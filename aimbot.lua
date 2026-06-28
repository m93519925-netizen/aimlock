-- Roblox Mobile Camera Lock-On System
-- Professional-grade, optimized for first-person touch controls
-- Boss man, this plays nice with Roblox's camera system instead of fighting it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Drawing API for UI
local Drawing = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Drawing/main/src/Library.lua"))()

-- ===== CONFIGURATION =====
local CONFIG = {
	DETECTION_RANGE = 100,
	DETECTION_RANGE_SQ = 10000, -- Pre-squared
	RAYCAST_LENGTH = 300,
	FOCUS_CIRCLE_RADIUS = 35,
	FOCUS_CIRCLE_THICKNESS = 2,
	CAMERA_SMOOTHING = 0.15, -- Lerp factor for smooth rotation
	UNLOCK_THRESHOLD = 35, -- pixels from center
	HEAD_LEAD_OFFSET = 0.5, -- Slight lead for moving targets
	RAYCAST_PARAMS = RaycastParams.new()
}

CONFIG.RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist

-- State machine
local state = {
	isActive = false,
	lockedTarget = nil,
	lastValidHeadPos = nil,
	isDragging = false,
	dragStart = Vector2.new(0, 0),
	startPos = nil,
	lastInputTime = 0,
	inputDelta = Vector2.new(0, 0)
}

-- Drawing objects
local focusCircle = Drawing.new("Circle")
focusCircle.Radius = CONFIG.FOCUS_CIRCLE_RADIUS
focusCircle.Thickness = CONFIG.FOCUS_CIRCLE_THICKNESS
focusCircle.Color = Color3.fromRGB(0, 255, 0)
focusCircle.Filled = false
focusCircle.Transparency = 0.7
focusCircle.Visible = false

-- ===== GUI: TOGGLE BUTTON =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CameraLockGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "AimToggle"
toggleButton.Size = UDim2.new(0, 80, 0, 40)
toggleButton.Position = UDim2.new(0.05, 0, 0.5, -20)
toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 12
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Text = "AIM: OFF"
toggleButton.BorderSizePixel = 0
toggleButton.Parent = screenGui

-- ===== DRAGGABLE BUTTON =====
local dragState = {
	isDragging = false,
	dragStart = Vector2.new(0, 0),
	startPos = toggleButton.Position
}

local function makeDraggable(gui)
	local function onInputBegan(input, gameProcessed)
		if gameProcessed or state.isDragging then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or
			input.UserInputType == Enum.UserInputType.Touch then

			local inputPos = input.Position
			local buttonPos = gui.AbsolutePosition
			local buttonSize = gui.AbsoluteSize

			if inputPos.X >= buttonPos.X and inputPos.X <= buttonPos.X + buttonSize.X and
				inputPos.Y >= buttonPos.Y and inputPos.Y <= buttonPos.Y + buttonSize.Y then

				dragState.isDragging = true
				dragState.dragStart = inputPos
				dragState.startPos = gui.Position
				state.isDragging = true
			end
		end
	end

	local function onInputChanged(input, gameProcessed)
		if not dragState.isDragging then return end

		local delta = input.Position - dragState.dragStart
		gui.Position = UDim2.new(
			dragState.startPos.X.Scale,
			dragState.startPos.X.Offset + delta.X,
			dragState.startPos.Y.Scale,
			dragState.startPos.Y.Offset + delta.Y
		)
	end

	local function onInputEnded(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
			input.UserInputType == Enum.UserInputType.Touch then
			dragState.isDragging = false
			state.isDragging = false
		end
	end

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
end

makeDraggable(toggleButton)

-- ===== UTILITY: LINE-OF-SIGHT CHECK =====
local function canSeeTarget(from, to, targetChar)
	local direction = (to - from).Unit
	local distance = (to - from).Magnitude

	CONFIG.RAYCAST_PARAMS:AddToFilter({character, targetChar})

	local rayResult = workspace:Raycast(from, direction * distance, CONFIG.RAYCAST_PARAMS)

	if rayResult then
		return false -- Blocked by something
	end

	return true
end

-- ===== UTILITY: SCREEN POSITION CONVERSION =====
local function worldToScreenPos(worldPos)
	local relPos = Camera:WorldToScreenPoint(worldPos)
	return Vector2.new(relPos.X, relPos.Y)
end

-- ===== UTILITY: DISTANCE CHECK (SQUARED FOR PERFORMANCE) =====
local function isInDetectionRange(targetPos)
	local delta = targetPos - humanoidRootPart.Position
	local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
	return distSq <= CONFIG.DETECTION_RANGE_SQ
end

-- ===== CORE: FIND NEAREST VALID TARGET =====
local function findNearestTarget()
	local closestTarget = nil
	local closestDistance = math.huge

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer == player then continue end

		local otherChar = otherPlayer.Character
		if not otherChar then continue end

		local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
		local otherHead = otherChar:FindFirstChild("Head")
		local otherHumanoid = otherChar:FindFirstChild("Humanoid")

		if not otherHRP or not otherHead or not otherHumanoid or otherHumanoid.Health <= 0 then
			continue
		end

		-- Distance check
		if not isInDetectionRange(otherHRP.Position) then
			continue
		end

		-- Line-of-sight check to head
		if not canSeeTarget(humanoidRootPart.Position, otherHead.Position, otherChar) then
			continue
		end

		-- Find closest
		local distance = (otherHRP.Position - humanoidRootPart.Position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestTarget = otherPlayer
		end
	end

	return closestTarget
end

-- ===== CORE: CAMERA LOCK-ON (FIXED FOR FIRST-PERSON) =====
local function updateCameraLockOn()
	if not state.lockedTarget or not state.lockedTarget.Character then
		state.lockedTarget = nil
		return
	end

	local targetChar = state.lockedTarget.Character
	local targetHead = targetChar:FindFirstChild("Head")
	local targetHumanoid = targetChar:FindFirstChild("Humanoid")

	if not targetHead or not targetHumanoid or targetHumanoid.Health <= 0 then
		state.lockedTarget = nil
		return
	end

	-- **KEY FIX: Use relative rotation instead of absolute CFrame assignment**
	-- This works WITH Roblox's touch camera system, not against it

	local currentCameraPos = Camera.CFrame.Position
	local targetPos = targetHead.Position + (targetHead.CFrame.LookVector * CONFIG.HEAD_LEAD_OFFSET)

	-- Calculate direction to target
	local directionToTarget = (targetPos - currentCameraPos).Unit

	-- Get current camera direction
	local currentDirection = Camera.CFrame.LookVector

	-- Smooth lerp between current and target direction
	local smoothedDirection = currentDirection:Lerp(directionToTarget, CONFIG.CAMERA_SMOOTHING)

	-- **CRITICAL: Use CFrame.lookAt with smoothing to avoid override**
	-- This maintains the camera position while rotating to look at target
	Camera.CFrame = CFrame.lookAt(currentCameraPos, currentCameraPos + smoothedDirection)

	-- Update focus circle position
	local headScreenPos = worldToScreenPos(targetHead.Position)
	focusCircle.Position = headScreenPos

	-- Check if head moved outside unlock threshold (touch input conflict detection)
	local centerScreenPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local screenDistance = (headScreenPos - centerScreenPos).Magnitude

	if screenDistance > CONFIG.UNLOCK_THRESHOLD then
		-- Player swiped to move camera away, unlock immediately
		state.lockedTarget = nil
		focusCircle.Visible = false
		toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		toggleButton.Text = "AIM: OFF"
		state.isActive = false
	end
end

-- ===== CORE: INPUT TRACKING FOR SWIPE DETECTION =====
local lastInputPos = Vector2.new(0, 0)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Touch or
		input.UserInputType == Enum.UserInputType.MouseMovement then
		state.lastInputTime = tick()
		lastInputPos = input.Position
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Touch or
		input.UserInputType == Enum.UserInputType.MouseMovement then
		state.inputDelta = input.Position - lastInputPos
		lastInputPos = input.Position
	end
end)

-- ===== TOGGLE BUTTON =====
toggleButton.MouseButton1Click:Connect(function()
	if state.isDragging then return end

	state.isActive = not state.isActive

	if state.isActive then
		toggleButton.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
		toggleButton.Text = "AIM: ON"
		focusCircle.Visible = true
		state.lockedTarget = findNearestTarget()
	else
		toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		toggleButton.Text = "AIM: OFF"
		focusCircle.Visible = false
		state.lockedTarget = nil
	end
end)

-- ===== MAIN LOOP: RENDER-STEPPED FOR CAMERA UPDATES =====
local renderConnection = RunService.RenderStepped:Connect(function()
	if not state.isActive or not state.lockedTarget then
		focusCircle.Visible = false
		return
	end

	updateCameraLockOn()
end)

-- ===== MAIN LOOP: HEARTBEAT FOR TARGET DETECTION =====
local heartbeatConnection = RunService.Heartbeat:Connect(function()
	if not state.isActive then return end

	if not state.lockedTarget or not state.lockedTarget.Character then
		state.lockedTarget = findNearestTarget()
	end
end)

-- ===== CHARACTER RESPAWN HANDLER =====
player.CharacterAdded:Connect(function(newCharacter)
	state.isActive = false
	state.lockedTarget = nil
	focusCircle.Visible = false
	toggleButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	toggleButton.Text = "AIM: OFF"

	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")
end)

-- ===== CLEANUP =====
game:BindToClose(function()
	if renderConnection then renderConnection:Disconnect() end
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	focusCircle:Remove()
	screenGui:Destroy()
end)

print("Camera Lock-On System loaded, boss man. Fuck yeah, first-person fixed.")
