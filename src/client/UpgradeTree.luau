-- The upgrade tree: opened with the big Upgrades button at the bottom middle
-- of the screen. Every coin upgrade is a branch growing out of the middle in
-- its own direction, one bubble per level (Config.UPGRADES). Some branches
-- open only once another branch reaches a level, and then grow out of that
-- bubble.
--   Mouse wheel: zoom in and out (around the mouse)
--   Right mouse button (or a finger) drag: move around the tree
--   Tap a bubble: see what it does and buy it. After buying, the view glides
--   to the next bubble so you can keep upgrading without moving around.
-- Looks: a sunny meadow with clouds, wooden branches that turn the branch's
-- color as you buy them, shiny bubbles, a sparkle on the next one and a star
-- at the end of a finished branch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Icons = require(script.Parent.Icons)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Boosts = require(script.Parent.Boosts)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local UpgradeTree = {}

local SPACING = 112 -- between bubbles along a branch
local NODE = 70 -- bubble size
local ROOT = 120
local PAD = 220 -- empty space around the tree
local GREEN = Color3.fromRGB(60, 200, 110)
local WOOD = Color3.fromRGB(176, 128, 84)
local ZOOM_MIN, ZOOM_MAX, ZOOM_START = 0.35, 1.6, 0.85

-- Where every bubble goes: positions[id][level] (pixels, root at 0,0) ------------

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

local panel = Ui.panel("Upgrades", nil, UDim2.fromOffset(980, 680), { GREEN })

Ui.label(panel.Frame, {
	Text = "Kept forever · scroll to zoom · right-click and drag to move",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(150, 28),
	Size = UDim2.new(1, -230, 0, 18),
})

-- the window you look at the tree through
local view = Instance.new("Frame")
view.Size = UDim2.new(1, 0, 1, -108)
view.BackgroundColor3 = Color3.new(1, 1, 1)
view.ClipsDescendants = true
view.Active = true -- keeps the mouse wheel and right-click for us (not the camera)
view.Parent = panel.Content
Ui.corner(view, 18)
Ui.stroke(view, Color3.fromRGB(200, 230, 200), 2)
local sky = Instance.new("UIGradient")
sky.Rotation = 90
sky.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 238, 255)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(226, 247, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(222, 247, 206)),
})
sky.Parent = view

-- the tree itself: one big canvas that we move and scale
local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
content.Parent = view
local zoomScale = Instance.new("UIScale")
zoomScale.Scale = ZOOM_START
zoomScale.Parent = content

-- fluffy clouds and little flowers on the canvas (same every time)
do
	local rng = Random.new(7)
	for _ = 1, 22 do
		local cloud = Instance.new("Frame")
		local w = rng:NextInteger(120, 220)
		cloud.Size = UDim2.fromOffset(w, w * 0.42)
		cloud.Position = UDim2.fromOffset(rng:NextInteger(0, math.floor(CANVAS.X)), rng:NextInteger(0, math.floor(CANVAS.Y)))
		cloud.BackgroundColor3 = Color3.new(1, 1, 1)
		cloud.BackgroundTransparency = 0.25
		cloud.BorderSizePixel = 0
		cloud.Parent = content
		Ui.corner(cloud, 0.5)
		local puff = Instance.new("Frame")
		puff.AnchorPoint = Vector2.new(0.5, 0.5)
		puff.Position = UDim2.fromScale(0.42, 0.2)
		puff.Size = UDim2.fromScale(0.5, 0.9)
		puff.BackgroundColor3 = Color3.new(1, 1, 1)
		puff.BackgroundTransparency = 0.25
		puff.BorderSizePixel = 0
		puff.Parent = cloud
		Ui.corner(puff, 0.5)
	end
	local flowers = { "🌼", "🌸", "🌷", "🍄", "⭐" }
	for _ = 1, 40 do
		Ui.label(content, {
			Text = flowers[rng:NextInteger(1, #flowers)],
			TextTransparency = 0.35,
			Position = UDim2.fromOffset(rng:NextInteger(0, math.floor(CANVAS.X)), rng:NextInteger(0, math.floor(CANVAS.Y))),
			Size = UDim2.fromOffset(26, 26),
		})
	end
end

local lines = Instance.new("Frame")
lines.Name = "Lines"
lines.BackgroundTransparency = 1
lines.Size = UDim2.fromScale(1, 1)
lines.ZIndex = 2
lines.Parent = content
local nodes = Instance.new("Frame")
nodes.Name = "Nodes"
nodes.BackgroundTransparency = 1
nodes.Size = UDim2.fromScale(1, 1)
nodes.ZIndex = 3
nodes.Parent = content

-- the trunk in the middle: a big round tree badge
local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromOffset(ORIGIN.X, ORIGIN.Y)
root.Size = UDim2.fromOffset(ROOT, ROOT)
root.BackgroundColor3 = Color3.fromRGB(255, 252, 240)
root.ZIndex = 4
root.Parent = content
Ui.corner(root, 0.5)
Ui.stroke(root, WOOD, 6)
local rootIcon = Instance.new("Frame")
rootIcon.AnchorPoint = Vector2.new(0.5, 0.5)
rootIcon.Position = UDim2.fromScale(0.5, 0.44)
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
local startTag = Ui.label(root, {
	Text = "START",
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	BackgroundColor3 = GREEN,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 1, 0),
	Size = UDim2.fromOffset(78, 26),
	ZIndex = 6,
})
Ui.corner(startTag, 0.5)

-- zoom buttons in the corner (for anyone without a mouse wheel)
local zoomBar = Instance.new("Frame")
zoomBar.BackgroundTransparency = 1
zoomBar.AnchorPoint = Vector2.new(1, 0)
zoomBar.Position = UDim2.new(1, -10, 0, 10)
zoomBar.Size = UDim2.fromOffset(44, 144)
zoomBar.ZIndex = 20
zoomBar.Parent = view
local zoomLayout = Instance.new("UIListLayout")
zoomLayout.Padding = UDim.new(0, 6)
zoomLayout.SortOrder = Enum.SortOrder.LayoutOrder
zoomLayout.Parent = zoomBar
local zoomIn = Ui.button(zoomBar, "+", Ui.COLORS.Panel, { Size = UDim2.fromOffset(44, 44), LayoutOrder = 1, ZIndex = 20 })
local zoomOut = Ui.button(zoomBar, "−", Ui.COLORS.Panel, { Size = UDim2.fromOffset(44, 44), LayoutOrder = 2, ZIndex = 20 })
local homeButton = Ui.button(zoomBar, "⌂", Ui.COLORS.Panel, { Size = UDim2.fromOffset(44, 44), LayoutOrder = 3, ZIndex = 20 })

-- The info card under the tree ------------------------------------------------------

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.fromScale(0, 1)
card.Size = UDim2.new(1, 0, 0, 96)
card.BackgroundColor3 = Ui.COLORS.Soft
card.Parent = panel.Content
Ui.corner(card, 18)
local cardStroke = Ui.stroke(card, Ui.COLORS.Line, 2)

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

-- Moving around: pan (content position) and zoom ----------------------------------

local pan = Vector2.zero -- where the canvas's top-left corner is inside the view
local zoom = ZOOM_START
local panTween

local function clampPan(p, z)
	-- keep at least a bit of the tree in view
	local size = view.AbsoluteSize
	local w, h = CANVAS.X * z, CANVAS.Y * z
	return Vector2.new(math.clamp(p.X, size.X * 0.5 - w, size.X * 0.5), math.clamp(p.Y, size.Y * 0.5 - h, size.Y * 0.5))
end

local function apply()
	content.Position = UDim2.fromOffset(pan.X, pan.Y)
	zoomScale.Scale = zoom
end

local function setPan(p)
	if panTween then
		panTween:Cancel()
		panTween = nil
	end
	pan = clampPan(p, zoom)
	apply()
end

-- Zooms by `factor`, keeping the point under `screenPoint` in place.
local function zoomAt(factor, screenPoint)
	local newZoom = math.clamp(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if newZoom == zoom then
		return
	end
	local local_ = screenPoint - view.AbsolutePosition
	local canvasPoint = (local_ - pan) / zoom
	zoom = newZoom
	setPan(local_ - canvasPoint * zoom)
end

-- Glides the view so `canvasPoint` (canvas pixels) is in the middle.
local function focus(canvasPoint, instant)
	local target = clampPan(view.AbsoluteSize / 2 - canvasPoint * zoom, zoom)
	if panTween then
		panTween:Cancel()
	end
	if instant then
		pan = target
		apply()
		return
	end
	local from = pan
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(t)
		pan = from:Lerp(target, t)
		apply()
	end)
	panTween = TweenService:Create(value, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = 1 })
	panTween:Play()
end

local function viewCenter()
	return view.AbsolutePosition + view.AbsoluteSize / 2
end
zoomIn.Activated:Connect(function()
	zoomAt(1.25, viewCenter())
end)
zoomOut.Activated:Connect(function()
	zoomAt(0.8, viewCenter())
end)
homeButton.Activated:Connect(function()
	focus(ORIGIN)
end)

local function mouseOverView(position)
	local p, s = view.AbsolutePosition, view.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

-- mouse wheel zooms around the mouse
view.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and panel.isOpen() then
		zoomAt(if input.Position.Z > 0 then 1.12 else 1 / 1.12, Vector2.new(input.Position.X, input.Position.Y))
	end
end)

-- right-click drag (or a finger drag) moves the tree
local dragging = nil -- { Start = screen pos, Pan = pan at start, Input = touch or nil }
UserInputService.InputBegan:Connect(function(input)
	if not panel.isOpen() then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and mouseOverView(pos) then
		dragging = { Start = pos, Pan = pan }
	elseif input.UserInputType == Enum.UserInputType.Touch and mouseOverView(pos) then
		dragging = { Start = pos, Pan = pan, Input = input }
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end
	local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement and not dragging.Input
	local isTouch = dragging.Input ~= nil and input == dragging.Input
	if isMouse or isTouch then
		setPan(dragging.Pan + (Vector2.new(input.Position.X, input.Position.Y) - dragging.Start))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton2 or input == dragging.Input) then
		dragging = nil
	end
end)
-- pinch to zoom on phones and tablets
UserInputService.TouchPinch:Connect(function(touches, scale, _, state)
	if not panel.isOpen() or #touches < 2 then
		return
	end
	if state == Enum.UserInputState.Change then
		local mid = (Vector2.new(touches[1].X, touches[1].Y) + Vector2.new(touches[2].X, touches[2].Y)) / 2
		zoomAt(math.clamp(scale, 0.9, 1.1), mid)
	end
end)

-- Drawing ----------------------------------------------------------------------------

local selected = nil -- upgrade id shown in the card
local pulsing = {} -- UIScales of the next bubbles, to pulse them
local sparkles = {} -- sparkle labels next to the next bubbles, to spin them
local render

local function levelOf(id)
	local data = State.Data
	return data and data.Upgrades[id] or 0
end

-- A wooden branch between two points; bought parts get the branch color.
local function branch(from, to, owned, color)
	local a, b = ORIGIN + from, ORIGIN + to
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	local angle = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
	local function bar(thickness, barColor, z)
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromOffset(mid.X, mid.Y)
		l.Size = UDim2.fromOffset(length, thickness)
		l.Rotation = angle
		l.BackgroundColor3 = barColor
		l.BorderSizePixel = 0
		l.ZIndex = z
		l.Parent = lines
		Ui.corner(l, 0.5)
	end
	if owned then
		bar(18, color:Lerp(Color3.new(0, 0, 0), 0.2), 2)
		bar(10, color, 3)
		bar(3, color:Lerp(Color3.new(1, 1, 1), 0.55), 3)
	else
		bar(16, WOOD:Lerp(Color3.new(0, 0, 0), 0.15), 2)
		bar(9, WOOD:Lerp(Color3.new(1, 1, 1), 0.25), 3)
	end
end

local function showCard()
	local data = State.Data
	local upgrade = selected and Config.UPGRADES_BY_ID[selected]
	if not data or not upgrade then
		cardIcon.Text = "🌳"
		cardTitle.Text = "Upgrade Tree"
		cardEffect.Text = "Tap a sparkly bubble to see what it does"
		cardInfo.Text = "New branches grow as you upgrade!"
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
		cardEffect.Text = (now or "") .. "  MAX ⭐"
	elseif now then
		cardEffect.Text = now .. "  ➜  " .. Boosts.upgradeText(upgrade.Id, level + 1)
	else
		cardEffect.Text = ""
	end
	cardInfo.Text = if open
		then upgrade.Info
		else ("🔒 Get %s to level %d to grow this branch"):format(Config.UPGRADES_BY_ID[upgrade.Requires[1]].Name, upgrade.Requires[2])

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
	table.clear(sparkles)
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
			branch(if l == 1 then start else points[l - 1], points[l], owned, upgrade.Color)

			local p = ORIGIN + points[l]
			local node = Instance.new("TextButton")
			node.Name = upgrade.Id .. l
			node.Text = ""
			node.AutoButtonColor = false
			node.AnchorPoint = Vector2.new(0.5, 0.5)
			node.Position = UDim2.fromOffset(p.X, p.Y)
			node.Size = UDim2.fromOffset(NODE, NODE)
			node.BackgroundColor3 = if owned then upgrade.Color elseif isNext then Color3.new(1, 1, 1) else Color3.fromRGB(238, 240, 244)
			node.ZIndex = 4
			node.Parent = nodes
			Ui.corner(node, 0.5)
			Ui.stroke(
				node,
				if owned then upgrade.Color:Lerp(Color3.new(0, 0, 0), 0.25) elseif isNext then upgrade.Color else Color3.fromRGB(205, 210, 220),
				if isNext then 6 else 3
			)
			-- a shiny bubble highlight
			local gloss = Instance.new("Frame")
			gloss.AnchorPoint = Vector2.new(0.5, 0.5)
			gloss.Position = UDim2.fromScale(0.34, 0.26)
			gloss.Size = UDim2.fromScale(0.3, 0.16)
			gloss.Rotation = -30
			gloss.BackgroundColor3 = Color3.new(1, 1, 1)
			gloss.BackgroundTransparency = if owned then 0.35 else 0.1
			gloss.BorderSizePixel = 0
			gloss.ZIndex = 5
			gloss.Parent = node
			Ui.corner(gloss, 0.5)

			Ui.label(node, {
				Text = if not open and l == 1 then "🔒" else upgrade.Icon,
				TextTransparency = if owned or isNext or (not open and l == 1) then 0 else 0.55,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.54, 0.54),
				ZIndex = 5,
			})
			-- level number, or a check once bought
			local chip = Ui.label(node, {
				Text = if owned then "✓" else tostring(l),
				TextColor3 = if owned then Color3.new(1, 1, 1) else Ui.COLORS.SubText,
				BackgroundTransparency = 0,
				BackgroundColor3 = if owned then Ui.COLORS.Green else Ui.COLORS.Panel,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(24, 24),
				ZIndex = 6,
			})
			Ui.corner(chip, 0.5)
			local chipPad = Instance.new("UIPadding")
			chipPad.PaddingTop = UDim.new(0, 4)
			chipPad.PaddingBottom = UDim.new(0, 4)
			chipPad.Parent = chip

			if isNext then
				local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
				local price = Ui.label(nodes, {
					Text = "💰 " .. Config.formatNumber(cost),
					TextColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BackgroundColor3 = if coins >= cost then Ui.COLORS.Green else Color3.fromRGB(160, 165, 180),
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(p.X, p.Y + NODE / 2 + 8),
					Size = UDim2.fromOffset(96, 26),
					ZIndex = 6,
				})
				Ui.corner(price, 0.5)
				local pricePad = Instance.new("UIPadding")
				pricePad.PaddingTop = UDim.new(0, 4)
				pricePad.PaddingBottom = UDim.new(0, 4)
				pricePad.Parent = price
				local scale = Instance.new("UIScale")
				scale.Parent = node
				table.insert(pulsing, scale)
				table.insert(
					sparkles,
					Ui.label(nodes, {
						Text = "✨",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(p.X - NODE / 2, p.Y - NODE / 2),
						Size = UDim2.fromOffset(30, 30),
						ZIndex = 7,
					})
				)
			end

			node.Activated:Connect(function()
				selected = upgrade.Id
				showCard()
			end)
		end

		-- a star at the end of a finished branch
		if level >= upgrade.Max then
			local last = ORIGIN + points[upgrade.Max]
			local dir = (points[upgrade.Max] - (if upgrade.Max > 1 then points[upgrade.Max - 1] else start)).Unit
			local starPos = last + dir * (NODE * 0.85)
			Ui.label(nodes, {
				Text = "⭐",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(starPos.X, starPos.Y),
				Size = UDim2.fromOffset(40, 40),
				ZIndex = 6,
			})
		end

		-- the branch's name on a little sign next to its first bubble
		local first = ORIGIN + points[1]
		local sign = Ui.label(nodes, {
			Text = upgrade.Name,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			BackgroundColor3 = if open then upgrade.Color else Color3.fromRGB(170, 175, 190),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromOffset(first.X, first.Y - NODE / 2 - 8),
			Size = UDim2.fromOffset(130, 26),
			ZIndex = 6,
		})
		Ui.corner(sign, 0.5)
		local signPad = Instance.new("UIPadding")
		signPad.PaddingTop = UDim.new(0, 4)
		signPad.PaddingBottom = UDim.new(0, 4)
		signPad.Parent = sign
	end
	showCard()
end

-- Buying -------------------------------------------------------------------------------

-- After buying, glide to the branch's next bubble (or its last one when done).
local function focusNext(upgrade)
	local level = math.min(levelOf(upgrade.Id) + 1, upgrade.Max)
	focus(ORIGIN + positions[upgrade.Id][level])
end

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
		-- wait for the new level to arrive, then glide to the next bubble
		task.delay(0.15, focusNext, upgrade)
	end
	busy = false
end
buyButton.Activated:Connect(function()
	buy(false)
end)
maxButton.Activated:Connect(function()
	buy(true)
end)

-- the next bubbles pulse, their sparkles twinkle
RunService.RenderStepped:Connect(function()
	if panel.isOpen() then
		local t = os.clock()
		local s = 1 + (math.sin(t * 4) + 1) * 0.05
		for _, scale in ipairs(pulsing) do
			scale.Scale = s
		end
		for i, sparkle in ipairs(sparkles) do
			sparkle.Rotation = math.sin(t * 3 + i) * 20
			sparkle.TextTransparency = 0.2 + math.abs(math.sin(t * 2 + i)) * 0.5
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

local firstOpen = true
panel.OnOpen.Event:Connect(function()
	render()
	-- the first time, start with the middle of the tree in view
	if firstOpen then
		firstOpen = false
		task.defer(function()
			focus(ORIGIN, true)
		end)
	end
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

return UpgradeTree
