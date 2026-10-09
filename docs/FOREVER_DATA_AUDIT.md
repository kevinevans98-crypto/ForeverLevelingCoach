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
