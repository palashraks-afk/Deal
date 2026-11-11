-- Street objects you can smash with a car. Anything tagged "Breakable" (streetlights,
-- traffic lights, stop signs, bus stops, hydrants, bins) flies off when a car hits it
-- fast enough, tumbles with real physics, fades out, and grows back in its spot later.
-- Hydrants spray water when knocked over. Pedestrians hit by a car get knocked down
-- and stand back up.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local BreakableService = {}

local MIN_SPEED = 16 -- studs/s a car needs to knock something over
local LINGER = 8 -- seconds the knocked object lies around
local RESPAWN = 35 -- seconds until it's back

local originals = {} -- model -> { copy = untouched clone, parent = original parent }
local broken = {}

-- the car (if any) a touching part belongs to, and how fast it's going
local function carOf(part: BasePart): (Model?, number)
	local node = part
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChild("DriverSeat") then
			local root = node.PrimaryPart
			return node, root and root.AssemblyLinearVelocity.Magnitude or 0
		end
		node = node.Parent
	end
	return nil, 0
end

local function sprayWater(at: BasePart)
	local att = Instance.new("Attachment")
	att.Parent = at
	local water = Instance.new("ParticleEmitter")
	water.Texture = "rbxasset://textures/particles/smoke_main.dds"
	water.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
	water.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.5) })
	water.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	water.Lifetime = NumberRange.new(1, 1.6)
	water.Rate = 90
	water.Speed = NumberRange.new(28, 36)
	water.SpreadAngle = Vector2.new(10, 10)
	water.Acceleration = Vector3.new(0, -60, 0)
	water.EmissionDirection = Enum.NormalId.Top
	water.Parent = att
	return water
end

local function hook(model: Model) end -- forward declaration (set below)

local function respawn(model: Model)
	local info = originals[model]
	if not info then
		return
	end
	originals[model] = nil
	local fresh = info.copy:Clone()
	fresh.Parent = info.parent
	hook(fresh)
end

local function knock(model: Model, carVelocity: Vector3)
	if broken[model] then
		return
	end
	broken[model] = true
	local parts = {}
	local biggest, vol = nil, 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > vol then
				vol, biggest = v, d
			end
		end
	end
	if not biggest then
		return
	end
	-- keep the object in one piece while it flies
	for _, p in parts do
		if p ~= biggest then
			local w = Instance.new("WeldConstraint")
			w.Part0 = biggest
			w.Part1 = p
			w.Parent = p
		end
		p.CanTouch = false
	end
	for _, p in parts do
		p.Anchored = false
		p.CanCollide = true
	end
	pcall(function()
		biggest:SetNetworkOwner(nil)
	end)
	local push = carVelocity * 0.9 + Vector3.new(0, 18 + carVelocity.Magnitude * 0.25, 0)
	biggest.AssemblyLinearVelocity = push
	biggest.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(-6, 6))
	Net.Effect:FireAllClients("CarHit", biggest.Position, Vector3.new(0, 1, 0))

	if model.Name == "Hydrant" then
		-- the stub stays and sprays
		local stub = Instance.new("Part")
		stub.Anchored = true
		stub.Size = Vector3.new(0.6, 0.4, 0.6)
		stub.Transparency = 1
		stub.CanCollide = false
		stub.Position = model:GetAttribute("Base") or biggest.Position
		stub.Parent = workspace
		sprayWater(stub)
		task.delay(LINGER + 4, function()
			stub:Destroy()
		end)
	end

	task.delay(LINGER, function()
		for _, p in parts do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
			end
		end
		task.wait(1.1)
		model:Destroy()
		broken[model] = nil
		task.delay(RESPAWN - LINGER, function()
			respawn(model)
		end)
	end)
end

hook = function(model: Model)
	if originals[model] then
		return
	end
	originals[model] = { copy = model:Clone(), parent = model.Parent }
	local base = model:GetBoundingBox()
	model:SetAttribute("Base", base.Position - Vector3.new(0, select(2, model:GetBoundingBox()).Y / 2 - 1, 0))
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanTouch = true
			p.Touched:Connect(function(hit)
				if broken[model] then
					return
				end
				local car, speed = carOf(hit)
				if car and speed >= MIN_SPEED then
					knock(model, car.PrimaryPart.AssemblyLinearVelocity)
				end
			end)
		end
	end
end

---------------------------------------------------------------- pedestrians
local downUntil = setmetatable({}, { __mode = "k" })
local function knockDown(npc: Model, carVelocity: Vector3)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not hum or not root or (downUntil[npc] and os.clock() < downUntil[npc]) then
		return
	end
	downUntil[npc] = os.clock() + 4
	hum.PlatformStand = true
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.AssemblyLinearVelocity = carVelocity * 0.8 + Vector3.new(0, 30, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
	Net.Effect:FireAllClients("BodyHit", root.Position, Vector3.new(0, 1, 0))
	task.delay(3, function()
		if hum.Parent and hum.Health > 0 then
			hum.PlatformStand = false
			-- stand back up the right way
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.1 then
				flat = Vector3.new(0, 0, -1)
			end
			root.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 2.5, 0), root.Position + Vector3.new(0, 2.5, 0) + flat.Unit)
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function hookNpc(npc: Instance)
	if not npc:IsA("Model") then
		return
	end
	local root = npc:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	root.CanTouch = true
	root.Touched:Connect(function(hit)
		local car, speed = carOf(hit)
		if car and speed >= MIN_SPEED then
			knockDown(npc, car.PrimaryPart.AssemblyLinearVelocity)
		end
	end)
end

function BreakableService.start()
	for _, m in CollectionService:GetTagged("Breakable") do
		hook(m)
	end
	-- pedestrians and dealership customers
	for _, folderName in { "Pedestrians", "Customers" } do
		task.spawn(function()
			local folder = workspace:WaitForChild(folderName, 30)
			if not folder then
				return
			end
			for _, npc in folder:GetChildren() do
				task.spawn(hookNpc, npc)
			end
			folder.ChildAdded:Connect(function(npc)
				task.spawn(hookNpc, npc)
			end)
		end)
	end
	local _ = Players
end

return BreakableService
