-- Factory: buy blueprints with cash, then each assembly line builds one car at a time.
-- Build time depends on rarity and factory speed upgrades; the car rolls down the belt
-- as it's built and lands in your garage when it's done.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local CarBuilder = require(Shared.CarBuilder)

local DataService = require(script.Parent.DataService)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Tycoon = require(script.Parent.TycoonService)
local VehicleService = require(script.Parent.VehicleService)

local FactoryService = {}
local notify = VehicleService.notify

function FactoryService.blueprintPrice(player: Player, car): number
	local e = DataService.effects(player)
	return math.floor(car.value * Config.BlueprintPriceMult * math.max(0.4, 1 - e.discount))
end

function FactoryService.buildTime(player: Player, car): number
	local e = DataService.effects(player)
	return math.max(10, math.floor(Config.Rarity[car.rarity].buildTime * e.speedMult))
end

local Actions = {}

function Actions.BuyBlueprint(player, args)
	local p = DataService.get(player)
	local e = DataService.effects(player)
	local car = Cars.List[tonumber(args.id) or 0]
	if not car then
		return false, "Unknown car."
	end
	if not e.factory then
		return false, "Build your Factory first (Car Factory upgrade station)."
	end
	local price = FactoryService.blueprintPrice(player, car)
	if p.cash < price then
		return false, ("Blueprint costs %s"):format(Cars.money(price))
	end
	DataService.addCash(player, -price)
	p.blueprints[car.id] = (p.blueprints[car.id] or 0) + 1
	return true, ("Bought %s blueprint!"):format(car.name)
end

function Actions.StartBuild(player, args)
	local p = DataService.get(player)
	local e = DataService.effects(player)
	local id = tonumber(args.id)
	local car = id and Cars.List[id]
	if not car or (p.blueprints[id] or 0) < 1 then
		return false, "You need that blueprint."
	end
	if not e.factory then
		return false, "Build your Factory first."
	end
	for line = 1, e.lines do
		if not p.factory[line] then
			p.blueprints[id] -= 1
			if p.blueprints[id] <= 0 then
				p.blueprints[id] = nil
			end
			p.factory[line] = { id = id, startedAt = os.time(), duration = FactoryService.buildTime(player, car) }
			FactoryService.refresh(player)
			return true, ("Line %d is building a %s!"):format(line, car.name)
		end
	end
	return false, "All assembly lines are busy - buy more lines."
end

FactoryService.Actions = Actions

-- Show the car being built on each line, sliding along the belt with progress.
local lineModels = {} -- [player] = { [line] = model }
function FactoryService.refresh(player: Player)
	local plot = Tycoon.plotOf(player)
	local p = DataService.get(player)
	if not plot or not p then
		return
	end
	lineModels[player] = lineModels[player] or {}
	local now = os.time()
	for line, job in p.factory do
		local car = Cars.List[job.id]
		local m = lineModels[player][line]
		if not m or not m.Parent or m:GetAttribute("CarId") ~= job.id then
			if m then
				m:Destroy()
			end
			m = CarBuilder.build(car, Cars.Paints[car.paint] or Cars.Paints.Silver, { drivable = false })
			m:SetAttribute("CarId", job.id)
			m.Parent = plot.model.Built
			lineModels[player][line] = m
		end
		local t = math.clamp((now - job.startedAt) / job.duration, 0, 1)
		local _, size = m:GetBoundingBox()
		local rootOffset = m.PrimaryPart.Position.Y - (m:GetBoundingBox().Position.Y - size.Y / 2)
		local cf = plot.cframe * PlotBuilder.lineCFrame(line) * CFrame.new(-40 + t * 85, 1 + rootOffset, 0) * CFrame.Angles(0, -math.pi / 2, 0)
		m:PivotTo(cf)
		-- ghosted until finished
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "Chassis" and d.Name ~= "DriverSeat" then
				if d:GetAttribute("BaseT") == nil then
					d:SetAttribute("BaseT", d.Transparency)
				end
				d.Transparency = math.max(d:GetAttribute("BaseT"), 0.75 * (1 - t))
			end
		end
	end
	for line, m in lineModels[player] do
		if not p.factory[line] then
			m:Destroy()
			lineModels[player][line] = nil
		end
	end
end

function FactoryService.start()
	table.insert(DataService.BeforeSave, function(player)
		for _, m in lineModels[player] or {} do
			m:Destroy()
		end
		lineModels[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in game:GetService("Players"):GetPlayers() do
				local p = DataService.get(player)
				if p and next(p.factory) then
					local e = DataService.effects(player)
					local changed = false
					for line, job in p.factory do
						if os.time() >= job.startedAt + job.duration then
							if #p.garage < DataService.garageCap(player) then
								local car = Cars.List[job.id]
								table.insert(p.garage, { uid = DataService.newUid(), id = job.id })
								p.factory[line] = nil
								p.stats.built += 1
								local bonus = math.floor(car.value * e.buildBonus)
								if bonus > 0 then
									DataService.addCash(player, bonus)
								end
								notify(player, ("Factory finished a %s %s!%s"):format(car.rarity, car.name, bonus > 0 and (" +" .. Cars.money(bonus) .. " bonus") or ""), Config.Rarity[car.rarity].color)
								changed = true
							elseif not job.warned then
								job.warned = true
								notify(player, "Factory done but your garage is full!", Color3.fromRGB(255, 90, 90))
							end
						end
					end
					FactoryService.refresh(player)
					if changed then
						DataService.push(player)
					end
				end
			end
		end
	end)
end

return FactoryService
