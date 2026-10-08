# Forever Leveling Coach — Alpha 1 Release Notes

## Alpha 1 — v0.44.0

Forever Leveling Coach Alpha 1 is an early tester build focused on validating the core leveling experience before wider class and route expansion.

### Primary test scope
- Horde Shaman
- Levels 1–30
- Rogue support remains experimental

### Core systems included
- Automatic quest routing
- Explainable smart route scoring
- Local quest stacking
- Dynamic local ordering
- Primary vs. background quest handling
- Smart completed-quest turn-in decisions
- Follow-up quest/chain detection
- Navigation arrow and verified waypoints
- Cross-zone travel hints
- Flight-path awareness
- Lazy Mode
- Auto Accept / Auto Turn-In with reward-choice safety
- Gear weakness scanning and upgrade guidance
- Shaman relic support
- Talent guidance
- Full `/flc export` diagnostics

### New in v0.44.0
- Added chain-aware completed-quest scoring.
- Follow-up quest unlocks can add +45 route value.
- Same-NPC follow-ups can add another +35.
- Chain bonuses are not applied while the turn-in is intentionally deferred, preserving local-route efficiency.

### Tester priority
Please focus feedback on:
- bad route decisions,
- bad/missing navigation,
- unnecessary travel,
- broken quest-chain continuation,
- confusing UI,
- incorrect gear advice,
- addon errors.

Use `/flc export` whenever possible.
