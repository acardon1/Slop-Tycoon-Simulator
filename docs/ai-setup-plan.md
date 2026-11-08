# AI Development Setup Plan — Slop Tycoon

Roadmap for setting up AI-assisted development on this repo. Work through the steps in order; most later steps depend on earlier ones.

**Shared vs. personal:** Steps 1–5 are shared setup for all developers. Step 6 (local 3D generation) is optional and for the project owner only. Don't include it in setup instructions for other developers.

**How to use this file (for Claude Code):** Read this before starting setup work. When you finish a task, tick its box, and add an entry to the **Handoff log** at the bottom.

## Environment

- Windows, Git Bash
- PC: RTX 5070 (12 GB VRAM), 32 GB RAM. This is the stated minimum for local 3D generation. The card is newer-generation (Blackwell), so it needs recent CUDA / PyTorch builds.
- Rojo is already set up. Two developers share this repo, and both use Claude.
- Claude Code runs **locally** in the repo folder, from the desktop app's Code tab. It must be local, not cloud, so MCPs can reach Studio and Blender.

---

## Step 1: Base (toolchain + rules)

- [x] Install a pinned toolchain with Rokit (`rokit.toml`): rojo, selene, stylua. Match the rojo version already in use.
- [x] Add `selene.toml` (roblox std) and `stylua.toml`.
- [x] Create `CLAUDE.md` with the core rules (see the Coding skill below). *(CLAUDE.md already existed; the rules were added as a new "AI setup and checks" section.)*
- [x] Add `.env` to `.gitignore` for API keys.
- [x] Commit on branch `ai-setup` for partner review.
- [x] Follow-up: clean up the existing code so selene and `stylua --check` pass (done 2026-11-08, see the handoff log).
- [x] Follow-up: move hardcoded tunable values from scripts into `SlopConfig` (Part 3 of the cleanup). List below, approved by the owner on 2026-11-08. *(done 2026-11-08, both batches)*

### Part 3: values to move into `SlopConfig`

Behaviour must stay the same: same numbers, only their home changes. Line numbers drift, so find each one by name or search.

- [x] **Batch 1: groups A + B + D** (one commit after a Studio play-test) *(done 2026-11-08, see the handoff log)*
- [x] **Batch 2: group C** (separate commit; check the layout in Studio with the MCP) *(done 2026-11-08; the reel width/spacing `REEL_W`, `REEL_STEP` stay in `SlopServer`, owner decision)*

**A. Gameplay (SlopServer)**

| Now in script | Value | What it is |
|---|---|---|
| `SPEED` | 10 | belt speed (studs/s) |
| `START_SLOTS` / `MAX_SLOTS` | 5 / 16 | equip slots. `Config.SlotCost` also hardcodes the 5 (`slots - 5`); make it use the new value |
| `NUM_PLOTS` | 8 | plots per server |
| `DROP_SPEED` | 6 | conveyor drop speed (also sent to clients as the `DropSpeed` attribute) |
| autosave `task.wait(60)` | 60 | autosave interval |
| income tick `task.wait(1)` | 1 | income tick |
| Collect pad loop `task.wait(0.2)` | 0.2 | Collect-pad check rate |
| belt spawner `raining and 0.45 or (1.7 + math.random() * 0.5)` | 0.45 / 1.7 + 0–0.5 | belt spawn gap (raining / normal) |
| `runEvent` AdminAbuse: `adminMult = 5`, `task.wait(15)` | 5, 15s | Admin Abuse |
| `runEvent` Rain: `task.wait(10)` | 10s | Raining Brainrot |
| `runEvent` BeltRush: `task.wait(30)` | 30s | Belt Rush |
| LuckyBlock: `math.max(100, incomePerSec(p) * 60)` | min $100, 60s of income | Lucky Block gift |
| event loop `math.random(45, 90)` | 45–90s | gap between events |
| event loop `r < 0.3 / 0.55 / 0.8` | 30/25/25/20% | event odds (Admin / Rain / Rush / Lucky) |
| `slapValue`: `2 + baseInc(p) * 0.05` | $2 + 5% of base income | slap payout |

The event banners have "x5", "15s", "10s", "30s" typed into the text. Build that text from the config values so it can't disagree with the event.

**B. Prompt and click reach (`MaxActivationDistance`, `HoldDuration`)**

| Where | Value |
|---|---|
| default prompt (`mkPrompt`) | 14 |
| slot machine lever | 18 |
| slap block ClickDetector | 24 |
| tank Sell prompt | 8 (hold 0.3s) |
| slot machine offer Buy prompt (the Slop in front of a reel; first listed here as the belt Buy prompt by mistake. The belt Buy prompt uses the default 14) | 12 (hold 0.4s) |
| slot machine click (SlotClient) | 80 |

**C. World and plot layout (SlopServer top, "Layout Settings" and below)**

`PLOT_W` 56, `PLOT_D` 60, `PLOT_GAP` 40, `PLAZA` 14, `CURB_W` 1, `BELT_W` 8, `EDGE_PAD` 50, `ROOM_H` 16, `DOOR_W/H` 16/11, `TANK_PITCH` 10, `TANK_W` 6, `TANK_BASE_H` 3, `TANK_GLASS_H` 8, `FACTORY_D` 44, `YARD_WALL_H` 7, `BACK_DOOR_W/H` 8/10, `BACK_DOOR_DX` -14, `ATM_DX` 4, `ATM_W/H/D` 8/10/6, `PAD_W/D` 12/6, `BELT_Y` 3, `DROP_BOX` 2, reel `HEX_S` 3, reel `RY` 7.75.

**D. Client**

| Where | Value | What it is |
|---|---|---|
| PlotClient `MAX_PER_TICK` | 4 | boxes per plot per drop |
| PlotClient `MAX_PER_PLOT` / `MAX_BOXES` | 30 / 120 | box caps |
| PlotClient `DRAW_RANGE` | 300 | box draw distance |
| PlotClient `BOX_SIZE` | 2 | copy of the server's `DROP_BOX`; point both at one config value |
| SlopClient `FAR_FROM_BASE` | 60 | when the BASE pop-up shows |

**Leave in the scripts:** UI pixel sizes and tween times (`PANEL_W`, 0.2s/0.8s tweens, UI refresh loops; the UI skill will cover them), values calculated from others (`PLOT_PITCH`, `CEIL_Y`, ...), and `DAY = 86400`.

## Step 2: Roblox Studio MCP

- [x] Install and connect the Roblox Studio MCP server so Claude can read the place, run scripts, and raycast inside Studio.
- [x] Verify Claude can run a test command in Studio. *(Verified 2026-11-08: `execute_luau` in Edit mode returned the Workspace child count.)*
- Required for the map measurements and UI preview screenshots.

**How it's set up:** Studio has a built-in MCP server ([Roblox docs](https://create.roblox.com/docs/en-us/studio/mcp)); the old standalone `studio-rust-mcp-server` is retired, don't use it. The repo's `.mcp.json` registers it for Claude Code as `Roblox_Studio`, using the same command Studio's MCP panel shows. Each developer, once:
1. In Studio: **Assistant** > **…** > **Manage MCP Servers** > turn on **Enable Studio as MCP server**.
2. Approve the `Roblox_Studio` server when Claude Code asks (or add `"enabledMcpjsonServers": ["Roblox_Studio"]` to `.claude/settings.local.json`, which is gitignored).
3. Start a new Claude Code session; MCP tools load only at session start. Studio's MCP panel shows a green dot when a client is connected.

Useful tools it gives: `execute_luau` (run code in Edit, Server or Client), `start_stop_play`, `get_console_output`, `screen_capture`, `search_game_tree`, `inspect_instance`, `character_navigation`. It can also edit scripts in Studio (`multi_edit`); **don't use that here**, since scripts live in `src/` and Rojo would overwrite Studio edits.

## Step 3: Skills (rules Claude follows automatically)

Skills live in the repo (`.claude/skills/`) so both developers get them.

### Coding skill (TO MAKE)

Every coding task must pass these checks, at minimum, before it counts as done:

- [ ] **Rojo build:** `rojo build` succeeds
- [ ] **Linter:** `selene` passes
- [ ] **Formatter:** `stylua --check` passes
- [ ] **Config centralization:** move as much config as possible into the single config file in the code. Tunable values (speeds, costs, timers, jump power, etc.) live there and are never hardcoded in scripts.

### UI skill (TO MAKE)

- When UI is suggested, show a **preview image**.
- Create the actual UI file somewhere in the codebase so it can be uploaded later.
- Show the part of the script that builds the UI, with comments.
- **Depth stack** for UI elements:
  - Shadow below each element, shifted slightly blue
  - Gradient on the face
  - Lift from the top
  - Outline the same thickness everywhere
- **Test resolutions:** phone, Full HD (1920×1080), 4K, and 4:3.
- Buttons big enough for thumbs.
- No UI elements touch each other.
- Anything meant to be centered is measured to within 1.5 px.
- Text must never shrink below a readable minimum size.

### Map audit skill (TO MAKE)

A map is a real 3D space players move through, not just a pile of parts. Questions to answer: How do you get there? How do you get back? Can you cross certain gaps? How long do you fall?

**Measurement:**

- Use raycasts plus real movement numbers to produce actual measurement data.
- Read jump height and walkspeed from the game's config.
- Every number is clearly labeled, with its source: *from game config*, *measured (raycast)*, *calculated*, or *guessed*.

Example report:
- WalkSpeed: 16 *(game config)*
- Jump height: 7.2 studs *(calculated from JumpPower + gravity in config)*
- Gap A→B: 11.4 studs *(measured, raycast)*
- Verdict: not jumpable *(calculated)*

**Quality-of-life checks:**

- [ ] No floating platforms without a reason
- [ ] No roofs that players can't stand on
- [ ] No unreachable high ground
- [ ] Blocked areas are truly blocked: if a player shouldn't reach a region, test that they really can't
- [ ] No pockets where a player can get stuck with no exit route
- [ ] No overlapping parts
- [ ] Sight lines aren't too constricted. Fan raycasts from eye height along paths and flag spots where view distance drops too low (the space feels claustrophobic or confusing).
- [ ] No awkward in-between drops. A height change should be either a small step or clearly a fall, not something in between (a default character is about 5 studs tall).

## Step 4: Image generation + upload

- [ ] Cloudflare Workers AI API: Flux Schnell for image generation (free tier).
- [ ] Roblox Open Cloud API: upload images and models directly.
- [ ] API keys stay in `.env` and are never committed.

## Step 5: Blender

- [ ] Install Blender (for checking out models, and for learning them).
- [ ] Install the Blender MCP add-on and connect it to Claude.

## Step 6: Local 3D generation (OPTIONAL, project owner only)

> **Not part of the shared setup.** This step is only for the project owner's machine (it needs a 12 GB+ VRAM GPU). Other developers skip it. Do not add it to CLAUDE.md, shared setup instructions, rokit.toml, or any required checks, and nothing else in the project may depend on it being installed.

This is the biggest item, so do it last. Build as an MCP. Start with image → 3D only, and add the rest only if the raw output isn't good enough.

**Image → 3D: TRELLIS.2 (`microsoft/TRELLIS.2-4B`), run stage by stage:**
1. RMBG-2.0 removes the background (only for images without transparency).
2. DINOv3 turns the image into conditioning features (512, plus 1024 for the cascade).
3. The sparse-structure flow and its decoder make the coarse voxel layout.
4. The shape flows (512 and 1024) and the shape decoder (SC-VAE) make the mesh.
5. The texture flows (512 and 1024) and the texture decoder make the PBR colours.

**Text → image (ComfyUI, in front of tbatch):** FLUX.2 [klein] 4B in FP8, with its Qwen3-4B text encoder and the FLUX.2 VAE. Handles text_to_image and the re-pose edit for rigging pictures.

**Quad export (opt-in):**
- SAM 2.1 Hiera Large (`facebook/sam2.1-hiera-large`; base+ is an option) splits the model into parts for part-based quad sizes.
- ViTPose+ base (`usyd-community/vitpose-plus-base`) finds the joints for animation focus, hands, and joint rings.
- QuadWild (with Blender's QuadriFlow as fallback), plus Blender for UVs and packaging.

---

## Open questions

- [x] Confirm what "no falls shorter than the Roblox ragdoll model" means. **Resolved (2026-11-08):** a height change should be either a small step or clearly a fall, never an awkward in-between drop (a default character is about 5 studs tall). See the last map audit check.

## Handoff log

At the end of each Claude Code session, add an entry: date, what was done, what changed, any problems, what's next.

<!-- Example:
### 2026-11-07
- Done: Step 1 toolchain + CLAUDE.md, on branch ai-setup
- Changed: added rokit.toml, selene.toml, stylua.toml, CLAUDE.md
- Issues: selene flagged 40 warnings in old scripts (not fixed yet)
- Next: Step 2, Studio MCP
-->

### 2026-11-08
- **Done:** Step 1 on branch `ai-setup` (branched from `phaseTwo`). Rokit 1.2.0 installed; tools pinned: rojo 7.7.1 (matches the version already in use), selene 0.32.0, stylua 2.6.0. Resolved the ragdoll/fall open question. Moved this plan from the repo root to `docs/`.
- **Changed:** added `rokit.toml`, `selene.toml`, `stylua.toml`, `docs/ai-setup-plan.md`; edited `CLAUDE.md` (new "AI setup and checks" section) and `.gitignore` (`.env`, `.env.*`).
- **Check results:** `rojo build` passes. `selene src`: 0 errors, 61 warnings (47 several statements on one line, 11 `UDim2.new` that could be `fromScale`/`fromOffset`, 3 unused variables: `fetchedAt` in MenuClient, `beltEdgeA1`/`beltEdgeB1` in SlopServer). `stylua --check src`: fails on all 9 scripts, mostly because it removes the lined-up spacing in tables like `Config.Mons`. PlotClient shows the most because its file uses LF line endings, unlike the others.
- **Problems:** no code was reformatted or fixed (waiting for the owner's OK). About 35 tunable constants are still hardcoded in scripts instead of `SlopConfig`. Partner needs to install Rokit and run `rokit install`.
- **Next:** owner decides on the cleanup (format all files, fix or silence the selene warnings), then Step 2: Roblox Studio MCP.

### 2026-11-08 (cleanup)
- **Done:** formatted every script with StyLua and fixed all selene warnings. `rojo build`, `selene src` (0 warnings) and `stylua --check src` all pass. Behaviour is meant to be unchanged.
- **Changed:** all 9 scripts in `src/`. `SlopConfig` keeps `Rarities`, `Mons` and `DailyRewards` one row per entry with `-- stylua: ignore` markers. 11 `UDim2.new` calls became `fromScale`/`fromOffset`; removed unused `fetchedAt` (MenuClient) and the unused `beltEdgeA1`/`beltEdgeB1` names (SlopServer; the belt edges are still built). CLAUDE.md status note updated.
- **Problems:** needs a Studio play-test before commit. Git Bash `sed -i` strips CRLF line endings; run `stylua src` afterwards to restore them.
- **Next:** Part 3, moving hardcoded tunables into `SlopConfig`, then Step 2: Roblox Studio MCP.

### 2026-11-08 (Step 2)
- **Done:** connected Roblox Studio's built-in MCP server to Claude Code. `claude mcp list` shows `Roblox_Studio ✔ Connected`.
- **Changed:** added `.mcp.json` (shared server config); `.gitignore` now ignores `.claude/settings.local.json` (personal approval of the server).
- **Problems:** the session that set it up can't use the tools (they load at session start), so the Studio test command is not verified yet.
- **Next:** in a new session with Studio open and the MCP server enabled, run a test command (e.g. `execute_luau` printing the workspace children count), tick the verify box, commit. Then Part 3: move hardcoded values into `SlopConfig` (the list is ready, waiting for the owner's OK).

### 2026-11-08 (Step 2 verified)
- **Done:** verified the Studio MCP from a fresh session. `list_roblox_studios` found one Studio (`SlopTycoon`); `execute_luau` in the Edit data model returned `Workspace children: 2, place: SlopTycoon`. Ticked the verify box and committed Step 2 on `ai-setup` (not pushed).
- **Changed:** `docs/ai-setup-plan.md` only (verify box, this entry). Committed with the earlier Step 2 files: `.mcp.json` and the `.gitignore` line for `.claude/settings.local.json`.
- **Problems:** none. Only Edit mode was tested; Server/Client modes need a running play session (`start_stop_play`).
- **Next:** Part 3 of the cleanup (move hardcoded tunables into `SlopConfig`, waiting for the owner's OK), then Step 3: skills.

### 2026-11-08 (Part 3, batch 1)
- **Done:** moved groups A, B and D into a new "GAMEPLAY TUNING" section of `SlopConfig` with the same numbers. Event banners and the DEV "Admin x5" button now build their text from `Config.Events`. Events are picked by weight (same 30/25/25/20 odds). `Config.SlotCost` uses `Config.START_SLOTS`. Server and PlotClient share `Config.Drops.BoxSize`.
- **Changed:** `SlopConfig`, `SlopServer`, `PlotClient`, `SlopClient`, `SlotClient`, `DevClient`.
- **Play-test (Studio MCP):** 8 plots; reach and hold values unchanged (lever 18, slap 24, default 14, tank Sell 8/0.3s, offer Buy 12/0.4s, reel click 80); Belt Rush, Admin Abuse and Lucky Block banners correct; Lucky Block paid about 60s of income; income tick about 1.0s; drop boxes size 2; BASE pop-up hidden at 55 studs, shown at 65. No new Output errors. Not tested: autosave (saving is off in a local file), Raining Brainrot.
- **Problems:** the plan listed the 12/0.4s prompt as the belt Buy prompt; it is the slot machine offer Buy prompt (key named `OfferBuy`, table corrected). A repeated `rbxassetid://203785492 … Asset type does not match` warning in Output comes from the place or a model, not from `src/`; not looked into yet.
- **Next:** batch 2 (group C, world and plot layout), checking the layout in Studio with the MCP.

### 2026-11-08 (Part 3, batch 2)
- **Done:** moved group C into `Config.Layout` with the same numbers; `SlopServer` keeps its own names (`PLOT_W`, `ROOM_H`, ...) read from it, and values worked out from them stay in the script. Part 3 is finished.
- **Changed:** `SlopConfig`, `SlopServer`, `CLAUDE.md` (config note updated, map note added).
- **Layout check (Studio MCP):** fingerprint of every part's name, position and size before and after: 771 parts, hash `1773248259` both times; 61 world GUIs both times; same conveyor paths on all 8 plots. No new Output errors.
- **Owner decisions:** the reel width/spacing (`REEL_W`, `REEL_STEP`) stay in `SlopServer`. A real map is coming soon to replace the procedural parts, so the layout values are short-lived; don't spend effort polishing them.
- **Next:** Step 3, skills (Coding skill first).
