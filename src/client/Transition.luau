-- The teleport screen: fade to black, "Teleporting to ..." with a spinning
-- ring, animated dots and a loading bar, then after 2 seconds teleport the
-- player and fade back in. Used by the portals and the teleport button.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)
local Icons = require(script.Parent.Icons)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Transition = {}

local NAMES = { Main = "Home", Eggs = "the Hatchery" }
local WAIT = 2 -- seconds on the black screen before teleporting

-- its own ScreenGui on top of everything, covering the top bar too
local gui = Instance.new("ScreenGui")
gui.Name = "Transition"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
black.Parent = gui

local center = Instance.new("Frame")
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.fromOffset(420, 200)
center.BackgroundTransparency = 1
center.Parent = black
local centerScale = Instance.new("UIScale")
centerScale.Parent = center

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0)
ring.Position = UDim2.new(0.5, 0, 0, 0)
ring.Size = UDim2.fromOffset(64, 64)
ring.BackgroundTransparency = 1
ring.Parent = center
Icons.rebirth(ring, Ui.COLORS.Accent2)

local title = Ui.label(center, {
	TextColor3 = Color3.new(1, 1, 1),
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 0, 34),
})
local subtitle = Ui.label(center, {
	Font = Ui.FONT_BODY,
	TextColor3 = Color3.fromRGB(170, 175, 200),
	Position = UDim2.fromOffset(0, 120),
	Size = UDim2.new(1, 0, 0, 20),
})

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 160)
bar.Size = UDim2.fromOffset(260, 6)
bar.BackgroundColor3 = Color3.fromRGB(40, 42, 60)
bar.BorderSizePixel = 0
bar.Parent = center
Ui.corner(bar, 0.5)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = bar
Ui.corner(fill, 0.5)
Ui.gradient(fill, Ui.COLORS.Accent, Ui.COLORS.Accent2, 0)

local busy = false

local function fade(transparency, time)
	local tween = TweenService:Create(black, TweenInfo.new(time, Enum.EasingStyle.Quad), { BackgroundTransparency = transparency })
	tween:Play()
	for _, obj in ipairs(center:GetDescendants()) do
		if obj:IsA("TextLabel") then
			TweenService:Create(obj, TweenInfo.new(time), { TextTransparency = transparency }):Play()
		end
	end
	return tween
end

-- Teleports to "Main" or "Eggs" with the black screen. Ignored while one is
-- already playing.
function Transition.go(area)
	if busy then
		return
	end
	busy = true

	title.Text = "Teleporting to " .. (NAMES[area] or area)
	fill.Size = UDim2.fromScale(0, 1)
	black.BackgroundTransparency = 1
	gui.Enabled = true
	centerScale.Scale = 0.8
	fade(0, 0.35).Completed:Wait()
	TweenService:Create(centerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	-- spinning ring, animated dots and the loading bar
	TweenService:Create(fill, TweenInfo.new(WAIT, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	local start = os.clock()
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		ring.Rotation = (t * 300) % 360
		subtitle.Text = "Get ready" .. string.rep(".", math.floor(t * 3) % 4)
	end)
	task.wait(WAIT)

	remotes.Teleport:FireServer(area)
	task.wait(0.35) -- let the character move before we fade back in
	spin:Disconnect()
	fade(1, 0.45).Completed:Wait()
	gui.Enabled = false
	busy = false
end

function Transition.busy()
	return busy
end

return Transition
