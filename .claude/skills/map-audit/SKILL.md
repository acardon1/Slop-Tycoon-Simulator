---
name: map-audit
description: Audit a Slop Tycoon map or area as a real 3D space players move through, using raycasts, real character movement and the game's movement numbers in Roblox Studio. Use it when a map, plot, building or route is designed, built or changed, or when asked whether a place is reachable, jumpable, escapable, blocked, cramped or has bad drops.
---

# Map audit (Slop Tycoon)

A map is a real 3D space players move through, not just a pile of parts. Answer these: How do you get there? How do you get back? Can you cross this gap? How long do you fall?

Run this in Studio through the Roblox Studio MCP. If the MCP or Studio isn't available, say so. Never fill in a report from reading code alone.

Don't edit scripts or the map during an audit. Report what you found, and let the owner decide what to fix.

## Reference images

Begin designing a map area or recommending changes to one from `reference/map/` (the Read tool shows images). These are the owner's local inspiration pictures.

- Use them freely, with no need to ask which ones. They are where you begin, not the final word, so go beyond them when the space calls for it.
- Use them for inspiration only: never copy someone else's map or art, and never take a measurement from a picture. Numbers come from Studio.
- If the folder is empty or nothing fits, say so and carry on.

## Label every number

Every number in the report carries its source:

- *(game setting)*: read from the game (`StarterPlayer`, `Workspace`, the character's `Humanoid`, or `SlopConfig`)
- *(measured, raycast)*
- *(measured, walked)*: a real character did it
- *(calculated)*: worked out from labelled numbers
- *(guessed)*: say why you couldn't measure it

Thresholds marked *(starting value)* below were picked when this skill was written. Change them if the owner asks.

## Step 1: Movement numbers

`SlopConfig` doesn't set movement today, so read the real values in Play (Client data model): `Humanoid.WalkSpeed`, `Humanoid.JumpHeight` (or `JumpPower` if `UseJumpPower` is on) and `workspace.Gravity`. If `SlopConfig` adds these later, report those too.

Then calculate:

- Jump height: `JumpHeight`, or `JumpPower^2 / (2 * Gravity)`.
- Air time: `2 * sqrt(2 * JumpHeight / Gravity)`.
- Longest flat gap: `WalkSpeed * air time`.
- Fall time from height `h`: `sqrt(2 * h / Gravity)`.

Reference from 2026-11-08 (default character): WalkSpeed 16, JumpHeight 7.2, Gravity 196.2 give air time 0.542s and a longest flat gap of 8.67 studs. A real jump measured 7.31 studs high and 0.55s in the air, so treat the calculated limits as close but not exact, and walk-test anything within 1 stud of a limit.

## Step 2: How to measure (all tested in Studio on 2026-11-08)

- **Raycast** in the Client data model with `RaycastParams`, excluding the character. Rays down and up give floor and ceiling distances. Filter out invisible helper parts if they'd hit something players can't touch.
- **Walk** with `character_navigation` (x, y, z or an instance path), then read `HumanoidRootPart.Position` to see whether it **actually arrived**. "Success" isn't enough: compare the position with the target.
- **Teleport** to a test spot with `char:PivotTo(CFrame.new(pos))`, then `task.wait(1.5)` to settle.
- **Jump** with `hum:ChangeState(Enum.HumanoidStateType.Jumping)`, tracking the peak of `hrp.Position.Y`.
- **Overlaps** in the Server data model with `workspace:GetPartsInPart(part)` on solid parts, skipping characters. Call `task.wait()` every 200 parts or so.
- `start_stop_play` to start and stop. Yield during large loops so Studio doesn't freeze.

## Step 3: Routes

For each area that matters (spawn, plots, doors, factory yard, ATM and Collect pad, any new area):

- Walk **there** and walk **back**. Record the time and whether it arrived.
- Measure each gap with raycasts and give a verdict against the longest flat gap and jump height.
- For each drop, give the fall height and fall time. Then check there's a way back up.

## Step 4: Quality-of-life checks

| Check | How |
|---|---|
| No floating platforms without a reason | Ray down from standable parts. Flag any with no support below, then say whether it looks intended |
| No roofs players can't stand on | Teleport onto the roof. Does the character stay there? Roofs that look walkable should be walkable, or clearly blocked |
| No unreachable high ground | Compare each high surface with jump height and nearby steps, then try to walk there |
| Blocked areas are truly blocked | Try to walk and jump into the region from several sides. Check for gaps and that the barrier is taller than a jump. "Looks blocked" doesn't count |
| No stuck pockets | Teleport into each low or enclosed spot, then walk to a known open point. Failing to arrive means a pocket |
| No overlapping parts | Run the overlap check, then group the results by name pair (see below) |
| Sight lines aren't too cramped | Along each path, fan 12 rays at eye height, up to 300 studs. Flag spots where fewer than 3 of the 12 rays see past 30 studs *(starting value)* |
| No awkward in-between drops | Each height change should be a small step, up to 2 studs *(starting value)*, or clearly a fall, 5 studs or more (a default character is about 5 studs tall). Flag anything between |

**Reading overlaps:** expect many harmless ones. Walls meeting at corners and decorations set into walls count as overlaps; the procedural world showed 717 pairs across 435 solid parts on 2026-11-08, mostly by design. Group them by name pair and report the groups. Flag these as real problems: two parts with the same position and size (they flicker), parts that stick out into a walking path, and parts inside a doorway.

## Step 5: Report

Example:

- WalkSpeed: 16 *(game setting)*
- Jump height: 7.2 studs *(game setting)*
- Longest flat gap: 8.67 studs *(calculated)*
- Gap A to B: 11.4 studs *(measured, raycast)*
- Verdict: not jumpable *(calculated)*

Then list each check as pass, fail or **not tested** (with the reason), with where it is (position or part name) for every failure, worst problems first. Finish with what you recommend fixing. Don't call an area clean if any check wasn't run.
