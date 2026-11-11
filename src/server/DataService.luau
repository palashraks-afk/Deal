-- Player save data: load with retries, autosave, save on leave and on shutdown.
-- If DataStores aren't available (unpublished place in Studio) players get a fresh,
-- unsaved profile and a warning instead of an error.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Upgrades = require(Shared.Upgrades)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }
DataService.Loaded = Instance.new("BindableEvent")
DataService.BeforeSave = {} :: { (Player) -> () }

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("DrivinDealz_v2")
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, progress will not save:", result)
	end
end

local function defaultProfile()
	return {
		cash = Config.StartingCash,
		garage = {}, -- array of {uid, id, paint?}
		showroom = {}, -- [slot] = { uid }
		prices = {}, -- [uid] = price multiplier (x value)
		prize = {}, -- [slot] = uid   (prize room: NPCs can't buy these)
		upgrades = { Base = {}, Factory = {}, Prize = {} }, -- [index] = true
		blueprints = {}, -- [carId] = count
		factory = {}, -- [line] = { id, startedAt, duration }
		guns = { Pistol = true },
		equippedGun = "Pistol",
		tutorial = 1, -- tutorial step (0 = finished/skipped)
		stats = { found = 0, stolen = 0, lost = 0, sold = 0, built = 0, earned = 0 },
	}
end

-- JSON turns number keys into strings; these maps use number keys in game.
local NUMBER_KEYED = { "showroom", "prize", "blueprints", "factory" }
local function numKeys(t)
	local out = {}
	for k, v in t or {} do
		out[tonumber(k) or k] = v
	end
	return out
end
local function strKeys(t)
	local out = {}
	for k, v in t or {} do
		out[tostring(k)] = v
	end
	return out
end

local function reconcile(data)
	local def = defaultProfile()
	for k, v in def do
		if data[k] == nil then
			data[k] = v
		end
	end
	for k, v in def.stats do
		data.stats[k] = data.stats[k] or v
	end
	for _, key in NUMBER_KEYED do
		data[key] = numKeys(data[key])
	end
	for _, track in Upgrades.Tracks do
		data.upgrades[track] = numKeys(data.upgrades[track])
	end
	data.guns.Pistol = true
	return data
end

-- A copy safe to send to the client / save (string keys for sparse maps).
local function serialise(p)
	local copy = table.clone(p)
	copy._noSave = nil
	copy._effects = nil
	for _, key in NUMBER_KEYED do
		copy[key] = strKeys(p[key])
	end
	copy.upgrades = {}
	for _, track in Upgrades.Tracks do
		copy.upgrades[track] = strKeys(p.upgrades[track])
	end
	return copy
end

function DataService.newUid(): string
	return HttpService:GenerateGUID(false)
end

function DataService.get(player: Player)
	return DataService.Profiles[player]
end

-- Upgrade effects, cached until the next purchase.
function DataService.effects(player: Player)
	local p = DataService.Profiles[player]
	if not p then
		return nil
	end
	if not p._effects then
		p._effects = Upgrades.effects(p.upgrades)
	end
	return p._effects
end

function DataService.invalidate(player: Player)
	local p = DataService.Profiles[player]
	if p then
		p._effects = nil
	end
end

function DataService.push(player: Player)
	local p = DataService.Profiles[player]
	if p then
		local data = serialise(p)
		data.serverTime = os.time()
		Net.Data:FireClient(player, data)
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			ls.Cash.Value = p.cash
			ls.Upgrades.Value = DataService.effects(player).baseCount
		end
	end
end

function DataService.addCash(player: Player, amount: number)
	local p = DataService.Profiles[player]
	if p then
		p.cash += amount
		if amount > 0 then
			p.stats.earned += amount
		end
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			ls.Cash.Value = p.cash
		end
	end
end

function DataService.findCar(player: Player, uid: string)
	local p = DataService.Profiles[player]
	if not p then
		return nil
	end
	for i, entry in p.garage do
		if entry.uid == uid then
			return entry, i
		end
	end
	return nil
end

function DataService.garageCap(player: Player): number
	local e = DataService.effects(player)
	return Config.BaseGarageSize + (e and e.garage or 0)
end

local function save(player: Player)
	local p = DataService.Profiles[player]
	if not p or not store or p._noSave then
		return
	end
	local copy = serialise(p)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync("u_" .. player.UserId, copy)
		end)
		if ok then
			return
		end
		warn("[DataService] save failed (try " .. attempt .. "):", err)
		task.wait(2)
	end
end
DataService.save = save

local function load(player: Player)
	local data
	local failed = false
	local studioOnly = false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync("u_" .. player.UserId)
			end)
			if ok then
				data = result
				failed = false
				break
			end
			if string.find(tostring(result), "Studio access", 1, true) then
				-- Studio without API access: play as a fresh, unsaved player (not an error)
				studioOnly = true
				break
			end
			failed = true
			warn("[DataService] load failed (try " .. attempt .. "):", result)
			task.wait(1.5)
		end
	end
	local isNew = data == nil and not failed
	local profile = reconcile(data or defaultProfile())
	if isNew then
		-- two starter cars so a new player can stock their lot straight away
		for _, id in { 1, 4 } do
			table.insert(profile.garage, { uid = DataService.newUid(), id = id })
		end
	end
	if studioOnly then
		profile._noSave = true
	elseif failed then
		profile._noSave = true
		Net.Notify:FireClient(player, { text = "Couldn't load your save - progress this session won't be saved.", color = Color3.fromRGB(255, 90, 90) })
	end
	for _, entry in profile.garage do
		entry.inTransit = nil
		entry.spawned = nil
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local ups = Instance.new("IntValue")
	ups.Name = "Upgrades"
	ups.Parent = ls
	ls.Parent = player

	DataService.Profiles[player] = profile
	DataService.push(player)
	DataService.Loaded:Fire(player, profile)
end

function DataService.start()
	Net.Tutorial.OnServerEvent:Connect(function(player, step)
		local p = DataService.Profiles[player]
		if p and type(step) == "number" and step >= 0 and step <= 20 then
			p.tutorial = math.floor(step)
		end
	end)
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, fn in DataService.BeforeSave do
			pcall(fn, player)
		end
		save(player)
		DataService.Profiles[player] = nil
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(save, player)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
end

return DataService
