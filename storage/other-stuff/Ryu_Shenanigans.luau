local Runtime = {
    Stage = "bootstrap",
    Ready = false,
    Failed = false,
    Errors = {},
    ErrorCount = 0,
    LastError = nil,
}
local latestByStage = {}

function Runtime:Run(label, callback, ...)
    return xpcall(callback, function(err)
        local message = tostring(err)
        local trace = message
        if debug and type(debug.traceback) == "function" then
            local ok, result = pcall(debug.traceback, message, 2)
            if ok then
                trace = result
            end
        end
        self.ErrorCount += 1
        local previous = latestByStage[label]
        if previous and previous.Message == message then
            previous.Count += 1
            self.LastError = previous
            return trace
        end
        local entry = {Stage = label, Message = message, Trace = trace, Count = 1}
        latestByStage[label] = entry
        self.LastError = entry
        table.insert(self.Errors, entry)
        if #self.Errors > 12 then
            table.remove(self.Errors, 1)
        end
        pcall(warn, "[RyuJJS] " .. label .. " failed:\n" .. trace)
        return trace
    end, ...)
end

function Runtime:Report()
    local lines = {
        "[RyuJJS] stage=" .. self.Stage .. " ready=" .. tostring(self.Ready)
            .. " errors=" .. self.ErrorCount,
    }
    for _, entry in ipairs(self.Errors) do
        table.insert(lines, entry.Stage .. " (" .. entry.Count .. "): " .. entry.Trace)
    end
    return table.concat(lines, "\n")
end

local function guard(label, callback)
    return function(...)
        Runtime:Run(label, callback, ...)
    end
end

local function connect(signal, label, callback)
    return signal:Connect(guard(label, callback))
end

local function delay(seconds, label, callback, ...)
    return task.delay(seconds, guard(label, callback), ...)
end

local function defer(label, callback, ...)
    return task.defer(guard(label, callback), ...)
end

local function spawn(label, callback, ...)
    return task.spawn(guard(label, callback), ...)
end

_G.RyuJJS_Diagnostics = Runtime
print("[RyuJJS] bootstrap entered")

local function start()
--[[
    RyuJJS + parsed JJS place adapter
    Standalone client script with labelled runtime diagnostics

    Controls
      C = lock / unlock closest target to screen center
      M = switch stare / aim
      V = toggle Y/pitch behavior
X = instant single-write CFrame teleport behind the target
      Z = facing-led Naoya aerial drift that finishes behind the target

    Notes
      - X/Z use normal HumanoidRootPart CFrame writes, with no hidden-property dependency.
      - No telemetry, webhooks, HttpGet loaders, HWID collection, or remote code loading.
      - Keeps the RyuJJS JJS animation hooks / Black Flash / Todo swap behavior.
      - Target selection remains manual: only C can choose a different target. A lock may
        follow the same player's respawn or the same named NPC, matching the upstream script.
      - X writes its destination once, immediately, without a timer or movement connection.
        Z runs its short facing-led drift; pressing Z again aborts it immediately. No
        TweenService drives root movement, and there is no orbit or lingering CFrame writer.
      - Nanami Ratio Point runs automatically only during a locally owned SpawnRatio event.
        It does not start Ratio Breaker, select targets, bind a key, or repeatedly press R.
        Other Specials are not claimed as automated: this client save lacks their server gates.
      - Runtime failures are recorded locally in _G.RyuJJS_Diagnostics.
      - Uses discovered JJS Knit service paths through a small adapter so the rest of the
        script does not hard-code long ReplicatedStorage paths everywhere.
]]

--==============================================================
-- SERVICES
--==============================================================
Runtime.Stage = "services"
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = nil -- optional; resolve only when an input is needed
local virtualInputUnavailable = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService") -- Naoya visuals only; never root travel
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

Runtime.Stage = "local player"
local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "RyuJJS needs the running player's client; Players.LocalPlayer is unavailable")
local Camera = workspace.CurrentCamera
Runtime.Stage = "PlayerGui"
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
assert(PlayerGui, "PlayerGui did not load within 15 seconds")

local SCRIPT_ID = "RyuJJS"

--==============================================================
-- CLEAN PREVIOUS INSTANCE
--==============================================================
if _G[SCRIPT_ID] then
    if type(_G[SCRIPT_ID]) == "function" then
        Runtime:Run("previous instance cleanup", _G[SCRIPT_ID])
    end
end

pcall(function()
    local old = PlayerGui:FindFirstChild("GameSenseHUD")
    if old then
        old:Destroy()
    end
end)

pcall(function()
    for _, obj in workspace:GetDescendants() do
        if obj:IsA("Highlight") and obj.Name == "RyuTargetHighlight" then
            obj:Destroy()
        end
    end
end)

_G[SCRIPT_ID] = nil

--==============================================================
-- CONNECTION TRACKING
--==============================================================
Runtime.Stage = "lifecycle"
local Connections = {}
local CharacterConnections = {}
local Alive = true
local characterGeneration = 0

local function track(conn)
    table.insert(Connections, conn)
    return conn
end

local function trackCharacter(conn)
    table.insert(CharacterConnections, conn)
    return conn
end

local function clearCharacterConnections()
    for _, conn in ipairs(CharacterConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(CharacterConnections)
end

--==============================================================
-- CONFIG
--==============================================================
local ToggleKey = Enum.KeyCode.C
local ModeCycleKey = Enum.KeyCode.M
local LockYKey = Enum.KeyCode.V
local QuickTeleportKey = Enum.KeyCode.X
local NaoyaAirKey = Enum.KeyCode.Z

local HighlightColor = Color3.new(1, 0, 0)
local AimPart = "Torso"
local SmoothAim = false
local Sensitivity = 0.22
local AimHorizontalOffset = 2.2

-- Target selection. Set to math.huge to preserve the old unlimited behavior.
local TARGET_FOV_PIXELS = math.huge
local TARGET_MAX_DISTANCE = math.huge
local TARGET_REQUIRE_VISIBLE = false

-- X: one immediate placement directly behind the target.
local QUICK_BACK_DISTANCE = 3.0
local QUICK_LOOK_UP_DEGREES = 10

-- Z: exact saved Weave cadence per cycle: 0.10 s hidden + 0.10 s recovery.
local NAOYA_HIDE_TIME = 0.10
local NAOYA_RECOVERY_TIME = 0.10
local NAOYA_FLICK_CYCLE = NAOYA_HIDE_TIME + NAOYA_RECOVERY_TIME
local NAOYA_FLICK_COUNT = 3
local NAOYA_AIR_DURATION = NAOYA_FLICK_CYCLE * NAOYA_FLICK_COUNT
local NAOYA_STOP_DISTANCE = 2.35
local NAOYA_START_DRIFT_MIN = 4.0
local NAOYA_START_DRIFT_MAX = 9.0
local NAOYA_REAR_ENTRY_DISTANCE = 3.5
local NAOYA_ARC_HEIGHT = 4.25
local NAOYA_WEAVE_WIDTH = 1.15
local NAOYA_TARGET_LEAD = 0.045

-- JJS behavior.
local swapAudioId = "rbxassetid://17156034319"

--==============================================================
-- EXISTING JJS AUTOMATION
--==============================================================
local Autos = {
    BlackFlash = true,          -- existing animation-timed BF helper
    TodoSwap = true,            -- existing Todo swap helper
    ShowFOV = false,
}

local CONFIG_FILE = "RyuJJS_Autos.json"

--==============================================================
-- STATE
--==============================================================
local isActive = false
local currentMode = "stare"
local LockY = false

local lockedTarget = nil
local lockedPlayer = nil
local lockedName = nil

local Highlight = nil
local GUI = nil
local Status = nil
local Credits = nil

-- Z owns at most one root writer; X cancels it before one immediate placement.
local movementConnection = nil
local movementState = "IDLE" -- IDLE | NAOYA_AIR
local naoyaHiddenOriginals = setmetatable({}, {__mode = "k"})

local fovDrawing = nil
local ratioMarkers = setmetatable({}, {__mode = "k"})

--==============================================================
-- BASIC HELPERS
--==============================================================
local function getRoot(char)
    if not char then
        return nil
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp
    end

    local primary = char.PrimaryPart
    if primary and primary:IsA("BasePart") then
        return primary
    end

    return nil
end

local function getHumanoid(char)
    if not char then
        return nil
    end
    return char:FindFirstChildOfClass("Humanoid") or char:FindFirstChild("Humanoid")
end

local function getAimPart(char)
    if not char then
        return nil
    end

    return char:FindFirstChild(AimPart)
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function getLockedTargetRoot()
    return getRoot(lockedTarget)
end

local function flatUnit(v, fallback)
    local flat = Vector3.new(v.X, 0, v.Z)
    if flat.Magnitude >= 1e-4 then
        return flat.Unit
    end

    if fallback then
        local fallbackFlat = Vector3.new(fallback.X, 0, fallback.Z)
        if fallbackFlat.Magnitude >= 1e-4 then
            return fallbackFlat.Unit
        end
    end

    return Vector3.new(0, 0, -1)
end

--==============================================================
-- JJS ADAPTER
--==============================================================
local JJS = {}

local function getKnitServices()
    local knit = ReplicatedStorage:FindFirstChild("Knit")
    knit = knit and knit:FindFirstChild("Knit")
    return knit and knit:FindFirstChild("Services")
end

function JJS:GetService(name)
    local services = getKnitServices()
    return services and services:FindFirstChild(name)
end

function JJS:GetRemote(serviceName, remoteName)
    local service = self:GetService(serviceName)
    local re = service and service:FindFirstChild("RE")
    return re and re:FindFirstChild(remoteName)
end

function JJS:Fire(serviceName, remoteName, ...)
    local remote = self:GetRemote(serviceName, remoteName)
    if not remote then
        return false, "missing remote"
    end

    local args = table.pack(...)
    local ok, err = pcall(function()
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
    return ok, err
end

JJS.Moves = {
    DivergentFist = {service = "DivergentFistService", remote = "Activated"},
    FocusStrike = {service = "FocusStrikeService", remote = "Activated"},
    ReversalRedMax = {service = "ReversalRedMaxService", remote = "Activated"},
    GojoRight = {service = "GojoService", remote = "RightActivated"},
    Todo = {service = "TodoService", remote = "Activated"},
}

function JJS:Use(moveName, ...)
    local move = self.Moves[moveName]
    if not move then
        return false, "unknown move"
    end
    return self:Fire(move.service, move.remote, ...)
end

function JJS:HasMove(moveName)
    local move = self.Moves[moveName]
    return move ~= nil and self:GetRemote(move.service, move.remote) ~= nil
end

--==============================================================
-- MOVEMENT / VISIBILITY LIFECYCLE
--==============================================================
local function restoreNaoyaVisibility()
    for obj, transparency in pairs(naoyaHiddenOriginals) do
        if obj and obj.Parent then
            pcall(function()
                obj.Transparency = transparency
            end)
        end
        naoyaHiddenOriginals[obj] = nil
    end
end

local function stopMovementSystem()
    movementState = "IDLE"

    -- Disconnect Z's CFrame writer before restoring its temporary visuals.
    if movementConnection then
        pcall(function()
            movementConnection:Disconnect()
        end)
        movementConnection = nil
    end

    restoreNaoyaVisibility()
end

local function Cleanup()
    Alive = false
    Runtime.Ready = false
    characterGeneration += 1
    table.clear(ratioMarkers)
    stopMovementSystem()
    clearCharacterConnections()
    if fovDrawing then
        pcall(function() fovDrawing:Remove() end)
        fovDrawing = nil
    end

    for _, conn in ipairs(Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Connections)

    pcall(function()
        if Highlight then
            Highlight:Destroy()
        end
    end)
    Highlight = nil

    pcall(function()
        local old = PlayerGui:FindFirstChild("GameSenseHUD")
        if old then
            old:Destroy()
        end
    end)

    if _G.RyuJJS_API then
        _G.RyuJJS_API = nil
    end
    _G[SCRIPT_ID] = nil
end


Runtime.Cleanup = Cleanup

local function movementStillValid(myRoot, targetRoot)
    return movementState ~= "IDLE"
        and myRoot
        and myRoot.Parent
        and targetRoot
        and targetRoot.Parent
        and getLockedTargetRoot() == targetRoot
end

--==============================================================
-- HUD
--==============================================================
local function createHUD()
    if not Alive then
        return
    end
    pcall(function()
        local old = PlayerGui:FindFirstChild("GameSenseHUD")
        if old then
            old:Destroy()
        end
    end)

    GUI = Instance.new("ScreenGui")
    GUI.Name = "GameSenseHUD"
    GUI.ResetOnSpawn = false
    GUI.IgnoreGuiInset = true
    GUI.Parent = PlayerGui

    Status = Instance.new("TextLabel")
    Status.Name = "Status"
    Status.Size = UDim2.new(0, 560, 0, 48)
    Status.Position = UDim2.new(0.5, -280, 0.84, 0)
    Status.BackgroundTransparency = 1
    Status.TextSize = 27
    Status.Font = Enum.Font.SourceSansBold
    Status.TextColor3 = Color3.new(1, 1, 1)
    Status.TextStrokeTransparency = 0.45
    Status.Text = "On Standby"
    Status.Parent = GUI

    Credits = Status:Clone()
    Credits.Name = "Credits"
    Credits.TextSize = 14
    Credits.Text = "RyuJJS • focused JJS build"
    Credits.Position = UDim2.new(0.5, -280, 0.84, -26)
    Credits.Parent = GUI
end

Runtime.Stage = "HUD creation"
createHUD()

track(connect(PlayerGui.ChildRemoved, "HUD removal", function(child)
    if Alive and child == GUI and _G[SCRIPT_ID] then
        defer("HUD rebuild", createHUD)
    end
end))

--==============================================================
-- HIGHLIGHT
--==============================================================
local function updateHighlight()
    if not Highlight then
        Highlight = Instance.new("Highlight")
        Highlight.Name = "RyuTargetHighlight"
        Highlight.FillTransparency = 1
        Highlight.OutlineColor = HighlightColor
        Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end

    if isActive and lockedTarget and lockedTarget.Parent then
        Highlight.Adornee = lockedTarget
        Highlight.Parent = workspace
    else
        Highlight.Adornee = nil
        Highlight.Parent = nil
    end
end

--==============================================================
-- TARGET ENUMERATION / SCREEN-CENTER TARGETING
--==============================================================
local function getCharactersFolder()
    if LocalPlayer.Character and LocalPlayer.Character.Parent and LocalPlayer.Character.Parent ~= workspace then
        return LocalPlayer.Character.Parent
    end
    return workspace:FindFirstChild("Characters") or workspace
end

local function collectTargets()
    local result = {}
    local seen = {}

    local function add(container)
        if not container then
            return
        end

        for _, obj in container:GetChildren() do
            if obj:IsA("Model") and not seen[obj] then
                seen[obj] = true
                local hum = getHumanoid(obj)
                local root = getRoot(obj)
                if hum and root then
                    table.insert(result, obj)
                end
            end
        end
    end

    add(getCharactersFolder())
    if getCharactersFolder() ~= workspace then
        add(workspace)
    end

    return result
end

local function findTargetByName(name)
    if not name then
        return nil
    end

    for _, obj in collectTargets() do
        if obj.Name == name then
            return obj
        end
    end
    return nil
end

local function isVisibleFromCamera(part, character)
    if not TARGET_REQUIRE_VISIBLE then
        return true
    end

    local origin = Camera.CFrame.Position
    local delta = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    params.IgnoreWater = true

    local hit = workspace:Raycast(origin, delta, params)
    if not hit then
        return true
    end

    return hit.Instance:IsDescendantOf(character)
end

local function findScreenCenterTarget()
    Camera = workspace.CurrentCamera or Camera

    if not Camera then
        return nil
    end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local myRoot = getRoot(LocalPlayer.Character)
    local closest = nil
    local bestScreenDist = math.huge

    for _, obj in collectTargets() do
        if obj == LocalPlayer.Character then
            continue
        end

        local hum = getHumanoid(obj)
        local part = getAimPart(obj)
        local root = getRoot(obj)

        if not hum or hum.Health <= 0 or not part or not root then
            continue
        end

        if myRoot and TARGET_MAX_DISTANCE < math.huge then
            if (root.Position - myRoot.Position).Magnitude > TARGET_MAX_DISTANCE then
                continue
            end
        end

        local screen, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen or screen.Z <= 0 then
            continue
        end

        local screenDist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
        if screenDist > TARGET_FOV_PIXELS then
            continue
        end

        if not isVisibleFromCamera(part, obj) then
            continue
        end

        if screenDist < bestScreenDist then
            bestScreenDist = screenDist
            closest = obj
        end
    end

    return closest
end

--==============================================================
-- TARGET LOCK / VALIDATION
--==============================================================
local function clearTarget()
    stopMovementSystem()
    isActive = false
    lockedTarget = nil
    lockedPlayer = nil
    lockedName = nil
    updateHighlight()
end

local function lockTarget(candidate)
    if typeof(candidate) ~= "Instance" or not candidate:IsA("Model") then
        return false
    end

    lockedTarget = candidate
    lockedPlayer = Players:GetPlayerFromCharacter(candidate)
    if lockedPlayer then
        lockedName = nil
    else
        lockedName = candidate.Name
    end
    isActive = true
    updateHighlight()
    return true
end

local function validateLockedTarget()
    if not isActive then
        return
    end

    if lockedPlayer then
        local stillPresent = Players:GetPlayerByUserId(lockedPlayer.UserId)
        if stillPresent ~= lockedPlayer then
            clearTarget()
            return
        end

        local char = lockedPlayer.Character
        local hum = getHumanoid(char)
        if char and char.Parent and hum then
            if lockedTarget ~= char then
                stopMovementSystem()
                lockedTarget = char
            end
        else
            stopMovementSystem()
            lockedTarget = nil
        end
        return
    end

    -- Match upstream: keep a dead NPC lock; replace by name only once its model is gone.
    if not lockedTarget or not lockedTarget.Parent then
        stopMovementSystem()
        if lockedName then
            local replacement = findTargetByName(lockedName)
            if replacement and getHumanoid(replacement) then
                lockedTarget = replacement
                return
            end
        end
        clearTarget()
        return
    end

    local hum = getHumanoid(lockedTarget)
    if not hum or hum.Health <= 0 then
        stopMovementSystem()
    end
end

--==============================================================
-- CAMERA / STARE TRACKING
--==============================================================
local function stareTracking()
    if not isActive or currentMode ~= "stare" or movementState ~= "IDLE" then
        return
    end

    local myRoot = getRoot(LocalPlayer.Character)
    local targetRoot = getLockedTargetRoot()
    if not myRoot or not targetRoot then
        return
    end

    local targetPos = targetRoot.Position
    local lookAt = LockY
        and targetPos
        or Vector3.new(targetPos.X, myRoot.Position.Y, targetPos.Z)

    local targetCF = CFrame.lookAt(myRoot.Position, lookAt)
    if SmoothAim then
        myRoot.CFrame = myRoot.CFrame:Lerp(targetCF, Sensitivity)
    else
        myRoot.CFrame = targetCF
    end
end

local function aimTracking()
    if not isActive or currentMode ~= "aim" then
        return
    end

    local targetPart = getAimPart(lockedTarget)
    if not targetPart then
        return
    end

    Camera = workspace.CurrentCamera or Camera

    local targetPos = targetPart.Position + Camera.CFrame.RightVector * AimHorizontalOffset
    local camPos = Camera.CFrame.Position
    local finalCF

    if LockY then
        local currentLook = Camera.CFrame.LookVector
        local currentPitch = math.asin(math.clamp(currentLook.Y, -1, 1))
        local toTarget = targetPos - camPos
        local targetYaw = math.atan2(toTarget.X, toTarget.Z)

        local newLook = Vector3.new(
            math.sin(targetYaw) * math.cos(currentPitch),
            math.sin(currentPitch),
            math.cos(targetYaw) * math.cos(currentPitch)
        ).Unit

        finalCF = CFrame.new(camPos, camPos + newLook)
    else
        finalCF = CFrame.new(camPos, targetPos)
    end

    if SmoothAim then
        Camera.CFrame = Camera.CFrame:Lerp(finalCF, Sensitivity)
    else
        Camera.CFrame = finalCF
    end
end

--==============================================================
-- X: INSTANT BEHIND-TARGET CFRAME TELEPORT
--==============================================================
local function faceTarget(position, targetPosition, lookUpDegrees)
    local lookVector = targetPosition - position
    if lookVector.Magnitude < 1e-4 then
        lookVector = Vector3.new(0, 0, -1)
    end

    local result = CFrame.lookAt(position, position + lookVector)
    if lookUpDegrees and lookUpDegrees ~= 0 then
        result *= CFrame.Angles(math.rad(lookUpDegrees), 0, 0)
    end
    return result
end

local function quickTeleportCFrame(targetRoot)
    Camera = workspace.CurrentCamera or Camera

    local targetPosition = targetRoot.Position
    local targetForward = flatUnit(
        targetRoot.CFrame.LookVector,
        Camera and Camera.CFrame.LookVector
    )

    -- Target LookVector points forward, so subtracting it lands directly at
    -- the target's back. Flattening avoids tilted/ragdolled target roots.
    local destination = targetPosition - targetForward * QUICK_BACK_DISTANCE

    return faceTarget(destination, targetPosition, QUICK_LOOK_UP_DEGREES)
end

local function startQuickTeleport()
    stopMovementSystem()

    local myRoot = getRoot(LocalPlayer.Character)
    local targetRoot = getLockedTargetRoot()
    if not myRoot or not targetRoot then
        return false
    end

    -- One direct CFrame write: no timer, physics override, or follow-up writer.
    myRoot.CFrame = quickTeleportCFrame(targetRoot)

    return true
end

--==============================================================
-- VERIFIED NAOYA CLIENT FLICK EFFECTS
--==============================================================
local function emitNaoyaHitGlow(character)
    pcall(function()
        local utils = ReplicatedStorage:FindFirstChild("Utils")
        local damage = utils and utils:FindFirstChild("Damage")
        local template = damage and damage:FindFirstChild("HitGlow")
        if not template then
            return
        end

        local glow = template:Clone()
        glow.Parent = workspace:FindFirstChild("Effects") or workspace
        Debris:AddItem(glow, 1.2)

        local tweenInfo = TweenInfo.new(1.2)
        local root = getRoot(character)
        local travel = root and root.CFrame.LookVector * 4 or Vector3.zero

        for _, part in glow:GetChildren() do
            local bodyPart = character:FindFirstChild(part.Name)
            if part:IsA("BasePart") and bodyPart and bodyPart:IsA("BasePart") then
                part.Color = Color3.fromRGB(128, 126, 255)
                part.Anchored = true
                part.CFrame = bodyPart.CFrame
                TweenService:Create(part, tweenInfo, {
                    Transparency = 1,
                    Position = part.Position + travel,
                }):Play()
            end
        end
    end)
end

local function hideNaoyaCharacter(character)
    restoreNaoyaVisibility()
    if not character or not character.Parent then
        return
    end
    for _, obj in character:GetDescendants() do
        if (obj:IsA("BasePart") or obj:IsA("Decal")) and obj.Transparency ~= 1 then
            naoyaHiddenOriginals[obj] = obj.Transparency
            obj.Transparency = 1
        end
    end
end

local function playNaoyaSound(root, soundName)
    pcall(function()
        local sounds = ReplicatedStorage:FindFirstChild("Sounds")
        local naoya = sounds and sounds:FindFirstChild("Naoya")
        local decisive = naoya and naoya:FindFirstChild("Decisive")
        local template = decisive and decisive:FindFirstChild(soundName)
        if not template or not template:IsA("Sound") then
            return
        end

        local sound = template:Clone()
        sound.Parent = root
        sound:Play()
        Debris:AddItem(sound, 3)
    end)
end

local function emitNaoyaFlick(root, flickIndex)
    pcall(function()
        local utils = ReplicatedStorage:FindFirstChild("Utils")
        local naoya = utils and utils:FindFirstChild("Naoya")
        local template = naoya and naoya:FindFirstChild("Teleport")
        if template then
            local effect = template:Clone()
            if effect:IsA("Model") then
                effect:PivotTo(root.CFrame)
            elseif effect:IsA("BasePart") then
                effect.CFrame = root.CFrame
            end

            effect.Parent = workspace:FindFirstChild("Effects") or workspace
            local lines = effect:FindFirstChild("Lines", true)
            local dust = effect:FindFirstChild("Dust", true)
            if lines and lines:IsA("ParticleEmitter") then
                lines:Emit(8)
            end
            if dust and dust:IsA("ParticleEmitter") then
                dust:Emit(30)
            end
            Debris:AddItem(effect, 1)
        end
    end)

    -- Saved DecisiveStrikeController cadence: silent first beat, then Flicker1/2.
    if flickIndex == 2 then
        playNaoyaSound(root, "Flicker1")
    elseif flickIndex == 3 then
        playNaoyaSound(root, "Flicker2")
    end
end

--==============================================================
-- Z: NAOYA-STYLE AERIAL CFRAME DASH
--==============================================================
local function startNaoyaAirDash()
    -- Z is a true toggle for this one movement only: pressing it again while
    -- the dash is active halts immediately and restores its temporary visuals.
    if movementState == "NAOYA_AIR" then
        stopMovementSystem()
        return true, "stopped"
    end

    stopMovementSystem()

    local myCharacter = LocalPlayer.Character
    local myRoot = getRoot(myCharacter)
    local targetRoot = getLockedTargetRoot()
    if not myRoot or not targetRoot then
        return false
    end

    Camera = workspace.CurrentCamera or Camera
    movementState = "NAOYA_AIR"

    local started = os.clock()
    local startPosition = myRoot.Position
    local startForward = flatUnit(
        myRoot.CFrame.LookVector,
        Camera and Camera.CFrame.LookVector
    )
    local startDistance = (targetRoot.Position - startPosition).Magnitude
    local startDriftDistance = math.clamp(
        startDistance * 0.4,
        NAOYA_START_DRIFT_MIN,
        NAOYA_START_DRIFT_MAX
    )
    local startControlPosition = startPosition + startForward * startDriftDistance
    local weaveRight = flatUnit(
        myRoot.CFrame.RightVector,
        Camera and Camera.CFrame.RightVector
    )
    local previousPosition = startPosition
    local nextFlick = 1
    local hidden = true

    playNaoyaSound(myRoot, "Startup")
    emitNaoyaHitGlow(myCharacter)
    hideNaoyaCharacter(myCharacter)

    movementConnection = connect(RunService.PreSimulation, "Naoya movement", function()
        if not movementStillValid(myRoot, targetRoot) then
            stopMovementSystem()
            return
        end

        local elapsed = os.clock() - started
        local progress = math.clamp(elapsed / NAOYA_AIR_DURATION, 0, 1)
        -- Saved controller sequence for each of three cycles:
        -- hide 0.10 s -> restore + glow + flick -> recover 0.10 s.
        local advanced = true
        while advanced and nextFlick <= NAOYA_FLICK_COUNT do
            advanced = false

            local cycleStart = (nextFlick - 1) * NAOYA_FLICK_CYCLE
            local flickAt = cycleStart + NAOYA_HIDE_TIME

            if hidden and elapsed >= flickAt then
                restoreNaoyaVisibility()
                emitNaoyaHitGlow(myCharacter)
                emitNaoyaFlick(myRoot, nextFlick)
                hidden = false
                nextFlick += 1
                advanced = true
            elseif not hidden and nextFlick <= NAOYA_FLICK_COUNT then
                local nextCycleStart = (nextFlick - 1) * NAOYA_FLICK_CYCLE
                if elapsed >= nextCycleStart then
                    emitNaoyaHitGlow(myCharacter)
                    hideNaoyaCharacter(myCharacter)
                    hidden = true
                    advanced = true
                end
            end
        end

        local targetPosition = targetRoot.Position
            + targetRoot.AssemblyLinearVelocity * NAOYA_TARGET_LEAD
        local targetForward = flatUnit(targetRoot.CFrame.LookVector, startForward)
        local targetBack = -targetForward
        local finalPosition = targetPosition + targetBack * NAOYA_STOP_DISTANCE
        local rearControlPosition = finalPosition
            + targetBack * NAOYA_REAR_ENTRY_DISTANCE

        -- Cubic Bezier: the first tangent is the exact direction the local
        -- character faced when Z began. The latter half bends toward a point
        -- farther behind the target, then settles at the target's back.
        local inverse = 1 - progress
        local position = startPosition * (inverse ^ 3)
            + startControlPosition * (3 * inverse ^ 2 * progress)
            + rearControlPosition * (3 * inverse * progress ^ 2)
            + finalPosition * (progress ^ 3)

        -- Squared envelope has zero slope at both ends, preserving the exact
        -- facing-led start and the exact behind-target finish.
        local envelope = math.sin(progress * math.pi) ^ 2
        local arc = envelope * NAOYA_ARC_HEIGHT
        local weave = math.sin(progress * math.pi * 3)
            * envelope
            * NAOYA_WEAVE_WIDTH
        position += Vector3.new(0, arc, 0) + weaveRight * weave

        local travelDirection = position - previousPosition
        if travelDirection.Magnitude < 1e-4 then
            travelDirection = startForward
        end

        -- Face along the curve: Z visibly begins in the player's original
        -- facing direction and naturally turns as it drifts around the rear.
        myRoot.CFrame = CFrame.lookAt(position, position + travelDirection)
        previousPosition = position

        if progress >= 1 then
            -- Final CFrame write occurs before cleanup disconnects this writer.
            myRoot.CFrame = faceTarget(finalPosition, targetPosition, 0)
            stopMovementSystem()
        end
    end)

    return true
end

--==============================================================
-- INPUT EMULATION
--==============================================================
local function pressKey(keyCode)
    if not Alive or virtualInputUnavailable then
        return false
    end
    if not VirtualInputManager then
        local ok, service = Runtime:Run("input service", function()
            return game:GetService("VirtualInputManager")
        end)
        if not ok or not service then
            virtualInputUnavailable = true
            return false
        end
        VirtualInputManager = service
    end

    local down = Runtime:Run("key down", function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    end)
    -- Attempt release even after a failed press, in case the bridge sent the
    -- key before throwing. Never leave a successful key-down unreleased.
    local up = Runtime:Run("key up", function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
    if not down or not up then
        virtualInputUnavailable = true
    end
    return down and up
end

local function getGlobalFunction(name)
    local env = (getfenv and getfenv()) or _G
    return rawget(env, name) or rawget(_G, name)
end

local function saveConfig()
    local write = getGlobalFunction("writefile")
    if typeof(write) ~= "function" then
        return false, "writefile unavailable"
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode({Autos = Autos})
    end)
    if not ok then
        return false, encoded
    end

    return pcall(write, CONFIG_FILE, encoded)
end

local function loadConfig()
    local read = getGlobalFunction("readfile")
    local exists = getGlobalFunction("isfile")
    if typeof(read) ~= "function" then
        return false
    end
    if typeof(exists) == "function" then
        local okExists, doesExist = pcall(exists, CONFIG_FILE)
        if not okExists or not doesExist then
            return false
        end
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(read(CONFIG_FILE))
    end)
    if not ok or type(decoded) ~= "table" then
        return false
    end

    if type(decoded.Autos) == "table" then
        for k, v in pairs(decoded.Autos) do
            if Autos[k] ~= nil and type(v) == "boolean" then
                Autos[k] = v
            end
        end
    end
    return true
end

Runtime.Stage = "configuration"
loadConfig()

--==============================================================
-- BLACK FLASH / TODO WRAPPERS
--==============================================================
local function isCurrentCharacter(char, generation)
    local hum = getHumanoid(char)
    return Alive
        and char ~= nil
        and characterGeneration == generation
        and LocalPlayer.Character == char
        and char.Parent ~= nil
        and hum ~= nil
        and hum.Health > 0
end

local function blackflashgojo()
    JJS:Use("ReversalRedMax", "false")
    JJS:Use("GojoRight")
end

local function blackflashsmg()
    JJS:Use("FocusStrike", "false")
end

local function blackflash()
    JJS:Use("DivergentFist", "false")
end

local function blueflash()
    JJS:Use("DivergentFist", "true")
end

local function runTwice(fn, fallback)
    local char = LocalPlayer.Character
    local generation = characterGeneration
    spawn("Black Flash sequence", function()
        if not isCurrentCharacter(char, generation) then
            return
        end
        local ok = pcall(function()
            fn()
            task.wait(0.32)
            if isCurrentCharacter(char, generation) then
                fn()
            end
        end)
        if not ok and fallback and isCurrentCharacter(char, generation) then
            pcall(fallback)
        end
    end)
end

local function run_blackflashgojo()
    runTwice(blackflashgojo, blueflash)
end

local function run_blackflash()
    runTwice(blackflash, blueflash)
end

local function run_blackflashsmg()
    runTwice(blackflashsmg, blueflash)
end

local function pressMouse1()
    JJS:Use("Todo", false)
end

local function pollForSwapAudio(char, generation)
    local started = os.clock()
    local conn

    conn = connect(RunService.Heartbeat, "Todo audio observer", function()
        if not Autos.TodoSwap or not isCurrentCharacter(char, generation)
            or os.clock() - started > 2 then
            conn:Disconnect()
            return
        end

        for _, obj in char:GetDescendants() do
            if obj:IsA("Sound")
                and obj.SoundId == swapAudioId
                and obj.IsPlaying
                and obj.Volume > 0
            then
                pressMouse1()
                conn:Disconnect()
                return
            end
        end
    end)

    trackCharacter(conn)
end

--==============================================================
-- NANAMI RATIO POINT: ONLY THE REAL SERVER-ISSUED TIMING WINDOW
--==============================================================
-- Source: NanamiController.SpawnRatio(owner, target, gui, resolved, duration, startedAt).
-- Cursor.Y = 1 - normalized server time. Its success placement is Y = 0.3, giving
-- normalized time 0.7. This is the visual center, not a recovered server hit tolerance.
local RATIO_POINT_TIMING = 0.7

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function hasNativeRatioRoute(char)
    if char:GetAttribute("Moveset") ~= "Nanami" then
        return false
    end
    local info = char:FindFirstChild("Info")
    local item = info and info:FindFirstChild("Item")
    local custom = char:FindFirstChild("CustomChar")
    -- Match ToolController.Special's precedence; do not bypass an item/custom Special.
    return not (item and item:FindFirstChild("M2"))
        and not (custom and custom:GetAttribute("CustomSpecial"))
end

local function queueRatioPoint(owner, target, gui, resolved, duration, startedAt)
    local char = LocalPlayer.Character
    local generation = characterGeneration
    if owner ~= LocalPlayer or not isCurrentCharacter(char, generation)
        or not hasNativeRatioRoute(char) then
        return false
    end
    if typeof(target) ~= "Instance" or not target:IsA("Model")
        or typeof(gui) ~= "Instance" or not gui:IsA("BillboardGui")
        or typeof(resolved) ~= "Instance" or not resolved:IsA("BoolValue")
        or not finiteNumber(duration) or duration <= 0 or not finiteNumber(startedAt) then
        return false
    end
    if ratioMarkers[resolved] then
        return false
    end

    local due = startedAt + duration * RATIO_POINT_TIMING
    local expires = startedAt + duration
    local now = workspace:GetServerTimeNow()
    if not finiteNumber(due) or not finiteNumber(expires) or now >= expires then
        return false
    end
    ratioMarkers[resolved] = true -- one attempt per actual prompt, including duplicate events

    delay(math.max(0, due - now), "Ratio Point timing", function()
        if not isCurrentCharacter(char, generation)
            or not hasNativeRatioRoute(char)
            or not target.Parent or not gui.Parent or not resolved.Parent
            or resolved.Value == true then
            return
        end
        local targetHum = getHumanoid(target)
        if not targetHum or targetHum.Health <= 0 then
            return
        end
        if isActive and lockedTarget ~= target then
            return -- never act on a different target while the manual lock is active
        end
        local serverNow = workspace:GetServerTimeNow()
        if serverNow < due or serverNow >= expires then
            return -- a stale/expired prompt must never turn into an idle Special
        end
        -- ToolController.Special's normal branch passes the actual target to RightActivated.
        -- Nanami has no RightDeactivated endpoint in this place.
        JJS:Fire("NanamiService", "RightActivated", target)
    end)
    return true
end

local function setupRatioPointObserver()
    local attached = setmetatable({}, {__mode = "k"})
    local function attach(remote)
        if not Alive or typeof(remote) ~= "Instance" or attached[remote] or not remote:IsA("RemoteEvent")
            or remote.Name ~= "Effects" or remote ~= JJS:GetRemote("NanamiService", "Effects") then
            return
        end
        attached[remote] = true
        track(connect(remote.OnClientEvent, "Nanami effects", function(effect, ...)
            if Alive and effect == "SpawnRatio" then
                queueRatioPoint(...)
            end
        end))
    end
    -- Observe arrivals before checking the current tree, without a recurring discovery loop.
    track(connect(ReplicatedStorage.DescendantAdded, "Ratio remote discovery", attach))
    local remote = JJS:GetRemote("NanamiService", "Effects")
    if remote then
        attach(remote)
    end
end

Runtime.Stage = "Ratio observer"
setupRatioPointObserver()

--==============================================================
-- JJS ANIMATION HOOKS
--==============================================================
local function setupJJS(char)
    if not Alive or char ~= LocalPlayer.Character then
        return
    end
    characterGeneration += 1
    local generation = characterGeneration
    clearCharacterConnections()
    table.clear(ratioMarkers)

    local hum = char:WaitForChild("Humanoid", 5)
    local animator = hum and hum:WaitForChild("Animator", 5)
    if not hum or not animator or not isCurrentCharacter(char, generation) then
        return
    end

    local AnimationTriggers = {
        ["rbxassetid://100962226150441"] = 0.18,
        ["rbxassetid://95852624447551"] = 0.18,
        ["rbxassetid://74145636023952"] = 0.18,
        ["rbxassetid://123171106092050"] = 0.18,
        ["rbxassetid://72475960800126"] = 0.20,
    }

    local todo1 = "rbxassetid://100081544058065"
    local todo2 = "rbxassetid://123167492985370"

    local swapAnims = {
        ["rbxassetid://116040503139675"] = true,
        ["rbxassetid://91074768993486"] = true,
        ["rbxassetid://131358603583212"] = true,
    }

    trackCharacter(connect(animator.AnimationPlayed, "animation played", function(track)
        if not isCurrentCharacter(char, generation) then
            return
        end
        local animation = track.Animation
        local animId = animation and animation.AnimationId or ""

        local delayTime = AnimationTriggers[animId]
        if delayTime and Autos.BlackFlash then
            delay(delayTime, "Black Flash input", function()
                if Autos.BlackFlash and isCurrentCharacter(char, generation) then
                    pressKey(Enum.KeyCode.Three)
                end
            end)
        end

        if animId == todo1 and Autos.TodoSwap then
            delay(0.3, "Todo first input", function()
                if Autos.TodoSwap and isCurrentCharacter(char, generation) then
                    pressKey(Enum.KeyCode.Two)
                end
            end)
        elseif animId == todo2 and Autos.TodoSwap then
            delay(0.6, "Todo second input", function()
                if Autos.TodoSwap and isCurrentCharacter(char, generation) then
                    pressKey(Enum.KeyCode.Two)
                end
            end)
        end

        if Autos.TodoSwap and swapAnims[animId] then
            local len = 1
            local targetHum = getHumanoid(lockedTarget)
            if targetHum and targetHum.PlatformStand then
                len = 0.2
            end

            delay(len / 2, "Todo swap", function()
                if Autos.TodoSwap and isCurrentCharacter(char, generation) then
                    pressMouse1()
                end
            end)

            pollForSwapAudio(char, generation)
        end
    end))
end

--==============================================================
-- FEATURE CONTROL
--==============================================================
local function setFeature(name, enabled)
    if Autos[name] == nil then
        return false, "unknown feature"
    end
    Autos[name] = enabled == true
    return true
end

local function toggleFeature(name)
    if Autos[name] == nil then
        return false
    end
    setFeature(name, not Autos[name])
    return Autos[name]
end

-- Optional Drawing FOV circle.
pcall(function()
    local DrawingAPI = rawget((getfenv and getfenv()) or _G, "Drawing") or rawget(_G, "Drawing")
    if DrawingAPI and typeof(DrawingAPI.new) == "function" then
        fovDrawing = DrawingAPI.new("Circle")
        fovDrawing.Filled = false
        fovDrawing.Thickness = 1
        fovDrawing.Transparency = 0.8
        fovDrawing.NumSides = 64
    end
end)

local function updateFOVDrawing()
    if not fovDrawing then
        return
    end
    Camera = workspace.CurrentCamera or Camera
    if not Camera then
        fovDrawing.Visible = false
        return
    end
    fovDrawing.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovDrawing.Radius = TARGET_FOV_PIXELS < math.huge and TARGET_FOV_PIXELS or 0
    fovDrawing.Visible = Autos.ShowFOV and TARGET_FOV_PIXELS < math.huge
end

--==============================================================
-- STATUS / MAIN HEARTBEAT
--==============================================================
Runtime.Stage = "frame callbacks"
track(connect(RunService.Heartbeat, "target status", function()
    if not Alive then
        return
    end
    validateLockedTarget()
    updateHighlight()

    local statusText = "On Standby"
    local color = Color3.fromHSV((tick() % 5) / 5, 0.7, 1)

    if isActive then
        if lockedTarget then
            if movementState == "NAOYA_AIR" then
                statusText = "💨 Naoya air flick @ " .. lockedTarget.Name
                color = Color3.fromRGB(110, 255, 150)
            else
                statusText = (currentMode == "aim" and "🎯 Aiming" or "👁️ Staring")
                    .. " @ " .. lockedTarget.Name
                color = currentMode == "aim"
                    and Color3.fromRGB(80, 180, 255)
                    or Color3.fromRGB(255, 140, 60)
            end
        elseif lockedPlayer then
            statusText = "⏳ Waiting for " .. lockedPlayer.Name .. " respawn"
        end
    end

    if Status then
        Status.Text = statusText
        Status.TextColor3 = color
    end
end))

--==============================================================
-- AIM / STARE LOOP
--==============================================================
track(connect(RunService.RenderStepped, "camera tracking", function()
    if not Alive then
        return
    end
    updateFOVDrawing()

    if not isActive then
        return
    end

    if currentMode == "aim" then
        aimTracking()
    elseif currentMode == "stare" then
        stareTracking()
    end
end))

--==============================================================
-- INPUT
--==============================================================
Runtime.Stage = "input callbacks"
track(connect(UserInputService.InputBegan, "keyboard input", function(input, gpe)
    if gpe or not Alive then
        return
    end

    if input.KeyCode == ToggleKey then
        if not isActive then
            lockTarget(findScreenCenterTarget())
        else
            clearTarget()
        end
        return
    end

    if input.KeyCode == ModeCycleKey then
        currentMode = currentMode == "stare" and "aim" or "stare"
        return
    end

    if input.KeyCode == LockYKey then
        LockY = not LockY
        return
    end

    if input.KeyCode == QuickTeleportKey and lockedTarget then
        startQuickTeleport()
        return
    end

    if input.KeyCode == NaoyaAirKey then
        if movementState == "NAOYA_AIR" or lockedTarget then
            startNaoyaAirDash()
        end
        return
    end
end))

--==============================================================
-- CHARACTER RESET
--==============================================================
Runtime.Stage = "character callbacks"
track(connect(LocalPlayer.CharacterAdded, "character added", function(char)
    stopMovementSystem()
    setupJJS(char)
end))

track(connect(LocalPlayer.CharacterRemoving, "character removing", function()
    characterGeneration += 1
    stopMovementSystem()
    clearCharacterConnections()
    table.clear(ratioMarkers)
end))

if LocalPlayer.Character then
    spawn("current character", setupJJS, LocalPlayer.Character)
end

--==============================================================
-- OPTIONAL GLOBAL API FOR MANUAL TESTING / EXTENSIONS
--==============================================================
_G.RyuJJS_API = {
    JJS = JJS,
    Autos = Autos,
    GetTarget = function()
        return lockedTarget
    end,
    LockClosest = function()
        return lockTarget(findScreenCenterTarget())
    end,
    Unlock = clearTarget,
    QuickTeleport = startQuickTeleport,
    NaoyaAirDash = startNaoyaAirDash,
    MovementState = function() return movementState end,
    StopMovement = stopMovementSystem,
    SetFeature = setFeature,
    ToggleFeature = toggleFeature,
    SaveConfig = saveConfig,
    LoadConfig = loadConfig,
    Diagnostics = function() return Runtime:Report() end,
    RetryInput = function()
        virtualInputUnavailable = false
        VirtualInputManager = nil
    end,
    BlackFlash = run_blackflash,
    BlackFlashGojo = run_blackflashgojo,
    BlackFlashSMG = run_blackflashsmg,
    BlueFlash = blueflash,
}

--==============================================================
-- PUBLISH CLEANUP
--==============================================================

_G[SCRIPT_ID] = Cleanup
Runtime.Stage = "ready"
Runtime.Ready = true
print("[RyuJJS] ready")

--==============================================================
-- STARTUP NOTIFICATION
--==============================================================
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "RyuJJS",
        Text = "C lock • M stare/aim • V pitch\n"
.. "X instant rear CFrame\n"
            .. "Z facing-led rear drift • press Z again to halt\n"
            .. "C is the only control that selects a different target.",
        Duration = 8,
    })
end)

end

local ok = Runtime:Run("startup", start)
if not ok then
    Runtime.Failed = true
    if Runtime.Cleanup then
        Runtime:Run("partial startup cleanup", Runtime.Cleanup)
    end
    warn("[RyuJJS] startup stopped at " .. Runtime.Stage
        .. "; see the labelled trace above")
end
