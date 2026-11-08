---
name: coding
description: Checklist for any change to the game's Luau code in src/ (SlopServer, SlopConfig, the client scripts). Use it before editing a script and again before calling the task done. It covers config centralization, code style, the three required checks (rojo build, selene, stylua), the Studio play-test through the Roblox Studio MCP, and how to report and commit.
---

# Coding checklist (Slop Tycoon)

Use this for every task that changes a `.luau` file in `src/`. CLAUDE.md has the background; this is the order to work in.

## 1. Before editing

- Read the code you are about to change, and anything it depends on. Never guess at a file you have not read.
- Find every place a value is used before moving or renaming it (search the whole of `src/`, server and client).
- Edit the files in `src/` only. Never edit scripts in Studio, and never use the Studio MCP's `multi_edit` on scripts: Rojo overwrites Studio edits.

## 2. While editing

**Config centralization.** Tunable values live in `src/ReplicatedStorage/SlopConfig.luau`, never typed into a script:

- Speeds, costs, timers, durations, chances, distances, reach and hold times, caps, payouts, jump power, sizes.
- Put them in the matching section: "GAMEPLAY TUNING" (`Config.Events`, `Config.Reach`, `Config.Hold`, `Config.Drops`, ...) or `Config.Layout`. Start a new, clearly named table if none fits.
- A script may keep a short local name for a config value (`local SPEED = Config.BELT_SPEED`). That's fine, and it keeps the change small.
- Text that shows a number (banners, button labels) is built from the config value, so it can never disagree with the game.
- Allowed to stay in scripts: UI pixel sizes and tween times (the UI skill covers those), values worked out from other values (`PLOT_PITCH`, `CEIL_Y`, ...), `DAY = 86400`, and the reel width and spacing `REEL_W`, `REEL_STEP` (owner decision).
- When you touch code that still has a hardcoded tunable, move it.

**Style:**

- Tabs for indentation. Match the file you are in (for example, strings are joined with `..`, not backtick strings).
- `Config.Mons` is index-based: only ever append new Slops at the end.
- Lined-up tables in `SlopConfig` (`Rarities`, `Mons`, `DailyRewards`) sit between `-- stylua: ignore start` / `-- stylua: ignore end`. Line new rows up by hand.
- Wrap anything that can fail at startup (DataStore, MarketplaceService, ...) in `pcall`. The place has no baseplate, so a startup error drops players into the void.
- Every new upgrade must also be reset by the DevTools `resetUpgrades` action in `SlopServer`. Add a DevTools button when a new feature needs quick testing.
- Leave a comment explaining how to reverse any decision the owner flagged as reversible.
- Never commit API keys or secrets. They go in `.env` (gitignored).

## 3. Required checks (all three must pass)

Run from the repo root, after formatting:

```bash
stylua src && rojo build -o build-check.rbxl && selene src && stylua --check src
```

- `rojo build -o build-check.rbxl` must build (the root `*.rbxl` is gitignored).
- `selene src` must show 0 errors and 0 warnings.
- `stylua --check src` must pass.
- If you edited with Git Bash `sed -i`, it strips CRLF line endings. Running `stylua src` puts them back.

The task is not done until all three pass. If one fails, fix it; don't report the task as done.

## 4. Play-test in Studio (Roblox Studio MCP)

If the `Roblox_Studio` MCP tools are available and Studio is open with Rojo syncing:

1. `list_roblox_studios` to get the `studio_id`.
2. Confirm Rojo synced your change: in the Edit data model, check that the script's `Source` contains a string from your edit.
3. `start_stop_play` (start), then test the change with `execute_luau`:
   - Server data model: read values, prompts, attributes and parts.
   - Client data model: do what a player would. Use the `SlopDev` RemoteFunction the same way the DEV panel does (`"slop"`, `"event"`, ...) and `SlopMenu` for menu actions. Fire a prompt with `InputHoldBegin()` / `InputHoldEnd()` after moving the character next to it.
4. Changes meant to keep behaviour the same: measure **before** and **after**. For layout or world changes, fingerprint every part's name, position and size into a hash before the edit and compare after.
5. `get_console_output` and check for new errors. The DataStore lines are normal in a local `.rbxl`, and the `rbxassetid://203785492` warning is already there (it's not from `src/`).
6. `start_stop_play` (stop) when done. Play mode doesn't pick up edits made while it is running: stop, check that Rojo synced, then start again.

If the MCP isn't available, say so, and give the owner exact steps to test in Studio.

## 5. Report, then commit

- Show the owner what changed (in plain words), the check results, and the play-test results, including anything **not** tested.
- If the work shows that a doc or the plan is wrong, say so, and fix it in the same change.
- Commit only after the owner confirms. Commit on the current branch with a message that clearly describes what was implemented. Never push unless asked.
- Handoff notes (date, what was done, what changed, problems, what's next):
  - **While the AI setup is still in progress** (`docs/ai-setup-plan.md` has unticked steps): setup work goes in that file's Handoff log, and you tick its box there.
  - **Once the AI setup is finished**, and for all game work: add the entry to the **Progress log** in `CLAUDE.md`. `docs/ai-setup-plan.md` is only for the setup process, so don't add new notes there.
