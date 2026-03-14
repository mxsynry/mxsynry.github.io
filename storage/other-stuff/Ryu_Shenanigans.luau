-- =============================================
-- Ryu's JJS script (FIXED)
-- Stare fixed, targetting, highlight on locked target,
-- BLACK FLASH + PERFECT TODO SWAP (players + NPCs)
-- 
-- FIXES:
-- • Auto-unlocks when target leaves the game
-- • Auto-renews targeting on death + respawn (seamless for players)
-- • Shows "Waiting for respawn" during the short death window
-- =============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local SCRIPT_ID = "RyuJJS"
if _G[SCRIPT_ID] then
    pcall(_G[SCRIPT_ID])
end

pcall(function()
    local old = PlayerGui:FindFirstChild("GameSenseHUD")
    if old then old:Destroy() end
end)
pcall(function()
    for _, obj in workspace:GetChildren() do
        if obj:IsA("Highlight") and obj.OutlineColor == Color3.new(1, 0, 0) then
            obj:Destroy()
        end
    end
end)
_G[SCRIPT_ID] = nil
-- =======================================================================
local Connections = {}
local function Cleanup()
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    pcall(function()
        local old = PlayerGui:FindFirstChild("GameSenseHUD")
        if old then old:Destroy() end
    end)
    pcall(function()
        for _, obj in workspace:GetChildren() do
            if obj:IsA("Highlight") and obj.OutlineColor == Color3.new(1, 0, 0) then
                obj:Destroy()
            end
        end
    end)
    _G[SCRIPT_ID] = nil
end
_G[SCRIPT_ID] = Cleanup

local GUI, Status, Credits
local function createHUD()
    local old = PlayerGui:FindFirstChild("GameSenseHUD")
    if old then old:Destroy() end
    GUI = Instance.new("ScreenGui")
    GUI.Name = "GameSenseHUD"
    GUI.ResetOnSpawn = false
    GUI.Parent = PlayerGui
    Status = Instance.new("TextLabel", GUI)
    Status.Size = UDim2.new(0, 500, 0, 50)
    Status.Position = UDim2.new(0.5, -250, 0.85, 0)
    Status.BackgroundTransparency = 1
    Status.TextSize = 28
    Status.Font = Enum.Font.SourceSansBold
    Status.TextColor3 = Color3.new(1,1,1)
    Status.TextStrokeTransparency = 0.5
    Status.Text = "On Standby"
    Credits = Status:Clone()
    Credits.TextSize = 14
    Credits.Text = "Ryu's JJS script"
    Credits.Position = UDim2.new(0.5, -250, 0.85, -25)
    Credits.Parent = GUI
end
createHUD()
table.insert(Connections, PlayerGui.ChildRemoved:Connect(function(child)
    if child.Name == "GameSenseHUD" then
        createHUD()
    end
end))

-- ===================================================================
-- Config
local ToggleKey = Enum.KeyCode.C
local ModeCycleKey = Enum.KeyCode.M
local LockYKey = Enum.KeyCode.V
local TeleportKey = Enum.KeyCode.X
local BackOffset = 3
local HighlightColor = Color3.new(1, 0, 0)
local AimPart = "Torso"
local SmoothAim = false
local Sensitivity = 0.22
local AngleOffset = -30
local AimHorizontalOffset = 2.2

-- Auto BF + Swap
local ENABLE_AUTO_BLACKFLASH = true
local mode2Delay = 0.1
local swapAudioId = "rbxassetid://17156034319"

-- State
local isActive = false
local currentMode = "stare"
local lockedTarget = nil
local lockedPlayer = nil      -- NEW: tracks Player for auto-respawn
local lockedName = nil        -- NEW: fallback for NPCs
local stareConnection = nil
local LockY = false
local Highlight = nil

-- (all helpers, stareTracking, aimTracking, blackflash functions, setupJJS, loops, input)
local function getRoot(char)
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return (hrp and hrp:IsA("BasePart")) and hrp or char.PrimaryPart
end

local function getLockedTargetRoot()
    if not lockedTarget then return nil end
    return getRoot(lockedTarget)
end

local function updateHighlight()
    if not Highlight then
        Highlight = Instance.new("Highlight")
        Highlight.FillTransparency = 1
        Highlight.OutlineColor = HighlightColor
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end
    if isActive and lockedTarget then
        Highlight.Adornee = lockedTarget
        Highlight.Parent = workspace
    else
        Highlight.Adornee = nil
        Highlight.Parent = nil
    end
end

local function findScreenCenterTarget()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local closest, minDist = nil, math.huge
    for _, obj in workspace.Characters:GetChildren() do
        if not obj:IsA("Model") then continue end
        if LocalPlayer.Character and obj == LocalPlayer.Character then continue end
        local hum = obj:FindFirstChild("Humanoid")
        local part = obj:FindFirstChild(AimPart)
        if not (hum and part and hum.Health > 0) then continue end
        local pt, onScreen = Camera:WorldToScreenPoint(part.Position)
        if onScreen and pt.Z > 0 then
            local dist = (Vector2.new(pt.X, pt.Y) - center).Magnitude
            if dist < minDist then
                minDist = dist
                closest = obj
            end
        end
    end
    return closest
end

local function stareTracking()
    if not isActive or currentMode ~= "stare" then return end
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    if not myRoot then return end
    local tRoot = getLockedTargetRoot()
    if not tRoot then return end
    local targetPos = tRoot.Position
    local lookAt = LockY and Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z) or targetPos
    local targetCF = CFrame.lookAt(myRoot.Position, lookAt)
    if SmoothAim then
        myRoot.CFrame = myRoot.CFrame:Lerp(targetCF, Sensitivity)
    else
        myRoot.CFrame = targetCF
    end
end

local function startStareLoop()
    if stareConnection then stareConnection:Disconnect() end
    if isActive and currentMode == "stare" and lockedTarget then
        stareConnection = RunService.RenderStepped:Connect(stareTracking)
    end
end

local function aimTracking()
    if not isActive or currentMode ~= "aim" then return end
    local tPart = lockedTarget and lockedTarget:FindFirstChild(AimPart)
    if not tPart then return end
    local targetPos = tPart.Position + (Camera.CFrame.RightVector * AimHorizontalOffset)
    local finalCF
    if LockY then
        local camPos = Camera.CFrame.Position
        local flat = Vector3.new(targetPos.X, camPos.Y, targetPos.Z)
        finalCF = CFrame.new(camPos, flat) * CFrame.Angles(math.rad(AngleOffset), 0, 0)
    else
        finalCF = CFrame.new(Camera.CFrame.Position, targetPos)
    end
    if not SmoothAim or LockY then
        Camera.CFrame = finalCF
    else
        Camera.CFrame = Camera.CFrame:Lerp(finalCF, Sensitivity)
    end
end

-- BLACK FLASH + pressKey + pressMouse1 + pollForSwapAudio + run_ functions
local function pressKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function blackflashgojo() pcall(function() ReplicatedStorage.Knit.Knit.Services.ReversalRedMaxService.RE.Activated:FireServer("false") ReplicatedStorage.Knit.Knit.Services.GojoService.RE.RightActivated:FireServer() end) end
local function blackflashsmg() pcall(function() ReplicatedStorage.Knit.Knit.Services.FocusStrikeService.RE.Activated:FireServer("false") end) end
local function blackflash() pcall(function() ReplicatedStorage.Knit.Knit.Services.DivergentFistService.RE.Activated:FireServer("false") end) end
local function blueflash() pcall(function() ReplicatedStorage.Knit.Knit.Services.DivergentFistService.RE.Activated:FireServer("true") end) end

local function run_blackflashgojo() task.spawn(function() local s = pcall(function() blackflashgojo() task.wait(0.32) blackflashgojo() end) if not s then blueflash() end end) end
local function run_blackflash() task.spawn(function() local s = pcall(function() blackflash() task.wait(0.32) blackflash() end) if not s then blueflash() end end) end
local function run_blackflashsmg() task.spawn(function() local s = pcall(function() blackflashsmg() task.wait(0.32) blackflashsmg() end) if not s then blueflash() end end) end

local function pressMouse1()
    pcall(function()
        ReplicatedStorage.Knit.Knit.Services.TodoService.RE.Activated:FireServer(false)
    end)
end

local function pollForSwapAudio(char)
    local start = tick()
    local conn; conn = RunService.Heartbeat:Connect(function()
        if tick() - start > 2 then conn:Disconnect() return end
        for _, obj in char:GetDescendants() do
            if obj:IsA("Sound") and obj.SoundId == swapAudioId and obj.IsPlaying and obj.Volume > 0 then
                pressMouse1()
                conn:Disconnect()
                break
            end
        end
    end)
end

local function setupJJS(char)
    local hum = char:WaitForChild("Humanoid", 5)
    local anim = hum and hum:WaitForChild("Animator", 5)
    if not anim then return end
    local AnimationTriggers = { ["rbxassetid://100962226150441"] = 0.18, ["rbxassetid://95852624447551"] = 0.18, ["rbxassetid://74145636023952"] = 0.18, ["rbxassetid://72475960800126"] = 0.20 } --3 of the first one are divergent fist from yuji, the last is from mahito's focus strike
    local todo1 = "rbxassetid://100081544058065" --rock sliding anim
    local todo2 = "rbxassetid://123167492985370" --brute force anim
    local swapAnims = { ["rbxassetid://116040503139675"] = true, ["rbxassetid://91074768993486"] = true, ["rbxassetid://131358603583212"] = true }
    anim.AnimationPlayed:Connect(function(track)
        local animId = track.Animation.AnimationId
        local delayTime = AnimationTriggers[animId]
        if delayTime and ENABLE_AUTO_BLACKFLASH then
            task.delay(delayTime, function()
                if hum.Health > 0 then
                    pressKey(Enum.KeyCode.Three)
                end
            end)
        end
        if animId == todo1 then
            task.spawn(function()
                task.wait(0.3)
                if hum.Health > 0 then pressKey(Enum.KeyCode.Two) end
            end)
        elseif animId == todo2 then
            task.spawn(function()
                task.wait(0.6)
                if hum.Health > 0 then pressKey(Enum.KeyCode.Two) end
            end)
        end
        if swapAnims[animId] then
            local len = 1
            if lockedTarget then
                local targetHum = lockedTarget:FindFirstChild("Humanoid")
                if targetHum and targetHum.PlatformStand == true then len = 0.2 end
            end
            task.delay(len/2, function() pressMouse1() end)
            pollForSwapAudio(char)
        end
    end)
end

-- ==================== NEW: VALIDATION + AUTO-RENEW ====================
local function validateLockedTarget()
    if not isActive then return end

    if lockedPlayer then
        -- Player target (auto-respawn + leave detection)
        if Players:GetPlayerByUserId(lockedPlayer.UserId) ~= lockedPlayer then
            -- Player left the game
            lockedTarget = nil
            lockedPlayer = nil
            lockedName = nil
            isActive = false
            return
        end

        local currentChar = lockedPlayer.Character
        if currentChar and currentChar.Parent and currentChar:FindFirstChild("Humanoid") then
            lockedTarget = currentChar
        else
            lockedTarget = nil
            -- keep isActive + lockedPlayer (waiting for respawn)
        end
    else
        -- NPC / non-player
        if not lockedTarget or not lockedTarget.Parent then
            if lockedName then
                local newTarget = workspace.Characters:FindFirstChild(lockedName)
                if newTarget and newTarget:FindFirstChild("Humanoid") then
                    lockedTarget = newTarget
                    return
                end
            end
            lockedTarget = nil
            lockedName = nil
            isActive = false
            return
        end

        local hum = lockedTarget:FindFirstChild("Humanoid")
        if not hum then
            if lockedName then
                local newTarget = workspace.Characters:FindFirstChild(lockedName)
                if newTarget and newTarget ~= lockedTarget and newTarget:FindFirstChild("Humanoid") then
                    lockedTarget = newTarget
                    return
                end
            end
            lockedTarget = nil
            lockedName = nil
            isActive = false
            return
        end
    end
end

-- ===================================================================
table.insert(Connections, RunService.Heartbeat:Connect(function()
    validateLockedTarget()      -- NEW: runs every frame
    updateHighlight()

    local statusText = "On Standby"
    local color = Color3.fromHSV((tick()%5)/5, 0.7, 1)
    if isActive then
        if lockedTarget then
            statusText = (currentMode == "aim" and "🎯 Aiming" or "👁️ Staring") .. " @ " .. lockedTarget.Name
            color = currentMode == "aim" and Color3.fromRGB(80,180,255) or Color3.fromRGB(255,140,60)
        elseif lockedPlayer then
            statusText = "⏳ Waiting for " .. lockedPlayer.Name .. " respawn"
            color = Color3.fromRGB(255, 165, 0)
        end
    end
    Status.Text = statusText
    Status.TextColor3 = color
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if isActive then
        if currentMode == "aim" then aimTracking() elseif currentMode == "stare" then stareTracking() end
    end
end))

-- Input + CharacterAdded
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == ToggleKey then
        if not isActive then
            local candidate = findScreenCenterTarget()
            if candidate then
                lockedTarget = candidate
                lockedPlayer = Players:GetPlayerFromCharacter(candidate)
                lockedName = lockedPlayer and nil or candidate.Name
                isActive = true
            end
        else
            isActive = false
            lockedTarget = nil
            lockedPlayer = nil
            lockedName = nil
            startStareLoop()
        end
    elseif input.KeyCode == ModeCycleKey then
        currentMode = currentMode == "stare" and "aim" or "stare"
        startStareLoop()
    elseif input.KeyCode == LockYKey then
        LockY = not LockY
    elseif input.KeyCode == TeleportKey and lockedTarget then
        local myRoot = getRoot(LocalPlayer.Character)
        local tRoot = getLockedTargetRoot()
        if myRoot and tRoot then myRoot.CFrame = tRoot.CFrame * CFrame.new(0,0,BackOffset) end
    end
end))

game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
    fireproximityprompt(prompt)
end)

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function(c)
    task.wait(0.15)
    setupJJS(c)
end))
if LocalPlayer.Character then task.spawn(setupJJS, LocalPlayer.Character) end

StarterGui:SetCore("SendNotification", {
    Title = "Ryu's JJS • With love",
    Text = "C = lock/unlock target (players + NPCs)\nM = switch stare ↔ aim\nV = toggle Y-lock\nX = TP behind target\n\nNow auto-unlocks on leave & renews on respawn!",
    Duration = 10
})
