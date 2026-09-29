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
		return Config.formatMult(Config.damageMult(u))
	end,
	Luck = function(u)
		return Config.formatMult(Config.luckMult(u))
	end,
	WalkSpeed = function(u)
		return ("+%d"):format(Config.walkSpeed(u) - Config.walkSpeed(nil))
	end,
	PetSpeed = function(u)
		return ("+%d%%"):format(math.floor((Config.petSpeedMult(u) - 1) * 100 + 0.5))
	end,
	CoinBonus = function(u)
		return Config.formatMult(Config.coinMult(u))
	end,
	Slots = function(u)
		return ("+%d"):format(Config.maxEquipped(u) - Config.maxEquipped(nil))
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
	BackgroundColor3 = Ui.COLORS.Panel,
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

-- One small pill: icon + short text, with a name tooltip on hover.
local function pill(order, icon, text, name, color)
	local p = Instance.new("Frame")
	p.AutomaticSize = Enum.AutomaticSize.X
	p.Size = UDim2.fromOffset(0, 22)
	p.BackgroundColor3 = Ui.COLORS.Panel
	p.LayoutOrder = order
	p.Parent = holder
	Ui.corner(p, 0.5)
	-- potions and perks get a colored border
	Ui.stroke(p, color or Ui.COLORS.Line, if color then 1.5 else 1)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 7)
	pad.Parent = p

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 3)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = p

	if icon ~= "" then
		Ui.label(p, { Text = icon, Size = UDim2.fromOffset(14, 14), LayoutOrder = 1 })
	end
	Ui.label(p, {
		Text = text,
		TextScaled = false,
		TextSize = 12,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		LayoutOrder = 2,
	})

	p.MouseEnter:Connect(function()
		tooltip.Text = name
		tooltip.Size = UDim2.fromOffset(math.max(140, #name * 7), 22)
		tooltip.Position = UDim2.fromOffset(p.AbsolutePosition.X - 6, p.AbsolutePosition.Y + p.AbsoluteSize.Y)
		tooltip.Visible = true
	end)
	p.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
end

local POTION_COLOR = Ui.COLORS.Green
local PERK_COLOR = Ui.COLORS.Gem
local MAX_SHOWN = 5 -- the rest are summed up in a "+N" pill

local function render()
	Ui.clear(holder)
	tooltip.Visible = false
	local data = State.Data
	if not data then
		return
	end

	-- potions first (with a timer), then diamond perks, then coin upgrades
	local entries = {}
	for _, boost in ipairs(Config.BOOSTS) do
		local left = math.floor(State.boostLeft(boost.Id))
		if left > 0 then
			table.insert(entries, { boost.Icon, ("2x %d:%02d"):format(left // 60, left % 60), boost.Name .. " potion", POTION_COLOR })
		end
	end
	for _, perk in ipairs(Config.PERKS) do
		local level = data.Perks and data.Perks[perk.Id] or 0
		if level > 0 then
			table.insert(entries, { perk.Icon, PERK_TEXT[perk.Id](level), perk.Name .. " (forever)", PERK_COLOR })
		end
	end
	for _, upgrade in ipairs(Config.UPGRADES) do
		if (data.Upgrades[upgrade.Id] or 0) > 0 then
			table.insert(entries, { upgrade.Icon, TEXT[upgrade.Id](data.Upgrades), upgrade.Name })
		end
	end

	local shown = if #entries > MAX_SHOWN then MAX_SHOWN - 1 else #entries
	for i = 1, shown do
		local e = entries[i]
		pill(i, e[1], e[2], e[3], e[4])
	end
	if #entries > shown then
		local hidden = {}
		for i = shown + 1, #entries do
			table.insert(hidden, entries[i][3])
		end
		pill(MAX_SHOWN, "", "+" .. (#entries - shown), table.concat(hidden, ", "), Ui.COLORS.Accent)
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

-- What an upgrade gives at `level` (e.g. "x4.0" or "+20%"), for the shop.
function Boosts.upgradeText(id, level)
	local f = TEXT[id]
	return if f then f({ [id] = level }) else nil
end

return Boosts
