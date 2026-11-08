-- LocalScript named "SlotClient"
-- Put it in: StarterPlayer > StarterPlayerScripts
-- Animates every Slop Machine's reels (the server owns the parts + attributes).
-- Click / tap one of YOUR reels after a pull to inspect and buy the Slop on it.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(RS:WaitForChild("SlopConfig"))
local UI = require(RS:WaitForChild("SlopUI"))
local Menu = RS:WaitForChild("SlopMenu")
local player = Players.LocalPlayer
local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
local COL = UI.COL
local corner, stroke, label = UI.corner, UI.stroke, UI.label

local WHITE = Color3.new(1, 1, 1)
local GREEN_TEXT = Color3.fromRGB(110, 255, 150)
local NEUTRAL = Color3.fromRGB(245, 245, 248)
local FACE_DIM = Color3.fromRGB(196, 196, 204)
local LOCKED = Color3.fromRGB(70, 72, 80)

local function randomEmoji()
	return Config.Mons[math.random(#Config.Mons)].Emoji
end

---------------------------------------------------------------------
-- Reels (3 visible faces: 1 = upper, 2 = middle, 3 = lower)
---------------------------------------------------------------------
local spinning = {} -- set of reels currently animating

local function paint(R)
	local reel = R.reel
	if reel:GetAttribute("Unlocked") ~= true then
		for f = 1, 3 do
			R.faces[f].part.Color = LOCKED
			R.faces[f].label.Text = (f == 2) and "🔒" or ""
		end
		return
	end
	local m = Config.Mons[reel:GetAttribute("Idx") or 0]
	if m then
		R.syms[2] = m.Emoji
		R.faces[2].part.Color = NEUTRAL:Lerp(Config.Rarities[m.Rarity].Color, 0.55)
	else
		R.syms[2] = "❔"
		R.faces[2].part.Color = NEUTRAL
	end
	R.faces[1].part.Color = FACE_DIM
	R.faces[3].part.Color = FACE_DIM
	for f = 1, 3 do
		R.faces[f].label.Text = R.syms[f]
	end
end

local function buildReel(reel, j)
	local faces = {}
	for f = 1, 3 do
		local part = reel:WaitForChild("Face" .. f, 10)
		if not part then
			return nil
		end
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Right
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.LightInfluence = 0
		sg.Parent = part
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = WHITE
		t.Text = ""
		t.Parent = sg
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = t
		faces[f] = { part = part, label = t }
	end
	local R = {
		reel = reel,
		j = j,
		faces = faces,
		syms = { randomEmoji(), "❔", randomEmoji() },
		spinning = false,
		stopAt = 0,
		nextTick = 0,
	}
	paint(R)
	return R
end

local function startSpin(machine)
	local now = os.clock()
	local n = #machine.reels
	for j, R in ipairs(machine.reels) do
		if R.reel:GetAttribute("Unlocked") then
			R.spinning = true
			R.nextTick = 0
			-- reels stop left to right; the last one lands at SpinTime
			R.stopAt = now + Config.Slot.SpinTime * (0.55 + 0.45 * (j - 1) / math.max(1, n - 1))
			for f = 1, 3 do
				R.faces[f].part.Color = NEUTRAL
			end
			spinning[R] = true
		end
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for R in pairs(spinning) do
		if not R.reel.Parent then
			spinning[R] = nil
		elseif now >= R.stopAt then
			spinning[R] = nil
			R.spinning = false
			paint(R) -- lands on whatever the server rolled
		elseif now >= R.nextTick then
			R.nextTick = now + Config.Slot.TickTime
			R.syms[3], R.syms[2], R.syms[1] = R.syms[2], R.syms[1], randomEmoji() -- drum turns downward
			for f = 1, 3 do
				R.faces[f].label.Text = R.syms[f]
			end
		end
	end
end)

---------------------------------------------------------------------
-- Inspect / buy panel (for the Slop on one of your reels)
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SlotHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -20, 0.5, 0)
panel.Size = UDim2.fromOffset(300, 330)
panel.BackgroundColor3 = COL.Panel
panel.Visible = false
panel.Parent = gui
corner(panel, UDim.new(0, 20))
stroke(panel, 5)

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local function fit()
	local view = workspace.CurrentCamera.ViewportSize
	panelScale.Scale = math.clamp(view.Y / 400, 0.5, 1)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local pEmoji = label(panel, "", UDim2.fromOffset(180, 70), UDim2.fromOffset(60, 8), WHITE)
local pName = label(panel, "", UDim2.fromOffset(276, 34), UDim2.fromOffset(12, 80), WHITE, true)
local pRarity = label(panel, "", UDim2.fromOffset(276, 24), UDim2.fromOffset(12, 114), WHITE, true)
local pTier = label(panel, "", UDim2.fromOffset(276, 24), UDim2.fromOffset(12, 140), WHITE, true)
local pIncome = label(panel, "", UDim2.fromOffset(276, 24), UDim2.fromOffset(12, 168), GREEN_TEXT, true)
local pCost = label(panel, "", UDim2.fromOffset(276, 24), UDim2.fromOffset(12, 194), COL.Text)
local pType = label(panel, "", UDim2.fromOffset(276, 20), UDim2.fromOffset(12, 220), COL.Text)
local buy = UI.button(panel, "", UDim2.fromOffset(268, 54), UDim2.fromOffset(16, 254), COL.Green)

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

local current = nil -- { reel = model, uid = offer Uid }
local busy = false

-- the Slop currently on the selected reel, or nil if it was bought / replaced by a new pull
local function currentOffer()
	if not current then
		return nil
	end
	local reel = current.reel
	if reel:GetAttribute("Uid") ~= current.uid then
		return nil
	end
	local m = Config.Mons[reel:GetAttribute("Idx") or 0]
	if not m then
		return nil
	end
	return m, reel:GetAttribute("Mult") or 1
end

local function updatePanel()
	local m, mult = currentOffer()
	if not m then
		current = nil
		panel.Visible = false
		return
	end
	local rar = Config.Rarities[m.Rarity]
	local tier = Config.MultTier(mult)
	pEmoji.Text = m.Emoji
	pName.Text = m.Name
	pRarity.Text = rar.Name
	pRarity.TextColor3 = rar.Color
	pTier.Text = tier.Name .. "  x" .. string.format("%.2f", mult)
	pTier.TextColor3 = tier.Color
	pIncome.Text = "Income: $" .. Config.Format(m.Income * mult) .. "/s"
	pCost.Text = "Cost: $" .. Config.Format(m.Price)
	pType.Text = "Type: " .. tostring(m.Type or "None")
	buy.Text = "BUY  $" .. Config.Format(m.Price)
	buy.BackgroundColor3 = (cash.Value >= m.Price) and COL.Green or COL.Gray
	panel.Visible = true
end

cash.Changed:Connect(function()
	if current then
		updatePanel()
	end
end)

panelX.Activated:Connect(function()
	current = nil
	panel.Visible = false
end)

buy.Activated:Connect(function()
	if not current or busy or not currentOffer() then
		return
	end
	busy = true
	pcall(function()
		Menu:InvokeServer("buyOffer", current and current.uid)
	end)
	busy = false
	-- on success the server clears the reel, which closes the panel; on failure it stays open
end)

---------------------------------------------------------------------
-- Machines (they stream in and out with StreamingEnabled)
---------------------------------------------------------------------
local machines = {} -- [model] = machine

local function updatePrompts(machine)
	local mine = machine.model:GetAttribute("OwnerId") == player.UserId
	local knob = machine.model:FindFirstChild("LeverKnob")
	local lever = knob and knob:FindFirstChildOfClass("ProximityPrompt")
	if lever then
		lever.Enabled = mine
	end
	if machine.offers then
		for _, d in ipairs(machine.offers:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				d.Enabled = mine
			end
		end
	end
end

local function setupMachine(model)
	if machines[model] then
		return
	end
	local machine = { model = model, reels = {} }
	machines[model] = machine

	local reelsFolder = model:WaitForChild("Reels", 10)
	if not reelsFolder then
		machines[model] = nil
		return
	end
	for j = 1, Config.Slot.Reels do
		local reel = reelsFolder:WaitForChild("Reel" .. j, 10)
		local R = reel and buildReel(reel, j)
		if not R then
			machines[model] = nil
			return
		end
		machine.reels[j] = R

		local function onChanged()
			if not R.spinning then
				paint(R)
			end
			if current and current.reel == reel then
				updatePanel()
			end
		end
		for _, a in ipairs({ "Unlocked", "Idx", "Mult", "Uid" }) do
			reel:GetAttributeChangedSignal(a):Connect(onChanged)
		end

		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = Config.Reach.SlotClick
		cd.Parent = reel
		cd.MouseClick:Connect(function()
			if model:GetAttribute("OwnerId") ~= player.UserId then
				return
			end -- only your own machine
			if R.spinning then
				return
			end
			if (reel:GetAttribute("Idx") or 0) == 0 then
				return
			end
			current = { reel = reel, uid = reel:GetAttribute("Uid") }
			updatePanel()
		end)
	end

	model:GetAttributeChangedSignal("Spin"):Connect(function()
		startSpin(machine)
	end)

	local plotFolder = model.Parent
	machine.offers = plotFolder and plotFolder:WaitForChild("Offers", 10)
	if machine.offers then
		machine.offers.DescendantAdded:Connect(function(d)
			if d:IsA("ProximityPrompt") then
				d.Enabled = model:GetAttribute("OwnerId") == player.UserId
			end
		end)
	end
	model:GetAttributeChangedSignal("OwnerId"):Connect(function()
		updatePrompts(machine)
	end)
	updatePrompts(machine)
end

local world = workspace:WaitForChild("SlopOverWorld")
local function consider(d)
	if d.Name == "SlotMachine" and d:IsA("Model") then
		task.spawn(setupMachine, d)
	end
end
for _, d in ipairs(world:GetDescendants()) do
	consider(d)
end
world.DescendantAdded:Connect(consider)
world.DescendantRemoving:Connect(function(d)
	local machine = machines[d]
	if machine then
		for _, R in pairs(machine.reels) do
			spinning[R] = nil
		end
		if current and current.reel:IsDescendantOf(d) then
			current = nil
			panel.Visible = false
		end
		machines[d] = nil
	end
end)
