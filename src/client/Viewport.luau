-- 3D previews of pets and eggs inside the UI (ViewportFrames).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetModel = require(ReplicatedStorage.Shared.PetModel)
local EggModel = require(ReplicatedStorage.Shared.EggModel)

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

-- Points the camera at the model's front (pets face -Z), a little from the
-- side, far enough back that the whole model fits (big huge pets too, and
-- in narrow frames).
local function frame(camera, model, vp)
	local cf, size = model:GetBoundingBox()
	-- previews spin around the body, so fit a sphere around the body that
	-- reaches the farthest corner (tails and wings stay in view while spinning)
	local pivot = model:GetPivot().Position
	local radius = (cf.Position - pivot).Magnitude + size.Magnitude / 2
	local aspect = if vp and vp.AbsoluteSize.Y > 0 then vp.AbsoluteSize.X / vp.AbsoluteSize.Y else 1
	local halfV = math.rad(camera.FieldOfView / 2)
	local halfH = math.atan(math.tan(halfV) * aspect)
	-- a box never fills its whole bounding sphere, so pull in a little
	local dist = radius / math.sin(math.min(halfV, halfH)) * 0.8
	local center = pivot
	local dir = Vector3.new(0.35, 0.3, -1).Unit
	camera.CFrame = CFrame.lookAt(center + dir * dist, center)
end

-- A pet preview. Silhouette = true shows it all black (not found yet).
function Viewport.pet(parent, petName, silhouette)
	local vp, world, camera = newViewport(parent)
	local model = PetModel.build(petName, { Anchored = true, Silhouette = silhouette })
	model:PivotTo(CFrame.new())
	model.Parent = world
	frame(camera, model, vp)
	-- refit once the frame has its real size on screen
	vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if model.Parent then
			local pivot = model:GetPivot()
			model:PivotTo(CFrame.new())
			frame(camera, model, vp)
			model:PivotTo(pivot)
		end
	end)
	return vp, model
end

-- An egg preview (the same decorated egg as in the hatchery). Returns the
-- ViewportFrame and the egg Model.
function Viewport.egg(parent, eggIndex)
	local vp, world, camera = newViewport(parent)
	local egg = EggModel.build(eggIndex, 6)
	egg:PivotTo(CFrame.new())
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
