-- The pets menu: stats at the top (pets, team power, best pet), filter tabs,
-- and every pet you own with its odds. Equip / Unequip, Equip Best, and a
-- delete mode (tap pets to pick them, then delete).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Inventory = {}

local panel = Ui.panel("Pets", "🐾", UDim2.fromOffset(780, 540), {
	Color3.fromRGB(110, 150, 255),
	Color3.fromRGB(80, 60, 180),
})

-- Stats bar ---------------------------------------------------------------------

local statsBar = Instance.new("Frame")
statsBar.BackgroundTransparency = 1
statsBar.Size = UDim2.new(1, 0, 0, 40)
statsBar.Parent = panel.Content
local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.Padding = UDim.new(0, 8)
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsBar

local function stat(color, order, width)
	local l = Ui.label(statsBar, {
		Size = UDim2.new(width, -6, 1, 0),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		LayoutOrder = order,
	})
	Ui.corner(l, 0.5)
	Ui.stroke(l, Color3.new(1, 1, 1), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = l
	return l
end
local countStat = stat(Color3.fromRGB(90, 170, 255), 1, 0.22)
local powerStat = stat(Color3.fromRGB(255, 120, 120), 2, 0.34)
local bestStat = stat(Color3.fromRGB(255, 185, 50), 3, 0.44)

-- Tabs + actions ----------------------------------------------------------------

local TABS = {
	{ "All", nil },
	{ "Equipped", "Equipped" },
	{ "Common", "Common" },
	{ "Uncommon", "Uncommon" },
	{ "Rare", "Rare" },
	{ "Legendary", "Legendary" },
	{ "Huge", "Huge" },
	{ "Mutated", "Mutated" },
}

local tabBar = Instance.new("ScrollingFrame")
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.Position = UDim2.fromOffset(0, 48)
tabBar.Size = UDim2.new(1, -330, 0, 44)
tabBar.ScrollBarThickness = 0
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.CanvasSize = UDim2.new()
tabBar.Parent = panel.Content
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 14)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local actions = Instance.new("Frame")
actions.BackgroundTransparency = 1
actions.AnchorPoint = Vector2.new(1, 0)
actions.Position = UDim2.new(1, 0, 0, 48)
actions.Size = UDim2.fromOffset(320, 44)
actions.Parent = panel.Content
local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
actionLayout.Padding = UDim.new(0, 8)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actions

local equipBest = Ui.button(actions, "⚡ Best", Ui.COLORS.Gold, { Size = UDim2.fromOffset(100, 42), LayoutOrder = 1 })
local deleteMode = Ui.button(actions, "🗑️", Ui.COLORS.Red, { Size = UDim2.fromOffset(60, 42), LayoutOrder = 2 })
local deleteConfirm = Ui.button(actions, "Delete 0", Ui.COLORS.Red, { Size = UDim2.fromOffset(130, 42), LayoutOrder = 3, Visible = false })

local listHolder = Instance.new("Frame")
listHolder.BackgroundTransparency = 1
listHolder.Position = UDim2.fromOffset(0, 100)
listHolder.Size = UDim2.new(1, 0, 1, -100)
listHolder.Parent = panel.Content
local list = Ui.grid(listHolder, UDim2.fromOffset(132, 188))

local filter = nil -- current tab's filter
local deleting = false
local selected = {} -- [petIndex] = true while picking pets to delete
local tabButtons = {}

local render

local function countSelected()
	local n = 0
	for _ in pairs(selected) do
		n += 1
	end
	return n
end

local function setDeleting(on)
	deleting = on
	selected = {}
	deleteMode.Text = if on then "✖" else "🗑️"
	deleteConfirm.Visible = on
	deleteConfirm.Text = "Delete 0"
	render()
end

-- minimal text tabs: the active one is bright with a thin underline
for order, tab in ipairs(TABS) do
	local button = Instance.new("TextButton")
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, 30)
	button.BackgroundTransparency = 1
	button.Text = tab[1]
	button.Font = Ui.FONT
	button.TextSize = 17
	button.TextColor3 = Color3.new(1, 1, 1)
	button.LayoutOrder = order
	button.Parent = tabBar

	local underline = Instance.new("Frame")
	underline.AnchorPoint = Vector2.new(0.5, 1)
	underline.Position = UDim2.fromScale(0.5, 1)
	underline.Size = UDim2.new(1, 0, 0, 2)
	underline.BackgroundColor3 = Color3.new(1, 1, 1)
	underline.BorderSizePixel = 0
	underline.Parent = button

	button.Activated:Connect(function()
		filter = tab[2]
		render()
	end)
	tabButtons[order] = { Button = button, Underline = underline, Filter = tab[2] }
end

local function matches(info, equipped)
	if filter == nil then
		return true
	elseif filter == "Equipped" then
		return equipped
	elseif filter == "Mutated" then
		return info.Mutation ~= nil
	end
	return info.Rarity == filter
end

render = function()
	Ui.clear(list)
	local data = State.Data
	if not data then
		return
	end

	for _, tab in ipairs(tabButtons) do
		local active = tab.Filter == filter
		tab.Button.TextTransparency = if active then 0 else 0.5
		tab.Underline.Visible = active
	end

	-- stats
	local teamPower, best = 0, nil
	for _, index in ipairs(data.Equipped) do
		local info = Config.PETS[data.Pets[index] or ""]
		if info then
			teamPower += info.Power
		end
	end
	for _, petName in ipairs(data.Pets) do
		local info = Config.PETS[petName]
		if info and (not best or info.Power > Config.PETS[best].Power) then
			best = petName
		end
	end
	countStat.Text = ("🐾 %d/%d"):format(#data.Pets, Config.maxPets(data))
	powerStat.Text = "⚔️ Team " .. Config.formatNumber(teamPower * Config.totalDamage(data))
	bestStat.Text = "🏆 " .. (best or "-")
	panel.Title.Text = ("🐾 Pets   ·   Equipped %d/%d"):format(#data.Equipped, Config.totalSlots(data))

	-- equipped first, then strongest first
	local order = {}
	for index, petName in ipairs(data.Pets) do
		local info = Config.PETS[petName]
		if info and matches(info, table.find(data.Equipped, index) ~= nil) then
			table.insert(order, index)
		end
	end
	table.sort(order, function(a, b)
		local ea = table.find(data.Equipped, a) ~= nil
		local eb = table.find(data.Equipped, b) ~= nil
		if ea ~= eb then
			return ea
		end
		return Config.PETS[data.Pets[a]].Power > Config.PETS[data.Pets[b]].Power
	end)

	if #order == 0 then
		Ui.label(list, { Text = "No pets here yet! 🥚", LayoutOrder = 1 })
	end

	for rank, index in ipairs(order) do
		local petName = data.Pets[index]
		local info = Config.PETS[petName]
		local equipped = table.find(data.Equipped, index) ~= nil
		local picked = selected[index] == true

		local card = Cards.pet(list, petName, {
			Detail = Config.chanceText(petName) .. " · ⚔️" .. Config.formatNumber(info.Power),
			LayoutOrder = rank,
			Equipped = equipped,
			Picked = picked,
		})
		card.PetName.Size = UDim2.new(1, -10, 0.13, 0)
		card.PetName.Position = UDim2.new(0, 5, 0.56, 0)
		card.Detail.Size = UDim2.new(1, -10, 0.1, 0)
		card.Detail.Position = UDim2.new(0, 5, 0.7, 0)

		local text, color
		if deleting then
			text = if equipped then "Equipped" elseif picked then "✔ Picked" else "Pick"
			color = if equipped then Ui.COLORS.PanelDark elseif picked then Ui.COLORS.Red else Color3.fromRGB(150, 140, 170)
		else
			text = if equipped then "Unequip" else "Equip"
			color = if equipped then Ui.COLORS.Red else Ui.COLORS.Green
		end
		local button = Ui.button(card, text, color, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -14, 0.15, 0),
			ZIndex = 3,
		})
		button.Activated:Connect(function()
			if deleting then
				if not equipped then
					selected[index] = if picked then nil else true
					deleteConfirm.Text = "Delete " .. countSelected()
					render()
				end
				return
			end
			local ok, message = remotes.SetEquipped:InvokeServer(index, not equipped)
			if not ok and message then
				Ui.toast(message, Ui.COLORS.Red)
			end
		end)
	end
end

equipBest.Activated:Connect(function()
	local ok, message = remotes.EquipBest:InvokeServer()
	if message then
		Ui.toast(message, if ok then Ui.COLORS.Gold else Ui.COLORS.Red)
	end
end)

deleteMode.Activated:Connect(function()
	setDeleting(not deleting)
end)

deleteConfirm.Activated:Connect(function()
	local indexes = {}
	for index in pairs(selected) do
		table.insert(indexes, index)
	end
	if #indexes == 0 then
		Ui.toast("Tap pets to pick which ones to delete!", Ui.COLORS.White)
		return
	end
	local ok, message = remotes.DeletePets:InvokeServer(indexes)
	if message then
		Ui.toast(message, if ok then Ui.COLORS.White else Ui.COLORS.Red)
	end
	setDeleting(false)
end)

panel.OnOpen.Event:Connect(function()
	if deleting then
		setDeleting(false)
	else
		render()
	end
end)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		-- pet numbers shift after deleting, so drop any picks
		selected = {}
		deleteConfirm.Text = "Delete 0"
		render()
	end
end)

Inventory.toggle = panel.toggle

return Inventory
