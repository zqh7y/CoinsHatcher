-- Breakables: shake when hit, damage numbers, "+coins" when they break.
-- Other players' breakables are hidden (everyone has their own).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local player = Players.LocalPlayer

local Breakables = {}

local myId = tostring(player.UserId)
local tracked = {} -- [model] = { Pivot, Health, Value, Height, ShakeUntil, Shaking }

local function hide(obj)
	if obj:IsA("BasePart") then
		obj.Transparency = 1
	elseif obj:IsA("LayerCollector") then -- BillboardGui / SurfaceGui
		obj.Enabled = false
	end
end

-- Floating text that rises and fades out.
local function popup(position, text, color, height)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = position
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(height * 5, height)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(40, 30, 60)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui

	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	Debris:AddItem(anchor, 0.9)
end

local function track(model)
	if not model:IsA("Model") then
		return
	end
	local info = {
		Pivot = model:GetPivot(),
		Health = model:GetAttribute("Health") or 0,
		Value = model:GetAttribute("Value") or 0,
		Diamonds = model:GetAttribute("Diamonds"),
		Height = model:GetAttribute("Height") or 2,
		ShakeUntil = 0,
		Shaking = false,
	}
	tracked[model] = info

	model:GetAttributeChangedSignal("Health"):Connect(function()
		local health = model:GetAttribute("Health")
		local damage = info.Health - health
		info.Health = health
		if damage > 0 then
			local crit = model:GetAttribute("Crit") == true
			local jitter = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
			popup(
				info.Pivot.Position + Vector3.new(0, info.Height + 0.5, 0) + jitter,
				(if crit then "💥 CRIT! -" else "-") .. Config.formatNumber(damage),
				if crit then Color3.fromRGB(255, 80, 80) else Color3.new(1, 1, 1),
				if crit then 38 else 26
			)
			info.ShakeUntil = os.clock() + (if crit then 0.35 else 0.2)
		end
	end)
end

local function untrack(model)
	local info = tracked[model]
	tracked[model] = nil
	if info and info.Health <= 0 then
		popup(
			info.Pivot.Position + Vector3.new(0, info.Height + 1, 0),
			"+" .. Config.formatNumber(info.Value * Config.totalCoins(State.Data)) .. " 💰",
			Color3.fromRGB(255, 215, 60),
			34
		)
		if info.Diamonds then
			popup(
				info.Pivot.Position + Vector3.new(0, info.Height + 2.6, 0),
				"+" .. info.Diamonds .. " 💎",
				Color3.fromRGB(120, 220, 255),
				32
			)
		end
	end
end

local function onCoinFolder(folder)
	if folder.Name == myId then
		for _, model in ipairs(folder:GetChildren()) do
			track(model)
		end
		folder.ChildAdded:Connect(track)
		folder.ChildRemoved:Connect(untrack)
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

-- Breakables only move while they're being hit: a quick wobble.
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for model, info in pairs(tracked) do
		if info.ShakeUntil > t then
			local wobble = CFrame.new(math.sin(t * 70) * 0.12, 0, math.cos(t * 60) * 0.12)
				* CFrame.Angles(0, math.sin(t * 50) * 0.06, 0)
			model:PivotTo(info.Pivot * wobble)
			info.Shaking = true
		elseif info.Shaking then
			model:PivotTo(info.Pivot)
			info.Shaking = false
		end
	end
end)

return Breakables
