-- Crafting: spend one Body, Engine, Chassis and Wheels blueprint to build your own car.
-- The rarity of each piece sets the stats; the Body piece decides which body styles you can pick.
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)

local DataService = require(script.Parent.DataService)

local BlueprintService = {}

local function filterName(player: Player, text: string): string?
	text = string.sub(string.gsub(text or "", "[%c]", ""), 1, 20)
	if #text < 2 then
		return nil
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		return result
	end
	return nil
end

function BlueprintService.craft(player: Player, args)
	local p = DataService.get(player)
	if p.level < Config.CraftingLevel then
		return false, ("Crafting unlocks at dealership level %d."):format(Config.CraftingLevel)
	end
	if type(args) ~= "table" or type(args.parts) ~= "table" then
		return false, "Pick all four blueprint pieces."
	end
	for _, part in Config.BlueprintParts do
		local r = args.parts[part]
		if type(r) ~= "string" or not Config.Rarity[r] then
			return false, "Pick a " .. part .. " blueprint."
		end
		if (p.blueprints[part][r] or 0) < 1 then
			return false, ("You don't have a %s %s blueprint."):format(r, part)
		end
	end
	local minBody = Cars.CraftBodies[args.body]
	if not minBody then
		return false, "Pick a body style."
	end
	if Cars.rarityIndex(args.parts.Body) < Cars.rarityIndex(minBody) then
		return false, ("A %s body needs a %s or better Body blueprint."):format(args.body, minBody)
	end
	if not Cars.Paints[args.paint] then
		return false, "Pick a paint."
	end
	if #p.garage >= DataService.garageCap(player) then
		return false, "Garage full."
	end
	local name = filterName(player, args.name)
	if not name then
		return false, "Give your car a name (2-20 letters)."
	end

	for _, part in Config.BlueprintParts do
		p.blueprints[part][args.parts[part]] -= 1
	end
	local stats = Cars.craftStats(name, args.body, args.paint, args.parts)
	table.insert(p.garage, { uid = DataService.newUid(), custom = stats, paint = args.paint })
	p.stats.crafted += 1
	return true, ("Built %s (%s)!"):format(name, stats.rarity)
end

return BlueprintService
