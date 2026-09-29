-- The hatch animation, for 1 or 3 eggs:
--   1) the eggs drop in and bounce
--   2) they wobble harder and harder while cracks appear
--   3) flash! the pets pop out in front of spinning light rays in their
--      rarity color, with their name, a rarity chip and their odds
-- Really rare pets (Mythical, Huge or 1 in 10,000+) get a special version:
-- the screen goes dark, the egg glows and shakes longer with a heartbeat,
-- two colored flashes, rainbow rays, a big title and extra confetti.
-- Auto-hatching plays a quicker version.
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
local current -- the overlay on screen, removed if an animation errors

local SLOT = 240 -- width of each egg/pet on screen

local function tween(obj, time, props, style, direction)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Spinning light rays behind a pet. Each bar is two opposite rays that
-- fade out toward their tips. Returns the frame and a stop function.
local function rays(parent, color, rainbow)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromScale(1.7, 1.7)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 0
	holder.Parent = parent
	local bars = {}
	for k = 0, 5 do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.09, 1)
		bar.Rotation = k * 30
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.ZIndex = 0
		bar.Parent = holder
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = bar
		table.insert(bars, bar)
	end
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.45, 0.45)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.45
	glow.ZIndex = 0
	glow.Parent = holder
	Ui.corner(glow, 0.5)

	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		holder.Rotation = (t * (if rainbow then 70 else 35)) % 360
		if rainbow then
			for k, bar in ipairs(bars) do
				bar.BackgroundColor3 = Color3.fromHSV((t * 0.4 + k / #bars) % 1, 0.6, 1)
			end
			glow.BackgroundColor3 = Color3.fromHSV((t * 0.4) % 1, 0.5, 1)
		end
	end)
	return holder, function()
		connection:Disconnect()
	end
end

-- A white crack line drawn over an egg.
local function crack(parent, index)
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5 + (index - 2) * 0.07, 0.45 + (index % 2) * 0.06)
	line.Size = UDim2.fromOffset(0, 4)
	line.Rotation = index * 55 - 30
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.ZIndex = 3
	line.Parent = parent
	tween(line, 0.12, { Size = UDim2.fromOffset(SLOT * 0.22, 4) })
end

local RARITY_TITLES = {
	Mythical = "MYTHICAL!",
	Huge = "HUGE!!",
}

local function play(petNames)
	local fast = Hatch.fast
	local count = #petNames
	local anyRare, epicPet = false, nil
	for _, petName in ipairs(petNames) do
		if Config.isRare(petName) then
			anyRare = true
		end
		if Config.isEpic(petName) then
			epicPet = petName
		end
	end
	local epic = epicPet ~= nil
	if epic then
		fast = false -- always show the special animation in full
	end

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = if epic then Color3.fromRGB(5, 0, 15) else Color3.fromRGB(20, 10, 40)
	overlay.BackgroundTransparency = 1
	overlay.ZIndex = 30
	overlay.Parent = Ui.gui
	current = overlay
	tween(overlay, 0.25, { BackgroundTransparency = if epic then 0.08 elseif fast then 0.6 else 0.35 })

	local stage = Instance.new("Frame")
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, -0.3)
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

	-- 1) the eggs drop in and bounce
	local eggs = {}
	for i, petName in ipairs(petNames) do
		local _, egg = Viewport.egg(slots[i], Config.PETS[petName].Egg)
		eggs[i] = egg
	end
	local home = UDim2.fromScale(0.5, 0.42)
	tween(stage, if fast then 0.3 else 0.55, { Position = home }, Enum.EasingStyle.Bounce).Completed:Wait()

	-- the special one: a glow grows behind the egg that holds it
	local stopEpicGlow
	if epic then
		local index = table.find(petNames, epicPet) or 1
		local holder
		holder, stopEpicGlow = rays(slots[index], Config.PETS[epicPet].Color, true)
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(0.2, 0.2)
		tween(holder, 2.6, { Size = UDim2.fromScale(1.5, 1.5) })
	end

	-- 2) wobble harder and harder, with cracks; the special one shakes the
	-- screen and pulses like a heartbeat
	local wobbleTime = if epic then 2.8 elseif fast then 0.6 else 1.4
	local start = os.clock()
	local cracked = 0
	local wobble = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local strength = math.min(t / wobbleTime, 1)
		for i, egg in ipairs(eggs) do
			egg:PivotTo(CFrame.Angles(0, 0, math.sin(t * (8 + 24 * strength) + i) * 0.4 * strength))
		end
		local beat = if epic then math.max(0, math.sin(t * 7)) ^ 8 * 0.1 else 0
		stageScale.Scale = 1 + strength * 0.15 + beat
		if epic and strength > 0.5 then
			local shake = math.floor((strength - 0.5) * 16)
			stage.Position = home + UDim2.fromOffset(math.random(-shake, shake), math.random(-shake, shake))
		end
		local wantCracks = if strength > 0.85 then 3 elseif strength > 0.6 then 2 elseif strength > 0.35 then 1 else 0
		while cracked < wantCracks do
			cracked += 1
			for _, slot in ipairs(slots) do
				crack(slot, cracked)
			end
		end
	end)
	task.wait(wobbleTime)
	wobble:Disconnect()
	stage.Position = home
	if stopEpicGlow then
		stopEpicGlow()
	end

	-- 3) flash! (the special one flashes twice, in color)
	local function flash(color, from)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = from
		f.ZIndex = 40
		f.Parent = overlay
		tween(f, 0.5, { BackgroundTransparency = 1 })
	end
	if epic then
		flash(Config.PETS[epicPet].Color, 0)
		task.wait(0.18)
	end
	flash(Color3.new(1, 1, 1), if fast then 0.5 else 0)

	-- the pets pop out
	local stops = {}
	local labels = {}
	for i, petName in ipairs(petNames) do
		local info = Config.PETS[petName]
		local slot = slots[i]
		Ui.clear(slot)
		local special = Config.isEpic(petName)
		local color = info.Color

		local _, stopRays = rays(slot, color, special or info.Mutation == "Rainbow")
		table.insert(stops, stopRays)

		local view = Instance.new("Frame")
		view.Size = UDim2.fromScale(1, 0.85)
		view.BackgroundTransparency = 1
		view.ZIndex = 1
		view.Parent = slot
		local _, pet = Viewport.pet(view, petName)
		table.insert(stops, Viewport.spin(pet, 2))

		local x = (i - (count + 1) / 2) * SLOT
		local name = Ui.label(overlay, {
			Text = petName,
			TextColor3 = color,
			TextStrokeTransparency = 0.2,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, x, 0.42, SLOT / 2 + 4),
			Size = UDim2.fromOffset(SLOT - 10, 36),
			ZIndex = 32,
		})
		local chip = Ui.label(overlay, {
			Text = info.Rarity:upper(),
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.15),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, x, 0.42, SLOT / 2 + 44),
			Size = UDim2.fromOffset(120, 24),
			ZIndex = 32,
		})
		Ui.corner(chip, 0.5)
		local chipPad = Instance.new("UIPadding")
		chipPad.PaddingTop = UDim.new(0, 4)
		chipPad.PaddingBottom = UDim.new(0, 4)
		chipPad.Parent = chip
		local odds = Ui.label(overlay, {
			Text = Config.chanceText(petName) .. "  ·  ⚔️ " .. Config.formatNumber(info.Power),
			TextColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, x, 0.42, SLOT / 2 + 74),
			Size = UDim2.fromOffset(SLOT - 10, 20),
			ZIndex = 32,
		})
		for _, label in ipairs({ name, chip, odds }) do
			table.insert(labels, label)
			local s = Instance.new("UIScale")
			s.Scale = 0
			s.Parent = label
			tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end

		-- huge, mythical and mutated pets get a rainbow name
		if special or info.Mutation then
			local connection = RunService.RenderStepped:Connect(function()
				name.TextColor3 = Color3.fromHSV((os.clock() * 0.5 + i * 0.2) % 1, 0.6, 1)
			end)
			table.insert(stops, function()
				connection:Disconnect()
			end)
		end
	end
	stageScale.Scale = 0.2
	tween(stageScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)

	-- a banner for rare ones, a huge pulsing title for the special ones
	if epic then
		local info = Config.PETS[epicPet]
		local banner = Ui.label(overlay, {
			Text = RARITY_TITLES[info.Rarity] or "INSANE LUCK!",
			TextStrokeTransparency = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.42, -SLOT / 2 - 10),
			Size = UDim2.fromOffset(560, 80),
			ZIndex = 33,
		})
		table.insert(labels, banner)
		local bannerScale = Instance.new("UIScale")
		bannerScale.Scale = 3
		bannerScale.Parent = banner
		tween(bannerScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		local connection = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			banner.TextColor3 = Color3.fromHSV((t * 0.6) % 1, 0.55, 1)
			banner.Rotation = math.sin(t * 3) * 3
		end)
		table.insert(stops, function()
			connection:Disconnect()
		end)
		Fx.confetti(120)
		task.delay(0.8, Fx.confetti, 120)
	elseif anyRare then
		local banner = Ui.label(overlay, {
			Text = "SO RARE!",
			TextColor3 = Ui.COLORS.Gold,
			TextStrokeTransparency = 0.2,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.42, -SLOT / 2 - 6),
			Size = UDim2.fromOffset(420, 56),
			ZIndex = 32,
		})
		table.insert(labels, banner)
		Fx.confetti(70)
	end

	task.wait(if epic then 4.5 elseif fast then 1 elseif anyRare then 3 else 2)

	-- 4) fade out
	tween(overlay, 0.25, { BackgroundTransparency = 1 })
	for _, label in ipairs(labels) do
		tween(label, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 })
	end
	tween(stageScale, 0.25, { Scale = 0 })
	task.wait(0.3)
	for _, stop in ipairs(stops) do
		stop()
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
				if current then
					current:Destroy()
				end
			end
			current = nil
		end
		playing = false
	end)
end

-- True while an animation is showing (auto-hatch waits for it).
function Hatch.busy()
	return playing
end

return Hatch
