-- The shop stall in the main area: buy upgrades (damage, luck, speed, ...).
-- Also applies walk speed and the hoverboard to the player's character.
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

local riding = {} -- [player] = true while on the hoverboard

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
	text.Text = "🛒 SHOP"
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

-- Walk speed + hoverboard -------------------------------------------------------

local BOARD_WHITE = Color3.fromRGB(245, 247, 252)
local BOARD_CYAN = Color3.fromRGB(70, 220, 255)
local BOARD_PINK = Color3.fromRGB(255, 90, 210)

-- A sleek hoverboard: white deck with rounded ends, dark grip, glowing neon
-- strips and underglow, twin rear thrusters with flames, light trails and
-- hover dust. The deck hangs from the player's root on a Weld called
-- "BoardWeld" so the client can make it bob and lean into turns.
local function buildHoverboard(root, offset)
	local model = Instance.new("Model")
	model.Name = "Hoverboard"

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(2.4, 0.3, 5)
	deck.Color = BOARD_WHITE
	deck.Material = Enum.Material.SmoothPlastic
	deck.Reflectance = 0.15
	deck.CanCollide = false
	deck.Massless = true
	deck.CFrame = root.CFrame * offset
	deck.Parent = model
	model.PrimaryPart = deck

	local weld = Instance.new("Weld")
	weld.Name = "BoardWeld"
	weld.Part0 = root
	weld.Part1 = deck
	weld.C0 = offset
	weld.Parent = deck

	local function add(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = deck.CFrame * cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = deck
		w.Part1 = p
		w.Parent = p
		p.Parent = model
		return p
	end
	local standUp = CFrame.Angles(0, 0, math.rad(90))
	-- rounded nose and tail
	for _, z in ipairs({ -2.5, 2.5 }) do
		add("DeckEnd", Vector3.new(0.3, 2.4, 2.4), CFrame.new(0, 0, z) * standUp, BOARD_WHITE, nil, Enum.PartType.Cylinder)
	end
	add("Grip", Vector3.new(2, 0.06, 4.6), CFrame.new(0, 0.17, 0), Color3.fromRGB(40, 42, 55))
	-- neon edge lines and underglow
	for _, x in ipairs({ -1.18, 1.18 }) do
		add("EdgeGlow", Vector3.new(0.1, 0.12, 5), CFrame.new(x, 0, 0), BOARD_CYAN, Enum.Material.Neon)
	end
	local under = add("UnderGlow", Vector3.new(1.8, 0.08, 4.6), CFrame.new(0, -0.19, 0), BOARD_PINK, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = BOARD_PINK
	light.Range = 10
	light.Brightness = 2
	light.Parent = under

	-- hover dust drifting down from under the board
	local dust = Instance.new("ParticleEmitter")
	dust.EmissionDirection = Enum.NormalId.Bottom
	dust.Rate = 25
	dust.Lifetime = NumberRange.new(0.3, 0.5)
	dust.Speed = NumberRange.new(3, 5)
	dust.SpreadAngle = Vector2.new(25, 25)
	dust.LightEmission = 1
	dust.Size = NumberSequence.new(0.25, 0)
	dust.Color = ColorSequence.new(BOARD_PINK, BOARD_CYAN)
	dust.Parent = under

	-- twin thrusters at the back with flames
	for _, x in ipairs({ -0.65, 0.65 }) do
		local thruster = add(
			"Thruster",
			Vector3.new(1.1, 0.6, 0.6),
			CFrame.new(x, 0.05, 2.9) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(60, 64, 80),
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		local nozzle = Instance.new("Attachment")
		nozzle.Position = Vector3.new(-0.6, 0, 0) -- the back end of the cylinder
		nozzle.Parent = thruster
		local flame = Instance.new("ParticleEmitter")
		flame.EmissionDirection = Enum.NormalId.Left
		flame.Rate = 40
		flame.Lifetime = NumberRange.new(0.15, 0.25)
		flame.Speed = NumberRange.new(6, 9)
		flame.LightEmission = 1
		flame.Size = NumberSequence.new(0.4, 0)
		flame.Color = ColorSequence.new(BOARD_CYAN, Color3.new(1, 1, 1))
		flame.Parent = nozzle
	end

	-- light trails from both back corners
	for _, x in ipairs({ -1.1, 1.1 }) do
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(x, 0.12, 2.5)
		a0.Parent = deck
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(x, -0.12, 2.5)
		a1.Parent = deck
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(BOARD_CYAN, BOARD_PINK)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = deck
	end

	return model
end

local function applyMovement(player)
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not humanoid or not root then
		return
	end

	if (data.Upgrades.Hoverboard or 0) == 0 then
		riding[player] = nil
	end
	local ride = riding[player] == true
	humanoid.WalkSpeed = Config.walkSpeed(data.Upgrades) + (if ride then Config.HOVERBOARD_SPEED else 0)

	local baseHip = humanoid:GetAttribute("BaseHipHeight")
	if not baseHip then
		baseHip = humanoid.HipHeight
		humanoid:SetAttribute("BaseHipHeight", baseHip)
	end

	local board = character:FindFirstChild("Hoverboard")
	if ride and not board then
		-- how far below the root part the feet are
		local feet = if humanoid.RigType == Enum.HumanoidRigType.R15 then root.Size.Y / 2 + baseHip else 3
		board = buildHoverboard(root, CFrame.new(0, -feet - 0.25, 0))
		board.Parent = character
		humanoid.HipHeight = baseHip + 1.2 -- hover above the ground
	elseif not ride and board then
		board:Destroy()
		humanoid.HipHeight = baseHip
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
	if id == "Hoverboard" then
		riding[player] = true -- hop on right away
	end
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

function Shop.start(remotes)
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

	remotes.ToggleHoverboard.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if data and (data.Upgrades.Hoverboard or 0) > 0 then
			riding[player] = not riding[player] or nil
			applyMovement(player)
		end
	end)

	PlayerData.Changed.Event:Connect(applyMovement)

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			character:WaitForChild("HumanoidRootPart")
			riding[player] = nil -- respawning drops you off the board
			applyMovement(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
	end)
end

return Shop
