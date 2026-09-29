-- New players pick their first pet (Dog or Cat) on a welcome screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Viewport = require(script.Parent.Viewport)
local Fx = require(script.Parent.Fx)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Starter = {}

local screen = Instance.new("Frame")
screen.Size = UDim2.fromScale(1, 1)
screen.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
screen.BackgroundTransparency = 0.45
screen.Visible = false
screen.ZIndex = 40
screen.Parent = Ui.gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(560, 420)
card.BackgroundColor3 = Ui.COLORS.Panel
card.ZIndex = 41
card.Parent = screen
Ui.corner(card, 24)
Ui.stroke(card, Ui.COLORS.Line, 1.5)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

Ui.label(card, {
	Text = "Welcome to Pet Park!",
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 0, 34),
	ZIndex = 42,
})
Ui.label(card, {
	Text = "Choose your first pet",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	Position = UDim2.fromOffset(0, 66),
	Size = UDim2.new(1, 0, 0, 20),
	ZIndex = 42,
})

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Position = UDim2.fromOffset(30, 104)
row.Size = UDim2.new(1, -60, 1, -130)
row.ZIndex = 42
row.Parent = card
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 24)
layout.Parent = row

local busy = false

local function choose(petName)
	if busy then
		return
	end
	busy = true
	local ok = remotes.ChooseStarter:InvokeServer(petName)
	busy = false
	if ok then
		screen.Visible = false
		Fx.confetti(70)
		Ui.toast("Say hi to your new " .. petName .. "! 🎉", Ui.COLORS.Green)
	end
end

for _, petName in ipairs(Config.STARTER_CHOICES) do
	local info = Config.PETS[petName]
	local option = Instance.new("TextButton")
	option.Size = UDim2.fromOffset(220, 280)
	option.BackgroundColor3 = Ui.COLORS.Soft
	option.Text = ""
	option.AutoButtonColor = true
	option.ZIndex = 42
	option.Parent = row
	Ui.corner(option, 20)
	local stroke = Ui.stroke(option, Ui.COLORS.Line, 1.5)

	local view = Instance.new("Frame")
	view.Size = UDim2.new(1, 0, 0, 190)
	view.BackgroundTransparency = 1
	view.ZIndex = 43
	view.Parent = option
	local vp, model = Viewport.pet(view, petName)
	vp.ZIndex = 43
	Viewport.spin(model, 1)

	Ui.label(option, { Text = petName, Position = UDim2.fromOffset(0, 194), Size = UDim2.new(1, 0, 0, 28), ZIndex = 43 })
	local pick = Ui.button(option, "Choose", info.BodyColor:Lerp(Ui.COLORS.Accent, 0.5), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -40, 0, 40),
		ZIndex = 43,
	})
	option.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Ui.COLORS.Accent, Thickness = 2.5 }):Play()
	end)
	option.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Ui.COLORS.Line, Thickness = 1.5 }):Play()
	end)
	Ui.bounce(option)
	option.Activated:Connect(function()
		choose(petName)
	end)
	pick.Activated:Connect(function()
		choose(petName)
	end)
end

local function refresh()
	local data = State.Data
	local show = data ~= nil and data.NeedsStarter == true
	if show and not screen.Visible then
		screen.Visible = true
		cardScale.Scale = 0.8
		TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	elseif not show then
		screen.Visible = false
	end
end

State.Changed.Event:Connect(refresh)

return Starter
