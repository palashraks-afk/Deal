-- The Disabler blaster: shoot a car until it breaks down, the driver is thrown out,
-- and anyone can hold E to hotwire it and drive off.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local VehicleService = require(script.Parent.VehicleService)

local CombatService = {}
local lastShot = {} :: { [Player]: number }

local function makeTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Disabler"
	tool.ToolTip = "Shoot cars to break them down"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, -0.2, 0.5)

	local function piece(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.CFrame = CFrame.new(offset)
		p.Parent = tool
		return p
	end
	local handle = piece("Handle", Vector3.new(0.4, 1, 0.6), Vector3.zero, Color3.fromRGB(30, 30, 34))
	local body = piece("Body", Vector3.new(0.5, 0.6, 2), Vector3.new(0, 0.6, -0.6), Color3.fromRGB(40, 44, 52), Enum.Material.Metal)
	local barrel = piece("Barrel", Vector3.new(0.25, 0.25, 0.8), Vector3.new(0, 0.65, -2), Color3.fromRGB(80, 200, 255), Enum.Material.Neon)
	for _, p in { body, barrel } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.65, -2.4)
	muzzle.Parent = handle
	return tool
end

local function carFromPart(part: Instance): Model?
	local node = part
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("MaxHealth") then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function breakDown(model: Model)
	model:SetAttribute("Disabled", true)
	model:SetAttribute("HotwiredBy", nil)
	VehicleService.eject(model)
	local root = model.PrimaryPart
	local smoke = Instance.new("Smoke")
	smoke.Name = "DamageSmoke"
	smoke.Color = Color3.fromRGB(40, 40, 40)
	smoke.Size = 6
	smoke.RiseVelocity = 6
	smoke.Opacity = 0.4
	smoke.Parent = root
	local fire = Instance.new("Fire")
	fire.Name = "DamageFire"
	fire.Size = 4
	fire.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HotwirePrompt"
	prompt.ActionText = "Hotwire"
	prompt.ObjectText = model:GetAttribute("CarName")
	prompt.HoldDuration = Config.Blaster.HotwireTime
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	local drive = root:FindFirstChild("DrivePrompt")
	if drive then
		drive.Enabled = false
	end
	prompt.Triggered:Connect(function(player)
		if not model.Parent or not model:GetAttribute("Disabled") then
			return
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			return
		end
		model:SetAttribute("Disabled", false)
		model:SetAttribute("Health", math.floor(model:GetAttribute("MaxHealth") * Config.Blaster.RepairedHealth))
		model:SetAttribute("HotwiredBy", player.UserId)
		smoke:Destroy()
		fire:Destroy()
		prompt:Destroy()
		if drive then
			drive.Enabled = true
		end
		model.DriverSeat:Sit(hum)
	end)

	local victim = model:GetAttribute("OwnerUserId")
	local owner = victim and Players:GetPlayerByUserId(victim)
	if owner then
		VehicleService.notify(owner, ("Your %s was disabled!"):format(model:GetAttribute("CarName")), Color3.fromRGB(255, 70, 70))
	end
end

local function onFire(player: Player, target: Vector3)
	if typeof(target) ~= "Vector3" then
		return
	end
	local now = os.clock()
	if now - (lastShot[player] or 0) < Config.Blaster.FireRate * 0.8 then
		return
	end
	lastShot[player] = now
	local char = player.Character
	local tool = char and char:FindFirstChild("Disabler")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not tool or not hum or hum.Health <= 0 or hum.Sit then
		return
	end
	local origin = tool.Handle.Muzzle.WorldPosition
	local dir = target - origin
	if dir.Magnitude < 0.1 then
		return
	end
	dir = dir.Unit * Config.Blaster.Range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(origin, dir, params)
	local hitPos = hit and hit.Position or (origin + dir)
	Net.Tracer:FireAllClients(player, origin, hitPos)

	if not hit then
		return
	end
	local car = carFromPart(hit.Instance)
	if not car or car:GetAttribute("Disabled") or not car.Parent or car.Parent.Name ~= "Vehicles" then
		return
	end
	-- you can't hurt your own personal car, or the car you're driving
	local info = VehicleService.Active[car]
	if not info then
		return
	end
	if info.source == "Garage" and info.ownerUserId == player.UserId and not car:GetAttribute("HotwiredBy") then
		return
	end
	if VehicleService.getDriver(car) == player then
		return
	end
	local health = car:GetAttribute("Health") - Config.Blaster.Damage
	car:SetAttribute("Health", math.max(0, health))
	if health <= 0 then
		breakDown(car)
	end
end

function CombatService.start()
	local template = makeTool()
	local function give(player: Player)
		local backpack = player:WaitForChild("Backpack")
		if not backpack:FindFirstChild("Disabler") then
			template:Clone().Parent = backpack
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			give(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		if player.Character then
			give(player)
		end
		player.CharacterAdded:Connect(function()
			give(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)
	Net.Fire.OnServerEvent:Connect(onFire)
end

return CombatService
