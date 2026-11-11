-- Minimap (top-left, north-up, follows you) + full map (press M): every area, road and
-- plot is drawn from the world. Click anywhere on the full map to set a waypoint.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local UIKit = require(script.Parent.UIKit)
local Waypoint = require(script.Parent.Waypoint)

local new = UIKit.new
local C = UIKit.Colors
local player = Players.LocalPlayer

local Minimap = {}

local SMALL_SIZE, SMALL_SCALE = 230, 0.3 -- px, px per stud
local BIG_SIZE = 640

function Minimap.start()
	local map = workspace:WaitForChild("Map")
	local screen = UIKit.screen()
	local halfX = map:GetAttribute("HalfX") or 2000
	local halfZ = map:GetAttribute("HalfZ") or 1400
	local minX, minZ = -halfX - 200, -halfZ - 200
	local worldW, worldD = halfX * 2 + 400, halfZ * 2 + 400

	-- one canvas at 1 px/stud * scale; we just change its scale for small vs big
	-- CanvasGroup so the round GPS shape really clips the map (plain Frames clip square)
	local holder = new("CanvasGroup", { Name = "Minimap", Size = UDim2.fromOffset(SMALL_SIZE, SMALL_SIZE), Position = UDim2.new(0, 14, 0, 62), BackgroundColor3 = Color3.fromRGB(60, 90, 60), Parent = screen }, { UIKit.corner(SMALL_SIZE / 2) })
	-- ring drawn outside the clip
	local ring = new("Frame", { Name = "MinimapRing", Size = UDim2.fromOffset(SMALL_SIZE + 8, SMALL_SIZE + 8), Position = UDim2.new(0, 10, 0, 58), BackgroundTransparency = 1, Parent = screen }, { UIKit.corner(SMALL_SIZE), UIKit.stroke(C.Accent, 3) })
	local canvas = new("Frame", { Name = "Canvas", BackgroundTransparency = 1, Parent = holder })
	local scale = SMALL_SCALE

	local drawn = {}
	local function addRect(part: BasePart)
		local col = part:GetAttribute("MapColor")
		if not col then
			return
		end
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			Rotation = part.Orientation.Y == 0 and 0 or -part.Orientation.Y,
			ZIndex = part:GetAttribute("MapLayer") or 1,
			Parent = canvas,
		})
		table.insert(drawn, { frame = f, part = part, size = Vector2.new(part.Size.X, part.Size.Z), pos = Vector2.new(part.Position.X, part.Position.Z) })
		local text = part:GetAttribute("MapLabel")
		if text then
			local l = UIKit.label({ Text = text, Font = UIKit.FontHeavy, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(120, 16), ZIndex = 9, Parent = canvas })
			l.TextStrokeTransparency = 0.3
			table.insert(drawn, { frame = l, pos = Vector2.new(part.Position.X, part.Position.Z), label = true })
		end
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			addRect(d)
		end
	end

	local function place(d)
		local p = (d.pos - Vector2.new(minX, minZ)) * scale
		d.frame.Position = UDim2.fromOffset(p.X, p.Y)
		if not d.label then
			d.frame.Size = UDim2.fromOffset(math.max(2, d.size.X * scale), math.max(2, d.size.Y * scale))
		end
	end
	local function layout()
		canvas.Size = UDim2.fromOffset(worldW * scale, worldD * scale)
		for _, d in drawn do
			place(d)
		end
	end
	layout()
	-- parts that replicate in after we start still get drawn
	map.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(function()
				local before = #drawn
				addRect(d)
				for i = before + 1, #drawn do
					place(drawn[i])
				end
			end)
		end
	end)

	local blips = new("Folder", { Name = "Blips", Parent = canvas })
	local me = UIKit.label({ Text = "▲", Font = UIKit.FontHeavy, TextSize = 22, TextColor3 = Color3.fromRGB(80, 200, 255), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, Parent = holder })
	me.TextStrokeTransparency = 0
	local compass = UIKit.label({ Text = "N", Font = UIKit.FontHeavy, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, -10, 0, 4), ZIndex = 21, Parent = holder })
	compass.TextStrokeTransparency = 0.3
	local hint = UIKit.label({ Text = "M: map", Font = UIKit.Font, TextSize = 11, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16), ZIndex = 21, Parent = holder })
	hint.TextStrokeTransparency = 0.5
	local wpDot = new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = C.Accent, Visible = false, ZIndex = 22, Parent = canvas }, { UIKit.stroke(Color3.new(0, 0, 0), 1.5) })

	local function toCanvas(pos: Vector3): UDim2
		return UDim2.fromOffset((pos.X - minX) * scale, (pos.Z - minZ) * scale)
	end
	local function blip(pos: Vector3, color: Color3, size: number, z: number)
		new("Frame", { Size = UDim2.fromOffset(size, size), Position = toCanvas(pos), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z, Parent = blips }, { UIKit.corner(size), UIKit.stroke(Color3.new(0, 0, 0), 1) })
	end
	local function refreshBlips()
		blips:ClearAllChildren()
		local finds = workspace:FindFirstChild("CityFinds")
		for _, f in finds and finds:GetChildren() or {} do
			local rarity = f:GetAttribute("Rarity")
			local m = f:IsA("ObjectValue") and f.Value or f
			local pos = m and m:IsA("Model") and m.PrimaryPart and m.PrimaryPart.Position
			if pos then
				local idx = table.find(Config.RarityOrder, rarity) or 1
				blip(pos, Config.Rarity[rarity] and Config.Rarity[rarity].color or C.Text, 7 + idx, 10 + idx)
			end
		end
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character and other.Character.PrimaryPart then
				blip(other.Character.PrimaryPart.Position, Color3.fromRGB(255, 70, 70), 8, 18)
			end
		end
		for _, plot in map.Plots:GetChildren() do
			local floor = plot:FindFirstChild("Floor")
			if floor then
				local mine = plot:GetAttribute("OwnerUserId") == player.UserId
				floor:SetAttribute("MapColor", mine and C.Accent or Color3.fromRGB(200, 200, 205))
			end
		end
		for _, d in drawn do
			if d.part and d.part.Name == "Floor" then
				d.frame.BackgroundColor3 = d.part:GetAttribute("MapColor")
			end
		end
		if Waypoint.Position then
			wpDot.Visible = true
			wpDot.Position = toCanvas(Waypoint.Position)
		else
			wpDot.Visible = false
		end
	end
	task.spawn(function()
		while true do
			refreshBlips()
			task.wait(0.5)
		end
	end)

	local big = false
	local function setBig(on: boolean)
		big = on
		local corner = holder:FindFirstChildOfClass("UICorner")
		if on then
			scale = BIG_SIZE / math.max(worldW, worldD) * 1.0
			holder.Size = UDim2.fromOffset(worldW * scale, worldD * scale)
			holder.Position = UDim2.fromScale(0.5, 0.5)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			corner.CornerRadius = UDim.new(0, 18)
			ring.Visible = false
			hint.Text = "Click to set a waypoint • right-click to clear • M to close"
		else
			scale = SMALL_SCALE
			holder.Size = UDim2.fromOffset(SMALL_SIZE, SMALL_SIZE)
			holder.Position = UDim2.new(0, 14, 0, 62)
			holder.AnchorPoint = Vector2.new(0, 0)
			corner.CornerRadius = UDim.new(0, SMALL_SIZE / 2)
			ring.Visible = true
			hint.Text = "M: map"
		end
		layout()
		refreshBlips()
	end
	Minimap.setBig = setBig
	Minimap.Frame = holder

	RunService.RenderStepped:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local p = root.Position
		local look = workspace.CurrentCamera.CFrame.LookVector
		me.Rotation = math.deg(math.atan2(look.X, -look.Z))
		if big then
			canvas.Position = UDim2.fromOffset(0, 0)
			me.Position = toCanvas(p)
		else
			local size = holder.AbsoluteSize / UIKit.scale()
			canvas.Position = UDim2.fromOffset(size.X / 2 - (p.X - minX) * scale, size.Y / 2 - (p.Z - minZ) * scale)
			me.Position = UDim2.fromScale(0.5, 0.5)
		end
	end)

	-- clicking the map sets a waypoint
	holder.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			Waypoint.clear()
			return
		end
		local s = UIKit.scale()
		local rel = (Vector2.new(input.Position.X, input.Position.Y) - canvas.AbsolutePosition) / s
		local world = Vector3.new(rel.X / scale + minX, 2, rel.Y / scale + minZ)
		Waypoint.set(world, "WAYPOINT")
		if big then
			setBig(false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.M then
			setBig(not big)
		end
	end)
end

return Minimap
