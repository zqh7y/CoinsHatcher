-- The rebirth menu: shows the cost and what happens, with a big button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Rebirth = {}

local panel = Ui.panel("Rebirth", nil, UDim2.fromOffset(480, 380), { Ui.COLORS.Accent2 })

local info = Ui.label(panel.Content, {
	Size = UDim2.new(1, 0, 0, 44),
	TextColor3 = Ui.COLORS.Accent2,
})
local details = Ui.label(panel.Content, {
	Size = UDim2.new(1, -10, 0, 120),
	Position = UDim2.fromOffset(5, 52),
	TextScaled = false,
	TextSize = 20,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "✅ You keep all your pets!\n"
		.. "🔄 Coins and shop upgrades reset.\n"
		.. "💪 The main area gets stronger (more coins!).\n"
		.. "🥚 A new egg unlocks!",
})
local button = Ui.button(panel.Content, "⭐ REBIRTH", Color3.fromRGB(170, 90, 230), {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -4),
	Size = UDim2.fromOffset(260, 64),
})

local function render()
	local data = State.Data
	if not data then
		return
	end
	if data.Rebirths >= Config.MAX_REBIRTHS then
		info.Text = "You're at max rebirth! 🎉"
		details.Visible = false
		button.Visible = false
	else
		info.Text = ("Rebirth %d → %d  ·  💰 %s"):format(
			data.Rebirths,
			data.Rebirths + 1,
			Config.formatNumber(Config.rebirthCost(data.Rebirths))
		)
		details.Visible = true
		button.Visible = true
	end
end

local busy = false
button.Activated:Connect(function()
	if busy then
		return
	end
	busy = true
	local ok, message = remotes.Rebirth:InvokeServer()
	Ui.toast(message, if ok then Color3.fromRGB(220, 170, 255) else Ui.COLORS.Red)
	if ok then
		panel.close()
		Fx.celebrate("⭐ REBIRTH! ⭐", Color3.fromRGB(230, 180, 255))
	end
	busy = false
end)

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)

Rebirth.toggle = panel.toggle

return Rebirth
