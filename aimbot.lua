-- Advanced Roblox Aimbot with Wall-Penetrating ESP
-- Axiom's Flow State Build

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Configuration
local CONFIG = {
    AimbotEnabled = true,
    ESPEnabled = true,
    CircleRadius = 50,
    AimSmoothness = 0.15,
    MaxDistance = 500,
    TargetPart = "Head",
    WallPenetration = true,
    CircleColor = Color3.fromRGB(255, 0, 0),
    ESPColor = Color3.fromRGB(0, 255, 0),
    LineThickness = 2
}

-- Aimbot State
local AimbotState = {
    TargetPlayer = nil,
    IsAiming = false,
    CircleActive = false
}

-- Create Circle GUI
local function CreateCircleGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AimbotCircle"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
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
    
    return screenGui, circle
end

-- Find closest valid target
local function FindClosestTarget()
    local closestPlayer = nil
    local closestDistance = CONFIG.MaxDistance
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(CONFIG.TargetPart)
            if targetPart then
                local distance = (LocalPlayer.Character.Head.Position - targetPart.Position).Magnitude
                
                if distance < closestDistance then
                    -- Wall penetration check
                    if CONFIG.WallPenetration then
                        closestPlayer = player
                        closestDistance = distance
                    else
                        local rayOrigin = Camera.CFrame.Position
                        local rayDirection = (targetPart.Position - rayOrigin).Unit
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                        
                        local rayResult = workspace:Raycast(rayOrigin, rayDirection * 1000, raycastParams)
                        if rayResult and rayResult.Instance:IsDescendantOf(player.Character) then
                            closestPlayer = player
                            closestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

-- Smooth aim assist
local function AimAt(targetPart)
    if not targetPart then return end
    
    local targetPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * 0.1)
    local direction = (targetPos - Camera.CFrame.Position).Unit
    local newCFrame = CFrame.lookAt(Camera.CFrame.Position, Camera.CFrame.Position + direction)
    
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, CONFIG.AimSmoothness)
end

-- Create ESP boxes and lines
local function CreateESP(player)
    if not player.Character then return end
    
    local character = player.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Remove existing ESP
    local existingESP = character:FindFirstChild("AimbotESP")
    if existingESP then existingESP:Destroy() end
    
    local espFolder = Instance.new("Folder")
    espFolder.Name = "AimbotESP"
    espFolder.Parent = character
    
    -- Create box
    local box = Instance.new("SelectionBox")
    box.Adornee = humanoidRootPart
    box.Color3 = CONFIG.ESPColor
    box.LineThickness = 0.05
    box.Parent = espFolder
    
    -- Create line to target
    local line = Instance.new("Part")
    line.Name = "ESPLine"
    line.Shape = Enum.PartType.Cylinder
    line.Material = Enum.Material.Neon
    line.CanCollide = false
    line.CFrame = CFrame.new(0, 0, 0)
    line.TopSurface = Enum.SurfaceType.Smooth
    line.BottomSurface = Enum.SurfaceType.Smooth
    line.Color = CONFIG.ESPColor
    line.Parent = espFolder
    
    return espFolder
end

-- Update ESP for all players
local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            CreateESP(player)
        end
    end
end

-- Main loop
local screenGui, circle = CreateCircleGUI()

RunService.RenderStepped:Connect(function()
    if CONFIG.AimbotEnabled then
        AimbotState.TargetPlayer = FindClosestTarget()
        
        if AimbotState.TargetPlayer and AimbotState.TargetPlayer.Character then
            local targetPart = AimbotState.TargetPlayer.Character:FindFirstChild(CONFIG.TargetPart)
            if targetPart and AimbotState.IsAiming then
                AimAt(targetPart)
            end
        end
    end
    
    if CONFIG.ESPEnabled then
        UpdateESP()
    end
end)

-- Keybinds
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.E then
        AimbotState.IsAiming = true
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        CONFIG.AimbotEnabled = not CONFIG.AimbotEnabled
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.E then
        AimbotState.IsAiming = false
    end
end)

-- Cleanup on death
LocalPlayer.CharacterAdded:Connect(function()
    screenGui:Destroy()
    screenGui, circle = CreateCircleGUI()
end)
