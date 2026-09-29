-- Playtime gifts menu: a free gift unlocks after 1, 3, 5, 10, 15 and 20
-- minutes of play. Gifts bounce, fill a progress bar, glow when ready and
-- burst open with their coins. The gift button gets a red badge when one is
-- ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Gifts = {}

local joinedAt = os.clock()
local claimed = {}

local panel = Ui.panel("Free Gifts", "🎁", UDim2.fromOffset(620, 470), {
	Color3.fromRGB(255, 130, 170),
	Color3.fromRGB(150, 70, 200),
})

Ui.label(panel.Content, {
	Text = "Keep playing to unlock free gifts! 🎉",
	Size = UDim2.new(1, 0, 0, 28),
	TextColor3 = Color3.fromRGB(255, 240, 200),
})
local holder = Instance.new("Frame")
holder.BackgroundTransparency = 1
holder.Position = UDim2.fromOffset(0, 36)
holder.Size = UDim2.new(1, 0, 1, -36)
holder.Parent = panel.Content
local list = Ui.grid(holder, UDim2.fromOffset(180, 170), UDim2.fromOffset(12, 12))

-- one bright color per gift
local GIFT_COLORS = {
	Color3.fromRGB(255, 120, 150),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(110, 200, 110),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(255, 200, 40),
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
	-- shake, then pop into the reward
	local icon = tile.Icon
	for i = 1, 8 do
		icon.Rotation = if i % 2 == 0 then 18 else -18
		task.wait(0.05)
	end
	icon.Rotation = 0
	icon.Text = "💰"
	local scale = icon:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = icon
	scale.Scale = 0.3
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1.3 }):Play()
	Ui.toast(message, Ui.COLORS.Gold)
	Fx.confetti(50)
	task.wait(0.8)
	TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
end

for i in ipairs(Config.GIFT_TIMES) do
	local color = GIFT_COLORS[(i - 1) % #GIFT_COLORS + 1]
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Color3.new(1, 1, 1)
	tile.LayoutOrder = i
	tile.Parent = list
	Ui.corner(tile, 18)
	local stroke = Ui.stroke(tile, Color3.new(1, 1, 1), 3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.fromRGB(60, 20, 90), 0.4))
	gradient.Rotation = 90
	gradient.Parent = tile

	local icon = Ui.label(tile, {
		Text = "🎁",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(64, 60),
		TextStrokeTransparency = 1,
	})
	local reward = Ui.label(tile, {
		Text = "",
		TextColor3 = Color3.fromRGB(255, 240, 160),
		Size = UDim2.new(1, -10, 0, 24),
		Position = UDim2.fromOffset(5, 68),
	})

	-- progress bar
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -24, 0, 12)
	bar.Position = UDim2.fromOffset(12, 98)
	bar.BackgroundColor3 = Color3.fromRGB(40, 20, 70)
	bar.BackgroundTransparency = 0.3
	bar.Parent = tile
	Ui.corner(bar, 0.5)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 240, 130)
	fill.Parent = bar
	Ui.corner(fill, 0.5)

	local button = Ui.button(tile, "", Ui.COLORS.Green, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 40),
	})
	local busy = false
	button.Activated:Connect(function()
		if busy or claimed[i] or secondsLeft(i) > 0 then
			return
		end
		busy = true
		local ok, message = remotes.ClaimGift:InvokeServer(i)
		if ok then
			claimed[i] = true
			openAnimation(tiles[i], message)
		elseif message then
			Ui.toast(message, Ui.COLORS.Red)
		end
		busy = false
	end)
	tiles[i] = { Icon = icon, Reward = reward, Button = button, Fill = fill, Stroke = stroke, Tile = tile }
end

local function refresh()
	local rebirths = State.Data and State.Data.Rebirths or 0
	for i, tile in ipairs(tiles) do
		tile.Reward.Text = ("💰 %s  💎 %d"):format(Config.formatNumber(Config.giftReward(i, rebirths)), Config.giftDiamonds(i))
		local total = Config.GIFT_TIMES[i] * 60
		local left = secondsLeft(i)
		tile.Fill.Size = UDim2.fromScale(1 - left / total, 1)
		if claimed[i] then
			tile.Button.Text = "Opened ✔"
			tile.Button.BackgroundColor3 = Ui.COLORS.PanelDark
			tile.Tile.BackgroundTransparency = 0.35
		elseif left == 0 then
			tile.Button.Text = "OPEN! 🎉"
			tile.Button.BackgroundColor3 = Ui.COLORS.Green
		else
			tile.Button.Text = ("⏰ %d:%02d"):format(left // 60, left % 60)
			tile.Button.BackgroundColor3 = Color3.fromRGB(150, 140, 170)
		end
	end
end

-- bounce the gifts and make ready ones glow
RunService.RenderStepped:Connect(function()
	if not panel.isOpen() then
		return
	end
	local t = os.clock()
	for i, tile in ipairs(tiles) do
		local ready = not claimed[i] and secondsLeft(i) == 0
		if not claimed[i] then
			local speed = if ready then 8 else 3
			tile.Icon.Position = UDim2.new(0.5, 0, 0, 6 - math.abs(math.sin(t * speed + i)) * (if ready then 8 else 3))
		end
		tile.Stroke.Color = if ready then Color3.fromHSV((t * 0.6) % 1, 0.5, 1) else Color3.new(1, 1, 1)
		tile.Stroke.Thickness = if ready then 5 else 3
	end
end)

-- Hooks up the gift button's red badge.
function Gifts.attach(giftButton)
	local badge = Ui.label(giftButton, {
		Text = "!",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = Ui.COLORS.Red,
		ZIndex = 3,
		Visible = false,
	})
	Ui.corner(badge, 0.5)
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
