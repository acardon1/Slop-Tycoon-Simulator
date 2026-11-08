local UI = {}

UI.COL = {
	Panel = Color3.fromRGB(236, 236, 238),
	Tile = Color3.fromRGB(214, 214, 219),
	Outline = Color3.fromRGB(40, 42, 48),
	Green = Color3.fromRGB(86, 176, 96),
	Tab = Color3.fromRGB(190, 190, 196),
	Text = Color3.fromRGB(70, 70, 76),
	Red = Color3.fromRGB(232, 72, 63),
	Gray = Color3.fromRGB(150, 150, 158),
}
local COL = UI.COL

function UI.corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 8)
	c.Parent = obj
end

function UI.stroke(obj, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or COL.Outline
	s.Parent = obj
	return s
end

function UI.label(parent, text, size, pos, color, outlined)
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

function UI.button(parent, text, size, pos, color)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or COL.Green
	b.Text = text
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	UI.corner(b, UDim.new(0, 12))
	UI.stroke(b, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = b
	return b
end

-- Window with overlapping title, red X and a green-active icon tab row.
-- tabs = { { Name = "Inventory", Icon = "🎒" }, ... }; returns win, pages[name], selectTab(name)
function UI.makeWindow(gui, title, tabs, width, height, extra)
	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.fromOffset(width, height)
	win.BackgroundColor3 = COL.Panel
	win.Visible = false
	win.Parent = gui
	UI.corner(win, UDim.new(0, 24))
	UI.stroke(win, 5)

	local scale = Instance.new("UIScale")
	scale.Parent = win
	local function fit()
		local view = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min(view.X / (width + (extra or 0) + 60), view.Y / (height + 60)), 0.4, 1)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	local titleLabel =
		UI.label(win, title, UDim2.fromOffset(340, 60), UDim2.fromOffset(-14, -36), Color3.new(1, 1, 1), true)
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
	UI.corner(close, UDim.new(1, 0))
	UI.stroke(close, 4)
	close.Activated:Connect(function()
		win.Visible = false
	end)

	local tabRow = Instance.new("Frame")
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromOffset(18, 28)
	tabRow.Size = UDim2.new(1, -90, 0, 56)
	tabRow.Parent = win
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.Parent = tabRow

	local pages, buttons = {}, {}
	local function selectTab(name)
		for n, page in pairs(pages) do
			page.Visible = (n == name)
			buttons[n].BackgroundColor3 = (n == name) and COL.Green or COL.Tab
		end
	end
	for _, tab in ipairs(tabs) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(170, 52)
		b.BackgroundColor3 = COL.Tab
		b.Text = tab.Icon .. " " .. tab.Name
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = tabRow
		UI.corner(b, UDim.new(0, 12))
		UI.stroke(b, 3)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = b
		buttons[tab.Name] = b
		b.Activated:Connect(function()
			selectTab(tab.Name)
		end)

		local page = Instance.new("Frame")
		page.BackgroundTransparency = 1
		page.Position = UDim2.fromOffset(0, 96)
		page.Size = UDim2.new(1, 0, 1, -104)
		page.Visible = false
		page.Parent = win
		pages[tab.Name] = page
	end
	selectTab(tabs[1].Name)
	return win, pages, selectTab
end

return UI
