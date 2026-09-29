# AQW Haxe Scripting API Guide (.hxs)

Welcome to the official scripting guide for the AQW Haxe API. Scripts are written in **HScript** (`.hxs` files) — a dynamic, lightweight scripting language matching standard JavaScript/ActionScript 3 syntax that executes live inside the client.

---

## 🌟 The Default Scripting Style (Top-Level & Zero-Boilerplate)

The recommended and default style for all `.hxs` scripts is **clean, top-level natural language**. Redundant prefixes like `bot.`, `map.`, or `combat.` are unnecessary — every primary action is available directly at the top level.

### Canonical Example:
```javascript
// Test Script: Hunt 10 Possessed Armor in ShadowBattleon
function onStart() {
    log("starting routine");
    acceptACs = true;
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
4. [Combat & Hunting (`hunt`)](#combat--hunting-hunt)
5. [Quests](#quests)
6. [Drops, Inventory & Bank](#drops-inventory--bank)
7. [Player Status & Auras](#player-status--auras)
8. [Namespaces (Optional)](#namespaces-optional)
9. [End-to-End Script Templates](#end-to-end-script-templates)

---

## Script Lifecycle Hooks

Every `.hxs` script can define these standard lifecycle functions:

| Hook | When it executes | Usage |
|---|---|---|
| `onStart()` | Executed once when the script starts | Set drop filters, equip loadouts, join starting map |
| `onTick()` | Executed periodically (default: every 100ms) | Main routine (hunting, ensuring map, turning in quests) |
| `onStop()` | Executed once when the script finishes or is stopped | Final teleport (e.g. `join("house")`), cleanup, final logs |
| `onPacket(packet)` | Executed on every incoming server packet | Packet listening, triggers, packet analysis |
| `onZoneEntered(zone)`| Executed on cell or map transfers | Area triggers, specialized buffs |
| `onQuestUpdated(id)` | Executed when a quest objective updates | Quest tracking |
| `onInventoryChanged(item)`| Executed when items are added/removed | Drop notifications |

---

## Top-Level Quick Reference

### Navigation
- `join(mapName, cell?, pad?)`: Transfers to a map. `join("house")` routes directly to your house.
- `ensureMap(mapName, cell?, pad?)`: Ensures you are in the target map and cell. Automatically drops combat stealthily before transferring if you are fighting.
- `ensureCell(cell, pad?)`: Ensures you are in the specified room on the current map.
- `jump(cell, pad?)`: Jumps to a room on the current map. Defaults to `"Spawn"` on `"Enter"`, and `"Left"` on all other rooms.
- `reload()`: Drops combat in-place with **stealth coordinate retention** (breaks aggro without character warping).

### Combat
- `hunt(monster, itemOrCount?, qty?, callback?)`: High-level full-map hunter. Discovers the cell, jumps there, locks target, tracks kills or item drops (single item or array of items: `[["Item A", 10], ["Item B", 5]]`), and auto-drops combat when done.
- `huntQuest(questId, monster?, callback?)`: Automatically tracks all requirements of a quest from a monster without needing to list item names.
- `ensureCombat()`: Ensures smart combat rotations and auto-attack are active (safely idles while loading).
- `equipLoadout("farm" | "solo" | "support")`: Equips predefined class and skill rotations.
- `stopCombat()` / `endCombat()`: Stops attacking and breaks combat aggro in-place.
- `attack(monster)` / `selectTarget(monster)`: Targets a specific monster.
- `useSkill(1..4)`: Manually activates a skill.

### Quests
- `ensureQuest(id)` / `ensureAccept(id)`: Accepts the quest if not already in your active quest log.
- `ensureComplete(id, itemId?)`: Turns in the quest once all requirements are fulfilled.
- `autoQuest([ids])` / `startAutoQuests([ids])`: Runs quest acceptance and turn-in automatically in the background.
- `stopAutoQuest()`: Stops background auto-questing.

### Drops & Inventory
- `acceptACs = true;`: Automatically picks up any AdventureCoin drop.
- `acceptAll = true;`: Automatically picks up all drops.
- `acceptDrop(itemName)`: Picks up a specific drop.
- `hasItem(itemName, qty?)`: Returns `true` if you have the required item quantity in your backpack.
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
5. Pauses 600ms, then transfers to the target map cleanly.

### Normalized Room Pads
Non-`"Enter"` rooms in AQW do not have a `"Spawn"` pad. The API automatically normalizes default pads:
- Cell `"Enter"` -> defaults to `"Spawn"`
- All other cells -> default to `"Left"`
- This completely prevents the game from defaulting your avatar to the center of the canvas `(480, 275)`.

---

## Combat & Hunting (`hunt`)

The `hunt()` function is a complete autonomous farming engine:
```javascript
hunt(monsterName, itemOrCount?, callback?)
```

1. **Full-Map Discovery:** Automatically searches the map's monster definition tree (`monTree`) to find which cell the monster spawns in without needing hardcoded cell names.
2. **Multi-Mob Kill Tracking:** In rooms with multiple monsters (e.g. 2-3 Possessed Armors), each individual kill transition is tracked independently.
3. **Auto Combat Dropping:** The instant target kills or item counts are achieved, `hunt()` automatically calls `stopCombat()` to clear aggro in-place.
4. **Completion Callbacks:** Pass `stop` as the callback to automatically halt the script and trigger `onStop()`:
   ```javascript
   hunt("Possessed Armor", 10, stop);
   ```
5. **Multi-Hunt Sequencing:** Multiple `hunt()` calls in `onTick()` automatically queue sequentially:
   ```javascript
   function onTick() {
       ensureMap("shadowbattleon");
       hunt("Possessed Armor", 10);      // Runs first to 10 kills
       hunt("Bone Cruncher", 5, stop);   // Automatically waits, then runs to 5 kills and stops
   }
   ```

---

## Quests

There are two primary ways to handle quests depending on your goal:

### 1. Multi-Quest Looping Farms (`autoQuest`)
For background farming where you continuously complete and re-accept multiple quests (e.g. leveling in ShadowBattleon with quests 9421, 9422, 9423):
- Call `autoQuest([9421, 9422, 9423]);` once in `onStart()`.
- It runs in the background on an independent 800ms timer with a serialized queue (1100ms server cooldown).
- It handles pre-loading, accepting, turning in, and re-accepting with zero packet spam.
- Keeps `onTick()` completely free of quest boilerplate!

### 2. Sequential & Storyline Quests (`ensureQuest` & `ensureComplete`)
For storyline chains, one-off dailies, or specific reward selections where Quest B only unlocks after Quest A completes:
```javascript
function onTick() {
    ensureMap("shadowbattleon");
    ensureQuest(1234);

    hunt("Possessed Armor", "Armor Scrap", 10);

    ensureComplete(1234, stop);
}
```
- `ensureQuest(1234)` ensures the quest is loaded and accepted.
- `hunt(...)` tracks the required item and returns `true` once 10 are in your bag.
- `ensureComplete(1234, stop)`: **Crucial**: Notice `stop` is passed to `ensureComplete`, **not** `hunt`! If `stop` were passed to `hunt`, the script would immediately exit before the quest could turn in. Passing `stop` to `ensureComplete` ensures the turn-in packet is delivered to the server before stopping!

---

## Namespaces (Optional)

If you prefer an object-oriented style, all modular managers remain available:
- `map.ensure(...)`, `map.join(...)`, `map.jump(...)`, `map.reload()`
- `combat.ensure()`, `combat.hunt(...)`, `combat.stop()`
- `quest.ensureAccept(...)`, `quest.ensureComplete(...)`
- `drop.acceptACs = true`, `drop.acceptAll = true`
- `player.hp`, `player.mp`, `player.isInCombat`, `player.hasAura(...)`

Both top-level shortcuts and namespaced methods execute the exact same underlying logic.

---

## End-to-End Script Templates

### 1. Minimalist Kill-Count Hunter
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

### 2. Multi-Monster Sequential Hunter
```javascript
function onStart() {
    acceptAcdrops();
    equipLoadout("farm");
    join("shadowbattleon");
}

function onTick() {
    ensureMap("shadowbattleon");
    hunt("Possessed Armor", 10);
    hunt("Bone Cruncher", 5, stop);
}

function onStop() {
    log("Routine completed.");
    join("house");
}
```

### 3. Background Auto-Quest Leveling
```javascript
function onStart() {
    log("Starting auto-leveling...");
    acceptAllDrops();
    equipLoadout("farm");
    join("shadowbattleon", "Enter", "Spawn");
    autoQuest([9421, 9422, 9423]);
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

### 4. Multi-Quest Saga / Complex Chain (10+ Quests & Mobs)
```javascript
// Data-driven task table: 10 quests, 10 maps, 10 mobs, multiple items
var tasks = [
    { map: "shadowbattleon", quest: 9421, mob: "Possessed Armor", items: [["Bone Scrap", 10], ["Dark Core", 5]] },
    { map: "infernalarena",  quest: 9422, mob: "Infernal Knight", items: [["Fire Shard", 10], ["Ash Ore", 3]] },
    { map: "iceplane",       quest: 9423, mob: "Frost Giant",     items: [["Ice Shard", 10]] }
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

            // Option A: Pass items array directly to hunt
            hunt(t.mob, t.items);

            // Option B: Or use huntQuest to auto-track all quest items
            // huntQuest(t.quest, t.mob);

            ensureComplete(t.quest);
            return; // Stay on current task until finished!
        }
    }

    // All quests completed
    stop();
}

function onStop() {
    log("All quests finished!");
    join("house");
}
```
