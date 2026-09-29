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
- `hunt(monster, count?, callback?)`: High-level full-map hunter. Discovers the cell, jumps there, locks target, tracks kills/drops, and auto-drops combat when done.
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
- `acceptAcdrops(enabled = true)`: Automatically accepts any AdventureCoin drop and sweeps current screen drops.
- `acceptAllDrops(enabled = true)`: Automatically accepts all drops and sweeps current screen drops.
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

### The `ensure*` Workflow
```javascript
function onTick() {
    ensureMap("shadowbattleon");
    ensureQuest(1234);

    hunt("Possessed Armor", "Armor Scrap", 10);

    ensureComplete(1234);
}
```
- `ensureQuest(1234)` ensures the quest is loaded and accepted.
- `hunt(...)` tracks the required item; when inventory reaches 10, it returns `true`.
- `ensureComplete(1234)` turns in the quest and claims rewards.
- On the next tick, `Armor Scrap` is consumed, so `hunt` seamlessly starts collecting 10 more for the next turn-in!

---

## Namespaces (Optional)

If you prefer an object-oriented style, all modular managers remain available:
- `map.ensure(...)`, `map.join(...)`, `map.jump(...)`, `map.reload()`
- `combat.ensure()`, `combat.hunt(...)`, `combat.stop()`
- `quest.ensureAccept(...)`, `quest.ensureComplete(...)`
- `drop.acceptAcdrops()`, `drop.acceptAllDrops()`
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
