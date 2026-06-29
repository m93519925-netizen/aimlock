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

-- BẢNG LƯU TRỮ ĐỐI TƯỢNG ESP ĐỂ QUẢN LÝ BỘ NHỚ
local ESP_Storage = {}

-- Hàm dọn dẹp vẽ ESP của một người chơi cụ thể
local function removeESP(player)
    if ESP_Storage[player] then
        if ESP_Storage[player].Box then ESP_Storage[player].Box:Remove() end
        if ESP_Storage[player].Tracer then ESP_Storage[player].Tracer:Remove() end
        ESP_Storage[player] = nil
    end
end

-- Hàm dọn dẹp toàn bộ dữ liệu ESP (Dùng khi tắt hệ thống)
local function clearAllESP()
    for player, _ in pairs(ESP_Storage) do
        removeESP(player)
    end
end

-- Tạo các đường nét ESP mới bằng Drawing API
local function createESP(player)
    if ESP_Storage[player] then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(255, 0, 0) -- Màu đỏ cho khung bao quanh
    box.Filled = false
    box.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = Color3.fromRGB(255, 255, 255) -- Màu trắng cho đường kẻ từ dưới màn hình
    tracer.Visible = false

    ESP_Storage[player] = {
        Box = box,
        Tracer = tracer
    }
end

-- Tự động quản lý khi người chơi thoát game
Players.PlayerRemoving:Connect(removeESP)

-- Hàm tìm mục tiêu khóa tâm tối ưu nhất
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(TARGET_PART) and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid.Health > 0 then
                local targetPart = player.Character[TARGET_PART]
                
                -- Kiểm tra vật cản (Line-of-Sight)
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

-- Vòng lặp chính cập nhật Lock-On và vẽ ESP đồ họa
local currentTarget = nil

local function startAimbot()
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Position = screenCenter

        if not AimbotEnabled then 
            clearAllESP()
            return 
        end

        -- LOGIC KHÓA CAMERA (LOCK-ON)
        if not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild(TARGET_PART) or (currentTarget.Character:FindFirstChildOfClass("Humanoid") and currentTarget.Character:FindFirstChildOfClass("Humanoid").Health <= 0) then
            currentTarget = getClosestPlayer()
        end

        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(TARGET_PART) then
            local targetPart = currentTarget.Character[TARGET_PART]
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
            local distanceToCenter = (targetPos2D - screenCenter).Magnitude

            -- Tự động nhả khóa (Unlock) khi vuốt lệch tâm 35px
            if not onScreen or distanceToCenter > FOV_RADIUS then
                currentTarget = nil
            else
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            end
        end

        -- LOGIC VẼ VÀ CẬP NHẬT ĐỒ HỌA ESP
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local head = player.Character:FindFirstChild("Head")
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

                if head and root and humanoid and humanoid.Health > 0 then
                    local hrpPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    
                    if onScreen then
                        createESP(player)
                        local esp = ESP_Storage[player]

                        if esp then
                            -- Tính toán kích thước Box ESP dựa trên khoảng cách của mục tiêu
                            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                            local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                            
                            local boxHeight = math.abs(headPos.Y - legPos.Y)
                            local boxWidth = boxHeight / 1.5

                            -- Cập nhật thông số Khung hình hộp (Box)
                            esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                            esp.Box.Position = Vector2.new(hrpPos.X - boxWidth / 2, hrpPos.Y - boxHeight / 2)
                            esp.Box.Visible = true

                            -- Cập nhật thông số Đường kẻ hướng (Tracer) từ đáy màn hình
                            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            esp.Tracer.To = Vector2.new(hrpPos.X, hrpPos.Y + (boxHeight / 2))
                            esp.Tracer.Visible = true
                        end
                    else
                        removeESP(player)
                    end
                else
                    removeESP(player)
                end
            else
                removeESP(player)
            end
        end
    end)
end

local function stopAimbot()
    RunService:UnbindFromRenderStep(BIND_NAME)
    FOVCircle.Visible = false
    currentTarget = nil
    clearAllESP()
end

-- Bắt đầu khởi chạy hệ thống lần đầu
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
ToggleButton.Text = "SYSTEM: ON"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14.0
ToggleButton.Active = true

UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

-- Cấu trúc Kéo/Thả GUI trên cảm ứng Mobile
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

-- Sự kiện nhấn nút kích hoạt hệ thống tổng
ToggleButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    if AimbotEnabled then
        ToggleButton.Text = "SYSTEM: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        FOVCircle.Visible = true
        startAimbot()
    else
        ToggleButton.Text = "SYSTEM: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopAimbot()
    end
end)
