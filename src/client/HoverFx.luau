-- Makes your hoverboard feel alive: it bobs up and down, leans into turns,
-- tips back a little when you speed up, and the camera widens with speed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local HoverFx = {}

local NORMAL_FOV = 70

local baseC0 = nil -- the weld offset the server set
local lastYaw = nil
local lean = 0
local pitch = 0

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local board = character and character:FindFirstChild("Hoverboard")
	local weld = board and board:FindFirstChild("BoardWeld", true)
	if not root or not weld or not weld:IsA("Weld") then
		baseC0, lastYaw = nil, nil
		if camera then
			camera.FieldOfView += (NORMAL_FOV - camera.FieldOfView) * math.min(dt * 5, 1)
		end
		return
	end
	baseC0 = baseC0 or weld.C0

	-- how fast we're turning (for leaning) and moving (for pitch and FOV)
	local _, yaw = root.CFrame:ToOrientation()
	local turn = 0
	if lastYaw then
		local delta = (yaw - lastYaw + math.pi) % (math.pi * 2) - math.pi
		turn = delta / math.max(dt, 1 / 240)
	end
	lastYaw = yaw
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude

	-- smooth toward the targets so it feels floaty
	lean += (math.clamp(-turn * 0.12, -0.4, 0.4) - lean) * math.min(dt * 6, 1)
	pitch += (math.clamp(speed / 120, 0, 0.18) - pitch) * math.min(dt * 4, 1)
	local bob = math.sin(os.clock() * 3) * 0.15

	weld.C0 = baseC0 * CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, lean)

	if camera then
		local target = NORMAL_FOV + math.clamp((speed - 16) * 0.6, 0, 20)
		camera.FieldOfView += (target - camera.FieldOfView) * math.min(dt * 4, 1)
	end
end)

return HoverFx
