-- Builds the whole map at server start. Six areas around Dealz Boulevard (z = 0):
--
--     SUBURBS  |  DOWNTOWN  |  PORT          (north, z < 0)
--   ================ DEALZ BOULEVARD ================
--      HILLS   |   BEACH    |  DESERT        (south, z > 0)
--
-- Each area has its own ground, roads, buildings and props, plus one dealership plot
-- placed inside it (PLOT_SPOTS) facing that area's road. Nothing else builds there. Parts with a "MapColor" attribute are drawn on the minimap.
local Lighting = game:GetService("Lighting")

local PlotBuilder = require(script.Parent.PlotBuilder)

local WorldBuilder = {}

local HALF_X, HALF_Z = 2000, 1400
local ROAD_W = 34
local AVENUE_X = { -650, 650 } -- the two north-south avenues between areas

WorldBuilder.PlotCount = 6
WorldBuilder.Plots = {}
WorldBuilder.SpawnPoints = {} -- CFrames where city finds can appear
WorldBuilder.Zones = {}
WorldBuilder.Landmarks = {} -- name -> Vector3 (tutorial waypoints)
WorldBuilder.PedestrianPaths = {} -- arrays of Vector3 sidewalk points
WorldBuilder.MaxSlots = PlotBuilder.DisplayPads + PlotBuilder.SpecialPads

local rng = Random.new(20261111)

---------------------------------------------------------------- helpers
local function make(className, props, parent)
	local p = Instance.new(className)
	for k, v in props do
		p[k] = v
	end
	if p:IsA("BasePart") then
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
	end
	p.Parent = parent
	return p
end

local MaterialService = game:GetService("MaterialService")
local function variant(part: BasePart, name: string)
	-- use an AI-generated MaterialVariant if this place has it
	local v = MaterialService:FindFirstChild(name, true)
	if v and v:IsA("MaterialVariant") then
		part.Material = v.BaseMaterial
		part.MaterialVariant = name
		-- part colour tints the texture; keep it near-white so the real facade shows
		local c = part.Color
		part.Color = Color3.new(0.82 + c.R * 0.18, 0.82 + c.G * 0.18, 0.82 + c.B * 0.18)
	end
end

-- Real props (Creator Store models, scripts stripped) live in ServerStorage.Assets.Props.
-- prop("Palm", position, scale) drops one with its base on the ground and a random turn.
local ServerStorage = game:GetService("ServerStorage")
local function propTemplate(name: string)
	local assets = ServerStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	return props and props:FindFirstChild(name)
end
local function prop(parent, name: string, pos: Vector3, scale: number?, yaw: number?): Model?
	local t = propTemplate(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale and scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	local bb, size = m:GetBoundingBox()
	local offset = m:GetPivot().Position - bb.Position
	m:PivotTo(CFrame.new(pos + offset + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw or rng:NextNumber(0, math.pi * 2), 0))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.Parent = parent
	return m
end
WorldBuilder.prop = prop

-- One pine from the pine pack (the pack is a model of several trees).
local function pine(parent, pos: Vector3, scale: number?)
	local pack = propTemplate("Trees2")
	if not pack then
		return
	end
	local kids = pack:GetChildren()
	local one = kids[rng:NextInteger(1, #kids)]:Clone()
	local holder = Instance.new("Model")
	one.Parent = holder
	if scale then
		holder:ScaleTo(scale)
	end
	local bb, size = holder:GetBoundingBox()
	holder:PivotTo(CFrame.new(pos + (holder:GetPivot().Position - bb.Position) + Vector3.new(0, size.Y / 2, 0)))
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	holder.Name = "Pine"
	holder.Parent = parent
end

local function mapColor(part: BasePart, color: Color3, layer: number)
	part:SetAttribute("MapColor", color)
	part:SetAttribute("MapLayer", layer)
end

local function road(parent, center: Vector3, sizeX: number, sizeZ: number, skipReserve: boolean?)
	-- roads stop at dealership lots instead of running through them
	if not skipReserve and WorldBuilder.Reserved then
		local alongX = sizeX >= sizeZ
		local a0 = (alongX and center.X or center.Z) - (alongX and sizeX or sizeZ) / 2
		local a1 = a0 + (alongX and sizeX or sizeZ)
		local c0 = (alongX and center.Z or center.X) - (alongX and sizeZ or sizeX) / 2
		local c1 = c0 + (alongX and sizeZ or sizeX)
		local pieces = { { a0, a1 } }
		for _, r in WorldBuilder.Reserved do
			local rc0, rc1 = alongX and r[3] or r[1], alongX and r[4] or r[2]
			local ra0, ra1 = alongX and r[1] or r[3], alongX and r[2] or r[4]
			if rc1 > c0 and rc0 < c1 then
				local nextPieces = {}
				for _, p in pieces do
					if ra1 <= p[1] or ra0 >= p[2] then
						table.insert(nextPieces, p)
					else
						if ra0 > p[1] then
							table.insert(nextPieces, { p[1], ra0 })
						end
						if ra1 < p[2] then
							table.insert(nextPieces, { ra1, p[2] })
						end
					end
				end
				pieces = nextPieces
			end
		end
		local last
		for _, p in pieces do
			local len = p[2] - p[1]
			if len > 4 then
				local mid = (p[1] + p[2]) / 2
				local c = alongX and Vector3.new(mid, center.Y, center.Z) or Vector3.new(center.X, center.Y, mid)
				last = road(parent, c, alongX and len or sizeX, alongX and sizeZ or len, true)
			end
		end
		return last
	end
	-- Roblox parts max out at 2048 studs, so long roads are built from pieces
	local MAX = 1800
	if sizeX > MAX or sizeZ > MAX then
		local alongX = sizeX > sizeZ
		local len = alongX and sizeX or sizeZ
		local n = math.ceil(len / MAX)
		local piece = len / n
		local last
		for i = 0, n - 1 do
			local offset = -len / 2 + piece * (i + 0.5)
			last = road(parent, center + (alongX and Vector3.new(offset, 0, 0) or Vector3.new(0, 0, offset)), alongX and piece or sizeX, alongX and sizeZ or piece, true)
		end
		return last
	end
	local r = make("Part", {
		Name = "Road",
		Size = Vector3.new(sizeX, 0.2, sizeZ),
		Position = center + Vector3.new(0, 0.1, 0),
		Material = Enum.Material.Asphalt,
		Color = Color3.fromRGB(44, 44, 48),
	}, parent)
	mapColor(r, Color3.fromRGB(46, 48, 54), 3)
	local alongX = sizeX > sizeZ
	local len = alongX and sizeX or sizeZ
	-- dashed centre line
	for d = -len / 2 + 6, len / 2 - 6, 18 do
		make("Part", {
			Name = "Line",
			Size = alongX and Vector3.new(8, 0.05, 0.5) or Vector3.new(0.5, 0.05, 8),
			Position = center + (alongX and Vector3.new(d, 0.23, 0) or Vector3.new(0, 0.23, d)),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(230, 200, 60),
			CanCollide = false,
			CanQuery = false,
		}, parent)
	end
	return r
end

local function streetLight(parent, pos: Vector3, facing: Vector3)
	local m = make("Model", { Name = "StreetLight" }, parent)
	make("Part", { Size = Vector3.new(0.8, 18, 0.8), Position = pos + Vector3.new(0, 9, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) }, m)
	make("Part", { Size = Vector3.new(0.6, 0.6, 6), CFrame = CFrame.lookAt(pos + Vector3.new(0, 18, 0) + facing * 3, pos + Vector3.new(0, 18, 0) + facing * 6), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) }, m)
	local lamp = make("Part", { Size = Vector3.new(2, 0.5, 2), Position = pos + Vector3.new(0, 17.7, 0) + facing * 6, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 170), CanCollide = false }, m)
	make("PointLight", { Range = 40, Brightness = 1.4, Color = Color3.fromRGB(255, 214, 160), Shadows = false }, lamp)
end

local function tree(parent, pos: Vector3, palm: boolean?)
	-- real models first, simple blocks as a fallback
	if prop(parent, palm and "Palm" or "Tree", pos, palm and rng:NextNumber(0.55, 0.75) or rng:NextNumber(0.45, 0.65)) then
		return
	end
	if palm then
		for i = 0, 5 do
			make("Part", { Size = Vector3.new(1.4 - i * 0.1, 3, 1.4 - i * 0.1), CFrame = CFrame.new(pos + Vector3.new(math.sin(i * 0.4) * 0.6, 1.5 + i * 2.8, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(120, 86, 52) }, parent)
		end
		for a = 0, 5 do
			make("Part", { Size = Vector3.new(0.3, 0.4, 8), CFrame = CFrame.new(pos + Vector3.new(0, 17, 0)) * CFrame.Angles(0, a * math.pi / 3, 0) * CFrame.Angles(-0.35, 0, 0) * CFrame.new(0, 0, -3.6), Material = Enum.Material.Grass, Color = Color3.fromRGB(60, 150, 60), CanCollide = false }, parent)
		end
		return
	end
	local h = rng:NextNumber(8, 14)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.5, 1.5), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 40) }, parent)
	for i = 1, 3 do
		make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(6, 10), Position = pos + Vector3.new(rng:NextNumber(-2, 2), h + i * 1.5, rng:NextNumber(-2, 2)), Material = Enum.Material.Grass, Color = Color3.fromRGB(50 + rng:NextInteger(0, 30), 120 + rng:NextInteger(0, 50), 45), CanCollide = false }, parent)
	end
end

-- Every dealership has its own spot inside its area, facing that area's road.
-- yaw turns the plot so its gate (local -Z) faces the road.
local PLOT_SPOTS = {
	-- first free spot goes to the next player, so new players start in the middle
	{ area = "Downtown", pos = Vector3.new(0, 0, -455), yaw = 0 }, -- heart of downtown, faces a city street
	{ area = "Suburbs", pos = Vector3.new(-1793, 0, -760), yaw = math.pi / 2 }, -- faces the west ring road
	{ area = "Port", pos = Vector3.new(1593, 0, -560), yaw = -math.pi / 2 }, -- by the docks, faces the dock road
	{ area = "Hills", pos = Vector3.new(-837, 0, 850), yaw = -math.pi / 2 }, -- faces the west avenue
	{ area = "Beach", pos = Vector3.new(0, 0, 707), yaw = 0 }, -- on the beach strip, faces the beach road
	{ area = "Desert", pos = Vector3.new(900, 0, 657), yaw = 0 }, -- faces the desert road, west of the speedway
}
-- axis-aligned rectangles nothing else may be built in: { x0, x1, z0, z1 }
local RESERVED = {}
for _, s in PLOT_SPOTS do
	local sideways = math.abs(math.sin(s.yaw)) > 0.5
	local hx = (sideways and PlotBuilder.D or PlotBuilder.W) / 2 + 6
	local hz = (sideways and PlotBuilder.W or PlotBuilder.D) / 2 + 6
	table.insert(RESERVED, { s.pos.X - hx, s.pos.X + hx, s.pos.Z - hz, s.pos.Z + hz })
end
WorldBuilder.Reserved = RESERVED

local function inPlotArea(x: number, z: number, margin: number?): boolean
	margin = margin or 0
	for _, r in RESERVED do
		if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
			return true
		end
	end
	return false
end

local function addSpawn(cf: CFrame)
	if inPlotArea(cf.Position.X, cf.Position.Z, 10) then
		return
	end
	table.insert(WorldBuilder.SpawnPoints, cf)
end

local function zoneGround(parent, name: string, x0, x1, z0, z1, material, color, mapCol)
	local g = make("Part", {
		Name = name .. "Ground",
		Size = Vector3.new(x1 - x0, 4, z1 - z0),
		Position = Vector3.new((x0 + x1) / 2, -2, (z0 + z1) / 2),
		Material = material,
		Color = color,
	}, parent)
	mapColor(g, mapCol, 1)
	g:SetAttribute("MapLabel", string.upper(name))
	table.insert(WorldBuilder.Zones, { name = name, x0 = x0, x1 = x1, z0 = z0, z1 = z1 })
	return g
end

---------------------------------------------------------------- lighting
local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 124, 138)
	Lighting.Ambient = Color3.fromRGB(44, 46, 54)
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("Clouds") then
			c:Destroy()
		end
	end
	make("Atmosphere", { Density = 0.18, Offset = 0.08, Color = Color3.fromRGB(205, 214, 228), Decay = Color3.fromRGB(120, 130, 150), Glare = 0.25, Haze = 0.8 }, Lighting)
	make("Sky", { SunAngularSize = 14, MoonAngularSize = 9, StarCount = 4000 }, Lighting)
	make("BloomEffect", { Intensity = 0.5, Size = 28, Threshold = 1.7 }, Lighting)
	make("SunRaysEffect", { Intensity = 0.05, Spread = 0.7 }, Lighting)
	make("ColorCorrectionEffect", { Contrast = 0.1, Saturation = 0.15, Brightness = 0.02 }, Lighting)
	pcall(function()
		make("Clouds", { Cover = 0.55, Density = 0.6 }, workspace.Terrain)
	end)
end

---------------------------------------------------------------- DOWNTOWN
local TOWER_STYLES = {
	{ "DD_OfficeGlass", Enum.Material.Glass, Color3.fromRGB(80, 120, 160) },
	{ "DD_ConcreteOffice", Enum.Material.Concrete, Color3.fromRGB(196, 186, 168) },
	{ "DD_BrickApartment", Enum.Material.Brick, Color3.fromRGB(150, 76, 58) },
	{ "DD_OfficeGlass", Enum.Material.Glass, Color3.fromRGB(40, 60, 80) },
	{ nil, Enum.Material.SmoothPlastic, Color3.fromRGB(30, 34, 42) },
}

local function tower(parent, pos: Vector3, w: number, d: number, h: number)
	local style = TOWER_STYLES[rng:NextInteger(1, #TOWER_STYLES)]
	local m = make("Model", { Name = "Tower" }, parent)
	local core = make("Part", { Name = "Core", Size = Vector3.new(w, h, d), Position = pos + Vector3.new(0, h / 2, 0), Material = style[2], Color = style[3], Reflectance = style[2] == Enum.Material.Glass and 0.15 or 0 }, m)
	if style[1] then
		variant(core, style[1])
	else
		-- dark tower with lit window bands
		for y = 8, h - 6, 10 do
			local lit = rng:NextNumber() < 0.4
			make("Part", { Size = Vector3.new(w + 0.3, 3.5, d + 0.3), Position = pos + Vector3.new(0, y, 0), Material = lit and Enum.Material.Neon or Enum.Material.Glass, Color = lit and Color3.fromRGB(255, 214, 150) or Color3.fromRGB(30, 44, 60), Transparency = lit and 0.4 or 0, CanCollide = false }, m)
		end
	end
	make("Part", { Size = Vector3.new(w + 1, 1.4, d + 1), Position = pos + Vector3.new(0, h + 0.7, 0), Material = Enum.Material.Concrete, Color = Color3.fromRGB(70, 70, 74) }, m)
	-- ground floor shopfront
	make("Part", { Size = Vector3.new(w + 0.6, 7, d + 0.6), Position = pos + Vector3.new(0, 3.5, 0), Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 190, 210), Transparency = 0.35, CanCollide = false }, m)
	if h > 120 and rng:NextNumber() < 0.5 then
		local antenna = make("Part", { Size = Vector3.new(0.6, 22, 0.6), Position = pos + Vector3.new(0, h + 12, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(80, 80, 86) }, m)
		local tip = make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, Position = antenna.Position + Vector3.new(0, 11.5, 0), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 40, 40), CanCollide = false }, m)
		make("PointLight", { Range = 16, Brightness = 2, Color = Color3.fromRGB(255, 40, 40) }, tip)
	end
end

local function buildDowntown(map)
	local f = make("Folder", { Name = "Downtown" }, map)
	local x0, x1, z0, z1 = AVENUE_X[1], AVENUE_X[2], -HALF_Z, 0
	zoneGround(f, "Downtown", x0, x1, z0, z1, Enum.Material.Concrete, Color3.fromRGB(150, 150, 152), Color3.fromRGB(120, 122, 130))
	local xs = { -480, -320, -160, 0, 160, 320, 480 }
	local zs = { -1280, -1120, -960, -800, -640, -480 }
	for _, x in xs do
		road(f, Vector3.new(x, 0, (-1360 + -400) / 2), ROAD_W, 960 + ROAD_W)
	end
	for _, z in zs do
		road(f, Vector3.new(0, 0, z), 1300, ROAD_W)
	end
	road(f, Vector3.new(0, 0, -400), 1300, ROAD_W) -- connects to the avenues
	for i = 1, #xs - 1 do
		for j = 1, #zs do
			local bz0 = zs[j] + ROAD_W / 2
			local bz1 = (zs[j + 1] or -400) - ROAD_W / 2
			local bx0, bx1 = xs[i] + ROAD_W / 2, xs[i + 1] - ROAD_W / 2
			local cx, cz = (bx0 + bx1) / 2, (bz0 + bz1) / 2
			local bw, bd = bx1 - bx0, bz1 - bz0
			-- the downtown dealership takes these blocks
			if inPlotArea(bx0, bz0) or inPlotArea(bx1, bz1) or inPlotArea(bx0, bz1) or inPlotArea(bx1, bz0) or inPlotArea(cx, cz) then
				continue
			end
			local walk = make("Part", { Name = "Sidewalk", Size = Vector3.new(bw, 0.6, bd), Position = Vector3.new(cx, 0.3, cz), Material = Enum.Material.Pavement, Color = Color3.fromRGB(176, 176, 172) }, f)
			variant(walk, "DD_Sidewalk")
			mapColor(walk, Color3.fromRGB(150, 152, 160), 2)
			local centrality = 1 - math.clamp(Vector2.new(cx, cz + 820).Magnitude / 650, 0, 1)
			local half = (bw - 16) / 2
			for _, ox in { -1, 1 } do
				for _, oz in { -1, 1 } do
					if rng:NextNumber() < 0.88 then
						local h = rng:NextNumber(40, 70) + centrality * rng:NextNumber(60, 260)
						tower(f, Vector3.new(cx + ox * half / 2, 0.6, cz + oz * half / 2), half - 6, half - 6, h)
					end
				end
			end
			streetLight(f, Vector3.new(bx0 + 2, 0.6, bz0 + 2), Vector3.new(-1, 0, 0))
			streetLight(f, Vector3.new(bx1 - 2, 0.6, bz1 - 2), Vector3.new(1, 0, 0))
			table.insert(WorldBuilder.PedestrianPaths, { Vector3.new(bx0 + 3, 1, bz0 + 3), Vector3.new(bx1 - 3, 1, bz0 + 3), Vector3.new(bx1 - 3, 1, bz1 - 3), Vector3.new(bx0 + 3, 1, bz1 - 3) })
		end
	end
	for _, x in xs do
		for j = 1, #zs - 1 do
			addSpawn(CFrame.new(x + 9, 0.2, (zs[j] + zs[j + 1]) / 2) * CFrame.Angles(0, math.pi, 0))
		end
	end
	-- plaza with fountain opposite the gun store
	local plaza = make("Part", { Name = "Plaza", Size = Vector3.new(200, 0.6, 300), Position = Vector3.new(400, 0.3, -230), Material = Enum.Material.Pavement, Color = Color3.fromRGB(200, 196, 186) }, f)
	variant(plaza, "DD_Sidewalk")
	mapColor(plaza, Color3.fromRGB(170, 170, 176), 2)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 40, 40), CFrame = CFrame.new(400, 1.5, -230) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 235, 230) }, f)
	local water = make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 36, 36), CFrame = CFrame.new(400, 2.8, -230) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Glass, Color = Color3.fromRGB(60, 140, 220), Transparency = 0.3, CanCollide = false }, f)
	make("ParticleEmitter", { Rate = 60, Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(14, 18), SpreadAngle = Vector2.new(12, 12), Acceleration = Vector3.new(0, -24, 0), Color = ColorSequence.new(Color3.fromRGB(170, 220, 255)), Size = NumberSequence.new(0.6), Transparency = NumberSequence.new(0.3), EmissionDirection = Enum.NormalId.Right }, water)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		tree(f, Vector3.new(400 + math.cos(a) * 60, 0.6, -230 + math.sin(a) * 90))
	end
	WorldBuilder.Landmarks.Plaza = Vector3.new(400, 2, -230)
	table.insert(WorldBuilder.PedestrianPaths, { Vector3.new(330, 1, -330), Vector3.new(470, 1, -330), Vector3.new(470, 1, -130), Vector3.new(330, 1, -130) })
	return f
end

---------------------------------------------------------------- GUN STORE (downtown, on the boulevard)
local function buildGunStore(map)
	local m = make("Model", { Name = "GunStore" }, map)
	local origin = CFrame.new(-400, 0, -150) * CFrame.Angles(0, math.pi, 0) -- faces the boulevard (+Z)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	local lot = make("Part", { Name = "Lot", Size = Vector3.new(120, 0.6, 110), CFrame = at(0, 0.3, 0), Material = Enum.Material.Asphalt, Color = Color3.fromRGB(60, 60, 64) }, m)
	mapColor(lot, Color3.fromRGB(220, 60, 60), 4)
	lot:SetAttribute("MapLabel", "GUN STORE")
	make("Part", { Name = "Building", Size = Vector3.new(80, 26, 46), CFrame = at(0, 13.6, 25), Material = Enum.Material.Brick, Color = Color3.fromRGB(60, 52, 50) }, m)
	-- dark trim bands + side windows so it reads as a shop, not a box
	for _, y in { 0.9, 25.8 } do
		make("Part", { Size = Vector3.new(81, 1.6, 47), CFrame = at(0, y, 25), Material = Enum.Material.Metal, Color = Color3.fromRGB(26, 26, 30) }, m)
	end
	make("Part", { Name = "Window", Size = Vector3.new(56, 12, 0.4), CFrame = at(0, 8, 1.8), Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 170, 200), Transparency = 0.45, CanCollide = false }, m)
	make("Part", { Name = "Awning", Size = Vector3.new(64, 0.6, 8), CFrame = at(0, 15, -2) * CFrame.Angles(math.rad(-12), 0, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(180, 30, 36) }, m)
	local sign = make("Part", { Name = "Sign", Size = Vector3.new(60, 9, 1.2), CFrame = at(0, 30, 1.6), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(16, 16, 20) }, m)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = make("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(600, 90), LightInfluence = 0 }, sign)
		make("TextLabel", { Size = UDim2.new(1, -30, 1, -12), Position = UDim2.fromOffset(15, 6), BackgroundTransparency = 1, Text = "AMMO & ARMS", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 70, 60) }, g)
	end
	make("PointLight", { Range = 40, Brightness = 2, Color = Color3.fromRGB(255, 90, 70) }, sign)
	-- walk-in counter
	local counter = make("Part", { Name = "Counter", Size = Vector3.new(26, 4, 4), CFrame = at(0, 2.6, -8), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 40) }, m)
	make("ProximityPrompt", { Name = "GunStorePrompt", ActionText = "Shop Guns", ObjectText = "Ammo & Arms", MaxActivationDistance = 16, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E, HoldDuration = 0 }, counter)
	local glow = make("Part", { Name = "Marker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 16, 16), CFrame = at(0, 0.75, -18) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 60), Transparency = 0.4, CanCollide = false }, m)
	local _ = glow
	WorldBuilder.Landmarks.GunStore = at(0, 3, -18).Position
	WorldBuilder.GunStore = m
end

---------------------------------------------------------------- SUBURBS
local HOUSE_COLORS = { Color3.fromRGB(240, 236, 226), Color3.fromRGB(200, 220, 236), Color3.fromRGB(236, 214, 190), Color3.fromRGB(210, 230, 200), Color3.fromRGB(240, 200, 200), Color3.fromRGB(230, 230, 180) }
local ROOF_COLORS = { Color3.fromRGB(80, 50, 40), Color3.fromRGB(50, 54, 64), Color3.fromRGB(120, 60, 40), Color3.fromRGB(70, 70, 70) }

local function house(parent, cf: CFrame)
	local m = make("Model", { Name = "House" }, parent)
	local col = HOUSE_COLORS[rng:NextInteger(1, #HOUSE_COLORS)]
	local roof = ROOF_COLORS[rng:NextInteger(1, #ROOF_COLORS)]
	local w, d, h = rng:NextNumber(26, 34), rng:NextNumber(20, 26), rng:NextNumber(12, 20)
	local body = make("Part", { Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Material = Enum.Material.WoodPlanks, Color = col }, m)
	variant(body, "DD_HouseSiding")
	-- gable roof: two wedges
	for _, s in { -1, 1 } do
		make("WedgePart", { Size = Vector3.new(w + 2, 7, d / 2 + 1), CFrame = cf * CFrame.new(0, h + 3.5, s * (d / 4 + 0.5)) * CFrame.Angles(0, s == 1 and math.pi or 0, 0), Material = Enum.Material.RoofShingles, Color = roof }, m)
	end
	make("Part", { Size = Vector3.new(4.5, 8, 0.4), CFrame = cf * CFrame.new(w * 0.2, 4, -d / 2 - 0.2), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 70, 40) }, m)
	for _, x in { -w * 0.25, w * 0.42 } do
		make("Part", { Size = Vector3.new(5, 4, 0.3), CFrame = cf * CFrame.new(x, h * 0.55, -d / 2 - 0.2), Material = Enum.Material.Glass, Color = Color3.fromRGB(150, 190, 220), Transparency = 0.2 }, m)
	end
	-- driveway + garage door
	make("Part", { Size = Vector3.new(12, 0.3, 18), CFrame = cf * CFrame.new(-w * 0.3, 0.15, -d / 2 - 9), Material = Enum.Material.Concrete, Color = Color3.fromRGB(170, 170, 168), CanCollide = false }, m)
	make("Part", { Size = Vector3.new(10, 8, 0.4), CFrame = cf * CFrame.new(-w * 0.3, 4, -d / 2 - 0.2), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(220, 220, 220) }, m)
	-- mailbox + bush
	make("Part", { Size = Vector3.new(0.4, 3.5, 0.4), CFrame = cf * CFrame.new(w * 0.45, 1.75, -d / 2 - 16), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 40) }, m)
	make("Part", { Size = Vector3.new(1.2, 1.2, 2), CFrame = cf * CFrame.new(w * 0.45, 3.9, -d / 2 - 16), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 60, 140) }, m)
	make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(5, 4, 5), CFrame = cf * CFrame.new(w * 0.1, 1.5, -d / 2 - 3), Material = Enum.Material.Grass, Color = Color3.fromRGB(50, 120, 50), CanCollide = false }, m)
end

local function buildSuburbs(map)
	local f = make("Folder", { Name = "Suburbs" }, map)
	local x0, x1, z0, z1 = -HALF_X, AVENUE_X[1], -HALF_Z, 0
	zoneGround(f, "Suburbs", x0, x1, z0, z1, Enum.Material.Grass, Color3.fromRGB(84, 140, 70), Color3.fromRGB(80, 130, 70))
	local streets = { -1260, -1060, -860, -660, -460 }
	for _, z in streets do
		road(f, Vector3.new((x0 + x1) / 2, 0, z), x1 - x0, ROAD_W)
	end
	for _, x in { -1900, -1600, -1300, -1000, -750 } do
		road(f, Vector3.new(x, 0, -860), ROAD_W, 840)
	end
	for _, z in streets do
		for x = -1940, -700, 52 do
			for _, side in { -1, 1 } do
				local hz = z + side * 50
				if not inPlotArea(x, hz, 30) and math.abs(((x + 1900) % 300) - 0) > 30 and rng:NextNumber() < 0.85 then
					house(f, CFrame.new(x, 0, hz) * CFrame.Angles(0, side == 1 and math.pi or 0, 0))
				end
			end
		end
		for x = -1880, -760, 140 do
			addSpawn(CFrame.new(x, 0.2, z - 9) * CFrame.Angles(0, math.pi / 2, 0))
		end
		table.insert(WorldBuilder.PedestrianPaths, { Vector3.new(-1900, 1, z + 22), Vector3.new(-720, 1, z + 22) })
	end
	for i = 1, 60 do
		local x, z = rng:NextNumber(-1980, -680), rng:NextNumber(-1380, -380)
		if not inPlotArea(x, z, 12) then
			tree(f, Vector3.new(x, 0, z))
		end
	end
	-- park with a basketball court feel
	local park = make("Part", { Name = "Park", Size = Vector3.new(160, 0.4, 120), Position = Vector3.new(-1500, 0.2, -1150), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 150, 60) }, f)
	mapColor(park, Color3.fromRGB(70, 150, 60), 2)
	WorldBuilder.Landmarks.Suburbs = Vector3.new(-1300, 2, -660)
end

---------------------------------------------------------------- PORT
local CONTAINER_COLORS = { Color3.fromRGB(190, 50, 40), Color3.fromRGB(40, 90, 170), Color3.fromRGB(230, 160, 30), Color3.fromRGB(40, 130, 80), Color3.fromRGB(200, 200, 200), Color3.fromRGB(120, 60, 140) }

local function buildPort(map)
	local f = make("Folder", { Name = "Port" }, map)
	local x0, x1, z0, z1 = AVENUE_X[2], HALF_X, -HALF_Z, 0
	zoneGround(f, "Port", x0, 1820, z0, z1, Enum.Material.Concrete, Color3.fromRGB(120, 122, 126), Color3.fromRGB(110, 112, 118))
	-- sea along the east edge
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(1950, -6, -700), Vector3.new(300, 14, 1400), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(1950, -16, -700), Vector3.new(300, 6, 1400), Enum.Material.Sand)
	local sea = make("Part", { Name = "SeaMap", Size = Vector3.new(180, 0.1, 1400), Position = Vector3.new(1910, -30, -700), Transparency = 1, CanCollide = false, CanQuery = false }, f)
	mapColor(sea, Color3.fromRGB(40, 110, 190), 1)
	for _, z in { -1250, -950, -650, -380 } do
		road(f, Vector3.new(1235, 0, z), 1170, ROAD_W)
	end
	road(f, Vector3.new(1100, 0, -820), ROAD_W, 900)
	road(f, Vector3.new(1600, 0, -820), ROAD_W, 900)
	-- warehouses
	for _, pos in { Vector3.new(850, 0, -1100), Vector3.new(850, 0, -800), Vector3.new(1350, 0, -1100), Vector3.new(1350, 0, -800), Vector3.new(850, 0, -520) } do
		local w = make("Part", { Name = "Warehouse", Size = Vector3.new(160, 34, 90), Position = pos + Vector3.new(0, 17, 0), Material = Enum.Material.CorrodedMetal, Color = CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)] }, f)
		variant(w, "DD_Corrugated")
		make("WedgePart", { Size = Vector3.new(162, 8, 46), CFrame = CFrame.new(pos + Vector3.new(0, 38, 22.5)) * CFrame.Angles(0, math.pi, 0), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(90, 92, 96) }, f)
		make("WedgePart", { Size = Vector3.new(162, 8, 46), CFrame = CFrame.new(pos + Vector3.new(0, 38, -22.5)), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(90, 92, 96) }, f)
		make("Part", { Size = Vector3.new(30, 22, 0.6), Position = pos + Vector3.new(0, 11, -45.4), Material = Enum.Material.CorrodedMetal, Color = Color3.fromRGB(200, 200, 205) }, f)
	end
	-- container yard by the water
	for row = 0, 5 do
		for col = 0, 8 do
			local stack = rng:NextInteger(1, 3)
			for s = 1, stack do
				make("Part", { Name = "Container", Size = Vector3.new(12, 10, 32), Position = Vector3.new(1680 + row * 15, 5 + (s - 1) * 10, -1250 + col * 40), Material = Enum.Material.CorrodedMetal, Color = CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)] }, f)
			end
		end
	end
	-- gantry cranes
	for _, z in { -1150, -750 } do
		local col = Color3.fromRGB(230, 170, 30)
		for _, dz in { -14, 14 } do
			for _, x in { 1760, 1860 } do
				make("Part", { Size = Vector3.new(3, 70, 3), Position = Vector3.new(x, 35, z + dz), Material = Enum.Material.Metal, Color = col }, f)
			end
		end
		make("Part", { Size = Vector3.new(170, 5, 32), Position = Vector3.new(1830, 72, z), Material = Enum.Material.Metal, Color = col }, f)
	end
	-- pier
	make("Part", { Name = "Pier", Size = Vector3.new(90, 2, 40), Position = Vector3.new(1860, 0.5, -300), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(120, 90, 60) }, f)
	for z = -1240, -420, 120 do
		addSpawn(CFrame.new(1100 + 9, 0.2, z) * CFrame.Angles(0, math.pi, 0))
		addSpawn(CFrame.new(1600 + 9, 0.2, z) * CFrame.Angles(0, math.pi, 0))
	end
	WorldBuilder.Landmarks.Port = Vector3.new(1600, 2, -950)
end

---------------------------------------------------------------- HILLS
local function buildHills(map)
	local f = make("Folder", { Name = "Hills" }, map)
	local x0, x1, z0, z1 = -HALF_X, AVENUE_X[1], 0, HALF_Z
	zoneGround(f, "Hills", x0, x1, z0, z1, Enum.Material.Grass, Color3.fromRGB(96, 150, 70), Color3.fromRGB(96, 150, 80))
	local terrain = workspace.Terrain
	-- rolling hills (big balls mostly underground) -- drivable slopes
	for i = 1, 26 do
		local x = rng:NextNumber(-1950, -720)
		local z = rng:NextNumber(420, 1350)
		local r = rng:NextNumber(70, 150)
		terrain:FillBall(Vector3.new(x, -r * 0.72, z), r, Enum.Material.Grass)
	end
	-- a couple of rocky peaks
	for _, p in { Vector3.new(-1700, 0, 1150), Vector3.new(-1150, 0, 1250) } do
		terrain:FillBall(p + Vector3.new(0, -40, 0), 120, Enum.Material.Rock)
		terrain:FillBall(p + Vector3.new(0, -10, 0), 70, Enum.Material.Grass)
	end
	-- winding dirt track (flat segments around the hills)
	local track = { Vector3.new(-760, 0, 420), Vector3.new(-1000, 0, 520), Vector3.new(-1300, 0, 470), Vector3.new(-1600, 0, 600), Vector3.new(-1850, 0, 820), Vector3.new(-1600, 0, 1000), Vector3.new(-1300, 0, 900), Vector3.new(-1000, 0, 1050), Vector3.new(-700, 0, 1120) }
	for i = 1, #track - 1 do
		local a, b = track[i], track[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local seg = make("Part", { Name = "Road", Size = Vector3.new(ROAD_W - 6, 0.6, len + 20), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0)), Material = Enum.Material.Ground, Color = Color3.fromRGB(130, 104, 74) }, f)
		mapColor(seg, Color3.fromRGB(150, 120, 80), 3)
		addSpawn(CFrame.lookAt(mid + Vector3.new(0, 0.6, 0), b))
	end
	-- clear terrain off the track and the plot
	for i = 1, #track - 1 do
		local a, b = track[i], track[i + 1]
		for t = 0, 1, 0.1 do
			local p = a:Lerp(b, t)
			terrain:FillBlock(CFrame.new(p + Vector3.new(0, 30, 0)), Vector3.new(40, 60, 40), Enum.Material.Air)
		end
	end
	for _, r in RESERVED do
		terrain:FillBlock(CFrame.new((r[1] + r[2]) / 2, 40, (r[3] + r[4]) / 2), Vector3.new(r[2] - r[1] + 80, 80, r[4] - r[3] + 80), Enum.Material.Air)
	end
	-- mansions on the hill tops
	for _, p in { Vector3.new(-1500, 0, 1250), Vector3.new(-900, 0, 1300), Vector3.new(-1850, 0, 450) } do
		local hit = workspace:Raycast(p + Vector3.new(0, 300, 0), Vector3.new(0, -400, 0))
		local y = hit and hit.Position.Y or 0
		local m = make("Model", { Name = "Mansion" }, f)
		make("Part", { Size = Vector3.new(60, 1, 50), Position = Vector3.new(p.X, y + 0.5, p.Z), Material = Enum.Material.Marble, Color = Color3.fromRGB(230, 228, 220) }, m)
		local b = make("Part", { Size = Vector3.new(50, 22, 36), Position = Vector3.new(p.X, y + 12, p.Z), Material = Enum.Material.Concrete, Color = Color3.fromRGB(245, 245, 240) }, m)
		variant(b, "DD_ConcreteOffice")
		make("Part", { Size = Vector3.new(40, 10, 0.4), Position = Vector3.new(p.X, y + 12, p.Z - 18.2), Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 170, 210), Transparency = 0.3 }, m)
		make("Part", { Size = Vector3.new(20, 0.6, 12), Position = Vector3.new(p.X + 32, y + 0.8, p.Z), Material = Enum.Material.Glass, Color = Color3.fromRGB(60, 170, 230), Transparency = 0.2 }, m)
	end
	-- pine forest (the map isn't in Workspace yet, so only terrain hills are hit; flat ground = y 0)
	for i = 1, 110 do
		local x, z = rng:NextNumber(-1980, -700), rng:NextNumber(380, 1380)
		if not inPlotArea(x, z, 12) then
			local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0))
			local y = hit and hit.Position.Y or 0
			if propTemplate("Trees2") then
				pine(f, Vector3.new(x, y - 1, z), rng:NextNumber(0.45, 0.7))
			else
				tree(f, Vector3.new(x, y, z))
			end
		end
	end
	WorldBuilder.Landmarks.Hills = Vector3.new(-1300, 4, 480)
end

---------------------------------------------------------------- BEACH
local function buildBeach(map)
	local f = make("Folder", { Name = "Beach" }, map)
	local x0, x1, z0, z1 = AVENUE_X[1], AVENUE_X[2], 0, HALF_Z
	zoneGround(f, "Beach", x0, x1, z0, 1150, Enum.Material.Sand, Color3.fromRGB(226, 206, 150), Color3.fromRGB(226, 206, 150))
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -6, 1280), Vector3.new(1300, 14, 260), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -16, 1280), Vector3.new(1300, 6, 260), Enum.Material.Sand)
	local sea = make("Part", { Name = "SeaMap", Size = Vector3.new(1300, 0.1, 250), Position = Vector3.new(0, -30, 1275), Transparency = 1, CanCollide = false, CanQuery = false }, f)
	mapColor(sea, Color3.fromRGB(40, 110, 190), 1)
	-- beach road + boardwalk
	road(f, Vector3.new(0, 0, 520), 1300, ROAD_W)
	road(f, Vector3.new(-330, 0, 760), ROAD_W, 480)
	road(f, Vector3.new(330, 0, 760), ROAD_W, 480)
	local boardwalk = make("Part", { Name = "Boardwalk", Size = Vector3.new(1200, 1, 26), Position = Vector3.new(0, 0.5, 1000), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(150, 110, 70) }, f)
	mapColor(boardwalk, Color3.fromRGB(150, 110, 70), 2)
	table.insert(WorldBuilder.PedestrianPaths, { Vector3.new(-580, 1.5, 1000), Vector3.new(580, 1.5, 1000) })
	-- beach shops along the road
	local shopCols = { Color3.fromRGB(80, 200, 220), Color3.fromRGB(250, 160, 80), Color3.fromRGB(250, 120, 160), Color3.fromRGB(150, 220, 120) }
	for i = 0, 7 do
		local x = -560 + i * 160
		if math.abs(x) > 190 then
			local s = make("Part", { Name = "Shop", Size = Vector3.new(40, 14, 26), Position = Vector3.new(x, 7, 600), Material = Enum.Material.Plaster, Color = shopCols[i % 4 + 1] }, f)
			local _ = s
			make("Part", { Size = Vector3.new(44, 0.6, 10), CFrame = CFrame.new(x, 12, 584) * CFrame.Angles(math.rad(-15), 0, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(255, 255, 255) }, f)
		end
	end
	-- umbrellas, towels, lifeguard towers, palms
	for i = 1, 40 do
		local x, z = rng:NextNumber(-600, 600), rng:NextNumber(1030, 1130)
		make("Part", { Size = Vector3.new(0.3, 8, 0.3), Position = Vector3.new(x, 4, z), Material = Enum.Material.Metal, Color = Color3.fromRGB(240, 240, 240) }, f)
		make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 9, 9), CFrame = CFrame.new(x, 8, z) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Fabric, Color = shopCols[rng:NextInteger(1, 4)], CanCollide = false }, f)
		make("Part", { Size = Vector3.new(3, 0.1, 6), Position = Vector3.new(x + 4, 0.05, z), Material = Enum.Material.Fabric, Color = shopCols[rng:NextInteger(1, 4)], CanCollide = false }, f)
	end
	for _, x in { -450, 0, 450 } do
		local t = make("Model", { Name = "LifeguardTower" }, f)
		for _, dx in { -3, 3 } do
			for _, dz in { -3, 3 } do
				make("Part", { Size = Vector3.new(0.6, 10, 0.6), Position = Vector3.new(x + dx, 5, 1100 + dz), Material = Enum.Material.Wood, Color = Color3.fromRGB(240, 240, 240) }, t)
			end
		end
		make("Part", { Size = Vector3.new(8, 6, 8), Position = Vector3.new(x, 13, 1100), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(220, 50, 50) }, t)
	end
	for x = -620, 620, 45 do
		tree(f, Vector3.new(x, 0, 960), true)
	end
	-- pier into the sea
	make("Part", { Name = "Pier", Size = Vector3.new(30, 2, 200), Position = Vector3.new(450, 1, 1220), Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(130, 96, 64) }, f)
	for x = -560, 560, 140 do
		addSpawn(CFrame.new(x, 0.2, 520 - 9) * CFrame.Angles(0, math.pi / 2, 0))
	end
	WorldBuilder.Landmarks.Beach = Vector3.new(0, 2, 980)
end

---------------------------------------------------------------- DESERT
local function buildDesert(map)
	local f = make("Folder", { Name = "Desert" }, map)
	local x0, x1, z0, z1 = AVENUE_X[2], HALF_X, 0, HALF_Z
	zoneGround(f, "Desert", x0, x1, z0, z1, Enum.Material.Sand, Color3.fromRGB(214, 170, 110), Color3.fromRGB(210, 166, 110))
	-- canyon: real mesa rock formations around the edges (away from roads and the track)
	local cx, cz = 1400, 900
	local mesaSpots = { Vector3.new(1900, 0, 1250), Vector3.new(1880, 0, 700), Vector3.new(950, 0, 1300), Vector3.new(780, 0, 1050), Vector3.new(1250, 0, 1330), Vector3.new(1650, 0, 1340), Vector3.new(1920, 0, 980) }
	for _, p in mesaSpots do
		if inPlotArea(p.X, p.Z, 90) then
			continue
		end
		if not prop(f, "Mesa", p, rng:NextNumber(0.7, 1.3)) then
			workspace.Terrain:FillBall(p + Vector3.new(0, 10, 0), 50, Enum.Material.Sandstone)
		end
	end
	-- speedway oval: many short overlapping pieces so there are no gaps
	local segs = 72
	local rx, rz = 300, 200
	for i = 0, segs - 1 do
		local a0, a1 = i / segs * math.pi * 2, (i + 1) / segs * math.pi * 2
		local p0 = Vector3.new(cx + math.cos(a0) * rx, 0.3, cz + math.sin(a0) * rz)
		local p1 = Vector3.new(cx + math.cos(a1) * rx, 0.3, cz + math.sin(a1) * rz)
		local len = (p1 - p0).Magnitude + 14
		local cf = CFrame.lookAt((p0 + p1) / 2, p1)
		local seg = make("Part", { Name = "Road", Size = Vector3.new(48, 0.6, len), CFrame = cf, Material = Enum.Material.Asphalt, Color = Color3.fromRGB(38, 38, 42) }, f)
		mapColor(seg, Color3.fromRGB(46, 48, 54), 3)
		-- red/white kerbs on both edges
		for _, side in { -1, 1 } do
			make("Part", { Name = "Kerb", Size = Vector3.new(3, 0.8, len - 10), CFrame = cf * CFrame.new(side * 25.5, 0.1, 0), Material = Enum.Material.SmoothPlastic, Color = (i % 2 == 0) and Color3.fromRGB(220, 30, 30) or Color3.fromRGB(245, 245, 245) }, f)
		end
		if i % 12 == 0 then
			addSpawn(CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 0.2, 0), p1))
		end
	end
	-- infield grass + start/finish line
	local infield = make("Part", { Name = "Infield", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, rz * 2 - 52, rx * 2 - 52), CFrame = CFrame.new(cx, 0.15, cz) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Grass, Color = Color3.fromRGB(80, 140, 60) }, f)
	local _ = infield
	for k = 0, 9 do
		make("Part", { Size = Vector3.new(4.8, 0.05, 4), Position = Vector3.new(cx + rx - 22 + k * 4.8, 0.62, cz), Material = Enum.Material.SmoothPlastic, Color = (k % 2 == 0) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), CanCollide = false }, f)
	end
	-- grandstands with seat rows
	for _, side in { -1, 1 } do
		local sz = cz + side * (rz + 40)
		for row = 0, 5 do
			make("Part", { Name = "Stand", Size = Vector3.new(220, 3, 6), Position = Vector3.new(cx, 1.5 + row * 3, sz + side * row * 6), Material = Enum.Material.Concrete, Color = row % 2 == 0 and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(230, 230, 235) }, f)
		end
	end
	road(f, Vector3.new(1400, 0, 470), 1300, ROAD_W)
	road(f, Vector3.new(1400, 0, 590), ROAD_W, 240)
	-- cacti (real model, scaled up)
	for i = 1, 70 do
		local x, z = rng:NextNumber(680, 1980), rng:NextNumber(380, 1380)
		if math.abs(((x - cx) / (rx + 60)) ^ 2 + ((z - cz) / (rz + 80)) ^ 2) > 1 and not inPlotArea(x, z, 20) and math.abs(z - 470) > 30 then
			if not prop(f, "Cactus", Vector3.new(x, 0, z), rng:NextNumber(2.5, 4)) then
				make("Part", { Size = Vector3.new(1.6, 10, 1.6), Position = Vector3.new(x, 5, z), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 130, 60) }, f)
			end
		end
	end
	-- gas station by the boulevard
	local gs = make("Model", { Name = "GasStation" }, f)
	make("Part", { Size = Vector3.new(80, 0.4, 50), Position = Vector3.new(1700, 0.2, 400), Material = Enum.Material.Concrete, Color = Color3.fromRGB(140, 140, 140) }, gs)
	make("Part", { Size = Vector3.new(60, 2, 30), Position = Vector3.new(1700, 16, 400), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(220, 40, 40) }, gs)
	for _, x in { 1680, 1720 } do
		make("Part", { Size = Vector3.new(2, 15, 2), Position = Vector3.new(x, 7.5, 400), Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 220, 220) }, gs)
	end
	WorldBuilder.Landmarks.Desert = Vector3.new(1400, 2, 700)
end

---------------------------------------------------------------- roads that connect everything
local function buildMainRoads(map)
	local f = make("Folder", { Name = "Roads" }, map)
	road(f, Vector3.new(0, 0, 0), HALF_X * 2, ROAD_W + 10) -- Dealz Boulevard
	for _, x in AVENUE_X do
		road(f, Vector3.new(x, 0, 0), ROAD_W, HALF_Z * 2)
	end
	-- ring road
	road(f, Vector3.new(0, 0, -HALF_Z + 20), HALF_X * 2, ROAD_W)
	road(f, Vector3.new(-HALF_X + 20, 0, 0), ROAD_W, HALF_Z * 2)
	road(f, Vector3.new(1780, 0, -680), ROAD_W, 1400) -- along the docks
	for x = -1900, 1900, 300 do
		streetLight(f, Vector3.new(x, 0, 26), Vector3.new(0, 0, -1))
		addSpawn(CFrame.new(x + 150, 0.2, -10) * CFrame.Angles(0, -math.pi / 2, 0))
	end
	for _, x in AVENUE_X do
		for z = -1300, 1300, 260 do
			if math.abs(z) > 60 then
				addSpawn(CFrame.new(x + 9, 0.2, z) * CFrame.Angles(0, math.pi, 0))
			end
		end
	end
end

---------------------------------------------------------------- plots
local function buildPlots(map)
	local plots = make("Folder", { Name = "Plots" }, map)
	for i, s in PLOT_SPOTS do
		local origin = CFrame.new(s.pos) * CFrame.Angles(0, s.yaw, 0)
		local model = make("Model", { Name = "Plot" .. i }, plots)
		local parts = PlotBuilder.buildShell(model, origin)
		model.PrimaryPart = model.Floor
		mapColor(model.Floor, Color3.fromRGB(200, 200, 205), 4)
		model:SetAttribute("Area", s.area)
		-- short paved driveway from the gate out to the road
		local drive = make("Part", { Name = "Driveway", Size = Vector3.new(84, 0.3, 24), CFrame = origin * CFrame.new(0, 0.15, -PlotBuilder.D / 2 - 12), Material = Enum.Material.Concrete, Color = Color3.fromRGB(150, 150, 150) }, model)
		mapColor(drive, Color3.fromRGB(46, 48, 54), 3)
		table.insert(WorldBuilder.Plots, { index = i, cframe = origin, model = model, zone = parts.zone, spawnPad = parts.spawnPad, trim = parts.trim, area = s.area })
		WorldBuilder.Landmarks[s.area .. "Dealership"] = (origin * CFrame.new(0, 3, -PlotBuilder.D / 2 - 10)).Position
	end
end

function WorldBuilder.build()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	for _, name in { "Baseplate", "SpawnLocation" } do
		local p = workspace:FindFirstChild(name)
		if p then
			p:Destroy()
		end
	end
	workspace.Terrain:Clear()
	setupLighting()

	local map = Instance.new("Model")
	map.Name = "Map"
	-- far ground under everything (so nothing falls into the void)
	-- base ground in tiles (parts can't be bigger than 2048 studs)
	for gx = -1, 1, 2 do
		for gz = -1, 1, 2 do
			make("Part", { Name = "Ground", Size = Vector3.new(HALF_X + 200, 4, HALF_Z + 200), Position = Vector3.new(gx * (HALF_X + 200) / 2, -2.05, gz * (HALF_Z + 200) / 2), Material = Enum.Material.Grass, Color = Color3.fromRGB(78, 120, 64) }, map)
		end
	end
	buildMainRoads(map)
	buildDowntown(map)
	buildGunStore(map)
	buildSuburbs(map)
	buildPort(map)
	buildHills(map)
	buildBeach(map)
	buildDesert(map)
	buildPlots(map)
	pcall(function()
		map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	map:SetAttribute("HalfX", HALF_X)
	map:SetAttribute("HalfZ", HALF_Z)
	map.Parent = workspace

	local spawn = make("SpawnLocation", { Name = "Spawn", Size = Vector3.new(16, 1, 16), Position = Vector3.new(0, 0.7, 0), Transparency = 1, CanCollide = false, Neutral = true, Duration = 0 }, workspace)
	spawn.Enabled = true
	-- landmarks for waypoints/tutorial
	local lm = Instance.new("Folder")
	lm.Name = "Landmarks"
	for name, pos in WorldBuilder.Landmarks do
		local v = Instance.new("Vector3Value")
		v.Name = name
		v.Value = pos
		v.Parent = lm
	end
	lm.Parent = workspace
	return map
end

-- Slow day/night cycle: a full day is ~24 minutes.
function WorldBuilder.startDayNight()
	task.spawn(function()
		while true do
			task.wait(1)
			Lighting.ClockTime = (Lighting.ClockTime + 24 / 1440) % 24
		end
	end)
end

return WorldBuilder
