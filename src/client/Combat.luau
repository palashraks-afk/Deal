-- Gun controls.
--  * Hip fire: shoots where your mouse points (with some spread).
--  * Right mouse = AIM: over-the-shoulder camera, zoom, crosshair locked to the centre,
--    your character faces where you aim, and shots go exactly to the crosshair.
--    (Sniper aims through a scope.)
--  * R reloads. Recoil kick, muzzle flash, tracers, gun sounds, hit marker, ammo HUD.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Guns = require(Shared.Guns)
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local new = UIKit.new
local C = UIKit.Colors

local Combat = {}
Combat.Aiming = false

local function tracer(from: Vector3, to: Vector3, color: Color3, width: number?)
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(width or 0.1, width or 0.1, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace.CurrentCamera
	TweenService:Create(p, TweenInfo.new(0.07), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.09)
end

local function muzzleFlash(at: Vector3, dir: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 210, 120)
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 0.7
	p.CFrame = CFrame.lookAt(at, at + dir)
	p.Parent = workspace.CurrentCamera
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 200, 120)
	l.Range = 12
	l.Brightness = 5
	l.Parent = p
	TweenService:Create(p, TweenInfo.new(0.05), { Size = Vector3.one * 0.1, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.07)
end

function Combat.start()
	local screen = UIKit.screen()
	local camera = workspace.CurrentCamera
	local state = {} -- [gunId] = { ammo, reloadUntil }
	local firing = false
	local lastFire = 0
	local recoil = 0
	local aimHeld = false

	------------------------------------------------ HUD pieces
	local cross = new("Frame", { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = screen })
	local bars = {}
	for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local b = new("Frame", { Size = UDim2.fromOffset(d[1] == 0 and 2 or 9, d[1] == 0 and 9 or 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 20, Parent = cross }, { UIKit.stroke(Color3.new(0, 0, 0), 1) })
		table.insert(bars, { frame = b, d = d })
	end
	new("Frame", { Size = UDim2.fromOffset(3, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Hot, BorderSizePixel = 0, ZIndex = 21, Parent = cross })
	local hitMark = UIKit.label({ Text = "X", Font = UIKit.FontHeavy, TextSize = 24, TextColor3 = C.Hot, Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 21, Parent = cross })
	local targetInfo = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(260, 18), AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 20, Parent = screen })
	targetInfo.TextStrokeTransparency = 0.3

	local ammoPanel = new("Frame", { Name = "Ammo", Size = UDim2.fromOffset(230, 80), Position = UDim2.new(1, -18, 1, -18), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Panel, Visible = false, ClipsDescendants = true, Parent = screen }, { UIKit.corner(12), UIKit.stroke(C.Hot, 2) })
	local gunName = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 14, TextColor3 = C.Hot, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 6), Parent = ammoPanel })
	local ammoText = UIKit.label({ Text = "0 / 0", Font = UIKit.FontHeavy, TextSize = 30, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(12, 22), Parent = ammoPanel })
	UIKit.label({ Text = "RMB aim • LMB fire • R reload", TextSize = 10, TextColor3 = C.Muted, Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(12, 54), Parent = ammoPanel })
	local reloadBack = new("Frame", { Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 1, -9), BackgroundColor3 = C.Panel3, Parent = ammoPanel }, { UIKit.corner(3) })
	local reloadFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Accent, Parent = reloadBack }, { UIKit.corner(3) })
	local scopeOverlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 15, Parent = screen })
	new("Frame", { Size = UDim2.fromScale(0.85, 0.85), SizeConstraint = Enum.SizeConstraint.RelativeYY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 15, Parent = scopeOverlay }, { UIKit.corner(9999), UIKit.stroke(Color3.new(0, 0, 0), 900) })

	local function equipped(): (Tool?, any)
		local char = player.Character
		if not char then
			return nil
		end
		for _, t in char:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("GunId") then
				return t, Guns.ById[t:GetAttribute("GunId")]
			end
		end
		return nil
	end

	local function gunState(gun)
		local s = state[gun.id]
		if not s then
			s = { ammo = gun.mag, reloadUntil = 0 }
			state[gun.id] = s
		end
		return s
	end

	local function reload(gun)
		local s = gunState(gun)
		if os.clock() < s.reloadUntil or s.ammo == gun.mag then
			return
		end
		s.reloadUntil = os.clock() + gun.reload
		s.ammo = gun.mag
		Net.Fire:FireServer(gun.id, "reload") -- the server tracks the same magazine
		local tool = equipped()
		Sounds.play("Reload", tool and tool:FindFirstChild("Handle"), 0.6)
	end

	-- Where the crosshair is, in VIEWPORT pixels (full window, top bar included).
	-- The ray uses this directly; the GUI draws it shifted up by the top-bar inset.
	local function crossPoint(): Vector2
		if Combat.Aiming then
			return camera.ViewportSize / 2
		end
		return UserInputService:GetMouseLocation()
	end

	-- the world point under the crosshair (ignoring yourself)
	local function aimPoint(): (Vector3, Instance?)
		local sp = crossPoint()
		local ray = camera:ViewportPointToRay(sp.X, sp.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { player.Character, camera }
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local ownCar = hum and hum.SeatPart and hum.SeatPart:FindFirstAncestorWhichIsA("Model")
		if ownCar then
			table.insert(ignore, ownCar)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 1200, params)
		return hit and hit.Position or (ray.Origin + ray.Direction * 1200), hit and hit.Instance
	end

	local function setAim(on: boolean, gun)
		if Combat.Aiming == on then
			return
		end
		Combat.Aiming = on
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.CameraOffset = on and Vector3.new(2.2, 0.6, 0) or Vector3.zero
			hum.AutoRotate = not on
		end
		UserInputService.MouseBehavior = on and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = not on
		local scoped = on and gun and gun.scope
		scopeOverlay.Visible = scoped == true
		TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = scoped and 16 or (on and 52 or 70) }):Play()
	end

	local function shoot(tool: Tool, gun)
		local s = gunState(gun)
		local now = os.clock()
		if now < s.reloadUntil or now - lastFire < gun.fireRate then
			return
		end
		if s.ammo <= 0 then
			reload(gun)
			return
		end
		s.ammo -= 1
		lastFire = now
		local target, hitInst = aimPoint()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		-- turn to face the shot
		if root and not Combat.Aiming then
			local flat = Vector3.new(target.X, root.Position.Y, target.Z)
			if (flat - root.Position).Magnitude > 1 then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
		end
		local handle = tool:FindFirstChild("Handle")
		local muzzle = handle and handle:FindFirstChild("Muzzle")
		local from = muzzle and muzzle.WorldPosition or target
		tracer(from, target, gun.explosive and Color3.fromRGB(255, 160, 60) or Color3.fromRGB(255, 230, 160), gun.explosive and 0.45 or nil)
		muzzleFlash(from, (target - from).Unit)
		local snd = Sounds.Gun[gun.id]
		if snd then
			Sounds.play(snd[1], handle, gun.id == "Sniper" and 1 or 0.7, snd[2] * (0.95 + math.random() * 0.1))
		end
		Net.Fire:FireServer(gun.id, target, Combat.Aiming)
		recoil += math.clamp(gun.damage / 35, 0.2, 2.6) * (Combat.Aiming and 0.6 or 1)
		if s.ammo <= 0 then
			reload(gun)
		end
		if hitInst then
			local model = hitInst:FindFirstAncestorWhichIsA("Model")
			if (model and model:FindFirstChildOfClass("Humanoid")) or hitInst:FindFirstAncestor("Vehicles") then
				hitMark.TextTransparency = 0
				TweenService:Create(hitMark, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		local tool, gun = equipped()
		if not tool then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimHeld = true
			setAim(true, gun)
		elseif input.KeyCode == Enum.KeyCode.R and not processed then
			reload(gun)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			aimHeld = false
			setAim(false)
		end
	end)

	local hooked = setmetatable({}, { __mode = "k" })
	local function hook(tool: Tool)
		if hooked[tool] or not tool:GetAttribute("GunId") then
			return
		end
		hooked[tool] = true
		tool.Activated:Connect(function()
			firing = true
			local gun = Guns.ById[tool:GetAttribute("GunId")]
			if gun and not gun.auto then
				shoot(tool, gun)
				firing = false
			end
		end)
		tool.Deactivated:Connect(function()
			firing = false
		end)
		tool.Equipped:Connect(function()
			if aimHeld then
				setAim(true, Guns.ById[tool:GetAttribute("GunId")])
			end
		end)
		tool.Unequipped:Connect(function()
			firing = false
			setAim(false)
		end)
	end
	local function watch(container)
		for _, c in container:GetChildren() do
			if c:IsA("Tool") then
				hook(c)
			end
		end
		container.ChildAdded:Connect(function(c)
			if c:IsA("Tool") then
				hook(c)
			end
		end)
	end
	local function onChar(char)
		setAim(false)
		watch(char)
		watch(player:WaitForChild("Backpack"))
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		onChar(player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		local tool, gun = equipped()
		cross.Visible = tool ~= nil and not scopeOverlay.Visible
		ammoPanel.Visible = tool ~= nil
		targetInfo.Visible = false
		if not tool then
			if Combat.Aiming then
				setAim(false)
			end
			return
		end
		local scale = UIKit.scale()
		local sp = crossPoint() - Vector2.new(0, GuiService:GetGuiInset().Y)
		local px, py = sp.X / scale, sp.Y / scale
		cross.Position = UDim2.fromOffset(px, py)
		local spreadPx = (Combat.Aiming and 5 or 10) + recoil * 6
		for _, b in bars do
			b.frame.Position = UDim2.new(0.5, b.d[1] * spreadPx, 0.5, b.d[2] * spreadPx)
		end
		targetInfo.Position = UDim2.fromOffset(px, py + 22)

		-- face where you aim
		if Combat.Aiming then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local look = camera.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude > 0.1 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
				end
			end
		end

		local s = gunState(gun)
		gunName.Text = string.upper(gun.name)
		local reloading = os.clock() < s.reloadUntil
		ammoText.Text = reloading and "RELOADING" or ("%d / %d"):format(s.ammo, gun.mag)
		ammoText.TextColor3 = reloading and C.Accent or (s.ammo <= math.ceil(gun.mag * 0.25) and C.Hot or C.Text)
		reloadFill.Size = UDim2.fromScale(reloading and (1 - (s.reloadUntil - os.clock()) / gun.reload) or s.ammo / gun.mag, 1)

		-- what's under the crosshair
		local _, inst = aimPoint()
		local node = inst
		while node and node.Parent and node.Parent ~= workspace and node.Parent.Name ~= "Vehicles" do
			node = node.Parent
		end
		if node and node.Parent and node.Parent.Name == "Vehicles" and node:GetAttribute("MaxHealth") then
			targetInfo.Visible = true
			targetInfo.Text = ("%s   %d/%d"):format(node:GetAttribute("CarName") or "", node:GetAttribute("Health") or 0, node:GetAttribute("MaxHealth"))
			local r = node:GetAttribute("Rarity")
			targetInfo.TextColor3 = r and Config.Rarity[r] and Config.Rarity[r].color or Color3.new(1, 1, 1)
		end

		if firing and gun.auto then
			shoot(tool, gun)
		end
		recoil = math.max(0, recoil - dt * 9)
	end)

	-- Two-handed aim pose (R15): the default tool pose sticks one arm straight out and
	-- never aims. Each frame, right after the Animator has posed the body
	-- (PreSimulation), we add on top of the animation: the right arm follows the
	-- camera's pitch and the left arm comes forward to support the gun.
	local poseBlend = 0
	local lastSet = setmetatable({}, { __mode = "k" }) -- what we wrote last frame
	local lastAnim = setmetatable({}, { __mode = "k" }) -- the animation's own value
	-- Newer avatars drive joints with AnimationConstraints instead of Motor6Ds; both
	-- have a Transform the Animator writes each frame, so either works here.
	local function motor(char, partName, jointName): any
		local part = char:FindFirstChild(partName)
		local m = part and part:FindFirstChild(jointName)
		if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then
			return m
		end
		return nil
	end
	local function addRotation(m: any, rot: CFrame)
		local anim = m.Transform
		-- if the Animator didn't touch this joint since our last write, reuse its old
		-- value instead of stacking our rotation on top of our own rotation
		local prev = lastSet[m]
		if prev and (anim.Position - prev.Position).Magnitude < 1e-4 and anim.LookVector:Dot(prev.LookVector) > 0.99999 and anim.UpVector:Dot(prev.UpVector) > 0.99999 then
			anim = lastAnim[m] or CFrame.identity
		end
		lastAnim[m] = anim
		local out = rot * anim
		m.Transform = out
		lastSet[m] = out
	end
	RunService.PreSimulation:Connect(function(dt)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
			return
		end
		local tool = equipped()
		local want = (tool and not hum.Sit and hum.Health > 0) and 1 or 0
		poseBlend += (want - poseBlend) * math.clamp(dt * 14, 0, 1)
		if poseBlend < 0.01 then
			return
		end
		local right = motor(char, "RightUpperArm", "RightShoulder")
		local left = motor(char, "LeftUpperArm", "LeftShoulder")
		local waist = motor(char, "UpperTorso", "Waist")
		if not right or not left then
			return
		end
		local pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -0.95, 0.95))
		local kick = math.rad(recoil * 4) -- arms ride up with the recoil
		-- right arm: the tool pose already points it forward, so only add the aim pitch
		addRotation(right, CFrame.Angles((pitch * 0.85 + kick) * poseBlend, 0, 0))
		-- left arm: from hanging down to forward and across to the gun's front grip
		addRotation(left, CFrame.Angles(0, -0.55 * poseBlend, 0) * CFrame.Angles((math.rad(85) + pitch * 0.85 + kick) * poseBlend, 0, 0))
		-- lean the upper body a little into the aim
		if waist then
			addRotation(waist, CFrame.Angles(pitch * 0.25 * poseBlend, 0, 0))
		end
	end)
	player.CharacterAdded:Connect(function()
		poseBlend = 0
	end)

	-- Recoil: a temporary kick applied AFTER Roblox's camera each frame, so it never
	-- accumulates or drags your aim upward.
	RunService:BindToRenderStep("GunRecoil", Enum.RenderPriority.Camera.Value + 1, function()
		if recoil > 0.01 then
			camera.CFrame *= CFrame.Angles(math.rad(recoil * 0.9), math.rad(math.sin(os.clock() * 40) * recoil * 0.15), 0)
		end
	end)

	Net.Tracer.OnClientEvent:Connect(function(shooter, gunId, from, hits)
		if shooter == player then
			return
		end
		local gun = Guns.ById[gunId]
		for _, hit in hits do
			tracer(from, hit, Color3.fromRGB(255, 120, 90), gun and gun.explosive and 0.45 or nil)
		end
		muzzleFlash(from, ((hits[1] or from) - from).Unit)
		local snd = Sounds.Gun[gunId]
		if snd then
			Sounds.play(snd[1], from, 0.8, snd[2])
		end
	end)
end

return Combat
