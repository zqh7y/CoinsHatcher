local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local DEFAULT = {
	Coins = 0,
	Rebirths = 0,
	Pets = {},       -- list of pet names the player owns
	Equipped = {},   -- which of those are following them
}

local sessionData = {} -- [player] = data table while they're in game

local function load(player)
	local ok, saved = pcall(function()
		return store:GetAsync("user_" .. player.UserId)
	end)
	if not ok then
		warn("Load failed for", player.Name, saved)
	end

	local data = table.clone(DEFAULT)
	data.Pets = {}
	data.Equipped = {}
	if ok and saved then
		for k, v in pairs(saved) do
			data[k] = v
		end
	end
	sessionData[player] = data

	-- leaderstats shows Coins/Rebirths on the player list
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.Rebirths
	rebirths.Parent = stats

	-- keep the table in sync when other scripts change the values
	coins.Changed:Connect(function(v) data.Coins = v end)
	rebirths.Changed:Connect(function(v) data.Rebirths = v end)
end

local function save(player)
	local data = sessionData[player]
	if not data then return end
	local ok, err = pcall(function()
		store:SetAsync("user_" .. player.UserId, data)
	end)
	if not ok then
		warn("Save failed for", player.Name, err)
	end
end

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(player)
	save(player)
	sessionData[player] = nil
end)

-- save everyone if the server shuts down
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		save(player)
	end
end)
