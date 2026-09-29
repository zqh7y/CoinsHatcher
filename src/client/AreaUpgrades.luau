-- The upgrade board in the main area: incremental upgrades for the coin zone
-- (coin value, chest value, more stuff, ...) drawn right on the board with
-- a SurfaceGui. Click to buy one level or Max. Reset on rebirth.
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

-- "now → next" text for each upgrade at a level
local EFFECT = {
	CoinValue = function(l)
		return ("+%d%%"):format(l * 10)
	end,
	ChestValue = function(l)
		return ("+%d%%"):format(l * 15)
	end,
	MoreBreakables = function(l)
		return ("%d things"):format(Config.COINS_PER_PLAYER + l)
	end,
	ChestLuck = function(l)
		return ("+%d%%"):format(l * 10)
	end,
	Respawn = function(l)
		return ("-%d%%"):format(l * 5)
	end,
	DiamondFinder = function(l)
		return ("%d%%"):format(math.floor(Config.diamondChance({ Upgrades = { DiamondFinder = l } }, 2) * 100 + 0.5))
	end,
	CritChance = function(l)
		return ("%d%%"):format(math.floor(Config.critChance({ Upgrades = { CritChance = l } }) * 100 + 0.5))
	end,
}

-- The SurfaceGui lives in PlayerGui (so its buttons can be clicked) and is
-- drawn on the board part the server built.
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
background.BackgroundColor3 = Color3.new(1, 1, 1)
background.Parent = board
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(60, 170, 150), Color3.fromRGB(30, 80, 110))
gradient.Rotation = 90
gradient.Parent = background

Ui.label(background, {
	Text = "📈 UPGRADES",
	Size = UDim2.new(1, 0, 0, 56),
	Position = UDim2.fromOffset(0, 6),
	TextColor3 = Color3.fromRGB(255, 240, 150),
})
Ui.label(background, {
	Text = "Make the coin zone pay more and more! (resets on rebirth)",
	Size = UDim2.new(1, 0, 0, 24),
	Position = UDim2.fromOffset(0, 60),
	TextColor3 = Color3.fromRGB(220, 255, 235),
})

local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(16, 92)
list.Size = UDim2.new(1, -32, 1, -100)
list.Parent = background
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local busy = false
local rows = {} -- [id] = row frame, to bounce after buying

local function buy(upgrade, max)
	if busy then
		return
	end
	busy = true
	local ok, message = remotes.BuyUpgrade:InvokeServer(upgrade.Id, max)
	if ok then
		Fx.confetti(if max then 35 else 15)
		Ui.toast(message, Ui.COLORS.Gold)
		local row = rows[upgrade.Id]
		if row then
			local scale = row:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = row
			scale.Scale = 1.04
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	elseif message then
		Ui.toast(message, Ui.COLORS.Red)
	end
	busy = false
end

local function render()
	Ui.clear(list)
	rows = {}
	local data = State.Data
	if not data then
		return
	end
	local coins = player:GetAttribute("Coins") or 0

	for order, upgrade in ipairs(Config.AREA_UPGRADES) do
		local level = data.Upgrades[upgrade.Id] or 0
		local maxed = level >= upgrade.Max
		local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
		local canAfford = coins >= cost

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 58) -- 7 rows fit the 560px-tall board
		row.BackgroundColor3 = if canAfford and not maxed then Color3.fromRGB(70, 175, 120) else Color3.fromRGB(45, 110, 120)
		row.LayoutOrder = order
		row.Parent = list
		Ui.corner(row, 12)
		Ui.stroke(row, Color3.new(1, 1, 1), 2)
		rows[upgrade.Id] = row

		Ui.label(row, { Text = upgrade.Icon, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(8, 5) })
		Ui.label(row, {
			Text = ("%s  Lv %d/%d"):format(upgrade.Name, level, upgrade.Max),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -330, 0, 26),
			Position = UDim2.fromOffset(64, 3),
		})
		local effect = EFFECT[upgrade.Id]
		Ui.label(row, {
			Text = if maxed then effect(level) .. "  (max!)" else ("%s  →  %s"):format(effect(level), effect(level + 1)),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 240, 150),
			Size = UDim2.new(1, -330, 0, 22),
			Position = UDim2.fromOffset(64, 30),
		})

		-- level progress bar along the bottom
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 10, 1, -3)
		bar.Size = UDim2.new(1, -20, 0, 4)
		bar.BackgroundColor3 = Color3.fromRGB(20, 60, 70)
		bar.BorderSizePixel = 0
		bar.Parent = row
		Ui.corner(bar, 0.5)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(level / upgrade.Max, 1)
		fill.BackgroundColor3 = Ui.COLORS.Gold
		fill.BorderSizePixel = 0
		fill.Parent = bar
		Ui.corner(fill, 0.5)

		local one = Ui.button(row, if maxed then "MAX" else "💰 " .. Config.formatNumber(cost), if maxed
			then Ui.COLORS.PanelDark
			elseif canAfford then Ui.COLORS.Green
			else Color3.fromRGB(120, 140, 150), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -96, 0.5, -2),
			Size = UDim2.fromOffset(170, 44),
		})
		local max = Ui.button(row, "Max", if canAfford and not maxed then Ui.COLORS.Gold else Color3.fromRGB(120, 140, 150), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -2),
			Size = UDim2.fromOffset(78, 44),
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
