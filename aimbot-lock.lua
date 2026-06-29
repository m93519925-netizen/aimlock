-- ==================== PROFESSIONAL CAMERA LOCK SYSTEM ====================
-- Roblox Mobile | Luau | Executor Delta
-- Created by: Axiom | Fixed: Camera Override + Touch Adaptation

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = workspace

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ==================== CONFIGURATION ====================
local CONFIG = {
	LOCK_RADIUS = 35,
	LOCK_ENABLED = false,
	SMOOTHING_FACTOR = 0.15,
	MAX_DISTANCE = 100,
	HEAD_OFFSET = Vector3.new(0, 0.5, 0),
	UNLOCK_THRESHOLD = 45,
	RAYCAST_IGNORE = {character},
}

local CURRENT_TARGET = nil
local TOUCH_INPUT_CACHE = {startPos = nil, lastPos = nil}
local SYSTEM_STATE = {isActive = false, lastSwipeTime = 0}

-- ==================== DRAWING SETUP ====================
local Drawing = loadstring(game:HttpGet("https://raw.githubusercontent.com/Stefanuk12/Drawing/main/src/Drawing.lua"))() or {}

local LOCK_CIRCLE = Drawing.new("Circle")
LOCK_CIRCLE.Visible = false
LOCK_CIRCLE.Radius = CONFIG.LOCK_RADIUS
LOCK_CIRCLE.Color = Color3.fromRGB(34, 177, 76)
LOCK_CIRCLE.Thickness = 2
LOCK_CIRCLE.Filled = false

local TOGGLE_BUTTON = Drawing.new("Rectangle")
TOGGLE_BUTTON.Size = Vector2.new(90, 40)
TOGGLE_BUTTON.Position = Vector2.new(20, 20)
TOGGLE_BUTTON.Color = Color3.fromRGB(50, 50, 50)
TOGGLE_BUTTON.Filled = true

local TOGGLE_TEXT = Drawing.new("Text")
TOGGLE_TEXT.Position = Vector2.new(35, 27)
TOGGLE_TEXT.Size = 18
TOGGLE_TEXT.Color = Color3.fromRGB(255, 255, 255)
TOGGLE_TEXT.Text = "AIM: OFF"

-- ==================== UTILITY FUNCTIONS ====================

local function LineOfSightCheck(targetHead)
	if not targetHead then return false end
	
	local rayOrigin = humanoidRootPart.Position + Vector3.new(0, 2, 0)
	local rayDirection = (targetHead.Position - rayOrigin).Unit * 500
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.FilterDescendantsInstances = CONFIG.RAYCAST_IGNORE
	
	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if not rayResult then return true end
	
	local hitPart = rayResult.Instance
	local hitCharacter = hitPart.Parent
	
	return hitCharacter and hitCharacter:FindFirstChild("Humanoid") ~= nil
end

local function GetNearestEnemy()
	local closestTarget = nil
	local closestDistance = CONFIG.MAX_DISTANCE
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer == player or not otherPlayer.Character then continue end
		
		local otherCharacter = otherPlayer.Character
		local otherHead = otherCharacter:FindFirstChild("Head")
		local otherHumanoid = otherCharacter:FindFirstChild("Humanoid")
		
		if otherHead and otherHumanoid and otherHumanoid.Health > 0 then
			local distance = (otherHead.Position - humanoidRootPart.Position).Magnitude
			
			if distance < closestDistance and LineOfSightCheck(otherHead) then
				closestDistance = distance
				closestTarget = otherHead
			end
		end
	end
	
	return closestTarget
end

local function WorldToScreenPoint(worldPos)
	local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
	return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

local function IsTargetInLockZone(targetHead)
	if not targetHead then return false end
	
	local screenPos, onScreen = WorldToScreenPoint(targetHead.Position)
	if not onScreen then return false end
	
	local centerX, centerY = camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2
	local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
	
	return distance <= CONFIG.UNLOCK_THRESHOLD
end

local function UnlockTarget()
	CURRENT_TARGET = nil
	LOCK_CIRCLE.Visible = false
end

-- ==================== CAMERA MANIPULATION ====================

local function UpdateCameraLock()
	if not SYSTEM_STATE.isActive or not CURRENT_TARGET then return end
	
	local targetHead = CURRENT_TARGET
	if not targetHead or not targetHead.Parent then
		UnlockTarget()
		return
	end
	
	-- Check if target is still in lock zone
	if not IsTargetInLockZone(targetHead) then
		UnlockTarget()
		return
	end
	
	-- Smooth camera rotation using relative CFrame (respects touch input)
	local targetPosition = targetHead.Position + CONFIG.HEAD_OFFSET
	local cameraPosition = camera.CFrame.Position
	local directionToTarget = (targetPosition - cameraPosition).Unit
	
	-- Create new CFrame that looks at target while maintaining distance
	local newCFrame = CFrame.new(cameraPosition, cameraPosition + directionToTarget)
	
	-- Interpolate smoothly instead of snapping
	camera.CFrame = camera.CFrame:Lerp(newCFrame, CONFIG.SMOOTHING_FACTOR)
	
	-- Update UI circle position
	local screenPos, onScreen = WorldToScreenPoint(targetHead.Position)
	if onScreen then
		LOCK_CIRCLE.Position = screenPos - Vector2.new(CONFIG.LOCK_RADIUS, CONFIG.LOCK_RADIUS)
		LOCK_CIRCLE.Visible = true
	else
		LOCK_CIRCLE.Visible = false
	end
end

-- ==================== INPUT HANDLING ====================

local function HandleToggleButton(inputPos)
	local buttonPos = TOGGLE_BUTTON.Position
	local buttonSize = TOGGLE_BUTTON.Size
	
	if inputPos.X >= buttonPos.X and inputPos.X <= buttonPos.X + buttonSize.X and
	   inputPos.Y >= buttonPos.Y and inputPos.Y <= buttonPos.Y + buttonSize.Y then
		SYSTEM_STATE.isActive = not SYSTEM_STATE.isActive
		TOGGLE_TEXT.Text = SYSTEM_STATE.isActive and "AIM: ON" or "AIM: OFF"
		TOGGLE_BUTTON.Color = SYSTEM_STATE.isActive and Color3.fromRGB(76, 175, 80) or Color3.fromRGB(50, 50, 50)
		
		if not SYSTEM_STATE.isActive then
			UnlockTarget()
		end
	end
end

local function HandleTouchMovement(inputPos)
	if not SYSTEM_STATE.isActive then return end
	
	-- Detect swipe: if movement is too large, unlock target
	if TOUCH_INPUT_CACHE.lastPos then
		local swipeDelta = (inputPos - TOUCH_INPUT_CACHE.lastPos).Magnitude
		if swipeDelta > 15 then
			SYSTEM_STATE.lastSwipeTime = tick()
			UnlockTarget()
		end
	end
	
	TOUCH_INPUT_CACHE.lastPos = inputPos
end

-- ==================== EVENT CONNECTIONS ====================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.Touch then
		local touchPos = input.Position
		TOUCH_INPUT_CACHE.startPos = touchPos
		TOUCH_INPUT_CACHE.lastPos = touchPos
		HandleToggleButton(touchPos)
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.Touch then
		HandleTouchMovement(input.Position)
	end
end)

-- ==================== MAIN LOOP ====================

RunService.RenderStepped:Connect(function()
	if not SYSTEM_STATE.isActive then
		LOCK_CIRCLE.Visible = false
		return
	end
	
	-- Auto-acquire nearest target if none selected
	if not CURRENT_TARGET then
		CURRENT_TARGET = GetNearestEnemy()
	end
	
	-- Update camera lock
	UpdateCameraLock()
	
	-- Update button position
	TOGGLE_TEXT.Position = TOGGLE_BUTTON.Position + Vector2.new(15, 7)
end)

-- ==================== CLEANUP ====================

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	CONFIG.RAYCAST_IGNORE = {character}
	UnlockTarget()
end)

game:GetService("RunService").Heartbeat:Connect(function()
	if character and not character:FindFirstChild("Humanoid") or character:FindFirstChild("Humanoid").Health <= 0 then
		UnlockTarget()
	end
end)

print("✓ Camera Lock System Initialized | Mobile Optimized | Fuck yeah, ready to go boss man")
