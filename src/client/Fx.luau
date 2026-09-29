-- Juicy UI effects: confetti, icons flying into the coin/diamond counters,
-- and a big celebration banner.
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

local Fx = {}

-- Set by the HUD: [name] = the counter frame icons fly into ("Coins", "Diamonds").
Fx.targets = {}

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(110, 210, 120),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 160, 70),
}

local function tween(obj, time, props, style, direction)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Confetti raining down the screen.
function Fx.confetti(amount)
	for _ = 1, amount or 40 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		piece.Position = UDim2.new(math.random(), 0, 0, -20)
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 60
		piece.Parent = Ui.gui
		local time = math.random(14, 24) / 10
		tween(piece, time, {
			Position = UDim2.new(piece.Position.X.Scale + math.random(-15, 15) / 100, 0, 1.05, 0),
			Rotation = piece.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(time, function()
			piece:Destroy()
		end)
	end
end

-- Makes a counter do a quick bump.
function Fx.bump(target)
	local scale = target:FindFirstChild("BumpScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "BumpScale"
		scale.Parent = target
	end
	scale.Scale = 1.18
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Little icons burst out of a spot in the world and fly into a counter.
function Fx.fly(worldPos, icon, targetName, count)
	local target = Fx.targets[targetName]
	local camera = workspace.CurrentCamera
	if not target or not camera then
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(worldPos)
	if not onScreen then
		return
	end
	local inset = GuiService:GetGuiInset()
	local from = Vector2.new(screen.X, screen.Y) - inset
	local to = target.AbsolutePosition + target.AbsoluteSize / 2

	for i = 1, count or 4 do
		local label = Ui.label(Ui.gui, {
			Text = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.fromOffset(from.X, from.Y),
			TextStrokeTransparency = 1,
			ZIndex = 50,
		})
		-- burst out a little, then zoom into the counter
		local spread = Vector2.new(math.random(-60, 60), math.random(-60, 20))
		task.spawn(function()
			task.wait((i - 1) * 0.05)
			tween(label, 0.18, { Position = UDim2.fromOffset(from.X + spread.X, from.Y + spread.Y) })
			task.wait(0.18)
			tween(label, 0.45, { Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.45)
			label:Destroy()
			Fx.bump(target)
		end)
	end
end

-- A big celebration: flash, huge text and lots of confetti.
function Fx.celebrate(text, color)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.2
	flash.ZIndex = 55
	flash.Parent = Ui.gui
	tween(flash, 0.6, { BackgroundTransparency = 1 })

	local label = Ui.label(Ui.gui, {
		Text = text,
		TextColor3 = color or Ui.COLORS.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 110),
		TextStrokeTransparency = 0,
		ZIndex = 58,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	Fx.confetti(90)

	task.delay(2.2, function()
		tween(label, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.wait(0.45)
		label:Destroy()
		flash:Destroy()
	end)
end

return Fx
