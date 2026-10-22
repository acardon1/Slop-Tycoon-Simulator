# Slop Tycoon Simulator

Roblox tycoon game (Luau) with brainrot-style "Slop" characters. The owner is not a full-time programmer: explain changes plainly, keep edits small and safe, and never guess at things you cannot see in the files.

## How we work

- Source of truth is the files in `src/`. Rojo (`rojo serve`) syncs them into Studio. **Never tell the owner to edit scripts in Studio**; Studio edits to scripts get overwritten.
- `default.project.json` maps: `src/ReplicatedStorage`, `src/ServerScriptService`, `src/ServerStorage`, `src/StarterPlayer/StarterPlayerScripts` (`src/StarterPlayerScripts`).
- Slop 3D models are `.rbxm` files in `src/ServerStorage`. Do not edit them. Config `Model` names must match a file there. `DailyDino` (Daily Drip Dino) has no model file yet.
- You cannot run the game. The owner tests in Studio and reports screenshots and Output errors. Say clearly what to test after each change.
- Commit to git after each working change so it can be undone. Do not push or commit unless asked.
- The owner does not want unverified instructions. If a step depends on a file you have not read, read it first.
- Leave code comments explaining how to reverse any decision we flagged as reversible (e.g. on-plot Slop selling was removed).
- Use tabs for indentation. Keep new code consistent with the file it goes in.
- Art is the owner's: you write the code that places and uses assets; you do not generate final art or real 3D meshes.

## Code map

- `SlopServer.server.luau` (Script): builds the whole world procedurally (8 plots, belt, sidewalk), handles saving (DataStore `SlopTycoonV1`, `DATA_VERSION` 3), rolls, buying, badges, daily rewards.
- `SlopConfig.luau` (ModuleScript, ReplicatedStorage): rarities, `Config.Mons`, quality tiers, slot machine, costs, badges, passes, products.
- `SlopUI.luau` (ModuleScript): shared UI helpers (`corner`, `stroke`, `label`, `button`, `makeWindow`).
- Client LocalScripts: `SlopClient` (HUD), `MenuClient` (Inventory, Upgrades, Stats tabs), `SlotClient` (slot machine reels and buy panel), `DailyClient` (daily rewards UI).
- Remotes: RemoteEvent `SlopEvent`; RemoteFunctions `SlopMenu` and `SlopDaily`.
- Slops are saved as instances `{Id, Mult}`. `Config.Mons` is index-based: **only ever append new Slops at the end** or saves break.
- The session may be partly out of sync with chat history: check that features discussed (slot machine rewrite, plot gap 40, Config.Slot additions) actually exist in the files before building on them.

## Settled game rules

- Rolls are free with a cooldown. Cooldown starts at 10s; each early upgrade drops it 1s until 5s, then 0.5s per upgrade after that. Roll cap starts at 3, max 10.
- Equip slots are bought with rebirth tokens, max 16. **Start at 4 slots** (code may still say 5).
- Every Slop rolls a cash multiplier x1.00 to x1.25 shown as a Quality tier: Normal 1.00, Good 1.10, Great 1.17, Excellent 1.22, Perfect 1.25 (Perfect = max roll only).
- Reels show odds as "1 in X".
- Bought Slops go to inventory first and auto-equip if a slot is open.
- Rebirth resets inventory and placed Slops. Tokens come from rebirthing (0.002% of cash earned that rebirth minus the rebirth cost, soft cap); token rework is delayed until after the plot rebuild.
- Cash from the factory is collected at the ATM on a large green Collect pad (no cooldown, works on mobile and console). ATM cash is uncapped. HUD shows CASH TO COLLECT.
- Multipliers: the Rebirth boost and 2x boost are NOT applied on the belt. They apply at ATM collection and show below the total as "Rebirth boost: +$X" and "2x Cash: +$X" lines. The 2x Cash game pass (placement decided): applies at the ATM and only the final amount is doubled, no separate line. The 2x boost no longer doubles wallet cash. The admin x5 event applies at drop time.
- Placeholders: `Config.Products.DoubleOffline = 0` (50 Robux double-offline product), a larger double-offline game pass decided in Phase 4.

## Plot rebuild design (next big task)

- Each plot becomes a larger **closed-top** office room (ceiling with neon pipes). Gap between plots doubled to 40. 4x4 grid of see-through tanks, one per Slop Spot, big enough to hold each Slop model floating inside. Locked spots show nothing. Each tank has a display with its next cash drop and a countdown to the next drop.
- Slot machine stays on the plot's left side (-X), facing in, hex-prism reels.
- On-plot Slop selling is removed (sell from the inventory menu only).
- ATM on the back wall: intake side faces the factory, screen faces the room showing a formula and the green total. Collect pad outline is white when cash is ready and gold above $1B.
- Factory starts beyond the old back wall. Winding conveyor that winds more as it grows. Gates change each drop's value and look (e.g. "Flood Gate" makes it wet). Drops are boxes labeled "[SLOP]" in red ACME-style lettering with a dollar amount above that rises per gate. Draw drops on the client with a cap on how many show.
- Tycoon buttons unlock factory pieces. First ten proposed in the roadmap doc (Power Switch, Slop Squeezer, Flood Gate, Greasy Rails, First Bend, Goo Injector, Second Bend, Slop Polisher, Overclocked Motors, Big Brain Gate). **Owner wants multipliers toned down:** flat additive ~+10% steps totaling about x2.5 by the 10th gate (or 20th) using the existing numbers.
- **Balance target (run the math before building):** in the first life with 0 rebirths, a player with 4 Rare or Epic Slops should max the factory (10th button) in about 15 minutes of play, then save for the first rebirth in about 5 more minutes. Add a note on whether players must max the factory before each rebirth.
- Token prices should keep players spending tokens until roughly rebirth 20, and be very expensive.

## Badges

- Live: Welcome, FirstExpand, FirstSlop, Legendary, FirstRebirth.
- Wired with IDs (verify in config): Mythic 2314593998507058, Secret 4021308275331040, MaxedSpots 1219058499510125, FullPlot 41422785915715, Rebirth5 3718036976376138.
- ATM lump ladder: one big collect awards every badge at or below its size at once. Needs **10** badges: $100, $1K, $10K, $100K, $1M, $10M, $1B, $1T, plus quadrillion and quintillion. Badge creation is limited to five a day.

## Later phases and owner notes

- Auto-Roll menu (modes: Count, Rarity, Quality, Rarity and Quality), greyed out until the pass is owned. Perma Slop Slot. Index with silhouettes, possible first-time claim reward per entry, extra reward per star (max 3 or 5). Robux map spawns.
- Map spawns are a small version of the Slop, about half stuck in the ground. When modifiers exist, map-spawned Slops get an exclusive tag such as "Stranded" or "Lone Wolf", and if they spawn during an event or weather that gives a modifier (the `Type` field in the code), they also carry that modifier.
- Modifiers (`Type` is the placeholder name): rolled or bought during events or weather, each with a set effect (e.g. "Golden": about +20% cash drop). Comes after Phase 4.
- Wide Noob: bald, faceless politician-lookalike Secret Slop, Phase 4. Mythic joins the Day 7 daily pool after first claim (Phase 4). Daily Drip Dino is the first-claim Day 7 reward (Special rarity).
- Custom models for every Slop. A new tier directly above Legendary, crafted from 3 Perfect Epic Slops (name TBD). More Slops below Legendary.
- Idea (undecided): unsecured cash that other players can steal if they pay Robux or sneak into the factory, with security upgrades and a "JAILBREAK" event.
- Full notes and open questions live in the Google Doc "Slop Tycoon Simulator: Roadmap" (owner's copy).
