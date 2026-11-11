-- DrivinDealz server entry point.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local WorldBuilder = require(script.WorldBuilder)
local DataService = require(script.DataService)
local VehicleService = require(script.VehicleService)
local TycoonService = require(script.TycoonService)
local NpcService = require(script.NpcService)
local FactoryService = require(script.FactoryService)
local CityService = require(script.CityService)
local CombatService = require(script.CombatService)
local BreakableService = require(script.BreakableService)

WorldBuilder.build()
WorldBuilder.startDayNight()
BreakableService.start()

VehicleService.Tycoon = TycoonService
VehicleService.start()
TycoonService.start()
FactoryService.start()
NpcService.start()
CombatService.start()
CityService.start()
DataService.start() -- last, so every service is listening when players load

-- One remote for every menu action. Each handler returns ok, message.
local handlers = table.clone(TycoonService.Actions)
for name, fn in FactoryService.Actions do
	handlers[name] = fn
end
for name, fn in CombatService.Actions do
	handlers[name] = fn
end

local busy = {}
Net.Action.OnServerInvoke = function(player, action, args)
	if type(action) ~= "string" or not handlers[action] then
		return false, "Unknown action."
	end
	if not DataService.get(player) then
		return false, "Still loading..."
	end
	if busy[player] then
		return false, "Slow down!"
	end
	busy[player] = true
	local ok, result, message = pcall(handlers[action], player, type(args) == "table" and args or {})
	busy[player] = nil
	if not ok then
		warn("[Action]", action, result)
		return false, "Something went wrong."
	end
	DataService.push(player)
	return result, message
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

-- Studio-only test hook (used for playtesting from the command bar / MCP). Never exists live.
if game:GetService("RunService"):IsStudio() then
	local Cars = require(Shared.Cars)
	local Upgrades = require(Shared.Upgrades)
	local hook = Instance.new("BindableFunction")
	hook.Name = "DevCommand"
	hook.OnInvoke = function(cmd, ...)
		local player = game:GetService("Players"):GetPlayers()[1]
		local p = player and DataService.get(player)
		if not p then
			return "no player"
		end
		local args = { ... }
		if cmd == "give" then -- give(rarity, count)
			for _ = 1, args[2] or 1 do
				local list = Cars.ByRarity[args[1]]
				table.insert(p.garage, { uid = DataService.newUid(), id = list[math.random(#list)].id })
			end
		elseif cmd == "giveId" then
			table.insert(p.garage, { uid = DataService.newUid(), id = args[1] })
		elseif cmd == "cash" then
			p.cash = args[1]
		elseif cmd == "upgrades" then -- buy the first n of a track for free
			for i = 1, args[2] do
				local u = Upgrades[args[1]][i]
				if u and not p.upgrades[args[1]][i] then
					p.cash += u.cost
					TycoonService.buyUpgrade(player, args[1], i)
					task.wait(1.25)
				end
			end
		elseif cmd == "action" then
			local ok, msg = handlers[args[1]](player, args[2] or {})
			DataService.push(player)
			return tostring(ok) .. " " .. tostring(msg)
		elseif cmd == "state" then
			local e = DataService.effects(player)
			local shown = 0
			for _ in p.showroom do
				shown += 1
			end
			return ("cash=%d garage=%d showroom=%d slots=%d special=%d base=%d factory=%s lines=%d prize=%d npcs=%d"):format(
				p.cash, #p.garage, shown, e.slots, e.specialLots, e.baseCount, tostring(e.factory), e.lines, e.prizeSlots, #workspace.Customers:GetChildren())
		elseif cmd == "garage" then
			local out = {}
			for i, e in p.garage do
				out[i] = e.uid .. "=" .. Cars.resolve(e).name
			end
			return table.concat(out, ";")
		end
		DataService.push(player)
		return "ok"
	end
	hook.Parent = game:GetService("ServerStorage")
end

print("[DrivinDealz] server ready")
