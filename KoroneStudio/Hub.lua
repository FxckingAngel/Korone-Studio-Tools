local shared      = _G.KS_Shared or error("KS_Shared missing")
local CoreGui     = shared.CoreGui
local UserInputService = shared.UserInputService

local KS_Explorer    = _G.KS_Explorer
local KS_Editor      = _G.KS_Editor
local KS_RSpy        = _G.KS_RSpy
local KS_Secret      = _G.KS_Secret
local KS_ModelViewer = _G.KS_ModelViewer

local gui = Instance.new("ScreenGui")
gui.Name           = "KoroneStudioHub"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = CoreGui

local frame = Instance.new("Frame")
frame.AnchorPoint      = Vector2.new(0, 0.5)
frame.Position         = UDim2.new(0, 8, 0.5, 0)
frame.Size             = UDim2.new(0, 56, 0, 260)
frame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
frame.BorderSizePixel  = 0
frame.Parent           = gui
local fc = Instance.new("UICorner")
fc.CornerRadius = UDim.new(0, 14)
fc.Parent       = frame

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size             = UDim2.new(1, 0, 0, 32)
title.Font             = Enum.Font.SourceSansSemibold
title.TextSize         = 18
title.TextColor3       = Color3.new(1, 1, 1)
title.Text             = "🌙"
title.Parent           = frame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder     = Enum.SortOrder.LayoutOrder
layout.Padding       = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment   = Enum.VerticalAlignment.Center
layout.Parent        = frame

title.LayoutOrder = 0

local function makeButton(emoji, tooltip, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0, 40, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
    btn.BorderSizePixel  = 0
    btn.Font             = Enum.Font.SourceSans
    btn.Text             = emoji
    btn.TextSize         = 24
    btn.TextColor3       = Color3.new(1, 1, 1)
    btn.AutoButtonColor  = true
    btn.LayoutOrder      = order
    btn.Parent           = frame
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 12)
    bc.Parent       = btn

    local tip = Instance.new("TextLabel")
    tip.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
    tip.BorderSizePixel  = 0
    tip.TextColor3       = Color3.new(1, 1, 1)
    tip.Font             = Enum.Font.SourceSans
    tip.TextSize         = 12
    tip.Text             = tooltip
    tip.Visible          = false
    tip.Parent           = frame
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 6)
    tc.Parent       = tip

    btn.MouseEnter:Connect(function()
        tip.Visible  = true
        tip.Position = UDim2.new(1, 4, 0, btn.AbsolutePosition.Y - frame.AbsolutePosition.Y)
        tip.Size     = UDim2.new(0, math.max(80, #tooltip * 6), 0, 20)
    end)
    btn.MouseLeave:Connect(function()
        tip.Visible = false
    end)

    btn.MouseButton1Click:Connect(callback)
end

makeButton("🗂", "Explorer", 1, function()
	if _G.KS_Explorer and _G.KS_Explorer.Toggle then
		_G.KS_Explorer.Toggle()
	else
		warn("[KoroneStudio] Explorer module not loaded")
	end

end)

makeButton("✏️", "Editor (current selection)", 2, function()
    if KS_Editor and game.Selection and #game.Selection:Get() > 0 then
        KS_Editor.Open(game.Selection:Get()[1])
    end
end)

makeButton("📡", "Remote Spy", 3, function()
    if KS_RSpy and KS_RSpy.Toggle then
        KS_RSpy.Toggle()
    end
end)

makeButton("🕵️", "Secret Panel", 4, function()
    if KS_Secret and KS_Secret.Toggle then
        KS_Secret.Toggle()
    end
end)

makeButton("🧊", "3D Viewer", 5, function()
    if KS_ModelViewer and KS_ModelViewer.Open then
        KS_ModelViewer.Open(workspace)
    end
end)

