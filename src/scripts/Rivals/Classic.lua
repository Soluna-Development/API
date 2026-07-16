local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local TeamCheckEnabled = false

local LocalPlayer = Players.LocalPlayer
local Camera = game.Workspace.CurrentCamera
local Keybind = Enum.UserInputType.MouseButton2

local SENSITIVITY_MULTIPLIER = 0.1

local AimbotMode = "Hold"

local ESPEnabled = false

local AutoShootEnabled = false

local InfiniteJumpEnabled = false

local NoClipEnabled = false

local WalkSpeedEnabled = false

local SPACING = 20
local ELEMENT_HEIGHT = 40
local FRAME_WIDTH = 300
local FRAME_HEIGHT = 300
local PADDING = 40

local ACTIVE_FEATURES_SPACING = 10
local ACTIVE_FEATURES_ELEMENT_HEIGHT = 30
local ACTIVE_FEATURES_FRAME_HEIGHT = 350

local MAX_DISTANCE_THRESHOLD = 1000
local FIRST_PERSON_CHECK = true     
local MAX_CAMERA_MOVEMENT = 20      
local SELF_TARGETING_PREVENTION = true  
local AIMBOT_THRESHOLD = 1000
local SHOOT_HOLD_DURATION = 0.5
local DETECTION_GRACE_PERIOD = 0.2
local MIN_DISTANCE_THRESHOLD = 10  
local MAX_SENSITIVITY = 1.5    
local BASE_SENSITIVITY = 0.5

local MAX_AIMBOT_DISTANCE = 1000
local AimbotToggleEnabled = false
local IsRightClickAimbot = true

local DefaultWalkSpeed = 16 

local Target = nil
local ESPHighlights = {}
local InfiniteJumpConnection = nil
local lastTargetTime = 0
local LERP_FACTOR = 0.2

local ThemeColors = {
    Dark = {
        Background = Color3.fromRGB(0, 0, 0),        -- Black
        Panel = Color3.fromRGB(15, 15, 15),           -- Darker Gray
        Accent = Color3.fromRGB(100, 100, 100),       -- Darker Gray
        Highlight = Color3.fromRGB(150, 150, 150),    -- Slightly Darker Light Gray
        Text = Color3.fromRGB(255, 255, 255),         -- White
        Danger = Color3.fromRGB(255, 255, 255)        -- White (for danger elements)
    },
    Light = {
        Background = Color3.fromRGB(255, 255, 255),   -- White
        Panel = Color3.fromRGB(230, 230, 230),        -- Light Gray
        Accent = Color3.fromRGB(128, 128, 128),       -- Gray
        Highlight = Color3.fromRGB(100, 100, 100),    -- Dark Gray
        Text = Color3.fromRGB(0, 0, 0),               -- Black
        Danger = Color3.fromRGB(0, 0, 0)              -- Black (for danger elements)
    }
}

local CurrentTheme = "Dark"

local MOVE_SPEED = 50
local MAX_FORCE = 10000
local DAMPENING = 0.9
local moveKeys = {
    [Enum.KeyCode.W] = Vector3.new(0, 0, -1),
    [Enum.KeyCode.S] = Vector3.new(0, 0, 1),
    [Enum.KeyCode.A] = Vector3.new(-1, 0, 0),
    [Enum.KeyCode.D] = Vector3.new(1, 0, 0),
    [Enum.KeyCode.Space] = Vector3.new(0, 1, 0),
    [Enum.KeyCode.LeftControl] = Vector3.new(0, -1, 0)
}
local keysDown = {}
local currentVelocity = Vector3.new(0, 0, 0)

local function updateWalkSpeed(newSpeed)
    MOVE_SPEED = newSpeed
    if WalkSpeedEnabled then
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = newSpeed
            end
        end
    end
end

local function onCharacterAdded(newCharacter)
    local humanoid = newCharacter:WaitForChild("Humanoid")
    local rootPart = newCharacter:WaitForChild("HumanoidRootPart")

    if WalkSpeedEnabled then

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
        bodyVelocity.P = 1250
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = rootPart

        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
        bodyGyro.D = 150
        bodyGyro.P = 5000
        bodyGyro.CFrame = rootPart.CFrame
        bodyGyro.Parent = rootPart

        humanoid.PlatformStand = true
    else

        humanoid.PlatformStand = false

        local bodyVelocity = rootPart:FindFirstChild("BodyVelocity")
        if bodyVelocity then
            bodyVelocity:Destroy()
        end

        local bodyGyro = rootPart:FindFirstChild("BodyGyro")
        if bodyGyro then
            bodyGyro:Destroy()
        end
    end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if moveKeys[input.KeyCode] then
        keysDown[input.KeyCode] = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if moveKeys[input.KeyCode] then
        keysDown[input.KeyCode] = nil
    end
end)

RunService.RenderStepped:Connect(function(deltaTime)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or humanoid:GetState() == Enum.HumanoidStateType.Dead then
        return
    end

    if WalkSpeedEnabled then
        local camera = workspace.CurrentCamera
        local camCF = camera.CFrame
        local moveDirection = Vector3.new(0, 0, 0)

        for key, direction in pairs(moveKeys) do
            if keysDown[key] then
                if direction.Y ~= 0 then
                    moveDirection = moveDirection + direction
                else
                    local rotatedDir = camCF:VectorToWorldSpace(direction)
                    rotatedDir = Vector3.new(rotatedDir.X, 0, rotatedDir.Z).Unit
                    moveDirection = moveDirection + rotatedDir
                end
            end
        end

        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end

        currentVelocity = currentVelocity * DAMPENING + moveDirection * (1 - DAMPENING)
        local bodyVelocity = rootPart:FindFirstChild("BodyVelocity")
        if bodyVelocity then
            bodyVelocity.Velocity = currentVelocity * MOVE_SPEED
        end
    end
end)

local function createSlider(parent, position, text, minValue, maxValue, defaultValue, callback)
    local slider = Instance.new("Frame")
    slider.Size = UDim2.new(0, 250, 0, 50)
    slider.Position = position
    slider.BackgroundTransparency = 1
    slider.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 250, 0, 20)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = ThemeColors[CurrentTheme].Text
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = slider

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(0, 250, 0, 6)
    sliderBar.Position = UDim2.new(0, 0, 0, 25) 
    sliderBar.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = slider

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0, 0, 1, 0)
    sliderFill.Position = UDim2.new(0, 0, 0, 0)
    sliderFill.BackgroundColor3 = ThemeColors[CurrentTheme].Accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar

    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 20, 0, 20)
    sliderButton.Position = UDim2.new(0, 0, 0.5, -10) 
    sliderButton.BackgroundColor3 = ThemeColors[CurrentTheme].Accent
    sliderButton.Text = ""
    sliderButton.AutoButtonColor = false
    sliderButton.Parent = slider

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = sliderButton

    local function updateSlider(value)
        local percent = (value - minValue) / (maxValue - minValue)
        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        sliderButton.Position = UDim2.new(percent, -10, 0.5, -10) 
        callback(value)
    end

    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local connection
            connection = RunService.RenderStepped:Connect(function()
                local mouseLocation = UserInputService:GetMouseLocation().X
                local sliderPosition = sliderBar.AbsolutePosition.X
                local sliderWidth = sliderBar.AbsoluteSize.X
                local percent = math.clamp((mouseLocation - sliderPosition) / sliderWidth, 0, 1)
                local value = minValue + (maxValue - minValue) * percent
                updateSlider(value)
            end)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    connection:Disconnect()
                end
            end)
        end
    end)

    updateSlider(defaultValue)
    return slider
end

local function isDead(player)
    if not player or not player.Character then return true end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    return not humanoid or humanoid.Health <= 0
end

local function isTeammate(player)
    if not TeamCheckEnabled then return false end
    if not LocalPlayer or not player then return false end
    if not LocalPlayer.Team or not player.Team then return false end
    return LocalPlayer.Team == player.Team
end


local function applyTheme(theme)
    local colors = ThemeColors[theme]
    for _, element in pairs(ScreenGui:GetDescendants()) do
        if element:IsA("Frame") or element:IsA("TextButton") or element:IsA("TextLabel") then
            if element.Name == "Accent" then
                element.BackgroundColor3 = colors.Accent
            elseif element.Name == "Panel" then
                element.BackgroundColor3 = colors.Panel
            elseif element.Name == "Text" then
                element.TextColor3 = colors.Text
            else
                element.BackgroundColor3 = colors.Background
            end
        end
    end
end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "EnhancedGameUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui
local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Size = 0
BlurEffect.Parent = game.Lighting
local function createToggle(parent, position, text, default)
    local toggle = Instance.new("Frame")
    toggle.Size = UDim2.new(0, 200, 0, 30)
    toggle.Position = position
    toggle.BackgroundTransparency = 1
    toggle.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 130, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = ThemeColors[CurrentTheme].Text
    label.TextSize = 14
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggle
    local switchContainer = Instance.new("Frame")
    switchContainer.Size = UDim2.new(0, 50, 0, 24)
    switchContainer.Position = UDim2.new(0, 140, 0, 3)
    switchContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    switchContainer.BackgroundTransparency = 0.3
    switchContainer.Parent = toggle
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switchContainer
    local toggleButton = Instance.new("Frame")
    toggleButton.Size = UDim2.new(0, 20, 0, 20)
    toggleButton.Position = UDim2.new(0, default and 27 or 2, 0, 2)
    toggleButton.BackgroundColor3 = default and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    toggleButton.Parent = switchContainer
    local toggleButtonCorner = Instance.new("UICorner")
    toggleButtonCorner.CornerRadius = UDim.new(1, 0)
    toggleButtonCorner.Parent = toggleButton
    local enabled = default
    local function updateToggleState()
        TweenService:Create(toggleButton, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Position = UDim2.new(0, enabled and 27 or 2, 0, 2),
            BackgroundColor3 = enabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
        }):Play()
        TweenService:Create(switchContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            BackgroundColor3 = enabled and Color3.fromRGB(60, 60, 70) or Color3.fromRGB(50, 50, 60)
        }):Play()
    end
    switchContainer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            enabled = not enabled
            updateToggleState()
        end
    end)
    label.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            enabled = not enabled
            updateToggleState()
        end
    end)
    local function getState()
        return enabled
    end
    local function setState(state)
        enabled = state
        updateToggleState()
    end
    return toggle, getState, setState
end

local function createGlassPanel(parent, size, position, cornerRadius)
    local panel = Instance.new("Frame")
    panel.Size = size
    panel.Position = position
    panel.BackgroundColor3 = ThemeColors[CurrentTheme].Panel
    panel.BackgroundTransparency = 0.4
    panel.BorderSizePixel = 0
    panel.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, cornerRadius or 12)
    corner.Parent = panel
    local stroke = Instance.new("UIStroke")
    stroke.Color = ThemeColors[CurrentTheme].Text
    stroke.Thickness = 1.5
    stroke.Transparency = 0.7
    stroke.Parent = panel
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(1, 0.9)
    })
    gradient.Rotation = 45
    gradient.Parent = panel
    return panel
end

local function createButton(parent, size, position, text, cornerRadius)
    local button = Instance.new("TextButton")
    button.Size = size
    button.Position = position
    button.Text = text
    button.BackgroundColor3 = ThemeColors[CurrentTheme].Accent -- Default background color
    button.BackgroundTransparency = 0.3
    button.TextColor3 = ThemeColors[CurrentTheme].Text -- Default text color
    button.TextSize = 14
    button.Font = Enum.Font.GothamSemibold
    button.AutoButtonColor = false
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, cornerRadius or 8)
    corner.Parent = button

    -- Hover effect
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.3), {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255), -- White background on hover
            TextColor3 = Color3.fromRGB(0, 0, 0), -- Black text on hover
            BackgroundTransparency = 0.1,
            TextSize = 15
        }):Play()
    end)

    -- Reset to default when not hovered
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.3), {
            BackgroundColor3 = ThemeColors[CurrentTheme].Accent, -- Default background color
            TextColor3 = ThemeColors[CurrentTheme].Text, -- Default text color
            BackgroundTransparency = 0.3,
            TextSize = 14
        }):Play()
    end)

    -- Button press effect
    button.MouseButton1Down:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {
            Size = size - UDim2.new(0, 4, 0, 4),
            Position = position + UDim2.new(0, 2, 0, 2)
        }):Play()
    end)

    button.MouseButton1Up:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {
            Size = size,
            Position = position
        }):Play()
    end)

    return button
end

local SidePanel = createGlassPanel(ScreenGui, UDim2.new(0, 240, 0, ACTIVE_FEATURES_FRAME_HEIGHT), UDim2.new(1, -230, 0.5, -ACTIVE_FEATURES_FRAME_HEIGHT / 2))
local SidePanelTitle = Instance.new("TextLabel")
SidePanelTitle.Size = UDim2.new(0, 200, 0, 30)
SidePanelTitle.Position = UDim2.new(0.1, 0, 0.05, 0)
SidePanelTitle.Text = "Active Features"
SidePanelTitle.BackgroundTransparency = 1
SidePanelTitle.TextColor3 = ThemeColors[CurrentTheme].Text
SidePanelTitle.TextSize = 18
SidePanelTitle.Font = Enum.Font.GothamBold
SidePanelTitle.TextXAlignment = Enum.TextXAlignment.Left
SidePanelTitle.Parent = SidePanel

local function createStatusIndicator(panel, position, icon, text)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 180, 0, 40)
    container.Position = position
    container.BackgroundTransparency = 1
    container.Parent = panel
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 40, 1, 0)
    iconLabel.Position = UDim2.new(0, 0, 0, 0)
    iconLabel.Text = icon
    iconLabel.BackgroundTransparency = 1
    iconLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    iconLabel.TextSize = 20
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextYAlignment = Enum.TextYAlignment.Center
    iconLabel.Parent = container
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 140, 1, 0)
    statusLabel.Position = UDim2.new(0, 40, 0, 0)
    statusLabel.Text = text
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    statusLabel.Parent = container
    return statusLabel, iconLabel
end

local ESPStatus, ESPIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.15, 0), "👁️", "ESP: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)
local InfiniteJumpStatus, InfiniteJumpIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.25, 0), "🔁", "Infinite Jump: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)
local AimbotStatus, AimbotIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.35, 0), "🎯", "Aimbot: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)
local AutoShootStatus, AutoShootIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.45, 0), "🔫", "Auto Shoot: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)
local NoClipStatus, NoClipIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.55, 0), "🚀", "NoClip: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)
local WalkSpeedStatus, WalkSpeedIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.65, 0), "🏃", "WalkSpeed: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)
local TeamCheckStatus, TeamCheckIcon = createStatusIndicator(SidePanel, UDim2.new(0.1, 0, 0.75, 0), "👥", "Team Check: Off", ACTIVE_FEATURES_ELEMENT_HEIGHT)


local SettingsButton = createButton(ScreenGui, UDim2.new(0, 110, 0, 40), UDim2.new(0.9, -120, 0.05, 0), "Settings")

spawn(function()
    while true do
        TweenService:Create(SettingsButton, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.1
        }):Play()
        wait(1.5)
        TweenService:Create(SettingsButton, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.3
        }):Play()
        wait(1.5)
    end
end)

local SettingsFrame = createGlassPanel(ScreenGui, UDim2.new(0, FRAME_WIDTH, 0, FRAME_HEIGHT), UDim2.new(0.5, -FRAME_WIDTH / 2, 0.5, -FRAME_HEIGHT / 2))
SettingsFrame.Visible = false

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.ScrollBarThickness = 0 
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.Parent = SettingsFrame

local SettingsTitle = Instance.new("TextLabel")
SettingsTitle.Size = UDim2.new(0, 250, 0, 40)
SettingsTitle.Position = UDim2.new(0.5, -125, 0, PADDING)
SettingsTitle.Text = "Rivals Script"
SettingsTitle.BackgroundTransparency = 1
SettingsTitle.TextColor3 = ThemeColors[CurrentTheme].Text
SettingsTitle.TextSize = 22
SettingsTitle.Font = Enum.Font.GothamBold
SettingsTitle.TextXAlignment = Enum.TextXAlignment.Center
SettingsTitle.Parent = ScrollingFrame

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollingFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.ScrollBarThickness = 0 
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.Parent = SettingsFrame

local ScrollingFrameCorner = Instance.new("UICorner")
ScrollingFrameCorner.CornerRadius = UDim.new(0, 12) 
ScrollingFrameCorner.Parent = ScrollingFrame

local ScrollBar = Instance.new("Frame")
ScrollBar.Name = "ScrollBar"
ScrollBar.Size = UDim2.new(0, 8, 1, -24) 
ScrollBar.Position = UDim2.new(1, -8, 0, 12) 
ScrollBar.BackgroundColor3 = ThemeColors[CurrentTheme].Accent
ScrollBar.BackgroundTransparency = 0.5
ScrollBar.BorderSizePixel = 0
ScrollBar.Visible = false 
ScrollBar.Parent = ScrollingFrame

local ScrollBarCorner = Instance.new("UICorner")
ScrollBarCorner.CornerRadius = UDim.new(1, 0) 
ScrollBarCorner.Parent = ScrollBar

local ScrollThumb = Instance.new("Frame")
ScrollThumb.Name = "ScrollThumb"
ScrollThumb.Size = UDim2.new(1, 0, 0, 50) 
ScrollThumb.BackgroundColor3 = ThemeColors[CurrentTheme].Highlight
ScrollThumb.BackgroundTransparency = 0.3
ScrollThumb.BorderSizePixel = 0
ScrollThumb.Parent = ScrollBar

local ScrollThumbCorner = Instance.new("UICorner")
ScrollThumbCorner.CornerRadius = UDim.new(1, 0) 
ScrollThumbCorner.Parent = ScrollThumb

local function UpdateScrollThumb()
    local canvasSize = ScrollingFrame.CanvasSize.Y.Offset
    local windowSize = ScrollingFrame.AbsoluteWindowSize.Y
    local isScrollable = canvasSize > windowSize

    ScrollBar.Visible = isScrollable

    if isScrollable then

        local thumbHeight = math.max(20, windowSize / canvasSize * ScrollBar.AbsoluteSize.Y)
        ScrollThumb.Size = UDim2.new(1, 0, 0, thumbHeight)

        local maxScroll = canvasSize - windowSize
        local scrollRatio = ScrollingFrame.CanvasPosition.Y / maxScroll
        local thumbPosition = scrollRatio * (ScrollBar.AbsoluteSize.Y - ScrollThumb.AbsoluteSize.Y)
        ScrollThumb.Position = UDim2.new(0, 0, 0, thumbPosition)
    end
end

ScrollingFrame:GetPropertyChangedSignal("CanvasSize"):Connect(UpdateScrollThumb)
ScrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(UpdateScrollThumb)

ScrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    local canvasSize = ScrollingFrame.CanvasSize.Y.Offset
    local windowSize = ScrollingFrame.AbsoluteWindowSize.Y
    local maxScroll = canvasSize - windowSize
    local scrollRatio = ScrollingFrame.CanvasPosition.Y / maxScroll
    local thumbPosition = scrollRatio * (ScrollBar.AbsoluteSize.Y - ScrollThumb.AbsoluteSize.Y)

    TweenService:Create(ScrollThumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Position = UDim2.new(0, 0, 0, thumbPosition)
    }):Play()
end)

local isDragging = false
local dragStartPosition = nil
local dragStartScrollPosition = nil

ScrollThumb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = true
        dragStartPosition = input.Position.Y
        dragStartScrollPosition = ScrollingFrame.CanvasPosition.Y
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local deltaY = input.Position.Y - dragStartPosition
        local canvasSize = ScrollingFrame.CanvasSize.Y.Offset
        local windowSize = ScrollingFrame.AbsoluteWindowSize.Y
        local maxScroll = canvasSize - windowSize
        local newScrollPosition = dragStartScrollPosition + (deltaY / ScrollBar.AbsoluteSize.Y) * canvasSize
        ScrollingFrame.CanvasPosition = Vector2.new(0, math.clamp(newScrollPosition, 0, maxScroll))
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = false
    end
end)

local CloseSettings = createButton(ScrollingFrame, UDim2.new(0, 40, 0, 40), UDim2.new(0.9, -45, 0.02, 0), "X")
CloseSettings.TextSize = 20
CloseSettings.BackgroundColor3 = ThemeColors[CurrentTheme].Danger

local espToggle, getESPState, setESPState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, (PADDING or 0) + (ELEMENT_HEIGHT or 0) + (SPACING or 0)), "ESP", ESPEnabled)

local KeybindLabel = Instance.new("TextLabel")
KeybindLabel.Size = UDim2.new(0, 250, 0, 30)
KeybindLabel.Position = UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 6 + 20)
KeybindLabel.Text = "Aimbot Keybind: Right Click"
KeybindLabel.BackgroundTransparency = 1
KeybindLabel.TextColor3 = ThemeColors[CurrentTheme].Text
KeybindLabel.TextSize = 14
KeybindLabel.Font = Enum.Font.Gotham
KeybindLabel.TextXAlignment = Enum.TextXAlignment.Left
KeybindLabel.Parent = ScrollingFrame

local ChangeKeybind = createButton(ScrollingFrame, UDim2.new(0, 250, 0, ELEMENT_HEIGHT), UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 6 + 50), "Change Keybind")

SettingsButton.MouseButton1Click:Connect(function()
    if SettingsFrame.Visible then
        TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 0}):Play()
        TweenService:Create(SettingsFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 400, 0, 0), 
            Position = UDim2.new(0.5, -200, 0.5, 0)
        }):Play()
        wait(0.5)
        SettingsFrame.Visible = false
    else
        SettingsFrame.Size = UDim2.new(0, 400, 0, 800) 
        SettingsFrame.Position = UDim2.new(0.5, -200, 0.5, -400) 
        SettingsFrame.Visible = true
        TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 10}):Play()
        TweenService:Create(SettingsFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 400, 0, 800), 
            Position = UDim2.new(0.5, -200, 0.5, -400) 
        }):Play()
    end
end)

CloseSettings.MouseButton1Click:Connect(function()
    TweenService:Create(BlurEffect, TweenInfo.new(0.3), {Size = 0}):Play()
    TweenService:Create(SettingsFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 400, 0, 0), 
        Position = UDim2.new(0.5, -200, 0.5, 0)
    }):Play()
    wait(0.5)
    SettingsFrame.Visible = false
end)

ChangeKeybind.MouseButton1Click:Connect(function()
    KeybindLabel.Text = "Press any key..."
    KeybindLabel.TextColor3 = ThemeColors[CurrentTheme].Highlight
    local inputConnection
    inputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard or 
           input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.MouseButton2 then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Keybind = input.KeyCode
            else
                Keybind = input.UserInputType
            end
            local keyName
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                keyName = "Left Click"
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                keyName = "Right Click"
            else
                keyName = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
            end
            KeybindLabel.Text = "Aimbot Keybind: " .. keyName
            KeybindLabel.TextColor3 = ThemeColors[CurrentTheme].Text
            TweenService:Create(KeybindLabel, TweenInfo.new(0.3), {TextSize = 16}):Play()
            wait(0.3)
            TweenService:Create(KeybindLabel, TweenInfo.new(0.3), {TextSize = 14}):Play()
            inputConnection:Disconnect()
        end
    end)
end)

local WalkSpeedSlider = createSlider(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 8 + 100), "WalkSpeed", 16, 100, 50, function(value)
    updateWalkSpeed(value)
end)

local function createESP(player)
    if not ESPEnabled or not player.Character then return end

    local localRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRootPart then return end

    local targetRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not targetRootPart then return end

    local distance = (localRootPart.Position - targetRootPart.Position).Magnitude
    if distance > MAX_DISTANCE_THRESHOLD then return end  

    if ESPHighlights[player] then
        ESPHighlights[player]:Destroy()
    end

local highlight = Instance.new("Highlight")
highlight.Adornee = player.Character
highlight.FillColor = Color3.new(0, 0, 0)  -- Black
highlight.OutlineColor = Color3.new(1, 1, 1)  -- White
highlight.FillTransparency = 0.5
highlight.OutlineTransparency = 0.3
highlight.Parent = player.Character
ESPHighlights[player] = highlight

end

local function removeESP(player)
    if ESPHighlights[player] then
        ESPHighlights[player]:Destroy()
        ESPHighlights[player] = nil
    end
end

local function applyESPToAllPlayers()
    if not ESPEnabled then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            createESP(player)
        end
    end
end

local function removeESPFromAllPlayers()
    for player, _ in pairs(ESPHighlights) do
        removeESP(player)
    end
end

local function onCharacterAdded(player)
    player.CharacterAdded:Connect(function(character)
        if ESPEnabled then
            wait(0.5) 
            createESP(player)
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        if ESPEnabled then
            wait(0.5)
            createESP(player)
        end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    if ESPEnabled then
        wait(0.5)
        applyESPToAllPlayers()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPHighlights[player] then
        removeESP(player)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    if WalkSpeedEnabled then

        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
        bodyVelocity.P = 1250
        bodyVelocity.Velocity = Vector3.zero
        bodyVelocity.Parent = rootPart

        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
        bodyGyro.D = 150
        bodyGyro.P = 5000
        bodyGyro.CFrame = rootPart.CFrame
        bodyGyro.Parent = rootPart

        humanoid.PlatformStand = true
    else

        humanoid.PlatformStand = false
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPHighlights[player] then
        removeESP(player)
    end
end)

espToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        ESPEnabled = not ESPEnabled
        ESPStatus.Text = "ESP: " .. (ESPEnabled and "On" or "Off")
        ESPStatus.TextColor3 = ESPEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
        ESPIcon.TextColor3 = ESPEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
        if ESPEnabled then
            applyESPToAllPlayers()
        else
            removeESPFromAllPlayers()
        end
    end
end)

local function enableNoclip()
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.Velocity = Vector3.zero
                part.RotVelocity = Vector3.zero
            end
        end
    end
end

local function disableNoclip()
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

local function toggleNoclip()
    NoClipEnabled = not NoClipEnabled
    if NoClipEnabled then
        enableNoclip()
    else
        disableNoclip()
    end
    NoClipStatus.Text = "NoClip: " .. (NoClipEnabled and "On" or "Off")
    NoClipStatus.TextColor3 = NoClipEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
    NoClipIcon.TextColor3 = NoClipEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
end

LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    wait(1)
    if NoClipEnabled then
        enableNoclip()
    end
end)

local NoClipToggle, getNoClipState, setNoClipState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 9 + 100), "NoClip", NoClipEnabled)
NoClipToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        toggleNoclip()
    end
end)

RunService.Heartbeat:Connect(function()
    if ESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local localRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local targetRootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if localRootPart and targetRootPart then
                    local distance = (localRootPart.Position - targetRootPart.Position).Magnitude
                    if distance <= MAX_DISTANCE_THRESHOLD then
                        if not ESPHighlights[player] then
                            createESP(player)
                        end
                    else
                        removeESP(player)
                    end
                end
            end
        end
    end
end)

local function GetClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local mouseLocation = UserInputService:GetMouseLocation()
    local localRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRootPart then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and (not TeamCheckEnabled or not isTeammate(player)) and not isDead(player) then
            local head = player.Character:FindFirstChild("Head")
            if head then
                local distance = (localRootPart.Position - head.Position).Magnitude

                if distance <= MAX_AIMBOT_DISTANCE then
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local cursorDistance = (Vector2.new(screenPosition.X, screenPosition.Y) - mouseLocation).Magnitude
                        if cursorDistance < shortestDistance then
                            shortestDistance = cursorDistance
                            closestPlayer = head
                        end
                    else
                        if distance < shortestDistance then
                            shortestDistance = distance
                            closestPlayer = head
                        end
                    end
                end
            end
        end
    end

    return closestPlayer
end

local function calculateVelocity(part, deltaTime)
    if not part or not part.Position then return Vector3.zero end
    if not part:FindFirstChild("LastPosition") then
        local lastPosition = Instance.new("Vector3Value")
        lastPosition.Name = "LastPosition"
        lastPosition.Value = part.Position
        lastPosition.Parent = part
    end
    local lastPosition = part.LastPosition.Value
    local velocity = (part.Position - lastPosition) / deltaTime
    part.LastPosition.Value = part.Position
    return velocity
end

local function predictPosition(target, deltaTime)
    if not target then return nil end
    local velocity = calculateVelocity(target, deltaTime)
    return target.Position + velocity * deltaTime * 2
end

local lastTime = tick()

local SensitivityLabel = Instance.new("TextLabel")
SensitivityLabel.Size = UDim2.new(0, 250, 0, 30)
SensitivityLabel.Position = UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 7 + 70)
SensitivityLabel.Text = "Aimbot Sensitivity: " .. SENSITIVITY_MULTIPLIER
SensitivityLabel.BackgroundTransparency = 1
SensitivityLabel.TextColor3 = ThemeColors[CurrentTheme].Text
SensitivityLabel.TextSize = 14
SensitivityLabel.Font = Enum.Font.Gotham
SensitivityLabel.TextXAlignment = Enum.TextXAlignment.Left
SensitivityLabel.Parent = ScrollingFrame

local SensitivityTextBox = Instance.new("TextBox")
SensitivityTextBox.Size = UDim2.new(0, 250, 0, ELEMENT_HEIGHT)
SensitivityTextBox.Position = UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 7 + 100)
SensitivityTextBox.Text = tostring(SENSITIVITY_MULTIPLIER)
SensitivityTextBox.BackgroundColor3 = ThemeColors[CurrentTheme].Panel
SensitivityTextBox.BackgroundTransparency = 0.3
SensitivityTextBox.TextColor3 = ThemeColors[CurrentTheme].Text
SensitivityTextBox.TextSize = 14
SensitivityTextBox.Font = Enum.Font.Gotham
SensitivityTextBox.PlaceholderText = "Enter sensitivity (0-5)"
SensitivityTextBox.Parent = ScrollingFrame

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = SensitivityTextBox

local function updateCanvasSize()
    local totalHeight = 0
    for _, child in pairs(ScrollingFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            totalHeight = totalHeight + child.Size.Y.Offset + child.Position.Y.Offset
        end
    end
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + PADDING * 2)
end

updateCanvasSize()

local function updateSensitivity()
    local input = tonumber(SensitivityTextBox.Text)
    if input and input >= 0.000000001 and input <= 5 then
        SENSITIVITY_MULTIPLIER = input
        SensitivityLabel.Text = "Aimbot Sensitivity: " .. string.format("%.9f", SENSITIVITY_MULTIPLIER)
    else
        SensitivityTextBox.Text = tostring(SENSITIVITY_MULTIPLIER) 
    end
end

SensitivityTextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        updateSensitivity()
    end
end)
SensitivityTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    local text = SensitivityTextBox.Text

    local newText = text:gsub("[^%d.]", "")

    local decimalCount = 0
    for char in newText:gmatch("%.") do
        decimalCount = decimalCount + 1
        if decimalCount > 1 then
            newText = newText:sub(1, -2) 
        end
    end
    SensitivityTextBox.Text = newText
end)

local function updateTargetSelection()
    if AimbotEnabled and AimbotToggleEnabled then
        local potentialTarget = GetClosestPlayerToCursor()
        if potentialTarget and not isPartOfLocalPlayer(potentialTarget) and not isTeammate(potentialTarget.Parent) and not isDead(potentialTarget.Parent) then
            Target = potentialTarget
        else
            Target = nil
        end
    end
end

local function isPartOfLocalPlayer(part)
    if not part or not part.Parent then return false end
    if LocalPlayer.Character and part:IsDescendantOf(LocalPlayer.Character) then
        return true
    end
    return false
end

local function updateTargetSelection()
    if AimbotEnabled and AimbotToggleEnabled then
        local potentialTarget = GetClosestPlayerToCursor()
        if potentialTarget and not isPartOfLocalPlayer(potentialTarget) then
            Target = potentialTarget
        else
            Target = nil
        end
    end
end

spawn(function()
    while wait(0.1) do  
        updateTargetSelection()
    end
end)

local AimbotModeLabel = Instance.new("TextLabel")
AimbotModeLabel.Size = UDim2.new(0, 250, 0, 30)
AimbotModeLabel.Position = UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 5)
AimbotModeLabel.Text = "Aimbot Mode: " .. AimbotMode
AimbotModeLabel.BackgroundTransparency = 1
AimbotModeLabel.TextColor3 = ThemeColors[CurrentTheme].Text
AimbotModeLabel.TextSize = 14
AimbotModeLabel.Font = Enum.Font.Gotham
AimbotModeLabel.TextXAlignment = Enum.TextXAlignment.Left
AimbotModeLabel.Parent = ScrollingFrame

local SwitchModeButton = createButton(ScrollingFrame, UDim2.new(0, 250, 0, ELEMENT_HEIGHT), UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 5 + 30), "Switch Aimbot Mode")

SwitchModeButton.MouseButton1Click:Connect(function()
    if AimbotMode == "Hold" then
        AimbotMode = "Toggle"
    else
        AimbotMode = "Hold"
    end

    AimbotModeLabel.Text = "Aimbot Mode: " .. AimbotMode

    TweenService:Create(AimbotModeLabel, TweenInfo.new(0.3), {TextSize = 16}):Play()

    wait(0.3)

    TweenService:Create(AimbotModeLabel, TweenInfo.new(0.3), {TextSize = 14}):Play()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.UserInputType == Keybind or (input.KeyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Keybind) then
            if AimbotToggleEnabled then
                if AimbotMode == "Toggle" then
                    AimbotEnabled = not AimbotEnabled
                    if AimbotEnabled then
                        Target = GetClosestPlayerToCursor() 
                        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                    else
                        Target = nil
                        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    end
                else
                    AimbotEnabled = true
                    Target = GetClosestPlayerToCursor() 
                    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if (input.UserInputType == Keybind) or (input.KeyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Keybind) then
        if AimbotMode == "Hold" then
            AimbotEnabled = false
            Target = nil
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end)

local MIN_DELTA_THRESHOLD = 0.1  

RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    local deltaTime = currentTime - lastTime
    lastTime = currentTime

    if AimbotEnabled and AimbotToggleEnabled then

        if not Target then
            Target = GetClosestPlayerToCursor()
        end

        if Target and Target.Parent and not isPartOfLocalPlayer(Target) and not isTeammate(Target.Parent) then
            local distance = (LocalPlayer.Character.HumanoidRootPart.Position - Target.Position).Magnitude

            if distance <= MAX_AIMBOT_DISTANCE then
                local predictedPosition = predictPosition(Target, deltaTime)
                if predictedPosition then
                    local screenPosition = Camera:WorldToViewportPoint(predictedPosition)
                    local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

                    local deltaX = (screenPosition.X - centerScreen.X) * SENSITIVITY_MULTIPLIER
                    local deltaY = (screenPosition.Y - centerScreen.Y) * SENSITIVITY_MULTIPLIER

                    mousemoverel(deltaX, deltaY)
                end
            else

                Target = nil
            end
        else

            Target = nil
        end
    else
        Target = nil
        AimbotEnabled = false
    end
end)

local function smoothMoveToTarget(targetPosition)
    local mouseLocation = UserInputService:GetMouseLocation()
    local screenPosition = Camera:WorldToViewportPoint(targetPosition)
    local deltaX = (screenPosition.X - mouseLocation.X) * SENSITIVITY_MULTIPLIER
    local deltaY = (screenPosition.Y - mouseLocation.Y) * SENSITIVITY_MULTIPLIER

    local lerpFactor = 0.2  
    local smoothDeltaX = deltaX * lerpFactor
    local smoothDeltaY = deltaY * lerpFactor

    mousemoverel(smoothDeltaX, smoothDeltaY)
end

local TeamCheckToggle, getTeamCheckState, setTeamCheckState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 11 + 100), "Team Check", TeamCheckEnabled)

TeamCheckToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        TeamCheckEnabled = not TeamCheckEnabled
    end
end)


local aimbotToggle, getAimbotState, setAimbotState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 3), "Aimbot", AimbotToggleEnabled)
aimbotToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        AimbotToggleEnabled = not AimbotToggleEnabled
        AimbotEnabled = false
        Target = nil
        AimbotStatus.Text = "Aimbot: " .. (AimbotToggleEnabled and (AimbotEnabled and "On" or "Off") or "Off")
        AimbotStatus.TextColor3 = (AimbotToggleEnabled and AimbotEnabled) and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
        AimbotIcon.TextColor3 = (AimbotToggleEnabled and AimbotEnabled) and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
    end
end)
local function InfiniteJump()
    if not InfiniteJumpEnabled then 
        if InfiniteJumpConnection then
            InfiniteJumpConnection:Disconnect()
            InfiniteJumpConnection = nil
        end
        return 
    end
    if InfiniteJumpConnection then
        InfiniteJumpConnection:Disconnect()
        InfiniteJumpConnection = nil
    end
    InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
end
LocalPlayer.CharacterAdded:Connect(function()
    if InfiniteJumpEnabled then
        InfiniteJump()
    end
end)
local InfiniteJumpToggle, getInfiniteJumpState, setInfiniteJumpState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 2), "Infinite Jump", InfiniteJumpEnabled)
InfiniteJumpToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        InfiniteJumpEnabled = not InfiniteJumpEnabled
        InfiniteJumpStatus.Text = "Infinite Jump: " .. (InfiniteJumpEnabled and "On" or "Off")
        InfiniteJumpStatus.TextColor3 = InfiniteJumpEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
        InfiniteJumpIcon.TextColor3 = InfiniteJumpEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
        if InfiniteJumpEnabled then
            InfiniteJump()
        else
            if InfiniteJumpConnection then
                InfiniteJumpConnection:Disconnect()
                InfiniteJumpConnection = nil
            end
        end
    end
end)

local function handleAutoShoot()
    local currentTime = tick()
    if not AutoShootEnabled then 
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and AutoShootIsControllingMouse then
            mouse1release()
            AutoShootIsControllingMouse = false
        end
        return 
    end
    if UserIsHoldingMouse then
        AutoShootIsControllingMouse = false
        return
    end
    if currentTime - lastTargetTime < 0.05 then
        return
    end
    local mouseLocation = UserInputService:GetMouseLocation()
    local isTargetDetected = false
    local closestDistance = 100 
    local closestPart = nil
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and LocalPlayer.Character and (not TeamCheckEnabled or not isTeammate(player)) and not isDead(player) then
            local character = player.Character
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            local head = character:FindFirstChild("Head")
            local partsToCheck = {head, humanoidRootPart}
            for _, part in pairs(partsToCheck) do
                if part and not isPartOfLocalPlayer(part) then
                    local screenPosition, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local partScreenPosition = Vector2.new(screenPosition.X, screenPosition.Y)
                        local mouseDistance = (partScreenPosition - mouseLocation).Magnitude
                        if mouseDistance < closestDistance then
                            closestDistance = mouseDistance
                            closestPart = part
                        end
                    end
                end
            end
        end
    end
    local wasTargetDetected = AutoShootIsControllingMouse
    if closestPart then
        local ray = Ray.new(
            Camera.CFrame.Position, 
            (closestPart.Position - Camera.CFrame.Position).Unit * 1000
        )
        local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
        if hit and hit:IsDescendantOf(closestPart.Parent) and not isPartOfLocalPlayer(hit) then
            isTargetDetected = true
            lastTargetTime = currentTime
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                mouse1press()
                AutoShootIsControllingMouse = true
            end
        end
    end
    if not isTargetDetected and wasTargetDetected then
        if not AutoShootCooldown then
            AutoShootCooldown = true
            spawn(function()
                wait(0.2) 
                if AutoShootIsControllingMouse and not isTargetDetected then
                    mouse1release()
                    AutoShootIsControllingMouse = false
                end
                AutoShootCooldown = false
            end)
        end
    end
end

local AutoShootCooldown = false
local UserIsHoldingMouse = false
local AutoShootIsControllingMouse = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        UserIsHoldingMouse = true
        AutoShootIsControllingMouse = false
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        UserIsHoldingMouse = false
    end
end)

RunService.Heartbeat:Connect(handleAutoShoot)
local autoShootToggle, getAutoShootState, setAutoShootState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 4), "Auto Shoot", AutoShootEnabled)
autoShootToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        AutoShootEnabled = not AutoShootEnabled
        AutoShootStatus.Text = "Auto Shoot: " .. (AutoShootEnabled and "On" or "Off")
        AutoShootStatus.TextColor3 = AutoShootEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
        AutoShootIcon.TextColor3 = AutoShootEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 150)
    end
end)

RunService.RenderStepped:Connect(handleAutoShoot)
LocalPlayer.CharacterAdded:Connect(function(character)
    if ESPEnabled then
        applyESPToAllPlayers()
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if ESPHighlights[player] then
        removeESP(player)
    end
end)

local lastUIUpdateTime = 0

local WalkSpeedToggle, getWalkSpeedState, setWalkSpeedState = createToggle(ScrollingFrame, UDim2.new(0.1, 0, 0, PADDING + (ELEMENT_HEIGHT + SPACING) * 10 + 100), "WalkSpeed", WalkSpeedEnabled)

WalkSpeedToggle:GetChildren()[2].InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        WalkSpeedEnabled = not WalkSpeedEnabled
        WalkSpeedStatus.Text = "WalkSpeed: " .. (WalkSpeedEnabled and "On" or "Off")
        WalkSpeedStatus.TextColor3 = WalkSpeedEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
        WalkSpeedIcon.TextColor3 = WalkSpeedEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)

        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local rootPart = character:FindFirstChild("HumanoidRootPart")

            if WalkSpeedEnabled then

                local bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
                bodyVelocity.P = 1250
                bodyVelocity.Velocity = Vector3.zero
                bodyVelocity.Parent = rootPart

                local bodyGyro = Instance.new("BodyGyro")
                bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
                bodyGyro.D = 150
                bodyGyro.P = 5000
                bodyGyro.CFrame = rootPart.CFrame
                bodyGyro.Parent = rootPart

                humanoid.PlatformStand = true
            else

                humanoid.PlatformStand = false

                local bodyVelocity = rootPart:FindFirstChild("BodyVelocity")
                if bodyVelocity then
                    bodyVelocity:Destroy()
                end

                local bodyGyro = rootPart:FindFirstChild("BodyGyro")
                if bodyGyro then
                    bodyGyro:Destroy()
                end
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(MAX_FORCE, MAX_FORCE, MAX_FORCE)
    bodyVelocity.P = 1250
    bodyVelocity.Velocity = Vector3.zero
    bodyVelocity.Parent = rootPart

    if WalkSpeedEnabled then
        humanoid.WalkSpeed = MOVE_SPEED
    else
        humanoid.WalkSpeed = DefaultWalkSpeed
        bodyVelocity.Velocity = Vector3.zero
    end
end)

local DiscordButton = createButton(ScreenGui, UDim2.new(0, 110, 0, 40), UDim2.new(0.9, -240, 0.05, 0), "Discord")

local function copyToClipboard(text)
    local clipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
    if clipboard then
        clipboard(text)
    else
        warn("Clipboard function not found. Unable to copy text.")
    end
end

DiscordButton.MouseButton1Click:Connect(function()
    local discordLink = "https://discord.gg/e52GujVvbN"
    copyToClipboard(discordLink)

    DiscordButton.Text = "Copied"

    wait(2)
    DiscordButton.Text = "Discord"
end)

local function updateUI()
    local currentTime = tick()
    if currentTime - lastUIUpdateTime < 0.2 then return end
    lastUIUpdateTime = currentTime
    ESPStatus.Text = "ESP: " .. (ESPEnabled and "On" or "Off")
    ESPStatus.TextColor3 = ESPEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    ESPIcon.TextColor3 = ESPEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    InfiniteJumpStatus.Text = "Infinite Jump: " .. (InfiniteJumpEnabled and "On" or "Off")
    InfiniteJumpStatus.TextColor3 = InfiniteJumpEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    InfiniteJumpIcon.TextColor3 = InfiniteJumpEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    AimbotStatus.Text = "Aimbot: " .. (AimbotToggleEnabled and (AimbotEnabled and "On" or "Off") or "Off")
    AimbotStatus.TextColor3 = (AimbotToggleEnabled and AimbotEnabled) and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    AimbotIcon.TextColor3 = (AimbotToggleEnabled and AimbotEnabled) and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    AutoShootStatus.Text = "Auto Shoot: " .. (AutoShootEnabled and "On" or "Off")
    AutoShootStatus.TextColor3 = AutoShootEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    AutoShootIcon.TextColor3 = AutoShootEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    WalkSpeedStatus.Text = "WalkSpeed: " .. (WalkSpeedEnabled and "On" or "Off")
    WalkSpeedStatus.TextColor3 = WalkSpeedEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    WalkSpeedIcon.TextColor3 = WalkSpeedEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    TeamCheckStatus.Text = "Team Check: " .. (TeamCheckEnabled and "On" or "Off")
    TeamCheckStatus.TextColor3 = TeamCheckEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
    TeamCheckIcon.TextColor3 = TeamCheckEnabled and ThemeColors[CurrentTheme].Accent or Color3.fromRGB(150, 150, 170)
end

updateUI()