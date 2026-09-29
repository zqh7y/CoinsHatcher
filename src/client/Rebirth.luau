-- The rebirth menu, made to be read at a glance: four big reward cards
-- (coin value x4 / +300%, diamonds, the new egg, pets kept 100%), a coin
-- progress bar with a %, and one clean button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Icons = require(script.Parent.Icons)
local State = require(script.Parent.State)
local Viewport = require(script.Parent.Viewport)
local Fx = require(script.Parent.Fx)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Rebirth = {}

local panel = Ui.panel("Rebirth", nil, UDim2.fromOffset(620, 470), { Ui.COLORS.Accent2 })
local content = panel.Content

-- "Rebirth 2 → 3" chip at the top
local stage = Ui.label(content, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.fromOffset(220, 34),
	TextColor3 = Ui.COLORS.White,
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.new(1, 1, 1),
})
Ui.corner(stage, 0.5)
Ui.gradient(stage, Ui.COLORS.Accent, Ui.COLORS.Accent2, 0)
local stagePad = Instance.new("UIPadding")
stagePad.PaddingTop = UDim.new(0, 7)
stagePad.PaddingBottom = UDim.new(0, 7)
stagePad.Parent = stage

-- the reward cards ---------------------------------------------------------
local cards = Instance.new("Frame")
cards.BackgroundTransparency = 1
cards.Position = UDim2.fromOffset(0, 48)
cards.Size = UDim2.new(1, 0, 0, 196)
cards.Parent = content
local cardLayout = Instance.new("UIListLayout")
cardLayout.FillDirection = Enum.FillDirection.Horizontal
cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
cardLayout.Padding = UDim.new(0, 10)
cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
cardLayout.Parent = cards

-- A card: a colored circle with an icon, a big number, a small % chip and a
-- one-word label. Returns the pieces so render() can fill them in.
local function card(order, color, label)
	local c = Instance.new("Frame")
	c.Size = UDim2.new(0.25, -8, 1, 0)
	c.BackgroundColor3 = Ui.COLORS.Soft
	c.LayoutOrder = order
	c.Parent = cards
	Ui.corner(c, 18)
	Ui.stroke(c, color:Lerp(Ui.COLORS.Line, 0.55), 2)

	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0)
	circle.Position = UDim2.new(0.5, 0, 0, 12)
	circle.Size = UDim2.fromOffset(72, 72)
	circle.BackgroundColor3 = color
	circle.BackgroundTransparency = 0.82
	circle.Parent = c
	Ui.corner(circle, 0.5)
	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.64, 0.64)
	icon.BackgroundTransparency = 1
	icon.Parent = circle

	local big = Ui.label(c, {
		TextColor3 = color,
		Position = UDim2.fromOffset(6, 92),
		Size = UDim2.new(1, -12, 0, 36),
	})
	local chip = Ui.label(c, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(84, 22),
		TextColor3 = Ui.COLORS.White,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
	})
	Ui.corner(chip, 0.5)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingTop = UDim.new(0, 4)
	chipPad.PaddingBottom = UDim.new(0, 4)
	chipPad.Parent = chip
	Ui.label(c, {
		Text = label,
		Font = Ui.FONT_BODY,
		TextColor3 = Ui.COLORS.SubText,
		Position = UDim2.fromOffset(6, 162),
		Size = UDim2.new(1, -12, 0, 18),
	})
	return { Frame = c, Icon = icon, Big = big, Chip = chip, Circle = circle }
end

local coinCard = card(1, Ui.COLORS.Gold, "Coin value")
Icons.coin(coinCard.Icon, Ui.COLORS.Gold)
local gemCard = card(2, Ui.COLORS.Gem, "Diamonds")
Icons.gem(gemCard.Icon, Ui.COLORS.Gem)
local eggCard = card(3, Ui.COLORS.Accent2, "New egg")
local petCard = card(4, Ui.COLORS.Green, "Pets kept")
Icons.paw(petCard.Icon, Ui.COLORS.Green)

-- the new egg spins in its circle (rebuilt when the next egg changes)
eggCard.Icon.Size = UDim2.fromScale(1.15, 1.15)
local shownEgg, stopSpin

-- what resets, as one small grey chip
local resets = Ui.label(content, {
	Text = "Resets: coins and the upgrade board",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 254),
	Size = UDim2.fromOffset(260, 24),
	BackgroundTransparency = 0,
	BackgroundColor3 = Ui.COLORS.Soft,
})
Ui.corner(resets, 0.5)
local resetsPad = Instance.new("UIPadding")
resetsPad.PaddingTop = UDim.new(0, 5)
resetsPad.PaddingBottom = UDim.new(0, 5)
resetsPad.Parent = resets

-- coin progress bar with the % in it ---------------------------------------
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 290)
bar.Size = UDim2.new(1, -40, 0, 30)
bar.BackgroundColor3 = Ui.COLORS.Line
bar.Parent = content
Ui.corner(bar, 0.5)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.Parent = bar
Ui.corner(fill, 0.5)
Ui.gradient(fill, Ui.COLORS.Gold, Ui.COLORS.Accent2, 0)
local barText = Ui.label(bar, {
	Size = UDim2.fromScale(1, 1),
	TextColor3 = Ui.COLORS.Text,
	ZIndex = 2,
})
local barPad = Instance.new("UIPadding")
barPad.PaddingTop = UDim.new(0, 7)
barPad.PaddingBottom = UDim.new(0, 7)
barPad.Parent = barText

local button = Ui.button(content, "Rebirth", Ui.COLORS.Accent2, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -4),
	Size = UDim2.fromOffset(240, 52),
})

local maxText = Ui.label(content, {
	Text = "Max rebirth reached!",
	TextColor3 = Ui.COLORS.Accent2,
	Position = UDim2.fromOffset(0, 150),
	Size = UDim2.new(1, 0, 0, 44),
	Visible = false,
})

local ready = false

local function render()
	local data = State.Data
	if not data then
		return
	end
	local r = data.Rebirths
	local maxed = r >= Config.MAX_REBIRTHS
	for _, obj in ipairs({ stage, cards, resets, bar, button }) do
		obj.Visible = not maxed
	end
	maxText.Visible = maxed
	if maxed then
		return
	end

	stage.Text = ("Rebirth %d  →  %d"):format(r, r + 1)

	coinCard.Big.Text = "x" .. Config.SCALE
	coinCard.Chip.Text = ("+%d%%"):format((Config.SCALE - 1) * 100)

	gemCard.Big.Text = "+" .. Config.formatNumber(Config.DIAMONDS_PER_REBIRTH * (r + 1))
	gemCard.Chip.Text = "FREE"

	local nextEgg = r + 2
	local egg = Config.EGGS[nextEgg]
	eggCard.Big.Text = if egg then (egg.Name:gsub(" Egg", "")) else "?"
	eggCard.Chip.Text = "UNLOCK"
	if shownEgg ~= nextEgg and nextEgg <= Config.REBIRTH_EGGS then
		shownEgg = nextEgg
		if stopSpin then
			stopSpin()
		end
		Ui.clear(eggCard.Icon)
		local _, model = Viewport.egg(eggCard.Icon, nextEgg)
		stopSpin = Viewport.spin(model, 1)
	end

	petCard.Big.Text = "100%"
	petCard.Chip.Text = "SAFE"

	local cost = Config.rebirthCost(r)
	local coins = player:GetAttribute("Coins") or data.Coins or 0
	local progress = math.clamp(coins / cost, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(math.max(progress, 0.04), 1) }):Play()
	barText.Text = ("%s / %s  ·  %d%%"):format(
		Config.formatNumber(coins),
		Config.formatNumber(cost),
		math.floor(progress * 100)
	)

	ready = progress >= 1
	if ready then
		button.Text = "Rebirth"
		Ui.setButtonColor(button, Ui.COLORS.Accent2)
	else
		button.Text = "Need " .. Config.formatNumber(cost - coins) .. " more"
		Ui.setButtonColor(button, Ui.COLORS.Disabled)
	end
end

-- the top chip breathes a little when you can rebirth
local breathe = Instance.new("UIScale")
breathe.Parent = stage
RunService.RenderStepped:Connect(function()
	if panel.isOpen() then
		breathe.Scale = if ready then 1 + math.sin(os.clock() * 5) * 0.04 else 1
	end
end)

local busy = false
button.Activated:Connect(function()
	if busy or not ready then
		return
	end
	busy = true
	local ok, message = remotes.Rebirth:InvokeServer()
	Ui.toast(message, if ok then Ui.COLORS.Accent2 else Ui.COLORS.Red)
	if ok then
		panel.close()
		Fx.celebrate("REBIRTH!", Color3.fromRGB(230, 180, 255))
	end
	busy = false
end)

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if panel.isOpen() then
		render()
	end
end)

Rebirth.toggle = panel.toggle

return Rebirth
