-- The upgrade tree: opened with the big Upgrades button at the bottom middle
-- of the screen. Every coin upgrade is a branch growing out of the middle in
-- its own direction, one circle per level (Config.UPGRADES). Some branches
-- open only once another branch reaches a level, and then grow out of that
-- circle. Drag to look around; tap a glowing circle to see it and buy it.
--   bought circles are filled in the branch color
--   the next circle glows and pulses, with its price under it
--   later circles are grey, and closed branches show a lock
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Icons = require(script.Parent.Icons)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Boosts = require(script.Parent.Boosts)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local UpgradeTree = {}

local SPACING = 112 -- between circles along a branch
local NODE = 66 -- circle size
local ROOT = 100
local PAD = 140 -- empty space around the tree
local GREEN = Color3.fromRGB(60, 200, 110)

-- Where every circle goes: positions[id][level] (pixels, root at 0,0) ------------

local positions = {}
local minX, minY, maxX, maxY = -ROOT, -ROOT, ROOT, ROOT
for _, upgrade in ipairs(Config.UPGRADES) do
	local start = Vector2.zero
	if upgrade.Requires then
		start = positions[upgrade.Requires[1]][upgrade.Requires[2]]
	end
	local a = math.rad(upgrade.Angle or 0)
	local dir = Vector2.new(math.cos(a), math.sin(a))
	positions[upgrade.Id] = {}
	for level = 1, upgrade.Max do
		local p = start + dir * SPACING * level
		positions[upgrade.Id][level] = p
		minX, minY = math.min(minX, p.X), math.min(minY, p.Y)
		maxX, maxY = math.max(maxX, p.X), math.max(maxY, p.Y)
	end
end
local ORIGIN = Vector2.new(-minX + PAD, -minY + PAD) -- canvas position of the root
local CANVAS = Vector2.new(maxX - minX + PAD * 2, maxY - minY + PAD * 2)

-- The panel ------------------------------------------------------------------------

local panel = Ui.panel("Upgrades", nil, UDim2.fromOffset(960, 660), { GREEN })

Ui.label(panel.Frame, {
	Text = "Kept forever · tap a glowing circle to upgrade · drag to look around",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(150, 28),
	Size = UDim2.new(1, -230, 0, 18),
})

local view = Instance.new("ScrollingFrame")
view.Size = UDim2.new(1, 0, 1, -108)
view.BackgroundColor3 = Color3.fromRGB(246, 249, 244)
view.BorderSizePixel = 0
view.ScrollingDirection = Enum.ScrollingDirection.XY
view.ScrollBarThickness = 6
view.ScrollBarImageColor3 = Ui.COLORS.Disabled
view.CanvasSize = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
view.ElasticBehavior = Enum.ElasticBehavior.Never
view.Parent = panel.Content
Ui.corner(view, 16)
Ui.stroke(view, Ui.COLORS.Line, 1.5)

-- soft dotted background so the canvas feels like a board
for x = 0, CANVAS.X, 120 do
	for y = 0, CANVAS.Y, 120 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromOffset(x, y)
		dot.Size = UDim2.fromOffset(4, 4)
		dot.BackgroundColor3 = Color3.fromRGB(215, 225, 212)
		dot.BorderSizePixel = 0
		dot.Parent = view
		Ui.corner(dot, 0.5)
	end
end

local lines = Instance.new("Frame")
lines.Name = "Lines"
lines.BackgroundTransparency = 1
lines.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
lines.ZIndex = 2
lines.Parent = view
local nodes = Instance.new("Frame")
nodes.Name = "Nodes"
nodes.BackgroundTransparency = 1
nodes.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
nodes.ZIndex = 3
nodes.Parent = view

-- the root in the middle
local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromOffset(ORIGIN.X, ORIGIN.Y)
root.Size = UDim2.fromOffset(ROOT, ROOT)
root.BackgroundColor3 = Ui.COLORS.Panel
root.ZIndex = 4
root.Parent = view
Ui.corner(root, 0.5)
Ui.stroke(root, GREEN, 5)
local rootIcon = Instance.new("Frame")
rootIcon.AnchorPoint = Vector2.new(0.5, 0.5)
rootIcon.Position = UDim2.fromScale(0.5, 0.45)
rootIcon.Size = UDim2.fromScale(0.62, 0.62)
rootIcon.BackgroundTransparency = 1
rootIcon.ZIndex = 5
rootIcon.Parent = root
Icons.tree(rootIcon, GREEN)
for _, obj in ipairs(rootIcon:GetDescendants()) do
	if obj:IsA("GuiObject") then
		obj.ZIndex = 5
	end
end
Ui.label(root, {
	Text = "START",
	TextColor3 = GREEN,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(60, 16),
	ZIndex = 5,
})

-- The info card under the tree ------------------------------------------------------

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.fromScale(0, 1)
card.Size = UDim2.new(1, 0, 0, 96)
card.BackgroundColor3 = Ui.COLORS.Soft
card.Parent = panel.Content
Ui.corner(card, 16)
local cardStroke = Ui.stroke(card, Ui.COLORS.Line, 1.5)

local cardIcon = Ui.label(card, {
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.fromOffset(68, 68),
	BackgroundTransparency = 0,
	BackgroundColor3 = Ui.COLORS.Panel,
})
Ui.corner(cardIcon, 0.5)
local cardIconPad = Instance.new("UIPadding")
cardIconPad.PaddingTop = UDim.new(0, 12)
cardIconPad.PaddingBottom = UDim.new(0, 12)
cardIconPad.Parent = cardIcon
local cardTitle = Ui.label(card, {
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(96, 12),
	Size = UDim2.new(1, -360, 0, 28),
})
local cardEffect = Ui.label(card, {
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Ui.COLORS.Green,
	Position = UDim2.fromOffset(96, 42),
	Size = UDim2.new(1, -360, 0, 22),
})
local cardInfo = Ui.label(card, {
	Font = Ui.FONT_BODY,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Ui.COLORS.SubText,
	Position = UDim2.fromOffset(96, 68),
	Size = UDim2.new(1, -360, 0, 16),
})
local buyButton = Ui.button(card, "", Ui.COLORS.Green, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -110, 0.5, 0),
	Size = UDim2.fromOffset(150, 60),
})
local maxButton = Ui.button(card, "Max", Ui.COLORS.Gold, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(84, 60),
})

-- Drawing ----------------------------------------------------------------------------

local selected = nil -- upgrade id shown in the card
local pulsing = {} -- UIScales of the next circles, to pulse them
local render

local function levelOf(id)
	local data = State.Data
	return data and data.Upgrades[id] or 0
end

local function line(from, to, color, thickness)
	local a, b = ORIGIN + from, ORIGIN + to
	local mid = (a + b) / 2
	local l = Instance.new("Frame")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromOffset(mid.X, mid.Y)
	l.Size = UDim2.fromOffset((b - a).Magnitude, thickness)
	l.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
	l.BackgroundColor3 = color
	l.BorderSizePixel = 0
	l.ZIndex = 2
	l.Parent = lines
	Ui.corner(l, 0.5)
end

local function showCard()
	local data = State.Data
	local upgrade = selected and Config.UPGRADES_BY_ID[selected]
	if not data or not upgrade then
		cardIcon.Text = "🌳"
		cardTitle.Text = "Upgrade Tree"
		cardEffect.Text = "Tap a glowing circle to see what it does"
		cardInfo.Text = "New branches open as you upgrade"
		cardStroke.Color = Ui.COLORS.Line
		buyButton.Visible = false
		maxButton.Visible = false
		return
	end
	local level = levelOf(upgrade.Id)
	local maxed = level >= upgrade.Max
	local open = Config.upgradeUnlocked(data.Upgrades, upgrade)
	local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
	local canAfford = (player:GetAttribute("Coins") or 0) >= cost

	cardIcon.Text = upgrade.Icon
	cardStroke.Color = upgrade.Color
	cardTitle.Text = ("%s  ·  Lv %d/%d"):format(upgrade.Name, level, upgrade.Max)
	local now = Boosts.upgradeText(upgrade.Id, level)
	if maxed then
		cardEffect.Text = (now or "") .. "  MAX"
	elseif now then
		cardEffect.Text = now .. "  ➜  " .. Boosts.upgradeText(upgrade.Id, level + 1)
	else
		cardEffect.Text = ""
	end
	cardInfo.Text = if open
		then upgrade.Info
		else ("🔒 Get %s to level %d to open this branch"):format(Config.UPGRADES_BY_ID[upgrade.Requires[1]].Name, upgrade.Requires[2])

	buyButton.Visible = open
	maxButton.Visible = open and not maxed
	buyButton.Text = if maxed then "MAX" else "💰 " .. Config.formatNumber(cost)
	Ui.setButtonColor(buyButton, if maxed then Ui.COLORS.Disabled elseif canAfford then Ui.COLORS.Green else Ui.COLORS.Disabled)
	Ui.setButtonColor(maxButton, if canAfford then Ui.COLORS.Gold else Ui.COLORS.Soft)
end

render = function()
	Ui.clear(lines)
	Ui.clear(nodes)
	table.clear(pulsing)
	local data = State.Data
	if not data then
		return
	end
	local coins = player:GetAttribute("Coins") or 0

	for _, upgrade in ipairs(Config.UPGRADES) do
		local level = levelOf(upgrade.Id)
		local open = Config.upgradeUnlocked(data.Upgrades, upgrade)
		local points = positions[upgrade.Id]
		local start = if upgrade.Requires then positions[upgrade.Requires[1]][upgrade.Requires[2]] else Vector2.zero

		for l = 1, upgrade.Max do
			local owned = l <= level
			local isNext = open and l == level + 1
			local from = if l == 1 then start else points[l - 1]
			line(from, points[l], if owned then upgrade.Color else Color3.fromRGB(215, 220, 228), if owned then 9 else 6)

			local p = ORIGIN + points[l]
			local node = Instance.new("TextButton")
			node.Name = upgrade.Id .. l
			node.Text = ""
			node.AutoButtonColor = false
			node.AnchorPoint = Vector2.new(0.5, 0.5)
			node.Position = UDim2.fromOffset(p.X, p.Y)
			node.Size = UDim2.fromOffset(NODE, NODE)
			node.BackgroundColor3 = if owned then upgrade.Color elseif isNext then Ui.COLORS.Panel else Color3.fromRGB(232, 235, 240)
			node.ZIndex = 3
			node.Parent = nodes
			Ui.corner(node, 0.5)
			Ui.stroke(
				node,
				if owned then upgrade.Color:Lerp(Color3.new(0, 0, 0), 0.15) elseif isNext then upgrade.Color else Color3.fromRGB(210, 214, 222),
				if isNext then 5 else 2.5
			)
			Ui.label(node, {
				Text = if not open and l == 1 then "🔒" else upgrade.Icon,
				TextTransparency = if owned or isNext or (not open and l == 1) then 0 else 0.55,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromScale(0.52, 0.52),
				ZIndex = 4,
			})
			-- level number in a little chip
			local chip = Ui.label(node, {
				Text = tostring(l),
				TextColor3 = if owned then upgrade.Color else Ui.COLORS.SubText,
				BackgroundTransparency = 0,
				BackgroundColor3 = Ui.COLORS.Panel,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.fromOffset(22, 16),
				ZIndex = 5,
			})
			Ui.corner(chip, 0.5)

			if isNext then
				local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
				local price = Ui.label(nodes, {
					Text = "💰 " .. Config.formatNumber(cost),
					TextColor3 = if coins >= cost then Ui.COLORS.Green else Ui.COLORS.SubText,
					BackgroundTransparency = 0,
					BackgroundColor3 = Ui.COLORS.Panel,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(p.X, p.Y + NODE / 2 + 6),
					Size = UDim2.fromOffset(90, 22),
					ZIndex = 5,
				})
				Ui.corner(price, 0.5)
				local pricePad = Instance.new("UIPadding")
				pricePad.PaddingTop = UDim.new(0, 3)
				pricePad.PaddingBottom = UDim.new(0, 3)
				pricePad.Parent = price
				local scale = Instance.new("UIScale")
				scale.Parent = node
				table.insert(pulsing, scale)
			end

			node.Activated:Connect(function()
				selected = upgrade.Id
				showCard()
			end)
		end

		-- the branch's name next to its first circle
		local first = ORIGIN + points[1]
		Ui.label(nodes, {
			Text = upgrade.Name,
			TextColor3 = upgrade.Color:Lerp(Color3.new(0, 0, 0), 0.2),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(first.X, first.Y - NODE / 2 - 4),
			Size = UDim2.fromOffset(120, 18),
			ZIndex = 5,
		})
	end
	showCard()
end

-- Buying -------------------------------------------------------------------------------

local busy = false
local function buy(max)
	local upgrade = selected and Config.UPGRADES_BY_ID[selected]
	if busy or not upgrade then
		return
	end
	busy = true
	local ok, message = remotes.BuyUpgrade:InvokeServer(upgrade.Id, max)
	if message then
		Ui.toast(message, if ok then GREEN else Ui.COLORS.Red)
	end
	if ok then
		Fx.confetti(if max then 35 else 18)
	end
	busy = false
end
buyButton.Activated:Connect(function()
	buy(false)
end)
maxButton.Activated:Connect(function()
	buy(true)
end)

-- the next circles pulse gently
RunService.RenderStepped:Connect(function()
	if panel.isOpen() then
		local s = 1 + (math.sin(os.clock() * 4) + 1) * 0.05
		for _, scale in ipairs(pulsing) do
			scale.Scale = s
		end
	end
end)

-- The button at the bottom middle of the screen -------------------------------------------

local openButton = Instance.new("TextButton")
openButton.Name = "UpgradesButton"
openButton.AnchorPoint = Vector2.new(0.5, 1)
openButton.Position = UDim2.new(0.5, 0, 1, -14)
openButton.Size = UDim2.fromOffset(190, 62)
openButton.BackgroundColor3 = Ui.COLORS.Panel
openButton.Text = ""
openButton.Parent = Ui.gui
Ui.corner(openButton, 0.5)
Ui.stroke(openButton, GREEN, 3)
Ui.bounce(openButton)
local buttonIcon = Instance.new("Frame")
buttonIcon.AnchorPoint = Vector2.new(0, 0.5)
buttonIcon.Position = UDim2.new(0, 14, 0.5, 0)
buttonIcon.Size = UDim2.fromOffset(40, 40)
buttonIcon.BackgroundTransparency = 1
buttonIcon.Parent = openButton
Icons.tree(buttonIcon, GREEN)
Ui.label(openButton, {
	Text = "Upgrades",
	TextColor3 = Ui.COLORS.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 62, 0.5, 0),
	Size = UDim2.new(1, -76, 0, 26),
})
-- a red badge when something can be bought
local badge = Ui.label(openButton, {
	Text = "!",
	TextColor3 = Ui.COLORS.White,
	BackgroundTransparency = 0,
	BackgroundColor3 = Ui.COLORS.Red,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(24, 24),
	ZIndex = 3,
	Visible = false,
})
Ui.corner(badge, 0.5)

local function refreshBadge()
	local data = State.Data
	local coins = player:GetAttribute("Coins") or 0
	local any = false
	if data then
		for _, upgrade in ipairs(Config.UPGRADES) do
			local level = data.Upgrades[upgrade.Id] or 0
			if level < upgrade.Max and Config.upgradeUnlocked(data.Upgrades, upgrade) and coins >= Config.upgradeCost(upgrade, level, data.Rebirths) then
				any = true
			end
		end
	end
	badge.Visible = any
end

openButton.Activated:Connect(function()
	panel.toggle()
end)

panel.OnOpen.Event:Connect(function()
	render()
	-- start with the middle of the tree in view
	task.defer(function()
		local window = view.AbsoluteWindowSize
		view.CanvasPosition = Vector2.new(ORIGIN.X - window.X / 2, ORIGIN.Y - window.Y / 2)
	end)
end)

-- keep it fresh
local pending = false
local function refreshSoon()
	refreshBadge()
	if panel.isOpen() and not pending then
		pending = true
		task.delay(0.3, function()
			pending = false
			if panel.isOpen() then
				render()
			end
		end)
	end
end
State.Changed.Event:Connect(refreshSoon)
player:GetAttributeChangedSignal("Coins"):Connect(refreshSoon)
refreshBadge()

UpgradeTree.toggle = panel.toggle
UpgradeTree.button = openButton

-- a little bounce when the button first appears
local intro = openButton:FindFirstChildOfClass("UIScale")
if intro then
	intro.Scale = 0
	TweenService:Create(intro, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

return UpgradeTree
