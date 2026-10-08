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
- Area quest clustering so nearby objectives are stacked before leaving a zone
- One-click Export button in the main addon window
- Verified navigation waypoint support now active for discovered route steps
- Adaptive Smart Route Scoring with explainable recommendation reasons
- Scrollable main guide window
- Navigation arrow auto-shows only for verified current-step waypoints
- Floating WoW-style navigation arrow with no background window
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

- Silverpine Water Totem cluster improves smart routing for Call of Water [63]
- Export cleanup hides historical unknowns once they are classified

- Step-by-step travel guidance with zone-aware instructions
- Live floating arrow updates while moving and turning

- Arrow distance display uses meters/kilometers when world-position conversion is available

- Navigation arrow uses same-map safety so unverified cross-zone math cannot misroute the player

- Corrected arrow heading math and added live rotation diagnostics

- Added terrain-aware quest instructions for tricky objectives like Call of Water [63]

- Added verified live Call of Water steps 96, 100, and 1103 so the class chain remains prioritized after the Silverpine cleanse

- Multi-step waypoint routing foundation: staged instructions, proximity-based advancement, and safer terrain-aware arrow activation

- Added a compact travel hint window for cross-zone travel when the arrow is intentionally hidden

- Added a movable and resizable travel hint window with saved position and size

- Travel Optimizer foundation: Hearthstone readiness/bind awareness plus route-specific flight-path shortcuts

- Next Quest Pickup guidance: shows the next quest name, giver, zone, coordinates, and optional arrow target

- Marked Person guidance for verified quest givers/contacts, with same-map arrow targeting and next-chain pickup data

- Travel Optimizer refresh fix: active routes now surface flight-path shortcuts in the main guide

- Fixed stale Sputtervalve guidance after The Glowing Shard completes; next-pickup routing now follows Falla Sagewind

- Added terrain/context guidance for quest people: outside vs dungeon, landmark notes, and approach instructions

- Added live-verified Quest 3369 (In Nightmares) with Hamuul Runetotem / Elder Rise turn-in guidance and flight-path-first travel instructions

- GPS-style compact play UI: GO TO / WHERE / FASTEST / DO, while verbose diagnostics stay in exports

- Flight-path learning and route-aware taxi selection: FLC records usable destinations at flight masters and can attempt to choose the route target automatically

- Ashenvale routes now use Splintertree Post as the preferred flight destination and stale taxi targets are cleared on route changes

- Added Leaders of the Fang [914] to the Wailing Caverns dungeon route so it competes against Ashenvale recommendations instead of being ignored

- Dungeon route mode: entrance waypoints, proximity-aware scoring, short next-objective guidance, and Wailing Caverns cave-vs-instance instructions

- Inside-dungeon cleanup: no stale entrance waypoint or taxi target once the player is already inside Wailing Caverns

- Gear Advisor: hover equippable items for a simple Shaman leveling verdict instead of manually comparing every stat

- Fixed Gear Advisor tooltip compatibility on Forever Beta and hardened export initialization

- Fixed Gear Advisor ShoppingTooltip crash on Forever Beta; comparison tooltips are now safely ignored

- Removed misleading Gear Advisor percentages; upgrade tooltips now use simple action-oriented verdicts

- Fixed stale AutoFlightTarget export while inside a dungeon

- Gear Advisor now rejects unusable items before scoring, preventing false MAJOR UPGRADE labels on gear the character cannot equip

- Added percentage-based Gear Advisor verdicts with bounded estimates instead of major/small upgrade labels

- Clickable quest focus: click the current route title or Go button to super-track/open the recommended quest when supported

- Objective-aware GPS routing for The Warsong Reports, including closest unfinished contact selection and verified Ashenvale waypoints

- Lazy Mode: minimal NEXT / GO TO / DO UI for short play sessions, plus local travel handoffs instead of unsafe cross-zone arrows

- Auto Accept / Auto Turn-In for routed quests, with reward-choice safety so the addon never guesses a reward

- Added Warsong Supplies [6571] as an OPTIONAL live-verified quest with local Ashenvale objective guidance
- Clears stale flight targets after reaching the active objective map

- Class Trainer routing: Lazy Mode now tells Horde Shamans when training is due and routes to the nearest practical Shaman trainer

- Training reminders no longer interrupt strong field routes; added live Ashenvale/Zoram/Thistlefur quest coverage and BFD quest recognition

- Level 22 Shaman training false-positive fixed; current 22-30 reminders begin at level 24 from live Forever Beta data

- Smart Flight Assist: flight routes are detected and suggested, but FLC never auto-clicks a taxi destination

- Splintertree local flight handoff and turn-in flight-target persistence fix

- Relic Advisor and 2H Axe / 2H Mace weapon preference filtering for the Horde Shaman route

- Fixed Relic Advisor render crash from function declaration order

- Shadowfang Keep dungeon awareness and generic inside-dungeon routing priority

- Rogue character profile support with per-character state isolation and class-aware gear/relic logic

- Rogue route started with The Mindless Ones [364] and class-specific route filtering

- Ultra-clean Lazy window: quest/task + one immediate action; arrow handles location

- Undead Rogue fastest-route foundation, expanded verified Tirisfal quest data, and Rogue-specific gear validation

- Nearby quest cluster line in Lazy Mode shows other active quests in the same local area
