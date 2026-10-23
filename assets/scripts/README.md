# AQW HScript library

This directory contains bundled HScript source. `Leveling.hxs` is the only
bundled entry script. The single file under `core/` is an include-only library
for staged hard farms and shop purchases; it is not runnable by itself.

```text
scripts/
├── Leveling.hxs         ShadowBattleon leveling: quests 9421, 9422, 9423
└── core/
    └── CoreHardFarms.hxs reusable hard-farm and shop stages
```

The API managers remain the source of truth for game access. Script cores only
compose those managers into reusable workflows.

## Current workflow layers

`core/CoreHardFarms.hxs` contains the reusable HScript functions. `Leveling.hxs`
is the current Script Manager entrypoint. New hard-farm entry scripts should
provide their own explicit recipes and use the shared staged planner.

Every helper is called again from `onTick()` while an action is pending. A
`false` result means “continue later” unless the script has recorded a fatal
condition such as a full inventory.
