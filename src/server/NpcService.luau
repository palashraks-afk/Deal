-- NPC customers. They walk in from the dealer road, browse up to a few cars, and buy if
-- the price you set looks fair to them (and they can afford it). Foot-traffic upgrades
-- bring more of them; "rich" upgrades and special lots make them pay more.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)

local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlotBuilder = require(script.Parent.PlotBuilder)
local Tycoon = require(script.Parent.TycoonService)

local NpcService = {}
local rng = Random.new()
local folder = Instance.new("Folder")
folder.Name = "Customers"
folder.Parent = workspace

local counts = {} -- [plot] = number alive
local total = 0

-- Default R15 walk / idle animations (from Roblox's built-in Animate script).
local WALK_ANIM = "rbxassetid://913402848"
local IDLE_ANIM = "rbxassetid://507766666"

local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(234, 184, 146), Color3.fromRGB(200, 140, 100), Color3.fromRGB(150, 98, 64), Color3.fromRGB(96, 62, 42) }
local SHIRT = { Color3.fromRGB(30, 60, 140), Color3.fromRGB(180, 30, 40), Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 30, 34), Color3.fromRGB(40, 120, 70), Color3.fromRGB(230, 170, 40), Color3.fromRGB(120, 60, 160), Color3.fromRGB(240, 120, 160) }
local PANTS = { Color3.fromRGB(30, 34, 60), Color3.fromRGB(40, 40, 44), Color3.fromRGB(120, 100, 80), Color3.fromRGB(70, 90, 120) }

-- Budget tiers (weights shift up with "rich" upgrades).
local BUDGETS = {
	{ 40000, 50, "$" },
	{ 100000, 26, "$$" },
	{ 300000, 13, "$$$" },
	{ 1000000, 6, "$$$$" },
	{ 5000000, 3.5, "VIP" },
	{ 50000000, 1.5, "BILLIONAIRE" },
}

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
	rig.Name = "Customer"
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = 11
	template = rig
	return template
end

local function rollBudget(richness: number)
	local total = 0
	local weights = {}
	for i, b in BUDGETS do
		local w = b[2] * (1 + richness * (i - 1) * 1.5)
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	for i, b in BUDGETS do
		pick -= weights[i]
		if pick <= 0 then
			return b[1] * rng:NextNumber(0.7, 1.3), b[3]
		end
	end
	return BUDGETS[1][1], BUDGETS[1][3]
end

local function bubble(npc: Model, text: string, color: Color3, seconds: number?)
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
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	Instance.new("UICorner").Parent = label
	gui.Parent = head
	if seconds then
		task.delay(seconds, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end
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
	game:GetService("Debris"):AddItem(p, 3)
end

local function walkTo(npc: Model, pos: Vector3, timeout: number?)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
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
		-- stuck: hop to the target
		npc:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	end
	return npc.Parent ~= nil
end

local function visit(plot, owner: Player)
	local base = getTemplate()
	if not base then
		return
	end
	local npc = base:Clone()
	local hum = npc:FindFirstChildOfClass("Humanoid")
	-- look
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = SHIRT[rng:NextInteger(1, #SHIRT)]
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

	local e = DataService.effects(owner)
	local budget, tier = rollBudget(e and e.richness or 0)
	local origin = plot.cframe
	local roadSide = origin * CFrame.new(rng:NextNumber(-60, 60), 3, -PlotBuilder.D / 2 - 24)
	local gate = origin * CFrame.new(rng:NextNumber(-20, 20), 3, -PlotBuilder.D / 2 + 12)
	npc:PivotTo(roadSide)
	npc.Parent = folder
	pcall(function()
		npc.HumanoidRootPart:SetNetworkOwner(nil)
	end)

	-- animations
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local walk, idle
	pcall(function()
		local wa = Instance.new("Animation")
		wa.AnimationId = WALK_ANIM
		walk = animator:LoadAnimation(wa)
		walk.Looped = true
		local ia = Instance.new("Animation")
		ia.AnimationId = IDLE_ANIM
		idle = animator:LoadAnimation(ia)
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
	bubble(npc, tier, Color3.fromRGB(40, 160, 70), 5)

	counts[plot] = (counts[plot] or 0) + 1
	total += 1
	local function finish()
		counts[plot] = math.max(0, (counts[plot] or 1) - 1)
		total = math.max(0, total - 1)
		if npc.Parent then
			npc:Destroy()
		end
	end

	task.spawn(function()
		if not walkTo(npc, gate.Position) then
			return finish()
		end
		local bought = false
		for _ = 1, Config.Npc.CarsPerVisit do
			if Tycoon.ownerOf(plot) ~= owner then
				break
			end
			local listings = Tycoon.listings(owner)
			if #listings == 0 then
				bubble(npc, "Nothing here...", Color3.fromRGB(120, 120, 120), 3)
				break
			end
			-- rich customers head for special lots first
			local pick = listings[rng:NextInteger(1, #listings)]
			if budget > 1e6 then
				for _, l in listings do
					if l.special then
						pick = l
					end
				end
			end
			local carPos = pick.model.PrimaryPart and pick.model.PrimaryPart.Position
			if not carPos then
				break
			end
			local side = (CFrame.new(carPos) * CFrame.new(rng:NextNumber(-1, 1) * 9, 0, 8)).Position
			if not walkTo(npc, Vector3.new(side.X, carPos.Y, side.Z)) then
				return finish()
			end
			if npc.PrimaryPart then
				npc:PivotTo(CFrame.lookAt(npc.PrimaryPart.Position, Vector3.new(carPos.X, npc.PrimaryPart.Position.Y, carPos.Z)))
			end
			bubble(npc, "Hmm... " .. Cars.money(pick.price), Color3.fromRGB(60, 60, 70))
			task.wait(rng:NextNumber(Config.Npc.Browse[1], Config.Npc.Browse[2]))
			if not npc.Parent then
				return finish()
			end
			-- decide
			local ratio = pick.price / math.max(1, pick.value)
			local tolerance = Config.Npc.BaseTolerance + (e and e.richness or 0) + (pick.special and Config.Npc.SpecialLotBonus or 0)
			local chance = math.clamp(1.3 - ratio / tolerance, 0.03, 0.92)
			if pick.price <= budget and rng:NextNumber() < chance then
				local ok = Tycoon.npcBuy(owner, pick.slot)
				if ok then
					bought = true
					bubble(npc, "SOLD! " .. Cars.money(pick.price), Color3.fromRGB(30, 170, 70), 4)
					confetti(carPos + Vector3.new(0, 6, 0))
					break
				end
			elseif pick.price > budget then
				bubble(npc, "Can't afford it", Color3.fromRGB(200, 60, 60), 2.5)
			else
				bubble(npc, ratio > tolerance and "Too pricey!" or "Not today", Color3.fromRGB(200, 120, 40), 2.5)
			end
			task.wait(1.5)
		end
		if not bought then
			task.wait(0.5)
		end
		walkTo(npc, gate.Position)
		walkTo(npc, roadSide.Position + Vector3.new(rng:NextNumber(-80, 80), 0, -10))
		finish()
	end)
end

function NpcService.start()
	task.spawn(getTemplate)
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
					if timers[plot] >= interval and (counts[plot] or 0) < maxHere and total < Config.Npc.MaxTotal then
						timers[plot] = 0
						task.spawn(visit, plot, owner)
					end
				end
			end
		end
	end)
end

return NpcService
