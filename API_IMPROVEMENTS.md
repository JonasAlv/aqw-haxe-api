# State, action results, and script diagnostics

These additions are backward compatible with existing HScript scripts.

## Check state availability and freshness

`stateHealth.get(domain, staleAfterMs)` returns a record with `available`, `status`, `ageMs`, and `lastUpdatedAt`. Supported domains are `player`, `target`, `auras`, `inventory`, `quests`, and `map`.

```haxe
var health = stateHealth.get("inventory", 15000);
if (health.status == "fresh") {
    // Inventory has emitted an update within the last 15 seconds.
} else if (health.status == "unavailable") {
    // The live game data needed for this read is not present.
}
```

`unknown` means the API has not observed an update event yet. `stale` means the last observed update is older than the requested threshold. This is an event-age signal, not a guarantee that the server has changed or not changed the data. Existing aura methods already expose `player.getAuraRemaining(name)` and `aura.getRemaining(name, target)` in seconds.

## Wait for action confirmation

The new callback methods return an `ActionResult` record containing `operation`, `status`, `success`, `message`, and `elapsedMs`. Status is `success`, `timeout`, or `failed`.

```haxe
inventory.equipWithResult("My Class", function(result) {
    if (!result.success) warn(result.message);
});

quests.acceptWithResult(1234, function(result) {
    if (result.status == "timeout") warn("Quest acceptance was not confirmed.");
});

quests.completeWithResult(1234, -1, function(result) {
    if (result.success) log("Quest completion confirmed.");
});

map.joinWithResult("battleon", "Enter", "Spawn", function(result) {
    if (result.success) log("Map arrival confirmed.");
}, 30000);

map.jumpWithResult("r1", "Left", function(result) {
    if (!result.success) warn(result.message);
});
```

The older fire-and-forget methods remain available. Confirmation is based on the client state exposed by the game.

## Script and rotation diagnostics

HScript runtime logs now include the active script name when available, the callback that failed, a stack trace where the runtime exposes one, and a line number where supplied by the runtime. Parser errors retain their line number. Skill DSL errors now identify source lines and sections or combo token positions; unknown and malformed settings are surfaced instead of silently ignored.

Run `tests/run-regression-checks.sh` for the runtime-independent parser and action-result checks. The normal `haxe build.hxml` build also checks the Flash-target API code.
