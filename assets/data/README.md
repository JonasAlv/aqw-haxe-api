# Bundled API data

This directory contains read-only defaults embedded into the API build:

- `skills.json` — default class skill profiles and combat modes.
- `userSkills.json` — initial user-editable skill profile seed.
- `enhancements.json` — default enhancement definitions.
- `item_presets.json` — default item/loadout presets.

The runtime still exposes the same logical filenames to managers and users.
User-edited copies continue to live in API storage as `userSkills.json`,
`userEnhancements.json`, and `item_presets.json`; this folder is only for
bundled build-time defaults.
