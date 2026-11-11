-- Every tunable number in DrivinDealz lives here.

local Config = {}

Config.StudsPerMeter = 3 -- real car dimensions are scaled by this

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic", "Legendary" }

Config.Rarity = {
	Common = { color = Color3.fromRGB(176, 182, 190), weight = 55, health = 100 },
	Uncommon = { color = Color3.fromRGB(76, 214, 108), weight = 25, health = 120 },
	Rare = { color = Color3.fromRGB(64, 156, 255), weight = 12, health = 140 },
	Epic = { color = Color3.fromRGB(178, 92, 255), weight = 5.5, health = 170 },
	Mythic = { color = Color3.fromRGB(255, 64, 88), weight = 2, health = 200 },
	Legendary = { color = Color3.fromRGB(255, 196, 40), weight = 0.5, health = 250 },
}

Config.StartingCash = 20000
Config.BaseGarageSize = 15
Config.SellMultiplier = 0.6 -- selling a car back to the game
Config.NpcMarkup = 1.3 -- NPC buyers pay this much for cars marked "For Sale"
Config.NpcBuyTime = { 25, 70 } -- seconds before an NPC buys a for-sale car
Config.CatalogRarities = { Common = 1, Uncommon = 2 } -- rarity -> dealership level needed to buy

-- Dealership progression
Config.Levels = {
	{ name = "Used Lot", slots = 3, cost = 0 },
	{ name = "Corner Dealer", slots = 5, cost = 25000 },
	{ name = "City Showroom", slots = 8, cost = 150000, garageBonus = 10, crafting = true },
	{ name = "Luxury Motors", slots = 12, cost = 750000, npcBonus = 1.25 },
	{ name = "Supercar Gallery", slots = 16, cost = 3000000, lockBonus = 60 },
	{ name = "Hypercar Palace", slots = 20, cost = 15000000, pedestal = true },
}
Config.CraftingLevel = 3

-- City spawns
Config.City = {
	MaxSpawns = 16,
	SpawnInterval = 12, -- seconds between spawn attempts
	BlueprintChance = 0.35, -- otherwise a car
	DespawnAfter = 300, -- unclaimed items vanish after this
	AnnounceFrom = "Mythic", -- server-wide announcement at this rarity and above
}

Config.BlueprintParts = { "Body", "Engine", "Chassis", "Wheels" }

-- Combat
Config.Blaster = {
	Damage = 9,
	FireRate = 0.14,
	Range = 350,
	HotwireTime = 3,
	RepairedHealth = 0.4, -- hotwired cars come back at 40% health
}

-- Raids
Config.Raid = {
	StealHoldTime = 4,
	LockDuration = 60,
	LockCooldown = 90,
	NewPlayerProtection = 300, -- seconds after joining before your base can be raided
	ReturnAfter = 180, -- abandoned stolen cars go home after this
}

-- Driving (studs, seconds)
Config.Drive = {
	SpeedScale = 0.55, -- real km/h -> game stud/s feel
	MinTopSpeed = 70,
	Grip = 0.9,
	SteerRate = 2.2,
}

Config.AutosaveInterval = 120

return Config
