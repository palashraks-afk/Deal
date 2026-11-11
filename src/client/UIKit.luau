-- Small UI toolkit so every screen shares one look: dark glass panels, rounded corners,
-- rarity-coloured accents.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Colors = {
	Panel = Color3.fromRGB(16, 18, 26),
	Panel2 = Color3.fromRGB(26, 29, 40),
	Stroke = Color3.fromRGB(60, 66, 86),
	Text = Color3.fromRGB(236, 238, 245),
	Muted = Color3.fromRGB(150, 156, 175),
	Accent = Color3.fromRGB(255, 196, 40),
	Good = Color3.fromRGB(80, 220, 120),
	Bad = Color3.fromRGB(255, 80, 90),
	Blue = Color3.fromRGB(70, 150, 255),
}
UIKit.Font = Enum.Font.GothamBold
UIKit.FontHeavy = Enum.Font.GothamBlack

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

function UIKit.button(text: string, color: Color3?, props)
	local base = {
		Text = text,
		AutoButtonColor = true,
		BackgroundColor3 = color or UIKit.Colors.Blue,
		TextColor3 = Color3.new(1, 1, 1),
		Font = UIKit.Font,
		TextSize = 15,
		Size = UDim2.fromOffset(110, 34),
	}
	for k, v in props or {} do
		base[k] = v
	end
	local b = new("TextButton", base, { UIKit.corner(8) })
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0.15 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundTransparency = 0 }):Play()
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
		-- shrink everything on small screens
		local scale = new("UIScale", { Parent = screen })
		local function rescale()
			local cam = workspace.CurrentCamera
			local y = cam and cam.ViewportSize.Y or 800
			scale.Scale = math.clamp(y / 820, 0.6, 1.15)
		end
		rescale()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	return screen
end

-- A centred window with a title bar and close button. Only one window shows at a time.
local openWindow
function UIKit.window(title: string, size: Vector2)
	local frame = new("Frame", {
		Name = title,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = UIKit.screen(),
	}, { UIKit.corner(14), UIKit.stroke() })
	UIKit.label({ Text = title, Font = UIKit.FontHeavy, TextSize = 24, Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(20, 6), Parent = frame })
	local close = UIKit.button("X", UIKit.Colors.Bad, { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -46, 0, 12), Parent = frame })
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, -32, 1, -70), Position = UDim2.fromOffset(16, 56), Parent = frame })

	local win = { frame = frame, body = body }
	function win.open()
		if openWindow and openWindow ~= win then
			openWindow.close()
		end
		openWindow = win
		frame.Visible = true
		frame.Size = UDim2.fromOffset(size.X * 0.92, size.Y * 0.92)
		TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(size.X, size.Y) }):Play()
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
		ScrollBarImageColor3 = UIKit.Colors.Stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}
	for k, v in props do
		base[k] = v
	end
	return new("ScrollingFrame", base)
end

return UIKit
