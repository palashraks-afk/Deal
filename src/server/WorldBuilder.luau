-- Builds the map at server start: ground, road grid, city blocks and buildings, street
-- lights, the dealer row of player plots, lighting and the day/night cycle.
-- Layout is seeded, so it's the same every server (the minimap reads it from Workspace).
local Lighting = game:GetService("Lighting")

local WorldBuilder = {}

local GRID = 160
local ROAD_W = 34
local X_LINES = {} -- north-south roads
for i = -4, 4 do
	table.insert(X_LINES, i * GRID)
end
local Z_LINES = {} -- east-west roads (city)
for i = -4, 1 do
	table.insert(Z_LINES, i * GRID - 80)
end
local DEALER_ROAD_Z = 360
local CITY_Z_MIN, CITY_Z_MAX = Z_LINES[1], Z_LINES[#Z_LINES]

WorldBuilder.PlotCount = 6
WorldBuilder.Plots = {} -- array of { index, cframe, model }
WorldBuilder.SpawnPoints = {} -- CFrames on city roads where finds appear

local rng = Random.new(20261110)

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

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 115, 130)
	Lighting.Ambient = Color3.fromRGB(40, 42, 50)
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	make("Atmosphere", { Density = 0.12, Offset = 0.05, Color = Color3.fromRGB(205, 212, 225), Decay = Color3.fromRGB(120, 128, 145), Glare = 0.2, Haze = 0.6 }, Lighting)
	make("Sky", { SunAngularSize = 14, MoonAngularSize = 9, StarCount = 4000 }, Lighting)
	make("BloomEffect", { Intensity = 0.6, Size = 30, Threshold = 1.6 }, Lighting)
	make("SunRaysEffect", { Intensity = 0.06, Spread = 0.7 }, Lighting)
	make("ColorCorrectionEffect", { Contrast = 0.08, Saturation = 0.12, Brightness = 0.02 }, Lighting)
end

local function road(parent, center: Vector3, sizeX: number, sizeZ: number)
	make("Part", {
		Name = "Road",
		Size = Vector3.new(sizeX, 0.2, sizeZ),
		Position = center + Vector3.new(0, 0.1, 0),
		Material = Enum.Material.Asphalt,
		Color = Color3.fromRGB(42, 42, 46),
	}, parent)
	-- centre line
	local alongX = sizeX > sizeZ
	make("Part", {
		Name = "Line",
		Size = alongX and Vector3.new(sizeX, 0.05, 0.5) or Vector3.new(0.5, 0.05, sizeZ),
		Position = center + Vector3.new(0, 0.22, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(220, 180, 40),
		CanCollide = false,
	}, parent)
end

local BUILDING_PALETTE = {
	{ Enum.Material.Concrete, Color3.fromRGB(150, 150, 155) },
	{ Enum.Material.Concrete, Color3.fromRGB(196, 188, 170) },
	{ Enum.Material.Brick, Color3.fromRGB(140, 70, 56) },
	{ Enum.Material.Glass, Color3.fromRGB(70, 110, 140) },
	{ Enum.Material.SmoothPlastic, Color3.fromRGB(32, 36, 44) },
	{ Enum.Material.Marble, Color3.fromRGB(220, 220, 215) },
}

local function building(parent, pos: Vector3, w: number, d: number, h: number)
	local style = BUILDING_PALETTE[rng:NextInteger(1, #BUILDING_PALETTE)]
	local model = make("Model", { Name = "Building" }, parent)
	make("Part", {
		Name = "Core",
		Size = Vector3.new(w, h, d),
		Position = pos + Vector3.new(0, h / 2, 0),
		Material = style[1],
		Color = style[2],
		Reflectance = style[1] == Enum.Material.Glass and 0.2 or 0,
	}, model)
	-- window bands; some lit (neon) for night-time glow
	local bandGap = 9
	for y = 6, h - 4, bandGap do
		local lit = rng:NextNumber() < 0.35
		make("Part", {
			Name = "Windows",
			Size = Vector3.new(w + 0.3, 3, d + 0.3),
			Position = pos + Vector3.new(0, y, 0),
			Material = lit and Enum.Material.Neon or Enum.Material.Glass,
			Color = lit and Color3.fromRGB(255, 214, 150) or Color3.fromRGB(30, 44, 60),
			Transparency = lit and 0.35 or 0,
			Reflectance = lit and 0 or 0.3,
			CanCollide = false,
		}, model)
	end
	make("Part", {
		Name = "Roof",
		Size = Vector3.new(w + 1, 1.2, d + 1),
		Position = pos + Vector3.new(0, h + 0.6, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(70, 70, 74),
	}, model)
end

local function tree(parent, pos: Vector3)
	local h = rng:NextNumber(8, 13)
	make("Part", { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.4, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Wood, Color = Color3.fromRGB(96, 66, 40) }, parent)
	make("Part", { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(8, 12), Position = pos + Vector3.new(0, h + 2, 0), Material = Enum.Material.Grass, Color = Color3.fromRGB(60, 130 + rng:NextInteger(0, 40), 50), CanCollide = false }, parent)
end

local function streetLight(parent, pos: Vector3, facing: Vector3)
	local m = make("Model", { Name = "StreetLight" }, parent)
	make("Part", { Name = "Pole", Size = Vector3.new(0.8, 18, 0.8), Position = pos + Vector3.new(0, 9, 0), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) }, m)
	make("Part", { Name = "Arm", Size = Vector3.new(0.6, 0.6, 6), CFrame = CFrame.lookAt(pos + Vector3.new(0, 18, 0) + facing * 3, pos + Vector3.new(0, 18, 0) + facing * 6), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) }, m)
	local lamp = make("Part", { Name = "Lamp", Size = Vector3.new(2, 0.5, 2), Position = pos + Vector3.new(0, 17.7, 0) + facing * 6, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 220, 170), CanCollide = false }, m)
	make("PointLight", { Range = 38, Brightness = 1.6, Color = Color3.fromRGB(255, 214, 160), Shadows = false }, lamp)
	return lamp
end

local function buildCity(map)
	local roads = make("Folder", { Name = "Roads" }, map)
	local blocks = make("Folder", { Name = "Blocks" }, map)
	local lights = make("Folder", { Name = "Lights" }, map)

	local zSouth = DEALER_ROAD_Z
	-- north-south roads run from the top of the city to the dealer row
	for _, x in X_LINES do
		local len = zSouth - CITY_Z_MIN
		road(roads, Vector3.new(x, 0, CITY_Z_MIN + len / 2), ROAD_W, len + ROAD_W)
	end
	local xMin, xMax = X_LINES[1], X_LINES[#X_LINES]
	for _, z in Z_LINES do
		road(roads, Vector3.new(0, 0, z), xMax - xMin + ROAD_W, ROAD_W)
	end
	road(roads, Vector3.new(0, 0, DEALER_ROAD_Z), 1860, ROAD_W) -- dealer row runs past every plot

	-- blocks + buildings
	for i = 1, #X_LINES - 1 do
		for j = 1, #Z_LINES - 1 do
			local x0, x1 = X_LINES[i] + ROAD_W / 2, X_LINES[i + 1] - ROAD_W / 2
			local z0, z1 = Z_LINES[j] + ROAD_W / 2, Z_LINES[j + 1] - ROAD_W / 2
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			local bw, bd = x1 - x0, z1 - z0
			local isPark = rng:NextNumber() < 0.14
			make("Part", {
				Name = isPark and "Park" or "Sidewalk",
				Size = Vector3.new(bw, 0.6, bd),
				Position = Vector3.new(cx, 0.3, cz),
				Material = isPark and Enum.Material.Grass or Enum.Material.Concrete,
				Color = isPark and Color3.fromRGB(70, 140, 60) or Color3.fromRGB(175, 175, 172),
			}, blocks)
			if isPark then
				for _ = 1, 9 do
					tree(blocks, Vector3.new(cx + rng:NextNumber(-bw / 2 + 8, bw / 2 - 8), 0.6, cz + rng:NextNumber(-bd / 2 + 8, bd / 2 - 8)))
				end
			else
				-- downtown (centre) is taller
				local centrality = 1 - math.clamp(Vector2.new(cx, cz + 240).Magnitude / 700, 0, 1)
				local inset = 10
				local half = (bw - inset * 2) / 2
				for _, ox in { -1, 1 } do
					for _, oz in { -1, 1 } do
						if rng:NextNumber() < 0.85 then
							local w = half - 4
							local h = rng:NextNumber(24, 50) + centrality * rng:NextNumber(30, 150)
							building(blocks, Vector3.new(cx + ox * half / 2 + ox * 1, 0.6, cz + oz * half / 2 + oz * 1), w, w, h)
						end
					end
				end
			end
			-- street lights on block corners
			streetLight(lights, Vector3.new(x0 + 2, 0.6, z0 + 2), Vector3.new(-1, 0, 0))
			streetLight(lights, Vector3.new(x1 - 2, 0.6, z1 - 2), Vector3.new(1, 0, 0))
		end
	end

	-- spawn points: middle of each city road segment, parked in the right-hand lane
	for _, x in X_LINES do
		for j = 1, #Z_LINES - 1 do
			local z = (Z_LINES[j] + Z_LINES[j + 1]) / 2
			table.insert(WorldBuilder.SpawnPoints, CFrame.new(x + 9, 0.2, z) * CFrame.Angles(0, math.pi, 0))
		end
	end
	for _, z in Z_LINES do
		for i = 1, #X_LINES - 1 do
			local x = (X_LINES[i] + X_LINES[i + 1]) / 2
			table.insert(WorldBuilder.SpawnPoints, CFrame.new(x, 0.2, z - 9) * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
end

-- Plots: built by PlotBuilder (260 x 320 each), in a row south of the dealer road.
local PlotBuilder = require(script.Parent.PlotBuilder)
local PLOT_GAP = 30
WorldBuilder.MaxSlots = PlotBuilder.DisplayPads + PlotBuilder.SpecialPads

local function buildPlot(index: number, plotsFolder)
	local x = (index - (WorldBuilder.PlotCount + 1) / 2) * (PlotBuilder.W + PLOT_GAP)
	local origin = CFrame.new(x, 0, DEALER_ROAD_Z + ROAD_W / 2 + 10 + PlotBuilder.D / 2)
	local model = make("Model", { Name = "Plot" .. index }, plotsFolder)
	local parts = PlotBuilder.buildShell(model, origin)
	model.PrimaryPart = model.Floor
	table.insert(WorldBuilder.Plots, { index = index, cframe = origin, model = model, zone = parts.zone, spawnPad = parts.spawnPad, trim = parts.trim })
end

-- Gun Store: between the city and the dealer row.
local function buildGunStore(map)
	local m = make("Model", { Name = "GunStore" }, map)
	local origin = CFrame.new(80, 0, 230)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	make("Part", { Name = "Lot", Size = Vector3.new(110, 0.6, 90), CFrame = at(0, 0.3, 0), Material = Enum.Material.Concrete, Color = Color3.fromRGB(90, 92, 98) }, m)
	make("Part", { Name = "Building", Size = Vector3.new(70, 22, 40), CFrame = at(0, 11.6, 15), Material = Enum.Material.Brick, Color = Color3.fromRGB(58, 56, 60) }, m)
	make("Part", { Name = "Window", Size = Vector3.new(50, 10, 0.4), CFrame = at(0, 8, -5.2), Material = Enum.Material.Glass, Color = Color3.fromRGB(120, 170, 200), Transparency = 0.5, CanCollide = false }, m)
	local sign = make("Part", { Name = "Sign", Size = Vector3.new(56, 8, 1.2), CFrame = at(0, 26, -5.6), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(16, 16, 20) }, m)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = make("SurfaceGui", { Face = face, PixelsPerStud = 14, LightInfluence = 0 }, sign)
		make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "AMMO & ARMS", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 70, 60) }, g)
	end
	make("PointLight", { Range = 30, Brightness = 2, Color = Color3.fromRGB(255, 90, 70) }, sign)
	local counter = make("Part", { Name = "Counter", Size = Vector3.new(24, 4, 4), CFrame = at(0, 2.6, -12), Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 60, 40) }, m)
	make("ProximityPrompt", { Name = "GunStorePrompt", ActionText = "Shop Guns", ObjectText = "Ammo & Arms", MaxActivationDistance = 14, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E }, counter)
	-- gun rack display
	for i = 0, 4 do
		make("Part", { Name = "Rack", Size = Vector3.new(4, 0.4, 1), CFrame = at(-8 + i * 4, 6, -5.6), Material = Enum.Material.Metal, Color = Color3.fromRGB(40, 40, 44) }, m)
	end
	WorldBuilder.GunStore = m
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
	setupLighting()

	local map = Instance.new("Model")
	map.Name = "Map"
	make("Part", { Name = "Ground", Size = Vector3.new(2048, 4, 2048), Position = Vector3.new(0, -2, 0), Material = Enum.Material.Grass, Color = Color3.fromRGB(78, 120, 64) }, map)
	buildCity(map)
	buildGunStore(map)
	local plots = make("Folder", { Name = "Plots" }, map)
	for i = 1, WorldBuilder.PlotCount do
		buildPlot(i, plots)
	end
	-- the minimap needs the whole layout on every client
	pcall(function()
		map.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	map:SetAttribute("CityMinX", X_LINES[1])
	map:SetAttribute("CityMaxX", X_LINES[#X_LINES])
	map:SetAttribute("CityMinZ", CITY_Z_MIN)
	map:SetAttribute("DealerRoadZ", DEALER_ROAD_Z)
	map.Parent = workspace

	local spawn = make("SpawnLocation", { Name = "Spawn", Size = Vector3.new(16, 1, 16), Position = Vector3.new(0, 0.7, DEALER_ROAD_Z), Transparency = 1, CanCollide = false, Neutral = true, Duration = 0 }, workspace)
	spawn.Enabled = true
	return map
end

-- Slow day/night cycle: a full day is ~20 minutes.
function WorldBuilder.startDayNight()
	task.spawn(function()
		while true do
			task.wait(1)
			Lighting.ClockTime = (Lighting.ClockTime + 24 / 1200) % 24
		end
	end)
end

return WorldBuilder
