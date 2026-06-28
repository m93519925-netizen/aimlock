-- Nyx Camera Lock-On System for Roblox Mobile (Delta Executor)
-- Professional, Optimized, First-Person Fixed

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Config
local AIM_RADIUS = 35 -- pixels
local SMOOTHNESS = 0.15 -- lower = faster lock
local MAX_DISTANCE = 500
local TOGGLE_KEY = Enum.KeyCode.F -- fallback if needed

local isAiming = false
local currentTarget = nil
local circle = nil
local toggleButton = nil

-- Create Drawing Circle
local function createCircle()
	if circle then circle:Remove() end
	circle = Drawing.new("Circle")
	circle.Color = Color3.fromRGB(0, 255, 0)
	circle.Thickness = 2
	circle.NumSides = 64
	circle.Radius = AIM_RADIUS
	circle.Filled = false
	circle.Transparency = 0.7
	circle.Visible = false
end

-- Create Draggable Toggle Button
local function createToggleButton()
	local screenGui = Instance.new("ScreenGui")
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(0, 80, 0, 40)
	toggleButton.Position = UDim2.new(0.5, -40, 0.1, 0)
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	toggleButton.BackgroundTransparency = 0.3
	toggleButton.Text = "AIM: OFF"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = screenGui

	-- Draggable
	local dragging = false
	local dragInput
	local dragStart
	local startPos

	local function update(input)
		local delta = input.Position - dragStart
		toggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	toggleButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = toggleButton.Position
		end
	end)

	toggleButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)

	toggleButton.MouseButton1Click:Connect(function()
		isAiming = not isAiming
		toggleButton.Text = isAiming and "AIM: ON" or "AIM: OFF"
		toggleButton.BackgroundColor3 = isAiming and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(0, 0, 0)
		if not isAiming then
			currentTarget = nil
		end
	end)
end

-- Get closest target in circle
local function getClosestTarget()
	local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local closest = nil
	local minDist = AIM_RADIUS + 1

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local character = player.Character
			local head = character:FindFirstChild("Head")
			if head then
				local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
				if onScreen then
					local screenPos = Vector2.new(headPos.X, headPos.Y)
					local dist = (screenPos - mousePos).Magnitude
					if dist < minDist then
						-- LOS Check
						local rayOrigin = Camera.CFrame.Position
						local rayDirection = (head.Position - rayOrigin).Unit * MAX_DISTANCE
						local raycastParams = RaycastParams.new()
						raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
						raycastParams.FilterType = Enum.RaycastFilterType.Exclude
						raycastParams.IgnoreWater = true

						local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
						if result and result.Instance:IsDescendantOf(character) then
							minDist = dist
							closest = head
						end
					end
				end
			end
		end
	end
	return closest
end

-- Auto unlock if target out of circle
local function shouldUnlockTarget(targetHead)
	if not targetHead then return true end
	local headPos = Camera:WorldToViewportPoint(targetHead.Position)
	if not headPos.Z > 0 then return true end
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local dist = (Vector2.new(headPos.X, headPos.Y) - center).Magnitude
	return dist > AIM_RADIUS
end

-- Main loop
local connection
local function startAimSystem()
	if connection then connection:Disconnect() end

	createCircle()
	createToggleButton()

	connection = RunService.RenderStepped:Connect(function(dt)
		if not isAiming then
			if circle then circle.Visible = false end
			currentTarget = nil
			return
		end

		if circle then
			circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
			circle.Visible = true
		end

		-- Update target
		if not currentTarget or shouldUnlockTarget(currentTarget) then
			currentTarget = getClosestTarget()
		end

		if currentTarget and currentTarget.Parent then
			local targetPos = currentTarget.Position

			-- Smooth lock using relative CFrame (mobile first-person friendly)
			local currentCFrame = Camera.CFrame
			local lookAtCFrame = CFrame.lookAt(currentCFrame.Position, targetPos)

			-- Interpolate smoothly
			Camera.CFrame = currentCFrame:Lerp(lookAtCFrame, SMOOTHNESS)
		else
			currentTarget = nil
		end
	end)
end

-- Cleanup
local function stopAimSystem()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if circle then
		circle:Remove()
		circle = nil
	end
	if toggleButton and toggleButton.Parent then
		toggleButton.Parent:Destroy()
	end
end

-- Initialize
startAimSystem()

-- Toggle with keyboard fallback (for testing)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == TOGGLE_KEY then
		isAiming = not isAiming
		if toggleButton then
			toggleButton.Text = isAiming and "AIM: ON" or "AIM: OFF"
			toggleButton.BackgroundColor3 = isAiming and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(0, 0, 0)
		end
		if not isAiming then currentTarget = nil end
	end
end)

-- Auto restart if character respawns
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if isAiming then
		startAimSystem()
	end
end)-- Nyx Camera Lock-On System for Roblox Mobile (Delta Executor)
-- Professional, Optimized, First-Person Fixed

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Config
local AIM_RADIUS = 35 -- pixels
local SMOOTHNESS = 0.15 -- lower = faster lock
local MAX_DISTANCE = 500
local TOGGLE_KEY = Enum.KeyCode.F -- fallback if needed

local isAiming = false
local currentTarget = nil
local circle = nil
local toggleButton = nil

-- Create Drawing Circle
local function createCircle()
	if circle then circle:Remove() end
	circle = Drawing.new("Circle")
	circle.Color = Color3.fromRGB(0, 255, 0)
	circle.Thickness = 2
	circle.NumSides = 64
	circle.Radius = AIM_RADIUS
	circle.Filled = false
	circle.Transparency = 0.7
	circle.Visible = false
end

-- Create Draggable Toggle Button
local function createToggleButton()
	local screenGui = Instance.new("ScreenGui")
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	toggleButton = Instance.new("TextButton")
	toggleButton.Size = UDim2.new(0, 80, 0, 40)
	toggleButton.Position = UDim2.new(0.5, -40, 0.1, 0)
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	toggleButton.BackgroundTransparency = 0.3
	toggleButton.Text = "AIM: OFF"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.BorderSizePixel = 0
	toggleButton.Parent = screenGui

	-- Draggable
	local dragging = false
	local dragInput
	local dragStart
	local startPos

	local function update(input)
		local delta = input.Position - dragStart
		toggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	toggleButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = toggleButton.Position
		end
	end)

	toggleButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)

	toggleButton.MouseButton1Click:Connect(function()
		isAiming = not isAiming
		toggleButton.Text = isAiming and "AIM: ON" or "AIM: OFF"
		toggleButton.BackgroundColor3 = isAiming and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(0, 0, 0)
		if not isAiming then
			currentTarget = nil
		end
	end)
end

-- Get closest target in circle
local function getClosestTarget()
	local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local closest = nil
	local minDist = AIM_RADIUS + 1

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local character = player.Character
			local head = character:FindFirstChild("Head")
			if head then
				local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
				if onScreen then
					local screenPos = Vector2.new(headPos.X, headPos.Y)
					local dist = (screenPos - mousePos).Magnitude
					if dist < minDist then
						-- LOS Check
						local rayOrigin = Camera.CFrame.Position
						local rayDirection = (head.Position - rayOrigin).Unit * MAX_DISTANCE
						local raycastParams = RaycastParams.new()
						raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
						raycastParams.FilterType = Enum.RaycastFilterType.Exclude
						raycastParams.IgnoreWater = true

						local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
						if result and result.Instance:IsDescendantOf(character) then
							minDist = dist
							closest = head
						end
					end
				end
			end
		end
	end
	return closest
end

-- Auto unlock if target out of circle
local function shouldUnlockTarget(targetHead)
	if not targetHead then return true end
	local headPos = Camera:WorldToViewportPoint(targetHead.Position)
	if not headPos.Z > 0 then return true end
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local dist = (Vector2.new(headPos.X, headPos.Y) - center).Magnitude
	return dist > AIM_RADIUS
end

-- Main loop
local connection
local function startAimSystem()
	if connection then connection:Disconnect() end

	createCircle()
	createToggleButton()

	connection = RunService.RenderStepped:Connect(function(dt)
		if not isAiming then
			if circle then circle.Visible = false end
			currentTarget = nil
			return
		end

		if circle then
			circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
			circle.Visible = true
		end

		-- Update target
		if not currentTarget or shouldUnlockTarget(currentTarget) then
			currentTarget = getClosestTarget()
		end

		if currentTarget and currentTarget.Parent then
			local targetPos = currentTarget.Position

			-- Smooth lock using relative CFrame (mobile first-person friendly)
			local currentCFrame = Camera.CFrame
			local lookAtCFrame = CFrame.lookAt(currentCFrame.Position, targetPos)

			-- Interpolate smoothly
			Camera.CFrame = currentCFrame:Lerp(lookAtCFrame, SMOOTHNESS)
		else
			currentTarget = nil
		end
	end)
end

-- Cleanup
local function stopAimSystem()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if circle then
		circle:Remove()
		circle = nil
	end
	if toggleButton and toggleButton.Parent then
		toggleButton.Parent:Destroy()
	end
end

-- Initialize
startAimSystem()

-- Toggle with keyboard fallback (for testing)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == TOGGLE_KEY then
		isAiming = not isAiming
		if toggleButton then
			toggleButton.Text = isAiming and "AIM: ON" or "AIM: OFF"
			toggleButton.BackgroundColor3 = isAiming and Color3.fromRGB(0, 100, 0) or Color3.fromRGB(0, 0, 0)
		end
		if not isAiming then currentTarget = nil end
	end
end)

-- Auto restart if character respawns
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if isAiming then
		startAimSystem()
	end
end)
