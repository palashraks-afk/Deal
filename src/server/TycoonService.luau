-- Plots, dealership levels, showroom display, passive income, NPC buyers, the
-- catalogue, base locks and showroom raids.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local CarBuilder = require(Shared.CarBuilder)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local VehicleService = require(script.Parent.VehicleService)

local Tycoon = {}
local plotOwner = {} -- [plot] = player
local playerPlot = {} -- [player] = plot
local joinedAt = {} -- [player] = os.clock()
local lockState = {} -- [plot] = { lockedUntil, readyAt }
local rng = Random.new()

local notify = VehicleService.notify

function Tycoon.plotOf(player: Player)
	return playerPlot[player]
end

local function levelInfo(profile)
	return Config.Levels[profile.level]
end

local function unlockedSlots(profile): number
	return levelInfo(profile).slots
end

function Tycoon.slotOf(player: Player, uid: string): number?
	local p = DataService.get(player)
	if not p then
		return nil
	end
	for slot, s in p.showroom do
		if s.uid == uid then
			return slot
		end
	end
	return nil
end

function Tycoon.clearSlotFor(player: Player, uid: string)
	local p = DataService.get(player)
	if not p then
		return
	end
	for slot, s in p.showroom do
		if s.uid == uid then
			p.showroom[slot] = nil
		end
	end
end

local function isLocked(plot): boolean
	local st = lockState[plot]
	return st ~= nil and st.lockedUntil > os.clock()
end

local function updateSign(plot, player: Player?)
	local text = "FOR SALE - Claim this lot!"
	if player then
		local p = DataService.get(player)
		text = ("%s's %s"):format(player.DisplayName, p and levelInfo(p).name or "Dealership")
	end
	for _, g in plot.model.Sign:GetChildren() do
		if g:IsA("SurfaceGui") then
			g.Label.Text = text
		end
	end
end

-- Rebuild the showroom display cars for a player's plot.
function Tycoon.refreshPlot(player: Player)
	local plot = playerPlot[player]
	local p = DataService.get(player)
	if not plot or not p then
		return
	end
	local displays = plot.model:FindFirstChild("Displays")
	if displays then
		displays:Destroy()
	end
	displays = Instance.new("Folder")
	displays.Name = "Displays"

	local unlocked = unlockedSlots(p)
	for _, pad in plot.model.Pads:GetChildren() do
		local slot = pad:GetAttribute("Slot")
		local open = slot <= unlocked
		pad.Transparency = open and 0 or 0.85
		pad.Color = open and Color3.fromRGB(60, 64, 72) or Color3.fromRGB(30, 30, 34)
		local s = p.showroom[slot]
		if open and s then
			local entry = DataService.findCar(player, s.uid)
			if entry and not entry.inTransit then
				local stats = Cars.resolve(entry)
				local model = CarBuilder.build(stats, Cars.paintOf(entry), { drivable = false })
				local _, size = model:GetBoundingBox()
				local rootOffset = model.PrimaryPart.Position.Y - (model:GetBoundingBox().Position.Y - size.Y / 2)
				local padTop = pad.Position.Y + pad.Size.X / 2
				model:PivotTo(CFrame.new(pad.Position.X, padTop + rootOffset, pad.Position.Z) * CFrame.Angles(0, math.rad(200), 0))
				model:SetAttribute("Slot", slot)
				model:SetAttribute("OwnerUserId", player.UserId)
				model:SetAttribute("CarName", stats.name or (stats.brand .. " " .. stats.model))

				-- price tag
				local tag = Instance.new("BillboardGui")
				tag.Size = UDim2.fromOffset(220, 56)
				tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3, 0)
				tag.MaxDistance = 90
				tag.AlwaysOnTop = false
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
				label.BackgroundTransparency = 0.25
				label.TextColor3 = Config.Rarity[stats.rarity].color
				label.Font = Enum.Font.GothamBold
				label.TextScaled = true
				label.Text = ("%s\n%s"):format(stats.name or stats.model, s.forSale and ("FOR SALE " .. Cars.money(stats.value * Config.NpcMarkup)) or (Cars.money(stats.income) .. "/s"))
				label.Parent = tag
				local corner = Instance.new("UICorner")
				corner.Parent = label
				tag.Adornee = model.PrimaryPart
				tag.Parent = model

				-- steal prompt (the client hides it from the owner)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "StealPrompt"
				prompt.ActionText = "Steal"
				prompt.ObjectText = stats.name or stats.model
				prompt.HoldDuration = Config.Raid.StealHoldTime
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.KeyboardKeyCode = Enum.KeyCode.G
				prompt.Enabled = not isLocked(plot)
				prompt:SetAttribute("OwnerUserId", player.UserId)
				prompt.Parent = model.PrimaryPart
				prompt.Triggered:Connect(function(thief)
					Tycoon.tryRaid(thief, player, slot)
				end)

				model.Parent = displays
			end
		end
	end
	-- Legendary pedestal glow at max level
	plot.trim.Color = p.level >= 6 and Color3.fromRGB(255, 196, 40) or (p.level >= 4 and Color3.fromRGB(178, 92, 255) or Color3.fromRGB(80, 170, 255))
	displays.Parent = plot.model
	updateSign(plot, player)
end

function Tycoon.tryRaid(thief: Player, owner: Player, slot: number)
	local plot = playerPlot[owner]
	local p = DataService.get(owner)
	if thief == owner or not plot or not p or not DataService.get(thief) then
		return
	end
	if isLocked(plot) then
		notify(thief, "This base is locked!", Color3.fromRGB(255, 90, 90))
		return
	end
	if os.clock() - (joinedAt[owner] or 0) < Config.Raid.NewPlayerProtection then
		notify(thief, "This player is new - their base is protected for a few minutes.", Color3.fromRGB(255, 160, 60))
		return
	end
	local s = p.showroom[slot]
	local entry = s and DataService.findCar(owner, s.uid)
	if not entry or entry.inTransit then
		return
	end
	local char = thief.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or hum.Sit then
		return
	end
	local pad = plot.model.Pads:FindFirstChild("Pad" .. slot)
	if not pad or (char:GetPivot().Position - pad.Position).Magnitude > 25 then
		return
	end
	entry.inTransit = true
	s.forSale = false
	Tycoon.refreshPlot(owner)
	-- face the gate (-Z)
	VehicleService.spawnRaid(owner, entry, CFrame.new(pad.Position.X, pad.Position.Y + 0.2, pad.Position.Z), thief)
	notify(owner, ("%s is stealing your %s! Shoot their car to stop them!"):format(thief.DisplayName, Cars.resolve(entry).name or Cars.resolve(entry).model), Color3.fromRGB(255, 60, 60))
	notify(thief, "Get it to YOUR garage zone to keep it!", Color3.fromRGB(255, 200, 40))
	DataService.push(owner)
end

local function setLock(plot, locked: boolean)
	local barrier = plot.model.LockBarrier
	barrier.Transparency = locked and 0.55 or 1
	barrier.CanCollide = locked
	local displays = plot.model:FindFirstChild("Displays")
	if displays then
		for _, d in displays:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" then
				d.Enabled = not locked
			end
		end
	end
end

local function onLockPrompt(plot, player: Player)
	if plotOwner[plot] ~= player then
		notify(player, "Only the owner can lock this base.", Color3.fromRGB(255, 90, 90))
		return
	end
	local p = DataService.get(player)
	local st = lockState[plot] or { lockedUntil = 0, readyAt = 0 }
	lockState[plot] = st
	local now = os.clock()
	if now < st.readyAt then
		notify(player, ("Lock recharging: %ds"):format(math.ceil(st.readyAt - now)), Color3.fromRGB(255, 160, 60))
		return
	end
	local duration = Config.Raid.LockDuration
	for lvl = 1, p.level do
		duration += Config.Levels[lvl].lockBonus or 0
	end
	st.lockedUntil = now + duration
	st.readyAt = now + duration + Config.Raid.LockCooldown
	setLock(plot, true)
	notify(player, ("Base locked for %ds."):format(duration), Color3.fromRGB(80, 180, 255))
	task.delay(duration, function()
		if lockState[plot] == st and os.clock() >= st.lockedUntil - 0.1 then
			setLock(plot, false)
			if plotOwner[plot] == player then
				notify(player, "Your base lock ended.", Color3.fromRGB(255, 160, 60))
			end
		end
	end)
end

local function assignPlot(player: Player)
	for _, plot in WorldBuilder.Plots do
		if not plotOwner[plot] then
			plotOwner[plot] = player
			playerPlot[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			Tycoon.refreshPlot(player)
			-- spawn the player at their plot
			local function toPlot(char)
				task.wait(0.2)
				char:PivotTo(plot.spawnPad.CFrame + Vector3.new(0, 4, 30))
			end
			player.CharacterAdded:Connect(toPlot)
			if player.Character then
				task.spawn(toPlot, player.Character)
			end
			return plot
		end
	end
	notify(player, "Server full of dealerships - you can still hunt and steal!", Color3.fromRGB(255, 160, 60))
	return nil
end

local function releasePlot(player: Player)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	plotOwner[plot] = nil
	playerPlot[player] = nil
	lockState[plot] = nil
	setLock(plot, false)
	plot.model:SetAttribute("OwnerUserId", nil)
	local displays = plot.model:FindFirstChild("Displays")
	if displays then
		displays:Destroy()
	end
	for _, pad in plot.model.Pads:GetChildren() do
		pad.Transparency = 0
	end
	updateSign(plot, nil)
end

---------------------------------------------------------------- actions

local Actions = {}

function Actions.Display(player, args)
	local p = DataService.get(player)
	local entry = DataService.findCar(player, args.uid)
	if not entry then
		return false, "Car not found."
	end
	if entry.spawned or entry.inTransit then
		return false, "Bring that car home first."
	end
	if Tycoon.slotOf(player, args.uid) then
		return false, "Already on display."
	end
	for slot = 1, unlockedSlots(p) do
		if not p.showroom[slot] then
			p.showroom[slot] = { uid = args.uid, forSale = false }
			Tycoon.refreshPlot(player)
			return true
		end
	end
	return false, "Showroom full - upgrade your dealership for more slots."
end

function Actions.Undisplay(player, args)
	local p = DataService.get(player)
	local slot = tonumber(args.slot)
	local s = slot and p.showroom[slot]
	if not s then
		return false, "Empty slot."
	end
	local entry = DataService.findCar(player, s.uid)
	if entry and entry.inTransit then
		return false, "That car is being stolen - get it back!"
	end
	p.showroom[slot] = nil
	Tycoon.refreshPlot(player)
	return true
end

function Actions.ToggleSale(player, args)
	local p = DataService.get(player)
	local slot = tonumber(args.slot)
	local s = slot and p.showroom[slot]
	if not s then
		return false, "Empty slot."
	end
	s.forSale = not s.forSale
	s.saleAt = s.forSale and (os.time() + rng:NextInteger(Config.NpcBuyTime[1], Config.NpcBuyTime[2])) or nil
	Tycoon.refreshPlot(player)
	return true
end

function Actions.Sell(player, args)
	local p = DataService.get(player)
	local entry, index = DataService.findCar(player, args.uid)
	if not entry then
		return false, "Car not found."
	end
	if entry.spawned or entry.inTransit or Tycoon.slotOf(player, args.uid) then
		return false, "Store it and take it off display first."
	end
	local stats = Cars.resolve(entry)
	local price = math.floor(stats.value * Config.SellMultiplier)
	table.remove(p.garage, index)
	p.cash += price
	p.stats.sold += 1
	return true, ("Sold for %s"):format(Cars.money(price))
end

function Actions.BuyCatalog(player, args)
	local p = DataService.get(player)
	local car = Cars.List[tonumber(args.id) or 0]
	if not car then
		return false, "Unknown car."
	end
	local needLevel = Config.CatalogRarities[car.rarity]
	if not needLevel then
		return false, "Rare cars can't be bought - find them in the city!"
	end
	if p.level < needLevel then
		return false, ("Reach dealership level %d to buy %s cars."):format(needLevel, car.rarity)
	end
	if p.cash < car.value then
		return false, "Not enough cash."
	end
	if #p.garage >= DataService.garageCap(player) then
		return false, "Garage full."
	end
	p.cash -= car.value
	table.insert(p.garage, { uid = DataService.newUid(), id = car.id })
	return true, ("Bought %s!"):format(car.name)
end

function Actions.Upgrade(player)
	local p = DataService.get(player)
	local nextLevel = Config.Levels[p.level + 1]
	if not nextLevel then
		return false, "Max level!"
	end
	if p.cash < nextLevel.cost then
		return false, "Not enough cash."
	end
	p.cash -= nextLevel.cost
	p.level += 1
	Tycoon.refreshPlot(player)
	return true, ("Upgraded to %s!"):format(nextLevel.name)
end

function Actions.SpawnCar(player, args)
	return VehicleService.spawnOwned(player, args.uid)
end

function Actions.StoreCar(player)
	for model, info in VehicleService.Active do
		if info.spawnedBy == player and info.source == "Garage" then
			if VehicleService.getDriver(model) == player or not VehicleService.getDriver(model) then
				VehicleService.despawn(model)
			end
		end
	end
	return true
end

function Actions.Paint(player, args)
	local p = DataService.get(player)
	local entry = DataService.findCar(player, args.uid)
	if not entry or not Cars.Paints[args.paint] then
		return false, "Can't paint that."
	end
	local cost = 2500
	if p.cash < cost then
		return false, "Paint costs $2,500."
	end
	p.cash -= cost
	entry.paint = args.paint
	if Tycoon.slotOf(player, args.uid) then
		Tycoon.refreshPlot(player)
	end
	return true, "Fresh paint!"
end

Tycoon.Actions = Actions

---------------------------------------------------------------- loops

function Tycoon.start()
	for _, plot in WorldBuilder.Plots do
		plot.model.LockButton.LockPrompt.Triggered:Connect(function(player)
			onLockPrompt(plot, player)
		end)
	end

	DataService.Loaded.Event:Connect(function(player)
		joinedAt[player] = os.clock()
		assignPlot(player)
	end)
	table.insert(DataService.BeforeSave, function(player)
		releasePlot(player)
		joinedAt[player] = nil
	end)

	-- income + NPC buyers, once a second
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local p = DataService.get(player)
				if p and playerPlot[player] then
					local income = 0
					local changed = false
					local npcBonus = 1
					for lvl = 1, p.level do
						npcBonus *= Config.Levels[lvl].npcBonus or 1
					end
					for slot, s in p.showroom do
						local entry, index = DataService.findCar(player, s.uid)
						if not entry then
							p.showroom[slot] = nil
							changed = true
						elseif not entry.inTransit then
							local stats = Cars.resolve(entry)
							if s.forSale then
								if s.saleAt and now >= s.saleAt then
									local price = math.floor(stats.value * Config.NpcMarkup * npcBonus)
									p.cash += price
									p.stats.sold += 1
									table.remove(p.garage, index)
									p.showroom[slot] = nil
									changed = true
									notify(player, ("A customer bought your %s for %s!"):format(stats.name or stats.model, Cars.money(price)), Color3.fromRGB(90, 230, 120))
								end
							else
								income += stats.income
							end
						end
					end
					if p.level >= 6 then
						income *= 1.25
					end
					p.cash += math.floor(income)
					local ls = player:FindFirstChild("leaderstats")
					if ls then
						ls.Cash.Value = p.cash
					end
					if changed then
						Tycoon.refreshPlot(player)
						DataService.push(player)
					end
				end
			end
		end
	end)
end

return Tycoon
