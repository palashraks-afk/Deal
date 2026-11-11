-- Builds a car model from its stats, scaled to the real car's length, width and height.
-- Car space: forward = -Z, wheels touch y = 0. The root part is "Chassis".
--
-- CarBuilder.build(stats, paintColor, { drivable = bool }) -> Model

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(script.Parent.Config)

local CarBuilder = {}

local S = Config.StudsPerMeter

-- Per body type:
-- r = wheel radius (m), clr = ground clearance (m), belt = beltline fraction of the height above clearance,
-- cab0/cab1 = cabin start/end as fraction of length, rakeF/rakeR = windscreen / rear glass share of cabin length,
-- nose = sloped nose length fraction, axleF/axleR = axle positions as fraction of length from centre.
local PROFILES = {
	hatch = { r = 0.31, clr = 0.14, belt = 0.5, cab0 = 0.30, cab1 = 0.94, rakeF = 0.26, rakeR = 0.08, nose = 0.05, axleF = 0.32, axleR = 0.33 },
	sedan = { r = 0.33, clr = 0.14, belt = 0.5, cab0 = 0.32, cab1 = 0.78, rakeF = 0.28, rakeR = 0.25, nose = 0.06, axleF = 0.31, axleR = 0.30 },
	wagon = { r = 0.33, clr = 0.15, belt = 0.5, cab0 = 0.30, cab1 = 0.96, rakeF = 0.25, rakeR = 0.05, nose = 0.05, axleF = 0.31, axleR = 0.31 },
	coupe = { r = 0.34, clr = 0.12, belt = 0.53, cab0 = 0.36, cab1 = 0.80, rakeF = 0.36, rakeR = 0.36, nose = 0.08, axleF = 0.32, axleR = 0.30 },
	muscle = { r = 0.35, clr = 0.13, belt = 0.55, cab0 = 0.40, cab1 = 0.80, rakeF = 0.32, rakeR = 0.34, nose = 0.04, axleF = 0.31, axleR = 0.30 },
	sports = { r = 0.33, clr = 0.11, belt = 0.55, cab0 = 0.38, cab1 = 0.82, rakeF = 0.40, rakeR = 0.38, nose = 0.13, axleF = 0.32, axleR = 0.30 },
	super = { r = 0.34, clr = 0.10, belt = 0.60, cab0 = 0.34, cab1 = 0.74, rakeF = 0.44, rakeR = 0.34, nose = 0.18, axleF = 0.31, axleR = 0.30 },
	hyper = { r = 0.35, clr = 0.09, belt = 0.62, cab0 = 0.33, cab1 = 0.71, rakeF = 0.46, rakeR = 0.34, nose = 0.20, axleF = 0.31, axleR = 0.31 },
	classic = { r = 0.32, clr = 0.15, belt = 0.52, cab0 = 0.38, cab1 = 0.78, rakeF = 0.26, rakeR = 0.26, nose = 0.06, axleF = 0.32, axleR = 0.31 },
	suv = { r = 0.38, clr = 0.20, belt = 0.50, cab0 = 0.26, cab1 = 0.96, rakeF = 0.18, rakeR = 0.06, nose = 0.03, axleF = 0.32, axleR = 0.31 },
	offroad = { r = 0.42, clr = 0.26, belt = 0.50, cab0 = 0.25, cab1 = 0.96, rakeF = 0.10, rakeR = 0.03, nose = 0.0, axleF = 0.31, axleR = 0.31 },
	truck = { r = 0.40, clr = 0.23, belt = 0.52, cab0 = 0.24, cab1 = 0.54, rakeF = 0.16, rakeR = 0.04, nose = 0.0, axleF = 0.34, axleR = 0.27, bed = true },
	van = { r = 0.36, clr = 0.17, belt = 0.42, cab0 = 0.08, cab1 = 0.98, rakeF = 0.10, rakeR = 0.02, nose = 0.0, axleF = 0.33, axleR = 0.30 },
}

local SPOILER_BODIES = { super = true, hyper = true }
local SPOILER_TRIMS = { "Track Edition", "Widebody", "Drag Spec", "Rally Spec", "Drift Spec" }

local GLASS = Color3.fromRGB(18, 24, 34)
local TRIM = Color3.fromRGB(22, 22, 24)
local CHROME = Color3.fromRGB(205, 208, 212)

local function part(model, root, name, size, cf, props)
	local p = Instance.new(props and props.wedge and "WedgePart" or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	if props then
		for k, v in props do
			if k ~= "wedge" then
				p[k] = v
			end
		end
	end
	p.Parent = model
	if root and root ~= p then
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	return p
end

local function hasSpoiler(stats)
	if SPOILER_BODIES[stats.body] then
		return true
	end
	for _, t in SPOILER_TRIMS do
		if string.find(stats.model or "", t, 1, true) then
			return true
		end
	end
	return false
end

-- AI-generated textured models live in ServerStorage.Assets.Cars as "Car_<id>"
-- (a body MeshPart + four wheel MeshParts named "...front left wheel..." etc).
local function findTemplate(stats)
	if not RunService:IsServer() or not stats.id then
		return nil
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Cars")
	return folder and folder:FindFirstChild("Car_" .. stats.id)
end

local WHEEL_KEYS = { { "front left", "FL" }, { "front right", "FR" }, { "rear left", "RL" }, { "rear right", "RR" } }

local function buildFromTemplate(template: Model, stats, opts)
	local P = PROFILES[stats.body] or PROFILES.sedan
	local L, W, H = stats.length * S, stats.width * S, stats.height * S
	local src = template:Clone()
	local bbCf, size = src:GetBoundingBox()
	-- stretch to the real car's length/width/height
	local f = Vector3.new(W / size.X, H / size.Y, L / size.Z)
	local origin = Vector3.new(bbCf.Position.X, bbCf.Position.Y - size.Y / 2, bbCf.Position.Z)

	local model = Instance.new("Model")
	model.Name = stats.name or stats.model
	local root = part(model, nil, "Chassis", Vector3.new(W * 0.9, H * 0.3, L * 0.9), CFrame.new(0, H * 0.32, 0), {
		Transparency = 1,
		Massless = false,
		CanCollide = opts.drivable == true,
		CustomPhysicalProperties = PhysicalProperties.new(2.4, 0.3, 0, 1, 1),
	})
	model.PrimaryPart = root

	local wheelR = P.r * S
	for _, d in src:GetDescendants() do
		if d:IsA("MeshPart") then
			local lname = string.lower(d.Name)
			local wheelKey
			for _, k in WHEEL_KEYS do
				if string.find(lname, k[1], 1, true) then
					wheelKey = k[2]
				end
			end
			local rel = (d.Position - origin) * f
			if wheelKey then
				-- keep wheels round: scale Y/Z equally
				local s = (f.Y + f.Z) / 2
				d.Size = Vector3.new(d.Size.X * f.X, d.Size.Y * s, d.Size.Z * s)
				wheelR = math.max(d.Size.Y, d.Size.Z) / 2
			else
				d.Size = d.Size * f
			end
			d.CFrame = CFrame.new(rel) * d.CFrame.Rotation
			d.Anchored = true
			d.CanTouch = false
			d.CanQuery = true
			d.Massless = true
			-- (CollisionFidelity = Box is set on the templates in Studio; it can't be set at runtime)
			if wheelKey then
				d.Name = "Wheel" .. wheelKey
				d.CanCollide = opts.drivable == true
				d.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
				d.Parent = model
				local weld = Instance.new("Weld")
				weld.Name = "Axle"
				weld.Part0 = root
				weld.Part1 = d
				weld.C0 = root.CFrame:Inverse() * d.CFrame
				weld.Parent = d
				d:SetAttribute("BaseC0", weld.C0)
			else
				d.Name = "Body"
				d.CanCollide = false
				d.Parent = model
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	src:Destroy()

	-- lights (the mesh already has painted lamps; these just glow at night)
	for _, sx in { -1, 1 } do
		local head = part(model, root, "Headlight", Vector3.new(0.3, 0.3, 0.1), CFrame.new(sx * W * 0.32, H * 0.42, -L / 2 + 0.2), { Transparency = 1 })
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 45
		spot.Angle = 70
		spot.Brightness = 2.5
		spot.Color = Color3.fromRGB(255, 244, 220)
		spot.Parent = head
		local tail = part(model, root, "Taillight", Vector3.new(0.3, 0.3, 0.1), CFrame.new(sx * W * 0.32, H * 0.5, L / 2 - 0.2), { Transparency = 1 })
		local glow = Instance.new("PointLight")
		glow.Range = 7
		glow.Brightness = 0.8
		glow.Color = Color3.fromRGB(255, 30, 30)
		glow.Parent = tail
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(0.5 * S, 0.12 * S, 0.5 * S)
	-- low seat so the driver's head stays under the roof
	seat.CFrame = CFrame.new(-W * 0.2, H * 0.2, -L / 2 + (P.cab0 + 0.14) * L + 0.4 * S)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.Anchored = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.Disabled = not opts.drivable
	seat.Parent = model
	local sw = Instance.new("WeldConstraint")
	sw.Part0 = root
	sw.Part1 = seat
	sw.Parent = seat

	model:SetAttribute("Length", L)
	model:SetAttribute("Width", W)
	model:SetAttribute("Height", H)
	model:SetAttribute("WheelRadius", wheelR)
	model:SetAttribute("Rarity", stats.rarity)
	model:SetAttribute("Mesh", true)
	return model
end

function CarBuilder.hasModel(stats): boolean
	return findTemplate(stats) ~= nil
end

function CarBuilder.build(stats, paint: Color3, opts)
	opts = opts or {}
	local template = findTemplate(stats)
	if template then
		return buildFromTemplate(template, stats, opts)
	end
	local P = PROFILES[stats.body] or PROFILES.sedan
	local L, W, H = stats.length * S, stats.width * S, stats.height * S
	local R = P.r * S
	local clr = P.clr * S
	local beltY = clr + (H - clr) * P.belt
	local lh = beltY - clr
	local ch = H - beltY
	local isGold = stats.rarity == "Legendary"
	local isPremium = stats.rarity == "Mythic" or isGold

	local model = Instance.new("Model")
	model.Name = stats.name or (stats.brand .. " " .. stats.model)

	-- Root: invisible, heavy, low -> stable centre of mass.
	local root = part(model, nil, "Chassis", Vector3.new(W * 0.9, lh * 0.6, L * 0.9), CFrame.new(0, clr + lh * 0.35, 0), {
		Transparency = 1,
		Massless = false,
		CustomPhysicalProperties = PhysicalProperties.new(2.4, 0.3, 0, 1, 1),
	})
	model.PrimaryPart = root

	local paintProps = {
		Color = paint,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.12,
	}
	local function paintPart(name, size, cf, extra)
		local props = table.clone(paintProps)
		if extra then
			for k, v in extra do
				props[k] = v
			end
		end
		return part(model, root, name, size, cf, props)
	end

	local meshBody = false
	if stats.meshId and stats.meshId ~= "" then
		-- Real mesh hook: drop a mesh id into the car data and it replaces the block body.
		local ok, mesh = pcall(function()
			return AssetService:CreateMeshPartAsync(stats.meshId)
		end)
		if ok and mesh then
			mesh.Name = "Body"
			mesh.Size = Vector3.new(W, H - clr * 0.5, L)
			mesh.CFrame = CFrame.new(0, clr * 0.5 + (H - clr * 0.5) / 2, 0)
			mesh.Color = paint
			mesh.Anchored = true
			mesh.Massless = true
			mesh.CanCollide = false
			mesh.Parent = model
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = mesh
			w.Parent = mesh
			meshBody = true
		end
	end

	local noseLen = L * P.nose
	local front = -L / 2

	if not meshBody then
		-- Lower body (collides, so cars bump into each other)
		local bodyLen = L - noseLen
		paintPart("LowerBody", Vector3.new(W, lh, bodyLen), CFrame.new(0, clr + lh / 2, front + noseLen + bodyLen / 2), {
			CanCollide = opts.drivable == true,
		})
		if noseLen > 0.05 then
			local baseH = lh * 0.45
			paintPart("NoseBase", Vector3.new(W, baseH, noseLen), CFrame.new(0, clr + baseH / 2, front + noseLen / 2))
			-- wedge slope falls toward -Z (front)
			paintPart(
				"NoseSlope",
				Vector3.new(W, lh - baseH, noseLen),
				CFrame.new(0, clr + baseH + (lh - baseH) / 2, front + noseLen / 2),
				{ wedge = true }
			)
		end

		-- Black lower trim / side skirts
		part(model, root, "Skirt", Vector3.new(W * 1.01, lh * 0.16, L * 0.98), CFrame.new(0, clr + lh * 0.08, 0), {
			Color = TRIM,
		})

		-- Cabin
		local z0 = front + P.cab0 * L
		local z1 = front + P.cab1 * L
		local cabLen = z1 - z0
		local cw = W * 0.86
		local fLen = cabLen * P.rakeF
		local rLen = cabLen * P.rakeR
		local midLen = cabLen - fLen - rLen
		local glassProps = { Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.25 }
		if fLen > 0.1 then
			local g = table.clone(glassProps)
			g.wedge = true
			part(model, root, "Windshield", Vector3.new(cw, ch, fLen), CFrame.new(0, beltY + ch / 2, z0 + fLen / 2), g)
		end
		if rLen > 0.1 then
			local g = table.clone(glassProps)
			g.wedge = true
			part(
				model,
				root,
				"RearGlass",
				Vector3.new(cw, ch, rLen),
				CFrame.new(0, beltY + ch / 2, z1 - rLen / 2) * CFrame.Angles(0, math.pi, 0),
				g
			)
		end
		local midZ = z0 + fLen + midLen / 2
		part(model, root, "SideGlass", Vector3.new(cw, ch * 0.9, midLen), CFrame.new(0, beltY + ch * 0.45, midZ), glassProps)
		paintPart("Roof", Vector3.new(cw * 1.01, ch * 0.1, midLen), CFrame.new(0, beltY + ch * 0.95, midZ))
		-- pillars
		for _, z in { z0 + fLen, midZ, z0 + fLen + midLen } do
			paintPart("Pillar", Vector3.new(cw * 1.02, ch * 0.9, 0.12 * S), CFrame.new(0, beltY + ch * 0.45, z))
		end
		-- mirrors
		for _, sx in { -1, 1 } do
			paintPart("Mirror", Vector3.new(0.12 * S, 0.1 * S, 0.06 * S), CFrame.new(sx * (W / 2 + 0.05 * S), beltY + 0.05 * S, z0 + fLen * 0.6))
		end

		-- Truck bed walls
		if P.bed then
			local bedLen = L / 2 - z1 - 0.05 * S
			local wallH = ch * 0.42
			for _, sx in { -1, 1 } do
				paintPart("BedWall", Vector3.new(0.08 * S, wallH, bedLen), CFrame.new(sx * (W / 2 - 0.04 * S), beltY + wallH / 2, z1 + bedLen / 2 + 0.05 * S))
			end
			paintPart("Tailgate", Vector3.new(W, wallH, 0.08 * S), CFrame.new(0, beltY + wallH / 2, L / 2 - 0.04 * S))
			part(model, root, "BedLiner", Vector3.new(W * 0.9, 0.04 * S, bedLen), CFrame.new(0, beltY + 0.02 * S, z1 + bedLen / 2 + 0.05 * S), {
				Color = TRIM,
			})
		end

		-- Spoiler
		if hasSpoiler(stats) then
			local wingY = beltY + 0.32 * S
			local wingZ = L / 2 - 0.3 * S
			for _, sx in { -0.3, 0.3 } do
				part(model, root, "WingPost", Vector3.new(0.06 * S, 0.32 * S, 0.12 * S), CFrame.new(sx * W, beltY + 0.16 * S, wingZ), { Color = TRIM })
			end
			part(model, root, "Wing", Vector3.new(W * 0.92, 0.05 * S, 0.32 * S), CFrame.new(0, wingY, wingZ), {
				Color = isGold and Color3.fromRGB(230, 180, 40) or TRIM,
				Material = isGold and Enum.Material.Metal or Enum.Material.SmoothPlastic,
			})
		end
	end

	-- Bumpers, grille, lights (also used with mesh bodies)
	part(model, root, "FrontBumper", Vector3.new(W * 1.0, lh * 0.35, 0.14 * S), CFrame.new(0, clr + lh * 0.2, front - 0.02 * S), { Color = TRIM })
	part(model, root, "RearBumper", Vector3.new(W * 1.0, lh * 0.35, 0.14 * S), CFrame.new(0, clr + lh * 0.2, L / 2 + 0.02 * S), { Color = TRIM })
	part(model, root, "Grille", Vector3.new(W * 0.45, lh * 0.25, 0.04 * S), CFrame.new(0, clr + lh * 0.5, front - 0.04 * S), {
		Color = isPremium and CHROME or TRIM,
		Material = isPremium and Enum.Material.Metal or Enum.Material.SmoothPlastic,
	})

	local lightY = noseLen > 0.05 and (clr + lh * 0.5) or (clr + lh * 0.75)
	for _, sx in { -1, 1 } do
		local head = part(model, root, "Headlight", Vector3.new(W * 0.2, lh * 0.16, 0.06 * S), CFrame.new(sx * W * 0.34, lightY, front - 0.03 * S), {
			Color = Color3.fromRGB(240, 245, 255),
			Material = Enum.Material.Neon,
		})
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 45
		spot.Angle = 70
		spot.Brightness = 2.5
		spot.Color = Color3.fromRGB(255, 244, 220)
		spot.Parent = head

		local tail = part(model, root, "Taillight", Vector3.new(W * 0.22, lh * 0.14, 0.06 * S), CFrame.new(sx * W * 0.34, clr + lh * 0.75, L / 2 + 0.03 * S), {
			Color = Color3.fromRGB(255, 20, 30),
			Material = Enum.Material.Neon,
		})
		local glow = Instance.new("PointLight")
		glow.Range = 8
		glow.Brightness = 1
		glow.Color = Color3.fromRGB(255, 30, 30)
		glow.Parent = tail

		part(model, root, "Exhaust", Vector3.new(0.3 * S, 0.1 * S, 0.1 * S), CFrame.new(sx * W * 0.22, clr + 0.05 * S, L / 2 + 0.05 * S) * CFrame.Angles(0, math.pi / 2, 0), {
			Shape = Enum.PartType.Cylinder,
			Color = CHROME,
			Material = Enum.Material.Metal,
		})
	end

	-- Wheels: tyre (collides, zero friction - the drive script handles grip) + rim
	local wheelW = (0.22 + stats.width * 0.04) * S
	local tyreProps = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	local wheels = {}
	local rimColor = isGold and Color3.fromRGB(230, 180, 40) or (isPremium and Color3.fromRGB(40, 40, 44) or CHROME)
	for _, def in {
		{ "FL", -1, -P.axleF },
		{ "FR", 1, -P.axleF },
		{ "RL", -1, P.axleR },
		{ "RR", 1, P.axleR },
	} do
		local name, sx, zf = def[1], def[2], def[3]
		local cf = CFrame.new(sx * (W / 2 - wheelW / 2 + 0.06 * S), R, zf * L)
		local tyre = part(model, nil, "Wheel" .. name, Vector3.new(wheelW, R * 2, R * 2), cf, {
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(24, 24, 26),
			CanCollide = opts.drivable == true,
			CustomPhysicalProperties = tyreProps,
		})
		-- Weld (not WeldConstraint) so the client can spin/steer it via C0.
		local weld = Instance.new("Weld")
		weld.Name = "Axle"
		weld.Part0 = root
		weld.Part1 = tyre
		weld.C0 = root.CFrame:Inverse() * cf
		weld.Parent = tyre
		tyre:SetAttribute("BaseC0", weld.C0)

		local rim = part(model, nil, "Rim", Vector3.new(wheelW * 1.04, R * 1.25, R * 1.25), cf, {
			Shape = Enum.PartType.Cylinder,
			Color = rimColor,
			Material = Enum.Material.Metal,
			Reflectance = 0.3,
		})
		local rw = Instance.new("WeldConstraint")
		rw.Part0 = tyre
		rw.Part1 = rim
		rw.Parent = rim
		table.insert(wheels, tyre)
	end

	-- Driver seat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(0.5 * S, 0.12 * S, 0.5 * S)
	seat.CFrame = CFrame.new(-W * 0.2, clr + lh * 0.55, front + (P.cab0 + 0.12) * L + 0.4 * S)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.Anchored = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.Disabled = not opts.drivable
	seat.Parent = model
	local sw = Instance.new("WeldConstraint")
	sw.Part0 = root
	sw.Part1 = seat
	sw.Parent = seat

	model:SetAttribute("Length", L)
	model:SetAttribute("Width", W)
	model:SetAttribute("Height", H)
	model:SetAttribute("WheelRadius", R)
	model:SetAttribute("Rarity", stats.rarity)
	return model
end

-- Unanchor every part so physics takes over.
function CarBuilder.release(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

function CarBuilder.anchor(model: Model, anchored: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

return CarBuilder
