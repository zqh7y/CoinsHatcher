-- Egg stands in the egg area. Walk up and press E (or use the popup buttons)
-- to hatch 1 or 3 eggs.
-- Egg N unlocks at rebirth N-1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggModel = require(ReplicatedStorage.Shared.EggModel)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Shrines = require(script.Parent.Shrines)

local Eggs = {}

-- Eggs stand in a ring around the hatchery: 12 slots of 30 degrees with the
-- slot at the gate left open. Egg 1 is just left of the gate and they go
-- around to the last egg on its right.
local RING_RADIUS = 34

-- Floor position of egg N (same layout as default.project.json).
function Eggs.position(eggIndex)
	local angle = math.rad(90 + 30 * eggIndex)
	return World.EGG_CENTER + Vector3.new(math.cos(angle) * RING_RADIUS, World.FLOOR_Y, math.sin(angle) * RING_RADIUS)
end

local remotes
local eggModels = {} -- [eggIndex] = model, to check the player is close enough
local lastHatch = {} -- [player] = time, so hatching can't be spammed
local HATCH_COOLDOWN = 0.8
local MAX_DISTANCE = 20 -- how close you must be to hatch

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
	giveHatch(player, math.min(data.Rebirths + 1, Config.EGG_COUNT), count)
	return true
end

-- Hatches `count` eggs (1 or 3) at once, paying with coins.
local function hatch(player, eggIndex, count)
	local data = PlayerData.get(player)
	local model = eggModels[eggIndex]
	if not data or not model then
		return
	end
	local now = os.clock()
	if lastHatch[player] and now - lastHatch[player] < HATCH_COOLDOWN then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - model:GetPivot().Position).Magnitude > MAX_DISTANCE then
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
	local cost = Config.eggCost(eggIndex) * count
	if data.Coins < cost then
		notify(player, "💰 You need " .. Config.formatNumber(cost) .. " coins!", RED)
		return
	end

	lastHatch[player] = now
	PlayerData.addCoins(player, -cost)
	giveHatch(player, eggIndex, count)
end

-- Creates the pedestal + egg for an egg that isn't in the project file.
local function createEggModel(eggIndex, parent)
	local egg = Config.EGGS[eggIndex]
	local base = Eggs.position(eggIndex)
	local soft = egg.Color:Lerp(Color3.new(1, 1, 1), 0.55)

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
	cylinder("Pedestal", 1.2, 10, 0.6, soft)
	cylinder("Glow", 0.3, 10.5, 0.7, egg.Color, Enum.Material.Neon)
	cylinder("Top", 1, 7.5, 1.7, Color3.fromRGB(255, 250, 245))

	local shell = World.part({
		Name = "Egg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		Position = base + Vector3.new(0, 5.65, 0),
		Color = egg.Color,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Parent = model,
	})

	-- make it egg-shaped
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
	mesh.Parent = shell

	local light = Instance.new("PointLight")
	light.Color = egg.Color
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = shell

	model.Parent = parent
	return model
end

-- Eggs are placed in default.project.json (so you can move them in Studio).
-- This adds the sign and hatch prompt, and creates any egg that's missing.
local function setupEgg(eggIndex, parent)
	local egg = Config.EGGS[eggIndex]
	local model = parent:FindFirstChild(egg.Name) or createEggModel(eggIndex, parent)
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

	-- themed shrine around the pedestal, name plaque and lock dome
	Shrines.build(model, eggIndex, Eggs.position(eggIndex))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.Name
	prompt.MaxActivationDistance = 9 -- eggs are ~14 studs apart, so only one prompt shows
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player)
		hatch(player, eggIndex, 1)
	end)
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

	for eggIndex = 1, Config.EGG_COUNT do
		setupEgg(eggIndex, eggsFolder)
	end

	-- the egg popup's Hatch 1 / Hatch 3 / Auto buttons
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
