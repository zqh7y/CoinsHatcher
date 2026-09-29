-- Egg shrines: every egg in the hatchery gets its own little themed world
-- (Config.EGGS[i].Theme): a colored pad under the pedestal plus matching
-- props around it.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)

local Shrines = {}

local rng = Random.new(77)
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder up

-- Everything for one shrine is built relative to `space`: a CFrame at the
-- pedestal's floor center where -Z points AWAY from the walkway.
-- spot(x, out, y): x = sideways, out = how far outward, y = height.
local function shrineBuilder(model, space)
	local b = {}

	function b.spot(x, out, y)
		return space * CFrame.new(x, y or 0, -out)
	end

	function b.part(props)
		props.Material = props.Material or Enum.Material.SmoothPlastic
		props.CanCollide = props.CanCollide or false
		props.Parent = props.Parent or model
		return World.part(props)
	end

	function b.ball(x, out, y, size, color, material)
		return b.part({ Shape = BALL, Size = Vector3.one * size, CFrame = b.spot(x, out, y), Color = color, Material = material })
	end

	-- a flattened/stretched ball (SpecialMesh)
	function b.blob(x, out, y, size, scale, color, material)
		local p = b.ball(x, out, y, size, color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = scale
		mesh.Parent = p
		return p
	end

	function b.column(x, out, height, width, color, material)
		return b.part({
			Shape = CYL,
			Size = Vector3.new(height, width, width),
			CFrame = b.spot(x, out, height / 2) * UP,
			Color = color,
			Material = material,
		})
	end

	function b.particles(y, props)
		local anchor = b.part({ Size = Vector3.new(8, 1, 8), CFrame = b.spot(0, 0, y), Transparency = 1, CanQuery = false, CanTouch = false })
		local emitter = Instance.new("ParticleEmitter")
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.LightEmission = 0.6
		for k, v in pairs(props) do
			emitter[k] = v
		end
		emitter.Parent = anchor
		return emitter
	end

	-- A ring of things orbiting the egg (spun by the client, tag "Spin").
	function b.orbit(radius, height, count, makeItem, speed)
		local orbit = Instance.new("Model")
		orbit.Name = "Orbit"
		local hubCFrame = b.spot(0, 0, height) * CFrame.Angles(-math.pi / 2, 0, 0) -- local Z points up
		local hub = b.part({ Size = Vector3.one * 0.2, CFrame = hubCFrame, Transparency = 1, Parent = orbit })
		for i = 1, count do
			local a = i / count * math.pi * 2
			local item = makeItem(i)
			item.CFrame = hubCFrame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0)
			item.Parent = orbit
		end
		orbit.PrimaryPart = hub
		orbit:SetAttribute("SpinSpeed", speed or 0.6)
		orbit.Parent = model
		CollectionService:AddTag(orbit, "Spin")
		return orbit
	end

	return b
end

-- Theme builders -------------------------------------------------------------

local THEMES = {}

THEMES.Meadow = function(b)
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(5.5, 7)
		local x, out = math.cos(a) * d, math.sin(a) * d
		b.column(x, out, 1.2, 0.2, Color3.fromRGB(90, 170, 70))
		b.ball(x, out, 1.3, 0.9, Color3.new(1, 1, 1))
		b.ball(x, out, 1.45, 0.4, Color3.fromRGB(255, 210, 60))
	end
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		b.blob(math.cos(a) * 6.5, math.sin(a) * 6.5, 0.4, 1.6, Vector3.new(1, 0.6, 1), Color3.fromRGB(120, 200, 90))
	end
end

THEMES.Forest = function(b)
	for _, spot in ipairs({ { -5, 3 }, { 0, 6.5 }, { 5, 3 } }) do
		b.column(spot[1], spot[2], 3.5, 0.8, Color3.fromRGB(130, 90, 60))
		b.ball(spot[1], spot[2], 4.5, 3.4, Color3.fromRGB(80, 160, 80))
		b.ball(spot[1], spot[2], 6, 2.4, Color3.fromRGB(100, 180, 90))
	end
	for _, spot in ipairs({ { -6, -2 }, { 6, -1.5 } }) do
		b.column(spot[1], spot[2], 1, 0.5, Color3.fromRGB(255, 245, 225))
		b.blob(spot[1], spot[2], 1.1, 1.6, Vector3.new(1, 0.55, 1), Color3.fromRGB(255, 90, 100))
	end
end

THEMES.Ocean = function(b)
	local corals = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 170, 90), Color3.fromRGB(200, 120, 255) }
	for i, spot in ipairs({ { -5, 3 }, { 0, 6 }, { 5, 3.5 } }) do
		local color = corals[i]
		b.column(spot[1], spot[2], 3, 0.6, color)
		b.ball(spot[1], spot[2], 3.1, 1, color)
		b.part({ Shape = CYL, Size = Vector3.new(2, 0.45, 0.45), CFrame = b.spot(spot[1] + 0.6, spot[2], 2) * CFrame.Angles(0, 0, math.rad(50)), Color = color })
	end
	for _, spot in ipairs({ { -6, -2 }, { 6, -2 } }) do
		b.blob(spot[1], spot[2], 0.3, 1.4, Vector3.new(1, 0.4, 1.2), Color3.fromRGB(255, 225, 235))
	end
	b.particles(3, {
		Rate = 6,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(1.5, 2.5),
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new(0.35),
		Transparency = NumberSequence.new(0.3, 1),
		Color = ColorSequence.new(Color3.fromRGB(190, 235, 255)),
	})
end

THEMES.Lava = function(b)
	for _, spot in ipairs({ { -5, 3, 2.6 }, { 0, 6.5, 3.2 }, { 5, 3, 2.4 }, { -6, -2, 1.8 } }) do
		b.blob(spot[1], spot[2], 0.5, spot[3], Vector3.new(1.2, 0.8, 1), Color3.fromRGB(60, 45, 45))
		b.ball(spot[1] + 0.4, spot[2], spot[3] * 0.35, 0.5, Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	end
	b.particles(1.5, {
		Rate = 8,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Size = NumberSequence.new(0.3, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 30)),
	})
end

THEMES.Candy = function(b)
	for i, spot in ipairs({ { -5, 3 }, { 5, 3 } }) do
		b.column(spot[1], spot[2], 4, 0.3, Color3.new(1, 1, 1))
		b.part({
			Shape = CYL,
			Size = Vector3.new(0.4, 2.6, 2.6),
			CFrame = b.spot(spot[1], spot[2], 4.6) * CFrame.Angles(0, math.rad(90), 0),
			Color = if i == 1 then Color3.fromRGB(255, 110, 160) else Color3.fromRGB(120, 200, 255),
		})
	end
	for i = 0, 3 do
		local color = if i % 2 == 0 then Color3.fromRGB(255, 80, 100) else Color3.new(1, 1, 1)
		b.part({ Shape = CYL, Size = Vector3.new(1, 0.6, 0.6), CFrame = b.spot(0, 6.5, 0.5 + i) * UP, Color = color })
	end
	local gumdrops = { Color3.fromRGB(255, 150, 60), Color3.fromRGB(120, 220, 120), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 220, 70) }
	for i, spot in ipairs({ { -6, -2 }, { 6, -2 }, { -3, 6 }, { 3, 6 } }) do
		b.blob(spot[1], spot[2], 0.3, 1.5, Vector3.new(1, 0.9, 1), gumdrops[i])
	end
end

THEMES.Snow = function(b)
	for _, spot in ipairs({ { -5, 3, 4 }, { 0, 6.5, 5 }, { 5, 3, 3.5 } }) do
		b.part({
			Size = Vector3.new(1, spot[3], 1),
			CFrame = b.spot(spot[1], spot[2], spot[3] / 2) * CFrame.Angles(0, math.rad(45), rng:NextNumber(-0.2, 0.2)),
			Color = Color3.fromRGB(170, 225, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
	for _, spot in ipairs({ { -6, -2 }, { 6, -2 }, { -2.5, 6.5 } }) do
		b.blob(spot[1], spot[2], 0.2, 2.4, Vector3.new(1, 0.5, 1), Color3.new(1, 1, 1))
	end
	b.particles(8, {
		Rate = 10,
		Lifetime = NumberRange.new(3, 4),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new(0.25),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
	})
end

THEMES.Jungle = function(b)
	for i = 1, 5 do
		local a = math.rad(200 + i * 28)
		local x, out = math.cos(a) * 4.5, -math.sin(a) * 4.5
		b.part({
			Size = Vector3.new(1.6, 0.2, 4.5),
			CFrame = b.spot(x, out, 1.8) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(35), 0, 0),
			Color = Color3.fromRGB(60, 160, 70):Lerp(Color3.fromRGB(110, 200, 80), i / 5),
		})
	end
	for _, spot in ipairs({ { -6, -2, Color3.fromRGB(255, 80, 110) }, { 6, -2, Color3.fromRGB(255, 170, 40) } }) do
		b.column(spot[1], spot[2], 1.2, 0.25, Color3.fromRGB(70, 150, 60))
		b.ball(spot[1], spot[2], 1.4, 1.1, spot[3])
	end
end

THEMES.Desert = function(b)
	for _, spot in ipairs({ { -5, 3, 4 }, { 5, 4, 3 } }) do
		local green = Color3.fromRGB(80, 160, 80)
		b.column(spot[1], spot[2], spot[3], 1, green)
		b.ball(spot[1], spot[2], spot[3], 1, green)
		-- little arm
		b.part({ Shape = CYL, Size = Vector3.new(1, 0.6, 0.6), CFrame = b.spot(spot[1] + 0.8, spot[2], spot[3] * 0.5), Color = green })
		b.column(spot[1] + 1.2, spot[2], spot[3] * 0.75, 0.6, green)
	end
	for _, spot in ipairs({ { 0, 6.5 }, { -6, -2 }, { 6, -2 } }) do
		b.blob(spot[1], spot[2], 0, 3, Vector3.new(1.3, 0.35, 1), Color3.fromRGB(240, 210, 150))
	end
end

THEMES.Space = function(b)
	b.orbit(5, 6.5, 3, function(i)
		local colors = { Color3.fromRGB(255, 150, 90), Color3.fromRGB(120, 200, 255), Color3.fromRGB(200, 130, 255) }
		return b.part({ Shape = BALL, Size = Vector3.one * (1 + i * 0.3), Color = colors[i], Parent = workspace })
	end, 0.5)
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		b.ball(math.cos(a) * 6, math.sin(a) * 6, rng:NextNumber(0.3, 1.5), 0.4, Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
	end
	b.particles(6, {
		Rate = 6,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.2, 0.5),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
	})
end

THEMES.Magic = function(b)
	b.orbit(4.5, 7, 4, function()
		local crystal = b.part({
			Size = Vector3.new(0.8, 1.8, 0.8),
			Color = Color3.fromRGB(200, 140, 255),
			Material = Enum.Material.Neon,
			Parent = workspace,
		})
		return crystal
	end, 0.8)
	for _, spot in ipairs({ { -5.5, 2 }, { 5.5, 2 }, { 0, 6.5 } }) do
		b.part({
			Size = Vector3.new(1, 3, 1),
			CFrame = b.spot(spot[1], spot[2], 1.5) * CFrame.Angles(0, math.rad(45), 0.2),
			Color = Color3.fromRGB(170, 110, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
		})
	end
	b.particles(4, {
		Rate = 8,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.5, 1),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(230, 180, 255), Color3.fromRGB(150, 200, 255)),
	})
end

THEMES.Mythic = function(b)
	local gold = Color3.fromRGB(255, 205, 70)
	for _, spot in ipairs({ { -5, 3 }, { 5, 3 }, { -3.5, 6 }, { 3.5, 6 } }) do
		b.column(spot[1], spot[2], 5, 1, Color3.fromRGB(255, 250, 235))
		b.part({ Size = Vector3.new(1.6, 0.5, 1.6), CFrame = b.spot(spot[1], spot[2], 5.2), Color = gold })
		b.ball(spot[1], spot[2], 5.9, 0.8, gold, Enum.Material.Neon)
	end
	b.particles(4, {
		Rate = 10,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.8, 1.5),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(gold, Color3.fromRGB(255, 255, 200)),
	})
end

THEMES.Party = function(b)
	-- balloons on strings, gift boxes and confetti
	local balloonColors = {
		Color3.fromRGB(255, 90, 130),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(90, 190, 255),
		Color3.fromRGB(150, 110, 255),
		Color3.fromRGB(90, 220, 140),
	}
	for i, spot in ipairs({ { -6.5, 2 }, { -4.5, 5.5 }, { 0, 7 }, { 4.5, 5.5 }, { 6.5, 2 } }) do
		local height = 6 + (i % 2) * 1.5
		b.column(spot[1], spot[2], height, 0.08, Color3.new(1, 1, 1))
		b.blob(spot[1], spot[2], height + 1, 1.8, Vector3.new(0.9, 1.15, 0.9), balloonColors[i])
	end
	for i, spot in ipairs({ { -6.5, -3.5 }, { 6.5, -3.5 }, { -3, 7.5 } }) do
		local size = 1.6 + (i % 2) * 0.5
		b.part({ Size = Vector3.one * size, CFrame = b.spot(spot[1], spot[2], size / 2) * CFrame.Angles(0, i, 0), Color = balloonColors[i + 1] })
		b.part({ Size = Vector3.new(size + 0.1, size + 0.1, 0.35), CFrame = b.spot(spot[1], spot[2], size / 2) * CFrame.Angles(0, i, 0), Color = Color3.new(1, 1, 1) })
	end
	b.particles(9, {
		Rate = 14,
		Lifetime = NumberRange.new(2.5, 3.5),
		Speed = NumberRange.new(0.5, 1),
		EmissionDirection = Enum.NormalId.Bottom,
		RotSpeed = NumberRange.new(-200, 200),
		Size = NumberSequence.new(0.3),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, balloonColors[1]),
			ColorSequenceKeypoint.new(0.33, balloonColors[2]),
			ColorSequenceKeypoint.new(0.66, balloonColors[3]),
			ColorSequenceKeypoint.new(1, balloonColors[4]),
		}),
	})
end

-- Pad colors under each shrine
local PAD = {
	Meadow = Color3.fromRGB(190, 235, 170),
	Forest = Color3.fromRGB(150, 205, 140),
	Ocean = Color3.fromRGB(170, 220, 240),
	Lava = Color3.fromRGB(110, 70, 65),
	Candy = Color3.fromRGB(255, 200, 225),
	Snow = Color3.fromRGB(240, 248, 255),
	Jungle = Color3.fromRGB(120, 190, 110),
	Desert = Color3.fromRGB(245, 225, 175),
	Space = Color3.fromRGB(60, 55, 110),
	Magic = Color3.fromRGB(205, 180, 255),
	Mythic = Color3.fromRGB(255, 235, 170),
	Party = Color3.fromRGB(255, 225, 150),
}

-- Builds the shrine for egg `eggIndex` into its model. `outward` points away
-- from the walkway (the shrine's back).
function Shrines.build(model, eggIndex, floorPosition, outward)
	local egg = Config.EGGS[eggIndex]
	local space = CFrame.lookAt(floorPosition, floorPosition + outward.Unit)
	local b = shrineBuilder(model, space)

	-- colored pad under the pedestal
	b.part({
		Name = "Pad",
		Shape = CYL,
		Size = Vector3.new(0.12, 14, 14),
		CFrame = b.spot(0, 0, 0.1) * UP,
		Color = PAD[egg.Theme] or egg.Color:Lerp(Color3.new(1, 1, 1), 0.6),
	})

	local theme = THEMES[egg.Theme]
	if theme then
		theme(b)
	end
end

return Shrines
