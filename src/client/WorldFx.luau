-- Little world animations: spins anything the server tagged "Spin"
-- (like the windmill blades) around its own forward axis.
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

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for model, start in pairs(spinners) do
		local speed = model:GetAttribute("SpinSpeed") or 1
		model:PivotTo(start * CFrame.Angles(0, 0, t * speed))
	end
end)

return WorldFx
