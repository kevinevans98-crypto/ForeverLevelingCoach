# Forever Leveling Coach — Alpha 1 Testing Guide

**Build:** v0.55.0  
**Status:** Early Alpha  
**Core support:** All standard Horde classes, levels 1–30  
**Class-optimized support:** Warrior, Hunter, Rogue, Priest, Paladin, Shaman, Mage, Warlock, and Druid  
**Coverage note:** All supported classes now use the same profile-based talent, gear, and trainer service architecture where verified data is available.

## What Alpha 1 is testing

Alpha 1 is intentionally small. We mainly want to know:

1. Does FLC recommend a sensible next quest or objective?
2. Does the navigation arrow/waypoint send you to the right place?
3. Does FLC avoid unnecessary travel and finish useful nearby work first?
4. Do quest turn-ins and follow-up chains continue correctly?
5. Is the normal guide understandable without reading technical diagnostics?

Do not worry about understanding route scores, quest IDs, map IDs, or addon internals.

## Install

Copy the `ForeverLevelingCoach` folder into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\ForeverLevelingCoach
```

Then launch WoW Forever Beta or run:

```
/reload
```

To confirm the addon is loaded, use:

```
/flc
```

## Recommended Alpha 1 settings

For the first test, leave the normal defaults enabled unless you are specifically testing a setting:

- Lazy Mode: ON
- Navigation arrow: ON
- Gear advice: ON
- Auto Accept: ON
- Auto Turn-In: ON
- Flight Assist: optional

FLC will not automatically choose a quest reward when the quest requires a reward choice.

## What to report

Please report anything that feels wrong, slow, confusing, or inaccurate.

Useful examples:

- Wrong quest recommendation
- Wrong or missing waypoint
- Arrow points the wrong direction
- Unnecessary zone travel
- Nearby quests should have been completed first
- Missing quest
- Quest chain/follow-up does not continue
- Auto Accept or Auto Turn-In behaves incorrectly
- Gear recommendation looks wrong
- Addon window is confusing
- Lua/addon error

## Simple bug report

You only need to send two things:

**What happened?**  
Describe the problem in 1–3 normal sentences.

**FLC Export**  
Run:

```
/flc export
```

Then paste the complete export with your report.

Optional information that can help:

- What you expected FLC to do instead
- Zone/subzone
- Screenshot
- Lua error text
- Whether the problem happened more than once

### Copy/paste template

```
Forever Leveling Coach — Alpha 1 Bug Report

Problem type:
Wrong quest / Wrong waypoint / Bad travel / Missing quest /
Quest chain / Gear / Addon error / Confusing UI / Other

What happened:


What did you expect instead? (optional)


Did it happen more than once?
Yes / No / Not sure

FLC Export:
[PASTE /flc export HERE]

Optional screenshot/error:
```

## Important Alpha limitations

- Alpha 1 is primarily validating Horde Shaman 1–30.
- Rogue support is still experimental.
- Not every WoW Forever quest, class, dungeon, gear source, or edge case is covered yet.
- Waypoint coordinates are only added when they have been verified; FLC should prefer no arrow over an invented location.
- Dungeon repeat-XP efficiency and broader class routing are still being refined.
- Gear recommendations are leveling guidance, not an endgame simulator.

## v0.45.0 focus

Alpha 1 now includes a universal Horde class foundation.

Every standard Horde class can pass the support gate and use the shared routing, navigation, travel, quest-chain, auto quest, export, and generic gear systems. Shaman and Rogue keep their additional optimized class-specific logic.

The build also retains chain-aware completed-quest scoring.

When a completed quest immediately unlocks a useful follow-up, FLC can give that turn-in additional value. A same-NPC follow-up can receive up to **+80 chain value**.

The existing smart turn-in defer logic still wins first. FLC should not send you across zones early just because a follow-up exists.

### Specific chain test

One useful live test is:

**Ziz Fizziks [1483] -> Super Reaper 6000 [1093]**

Expected behavior:

1. If valuable Ashenvale work is still nearby, Ziz Fizziks can remain deferred.
2. Once the turn-in is appropriate, the score reason may show:
   `unlocks same-NPC follow-up (+80)`
3. After turning in Ziz Fizziks, FLC should identify Super Reaper 6000 as the immediate follow-up when near Ziz.
4. After accepting Super Reaper 6000, normal objective routing should resume.

## Tester rule

Play normally.

If you find yourself thinking **"Why is the addon telling me to do this?"**, that is useful feedback even if the addon technically works.

The goal of Alpha 1 is not perfection. The goal is to find incorrect or confusing decisions before expanding testing to more classes, levels, and players.
