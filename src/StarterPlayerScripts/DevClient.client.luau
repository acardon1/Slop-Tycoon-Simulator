-- LocalScript named "DevClient"
-- Put it in: StarterPlayer > StarterPlayerScripts
-- DEV cheat panel for testing. The server decides who may use it (always in Studio,
-- live servers only for Config.DevUserIds); everyone else never sees the button.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("SlopConfig"))
local UI = require(RS:WaitForChild("SlopUI"))
local Dev = RS:WaitForChild("SlopDev")
local player = Players.LocalPlayer
local COL = UI.COL

local ok, info = pcall(function()
	return Dev:InvokeServer("check")
end)
if not ok or type(info) ~= "table" then
	return
end

local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(232, 140, 40)
local BLUE = Color3.fromRGB(59, 143, 224)
local PURPLE = Color3.fromRGB(176, 98, 232)
local PANEL_W = 380

local gui = Instance.new("ScreenGui")
gui.Name = "DevHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local busy = false
local function call(action, a, b)
	if busy then
		return
	end
	busy = true
	pcall(function()
		Dev:InvokeServer(action, a, b)
	end)
	busy = false
end

---------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------
local panel = Instance.new("ScrollingFrame")
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 154, 1, -12)
panel.Size = UDim2.fromOffset(PANEL_W, 480)
panel.BackgroundColor3 = COL.Panel
panel.BorderSizePixel = 0
panel.ScrollBarThickness = 6
panel.CanvasSize = UDim2.new()
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.Visible = false
panel.Parent = gui
UI.corner(panel, UDim.new(0, 16))
UI.stroke(panel, 4)

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local function fit()
	local view = workspace.CurrentCamera.ViewportSize
	panelScale.Scale = math.clamp((view.Y - 40) / 480, 0.5, 1)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
pad.Parent = panel

local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 6)
list.Parent = panel

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function header(text, color)
	local t = UI.label(panel, text, UDim2.new(1, 0, 0, 26), UDim2.new(), color or COL.Text)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.LayoutOrder = nextOrder()
	return t
end

-- a row of equal-width buttons: { { "text", color, function }, ... }
local function row(buttons)
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 42)
	f.LayoutOrder = nextOrder()
	f.Parent = panel
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.Parent = f
	local w = (PANEL_W - 24 - 6 * (#buttons - 1)) / #buttons
	local made = {}
	for i, def in ipairs(buttons) do
		local b = UI.button(f, def[1], UDim2.fromOffset(w, 42), UDim2.new(), def[2])
		b.Activated:Connect(def[3])
		made[i] = b
	end
	return made
end

local title = header("DEVTOOLS", ORANGE)
title.Size = UDim2.new(1, 0, 0, 32)
if info.BlockSave then
	local note = header("Using a cheat turns off saving until you rejoin.", COL.Red)
	note.TextWrapped = true
	note.Size = UDim2.new(1, 0, 0, 36)
end

header("Cash")
row({
	{
		"+$10K",
		COL.Green,
		function()
			call("cash", 1e4)
		end,
	},
	{
		"+$1M",
		COL.Green,
		function()
			call("cash", 1e6)
		end,
	},
	{
		"+$1B",
		COL.Green,
		function()
			call("cash", 1e9)
		end,
	},
	{
		"+$1T",
		COL.Green,
		function()
			call("cash", 1e12)
		end,
	},
})

header("ATM (collect on the pad)")
row({
	{
		"ATM +$10K",
		COL.Green,
		function()
			call("atm", 1e4)
		end,
	},
	{
		"ATM +$1B",
		COL.Green,
		function()
			call("atm", 1e9)
		end,
	},
})

header("Rebirth Tokens")
row({
	{
		"+100",
		BLUE,
		function()
			call("tokens", 100)
		end,
	},
	{
		"+10K",
		BLUE,
		function()
			call("tokens", 1e4)
		end,
	},
	{
		"+1M",
		BLUE,
		function()
			call("tokens", 1e6)
		end,
	},
})

header("Rebirths, rolls and upgrades")
row({
	{
		"+1 Rebirth",
		PURPLE,
		function()
			call("rebirth")
		end,
	},
	{
		"Reset to 0",
		COL.Gray,
		function()
			call("resetRebirths")
		end,
	},
	{
		"No cooldown",
		ORANGE,
		function()
			call("cooldown")
		end,
	},
})
row({
	{
		"Max Slop Spots",
		BLUE,
		function()
			call("maxSlots")
		end,
	},
	{
		"Reset all upgrades",
		COL.Red,
		function()
			call("resetUpgrades")
		end,
	},
})

header("Server events")
row({
	{
		"Admin x5",
		COL.Red,
		function()
			call("event", "AdminAbuse")
		end,
	},
	{
		"Rain",
		COL.Red,
		function()
			call("event", "Rain")
		end,
	},
})
row({
	{
		"Belt Rush",
		COL.Red,
		function()
			call("event", "BeltRush")
		end,
	},
	{
		"Lucky Block",
		COL.Red,
		function()
			call("event", "LuckyBlock")
		end,
	},
})

-- Slops: tap one to add it to your inventory
header("Give Slop (goes to inventory)")
-- quality button cycles Random -> each tier in Config.MultTiers; a tier gives its minimum multiplier
local quality = 0 -- 0 = random roll, otherwise an index into Config.MultTiers
local qualityBtn
qualityBtn = row({
	{
		"Quality: Random",
		COL.Gray,
		function()
			quality = (quality + 1) % (#Config.MultTiers + 1)
			local tier = Config.MultTiers[quality]
			qualityBtn.Text = tier and string.format("Quality: %s x%.2f", tier.Name, tier.Min) or "Quality: Random"
			qualityBtn.BackgroundColor3 = tier and tier.Color or COL.Gray
		end,
	},
})[1]

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Size = UDim2.fromScale(1, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.LayoutOrder = nextOrder()
grid.Parent = panel
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.fromOffset((PANEL_W - 24 - 6) / 2, 38)
gl.CellPadding = UDim2.fromOffset(6, 6)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = grid

for i, m in ipairs(Config.Mons) do
	local b = UI.button(grid, m.Emoji .. " " .. m.Name, UDim2.new(), UDim2.new(), Config.Rarities[m.Rarity].Color)
	b.LayoutOrder = i
	b.Activated:Connect(function()
		local tier = Config.MultTiers[quality]
		call("slop", i, tier and tier.Min)
	end)
end

---------------------------------------------------------------------
-- Open button (above the SLOPS button)
---------------------------------------------------------------------
local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 12, 1, -186)
openBtn.Size = UDim2.fromOffset(130, 48)
openBtn.BackgroundColor3 = ORANGE
openBtn.Text = "DEV"
openBtn.Font = Enum.Font.FredokaOne
openBtn.TextScaled = true
openBtn.TextColor3 = WHITE
openBtn.Parent = gui
UI.corner(openBtn, UDim.new(0, 8))
UI.stroke(openBtn, 3)

openBtn.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
