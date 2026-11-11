-- Every tunable number in DrivinDealz lives here (upgrades are in Upgrades.luau, guns in Guns.luau).

local Config = {}

-- Real car dimensions are scaled by this. 4 studs/m makes cars big enough for a Roblox
-- character (~5 studs tall) to sit inside instead of poking through the roof.
Config.StudsPerMeter = 4

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic", "Legendary" }

Config.Rarity = {
	Common = { color = Color3.fromRGB(176, 182, 190), weight = 55, health = 100, buildTime = 45 },
	Uncommon = { color = Color3.fromRGB(76, 214, 108), weight = 25, health = 120, buildTime = 90 },
	Rare = { color = Color3.fromRGB(64, 156, 255), weight = 12, health = 150, buildTime = 180 },
	Epic = { color = Color3.fromRGB(178, 92, 255), weight = 5.5, health = 190, buildTime = 360 },
	Mythic = { color = Color3.fromRGB(255, 64, 88), weight = 2, health = 240, buildTime = 720 },
	Legendary = { color = Color3.fromRGB(255, 196, 40), weight = 0.5, health = 300, buildTime = 1500 },
}

Config.StartingCash = 25000
Config.BaseGarageSize = 20
Config.SellMultiplier = 0.6 -- instant-sell a car back to the game
Config.DefaultPriceMult = 1.2 -- new showroom cars are listed at 120% of value
Config.PriceMultRange = { 0.5, 3 } -- owners can list between 50% and 300% of value
Config.CatalogRarities = { Common = 0, Uncommon = 10 } -- rarity -> base upgrades needed to buy it new

-- Blueprints (bought with cash, built in the Factory)
Config.BlueprintPriceMult = 0.4 -- blueprint costs 40% of the car's value (minus factory discounts)

-- NPC customers
Config.Npc = {
	SpawnEvery = 9, -- seconds per plot at 1x foot traffic
	MaxPerPlot = 6,
	MaxPerPlotCap = 14,
	MaxTotal = 60,
	Browse = { 4, 9 }, -- seconds looking at a car
	CarsPerVisit = 3,
	BaseTolerance = 1.15, -- happy paying up to ~115% of value
	SpecialLotBonus = 0.4, -- special lots pull buyers who pay more
	Pedestrians = 70, -- people walking around the map
}

-- City spawns
Config.City = {
	MaxSpawns = 14,
	SpawnInterval = 12,
	DespawnAfter = 300,
	AnnounceFrom = "Mythic",
}

-- Combat
Config.Combat = {
	HotwireTime = 3,
	RepairedHealth = 0.4,
	PlayerRespawn = 4,
}

-- Raids
Config.Raid = {
	StealHoldTime = 4,
	LockDuration = 60,
	LockCooldown = 90,
	NewPlayerProtection = 300,
	ReturnAfter = 180,
}

-- Driving
Config.Drive = {
	Grip = 0.92,
	DriftGrip = 0.18,
	SteerRate = 2.3,
}

Config.AutosaveInterval = 120

return Config
