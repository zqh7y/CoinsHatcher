-- The client's copy of our player data (pets, upgrades, index, ...).
local State = {}

State.Data = nil
State.Changed = Instance.new("BindableEvent") -- fires (data)

State.ReceivedAt = os.clock() -- when Data arrived (potion timers count down from here)

function State.set(data)
	State.Data = data
	State.ReceivedAt = os.clock()
	State.Changed:Fire(data)
end

-- Seconds left on a potion, counting down locally between server updates.
function State.boostLeft(id)
	local data = State.Data
	local seconds = data and data.Boosts and data.Boosts[id] or 0
	return math.max(0, seconds - (os.clock() - State.ReceivedAt))
end

return State
