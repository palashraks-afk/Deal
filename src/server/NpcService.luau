-- NPCs.
--  * Customers walk into dealerships, browse, and buy if your price looks fair to them.
--    Each has a personality (budget, how picky they are, what they say).
--  * Pedestrians walk the sidewalks of every area and react to players nearby.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Tycoon = require(script.Parent.TycoonService)

local NpcService = {}
local rng = Random.new()
local folder = Instance.new("Folder")
folder.Name = "Customers"
folder.Parent = workspace
local walkers = Instance.new("Folder")
walkers.Name = "Pedestrians"
walkers.Parent = workspace

local counts = {} -- [plot] = number alive
local totalCustomers = 0

-- Default R15 walk / idle animations (Roblox's built-in Animate script).
local WALK_ANIM = "rbxassetid://913402848"
local IDLE_ANIM = "rbxassetid://507766666"

local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(200, 140, 100), Color3.fromRGB(150, 98, 64), Color3.fromRGB(96, 62, 42) }
local PANTS = { Color3.fromRGB(30, 34, 60), Color3.fromRGB(40, 40, 44), Color3.fromRGB(120, 100, 80), Color3.fromRGB(70, 90, 120), Color3.fromRGB(200, 190, 170) }

-- Customer personalities: budget range, how much over value they'll pay, outfit, lines.
local TYPES = {
	{
		name = "Bargain Hunter",
		weight = 30,
		budget = { 15000, 60000 },
		tolerance = 0.95,
		shirt = Color3.fromRGB(200, 200, 200),
		hello = { "Got anything cheap?", "Just looking...", "What's your best deal?" },
		buy = { "Finally, a fair price!", "I'll take it!", "Deal of the century!" },
		no = { "Way too expensive!", "I could get this cheaper online.", "Nah, overpriced." },
	},
	{
		name = "Family Driver",
		weight = 24,
		budget = { 40000, 150000 },
		tolerance = 1.15,
		shirt = Color3.fromRGB(70, 130, 200),
		hello = { "Need something for the kids.", "Is it safe?", "How's the mileage?" },
		buy = { "The kids will love it!", "Perfect family car.", "Sold, wrap it up!" },
		no = { "Hmm, not for us.", "Too flashy for me.", "I'll think about it." },
	},
	{
		name = "Street Racer",
		weight = 16,
		budget = { 80000, 600000 },
		tolerance = 1.25,
		shirt = Color3.fromRGB(30, 30, 34),
		hello = { "How fast does it go?", "I need SPEED.", "Does it drift?" },
		buy = { "Let's gooo!", "This thing is FAST!", "See you on the track!" },
		no = { "Too slow, bro.", "Not enough horsepower.", "Nah, weak." },
	},
	{
		name = "Collector",
		weight = 10,
		budget = { 400000, 6000000 },
		tolerance = 1.4,
		shirt = Color3.fromRGB(120, 60, 140),
		hello = { "Anything rare today?", "I only buy the best.", "Show me your finest." },
		buy = { "A fine addition to my collection.", "Exquisite.", "Worth every penny." },
		no = { "Common trash.", "Not rare enough.", "Disappointing." },
	},
	{
		name = "Influencer",
		weight = 12,
		budget = { 150000, 2000000 },
		tolerance = 1.3,
		shirt = Color3.fromRGB(240, 120, 170),
		hello = { "Is this content-worthy?", "Smash that like button!", "Hey chat, look at this!" },
		buy = { "OMG new car reveal!", "Chat, we're buying it!", "This is going viral!" },
		no = { "Not aesthetic enough.", "Chat says no.", "Mid." },
	},
	{
		name = "Billionaire",
		weight = 4,
		budget = { 3000000, 60000000 },
		tolerance = 1.6,
		shirt = Color3.fromRGB(230, 180, 40),
		hello = { "I'll buy the whole lot.", "Money is no object.", "Where's the hypercar?" },
		buy = { "Have it delivered.", "Pocket change.", "I'll take two. Just kidding. One." },
		no = { "Beneath me.", "I have three of these.", "Bring me something better." },
	},
}

local PEDESTRIAN_LINES = {
	"Nice ride!",
	"Is that a Bugotti?!",
	"Drive safe!",
	"Heard there's a Legendary near the port...",
	"Watch where you're going!",
	"The gun store is downtown on the boulevard.",
	"Have you seen the desert speedway?",
	"I saw a glowing car in the hills!",
	"Beach is nice today.",
	"Whose dealership is the best around here?",
	"I'm saving up for a Ferrano.",
	"Get off the sidewalk!",
}
local SHOT_LINES = { "HEY!", "Watch it!", "Are you crazy?!", "Help!", "Not cool!" }

local template
local function getTemplate()
	if template then
		return template
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[NpcService] couldn't build NPC rig:", rig)
		return nil
	end
	rig.Name = "NPC"
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = 11
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	template = rig
	return template
end

local function dress(npc: Model, shirt: Color3)
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local pants = PANTS[rng:NextInteger(1, #PANTS)]
	for _, part in npc:GetChildren() do
		if part:IsA("BasePart") then
			local n = part.Name
			if n:find("Torso") or n:find("UpperArm") then
				part.Color = shirt
			elseif n:find("Leg") or n:find("Foot") then
				part.Color = pants
			elseif n ~= "HumanoidRootPart" then
				part.Color = skin
			end
		end
	end
	local bc = npc:FindFirstChildOfClass("BodyColors")
	if bc then
		bc:Destroy()
	end
end

local function animate(npc: Model)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local walk
	pcall(function()
		local wa = Instance.new("Animation")
		wa.AnimationId = WALK_ANIM
		walk = animator:LoadAnimation(wa)
		walk.Looped = true
		local ia = Instance.new("Animation")
		ia.AnimationId = IDLE_ANIM
		local idle = animator:LoadAnimation(ia)
		idle.Looped = true
		idle:Play()
	end)
	hum.Running:Connect(function(speed)
		if walk then
			if speed > 0.5 and not walk.IsPlaying then
				walk:Play(0.2)
			elseif speed <= 0.5 and walk.IsPlaying then
				walk:Stop(0.2)
			end
		end
	end)
end

local function bubble(npc: Model, text: string, color: Color3?, seconds: number?)
	local head = npc:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(190, 46)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.TextColor3 = color or Color3.fromRGB(30, 30, 36)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	Instance.new("UICorner").Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = label
	gui.Parent = head
	task.delay(seconds or 3.5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end
NpcService.bubble = bubble

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function confetti(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Speed = NumberRange.new(14, 22)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Size = NumberSequence.new(0.5)
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 60)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 160, 255)) })
	e.Parent = p
	e:Emit(60)
	Debris:AddItem(p, 3)
end

local function walkTo(npc: Model, pos: Vector3, timeout: number?)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if not hum or not npc.Parent then
		return false
	end
	hum:MoveTo(pos)
	local done = false
	local conn = hum.MoveToFinished:Connect(function()
		done = true
	end)
	local t0 = os.clock()
	while not done and npc.Parent and os.clock() - t0 < (timeout or 10) do
		task.wait(0.2)
	end
	conn:Disconnect()
	if not done and npc.Parent and npc.PrimaryPart then
		npc:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	end
	return npc.Parent ~= nil
end

local function spawnRig(shirt: Color3, at: CFrame, parent: Instance): Model?
	local base = getTemplate()
	if not base then
		return nil
	end
	local npc = base:Clone()
	dress(npc, shirt)
	npc:PivotTo(at)
	npc.Parent = parent
	pcall(function()
		npc.HumanoidRootPart:SetNetworkOwner(nil)
	end)
	animate(npc)
	return npc
end

---------------------------------------------------------------- customers
local function rollType(richness: number)
	local total = 0
	local weights = {}
	for i, t in TYPES do
		local w = t.weight * (1 + richness * (i - 1) * 1.2)
		weights[i] = w
		total += w
	end
	local p = rng:NextNumber() * total
	for i, t in TYPES do
		p -= weights[i]
		if p <= 0 then
			return t
		end
	end
	return TYPES[1]
end

local function visit(plot, owner: Player)
	local e = DataService.effects(owner)
	local kind = rollType(e and e.richness or 0)
	local budget = rng:NextNumber(kind.budget[1], kind.budget[2]) * (1 + (e and e.richness or 0))
	local origin = plot.cframe
	local roadSide = origin * CFrame.new(rng:NextNumber(-60, 60), 3, -PlotBuilder.D / 2 - 26)
	local gate = origin * CFrame.new(rng:NextNumber(-20, 20), 3, -PlotBuilder.D / 2 + 12)
	local npc = spawnRig(kind.shirt, roadSide, folder)
	if not npc then
		return
	end
	npc.Name = kind.name
	npc:SetAttribute("Kind", "Customer")
	bubble(npc, kind.name .. ": " .. pick(kind.hello), Color3.fromRGB(40, 120, 70), 4)

	counts[plot] = (counts[plot] or 0) + 1
	totalCustomers += 1
	local function finish()
		counts[plot] = math.max(0, (counts[plot] or 1) - 1)
		totalCustomers = math.max(0, totalCustomers - 1)
		if npc.Parent then
			npc:Destroy()
		end
	end

	task.spawn(function()
		if not walkTo(npc, gate.Position) then
			return finish()
		end
		for _ = 1, Config.Npc.CarsPerVisit do
			if Tycoon.ownerOf(plot) ~= owner then
				break
			end
			local listings = Tycoon.listings(owner)
			if #listings == 0 then
				bubble(npc, "Empty lot? I'm leaving.", Color3.fromRGB(120, 120, 120), 3)
				break
			end
			local choice = listings[rng:NextInteger(1, #listings)]
			if budget > 1e6 then
				for _, l in listings do
					if l.special then
						choice = l
					end
				end
			end
			local carPos = choice.model.PrimaryPart and choice.model.PrimaryPart.Position
			if not carPos then
				break
			end
			local side = (CFrame.new(carPos) * CFrame.new(rng:NextNumber(-1, 1) * 11, 0, 10)).Position
			if not walkTo(npc, Vector3.new(side.X, carPos.Y, side.Z)) then
				return finish()
			end
			if npc.PrimaryPart then
				npc:PivotTo(CFrame.lookAt(npc.PrimaryPart.Position, Vector3.new(carPos.X, npc.PrimaryPart.Position.Y, carPos.Z)))
			end
			bubble(npc, "Hmm... " .. Cars.money(choice.price) .. "?", Color3.fromRGB(60, 60, 70), 5)
			task.wait(rng:NextNumber(Config.Npc.Browse[1], Config.Npc.Browse[2]))
			if not npc.Parent then
				return finish()
			end
			local ratio = choice.price / math.max(1, choice.value)
			local tolerance = kind.tolerance + (e and e.richness or 0) + (choice.special and Config.Npc.SpecialLotBonus or 0)
			local chance = math.clamp(1.3 - ratio / tolerance, 0.03, 0.92)
			if choice.price <= budget and rng:NextNumber() < chance then
				local ok = Tycoon.npcBuy(owner, choice.slot)
				if ok then
					bubble(npc, pick(kind.buy), Color3.fromRGB(30, 170, 70), 4)
					confetti(carPos + Vector3.new(0, 6, 0))
					Net.Effect:FireAllClients("Sale", carPos)
					task.wait(1.5)
					break
				end
			else
				bubble(npc, choice.price > budget and "Can't afford that..." or pick(kind.no), Color3.fromRGB(200, 90, 40), 3)
			end
			task.wait(1.5)
		end
		walkTo(npc, gate.Position)
		walkTo(npc, roadSide.Position + Vector3.new(rng:NextNumber(-80, 80), 0, -10))
		finish()
	end)
end

---------------------------------------------------------------- pedestrians
local function pedestrian(path: { Vector3 })
	local shirt = Color3.fromHSV(rng:NextNumber(), rng:NextNumber(0.3, 0.8), rng:NextNumber(0.4, 0.95))
	local npc = spawnRig(shirt, CFrame.new(path[1] + Vector3.new(0, 3, 0)), walkers)
	if not npc then
		return
	end
	npc:SetAttribute("Kind", "Pedestrian")
	npc:FindFirstChildOfClass("Humanoid").WalkSpeed = rng:NextNumber(7, 10)
	task.spawn(function()
		local i = 1
		local lastTalk = 0
		while npc.Parent do
			i = i % #path + 1
			local target = path[i] + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
			walkTo(npc, target, 30)
			-- chat with nearby players now and then
			if os.clock() - lastTalk > 12 and npc.PrimaryPart then
				for _, p in Players:GetPlayers() do
					local c = p.Character
					if c and c.PrimaryPart and (c.PrimaryPart.Position - npc.PrimaryPart.Position).Magnitude < 30 then
						bubble(npc, pick(PEDESTRIAN_LINES), nil, 4)
						lastTalk = os.clock()
						break
					end
				end
			end
		end
	end)
end

function NpcService.react(npc: Model)
	bubble(npc, pick(SHOT_LINES), Color3.fromRGB(220, 40, 40), 2)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum and npc.PrimaryPart then
		hum.WalkSpeed = 20
		hum:MoveTo(npc.PrimaryPart.Position + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40)))
		task.delay(3, function()
			if hum.Parent then
				hum.WalkSpeed = 9
			end
		end)
	end
end

function NpcService.start()
	task.spawn(function()
		getTemplate()
		-- pedestrians on sidewalks across the map
		for n = 1, Config.Npc.Pedestrians do
			local path = WorldBuilder.PedestrianPaths[(n - 1) % #WorldBuilder.PedestrianPaths + 1]
			if path then
				pedestrian(path)
				task.wait(0.15)
			end
		end
	end)
	local timers = {}
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in WorldBuilder.Plots do
				local owner = Tycoon.ownerOf(plot)
				local e = owner and DataService.effects(owner)
				if owner and e then
					local maxHere = math.clamp(Config.Npc.MaxPerPlot + math.floor((e.traffic - 1) * 4), 1, Config.Npc.MaxPerPlotCap)
					timers[plot] = (timers[plot] or 0) + 1
					local interval = Config.Npc.SpawnEvery / e.traffic
					if timers[plot] >= interval and (counts[plot] or 0) < maxHere and totalCustomers < Config.Npc.MaxTotal then
						timers[plot] = 0
						task.spawn(visit, plot, owner)
					end
				end
			end
		end
	end)
end

return NpcService
