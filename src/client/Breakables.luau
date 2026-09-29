-- Breakables: shake when hit, damage numbers, "+coins" when they break.
-- Other players' breakables are hidden (everyone has their own).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

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

-- White flash on hit (Highlights are limited, so it's only on briefly).
local function flash(model)
	local highlight = model:FindFirstChild("HitFlash")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "HitFlash"
		highlight.FillColor = Color3.new(1, 1, 1)
		highlight.OutlineTransparency = 1
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	end
	highlight.Enabled = true
	highlight.FillTransparency = 0.35
	local fade = TweenService:Create(highlight, TweenInfo.new(0.15), { FillTransparency = 1 })
	fade:Play()
	fade.Completed:Connect(function()
		highlight.Enabled = false
	end)
end

-- Pops in from small when it spawns.
local function popIn(model)
	if not model.PrimaryPart then
		return
	end
	pcall(model.ScaleTo, model, 0.05)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / 0.3, 1)
		-- overshoot a little, then settle (back-out easing)
		local c = 1.7
		local eased = 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
		if model.Parent then
			pcall(model.ScaleTo, model, math.max(0.05, eased))
		end
		if t >= 1 or not model.Parent then
			connection:Disconnect()
		end
	end)
end

-- Coins (and diamonds) burst out of a broken breakable.
local function burst(position, diamonds)
	local pieces = {}
	for i = 1, 8 do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.25, 1.1, 1.1)
		coin.Color = if diamonds and i % 3 == 0 then Color3.fromRGB(110, 220, 255) else Color3.fromRGB(255, 205, 50)
		coin.Material = if diamonds and i % 3 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CanTouch = false
		coin.CastShadow = false
		coin.CFrame = CFrame.new(position)
		coin.Parent = workspace
		table.insert(pieces, coin)

		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.random(20, 40) / 10
		local peak = position + out * 0.5 + Vector3.new(0, math.random(25, 40) / 10, 0)
		local land = position + out - Vector3.new(0, 0.8, 0)
		local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		TweenService:Create(coin, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) * spin }):Play()
		task.delay(0.22, function()
			TweenService
				:Create(coin, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land) * spin * spin, Transparency = 1 })
				:Play()
		end)
	end

	-- sparkle burst
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position
	anchor.Parent = workspace
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 0
	sparkles.Lifetime = NumberRange.new(0.4, 0.7)
	sparkles.Speed = NumberRange.new(8, 14)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 170, 60))
	sparkles.Parent = anchor
	sparkles:Emit(25)

	Debris:AddItem(anchor, 1)
	for _, coin in ipairs(pieces) do
		Debris:AddItem(coin, 0.6)
	end
end

local function track(model)
	if not model:IsA("Model") then
		return
	end
	local info = {
		Pivot = model:GetPivot(),
		Health = model:GetAttribute("Health") or 0,
		Value = model:GetAttribute("Value") or 0,
		Kind = model:GetAttribute("Kind") or 1,
		Diamonds = model:GetAttribute("Diamonds"),
		Height = model:GetAttribute("Height") or 2,
		ShakeUntil = 0,
		Shaking = false,
	}
	tracked[model] = info
	popIn(model)

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
			if health > 0 then
				flash(model)
			end
		end
	end)
end

local function untrack(model)
	local info = tracked[model]
	tracked[model] = nil
	if info and info.Health <= 0 then
		local center = info.Pivot.Position + Vector3.new(0, info.Height / 2, 0)
		burst(center, info.Diamonds)
		popup(
			info.Pivot.Position + Vector3.new(0, info.Height + 1, 0),
			"+" .. Config.formatNumber(Config.breakablePayout(State.Data, info.Kind, info.Value)) .. " 💰",
			Color3.fromRGB(255, 215, 60),
			34
		)
		Fx.fly(center, "💰", "Coins", if info.Kind >= 3 then 7 else 3)
		if info.Diamonds then
			popup(
				info.Pivot.Position + Vector3.new(0, info.Height + 2.6, 0),
				"+" .. info.Diamonds .. " 💎",
				Color3.fromRGB(120, 220, 255),
				32
			)
			Fx.fly(center, "💎", "Diamonds", math.min(info.Diamonds + 1, 5))
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
