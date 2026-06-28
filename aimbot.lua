-- Đợi game tải xong hoàn toàn dữ liệu người chơi
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Đợi PlayerGui sẵn sàng
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local AimbotEnabled = true
local FOV_RADIUS = 35 
local TARGET_PART = "Head"

-- Khởi tạo vòng tròn FOV
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 0)
FOVCircle.Filled = false
FOVCircle.Radius = FOV_RADIUS
FOVCircle.Visible = true

-- Hàm tìm mục tiêu
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(TARGET_PART) and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid.Health > 0 then
                local targetPart = player.Character[TARGET_PART]
                
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
                
                local origin = Camera.CFrame.Position
                local direction = targetPart.Position - origin
                local raycastResult = workspace:Raycast(origin, direction, raycastParams)
                
                if not raycastResult then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
                        local distanceToCenter = (targetPos2D - screenCenter).Magnitude
                        
                        if distanceToCenter <= FOV_RADIUS and distanceToCenter < shortestDistance then
                            closestPlayer = player
                            shortestDistance = distanceToCenter
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- Vòng lặp cập nhật hệ thống
local aimConnection
local function startAimbot()
    aimConnection = RunService.RenderStepped:Connect(function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Position = screenCenter

        if not AimbotEnabled then return end

        local targetPlayer = getClosestPlayer()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild(TARGET_PART) then
            local targetPos = targetPlayer.Character[TARGET_PART].Position
            local direction = (targetPos - Camera.CFrame.Position).Unit
            local targetYaw = math.atan2(-direction.X, -direction.Z)
            local targetPitch = math.asin(direction.Y)
            
            -- Xoay camera ép buộc cho góc nhìn thứ nhất trên Mobile
            Camera.CFrame = CFrame.new(Camera.CFrame.Position) 
                            * CFrame.Angles(0, targetYaw, 0) 
                            * CFrame.Angles(targetPitch, 0, 0)
        end
    end)
end

local function stopAimbot()
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
    FOVCircle.Visible = false
end

startAimbot()

-- TẠO GUI - ĐÃ SỬA ĐỂ HIỆN THỊ TRÊN DELTA
if PlayerGui:FindFirstChild("MobileAimbotGui") then
    PlayerGui.MobileAimbotGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
local ToggleButton = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")

ScreenGui.Name = "MobileAimbotGui"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false

ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
ToggleButton.Position = UDim2.new(0.15, 0, 0.25, 0)
ToggleButton.Size = UDim2.new(0, 75, 0, 35)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "TRACK: ON"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14.0
ToggleButton.Active = true

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = ToggleButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

ToggleButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    if AimbotEnabled then
        ToggleButton.Text = "TRACK: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        FOVCircle.Visible = true
        if not aimConnection then startAimbot() end
    else
        ToggleButton.Text = "TRACK: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopAimbot()
    end
end)
