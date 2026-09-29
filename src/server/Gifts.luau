-- Playtime mystery gifts after 1, 3, 5, 10, 15 and 20 minutes of play. Each
-- one rolls a prize from Config.GIFT_POOLS: free hatches, potions, diamonds
-- or coins. The last one is a MEGA gift.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Eggs = require(script.Parent.Eggs)

local Gifts = {}

local joined = {} -- [player] = when they joined (os.clock)
local claimed = {} -- [player] = { [giftIndex] = true }

-- Gives one prize item; returns the text describing it.
local function give(player, data, item)
	local kind = item[1]
	if kind == "Diamonds" then
		PlayerData.addDiamonds(player, item[2])
		return item[2] .. " 💎"
	elseif kind == "Coins" then
		local coins = Config.giftCoins(item[2], data.Coins, data.Rebirths)
		PlayerData.addCoins(player, coins)
		return ("+%d%% coins (%s 💰)"):format(item[2], Config.formatNumber(coins))
	elseif kind == "Potion" then
		local boost = Config.BOOSTS_BY_ID[item[2]]
		PlayerData.addBoost(player, boost.Id, item[3] * 60)
		return ("🧪 %s (%d min)"):format(boost.Name, item[3])
	elseif kind == "AllPotions" then
		for _, boost in ipairs(Config.BOOSTS) do
			PlayerData.addBoost(player, boost.Id, item[2] * 60)
		end
		return ("🧪 ALL potions (%d min)"):format(item[2])
	elseif kind == "Hatch" then
		if Eggs.freeHatch(player, item[2]) then
			return ("🥚 %d free pet%s!"):format(item[2], if item[2] > 1 then "s" else "")
		end
		-- inventory full: diamonds instead
		PlayerData.addDiamonds(player, 100 * item[2])
		return ("%d 💎 (your pets are full!)"):format(100 * item[2])
	end
	return ""
end

local function claim(player, giftIndex)
	local data = PlayerData.get(player)
	local minutes = Config.GIFT_TIMES[giftIndex]
	local pool = Config.GIFT_POOLS[giftIndex]
	if not data or not minutes or not pool or not joined[player] then
		return false
	end
	if claimed[player][giftIndex] then
		return false, "You already opened this gift!"
	end
	if os.clock() - joined[player] < minutes * 60 then
		return false, "This gift isn't ready yet!"
	end

	claimed[player][giftIndex] = true
	local prize = pool[math.random(#pool)]
	local parts = {}
	for _, item in ipairs(prize) do
		table.insert(parts, give(player, data, item))
	end
	local text = table.concat(parts, " + ")
	return true, "🎁 " .. text, text
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
