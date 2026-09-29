-- 3D previews of pets and eggs inside the UI (ViewportFrames).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetModel = require(ReplicatedStorage.Shared.PetModel)

local Viewport = {}

local function newViewport(parent)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 210)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1.5, 1)
	vp.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp, world, camera
end

-- Points the camera at the model's front (pets face -Z), a little from the side.
local function frame(camera, model)
	local cf, size = model:GetBoundingBox()
	local dist = size.Magnitude * 1.25
	local center = cf.Position
	camera.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.35, dist * 0.3, -dist), center)
end

-- A pet preview. Silhouette = true shows it all black (not found yet).
function Viewport.pet(parent, petName, silhouette)
	local vp, world, camera = newViewport(parent)
	local model = PetModel.build(petName, { Anchored = true, Silhouette = silhouette })
	model:PivotTo(CFrame.new())
	model.Parent = world
	frame(camera, model)
	return vp, model
end

-- An egg preview.
function Viewport.egg(parent, eggIndex)
	local vp, world, camera = newViewport(parent)
	local egg = Instance.new("Part")
	egg.Shape = Enum.PartType.Ball
	egg.Size = Vector3.one * 6
	egg.Color = Config.EGGS[eggIndex].Color
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CFrame = CFrame.new()
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
	mesh.Parent = egg
	egg.Parent = world
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1, -16), Vector3.zero)
	return vp, egg
end

-- Slowly spins a model around; returns a function that stops it.
function Viewport.spin(model, speed)
	local start = model:GetPivot()
	local connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			return
		end
		model:PivotTo(start * CFrame.Angles(0, os.clock() * (speed or 1.5), 0))
	end)
	return function()
		connection:Disconnect()
	end
end

return Viewport
