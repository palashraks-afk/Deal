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
local UIAssets = require(Shared.UIAssets)

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local DriveController = require(script.Parent.DriveController)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local HUD = {}

function HUD.start(menus)
	local screen = UIKit.screen()

	------------------------------------------------ logo splash when you join
	if UIAssets.Logo ~= "" then
		local splash = new("ImageLabel", { Name = "Splash", Image = UIAssets.Logo, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(620, 350), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 50, Parent = screen })
		local s = new("UIScale", { Scale = 0.6, Parent = splash })
		TweenService:Create(s, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(3.2, function()
			local tw = TweenService:Create(splash, TweenInfo.new(0.6), { ImageTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			splash:Destroy()
		end)
	end

	------------------------------------------------ money bar (top centre)
	-- one frosted glass bar: logo badge, cash, and a rank/income line underneath
	local function glass(props, radius)
		local f = new("Frame", props, {
			UIKit.corner(radius or 16),
			new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85, Thickness = 1 }),
			new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(40, 43, 58), Color3.fromRGB(14, 15, 21)), Rotation = 90 }),
		})
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 0.08
		return f
	end
	local plate = glass({ Name = "Plate", Size = UDim2.fromOffset(380, 72), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), Parent = screen }, 20)
	if UIAssets.Logo ~= "" then
		new("ImageLabel", { Image = UIAssets.Logo, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(84, 52), Position = UDim2.fromOffset(10, 10), Parent = plate })
	end
	-- thin gold accent line along the bottom edge
	new("Frame", { Size = UDim2.new(1, -40, 0, 2), Position = UDim2.new(0, 20, 1, -2), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = plate }, {
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local cash = UIKit.label({ Text = "$0", Font = UIKit.FontHeavy, TextSize = 32, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -110, 0, 36), Position = UDim2.fromOffset(100, 8), Parent = plate })
	cash.TextXAlignment = Enum.TextXAlignment.Left
	local rankText = UIKit.label({ Text = "USED LOT", Font = UIKit.FontHeavy, TextSize = 11, TextColor3 = C.Muted, Size = UDim2.new(1, -200, 0, 14), Position = UDim2.fromOffset(101, 44), TextTruncate = Enum.TextTruncate.AtEnd, Parent = plate })
	-- income lives inside the bar now, as a small green chip on the right
	-- bottom-right of the bar, beside the rank line, so it never covers a big cash number
	local incomePill = new("Frame", { Size = UDim2.fromOffset(78, 18), Position = UDim2.new(1, -12, 0, 42), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.Good, BackgroundTransparency = 0.82, Parent = plate }, { UIKit.corner(9) })
	local incomeText = UIKit.label({ Text = "+$0/s", Font = UIKit.FontHeavy, TextSize = 12, TextColor3 = C.Good, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = incomePill })

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
		-- bright rank colours that read on the dark glass bar
		rankText.TextColor3 = ({ Color3.fromRGB(170, 178, 200), Color3.fromRGB(110, 230, 150), Color3.fromRGB(110, 180, 255), Color3.fromRGB(190, 130, 255), Color3.fromRGB(255, 110, 130), Color3.fromRGB(255, 205, 80) })[idx]
	end)

	------------------------------------------------ dock
	-- vertical dock on the left (the Roblox hotbar owns the bottom centre)
	local dock = new("Frame", { Name = "Dock", Size = UDim2.fromOffset(84, 4 * 90), Position = UDim2.new(0, 14, 0.5, 130), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = screen })
	local dl = UIKit.list(dock, 8, Enum.FillDirection.Vertical)
	dl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	dl.VerticalAlignment = Enum.VerticalAlignment.Center
	for i, def in {
		{ "🚗", "GARAGE", "B", C.Blue, menus.Garage, UIAssets.IconGarage },
		{ "🏷️", "SHOP", "N", C.Accent, menus.Shop, UIAssets.IconShop },
		{ "🔧", "UPGRADES", "U", C.Good, menus.Upgrades, UIAssets.IconUpgrades },
		{ "🏭", "FACTORY", "J", Color3.fromRGB(255, 140, 40), menus.Factory, UIAssets.IconFactory },
	} do
		-- frosted glass tile: icon on a soft coloured disc, white label, key hint chip
		local tile = new("TextButton", { Size = UDim2.fromOffset(72, 76), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.08, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = dock }, {
			UIKit.corner(18),
			new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.86, Thickness = 1 }),
			new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(40, 43, 58), Color3.fromRGB(14, 15, 21)), Rotation = 90 }),
		})
		local disc = new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0.5, -23, 0, 7), BackgroundColor3 = def[4], BackgroundTransparency = 0.78, Parent = tile }, { UIKit.corner(23) })
		if def[6] ~= "" then
			new("ImageLabel", { Image = def[6], BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(4, 4), Parent = disc })
		else
			UIKit.label({ Text = def[1], TextSize = 24, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = disc })
		end
		UIKit.label({ Text = def[2], Font = UIKit.FontHeavy, TextSize = 10, TextColor3 = Color3.fromRGB(235, 238, 245), Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 56), TextXAlignment = Enum.TextXAlignment.Center, Parent = tile })
		local keyChip = new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, Parent = tile }, { UIKit.corner(5) })
		UIKit.label({ Text = def[3], Font = UIKit.FontHeavy, TextSize = 10, TextColor3 = C.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = keyChip })
		local s = new("UIScale", { Parent = tile })
		local stroke = tile:FindFirstChildOfClass("UIStroke")
		tile.MouseEnter:Connect(function()
			TweenService:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 1.06 }):Play()
			TweenService:Create(disc, TweenInfo.new(0.14), { BackgroundTransparency = 0.55 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.14), { Color = def[4], Transparency = 0.3 }):Play()
		end)
		tile.MouseLeave:Connect(function()
			TweenService:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
			TweenService:Create(disc, TweenInfo.new(0.14), { BackgroundTransparency = 0.78 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.14), { Color = Color3.new(1, 1, 1), Transparency = 0.86 }):Play()
		end)
		tile.Activated:Connect(def[5].toggle)
	end

	------------------------------------------------ toasts
	local toasts = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(520, 320), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = screen })
	UIKit.list(toasts, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function toast(info)
		local big = info.big
		local color = info.color or C.Text
		-- frosted pill with a coloured dot; text in white so it's easy to read
		local t = new("Frame", { Size = UDim2.fromOffset(big and 520 or 420, big and 46 or 38), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1, Parent = toasts }, {
			UIKit.corner(big and 23 or 19),
			new("UIStroke", { Color = color, Transparency = 0.55, Thickness = 1 }),
			new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(38, 41, 55), Color3.fromRGB(14, 15, 21)), Rotation = 90 }),
		})
		new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 16, 0.5, -5), BackgroundColor3 = color, Parent = t }, { UIKit.corner(5) })
		local text = UIKit.label({ Text = info.text, Font = big and UIKit.FontHeavy or UIKit.Font, TextSize = big and 18 or 14, TextColor3 = big and color or Color3.fromRGB(238, 240, 246), TextWrapped = true, Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(36, 0), Parent = t })
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
	local gauge = new("Frame", { Name = "Gauge", Size = UDim2.fromOffset(190, 190), Position = UDim2.new(1, -18, 1, -18), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, Visible = false, Parent = screen }, { UIKit.corner(95), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.8, Thickness = 1.5 }) })
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
	local carPanel = new("Frame", { Size = UDim2.fromOffset(250, 58), Position = UDim2.new(1, -216, 1, -18), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, Visible = false, Parent = screen }, { UIKit.corner(16), new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85, Thickness = 1 }) })
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
