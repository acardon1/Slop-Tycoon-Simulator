-- LocalScript named "DailyClient"
-- Put it in: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("SlopConfig"))
local DailyRF = RS:WaitForChild("SlopDaily")
local player = Players.LocalPlayer

local COL = {
	Panel   = Color3.fromRGB(236, 236, 238),
	Outline = Color3.fromRGB(40, 42, 48),
	Green   = Color3.fromRGB(86, 176, 96),
	Text    = Color3.fromRGB(70, 70, 76),
	Red     = Color3.fromRGB(232, 72, 63),
	Gray    = Color3.fromRGB(150, 150, 158),
	Locked  = Color3.fromRGB(176, 176, 183),
}
local SHAPE_COLORS = {
	Cash = Color3.fromRGB(120, 220, 130),
	Boost = Color3.fromRGB(190, 130, 240),
	Mon = Color3.fromRGB(255, 205, 70),
}
local GOLD = Color3.fromRGB(255, 196, 0)

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = obj
end

local function stroke(obj, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or COL.Outline
	s.Parent = obj
	return s
end

local function label(parent, text, size, pos, color, outlined)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = text
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or COL.Text
	t.Parent = parent
	if outlined then
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = COL.Outline
		s.Parent = t
	end
	return t
end

-- Window with the title overlapping the top corner and a red X. Returns window, page.
local function makeWindow(gui, title, width, height)
	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromOffset(width, height)
	win.BackgroundColor3 = COL.Panel
	win.Visible = false
	win.Parent = gui
	corner(win, UDim.new(0, 24))
	stroke(win, 5)

	local scale = Instance.new("UIScale")
	scale.Parent = win
	local function fit()
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / (width + 60), view.Y / (height + 60)), 0.4, 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	local titleLabel = label(win, title, UDim2.fromOffset(340, 60), UDim2.fromOffset(-14, -36), Color3.new(1, 1, 1), true)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Rotation = -3
	titleLabel.ZIndex = 5
	titleLabel:FindFirstChildOfClass("UIStroke").Thickness = 4

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(54, 54)
	close.BackgroundColor3 = COL.Red
	close.Text = "X"
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.ZIndex = 6
	close.Parent = win
	corner(close, UDim.new(1, 0))
	stroke(close, 4)
	close.Activated:Connect(function() win.Visible = false end)

	local page = Instance.new("Frame")
	page.BackgroundTransparency = 1
	page.Position = UDim2.fromOffset(0, 46)
	page.Size = UDim2.new(1, 0, 1, -54)
	page.Parent = win
	return win, page
end

---------------------------------------------------------------------
-- Daily rewards window
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DailyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local win, page = makeWindow(gui, "Daily Rewards!", 800, 580)

label(page, "Claim a reward every day! Miss a day and your streak resets.",
	UDim2.new(1, -60, 0, 36), UDim2.fromOffset(30, 0), COL.Text)

local state, fetchedAt, busy = nil, 0, false
local fetch -- defined below
local tiles = {}

-- shape = "circle" or "star"; d = diameter of the shape
local function makeTile(day, x, y, d, shape)
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.BackgroundTransparency = 1
	btn.Position = UDim2.fromOffset(x, y)
	btn.Size = UDim2.fromOffset(d, d + 32)
	btn.Parent = page

	local base = SHAPE_COLORS[Config.DailyRewards[day].Kind]

	-- shape layer (bottom)
	local bg = Instance.new("Frame")
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	bg.Position = UDim2.new(0.5, 0, 0, d / 2)
	bg.Size = UDim2.fromOffset(d, d)
	bg.ZIndex = 1
	bg.Parent = btn

	local bgStroke, fills, outlines
	local s = d * 0.72
	if shape == "star" then
		bg.BackgroundTransparency = 1
		fills, outlines = {}, {}
		for _, rot in ipairs({ 0, 45 }) do
			local o = Instance.new("Frame")
			o.AnchorPoint = Vector2.new(0.5, 0.5)
			o.Position = UDim2.fromScale(0.5, 0.5)
			o.Size = UDim2.fromOffset(s + 12, s + 12)
			o.Rotation = rot
			o.BackgroundColor3 = COL.Outline
			o.ZIndex = 1
			o.Parent = bg
			corner(o, UDim.new(0, 14))
			table.insert(outlines, o)
		end
		for _, rot in ipairs({ 0, 45 }) do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromOffset(s, s)
			f.Rotation = rot
			f.BackgroundColor3 = base
			f.ZIndex = 2
			f.Parent = bg
			corner(f, UDim.new(0, 10))
			table.insert(fills, f)
		end
	else
		bg.BackgroundColor3 = base
		corner(bg, UDim.new(1, 0))
		bgStroke = stroke(bg, 5)
	end

	-- content layer (above the shape): emoji + text centered as a group
	local face = Instance.new("CanvasGroup")
	face.BackgroundTransparency = 1
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.new(0.5, 0, 0, d / 2)
	local inner = (shape == "star") and 0.7 or 1
	face.Size = UDim2.fromOffset(d * inner, d * inner)
	face.ZIndex = 10
	face.Parent = btn

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = face

	local emoji = label(face, "", UDim2.fromScale(0.6, 0.4), UDim2.new(), Color3.new(1, 1, 1))
	emoji.LayoutOrder = 1
	local amount = label(face, "", UDim2.fromScale(0.86, 0.24), UDim2.new(), Color3.new(1, 1, 1), true)
	amount.TextWrapped = true
	amount.LayoutOrder = 2

	-- CLAIMED stamp (top)
	local badge = label(btn, "CLAIMED", UDim2.fromOffset(d, d * 0.24),
		UDim2.new(0, 0, 0, d / 2 - d * 0.12), Color3.fromRGB(110, 255, 150), true)
	badge.Rotation = -12
	badge.ZIndex = 20
	badge.Visible = false

	local dayLabel = label(btn, "Day " .. day, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 1, -28), Color3.new(1, 1, 1), true)
	dayLabel.ZIndex = 20

	tiles[day] = { bg = bg, bgStroke = bgStroke, base = base, face = face, emoji = emoji,
		amount = amount, badge = badge, dayLabel = dayLabel, shape = shape, claimable = false,
		fills = fills, outlines = outlines, s = s }
	btn.Activated:Connect(function()
		if tiles[day].claimable then
			fetch("claim", day)
		end
	end)
end

-- Days 1-6 as a 3x2 grid of circles, Day 7 as a large star on the right
local D = 130
for day = 1, 6 do
	local col = (day - 1) % 3
	local row = (day - 1) // 3
	makeTile(day, 26 + col * (D + 14), 50 + row * (D + 56), D, "circle")
end
makeTile(7, 480, 70, 280, "star")

local info = label(page, "", UDim2.new(1, -60, 0, 34), UDim2.fromOffset(30, 412), COL.Text)

local claimBtn = Instance.new("TextButton")
claimBtn.AnchorPoint = Vector2.new(0.5, 0)
claimBtn.Position = UDim2.new(0.5, 0, 0, 452)
claimBtn.Size = UDim2.fromOffset(340, 62)
claimBtn.Font = Enum.Font.FredokaOne
claimBtn.TextScaled = true
claimBtn.TextColor3 = Color3.new(1, 1, 1)
claimBtn.Text = "CLAIM"
claimBtn.BackgroundColor3 = COL.Green
claimBtn.Parent = page
corner(claimBtn, UDim.new(0, 14))
stroke(claimBtn, 4)
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 9), UDim.new(0, 9)
pad.Parent = claimBtn

---------------------------------------------------------------------
-- State + actions
---------------------------------------------------------------------
local function firstClaimable()
	if not state then return nil end
	for day = 1, math.min(state.Unlocked, 7) do
		if not state.Claimed[tostring(day)] then
			return day
		end
	end
	return nil
end

local function applyState(st)
	state, fetchedAt = st, os.clock()
	for day, t in ipairs(tiles) do
		local r = Config.DailyRewards[day]
		local first = (r.First ~= nil or r.FirstIdx ~= nil) and not st.Seen["Day" .. day]
		t.emoji.Text = (first and r.FirstEmoji) or r.Emoji
		t.amount.Text = (first and r.FirstText) or r.Text

		local claimed = st.Claimed[tostring(day)] == true
		local locked = day > st.Unlocked
		t.claimable = (not claimed) and (not locked)

		-- Day 7 is gold once it's available
		local base = (day == 7) and GOLD or t.base
		local fill = base
		if locked then
			fill = COL.Locked                       -- greyed out
		elseif claimed then
			fill = base:Lerp(COL.Gray, 0.55)
		end

		if t.shape == "star" then
			for _, f in ipairs(t.fills) do
				f.BackgroundColor3 = fill
			end
			local grow = t.claimable and 20 or 12
			for _, o in ipairs(t.outlines) do
				o.BackgroundColor3 = t.claimable and COL.Green or COL.Outline
				o.Size = UDim2.fromOffset(t.s + grow, t.s + grow)
			end
		else
			t.bg.BackgroundColor3 = fill
			t.bgStroke.Color = t.claimable and COL.Green or COL.Outline
			t.bgStroke.Thickness = 5 + (t.claimable and 2 or 0)
		end

		t.face.GroupTransparency = locked and 0.55 or (claimed and 0.3 or 0)
		t.dayLabel.TextColor3 = locked and Color3.fromRGB(215, 215, 220) or Color3.new(1, 1, 1)
		t.badge.Visible = claimed
	end
end

fetch = function(action, day)
	if busy then return end
	busy = true
	local ok, st = pcall(function()
		return DailyRF:InvokeServer(action, day)
	end)
	busy = false
	if ok and st then
		applyState(st)
	end
end

claimBtn.Activated:Connect(function()
	local day = firstClaimable()
	if day then
		fetch("claim", day)
	end
end)

local function fmt(secs)
	secs = math.max(0, math.floor(secs))
	if secs >= 3600 then
		return string.format("%dh %02dm", secs // 3600, (secs % 3600) // 60)
	end
	return string.format("%dm %02ds", secs // 60, secs % 60)
end

-- countdown + button text, once per second
task.spawn(function()
	while true do
		if state then
			local left = state.SecondsLeft - (os.clock() - fetchedAt)
			if left <= 0 then
				fetch("get")
			else
				local day = firstClaimable()
				if day then
					info.Text = "Reward ready! Day " .. day
					claimBtn.Text = "CLAIM"
					claimBtn.BackgroundColor3 = COL.Green
				else
					info.Text = (state.Unlocked >= 7) and ("New week starts in " .. fmt(left)) or ("Next reward in " .. fmt(left))
					claimBtn.Text = fmt(left)
					claimBtn.BackgroundColor3 = COL.Gray
				end
			end
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------------
-- Open button (above the SHOP button) with a red dot when something is claimable
---------------------------------------------------------------------
local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 12, 1, -70)
openBtn.Size = UDim2.fromOffset(130, 48)
openBtn.BackgroundColor3 = Color3.fromRGB(176, 98, 232)
openBtn.Text = "DAILY"
openBtn.Font = Enum.Font.FredokaOne
openBtn.TextScaled = true
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Parent = gui
corner(openBtn, UDim.new(0, 8))
stroke(openBtn, 3)

local dot = Instance.new("Frame")
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(1, -4, 0, 4)
dot.Size = UDim2.fromOffset(18, 18)
dot.BackgroundColor3 = COL.Red
dot.Visible = false
dot.Parent = openBtn
corner(dot, UDim.new(1, 0))
stroke(dot, 2)

task.spawn(function()
	while true do
		dot.Visible = firstClaimable() ~= nil
		task.wait(1)
	end
end)

openBtn.Activated:Connect(function()
	win.Visible = not win.Visible
	if win.Visible then
		fetch("get")
	end
end)

fetch("get")