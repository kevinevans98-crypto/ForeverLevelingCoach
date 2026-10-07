Forever Leveling Coach v0.4.2

Current scope
-------------
WoW Forever Beta
Horde Shaman
Levels 1-30

v0.4.2 highlights
-----------------
- Quest-ID-based automatic routing foundation
- Live quest-log syncing
- Quest objective completion display
- Completed-quest checks
- 15-second backup quest sync ticker
- /flc sync
- /flc export
- Movable and resizable guide window
- Saved UI settings
- Beginner Mode
- Unknown/new quest scanner with NEW / UNVERIFIED labels
- Unknown quest history saved in SavedVariables
- /flc export includes unknown quest IDs and objectives
- Navigation arrow window foundation
- /flc arrow toggles the arrow
- Arrow uses route waypoints only when Forever-specific coordinates are verified
- Fixed unknown-quest history persistence discovered during v0.4.1 testing
- Compact current-quest-only main window
- Semi-transparent Blizzard-style frame and border
- Full quest list stays hidden from the main UI and remains available through /flc export

Important routing rule
----------------------
Forever can contain multiple quests with the same title, so route logic uses
unique quest IDs rather than quest names.

Route-data policy
-----------------
Do not invent quest IDs or coordinates. New route steps and waypoint data
should be added only after they are verified for WoW Forever.

Current verified route anchor
-----------------------------
The first automatic-routing anchor is the Horde Shaman Call of Water chain.
The route database currently includes verified quest IDs 2986, 1534, and 1536.

Roadmap
-------
- Expand the verified Horde Shaman 21-30 route first
- Add navigation arrow / waypoint destinations using verified coordinates
- Backfill levels 1-20
- Add worthwhile dungeon quest logic
- Add beginner-friendly macros
- Add gear scanning and upgrade recommendations
- Add community feedback/export tools
