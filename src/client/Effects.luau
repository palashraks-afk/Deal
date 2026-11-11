-- Visual + sound effects triggered by the server (Net.Effect) or locally:
-- bullet impacts (dust puffs), car hits (sparks + metal ping), explosions (fireball,
-- smoke, screen shake), sales (cash sound), upgrades (build chime), city ambience.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local player = Players.LocalPlayer

local Effects = {}

local function holder(pos: Vector3, normal: Vector3?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.lookAt(pos, pos + (normal or Vector3.yAxis))
	p.Parent = workspace.CurrentCamera
	return p
end

local function burst(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Front
	for k, v in props do
		if k ~= "count" then
			e[k] = v
		end
	end
	e.Parent = parent
	e:Emit(props.count or 10)
	return e
end

function Effects.sparks(pos: Vector3, normal: Vector3?)
	local h = holder(pos, normal)
	burst(h, {
		count = 14,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 140, 40)),
		LightEmission = 1,
		Size = NumberSequence.new(0.35, 0),
		Lifetime = NumberRange.new(0.15, 0.35),
		Speed = NumberRange.new(18, 35),
		SpreadAngle = Vector2.new(50, 50),
		Acceleration = Vector3.new(0, -60, 0),
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Range = 8
	light.Brightness = 3
	light.Parent = h
	Debris:AddItem(h, 0.6)
	task.delay(0.06, function()
		light.Enabled = false
	end)
end

function Effects.dust(pos: Vector3, normal: Vector3?)
	local h = holder(pos, normal)
	burst(h, {
		count = 8,
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(170, 160, 150)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(4, 10),
		SpreadAngle = Vector2.new(30, 30),
	})
	-- bullet hole
	local hole = Instance.new("Part")
	hole.Anchored = true
	hole.CanCollide = false
	hole.CanQuery = false
	hole.Size = Vector3.new(0.35, 0.35, 0.05)
	hole.Color = Color3.fromRGB(20, 20, 20)
	hole.Material = Enum.Material.SmoothPlastic
	hole.CFrame = CFrame.lookAt(pos, pos + (normal or Vector3.yAxis))
	hole.Parent = workspace.CurrentCamera
	Debris:AddItem(hole, 8)
	Debris:AddItem(h, 1)
end

function Effects.shake(intensity: number, duration: number)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > duration then
			conn:Disconnect()
			return
		end
		local k = intensity * (1 - t / duration)
		workspace.CurrentCamera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * k), math.rad((math.random() - 0.5) * k), 0)
	end)
end

function Effects.explosion(pos: Vector3)
	local h = holder(pos)
	local fire = burst(h, {
		count = 40,
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 30)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 30, 10)) }),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(10, 30),
		SpreadAngle = Vector2.new(180, 180),
	})
	local _ = fire
	burst(h, {
		count = 30,
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(50, 50, 50)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 18) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(6, 16),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 6, 0),
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Range = 50
	light.Brightness = 6
	light.Parent = h
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(h, 4)
	Sounds.play("Explosion", pos, 1)
	local char = player.Character
	if char and char.PrimaryPart then
		local d = (char.PrimaryPart.Position - pos).Magnitude
		if d < 160 then
			Effects.shake(6 * (1 - d / 160), 0.6)
		end
	end
end

function Effects.start()
	Net.Effect.OnClientEvent:Connect(function(kind, pos, normal)
		if kind == "Impact" then
			Effects.dust(pos, normal)
		elseif kind == "CarHit" then
			Effects.sparks(pos, normal)
			Sounds.play("Impact", pos, 0.5, 0.9 + math.random() * 0.3)
		elseif kind == "BodyHit" then
			Effects.dust(pos, normal)
		elseif kind == "Explosion" then
			Effects.explosion(pos)
		elseif kind == "Sale" then
			Sounds.play("Cash", pos, 0.9)
		elseif kind == "Build" then
			Sounds.play("Build", nil, 0.7)
		end
	end)
	-- background city sound
	local amb = Sounds.loop("CityAmbience", game:GetService("SoundService"), 0.25)
	local _ = amb
end

return Effects
