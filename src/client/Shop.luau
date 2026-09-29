-- The shop menu: opens at the shop stall in the main area.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local Shop = {}

local panel = Ui.panel("Shop", "🛒", UDim2.fromOffset(620, 470))

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromScale(1, 1)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel.Content

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local busy = false

local function render()
	Ui.clear(list)
	local data = State.Data
	if not data then
		return
	end

	for order, upgrade in ipairs(Config.UPGRADES) do
		local level = data.Upgrades[upgrade.Id] or 0
		local maxed = level >= upgrade.Max

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 76)
		row.BackgroundColor3 = Ui.COLORS.Card
		row.LayoutOrder = order
		row.Parent = list
		Ui.corner(row, 14)
		Ui.stroke(row, Ui.COLORS.Outline, 2)

		Ui.label(row, { Text = upgrade.Icon, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10) })
		Ui.label(row, {
			Text = upgrade.Name .. (if upgrade.Max > 1 then ("  Lv %d/%d"):format(level, upgrade.Max) else ""),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -230, 0, 30),
			Position = UDim2.fromOffset(76, 8),
		})
		Ui.label(row, {
			Text = upgrade.Info,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(230, 225, 255),
			Size = UDim2.new(1, -230, 0, 22),
			Position = UDim2.fromOffset(76, 42),
		})

		-- level pips
		local pips = Instance.new("Frame")
		pips.BackgroundTransparency = 1
		pips.Size = UDim2.new(1, -230, 0, 6)
		pips.Position = UDim2.fromOffset(76, 66)
		pips.Parent = row
		for i = 1, upgrade.Max do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.new(1 / upgrade.Max, -3, 1, 0)
			pip.Position = UDim2.fromScale((i - 1) / upgrade.Max, 0)
			pip.BackgroundColor3 = if i <= level then Ui.COLORS.Gold else Ui.COLORS.PanelDark
			pip.BorderSizePixel = 0
			pip.Parent = pips
			Ui.corner(pip, 0.5)
		end

		local cost = Config.upgradeCost(upgrade, level, data.Rebirths)
		local canAfford = data.Coins >= cost
		local buy = Ui.button(
			row,
			if maxed then "MAX" else "💰 " .. Config.formatNumber(cost),
			if maxed then Ui.COLORS.PanelDark elseif canAfford then Ui.COLORS.Green else Color3.fromRGB(150, 140, 170),
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(130, 50),
			}
		)
		buy.Activated:Connect(function()
			if maxed or busy then
				return
			end
			busy = true
			local ok, message = remotes.BuyUpgrade:InvokeServer(upgrade.Id)
			if message then
				Ui.toast(message, if ok then Ui.COLORS.Gold else Ui.COLORS.Red)
			end
			busy = false
		end)
	end
end

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)

-- coins change often; refresh the prices' colors when they do
task.spawn(function()
	local pending = false
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		if panel.isOpen() and not pending then
			pending = true
			task.delay(0.3, function()
				pending = false
				if panel.isOpen() then
					if State.Data then
						State.Data.Coins = player:GetAttribute("Coins") or 0
					end
					render()
				end
			end)
		end
	end)
end)

-- open at the stall, close when walking away
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		panel.open()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		if panel.isOpen() then
			local shop = workspace:FindFirstChild("MainArea") and workspace.MainArea:FindFirstChild("Shop")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if shop and root and (shop:GetPivot().Position - root.Position).Magnitude > 20 then
				panel.close()
			end
		end
	end
end)

return Shop
