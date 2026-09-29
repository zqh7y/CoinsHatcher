-- A pet card: a light card with a soft glow in the pet's rarity color, a 3D
-- preview, the name and a detail line, plus small badges (equipped,
-- mutation, huge). Compact = a square icon tile (for the inventory grid).
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
		TextColor3 = Ui.COLORS.White,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		ZIndex = 4,
	})
	Ui.corner(b, 0.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

-- options: Silhouette, Detail (text under the name), LayoutOrder, Equipped,
-- Picked (red, for delete mode), Compact (square icon tile), Button (make the
-- card itself clickable; returns it as a TextButton)
function Cards.pet(parent, petName, options)
	options = options or {}
	local info = Config.PETS[petName]
	local hidden = options.Silhouette
	local color = if hidden then Ui.COLORS.Disabled else info.Color
	local compact = options.Compact

	local card = Instance.new(if options.Button then "TextButton" else "Frame")
	card.Name = petName
	card.BackgroundColor3 = if options.Picked then Color3.fromRGB(255, 235, 238) else Ui.COLORS.Soft
	card.LayoutOrder = options.LayoutOrder or 0
	if options.Button then
		card.Text = ""
		card.AutoButtonColor = true
	end
	card.Parent = parent
	Ui.corner(card, 16)
	Ui.stroke(card, if options.Picked then Ui.COLORS.Red elseif options.Equipped then Ui.COLORS.Green else color:Lerp(Color3.new(1, 1, 1), 0.35), if options.Equipped or options.Picked then 2.5 else 1.5)

	-- soft glow in the rarity color behind the pet
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, if compact then 0.44 else 0.3)
	glow.Size = UDim2.fromScale(0.78, if compact then 0.7 else 0.5)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = if hidden then 0.85 else 0.72
	glow.Parent = card
	Ui.corner(glow, 0.5)

	local view = Instance.new("Frame")
	view.Size = if compact then UDim2.fromScale(1, 0.84) else UDim2.new(1, 0, 0.58, 0)
	view.BackgroundTransparency = 1
	view.ZIndex = 2
	view.Parent = card
	Viewport.pet(view, petName, hidden)

	Ui.label(card, {
		Name = "PetName",
		Text = if hidden then "???" else petName,
		Size = if compact then UDim2.new(1, -10, 0.13, 0) else UDim2.new(1, -10, 0.13, 0),
		Position = if compact then UDim2.new(0, 5, 0.83, 0) else UDim2.new(0, 5, 0.6, 0),
		ZIndex = 3,
	})
	if not compact then
		Ui.label(card, {
			Name = "Detail",
			Text = options.Detail or info.Rarity,
			Font = Ui.FONT_BODY,
			TextColor3 = Ui.COLORS.SubText,
			Size = UDim2.new(1, -10, 0.1, 0),
			Position = UDim2.new(0, 5, 0.75, 0),
			ZIndex = 3,
		})
	elseif options.Detail then
		-- small power chip in the corner
		local chip = Ui.label(card, {
			Name = "Detail",
			Text = options.Detail,
			Font = Ui.FONT_BODY,
			TextColor3 = Ui.COLORS.SubText,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(0.62, 0, 0.12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		chip.Name = "Detail"
	end

	if options.Equipped then
		badge(card, "✓", Ui.COLORS.Green, Vector2.new(1, 0), UDim2.new(1, -5, 0, 5))
	end
	if options.Picked then
		badge(card, "✕", Ui.COLORS.Red, Vector2.new(1, 0), UDim2.new(1, -5, 0, 5))
	end
	if not hidden and info.Mutation then
		badge(card, MUTATION_ICONS[info.Mutation], Color3.fromRGB(120, 90, 220), Vector2.new(0, 1), UDim2.new(0, 5, if compact then 0.8 else 0.56, 0))
	elseif not hidden and info.Rarity == "Huge" then
		badge(card, "💎", Color3.fromRGB(230, 70, 170), Vector2.new(0, 1), UDim2.new(0, 5, if compact then 0.8 else 0.56, 0))
	end
	return card
end

return Cards
