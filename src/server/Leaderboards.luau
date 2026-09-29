-- Three leaderboards in the main area: most eggs hatched, most rebirths and
-- the rarest pet ever hatched (by its odds, "1 in N"). They're global
-- (OrderedDataStores, refreshed every minute) with the players in this server
-- mixed in live, so they also work in Studio without API access.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Leaderboards = {}

local TOP = 10
local GLOBAL_EVERY = 60 -- seconds between DataStore refreshes
local LIVE_EVERY = 5 -- seconds between redraws with this server's players

local BOARDS = {
	{
		Id = "Hatched",
		Title = "🥚 Most Hatched",
		Colors = { Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 95, 130) },
		Value = function(data)
			return data.Hatched or 0
		end,
		Text = function(value)
			return Config.formatNumber(value)
		end,
	},
	{
		Id = "Rebirths",
		Title = "🔄 Most Rebirths",
		Colors = { Color3.fromRGB(95, 110, 255), Color3.fromRGB(175, 95, 255) },
		Value = function(data)
			return data.Rebirths or 0
		end,
		Text = function(value)
			return tostring(value)
		end,
	},
	{
		Id = "Rarest",
		Title = "🍀 Rarest Pet",
		Colors = { Color3.fromRGB(35, 200, 125), Color3.fromRGB(45, 185, 255) },
		Value = function(data)
			return if data.Rarest then data.Rarest.Odds else 0
		end,
		Text = function(value)
			return "1 in " .. Config.formatNumber(value)
		end,
	},
}

-- DataStores (these fail in Studio without API access; we then just show
-- the players in this server)
local function getStore(fn)
	local ok, store = pcall(fn)
	return if ok then store else nil
end
for _, board in ipairs(BOARDS) do
	board.Store = getStore(function()
		return DataStoreService:GetOrderedDataStore("Leader" .. board.Id .. "_v1")
	end)
	board.Global = {} -- { { UserId, Value } } from the last refresh
	board.Written = {} -- [userId] = value we last saved
end
local rarestPets = getStore(function()
	return DataStoreService:GetDataStore("LeaderRarestPet_v1")
end)
local petNameCache = {} -- [userId .. ":" .. odds] = pet name
local userNameCache = {} -- [userId] = name

local function userName(userId)
	local online = Players:GetPlayerByUserId(userId)
	if online then
		return online.DisplayName
	end
	if userNameCache[userId] == nil then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		userNameCache[userId] = if ok then name else "Player"
	end
	return userNameCache[userId]
end

local function rarestPetName(userId, odds)
	local online = Players:GetPlayerByUserId(userId)
	local data = online and PlayerData.get(online)
	if data and data.Rarest and data.Rarest.Odds == odds then
		return data.Rarest.Pet
	end
	local key = userId .. ":" .. odds
	if petNameCache[key] == nil and rarestPets then
		local ok, name = pcall(rarestPets.GetAsync, rarestPets, tostring(userId))
		petNameCache[key] = if ok and type(name) == "string" then name else false
	end
	return petNameCache[key] or nil
end

-- The board parts -----------------------------------------------------------

local function newPart(props)
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return World.part(props)
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(30, 33, 48)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius < 1 then UDim.new(radius, 0) else UDim.new(0, radius)
	c.Parent = parent
end

local MEDALS = { Color3.fromRGB(255, 190, 40), Color3.fromRGB(175, 185, 200), Color3.fromRGB(215, 140, 80) }

local function buildBoard(board, angle)
	local main = workspace:WaitForChild("MainArea")
	local a = math.rad(angle)
	local base = World.MAIN_CENTER + Vector3.new(math.cos(a) * 43, World.FLOOR_Y, math.sin(a) * 43)
	local facing = CFrame.lookAt(base, Vector3.new(World.MAIN_CENTER.X, base.Y, World.MAIN_CENTER.Z))
	local frame = Color3.fromRGB(236, 239, 246)

	local screen = newPart({
		Name = "Leaderboard" .. board.Id,
		Size = Vector3.new(10, 13, 0.5),
		CFrame = facing * CFrame.new(0, 8.5, 0),
		Color = Color3.new(1, 1, 1),
		Parent = main,
	})
	for _, x in ipairs({ -5.4, 5.4 }) do
		newPart({ Name = "BoardLeg", Size = Vector3.new(0.8, 15.4, 0.8), CFrame = facing * CFrame.new(x, 7.7, 0), Color = frame, Parent = main })
	end
	newPart({
		Name = "BoardRoof",
		Size = Vector3.new(11.8, 0.5, 2.4),
		CFrame = facing * CFrame.new(0, 15.3, 0.3) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = board.Colors[1],
		Parent = main,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50 -- 500 x 650
	gui.LightInfluence = 0.2
	gui.Parent = screen

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 90)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(board.Colors[1], board.Colors[2])
	gradient.Parent = header
	label(header, {
		Text = board.Title,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(16, 18),
		Size = UDim2.new(1, -32, 0, 54),
	})

	local rows = {}
	for i = 1, TOP do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(12, 96 + (i - 1) * 55)
		row.Size = UDim2.new(1, -24, 0, 50)
		row.BackgroundColor3 = if i % 2 == 1 then Color3.fromRGB(245, 246, 250) else Color3.new(1, 1, 1)
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = gui
		corner(row, 12)

		local rank = label(row, {
			Text = tostring(i),
			TextColor3 = if i <= 3 then Color3.new(1, 1, 1) else Color3.fromRGB(125, 130, 148),
			BackgroundTransparency = if i <= 3 then 0 else 1,
			BackgroundColor3 = MEDALS[i] or Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(34, 34),
		})
		corner(rank, 0.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = rank

		-- the player's avatar (head shot) in a round frame
		local avatar = Instance.new("ImageLabel")
		avatar.Position = UDim2.fromOffset(48, 5)
		avatar.Size = UDim2.fromOffset(40, 40)
		avatar.BackgroundColor3 = Color3.fromRGB(225, 230, 240)
		avatar.Image = ""
		avatar.Parent = row
		corner(avatar, 0.5)

		-- the rarest board shows the pet under the name
		local two = board.Id == "Rarest"
		local name = label(row, {
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(96, if two then 5 else 8),
			Size = UDim2.new(0.55, -96, 0, if two then 24 else 34),
		})
		local pet = if two
			then label(row, {
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(96, 29),
				Size = UDim2.new(0.55, -96, 0, 17),
			})
			else nil
		local value = label(row, {
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = board.Colors[1]:Lerp(Color3.new(0, 0, 0), 0.15),
			Position = UDim2.new(0.55, 0, 0, 8),
			Size = UDim2.new(0.45, -10, 0, 34),
		})
		rows[i] = { Frame = row, Name = name, Value = value, Pet = pet, Avatar = avatar }
	end
	board.Rows = rows
end

-- Filling them in -------------------------------------------------------------

-- The global top list with this server's players mixed in (live values).
local function merged(board)
	local values = {}
	for _, entry in ipairs(board.Global) do
		values[entry[1]] = entry[2]
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(player)
		if data then
			values[player.UserId] = math.max(values[player.UserId] or 0, board.Value(data))
		end
	end
	local list = {}
	for userId, value in pairs(values) do
		if value > 0 then
			table.insert(list, { userId, value })
		end
	end
	table.sort(list, function(x, y)
		return x[2] > y[2]
	end)
	return list
end

local function draw(board)
	local list = merged(board)
	for i, row in ipairs(board.Rows) do
		local entry = list[i]
		row.Frame.Visible = entry ~= nil
		if entry then
			row.Name.Text = userName(entry[1])
			row.Avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60"):format(entry[1])
			row.Value.Text = board.Text(entry[2])
			if row.Pet then
				local pet = rarestPetName(entry[1], entry[2])
				local info = pet and Config.PETS[pet]
				row.Pet.Text = pet or ""
				row.Pet.TextColor3 = if info then info.Color:Lerp(Color3.new(0, 0, 0), 0.3) else Color3.fromRGB(125, 130, 148)
			end
		end
	end
end

-- Saves online players' values and reloads the global top lists.
local function refreshGlobal()
	for _, board in ipairs(BOARDS) do
		local store = board.Store
		if store then
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.get(player)
				local value = data and board.Value(data)
				if value and value > 0 and board.Written[player.UserId] ~= value then
					local ok = pcall(store.SetAsync, store, tostring(player.UserId), math.floor(value))
					if ok then
						board.Written[player.UserId] = value
						if board.Id == "Rarest" and rarestPets and data.Rarest then
							pcall(rarestPets.SetAsync, rarestPets, tostring(player.UserId), data.Rarest.Pet)
						end
					end
				end
			end
			local ok, pages = pcall(store.GetSortedAsync, store, false, TOP)
			if ok and pages then
				local global = {}
				for _, item in ipairs(pages:GetCurrentPage()) do
					local userId = tonumber(item.key)
					if userId then
						table.insert(global, { userId, item.value })
					end
				end
				board.Global = global
			end
		end
	end
end

function Leaderboards.start()
	for i, board in ipairs(BOARDS) do
		buildBoard(board, World.LEADERBOARD_ANGLES[i])
	end
	task.spawn(function()
		task.wait(3)
		local lastGlobal = -math.huge
		while true do
			if os.clock() - lastGlobal >= GLOBAL_EVERY then
				lastGlobal = os.clock()
				refreshGlobal()
			end
			for _, board in ipairs(BOARDS) do
				draw(board)
			end
			task.wait(LIVE_EVERY)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		userNameCache[player.UserId] = player.DisplayName
	end)
end

return Leaderboards
