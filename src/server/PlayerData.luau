-- Loads, saves and changes player data. Other server modules go through here.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local store = DataStoreService:GetDataStore("PlayerData_v1")

local PlayerData = {}

-- Fires (player) after data loads and whenever Pets/Equipped/Rebirths change.
PlayerData.Changed = Instance.new("BindableEvent")

local DEFAULT = {
	Coins = 0,
	Rebirths = 0,
	Pets = {}, -- list of pet names the player owns
	Equipped = {}, -- indexes into Pets for the pets following them
	Upgrades = {}, -- [upgrade id] = level, bought in the shop
	Index = {}, -- [pet name] = true for every pet ever hatched
}

local sessionData = {} -- [player] = data table while they're in game
local loadFailed = {} -- [player] = true if we couldn't load, so we don't overwrite their save

local function setStat(player, name, value)
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild(name)
	if stat then
		stat.Value = value
	end
end

local function load(player)
	local ok, saved = pcall(function()
		return store:GetAsync("user_" .. player.UserId)
	end)
	if not ok then
		warn("Load failed for", player.Name, saved)
		loadFailed[player] = true
	end

	local data = table.clone(DEFAULT)
	data.Pets = {}
	data.Equipped = {}
	data.Upgrades = {}
	data.Index = {}
	if ok and saved then
		for k, v in pairs(saved) do
			data[k] = v
		end
	end
	-- older saves: fill in the index from the pets they already own
	for _, petName in ipairs(data.Pets) do
		data.Index[petName] = true
	end

	-- new players get a starter pet so they can break coins
	if #data.Pets == 0 then
		table.insert(data.Pets, Config.STARTER_PET)
		table.insert(data.Equipped, 1)
		data.Index[Config.STARTER_PET] = true
	end

	-- leaderstats shows Coins/Rebirths on the player list
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = stats

	stats.Parent = player

	if player.Parent then
		sessionData[player] = data
		PlayerData.Changed:Fire(player)
	end
end

local function save(player)
	local data = sessionData[player]
	if not data or loadFailed[player] then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("user_" .. player.UserId, data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
end

-- Returns the player's data, or nil if it hasn't loaded yet.
function PlayerData.get(player)
	return sessionData[player]
end

-- Waits (up to 15s) for the player's data to load.
function PlayerData.waitFor(player)
	local start = os.clock()
	while not sessionData[player] and player.Parent and os.clock() - start < 15 do
		task.wait(0.1)
	end
	return sessionData[player]
end

function PlayerData.addCoins(player, amount)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Coins = math.floor(data.Coins + amount)
	setStat(player, "Coins", data.Coins)
end

-- Rebirth resets everything except pets (and the index of pets found).
function PlayerData.rebirth(player)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Coins = 0
	data.Rebirths += 1
	data.Upgrades = {}
	-- extra pet slots were reset, so unequip pets that no longer fit
	while #data.Equipped > Config.maxEquipped(data.Upgrades) do
		table.remove(data.Equipped)
	end
	setStat(player, "Coins", data.Coins)
	setStat(player, "Rebirths", data.Rebirths)
	PlayerData.Changed:Fire(player)
end

function PlayerData.addPet(player, petName)
	local data = sessionData[player]
	if not data then
		return
	end
	table.insert(data.Pets, petName)
	data.Index[petName] = true
	PlayerData.Changed:Fire(player)
	return #data.Pets
end

function PlayerData.setUpgrade(player, id, level)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Upgrades[id] = level
	PlayerData.Changed:Fire(player)
end

function PlayerData.setEquipped(player, equipped)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Equipped = equipped
	PlayerData.Changed:Fire(player)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		sessionData[player] = nil
		loadFailed[player] = nil
	end)

	-- save everyone if the server shuts down
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			save(player)
		end
	end)
end

return PlayerData
