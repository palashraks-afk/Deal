-- Player save data: load with retries, autosave, save on leave and on shutdown.
-- If DataStores aren't available (Studio without API access) players get a fresh,
-- unsaved profile and a warning instead of an error.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }
DataService.Loaded = Instance.new("BindableEvent")
DataService.BeforeSave = {} :: { (Player) -> () }

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("DrivinDealz_v1")
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, progress will not save:", result)
	end
end

local function blueprintTable()
	local t = {}
	for _, part in Config.BlueprintParts do
		t[part] = {}
		for _, r in Config.RarityOrder do
			t[part][r] = 0
		end
	end
	return t
end

local function defaultProfile()
	return {
		cash = Config.StartingCash,
		level = 1,
		garage = {}, -- array of {uid, id | custom, paint?}
		showroom = {}, -- [slotIndex] = { uid = string, forSale = bool, saleAt = number? }
		blueprints = blueprintTable(),
		stats = { found = 0, stolen = 0, lost = 0, sold = 0, crafted = 0 },
	}
end

-- Fill in any fields added after a player's data was first saved.
local function reconcile(data)
	local def = defaultProfile()
	for k, v in def do
		if data[k] == nil then
			data[k] = v
		end
	end
	for _, part in Config.BlueprintParts do
		data.blueprints[part] = data.blueprints[part] or {}
		for _, r in Config.RarityOrder do
			data.blueprints[part][r] = data.blueprints[part][r] or 0
		end
	end
	for k, v in def.stats do
		data.stats[k] = data.stats[k] or v
	end
	-- showroom keys come back from JSON as strings
	local fixed = {}
	for k, v in data.showroom do
		fixed[tonumber(k)] = v
	end
	data.showroom = fixed
	return data
end

function DataService.newUid(): string
	return HttpService:GenerateGUID(false)
end

function DataService.get(player: Player)
	return DataService.Profiles[player]
end

-- Send the client a copy of their data. Called after every change.
function DataService.push(player: Player)
	local p = DataService.Profiles[player]
	if p then
		local showroom = {}
		for slot, v in p.showroom do
			showroom[tostring(slot)] = v
		end
		Net.Data:FireClient(player, {
			cash = p.cash,
			level = p.level,
			garage = p.garage,
			showroom = showroom,
			blueprints = p.blueprints,
			stats = p.stats,
		})
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			ls.Cash.Value = p.cash
			ls.Level.Value = p.level
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
	local p = DataService.Profiles[player]
	local cap = Config.BaseGarageSize
	for lvl = 1, p.level do
		cap += Config.Levels[lvl].garageBonus or 0
	end
	return cap + p.level * 5
end

local function save(player: Player)
	local p = DataService.Profiles[player]
	if not p or not store or p._noSave then
		return
	end
	local copy = table.clone(p)
	copy._noSave = nil
	local showroom = {}
	for slot, v in p.showroom do
		showroom[tostring(slot)] = v
	end
	copy.showroom = showroom
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
			failed = true
			warn("[DataService] load failed (try " .. attempt .. "):", result)
			task.wait(1.5)
		end
	end
	local profile = reconcile(data or defaultProfile())
	if failed then
		-- Never overwrite real data with a blank profile.
		profile._noSave = true
		Net.Notify:FireClient(player, { text = "Couldn't load your save - progress this session won't be saved.", color = Color3.fromRGB(255, 90, 90) })
	end
	-- Cars stuck "in transit" from a crash come home.
	for _, entry in profile.garage do
		entry.inTransit = nil
		entry.spawned = nil
	end

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = ls
	ls.Parent = player

	DataService.Profiles[player] = profile
	DataService.push(player)
	DataService.Loaded:Fire(player, profile)
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	for _, p in Players:GetPlayers() do
		task.spawn(load, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Let other services tidy up (despawn cars, return stolen ones) before saving.
		for _, fn in DataService.BeforeSave do
			pcall(fn, player)
		end
		save(player)
		DataService.Profiles[player] = nil
	end)
	game:BindToClose(function()
		local threads = {}
		for _, player in Players:GetPlayers() do
			table.insert(threads, task.spawn(save, player))
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
