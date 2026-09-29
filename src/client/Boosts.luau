-- Small boost icons in the bottom right corner: active potions (with a timer),
-- diamond perks and coin upgrades (⚔️ +20%, 🍀 +15%, ...). Hover one to see
-- its name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Boosts = {}

-- How each upgrade's boost is written, from the player's upgrade levels.
local TEXT = {
	Damage = function(u)
		return ("+%d%%"):format(math.floor((Config.damageMult(u) - 1) * 100 + 0.5))
	end,
	Luck = function(u)
		return ("+%d%%"):format(math.floor((Config.luckMult(u) - 1) * 100 + 0.5))
	end,
	WalkSpeed = function(u)
		return ("+%d"):format(Config.walkSpeed(u) - Config.walkSpeed(nil))
	end,
	PetSpeed = function(u)
		return ("+%d%%"):format(math.floor((Config.petSpeedMult(u) - 1) * 100 + 0.5))
	end,
	CoinBonus = function(u)
		return ("+%d%%"):format(math.floor((Config.coinMult(u) - 1) * 100 + 0.5))
	end,
	Slots = function(u)
		return ("+%d"):format(Config.maxEquipped(u) - Config.maxEquipped(nil))
	end,
	Hoverboard = function()
		return "ON"
	end,
}

local holder = Instance.new("Frame")
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.new(1, -10, 1, -10)
holder.Size = UDim2.fromOffset(150, 340)
holder.BackgroundTransparency = 1
holder.Parent = Ui.gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = holder

local tooltip = Ui.label(Ui.gui, {
	AnchorPoint = Vector2.new(1, 1),
	Size = UDim2.fromOffset(140, 22),
	BackgroundTransparency = 0.2,
	BackgroundColor3 = Ui.COLORS.PanelDark,
	Visible = false,
	ZIndex = 10,
})
Ui.corner(tooltip, 8)

local PERK_TEXT = {
	Coins = function(level)
		return ("+%d%%"):format(level * 10)
	end,
	Luck = function(level)
		return ("+%d%%"):format(level * 10)
	end,
	Backpack = function(level)
		return ("+%d"):format(level * 25)
	end,
	Slots = function(level)
		return ("+%d"):format(level)
	end,
}

-- One little pill: icon + short text, with a name tooltip on hover.
local function pill(order, icon, text, name, color)
	local p = Instance.new("Frame")
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, 26)
	p.BackgroundColor3 = color or Ui.COLORS.PanelDark
	p.BackgroundTransparency = 0.15
	p.LayoutOrder = order
	p.Parent = holder
	Ui.corner(p, 0.5)
	Ui.stroke(p, Ui.COLORS.Outline, 2)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = p

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 3)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = p

	Ui.label(p, { Text = icon, Size = UDim2.fromOffset(18, 18), TextStrokeTransparency = 1, LayoutOrder = 1 })
	Ui.label(p, {
		Text = text,
		TextScaled = false,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		LayoutOrder = 2,
	})

	p.MouseEnter:Connect(function()
		tooltip.Text = name
		tooltip.Position = UDim2.fromOffset(p.AbsolutePosition.X - 6, p.AbsolutePosition.Y + p.AbsoluteSize.Y)
		tooltip.Visible = true
	end)
	p.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
end

local POTION_COLOR = Color3.fromRGB(40, 140, 110)
local PERK_COLOR = Color3.fromRGB(40, 110, 170)

local function render()
	Ui.clear(holder)
	local data = State.Data
	if not data then
		return
	end

	-- potions first (with a timer), then diamond perks, then coin upgrades
	for order, boost in ipairs(Config.BOOSTS) do
		local left = math.floor(State.boostLeft(boost.Id))
		if left > 0 then
			pill(order, "🧪", ("%s 2x %d:%02d"):format(boost.Icon, left // 60, left % 60), boost.Name .. " potion", POTION_COLOR)
		end
	end
	for order, perk in ipairs(Config.PERKS) do
		local level = data.Perks and data.Perks[perk.Id] or 0
		if level > 0 then
			pill(10 + order, "💎", perk.Icon .. " " .. PERK_TEXT[perk.Id](level), perk.Name .. " (forever)", PERK_COLOR)
		end
	end
	for order, upgrade in ipairs(Config.UPGRADES) do
		if (data.Upgrades[upgrade.Id] or 0) > 0 then
			pill(20 + order, upgrade.Icon, TEXT[upgrade.Id](data.Upgrades), upgrade.Name)
		end
	end
end

State.Changed.Event:Connect(render)

-- tick the potion timers
task.spawn(function()
	while true do
		task.wait(1)
		local data = State.Data
		if data and data.Boosts and next(data.Boosts) then
			render()
		end
	end
end)

return Boosts
