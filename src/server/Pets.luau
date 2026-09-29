-- Equipped pets follow their owner. In the main area they run to the nearest
-- coin and break it; a pet's power is its damage per second, so stronger pets
-- break coins faster.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Coins = require(script.Parent.Coins)

local Pets = {}

local PET_SIZE = 2
local SEARCH_RADIUS = 70 -- pets only go for coins this close to their owner
local ATTACK_RANGE = 1

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

-- [player] = list of { Part, Power, Target }
local active = {}

local function makePet(petName, parent)
	local info = Config.PETS[petName]

	local body = Instance.new("Part")
	body.Name = petName
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * PET_SIZE
	body.Color = info.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(120, 24)
	label.StudsOffset = Vector3.new(0, 2, 0)
	label.MaxDistance = 60
	label.Parent = body

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = petName
	text.TextColor3 = info.Color
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Parent = label

	body.Parent = parent
	return body
end

-- Rebuilds the player's pet parts from their equipped list.
function Pets.refresh(player)
	local old = folder:FindFirstChild(tostring(player.UserId))
	if old then
		old:Destroy()
	end
	active[player] = nil

	local data = PlayerData.get(player)
	if not data then
		return
	end

	local playerFolder = Instance.new("Folder")
	playerFolder.Name = tostring(player.UserId)
	playerFolder.Parent = folder

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local startPos = if root then root.Position else World.MAIN_CENTER

	local list = {}
	for _, index in ipairs(data.Equipped) do
		local petName = data.Pets[index]
		if petName and Config.PETS[petName] then
			local part = makePet(petName, playerFolder)
			part.CFrame = CFrame.new(startPos)
			table.insert(list, { Part = part, Power = Config.PETS[petName].Power })
		end
	end
	active[player] = list
end

-- Picks the nearest coin to the owner, preferring ones no other pet is on.
local function findTarget(player, pets, rootPos)
	local taken = {}
	for _, pet in ipairs(pets) do
		if pet.Target then
			taken[pet.Target] = true
		end
	end

	local best, bestDist, bestFree = nil, math.huge, false
	for _, coin in ipairs(Coins.get(player)) do
		local dist = (coin.Position - rootPos).Magnitude
		if dist <= SEARCH_RADIUS then
			local free = not taken[coin]
			-- a free coin always beats a taken one; otherwise the closer one wins
			if (free and not bestFree) or (free == bestFree and dist < bestDist) then
				best, bestDist, bestFree = coin, dist, free
			end
		end
	end
	return best
end

local function moveTowards(part, goal, speed, dt)
	local pos = part.Position
	local offset = goal - pos
	local dist = offset.Magnitude
	local step = math.min(dist, speed * dt)
	local newPos = if dist > 0 then pos + offset.Unit * step else pos

	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > 0.1 then
		part.CFrame = CFrame.lookAt(newPos, newPos + flat)
	else
		part.CFrame = part.CFrame.Rotation + newPos
	end
	return dist - step
end

local function update(dt)
	local t = os.clock()
	for player, pets in pairs(active) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		local rootPos = root.Position
		local inMain = World.isInMainArea(rootPos)

		for i, pet in ipairs(pets) do
			local part = pet.Part

			-- drop the target if it broke or the owner walked away
			local target = pet.Target
			if target and (not target.Parent or not inMain or (target.Position - rootPos).Magnitude > SEARCH_RADIUS + 10) then
				target = nil
			end
			if not target and inMain then
				target = findTarget(player, pets, rootPos)
			end
			pet.Target = target

			if target then
				-- spread pets around the coin so they don't stack
				local angle = (i / #pets) * math.pi * 2
				local ring = target.Size.Y / 2 + 0.5
				local goal = Vector3.new(
					target.Position.X + math.cos(angle) * ring,
					World.FLOOR_Y + PET_SIZE / 2,
					target.Position.Z + math.sin(angle) * ring
				)
				local left = moveTowards(part, goal, Config.PET_SPEED, dt)
				if left <= ATTACK_RANGE then
					if Coins.damage(player, target, pet.Power * dt) then
						pet.Target = nil
					end
				end
			else
				-- follow behind the owner in a little arc, bobbing up and down
				local spread = (i - (#pets + 1) / 2) * 3.5
				local behind = root.CFrame * CFrame.new(spread, 0, 5 + math.abs(spread) * 0.3)
				local groundY = rootPos.Y - 3 + PET_SIZE / 2
				local goal = Vector3.new(behind.X, groundY + math.abs(math.sin(t * 4 + i)) * 0.6, behind.Z)
				local dist = (goal - part.Position).Magnitude
				if dist > 80 then
					part.CFrame = CFrame.new(goal) -- owner teleported, snap to them
				else
					moveTowards(part, goal, math.max(Config.PET_SPEED, dist * 6), dt)
				end
			end
		end
	end
end

function Pets.start()
	PlayerData.Changed.Event:Connect(Pets.refresh)

	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		local f = folder:FindFirstChild(tostring(player.UserId))
		if f then
			f:Destroy()
		end
	end)

	RunService.Heartbeat:Connect(update)
end

return Pets
