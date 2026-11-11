-- One active waypoint: a tall light beam in the world + an on-screen marker that sticks to
-- the screen edge when it's off-screen, with the distance. Used by the map (click to set),
-- the tutorial, and "show me" buttons.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local new = UIKit.new

local Waypoint = {}
Waypoint.Position = nil :: Vector3?
Waypoint.Changed = Instance.new("BindableEvent")

local beamPart, marker, label, distText
local color = UIKit.Colors.Accent

local function ensure()
	if marker then
		return
	end
	local screen = UIKit.screen()
	marker = new("Frame", { Name = "Waypoint", Size = UDim2.fromOffset(150, 54), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = screen })
	local diamond = new("Frame", { Name = "Diamond", Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = color, ZIndex = 30, Parent = marker }, { UIKit.stroke(Color3.new(0, 0, 0), 2) })
	local _ = diamond
	label = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 26), ZIndex = 30, Parent = marker })
	label.TextStrokeTransparency = 0.2
	distText = UIKit.label({ Text = "", Font = UIKit.FontHeavy, TextSize = 12, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 40), ZIndex = 30, Parent = marker })
	distText.TextStrokeTransparency = 0.2
end

function Waypoint.set(pos: Vector3, text: string?, c: Color3?)
	ensure()
	Waypoint.clear(true)
	color = c or UIKit.Colors.Accent
	Waypoint.Position = pos
	marker.Diamond.BackgroundColor3 = color
	distText.TextColor3 = color
	label.Text = text or "WAYPOINT"
	-- world beam
	beamPart = Instance.new("Part")
	beamPart.Name = "WaypointBeam"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanQuery = false
	beamPart.CanTouch = false
	beamPart.CastShadow = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = color
	beamPart.Transparency = 0.55
	beamPart.Shape = Enum.PartType.Cylinder
	beamPart.Size = Vector3.new(300, 3, 3)
	beamPart.CFrame = CFrame.new(pos + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beamPart.Parent = workspace.CurrentCamera
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 16, 16)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = beamPart
	marker.Visible = true
	Waypoint.Changed:Fire(pos)
end

function Waypoint.clear(silent: boolean?)
	if beamPart then
		beamPart:Destroy()
		beamPart = nil
	end
	Waypoint.Position = nil
	if marker then
		marker.Visible = false
	end
	if not silent then
		Waypoint.Changed:Fire(nil)
	end
end

function Waypoint.start()
	ensure()
	RunService.RenderStepped:Connect(function()
		local pos = Waypoint.Position
		if not pos then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if not root then
			return
		end
		local dist = (Vector3.new(pos.X, root.Position.Y, pos.Z) - root.Position).Magnitude
		distText.Text = ("%dm"):format(math.floor(dist / 4))
		if dist < 25 and label.Text == "WAYPOINT" then
			Waypoint.clear()
			return
		end
		local scale = UIKit.scale()
		local vp = cam.ViewportSize / scale
		local sp, onScreen = cam:WorldToViewportPoint(pos + Vector3.new(0, 6, 0))
		local x, y = sp.X / scale, sp.Y / scale - 36
		if not onScreen or sp.Z < 0 then
			-- clamp to the screen edge in the direction of the target
			local dir = (Vector2.new(x, y) - vp / 2)
			if sp.Z < 0 then
				dir = -dir
			end
			if dir.Magnitude < 1 then
				dir = Vector2.new(0, 1)
			end
			dir = dir.Unit
			local edge = vp / 2 - Vector2.new(80, 60)
			local t = math.min(math.abs(edge.X / dir.X), math.abs(edge.Y / dir.Y))
			local p = vp / 2 + dir * t
			x, y = p.X, p.Y
		else
			x = math.clamp(x, 70, vp.X - 70)
			y = math.clamp(y, 40, vp.Y - 40)
		end
		marker.Position = UDim2.fromOffset(x, y)
	end)
end

return Waypoint
