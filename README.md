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

- Added A Light in the Darkness [98389], Marla's Last Wish item-aware routing, and Night Web's Hollow clustering

- Cluster quests now render as normal quest blocks in the scrollable Lazy window; no NEARBY label or 3-quest cap

- Step-by-step Lazy guide with STEP 1 owning the arrow and later clustered quests queued below it

- Improved same-cave ordering for Deathknell Rogue route and exact Night Web kill counts

- Rogue talent/spec advisor with a level-by-level Combat 10-30 leveling path ending in Blade Flurry

- Added The Scarlet Crusade [381] route so local proximity can beat farther Deathknell objectives

- Added per-spec Rogue talent guides with switchable Combat, Assassination, and Subtlety community-recommended builds

- Added The Red Messenger [382] and Vital Intelligence [383] to bridge Deathknell into Brill

- Added Undead Forever camping chain The Adventurer [96656] / The Great Outdoors [96607], with Sticks and Bones [86784] optional

- Added Fields of Grief [365]/[407], A Rogue's Deal [8] routing, and local-objective-before-hub turn-in deferral

- Added Gordo's Task [5481] and integrated it into the Deathknell-to-Brill no-backtracking route

- SFK completed-quest exit fix and verified Book of Ur / Arugal turn-in routing

- Added turn-in proximity scoring so local completed quest hand-ins beat farther/cross-map turn-ins

- Added talent build export with per-tree point totals and detailed invested talent ranks

- Added WoW Forever 1.60.1 SharedTraits fallback for talent build export

- Added speed-first Shaman 23-30 routing, Lost Pages [6504], stale-quest XP penalties, and better Ashenvale objective guidance

- SKIP route classification is now a hard exclusion: skipped quests cannot become STEP 1 or inflate nearby-cluster scoring

- v0.19.0: Added a verified Undead Rogue Silverpine 10–20 route package to reduce fallback-only leveling.

- Added Forever-exclusive Wild Eyes [91920] and Watching the Roads [95981] to automatic routing.

- Added verified Return to Podrig, Wild Hearts/Return to Quinn, Prove Your Worth, Arugal's Folly, Dalaran investigation, and Recipe for Death classifications.

- Elite/escort Silverpine steps are classified conservatively as OPTIONAL when they can hurt solo XP/hour.

- v0.20.0: Added a verified universal Horde Shaman 10–20 Barrens/Stonetalon route package.

- Added Barrens Oases [886], Disrupt the Attacks [871], Raptor Thieves [869], Centaur Bracers [855], and Samophlange [894] to Shaman automatic routing.

- Added The Spirits of Stonetalon [1061], Boulderslide Ravine [6421], Blood Feeders [6461], and Report to Kadrak [6542] as the Shaman bridge into the existing Ashenvale route.

- Shaman levels 1–10 remain intentionally race-specific; a later race-aware router will cover Orc/Troll, Tauren, and Skyborne starter zones without mixing incompatible quest paths.

- v0.21.0: Added race-aware Horde Shaman starter routing.

- Orc/Troll Shamans now use verified Durotar starter quests; Tauren Shamans use verified Mulgore starter quests.

- Added race filtering to the route engine so starter quests from the wrong race can never win scoring.

- Skyborne Shamans now receive Zephras Isle-specific level 1-12 fallback guidance without fabricated quest IDs.

- v0.21.1: Added background-quest routing so incidental quests cannot get FLC stuck on STEP 1.

- Background quests never own STEP 1, the navigation arrow, or the Go button; they remain visible in the local quest queue.

- The Lost Pages [6504] is now a background quest and is prioritized as STEP 2 while a real Thistlefur objective drives navigation.

- v0.21.2: Background quests are explicitly labeled in exports and the Lazy Mode queue.

- Thistlefur routing now finishes incomplete real local objectives before sending the player away for completed quest turn-ins.

- Queue ordering is now: STEP 1 primary navigation, STEP 2 while-questing background objective, remaining primary objectives, then deferred completed turn-ins.

- v0.22.0: Added GPS-style dynamic local quest ordering.

- Route proximity scoring now uses the closest verified unfinished objective waypoint, not only a quest's top-level waypoint.

- Remaining primary quests in the Lazy Mode queue are sorted by live score, so movement and objective progress can reorder the route.

- Added a small route-switch margin to prevent the recommended quest from flickering between near-equal candidates.

- v0.22.1: Added numeric objective-progress scoring.

- FLC now parses progress such as 6/12 or 1/4 and averages it with completed objectives instead of only counting fully finished objective lines.

- Route reasons now show the calculated quest progress percentage, making near-complete quests easier to understand in exports.

- v0.23.0: Added the first full equipped-gear weakness scanner.

- `/flc gearscan` ranks weak, outdated, and expected-but-empty slots, with extra priority for an outdated weapon.

- `/flc export` now includes GearTopPriority, GearScan priorities, and a complete equipped-slot status snapshot.

- Gear scan is intentionally conservative: it identifies upgrade needs from the player's actual equipment and level without inventing unverified Forever item sources.

- v0.23.1: Added an in-window Gear Scanner view.

- The main FLC window now has a Gear/Guide toggle beside Go and Export.

- Gear view shows the top five upgrade priorities followed by the full equipped-slot scan, while route/arrow state continues updating underneath.

- `/flc gearscan` now opens the Gear Scanner directly in the main window.

- v0.23.2: Rebalanced gear-scan slot expectations so real weak equipped gear outranks optional empty accessories.

- Head, neck, and low-level trinket empties are now OPTIONAL EMPTY instead of top-priority failures before their expected levels.

- Weak wrist/hands/weapon pieces now rank ahead of opportunistic accessory slots, producing more practical leveling upgrade priorities.

- v0.24.0: Connected the Gear Scanner to a conservative verified upgrade-source catalog.

- Gear priorities now show an estimated upgrade percentage, source, and ROUTE-FRIENDLY vs OPTIONAL FARM/AH guidance when a verified target actually beats the equipped item.

- Added verified Shaman wrist targets including Witherbite Bracers from Witherfang in Ruins of Lordaeron and Wolfmane Wristguards from Earthen Arise.

- Added verified hand candidates including The Lost Pages rewards and Brawler Gloves; weak-looking gear becomes HOLD when no verified candidate actually beats its leveling score.

- v0.24.1: Replaced the dedicated Gear tab with a compact Gear Upgrades section inside the normal Guide view.

- The live window now shows at most two actionable gear upgrades with current item, recommended item, estimated gain, and source; optional empty slots stay hidden during gameplay.

- Full equipped-slot diagnostics remain in `/flc export`, while `/flc gearscan` prints only a compact upgrade summary.

- v0.24.2: Hotfix gear scanner compatibility on Forever clients where the legacy global item-info API is unavailable; item info/stat reads now use safe legacy/new-API fallbacks.

- v0.25.0: Added an in-addon Settings panel so common features no longer require memorizing slash commands.

- Settings includes clickable ON/OFF controls for Lazy Mode, auto accept, auto turn-in, gear advice, navigation arrow, flight assist, Beginner Mode, and Relic Advisor.

- Settings also includes Lock/Unlock UI, Gear Summary, and Mark Class Training Done actions.

- v0.25.1: Added verified Zoram'gar turn-in targets for Between a Rock and a Thistlefur and Troll Charm.

- Completed Thistlefur quests now provide a real navigation target and arrow instead of leaving STEP 1 with no waypoint.

- Between a Rock and a Thistlefur now also exposes the verified King of the Foulweald follow-up pickup at Karang Amakkar.

- v0.26.0: Major interface polish pass focused on readability during active leveling.

- STEP 1 now has a stronger visual hierarchy with a dedicated Current Objective label and larger quest title; queued/background quests are visually quieter.

- Settings is reorganized into Guide, Navigation, Advisors, Interface, and Actions sections.

- Added Compact/Detailed display modes and a Reset UI button for restoring the main window, arrow, and travel-hint positions/sizes.

- Compact mode hides secondary gear details and background-task instructions; Detailed mode keeps the fuller coaching view.

- v0.26.1: Tuned the redesigned main window after in-game testing.

- The current quest title now gets the full window width instead of competing with Settings/Go/Export, preventing unnecessary title wrapping.

- Increased the redesigned default height and shortened the compact footer so the bottom of the guide no longer feels clipped.

- v0.26.2: Polished the leveling interface so STEP 1 dominates visually while queued/background quests are quieter.

- Removed the compact-mode footer and softened the scroll bar chrome to reduce visual clutter.

- Replaced the stock scrollbar-style navigation arrow with a larger GPS-style minimap arrow, gold tint, shadow, and separate target/distance panel.

- v0.26.3: Fixed malformed queued-quest color markup that could print raw color codes in the guide.

- Navigation arrow now uses WorldMapArrow with a safe scrollbar-arrow fallback for Forever clients where the previous minimap texture does not render.

- Tightened the arrow target/distance panel so it takes less screen space.

- v0.27.0: Reworked FLC into its own modern visual style instead of mimicking the stock WoW interface.

- Main window, travel hint, and Settings now use flat charcoal panels with a teal accent and minimal borders.

- Main and Settings buttons are visually flattened, current-objective styling uses a simple accent strip, and queued steps use muted slate colors.

- Navigation is now a minimal teal pointer with plain target/distance text and no bordered fantasy-style label box.

- v0.27.1: Hotfix a malformed Talent color string introduced by the v0.27.0 modern UI theme; addon now loads normally.

- v0.28.0: Replaced the compact guide's formatted quest text with reusable modern quest-card frames.

- STEP 1 now has a stronger active card; queued quests use smaller muted cards and background quests are visually de-emphasized as WHILE QUESTING.

- The navigation marker now sits on a small flat high-contrast plate so it remains readable against terrain without returning to stock WoW chrome.

- Main toolbar buttons received slightly more vertical padding for the modern layout.

- v0.28.1: Removed the navigation marker's black backing square and increased pointer contrast/size for better in-world readability.

- The top objective header now shows route context (Current route / Travel / Turn in quest / Class training) while the STEP 1 card owns the quest title, removing duplicate quest names.

- Tightened spacing above the quest cards so the compact guide uses screen space more efficiently.

- v0.28.2: Replaced the remaining WoW map-arrow artwork with an FLC-built flat chevron made from simple UI textures.

- The custom chevron rotates with the existing navigation math and keeps the modern teal identity without relying on stock fantasy assets.

- Route context headers such as Travel now use the teal UI palette, and quest-card borders were softened slightly.

- v0.28.3: Fixed the custom navigation chevron geometry so both wings rotate around one shared pivot instead of separating/crossing while the player turns; increased arrow refresh smoothness.

- v0.28.4: Converted the custom navigation chevron into a true arrow by adding a rotating shaft and matching shadow, while preserving the modern FLC visual style.

- v0.28.5: Replaced the multi-piece navigation marker with a custom single-piece FLC arrow texture stored in the addon.

- The navigation arrow now rotates as one texture, eliminating the Y-shape, wing separation, and geometry glitches from the previous construction.

- v0.28.6: Polished the single-piece navigation arrow by shrinking it slightly, softening its visual weight, and adding more spacing before the target label.

- The active STEP 1 card now has a little more height and contrast, while the top toolbar buttons are tighter and more evenly spaced.

- Main guide scroll controls now hide automatically when the visible content fits without scrolling.

- v0.28.7: Fixed Lazy Mode sending the player to a flight master when the route's flightTarget already matches the current zone/subzone.

- Local same-map objective navigation now explicitly overrides any stale lazy travel target, so Ashenvale Outrunners at Splintertree points to the Outrunners instead of the Splintertree flight master.

- Navigation rotation is normalized to -180..180 degrees for cleaner arrow behavior and export diagnostics.

- v0.28.8: Added localAliases support for route clusters so the large current-area bonus can distinguish separate hubs inside the same parent zone.

- Ashenvale Zoram Strand, Thistlefur, and Splintertree now score as distinct local areas instead of every Ashenvale quest receiving the full +170 local bonus.

- v0.29.0: Added a verified Pickup Suggestions system. Unaccepted route quests with known quest-giver data can now be classified as PICK UP NOW, PICK UP IF NEARBY, or SKIP based on level, class/race, current hub, route cluster, and proximity.

- Pickup suggestion cards now appear in the main guide without replacing the active STEP 1 objective; export includes a dedicated PickupSuggestions section for testing.

- Added verified pickup data for key Ashenvale Horde quests including Naga at the Zoram Strand, Between a Rock and a Thistlefur, Troll Charm, The Lost Pages, Warsong Supplies, Ashenvale Outrunners, and Satyr Horns.

- Promoted Stonetalon Standstill (25) and King of the Foulweald (6621) from unknown scanner entries into verified route data, including quest givers, objectives, turn-ins, and safe waypoints.

- v0.29.1: Added verified Torek's Assault (6544) route data after live discovery on Shamm.

- Torek's Assault now includes the verified quest giver, assault start, Splintertree turn-in, and pickup metadata, so it no longer appears as NEW/UNVERIFIED.

- v0.29.2: Hotfixed a pickup-card UI crash caused by `stepNumber` being scoped inside the cluster queue block. Pickup suggestions can now render safely when present.

- v0.29.3: Added situational escort/event urgency scoring for verified active quests. The bonus only applies while the event start/objective is genuinely nearby and fades to zero outside the configured radius.

- Torek's Assault now uses the event-urgency rule after pickup, helping FLC recommend doing the nearby assault before leaving the area without globally overvaluing escort quests.

- v0.29.4: Compact HUD pass. Reduced default main-window height from 190 to 170, tightened the header/objective strip, shrank top controls, and reduced card height/padding.

- Existing default-sized windows migrate to the new compact height while intentionally taller resized windows are preserved.

- v0.29.5: Added QUICK PICKUP navigation. A very-close verified PICK UP NOW quest can temporarily own the arrow while the current routed quest remains STEP 1.

- Quick pickup suggestions now render directly under STEP 1 and disappear automatically once accepted; ordinary queued quests remain below them.

- Added the verified Ashenvale Outrunners turn-in target: Kuray'bin at 71.1, 68.1.

- v0.29.6: Fixed Quick Pickup visual ownership so the top card now always matches the arrow/navigation target.

- While Quick Pickup is active, the pickup becomes the emphasized first card and the saved route moves directly underneath as ROUTE. Once the quest is accepted, normal STEP 1 presentation returns automatically.

- v0.29.7: Added live Quick Pickup arrival handling. Within 8 meters of the verified quest giver, FLC hides the arrow and changes the top HUD prompt to INTERACT NOW.

- If the player backs away before accepting the quest, FLC automatically restores normal Quick Pickup arrow navigation; accepting the quest still returns control to the saved route.

- v0.30.0: Added Smart Turn-In Flow with TURN IN NOW, DEFER TURN-IN, and QUICK PICKUP FIRST decisions for completed quests.

- Completed quests can now receive a real routing penalty when nearby unfinished route work should be finished first, allowing another active quest to become STEP 1 instead of merely displaying a defer message.

- Export now includes TurnInDecision and TurnInDecisionReason for live route auditing.

- v0.31.0: Added batched turn-ins. Multiple completed verified quests returning to the same hub are grouped into a single RETURN TO [HUB] flow.

- Batched turn-ins sort verified NPCs by current same-map distance, navigate to the nearest turn-in first, and automatically recalculate after each quest leaves the log.

- The compact HUD now shows the hub and turn-in count instead of duplicating individual completed quests, and export includes TurnInBatch details.

- v0.32.0: Added post-turn-in hub chaining. QUEST_TURNED_IN now preserves a verified follow-up pickup briefly after the source quest disappears from the quest log.

- Verified same-hub follow-ups can temporarily own navigation as PICK UP NEXT, then automatically clear when the follow-up is accepted or becomes active/completed.

- Added verified follow-up quest IDs to existing route chains for Vital Intelligence, Fields of Grief, The Great Outdoors, Rattling the Rattlecages, and In Nightmares.

- v0.33.0: Added completed known-quest route-data gap detection. FLC now identifies completed quests that are known to the addon but lack a routable verified turn-in definition.

- Route data gaps appear as non-disruptive warning cards beneath the live route and never steal STEP 1 or arrow ownership.

- Export now includes RouteDataGapCount, RouteDataGapTop, and a RouteDataGaps section distinguishing missing route entries from missing turn-in targets/waypoints.

- v0.34.0: Added a verified route entry for quest 1483 Ziz Fizziks, including Ratchet pickup, Windshear Crag turn-in at Ziz Fizziks around 59.0, 62.6, and verified waypoint navigation.

- Added verified follow-up quest 1093 Super Reaper 6000 with Ziz pickup/turn-in and Venture Co. Operator objective routing around 69, 54 in Stonetalon Mountains.

- Ziz Fizziks should no longer appear as a completed known-quest route-data gap; after turn-in, hub chaining can surface Super Reaper 6000.

- v0.35.0: Added automatic optional-quest cleanup. OPTIONAL quests stop competing for routing once the player reaches that quest's configured route cutoff level.

- Active pruned quests are surfaced under QuestCleanup as SAFE TO IGNORE / ABANDON instead of silently remaining in route scoring.

- Cleanup warnings are informational only; FLC does not automatically abandon quests from the player's quest log.

- v0.36.0: Cleanup cards now include a clickable DROP button for quests currently marked SAFE TO DROP.

- DROP validates that the quest is still in the live QuestCleanup set, asks for confirmation, selects that exact quest ID, and uses the available client abandon API before refreshing the route.

- Cleanup buttons never appear on normal DO/IMPORTANT quests or other route cards.

- v0.37.0: Added cross-zone completed-turn-in deferral. Normal completed quests on another map are deferred while eligible unfinished DO/IMPORTANT objectives remain on the player's current map.

- IMPORTANT completed quests are exempt from cross-zone deferral so class/progression-critical turn-ins can still take priority.

- Cross-zone deferral uses a dedicated 400-point penalty and explains the local quest that should be finished first in scoring/export reasons.

- v0.38.0: Completed Satyr Horns (6441) routing with a verified Ashenvale satyr objective waypoint around 75, 50 and Pixel turn-in at Splintertree Post around 73.1, 61.5.

- Removed the redundant Splintertree flight target from Satyr Horns so being at Splintertree no longer produces a bogus flight-master instruction.

- Satyr Horns can now own normal same-map arrow navigation for both collection and turn-in.
