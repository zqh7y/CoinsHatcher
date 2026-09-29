-- Server entry point: builds the world, starts every system and handles
-- requests from the client (teleport, rebirth, equip).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.PlayerData)
local World = require(script.World)
local Coins = require(script.Coins)
local Pets = require(script.Pets)
local Eggs = require(script.Eggs)

-- Remotes the client talks to
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function remote(className, name)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local Teleport = remote("RemoteEvent", "Teleport") -- client -> server: "Main" | "Eggs"
local Rebirth = remote("RemoteFunction", "Rebirth") -- client -> server, returns ok, message
local SetEquipped = remote("RemoteFunction", "SetEquipped") -- client -> server: petIndex, bool
local GetData = remote("RemoteFunction", "GetData") -- client -> server, returns data
local DataChanged = remote("RemoteEvent", "DataChanged") -- server -> client: data
remote("RemoteEvent", "Notify") -- server -> client: message, color
remote("RemoteEvent", "Hatched") -- server -> client: petName

remotes.Parent = ReplicatedStorage

World.build()
PlayerData.start()
Coins.start()
Pets.start()
Eggs.start(remotes)

-- Keep the client's copy of the data (pets, equipped, rebirths) up to date
PlayerData.Changed.Event:Connect(function(player)
	DataChanged:FireClient(player, PlayerData.get(player))
end)

GetData.OnServerInvoke = function(player)
	return PlayerData.waitFor(player)
end

local lastTeleport = {}
Teleport.OnServerEvent:Connect(function(player, area)
	if area ~= "Main" and area ~= "Eggs" then
		return
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < 1 then
		return
	end
	lastTeleport[player] = now

	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(World.spawnCFrame(area))
	end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

Rebirth.OnServerInvoke = function(player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading..."
	end
	if data.Rebirths >= Config.MAX_REBIRTHS then
		return false, "You're at max rebirth!"
	end
	local cost = Config.rebirthCost(data.Rebirths)
	if data.Coins < cost then
		return false, "You need " .. Config.formatNumber(cost) .. " coins to rebirth!"
	end

	PlayerData.rebirth(player)
	Coins.reset(player) -- respawn their coins at the new, stronger level
	return true, "Rebirth " .. data.Rebirths .. "! The area got stronger and a new egg unlocked!"
end

SetEquipped.OnServerInvoke = function(player, petIndex, equip)
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
		if #equipped >= Config.MAX_EQUIPPED then
			return false, "You can only equip " .. Config.MAX_EQUIPPED .. " pets!"
		end
		table.insert(equipped, petIndex)
	elseif not equip and pos then
		table.remove(equipped, pos)
	end
	PlayerData.setEquipped(player, equipped)
	return true
end
