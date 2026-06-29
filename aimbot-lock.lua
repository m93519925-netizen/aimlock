--[=[
    MOBILE CAMERA LOCK-ON SYSTEM (DELTA EXECUTOR OPTIMIZED)
    - Sửa lỗi First-Person trên Mobile bằng cách kiểm soát CameraType và CFrame.lookAt
    - Tự động hủy khóa (Unlock) nếu người chơi vuốt màn hình làm mục tiêu lệch tâm > 35px
    - Tối ưu hóa hiệu năng, dừng hoàn toàn Drawing/Raycast khi tắt (AIM: OFF)
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- --- CẤU HÌNH HỆ THỐNG ---
local TARGET_RADIUS = 35 -- Bán kính vòng tròn tâm (pixels)
local FOV_COLOR = Color3.fromRGB(0, 255, 100) -- Màu xanh lá cây
local BUTTON_SIZE = UDim2.new(0, 100, 0, 40)
local BUTTON_POS = UDim2.new(0.5, -50, 0.8, 0)

-- --- TRẠNG THÁI HỆ THỐNG ---
local isSystemOn = false
local lockedTarget = nil
local originalCameraType = Camera.CameraType

-- --- KHỞI TẠO DRAWING FOV ---
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Color = FOV_COLOR
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.NumSides = 32
FOVCircle.Visible = false

-- --- TẠO UI BUTTON (TOGGLE & DRAGGABLE) ---
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LockOnSystemUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = BUTTON_SIZE
ToggleButton.Position = BUTTON_POS
ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 16
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Text = "AIM: OFF"
ToggleButton.BorderSizePixel = 0
ToggleButton.Parent = ScreenGui

-- Bo góc UI
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = ToggleButton

-- Logic Kéo/Thả (Drag) mượt mà trên Mobile
local dragging, dragInput, dragStart, startPos
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
        local delta = input.Position - dragStart
        ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- --- CÁC HÀM BỔ TRỢ (HELPER FUNCTIONS) ---

-- Kiểm tra vật cản (Line of Sight) bằng Raycast
local function hasLineOfSight(targetCharacter)
    local head = targetCharacter:FindFirstChild("Head")
    if not head then return false end
    
    local origin = Camera.CFrame.Position
    local direction = head.Position - origin
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetCharacter}
    raycastParams.IgnoreWater = true
    
    local raycastResult = Workspace:Raycast(origin, direction, raycastParams)
    return raycastResult == nil -- Nếu không chạm gì tức là không bị cản
end

-- Tìm mục tiêu hợp lệ gần tâm màn hình nhất
local function getClosestTargetToCenter()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closestPlayer = nil
    local shortestDistance = TARGET_RADIUS

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local character = player.Character
            local head = character:FindFirstChild("Head")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    local targetScreenPos = Vector2.new(screenPos.X, screenPos.Y)
                    local distance = (targetScreenPos - center).Magnitude
                    
                    if distance < shortestDistance then
                        if hasLineOfSight(character) then
                            shortestDistance = distance
                            closestPlayer = player
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- --- VÒNG LẶP XỬ LÝ CHÍNH (RENDERSTEPPED) ---
RunService.RenderStepped:Connect(function()
    if not isSystemOn then 
        if FOVCircle.Visible then FOVCircle.Visible = false end
        if Camera.CameraType == Enum.CameraType.Scriptable then
            Camera.CameraType = Enum.CameraType.Custom
        end
        return 
    end

    -- Cập nhật vị trí vòng tròn Drawing ở tâm màn hình
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Position = center
    FOVCircle.Radius = TARGET_RADIUS
    FOVCircle.Visible = true

    -- Nếu chưa có mục tiêu, tiến hành quét tìm mục tiêu mới
    if not lockedTarget then
        local target = getClosestTargetToCenter()
        if target then
            lockedTarget = target
        end
    else
        -- Kiểm tra tính hợp lệ của mục tiêu hiện tại
        local character = lockedTarget.Character
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if not head or not humanoid or humanoid.Health <= 0 or not hasLineOfSight(character) then
            lockedTarget = nil
            return
        end

        -- Lấy tọa độ màn hình của mục tiêu hiện tại
        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        local targetScreenPos = Vector2.new(screenPos.X, screenPos.Y)
        local distanceFromCenter = (targetScreenPos - center).Magnitude

        -- YÊU CẦU 2: Tự động hủy theo dõi (Unlock) nếu người chơi vuốt tay làm lệch > 35px
        if not onScreen or distanceFromCenter > TARGET_RADIUS then
            lockedTarget = nil
            return
        end

        -- YÊU CẦU 1: Khắc phục lỗi First-Person trên Mobile
        -- Buộc Camera chuyển sang dạng Scriptable trong khung hình này để triệt tiêu việc Touch ghi đè CFrame
        Camera.CameraType = Enum.CameraType.Scriptable
        
        -- Cập nhật CFrame hướng thẳng vào Head một cách mượt mà và chính xác tuyệt đối
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, head.Position)
    end
    
    -- Nếu có mục tiêu thì giữ Scriptable, nếu không thì trả về Custom ngay để người chơi vuốt mượt mà
    if not lockedTarget then
        Camera.CameraType = Enum.CameraType.Custom
    end
end)

-- Trả lại Camera bình thường khi người chơi chết hoặc hồi sinh
LocalPlayer.CharacterAdded:Connect(function()
    Camera.CameraType = Enum.CameraType.Custom
end)

-- --- LOGIC NÚT BẤM TOGGLE ---
ToggleButton.MouseButton1Click:Connect(function()
    isSystemOn = not isSystemOn
    if isSystemOn then
        ToggleButton.Text = "AIM: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 70)
    else
        ToggleButton.Text = "AIM: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        lockedTarget = nil
        FOVCircle.Visible = false
        Camera.CameraType = Enum.CameraType.Custom
    end
end)
