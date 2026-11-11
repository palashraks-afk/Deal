-- Drivable cars in the world: spawning, who may sit in them, network ownership,
-- parking, and the garage zones (drive a find or a stolen car into YOUR garage zone to keep it).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local CarBuilder = require(Shared.CarBuilder)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)

local VehicleService = {}
VehicleService.Active = {} :: { [Model]: any }

-- Set by init so we don't get circular requires.
VehicleService.Tycoon = nil

local folder = Instance.new("Folder")
folder.Name = "Vehicles"
folder.Parent = workspace

local function notify(player, text, color)
	if player then
		Net.Notify:FireClient(player, { text = text, color = color })
	end
end
VehicleService.notify = notify

local SCALE = Config.StudsPerMeter / 3 -- speeds were tuned at 3 studs/m

function VehicleService.topSpeed(stats): number
	return math.floor((40 + stats.topKmh * 0.32) * SCALE)
end

function VehicleService.accel(stats): number
	return math.floor((18 + math.sqrt(stats.hp) * 1.6) * SCALE)
end

-- Put a car's wheels on the ground at cf (cf = ground position + facing).
local function placeOnGround(model: Model, cf: CFrame)
	local root = model.PrimaryPart
	local _, size = model:GetBoundingBox()
	local rootOffset = root.Position.Y - (model:GetBoundingBox().Position.Y - size.Y / 2)
	model:PivotTo(cf * CFrame.new(0, rootOffset + 0.3, 0))
end
VehicleService.placeOnGround = placeOnGround

local function getDriver(model: Model): Player?
	local seat = model:FindFirstChild("DriverSeat")
	if seat and seat.Occupant then
		return Players:GetPlayerFromCharacter(seat.Occupant.Parent)
	end
	return nil
end
VehicleService.getDriver = getDriver

function VehicleService.eject(model: Model)
	local seat = model:FindFirstChild("DriverSeat")
	if seat and seat.Occupant then
		local hum = seat.Occupant
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		hum.Sit = false
		hum.Jump = true
	end
end

local function mayDrive(info, player: Player): boolean
	if info.source == "City" then
		return true
	end
	if info.ownerUserId == player.UserId then
		return true
	end
	return info.model:GetAttribute("HotwiredBy") == player.UserId
end

-- Park: once the car has stopped (or after 5s), anchor it so it can't drift.
local function park(info)
	local model = info.model
	local root = model.PrimaryPart
	local t0 = os.clock()
	while model.Parent and not getDriver(model) and os.clock() - t0 < 5 do
		if root.AssemblyLinearVelocity.Magnitude < 1.5 then
			break
		end
		task.wait(0.25)
	end
	if model.Parent and not getDriver(model) then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- stand it upright if it rolled
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.1 and root.CFrame.UpVector.Y < 0.8 then
			placeOnGround(model, CFrame.lookAt(Vector3.new(root.Position.X, 0.2, root.Position.Z), Vector3.new(root.Position.X, 0.2, root.Position.Z) + flat))
		end
		CarBuilder.anchor(model, true)
	end
end

local function register(model: Model, stats, info)
	info.model = model
	info.stats = stats
	info.lastOccupied = os.clock()
	VehicleService.Active[model] = info

	local maxHealth = Config.Rarity[stats.rarity].health
	model:SetAttribute("CarName", stats.name or (stats.brand .. " " .. stats.model))
	model:SetAttribute("Rarity", stats.rarity)
	model:SetAttribute("Value", stats.value)
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("MaxHealth", maxHealth)
	model:SetAttribute("Disabled", false)
	model:SetAttribute("OwnerUserId", info.ownerUserId or 0)
	model:SetAttribute("Source", info.source)
	model:SetAttribute("TopSpeed", VehicleService.topSpeed(stats))
	model:SetAttribute("Accel", VehicleService.accel(stats))

	local seat = model:FindFirstChild("DriverSeat")
	seat.Disabled = false
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if hum then
			local player = Players:GetPlayerFromCharacter(hum.Parent)
			if not player or model:GetAttribute("Disabled") or not mayDrive(info, player) then
				task.defer(VehicleService.eject, model)
				if player and not model:GetAttribute("Disabled") then
					notify(player, "Locked - shoot it with your Disabler, then hotwire it to steal it.", Color3.fromRGB(255, 160, 60))
				end
				return
			end
			info.lastOccupied = os.clock()
			CarBuilder.anchor(model, false)
			model.PrimaryPart:SetNetworkOwner(player)
		else
			info.lastOccupied = os.clock()
			task.spawn(park, info)
		end
	end)

	-- "Drive" prompt so players don't have to jump onto the seat
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = model:GetAttribute("CarName")
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if model:GetAttribute("Disabled") or seat.Occupant then
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not hum.Sit then
			seat:Sit(hum)
		end
	end)

	model.Parent = folder
	return model
end

local function build(stats, paint: Color3, cf: CFrame)
	local model = CarBuilder.build(stats, paint, { drivable = true })
	placeOnGround(model, cf)
	return model
end

-- Player spawns a car from their garage at their plot.
function VehicleService.spawnOwned(player: Player, uid: string)
	local entry = DataService.findCar(player, uid)
	if not entry then
		return false, "Car not found."
	end
	if entry.spawned or entry.inTransit then
		return false, "That car is already out."
	end
	local Tycoon = VehicleService.Tycoon
	if Tycoon.isBusy(player, uid) then
		return false, "Take it off display first."
	end
	local plot = Tycoon.plotOf(player)
	if not plot then
		return false, "No plot yet."
	end
	-- one personal car out at a time
	for model, info in VehicleService.Active do
		if info.source == "Garage" and info.spawnedBy == player then
			VehicleService.despawn(model)
		end
	end
	local stats = Cars.resolve(entry)
	local padCf = plot.spawnPad.CFrame
	local model = build(stats, Cars.paintOf(entry), padCf - Vector3.new(0, plot.spawnPad.Size.Y / 2, 0))
	entry.spawned = true
	register(model, stats, { source = "Garage", ownerUserId = player.UserId, uid = uid, entry = entry, spawnedBy = player })
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		model.DriverSeat:Sit(hum)
	end
	return true
end

function VehicleService.spawnCity(stats, cf: CFrame)
	local model = build(stats, Cars.Paints[stats.paint] or Cars.Paints.Silver, cf)
	return register(model, stats, { source = "City", ownerUserId = 0 })
end

-- A showroom car being stolen: drivable copy owned by the victim, unlocked for the thief.
function VehicleService.spawnRaid(victim: Player, entry, cf: CFrame, thief: Player)
	local stats = Cars.resolve(entry)
	local model = build(stats, Cars.paintOf(entry), cf)
	model:SetAttribute("HotwiredBy", thief.UserId)
	register(model, stats, { source = "Raid", ownerUserId = victim.UserId, uid = entry.uid, entry = entry, victim = victim })
	local hum = thief.Character and thief.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		model.DriverSeat:Sit(hum)
	end
	return model
end

-- Remove a car from the world. Owned cars go back to their owner's garage/showroom.
function VehicleService.despawn(model: Model)
	local info = VehicleService.Active[model]
	VehicleService.Active[model] = nil
	if info then
		if info.entry then
			info.entry.spawned = nil
			if info.source == "Raid" then
				info.entry.inTransit = nil
				local owner = Players:GetPlayerByUserId(info.ownerUserId)
				if owner and VehicleService.Tycoon then
					VehicleService.Tycoon.refreshPlot(owner)
					DataService.push(owner)
				end
			end
		end
	end
	VehicleService.eject(model)
	model:Destroy()
end

-- A driver reached their own garage zone.
local function claim(model: Model, info, driver: Player)
	local profile = DataService.get(driver)
	if not profile then
		return
	end
	if info.lastClaimTry and os.clock() - info.lastClaimTry < 3 then
		return -- don't spam "garage full"
	end
	info.lastClaimTry = os.clock()
	local stats = info.stats
	local name = model:GetAttribute("CarName")

	if info.source == "City" then
		if #profile.garage >= DataService.garageCap(driver) then
			notify(driver, "Garage full! Sell or display a car first.", Color3.fromRGB(255, 90, 90))
			return
		end
		local entry = { uid = DataService.newUid(), id = stats.id }
		table.insert(profile.garage, entry)
		profile.stats.found += 1
		VehicleService.Active[model] = nil
		VehicleService.eject(model)
		model:Destroy()
		notify(driver, ("Found a %s %s! Added to your garage."):format(stats.rarity, name), Config.Rarity[stats.rarity].color)
		DataService.push(driver)
		return
	end

	if info.ownerUserId == driver.UserId then
		-- Your own car back home: store it (or put the rescued showroom car back on display).
		VehicleService.despawn(model)
		DataService.push(driver)
		return
	end

	-- Stolen car delivered.
	if #profile.garage >= DataService.garageCap(driver) then
		notify(driver, "Garage full! Make room to keep stolen cars.", Color3.fromRGB(255, 90, 90))
		return
	end
	local victim = Players:GetPlayerByUserId(info.ownerUserId)
	local victimProfile = victim and DataService.get(victim)
	if not victimProfile or not info.entry then
		return
	end
	local _, index = DataService.findCar(victim, info.uid)
	if index then
		table.remove(victimProfile.garage, index)
	end
	VehicleService.Tycoon.clearSlotFor(victim, info.uid)
	victimProfile.stats.lost += 1
	local newEntry = { uid = DataService.newUid(), id = info.entry.id, custom = info.entry.custom, paint = info.entry.paint }
	table.insert(profile.garage, newEntry)
	profile.stats.stolen += 1
	VehicleService.Active[model] = nil
	VehicleService.eject(model)
	model:Destroy()
	notify(driver, ("You stole %s's %s!"):format(victim.DisplayName, name), Color3.fromRGB(255, 200, 40))
	notify(victim, ("%s stole your %s!"):format(driver.DisplayName, name), Color3.fromRGB(255, 70, 70))
	VehicleService.Tycoon.refreshPlot(victim)
	DataService.push(victim)
	DataService.push(driver)
end

local function insideZone(zone: BasePart, pos: Vector3): boolean
	local lp = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y + 4 and math.abs(lp.Z) <= h.Z
end

function VehicleService.start()
	-- garage zone checks
	task.spawn(function()
		while true do
			task.wait(0.3)
			for model, info in VehicleService.Active do
				local driver = getDriver(model)
				if driver and model.PrimaryPart then
					local plot = VehicleService.Tycoon.plotOf(driver)
					if plot and insideZone(plot.zone, model.PrimaryPart.Position) then
						task.spawn(claim, model, info, driver)
					end
				end
			end
		end
	end)

	-- abandoned cars
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for model, info in VehicleService.Active do
				if not getDriver(model) then
					local limit
					if info.source == "City" then
						limit = Config.City.DespawnAfter
					elseif info.source == "Garage" and model:GetAttribute("HotwiredBy") == nil then
						limit = 600
					else
						limit = Config.Raid.ReturnAfter
					end
					if now - info.lastOccupied > limit then
						VehicleService.despawn(model)
					end
				end
				-- fell out of the world
				if model.Parent and model.PrimaryPart and model.PrimaryPart.Position.Y < -50 then
					VehicleService.despawn(model)
				end
			end
		end
	end)

	table.insert(DataService.BeforeSave, function(player)
		for model, info in VehicleService.Active do
			if info.ownerUserId == player.UserId or info.spawnedBy == player then
				VehicleService.despawn(model)
			end
		end
	end)
end

return VehicleService
