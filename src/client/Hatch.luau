-- The hatch animation: the egg wobbles harder and harder, flashes, and the
-- pet pops out spinning with its name and rarity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Viewport = require(script.Parent.Viewport)

local Hatch = {}

local queue = {}
local playing = false

local function tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

local function play(petName)
	local info = Config.PETS[petName]
	local huge = info.Rarity == "Huge"

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 30
	overlay.Parent = Ui.gui
	tween(overlay, 0.3, { BackgroundTransparency = 0.35 })

	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.45)
	stage.Size = UDim2.fromOffset(320, 320)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 31
	stage.Parent = overlay
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage

	-- 1) the egg wobbles, faster and faster
	local _, egg = Viewport.egg(stage, info.Egg)
	local start = os.clock()
	local wobble = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local strength = math.min(t / 1.4, 1)
		egg.CFrame = CFrame.Angles(0, 0, math.sin(t * (8 + 22 * strength)) * 0.35 * strength)
		stageScale.Scale = 1 + strength * 0.15
	end)
	task.wait(1.5)
	wobble:Disconnect()

	-- 2) flash!
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.ZIndex = 40
	flash.Parent = overlay
	Ui.clear(stage)
	tween(flash, 0.5, { BackgroundTransparency = 1 })

	-- 3) the pet pops out: spinning shine behind, spinning pet in front
	local shine = Ui.label(stage, {
		Text = "✨",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.5, 1.5),
		TextTransparency = 0.3,
		TextStrokeTransparency = 1,
		ZIndex = 0, -- behind the pet
	})
	local _, pet = Viewport.pet(stage, petName)
	local stopSpin = Viewport.spin(pet, 2)
	stageScale.Scale = 0.2
	tween(stageScale, 0.45, { Scale = if huge then 1.25 else 1 }, Enum.EasingStyle.Back)

	local spinShine = RunService.RenderStepped:Connect(function()
		shine.Rotation = os.clock() * 40 % 360
	end)

	local name = Ui.label(overlay, {
		Text = (if huge then "✨ HUGE! ✨\n" else "") .. petName,
		TextColor3 = info.Color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromOffset(520, if huge then 110 else 64),
		ZIndex = 32,
	})
	local rarity = Ui.label(overlay, {
		Text = info.Rarity .. "  ·  ⚔️ " .. Config.formatNumber(info.Power),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.72, if huge then 116 else 68),
		Size = UDim2.fromOffset(360, 36),
		ZIndex = 32,
	})
	local nameScale = Instance.new("UIScale")
	nameScale.Scale = 0
	nameScale.Parent = name
	tween(nameScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

	-- huge pets get a rainbow name
	local rainbow
	if huge then
		rainbow = RunService.RenderStepped:Connect(function()
			name.TextColor3 = Color3.fromHSV(os.clock() * 0.5 % 1, 0.6, 1)
		end)
	end

	task.wait(if huge then 3.5 else 2.2)

	-- 4) fade out
	tween(overlay, 0.3, { BackgroundTransparency = 1 })
	tween(name, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	tween(rarity, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	tween(stageScale, 0.3, { Scale = 0 })
	task.wait(0.35)
	stopSpin()
	spinShine:Disconnect()
	if rainbow then
		rainbow:Disconnect()
	end
	overlay:Destroy()
end

-- Plays hatches one after another.
function Hatch.play(petName)
	table.insert(queue, petName)
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local ok, err = pcall(play, table.remove(queue, 1))
			if not ok then
				warn("Hatch animation failed:", err)
			end
		end
		playing = false
	end)
end

return Hatch
