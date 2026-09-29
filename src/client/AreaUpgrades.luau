-- The upgrade board in the main area: incremental upgrades for the coin zone,
-- drawn right on the board with a SurfaceGui. A clean white board with tall
-- upgrade cards in two rows that scroll to the right (arrows or drag).
-- Click Buy for one level or Max for as many as you can afford. Reset on
-- rebirth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local AreaUpgrades = {}

local function percent(value)
	return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

-- "now → next" text for each upgrade at a level
local EFFECT = {
	CoinValue = function(l)
		return ("+%d%%"):format(l * 10)
	end,
	ChestValue = function(l)
		return ("+%d%%"):format(l * 15)
	end,
	MoreBreakables = function(l)
		return tostring(Config.COINS_PER_PLAYER + l)
	end,
	ChestLuck = function(l)
		return ("+%d%%"):format(l * 10)
	end,
	Respawn = function(l)
		return ("-%d%%"):format(l * 5)
	end,
	DiamondFinder = function(l)
		return percent(Config.diamondChance({ Upgrades = { DiamondFinder = l } }, 2))
	end,
	CritChance = function(l)
		return percent(Config.critChance({ Upgrades = { CritChance = l } }))
	end,
	CritDamage = function(l)
		return ("x%.1f"):format(Config.critMult({ Upgrades = { CritDamage = l } }))
	end,
	HitSpeed = function(l)
		return ("-%d%%"):format(l * 3)
	end,
	BigChestLuck = function(l)
		return ("+%d%%"):format(l * 15)
	end,
	OrbLuck = function(l)
		return ("+%d%%"):format(l * 10)
	end,
	OrbTime = function(l)
		return ("%ds"):format(Config.orbSeconds({ Upgrades = { OrbTime = l } }))
	end,
	ComboTime = function(l)
		return ("%ds"):format(Config.comboSeconds({ Upgrades = { ComboTime = l } }))
	end,
	EggDiscount = function(l)
		return ("-%d%%"):format(l * 2)
	end,
	StackGems = function(l)
		return ("%d%%"):format(l)
	end,
}

-- a soft color for each card's icon circle
local TINTS = {
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(255, 140, 80),
	Color3.fromRGB(90, 200, 130),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(150, 120, 255),
	Color3.fromRGB(60, 190, 255),
	Color3.fromRGB(255, 95, 120),
}

-- The SurfaceGui lives in PlayerGui (so its buttons can be clicked) and is
-- drawn on the board part the server built (880 x 560 pixels).
local board = Instance.new("SurfaceGui")
board.Name = "UpgradeBoard"
board.Face = Enum.NormalId.Front
board.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
board.PixelsPerStud = 40
board.LightInfluence = 0
board.ResetOnSpawn = false
board.Parent = player:WaitForChild("PlayerGui")

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Ui.COLORS.Panel
background.Parent = board

local accent = Instance.new("Frame")
accent.Position = UDim2.fromOffset(32, 30)
accent.Size = UDim2.fromOffset(6, 34)
accent.BackgroundColor3 = Ui.COLORS.Accent
accent.Parent = background
Ui.corner(accent, 0.5)
Ui.label(background, {
	Text = "Upgrades",
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(50, 26),
	Size = UDim2.fromOffset(300, 40),
})
Ui.label(background, {
	Text = "Make the coin zone pay more and more · resets on rebirth",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(50, 66),
	Size = UDim2.fromOffset(560, 20),
})

-- two rows of cards that scroll sideways
local strip = Instance.new("ScrollingFrame")
strip.Position = UDim2.fromOffset(60, 100)
strip.Size = UDim2.new(1, -120, 1, -112)
strip.BackgroundTransparency = 1
strip.BorderSizePixel = 0
strip.ScrollingDirection = Enum.ScrollingDirection.X
strip.ScrollBarThickness = 6
strip.ScrollBarImageColor3 = Ui.COLORS.Disabled
strip.AutomaticCanvasSize = Enum.AutomaticSize.X
strip.CanvasSize = UDim2.new()
strip.Parent = background
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(140, 210) -- tall 4 x 6 cards
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.FillDirection = Enum.FillDirection.Vertical
grid.FillDirectionMaxCells = 2
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = strip

-- arrows to scroll left/right
local function arrow(text, xScale, anchorX, direction)
	local b = Ui.button(background, text, Ui.COLORS.Soft, {
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Position = UDim2.new(xScale, if anchorX == 0 then 10 else -10, 0.6, 0),
		Size = UDim2.fromOffset(42, 64),
	})
	b.Activated:Connect(function()
		local maxX = math.max(0, strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X)
		local target = math.clamp(strip.CanvasPosition.X + direction * 152 * 3, 0, maxX)
		TweenService:Create(strip, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(target, 0) }):Play()
	end)
end
arrow("‹", 0, 0, -1)
arrow("›", 1, 1, 1)

local busy = false
local cards = {} -- [id] = card, to bounce after buying

local function buy(upgrade, max)
	if busy then
		return
	end
	busy = true
	local ok, message = remotes.BuyUpgrade:InvokeServer(upgrade.Id, max)
	if ok then
		Fx.confetti(if max then 35 else 15)
		Ui.toast(message, Ui.COLORS.Green)
		local card = cards[upgrade.Id]
		if card then
			local scale = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = card
			scale.Scale = 1.06
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	elseif message then
		Ui.toast(message, Ui.COLORS.Red)
	end
	busy = false
end

local function render()
	Ui.clear(strip)
	cards = {}
	local data = State.Data
	if not data then
		return
	end
	local coins = player:GetAttribute("Coins") or 0

	for order, upgrade in ipairs(Config.AREA_UPGRADES) do
		local level = data.Upgrades[upgrade.Id] or 0
		local maxed = level >= upgrade.Max
		local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
		local canAfford = coins >= cost and not maxed
		local tint = TINTS[(order - 1) % #TINTS + 1]

		local card = Instance.new("Frame")
		card.BackgroundColor3 = Ui.COLORS.Soft
		card.LayoutOrder = order
		card.Parent = strip
		Ui.corner(card, 16)
		Ui.stroke(card, if canAfford then Ui.COLORS.Green else Ui.COLORS.Line, if canAfford then 2.5 else 1.5)
		cards[upgrade.Id] = card

		local circle = Instance.new("Frame")
		circle.AnchorPoint = Vector2.new(0.5, 0)
		circle.Position = UDim2.new(0.5, 0, 0, 10)
		circle.Size = UDim2.fromOffset(56, 56)
		circle.BackgroundColor3 = tint
		circle.BackgroundTransparency = 0.75
		circle.Parent = card
		Ui.corner(circle, 0.5)
		Ui.label(circle, { Text = upgrade.Icon, Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19) })

		Ui.label(card, { Text = upgrade.Name, Position = UDim2.fromOffset(6, 72), Size = UDim2.new(1, -12, 0, 18) })
		Ui.label(card, {
			Text = ("Lv %d/%d"):format(level, upgrade.Max),
			Font = Ui.FONT_BODY,
			TextColor3 = Ui.COLORS.SubText,
			Position = UDim2.fromOffset(6, 92),
			Size = UDim2.new(1, -12, 0, 14),
		})
		local effect = EFFECT[upgrade.Id]
		Ui.label(card, {
			Text = if maxed then effect(level) else ("%s → %s"):format(effect(level), effect(level + 1)),
			TextColor3 = Ui.COLORS.Accent,
			Position = UDim2.fromOffset(6, 110),
			Size = UDim2.new(1, -12, 0, 16),
		})

		-- level progress
		local bar = Instance.new("Frame")
		bar.Position = UDim2.fromOffset(12, 134)
		bar.Size = UDim2.new(1, -24, 0, 5)
		bar.BackgroundColor3 = Ui.COLORS.Line
		bar.BorderSizePixel = 0
		bar.Parent = card
		Ui.corner(bar, 0.5)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(level / upgrade.Max, 1)
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		Ui.corner(fill, 0.5)
		Ui.gradient(fill, Ui.COLORS.Accent, Ui.COLORS.Accent2, 0)

		local one = Ui.button(card, if maxed then "MAX" else "💰 " .. Config.formatNumber(cost), if maxed
			then Ui.COLORS.Disabled
			elseif canAfford then Ui.COLORS.Green
			else Ui.COLORS.Disabled, {
			Position = UDim2.fromOffset(10, 146),
			Size = UDim2.new(1, -20, 0, 30),
		})
		local max = Ui.button(card, "Max", if canAfford then Ui.COLORS.Gold else Ui.COLORS.Soft, {
			Position = UDim2.fromOffset(10, 180),
			Size = UDim2.new(1, -20, 0, 22),
			Visible = not maxed,
		})
		one.Activated:Connect(function()
			if not maxed then
				buy(upgrade, false)
			end
		end)
		max.Activated:Connect(function()
			buy(upgrade, true)
		end)
	end
end

task.spawn(function()
	board.Adornee = workspace:WaitForChild("MainArea"):WaitForChild("UpgradeBoard")
	render()
end)

State.Changed.Event:Connect(render)
local pending = false
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if not pending then
		pending = true
		task.delay(0.4, function()
			pending = false
			render()
		end)
	end
end)

return AreaUpgrades
