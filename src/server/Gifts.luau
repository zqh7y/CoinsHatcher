-- Playtime gifts: free coins and diamonds after 1, 3, 5, 10, 15 and 20
-- minutes of play.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Gifts = {}

local joined = {} -- [player] = when they joined (os.clock)
local claimed = {} -- [player] = { [giftIndex] = true }

local function claim(player, giftIndex)
	local data = PlayerData.get(player)
	local minutes = Config.GIFT_TIMES[giftIndex]
	if not data or not minutes or not joined[player] then
		return false
	end
	if claimed[player][giftIndex] then
		return false, "You already opened this gift!"
	end
	if os.clock() - joined[player] < minutes * 60 then
		return false, "This gift isn't ready yet!"
	end

	claimed[player][giftIndex] = true
	local reward = Config.giftReward(giftIndex, data.Rebirths)
	local diamonds = Config.giftDiamonds(giftIndex)
	PlayerData.addCoins(player, reward)
	PlayerData.addDiamonds(player, diamonds)
	return true, ("🎁 You got %s coins and %d 💎!"):format(Config.formatNumber(reward), diamonds)
end

function Gifts.start(remotes)
	local function onPlayer(player)
		joined[player] = os.clock()
		claimed[player] = {}
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		joined[player] = nil
		claimed[player] = nil
	end)

	remotes.ClaimGift.OnServerInvoke = function(player, giftIndex)
		if typeof(giftIndex) ~= "number" then
			return false
		end
		return claim(player, giftIndex)
	end
end

return Gifts
