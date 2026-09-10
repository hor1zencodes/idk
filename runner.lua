-- Zen Reanimations Runner (ZenScript Theme)
-- Loads module.lua and provides 5 unified tabs: Reanims, Favs, Binds, Speed, States + Now Playing bar

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════
-- ZEN THEME PALETTE
-- ═══════════════════════════════════════════════════
local C = {
    bg              = Color3.fromRGB(8, 8, 8),       -- Deep black
    bgCard          = Color3.fromRGB(14, 14, 16),    -- Dark glass card
    surface         = Color3.fromRGB(20, 20, 24),    -- Surface panel
    surfaceHover    = Color3.fromRGB(28, 28, 34),    -- Surface hover
    input           = Color3.fromRGB(22, 22, 26),    -- Input background
    accent          = Color3.fromRGB(248, 248, 255), -- Clean bright white/ice accent
    accentDim       = Color3.fromRGB(180, 180, 190), -- Muted accent
    accentGlow      = Color3.fromRGB(248, 248, 255), -- Glow accent
    danger          = Color3.fromRGB(230, 70, 70),   -- Red danger
    dangerDim       = Color3.fromRGB(160, 50, 50),   -- Muted danger
    success         = Color3.fromRGB(80, 220, 140),  -- Emerald success
    warning         = Color3.fromRGB(240, 180, 60),  -- Gold warning
    text            = Color3.fromRGB(225, 225, 235), -- Primary text
    textMuted       = Color3.fromRGB(130, 135, 150), -- Muted text
    textDim         = Color3.fromRGB(80, 85, 100),   -- Dim text
    divider         = Color3.fromRGB(35, 35, 45),    -- Subtle borders
    border          = Color3.fromRGB(42, 42, 54),    -- Card stroke border
    green           = Color3.fromRGB(80, 220, 140),  -- Active green status
}

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

local function applyStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or C.accent
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0.6
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function tween(obj, props, dur, style, dir)
    local info = TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

-- Clean up old GUI if it exists
if CoreGui:FindFirstChild("ZenReanimationsRunner") then
    CoreGui.ZenReanimationsRunner:Destroy()
end

-- ═══════════════════════════════════════════════════
-- 1. LOAD MODULE API
-- ═══════════════════════════════════════════════════
local api
local success, result = pcall(function()
    if isfile and isfile("module.lua") then
        return loadstring(readfile("module.lua"))()
    end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/hor1zencodes/idk/main/module.lua"))()
end)

if success and type(result) == "table" then
    api = result
else
    warn("Zen Reanimations: Failed to load module.lua. Error: " .. tostring(result))
    return
end

-- ═══════════════════════════════════════════════════
-- 2. LOAD ANIMATIONS LIST (Merge Main + Unicorns)
-- ═══════════════════════════════════════════════════
local animations = {}
local anim_success, anim_data = pcall(function()
    if isfile and isfile("animations.json") then
        return readfile("animations.json")
    end
    return game:HttpGet("https://raw.githubusercontent.com/horizen-rblx/reanimsource/main/animations.json")
end)

if anim_success and type(anim_data) == "string" then
    -- Strip UTF-8 BOM if present
    if anim_data:sub(1, 3) == "\239\187\191" then
        anim_data = anim_data:sub(4)
    end
    local decode_success, decoded = pcall(function()
        return HttpService:JSONDecode(anim_data)
    end)
    if decode_success and type(decoded) == "table" then
        for _, item in ipairs(decoded) do
            if item.name and item.path then
                table.insert(animations, {
                    name = item.name,
                    path = item.path,
                    category = item.category or "Reanims"
                })
            end
        end
        -- Sort alphabetically
        table.sort(animations, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
    else
        warn("Zen Reanimations: Failed to parse animations.json")
    end
else
    warn("Zen Reanimations: Failed to download animations.json from GitHub")
end

-- ═══════════════════════════════════════════════════
-- 3. PERSISTENT CONFIGURATION
-- ═══════════════════════════════════════════════════
local CONFIG_FILE = "ZenReanimConfig.json"
local savedConfig = {
    favs = {},
    binds = {},
    states = {},
    speed = 1.0,
    speedBinds = {},
    customAnims = {},
    hiddenLimbs = {},
    trackingBinds = {}
}

if isfile and readfile and isfile(CONFIG_FILE) then
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            if data.favs then savedConfig.favs = data.favs end
            if data.binds then savedConfig.binds = data.binds end
            if data.states then savedConfig.states = data.states end
            if data.speed then savedConfig.speed = tonumber(data.speed) or 1.0 end
            if data.speedBinds then savedConfig.speedBinds = data.speedBinds end
            if data.customAnims then savedConfig.customAnims = data.customAnims end
            if data.hiddenLimbs then savedConfig.hiddenLimbs = data.hiddenLimbs end
            if data.trackingBinds then savedConfig.trackingBinds = data.trackingBinds end
        end
    end)
end
savedConfig.trackingBinds = savedConfig.trackingBinds or {}

_G.hiddenBodyParts = _G.hiddenBodyParts or {}
if savedConfig.hiddenLimbs then
    for limbName, isHidden in pairs(savedConfig.hiddenLimbs) do
        if isHidden then
            _G.hiddenBodyParts[limbName] = true
        end
    end
end

-- Inject saved custom animations into catalog
if savedConfig.customAnims and #savedConfig.customAnims > 0 then
    for _, ca in ipairs(savedConfig.customAnims) do
        table.insert(animations, {
            name = ca.name,
            path = ca.script,
            category = "Custom",
            isCustom = true
        })
    end
    table.sort(animations, function(a, b) return a.name:lower() < b.name:lower() end)
end

local function saveConfig()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(savedConfig))
        end)
    end
end

-- Preload Favorites in background
task.spawn(function()
    task.wait(2)
    if api and api.preload_animation then
        for animName, _ in pairs(savedConfig.favs) do
            for _, a in ipairs(animations) do
                if a.name == animName then
                    api.preload_animation(a.path)
                    task.wait(0.3)
                    break
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 4. GUI CONSTRUCTION
-- ═══════════════════════════════════════════════════
local currentSpeed = savedConfig.speed or 1.0
local currentPlayingAnim = nil
local manualAnimationPlaying = false
local currentTab = "Reanims"

local gui = Instance.new("ScreenGui")
gui.Name = "ZenReanimationsRunner"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local GUI_WIDTH = 380
local GUI_HEIGHT = 525

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)
mainFrame.Position = UDim2.new(0.5, -math.floor(GUI_WIDTH / 2), 0.5, -math.floor(GUI_HEIGHT / 2))
mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui

applyCorner(mainFrame, 14)

-- Eternity vertical dark glass gradient
local mainGradient = Instance.new("UIGradient", mainFrame)
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 24)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 8))
})
mainGradient.Rotation = 90

local mainStroke = applyStroke(mainFrame, C.accent, 1.5, 0)
local mainStrokeGrad = Instance.new("UIGradient", mainStroke)
mainStrokeGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.2, 0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(0.8, 0.6),
    NumberSequenceKeypoint.new(1, 1)
})
mainStrokeGrad.Rotation = 45

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 20
titleBar.Parent = mainFrame
applyCorner(titleBar, 14)

local titleDivider = Instance.new("Frame")
titleDivider.Size = UDim2.new(1, 0, 0, 1)
titleDivider.Position = UDim2.new(0, 0, 1, -1)
titleDivider.BackgroundColor3 = C.divider
titleDivider.BorderSizePixel = 0
titleDivider.ZIndex = 20
titleDivider.Parent = titleBar

local macBtns = Instance.new("Frame")
macBtns.Size = UDim2.new(0, 44, 1, 0)
macBtns.Position = UDim2.new(0, 12, 0, 0)
macBtns.BackgroundTransparency = 1
macBtns.ZIndex = 21
macBtns.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 12, 0, 12)
closeBtn.Position = UDim2.new(0, 0, 0.5, -6)
closeBtn.BackgroundColor3 = C.danger
closeBtn.Text = ""
closeBtn.ZIndex = 22
closeBtn.Parent = macBtns
applyCorner(closeBtn, 6)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 12, 0, 12)
minBtn.Position = UDim2.new(0, 18, 0.5, -6)
minBtn.BackgroundColor3 = C.warning
minBtn.Text = ""
minBtn.ZIndex = 22
minBtn.Parent = macBtns
applyCorner(minBtn, 6)

local titleLogo = Instance.new("ImageLabel")
titleLogo.Name = "TitleLogo"
titleLogo.Size = UDim2.new(0, 76, 0, 20)
titleLogo.Position = UDim2.new(0, 48, 0.5, -10)
titleLogo.BackgroundTransparency = 1
titleLogo.Image = "rbxassetid://139175707588865"
titleLogo.ScaleType = Enum.ScaleType.Fit
titleLogo.ZIndex = 21
titleLogo.Parent = titleBar

-- Enable / Disable Reanimation Capsule Button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 118, 0, 26)
toggleBtn.Position = UDim2.new(1, -128, 0.5, -13)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
toggleBtn.Text = "Enable Reanim"
toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 10
toggleBtn.ZIndex = 21
toggleBtn.Parent = titleBar
applyCorner(toggleBtn, 100)
local toggleStroke = applyStroke(toggleBtn, C.border, 1, 0.2)

-- Body Container (houses tabs, page content, and now playing bar; hidden during minimize)
local bodyContainer = Instance.new("Frame")
bodyContainer.Name = "BodyContainer"
bodyContainer.Size = UDim2.new(1, 0, 1, -48)
bodyContainer.Position = UDim2.new(0, 0, 0, 48)
bodyContainer.BackgroundTransparency = 1
bodyContainer.ClipsDescendants = true
bodyContainer.Parent = mainFrame

local modalOverlay = nil
local addCustomModal = nil
local isMinimized = false

local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        bodyContainer.Visible = false
        titleDivider.Visible = false
        if modalOverlay then
            modalOverlay.Visible = false
        end
        if addCustomModal then
            addCustomModal.Visible = false
        end
        tween(mainFrame, {Size = UDim2.new(0, GUI_WIDTH, 0, 44)}, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    else
        titleDivider.Visible = true
        tween(mainFrame, {Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)}, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        task.delay(0.12, function()
            if not isMinimized then
                bodyContainer.Visible = true
            end
        end)
    end
end

minBtn.MouseEnter:Connect(function() tween(minBtn, {BackgroundColor3 = Color3.fromRGB(255, 220, 100)}, 0.15) end)
minBtn.MouseLeave:Connect(function() tween(minBtn, {BackgroundColor3 = Color3.fromRGB(255, 190, 60)}, 0.15) end)
minBtn.MouseButton1Click:Connect(toggleMinimize)

closeBtn.MouseEnter:Connect(function() tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 130, 130)}, 0.15) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 90, 90)}, 0.15) end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Window Dragging
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 5. SUB-TAB CAPSULE BAR (from forjnkie.lua createSubTabBar)
-- ═══════════════════════════════════════════════════
local tabNames = { "Reanims", "Favs", "Custom", "Binds", "States", "Speed", "Copier", "Tracking", "Stretching", "Limbs", "Studio" }
local tabButtons = {}
local switchTab -- forward declaration for early click binding

local subTabBar = Instance.new("Frame")
subTabBar.Name = "SubTabBar"
subTabBar.Size = UDim2.new(1, -20, 0, 34)
subTabBar.Position = UDim2.new(0, 10, 0, 8)
subTabBar.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
subTabBar.BackgroundTransparency = 0.2
subTabBar.BorderSizePixel = 0
subTabBar.ClipsDescendants = true
subTabBar.Parent = bodyContainer
applyCorner(subTabBar, 100) -- Capsule shape

local subTabStroke = applyStroke(subTabBar, C.accent, 1.2, 0)
local subStrokeGrad = Instance.new("UIGradient", subTabStroke)
subStrokeGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.4, 1),
    NumberSequenceKeypoint.new(0.5, 0.2),
    NumberSequenceKeypoint.new(0.6, 1),
    NumberSequenceKeypoint.new(1, 1)
})
subStrokeGrad.Rotation = 0

task.spawn(function()
    local t = TweenService:Create(subStrokeGrad, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
    t:Play()
end)

local subBarGrad = Instance.new("UIGradient", subTabBar)
subBarGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 36, 44)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 22))
})
subBarGrad.Rotation = 45

local tabsScroll = Instance.new("ScrollingFrame")
tabsScroll.Size = UDim2.new(1, -8, 1, -6)
tabsScroll.Position = UDim2.new(0, 4, 0, 3)
tabsScroll.BackgroundTransparency = 1
tabsScroll.BorderSizePixel = 0
tabsScroll.ScrollBarThickness = 0
tabsScroll.ScrollingDirection = Enum.ScrollingDirection.X
pcall(function()
    tabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
end)
tabsScroll.CanvasSize = UDim2.new(0, #tabNames * 62 + 10, 0, 0)
tabsScroll.Parent = subTabBar

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabsLayout.Padding = UDim.new(0, 4)
tabsLayout.Parent = tabsScroll

for i, tName in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(0, 58, 1, 0)
    tb.BackgroundColor3 = (i == 1) and C.accent or Color3.fromRGB(30, 30, 35)
    tb.BackgroundTransparency = (i == 1) and 0 or 0.5
    tb.Text = tName
    tb.TextColor3 = (i == 1) and Color3.fromRGB(8, 8, 10) or C.textMuted
    tb.Font = (i == 1) and Enum.Font.GothamBold or Enum.Font.GothamMedium
    tb.TextSize = 10
    tb.AutoButtonColor = false
    tb.Parent = tabsScroll
    applyCorner(tb, 100) -- Capsule shape
    tabButtons[tName] = { btn = tb }

    local function onTabClick()
        if switchTab then
            switchTab(tName)
        end
    end
    tb.MouseButton1Click:Connect(onTabClick)
    pcall(function()
        tb.Activated:Connect(onTabClick)
    end)
end

-- ═══════════════════════════════════════════════════
-- 6. NOW PLAYING CAPSULE DOCK & STOP BUTTON
-- ═══════════════════════════════════════════════════
local npBar = Instance.new("Frame")
npBar.Size = UDim2.new(1, -20, 0, 32)
npBar.Position = UDim2.new(0, 10, 1, -40)
npBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
npBar.BorderSizePixel = 0
npBar.ZIndex = 15
npBar.Parent = bodyContainer
applyCorner(npBar, 100) -- Capsule dock
local npStroke = applyStroke(npBar, C.border, 1, 0.4)

local npDot = Instance.new("Frame")
npDot.Size = UDim2.new(0, 7, 0, 7)
npDot.Position = UDim2.new(0, 12, 0.5, -3.5)
npDot.BackgroundColor3 = C.textMuted
npDot.BorderSizePixel = 0
npDot.ZIndex = 16
npDot.Parent = npBar
applyCorner(npDot, 4)

local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1, -68, 1, 0)
nowPlayingLabel.Position = UDim2.new(0, 28, 0, 0)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "No animation playing"
nowPlayingLabel.TextColor3 = C.textMuted
nowPlayingLabel.Font = Enum.Font.GothamMedium
nowPlayingLabel.TextSize = 10.5
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.TextTruncate = Enum.TextTruncate.AtEnd
nowPlayingLabel.ZIndex = 16
nowPlayingLabel.Parent = npBar

-- Stop Button (glass circle with square stop icon)
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0, 22, 0, 22)
stopBtn.Position = UDim2.new(1, -28, 0.5, -11)
stopBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
stopBtn.Text = ""
stopBtn.ZIndex = 16
stopBtn.Parent = npBar
applyCorner(stopBtn, 11)
local stopStroke = applyStroke(stopBtn, C.divider, 1, 0.3)

local stopIcon = Instance.new("Frame")
stopIcon.Size = UDim2.new(0, 8, 0, 8)
stopIcon.Position = UDim2.new(0.5, -4, 0.5, -4)
stopIcon.BackgroundColor3 = C.textMuted
stopIcon.BorderSizePixel = 0
stopIcon.ZIndex = 17
stopIcon.Parent = stopBtn
applyCorner(stopIcon, 2)

local function updateNowPlayingUI(animName)
    currentPlayingAnim = animName
    if animName and animName ~= "" then
        local displayName = animName:gsub("%.lua$", "")
        nowPlayingLabel.Text = "▶  " .. displayName
        nowPlayingLabel.TextColor3 = C.text
        npDot.BackgroundColor3 = C.green
        stopIcon.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
        tween(stopBtn, {BackgroundColor3 = Color3.fromRGB(35, 20, 20)}, 0.2)
        tween(stopStroke, {Color = Color3.fromRGB(160, 50, 50), Transparency = 0.2}, 0.2)
    else
        nowPlayingLabel.Text = "No animation playing"
        nowPlayingLabel.TextColor3 = C.textMuted
        npDot.BackgroundColor3 = C.textMuted
        stopIcon.BackgroundColor3 = C.textMuted
        tween(stopBtn, {BackgroundColor3 = Color3.fromRGB(24, 24, 24)}, 0.2)
        tween(stopStroke, {Color = C.divider, Transparency = 0.5}, 0.2)
    end
end

stopBtn.MouseButton1Click:Connect(function()
    manualAnimationPlaying = false
    if api and api.stop_animation then
        api.stop_animation()
    end
    updateNowPlayingUI(nil)
end)

api.on_animation_play(function(url)
    local name = nil
    for _, a in ipairs(animations) do
        if a.path == url then name = a.name break end
    end
    updateNowPlayingUI(name or "Playing Animation")
end)

api.on_animation_stop(function()
    updateNowPlayingUI(nil)
end)

-- ═══════════════════════════════════════════════════
-- 7. TAB PANELS CONTAINER
-- ═══════════════════════════════════════════════════
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -20, 1, -94)
contentArea.Position = UDim2.new(0, 10, 0, 48)
contentArea.BackgroundTransparency = 1
contentArea.Parent = bodyContainer

-- PANEL 1: REANIMS & FAVS (Shares animation virtual list)
local listPanel = Instance.new("Frame")
listPanel.Size = UDim2.new(1, 0, 1, 0)
listPanel.BackgroundTransparency = 1
listPanel.Visible = true
listPanel.Parent = contentArea

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -96, 0, 30)
searchBox.Position = UDim2.new(0, 0, 0, 0)
searchBox.BackgroundColor3 = C.input
searchBox.PlaceholderText = "Search animations..."
searchBox.PlaceholderColor3 = C.textMuted
searchBox.Text = ""
searchBox.TextColor3 = C.text
searchBox.Font = Enum.Font.GothamMedium
searchBox.TextSize = 10.5
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = listPanel
applyCorner(searchBox, 100)
applyStroke(searchBox, C.divider, 1, 0.2)

local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 12)
searchPadding.PaddingRight = UDim.new(0, 10)
searchPadding.Parent = searchBox

local addCustomBtn = Instance.new("TextButton")
addCustomBtn.Size = UDim2.new(0, 90, 0, 30)
addCustomBtn.Position = UDim2.new(1, -90, 0, 0)
addCustomBtn.BackgroundColor3 = C.surface
addCustomBtn.Text = "+ Add Custom"
addCustomBtn.TextColor3 = C.accent
addCustomBtn.Font = Enum.Font.GothamBold
addCustomBtn.TextSize = 9.5
addCustomBtn.Parent = listPanel
applyCorner(addCustomBtn, 100)
applyStroke(addCustomBtn, C.border, 1, 0.3)

local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, 0, 1, -38)
scrollList.Position = UDim2.new(0, 0, 0, 38)
scrollList.BackgroundTransparency = 1
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 3
scrollList.ScrollBarImageColor3 = C.accent
scrollList.ScrollBarImageTransparency = 0.6
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.Parent = listPanel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollList

local emptyFavsLabel = Instance.new("TextLabel")
emptyFavsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyFavsLabel.Position = UDim2.new(0, 0, 0.3, 0)
emptyFavsLabel.BackgroundTransparency = 1
emptyFavsLabel.Text = "No favorite animations yet.\nClick the star icon (★) on any animation in the Reanims tab!"
emptyFavsLabel.TextColor3 = C.textMuted
emptyFavsLabel.Font = Enum.Font.GothamMedium
emptyFavsLabel.TextSize = 11
emptyFavsLabel.Visible = false
emptyFavsLabel.Parent = listPanel

local emptyCustomLabel = Instance.new("TextLabel")
emptyCustomLabel.Size = UDim2.new(1, 0, 0, 60)
emptyCustomLabel.Position = UDim2.new(0, 0, 0.3, 0)
emptyCustomLabel.BackgroundTransparency = 1
emptyCustomLabel.Text = "No custom animations added yet.\nClick [+ Add Custom] above to paste and import animations!"
emptyCustomLabel.TextColor3 = C.textMuted
emptyCustomLabel.Font = Enum.Font.GothamMedium
emptyCustomLabel.TextSize = 11
emptyCustomLabel.Visible = false
emptyCustomLabel.Parent = listPanel

-- PANEL 2: BINDS PANEL
local bindsPanel = Instance.new("ScrollingFrame")
bindsPanel.Size = UDim2.new(1, 0, 1, 0)
bindsPanel.BackgroundTransparency = 1
bindsPanel.BorderSizePixel = 0
bindsPanel.ScrollBarThickness = 3
bindsPanel.ScrollBarImageColor3 = C.accent
bindsPanel.ScrollBarImageTransparency = 0.6
bindsPanel.Visible = false
bindsPanel.Parent = contentArea

local bindsLayout = Instance.new("UIListLayout")
bindsLayout.Padding = UDim.new(0, 6)
bindsLayout.SortOrder = Enum.SortOrder.LayoutOrder
bindsLayout.Parent = bindsPanel

local bindsHeader = Instance.new("TextLabel")
bindsHeader.Size = UDim2.new(1, 0, 0, 20)
bindsHeader.BackgroundTransparency = 1
bindsHeader.Text = "Click key button to rebind  |  Click [X] to unbind"
bindsHeader.TextColor3 = C.textMuted
bindsHeader.Font = Enum.Font.GothamMedium
bindsHeader.TextSize = 10
bindsHeader.TextXAlignment = Enum.TextXAlignment.Left
bindsHeader.Parent = bindsPanel

local emptyBindsLabel = Instance.new("TextLabel")
emptyBindsLabel.Size = UDim2.new(1, 0, 0, 60)
emptyBindsLabel.BackgroundTransparency = 1
emptyBindsLabel.Text = "No keybinds assigned yet.\nIn the Reanims tab, click [+] next to any animation to bind a key!"
emptyBindsLabel.TextColor3 = C.textMuted
emptyBindsLabel.Font = Enum.Font.GothamMedium
emptyBindsLabel.TextSize = 11
emptyBindsLabel.Visible = false
emptyBindsLabel.Parent = bindsPanel

-- PANEL 3: SPEED PANEL
local speedPanel = Instance.new("ScrollingFrame")
speedPanel.Size = UDim2.new(1, 0, 1, 0)
speedPanel.BackgroundTransparency = 1
speedPanel.BorderSizePixel = 0
speedPanel.ScrollBarThickness = 3
speedPanel.ScrollBarImageColor3 = C.accent
speedPanel.ScrollBarImageTransparency = 0.6
speedPanel.Visible = false
speedPanel.Parent = contentArea

local speedListLayout = Instance.new("UIListLayout")
speedListLayout.Padding = UDim.new(0, 10)
speedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
speedListLayout.Parent = speedPanel

-- Speed Card 1: Continuous Slider
local sliderCard = Instance.new("Frame")
sliderCard.Size = UDim2.new(1, 0, 0, 78)
sliderCard.BackgroundColor3 = C.bgCard
sliderCard.Parent = speedPanel
applyCorner(sliderCard, 8)
applyStroke(sliderCard, C.divider, 1, 0)

local scTitle = Instance.new("TextLabel")
scTitle.Size = UDim2.new(1, -20, 0, 22)
scTitle.Position = UDim2.new(0, 10, 0, 8)
scTitle.BackgroundTransparency = 1
scTitle.Text = "PLAYBACK SPEED"
scTitle.TextColor3 = C.textMuted
scTitle.Font = Enum.Font.GothamBold
scTitle.TextSize = 10
scTitle.TextXAlignment = Enum.TextXAlignment.Left
scTitle.Parent = sliderCard

local sliderTrack = Instance.new("Frame")
sliderTrack.Size = UDim2.new(1, -130, 0, 6)
sliderTrack.Position = UDim2.new(0, 10, 0, 46)
sliderTrack.BackgroundColor3 = C.surface
sliderTrack.BorderSizePixel = 0
sliderTrack.Parent = sliderCard
applyCorner(sliderTrack, 3)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.3, 0, 1, 0)
sliderFill.BackgroundColor3 = C.accent
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
applyCorner(sliderFill, 3)

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, 14, 0, 14)
sliderKnob.Position = UDim2.new(1, -7, 0.5, -7)
sliderKnob.BackgroundColor3 = C.text
sliderKnob.BorderSizePixel = 0
sliderKnob.Parent = sliderFill
applyCorner(sliderKnob, 7)

local sliderValLabel = Instance.new("TextLabel")
sliderValLabel.Size = UDim2.new(0, 48, 0, 22)
sliderValLabel.Position = UDim2.new(1, -114, 0, 38)
sliderValLabel.BackgroundColor3 = C.input
sliderValLabel.Text = string.format("%.1fx", currentSpeed)
sliderValLabel.TextColor3 = C.accent
sliderValLabel.Font = Enum.Font.GothamBold
sliderValLabel.TextSize = 10
sliderValLabel.Parent = sliderCard
applyCorner(sliderValLabel, 4)
applyStroke(sliderValLabel, C.divider, 1, 0)

local resetSpeedBtn = Instance.new("TextButton")
resetSpeedBtn.Size = UDim2.new(0, 54, 0, 22)
resetSpeedBtn.Position = UDim2.new(1, -60, 0, 38)
resetSpeedBtn.BackgroundColor3 = C.surface
resetSpeedBtn.Text = "Reset 1.0x"
resetSpeedBtn.TextColor3 = C.text
resetSpeedBtn.Font = Enum.Font.GothamSemibold
resetSpeedBtn.TextSize = 9
resetSpeedBtn.Parent = sliderCard
applyCorner(resetSpeedBtn, 4)
applyStroke(resetSpeedBtn, C.divider, 1, 0)

local function applySpeed(val)
    currentSpeed = math.clamp(math.floor(val * 10) / 10, 0.1, 5.0)
    savedConfig.speed = currentSpeed
    saveConfig()
    sliderValLabel.Text = string.format("%.1fx", currentSpeed)
    local pct = (currentSpeed - 0.1) / (3.0 - 0.1)
    sliderFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
    if api and api.set_animation_speed then
        api.set_animation_speed(currentSpeed)
    end
end

resetSpeedBtn.MouseButton1Click:Connect(function()
    applySpeed(1.0)
end)

local draggingSlider = false
local function updateSliderFromInput(input)
    local relX = math.clamp(input.Position.X - sliderTrack.AbsolutePosition.X, 0, sliderTrack.AbsoluteSize.X)
    local pct = relX / sliderTrack.AbsoluteSize.X
    local spd = 0.1 + (2.9 * pct)
    applySpeed(spd)
end

sliderCard.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        updateSliderFromInput(input)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSliderFromInput(input)
    end
end)

-- Speed Card 2: Presets & Keybinds
local presetCard = Instance.new("Frame")
presetCard.Size = UDim2.new(1, 0, 0, 110)
presetCard.BackgroundColor3 = C.bgCard
presetCard.Parent = speedPanel
applyCorner(presetCard, 8)
applyStroke(presetCard, C.divider, 1, 0)

local pcTitle = Instance.new("TextLabel")
pcTitle.Size = UDim2.new(1, -20, 0, 20)
pcTitle.Position = UDim2.new(0, 10, 0, 8)
pcTitle.BackgroundTransparency = 1
pcTitle.Text = "SPEED PRESETS & HOTKEYS"
pcTitle.TextColor3 = C.textMuted
pcTitle.Font = Enum.Font.GothamBold
pcTitle.TextSize = 10
pcTitle.TextXAlignment = Enum.TextXAlignment.Left
pcTitle.Parent = presetCard

local pcSubtitle = Instance.new("TextLabel")
pcSubtitle.Size = UDim2.new(1, -20, 0, 14)
pcSubtitle.Position = UDim2.new(0, 10, 0, 26)
pcSubtitle.BackgroundTransparency = 1
pcSubtitle.Text = "Click speed button to apply  |  Click [+] to bind key"
pcSubtitle.TextColor3 = C.textMuted
pcSubtitle.Font = Enum.Font.Gotham
pcSubtitle.TextSize = 9
pcSubtitle.TextXAlignment = Enum.TextXAlignment.Left
pcSubtitle.Parent = presetCard

local speedPresets = { 0.5, 1.0, 1.5, 2.0, 3.0 }
local presetRow = Instance.new("Frame")
presetRow.Size = UDim2.new(1, -20, 0, 52)
presetRow.Position = UDim2.new(0, 10, 0, 48)
presetRow.BackgroundTransparency = 1
presetRow.Parent = presetCard

local currentlyBindingSpeed = nil
local speedBindButtons = {}

local pW = 1 / #speedPresets
for i, spd in ipairs(speedPresets) do
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(pW, -4, 0, 24)
    sBtn.Position = UDim2.new((i - 1) * pW, 2, 0, 0)
    sBtn.BackgroundColor3 = C.surface
    sBtn.Text = string.format("%.1fx", spd)
    sBtn.TextColor3 = C.text
    sBtn.Font = Enum.Font.GothamBold
    sBtn.TextSize = 11
    sBtn.Parent = presetRow
    applyCorner(sBtn, 4)
    applyStroke(sBtn, C.divider, 1, 0)

    sBtn.MouseButton1Click:Connect(function()
        applySpeed(spd)
    end)

    local kBtn = Instance.new("TextButton")
    kBtn.Size = UDim2.new(pW, -4, 0, 20)
    kBtn.Position = UDim2.new((i - 1) * pW, 2, 0, 28)
    kBtn.BackgroundColor3 = C.input
    local bound = savedConfig.speedBinds[tostring(spd)]
    kBtn.Text = bound and ("[" .. bound .. "]") or "[+]"
    kBtn.TextColor3 = bound and C.accent or C.textMuted
    kBtn.Font = Enum.Font.GothamSemibold
    kBtn.TextSize = 9
    kBtn.Parent = presetRow
    applyCorner(kBtn, 4)
    applyStroke(kBtn, C.divider, 1, 0)

    speedBindButtons[tostring(spd)] = kBtn

    kBtn.MouseButton1Click:Connect(function()
        if currentlyBindingSpeed == tostring(spd) then
            currentlyBindingSpeed = nil
            local b = savedConfig.speedBinds[tostring(spd)]
            kBtn.Text = b and ("[" .. b .. "]") or "[+]"
            return
        end
        currentlyBindingSpeed = tostring(spd)
        kBtn.Text = "[?]"
        kBtn.TextColor3 = Color3.fromRGB(255, 180, 50)
    end)
end

-- PANEL 4: STATES PANEL
local statesPanel = Instance.new("ScrollingFrame")
statesPanel.Size = UDim2.new(1, 0, 1, 0)
statesPanel.BackgroundTransparency = 1
statesPanel.BorderSizePixel = 0
statesPanel.ScrollBarThickness = 3
statesPanel.ScrollBarImageColor3 = C.accent
statesPanel.ScrollBarImageTransparency = 0.6
statesPanel.Visible = false
statesPanel.Parent = contentArea

local statesListLayout = Instance.new("UIListLayout")
statesListLayout.Padding = UDim.new(0, 8)
statesListLayout.SortOrder = Enum.SortOrder.LayoutOrder
statesListLayout.Parent = statesPanel

local statesHeader = Instance.new("TextLabel")
statesHeader.Size = UDim2.new(1, 0, 0, 18)
statesHeader.BackgroundTransparency = 1
statesHeader.Text = "CHARACTER STATE ANIMATIONS"
statesHeader.TextColor3 = C.textMuted
statesHeader.Font = Enum.Font.GothamBold
statesHeader.TextSize = 10
statesHeader.TextXAlignment = Enum.TextXAlignment.Left
statesHeader.Parent = statesPanel

local statesSubtitle = Instance.new("TextLabel")
statesSubtitle.Size = UDim2.new(1, 0, 0, 14)
statesSubtitle.BackgroundTransparency = 1
statesSubtitle.Text = "Automatically triggers animations on character movement"
statesSubtitle.TextColor3 = C.textMuted
statesSubtitle.Font = Enum.Font.Gotham
statesSubtitle.TextSize = 9
statesSubtitle.TextXAlignment = Enum.TextXAlignment.Left
statesSubtitle.Parent = statesPanel

local stateTypes = { "Idle", "Walk", "Run", "Jump", "Fall" }
local stateSelectButtons = {}
local modalSelectingState = nil

-- ═══════════════════════════════════════════════════
-- 8. ANIMATION SELECTOR MODAL (For States Tab)
-- ═══════════════════════════════════════════════════
modalOverlay = Instance.new("Frame")
modalOverlay.Size = UDim2.new(1, 0, 1, 0)
modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalOverlay.BackgroundTransparency = 0.4
modalOverlay.BorderSizePixel = 0
modalOverlay.ZIndex = 50
modalOverlay.Visible = false
modalOverlay.Parent = mainFrame

local modalCard = Instance.new("Frame")
modalCard.Size = UDim2.new(0, 330, 0, 400)
modalCard.Position = UDim2.new(0.5, -165, 0.5, -200)
modalCard.BackgroundColor3 = C.bgCard
modalCard.BorderSizePixel = 0
modalCard.ZIndex = 51
modalCard.Parent = modalOverlay
applyCorner(modalCard, 10)
applyStroke(modalCard, C.border, 1.5, 0)

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, -50, 0, 36)
modalTitle.Position = UDim2.new(0, 14, 0, 6)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "Select Animation for State"
modalTitle.TextColor3 = C.text
modalTitle.Font = Enum.Font.GothamBold
modalTitle.TextSize = 12
modalTitle.TextXAlignment = Enum.TextXAlignment.Left
modalTitle.ZIndex = 52
modalTitle.Parent = modalCard

local modalCloseBtn = Instance.new("TextButton")
modalCloseBtn.Size = UDim2.new(0, 24, 0, 24)
modalCloseBtn.Position = UDim2.new(1, -34, 0, 10)
modalCloseBtn.BackgroundColor3 = C.surface
modalCloseBtn.Text = "✕"
modalCloseBtn.TextColor3 = C.textMuted
modalCloseBtn.Font = Enum.Font.GothamBold
modalCloseBtn.TextSize = 11
modalCloseBtn.ZIndex = 52
modalCloseBtn.Parent = modalCard
applyCorner(modalCloseBtn, 12)

modalCloseBtn.MouseButton1Click:Connect(function()
    modalOverlay.Visible = false
    modalSelectingState = nil
end)

local modalSearch = Instance.new("TextBox")
modalSearch.Size = UDim2.new(1, -28, 0, 30)
modalSearch.Position = UDim2.new(0, 14, 0, 44)
modalSearch.BackgroundColor3 = C.input
modalSearch.PlaceholderText = "Search animations to assign..."
modalSearch.PlaceholderColor3 = C.textMuted
modalSearch.Text = ""
modalSearch.TextColor3 = C.text
modalSearch.Font = Enum.Font.GothamMedium
modalSearch.TextSize = 11
modalSearch.TextXAlignment = Enum.TextXAlignment.Left
modalSearch.ZIndex = 52
modalSearch.ClearTextOnFocus = false
modalSearch.Parent = modalCard
applyCorner(modalSearch, 6)
applyStroke(modalSearch, C.divider, 1, 0)

local msp = Instance.new("UIPadding")
msp.PaddingLeft = UDim.new(0, 10)
msp.PaddingRight = UDim.new(0, 10)
msp.Parent = modalSearch

local modalList = Instance.new("ScrollingFrame")
modalList.Size = UDim2.new(1, -28, 1, -90)
modalList.Position = UDim2.new(0, 14, 0, 80)
modalList.BackgroundTransparency = 1
modalList.BorderSizePixel = 0
modalList.ScrollBarThickness = 3
modalList.ScrollBarImageColor3 = C.accent
modalList.ScrollBarImageTransparency = 0.6
modalList.ZIndex = 52
modalList.CanvasSize = UDim2.new(0, 0, 0, 0)
modalList.Parent = modalCard

local modalListLayout = Instance.new("UIListLayout")
modalListLayout.Padding = UDim.new(0, 4)
modalListLayout.SortOrder = Enum.SortOrder.LayoutOrder
modalListLayout.Parent = modalList

local function populateModalList(filter)
    for _, c in ipairs(modalList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local term = (filter or ""):lower()
    local count = 0

    for _, a in ipairs(animations) do
        if term == "" or a.name:lower():find(term, 1, true) then
            count = count + 1
            local ab = Instance.new("TextButton")
            ab.Size = UDim2.new(1, -6, 0, 28)
            ab.BackgroundColor3 = C.surface
            ab.Text = a.name
            ab.TextColor3 = C.text
            ab.Font = Enum.Font.GothamMedium
            ab.TextSize = 11
            ab.TextXAlignment = Enum.TextXAlignment.Left
            ab.TextTruncate = Enum.TextTruncate.AtEnd
            ab.ZIndex = 53
            ab.Parent = modalList
            applyCorner(ab, 4)
            applyStroke(ab, C.divider, 1, 0)

            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 10)
            pad.Parent = ab

            ab.MouseButton1Click:Connect(function()
                if modalSelectingState then
                    savedConfig.states[modalSelectingState] = { name = a.name, path = a.path }
                    saveConfig()
                    if stateSelectButtons[modalSelectingState] then
                        stateSelectButtons[modalSelectingState].Text = a.name
                        stateSelectButtons[modalSelectingState].TextColor3 = Color3.fromRGB(100, 220, 120)
                    end
                end
                modalOverlay.Visible = false
                modalSelectingState = nil
            end)
        end
    end
    modalList.CanvasSize = UDim2.new(0, 0, 0, count * 32)
end

modalSearch:GetPropertyChangedSignal("Text"):Connect(function()
    populateModalList(modalSearch.Text)
end)

-- ═══════════════════════════════════════════════════
-- 8B. ADD CUSTOM ANIMATION MODAL
-- ═══════════════════════════════════════════════════
addCustomModal = Instance.new("Frame")
addCustomModal.Size = UDim2.new(1, 0, 1, 0)
addCustomModal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
addCustomModal.BackgroundTransparency = 0.4
addCustomModal.BorderSizePixel = 0
addCustomModal.ZIndex = 50
addCustomModal.Visible = false
addCustomModal.Parent = mainFrame

local addCard = Instance.new("Frame")
addCard.Size = UDim2.new(0, 330, 0, 380)
addCard.Position = UDim2.new(0.5, -165, 0.5, -190)
addCard.BackgroundColor3 = C.bgCard
addCard.BorderSizePixel = 0
addCard.ZIndex = 51
addCard.Parent = addCustomModal
applyCorner(addCard, 10)
applyStroke(addCard, C.border, 1.5, 0)

local addTitle = Instance.new("TextLabel")
addTitle.Size = UDim2.new(1, -50, 0, 36)
addTitle.Position = UDim2.new(0, 14, 0, 6)
addTitle.BackgroundTransparency = 1
addTitle.Text = "Add Custom Animation"
addTitle.TextColor3 = C.text
addTitle.Font = Enum.Font.GothamBold
addTitle.TextSize = 12
addTitle.TextXAlignment = Enum.TextXAlignment.Left
addTitle.ZIndex = 52
addTitle.Parent = addCard

local addCloseBtn = Instance.new("TextButton")
addCloseBtn.Size = UDim2.new(0, 24, 0, 24)
addCloseBtn.Position = UDim2.new(1, -34, 0, 10)
addCloseBtn.BackgroundColor3 = C.surface
addCloseBtn.Text = "✕"
addCloseBtn.TextColor3 = C.textMuted
addCloseBtn.Font = Enum.Font.GothamBold
addCloseBtn.TextSize = 11
addCloseBtn.ZIndex = 52
addCloseBtn.Parent = addCard
applyCorner(addCloseBtn, 12)

local addNameBox = Instance.new("TextBox")
addNameBox.Size = UDim2.new(1, -28, 0, 28)
addNameBox.Position = UDim2.new(0, 14, 0, 44)
addNameBox.BackgroundColor3 = C.input
addNameBox.PlaceholderText = "Animation Name (optional)"
addNameBox.PlaceholderColor3 = C.textMuted
addNameBox.Text = ""
addNameBox.TextColor3 = C.text
addNameBox.Font = Enum.Font.GothamMedium
addNameBox.TextSize = 11
addNameBox.TextXAlignment = Enum.TextXAlignment.Left
addNameBox.ClearTextOnFocus = false
addNameBox.ZIndex = 52
addNameBox.Parent = addCard
applyCorner(addNameBox, 6)
applyStroke(addNameBox, C.divider, 1, 0)
local addNamePad = Instance.new("UIPadding")
addNamePad.PaddingLeft = UDim.new(0, 10)
addNamePad.Parent = addNameBox

local addDataBox = Instance.new("TextBox")
addDataBox.Size = UDim2.new(1, -28, 0, 210)
addDataBox.Position = UDim2.new(0, 14, 0, 80)
addDataBox.BackgroundColor3 = C.input
addDataBox.PlaceholderText = "Paste keyframe script or table here...\n(Or press Ctrl+V to paste from clipboard)"
addDataBox.PlaceholderColor3 = C.textMuted
addDataBox.Text = ""
addDataBox.TextColor3 = C.green
addDataBox.Font = Enum.Font.Code
addDataBox.TextSize = 10
addDataBox.MultiLine = true
addDataBox.ClearTextOnFocus = false
addDataBox.TextWrapped = true
addDataBox.TextXAlignment = Enum.TextXAlignment.Left
addDataBox.TextYAlignment = Enum.TextYAlignment.Top
addDataBox.ClipsDescendants = true
addDataBox.ZIndex = 52
addDataBox.Parent = addCard
applyCorner(addDataBox, 6)
applyStroke(addDataBox, C.divider, 1, 0)
local addDataPad = Instance.new("UIPadding")
addDataPad.PaddingLeft = UDim.new(0, 8)
addDataPad.PaddingTop = UDim.new(0, 8)
addDataPad.PaddingRight = UDim.new(0, 8)
addDataPad.Parent = addDataBox

local addStatus = Instance.new("TextLabel")
addStatus.Size = UDim2.new(1, -28, 0, 20)
addStatus.Position = UDim2.new(0, 14, 0, 298)
addStatus.BackgroundTransparency = 1
addStatus.Text = "Paste keyframe data or script table above."
addStatus.TextColor3 = C.textMuted
addStatus.Font = Enum.Font.Gotham
addStatus.TextSize = 10
addStatus.TextXAlignment = Enum.TextXAlignment.Left
addStatus.ZIndex = 52
addStatus.Parent = addCard

local addSubmitBtn = Instance.new("TextButton")
addSubmitBtn.Size = UDim2.new(1, -28, 0, 32)
addSubmitBtn.Position = UDim2.new(0, 14, 1, -44)
addSubmitBtn.BackgroundColor3 = Color3.fromRGB(24, 40, 30)
addSubmitBtn.Text = "+ Add Animation"
addSubmitBtn.TextColor3 = C.green
addSubmitBtn.Font = Enum.Font.GothamBold
addSubmitBtn.TextSize = 11
addSubmitBtn.ZIndex = 52
addSubmitBtn.Parent = addCard
applyCorner(addSubmitBtn, 6)
applyStroke(addSubmitBtn, Color3.fromRGB(40, 100, 60), 1, 0.4)

local function closeAddModal()
    addCustomModal.Visible = false
    addNameBox.Text = ""
    addDataBox.Text = ""
    addStatus.Text = "Paste keyframe data or script table above."
    addStatus.TextColor3 = C.textMuted
end

addCloseBtn.MouseButton1Click:Connect(closeAddModal)
addCustomBtn.MouseButton1Click:Connect(function()
    addCustomModal.Visible = true
    addNameBox:CaptureFocus()
end)

local isDataBoxFocused = false
addDataBox.Focused:Connect(function() isDataBoxFocused = true end)
addDataBox.FocusLost:Connect(function() isDataBoxFocused = false end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if not isDataBoxFocused then return end
    if input.KeyCode == Enum.KeyCode.V and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        task.spawn(function()
            local ok, clip = pcall(getclipboard)
            if ok and type(clip) == "string" and #clip > 0 then
                addDataBox.Text = clip
                addStatus.Text = "Loaded " .. tostring(#clip) .. " characters from clipboard."
                addStatus.TextColor3 = C.green
            end
        end)
    end
end)

addSubmitBtn.MouseButton1Click:Connect(function()
    local raw = addDataBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then
        addStatus.Text = "Please paste keyframe script or table first!"
        addStatus.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end

    if not raw:find("{", 1, true) then
        addStatus.Text = "Invalid data: doesn't look like keyframes table or script."
        addStatus.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end

    local capturedName = addNameBox.Text:match("^%s*(.-)%s*$")
    local finalName = (capturedName and capturedName ~= "") and capturedName or ("Custom_" .. (#savedConfig.customAnims + 1))

    table.insert(savedConfig.customAnims, { name = finalName, script = raw })
    saveConfig()

    table.insert(animations, {
        name = finalName,
        path = raw,
        category = "Custom",
        isCustom = true
    })

    table.sort(animations, function(a, b) return a.name:lower() < b.name:lower() end)
    closeAddModal()
    populateList()
end)

-- Build States Tab Rows
for _, st in ipairs(stateTypes) do
    local sRow = Instance.new("Frame")
    sRow.Size = UDim2.new(1, 0, 0, 42)
    sRow.BackgroundColor3 = C.bgCard
    sRow.Parent = statesPanel
    applyCorner(sRow, 6)
    applyStroke(sRow, C.divider, 1, 0)

    local stLabel = Instance.new("TextLabel")
    stLabel.Size = UDim2.new(0, 70, 1, 0)
    stLabel.Position = UDim2.new(0, 12, 0, 0)
    stLabel.BackgroundTransparency = 1
    stLabel.Text = st
    stLabel.TextColor3 = C.text
    stLabel.Font = Enum.Font.GothamBold
    stLabel.TextSize = 11
    stLabel.TextXAlignment = Enum.TextXAlignment.Left
    stLabel.Parent = sRow

    local currentAssignment = savedConfig.states[st]
    local sBtn = Instance.new("TextButton")
    sBtn.Size = UDim2.new(1, -150, 0, 26)
    sBtn.Position = UDim2.new(0, 84, 0.5, -13)
    sBtn.BackgroundColor3 = C.surface
    sBtn.Text = currentAssignment and currentAssignment.name or "None"
    sBtn.TextColor3 = currentAssignment and Color3.fromRGB(100, 220, 120) or C.textMuted
    sBtn.Font = Enum.Font.GothamMedium
    sBtn.TextSize = 11
    sBtn.TextXAlignment = Enum.TextXAlignment.Left
    sBtn.TextTruncate = Enum.TextTruncate.AtEnd
    sBtn.Parent = sRow
    applyCorner(sBtn, 4)
    applyStroke(sBtn, C.divider, 1, 0)

    local bp = Instance.new("UIPadding")
    bp.PaddingLeft = UDim.new(0, 8)
    bp.PaddingRight = UDim.new(0, 8)
    bp.Parent = sBtn

    stateSelectButtons[st] = sBtn

    sBtn.MouseButton1Click:Connect(function()
        modalSelectingState = st
        modalTitle.Text = "Assign Animation for: " .. st
        modalSearch.Text = ""
        populateModalList("")
        modalOverlay.Visible = true
    end)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 52, 0, 26)
    clearBtn.Position = UDim2.new(1, -60, 0.5, -13)
    clearBtn.BackgroundColor3 = C.surface
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = C.textMuted
    clearBtn.Font = Enum.Font.GothamSemibold
    clearBtn.TextSize = 10
    clearBtn.Parent = sRow
    applyCorner(clearBtn, 4)
    applyStroke(clearBtn, C.divider, 1, 0)

    clearBtn.MouseEnter:Connect(function()
        tween(clearBtn, {BackgroundColor3 = C.dangerHover, TextColor3 = C.accent}, 0.15)
    end)
    clearBtn.MouseLeave:Connect(function()
        tween(clearBtn, {BackgroundColor3 = C.surface, TextColor3 = C.textMuted}, 0.15)
    end)
    clearBtn.MouseButton1Click:Connect(function()
        savedConfig.states[st] = nil
        saveConfig()
        sBtn.Text = "None"
        sBtn.TextColor3 = C.textMuted
    end)
end

-- PANEL 5: LIMBS TAB (Hide / Show Body Parts & Hats)
local limbsPanel = Instance.new("ScrollingFrame")
limbsPanel.Size = UDim2.new(1, 0, 1, 0)
limbsPanel.BackgroundTransparency = 1
limbsPanel.BorderSizePixel = 0
limbsPanel.ScrollBarThickness = 3
limbsPanel.ScrollBarImageColor3 = C.accent
limbsPanel.ScrollBarImageTransparency = 0.6
pcall(function()
    limbsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
end)
limbsPanel.CanvasSize = UDim2.new(0, 0, 0, 420)
limbsPanel.Visible = false
limbsPanel.Parent = contentArea

local limbsPadding = Instance.new("UIPadding")
limbsPadding.PaddingLeft = UDim.new(0, 2)
limbsPadding.PaddingRight = UDim.new(0, 4)
limbsPadding.PaddingTop = UDim.new(0, 2)
limbsPadding.PaddingBottom = UDim.new(0, 12)
limbsPadding.Parent = limbsPanel

local limbsLayout = Instance.new("UIListLayout")
limbsLayout.Padding = UDim.new(0, 8)
limbsLayout.SortOrder = Enum.SortOrder.LayoutOrder
limbsLayout.Parent = limbsPanel

local limbsHeader = Instance.new("TextLabel")
limbsHeader.Size = UDim2.new(1, 0, 0, 16)
limbsHeader.BackgroundTransparency = 1
limbsHeader.Text = "LIMB & BODY VISIBILITY"
limbsHeader.TextColor3 = C.textMuted
limbsHeader.Font = Enum.Font.GothamBold
limbsHeader.TextSize = 10
limbsHeader.TextXAlignment = Enum.TextXAlignment.Left
limbsHeader.LayoutOrder = 1
limbsHeader.Parent = limbsPanel

-- Helper: Create Eternity Capsule Toggle Switch (forjnkie.lua theme)
local function createEternityToggleSwitch(parent, posX, posY)
    local track = Instance.new("Frame", parent)
    track.Size = UDim2.new(0, 44, 0, 22)
    track.Position = UDim2.new(1, posX or -54, 0.5, posY or -11)
    track.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    track.BackgroundTransparency = 0.5
    track.BorderSizePixel = 0
    applyCorner(track, 100)

    local trackStroke = Instance.new("UIStroke", track)
    trackStroke.Color = Color3.fromRGB(255, 255, 255)
    trackStroke.Thickness = 1
    trackStroke.Transparency = 0.85

    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    knob.BorderSizePixel = 0
    applyCorner(knob, 100)

    local knobGrad = Instance.new("UIGradient", knob)
    knobGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150))
    })
    knobGrad.Rotation = 90

    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Color = Color3.fromRGB(255, 255, 255)
    knobStroke.Thickness = 1
    knobStroke.Transparency = 0.5

    local glowRing = Instance.new("Frame", knob)
    glowRing.Size = UDim2.new(1, 0, 1, 0)
    glowRing.Position = UDim2.new(0.5, 0, 0.5, 0)
    glowRing.AnchorPoint = Vector2.new(0.5, 0.5)
    glowRing.BackgroundTransparency = 1
    glowRing.ZIndex = knob.ZIndex - 1
    applyCorner(glowRing, 100)

    local glowStroke = Instance.new("UIStroke", glowRing)
    glowStroke.Color = Color3.fromRGB(80, 220, 140)
    glowStroke.Thickness = 5
    glowStroke.Transparency = 1

    return track, knob, glowStroke
end

-- Helper: Apply visual state to Eternity Toggle with Back easing
local function updateEternityToggleVisual(track, knob, glowStroke, isOn, animate)
    local targetTrackBg = isOn and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(15, 15, 15)
    local targetKnobBg = isOn and Color3.fromRGB(80, 220, 140) or Color3.fromRGB(100, 100, 100)
    local targetKnobPos = isOn and UDim2.new(0, 25, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    local targetGlowTrans = isOn and 0.65 or 1.0

    if animate then
        tween(track, {BackgroundColor3 = targetTrackBg}, 0.25)
        tween(knob, {BackgroundColor3 = targetKnobBg, Position = targetKnobPos}, 0.25, Enum.EasingStyle.Back)
        if glowStroke then
            tween(glowStroke, {Transparency = targetGlowTrans}, 0.25)
        end
    else
        track.BackgroundColor3 = targetTrackBg
        knob.BackgroundColor3 = targetKnobBg
        knob.Position = targetKnobPos
        if glowStroke then
            glowStroke.Transparency = targetGlowTrans
        end
    end
end

-- Master Limbs Toggle Card (Replaces the clunky dual buttons)
local masterCard = Instance.new("Frame")
masterCard.Size = UDim2.new(1, 0, 0, 46)
masterCard.BackgroundColor3 = C.surface
masterCard.BorderSizePixel = 0
masterCard.LayoutOrder = 2
masterCard.Parent = limbsPanel
applyCorner(masterCard, 10)

local masterStroke = Instance.new("UIStroke", masterCard)
masterStroke.Color = Color3.fromRGB(255, 255, 255)
masterStroke.Thickness = 1
masterStroke.Transparency = 0.88

local masterInfoFrame = Instance.new("Frame")
masterInfoFrame.Size = UDim2.new(1, -125, 1, 0)
masterInfoFrame.Position = UDim2.new(0, 14, 0, 0)
masterInfoFrame.BackgroundTransparency = 1
masterInfoFrame.Parent = masterCard

local masterTitleLbl = Instance.new("TextLabel")
masterTitleLbl.Size = UDim2.new(1, 0, 0, 20)
masterTitleLbl.Position = UDim2.new(0, 0, 0, 5)
masterTitleLbl.BackgroundTransparency = 1
masterTitleLbl.Text = "Master Limbs Switch"
masterTitleLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
masterTitleLbl.Font = Enum.Font.GothamBold
masterTitleLbl.TextSize = 11
masterTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
masterTitleLbl.Parent = masterInfoFrame

local masterDescLbl = Instance.new("TextLabel")
masterDescLbl.Size = UDim2.new(1, 0, 0, 16)
masterDescLbl.Position = UDim2.new(0, 0, 0, 23)
masterDescLbl.BackgroundTransparency = 1
masterDescLbl.Text = "Toggle all body parts on or off at once"
masterDescLbl.TextColor3 = C.textMuted
masterDescLbl.Font = Enum.Font.Gotham
masterDescLbl.TextSize = 9
masterDescLbl.TextXAlignment = Enum.TextXAlignment.Left
masterDescLbl.TextTruncate = Enum.TextTruncate.AtEnd
masterDescLbl.Parent = masterInfoFrame

local masterStatusLbl = Instance.new("TextLabel")
masterStatusLbl.Size = UDim2.new(0, 54, 1, 0)
masterStatusLbl.Position = UDim2.new(1, -114, 0, 0)
masterStatusLbl.BackgroundTransparency = 1
masterStatusLbl.Font = Enum.Font.GothamBold
masterStatusLbl.TextSize = 9
masterStatusLbl.TextXAlignment = Enum.TextXAlignment.Right
masterStatusLbl.Text = "ALL SHOWN"
masterStatusLbl.TextColor3 = Color3.fromRGB(80, 220, 140)
masterStatusLbl.Parent = masterCard

local masterTrack, masterKnob, masterGlowStroke = createEternityToggleSwitch(masterCard, -54, -11)

local masterBtn = Instance.new("TextButton")
masterBtn.Size = UDim2.new(1, 0, 1, 0)
masterBtn.BackgroundTransparency = 1
masterBtn.Text = ""
masterBtn.ZIndex = 5
masterBtn.Parent = masterCard

masterBtn.MouseEnter:Connect(function()
    tween(masterCard, {BackgroundColor3 = C.surfaceHover}, 0.2)
end)
masterBtn.MouseLeave:Connect(function()
    tween(masterCard, {BackgroundColor3 = C.surface}, 0.2)
end)

-- Section Divider
local sectionDivider = Instance.new("Frame")
sectionDivider.Size = UDim2.new(1, 0, 0, 18)
sectionDivider.BackgroundTransparency = 1
sectionDivider.LayoutOrder = 3
sectionDivider.Parent = limbsPanel

local sectionLbl = Instance.new("TextLabel")
sectionLbl.Size = UDim2.new(1, 0, 1, 0)
sectionLbl.BackgroundTransparency = 1
sectionLbl.Text = "INDIVIDUAL BODY PARTS"
sectionLbl.TextColor3 = C.textDim
sectionLbl.Font = Enum.Font.GothamBold
sectionLbl.TextSize = 9
sectionLbl.TextXAlignment = Enum.TextXAlignment.Left
sectionLbl.Parent = sectionDivider

local limbDefinitions = {
    { id = "Head", name = "Head (Face, Hats, Nametag)", desc = "Hides head, all hats, hair, face decals & player billboard", parts = {"Head"} },
    { id = "Torso", name = "Torso", desc = "Hides main body (Torso, UpperTorso, LowerTorso)", parts = {"Torso", "UpperTorso", "LowerTorso"} },
    { id = "Left Arm", name = "Left Arm", desc = "Hides Left Arm / UpperArm / LowerArm / LeftHand", parts = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"} },
    { id = "Right Arm", name = "Right Arm", desc = "Hides Right Arm / UpperArm / LowerArm / RightHand", parts = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"} },
    { id = "Left Leg", name = "Left Leg", desc = "Hides Left Leg / UpperLeg / LowerLeg / LeftFoot", parts = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"} },
    { id = "Right Leg", name = "Right Leg", desc = "Hides Right Leg / UpperLeg / LowerLeg / RightFoot", parts = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"} }
}

local limbButtons = {}

local function updateMasterToggleVisual(animate)
    if animate == nil then animate = true end
    local hiddenCount = 0
    for _, ldef in ipairs(limbDefinitions) do
        local isHidden = false
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                isHidden = true
                break
            end
        end
        if isHidden then
            hiddenCount = hiddenCount + 1
        end
    end

    if hiddenCount == 0 then
        masterStatusLbl.Text = "ALL SHOWN"
        masterStatusLbl.TextColor3 = Color3.fromRGB(80, 220, 140)
        updateEternityToggleVisual(masterTrack, masterKnob, masterGlowStroke, true, animate)
    elseif hiddenCount == #limbDefinitions then
        masterStatusLbl.Text = "ALL HIDDEN"
        masterStatusLbl.TextColor3 = Color3.fromRGB(235, 75, 75)
        updateEternityToggleVisual(masterTrack, masterKnob, masterGlowStroke, false, animate)
    else
        masterStatusLbl.Text = "CUSTOM"
        masterStatusLbl.TextColor3 = Color3.fromRGB(240, 180, 60)
        local targetTrackBg = Color3.fromRGB(18, 18, 22)
        local targetKnobBg = Color3.fromRGB(140, 140, 150)
        local targetKnobPos = UDim2.new(0, 3, 0.5, -8)
        if animate then
            tween(masterTrack, {BackgroundColor3 = targetTrackBg}, 0.25)
            tween(masterKnob, {BackgroundColor3 = targetKnobBg, Position = targetKnobPos}, 0.25, Enum.EasingStyle.Back)
            if masterGlowStroke then
                tween(masterGlowStroke, {Transparency = 1}, 0.25)
            end
        else
            masterTrack.BackgroundColor3 = targetTrackBg
            masterKnob.BackgroundColor3 = targetKnobBg
            masterKnob.Position = targetKnobPos
            if masterGlowStroke then
                masterGlowStroke.Transparency = 1
            end
        end
    end
end

local function setLimbHidden(limbDef, hidden, skipMasterUpdate, animate)
    if animate == nil then animate = true end
    for _, p in ipairs(limbDef.parts) do
        if hidden then
            _G.hiddenBodyParts[p] = true
            savedConfig.hiddenLimbs[p] = true
        else
            _G.hiddenBodyParts[p] = nil
            savedConfig.hiddenLimbs[p] = nil
        end
    end
    saveConfig()

    local rowData = limbButtons[limbDef.id]
    if rowData then
        local isVisible = not hidden
        rowData.statusLbl.Text = isVisible and "VISIBLE" or "HIDDEN"
        rowData.statusLbl.TextColor3 = isVisible and Color3.fromRGB(80, 220, 140) or Color3.fromRGB(235, 75, 75)
        updateEternityToggleVisual(rowData.track, rowData.knob, rowData.glowStroke, isVisible, animate)
    end

    if not skipMasterUpdate then
        updateMasterToggleVisual(animate)
    end
end

masterBtn.MouseButton1Click:Connect(function()
    local hiddenCount = 0
    for _, ldef in ipairs(limbDefinitions) do
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                hiddenCount = hiddenCount + 1
                break
            end
        end
    end

    -- If 0 hidden (all visible), turn all OFF (hide all)
    -- If 1 or more hidden, turn all ON (show all)
    local targetHidden = (hiddenCount == 0)
    for _, ldef in ipairs(limbDefinitions) do
        setLimbHidden(ldef, targetHidden, true, true)
    end
    updateMasterToggleVisual(true)
end)

for idx, ldef in ipairs(limbDefinitions) do
    local lRow = Instance.new("Frame")
    lRow.Size = UDim2.new(1, 0, 0, 44)
    lRow.BackgroundColor3 = C.surface
    lRow.BorderSizePixel = 0
    lRow.LayoutOrder = 3 + idx
    lRow.Parent = limbsPanel
    applyCorner(lRow, 10)

    local rowStroke = Instance.new("UIStroke", lRow)
    rowStroke.Color = Color3.fromRGB(255, 255, 255)
    rowStroke.Thickness = 1
    rowStroke.Transparency = 0.9

    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -125, 1, 0)
    infoFrame.Position = UDim2.new(0, 14, 0, 0)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = lRow

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Position = UDim2.new(0, 0, 0, 5)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = ldef.name
    titleLbl.TextColor3 = Color3.fromRGB(240, 240, 248)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = infoFrame

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, 0, 0, 16)
    descLbl.Position = UDim2.new(0, 0, 0, 23)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = ldef.desc
    descLbl.TextColor3 = C.textMuted
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 9
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextTruncate = Enum.TextTruncate.AtEnd
    descLbl.Parent = infoFrame

    -- Check if currently hidden
    local isCurrentlyHidden = false
    for _, p in ipairs(ldef.parts) do
        if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
            isCurrentlyHidden = true
            break
        end
    end

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 52, 1, 0)
    statusLbl.Position = UDim2.new(1, -112, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 9
    statusLbl.TextXAlignment = Enum.TextXAlignment.Right
    statusLbl.Text = isCurrentlyHidden and "HIDDEN" or "VISIBLE"
    statusLbl.TextColor3 = isCurrentlyHidden and Color3.fromRGB(235, 75, 75) or Color3.fromRGB(80, 220, 140)
    statusLbl.Parent = lRow

    local track, knob, glowStroke = createEternityToggleSwitch(lRow, -54, -11)
    updateEternityToggleVisual(track, knob, glowStroke, not isCurrentlyHidden, false)

    local rowBtn = Instance.new("TextButton")
    rowBtn.Size = UDim2.new(1, 0, 1, 0)
    rowBtn.BackgroundTransparency = 1
    rowBtn.Text = ""
    rowBtn.ZIndex = 5
    rowBtn.Parent = lRow

    rowBtn.MouseEnter:Connect(function()
        tween(lRow, {BackgroundColor3 = C.surfaceHover}, 0.2)
    end)
    rowBtn.MouseLeave:Connect(function()
        tween(lRow, {BackgroundColor3 = C.surface}, 0.2)
    end)

    limbButtons[ldef.id] = {
        statusLbl = statusLbl,
        track = track,
        knob = knob,
        glowStroke = glowStroke
    }

    rowBtn.MouseButton1Click:Connect(function()
        local isHidden = false
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                isHidden = true
                break
            end
        end
        setLimbHidden(ldef, not isHidden, false, true)
    end)
end

local function updateLimbsUI()
    for _, ldef in ipairs(limbDefinitions) do
        local isHidden = false
        for _, p in ipairs(ldef.parts) do
            if savedConfig.hiddenLimbs[p] or (_G.hiddenBodyParts and _G.hiddenBodyParts[p]) then
                isHidden = true
                break
            end
        end
        local rowData = limbButtons[ldef.id]
        if rowData then
            local isVisible = not isHidden
            rowData.statusLbl.Text = isVisible and "VISIBLE" or "HIDDEN"
            rowData.statusLbl.TextColor3 = isVisible and Color3.fromRGB(80, 220, 140) or Color3.fromRGB(235, 75, 75)
            updateEternityToggleVisual(rowData.track, rowData.knob, rowData.glowStroke, isVisible, false)
        end
    end
    updateMasterToggleVisual(false)
end


-- Continuous RenderStepped loop to enforce clone transparency and nametag hiding
RunService.RenderStepped:Connect(function()
    local clone = api and api.get_clone and api.get_clone()
    if not clone then return end
    if not _G.hiddenBodyParts or not next(_G.hiddenBodyParts) then return end

    for partName, _ in pairs(_G.hiddenBodyParts) do
        local p = clone:FindFirstChild(partName)
        if p and p:IsA("BasePart") then
            p.LocalTransparencyModifier = 1
            p.Transparency = 1
        end

        if partName == "Head" then
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("Decal") then
                    d.Transparency = 1
                elseif d:IsA("Accessory") then
                    local handle = d:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        handle.LocalTransparencyModifier = 1
                        handle.Transparency = 1
                    end
                end
            end
            local hum = clone:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.DisplayName = ""
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
                hum.NameDisplayDistance = 100
                hum.HealthDisplayDistance = 100
            end
        end
    end
end)

limbsPanel.CanvasSize = UDim2.new(0, 0, 0, #limbDefinitions * 56 + 80)



-- ═══════════════════════════════════════════════════
-- PANEL FORWARD DECLARATIONS (Luau 200 Register Guard)
-- ═══════════════════════════════════════════════════
local copierPanel = nil
local trackingPanel = nil
local stretchingPanel = nil
local studioPanel = nil
local currentlyBindingTracking = nil
local htCardUI = nil
local laCardUI = nil
local raCardUI = nil
local updateTrackingEngineState = function() end


-- ═══════════════════════════════════════════════════
-- BUILDER: COPIER TAB (Reanimation Mirror Engine)
-- ═══════════════════════════════════════════════════
local function buildCopierPanel(parent)
    local lp = player or Players.LocalPlayer
    -- ═══════════════════════════════════════════════════
    -- PANEL 6: COPIER TAB (Reanimation Mirror Engine)
    -- ═══════════════════════════════════════════════════
    local copierPanel = Instance.new("ScrollingFrame")
    copierPanel.Size = UDim2.new(1, 0, 1, 0)
    copierPanel.BackgroundTransparency = 1
    copierPanel.BorderSizePixel = 0
    copierPanel.ScrollBarThickness = 3
    copierPanel.ScrollBarImageColor3 = C.accent
    copierPanel.ScrollBarImageTransparency = 0.6
    pcall(function() copierPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    copierPanel.CanvasSize = UDim2.new(0, 0, 0, 580)
    copierPanel.Visible = false
    copierPanel.Parent = parent
    
    local copierPadding = Instance.new("UIPadding", copierPanel)
    copierPadding.PaddingLeft = UDim.new(0, 2)
    copierPadding.PaddingRight = UDim.new(0, 4)
    copierPadding.PaddingTop = UDim.new(0, 2)
    copierPadding.PaddingBottom = UDim.new(0, 14)
    
    local copierLayout = Instance.new("UIListLayout", copierPanel)
    copierLayout.Padding = UDim.new(0, 8)
    copierLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local copierHeader = Instance.new("TextLabel", copierPanel)
    copierHeader.Size = UDim2.new(1, 0, 0, 16)
    copierHeader.BackgroundTransparency = 1
    copierHeader.Text = "REANIMATION COPIER"
    copierHeader.TextColor3 = C.textMuted
    copierHeader.Font = Enum.Font.GothamBold
    copierHeader.TextSize = 10
    copierHeader.TextXAlignment = Enum.TextXAlignment.Left
    copierHeader.LayoutOrder = 1
    
    -- Copier Variables & State
    local acEnabled = false
    local acFreeze = false
    local acFreeRoam = false
    local acSelectedPlayer = nil
    local acFrozenPos = nil
    local acSideDist = 2.0
    local acForwardDist = 2.0
    local acSideMode = "Left"
    local acForwardMode = nil
    local acConn = nil
    local acSavedStates = {}
    local acSideDragging = false
    local acFwdDragging = false
    
    -- Card 1: Master Copier Toggle
    local acToggleCard = Instance.new("Frame", copierPanel)
    acToggleCard.Size = UDim2.new(1, 0, 0, 48)
    acToggleCard.BackgroundColor3 = C.bgCard
    acToggleCard.LayoutOrder = 2
    applyCorner(acToggleCard, 8)
    applyStroke(acToggleCard, C.divider, 1, 0)
    
    local acToggleTitle = Instance.new("TextLabel", acToggleCard)
    acToggleTitle.Size = UDim2.new(1, -70, 0, 18)
    acToggleTitle.Position = UDim2.new(0, 12, 0, 6)
    acToggleTitle.BackgroundTransparency = 1
    acToggleTitle.Text = "Animation Copier"
    acToggleTitle.TextColor3 = C.text
    acToggleTitle.Font = Enum.Font.GothamBold
    acToggleTitle.TextSize = 10.5
    acToggleTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local acToggleSub = Instance.new("TextLabel", acToggleCard)
    acToggleSub.Size = UDim2.new(1, -70, 0, 16)
    acToggleSub.Position = UDim2.new(0, 12, 0, 24)
    acToggleSub.BackgroundTransparency = 1
    acToggleSub.Text = "Mirror target player's exact pose & animations"
    acToggleSub.TextColor3 = C.textMuted
    acToggleSub.Font = Enum.Font.GothamMedium
    acToggleSub.TextSize = 9
    acToggleSub.TextXAlignment = Enum.TextXAlignment.Left
    
    local acMasterTrack, acMasterKnob, acMasterGlow = createEternityToggleSwitch(acToggleCard, -54, -11)
    local acMasterBtn = Instance.new("TextButton", acMasterTrack)
    acMasterBtn.Size = UDim2.new(1, 0, 1, 0)
    acMasterBtn.BackgroundTransparency = 1
    acMasterBtn.Text = ""
    
    -- Card 2: Target Player Search & List
    local acPlayerCard = Instance.new("Frame", copierPanel)
    acPlayerCard.Size = UDim2.new(1, 0, 0, 190)
    acPlayerCard.BackgroundColor3 = C.bgCard
    acPlayerCard.LayoutOrder = 3
    applyCorner(acPlayerCard, 8)
    applyStroke(acPlayerCard, C.divider, 1, 0)
    
    local acPlayerTitle = Instance.new("TextLabel", acPlayerCard)
    acPlayerTitle.Size = UDim2.new(1, -20, 0, 16)
    acPlayerTitle.Position = UDim2.new(0, 10, 0, 6)
    acPlayerTitle.BackgroundTransparency = 1
    acPlayerTitle.Text = "SELECT TARGET PLAYER"
    acPlayerTitle.TextColor3 = C.accent
    acPlayerTitle.Font = Enum.Font.GothamBold
    acPlayerTitle.TextSize = 9.5
    acPlayerTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local acSearchBox = Instance.new("TextBox", acPlayerCard)
    acSearchBox.Size = UDim2.new(1, -20, 0, 26)
    acSearchBox.Position = UDim2.new(0, 10, 0, 26)
    acSearchBox.BackgroundColor3 = C.input
    acSearchBox.PlaceholderText = "Search player by name..."
    acSearchBox.PlaceholderColor3 = C.textMuted
    acSearchBox.Text = ""
    acSearchBox.TextColor3 = C.text
    acSearchBox.Font = Enum.Font.GothamMedium
    acSearchBox.TextSize = 10
    acSearchBox.ClearTextOnFocus = false
    applyCorner(acSearchBox, 6)
    applyStroke(acSearchBox, C.divider, 1, 0.2)
    
    local acSearchPad = Instance.new("UIPadding", acSearchBox)
    acSearchPad.PaddingLeft = UDim.new(0, 8)
    
    local acPlayerList = Instance.new("ScrollingFrame", acPlayerCard)
    acPlayerList.Size = UDim2.new(1, -20, 0, 124)
    acPlayerList.Position = UDim2.new(0, 10, 0, 58)
    acPlayerList.BackgroundColor3 = C.surface
    acPlayerList.BackgroundTransparency = 0.5
    acPlayerList.BorderSizePixel = 0
    acPlayerList.ScrollBarThickness = 3
    acPlayerList.ScrollBarImageColor3 = C.accent
    acPlayerList.ScrollBarImageTransparency = 0.5
    applyCorner(acPlayerList, 6)
    
    local acListLayout = Instance.new("UIListLayout", acPlayerList)
    acListLayout.Padding = UDim.new(0, 3)
    acListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    acListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        acPlayerList.CanvasSize = UDim2.new(0, 0, 0, acListLayout.AbsoluteContentSize.Y + 6)
    end)
    
    -- Card 3: Freeze Mode
    local acFreezeCard = Instance.new("Frame", copierPanel)
    acFreezeCard.Size = UDim2.new(1, 0, 0, 44)
    acFreezeCard.BackgroundColor3 = C.bgCard
    acFreezeCard.LayoutOrder = 4
    applyCorner(acFreezeCard, 8)
    applyStroke(acFreezeCard, C.divider, 1, 0)
    
    local acFreezeTitle = Instance.new("TextLabel", acFreezeCard)
    acFreezeTitle.Size = UDim2.new(1, -70, 0, 16)
    acFreezeTitle.Position = UDim2.new(0, 12, 0, 6)
    acFreezeTitle.BackgroundTransparency = 1
    acFreezeTitle.Text = "FREEZE MODE"
    acFreezeTitle.TextColor3 = C.text
    acFreezeTitle.Font = Enum.Font.GothamBold
    acFreezeTitle.TextSize = 10
    acFreezeTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local acFreezeSub = Instance.new("TextLabel", acFreezeCard)
    acFreezeSub.Size = UDim2.new(1, -70, 0, 14)
    acFreezeSub.Position = UDim2.new(0, 12, 0, 22)
    acFreezeSub.BackgroundTransparency = 1
    acFreezeSub.Text = "Freeze in place; spins & poses on the spot"
    acFreezeSub.TextColor3 = C.textMuted
    acFreezeSub.Font = Enum.Font.GothamMedium
    acFreezeSub.TextSize = 8.5
    acFreezeSub.TextXAlignment = Enum.TextXAlignment.Left
    
    local acFreezeTrack, acFreezeKnob, acFreezeGlow = createEternityToggleSwitch(acFreezeCard, -54, -11)
    local acFreezeBtn = Instance.new("TextButton", acFreezeTrack)
    acFreezeBtn.Size = UDim2.new(1, 0, 1, 0)
    acFreezeBtn.BackgroundTransparency = 1
    acFreezeBtn.Text = ""
    
    -- Card 4: FreeRoam Mode
    local acFreeRoamCard = Instance.new("Frame", copierPanel)
    acFreeRoamCard.Size = UDim2.new(1, 0, 0, 44)
    acFreeRoamCard.BackgroundColor3 = C.bgCard
    acFreeRoamCard.LayoutOrder = 5
    applyCorner(acFreeRoamCard, 8)
    applyStroke(acFreeRoamCard, C.divider, 1, 0)
    
    local acFreeRoamTitle = Instance.new("TextLabel", acFreeRoamCard)
    acFreeRoamTitle.Size = UDim2.new(1, -70, 0, 16)
    acFreeRoamTitle.Position = UDim2.new(0, 12, 0, 6)
    acFreeRoamTitle.BackgroundTransparency = 1
    acFreeRoamTitle.Text = "FREEROAM MODE"
    acFreeRoamTitle.TextColor3 = C.text
    acFreeRoamTitle.Font = Enum.Font.GothamBold
    acFreeRoamTitle.TextSize = 10
    acFreeRoamTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local acFreeRoamSub = Instance.new("TextLabel", acFreeRoamCard)
    acFreeRoamSub.Size = UDim2.new(1, -70, 0, 14)
    acFreeRoamSub.Position = UDim2.new(0, 12, 0, 22)
    acFreeRoamSub.BackgroundTransparency = 1
    acFreeRoamSub.Text = "Move freely (WASD) while copying target's animation"
    acFreeRoamSub.TextColor3 = C.textMuted
    acFreeRoamSub.Font = Enum.Font.GothamMedium
    acFreeRoamSub.TextSize = 8.5
    acFreeRoamSub.TextXAlignment = Enum.TextXAlignment.Left
    
    local acFreeRoamTrack, acFreeRoamKnob, acFreeRoamGlow = createEternityToggleSwitch(acFreeRoamCard, -54, -11)
    local acFreeRoamBtn = Instance.new("TextButton", acFreeRoamTrack)
    acFreeRoamBtn.Size = UDim2.new(1, 0, 1, 0)
    acFreeRoamBtn.BackgroundTransparency = 1
    acFreeRoamBtn.Text = ""
    
    -- Card 5: Lateral Offset (Left / Right)
    local acLateralCard = Instance.new("Frame", copierPanel)
    acLateralCard.Size = UDim2.new(1, 0, 0, 66)
    acLateralCard.BackgroundColor3 = C.bgCard
    acLateralCard.LayoutOrder = 6
    applyCorner(acLateralCard, 8)
    applyStroke(acLateralCard, C.divider, 1, 0)
    
    local acLateralTitle = Instance.new("TextLabel", acLateralCard)
    acLateralTitle.Size = UDim2.new(0.5, 0, 0, 16)
    acLateralTitle.Position = UDim2.new(0, 10, 0, 5)
    acLateralTitle.BackgroundTransparency = 1
    acLateralTitle.Text = "LATERAL OFFSET"
    acLateralTitle.TextColor3 = C.textMuted
    acLateralTitle.Font = Enum.Font.GothamBold
    acLateralTitle.TextSize = 9
    acLateralTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local acSideBadge = Instance.new("TextLabel", acLateralCard)
    acSideBadge.Size = UDim2.new(0, 70, 0, 16)
    acSideBadge.Position = UDim2.new(1, -80, 0, 5)
    acSideBadge.BackgroundColor3 = C.surface
    acSideBadge.Text = "2.0 studs"
    acSideBadge.TextColor3 = C.accent
    acSideBadge.Font = Enum.Font.GothamBold
    acSideBadge.TextSize = 8.5
    applyCorner(acSideBadge, 4)
    applyStroke(acSideBadge, C.divider, 1, 0)
    
    local acSideLeft = Instance.new("TextButton", acLateralCard)
    acSideLeft.Position = UDim2.new(0, 10, 0, 24)
    acSideLeft.Size = UDim2.new(0.5, -14, 0, 20)
    acSideLeft.BackgroundColor3 = C.accent
    acSideLeft.Text = "Left"
    acSideLeft.TextColor3 = Color3.fromRGB(8, 8, 10)
    acSideLeft.Font = Enum.Font.GothamBold
    acSideLeft.TextSize = 9
    acSideLeft.AutoButtonColor = false
    applyCorner(acSideLeft, 4)
    
    local acSideRight = Instance.new("TextButton", acLateralCard)
    acSideRight.Position = UDim2.new(0.5, 4, 0, 24)
    acSideRight.Size = UDim2.new(0.5, -14, 0, 20)
    acSideRight.BackgroundColor3 = C.surface
    acSideRight.Text = "Right"
    acSideRight.TextColor3 = C.textDim
    acSideRight.Font = Enum.Font.GothamBold
    acSideRight.TextSize = 9
    acSideRight.AutoButtonColor = false
    applyCorner(acSideRight, 4)
    
    local acSideDistTrack = Instance.new("Frame", acLateralCard)
    acSideDistTrack.Position = UDim2.new(0, 10, 0, 50)
    acSideDistTrack.Size = UDim2.new(1, -20, 0, 6)
    acSideDistTrack.BackgroundColor3 = C.surface
    applyCorner(acSideDistTrack, 3)
    
    local acSideDistFill = Instance.new("Frame", acSideDistTrack)
    acSideDistFill.Size = UDim2.new(0.04, 0, 1, 0)
    acSideDistFill.BackgroundColor3 = C.accent
    applyCorner(acSideDistFill, 3)
    
    local acSideDistHandle = Instance.new("Frame", acSideDistTrack)
    acSideDistHandle.AnchorPoint = Vector2.new(0.5, 0.5)
    acSideDistHandle.Position = UDim2.new(0.04, 0, 0.5, 0)
    acSideDistHandle.Size = UDim2.new(0, 12, 0, 12)
    acSideDistHandle.BackgroundColor3 = C.text
    applyCorner(acSideDistHandle, 6)
    
    -- Card 6: Depth Offset (Front / Back)
    local acDepthCard = Instance.new("Frame", copierPanel)
    acDepthCard.Size = UDim2.new(1, 0, 0, 66)
    acDepthCard.BackgroundColor3 = C.bgCard
    acDepthCard.LayoutOrder = 7
    applyCorner(acDepthCard, 8)
    applyStroke(acDepthCard, C.divider, 1, 0)
    
    local acDepthTitle = Instance.new("TextLabel", acDepthCard)
    acDepthTitle.Size = UDim2.new(0.5, 0, 0, 16)
    acDepthTitle.Position = UDim2.new(0, 10, 0, 5)
    acDepthTitle.BackgroundTransparency = 1
    acDepthTitle.Text = "DEPTH OFFSET"
    acDepthTitle.TextColor3 = C.textMuted
    acDepthTitle.Font = Enum.Font.GothamBold
    acDepthTitle.TextSize = 9
    acDepthTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local acFwdBadge = Instance.new("TextLabel", acDepthCard)
    acFwdBadge.Size = UDim2.new(0, 70, 0, 16)
    acFwdBadge.Position = UDim2.new(1, -80, 0, 5)
    acFwdBadge.BackgroundColor3 = C.surface
    acFwdBadge.Text = "2.0 studs"
    acFwdBadge.TextColor3 = C.accent
    acFwdBadge.Font = Enum.Font.GothamBold
    acFwdBadge.TextSize = 8.5
    applyCorner(acFwdBadge, 4)
    applyStroke(acFwdBadge, C.divider, 1, 0)
    
    local acSideFront = Instance.new("TextButton", acDepthCard)
    acSideFront.Position = UDim2.new(0, 10, 0, 24)
    acSideFront.Size = UDim2.new(0.5, -14, 0, 20)
    acSideFront.BackgroundColor3 = C.surface
    acSideFront.Text = "Front"
    acSideFront.TextColor3 = C.textDim
    acSideFront.Font = Enum.Font.GothamBold
    acSideFront.TextSize = 9
    acSideFront.AutoButtonColor = false
    applyCorner(acSideFront, 4)
    
    local acSideBack = Instance.new("TextButton", acDepthCard)
    acSideBack.Position = UDim2.new(0.5, 4, 0, 24)
    acSideBack.Size = UDim2.new(0.5, -14, 0, 20)
    acSideBack.BackgroundColor3 = C.surface
    acSideBack.Text = "Back"
    acSideBack.TextColor3 = C.textDim
    acSideBack.Font = Enum.Font.GothamBold
    acSideBack.TextSize = 9
    acSideBack.AutoButtonColor = false
    applyCorner(acSideBack, 4)
    
    local acFwdDistTrack = Instance.new("Frame", acDepthCard)
    acFwdDistTrack.Position = UDim2.new(0, 10, 0, 50)
    acFwdDistTrack.Size = UDim2.new(1, -20, 0, 6)
    acFwdDistTrack.BackgroundColor3 = C.surface
    applyCorner(acFwdDistTrack, 3)
    
    local acFwdDistFill = Instance.new("Frame", acFwdDistTrack)
    acFwdDistFill.Size = UDim2.new(0.04, 0, 1, 0)
    acFwdDistFill.BackgroundColor3 = C.accent
    applyCorner(acFwdDistFill, 3)
    
    local acFwdDistHandle = Instance.new("Frame", acFwdDistTrack)
    acFwdDistHandle.AnchorPoint = Vector2.new(0.5, 0.5)
    acFwdDistHandle.Position = UDim2.new(0.04, 0, 0.5, 0)
    acFwdDistHandle.Size = UDim2.new(0, 12, 0, 12)
    acFwdDistHandle.BackgroundColor3 = C.text
    applyCorner(acFwdDistHandle, 6)
    
    -- Card 7: Live Status Box
    local acStatusBox = Instance.new("Frame", copierPanel)
    acStatusBox.Size = UDim2.new(1, 0, 0, 28)
    acStatusBox.BackgroundColor3 = C.bgCard
    acStatusBox.LayoutOrder = 8
    applyCorner(acStatusBox, 6)
    applyStroke(acStatusBox, C.divider, 1, 0)
    
    local acStatusDot = Instance.new("Frame", acStatusBox)
    acStatusDot.Position = UDim2.new(0, 8, 0.5, -3)
    acStatusDot.Size = UDim2.new(0, 6, 0, 6)
    acStatusDot.BackgroundColor3 = C.textMuted
    applyCorner(acStatusDot, 100)
    
    local acStatus = Instance.new("TextLabel", acStatusBox)
    acStatus.BackgroundTransparency = 1
    acStatus.Position = UDim2.new(0, 22, 0, 0)
    acStatus.Size = UDim2.new(1, -28, 1, 0)
    acStatus.Font = Enum.Font.GothamMedium
    acStatus.Text = "OFF - Select a player and toggle ON"
    acStatus.TextColor3 = C.textMuted
    acStatus.TextSize = 8.5
    acStatus.TextXAlignment = Enum.TextXAlignment.Left
    acStatus.TextTruncate = Enum.TextTruncate.AtEnd
    
    -- Copier Helper Functions
    local function acUpdateStatusText()
        if not acSelectedPlayer then
            acStatus.Text = acEnabled and "ON - Select a player from list above" or "OFF - Select a player and toggle ON"
            acStatus.TextColor3 = acEnabled and Color3.fromRGB(240, 200, 80) or C.textMuted
            acStatusDot.BackgroundColor3 = acEnabled and Color3.fromRGB(240, 200, 80) or C.textMuted
            return
        end
    
        local modeSuffix = ""
        if acFreeze then
            modeSuffix = " [Frozen In-Place]"
        elseif acFreeRoam then
            modeSuffix = " [FreeRoam]"
        else
            local distInfo = {}
            if acSideMode then table.insert(distInfo, string.format("%s: %.1f", acSideMode, acSideDist)) end
            if acForwardMode then table.insert(distInfo, string.format("%s: %.1f", acForwardMode, acForwardDist)) end
            local distStr = (#distInfo > 0) and table.concat(distInfo, " | ") or "In-Place"
            modeSuffix = " (" .. distStr .. ")"
        end
    
        if acEnabled then
            acStatus.Text = "COPYING " .. acSelectedPlayer.Name .. modeSuffix
            acStatus.TextColor3 = C.green
            acStatusDot.BackgroundColor3 = C.green
        else
            acStatus.Text = "Selected: " .. acSelectedPlayer.Name .. modeSuffix
            acStatus.TextColor3 = C.accent
            acStatusDot.BackgroundColor3 = C.accent
        end
    end
    
    local function acUpdatePlayerList(term)
        for _, c in ipairs(acPlayerList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        term = (term or ""):lower()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local name = p.Name .. " (@" .. p.DisplayName .. ")"
                if term == "" or name:lower():find(term, 1, true) then
                    local btn = Instance.new("TextButton", acPlayerList)
                    btn.BackgroundColor3 = (acSelectedPlayer == p) and C.accent or C.bgCard
                    btn.BackgroundTransparency = (acSelectedPlayer == p) and 0.2 or 0.5
                    btn.BorderSizePixel = 0
                    btn.Size = UDim2.new(1, -6, 0, 24)
                    btn.Font = Enum.Font.GothamMedium
                    btn.Text = "  " .. name
                    btn.TextColor3 = (acSelectedPlayer == p) and Color3.fromRGB(8, 8, 10) or C.text
                    btn.TextSize = 9.5
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.AutoButtonColor = false
                    btn.TextTruncate = Enum.TextTruncate.AtEnd
                    applyCorner(btn, 4)
    
                    btn.MouseButton1Click:Connect(function()
                        acSelectedPlayer = p
                        for _, c2 in ipairs(acPlayerList:GetChildren()) do
                            if c2:IsA("TextButton") then
                                local isSel = (c2 == btn)
                                c2.BackgroundColor3 = isSel and C.accent or C.bgCard
                                c2.BackgroundTransparency = isSel and 0.2 or 0.5
                                c2.TextColor3 = isSel and Color3.fromRGB(8, 8, 10) or C.text
                            end
                        end
                        acUpdateStatusText()
                    end)
                end
            end
        end
    end
    
    local function acSetSideDistance(val)
        acSideDist = math.clamp(math.floor(val * 10 + 0.5) / 10, 0.0, 50.0)
        local pct = math.clamp(acSideDist / 50.0, 0, 1)
        acSideDistFill.Size = UDim2.new(pct, 0, 1, 0)
        acSideDistHandle.Position = UDim2.new(pct, 0, 0.5, 0)
        acSideBadge.Text = string.format("%.1f studs", acSideDist)
        acUpdateStatusText()
    end
    
    local function acSetForwardDistance(val)
        acForwardDist = math.clamp(math.floor(val * 10 + 0.5) / 10, 0.0, 50.0)
        local pct = math.clamp(acForwardDist / 50.0, 0, 1)
        acFwdDistFill.Size = UDim2.new(pct, 0, 1, 0)
        acFwdDistHandle.Position = UDim2.new(pct, 0, 0.5, 0)
        acFwdBadge.Text = string.format("%.1f studs", acForwardDist)
        acUpdateStatusText()
    end
    
    acSetSideDistance(2.0)
    acSetForwardDistance(2.0)
    
    acSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        acUpdatePlayerList(acSearchBox.Text)
    end)
    Players.PlayerAdded:Connect(function() task.wait(0.1); acUpdatePlayerList(acSearchBox.Text) end)
    Players.PlayerRemoving:Connect(function() task.wait(0.1); acUpdatePlayerList(acSearchBox.Text) end)
    
    acSideDistTrack.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            acSideDragging = true
            local pct = math.clamp((inp.Position.X - acSideDistTrack.AbsolutePosition.X) / acSideDistTrack.AbsoluteSize.X, 0, 1)
            acSetSideDistance(pct * 50)
        end
    end)
    acFwdDistTrack.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            acFwdDragging = true
            local pct = math.clamp((inp.Position.X - acFwdDistTrack.AbsolutePosition.X) / acFwdDistTrack.AbsoluteSize.X, 0, 1)
            acSetForwardDistance(pct * 50)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            acSideDragging = false
            acFwdDragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            if acSideDragging then
                local pct = math.clamp((inp.Position.X - acSideDistTrack.AbsolutePosition.X) / acSideDistTrack.AbsoluteSize.X, 0, 1)
                acSetSideDistance(pct * 50)
            elseif acFwdDragging then
                local pct = math.clamp((inp.Position.X - acFwdDistTrack.AbsolutePosition.X) / acFwdDistTrack.AbsoluteSize.X, 0, 1)
                acSetForwardDistance(pct * 50)
            end
        end
    end)
    
    local function acUpdateSideButtons()
        local function setBtnActive(btn, active)
            btn.BackgroundColor3 = active and C.accent or C.surface
            btn.TextColor3 = active and Color3.fromRGB(8, 8, 10) or C.textDim
        end
        setBtnActive(acSideLeft, acSideMode == "Left")
        setBtnActive(acSideRight, acSideMode == "Right")
        setBtnActive(acSideFront, acForwardMode == "Front")
        setBtnActive(acSideBack, acForwardMode == "Back")
    end
    
    acSideLeft.MouseButton1Click:Connect(function()
        acSideMode = (acSideMode == "Left") and nil or "Left"
        acUpdateSideButtons()
        acUpdateStatusText()
    end)
    acSideRight.MouseButton1Click:Connect(function()
        acSideMode = (acSideMode == "Right") and nil or "Right"
        acUpdateSideButtons()
        acUpdateStatusText()
    end)
    acSideFront.MouseButton1Click:Connect(function()
        acForwardMode = (acForwardMode == "Front") and nil or "Front"
        acUpdateSideButtons()
        acUpdateStatusText()
    end)
    acSideBack.MouseButton1Click:Connect(function()
        acForwardMode = (acForwardMode == "Back") and nil or "Back"
        acUpdateSideButtons()
        acUpdateStatusText()
    end)
    
    -- Copier Freeze / Unfreeze
    local function acFreezeClone(clone)
        if not clone then return end
        acSavedStates = {}
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                if not part:FindFirstAncestorOfClass("Accessory") then
                    acSavedStates[part] = {
                        Anchored = part.Anchored,
                        CanCollide = part.CanCollide,
                    }
                    part.Anchored = not acFreeRoam
                    part.CanCollide = false
                end
            end
        end
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then
            acSavedStates.Humanoid = {
                WalkSpeed = hum.WalkSpeed,
                JumpPower = hum.JumpPower,
                AutoRotate = hum.AutoRotate,
            }
            if not acFreeRoam then
                hum.WalkSpeed = 0
                hum.JumpPower = 0
                hum.AutoRotate = false
            else
                hum.AutoRotate = true
                if hum.WalkSpeed <= 0 then hum.WalkSpeed = 16 end
            end
        end
    end
    
    local function acUnfreezeClone(clone)
        if not clone then return end
        for part, state in pairs(acSavedStates) do
            if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
                if state.Anchored ~= nil then pcall(function() part.Anchored = state.Anchored end) end
                pcall(function() part.CanCollide = state.CanCollide end)
            end
        end
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum and acSavedStates.Humanoid then
            pcall(function() hum.WalkSpeed = acSavedStates.Humanoid.WalkSpeed end)
            pcall(function() hum.JumpPower = acSavedStates.Humanoid.JumpPower end)
            pcall(function() hum.AutoRotate = acSavedStates.Humanoid.AutoRotate end)
        end
        acSavedStates = {}
    end
    
    local r15ToR6Map = {
        ["Torso"] = {"UpperTorso", "LowerTorso"},
        ["Right Arm"] = {"RightUpperArm", "RightLowerArm", "RightHand"},
        ["Left Arm"] = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
        ["Right Leg"] = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
        ["Left Leg"] = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
        ["UpperTorso"] = {"Torso"},
        ["LowerTorso"] = {"Torso"},
        ["RightUpperArm"] = {"Right Arm"},
        ["LeftUpperArm"] = {"Left Arm"},
        ["RightUpperLeg"] = {"Right Leg"},
        ["LeftUpperLeg"] = {"Left Leg"},
    }
    
    local function getTargetPart(char, partName)
        if not char then return nil end
        local p = char:FindFirstChild(partName)
        if p and p:IsA("BasePart") then return p end
        local alts = r15ToR6Map[partName]
        if alts then
            for _, alt in ipairs(alts) do
                local ap = char:FindFirstChild(alt)
                if ap and ap:IsA("BasePart") then return ap end
            end
        end
        return nil
    end
    
    local function acStartCopying()
        if acConn then acConn:Disconnect(); acConn = nil end
    
        local clone = api and api.get_clone and api.get_clone(lp)
        acFreezeClone(clone)
    
        local clonePartMap = {}
        if clone then
            for _, part in ipairs(clone:GetDescendants()) do
                if part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Accessory") then
                    clonePartMap[part.Name] = part
                end
            end
        end
    
        acConn = RunService.Stepped:Connect(function()
            if not acEnabled or not acSelectedPlayer then return end
            if not (api and api.is_reanimated and api.is_reanimated()) then return end
    
            local cloneChar = api.get_clone(lp)
            if not cloneChar then return end
    
            local targetChar = acSelectedPlayer.Character
            local targetHRP = targetChar and (targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso"))
            if not targetHRP then return end
    
            if acFreeRoam then
                -- FreeRoam Mode: sync motor transforms
                for _, d in ipairs(cloneChar:GetDescendants()) do
                    if d:IsA("Motor6D") and d.Part0 and d.Part1 then
                        local tP0 = getTargetPart(targetChar, d.Part0.Name)
                        local tP1 = getTargetPart(targetChar, d.Part1.Name)
                        if tP0 and tP1 then
                            local relCF = tP0.CFrame:Inverse() * tP1.CFrame
                            pcall(function()
                                d.Transform = d.C0:Inverse() * relCF * d.C1
                            end)
                        end
                    end
                end
            elseif acFreeze then
                -- Freeze Mode: stay on spot, match rotation
                if not acFrozenPos then
                    local myHRP = cloneChar:FindFirstChild("HumanoidRootPart") or cloneChar:FindFirstChild("Torso")
                    acFrozenPos = myHRP and myHRP.Position or targetHRP.Position
                end
                local rootCF = CFrame.new(acFrozenPos) * targetHRP.CFrame.Rotation
                for _, tPart in ipairs(targetChar:GetDescendants()) do
                    if tPart:IsA("BasePart") and not tPart:FindFirstAncestorOfClass("Accessory") then
                        local cPart = clonePartMap[tPart.Name] or cloneChar:FindFirstChild(tPart.Name)
                        if cPart and cPart:IsA("BasePart") then
                            local rel = targetHRP.CFrame:Inverse() * tPart.CFrame
                            cPart.CFrame = rootCF * rel
                        end
                    end
                end
            else
                -- Follow Mode: offset from target
                local rVec = targetHRP.CFrame.RightVector
                local lVec = targetHRP.CFrame.LookVector
                local sOff = Vector3.zero
                if acSideMode == "Left" then sOff = -rVec * acSideDist
                elseif acSideMode == "Right" then sOff = rVec * acSideDist end
    
                local fOff = Vector3.zero
                if acForwardMode == "Front" then fOff = lVec * acForwardDist
                elseif acForwardMode == "Back" then fOff = -lVec * acForwardDist end
    
                local rootCF = CFrame.new(targetHRP.Position + sOff + fOff) * targetHRP.CFrame.Rotation
                for _, tPart in ipairs(targetChar:GetDescendants()) do
                    if tPart:IsA("BasePart") and not tPart:FindFirstAncestorOfClass("Accessory") then
                        local cPart = clonePartMap[tPart.Name] or cloneChar:FindFirstChild(tPart.Name)
                        if cPart and cPart:IsA("BasePart") then
                            local rel = targetHRP.CFrame:Inverse() * tPart.CFrame
                            cPart.CFrame = rootCF * rel
                        end
                    end
                end
            end
        end)
    end
    
    local function acStopCopying()
        if acConn then acConn:Disconnect(); acConn = nil end
        local clone = api and api.get_clone and api.get_clone(lp)
        acUnfreezeClone(clone)
        acFrozenPos = nil
        acUpdateStatusText()
    end
    
    acMasterBtn.MouseButton1Click:Connect(function()
        acEnabled = not acEnabled
        updateEternityToggleVisual(acMasterTrack, acMasterKnob, acMasterGlow, acEnabled, true)
        if acEnabled then
            acStartCopying()
        else
            acStopCopying()
        end
        acUpdateStatusText()
    end)
    
    acFreezeBtn.MouseButton1Click:Connect(function()
        acFreeze = not acFreeze
        if acFreeze and acFreeRoam then
            acFreeRoam = false
            updateEternityToggleVisual(acFreeRoamTrack, acFreeRoamKnob, acFreeRoamGlow, false, true)
        end
        updateEternityToggleVisual(acFreezeTrack, acFreezeKnob, acFreezeGlow, acFreeze, true)
        if not acFreeze then acFrozenPos = nil end
        if acEnabled then acStartCopying() end
        acUpdateStatusText()
    end)
    
    acFreeRoamBtn.MouseButton1Click:Connect(function()
        acFreeRoam = not acFreeRoam
        if acFreeRoam and acFreeze then
            acFreeze = false
            acFrozenPos = nil
            updateEternityToggleVisual(acFreezeTrack, acFreezeKnob, acFreezeGlow, false, true)
        end
        updateEternityToggleVisual(acFreeRoamTrack, acFreeRoamKnob, acFreeRoamGlow, acFreeRoam, true)
        if acEnabled then acStartCopying() end
        acUpdateStatusText()
    end)
    
    task.defer(function()
        acUpdatePlayerList("")
        acUpdateSideButtons()
        acUpdateStatusText()
    end)
    
    

    return copierPanel
end


-- ═══════════════════════════════════════════════════
-- BUILDER: TRACKING TAB (Head, Arms & Torso Cam - NO FAKE VR)
-- ═══════════════════════════════════════════════════
local function buildTrackingPanel(parent)
    local lp = player or Players.LocalPlayer
    -- ═══════════════════════════════════════════════════
    -- PANEL 7: TRACKING TAB (Head, Arms & Torso Cam - NO FAKE VR)
    -- ═══════════════════════════════════════════════════
    local trackingPanel = Instance.new("ScrollingFrame")
    trackingPanel.Size = UDim2.new(1, 0, 1, 0)
    trackingPanel.BackgroundTransparency = 1
    trackingPanel.BorderSizePixel = 0
    trackingPanel.ScrollBarThickness = 3
    trackingPanel.ScrollBarImageColor3 = C.accent
    trackingPanel.ScrollBarImageTransparency = 0.6
    pcall(function() trackingPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    trackingPanel.CanvasSize = UDim2.new(0, 0, 0, 400)
    trackingPanel.Visible = false
    trackingPanel.Parent = parent
    
    local trackingPadding = Instance.new("UIPadding", trackingPanel)
    trackingPadding.PaddingLeft = UDim.new(0, 2)
    trackingPadding.PaddingRight = UDim.new(0, 4)
    trackingPadding.PaddingTop = UDim.new(0, 2)
    trackingPadding.PaddingBottom = UDim.new(0, 14)
    
    local trackingLayout = Instance.new("UIListLayout", trackingPanel)
    trackingLayout.Padding = UDim.new(0, 8)
    trackingLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local trackingHeader = Instance.new("TextLabel", trackingPanel)
    trackingHeader.Size = UDim2.new(1, 0, 0, 16)
    trackingHeader.BackgroundTransparency = 1
    trackingHeader.Text = "HEAD & LIMB TRACKING"
    trackingHeader.TextColor3 = C.textMuted
    trackingHeader.Font = Enum.Font.GothamBold
    trackingHeader.TextSize = 10
    trackingHeader.TextXAlignment = Enum.TextXAlignment.Left
    trackingHeader.LayoutOrder = 1
    
    -- Tracking Global States
    _G._HaloHeadTrackerEnabled = false
    _G._HaloLeftArmPointerEnabled = false
    _G._HaloRightArmPointerEnabled = false
    _G._HaloLimbsTorsoCamControl = false
    _G._HaloLimbsTorsoCamMode = "Follow Camera"
    
    -- State tracking forward declaration
    
    -- Card 1: Torso Camera Control
    local tccCard = Instance.new("Frame", trackingPanel)
    tccCard.Size = UDim2.new(1, 0, 0, 72)
    tccCard.BackgroundColor3 = C.bgCard
    tccCard.LayoutOrder = 2
    applyCorner(tccCard, 8)
    applyStroke(tccCard, C.divider, 1, 0)
    
    local tccTitle = Instance.new("TextLabel", tccCard)
    tccTitle.Size = UDim2.new(1, -70, 0, 16)
    tccTitle.Position = UDim2.new(0, 12, 0, 6)
    tccTitle.BackgroundTransparency = 1
    tccTitle.Text = "Torso Camera Control"
    tccTitle.TextColor3 = C.text
    tccTitle.Font = Enum.Font.GothamBold
    tccTitle.TextSize = 10.5
    tccTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local tccSub = Instance.new("TextLabel", tccCard)
    tccSub.Size = UDim2.new(1, -70, 0, 14)
    tccSub.Position = UDim2.new(0, 12, 0, 22)
    tccSub.BackgroundTransparency = 1
    tccSub.Text = "Lean and turn body with camera look direction"
    tccSub.TextColor3 = C.textMuted
    tccSub.Font = Enum.Font.GothamMedium
    tccSub.TextSize = 8.5
    tccSub.TextXAlignment = Enum.TextXAlignment.Left
    
    local tccTrack, tccKnob, tccGlow = createEternityToggleSwitch(tccCard, -54, -20)
    local tccBtn = Instance.new("TextButton", tccTrack)
    tccBtn.Size = UDim2.new(1, 0, 1, 0)
    tccBtn.BackgroundTransparency = 1
    tccBtn.Text = ""
    
    -- Mode Row for Torso Cam
    local tccModeRow = Instance.new("Frame", tccCard)
    tccModeRow.Position = UDim2.new(0, 10, 0, 42)
    tccModeRow.Size = UDim2.new(1, -20, 0, 22)
    tccModeRow.BackgroundTransparency = 1
    
    local tccModes = { "Follow Camera", "Pitch Only", "Locked" }
    local tccModeButtons = {}
    for idx, mName in ipairs(tccModes) do
        local mBtn = Instance.new("TextButton", tccModeRow)
        mBtn.Size = UDim2.new(0.315, 0, 1, 0)
        mBtn.Position = UDim2.new((idx - 1) * 0.342, 0, 0, 0)
        mBtn.BackgroundColor3 = (mName == _G._HaloLimbsTorsoCamMode) and C.accent or C.surface
        mBtn.Text = mName
        mBtn.TextColor3 = (mName == _G._HaloLimbsTorsoCamMode) and Color3.fromRGB(8, 8, 10) or C.textDim
        mBtn.Font = Enum.Font.GothamBold
        mBtn.TextSize = 8.5
        applyCorner(mBtn, 4)
        tccModeButtons[mName] = mBtn
    
        mBtn.MouseButton1Click:Connect(function()
            _G._HaloLimbsTorsoCamMode = mName
            for k, b in pairs(tccModeButtons) do
                local isAct = (k == mName)
                b.BackgroundColor3 = isAct and C.accent or C.surface
                b.TextColor3 = isAct and Color3.fromRGB(8, 8, 10) or C.textDim
            end
        end)
    end
    
    tccBtn.MouseButton1Click:Connect(function()
        _G._HaloLimbsTorsoCamControl = not _G._HaloLimbsTorsoCamControl
        updateEternityToggleVisual(tccTrack, tccKnob, tccGlow, _G._HaloLimbsTorsoCamControl, true)
        updateTrackingEngineState()
    end)
    
    -- Helper: Keybindable Toggle Card for Tracking
    currentlyBindingTracking = nil
    local function createTrackingToggleCard(title, subtitle, bindKeyName, onToggleChanged, layoutOrder)
        local card = Instance.new("Frame", trackingPanel)
        card.Size = UDim2.new(1, 0, 0, 46)
        card.BackgroundColor3 = C.bgCard
        card.LayoutOrder = layoutOrder
        applyCorner(card, 8)
        applyStroke(card, C.divider, 1, 0)
    
        local tLbl = Instance.new("TextLabel", card)
        tLbl.Size = UDim2.new(1, -125, 0, 16)
        tLbl.Position = UDim2.new(0, 12, 0, 6)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = title
        tLbl.TextColor3 = C.text
        tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 10.5
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
    
        local sLbl = Instance.new("TextLabel", card)
        sLbl.Size = UDim2.new(1, -125, 0, 14)
        sLbl.Position = UDim2.new(0, 12, 0, 24)
        sLbl.BackgroundTransparency = 1
        sLbl.Text = subtitle
        sLbl.TextColor3 = C.textMuted
        sLbl.Font = Enum.Font.GothamMedium
        sLbl.TextSize = 8.5
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
    
        -- Keybind Button
        local curKey = savedConfig.trackingBinds and savedConfig.trackingBinds[bindKeyName]
        local bindBtn = Instance.new("TextButton", card)
        bindBtn.Size = UDim2.new(0, 48, 0, 22)
        bindBtn.Position = UDim2.new(1, -112, 0.5, -11)
        bindBtn.BackgroundColor3 = C.surface
        bindBtn.Text = curKey and ("[" .. curKey .. "]") or "[None]"
        bindBtn.TextColor3 = curKey and C.accent or C.textMuted
        bindBtn.Font = Enum.Font.GothamBold
        bindBtn.TextSize = 8.5
        applyCorner(bindBtn, 6)
        applyStroke(bindBtn, C.border, 1, 0.3)
    
        bindBtn.MouseButton1Click:Connect(function()
            if currentlyBindingTracking == bindKeyName then
                currentlyBindingTracking = nil
                local k = savedConfig.trackingBinds and savedConfig.trackingBinds[bindKeyName]
                bindBtn.Text = k and ("[" .. k .. "]") or "[None]"
                bindBtn.TextColor3 = k and C.accent or C.textMuted
            else
                currentlyBindingTracking = bindKeyName
                bindBtn.Text = "[...]"
                bindBtn.TextColor3 = Color3.fromRGB(255, 200, 80)
            end
        end)
    
        local track, knob, glow = createEternityToggleSwitch(card, -54, -11)
        local btn = Instance.new("TextButton", track)
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
    
        local isToggled = false
        btn.MouseButton1Click:Connect(function()
            isToggled = not isToggled
            updateEternityToggleVisual(track, knob, glow, isToggled, true)
            onToggleChanged(isToggled)
            updateTrackingEngineState()
        end)
    
        return {
            setToggled = function(val)
                isToggled = val
                updateEternityToggleVisual(track, knob, glow, isToggled, true)
                onToggleChanged(isToggled)
                updateTrackingEngineState()
            end,
            updateKeyUI = function()
                local k = savedConfig.trackingBinds and savedConfig.trackingBinds[bindKeyName]
                bindBtn.Text = k and ("[" .. k .. "]") or "[None]"
                bindBtn.TextColor3 = k and C.accent or C.textMuted
            end
        }
    end
    
    -- Card 2: Head Tracker
    htCardUI = createTrackingToggleCard("Head Tracker", "Head turns realistically toward camera", "HeadTracker", function(state)
        _G._HaloHeadTrackerEnabled = state
    end, 3)
    
    -- Card 3: Left Arm Pointer
    laCardUI = createTrackingToggleCard("Left Arm Pointer", "Left arm aims straight at mouse cursor", "LeftArm", function(state)
        _G._HaloLeftArmPointerEnabled = state
    end, 4)
    
    -- Card 4: Right Arm Pointer
    raCardUI = createTrackingToggleCard("Right Arm Pointer", "Right arm aims straight at mouse cursor", "RightArm", function(state)
        _G._HaloRightArmPointerEnabled = state
    end, 5)
    
    

    return trackingPanel
end


-- ═══════════════════════════════════════════════════
-- BUILDER: STRETCHING TAB (Torso, Legs & Arms)
-- ═══════════════════════════════════════════════════
local function buildStretchingPanel(parent)
    local lp = player or Players.LocalPlayer
    -- ═══════════════════════════════════════════════════
    -- PANEL 8: STRETCHING TAB (Torso, Legs & Arms)
    -- ═══════════════════════════════════════════════════
    local stretchingPanel = Instance.new("ScrollingFrame")
    stretchingPanel.Size = UDim2.new(1, 0, 1, 0)
    stretchingPanel.BackgroundTransparency = 1
    stretchingPanel.BorderSizePixel = 0
    stretchingPanel.ScrollBarThickness = 3
    stretchingPanel.ScrollBarImageColor3 = C.accent
    stretchingPanel.ScrollBarImageTransparency = 0.6
    pcall(function() stretchingPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    stretchingPanel.CanvasSize = UDim2.new(0, 0, 0, 360)
    stretchingPanel.Visible = false
    stretchingPanel.Parent = parent
    
    local stretchingPadding = Instance.new("UIPadding", stretchingPanel)
    stretchingPadding.PaddingLeft = UDim.new(0, 2)
    stretchingPadding.PaddingRight = UDim.new(0, 4)
    stretchingPadding.PaddingTop = UDim.new(0, 2)
    stretchingPadding.PaddingBottom = UDim.new(0, 14)
    
    local stretchingLayout = Instance.new("UIListLayout", stretchingPanel)
    stretchingLayout.Padding = UDim.new(0, 8)
    stretchingLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local stretchingHeader = Instance.new("TextLabel", stretchingPanel)
    stretchingHeader.Size = UDim2.new(1, 0, 0, 16)
    stretchingHeader.BackgroundTransparency = 1
    stretchingHeader.Text = "LIMB & TORSO STRETCHING"
    stretchingHeader.TextColor3 = C.textMuted
    stretchingHeader.Font = Enum.Font.GothamBold
    stretchingHeader.TextSize = 10
    stretchingHeader.TextXAlignment = Enum.TextXAlignment.Left
    stretchingHeader.LayoutOrder = 1
    
    -- Stretching States
    _G._HaloTorsoStretcherEnabled = false
    _G._HaloLegStretcherEnabled = false
    _G._HaloLeftArmStretching = false
    _G._HaloRightArmStretching = false
    _G._HaloLimbsUpperTorsoHeight = 1.0
    _G._HaloLimbsLegHeight = 1.0
    _G._HaloArmStretchAmount = 2.5
    
    -- Helper: Create Slider Card for Stretching
    local function createStretchSliderCard(title, subtitle, defaultVal, minVal, maxVal, unitStr, onToggleChanged, onValChanged, layoutOrder)
        local card = Instance.new("Frame", stretchingPanel)
        card.Size = UDim2.new(1, 0, 0, 72)
        card.BackgroundColor3 = C.bgCard
        card.LayoutOrder = layoutOrder
        applyCorner(card, 8)
        applyStroke(card, C.divider, 1, 0)
    
        local tLbl = Instance.new("TextLabel", card)
        tLbl.Size = UDim2.new(1, -70, 0, 16)
        tLbl.Position = UDim2.new(0, 12, 0, 6)
        tLbl.BackgroundTransparency = 1
        tLbl.Text = title
        tLbl.TextColor3 = C.text
        tLbl.Font = Enum.Font.GothamBold
        tLbl.TextSize = 10.5
        tLbl.TextXAlignment = Enum.TextXAlignment.Left
    
        local sLbl = Instance.new("TextLabel", card)
        sLbl.Size = UDim2.new(1, -70, 0, 14)
        sLbl.Position = UDim2.new(0, 12, 0, 22)
        sLbl.BackgroundTransparency = 1
        sLbl.Text = subtitle
        sLbl.TextColor3 = C.textMuted
        sLbl.Font = Enum.Font.GothamMedium
        sLbl.TextSize = 8.5
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
    
        local badge = Instance.new("TextLabel", card)
        badge.Size = UDim2.new(0, 64, 0, 16)
        badge.Position = UDim2.new(1, -128, 0, 6)
        badge.BackgroundColor3 = C.surface
        badge.Text = string.format("%.1f%s", defaultVal, unitStr)
        badge.TextColor3 = C.accent
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 8.5
        applyCorner(badge, 4)
        applyStroke(badge, C.divider, 1, 0)
    
        local track, knob, glow = createEternityToggleSwitch(card, -54, -20)
        local btn = Instance.new("TextButton", track)
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
    
        local sliderTrack = Instance.new("Frame", card)
        sliderTrack.Position = UDim2.new(0, 12, 0, 48)
        sliderTrack.Size = UDim2.new(1, -24, 0, 6)
        sliderTrack.BackgroundColor3 = C.surface
        applyCorner(sliderTrack, 3)
    
        local initPct = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
        local sliderFill = Instance.new("Frame", sliderTrack)
        sliderFill.Size = UDim2.new(initPct, 0, 1, 0)
        sliderFill.BackgroundColor3 = C.accent
        applyCorner(sliderFill, 3)
    
        local sliderHandle = Instance.new("Frame", sliderTrack)
        sliderHandle.AnchorPoint = Vector2.new(0.5, 0.5)
        sliderHandle.Position = UDim2.new(initPct, 0, 0.5, 0)
        sliderHandle.Size = UDim2.new(0, 12, 0, 12)
        sliderHandle.BackgroundColor3 = C.text
        applyCorner(sliderHandle, 6)
    
        local isEnabled = false
        btn.MouseButton1Click:Connect(function()
            isEnabled = not isEnabled
            updateEternityToggleVisual(track, knob, glow, isEnabled, true)
            onToggleChanged(isEnabled)
            updateTrackingEngineState()
        end)
    
        local dragging = false
        local function setValFromPct(pct)
            local val = minVal + pct * (maxVal - minVal)
            val = math.floor(val * 10 + 0.5) / 10
            pct = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
            sliderFill.Size = UDim2.new(pct, 0, 1, 0)
            sliderHandle.Position = UDim2.new(pct, 0, 0.5, 0)
            badge.Text = string.format("%.1f%s", val, unitStr)
            onValChanged(val)
        end
    
        sliderTrack.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local pct = math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
                setValFromPct(pct)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local pct = math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
                setValFromPct(pct)
            end
        end)
    end
    
    -- Card 1: Torso Stretcher
    createStretchSliderCard("Torso Stretcher", "Scales UpperTorso height along spine", 1.0, 0.4, 25.0, "x", function(state)
        _G._HaloTorsoStretcherEnabled = state
    end, function(v)
        _G._HaloLimbsUpperTorsoHeight = v
    end, 2)
    
    -- Card 2: Leg Stretcher
    createStretchSliderCard("Leg Stretcher", "Scales leg length and adjusts HipHeight", 1.0, 0.4, 25.0, "x", function(state)
        _G._HaloLegStretcherEnabled = state
    end, function(v)
        _G._HaloLimbsLegHeight = v
    end, 3)
    
    -- Card 3: Arm Stretch
    createStretchSliderCard("Arm Stretch", "Scales arm bone length toward aim direction", 2.5, 0.5, 50.0, "x", function(state)
        _G._HaloLeftArmStretching = state
        _G._HaloRightArmStretching = state
    end, function(v)
        _G._HaloArmStretchAmount = v
    end, 4)
    
    

    return stretchingPanel
end

-- ═══════════════════════════════════════════════════
-- BUILDER: STUDIO TAB (Eternity Studio Sequencer Launcher)
-- ═══════════════════════════════════════════════════
local function buildStudioPanel(parent)
    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 3
    panel.ScrollBarImageColor3 = C.accent
    panel.ScrollBarImageTransparency = 0.6
    pcall(function() panel.AutomaticCanvasSize = Enum.AutomaticSize.Y end)
    panel.CanvasSize = UDim2.new(0, 0, 0, 480)
    panel.Visible = false
    panel.Parent = parent

    local padding = Instance.new("UIPadding", panel)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingTop = UDim.new(0, 2)
    padding.PaddingBottom = UDim.new(0, 14)

    local layout = Instance.new("UIListLayout", panel)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local header = Instance.new("TextLabel", panel)
    header.Size = UDim2.new(1, 0, 0, 16)
    header.BackgroundTransparency = 1
    header.Text = "ETERNITY STUDIO"
    header.TextColor3 = C.textMuted
    header.Font = Enum.Font.GothamBold
    header.TextSize = 10
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.LayoutOrder = 1

    -- Card 1: Master Studio Launch / Toggle Card
    local masterCard = Instance.new("Frame", panel)
    masterCard.Size = UDim2.new(1, 0, 0, 92)
    masterCard.BackgroundColor3 = C.bgCard
    masterCard.LayoutOrder = 2
    applyCorner(masterCard, 8)
    applyStroke(masterCard, C.divider, 1, 0)

    local titleLbl = Instance.new("TextLabel", masterCard)
    titleLbl.Size = UDim2.new(1, -120, 0, 18)
    titleLbl.Position = UDim2.new(0, 12, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Timeline Sequencer & Video Editor"
    titleLbl.TextColor3 = C.text
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local descLbl = Instance.new("TextLabel", masterCard)
    descLbl.Size = UDim2.new(1, -120, 0, 14)
    descLbl.Position = UDim2.new(0, 12, 0, 26)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = "Multi-clip sequencing, avatar scrubbing & export suite"
    descLbl.TextColor3 = C.textMuted
    descLbl.Font = Enum.Font.GothamMedium
    descLbl.TextSize = 8.5
    descLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Live Status Badge
    local statusBadge = Instance.new("TextLabel", masterCard)
    statusBadge.Size = UDim2.new(0, 96, 0, 18)
    statusBadge.Position = UDim2.new(1, -108, 0, 8)
    statusBadge.BackgroundColor3 = C.surface
    statusBadge.Text = "CLOSED"
    statusBadge.TextColor3 = C.textMuted
    statusBadge.Font = Enum.Font.GothamBold
    statusBadge.TextSize = 8.5
    applyCorner(statusBadge, 4)
    applyStroke(statusBadge, C.divider, 1, 0)

    -- Launch / Toggle Button
    local launchBtn = Instance.new("TextButton", masterCard)
    launchBtn.Size = UDim2.new(0.68, -16, 0, 32)
    launchBtn.Position = UDim2.new(0, 12, 0, 48)
    launchBtn.BackgroundColor3 = C.accent
    launchBtn.Text = "LAUNCH ETERNITY STUDIO"
    launchBtn.TextColor3 = Color3.fromRGB(8, 8, 10)
    launchBtn.Font = Enum.Font.GothamBold
    launchBtn.TextSize = 9.5
    launchBtn.AutoButtonColor = false
    applyCorner(launchBtn, 6)

    local resetBtn = Instance.new("TextButton", masterCard)
    resetBtn.Size = UDim2.new(0.32, -8, 0, 32)
    resetBtn.Position = UDim2.new(0.68, 0, 0, 48)
    resetBtn.BackgroundColor3 = C.surface
    resetBtn.Text = "RELOAD"
    resetBtn.TextColor3 = C.textDim
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 9
    resetBtn.AutoButtonColor = false
    applyCorner(resetBtn, 6)
    applyStroke(resetBtn, C.divider, 1, 0)

    local function updateStatus()
        local open = (api and api.is_studio_open and api.is_studio_open()) or (CoreGui:FindFirstChild("EternityStudioTimelineEditor") and CoreGui.EternityStudioTimelineEditor.Enabled)
        if open then
            statusBadge.Text = "ACTIVE"
            statusBadge.TextColor3 = C.green
            launchBtn.Text = "CLOSE STUDIO"
            launchBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
            launchBtn.TextColor3 = C.text
        else
            statusBadge.Text = "CLOSED"
            statusBadge.TextColor3 = C.textMuted
            launchBtn.Text = "LAUNCH ETERNITY STUDIO"
            launchBtn.BackgroundColor3 = C.accent
            launchBtn.TextColor3 = Color3.fromRGB(8, 8, 10)
        end
    end

    launchBtn.MouseButton1Click:Connect(function()
        if api and api.toggle_studio then
            api.toggle_studio()
        else
            local existing = CoreGui:FindFirstChild("EternityStudioTimelineEditor")
            if existing then
                existing.Enabled = not existing.Enabled
            else
                pcall(function()
                    if isfile and isfile("EternityStudio.lua") then
                        loadstring(readfile("EternityStudio.lua"))()
                    elseif isfile and isfile("EternityStudio") then
                        loadstring(readfile("EternityStudio"))()
                    else
                        loadstring(game:HttpGet("https://raw.githubusercontent.com/hor1zencodes/idk/main/EternityStudio.lua"))()
                    end
                end)
            end
        end
        task.wait(0.1)
        updateStatus()
    end)

    resetBtn.MouseButton1Click:Connect(function()
        local existing = CoreGui:FindFirstChild("EternityStudioTimelineEditor")
        if existing then existing:Destroy() end
        task.wait(0.05)
        pcall(function()
            if isfile and isfile("EternityStudio.lua") then
                loadstring(readfile("EternityStudio.lua"))()
            elseif isfile and isfile("EternityStudio") then
                loadstring(readfile("EternityStudio"))()
            else
                loadstring(game:HttpGet("https://raw.githubusercontent.com/hor1zencodes/idk/main/EternityStudio.lua"))()
            end
        end)
        task.wait(0.1)
        updateStatus()
    end)

    local function createFeatureCard(title, desc, badgeTxt, iconTxt, order)
        local c = Instance.new("Frame", panel)
        c.Size = UDim2.new(1, 0, 0, 50)
        c.BackgroundColor3 = C.bgCard
        c.LayoutOrder = order
        applyCorner(c, 8)
        applyStroke(c, C.divider, 1, 0)

        local ic = Instance.new("TextLabel", c)
        ic.Size = UDim2.new(0, 36, 1, 0)
        ic.Position = UDim2.new(0, 6, 0, 0)
        ic.BackgroundTransparency = 1
        ic.Text = iconTxt
        ic.TextColor3 = C.accent
        ic.Font = Enum.Font.GothamBold
        ic.TextSize = 14

        local t = Instance.new("TextLabel", c)
        t.Size = UDim2.new(1, -120, 0, 16)
        t.Position = UDim2.new(0, 42, 0, 8)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = C.text
        t.Font = Enum.Font.GothamBold
        t.TextSize = 10
        t.TextXAlignment = Enum.TextXAlignment.Left

        local d = Instance.new("TextLabel", c)
        d.Size = UDim2.new(1, -50, 0, 14)
        d.Position = UDim2.new(0, 42, 0, 26)
        d.BackgroundTransparency = 1
        d.Text = desc
        d.TextColor3 = C.textMuted
        d.Font = Enum.Font.GothamMedium
        d.TextSize = 8.5
        d.TextXAlignment = Enum.TextXAlignment.Left

        local b = Instance.new("TextLabel", c)
        b.Size = UDim2.new(0, 64, 0, 16)
        b.Position = UDim2.new(1, -74, 0, 8)
        b.BackgroundColor3 = C.surface
        b.Text = badgeTxt
        b.TextColor3 = C.accent
        b.Font = Enum.Font.GothamBold
        b.TextSize = 8
        applyCorner(b, 4)
        applyStroke(b, C.divider, 1, 0)

        return c
    end

    createFeatureCard("Multi-Track Timeline Sequencer", "Drag, position, loop & re-time sequential animation clips", "Sequencer", ">", 3)
    createFeatureCard("Real-Time Avatar Playhead Scrubbing", "Scrub time across tracks to view character pose frame-by-frame", "Pose Sync", "O", 4)
    createFeatureCard("Precision Clip Trimming & Splitting", "Non-destructive in/out trimming with split point markers", "Trimmer", "/", 5)
    createFeatureCard("One-Click Merge & Catalog Export", "Merge tracks to single Lua file; auto-saves into Custom tab", "Catalog", "+", 6)

    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        if panel.Visible then
            updateStatus()
        end
    end)

    return panel
end



-- ═══════════════════════════════════════════════════
-- BUILDER: TRACKING & STRETCHING RUNTIME ENGINE
-- ═══════════════════════════════════════════════════
local function initTrackingAndStretchingEngine()
    local lp = player or Players.LocalPlayer
    -- ═══════════════════════════════════════════════════
    -- TRACKING & STRETCHING RUNTIME ENGINE (Stepped Loop)
    -- ═══════════════════════════════════════════════════
    local trackingConn = nil
    local headSmoothedCF = nil
    local torsoCamSmoothedCF = nil
    
    updateTrackingEngineState = function()
        local needsEngine = _G._HaloHeadTrackerEnabled
            or _G._HaloLeftArmPointerEnabled
            or _G._HaloRightArmPointerEnabled
            or _G._HaloLimbsTorsoCamControl
            or _G._HaloTorsoStretcherEnabled
            or _G._HaloLegStretcherEnabled
            or _G._HaloLeftArmStretching
            or _G._HaloRightArmStretching
    
        if not needsEngine then
            if trackingConn then trackingConn:Disconnect(); trackingConn = nil end
            headSmoothedCF = nil
            torsoCamSmoothedCF = nil
            return
        end
    
        if trackingConn then return end
    
        trackingConn = RunService.Stepped:Connect(function()
            if not (api and api.is_reanimated and api.is_reanimated()) then return end
            local clone = api.get_clone(lp)
            if not clone then return end
    
            local camera = workspace.CurrentCamera
            local mouse = lp:GetMouse()
    
            -- 1. Head Tracker: Realistic smooth neck tracking (clamped yaw 75°, pitch 55°)
            if _G._HaloHeadTrackerEnabled and camera then
                local neck = nil
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("Motor6D") and (d.Name == "Neck" or d.Part1 and d.Part1.Name == "Head") then
                        neck = d
                        break
                    end
                end
                if neck and neck.Part0 then
                    local parentCF = neck.Part0.CFrame * neck.C0
                    local camLook = camera.CFrame.LookVector
                    local localLook = parentCF.Rotation:Inverse() * camLook
                    local yaw = math.clamp(math.atan2(localLook.X, -localLook.Z), -math.rad(75), math.rad(75))
                    local pitch = math.clamp(math.asin(math.clamp(localLook.Y, -1, 1)), -math.rad(55), math.rad(55))
                    local targetDir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)).Unit
                    local bindDir = Vector3.new(0, 0, -1)
                    local rotAxis = bindDir:Cross(targetDir)
                    local targetCF = CFrame.new()
                    if rotAxis.Magnitude > 0.001 then
                        local angle = math.acos(math.clamp(bindDir:Dot(targetDir), -1, 1))
                        targetCF = CFrame.fromAxisAngle(rotAxis.Unit, angle)
                    end
                    headSmoothedCF = headSmoothedCF and headSmoothedCF:Lerp(targetCF, 0.18) or targetCF
                    neck.Transform = headSmoothedCF
                end
            end
    
            -- 2. Arm Pointers: Left & Right aim straight at 3D mouse cursor
            if (_G._HaloLeftArmPointerEnabled or _G._HaloRightArmPointerEnabled) and camera and mouse then
                local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                local filterList = { clone }
                local real = api.get_real_character and api.get_real_character(lp)
                if real then table.insert(filterList, real) end
                params.FilterDescendantsInstances = filterList
                local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                local targetPos = hit and hit.Position or (ray.Origin + ray.Direction * 1000)
    
                local function pointArm(shoulderName, elbowName, wristName, stretchMult)
                    local shoulder = nil
                    for _, d in ipairs(clone:GetDescendants()) do
                        if d:IsA("Motor6D") and (d.Name == shoulderName or (d.Part1 and d.Part1.Name == shoulderName)) then
                            shoulder = d
                            break
                        end
                    end
                    if not shoulder or not shoulder.Part0 then return end
    
                    local shoulderPos = (shoulder.Part0.CFrame * shoulder.C0).Position
                    local aimDir = (targetPos - shoulderPos)
                    if aimDir.Magnitude <= 0.001 then return end
                    aimDir = aimDir.Unit
    
                    local localAim = (shoulder.Part0.CFrame * shoulder.C0).Rotation:Inverse() * aimDir
                    local bindDir = Vector3.new(0, -1, 0)
                    local rotAxis = bindDir:Cross(localAim)
                    local rotCF = CFrame.new()
                    if rotAxis.Magnitude > 0.001 then
                        local angle = math.acos(math.clamp(bindDir:Dot(localAim), -1, 1))
                        rotCF = CFrame.fromAxisAngle(rotAxis.Unit, angle)
                    end
                    shoulder.Transform = rotCF
    
                    local elbow = nil
                    for _, d in ipairs(clone:GetDescendants()) do
                        if d:IsA("Motor6D") and (d.Name == elbowName or (d.Part1 and d.Part1.Name == elbowName)) then
                            elbow = d
                            break
                        end
                    end
                    if elbow then
                        if stretchMult and stretchMult > 1.0 then
                            elbow.Transform = CFrame.new(0, -(stretchMult - 1.0) * 1.2, 0)
                        else
                            elbow.Transform = CFrame.new()
                        end
                    end
                end
    
                local sAmt = _G._HaloArmStretchAmount or 2.5
                if _G._HaloRightArmPointerEnabled then
                    local isStretching = _G._HaloRightArmStretching or false
                    pointArm("RightShoulder", "RightElbow", "RightWrist", isStretching and sAmt or 1.0)
                end
                if _G._HaloLeftArmPointerEnabled then
                    local isStretching = _G._HaloLeftArmStretching or false
                    pointArm("LeftShoulder", "LeftElbow", "LeftWrist", isStretching and sAmt or 1.0)
                end
            end
    
            -- 3. Torso Camera Control & Torso Stretcher
            local doTorso = _G._HaloTorsoStretcherEnabled or _G._HaloLimbsTorsoCamControl
            if doTorso then
                local waist = nil
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("Motor6D") and (d.Name == "Waist" or d.Name == "RootJoint") then
                        waist = d
                        break
                    end
                end
                if waist and waist.Part0 then
                    local baseRot = CFrame.new()
                    if _G._HaloLimbsTorsoCamControl and camera then
                        local parentCF = waist.Part0.CFrame * waist.C0
                        local camLook = camera.CFrame.LookVector
                        local localLook = parentCF.Rotation:Inverse() * camLook
                        local yaw = math.atan2(localLook.X, -localLook.Z)
                        local pitch = math.asin(math.clamp(localLook.Y, -1, 1))
                        local camRotCF = CFrame.new()
                        local mode = _G._HaloLimbsTorsoCamMode
                        if mode == "Locked" then
                            yaw = math.clamp(yaw, -math.rad(45), math.rad(45))
                            pitch = math.clamp(pitch, -math.rad(30), math.rad(30))
                            camRotCF = CFrame.fromEulerAnglesYXZ(pitch, -yaw, 0)
                        elseif mode == "Pitch Only" then
                            camRotCF = CFrame.fromEulerAnglesYXZ(pitch, 0, 0)
                        else
                            camRotCF = CFrame.fromEulerAnglesYXZ(pitch * 2.0, -yaw, 0)
                        end
                        torsoCamSmoothedCF = torsoCamSmoothedCF and torsoCamSmoothedCF:Lerp(camRotCF, 0.2) or camRotCF
                        baseRot = torsoCamSmoothedCF
                    end
    
                    local utH = _G._HaloLimbsUpperTorsoHeight or 1.0
                    local stretchY = _G._HaloTorsoStretcherEnabled and ((utH - 1.0) * 2.5) or 0
                    waist.Transform = CFrame.new(0, stretchY, 0) * baseRot
                end
            end
    
            -- 4. Leg Stretcher
            if _G._HaloLegStretcherEnabled then
                local legScale = math.clamp(_G._HaloLimbsLegHeight or 1.0, 0.4, 25.0)
                local rKnee, lKnee
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("Motor6D") then
                        if d.Name == "RightKnee" or (d.Part1 and d.Part1.Name == "RightLowerLeg") then rKnee = d end
                        if d.Name == "LeftKnee" or (d.Part1 and d.Part1.Name == "LeftLowerLeg") then lKnee = d end
                    end
                end
                if legScale ~= 1.0 then
                    local kneeOff = CFrame.new(0, -(legScale - 1.0) * 1.5, 0)
                    if rKnee then rKnee.Transform = kneeOff end
                    if lKnee then lKnee.Transform = kneeOff end
                end
                local hum = clone:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.HipHeight = 2.0 * legScale
                end
            end
        end)
    end
    
    
    

end


-- Initialize Panels & Engine safely
local ok1, err1 = pcall(function() initTrackingAndStretchingEngine() end)
if not ok1 then warn("Zen Reanimations [Engine Error]: " .. tostring(err1)) end

local ok2, err2 = pcall(function() copierPanel = buildCopierPanel(contentArea) end)
if not ok2 then warn("Zen Reanimations [Copier Error]: " .. tostring(err2)) end

local ok3, err3 = pcall(function() trackingPanel = buildTrackingPanel(contentArea) end)
if not ok3 then warn("Zen Reanimations [Tracking Error]: " .. tostring(err3)) end

local ok4, err4 = pcall(function() stretchingPanel = buildStretchingPanel(contentArea) end)
if not ok4 then warn("Zen Reanimations [Stretching Error]: " .. tostring(err4)) end

local ok5, err5 = pcall(function() studioPanel = buildStudioPanel(contentArea) end)
if not ok5 then warn("Zen Reanimations [Studio Error]: " .. tostring(err5)) end


-- ═══════════════════════════════════════════════════
-- 9. REANIMS & FAVS LIST ENGINE (Fast Virtualized)
-- ═══════════════════════════════════════════════════
local ROW_HEIGHT = 38
local currentlyBinding = nil
local activeOutlineAnim = nil
local animButtons = {}

local function playSelectedAnimation(anim)
    if not (api and api.is_reanimated and api.is_reanimated()) then
        warn("Zen Reanimations: Enable Reanimation first to play animations!")
        return
    end

    if currentPlayingAnim == anim.name then
        manualAnimationPlaying = false
        api.stop_animation()
        activeOutlineAnim = nil
        updateNowPlayingUI(nil)
        return
    end

    manualAnimationPlaying = true
    activeOutlineAnim = anim.name
    api.play_animation(anim.path, currentSpeed)
    updateNowPlayingUI(anim.name)
end

local function populateList()
    for _, child in ipairs(scrollList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    table.clear(animButtons)

    local term = searchBox.Text:lower()
    local displayList = {}

    for _, a in ipairs(animations) do
        local isCustomAnim = a.isCustom or (a.category == "Custom") or (a.category == "Recorded")
        if currentTab == "Favs" then
            if savedConfig.favs[a.name] then
                if term == "" or a.name:lower():find(term, 1, true) then
                    table.insert(displayList, a)
                end
            end
        elseif currentTab == "Custom" then
            if isCustomAnim then
                if term == "" or a.name:lower():find(term, 1, true) then
                    table.insert(displayList, a)
                end
            end
        else
            if term == "" or a.name:lower():find(term, 1, true) then
                table.insert(displayList, a)
            end
        end
    end

    if currentTab == "Favs" then
        emptyFavsLabel.Visible = (#displayList == 0)
        emptyCustomLabel.Visible = false
    elseif currentTab == "Custom" then
        emptyFavsLabel.Visible = false
        emptyCustomLabel.Visible = (#displayList == 0)
    else
        emptyFavsLabel.Visible = false
        emptyCustomLabel.Visible = false
    end

    for i, anim in ipairs(displayList) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = scrollList
        applyCorner(row, 6)
        local rowStroke = applyStroke(row, (activeOutlineAnim == anim.name) and C.accent or C.divider, 1, (activeOutlineAnim == anim.name) and 0 or 0.5)

        -- Star Button
        local isFav = savedConfig.favs[anim.name]
        local starBtn = Instance.new("TextButton")
        starBtn.Size = UDim2.new(0, 24, 1, 0)
        starBtn.Position = UDim2.new(0, 4, 0, 0)
        starBtn.BackgroundTransparency = 1
        starBtn.Text = isFav and "★" or "☆"
        starBtn.TextColor3 = isFav and Color3.fromRGB(255, 215, 0) or C.textMuted
        starBtn.Font = Enum.Font.GothamBold
        starBtn.TextSize = 14
        starBtn.Parent = row

        starBtn.MouseButton1Click:Connect(function()
            if savedConfig.favs[anim.name] then
                savedConfig.favs[anim.name] = nil
                starBtn.Text = "☆"
                starBtn.TextColor3 = C.textMuted
            else
                savedConfig.favs[anim.name] = true
                starBtn.Text = "★"
                starBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
            saveConfig()
            if currentTab == "Favs" then
                populateList()
            end
        end)

        -- Play Button (Animation Title)
        local isCustomAnim = anim.isCustom or (anim.category == "Custom") or (anim.category == "Recorded")
        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, isCustomAnim and -108 or -78, 1, 0)
        playBtn.Position = UDim2.new(0, 30, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.RichText = true
        if isCustomAnim then
            playBtn.Text = anim.name .. " <font color=\"rgb(80,210,255)\">[CUSTOM]</font>"
        else
            playBtn.Text = anim.name
        end
        playBtn.TextColor3 = (activeOutlineAnim == anim.name) and C.accent or C.text
        playBtn.Font = (activeOutlineAnim == anim.name) and Enum.Font.GothamBold or Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.Parent = row

        animButtons[anim.name] = { stroke = rowStroke, btn = playBtn, star = starBtn }

        playBtn.MouseEnter:Connect(function()
            if activeOutlineAnim ~= anim.name then
                tween(row, {BackgroundColor3 = C.surfaceHover}, 0.15)
            end
        end)
        playBtn.MouseLeave:Connect(function()
            if activeOutlineAnim ~= anim.name then
                tween(row, {BackgroundColor3 = C.surface}, 0.15)
            end
        end)
        playBtn.MouseButton1Click:Connect(function()
            playSelectedAnimation(anim)
            for aName, widgets in pairs(animButtons) do
                local isActive = (activeOutlineAnim == aName)
                widgets.stroke.Color = isActive and C.accent or C.divider
                widgets.stroke.Transparency = isActive and 0 or 0.5
                widgets.btn.TextColor3 = isActive and C.accent or C.text
                widgets.btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
            end
        end)

        -- Keybind Button
        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 38, 0, 22)
        keyBtn.Position = UDim2.new(1, isCustomAnim and -72 or -44, 0.5, -11)
        keyBtn.BackgroundColor3 = C.input
        local boundKey = savedConfig.binds[anim.name]
        keyBtn.Text = boundKey and ("[" .. boundKey .. "]") or "[+]"
        keyBtn.TextColor3 = boundKey and C.accent or C.textMuted
        keyBtn.Font = Enum.Font.GothamSemibold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        applyCorner(keyBtn, 4)
        applyStroke(keyBtn, C.divider, 1, 0)

        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == anim.name then
                currentlyBinding = nil
                local b = savedConfig.binds[anim.name]
                keyBtn.Text = b and ("[" .. b .. "]") or "[+]"
                keyBtn.TextColor3 = b and C.accent or C.textMuted
                return
            end
            currentlyBinding = { name = anim.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = Color3.fromRGB(255, 180, 50)
        end)

        if isCustomAnim then
            local delBtn = Instance.new("TextButton")
            delBtn.Size = UDim2.new(0, 24, 0, 22)
            delBtn.Position = UDim2.new(1, -28, 0.5, -11)
            delBtn.BackgroundColor3 = C.surface
            delBtn.Text = "✕"
            delBtn.TextColor3 = C.textMuted
            delBtn.Font = Enum.Font.GothamBold
            delBtn.TextSize = 10
            delBtn.Parent = row
            applyCorner(delBtn, 4)
            applyStroke(delBtn, C.divider, 1, 0)

            delBtn.MouseEnter:Connect(function()
                tween(delBtn, {BackgroundColor3 = C.dangerHover, TextColor3 = Color3.fromRGB(255, 120, 120)}, 0.15)
            end)
            delBtn.MouseLeave:Connect(function()
                tween(delBtn, {BackgroundColor3 = C.surface, TextColor3 = C.textMuted}, 0.15)
            end)
            delBtn.MouseButton1Click:Connect(function()
                for i, a in ipairs(animations) do
                    if a.name == anim.name then
                        table.remove(animations, i)
                        break
                    end
                end
                for i, ca in ipairs(savedConfig.customAnims) do
                    if ca.name == anim.name then
                        table.remove(savedConfig.customAnims, i)
                        break
                    end
                end
                savedConfig.favs[anim.name] = nil
                savedConfig.binds[anim.name] = nil
                saveConfig()
                populateList()
            end)
        end
    end

    scrollList.CanvasSize = UDim2.new(0, 0, 0, #displayList * (ROW_HEIGHT + 4))
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    populateList()
end)

-- ═══════════════════════════════════════════════════
-- 10. BINDS LIST ENGINE
-- ═══════════════════════════════════════════════════
local function populateBindsList()
    for _, child in ipairs(bindsPanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local boundItems = {}
    for animName, keyName in pairs(savedConfig.binds) do
        -- Find path
        local path = nil
        for _, a in ipairs(animations) do
            if a.name == animName then path = a.path break end
        end
        if path then
            table.insert(boundItems, { name = animName, path = path, key = keyName })
        end
    end

    table.sort(boundItems, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    emptyBindsLabel.Visible = (#boundItems == 0)

    for i, item in ipairs(boundItems) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 36)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.LayoutOrder = i + 1
        row.Parent = bindsPanel
        applyCorner(row, 6)
        applyStroke(row, C.divider, 1, 0.4)

        local playBtn = Instance.new("TextButton")
        playBtn.Size = UDim2.new(1, -120, 1, 0)
        playBtn.Position = UDim2.new(0, 12, 0, 0)
        playBtn.BackgroundTransparency = 1
        playBtn.Text = item.name
        playBtn.TextColor3 = C.text
        playBtn.Font = Enum.Font.GothamMedium
        playBtn.TextSize = 11
        playBtn.TextXAlignment = Enum.TextXAlignment.Left
        playBtn.TextTruncate = Enum.TextTruncate.AtEnd
        playBtn.Parent = row

        playBtn.MouseButton1Click:Connect(function()
            playSelectedAnimation(item)
        end)

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 48, 0, 24)
        keyBtn.Position = UDim2.new(1, -100, 0.5, -12)
        keyBtn.BackgroundColor3 = C.input
        keyBtn.Text = "[" .. item.key .. "]"
        keyBtn.TextColor3 = C.accent
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 10
        keyBtn.Parent = row
        applyCorner(keyBtn, 4)
        applyStroke(keyBtn, C.divider, 1, 0)

        keyBtn.MouseButton1Click:Connect(function()
            if currentlyBinding and currentlyBinding.name == item.name then
                currentlyBinding = nil
                keyBtn.Text = "[" .. item.key .. "]"
                keyBtn.TextColor3 = C.accent
                return
            end
            currentlyBinding = { name = item.name, btn = keyBtn }
            keyBtn.Text = "[?]"
            keyBtn.TextColor3 = Color3.fromRGB(255, 180, 50)
        end)

        local unbindBtn = Instance.new("TextButton")
        unbindBtn.Size = UDim2.new(0, 42, 0, 24)
        unbindBtn.Position = UDim2.new(1, -48, 0.5, -12)
        unbindBtn.BackgroundColor3 = C.surface
        unbindBtn.Text = "Unbind"
        unbindBtn.TextColor3 = C.textMuted
        unbindBtn.Font = Enum.Font.GothamSemibold
        unbindBtn.TextSize = 9
        unbindBtn.Parent = row
        applyCorner(unbindBtn, 4)
        applyStroke(unbindBtn, C.divider, 1, 0)

        unbindBtn.MouseEnter:Connect(function()
            tween(unbindBtn, {BackgroundColor3 = C.dangerHover, TextColor3 = C.accent}, 0.15)
        end)
        unbindBtn.MouseLeave:Connect(function()
            tween(unbindBtn, {BackgroundColor3 = C.surface, TextColor3 = C.textMuted}, 0.15)
        end)
        unbindBtn.MouseButton1Click:Connect(function()
            savedConfig.binds[item.name] = nil
            saveConfig()
            populateBindsList()
        end)
    end

    bindsPanel.CanvasSize = UDim2.new(0, 0, 0, 26 + #boundItems * 42)
end

-- ═══════════════════════════════════════════════════
-- 11. SWITCH TABS LOGIC
-- ═══════════════════════════════════════════════════
switchTab = function(tab)
    currentTab = tab

    for tName, data in pairs(tabButtons) do
        local isActive = (tName == tab)
        tween(data.btn, {
            BackgroundColor3 = isActive and C.accent or Color3.fromRGB(30, 30, 35),
            BackgroundTransparency = isActive and 0 or 0.5,
            TextColor3 = isActive and Color3.fromRGB(8, 8, 10) or C.textMuted
        }, 0.2, Enum.EasingStyle.Quint)
        data.btn.Font = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end

    local isAnimListTab = (tab == "Reanims" or tab == "Favs" or tab == "Custom")
    listPanel.Visible       = isAnimListTab
    bindsPanel.Visible      = (tab == "Binds")
    speedPanel.Visible      = (tab == "Speed")
    statesPanel.Visible     = (tab == "States")
    if copierPanel then copierPanel.Visible = (tab == "Copier") end
    if trackingPanel then trackingPanel.Visible = (tab == "Tracking") end
    if stretchingPanel then stretchingPanel.Visible = (tab == "Stretching") end
    if studioPanel then studioPanel.Visible = (tab == "Studio") end
    limbsPanel.Visible      = (tab == "Limbs")

    local activePanel = isAnimListTab and listPanel
        or (tab == "Binds" and bindsPanel)
        or (tab == "Speed" and speedPanel)
        or (tab == "States" and statesPanel)
        or (tab == "Copier" and copierPanel)
        or (tab == "Tracking" and trackingPanel)
        or (tab == "Stretching" and stretchingPanel)
        or (tab == "Limbs" and limbsPanel)
        or (tab == "Studio" and studioPanel)

    if activePanel then
        activePanel.Position = UDim2.new(0, 0, 0, 6)
        tween(activePanel, {Position = UDim2.new(0, 0, 0, 0)}, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    end

    if isAnimListTab then
        if tab == "Favs" then
            searchBox.PlaceholderText = "Search favorites..."
            addCustomBtn.Visible = false
            searchBox.Size = UDim2.new(1, 0, 0, 30)
        elseif tab == "Custom" then
            searchBox.PlaceholderText = "Search custom animations..."
            addCustomBtn.Visible = true
            searchBox.Size = UDim2.new(1, -96, 0, 30)
        else
            searchBox.PlaceholderText = "Search animations..."
            addCustomBtn.Visible = true
            searchBox.Size = UDim2.new(1, -96, 0, 30)
        end
        populateList()
    elseif tab == "Binds" then
        populateBindsList()
    elseif tab == "Limbs" then
        updateLimbsUI()
    end
end

-- ═══════════════════════════════════════════════════
-- 12. CHARACTER STATE MACHINE (States Engine)
-- ═══════════════════════════════════════════════════
local lastLogicalState = nil
local stateThrottle = 0

RunService.Heartbeat:Connect(function()
    if not (api and api.is_reanimated and api.is_reanimated()) then return end
    if manualAnimationPlaying then return end
    if not (savedConfig.states and next(savedConfig.states)) then return end

    stateThrottle = stateThrottle + 1
    if stateThrottle % 2 ~= 0 then return end -- 30Hz evaluation

    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local hs = hum:GetState()
    local logical = "Idle"

    if hs == Enum.HumanoidStateType.Jumping then
        logical = "Jump"
    elseif hs == Enum.HumanoidStateType.Freefall then
        if hrp.AssemblyLinearVelocity.Y > 0.1 then
            logical = "Jump"
        else
            logical = "Fall"
        end
    else
        local vel = hrp.AssemblyLinearVelocity
        local horizSpeed = Vector2.new(vel.X, vel.Z).Magnitude
        if horizSpeed > 14 then
            logical = "Run"
        elseif horizSpeed > 1.5 then
            logical = "Walk"
        else
            logical = "Idle"
        end
    end

    if logical ~= lastLogicalState then
        lastLogicalState = logical
        local assigned = savedConfig.states[logical]
        if assigned and assigned.path then
            api.play_animation(assigned.path, currentSpeed)
            updateNowPlayingUI("[" .. logical .. "] " .. assigned.name)
        else
            api.stop_animation()
            updateNowPlayingUI(nil)
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 13. GLOBAL KEYBIND HANDLER
-- ═══════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    -- Check if listening to bind an animation
    if currentlyBinding then
        local kName = input.KeyCode.Name
        savedConfig.binds[currentlyBinding.name] = kName
        saveConfig()
        if currentlyBinding.btn then
            currentlyBinding.btn.Text = "[" .. kName .. "]"
            currentlyBinding.btn.TextColor3 = C.accent
        end
        currentlyBinding = nil
        return
    end

    -- Check if listening to bind a speed preset
    if currentlyBindingSpeed then
        local kName = input.KeyCode.Name
        savedConfig.speedBinds[currentlyBindingSpeed] = kName
        saveConfig()
        local btn = speedBindButtons[currentlyBindingSpeed]
        if btn then
            btn.Text = "[" .. kName .. "]"
            btn.TextColor3 = C.accent
        end
        currentlyBindingSpeed = nil
        return
    end

    if gpe then return end

    -- Check speed preset keybinds
    for spdStr, kName in pairs(savedConfig.speedBinds) do
        if input.KeyCode.Name == kName then
            applySpeed(tonumber(spdStr) or 1.0)
            return
        end
    end

    -- Check tracking keybind assignment
    if currentlyBindingTracking then
        local kName = input.KeyCode.Name
        savedConfig.trackingBinds = savedConfig.trackingBinds or {}
        savedConfig.trackingBinds[currentlyBindingTracking] = kName
        saveConfig()
        if currentlyBindingTracking == "HeadTracker" and htCardUI then htCardUI.updateKeyUI()
        elseif currentlyBindingTracking == "LeftArm" and laCardUI then laCardUI.updateKeyUI()
        elseif currentlyBindingTracking == "RightArm" and raCardUI then raCardUI.updateKeyUI() end
        currentlyBindingTracking = nil
        return
    end

    -- Check tracking toggles via keybinds
    if savedConfig.trackingBinds and savedConfig.trackingBinds.HeadTracker and input.KeyCode.Name == savedConfig.trackingBinds.HeadTracker then
        if htCardUI then htCardUI.setToggled(not _G._HaloHeadTrackerEnabled) end
        return
    end
    if savedConfig.trackingBinds and savedConfig.trackingBinds.LeftArm and input.KeyCode.Name == savedConfig.trackingBinds.LeftArm then
        if laCardUI then laCardUI.setToggled(not _G._HaloLeftArmPointerEnabled) end
        return
    end
    if savedConfig.trackingBinds and savedConfig.trackingBinds.RightArm and input.KeyCode.Name == savedConfig.trackingBinds.RightArm then
        if raCardUI then raCardUI.setToggled(not _G._HaloRightArmPointerEnabled) end
        return
    end

    -- Check animation keybinds
    for animName, kName in pairs(savedConfig.binds) do
        if input.KeyCode.Name == kName then
            for _, a in ipairs(animations) do
                if a.name == animName then
                    playSelectedAnimation(a)
                    return
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════
-- 14. TOGGLE REANIMATION BUTTON LOGIC
-- ═══════════════════════════════════════════════════
local function updateReanimButtonState()
    local isReanimated = api.is_reanimated()
    if isReanimated then
        toggleBtn.Text = "Disable Reanim"
        toggleBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        toggleStroke.Color = Color3.fromRGB(160, 160, 160)
        toggleStroke.Transparency = 0.2
    else
        toggleBtn.Text = "Enable Reanim"
        toggleBtn.TextColor3 = C.text
        toggleBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        toggleStroke.Color = C.border
        toggleStroke.Transparency = 0.4
    end
end

toggleBtn.MouseButton1Click:Connect(function()
    local isReanimated = api.is_reanimated()
    local newState = not isReanimated

    toggleBtn.Text = newState and "Reanimating..." or "Disabling..."
    toggleBtn.TextColor3 = C.textMuted

    task.spawn(function()
        local err = api.reanimate(newState)
        if err and typeof(err) == "string" and err ~= "Already reanimated." then
            warn("Zen Reanimations: " .. err)
        end
        updateReanimButtonState()
        if not newState then
            manualAnimationPlaying = false
            updateNowPlayingUI(nil)
        end
    end)
end)

-- Initialize
updateReanimButtonState()
applySpeed(currentSpeed)
switchTab("Reanims")
populateList()
