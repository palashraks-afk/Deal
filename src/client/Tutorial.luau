-- Beginner tutorial: a guide card that walks new players through everything, with a
-- waypoint for each step. Steps complete by themselves when you do the thing.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Sounds = require(Shared.Sounds)

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local Waypoint = require(script.Parent.Waypoint)
local DriveController = require(script.Parent.DriveController)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local Tutorial = {}

local function myPlot()
	local plots = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
	for _, p in plots and plots:GetChildren() or {} do
		if p:GetAttribute("OwnerUserId") == player.UserId then
			return p
		end
	end
	return nil
end

local function landmark(name)
	local lm = workspace:FindFirstChild("Landmarks")
	local v = lm and lm:FindFirstChild(name)
	return v and v.Value
end

local function showroomCount()
	local n = 0
	for _ in State.Data and State.Data.showroom or {} do
		n += 1
	end
	return n
end

local function nearestFind(): Vector3?
	local char = player.Character
	local finds = workspace:FindFirstChild("CityFinds")
	if not char or not char.PrimaryPart or not finds then
		return nil
	end
	local best, bestD
	for _, f in finds:GetChildren() do
		local m = f:IsA("ObjectValue") and f.Value
		local pos = m and m.PrimaryPart and m.PrimaryPart.Position
		if pos then
			local d = (pos - char.PrimaryPart.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = pos, d
			end
		end
	end
	return best
end

-- Each step: title, text, where to point, when it's done, and whether "Next" shows.
local STEPS = {
	{
		title = "Welcome to DrivinDealz!",
		text = "This lot is YOUR car dealership. Sell cars, build it up, hunt rare cars in the city and steal from rivals. Let's go!",
		manual = true,
	},
	{
		title = "Put a car up for sale",
		text = "Press B (or the GARAGE tile) and hit SELL LOT on a car. It appears in your showroom with a price tag.",
		target = function()
			local p = myPlot()
			return p and p.Pads.Pad1.Position
		end,
		done = function()
			return showroomCount() >= 1
		end,
	},
	{
		title = "Set your price",
		text = "In the Garage, use + and − on a showroom car. Cheaper = sells faster, pricier = more money. Customers decide if it's fair!",
		manual = true,
		done = function()
			for _, m in State.Data.prices or {} do
				if math.abs(m - 1.2) > 0.01 then
					return true
				end
			end
			return false
		end,
	},
	{
		title = "Build your first upgrade",
		text = "Walk onto a GREEN button at DEALERSHIP UPGRADES. There are 110 of them — each one builds something on your lot!",
		target = function()
			local p = myPlot()
			return p and p.BaseStation.Base.Position
		end,
		done = function()
			return State.Effects and State.Effects.baseCount >= 1
		end,
	},
	{
		title = "Customers are coming",
		text = "NPC customers walk in, look at your cars and buy them if the price is fair. Watch your cash on the license plate!",
		manual = true,
		done = function()
			return (State.Data.stats.sold or 0) >= 1
		end,
	},
	{
		title = "Take a car for a drive",
		text = "Open your Garage (B) and press DRIVE. WASD to drive, SHIFT to drift, SPACE to get out.",
		done = function()
			return DriveController.Car ~= nil
		end,
	},
	{
		title = "Hunt a rare car",
		text = "Glowing light beams around the map are free cars! Drive to one, hop in, and bring it back to your yellow GARAGE zone.",
		target = nearestFind,
		manual = true,
		done = function()
			return (State.Data.stats.found or 0) >= 1
		end,
	},
	{
		title = "Get some guns",
		text = "Visit AMMO & ARMS downtown on the boulevard. Hold RIGHT-CLICK to aim, LEFT-CLICK to shoot. Wreck a rival's car, then hold E to hotwire and steal it!",
		target = function()
			return landmark("GunStore")
		end,
		manual = true,
		done = function()
			local n = 0
			for _ in State.Data.guns or {} do
				n += 1
			end
			return n >= 2
		end,
	},
	{
		title = "Build your Factory",
		text = "At the CAR FACTORY station on your lot, build the Factory. Then buy blueprints in the Shop and build ANY car — even Legendaries.",
		target = function()
			local p = myPlot()
			return p and p.FactoryStation.Base.Position
		end,
		manual = true,
		done = function()
			return State.Effects and State.Effects.factory
		end,
	},
	{
		title = "You're ready!",
		text = "Press M for the big map — click anywhere to set a waypoint. Explore Downtown, Suburbs, Port, Hills, Beach and Desert. Build the best dealership in the city!",
		manual = true,
		final = true,
	},
}

function Tutorial.start()
	local step
	-- frosted glass card (matches the menus and HUD): a gold pill for the step count
	-- instead of a solid yellow header
	local card = new("Frame", { Name = "Tutorial", Size = UDim2.fromOffset(330, 160), Position = UDim2.new(1, -16, 0.5, -40), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.08, Visible = false, ZIndex = 25, Parent = UIKit.screen() }, {
		UIKit.corner(20),
		new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85, Thickness = 1 }),
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(40, 43, 58), Color3.fromRGB(14, 15, 21)), Rotation = 90 }),
	})
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, ZIndex = 25, Parent = card })
	local pill = new("Frame", { Size = UDim2.fromOffset(110, 22), Position = UDim2.fromOffset(12, 9), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.8, ZIndex = 25, Parent = head }, { UIKit.corner(11) })
	local stepLabel = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 11, TextColor3 = C.Accent, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 26, Parent = pill })
	local skipAll = UIKit.button("Skip all", UIKit.Colors.Panel3, { Size = UDim2.fromOffset(70, 24), Position = UDim2.new(1, -82, 0, 8), TextSize = 11, ZIndex = 27, Parent = head })
	local title = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 18, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 40), ZIndex = 26, Parent = card })
	local body = UIKit.label({ Text = "", TextSize = 14, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 64), ZIndex = 26, Parent = card })
	local nextBtn = UIKit.button("NEXT ›", C.Good, { Size = UDim2.fromOffset(90, 28), Position = UDim2.new(1, -102, 1, -36), ZIndex = 27, Parent = card })
	local dots = new("Frame", { Size = UDim2.fromOffset(200, 10), Position = UDim2.new(0, 12, 1, -26), BackgroundTransparency = 1, ZIndex = 26, Parent = card })
	UIKit.list(dots, 5, Enum.FillDirection.Horizontal)

	local function save(n)
		Net.Tutorial:FireServer(n)
	end

	local function show(n)
		step = n
		if n == 0 or n > #STEPS then
			card.Visible = false
			Waypoint.clear()
			return
		end
		local s = STEPS[n]
		card.Visible = true
		stepLabel.Text = ("TUTORIAL  %d / %d"):format(n, #STEPS)
		title.Text = s.title
		body.Text = s.text
		nextBtn.Visible = s.manual == true
		nextBtn.Text = s.final and "LET'S GO!" or "NEXT ›"
		dots:ClearAllChildren()
		UIKit.list(dots, 5, Enum.FillDirection.Horizontal)
		for i = 1, #STEPS do
			new("Frame", { Size = UDim2.fromOffset(i == n and 18 or 10, 8), BackgroundColor3 = i <= n and C.Accent or C.Panel3, LayoutOrder = i, ZIndex = 26, Parent = dots }, { UIKit.corner(4) })
		end
		local s2 = card:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = card })
		s2.Scale = 0.85
		TweenService:Create(s2, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if s.target then
			local pos = s.target()
			if pos then
				Waypoint.set(pos, string.upper(s.title), C.Accent)
			else
				Waypoint.clear()
			end
		else
			Waypoint.clear()
		end
	end

	local function advance()
		Sounds.play("Build", nil, 0.5)
		local n = step + 1
		if n > #STEPS then
			n = 0
		end
		save(n)
		show(n)
	end
	nextBtn.Activated:Connect(advance)
	skipAll.Activated:Connect(function()
		save(0)
		show(0)
	end)

	-- wait for data, then resume where they left off
	local function begin(data)
		if step == nil then
			show(data.tutorial or 1)
		end
	end
	if State.Data then
		begin(State.Data)
	end
	State.Changed.Event:Connect(begin)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local s = step and STEPS[step]
			if s and State.Data then
				if s.done and s.done() then
					advance()
				elseif s.target and s.target == nearestFind and not Waypoint.Position then
					local pos = nearestFind()
					if pos then
						Waypoint.set(pos, "RARE CAR", C.Accent)
					end
				end
			end
		end
	end)
end

return Tutorial
