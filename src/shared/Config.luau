-- All the game's numbers and formulas live here so they're easy to tweak.
local Config = {}

-- Rebirths ------------------------------------------------------------------

Config.MAX_REBIRTHS = 10

-- Every rebirth multiplies the main area's coin health and coin value by this.
-- Egg costs and pet power scale by the same amount so the game stays balanced.
-- Numbers start big (hundreds/thousands) and grow x4 per rebirth, so after
-- 10 rebirths they reach millions/billions without jumping into crazy ranges.
Config.SCALE = 4

function Config.rebirthCost(rebirths: number): number
	return 25000 * Config.SCALE ^ rebirths
end

-- Main area -----------------------------------------------------------------

Config.COINS_PER_PLAYER = 2 -- starts small; the board's "More Stuff" upgrade adds up to 18 more
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

function Config.rollBreakable(data): number
	return Config.rollWeighted(Config.breakableWeights(data))
end

-- Floor color of the main area at each rebirth level (last one repeats).
Config.AREA_COLORS = { -- kept mid-bright like the grass so nothing glares
	Color3.fromRGB(120, 210, 90), -- grass
	Color3.fromRGB(215, 175, 90), -- sand
	Color3.fromRGB(140, 185, 225), -- ice
	Color3.fromRGB(235, 130, 185), -- candy
	Color3.fromRGB(70, 160, 215), -- ocean
	Color3.fromRGB(70, 160, 90), -- jungle
	Color3.fromRGB(240, 140, 80), -- sunset
	Color3.fromRGB(160, 120, 235), -- magic
	Color3.fromRGB(90, 200, 160), -- mint
	Color3.fromRGB(100, 90, 190), -- space
	Color3.fromRGB(230, 180, 50), -- gold
}

function Config.areaColor(rebirths: number): Color3
	return Config.AREA_COLORS[math.min(rebirths + 1, #Config.AREA_COLORS)]
end

-- Pets ----------------------------------------------------------------------

Config.MAX_EQUIPPED = 3
Config.MAX_PETS = 100
Config.STARTER_CHOICES = { "Dog", "Cat" } -- new players pick one of these

-- Developer test money: when testing in Studio (and for the user ids listed
-- here) your coins and diamonds are topped up to these amounts when you
-- join. Set Enabled = false before releasing the game.
Config.DEV_MONEY = {
	Enabled = true,
	Coins = 1e15, -- 1Qd
	Diamonds = 1e9, -- 1B
	UserIds = {}, -- e.g. { 123456789 } to also get it in the live game
}
Config.PET_SPEED = 32 -- studs per second when running to a coin
Config.PET_HIT_INTERVAL = 0.6 -- seconds between hits; each hit deals the pet's power
Config.CRIT_CHANCE = 0.1 -- 10% of hits are critical hits...
Config.CRIT_MULT = 3 -- ...that deal 3x damage

-- Rarities in order. Chance is a weight (Legendary and Mythical shrink in
-- better eggs, see Config.rarityWeights), Power multiplies the egg's base
-- power and LuckPower is how strongly luck helps (luck ^ LuckPower).
Config.RARITIES = {
	{ Name = "Common", Chance = 60, Power = 1, LuckPower = 0, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Uncommon", Chance = 28, Power = 2, LuckPower = 0, Color = Color3.fromRGB(90, 200, 90) },
	{ Name = "Rare", Chance = 10, Power = 4, LuckPower = 0.5, Color = Color3.fromRGB(80, 140, 255) },
	{ Name = "Legendary", Chance = 2, Power = 10, LuckPower = 0.5, Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythical", Chance = 0.1, Power = 30, LuckPower = 0.35, Color = Color3.fromRGB(255, 70, 120) },
}

-- Eggs: egg N unlocks at rebirth N-1 (unless Required says otherwise). Each
-- egg has one pet per rarity, listed in the same order as RARITIES; the
-- Mythical one is always really hard to get, and harder in better eggs.
-- HugeOdds (1 in N, before luck) gives the egg a Huge pet; only some eggs
-- have one. Tier sets the power and price level (defaults to the egg's
-- number). Theme picks the egg's shrine in the hatchery.
Config.EGGS = {
	{ Name = "Basic Egg", Theme = "Meadow", Color = Color3.fromRGB(245, 240, 225), Pets = { "Dog", "Cat", "Bunny", "Bear", "Angel Puppy" } },
	{ Name = "Forest Egg", Theme = "Forest", Color = Color3.fromRGB(90, 150, 70), Pets = { "Fox", "Deer", "Owl", "Wolf", "Spirit Stag" } },
	{ Name = "Ocean Egg", Theme = "Ocean", Color = Color3.fromRGB(60, 140, 210), Pets = { "Fish", "Crab", "Turtle", "Shark", "Leviathan" }, HugeOdds = 200000 },
	{ Name = "Lava Egg", Theme = "Lava", Color = Color3.fromRGB(220, 80, 30), Pets = { "Salamander", "Magma Golem", "Phoenix", "Dragon", "Inferno Wyrm" } },
	{ Name = "Candy Egg", Theme = "Candy", Color = Color3.fromRGB(255, 150, 200), Pets = { "Gummy Bear", "Candy Cat", "Jelly Bunny", "Unicorn", "Lollipop Dragon" } },
	{ Name = "Snow Egg", Theme = "Snow", Color = Color3.fromRGB(200, 230, 255), Pets = { "Penguin", "Snow Fox", "Polar Bear", "Yeti", "Frost Phoenix" }, HugeOdds = 500000 },
	{ Name = "Jungle Egg", Theme = "Jungle", Color = Color3.fromRGB(60, 170, 80), Pets = { "Monkey", "Parrot", "Tiger", "Lion", "Jaguar King" } },
	{ Name = "Desert Egg", Theme = "Desert", Color = Color3.fromRGB(240, 200, 120), Pets = { "Fennec", "Camel", "Scorpion", "Sphinx Cat", "Pharaoh Cat" } },
	{ Name = "Space Egg", Theme = "Space", Color = Color3.fromRGB(80, 60, 160), Pets = { "Alien", "Robot Dog", "Star Bunny", "Cosmic Whale", "Nebula Dragon" }, HugeOdds = 1000000 },
	{ Name = "Magic Egg", Theme = "Magic", Color = Color3.fromRGB(180, 110, 255), Pets = { "Pixie", "Wizard Cat", "Crystal Bunny", "Griffin", "Arcane Owl" } },
	{ Name = "Mythic Egg", Theme = "Mythic", Color = Color3.fromRGB(255, 215, 80), Pets = { "Kitsune", "Pegasus", "Hydra", "Mythic Dragon", "Divine Dragon" }, HugeOdds = 2500000 },
	-- the limited Release event egg at the end of the hatchery: open for
	-- everyone, party pets and a Huge
	{
		Name = "Release Egg",
		Theme = "Party",
		Color = Color3.fromRGB(255, 200, 60),
		Pets = { "Party Dog", "Confetti Cat", "Balloon Bunny", "Firework Fox", "Launch Dragon" },
		HugeOdds = 300000,
		Required = 0,
		Tier = 3,
		Cost = 50000,
		Release = true,
	},
}
Config.REBIRTH_EGGS = 11 -- the eggs unlocked one per rebirth (the rest are event eggs)

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
	["Gummy Bear"] = Color3.fromRGB(255, 110, 140),
	["Candy Cat"] = Color3.fromRGB(255, 190, 230),
	["Jelly Bunny"] = Color3.fromRGB(170, 230, 255),
	Unicorn = Color3.fromRGB(255, 245, 255),
	Penguin = Color3.fromRGB(70, 80, 110),
	["Snow Fox"] = Color3.fromRGB(240, 245, 255),
	["Polar Bear"] = Color3.fromRGB(250, 250, 250),
	Yeti = Color3.fromRGB(200, 225, 255),
	Monkey = Color3.fromRGB(170, 115, 70),
	Parrot = Color3.fromRGB(80, 210, 100),
	Tiger = Color3.fromRGB(255, 150, 50),
	Lion = Color3.fromRGB(245, 190, 90),
	Fennec = Color3.fromRGB(245, 205, 150),
	Camel = Color3.fromRGB(215, 170, 110),
	Scorpion = Color3.fromRGB(200, 90, 60),
	["Sphinx Cat"] = Color3.fromRGB(240, 210, 130),
	Alien = Color3.fromRGB(140, 240, 120),
	["Robot Dog"] = Color3.fromRGB(180, 190, 210),
	["Star Bunny"] = Color3.fromRGB(255, 235, 120),
	["Cosmic Whale"] = Color3.fromRGB(90, 110, 220),
	Pixie = Color3.fromRGB(255, 180, 240),
	["Wizard Cat"] = Color3.fromRGB(120, 90, 200),
	["Crystal Bunny"] = Color3.fromRGB(190, 240, 255),
	Griffin = Color3.fromRGB(230, 180, 90),
	Kitsune = Color3.fromRGB(255, 120, 80),
	Pegasus = Color3.fromRGB(245, 245, 255),
	Hydra = Color3.fromRGB(70, 170, 150),
	["Mythic Dragon"] = Color3.fromRGB(255, 200, 60),
	-- mythical pets
	["Angel Puppy"] = Color3.fromRGB(255, 250, 240),
	["Spirit Stag"] = Color3.fromRGB(170, 240, 230),
	Leviathan = Color3.fromRGB(40, 90, 170),
	["Inferno Wyrm"] = Color3.fromRGB(200, 40, 30),
	["Lollipop Dragon"] = Color3.fromRGB(255, 120, 200),
	["Frost Phoenix"] = Color3.fromRGB(150, 220, 255),
	["Jaguar King"] = Color3.fromRGB(230, 170, 60),
	["Pharaoh Cat"] = Color3.fromRGB(60, 60, 80),
	["Nebula Dragon"] = Color3.fromRGB(120, 60, 200),
	["Arcane Owl"] = Color3.fromRGB(90, 70, 190),
	["Divine Dragon"] = Color3.fromRGB(255, 245, 210),
	-- release event pets
	["Party Dog"] = Color3.fromRGB(255, 205, 140),
	["Confetti Cat"] = Color3.fromRGB(255, 140, 190),
	["Balloon Bunny"] = Color3.fromRGB(130, 200, 255),
	["Firework Fox"] = Color3.fromRGB(255, 110, 60),
	["Launch Dragon"] = Color3.fromRGB(255, 200, 60),
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
	["Gummy Bear"] = { Ears = "round", Tail = "short" },
	["Candy Cat"] = { Ears = "pointy", Tail = "long" },
	["Jelly Bunny"] = { Ears = "long", Tail = "fluffy" },
	Unicorn = { Ears = "pointy", Tail = "fluffy", Extras = { "horns" } },
	Penguin = { Extras = { "beak", "wings" } },
	["Snow Fox"] = { Ears = "pointy", Tail = "fluffy" },
	["Polar Bear"] = { Ears = "round", Tail = "short" },
	Yeti = { Ears = "round", Extras = { "horns" } },
	Monkey = { Ears = "round", Tail = "long" },
	Parrot = { Tail = "long", Extras = { "beak", "wings" } },
	Tiger = { Ears = "round", Tail = "long" },
	Lion = { Ears = "round", Tail = "fluffy" },
	Fennec = { Ears = "long", Tail = "fluffy" },
	Camel = { Ears = "floppy", Tail = "short" },
	Scorpion = { Tail = "long", Extras = { "claws" } },
	["Sphinx Cat"] = { Ears = "pointy", Tail = "long", Extras = { "wings" } },
	Alien = { Extras = { "antlers" } },
	["Robot Dog"] = { Ears = "floppy", Tail = "short", Extras = { "antlers" } },
	["Star Bunny"] = { Ears = "long", Tail = "fluffy" },
	["Cosmic Whale"] = { Tail = "fin", Extras = { "topfin", "nofeet" } },
	Pixie = { Ears = "pointy", Extras = { "wings" } },
	["Wizard Cat"] = { Ears = "pointy", Tail = "long" },
	["Crystal Bunny"] = { Ears = "long", Tail = "fluffy" },
	Griffin = { Tail = "long", Extras = { "beak", "wings" } },
	Kitsune = { Ears = "pointy", Tail = "fluffy", Extras = { "fire" } },
	Pegasus = { Ears = "pointy", Tail = "fluffy", Extras = { "wings" } },
	Hydra = { Tail = "long", Extras = { "horns", "fire" } },
	["Mythic Dragon"] = { Tail = "long", Extras = { "horns", "wings", "fire" } },
	-- mythical pets (they also get a crown)
	["Angel Puppy"] = { Ears = "floppy", Tail = "short", Extras = { "wings", "halo" } },
	["Spirit Stag"] = { Ears = "pointy", Tail = "short", Extras = { "antlers", "halo" } },
	Leviathan = { Tail = "fin", Extras = { "topfin", "horns", "nofeet" } },
	["Inferno Wyrm"] = { Tail = "long", Extras = { "horns", "wings", "fire" } },
	["Lollipop Dragon"] = { Tail = "long", Extras = { "horns", "wings" } },
	["Frost Phoenix"] = { Tail = "long", Extras = { "beak", "wings" } },
	["Jaguar King"] = { Ears = "round", Tail = "long" },
	["Pharaoh Cat"] = { Ears = "pointy", Tail = "long", Extras = { "wings" } },
	["Nebula Dragon"] = { Tail = "long", Extras = { "horns", "wings" } },
	["Arcane Owl"] = { Ears = "pointy", Extras = { "beak", "wings", "halo" } },
	["Divine Dragon"] = { Tail = "long", Extras = { "horns", "wings", "fire", "halo" } },
	-- release event pets: party hats and bow ties
	["Party Dog"] = { Ears = "floppy", Tail = "short", Extras = { "partyhat" } },
	["Confetti Cat"] = { Ears = "pointy", Tail = "long", Extras = { "partyhat", "bowtie" } },
	["Balloon Bunny"] = { Ears = "long", Tail = "fluffy", Extras = { "partyhat", "balloon" } },
	["Firework Fox"] = { Ears = "pointy", Tail = "fluffy", Extras = { "partyhat", "bowtie", "fire" } },
	["Launch Dragon"] = { Tail = "long", Extras = { "horns", "wings", "partyhat", "bowtie" } },
}

Config.EGG_COUNT = #Config.EGGS

-- An egg's level for power and price (the Release egg borrows one).
function Config.eggTier(eggIndex: number): number
	return Config.EGGS[eggIndex].Tier or eggIndex
end

function Config.eggCost(eggIndex: number): number
	return Config.EGGS[eggIndex].Cost or 1000 * Config.SCALE ^ (Config.eggTier(eggIndex) - 1)
end

function Config.eggRequiredRebirths(eggIndex: number): number
	return Config.EGGS[eggIndex].Required or eggIndex - 1
end

-- Pet power = damage per hit. Stronger pets break coins faster.
function Config.petPower(eggIndex: number, rarityIndex: number): number
	return 40 * Config.SCALE ^ (Config.eggTier(eggIndex) - 1) * Config.RARITIES[rarityIndex].Power
end

-- Rarity weights of an egg before luck: Legendary and Mythical get rarer in
-- better eggs (Mythical goes from 1 in 1,000 in the Basic Egg to about 1 in
-- 6M in the Mythic Egg).
function Config.rarityWeights(eggIndex: number): { number }
	local tier = Config.eggTier(eggIndex)
	local weights = {}
	for i, rarity in ipairs(Config.RARITIES) do
		local w = rarity.Chance
		if rarity.Name == "Legendary" then
			w *= 0.87 ^ (tier - 1)
		elseif rarity.Name == "Mythical" then
			w *= 0.42 ^ (tier - 1)
		end
		weights[i] = w
	end
	return weights
end

-- Huge pets: some eggs have a giant version of their legendary pet with a
-- really low chance (egg.HugeOdds). Luck only helps a little (luck ^ 0.25).
Config.HUGE_LUCK_POWER = 0.25
Config.HUGE_POWER = 6 -- times the legendary's power
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

	-- every egg's legendary has a Huge version (so older saves keep working),
	-- but only eggs with HugeOdds can hatch it
	local base = egg.Pets[4]
	local hugeName = "Huge " .. base
	if egg.HugeOdds then
		egg.Huge = hugeName
	end
	Config.PETS[hugeName] = {
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

-- Chance (in %) of something rare after luck. Luck counts like extra tries
-- (square-rooted), so even x100 luck keeps mutations special.
local function withLuck(chance: number, luck: number): number
	return (1 - (1 - chance / 100) ^ math.sqrt(luck)) * 100
end

-- The chance (in %) of each pet in an egg, including the player's luck
-- (data can be nil for the base odds). Returns a list of { Pet, Chance }
-- with the huge pet last (if the egg has one).
function Config.eggChances(eggIndex: number, data)
	local luck = Config.totalLuck(data)
	local egg = Config.EGGS[eggIndex]
	local hugeChance = if egg.HugeOdds then math.min(100 / egg.HugeOdds * luck ^ Config.HUGE_LUCK_POWER, 1) else 0

	-- luck makes Rare and better pets more likely (less and less for rarer ones)
	local weights, total = Config.rarityWeights(eggIndex), 0
	for i, rarity in ipairs(Config.RARITIES) do
		weights[i] *= luck ^ rarity.LuckPower
		total += weights[i]
	end

	local list = {}
	for i, petName in ipairs(egg.Pets) do
		table.insert(list, { Pet = petName, Chance = weights[i] / total * (100 - hugeChance) })
	end
	if egg.Huge then
		table.insert(list, { Pet = egg.Huge, Chance = hugeChance })
	end
	return list
end

-- A chance (in %) the way kids read it: "1 in 4", "1 in 25K", and for the
-- really tiny ones the percent ("0.00004%").
function Config.chanceLabel(chance: number): string
	if chance <= 0 then
		return "0%"
	end
	local oneIn = 100 / chance
	if oneIn < 100000 then
		return "1 in " .. Config.formatNumber(math.max(1, math.floor(oneIn + 0.5)))
	end
	local digits = math.max(2, -math.floor(math.log10(chance)) + 1)
	return (("%." .. digits .. "f"):format(chance):gsub("0+$", "")) .. "%"
end

-- Mutation chances (in %) with the player's luck applied.
function Config.mutationChances(data)
	local luck = Config.totalLuck(data)
	local list = {}
	for _, mutation in ipairs(Config.MUTATIONS) do
		table.insert(list, { Mutation = mutation, Chance = withLuck(mutation.Chance, luck) })
	end
	return list
end

-- The base odds of hatching this exact pet (mutation included) as N in
-- "1 in N", or nil for pets that don't come from an egg.
function Config.odds(petName: string): number?
	local info = Config.PETS[petName]
	if not info then
		return nil
	end
	local name = info.Base or petName
	local chance = nil
	for _, entry in ipairs(Config.eggChances(info.Egg, nil)) do
		if entry.Pet == name then
			chance = entry.Chance / 100
		end
	end
	if not chance then
		return nil
	end
	if info.Mutation then
		for _, mutation in ipairs(Config.MUTATIONS) do
			if mutation.Name == info.Mutation then
				chance *= mutation.Chance / 100
			end
		end
	end
	return math.floor(1 / chance + 0.5)
end

-- The base odds as text, e.g. "1 in 5K".
function Config.chanceText(petName: string): string
	local odds = Config.odds(petName)
	return if odds then "1 in " .. Config.formatNumber(odds) else ""
end

-- Rolls a pet from the egg, then maybe a mutation.
function Config.rollHatch(eggIndex: number, data): string
	local list = Config.eggChances(eggIndex, data)
	local petName = list[Config.rollWeighted(list)].Pet
	if Config.PETS[petName].Rarity == "Huge" then
		return petName
	end
	-- try the rarest mutation first, then the next one, ...
	local chances = Config.mutationChances(data)
	for i = #chances, 1, -1 do
		if math.random() * 100 < chances[i].Chance then
			return chances[i].Mutation.Name .. " " .. petName
		end
	end
	return petName
end

-- Is this hatch worth announcing to the whole server?
function Config.isRare(petName: string): boolean
	local info = Config.PETS[petName]
	return info ~= nil
		and (
			info.Rarity == "Legendary"
			or info.Rarity == "Mythical"
			or info.Rarity == "Huge"
			or info.Mutation == "Rainbow"
			or info.Mutation == "Galaxy"
		)
end

-- Is this hatch so rare it gets the special hatch animation? (Mythical,
-- Huge, or anything 1 in 10,000 or rarer.)
function Config.isEpic(petName: string): boolean
	local info = Config.PETS[petName]
	if not info then
		return false
	end
	local odds = Config.odds(petName)
	return info.Rarity == "Mythical" or info.Rarity == "Huge" or (odds ~= nil and odds >= 10000)
end

-- Shop upgrades ----------------------------------------------------------------
-- Shop upgrades are kept forever (rebirth only resets coins and the board).
-- Every level has its own fixed price that doesn't change on rebirth. The
-- levels are spread over the rebirths (Span): level L is priced for the
-- rebirth you'd be at when buying it, so the price grows x4 (like everything
-- else per rebirth) every Max/Span levels.
Config.UPGRADES = {
	{ Id = "Damage", Name = "Pet Damage", Icon = "⚔️", Max = 15, BaseCost = 1500, Span = 10, Info = "Pet damage x20 at max" },
	{ Id = "Luck", Name = "Luck", Icon = "🍀", Max = 10, BaseCost = 2500, Span = 10, Info = "Luck x1.6 every level (x100 at max)" },
	{ Id = "WalkSpeed", Name = "Walk Speed", Icon = "👟", Max = 8, BaseCost = 1000, Span = 5, Info = "+2 walk speed" },
	{ Id = "PetSpeed", Name = "Pet Speed", Icon = "💨", Max = 5, BaseCost = 2000, Span = 8, Info = "+15% pet run speed" },
	{ Id = "CoinBonus", Name = "Coin Bonus", Icon = "💰", Max = 15, BaseCost = 3000, Span = 10, Info = "Coins x10 at max" },
	{ Id = "Slots", Name = "Pet Slots", Icon = "🐾", Max = 3, BaseCost = 10000, Span = 9, Info = "+1 pet you can equip" },
}

-- Incremental "area" upgrades (📈 menu, buy anywhere, reset on rebirth).
-- Lots of cheap levels that make the coin zone pay out more and more.
Config.AREA_UPGRADES = {
	{ Id = "CoinValue", Name = "Coin Value", Icon = "💰", Max = 50, BaseCost = 100, Growth = 1.18, Info = "Coin stacks & piles worth +10%" },
	{ Id = "ChestValue", Name = "Chest Value", Icon = "🧰", Max = 50, BaseCost = 250, Growth = 1.2, Info = "Chests worth +15%" },
	{ Id = "MoreBreakables", Name = "More Stuff", Icon = "➕", Max = 18, BaseCost = 50, Growth = 1.4, Info = "+1 thing to break (up to 20)" },
	{ Id = "ChestLuck", Name = "Chest Luck", Icon = "🍀", Max = 20, BaseCost = 350, Growth = 1.3, Info = "More chests (x10 at max)" },
	{ Id = "Respawn", Name = "Fast Respawn", Icon = "⏩", Max = 10, BaseCost = 300, Growth = 1.4, Info = "Things come back 5% faster" },
	{ Id = "DiamondFinder", Name = "Diamond Finder", Icon = "💎", Max = 10, BaseCost = 500, Growth = 1.45, Info = "+5% coin piles carry diamonds" },
	{ Id = "CritChance", Name = "Crit Chance", Icon = "🎯", Max = 20, BaseCost = 450, Growth = 1.3, Info = "+1% critical hits" },
	{ Id = "CritDamage", Name = "Crit Damage", Icon = "💥", Max = 10, BaseCost = 600, Growth = 1.4, Info = "Crits hit harder" },
	{ Id = "HitSpeed", Name = "Hit Speed", Icon = "⚡", Max = 10, BaseCost = 700, Growth = 1.4, Info = "Pets hit 3% faster" },
	{ Id = "BigChestLuck", Name = "Big Chest Luck", Icon = "👑", Max = 15, BaseCost = 800, Growth = 1.35, Info = "More big chests (x10 at max)" },
	{ Id = "OrbLuck", Name = "Orb Luck", Icon = "🧪", Max = 15, BaseCost = 500, Growth = 1.3, Info = "Boost orbs drop more" },
	{ Id = "OrbTime", Name = "Orb Time", Icon = "⏱️", Max = 10, BaseCost = 450, Growth = 1.35, Info = "Orb boosts last longer" },
	{ Id = "ComboTime", Name = "Combo Time", Icon = "🔥", Max = 10, BaseCost = 450, Growth = 1.35, Info = "Combo boosts last longer" },
	{ Id = "EggDiscount", Name = "Egg Discount", Icon = "🏷️", Max = 15, BaseCost = 900, Growth = 1.35, Info = "Eggs cost 2% less" },
	{ Id = "StackGems", Name = "Stack Gems", Icon = "💠", Max = 10, BaseCost = 700, Growth = 1.4, Info = "Coin stacks can carry 💎" },
}

Config.UPGRADES_BY_ID = {}
for _, upgrade in ipairs(Config.UPGRADES) do
	Config.UPGRADES_BY_ID[upgrade.Id] = upgrade
end
for _, upgrade in ipairs(Config.AREA_UPGRADES) do
	Config.UPGRADES_BY_ID[upgrade.Id] = upgrade
end

-- Price of the next level. Shop upgrades (with a Span) have a fixed price
-- per level; board upgrades (reset on rebirth) scale with your rebirths.
function Config.upgradeCost(upgrade, level: number, rebirths: number): number
	if upgrade.Span then
		local stage = upgrade.Span * level / upgrade.Max -- the rebirth this level is meant for
		return Config.roundPrice(upgrade.BaseCost * Config.SCALE ^ stage)
	end
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ level * Config.SCALE ^ rebirths)
end

-- Rounds a price to 2 significant digits (1234 -> 1200) so it looks clean.
function Config.roundPrice(x: number): number
	if x < 100 then
		return math.floor(x)
	end
	local unit = 10 ^ (math.floor(math.log10(x)) - 1)
	return math.floor(x / unit + 0.5) * unit
end

local function level(upgrades, id)
	return if upgrades then upgrades[id] or 0 else 0
end

-- Area upgrade effects (data can be nil).
local function areaLevel(data, id)
	return level(data and data.Upgrades, id)
end
function Config.breakableCount(data): number
	return Config.COINS_PER_PLAYER + areaLevel(data, "MoreBreakables")
end
function Config.respawnTime(data): number
	return Config.COIN_RESPAWN_TIME * (1 - 0.05 * areaLevel(data, "Respawn"))
end
function Config.critChance(data): number
	return Config.CRIT_CHANCE + 0.01 * areaLevel(data, "CritChance")
end
function Config.critMult(data): number
	return Config.CRIT_MULT + 0.2 * areaLevel(data, "CritDamage")
end
function Config.hitInterval(data): number
	return Config.PET_HIT_INTERVAL * (1 - 0.03 * areaLevel(data, "HitSpeed"))
end
function Config.orbChance(data, kind: number): number
	return (Config.ORB_CHANCE[kind] or 0) * (1 + 0.1 * areaLevel(data, "OrbLuck"))
end
function Config.orbSeconds(data): number
	return Config.ORB_SECONDS + 5 * areaLevel(data, "OrbTime")
end
function Config.comboSeconds(data): number
	return Config.COMBO_BOOST_SECONDS + 5 * areaLevel(data, "ComboTime")
end
-- What an egg costs this player (Egg Discount upgrade).
function Config.eggPrice(data, eggIndex: number): number
	return math.floor(Config.eggCost(eggIndex) * (1 - 0.02 * areaLevel(data, "EggDiscount")))
end
-- Value multiplier for a kind of breakable (1-2 coins, 3-4 chests).
function Config.breakableValueMult(data, kind: number): number
	if kind >= 3 then
		return 1 + 0.15 * areaLevel(data, "ChestValue")
	end
	return 1 + 0.1 * areaLevel(data, "CoinValue")
end
-- Spawn weights with Chest Luck applied.
function Config.breakableWeights(data)
	local luck = 10 ^ (areaLevel(data, "ChestLuck") / 20) -- up to x10
	local bigLuck = 10 ^ (areaLevel(data, "BigChestLuck") / 15) -- up to x10
	local list = {}
	for kind, b in ipairs(Config.BREAKABLES) do
		local weight = b.Chance * (if kind >= 3 then luck else 1) * (if kind == #Config.BREAKABLES then bigLuck else 1)
		table.insert(list, { Chance = weight })
	end
	return list
end
function Config.diamondChance(data, kind: number): number
	if kind == 1 then
		return 0.01 * areaLevel(data, "StackGems") -- plain coin stacks
	end
	local b = Config.BREAKABLES[kind]
	return math.min(1, b.DiamondChance + (if kind == 2 then 0.05 * areaLevel(data, "DiamondFinder") else 0))
end
-- How many diamonds a breakable carries when it has some.
function Config.breakableDiamonds(kind: number): number
	return math.max(1, Config.BREAKABLES[kind].Diamonds)
end
-- Coins a broken breakable pays: its base value x area upgrades x bonuses.
function Config.breakablePayout(data, kind: number, baseValue: number): number
	return math.floor(baseValue * Config.breakableValueMult(data, kind) * Config.totalCoins(data))
end

-- Damage and coins multiply every level too: x20 / x10 at max (level 15).
function Config.damageMult(upgrades): number
	return 20 ^ (level(upgrades, "Damage") / 15)
end
-- Luck grows fast: x1.6 per level, x100 at max level.
function Config.luckMult(upgrades): number
	return 100 ^ (level(upgrades, "Luck") / 10)
end
function Config.walkSpeed(upgrades): number
	return 16 + 2 * level(upgrades, "WalkSpeed")
end
function Config.petSpeedMult(upgrades): number
	return 1 + 0.15 * level(upgrades, "PetSpeed")
end
function Config.coinMult(upgrades): number
	return 10 ^ (level(upgrades, "CoinBonus") / 15)
end
function Config.maxEquipped(upgrades): number
	return Config.MAX_EQUIPPED + level(upgrades, "Slots")
end

-- Diamonds ------------------------------------------------------------------
-- Diamonds never reset. Earned from chests, new pets, rebirths and gifts;
-- spent on boost potions and permanent perks.
Config.DIAMONDS_NEW_PET = 25 -- first time you hatch a pet
Config.DIAMONDS_NEW_HUGE = 250 -- first time you hatch a huge
Config.DIAMONDS_PER_REBIRTH = 100 -- times the new rebirth number

-- Potions: 2x for a while. Buying more adds time (up to BOOST_MAX_MINUTES).
-- Their time only counts down while you're playing.
Config.BOOSTS = {
	{ Id = "Coins", Name = "2x Coins", Icon = "💰", Cost = 250, Minutes = 10 },
	{ Id = "Luck", Name = "2x Luck", Icon = "🍀", Cost = 300, Minutes = 10 },
	{ Id = "Damage", Name = "2x Damage", Icon = "⚔️", Cost = 250, Minutes = 10 },
}
Config.BOOST_MAX_MINUTES = 60

-- Boosts from playing -----------------------------------------------------------
-- Combo: keep breaking things (no more than COMBO_TIMEOUT seconds apart);
-- every COMBO_STEP breaks in a row gives a short free 2x boost.
Config.COMBO_STEP = 25
Config.COMBO_TIMEOUT = 4
Config.COMBO_BOOST_SECONDS = 30
Config.COMBO_BOOSTS = { "Coins", "Damage", "Luck" } -- given in this order

-- Boost orbs: sometimes a broken breakable drops a glowing potion orb.
-- Walk close to grab it for a free 2x boost.
Config.ORB_CHANCE = { 0.015, 0.03, 0.08, 0.25 } -- per breakable kind
Config.ORB_SECONDS = 45 -- boost length
Config.ORB_LIFETIME = 25 -- seconds before an orb disappears
Config.ORB_RANGE = 10 -- how close you need to get

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
	return Config.luckMult(data and data.Upgrades) * (1 + 0.1 * perkLevel(data, "Luck")) * boosted(data, "Luck")
end
function Config.totalCoins(data): number
	return Config.coinMult(data and data.Upgrades) * (1 + 0.1 * perkLevel(data, "Coins")) * boosted(data, "Coins")
end
function Config.totalSlots(data): number
	return Config.maxEquipped(data and data.Upgrades) + perkLevel(data, "Slots")
end
function Config.maxPets(data): number
	return Config.MAX_PETS + 25 * perkLevel(data, "Backpack")
end

-- Numbers for kids: 1,234 / 12.5K / 3.4M / 750B / 1.2T ...
local SUFFIXES = { "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc" }

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

-- Multipliers: x1.6 / x25 / x100
function Config.formatMult(x: number): string
	if x < 10 then
		return ("x%.1f"):format(x)
	end
	return "x" .. Config.formatNumber(x)
end

-- Playtime gifts --------------------------------------------------------------
-- Minutes of play (this session) needed for each gift.
Config.GIFT_TIMES = { 1, 3, 5, 10, 15, 20 }

-- Mystery gifts: each gift rolls one prize from its pool; later gifts have
-- better pools and the last one is a MEGA gift. A prize is a list of items:
--   { "Diamonds", amount }       { "Coins", percent of your coins }
--   { "Potion", boost id, minutes }   { "AllPotions", minutes }
--   { "Hatch", count }  (free pets from your best unlocked egg)
Config.GIFT_POOLS = {
	{ { { "Diamonds", 40 } }, { { "Potion", "Coins", 3 } }, { { "Coins", 10 } } },
	{ { { "Diamonds", 75 } }, { { "Potion", "Luck", 5 } }, { { "Coins", 20 } }, { { "Hatch", 1 } } },
	{ { { "Hatch", 1 } }, { { "Potion", "Damage", 5 } }, { { "Diamonds", 120 } }, { { "Coins", 35 } } },
	{ { { "Hatch", 3 } }, { { "Potion", "Coins", 10 } }, { { "Diamonds", 200 } } },
	{ { { "Hatch", 3 } }, { { "AllPotions", 5 } }, { { "Diamonds", 300 } } },
	{ { { "Hatch", 3 }, { "Diamonds", 500 }, { "AllPotions", 10 } } }, -- MEGA
}

-- Coins for a "Coins" gift item: a percent of the coins you already have
-- (at least a few big chests' worth, so new players get something too).
function Config.giftCoins(percent: number, coins: number, rebirths: number): number
	local minimum = Config.coinStats(rebirths, #Config.BREAKABLES).Value * percent / 10
	return math.floor(math.max(coins * percent / 100, minimum))
end

return Config
