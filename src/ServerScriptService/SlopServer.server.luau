-- Script named "SlopServer"
-- Put it in: ServerScriptService
-- Builds the whole game procedurally: belt, 8 player bases, buy/sell prompts, events, saving.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerStorage = game:GetService("ServerStorage")
local BadgeService = game:GetService("BadgeService")
local CollectionService = game:GetService("CollectionService")

local Config = require(RS:WaitForChild("SlopConfig"))

local Remote = Instance.new("RemoteEvent")
Remote.Name = "SlopEvent"
Remote.Parent = RS

-- GetDataStore errors when the place isn't linked to a published game (e.g. a local .rbxl in Studio).
-- Catch it so the world still builds; Store stays nil and load/save fail safely inside their pcalls.
local storeOk, Store = pcall(function()
	return DataStoreService:GetDataStore("SlopTycoonV1")
end)
if not storeOk then
	warn("[Slop] DataStore unavailable, saving is off: " .. tostring(Store))
	Store = nil
end

-- Settings (the numbers live in SlopConfig, "GAMEPLAY TUNING")
local SPEED = Config.BELT_SPEED
local START_SLOTS = Config.START_SLOTS
local MAX_SLOTS = Config.MAX_SLOTS
local NUM_PLOTS = Config.NUM_PLOTS

-- Layout Settings (the numbers live in SlopConfig, Config.Layout; the values below them are worked out here)
local L = Config.Layout
local PLOT_W = L.PlotW -- plot width; size along the belt (x)
local PLOT_D = L.PlotD -- plot depth; size away from the belt (z)
local PLOT_GAP = L.PlotGap -- empty grass between neighboring plots
local PLAZA = L.Plaza -- curb + sidewalk depth between belt and plot
local CURB_W = L.CurbW
local BELT_W = L.BeltW -- width of conveyor belt
local EDGE_PAD = L.EdgePad -- baseplate padding past the outermost plots
local PER_SIDE = NUM_PLOTS / 2
local PLOT_PITCH = PLOT_W + PLOT_GAP
local PLOT_CZ = BELT_W / 2 + PLAZA + PLOT_D / 2 -- plot center distance from belt (38)
local PLOTS_HALF_LEN = (PER_SIDE * PLOT_PITCH - PLOT_GAP) / 2 -- 110
local PLOTS_HALF_WIDTH = PLOT_CZ + PLOT_D / 2 -- 58
local BELT_HALF = PLOTS_HALF_LEN -- belt now spans every plot

-- Office room on each plot (closed top) and its 4x4 grid of Slop tanks
local ROOM_H = L.RoomH -- floor to ceiling
local CEIL_Y = 0.5 + ROOM_H -- the floor's top is at y 0.5
local DOOR_W, DOOR_H = L.DoorW, L.DoorH -- doorway in the front wall, toward the belt
local TANK_PITCH = L.TankPitch -- studs between tank centres
local TANK_W = L.TankW -- glass footprint
local TANK_BASE_H = L.TankBaseH -- console under the glass; its front holds the screen
local TANK_GLASS_H = L.TankGlassH

-- Factory yard behind each room (open top), and the ATM in the room's back wall
local FACTORY_D = L.FactoryD -- yard depth beyond the room's back wall
local YARD_WALL_H = L.YardWallH
local BACK_DOOR_W, BACK_DOOR_H = L.BackDoorW, L.BackDoorH
local BACK_DOOR_DX = L.BackDoorDX -- back-wall doorway into the yard, x offset from the plot centre
local ATM_DX = L.AtmDX -- ATM and conveyor line up with the tank grid
local ATM_W, ATM_H, ATM_D = L.AtmW, L.AtmH, L.AtmD
local PAD_W, PAD_D = L.PadW, L.PadD -- Collect pad in front of the ATM
local BELT_Y = L.ConveyorY -- top of the factory conveyor
local DROP_SPEED = Config.Drops.Speed -- studs per second along the conveyor
local DROP_BOX = Config.Drops.BoxSize -- drop box size (PlotClient draws the boxes)

-- State
local State = {} -- [player] = {Owned = {}, Slots = 6, Rebirths = 0, Plot = plot, Loaded = bool}
local items = {} -- belt items: {Part = part, Idx = monIndex, Taken = false}
local rainbow = {} -- parts that cycle colors (SECRET rarity)
local adminMult = 1
local raining = false
local beltOn = false -- the belt only runs during events

local refreshPlot -- forward declaration
local refreshMachine, clearMachine, doRoll, buyOffer -- slot machine (defined below)

-- A Slop the player owns: { Id = index in Config.Mons, Mult = rolled cash multiplier }
local function newSlop(idx, mult)
	return { Id = idx, Mult = mult or Config.RollMult() }
end

local function cleanSlop(v)
	if type(v) == "number" and Config.Mons[v] then
		return { Id = v, Mult = 1 } -- old save format
	elseif type(v) == "table" and Config.Mons[tonumber(v.Id)] then
		return { Id = tonumber(v.Id), Mult = math.clamp(tonumber(v.Mult) or 1, 0.1, 100) }
	end
	return nil
end

local function slopIncome(sl)
	return Config.Mons[sl.Id].Income * sl.Mult
end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function mk(name, size, cf, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function textLabel(parent, text, y, h, color)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0, y)
	t.Size = UDim2.fromScale(1, h)
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Parent = parent
	return t
end

local function mkPrompt(parent, action, object, hold)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = Config.Reach.Default
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function awardBadge(player, badgeId)
	-- Fetch badge information
	local success, badgeInfo = pcall(function()
		return BadgeService:GetBadgeInfoAsync(badgeId)
	end)

	if success then
		-- Confirm that badge can be awarded
		if badgeInfo.IsEnabled then
			-- Award badge
			local awarded, errorMessage = pcall(BadgeService.AwardBadgeAsync, BadgeService, player.UserId, badgeId)
			if not awarded then
				warn("Error while awarding badge:", errorMessage)
			end
		end
	else
		warn("Error while fetching badge info: " .. badgeInfo)
	end
end

local badgeSeen = {} -- [player] = { [badgeId] = true }

local function giveBadge(p, badgeId)
	if not badgeId or badgeId == 0 then
		return
	end
	local seen = badgeSeen[p]
	if not seen then
		seen = {}
		badgeSeen[p] = seen
	end
	if seen[badgeId] then
		return
	end
	seen[badgeId] = true
	task.spawn(awardBadge, p, badgeId)
end

-- Badges for buying a Slop. To add one: put its id in Config.Badges and add a line here.
local function giveSlopBadges(p, m)
	giveBadge(p, Config.Badges.FirstSlop)
	if m.Rarity == 4 then
		giveBadge(p, Config.Badges.Legendary)
	end
	if m.Rarity == 5 then
		giveBadge(p, Config.Badges.Mythic)
	end
	if m.Rarity == 6 then
		giveBadge(p, Config.Badges.Secret)
	end
end

-- Max Slop Spots, and every one of them filled
local function checkPlotBadges(p)
	local s = State[p]
	if not s or s.Slots < MAX_SLOTS then
		return
	end
	giveBadge(p, Config.Badges.MaxedSpots)
	for k = 1, s.Slots do
		if s.Owned[k] == 0 then
			return
		end
	end
	giveBadge(p, Config.Badges.FullPlot)
end

-- Custom 3D models -------------------------------------------------
-- A character can use your own model by setting Model = "name" (and
-- optionally ModelHeight in studs) on its entry in SlopConfig.
-- The model is looked up by name in ServerStorage, ReplicatedStorage, then Workspace.
local templateCache = {}

local function getTemplate(name)
	local cached = templateCache[name]
	if cached ~= nil then
		return cached or nil
	end
	local t = ServerStorage:FindFirstChild(name, true)
		or RS:FindFirstChild(name, true)
		or Workspace:FindFirstChild(name, true)
	if t and not (t:IsA("Model") or t:IsA("BasePart")) then
		t = nil
	end
	if not t then
		warn("[Slop] Could not find a Model or MeshPart named '" .. name .. "'. Using the default block instead.")
	end
	templateCache[name] = t or false
	return t
end

local function primaryOf(root)
	if root:IsA("BasePart") then
		return root
	end
	return root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true)
end

local function boundsOf(root)
	if root:IsA("Model") then
		return root:GetBoundingBox()
	end
	return root.CFrame, root.Size
end

local function scaleTo(root, targetHeight)
	local _, size = boundsOf(root)
	if size.Y <= 0 then
		return
	end
	local f = targetHeight / size.Y
	if root:IsA("Model") then
		root:ScaleTo(root:GetScale() * f)
	else
		root.Size = root.Size * f
	end
end

-- pos is where the center of a 3x3x3 block would be; the model's feet land 1.5 studs below it
local function placeAt(root, pos)
	local cf, size = boundsOf(root)
	local bottomY = cf.Position.Y - size.Y / 2
	local pivot = root:GetPivot()
	local dy = (pos.Y - 1.5) - bottomY
	root:PivotTo(CFrame.new(pos.X, pivot.Position.Y + dy, pos.Z) * (pivot - pivot.Position))
end
-----------------------------
--Model generation
-----------------------------

-- kind = "belt": rarity, emoji, name, then `sub` (rich text allowed)
-- kind = "plot": name colored by rarity, then `sub` colored with subColor
local function makeMon(idx, kind, sub, subColor)
	local m = Config.Mons[idx]
	local r = Config.Rarities[m.Rarity]

	local root
	local template = m.Model and getTemplate(m.Model)
	if template then
		root = template:Clone()
		root.Name = m.Name
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in ipairs(list) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.Color = r.Color
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		scaleTo(root, m.ModelHeight or 4)
	else
		root = Instance.new("Part")
		root.Name = m.Name
		root.Size = Vector3.new(3, 3, 3)
		root.Anchored = true
		root.CanCollide = false
		root.Material = Enum.Material.SmoothPlastic
		root.Color = r.Color
		if m.Rarity == 6 then
			rainbow[root] = true
		end
	end

	local primary = primaryOf(root)
	local cf, size = boundsOf(root)
	local top = cf.Position.Y + size.Y / 2
	local lift = m.LabelLift or 0

	local gui = Instance.new("BillboardGui")
	gui.Size = (kind == "belt") and UDim2.fromOffset(170, 110) or UDim2.fromOffset(170, 64)
	if template then
		gui.StudsOffsetWorldSpace = Vector3.new(0, top - primary.Position.Y + 1.8 + lift, 0)
	else
		gui.StudsOffset = Vector3.new(0, 3.4 + lift, 0)
	end
	gui.MaxDistance = 90
	gui.Adornee = primary
	gui.Parent = primary

	if kind == "belt" then
		textLabel(gui, r.Name, 0, 0.2, r.Color)
		textLabel(gui, m.Emoji, 0.2, 0.4)
		textLabel(gui, m.Name, 0.6, 0.2)
		local subLabel = textLabel(gui, sub, 0.8, 0.2, subColor or Color3.new(1, 1, 1))
		subLabel.RichText = true
	else
		textLabel(gui, m.Name, 0, 0.5, r.Color)
		textLabel(gui, sub, 0.5, 0.5, subColor or Color3.new(1, 1, 1))
	end
	return root
end

-- Label-free Slop (its model, or a cube): offers in front of the reels and Slops in tanks.
-- useModel = false forces the cube; nil follows Config.Slot.OfferModels.
local function buildDisplay(idx, height, useModel)
	local m = Config.Mons[idx]
	local r = Config.Rarities[m.Rarity]
	if useModel == nil then
		useModel = Config.Slot.OfferModels
	end
	local template = useModel and m.Model and getTemplate(m.Model)
	local root
	if template then
		root = template:Clone()
		root.Name = m.Name
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in ipairs(list) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.Color = r.Color
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		scaleTo(root, height)
	else
		root = Instance.new("Part")
		root.Name = m.Name
		root.Size = Vector3.new(height * 0.85, height * 0.85, height * 0.85)
		root.Anchored = true
		root.CanCollide = false
		root.Material = Enum.Material.SmoothPlastic
		root.Color = r.Color
		if m.Rarity == 6 then
			rainbow[root] = true
		end
	end
	return root
end

local function getCash(p)
	return p.leaderstats.Cash.Value
end

local function setCash(p, v)
	p.leaderstats.Cash.Value = math.floor(v)
end

local function notify(p, text)
	Remote:FireClient(p, "toast", text)
end

local function baseInc(p)
	local s = State[p]
	local total = 0
	for _, sl in ipairs(s.Owned) do
		if sl ~= 0 then
			total += slopIncome(sl)
		end
	end
	return total
end

local function boostActive(s)
	return s.BoostUntil > os.time()
end

-- rebirth x gamepass x personal boost x server event
local function totalMult(p)
	local s = State[p]
	local m = Config.Mult(s.Rebirths) * adminMult
	if s.Passes.DoubleCash then
		m *= 2
	end
	if boostActive(s) then
		m *= 2
	end
	return m
end

local function incomePerSec(p)
	return baseInc(p) * totalMult(p)
end

-- ATM screen, Collect pad outline and the HUD's CASH TO COLLECT (player attribute AtmCash)
local PAD_EMPTY = Color3.fromRGB(90, 94, 104)
local PAD_READY = Color3.new(1, 1, 1)
local PAD_GOLD = Color3.fromRGB(255, 196, 0)

local function setPadColor(plot, cash)
	local c = (cash >= 1e9 and PAD_GOLD) or (cash >= 1 and PAD_READY) or PAD_EMPTY
	for _, edge in ipairs(plot.PadOutline) do
		edge.Color = c
	end
end

local function updateAtm(p)
	local s = State[p]
	if not s or not s.Plot then
		return
	end
	local plot = s.Plot
	local cash = math.floor(s.AtmCash)
	plot.AtmTotal.Text = "$" .. Config.Format(cash)
	plot.AtmFormula.Text = string.format(
		"Slops $%s/s  x%.2f boosts  =  $%s/s",
		Config.Format(baseInc(p)),
		totalMult(p),
		Config.Format(incomePerSec(p))
	)
	setPadColor(plot, cash)
	p:SetAttribute("AtmCash", cash)
end

local function clearAtm(plot)
	plot.AtmTotal.Text = "$0"
	plot.AtmFormula.Text = "Unclaimed"
	setPadColor(plot, 0)
end

local function updateIncome(p)
	local ls = p:FindFirstChild("leaderstats")
	local s = State[p]
	if ls and s then
		local inc = math.floor(incomePerSec(p))
		ls.Income.Value = inc
		if inc > s.Stats.MaxIncome then
			s.Stats.MaxIncome = inc
		end
		updateAtm(p)
	end
end

local function slapValue(p)
	return math.max(1, math.floor((Config.Slap.Base + baseInc(p) * Config.Slap.IncomeShare) * totalMult(p)))
end

local function addStat(p, name, amount)
	local s = State[p]
	if s then
		s.Stats[name] = (s.Stats[name] or 0) + amount
	end
end

local function discover(p, idx)
	local s = State[p]
	if s then
		s.Discovered[tostring(idx)] = true
	end
end
---------------------------------------------------------------------
-- World1: ground + belt
---------------------------------------------------------------------
local world1 = Instance.new("Folder")
world1.Name = "SlopOverWorld"
world1.Parent = Workspace

world1:SetAttribute("DropSpeed", DROP_SPEED) -- PlotClient moves drop boxes at this speed

local ground1 = mk(
	"Ground",
	Vector3.new(PLOTS_HALF_LEN * 2 + EDGE_PAD * 2, 1, (PLOTS_HALF_WIDTH + FACTORY_D + EDGE_PAD) * 2),
	CFrame.new(0, -0.4, 0),
	Color3.fromRGB(90, 166, 70),
	world1
)
ground1.Material = Enum.Material.Grass

mk("Belt", Vector3.new(BELT_HALF * 2, 1, 8), CFrame.new(0, 0.6, 0), Color3.fromRGB(58, 63, 71), world1)
mk("BeltEdge", Vector3.new(BELT_HALF * 2, 0.4, 0.6), CFrame.new(0, 1.2, 4.3), Color3.fromRGB(255, 210, 63), world1)
mk("BeltEdge", Vector3.new(BELT_HALF * 2, 0.4, 0.6), CFrame.new(0, 1.2, -4.3), Color3.fromRGB(255, 210, 63), world1)

-- Continuous curb + sidewalk on both sides of the belt
local walkInner = BELT_W / 2 + CURB_W -- starts just outside the yellow edge strip
local walkOuter = BELT_W / 2 + PLAZA -- meets the front edge of the plots
local walkWidth = walkOuter - walkInner - 1 --width of sidewalk
for _, side in ipairs({ -1, 1 }) do
	mk(
		"Curb Inner",
		Vector3.new(BELT_HALF * 2, 0.9, CURB_W),
		CFrame.new(0, 0.55, side * (walkInner - CURB_W / 2)),
		Color3.fromRGB(205, 205, 210),
		world1
	)

	local walk = mk(
		"Sidewalk",
		Vector3.new(BELT_HALF * 2, 0.4, walkWidth),
		CFrame.new(0, 0.3, side * (walkInner + walkWidth / 2)),
		Color3.fromRGB(160, 160, 166),
		world1
	)
	walk.Material = Enum.Material.Plastic
	walk.TopSurface = Enum.SurfaceType.Studs

	mk(
		"Curb Outer",
		Vector3.new(BELT_HALF * 2, 0.9, CURB_W),
		CFrame.new(0, 0.55, side * (walkOuter - 1 + CURB_W / 2)),
		Color3.fromRGB(205, 205, 210),
		world1
	)
end

---------------------------------------------------------------------
-- World2: ground + belt
---------------------------------------------------------------------
--local world2 = Instance.new("Folder")
--world2.Name = "BlizzardWorld"
--world2.Parent = Workspace

--local ground2 = mk("Ground", Vector3.new(260, 1, 120), CFrame.new(0, -0.4, 162), Color3.fromRGB(90, 166, 70), world2)
--ground2.Material = Enum.Material.Grass

--mk("Belt", Vector3.new(BELT_HALF * 2, 1, 8), CFrame.new(0, 0.6, 142), Color3.fromRGB(58, 63, 71), world2)
--local beltEdgeA2 = mk("BeltEdge", Vector3.new(BELT_HALF * 2, 0.4, 0.6), CFrame.new(0, 1.2, 144.3), Color3.fromRGB(255, 210, 63), world2)
--local beltEdgeB2 = mk("BeltEdge", Vector3.new(BELT_HALF * 2, 0.4, 0.6), CFrame.new(0, 1.2, 135.7), Color3.fromRGB(255, 210, 63), world2)

-----------------------------------------------------------------------
---- World3: ground + belt
-----------------------------------------------------------------------
--local world3 = Instance.new("Folder")
--world3.Name = "SlopWorld"
--world3.Parent = Workspace

--local ground3 = mk("Ground", Vector3.new(260, 1, 120), CFrame.new(200, -0.4, 22), Color3.fromRGB(90, 166, 70), world3)
--ground3.Material = Enum.Material.Grass

--mk("Belt", Vector3.new(BELT_HALF * 2, 1, 8), CFrame.new(0, 0.6, 0), Color3.fromRGB(58, 63, 71), world3)
--local beltEdgeA3 = mk("BeltEdge", Vector3.new(BELT_HALF * 2, 0.4, 0.6), CFrame.new(0, 1.2, 4.3), Color3.fromRGB(255, 210, 63), world3)
--local beltEdgeB3 = mk("BeltEdge", Vector3.new(BELT_HALF * 2, 0.4, 0.6), CFrame.new(0, 1.2, -4.3), Color3.fromRGB(255, 210, 63), world3)

---------------------------------------------------------------------
-- Plots (player bases)
---------------------------------------------------------------------
local plots = {}

-- Floor-level centre of tank k (1-16). Row 1 is nearest the door, column 1 nearest the Slop Machine.
-- The grid is shifted 4 studs toward +X to leave a walkway beside the machine's offers.
local function tankPos(plot, k)
	local col = (k - 1) % 4
	local row = math.floor((k - 1) / 4)
	return Vector3.new(plot.CX + 4 + (col - 1.5) * TANK_PITCH, 0.5, plot.CZ - plot.Side * (1.5 - row) * TANK_PITCH)
end

-- A full-height room wall along x (from x0 to x1, plus 0.5 past each end) at z, with a doorway at doorX
local function wallWithDoor(name, z, doorX, doorW, doorH, x0, x1, color, parent)
	local doorL, doorR = doorX - doorW / 2, doorX + doorW / 2
	local leftLen, rightLen = doorL - (x0 - 0.5), (x1 + 0.5) - doorR
	mk(name, Vector3.new(leftLen, CEIL_Y, 1), CFrame.new(doorL - leftLen / 2, CEIL_Y / 2, z), color, parent)
	mk(name, Vector3.new(rightLen, CEIL_Y, 1), CFrame.new(doorR + rightLen / 2, CEIL_Y / 2, z), color, parent)
	local headerBottom = 0.5 + doorH
	mk(
		"DoorHeader",
		Vector3.new(doorW, CEIL_Y - headerBottom, 1),
		CFrame.new(doorX, (headerBottom + CEIL_Y) / 2, z),
		color,
		parent
	)
end

-- Office room: walls all round (doorway in the front toward the belt, and one in the back into
-- the factory yard) and a closed ceiling with neon pipes. The -X wall stands just behind the
-- Slop Machine, so the machine is inside.
local function buildRoom(plot)
	local room = Instance.new("Folder")
	room.Name = "Room"
	room.Parent = plot.Folder

	local wallColor = Color3.fromRGB(226, 224, 216)
	local x0 = plot.CX - PLOT_W / 2 - 5.5 -- -X wall, behind the machine's pedestal
	local x1 = plot.CX + PLOT_W / 2 -- +X wall
	local lenX = x1 - x0 + 1 -- front/back walls and ceiling cover both side walls
	local midX = (x0 + x1) / 2
	local frontZ = plot.CZ - plot.Side * PLOT_D / 2
	local backZ = plot.CZ + plot.Side * PLOT_D / 2

	mk("WallSide", Vector3.new(1, CEIL_Y, PLOT_D), CFrame.new(x1, CEIL_Y / 2, plot.CZ), wallColor, room)
	mk("WallSide", Vector3.new(1, CEIL_Y, PLOT_D), CFrame.new(x0, CEIL_Y / 2, plot.CZ), wallColor, room)
	wallWithDoor("WallFront", frontZ, plot.CX, DOOR_W, DOOR_H, x0, x1, wallColor, room)
	wallWithDoor("WallBack", backZ, plot.CX + BACK_DOOR_DX, BACK_DOOR_W, BACK_DOOR_H, x0, x1, wallColor, room)

	local ceiling = mk(
		"Ceiling",
		Vector3.new(lenX, 1, PLOT_D + 1),
		CFrame.new(midX, CEIL_Y + 0.5, plot.CZ),
		Color3.fromRGB(52, 55, 64),
		room
	)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 22
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 244, 228)
	light.Parent = ceiling

	-- neon pipes under the ceiling: three along the room, two across
	for _, f in ipairs({ -0.3, 0, 0.3 }) do
		local pipe = mk(
			"NeonPipe",
			Vector3.new(PLOT_W - 2, 0.8, 0.8),
			CFrame.new(plot.CX, CEIL_Y - 0.6, plot.CZ + f * PLOT_D),
			Color3.fromRGB(57, 255, 120),
			room
		)
		pipe.Shape = Enum.PartType.Cylinder
		pipe.Material = Enum.Material.Neon
		pipe.CanCollide = false
	end
	for _, f in ipairs({ -0.25, 0.25 }) do
		local pipe = mk(
			"NeonPipe",
			Vector3.new(PLOT_D - 2, 0.6, 0.6),
			CFrame.new(plot.CX + f * PLOT_W, CEIL_Y - 1.4, plot.CZ) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(255, 80, 200),
			room
		)
		pipe.Shape = Enum.PartType.Cylinder
		pipe.Material = Enum.Material.Neon
		pipe.CanCollide = false
	end
end

-- Factory yard behind the room (open top, doorway from the room), the conveyor that carries
-- drop boxes to the ATM, and the ATM + Collect pad on the room's back wall.
-- PlotClient draws the boxes along the plot folder's Path1..PathN attributes (world positions).
local function buildFactory(plot)
	local f = Instance.new("Folder")
	f.Name = "Factory"
	f.Parent = plot.Folder

	local side = plot.Side
	local x0 = plot.CX - PLOT_W / 2 - 5.5 -- same outline as the room
	local x1 = plot.CX + PLOT_W / 2
	local lenX = x1 - x0 + 1
	local midX = (x0 + x1) / 2
	local backZ = plot.CZ + side * PLOT_D / 2 -- the room's back wall
	local farZ = backZ + side * FACTORY_D -- the yard's far wall
	local midZ = (backZ + farZ) / 2
	local toRoom = Vector3.new(0, 0, -side)
	local concrete = Color3.fromRGB(150, 152, 158)
	local green = Color3.fromRGB(57, 255, 120)

	-- yard
	local floor = mk(
		"YardFloor",
		Vector3.new(lenX, 0.4, FACTORY_D),
		CFrame.new(midX, 0.3, midZ),
		Color3.fromRGB(112, 114, 120),
		f
	)
	floor.Material = Enum.Material.Concrete
	for _, wx in ipairs({ x0, x1 }) do
		local w =
			mk("YardWall", Vector3.new(1, YARD_WALL_H, FACTORY_D), CFrame.new(wx, YARD_WALL_H / 2, midZ), concrete, f)
		w.Material = Enum.Material.Concrete
	end
	local farWall =
		mk("YardWall", Vector3.new(lenX, YARD_WALL_H, 1), CFrame.new(midX, YARD_WALL_H / 2, farZ), concrete, f)
	farWall.Material = Enum.Material.Concrete

	-- Slop Boxer at the far end: packs the Slops' cash into boxes
	local ax = plot.CX + ATM_DX
	local boxerZ = farZ - side * 4 -- 1 to 7 studs in from the far wall
	local boxer = mk("SlopBoxer", Vector3.new(7, 9, 6), CFrame.new(ax, 4.5, boxerZ), Color3.fromRGB(196, 60, 52), f)
	local bsg = Instance.new("SurfaceGui")
	bsg.Face = (side == 1) and Enum.NormalId.Front or Enum.NormalId.Back -- the face toward the room
	bsg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	bsg.PixelsPerStud = 40
	bsg.Parent = boxer
	textLabel(bsg, "SLOP BOXER", 0.06, 0.2)
	local startZ = farZ - side * 7.5 -- just in front of the boxer
	mk("Chute", Vector3.new(3, 3, 0.4), CFrame.new(ax, BELT_Y + 1.5, farZ - side * 7.1), Color3.fromRGB(12, 12, 14), f)

	-- slop pipe from the room (over the ATM) to the boxer
	local pipeLen = math.abs(boxerZ - backZ)
	local pipe = mk(
		"SlopPipe",
		Vector3.new(pipeLen, 1.2, 1.2),
		CFrame.new(ax, 12, (backZ + boxerZ) / 2) * CFrame.Angles(0, math.rad(90), 0),
		green,
		f
	)
	local pipeDown = mk(
		"SlopPipe",
		Vector3.new(3, 1.2, 1.2),
		CFrame.new(ax, 10.5, boxerZ) * CFrame.Angles(0, 0, math.rad(90)),
		green,
		f
	)
	for _, pp in ipairs({ pipe, pipeDown }) do
		pp.Shape = Enum.PartType.Cylinder
		pp.Material = Enum.Material.Neon
		pp.CanCollide = false
	end

	-- conveyor from the boxer to the ATM's intake
	local endZ = backZ + side * ATM_D / 2
	local beltLen = math.abs(endZ - startZ)
	local beltMidZ = (startZ + endZ) / 2
	mk("Conveyor", Vector3.new(4, 0.6, beltLen), CFrame.new(ax, BELT_Y - 0.3, beltMidZ), Color3.fromRGB(40, 42, 48), f)
	mk(
		"ConveyorBase",
		Vector3.new(3.6, BELT_Y - 0.6, beltLen),
		CFrame.new(ax, (BELT_Y - 0.6) / 2, beltMidZ),
		Color3.fromRGB(70, 74, 86),
		f
	)
	for _, dx in ipairs({ -2.15, 2.15 }) do
		mk(
			"Rail",
			Vector3.new(0.3, 0.6, beltLen),
			CFrame.new(ax + dx, BELT_Y + 0.1, beltMidZ),
			Color3.fromRGB(255, 210, 63),
			f
		)
	end
	plot.Folder:SetAttribute("PathN", 2)
	plot.Folder:SetAttribute("Path1", Vector3.new(ax, BELT_Y + DROP_BOX / 2, startZ))
	plot.Folder:SetAttribute("Path2", Vector3.new(ax, BELT_Y + DROP_BOX / 2, endZ))
	plot.DropTravel = beltLen / DROP_SPEED -- seconds from the boxer to the ATM

	-- ATM: goes through the back wall; intake on the yard side, screen on the room side
	mk("ATM", Vector3.new(ATM_W, ATM_H, ATM_D), CFrame.new(ax, 0.5 + ATM_H / 2, backZ), Color3.fromRGB(46, 50, 60), f)
	mk(
		"Intake",
		Vector3.new(3, 2.6, 0.3),
		CFrame.new(ax, BELT_Y + 1.3, endZ + side * 0.1),
		Color3.fromRGB(12, 12, 14),
		f
	)
	local screenPos = Vector3.new(ax, 0.5 + ATM_H / 2 + 1, backZ) + toRoom * (ATM_D / 2 + 0.1)
	local screen = mk(
		"AtmScreen",
		Vector3.new(ATM_W - 1, ATM_H - 3, 0.2),
		CFrame.lookAt(screenPos, screenPos + toRoom),
		Color3.fromRGB(14, 16, 20),
		f
	)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = screen
	textLabel(sg, "ATM", 0.03, 0.17, Color3.fromRGB(255, 210, 63))
	textLabel(sg, "CASH TO COLLECT", 0.22, 0.1, Color3.fromRGB(200, 205, 215))
	plot.AtmTotal = textLabel(sg, "$0", 0.34, 0.3, Color3.fromRGB(110, 255, 150))
	plot.AtmFormula = textLabel(sg, "", 0.72, 0.18)

	-- Collect pad: stand on it to collect. Outline: dim = empty, white = cash ready, gold = $1B+
	local padCenter = Vector3.new(ax, 0.65, backZ) + toRoom * (ATM_D / 2 + 0.5 + PAD_D / 2)
	local pad = mk("CollectPad", Vector3.new(PAD_W, 0.3, PAD_D), CFrame.new(padCenter), Color3.fromRGB(56, 193, 114), f)
	local psg = Instance.new("SurfaceGui")
	psg.Face = Enum.NormalId.Top
	psg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	psg.PixelsPerStud = 30
	psg.Parent = pad
	textLabel(psg, "COLLECT", 0.15, 0.7)
	plot.PadCenter = padCenter
	plot.PadOutline = {}
	for _, e in ipairs({
		{ Vector3.new(PAD_W + 0.8, 0.4, 0.4), Vector3.new(0, 0, PAD_D / 2 + 0.2) },
		{ Vector3.new(PAD_W + 0.8, 0.4, 0.4), Vector3.new(0, 0, -PAD_D / 2 - 0.2) },
		{ Vector3.new(0.4, 0.4, PAD_D), Vector3.new(PAD_W / 2 + 0.2, 0, 0) },
		{ Vector3.new(0.4, 0.4, PAD_D), Vector3.new(-PAD_W / 2 - 0.2, 0, 0) },
	}) do
		local edge =
			mk("PadEdge", e[1], CFrame.new(padCenter + e[2] + Vector3.new(0, 0.05, 0)), Color3.fromRGB(90, 94, 104), f)
		edge.Material = Enum.Material.Neon
		edge.CanCollide = false
		table.insert(plot.PadOutline, edge)
	end
end

-- Slap and rebirth blocks stand inside the room, one each side of the front doorway.
-- PLANNED: rebirth moves to its own totem/structure that players walk up to.
local function mkBlock(plot, name, dx, color, text)
	local b = mk(
		name,
		Vector3.new(3.5, 3.5, 1.5),
		CFrame.new(plot.CX + dx, 2.25, plot.CZ - plot.Side * (PLOT_D / 2 - 2.5)),
		color,
		plot.Folder
	)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 40)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 60
	gui.Adornee = b
	gui.Parent = b
	textLabel(gui, text, 0, 1)
	return b
end

-- Slop Machine: stands on each plot's -X side, facing the plot. Hexagonal-prism reels
-- (three faces show), ridges between reels, lever at the right end.
-- The client animates the reels; the server owns the parts and the attributes
-- (Unlocked / Idx / Mult / Uid on each reel, Spin / OwnerId on the machine).
local REEL_W, REEL_STEP = 3.2, 3.7
local HEX_S = L.HexSide -- hexagon side length
local HEX_A = HEX_S * math.sqrt(3) / 2 -- axis to the middle of a face
local RY = L.ReelY -- reel centre height

local function buildMachine(plot)
	local n = Config.Slot.Reels
	local H = PLOT_D -- as long as the plot is deep
	local ox = plot.CX - PLOT_W / 2 -- plot's -X edge = machine front plane
	local reelsLen = n * REEL_STEP
	local capW = (H - reelsLen) / 2
	local capZ = reelsLen / 2 + capW / 2

	-- dz: offset along the plot depth; behind: studs behind the front plane (negative = in front)
	local function part(name, size, dz, y, behind, color, parent)
		return mk(name, size, CFrame.new(ox - behind, y, plot.CZ + dz), color, parent)
	end

	local machine = Instance.new("Model")
	machine.Name = "SlotMachine"
	machine.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	machine:SetAttribute("OwnerId", 0)
	machine:SetAttribute("Spin", 0)
	machine.Parent = plot.Folder
	plot.Machine = machine

	local blue = Color3.fromRGB(70, 90, 120)
	local dark = Color3.fromRGB(44, 48, 60)
	local gold = Color3.fromRGB(255, 196, 0)

	part("Pedestal", Vector3.new(5, 3, H), 0, 1.5, 2.5, blue, machine)
	part("CabinetBack", Vector3.new(1, 9.5, H), 0, 7.75, 3.5, dark, machine)
	part("CabinetTop", Vector3.new(5, 1.6, H), 0, 11.7, 2.5, dark, machine)
	part("CabinetBottom", Vector3.new(5, 1.6, H), 0, 3.8, 2.5, dark, machine)
	local header = part("Header", Vector3.new(5, 3, H), 0, 14, 2.5, Color3.fromRGB(232, 72, 63), machine)
	for _, sz in ipairs({ -1, 1 }) do
		part("EndCap", Vector3.new(5, 6.3, capW), sz * capZ, RY, 2.5, dark, machine)
		part("Post", Vector3.new(5.4, 15.5, 1.2), sz * (H / 2 + 0.7), 7.75, 2.5, gold, machine)
	end

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Right
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = header
	plot.SignLabel = textLabel(sg, "UNCLAIMED SLOP MACHINE", 0.1, 0.8)

	-- reels: three visible faces of a hexagonal prism (upper, middle, lower)
	local reels = Instance.new("Folder")
	reels.Name = "Reels"
	reels.Parent = machine
	plot.Reels = {}
	local axisX = ox - HEX_A + 0.8 -- the middle face sticks out of the cabinet
	for j = 1, n do
		local dz = ((n + 1) / 2 - j) * REEL_STEP -- reel 1 is on the viewer's left
		local reel = Instance.new("Model")
		reel.Name = "Reel" .. j
		reel:SetAttribute("Unlocked", false)
		reel:SetAttribute("Idx", 0)
		reel:SetAttribute("Mult", 0)
		reel:SetAttribute("Uid", 0)
		for f, ang in ipairs({ 60, 0, -60 }) do
			local rad = math.rad(ang)
			local face = Instance.new("Part")
			face.Name = "Face" .. f
			face.Size = Vector3.new(0.3, HEX_S, REEL_W)
			face.Anchored = true
			face.CanCollide = false
			face.Material = Enum.Material.SmoothPlastic
			face.Color = Color3.fromRGB(245, 245, 248)
			face.CFrame = CFrame.new(axisX + HEX_A * math.cos(rad), RY + HEX_A * math.sin(rad), plot.CZ + dz)
				* CFrame.Angles(0, 0, rad)
			face.Parent = reel
		end
		reel.Parent = reels
		plot.Reels[j] = reel
	end

	-- ridges between the reels
	for k = 0, n do
		part("Ridge", Vector3.new(3.4, HEX_S * 2 + 0.6, 0.4), (n / 2 - k) * REEL_STEP, RY, 0.3, gold, machine)
	end

	-- lever on the right end (viewer's right = -Z), standing in front of the end cap
	part("LeverBase", Vector3.new(1.8, 3, 2.6), -capZ, 1.5, -1.6, blue, machine)
	part("LeverPlate", Vector3.new(1.8, 0.4, 2.6), -capZ, 3.2, -1.6, gold, machine)
	part("LeverArm", Vector3.new(0.4, 2.4, 0.4), -capZ, 4.6, -1.6, Color3.fromRGB(190, 190, 196), machine)
	local knob = part("LeverKnob", Vector3.new(1.4, 1.4, 1.4), -capZ, 6.0, -1.6, Color3.fromRGB(232, 72, 63), machine)
	knob.Shape = Enum.PartType.Ball

	-- offers (small Slop in front of each reel) live here, outside the streamed machine model
	local offers = Instance.new("Folder")
	offers.Name = "Offers"
	offers.Parent = plot.Folder
	plot.Offers = offers
	plot.Displays = {}

	local pp = mkPrompt(knob, "Pull Lever", "Slop Machine", 0)
	pp.MaxActivationDistance = Config.Reach.Lever
	pp.Triggered:Connect(function(who)
		if plot.Owner ~= who or not State[who] then
			notify(
				who,
				plot.Owner and ("That's " .. plot.Owner.DisplayName .. "'s machine!") or "Nobody owns this machine yet."
			)
			return
		end
		if not doRoll(who) then
			notify(who, "The machine is still cooling down...")
		end
	end)
end

for i = 1, NUM_PLOTS do
	local side = (i % 2 == 1) and -1 or 1 -- -1 = north of belt, 1 = south
	local col = math.ceil(i / 2)
	local cx = (col - (PER_SIDE + 1) / 2) * PLOT_PITCH
	local cz = side * PLOT_CZ

	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. i
	folder.Parent = world1

	local plot = {
		Index = i,
		CX = cx,
		CZ = cz,
		Side = side,
		Folder = folder,
		Owner = nil,
		-- spawn near the front of the plot, looking at the belt
		Spawn = CFrame.lookAt(Vector3.new(cx, 4, cz - side * (PLOT_D / 2 - 4)), Vector3.new(cx, 4, 0)),
	}

	-- office floor; the plate also runs under the Slop Machine on the -X side
	local plotPlate = mk(
		"Base",
		Vector3.new(PLOT_W + 5, 0.4, PLOT_D),
		CFrame.new(cx - 2.5, 0.3, cz),
		Color3.fromRGB(72, 78, 92),
		folder
	)
	plotPlate.Material = Enum.Material.Fabric

	buildRoom(plot)
	buildFactory(plot)
	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = folder
	plot.Dynamic = dynamic

	-- owner label, floating above the roof
	local lp = mk("OwnerPart", Vector3.new(1, 1, 1), CFrame.new(cx, CEIL_Y + 6, cz), Color3.new(1, 1, 1), folder)
	lp.Transparency = 1
	lp.CanCollide = false
	local lg = Instance.new("BillboardGui")
	lg.Size = UDim2.fromOffset(320, 60)
	lg.AlwaysOnTop = true
	lg.MaxDistance = 160
	lg.Adornee = lp
	lg.Parent = lp
	plot.OwnerLabel = textLabel(lg, "Unclaimed base", 0, 1, Color3.fromRGB(255, 210, 63))

	-- slap block
	local slap = mkBlock(plot, "Slap", -12, Color3.fromRGB(56, 193, 114), "SLAP")
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = Config.Reach.SlapBlock
	cd.Parent = slap
	cd.MouseClick:Connect(function(who)
		if plot.Owner ~= who or not State[who] then
			return
		end
		local v = slapValue(who)
		setCash(who, getCash(who) + v)
		addStat(who, "TotalCash", v)
		addStat(who, "CashThisRebirth", v)
		Remote:FireClient(who, "slap", v)
	end)

	-- rebirth block (hold to confirm)
	---------------------------------------------------------------------------------------------
	-- rebirth handler
	---------------------------------------------------------------------------------------------
	local reb = mkBlock(plot, "Rebirth", 12, Color3.fromRGB(176, 98, 232), "REBIRTH")
	plot.RebirthPrompt = mkPrompt(reb, "Rebirth (hold)", "Resets cash and base", 2)
	plot.RebirthPrompt.Triggered:Connect(function(who)
		if plot.Owner ~= who or not State[who] then
			return
		end
		local s = State[who]
		local cost = Config.RebirthCost(s.Rebirths)
		if getCash(who) < cost then
			notify(who, "Need $" .. Config.Format(cost) .. " to rebirth")
			return
		end
		local st = s.Stats
		local tokens = math.floor(st.CashThisRebirth * Config.TOKEN_RATE)
		s.Tokens += tokens
		who:SetAttribute("Tokens", s.Tokens)
		st.MaxTokens = math.max(st.MaxTokens, tokens)
		st.MaxCashInRebirth = math.max(st.MaxCashInRebirth, st.CashThisRebirth)
		st.CashThisRebirth = 0

		s.Rebirths += 1
		giveBadge(who, Config.Badges.FirstRebirth)
		if s.Rebirths >= 5 then
			giveBadge(who, Config.Badges.Rebirth5)
		end
		setCash(who, 0)
		-- the ATM is cash too, so it empties (to keep it through rebirth, delete these two lines)
		s.AtmCash = 0
		s.Pending = {}
		s.Owned = {}
		for k = 1, s.Slots do
			s.Owned[k] = 0
		end
		s.Inventory = {}
		who.leaderstats.Rebirths.Value = s.Rebirths
		refreshPlot(who)
		notify(who, "+" .. Config.Format(tokens) .. " Rebirth Tokens!")
		Remote:FireAllClients(
			"banner",
			who.DisplayName .. " REBIRTHED! (x" .. string.format("%.2f", Config.Mult(s.Rebirths)) .. ")",
			4
		)
	end)

	buildMachine(plot)
	plots[i] = plot
end

---------------------------------------------------------------------
-- Selling + refreshing a player's plot
---------------------------------------------------------------------
local function sell(p, k)
	local s = State[p]
	if not s then
		return
	end
	local sl = s.Owned[k]
	if not sl or sl == 0 then
		return
	end
	local mon = Config.Mons[sl.Id]
	local v = math.floor(mon.Price / 2)
	setCash(p, getCash(p) + v)
	s.Owned[k] = 0
	refreshPlot(p)
	notify(p, "Sold " .. mon.Name .. " for $" .. Config.Format(v))
end

-- shrinks a Slop (never grows it) until it fits a box maxW wide and maxH tall
local function fitInside(root, maxW, maxH)
	local _, size = boundsOf(root)
	local f = math.min(1, maxW / size.X, maxW / size.Z, maxH / size.Y)
	if f < 1 then
		scaleTo(root, size.Y * f)
	end
end

-- One see-through tank for Slop Spot k. sl = the equipped Slop, or nil for an empty spot.
-- The screen shows the Slop's next cash drop; PlotClient animates the countdown bar
-- (tag "SlopTank", attribute DropTime, synced to SlopOverWorld's "IncomeTick").
local function buildTank(p, plot, k, sl, mult)
	local pos = tankPos(plot, k)
	local front = Vector3.new(0, 0, -plot.Side) -- toward the door
	local metal = Color3.fromRGB(58, 62, 74)
	local up = function(y)
		return pos + Vector3.new(0, y, 0)
	end

	local tank = Instance.new("Model")
	tank.Name = "Tank" .. k
	tank.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local outer = TANK_W + 0.4
	mk("Base", Vector3.new(outer, TANK_BASE_H, outer), CFrame.new(up(TANK_BASE_H / 2)), metal, tank)
	local rim = mk(
		"Rim",
		Vector3.new(outer + 0.1, 0.2, outer + 0.1),
		CFrame.new(up(TANK_BASE_H + 0.1)),
		Color3.fromRGB(57, 255, 120),
		tank
	)
	rim.Material = Enum.Material.Neon
	local glass = mk(
		"Glass",
		Vector3.new(TANK_W, TANK_GLASS_H, TANK_W),
		CFrame.new(up(TANK_BASE_H + TANK_GLASS_H / 2)),
		Color3.fromRGB(170, 230, 255),
		tank
	)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.75
	mk("Cap", Vector3.new(outer, 0.6, outer), CFrame.new(up(TANK_BASE_H + TANK_GLASS_H + 0.3)), metal, tank)

	local screenPos = up(TANK_BASE_H / 2) + front * (outer / 2 + 0.1)
	local screen = mk(
		"Screen",
		Vector3.new(TANK_W - 0.6, TANK_BASE_H - 0.8, 0.2),
		CFrame.lookAt(screenPos, screenPos + front),
		Color3.fromRGB(18, 20, 26),
		tank
	)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Gui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.LightInfluence = 0
	sg.MaxDistance = 80
	sg.Parent = screen

	if sl then
		local m = Config.Mons[sl.Id]
		local tier = Config.MultTier(sl.Mult)

		local root = buildDisplay(sl.Id, m.ModelHeight or 4, true)
		fitInside(root, TANK_W - 1.2, TANK_GLASS_H - 1.5)
		local cf = boundsOf(root)
		root:PivotTo(root:GetPivot() + (glass.Position - cf.Position)) -- floats in the middle of the glass
		root.Parent = tank

		textLabel(sg, m.Name, 0.04, 0.3, Config.Rarities[m.Rarity].Color)
		local drop = textLabel(
			sg,
			string.format(
				'+$%s  <font color="#%s">%s</font>',
				Config.Format(slopIncome(sl) * mult),
				tier.Color:ToHex(),
				tier.Name
			),
			0.34,
			0.28,
			Color3.fromRGB(110, 255, 150)
		)
		drop.RichText = true

		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.Position = UDim2.fromScale(0.06, 0.67)
		bar.Size = UDim2.fromScale(0.88, 0.27)
		bar.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
		bar.BorderSizePixel = 0
		bar.Parent = sg
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.fromRGB(56, 193, 114)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		local timer = textLabel(bar, "Next drop", 0, 1)
		timer.Name = "Timer"
		timer.ZIndex = 2

		tank:SetAttribute("DropTime", m.DropTime)

		local pp = mkPrompt(glass, "Sell for $" .. Config.Format(math.floor(m.Price / 2)), m.Name, Config.Hold.TankSell)
		pp.MaxActivationDistance = Config.Reach.TankSell
		pp.Triggered:Connect(function(who)
			if who == p then
				sell(p, k)
			end
		end)
	else
		textLabel(sg, "EMPTY SPOT", 0.1, 0.42, Color3.fromRGB(150, 155, 165))
		textLabel(sg, "Equip a Slop from your inventory", 0.58, 0.28, Color3.fromRGB(200, 205, 215))
	end

	CollectionService:AddTag(tank, "SlopTank")
	tank.Parent = plot.Dynamic
end

function refreshPlot(p)
	local s = State[p]
	if not s or not s.Plot then
		return
	end
	local plot = s.Plot
	plot.Dynamic:ClearAllChildren()

	-- one tank per unlocked Slop Spot; locked spots show nothing
	local mult = totalMult(p) / adminMult
	for k = 1, s.Slots do
		local sl = s.Owned[k]
		buildTank(p, plot, k, (sl and sl ~= 0) and sl or nil, mult)
	end

	plot.RebirthPrompt.ObjectText = "$"
		.. Config.Format(Config.RebirthCost(s.Rebirths))
		.. " for x"
		.. string.format("%.2f", Config.Mult(s.Rebirths + 1))

	checkPlotBadges(p)
	updateIncome(p)
end

---------------------------------------------------------------------
-- Conveyor belt
---------------------------------------------------------------------
local function pickMon()
	local total = 0
	for _, r in ipairs(Config.Rarities) do
		total += r.Weight
	end
	local roll = math.random() * total
	local rar = 1
	for i, r in ipairs(Config.Rarities) do
		roll -= r.Weight
		if roll <= 0 then
			rar = i
			break
		end
	end
	local pool = {}
	for i, m in ipairs(Config.Mons) do
		if m.Rarity == rar then
			table.insert(pool, i)
		end
	end
	return pool[math.random(#pool)]
end

local function buyItem(p, item)
	local s = State[p]
	if not s or not s.Plot then
		return
	end
	if item.Taken or not item.Part.Parent then
		return
	end

	local m = Config.Mons[item.Idx]
	if getCash(p) < m.Price then
		notify(p, "Not enough cash for " .. m.Name)
		return
	end
	local slot
	if Config.BUY_TO_INVENTORY then
		if #s.Inventory >= Config.INV_MAX then
			notify(p, "Inventory full! Sell some Slops first.")
			return
		end
	else
		slot = table.find(s.Owned, 0)
		if not slot then
			notify(p, "Your base is full! Sell something or expand.")
			return
		end
	end

	item.Taken = true
	setCash(p, getCash(p) - m.Price)
	local sl = newSlop(item.Idx, item.Mult)
	if Config.BUY_TO_INVENTORY then
		table.insert(s.Inventory, sl)
	else
		s.Owned[slot] = sl
	end
	item.Part:Destroy()
	refreshPlot(p)
	addStat(p, "SlopsPurchased", 1)
	discover(p, item.Idx)

	giveSlopBadges(p, m)
	if m.Rarity >= 4 then
		Remote:FireAllClients("banner", p.DisplayName .. " bought " .. m.Name .. "!", 4)
	end
end

local function spawnItem()
	local idx = pickMon()
	local m = Config.Mons[idx]
	local mult = Config.RollMult()
	local tier = Config.MultTier(mult)
	local sub = "$"
		.. Config.Format(m.Price)
		.. '  <font color="#'
		.. tier.Color:ToHex()
		.. '">'
		.. tier.Name
		.. "</font>"
	local part = makeMon(idx, "belt", sub, Color3.fromRGB(110, 255, 150))
	part.Parent = world1
	placeAt(part, Vector3.new(BELT_HALF - 2, 2.6, 0))

	local item = { Part = part, Idx = idx, Mult = mult, Taken = false }
	local pp = mkPrompt(primaryOf(part), "Buy", m.Name, 0)
	pp.Triggered:Connect(function(who)
		buyItem(who, item)
	end)
	table.insert(items, item)

	if m.Rarity >= 5 then
		Remote:FireAllClients(
			"banner",
			"A " .. Config.Rarities[m.Rarity].Name .. " " .. m.Name .. " is on the belt!",
			4
		)
	end
end

RunService.Heartbeat:Connect(function(dt)
	local step = SPEED * dt
	local spin = math.rad(90) * dt
	for i = #items, 1, -1 do
		local part = items[i].Part
		if not part.Parent then
			table.remove(items, i)
		else
			local cf = part:GetPivot()
			if cf.Position.X - step < -BELT_HALF - 4 then
				part:Destroy()
				table.remove(items, i)
			else
				part:PivotTo((cf - Vector3.new(step, 0, 0)) * CFrame.Angles(0, spin, 0))
			end
		end
	end

	local col = Color3.fromHSV((os.clock() * 0.4) % 1, 0.8, 1)
	for part in pairs(rainbow) do
		if part.Parent then
			part.Color = col
		else
			rainbow[part] = nil
		end
	end
end)

--Belt spawn loop
task.spawn(function()
	while true do
		if beltOn then
			local ok, err = pcall(spawnItem)
			if not ok then
				warn("[Slop] spawnItem failed: " .. tostring(err))
			end
			local gap = Config.BeltSpawnGap
			task.wait(raining and gap.Raining or (gap.Min + math.random() * gap.Random))
		else
			task.wait(0.5)
		end
	end
end)

---------------------------------------------------------------------
-- Saving / loading
---------------------------------------------------------------------
local function loadData(p)
	local ok, data = pcall(function()
		return Store:GetAsync("P_" .. p.UserId)
	end)

	if not ok then
		warn(
			"[Slop] Could not load saved data for "
				.. p.Name
				.. ": "
				.. tostring(data)
				.. "  (In Studio: publish the place, then turn on Game Settings > Security > Enable Studio Access to API Services.)"
		)
	end

	-- In Studio we let play-testing continue (and purchases grant) even when saving is unavailable.
	-- In a real server, Loaded stays false on failure so we never overwrite or lose a player's data.
	local s = {
		Owned = {},
		Slots = START_SLOTS,
		Rebirths = 0,
		Loaded = ok or RunService:IsStudio(),
		Passes = {},
		BoostUntil = 0,
		Receipts = {},
		DailyLast = 0,
		DailyStreak = 0,
		DailyClaimed = {},
		DailySeen = {},
		Version = Config.DATA_VERSION,
		Inventory = {},
		Discovered = {},
		Tokens = 0,
		Stats = {},
		RollCount = 1,
		RollCap = Config.Wheel.CapStart,
		SpeedLevel = 0,
		NextRoll = 0,
		AtmCash = 0, -- waiting in the ATM (saved)
		Pending = {}, -- drops still on the conveyor: { At = os.clock() arrival, Amount }
	}
	for k, v in pairs(Config.DefaultStats) do
		s.Stats[k] = v
	end
	local cash = 0

	if ok and type(data) == "table" then
		local ver = tonumber(data.Version) or 1

		s.Slots = math.clamp(tonumber(data.Slots) or START_SLOTS, START_SLOTS, MAX_SLOTS)
		s.Rebirths = tonumber(data.Rebirths) or 0
		cash = tonumber(data.Cash) or 0
		s.BoostUntil = tonumber(data.BoostUntil) or 0
		s.DailyLast = tonumber(data.DailyLast) or 0
		s.DailyStreak = tonumber(data.DailyStreak) or 0
		if type(data.DailyClaimed) == "table" then
			s.DailyClaimed = data.DailyClaimed
		end
		if type(data.DailySeen) == "table" then
			s.DailySeen = data.DailySeen
		end
		if type(data.Receipts) == "table" then
			s.Receipts = data.Receipts
		end

		for i = 1, s.Slots do
			s.Owned[i] = cleanSlop(data.Owned and data.Owned[i]) or 0
		end

		s.Tokens = tonumber(data.Tokens) or 0
		s.AtmCash = math.max(0, tonumber(data.AtmCash) or 0)
		if type(data.Inventory) == "table" then
			for _, v in ipairs(data.Inventory) do
				local sl = cleanSlop(v)
				if sl then
					table.insert(s.Inventory, sl)
				end
			end
		end
		if type(data.Stats) == "table" then
			for k in pairs(s.Stats) do
				s.Stats[k] = tonumber(data.Stats[k]) or s.Stats[k]
			end
		end
		if type(data.Discovered) == "table" then
			for k in pairs(data.Discovered) do
				if Config.Mons[tonumber(k)] then
					s.Discovered[tostring(k)] = true
				end
			end
		end

		s.RollCap =
			math.clamp(tonumber(data.RollCap) or Config.Wheel.CapStart, Config.Wheel.CapStart, Config.Wheel.CapMax)
		s.RollCount = math.clamp(tonumber(data.RollCount) or 1, 1, s.RollCap)
		s.SpeedLevel = math.clamp(tonumber(data.SpeedLevel) or 0, 0, Config.Wheel.SpeedLevels)

		-- v3: equip slots are now 5, so keep the best 5 and move the rest to inventory
		if ver < 3 then
			local all = {}
			for _, sl in ipairs(s.Owned) do
				if sl ~= 0 then
					table.insert(all, sl)
				end
			end
			for _, sl in ipairs(s.Inventory) do
				table.insert(all, sl)
			end
			table.sort(all, function(a, b)
				return slopIncome(a) > slopIncome(b)
			end)
			s.Slots = START_SLOTS
			s.Owned, s.Inventory = {}, {}
			for k = 1, START_SLOTS do
				s.Owned[k] = all[k] or 0
			end
			for k = START_SLOTS + 1, #all do
				table.insert(s.Inventory, all[k])
			end
		end
	else
		for i = 1, s.Slots do
			s.Owned[i] = 0
		end
	end

	for _, sl in ipairs(s.Owned) do
		if sl ~= 0 then
			s.Discovered[tostring(sl.Id)] = true
		end
	end
	for _, sl in ipairs(s.Inventory) do
		s.Discovered[tostring(sl.Id)] = true
	end
	return s, cash
end

local function saveData(p)
	local s = State[p]
	if not s or not s.Loaded or not p:FindFirstChild("leaderstats") then
		return false
	end
	if s.Cheated then
		return false
	end -- DevTools were used this session (see Config.DEV_BLOCK_SAVE)
	while #s.Receipts > 100 do
		table.remove(s.Receipts, 1)
	end
	local atm = s.AtmCash -- drops still on the conveyor count as in the ATM
	for _, d in ipairs(s.Pending) do
		atm += d.Amount
	end
	local ok = pcall(function()
		Store:SetAsync("P_" .. p.UserId, {
			Cash = getCash(p),
			Rebirths = s.Rebirths,
			Slots = s.Slots,
			Owned = s.Owned,
			BoostUntil = s.BoostUntil,
			Receipts = s.Receipts,
			DailyLast = s.DailyLast,
			DailyStreak = s.DailyStreak,
			DailyClaimed = s.DailyClaimed,
			DailySeen = s.DailySeen,
			Version = Config.DATA_VERSION,
			Inventory = s.Inventory,
			Stats = s.Stats,
			Discovered = s.Discovered,
			Tokens = s.Tokens,
			AtmCash = atm,
			RollCount = s.RollCount,
			RollCap = s.RollCap,
			SpeedLevel = s.SpeedLevel,
		})
	end)
	return ok
end

local function equipBest(p, limit)
	local s = State[p]
	if not s then
		return
	end
	local all = {}
	for _, sl in ipairs(s.Owned) do
		if sl ~= 0 then
			table.insert(all, sl)
		end
	end
	for _, sl in ipairs(s.Inventory) do
		table.insert(all, sl)
	end
	table.sort(all, function(a, b)
		return slopIncome(a) > slopIncome(b)
	end)
	limit = math.min(limit or s.Slots, s.Slots)
	local owned, inv = {}, {}
	for k = 1, s.Slots do
		owned[k] = 0
	end
	for i, sl in ipairs(all) do
		if i <= limit then
			owned[i] = sl
		else
			table.insert(inv, sl)
		end
	end
	s.Owned, s.Inventory = owned, inv
	refreshPlot(p)
end

---------------------------------------------------------------------
-- Slop machine state (reels + rolling)
---------------------------------------------------------------------
local function buildOfferDisplay(plot, o)
	local m = Config.Mons[o.Id]
	local r = Config.Rarities[m.Rarity]
	local tier = Config.MultTier(o.Mult)
	local x = plot.CX - PLOT_W / 2 + 4.5
	local z = plot.CZ + ((Config.Slot.Reels + 1) / 2 - o.Reel) * REEL_STEP

	local holder = Instance.new("Model")
	holder.Name = "Offer" .. o.Uid
	mk("OfferPad", Vector3.new(3.4, 0.2, 3.4), CFrame.new(x, 0.6, z), Color3.fromRGB(40, 90, 36), holder)

	local root = buildDisplay(o.Id, Config.Slot.OfferHeight)
	root.Parent = holder
	placeAt(root, Vector3.new(x, 2.2, z)) -- feet land on the pad

	local primary = primaryOf(root)
	local cf, size = boundsOf(root)
	local top = cf.Position.Y + size.Y / 2
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 78)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top - primary.Position.Y + 1.6, 0)
	gui.MaxDistance = 60
	gui.Adornee = primary
	gui.Parent = primary
	textLabel(gui, m.Name, 0, 0.36, r.Color)
	textLabel(gui, tier.Name, 0.36, 0.28, tier.Color)
	textLabel(gui, "$" .. Config.Format(m.Price), 0.64, 0.36, Color3.fromRGB(110, 255, 150))

	local pp = mkPrompt(primary, "Buy  $" .. Config.Format(m.Price), m.Name, Config.Hold.OfferBuy)
	pp.MaxActivationDistance = Config.Reach.OfferBuy
	pp.Triggered:Connect(function(who)
		if plot.Owner ~= who then
			notify(who, "That's not your machine!")
			return
		end
		buyOffer(who, o.Uid)
	end)

	holder.Parent = plot.Offers
	return holder
end

-- keeps the little Slops in front of the reels in step with the player's offers
local function syncDisplays(p)
	local s = State[p]
	if not s or not s.Plot then
		return
	end
	local plot = s.Plot
	local wanted = {}
	for _, o in ipairs(s.Offers or {}) do
		if o.Shown then
			wanted[o.Uid] = o
		end
	end
	for uid, d in pairs(plot.Displays) do
		if not wanted[uid] then
			d:Destroy()
			plot.Displays[uid] = nil
		end
	end
	for uid, o in pairs(wanted) do
		if not plot.Displays[uid] then
			plot.Displays[uid] = buildOfferDisplay(plot, o)
		end
	end
end

function refreshMachine(p)
	local s = State[p]
	if not s or not s.Plot then
		return
	end
	local plot = s.Plot
	local order = Config.Slot.ReelOrder
	local byReel = {}
	for _, o in ipairs(s.Offers or {}) do
		if o.Reel then
			byReel[o.Reel] = o
		end
	end
	for j, reel in ipairs(plot.Reels) do
		local unlocked = (table.find(order, j) or math.huge) <= s.RollCount
		local o = byReel[j]
		reel:SetAttribute("Unlocked", unlocked)
		reel:SetAttribute("Idx", o and o.Id or 0)
		reel:SetAttribute("Mult", o and o.Mult or 0)
		reel:SetAttribute("Uid", o and o.Uid or 0)
	end
	plot.Machine:SetAttribute("OwnerId", p.UserId)
	plot.SignLabel.Text = string.format(
		"%s's SLOP MACHINE  |  Rolls %d/%d  |  Cooldown %.1fs",
		p.DisplayName,
		s.RollCount,
		s.RollCap,
		Config.RollCooldown(s.SpeedLevel)
	)
	syncDisplays(p)
end

function clearMachine(plot)
	for _, reel in ipairs(plot.Reels) do
		reel:SetAttribute("Unlocked", false)
		reel:SetAttribute("Idx", 0)
		reel:SetAttribute("Mult", 0)
		reel:SetAttribute("Uid", 0)
	end
	for uid, d in pairs(plot.Displays) do
		d:Destroy()
		plot.Displays[uid] = nil
	end
	plot.Machine:SetAttribute("OwnerId", 0)
	plot.SignLabel.Text = "UNCLAIMED SLOP MACHINE"
end

-- RollCount Slops per pull, cooldown from SpeedLevel. Offers appear in front of the reels once they stop.
function doRoll(p)
	local s = State[p]
	if not s or not s.Loaded or not s.Plot then
		return false
	end
	local now = os.clock()
	if now < s.NextRoll - 0.1 then
		return false
	end
	s.NextRoll = now + Config.RollCooldown(s.SpeedLevel)
	s.Offers = {} -- leftovers from the last pull are gone
	s.OfferSeq = s.OfferSeq or 0
	local order = Config.Slot.ReelOrder
	for k = 1, math.min(s.RollCount, #order) do
		local idx = pickMon()
		s.OfferSeq += 1
		local sl = newSlop(idx)
		sl.Uid = s.OfferSeq
		sl.Reel = order[k]
		sl.Shown = false
		table.insert(s.Offers, sl)
		addStat(p, "SlopsRolled", 1)
		local m = Config.Mons[idx]
		if m.Rarity >= 5 then
			task.delay(Config.Slot.SpinTime, function()
				Remote:FireAllClients("banner", p.DisplayName .. " rolled " .. m.Name .. "!", 4)
			end)
		end
	end
	refreshMachine(p)
	s.Plot.Machine:SetAttribute("Spin", (s.Plot.Machine:GetAttribute("Spin") or 0) + 1) -- set last: clients animate on this

	local seq = s.OfferSeq
	task.delay(Config.Slot.SpinTime + 0.1, function()
		if State[p] ~= s or s.OfferSeq ~= seq then
			return
		end -- a newer pull replaced these
		for _, o in ipairs(s.Offers) do
			o.Shown = true
		end
		syncDisplays(p)
	end)
	return true
end

function buyOffer(p, uid)
	local s = State[p]
	if not s or not s.Offers then
		return false
	end
	for i, o in ipairs(s.Offers) do
		if o.Uid == uid then
			local m = Config.Mons[o.Id]
			if #s.Inventory >= Config.INV_MAX then
				notify(p, "Inventory full! Sell some Slops first.")
				return false
			end
			if getCash(p) < m.Price then
				notify(p, "Not enough cash for " .. m.Name)
				return false
			end
			setCash(p, getCash(p) - m.Price)
			table.insert(s.Inventory, newSlop(o.Id, o.Mult))
			table.remove(s.Offers, i)
			addStat(p, "SlopsPurchased", 1)
			discover(p, o.Id)
			giveSlopBadges(p, m)
			if m.Rarity >= 4 then
				Remote:FireAllClients("banner", p.DisplayName .. " bought " .. m.Name .. "!", 4)
			end
			notify(p, "Bought " .. m.Name .. "! It's in your inventory.")
			refreshMachine(p)
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
-- Menu: inventory, upgrades, stats
---------------------------------------------------------------------
local Menu = Instance.new("RemoteFunction")
Menu.Name = "SlopMenu"
Menu.Parent = RS

local function menuSnapshot(p, results)
	local s = State[p]
	local found = 0
	for _ in pairs(s.Discovered) do
		found += 1
	end
	return {
		Owned = s.Owned,
		Inventory = s.Inventory,
		Slots = s.Slots,
		Tokens = s.Tokens,
		RollCount = s.RollCount,
		RollCap = s.RollCap,
		SpeedLevel = s.SpeedLevel,
		Cooldown = Config.RollCooldown(s.SpeedLevel),
		Wait = math.max(0, s.NextRoll - os.clock()),
		Stats = s.Stats,
		Discovered = found,
		TotalSlops = #Config.Mons,
		Results = results,
	}
end

local function isIndex(v)
	return type(v) == "number" and v % 1 == 0 and v >= 1
end

local function spendTokens(p, cost)
	local s = State[p]
	if s.Tokens < cost then
		notify(p, "Not enough Rebirth Tokens (need " .. Config.Format(cost) .. ")")
		return false
	end
	s.Tokens -= cost
	return true
end

Menu.OnServerInvoke = function(p, action, a, b)
	local s = State[p]
	if not s or not s.Loaded then
		return nil
	end
	s.Offers = s.Offers or {}
	s.OfferSeq = s.OfferSeq or 0
	local W = Config.Wheel

	if action == "equip" then
		local sl = isIndex(a) and s.Inventory[a]
		if sl then
			local slot = table.find(s.Owned, 0)
			if slot and slot <= s.Slots then
				table.remove(s.Inventory, a)
				s.Owned[slot] = sl
				refreshPlot(p)
			else
				notify(p, "No free Slop Spot. Swap one out, or buy more with tokens.")
			end
		end
	elseif action == "swap" then
		local inv = isIndex(a) and s.Inventory[a]
		local out = isIndex(b) and s.Owned[b]
		if inv and type(out) == "table" then
			s.Owned[b] = inv
			s.Inventory[a] = out
			refreshPlot(p)
		end
	elseif action == "unequip" then
		local sl = isIndex(a) and s.Owned[a]
		if sl and sl ~= 0 then
			if #s.Inventory >= Config.INV_MAX then
				notify(p, "Inventory full! Sell some Slops first.")
			else
				s.Owned[a] = 0
				table.insert(s.Inventory, sl)
				refreshPlot(p)
			end
		end
	elseif action == "equipBest" then
		equipBest(p)
	elseif action == "sell" then
		local sl = isIndex(a) and s.Inventory[a]
		if sl then
			table.remove(s.Inventory, a)
			local mon = Config.Mons[sl.Id]
			local v = math.floor(mon.Price / 2)
			setCash(p, getCash(p) + v)
			notify(p, "Sold " .. mon.Name .. " for $" .. Config.Format(v))
		end
	elseif action == "sellEquipped" then
		if isIndex(a) then
			sell(p, a)
		end
	elseif action == "buyOffer" then
		buyOffer(p, a)
	elseif action == "upgradeRolls" then
		if s.RollCount < s.RollCap then
			local cost = Config.RollUpgradeCost(s.RollCount)
			if getCash(p) >= cost then
				setCash(p, getCash(p) - cost)
				s.RollCount += 1
			else
				notify(p, "Need $" .. Config.Format(cost))
			end
		end
	elseif action == "upgradeCap" then
		if s.RollCap < W.CapMax and spendTokens(p, Config.CapUpgradeCost(s.RollCap)) then
			s.RollCap += 1
		end
	elseif action == "upgradeSpeed" then
		if s.SpeedLevel < W.SpeedLevels and spendTokens(p, Config.SpeedUpgradeCost(s.SpeedLevel)) then
			s.SpeedLevel += 1
		end
	elseif action == "buySlot" then
		if s.Slots < MAX_SLOTS and spendTokens(p, Config.SlotCost(s.Slots)) then
			s.Slots += 1
			table.insert(s.Owned, 0)
			giveBadge(p, Config.Badges.FirstExpand)
			refreshPlot(p)
		end
	end

	refreshMachine(p)
	p:SetAttribute("Tokens", s.Tokens)
	return menuSnapshot(p)
end

---------------------------------------------------------------------
-- Daily rewards (login streak)
---------------------------------------------------------------------
local DAY = 86400

local DailyRF = Instance.new("RemoteFunction")
DailyRF.Name = "SlopDaily"
DailyRF.Parent = RS

-- Counts today as a login day if it hasn't been counted yet.
local function dailyRefresh(s)
	local today = os.time() // DAY
	if s.DailyLast == today then
		return
	end

	if s.DailyLast == today - 1 and s.DailyStreak < 7 then
		s.DailyStreak += 1 -- consecutive day: unlock the next reward
	else
		s.DailyStreak = 1 -- first login, missed a day, or finished the week
		s.DailyClaimed = {}
	end
	s.DailyLast = today
end

local function dailySnapshot(s)
	return {
		Unlocked = s.DailyStreak,
		Claimed = s.DailyClaimed,
		Seen = s.DailySeen,
		SecondsLeft = DAY - (os.time() % DAY),
	}
end

-- Gives the reward. Returns false (and gives nothing) if it can't, so the day stays claimable.
local function grantDailyReward(p, day)
	local s = State[p]
	local r = Config.DailyRewards[day]
	if not s or not r then
		return false
	end
	local seenKey = "Day" .. day
	local isFirst = (r.First ~= nil or r.FirstIdx ~= nil) and not s.DailySeen[seenKey]

	if r.Kind == "Cash" then
		local amount
		if isFirst and r.First then
			amount = r.First
		else
			local perHour = incomePerSec(p) / adminMult * 3600
			amount = math.max(r.Min or 0, math.floor(perHour * r.Pct))
		end
		setCash(p, getCash(p) + amount)
		notify(p, "Daily reward: +$" .. Config.Format(amount))
	elseif r.Kind == "Boost" then
		s.BoostUntil = math.max(os.time(), s.BoostUntil) + r.Seconds
		p:SetAttribute("BoostUntil", s.BoostUntil)
		refreshPlot(p)
		notify(p, "Daily reward: 2x income for " .. (r.Seconds // 3600) .. "h!")
	elseif r.Kind == "Mon" then
		if #s.Inventory >= Config.INV_MAX then
			notify(p, "Your inventory is full! Sell something, then claim your Day " .. day .. " reward.")
			return false
		end
		local idx = (isFirst and r.FirstIdx) or r.Pool[math.random(#r.Pool)]
		table.insert(s.Inventory, newSlop(idx))
		discover(p, idx)
		notify(p, "Daily reward: " .. Config.Mons[idx].Name .. "! Check your inventory.")
	else
		return false
	end

	if isFirst then
		s.DailySeen[seenKey] = true
	end
	return true
end

DailyRF.OnServerInvoke = function(p, action, day)
	local s = State[p]
	if not s or not s.Loaded then
		return nil
	end

	dailyRefresh(s)
	if action == "claim" and type(day) == "number" and day % 1 == 0 and day >= 1 and day <= 7 then
		local key = tostring(day)
		if day <= s.DailyStreak and not s.DailyClaimed[key] then
			if grantDailyReward(p, day) then
				s.DailyClaimed[key] = true
				task.spawn(saveData, p) -- save right away so a quick rejoin can't re-claim
			end
		end
	end
	return dailySnapshot(s)
end

---------------------------------------------------------------------
-- Players joining / leaving
---------------------------------------------------------------------
local function grantPass(p, name)
	local s = State[p]
	if not s then
		return
	end
	s.Passes[name] = true
	p:SetAttribute("Pass_" .. name, true)
	refreshPlot(p)
end

local function loadPasses(p)
	for name, id in pairs(Config.Passes) do
		if id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(p.UserId, id)
			end)
			if ok and owns then
				grantPass(p, name)
			end
		end
	end
end

local function teleport(p)
	local s = State[p]
	if not s or not s.Plot then
		return
	end
	local char = p.Character
	if not char then
		return
	end
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		char:PivotTo(s.Plot.Spawn)
	end
end

-- HUD "BASE" pop-up and BASE button (SlopClient). The server does the move, so it only ever goes to your own plot.
local lastHome = {} -- [player] = os.clock() of the last teleport
Remote.OnServerEvent:Connect(function(p, action)
	if action == "home" then
		local now = os.clock()
		if now - (lastHome[p] or 0) < 1 then
			return
		end
		lastHome[p] = now
		teleport(p)
	end
end)

local function onJoin(p)
	local s, cash = loadData(p)
	State[p] = s
	p:SetAttribute("Tokens", s.Tokens)
	p:SetAttribute("BoostUntil", s.BoostUntil)

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local function nv(name, v)
		local n = Instance.new("NumberValue")
		n.Name = name
		n.Value = v
		n.Parent = ls
	end
	nv("Cash", cash)
	nv("Rebirths", s.Rebirths)
	nv("Income", 0)
	ls.Parent = p

	giveBadge(p, Config.Badges.Welcome) --welcome badge for first time players

	for _, plot in ipairs(plots) do
		if not plot.Owner then
			plot.Owner = p
			s.Plot = plot
			break
		end
	end

	if s.Plot then
		s.Plot.OwnerLabel.Text = p.DisplayName .. "'s Base"
		p:SetAttribute("PlotCenter", Vector3.new(s.Plot.CX, 0, s.Plot.CZ)) -- SlopClient shows "TP TO BASE" when far from it
		refreshPlot(p)
		refreshMachine(p)
	else
		notify(p, "All bases are taken. You can watch, but not play.")
	end

	task.spawn(loadPasses, p)

	p.CharacterAdded:Connect(function()
		teleport(p)
	end)
	if p.Character then
		task.spawn(teleport, p)
	end
end

local function onLeave(p)
	saveData(p)
	local s = State[p]
	if s and s.Plot then
		s.Plot.Owner = nil
		s.Plot.Dynamic:ClearAllChildren()
		s.Plot.OwnerLabel.Text = "Unclaimed base"
		clearMachine(s.Plot)
		clearAtm(s.Plot)
	end
	State[p] = nil
	badgeSeen[p] = nil
	lastHome[p] = nil
end

Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		saveData(p)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_SECONDS)
		for _, p in ipairs(Players:GetPlayers()) do
			saveData(p)
		end
	end
end)

---------------------------------------------------------------------
-- Income tick
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(Config.INCOME_TICK)
		-- tank countdown bars (PlotClient) restart from this shared server time
		world1:SetAttribute("IncomeTick", Workspace:GetServerTimeNow())
		local drops = {} -- { { P = plot index, V = { value per Slop } } } for PlotClient
		for p, s in pairs(State) do
			if p.Parent and p:FindFirstChild("leaderstats") then
				if s.BoostUntil > 0 and s.BoostUntil <= os.time() then
					s.BoostUntil = 0
					p:SetAttribute("BoostUntil", 0)
					refreshPlot(p)
					notify(p, "Your 2x boost ended")
				end

				-- every equipped Slop drops a box; its cash reaches the ATM when the box does.
				-- All boosts (incl. admin x5) still apply here until build step 4 moves them to the ATM.
				if s.Plot then
					local mult = totalMult(p)
					local values, total = {}, 0
					for _, sl in ipairs(s.Owned) do
						if sl ~= 0 then
							local v = slopIncome(sl) * mult
							total += v
							table.insert(values, v)
						end
					end
					if total > 0 then
						-- +0.5s: PlotClient spreads each second's boxes over that second
						table.insert(s.Pending, { At = os.clock() + s.Plot.DropTravel + 0.5, Amount = total })
						table.insert(drops, { P = s.Plot.Index, V = values })
					end
				end

				-- slaps still go straight to the wallet
				if s.Passes.AutoSlap then
					local gain = slapValue(p)
					setCash(p, getCash(p) + gain)
					addStat(p, "TotalCash", gain)
					addStat(p, "CashThisRebirth", gain)
				end
			end
		end
		if #drops > 0 then
			Remote:FireAllClients("drops", drops)
		end
	end
end)

---------------------------------------------------------------------
-- ATM: drops arriving, and collecting on the pad
---------------------------------------------------------------------
local function onPad(p, plot)
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local d = hrp.Position - plot.PadCenter
	return math.abs(d.X) <= PAD_W / 2 + 0.5 and math.abs(d.Z) <= PAD_D / 2 + 0.5 and d.Y < 8
end

-- no cooldown: standing on the pad keeps collecting as boxes arrive
local function collectAtm(p)
	local s = State[p]
	local amount = math.floor(s.AtmCash)
	if amount < 1 then
		return
	end
	s.AtmCash -= amount
	setCash(p, getCash(p) + amount)
	addStat(p, "TotalCash", amount) -- cash counts as earned when collected
	addStat(p, "CashThisRebirth", amount)
	Remote:FireClient(p, "collect", amount)
end

task.spawn(function()
	while true do
		task.wait(Config.COLLECT_CHECK)
		local now = os.clock()
		for p, s in pairs(State) do
			if s.Plot and p.Parent and p:FindFirstChild("leaderstats") then
				local before = math.floor(s.AtmCash)
				while s.Pending[1] and s.Pending[1].At <= now do
					s.AtmCash += table.remove(s.Pending, 1).Amount
				end
				if onPad(p, s.Plot) then
					collectAtm(p)
				end
				if math.floor(s.AtmCash) ~= before then
					updateAtm(p)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
-- Random server events
---------------------------------------------------------------------
local function updateAllIncome()
	for p in pairs(State) do
		updateIncome(p)
	end
end

local eventRunning = false
local EVENT_KINDS = { "AdminAbuse", "Rain", "BeltRush", "LuckyBlock" }

-- Runs one server event and waits until it ends. Returns false if another event is already running.
local function runEvent(kind)
	if eventRunning then
		return false
	end
	eventRunning = true
	local ev = Config.Events[kind]
	if kind == "AdminAbuse" then
		adminMult = ev.Mult
		updateAllIncome()
		Remote:FireAllClients("banner", "ADMIN ABUSE! Income x" .. ev.Mult .. " for " .. ev.Seconds .. "s", ev.Seconds)
		task.wait(ev.Seconds)
		adminMult = 1
		updateAllIncome()
	elseif kind == "Rain" then
		raining = true
		beltOn = true
		Remote:FireAllClients("banner", "RAINING BRAINROT! The belt is flooded for " .. ev.Seconds .. "s", ev.Seconds)
		task.wait(ev.Seconds)
		raining = false
		beltOn = false
	elseif kind == "BeltRush" then
		beltOn = true
		Remote:FireAllClients(
			"banner",
			"BELT RUSH! Slops are rolling down the belt for " .. ev.Seconds .. "s",
			ev.Seconds
		)
		task.wait(ev.Seconds)
		beltOn = false
	elseif kind == "LuckyBlock" then
		for p in pairs(State) do
			if p:FindFirstChild("leaderstats") then
				local gift = math.max(ev.MinCash, math.floor(incomePerSec(p) * ev.IncomeSeconds))
				setCash(p, getCash(p) + gift)
				notify(p, "Lucky Block! +$" .. Config.Format(gift))
			end
		end
		Remote:FireAllClients("banner", "LUCKY BLOCK! Free cash for everyone", 4)
	end
	eventRunning = false
	return true
end

task.spawn(function()
	while true do
		local evs = Config.Events
		task.wait(math.random(evs.GapMin, evs.GapMax))
		-- pick one event by weight (see Config.Events)
		local total = 0
		for _, kind in ipairs(evs.Order) do
			total += evs[kind].Weight
		end
		local r = math.random() * total
		local pick = evs.Order[#evs.Order]
		for _, kind in ipairs(evs.Order) do
			r -= evs[kind].Weight
			if r < 0 then
				pick = kind
				break
			end
		end
		runEvent(pick)
	end
end)

---------------------------------------------------------------------
-- Monetization: Game Passes + Developer Products
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, passId, purchased)
	if not purchased or not State[p] then
		return
	end
	for name, id in pairs(Config.Passes) do
		if id ~= 0 and id == passId then
			grantPass(p, name)
			notify(p, "Thanks! Unlocked: " .. name)
		end
	end
end)

local function hasReceipt(s, purchaseId)
	for _, v in ipairs(s.Receipts) do
		if v == purchaseId then
			return true
		end
	end
	return false
end

local function giveCashPack(p, seconds, minimum)
	local perSec = incomePerSec(p) / adminMult
	local gift = math.max(minimum, math.floor(perSec * seconds))
	setCash(p, getCash(p) + gift)
	notify(p, "+$" .. Config.Format(gift) .. "! Thanks for the support")
end

MarketplaceService.ProcessReceipt = function(info)
	print("[Slop] Receipt received. ProductId:", info.ProductId, "PurchaseId:", info.PurchaseId)
	local p = Players:GetPlayerByUserId(info.PlayerId)
	local s = p and State[p]
	if not p or not s then
		warn("[Slop] Receipt not processed: player is not in the game (yet).")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not s.Loaded then
		warn("[Slop] Receipt not processed: this player's data did not load, so we refuse to grant (it could be lost).")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Roblox can retry receipts, so never grant the same purchase twice
	if hasReceipt(s, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local id = info.ProductId
	local P = Config.Products
	if id == P.CashSmall then
		giveCashPack(p, Config.CASH_SMALL_SECONDS, Config.CASH_SMALL_MIN)
	elseif id == P.CashBig then
		giveCashPack(p, Config.CASH_BIG_SECONDS, Config.CASH_BIG_MIN)
	elseif id == P.Boost then
		s.BoostUntil = math.max(os.time(), s.BoostUntil) + Config.BOOST_SECONDS
		p:SetAttribute("BoostUntil", s.BoostUntil)
		refreshPlot(p)
		notify(p, "2x Boost active!")
	elseif P.DoubleOffline ~= nil and P.DoubleOffline ~= 0 and id == P.DoubleOffline then
		-- PLACEHOLDER: the offline-rewards claim (not built yet) should read and clear this flag
		s.OfflineDoubled = true
		notify(p, "Offline rewards doubled!")
	else
		warn(
			"[Slop] Receipt not processed: ProductId "
				.. tostring(id)
				.. " does not match CashSmall/CashBig/Boost in SlopConfig.Products."
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(s.Receipts, info.PurchaseId)
	saveData(p) -- persist right away; the 60s autosave retries if this fails
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
---------------------------------------------------------------------
-- DevTools (cheat panel for testing, see DevClient)
---------------------------------------------------------------------
-- Allowed in Studio always, and in live servers only for UserIds in Config.DevUserIds.
-- With Config.DEV_BLOCK_SAVE on, the first cheat turns off saving for that player until they rejoin.
local DevRF = Instance.new("RemoteFunction")
DevRF.Name = "SlopDev"
DevRF.Parent = RS

local function isDev(p)
	return RunService:IsStudio() or table.find(Config.DevUserIds, p.UserId) ~= nil
end

local function devAmount(v)
	v = tonumber(v)
	if not v or v ~= v or v <= 0 or v == math.huge then
		return nil
	end
	return math.floor(v)
end

DevRF.OnServerInvoke = function(p, action, a, b)
	if not isDev(p) then
		return false
	end
	if action == "check" then
		return { BlockSave = Config.DEV_BLOCK_SAVE }
	end
	local s = State[p]
	if not s or not s.Plot then
		return false
	end
	if Config.DEV_BLOCK_SAVE then
		s.Cheated = true
	end

	if action == "cash" then
		local v = devAmount(a)
		if v then
			setCash(p, getCash(p) + v)
			notify(p, "[DEV] +$" .. Config.Format(v))
		end
	elseif action == "atm" then
		local v = devAmount(a)
		if v then
			s.AtmCash += v
			updateAtm(p)
			notify(p, "[DEV] +$" .. Config.Format(v) .. " in the ATM")
		end
	elseif action == "tokens" then
		local v = devAmount(a)
		if v then
			s.Tokens += v
			p:SetAttribute("Tokens", s.Tokens)
			notify(p, "[DEV] +" .. Config.Format(v) .. " tokens")
		end
	elseif action == "slop" then
		local idx = tonumber(a)
		if idx and Config.Mons[idx] then
			if #s.Inventory >= Config.INV_MAX then
				notify(p, "[DEV] Inventory full")
			else
				-- b = exact multiplier picked in the panel, or nil for a normal random roll
				local mult = tonumber(b) and math.clamp(tonumber(b), Config.MULT_MIN, Config.MULT_MAX) or nil
				table.insert(s.Inventory, newSlop(idx, mult))
				discover(p, idx)
				notify(p, "[DEV] " .. Config.Mons[idx].Name .. " added to inventory")
			end
		end
	elseif action == "rebirth" then
		s.Rebirths += 1
		p.leaderstats.Rebirths.Value = s.Rebirths
		refreshPlot(p)
		notify(p, "[DEV] Rebirths: " .. s.Rebirths)
	elseif action == "resetRebirths" then
		s.Rebirths = 0
		p.leaderstats.Rebirths.Value = 0
		refreshPlot(p)
		notify(p, "[DEV] Rebirths reset to 0")
	elseif action == "maxSlots" then
		-- every Slop Spot unlocked, so all 16 tanks can be checked; "resetUpgrades" undoes it
		while s.Slots < MAX_SLOTS do
			s.Slots += 1
			table.insert(s.Owned, 0)
		end
		refreshPlot(p)
		notify(p, "[DEV] All " .. MAX_SLOTS .. " Slop Spots unlocked")
	elseif action == "cooldown" then
		s.NextRoll = 0
		notify(p, "[DEV] Roll cooldown cleared")
	elseif action == "resetUpgrades" then
		-- Every purchased upgrade back to its starting value. Rebirths have their own reset button.
		-- ADD NEW UPGRADES HERE (Slop shop, stars, ...) so this keeps resetting everything.
		for k = #s.Owned, START_SLOTS + 1, -1 do
			local sl = table.remove(s.Owned, k)
			if sl ~= 0 then
				table.insert(s.Inventory, sl) -- Slops on removed spots go back to inventory
			end
		end
		s.Slots = START_SLOTS
		s.RollCount = 1
		s.RollCap = Config.Wheel.CapStart
		s.SpeedLevel = 0
		refreshPlot(p)
		notify(p, "[DEV] All upgrades reset")
	elseif action == "event" then
		if table.find(EVENT_KINDS, a) then
			if eventRunning then
				notify(p, "[DEV] An event is already running")
			else
				task.spawn(runEvent, a)
			end
		end
	end

	refreshMachine(p)
	return true
end
