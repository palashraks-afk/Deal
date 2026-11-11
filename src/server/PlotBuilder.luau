-- Builds a dealership plot and everything its upgrades add to it.
-- Layout (local space, -Z faces the dealer road, plot is 260 x 320 studs):
--   front lot   z -160..-100 : gate, spawn pad, garage zone, Base upgrade station, lock, catalogue
--   showroom    z  -95..  35 : 20 display pads (x -125..45) + 6 special lots (x 55..125)
--   corridor    z   35..  55 : Prize + Factory upgrade stations
--   prize vault z   55.. 155 : x -125..-10, up to 10 pedestals
--   factory     z   55.. 155 : x 0..125, up to 5 assembly lines
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Upgrades = require(Shared.Upgrades)

local PlotBuilder = {}

PlotBuilder.W, PlotBuilder.D = 260, 320
local W, D = PlotBuilder.W, PlotBuilder.D

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
PlotBuilder.make = make

local function blk(parent, size, cf, color, material, extra)
	local props = { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic }
	for k, v in extra or {} do
		props[k] = v
	end
	return make(props.Shape and "Part" or "Part", props, parent)
end

local function label(parent: BasePart, text: string, color: Color3, face)
	local g = make("SurfaceGui", { Face = face or Enum.NormalId.Front, PixelsPerStud = 24, LightInfluence = 0 }, parent)
	make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = color }, g)
	return g
end

---------------------------------------------------------------- props (one per upgrade look)
local C = {
	white = Color3.fromRGB(240, 240, 236),
	dark = Color3.fromRGB(28, 30, 36),
	metal = Color3.fromRGB(120, 124, 132),
	gold = Color3.fromRGB(230, 180, 40),
	wood = Color3.fromRGB(110, 76, 46),
	green = Color3.fromRGB(60, 140, 60),
	red = Color3.fromRGB(190, 30, 40),
	neonBlue = Color3.fromRGB(70, 170, 255),
	neonPink = Color3.fromRGB(255, 60, 170),
}

local Props = {}

function Props.palm(m, cf)
	for i = 0, 5 do
		blk(m, Vector3.new(1.4 - i * 0.1, 3, 1.4 - i * 0.1), cf * CFrame.new(math.sin(i * 0.4) * 0.6, 1.5 + i * 2.8, 0) * CFrame.Angles(0, 0, 0.06), C.wood, Enum.Material.Wood)
	end
	for a = 0, 5 do
		blk(m, Vector3.new(0.3, 0.4, 7), cf * CFrame.new(0, 17, 0) * CFrame.Angles(0, a * math.pi / 3, 0) * CFrame.Angles(-0.35, 0, 0) * CFrame.new(0, 0, -3.2), C.green, Enum.Material.Grass)
	end
end
function Props.planter(m, cf)
	blk(m, Vector3.new(6, 2.5, 6), cf * CFrame.new(0, 1.25, 0), Color3.fromRGB(80, 82, 88), Enum.Material.Concrete)
	make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(6, 5, 6), CFrame = cf * CFrame.new(0, 4, 0), Color = C.green, Material = Enum.Material.Grass, CanCollide = false }, m)
end
function Props.bench(m, cf)
	blk(m, Vector3.new(7, 0.4, 2), cf * CFrame.new(0, 1.8, 0), C.wood, Enum.Material.Wood)
	blk(m, Vector3.new(7, 2, 0.3), cf * CFrame.new(0, 2.8, 0.9), C.wood, Enum.Material.Wood)
	for _, x in { -3, 3 } do
		blk(m, Vector3.new(0.4, 1.8, 2), cf * CFrame.new(x, 0.9, 0), C.dark, Enum.Material.Metal)
	end
end
function Props.lamp(m, cf)
	blk(m, Vector3.new(0.6, 14, 0.6), cf * CFrame.new(0, 7, 0), C.dark, Enum.Material.Metal)
	local head = make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = cf * CFrame.new(0, 14.5, 0), Color = Color3.fromRGB(255, 230, 180), Material = Enum.Material.Neon, CanCollide = false }, m)
	make("PointLight", { Range = 30, Brightness = 1.5, Color = Color3.fromRGB(255, 220, 170) }, head)
end
function Props.hedge(m, cf)
	blk(m, Vector3.new(16, 3.5, 3), cf * CFrame.new(0, 1.75, 0), Color3.fromRGB(46, 110, 46), Enum.Material.Grass)
end
function Props.flowers(m, cf)
	blk(m, Vector3.new(10, 1, 4), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Ground)
	for i = -4, 4, 2 do
		make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = cf * CFrame.new(i, 1.4, (i % 4 == 0) and 0.8 or -0.8), Color = (i % 4 == 0) and C.neonPink or Color3.fromRGB(255, 220, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false }, m)
	end
end
function Props.rock(m, cf)
	for i = 1, 4 do
		make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2, 3) * (1 + i * 0.2), CFrame = cf * CFrame.new(i * 1.6 - 4, 0.6, (i % 2) * 1.5), Color = Color3.fromRGB(120, 116, 110), Material = Enum.Material.Slate }, m)
	end
end
function Props.fountain(m, cf)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 14, 14), CFrame = cf * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = C.white, Material = Enum.Material.Marble }, m)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 12, 12), CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 140, 220), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false }, m)
	blk(m, Vector3.new(1.4, 7, 1.4), cf * CFrame.new(0, 4.5, 0), C.white, Enum.Material.Marble)
	local top = make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = cf * CFrame.new(0, 8.5, 0), Color = C.white, Material = Enum.Material.Marble }, m)
	make("ParticleEmitter", { Rate = 40, Lifetime = NumberRange.new(1, 1.4), Speed = NumberRange.new(8, 10), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, -20, 0), Color = ColorSequence.new(Color3.fromRGB(150, 210, 255)), Size = NumberSequence.new(0.4), Transparency = NumberSequence.new(0.3) }, top)
end
function Props.statue(m, cf, color)
	blk(m, Vector3.new(5, 4, 5), cf * CFrame.new(0, 2, 0), C.white, Enum.Material.Marble)
	blk(m, Vector3.new(2.4, 7, 1.6), cf * CFrame.new(0, 7.5, 0), color or C.gold, Enum.Material.Metal, { Reflectance = 0.3 })
	make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = cf * CFrame.new(0, 12, 0), Color = color or C.gold, Material = Enum.Material.Metal, Reflectance = 0.3 }, m)
end
function Props.canopy(m, cf, color)
	for _, x in { -6, 6 } do
		for _, z in { -4, 4 } do
			blk(m, Vector3.new(0.5, 9, 0.5), cf * CFrame.new(x, 4.5, z), C.metal, Enum.Material.Metal)
		end
	end
	blk(m, Vector3.new(14, 0.4, 10), cf * CFrame.new(0, 9.2, 0), color or C.white, Enum.Material.Fabric)
end
function Props.flag(m, cf, color)
	blk(m, Vector3.new(0.4, 20, 0.4), cf * CFrame.new(0, 10, 0), C.metal, Enum.Material.Metal)
	blk(m, Vector3.new(6, 3.5, 0.1), cf * CFrame.new(3, 18, 0), color or C.red, Enum.Material.Fabric)
end
function Props.drums(m, cf)
	for i = 0, 2 do
		make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.2, 2.2), CFrame = cf * CFrame.new(i * 2.4 - 2.4, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = ({ C.red, Color3.fromRGB(40, 90, 170), Color3.fromRGB(230, 170, 30) })[i + 1], Material = Enum.Material.Metal }, m)
	end
end
function Props.tires(m, cf)
	for i = 0, 3 do
		make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 3, 3), CFrame = cf * CFrame.new(0, 0.5 + i, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = C.dark, Material = Enum.Material.SmoothPlastic }, m)
	end
end
function Props.lift(m, cf)
	for _, x in { -4, 4 } do
		blk(m, Vector3.new(1, 10, 1), cf * CFrame.new(x, 5, 0), Color3.fromRGB(220, 60, 40), Enum.Material.Metal)
	end
	blk(m, Vector3.new(9, 0.6, 12), cf * CFrame.new(0, 5, 0), C.metal, Enum.Material.DiamondPlate)
end
function Props.box(m, cf, color)
	blk(m, Vector3.new(4, 3, 2), cf * CFrame.new(0, 1.5, 0), color or C.red, Enum.Material.Metal)
end
function Props.vending(m, cf)
	local v = blk(m, Vector3.new(4, 7, 3), cf * CFrame.new(0, 3.5, 0), Color3.fromRGB(200, 30, 50), Enum.Material.SmoothPlastic)
	blk(m, Vector3.new(3, 4, 0.2), cf * CFrame.new(0, 4.2, -1.55), Color3.fromRGB(160, 220, 255), Enum.Material.Neon)
	return v
end
function Props.sign(m, cf, color, text)
	blk(m, Vector3.new(0.6, 8, 0.6), cf * CFrame.new(-5, 4, 0), C.metal, Enum.Material.Metal)
	blk(m, Vector3.new(0.6, 8, 0.6), cf * CFrame.new(5, 4, 0), C.metal, Enum.Material.Metal)
	local board = blk(m, Vector3.new(12, 5, 0.4), cf * CFrame.new(0, 9, 0), C.dark, Enum.Material.SmoothPlastic)
	label(board, text or "DEALZ", color or C.neonBlue)
	label(board, text or "DEALZ", color or C.neonBlue, Enum.NormalId.Back)
	make("SurfaceLight", { Face = Enum.NormalId.Front, Range = 12, Brightness = 1, Color = color or C.neonBlue }, board)
end
function Props.billboard(m, cf, color, text)
	blk(m, Vector3.new(1, 20, 1), cf * CFrame.new(0, 10, 0), C.metal, Enum.Material.Metal)
	local board = blk(m, Vector3.new(22, 10, 1), cf * CFrame.new(0, 24, 0), C.white, Enum.Material.SmoothPlastic)
	label(board, text or "BEST DEALZ IN TOWN", color or C.red)
	label(board, text or "BEST DEALZ IN TOWN", color or C.red, Enum.NormalId.Back)
end
function Props.balloons(m, cf)
	for i = 0, 10 do
		local a = i / 10 * math.pi
		make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = cf * CFrame.new(math.cos(a) * 9, math.sin(a) * 9 + 1, 0), Color = (i % 2 == 0) and C.red or C.white, Material = Enum.Material.SmoothPlastic, CanCollide = false }, m)
	end
end
function Props.searchlight(m, cf)
	blk(m, Vector3.new(3, 2, 3), cf * CFrame.new(0, 1, 0), C.dark, Enum.Material.Metal)
	local lamp = make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.4, 2.4), CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2.5), Color = C.white, Material = Enum.Material.Neon }, m)
	local a0 = make("Attachment", {}, lamp)
	local a1 = make("Attachment", { Position = Vector3.new(120, 0, 0) }, lamp)
	make("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 2.5, Width1 = 14, LightEmission = 1, LightInfluence = 0, Transparency = NumberSequence.new(0.6, 1), Color = ColorSequence.new(Color3.fromRGB(255, 250, 220)), FaceCamera = true }, lamp)
end
function Props.dancer(m, cf, color)
	for i = 0, 5 do
		blk(m, Vector3.new(1.6, 2.2, 1.6), cf * CFrame.new(math.sin(i) * 0.5, 1.1 + i * 2.1, 0) * CFrame.Angles(0, 0, math.sin(i * 1.3) * 0.25), color or Color3.fromRGB(255, 120, 20), Enum.Material.Fabric, { CanCollide = false })
	end
end
function Props.arrow(m, cf, color)
	local a = blk(m, Vector3.new(10, 3, 0.5), cf * CFrame.new(0, 6, 0), color or C.neonPink, Enum.Material.Neon)
	label(a, "DEALZ  >>>", Color3.new(1, 1, 1))
	blk(m, Vector3.new(0.5, 4.5, 0.5), cf * CFrame.new(0, 2.25, 0), C.metal, Enum.Material.Metal)
end
function Props.carpet(m, cf)
	blk(m, Vector3.new(8, 0.15, 40), cf * CFrame.new(0, 0.08, 0), Color3.fromRGB(170, 20, 30), Enum.Material.Fabric, { CanCollide = false })
end
function Props.ropes(m, cf)
	for i = -2, 2 do
		blk(m, Vector3.new(0.5, 3.5, 0.5), cf * CFrame.new(i * 5, 1.75, 0), C.gold, Enum.Material.Metal)
		make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = cf * CFrame.new(i * 5, 3.7, 0), Color = C.gold, Material = Enum.Material.Metal }, m)
	end
	blk(m, Vector3.new(20, 0.3, 0.3), cf * CFrame.new(0, 2.9, 0), Color3.fromRGB(150, 10, 30), Enum.Material.Fabric, { CanCollide = false })
end
function Props.chandelier(m, cf)
	local c = make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(6, 3, 6), CFrame = cf, Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.4, CanCollide = false }, m)
	make("PointLight", { Range = 30, Brightness = 2, Color = Color3.fromRGB(255, 230, 190) }, c)
	blk(m, Vector3.new(0.2, 4, 0.2), cf * CFrame.new(0, 3, 0), C.gold, Enum.Material.Metal, { CanCollide = false })
end
function Props.helipad(m, cf)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 26, 26), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(50, 52, 58), Material = Enum.Material.Concrete }, m)
	local h = blk(m, Vector3.new(12, 0.1, 12), cf * CFrame.new(0, 0.45, 0), C.white, Enum.Material.SmoothPlastic, { Transparency = 1 })
	label(h, "H", C.white, Enum.NormalId.Top)
end
function Props.camera(m, cf)
	blk(m, Vector3.new(0.4, 3, 0.4), cf * CFrame.new(0, 1.5, 0), C.dark, Enum.Material.Metal)
	blk(m, Vector3.new(1.2, 1, 2.2), cf * CFrame.new(0, 3.4, -0.6) * CFrame.Angles(-0.3, 0, 0), C.white, Enum.Material.SmoothPlastic)
	make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, CFrame = cf * CFrame.new(0, 3.2, -1.7), Color = C.red, Material = Enum.Material.Neon }, m)
end
function Props.bollards(m, cf)
	for i = -3, 3 do
		make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.2, 1.2), CFrame = cf * CFrame.new(i * 3, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(240, 200, 40), Material = Enum.Material.Metal }, m)
	end
end
function Props.booth(m, cf)
	blk(m, Vector3.new(6, 8, 6), cf * CFrame.new(0, 4, 0), C.white, Enum.Material.Concrete)
	blk(m, Vector3.new(6.2, 2.4, 6.2), cf * CFrame.new(0, 5.5, 0), Color3.fromRGB(120, 190, 230), Enum.Material.Glass, { Transparency = 0.4 })
	blk(m, Vector3.new(7, 0.6, 7), cf * CFrame.new(0, 8.3, 0), C.dark, Enum.Material.SmoothPlastic)
end
function Props.laser(m, cf)
	for i = 0, 3 do
		blk(m, Vector3.new(30, 0.15, 0.15), cf * CFrame.new(0, 1.5 + i * 2.2, 0), C.red, Enum.Material.Neon, { CanCollide = false, Transparency = 0.2 })
	end
end
function Props.tower(m, cf)
	for _, x in { -2, 2 } do
		for _, z in { -2, 2 } do
			blk(m, Vector3.new(0.6, 22, 0.6), cf * CFrame.new(x, 11, z), C.metal, Enum.Material.Metal)
		end
	end
	blk(m, Vector3.new(7, 5, 7), cf * CFrame.new(0, 24.5, 0), C.dark, Enum.Material.SmoothPlastic)
	Props.searchlight(m, cf * CFrame.new(0, 27, 0))
end
function Props.garageBay(m, cf, color, n)
	blk(m, Vector3.new(16, 12, 1), cf * CFrame.new(0, 6, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Concrete)
	local door = blk(m, Vector3.new(13, 9, 0.4), cf * CFrame.new(0, 4.6, -0.6), Color3.fromRGB(150, 155, 165), Enum.Material.CorrodedMetal)
	label(door, "BAY " .. tostring(n or ""), C.dark)
end
function Props.screen(m, cf, color, text)
	local s = blk(m, Vector3.new(14, 8, 0.5), cf * CFrame.new(0, 10, 0), C.dark, Enum.Material.SmoothPlastic)
	local g = make("SurfaceGui", { Face = Enum.NormalId.Front, PixelsPerStud = 20, LightInfluence = 0 }, s)
	local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or C.neonBlue }, g)
	make("UIGradient", { Color = ColorSequence.new(color or C.neonBlue, C.neonPink), Rotation = 30 }, f)
	make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text or "NEW ARRIVALS", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) }, f)
	blk(m, Vector3.new(0.6, 6, 0.6), cf * CFrame.new(0, 3, 0.4), C.metal, Enum.Material.Metal)
end
function Props.neonStrip(m, cf, color)
	blk(m, Vector3.new(40, 0.4, 0.4), cf, color or C.neonBlue, Enum.Material.Neon, { CanCollide = false })
end
function Props.robotArm(m, cf, color)
	blk(m, Vector3.new(3, 2, 3), cf * CFrame.new(0, 1, 0), C.dark, Enum.Material.Metal)
	blk(m, Vector3.new(1, 6, 1), cf * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, 0.3), color or Color3.fromRGB(255, 150, 30), Enum.Material.Metal)
	blk(m, Vector3.new(1, 5, 1), cf * CFrame.new(1.6, 8, 0) * CFrame.Angles(0, 0, -1.1), color or Color3.fromRGB(255, 150, 30), Enum.Material.Metal)
	make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = cf * CFrame.new(3.6, 8.6, 0), Color = C.metal, Material = Enum.Material.Metal }, m)
end
function Props.shelves(m, cf)
	blk(m, Vector3.new(10, 8, 3), cf * CFrame.new(0, 4, 0), C.metal, Enum.Material.DiamondPlate, { Transparency = 0.2 })
	for i = 0, 2 do
		Props.box(m, cf * CFrame.new(-3 + i * 3, 2.6 + i * 0.1, 0), ({ C.red, Color3.fromRGB(40, 90, 170), C.gold })[i + 1])
	end
end
function Props.crane(m, cf)
	blk(m, Vector3.new(1.2, 24, 1.2), cf * CFrame.new(0, 12, 0), Color3.fromRGB(240, 190, 30), Enum.Material.Metal)
	blk(m, Vector3.new(1, 1, 30), cf * CFrame.new(0, 24, -10), Color3.fromRGB(240, 190, 30), Enum.Material.Metal)
	blk(m, Vector3.new(0.2, 10, 0.2), cf * CFrame.new(0, 19, -20), C.dark, Enum.Material.Metal)
end

-- upgrade name -> prop builder
local LOOK = {
	["Palm Trees"] = "palm", Planters = "planter", Benches = "bench", ["Lamp Posts"] = "lamp", Hedges = "hedge",
	["Flower Beds"] = "flowers", ["Rock Garden"] = "rock", ["Water Feature"] = "fountain", Statue = "statue",
	["Bike Rack"] = "bollards", ["Trash Cans"] = "drums", ["Picnic Table"] = "bench", ["Shade Canopy"] = "canopy",
	["Flag Pole"] = "flag", Mailbox = "box", ["Parking Lines"] = "carpet", ["Tire Stack"] = "tires", ["Oil Drums"] = "drums",
	Toolbox = "box", ["Car Lift"] = "lift", ["Neon Logo"] = "sign", ["Rooftop Sign"] = "billboard", Awning = "canopy",
	["Wall Art"] = "screen", ["Clock Tower"] = "tower", ["Fence Lights"] = "neonStrip", ["Gravel Path"] = "rock",
	Kiosk = "booth", ["Vending Machine"] = "vending",
	["Street Banner"] = "flag", ["Balloon Arch"] = "balloons", Billboard = "billboard", ["Flag Row"] = "flag",
	Searchlights = "searchlight", ["Radio Ad"] = "sign", ["Inflatable Dancer"] = "dancer", ["Neon Arrow"] = "arrow",
	["Bus Stop"] = "canopy", ["Sidewalk Ads"] = "sign", ["Giant Sign"] = "billboard", ["TV Commercial"] = "screen",
	["Blimp Ad"] = "billboard", ["Grand Opening"] = "balloons", ["City Mural"] = "screen",
	["Red Carpet"] = "carpet", ["Velvet Ropes"] = "ropes", ["VIP Lounge"] = "canopy", ["Valet Stand"] = "booth",
	["Champagne Bar"] = "vending", Chandelier = "chandelier", ["Art Gallery"] = "screen", ["Private Booth"] = "booth",
	["Fountain Court"] = "fountain", Helipad = "helipad",
	Cameras = "camera", Bollards = "bollards", Alarm = "camera", ["Guard Booth"] = "booth", ["Spike Strip"] = "bollards",
	["Laser Fence"] = "laser", ["Steel Gate"] = "bollards", ["Watch Tower"] = "tower",
	["Polished Floors"] = "neonStrip", ["LED Ceiling"] = "chandelier", ["Glass Walls"] = "neonStrip", ["Car Turntables"] = "neonStrip",
	["Spot Lights"] = "chandelier", ["Marble Tiles"] = "neonStrip", ["Chrome Trim"] = "neonStrip", ["Sound System"] = "box",
	["Big Screens"] = "screen", ["Coffee Bar"] = "vending", ["Showroom Mirrors"] = "screen", ["Laser Show"] = "laser",
	["Gold Railings"] = "ropes", ["Smoke Machine"] = "drums", ["Hologram Signs"] = "screen",
	["Faster Conveyor"] = "neonStrip", ["Torque Wrenches"] = "box", ["Paint Booth"] = "booth", ["Welding Robot"] = "robotArm",
	["Engine Hoist"] = "crane", ["Parts Shelves"] = "shelves", ["Air Tools"] = "box", ["Laser Cutter"] = "laser",
	["Assembly Jig"] = "lift", ["Night Shift"] = "lamp", ["Quality Check"] = "screen", ["Detailing Bay"] = "lift",
	["Polish Station"] = "robotArm", ["Test Track"] = "carpet", ["Wax Machine"] = "robotArm", ["Bulk Deal"] = "shelves",
	["Supplier Contract"] = "shelves", ["Blueprint Scanner"] = "screen", ["Draft Table"] = "box", ["Engineer Hire"] = "booth",
	["Robot Arm"] = "robotArm", Forklift = "box", Crane = "crane", Drone = "lamp", ["Smart Screens"] = "screen",
}

---------------------------------------------------------------- spots
-- Deterministic places for each kind of upgrade prop (local CFrames).
local function ring(list, x0, x1, z, step, rot)
	for x = x0, x1, step do
		table.insert(list, CFrame.new(x, 1, z) * CFrame.Angles(0, rot or 0, 0))
	end
end
local SPOTS = { decor = {}, traffic = {}, rich = {}, security = {}, income = {}, garage = {} }
ring(SPOTS.decor, -122, 122, 156, 16, math.pi) -- along back wall (behind buildings)
for z = -150, 150, 22 do
	table.insert(SPOTS.decor, CFrame.new(-126, 1, z) * CFrame.Angles(0, math.pi / 2, 0))
end
ring(SPOTS.traffic, -120, 120, -172, 18) -- outside the front wall, facing the road
ring(SPOTS.rich, -36, 36, -140, 18)
for _, x in { -60, 60 } do
	table.insert(SPOTS.rich, CFrame.new(x, 1, -118))
end
for i = 1, 8 do
	table.insert(SPOTS.security, CFrame.new(-120 + (i - 1) * 34, 13, -158) * CFrame.Angles(0, math.pi, 0))
end
for i = 1, 15 do
	local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
	table.insert(SPOTS.income, CFrame.new(-108 + col * 38, row == 0 and 26 or 1, -88 + row * 60))
end
-- garage bays: outside the right wall
for i = 1, 10 do
	table.insert(SPOTS.garage, CFrame.new(135, 1, -150 + (i - 1) * 32) * CFrame.Angles(0, -math.pi / 2, 0))
end

---------------------------------------------------------------- shell
-- Pads: 20 display pads + 6 special lots. Index 1..20 = display, 21..26 = special.
PlotBuilder.DisplayPads = 20
PlotBuilder.SpecialPads = 6

function PlotBuilder.padCFrame(slot: number): CFrame
	if slot <= 20 then
		local col, row = (slot - 1) % 5, math.floor((slot - 1) / 5)
		return CFrame.new(-108 + col * 34, 1.2, -78 + row * 30) * CFrame.Angles(0, math.rad(200), 0)
	end
	local i = slot - 20
	return CFrame.new(90, 1.2, -82 + (i - 1) * 21) * CFrame.Angles(0, math.rad(-70), 0)
end

function PlotBuilder.pedestalCFrame(i: number): CFrame
	local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
	return CFrame.new(-112 + col * 22, 3, 80 + row * 46) * CFrame.Angles(0, math.rad(180), 0)
end

function PlotBuilder.lineCFrame(line: number): CFrame
	return CFrame.new(62, 1.2, 70 + (line - 1) * 20)
end

function PlotBuilder.stationCFrame(track: string): CFrame
	if track == "Base" then
		return CFrame.new(-82, 1, -128)
	elseif track == "Prize" then
		return CFrame.new(-70, 1, 45)
	end
	return CFrame.new(62, 1, 45)
end

function PlotBuilder.buildShell(model: Model, origin: CFrame)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	blk(model, Vector3.new(W, 1, D), at(0, 0.5, 0), Color3.fromRGB(64, 66, 72), Enum.Material.Asphalt).Name = "Floor"
	-- walls with a gate in front
	local wallH = 12
	local wallColor = Color3.fromRGB(196, 190, 180)
	local function wall(size, cf)
		blk(model, size, cf, wallColor, Enum.Material.Concrete).Name = "Wall"
		blk(model, Vector3.new(size.X + 0.4, 0.8, size.Z + 0.4), cf * CFrame.new(0, size.Y / 2 + 0.4, 0), Color3.fromRGB(60, 62, 70), Enum.Material.Metal).Name = "WallCap"
	end
	wall(Vector3.new(W, wallH, 2), at(0, wallH / 2 + 1, D / 2))
	wall(Vector3.new(2, wallH, D), at(-W / 2, wallH / 2 + 1, 0))
	wall(Vector3.new(2, wallH, D), at(W / 2, wallH / 2 + 1, 0))
	local gateW = 80
	local sideW = (W - gateW) / 2
	wall(Vector3.new(sideW, wallH, 2), at(-W / 2 + sideW / 2, wallH / 2 + 1, -D / 2))
	wall(Vector3.new(sideW, wallH, 2), at(W / 2 - sideW / 2, wallH / 2 + 1, -D / 2))
	make("Part", { Name = "LockBarrier", Size = Vector3.new(gateW, wallH + 6, 1), CFrame = at(0, (wallH + 6) / 2 + 1, -D / 2), Material = Enum.Material.ForceField, Color = Color3.fromRGB(80, 180, 255), Transparency = 1, CanCollide = false }, model)

	-- driveway stripes
	for i = -3, 3 do
		blk(model, Vector3.new(0.6, 0.05, 8), at(i * 10, 1.03, -140), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, { CanCollide = false }).Name = "Stripe"
	end

	-- showroom floor (open-air "used lot" until income upgrades dress it up)
	blk(model, Vector3.new(172, 0.4, 132), at(-40, 1.1, -30), Color3.fromRGB(150, 152, 158), Enum.Material.Concrete).Name = "ShowroomFloor"
	blk(model, Vector3.new(74, 0.4, 132), at(90, 1.1, -30), Color3.fromRGB(46, 40, 30), Enum.Material.Slate).Name = "SpecialFloor"

	local pads = make("Folder", { Name = "Pads" }, model)
	for slot = 1, PlotBuilder.DisplayPads + PlotBuilder.SpecialPads do
		local special = slot > PlotBuilder.DisplayPads
		local pad = make("Part", {
			Name = "Pad" .. slot,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, special and 19 or 26, special and 19 or 26),
			CFrame = origin * PlotBuilder.padCFrame(slot) * CFrame.Angles(0, 0, math.pi / 2),
			Material = Enum.Material.Metal,
			Color = special and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(70, 74, 82),
			Reflectance = 0.2,
			Transparency = 1,
			CanCollide = false,
		}, pads)
		pad:SetAttribute("Slot", slot)
		pad:SetAttribute("Special", special)
	end

	-- spawn pad, garage zone, lock, catalogue kiosk, gun rack
	local spawnPad = make("Part", { Name = "SpawnPad", Size = Vector3.new(24, 0.3, 30), CFrame = at(-22, 1.15, -128), Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 200, 120), Transparency = 0.65, CanCollide = false }, model)
	label(spawnPad, "CAR SPAWN", Color3.new(1, 1, 1), Enum.NormalId.Top)
	local zone = make("Part", { Name = "GarageZone", Size = Vector3.new(44, 14, 40), CFrame = at(50, 8, -128), Material = Enum.Material.ForceField, Color = Color3.fromRGB(255, 200, 40), Transparency = 0.75, CanCollide = false, CanQuery = false }, model)
	label(zone, "GARAGE\ndrive cars here", Color3.fromRGB(255, 220, 80), Enum.NormalId.Top)

	local lockPad = make("Part", { Name = "LockButton", Size = Vector3.new(6, 1.2, 6), CFrame = at(-118, 1.6, -148), Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 180, 255) }, model)
	make("ProximityPrompt", { Name = "LockPrompt", ActionText = "Lock Base", ObjectText = "Base Lock", HoldDuration = 0.5, MaxActivationDistance = 12, RequiresLineOfSight = false }, lockPad)

	local kiosk = make("Part", { Name = "CatalogKiosk", Size = Vector3.new(6, 8, 3), CFrame = at(-60, 5, -108), Material = Enum.Material.Glass, Color = Color3.fromRGB(40, 50, 70) }, model)
	label(kiosk, "BUY CARS", Color3.fromRGB(255, 220, 80))
	make("ProximityPrompt", { Name = "CatalogPrompt", ActionText = "Open Catalogue", ObjectText = "New Cars", MaxActivationDistance = 12, RequiresLineOfSight = false }, kiosk)

	-- sign over the gate
	local sign = blk(model, Vector3.new(gateW, 9, 1), at(0, wallH + 13, -D / 2), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic)
	sign.Name = "Sign"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = make("SurfaceGui", { Face = face, PixelsPerStud = 12, LightInfluence = 0 }, sign)
		make("TextLabel", { Name = "Label", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "FOR SALE - Claim this lot!", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) }, g)
	end
	for _, side in { -1, 1 } do
		blk(model, Vector3.new(1.5, wallH + 12, 1.5), at(side * (gateW / 2 + 1), (wallH + 12) / 2 + 1, -D / 2), Color3.fromRGB(50, 52, 56), Enum.Material.Metal).Name = "SignPost"
	end
	local trim = blk(model, Vector3.new(gateW + 4, 0.6, 1.2), at(0, wallH + 8.2, -D / 2), Color3.fromRGB(80, 170, 255), Enum.Material.Neon)
	trim.Name = "Trim"

	-- upgrade stations (button pads appear here)
	for _, track in Upgrades.Tracks do
		local st = make("Model", { Name = track .. "Station" }, model)
		local base = blk(st, Vector3.new(30, 0.6, 10), origin * PlotBuilder.stationCFrame(track) * CFrame.new(0, 0.3, 0), Color3.fromRGB(30, 32, 40), Enum.Material.DiamondPlate)
		base.Name = "Base"
		local board = blk(st, Vector3.new(30, 4, 0.6), origin * PlotBuilder.stationCFrame(track) * CFrame.new(0, 7, 5), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic)
		board.Name = "Board"
		label(board, track == "Base" and "DEALERSHIP UPGRADES" or (track == "Prize" and "PRIZE VAULT" or "CAR FACTORY"), track == "Prize" and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(120, 200, 255))
	end

	make("Folder", { Name = "Built" }, model) -- upgrade props go here
	return { spawnPad = spawnPad, zone = zone, trim = trim }
end

---------------------------------------------------------------- applying upgrades
local KIND_COLOR = {
	income = Color3.fromRGB(80, 170, 255),
	traffic = Color3.fromRGB(255, 80, 120),
	rich = Color3.fromRGB(230, 180, 40),
	security = Color3.fromRGB(255, 60, 60),
	decor = Color3.fromRGB(120, 220, 140),
}

local function buildVault(model, origin)
	local v = make("Model", { Name = "PrizeVault" }, model.Built)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	blk(v, Vector3.new(118, 0.6, 104), at(-68, 1.3, 105), Color3.fromRGB(26, 24, 30), Enum.Material.Marble, { Reflectance = 0.15 })
	for _, x in { -127, -9 } do
		blk(v, Vector3.new(2, 22, 104), at(x, 12, 105), Color3.fromRGB(40, 36, 44), Enum.Material.Metal)
	end
	blk(v, Vector3.new(120, 2, 106), at(-68, 23, 105), Color3.fromRGB(30, 28, 34), Enum.Material.Metal)
	local door = blk(v, Vector3.new(40, 18, 2), at(-68, 10, 54), Color3.fromRGB(180, 150, 60), Enum.Material.DiamondPlate, { Transparency = 0.6, CanCollide = false })
	door.Name = "VaultDoor"
	label(blk(v, Vector3.new(44, 4, 1), at(-68, 21, 53), Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic), "PRIZE VAULT", Color3.fromRGB(255, 200, 60))
end

local function buildFactory(model, origin)
	local f = make("Model", { Name = "Factory" }, model.Built)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	blk(f, Vector3.new(126, 0.6, 104), at(62, 1.3, 105), Color3.fromRGB(110, 112, 118), Enum.Material.DiamondPlate)
	blk(f, Vector3.new(2, 26, 104), at(126, 14, 105), Color3.fromRGB(150, 70, 50), Enum.Material.Brick)
	blk(f, Vector3.new(128, 2, 106), at(62, 27, 105), Color3.fromRGB(70, 74, 80), Enum.Material.CorrodedMetal)
	for i = 0, 3 do
		blk(f, Vector3.new(1.4, 26, 1.4), at(2 + i * 40, 14, 56), Color3.fromRGB(240, 190, 30), Enum.Material.Metal)
	end
	label(blk(f, Vector3.new(50, 5, 1), at(62, 24, 53), Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic), "DEALZ MOTOR WORKS", Color3.fromRGB(255, 160, 40))
end

local function buildLine(model, origin, line)
	local l = make("Model", { Name = "Line" .. line }, model.Built)
	local cf = origin * PlotBuilder.lineCFrame(line)
	local belt = blk(l, Vector3.new(100, 1, 9), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(30, 30, 34), Enum.Material.DiamondPlate)
	belt.Name = "Belt"
	for _, z in { -5, 5 } do
		blk(l, Vector3.new(100, 1.4, 0.6), cf * CFrame.new(0, 1, z), Color3.fromRGB(240, 190, 30), Enum.Material.Metal)
	end
	local gate = blk(l, Vector3.new(2, 10, 12), cf * CFrame.new(-40, 5, 0), Color3.fromRGB(60, 64, 72), Enum.Material.Metal)
	gate.Name = "Arch"
	blk(l, Vector3.new(2.2, 0.6, 12.2), cf * CFrame.new(-40, 10, 0), Color3.fromRGB(255, 140, 30), Enum.Material.Neon)
end

-- Build the prop for one upgrade on a plot.
function PlotBuilder.apply(model: Model, origin: CFrame, u)
	local built = model.Built
	if u.track == "Base" then
		if u.kind == "slot" or u.kind == "special" then
			return -- pads are shown by the tycoon refresh
		end
		local spots = SPOTS[u.kind]
		if not spots then
			return
		end
		local cf = origin * spots[(u.nth - 1) % #spots + 1]
		local m = make("Model", { Name = u.name }, built)
		if u.kind == "garage" then
			Props.garageBay(m, cf, nil, u.nth)
		else
			local look = Props[LOOK[u.name] or "sign"] or Props.sign
			look(m, cf, KIND_COLOR[u.kind], string.upper(u.name))
		end
	elseif u.track == "Factory" then
		if u.kind == "unlock" then
			buildFactory(model, origin)
			buildLine(model, origin, 1)
		elseif u.kind == "line" then
			buildLine(model, origin, u.nth + 1)
		else
			-- machines along the back of the factory
			local i = u.index
			local cf = origin * CFrame.new(10 + (i % 12) * 10, 1.6, 150 - math.floor(i / 12) % 3 * 4) * CFrame.Angles(0, math.pi, 0)
			local m = make("Model", { Name = u.name }, built)
			local look = Props[LOOK[u.name] or "box"] or Props.box
			look(m, cf, Color3.fromRGB(255, 150, 30), string.upper(u.name))
		end
	elseif u.track == "Prize" then
		if u.kind == "unlock" then
			buildVault(model, origin)
		elseif u.kind == "glow" then
			local m = make("Model", { Name = u.name }, built)
			for i = 1, 10 do
				local cf = origin * PlotBuilder.pedestalCFrame(i)
				local c = make("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = cf * CFrame.new(0, 17, 0), Color = u.name == "Diamond Vault" and Color3.fromRGB(180, 230, 255) or Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, CanCollide = false }, m)
				make("SpotLight", { Face = Enum.NormalId.Bottom, Range = 22, Angle = 50, Brightness = 3, Color = c.Color }, c)
			end
		elseif u.kind == "laser" then
			local m = make("Model", { Name = u.name }, built)
			Props.laser(m, origin * CFrame.new(-68, 1, 58))
			Props.laser(m, origin * CFrame.new(-96, 1, 58))
			Props.laser(m, origin * CFrame.new(-40, 1, 58))
		end
	end
end

-- Pedestals for the prize room (shown up to the unlocked count).
function PlotBuilder.pedestal(parent, origin: CFrame, i: number)
	local cf = origin * PlotBuilder.pedestalCFrame(i)
	local m = make("Model", { Name = "Pedestal" .. i }, parent)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 18, 18), CFrame = cf * CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(20, 20, 24), Material = Enum.Material.Marble, Reflectance = 0.2 }, m)
	make("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 18.6, 18.6), CFrame = cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(230, 180, 40), Material = Enum.Material.Neon, CanCollide = false }, m)
	return m
end

return PlotBuilder
