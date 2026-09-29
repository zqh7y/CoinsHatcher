-- A pet card: a glowing gradient in the pet's rarity color, a 3D preview,
-- the name and a detail line, plus little badges (equipped, mutation).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local Viewport = require(script.Parent.Viewport)

local Cards = {}

local MUTATION_ICONS = {}
for _, mutation in ipairs(Config.MUTATIONS) do
	MUTATION_ICONS[mutation.Name] = mutation.Icon
end

local function badge(parent, text, color, anchor, position)
	local b = Ui.label(parent, {
		Text = text,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextStrokeTransparency = 1,
		ZIndex = 4,
	})
	Ui.corner(b, 0.5)
	Ui.stroke(b, Color3.new(1, 1, 1), 2)
	return b
end

-- options: Silhouette, Detail (text under the name), LayoutOrder, Equipped,
-- Picked (red, for delete mode)
function Cards.pet(parent, petName, options)
	options = options or {}
	local info = Config.PETS[petName]
	local hidden = options.Silhouette
	local color = if hidden then Color3.fromRGB(70, 55, 110) else info.Color

	local card = Instance.new("Frame")
	card.Name = petName
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.LayoutOrder = options.LayoutOrder or 0
	card.Parent = parent
	Ui.corner(card, 14)
	Ui.stroke(card, if options.Picked then Ui.COLORS.Red else color:Lerp(Color3.new(1, 1, 1), 0.3), 3)

	-- rarity gradient
	local top = if options.Picked then Color3.fromRGB(255, 120, 130) else color:Lerp(Color3.new(1, 1, 1), 0.2)
	local bottom = if options.Picked then Color3.fromRGB(170, 40, 60) else color:Lerp(Color3.fromRGB(40, 20, 80), 0.55)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = card

	-- soft glow behind the pet
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.3)
	glow.Size = UDim2.fromScale(0.75, 0.5)
	glow.BackgroundColor3 = Color3.new(1, 1, 1)
	glow.BackgroundTransparency = if hidden then 0.9 else 0.7
	glow.Parent = card
	Ui.corner(glow, 0.5)

	local view = Instance.new("Frame")
	view.Size = UDim2.new(1, 0, 0.58, 0)
	view.BackgroundTransparency = 1
	view.ZIndex = 2
	view.Parent = card
	Viewport.pet(view, petName, hidden)

	Ui.label(card, {
		Name = "PetName",
		Text = if hidden then "???" else petName,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -10, 0.15, 0),
		Position = UDim2.new(0, 5, 0.58, 0),
		ZIndex = 3,
	})
	Ui.label(card, {
		Name = "Detail",
		Text = options.Detail or info.Rarity,
		TextColor3 = Color3.fromRGB(255, 245, 200),
		Size = UDim2.new(1, -10, 0.12, 0),
		Position = UDim2.new(0, 5, 0.75, 0),
		ZIndex = 3,
	})

	if options.Equipped then
		badge(card, "✔", Ui.COLORS.Green, Vector2.new(1, 0), UDim2.new(1, -4, 0, 4))
	end
	if not hidden and info.Mutation then
		badge(card, MUTATION_ICONS[info.Mutation], Color3.fromRGB(80, 50, 140), Vector2.new(0, 0), UDim2.fromOffset(4, 4))
	elseif not hidden and info.Rarity == "Huge" then
		badge(card, "💎", Color3.fromRGB(200, 60, 160), Vector2.new(0, 0), UDim2.fromOffset(4, 4))
	end
	return card
end

return Cards
