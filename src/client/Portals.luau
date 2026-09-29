-- Gate portals: walk through the glowing portal in the PET PARK / HATCHERY
-- gate and you get the teleport screen, then land in the other world. The
-- server tags the portal membranes "Portal" with a Destination attribute.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Transition = require(script.Parent.Transition)

local player = Players.LocalPlayer

local Portals = {}

-- the membrane is thin, so count a couple of studs in front and behind it too
-- (you can move a few studs between checks)
local DEPTH = 2.2

local function inside(root, membrane)
	local p = membrane.CFrame:PointToObjectSpace(root.Position)
	local half = membrane.Size / 2
	return math.abs(p.X) < half.X and math.abs(p.Y) < half.Y + 1 and math.abs(p.Z) < DEPTH
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not Transition.busy() then
			for _, membrane in ipairs(CollectionService:GetTagged("Portal")) do
				if membrane:IsA("BasePart") and inside(root, membrane) then
					local destination = membrane:GetAttribute("Destination")
					if destination then
						task.spawn(Transition.go, destination)
					end
					break
				end
			end
		end
	end
end)

return Portals
