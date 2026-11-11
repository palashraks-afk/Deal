-- The three menu windows: Garage (your cars + showroom), Dealership (upgrades + catalogue),
-- and Craft (blueprints -> custom car).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)

local new = UIKit.new
local C = UIKit.Colors

local Menus = {}

local function rarityColor(r: string): Color3
	return Config.Rarity[r] and Config.Rarity[r].color or C.Text
end

-- A row card for a car.
local function carCard(parent, stats, subtitle: string, order: number)
	local card = new("Frame", {
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = C.Panel2,
		LayoutOrder = order,
		Parent = parent,
	}, { UIKit.corner(10) })
	new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = rarityColor(stats.rarity), BorderSizePixel = 0, Parent = card }, { UIKit.corner(3) })
	UIKit.label({ Text = stats.name or (stats.brand .. " " .. stats.model), TextSize = 17, Size = UDim2.new(0.55, 0, 0, 24), Position = UDim2.fromOffset(16, 8), TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	UIKit.label({
		Text = ("%s  •  %s  •  %d hp  •  %s"):format(stats.rarity, stats.body, stats.hp, subtitle),
		TextSize = 13,
		TextColor3 = rarityColor(stats.rarity),
		Size = UDim2.new(0.6, 0, 0, 18),
		Position = UDim2.fromOffset(16, 36),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	local buttons = new("Frame", { Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromScale(0.58, 0), BackgroundTransparency = 1, Parent = card })
	local layout = UIKit.list(buttons, 6, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = buttons })
	return card, buttons
end

---------------------------------------------------------------- Garage
local function buildGarage()
	local win = UIKit.window("Garage", Vector2.new(780, 520))
	local tabs = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = win.body })
	UIKit.list(tabs, 8, Enum.FillDirection.Horizontal)
	local info = UIKit.label({ Text = "", TextSize = 14, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 40), Parent = win.body })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 64), Parent = win.body })
	UIKit.list(list, 6)

	local mode = "cars"
	local function render()
		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local data = State.Data
		if not data then
			return
		end
		local level = Config.Levels[data.level]
		if mode == "cars" then
			info.Text = ("%d cars  •  B to close  •  Drive a car into your GARAGE zone to store it"):format(#data.garage)
			local sorted = table.clone(data.garage)
			table.sort(sorted, function(a, b)
				return Cars.resolve(a).value > Cars.resolve(b).value
			end)
			for i, entry in sorted do
				local stats = Cars.resolve(entry)
				local slot = State.slotOf(entry.uid)
				local status = entry.inTransit and "BEING STOLEN" or (entry.spawned and "Out driving" or (slot and ("On display #" .. slot) or Cars.money(stats.value)))
				local _, buttons = carCard(list, stats, status, i)
				if not slot and not entry.spawned and not entry.inTransit then
					UIKit.button("Drive", C.Blue, { Size = UDim2.fromOffset(72, 34), Parent = buttons }).Activated:Connect(function()
						State.act("SpawnCar", { uid = entry.uid })
						win.close()
					end)
					UIKit.button("Display", C.Good, { Size = UDim2.fromOffset(78, 34), Parent = buttons }).Activated:Connect(function()
						State.act("Display", { uid = entry.uid })
					end)
					local sell = UIKit.button("Sell", C.Bad, { Size = UDim2.fromOffset(60, 34), Parent = buttons })
					local armed = false
					sell.Activated:Connect(function()
						if not armed then
							armed = true
							sell.Text = "Sure?"
							task.delay(2.5, function()
								armed = false
								if sell.Parent then
									sell.Text = "Sell"
								end
							end)
							return
						end
						State.act("Sell", { uid = entry.uid })
					end)
				elseif entry.spawned then
					UIKit.button("Store", C.Panel, { Size = UDim2.fromOffset(72, 34), Parent = buttons }).Activated:Connect(function()
						State.act("StoreCar")
					end)
				end
			end
		else
			info.Text = ("Showroom %d slots  •  Displayed cars earn cash every second. 'For Sale' cars sell to customers for %d%% of value."):format(level.slots, Config.NpcMarkup * 100)
			for slot = 1, level.slots do
				local s = data.showroom[slot]
				local entry
				if s then
					for _, e in data.garage do
						if e.uid == s.uid then
							entry = e
						end
					end
				end
				if entry then
					local stats = Cars.resolve(entry)
					local sub = entry.inTransit and "BEING STOLEN!" or (s.forSale and ("For sale " .. Cars.money(stats.value * Config.NpcMarkup)) or (Cars.money(stats.income) .. "/s"))
					local _, buttons = carCard(list, stats, ("#%d  %s"):format(slot, sub), slot)
					UIKit.button(s.forSale and "Keep" or "For Sale", C.Accent, { Size = UDim2.fromOffset(84, 34), TextColor3 = Color3.fromRGB(30, 24, 8), Parent = buttons }).Activated:Connect(function()
						State.act("ToggleSale", { slot = slot })
					end)
					UIKit.button("Remove", C.Panel, { Size = UDim2.fromOffset(80, 34), Parent = buttons }).Activated:Connect(function()
						State.act("Undisplay", { slot = slot })
					end)
				else
					local empty = new("Frame", { Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C.Panel2, BackgroundTransparency = 0.5, LayoutOrder = slot, Parent = list }, { UIKit.corner(10) })
					UIKit.label({ Text = ("#%d  Empty - press Display on a car"):format(slot), TextColor3 = C.Muted, TextSize = 14, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(16, 0), Parent = empty })
				end
			end
		end
	end
	for _, def in { { "My Cars", "cars" }, { "Showroom", "showroom" } } do
		UIKit.button(def[1], C.Panel2, { Size = UDim2.fromOffset(130, 34), Parent = tabs }).Activated:Connect(function()
			mode = def[2]
			render()
		end)
	end
	State.Changed.Event:Connect(function()
		if win.frame.Visible then
			render()
		end
	end)
	win.onOpen = render
	return win
end

---------------------------------------------------------------- Dealership
local function buildDealership()
	local win = UIKit.window("Dealership", Vector2.new(820, 560))
	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = C.Panel2, Parent = win.body }, { UIKit.corner(12) })
	local levelText = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 22, Size = UDim2.new(0.62, 0, 0, 30), Position = UDim2.fromOffset(16, 10), Parent = header })
	local nextText = UIKit.label({ Text = "", TextSize = 14, TextColor3 = C.Muted, TextWrapped = true, Size = UDim2.new(0.62, 0, 0, 40), Position = UDim2.fromOffset(16, 44), TextYAlignment = Enum.TextYAlignment.Top, Parent = header })
	local upgrade = UIKit.button("Upgrade", C.Accent, { Size = UDim2.fromOffset(240, 56), Position = UDim2.new(1, -256, 0, 18), TextSize = 18, Font = UIKit.FontHeavy, TextColor3 = Color3.fromRGB(30, 24, 8), Parent = header })
	upgrade.Activated:Connect(function()
		State.act("Upgrade")
	end)

	local filters = new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 100), BackgroundTransparency = 1, Parent = win.body })
	UIKit.list(filters, 8, Enum.FillDirection.Horizontal)
	local search = new("TextBox", {
		PlaceholderText = "Search cars...",
		Text = "",
		ClearTextOnFocus = false,
		Font = UIKit.Font,
		TextSize = 15,
		TextColor3 = C.Text,
		PlaceholderColor3 = C.Muted,
		BackgroundColor3 = C.Panel2,
		Size = UDim2.fromOffset(260, 34),
		LayoutOrder = 10,
		Parent = filters,
	}, { UIKit.corner(8), UIKit.pad(6) })
	local list = UIKit.scroll({ Size = UDim2.new(1, 0, 1, -146), Position = UDim2.fromOffset(0, 142), Parent = win.body })
	UIKit.list(list, 6)

	local rarityFilter = "Common"
	local function render()
		local data = State.Data
		if not data then
			return
		end
		local lvl = Config.Levels[data.level]
		local nxt = Config.Levels[data.level + 1]
		levelText.Text = ("Level %d - %s  (%d showroom slots)"):format(data.level, lvl.name, lvl.slots)
		if nxt then
			local perks = { ("%d slots"):format(nxt.slots) }
			if nxt.crafting then
				table.insert(perks, "blueprint crafting")
			end
			if nxt.garageBonus then
				table.insert(perks, ("+%d garage space"):format(nxt.garageBonus))
			end
			if nxt.npcBonus then
				table.insert(perks, "customers pay more")
			end
			if nxt.lockBonus then
				table.insert(perks, "longer base lock")
			end
			if nxt.pedestal then
				table.insert(perks, "+25% income")
			end
			for r, need in Config.CatalogRarities do
				if need == data.level + 1 then
					table.insert(perks, r .. " cars in catalogue")
				end
			end
			nextText.Text = ("Next: %s - %s"):format(nxt.name, table.concat(perks, ", "))
			upgrade.Text = ("Upgrade  %s"):format(Cars.money(nxt.cost))
			upgrade.BackgroundColor3 = data.cash >= nxt.cost and C.Accent or C.Panel
		else
			nextText.Text = "Max level - you run the best dealership in the city."
			upgrade.Text = "MAX"
			upgrade.BackgroundColor3 = C.Panel
		end

		for _, c in list:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local needLevel = Config.CatalogRarities[rarityFilter]
		local query = string.lower(search.Text)
		local shown = 0
		for _, car in Cars.ByRarity[rarityFilter] do
			if query == "" or string.find(string.lower(car.name), query, 1, true) then
				shown += 1
				if shown > 120 then
					break
				end
				local _, buttons = carCard(list, car, ("%s  •  %s/s on display"):format(Cars.money(car.value), Cars.money(car.income)), shown)
				if needLevel and data.level >= needLevel then
					UIKit.button("Buy", data.cash >= car.value and C.Good or C.Panel, { Size = UDim2.fromOffset(70, 34), Parent = buttons }).Activated:Connect(function()
						State.act("BuyCatalog", { id = car.id })
					end)
				else
					UIKit.label({ Text = needLevel and ("Unlocks Lv " .. needLevel) or "Find in city", TextColor3 = C.Muted, TextSize = 13, Size = UDim2.fromOffset(110, 34), TextXAlignment = Enum.TextXAlignment.Right, Parent = buttons })
				end
			end
		end
	end
	for i, r in Config.RarityOrder do
		local b = UIKit.button(r, Config.Rarity[r].color, { Size = UDim2.fromOffset(84, 34), TextSize = 13, LayoutOrder = i, TextColor3 = Color3.fromRGB(15, 15, 20), Parent = filters })
		b.Activated:Connect(function()
			rarityFilter = r
			render()
		end)
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if win.frame.Visible then
			render()
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

---------------------------------------------------------------- Craft
local function buildCraft()
	local win = UIKit.window("Blueprint Crafting", Vector2.new(780, 540))
	local hint = UIKit.label({ Text = "", TextSize = 14, TextColor3 = C.Muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36), Parent = win.body })
	local grid = new("Frame", { Size = UDim2.new(1, 0, 0, 200), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1, Parent = win.body })
	local options = new("Frame", { Size = UDim2.new(1, 0, 0, 230), Position = UDim2.fromOffset(0, 250), BackgroundTransparency = 1, Parent = win.body })

	local dyn = new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, Parent = options })
	local choice = { parts = {}, body = "sedan", paint = "Crimson" }
	local nameBox = new("TextBox", {
		PlaceholderText = "Name your car",
		Text = "",
		ClearTextOnFocus = false,
		Font = UIKit.Font,
		TextSize = 16,
		TextColor3 = C.Text,
		PlaceholderColor3 = C.Muted,
		BackgroundColor3 = C.Panel2,
		Size = UDim2.fromOffset(300, 38),
		Position = UDim2.fromOffset(0, 180),
		Parent = options,
	}, { UIKit.corner(8), UIKit.pad(8) })
	local preview = UIKit.label({ Text = "", TextSize = 15, Size = UDim2.new(1, -470, 0, 38), Position = UDim2.fromOffset(310, 180), TextWrapped = true, Parent = options })
	local craftBtn = UIKit.button("CRAFT", Color3.fromRGB(178, 92, 255), { Size = UDim2.fromOffset(150, 44), Position = UDim2.new(1, -150, 0, 176), Font = UIKit.FontHeavy, TextSize = 20, Parent = options })

	local function render()
		local data = State.Data
		if not data then
			return
		end
		hint.Text = data.level >= Config.CraftingLevel and "Pick one blueprint of each type. Better pieces = faster, more valuable car. Your Body piece decides which body styles you can build."
			or ("Collect blueprints in the city now - crafting unlocks at dealership level %d."):format(Config.CraftingLevel)
		grid:ClearAllChildren()
		UIKit.list(grid, 6)
		for row, part in Config.BlueprintParts do
			local line = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = row, Parent = grid })
			UIKit.list(line, 6, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
			UIKit.label({ Text = part, Font = UIKit.FontHeavy, TextSize = 16, Size = UDim2.fromOffset(90, 40), Parent = line })
			for i, r in Config.RarityOrder do
				local count = data.blueprints[part][r] or 0
				local picked = choice.parts[part] == r
				local b = UIKit.button(("%s x%d"):format(r, count), count > 0 and Config.Rarity[r].color or C.Panel2, {
					Size = UDim2.fromOffset(104, 38),
					TextSize = 12,
					LayoutOrder = i,
					TextColor3 = count > 0 and Color3.fromRGB(15, 15, 20) or C.Muted,
					Parent = line,
				})
				if picked then
					UIKit.stroke(Color3.new(1, 1, 1), 3).Parent = b
				end
				b.Activated:Connect(function()
					if count > 0 then
						choice.parts[part] = r
						render()
					end
				end)
			end
		end

		dyn:ClearAllChildren()
		local bodyRow = new("Frame", { Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1, Parent = dyn })
		local bl = new("UIGridLayout", { CellSize = UDim2.fromOffset(88, 34), CellPadding = UDim2.fromOffset(6, 6), Parent = bodyRow })
		bl.SortOrder = Enum.SortOrder.LayoutOrder
		local bodyRarity = choice.parts.Body and Cars.rarityIndex(choice.parts.Body) or 0
		local bodies = {}
		for body in Cars.CraftBodies do
			table.insert(bodies, body)
		end
		table.sort(bodies, function(a, b)
			return Cars.rarityIndex(Cars.CraftBodies[a]) < Cars.rarityIndex(Cars.CraftBodies[b])
		end)
		for i, body in bodies do
			local ok = bodyRarity >= Cars.rarityIndex(Cars.CraftBodies[body])
			local b = UIKit.button(body, ok and (choice.body == body and C.Accent or C.Blue) or C.Panel2, { LayoutOrder = i, TextSize = 13, TextColor3 = ok and Color3.new(1, 1, 1) or C.Muted, Parent = bodyRow })
			b.Activated:Connect(function()
				if ok then
					choice.body = body
					render()
				end
			end)
		end
		local paintRow = new("Frame", { Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 86), BackgroundTransparency = 1, Parent = dyn })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(40, 34), CellPadding = UDim2.fromOffset(6, 6), Parent = paintRow })
		for _, paint in Cars.PaintNames do
			local b = UIKit.button("", Cars.Paints[paint], { Parent = paintRow })
			if choice.paint == paint then
				UIKit.stroke(Color3.new(1, 1, 1), 3).Parent = b
			end
			b.Activated:Connect(function()
				choice.paint = paint
				render()
			end)
		end

		local complete = true
		for _, part in Config.BlueprintParts do
			if not choice.parts[part] then
				complete = false
			end
		end
		if complete then
			local s = Cars.craftStats(nameBox.Text ~= "" and nameBox.Text or "My Car", choice.body, choice.paint, choice.parts)
			preview.Text = ("%s %s  •  %d hp  •  %s  •  %s/s"):format(s.rarity, s.body, s.hp, Cars.money(s.value), Cars.money(s.income))
			preview.TextColor3 = rarityColor(s.rarity)
		else
			preview.Text = "Pick all 4 pieces"
			preview.TextColor3 = C.Muted
		end
	end
	craftBtn.Activated:Connect(function()
		if State.act("Craft", { parts = choice.parts, body = choice.body, paint = choice.paint, name = nameBox.Text }) then
			choice.parts = {}
			nameBox.Text = ""
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

function Menus.build()
	return {
		Garage = buildGarage(),
		Dealership = buildDealership(),
		Craft = buildCraft(),
	}
end

return Menus
