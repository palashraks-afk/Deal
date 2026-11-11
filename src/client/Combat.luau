-- Client side of the Disabler: hold click to fire at the mouse/tap point, draw tracers,
-- and show a crosshair + target car health while aiming.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Combat = {}

local function tracer(from: Vector3, to: Vector3, color: Color3)
	local dist = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.18, 0.18, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	Debris:AddItem(p, 0.06)
	local spark = Instance.new("Part")
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.Shape = Enum.PartType.Ball
	spark.Material = Enum.Material.Neon
	spark.Color = color
	spark.Size = Vector3.one * 0.9
	spark.Position = to
	spark.Parent = workspace
	Debris:AddItem(spark, 0.08)
end

function Combat.start()
	local firing = false
	local lastFire = 0

	local cross = UIKit.label({ Text = "+", Font = UIKit.FontHeavy, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = UIKit.screen() })
	cross.TextColor3 = Color3.fromRGB(120, 220, 255)
	cross.TextStrokeTransparency = 0.3
	local targetInfo = UIKit.label({ Text = "", TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(240, 20), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = UIKit.screen() })
	targetInfo.TextStrokeTransparency = 0.3

	local function equippedTool()
		local char = player.Character
		return char and char:FindFirstChild("Disabler")
	end

	local function aimPoint(): Vector3
		return mouse.Hit.Position
	end

	local function hookTool(tool: Tool)
		tool.Activated:Connect(function()
			firing = true
		end)
		tool.Deactivated:Connect(function()
			firing = false
		end)
		tool.Unequipped:Connect(function()
			firing = false
		end)
	end
	local function watch(container)
		container.ChildAdded:Connect(function(c)
			if c:IsA("Tool") and c.Name == "Disabler" and not c:GetAttribute("Hooked") then
				c:SetAttribute("Hooked", true)
				hookTool(c)
			end
		end)
	end
	player.CharacterAdded:Connect(function(char)
		watch(char)
		watch(player:WaitForChild("Backpack"))
	end)
	if player.Character then
		watch(player.Character)
		local tool = player.Character:FindFirstChild("Disabler") or player:WaitForChild("Backpack"):FindFirstChild("Disabler")
		if tool then
			tool:SetAttribute("Hooked", true)
			hookTool(tool)
		end
		watch(player:WaitForChild("Backpack"))
	end

	RunService.RenderStepped:Connect(function()
		local tool = equippedTool()
		cross.Visible = tool ~= nil
		targetInfo.Visible = false
		if not tool then
			UserInputService.MouseIconEnabled = true
			return
		end
		local pos = UserInputService:GetMouseLocation()
		local inset = game:GetService("GuiService"):GetGuiInset()
		local scale = UIKit.screen():FindFirstChildOfClass("UIScale").Scale
		cross.Position = UDim2.fromOffset((pos.X - inset.X) / scale, (pos.Y - inset.Y) / scale)
		targetInfo.Position = UDim2.fromOffset((pos.X - inset.X) / scale, (pos.Y - inset.Y) / scale + 18)

		-- show the car under the crosshair
		local target = mouse.Target
		local node = target
		while node and node.Parent and node.Parent ~= workspace and node.Parent.Name ~= "Vehicles" do
			node = node.Parent
		end
		if node and node.Parent and node.Parent.Name == "Vehicles" and node:GetAttribute("MaxHealth") then
			targetInfo.Visible = true
			targetInfo.Text = ("%s  %d/%d"):format(node:GetAttribute("CarName") or "", node:GetAttribute("Health") or 0, node:GetAttribute("MaxHealth"))
			local r = node:GetAttribute("Rarity")
			targetInfo.TextColor3 = r and Config.Rarity[r] and Config.Rarity[r].color or Color3.new(1, 1, 1)
		end

		if firing and os.clock() - lastFire >= Config.Blaster.FireRate then
			lastFire = os.clock()
			local muzzle = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Muzzle")
			local hit = aimPoint()
			if muzzle then
				tracer(muzzle.WorldPosition, hit, Color3.fromRGB(120, 220, 255)) -- instant local feedback
			end
			Net.Fire:FireServer(hit)
		end
	end)

	Net.Tracer.OnClientEvent:Connect(function(shooter, from, to)
		if shooter ~= player then
			tracer(from, to, Color3.fromRGB(255, 90, 90))
		end
	end)
end

return Combat
