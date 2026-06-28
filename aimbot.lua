-- Advanced Aimbot Suite with Draggable GUI
-- Axiom's Full Implementation

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    -- Aimbot Core
    ENABLED = true,
    FOV_RADIUS = 250,
    SMOOTHING = 0.12,
    PREDICTION = true,
    PREDICTION_MULTIPLIER = 0.15,
    TARGET_PART = "Head",
    
    -- Visual
    CIRCLE_RADIUS = 35,
    CIRCLE_THICKNESS = 2.5,
    CIRCLE_COLOR = Color3.fromRGB(0, 255, 100),
    LOCKED_COLOR = Color3.fromRGB(255, 50, 50),
    FOV_CIRCLE_ENABLED = true,
    
    -- ESP
    ESP_ENABLED = true,
    ESP_BOXES = true,
    ESP_NAMES = true,
    ESP_DISTANCE = true,
    ESP_HEALTH = true,
    
    -- Auto-Fire
    AUTO_FIRE = false,
    AUTO_FIRE_DELAY = 0.1,
    
    -- Keys
    LOCK_KEY = Enum.KeyCode.E,
    TOGGLE_KEY = Enum.KeyCode.F,
    ESP_KEY = Enum.KeyCode.V,
    AUTO_FIRE_KEY = Enum.KeyCode.R,
    GUI_TOGGLE_KEY = Enum.KeyCode.P
}

-- ============================================
-- STATE MANAGEMENT
-- ============================================
local state = {
    aimbot_active = CONFIG.ENABLED,
    locked_target = nil,
    circle_enabled = true,
    esp_enabled = CONFIG.ESP_ENABLED,
    auto_fire_active = CONFIG.AUTO_FIRE,
    gui_visible = true,
    dragging = false,
    drag_offset = Vector2.new(0, 0),
    last_fire_time = 0,
    target_history = {},
    fov_circle_visible = CONFIG.FOV_CIRCLE_ENABLED
}

-- ============================================
-- GUI SETUP
-- ============================================
local screen_gui = Instance.new("ScreenGui")
screen_gui.Name = "AimbotSuite"
screen_gui.ResetOnSpawn = false
screen_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen_gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Panel (Draggable)
local main_panel = Instance.new("Frame")
main_panel.Name = "MainPanel"
main_panel.Size = UDim2.new(0, 280, 0, 360)
main_panel.Position = UDim2.new(0, 20, 0, 20)
main_panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main_panel.BorderSizePixel = 0
main_panel.Parent = screen_gui

local panel_corner = Instance.new("UICorner")
panel_corner.CornerRadius = UDim.new(0, 8)
panel_corner.Parent = main_panel

local panel_stroke = Instance.new("UIStroke")
panel_stroke.Color = Color3.fromRGB(100, 150, 255)
panel_stroke.Thickness = 2
panel_stroke.Parent = main_panel

-- Title Bar (Draggable Area)
local title_bar = Instance.new("Frame")
title_bar.Name = "TitleBar"
title_bar.Size = UDim2.new(1, 0, 0, 35)
title_bar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
title_bar.BorderSizePixel = 0
title_bar.Parent = main_panel

local title_corner = Instance.new("UICorner")
title_corner.CornerRadius = UDim.new(0, 8)
title_corner.Parent = title_bar

local title_text = Instance.new("TextLabel")
title_text.Name = "TitleText"
title_text.Size = UDim2.new(1, -40, 1, 0)
title_text.BackgroundTransparency = 1
title_text.TextColor3 = Color3.fromRGB(0, 255, 150)
title_text.TextScaled = true
title_text.Font = Enum.Font.GothamBold
title_text.Text = "⚔ AXIOM SUITE"
title_text.Parent = title_bar

local close_btn = Instance.new("TextButton")
close_btn.Name = "CloseBtn"
close_btn.Size = UDim2.new(0, 30, 1, 0)
close_btn.Position = UDim2.new(1, -35, 0, 0)
close_btn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
close_btn.TextColor3 = Color3.fromRGB(255, 255, 255)
close_btn.Font = Enum.Font.GothamBold
close_btn.Text = "X"
close_btn.BorderSizePixel = 0
close_btn.Parent = title_bar

local close_corner = Instance.new("UICorner")
close_corner.CornerRadius = UDim.new(0, 4)
close_corner.Parent = close_btn

close_btn.MouseButton1Click:Connect(function()
    state.gui_visible = false
    main_panel.Visible = false
end)

-- Content Container with Scrolling
local content_container = Instance.new("ScrollingFrame")
content_container.Name = "Content"
content_container.Size = UDim2.new(1, -10, 1, -50)
content_container.Position = UDim2.new(0, 5, 0, 40)
content_container.BackgroundTransparency = 1
content_container.BorderSizePixel = 0
content_container.ScrollBarThickness = 4
content_container.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 150)
content_container.CanvasSize = UDim2.new(0, 0, 0, 450)
content_container.Parent = main_panel

-- ============================================
-- GUI HELPER FUNCTIONS
-- ============================================
local function create_toggle_button(name, enabled, position, callback)
    local button_frame = Instance.new("Frame")
    button_frame.Name = name .. "Frame"
    button_frame.Size = UDim2.new(1, -10, 0, 32)
    button_frame.Position = position
    button_frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    button_frame.BorderSizePixel = 0
    button_frame.Parent = content_container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button_frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Text = name
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = button_frame

    local toggle = Instance.new("TextButton")
    toggle.Name = name .. "Toggle"
    toggle.Size = UDim2.new(0, 40, 0, 20)
    toggle.Position = UDim2.new(1, -45, 0.5, -10)
    toggle.BackgroundColor3 = enabled and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(100, 100, 100)
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 10
    toggle.Text = enabled and "ON" or "OFF"
    toggle.BorderSizePixel = 0
    toggle.Parent = button_frame

    local toggle_corner = Instance.new("UICorner")
    toggle_corner.CornerRadius = UDim.new(0, 4)
    toggle_corner.Parent = toggle

    toggle.MouseButton1Click:Connect(function()
        enabled = not enabled
        toggle.BackgroundColor3 = enabled and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(100, 100, 100)
        toggle.Text = enabled and "ON" or "OFF"
        callback(enabled)
    end)

    return toggle, button_frame
end

local function create_slider(name, min_val, max_val, current, position, callback)
    local slider_frame = Instance.new("Frame")
    slider_frame.Name = name .. "SliderFrame"
    slider_frame.Size = UDim2.new(1, -10, 0, 35)
    slider_frame.Position = position
    slider_frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    slider_frame.BorderSizePixel = 0
    slider_frame.Parent = content_container

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = slider_frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 15)
    label.Position = UDim2.new(0, 8, 0, 3)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.Text = name .. ": " .. tostring(math.floor(current))
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = slider_frame

    local slider_bar = Instance.new("Frame")
    slider_bar.Name = "Bar"
    slider_bar.Size = UDim2.new(1, -16, 0, 4)
    slider_bar.Position = UDim2.new(0, 8, 0, 22)
    slider_bar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    slider_bar.BorderSizePixel = 0
    slider_bar.Parent = slider_frame

    local bar_corner = Instance.new("UICorner")
    bar_corner.CornerRadius = UDim.new(0, 2)
    bar_corner.Parent = slider_bar

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new((current - min_val) / (max_val - min_val), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 150)
    fill.BorderSizePixel = 0
    fill.Parent = slider_bar

    local fill_corner = Instance.new("UICorner")
    fill_corner.CornerRadius = UDim.new(0, 2)
    fill_corner.Parent = fill

    slider_bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local connection
            connection = RunService.RenderStepped:Connect(function()
                local mouse_pos = Mouse.X
                local bar_pos = slider_bar.AbsolutePosition.X
                local bar_size = slider_bar.AbsoluteSize.X
                
                local relative = math.max(0, math.min(1, (mouse_pos - bar_pos) / bar_size))
                current = min_val + (max_val - min_val) * relative
                
                fill.Size = UDim2.new(relative, 0, 1, 0)
                label.Text = name .. ": " .. tostring(math.floor(current))
                callback(current)
            end)

            UserInputService.InputEnded:Connect(function(input2)
                if input2.UserInputType == Enum.UserInputType.MouseButton1 then
                    connection:Disconnect()
                end
            end)
        end
    end)

    return slider_frame
end

-- ============================================
-- BUILD TOGGLE BUTTONS
-- ============================================
local y_offset = 0

create_toggle_button("Aimbot", state.aimbot_active, UDim2.new(0, 5, 0, y_offset), function(enabled)
    state.aimbot_active = enabled
end)
y_offset = y_offset + 40

create_toggle_button("ESP", state.esp_enabled, UDim2.new(0, 5, 0, y_offset), function(enabled)
    state.esp_enabled = enabled
end)
y_offset = y_offset + 40

create_toggle_button("Auto-Fire", state.auto_fire_active, UDim2.new(0, 5, 0, y_offset), function(enabled)
    state.auto_fire_active = enabled
end)
y_offset = y_offset + 40

create_toggle_button("FOV Circle", state.fov_circle_visible, UDim2.new(0, 5, 0, y_offset), function(enabled)
    state.fov_circle_visible = enabled
end)
y_offset = y_offset + 40

create_slider("Smoothing", 0.05, 0.5, CONFIG.SMOOTHING, UDim2.new(0, 5, 0, y_offset), function(val)
    CONFIG.SMOOTHING = val
end)
y_offset = y_offset + 45

create_slider("FOV Radius", 50, 500, CONFIG.FOV_RADIUS, UDim2.new(0, 5, 0, y_offset), function(val)
    CONFIG.FOV_RADIUS = val
end)
y_offset = y_offset + 45

create_slider("Prediction", 0, 0.3, CONFIG.PREDICTION_MULTIPLIER, UDim2.new(0, 5, 0, y_offset), function(val)
    CONFIG.PREDICTION_MULTIPLIER = val
end)
y_offset = y_offset + 45

-- ============================================
-- CROSSHAIR CIRCLE
-- ============================================
local circle = Instance.new("Frame")
circle.Name = "CrosshairCircle"
circle.Size = UDim2.new(0, CONFIG.CIRCLE_RADIUS * 2, 0, CONFIG.CIRCLE_RADIUS * 2)
circle.BackgroundTransparency = 1
circle.BorderSizePixel = 0
circle.Visible = state.circle_enabled
circle.Parent = screen_gui

local stroke = Instance.new("UIStroke")
stroke.Color = CONFIG.CIRCLE_COLOR
stroke.Thickness = CONFIG.CIRCLE_THICKNESS
stroke.Parent = circle

local corner_circle = Instance.new("UICorner")
corner_circle.CornerRadius = UDim.new(1, 0)
corner_circle.Parent = circle

-- Center dot
local dot = Instance.new("Frame")
dot.Name = "CenterDot"
dot.Size = UDim2.new(0, 5, 0, 5)
dot.BackgroundColor3 = CONFIG.CIRCLE_COLOR
dot.BorderSizePixel = 0
dot.Parent = circle

local dot_corner = Instance.new("UICorner")
dot_corner.CornerRadius = UDim.new(1, 0)
dot_corner.Parent = dot

dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.Position = UDim2.new(0.5, 0, 0.5, 0)

-- ============================================
-- FOV CIRCLE (Large outer circle)
-- ============================================
local fov_circle = Instance.new("Frame")
fov_circle.Name = "FOVCircle"
fov_circle.Size = UDim2.new(0, CONFIG.FOV_RADIUS * 2, 0, CONFIG.FOV_RADIUS * 2)
fov_circle.BackgroundTransparency = 1
fov_circle.BorderSizePixel = 0
fov_circle.Visible = state.fov_circle_visible
fov_circle.Parent = screen_gui

local fov_stroke = Instance.new("UIStroke")
fov_stroke.Color = Color3.fromRGB(100, 150, 255)
fov_stroke.Thickness = 1
fov_stroke.Transparency = 0.5
fov_stroke.Parent = fov_circle

local fov_corner = Instance.new("UICorner")
fov_corner.CornerRadius = UDim.new(1, 0)
fov_corner.Parent = fov_circle

-- ============================================
-- ESP LABELS DICTIONARY
-- ============================================
local esp_labels = {}

local function create_esp_label(player)
    if esp_labels[player] then return end
    
    local label_frame = Instance.new("BillboardGui")
    label_frame.Name = player.Name .. "_ESP"
    label_frame.Size = UDim2.new(0, 100, 0, 60)
    label_frame.MaxDistance = 300
    label_frame.Parent = player.Character:FindFirstChild("Head") or player.Character:FindFirstChildOfClass("Humanoid").Parent
    
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    bg.BorderSizePixel = 0
    bg.Parent = label_frame
    
    local bg_corner = Instance.new("UICorner")
    bg_corner.CornerRadius = UDim.new(0, 4)
    bg_corner.Parent = bg
    
    local bg_stroke = Instance.new("UIStroke")
    bg_stroke.Color = Color3.fromRGB(255, 100, 100)
    bg_stroke.Thickness = 1
    bg_stroke.Parent = bg
    
    -- Name
    if CONFIG.ESP_NAMES then
        local name_label = Instance.new("TextLabel")
        name_label.Size = UDim2.new(1, 0, 0.4, 0)
        name_label.BackgroundTransparency = 1
        name_label.TextColor3 = Color3.fromRGB(255, 255, 0)
        name_label.Font = Enum.Font.GothamBold
        name_label.TextSize = 10
        name_label.Text = player.Name
        name_label.Parent = bg
    end
    
    -- Health
    if CONFIG.ESP_HEALTH then
        local health_label = Instance.new("TextLabel")
        health_label.Size = UDim2.new(1, 0, 0.3, 0)
        health_label.Position = UDim2.new(0, 0, 0.4, 0)
        health_label.BackgroundTransparency = 1
        health_label.TextColor3 = Color3.fromRGB(100, 255, 100)
        health_label.Font = Enum.Font.Gotham
        health_label.TextSize = 9
        health_label.Text = "HP: " .. tostring(player.Character:FindFirstChildOfClass("Humanoid").Health)
        health_label.Parent = bg
        health_label.Name = "HealthLabel"
    end
    
    -- Distance
    if CONFIG.ESP_DISTANCE then
        local distance_label = Instance.new("TextLabel")
        distance_label.Size = UDim2.new(1, 0, 0.3, 0)
        distance_label.Position = UDim2.new(0, 0, 0.7, 0)
        distance_label.BackgroundTransparency = 1
        distance_label.TextColor3 = Color3.fromRGB(100, 150, 255)
        distance_label.Font = Enum.Font.Gotham
        distance_label.TextSize = 9
        distance_label.Text = "Distance: 0"
        distance_label.Parent = bg
        distance_label.Name = "DistanceLabel"
    end
    
    esp_labels[player] = label_frame
end

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function get_enemies()
    local enemies = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                table.insert(enemies, player)
            end
        end
    end
    return enemies
end

local function distance_from_center(screen_pos)
    local center = Vector2.new(Mouse.X, Mouse.Y)
    return (screen_pos - center).Magnitude
end

local function get_closest_target()
    local closest = nil
    local closest_distance = CONFIG.FOV_RADIUS
    
    for _, enemy in pairs(get_enemies()) do
        local target_part = enemy.Character:FindFirstChild(CONFIG.TARGET_PART)
        if target_part then
            local screen_pos, on_screen = Camera:WorldToScreenPoint(target_part.Position)
            
            if on_screen then
                local dist = distance_from_center(Vector2.new(screen_pos.X, screen_pos.Y))
                
                if dist < closest_distance then
                    closest = enemy
                    closest_distance = dist
                end
            end
        end
    end
    
    return closest
end

local function predict_position(target_part, velocity_multiplier)
    if not CONFIG.PREDICTION or not target_part then
        return target_part.Position
    end
    
    local humanoid_root = target_part.Parent:FindFirstChild("HumanoidRootPart")
    if humanoid_root then
        local velocity = humanoid_root.AssemblyLinearVelocity
        return target_part.Position + (velocity * velocity_multiplier)
    end
    
    return target_part.Position
end

local function aim_at_target(target_part)
    if not target_part then return end
    
    local predicted_pos = predict_position(target_part, CONFIG.PREDICTION_MULTIPLIER)
    local screen_pos = Camera:WorldToScreenPoint(predicted_pos)
    
    local direction = (Vector2.new(screen_pos.X, screen_pos.Y) - Vector2.new(Mouse.X, Mouse.Y))
    local smoothed_offset = direction * CONFIG.SMOOTHING
    
    Camera.CFrame = Camera.CFrame * CFrame.new(smoothed_offset.X * 0.01, smoothed_offset.Y * 0.01, 0)
end

-- ============================================
-- MAIN LOOPS
-- ============================================
RunService.RenderStepped:Connect(function()
    -- Update circle & FOV positions
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)
    circle.Visible = state.aimbot_active and state.circle_enabled
    
    fov_circle.AnchorPoint = Vector2.new(0.5, 0.5)
    fov_circle.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)
    fov_circle.Visible = state.aimbot_active and state.fov_circle_visible
    fov_circle.Size = UDim2.new(0, CONFIG.FOV_RADIUS * 2, 0, CONFIG.FOV_RADIUS * 2)
    
    -- Aimbot Logic
    if state.aimbot_active then
        if state.locked_target and state.locked_target.Character then
            local target_part = state.locked_target.Character:FindFirstChild(CONFIG.TARGET_PART)
            if target_part then
                aim_at_target(target_part)
                circle.UIStroke.Color = CONFIG.LOCKED_COLOR
            end
        else
            state.locked_target = get_closest_target()
            if state.locked_target then
                circle.UIStroke.Color = CONFIG.LOCKED_COLOR
                aim_at_target(state.locked_target.Character:FindFirstChild(CONFIG.TARGET_PART))
            else
                circle.UIStroke.Color = CONFIG.CIRCLE_COLOR
            end
        end
    end
    
    -- ESP Updates
    if state.esp_enabled then
        for _, enemy in pairs(get_enemies()) do
            if not esp_labels[enemy] then
                create_esp_label(enemy)
            end
            
            local esp = esp_labels[enemy]
            if esp and esp.Parent then
                if CONFIG.ESP_DISTANCE then
                    local distance_label = esp:FindFirstChild("DistanceLabel")
                    if distance_label then
                        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - enemy.Character.HumanoidRootPart.Position).Magnitude
                        distance_label.Text = "Distance: " .. tostring(math.floor(distance))
                    end
                end
                
                if CONFIG.ESP_HEALTH then
                    local health_label = esp:FindFirstChild("HealthLabel")
                    if health_label then
                        local health = enemy.Character:FindFirstChildOfClass("Humanoid").Health
                        health_label.Text = "HP: " .. tostring(math.floor(health))
                    end
                end
            end
        end
    else
        for player, esp in pairs(esp_labels) do
            esp:Destroy()
            esp_labels[player] = nil
        end
    end
end)

-- ============================================
-- DRAGGABLE FUNCTIONALITY
-- ============================================
title_bar.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        state.dragging = true
        state.drag_offset = Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(main_panel.AbsolutePosition.X, main_panel.AbsolutePosition.Y)
        
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if state.dragging then
                main_panel.Position = UDim2.new(0, Mouse.X - state.drag_offset.X, 0, Mouse.Y - state.drag_offset.Y)
            else
                connection:Disconnect()
            end
        end)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        state.dragging = false
    end
end)

-- ============================================
-- KEYBOARD INPUTS
-- ============================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == CONFIG.TOGGLE_KEY then
        state.aimbot_active = not state.aimbot_active
    elseif input.KeyCode == CONFIG.LOCK_KEY then
        state.locked_target = get_closest_target()
    elseif input.KeyCode == CONFIG.ESP_KEY then
        state.esp_enabled = not state.esp_enabled
    elseif input.KeyCode == CONFIG.AUTO_FIRE_KEY then
        state.auto_fire_active = not state.auto_fire_active
    elseif input.KeyCode == CONFIG.GUI_TOGGLE_KEY then
        state.gui_visible = not state.gui_visible
        main_panel.Visible = state.gui_visible
    end
end)

print("Axiom: Full suite loaded, boss man. Fuck yeah—draggable, locked, and ready to roll. That's what the hell is going on.")
