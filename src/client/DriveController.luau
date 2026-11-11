-- Arcade driving for the car you're sitting in. The client owns the car's physics,
-- so this runs every frame: raycast suspension, throttle, braking, grip (kills
-- sideways slide), steering, downforce, and the wheel visuals (spin, steer, travel).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)

local player = Players.LocalPlayer

local DriveController = {}
DriveController.Car = nil :: Model?
DriveController.Speed = 0
DriveController.Fx = {}
DriveController.Drifting = false

local handbrake = false
local conn
local wheelSpin = 0
local WHEELS = { "WheelFL", "WheelFR", "WheelRL", "WheelRR" }
local wheelDrop = {} -- how far each wheel hangs below its rest spot (suspension visual)

local function currentCar(): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		return seat.Parent
	end
	return nil
end

local function step(dt: number)
	local car = DriveController.Car
	if not car or not car.Parent or not car.PrimaryPart then
		return
	end
	local root = car.PrimaryPart
	if root.Anchored or car:GetAttribute("Disabled") then
		return
	end
	local seat = car:FindFirstChild("DriverSeat")
	-- keyboard directly, plus the seat's own input (mobile thumbstick / gamepad)
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	if not UserInputService:GetFocusedTextBox() then
		local kb = (UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)) and 1 or 0
		kb -= (UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)) and 1 or 0
		local ks = (UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)) and 1 or 0
		ks -= (UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)) and 1 or 0
		if kb ~= 0 then
			throttle = kb
		end
		if ks ~= 0 then
			steer = ks
		end
	end

	local mass = root.AssemblyMass
	local cf = root.CFrame
	local vel = root.AssemblyLinearVelocity
	local forward = cf.LookVector
	local right = cf.RightVector
	local fwdSpeed = vel:Dot(forward)
	local sideSpeed = vel:Dot(right)
	DriveController.Speed = fwdSpeed

	local top = car:GetAttribute("TopSpeed") or 100
	local accel = car:GetAttribute("Accel") or 30
	local health = car:GetAttribute("Health") or 100
	local maxHealth = car:GetAttribute("MaxHealth") or 100
	-- damaged cars lose power
	local power = 0.55 + 0.45 * (health / maxHealth)

	-- RAYCAST SUSPENSION: a spring + damper at each wheel. Wheels don't collide, so
	-- road seams, kerbs and slopes are smoothed out instead of jolting the car.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car, player.Character }
	local up = cf.UpVector
	local wheelR = car:GetAttribute("WheelRadius") or 1
	local travel = math.max(wheelR * 0.9, 0.8)
	local g = workspace.Gravity
	local k = mass * g / 4 / (travel * 0.45) -- settles at ~45% compression
	local c = 2 * math.sqrt(k * mass / 4) * 0.55 -- a little under critical damping
	local grounded = 0
	for _, name in WHEELS do
		local wheel = car:FindFirstChild(name)
		local base = wheel and wheel:GetAttribute("BaseC0")
		if base then
			local origin = cf * (base.Position + Vector3.new(0, travel * 0.5, 0))
			local len = wheelR + travel * 1.5
			local hit = workspace:Raycast(origin, -up * len, params)
			local drop = travel * 1.5 -- wheel hangs fully down in the air
			if hit then
				local compress = len - hit.Distance
				local pointVel = root:GetVelocityAtPosition(origin):Dot(up)
				local force = math.max(k * compress - c * pointVel, 0)
				root:ApplyImpulseAtPosition(up * force * dt, origin)
				grounded += 1
				drop = hit.Distance - wheelR
			end
			-- visual: wheel sits where the ray says the road is
			wheelDrop[name] = (wheelDrop[name] or 0) + ((drop - travel * 0.5) - (wheelDrop[name] or 0)) * math.clamp(dt * 20, 0, 1)
		end
	end
	if grounded == 0 then
		return
	end
	local tractionShare = grounded / 4

	-- throttle / brake / reverse
	local impulse = Vector3.zero
	if throttle > 0 then
		if fwdSpeed < top * power then
			local falloff = 1 - math.clamp(fwdSpeed / (top * power), 0, 1) * 0.6
			impulse += forward * accel * power * falloff * throttle
		end
	elseif throttle < 0 then
		if fwdSpeed > 2 then
			impulse += -forward * accel * 2.2 -- braking
		elseif fwdSpeed > -top * 0.3 then
			impulse += -forward * accel * 0.6
		end
	else
		-- rolling resistance
		impulse += -forward * math.clamp(fwdSpeed, -6, 6) * 1.2
	end

	-- grip: cancel sideways slide (less with handbrake = drift)
	local grip = handbrake and 0.12 or Config.Drive.Grip
	impulse += -right * sideSpeed * grip * 8
	if handbrake then
		impulse += -forward * math.clamp(fwdSpeed, -1, 1) * 18
	end
	-- downforce keeps fast cars planted
	impulse += -cf.UpVector * math.abs(fwdSpeed) * 0.15

	root:ApplyImpulse(impulse * mass * dt * tractionShare)

	-- steering: set yaw rate directly (smooth + predictable); full steering from ~8 studs/s
	local speedFactor = math.clamp(math.abs(fwdSpeed) / 8, 0, 1)
	local highSpeedDamp = 1 - math.clamp(math.abs(fwdSpeed) / (top * 1.6), 0, 0.55)
	local yawRate = -steer * Config.Drive.SteerRate * speedFactor * highSpeedDamp * math.sign(fwdSpeed + 0.01)
	if handbrake then
		yawRate *= 1.5
	end
	local ang = root.AssemblyAngularVelocity
	local currentYaw = ang:Dot(up)
	local newYaw = currentYaw + (yawRate - currentYaw) * math.clamp(dt * 8, 0, 1)
	-- damp roll/pitch wobble
	local nonYaw = (ang - up * currentYaw) * 0.9
	root.AssemblyAngularVelocity = nonYaw + up * newYaw

	-- drift effects: tyre smoke + skid marks while sliding
	local sliding = (math.abs(sideSpeed) > 14 or (handbrake and math.abs(fwdSpeed) > 18))
	for _, fx in DriveController.Fx do
		fx.smoke.Enabled = sliding
		fx.trail.Enabled = sliding
	end
	DriveController.Drifting = sliding

	-- wheels
	wheelSpin =(wheelSpin + fwdSpeed * dt / ((car:GetAttribute("WheelRadius") or 1))) % (math.pi * 2)
	for _, name in { "WheelFL", "WheelFR", "WheelRL", "WheelRR" } do
		local wheel = car:FindFirstChild(name)
		local weld = wheel and wheel:FindFirstChild("Axle")
		local base = wheel and wheel:GetAttribute("BaseC0")
		if weld and base then
			local steerAngle = (name == "WheelFL" or name == "WheelFR") and -steer * 0.45 or 0
			weld.C0 = CFrame.new(0, -(wheelDrop[name] or 0), 0) * base * CFrame.Angles(0, steerAngle, 0) * CFrame.Angles(-wheelSpin, 0, 0)
		end
	end
end

-- flip the car back over if it's stuck upside down
local function unflip()
	local car = DriveController.Car
	if not car or not car.PrimaryPart then
		return
	end
	local root = car.PrimaryPart
	if root.CFrame.UpVector.Y < 0.5 then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(0, 0, -1)
		end
		local pos = root.Position + Vector3.new(0, 4, 0)
		car:PivotTo(CFrame.lookAt(pos, pos + flat.Unit))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function DriveController.start()
	ContextActionService:BindAction("Handbrake", function(_, state)
		handbrake = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonX) -- Space is "get out"
	ContextActionService:SetTitle("Handbrake", "Drift")
	ContextActionService:SetPosition("Handbrake", UDim2.new(1, -150, 1, -150))
	ContextActionService:BindAction("Unflip", function(_, state)
		if state == Enum.UserInputState.Begin then
			unflip()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R)

	RunService.Heartbeat:Connect(function()
		local car = currentCar()
		if car ~= DriveController.Car then
			for _, fx in DriveController.Fx do
				fx.folder:Destroy()
			end
			table.clear(DriveController.Fx)
			DriveController.Car = car
			DriveController.Speed = 0
			handbrake = false
			if car then
				-- local-only drift FX on the rear wheels
				for _, name in { "WheelRL", "WheelRR" } do
					local wheel = car:FindFirstChild(name)
					if wheel then
						local folder = Instance.new("Folder")
						folder.Name = "DriftFx"
						local r = wheel.Size.Y / 2
						local a0 = Instance.new("Attachment")
						a0.Position = Vector3.new(-wheel.Size.X / 2, -r + 0.1, 0)
						local a1 = Instance.new("Attachment")
						a1.Position = Vector3.new(wheel.Size.X / 2, -r + 0.1, 0)
						local mid = Instance.new("Attachment")
						mid.Position = Vector3.new(0, -r + 0.2, 0)
						for _, a in { a0, a1, mid } do
							a.Parent = car.PrimaryPart
							a.WorldPosition = wheel.CFrame:PointToWorldSpace(a.Position)
						end
						local trail = Instance.new("Trail")
						trail.Attachment0 = a0
						trail.Attachment1 = a1
						trail.Lifetime = 4
						trail.Color = ColorSequence.new(Color3.fromRGB(20, 20, 22))
						trail.Transparency = NumberSequence.new(0.35, 1)
						trail.LightInfluence = 1
						trail.FaceCamera = false
						trail.Enabled = false
						trail.Parent = folder
						local smoke = Instance.new("ParticleEmitter")
						smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
						smoke.Rate = 40
						smoke.Lifetime = NumberRange.new(1, 1.8)
						smoke.Speed = NumberRange.new(2, 5)
						smoke.SpreadAngle = Vector2.new(40, 40)
						smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) })
						smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
						smoke.Color = ColorSequence.new(Color3.fromRGB(225, 225, 225))
						smoke.Acceleration = Vector3.new(0, 3, 0)
						smoke.Enabled = false
						smoke.Parent = mid
						folder.Parent = car
						table.insert(DriveController.Fx, { folder = folder, trail = trail, smoke = smoke, attachments = { a0, a1, mid } })
						folder.Destroying:Connect(function()
							for _, a in { a0, a1, mid } do
								a:Destroy()
							end
						end)
					end
				end
			end
		end
	end)
	conn = RunService.PreSimulation:Connect(step)

	-- engine sounds for every occupied car near you (pitch follows speed), skid squeal for yours
	local engines = {}
	local skid
	RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera.CFrame.Position
		local vehicles = workspace:FindFirstChild("Vehicles")
		for _, car in vehicles and vehicles:GetChildren() or {} do
			local seat = car:FindFirstChild("DriverSeat")
			local root = car.PrimaryPart
			local active = seat and seat.Occupant and root and (root.Position - cam).Magnitude < 250
			local s = engines[car]
			if active and not s then
				s = Sounds.loop("Engine", root, car == DriveController.Car and 0.55 or 0.4)
				engines[car] = s
			elseif not active and s then
				s:Destroy()
				engines[car] = nil
				s = nil
			end
			if s then
				local top = car:GetAttribute("TopSpeed") or 120
				local speed = root.AssemblyLinearVelocity.Magnitude
				s.PlaybackSpeed = 0.75 + math.clamp(speed / top, 0, 1.1) * 1.05
			end
		end
		for car, s in engines do
			if not car.Parent then
				s:Destroy()
				engines[car] = nil
			end
		end
		local mine = DriveController.Car
		if mine and mine.PrimaryPart then
			if not skid or skid.Parent ~= mine.PrimaryPart then
				if skid then
					skid:Destroy()
				end
				skid = Sounds.loop("Skid", mine.PrimaryPart, 0)
			end
			skid.Volume = DriveController.Drifting and 0.5 or 0
		elseif skid then
			skid:Destroy()
			skid = nil
		end
	end)
end

function DriveController.stop()
	if conn then
		conn:Disconnect()
	end
end

return DriveController
