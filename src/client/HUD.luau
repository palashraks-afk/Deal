-- Always-on HUD: cash + dealership level, menu buttons, toasts, speedometer and car health.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Cars = require(Shared.Cars)
local Net = require(Shared.Net)

local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.State)
local DriveController = require(script.Parent.DriveController)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local HUD = {}

function HUD.start(menus)
	local screen = UIKit.screen()

	-- Cash / level pill (top centre)
	local top = new("Frame", {
		Name = "TopBar",
		Size = UDim2.fromOffset(340, 56),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { UIKit.corner(28), UIKit.stroke(C.Accent, 2) })
	local cash = UIKit.label({ Text = "$0", Font = UIKit.FontHeavy, TextSize = 28, TextColor3 = C.Good, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, Parent = top })
	local level = UIKit.label({ Text = "Used Lot", TextSize = 14, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 36), TextXAlignment = Enum.TextXAlignment.Center, Parent = top })

	local shownCash = 0
	RunService.RenderStepped:Connect(function(dt)
		local ls = player:FindFirstChild("leaderstats")
		local target = ls and ls:FindFirstChild("Cash") and ls.Cash.Value or 0
		shownCash += (target - shownCash) * math.clamp(dt * 8, 0, 1)
		if math.abs(target - shownCash) < 1 then
			shownCash = target
		end
		cash.Text = Cars.money(shownCash)
	end)
	State.Changed.Event:Connect(function(data)
		level.Text = ("Lv %d  -  %s"):format(data.level, Config.Levels[data.level].name)
	end)

	-- Menu buttons (left)
	local side = new("Frame", { Name = "Menu", Size = UDim2.fromOffset(150, 220), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = screen })
	UIKit.list(side, 8)
	for _, def in {
		{ "Garage", "[B]", C.Blue, menus.Garage },
		{ "Dealership", "[N]", C.Accent, menus.Dealership },
		{ "Craft", "[C]", Color3.fromRGB(178, 92, 255), menus.Craft },
	} do
		local b = UIKit.button(def[1] .. "  " .. def[2], def[3], { Size = UDim2.fromOffset(150, 44), TextSize = 17, Font = UIKit.FontHeavy, Parent = side })
		if def[3] == C.Accent then
			b.TextColor3 = Color3.fromRGB(30, 24, 8)
		end
		b.Activated:Connect(def[4].toggle)
	end

	-- Toasts (top centre, under the cash bar)
	local toasts = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(520, 300), Position = UDim2.new(0.5, 0, 0, 74), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = screen })
	UIKit.list(toasts, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function toast(info)
		local big = info.big
		local t = new("TextLabel", {
			Size = UDim2.fromOffset(big and 520 or 440, big and 46 or 36),
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = 0.1,
			Font = big and UIKit.FontHeavy or UIKit.Font,
			TextSize = big and 20 or 16,
			TextColor3 = info.color or C.Text,
			TextWrapped = true,
			Text = info.text,
			Parent = toasts,
		}, { UIKit.corner(10), UIKit.stroke(info.color or C.Stroke, big and 2.5 or 1.5) })
		task.delay(big and 6 or 4, function()
			local tw = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
			tw:Play()
			tw.Completed:Wait()
			t:Destroy()
		end)
		if #toasts:GetChildren() > 7 then
			for _, c in toasts:GetChildren() do
				if c:IsA("TextLabel") then
					c:Destroy()
					break
				end
			end
		end
	end
	Net.Notify.OnClientEvent:Connect(toast)
	State.Toast.Event:Connect(toast)

	-- Speedometer + car health (bottom right, only while driving)
	local dash = new("Frame", {
		Name = "Dash",
		Size = UDim2.fromOffset(260, 120),
		Position = UDim2.new(1, -16, 1, -16),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screen,
	}, { UIKit.corner(14), UIKit.stroke() })
	local carName = UIKit.label({ Text = "", TextSize = 15, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 8), TextTruncate = Enum.TextTruncate.AtEnd, Parent = dash })
	local speed = UIKit.label({ Text = "0", Font = UIKit.FontHeavy, TextSize = 44, Size = UDim2.new(0, 140, 0, 46), Position = UDim2.fromOffset(12, 28), Parent = dash })
	UIKit.label({ Text = "KM/H", TextSize = 14, TextColor3 = C.Muted, Size = UDim2.fromOffset(60, 20), Position = UDim2.fromOffset(150, 50), Parent = dash })
	local barBack = new("Frame", { Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 84), BackgroundColor3 = C.Panel2, Parent = dash }, { UIKit.corner(6) })
	local bar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Good, Parent = barBack }, { UIKit.corner(6) })
	UIKit.label({ Text = "Shift: drift   R: flip   Space: get out", TextSize = 11, TextColor3 = C.Muted, Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 100), Parent = dash })

	RunService.RenderStepped:Connect(function()
		local car = DriveController.Car
		dash.Visible = car ~= nil
		if car then
			carName.Text = car:GetAttribute("CarName") or ""
			local rarity = car:GetAttribute("Rarity")
			carName.TextColor3 = rarity and Config.Rarity[rarity] and Config.Rarity[rarity].color or C.Text
			-- show real-feeling km/h: game stud/s -> km/h using the same scale the car was built at
			speed.Text = tostring(math.floor(math.abs(DriveController.Speed) / Config.StudsPerMeter * 3.6 * 1.6))
			local h = (car:GetAttribute("Health") or 0) / (car:GetAttribute("MaxHealth") or 1)
			bar.Size = UDim2.fromScale(math.clamp(h, 0, 1), 1)
			bar.BackgroundColor3 = h > 0.5 and C.Good or (h > 0.25 and C.Accent or C.Bad)
		end
	end)
end

return HUD
