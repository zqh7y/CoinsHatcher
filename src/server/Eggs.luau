-- The eggs in the hatchery. Walk up to one: the popup shows its pets, and
-- E / F / T (or the popup's buttons) hatch 1, 3 or auto.
-- Egg N unlocks at rebirth N-1; the Release egg at the end is open for all.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggModel = require(ReplicatedStorage.Shared.EggModel)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Shrines = require(script.Parent.Shrines)

local Eggs = {}

-- The eggs stand along the hall's right side, one every EggSpacing studs
-- from the gate end; the Release egg sits across the far end (see World.HALL).
function Eggs.position(eggIndex)
	local hall = World.HALL
	if Config.EGGS[eggIndex].Release then
		return World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y, hall.ReleaseZ)
	end
	return World.EGG_CENTER + Vector3.new(hall.EggX, World.FLOOR_Y, hall.FirstEggZ - (eggIndex - 1) * hall.EggSpacing)
end

function Eggs.outward(eggIndex)
	return if Config.EGGS[eggIndex].Release then Vector3.new(0, 0, -1) else Vector3.new(1, 0, 0)
end

local remotes
local eggModels = {} -- [eggIndex] = model, to check the player is close enough
local lastHatch = {} -- [player] = time, so hatching can't be spammed
local HATCH_COOLDOWN = 0.8
local MAX_DISTANCE = 22 -- how close you must be to hatch

local RED = Color3.fromRGB(255, 90, 90)

local function notify(player, message, color, celebrate)
	remotes.Notify:FireClient(player, message, color, celebrate)
end

-- Rolls `count` pets from an egg and gives them to the player: diamonds for
-- new discoveries, auto-equip into free slots, the hatch animation and a
-- server-wide shout-out for rare ones. No cost or distance checks here.
local function giveHatch(player, eggIndex, count)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local names = {}
	for _ = 1, count do
		table.insert(names, Config.rollHatch(eggIndex, data))
	end

	-- diamonds for pets you've never found before (checked before adding them)
	local reward, found = 0, {}
	for _, petName in ipairs(names) do
		local info = Config.PETS[petName]
		local base = info.Base or petName
		if not data.Index[base] and not found[base] then
			found[base] = true
			reward += if info.Rarity == "Huge" then Config.DIAMONDS_NEW_HUGE else Config.DIAMONDS_NEW_PET
		end
	end

	local indexes = PlayerData.addPets(player, names)
	if reward > 0 then
		PlayerData.addDiamonds(player, reward)
		notify(player, "📖 New pet discovered! +" .. reward .. " 💎", Color3.fromRGB(130, 220, 255), true)
	end

	-- auto-equip into free slots
	local max = Config.totalSlots(data)
	if #data.Equipped < max then
		local equipped = table.clone(data.Equipped)
		for _, index in ipairs(indexes) do
			if #equipped < max then
				table.insert(equipped, index)
			end
		end
		PlayerData.setEquipped(player, equipped)
	end

	remotes.Hatched:FireClient(player, names)

	-- let the whole server know about rare hatches
	for _, petName in ipairs(names) do
		if Config.isRare(petName) then
			remotes.Announce:FireAllClients(player.DisplayName, petName)
		end
	end
end

-- Free pets (from gifts) out of the best egg the player has unlocked.
-- Returns false if their inventory is too full.
function Eggs.freeHatch(player, count)
	local data = PlayerData.get(player)
	if not data or #data.Pets + count > Config.maxPets(data) then
		return false
	end
	giveHatch(player, math.min(data.Rebirths + 1, Config.REBIRTH_EGGS), count)
	return true
end

-- Hatches `count` eggs (1 or 3) at once, paying with coins.
local function hatch(player, eggIndex, count)
	local data = PlayerData.get(player)
	if not data or not eggModels[eggIndex] then
		return
	end
	local now = os.clock()
	if lastHatch[player] and now - lastHatch[player] < HATCH_COOLDOWN then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - Eggs.position(eggIndex)).Magnitude > MAX_DISTANCE then
		return
	end

	local required = Config.eggRequiredRebirths(eggIndex)
	if data.Rebirths < required then
		notify(player, "🔒 Rebirth " .. required .. " needed to open this egg!", RED)
		return
	end
	if #data.Pets + count > Config.maxPets(data) then
		notify(player, "🎒 Your pet inventory is full! Delete some pets.", RED)
		return
	end
	local cost = Config.eggPrice(data, eggIndex) * count
	if data.Coins < cost then
		notify(player, "💰 You need " .. Config.formatNumber(cost) .. " coins!", RED)
		return
	end

	lastHatch[player] = now
	PlayerData.addCoins(player, -cost)
	giveHatch(player, eggIndex, count)
end

-- Builds an egg stand: a tiered pedestal with a gold rim and a glowing ring,
-- the decorated egg floating on top, a soft light beam and sparkles. Parts named Glow / Top / Egg are used by the client.
local function createEggModel(eggIndex, parent)
	local egg = Config.EGGS[eggIndex]
	local base = Eggs.position(eggIndex)
	local soft = egg.Color:Lerp(Color3.new(1, 1, 1), 0.55)
	local gold = Color3.fromRGB(255, 205, 70)
	local big = egg.Release -- the Release egg gets a bigger stand

	local model = Instance.new("Model")
	model.Name = egg.Name

	local function cylinder(name, height, width, y, color, material)
		return World.part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, width, width),
			CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end
	local w = if big then 1.25 else 1
	cylinder("Pedestal", 0.8, 9 * w, 0.4, soft)
	cylinder("Rim", 0.25, 9.3 * w, 0.85, gold)
	cylinder("Glow", 0.3, 8.2 * w, 1.1, egg.Color, Enum.Material.Neon)
	cylinder("Middle", 0.8, 7.4 * w, 1.6, Color3.fromRGB(255, 250, 245))
	cylinder("Top", 0.5, 6 * w, 2.25, soft)
	cylinder("TopRim", 0.15, 6.2 * w, 2.55, gold)

	local eggSize = if big then 7.5 else 6
	local shell = World.part({
		Name = "Egg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * eggSize,
		Position = base + Vector3.new(0, 2.7 + eggSize * 0.58 + 0.4, 0),
		Color = egg.Color,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		CanCollide = false,
		Parent = model,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = EggModel.SHAPE
	mesh.Parent = shell

	local light = Instance.new("PointLight")
	light.Color = egg.Color
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = shell

	-- a soft beam of light going up from the pedestal
	World.part({
		Name = "Beam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 5 * w, 5 * w),
		CFrame = CFrame.new(base + Vector3.new(0, 2.6 + 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = egg.Color:Lerp(Color3.new(1, 1, 1), 0.4),
		Material = Enum.Material.Neon,
		Transparency = 0.92,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Shape = Enum.ParticleEmitterShape.Sphere
	sparkles.Rate = 4
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(0.6, 1.4)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Color = ColorSequence.new(egg.Color:Lerp(Color3.new(1, 1, 1), 0.3), Color3.new(1, 1, 1))
	sparkles.Parent = shell

	model.Parent = parent
	return model
end

-- Builds each egg with its stand, pattern, platform and attributes.
local function setupEgg(eggIndex, parent)
	local egg = Config.EGGS[eggIndex]
	local model = createEggModel(eggIndex, parent)
	local shell = model:FindFirstChild("Egg")
	if not shell then
		warn(egg.Name .. " needs a part named Egg inside it")
		return
	end
	model.PrimaryPart = shell
	model:SetAttribute("EggIndex", eggIndex)
	model:SetAttribute("RequiredRebirths", Config.eggRequiredRebirths(eggIndex))

	-- the egg's pattern and shine (the client bobs these along with the egg)
	shell.Color = EggModel.shellColor(eggIndex)
	local look = Instance.new("Folder")
	look.Name = "EggLook"
	look.Parent = model
	EggModel.decorate(shell, eggIndex, look)

	-- themed decorations around the stand
	Shrines.build(model, eggIndex, Eggs.position(eggIndex), Eggs.outward(eggIndex))

	eggModels[eggIndex] = model
end

function Eggs.start(remoteFolder)
	remotes = remoteFolder

	local eggsFolder = workspace.EggArea:FindFirstChild("Eggs")
	if not eggsFolder then
		eggsFolder = Instance.new("Folder")
		eggsFolder.Name = "Eggs"
		eggsFolder.Parent = workspace.EggArea
	end

	-- always build the eggs fresh in the hall (older place files still have
	-- the eggs from the round hatchery saved in them)
	eggsFolder:ClearAllChildren()
	for eggIndex = 1, Config.EGG_COUNT do
		setupEgg(eggIndex, eggsFolder)
	end

	-- E / F / T and the popup's buttons (auto sends 1 or 3 over and over)
	remotes.Hatch.OnServerEvent:Connect(function(player, eggIndex, count)
		if typeof(eggIndex) ~= "number" or (count ~= 1 and count ~= 3) then
			return
		end
		hatch(player, eggIndex, count)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastHatch[player] = nil
	end)
end

return Eggs
