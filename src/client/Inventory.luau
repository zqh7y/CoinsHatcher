-- The pets menu: every pet you own, click Equip / Unequip.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Inventory = {}

local panel = Ui.panel("Pets", "🐾", UDim2.fromOffset(640, 460))
local list = Ui.grid(panel.Content, UDim2.fromOffset(132, 178))

local function render()
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

	for index, petName in ipairs(data.Pets) do
		local info = Config.PETS[petName]
		if not info then
			continue
		end
		local equipped = table.find(data.Equipped, index) ~= nil

		local card = Cards.pet(list, petName, {
			Detail = "⚔️ " .. Config.formatNumber(info.Power),
			-- equipped first, then strongest first
			LayoutOrder = (if equipped then 0 else 1e9) - info.Power,
			Background = if equipped then Color3.fromRGB(95, 180, 120) else nil,
		})
		card.PetName.Size = UDim2.new(1, -10, 0.14, 0)
		card.Detail.Size = UDim2.new(1, -10, 0.1, 0)
		card.Detail.Position = UDim2.new(0, 5, 0.72, 0)

		local button = Ui.button(card, if equipped then "Unequip" else "Equip", if equipped then Ui.COLORS.Red else Ui.COLORS.Green, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -14, 0.15, 0),
		})
		button.Activated:Connect(function()
			local ok, message = remotes.SetEquipped:InvokeServer(index, not equipped)
			if not ok and message then
				Ui.toast(message, Ui.COLORS.Red)
			end
		end)
	end
end

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)

Inventory.toggle = panel.toggle

return Inventory
