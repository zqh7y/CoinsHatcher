-- The pets menu: every pet you own with its odds. Equip / Unequip, Equip Best,
-- and a delete mode (tap pets to pick them, then delete).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Inventory = {}

local panel = Ui.panel("Pets", "🐾", UDim2.fromOffset(680, 500))

-- top bar with Equip Best + Delete
local bar = Instance.new("Frame")
bar.BackgroundTransparency = 1
bar.Size = UDim2.new(1, 0, 0, 48)
bar.Parent = panel.Content
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.Padding = UDim.new(0, 10)
barLayout.Parent = bar

local equipBest = Ui.button(bar, "⚡ Equip Best", Ui.COLORS.Gold, { Size = UDim2.fromOffset(170, 44) })
local deleteMode = Ui.button(bar, "🗑️ Delete", Ui.COLORS.Red, { Size = UDim2.fromOffset(150, 44) })
local deleteConfirm = Ui.button(bar, "Delete 0", Ui.COLORS.Red, { Size = UDim2.fromOffset(150, 44), Visible = false })

local listHolder = Instance.new("Frame")
listHolder.BackgroundTransparency = 1
listHolder.Position = UDim2.fromOffset(0, 56)
listHolder.Size = UDim2.new(1, 0, 1, -56)
listHolder.Parent = panel.Content
local list = Ui.grid(listHolder, UDim2.fromOffset(140, 196))

local deleting = false
local selected = {} -- [petIndex] = true while picking pets to delete

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
	deleteMode.Text = if on then "✖ Cancel" else "🗑️ Delete"
	deleteConfirm.Visible = on
	deleteConfirm.Text = "Delete 0"
	render()
end

render = function()
	Ui.clear(list)
	local data = State.Data
	if not data then
		return
	end
	panel.Title.Text = ("🐾 Pets %d/%d   ·   Equipped %d/%d"):format(
		#data.Pets,
		Config.MAX_PETS,
		#data.Equipped,
		Config.maxEquipped(data.Upgrades)
	)

	-- equipped first, then strongest first
	local order = {}
	for index, petName in ipairs(data.Pets) do
		if Config.PETS[petName] then
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

	for rank, index in ipairs(order) do
		local petName = data.Pets[index]
		local info = Config.PETS[petName]
		local equipped = table.find(data.Equipped, index) ~= nil
		local picked = selected[index] == true

		local card = Cards.pet(list, petName, {
			Detail = Config.chanceText(petName) .. "  ·  ⚔️ " .. Config.formatNumber(info.Power),
			LayoutOrder = rank,
			Background = if picked
				then Color3.fromRGB(220, 90, 100)
				elseif equipped then Color3.fromRGB(95, 180, 120)
				else nil,
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
