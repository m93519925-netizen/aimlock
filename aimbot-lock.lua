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
local BIND_NAME = "MobileCameraLockSystem"

-- Khởi tạo vòng tròn FOV bằng Drawing API
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 0)
FOVCircle.Filled = false
FOVCircle.Radius = FOV_RADIUS
FOVCircle.Visible = true

-- Hàm kiểm tra và tìm mục tiêu tối ưu nhất gần tâm màn hình
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(TARGET_PART) and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid.Health > 0 then
                local targetPart = player.Character[TARGET_PART]
                
                -- Khởi tạo Raycast để kiểm tra vật cản (Line-of-Sight)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
                
                local origin = Camera.CFrame.Position
                local direction = targetPart.Position - origin
                local raycastResult = workspace:Raycast(origin, direction, raycastParams)
                
                -- Nếu không có vật cản (tường, địa hình...) che khuất
                if not raycastResult then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
                        local distanceToCenter = (targetPos2D - screenCenter).Magnitude
                        
                        -- Kiểm tra xem mục tiêu có nằm trong vòng tròn FOV giới hạn không
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

-- Vòng lặp cập nhật hệ thống camera nâng cao
local currentTarget = nil

local function startAimbot()
    -- Liên kết vào hệ thống Render với mức ưu tiên cao hơn Camera gốc của Roblox
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Position = screenCenter

        if not AimbotEnabled then return end

        -- Nếu chưa có mục tiêu hoặc mục tiêu cũ đã chết/thoát game, tiến hành quét tìm mục tiêu mới
        if not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild(TARGET_PART) or (currentTarget.Character:FindFirstChildOfClass("Humanoid") and currentTarget.Character:FindFirstChildOfClass("Humanoid").Health <= 0) then
            currentTarget = getClosestPlayer()
        end

        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(TARGET_PART) then
            local targetPart = currentTarget.Character[TARGET_PART]
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
            local distanceToCenter = (targetPos2D - screenCenter).Magnitude

            -- TÍNH NĂNG TỰ ĐỘNG HỦY KHÓA (UNLOCK):
            -- Nếu người chơi vuốt mạnh màn hình khiến mục tiêu lệch ra ngoài bán kính 35px hoặc khuất màn hình
            if not onScreen or distanceToCenter > FOV_RADIUS then
                currentTarget = nil -- Giải phóng mục tiêu để người chơi tự do điều khiển
                return
            end

            -- KHẮC PHỤC LỖI GÓC NHÌN THỨ NHẤT:
            -- Sử dụng CFrame.lookAt cập nhật trực tiếp vị trí hiện tại hướng thẳng về phía mục tiêu mượt mà
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
        end
    end)
end

local function stopAimbot()
    RunService:UnbindFromRenderStep(BIND_NAME)
    FOVCircle.Visible = false
    currentTarget = nil
end

-- Bắt đầu chạy hệ thống
startAimbot()

-- GIAO DIỆN ĐIỀU KHIỂN (GUI TOGGLE)
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
ToggleButton.Size = UDim2.new(0, 85, 0, 35)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "AIM: ON"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14.0
ToggleButton.Active = true

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

-- Logic Kéo/Thả (Drag) tối ưu riêng cho màn hình cảm ứng Mobile
local dragging, dragStart, startPos
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

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        update(input)
    end
end)

-- Sự kiện bật/tắt hệ thống
ToggleButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    if AimbotEnabled then
        ToggleButton.Text = "AIM: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        FOVCircle.Visible = true
        startAimbot()
    else
        ToggleButton.Text = "AIM: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopAimbot()
    end
end)
