# Forever Leveling Coach — Alpha 1 Release Notes

## Alpha 1 — v0.55.0

Forever Leveling Coach Alpha 1 is an early tester build focused on validating the core leveling experience before wider class and route expansion.

### Primary test scope
- All standard Horde classes, levels 1–30, can use the core addon
- Shaman and Rogue currently have the deepest class-specific optimization
- Other classes use the universal routing/navigation engine with generic class behavior where custom data is not yet available

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

### New in v0.55.0
- Normalized Shaman onto the generic class talent and gear services.
- Added an Enhancement 1–30 Shaman talent path and class gear profile.
- Normalized Rogue onto the generic class trainer service.
- Added Rogue trainer routing for Undercity and Orgrimmar.
- All supported classes now use the same profile-driven service architecture for talents, gear, and trainers when configured.

### Retained from v0.54.0
- Added Druid as an optimized class on the generic class framework.
- Added the current Feral 1–30 leveling talent path.
- Added Druid-specific Feral stat weights and leather/weapon rules.
- Added Thunder Bluff Druid trainer routing.
- All current WoW Forever classes now exist in the universal support table.

### Retained from v0.53.0
- Added Paladin as an optimized class on the generic class framework.
- Added the current Retribution 1–30 leveling talent path.
- Added Paladin-specific melee/caster stat weights and mail/weapon rules.
- Added a Retribution 2H weapon preference.
- Added Paladin trainer routing for Undercity and Orgrimmar.

### Retained from v0.52.0
- Added Priest as an optimized class on the generic class framework.
- Added the current Shadow 1–30 leveling talent path.
- Added Priest-specific caster/wand stat weights and cloth/weapon rules.
- Added Priest trainer routing for Undercity, Orgrimmar, and Thunder Bluff.
- Restored Paladin to the universal Horde class support table so all current WoW Forever classes are represented.

### Retained from v0.51.0
- Added Warlock as an optimized class on the generic class framework.
- Added the current Affliction 1–30 leveling talent path.
- Added Warlock-specific caster stat weights and cloth/weapon rules.
- Extended trainer services to support profile-defined trainer hub lists.
- Added Warlock trainer routing for Undercity and Orgrimmar, with nearby-zone preferences.

### Retained from v0.50.0
- Added Mage as an optimized class on the generic class framework.
- Added the current Frost 1–30 leveling talent path.
- Added Mage-specific caster stat weights and cloth/weapon rules.
- Added Mage trainer routing for Orgrimmar and Thunder Bluff.
- Mage now uses class-specific talent, gear, and trainer services instead of generic fallback.

### Retained from v0.49.0
- Added Hunter as an optimized class on the generic class framework.
- Added the current Beast Mastery 1–30 leveling talent path.
- Added Hunter-specific leveling stat weights and weapon/armor rules.
- Added Hunter trainer routing for Orgrimmar and Thunder Bluff.
- Hunter now uses class-specific talent, gear, and trainer services instead of generic fallback.

### Retained from v0.48.0
- Added Warrior as the first newly optimized class on the generic class framework.
- Added a current WoW Forever Warrior leveling talent path, including the level-16 Protection respec handoff.
- Added Warrior-specific leveling stat weights and armor/weapon rules.
- Added Warrior class trainer routing for Orgrimmar and Thunder Bluff.
- Warrior training reminders use the generic class trainer service.
- Shields are handled as valid Warrior gear instead of receiving a mail-preference warning.

### Retained from v0.47.0
- Moved talent-guide lookup behind the generic class profile.
- Moved class gear restrictions behind the generic class profile.
- `/flc spec` now reads the active class profile instead of directly referencing Rogue data.
- Generic classes safely report that no class-specific talent guide is configured yet.
- Replaced Rogue-only gear preference handling with a reusable class preference path.

### Retained from v0.46.0
- Refactored class training into a reusable generic class service.
- Removed Shaman-only trainer calls from the core render path.
- Class profiles now declare whether trainer guidance exists and when training reminders should trigger.
- Classes without verified trainer data safely skip trainer routing instead of failing.
- Shaman keeps its verified trainer locations and current level-24+ reminder behavior.

### Retained from v0.45.0
- Added universal Horde class support foundation.
- Warrior, Hunter, Rogue, Priest, Shaman, Mage, Warlock, and Druid now pass the core support gate.
- Added generic class profiles so unsupported class-specific systems fail safely instead of blocking the entire addon.
- Shaman and Rogue retain their existing specialized behavior.

### Retained from v0.44.0
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
