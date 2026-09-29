-- The new-player guide: a small card at the top of the screen tells new
-- players what to do next, and a glowing beam from them (plus a bouncing
-- arrow) points to where to go. Steps:
--   1) walk into the coin circle: your pets break coins
--   2) buy a board upgrade (More Coins)
--   3) save up for your first egg (progress bar)
--   4) walk through the portal to the hatchery
--   5) hatch the Basic Egg
--   6) buy something in the Upgrades tree
--   7) rebirth when you can (the end)
-- The step is saved on the server; it can be skipped any time.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local UpgradeTree = require(script.Parent.UpgradeTree)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Guide = {}

local MAIN_CENTER = Vector3.new(0, 0, 0) -- same as World on the server
local EGG_CENTER = Vector3.new(0, 0, 1000)
local GOLD = Color3.fromRGB(255, 200, 50)

local function coins()
	return player:GetAttribute("Coins") or 0
end
local function anyLevel(list, data)
	for _, upgrade in ipairs(list) do
		if (data.Upgrades[upgrade.Id] or 0) > 0 then
			return true
		end
	end
	return false
end
local function root()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

-- where the targets are
local function coinZone()
	return MAIN_CENTER + Vector3.new(0, 2, 0)
end
local function board()
	local main = workspace:FindFirstChild("MainArea")
	local part = main and main:FindFirstChild("UpgradeBoard")
	return part and part.Position
end
local function hatcheryPortal()
	for _, part in ipairs(CollectionService:GetTagged("Portal")) do
		if part:GetAttribute("Destination") == "Eggs" then
			return part.Position
		end
	end
	return nil
end
local function firstEgg()
	local eggArea = workspace:FindFirstChild("EggArea")
	local eggs = eggArea and eggArea:FindFirstChild("Eggs")
	if eggs then
		for _, model in ipairs(eggs:GetChildren()) do
			if model:GetAttribute("EggIndex") == 1 and model:FindFirstChild("Egg") then
				return model.Egg.Position
			end
		end
	end
	return nil
end

local firstEggPrice = Config.eggCost(1)
local startCoins = 0

local STEPS = {
	{
		Icon = "💰",
		Text = "Walk into the coin circle! Your pets break the coins for you.",
		Target = coinZone,
		Start = function()
			startCoins = coins()
		end,
		Done = function()
			return coins() > startCoins
		end,
	},
	{
		Icon = "📈",
		Text = "Buy \"More Coins\" on the upgrade board to get more coins!",
		Target = board,
		Done = function(data)
			return anyLevel(Config.AREA_UPGRADES, data)
		end,
	},
	{
		Icon = "🥚",
		Text = ("Save up %s coins for your first egg!"):format(Config.formatNumber(firstEggPrice)),
		Target = coinZone,
		Progress = function()
			return math.clamp(coins() / firstEggPrice, 0, 1)
		end,
		Done = function(data)
			return coins() >= firstEggPrice or (data.Hatched or 0) > 0
		end,
	},
	{
		Icon = "🌀",
		Text = "Walk through the glowing portal to the Hatchery!",
		Target = hatcheryPortal,
		Done = function(data)
			local r = root()
			return (r ~= nil and (r.Position - EGG_CENTER).Magnitude < 250) or (data.Hatched or 0) > 0
		end,
	},
	{
		Icon = "✨",
		Text = "Walk up to the Basic Egg and press E (or tap Buy 1) to hatch a pet!",
		Target = firstEgg,
		Done = function(data)
			return (data.Hatched or 0) > 0
		end,
	},
	{
		Icon = "🌳",
		Text = "Open Upgrades at the bottom and buy your first upgrade!",
		PointAtButton = true,
		Done = function(data)
			return anyLevel(Config.UPGRADES, data)
		end,
	},
	{
		Icon = "🔄",
		Text = "Keep going! When you have enough coins, press Rebirth: stronger coins and a new egg!",
		Final = true,
	},
}

-- The card at the top -------------------------------------------------------------------

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 84)
card.Size = UDim2.fromOffset(540, 86)
card.BackgroundColor3 = Ui.COLORS.Panel
card.Visible = false
card.Parent = Ui.gui
Ui.corner(card, 18)
local cardStroke = Ui.stroke(card, GOLD, 3)
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

local icon = Ui.label(card, {
	Position = UDim2.fromOffset(12, 13),
	Size = UDim2.fromOffset(60, 60),
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(255, 244, 210),
})
Ui.corner(icon, 0.5)
local iconPad = Instance.new("UIPadding")
iconPad.PaddingTop = UDim.new(0, 12)
iconPad.PaddingBottom = UDim.new(0, 12)
iconPad.Parent = icon
local stepLabel = Ui.label(card, {
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(84, 8),
	Size = UDim2.fromOffset(200, 16),
})
local text = Ui.label(card, {
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	Position = UDim2.fromOffset(84, 26),
	Size = UDim2.new(1, -100, 0, 38),
})
local bar = Instance.new("Frame")
bar.Position = UDim2.fromOffset(84, 68)
bar.Size = UDim2.new(1, -100, 0, 8)
bar.BackgroundColor3 = Ui.COLORS.Line
bar.BorderSizePixel = 0
bar.Parent = card
Ui.corner(bar, 0.5)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = bar
Ui.corner(fill, 0.5)
Ui.gradient(fill, GOLD, Ui.COLORS.Green, 0)

local skip = Instance.new("TextButton")
skip.AnchorPoint = Vector2.new(1, 0)
skip.Position = UDim2.new(1, -12, 0, 6)
skip.Size = UDim2.fromOffset(80, 18)
skip.BackgroundTransparency = 1
skip.Text = "skip guide"
skip.Font = Ui.FONT_BODY
skip.TextSize = 13
skip.TextColor3 = Ui.COLORS.SubText
skip.Parent = card

local gotIt = Ui.button(card, "Got it!", Ui.COLORS.Green, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -12, 1, -10),
	Size = UDim2.fromOffset(110, 36),
	Visible = false,
})

-- The beam and arrows ---------------------------------------------------------------------

local targetPart = Instance.new("Part")
targetPart.Name = "GuideTarget"
targetPart.Anchored = true
targetPart.CanCollide = false
targetPart.CanQuery = false
targetPart.CanTouch = false
targetPart.Transparency = 1
targetPart.Size = Vector3.one * 0.2
targetPart.Parent = workspace
local targetAttachment = Instance.new("Attachment")
targetAttachment.Parent = targetPart

local beam = Instance.new("Beam")
beam.Attachment1 = targetAttachment
beam.FaceCamera = true
beam.Width0 = 0.6
beam.Width1 = 0.6
beam.LightEmission = 1
beam.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
beam.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.9),
	NumberSequenceKeypoint.new(0.2, 0.25),
	NumberSequenceKeypoint.new(1, 0.1),
})
beam.Enabled = false
beam.Parent = targetPart

-- a big bouncing arrow over the target
local arrow = Instance.new("BillboardGui")
arrow.Size = UDim2.fromOffset(70, 70)
arrow.AlwaysOnTop = true
arrow.LightInfluence = 0
arrow.Adornee = targetPart
arrow.Enabled = false
arrow.Parent = player:WaitForChild("PlayerGui")
local arrowLabel = Ui.label(arrow, {
	Text = "⬇",
	TextColor3 = GOLD,
	TextStrokeTransparency = 0,
	Size = UDim2.fromScale(1, 1),
})

-- an arrow on the screen pointing at the Upgrades button
local screenArrow = Ui.label(Ui.gui, {
	Text = "⬇",
	TextColor3 = GOLD,
	TextStrokeTransparency = 0,
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(60, 60),
	Visible = false,
	ZIndex = 20,
})

-- Running it --------------------------------------------------------------------------------

local step = 0 -- 0 = off
local started = false

local function show(index)
	step = index
	local def = STEPS[index]
	if not def then
		card.Visible = false
		return
	end
	if def.Start then
		def.Start()
	end
	icon.Text = def.Icon
	stepLabel.Text = ("Step %d of %d"):format(index, #STEPS)
	text.Text = def.Text
	bar.Visible = def.Progress ~= nil
	gotIt.Visible = def.Final == true
	card.Visible = true
	cardScale.Scale = 0.7
	TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function finish()
	step = 0
	card.Visible = false
	beam.Enabled = false
	arrow.Enabled = false
	screenArrow.Visible = false
	remotes.SetGuideStep:FireServer(0)
end

local function advance()
	local nextStep = step + 1
	Fx.confetti(25)
	Ui.toast("✅ Nice! Next step", Ui.COLORS.Green)
	remotes.SetGuideStep:FireServer(nextStep)
	show(nextStep)
end

skip.Activated:Connect(finish)
gotIt.Activated:Connect(function()
	Fx.confetti(60)
	finish()
end)

-- starts once the data has loaded and the starter pet is picked
local function tryStart()
	local data = State.Data
	if started or not data or data.NeedsStarter then
		return
	end
	started = true
	local saved = data.Guide
	if saved == nil then
		saved = if (data.Hatched or 0) > 0 then 0 else 1
	end
	if saved >= 1 and saved <= #STEPS then
		show(saved)
	end
end
State.Changed.Event:Connect(tryStart)
tryStart()

-- check the current step and move the beam/arrows
local attachment = nil
RunService.Heartbeat:Connect(function()
	local data = State.Data
	local def = STEPS[step]
	if step == 0 or not def or not data then
		beam.Enabled = false
		arrow.Enabled = false
		screenArrow.Visible = false
		return
	end

	-- done? then the next step
	if def.Done and def.Done(data) then
		advance()
		return
	end
	if def.Progress then
		fill.Size = UDim2.fromScale(math.max(def.Progress(), 0.03), 1)
	end
	cardStroke.Color = GOLD:Lerp(Color3.new(1, 1, 1), (math.sin(os.clock() * 4) + 1) * 0.2)

	-- the beam from you to the target
	local r = root()
	local target = def.Target and def.Target()
	if r and target and (target - r.Position).Magnitude < 400 then
		if not attachment or attachment.Parent ~= r then
			attachment = Instance.new("Attachment")
			attachment.Name = "GuideAttachment"
			attachment.Parent = r
			beam.Attachment0 = attachment
		end
		local bounce = math.abs(math.sin(os.clock() * 3)) * 1.5
		targetPart.Position = target + Vector3.new(0, 4 + bounce, 0)
		beam.Enabled = true
		arrow.Enabled = true
	else
		beam.Enabled = false
		arrow.Enabled = false
	end

	-- the arrow pointing at the Upgrades button
	local button = UpgradeTree.button
	if def.PointAtButton and button then
		local bounce = math.abs(math.sin(os.clock() * 3)) * 10
		screenArrow.Position = UDim2.fromOffset(button.AbsolutePosition.X + button.AbsoluteSize.X / 2, button.AbsolutePosition.Y - 4 - bounce)
		screenArrow.Visible = true
	else
		screenArrow.Visible = false
	end
end)

return Guide
