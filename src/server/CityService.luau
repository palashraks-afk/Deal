-- Rare cars and blueprint pieces appear around the city using the rarity weights in Config.
-- Each find glows in its rarity colour with a light beam visible from far away.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local VehicleService = require(script.Parent.VehicleService)

local CityService = {}
local rng = Random.new()

local finds = Instance.new("Folder")
finds.Name = "CityFinds"
finds.Parent = workspace

local function beacon(parent: Instance, attachTo: BasePart, rarity: string)
	local color = Config.Rarity[rarity].color
	local idx = Cars.rarityIndex(rarity)
	local a0 = Instance.new("Attachment")
	a0.Name = "BeaconBottom"
	a0.Parent = attachTo
	local a1 = Instance.new("Attachment")
	a1.Name = "BeaconTop"
	a1.Position = Vector3.new(0, 40 + idx * 25, 0)
	a1.Parent = attachTo
	local beam = Instance.new("Beam")
	beam.Name = "Beacon"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Width0 = 2 + idx * 0.6
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = attachTo
	local light = Instance.new("PointLight")
	light.Name = "RarityGlow"
	light.Color = color
	light.Range = 16 + idx * 2
	light.Brightness = 2
	light.Parent = attachTo

	local gui = Instance.new("BillboardGui")
	gui.Name = "RarityTag"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.MaxDistance = 400
	gui.AlwaysOnTop = true
	gui.Adornee = attachTo
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = parent:GetAttribute("Label") or rarity
	label.Parent = gui
	gui.Parent = parent
end

local function occupied(cf: CFrame): boolean
	for _, f in finds:GetChildren() do
		local pos
		if f:IsA("ObjectValue") then
			pos = f.Value and f.Value:GetPivot().Position
		else
			pos = f:GetPivot().Position
		end
		if pos and (pos - cf.Position).Magnitude < 60 then
			return true
		end
	end
	for model in VehicleService.Active do
		if model.PrimaryPart and (model.PrimaryPart.Position - cf.Position).Magnitude < 30 then
			return true
		end
	end
	return false
end

local function announce(text: string, color: Color3)
	Net.Notify:FireAllClients({ text = text, color = color, big = true })
end

local function spawnCar(cf: CFrame, rarity: string)
	local list = Cars.ByRarity[rarity]
	local stats = list[rng:NextInteger(1, #list)]
	local model = VehicleService.spawnCity(stats, cf)
	model:SetAttribute("Label", ("%s %s"):format(rarity:upper(), stats.name))
	model:SetAttribute("Kind", "Car")
	model:SetAttribute("CityFind", true)
	beacon(model, model.PrimaryPart, rarity)
	-- city cars are listed in CityFinds via an ObjectValue so the minimap can find them
	local ref = Instance.new("ObjectValue")
	ref.Name = "CarFind"
	ref.Value = model
	ref:SetAttribute("Rarity", rarity)
	ref:SetAttribute("Kind", "Car")
	ref.Parent = finds
	model.Destroying:Connect(function()
		ref:Destroy()
	end)
	return stats
end

local function spawnBlueprint(cf: CFrame, rarity: string)
	local partType = Config.BlueprintParts[rng:NextInteger(1, #Config.BlueprintParts)]
	local model = Instance.new("Model")
	model.Name = "Blueprint"
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("Kind", "Blueprint")
	model:SetAttribute("PartType", partType)
	model:SetAttribute("Label", ("%s %s BLUEPRINT"):format(rarity:upper(), partType:upper()))

	local scroll = Instance.new("Part")
	scroll.Name = "Scroll"
	scroll.Size = Vector3.new(3, 0.2, 4)
	scroll.CFrame = cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	scroll.Material = Enum.Material.Neon
	scroll.Color = Color3.fromRGB(70, 140, 255)
	scroll.Anchored = true
	scroll.CanCollide = false
	scroll.Parent = model
	local base = Instance.new("Part")
	base.Name = "Pedestal"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.6, 6, 6)
	base.CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	base.Material = Enum.Material.Neon
	base.Color = Config.Rarity[rarity].color
	base.Transparency = 0.3
	base.Anchored = true
	base.CanCollide = false
	base.Parent = model
	local hit = Instance.new("Part")
	hit.Name = "Pickup"
	hit.Size = Vector3.new(7, 7, 7)
	hit.CFrame = cf * CFrame.new(0, 3.5, 0)
	hit.Transparency = 1
	hit.Anchored = true
	hit.CanCollide = false
	hit.Parent = model
	model.PrimaryPart = hit
	beacon(model, hit, rarity)

	local taken = false
	hit.Touched:Connect(function(other)
		if taken then
			return
		end
		local char = other:FindFirstAncestorOfClass("Model")
		local player = char and Players:GetPlayerFromCharacter(char)
		-- also count players touching it while driving
		if not player then
			local node = other
			while node and node.Parent and node.Parent ~= workspace and node.Parent.Name ~= "Vehicles" do
				node = node.Parent
			end
			if node and node.Parent and node.Parent.Name == "Vehicles" and node:IsA("Model") then
				player = VehicleService.getDriver(node)
			end
		end
		local p = player and DataService.get(player)
		if not p then
			return
		end
		taken = true
		p.blueprints[partType][rarity] += 1
		VehicleService.notify(player, ("Picked up a %s %s blueprint!"):format(rarity, partType), Config.Rarity[rarity].color)
		DataService.push(player)
		model:Destroy()
	end)

	model.Parent = finds
	task.delay(Config.City.DespawnAfter, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function spawnOne()
	local points = WorldBuilder.SpawnPoints
	for _ = 1, 10 do
		local cf = points[rng:NextInteger(1, #points)]
		if not occupied(cf) then
			local rarity = Cars.rollRarity(rng)
			local announceIdx = Cars.rarityIndex(Config.City.AnnounceFrom)
			if rng:NextNumber() < Config.City.BlueprintChance then
				spawnBlueprint(cf, rarity)
				if Cars.rarityIndex(rarity) >= announceIdx then
					announce(("A %s blueprint appeared in the city!"):format(rarity), Config.Rarity[rarity].color)
				end
			else
				local stats = spawnCar(cf, rarity)
				if Cars.rarityIndex(rarity) >= announceIdx then
					announce(("A %s %s was spotted in the city!"):format(rarity, stats.name), Config.Rarity[rarity].color)
				end
			end
			return
		end
	end
end

function CityService.start()
	for _ = 1, math.floor(Config.City.MaxSpawns * 0.6) do
		spawnOne()
	end
	task.spawn(function()
		while true do
			task.wait(Config.City.SpawnInterval)
			if #finds:GetChildren() < Config.City.MaxSpawns then
				spawnOne()
			end
		end
	end)
end

return CityService
