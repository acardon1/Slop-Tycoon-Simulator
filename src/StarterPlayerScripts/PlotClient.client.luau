-- LocalScript named "PlotClient"
-- Put it in: StarterPlayer > StarterPlayerScripts
-- 1. Animates the countdown bar on every Slop tank's screen. The server builds the tanks
--    (tag "SlopTank", attribute DropTime) and stamps the server time of each income tick
--    on SlopOverWorld ("IncomeTick"), so every player sees the same countdown.
-- 2. Draws the "[SLOP]" drop boxes riding each factory conveyor to the ATM. They are only
--    visuals (this player's copy); the server credits the ATM on its own timer.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("SlopConfig"))
local Remote = RS:WaitForChild("SlopEvent")
local world = workspace:WaitForChild("SlopOverWorld")
local tanks = {}   -- [tank model] = { Fill = frame, Timer = label }

local function track(tank)
	if not tank:GetAttribute("DropTime") then return end   -- empty spot: nothing to count down
	local screen = tank:WaitForChild("Screen", 5)
	local sg = screen and screen:WaitForChild("Gui", 5)
	local bar = sg and sg:WaitForChild("Bar", 5)
	if not bar or not tank.Parent then return end
	tanks[tank] = { Fill = bar:WaitForChild("Fill"), Timer = bar:WaitForChild("Timer") }
end

CollectionService:GetInstanceAddedSignal("SlopTank"):Connect(function(tank)
	task.spawn(track, tank)
end)
CollectionService:GetInstanceRemovedSignal("SlopTank"):Connect(function(tank)
	tanks[tank] = nil
end)
for _, tank in ipairs(CollectionService:GetTagged("SlopTank")) do
	task.spawn(track, tank)
end

RunService.RenderStepped:Connect(function()
	local lastTick = world:GetAttribute("IncomeTick")
	if not lastTick then return end
	local since = workspace:GetServerTimeNow() - lastTick
	for tank, ui in pairs(tanks) do
		if tank.Parent then
			local dropTime = tank:GetAttribute("DropTime") or 1
			local left = dropTime - since % dropTime
			ui.Fill.Size = UDim2.fromScale(1 - left / dropTime, 1)
			ui.Timer.Text = string.format("Next drop %.1fs", left)
		else
			tanks[tank] = nil
		end
	end
end)

---------------------------------------------------------------------
-- Drop boxes
---------------------------------------------------------------------
local MAX_PER_TICK = 4     -- boxes per plot per drop; with more Slops their cash is merged
local MAX_PER_PLOT = 30    -- caps on boxes shown at once (the cash is credited either way)
local MAX_BOXES = 120
local DRAW_RANGE = 300     -- plots farther than this from the camera draw no boxes
local BOX_SIZE = 2         -- matches DROP_BOX in SlopServer

local dropFolder = Instance.new("Folder")
dropFolder.Name = "SlopDrops"
dropFolder.Parent = workspace

local boxes = {}           -- { Part, Path, Born, Plot }
local perPlot = {}         -- [plot index] = boxes showing

-- conveyor waypoints, from the plot folder's Path1..PathN attributes
local function getPath(plotIndex)
	local pf = world:FindFirstChild("Plot" .. plotIndex)
	local n = pf and pf:GetAttribute("PathN")
	if not n then return nil end
	local pts = {}
	for i = 1, n do
		pts[i] = pf:GetAttribute("Path" .. i)
		if not pts[i] then return nil end
	end
	return pts
end

-- point at distance d along the path, or nil once past the end
local function along(path, d)
	for i = 1, #path - 1 do
		local seg = (path[i + 1] - path[i]).Magnitude
		if d <= seg then
			return path[i]:Lerp(path[i + 1], d / seg)
		end
		d -= seg
	end
	return nil
end

-- art is placeholder: brown box, red "[SLOP]" on the top and sides, green value above
local function makeBox(value)
	local part = Instance.new("Part")
	part.Name = "SlopBox"
	part.Size = Vector3.new(BOX_SIZE, BOX_SIZE, BOX_SIZE)
	part.Color = Color3.fromRGB(196, 154, 108)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.MaxDistance = 100
		sg.Parent = part
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "[SLOP]"
		t.Font = Enum.Font.Bangers
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(210, 30, 30)
		t.Parent = sg
	end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 26)
	bb.StudsOffset = Vector3.new(0, BOX_SIZE / 2 + 1, 0)
	bb.MaxDistance = 80
	bb.Parent = part
	local v = Instance.new("TextLabel")
	v.BackgroundTransparency = 1
	v.Size = UDim2.fromScale(1, 1)
	v.Text = "$" .. Config.Format(value)
	v.Font = Enum.Font.FredokaOne
	v.TextScaled = true
	v.TextColor3 = Color3.fromRGB(110, 255, 150)
	v.TextStrokeTransparency = 0
	v.Parent = bb
	return part
end

local function spawnBox(plotIndex, path, value)
	if #boxes >= MAX_BOXES or (perPlot[plotIndex] or 0) >= MAX_PER_PLOT then return end
	local part = makeBox(value)
	part.Position = path[1]
	part.Parent = dropFolder
	perPlot[plotIndex] = (perPlot[plotIndex] or 0) + 1
	table.insert(boxes, { Part = part, Path = path, Born = os.clock(), Plot = plotIndex })
end

-- each drop: one value per Slop; merged into at most MAX_PER_TICK boxes spread over the second
Remote.OnClientEvent:Connect(function(kind, drops)
	if kind ~= "drops" then return end
	local cam = workspace.CurrentCamera
	for _, d in ipairs(drops) do
		local path = getPath(d.P)
		if path and cam and (cam.CFrame.Position - path[#path]).Magnitude <= DRAW_RANGE then
			local n = #d.V
			local groups = math.min(n, MAX_PER_TICK)
			local sums = table.create(groups, 0)
			for i, v in ipairs(d.V) do
				local g = (i - 1) % groups + 1
				sums[g] += v
			end
			for g = 1, groups do
				task.delay((g - 1) / groups, spawnBox, d.P, path, sums[g])
			end
		end
	end
end)

RunService.RenderStepped:Connect(function()
	local speed = world:GetAttribute("DropSpeed") or 6
	local now = os.clock()
	for i = #boxes, 1, -1 do
		local b = boxes[i]
		local pos = along(b.Path, (now - b.Born) * speed)
		if pos then
			b.Part.Position = pos
		else
			b.Part:Destroy()
			perPlot[b.Plot] -= 1
			table.remove(boxes, i)
		end
	end
end)
