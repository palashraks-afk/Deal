-- Plots, tycoon upgrade buttons, showroom + special lots, player-set prices, prize room,
-- passive income, player-to-player sales, base locks and showroom raids.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local CarBuilder = require(Shared.CarBuilder)
local Upgrades = require(Shared.Upgrades)
local Net = require(Shared.Net)

local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlotBuilder = require(script.Parent.PlotBuilder)
local VehicleService = require(script.Parent.VehicleService)

local Tycoon = {}
local plotOwner = {} -- [plot] = player
local playerPlot = {} -- [player] = plot
local joinedAt = {} -- [player] = os.clock()
local lockState = {} -- [plot] = { lockedUntil, readyAt }

local notify = VehicleService.notify
local DISPLAY = PlotBuilder.DisplayPads

function Tycoon.plotOf(player: Player)
	return playerPlot[player]
end

function Tycoon.ownerOf(plot)
	return plotOwner[plot]
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

function Tycoon.prizeSlotOf(player: Player, uid: string): number?
	local p = DataService.get(player)
	for slot, u in p and p.prize or {} do
		if u == uid then
			return slot
		end
	end
	return nil
end

function Tycoon.isBusy(player: Player, uid: string): boolean
	return Tycoon.slotOf(player, uid) ~= nil or Tycoon.prizeSlotOf(player, uid) ~= nil
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
	for slot, u in p.prize do
		if u == uid then
			p.prize[slot] = nil
		end
	end
	p.prices[uid] = nil
end

function Tycoon.priceOf(player: Player, entry): number
	local p = DataService.get(player)
	local mult = p and p.prices[entry.uid] or Config.DefaultPriceMult
	return math.floor(Cars.resolve(entry).value * mult)
end

local function slotOpen(e, slot: number): boolean
	if slot <= DISPLAY then
		return slot <= e.slots
	end
	return slot - DISPLAY <= e.specialLots
end

local function isLocked(plot): boolean
	local st = lockState[plot]
	return st ~= nil and st.lockedUntil > os.clock()
end

local function updateSign(plot, player: Player?)
	local text = "FOR SALE - Claim this lot!"
	if player then
		local e = DataService.effects(player)
		local _, rank = Upgrades.rank(e and e.baseCount or 0)
		text = ("%s's %s"):format(player.DisplayName, rank)
	end
	for _, g in plot.model.Sign:GetChildren() do
		if g:IsA("SurfaceGui") then
			g.Label.Text = text
		end
	end
end

---------------------------------------------------------------- display models
local function tagFor(model: Model, title: string, sub: string, color: Color3)
	local _, size = model:GetBoundingBox()
	local tag = Instance.new("BillboardGui")
	tag.Name = "PriceTag"
	tag.Size = UDim2.fromOffset(210, 58)
	tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 3.5, 0)
	tag.MaxDistance = 110
	tag.Adornee = model.PrimaryPart
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
	frame.BackgroundTransparency = 0.15
	frame.Parent = tag
	Instance.new("UICorner").Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -10, 0.5, 0)
	t.Position = UDim2.fromOffset(5, 2)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = title
	t.Parent = frame
	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, -10, 0.45, 0)
	s.Position = UDim2.new(0, 5, 0.5, 0)
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.GothamBold
	s.TextScaled = true
	s.TextColor3 = Color3.fromRGB(110, 255, 140)
	s.Text = sub
	s.Parent = frame
	tag.Parent = model
end

local function placeCar(entry, cf: CFrame, parent)
	local stats = Cars.resolve(entry)
	local model = CarBuilder.build(stats, Cars.paintOf(entry), { drivable = false })
	local _, size = model:GetBoundingBox()
	local rootOffset = model.PrimaryPart.Position.Y - (model:GetBoundingBox().Position.Y - size.Y / 2)
	model:PivotTo(cf * CFrame.new(0, rootOffset, 0))
	model:SetAttribute("CarName", stats.name)
	model.Parent = parent
	return model, stats
end

-- Rebuild pads, display cars, prize pedestals and the sign for a player's plot.
function Tycoon.refreshPlot(player: Player)
	local plot = playerPlot[player]
	local p = DataService.get(player)
	if not plot or not p then
		return
	end
	local e = DataService.effects(player)
	local old = plot.model:FindFirstChild("Displays")
	if old then
		old:Destroy()
	end
	local displays = Instance.new("Folder")
	displays.Name = "Displays"

	for _, pad in plot.model.Pads:GetChildren() do
		local slot = pad:GetAttribute("Slot")
		local open = slotOpen(e, slot)
		pad.Transparency = open and 0 or 1
		pad.CanCollide = open
		local s = p.showroom[slot]
		if open and s then
			local entry = DataService.findCar(player, s.uid)
			if entry and not entry.inTransit then
				local padTop = pad.Position + Vector3.new(0, pad.Size.X / 2, 0)
				local cf = CFrame.new(padTop) * (plot.cframe * PlotBuilder.padCFrame(slot)).Rotation
				local model, stats = placeCar(entry, cf, displays)
				local price = Tycoon.priceOf(player, entry)
				model:SetAttribute("Slot", slot)
				model:SetAttribute("OwnerUserId", player.UserId)
				model:SetAttribute("Price", price)
				model:SetAttribute("Special", slot > DISPLAY)
				tagFor(model, stats.name, Cars.money(price), Config.Rarity[stats.rarity].color)

				-- other players can buy at the listed price, or steal it
				local buy = Instance.new("ProximityPrompt")
				buy.Name = "BuyPrompt"
				buy.ActionText = "Buy " .. Cars.money(price)
				buy.ObjectText = stats.name
				buy.HoldDuration = 0.6
				buy.MaxActivationDistance = 14
				buy.RequiresLineOfSight = false
				buy.KeyboardKeyCode = Enum.KeyCode.E
				buy:SetAttribute("OwnerUserId", player.UserId)
				buy.Parent = model.PrimaryPart
				buy.Triggered:Connect(function(buyer)
					Tycoon.playerBuy(buyer, player, slot)
				end)
				local steal = Instance.new("ProximityPrompt")
				steal.Name = "StealPrompt"
				steal.ActionText = "Steal"
				steal.ObjectText = stats.name
				steal.HoldDuration = Config.Raid.StealHoldTime
				steal.MaxActivationDistance = 14
				steal.RequiresLineOfSight = false
				steal.KeyboardKeyCode = Enum.KeyCode.G
				steal.UIOffset = Vector2.new(0, 70)
				steal.Enabled = not isLocked(plot)
				steal:SetAttribute("OwnerUserId", player.UserId)
				steal.Parent = model.PrimaryPart
				steal.Triggered:Connect(function(thief)
					Tycoon.tryRaid(thief, player, slot)
				end)
			end
		end
	end

	-- prize room
	if e.prizeSlots > 0 then
		local prizeFolder = Instance.new("Folder")
		prizeFolder.Name = "Prize"
		prizeFolder.Parent = displays
		for i = 1, e.prizeSlots do
			PlotBuilder.pedestal(prizeFolder, plot.cframe, i)
			local uid = p.prize[i]
			local entry = uid and DataService.findCar(player, uid)
			if entry and not entry.inTransit then
				local cf = plot.cframe * PlotBuilder.pedestalCFrame(i) * CFrame.new(0, 0.3, 0)
				local model, stats = placeCar(entry, cf, prizeFolder)
				tagFor(model, stats.name, "PRIZE  " .. Cars.money(stats.income * e.prizeMult) .. "/s", Color3.fromRGB(255, 200, 60))
			end
		end
	end

	local rankIdx = Upgrades.rank(e.baseCount)
	plot.trim.Color = ({ Color3.fromRGB(80, 170, 255), Color3.fromRGB(80, 220, 140), Color3.fromRGB(80, 170, 255), Color3.fromRGB(178, 92, 255), Color3.fromRGB(255, 64, 88), Color3.fromRGB(255, 196, 40) })[rankIdx]
	displays.Parent = plot.model
	updateSign(plot, player)
end

---------------------------------------------------------------- upgrade stations
local function refreshStations(player: Player)
	local plot = playerPlot[player]
	local p = DataService.get(player)
	if not plot or not p then
		return
	end
	for _, track in Upgrades.Tracks do
		local station = plot.model:FindFirstChild(track .. "Station")
		local old = station:FindFirstChild("Buttons")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Buttons"
		local avail = Upgrades.available(track, p.upgrades)
		for i, u in avail do
			local cf = plot.cframe * PlotBuilder.stationCFrame(track) * CFrame.new((i - 2) * 9.5, 1, -1)
			local afford = p.cash >= u.cost
			local b = Instance.new("Part")
			b.Name = "Button"
			b.Shape = Enum.PartType.Cylinder
			b.Size = Vector3.new(0.8, 7, 7)
			b.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
			b.Anchored = true
			b.Material = Enum.Material.Neon
			b.Color = afford and Color3.fromRGB(60, 220, 110) or Color3.fromRGB(220, 60, 70)
			b:SetAttribute("Track", track)
			b:SetAttribute("Index", u.index)
			b:SetAttribute("Cost", u.cost)
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(150, 56)
			gui.StudsOffset = Vector3.new(0, 4.5, 0)
			gui.MaxDistance = 70
			gui.Adornee = b
			local name = Instance.new("TextLabel")
			name.Size = UDim2.fromScale(1, 0.55)
			name.BackgroundTransparency = 1
			name.Font = Enum.Font.GothamBlack
			name.TextScaled = true
			name.TextColor3 = Color3.new(1, 1, 1)
			name.TextStrokeTransparency = 0.2
			name.Text = u.name
			name.Parent = gui
			local cost = Instance.new("TextLabel")
			cost.Name = "Cost"
			cost.Size = UDim2.fromScale(1, 0.45)
			cost.Position = UDim2.fromScale(0, 0.55)
			cost.BackgroundTransparency = 1
			cost.Font = Enum.Font.GothamBold
			cost.TextScaled = true
			cost.TextColor3 = afford and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
			cost.TextStrokeTransparency = 0.2
			cost.Text = Cars.money(u.cost)
			cost.Parent = gui
			gui.Parent = b
			b.Touched:Connect(function(hit)
				local char = hit:FindFirstAncestorOfClass("Model")
				if char and Players:GetPlayerFromCharacter(char) == player then
					Tycoon.buyUpgrade(player, track, u.index)
				end
			end)
			b.Parent = folder
		end
		folder.Parent = station
	end
end

-- Recolour buttons as cash changes (cheap; no rebuild).
local function recolourStations(player: Player)
	local plot = playerPlot[player]
	local p = DataService.get(player)
	if not plot or not p then
		return
	end
	for _, track in Upgrades.Tracks do
		local folder = plot.model[track .. "Station"]:FindFirstChild("Buttons")
		for _, b in folder and folder:GetChildren() or {} do
			local afford = p.cash >= b:GetAttribute("Cost")
			b.Color = afford and Color3.fromRGB(60, 220, 110) or Color3.fromRGB(220, 60, 70)
			local gui = b:FindFirstChildOfClass("BillboardGui")
			if gui then
				gui.Cost.TextColor3 = afford and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
			end
		end
	end
end

local buying = {}
function Tycoon.buyUpgrade(player: Player, track: string, index: number)
	if buying[player] then
		return false, nil
	end
	local p = DataService.get(player)
	local plot = playerPlot[player]
	if not p or not plot or not Upgrades[track] then
		return false, "No plot."
	end
	local ok = false
	for _, u in Upgrades.available(track, p.upgrades) do
		if u.index == index then
			ok = true
		end
	end
	if not ok then
		return false, "Not available yet."
	end
	local u = Upgrades[track][index]
	if p.cash < u.cost then
		return false, ("Need %s"):format(Cars.money(u.cost))
	end
	buying[player] = true
	p.cash -= u.cost
	p.upgrades[track][index] = true
	DataService.invalidate(player)
	PlotBuilder.apply(plot.model, plot.cframe, u)
	refreshStations(player)
	Tycoon.refreshPlot(player)
	DataService.push(player)
	notify(player, ("Built: %s"):format(u.name), Color3.fromRGB(110, 255, 150))
	Net.Effect:FireClient(player, "Build", plot.cframe.Position)
	task.delay(1.2, function() -- the next button appears where you're standing; don't auto-buy it
		buying[player] = nil
	end)
	return true, nil
end

---------------------------------------------------------------- selling
-- Remove a sold/stolen car from a player's data and showroom.
local function removeCar(player: Player, uid: string)
	local p = DataService.get(player)
	local _, index = DataService.findCar(player, uid)
	if index then
		table.remove(p.garage, index)
	end
	Tycoon.clearSlotFor(player, uid)
end

-- An NPC buys the car on `slot` for its listed price. Called by NpcService.
function Tycoon.npcBuy(owner: Player, slot: number): (boolean, number?)
	local p = DataService.get(owner)
	local s = p and p.showroom[slot]
	local entry = s and DataService.findCar(owner, s.uid)
	if not entry or entry.inTransit then
		return false
	end
	local price = Tycoon.priceOf(owner, entry)
	local stats = Cars.resolve(entry)
	removeCar(owner, entry.uid)
	DataService.addCash(owner, price)
	p.stats.sold += 1
	Tycoon.refreshPlot(owner)
	DataService.push(owner)
	notify(owner, ("SOLD! %s for %s"):format(stats.name, Cars.money(price)), Color3.fromRGB(90, 230, 120))
	return true, price
end

function Tycoon.playerBuy(buyer: Player, owner: Player, slot: number)
	if buyer == owner then
		return
	end
	local p = DataService.get(owner)
	local bp = DataService.get(buyer)
	local s = p and p.showroom[slot]
	local entry = s and DataService.findCar(owner, s.uid)
	if not bp or not entry or entry.inTransit then
		return
	end
	local price = Tycoon.priceOf(owner, entry)
	if bp.cash < price then
		notify(buyer, ("You need %s"):format(Cars.money(price)), Color3.fromRGB(255, 90, 90))
		return
	end
	if #bp.garage >= DataService.garageCap(buyer) then
		notify(buyer, "Your garage is full.", Color3.fromRGB(255, 90, 90))
		return
	end
	local stats = Cars.resolve(entry)
	removeCar(owner, entry.uid)
	DataService.addCash(buyer, -price)
	DataService.addCash(owner, price)
	table.insert(bp.garage, { uid = DataService.newUid(), id = entry.id, paint = entry.paint })
	p.stats.sold += 1
	notify(buyer, ("You bought %s for %s!"):format(stats.name, Cars.money(price)), Color3.fromRGB(90, 230, 120))
	notify(owner, ("%s bought your %s for %s!"):format(buyer.DisplayName, stats.name, Cars.money(price)), Color3.fromRGB(90, 230, 120))
	Tycoon.refreshPlot(owner)
	DataService.push(owner)
	DataService.push(buyer)
end

-- Listings an NPC can browse: display + special lots (never the prize room).
function Tycoon.listings(owner: Player)
	local plot = playerPlot[owner]
	local p = DataService.get(owner)
	local out = {}
	local displays = plot and plot.model:FindFirstChild("Displays")
	if not displays or not p then
		return out
	end
	for _, model in displays:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Slot") then
			local slot = model:GetAttribute("Slot")
			local s = p.showroom[slot]
			local entry = s and DataService.findCar(owner, s.uid)
			if entry then
				table.insert(out, { slot = slot, model = model, price = Tycoon.priceOf(owner, entry), value = Cars.resolve(entry).value, special = slot > DISPLAY })
			end
		end
	end
	return out
end

---------------------------------------------------------------- raids + locks
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
	Tycoon.refreshPlot(owner)
	-- face the plot's gate
	VehicleService.spawnRaid(owner, entry, CFrame.new(pad.Position + Vector3.new(0, 0.4, 0)) * plot.cframe.Rotation, thief)
	local name = Cars.resolve(entry).name
	notify(owner, ("%s is stealing your %s! Shoot their car!"):format(thief.DisplayName, name), Color3.fromRGB(255, 60, 60))
	notify(thief, "Get it to YOUR garage zone to keep it!", Color3.fromRGB(255, 200, 40))
	DataService.push(owner)
end

local function setLock(plot, locked: boolean)
	local barrier = plot.model.LockBarrier
	barrier.Transparency = locked and 0.55 or 1
	barrier.CanCollide = locked
	local displays = plot.model:FindFirstChild("Displays")
	for _, d in displays and displays:GetDescendants() or {} do
		if d:IsA("ProximityPrompt") and d.Name == "StealPrompt" then
			d.Enabled = not locked
		end
	end
end

local function onLockPrompt(plot, player: Player)
	if plotOwner[plot] ~= player then
		notify(player, "Only the owner can lock this base.", Color3.fromRGB(255, 90, 90))
		return
	end
	local e = DataService.effects(player)
	local st = lockState[plot] or { lockedUntil = 0, readyAt = 0 }
	lockState[plot] = st
	local now = os.clock()
	if now < st.readyAt then
		notify(player, ("Lock recharging: %ds"):format(math.ceil(st.readyAt - now)), Color3.fromRGB(255, 160, 60))
		return
	end
	local duration = Config.Raid.LockDuration + e.lockBonus
	st.lockedUntil = now + duration
	st.readyAt = now + duration + Config.Raid.LockCooldown
	setLock(plot, true)
	notify(player, ("Base locked for %ds."):format(duration), Color3.fromRGB(80, 180, 255))
	task.delay(duration, function()
		if lockState[plot] == st then
			setLock(plot, false)
			if plotOwner[plot] == player then
				notify(player, "Your base lock ended.", Color3.fromRGB(255, 160, 60))
			end
		end
	end)
end

---------------------------------------------------------------- plot claim / release
local function clearBuilt(plot)
	plot.model.Built:ClearAllChildren()
	for _, track in Upgrades.Tracks do
		local b = plot.model[track .. "Station"]:FindFirstChild("Buttons")
		if b then
			b:Destroy()
		end
	end
end

local function assignPlot(player: Player)
	for _, plot in WorldBuilder.Plots do
		if not plotOwner[plot] then
			plotOwner[plot] = player
			playerPlot[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			clearBuilt(plot)
			-- rebuild everything they've already bought
			local p = DataService.get(player)
			for _, track in Upgrades.Tracks do
				for _, u in Upgrades[track] do
					if p.upgrades[track][u.index] then
						PlotBuilder.apply(plot.model, plot.cframe, u)
					end
				end
			end
			refreshStations(player)
			Tycoon.refreshPlot(player)
			local function toPlot(char)
				task.wait(0.2)
				char:PivotTo(plot.cframe * CFrame.new(-22, 5, -110))
			end
			player.CharacterAdded:Connect(toPlot)
			if player.Character then
				task.spawn(toPlot, player.Character)
			end
			return plot
		end
	end
	notify(player, "Every lot is taken - you can still hunt, buy and steal!", Color3.fromRGB(255, 160, 60))
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
	clearBuilt(plot)
	for _, pad in plot.model.Pads:GetChildren() do
		pad.Transparency = 1
	end
	updateSign(plot, nil)
end

---------------------------------------------------------------- actions (from menus)
local Actions = {}

local function freeSlot(player, wantSpecial: boolean): number?
	local p = DataService.get(player)
	local e = DataService.effects(player)
	local from, to = 1, e.slots
	if wantSpecial then
		from, to = DISPLAY + 1, DISPLAY + e.specialLots
	end
	for slot = from, to do
		if not p.showroom[slot] then
			return slot
		end
	end
	return nil
end

function Actions.Display(player, args)
	local p = DataService.get(player)
	local entry = DataService.findCar(player, args.uid)
	if not entry then
		return false, "Car not found."
	end
	if entry.spawned or entry.inTransit then
		return false, "Bring that car home first."
	end
	if Tycoon.isBusy(player, args.uid) then
		return false, "Already on display."
	end
	local slot = freeSlot(player, args.special == true)
	if not slot then
		return false, args.special and "No free special lot - buy more Special Lot upgrades." or "Showroom full - buy Display Pad upgrades."
	end
	p.showroom[slot] = { uid = args.uid }
	p.prices[args.uid] = p.prices[args.uid] or Config.DefaultPriceMult
	Tycoon.refreshPlot(player)
	return true
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

function Actions.SetPrice(player, args)
	local p = DataService.get(player)
	local entry = DataService.findCar(player, args.uid)
	local mult = tonumber(args.mult)
	if not entry or not mult then
		return false, "Bad price."
	end
	p.prices[args.uid] = math.clamp(math.floor(mult * 100 + 0.5) / 100, Config.PriceMultRange[1], Config.PriceMultRange[2])
	if Tycoon.slotOf(player, args.uid) then
		Tycoon.refreshPlot(player)
	end
	return true
end

function Actions.PrizePut(player, args)
	local p = DataService.get(player)
	local e = DataService.effects(player)
	local entry = DataService.findCar(player, args.uid)
	if e.prizeSlots == 0 then
		return false, "Build the Prize Vault first."
	end
	if not entry or entry.spawned or entry.inTransit or Tycoon.isBusy(player, args.uid) then
		return false, "That car is busy."
	end
	for i = 1, e.prizeSlots do
		if not p.prize[i] then
			p.prize[i] = args.uid
			Tycoon.refreshPlot(player)
			return true, "Added to your Prize Vault!"
		end
	end
	return false, "Prize Vault is full - upgrade it."
end

function Actions.PrizeRemove(player, args)
	local p = DataService.get(player)
	local slot = tonumber(args.slot)
	if not slot or not p.prize[slot] then
		return false, "Empty pedestal."
	end
	p.prize[slot] = nil
	Tycoon.refreshPlot(player)
	return true
end

function Actions.Sell(player, args)
	local p = DataService.get(player)
	local entry, index = DataService.findCar(player, args.uid)
	if not entry then
		return false, "Car not found."
	end
	if entry.spawned or entry.inTransit or Tycoon.isBusy(player, args.uid) then
		return false, "Store it and take it off display first."
	end
	local price = math.floor(Cars.resolve(entry).value * Config.SellMultiplier)
	table.remove(p.garage, index)
	p.prices[args.uid] = nil
	DataService.addCash(player, price)
	p.stats.sold += 1
	return true, ("Sold for %s"):format(Cars.money(price))
end

function Actions.BuyCatalog(player, args)
	local p = DataService.get(player)
	local e = DataService.effects(player)
	local car = Cars.List[tonumber(args.id) or 0]
	if not car then
		return false, "Unknown car."
	end
	local need = Config.CatalogRarities[car.rarity]
	if not need then
		return false, "Rare cars can't be bought new - hunt them in the city or build them in your Factory!"
	end
	if e.baseCount < need then
		return false, ("Buy %d dealership upgrades to unlock %s cars."):format(need, car.rarity)
	end
	if p.cash < car.value then
		return false, "Not enough cash."
	end
	if #p.garage >= DataService.garageCap(player) then
		return false, "Garage full."
	end
	DataService.addCash(player, -car.value)
	table.insert(p.garage, { uid = DataService.newUid(), id = car.id })
	return true, ("Bought %s!"):format(car.name)
end

function Actions.BuyUpgrade(player, args)
	return Tycoon.buyUpgrade(player, tostring(args.track), tonumber(args.index) or 0)
end

function Actions.SpawnCar(player, args)
	return VehicleService.spawnOwned(player, args.uid)
end

function Actions.StoreCar(player)
	for model, info in VehicleService.Active do
		if info.spawnedBy == player and info.source == "Garage" then
			local driver = VehicleService.getDriver(model)
			if driver == player or not driver then
				VehicleService.despawn(model)
			end
		end
	end
	return true
end

Tycoon.Actions = Actions

---------------------------------------------------------------- start
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
		buying[player] = nil
	end)

	-- passive income once a second (display x incomeMult, prize room x prizeMult)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local p = DataService.get(player)
				if p and playerPlot[player] then
					local e = DataService.effects(player)
					local income = 0
					for slot, s in p.showroom do
						local entry = DataService.findCar(player, s.uid)
						if not entry then
							p.showroom[slot] = nil
						elseif not entry.inTransit and slot <= DISPLAY then
							income += Cars.resolve(entry).income * e.incomeMult
						end
					end
					for slot, uid in p.prize do
						local entry = DataService.findCar(player, uid)
						if not entry then
							p.prize[slot] = nil
						elseif not entry.inTransit and slot <= e.prizeSlots then
							income += Cars.resolve(entry).income * e.prizeMult
						end
					end
					DataService.addCash(player, math.floor(income))
					player:SetAttribute("IncomePerSec", math.floor(income))
					recolourStations(player)
				end
			end
		end
	end)
end

return Tycoon
