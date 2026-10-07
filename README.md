# Forever Leveling Coach

A beginner-friendly leveling assistant for **WoW Forever Beta**.

Current development focus:
- Horde Shaman
- Levels 1–30
- Quest-ID-based automatic routing
- Live quest-log syncing
- Unknown/new quest scanner
- Navigation arrow foundation using verified waypoint data only
- Compact semi-transparent Blizzard-style UI showing the current recommended quest only
- Semi-fast leveling philosophy: strong XP/hour without turning the route into a hardcore speedrun

## Install

Copy the `ForeverLevelingCoach` folder into your WoW Forever Beta addon directory:

```
World of Warcraft\_classic_beta_\Interface\AddOns\ForeverLevelingCoach
```

Then launch the game or run `/reload`.

## Commands

- `/flc`
- `/flc show`
- `/flc hide`
- `/flc sync`
- `/flc export`
- `/flc arrow`
- `/flc lock`
- `/flc unlock`
- `/flc beginner`

## Development rule

Do not invent Forever quest IDs or waypoint coordinates. Route data should be verified before being shipped.
