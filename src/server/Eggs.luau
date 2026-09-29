-- The eggs in the hatchery. Walk up to one: the popup shows its pets, and
-- E / F / T (or the popup's buttons) hatch 1, 3 or auto.
-- Egg N unlocks at rebirth N-1; the Release egg (open for all) stands in the
-- main area.
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
		-- event eggs stand in the main area (see World.RELEASE_ANGLE)
		local a = math.rad(World.RELEASE_ANGLE)
		return World.MAIN_CENTER + Vector3.new(math.cos(a) * World.RELEASE_DIST, World.FLOOR_Y, math.sin(a) * World.RELEASE_DIST)
	end
	return World.EGG_CENTER + Vector3.new(hall.EggX, World.FLOOR_Y, hall.FirstEggZ - (eggIndex - 1) * hall.EggSpacing)
end

function Eggs.outward(eggIndex)
	if Config.EGGS[eggIndex].Release then
		-- away from the middle of the main area
		local a = math.rad(World.RELEASE_ANGLE)
		return Vector3.new(math.cos(a), 0, math.sin(a))
	end
	return Vector3.new(1, 0, 0)
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

-- Should this freshly hatched pet be deleted right away? (The player picked
-- it for auto-delete in the egg popup; its Shiny/Rainbow/Galaxy versions go
-- too.)
local function autoDeleted(data, petName)
	local info = Config.PETS[petName]
	local base = info and info.Base or petName
	return data.AutoDelete ~= nil and data.AutoDelete[base] == true
end

-- Gives hatched pets to the player: diamonds for new discoveries, auto-delete,
-- auto-equip into free slots, the hatch animation and a server-wide shout-out
-- for rare ones. No cost or distance checks here.
local function giveHatch(player, names)
	local data = PlayerData.get(player)
	if not data then
		return
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

	local deleted = {}
	for i, petName in ipairs(names) do
		deleted[i] = autoDeleted(data, petName)
	end
	local indexes = PlayerData.addPets(player, names, deleted)
	if reward > 0 then
		PlayerData.addDiamonds(player, reward)
		notify(player, "📖 New pet discovered! +" .. reward .. " 💎", Color3.fromRGB(130, 220, 255), true)
	end

	-- auto-equip into free slots
	local max = Config.totalSlots(data)
	if #data.Equipped < max and #indexes > 0 then
		local equipped = table.clone(data.Equipped)
		for _, index in ipairs(indexes) do
			if #equipped < max then
				table.insert(equipped, index)
			end
		end
		PlayerData.setEquipped(player, equipped)
	end

	remotes.Hatched:FireClient(player, names, deleted)

	-- let the whole server know about rare hatches
	for _, petName in ipairs(names) do
		if Config.isRare(petName) then
			remotes.Announce:FireAllClients(player.DisplayName, petName)
		end
	end
end

-- How many of these pets would actually go into the inventory.
local function keptCount(data, names)
	local kept = 0
	for _, petName in ipairs(names) do
		if not autoDeleted(data, petName) then
			kept += 1
		end
	end
	return kept
end

local function roll(eggIndex, data, count)
	local names = {}
	for _ = 1, count do
		table.insert(names, Config.rollHatch(eggIndex, data))
	end
	return names
end

-- Free pets (from gifts) out of the best egg the player has unlocked.
-- Returns false if their inventory is too full.
function Eggs.freeHatch(player, count)
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local names = roll(math.min(data.Rebirths + 1, Config.REBIRTH_EGGS), data, count)
	if #data.Pets + keptCount(data, names) > Config.maxPets(data) then
		return false
	end
	giveHatch(player, names)
	return true
end

-- Gives one special pet (the gift huge) with the hatch animation.
function Eggs.giveSpecial(player, petName)
	giveHatch(player, { petName })
end

-- Opens Exclusive Eggs (bought with tokens or from a code). They always go in,
-- even if the inventory is full.
function Eggs.giveExclusive(player, count)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local names = {}
	for _ = 1, count do
		table.insert(names, Config.rollExclusive(data))
	end
	giveHatch(player, names)
end

-- Hatches `count` eggs (1 up to the Hatch Amount) at once, paying with coins.
local function hatch(player, eggIndex, count)
	local data = PlayerData.get(player)
	if not data or not eggModels[eggIndex] then
		return
	end
	local now = os.clock()
	if lastHatch[player] and now - lastHatch[player] < HATCH_COOLDOWN / Config.totalHatchSpeed(data) then
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
	local cost = Config.eggPrice(data, eggIndex) * count
	if data.Coins < cost then
		notify(player, "💰 You need " .. Config.formatNumber(cost) .. " coins!", RED)
		return
	end
	-- roll first: auto-deleted pets don't need room in the inventory
	local names = roll(eggIndex, data, count)
	if #data.Pets + keptCount(data, names) > Config.maxPets(data) then
		notify(player, "🎒 Your pet inventory is full! Delete some pets.", RED)
		return
	end

	lastHatch[player] = now
	PlayerData.addCoins(player, -cost)
	giveHatch(player, names)
end

-- Turns auto-delete on or off for one pet of an egg. Only normal pets up to
-- Legendary can be auto-deleted (never Mythical or Huge ones).
local AUTO_DELETABLE = { Common = true, Uncommon = true, Rare = true, Legendary = true }
local function setAutoDelete(player, petName, on)
	local data = PlayerData.get(player)
	local info = Config.PETS[petName]
	if not data or not info or info.Mutation or not AUTO_DELETABLE[info.Rarity] then
		return false
	end
	data.AutoDelete = data.AutoDelete or {}
	data.AutoDelete[petName] = if on then true else nil
	PlayerData.Changed:Fire(player)
	return true
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
	model:SetAttribute("Front", -Eggs.outward(eggIndex)) -- the side facing the players

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
		if typeof(eggIndex) ~= "number" or typeof(count) ~= "number" or count ~= math.floor(count) or count < 1 then
			return
		end
		-- 1, or up to the player's Hatch Amount
		local data = PlayerData.get(player)
		if not data or (count ~= 1 and count > Config.totalHatchAmount(data)) then
			return
		end
		hatch(player, eggIndex, count)
	end)

	-- tapping a pet in the egg popup toggles auto-delete for it
	remotes.SetAutoDelete.OnServerInvoke = function(player, petName, on)
		if typeof(petName) ~= "string" or typeof(on) ~= "boolean" then
			return false
		end
		return setAutoDelete(player, petName, on)
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastHatch[player] = nil
	end)
end

return Eggs
