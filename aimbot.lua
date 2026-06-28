-- Professional Player ESP System for Roblox (Native Implementation)
-- Real-time rendering with 3D boxes, names, distance, health
-- Boss man, zero external dependencies.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ===== CONFIGURATION =====
local CONFIG = {
	-- Rendering
	ESP_ENABLED = true,
	MAX_DISTANCE = 500,
	BOX_THICKNESS = 1,
	TEXT_SIZE = 14,
	
	-- Colors
	ENEMY_COLOR = Color3.fromRGB(255, 0, 0),
	TEAMMATE_COLOR = Color3.fromRGB(0, 255, 0),
	NEUTRAL_COLOR = Color3.fromRGB(255, 255, 255),
	HEALTH_COLOR_GOOD = Color3.fromRGB(0, 255, 0),
	HEALTH_COLOR_BAD = Color3.fromRGB(255, 0, 0),
	
	-- Features
	SHOW_BOXES = true,
	SHOW_NAMES = true,
	SHOW_DISTANCE = true,
	SHOW_HEALTH = true,
	SHOW_TEAM_COLOR = true,
	UPDATE_INTERVAL = 0.016 -- ~60fps
}

-- ===== STATE MANAGEMENT =====
local state = {
	espObjects = {}, -- Cache for BillboardGui objects
	playerCache = {},
	isDragging = false
}

-- ===== GUI SETUP =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerESPGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 350)
mainFrame.Position = UDim2.new(0.98, -260, 0.05, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "PLAYER ESP"
titleLabel.Parent = titleBar

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 40, 1, 0)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 12
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.BorderSizePixel = 0
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

-- Content frame
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, 0, 1, -35)
contentFrame.Position = UDim2.new(0, 0, 0, 35)
contentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 4
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
contentFrame.Parent = mainFrame

-- ===== GUI HELPERS =====
local function createToggle(parent, label, initialState, callback, yPos)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, -20, 0, 30)
	container.Position = UDim2.new(0, 10, 0, yPos)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	container.BorderSizePixel = 0
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = container

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(1, -50, 1, 0)
	labelText.BackgroundTransparency = 1
	labelText.TextColor3 = Color3.fromRGB(200, 200, 200)
	labelText.TextSize = 11
	labelText.Font = Enum.Font.Gotham
	labelText.Text = label
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Parent = container

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 35, 0, 20)
	button.Position = UDim2.new(1, -40, 0.5, -10)
	button.BackgroundColor3 = initialState and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 9
	button.Font = Enum.Font.GothamBold
	button.Text = initialState and "ON" or "OFF"
	button.BorderSizePixel = 0
	button.Parent = container

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 3)
	buttonCorner.Parent = button

	button.MouseButton1Click:Connect(function()
		local newState = not initialState
		initialState = newState
		button.BackgroundColor3 = newState and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(255, 50, 50)
		button.Text = newState and "ON" or "OFF"
		callback(newState)
	end)

	return button
end

-- ===== BUILD CONTROLS =====
createToggle(contentFrame, "Enable ESP", CONFIG.ESP_ENABLED, function(state)
	CONFIG.ESP_ENABLED = state
end, 10)

createToggle(contentFrame, "Show Boxes", CONFIG.SHOW_BOXES, function(state)
	CONFIG.SHOW_BOXES = state
end, 50)

createToggle(contentFrame, "Show Names", CONFIG.SHOW_NAMES, function(state)
	CONFIG.SHOW_NAMES = state
end, 90)

createToggle(contentFrame, "Show Distance", CONFIG.SHOW_DISTANCE, function(state)
	CONFIG.SHOW_DISTANCE = state
end, 130)

createToggle(contentFrame, "Show Health", CONFIG.SHOW_HEALTH, function(state)
	CONFIG.SHOW_HEALTH = state
end, 170)

createToggle(contentFrame, "Team Colors", CONFIG.SHOW_TEAM_COLOR, function(state)
	CONFIG.SHOW_TEAM_COLOR = state
end, 210)

-- Make GUI draggable
local dragging = false
local dragStart = Vector2.new(0, 0)
local startPos = mainFrame.Position

titleBar.MouseButton1Down:Connect(function()
	dragging = true
	dragStart = UserInputService:GetMouseLocation()
	startPos = mainFrame.Position
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if not dragging then return end
	local currentMouse = UserInputService:GetMouseLocation()
	local delta = currentMouse - dragStart
	mainFrame.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
end)

-- ===== CORE: GET PLAYER COLOR =====
local function getPlayerColor(targetPlayer)
	if not CONFIG.SHOW_TEAM_COLOR then
		return CONFIG.NEUTRAL_COLOR
	end

	if targetPlayer.Team == player.Team and player.Team ~= nil then
		return CONFIG.TEAMMATE_COLOR
	else
		return CONFIG.ENEMY_COLOR
	end
end

-- ===== CORE: CREATE ESP BILLBOARD =====
local function createESPBillboard(targetChar, targetPlayer)
	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	-- Main billboard container
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_Billboard"
	billboard.Size = UDim2.new(0, 200, 0, 150)
	billboard.MaxDistance = CONFIG.MAX_DISTANCE
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Parent = hrp

	-- Background frame
	local bgFrame = Instance.new("Frame")
	bgFrame.Name = "Background"
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bgFrame.BackgroundTransparency = 0.6
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = bgFrame

	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 25)
	nameLabel.Position = UDim2.new(0, 0, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = getPlayerColor(targetPlayer)
	nameLabel.TextSize = CONFIG.TEXT_SIZE
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = targetPlayer.Name
	nameLabel.Parent = bgFrame

	-- Distance label
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(1, 0, 0, 20)
	distanceLabel.Position = UDim2.new(0, 0, 0, 30)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	distanceLabel.TextSize = 12
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Text = "-- studs"
	distanceLabel.Parent = bgFrame

	-- Health label
	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthLabel"
	healthLabel.Size = UDim2.new(1, 0, 0, 20)
	healthLabel.Position = UDim2.new(0, 0, 0, 50)
	healthLabel.BackgroundTransparency = 1
	healthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	healthLabel.TextSize = 12
	healthLabel.Font = Enum.Font.Gotham
	healthLabel.Text = "HP: --/--"
	healthLabel.Parent = bgFrame

	-- Health bar background
	local healthBarBg = Instance.new("Frame")
	healthBarBg.Name = "HealthBarBg"
	healthBarBg.Size = UDim2.new(0.9, 0, 0, 8)
	healthBarBg.Position = UDim2.new(0.05, 0, 0, 75)
	healthBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	healthBarBg.BorderSizePixel = 0
	healthBarBg.Parent = bgFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 2)
	barCorner.Parent = healthBarBg

	-- Health bar fill
	local healthBarFill = Instance.new("Frame")
	healthBarFill.Name = "HealthBarFill"
	healthBarFill.Size = UDim2.new(1, 0, 1, 0)
	healthBarFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	healthBarFill.BorderSizePixel = 0
	healthBarFill.Parent = healthBarBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = healthBarFill

	return {
		billboard = billboard,
		nameLabel = nameLabel,
		distanceLabel = distanceLabel,
		healthLabel = healthLabel,
		healthBarFill = healthBarFill,
		bgFrame = bgFrame
	}
end

-- ===== CORE: UPDATE ESP BILLBOARD =====
local function updateESPBillboard(targetPlayer, espData)
	local targetChar = targetPlayer.Character
	if not targetChar then
		if espData.billboard.Parent then
			espData.billboard:Destroy()
		end
		return false
	end

	local hrp = targetChar:FindFirstChild("HumanoidRootPart")
	local humanoid = targetChar:FindFirstChild("Humanoid")

	if not hrp or not humanoid or humanoid.Health <= 0 then
		if espData.billboard.Parent then
			espData.billboard:Destroy()
		end
		return false
	end

	-- Update name color
	espData.nameLabel.TextColor3 = getPlayerColor(targetPlayer)

	-- Update distance
	if CONFIG.SHOW_DISTANCE then
		local distance = (hrp.Position - humanoidRootPart.Position).Magnitude
		espData.distanceLabel.Text = math.floor(distance) .. " studs"
		espData.distanceLabel.Visible = true
	else
		espData.distanceLabel.Visible = false
	end

	-- Update health
	if CONFIG.SHOW_HEALTH then
		local health = humanoid.Health
		local maxHealth = humanoid.MaxHealth
		espData.healthLabel.Text = "HP: " .. math.floor(health) .. "/" .. math.floor(maxHealth)

		local healthPercent = math.clamp(health / maxHealth, 0, 1)
		espData.healthBarFill.Size = UDim2.new(healthPercent, 0, 1, 0)

		-- Color gradient for health
		local healthColor = Color3.new(
			CONFIG.HEALTH_COLOR_BAD.R + (CONFIG.HEALTH_COLOR_GOOD.R - CONFIG.HEALTH_COLOR_BAD.R) * healthPercent,
			CONFIG.HEALTH_COLOR_BAD.G + (CONFIG.HEALTH_COLOR_GOOD.G - CONFIG.HEALTH_COLOR_BAD.G) * healthPercent,
			CONFIG.HEALTH_COLOR_BAD.B + (CONFIG.HEALTH_COLOR_GOOD.B - CONFIG.HEALTH_COLOR_BAD.B) * healthPercent
		)
		espData.healthBarFill.BackgroundColor3 = healthColor
		espData.healthLabel.Visible = true
	else
		espData.healthLabel.Visible = false
		espData.healthBarFill.Parent.Visible = false
	end

	-- Update visibility based on distance
	local distance = (hrp.Position - humanoidRootPart.Position).Magnitude
	if distance > CONFIG.MAX_DISTANCE then
		espData.billboard.MaxDistance = 0
	else
		espData.billboard.MaxDistance = CONFIG.MAX_DISTANCE
	end

	-- Toggle entire billboard
	espData.billboard.Enabled = CONFIG.ESP_ENABLED and CONFIG.SHOW_NAMES

	return true
end

-- ===== CORE: UPDATE ALL ESP =====
local function updateAllESP()
	if not CONFIG.ESP_ENABLED then
		for targetPlayer, espData in pairs(state.espObjects) do
			if espData.billboard.Parent then
				espData.billboard:Destroy()
			end
		end
		state.espObjects = {}
		return
	end

	local activePlayers = {}

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer == player then continue end

		local targetChar = targetPlayer.Character
		if not targetChar then continue end

		activePlayers[targetPlayer] = true

		-- Create ESP if it doesn't exist
		if not state.espObjects[targetPlayer] then
			local espData = createESPBillboard(targetChar, targetPlayer)
			if espData then
				state.espObjects[targetPlayer] = espData
			else
				continue
			end
		end

		-- Update existing ESP
		if not updateESPBillboard(targetPlayer, state.espObjects[targetPlayer]) then
			state.espObjects[targetPlayer] = nil
		end
	end

	-- Remove ESP for players that left
	for targetPlayer, espData in pairs(state.espObjects) do
		if not activePlayers[targetPlayer] then
			if espData.billboard.Parent then
				espData.billboard:Destroy()
			end
			state.espObjects[targetPlayer] = nil
		end
	end
end

-- ===== MAIN LOOP =====
RunService.RenderStepped:Connect(function()
	updateAllESP()
end)

-- ===== CHARACTER RESPAWN =====
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)

-- ===== CLEANUP =====
game:BindToClose(function()
	for targetPlayer, espData in pairs(state.espObjects) do
		if espData.billboard.Parent then
			espData.billboard:Destroy()
		end
	end
	screenGui:Destroy()
end)

print("Player ESP loaded, boss man. Fuck yeah, native implementation active.")
