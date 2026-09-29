# AQW Haxe Scripting API Guide (.hxs)

Welcome to the official scripting guide for the AQW Haxe API. Scripts are written in **HScript** (`.hxs` files) — a dynamic, lightweight scripting language matching standard JavaScript/ActionScript 3 syntax that executes live inside the game client.

---

## The Default Scripting Style (Top-Level & Zero-Boilerplate)

The official standard for all `.hxs` scripts is **clean, top-level natural language**. Redundant object prefixes like `bot.`, `map.`, or `combat.` are completely unnecessary — every primary game action is available directly at the top level.

### Canonical Example:
```javascript
// Test Script: Hunt 10 Possessed Armor in ShadowBattleon
function onStart() {
    log("starting routine");
    acceptAcDrops();
    equipLoadout("farm");
    join("shadowbattleon");
}

function onTick() {
    ensureMap("shadowbattleon");
    hunt("Possessed Armor", 10, stop);
}

function onStop() {
    log("ending routine");
    join("house"); 
}
```

Reading `onTick()` in plain English:
> *"Ensure map shadowbattleon. Hunt 10 Possessed Armor, then stop."*

---

## Table of Contents
1. [Script Lifecycle Hooks](#script-lifecycle-hooks)
2. [Top-Level Quick Reference](#top-level-quick-reference)
3. [Map & Navigation](#map--navigation)
4. [Combat & Hunting](#combat--hunting)
5. [Quests & Quest Chains](#quests--quest-chains)
6. [Drops, Inventory & Bank](#drops-inventory--bank)
7. [Blacklist Management](#blacklist-management)
8. [Player Status & Auras](#player-status--auras)
9. [The 6 Scripting Architectural Patterns](#the-6-scripting-architectural-patterns)
10. [AI Script Generation Prompting Guide](#ai-script-generation-prompting-guide)

---

## Script Lifecycle Hooks

Every `.hxs` script defines these standard lifecycle functions:

| Hook | When it executes | Common Usage |
|---|---|---|
| `onStart()` | Executed **once** when the script starts | Set drop filters (`acceptAcDrops()`), equip loadouts, join starting map, start background `autoQuest()` |
| `onTick()` | Executed **periodically** (every 100ms) | Main routine (hunting monsters, checking quests, ensuring map location) |
| `onStop()` | Executed **once** when finished or stopped | Final teleport (e.g. `join("house")`), cleanup, final completion logs |
| `onPacket(packet)` | Executed on every incoming server packet | Custom packet sniffing, rare event triggers |
| `onZoneEntered(zone)`| Executed on cell or map transfers | Location-triggered buffs or special dialog handling |
| `onQuestUpdated(id)` | Executed when a quest objective updates | Custom quest progress logging |
| `onInventoryChanged(item)`| Executed when items are added/removed | Inventory tracking |

---

## Top-Level Quick Reference

### Navigation
- `join(mapName, cell?, pad?)`: Transfers to a map. `join("house")` routes directly to your personal house. Automatically delays up to 2000ms if recently leaving combat to prevent transfer rejection.
- `joinHouse(username?)`: Transfers to your personal house, or specified player's house. Automatically manages safe combat exit cooldown.
- `ensureMap(mapName, cell?, pad?)`: Ensures you are in the target map and cell. Automatically drops combat stealthily before transferring if you are fighting.
- `ensureCell(cell, pad?)`: Ensures you are in the specified room on the current map.
- `jump(cell, pad?)`: Jumps to a room on the current map. Defaults to `"Spawn"` on `"Enter"`, and `"Left"` on all other rooms.
- `dropCombat()`: Drops combat in-place with **stealth coordinate retention** (breaks aggro without character warping).
- `setDeathSpawn(enabled? = true)`: Enables/disables auto-respawn at spawn point on death.
- `setSkipCutscenes(enabled? = true)`: Toggles automatic cutscene skipping on map joins.
- `skipCutscene()`: Immediately aborts any active in-game cutscene.

### Combat & Hunting
- `hunt(monster, count?, callback?)`: High-level full-map hunter. Discovers the cell, jumps there, locks target, tracks kills, and auto-drops combat when done.
- `hunt(monster, item, qty?, callback?)`: Hunts monster until you have `qty` of `item` in your inventory.
- `hunt(monster, itemsArray, callback?)`: Hunts monster until **all items** in array are gathered.
  - Format A: `hunt("Mob", ["Item A:10", "Item B:5", "Item C:1"])`
  - Format B: `hunt("Mob", [["Item A", 10], ["Item B", 5], ["Item C", 1]])`
  - Format C: `hunt("Mob", ["Item A", "Item B", "Item C"], 10)` (shared quantity)
- `huntQuest(questId, monster?, callback?)`: Automatically inspects quest requirements from the game data and hunts `monster` until all items for `questId` are collected (`canCompleteQuest(questId) == true`).
- `ensureCombat()`: Ensures smart combat rotations and auto-attack are active (safely idles while loading).
- `equipLoadout("farm" | "solo" | "support")`: Equips predefined class and skill rotations.
- `stopCombat()` / `stopAttack()`: Stops attacking and breaks combat aggro in-place.
- `attack(monster)` / `selectTarget(monster)`: Targets a specific monster.
- `useSkill(1..4)`: Manually activates a skill.
- `canUseSkill(1..4)`: Returns true if skill is off cooldown and has sufficient mana.
- `usePotion(potionName, auraName?)`: Equips and consumes a potion if the aura is not active.
- `setInfiniteRange(enabled? = true)`: Toggles infinite attack and targeting range.
- `magnetize()`: Teleports all monsters in the current cell directly onto your avatar coordinates.

### Quests
- `ensureQuest(id)`: Accepts the quest if not already in your active quest log.
- `ensureComplete(id, rewardChoice?, callback?)`: Turns in the quest once all requirements are fulfilled. `rewardChoice` can be an Item ID, reward name string (e.g. `"Blood Gem of the Archfiend"`), or `"unowned"` (auto-selects the first unowned reward).
- `ensureCompleteChoose(id, preferredItems?)`: Automatically selects the next reward not owned in backpack or bank. Ideal for multi-reward quests farmed multiple times without duplicate errors.
- `isChoiceQuest(id)` *(Bool)*: Returns `true` if the quest requires selecting a reward.
- `getChoiceRewards(id)` *(Array)*: Returns selectable choice reward items for the quest.
- `getUnownedRewards(id)` *(Array)*: Returns choice rewards that are not in your backpack and not in your bank.
- `getNextUnownedReward(id, preferredItems?)`: Returns the next choice reward item object not owned in backpack or bank.
- `autoQuest([ids])`: Runs quest acceptance, requirement checking, and turn-in automatically in the background (800ms timer, 1100ms safe server cooldown).
- `stopAutoQuest()`: Stops background auto-questing.
- `isQuestComplete(id)` *(Bool)*: Returns true if the quest has been completed and saved on the server (for story quests).
- `canCompleteQuest(id)` *(Bool)*: Returns true if all turn-in requirements are currently in your inventory.

### Drops, Inventory & Bank
- `acceptAcDrops(enabled? = true)`: Enables auto-accepting AdventureCoins drops for the session and sweeps current screen drops.
- `acceptAllDrops(enabled? = true)`: Enables auto-accepting all item drops for the session and sweeps current screen drops.
- `getDrop(itemName)`: Picks up a specific drop.
- `getDrops(filter?)`: Picks up pending drops matching filter or all drops (`"all"`).
- `bankItem(items)`: Deposits an item or array of items (`["Item 1", "Item 2"]`) into your Bank with automatic queue pacing.
- `bankAll(excludeItems?)`: Deposits **all unequipped, non-temporary** items from backpack into your Bank, optionally skipping any items in `excludeItems`.
- `bankAllExcept(presetOrList)`: Deposits unequipped backpack items, preserving both equipped gear AND any items in the specified preset or item list (e.g. `bankAllExcept("vhl")`).
- `bankAllAcItems(excludeItems?)`: Deposits all unequipped AC items into free bank storage.
- `unbankItem(items)`: Retrieves an item or array of items (`["Item 1", "Item 2"]`) from your Bank into your backpack with automatic queue pacing.
- `unbankPreset(name)`: Unbanks all items from a named hardfarm preset (e.g. `"nulgath"`, `"vhl"`, `"lr"`, `"nsod"`) with automatic queue pacing.
- `ensurePresetUnbanked(name)` *(Bool)*: Returns `true` once all items in the preset are verified to be in your backpack.
- `ensureUnbanked(items)` *(Bool)*: Ensures items are out of the bank. Returns `true` once items are confirmed in inventory.
- `unbankAllNonAcItems(excludeItems?)`: Loads your bank and withdraws all non-AC items back into inventory (automatically halting if inventory fills up).
- `bankAcAndUnbankNonAc(excludeItems?)`: Sequentially banks all AC items first, then withdraws non-AC items.
- `getBankableItems(excludeItems?)` *(Array<String>)*: Returns the list of unequipped, non-temporary backpack item names eligible for banking.
- `getBankableAcItems(excludeItems?)` *(Array<String>)*: Returns the list of unequipped AC item names eligible for banking.
- `getPresetItems(name)` *(Array<String>)*: Returns the array of item names belonging to the specified preset.
- `hasPreset(name)` *(Bool)*: Returns `true` if the named preset exists.
- `getPresetNames()` *(Array<String>)*: Returns the list of all available preset names.
- `isBanking()` *(Bool)*: Returns `true` while the bank deposit queue is actively processing.
- `isUnbanking()` *(Bool)*: Returns `true` while the unbank queue is actively processing.
- `isInBank(itemName)` *(Bool)*: Returns `true` if the item is currently in your bank.
- `hasItem(itemName, qty? = 1)` *(Bool)*: Returns `true` if you have the required item quantity in your backpack.
- `getItemCount(itemName)` *(Int)*: Returns the current quantity of an item in your backpack.
- `ensureEquipped(itemName)`: Equips an item or class if not currently worn.
- `isInventoryFull()` *(Bool)*: Returns `true` if backpack is full.
- `freeSlots()` *(Int)*: Returns count of empty inventory slots.

### Blacklist
- `addBlacklist(name)`: Adds an item to the blacklist filter.
- `removeBlacklist(name)`: Removes an item from the blacklist filter.
- `isBlacklisted(name)` *(Bool)*: Returns `true` if an item is currently on the blacklist.
- `getBlacklist()` *(Array<String>)*: Returns the list of all blacklisted item names.
- `clearBlacklist()`: Clears all items from the blacklist.
- `sellBlacklist()`: Iterates through inventory and immediately sells all owned blacklisted items.

### System & Flow Control
- `log(message)`: Outputs a timestamped message to the bot log console.
- `warn(message)`: Outputs a warning message to the bot log console.
- `error(message)`: Outputs an error message to the bot log console.
- `clearLog()`: Clears the console log.
- `notify(message)`: Displays an in-game notification popup/banner.
- `sleep(ms)`: Pauses `onTick()` execution for the specified milliseconds.
- `delay(ms, callback)`: Schedules a callback to execute after `ms` milliseconds.
- `stop()`: Halts the script, drops combat automatically, and triggers `onStop()`.

---

## Map & Navigation

### Stealth Drop Combat
AQW blocks map transfers while in combat. When you call `join()` or `ensureMap()`, the engine automatically:
1. Detects if you are in combat.
2. Captures your exact `(x, y)` avatar coordinates.
3. Reloads the cell in-place to send the aggro reset packet `%xt%zm%moveToCell%...%`.
4. Instantly restores your avatar position so other players don't see you warp across the room.

```javascript
// Transfers safely without ever getting blocked by combat aggro:
ensureMap("shadowbattleon");
ensureMap("shadowbattleon", "r2", "Left");
```

### Safe Combat Cooldown on Map Transfers
The AQW game server rejects map transfers (`cmd: "tfer"`) if sent within 2000ms of leaving combat. The API automatically tracks combat exit timestamps. When `join(map)` or `joinHouse()` is invoked:
1. If the player left combat less than 2000ms ago, the API automatically calculates the remaining cooldown time and safely delays the transfer packet.
2. The transfer is dispatched cleanly without triggering server rejections or disconnects.

This allows routines in `onStop()` to call `join("house")` right after halting combat without needing manual `sleep(2000)` calls:
```javascript
function onStop() {
    log("Routine complete");
    join("house"); // Automatically handles the 2-second combat cooldown safely!
}
```

---

## Combat & Hunting

### Full-Map Monster Discovery
You never need to hardcode cell names for monsters. When you call `hunt("Possessed Armor", ...)`, the engine:
1. Scans all rooms on the current map to find where `"Possessed Armor"` spawns.
2. Automatically jumps to that room and locks the target.
3. Once the target kills or items are gathered, it immediately drops combat in-place.

### Completion Callbacks
Pass `stop` as the callback to automatically halt the script and trigger `onStop()`:
```javascript
hunt("Possessed Armor", 10, stop);
```

---

## Quests & Quest Chains

### 1. Looping Farms vs Sequential Storylines
There are two primary paradigms for quests:
1. **Looping Farms** (e.g. repetitive leveling in ShadowBattleon): Use `autoQuest([9421, 9422, 9423])` in `onStart()`. It handles accepting and turning in all quests concurrently in the background.
2. **Sequential Storylines / Sagas**: Use `ensureQuest(id)` and `ensureComplete(id)` step by step.

### 2. Passing `stop` on Completion
When a quest must turn in before stopping, pass `stop` to `ensureComplete`, **never** `hunt`:
```javascript
// [CORRECT]:
hunt("Possessed Armor", "Armor Scrap", 10);
ensureComplete(1234, stop); // Turns in the quest, THEN halts!

// [WRONG]:
hunt("Possessed Armor", "Armor Scrap", 10, stop); // Exits before turning in!
ensureComplete(1234);                             // Never reached!
```

---

## Drops, Inventory & Bank

### Drop Management
Always enable drop handling in `onStart()`:
```javascript
function onStart() {
    acceptAcDrops();   // Auto-accept all AC-tagged drops
    // or:
    acceptAllDrops();  // Auto-accept all drops (regular + AC)
}
```

### The Bank Trap & Unbanking Routine (Crucial)
In AQW, if an item exists in your **Bank**, any new drops of that item will automatically be routed directly into your Bank instead of your backpack. Because quest turn-ins only check your backpack inventory, this causes the bot to farm forever!

To eliminate this problem, **always unbank your quest items in `onStart()`**:
```javascript
function onStart() {
    acceptAllDrops();
    equipLoadout("farm");

    // Unbank all quest items used across this script:
    unbankItem(["Bone Scrap", "Dark Core", "Broken Helm", "Fire Shard"]);

    join("shadowbattleon");
}
```

#### How `unbankItem([...])` works under the hood:
1. **Private House Safety**: The engine checks if you are in your private house. If you are in a public room, it automatically joins `house` first before transferring items, ensuring you never bank or unbank in public.
2. **Auto Bank Loading**: If bank data has not been retrieved from the server in this login session, it sends `sendLoadBankRequest(["All"])` and waits for the bank list.
3. **Smart Filtering**: It checks which items from your array are actually in the bank. Items already in your inventory or not owned are safely ignored.
4. **Paced Transfer Queue**: It transfers items one by one with a safe 1000ms server cooldown timer (including lag compensation) between packets to prevent kicks or bans.
5. **Combat Safety**: While unbanking is in flight (`isUnbanking == true`), `hunt()` automatically pauses combat so you never accidentally kill a monster while an unbank packet is in flight.

### Depositing Items to Bank (`bankAll()` & `bankItem()`)
To quickly empty your inventory before a big farm without accidentally banking what you're wearing:

```javascript
// Test Script: Bank All Unequipped Items
function onStart() {
    log("starting bank routine");
    bankAll(); // or bankAll(["Gold Voucher 25k", "Item To Keep"]);
}

function onTick() {
    if (isBanking()) return; // Wait for paced deposit queue to finish

    log("Banking complete");
    stop();
}

function onStop() {
    log("Bank all stopped");
}
```

### AC & Non-AC Optimization (`bankAllAcItems()` & `unbankAllNonAcItems()`)
In AQW, AC-tagged items have free unlimited bank storage, whereas non-AC items consume limited bank slots. To optimize your storage and avoid wasting bank slots:

- `bankAllAcItems(?exclude)`: Banks all unequipped AC items into free bank storage.
- `unbankAllNonAcItems(?exclude)`: Loads your bank and withdraws all non-AC items back into inventory (automatically halting if inventory fills up).
- `bankAcAndUnbankNonAc(?exclude)`: Sequentially banks all AC items first, then withdraws all Non-AC items.

```javascript
function onStart() {
    log("Starting AC inventory optimization");
    bankAcAndUnbankNonAc();
}

function onTick() {
    if (isBanking() || isUnbanking()) return;

    log("AC inventory optimization complete");
    stop();
}
```

#### How banking and unbanking protects your account:
1. **Private House Safety**: If you are not in your private house, the engine automatically moves you to `house` first before opening or transferring items.
2. **Equipped & Cosmetic Items Protected**: The engine strictly checks both `bEquip == 1` (equipped gear) and `bWear == 1` (cosmetics shown in green). Classes, armors, weapons, helms, capes, and pets you are currently wearing or displaying as cosmetics are never banked.
3. **Temporary Items Excluded**: Temporary quest drops (`bTemp == 1`) cannot be stored in the bank and are safely skipped.
4. **Queue Pacing & Lag Compensation**: Items are transferred one by one using an 1100ms server cooldown timer (`isBanking == true` / `isUnbanking == true`), preventing packet flooding, server warnings, or disconnects.
5. **Inventory Overflow Protection**: When unbanking Non-AC items, the queue checks `isFull` and safely halts if your bag fills up, preventing exceeded storage server modals.
6. **Auto Popup Closing**: Closes the bank popup (`ui.mcPopup.fClose()`) once transfers complete.

### Built-in Hardfarm Item Presets (`unbankPreset()` & `bankAllExcept()`)

AQW hardfarms involve dozens of reagents, quest items, and temporary boss drops. If any reagent exists in your Bank when a mob drops it, AQW routes the drop straight into your Bank instead of your backpack, stalling your farm.

To completely prevent this without writing 50-item lists manually, use the **built-in hardfarm presets** stored in `assets/item_presets.json`:

#### 12 Available Presets:
- `"nulgath"` (*Nulgath Nation*) - 27 items: Vouchers (member & non-mem), Gems, Diamonds, Tainted Gems, Dark Crystal Shards, Blood Gems, Totems, Essences, Emblems, Receipts, Fiend Tokens, Bone Dust, Approvals/Favors, Unidentified items (1, 6, 9, 10, 13, 16, 19, 20, 24, 25, 34), Relic of Chaos.
- `"vhl"` (*Void Highlord*) - 32 items: Roentgeniums, Crystals A & B, Unidentified 10/13/19, Elders' Blood, Totems, Blood Gems, Vouchers, etc.
- `"lr"` (*Legion Revenant*) - 24 items: LF1, LF2 (all 10 cohorts), LF3, Spellscrolls, Conquest Wreaths, Exalted Crowns, Legion Tokens.
- `"dot"` (*Dragon of Time*) - 49 items: All temporal artifacts, boss fangs, and quest requirements.
- `"ynr"` (*Yami no Ronin*) - 28 items: All sword scrolls, folded steel, yami, and materials.
- `"kings_echo"` (*King's Echo*) - 19 items: Crown, royal sword, reforged armor, and gold vouchers.
- `"vdk"` (*Verus DoomKnight*) - 44 items: All souls, elemental traces, and doom artifacts.
- `"cav"` (*Chaos Avenger*) - 10 items: All fragments, amulets, and insignias.
- `"arcana_invoker"` (*Arcana Invoker*) - 29 items: All 22 Major Arcana tarot items and core materials.
- `"archmage"` (*ArchMage*) - 27 items: Books, tomes, astral boss drops, and scribing materials.
- `"nsod"` (*Necrotic Sword of Doom*) - 29 items: Void auras, essences, hilts, blades, and doom auras.
- `"sdka"` (*Sepulchure's DoomKnight Armor*) - 40 items: Dark spirit orbs, metals, weapon kits, and doom auras.

#### Usage in Scripts:
```javascript
function onStart() {
    log("Starting Void Highlord farm...");
    acceptAllDrops();
    equipLoadout("farm");

    // 1. Bank all junk while strictly preserving VHL materials:
    bankAllExcept("vhl");

    // 2. Unbank all 32 VHL reagents so drops never get misdirected:
    unbankPreset("vhl");

    join("tercessuinotlim");
}

function onTick() {
    // Wait until unbanking queue completes before fighting:
    if (isUnbanking()) return;

    // Routine continues...
}
```

---

## Blacklist Management

The Blacklist system blocks unwanted items before they enter your drop queue and enables quick liquidation of junk items:

### Blocking Drops
When an item is added to the blacklist:
- `acceptAllDrops()` will automatically reject the blacklisted item.
- The item will never clutter your drop UI or inventory space.

### Mass-Selling Blacklisted Items
If unwanted items already exist in your backpack (e.g. from previous quests or mob farming), `sellBlacklist()` safely scans your inventory and sells every blacklisted item one by one.

### Scripting Example:
```javascript
function onStart() {
    log("Setting up drop filters and blacklist");
    acceptAllDrops();

    // Add unwanted junk drops to blacklist:
    addBlacklist("Bone Scrap");
    addBlacklist("Zardman Tooth");

    // Mass-sell any blacklisted items currently taking up bag space:
    sellBlacklist();

    join("shadowbattleon");
}
```

---

## The 6 Scripting Architectural Patterns

### Pattern 1: Minimalist Kill-Count Hunter
Hunts a target number of monsters and safely teleports to house when finished:
```javascript
function onStart() {
    log("starting routine");
    acceptAcDrops();
    equipLoadout("farm");
    join("shadowbattleon");
}

function onTick() {
    ensureMap("shadowbattleon");
    hunt("Possessed Armor", 10, stop);
}

function onStop() {
    log("ending routine");
    join("house"); 
}
```

---

### Pattern 2: Sequential Storyline Quest Chain (`if (!huntQuest) return;`)
For multi-quest sagas where Quest 2 unlocks only after Quest 1 is turned in:
```javascript
function onStart() {
    acceptAllDrops();
    equipLoadout("farm");
}

function onTick() {
    // --- Quest 1 ---
    ensureMap("shadowbattleon");
    if (!huntQuest(9421, "Possessed Armor")) return;
    ensureComplete(9421);

    // --- Quest 2 ---
    ensureMap("infernalarena");
    if (!huntQuest(9422, "Infernal Knight")) return;
    ensureComplete(9422);

    // --- Quest 3 ---
    ensureMap("iceplane");
    if (!huntQuest(9423, "Frost Giant")) return;
    ensureComplete(9423);

    // All quests complete!
    stop();
}

function onStop() {
    log("Quest chain finished!");
    join("house");
}
```
> **Why `if (!huntQuest(...)) return;` is used**: While the quest requirements are still being hunted, `huntQuest` returns `false`, exiting `onTick()` for this cycle. The rest of the file waits until Quest 1 is 100% complete!

---

### Pattern 3: Data-Driven Task Table (10+ Quests & 30+ Items)
The cleanest, most compact way to write massive 10+ quest chains (e.g. Void Highlord, ArchMage, Legion Revenant):
```javascript
var tasks = [
    { map: "shadowbattleon", quest: 9421, mob: "Possessed Armor", items: [["Bone Scrap", 10], ["Dark Core", 5]] },
    { map: "infernalarena",  quest: 9422, mob: "Infernal Knight", items: [["Fire Shard", 10], ["Ash Ore", 3]] },
    { map: "iceplane",       quest: 9423, mob: "Frost Giant",     items: [["Ice Shard", 10], ["Frost Core", 2]] }
];

function onStart() {
    acceptAllDrops();
    equipLoadout("farm");
}

function onTick() {
    for (t in tasks) {
        if (!isQuestComplete(t.quest)) {
            ensureMap(t.map);
            ensureQuest(t.quest);

            // Gathers all items for this mob:
            hunt(t.mob, t.items);

            ensureComplete(t.quest);
            return; // Stays on this task until complete!
        }
    }

    // All 10 tasks completed:
    stop();
}

function onStop() {
    log("All tasks completed!");
    join("house");
}
```

---

### Pattern 4: Background Concurrent Farming (`autoQuest`)
For infinite or long-running farming of multiple quests in the same map (leveling, reputation, gold):
```javascript
function onStart() {
    log("Starting auto-leveling...");
    acceptAllDrops();
    equipLoadout("farm");
    join("shadowbattleon", "Enter", "Spawn");
    autoQuest([9421, 9422, 9423]); // Runs in background
}

function onTick() {
    ensureMap("shadowbattleon", "Enter", "Spawn");
    ensureCombat();
}

function onStop() {
    log("Stopped leveling.");
    stopAutoQuest();
    stopCombat();
    join("house");
}
```

---

### Pattern 5: Multi-Item Hunt from a Single Monster
When 1 monster drops 2, 3, or more required items:
```javascript
function onStart() {
    acceptAllDrops();
    equipLoadout("farm");
    join("shadowbattleon");
}

function onTick() {
    ensureMap("shadowbattleon");
    ensureQuest(9421);

    // Tracks all 3 items simultaneously:
    hunt("Possessed Armor", ["Bone Scrap:10", "Dark Core:5", "Broken Helm:1"]);

    ensureComplete(9421, stop);
}

function onStop() {
    join("house");
}
```

---

### Pattern 6: Finite State Machine (`switch (step)`)
When you need explicit control with cutscenes, dialogs, or shop purchases between quests:
```javascript
var step = 1;

function onStart() {
    acceptAllDrops();
    equipLoadout("farm");
}

function onTick() {
    switch (step) {
        case 1:
            ensureMap("shadowbattleon");
            if (huntQuest(9421, "Possessed Armor")) {
                ensureComplete(9421);
                step = 2;
            }
            break;

        case 2:
            ensureMap("infernalarena");
            if (huntQuest(9422, "Infernal Knight")) {
                ensureComplete(9422);
                step = 3;
            }
            break;

        case 3:
            stop();
            break;
    }
}

function onStop() {
    join("house");
}
```

---

## AI Script Generation Prompting Guide

When copying this document into an AI (ChatGPT, Claude, Gemini, etc.) to generate AQW scripts, provide this instruction:

> **System Prompt for AI**:
> You are generating an AQW `.hxs` script using the AQW Haxe Scripting API. Follow these mandatory rules:
> 1. Always implement `function onStart()`, `function onTick()`, and `function onStop()`.
> 2. NEVER use object prefixes (`bot.`, `map.`, `combat.`). Use direct top-level methods (`join`, `ensureMap`, `hunt`, `huntQuest`, `ensureQuest`, `ensureComplete`, `stop`).
> 3. Use `acceptAcDrops()` or `acceptAllDrops()` inside `onStart()`.
> 4. For sequential multi-map quests, always guard with `if (!hunt(...)) return;` or `if (!huntQuest(...)) return;` so `onTick()` does not evaluate downstream stages early.
> 5. If the script turns in a quest before finishing, pass `stop` to `ensureComplete(questId, stop)`. Never pass `stop` to `hunt` if a quest turn-in is required.
> 6. Always include `join("house");` inside `onStop()`.
> 7. If the quest requires non-temporary items that might be stored in the Bank, always unbank them in `onStart()`: `unbankItem(["Item 1", "Item 2"]);`.
