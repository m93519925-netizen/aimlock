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
local BIND_NAME = "MobileAdvancedLockSystem"

-- Khởi tạo vòng tròn FOV bằng Drawing API
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 0)
FOVCircle.Filled = false
FOVCircle.Radius = FOV_RADIUS
FOVCircle.Visible = true

-- QUẢN LÝ BỘ NHỚ ĐỒ HỌA ESP
local ESP_Storage = {}

local function removeESP(player)
    if ESP_Storage[player] then
        if ESP_Storage[player].Box then ESP_Storage[player].Box:Remove() end
        if ESP_Storage[player].Tracer then ESP_Storage[player].Tracer:Remove() end
        ESP_Storage[player] = nil
    end
end

local function clearAllESP()
    for player, _ in pairs(ESP_Storage) do
        removeESP(player)
    end
end

local function createESP(player)
    if ESP_Storage[player] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Filled = false
    box.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Color = Color3.fromRGB(255, 255, 255)
    tracer.Visible = false

    ESP_Storage[player] = { Box = box, Tracer = tracer }
end

Players.PlayerRemoving:Connect(removeESP)

-- Hàm tìm kiếm mục tiêu gần tâm màn hình nhất
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(TARGET_PART) and player.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid.Health > 0 then
                local targetPart = player.Character[TARGET_PART]
                
                -- Quét tia vật cản (Line-of-Sight)
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

-- VÒNG LẶP CHÍNH CẬP NHẬT HỆ THỐNG
local currentTarget = nil

local function startAimbot()
    RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        FOVCircle.Position = screenCenter

        if not AimbotEnabled then 
            clearAllESP()
            return 
        end

        -- Xử lý mục tiêu khóa (Lock Target)
        if not currentTarget or not currentTarget.Character or not currentTarget.Character:FindFirstChild(TARGET_PART) or (currentTarget.Character:FindFirstChildOfClass("Humanoid") and currentTarget.Character:FindFirstChildOfClass("Humanoid").Health <= 0) then
            currentTarget = getClosestPlayer()
        end

        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild(TARGET_PART) then
            local targetPart = currentTarget.Character[TARGET_PART]
            local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
            local targetPos2D = Vector2.new(screenPos.X, screenPos.Y)
            local distanceToCenter = (targetPos2D - screenCenter).Magnitude

            -- Tự động nhả khóa (Unlock) khi vuốt lệch tâm quá 35px
            if not onScreen or distanceToCenter > FOV_RADIUS then
                currentTarget = nil
            else
                -- Ép góc quay nhìn thẳng mục tiêu (Khắc phục lỗi trên Mobile góc nhìn thứ nhất)
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            end
        end

        -- Cập nhật vẽ đồ họa ESP liên tục
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
                            local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                            local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                            local boxHeight = math.abs(headPos.Y - legPos.Y)
                            local boxWidth = boxHeight / 1.5

                            esp.Box.Size = Vector2.new(boxWidth, boxHeight)
                            esp.Box.Position = Vector2.new(hrpPos.X - boxWidth / 2, hrpPos.Y - boxHeight / 2)
                            esp.Box.Visible = true

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

startAimbot()

-- THIẾT KẾ CỤM MENU HỢP NHẤT HỖ TRỢ KÉO THẢ (DRAGGABLE GUI)
if PlayerGui:FindFirstChild("MobileAimbotSystemGui") then
    PlayerGui.MobileAimbotSystemGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MobileAimbotSystemGui"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false

-- Khung chứa chính (Main Panel) dùng để Drag bám theo ngón tay
local MainPanel = Instance.new("Frame")
MainPanel.Name = "MainPanel"
MainPanel.Parent = ScreenGui
MainPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainPanel.BackgroundTransparency = 0.3
MainPanel.Position = UDim2.new(0.15, 0, 0.25, 0)
MainPanel.Size = UDim2.new(0, 180, 0, 45)
MainPanel.Active = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainPanel

-- Nút ON/OFF Hệ thống
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Parent = MainPanel
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
ToggleButton.Position = UDim2.new(0, 8, 0, 7)
ToggleButton.Size = UDim2.new(0, 75, 0, 30)
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "SYS: ON"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14.0

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

-- Nút TỪ BỎ MỤC TIÊU NHANH (UNLINK)
local UnlinkButton = Instance.new("TextButton")
UnlinkButton.Name = "UnlinkButton"
UnlinkButton.Parent = MainPanel
UnlinkButton.BackgroundColor3 = Color3.fromRGB(230, 125, 0)
UnlinkButton.Position = UDim2.new(0, 93, 0, 7)
UnlinkButton.Size = UDim2.new(0, 80, 0, 30)
UnlinkButton.Font = Enum.Font.SourceSansBold
UnlinkButton.Text = "UNLINK"
UnlinkButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UnlinkButton.TextSize = 14.0

local UnlinkCorner = Instance.new("UICorner")
UnlinkCorner.CornerRadius = UDim.new(0, 6)
UnlinkCorner.Parent = UnlinkButton

-- Logic xử lý Kéo/Thả (Drag) mượt mà cho Main Panel trên Mobile Touch
local dragging, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    MainPanel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

MainPanel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainPanel.Position
        
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

-- Sự kiện bật/tắt hệ thống tổng qua nút bấm
ToggleButton.MouseButton1Click:Connect(function()
    AimbotEnabled = not AimbotEnabled
    if AimbotEnabled then
        ToggleButton.Text = "SYS: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        FOVCircle.Visible = true
        startAimbot()
    else
        ToggleButton.Text = "SYS: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopAimbot()
    end
end)

-- Sự kiện nhấn nút UNLINK để bỏ mục tiêu thủ công lập tức
UnlinkButton.MouseButton1Click:Connect(function()
    if currentTarget then
        currentTarget = nil
    end
end)
