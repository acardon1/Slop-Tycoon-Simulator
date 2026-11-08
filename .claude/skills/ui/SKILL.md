---
name: ui
description: Rules for suggesting, designing, building or changing any player-facing UI in Slop Tycoon (HUD, menus, windows, buttons, panels, icons, ScreenGuis). Use it whenever UI is proposed, not only when it is coded. It covers the preview image, the local base images and icon set, the depth stack, the required resolutions, and the measured checks in Studio. Use the coding skill as well when scripts change.
---

# UI rules (Slop Tycoon)

These rules apply to new UI and to any UI you change. Older UI doesn't follow them all yet (for example, its outlines are 2.5 to 5 px). Bring what you touch up to these rules, but don't restyle other screens unless asked.

Values marked *(starting value)* were chosen when this skill was written, not by the owner. Change them if the owner asks.

## Start with the reference images

Begin any UI design or suggestion from `reference/ui/` (the Read tool shows images). These are the owner's local inspiration pictures.

- Use them freely, with no need to ask which ones. They are where you begin, not the final word, so go beyond them when the design calls for it.
- Use them for inspiration only. Never copy someone else's art, logos or exact screens into the game, and never put a reference image in `ui/` or upload one to Roblox.
- If the folder is empty or nothing fits, say so and carry on.

## 1. What to show the owner

Whenever UI is suggested, show all three:

1. **A preview image.** Don't describe UI in words only. Save it to `ui/previews/`, and show it in the conversation.
2. **The UI files** (section 2).
3. **The part of the script that builds the UI, with comments** explaining each piece.

**Making the preview in Studio** (tested 2026-11-08):

1. `start_stop_play` (start).
2. Build the draft with `execute_luau` in the Client data model, in a temporary ScreenGui under `PlayerGui`. This goes away when play stops, and it does not edit any script.
3. `screen_capture` in Play mode. It shows the game view, HUD included.
4. The tool result names the saved `.jpg`. Copy it to `ui/previews/<screen-name>.jpg`.
5. `start_stop_play` (stop).

Images that aren't uploaded to Roblox yet can't appear in Studio. Until they are, use a flat coloured frame of the same size as a stand-in, and say that you did.

## 2. UI is made of images the owner can see locally

UI is put together from **base images** and a **set of icons to choose from**. These are real picture files in the repo:

| Folder | What goes there | Example |
|---|---|---|
| `ui/base/` | Bare screens and pieces, with no live content | `ui/base/inventory.png` (the naked inventory screen) |
| `ui/icons/` | The icon set to choose from | `ui/icons/cash.png` |
| `ui/previews/` | Preview images for review | `ui/previews/inventory.jpg` |

- Use PNG with transparency for `ui/base/` and `ui/icons/`. Name files in lowercase with hyphens.
- Check `ui/icons/` first and reuse an icon before asking for a new one.
- Art is the owner's. Don't present generated or placeholder art as final. Say what is missing and what size it needs to be.
- Live content (numbers, names, Slops) is **not** baked into images. Scripts place it on top.

**In the game:**

- The script builds the UI by placing `ImageLabel` / `ImageButton` objects that use those images, in the shared `SlopUI` module or the client script that owns the screen. Rojo syncs the scripts; the pictures themselves are uploaded to Roblox separately (Step 4 of `docs/ai-setup-plan.md`).
- Keep image IDs in one table in `SlopUI`, keyed by file name. Use `0` for "not uploaded yet", and fall back to a code-drawn frame in that case, so the game never shows a blank square.

## 3. The depth stack (every element)

From bottom to top:

| Layer | Rule | How |
|---|---|---|
| **Shadow** | Below the element, colour shifted slightly blue | Copy of the shape, 4 px lower *(starting value)*, in a dark blue such as RGB 28, 32, 62 *(starting value)* |
| **Face** | Gradient | `UIGradient`, lighter at the top and darker at the bottom |
| **Top lift** | A thin lighter strip along the inside of the top edge, so it looks raised and chunky (owner decision) | A lighter band across about the top 15-20% of the face *(starting value)*, following the corners |
| **Outline** | **3 px everywhere** (owner decision), on windows, buttons, tabs and text alike | `UIStroke`, `Thickness = 3`, using `UI.COL.Outline` |

If a base image already has these layers drawn in, don't add them again in code. Check the picture for all four.

## 4. Layout rules

- **Thumb size:** anything tappable is at least 44 x 44 px at phone resolution *(starting value)*.
- **No touching:** no two elements touch. Compare elements with the same parent (a child sitting on its own window is fine). Include the outline when measuring: it sits outside `AbsoluteSize`, so two 3 px outlines need more than 6 px between the boxes.
- **Centring:** anything meant to be centred is within **1.5 px** of the centre of what it is centred in, measured.
- **Text size:** text must never be smaller than **14 px** at phone resolution (owner decision). `TextScaled` has no minimum by itself, so always measure it, and set `UITextSizeConstraint.MinTextSize = 14`, plus make sure the box is big enough for its text at that size.

## 5. Test at all four resolutions

| Name | Size |
|---|---|
| Phone | 667 x 375 *(starting value for "phone")* |
| Full HD | 1920 x 1080 |
| 4K | 3840 x 2160 |
| 4:3 | 1024 x 768 *(starting value for "4:3")* |

**How to measure** (tested 2026-11-08): in Play, in the Client data model, make a temporary `ScreenGui` with `IgnoreGuiInset = true`. Add a `Frame` with `UDim2.fromOffset(w, h)` for each resolution, build or clone the UI into it, `task.wait(0.2)`, then read:

- `AbsoluteSize` for thumb size.
- `AbsolutePosition` and `AbsoluteSize` for the touching and centring checks.
- `TextBounds.Y` for the text size. Skip Roblox's own `ProximityPrompts` GUI.

Destroy the test ScreenGui afterwards.

**Limit of this method:** anything that reads `workspace.CurrentCamera.ViewportSize` (like the `UIScale` in `UI.makeWindow`) sees the real Studio window, not the test frame. For those, work out the scale with the same formula for each resolution and set that `UIScale` by hand during the test. Ask the owner to look once in Studio's Device Emulator (phone) for a final visual check, since this method only measures.

## 6. Report

Show a table with one row per resolution: smallest text, smallest button, smallest gap, worst centring error, pass or fail. Then follow the coding skill's report-and-commit steps.
