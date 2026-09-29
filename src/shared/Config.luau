-- All the game's numbers and formulas live here so they're easy to tweak.
local Config = {}

-- Rebirths ------------------------------------------------------------------

Config.MAX_REBIRTHS = 3

-- Every rebirth multiplies the main area's coin health and coin value by this.
-- Egg costs and pet power scale by the same amount so the game stays balanced.
Config.SCALE = 5

function Config.rebirthCost(rebirths: number): number
	return 1500 * Config.SCALE ^ rebirths
end

-- Main area -----------------------------------------------------------------

Config.COINS_PER_PLAYER = 18
Config.COIN_RESPAWN_TIME = 1

-- The things pets break in the coin zone. Chance is a weight;
-- Mult multiplies both health and coins.
Config.BREAKABLES = {
	{ Name = "Coins", Chance = 60, Mult = 1 }, -- a stack of 4 coins
	{ Name = "Coin Pile", Chance = 27, Mult = 3 },
	{ Name = "Chest", Chance = 10, Mult = 10 },
	{ Name = "Big Chest", Chance = 3, Mult = 30 },
}

function Config.coinStats(rebirths: number, kind: number)
	local scale = Config.SCALE ^ rebirths * Config.BREAKABLES[kind].Mult
	return {
		Health = 12 * scale,
		Value = 10 * scale,
	}
end

function Config.rollBreakable(): number
	return Config.rollWeighted(Config.BREAKABLES)
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
Config.PET_HIT_INTERVAL = 0.6 -- seconds between hits; each hit deals the pet's power

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

-- What each pet looks like. Pets are little cubes with a face plus:
--   Ears: "pointy", "round", "long", "floppy" or nil
--   Tail: "short", "long", "fluffy", "fin" or nil
--   Extras: any of "wings", "beak", "horns", "antlers", "shell", "claws",
--           "topfin", "fire", "nofeet"
Config.PET_LOOKS = {
	Dog = { Ears = "floppy", Tail = "short" },
	Cat = { Ears = "pointy", Tail = "long" },
	Bunny = { Ears = "long", Tail = "fluffy" },
	Bear = { Ears = "round", Tail = "short" },
	Fox = { Ears = "pointy", Tail = "fluffy" },
	Deer = { Ears = "pointy", Tail = "short", Extras = { "antlers" } },
	Owl = { Ears = "pointy", Extras = { "beak", "wings" } },
	Wolf = { Ears = "pointy", Tail = "fluffy" },
	Fish = { Tail = "fin", Extras = { "topfin", "nofeet" } },
	Crab = { Extras = { "claws" } },
	Turtle = { Tail = "short", Extras = { "shell" } },
	Shark = { Tail = "fin", Extras = { "topfin", "nofeet" } },
	Salamander = { Tail = "long", Extras = { "fire" } },
	["Magma Golem"] = { Extras = { "horns", "fire" } },
	Phoenix = { Tail = "long", Extras = { "beak", "wings", "fire" } },
	Dragon = { Tail = "long", Extras = { "horns", "wings" } },
}

Config.EGG_COUNT = math.min(#Config.EGGS, Config.MAX_REBIRTHS + 1)

function Config.eggCost(eggIndex: number): number
	return 50 * Config.SCALE ^ (eggIndex - 1)
end

function Config.eggRequiredRebirths(eggIndex: number): number
	return eggIndex - 1
end

-- Pet power = damage per hit. Stronger pets break coins faster.
function Config.petPower(eggIndex: number, rarityIndex: number): number
	return 5 * Config.SCALE ^ (eggIndex - 1) * Config.RARITIES[rarityIndex].Power
end

-- Huge pets: every egg has a super rare giant version of its legendary pet.
Config.HUGE_CHANCE = 0.5 -- percent per hatch, before luck
Config.HUGE_POWER = 5 -- times the legendary's power
Config.HUGE_SCALE = 2 -- times bigger
Config.HUGE_COLOR = Color3.fromRGB(255, 90, 200)

-- Lookup table built from the eggs:
-- Config.PETS["Dog"] = { Egg, Rarity, Power, Color, BodyColor, Look, Scale }
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
			Look = Config.PET_LOOKS[petName] or {},
			Scale = 1,
		}
	end

	local base = egg.Pets[#egg.Pets]
	egg.Huge = "Huge " .. base
	Config.PETS[egg.Huge] = {
		Egg = eggIndex,
		Rarity = "Huge",
		Power = Config.PETS[base].Power * Config.HUGE_POWER,
		Color = Config.HUGE_COLOR,
		BodyColor = Config.PETS[base].BodyColor,
		Look = Config.PETS[base].Look,
		Scale = Config.HUGE_SCALE,
	}
end

-- Picks a random index from a list of { Chance = weight } entries.
function Config.rollWeighted(list): number
	local total = 0
	for _, entry in ipairs(list) do
		total += entry.Chance
	end
	local roll = math.random() * total
	for i, entry in ipairs(list) do
		roll -= entry.Chance
		if roll <= 0 then
			return i
		end
	end
	return 1
end

-- The chance (in %) of each pet in an egg, including luck from upgrades.
-- Returns a list of { Pet, Chance } with the huge pet last.
function Config.eggChances(eggIndex: number, upgrades)
	local luck = Config.luckMult(upgrades)
	local egg = Config.EGGS[eggIndex]
	local hugeChance = Config.HUGE_CHANCE * luck

	-- luck makes Rare and better pets more likely
	local weights, total = {}, 0
	for i, rarity in ipairs(Config.RARITIES) do
		weights[i] = rarity.Chance * (if i >= 3 then luck else 1)
		total += weights[i]
	end

	local list = {}
	for i, petName in ipairs(egg.Pets) do
		table.insert(list, { Pet = petName, Chance = weights[i] / total * (100 - hugeChance) })
	end
	table.insert(list, { Pet = egg.Huge, Chance = hugeChance })
	return list
end

function Config.rollHatch(eggIndex: number, upgrades): string
	local list = Config.eggChances(eggIndex, upgrades)
	return list[Config.rollWeighted(list)].Pet
end

-- Shop upgrades ----------------------------------------------------------------
-- Upgrades reset on rebirth (rebirth resets everything except pets).
-- Cost = BaseCost * Growth^level, times SCALE^rebirths like everything else.
Config.UPGRADES = {
	{ Id = "Damage", Name = "Pet Damage", Icon = "⚔️", Max = 10, BaseCost = 40, Growth = 1.6, Info = "+20% pet damage" },
	{ Id = "Luck", Name = "Luck", Icon = "🍀", Max = 10, BaseCost = 60, Growth = 1.6, Info = "+15% rare & huge chance" },
	{ Id = "WalkSpeed", Name = "Walk Speed", Icon = "👟", Max = 8, BaseCost = 30, Growth = 1.5, Info = "+2 walk speed" },
	{ Id = "PetSpeed", Name = "Pet Speed", Icon = "💨", Max = 5, BaseCost = 50, Growth = 1.7, Info = "+15% pet run speed" },
	{ Id = "CoinBonus", Name = "Coin Bonus", Icon = "💰", Max = 10, BaseCost = 80, Growth = 1.6, Info = "+10% coins" },
	{ Id = "Slots", Name = "Pet Slots", Icon = "🐾", Max = 3, BaseCost = 300, Growth = 3, Info = "+1 pet you can equip" },
	{ Id = "Hoverboard", Name = "Hoverboard", Icon = "🛹", Max = 1, BaseCost = 500, Growth = 1, Info = "Ride a super fast hoverboard!" },
}

Config.UPGRADES_BY_ID = {}
for _, upgrade in ipairs(Config.UPGRADES) do
	Config.UPGRADES_BY_ID[upgrade.Id] = upgrade
end

function Config.upgradeCost(upgrade, level: number, rebirths: number): number
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ level * Config.SCALE ^ rebirths)
end

local function level(upgrades, id)
	return if upgrades then upgrades[id] or 0 else 0
end

function Config.damageMult(upgrades): number
	return 1 + 0.2 * level(upgrades, "Damage")
end
function Config.luckMult(upgrades): number
	return 1 + 0.15 * level(upgrades, "Luck")
end
function Config.walkSpeed(upgrades): number
	return 16 + 2 * level(upgrades, "WalkSpeed")
end
function Config.petSpeedMult(upgrades): number
	return 1 + 0.15 * level(upgrades, "PetSpeed")
end
function Config.coinMult(upgrades): number
	return 1 + 0.1 * level(upgrades, "CoinBonus")
end
function Config.maxEquipped(upgrades): number
	return Config.MAX_EQUIPPED + level(upgrades, "Slots")
end
Config.HOVERBOARD_SPEED = 14 -- extra walk speed while riding

-- 12345 -> "12,345"
function Config.formatNumber(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

return Config
