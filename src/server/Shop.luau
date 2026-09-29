-- The merchant stall in the main area: stand on its circle to open the
-- Merchant (pets for diamonds) and the Diamond Shop (potions and perks).
-- Coin upgrades are bought in the upgrade tree (BuyUpgrade below).
-- Also applies walk speed to the player's character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PetModel = require(ReplicatedStorage.Shared.PetModel)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Coins = require(script.Parent.Coins)

local Shop = {}

-- Between the coin zone and the fence, facing the middle
Shop.POSITION = World.MAIN_CENTER + Vector3.new(-38, World.FLOOR_Y, 0)

local function part(model, origin, offset, size, color)
	return World.part({
		Size = size,
		CFrame = origin * offset,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
end

local function buildStall()
	local origin = CFrame.lookAt(Shop.POSITION, Vector3.new(World.MAIN_CENTER.X, Shop.POSITION.Y, World.MAIN_CENTER.Z))
	local model = Instance.new("Model")
	model.Name = "Shop"

	-- counter
	local counter = part(model, origin, CFrame.new(0, 1.5, -1), Vector3.new(10, 3, 3), Color3.fromRGB(200, 140, 90))
	part(model, origin, CFrame.new(0, 3.2, -1), Vector3.new(10.6, 0.4, 3.6), Color3.fromRGB(255, 245, 225))
	-- posts
	for _, x in ipairs({ -4.8, 4.8 }) do
		for _, z in ipairs({ -2.6, 3 }) do
			part(model, origin, CFrame.new(x, 4.5, z), Vector3.new(0.8, 9, 0.8), Color3.fromRGB(255, 250, 240))
		end
	end
	-- striped awning
	local stripes = 6
	local width = 10.8 / stripes
	for i = 1, stripes do
		local x = -5.4 + width * (i - 0.5)
		local color = if i % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(255, 110, 130)
		part(model, origin, CFrame.new(x, 9.3, 0.2) * CFrame.Angles(-0.15, 0, 0), Vector3.new(width, 0.4, 7.2), color)
	end
	-- goodies on the counter
	local boxColors = { Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 200, 70), Color3.fromRGB(180, 130, 255) }
	for i, x in ipairs({ -3.5, 3.2, 1.6 }) do
		part(model, origin, CFrame.new(x, 3.95, -1.2) * CFrame.Angles(0, i, 0), Vector3.new(1.1, 1.1, 1.1), boxColors[i])
	end

	-- a shopkeeper cat behind the counter
	local keeper = PetModel.build("Cat", { Anchored = true })
	keeper:PivotTo(origin * CFrame.new(0, 4.6, 1.2))
	keeper.Parent = model

	-- sign
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(200, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
	sign.MaxDistance = 150
	sign.Parent = counter
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "🐾 MERCHANT"
	text.TextColor3 = Color3.fromRGB(255, 220, 80)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(120, 60, 20)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Parent = sign

	-- a glowing circle in front of the stall: stand on it and the shop opens
	-- (the client watches for the part named "ShopPad")
	local padCenter = origin * CFrame.new(0, 0, -8)
	local function disc(name, height, width, y, color, material)
		return World.part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, width, width),
			CFrame = padCenter * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
	end
	disc("ShopRing", 0.12, 10, 0.06, Color3.fromRGB(255, 190, 50), Enum.Material.Neon)
	local pad = disc("ShopPad", 0.14, 8.8, 0.08, Color3.fromRGB(255, 250, 235))
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Shape = Enum.ParticleEmitterShape.Cylinder
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.EmissionDirection = Enum.NormalId.Right -- up, since the cylinder is turned
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1, 1.6)
	sparkles.Speed = NumberRange.new(2, 3)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 110))
	sparkles.Parent = pad

	model.PrimaryPart = counter
	model.Parent = workspace.MainArea
end

-- Walk speed ------------------------------------------------------------------

local function applyMovement(player)
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Config.walkSpeed(data.Upgrades)
	end
end

-- Buying ------------------------------------------------------------------------

-- Buys one level, or as many as you can afford when `max` is true.
local function buy(player, id, max)
	local data = PlayerData.get(player)
	local upgrade = Config.UPGRADES_BY_ID[id]
	if not data or not upgrade then
		return false, "Can't buy that."
	end
	local startLevel = data.Upgrades[id] or 0
	if startLevel >= upgrade.Max then
		return false, upgrade.Name .. " is maxed out!"
	end
	-- upgrade tree: a branch opens once the branch it grows from is far enough
	if not Config.upgradeUnlocked(data.Upgrades, upgrade) then
		local req = upgrade.Requires
		return false, ("Get %s to level %d first!"):format(Config.UPGRADES_BY_ID[req[1]].Name, req[2])
	end

	local level, spent = startLevel, 0
	repeat
		local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
		if data.Coins - spent < cost then
			break
		end
		spent += cost
		level += 1
	until not max or level >= upgrade.Max
	if level == startLevel then
		return false, "Not enough coins!"
	end

	PlayerData.addCoins(player, -spent)
	PlayerData.setUpgrade(player, id, level)
	if id == "MoreBreakables" then
		Coins.fill(player) -- spawn the extra ones now
	end
	local levels = level - startLevel
	return true, ("%s %s upgraded%s!"):format(upgrade.Icon, upgrade.Name, if levels > 1 then " x" .. levels else "")
end

-- Diamond shop: permanent perks and 2x potions.
local function buyPerk(player, id)
	local data = PlayerData.get(player)
	local perk = Config.PERKS_BY_ID[id]
	if not data or not perk then
		return false, "Can't buy that."
	end
	local level = data.Perks[id] or 0
	if level >= perk.Max then
		return false, perk.Name .. " is maxed out!"
	end
	local cost = Config.perkCost(perk, level)
	if data.Diamonds < cost then
		return false, "Not enough diamonds! 💎"
	end
	PlayerData.addDiamonds(player, -cost)
	PlayerData.setPerk(player, id, level + 1)
	return true, perk.Icon .. " " .. perk.Name .. " upgraded forever!"
end

local function buyBoost(player, id)
	local data = PlayerData.get(player)
	local boost = Config.BOOSTS_BY_ID[id]
	if not data or not boost then
		return false, "Can't buy that."
	end
	if (data.Boosts[id] or 0) + boost.Minutes * 60 > Config.BOOST_MAX_MINUTES * 60 then
		return false, "You already have the most time on this potion!"
	end
	if data.Diamonds < boost.Cost then
		return false, "Not enough diamonds! 💎"
	end
	PlayerData.addDiamonds(player, -boost.Cost)
	PlayerData.addBoost(player, id, boost.Minutes * 60)
	return true, "🧪 " .. boost.Name .. " for " .. boost.Minutes .. " more minutes!"
end

-- Merchant: buys one of the current offers (once per restock).
local function buyMerchant(player, slot)
	local data = PlayerData.get(player)
	if not data then
		return false, "Can't buy that."
	end
	local cycle = Config.merchantCycle(workspace:GetServerTimeNow())
	local offer = Config.merchantOffers(data, cycle)[slot]
	if not offer then
		return false, "Can't buy that."
	end
	-- what was already bought this restock
	if not data.Merchant or data.Merchant.Cycle ~= cycle then
		data.Merchant = { Cycle = cycle, Bought = {} }
	end
	local key = "s" .. slot
	if data.Merchant.Bought[key] then
		return false, "Sold out! New pets soon."
	end
	if #data.Pets >= Config.maxPets(data) then
		return false, "🎒 Your pet inventory is full! Delete some pets."
	end
	if data.Diamonds < offer.Price then
		return false, "Not enough diamonds! 💎"
	end
	data.Merchant.Bought[key] = true
	PlayerData.addDiamonds(player, -offer.Price)
	PlayerData.givePet(player, offer.Pet)
	return true, "🐾 You got a " .. offer.Pet .. "!"
end

-- Auto Buy (bought in the upgrade tree): keeps buying the cheapest upgrade
-- board level you can afford, while its switch on the board is on.
local function autoBuyTick()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(player)
		if data and (data.Upgrades.AutoBuy or 0) > 0 and data.AutoBuyOn ~= false then
			local bestId, bestCost = nil, math.huge
			for _, upgrade in ipairs(Config.AREA_UPGRADES) do
				local level = data.Upgrades[upgrade.Id] or 0
				if level < upgrade.Max then
					local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
					if cost < bestCost then
						bestId, bestCost = upgrade.Id, cost
					end
				end
			end
			if bestId and data.Coins >= bestCost then
				buy(player, bestId, false)
			end
		end
	end
end

function Shop.start(remotes)
	remotes.SetAutoBuy.OnServerInvoke = function(player, on)
		local data = PlayerData.get(player)
		if not data or typeof(on) ~= "boolean" or (data.Upgrades.AutoBuy or 0) == 0 then
			return false
		end
		data.AutoBuyOn = on
		PlayerData.Changed:Fire(player)
		return true
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			autoBuyTick()
		end
	end)

	remotes.BuyMerchant.OnServerInvoke = function(player, slot)
		if typeof(slot) ~= "number" then
			return false
		end
		return buyMerchant(player, slot)
	end

	buildStall()

	remotes.BuyPerk.OnServerInvoke = function(player, id)
		if typeof(id) ~= "string" then
			return false
		end
		return buyPerk(player, id)
	end
	remotes.BuyBoost.OnServerInvoke = function(player, id)
		if typeof(id) ~= "string" then
			return false
		end
		return buyBoost(player, id)
	end

	remotes.BuyUpgrade.OnServerInvoke = function(player, id, max)
		if typeof(id) ~= "string" then
			return false
		end
		return buy(player, id, max == true)
	end

	PlayerData.Changed.Event:Connect(applyMovement)

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			applyMovement(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return Shop
