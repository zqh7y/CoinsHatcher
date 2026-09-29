-- Playtime gifts menu: a mystery gift unlocks after 1, 3, 5, 10, 15 and 20
-- minutes of play (free pets, potions, diamonds or coins; the last is a MEGA
-- gift). Clean white tiles with a drawn gift, a progress bar and a timer;
-- ready gifts bounce and glow with a spinning colored border, and burst open
-- to show the prize. The side button gets a badge when one is ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Icons = require(script.Parent.Icons)
local Fx = require(script.Parent.Fx)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Gifts = {}

local joinedAt = os.clock()
local claimed = {}
local prizes = {} -- [giftIndex] = what it gave, shown after opening

local panel = Ui.panel("Free Gifts", nil, UDim2.fromOffset(640, 540), { Ui.COLORS.Red })

Ui.label(panel.Content, {
	Text = "Keep playing to unlock free mystery gifts",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, 0, 0, 18),
})
local holder = Instance.new("Frame")
holder.BackgroundTransparency = 1
holder.Position = UDim2.fromOffset(0, 30)
holder.Size = UDim2.new(1, 0, 1, -30)
holder.Parent = panel.Content
local list = Ui.grid(holder, UDim2.fromOffset(186, 196), UDim2.fromOffset(12, 12))

-- one accent color per gift
local GIFT_COLORS = {
	Color3.fromRGB(255, 95, 130),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(40, 200, 130),
	Color3.fromRGB(60, 160, 255),
	Color3.fromRGB(150, 100, 255),
	Color3.fromRGB(255, 185, 30),
}

local tiles = {}

local function secondsLeft(giftIndex)
	return math.max(0, math.ceil(Config.GIFT_TIMES[giftIndex] * 60 - (os.clock() - joinedAt)))
end

local function readyCount()
	local n = 0
	for i in ipairs(Config.GIFT_TIMES) do
		if not claimed[i] and secondsLeft(i) == 0 then
			n += 1
		end
	end
	return n
end

local function openAnimation(tile, message)
	-- shake harder and harder, then pop
	local icon = tile.Icon
	for i = 1, 14 do
		icon.Rotation = (if i % 2 == 0 then 1 else -1) * (6 + i * 1.5)
		task.wait(0.05)
	end
	icon.Rotation = 0
	local scale = icon:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = icon
	scale.Scale = 1.4
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Ui.toast(message, Ui.COLORS.Gold)
	Fx.confetti(60)
end

for i in ipairs(Config.GIFT_TIMES) do
	local color = GIFT_COLORS[(i - 1) % #GIFT_COLORS + 1]
	local mega = i == #Config.GIFT_TIMES

	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Ui.COLORS.Soft
	tile.LayoutOrder = i
	tile.Parent = list
	Ui.corner(tile, 18)
	local stroke = Ui.stroke(tile, Ui.COLORS.Line, 1.5)
	-- spins around the border when the gift is ready
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, Ui.COLORS.Accent2),
		ColorSequenceKeypoint.new(1, color),
	})
	glow.Enabled = false
	glow.Parent = stroke

	-- soft colored circle with the gift drawn in it
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0)
	circle.Position = UDim2.new(0.5, 0, 0, 14)
	circle.Size = UDim2.fromOffset(70, 70)
	circle.BackgroundColor3 = color
	circle.BackgroundTransparency = 0.82
	circle.Parent = tile
	Ui.corner(circle, 0.5)
	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.62, 0.62)
	icon.BackgroundTransparency = 1
	icon.Parent = circle
	Icons.gift(icon, color)

	local title = Ui.label(tile, {
		Text = if mega then "MEGA Gift" else "Mystery Gift",
		TextColor3 = if mega then color else Ui.COLORS.Text,
		Position = UDim2.fromOffset(8, 92),
		Size = UDim2.new(1, -16, 0, 18),
	})
	local reward = Ui.label(tile, {
		Text = "",
		Font = Ui.FONT_BODY,
		TextColor3 = Ui.COLORS.SubText,
		TextWrapped = true,
		Position = UDim2.fromOffset(8, 112),
		Size = UDim2.new(1, -16, 0, 16),
	})

	-- progress toward unlocking
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(16, 134)
	bar.Size = UDim2.new(1, -32, 0, 5)
	bar.BackgroundColor3 = Ui.COLORS.Line
	bar.BorderSizePixel = 0
	bar.Parent = tile
	Ui.corner(bar, 0.5)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Ui.corner(fill, 0.5)
	Ui.gradient(fill, color, Ui.COLORS.Accent2, 0)

	local button = Ui.button(tile, "", Ui.COLORS.Disabled, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -32, 0, 36),
	})
	local busy = false
	button.Activated:Connect(function()
		if busy or claimed[i] or secondsLeft(i) > 0 then
			return
		end
		busy = true
		local ok, message, prize = remotes.ClaimGift:InvokeServer(i)
		if ok then
			claimed[i] = true
			prizes[i] = prize
			openAnimation(tiles[i], message)
		elseif message then
			Ui.toast(message, Ui.COLORS.Red)
		end
		busy = false
	end)
	tiles[i] = { Icon = icon, Title = title, Reward = reward, Button = button, Fill = fill, Stroke = stroke, Glow = glow, Color = color }
end

local function refresh()
	for i, tile in ipairs(tiles) do
		local total = Config.GIFT_TIMES[i] * 60
		local left = secondsLeft(i)
		tile.Fill.Size = UDim2.fromScale(1 - left / total, 1)
		if claimed[i] then
			tile.Reward.Text = prizes[i] or ""
			tile.Reward.TextColor3 = Ui.COLORS.Accent
			tile.Button.Text = "Opened ✓"
			Ui.setButtonColor(tile.Button, Ui.COLORS.Soft)
		elseif left == 0 then
			tile.Reward.Text = "Ready to open!"
			tile.Reward.TextColor3 = tile.Color
			tile.Button.Text = "Open"
			Ui.setButtonColor(tile.Button, tile.Color)
		else
			tile.Reward.Text = ("Unlocks in %d:%02d"):format(left // 60, left % 60)
			tile.Reward.TextColor3 = Ui.COLORS.SubText
			tile.Button.Text = ("%d:%02d"):format(left // 60, left % 60)
			Ui.setButtonColor(tile.Button, Ui.COLORS.Disabled)
		end
	end
end

-- ready gifts bounce and their border glows and spins
RunService.RenderStepped:Connect(function()
	if not panel.isOpen() then
		return
	end
	local t = os.clock()
	for i, tile in ipairs(tiles) do
		local ready = not claimed[i] and secondsLeft(i) == 0
		tile.Glow.Enabled = ready
		tile.Stroke.Thickness = if ready then 3 else 1.5
		tile.Stroke.Color = if ready then Color3.new(1, 1, 1) else Ui.COLORS.Line
		if ready then
			tile.Glow.Rotation = (t * 120) % 360
			tile.Icon.Position = UDim2.fromScale(0.5, 0.5 - math.abs(math.sin(t * 6 + i)) * 0.08)
		else
			tile.Icon.Position = UDim2.fromScale(0.5, 0.5)
		end
	end
end)

-- Hooks up the gift button's badge (how many gifts are ready).
function Gifts.attach(giftButton)
	local badge = Ui.label(giftButton, {
		Text = "!",
		TextColor3 = Ui.COLORS.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = Ui.COLORS.Red,
		ZIndex = 3,
		Visible = false,
	})
	Ui.corner(badge, 0.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = badge
	task.spawn(function()
		while true do
			local ready = readyCount()
			badge.Visible = ready > 0
			badge.Text = tostring(ready)
			if panel.isOpen() then
				refresh()
			end
			task.wait(1)
		end
	end)
end

panel.OnOpen.Event:Connect(refresh)
Gifts.toggle = panel.toggle

return Gifts
