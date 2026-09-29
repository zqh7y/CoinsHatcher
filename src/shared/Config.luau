-- All the game's numbers and formulas live here so they're easy to tweak.
local Config = {}

-- Rebirths ------------------------------------------------------------------

Config.MAX_REBIRTHS = 3

-- Every rebirth multiplies the main area's coin health and coin value by this.
-- Egg costs and pet power scale by the same amount so the game stays balanced.
Config.SCALE = 5

function Config.rebirthCost(rebirths: number): number
	return 2500 * Config.SCALE ^ rebirths
end

-- Main area -----------------------------------------------------------------

Config.COINS_PER_PLAYER = 20
Config.COIN_RESPAWN_TIME = 1.5

-- size is 1 (small), 2 (medium) or 3 (big)
function Config.coinStats(rebirths: number, size: number)
	local scale = Config.SCALE ^ rebirths
	return {
		Health = 20 * size * scale,
		Value = 5 * size * scale,
	}
end

-- Floor color of the main area at each rebirth level (last one repeats).
Config.AREA_COLORS = {
	Color3.fromRGB(120, 210, 90), -- grass
	Color3.fromRGB(250, 215, 130), -- sand
	Color3.fromRGB(215, 235, 255), -- snow
	Color3.fromRGB(255, 180, 215), -- candy
}

function Config.areaColor(rebirths: number): Color3
	return Config.AREA_COLORS[math.min(rebirths + 1, #Config.AREA_COLORS)]
end

-- Pets ----------------------------------------------------------------------

Config.MAX_EQUIPPED = 3
Config.MAX_PETS = 50
Config.STARTER_PET = "Dog"
Config.PET_SPEED = 32 -- studs per second when running to a coin

-- Rarities in order. Chance is a weight, Power multiplies the egg's base power.
Config.RARITIES = {
	{ Name = "Common", Chance = 60, Power = 1, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Uncommon", Chance = 28, Power = 2, Color = Color3.fromRGB(90, 200, 90) },
	{ Name = "Rare", Chance = 10, Power = 4, Color = Color3.fromRGB(80, 140, 255) },
	{ Name = "Legendary", Chance = 2, Power = 10, Color = Color3.fromRGB(255, 190, 40) },
}

-- Eggs: egg N unlocks at rebirth N-1. Each egg has one pet per rarity,
-- listed in the same order as RARITIES.
Config.EGGS = {
	{ Name = "Basic Egg", Color = Color3.fromRGB(245, 240, 225), Pets = { "Dog", "Cat", "Bunny", "Bear" } },
	{ Name = "Forest Egg", Color = Color3.fromRGB(90, 150, 70), Pets = { "Fox", "Deer", "Owl", "Wolf" } },
	{ Name = "Ocean Egg", Color = Color3.fromRGB(60, 140, 210), Pets = { "Fish", "Crab", "Turtle", "Shark" } },
	{ Name = "Lava Egg", Color = Color3.fromRGB(220, 80, 30), Pets = { "Salamander", "Magma Golem", "Phoenix", "Dragon" } },
}

-- Body color of each pet (the name tag uses the rarity color)
Config.PET_COLORS = {
	Dog = Color3.fromRGB(230, 185, 130),
	Cat = Color3.fromRGB(255, 170, 90),
	Bunny = Color3.fromRGB(255, 225, 235),
	Bear = Color3.fromRGB(170, 120, 85),
	Fox = Color3.fromRGB(255, 140, 60),
	Deer = Color3.fromRGB(205, 150, 100),
	Owl = Color3.fromRGB(175, 140, 215),
	Wolf = Color3.fromRGB(165, 180, 205),
	Fish = Color3.fromRGB(120, 205, 255),
	Crab = Color3.fromRGB(255, 110, 100),
	Turtle = Color3.fromRGB(120, 210, 130),
	Shark = Color3.fromRGB(110, 150, 200),
	Salamander = Color3.fromRGB(255, 150, 80),
	["Magma Golem"] = Color3.fromRGB(230, 100, 60),
	Phoenix = Color3.fromRGB(255, 200, 60),
	Dragon = Color3.fromRGB(190, 110, 255),
}

Config.EGG_COUNT = math.min(#Config.EGGS, Config.MAX_REBIRTHS + 1)

function Config.eggCost(eggIndex: number): number
	return 100 * Config.SCALE ^ (eggIndex - 1)
end

function Config.eggRequiredRebirths(eggIndex: number): number
	return eggIndex - 1
end

-- Pet power = damage per second to coins. Stronger pets break coins faster.
function Config.petPower(eggIndex: number, rarityIndex: number): number
	return 5 * Config.SCALE ^ (eggIndex - 1) * Config.RARITIES[rarityIndex].Power
end

-- Lookup table built from the eggs: Config.PETS["Dog"] = { Egg, Rarity, Power, Color }
Config.PETS = {}
for eggIndex, egg in ipairs(Config.EGGS) do
	for rarityIndex, petName in ipairs(egg.Pets) do
		local rarity = Config.RARITIES[rarityIndex]
		Config.PETS[petName] = {
			Egg = eggIndex,
			Rarity = rarity.Name,
			Power = Config.petPower(eggIndex, rarityIndex),
			Color = rarity.Color,
			BodyColor = Config.PET_COLORS[petName] or rarity.Color,
		}
	end
end

-- Picks a random rarity index using the Chance weights.
function Config.rollRarity(): number
	local total = 0
	for _, rarity in ipairs(Config.RARITIES) do
		total += rarity.Chance
	end
	local roll = math.random() * total
	for i, rarity in ipairs(Config.RARITIES) do
		roll -= rarity.Chance
		if roll <= 0 then
			return i
		end
	end
	return 1
end

-- 12345 -> "12,345"
function Config.formatNumber(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

return Config
