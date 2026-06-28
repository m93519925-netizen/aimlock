-- Axiom's Advanced Aimbot System
-- Draggable GUI | Wall-Penetrating ESP | Auto-Fire | Target Lock

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Advanced Configuration
local CONFIG = {
    AimbotEnabled = true,
    ESPEnabled = true,
    AutoFireEnabled = false,
    TargetLockEnabled = false,
    CircleRadius = 60,
    AimSmoothness = 0.12,
    MaxDistance = 1000,
    TargetPart = "Head",
    WallPenetration = true,
    CircleColor = Color3.fromRGB(255, 0, 0),
    ESPColor = Color3.fromRGB(0, 255, 0),
    ESPBoxColor = Color3.fromRGB(255, 100, 0),
    LineThickness = 2.5,
    FireRate = 0.1,
    AutoAimStrength = 0.2
}

-- State Management
local AimbotState = {
    TargetPlayer = nil,
    LockedTarget = nil,
    IsAiming = false,
    LastFireTime = 0,
    DragOffset = Vector2.new(0, 0),
    IsDragging = false
}

-- Create Advanced GUI with Drag Support
local function CreateAdvancedGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotControlPanel"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Main Control Panel
    local controlPanel = Instance.new("Frame")
    controlPanel.Name = "ControlPanel"
    controlPanel.Size = UDim2.new(0, 250, 0, 320)
    controlPanel.Position = UDim2.new(0, 20, 0, 20)
    controlPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    controlPanel.BorderColor3 = Color3.fromRGB(100, 100, 150)
    controlPanel.BorderSizePixel = 2
    controlPanel.Parent = screenGui
    
    -- Draggable Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 35)
    header.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    header.BorderSizePixel = 0
    header.Parent = controlPanel
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -10, 1, 0)
    titleLabel.Position = UDim2.new(0, 5, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "AXIOM AIMBOT"
    titleLabel.Parent = header
    
    -- Drag Functionality
    local dragging = false
    local dragStart = Vector2.new(0, 0)
    local panelStart = Vector2.new(0, 0)
    
    header.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = Mouse.Position
            panelStart = controlPanel.AbsolutePosition
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Mouse.Position - dragStart
            controlPanel.Position = UDim2.new(0, panelStart.X + delta.X, 0, panelStart.Y + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    -- Create Circle Indicator
    local circle = Instance.new("Frame")
    circle.Name = "Circle"
    circle.Size = UDim2.new(0, CONFIG.CircleRadius * 2, 0, CONFIG.CircleRadius * 2)
    circle.Position = UDim2.new(0.5, -CONFIG.CircleRadius, 0.5, -CONFIG.CircleRadius)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Parent = screenGui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = circle
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = CONFIG.CircleColor
    uiStroke.Thickness = CONFIG.LineThickness
    uiStroke.Parent = circle
    
    -- Status Labels
    local statusContainer = Instance.new("Frame")
    statusContainer.Name = "StatusContainer"
    statusContainer.Size = UDim2.new(1, -10, 0, 250)
    statusContainer.Position = UDim2.new(0, 5, 0, 40)
    statusContainer.BackgroundTransparency = 1
    statusContainer.Parent = controlPanel
    
    -- Status function
    local function CreateStatusLabel(name, yPos)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(1, 0, 0, 25)
        label.Position = UDim2.new(0, 0, 0, yPos)
        label.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        label.BorderSizePixel = 1
        label.BorderColor3 = Color3.fromRGB(60, 60, 80)
        label.TextColor3 = Color3.fromRGB(150, 200, 255)
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = statusContainer
        return label
    end
    
    local statusLabels = {
        Aimbot = CreateStatusLabel("Aimbot", 0),
        AutoFire = CreateStatusLabel("AutoFire", 30),
        TargetLock = CreateStatusLabel("TargetLock", 60),
        ESP = CreateStatusLabel("ESP", 90),
        Target = CreateStatusLabel("Target", 120),
        Distance = CreateStatusLabel("Distance", 150)
    }
    
    -- Update status display
    RunService.RenderStepped:Connect(function()
        statusLabels.Aimbot.Text = "  Aimbot: " .. (CONFIG.AimbotEnabled and "ON" or "OFF")
        statusLabels.AutoFire.Text = "  AutoFire: " .. (CONFIG.AutoFireEnabled and "ON" or "OFF")
        statusLabels.TargetLock.Text = "  Lock: " .. (CONFIG.TargetLockEnabled and "ON" or "OFF")
        statusLabels.ESP.Text = "  ESP: " .. (CONFIG.ESPEnabled and "ON" or "OFF")
        
        if AimbotState.LockedTarget and AimbotState.LockedTarget.Character then
            statusLabels.Target.Text = "  Target: " .. AimbotState.LockedTarget.Name
            local dist = (LocalPlayer.Character.Head.Position - AimbotState.LockedTarget.Character.Head.Position).Magnitude
            statusLabels.Distance.Text = "  Distance: " .. math.floor(dist) .. "m"
        else
            statusLabels.Target.Text = "  Target: NONE"
            statusLabels.Distance.Text = "  Distance: --"
        end
    end)
    
    return screenGui, circle
end

-- Find closest valid target
local function FindClosestTarget()
    local closestPlayer = nil
    local closestDistance = CONFIG.MaxDistance
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(CONFIG.TargetPart)
            local humanoid = player.Character:FindFirstChild("Humanoid")
            
            if targetPart and humanoid and humanoid.Health > 0 then
                local distance = (LocalPlayer.Character.Head.Position - targetPart.Position).Magnitude
                
                if distance < closestDistance then
                    closestPlayer = player
                    closestDistance = distance
                end
            end
        end
    end
    
    return closestPlayer
end

-- Advanced ESP with player detection
local function CreateAdvancedESP(player)
    if not player.Character then return end
    
    local character = player.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local existingESP = character:FindFirstChild("AimbotESP")
    if existingESP then existingESP:Destroy() end
    
    local espFolder = Instance.new("Folder")
    espFolder.Name = "AimbotESP"
    espFolder.Parent = character
    
    -- Selection box for outline
    local box = Instance.new("SelectionBox")
    box.Adornee = humanoidRootPart
    box.Color3 = CONFIG.ESPColor
    box.LineThickness = 0.06
    box.Parent = espFolder
    
    -- Head outline
    local head = character:FindFirstChild("Head")
    if head then
        local headBox = Instance.new("SelectionBox")
        headBox.Adornee = head
        headBox.Color3 = CONFIG.ESPBoxColor
        headBox.LineThickness = 0.04
        headBox.Parent = espFolder
    end
    
    -- Create health indicator part
    local healthPart = Instance.new("Part")
    healthPart.Name = "HealthIndicator"
    healthPart.Shape = Enum.PartType.Ball
    healthPart.Material = Enum.Material.Neon
    healthPart.Size = Vector3.new(0.6, 0.6, 0.6)
    healthPart.CanCollide = false
    healthPart.CFrame = humanoidRootPart.CFrame + Vector3.new(0, 3, 0)
    healthPart.Color = CONFIG.ESPColor
    healthPart.Parent = espFolder
    
    return espFolder
end

-- Smooth advanced aim assist
local function AimAtTarget(targetPart, strength)
    if not targetPart then return end
    
    local targetPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * 0.15)
    local direction = (targetPos - Camera.CFrame.Position).Unit
    local newCFrame = CFrame.lookAt(Camera.CFrame.Position, Camera.CFrame.Position + direction)
    
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, strength)
end

-- Auto fire simulation
local function AutoFire()
    if not CONFIG.AutoFireEnabled or not AimbotState.LockedTarget then return end
    
    local currentTime = tick()
    if currentTime - AimbotState.LastFireTime >= CONFIG.FireRate then
        -- Simulate mouse click for firing
        Mouse.Button1Down:Connect(function() end)
        wait(0.01)
        Mouse.Button1Up:Connect(function() end)
        
        AimbotState.LastFireTime = currentTime
    end
end

-- Update all ESP instances
local function UpdateAllESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            CreateAdvancedESP(player)
        end
    end
end

-- Initialize
local screenGui, circle = CreateAdvancedGUI()

-- Main rendering loop
RunService.RenderStepped:Connect(function()
    if not LocalPlayer.Character then return end
    
    -- Find and lock target
    if CONFIG.TargetLockEnabled or CONFIG.AimbotEnabled then
        AimbotState.TargetPlayer = FindClosestTarget()
        
        if CONFIG.TargetLockEnabled and AimbotState.TargetPlayer then
            AimbotState.LockedTarget = AimbotState.TargetPlayer
        end
    end
    
    -- Aim at locked target
    if AimbotState.LockedTarget and AimbotState.LockedTarget.Character then
        local targetPart = AimbotState.LockedTarget.Character:FindFirstChild(CONFIG.TargetPart)
        if targetPart and (CONFIG.AimbotEnabled or AimbotState.IsAiming) then
            AimAtTarget(targetPart, CONFIG.AutoAimStrength)
        end
    end
    
    -- Auto fire
    AutoFire()
    
    -- Update ESP
    if CONFIG.ESPEnabled then
        UpdateAllESP()
    end
end)

-- Keybinds
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- E to aim
    if input.KeyCode == Enum.KeyCode.E then
        AimbotState.IsAiming = true
    end
    
    -- F to toggle aimbot
    if input.KeyCode == Enum.KeyCode.F then
        CONFIG.AimbotEnabled = not CONFIG.AimbotEnabled
    end
    
    -- G to toggle auto fire
    if input.KeyCode == Enum.KeyCode.G then
        CONFIG.AutoFireEnabled = not CONFIG.AutoFireEnabled
    end
    
    -- H to toggle target lock
    if input.KeyCode == Enum.KeyCode.H then
        CONFIG.TargetLockEnabled = not CONFIG.TargetLockEnabled
        if not CONFIG.TargetLockEnabled then
            AimbotState.LockedTarget = nil
        end
    end
    
    -- V to toggle ESP
    if input.KeyCode == Enum.KeyCode.V then
        CONFIG.ESPEnabled = not CONFIG.ESPEnabled
    end
    
    -- R to unlock current target
    if input.KeyCode == Enum.KeyCode.R then
        AimbotState.LockedTarget = nil
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.E then
        AimbotState.IsAiming = false
    end
end)

-- Cleanup on respawn
LocalPlayer.CharacterAdded:Connect(function()
    screenGui:Destroy()
    screenGui, circle = CreateAdvancedGUI()
end)

print("Axiom Aimbot Loaded - Boss man, we're locked and loaded")
