-- Helpers around the car list: lookups, rarity lists, paint colours, formatting.
local Config = require(script.Parent.Config)
local CarData = require(script.Parent.CarData)

local Cars = {}

Cars.List = CarData
Cars.ByRarity = {}
for _, r in Config.RarityOrder do
	Cars.ByRarity[r] = {}
end
for _, car in CarData do
	table.insert(Cars.ByRarity[car.rarity], car)
end

Cars.Paints = {
	["Crimson"] = Color3.fromRGB(178, 20, 30),
	["Midnight Blue"] = Color3.fromRGB(18, 30, 78),
	["Pearl White"] = Color3.fromRGB(236, 236, 230),
	["Gunmetal"] = Color3.fromRGB(62, 66, 72),
	["Racing Green"] = Color3.fromRGB(16, 74, 42),
	["Sunset Orange"] = Color3.fromRGB(240, 110, 20),
	["Lime"] = Color3.fromRGB(150, 220, 30),
	["Jet Black"] = Color3.fromRGB(14, 14, 16),
	["Silver"] = Color3.fromRGB(180, 184, 190),
	["Canary Yellow"] = Color3.fromRGB(250, 205, 20),
	["Royal Purple"] = Color3.fromRGB(88, 36, 150),
	["Sky Blue"] = Color3.fromRGB(80, 160, 230),
	["Burgundy"] = Color3.fromRGB(100, 18, 34),
	["Bronze"] = Color3.fromRGB(150, 100, 50),
	["Matte Grey"] = Color3.fromRGB(110, 112, 114),
	["Hot Pink"] = Color3.fromRGB(240, 60, 150),
	["Teal"] = Color3.fromRGB(20, 140, 140),
}
Cars.PaintNames = {}
for name in Cars.Paints do
	table.insert(Cars.PaintNames, name)
end
table.sort(Cars.PaintNames)

function Cars.rarityIndex(r: string): number
	return table.find(Config.RarityOrder, r) or 1
end

-- An owned car entry is {uid, id} for list cars or {uid, custom = {...}} for crafted cars.
-- resolve() returns the stats table either way.
function Cars.resolve(entry)
	if entry.custom then
		return entry.custom
	end
	return CarData[entry.id]
end

function Cars.paintOf(entry)
	local stats = Cars.resolve(entry)
	return Cars.Paints[entry.paint or stats.paint] or Cars.Paints.Silver
end

function Cars.money(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("$%.2fM", n / 1e6)
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

-- Weighted rarity roll using Config.Rarity weights.
function Cars.rollRarity(rng: Random): string
	local total = 0
	for _, r in Config.RarityOrder do
		total += Config.Rarity[r].weight
	end
	local pick = rng:NextNumber() * total
	for _, r in Config.RarityOrder do
		pick -= Config.Rarity[r].weight
		if pick <= 0 then
			return r
		end
	end
	return "Common"
end

-- Stats for a crafted car, from the rarity of each blueprint piece.
local CRAFT_BASE = {
	hatch = { 4.2, 1.78, 1.45 },
	sedan = { 4.8, 1.85, 1.44 },
	coupe = { 4.6, 1.9, 1.33 },
	sports = { 4.4, 1.88, 1.27 },
	muscle = { 4.9, 1.92, 1.38 },
	suv = { 4.9, 1.98, 1.74 },
	truck = { 5.7, 2.05, 1.95 },
	offroad = { 4.8, 2.0, 1.9 },
	super = { 4.6, 1.98, 1.2 },
	hyper = { 4.7, 2.04, 1.14 },
}
Cars.CraftBodies = {
	-- body type -> minimum Body-piece rarity
	hatch = "Common",
	sedan = "Common",
	suv = "Common",
	coupe = "Uncommon",
	truck = "Uncommon",
	offroad = "Uncommon",
	muscle = "Rare",
	sports = "Rare",
	super = "Epic",
	hyper = "Legendary",
}

function Cars.craftStats(name: string, body: string, paint: string, parts: { [string]: string })
	local idx = {}
	local sum = 0
	for _, p in Config.BlueprintParts do
		idx[p] = Cars.rarityIndex(parts[p])
		sum += idx[p]
	end
	local avg = sum / #Config.BlueprintParts
	local rarity = Config.RarityOrder[math.clamp(math.floor(avg + 0.5), 1, 6)]
	local dims = CRAFT_BASE[body] or CRAFT_BASE.sedan
	local hp = math.floor(120 * 1.65 ^ (idx.Engine - 1) + 30 * idx.Chassis)
	local value = math.floor(20000 * 3.1 ^ (avg - 1))
	return {
		name = name,
		brand = "Custom",
		model = name,
		rarity = rarity,
		body = body,
		length = dims[1],
		width = dims[2],
		height = dims[3],
		hp = hp,
		topKmh = math.floor(60 + 11 * math.sqrt(hp) + 4 * idx.Wheels),
		value = value,
		income = math.max(1, math.floor(0.02 * value ^ 0.75 * 1.15)), -- crafted cars earn a bit more
		paint = paint,
		crafted = true,
	}
end

return Cars
