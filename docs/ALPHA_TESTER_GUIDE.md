# Forever Leveling Coach — Alpha Tester Guide

**Status:** Recruitment preparation. The alpha build is not yet released or verified for public installation. Stable v0.58.0 is unchanged.

## Join and install

1. Ask to join the alpha through the project owner or a recruitment post. Do not download random addon archives from strangers.
2. Wait for an explicitly tagged, tested alpha ZIP and installation instructions. Back up your current addon and SavedVariables first.
3. Install only the approved alpha package. Confirm the addon version/build shown in the export.
4. Test for 20–30 minutes in your assigned starting zone. Beginners welcome.

## What to test

- Accept 2+ nearby quests: does the addon show them, group their objectives, and avoid unnecessary backtracking?
- Finish objectives and turn in quests: do cards and arrows update correctly?
- Check unknown/unverified quest handling: no invented waypoints.
- Check class training, gear suggestions, UI behavior, and any Lua errors.
- Record quest ID, zone, level, class, expected behavior, actual behavior, and reproduction steps.

## How to report

1. Click **Report** or type `/flc report`.
2. Copy the text and replace the bracketed Expected/Actual/Reproduce/Frequency fields.
3. Review the export before sharing: it can contain character name, position, quest progress, gear, and other gameplay details. Redact anything you do not want public.
4. Open [New Alpha Bug Report](https://github.com/kevinevans98-crypto/ForeverLevelingCoach/issues/new?template=alpha-bug-report.yml). GitHub login is required.
5. Attach a screenshot or Lua error if useful. No account passwords, tokens, private chat, or personal details.

Reports are **not automatically uploaded by the addon**. GitHub Issues is the feedback inbox. GitHub Actions can categorize submitted issues after the workflow is active on the default branch.

## Test coverage plan

| Volunteer | Area | Focus |
|---|---|---|
| 1 | Tirisfal Glades / Brill | Rogue; parallel quests |
| 2 | Durotar | Horde early quests |
| 3 | Mulgore | Tauren early quests |
| 4 | Elwynn Forest | Alliance early quests |
| 5 | Teldrassil | Alliance early quests |

A volunteer can test any class. Do not promise universal class or faction coverage before verification.

## Severity

- **Blocker:** addon fails to load, repeated Lua crash, UI unusable
- **High:** incorrect route, dangerous/unverified arrow, lost quest progress
- **Medium:** missing quest, bad class/gear advice, repeated detours
- **Low:** cosmetic, wording, minor layout

## Test session checklist

- [ ] Addon loads without Lua errors
- [ ] Version/build confirmed
- [ ] Multiple quests appear as expected
- [ ] Primary waypoint and nearby objectives make sense
- [ ] Quest completion and turn-in update the route
- [ ] Report command opens a copyable report
- [ ] Issue form accepts a redacted report

**Stop testing and report immediately** if the addon causes repeated UI errors. Do not delete SavedVariables without backing them up.
