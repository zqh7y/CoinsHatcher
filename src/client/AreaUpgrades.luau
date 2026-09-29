-- The 📈 Upgrades menu: incremental upgrades for the coin zone (coin value,
-- chest value, more stuff, ...). Buy anywhere, one level or Max. Reset on
-- rebirth. The button gets a badge when you can afford something.
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

local panel = Ui.panel("Upgrades", "📈", UDim2.fromOffset(660, 520), {
	Color3.fromRGB(80, 200, 150),
	Color3.fromRGB(40, 110, 140),
})

Ui.label(panel.Content, {
	Text = "Make the coin zone pay more and more! (resets on rebirth)",
	TextColor3 = Color3.fromRGB(220, 255, 235),
	Size = UDim2.new(1, 0, 0, 24),
})

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 32)
list.Size = UDim2.new(1, 0, 1, -32)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel.Content
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

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

local busy = false
local rows = {} -- [id] = row frame, to flash after buying

local function buy(upgrade, max)
	if busy then
		return
	end
	busy = true
	local ok, message = remotes.BuyUpgrade:InvokeServer(upgrade.Id, max)
	if ok then
		Fx.confetti(if max then 35 else 15)
		local row = rows[upgrade.Id]
		if row then
			local scale = row:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			scale.Parent = row
			scale.Scale = 1.05
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

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 84)
		row.BackgroundColor3 = Color3.fromRGB(60, 150, 140)
		row.LayoutOrder = order
		row.Parent = list
		Ui.corner(row, 14)
		Ui.stroke(row, Color3.new(1, 1, 1), 2)
		rows[upgrade.Id] = row

		Ui.label(row, { Text = upgrade.Icon, Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(10, 14) })
		Ui.label(row, {
			Text = ("%s  Lv %d/%d"):format(upgrade.Name, level, upgrade.Max),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -300, 0, 28),
			Position = UDim2.fromOffset(74, 6),
		})
		local effect = EFFECT[upgrade.Id]
		Ui.label(row, {
			Text = if maxed then effect(level) .. "  (max!)" else ("%s  →  %s"):format(effect(level), effect(level + 1)),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 240, 150),
			Size = UDim2.new(1, -300, 0, 22),
			Position = UDim2.fromOffset(74, 36),
		})
		Ui.label(row, {
			Text = upgrade.Info,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(215, 245, 235),
			Size = UDim2.new(1, -300, 0, 18),
			Position = UDim2.fromOffset(74, 60),
		})

		-- level progress bar along the bottom
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 12, 1, -4)
		bar.Size = UDim2.new(1, -24, 0, 4)
		bar.BackgroundColor3 = Color3.fromRGB(30, 80, 80)
		bar.BorderSizePixel = 0
		bar.Parent = row
		Ui.corner(bar, 0.5)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(level / upgrade.Max, 1)
		fill.BackgroundColor3 = Ui.COLORS.Gold
		fill.BorderSizePixel = 0
		fill.Parent = bar
		Ui.corner(fill, 0.5)

		local canAfford = coins >= cost
		local one = Ui.button(row, if maxed then "MAX" else "💰 " .. Config.formatNumber(cost), if maxed
			then Ui.COLORS.PanelDark
			elseif canAfford then Ui.COLORS.Green
			else Color3.fromRGB(140, 150, 160), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -86, 0.5, -2),
			Size = UDim2.fromOffset(130, 48),
		})
		local max = Ui.button(row, "Max", if canAfford and not maxed then Ui.COLORS.Gold else Color3.fromRGB(140, 150, 160), {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, -2),
			Size = UDim2.fromOffset(66, 48),
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

-- anything affordable right now?
local function affordable()
	local data = State.Data
	if not data then
		return false
	end
	local coins = player:GetAttribute("Coins") or 0
	for _, upgrade in ipairs(Config.AREA_UPGRADES) do
		local level = data.Upgrades[upgrade.Id] or 0
		if level < upgrade.Max and coins >= Config.upgradeCost(upgrade, level, data.Rebirths) then
			return true
		end
	end
	return false
end

-- Hooks up the button's "!" badge, which wiggles when you can buy something.
function AreaUpgrades.attach(button)
	local badge = Ui.label(button, {
		Text = "!",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = Ui.COLORS.Green,
		ZIndex = 3,
		Visible = false,
	})
	Ui.corner(badge, 0.5)
	task.spawn(function()
		while true do
			local show = affordable()
			badge.Visible = show
			if show then
				badge.Rotation = if badge.Rotation == 0 then 15 else 0
			end
			task.wait(0.5)
		end
	end)
end

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)
local pending = false
player:GetAttributeChangedSignal("Coins"):Connect(function()
	if panel.isOpen() and not pending then
		pending = true
		task.delay(0.4, function()
			pending = false
			if panel.isOpen() then
				render()
			end
		end)
	end
end)

AreaUpgrades.toggle = panel.toggle

return AreaUpgrades
