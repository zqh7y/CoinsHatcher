-- Equipped pets follow their owner. In the main area they run to the nearest
-- breakable and hit it every Config.PET_HIT_INTERVAL seconds; each hit deals
-- the pet's power, so stronger pets break things faster.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)
local Coins = require(script.Parent.Coins)

local Pets = {}

local PET_SIZE = 2.2
local PET_LIFT = PET_SIZE / 2 + 0.3 -- body height above the ground (feet underneath)
local SEARCH_RADIUS = 70 -- pets only go for coins this close to their owner
local ATTACK_RANGE = 1.5

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

-- [player] = list of { Part, Power, Target, LastHit }
local active = {}

local function circle(parent, color, size, pos)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	return f
end

-- Big shiny eyes and pink cheeks on the front of the pet.
local function makeFace(body)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = body

	local black = Color3.fromRGB(35, 30, 40)
	for _, x in ipairs({ 0.3, 0.7 }) do
		local eye = circle(gui, black, UDim2.fromScale(0.2, 0.27), UDim2.fromScale(x, 0.42))
		circle(eye, Color3.new(1, 1, 1), UDim2.fromScale(0.4, 0.3), UDim2.fromScale(0.65, 0.3))
	end
	for _, x in ipairs({ 0.18, 0.82 }) do
		local cheek = circle(gui, Color3.fromRGB(255, 140, 170), UDim2.fromScale(0.16, 0.1), UDim2.fromScale(x, 0.62))
		cheek.BackgroundTransparency = 0.3
	end
	-- little smile
	local mouth = Instance.new("TextLabel")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.64)
	mouth.Size = UDim2.fromScale(0.25, 0.18)
	mouth.BackgroundTransparency = 1
	mouth.Text = "w"
	mouth.TextColor3 = black
	mouth.TextScaled = true
	mouth.Font = Enum.Font.FredokaOne
	mouth.Parent = gui
end

-- Adds a decoration part welded to the body, placed at offset (body space:
-- -Z is the front where the face is, +Z is the back, +Y is up).
local function attach(body, offset, size, color, shape)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = body
	return p
end

local BALL = Enum.PartType.Ball
local function mirror(fn)
	fn(1)
	fn(-1)
end

local EARS = {
	pointy = function(body, color)
		mirror(function(side)
			attach(body, CFrame.new(side * 0.6, 1.35, -0.2) * CFrame.Angles(0, 0, side * -0.35), Vector3.new(0.55, 0.8, 0.3), color)
		end)
	end,
	round = function(body, color)
		mirror(function(side)
			attach(body, CFrame.new(side * 0.7, 1.15, -0.1), Vector3.one * 0.75, color, BALL)
		end)
	end,
	long = function(body, color)
		mirror(function(side)
			attach(body, CFrame.new(side * 0.45, 1.85, 0) * CFrame.Angles(0, 0, side * -0.15), Vector3.new(0.45, 1.6, 0.3), color)
		end)
	end,
	floppy = function(body, color)
		mirror(function(side)
			attach(body, CFrame.new(side * 1.25, 0.45, -0.1) * CFrame.Angles(0, 0, side * 0.25), Vector3.new(0.3, 1, 0.7), color)
		end)
	end,
}

local TAILS = {
	short = function(body, color)
		attach(body, CFrame.new(0, 0.3, 1.25), Vector3.one * 0.6, color, BALL)
	end,
	long = function(body, color)
		attach(body, CFrame.new(0, 0.45, 1.65) * CFrame.Angles(0.5, 0, 0), Vector3.new(0.35, 0.35, 1.5), color)
	end,
	fluffy = function(body, color)
		attach(body, CFrame.new(0, 0.4, 1.45), Vector3.one * 1.1, color:Lerp(Color3.new(1, 1, 1), 0.4), BALL)
	end,
	fin = function(body, color)
		attach(body, CFrame.new(0, 0, 1.5), Vector3.new(0.2, 1.4, 0.9), color)
	end,
}

local EXTRAS = {
	wings = function(body, color)
		mirror(function(side)
			attach(
				body,
				CFrame.new(side * 1.55, 0.35, 0.15) * CFrame.Angles(0, 0, side * 0.45),
				Vector3.new(1.1, 0.18, 1),
				color:Lerp(Color3.new(1, 1, 1), 0.3)
			)
		end)
	end,
	beak = function(body)
		attach(body, CFrame.new(0, -0.15, -1.25), Vector3.new(0.5, 0.35, 0.4), Color3.fromRGB(255, 170, 40))
	end,
	horns = function(body)
		mirror(function(side)
			attach(body, CFrame.new(side * 0.55, 1.4, -0.3) * CFrame.Angles(0, 0, side * -0.3), Vector3.new(0.3, 0.8, 0.3), Color3.fromRGB(255, 245, 215))
		end)
	end,
	antlers = function(body)
		local brown = Color3.fromRGB(150, 100, 60)
		mirror(function(side)
			attach(body, CFrame.new(side * 0.55, 1.6, 0) * CFrame.Angles(0, 0, side * -0.35), Vector3.new(0.22, 1.2, 0.22), brown)
			attach(body, CFrame.new(side * 0.95, 1.85, 0) * CFrame.Angles(0, 0, side * 0.6), Vector3.new(0.2, 0.6, 0.2), brown)
		end)
	end,
	shell = function(body)
		local green = Color3.fromRGB(70, 150, 80)
		attach(body, CFrame.new(0, 1.3, 0.1), Vector3.new(2.5, 0.5, 2.5), green)
		attach(body, CFrame.new(0, 1.7, 0.1), Vector3.new(1.7, 0.4, 1.7), green:Lerp(Color3.new(1, 1, 1), 0.2))
	end,
	claws = function(body, color)
		mirror(function(side)
			attach(body, CFrame.new(side * 1.5, -0.2, -0.7), Vector3.one * 0.9, color:Lerp(Color3.new(0, 0, 0), 0.15), BALL)
		end)
	end,
	topfin = function(body, color)
		attach(body, CFrame.new(0, 1.45, 0.3) * CFrame.Angles(-0.35, 0, 0), Vector3.new(0.2, 0.9, 1), color)
	end,
	fire = function(body)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 2
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 230, 90)
		fire.Parent = body
	end,
}

local function makePet(petName, parent)
	local info = Config.PETS[petName]
	local look = Config.PET_LOOKS[petName] or {}
	local extras = look.Extras or {}
	local color = info.BodyColor
	local darker = color:Lerp(Color3.new(0, 0, 0), 0.15)

	-- a cute little cube
	local body = Instance.new("Part")
	body.Name = petName
	body.Size = Vector3.one * PET_SIZE
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false

	makeFace(body)

	if look.Ears then
		EARS[look.Ears](body, darker)
	end
	if look.Tail then
		TAILS[look.Tail](body, darker)
	end
	for _, extra in ipairs(extras) do
		if EXTRAS[extra] then
			EXTRAS[extra](body, color)
		end
	end
	if not table.find(extras, "nofeet") then
		for _, x in ipairs({ -0.6, 0.6 }) do
			for _, z in ipairs({ -0.6, 0.6 }) do
				attach(body, CFrame.new(x, -1.25, z), Vector3.new(0.6, 0.3, 0.6), darker)
			end
		end
	end

	if info.Rarity == "Legendary" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = info.Color
		sparkles.Parent = body
	end

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(120, 24)
	label.StudsOffset = Vector3.new(0, 3, 0)
	label.MaxDistance = 60
	label.Parent = body

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = petName
	text.TextColor3 = info.Color
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.FredokaOne
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
			table.insert(list, { Part = part, Power = Config.PETS[petName].Power, LastHit = 0 })
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
		local dist = (coin:GetPivot().Position - rootPos).Magnitude
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
				local ring = (target:GetAttribute("Radius") or 1.5) + PET_SIZE / 2 + 0.2
				local goal = Vector3.new(
					center.X + math.cos(angle) * ring,
					World.FLOOR_Y + PET_LIFT,
					center.Z + math.sin(angle) * ring
				)
				local left = moveTowards(part, goal, Config.PET_SPEED, dt)
				if left <= ATTACK_RANGE then
					-- face the breakable and do a little hop on each hit
					local sinceHit = t - pet.LastHit
					local hop = if sinceHit < 0.3 then math.sin(sinceHit / 0.3 * math.pi) * 0.9 else 0
					local pos = goal + Vector3.new(0, hop, 0)
					part.CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))

					if t >= pet.LastHit + Config.PET_HIT_INTERVAL then
						pet.LastHit = t
						if Coins.damage(player, target, pet.Power) then
							pet.Target = nil
						end
					end
				end
			else
				-- follow behind the owner in a little arc, bobbing up and down
				local spread = (i - (#pets + 1) / 2) * 3.5
				local behind = root.CFrame * CFrame.new(spread, 0, 5 + math.abs(spread) * 0.3)
				local groundY = rootPos.Y - 3 + PET_LIFT
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
