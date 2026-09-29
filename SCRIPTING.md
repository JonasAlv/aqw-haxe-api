# AQW Haxe Scripting API Guide (.hxs)

Welcome to the official scripting documentation for the AQW Haxe API. Scripts are written in **HScript** (`.hxs` files) — a fast, lightweight, and sandbox-safe scripting language matching JavaScript/ActionScript 3 syntax.

---

## Table of Contents
1. [Core Philosophy: Zero-Boilerplate](#core-philosophy-zero-boilerplate)
2. [Script Lifecycle Hooks](#script-lifecycle-hooks)
3. [Namespaces & Syntax Flavors](#namespaces--syntax-flavors)
4. [Map & Navigation (`map`)](#map--navigation-map)
5. [Combat & Hunting (`combat`)](#combat--hunting-combat)
6. [Quests (`quest`)](#quests-quest)
7. [Inventory, Drops & Bank](#inventory-drops--bank)
8. [Player Status & Auras (`player`)](#player-status--auras-player)
9. [Utility & Flow Control](#utility--flow-control)
10. [End-to-End Examples](#end-to-end-examples)

---

## Core Philosophy: Zero-Boilerplate

Scripts are designed to read like natural language. The engine internally handles aggro drops, in-combat safety, coordinate preservation, cell discovery, and multi-task sequencing.

### Before vs. After
```javascript
// ❌ Old boilerplate style:
function onTick() {
    if (!bot.isMap("shadowbattleon")) {
        bot.ensureMap("shadowbattleon");
        return;
    }
    if (!bot.hunt("Possessed Armor", 10)) {
        return;
    }
    bot.stop();
}

// ✅ Modern Zero-Boilerplate style:
function onTick() {
    map.ensure("shadowbattleon");
    hunt("Possessed Armor", 10, stop);
}
```

---

## Script Lifecycle Hooks

Every `.hxs` script can implement any of these standard entry points:

| Hook | When it executes | Common Usage |
|---|---|---|
| `onStart()` | Executed once when the script starts | Set configurations, equip classes, join initial map |
| `onTick()` | Executed periodically (default: every 100ms) | Main bot loop (hunting, turning in quests, movement) |
| `onStop()` | Executed once when the script stops | Cleanup, final logs, state notifications |
| `onPacket(packet)` | Executed on every incoming server packet | Packet listening, packet logging, triggers |
| `onZoneEntered(zone)`| Executed on cell or map transfers | Area triggers, specialized buffs |
| `onQuestUpdated(id)` | Executed when a quest objective updates | Quest tracking |
| `onInventoryChanged(item)`| Executed when items are added/removed | Drop notifications |

---

## Namespaces & Syntax Flavors

You can write your scripts in whatever style you find most readable:

1. **Natural / Flat Style:** Direct global functions (`ensureMap("battleon")`, `hunt("Frogzard", 5)`, `stop()`).
2. **Object-Oriented Style:** Modular namespaces (`map.ensure("battleon")`, `combat.hunt("Frogzard", 5)`).
3. **Bot Prefix Style:** Explicit client root (`bot.map.ensure("battleon")`, `bot.combat.hunt("Frogzard", 5)`).

All three styles execute identically and can be mixed freely.

---

## Map & Navigation (`map`)

The `map` manager handles map transfers, cell jumps, coordinate retention, and room reloads.

### Methods & Properties
- `map.ensure(mapName, cell?, pad?)` *(returns Bool)*:
  - If you are not in the target map, it automatically drops combat in-place, pauses the script, and transfers you there.
  - Automatically defaults pads to `"Spawn"` on `"Enter"`, and `"Left"` on all other rooms (no more warping to the center of the screen).
  - Returns `true` only when the map is fully loaded and you are in the target cell.
- `map.join(mapName, cell?, pad?)`: Direct map transfer. Automatically drops combat if fighting before sending the transfer packet.
- `map.jump(cell, pad?)`: Jumps to a cell on the current map.
- `map.reload(pad?)`: **Stealth Drop Combat**. Reloads the current cell while preserving the player's exact `(x, y)` coordinates, dropping server aggro without your character visibly teleporting across the screen.
- `map.ensureCell(cell, pad?)`: Ensures you are in a specific cell on the current map.
- `map.isMap(mapName)` *(Bool)*: Returns whether you are on the specified map.
- `map.isCell(cellName)` *(Bool)*: Returns whether you are in the specified cell.
- `map.isLoaded` *(Bool)*: Returns whether the current map is fully loaded and ready for interaction.
- `map.getMapCells()` *(Array<String>)*: Returns all cell names on the current map.
- `map.getCellPads()` *(Array<String>)*: Returns all door and spawn pads on the current frame.
- `map.usePrivateRoom = true`: Automatically appends a private room number (`-100000+`).

---

## Combat & Hunting (`combat`)

The `combat` manager automates targeting, skill rotations, loadouts, and cross-map monster farming.

### The Universal `hunt()` Method
`hunt(monsterName, itemOrCount?, quantityOrCallback?, mmidOrCallback?, onComplete?)`

`hunt()` is a full-featured automated hunter:
1. Automatically queries the map's monster definition tree (`monTree` / `mondef`) to discover which cell the monster spawns in.
2. Automatically jumps to that cell using the correct pad.
3. Locks combat targeting to that monster name (or MMID).
4. Tracks individual kills even in rooms with multiple monsters using per-monster alive-state transitions.
5. **Auto Combat Drop:** Once the goal is reached, it automatically calls `stopCombat()` to clear aggro in-place.
6. **Auto Multi-Task Sequencing:** Multiple `hunt()` lines in `onTick()` automatically queue sequentially without needing `if (!...) return;`.

#### Usage Examples:
```javascript
// 1. Kill count with stop callback:
hunt("Possessed Armor", 10, stop);

// 2. Kill count with custom lambda callback:
hunt("Possessed Armor", 10, function() {
    log("Possessed Armor hunt completed!");
    map.jump("Enter");
});

// 3. Item drop hunting:
hunt("Possessed Armor", "Shadow Core", 5, stop);

// 4. Sequential hunting (Zero Boilerplate):
hunt("Possessed Armor", 10);      // Runs first until 10 kills
hunt("Bone Cruncher", 5, stop);   // Automatically waits, then runs until 5 kills and stops
```

### Other Combat Methods
- `combat.ensure()`: Starts auto-combat if not already running (safely idles while map loads).
- `combat.stopAttack()`: Stops auto-attack and skill rotations without reloading the room.
- `combat.dropCombat()`: Cancels target, cancels auto-attack, and reloads cell in-place to break aggro.
- `combat.stopCombat()` / `combat.stop()`: Stops attack AND drops combat aggro.
- `combat.equipLoadout("farm" | "solo" | "support")`: Equips predefined skill rotations and classes.
- `combat.useSkill(1..4)`: Manually activates a skill (bypasses range limitations).
- `combat.selectTarget(name)` / `attack(name)`: Targets a specific monster.
- `resetHunt()`: Resets all active and completed hunt tracking states.

---

## Quests (`quest`)

The `quest` manager manages quest loading, accepting, turning in, and auto-progression.

### Methods
- `quest.ensureAccept(questId)`: Accepts the quest if not already accepted.
- `quest.ensureComplete(questId, itemId?)`: Turns in the quest once all requirements are met.
- `quest.load(questId)`: Loads quest definitions from the server.
- `quest.has(questId)` *(Bool)*: Returns whether the quest is in the active quest log.
- `quest.canComplete(questId)` *(Bool)*: Returns whether all turn-in items and requirements are fulfilled.
- `quest.startAuto([questIds])`: Automatically accepts and turns in the specified quest IDs in the background.
- `quest.stopAuto()`: Halts auto-questing.

---

## Inventory, Drops & Bank

### Drops (`drop`)
- `drop.accept(itemName)`: Picks up a dropped item from the screen.
- `drop.acceptACs = true`: Automatically picks up any drop worth AdventureCoins.
- `drop.startAuto([itemNames])`: Automatically picks up specific drops on arrival.

### Inventory (`inventory`)
- `inventory.hasItem(itemName, qty = 1)` *(Bool)*: Returns whether you have the item and amount in your backpack.
- `inventory.getQuantity(itemName)` *(Int)*: Returns the current quantity of the item.
- `inventory.equip(itemName)`: Equips an inventory item or class.

### Bank (`bank`)
- `bank.open()`: Opens the bank.
- `bank.toInventory(itemName)`: Withdraws an item to your backpack.
- `bank.toBank(itemName)`: Deposits an item to your bank.

---

## Player Status & Auras (`player`)

- `player.hp` / `player.maxHp`: Current and maximum hit points.
- `player.mp` / `player.maxMp`: Current and maximum mana points.
- `player.level`: Current character level.
- `player.cell` / `player.pad`: Current room and pad.
- `player.x` / `player.y`: Exact avatar stage coordinates.
- `player.isAlive` *(Bool)*: Character alive status.
- `player.isInCombat` *(Bool)*: True if character is in combat or has active combat state.
- `player.className` *(String)*: Name of currently equipped class.
- `player.hasAura(auraName)` *(Bool)*: Checks if you currently have a specific buff/debuff.
- `player.getAuraStacks(auraName)` *(Float)*: Returns the stack count of an active aura.
- `player.getAuraRemaining(auraName)` *(Float)*: Returns seconds remaining on an aura.
- `player.rest()`: Initiates player resting to regenerate HP/MP.

---

## Utility & Flow Control

- `log(message)`: Outputs a timestamped message to the bot log console.
- `sleep(ms)`: Pauses execution of `onTick()` for the specified duration in milliseconds.
- `stop()`: Halts the script, stops combat, and stealthily drops aggro.
- `sendPacket(packet)`: Sends a raw string packet to the server (e.g. `"%xt%zm%...%"`).

---

## End-to-End Examples

### 1. Minimalist Kill-Count Hunter (Zero Boilerplate)
```javascript
// Hunt 10 Possessed Armor and stop
function onStart() {
    log("Starting Hunt Test...");
    drop.acceptACs = true;
    combat.equipLoadout("farm");
    map.join("shadowbattleon");
}

function onTick() {
    map.ensure("shadowbattleon");
    hunt("Possessed Armor", 10, stop);
}

function onStop() {
    log("Hunt Test finished!");
}
```

### 2. Multi-Monster Sequential Hunter
```javascript
// Hunts 10 Possessed Armor, then 5 Bone Crunchers, then stops
function onStart() {
    combat.equipLoadout("farm");
}

function onTick() {
    map.ensure("shadowbattleon");

    // Automatically executes in order:
    hunt("Possessed Armor", 10);
    hunt("Bone Cruncher", 5, stop);
}
```

### 3. Infinite Quest Farming Loop
```javascript
// Repeatedly completes quest 1234
function onStart() {
    combat.equipLoadout("farm");
    drop.startAuto(["Shadow Core"]);
}

function onTick() {
    map.ensure("shadowbattleon");
    quest.ensureAccept(1234);

    // Farms 5 Shadow Cores; automatically continues to turnIn when collected
    hunt("Possessed Armor", "Shadow Core", 5);

    quest.ensureComplete(1234);
}
```
