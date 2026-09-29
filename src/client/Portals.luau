-- Portal holes: jump into one (step onto the swirl) and you get the teleport
-- screen, then land in the other world. The server tags the swirl discs
-- "Portal" with a Destination attribute.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Transition = require(script.Parent.Transition)

local player = Players.LocalPlayer

local Portals = {}

local INSIDE = 3.2 -- how close to the center counts as "in the hole"

task.spawn(function()
	while true do
		task.wait(0.1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not Transition.busy() then
			for _, hole in ipairs(CollectionService:GetTagged("Portal")) do
				local offset = root.Position - hole.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < INSIDE and math.abs(offset.Y) < 6 then
					local destination = hole:GetAttribute("Destination")
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
