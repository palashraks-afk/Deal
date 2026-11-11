-- Latest copy of this player's data from the server, plus helpers to call actions.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = {}
State.Data = nil
State.Changed = Instance.new("BindableEvent")
State.Toast = Instance.new("BindableEvent") -- fire({text, color}) to show a toast

Net.Data.OnClientEvent:Connect(function(data)
	local showroom = {}
	for k, v in data.showroom do
		showroom[tonumber(k)] = v
	end
	data.showroom = showroom
	State.Data = data
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

return State
