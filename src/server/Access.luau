-- "Coming soon" lock: the game can be public (so it shows on your profile)
-- while only allowed players can actually play. Everyone else sees the
-- coming-soon message and is sent back out. Set Config.ACCESS.Open = true on
-- release day.
--
-- Always allowed: the game's owner (or the owner / high ranks of the group
-- that owns it), anyone in Config.ACCESS.AllowedUserIds, and anyone playing
-- in Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Access = {}

-- Can this player play while the game is closed?
function Access.isAllowed(player)
	local access = Config.ACCESS
	if access.Open or RunService:IsStudio() then
		return true
	end
	if table.find(access.AllowedUserIds, player.UserId) then
		return true
	end
	-- the game's owner
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	-- a group game: the group's owner and high ranks (admins) can play
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank >= access.GroupMinRank then
			return true
		end
	end
	return false
end

local function check(player)
	if not Access.isAllowed(player) then
		player:Kick(Config.ACCESS.Message)
	end
end

function Access.start()
	Players.PlayerAdded:Connect(check)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(check, player)
	end
end

return Access
