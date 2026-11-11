-- Top-right minimap, north-up, centred on you. Shows roads, blocks, plots (yours in gold),
-- other players, and every city find in its rarity colour. Press M for a big map.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local UIKit = require(script.Parent.UIKit)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local Minimap = {}

local SCALE = 0.36 -- pixels per stud
local SMALL, BIG = 230, 560

function Minimap.start()
	local map = workspace:WaitForChild("Map")
	local screen = UIKit.screen()

	local holder = new("Frame", {
		Name = "Minimap",
		Size = UDim2.fromOffset(SMALL, SMALL),
		Position = UDim2.new(1, -14, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(58, 86, 52),
		ClipsDescendants = true,
		Parent = screen,
	}, { UIKit.corner(16), UIKit.stroke(C.Stroke, 2.5) })

	-- world bounds from the ground part
	local ground = map:WaitForChild("Ground")
	local minX = ground.Position.X - ground.Size.X / 2
	local minZ = ground.Position.Z - ground.Size.Z / 2
	local canvas = new("Frame", {
		Name = "Canvas",
		Size = UDim2.fromOffset(ground.Size.X * SCALE, ground.Size.Z * SCALE),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local function toCanvas(pos: Vector3): UDim2
		return UDim2.fromOffset((pos.X - minX) * SCALE, (pos.Z - minZ) * SCALE)
	end
	local function rect(part: BasePart, color: Color3, z: number)
		new("Frame", {
			Size = UDim2.fromOffset(math.max(2, part.Size.X * SCALE), math.max(2, part.Size.Z * SCALE)),
			Position = toCanvas(part.Position),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = canvas,
		})
	end
	for _, p in map:WaitForChild("Blocks"):GetChildren() do
		if p:IsA("BasePart") then
			rect(p, p.Name == "Park" and Color3.fromRGB(70, 130, 60) or Color3.fromRGB(120, 122, 130), 1)
		end
	end
	for _, p in map:WaitForChild("Roads"):GetChildren() do
		if p.Name == "Road" then
			rect(p, Color3.fromRGB(40, 42, 48), 2)
		end
	end
	local plotFrames = {}
	for _, plot in map:WaitForChild("Plots"):GetChildren() do
		local floor = plot:WaitForChild("Floor")
		local f = new("Frame", {
			Size = UDim2.fromOffset(floor.Size.X * SCALE, floor.Size.Z * SCALE),
			Position = toCanvas(floor.Position),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(190, 190, 195),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = canvas,
		}, { UIKit.corner(3) })
		plotFrames[plot] = f
	end

	-- blips layer
	local blips = new("Folder", { Name = "Blips", Parent = canvas })
	local me = new("TextLabel", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = "▲",
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(80, 200, 255),
		TextStrokeTransparency = 0,
		ZIndex = 10,
		Parent = holder,
	})
	local compass = UIKit.label({ Text = "N", Font = UIKit.FontHeavy, TextSize = 16, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, -10, 0, 4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11, Parent = holder })
	compass.TextStrokeTransparency = 0.4

	local function blip(pos: Vector3, color: Color3, size: number, z: number)
		new("Frame", {
			Size = UDim2.fromOffset(size, size),
			Position = toCanvas(pos),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = blips,
		}, { UIKit.corner(size), UIKit.stroke(Color3.new(0, 0, 0), 1) })
	end

	local function refreshBlips()
		blips:ClearAllChildren()
		local finds = workspace:FindFirstChild("CityFinds")
		if finds then
			for _, f in finds:GetChildren() do
				local rarity = f:GetAttribute("Rarity")
				local color = rarity and Config.Rarity[rarity] and Config.Rarity[rarity].color or C.Text
				local pos
				if f:IsA("ObjectValue") then
					local m = f.Value
					pos = m and m.PrimaryPart and m.PrimaryPart.Position
				elseif f:IsA("Model") then
					pos = f:GetPivot().Position
				end
				if pos then
					local idx = table.find(Config.RarityOrder, rarity) or 1
					blip(pos, color, f:GetAttribute("Kind") == "Blueprint" and 8 or 9 + idx, 6 + idx)
				end
			end
		end
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character and other.Character.PrimaryPart then
				blip(other.Character.PrimaryPart.Position, Color3.fromRGB(255, 70, 70), 8, 9)
			end
		end
		for plot, frame in plotFrames do
			frame.BackgroundColor3 = plot:GetAttribute("OwnerUserId") == player.UserId and C.Accent or Color3.fromRGB(190, 190, 195)
		end
	end
	task.spawn(function()
		while true do
			refreshBlips()
			task.wait(0.4)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local p = root.Position
		local size = holder.AbsoluteSize / (UIKit.screen():FindFirstChildOfClass("UIScale").Scale)
		canvas.Position = UDim2.fromOffset(size.X / 2 - (p.X - minX) * SCALE, size.Y / 2 - (p.Z - minZ) * SCALE)
		local look = workspace.CurrentCamera.CFrame.LookVector
		me.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			local big = holder.Size.X.Offset == SMALL
			holder.Size = UDim2.fromOffset(big and BIG or SMALL, big and BIG or SMALL)
		end
	end)
end

return Minimap
