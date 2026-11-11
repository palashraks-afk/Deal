-- UI toolkit: street-racing look. Carbon-dark panels, slanted neon accent stripes,
-- chunky type, rarity-coloured trims. Every screen builds from these pieces.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Sounds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Sounds"))

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(14, 15, 20),
	Panel2 = Color3.fromRGB(24, 26, 34),
	Panel3 = Color3.fromRGB(34, 37, 48),
	Stroke = Color3.fromRGB(58, 62, 80),
	Text = Color3.fromRGB(240, 242, 248),
	Muted = Color3.fromRGB(140, 146, 168),
	Accent = Color3.fromRGB(255, 196, 40), -- taxi yellow
	Hot = Color3.fromRGB(255, 70, 90), -- racing red
	Good = Color3.fromRGB(70, 230, 130),
	Bad = Color3.fromRGB(255, 80, 90),
	Blue = Color3.fromRGB(60, 150, 255),
	Purple = Color3.fromRGB(170, 90, 255),
}
UIKit.Font = Enum.Font.GothamBold
UIKit.FontHeavy = Enum.Font.GothamBlack
UIKit.FontMono = Enum.Font.RobotoMono

function UIKit.new(className: string, props, children)
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = UIKit.new

function UIKit.corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

function UIKit.stroke(color: Color3?, thickness: number?)
	return new("UIStroke", { Color = color or UIKit.Colors.Stroke, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function UIKit.gradient(c0: Color3, c1: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rotation or 90 })
end

function UIKit.pad(px: number)
	return new("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end

function UIKit.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

-- A slanted "racing stripe" bar (a rotated frame clipped by its parent).
function UIKit.stripe(parent, color: Color3, x: number, width: number?)
	return new("Frame", {
		Size = UDim2.new(0, width or 10, 2, 0),
		Position = UDim2.new(0, x, -0.5, 0),
		Rotation = 20,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

function UIKit.button(text: string, color: Color3?, props)
	local base = {
		Text = text,
		AutoButtonColor = false,
		BackgroundColor3 = color or UIKit.Colors.Blue,
		TextColor3 = Color3.new(1, 1, 1),
		Font = UIKit.FontHeavy,
		TextSize = 14,
		Size = UDim2.fromOffset(110, 34),
	}
	for k, v in props or {} do
		base[k] = v
	end
	local b = new("TextButton", base, { UIKit.corner(7), UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90) })
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
		Sounds.play("Click", nil, 0.4)
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	return b
end

local screen
function UIKit.screen(): ScreenGui
	if not screen then
		screen = new("ScreenGui", {
			Name = "DrivinDealzUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		})
		local scale = new("UIScale", { Name = "Scale", Parent = screen })
		local function rescale()
			local cam = workspace.CurrentCamera
			local v = cam and cam.ViewportSize or Vector2.new(1280, 800)
			scale.Scale = math.clamp(math.min(v.Y / 820, v.X / 1300), 0.55, 1.15)
		end
		rescale()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return screen
end

function UIKit.scale(): number
	return UIKit.screen().Scale.Scale
end

-- A centred window: carbon panel, coloured header band with slanted stripes, close button.
local openWindow
function UIKit.window(title: string, size: Vector2, accent: Color3?)
	accent = accent or UIKit.Colors.Accent
	local frame = new("Frame", {
		Name = title,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UIKit.Colors.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = UIKit.screen(),
	}, { UIKit.corner(16), UIKit.stroke(accent, 2) })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(28, 30, 40), Color3.fromRGB(10, 11, 15)), Rotation = 90, Parent = frame })

	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = accent, ClipsDescendants = true, ZIndex = 6, Parent = frame }, { UIKit.corner(16) })
	new("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 6, Parent = header })
	for i = 0, 2 do
		local s = UIKit.stripe(header, Color3.new(0, 0, 0), size.X - 210 + i * 22, 9)
		s.BackgroundTransparency = 0.75
		s.ZIndex = 6
	end
	UIKit.label({ Text = string.upper(title), Font = UIKit.FontHeavy, TextSize = 26, TextColor3 = Color3.fromRGB(16, 14, 10), Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(22, 0), ZIndex = 7, Parent = header })
	local close = UIKit.button("X",Color3.fromRGB(16, 16, 20), { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -50, 0, 9), TextSize = 18, ZIndex = 8, Parent = header })
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, -32, 1, -76), Position = UDim2.fromOffset(16, 66), ZIndex = 6, Parent = frame })

	local win = { frame = frame, body = body, accent = accent }
	function win.open()
		if openWindow and openWindow ~= win then
			openWindow.close()
		end
		openWindow = win
		frame.Visible = true
		frame.Position = UDim2.new(0.5, 0, 0.5, 30)
		TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		if win.onOpen then
			win.onOpen()
		end
	end
	function win.close()
		frame.Visible = false
		if openWindow == win then
			openWindow = nil
		end
	end
	function win.toggle()
		if frame.Visible then
			win.close()
		else
			win.open()
		end
	end
	close.Activated:Connect(win.close)
	return win
end

function UIKit.list(parent, padding: number?, fill: Enum.FillDirection?)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = fill or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UIKit.scroll(props)
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIKit.Colors.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
	}
	for k, v in props do
		base[k] = v
	end
	return new("ScrollingFrame", base)
end

-- Row of tab buttons; calls onPick(key). Returns a function to highlight a key.
function UIKit.tabs(parent, defs, onPick)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, ZIndex = 6, Parent = parent })
	UIKit.list(row, 8, Enum.FillDirection.Horizontal)
	local buttons = {}
	local function highlight(key)
		for k, b in buttons do
			b.BackgroundColor3 = k == key and UIKit.Colors.Accent or UIKit.Colors.Panel3
			b.TextColor3 = k == key and Color3.fromRGB(16, 14, 10) or UIKit.Colors.Text
		end
	end
	for i, d in defs do
		local b = UIKit.button(d[1], UIKit.Colors.Panel3, { Size = UDim2.fromOffset(d[3] or 130, 36), LayoutOrder = i, ZIndex = 7, Parent = row })
		buttons[d[2]] = b
		b.Activated:Connect(function()
			highlight(d[2])
			onPick(d[2])
		end)
	end
	return highlight, row
end

-- Horizontal stat bar (0..1).
function UIKit.bar(parent, frac: number, color: Color3, props)
	local back = new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = UIKit.Colors.Panel3, ZIndex = 7, Parent = parent }, { UIKit.corner(4) })
	for k, v in props or {} do
		back[k] = v
	end
	new("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0.02, 1), 1), BackgroundColor3 = color, ZIndex = 8, Parent = back }, { UIKit.corner(4) })
	return back
end

return UIKit
