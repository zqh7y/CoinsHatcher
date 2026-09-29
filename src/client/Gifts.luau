-- Playtime gifts menu: a free gift unlocks after 1, 3, 5, 10, 15 and 20
-- minutes of play. The gift button gets a red badge when one is ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Gifts = {}

local joinedAt = os.clock()
local claimed = {}

local panel = Ui.panel("Free Gifts", "🎁", UDim2.fromOffset(560, 400))
local list = Ui.grid(panel.Content, UDim2.fromOffset(160, 150))

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

for i in ipairs(Config.GIFT_TIMES) do
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Ui.COLORS.Card
	tile.LayoutOrder = i
	tile.Parent = list
	Ui.corner(tile, 16)
	Ui.stroke(tile, Ui.COLORS.Outline, 3)

	Ui.label(tile, { Text = "🎁", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6) })
	local reward = Ui.label(tile, {
		Text = "",
		TextColor3 = Ui.COLORS.Gold,
		Size = UDim2.new(1, -10, 0, 26),
		Position = UDim2.fromOffset(5, 58),
	})
	local button = Ui.button(tile, "", Ui.COLORS.Green, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 44),
	})
	button.Activated:Connect(function()
		if claimed[i] or secondsLeft(i) > 0 then
			return
		end
		local ok, message = remotes.ClaimGift:InvokeServer(i)
		if ok then
			claimed[i] = true
		end
		if message then
			Ui.toast(message, if ok then Ui.COLORS.Gold else Ui.COLORS.Red)
		end
	end)
	tiles[i] = { Reward = reward, Button = button }
end

local function refresh()
	local rebirths = State.Data and State.Data.Rebirths or 0
	for i, tile in ipairs(tiles) do
		tile.Reward.Text = "💰 " .. Config.formatNumber(Config.giftReward(i, rebirths))
		local left = secondsLeft(i)
		if claimed[i] then
			tile.Button.Text = "Opened ✔"
			tile.Button.BackgroundColor3 = Ui.COLORS.PanelDark
		elseif left == 0 then
			tile.Button.Text = "Open!"
			tile.Button.BackgroundColor3 = Ui.COLORS.Green
		else
			tile.Button.Text = ("%d:%02d"):format(left // 60, left % 60)
			tile.Button.BackgroundColor3 = Color3.fromRGB(150, 140, 170)
		end
	end
end

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
