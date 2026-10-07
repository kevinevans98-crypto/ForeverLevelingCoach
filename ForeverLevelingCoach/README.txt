Forever Leveling Coach v0.8.2

Current scope
-------------
WoW Forever Beta
Horde Shaman
Levels 1-30

v0.8.2 highlights
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
- Quest 220 (Call of Water) added as an IMPORTANT Water Totem-chain step after live discovery
- First verified navigation waypoint added: Islen Waterseer in The Barrens
- Smart Route Scoring chooses the best active verified quest dynamically
- Scores IMPORTANT / DO / OPTIONAL / SKIP priorities
- Boosts quests that are ready to turn in or partly complete
- Boosts current-area quest clusters and remembers the active route cluster to reduce zone hopping
- Uses verified waypoint proximity as an extra signal when available
- /flc export now shows the winning score, reasons, and all scored candidate quests
- Quest 63 (Call of Water) added as an IMPORTANT Water Totem-chain step
- Verified Silverpine waypoint added for the Brazier of Everfount
- Main guide window can now scroll with the mouse wheel when instructions are longer than the panel
- Navigation arrow now appears automatically only when the current recommended step has a verified waypoint
- Floating WoW-style navigation arrow: no extra window or background box
- Uses a native WoW minimap-arrow texture with a small target/distance label
- /flc arrow remains the master on/off toggle

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

- Silverpine Water Totem cluster improves smart routing for Call of Water [63]
- Export now hides historical unknown quests after they become classified

- Live 20 FPS-style arrow updates while moving/turning
- Compatibility-safe angle math for Classic clients
- Step-by-step travel guidance framework added
- Call of Water [63] now guides Barrens -> Orgrimmar/Durotar -> Undercity/Tirisfal -> Silverpine
- Arrow only appears when the current travel step has a verified same-map waypoint

- Floating navigation arrow now shows distance in meters/kilometers when world-position conversion is available
- Falls back to map-percent distance if the client cannot provide world coordinates

- Arrow same-map safety rule: never points across a zone/map boundary
- Removed unsafe Alterac -> Silverpine cross-zone arrow behavior after live test failure
- Alterac/Misty Shore now shows an OFF ROUTE recovery instruction until the player returns to Silverpine
- Export includes ArrowState for navigation debugging

- Corrected WoW-facing math: GetPlayerFacing is counterclockwise from north, while map Y increases south
- Switched the floating arrow to a native Blizzard up-arrow texture with a known zero-direction orientation
- Export now includes arrow heading/rotation diagnostics for live verification

- Call of Water [63] Silverpine instructions expanded with the actual terrain route: Sepulcher backside -> trees/rocks -> hidden pool -> Water Sapta -> elemental -> bracers -> Brazier

- Added live-discovered Call of Water quest IDs 96, 100, and 1103
- Quest 96 is prioritized as the Water Totem turn-in at Islen Waterseer in The Barrens
- Quest 1103 is recognized as the Water Sapta recovery step for Tiev Mordune

- Multi-step navigation engine added
- Route steps can now advance automatically using verified same-map proximity checks
- Arrow can stay intentionally hidden during unsafe terrain approaches, then activate only for the final local segment
- /flc export now reports NavigationStep=x/y

- Added a compact travel hint window that appears when the arrow is hidden because the next target is on another map or has no safe waypoint
- The hint automatically disappears when the same-map arrow becomes active again

- Travel hint window is now movable and resizable
- Travel hint size and position persist between sessions
- /flc lock also locks the travel hint window and hides its resize grip

- Travel Optimizer foundation added
- Detects Hearthstone ownership, cooldown/readiness, and bind location
- Route-specific fast-travel suggestions can prefer Hearthstone or flight paths over long rides
- Quest 96 now suggests a Ratchet flight from Orgrimmar when useful, with a Ratchet-bound ready Hearthstone taking priority
- Export includes FastTravelMode and FastTravelSuggestion

- Next Quest Pickup support added
- Route data can now name the next quest, NPC, zone, coordinates, and optional pickup waypoint
- Main guide shows the pickup separately from the current objective
- Export includes NextQuestPickup fields
- Call of Water recovery now shows Water Sapta from Islen Waterseer at 65.8, 43.8 without inventing an unknown quest ID

- Marked Person guidance added for verified quest givers and quest contacts
- Main guide now labels the person, role, zone, and coordinates
- Same-map arrow can point directly to a verified quest giver/contact
- The Glowing Shard now marks Sputtervalve in Ratchet and records Falla Sagewind as the next quest giver after the Ratchet step
