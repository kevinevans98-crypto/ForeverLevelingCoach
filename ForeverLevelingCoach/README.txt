Forever Leveling Coach v0.4.5

Current scope
-------------
WoW Forever Beta
Horde Shaman
Levels 1-30

v0.4.5 highlights
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
- Live level-21 quest classifications added for Ashenvale, Stonetalon, Wailing Caverns follow-ups, and Warsong Reports
- These newly classified entries use verified quest IDs from the player's Forever quest log; no invented coordinates were added
- Area quest clustering: stacks multiple active quests in the same zone instead of bouncing between areas
- Current-zone clusters are preferred automatically
- If the current zone is unknown, the cluster with the most useful active work is preferred
- IMPORTANT class/unlock quests still override normal area clusters
- Main window stays clean: it shows only the current quest plus a short "Area stack" count
- Export button added directly to the main guide window for one-click /flc export access

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
