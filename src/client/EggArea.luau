-- Makes the hatchery eggs gently bob and sway, and greys out the glow of
-- eggs you haven't unlocked yet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local EggArea = {}

local LOCKED_GLOW = Color3.fromRGB(170, 170, 185)

local eggs = {} -- { Model, Shell, Base, Phase }

local function refreshLocks()
	local data = State.Data
	if not data then
		return
	end
	for _, egg in ipairs(eggs) do
		local required = egg.Model:GetAttribute("RequiredRebirths") or 0
		local eggIndex = egg.Model:GetAttribute("EggIndex")
		local locked = data.Rebirths < required
		local glow = egg.Model:FindFirstChild("Glow")
		if glow and eggIndex then
			glow.Color = if locked then LOCKED_GLOW else Config.EGGS[eggIndex].Color
		end
		local light = egg.Shell:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = not locked
		end
		-- frosted glass dome over eggs you can't open yet
		local dome = egg.Model:FindFirstChild("LockDome")
		if dome then
			dome.Transparency = if locked then 0.45 else 1
		end
	end
end

local function track(model)
	local shell = model:IsA("Model") and model:FindFirstChild("Egg")
	if not shell then
		return
	end
	table.insert(eggs, { Model = model, Shell = shell, Base = shell.CFrame, Phase = #eggs * 1.3 })
	refreshLocks()
end

task.spawn(function()
	local folder = workspace:WaitForChild("EggArea"):WaitForChild("Eggs")
	folder.ChildAdded:Connect(track)
	for _, model in ipairs(folder:GetChildren()) do
		track(model)
	end
	-- attributes are set by the server once it starts
	for _, model in ipairs(folder:GetChildren()) do
		model:GetAttributeChangedSignal("RequiredRebirths"):Connect(refreshLocks)
	end
end)

State.Changed.Event:Connect(refreshLocks)

RunService.RenderStepped:Connect(function()
	-- only animate when we're near the hatchery
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or #eggs == 0 or (root.Position - eggs[1].Base.Position).Magnitude > 200 then
		return
	end
	local t = os.clock()
	for _, egg in ipairs(eggs) do
		local bob = math.sin(t * 1.6 + egg.Phase) * 0.35
		local sway = math.sin(t * 1.1 + egg.Phase) * 0.07
		egg.Shell.CFrame = egg.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, sway)
	end
end)

return EggArea
