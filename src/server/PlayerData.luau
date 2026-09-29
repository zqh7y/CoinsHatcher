-- Loads, saves and changes player data. Other server modules go through here.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	AutoDelete = {}, -- [pet name] = true: hatched copies are deleted right away
	Guide = 1, -- step of the new-player guide (0 = finished or skipped)
	Rarest = nil, -- { Pet = name, Odds = N } the rarest pet ever hatched (1 in N)
	Passes = {}, -- [pass key] = true for owned gamepasses (see Config.ROBUX)
	Codes = {}, -- [code] = true for promo codes already redeemed
	Receipts = {}, -- [purchase id] = time, Robux purchases already given
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
	data.AutoDelete = {}
	data.Boosts = {}
	data.Passes = {}
	data.Codes = {}
	data.Receipts = {}
	if ok and saved then
		for k, v in pairs(saved) do
			data[k] = v
		end
	end
	-- older saves: drop upgrades that aren't sold any more (their levels would
	-- otherwise keep giving hidden bonuses)
	for id in pairs(data.Upgrades) do
		if not Config.UPGRADES_BY_ID[id] then
			data.Upgrades[id] = nil
		end
	end

	-- older saves: players who already hatched something don't need the guide
	if ok and saved and saved.Guide == nil then
		data.Guide = if (data.Hatched or 0) > 0 then 0 else 1
	end

	-- older saves: fill in the index from the pets they already own
	for _, petName in ipairs(data.Pets) do
		data.Index[petName] = true
		local info = Config.PETS[petName]
		if info and info.Base then
			data.Index[info.Base] = true
		end
	end

	-- new players pick their first pet (Dog or Cat) when they join
	data.NeedsStarter = #data.Pets == 0 or nil

	-- developer test money (Studio, or user ids in Config.DEV_MONEY)
	if PlayerData.isDev(player) then
		data.Coins = math.max(data.Coins, Config.DEV_MONEY.Coins)
		data.Diamonds = math.max(data.Diamonds, Config.DEV_MONEY.Diamonds)
		-- huge pets to look at (once each)
		for _, huge in ipairs(Config.DEV_MONEY.Huges or {}) do
			if Config.PETS[huge] and not table.find(data.Pets, huge) then
				table.insert(data.Pets, huge)
				data.Index[huge] = true
			end
		end
		player:SetAttribute("Dev", true) -- the client shows free rebirths
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

local function save(player): boolean
	local data = sessionData[player]
	if not data or loadFailed[player] then
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync("user_" .. player.UserId, data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
	return ok
end

-- Saves right away (after a Robux purchase). Returns true if it worked.
function PlayerData.saveNow(player): boolean
	return save(player)
end

-- Developers (in Studio, or user ids in Config.DEV_MONEY) get test money and
-- free rebirths.
function PlayerData.isDev(player)
	local dev = Config.DEV_MONEY
	return dev.Enabled and (RunService:IsStudio() or table.find(dev.UserIds, player.UserId) ~= nil)
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

-- Rebirth resets coins and the upgrade board. Shop upgrades, pets, the
-- index, diamonds, perks and potions are kept.
function PlayerData.rebirth(player)
	local data = sessionData[player]
	if not data then
		return
	end
	data.Coins = 0
	data.Rebirths += 1
	local kept = {}
	for _, upgrade in ipairs(Config.UPGRADES) do
		kept[upgrade.Id] = data.Upgrades[upgrade.Id]
	end
	data.Upgrades = kept
	showCoins(player, data.Coins)
	setStat(player, "Rebirths", data.Rebirths)
	PlayerData.Changed:Fire(player)
end

-- Gives a new player the starter pet they picked (only once).
function PlayerData.giveStarter(player, petName)
	local data = sessionData[player]
	if not data or not data.NeedsStarter or not table.find(Config.STARTER_CHOICES, petName) then
		return false
	end
	data.NeedsStarter = nil
	table.insert(data.Pets, petName)
	data.Equipped = { #data.Pets }
	data.Index[petName] = true
	PlayerData.Changed:Fire(player)
	return true
end

-- Gives one pet that wasn't hatched (bought from the merchant): it goes into
-- the inventory and the index, but doesn't count as a hatch.
function PlayerData.givePet(player, petName)
	local data = sessionData[player]
	if not data then
		return
	end
	table.insert(data.Pets, petName)
	data.Index[petName] = true
	local info = Config.PETS[petName]
	if info and info.Base then
		data.Index[info.Base] = true
	end
	PlayerData.Changed:Fire(player)
end

-- Adds hatched pets. `deleted[i]` = true for pets that are auto-deleted: they
-- still count as found and hatched, but don't go into the inventory.
-- Returns the new pets' indexes.
function PlayerData.addPets(player, petNames, deleted)
	local data = sessionData[player]
	if not data then
		return {}
	end
	local indexes = {}
	for i, petName in ipairs(petNames) do
		if not (deleted and deleted[i]) then
			table.insert(data.Pets, petName)
			table.insert(indexes, #data.Pets)
		end
		data.Index[petName] = true
		-- a mutated pet ("Shiny Dog") also counts as finding the normal one
		local info = Config.PETS[petName]
		if info and info.Base then
			data.Index[info.Base] = true
		end
		-- remember the rarest hatch for the leaderboard
		local odds = Config.odds(petName)
		if odds and (not data.Rarest or odds > data.Rarest.Odds) then
			data.Rarest = { Pet = petName, Odds = odds }
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
