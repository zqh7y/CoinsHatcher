-- The Robux shop (the Shop button on the left):
--   🥚 Exclusive Egg - pets that grow with you (Robux, 1 / 3 / 10 eggs)
--   👑 All Gamepasses + the 4 gamepasses (yours forever)
--   🎟️ Promo codes at the bottom
-- Prices and ids are in Config.ROBUX; the server does the buying.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Viewport = require(script.Parent.Viewport)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local RobuxShop = {}

local PINK = Color3.fromRGB(255, 80, 170)
local PURPLE = Color3.fromRGB(150, 80, 255)
local BLUE = Color3.fromRGB(60, 170, 255)
local GOLD = Color3.fromRGB(255, 190, 40)
local WHITE = Color3.new(1, 1, 1)
local NEON = Config.EXCLUSIVE_COLOR
local TIER_COLORS = {
	Color3.fromRGB(150, 160, 185),
	Color3.fromRGB(70, 200, 110),
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(255, 180, 40),
	Color3.fromRGB(255, 70, 170),
}

local panel = Ui.panel("Shop", nil, UDim2.fromOffset(780, 620), { PINK })
panel.Title.Text = "🛒 Pet Park Shop"

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromScale(1, 1)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel.Content

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 14)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = list

local listPad = Instance.new("UIPadding")
listPad.PaddingRight = UDim.new(0, 12)
listPad.PaddingBottom = UDim.new(0, 12)
listPad.PaddingTop = UDim.new(0, 2)
listPad.Parent = list

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function gradient(parent, colors, rotation)
	local keypoints = {}
	for i, color in ipairs(colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(keypoints)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

-- little white sparkles sprinkled over a banner
local function sparkles(parent, count, seed)
	local rng = Random.new(seed)
	for _ = 1, count do
		local s = rng:NextInteger(5, 11)
		local star = frame(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.03, 0.97), rng:NextNumber(0.1, 0.9)),
			Size = UDim2.fromOffset(s, s),
			Rotation = 45,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = rng:NextNumber(0.35, 0.7),
		})
		Ui.corner(star, 0.2)
	end
end

-- A big glossy Robux price button ("R$ 39"). `tag` is a small ribbon on top.
local function priceButton(parent, top, price, color, tag)
	local b = Ui.button(parent, "", color, { Size = UDim2.fromScale(1, 1) })
	b.Text = ""
	Ui.stroke(b, color:Lerp(Color3.new(0, 0, 0), 0.25), 2)
	local topLabel = Ui.label(b, {
		Name = "Top",
		Text = top,
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 0.42),
	})
	local bottom = Ui.label(b, {
		Name = "Bottom",
		Text = "R$ " .. price,
		TextColor3 = WHITE,
		Position = UDim2.fromScale(0, 0.44),
		Size = UDim2.fromScale(1, 0.56),
	})
	for _, l in ipairs({ topLabel, bottom }) do
		l.TextStrokeTransparency = 0.7
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
	end
	if tag then
		local ribbon = Ui.label(b, {
			Text = tag,
			TextColor3 = WHITE,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, -8),
			Size = UDim2.new(0.8, 0, 0, 20),
			BackgroundTransparency = 0,
			BackgroundColor3 = Ui.COLORS.Red,
			ZIndex = 3,
		})
		Ui.corner(ribbon, 0.5)
		Ui.stroke(ribbon, WHITE, 2)
	end
	return b
end

-- 1) the welcome banner -------------------------------------------------------
local hero = frame(list, { Size = UDim2.new(1, 0, 0, 74), LayoutOrder = 1, BackgroundColor3 = WHITE })
Ui.corner(hero, 18)
gradient(hero, { PINK, PURPLE, BLUE }, 0)
sparkles(hero, 14, 7)
Ui.label(hero, {
	Text = "✨ Welcome to the Shop! ✨",
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.6,
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 34),
})
Ui.label(hero, {
	Text = "Every purchase helps Pet Park grow 💜",
	Font = Ui.FONT_BODY,
	TextColor3 = WHITE,
	Position = UDim2.fromOffset(16, 44),
	Size = UDim2.new(1, -32, 0, 20),
})

-- 2) the Exclusive Egg --------------------------------------------------------
local eggCard = frame(list, { Size = UDim2.new(1, 0, 0, 300), LayoutOrder = 2, BackgroundColor3 = WHITE })
Ui.corner(eggCard, 18)
gradient(eggCard, { Color3.fromRGB(45, 20, 95), Color3.fromRGB(95, 40, 170), Color3.fromRGB(40, 70, 170) }, 25)
Ui.stroke(eggCard, NEON, 3)
sparkles(eggCard, 22, 11)

-- the egg on the left, with slowly turning light rays behind it
local eggSide = frame(eggCard, { Size = UDim2.new(0.3, 0, 1, 0), BackgroundTransparency = 1 })
local rays = {}
for i = 1, 3 do
	local ray = frame(eggSide, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(150, 150),
		BackgroundColor3 = if i == 2 then PINK else NEON,
		BackgroundTransparency = 0.8,
		Rotation = i * 30,
	})
	Ui.corner(ray, 0.18)
	rays[i] = ray
end
local eggGlow = frame(eggSide, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromOffset(120, 120),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.82,
})
Ui.corner(eggGlow, 0.5)
local eggView = frame(eggSide, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromOffset(190, 190),
	BackgroundTransparency = 1,
	ZIndex = 2,
})
local _, eggModel = Viewport.egg(eggView, "Exclusive")
Viewport.spin(eggModel, 0.8)
local limitedTag = Ui.label(eggSide, {
	Text = "🔥 ROBUX ONLY",
	TextColor3 = WHITE,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.new(0.8, 0, 0, 24),
	BackgroundTransparency = 0,
	BackgroundColor3 = PINK,
	ZIndex = 3,
})
Ui.corner(limitedTag, 0.5)
Ui.stroke(limitedTag, WHITE, 2)

local eggRight = frame(eggCard, {
	Position = UDim2.fromScale(0.3, 0),
	Size = UDim2.new(0.7, -14, 1, 0),
	BackgroundTransparency = 1,
})
Ui.label(eggRight, {
	Text = "EXCLUSIVE EGG",
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 32),
})
local bestLabel = Ui.label(eggRight, {
	Text = "",
	Font = Ui.FONT_BODY,
	TextColor3 = Color3.fromRGB(215, 225, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.new(1, 0, 0, 18),
})

-- the 5 pets you can get: chance, pet and how strong it is for you
local chipsRow = frame(eggRight, {
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.new(1, 0, 0, 124),
	BackgroundTransparency = 1,
})
local chipsLayout = Instance.new("UIListLayout")
chipsLayout.FillDirection = Enum.FillDirection.Horizontal
chipsLayout.Padding = UDim.new(0, 6)
chipsLayout.Parent = chipsRow

local chips = {}
for tier, design in ipairs(Config.EXCLUSIVE_PETS) do
	local color = TIER_COLORS[tier]
	local chip = frame(chipsRow, {
		Size = UDim2.new(0.2, -5, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.08,
		LayoutOrder = tier,
	})
	Ui.corner(chip, 14)
	Ui.stroke(chip, color, 2.5)
	local top = Ui.label(chip, {
		Text = design.Chance .. "%",
		TextColor3 = WHITE,
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
	})
	Ui.corner(top, 12)
	local view = frame(chip, {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
	})
	local power = Ui.label(chip, {
		Text = "",
		TextColor3 = Ui.COLORS.Text,
		Position = UDim2.new(0, 4, 0, 86),
		Size = UDim2.new(1, -8, 0, 18),
	})
	Ui.label(chip, {
		Text = ("%d%% of your best"):format(design.Strength * 100),
		Font = Ui.FONT_BODY,
		TextColor3 = Ui.COLORS.SubText,
		Position = UDim2.new(0, 4, 0, 104),
		Size = UDim2.new(1, -8, 0, 14),
	})
	chips[tier] = { View = view, Power = power, Pet = nil }
end

local buyRow = frame(eggRight, {
	Position = UDim2.fromOffset(0, 212),
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundTransparency = 1,
})
local buyLayout = Instance.new("UIListLayout")
buyLayout.FillDirection = Enum.FillDirection.Horizontal
buyLayout.Padding = UDim.new(0, 10)
buyLayout.Parent = buyRow

local singlePrice = Config.ROBUX.Products[1].Price
for order, product in ipairs(Config.ROBUX.Products) do
	local cell = frame(buyRow, {
		Size = UDim2.new(1 / 3, -7, 1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	})
	local full = singlePrice * product.Eggs
	local save = math.floor((1 - product.Price / full) * 100 + 0.5)
	local b = priceButton(
		cell,
		if product.Eggs == 1 then "1 EGG" else product.Eggs .. " EGGS",
		product.Price,
		if order == 3 then PINK elseif order == 2 then PURPLE else Color3.fromRGB(35, 190, 120),
		if save > 0 then "SAVE " .. save .. "%" else nil
	)
	b.Activated:Connect(function()
		remotes.BuyRobux:FireServer("Product", product.Key)
	end)
end

-- 3) gamepasses ----------------------------------------------------------------
Ui.label(list, {
	Text = "⭐ GAMEPASSES  ·  yours forever!",
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, 0, 0, 26),
	LayoutOrder = 3,
})

-- the big gold "ALL GAMEPASSES" deal
local all = Config.ROBUX.All
local allFull = 0
for _, pass in ipairs(Config.ROBUX.Passes) do
	allFull += pass.Price
end
local allCard = frame(list, { Size = UDim2.new(1, 0, 0, 112), LayoutOrder = 4, BackgroundColor3 = WHITE })
Ui.corner(allCard, 18)
gradient(allCard, { Color3.fromRGB(255, 215, 80), Color3.fromRGB(255, 165, 40), Color3.fromRGB(255, 120, 90) }, 0)
Ui.stroke(allCard, Color3.fromRGB(230, 140, 20), 3)
sparkles(allCard, 16, 23)
local crown = Ui.label(allCard, {
	Text = all.Icon,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(78, 78),
	BackgroundTransparency = 0,
	BackgroundColor3 = WHITE,
})
Ui.corner(crown, 0.5)
Ui.stroke(crown, Color3.fromRGB(230, 140, 20), 3)
local crownPad = Instance.new("UIPadding")
crownPad.PaddingTop = UDim.new(0, 12)
crownPad.PaddingBottom = UDim.new(0, 12)
crownPad.Parent = crown
Ui.label(allCard, {
	Text = all.Name,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.4,
	TextStrokeColor3 = Color3.fromRGB(150, 70, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(106, 14),
	Size = UDim2.new(0.62, -106, 0, 34),
})
local icons = {}
for _, pass in ipairs(Config.ROBUX.Passes) do
	table.insert(icons, pass.Icon .. " " .. pass.Name)
end
Ui.label(allCard, {
	Text = table.concat(icons, "   "),
	Font = Ui.FONT_BODY,
	TextColor3 = Color3.fromRGB(110, 55, 0),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	Position = UDim2.fromOffset(106, 52),
	Size = UDim2.new(0.62, -106, 0, 40),
})
local allRight = frame(allCard, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.new(0.34, 0, 0, 80),
	BackgroundTransparency = 1,
})
local allWas = Ui.label(allRight, {
	Text = ("was R$ %d  ·  SAVE R$ %d"):format(allFull, allFull - all.Price),
	TextColor3 = Color3.fromRGB(120, 50, 0),
	Size = UDim2.new(1, 0, 0, 18),
})
local allButtonHolder = frame(allRight, {
	Position = UDim2.fromOffset(0, 22),
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundTransparency = 1,
})
local allButton = priceButton(allButtonHolder, "GET ALL 4", all.Price, PINK)
allButton.Activated:Connect(function()
	remotes.BuyRobux:FireServer("Pass", all.Key)
end)
local allOwned = Ui.label(allButtonHolder, {
	Text = "OWNED ✓",
	TextColor3 = WHITE,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 0,
	BackgroundColor3 = Ui.COLORS.Green,
	Visible = false,
})
Ui.corner(allOwned, 12)

-- the 4 single passes
local passGrid = frame(list, { Size = UDim2.new(1, 0, 0, 214), LayoutOrder = 5, BackgroundTransparency = 1 })
local passLayout = Instance.new("UIGridLayout")
passLayout.CellSize = UDim2.new(0.25, -9, 1, 0)
passLayout.CellPadding = UDim2.fromOffset(12, 0)
passLayout.SortOrder = Enum.SortOrder.LayoutOrder
passLayout.Parent = passGrid

local passCards = {}
for order, pass in ipairs(Config.ROBUX.Passes) do
	local card = frame(passGrid, { LayoutOrder = order, BackgroundColor3 = WHITE })
	Ui.corner(card, 18)
	Ui.stroke(card, pass.Color, 2.5)
	local band = frame(card, { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = WHITE })
	Ui.corner(band, 18)
	gradient(band, { pass.Color:Lerp(WHITE, 0.35), pass.Color }, 90)
	sparkles(band, 6, order * 5)
	local icon = Ui.label(band, {
		Text = pass.Icon,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(62, 62),
		BackgroundTransparency = 0,
		BackgroundColor3 = WHITE,
	})
	Ui.corner(icon, 0.5)
	local iconPad = Instance.new("UIPadding")
	iconPad.PaddingTop = UDim.new(0, 10)
	iconPad.PaddingBottom = UDim.new(0, 10)
	iconPad.Parent = icon
	Ui.label(card, {
		Text = pass.Name,
		Position = UDim2.fromOffset(8, 90),
		Size = UDim2.new(1, -16, 0, 24),
	})
	Ui.label(card, {
		Text = pass.Info,
		Font = Ui.FONT_BODY,
		TextColor3 = Ui.COLORS.SubText,
		TextWrapped = true,
		Position = UDim2.fromOffset(8, 116),
		Size = UDim2.new(1, -16, 0, 32),
	})
	local holder = frame(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 48),
		BackgroundTransparency = 1,
	})
	local b = priceButton(holder, "BUY", pass.Price, Color3.fromRGB(35, 190, 120))
	b.Activated:Connect(function()
		remotes.BuyRobux:FireServer("Pass", pass.Key)
	end)
	local owned = Ui.label(holder, {
		Text = "OWNED ✓",
		TextColor3 = WHITE,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		BackgroundColor3 = Ui.COLORS.Green,
		Visible = false,
	})
	Ui.corner(owned, 12)
	passCards[pass.Key] = { Button = b, Owned = owned }
end

-- 4) promo codes -----------------------------------------------------------------
local codeCard = frame(list, { Size = UDim2.new(1, 0, 0, 118), LayoutOrder = 6, BackgroundColor3 = Ui.COLORS.Soft })
Ui.corner(codeCard, 18)
Ui.stroke(codeCard, Ui.COLORS.Line, 1.5)
Ui.label(codeCard, {
	Text = "🎟️ Got a code? Type it here!",
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -32, 0, 24),
})
local box = Instance.new("TextBox")
box.Position = UDim2.fromOffset(16, 44)
box.Size = UDim2.new(0.7, -24, 0, 44)
box.BackgroundColor3 = WHITE
box.PlaceholderText = "Enter code..."
box.PlaceholderColor3 = Ui.COLORS.SubText
box.Text = ""
box.ClearTextOnFocus = false
box.Font = Ui.FONT
box.TextSize = 20
box.TextColor3 = Ui.COLORS.Text
box.Parent = codeCard
Ui.corner(box, 12)
local boxStroke = Ui.stroke(box, Ui.COLORS.Line, 2)
local boxPad = Instance.new("UIPadding")
boxPad.PaddingLeft = UDim.new(0, 12)
boxPad.Parent = box
box.Focused:Connect(function()
	boxStroke.Color = PINK
end)
box.FocusLost:Connect(function()
	boxStroke.Color = Ui.COLORS.Line
end)

local redeem = Ui.button(codeCard, "REDEEM", PINK, {
	Position = UDim2.new(0.7, 0, 0, 44),
	Size = UDim2.new(0.3, -16, 0, 44),
})
local codeMessage = Ui.label(codeCard, {
	Text = "",
	Font = Ui.FONT_BODY,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(16, 92),
	Size = UDim2.new(1, -32, 0, 18),
})

local redeeming = false
local function tryCode()
	if redeeming or box.Text:gsub("%s", "") == "" then
		return
	end
	redeeming = true
	local ok, message = remotes.RedeemCode:InvokeServer(box.Text)
	codeMessage.Text = message or ""
	codeMessage.TextColor3 = if ok then Ui.COLORS.Green else Ui.COLORS.Red
	if ok then
		box.Text = ""
		Fx.confetti(60)
	end
	redeeming = false
end
redeem.Activated:Connect(tryCode)
box.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		tryCode()
	end
end)

-- Updates what depends on your data: your pets' strength and owned passes.
local shownBest = nil
local function refresh()
	local data = State.Data
	if not data then
		return
	end
	local best = Config.bestPetPower(data)
	bestLabel.Text = "Pets grow with you!  Your best pet: ⚔️ " .. Config.formatNumber(best)
	if best ~= shownBest then
		shownBest = best
		for tier, chip in ipairs(chips) do
			local petName = Config.exclusivePet(tier, best)
			if petName ~= chip.Pet then
				chip.Pet = petName
				Ui.clear(chip.View)
				Viewport.pet(chip.View, petName)
			end
			chip.Power.Text = "⚔️ " .. Config.formatNumber(Config.PETS[petName].Power)
		end
	end

	local hasAll = Config.hasPass(data, all.Key)
	allButton.Visible = not hasAll
	allOwned.Visible = hasAll
	allWas.Visible = not hasAll
	for key, card in pairs(passCards) do
		local owned = Config.hasPass(data, key)
		card.Button.Visible = not owned
		card.Owned.Visible = owned
	end
end

State.Changed.Event:Connect(function()
	if panel.isOpen() then
		refresh()
	end
end)
panel.OnOpen.Event:Connect(function()
	codeMessage.Text = ""
	refresh()
end)

-- the light rays behind the egg turn slowly while the shop is open
RunService.RenderStepped:Connect(function(dt)
	if not panel.isOpen() then
		return
	end
	for i, ray in ipairs(rays) do
		ray.Rotation += dt * (if i % 2 == 0 then -12 else 18)
	end
end)

RobuxShop.toggle = panel.toggle
RobuxShop.open = panel.open

return RobuxShop
