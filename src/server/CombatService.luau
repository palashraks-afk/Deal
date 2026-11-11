-- Guns: the Gun Store sells 10 guns (textured AI models in ServerStorage.Assets.Guns).
-- Shots are checked on the server (fire rate, ammo, range, line of sight). Guns hurt
-- players and cars; a car at 0 health breaks down, the driver is thrown out, and anyone
-- can hold E to hotwire it.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Guns = require(Shared.Guns)
local Cars = require(Shared.Cars)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local VehicleService = require(script.Parent.VehicleService)
local NpcService = require(script.Parent.NpcService)

local CombatService = {}
local state = {} :: { [Player]: { [string]: { ammo: number, last: number, reloadUntil: number } } }
local rng = Random.new()

---------------------------------------------------------------- tools
-- Which way each model's barrel points along its long (Z) axis: -1 = -Z, 1 = +Z.
-- (AI models come out either way; tuned by looking at them.)
local BARREL = { Pistol = -1, Revolver = -1, SMG = -1, MachinePistol = -1, Shotgun = -1, Rifle = -1, Bullpup = -1, Sniper = -1, LMG = -1, RPG = -1 }

local function makeTool(gun): Tool
	local tool = Instance.new("Tool")
	tool.Name = gun.id
	tool.ToolTip = gun.name
	tool.CanBeDropped = false
	tool:SetAttribute("GunId", gun.id)

	local assets = ServerStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Guns") and assets.Guns:FindFirstChild(gun.id)
	local handle
	if template then
		local mesh = template:FindFirstChildWhichIsA("MeshPart", true)
		if mesh then
			handle = mesh:Clone()
		end
	end
	if not handle then
		handle = Instance.new("Part")
		handle.Size = Vector3.new(0.4, 1, 2.4)
		handle.Color = Color3.fromRGB(30, 30, 34)
		handle.Material = Enum.Material.Metal
	end
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.CanTouch = false
	handle.Parent = tool

	local dir = BARREL[gun.id] or -1
	local len = handle.Size.Z
	-- hold it a third of the way from the back, barrel pointing forward
	tool.Grip = CFrame.new(0, -handle.Size.Y * 0.15, dir * -len * 0.18) * (dir == 1 and CFrame.Angles(0, math.pi, 0) or CFrame.new())
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, handle.Size.Y * 0.2, dir * len / 2)
	muzzle.Parent = handle
	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Range = 10
	flash.Brightness = 4
	flash.Color = Color3.fromRGB(255, 200, 120)
	flash.Enabled = false
	flash.Parent = handle
	return tool
end

local templates = {}
local function giveGuns(player: Player)
	local p = DataService.get(player)
	local backpack = player:FindFirstChild("Backpack")
	if not p or not backpack then
		return
	end
	for _, gun in ipairs(Guns) do
		if p.guns[gun.id] and not backpack:FindFirstChild(gun.id) and not (player.Character and player.Character:FindFirstChild(gun.id)) then
			templates[gun.id] = templates[gun.id] or makeTool(gun)
			templates[gun.id]:Clone().Parent = backpack
		end
	end
end
CombatService.giveGuns = giveGuns

---------------------------------------------------------------- cars
local function carFromPart(part: Instance): Model?
	local node = part
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("MaxHealth") and node.Parent and node.Parent.Name == "Vehicles" then
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
	smoke.Color = Color3.fromRGB(40, 40, 40)
	smoke.Size = 6
	smoke.RiseVelocity = 6
	smoke.Opacity = 0.45
	smoke.Parent = root
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Parent = root
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HotwirePrompt"
	prompt.ActionText = "Hotwire"
	prompt.ObjectText = model:GetAttribute("CarName")
	prompt.HoldDuration = Config.Combat.HotwireTime
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
		model:SetAttribute("Health", math.floor(model:GetAttribute("MaxHealth") * Config.Combat.RepairedHealth))
		model:SetAttribute("HotwiredBy", player.UserId)
		smoke:Destroy()
		fire:Destroy()
		prompt:Destroy()
		if drive then
			drive.Enabled = true
		end
		model.DriverSeat:Sit(hum)
	end)
	local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
	if owner then
		VehicleService.notify(owner, ("Your %s was wrecked!"):format(model:GetAttribute("CarName")), Color3.fromRGB(255, 70, 70))
	end
end

local function damageCar(shooter: Player, car: Model, amount: number)
	if car:GetAttribute("Disabled") then
		return
	end
	local info = VehicleService.Active[car]
	if not info then
		return
	end
	-- not your own personal car, not the car you're driving
	if info.source == "Garage" and info.ownerUserId == shooter.UserId and not car:GetAttribute("HotwiredBy") then
		return
	end
	if VehicleService.getDriver(car) == shooter then
		return
	end
	local health = car:GetAttribute("Health") - amount
	car:SetAttribute("Health", math.max(0, health))
	if health <= 0 then
		breakDown(car)
	end
end

local function damageHumanoid(shooter: Player, hum: Humanoid, amount: number)
	if hum.Health <= 0 then
		return false
	end
	local victim = Players:GetPlayerFromCharacter(hum.Parent)
	if victim == shooter then
		return false
	end
	if victim then
		-- a little armour while sitting in a car
		if hum.Sit then
			amount *= 0.5
		end
		hum:TakeDamage(amount)
		if hum.Health <= 0 then
			VehicleService.notify(shooter, ("You took out %s!"):format(victim.DisplayName), Color3.fromRGB(255, 200, 60))
		end
		return true
	end
	-- NPC customers just flinch (no killing shoppers)
	return false
end

local function explode(shooter: Player, gun, at: Vector3)
	Net.Effect:FireAllClients("Explosion", at)
	local boom = Instance.new("Explosion")
	boom.Position = at
	boom.BlastRadius = gun.explosive
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Parent = workspace
	local hitCars = {}
	for _, part in workspace:GetPartBoundsInRadius(at, gun.explosive) do
		local car = carFromPart(part)
		if car and not hitCars[car] then
			hitCars[car] = true
			damageCar(shooter, car, gun.carDamage)
		end
	end
	for _, other in Players:GetPlayers() do
		local char = other.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and char.PrimaryPart and (char.PrimaryPart.Position - at).Magnitude <= gun.explosive then
			damageHumanoid(shooter, hum, gun.damage * (1 - (char.PrimaryPart.Position - at).Magnitude / gun.explosive * 0.6))
		end
	end
end

---------------------------------------------------------------- firing
local function onFire(player: Player, gunId: string, target: Vector3, aiming: boolean?)
	if typeof(target) ~= "Vector3" or type(gunId) ~= "string" then
		return
	end
	local gun = Guns.ById[gunId]
	local char = player.Character
	local tool = char and char:FindFirstChild(gunId)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not gun or not tool or not hum or hum.Health <= 0 then
		return
	end
	state[player] = state[player] or {}
	local s = state[player][gunId]
	if not s then
		s = { ammo = gun.mag, last = 0, reloadUntil = 0 }
		state[player][gunId] = s
	end
	local now = os.clock()
	if now < s.reloadUntil or now - s.last < gun.fireRate * 0.8 then
		return
	end
	if s.ammo <= 0 then
		s.ammo = gun.mag
		s.reloadUntil = now + gun.reload
		return
	end
	s.ammo -= 1
	s.last = now
	if s.ammo <= 0 then
		s.ammo = gun.mag
		s.reloadUntil = now + gun.reload
	end

	local handle = tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	local origin = muzzle and muzzle.WorldPosition or char.Head.Position
	-- don't let people shoot from far away from their own body
	if (origin - char.Head.Position).Magnitude > 8 then
		origin = char.Head.Position
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local hits = {}
	for _ = 1, gun.pellets or 1 do
		local dir = (target - origin).Unit
		-- aiming down sights = shots land where the crosshair is (shotguns still spread a bit)
		local spread = math.rad(gun.spread) * (aiming == true and (gun.pellets and 0.5 or 0.08) or 1)
		dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread), 0)).LookVector
		local result = workspace:Raycast(origin, dir * gun.range, params)
		local hitPos = result and result.Position or (origin + dir * gun.range)
		table.insert(hits, hitPos)
		if result then
			if gun.explosive then
				explode(player, gun, hitPos)
			else
				local car = carFromPart(result.Instance)
				if car then
					damageCar(player, car, gun.carDamage)
					Net.Effect:FireAllClients("CarHit", hitPos, result.Normal)
				else
					local model = result.Instance:FindFirstAncestorOfClass("Model")
					local victimHum = model and model:FindFirstChildOfClass("Humanoid")
					if victimHum then
						if model:GetAttribute("Kind") then
							NpcService.react(model)
						else
							local headshot = result.Instance.Name == "Head"
							damageHumanoid(player, victimHum, gun.damage * (headshot and 1.6 or 1))
						end
						Net.Effect:FireAllClients("BodyHit", hitPos, result.Normal)
					else
						Net.Effect:FireAllClients("Impact", hitPos, result.Normal)
					end
				end
			end
		elseif gun.explosive then
			explode(player, gun, hitPos)
		end
	end
	Net.Tracer:FireAllClients(player, gunId, origin, hits)
	if handle and handle:FindFirstChild("Flash") then
		handle.Flash.Enabled = true
		task.delay(0.05, function()
			handle.Flash.Enabled = false
		end)
	end
end

---------------------------------------------------------------- store
local Actions = {}
function Actions.BuyGun(player, args)
	local p = DataService.get(player)
	local gun = Guns.ById[tostring(args.id)]
	if not gun then
		return false, "Unknown gun."
	end
	if p.guns[gun.id] then
		return false, "You already own it."
	end
	if p.cash < gun.price then
		return false, ("Costs %s"):format(Cars.money(gun.price))
	end
	DataService.addCash(player, -gun.price)
	p.guns[gun.id] = true
	giveGuns(player)
	return true, ("Bought the %s!"):format(gun.name)
end
CombatService.Actions = Actions

function CombatService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			state[player] = nil
			char:WaitForChild("Humanoid")
			task.wait(0.5)
			giveGuns(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	DataService.Loaded.Event:Connect(function(player)
		task.wait(1)
		giveGuns(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
	Players.RespawnTime = Config.Combat.PlayerRespawn
	Net.Fire.OnServerEvent:Connect(onFire)
end

return CombatService
