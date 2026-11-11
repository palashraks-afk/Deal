-- Remote events/functions. The server creates them; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local function get(name: string, className: string)
	if RunService:IsServer() then
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new(className)
			r.Name = name
			r.Parent = folder
		end
		return r
	end
	return folder:WaitForChild(name)
end

Net.Data = get("Data", "RemoteEvent") -- server -> client: full profile snapshot
Net.Notify = get("Notify", "RemoteEvent") -- server -> client: toast {text, color}
Net.Action = get("Action", "RemoteFunction") -- client -> server: (action, args) -> ok, message
Net.Fire = get("Fire", "RemoteEvent") -- client -> server: blaster shot at position
Net.Tracer = get("Tracer", "RemoteEvent") -- server -> clients: draw a shot
Net.Effect = get("Effect", "RemoteEvent") -- server -> clients: (kind, position) sounds + VFX
Net.Tutorial = get("Tutorial", "RemoteEvent") -- client -> server: tutorial progress

return Net
