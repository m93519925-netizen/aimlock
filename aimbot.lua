-- ============================================================
-- Camera Lock‑On System – Mobile (Roblox / Delta Executor)
-- Tác giả: [Your Name]
-- Ngôn ngữ: Luau
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- ================== CẤU HÌNH ==================
local CONFIG = {
    CircleRadius = 35,          -- bán kính vòng tròn (pixel)
    MaxLockDistance = 200,      -- khoảng cách tối đa để tìm mục tiêu (studs)
    ScanInterval = 0.15,        -- thời gian giữa các lần quét (giây)
    CircleColor = Color3.fromRGB(0, 255, 0),
    CircleThickness = 2,
}

-- ================== BIẾN TOÀN CỤC ==================
local isAimEnabled = false
local currentTarget = nil
local circleObject = nil
local toggleButton = nil
local renderConnection = nil
local scanConnection = nil
local lastScanTime = 0

-- ================== HÀM VẼ VÒNG TRÒN ==================
local function createCircle()
    if circleObject then return end
    circleObject = Drawing.new("Circle")
    circleObject.Visible = false
    circleObject.Radius = CONFIG.CircleRadius
    circleObject.Thickness = CONFIG.CircleThickness
    circleObject.Color = CONFIG.CircleColor
    circleObject.Filled = false
    circleObject.Transparency = 1
    circleObject.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function updateCirclePosition()
    if circleObject then
        circleObject.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
end

local function destroyCircle()
    if circleObject then
        circleObject:Remove()
        circleObject = nil
    end
end

-- ================== KIỂM TRA TẦM NHÌN (LINE‑OF‑SIGHT) ==================
local function hasLineOfSight(from, to)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {character, Camera}
    local result = Workspace:Raycast(from, to - from, params)
    return result == nil
end

-- ================== TÌM MỤC TIÊU TỐT NHẤT ==================
local function findBestTarget()
    if not character or not character.PrimaryPart then
        return nil
    end
    local head = character:FindFirstChild("Head")
    if not head then return nil end

    local origin = head.Position
    local bestTarget = nil
    local bestDist = math.huge

    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherChar = otherPlayer.Character
            if otherChar and otherChar.PrimaryPart then
                local otherHead = otherChar:FindFirstChild("Head")
                if otherHead and otherHead.Parent then
                    local targetPos = otherHead.Position
                    local dist = (origin - targetPos).Magnitude
                    if dist < CONFIG.MaxLockDistance and dist < bestDist then
                        -- Kiểm tra tầm nhìn từ camera đến đầu mục tiêu
                        if hasLineOfSight(Camera.CFrame.Position, targetPos) then
                            bestTarget = otherChar
                            bestDist = dist
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- ================== KIỂM TRA MỤC TIÊU TRONG VÒNG TRÒN ==================
local function isTargetInCircle(targetHead)
    if not targetHead then return false end
    local screenPos, onScreen = Camera:WorldToScreenPoint(targetHead.Position)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    return distance <= CONFIG.CircleRadius
end

-- ================== CẬP NHẬT CAMERA ==================
local function updateCamera(targetHead)
    if not targetHead or not targetHead.Parent then
        unlockTarget()
        return
    end

    local currentPos = Camera.CFrame.Position
    local targetPos = targetHead.Position

    -- Kiểm tra tầm nhìn
    if not hasLineOfSight(currentPos, targetPos) then
        unlockTarget()
        return
    end

    -- Kiểm tra trong vòng tròn
    if not isTargetInCircle(targetHead) then
        unlockTarget()
        return
    end

    -- Cập nhật hướng camera (giữ nguyên vị trí, chỉ xoay về mục tiêu)
    Camera.CFrame = CFrame.lookAt(currentPos, targetPos)
end

-- ================== KHÓA / MỞ KHÓA MỤC TIÊU ==================
local function lockTarget(target)
    if currentTarget == target then return end
    unlockTarget()

    currentTarget = target
    if circleObject then circleObject.Visible = true end

    -- Kết nối RenderStepped để cập nhật camera liên tục
    if renderConnection then renderConnection:Disconnect() end
    renderConnection = RunService.RenderStepped:Connect(function()
        if currentTarget then
            local head = currentTarget:FindFirstChild("Head")
            if head and head.Parent then
                updateCamera(head)
            else
                unlockTarget()
            end
        end
    end)
end

local function unlockTarget()
    currentTarget = nil
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    if circleObject then circleObject.Visible = false end
end

-- ================== QUÉT TÌM MỤC TIÊU ĐỊNH KỲ ==================
local function scanForTarget()
    if not isAimEnabled then return end

    -- Nếu đang có target, kiểm tra tính hợp lệ
    if currentTarget then
        local head = currentTarget:FindFirstChild("Head")
        if not head or not head.Parent then
            unlockTarget()
        else
            -- Nếu mất tầm nhìn hoặc ra khỏi vòng tròn → unlock
            if not hasLineOfSight(Camera.CFrame.Position, head.Position) or not isTargetInCircle(head) then
                unlockTarget()
            end
        end
    end

    -- Nếu chưa có target, tìm mới
    if not currentTarget then
        local newTarget = findBestTarget()
        if newTarget then
            lockTarget(newTarget)
        end
    end
end

-- ================== BẬT / TẮT HỆ THỐNG ==================
local function toggleAim()
    isAimEnabled = not isAimEnabled

    if isAimEnabled then
        -- Tạo vòng tròn nếu chưa có
        createCircle()
        updateCirclePosition()
        circleObject.Visible = true

        -- Bắt đầu quét
        if scanConnection then scanConnection:Disconnect() end
        scanConnection = RunService.Heartbeat:Connect(function()
            -- Giới hạn tần suất quét để tiết kiệm tài nguyên
            local now = tick()
            if now - lastScanTime >= CONFIG.ScanInterval then
                lastScanTime = now
                scanForTarget()
            end
        end)

        -- Quét ngay lập tức
        scanForTarget()
        if toggleButton then toggleButton.Text = "AIM: ON" end
    else
        -- Tắt hoàn toàn
        if scanConnection then
            scanConnection:Disconnect()
            scanConnection = nil
        end
        unlockTarget()
        if circleObject then circleObject.Visible = false end
        if toggleButton then toggleButton.Text = "AIM: OFF" end
    end
end

-- ================== TẠO NÚT BẤM (TOGGLE + KÉO THẢ) ==================
local function createToggleButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = player.PlayerGui
    screenGui.Name = "AIMLockGUI"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Parent = screenGui
    frame.Size = UDim2.new(0, 70, 0, 40)
    frame.Position = UDim2.new(0, 10, 1, -50)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.6
    frame.BorderSizePixel = 0
    frame.Active = true

    -- Làm tròn góc
    local corner = Instance.new("UICorner")
    corner.Parent = frame
    corner.CornerRadius = UDim.new(0, 8)

    -- Label
    local label = Instance.new("TextLabel")
    label.Parent = frame
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "AIM: OFF"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true

    toggleButton = label

    -- === KÉO THẢ ===
    local dragging = false
    local dragStartPos = nil
    local startFramePos = nil
    local dragInput = nil

    local function updateDrag(input)
        if not dragging or not dragStartPos or not startFramePos then return end
        local delta = input.Position - dragStartPos
        local newPos = UDim2.new(
            startFramePos.X.Scale + delta.X / screenGui.AbsoluteSize.X,
            0,
            startFramePos.Y.Scale + delta.Y / screenGui.AbsoluteSize.Y,
            0
        )
        -- Giới hạn trong màn hình
        newPos = UDim2.new(
            math.clamp(newPos.X.Scale, 0, 1 - frame.Size.X.Scale),
            0,
            math.clamp(newPos.Y.Scale, 0, 1 - frame.Size.Y.Scale),
            0
        )
        frame.Position = newPos
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = input.Position
            startFramePos = frame.Position
            dragInput = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragStartPos = nil
                    startFramePos = nil
                    dragInput = nil
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Mouse then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    -- === SỰ KIỆN CLICK / TAP ===
    local function onActivate()
        toggleAim()
    end

    frame.MouseButton1Click:Connect(onActivate)
    frame.TouchTap:Connect(onActivate)

    return screenGui
end

-- ================== KHỞI TẠO ==================
local function init()
    createCircle()
    createToggleButton()

    -- Cập nhật vị trí vòng tròn khi thay đổi kích thước màn hình
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCirclePosition)

    -- Luôn ẩn khi chưa bật
    if circleObject then circleObject.Visible = false end
end

-- Chạy
init()

-- Xử lý khi nhân vật bị respawn (giữ nguyên trạng thái)
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    -- Nếu đang bật, tìm target lại
    if isAimEnabled then
        unlockTarget()
        scanForTarget()
    end
end)
