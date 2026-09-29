-- The shop menu: opens at the shop stall in the main area. Two tabs:
--   💰 Upgrades     - bought with coins, reset when you rebirth
--   💎 Diamond Shop - 2x potions and permanent perks, bought with diamonds
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Boosts = require(script.Parent.Boosts)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Shop = {}

-- fixed: only stepping off the shop circle closes it
local panel = Ui.panel("Shop", nil, UDim2.fromOffset(640, 540), { Ui.COLORS.Gold }, { Fixed = true })

-- minimal text tabs, like the pets menu
local tabBar = Instance.new("Frame")
tabBar.BackgroundTransparency = 1
tabBar.Size = UDim2.new(1, 0, 0, 32)
tabBar.Parent = panel.Content
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 20)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 40)
list.Size = UDim2.new(1, 0, 1, -40)
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

local tab = "Upgrades"
local tabs = {}
local busy = false
local render

for order, def in ipairs({ { "Upgrades", "💰 Upgrades" }, { "Diamonds", "💎 Diamond Shop" } }) do
	local button = Instance.new("TextButton")
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, 30)
	button.BackgroundTransparency = 1
	button.Text = def[2]
	button.Font = Ui.FONT
	button.TextSize = 17
	button.TextColor3 = Ui.COLORS.Text
	button.LayoutOrder = order
	button.Parent = tabBar
	local underline = Instance.new("Frame")
	underline.AnchorPoint = Vector2.new(0.5, 1)
	underline.Position = UDim2.fromScale(0.5, 1)
	underline.Size = UDim2.new(1, 0, 0, 3)
	underline.BackgroundColor3 = Ui.COLORS.Accent
	underline.BorderSizePixel = 0
	underline.Parent = button
	button.Activated:Connect(function()
		tab = def[1]
		render()
	end)
	tabs[def[1]] = { Button = button, Underline = underline }
end

local function header(order, text)
	Ui.label(list, {
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Ui.FONT_BODY,
		TextColor3 = Ui.COLORS.SubText,
		Size = UDim2.new(1, -12, 0, 20),
		LayoutOrder = order,
	})
end

-- One shop row. `level`/`max` draw pips when max > 1; `extra` goes after the
-- name (e.g. "Lv 2/10" or "⏰ 4:59").
local function row(order, item)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, -12, 0, 76)
	r.BackgroundColor3 = Ui.COLORS.Card
	r.LayoutOrder = order
	r.Parent = list
	Ui.corner(r, 14)
	Ui.stroke(r, Ui.COLORS.Line, 1.5)

	Ui.label(r, { Text = item.Icon, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10) })
	Ui.label(r, {
		Text = item.Name .. (if item.Extra then "  " .. item.Extra else ""),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -230, 0, 30),
		Position = UDim2.fromOffset(76, 8),
	})
	Ui.label(r, {
		Text = item.Info,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = if item.InfoColor then Ui.FONT else Ui.FONT_BODY,
		TextColor3 = item.InfoColor or Ui.COLORS.SubText,
		Size = UDim2.new(1, -230, 0, 22),
		Position = UDim2.fromOffset(76, 42),
	})

	if item.Max and item.Max > 1 then
		local pips = Instance.new("Frame")
		pips.BackgroundTransparency = 1
		pips.Size = UDim2.new(1, -230, 0, 6)
		pips.Position = UDim2.fromOffset(76, 66)
		pips.Parent = r
		for i = 1, item.Max do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(1 / item.Max, -3, 1, 0)
			pip.Position = UDim2.fromScale((i - 1) / item.Max, 0)
			pip.BackgroundColor3 = if i <= item.Level then item.PipColor else Ui.COLORS.PanelDark
			pip.BorderSizePixel = 0
			pip.Parent = pips
			Ui.corner(pip, 0.5)
		end
	end

	local color = if item.Maxed
		then Ui.COLORS.PanelDark
		elseif item.CanAfford then item.BuyColor
		else Ui.COLORS.Disabled
	local buy = Ui.button(r, if item.Maxed then "MAX" else item.Price, color, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(130, 50),
	})
	buy.Activated:Connect(function()
		if item.Maxed or busy then
			return
		end
		busy = true
		local ok, message = item.Buy()
		if message then
			Ui.toast(message, if ok then Ui.COLORS.Gold else Ui.COLORS.Red)
		end
		if ok then
			Fx.confetti(20)
		end
		busy = false
	end)
end

local function upgradesTab(data)
	header(0, "Bought with coins · kept forever")
	local coins = player:GetAttribute("Coins") or 0
	for order, upgrade in ipairs(Config.UPGRADES) do
		local level = data.Upgrades[upgrade.Id] or 0
		local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
		-- show the real value: "x2.5 ➜ x4.0", or "x100 MAX" when maxed
		local now = Boosts.upgradeText(upgrade.Id, level)
		local info = upgrade.Info
		if now then
			info = if level >= upgrade.Max
				then now .. "  MAX"
				else now .. "  ➜  " .. Boosts.upgradeText(upgrade.Id, level + 1)
		end
		row(order, {
			Icon = upgrade.Icon,
			Name = upgrade.Name,
			Extra = if upgrade.Max > 1 then ("Lv %d/%d"):format(level, upgrade.Max) else nil,
			Info = info,
			InfoColor = if now then Ui.COLORS.Green else nil,
			Level = level,
			Max = upgrade.Max,
			PipColor = Ui.COLORS.Gold,
			Maxed = level >= upgrade.Max,
			Price = "💰 " .. Config.formatNumber(cost),
			CanAfford = coins >= cost,
			BuyColor = Ui.COLORS.Green,
			Buy = function()
				return remotes.BuyUpgrade:InvokeServer(upgrade.Id)
			end,
		})
	end
end

local function diamondsTab(data)
	local diamonds = player:GetAttribute("Diamonds") or 0
	local cyan = Color3.fromRGB(60, 180, 240)

	header(0, "🧪 Potions · 2x for 10 min · only counts down while you play")
	for order, boost in ipairs(Config.BOOSTS) do
		local left = math.floor(State.boostLeft(boost.Id))
		row(order, {
			Icon = boost.Icon,
			Name = boost.Name,
			Extra = if left > 0 then ("⏰ %d:%02d"):format(left // 60, left % 60) else nil,
			Info = if left > 0 then "Active! Buy more to add time" else "Double for " .. boost.Minutes .. " minutes",
			Maxed = left + boost.Minutes * 60 > Config.BOOST_MAX_MINUTES * 60,
			Price = "💎 " .. Config.formatNumber(boost.Cost),
			CanAfford = diamonds >= boost.Cost,
			BuyColor = cyan,
			Buy = function()
				return remotes.BuyBoost:InvokeServer(boost.Id)
			end,
		})
	end

	header(10, "💎 Forever perks · kept when you rebirth")
	for order, perk in ipairs(Config.PERKS) do
		local level = data.Perks[perk.Id] or 0
		local cost = Config.perkCost(perk, level)
		row(10 + order, {
			Icon = perk.Icon,
			Name = perk.Name,
			Extra = ("Lv %d/%d"):format(level, perk.Max),
			Info = perk.Info,
			Level = level,
			Max = perk.Max,
			PipColor = Color3.fromRGB(110, 220, 255),
			Maxed = level >= perk.Max,
			Price = "💎 " .. Config.formatNumber(cost),
			CanAfford = diamonds >= cost,
			BuyColor = cyan,
			Buy = function()
				return remotes.BuyPerk:InvokeServer(perk.Id)
			end,
		})
	end
end

render = function()
	Ui.clear(list)
	for id, t in pairs(tabs) do
		t.Button.TextTransparency = if id == tab then 0 else 0.5
		t.Underline.Visible = id == tab
	end
	local data = State.Data
	if not data then
		return
	end
	if tab == "Upgrades" then
		upgradesTab(data)
	else
		diamondsTab(data)
	end
end

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)

-- coins/diamonds change often (and potion timers tick): refresh now and then
task.spawn(function()
	local pending = false
	local function refreshSoon()
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
	player:GetAttributeChangedSignal("Coins"):Connect(refreshSoon)
	player:GetAttributeChangedSignal("Diamonds"):Connect(refreshSoon)
	while true do
		task.wait(1)
		if tab == "Diamonds" then
			refreshSoon()
		end
	end
end)

-- Stand on the glowing circle in front of the stall to open the shop; step
-- off to close it. If you close it yourself, it stays closed until you step
-- off and back on.
task.spawn(function()
	local onPad = false
	local openedByPad = false
	while true do
		task.wait(0.15)
		local shop = workspace:FindFirstChild("MainArea") and workspace.MainArea:FindFirstChild("Shop")
		local pad = shop and shop:FindFirstChild("ShopPad")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local inside = false
		if pad and root then
			local offset = root.Position - pad.Position
			inside = Vector3.new(offset.X, 0, offset.Z).Magnitude < pad.Size.Y / 2 and math.abs(offset.Y) < 8
		end
		if inside and not onPad then
			panel.open()
			openedByPad = true
		elseif not inside and onPad and openedByPad then
			panel.close()
			openedByPad = false
		end
		onPad = inside
	end
end)

return Shop
