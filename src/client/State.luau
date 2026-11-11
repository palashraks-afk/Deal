-- Latest copy of this player's data from the server, plus helpers to call actions.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Upgrades = require(Shared.Upgrades)

local State = {}
State.Data = nil
State.Effects = nil
State.Changed = Instance.new("BindableEvent")
State.Toast = Instance.new("BindableEvent") -- fire({text, color}) to show a toast

local function numKeys(t)
	local out = {}
	for k, v in t or {} do
		out[tonumber(k) or k] = v
	end
	return out
end

Net.Data.OnClientEvent:Connect(function(data)
	for _, key in { "showroom", "prize", "blueprints", "factory" } do
		data[key] = numKeys(data[key])
	end
	for _, track in Upgrades.Tracks do
		data.upgrades[track] = numKeys(data.upgrades[track])
	end
	-- server clock offset so factory timers count down correctly
	data.clockOffset = (data.serverTime or os.time()) - os.time()
	State.Data = data
	State.Effects = Upgrades.effects(data.upgrades)
	State.Changed:Fire(data)
end)

-- Run a server action; shows the server's message as a toast.
function State.act(action: string, args)
	local ok, message = Net.Action:InvokeServer(action, args or {})
	if message then
		State.Toast:Fire({ text = message, color = ok and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(255, 90, 90) })
	end
	return ok
end

function State.slotOf(uid: string): number?
	if not State.Data then
		return nil
	end
	for slot, s in State.Data.showroom do
		if s.uid == uid then
			return slot
		end
	end
	return nil
end

function State.prizeSlotOf(uid: string): number?
	if not State.Data then
		return nil
	end
	for slot, u in State.Data.prize do
		if u == uid then
			return slot
		end
	end
	return nil
end

function State.now(): number
	return os.time() + (State.Data and State.Data.clockOffset or 0)
end

return State
