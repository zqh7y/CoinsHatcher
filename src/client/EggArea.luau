-- The hatchery on this player's screen:
--  * eggs gently bob and sway
--  * eggs you haven't unlocked turn into plain black eggs with a gold
--    padlock on the front that says which rebirth opens them; unlocked ones
--    show their name floating above
--  * the speed lane down the middle makes you run much faster and its arrows
--    light up in a wave
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer

local EggArea = {}

local LANE_SPEED = 2.6 -- times your normal walk speed on the speed lane
local LOCKED_COLOR = Color3.fromRGB(22, 22, 30)

local eggs = {} -- { Model, Shell, Base, Phase, Look = { { Part, Offset, Transparency } }, Lock, Gui, Glows }

local lockFolder = Instance.new("Folder")
lockFolder.Name = "EggLocks"
lockFolder.Parent = workspace

-- A gold padlock on the front of an egg (the side facing the walkway) with
-- "REBIRTH N" written on it. Only this player sees it. Returns its parts as
-- { Part, Offset } so they bob with the egg, and its sign.
local function makePadlock(shell, eggIndex)
	local front = if Config.EGGS[eggIndex].Release then Vector3.new(0, 0, 1) else Vector3.new(-1, 0, 0)
	local radius = shell.Size.X / 2 * 0.85
	local center = shell.Position + front * (radius + 0.3) + Vector3.new(0, -0.5, 0)
	local cf = CFrame.lookAt(center, center + front)
	local gold = Color3.fromRGB(255, 200, 60)
	local silver = Color3.fromRGB(215, 220, 235)

	local parts = {}
	local function add(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Reflectance = 0.15
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = lockFolder
		table.insert(parts, { Part = p, Offset = shell.CFrame:ToObjectSpace(p.CFrame) })
		return p
	end
	-- the shackle (an upside-down U), then the body
	for _, x in ipairs({ -0.8, 0.8 }) do
		add("Shackle", Vector3.new(0.4, 1.4, 0.4), CFrame.new(x, 1.55, 0.05), silver, Enum.Material.Metal)
	end
	add("Shackle", Vector3.new(2, 0.4, 0.4), CFrame.new(0, 2.25, 0.05), silver, Enum.Material.Metal)
	local body = add("LockBody", Vector3.new(2.8, 2.3, 0.7), CFrame.new(), gold)
	add("LockRim", Vector3.new(2.95, 0.25, 0.75), CFrame.new(0, 1.0, 0), gold:Lerp(Color3.new(0, 0, 0), 0.15))

	local sign = Instance.new("SurfaceGui")
	sign.Face = Enum.NormalId.Front
	sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sign.PixelsPerStud = 80
	sign.LightInfluence = 0
	sign.Adornee = body
	sign.Parent = player:WaitForChild("PlayerGui")
	local function line(text, y, height)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.06, y)
		label.Size = UDim2.fromScale(0.88, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = Color3.fromRGB(110, 70, 10)
		label.Parent = sign
	end
	line("REBIRTH", 0.12, 0.3)
	line(tostring(Config.eggRequiredRebirths(eggIndex)), 0.42, 0.5)
	return parts, sign
end

-- Floating name over an unlocked egg.
local function makeLabel(model, shell)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EggLabel"
	gui.Size = UDim2.fromOffset(160, 30)
	-- above the egg's top, attached to the pedestal (not the bobbing shell)
	gui.StudsOffsetWorldSpace = Vector3.new(0, shell.Size.Y * 1.25 + 1.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = model:FindFirstChild("Top") or shell
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return gui, label
end

local function refreshLocks()
	local data = State.Data
	if not data then
		return
	end
	for _, egg in ipairs(eggs) do
		local eggIndex = egg.Model:GetAttribute("EggIndex")
		if eggIndex then
			local info = Config.EGGS[eggIndex]
			local required = Config.eggRequiredRebirths(eggIndex)
			local locked = data.Rebirths < required

			-- a locked egg is just a black egg: no pattern, no glow
			egg.Shell.Color = if locked then LOCKED_COLOR else egg.ShellColor
			egg.Shell.Reflectance = if locked then 0.35 else 0.2
			for _, piece in ipairs(egg.Look) do
				piece.Part.Transparency = if locked then 1 else piece.Transparency
			end
			for _, glow in ipairs(egg.Glows) do
				glow.Part.Color = if locked then Color3.fromRGB(70, 70, 85) else glow.Color
			end
			for _, obj in ipairs(egg.Shell:GetChildren()) do
				if obj:IsA("PointLight") or obj:IsA("ParticleEmitter") then
					obj.Enabled = not locked
				end
			end
			local beam = egg.Model:FindFirstChild("Beam")
			if beam then
				beam.Transparency = if locked then 1 else 0.92
			end

			-- the padlock shows on locked eggs, the floating name on unlocked ones
			for _, piece in ipairs(egg.Lock) do
				piece.Part.Transparency = if locked then 0 else 1
			end
			egg.Sign.Enabled = locked
			egg.Locked = locked
			egg.Gui.Enabled = not locked and not egg.PopupOpen
			egg.Text.Text = info.Name
			egg.Text.TextStrokeColor3 = info.Color:Lerp(Color3.new(0, 0, 0), 0.5)
		end
	end
end

local function track(model)
	local shell = model:IsA("Model") and model:FindFirstChild("Egg")
	if not shell or not model:GetAttribute("EggIndex") then
		return
	end
	for _, egg in ipairs(eggs) do
		if egg.Model == model then
			return
		end
	end
	-- the pattern/shine parts move with the shell
	local look = {}
	local lookFolder = model:FindFirstChild("EggLook")
	if lookFolder then
		for _, part in ipairs(lookFolder:GetChildren()) do
			if part:IsA("BasePart") then
				table.insert(look, { Part = part, Offset = shell.CFrame:ToObjectSpace(part.CFrame), Transparency = part.Transparency })
			end
		end
	end
	local glows = {}
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and (part.Name == "Glow" or part.Name == "Gem") then
			table.insert(glows, { Part = part, Color = part.Color })
		end
	end
	local gui, text = makeLabel(model, shell)
	local lock, sign = makePadlock(shell, model:GetAttribute("EggIndex"))
	table.insert(eggs, {
		Lock = lock,
		Sign = sign,
		Model = model,
		Shell = shell,
		ShellColor = shell.Color,
		Base = shell.CFrame,
		Phase = #eggs * 1.3,
		Look = look,
		Glows = glows,
		Gui = gui,
		Text = text,
	})
	refreshLocks()
end

task.spawn(function()
	local folder = workspace:WaitForChild("EggArea"):WaitForChild("Eggs")
	local function watch(model)
		-- the server sets EggIndex and adds the pattern once it has built the egg
		if model:GetAttribute("EggIndex") and model:FindFirstChild("EggLook") then
			track(model)
		else
			task.delay(1, watch, model)
		end
	end
	folder.ChildAdded:Connect(watch)
	for _, model in ipairs(folder:GetChildren()) do
		watch(model)
	end
end)

State.Changed.Event:Connect(refreshLocks)

-- Is this egg locked for us? (black egg, no popup)
function EggArea.isLocked(eggIndex)
	local data = State.Data
	return data ~= nil and data.Rebirths < Config.eggRequiredRebirths(eggIndex)
end

-- The egg popup hides the egg's floating name while it's open.
function EggArea.setLabelVisible(eggIndex, visible)
	for _, egg in ipairs(eggs) do
		if egg.Model:GetAttribute("EggIndex") == eggIndex then
			egg.PopupOpen = not visible
			egg.Gui.Enabled = visible and not egg.Locked
		end
	end
end

-- Speed lane -----------------------------------------------------------------

local lane, arrows
local onLane = false
local toldAboutLane = false

task.spawn(function()
	local eggArea = workspace:WaitForChild("EggArea")
	lane = eggArea:WaitForChild("SpeedLane")
	arrows = eggArea:WaitForChild("LaneArrows"):GetChildren()
end)

local function isOnLane(root)
	if not lane then
		return false
	end
	local p = lane.CFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) < lane.Size.X / 2 + 0.5 and math.abs(p.Z) < lane.Size.Z / 2 and p.Y > -1 and p.Y < 6
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or #eggs == 0 or (root.Position - eggs[1].Base.Position).Magnitude > 400 then
		return
	end
	local t = os.clock()

	-- eggs bob and sway
	for _, egg in ipairs(eggs) do
		local bob = math.sin(t * 1.6 + egg.Phase) * 0.35
		local sway = math.sin(t * 1.1 + egg.Phase) * 0.07
		local cf = egg.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, sway)
		egg.Shell.CFrame = cf
		for _, piece in ipairs(egg.Look) do
			piece.Part.CFrame = cf * piece.Offset
		end
		if egg.Locked then
			for _, piece in ipairs(egg.Lock) do
				piece.Part.CFrame = cf * piece.Offset
			end
		end
	end

	-- speed lane: run faster while on it
	local normal = Config.walkSpeed(State.Data and State.Data.Upgrades)
	local now = isOnLane(root)
	if now then
		humanoid.WalkSpeed = normal * LANE_SPEED
	elseif onLane then
		humanoid.WalkSpeed = normal
	end
	if now and not onLane and not toldAboutLane then
		toldAboutLane = true
		Ui.toast("💨 Speed lane! Run faster while you're on it", Color3.fromRGB(90, 200, 255))
	end
	onLane = now

	-- the arrows light up in a wave running down the lane
	if arrows then
		for _, arrow in ipairs(arrows) do
			local step = arrow:GetAttribute("Step") or 0
			local wave = (math.sin(t * 6 - step * 0.6) + 1) / 2
			arrow.Transparency = 0.7 - wave * 0.7
		end
	end
end)

return EggArea
