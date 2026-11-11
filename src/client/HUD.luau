-- Always-on HUD: license-plate cash counter, income ticker, menu dock, toasts,
-- gauge speedometer + car health while driving.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Net = require(Shared.Net)
local Upgrades = require(Shared.Upgrades)

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local DriveController = require(script.Parent.DriveController)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local HUD = {}

function HUD.start(menus)
	local screen = UIKit.screen()

	------------------------------------------------ license plate
	local plate = new("Frame", {
		Name = "Plate",
		Size = UDim2.fromOffset(300, 86),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(248, 244, 228),
		Parent = screen,
	}, { UIKit.corner(12), UIKit.stroke(Color3.fromRGB(20, 22, 30), 4) })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 250), Color3.fromRGB(220, 214, 196)), Rotation = 90, Parent = plate })
	for _, x in { 12, 276 } do
		new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(x, 8), BackgroundColor3 = Color3.fromRGB(150, 150, 150), Parent = plate }, { UIKit.corner(5) })
	end
	UIKit.label({ Text = "DRIVINDEALZ", Font = UIKit.FontHeavy, TextSize = 13, TextColor3 = Color3.fromRGB(200, 30, 40), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 5), TextXAlignment = Enum.TextXAlignment.Center, Parent = plate })
	local cash = UIKit.label({ Text = "$0", Font = UIKit.FontMono, TextSize = 38, TextColor3 = Color3.fromRGB(20, 24, 40), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = plate })
	cash.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	local rankText = UIKit.label({ Text = "USED LOT", Font = UIKit.FontHeavy, TextSize = 12, TextColor3 = Color3.fromRGB(60, 70, 110), Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 64), TextXAlignment = Enum.TextXAlignment.Center, Parent = plate })

	local incomePill = new("Frame", { Size = UDim2.fromOffset(150, 26), Position = UDim2.new(0.5, 0, 0, 98), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Panel, Parent = screen }, { UIKit.corner(13), UIKit.stroke(C.Good, 1.5) })
	local incomeText = UIKit.label({ Text = "+$0/s", Font = UIKit.FontHeavy, TextSize = 15, TextColor3 = C.Good, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = incomePill })

	local shownCash, lastTarget = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		local ls = player:FindFirstChild("leaderstats")
		local target = ls and ls:FindFirstChild("Cash") and ls.Cash.Value or 0
		if target > lastTarget + 1 and lastTarget > 0 and target - lastTarget > 500 then
			-- big gain: little bounce
			local s = plate:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = plate })
			s.Scale = 1.08
			TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastTarget = target
		shownCash += (target - shownCash) * math.clamp(dt * 9, 0, 1)
		if math.abs(target - shownCash) < 1 then
			shownCash = target
		end
		cash.Text = Cars.money(shownCash)
		incomeText.Text = "+" .. Cars.money(player:GetAttribute("IncomePerSec") or 0) .. "/s"
	end)
	State.Changed.Event:Connect(function()
		local e = State.Effects
		local idx, rank = Upgrades.rank(e.baseCount)
		rankText.Text = ("%s  •  %d/110 UPGRADES"):format(string.upper(rank), e.baseCount)
		rankText.TextColor3 = ({ Color3.fromRGB(60, 70, 110), Color3.fromRGB(30, 120, 60), Color3.fromRGB(30, 90, 170), Color3.fromRGB(120, 50, 180), Color3.fromRGB(190, 30, 50), Color3.fromRGB(180, 130, 10) })[idx]
	end)

	------------------------------------------------ dock
	-- vertical dock on the left (the Roblox hotbar owns the bottom centre)
	local dock = new("Frame", { Name = "Dock", Size = UDim2.fromOffset(84, 4 * 90), Position = UDim2.new(0, 14, 0.5, 130), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = screen })
	local dl = UIKit.list(dock, 8, Enum.FillDirection.Vertical)
	dl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	dl.VerticalAlignment = Enum.VerticalAlignment.Center
	for i, def in {
		{ "🚗", "GARAGE", "B", C.Blue, menus.Garage },
		{ "🏷️", "SHOP", "N", C.Accent, menus.Shop },
		{ "🔧", "UPGRADES", "U", C.Good, menus.Upgrades },
		{ "🏭", "FACTORY", "J", Color3.fromRGB(255, 140, 40), menus.Factory },
	} do
		local tile = new("TextButton", { Size = UDim2.fromOffset(76, 80), BackgroundColor3 = C.Panel, Text = "", AutoButtonColor = false, LayoutOrder = i, ClipsDescendants = true, Parent = dock }, { UIKit.corner(14), UIKit.stroke(def[4], 2) })
		new("Frame", { Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 1, -5), BackgroundColor3 = def[4], BorderSizePixel = 0, Parent = tile })
		UIKit.label({ Text = def[1], TextSize = 30, Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 6), TextXAlignment = Enum.TextXAlignment.Center, Parent = tile })
		UIKit.label({ Text = def[2], Font = UIKit.FontHeavy, TextSize = 11, TextColor3 = def[4], Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 50), TextXAlignment = Enum.TextXAlignment.Center, Parent = tile })
		UIKit.label({ Text = def[3], Font = UIKit.FontHeavy, TextSize = 10, TextColor3 = C.Muted, Size = UDim2.fromOffset(16, 14), Position = UDim2.fromOffset(4, 3), Parent = tile })
		local s = new("UIScale", { Parent = tile })
		tile.MouseEnter:Connect(function()
			TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1.1 }):Play()
		end)
		tile.MouseLeave:Connect(function()
			TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
		tile.Activated:Connect(def[5].toggle)
	end

	------------------------------------------------ toasts
	local toasts = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(520, 320), Position = UDim2.new(0.5, 0, 0, 134), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = screen })
	UIKit.list(toasts, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function toast(info)
		local big = info.big
		local color = info.color or C.Text
		local t = new("Frame", { Size = UDim2.fromOffset(big and 520 or 430, big and 46 or 36), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.05, ClipsDescendants = true, Parent = toasts }, { UIKit.corner(9), UIKit.stroke(color, big and 2.5 or 1.5) })
		new("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = t })
		local text = UIKit.label({ Text = info.text, Font = big and UIKit.FontHeavy or UIKit.Font, TextSize = big and 19 or 15, TextColor3 = color, TextWrapped = true, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(16, 0), Parent = t })
		local s = new("UIScale", { Scale = 0.6, Parent = t })
		TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(big and 6 or 4, function()
			TweenService:Create(t, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			local tw = TweenService:Create(text, TweenInfo.new(0.35), { TextTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			t:Destroy()
		end)
		local frames = {}
		for _, c in toasts:GetChildren() do
			if c:IsA("Frame") then
				table.insert(frames, c)
			end
		end
		if #frames > 6 then
			frames[1]:Destroy()
		end
	end
	Net.Notify.OnClientEvent:Connect(toast)
	State.Toast.Event:Connect(toast)

	------------------------------------------------ speedometer
	local gauge = new("Frame", { Name = "Gauge", Size = UDim2.fromOffset(190, 190), Position = UDim2.new(1, -18, 1, -18), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Panel, Visible = false, Parent = screen }, { UIKit.corner(95), UIKit.stroke(C.Accent, 3) })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(34, 36, 48), Color3.fromRGB(8, 8, 12)), Rotation = 90, Parent = gauge })
	-- tick marks
	for i = 0, 10 do
		local a = -225 + i * 27
		local tick = new("Frame", { Size = UDim2.fromOffset(3, i % 2 == 0 and 14 or 8), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = i >= 8 and C.Hot or C.Muted, BorderSizePixel = 0, Rotation = a + 90, Parent = gauge })
		tick.Position = UDim2.new(0.5, math.cos(math.rad(a)) * 80, 0.5, math.sin(math.rad(a)) * 80)
	end
	-- needle: a bar centred on the hub whose bottom half is invisible, so rotating it swings the top half
	local needlePivot = new("Frame", { Size = UDim2.fromOffset(4, 144), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Hot, BorderSizePixel = 0, Parent = gauge })
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = needlePivot })
	new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Accent, Parent = gauge }, { UIKit.corner(7) })
	local speedText = UIKit.label({ Text = "0", Font = UIKit.FontHeavy, TextSize = 36, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0.5, 18), TextXAlignment = Enum.TextXAlignment.Center, Parent = gauge })
	UIKit.label({ Text = "KM/H", Font = UIKit.FontHeavy, TextSize = 11, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0.5, 54), TextXAlignment = Enum.TextXAlignment.Center, Parent = gauge })
	local carPanel = new("Frame", { Size = UDim2.fromOffset(250, 58), Position = UDim2.new(1, -216, 1, -18), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Panel, Visible = false, Parent = screen }, { UIKit.corner(10), UIKit.stroke() })
	local carName = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 15, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 6), TextTruncate = Enum.TextTruncate.AtEnd, Parent = carPanel })
	local hpBack = new("Frame", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 30), BackgroundColor3 = C.Panel3, Parent = carPanel }, { UIKit.corner(5) })
	local hp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Good, Parent = hpBack }, { UIKit.corner(5) })
	UIKit.label({ Text = "WASD drive • SHIFT drift • R flip • SPACE exit", TextSize = 10, TextColor3 = C.Muted, Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 43), Parent = carPanel })

	local wasDriving = false
	RunService.RenderStepped:Connect(function()
		local car = DriveController.Car
		gauge.Visible = car ~= nil
		carPanel.Visible = car ~= nil
		-- driving mode: only the minimap + driving HUD
		local driving = car ~= nil
		if driving ~= wasDriving then
			wasDriving = driving
			dock.Visible = not driving
			incomePill.Visible = not driving
			if driving then
				for _, m in menus do
					m.close()
				end
			end
		end
		if car then
			local rarity = car:GetAttribute("Rarity")
			carName.Text = car:GetAttribute("CarName") or ""
			carName.TextColor3 = rarity and Config.Rarity[rarity] and Config.Rarity[rarity].color or C.Text
			local kmh = math.abs(DriveController.Speed) / Config.StudsPerMeter * 3.6 * 1.6
			speedText.Text = tostring(math.floor(kmh))
			local top = (car:GetAttribute("TopSpeed") or 100) / Config.StudsPerMeter * 3.6 * 1.6
			needlePivot.Rotation = -135 + math.clamp(kmh / math.max(top, 1), 0, 1.05) * 270
			local h = (car:GetAttribute("Health") or 0) / (car:GetAttribute("MaxHealth") or 1)
			hp.Size = UDim2.fromScale(math.clamp(h, 0, 1), 1)
			hp.BackgroundColor3 = h > 0.5 and C.Good or (h > 0.25 and C.Accent or C.Bad)
		end
	end)
end

return HUD
