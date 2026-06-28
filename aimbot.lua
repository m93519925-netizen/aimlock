-- ============================================================
-- Camera Lock‑On System – Mobile (Roblox / Delta Executor)
-- Tác giả: Hoàn thiện & Sửa lỗi
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

-- Khai báo trước (Forward Declaration) để tránh lỗi gọi hàm trước khi định nghĩa
local unlockTarget 

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

-- ================== KIỂM TRA TẦM NHÌN (LINE‑OF‑SIGHT) ==================
local function hasLineOfSight(from, to)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, Camera}
    local result = Workspace:Raycast(from, to - from, params)
    return result == nil
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

-- ================== TÌM MỤC TIÊU TỐT NHẤT ==================
local function findBestTarget()
    if not character or not character.PrimaryPart then return nil end
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
                        if hasLineOfSight(Camera.CFrame.Position, targetPos) and isTargetInCircle(otherHead) then
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

-- ================== CẬP NHẬT CAMERA ==================
local function updateCamera(targetHead)
    if not targetHead or not targetHead.Parent then
        unlockTarget()
        return
    end

    local currentPos = Camera.CFrame.Position
    local targetPos = targetHead.Position

    if not hasLineOfSight(currentPos, targetPos) or not isTargetInCircle(targetHead) then
        unlockTarget()
        return
    end

    Camera.CFrame = CFrame.lookAt(currentPos, targetPos)
end

-- ================== KHÓA / MỞ KHÓA MỤC TIÊU ==================
local function lockTarget(target)
    if currentTarget == target then return end
    unlockTarget()

    currentTarget = target
    if circleObject then circleObject.Visible = true end

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

-- Định nghĩa hàm unlockTarget đã khai báo ở trên
unlockTarget = function()
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

    if currentTarget then
        local head = currentTarget:FindFirstChild("Head")
        if not head or not head.Parent or not hasLineOfSight(Camera.CFrame.Position, head.Position) or not isTargetInCircle(head) then
            unlockTarget()
        end
    end

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
        createCircle()
        updateCirclePosition()
        circleObject.Visible = true

        if scanConnection then scanConnection:Disconnect() end
        scanConnection = RunService.Heartbeat:Connect(function()
            local now = tick()
            if now - lastScanTime >= CONFIG.ScanInterval then
                lastScanTime = now
                scanForTarget()
            end
        end)

        scanForTarget()
        if toggleButton then toggleButton.Text = "AIM: ON" end
    end
end

-- ================== TẠO NÚT BẤM (TOGGLE + KÉO THẢ) ==================
local function createToggleButton()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Parent = player.PlayerGui
    screenGui.Name = "AIMLockGUI"
    screenGui.ResetOnSpawn = false

    -- SỬA: Đổi từ "Frame" thành "TextButton" để dùng được sự kiện Click/Tap công khai
    local frame = Instance.new("TextButton")
    frame.Parent = screenGui
    frame.Size = UDim2.new(0, 90, 0, 45)
    frame.Position = UDim2.new(0, 10, 1, -60)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Text = "AIM: OFF"
    frame.TextColor3 = Color3.fromRGB(255, 255, 255)
    frame.TextSize = 16
    frame.Font = Enum.Font.SourceSansBold

    local corner = Instance.new("UICorner")
    corner.Parent = frame
    corner.CornerRadius = UDim.new(0, 8)

    toggleButton = frame

    -- === XỬ LÝ KÉO THẢ ===
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
    frame.MouseButton1Click:Connect(toggleAim)

    return screenGui
end

-- ================== KHỞI TẠO ==================
local function init()
    createCircle()
    createToggleButton()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCirclePosition)
end

init()

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    if isAimEnabled then
        unlockTarget()
        scanForTarget()
    end
end)
