-- UI toolkit: sleek automotive look. Frosted dark-glass panels with soft shadows,
-- rounded lit buttons, segmented tabs, rarity-coloured trims. Every screen builds
-- from these pieces.
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

-- Soft drop shadow (a 9-slice blur image) placed behind a frame.
UIKit.ShadowImage = "rbxassetid://1316045217"
-- Children always draw above their parent, so the shadow is a sibling that follows
-- the target's position, size, anchor and visibility.
function UIKit.shadow(target: GuiObject, spread: number?, transparency: number?)
	spread = spread or 18
	local sh = new("ImageLabel", {
		Name = target.Name .. "Shadow",
		Image = UIKit.ShadowImage,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = transparency or 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		BackgroundTransparency = 1,
		ZIndex = math.max(target.ZIndex - 1, 0),
		Parent = target.Parent,
	})
	local function sync()
		sh.AnchorPoint = target.AnchorPoint
		local s, p = target.Size, target.Position
		sh.Size = UDim2.new(s.X.Scale, s.X.Offset + spread * 2, s.Y.Scale, s.Y.Offset + spread * 2)
		-- keep centred on the target whatever its anchor point is
		local ax, ay = target.AnchorPoint.X, target.AnchorPoint.Y
		sh.Position = UDim2.new(p.X.Scale, p.X.Offset - spread * (1 - 2 * ax), p.Y.Scale, p.Y.Offset - spread * (1 - 2 * ay) + 6)
		sh.Visible = target.Visible
	end
	for _, prop in { "Position", "Size", "AnchorPoint", "Visible" } do
		target:GetPropertyChangedSignal(prop):Connect(sync)
	end
	sync()
	return sh
end

-- Rounded, lit button: soft top highlight, darker rim, presses in when clicked.
function UIKit.button(text: string, color: Color3?, props)
	local base = {
		Text = text,
		AutoButtonColor = false,
		BackgroundColor3 = color or UIKit.Colors.Blue,
		TextColor3 = Color3.new(1, 1, 1),
		Font = UIKit.Font,
		TextSize = 15,
		Size = UDim2.fromOffset(110, 36),
	}
	for k, v in props or {} do
		base[k] = v
	end
	local h, s, v = (base.BackgroundColor3 :: Color3):ToHSV()
	local rim = Color3.fromHSV(h, s, v * 0.6)
	local r = math.min(12, math.floor((base.Size :: UDim2).Y.Offset / 2.4))
	local b = new("TextButton", base, {
		UIKit.corner(r > 0 and r or 10),
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)), ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 185)) }), Rotation = 90 }),
		new("UIStroke", { Color = rim, Thickness = 1.2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	-- text sits slightly raised with a faint shadow
	b.TextStrokeColor3 = Color3.new(0, 0, 0)
	b.TextStrokeTransparency = 0.75
	local scale = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.03 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.05), { Scale = 0.96 }):Play()
		Sounds.play("Click", nil, 0.4)
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1.03 }):Play()
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

-- A centred window: frosted dark glass with a soft shadow, a clean header with a
-- thin accent line, and a round close button. The world behind dims and blurs.
local openWindow
local backdrop, blur
local function setBackdrop(on: boolean)
	if not backdrop then
		backdrop = new("Frame", { Name = "Backdrop", Size = UDim2.new(1, 0, 1, 80), Position = UDim2.fromOffset(0, -60), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 1, Parent = UIKit.screen() })
		blur = Instance.new("BlurEffect")
		blur.Name = "MenuBlur"
		blur.Size = 0
		blur.Parent = workspace.CurrentCamera
	end
	backdrop.Visible = true
	TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = on and 0.55 or 1 }):Play()
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = on and 10 or 0 }):Play()
	if not on then
		task.delay(0.21, function()
			if not openWindow then
				backdrop.Visible = false
			end
		end)
	end
end

function UIKit.window(title: string, size: Vector2, accent: Color3?)
	accent = accent or UIKit.Colors.Accent
	local frame = new("Frame", {
		Name = title,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.06,
		Visible = false,
		ZIndex = 5,
		Parent = UIKit.screen(),
	}, { UIKit.corner(20), new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.86, Thickness = 1 }) })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(34, 37, 50), Color3.fromRGB(12, 13, 18)), Rotation = 90, Parent = frame })
	local winScale = new("UIScale", { Parent = frame })

	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, ZIndex = 6, Parent = frame })
	-- accent pill next to the title + hairline under the header
	new("Frame", { Size = UDim2.fromOffset(6, 26), Position = UDim2.fromOffset(22, 17), BackgroundColor3 = accent, ZIndex = 7, Parent = header }, { UIKit.corner(3) })
	UIKit.label({ Text = title, Font = UIKit.FontHeavy, TextSize = 24, TextColor3 = UIKit.Colors.Text, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(38, 0), ZIndex = 7, Parent = header })
	new("Frame", { Size = UDim2.new(1, -40, 0, 1), Position = UDim2.new(0, 20, 1, -1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 7, Parent = header }, {
		new("UIGradient", { Color = ColorSequence.new(accent, Color3.new(1, 1, 1)), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local close = UIKit.button("X", UIKit.Colors.Panel3, { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -52, 0, 12), TextSize = 16, ZIndex = 8, Parent = header })
	close:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, -40, 1, -84), Position = UDim2.fromOffset(20, 70), ZIndex = 6, Parent = frame })

	local win = { frame = frame, body = body, accent = accent }
	function win.open()
		if openWindow and openWindow ~= win then
			openWindow.close(true)
		end
		openWindow = win
		frame.Visible = true
		setBackdrop(true)
		winScale.Scale = 0.92
		frame.Position = UDim2.new(0.5, 0, 0.5, 14)
		TweenService:Create(winScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		if win.onOpen then
			win.onOpen()
		end
	end
	function win.close(switching: boolean?)
		frame.Visible = false
		if openWindow == win then
			openWindow = nil
		end
		if not switching then
			setBackdrop(false)
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
	-- segmented control: one rounded track, the picked tab lights up inside it
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = UIKit.Colors.Panel2, BackgroundTransparency = 0.2, AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6, Parent = parent }, { UIKit.corner(12), UIKit.pad(3) })
	row.Size = UDim2.fromOffset(0, 42)
	UIKit.list(row, 4, Enum.FillDirection.Horizontal)
	local buttons = {}
	local function highlight(key)
		for k, b in buttons do
			local on = k == key
			TweenService:Create(b, TweenInfo.new(0.15), { BackgroundTransparency = on and 0 or 1, TextColor3 = on and Color3.fromRGB(16, 14, 10) or UIKit.Colors.Muted }):Play()
		end
	end
	for i, d in defs do
		local b = UIKit.button(d[1], UIKit.Colors.Accent, { Size = UDim2.fromOffset(d[3] or 130, 36), LayoutOrder = i, ZIndex = 7, BackgroundTransparency = 1, TextColor3 = UIKit.Colors.Muted, Parent = row })
		b:FindFirstChildOfClass("UIStroke").Enabled = false
		b.TextStrokeTransparency = 1
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
