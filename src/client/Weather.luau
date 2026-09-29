-- Weather over the main area that matches the area of your rebirth
-- (Config.areaTheme): falling leaves in the meadow, dust in the desert, snow
-- on the ice, sprinkles in candy land, bubbles in the ocean, embers at
-- sunset, sparkles in magic land, petals in mint land, stars in space and
-- glitter in the golden area. Only this player sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local Weather = {}

local MAIN_CENTER = Vector3.new(0, 0, 0) -- same as World.MAIN_CENTER on the server
local SIZE = 110 -- covers the whole main area

-- How each kind of weather moves: from the sky (Top) falling down, or from
-- the ground (Bottom) rising up.
local STYLES = {
	leaves = { From = "Sky", Rate = 14, Size = 0.35, Speed = { 2, 4 }, Life = { 7, 10 }, Spin = 120, Drift = 3 },
	dust = { From = "Sky", Rate = 30, Size = 0.18, Speed = { 1, 2 }, Life = { 8, 12 }, Spin = 0, Drift = 7, Faint = true },
	snow = { From = "Sky", Rate = 45, Size = 0.3, Speed = { 3, 5 }, Life = { 7, 10 }, Spin = 30, Drift = 2 },
	sprinkles = { From = "Sky", Rate = 30, Size = 0.25, Speed = { 4, 6 }, Life = { 6, 8 }, Spin = 300, Drift = 1, Rainbow = true },
	bubbles = { From = "Ground", Rate = 18, Size = 0.5, Speed = { 2, 4 }, Life = { 5, 8 }, Spin = 0, Drift = 1, Faint = true },
	embers = { From = "Ground", Rate = 16, Size = 0.25, Speed = { 2, 4 }, Life = { 4, 7 }, Spin = 60, Drift = 2, Glow = true },
	sparkles = { From = "Sky", Rate = 20, Size = 0.35, Speed = { 1, 2 }, Life = { 5, 8 }, Spin = 180, Drift = 1, Glow = true },
	petals = { From = "Sky", Rate = 16, Size = 0.35, Speed = { 2, 3 }, Life = { 8, 11 }, Spin = 160, Drift = 4 },
	stars = { From = "Sky", Rate = 24, Size = 0.3, Speed = { 0.5, 1 }, Life = { 4, 7 }, Spin = 0, Drift = 0.5, Glow = true, Twinkle = true },
	glitter = { From = "Sky", Rate = 26, Size = 0.25, Speed = { 2, 3 }, Life = { 6, 9 }, Spin = 200, Drift = 1, Glow = true },
}

local SKY_Y = 45

local emitterPart = Instance.new("Part")
emitterPart.Name = "Weather"
emitterPart.Anchored = true
emitterPart.CanCollide = false
emitterPart.CanQuery = false
emitterPart.CanTouch = false
emitterPart.CastShadow = false
emitterPart.Transparency = 1
emitterPart.Size = Vector3.new(SIZE, 1, SIZE)
emitterPart.Position = MAIN_CENTER + Vector3.new(0, SKY_Y, 0)
emitterPart.Parent = workspace

local emitter = Instance.new("ParticleEmitter")
emitter.Shape = Enum.ParticleEmitterShape.Box
emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
emitter.Parent = emitterPart

local shown = nil

local function apply()
	local data = State.Data
	if not data then
		return
	end
	local theme = Config.areaTheme(data.Rebirths)
	if theme.Weather == shown then
		return
	end
	shown = theme.Weather
	local style = STYLES[theme.Weather] or STYLES.leaves

	local fromGround = style.From == "Ground"
	emitterPart.Position = MAIN_CENTER + Vector3.new(0, if fromGround then 1.5 else SKY_Y, 0)
	emitter.EmissionDirection = if fromGround then Enum.NormalId.Top else Enum.NormalId.Bottom
	emitter.Rate = style.Rate
	emitter.Lifetime = NumberRange.new(style.Life[1], style.Life[2])
	emitter.Speed = NumberRange.new(style.Speed[1], style.Speed[2])
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.RotSpeed = NumberRange.new(-style.Spin, style.Spin)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Acceleration = Vector3.new(style.Drift, 0, style.Drift * 0.5)
	emitter.LightEmission = if style.Glow then 1 else 0
	emitter.LightInfluence = if style.Glow then 0 else 1
	emitter.Size = if style.Twinkle
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, style.Size),
			NumberSequenceKeypoint.new(1, 0),
		})
		else NumberSequence.new(style.Size)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, if style.Faint then 0.4 else 0.05),
		NumberSequenceKeypoint.new(0.85, if style.Faint then 0.4 else 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = if style.Rainbow
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 70)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(110, 210, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 170, 255)),
		})
		else ColorSequence.new(theme.WeatherColor)
	emitter:Clear()
end

State.Changed.Event:Connect(apply)
apply()

-- only snow/fall while you're in the main area
task.spawn(function()
	while true do
		task.wait(1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		emitter.Enabled = root ~= nil and (root.Position - MAIN_CENTER).Magnitude < 200
	end
end)

return Weather
