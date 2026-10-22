# Slop Tycoon Simulator

Roblox tycoon game (Luau) with brainrot-style "Slop" characters. The owner is not a full-time programmer: explain changes plainly, keep edits small and safe, and never guess at things you cannot see in the files.

## How we work

- Source of truth is the files in `src/`. Rojo (`rojo serve`) syncs them into Studio. **Never tell the owner to edit scripts in Studio**; Studio edits to scripts get overwritten.
- `default.project.json` maps `src/ReplicatedStorage`, `src/ServerScriptService` and `src/ServerStorage` to the services of the same name, and `src/StarterPlayerScripts` to `StarterPlayer > StarterPlayerScripts`. Workspace is not mapped.
- The place file (`SlopTycoon.rbxl`) is not tracked in git. It only holds Studio-side settings; everything else is in `src/`.
- Slop 3D models are `.rbxm` files in `src/ServerStorage`. Do not edit them. Config `Model` names must match a file there. `DailyDino` (Daily Drip Dino) has no model file yet (the server warns and uses a block).
- You cannot run the game. The owner tests in Studio and reports screenshots and Output errors. Say clearly what to test after each change.
- **Git:** after a batch of changes, the owner tests in Studio; commit only once they confirm it works. Also commit when a phase ends or a new one begins. Commit messages must clearly describe what was implemented. Never push unless asked.
- The owner does not want unverified instructions. If a step depends on a file you have not read, read it first.
- Leave code comments explaining how to reverse any decision we flagged as reversible.
- Use tabs for indentation. Keep new code consistent with the file it goes in.
- Art is the owner's: you write the code that places and uses assets; you do not generate final art or real 3D meshes.

## Code map

- `SlopServer.server.luau` (Script): builds the whole world procedurally (ground, belt, sidewalk, 8 plots with gap 40, slot machines, slap and rebirth blocks), handles saving (DataStore `SlopTycoonV1`, `DATA_VERSION` 3), rolls, buying, badges, daily rewards, passes and products, income tick, belt events.
- **The place has no baseplate or SpawnLocation.** If `SlopServer` errors before it builds the ground, players fall into the void. Anything that can fail at startup (DataStore, MarketplaceService, etc.) must be wrapped in `pcall`.
- `SlopConfig.luau` (ModuleScript, ReplicatedStorage): rarities, `Config.Mons`, quality tiers, slot machine (`Config.Slot`), roll settings (`Config.Wheel`, a leftover name the slot machine still uses), costs, badges, passes, products, shop items.
- `SlopUI.luau` (ModuleScript): shared UI helpers (`corner`, `stroke`, `label`, `button`, `makeWindow`).
- Client LocalScripts: `SlopClient` (HUD, banners, toasts, Shop UI), `MenuClient` (Inventory, Upgrades, Stats tabs), `SlotClient` (slot machine reels and buy panel), `DailyClient` (daily rewards UI), `DevClient` (DevTools cheat panel).
- Remotes: RemoteEvent `SlopEvent`; RemoteFunctions `SlopMenu`, `SlopDaily` and `SlopDev`.
- Slops are saved as instances `{Id, Mult}`. `Config.Mons` is index-based: **only ever append new Slops at the end** or saves break.
- Unused leftovers: `Config.ExpandCost`, and the belt's buy-straight-to-plot path (`BUY_TO_INVENTORY = true`).
- The `.meta.json` files only hold an empty `SerializedOverrides` from the Studio export; harmless.

## Current features (keep)

- Income: right now every equipped Slop pays straight into the wallet every second (the factory/ATM replaces this in the plot rebuild).
- Slap block on each plot gives a small cash slap; the AutoSlap game pass slaps every second.
- Belt events every 45-90s: Admin Abuse (income x5 for 15s), Raining Brainrot (flooded belt 10s), Belt Rush (belt runs 30s), Lucky Block (free cash). The belt only runs during events.
- Shop UI (SHOP button) lists `Config.ShopItems`.
- On-plot Slop selling (Sell prompt on placed Slops) **stays permanently**, including after the plot rebuild. Selling from the inventory menu also works.
- DevTools: `DevClient` LocalScript + `SlopDev` RemoteFunction. The DEV panel always shows in Studio; in live servers only for UserIds in `Config.DevUserIds`. Using a cheat turns off saving for that player for the session (`Config.DEV_BLOCK_SAVE`). Add a button there whenever a new feature needs quick testing. **Every new upgrade (Slop shop, stars, etc.) must also be reset by the DevTools "resetUpgrades" action** in `SlopServer`.
- Studio Play always runs a private local server, never a live one. It only reads real save data when the place opened in Studio is the published game (File > Open from Roblox) with Studio API access on; a local `.rbxl` has saving off.

## Settled game rules

Each rule is tagged **(built)** or **(not built yet)**. When it is not built, the note says what the code does today.

- Rolls are free with a cooldown. **(built)**
- Cooldown: 15 speed upgrades. Starts at 10s, the first 5 upgrades drop it 1s each to 5s, the next 10 drop it 0.4s each to 1s. **(built: `Config.Wheel` + `Config.RollCooldown`)**
- Roll cap starts at 3, max 10. **(built)**
- Equip slots are bought with rebirth tokens, max 16. **(built)** Start at 4 slots. **(not built yet: code is 5; changes with the plot rebuild, needs `DATA_VERSION` 4 and a save upgrade that moves the 5th Slop to inventory)**
- Every Slop rolls a cash multiplier x1.00 to x1.25 shown as a Quality tier. **(built)** Tiers: Normal 1.00, Good 1.10, Great 1.17, Excellent 1.22, Perfect 1.25 (Perfect = max roll only). **(built)**
- Reels show odds as "1 in X". **(not built yet: reels show emoji)**
- Bought Slops go to inventory first **(built)** and auto-equip if a slot is open. **(not built yet)**
- Rebirth resets inventory and placed Slops. **(built)** Tokens come from rebirthing: 0.002% of cash earned that rebirth minus the rebirth cost, soft cap. **(not built yet: code is 0.002% of cash earned, no minus, no cap)** Token rework is delayed until after the plot rebuild.
- Cash from the factory is collected at the ATM on a large green Collect pad (no cooldown, works on mobile and console). ATM cash is uncapped. HUD shows CASH TO COLLECT. **(not built yet)**
- Multipliers: the Rebirth boost and 2x boost are NOT applied on the belt. They apply at ATM collection and show below the total as "Rebirth boost: +$X" and "2x Cash: +$X" lines. The 2x Cash game pass applies at the ATM and only the final amount is doubled, no separate line. The 2x boost no longer doubles wallet cash. The admin x5 event applies at drop time. **(not built yet: today the pass, boost, rebirth and admin x5 all multiply income per second, and the pass also doubles slaps)**
- Products: `Config.Products.DoubleOffline` is set (50 Robux double-offline product), but offline rewards are not built yet, so it only sets a flag. A larger double-offline game pass is decided in Phase 4.

## Plot rebuild design (next big task)

- Each plot becomes a larger **closed-top** office room (ceiling with neon pipes). Gap between plots is already 40. 4x4 grid of see-through tanks, one per Slop Spot, big enough to hold each Slop model floating inside. Locked spots show nothing. Each tank has a display with its next cash drop and a countdown to the next drop.
- Slot machine stays on the plot's left side (-X), facing in, hex-prism reels (already built that way).
- On-plot Slop selling stays (owner decision, permanent); the tanks need a Sell prompt too.
- Starting slots drop to 4 in the rebuild (see Settled game rules).
- ATM on the back wall: intake side faces the factory, screen faces the room showing a formula and the green total. Collect pad outline is white when cash is ready and gold above $1B.
- Factory starts beyond the old back wall. Winding conveyor that winds more as it grows. Gates change each drop's value and look (e.g. "Flood Gate" makes it wet). Drops are boxes labeled "[SLOP]" in red ACME-style lettering with a dollar amount above that rises per gate. Draw drops on the client with a cap on how many show.
- Tycoon buttons unlock factory pieces. First ten proposed in the roadmap doc (Power Switch, Slop Squeezer, Flood Gate, Greasy Rails, First Bend, Goo Injector, Second Bend, Slop Polisher, Overclocked Motors, Big Brain Gate).
- **Gate rules (decided):** a button is either a **drop gate** (adds to the cash value of every drop passing it; drop gates add together) or a **Slop buff** (raises every equipped Slop's base cash, shown on its tank). Total = Slop cash x (1 + Slop buffs) x (1 + drop gates). The first 3 gates are +5%. Gates get stronger over time but never above +10% each, and +10% is first reached in factory section 3. Long-term aim is about x2.5 over 20 gates.
- **Slop buffs (decided):** always multiples of 5%. Two per factory section: section 1 buffs are +5% each, section 2 +10% each, and so on.
- **Section 1 button table (decided):**

  | # | Button | Effect | Cost |
  |---|---|---|---|
  | 1 | Power Switch | Drop +5% | $13K |
  | 2 | Slop Squeezer | Drop +5% | $21K |
  | 3 | Flood Gate | Drop +5% (wet look) | $34K |
  | 4 | Greasy Rails | Slop buff +5% | $55K |
  | 5 | First Bend | Drop +6% (conveyor bends) | $88K |
  | 6 | Goo Injector | Drop +6% | $140K |
  | 7 | Second Bend | Drop +7% (bends again) | $225K |
  | 8 | Slop Polisher | Slop buff +5% | $360K |
  | 9 | Overclocked Motors | Drop +8% | $575K |
  | 10 | Big Brain Gate | Drop +8% | $921K |

  At button 10: drops x1.50, Slops x1.10, about x1.65 total. Costs rise 1.6x per button (~$2.43M total).
- **The factory runs from the start (decided).** Power Switch is just the first +5% gate, not an on switch.
- **Balance target (decided):** in the first life with 0 rebirths, a player with **4 average Epic Slops** (~$1,890/s) maxes the 10th button in about 15 minutes, then saves for the first rebirth in about 5 more minutes. Other teams are slower or faster by design (2 Rare + 2 Epic ~27 min, 4 average Rare ~2 h).
- **Rebirth and the factory (decided):** rebirth resets all factory buttons. Maxing the factory is **not** required to rebirth.
- **First rebirth cost (decided): about $1M** (5 min at ~$3,120/s with 4 average Epic Slops and a maxed section 1), still x3 per rebirth. Change `Config.RebirthCost` in build step 3 together with the buttons, not before (without the factory it would make rebirth too slow).
- Balance math method: simulate a player buying each button as soon as they can afford it, and tune the first cost so the 10th button lands at 15 min.

## Plot rebuild build order

Each step is tested in Studio and committed before the next starts.

1. **Office room + tanks:** closed-top room with neon-pipe ceiling, 4x4 see-through tanks with Slops floating inside, and each tank showing its next drop and countdown. Income still goes straight to the wallet. On-plot Sell prompts move onto the tanks.
2. **Factory + ATM:** conveyor beyond the back wall, client-drawn "[SLOP]" drop boxes (capped count), ATM on the back wall, Collect pad, CASH TO COLLECT HUD. Income moves to the ATM.
3. **Buttons + gates:** the section 1 table above, rebirth resets buttons, `Config.RebirthCost` to ~$1M, DevTools buttons to buy and reset factory buttons (add to `resetUpgrades`).
4. **Finish:** Rebirth and 2x boost/pass applied at the ATM with their lines, admin x5 at drop time, 4 starting slots with `DATA_VERSION` 4 and the save upgrade.

## Progress log

- **2026-10-22:**
  - Fixed falling into the void: `GetDataStore` is now in a `pcall`. It errored in a local `.rbxl` and stopped `SlopServer` before the world was built.
  - Added DevTools: cash, tokens, rebirths, cooldown reset, events, any Slop at any quality, reset all upgrades.
  - Server events moved into `runEvent`.
  - `SlopTycoon.rbxl` is no longer tracked in git.
  - Quality tiers and the 15-level roll cooldown now match the settled rules.
  - Ran the section 1 balance math and settled the gate rules, button table and rebirth target.
  - **Next:** start build step 1 when the owner says go.
- Token prices should keep players spending tokens until roughly rebirth 20, and be very expensive.

## Badges

- Live and wired in code: Welcome, FirstExpand, FirstSlop, Legendary, FirstRebirth, Mythic, Secret, MaxedSpots, FullPlot, Rebirth5 (IDs in `Config.Badges`).
- ATM lump ladder: one big collect awards every badge at or below its size at once. Needs **10** badges: $100, $1K, $10K, $100K, $1M, $10M, $1B, $1T, plus quadrillion and quintillion. **(not built yet; no badges created)** Badge creation is limited to five a day.

## Later phases and owner notes

- Auto-Roll menu (modes: Count, Rarity, Quality, Rarity and Quality), greyed out until the pass is owned. Perma Slop Slot. Index with silhouettes, possible first-time claim reward per entry, extra reward per star (max 3 or 5). Robux map spawns.
- Map spawns are a small version of the Slop, about half stuck in the ground. When modifiers exist, map-spawned Slops get an exclusive tag such as "Stranded" or "Lone Wolf", and if they spawn during an event or weather that gives a modifier (the `Type` field in the code), they also carry that modifier.
- Modifiers (`Type` is the placeholder name): rolled or bought during events or weather, each with a set effect (e.g. "Golden": about +20% cash drop). Comes after Phase 4.
- Wide Noob: bald, faceless politician-lookalike Secret Slop, Phase 4. Mythic joins the Day 7 daily pool after first claim (Phase 4). Daily Drip Dino is the first-claim Day 7 reward (Special rarity).
- Custom models for every Slop. A new tier directly above Legendary, crafted from 3 Perfect Epic Slops (name TBD). More Slops below Legendary.
- World2/World3 (commented out in `SlopServer`) are not planned; the commented code can be removed. The Rebirth5 badge comment ("unlocks the second world") is out of date.
- Idea (undecided): unsecured cash that other players can steal if they pay Robux or sneak into the factory, with security upgrades and a "JAILBREAK" event.
- Full notes and open questions live in the Google Doc "Slop Tycoon Simulator: Roadmap" (owner's copy).
