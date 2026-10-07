Forever Leveling Coach v0.13.3

Current scope
-------------
WoW Forever Beta
Horde Shaman
Levels 1-30

v0.13.3 highlights
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

- Fixed Travel Optimizer refresh bug: suggestions are now recalculated whenever the route renders
- Fast travel advice now appears in the main guide as well as the travel hint window
- Orgrimmar -> Ratchet flight advice now covers Call of Water 96/1103 and The Glowing Shard 6981

- Fixed completed Glowing Shard routing: once Sputtervalve is done, fast-travel guidance now targets Falla Sagewind instead of the stale Ratchet contact
- When already near the Wailing Caverns mountain, FLC tells you to follow the local arrow instead of taking a flight
- Live-discovered quest 1483 (Ziz Fizziks) is now recognized as known

- Quest-person guidance now includes Location type, Location note, and How to get there
- Falla Sagewind is explicitly marked OUTSIDE on top of the Wailing Caverns mountain, NOT inside the dungeon
- Sputtervalve is explicitly marked beside the Ratchet flight master and may lack a normal quest marker

- Live-discovered Quest 3369 (In Nightmares) is now known and routed as a completed Thunder Bluff turn-in
- Hamuul Runetotem is labeled as the turn-in person on Elder Rise
- Barrens -> Thunder Bluff guidance now explicitly recommends using the flight path when available, with a ground-route fallback
- No unverified Hamuul coordinates were invented; the addon gives city/landmark instructions until we verify a precise waypoint

- GPS-style compact main window: GO TO / WHERE / FASTEST / DO
- Removed long notes, scoring details, and route explanations from the normal play window
- Detailed diagnostics remain available in /flc export for testing
- Travel hint spacing shortened so directions are quicker to read while moving

- Flight-path learning: opening a flight master records flight destinations currently available to the character
- Route steps can declare a flight destination such as Ratchet or Thunder Bluff
- When the target is reachable at the open flight master, FLC attempts to select that flight automatically
- If the WoW client blocks automated taxi selection, FLC falls back safely and tells you to click the matching destination
- /flc autoflight toggles automatic flight selection
- /flc export now shows AutoFlightTarget, AutoFlightStatus, CurrentFlightOptions, and learned KnownFlightPaths

- Fixed stale AutoFlightTarget values after the recommended route changes
- Ashenvale route quests now target Splintertree Post as the preferred flight destination
- At a flight master, FLC can now detect Splintertree Post as reachable and attempt to select it automatically
- Live-discovered quest IDs 914 (Leaders of the Fang) and 1490 (Nara Wildmane) are now recognized as known

- Leaders of the Fang [914] is now a routed Wailing Caverns dungeon quest
- Dungeon quests can now compete with zone quests instead of being ignored just because they are newly discovered
- Leaders of the Fang is labeled DUNGEON — inside Wailing Caverns with a short one-run objective note

- Dungeon entrance waypoint added for Wailing Caverns at the classic/Forever cave entrance around 46.0, 36.0
- Wailing Caverns no longer gets the full current-area bonus merely because the player is somewhere in The Barrens
- Entrance proximity now helps score the dungeon while outside; being inside Wailing Caverns gives the full area bonus
- Dungeon mode keeps the GPS UI short by showing only the next unfinished dungeon objective
- Leaders of the Fang can use Ratchet as its preferred flight destination when approaching from another zone
- Wailing Caverns travel guidance distinguishes the outside cave entrance from the dungeon portal inside

- Inside-dungeon cleanup: once inside Wailing Caverns, FLC clears the outside cave waypoint, Ratchet taxi target, and entrance instructions
- Dungeon GPS now uses GO TO for the next unfinished objective and keeps the travel hint hidden while already inside

- Gear Advisor added: hover equippable loot, bag items, or quest rewards for a quick FLC upgrade verdict
- Labels: MAJOR UPGRADE, UPGRADE, SMALL UPGRADE, KEEP CURRENT ITEM, or NOT USABLE YET
- Uses a leveling-focused Shaman stat heuristic and heavily weights weapon DPS when the client exposes damage/speed on the tooltip
- Rings/trinkets compare against the weaker equipped slot
- /flc gear toggles Gear Advisor on/off
- This is intentionally labeled a leveling estimate rather than a perfect endgame simulator

- Fixed Gear Advisor tooltip hook crash on the Forever Beta client
- Uses TooltipDataProcessor for item tooltips when available instead of blindly hooking OnTooltipSetItem
- Export now self-initializes saved settings if addon startup was interrupted, preventing DB nil errors
- Hidden comparison tooltip is excluded from Gear Advisor processing

- Fixed ShoppingTooltip crash in Gear Advisor on Forever Beta
- Gear Advisor now ignores comparison shopping tooltips that do not expose GetItem(), while still annotating the primary hovered-item tooltip
- Tooltip post-callback now accepts tooltip data as a safe fallback for item links

- Removed misleading Gear Advisor percentage estimates
- Tooltips now use simple action text: Equip this / Better for leveling / Small improvement / Keep current item
- Gear Advisor stays focused on fast decisions instead of fake precision

- Fixed stale AutoFlightTarget export while inside a dungeon; it now correctly reports none when taxi routing is disabled by dungeon mode

- Gear Advisor now checks whether the character can actually use the item before scoring it
- Weapon/armor proficiency and class restrictions can no longer be labeled as upgrades when the game reports the item unusable
- Added FLC: CANNOT USE verdict with red-tooltip fallback for Forever Beta restrictions

- Gear Advisor now shows a percentage-based verdict instead of MAJOR/SMALL upgrade labels
- Example: FLC: +12% better for leveling or FLC: -8% worse for leveling
- Percentage is normalized against the stronger of the two item scores so it stays bounded and avoids exaggerated 200%+ results
- Unusable and level-locked items still show CANNOT USE / NOT USABLE YET instead of a percentage

- Clickable quest focus added: click the current quest title or the new Go button to track/open the recommended quest in Blizzard UI when the client supports it
- /flc go provides the same action
- Feature-detects quest APIs so unsupported Forever clients fail safely instead of throwing Lua errors

- Objective-aware GPS routing added for multi-objective quests
- The Warsong Reports now targets unfinished report NPCs individually with verified Ashenvale waypoints
- While in Ashenvale, FLC prefers the closest unfinished report contact rather than blindly following quest-log objective order
- Warsong Scout: ~71.1,68.4; Warsong Outrider patrol road: ~84,50; Warsong Runner: ~12.2,34.2
- Arrow and GO TO / WHERE / DO lines update automatically as each report is completed

- Lazy Mode is now enabled by default for short play sessions
- Main panel is reduced to the immediate NEXT / GO TO / DO decision instead of route explanations
- Cross-zone navigation no longer leaves the player with a dead arrow: when in Orgrimmar and the route needs a known flight destination, FLC points locally to the flight master first
- After reaching the flight master, existing AutoFlight can attempt to choose the route destination
- Orgrimmar flight-master local step uses the classic Doras location around 45,64
- /flc lazy toggles Lazy Mode
- Export now reports LazyModeEnabled and LazyTravelTarget

- Auto Accept / Auto Turn-In added for Lazy Mode
- Routed IMPORTANT / DO / OPTIONAL quests are auto-accepted; SKIP and unknown quests are left alone
- Completed routed quests auto-progress and auto-turn-in when there is no reward choice
- Reward-choice quests stop safely so FLC never guesses which reward to take
- /flc autoaccept toggles automatic quest acceptance
- /flc autoturnin toggles automatic quest completion/turn-in
- Export reports AutoAcceptEnabled and AutoTurnInEnabled

- Warsong Supplies [6571] is now recognized from the live Forever quest log
- Classified OPTIONAL because the full quest includes a long multi-zone detour
- Added local Lazy Mode targets for Warsong Oil, Logging Rope, and Pixel / Warsong Saw Blades
- Fixed stale Splintertree AutoFlightTarget once the active objective is already on the player's current map

- Class Trainer routing added for Horde Shaman
- FLC now treats every even level from 4 onward as a Shaman training checkpoint until the trainer confirms no trainable abilities remain
- When training is due, Lazy Mode temporarily prioritizes TRAIN SHAMAN over normal questing
- Nearest trainer routing prefers Orgrimmar for Ashenvale/Durotar/Barrens routes and Thunder Bluff for Mulgore/Stonetalon routes
- Orgrimmar trainers: Kardris Dreamseeker / Sagorne Creststrider / Sian'tsu in Valley of Wisdom around 38.9,36.4
- Thunder Bluff trainers: Beram / Siln / Tigor Skychaser on Spirit Rise around 22.0,18.8
- Ashenvale training travel uses the Splintertree Post flight master handoff, then AutoFlight targets Orgrimmar
- TRAINER_SHOW/TRAINER_UPDATE scanning keeps the reminder active until no trainable services remain
- /flc trained manually clears the current-level training reminder if the Forever trainer API cannot verify it
- Export reports ClassTrainingDue, ClassTrainerTarget, LastClassTrainerLevel, and TrainerAvailableCount

- Training reminders no longer yank you out of a strong field route; FLC shows SOON: Train Shaman while questing and hard-prioritizes training once you reach a trainer city or the current route is weak
- Added live-discovered Ashenvale quests 6442, 6641, 216, 6462, 6563, and 6921 to the known database
- Added Zoram Strand and Thistlefur quest clusters so nearby objectives can be stacked instead of ignored
- Naga at the Zoram Strand, Between a Rock and a Thistlefur, and Troll Charm now have local GPS targets
- Vorsha the Lasher is OPTIONAL because it is an elite escort/event and may cost time while solo
- Blackfathom Deeps quests The Essence of Aku'Mai and Amongst the Ruins are recognized as OPTIONAL dungeon work for a future BFD run

- Completed Warsong Reports now routes back to Kadrak at 48.1,5.4 in northern The Barrens instead of leaving the arrow blank
- Completed route steps can now declare a dedicated turnInTarget and turnInFlightTarget
- At Zoram'gar, cross-zone turn-ins can hand off locally to the Zoram'gar flight master rather than pointing blindly across maps
- Warsong Reports completion prefers a flight toward Crossroads, then a local Barrens arrow to Kadrak

- Level 22 training false-positive fixed from live Forever Beta verification
- The Shaman What's Training panel shows 0 available at level 22 and the next ranks at level 24
- For the current 22-30 route, class-training reminders now begin at level 24 and then check even levels
