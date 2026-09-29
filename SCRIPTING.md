# AQW Haxe Scripting API Guide (.hxs)

Welcome to the official scripting guide for the AQW Haxe API. Scripts are written in **HScript** (`.hxs` files) — a dynamic, lightweight scripting language matching standard JavaScript/ActionScript 3 syntax that executes live inside the game client.

---

## 🌟 The Default Scripting Style (Top-Level & Zero-Boilerplate)

The official standard for all `.hxs` scripts is **clean, top-level natural language**. Redundant object prefixes like `bot.`, `map.`, or `combat.` are completely unnecessary — every primary game action is available directly at the top level.

### Canonical Example:
```javascript
// Test Script: Hunt 10 Possessed Armor in ShadowBattleon
function onStart() {
    log("starting routine");
    acceptAcdrops();
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
7. [Player Status & Auras](#player-status--auras)
8. [The 6 Scripting Architectural Patterns](#the-6-scripting-architectural-patterns)
9. [AI Script Generation Prompting Guide](#ai-script-generation-prompting-guide)

---

## Script Lifecycle Hooks

Every `.hxs` script defines these standard lifecycle functions:

| Hook | When it executes | Common Usage |
|---|---|---|
| `onStart()` | Executed **once** when the script starts | Set drop filters (`acceptAcdrops()`), equip loadouts, join starting map, start background `autoQuest()` |
| `onTick()` | Executed **periodically** (every 100ms) | Main routine (hunting monsters, checking quests, ensuring map location) |
| `onStop()` | Executed **once** when finished or stopped | Final teleport (e.g. `join("house")`), cleanup, final completion logs |
| `onPacket(packet)` | Executed on every incoming server packet | Custom packet sniffing, rare event triggers |
| `onZoneEntered(zone)`| Executed on cell or map transfers | Location-triggered buffs or special dialog handling |
| `onQuestUpdated(id)` | Executed when a quest objective updates | Custom quest progress logging |
| `onInventoryChanged(item)`| Executed when items are added/removed | Inventory tracking |

---

## Top-Level Quick Reference

### Navigation
- `join(mapName, cell?, pad?)`: Transfers to a map. `join("house")` routes directly to your personal house.
- `ensureMap(mapName, cell?, pad?)`: Ensures you are in the target map and cell. Automatically drops combat stealthily before transferring if you are fighting.
- `ensureCell(cell, pad?)`: Ensures you are in the specified room on the current map.
- `jump(cell, pad?)`: Jumps to a room on the current map. Defaults to `"Spawn"` on `"Enter"`, and `"Left"` on all other rooms.
- `reload()`: Drops combat in-place with **stealth coordinate retention** (breaks aggro without character warping).

### Combat & Hunting
- `hunt(monster, count?, callback?)`: High-level full-map hunter. Discovers the cell, jumps there, locks target, tracks kills, and auto-drops combat when done.
- `hunt(monster, item, qty?, callback?)`: Hunts monster until you have `qty` of `item` in your inventory.
- `hunt(monster, itemsArray, callback?)`: Hunts monster until **all items** in array are gathered.
  - Format A: `hunt("Mob", ["Item A:10", "Item B:5", "Item C:1"])`
  - Format B: `hunt("Mob", [["Item A", 10], ["Item B", 5], ["Item C", 1]])`
  - Format C: `hunt("Mob", ["Item A", "Item B", "Item C"], 10)` (shared quantity)
- `huntQuest(questId, monster?, callback?)`: Automatically inspects quest requirements from the game data and hunts `monster` until all items for `questId` are collected (`canComplete(questId) == true`).
- `ensureCombat()`: Ensures smart combat rotations and auto-attack are active (safely idles while loading).
- `equipLoadout("farm" | "solo" | "support")`: Equips predefined class and skill rotations.
- `stopCombat()` / `endCombat()`: Stops attacking and breaks combat aggro in-place.
- `attack(monster)` / `selectTarget(monster)`: Targets a specific monster.
- `useSkill(1..4)`: Manually activates a skill.

### Quests
- `ensureQuest(id)` / `ensureAccept(id)`: Accepts the quest if not already in your active quest log.
- `ensureComplete(id, itemId?, callback?)`: Turns in the quest once all requirements are fulfilled. Accepts optional `stop` callback.
- `autoQuest([ids])`: Runs quest acceptance, requirement checking, and turn-in automatically in the background (800ms timer, 1100ms safe server cooldown).
- `stopAutoQuest()`: Stops background auto-questing.
- `isQuestComplete(id)` *(Bool)*: Returns true if the quest has been completed and saved on the server (for story quests).
- `canComplete(id)` *(Bool)*: Returns true if all turn-in requirements are currently in your inventory.

### Drops, Inventory & Bank
- `acceptAcdrops(enabled? = true)`: Enables auto-accepting AdventureCoins drops for the session and sweeps current screen drops.
- `acceptAllDrops(enabled? = true)`: Enables auto-accepting all item drops for the session and sweeps current screen drops.
- `bank(items)`: Deposits an item or array of items (`["Item 1", "Item 2"]`) into your Bank with automatic 650ms queue pacing.
- `bankAll(excludeItems?)`: Deposits **all unequipped, non-temporary** items from backpack into your Bank, optionally skipping any items in `excludeItems`.
- `isBanking()` *(Bool)*: Returns `true` while the bank deposit queue is actively processing.
- `getBankableItems(excludeItems?)` *(Array<String>)*: Returns the list of unequipped, non-temporary backpack item names eligible for banking.
- `unbank(items)`: Retrieves an item or array of items (`["Item 1", "Item 2"]`) from your Bank into your backpack with automatic queue pacing.
- `isUnbanking()` *(Bool)*: Returns `true` while the unbank queue is actively processing.
- `ensureUnbanked(items)` *(Bool)*: Ensures items are out of the bank. Returns `true` once items are confirmed in inventory.
- `isInBank(itemName)` *(Bool)*: Returns `true` if the item is currently in your bank.
- `getDrop(itemName)`: Picks up a specific drop.
- `hasItem(itemName, qty? = 1)` *(Bool)*: Returns `true` if you have the required item quantity in your backpack.
- `getItemCount(itemName)` *(Int)*: Returns the current quantity of an item in your backpack.
- `ensureEquipped(itemName)`: Equips an item or class if not currently worn.

### System & Flow Control
- `log(message)`: Outputs a timestamped message to the bot log console.
- `sleep(ms)` / `wait(ms)`: Pauses `onTick()` execution for the specified milliseconds.
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
// ✅ CORRECT:
hunt("Possessed Armor", "Armor Scrap", 10);
ensureComplete(1234, stop); // Turns in the quest, THEN halts!

// ❌ WRONG:
hunt("Possessed Armor", "Armor Scrap", 10, stop); // Exits before turning in!
ensureComplete(1234);                             // Never reached!
```

---

## Drops, Inventory & Bank

### Drop Management
Always enable drop handling in `onStart()`:
```javascript
function onStart() {
    acceptAcdrops();   // Auto-accept all AC-tagged drops
    // or:
    acceptAllDrops();  // Auto-accept all drops (regular + AC)
}
```

### 🏦 The Bank Trap & Unbanking Routine (Crucial)
In AQW, if an item exists in your **Bank**, any new drops of that item will automatically be routed directly into your Bank instead of your backpack. Because quest turn-ins only check your backpack inventory, this causes the bot to farm forever!

To eliminate this problem, **always unbank your quest items in `onStart()`**:
```javascript
function onStart() {
    acceptAllDrops();
    equipLoadout("farm");

    // Unbank all quest items used across this script:
    unbank(["Bone Scrap", "Dark Core", "Broken Helm", "Fire Shard"]);

    join("shadowbattleon");
}
```

#### How `unbank([...])` works under the hood:
1. **Auto Bank Loading**: If bank data has not been retrieved from the server in this login session, it automatically sends `loadBank()` and waits for the bank list.
2. **Smart Filtering**: It checks which items from your array are actually in the bank. Items already in your inventory or not owned are safely ignored.
3. **Paced Transfer Queue**: It transfers items one by one with a safe 650ms cooldown between packets to prevent server disconnects.
4. **Combat Safety**: While unbanking is in flight (`isUnbanking == true`), `hunt()` automatically pauses combat so you never accidentally kill a monster while an unbank packet is in flight!

### 🏦 Depositing Items to Bank (`bankAll()` & `bank()`)
To quickly empty your inventory before a big farm without accidentally banking what you're wearing:

```javascript
// Test Script: Bank All Unequipped Items
function onStart() {
    log("starting bank routine");
    bankAll(); // or bankAll(["Gold Voucher 25k", "Item To Keep"]);
}

function onTick() {
    if (isBanking()) return; // Wait for paced deposit queue to finish

    log("Banking complete!");
    stop();
}

function onStop() {
    join("house");
}
```

#### How `bankAll()` protects your gear:
1. **Equipped Armor & Weapons are Protected**: The engine strictly checks `bEquip == 1`. Classes, armors, weapons, helms, capes, and pets you are currently wearing are never banked.
2. **Temporary Items Excluded**: Temporary quest drops (`bTemp == 1`) cannot be stored in the bank and are safely skipped.
3. **Queue Pacing**: Items are deposited one by one using a safe 650ms queue timer (`isBanking == true`), preventing packet flooding and server disconnects.
4. **Combat Safety**: Like unbanking, active combat routines automatically pause while banking is in flight to eliminate packet conflicts.

---

## The 6 Scripting Architectural Patterns

### Pattern 1: Minimalist Kill-Count Hunter
Hunts a target number of monsters and safely teleports to house when finished:
```javascript
function onStart() {
    log("starting routine");
    acceptAcdrops();
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
> 3. Use `acceptAcdrops()` or `acceptAllDrops()` inside `onStart()`.
> 4. For sequential multi-map quests, always guard with `if (!hunt(...)) return;` or `if (!huntQuest(...)) return;` so `onTick()` does not evaluate downstream stages early.
> 5. If the script turns in a quest before finishing, pass `stop` to `ensureComplete(questId, stop)`. Never pass `stop` to `hunt` if a quest turn-in is required.
> 6. Always include `join("house");` inside `onStop()`.
> 7. If the quest requires non-temporary items that might be stored in the Bank, always unbank them in `onStart()`: `unbank(["Item 1", "Item 2"]);`.
