--[[
    ============================================================
    🔒 PROFESSIONAL CAMERA LOCK-ON SYSTEM FOR ROBLOX MOBILE
    ============================================================
    Executor: Delta Mobile
    Language: Luau
    Version: 2.0 (Fixed First-Person Override Issue)
    
    FEATURES:
    ✅ Smooth camera tracking in First-Person view
    ✅ Auto-unlock when target leaves screen radius (35px)
    ✅ Line-of-Sight (Raycast) check
    ✅ Draggable Toggle Button
    ✅ Drawing API FOV Circle
    ✅ Optimized performance (stops when disabled)
    ============================================================
]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

--// Local Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

--// Configuration
local CONFIG = {
    -- FOV Circle
    FOV_RADIUS = 35,           -- pixels
    FOV_COLOR = Color3.fromRGB(0, 255, 100),  -- Green
    FOV_TRANSPARENCY = 0.7,
    FOV_THICKNESS = 2,
    
    -- Targeting
    MAX_DISTANCE = 250,        -- studs
    RAYCAST_OFFSET = Vector3.new(0, 1.5, 0),  -- offset from head
    
    -- Smoothing
    SMOOTH_FACTOR = 0.15,      -- 0-1 (higher = snappier)
    
    -- Auto-unlock
    SCREEN_UNLOCK_RADIUS = 35, -- pixels from center
    
    -- Team Check (optional)
    TEAM_CHECK = false,
    
    -- Priority: Head > HumanoidRootPart > Torso
    TARGET_PARTS = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}
}

--// State Variables
local SystemActive = false
local CurrentTarget = nil
local CurrentTargetCharacter = nil
local RenderConnection = nil
local FOV_Circle = nil

--// UI References
local ToggleButton = nil

--// ============================================================
--//  DRAWING API - FOV CIRCLE
--// ============================================================

local function CreateFOVCircle()
    local circle = Drawing.new("Circle")
    circle.Visible = false
    circle.Thickness = CONFIG.FOV_THICKNESS
    circle.Color = CONFIG.FOV_COLOR
    circle.Transparency = CONFIG.FOV_TRANSPARENCY
    circle.Filled = false
    circle.NumSides = 64
    circle.Radius = CONFIG.FOV_RADIUS
    
    -- Center of screen
    local viewportSize = Camera.ViewportSize
    circle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    
    return circle
end

local function UpdateFOVCircle()
    if not FOV_Circle then return end
    
    local viewportSize = Camera.ViewportSize
    FOV_Circle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    FOV_Circle.Visible = SystemActive
    
    -- Change color when target locked
    if CurrentTarget then
        FOV_Circle.Color = Color3.fromRGB(255, 50, 50)  -- Red when locked
        FOV_Circle.Thickness = 3
    else
        FOV_Circle.Color = CONFIG.FOV_COLOR  -- Green when scanning
        FOV_Circle.Thickness = CONFIG.FOV_THICKNESS
    end
end

local function DestroyFOVCircle()
    if FOV_Circle then
        FOV_Circle:Remove()
        FOV_Circle = nil
    end
end

--// ============================================================
--//  UTILITY FUNCTIONS
--// ============================================================

-- Check if target is valid (alive, not local player, etc.)
local function IsValidTarget(character)
    if not character then return false end
    if character == LocalPlayer.Character then return false end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if humanoid.Health <= 0 then return false end
    
    -- Team check
    if CONFIG.TEAM_CHECK then
        local player = Players:GetPlayerFromCharacter(character)
        if player and player.Team == LocalPlayer.Team then
            return false
        end
    end
    
    return true
end

-- Get target part position (Head preferred)
local function GetTargetPartPosition(character)
    for _, partName in ipairs(CONFIG.TARGET_PARTS) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part.Position, part
        end
    end
    return nil, nil
end

-- Check Line of Sight using Raycast
local function HasLineOfSight(targetPosition)
    local origin = Camera.CFrame.Position
    local direction = (targetPosition - origin)
    local distance = direction.Magnitude
    direction = direction.Unit * distance
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.IgnoreWater = true
    
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if result then
        -- Check if we hit the target or something else
        local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
        if hitModel then
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
            if hitPlayer and hitPlayer ~= LocalPlayer then
                return true  -- Hit target directly
            end
        end
        return false  -- Hit wall/obstacle
    end
    
    return true  -- Nothing in between
end

-- Convert 3D world position to 2D screen position
local function WorldToScreen(position)
    local screenPos, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

-- Check if target is within screen FOV circle
local function IsInScreenFOV(targetPosition)
    local screenPos, onScreen, depth = WorldToScreen(targetPosition)
    if not onScreen or depth <= 0 then return false end
    
    local viewportSize = Camera.ViewportSize
    local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    local distance = (screenPos - center).Magnitude
    
    return distance <= CONFIG.SCREEN_UNLOCK_RADIUS
end

-- Find closest valid target within FOV
local function FindClosestTarget()
    local closestTarget = nil
    local closestDistance = math.huge
    local localCharacter = LocalPlayer.Character
    
    if not localCharacter then return nil end
    
    local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not IsValidTarget(character) then continue end
        
        local targetPos, targetPart = GetTargetPartPosition(character)
        if not targetPos then continue end
        
        -- Check distance
        local distance = (targetPos - localRoot.Position).Magnitude
        if distance > CONFIG.MAX_DISTANCE then continue end
        
        -- Check if in screen FOV
        local screenPos, onScreen, depth = WorldToScreen(targetPos)
        if not onScreen or depth <= 0 then continue end
        
        local viewportSize = Camera.ViewportSize
        local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        local screenDistance = (screenPos - center).Magnitude
        
        if screenDistance > CONFIG.FOV_RADIUS then continue end
        
        -- Check Line of Sight
        if not HasLineOfSight(targetPos) then continue end
        
        -- Check if closer than current best
        if distance < closestDistance then
            closestDistance = distance
            closestTarget = character
        end
    end
    
    return closestTarget
end

--// ============================================================
--//  CORE CAMERA LOCK-ON LOGIC (FIXED FOR FIRST-PERSON)
--// ============================================================

-- Store original camera CFrame to restore if needed
local OriginalCameraType = Enum.CameraType.Custom
local IsFirstPerson = false

local function CheckFirstPerson()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local head = character:FindFirstChild("Head")
    if not head then return false end
    
    -- Check if camera is close to head (first person)
    local distance = (Camera.CFrame.Position - head.Position).Magnitude
    return distance < 2  -- Within 2 studs = first person
end

-- The CRITICAL FIX: Override camera properly in first-person
local function UpdateCameraToTarget()
    if not CurrentTarget then return end
    if not IsValidTarget(CurrentTarget) then
        CurrentTarget = nil
        CurrentTargetCharacter = nil
        return
    end
    
    local targetPos, targetPart = GetTargetPartPosition(CurrentTarget)
    if not targetPos then
        CurrentTarget = nil
        return
    end
    
    -- ============================================
    -- CHECK 1: Auto-unlock if target leaves screen FOV
    -- ============================================
    if not IsInScreenFOV(targetPos) then
        CurrentTarget = nil
        CurrentTargetCharacter = nil
        return
    end
    
    -- ============================================
    -- CHECK 2: Auto-unlock if line of sight broken
    -- ============================================
    if not HasLineOfSight(targetPos) then
        CurrentTarget = nil
        CurrentTargetCharacter = nil
        return
    end
    
    -- ============================================
    -- FIX: Force camera to look at target
    -- ============================================
    IsFirstPerson = CheckFirstPerson()
    
    if IsFirstPerson then
        -- ============================================
        -- FIRST-PERSON FIX: Override touch controls
        -- ============================================
        -- Method: Set CameraType to Scriptable temporarily,
        -- update CFrame, then restore (or keep Scriptable)
        
        -- IMPORTANT: We use Scriptable to bypass touch override
        Camera.CameraType = Enum.CameraType.Scriptable
        
        -- Smoothly interpolate camera rotation
        local currentCF = Camera.CFrame
        local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
        
        -- Smooth the rotation (only rotate, keep position)
        local smoothedCF = currentCF:Lerp(targetCF, CONFIG.SMOOTH_FACTOR)
        
        -- Force the camera CFrame
        Camera.CFrame = smoothedCF
        
    else
        -- ============================================
        -- THIRD-PERSON: Standard approach works fine
        -- ============================================
        local currentCF = Camera.CFrame
        local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
        Camera.CFrame = currentCF:Lerp(targetCF, CONFIG.SMOOTH_FACTOR)
    end
end

--// ============================================================
--//  TOGGLE BUTTON UI (Draggable for Mobile)
--// ============================================================

local function CreateToggleButton()
    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LockOnSystem"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = PlayerGui
    
    -- Button Frame
    local button = Instance.new("Frame")
    button.Name = "ToggleBtn"
    button.Size = UDim2.new(0, 80, 0, 40)
    button.Position = UDim2.new(0, 20, 0.5, -20)
    button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    button.Parent = screenGui
    
    -- Corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    
    -- Stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 100)
    stroke.Thickness = 2
    stroke.Parent = button
    
    -- Text Label
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "StatusText"
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "AIM: OFF"
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Parent = button
    
    -- Touch detection area (larger for easier tapping)
    local touchArea = Instance.new("TextButton")
    touchArea.Name = "TouchArea"
    touchArea.Size = UDim2.new(1, 20, 1, 20)
    touchArea.Position = UDim2.new(0, -10, 0, -10)
    touchArea.BackgroundTransparency = 1
    touchArea.Text = ""
    touchArea.Parent = button
    
    --// DRAGGING LOGIC FOR MOBILE
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    local dragThreshold = 10  -- pixels to consider as drag vs tap
    
    touchArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
            dragStart = input.Position
            startPos = button.Position
            
            local connection
            connection = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    connection:Disconnect()
                    
                    -- If not dragged, it's a tap (toggle)
                    if not isDragging then
                        ToggleSystem()
                    end
                end
            end)
        end
    end)
    
    touchArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and dragStart then
            local delta = input.Position - dragStart
            if delta.Magnitude > dragThreshold then
                isDragging = true
                
                local newPos = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
                
                -- Clamp to screen bounds
                local viewportSize = Camera.ViewportSize
                local btnSize = button.AbsoluteSize
                
                local clampedX = math.clamp(
                    newPos.X.Offset,
                    0,
                    viewportSize.X - btnSize.X
                )
                local clampedY = math.clamp(
                    newPos.Y.Offset,
                    0,
                    viewportSize.Y - btnSize.Y
                )
                
                button.Position = UDim2.new(0, clampedX, 0, clampedY)
            end
        end
    end)
    
    ToggleButton = button
    return button
end

local function UpdateButtonVisual()
    if not ToggleButton then return end
    
    local textLabel = ToggleButton:FindFirstChild("StatusText")
    local stroke = ToggleButton:FindFirstChildOfClass("UIStroke")
    
    if SystemActive then
        if textLabel then textLabel.Text = "AIM: ON" end
        if stroke then stroke.Color = Color3.fromRGB(255, 50, 50) end
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
    else
        if textLabel then textLabel.Text = "AIM: OFF" end
        if stroke then stroke.Color = Color3.fromRGB(0, 255, 100) end
        ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end
end

--// ============================================================
--//  SYSTEM CONTROL
--// ============================================================

function ToggleSystem()
    SystemActive = not SystemActive
    
    if SystemActive then
        -- START SYSTEM
        FOV_Circle = CreateFOVCircle()
        
        -- Start RenderStepped loop
        RenderConnection = RunService.RenderStepped:Connect(function()
            if not SystemActive then return end
            
            -- Update FOV Circle
            UpdateFOVCircle()
            
            -- If no target, find one
            if not CurrentTarget then
                CurrentTarget = FindClosestTarget()
                if CurrentTarget then
                    CurrentTargetCharacter = CurrentTarget
                end
            else
                -- Check if target is still valid
                if not IsValidTarget(CurrentTarget) then
                    CurrentTarget = nil
                    CurrentTargetCharacter = nil
                end
            end
            
            -- Update camera if target exists
            if CurrentTarget then
                UpdateCameraToTarget()
            else
                -- Reset camera type when no target (allow normal movement)
                if Camera.CameraType == Enum.CameraType.Scriptable then
                    Camera.CameraType = Enum.CameraType.Custom
                end
            end
        end)
        
    else
        -- STOP SYSTEM
        if RenderConnection then
            RenderConnection:Disconnect()
            RenderConnection = nil
        end
        
        DestroyFOVCircle()
        CurrentTarget = nil
        CurrentTargetCharacter = nil
        
        -- Reset camera type
        if Camera.CameraType == Enum.CameraType.Scriptable then
            Camera.CameraType = Enum.CameraType.Custom
        end
    end
    
    UpdateButtonVisual()
end

--// ============================================================
--//  CLEANUP
--// ============================================================

local function Cleanup()
    SystemActive = false
    
    if RenderConnection then
        RenderConnection:Disconnect()
        RenderConnection = nil
    end
    
    DestroyFOVCircle()
    
    if ToggleButton and ToggleButton.Parent then
        ToggleButton.Parent:Destroy()
    end
    
    -- Reset camera
    Camera.CameraType = Enum.CameraType.Custom
end

-- Auto cleanup on character respawn
LocalPlayer.CharacterRemoving:Connect(function()
    Cleanup()
end)

--// ============================================================
--//  INITIALIZATION
--// ============================================================

local function Initialize()
    -- Wait for character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Create UI
    CreateToggleButton()
    
    -- Handle viewport size changes
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if FOV_Circle then
            local viewportSize = Camera.ViewportSize
            FOV_Circle.Position = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
        end
    end)
    
    print("✅ Camera Lock-On System initialized!")
    print("   - Tap button to toggle AIM")
    print("   - Drag button to move it")
    print("   - First-Person override: FIXED")
    print("   - Auto-unlock radius: " .. CONFIG.SCREEN_UNLOCK_RADIUS .. "px")
end

-- Start
Initialize()

--[[
    ============================================================
    USAGE INSTRUCTIONS:
    ============================================================
    1. Copy entire script into Delta Executor
    2. Execute while in-game
    3. Tap the "AIM: OFF" button to enable
    4. Camera will auto-lock to nearest visible target
    5. Drag button to reposition on screen
    
    TROUBLESHOOTING:
    - If camera doesn't rotate in first-person: The Scriptable
      camera type override should fix this. If still issues,
      try increasing SMOOTH_FACTOR to 0.3-0.5.
    - If button is hard to tap: Increase button size in
      CreateToggleButton() function.
    ============================================================
]]
