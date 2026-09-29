-- Pet management requests from the pets menu: equip/unequip, equip best,
-- and deleting pets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Inventory = {}

local function setEquipped(player, petIndex, equip)
	local data = PlayerData.get(player)
	if not data or typeof(petIndex) ~= "number" or typeof(equip) ~= "boolean" then
		return false
	end
	if not data.Pets[petIndex] then
		return false
	end

	local equipped = table.clone(data.Equipped)
	local pos = table.find(equipped, petIndex)
	if equip and not pos then
		local max = Config.totalSlots(data)
		if #equipped >= max then
			return false, "You can only equip " .. max .. " pets! Buy more slots in the shop."
		end
		table.insert(equipped, petIndex)
	elseif not equip and pos then
		table.remove(equipped, pos)
	end
	PlayerData.setEquipped(player, equipped)
	return true
end

-- Equips the strongest pets.
local function equipBest(player)
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local order = {}
	for index, petName in ipairs(data.Pets) do
		if Config.PETS[petName] then
			table.insert(order, index)
		end
	end
	table.sort(order, function(a, b)
		return Config.PETS[data.Pets[a]].Power > Config.PETS[data.Pets[b]].Power
	end)

	local equipped = {}
	for i = 1, math.min(#order, Config.totalSlots(data)) do
		table.insert(equipped, order[i])
	end
	PlayerData.setEquipped(player, equipped)
	return true, "⚡ Equipped your best pets!"
end

-- Deletes the given pets. Equipped pets can't be deleted (so nobody deletes
-- their best pet by accident).
local function deletePets(player, indexes)
	local data = PlayerData.get(player)
	if not data or typeof(indexes) ~= "table" then
		return false
	end
	local keep = {}
	for i = 1, #data.Pets do
		keep[i] = true
	end
	local count = 0
	for _, index in ipairs(indexes) do
		if typeof(index) == "number" and keep[index] and not table.find(data.Equipped, index) then
			keep[index] = false
			count += 1
		end
	end
	if count == 0 then
		return false, "Nothing to delete (equipped pets can't be deleted)."
	end
	if count >= #data.Pets then
		return false, "You need to keep at least one pet!"
	end
	PlayerData.rebuildPets(player, keep)
	return true, "🗑️ Deleted " .. count .. " pet" .. (if count == 1 then "" else "s")
end

function Inventory.start(remotes)
	remotes.SetEquipped.OnServerInvoke = setEquipped
	remotes.EquipBest.OnServerInvoke = equipBest
	remotes.DeletePets.OnServerInvoke = deletePets
end

return Inventory
