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
	Hatched = 0, -- eggs hatched, shown on the player list for flexing
	Diamonds = 0, -- never reset
	Perks = {}, -- [perk id] = level, bought with diamonds, never reset
	Boosts = {}, -- [boost id] = seconds left on a potion (counts down while online)
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

-- Coins can get huge, so the player list shows them short ("1.5M") and the
-- exact number is kept in the player's "Coins" attribute for the client.
local function showCoins(player, coins)
	setStat(player, "Coins", Config.formatNumber(coins))
	player:SetAttribute("Coins", coins)
end

local function showDiamonds(player, diamonds)
	player:SetAttribute("Diamonds", diamonds)
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
	data.Perks = {}
	data.Boosts = {}
	if ok and saved then
		for k, v in pairs(saved) do
			data[k] = v
		end
	end
	-- older saves: fill in the index from the pets they already own
	for _, petName in ipairs(data.Pets) do
		data.Index[petName] = true
		local info = Config.PETS[petName]
		if info and info.Base then
			data.Index[info.Base] = true
		end
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

	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = stats

	local hatched = Instance.new("IntValue")
	hatched.Name = "Hatched"
	hatched.Value = data.Hatched
	hatched.Parent = stats

	stats.Parent = player
	showCoins(player, data.Coins)
	showDiamonds(player, data.Diamonds)

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
	showCoins(player, data.Coins)
end

function PlayerData.addDiamonds(player, amount)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Diamonds = math.floor(data.Diamonds + amount)
	showDiamonds(player, data.Diamonds)
end

function PlayerData.setPerk(player, id, level)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Perks[id] = level
	PlayerData.Changed:Fire(player)
end

-- Adds potion time (seconds), capped at Config.BOOST_MAX_MINUTES.
function PlayerData.addBoost(player, id, seconds)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Boosts[id] = math.min((data.Boosts[id] or 0) + seconds, Config.BOOST_MAX_MINUTES * 60)
	PlayerData.Changed:Fire(player)
end

-- Rebirth resets coins and shop upgrades. Pets, the index, diamonds, perks
-- and potions are kept.
function PlayerData.rebirth(player)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Coins = 0
	data.Rebirths += 1
	data.Upgrades = {}
	-- extra pet slots were reset, so unequip pets that no longer fit
	while #data.Equipped > Config.totalSlots(data) do
		table.remove(data.Equipped)
	end
	showCoins(player, data.Coins)
	setStat(player, "Rebirths", data.Rebirths)
	PlayerData.Changed:Fire(player)
end

-- Adds hatched pets. Returns the new pets' indexes.
function PlayerData.addPets(player, petNames)
	local data = sessionData[player]
	if not data then
		return {}
	end
	local indexes = {}
	for _, petName in ipairs(petNames) do
		table.insert(data.Pets, petName)
		table.insert(indexes, #data.Pets)
		data.Index[petName] = true
		-- a mutated pet ("Shiny Dog") also counts as finding the normal one
		local info = Config.PETS[petName]
		if info and info.Base then
			data.Index[info.Base] = true
		end
	end
	data.Hatched += #petNames
	setStat(player, "Hatched", data.Hatched)
	PlayerData.Changed:Fire(player)
	return indexes
end

-- Replaces the pet list (e.g. after deleting or combining pets). keep[i] is
-- true for pets to keep; `added` are new pet names to append. Equipped pets
-- that are kept stay equipped.
function PlayerData.rebuildPets(player, keep, added)
	local data = sessionData[player]
	if not data then
		return
	end
	local pets, newIndex = {}, {}
	for i, petName in ipairs(data.Pets) do
		if keep[i] then
			table.insert(pets, petName)
			newIndex[i] = #pets
		end
	end
	for _, petName in ipairs(added or {}) do
		table.insert(pets, petName)
		data.Index[petName] = true
	end
	local equipped = {}
	for _, i in ipairs(data.Equipped) do
		if newIndex[i] then
			table.insert(equipped, newIndex[i])
		end
	end
	data.Pets = pets
	data.Equipped = equipped
	PlayerData.Changed:Fire(player)
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

-- Counts down potion timers for everyone online (called once a second).
local function tickBoosts()
	for player, data in pairs(sessionData) do
		local expired = false
		for id, seconds in pairs(data.Boosts) do
			if seconds <= 1 then
				data.Boosts[id] = nil
				expired = true
			else
				data.Boosts[id] = seconds - 1
			end
		end
		if expired then
			PlayerData.Changed:Fire(player)
		end
	end
end

function PlayerData.start()
	task.spawn(function()
		while true do
			task.wait(1)
			tickBoosts()
		end
	end)

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
