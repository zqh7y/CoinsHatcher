-- Egg stands in the egg area. Walk up and press E (or use the popup buttons)
-- to hatch 1 or 3 eggs.
-- Egg N unlocks at rebirth N-1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Eggs = {}

local SPACING = 22

local remotes
local eggModels = {} -- [eggIndex] = model, to check the player is close enough
local lastHatch = {} -- [player] = time, so hatching can't be spammed
local HATCH_COOLDOWN = 0.8
local MAX_DISTANCE = 20 -- how close you must be to hatch

local RED = Color3.fromRGB(255, 90, 90)

local function notify(player, message, color)
	remotes.Notify:FireClient(player, message, color)
end

-- Hatches `count` eggs (1 or 3) at once.
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
	if #data.Pets + count > Config.MAX_PETS then
		notify(player, "🎒 Your pet inventory is full! Delete or combine some pets.", RED)
		return
	end
	local cost = Config.eggCost(eggIndex) * count
	if data.Coins < cost then
		notify(player, "💰 You need " .. Config.formatNumber(cost) .. " coins!", RED)
		return
	end

	lastHatch[player] = now
	PlayerData.addCoins(player, -cost)

	local names = {}
	for _ = 1, count do
		table.insert(names, Config.rollHatch(eggIndex, data.Upgrades))
	end
	local indexes = PlayerData.addPets(player, names)

	-- auto-equip into free slots
	local max = Config.maxEquipped(data.Upgrades)
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
		local rarity = Config.PETS[petName].Rarity
		if rarity == "Legendary" or rarity == "Huge" then
			remotes.Announce:FireAllClients(player.DisplayName, petName)
		end
	end
end

-- Creates the pedestal + egg for an egg that isn't in the project file.
local function createEggModel(eggIndex, parent)
	local egg = Config.EGGS[eggIndex]
	local x = (eggIndex - (Config.EGG_COUNT + 1) / 2) * SPACING
	local base = World.EGG_CENTER + Vector3.new(x, World.FLOOR_Y, -15)

	local model = Instance.new("Model")
	model.Name = egg.Name

	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Anchored = true
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.Size = Vector3.new(2, 9, 9)
	pedestal.CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Color = Color3.fromRGB(255, 225, 240)
	pedestal.Material = Enum.Material.SmoothPlastic
	pedestal.Parent = model

	local shell = Instance.new("Part")
	shell.Name = "Egg"
	shell.Anchored = true
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(6, 6, 6)
	shell.Position = base + Vector3.new(0, 5, 0)
	shell.Color = egg.Color
	shell.Material = Enum.Material.SmoothPlastic
	shell.Parent = model

	-- make it egg-shaped
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
	mesh.Parent = shell

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

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(220, 90)
	sign.StudsOffset = Vector3.new(0, 6, 0)
	sign.MaxDistance = 100
	sign.Parent = shell

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = sign

	local function line(name, text, color, height)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.2
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = sign
		return label
	end
	line("Title", egg.Name, Color3.new(1, 1, 1), 32)
	line("Cost", "💰 " .. Config.formatNumber(Config.eggCost(eggIndex)), Color3.fromRGB(255, 210, 60), 26)
	-- the client shows/hides this depending on the player's rebirths
	line("Lock", "🔒 Rebirth " .. Config.eggRequiredRebirths(eggIndex), Color3.fromRGB(255, 90, 90), 26)


	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.Name
	prompt.MaxActivationDistance = 12
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
