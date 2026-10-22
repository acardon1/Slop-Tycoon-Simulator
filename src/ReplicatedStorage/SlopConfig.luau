-- ModuleScript named "SlopConfig"
-- Put it in: ReplicatedStorage

local Config = {}

Config.Rarities = {
	{ Name = "Common",    Color = Color3.fromRGB(127, 152, 166), Weight = 60 },
	{ Name = "Rare",      Color = Color3.fromRGB(47, 147, 232),  Weight = 25 },
	{ Name = "Epic",      Color = Color3.fromRGB(162, 79, 224),  Weight = 10 },
	{ Name = "Legendary", Color = Color3.fromRGB(240, 165, 0),   Weight = 4 },
	{ Name = "Mythic",    Color = Color3.fromRGB(232, 52, 74),   Weight = 1.2 },
	{ Name = "SECRET",    Color = Color3.fromRGB(255, 255, 255), Weight = 0.3 }, -- rainbow in-game
	{ Name = "Special", Color = Color3.fromRGB(255, 120, 200), Weight = 0 }, -- Event only exclusives
}

-- Rarity is an index into Config.Rarities
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

Config.SpecialPool = { 14 }

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

Config.Badges = {
	Welcome = 758648761145262, 	--join the game
	FirstExpand = 80377063974812,	--first slop spot
	FirstSlop = 3326706043723622,	--buy first slop
	Legendary = 1584927148149870,	--buy a legendary slop
	FirstRebirth = 2255879886089870,	--rebirth first time
	Mythic = 2314593998507058,        -- buy a Mythic Slop
	Secret = 4021308275331040,        -- buy a SECRET Slop
	MaxedSpots = 1219058499510125,    -- unlock every Slop Spot
	FullPlot = 41422785915715,      -- every Slop Spot unlocked and filled
	Rebirth5 = 3718036976376138,      -- 5th rebirth (unlocks the second world)
}

-- DEVTOOLS: the DEV cheat panel always shows in Studio.
-- To use it in live servers too, add your Roblox UserId, e.g. { 12345678 }.
Config.DevUserIds = {}
-- true = using any cheat turns off saving for that player until they rejoin, so real saves stay clean.
-- Set to false to keep saving while cheating (e.g. to test that cheated progress saves and loads).
Config.DEV_BLOCK_SAVE = true

Config.DATA_VERSION = 3
Config.BUY_TO_INVENTORY = true
Config.INV_MAX = 300             -- keeps saves small
Config.TOKEN_RATE = 0.00002      -- 0.002% of cash earned this rebirth

-- Cash multiplier rolled for every new Slop: uniform x1.00 - x1.25
Config.MULT_MIN, Config.MULT_MAX = 1, 1.25
Config.MultTiers = {
	{ Name = "Normal",    Min = 1.00, Color = Color3.fromRGB(150, 155, 165) },
	{ Name = "Good",      Min = 1.05, Color = Color3.fromRGB(86, 176, 96) },
	{ Name = "Great",     Min = 1.10, Color = Color3.fromRGB(47, 147, 232) },
	{ Name = "Excellent", Min = 1.15, Color = Color3.fromRGB(162, 79, 224) },
	{ Name = "Perfect",   Min = 1.25, Color = Color3.fromRGB(240, 165, 0) },
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
		if m >= tier.Min then t = tier end
	end
	return t
end

-- Wheel (costs below are placeholders)
Config.Wheel = {
	CapStart = 3, CapMax = 10,
	CooldownStart = 5, CooldownMin = 1, SpeedLevels = 10,
}

-- Slot machine (replaces the wheel UI). One reel unlocks per roll upgrade.
-- RollNumber[reel] = which roll unlocks that reel. Reels are numbered 1-10 left to right,
-- so this reads left to right: reel 5 is roll #1, reel 6 is roll #2, and it grows outward.
-- SpinTime is the minimum visual spin length in seconds.
Config.Slot = {
	Reels = 10,
	RollNumber = { 9, 7, 5, 3, 1, 2, 4, 6, 8, 10 },
	SpinTime = 1,
	TickTime = 0.07,        -- seconds per face flip while a reel spins
	OfferModels = true,     -- false = plain cubes in front of the reels (cheaper)
	OfferHeight = 2.6,
}
Config.Slot.ReelOrder = {}                       -- ReelOrder[roll] = reel (derived; used by server + client)
for reel, roll in ipairs(Config.Slot.RollNumber) do
	Config.Slot.ReelOrder[roll] = reel
end

function Config.RollCooldown(level)
	local w = Config.Wheel
	return math.max(w.CooldownMin, w.CooldownStart - level * (w.CooldownStart - w.CooldownMin) / w.SpeedLevels)
end

function Config.RollUpgradeCost(n)  return 5000 * 5 ^ (n - 1) end                 -- cash: n -> n+1 rolls
function Config.CapUpgradeCost(cap) return 50 * 2 ^ (cap - Config.Wheel.CapStart) end -- tokens
function Config.SpeedUpgradeCost(l) return math.floor(20 * 1.6 ^ l) end             -- tokens
function Config.SlotCost(slots)     return 25 * 2 ^ (slots - 5) end                 -- tokens

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
	AutoSlap   = 2037368267, -- Game Pass: slaps for you every second
}
Config.Products = {
	CashSmall = 3718484283,  -- Developer Product: 5 minutes of income
	CashBig   = 3718484392,  -- Developer Product: 1 hour of income
	Boost     = 3718484154,  -- Developer Product: 2x income for 15 minutes
	DoubleOffline = 3721014660,       -- Developer Product: doubles offline rewards when claimed
}

Config.BOOST_SECONDS = 900
Config.CASH_SMALL_SECONDS, Config.CASH_SMALL_MIN = 300, 1000
Config.CASH_BIG_SECONDS, Config.CASH_BIG_MIN = 3600, 25000

-- What the in-game shop shows (Kind is "Pass" or "Product")
Config.ShopItems = {
	{ Kind = "Pass",    Key = "DoubleCash", Title = "2x Cash",    Desc = "Double all income and slaps. Permanent." },
	{ Kind = "Pass",    Key = "AutoSlap",   Title = "Auto Slap",  Desc = "Slaps the ground for you every second. Permanent." },
	{ Kind = "Product", Key = "Boost",      Title = "2x Boost",   Desc = "Double income for 15 minutes." },
	{ Kind = "Product", Key = "CashSmall",  Title = "Cash Pack",  Desc = "5 minutes of your income, instantly." },
	{ Kind = "Product", Key = "CashBig",    Title = "Mega Cash",  Desc = "1 hour of your income, instantly." },
}

return Config