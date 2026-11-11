-- Client side of guns: aim at the mouse/tap, fire (auto or semi), ammo + reload (R),
-- recoil kick, muzzle flash, tracers, hit marker, sniper scope (right mouse), ammo HUD.
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

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local new = UIKit.new
local C = UIKit.Colors

local Combat = {}

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
	p.Size = Vector3.new(width or 0.12, width or 0.12, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.08), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.1)
	local spark = Instance.new("Part")
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CastShadow = false
	spark.Shape = Enum.PartType.Ball
	spark.Material = Enum.Material.Neon
	spark.Color = Color3.fromRGB(255, 220, 140)
	spark.Size = Vector3.one * 0.7
	spark.Position = to
	spark.Parent = workspace
	TweenService:Create(spark, TweenInfo.new(0.12), { Size = Vector3.one * 0.1, Transparency = 1 }):Play()
	Debris:AddItem(spark, 0.15)
end

function Combat.start()
	local screen = UIKit.screen()
	local state = {} -- [gunId] = { ammo, reloadUntil }
	local firing = false
	local lastFire = 0
	local recoil = 0
	local scoped = false

	------------------------------------------------ HUD pieces
	local cross = new("Frame", { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = screen })
	for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		new("Frame", { Size = UDim2.fromOffset(d[1] == 0 and 2 or 8, d[1] == 0 and 8 or 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, d[1] * 9, 0.5, d[2] * 9), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 20, Parent = cross }, { UIKit.stroke(Color3.new(0, 0, 0), 1) })
	end
	local hitMark = UIKit.label({ Text = "✕", Font = UIKit.FontHeavy, TextSize = 26, TextColor3 = C.Hot, Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0.5, 0.5), TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 21, Parent = cross })
	hitMark.Position = UDim2.fromScale(0.5, 0.5)
	local targetInfo = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(260, 18), AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 20, Parent = screen })
	targetInfo.TextStrokeTransparency = 0.3

	local ammoPanel = new("Frame", { Name = "Ammo", Size = UDim2.fromOffset(220, 74), Position = UDim2.new(1, -18, 1, -18), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Panel, Visible = false, ClipsDescendants = true, Parent = screen }, { UIKit.corner(12), UIKit.stroke(C.Hot, 2) })
	local gunName = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 14, TextColor3 = C.Hot, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 6), Parent = ammoPanel })
	local ammoText = UIKit.label({ Text = "0 / 0", Font = UIKit.FontHeavy, TextSize = 32, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(12, 24), Parent = ammoPanel })
	local reloadBack = new("Frame", { Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 1, -12), BackgroundColor3 = C.Panel3, Parent = ammoPanel }, { UIKit.corner(3) })
	local reloadFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Accent, Parent = reloadBack }, { UIKit.corner(3) })
	local scopeOverlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 15, Parent = screen })
	local ring = new("Frame", { Size = UDim2.fromScale(0.8, 0.8), SizeConstraint = Enum.SizeConstraint.RelativeYY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 15, Parent = scopeOverlay }, { UIKit.corner(9999), UIKit.stroke(Color3.new(0, 0, 0), 60) })
	local _ = ring

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
	end

	local function setScope(on: boolean)
		scoped = on
		scopeOverlay.Visible = on
		local cam = workspace.CurrentCamera
		TweenService:Create(cam, TweenInfo.new(0.15), { FieldOfView = on and 18 or 70 }):Play()
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
		local target = mouse.Hit.Position
		local handle = tool:FindFirstChild("Handle")
		local muzzle = handle and handle:FindFirstChild("Muzzle")
		local from = muzzle and muzzle.WorldPosition or target
		tracer(from, target, gun.explosive and Color3.fromRGB(255, 160, 60) or Color3.fromRGB(255, 230, 160), gun.explosive and 0.5 or nil)
		Net.Fire:FireServer(gun.id, target)
		-- recoil kick
		recoil += math.clamp(gun.damage / 40, 0.15, 2.2)
		if s.ammo <= 0 then
			reload(gun)
		end
		-- did we hit something worth a marker?
		local t = mouse.Target
		if t and (t:FindFirstAncestorWhichIsA("Model") and t:FindFirstAncestorWhichIsA("Model"):FindFirstChildOfClass("Humanoid")) or (t and t:FindFirstAncestor("Vehicles")) then
			hitMark.TextTransparency = 0
			TweenService:Create(hitMark, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		local tool, gun = equipped()
		if not tool then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 and gun.scope then
			setScope(true)
		elseif input.KeyCode == Enum.KeyCode.R and not processed then
			reload(gun)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and scoped then
			setScope(false)
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
		tool.Unequipped:Connect(function()
			firing = false
			if scoped then
				setScope(false)
			end
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
		watch(char)
		watch(player:WaitForChild("Backpack"))
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		onChar(player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		local tool, gun = equipped()
		cross.Visible = tool ~= nil
		ammoPanel.Visible = tool ~= nil
		targetInfo.Visible = false
		if not tool then
			return
		end
		local pos = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		local scale = UIKit.scale()
		local px, py = (pos.X - inset.X) / scale, (pos.Y - inset.Y) / scale
		cross.Position = UDim2.fromOffset(px, py)
		local spreadPx = 9 + recoil * 6
		for _, bar in cross:GetChildren() do
			if bar:IsA("Frame") then
				local dx = bar.Position.X.Offset ~= 0 and math.sign(bar.Position.X.Offset) or 0
				local dy = bar.Position.Y.Offset ~= 0 and math.sign(bar.Position.Y.Offset) or 0
				bar.Position = UDim2.new(0.5, dx * spreadPx, 0.5, dy * spreadPx)
			end
		end
		targetInfo.Position = UDim2.fromOffset(px, py + 22)

		local s = gunState(gun)
		gunName.Text = string.upper(gun.name)
		local reloading = os.clock() < s.reloadUntil
		ammoText.Text = reloading and "RELOADING" or ("%d / %d"):format(s.ammo, gun.mag)
		ammoText.TextColor3 = reloading and C.Accent or (s.ammo <= math.ceil(gun.mag * 0.25) and C.Hot or C.Text)
		reloadFill.Size = UDim2.fromScale(reloading and (1 - (s.reloadUntil - os.clock()) / gun.reload) or s.ammo / gun.mag, 1)

		-- car under the crosshair: show its health
		local node = mouse.Target
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
		-- recoil: kick the camera up a little, then settle
		if recoil > 0 then
			local kick = recoil * dt * 6
			workspace.CurrentCamera.CFrame *= CFrame.Angles(math.rad(kick), 0, 0)
			recoil = math.max(0, recoil - dt * 8)
		end
	end)

	Net.Tracer.OnClientEvent:Connect(function(shooter, gunId, from, hits)
		if shooter == player then
			return
		end
		local gun = Guns.ById[gunId]
		for _, hit in hits do
			tracer(from, hit, Color3.fromRGB(255, 120, 90), gun and gun.explosive and 0.5 or nil)
		end
	end)
end

return Combat
