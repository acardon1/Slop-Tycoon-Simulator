-- LocalScript named "SlopClient"
-- Put it in: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(RS:WaitForChild("SlopConfig"))
local Remote = RS:WaitForChild("SlopEvent")

local player = Players.LocalPlayer
local ls = player:WaitForChild("leaderstats")
local cash = ls:WaitForChild("Cash")
local income = ls:WaitForChild("Income")
local rebirths = ls:WaitForChild("Rebirths")

local gui = Instance.new("ScreenGui")
gui.Name = "SlopHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function style(obj, strokeColor)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = obj
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = strokeColor or Color3.fromRGB(27, 29, 34)
	s.Parent = obj
end

local function newLabel(parent, size, pos, textColor)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = textColor or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Parent = parent
	return t
end

-- HUD
local hud = Instance.new("Frame")
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 12)
hud.Size = UDim2.fromOffset(250, 154)
hud.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
hud.BackgroundTransparency = 0.15
hud.Parent = gui
style(hud)

local cashLabel = newLabel(hud, UDim2.new(1, -16, 0, 44), UDim2.new(0, 8, 0, 4), Color3.fromRGB(109, 255, 156))
local incLabel = newLabel(hud, UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 50), Color3.fromRGB(255, 210, 63))
local rebLabel = newLabel(hud, UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 80), Color3.fromRGB(200, 150, 255))
local tokLabel = newLabel(hud, UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 0, 103), Color3.fromRGB(255, 226, 120))
local atmLabel = newLabel(hud, UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 127), Color3.fromRGB(150, 255, 190))

local function refresh()
	atmLabel.Text = "CASH TO COLLECT $" .. Config.Format(player:GetAttribute("AtmCash") or 0)
	cashLabel.Text = "$" .. Config.Format(cash.Value)
	incLabel.Text = "+$" .. Config.Format(income.Value) .. "/s"
	rebLabel.Text = "Rebirths: " .. rebirths.Value .. " (x" .. string.format("%.2f", Config.Mult(rebirths.Value)) .. ")"
	tokLabel.Text = "🪙 " .. Config.Format(player:GetAttribute("Tokens") or 0) .. " tokens"
end
for _, v in ipairs({ cash, income, rebirths }) do
	v.Changed:Connect(refresh)
end
player:GetAttributeChangedSignal("Tokens"):Connect(refresh)
player:GetAttributeChangedSignal("AtmCash"):Connect(refresh)
refresh()

-- Round headshot right of the HUD, centred on its height. Not clickable yet:
-- LATER it opens a profile page or the Stats page (connect head.Activated then).
-- Quick TP: the "BASE" pop-up under the HUD (shows when you are far from your plot)
-- and the BASE button (bottom left) ask the server to move you to your own plot.
local FAR_FROM_BASE = 60   -- studs from the plot centre before the pop-up shows

local head = Instance.new("ImageButton")
head.AnchorPoint = Vector2.new(0, 0.5)
head.Position = UDim2.new(0.5, 133, 0, 89)   -- HUD spans x -125..125 and y 12..166
head.Size = UDim2.fromOffset(72, 72)
head.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
head.BackgroundTransparency = 0.15
head.Parent = gui
style(head)
head:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)

task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok then
		head.Image = img
	end
end)

local tpPopup = Instance.new("TextButton")
tpPopup.AnchorPoint = Vector2.new(0.5, 0)
tpPopup.Position = UDim2.new(0.5, 0, 0, 174)   -- centred under the HUD (its bottom is at y 166)
tpPopup.Size = UDim2.fromOffset(100, 30)
tpPopup.BackgroundColor3 = Color3.fromRGB(56, 193, 114)
tpPopup.Text = "BASE"
tpPopup.Font = Enum.Font.FredokaOne
tpPopup.TextScaled = true
tpPopup.TextColor3 = Color3.new(1, 1, 1)
tpPopup.Visible = false
tpPopup.Parent = gui
style(tpPopup)

local function goHome()
	Remote:FireServer("home")
end
tpPopup.Activated:Connect(goHome)

local homeButton = Instance.new("TextButton")
homeButton.AnchorPoint = Vector2.new(0, 1)
homeButton.Position = UDim2.new(0, 154, 1, -12)   -- right of SHOP
homeButton.Size = UDim2.fromOffset(130, 48)
homeButton.BackgroundColor3 = Color3.fromRGB(59, 143, 224)
homeButton.Text = "🏠 BASE"
homeButton.Font = Enum.Font.FredokaOne
homeButton.TextScaled = true
homeButton.TextColor3 = Color3.new(1, 1, 1)
homeButton.Parent = gui
style(homeButton)
homeButton.Activated:Connect(goHome)

task.spawn(function()
	while true do
		local center = player:GetAttribute("PlotCenter")
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local far = false
		if center and hrp then
			local offset = hrp.Position - center
			far = Vector2.new(offset.X, offset.Z).Magnitude > FAR_FROM_BASE
		end
		tpPopup.Visible = far
		task.wait(0.5)
	end
end)


-- Event banner
local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.new(0.5, 0, 0.2, 0)
banner.Size = UDim2.new(0.55, 0, 0, 54)
banner.BackgroundColor3 = Color3.fromRGB(232, 72, 63)
banner.Font = Enum.Font.FredokaOne
banner.TextScaled = true
banner.TextColor3 = Color3.new(1, 1, 1)
banner.TextStrokeTransparency = 0
banner.Visible = false
banner.Parent = gui
style(banner)

local bannerId = 0
local function showBanner(text, secs)
	bannerId += 1
	local id = bannerId
	banner.Text = text
	banner.Visible = true
	task.delay(secs, function()
		if bannerId == id then
			banner.Visible = false
		end
	end)
end

-- Toast
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -90)
toast.Size = UDim2.new(0.4, 0, 0, 40)
toast.BackgroundColor3 = Color3.fromRGB(27, 29, 34)
toast.Font = Enum.Font.FredokaOne
toast.TextScaled = true
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Visible = false
toast.Parent = gui
style(toast, Color3.fromRGB(255, 210, 63))

local toastId = 0
local function showToast(text)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(2, function()
		if toastId == id then
			toast.Visible = false
		end
	end)
end

-- Floating +$ text when slapping
local function floatSlap(value)
	local pos = UserInputService:GetMouseLocation()
	local t = newLabel(gui, UDim2.fromOffset(120, 30), UDim2.fromOffset(pos.X - 60 + math.random(-20, 20), pos.Y - 30), Color3.fromRGB(109, 255, 156))
	t.Text = "+$" .. Config.Format(value)
	local tween = TweenService:Create(t, TweenInfo.new(0.8), {
		Position = t.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		t:Destroy()
	end)
end

Remote.OnClientEvent:Connect(function(kind, a, b)
	if kind == "banner" then
		showBanner(a, b or 4)
	elseif kind == "toast" then
		showToast(a)
	elseif kind == "slap" then
		floatSlap(a)
	elseif kind == "collect" then
		showToast("Collected $" .. Config.Format(a))
	end
end)

---------------------------------------------------------------------
-- Boost timer + Shop
---------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")

local boostLabel = Instance.new("TextLabel")
boostLabel.Position = UDim2.new(0, 12, 0, 124)
boostLabel.Size = UDim2.fromOffset(250, 32)
boostLabel.BackgroundColor3 = Color3.fromRGB(176, 98, 232)
boostLabel.Font = Enum.Font.FredokaOne
boostLabel.TextScaled = true
boostLabel.TextColor3 = Color3.new(1, 1, 1)
boostLabel.Visible = false
boostLabel.Parent = gui
style(boostLabel)

task.spawn(function()
	while true do
		local t = (player:GetAttribute("BoostUntil") or 0) - os.time()
		if t > 0 then
			boostLabel.Text = string.format("2x BOOST  %d:%02d", t // 60, t % 60)
			boostLabel.Visible = true
		else
			boostLabel.Visible = false
		end
		task.wait(1)
	end
end)

local shopButton = Instance.new("TextButton")
shopButton.AnchorPoint = Vector2.new(0, 1)
shopButton.Position = UDim2.new(0, 12, 1, -12)
shopButton.Size = UDim2.fromOffset(130, 48)
shopButton.BackgroundColor3 = Color3.fromRGB(56, 193, 114)
shopButton.Text = "SHOP"
shopButton.Font = Enum.Font.FredokaOne
shopButton.TextScaled = true
shopButton.TextColor3 = Color3.new(1, 1, 1)
shopButton.Parent = gui
style(shopButton)


local shop = Instance.new("Frame")
shop.AnchorPoint = Vector2.new(0.5, 0.5)
shop.Position = UDim2.fromScale(0.5, 0.5)
shop.Size = UDim2.fromOffset(420, 380)
shop.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
shop.Visible = false
shop.Parent = gui
style(shop)

local shopTitle = newLabel(shop, UDim2.new(1, -60, 0, 40), UDim2.fromOffset(12, 8), Color3.fromRGB(255, 210, 63))
shopTitle.Text = "SHOP"

local closeBtn = Instance.new("TextButton")
closeBtn.Position = UDim2.new(1, -44, 0, 8)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.BackgroundColor3 = Color3.fromRGB(232, 72, 63)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextScaled = true
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = shop
style(closeBtn)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 56)
list.Size = UDim2.new(1, -24, 1, -68)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = shop

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = list

local function idFor(item)
	if item.Kind == "Pass" then
		return Config.Passes[item.Key] or 0
	end
	return Config.Products[item.Key] or 0
end

for _, item in ipairs(Config.ShopItems) do
	local id = idFor(item)
	if id ~= 0 then
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 70)
		row.BackgroundColor3 = Color3.fromRGB(43, 47, 58)
		row.Parent = list
		style(row)

		local title = newLabel(row, UDim2.new(0.6, 0, 0, 26), UDim2.fromOffset(10, 6))
		title.Text = item.Title
		title.TextXAlignment = Enum.TextXAlignment.Left

		local desc = newLabel(row, UDim2.new(0.6, 0, 0, 28), UDim2.fromOffset(10, 34), Color3.fromRGB(200, 205, 215))
		desc.Text = item.Desc
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextWrapped = true
		desc.TextScaled = false
		desc.TextSize = 14
		desc.TextStrokeTransparency = 1

		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -10, 0.5, 0)
		buy.Size = UDim2.fromOffset(110, 44)
		buy.BackgroundColor3 = Color3.fromRGB(56, 193, 114)
		buy.Text = "BUY"
		buy.Font = Enum.Font.FredokaOne
		buy.TextScaled = true
		buy.TextColor3 = Color3.new(1, 1, 1)
		buy.Parent = row
		style(buy)

		-- show the Robux price if it can be looked up
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, item.Kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				buy.Text = "\u{E002} " .. info.PriceInRobux
			end
		end)

		local function updateOwned()
			if item.Kind == "Pass" and player:GetAttribute("Pass_" .. item.Key) then
				buy.Text = "OWNED"
				buy.BackgroundColor3 = Color3.fromRGB(90, 96, 110)
				buy.Active = false
			end
		end
		if item.Kind == "Pass" then
			player:GetAttributeChangedSignal("Pass_" .. item.Key):Connect(updateOwned)
			updateOwned()
		end

		buy.Activated:Connect(function()
			if item.Kind == "Pass" then
				if not player:GetAttribute("Pass_" .. item.Key) then
					MarketplaceService:PromptGamePassPurchase(player, id)
				end
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
	end
end

local emptyNote = newLabel(shop, UDim2.new(1, -24, 0, 40), UDim2.fromOffset(12, 160), Color3.fromRGB(200, 205, 215))
emptyNote.Text = "Shop items are not set up yet."
emptyNote.Visible = #list:GetChildren() <= 1 -- only the UIListLayout

shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
closeBtn.Activated:Connect(function()
	shop.Visible = false
end)