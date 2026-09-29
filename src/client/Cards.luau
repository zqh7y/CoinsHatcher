-- A pet card: 3D preview on top, name and a detail line underneath.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Viewport = require(script.Parent.Viewport)

local Cards = {}

-- options: Silhouette, Detail (text under the name), LayoutOrder, Background
function Cards.pet(parent, petName, options)
	options = options or {}
	local info = Config.PETS[petName]
	local hidden = options.Silhouette

	local card = Instance.new("Frame")
	card.Name = petName
	card.BackgroundColor3 = options.Background or Ui.COLORS.Card
	card.LayoutOrder = options.LayoutOrder or 0
	card.Parent = parent
	Ui.corner(card, 14)
	Ui.stroke(card, if hidden then Ui.COLORS.Outline else info.Color, 3)

	local view = Instance.new("Frame")
	view.Size = UDim2.new(1, 0, 0.58, 0)
	view.BackgroundTransparency = 1
	view.Parent = card
	Viewport.pet(view, petName, hidden)

	Ui.label(card, {
		Name = "PetName",
		Text = if hidden then "???" else petName,
		TextColor3 = if hidden then Ui.COLORS.White else info.Color,
		Size = UDim2.new(1, -10, 0.17, 0),
		Position = UDim2.new(0, 5, 0.58, 0),
	})
	Ui.label(card, {
		Name = "Detail",
		Text = options.Detail or info.Rarity,
		Size = UDim2.new(1, -10, 0.14, 0),
		Position = UDim2.new(0, 5, 0.76, 0),
	})
	return card
end

return Cards
