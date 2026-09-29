-- The token shop: the game is free to play, so nothing is sold for Robux.
-- Everyone earns Tokens just by playing (Config.TOKENS_PER_MINUTE) and spends
-- them on Exclusive Eggs and passes (Config.TOKEN_SHOP). Promo codes are
-- redeemed here too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Eggs = require(script.Parent.Eggs)

local TokenShop = {}


local productsByKey, passesByKey = {}, {}
for _, product in ipairs(Config.TOKEN_SHOP.Products) do
	productsByKey[product.Key] = product
end
for _, pass in ipairs(Config.TOKEN_SHOP.Passes) do
	passesByKey[pass.Key] = pass
end
passesByKey[Config.TOKEN_SHOP.All.Key] = Config.TOKEN_SHOP.All

-- Buys an Exclusive Egg pack or a pass with tokens. Returns ok, message.
local function buy(player, kind, key)
	local data = PlayerData.get(player)
	local item = if kind == "Product" then productsByKey[key] elseif kind == "Pass" then passesByKey[key] else nil
	if not data or not item then
		return false, "Still loading..."
	end
	if kind == "Pass" and Config.hasPass(data, key) then
		return false, "✅ You already own this!"
	end
	if data.Tokens < item.Price then
		local missing = item.Price - data.Tokens
		return false, ("%s You need %d more tokens (about %d min of play)"):format(Config.TOKEN_ICON, missing, math.ceil(missing / Config.TOKENS_PER_MINUTE))
	end
	PlayerData.addTokens(player, -item.Price)
	if kind == "Product" then
		Eggs.giveExclusive(player, item.Eggs)
		return true, ("💜 %d Exclusive Egg%s opened!"):format(item.Eggs, if item.Eggs > 1 then "s" else "")
	end
	data.Passes[item.Key] = true
	PlayerData.Changed:Fire(player)
	return true, "🎉 " .. item.Name .. " is yours forever!"
end

-- Promo codes (Config.CODES), each once per player.
local function redeem(player, code)
	local data = PlayerData.get(player)
	if not data then
		return false, "Still loading..."
	end
	code = string.upper((code:gsub("%s", "")))
	local info = Config.CODES[code]
	if not info then
		return false, "❌ That code doesn't exist"
	end
	if data.Codes[code] then
		return false, "✅ You already used this code"
	end
	data.Codes[code] = true
	for _, reward in ipairs(info.Rewards) do
		local kind = reward[1]
		if kind == "Diamonds" then
			PlayerData.addDiamonds(player, reward[2])
		elseif kind == "Tokens" then
			PlayerData.addTokens(player, reward[2])
		elseif kind == "AllPotions" then
			for _, boost in ipairs(Config.BOOSTS) do
				PlayerData.addBoost(player, boost.Id, reward[2] * 60)
			end
		elseif kind == "ExclusiveEggs" then
			Eggs.giveExclusive(player, reward[2])
		end
	end
	PlayerData.Changed:Fire(player)
	return true, "🎉 Code redeemed! " .. info.Text
end

function TokenShop.start(remotes)
	-- a token every minute you're in the game; the "NextToken" attribute (server
	-- time) lets the client show a countdown
	local nextToken = {}
	local seconds = 60 / Config.TOKENS_PER_MINUTE
	task.spawn(function()
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			for _, player in ipairs(Players:GetPlayers()) do
				if PlayerData.get(player) then
					if not nextToken[player] then
						nextToken[player] = now + seconds
						player:SetAttribute("NextToken", nextToken[player])
					elseif now >= nextToken[player] then
						PlayerData.addTokens(player, 1)
						nextToken[player] += seconds
						player:SetAttribute("NextToken", nextToken[player])
					end
				end
			end
		end
	end)

	local lastBuy, lastCode = {}, {}
	remotes.BuyTokenItem.OnServerInvoke = function(player, kind, key)
		if typeof(kind) ~= "string" or typeof(key) ~= "string" then
			return false, "Something went wrong"
		end
		local now = os.clock()
		if lastBuy[player] and now - lastBuy[player] < 0.5 then
			return false, "⏳ Slow down a little!"
		end
		lastBuy[player] = now
		return buy(player, kind, key)
	end

	remotes.RedeemCode.OnServerInvoke = function(player, code)
		if typeof(code) ~= "string" or #code > 40 then
			return false, "❌ That code doesn't exist"
		end
		local now = os.clock()
		if lastCode[player] and now - lastCode[player] < 1.5 then
			return false, "⏳ Slow down a little!"
		end
		lastCode[player] = now
		return redeem(player, code)
	end

	Players.PlayerRemoving:Connect(function(player)
		nextToken[player] = nil
		lastBuy[player] = nil
		lastCode[player] = nil
	end)
end

return TokenShop
