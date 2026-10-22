-- LocalScript named "PlotClient"
-- Put it in: StarterPlayer > StarterPlayerScripts
-- Animates the countdown bar on every Slop tank's screen. The server builds the tanks
-- (tag "SlopTank", attribute DropTime) and stamps the server time of each income tick
-- on SlopOverWorld ("IncomeTick"), so every player sees the same countdown.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

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
