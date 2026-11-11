-- DrivinDealz server entry point.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local WorldBuilder = require(script.WorldBuilder)
local DataService = require(script.DataService)
local VehicleService = require(script.VehicleService)
local TycoonService = require(script.TycoonService)
local CityService = require(script.CityService)
local CombatService = require(script.CombatService)
local BlueprintService = require(script.BlueprintService)

WorldBuilder.build()
WorldBuilder.startDayNight()

VehicleService.Tycoon = TycoonService
VehicleService.start()
TycoonService.start()
CombatService.start()
CityService.start()
DataService.start() -- last, so every service is listening when players load

-- One remote for every menu action. Each handler returns ok, message.
local handlers = table.clone(TycoonService.Actions)
handlers.Craft = BlueprintService.craft

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
		elseif cmd == "cash" then
			p.cash = args[1]
		elseif cmd == "blueprints" then
			for part, t in p.blueprints do
				t[args[1]] += args[2] or 1
			end
		elseif cmd == "action" then
			local ok, msg = handlers[args[1]](player, args[2] or {})
			DataService.push(player)
			return tostring(ok) .. " " .. tostring(msg)
		elseif cmd == "state" then
			local active = 0
			for _ in VehicleService.Active do
				active += 1
			end
			local shown = 0
			for _ in p.showroom do
				shown += 1
			end
			return ("cash=%d level=%d garage=%d showroom=%d activeCars=%d plot=%s"):format(p.cash, p.level, #p.garage, shown, active, tostring(TycoonService.plotOf(player) and TycoonService.plotOf(player).index))
		elseif cmd == "garage" then
			local out = {}
			for i, e in p.garage do
				out[i] = e.uid .. "=" .. (Cars.resolve(e).name or "?")
			end
			return table.concat(out, ";")
		end
		DataService.push(player)
		return "ok"
	end
	hook.Parent = game:GetService("ServerStorage")
end

print("[DrivinDealz] server ready")
