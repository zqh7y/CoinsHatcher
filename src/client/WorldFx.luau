-- Little world animations: spins anything the server tagged "Spin" (like the
-- windmill blades) around its own forward axis, and bobs anything tagged "Bob".
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WorldFx = {}

local spinners = {} -- [model] = starting pivot

local function add(model)
	if model:IsA("Model") then
		spinners[model] = model:GetPivot()
	end
end

CollectionService:GetInstanceAddedSignal("Spin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(model)
	spinners[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("Spin")) do
	add(model)
end

-- Parts tagged "Bob" (boost orbs) float up and down and turn slowly.
local bobbers = {} -- [part] = starting CFrame

local function addBob(part)
	if part:IsA("BasePart") then
		bobbers[part] = part.CFrame
	end
end
CollectionService:GetInstanceAddedSignal("Bob"):Connect(addBob)
CollectionService:GetInstanceRemovedSignal("Bob"):Connect(function(part)
	bobbers[part] = nil
end)
for _, part in ipairs(CollectionService:GetTagged("Bob")) do
	addBob(part)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for model, start in pairs(spinners) do
		local speed = model:GetAttribute("SpinSpeed") or 1
		model:PivotTo(start * CFrame.Angles(0, 0, t * speed))
	end
	for part, start in pairs(bobbers) do
		if part.Parent then
			part.CFrame = start * CFrame.new(0, math.sin(t * 3) * 0.5, 0) * CFrame.Angles(0, t * 2, 0)
		else
			bobbers[part] = nil
		end
	end
end)

return WorldFx
