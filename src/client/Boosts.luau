-- Small boost icons in the bottom right corner showing every active upgrade
-- (⚔️ +20%, 🍀 +15%, ...). Hover one to see its name.
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
holder.Size = UDim2.fromOffset(110, 260)
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

local function render()
	Ui.clear(holder)
	local data = State.Data
	if not data then
		return
	end
	for order, upgrade in ipairs(Config.UPGRADES) do
		if (data.Upgrades[upgrade.Id] or 0) > 0 then
			local pill = Instance.new("Frame")
			pill.AutomaticSize = Enum.AutomaticSize.X
			pill.Size = UDim2.fromOffset(0, 26)
			pill.BackgroundColor3 = Ui.COLORS.PanelDark
			pill.BackgroundTransparency = 0.15
			pill.LayoutOrder = order
			pill.Parent = holder
			Ui.corner(pill, 0.5)
			Ui.stroke(pill, Ui.COLORS.Outline, 2)

			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 8)
			pad.Parent = pill

			local row = Instance.new("UIListLayout")
			row.FillDirection = Enum.FillDirection.Horizontal
			row.VerticalAlignment = Enum.VerticalAlignment.Center
			row.Padding = UDim.new(0, 3)
			row.Parent = pill

			Ui.label(pill, { Text = upgrade.Icon, Size = UDim2.fromOffset(18, 18), TextStrokeTransparency = 1 })
			local amount = Ui.label(pill, {
				Text = TEXT[upgrade.Id](data.Upgrades),
				TextScaled = false,
				TextSize = 14,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 18),
			})
			amount.LayoutOrder = 2

			pill.MouseEnter:Connect(function()
				tooltip.Text = upgrade.Name
				tooltip.Position = UDim2.fromOffset(pill.AbsolutePosition.X - 6, pill.AbsolutePosition.Y + pill.AbsoluteSize.Y)
				tooltip.Visible = true
			end)
			pill.MouseLeave:Connect(function()
				tooltip.Visible = false
			end)
		end
	end
end

State.Changed.Event:Connect(render)

return Boosts
