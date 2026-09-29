-- The Robux shop: Exclusive Eggs (developer products), gamepasses and promo
-- codes. The ids are in Config.ROBUX; an item with Id = 0 isn't made yet:
-- in Studio its button gives it for free (to test), in the live game it's off.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Eggs = require(script.Parent.Eggs)

local Robux = {}

local remotes
local GREEN = Color3.fromRGB(90, 210, 110)
local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 200, 60)

local function notify(player, message, color, celebrate)
	remotes.Notify:FireClient(player, message, color, celebrate)
end

local productsById, productsByKey = {}, {}
for _, product in ipairs(Config.ROBUX.Products) do
	productsByKey[product.Key] = product
	if product.Id ~= 0 then
		productsById[product.Id] = product
	end
end
local passes = table.clone(Config.ROBUX.Passes)
table.insert(passes, Config.ROBUX.All)
local passesByKey, passesById = {}, {}
for _, pass in ipairs(passes) do
	passesByKey[pass.Key] = pass
	if pass.Id ~= 0 then
		passesById[pass.Id] = pass
	end
end

local function givePass(player, pass)
	local data = PlayerData.get(player)
	if not data or data.Passes[pass.Key] then
		return
	end
	data.Passes[pass.Key] = true
	PlayerData.Changed:Fire(player)
end

-- Gamepasses are checked with Roblox every time you join (and kept in the
-- save, so a Roblox hiccup never takes one away).
local function checkPasses(player)
	local data = PlayerData.waitFor(player)
	if not data then
		return
	end
	local changed = false
	for _, pass in ipairs(passes) do
		if pass.Id ~= 0 and not data.Passes[pass.Key] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				data.Passes[pass.Key] = true
				changed = true
			end
		end
	end
	if changed then
		PlayerData.Changed:Fire(player)
	end
end

-- Old receipts are forgotten after a week (Roblox only retries for 3 days).
local function trimReceipts(data)
	local now = os.time()
	for id, time in pairs(data.Receipts) do
		if now - time > 7 * 24 * 3600 then
			data.Receipts[id] = nil
		end
	end
end

-- Robux purchases of developer products (the Exclusive Eggs). Only reports
-- "granted" once the pets are safely saved, so nobody pays for nothing.
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = productsById[receipt.ProductId]
	if not player or not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerData.waitFor(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Receipts[receipt.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already given
	end

	Eggs.giveExclusive(player, product.Eggs)
	data.Receipts[receipt.PurchaseId] = os.time()
	trimReceipts(data)
	notify(player, ("💜 Thank you! %d Exclusive Egg%s opened!"):format(product.Eggs, if product.Eggs > 1 then "s" else ""), GOLD, true)
	if not PlayerData.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- A shop button: shows Roblox's purchase window (or gives it free in Studio
-- while the item isn't made yet).
local function buy(player, kind, key)
	local item = if kind == "Product" then productsByKey[key] elseif kind == "Pass" then passesByKey[key] else nil
	local data = PlayerData.get(player)
	if not item or not data then
		return
	end
	if kind == "Pass" and Config.hasPass(data, key) then
		notify(player, "✅ You already own this!", GREEN)
		return
	end
	if item.Id == 0 then
		if RunService:IsStudio() then
			-- test purchase: nothing is charged
			if kind == "Product" then
				Eggs.giveExclusive(player, item.Eggs)
			else
				givePass(player, item)
			end
			notify(player, "🧪 Studio test purchase (free)", GOLD)
		else
			notify(player, "🛒 Coming soon!", GOLD)
		end
		return
	end
	if kind == "Product" then
		MarketplaceService:PromptProductPurchase(player, item.Id)
	else
		MarketplaceService:PromptGamePassPurchase(player, item.Id)
	end
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

function Robux.start(remoteFolder)
	remotes = remoteFolder

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passesById[passId]
		if purchased and pass then
			givePass(player, pass)
			notify(player, "💜 Thank you! " .. pass.Name .. " is yours forever!", GOLD, true)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		checkPasses(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(checkPasses, player)
	end

	local lastBuy = {}
	remotes.BuyRobux.OnServerEvent:Connect(function(player, kind, key)
		if typeof(kind) ~= "string" or typeof(key) ~= "string" then
			return
		end
		local now = os.clock()
		if lastBuy[player] and now - lastBuy[player] < 1 then
			return
		end
		lastBuy[player] = now
		buy(player, kind, key)
	end)

	local lastCode = {}
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
		lastBuy[player] = nil
		lastCode[player] = nil
	end)
end

return Robux
