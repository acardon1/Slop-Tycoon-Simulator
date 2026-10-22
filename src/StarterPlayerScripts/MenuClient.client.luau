-- LocalScript named "MenuClient"
-- Put it in: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("SlopConfig"))
local UI = require(RS:WaitForChild("SlopUI"))
local Menu = RS:WaitForChild("SlopMenu")
local player = Players.LocalPlayer
local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
local COL = UI.COL
local corner, stroke, label = UI.corner, UI.stroke, UI.label

local GOLD = Color3.fromRGB(255, 196, 0)
local WHITE = Color3.new(1, 1, 1)
local GREEN_TEXT = Color3.fromRGB(110, 255, 150)
local BLUE = Color3.fromRGB(59, 143, 224)
local PURPLE = Color3.fromRGB(176, 98, 232)

local WIN_W, WIN_H = 820, 640
local PANEL_W = 270
local SLIDE = PANEL_W + 14
local AREA_W = WIN_W - 40

local gui = Instance.new("ScreenGui")
gui.Name = "MenuHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local win, pages = UI.makeWindow(gui, "Slops!", {
	{ Name = "Inventory", Icon = "🎒" },
	{ Name = "Upgrades", Icon = "⭐" },
	{ Name = "Stats", Icon = "📊" },
}, WIN_W, WIN_H, SLIDE)
local winScale = win:FindFirstChildOfClass("UIScale")

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local state, fetchedAt, busy = nil, 0, false
local sel = nil            -- { kind = "inv" | "eq", key = index }
local swapFrom = nil       -- inventory index waiting for an equipped Slop to replace
local sortKey, sortDesc = "Rarity", true
local render

local function call(action, a, b)
	if busy then return nil end
	busy = true
	local ok, st = pcall(function()
		return Menu:InvokeServer(action, a, b)
	end)
	busy = false
	if ok and st then
		state, fetchedAt = st, os.clock()
		render()
		return st
	end
	return nil
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function incomeOf(sl)
	return Config.Mons[sl.Id].Income * sl.Mult
end

-- Largest square cell that fits n items in a w x h area (fewer items = bigger icons)
local function fitGrid(n, w, h, gap, minSize, maxSize)
	local best = minSize
	for cols = 1, math.max(1, n) do
		local rows = math.ceil(n / cols)
		local size = math.min((w - (cols - 1) * gap) / cols, (h - (rows - 1) * gap) / rows)
		if size > best then best = size end
	end
	return math.floor(math.clamp(best, minSize, maxSize))
end

---------------------------------------------------------------------
-- Hover tooltip (mouse)
---------------------------------------------------------------------
local tip = Instance.new("Frame")
tip.Size = UDim2.fromOffset(230, 176)
tip.BackgroundColor3 = COL.Panel
tip.Visible = false
tip.ZIndex = 100
tip.Parent = gui
corner(tip, UDim.new(0, 12))
stroke(tip, 4)
local tipName   = label(tip, "", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 6), WHITE, true)
local tipRarity = label(tip, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 38), WHITE, true)
local tipTier   = label(tip, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 66), WHITE, true)
local tipIncome = label(tip, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 94), GREEN_TEXT, true)
local tipValue  = label(tip, "", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 122), COL.Text)
local tipType   = label(tip, "", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 148), COL.Text)

local function moveTip()
	local mp = UserInputService:GetMouseLocation()
	local view = workspace.CurrentCamera.ViewportSize
	tip.Position = UDim2.fromOffset(math.min(mp.X + 18, view.X - 240), math.min(mp.Y + 18, view.Y - 186))
end

local function showTip(sl, valueText)
	local m = Config.Mons[sl.Id]
	local r = Config.Rarities[m.Rarity]
	local tier = Config.MultTier(sl.Mult)
	tipName.Text = m.Name
	tipRarity.Text = r.Name
	tipRarity.TextColor3 = r.Color
	tipTier.Text = tier.Name .. "  x" .. string.format("%.2f", sl.Mult)
	tipTier.TextColor3 = tier.Color
	tipIncome.Text = "$" .. Config.Format(incomeOf(sl)) .. "/s"
	tipValue.Text = valueText
	tipType.Text = "Type: " .. tostring(m.Type or "None")
	tip.Visible = true
	moveTip()
end

local function hideTip()
	tip.Visible = false
end

-- opts: bottom, bottomColor, tipValue, highlight, onClick
local function slopCard(parent, sl, size, opts)
	local m = Config.Mons[sl.Id]
	local r = Config.Rarities[m.Rarity]
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = COL.Tile:Lerp(r.Color, 0.45)
	b.Parent = parent
	corner(b, UDim.new(0, 12))
	stroke(b, opts.highlight and 5 or 3, opts.highlight or COL.Outline)
	label(b, m.Emoji, UDim2.fromScale(0.7, 0.55), UDim2.fromScale(0.15, 0.05), WHITE)
	label(b, opts.bottom or "", UDim2.fromScale(0.9, 0.24), UDim2.fromScale(0.05, 0.69), opts.bottomColor or WHITE, true)
	b.MouseEnter:Connect(function() showTip(sl, opts.tipValue or "") end)
	b.MouseMoved:Connect(moveTip)
	b.MouseLeave:Connect(hideTip)
	if opts.onClick then
		b.Activated:Connect(opts.onClick)
	end
	return b
end

---------------------------------------------------------------------
-- Side panel (slides the window left)
---------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(WIN_W + 14, 40)
panel.Size = UDim2.fromOffset(PANEL_W, 484)
panel.BackgroundColor3 = COL.Panel
panel.Visible = false
panel.Parent = win
corner(panel, UDim.new(0, 20))
stroke(panel, 5)

local pEmoji  = label(panel, "", UDim2.new(1, -120, 0, 80), UDim2.fromOffset(60, 10), WHITE)
local pName   = label(panel, "", UDim2.new(1, -24, 0, 38), UDim2.fromOffset(12, 96), WHITE, true)
local pRarity = label(panel, "", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 136), WHITE, true)
local pTier   = label(panel, "", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 166), WHITE, true)
local pIncome = label(panel, "", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 206), GREEN_TEXT, true)
local pValue  = label(panel, "", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 236), COL.Text)
local pType   = label(panel, "", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 266), COL.Text)
local pHint   = label(panel, "", UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 296), Color3.fromRGB(232, 140, 40), true)
pHint.TextWrapped = true

local btn1 = UI.button(panel, "", UDim2.fromOffset(PANEL_W - 32, 54), UDim2.fromOffset(16, 350), COL.Green)
local btn2 = UI.button(panel, "", UDim2.fromOffset(PANEL_W - 32, 54), UDim2.fromOffset(16, 414), COL.Red)

local panelX = Instance.new("TextButton")
panelX.Size = UDim2.fromOffset(34, 34)
panelX.Position = UDim2.new(1, -42, 0, 8)
panelX.BackgroundColor3 = COL.Red
panelX.Text = "X"
panelX.Font = Enum.Font.FredokaOne
panelX.TextScaled = true
panelX.TextColor3 = WHITE
panelX.Parent = panel
corner(panelX, UDim.new(1, 0))
stroke(panelX, 3)

local panelOpen = false
local function setPanel(open)
	if open == panelOpen then return end
	panelOpen = open
	panel.Visible = open
	local shift = open and (SLIDE / 2) * winScale.Scale or 0
	TweenService:Create(win, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -shift, 0.5, 0) }):Play()
end

local function selectedSlop()
	if not sel or not state then return nil end
	if sel.kind == "inv" then
		return state.Inventory[sel.key]
	elseif sel.kind == "eq" then
		local sl = state.Owned[sel.key]
		return type(sl) == "table" and sl or nil
	end
	return nil
end

local function updatePanel()
	local sl = selectedSlop()
	if not sl then
		sel = nil
		setPanel(false)
		return
	end
	local m = Config.Mons[sl.Id]
	local r = Config.Rarities[m.Rarity]
	local tier = Config.MultTier(sl.Mult)
	pEmoji.Text = m.Emoji
	pName.Text = m.Name
	pRarity.Text = r.Name
	pRarity.TextColor3 = r.Color
	pTier.Text = tier.Name .. "  x" .. string.format("%.2f", sl.Mult)
	pTier.TextColor3 = tier.Color
	pIncome.Text = "Income: $" .. Config.Format(incomeOf(sl)) .. "/s"
	pType.Text = "Type: " .. tostring(m.Type or "None")

	pValue.Text = "Sells for: $" .. Config.Format(math.floor(m.Price / 2))
	btn2.Text = "SELL"
	btn2.BackgroundColor3 = COL.Red
	if sel.kind == "inv" then
		btn1.Text = swapFrom and "CANCEL" or "QUICK EQUIP"
		btn1.BackgroundColor3 = swapFrom and COL.Gray or COL.Green
		pHint.Text = swapFrom and "Pick the equipped Slop to replace" or ""
	else
		btn1.Text = "UNEQUIP"
		btn1.BackgroundColor3 = COL.Green
		pHint.Text = ""
	end
	setPanel(true)
end

---------------------------------------------------------------------
-- Sell confirmation
---------------------------------------------------------------------
local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.AutoButtonColor = false
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = gui

local dlg = Instance.new("Frame")
dlg.AnchorPoint = Vector2.new(0.5, 0.5)
dlg.Position = UDim2.fromScale(0.5, 0.5)
dlg.Size = UDim2.fromOffset(480, 270)
dlg.BackgroundColor3 = COL.Panel
dlg.Parent = overlay
corner(dlg, UDim.new(0, 20))
stroke(dlg, 5)

local warnLabel = label(dlg, "", UDim2.new(1, -40, 0, 36), UDim2.fromOffset(20, 18), COL.Red, true)
local msgLabel = label(dlg, "", UDim2.new(1, -40, 0, 100), UDim2.fromOffset(20, 62), COL.Text)
msgLabel.TextWrapped = true
local yesBtn = UI.button(dlg, "SELL", UDim2.fromOffset(200, 56), UDim2.fromOffset(30, 192), COL.Red)
local noBtn = UI.button(dlg, "CANCEL", UDim2.fromOffset(200, 56), UDim2.fromOffset(250, 192), COL.Gray)

local pendingSell = nil
local function confirmSell(sl, onYes)
	local m = Config.Mons[sl.Id]
	local r = Config.Rarities[m.Rarity]
	local value = math.floor(m.Price / 2)
	warnLabel.Visible = m.Rarity >= 4
	warnLabel.Text = "WARNING: Selling " .. r.Name .. " tier unit!"
	msgLabel.Position = warnLabel.Visible and UDim2.fromOffset(20, 62) or UDim2.fromOffset(20, 36)
	msgLabel.Text = "Are you sure you want to sell " .. m.Name .. " for $" .. Config.Format(value) .. " cash?"
	pendingSell = onYes
	hideTip()
	overlay.Visible = true
end

yesBtn.Activated:Connect(function()
	overlay.Visible = false
	local f = pendingSell
	pendingSell = nil
	if f then f() end
end)
noBtn.Activated:Connect(function()
	overlay.Visible = false
	pendingSell = nil
end)

---------------------------------------------------------------------
-- Panel buttons
---------------------------------------------------------------------
btn1.Activated:Connect(function()
	if not sel or not state then return end
	if sel.kind == "inv" then
		if swapFrom then
			swapFrom = nil
			render()
			return
		end
		local free = false
		for k = 1, state.Slots do
			if type(state.Owned[k]) ~= "table" then free = true break end
		end
		if free then
			local i = sel.key
			sel = nil
			call("equip", i)
		else
			swapFrom = sel.key
			render()
		end
	else
		local k = sel.key
		sel = nil
		call("unequip", k)
	end
end)

btn2.Activated:Connect(function()
	if not sel or not state then return end
	local sl = selectedSlop()
	if not sl then return end
	local kind, key = sel.kind, sel.key
	confirmSell(sl, function()
		sel = nil
		swapFrom = nil
		call(kind == "inv" and "sell" or "sellEquipped", key)
	end)
end)

panelX.Activated:Connect(function()
	sel = nil
	swapFrom = nil
	render()
end)

---------------------------------------------------------------------
-- Inventory tab
---------------------------------------------------------------------
local inv = pages.Inventory
local equipLabel = label(inv, "", UDim2.new(1, -40, 0, 26), UDim2.fromOffset(20, 0), COL.Text)
equipLabel.TextXAlignment = Enum.TextXAlignment.Left

local equipFrame = Instance.new("Frame")
equipFrame.BackgroundTransparency = 1
equipFrame.Position = UDim2.fromOffset(20, 28)
equipFrame.Size = UDim2.new(1, -40, 0, 192)
equipFrame.Parent = inv
local eg = Instance.new("UIGridLayout")
eg.CellSize = UDim2.fromOffset(88, 88)
eg.CellPadding = UDim2.fromOffset(8, 8)
eg.SortOrder = Enum.SortOrder.LayoutOrder
eg.HorizontalAlignment = Enum.HorizontalAlignment.Center
eg.VerticalAlignment = Enum.VerticalAlignment.Center
eg.Parent = equipFrame

local invLabel = label(inv, "", UDim2.fromOffset(240, 34), UDim2.fromOffset(20, 225), COL.Text)
invLabel.TextXAlignment = Enum.TextXAlignment.Left
local sortBtn = UI.button(inv, "", UDim2.fromOffset(190, 40), UDim2.fromOffset(270, 222), BLUE)
local orderBtn = UI.button(inv, "DESC", UDim2.fromOffset(110, 40), UDim2.fromOffset(466, 222), BLUE)
local bestBtn = UI.button(inv, "EQUIP BEST", UDim2.fromOffset(204, 40), UDim2.fromOffset(582, 222), PURPLE)

local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(20, 270)
scroll.Size = UDim2.new(1, -40, 0, 262)
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = inv
local ig = Instance.new("UIGridLayout")
ig.CellSize = UDim2.fromOffset(88, 88)
ig.CellPadding = UDim2.fromOffset(8, 8)
ig.SortOrder = Enum.SortOrder.LayoutOrder
ig.Parent = scroll
local igPad = Instance.new("UIPadding")
igPad.PaddingTop, igPad.PaddingLeft = UDim.new(0, 4), UDim.new(0, 4)
igPad.Parent = scroll

local SORTS = { "Rarity", "Multiplier", "Income", "Value", "Type", "Name", "Newest" }

local function sortValue(sl, key)
	local m = Config.Mons[sl.Id]
	if key == "Rarity" then return m.Rarity
	elseif key == "Multiplier" then return sl.Mult
	elseif key == "Income" then return incomeOf(sl)
	elseif key == "Value" then return m.Price
	elseif key == "Type" then return tostring(m.Type or "None")
	elseif key == "Name" then return m.Name
	end
	return 0
end

local function sortedIndices()
	local order = {}
	for i in ipairs(state.Inventory) do order[i] = i end
	table.sort(order, function(a, b)
		if sortKey == "Newest" then
			if sortDesc then return a > b else return a < b end
		end
		local sa, sb = state.Inventory[a], state.Inventory[b]
		local va, vb = sortValue(sa, sortKey), sortValue(sb, sortKey)
		if va ~= vb then
			if sortDesc then return va > vb else return va < vb end
		end
		local ia, ib = incomeOf(sa), incomeOf(sb)
		if ia ~= ib then return ia > ib end     -- ties: higher income first
		return a < b
	end)
	return order
end

sortBtn.Activated:Connect(function()
	local i = table.find(SORTS, sortKey) or 1
	sortKey = SORTS[i % #SORTS + 1]
	render()
end)
orderBtn.Activated:Connect(function()
	sortDesc = not sortDesc
	render()
end)
bestBtn.Activated:Connect(function()
	sel = nil
	swapFrom = nil
	call("equipBest")
end)

---------------------------------------------------------------------
-- Upgrades tab
---------------------------------------------------------------------
local up = pages.Upgrades
local tokenLabel = label(up, "", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 0), COL.Text)

local function makeRow(y, title)
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(20, y)
	row.Size = UDim2.new(1, -40, 0, 96)
	row.BackgroundColor3 = COL.Tile
	row.Parent = up
	corner(row, UDim.new(0, 14))
	stroke(row, 3)
	local t = label(row, title, UDim2.new(0.6, 0, 0, 34), UDim2.fromOffset(16, 8), COL.Text)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local d = label(row, "", UDim2.new(0.6, 0, 0, 30), UDim2.fromOffset(16, 48), Color3.fromRGB(110, 110, 118))
	d.TextXAlignment = Enum.TextXAlignment.Left
	local b = UI.button(row, "", UDim2.fromOffset(190, 60), UDim2.new(1, -206, 0.5, -30), COL.Green)
	return { desc = d, btn = b }
end

local rows = {
	slots = makeRow(40, "Slop Spots"),
	rolls = makeRow(146, "More Rolls"),
	cap = makeRow(252, "Roll Cap"),
	speed = makeRow(358, "Faster Rolls"),
}
rows.slots.btn.Activated:Connect(function() call("buySlot") end)
rows.rolls.btn.Activated:Connect(function() call("upgradeRolls") end)
rows.cap.btn.Activated:Connect(function() call("upgradeCap") end)
rows.speed.btn.Activated:Connect(function() call("upgradeSpeed") end)

local function setRow(r, desc, cost, kind, maxed)
	r.desc.Text = desc
	if maxed then
		r.btn.Text = "MAX"
		r.btn.BackgroundColor3 = COL.Gray
	else
		local have = (kind == "cash") and cash.Value or state.Tokens
		r.btn.Text = ((kind == "cash") and "$" or "🪙 ") .. Config.Format(cost)
		r.btn.BackgroundColor3 = (have >= cost) and COL.Green or COL.Gray
	end
end

---------------------------------------------------------------------
-- Stats tab
---------------------------------------------------------------------
-- ADD A STAT HERE: one line per row, { "Display name", function(s) return <text> end }.
-- `s` is the server snapshot: s.Stats.<Key> holds anything listed in Config.DefaultStats.
-- The page fits 10 rows (row 11 would overflow); beyond that, make pages.Stats a ScrollingFrame.
local STAT_DEFS = {
	{ "Total cash earned",          function(s) return "$" .. Config.Format(s.Stats.TotalCash) end },
	{ "Cash this Life",          function(s) return "$" .. Config.Format(s.Stats.CashThisRebirth) end },
	{ "Highest Cash in a single Life",   function(s) return "$" .. Config.Format(s.Stats.MaxCashInRebirth) end },
	{ "Total Slops rolled",               function(s) return Config.Format(s.Stats.SlopsRolled) end },
	{ "Total Slops purchased",            function(s) return Config.Format(s.Stats.SlopsPurchased) end },
	{ "Slops discovered",           function(s) return s.Discovered .. " / " .. s.TotalSlops end },
	{ "Best Income in a single Life",     function(s) return "$" .. Config.Format(s.Stats.MaxIncome) end },
	{ "Most Tokens Awarded for a Rebirth", function(s) return Config.Format(s.Stats.MaxTokens) end },
	{ "Rebirths",                   function() return tostring(player.leaderstats.Rebirths.Value) end },
}
local statValues = {}
for i, def in ipairs(STAT_DEFS) do
	local row = Instance.new("Frame")
	row.Position = UDim2.fromOffset(20, (i - 1) * 54)
	row.Size = UDim2.new(1, -40, 0, 46)
	row.BackgroundColor3 = COL.Tile
	row.Parent = pages.Stats
	corner(row, UDim.new(0, 12))
	stroke(row, 3)
	local name = label(row, def[1], UDim2.new(0.6, 0, 0, 30), UDim2.fromOffset(14, 8), COL.Text)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local value = label(row, "", UDim2.new(0.38, 0, 0, 30), UDim2.new(0.62, -10, 0, 8), GREEN_TEXT, true)
	value.TextXAlignment = Enum.TextXAlignment.Right
	statValues[i] = value
end

---------------------------------------------------------------------
-- Render
---------------------------------------------------------------------
render = function()
	if not state then return end
	hideTip()
	local W = Config.Wheel

	if sel and not selectedSlop() then sel = nil end
	if swapFrom and not state.Inventory[swapFrom] then swapFrom = nil end

	-- equipped
	clear(equipFrame)
	local eSize = fitGrid(state.Slots, AREA_W, 192, 8, 64, 130)
	eg.CellSize = UDim2.fromOffset(eSize, eSize)
	local used = 0
	for k = 1, state.Slots do
		local sl = state.Owned[k]
		local c
		if type(sl) == "table" then
			used += 1
			local hl
			if swapFrom then
				hl = COL.Green
			elseif sel and sel.kind == "eq" and sel.key == k then
				hl = GOLD
			end
			c = slopCard(equipFrame, sl, 88, {
				bottom = "x" .. string.format("%.2f", sl.Mult),
				bottomColor = Config.MultTier(sl.Mult).Color,
				tipValue = "Sells for $" .. Config.Format(math.floor(Config.Mons[sl.Id].Price / 2)),
				highlight = hl,
				onClick = function()
					if swapFrom then
						local from = swapFrom
						swapFrom = nil
						sel = nil
						call("swap", from, k)
					else
						sel = { kind = "eq", key = k }
						render()
					end
				end,
			})
		else
			c = Instance.new("Frame")
			c.BackgroundTransparency = 0.5
			c.BackgroundColor3 = COL.Tile
			c.Parent = equipFrame
			corner(c, UDim.new(0, 12))
			stroke(c, 2, COL.Gray)
			label(c, "Empty", UDim2.fromScale(0.8, 0.25), UDim2.fromScale(0.1, 0.375), COL.Gray)
		end
		c.LayoutOrder = k
	end
	if swapFrom then
		equipLabel.Text = "Pick the equipped Slop you want to replace!"
		equipLabel.TextColor3 = Color3.fromRGB(232, 140, 40)
	else
		equipLabel.Text = string.format("Equipped %d/%d", used, state.Slots)
		equipLabel.TextColor3 = COL.Text
	end

	-- inventory
	clear(scroll)
	local iSize = fitGrid(#state.Inventory, AREA_W - 14, 262, 8, 80, 112)
	ig.CellSize = UDim2.fromOffset(iSize, iSize)
	for rank, i in ipairs(sortedIndices()) do
		local sl = state.Inventory[i]
		local c = slopCard(scroll, sl, 88, {
			bottom = "x" .. string.format("%.2f", sl.Mult),
			bottomColor = Config.MultTier(sl.Mult).Color,
			tipValue = "Sells for $" .. Config.Format(math.floor(Config.Mons[sl.Id].Price / 2)),
			highlight = (sel and sel.kind == "inv" and sel.key == i) and GOLD or nil,
			onClick = function()
				swapFrom = nil
				sel = { kind = "inv", key = i }
				render()
			end,
		})
		c.LayoutOrder = rank
	end
	invLabel.Text = string.format("Inventory %d/%d", #state.Inventory, Config.INV_MAX)
	sortBtn.Text = "Sort: " .. sortKey
	orderBtn.Text = sortDesc and "DESC" or "ASC"
	
	for i, def in ipairs(STAT_DEFS) do
		statValues[i].Text = def[2](state)
	end
	-- upgrades
	tokenLabel.Text = "🪙 Rebirth Tokens: " .. Config.Format(state.Tokens)
	setRow(rows.slots, string.format("Equip more Slops. Spots: %d / 16", state.Slots),
		Config.SlotCost(state.Slots), "tokens", state.Slots >= 16)
	setRow(rows.rolls, string.format("Slot reels: %d (cap %d). Each upgrade unlocks a reel.", state.RollCount, state.RollCap),
		Config.RollUpgradeCost(state.RollCount), "cash", state.RollCount >= state.RollCap)
	setRow(rows.cap, string.format("Raise the reel cap: %d -> %d (max %d)", state.RollCap, state.RollCap + 1, W.CapMax),
		Config.CapUpgradeCost(state.RollCap), "tokens", state.RollCap >= W.CapMax)
	setRow(rows.speed, string.format("Cooldown %.1fs -> %.1fs", state.Cooldown, Config.RollCooldown(state.SpeedLevel + 1)),
		Config.SpeedUpgradeCost(state.SpeedLevel), "tokens", state.SpeedLevel >= W.SpeedLevels)

	updatePanel()
end

---------------------------------------------------------------------
-- Close handling + open button
---------------------------------------------------------------------
for _, name in ipairs({ "Inventory", "Upgrades", "Stats" }) do
	pages[name]:GetPropertyChangedSignal("Visible"):Connect(function()
		sel = nil
		swapFrom = nil
		if pages[name].Visible then
			call("get")          -- refresh tokens and stats whenever a tab opens
		elseif state then
			render()
		end
	end)
end

win:GetPropertyChangedSignal("Visible"):Connect(function()
	if not win.Visible then
		sel = nil
		swapFrom = nil
		hideTip()
		overlay.Visible = false
		pendingSell = nil
		panel.Visible = false
		panelOpen = false
		win.Position = UDim2.fromScale(0.5, 0.5)
	end
end)

local openBtn = Instance.new("TextButton")
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 12, 1, -128)
openBtn.Size = UDim2.fromOffset(130, 48)
openBtn.BackgroundColor3 = BLUE
openBtn.Text = "SLOPS"
openBtn.Font = Enum.Font.FredokaOne
openBtn.TextScaled = true
openBtn.TextColor3 = WHITE
openBtn.Parent = gui
corner(openBtn, UDim.new(0, 8))
stroke(openBtn, 3)

openBtn.Activated:Connect(function()
	win.Visible = not win.Visible
	if win.Visible then
		call("get")
	end
end)

call("get")