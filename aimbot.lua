-- Nyx Aimbot with Fixed Center Circle
-- Paste into a LocalScript in StarterPlayerScripts or use executor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Settings
local FOV = 150
local Smoothness = 0.5  -- Lower = faster snap (0.1-1)
local TargetPart = "Head"  -- Head, HumanoidRootPart, UpperTorso
local TeamCheck = true
local ToggleKey = Enum.KeyCode.RightAlt

-- State
local aimbotEnabled = false
local target = nil

-- Fixed Center Circle (Drawing API)
local Circle = Drawing.new("Circle")
Circle.Color = Color3.fromRGB(255, 0, 255)
Circle.Thickness = 2
Circle.NumSides = 64
Circle.Radius = FOV
Circle.Filled = false
Circle.Transparency = 0.8
Circle.Visible = true

-- Update circle position to screen center
local function updateCircle()
    Circle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

-- Get closest player in FOV
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = FOV
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            if TeamCheck and player.Team == LocalPlayer.Team then continue end
            
            local targetPart = player.Character:FindFirstChild(TargetPart)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- Aimbot loop
RunService.RenderStepped:Connect(function()
    updateCircle()
    
    if not aimbotEnabled then
        target = nil
        return
    end
    
    target = getClosestPlayer()
    
    if target and target.Character and target.Character:FindFirstChild(TargetPart) then
        local targetPos = target.Character[TargetPart].Position
        local direction = (targetPos - Camera.CFrame.Position).Unit
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
        
        -- Smooth aim
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Smoothness)
    end
end)

-- Toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == ToggleKey then
        aimbotEnabled = not aimbotEnabled
        print("Nyx Aimbot: " .. (aimbotEnabled and "ENABLED" or "DISABLED"))
    end
end)

-- Cleanup on destroy
game:GetService("CoreGui").DescendantAdded:Connect(function() end) -- placeholder

print("Nyx Aimbot with fixed center circle loaded. Press RightAlt to toggle.")
