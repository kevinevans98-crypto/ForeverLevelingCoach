# Forever beta data validation backlog (Shamm, level 24)

This is a verification backlog, **not** a claim that all external database entries are accurate for the current beta. Do not publish speculative waypoints, item sources, or quest rewards as verified.

## Confirmed from player exports (addon v0.58.0)

- Blackfathom Deeps recognized as active dungeon, cluster BLACKFATHOM_DEEPS, quests 6563 and 6921 tracked.
- 6921 Amongst the Ruins: Fathom Core 1/1, completed, Je'neu Sancrea turn-in at Zoram'gar Outpost (11.6, 34.3).
- 6922 Baron Aquanis: observed completed with Strange Water Globe turn-in at Je'neu Sancrea. Current route status NEW/UNVERIFIED. Verify pickup and repeatability before making a routed quest entry.
- 6561 Blackfathom Villainy: observed completed with Head of Kelris 1/1. Current route status NEW/UNVERIFIED. Verify NPC, location, faction and prerequisites before adding a route.
- 6563 The Essence of Aku'Mai: remained at 0/20 after run. Do not assume completion or award XP.
- Cross-zone travel readiness warnings: 6441 Satyr Horns, 6442 Naga at the Zoram Strand, 6621 King of the Foulweald, 6641 Vorsha the Lasher. Verify entrances, flight targets, and routes in-game before adding coordinates.
- Class training remained due at level 24 with lastClassTrainerLevel=0. Investigate whether trainer visit/learning event updates persisted DB state; do not auto-clear training without evidence.
- Same-city flight suggestion: Thunder Bluff recommended while player was already in Thunder Bluff. Separate branch fix suppresses same-city Thunder Bluff/Orgrimmar trainer flights.
- Talent export: Ancestral Knowledge 1/5, Elemental Weapons 3/3, Flurry 4/5, Improved Ghost Wolf 2/2, Mental Dexterity 3/3, Shamanistic Focus 1/1, Stormstrike 1/1, Thundering Strikes 5/5. Talent recommendations should exclude maxed talents and be verified against current beta build.

## Dungeon XP test (observed, not a universal XP table)

- Starting level 24 XP: 2,153 / 31,700.
- After BFD before quest turn-ins: 8,947 / 31,700 (+6,794).
- After quest turn-ins: 30,597 / 31,700 (+21,650). Player confirmed no other kills or quests between those snapshots.
- Combined gain: 28,444 XP, 89.73% of level 24.
- Run duration estimated 40–50 minutes; run-only XP/hour 8,153–10,191. Do not combine travel/turn-in time into this rate without measuring it.
- One-time quest rewards must never be projected as repeatable dungeon XP.

## Data import rules

1. Keep records keyed by stable quest/item/spell IDs, faction, level and game build where known.
2. Record provenance: player export, in-game verified, external database, or unverified.
3. Do not overwrite verified coordinates with external unverified positions.
4. Separate dungeon kill XP, one-time quest XP, and run duration.
5. Add new quest records only after verifying pickup NPC, objectives, turn-in, prerequisites and beta availability.
6. Test all nine classes and both factions before labeling universal support.

## QA checklist

- [ ] Trainer in Thunder Bluff does not suggest flying to Thunder Bluff.
- [ ] Remote flight targets still appear when actually needed.
- [ ] BFD entrance and internal objectives do not point back to outdoor approach after entry.
- [ ] Quest 6922 and 6561 can be resolved to verified quest data.
- [ ] Four cross-zone warnings have verified, safe instructions.
- [ ] Class trainer history persists after training.
- [ ] Talent recommendation avoids maxed/incorrect ranks.
- [ ] First-run and repeat-run dungeon XP reported separately.

## v0.59.0 Alpha 1 batch delivery and release gates

Goal: optimize a *local quest loop*, not just a single highest-scored quest. Keep stable v0.58.0 untouched until the alpha passes.

### Batch A — Brill (Horde level 5–10)

- [ ] Cover observed missing quests by ID: 404 A Putrid Task, 427 At War With The Scarlet Crusade, 5482 Doom Weed, 358 Graverobbers, 398 WANTED: Maggot Eye.
- [ ] Audit Forever candidates separately: 99134 Discipline, 99141 Patience, 96658 Cooking, 97955 First Aid, 97960 Skinning. No invented locations or NPCs.
- [ ] Verify each quest's objectives, prerequisite/pickup, objective coordinates, and turn-in against in-game Forever Beta observations before adding navigable targets.
- [ ] Export all active quests and distinguish VERIFIED LOCAL CLUSTER from LOCATION UNVERIFIED; do not claim that unknown quests are locally routed.
- [ ] Score parallel verified objectives for travel efficiency, shared kills/loot, remaining progress, and turn-in proximity; retain a safe single navigation arrow.
- [ ] Avoid oscillating between objectives when score differences are small; preserve route-switch margin.
- [ ] Batch nearby turn-ins only when NPC/hub locations are verified.
- [ ] Ensure CurrentTravelStep is meaningful for verified objective and turn-in targets.
- [ ] Level-6 Rogue off-hand is NOT EXPECTED YET; trainer reminders should be actionable.
- [ ] Fix misleading RouteDataGapCount=0 when unresolved unknown quests exist (or add a distinct unknown coverage count).

### Batch B — automated checks before gameplay

- [ ] Parse every changed Lua file with a compatible Lua syntax checker.
- [ ] Run fixtures for: incomplete parallel quests; completed turn-in; unknown quest; quest chain transition; unavailable quest; class-specific level gating; map mismatch.
- [ ] Verify no fabricated waypoints, duplicated quest cards, or accidental stable-branch changes.
- [ ] Verify export reflects actual active quest count, known/unknown count, primary target, parallel targets, and decision reasons.
- [ ] Review licenses and data provenance before importing any third-party quest database or art.

### Batch C — one focused gameplay session

1. Install alpha separately and confirm the alpha version/build identifier in export.
2. On Ms, accept multiple Brill quests, then play 30–60 minutes completing overlapping objectives.
3. Export at start, after two completed objectives, after grouped turn-ins, and at end; note bad arrows or backtracking.
4. Compare travel and objective order to actual opportunities seen in-game. Record regressions and fix in a single batch.

### Stable release gate

Only after syntax/fixture checks, in-game route validation, regression review, and a successful updater test: bump version consistently in metadata and export, merge alpha PR, and publish stable v0.59.0. Do not claim these checks passed until executed.

## Alpha tester quick start (v0.59.0 preparation)

**Build:** use the alpha branch package only; do not overwrite a working stable addon without a backup. The alpha branch is not yet a released or validated build.

**Test:** play normally for 20–30 minutes in the assigned class/zone. Watch for wrong arrows, missing nearby quests, needless backtracking, incorrect training or gear advice, Lua errors, and stuck turn-ins.

**Report:** click **Report** in the addon or type `/flc report`. Copy the diagnostic text into an issue. Replace the bracketed Expected/Actual/Reproduce/Frequency fields with observations. Include an optional screenshot and the error text if available. Reports are manual; the addon does **not** upload or transmit them.

**Privacy:** exports include character name, class, faction, level, current location/coordinates, quests and gear. Review and redact identifying details before posting publicly. Never include account credentials or private chat.

**Triage labels:** blocker (crash, unplayable), high (wrong route or unsafe waypoint), medium (missing quest/incorrect guidance), low (cosmetic). Include exact quest ID and addon version. Deduplicate issues by quest ID + zone + symptom.

**Release rule:** verify syntax and in-game behavior before sending a build to outside testers. Keep test and stable installations clearly separated.
