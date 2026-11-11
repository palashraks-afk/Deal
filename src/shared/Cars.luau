-- Helpers around the car list: lookups, rarity lists, paint colours, money formatting.
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

function Cars.rarityIndex(r: string): number
	return table.find(Config.RarityOrder, r) or 1
end

-- An owned car entry is {uid, id}. resolve() returns the car's stats.
function Cars.resolve(entry)
	return CarData[entry.id]
end

function Cars.paintOf(entry)
	local stats = Cars.resolve(entry)
	return Cars.Paints[entry.paint or stats.paint] or Cars.Paints.Silver
end

function Cars.money(n: number): string
	local neg = n < 0
	n = math.floor(math.abs(n))
	local s
	if n >= 1e12 then
		s = string.format("$%.2fT", n / 1e12)
	elseif n >= 1e9 then
		s = string.format("$%.2fB", n / 1e9)
	elseif n >= 1e6 then
		s = string.format("$%.2fM", n / 1e6)
	else
		local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if out:sub(1, 1) == "," then
			out = out:sub(2)
		end
		s = "$" .. out
	end
	return neg and ("-" .. s) or s
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

return Cars
