# AQW Haxe Scripting Guide

Scripts for the AQW Haxe API are `.hxs` files written in HScript. They execute inside the AQW client and call the existing Haxe API managers for maps, quests, combat, inventory, drops, shops, auras, and player state.

This guide describes the current Ruffle/Mugetsu scripting runtime. It does not describe the planned Rust API or a future CoreBots layer.

## Contents

1. [Execution model](#execution-model)
2. [Script lifecycle](#script-lifecycle)
3. [Event callbacks](#event-callbacks)
4. [Writing a script](#writing-a-script)
5. [Top-level API](#top-level-api)
6. [Subsystem namespaces](#subsystem-namespaces)
7. [Script storage and Script Manager](#script-storage-and-script-manager)
8. [Included scripts](#included-scripts)
9. [Safety rules](#safety-rules)
10. [Examples](#examples)

## Execution model

HScript runs on the same game/client thread as the Haxe bridge. Scripts must never block that thread or access AQW objects from a background thread.

The scheduler has a nominal 100 ms watchdog interval, configured by `ApiTimings.SCRIPT_TICK_MS`. This is a scheduler interval, not a combat packet tick. Combat timing remains owned by `CombatManager` and `CombatEngine`.

The runtime is cooperative:

- A script callback runs briefly and returns control to the game.
- `sleep(ms)` yields the script until the requested deadline; it does not block the client.
- Map loading, player death, and unavailable game state pause script work safely.
- Callbacks from game events are queued and processed on the next scheduler turn. They are not invoked re-entrantly from packet or game handlers.
- Combat update callbacks are coalesced because only the newest combat state is useful.
- Packet and lifecycle callbacks preserve their order.

The callback queue currently allows up to 256 pending callbacks and processes at most 16 per scheduler turn. Slow callbacks and queue overflow are logged by the API.

When a script starts, the engine saves and restores temporary script settings such as infinite range, death-spawn behavior, cutscene skipping, smart class, and skill mode. Scripts should still stop their own combat and automation in `onStop()`.

## Script lifecycle

The three main lifecycle functions are optional, but a normal long-running script should define all three:

```hscript
function onStart() {
    log("Script started");
    acceptAllDrops();
    equipLoadout("farm");
}

function onTick() {
    // State-machine watchdog and recovery logic.
}

function onStop() {
    stopCombat();
    stopAutoQuest();
    restoreGear();
    log("Script stopped");
}
```

`onStart()` runs once after the script has been loaded and started.

`onTick()` runs from the scheduler. Use it for a small state machine, not for blocking loops. If a script has no `onTick()` but has event callbacks, it runs in event-driven mode. If it has neither a tick loop nor event callbacks, it executes once and stops after any API-owned background action finishes.

`onStop()` runs when the user stops the script, when the script calls `stop()`, or when the runtime stops it after an error. Cleanup should be safe to call more than once.

## Event callbacks

The engine recognizes these callbacks:

```hscript
function onPacket(type, command, data) {
    // Observational packet callback. Keep it very light.
}

function onZoneEntered(data) {
    // The map is ready before this callback is queued.
}

function onQuestUpdated(data) {
    // Quest state or completion data changed.
}

function onInventoryChanged(data) {
    // Inventory or temporary quest inventory changed.
}

function onCombatUpdated(data) {
    // Combat state changed. Updates may be coalesced.
}
```

Use events to wake or invalidate a state machine. Do not perform a large quest chain inside an event callback. Set a flag and let `onTick()` perform the next action:

```hscript
var needsReview = true;

function onInventoryChanged(data) {
    needsReview = true;
}

function onTick() {
    if (!needsReview && isInCombat()) {
        sleep(400);
        return;
    }

    needsReview = false;
    if (!huntItem("Doomed Troll", "Troll Token", 10)) {
        sleep(300);
        return;
    }
    log("Objective complete");
    stop();
}
```

## Writing a script

HScript uses Haxe-style expressions and functions. It is not JavaScript, and it is not a second ActionScript program. The API injects the registered functions into the script scope.

Prefer the clean top-level functions for normal scripts:

```hscript
ensureMap("shadowbattleon", "Enter", "Spawn");
ensureAccept(9421);
if (!hunt("Doomed Troll", "Troll Token", 10)) return;
if (!complete(9421)) return;
```

The API identity is also available as `api` for advanced access. `bot` remains as a compatibility alias, but new scripts should prefer top-level functions or `api.*` so the script describes the API rather than a bot object.

## Top-level API

All functions below are available without a namespace prefix.

### Navigation and map state

- `join(map, cell?, pad?)`
- `joinHouse(username?)`
- `ensureMap(map, cell?, pad?)` -> `Bool`
- `ensureHouse()` -> `Bool`
- `isHouse()` / `isMap(name)` / `isCell(name)` / `isLoaded()` -> `Bool`
- `jump(cell, pad?, autoCorrect?)`
- `jumpCorrect(cell, pad?)`
- `ensureCell(cell, pad?)` -> `Bool`
- `cell()` / `getCell()`
- `pad()` / `getPad()`
- `mapName()` / `getMapName()`
- `getMapCells()` / `getCellPads()` / `getValidCellPads()`
- `ensureTercess(destination?, pad?)` -> `Bool`
- `joinTercess(destination?, pad?)`
- `isTercess()` -> `Bool`
- `fastTravel(destination)` -> `Bool`
- `walkThroughWalls(enabled?)`
- `disableCollisions(enabled?)`
- `setSkipCutscenes(enabled?)` / `autoSkipCutscenes(enabled?)`
- `skipCutscenes()` / `skipCutscene()`
- `isSkipCutscenes()` -> `Bool`
- `getMapItem(itemId)` -> `Bool`
- `mapItem(itemId, quantityOrName?, nameOrMap?, map?)` -> `Bool`
- `ensureMapItem(...)` -> `Bool`
- `resetMapItems()`

`ensureMap()` and `ensureCell()` are asynchronous in behavior: a `false` result means the action is still pending or the target is not ready. Call them again from a later scheduler turn.

### Combat and hunting

- `hunt(monster, itemOrCount?, quantityOrCallback?, mmidOrCallback?, onComplete?)` -> `Bool`
- `kill(...)` -> alias for `hunt`
- `huntItem(monster, item, quantity?, map?)` -> `Bool`
- `huntForItem(monster, item, quantity?, isTemp?, onComplete?)` -> `Bool`
- `farmItem(monster, item, quantity?, isTemp?, onComplete?)` -> `Bool`
- `huntMonster(monster, kills?, map?)` -> `Bool`
- `attack(monster)`
- `ensureCombat(smart?)`
- `stopCombat()`
- `resetHunt()`
- `equipLoadout(name)` -> `Bool`
- `setTargetPriority(targets)`
- `setHuntPriority(priority)`
- `getBestTarget(nameOrId?)`
- `getBestMonsterTarget(cell?, nameOrId?)`
- `sortByLowestHp(monsters)`
- `provokeAll(enabled?)`
- `farmCell(cell?)`
- `usePotion(name)` -> `Bool`
- `autoPotion(name, intervalMs?, hpThreshold?)`
- `stopAutoPotion()`
- `enableTaunt(presetOrBoss)` / `tauntBoss(presetOrBoss)` / `taunt(presetOrBoss?)`
- `disableTaunt()`
- `counterHandler(enabled?)` / `enableCounterHandler(enabled?)`
- `pauseOnAuras(auras)` / `clearPauseAuras()`
- `isPausedByAura()` -> `Bool`

`hunt()` is an idempotent request. It returns `false` while map travel, target selection, combat, drops, or requirements are still in progress. Use an early return and let the next scheduler turn continue the same request:

```hscript
if (!hunt("Doomed Troll", "Troll Token", 10)) {
    sleep(300);
    return;
}
```

The combat manager owns target selection, skill timing, cooldowns, approach behavior, and native AQW action validation. Scripts choose goals and conditions; they do not reproduce the combat loop.

### Quests and progression

- `quest(questId, mapName?)` -> `Bool`
- `ensureQuest(questId)` / `ensureAccept(questId)` -> `Bool`
- `acceptQuest(questId)`
- `complete(questId, choice?)` -> `Bool`
- `completeChoose(questId, preferredItems?)` -> `Bool`
- `ensureComplete(questId, choice?)` -> `Bool`
- `completeQuest(questId, choice?)` (raw, non-waiting turn-in)
- `canComplete(questId)` / `isQuestComplete(questId)` -> `Bool`
- `hasBeenCompleted(questId)` / `isCompletedBefore(questId)` -> `Bool`
- `isDaily(questId)` / `isDailyComplete(questId)` -> `Bool`
- `isQuestAccepted(questId)` -> `Bool`
- `isQuestUnlocked(questId)` / `isUnlocked(questId)` -> `Bool`
- `loadQuest(questId)` / `loadQuests(questIds)`
- `ensureQuestsLoaded(questIds)` / `areQuestsLoaded(questIds)` -> `Bool`
- `getMissingRequirements(questId)` -> `Array`
- `storyKillQuest(questId, map, monster)` -> `Bool`
- `storyMapItemQuest(questId, map, itemIds, amount?)` -> `Bool`
- `storyChainQuest(questId, map?)` -> `Bool`
- `autoQuest(questIds)`
- `stopAutoQuest()`
- `isAutoQuestRunning()` -> `Bool`

Quest identifiers should be numeric IDs. `complete()` checks native AQW quest state and server requirements before sending a turn-in. `completeQuest()` is the lower-level immediate operation; use it only when you intentionally manage acknowledgement yourself.

### Inventory, bank, shops, and gear

- `hasItem(nameOrId, quantity?)` -> `Bool`
- `getItemCount(nameOrId)`
- `getQuestQuantity(nameOrId)`
- `getInventoryQuantity(nameOrId)`
- `getBankQuantity(nameOrId)`
- `getTempQuantity(nameOrId)`
- `hasTempItem(nameOrId, quantity?)` -> `Bool`
- `getItemLocation(nameOrId)`
- `findItem(nameOrId)`
- `getInventory()` / `getBankItems()` / `getTempItems()`
- `equip(nameOrId)` / `ensureEquipped(nameOrId)` / `isEquipped(nameOrId)`
- `storeGear(items?)`
- `restoreGear(onComplete?)`
- `ensureRestored()` / `ensureRestoreGear()` / `isGearRestored()` -> `Bool`
- `hasGearSnapshot()` / `getGearSnapshot()` / `clearGearSnapshot()`
- `cancelRestoreGear()`
- `bankAll(exclude?)`
- `bankAllAcItems(exclude?)`
- `unbankPreset(name)`
- `unbankAllNonAcItems(exclude?)`
- `bankAcAndUnbankNonAc(exclude?)`
- `isBanking()` / `isUnbanking()` -> `Bool`
- `buyItem(shopId, nameOrId?, quantity?)`
- `buyItems(list, gapMs?)`
- `getPendingBuyCount()` / `clearBuyQueue()`
- `sellItem(nameOrId, quantity?)`

`getQuestQuantity()` is the preferred requirement check because it understands normal inventory and temporary quest inventory. Use bank-aware helpers when a script intentionally wants to include or move banked items.

### Drops and blacklists

- `acceptAllDrops(enabled?)`
- `acceptAcDrops(enabled?)`
- `getDrop(nameOrId)`
- `getDrops(target?)`
- `addBlacklist(nameOrId)` / `removeBlacklist(nameOrId)`
- `isBlacklisted(nameOrId)`
- `clearBlacklist()`
- `sellBlacklist()`

Both `acceptAllDrops(true)` and the compatibility assignment form `acceptAllDrops = true` are supported.

### Player, boosts, auras, party, and feedback

Player state:

- `hp()` / `maxHp()` / `mp()` / `maxMp()`
- `gold()` / `level()` / `username()`
- `isAlive()` / `isInCombat()` / `isMember()`
- `factionRank(name)`
- `hasAura(name)` / `getAuraStacks(name)` / `getAuraRemaining(name)`
- `isBoostActive(type)` / `getBoostRemaining(type)` / `useBoost(nameOrId)` / `autoBoost(type, enabled?)`

Party:

- `inParty()` / `isPartyLeader()` / `partyLeader()`
- `partyMembers()` / `partyTarget()`
- `partyInvite(username)` / `partyKick(username)` / `partyLeave()`

Auras:

- `cleanAuras()` / `cleanExpiredAuras()`
- `autoCleanAuras(enabled?)`

Feedback and diagnostics:

- `log(message)`
- `warn(message)` / `error(message)`
- `msg(message)` / `notify(message)` / `notifyCard(message)`
- `notifySticky(id, message)` / `removeStickyNotification(id)`
- `getStickyNotifications()` / `clearStickyNotifications()`
- `logToScreen(message)`
- `setMirrorLogs(enabled?)`
- `setDiagnostics(enabled?)` / `getDiagnostics()`
- `setChatLogging(enabled?)` / `isChatLogging()`
- `clearLog()`
- `feedbackConfig()`
- `rateLimit(name, intervalMs?)` / `rateLimitDump()`
- `questActionCooldownMs()`

### Script control

- `sleep(milliseconds)`
- `stop()`
- `sendPacket(packet)`
- `resetStoryData()`

`sendPacket()` is intentionally a low-level escape hatch. Prefer the typed API managers because they apply native validation, action timing, state tracking, and cleanup.

## Subsystem namespaces

The same managers can be reached through namespaces when a script needs deeper access:

```hscript
api.map.ensure("shadowbattleon", "Enter", "Spawn");
api.combat.stopCombat();
api.quest.canComplete(9421);
api.inventory.getQuestQuantity("Troll Token");
api.player.hp;
api.aura.getRemaining("Power Word Die");
```

Available namespaces include:

| Namespace | Manager |
|---|---|
| `api` / `bot` | Full API compatibility entry point; prefer `api` in new scripts |
| `player` | Player state and player auras/boosts |
| `stateHealth` | Snapshot freshness and state-domain health |
| `combat` | Combat manager and skill actions |
| `map` | Map, travel, cells, and map items |
| `quests` | Quest loading, acceptance, completion, and status |
| `inventory` / `inv` | Inventory, temporary items, gear, and banking |
| `bank` | Inventory manager banking operations |
| `drop` / `drops` | Drop acceptance and pickup |
| `shop` / `shops` | Shop loading and purchase queues |
| `monster` / `monsters` | Monster discovery and target selection |
| `enhancement` / `enhancements` | Enhancement operations |
| `skills` | Skill profiles and combat mode data |
| `aura` / `auras` | Aura queries and cleanup |
| `party` | Party operations |
| `blacklist` | Item blacklist operations |
| `script` | Script manager state |
| `events` | API event dispatcher |

`ApiTime`, `ApiUtils`, `ApiJson`, and `ApiStorage` are also resolvable for advanced scripts. Treat storage and manager internals as advanced APIs because their exact fields can change.

## Script storage and Script Manager

The Script Manager discovers `.hxs` files from:

- Bundled `assets/scripts/` files included in the API build.
- Persistent user scripts saved by the Script Manager.

In Ruffle/Mugetsu, user scripts are persisted through the client’s SharedObject-backed API storage. Bundled scripts are read-only; saving a bundled script creates a user copy instead of overwriting the bundled asset.

The Script Manager can:

- Load bundled and user scripts.
- Create and save user scripts.
- Edit HScript source.
- Start and stop the active script.
- Delete user scripts.

The topbar Script button opens the manager. The Script Runner control starts or stops the selected script; opening the manager does not start it.

## Included scripts

Current bundled examples include:

- `Dailies.hxs` — legacy step-based daily routine.
- `Dailies_Advanced.hxs` — data-driven daily queue with event-assisted progression and membership-aware tasks.
- `ShadowBattleon_Leveling.hxs` — simple auto-quest leveling example.
- `ShadowBattleon_Farm_EventDriven.hxs` — lifecycle and event callback example.
- `ShadowBattleon_API_Test.hxs` — result callbacks and state-health probe example.
- `Bank_All_Items.hxs`, `Bank_All_Ac_Items.hxs`, and `Unbank_All_Non_Ac_Items.hxs` — inventory examples.
- `Optimize_AC_Inventory.hxs` and `Sell_Blacklisted.hxs` — maintenance examples.

The advanced daily script demonstrates the preferred direction for larger scripts: a small state machine, declarative task data, native API actions, and event callbacks used to wake or re-evaluate the current task.

## Safety rules

1. Never use blocking `while` loops, `Thread.sleep`, or long synchronous work in a script.
2. Keep each lifecycle/event callback short and return control to the scheduler.
3. Use early returns when an action returns `false`; that normally means the action is pending.
4. Let `CombatManager` own skill timing, target locking, cooldowns, movement, aura checks, and native AQW action validation.
5. Use `isDailyComplete()` for daily lockouts. Do not treat a daily quest as a permanent quest-slot completion.
6. Use numeric quest IDs and readable monster/item names unless an ID is needed to disambiguate a target.
7. Use `getQuestQuantity()` for quest requirements instead of manually adding inventory containers.
8. Stop automation and combat in `onStop()`.
9. Restore gear only when the script created a snapshot with `storeGear()`.
10. Keep packet callbacks observational and rate-limited; never run a full quest or combat routine from `onPacket()`.
11. Do not assume a script callback runs at combat speed. Combat is event/action driven; script scheduling is separate.
12. Do not use the compatibility `bot` namespace in new scripts. Prefer clean functions or `api.*`.

## Examples

### Simple state-machine farm

```hscript
var active = true;

function onStart() {
    storeGear();
    acceptAllDrops();
    equipLoadout("farm");
}

function onTick() {
    if (!active) return;
    if (!ensureMap("shadowbattleon", "Enter", "Spawn")) {
        sleep(300);
        return;
    }
    if (!huntItem("Doomed Troll", "Troll Token", 10)) {
        sleep(300);
        return;
    }
    log("Farm goal reached");
    stop();
}

function onStop() {
    active = false;
    stopCombat();
    restoreGear();
}
```

### Quest routine

```hscript
var questId = 9421;

function onStart() {
    acceptAllDrops();
    equipLoadout("farm");
}

function onTick() {
    if (isDailyComplete(questId)) {
        log("Daily already complete");
        stop();
        return;
    }
    if (!ensureMap("shadowbattleon", "Enter", "Spawn")) return;
    if (!ensureAccept(questId)) return;
    if (!hunt("Doomed Troll", "Troll Token", 10)) return;
    if (!complete(questId)) return;
    stop();
}

function onStop() {
    stopCombat();
}
```

### Event-assisted queue

```hscript
var review = true;

function onInventoryChanged(data) {
    review = true;
}

function onQuestUpdated(data) {
    review = true;
}

function onTick() {
    if (!review && isInCombat()) {
        sleep(400);
        return;
    }
    review = false;

    if (!huntItem("Doomed Troll", "Troll Token", 10)) {
        sleep(300);
        return;
    }
    stop();
}
```

### Planned CoreBots-style layer

A reusable CoreBots-style layer is not yet part of the API contract. It is planned as smaller API-oriented services such as `CoreQuest`, `CoreCombat`, `CoreInventory`, `CoreDailies`, and `CoreProgression`. Until those services exist, reusable script helpers should remain in the script itself or in the typed Haxe managers rather than assuming a `core` namespace is available.
