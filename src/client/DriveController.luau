-- Arcade driving for the car you're sitting in. The client owns the car's physics,
-- so this runs every frame: throttle, braking, grip (kills sideways slide), steering,
-- downforce, anti-flip, and spinning/steering the wheel visuals.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local player = Players.LocalPlayer

local DriveController = {}
DriveController.Car = nil :: Model?
DriveController.Speed = 0

local handbrake = false
local conn
local wheelSpin = 0

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

	-- are we on the ground?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car, player.Character }
	local ground = workspace:Raycast(root.Position, -cf.UpVector * ((car:GetAttribute("Height") or 5) + 2), params)
	if not ground then
		return
	end

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

	root:ApplyImpulse(impulse * mass * dt)

	-- steering: set yaw rate directly (smooth + predictable)
	local speedFactor = math.clamp(math.abs(fwdSpeed) / 25, 0, 1)
	local highSpeedDamp = 1 - math.clamp(math.abs(fwdSpeed) / (top * 1.6), 0, 0.55)
	local yawRate = -steer * Config.Drive.SteerRate * speedFactor * highSpeedDamp * math.sign(fwdSpeed + 0.01)
	if handbrake then
		yawRate *= 1.5
	end
	local ang = root.AssemblyAngularVelocity
	local up = cf.UpVector
	local currentYaw = ang:Dot(up)
	local newYaw = currentYaw + (yawRate - currentYaw) * math.clamp(dt * 8, 0, 1)
	-- damp roll/pitch wobble
	local nonYaw = (ang - up * currentYaw) * 0.9
	root.AssemblyAngularVelocity = nonYaw + up * newYaw

	-- wheels
	wheelSpin = (wheelSpin + fwdSpeed * dt / ((car:GetAttribute("WheelRadius") or 1))) % (math.pi * 2)
	for _, name in { "WheelFL", "WheelFR", "WheelRL", "WheelRR" } do
		local wheel = car:FindFirstChild(name)
		local weld = wheel and wheel:FindFirstChild("Axle")
		local base = wheel and wheel:GetAttribute("BaseC0")
		if weld and base then
			local steerAngle = (name == "WheelFL" or name == "WheelFR") and -steer * 0.45 or 0
			weld.C0 = base * CFrame.Angles(0, steerAngle, 0) * CFrame.Angles(-wheelSpin, 0, 0)
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
			DriveController.Car = car
			DriveController.Speed = 0
			handbrake = false
		end
	end)
	conn = RunService.PreSimulation:Connect(step)
end

function DriveController.stop()
	if conn then
		conn:Disconnect()
	end
end

return DriveController
