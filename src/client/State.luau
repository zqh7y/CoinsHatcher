-- The client's copy of our player data (pets, upgrades, index, ...).
local State = {}

State.Data = nil
State.Changed = Instance.new("BindableEvent") -- fires (data)

function State.set(data)
	State.Data = data
	State.Changed:Fire(data)
end

return State
