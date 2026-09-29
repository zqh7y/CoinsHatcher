-- Egg stands in the egg area. Walk up and press E to hatch.
-- Egg N unlocks at rebirth N-1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Eggs = {}

local SPACING = 22

local remotes

local function notify(player, message, color)
	remotes.Notify:FireClient(player, message, color)
end

local function hatch(player, eggIndex)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	local required = Config.eggRequiredRebirths(eggIndex)
	if data.Rebirths < required then
		notify(player, "Rebirth " .. required .. " needed to open this egg!", Color3.fromRGB(255, 90, 90))
		return
	end
	if #data.Pets >= Config.MAX_PETS then
		notify(player, "Your pet inventory is full!", Color3.fromRGB(255, 90, 90))
		return
	end
	local cost = Config.eggCost(eggIndex)
	if data.Coins < cost then
		notify(player, "Not enough coins!", Color3.fromRGB(255, 90, 90))
		return
	end

	PlayerData.addCoins(player, -cost)

	local rarityIndex = Config.rollRarity()
	local petName = Config.EGGS[eggIndex].Pets[rarityIndex]
	local index = PlayerData.addPet(player, petName)

	-- auto-equip if there's a free slot
	if index and #data.Equipped < Config.MAX_EQUIPPED then
		local equipped = table.clone(data.Equipped)
		table.insert(equipped, index)
		PlayerData.setEquipped(player, equipped)
	end

	remotes.Hatched:FireClient(player, petName)
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
	pedestal.Color = Color3.fromRGB(90, 90, 100)
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
	sign.Size = UDim2.fromOffset(220, 110)
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
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = sign
		return label
	end
	line("Title", egg.Name, Color3.new(1, 1, 1), 32)
	line("Cost", "💰 " .. Config.formatNumber(Config.eggCost(eggIndex)), Color3.fromRGB(255, 210, 60), 26)
	-- the client shows/hides this depending on the player's rebirths
	line("Lock", "🔒 Rebirth " .. Config.eggRequiredRebirths(eggIndex), Color3.fromRGB(255, 90, 90), 26)

	-- show what's inside + chances
	local chances = {}
	for rarityIndex, petName in ipairs(egg.Pets) do
		table.insert(chances, petName .. " " .. Config.RARITIES[rarityIndex].Chance .. "%")
	end
	line("Pets", table.concat(chances, " · "), Color3.fromRGB(220, 220, 220), 18)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.Name
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player)
		hatch(player, eggIndex)
	end)

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
end

return Eggs
