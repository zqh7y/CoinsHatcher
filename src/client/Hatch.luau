-- The hatch animation: the eggs wobble harder and harder, flash, and the pets
-- pop out spinning with their name, rarity and odds. Works for 1 or 3 eggs,
-- and has a quicker version while auto-hatching.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Viewport = require(script.Parent.Viewport)
local Fx = require(script.Parent.Fx)

local Hatch = {}

Hatch.fast = false -- set by auto-hatch for a shorter animation

local queue = {}
local playing = false

local SLOT = 250 -- width of each egg/pet on screen

local function tween(obj, time, props, style)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad), props)
	t:Play()
	return t
end

local function play(petNames)
	local fast = Hatch.fast
	local count = #petNames
	local anyRare = false
	for _, petName in ipairs(petNames) do
		if Config.isRare(petName) then
			anyRare = true
		end
	end

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 30
	overlay.Parent = Ui.gui
	tween(overlay, 0.25, { BackgroundTransparency = if fast then 0.6 else 0.35 })

	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.42)
	stage.Size = UDim2.fromOffset(SLOT * count, SLOT)
	stage.BackgroundTransparency = 1
	stage.Parent = overlay
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage

	local slots = {}
	for i = 1, count do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.fromScale(1 / count, 1)
		slot.Position = UDim2.fromScale((i - 1) / count, 0)
		slot.BackgroundTransparency = 1
		slot.Parent = stage
		slots[i] = slot
	end

	-- 1) the eggs wobble, faster and faster
	local eggs = {}
	for i, petName in ipairs(petNames) do
		local _, egg = Viewport.egg(slots[i], Config.PETS[petName].Egg)
		eggs[i] = egg
	end
	local wobbleTime = if fast then 0.6 else 1.5
	local start = os.clock()
	local wobble = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local strength = math.min(t / wobbleTime, 1)
		for i, egg in ipairs(eggs) do
			egg:PivotTo(CFrame.Angles(0, 0, math.sin(t * (8 + 22 * strength) + i) * 0.35 * strength))
		end
		stageScale.Scale = 1 + strength * 0.12
	end)
	task.wait(wobbleTime)
	wobble:Disconnect()

	-- 2) flash!
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = if fast then 0.5 else 0
	flash.ZIndex = 40
	flash.Parent = overlay
	tween(flash, 0.5, { BackgroundTransparency = 1 })

	-- 3) the pets pop out
	local stops = {}
	local labels = {}
	local rainbows = {}
	for i, petName in ipairs(petNames) do
		local info = Config.PETS[petName]
		local slot = slots[i]
		Ui.clear(slot)

		local shine = Ui.label(slot, {
			Text = "✨",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(1.2, 1.2),
			TextTransparency = 0.3,
			TextStrokeTransparency = 1,
			ZIndex = 0, -- behind the pet
		})
		local view = Instance.new("Frame")
		view.Size = UDim2.fromScale(1, 0.8)
		view.BackgroundTransparency = 1
		view.ZIndex = 1
		view.Parent = slot
		local _, pet = Viewport.pet(view, petName)
		table.insert(stops, Viewport.spin(pet, 2))
		table.insert(stops, function()
			shine:Destroy()
		end)
		local spinShine = RunService.RenderStepped:Connect(function()
			shine.Rotation = os.clock() * 40 % 360
		end)
		table.insert(stops, function()
			spinShine:Disconnect()
		end)

		local special = info.Rarity == "Huge" or info.Mutation ~= nil
		local name = Ui.label(overlay, {
			Text = petName,
			TextColor3 = info.Color,
			TextStrokeTransparency = 0.3,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - (count + 1) / 2) * SLOT, 0.42, SLOT / 2 + 6),
			Size = UDim2.fromOffset(SLOT - 10, 40),
			ZIndex = 32,
		})
		local detail = Ui.label(overlay, {
			Text = ("%s · %s · ⚔️ %s"):format(info.Rarity, Config.chanceText(petName), Config.formatNumber(info.Power)),
			TextColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - (count + 1) / 2) * SLOT, 0.42, SLOT / 2 + 48),
			Size = UDim2.fromOffset(SLOT - 10, 24),
			ZIndex = 32,
		})
		table.insert(labels, name)
		table.insert(labels, detail)
		local nameScale = Instance.new("UIScale")
		nameScale.Scale = 0
		nameScale.Parent = name
		tween(nameScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)

		-- huge and mutated pets get a rainbow name
		if special then
			table.insert(
				rainbows,
				RunService.RenderStepped:Connect(function()
					name.TextColor3 = Color3.fromHSV((os.clock() * 0.5 + i * 0.2) % 1, 0.6, 1)
				end)
			)
		end
	end
	stageScale.Scale = 0.2
	tween(stageScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- a big banner for the really rare ones
	if anyRare then
		local banner = Ui.label(overlay, {
			Text = "🎉 SO RARE! 🎉",
			TextColor3 = Ui.COLORS.Gold,
			TextStrokeTransparency = 0.3,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.42, -SLOT / 2 - 6),
			Size = UDim2.fromOffset(420, 60),
			ZIndex = 32,
		})
		table.insert(labels, banner)
		Fx.confetti(80)
	end

	task.wait(if fast then 1 elseif anyRare then 3.5 else 2.2)

	-- 4) fade out
	tween(overlay, 0.25, { BackgroundTransparency = 1 })
	for _, label in ipairs(labels) do
		tween(label, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end
	tween(stageScale, 0.25, { Scale = 0 })
	task.wait(0.3)
	for _, stop in ipairs(stops) do
		stop()
	end
	for _, connection in ipairs(rainbows) do
		connection:Disconnect()
	end
	overlay:Destroy()
end

-- Plays hatches one after another.
function Hatch.play(petNames)
	table.insert(queue, petNames)
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

-- True while an animation is showing (auto-hatch waits for it).
function Hatch.busy()
	return playing
end

return Hatch
