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
- [ ] Follow-up: move hardcoded tunable values from scripts into `SlopConfig` (Part 3 of the cleanup).

## Step 2: Roblox Studio MCP

- [ ] Install and connect the Roblox Studio MCP server so Claude can read the place, run scripts, and raycast inside Studio.
- [ ] Verify Claude can run a test command in Studio.
- Required for the map measurements and UI preview screenshots.

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
