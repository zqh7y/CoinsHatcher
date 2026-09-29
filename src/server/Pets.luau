-- Equipped pets follow their owner. In the main area they run to the nearest
-- breakable and hit it every Config.PET_HIT_INTERVAL seconds; each hit deals
-- the pet's power (times the Damage upgrade), so stronger pets break things
-- faster.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetModel = require(ReplicatedStorage.Shared.PetModel)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Coins = require(script.Parent.Coins)

local Pets = {}

local SEARCH_RADIUS = 70 -- pets only go for coins this close to their owner
local ATTACK_RANGE = 1.5

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

-- [player] = list of { Part, Name, Power, Lift, Half, Target, LastHit }
local active = {}
local equippedKey = {} -- [player] = the equipped pets we last built, to skip needless rebuilds

-- Name and odds over the pet's head, so everyone can see how rare it is.
local function addNameTag(body, petName)
	local info = Config.PETS[petName]
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(160, 40)
	label.StudsOffset = Vector3.new(0, 3.3 * info.Scale, 0)
	label.MaxDistance = 80
	label.Parent = body

	local function line(text, color, y, height)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, height, 0)
		l.Position = UDim2.fromScale(0, y)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.2
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Parent = label
	end
	line(petName, info.Color, 0, 0.58)
	line(Config.chanceText(petName), Color3.new(1, 1, 1), 0.6, 0.4)
end

-- Rebuilds the player's pets from their equipped list (only if it changed).
function Pets.refresh(player)
	local data = PlayerData.get(player)
	local names = {}
	if data then
		for _, index in ipairs(data.Equipped) do
			table.insert(names, data.Pets[index] or "?")
		end
	end
	local key = table.concat(names, ",")
	if active[player] and equippedKey[player] == key then
		return
	end
	equippedKey[player] = key

	local old = folder:FindFirstChild(tostring(player.UserId))
	if old then
		old:Destroy()
	end
	active[player] = nil
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
	for _, petName in ipairs(names) do
		local info = Config.PETS[petName]
		if info then
			local model = PetModel.build(petName)
			addNameTag(model.PrimaryPart, petName)
			model:PivotTo(CFrame.new(startPos))
			model.Parent = playerFolder
			table.insert(list, {
				Part = model.PrimaryPart,
				Name = petName,
				Power = info.Power,
				Lift = PetModel.lift(petName),
				Half = PetModel.SIZE / 2 * info.Scale,
				LastHit = 0,
			})
		end
	end
	active[player] = list
end

-- Picks the nearest breakable to the owner, preferring ones no other pet is on.
local function findTarget(player, pets, rootPos)
	local taken = {}
	for _, pet in ipairs(pets) do
		if pet.Target then
			taken[pet.Target] = true
		end
	end

	local best, bestDist, bestFree = nil, math.huge, false
	for _, coin in ipairs(Coins.get(player)) do
		local dist = (coin:GetPivot().Position - rootPos).Magnitude
		if dist <= SEARCH_RADIUS then
			local free = not taken[coin]
			-- a free one always beats a taken one; otherwise the closer one wins
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
		local data = PlayerData.get(player)
		if not root or not data then
			continue
		end

		local rootPos = root.Position
		local inMain = World.isInMainArea(rootPos)
		local speed = Config.PET_SPEED * Config.petSpeedMult(data.Upgrades)
		local damageMult = Config.totalDamage(data)

		for i, pet in ipairs(pets) do
			local part = pet.Part

			-- drop the target if it broke or the owner walked away
			local target = pet.Target
			if
				target
				and (
					not target.Parent
					or not inMain
					or (target:GetPivot().Position - rootPos).Magnitude > SEARCH_RADIUS + 10
				)
			then
				target = nil
			end
			if not target and inMain then
				target = findTarget(player, pets, rootPos)
			end
			pet.Target = target

			if target then
				-- spread pets around the breakable so they don't stack
				local center = target:GetPivot().Position
				local angle = (i / #pets) * math.pi * 2
				local ring = (target:GetAttribute("Radius") or 1.5) + pet.Half + 0.2
				local goal = Vector3.new(
					center.X + math.cos(angle) * ring,
					World.FLOOR_Y + pet.Lift,
					center.Z + math.sin(angle) * ring
				)
				local left = moveTowards(part, goal, speed, dt)
				if left <= ATTACK_RANGE then
					-- face the breakable and do a little hop on each hit
					local sinceHit = t - pet.LastHit
					local hop = if sinceHit < 0.3 then math.sin(sinceHit / 0.3 * math.pi) * 0.9 else 0
					local pos = goal + Vector3.new(0, hop, 0)
					part.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))

					if t >= pet.LastHit + Config.hitInterval(data) then
						pet.LastHit = t
						local crit = math.random() < Config.critChance(data)
						local damage = math.floor(pet.Power * damageMult * (if crit then Config.critMult(data) else 1))
						if Coins.damage(player, target, damage, crit) then
							pet.Target = nil
						end
					end
				end
			else
				-- follow behind the owner in a little arc, bobbing up and down
				local spread = (i - (#pets + 1) / 2) * (2.5 + pet.Half)
				local behind = root.CFrame * CFrame.new(spread, 0, 4 + pet.Half + math.abs(spread) * 0.3)
				local groundY = rootPos.Y - 3 + pet.Lift
				local goal = Vector3.new(behind.X, groundY + math.abs(math.sin(t * 4 + i)) * 0.6, behind.Z)
				local dist = (goal - part.Position).Magnitude
				if dist > 80 then
					part.CFrame = CFrame.new(goal) -- owner teleported, snap to them
				else
					moveTowards(part, goal, math.max(speed, dist * 6), dt)
				end
			end
		end
	end
end

function Pets.start()
	PlayerData.Changed.Event:Connect(Pets.refresh)

	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		equippedKey[player] = nil
		local f = folder:FindFirstChild(tostring(player.UserId))
		if f then
			f:Destroy()
		end
	end)

	RunService.Heartbeat:Connect(update)
end

return Pets
