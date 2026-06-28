-- Roblox Professional ESP + Camera Lock-On System
-- Combined native implementation. Zero external deps. Fully draggable GUI.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- ===== SHARED CONFIG =====
local CONFIG = {
	-- ESP
	ESP_ENABLED = true,
	MAX_DISTANCE = 500,
	ENEMY_COLOR = Color3.fromRGB(255, 0, 0),
	TEAMMATE_COLOR = Color3.fromRGB(0, 255, 0),
	NEUTRAL_COLOR = Color3.fromRGB(255, 255, 255),
	HEALTH_COLOR_GOOD = Color3.fromRGB(0, 255, 0),
	HEALTH_COLOR_BAD = Color3.fromRGB(255, 0, 0),
	SHOW_NAMES = true,
	SHOW_DISTANCE = true,
	SHOW_HEALTH = true,
	SHOW_TEAM_COLOR = true,
	
	-- CAMERA LOCK
	DETECTION_RANGE = 100,
	DETECTION_RANGE_SQ = 10000,
	CAMERA_SMOOTHING = 0.15,
	UNLOCK_THRESHOLD = 35,
	HEAD_LEAD_OFFSET = 0.5,
	RAYCAST_PARAMS = RaycastParams.new()
}
CONFIG.RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist

-- ===== STATE =====
local state = {
	espObjects = {},
	isActive = false,
	lockedTarget = nil,
}

-- ===== MAIN SCREEN GUI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ProESP_AimGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 380)
mainFrame.Position = UDim2.new(0.98, -260, 0.05, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

-- Title Bar (Draggable)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "ESP + AIM LOCK"
titleLabel.Parent = titleBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 40, 1, 0)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.BorderSizePixel = 0
closeButton.Parent = titleBar
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 4)
closeButton.MouseButton1Click:Connect(function() screenGui:Destroy() end)

local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1, 0, 1, -35)
contentFrame.Position = UDim2.new(0, 0, 0, 35)
contentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
contentFrame.ScrollBarThickness = 4
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 520)
contentFrame.Parent = mainFrame

-- ===== DRAGGABLE SYSTEM (Mouse + Touch) =====
local dragging = false
local dragInput
local dragStart
local startPos

local function updateDrag(input)
	local delta = input.Position - dragStart
	mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = mainFrame.Position
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

titleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input == dragInput) then
		updateDrag(input)
	end
end)

-- ===== TOGGLE HELPERS =====
local function createToggle(parent, label, initialState, callback, yPos)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 30)
	container.Position = UDim2.new(0, 10, 0, yPos)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	container.BorderSizePixel = 0
	container.Parent = parent
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(1, -60, 1, 0)
	labelText.BackgroundTransparency = 1
	labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
	labelText.TextSize = 12
	labelText.Font = Enum.Font.Gotham
	labelText.Text = label
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Parent = container

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 45, 0, 22)
	button.Position = UDim2.new(1, -50, 0.5, -11)
	button.BackgroundColor3 = initialState and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 10
	button.Font = Enum.Font.GothamBold
	button.Text = initialState and "ON" or "OFF"
	button.BorderSizePixel = 0
	button.Parent = container
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)

	button.MouseButton1Click:Connect(function()
		local newState = not initialState
		initialState = newState
		button.BackgroundColor3 = newState and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
		button.Text = newState and "ON" or "OFF"
		callback(newState)
	end)
end

-- Toggles
createToggle(contentFrame, "Enable ESP", CONFIG.ESP_ENABLED, function(s) CONFIG.ESP_ENABLED = s end, 10)
createToggle(contentFrame, "Show Names", CONFIG.SHOW_NAMES, function(s) CONFIG.SHOW_NAMES = s end, 50)
createToggle(contentFrame, "Show Distance", CONFIG.SHOW_DISTANCE, function(s) CONFIG.SHOW_DISTANCE = s end, 90)
createToggle(contentFrame, "Show Health", CONFIG.SHOW_HEALTH, function(s) CONFIG.SHOW_HEALTH = s end, 130)
createToggle(contentFrame, "Team Colors", CONFIG.SHOW_TEAM_COLOR, function(s) CONFIG.SHOW_TEAM_COLOR = s end, 170)

-- AIM Toggle
local aimToggle = Instance.new("TextButton")
aimToggle.Size = UDim2.new(0.9, 0, 0, 50)
aimToggle.Position = UDim2.new(0.05, 0, 0, 220)
aimToggle.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
aimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
aimToggle.TextSize = 16
aimToggle.Font = Enum.Font.GothamBold
aimToggle.Text = "AIM LOCK: OFF"
aimToggle.Parent = contentFrame
Instance.new("UICorner", aimToggle).CornerRadius = UDim.new(0, 8)

-- ===== FOCUS CIRCLE =====
local focusFrame = Instance.new("Frame")
focusFrame.Size = UDim2.new(0, 70, 0, 70)
focusFrame.BackgroundTransparency = 1
focusFrame.Visible = false
focusFrame.Parent = screenGui

Instance.new("Frame", focusFrame).Size = UDim2.new(1,0,1,0)
focusFrame:FindFirstChildWhichIsA("Frame").BackgroundTransparency = 1
focusFrame:FindFirstChildWhichIsA("Frame").BorderSizePixel = 2
focusFrame:FindFirstChildWhichIsA("Frame").BorderColor3 = Color3.fromRGB(0, 255, 0)

local innerCircle = Instance.new("Frame")
innerCircle.Size = UDim2.new(0.6,0,0.6,0)
innerCircle.Position = UDim2.new(0.2,0,0.2,0)
innerCircle.BackgroundTransparency = 1
innerCircle.BorderSizePixel = 2
innerCircle.BorderColor3 = Color3.fromRGB(0, 255, 0)
innerCircle.Parent = focusFrame

-- ===== ESP FUNCTIONS =====
local function getPlayerColor(targetPlayer)
	if not CONFIG.SHOW_TEAM_COLOR then return CONFIG.NEUTRAL_COLOR end
	return (targetPlayer.Team == player.Team and player.Team) and CONFIG.TEAMMATE_COLOR or CONFIG.ENEMY_COLOR
end

local function createESPBillboard(targetChar, targetPlayer)
	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 150)
	billboard.MaxDistance = CONFIG.MAX_DISTANCE
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = hrp

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
	bg.BackgroundTransparency = 0.6
	bg.Parent = billboard
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0,4)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1,0,0,25)
	nameLabel.Position = UDim2.new(0,0,0,5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = getPlayerColor(targetPlayer)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = targetPlayer.Name
	nameLabel.Parent = bg

	local distLabel = Instance.new("TextLabel")
	distLabel.Size = UDim2.new(1,0,0,20)
	distLabel.Position = UDim2.new(0,0,0,30)
	distLabel.BackgroundTransparency = 1
	distLabel.TextColor3 = Color3.fromRGB(150,150,150)
	distLabel.TextSize = 12
	distLabel.Font = Enum.Font.Gotham
	distLabel.Text = "-- studs"
	distLabel.Parent = bg

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Size = UDim2.new(1,0,0,20)
	hpLabel.Position = UDim2.new(0,0,0,50)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.fromRGB(0,255,0)
	hpLabel.TextSize = 12
	hpLabel.Font = Enum.Font.Gotham
	hpLabel.Text = "HP: --/--"
	hpLabel.Parent = bg

	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(0.9,0,0,8)
	hpBg.Position = UDim2.new(0.05,0,0,75)
	hpBg.BackgroundColor3 = Color3.fromRGB(50,50,50)
	hpBg.Parent = bg
	Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0,2)

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.new(1,0,1,0)
	hpFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
	hpFill.Parent = hpBg
	Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0,2)

	return {billboard = billboard, nameLabel = nameLabel, distanceLabel = distLabel, healthLabel = hpLabel, healthBarFill = hpFill}
end

local function updateESPBillboard(targetPlayer, espData)
	local targetChar = targetPlayer.Character
	if not targetChar then
		if espData.billboard then espData.billboard:Destroy() end
		return false
	end
	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	local hum = targetChar:FindFirstChild("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		if espData.billboard then espData.billboard:Destroy() end
		return false
	end

	espData.nameLabel.TextColor3 = getPlayerColor(targetPlayer)

	if CONFIG.SHOW_DISTANCE then
		local dist = (hrp.Position - humanoidRootPart.Position).Magnitude
		espData.distanceLabel.Text = math.floor(dist) .. " studs"
		espData.distanceLabel.Visible = true
	else
		espData.distanceLabel.Visible = false
	end

	if CONFIG.SHOW_HEALTH then
		local health = hum.Health
		local maxH = hum.MaxHealth
		espData.healthLabel.Text = "HP: " .. math.floor(health) .. "/" .. math.floor(maxH)
		local perc = math.clamp(health / maxH, 0, 1)
		espData.healthBarFill.Size = UDim2.new(perc, 0, 1, 0)
		espData.healthBarFill.BackgroundColor3 = CONFIG.HEALTH_COLOR_BAD:Lerp(CONFIG.HEALTH_COLOR_GOOD, perc)
		espData.healthLabel.Visible = true
	else
		espData.healthLabel.Visible = false
	end

	local dist = (hrp.Position - humanoidRootPart.Position).Magnitude
	espData.billboard.MaxDistance = dist > CONFIG.MAX_DISTANCE and 0 or CONFIG.MAX_DISTANCE
	espData.billboard.Enabled = CONFIG.ESP_ENABLED and CONFIG.SHOW_NAMES
	return true
end

local function updateAllESP()
	if not CONFIG.ESP_ENABLED then
		for _, data in pairs(state.espObjects) do if data.billboard then data.billboard:Destroy() end end
		state.espObjects = {}
		return
	end

	local active = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p == player then continue end
		local char = p.Character
		if not char then continue end
		active[p] = true

		if not state.espObjects[p] then
			local data = createESPBillboard(char, p)
			if data then state.espObjects[p] = data end
		end

		if state.espObjects[p] and not updateESPBillboard(p, state.espObjects[p]) then
			state.espObjects[p] = nil
		end
	end

	for p, data in pairs(state.espObjects) do
		if not active[p] then
			if data.billboard then data.billboard:Destroy() end
			state.espObjects[p] = nil
		end
	end
end

-- ===== CAMERA LOCK =====
local function canSeeTarget(from, to, targetChar)
	local dir = (to - from).Unit
	local dist = (to - from).Magnitude
	CONFIG.RAYCAST_PARAMS:AddToFilter({character, targetChar})
	return not workspace:Raycast(from, dir * dist, CONFIG.RAYCAST_PARAMS)
end

local function isInDetectionRange(targetPos)
	local delta = targetPos - humanoidRootPart.Position
	return delta.X*delta.X + delta.Y*delta.Y + delta.Z*delta.Z <= CONFIG.DETECTION_RANGE_SQ
end

local function findNearestTarget()
	local closest, minDist = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p == player then continue end
		local char = p.Character
		if not char then continue end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local head = char:FindFirstChild("Head")
		local hum = char:FindFirstChild("Humanoid")
		if not hrp or not head or not hum or hum.Health <= 0 then continue end
		if not isInDetectionRange(hrp.Position) then continue end
		if not canSeeTarget(humanoidRootPart.Position, head.Position, char) then continue end

		local dist = (hrp.Position - humanoidRootPart.Position).Magnitude
		if dist < minDist then minDist = dist closest = p end
	end
	return closest
end

local function updateCameraLockOn()
	if not state.lockedTarget or not state.lockedTarget.Character then return end
	local tChar = state.lockedTarget.Character
	local tHead = tChar:FindFirstChild("Head")
	local tHum = tChar:FindFirstChild("Humanoid")
	if not tHead or not tHum or tHum.Health <= 0 then
		state.lockedTarget = nil
		return
	end

	local camPos = camera.CFrame.Position
	local targetPos = tHead.Position + (tHead.CFrame.LookVector * CONFIG.HEAD_LEAD_OFFSET)
	local dirToTarget = (targetPos - camPos).Unit
	local currentDir = camera.CFrame.LookVector
	local smoothed = currentDir:Lerp(dirToTarget, CONFIG.CAMERA_SMOOTHING)
	camera.CFrame = CFrame.lookAt(camPos, camPos + smoothed)

	local screenPos = camera:WorldToScreenPoint(tHead.Position)
	focusFrame.Position = UDim2.new(0, screenPos.X - 35, 0, screenPos.Y - 35)

	local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
	if (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude > CONFIG.UNLOCK_THRESHOLD then
		state.lockedTarget = nil
		focusFrame.Visible = false
		aimToggle.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		aimToggle.Text = "AIM LOCK: OFF"
		state.isActive = false
	end
end

-- AIM Toggle
aimToggle.MouseButton1Click:Connect(function()
	state.isActive = not state.isActive
	if state.isActive then
		aimToggle.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
		aimToggle.Text = "AIM LOCK: ON"
		focusFrame.Visible = true
		state.lockedTarget = findNearestTarget()
	else
		aimToggle.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		aimToggle.Text = "AIM LOCK: OFF"
		focusFrame.Visible = false
		state.lockedTarget = nil
	end
end)

-- ===== MAIN LOOPS =====
RunService.RenderStepped:Connect(function()
	updateAllESP()
	if state.isActive and state.lockedTarget then
		updateCameraLockOn()
	else
		focusFrame.Visible = false
	end
end)

RunService.Heartbeat:Connect(function()
	if state.isActive and (not state.lockedTarget or not state.lockedTarget.Character) then
		state.lockedTarget = findNearestTarget()
	end
end)

-- Respawn Handler
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
	humanoid = newChar:WaitForChild("Humanoid")
end)

-- Cleanup
game:BindToClose(function()
	for _, data in pairs(state.espObjects) do
		if data.billboard then data.billboard:Destroy() end
	end
	screenGui:Destroy()
end)

print("ESP + Camera Lock-On loaded. GUI is now fully draggable (mouse + touch). Boss man approved.")
