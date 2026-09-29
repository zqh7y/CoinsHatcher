-- Boosts you earn by playing:
--   Combos:     break things without stopping; every Config.COMBO_STEP in a
--               row gives a short free 2x boost.
--   Boost orbs: broken breakables sometimes drop a glowing potion orb; walk
--               close to grab a free 2x boost.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Coins = require(script.Parent.Coins)

local Pickups = {}

local ORB_COLORS = {
	Coins = Color3.fromRGB(255, 200, 50),
	Luck = Color3.fromRGB(110, 220, 110),
	Damage = Color3.fromRGB(255, 90, 90),
}

local remotes
local folder = Instance.new("Folder")
folder.Name = "Pickups"
folder.Parent = workspace

local combos = {} -- [player] = { Count, Last }
local orbs = {} -- [orb part] = { Owner, Boost, Expires }

local function notify(player, message, color, celebrate)
	remotes.Notify:FireClient(player, message, color, celebrate)
end

local function playerFolder(player)
	local f = folder:FindFirstChild(tostring(player.UserId))
	if not f then
		f = Instance.new("Folder")
		f.Name = tostring(player.UserId)
		f.Parent = folder
	end
	return f
end

local function spawnOrb(player, position)
	local boost = Config.BOOSTS[math.random(#Config.BOOSTS)]
	local orb = Instance.new("Part")
	orb.Name = "BoostOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 1.8
	orb.Color = ORB_COLORS[boost.Id] or Color3.new(1, 1, 1)
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CastShadow = false
	orb.Position = position + Vector3.new(0, 2.5, 0)

	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = orb

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(110, 36)
	tag.StudsOffset = Vector3.new(0, 2, 0)
	tag.MaxDistance = 80
	tag.Parent = orb
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "🧪 " .. boost.Icon .. " 2x"
	text.TextColor3 = orb.Color
	text.TextStrokeTransparency = 0
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Parent = tag

	orb.Parent = playerFolder(player)
	CollectionService:AddTag(orb, "Bob") -- the client makes it float up and down
	orbs[orb] = { Owner = player, Boost = boost, Expires = os.clock() + Config.ORB_LIFETIME }
end

local function onBroken(player, position, kind)
	-- combo
	local now = os.clock()
	local combo = combos[player]
	if not combo or now - combo.Last > Config.COMBO_TIMEOUT then
		combo = { Count = 0, Last = now }
		combos[player] = combo
	end
	combo.Count += 1
	combo.Last = now
	player:SetAttribute("Combo", combo.Count)

	if combo.Count % Config.COMBO_STEP == 0 then
		local step = combo.Count // Config.COMBO_STEP
		local id = Config.COMBO_BOOSTS[(step - 1) % #Config.COMBO_BOOSTS + 1]
		local boost = Config.BOOSTS_BY_ID[id]
		PlayerData.addBoost(player, id, Config.COMBO_BOOST_SECONDS)
		notify(
			player,
			("🔥 Combo x%d! %s for %ds!"):format(combo.Count, boost.Name, Config.COMBO_BOOST_SECONDS),
			Color3.fromRGB(255, 160, 60),
			true
		)
	end

	-- boost orb drop
	if math.random() < (Config.ORB_CHANCE[kind] or 0) then
		spawnOrb(player, position)
	end
end

local function update()
	local now = os.clock()
	-- combos run out if you stop breaking things
	for player, combo in pairs(combos) do
		if now - combo.Last > Config.COMBO_TIMEOUT then
			combos[player] = nil
			player:SetAttribute("Combo", 0)
		end
	end
	-- orbs: grab when close, vanish when old
	for orb, info in pairs(orbs) do
		local root = info.Owner.Character and info.Owner.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - orb.Position).Magnitude < Config.ORB_RANGE then
			orbs[orb] = nil
			orb:Destroy()
			PlayerData.addBoost(info.Owner, info.Boost.Id, Config.ORB_SECONDS)
			notify(
				info.Owner,
				("🧪 Grabbed %s for %ds!"):format(info.Boost.Name, Config.ORB_SECONDS),
				ORB_COLORS[info.Boost.Id],
				true
			)
		elseif now > info.Expires or not info.Owner.Parent then
			orbs[orb] = nil
			orb:Destroy()
		end
	end
end

function Pickups.start(remoteFolder)
	remotes = remoteFolder
	Coins.Broken.Event:Connect(onBroken)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			update()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		combos[player] = nil
		local f = folder:FindFirstChild(tostring(player.UserId))
		if f then
			f:Destroy()
		end
	end)
end

return Pickups
