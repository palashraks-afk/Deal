-- Menu windows: Garage, Shop (new cars + blueprints), Upgrades (all 3 tracks), Factory, Guns.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Upgrades = require(Shared.Upgrades)
local Guns = require(Shared.Guns)

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local Menus = {}

local BODY_ICON = { hatch = "🚙", sedan = "🚗", wagon = "🚙", coupe = "🏎️", muscle = "🏎️", sports = "🏎️", super = "🏎️", hyper = "🚀", classic = "🚘", suv = "🚙", offroad = "🛻", truck = "🛻", van = "🚐" }

local function rarityColor(r: string): Color3
	return Config.Rarity[r] and Config.Rarity[r].color or C.Text
end

local function clear(list)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- A car row: rarity edge, icon, name, info line, and a button area on the right.
local function carCard(parent, car, info: string, order: number, height: number?)
	local card = new("Frame", { Size = UDim2.new(1, -10, 0, height or 70), BackgroundColor3 = C.Panel2, LayoutOrder = order, ClipsDescendants = true, ZIndex = 7, Parent = parent }, { UIKit.corner(10) })
	local rc = rarityColor(car.rarity)
	new("UIGradient", { Color = ColorSequence.new(rc:Lerp(C.Panel2, 0.78), C.Panel2), Rotation = 0, Parent = card })
	new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = rc, BorderSizePixel = 0, ZIndex = 8, Parent = card })
	UIKit.label({ Text = BODY_ICON[car.body] or "🚗", TextSize = 30, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(14, 10), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = card })
	UIKit.label({ Text = car.name, Font = UIKit.FontHeavy, TextSize = 18, Size = UDim2.new(0.5, 0, 0, 24), Position = UDim2.fromOffset(66, 9), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card })
	local tag = new("Frame", { Size = UDim2.fromOffset(84, 18), Position = UDim2.fromOffset(66, 38), BackgroundColor3 = rc, ZIndex = 8, Parent = card }, { UIKit.corner(4) })
	UIKit.label({ Text = string.upper(car.rarity), Font = UIKit.FontHeavy, TextSize = 11, TextColor3 = Color3.fromRGB(14, 14, 18), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9, Parent = tag })
	UIKit.label({ Text = info, TextSize = 13, TextColor3 = C.Muted, Size = UDim2.new(0.42, 0, 0, 18), Position = UDim2.fromOffset(158, 38), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card })
	local buttons = new("Frame", { Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundTransparency = 1, ZIndex = 8, Parent = card })
	local layout = UIKit.list(buttons, 6, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	return card, buttons
end

local function btn(parent, text, color, w, order, onClick, dark)
	local b = UIKit.button(text, color, { Size = UDim2.fromOffset(w or 76, 34), LayoutOrder = order or 0, ZIndex = 9, TextColor3 = dark and Color3.fromRGB(16, 14, 10) or Color3.new(1, 1, 1), Parent = parent })
	b.Activated:Connect(onClick)
	return b
end

---------------------------------------------------------------- Garage
local function buildGarage()
	local win = UIKit.window("Garage", Vector2.new(860, 560), C.Blue)
	local info = UIKit.label({ Text = "", TextSize = 13, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 44), ZIndex = 7, Parent = win.body })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -68), Position = UDim2.fromOffset(0, 66), Parent = win.body })
	UIKit.list(list, 6)
	local mode = "cars"

	local function priceControls(buttons, entry, car)
		local mult = State.Data.prices[entry.uid] or Config.DefaultPriceMult
		local price = math.floor(car.value * mult)
		local feel = mult <= 1 and "🔥 sells fast" or (mult <= 1.3 and "👍 fair" or (mult <= 1.8 and "🐢 slow" or "🧊 frozen"))
		local box = new("Frame", { Size = UDim2.fromOffset(150, 52), BackgroundColor3 = C.Panel, LayoutOrder = 1, ZIndex = 9, Parent = buttons }, { UIKit.corner(8) })
		UIKit.label({ Text = Cars.money(price), Font = UIKit.FontHeavy, TextSize = 16, TextColor3 = C.Good, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10, Parent = box })
		UIKit.label({ Text = ("%d%% • %s"):format(math.floor(mult * 100 + 0.5), feel), TextSize = 11, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10, Parent = box })
		btn(buttons, "−", C.Panel3, 34, 0, function()
			State.act("SetPrice", { uid = entry.uid, mult = mult - 0.1 })
		end)
		btn(buttons, "+", C.Panel3, 34, 2, function()
			State.act("SetPrice", { uid = entry.uid, mult = mult + 0.1 })
		end)
	end

	local function render()
		clear(list)
		local data = State.Data
		if not data then
			return
		end
		local e = State.Effects
		if mode == "cars" then
			info.Text = ("%d cars • drive a car into your GARAGE zone to store it • NPCs buy showroom cars at YOUR price"):format(#data.garage)
			local sorted = table.clone(data.garage)
			table.sort(sorted, function(a, b)
				return Cars.resolve(a).value > Cars.resolve(b).value
			end)
			for i, entry in sorted do
				local car = Cars.resolve(entry)
				local slot = State.slotOf(entry.uid)
				local prize = State.prizeSlotOf(entry.uid)
				local status = entry.inTransit and "⚠ BEING STOLEN" or (entry.spawned and "Out driving" or (prize and "In Prize Vault" or (slot and (slot > 20 and "Special lot" or "On display") or (Cars.money(car.value) .. " • " .. Cars.money(car.income) .. "/s"))))
				local _, buttons = carCard(list, car, status, i)
				if entry.inTransit then
					continue
				elseif slot then
					priceControls(buttons, entry, car)
					btn(buttons, "Take Off", C.Panel3, 80, 3, function()
						State.act("Undisplay", { slot = slot })
					end)
				elseif prize then
					btn(buttons, "Remove", C.Panel3, 80, 1, function()
						State.act("PrizeRemove", { slot = prize })
					end)
				elseif entry.spawned then
					btn(buttons, "Store", C.Panel3, 80, 1, function()
						State.act("StoreCar")
					end)
				else
					btn(buttons, "Drive", C.Blue, 64, 1, function()
						if State.act("SpawnCar", { uid = entry.uid }) then
							win.close()
						end
					end)
					btn(buttons, "Sell Lot", C.Good, 74, 2, function()
						State.act("Display", { uid = entry.uid })
					end)
					if e.specialLots > 0 then
						btn(buttons, "★ VIP", C.Accent, 60, 3, function()
							State.act("Display", { uid = entry.uid, special = true })
						end, true)
					end
					if e.prizeSlots > 0 then
						btn(buttons, "🏆", Color3.fromRGB(200, 150, 30), 40, 4, function()
							State.act("PrizePut", { uid = entry.uid })
						end)
					end
					local sell = btn(buttons, "Scrap", C.Bad, 58, 5, function() end)
					local armed = false
					sell.Activated:Connect(function()
						if not armed then
							armed = true
							sell.Text = Cars.money(car.value * Config.SellMultiplier)
							task.delay(2.5, function()
								armed = false
								if sell.Parent then
									sell.Text = "Scrap"
								end
							end)
							return
						end
						State.act("Sell", { uid = entry.uid })
					end)
				end
			end
		end
	end
	UIKit.tabs(win.body, { { "MY CARS", "cars" } }, function(k)
		mode = k
		render()
	end)("cars")
	State.Changed.Event:Connect(function()
		if win.frame.Visible then
			render()
		end
	end)
	win.onOpen = render
	return win
end

---------------------------------------------------------------- Shop (new cars + blueprints)
local function buildShop()
	local win = UIKit.window("Car Shop", Vector2.new(860, 580), C.Accent)
	local mode = "new"
	local rarity = "Common"
	local filters = new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1, ZIndex = 7, Parent = win.body })
	UIKit.list(filters, 6, Enum.FillDirection.Horizontal)
	local info = UIKit.label({ Text = "", TextSize = 13, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 82), ZIndex = 7, Parent = win.body })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -106), Position = UDim2.fromOffset(0, 104), Parent = win.body })
	UIKit.list(list, 6)

	local function render()
		clear(list)
		local data = State.Data
		if not data then
			return
		end
		local e = State.Effects
		if mode == "new" then
			local need = Config.CatalogRarities[rarity]
			info.Text = need and (e.baseCount >= need and "Buy brand-new cars to stock your lot." or ("Unlocks after %d dealership upgrades."):format(need))
				or "Rare and up can't be bought new — hunt them in the city or build them in your Factory."
			for i, car in Cars.ByRarity[rarity] do
				local _, buttons = carCard(list, car, ("%s • %d hp • %s/s"):format(Cars.money(car.value), car.hp, Cars.money(car.income)), i)
				if need and e.baseCount >= need then
					btn(buttons, "Buy " .. Cars.money(car.value), data.cash >= car.value and C.Good or C.Panel3, 130, 1, function()
						State.act("BuyCatalog", { id = car.id })
					end)
				end
			end
		else
			info.Text = e.factory and "Blueprints are built by your Factory. Price drops with Factory discount upgrades."
				or "Build your Factory (Car Factory station on your lot) to use blueprints."
			for i, car in Cars.ByRarity[rarity] do
				local price = math.floor(car.value * Config.BlueprintPriceMult * math.max(0.4, 1 - e.discount))
				local owned = data.blueprints[car.id] or 0
				local _, buttons = carCard(list, car, ("Blueprint %s • owned %d"):format(Cars.money(price), owned), i)
				if e.factory then
					btn(buttons, "📐 " .. Cars.money(price), data.cash >= price and Color3.fromRGB(255, 140, 40) or C.Panel3, 130, 1, function()
						State.act("BuyBlueprint", { id = car.id })
					end)
				end
			end
		end
	end
	for i, r in Config.RarityOrder do
		local b = UIKit.button(string.upper(r), Config.Rarity[r].color, { Size = UDim2.fromOffset(100, 32), TextSize = 12, LayoutOrder = i, ZIndex = 8, TextColor3 = Color3.fromRGB(14, 14, 18), Parent = filters })
		b.Activated:Connect(function()
			rarity = r
			render()
		end)
	end
	UIKit.tabs(win.body, { { "NEW CARS", "new" }, { "📐 BLUEPRINTS", "bp", 150 } }, function(k)
		mode = k
		render()
	end)("new")
	State.Changed.Event:Connect(function()
		if win.frame.Visible then
			render()
		end
	end)
	win.onOpen = render
	function win.openBlueprints()
		mode = "bp"
		win.open()
	end
	return win
end

---------------------------------------------------------------- Upgrades
local function buildUpgrades()
	local win = UIKit.window("Upgrades", Vector2.new(820, 580), C.Good)
	local track = "Base"
	local info = UIKit.label({ Text = "", TextSize = 13, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 44), ZIndex = 7, Parent = win.body })
	local progress = UIKit.bar(win.body, 0, C.Good, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 10) })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -90), Position = UDim2.fromOffset(0, 88), Parent = win.body })
	local grid = new("UIGridLayout", { CellSize = UDim2.fromOffset(190, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local _ = grid

	local KIND_ICON = { slot = "🅿️", income = "💡", traffic = "📣", rich = "💎", special = "⭐", garage = "🚪", security = "🛡️", decor = "🌴", unlock = "🏗️", speed = "⚙️", line = "🛤️", bonus = "✨", discount = "🏷️", robot = "🤖", pedestal = "🏆", glow = "💡", laser = "🔴" }
	local KIND_TEXT = {
		slot = "+1 showroom slot",
		income = "+6% showroom income",
		traffic = "+12% customers",
		rich = "richer customers",
		special = "+1 VIP lot (buyers pay more)",
		garage = "+3 garage space",
		security = "+10s base lock",
		decor = "+1% income",
		speed = "-2.5% build time",
		line = "+1 assembly line",
		bonus = "+3% build bonus",
		discount = "-1% blueprint price",
		robot = "-1% build time",
		pedestal = "more vault pedestals",
		glow = "bigger prize bonus",
		laser = "vault security",
	}

	local function render()
		clear(list)
		local data = State.Data
		if not data then
			return
		end
		local bought = data.upgrades[track]
		local count = 0
		for _ in bought do
			count += 1
		end
		local total = #Upgrades[track]
		progress:FindFirstChildOfClass("Frame").Size = UDim2.fromScale(math.max(0.02, count / total), 1)
		info.Text = ("%s: %d / %d built • buttons also appear on your lot — just walk on them"):format(track == "Base" and "Dealership" or (track == "Prize" and "Prize Vault" or "Factory"), count, total)
		local avail = {}
		for _, u in Upgrades.available(track, data.upgrades) do
			avail[u.index] = true
		end
		for _, u in Upgrades[track] do
			local owned = bought[u.index]
			local canBuy = avail[u.index]
			local card = new("Frame", { BackgroundColor3 = owned and Color3.fromRGB(22, 46, 32) or C.Panel2, LayoutOrder = u.index, ZIndex = 7, Parent = list }, { UIKit.corner(10), UIKit.stroke(owned and C.Good or (canBuy and C.Accent or C.Stroke), canBuy and 2 or 1) })
			UIKit.label({ Text = KIND_ICON[u.kind] or "🔧", TextSize = 22, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(6, 6), ZIndex = 8, Parent = card })
			UIKit.label({ Text = ("#%d %s"):format(u.index, u.name), Font = UIKit.FontHeavy, TextSize = 13, Size = UDim2.new(1, -44, 0, 18), Position = UDim2.fromOffset(38, 8), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card })
			UIKit.label({ Text = u.kind == "unlock" and "builds the extension" or (KIND_TEXT[u.kind] or ""), TextSize = 11, TextColor3 = C.Muted, Size = UDim2.new(1, -44, 0, 14), Position = UDim2.fromOffset(38, 28), ZIndex = 8, Parent = card })
			if owned then
				UIKit.label({ Text = "✔ BUILT", Font = UIKit.FontHeavy, TextSize = 14, TextColor3 = C.Good, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 52), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = card })
			elseif canBuy then
				local b = UIKit.button(Cars.money(u.cost), data.cash >= u.cost and C.Good or C.Panel3, { Size = UDim2.new(1, -12, 0, 32), Position = UDim2.fromOffset(6, 52), ZIndex = 9, Parent = card })
				b.Activated:Connect(function()
					State.act("BuyUpgrade", { track = track, index = u.index })
				end)
			else
				UIKit.label({ Text = "🔒 " .. Cars.money(u.cost), Font = UIKit.FontHeavy, TextSize = 13, TextColor3 = C.Muted, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 52), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = card })
			end
		end
	end
	UIKit.tabs(win.body, { { "🏢 DEALERSHIP (110)", "Base", 190 }, { "🏭 FACTORY (100)", "Factory", 170 }, { "🏆 PRIZE VAULT (10)", "Prize", 180 } }, function(k)
		track = k
		render()
	end)("Base")
	State.Changed.Event:Connect(function()
		if win.frame.Visible then
			render()
		end
	end)
	win.onOpen = render
	return win
end

---------------------------------------------------------------- Factory
local function buildFactory(shop)
	local win = UIKit.window("Factory", Vector2.new(800, 540), Color3.fromRGB(255, 140, 40))
	local info = UIKit.label({ Text = "", TextSize = 13, TextColor3 = C.Muted, TextWrapped = true, Size = UDim2.new(1, -170, 0, 36), Position = UDim2.fromOffset(0, 0), ZIndex = 7, Parent = win.body })
	local buyBp = UIKit.button("📐 BUY BLUEPRINTS", Color3.fromRGB(255, 140, 40), { Size = UDim2.fromOffset(160, 36), Position = UDim2.new(1, -160, 0, 0), ZIndex = 8, Parent = win.body })
	buyBp.Activated:Connect(function()
		shop.openBlueprints()
	end)
	local lines = new("Frame", { Size = UDim2.new(1, 0, 0, 5 * 46), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1, ZIndex = 7, Parent = win.body })
	UIKit.list(lines, 6)
	UIKit.label({ Text = "YOUR BLUEPRINTS", Font = UIKit.FontHeavy, TextSize = 14, TextColor3 = Color3.fromRGB(255, 160, 60), Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 44 + 5 * 46 + 4), ZIndex = 7, Parent = win.body })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -(44 + 5 * 46 + 26)), Position = UDim2.fromOffset(0, 44 + 5 * 46 + 24), Parent = win.body })
	UIKit.list(list, 6)
	local bars = {}

	local function render()
		clear(lines)
		clear(list)
		table.clear(bars)
		local data = State.Data
		if not data then
			return
		end
		local e = State.Effects
		if not e.factory then
			info.Text = "Your Factory isn't built yet. Walk to the CAR FACTORY station on your lot (or open Upgrades → Factory) to build it."
			return
		end
		info.Text = ("%d assembly line%s • build speed x%.2f • +%d%% bonus cash per car"):format(e.lines, e.lines == 1 and "" or "s", 1 / e.speedMult, math.floor(e.buildBonus * 100))
		for line = 1, 5 do
			local row = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = line <= e.lines and C.Panel2 or C.Panel, LayoutOrder = line, ZIndex = 7, Parent = lines }, { UIKit.corner(8) })
			local job = data.factory[line]
			local text = line > e.lines and "🔒 Buy an Assembly Line upgrade" or (job and Cars.List[job.id].name or "Idle — start a build below")
			UIKit.label({ Text = ("LINE %d   %s"):format(line, text), Font = UIKit.FontHeavy, TextSize = 14, TextColor3 = line <= e.lines and C.Text or C.Muted, Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(12, 0), ZIndex = 8, Parent = row })
			if job then
				local back = UIKit.bar(row, 0, Color3.fromRGB(255, 140, 40), { Position = UDim2.new(0.5, 0, 0.5, -5), Size = UDim2.new(0.35, 0, 0, 10) })
				local timeLabel = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 13, Size = UDim2.new(0.14, 0, 1, 0), Position = UDim2.new(0.86, 0, 0, 0), ZIndex = 8, Parent = row })
				table.insert(bars, { fill = back:FindFirstChildOfClass("Frame"), label = timeLabel, job = job })
			end
		end
		local ids = {}
		for id, n in data.blueprints do
			if n > 0 then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			return Cars.List[a].value > Cars.List[b].value
		end)
		if #ids == 0 then
			UIKit.label({ Text = "No blueprints yet — buy some in the Car Shop → Blueprints tab.", TextSize = 14, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 30), ZIndex = 7, Parent = list })
		end
		for i, id in ids do
			local car = Cars.List[id]
			local t = math.max(10, math.floor(Config.Rarity[car.rarity].buildTime * e.speedMult))
			local _, buttons = carCard(list, car, ("x%d • builds in %dm %02ds"):format(data.blueprints[id], t // 60, t % 60), i, 62)
			btn(buttons, "BUILD", Color3.fromRGB(255, 140, 40), 90, 1, function()
				State.act("StartBuild", { id = id })
			end)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			if win.frame.Visible then
				for _, b in bars do
					local left = math.max(0, b.job.startedAt + b.job.duration - State.now())
					b.fill.Size = UDim2.fromScale(math.clamp(1 - left / b.job.duration, 0.02, 1), 1)
					b.label.Text = left > 0 and ("%d:%02d"):format(left // 60, left % 60) or "DONE"
				end
			end
		end
	end)
	State.Changed.Event:Connect(function()
		if win.frame.Visible then
			render()
		end
	end)
	win.onOpen = render
	return win
end

---------------------------------------------------------------- Guns
local function buildGuns()
	local win = UIKit.window("Ammo & Arms", Vector2.new(860, 560), C.Hot)
	UIKit.label({ Text = "Guns damage players AND cars. Wreck a car → hold E to hotwire it → drive it to YOUR garage to keep it.", TextSize = 13, TextColor3 = C.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 34), ZIndex = 7, Parent = win.body })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -40), Position = UDim2.fromOffset(0, 40), Parent = win.body })
	new("UIGridLayout", { CellSize = UDim2.fromOffset(266, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local maxDps = 0
	for _, g in ipairs(Guns) do
		maxDps = math.max(maxDps, g.damage * (g.pellets or 1) / g.fireRate)
	end
	local function render()
		clear(list)
		local data = State.Data
		if not data then
			return
		end
		for _, g in ipairs(Guns) do
			local owned = data.guns[g.id]
			local card = new("Frame", { BackgroundColor3 = C.Panel2, LayoutOrder = g.order, ClipsDescendants = true, ZIndex = 7, Parent = list }, { UIKit.corner(12), UIKit.stroke(g.color, owned and 2.5 or 1) })
			for i = 0, 1 do
				local s = UIKit.stripe(card, g.color, 200 + i * 16, 8)
				s.BackgroundTransparency = 0.6
				s.ZIndex = 7
			end
			UIKit.label({ Text = string.upper(g.name), Font = UIKit.FontHeavy, TextSize = 19, TextColor3 = g.color, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(12, 8), ZIndex = 8, Parent = card })
			UIKit.label({ Text = (g.auto and "AUTO" or "SEMI") .. (g.pellets and " • SPREAD" or "") .. (g.explosive and " • EXPLOSIVE" or "") .. (g.scope and " • SCOPE" or ""), TextSize = 11, TextColor3 = C.Muted, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(12, 30), ZIndex = 8, Parent = card })
			local stats = {
				{ "DMG", math.min(1, g.damage * (g.pellets or 1) / 120) },
				{ "RATE", math.min(1, 0.08 / g.fireRate * 1.1) },
				{ "CARS", math.min(1, g.carDamage * (g.pellets or 1) / 120) },
				{ "RANGE", math.min(1, g.range / 900) },
			}
			for i, s in stats do
				UIKit.label({ Text = s[1], Font = UIKit.FontHeavy, TextSize = 10, TextColor3 = C.Muted, Size = UDim2.fromOffset(44, 12), Position = UDim2.fromOffset(12, 48 + (i - 1) * 15), ZIndex = 8, Parent = card })
				UIKit.bar(card, s[2], g.color, { Position = UDim2.fromOffset(58, 50 + (i - 1) * 15), Size = UDim2.new(1, -72, 0, 7) })
			end
			if owned then
				UIKit.label({ Text = "✔ OWNED  (in your backpack)", Font = UIKit.FontHeavy, TextSize = 13, TextColor3 = C.Good, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 112), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = card })
			else
				local b = UIKit.button("BUY " .. Cars.money(g.price), data.cash >= g.price and C.Hot or C.Panel3, { Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 110), ZIndex = 9, Parent = card })
				b.Activated:Connect(function()
					State.act("BuyGun", { id = g.id })
				end)
			end
		end
	end
	State.Changed.Event:Connect(function()
		if win.frame.Visible then
			render()
		end
	end)
	win.onOpen = render
	return win
end

function Menus.build()
	local shop = buildShop()
	return {
		Garage = buildGarage(),
		Shop = shop,
		Upgrades = buildUpgrades(),
		Factory = buildFactory(shop),
		Guns = buildGuns(),
	}
end

return Menus
