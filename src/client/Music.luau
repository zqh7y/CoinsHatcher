-- Background music: calm tracks from Config.MUSIC, shuffled, one after
-- another with a soft fade in. The 🎵 button next to the counters turns it
-- on/off (saved with your data).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Music = {}
Music.Changed = Instance.new("BindableEvent") -- fires (on) when turned on/off

local tracks = {}
for _, track in ipairs(Config.MUSIC.Tracks) do
	if track.Id ~= 0 then
		table.insert(tracks, "rbxassetid://" .. track.Id)
	end
end

local sound = Instance.new("Sound")
sound.Name = "Music"
sound.Volume = 0
sound.Parent = SoundService

local on = true
local FADE = 2

local function fadeTo(volume)
	TweenService:Create(sound, TweenInfo.new(FADE), { Volume = volume }):Play()
end

-- a shuffled order, so every track plays once before any repeats
local order, position = {}, 0
local function nextTrack()
	if position >= #order then
		order = table.clone(tracks)
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
		position = 0
	end
	position += 1
	return order[position]
end

local function playNext()
	if #tracks == 0 then
		return
	end
	-- skip tracks that don't load (a wrong or private id)
	repeat
		sound.SoundId = nextTrack()
		sound.Volume = 0
		local start = os.clock()
		while not sound.IsLoaded and os.clock() - start < 8 do
			task.wait(0.2)
		end
		if not sound.IsLoaded then
			task.wait(1)
		end
	until sound.IsLoaded
	sound:Play()
	if on then
		fadeTo(Config.MUSIC.Volume)
	end
end

sound.Ended:Connect(function()
	task.wait(1.5) -- a short break between songs
	playNext()
end)

function Music.isOn()
	return on
end

function Music.set(value)
	if value == on then
		return
	end
	on = value
	fadeTo(if on then Config.MUSIC.Volume else 0)
	remotes.SetMusic:FireServer(on)
	Music.Changed:Fire(on)
end

function Music.toggle()
	Music.set(not on)
end

-- start with the setting saved in your data
task.spawn(function()
	while not State.Data do
		task.wait(0.2)
	end
	on = State.Data.MusicOff ~= true
	Music.Changed:Fire(on)
	playNext()
end)

return Music
