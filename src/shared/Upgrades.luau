-- Every tycoon upgrade: 110 Base, 100 Factory, 10 Prize Room.
-- Each upgrade: { track, index, name, cost, kind, amount }. Buttons on your plot show the
-- next few in each track; buying builds something on the lot and applies the effect.

local Upgrades = {}

local function niceRound(n: number): number
	local mag = 10 ^ math.max(0, math.floor(math.log10(n)) - 1)
	return math.floor(n / mag + 0.5) * mag
end

---------------------------------------------------------------- Base (110)
-- kind -> {count, amount, names}
local BASE_KINDS = {
	slot = { 17, 1, { "Display Pad" } },
	income = { 15, 0.06, { "Polished Floors", "LED Ceiling", "Glass Walls", "Car Turntables", "Spot Lights", "Marble Tiles", "Chrome Trim", "Sound System", "Big Screens", "Coffee Bar", "Showroom Mirrors", "Laser Show", "Gold Railings", "Smoke Machine", "Hologram Signs" } },
	traffic = { 15, 0.12, { "Street Banner", "Balloon Arch", "Billboard", "Flag Row", "Searchlights", "Radio Ad", "Inflatable Dancer", "Neon Arrow", "Bus Stop", "Sidewalk Ads", "Giant Sign", "TV Commercial", "Blimp Ad", "Grand Opening", "City Mural" } },
	rich = { 10, 0.06, { "Red Carpet", "Velvet Ropes", "VIP Lounge", "Valet Stand", "Champagne Bar", "Chandelier", "Art Gallery", "Private Booth", "Fountain Court", "Helipad" } },
	special = { 6, 1, { "Special Lot" } },
	garage = { 10, 3, { "Garage Bay" } },
	security = { 8, 10, { "Cameras", "Bollards", "Alarm", "Guard Booth", "Spike Strip", "Laser Fence", "Steel Gate", "Watch Tower" } },
	decor = { 29, 0.01, { "Palm Trees", "Planters", "Benches", "Lamp Posts", "Hedges", "Flower Beds", "Rock Garden", "Water Feature", "Statue", "Bike Rack", "Trash Cans", "Picnic Table", "Shade Canopy", "Flag Pole", "Mailbox", "Parking Lines", "Tire Stack", "Oil Drums", "Toolbox", "Car Lift", "Neon Logo", "Rooftop Sign", "Awning", "Wall Art", "Clock Tower", "Fence Lights", "Gravel Path", "Kiosk", "Vending Machine" } },
}
-- the order they come up in (interleaved so every few buys does something different)
local BASE_PATTERN = { "slot", "decor", "income", "traffic", "decor", "rich", "garage", "slot", "decor", "income", "traffic", "security", "decor", "special" }

local function buildTrack(track: string, kinds, pattern, total: number, startCost: number, growth: number)
	local list = {}
	local used = {}
	for k in kinds do
		used[k] = 0
	end
	local p = 0
	while #list < total do
		p = p % #pattern + 1
		local kind = pattern[p]
		local def = kinds[kind]
		if used[kind] < def[1] then
			used[kind] += 1
			local n = used[kind]
			local names = def[3]
			local name = #names == 1 and (names[1] .. " " .. n) or names[(n - 1) % #names + 1]
			local index = #list + 1
			table.insert(list, {
				track = track,
				index = index,
				kind = kind,
				amount = def[2],
				nth = n,
				name = name,
				cost = niceRound(startCost * growth ^ (index - 1)),
			})
		end
		-- stop if every kind is used up
		local left = 0
		for k, d in kinds do
			left += d[1] - used[k]
		end
		if left == 0 then
			break
		end
	end
	assert(#list == total, track .. " track has " .. #list)
	return list
end

Upgrades.Base = buildTrack("Base", BASE_KINDS, BASE_PATTERN, 110, 400, 1.115)

---------------------------------------------------------------- Factory (100)
local FACTORY_KINDS = {
	unlock = { 1, 1, { "Build Factory" } },
	speed = { 40, 0.025, { "Faster Conveyor", "Torque Wrenches", "Paint Booth", "Welding Robot", "Engine Hoist", "Parts Shelves", "Air Tools", "Laser Cutter", "Assembly Jig", "Night Shift" } },
	line = { 4, 1, { "Assembly Line" } },
	bonus = { 20, 0.03, { "Quality Check", "Detailing Bay", "Polish Station", "Test Track", "Wax Machine" } },
	discount = { 20, 0.01, { "Bulk Deal", "Supplier Contract", "Blueprint Scanner", "Draft Table", "Engineer Hire" } },
	robot = { 15, 0.01, { "Robot Arm", "Forklift", "Crane", "Drone", "Smart Screens" } },
}
local FACTORY_PATTERN = { "unlock", "speed", "robot", "bonus", "speed", "discount", "line", "speed", "bonus", "discount", "speed", "robot" }
Upgrades.Factory = buildTrack("Factory", FACTORY_KINDS, FACTORY_PATTERN, 100, 25000, 1.11)

---------------------------------------------------------------- Prize Room (10)
Upgrades.Prize = {
	{ track = "Prize", index = 1, kind = "unlock", name = "Build Prize Vault", cost = 100000, pedestals = 2, mult = 1.5 },
	{ track = "Prize", index = 2, kind = "pedestal", name = "Pedestal 3", cost = 250000, pedestals = 3, mult = 1.5 },
	{ track = "Prize", index = 3, kind = "pedestal", name = "Pedestal 4", cost = 600000, pedestals = 4, mult = 1.5 },
	{ track = "Prize", index = 4, kind = "glow", name = "Spotlights", cost = 1200000, pedestals = 4, mult = 1.75 },
	{ track = "Prize", index = 5, kind = "pedestal", name = "Pedestal 5 & 6", cost = 2500000, pedestals = 6, mult = 1.75 },
	{ track = "Prize", index = 6, kind = "laser", name = "Laser Grid", cost = 5000000, pedestals = 6, mult = 1.75, protected = true },
	{ track = "Prize", index = 7, kind = "pedestal", name = "Pedestal 7 & 8", cost = 10000000, pedestals = 8, mult = 2 },
	{ track = "Prize", index = 8, kind = "glow", name = "Velvet & Gold", cost = 20000000, pedestals = 8, mult = 2.5 },
	{ track = "Prize", index = 9, kind = "pedestal", name = "Pedestal 9 & 10", cost = 40000000, pedestals = 10, mult = 2.5 },
	{ track = "Prize", index = 10, kind = "glow", name = "Diamond Vault", cost = 80000000, pedestals = 10, mult = 3.5 },
}

Upgrades.Tracks = { "Base", "Factory", "Prize" }

-- How many of the next upgrades in a track you may buy at once (tycoon "button window").
Upgrades.Window = 3

---------------------------------------------------------------- effects
-- Turn a player's bought set into numbers the game uses.
function Upgrades.effects(bought)
	local e = {
		slots = 3,
		incomeMult = 1,
		traffic = 1,
		richness = 0,
		specialLots = 0,
		garage = 0,
		lockBonus = 0,
		factory = false,
		speedMult = 1,
		lines = 1,
		buildBonus = 0,
		discount = 0,
		prizeSlots = 0,
		prizeMult = 1,
		prizeProtected = false,
		baseCount = 0,
	}
	for _, u in Upgrades.Base do
		if bought.Base[u.index] then
			e.baseCount += 1
			if u.kind == "slot" then
				e.slots += 1
			elseif u.kind == "income" or u.kind == "decor" then
				e.incomeMult += u.amount
			elseif u.kind == "traffic" then
				e.traffic += u.amount
			elseif u.kind == "rich" then
				e.richness += u.amount
			elseif u.kind == "special" then
				e.specialLots += 1
			elseif u.kind == "garage" then
				e.garage += u.amount
			elseif u.kind == "security" then
				e.lockBonus += u.amount
			end
		end
	end
	for _, u in Upgrades.Factory do
		if bought.Factory[u.index] then
			if u.kind == "unlock" then
				e.factory = true
			elseif u.kind == "speed" or u.kind == "robot" then
				e.speedMult *= 1 - u.amount
			elseif u.kind == "line" then
				e.lines += 1
			elseif u.kind == "bonus" then
				e.buildBonus += u.amount
			elseif u.kind == "discount" then
				e.discount += u.amount
			end
		end
	end
	for _, u in Upgrades.Prize do
		if bought.Prize[u.index] then
			e.prizeSlots = math.max(e.prizeSlots, u.pedestals)
			e.prizeMult = math.max(e.prizeMult, u.mult)
			if u.protected then
				e.prizeProtected = true
			end
		end
	end
	return e
end

-- The next buyable upgrades in a track (up to Window of them).
function Upgrades.available(track: string, bought): { any }
	local out = {}
	local list = Upgrades[track]
	for _, u in list do
		if not bought[track][u.index] then
			table.insert(out, u)
			if #out >= Upgrades.Window then
				break
			end
		end
	end
	-- Factory and Prize only open up once their first upgrade (the building) is bought
	if (track == "Factory" or track == "Prize") and not bought[track][1] then
		return { list[1] }
	end
	return out
end

-- Dealership rank title from how built-up the base is.
local RANKS = { "Used Lot", "Corner Dealer", "City Showroom", "Luxury Motors", "Supercar Gallery", "Hypercar Palace" }
function Upgrades.rank(baseCount: number): (number, string)
	local r = math.clamp(math.floor(baseCount / 22) + 1, 1, #RANKS)
	return r, RANKS[r]
end

return Upgrades
