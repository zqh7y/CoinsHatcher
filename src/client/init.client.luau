-- Client: screen buttons (teleport, rebirth, pets), pet inventory,
-- hatch popups, and making the world match this player's rebirth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local data = nil -- latest copy of our data from the server

-- UI helpers -----------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "PetSimUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

local function button(text, color, parent)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(170, 50)
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.5
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	return b
end

-- Toast messages -------------------------------------------------------------

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 60)
toast.Size = UDim2.fromOffset(520, 44)
toast.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui
corner(toast)

local toastId = 0
local function showToast(message, color)
	toastId += 1
	local id = toastId
	toast.Text = message
	toast.TextColor3 = color or Color3.new(1, 1, 1)
	toast.Visible = true
	task.delay(3, function()
		if toastId == id then
			toast.Visible = false
		end
	end)
end

remotes.Notify.OnClientEvent:Connect(showToast)

-- Side buttons ---------------------------------------------------------------

local side = Instance.new("Frame")
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 12, 0.5, 0)
side.Size = UDim2.fromOffset(170, 230)
side.BackgroundTransparency = 1
side.Parent = gui

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 8)
sideLayout.Parent = side

local mainButton = button("🏠 Main Area", Color3.fromRGB(70, 160, 80), side)
local eggButton = button("🥚 Egg Area", Color3.fromRGB(220, 150, 50), side)
local rebirthButton = button("⭐ Rebirth", Color3.fromRGB(150, 80, 220), side)
local petsButton = button("🐾 Pets", Color3.fromRGB(60, 130, 220), side)

mainButton.Activated:Connect(function()
	remotes.Teleport:FireServer("Main")
end)
eggButton.Activated:Connect(function()
	remotes.Teleport:FireServer("Eggs")
end)

local rebirthBusy = false
rebirthButton.Activated:Connect(function()
	if rebirthBusy then
		return
	end
	rebirthBusy = true
	local ok, message = remotes.Rebirth:InvokeServer()
	showToast(message, if ok then Color3.fromRGB(200, 150, 255) else Color3.fromRGB(255, 90, 90))
	rebirthBusy = false
end)

-- Pet inventory --------------------------------------------------------------

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(560, 400)
panel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
panel.Visible = false
panel.Parent = gui
corner(panel, 14)

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(16, 10)
title.Size = UDim2.new(1, -80, 0, 36)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
close.Text = "X"
close.TextColor3 = Color3.new(1, 1, 1)
close.Font = Enum.Font.GothamBold
close.TextScaled = true
close.Parent = panel
corner(close, 8)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 56)
list.Size = UDim2.new(1, -24, 1, -68)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(125, 130)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = list

local function renderPets()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not data then
		return
	end

	title.Text = ("Pets %d/%d  ·  Equipped %d/%d"):format(#data.Pets, Config.MAX_PETS, #data.Equipped, Config.MAX_EQUIPPED)

	for index, petName in ipairs(data.Pets) do
		local info = Config.PETS[petName]
		if not info then
			continue
		end
		local isEquipped = table.find(data.Equipped, index) ~= nil

		local card = Instance.new("Frame")
		-- equipped first, then strongest first
		card.LayoutOrder = (if isEquipped then 0 else 1e9) - info.Power
		card.BackgroundColor3 = if isEquipped then Color3.fromRGB(60, 90, 60) else Color3.fromRGB(55, 55, 70)
		card.Parent = list
		corner(card)

		local stroke = Instance.new("UIStroke")
		stroke.Color = info.Color
		stroke.Thickness = 2
		stroke.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.fromOffset(6, 6)
		nameLabel.Size = UDim2.new(1, -12, 0, 26)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = petName
		nameLabel.TextColor3 = info.Color
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.Parent = card

		local statLabel = Instance.new("TextLabel")
		statLabel.Position = UDim2.fromOffset(6, 34)
		statLabel.Size = UDim2.new(1, -12, 0, 40)
		statLabel.BackgroundTransparency = 1
		statLabel.Text = info.Rarity .. "\n⚔ " .. Config.formatNumber(info.Power)
		statLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		statLabel.Font = Enum.Font.Gotham
		statLabel.TextScaled = true
		statLabel.Parent = card

		local equipButton = Instance.new("TextButton")
		equipButton.AnchorPoint = Vector2.new(0.5, 1)
		equipButton.Position = UDim2.new(0.5, 0, 1, -6)
		equipButton.Size = UDim2.new(1, -12, 0, 34)
		equipButton.BackgroundColor3 = if isEquipped then Color3.fromRGB(200, 70, 70) else Color3.fromRGB(70, 170, 80)
		equipButton.Text = if isEquipped then "Unequip" else "Equip"
		equipButton.TextColor3 = Color3.new(1, 1, 1)
		equipButton.Font = Enum.Font.GothamBold
		equipButton.TextScaled = true
		equipButton.Parent = card
		corner(equipButton, 8)

		equipButton.Activated:Connect(function()
			local ok, message = remotes.SetEquipped:InvokeServer(index, not isEquipped)
			if not ok and message then
				showToast(message, Color3.fromRGB(255, 90, 90))
			end
		end)
	end
end

petsButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	renderPets()
end)
close.Activated:Connect(function()
	panel.Visible = false
end)

-- Hatch popup ----------------------------------------------------------------

local hatchLabel = Instance.new("TextLabel")
hatchLabel.AnchorPoint = Vector2.new(0.5, 0.5)
hatchLabel.Position = UDim2.fromScale(0.5, 0.4)
hatchLabel.Size = UDim2.fromOffset(0, 0)
hatchLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
hatchLabel.BackgroundTransparency = 0.1
hatchLabel.Font = Enum.Font.GothamBold
hatchLabel.TextScaled = true
hatchLabel.Visible = false
hatchLabel.Parent = gui
corner(hatchLabel, 14)

local hatchId = 0
remotes.Hatched.OnClientEvent:Connect(function(petName)
	local info = Config.PETS[petName]
	hatchId += 1
	local id = hatchId

	hatchLabel.Text = "You hatched a " .. info.Rarity .. " " .. petName .. "!\n⚔ " .. Config.formatNumber(info.Power)
	hatchLabel.TextColor3 = info.Color
	hatchLabel.Size = UDim2.fromOffset(0, 0)
	hatchLabel.Visible = true
	TweenService:Create(hatchLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(420, 110),
	}):Play()

	task.delay(2.5, function()
		if hatchId == id then
			hatchLabel.Visible = false
		end
	end)
end)

-- World: match this player's rebirth -----------------------------------------

local function updateWorld()
	if not data then
		return
	end

	-- recolor the main area for our rebirth level
	local floor = workspace:FindFirstChild("MainArea") and workspace.MainArea:FindFirstChild("Floor")
	if floor then
		floor.Color = Config.areaColor(data.Rebirths)
	end

	-- show a lock on eggs we haven't unlocked yet
	local eggArea = workspace:FindFirstChild("EggArea")
	local eggs = eggArea and eggArea:FindFirstChild("Eggs")
	if eggs then
		for _, egg in ipairs(eggs:GetChildren()) do
			local lock = egg:FindFirstChild("Lock", true)
			if lock then
				lock.Visible = data.Rebirths < egg:GetAttribute("RequiredRebirths")
			end
		end
	end

	-- rebirth button shows the cost
	if data.Rebirths >= Config.MAX_REBIRTHS then
		rebirthButton.Text = "⭐ Max Rebirth"
	else
		rebirthButton.Text = "⭐ Rebirth (" .. Config.formatNumber(Config.rebirthCost(data.Rebirths)) .. ")"
	end
end

local function onData(newData)
	data = newData
	updateWorld()
	if panel.Visible then
		renderPets()
	end
end

remotes.DataChanged.OnClientEvent:Connect(onData)
task.spawn(function()
	local initial = remotes.GetData:InvokeServer()
	if initial and not data then
		onData(initial)
	end
end)

-- eggs are built by the server and may replicate after we start
task.spawn(function()
	workspace:WaitForChild("EggArea"):WaitForChild("Eggs").DescendantAdded:Connect(updateWorld)
	updateWorld()
end)

-- Hide other players' coins (each player has their own) ----------------------

local myId = tostring(player.UserId)

local function hide(obj)
	if obj:IsA("BasePart") then
		obj.Transparency = 1
	elseif obj:IsA("BillboardGui") then
		obj.Enabled = false
	end
end

local function onCoinFolder(folder)
	if folder.Name == myId then
		return
	end
	for _, obj in ipairs(folder:GetDescendants()) do
		hide(obj)
	end
	folder.DescendantAdded:Connect(hide)
end

local coinsFolder = workspace:WaitForChild("Coins")
coinsFolder.ChildAdded:Connect(onCoinFolder)
for _, folder in ipairs(coinsFolder:GetChildren()) do
	onCoinFolder(folder)
end
