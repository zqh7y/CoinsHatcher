-- All the game's numbers and formulas live here so they're easy to tweak.
local Config = {}

-- Rebirths ------------------------------------------------------------------

Config.MAX_REBIRTHS = 3

-- Every rebirth multiplies the main area's coin health and coin value by this.
-- Egg costs and pet power scale by the same amount so the game stays balanced.
-- Numbers start big (hundreds/thousands) and grow x10 per rebirth, so they
-- feel big without jumping into crazy ranges.
Config.SCALE = 10

function Config.rebirthCost(rebirths: number): number
	return 25000 * Config.SCALE ^ rebirths
end

-- Main area -----------------------------------------------------------------

Config.COINS_PER_PLAYER = 18
Config.COIN_RESPAWN_TIME = 1

-- The things pets break in the coin zone. Chance is a weight;
-- Mult multiplies both health and coins.
-- Diamonds: how many a breakable drops, and the chance (0-1) it has them.
Config.BREAKABLES = {
	{ Name = "Coins", Chance = 60, Mult = 1, Diamonds = 0, DiamondChance = 0 }, -- a stack of 4 coins
	{ Name = "Coin Pile", Chance = 27, Mult = 3, Diamonds = 1, DiamondChance = 0.1 },
	{ Name = "Chest", Chance = 10, Mult = 10, Diamonds = 1, DiamondChance = 1 },
	{ Name = "Big Chest", Chance = 3, Mult = 30, Diamonds = 4, DiamondChance = 1 },
}

function Config.coinStats(rebirths: number, kind: number)
	local scale = Config.SCALE ^ rebirths * Config.BREAKABLES[kind].Mult
	return {
		Health = 100 * scale,
		Value = 150 * scale,
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
Config.MAX_PETS = 100
Config.STARTER_PET = "Dog"
Config.PET_SPEED = 32 -- studs per second when running to a coin
Config.PET_HIT_INTERVAL = 0.6 -- seconds between hits; each hit deals the pet's power
Config.CRIT_CHANCE = 0.1 -- 10% of hits are critical hits...
Config.CRIT_MULT = 3 -- ...that deal 3x damage

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
	return 1000 * Config.SCALE ^ (eggIndex - 1)
end

function Config.eggRequiredRebirths(eggIndex: number): number
	return eggIndex - 1
end

-- Pet power = damage per hit. Stronger pets break coins faster.
function Config.petPower(eggIndex: number, rarityIndex: number): number
	return 40 * Config.SCALE ^ (eggIndex - 1) * Config.RARITIES[rarityIndex].Power
end

-- Huge pets: every egg has a super rare giant version of its legendary pet.
Config.HUGE_CHANCE = 0.5 -- percent per hatch, before luck
Config.HUGE_POWER = 3 -- times the legendary's power
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

-- Mutations: a hatched pet can come out mutated, with more power and a
-- special look. Huge pets don't mutate (they're special enough). Chance is in
-- percent, before luck.
Config.MUTATIONS = {
	{ Name = "Shiny", Icon = "✨", Chance = 5, Power = 1.5, Color = Color3.fromRGB(255, 240, 150) },
	{ Name = "Rainbow", Icon = "🌈", Chance = 2, Power = 2, Color = Color3.fromRGB(255, 120, 200) },
	{ Name = "Galaxy", Icon = "🌌", Chance = 0.5, Power = 3, Color = Color3.fromRGB(170, 110, 255) },
}

-- Adds "Shiny Dog", "Rainbow Huge Dragon", ... to Config.PETS
local basePets = {}
for petName, info in pairs(Config.PETS) do
	if info.Rarity ~= "Huge" then
		table.insert(basePets, petName)
	end
end
for _, petName in ipairs(basePets) do
	local base = Config.PETS[petName]
	for _, mutation in ipairs(Config.MUTATIONS) do
		Config.PETS[mutation.Name .. " " .. petName] = {
			Egg = base.Egg,
			Rarity = base.Rarity,
			Power = base.Power * mutation.Power,
			Color = mutation.Color,
			BodyColor = base.BodyColor,
			Look = base.Look,
			Scale = base.Scale,
			Mutation = mutation.Name,
			Base = petName,
		}
	end
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

-- The chance (in %) of each pet in an egg, including the player's luck
-- (data can be nil for the base odds). Returns a list of { Pet, Chance }
-- with the huge pet last.
function Config.eggChances(eggIndex: number, data)
	local luck = Config.totalLuck(data)
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

-- Mutation chances (in %) with the player's luck applied.
function Config.mutationChances(data)
	local luck = Config.totalLuck(data)
	local list = {}
	for _, mutation in ipairs(Config.MUTATIONS) do
		table.insert(list, { Mutation = mutation, Chance = mutation.Chance * luck })
	end
	return list
end

-- The base odds of hatching this exact pet (mutation included), e.g. "1 in 5K".
function Config.chanceText(petName: string): string
	local info = Config.PETS[petName]
	if not info then
		return ""
	end
	local name = info.Base or petName
	local chance = nil
	for _, entry in ipairs(Config.eggChances(info.Egg, nil)) do
		if entry.Pet == name then
			chance = entry.Chance / 100
		end
	end
	if not chance then
		return ""
	end
	if info.Mutation then
		for _, mutation in ipairs(Config.MUTATIONS) do
			if mutation.Name == info.Mutation then
				chance *= mutation.Chance / 100
			end
		end
	end
	return "1 in " .. Config.formatNumber(math.floor(1 / chance + 0.5))
end

-- Rolls a pet from the egg, then maybe a mutation.
function Config.rollHatch(eggIndex: number, data): string
	local list = Config.eggChances(eggIndex, data)
	local petName = list[Config.rollWeighted(list)].Pet
	if Config.PETS[petName].Rarity == "Huge" then
		return petName
	end
	-- rarest mutation first, so luck can't make a common one hide a rare one
	local roll = math.random() * 100
	local chances = Config.mutationChances(data)
	for i = #chances, 1, -1 do
		if roll < chances[i].Chance then
			return chances[i].Mutation.Name .. " " .. petName
		end
		roll -= chances[i].Chance
	end
	return petName
end

-- Is this hatch worth announcing to the whole server?
function Config.isRare(petName: string): boolean
	local info = Config.PETS[petName]
	return info ~= nil
		and (info.Rarity == "Legendary" or info.Rarity == "Huge" or info.Mutation == "Rainbow" or info.Mutation == "Galaxy")
end

-- Shop upgrades ----------------------------------------------------------------
-- Upgrades reset on rebirth (rebirth resets everything except pets).
-- Cost = BaseCost * Growth^level, times SCALE^rebirths like everything else.
Config.UPGRADES = {
	{ Id = "Damage", Name = "Pet Damage", Icon = "⚔️", Max = 10, BaseCost = 600, Growth = 1.6, Info = "+20% pet damage" },
	{ Id = "Luck", Name = "Luck", Icon = "🍀", Max = 10, BaseCost = 900, Growth = 1.6, Info = "+15% rare & huge chance" },
	{ Id = "WalkSpeed", Name = "Walk Speed", Icon = "👟", Max = 8, BaseCost = 450, Growth = 1.5, Info = "+2 walk speed" },
	{ Id = "PetSpeed", Name = "Pet Speed", Icon = "💨", Max = 5, BaseCost = 750, Growth = 1.7, Info = "+15% pet run speed" },
	{ Id = "CoinBonus", Name = "Coin Bonus", Icon = "💰", Max = 10, BaseCost = 1200, Growth = 1.6, Info = "+10% coins" },
	{ Id = "Slots", Name = "Pet Slots", Icon = "🐾", Max = 3, BaseCost = 4500, Growth = 3, Info = "+1 pet you can equip" },
	{ Id = "Hoverboard", Name = "Hoverboard", Icon = "🛹", Max = 1, BaseCost = 7500, Growth = 1, Info = "Ride a super fast hoverboard!" },
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

-- Diamonds ------------------------------------------------------------------
-- Diamonds never reset. Earned from chests, new pets, rebirths and gifts;
-- spent on boost potions and permanent perks.
Config.DIAMONDS_NEW_PET = 25 -- first time you hatch a pet
Config.DIAMONDS_NEW_HUGE = 250 -- first time you hatch a huge
Config.DIAMONDS_PER_REBIRTH = 100 -- times the new rebirth number

function Config.giftDiamonds(giftIndex: number): number
	return 10 * giftIndex
end

-- Potions: 2x for a while. Buying more adds time (up to BOOST_MAX_MINUTES).
-- Their time only counts down while you're playing.
Config.BOOSTS = {
	{ Id = "Coins", Name = "2x Coins", Icon = "💰", Cost = 250, Minutes = 10 },
	{ Id = "Luck", Name = "2x Luck", Icon = "🍀", Cost = 300, Minutes = 10 },
	{ Id = "Damage", Name = "2x Damage", Icon = "⚔️", Cost = 250, Minutes = 10 },
}
Config.BOOST_MAX_MINUTES = 60

-- Perks: permanent, kept through rebirths.
Config.PERKS = {
	{ Id = "Coins", Name = "Coin Master", Icon = "💰", Max = 10, BaseCost = 300, Growth = 1.4, Info = "+10% coins forever" },
	{ Id = "Luck", Name = "Lucky Charm", Icon = "🍀", Max = 10, BaseCost = 350, Growth = 1.4, Info = "+10% luck forever" },
	{ Id = "Backpack", Name = "Big Backpack", Icon = "🎒", Max = 4, BaseCost = 600, Growth = 2, Info = "+25 pet storage" },
	{ Id = "Slots", Name = "Extra Slot", Icon = "🐾", Max = 2, BaseCost = 2000, Growth = 3, Info = "+1 pet slot forever" },
}

Config.BOOSTS_BY_ID = {}
for _, boost in ipairs(Config.BOOSTS) do
	Config.BOOSTS_BY_ID[boost.Id] = boost
end
Config.PERKS_BY_ID = {}
for _, perk in ipairs(Config.PERKS) do
	Config.PERKS_BY_ID[perk.Id] = perk
end

function Config.perkCost(perk, level: number): number
	return math.floor(perk.BaseCost * perk.Growth ^ level)
end

local function perkLevel(data, id)
	return if data and data.Perks then data.Perks[id] or 0 else 0
end
local function boosted(data, id)
	return if data and data.Boosts and (data.Boosts[id] or 0) > 0 then 2 else 1
end

-- Totals: shop upgrades + diamond perks + potions, from the player's data.
function Config.totalDamage(data): number
	return Config.damageMult(data and data.Upgrades) * boosted(data, "Damage")
end
function Config.totalLuck(data): number
	return (Config.luckMult(data and data.Upgrades) + 0.1 * perkLevel(data, "Luck")) * boosted(data, "Luck")
end
function Config.totalCoins(data): number
	return (Config.coinMult(data and data.Upgrades) + 0.1 * perkLevel(data, "Coins")) * boosted(data, "Coins")
end
function Config.totalSlots(data): number
	return Config.maxEquipped(data and data.Upgrades) + perkLevel(data, "Slots")
end
function Config.maxPets(data): number
	return Config.MAX_PETS + 25 * perkLevel(data, "Backpack")
end

-- Numbers for kids: 1,234 / 12.5K / 3.4M / 750B / 1.2T ...
local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.formatNumber(n: number): string
	n = math.floor(n)
	if math.abs(n) < 10000 then
		local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (s:gsub("^(-?),", "%1"))
	end
	local tier = math.min(math.floor(math.log10(math.abs(n)) / 3), #SUFFIXES)
	local short = n / 1000 ^ tier
	local text = if math.abs(short) < 100 then string.format("%.1f", short) else string.format("%d", math.floor(short))
	return (text:gsub("%.0$", "")) .. SUFFIXES[tier]
end

-- Playtime gifts --------------------------------------------------------------
-- Minutes of play (this session) needed for each gift.
Config.GIFT_TIMES = { 1, 3, 5, 10, 15, 20 }

-- Gift coins grow with each gift and with your rebirths.
function Config.giftReward(giftIndex: number, rebirths: number): number
	return 1800 * 2 ^ (giftIndex - 1) * Config.SCALE ^ rebirths
end

return Config
