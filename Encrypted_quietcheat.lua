local player = game.Players.LocalPlayer
local camera = game.Workspace.CurrentCamera
local userInput = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local mouse = player:GetMouse()

local defaultAimStrength = 0.15
local headAimStrength = 0.26
local lockRadius = 75
local camLocked = false
local targetPlayer = nil
local targetPlayerDeathConnection = nil

-- Function to check if the player is knocked (low health, not dead)
local function isKnockedDown(target)
    if target.Character then
        local humanoid = target.Character:FindFirstChild("Humanoid")
        if humanoid then
            -- Consider the player knocked if their health is below a threshold (like 3), but not fully dead
            return humanoid.Health > 0 and humanoid.Health <= 3
        end
    end
    return false
end

-- Function to check if the player is a valid target (alive and not knocked down)
local function isValidTarget(target)
    if target and target.Character then
        local humanoid = target.Character:FindFirstChild("Humanoid")
        return humanoid and humanoid.Health > 0 and not isKnockedDown(target)
    end
    return false
end

-- Function to get the nearest valid player to the cursor
local function getNearestPlayerToCursor()
    local closestPlayer = nil
    local closestDistance = lockRadius

    for _, target in pairs(game.Players:GetPlayers()) do
        if target ~= player and isValidTarget(target) then
            local targetPart = target.Character:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local screenPosition, onScreen = camera:WorldToScreenPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(screenPosition.X, screenPosition.Y)).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = target
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- Function to toggle aim assist on or off
local function toggleAimAssist()
    if camLocked then
        camLocked = false
        targetPlayer = nil
        if targetPlayerDeathConnection then
            targetPlayerDeathConnection:Disconnect()
            targetPlayerDeathConnection = nil
        end
    else
        local potentialTarget = getNearestPlayerToCursor()
        if potentialTarget then
            camLocked = true
            targetPlayer = potentialTarget
            local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                if targetPlayerDeathConnection then targetPlayerDeathConnection:Disconnect() end
                targetPlayerDeathConnection = humanoid.Died:Connect(function()
                    camLocked = false
                    targetPlayer = nil
                    if targetPlayerDeathConnection then
                        targetPlayerDeathConnection:Disconnect()
                        targetPlayerDeathConnection = nil
                    end
                end)
            end
        end
    end
end

-- Function to smoothly lock the camera onto the target
local function smoothAimLock()
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local humanoid = targetPlayer.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 and not isKnockedDown(targetPlayer) then
            local targetPart = targetPlayer.Character.HumanoidRootPart
            local headPart = targetPlayer.Character:FindFirstChild("Head")
            local currentCFrame = camera.CFrame
            local targetPosition = targetPart.Position
            local currentAimStrength = defaultAimStrength

            -- Aim for the head if the target is jumping or knocked down
            if headPart and humanoid:GetState() == Enum.HumanoidStateType.Jumping then
                targetPosition = headPart.Position
                currentAimStrength = headAimStrength
            end

            -- Smooth the camera movement towards the target
            local targetLookVector = (targetPosition - currentCFrame.Position).unit
            local newLookVector = currentCFrame.LookVector:Lerp(targetLookVector, currentAimStrength)
            camera.CFrame = CFrame.lookAt(currentCFrame.Position, currentCFrame.Position + newLookVector)
        else
            -- If the target is knocked or dead, stop locking on
            camLocked = false
            targetPlayer = nil
            if targetPlayerDeathConnection then
                targetPlayerDeathConnection:Disconnect()
                targetPlayerDeathConnection = nil
            end
        end
    else
        -- Reset if no valid target is found
        camLocked = false
        targetPlayer = nil
    end
end

-- Toggle aim assist when pressing 'C'
userInput.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.X then
        toggleAimAssist()
    end
end)

-- Update the camera every frame if locked onto a player
runService.RenderStepped:Connect(function()
    if camLocked then
        smoothAimLock()
    end
end)

-- Handle player death and reset the aim assist if the player dies
if player.Character then
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            camLocked = false
            targetPlayer = nil
            if targetPlayerDeathConnection then
                targetPlayerDeathConnection:Disconnect()
                targetPlayerDeathConnection = nil
            end
        end)
    end
end

-- Reset aim assist if the player respawns
player.CharacterAdded:Connect(function(character)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            camLocked = false
            targetPlayer = nil
            if targetPlayerDeathConnection then
                targetPlayerDeathConnection:Disconnect()
                targetPlayerDeathConnection = nil
            end
        end)
    end
end)

getgenv().esp_running = true

local settings = {
    default_color = Color3.fromRGB(255, 255, 255),
    team_check = true,
    outline_thickness = 0.7,
    r6_y_offset = 1.5,
    r15_height_scale = 6,
    width_scale = 3.2,
    esp_enabled = true, -- Add esp_enabled setting
}

local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService") -- Add UserInputService

local local_player = players.LocalPlayer
local camera = workspace.CurrentCamera

local new_vector2, new_drawing = Vector2.new, Drawing.new
local tan, rad = math.tan, math.rad
local round = function(...)
    local result = {}
    for i, v in next, table.pack(...) do
        result[i] = math.round(v)
    end
    return unpack(result)
end
local world_to_viewport = function(...)
    local pos, on_screen, depth = camera:WorldToViewportPoint(...)
    return new_vector2(pos.X, pos.Y), on_screen, pos.Z
end

getgenv().esp_cache = {}

local function create_esp(player)
    local drawings = {}

    drawings.box = new_drawing("Square")
    drawings.box.Thickness = 1
    drawings.box.Filled = false
    drawings.box.Color = settings.default_color
    drawings.box.Visible = false
    drawings.box.ZIndex = 2

    drawings.outline = new_drawing("Square")
    drawings.outline.Thickness = settings.outline_thickness
    drawings.outline.Filled = false
    drawings.outline.Color = Color3.new(0, 0, 0)
    drawings.outline.Visible = false
    drawings.outline.ZIndex = 1

    drawings.inner_outline = new_drawing("Square")
    drawings.inner_outline.Thickness = settings.outline_thickness
    drawings.inner_outline.Filled = false
    drawings.inner_outline.Color = Color3.new(0, 0, 0)
    drawings.inner_outline.Visible = false
    drawings.inner_outline.ZIndex = 1

    drawings.healthbar = new_drawing("Line")
    drawings.healthbar.Thickness = 3
    drawings.healthbar.Color = Color3.new(0, 0, 0)
    drawings.healthbar.Visible = false
    drawings.healthbar.ZIndex = 3

    drawings.greenhealth = new_drawing("Line")
    drawings.greenhealth.Thickness = 1.5
    drawings.greenhealth.Color = Color3.new(0, 255, 0)
    drawings.greenhealth.Visible = false
    drawings.greenhealth.ZIndex = 4

    getgenv().esp_cache[player] = drawings
end

local function remove_esp(player)
    if getgenv().esp_cache[player] then
        for _, drawing in pairs(getgenv().esp_cache[player]) do
            drawing:Remove()
        end
        getgenv().esp_cache[player] = nil
    end
end

local function update_esp(player, esp)
    local character = player and player.Character
    if character then
        local root_part = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
        local humanoid = character:FindFirstChild("Humanoid")
        if root_part and humanoid then
            local cframe = root_part.CFrame
            local position, visible, depth = world_to_viewport(cframe.Position)

            if visible and settings.esp_enabled then -- Check if esp_enabled
                local scale_factor = 1 / (depth * tan(rad(camera.FieldOfView / 2)) * 2) * 1000

                local width = round(settings.width_scale * scale_factor)
                local height = round(
                    (character:FindFirstChild("Torso") and not character:FindFirstChild("HumanoidRootPart") and settings.r6_y_offset or settings.r15_height_scale) * scale_factor
                )

                local x, y = round(position.X, position.Y)

                if character:FindFirstChild("Torso") and not character:FindFirstChild("HumanoidRootPart") then
                    y = y + (settings.r6_y_offset * height / 2)
                end

                esp.box.Size = new_vector2(width, height)
                esp.box.Position = new_vector2(x - width / 2, y - height / 2)

                if settings.team_check and local_player.Team then
                    if player.Team == local_player.Team then
                        esp.box.Visible = false
                        esp.outline.Visible = false
                        esp.inner_outline.Visible = false
                        esp.healthbar.Visible = false
                        esp.greenhealth.Visible = false
                        return -- Skip the rest of the update
                    else
                        -- Use the player's team color
                        if player.TeamColor then
                            esp.box.Color = player.TeamColor.Color
                        else
                            esp.box.Color = settings.default_color
                        end

                    end
                else
                    esp.box.Color = settings.default_color
                end

                esp.box.Visible = true

                esp.outline.Size = esp.box.Size + new_vector2(2, 2)
                esp.outline.Position = esp.box.Position - new_vector2(1, 1)
                esp.outline.Visible = true

                esp.inner_outline.Size = esp.box.Size - new_vector2(1, 1)
                esp.inner_outline.Position = esp.box.Position + new_vector2(1, 1)
                esp.inner_outline.Visible = true

                -- Healthbar
                local healthoffset = humanoid.Health / humanoid.MaxHealth * height
                esp.healthbar.From = new_vector2(x - width / 2 - 4, y + height / 2)
                esp.healthbar.To = new_vector2(x - width / 2 - 4, y - height / 2)
                esp.healthbar.Visible = true

                esp.greenhealth.From = new_vector2(x - width / 2 - 4, y + height / 2)
                esp.greenhealth.To = new_vector2(x - width / 2 - 4, y + height / 2 - healthoffset)
                esp.greenhealth.Color = Color3.fromRGB(255, 0, 0):lerp(Color3.fromRGB(0, 255, 0), humanoid.Health / humanoid.MaxHealth)
                esp.greenhealth.Visible = true

            else
                esp.box.Visible = false
                esp.outline.Visible = false
                esp.inner_outline.Visible = false
                esp.healthbar.Visible = false
                esp.greenhealth.Visible = false
            end
        end
    else
        esp.box.Visible = false
        esp.outline.Visible = false
        esp.inner_outline.Visible = false
        esp.healthbar.Visible = false
        esp.greenhealth.Visible = false
    end
end

for _, player in pairs(players:GetPlayers()) do
    if player ~= local_player then
        create_esp(player)
    end
end

players.PlayerAdded:Connect(create_esp)
players.PlayerRemoving:Connect(remove_esp)

run_service:BindToRenderStep("esp_render", Enum.RenderPriority.Camera.Value, function()
    for player, drawings in pairs(getgenv().esp_cache) do
        update_esp(player, drawings)
    end
end)

-- Toggle ESP with 'V' key
userInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
        settings.esp_enabled = not settings.esp_enabled
    end
end)
-- Check if the script is already loaded
if getgenv().triggerbotLoaded then
    print("Triggerbot is already loaded.")
    return
end

-- Mark the script as loaded
getgenv().triggerbotLoaded = true

-- Define the triggerbot table
getgenv().triggerbot = {
    Settings = {
        isEnabled = false,  -- Determines if clicking is enabled
        clickDelay = 0,   -- Time in seconds to wait before clicking
        toggleKey = Enum.KeyCode.T,  -- Key to toggle the clicking on and off
        lastClickTime = 0   -- Tracks the last click time
    },
    load = function()
        local Players = game:GetService("Players")
        local UserInputService = game:GetService("UserInputService")
        local StarterGui = game:GetService("StarterGui")
        local LocalPlayer = Players.LocalPlayer
        local mouse = LocalPlayer:GetMouse()

        -- Function to check if the player is knocked (low health, not dead)
        local function isKnockedDown(target)
            if target.Character then
                local humanoid = target.Character:FindFirstChild("Humanoid")
                if humanoid then
                    -- Consider the player knocked if their health is below a threshold (like 3), but not fully dead
                    return humanoid.Health > 0 and humanoid.Health <= 3
                end
            end
            return false
        end

        -- Function to simulate mouse click
        local function simulateClick()
            mouse1click()
        end

        -- Function to check if the hovered part belongs to another player and is not knocked or dead
        local function isHoveringValidPlayer()
            local target = mouse.Target

            if target then
                local character = target:FindFirstAncestorOfClass("Model")
                if character and Players:GetPlayerFromCharacter(character) then
                    local player = Players:GetPlayerFromCharacter(character)
                    local humanoid = character:FindFirstChild("Humanoid")

                    -- Ensure the character is not knocked down or dead
                    if humanoid and humanoid.Health > 0 and not isKnockedDown(player) then
                        return true
                    end
                end
            end
            return false
        end

        -- Function to create a notification in the bottom right
        local function createNotification(message)
            StarterGui:SetCore("SendNotification", {
                Title = "Triggerbot",
                Text = message,
                Duration = 2,  -- Duration in seconds
            })
        end

        -- Listen for the toggle key press
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.KeyCode == getgenv().triggerbot.Settings.toggleKey and not gameProcessed then
                getgenv().triggerbot.Settings.isEnabled = not getgenv().triggerbot.Settings.isEnabled
                local statusMessage = getgenv().triggerbot.Settings.isEnabled and "enabled -gg.phantomcc" or "disabled - gg.phantomcc"
                print("Triggerbot is now " .. statusMessage)
                
                -- Show notification
                createNotification("Triggerbot is now " .. statusMessage)
            end
        end)

        -- Listen to mouse movement
        mouse.Move:Connect(function()
            if getgenv().triggerbot.Settings.isEnabled and isHoveringValidPlayer() then
                local currentTime = tick()
                if currentTime - getgenv().triggerbot.Settings.lastClickTime >= getgenv().triggerbot.Settings.clickDelay then
                    simulateClick()
                    getgenv().triggerbot.Settings.lastClickTime = currentTime
                end
            end
        end)
    end
}

-- Load the Triggerbot
getgenv().triggerbot.load()
