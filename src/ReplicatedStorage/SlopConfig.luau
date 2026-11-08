-- ModuleScript named "SlopConfig"
-- Put it in: ReplicatedStorage

local Config = {}

-- The "stylua: ignore" markers below keep these tables as one lined-up row per entry.
-- Without them StyLua spreads each entry over many lines.
-- To reverse: delete the "-- stylua: ignore start" / "-- stylua: ignore end" lines and run `stylua src`.

-- stylua: ignore start
Config.Rarities = {
	{ Name = "Common",    Color = Color3.fromRGB(127, 152, 166), Weight = 60 },
	{ Name = "Rare",      Color = Color3.fromRGB(47, 147, 232),  Weight = 25 },
	{ Name = "Epic",      Color = Color3.fromRGB(162, 79, 224),  Weight = 10 },
	{ Name = "Legendary", Color = Color3.fromRGB(240, 165, 0),   Weight = 4 },
	{ Name = "Mythic",    Color = Color3.fromRGB(232, 52, 74),   Weight = 1.2 },
	{ Name = "SECRET",    Color = Color3.fromRGB(255, 255, 255), Weight = 0.3 }, -- rainbow in-game
	{ Name = "Special", Color = Color3.fromRGB(255, 120, 200), Weight = 0 }, -- Event only exclusives
}
-- stylua: ignore end

-- Rarity is an index into Config.Rarities
-- stylua: ignore start
Config.Mons = {
	{ Name = "Noodlefish Barrelo",   Emoji = "🐟", Rarity = 1, Price = 50,       Income = 1, Model = "Barrelo", ModelHeight = 4 },
	{ Name = "Rizzbert the Frog",    Emoji = "🐸", Rarity = 1, Price = 120,      Income = 3, Model = "FrogChair", ModelHeight = 4 },
	{ Name = "Ohio Toaster",         Emoji = "🍞", Rarity = 1, Price = 250,      Income = 6, Model = "Toaster", ModelHeight = 4, LabelLift = 2 },
	{ Name = "Gyatt Gator",          Emoji = "🐊", Rarity = 2, Price = 800,      Income = 20 },
	{ Name = "Mewing Moai",          Emoji = "🗿", Rarity = 2, Price = 1800,     Income = 45, Model = "Mewing", ModelHeight = 3, LabelLift = 2 },
	{ Name = "Fanum Taxer Cat",      Emoji = "🐱", Rarity = 2, Price = 3500,     Income = 90, Model = "Cat", ModelHeight = 6 },
	{ Name = "Sigma Sock",           Emoji = "🧦", Rarity = 3, Price = 9000,     Income = 240, Model = "CardonasSocks", ModelHeight = 5 },
	{ Name = "Aura Farmer Goat",     Emoji = "🐐", Rarity = 3, Price = 22000,    Income = 600, Model = "goatModel", ModelHeight = 4 },
	{ Name = "Spaghetti Overlord",   Emoji = "🍝", Rarity = 4, Price = 60000,    Income = 1700 , Model = "SpaghettiOverlord", ModelHeight = 4 },
	{ Name = "Cyclops Doomscroller", Emoji = "👁️", Rarity = 4, Price = 150000,   Income = 4500, Model = "Cyclops", ModelHeight = 4 },
	{ Name = "Quantum Capybara",     Emoji = "🦫", Rarity = 5, Price = 500000,   Income = 16000, Model = "Capybara", ModelHeight = 4 },
	{ Name = "The Final Boss Toilet",Emoji = "🚽", Rarity = 5, Price = 1500000,  Income = 50000, Model = "Skibidi", ModelHeight = 4 },
	{ Name = "THE ONE BLOCK",        Emoji = "🟨", Rarity = 6, Price = 10000000, Income = 400000, Model = "Ring", ModelHeight = 4 },
	{ Name = "Daily Drip Dino", Emoji = "🦖", Rarity = 7, Price = 1000000, Income = 25000, Model = "DailyDino", ModelHeight = 4 },
}
-- stylua: ignore end

Config.SpecialPool = { 14 }

-- stylua: ignore start
Config.DailyRewards = {
	[1] = { Kind = "Cash", First = 250,  Pct = 0.25, Min = 250,  Emoji = "💵", Text = "Quick Cash", FirstText = "$250" },
	[2] = { Kind = "Cash", First = 1000, Pct = 0.50, Min = 1000, Emoji = "💰", Text = "BIG Cash", FirstText = "$1000" },
	[3] = { Kind = "Boost", Seconds = 3600, Emoji = "⚡", Text = "2x for 1h" },
	[4] = { Kind = "Cash", Pct = 1.00, Min = 2500, Emoji = "💵", Text = "HUGE Cash" },
	[5] = { Kind = "Cash", Pct = 2.50, Min = 5000, Emoji = "💎", Text = "MEGA Cash" },
	[6] = { Kind = "Boost", Seconds = 7200, Emoji = "🔥", Text = "2x for 2h" },
	[7] = { Kind = "Mon", FirstIdx = 14, Pool = Config.SpecialPool,
		Emoji = "🎁", Text = "Special Slop", FirstEmoji = "🦖", FirstText = "Daily Drip Dino" },
}
-- stylua: ignore end

Config.Badges = {
	Welcome = 758648761145262, --join the game
	FirstExpand = 80377063974812, --first slop spot
	FirstSlop = 3326706043723622, --buy first slop
	Legendary = 1584927148149870, --buy a legendary slop
	FirstRebirth = 2255879886089870, --rebirth first time
	Mythic = 2314593998507058, -- buy a Mythic Slop
	Secret = 4021308275331040, -- buy a SECRET Slop
	MaxedSpots = 1219058499510125, -- unlock every Slop Spot
	FullPlot = 41422785915715, -- every Slop Spot unlocked and filled
	Rebirth5 = 3718036976376138, -- 5th rebirth (unlocks the second world)
}

-- DEVTOOLS: the DEV cheat panel always shows in Studio.
-- To use it in live servers too, add your Roblox UserId, e.g. { 12345678 }.
Config.DevUserIds = {}
-- true = using any cheat turns off saving for that player until they rejoin, so real saves stay clean.
-- Set to false to keep saving while cheating (e.g. to test that cheated progress saves and loads).
Config.DEV_BLOCK_SAVE = true

Config.DATA_VERSION = 3
Config.BUY_TO_INVENTORY = true
Config.INV_MAX = 300 -- keeps saves small
Config.TOKEN_RATE = 0.00002 -- 0.002% of cash earned this rebirth

-- GAMEPLAY TUNING ----------------------------------------------------
-- Moved here from the scripts (AI setup Part 3, batch 1). The numbers are the same as before.

Config.BELT_SPEED = 10 -- studs per second the Slops move along the belt
Config.START_SLOTS = 5 -- equip slots a new player starts with (also the base of Config.SlotCost)
Config.MAX_SLOTS = 16
Config.NUM_PLOTS = 8 -- plots per server (keep it even: half sit on each side of the belt)

Config.AUTOSAVE_SECONDS = 60 -- every player is saved this often
-- Seconds between income drops. Slop Income is cash per drop and the tank bars count down DropTime,
-- so changing this also changes cash per second. Leave it at 1 unless you rebalance.
Config.INCOME_TICK = 1
Config.COLLECT_CHECK = 0.2 -- how often the server checks who is standing on a Collect pad

-- Gap between Slops spawned on the belt: Min + up to Random extra seconds, or Raining while it rains
Config.BeltSpawnGap = { Min = 1.7, Random = 0.5, Raining = 0.45 }

-- Server events. A random event starts every GapMin-GapMax seconds.
-- Weight = chance out of the total of all weights (30 + 25 + 25 + 20 = 100, so 30%, 25%, 25%, 20%).
-- The banner text is built from these numbers, so it always matches.
Config.Events = {
	GapMin = 45,
	GapMax = 90,
	Order = { "AdminAbuse", "Rain", "BeltRush", "LuckyBlock" }, -- order the weights are checked in
	AdminAbuse = { Weight = 30, Mult = 5, Seconds = 15 }, -- income x Mult
	Rain = { Weight = 25, Seconds = 10 }, -- belt flooded with Slops
	BeltRush = { Weight = 25, Seconds = 30 }, -- belt runs
	LuckyBlock = { Weight = 20, MinCash = 100, IncomeSeconds = 60 }, -- gift = this many seconds of income
}

-- Slap payout: Base + IncomeShare x base income per second (boosts multiply the result)
Config.Slap = { Base = 2, IncomeShare = 0.05 }

-- How close a player must be (studs) to use a prompt or click, and how long to hold (seconds)
Config.Reach = {
	Default = 14, -- any prompt without its own value (the belt Buy and Rebirth prompts use this)
	Lever = 18, -- slot machine lever
	SlapBlock = 24,
	TankSell = 8,
	OfferBuy = 12, -- Buy prompt on the Slop shown in front of a slot machine reel
	SlotClick = 80, -- clicking a reel (SlotClient)
}
Config.Hold = { TankSell = 0.3, OfferBuy = 0.4 }

-- Factory drop boxes. The server times the cash with DropSpeed; PlotClient draws the boxes.
Config.Drops = {
	Speed = 6, -- studs per second along the conveyor
	BoxSize = 2,
	MaxPerTick = 4, -- boxes per plot per drop; with more Slops their cash is merged
	MaxPerPlot = 30, -- caps on boxes shown at once (the cash is credited either way)
	MaxBoxes = 120,
	DrawRange = 300, -- plots farther than this from the camera draw no boxes
}

Config.FAR_FROM_BASE = 60 -- studs from your plot centre before the HUD's BASE pop-up shows

-- WORLD AND PLOT LAYOUT (studs) ------------------------------------------
-- Moved here from the top of SlopServer (AI setup Part 3, batch 2). The numbers are the same as before.
-- SlopServer works out the rest from these (plot spacing, ceiling height, and so on).
-- Changing a size moves things around the whole map, so check the layout in Studio after any change.
Config.Layout = {
	-- the map
	PlotW = 56, -- plot width; size along the belt (x)
	PlotD = 60, -- plot depth; size away from the belt (z)
	PlotGap = 40, -- empty grass between neighbouring plots
	Plaza = 14, -- curb + sidewalk depth between belt and plot
	CurbW = 1,
	BeltW = 8, -- width of the main belt
	EdgePad = 50, -- ground padding past the outermost plots

	-- office room on each plot (closed top) and its 4x4 grid of Slop tanks
	RoomH = 16, -- floor to ceiling
	DoorW = 16, -- doorway in the front wall, toward the belt
	DoorH = 11,
	TankPitch = 10, -- studs between tank centres
	TankW = 6, -- glass footprint
	TankBaseH = 3, -- console under the glass; its front holds the screen
	TankGlassH = 8,

	-- factory yard behind each room (open top), and the ATM in the room's back wall
	FactoryD = 44, -- yard depth beyond the room's back wall
	YardWallH = 7,
	BackDoorW = 8,
	BackDoorH = 10,
	BackDoorDX = -14, -- back-wall doorway into the yard, x offset from the plot centre
	AtmDX = 4, -- ATM and factory conveyor line up with the tank grid
	AtmW = 8,
	AtmH = 10,
	AtmD = 6,
	PadW = 12, -- Collect pad in front of the ATM
	PadD = 6,
	ConveyorY = 3, -- top of the factory conveyor (drop box size is Config.Drops.BoxSize)

	-- slot machine reels
	HexSide = 3, -- hexagon side length of each reel
	ReelY = 7.75, -- reel centre height
}

-- Cash multiplier rolled for every new Slop: uniform x1.00 - x1.25
Config.MULT_MIN, Config.MULT_MAX = 1, 1.25
Config.MultTiers = {
	{ Name = "Normal", Min = 1.00, Color = Color3.fromRGB(150, 155, 165) },
	{ Name = "Good", Min = 1.10, Color = Color3.fromRGB(86, 176, 96) },
	{ Name = "Great", Min = 1.17, Color = Color3.fromRGB(47, 147, 232) },
	{ Name = "Excellent", Min = 1.22, Color = Color3.fromRGB(162, 79, 224) },
	{ Name = "Perfect", Min = 1.25, Color = Color3.fromRGB(240, 165, 0) },
}

-- Default stats for every Slop; override per entry later (DropTime, BaseCash, CashMult, Type)
for _, m in ipairs(Config.Mons) do
	m.DropTime = m.DropTime or 1
	m.BaseCash = m.Income or 0
	m.CashMult = m.CashMult or 1
	m.Type = m.Type or "None"
end

-- HOW TO ADD A STAT:
-- 1. Add its key below with a starting value of 0. It saves automatically, and old saves start it at 0.
-- 2. In SlopServer, call addStat(p, "KeyName", amount) wherever it should go up.
--    For "best ever" stats use: s.Stats.KeyName = math.max(s.Stats.KeyName, value)
-- 3. In MenuClient, add one line to STAT_DEFS: { "Display name", function(s) return ... end }
-- 4. The Stats tab fits 10 rows. For more, turn the Stats page into a ScrollingFrame.
Config.DefaultStats = {
	TotalCash = 0,
	CashThisRebirth = 0,
	MaxCashInRebirth = 0,
	SlopsRolled = 0,
	SlopsPurchased = 0,
	MaxIncome = 0,
	MaxTokens = 0,
}

-- Cash multiplier rolled for every new Slop
function Config.RollMult()
	local v = Config.MULT_MIN + math.random() * (Config.MULT_MAX - Config.MULT_MIN)
	return math.floor(v * 100 + 0.5) / 100
end

function Config.MultTier(m)
	local t = Config.MultTiers[1]
	for _, tier in ipairs(Config.MultTiers) do
		if m >= tier.Min then
			t = tier
		end
	end
	return t
end

-- Wheel (costs below are placeholders)
-- Roll cooldown: 10s -> 5s in 1s steps (first MidLevel upgrades), then 5s -> 1s in equal steps (0.4s).
Config.Wheel = {
	CapStart = 3,
	CapMax = 10,
	CooldownStart = 10,
	CooldownMid = 5,
	CooldownMin = 1,
	MidLevel = 5,
	SpeedLevels = 15,
}

-- Slot machine (replaces the wheel UI). One reel unlocks per roll upgrade.
-- RollNumber[reel] = which roll unlocks that reel. Reels are numbered 1-10 left to right,
-- so this reads left to right: reel 5 is roll #1, reel 6 is roll #2, and it grows outward.
-- SpinTime is the minimum visual spin length in seconds.
Config.Slot = {
	Reels = 10,
	RollNumber = { 9, 7, 5, 3, 1, 2, 4, 6, 8, 10 },
	SpinTime = 1,
	TickTime = 0.07, -- seconds per face flip while a reel spins
	OfferModels = true, -- false = plain cubes in front of the reels (cheaper)
	OfferHeight = 2.6,
}
Config.Slot.ReelOrder = {} -- ReelOrder[roll] = reel (derived; used by server + client)
for reel, roll in ipairs(Config.Slot.RollNumber) do
	Config.Slot.ReelOrder[roll] = reel
end

function Config.RollCooldown(level)
	local w = Config.Wheel
	level = math.clamp(level, 0, w.SpeedLevels)
	if level <= w.MidLevel then
		return w.CooldownStart - level * (w.CooldownStart - w.CooldownMid) / w.MidLevel
	end
	return w.CooldownMid - (level - w.MidLevel) * (w.CooldownMid - w.CooldownMin) / (w.SpeedLevels - w.MidLevel)
end

function Config.RollUpgradeCost(n)
	return 5000 * 5 ^ (n - 1)
end -- cash: n -> n+1 rolls
function Config.CapUpgradeCost(cap)
	return 50 * 2 ^ (cap - Config.Wheel.CapStart)
end -- tokens
function Config.SpeedUpgradeCost(l)
	return math.floor(20 * 1.6 ^ l)
end -- tokens
function Config.SlotCost(slots)
	return 25 * 2 ^ (slots - Config.START_SLOTS)
end -- tokens

function Config.Mult(rebirths)
	return 1 + 0.75 * rebirths
end

function Config.ExpandCost(slots)
	return 3000 * 4 ^ ((slots - 6) / 2)
end

function Config.RebirthCost(rebirths)
	return 250000 * 3 ^ rebirths
end

local SUF = { "", "K", "M", "B", "T", "Qa", "Qi" }
function Config.Format(n)
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local i = math.min(#SUF, math.floor(math.log10(n) / 3) + 1)
	local v = n / 10 ^ ((i - 1) * 3)
	local f = v >= 100 and "%.0f%s" or (v >= 10 and "%.1f%s" or "%.2f%s")
	return string.format(f, v, SUF[i])
end

-- MONETIZATION -------------------------------------------------------
-- Create these in the Creator Dashboard (create.roblox.com) for your experience,
-- then paste the numeric IDs here. Anything left at 0 is hidden/disabled.
Config.Passes = {
	DoubleCash = 2037824275, -- Game Pass: x2 income and slaps, forever
	AutoSlap = 2037368267, -- Game Pass: slaps for you every second
}
Config.Products = {
	CashSmall = 3718484283, -- Developer Product: 5 minutes of income
	CashBig = 3718484392, -- Developer Product: 1 hour of income
	Boost = 3718484154, -- Developer Product: 2x income for 15 minutes
	DoubleOffline = 3721014660, -- Developer Product: doubles offline rewards when claimed
}

Config.BOOST_SECONDS = 900
Config.CASH_SMALL_SECONDS, Config.CASH_SMALL_MIN = 300, 1000
Config.CASH_BIG_SECONDS, Config.CASH_BIG_MIN = 3600, 25000

-- What the in-game shop shows (Kind is "Pass" or "Product")
Config.ShopItems = {
	{ Kind = "Pass", Key = "DoubleCash", Title = "2x Cash", Desc = "Double all income and slaps. Permanent." },
	{
		Kind = "Pass",
		Key = "AutoSlap",
		Title = "Auto Slap",
		Desc = "Slaps the ground for you every second. Permanent.",
	},
	{ Kind = "Product", Key = "Boost", Title = "2x Boost", Desc = "Double income for 15 minutes." },
	{ Kind = "Product", Key = "CashSmall", Title = "Cash Pack", Desc = "5 minutes of your income, instantly." },
	{ Kind = "Product", Key = "CashBig", Title = "Mega Cash", Desc = "1 hour of your income, instantly." },
}

return Config
