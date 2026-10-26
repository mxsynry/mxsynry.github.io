-- RyuJJS runtime diagnostics. Run this readable file directly.
-- An error reported before "bootstrap entered" occurs outside this script body.
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
      RightShift / controls button = combat settings

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
      - Beam clashes respond only through a server-issued ClashQTE remote.
      - Reactive block recognises basic M1 animations from the live animation folder.
        Special attacks and counters are not assigned guessed block/parry timings.
      - Mouse assist keeps C's locked target in the game's shared mouse-dependent
        target, skill-aim and swap routes. Chase assist supplies that target specifically
        to MovementController.DashRequest; the game still decides when extra dashes apply.
      - Mouse assist and chase assist have separate toggles and are enabled by default.
      - Native targeting, chase and sphere-hitbox edits restore their previous methods on unload.
        Extended hitboxes are experimental; successful server damage is not guaranteed.
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
    AutoRatio = true,
    AutoBeam = true,
    PredictiveAim = true,
    MouseAssist = true,
    ChaseAssist = true,
    TodoSmart = true,
    AutoBlock = false,
    FollowUp = false,
    TargetInfo = true,
    ExtendedHitbox = false,
}

local Options = {
    AimLead = 0.08,
    HitboxScale = 1.5,
    BlockRange = 12,
    BlockHold = 0.38,
    BeamInterval = 0.12,
    FollowUpSlot = 1,
    FollowUpRange = 12,
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
local Combat = {
    Actions = {}, Patches = {}, TargetConnections = {}, UIConnections = {},
    MouseContexts = setmetatable({}, {__mode = "k"}),
    Attached = setmetatable({}, {__mode = "k"}), Blockable = {}, AmbiguousAnimations = {},
    PanelOpen = false, NativeStatus = "Waiting for game controllers",
    NextWatch = 0, NextDiscovery = 0, NextFollowUp = 0, RatioEpoch = 0,
    Stats = {HitboxCandidates = 0, HitConfirms = 0, Blocks = 0, BeamResponses = 0, FollowUps = 0,
        ChaseSelections = 0, MouseSelections = 0, MouseAimPoints = 0, MouseSwapTargets = 0},
}

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
    if Combat.Destroy then Runtime:Run("combat cleanup", Combat.Destroy, Combat) end
    Runtime.Cleanup = nil
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
    if Combat.BuildPanel then Combat:BuildPanel() end
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
    if Combat.ReleaseBlock then Combat:ReleaseBlock() end
    if Combat.DisconnectList then Combat:DisconnectList(Combat.TargetConnections) end
    Combat.WatchedTarget, Combat.TargetAnimator, Combat.Threat, Combat.FollowUp = nil, nil, nil, nil
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

    local targetPos = (Combat.Predict and Combat:Predict(targetPart) or targetPart.Position)
        + Camera.CFrame.RightVector * AimHorizontalOffset
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
    local ok, env = pcall(function() return getfenv() end)
    if ok and type(env) == "table" then
        local resolved, value = pcall(function() return env[name] end)
        if resolved and type(value) == "function" then return value end
    end
    return rawget(_G, name)
end

local function saveConfig()
    local write = getGlobalFunction("writefile")
    if typeof(write) ~= "function" then
        return false, "writefile unavailable"
    end

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode({Autos = Autos, Options = Options})
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
                if Combat.SetFeature then Combat:SetFeature(k, v) else Autos[k] = v end
            end
        end
    end
    if type(decoded.Options) == "table" and Combat.SetOption then
        for key, value in pairs(decoded.Options) do Combat:SetOption(key, value) end
    end
    return true
end

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

local function pollForSwapAudio(char, generation, ticket)
    local started = os.clock()
    local conn

    conn = connect(RunService.Heartbeat, "Todo audio observer", function()
        if not Autos.TodoSwap or not isCurrentCharacter(char, generation)
            or (ticket and (ticket.Done or ticket.Track.IsPlaying ~= true))
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
                if ticket then Combat:Consume(ticket) else pressMouse1() end
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
    local ratioEpoch = Combat.RatioEpoch
    if not Autos.AutoRatio or owner ~= LocalPlayer or not isCurrentCharacter(char, generation)
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
        if not Autos.AutoRatio or Combat.RatioEpoch ~= ratioEpoch
            or not isCurrentCharacter(char, generation)
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
-- COMBAT HELPERS: CONTRACTS RECOVERED FROM THE ATTACHED CLIENT
--==============================================================
-- BeamController.ClashQTE receives a temporary remote and responds with a boolean.
-- HitboxController:SphereHitbox(character, offsetCFrame, diameter) returns Models.
-- Its native Hitbox event loop reports that list through a temporary remote.
-- Native server validation is absent from the dump. Extended hitboxes are
-- experimental and disabled by default; a local list edit is not a confirmed hit.

function Combat:HasState(character, name)
    if not character then return false end
    local value = character:GetAttribute(name)
    if type(value) == "boolean" then
        if value then return true end
    elseif type(value) == "number" then
        if value > 0 then return true end
    end
    local info = character:FindFirstChild("Info")
    local marker = info and info:FindFirstChild(name)
    if not marker then return false end
    if marker:IsA("BoolValue") then return marker.Value end
    if marker:IsA("NumberValue") or marker:IsA("IntValue") then return marker.Value > 0 end
    return true
end

function Combat:CanAct(character, allowSkill)
    local hum = getHumanoid(character)
    return Alive and character ~= nil and character == LocalPlayer.Character
        and character.Parent ~= nil and hum ~= nil and hum.Health > 0
        and not self:HasState(character, "Stun")
        and not self:HasState(character, "Ragdoll")
        and not self:HasState(character, "InDash")
        and (allowSkill or not self:HasState(character, "InSkill"))
end

function Combat:IsTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

function Combat:LockedWithin(distance)
    if not isActive or not lockedTarget or lockedTarget == LocalPlayer.Character
        or not lockedTarget.Parent then return nil end
    local hum, root = getHumanoid(lockedTarget), getRoot(lockedTarget)
    local ownRoot = getRoot(LocalPlayer.Character)
    if not hum or hum.Health <= 0 or not root or not ownRoot then return nil end
    if (root.Position - ownRoot.Position).Magnitude > distance then return nil end
    return lockedTarget, root, ownRoot
end

function Combat:ClearLine(character, position)
    local ownRoot = getRoot(LocalPlayer.Character)
    if not ownRoot then return false end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
    ray.IgnoreWater = true
    local hit = workspace:Raycast(ownRoot.Position, position - ownRoot.Position, ray)
    return not hit or hit.Instance:IsDescendantOf(character)
end

function Combat:Predict(part)
    if not Autos.PredictiveAim then return part.Position end
    local velocity = part.AssemblyLinearVelocity
    if typeof(velocity) ~= "Vector3" then return part.Position end
    local seconds = Options.AimLead
    if velocity.Magnitude > 160 then
        velocity = velocity.Unit * 160
    end
    return part.Position + velocity * seconds
end

function Combat:DisconnectList(list)
    for _, connection in ipairs(list) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(list)
end

function Combat:Patch(object, name, wrapperFactory)
    if type(object) ~= "table" or type(object[name]) ~= "function" then return false end
    for _, record in ipairs(self.Patches) do
        if record.Object == object and record.Name == name then return true end
    end
    local original = object[name]
    local wrapper = wrapperFactory(original)
    local ok = Runtime:Run("install " .. name, function() object[name] = wrapper end)
    if not ok then return false end
    table.insert(self.Patches, {Object = object, Name = name, Original = original, Wrapper = wrapper})
    return true
end

function Combat:RestorePatches()
    for i = #self.Patches, 1, -1 do
        local patch = self.Patches[i]
        if patch.Object[patch.Name] == patch.Wrapper then
            patch.Object[patch.Name] = patch.Original
        end
    end
    table.clear(self.Patches)
end

-- Shared mouse targeting routes recovered from the saved client:
--   MovementController.DashRequest -> ToolController:GetTarget(200)
--   Skills / specials / items      -> ToolController:GetTarget / GetMouseTarget
--   Todo character / object swap   -> ToolController:GetTargetOrProjectile
-- GetTarget's native per-moveset limit overwrites its argument in this dump.
-- The movement query must therefore retain that limit, not assume 200 studs.

function Combat:NativeTargetLimit()
    local char = LocalPlayer.Character
    local moveset = char and char:GetAttribute("Moveset")
    local ranges = {SuperTze = 1000, Haruta = 350, Mechamaru = 300, Chara = 60, Hanami = 300}
    return ranges[moveset] or 100
end

function Combat:MouseTargetWithin(distance)
    local char = LocalPlayer.Character
    local hum = getHumanoid(char)
    if not Alive or not hum or hum.Health <= 0 or not char.Parent or self:IsTyping() then return nil end
    local target, root = self:LockedWithin(distance)
    local camera = workspace.CurrentCamera
    if not target or not camera or target.Name == "HarutaSwordNPC"
        or not target:FindFirstChild("Info") or self:HasState(target, "UroDistort")
        or (root.Position - camera.CFrame.Position).Magnitude > distance then return nil end
    return target, root
end

function Combat:WithMouseRoute(route, original, ...)
    -- A DashRequest may yield or overlap another input callback. A single global
    -- 'currently dashing' flag would redirect unrelated calls in those threads.
    local token = coroutine.running() or self
    local previous = self.MouseContexts[token]
    self.MouseContexts[token] = {Route = route, Character = LocalPlayer.Character,
        Generation = characterGeneration}
    local results = table.pack(pcall(original, ...))
    self.MouseContexts[token] = previous
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end

function Combat:MouseRouteEnabled()
    local context = self.MouseContexts[coroutine.running() or self]
    if context and context.Route == "chase" then
        return Autos.ChaseAssist and context.Character == LocalPlayer.Character
            and context.Generation == characterGeneration, "chase"
    end
    return Autos.MouseAssist, "mouse"
end

function Combat:HasPatch(object, name)
    if type(object) ~= "table" then return false end
    for _, patch in ipairs(self.Patches) do
        if patch.Object == object and patch.Name == name and object[name] == patch.Wrapper then return true end
    end
    return false
end

function Combat:RefreshControllerStatus()
    local mouse = self:HasPatch(self.Tool, "GetTarget") and self:HasPatch(self.Tool, "GetMouseTarget")
        and self:HasPatch(self.Tool, "GetTargetOrProjectile")
    local chase = self:HasPatch(self.Movement, "DashRequest") and self:HasPatch(self.Tool, "GetTarget")
    local hitboxes = self:HasPatch(self.Hitbox, "SphereHitbox")
    self.NativeStatus = "Mouse: " .. (mouse and "ready" or "unavailable")
        .. " · Chase: " .. (chase and "ready" or "unavailable")
        .. " · Hitboxes: " .. (hitboxes and "ready" or "unavailable")
end

function Combat:InstallMouseControllers(tool, movement)
    self:Patch(tool, "GetTarget", function(original)
        return function(controller, ...)
            local enabled, route = self:MouseRouteEnabled()
            if Alive and enabled then
                local target = self:MouseTargetWithin(self:NativeTargetLimit())
                if target then
                    if route == "chase" then self.Stats.ChaseSelections += 1
                    else self.Stats.MouseSelections += 1 end
                    return target -- same Model contract used by the native fleeing check
                end
            end
            return original(controller, ...)
        end
    end)
    self:Patch(tool, "GetMouseTarget", function(original)
        return function(controller, range, ...)
            if Alive and Autos.MouseAssist then
                local char = LocalPlayer.Character
                local limit = char and char:GetAttribute("Moveset") == "Hanami" and 600 or range
                if not finiteNumber(limit) or limit <= 0 then limit = 300 end
                local target = self:MouseTargetWithin(limit)
                local part = target and getAimPart(target)
                local camera = workspace.CurrentCamera
                if part and camera then
                    local position = self:Predict(part)
                    local delta = position - camera.CFrame.Position
                    if delta.Magnitude > limit then
                        position = camera.CFrame.Position + delta.Unit * limit
                    end
                    if self:ClearLine(target, position) then
                        self.Stats.MouseAimPoints += 1
                        return position -- Vector3; native controllers keep their own raycasts / steering
                    end
                end
            end
            return original(controller, range, ...)
        end
    end)
    self:Patch(tool, "GetTargetOrProjectile", function(original)
        return function(controller, ...)
            local char = LocalPlayer.Character
            if Alive and char and (Autos.MouseAssist
                or Autos.TodoSmart and char:GetAttribute("Moveset") == "Todo") then
                local target = self:MouseTargetWithin(100)
                if target then
                    self.Stats.MouseSwapTargets += 1
                    return target -- native return is the selected root / projectile part's parent
                end
            end
            -- Retain native projectile / throwable selection when no character is locked.
            return original(controller, ...)
        end
    end)
    self:Patch(movement, "DashRequest", function(original)
        return function(controller, ...)
            if not Alive then return original(controller, ...) end
            -- Only supply the target. The original function retains DisableChase,
            -- ragdoll/stun, facing/velocity tests, dash direction, charges and timers.
            return self:WithMouseRoute("chase", original, controller, ...)
        end
    end)
end

function Combat:InstallControllers(tool, hitbox, movement)
    self.Tool, self.Hitbox, self.Movement = tool, hitbox, movement
    self:InstallMouseControllers(tool, movement)
    self:Patch(hitbox, "SphereHitbox", function(original)
        return function(controller, character, offset, diameter, ...)
            local results = original(controller, character, offset, diameter, ...)
            if not Alive or not Autos.ExtendedHitbox or character ~= LocalPlayer.Character
                or type(results) ~= "table" or not finiteNumber(diameter) or diameter <= 0
                or typeof(offset) ~= "CFrame" then return results end
            local target, root, ownRoot = self:LockedWithin(80)
            if not target or table.find(results, target) then return results end
            local radius = diameter * 0.5
            local extendedRadius = math.min(radius * Options.HitboxScale, radius + 12)
            local center = (ownRoot.CFrame * offset).Position
            if (root.Position - center).Magnitude > extendedRadius
                or not self:ClearLine(target, root.Position) then return results end
            local copy = table.clone(results)
            table.insert(copy, target)
            self.Stats.HitboxCandidates += 1
            return copy
        end
    end)
    self:RefreshControllerStatus()
end

function Combat:ResolveControllers()
    if self.Resolving or not Alive then return end
    self.Resolving = true
    spawn("game controller discovery", function()
        local completed = Runtime:Run("connect game controllers", function()
        local package = ReplicatedStorage:FindFirstChild("Knit")
        local module = package and package:FindFirstChild("Knit")
        if module and module:IsA("ModuleScript") then
            local ok, knit = pcall(require, module)
            if ok and type(knit) == "table" and type(knit.GetController) == "function" then
                local function resolve(name)
                    if type(knit.DoesControllerExist) == "function" and not knit.DoesControllerExist(name) then
                        return nil
                    end
                    local found, result = pcall(knit.GetController, name)
                    return found and result or nil
                end
                local tool, hitbox = resolve("ToolController"), resolve("HitboxController")
                local movement = resolve("MovementController")
                if Alive then self:InstallControllers(tool, hitbox, movement) end
            end
        end
        end)
        if not completed then self.NativeStatus = "Game controller connection failed; see diagnostics" end
        self.Resolving = false
    end)
end

function Combat:QueueAnimation(track, at, feature, callback)
    if not track or not finiteNumber(at) then return nil end
    local ticket = {
        Track = track, At = at, Feature = feature, Callback = callback,
        Character = LocalPlayer.Character, Generation = characterGeneration,
        Deadline = os.clock() + 4, Done = false,
    }
    table.insert(self.Actions, ticket)
    return ticket
end

function Combat:Consume(ticket)
    if not ticket or ticket.Done or not Autos[ticket.Feature]
        or not isCurrentCharacter(ticket.Character, ticket.Generation)
        or ticket.Track.IsPlaying ~= true or not self:CanAct(ticket.Character, true)
        or self:IsTyping() then return false end
    ticket.Done = true
    ticket.Callback()
    return true
end

function Combat:StepAnimations()
    for index = #self.Actions, 1, -1 do
        local ticket = self.Actions[index]
        if ticket.Done or not Autos[ticket.Feature]
            or not isCurrentCharacter(ticket.Character, ticket.Generation)
            or ticket.Track.IsPlaying ~= true or os.clock() > ticket.Deadline then
            table.remove(self.Actions, index)
        else
            local position = ticket.Track.TimePosition
            if finiteNumber(position) and position >= ticket.At then
                if position <= ticket.At + 0.18 then self:Consume(ticket) end
                ticket.Done = true
                table.remove(self.Actions, index)
            end
        end
    end
end

function Combat:IndexAnimation(animation)
    if not animation:IsA("Animation") then return end
    local parent = animation.Parent
    if not parent or not string.match(parent.Name, "^Melee") then return end
    local name = animation.Name
    if name == "Melee4" or name == "Up" or name == "Down" then
        self.AmbiguousAnimations[animation.AnimationId] = true
        self.Blockable[animation.AnimationId] = nil
    elseif string.match(name, "^Melee[123]$") and not self.AmbiguousAnimations[animation.AnimationId] then
        self.Blockable[animation.AnimationId] = name
    end
end

function Combat:IndexAnimations()
    local animations = ReplicatedStorage:FindFirstChild("Animations")
    if not animations or self.AnimationFolder == animations then return end
    self.AnimationFolder = animations
    for _, animation in ipairs(animations:GetDescendants()) do self:IndexAnimation(animation) end
end

function Combat:ReleaseBlock()
    if not self.BlockOwned then return end
    local char = self.BlockCharacter
    self.BlockOwned, self.BlockCharacter = false, nil
    local held = UserInputService:IsKeyDown(Enum.KeyCode.F)
    if char and char == LocalPlayer.Character and not held then
        JJS:Fire("BlockService", "Deactivated")
    end
end

function Combat:OnThreat(track)
    if not Autos.AutoBlock then return end
    local animation = track.Animation
    local label = animation and self.Blockable[animation.AnimationId]
    if label then
        self.Threat = {Track = track, Target = lockedTarget, Label = label,
            Until = os.clock() + Options.BlockHold}
    end
end

function Combat:WatchTarget()
    local hum = getHumanoid(lockedTarget)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator == self.TargetAnimator and lockedTarget == self.WatchedTarget then return end
    self:DisconnectList(self.TargetConnections)
    self:ReleaseBlock()
    self.TargetAnimator, self.WatchedTarget, self.Threat = animator, lockedTarget, nil
    if animator then
        table.insert(self.TargetConnections, connect(animator.AnimationPlayed, "target attack", function(track)
            self:OnThreat(track)
        end))
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do self:OnThreat(track) end
    end
end

function Combat:StepDefence()
    local threat = self.Threat
    local char = LocalPlayer.Character
    if not Autos.AutoBlock or not threat or not isActive or threat.Target ~= lockedTarget
        or os.clock() >= threat.Until or threat.Track.IsPlaying ~= true
        or not self:CanAct(char, false) or movementState ~= "IDLE" or self:IsTyping() then
        self:ReleaseBlock()
        return
    end
    local target, targetRoot, ownRoot = self:LockedWithin(Options.BlockRange)
    if not target then self:ReleaseBlock(); return end
    local delta = ownRoot.Position - targetRoot.Position
    if math.abs(delta.Y) > 8 or delta.Magnitude < 0.01
        or targetRoot.CFrame.LookVector:Dot(delta.Unit) < 0.1
        or not self:ClearLine(target, targetRoot.Position) then
        self:ReleaseBlock()
        return
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.F) then
        self.BlockOwned, self.BlockCharacter = false, nil
        return
    end
    if self:HasState(char, "Block") and not self.BlockOwned then return end
    local aimAt = Vector3.new(targetRoot.Position.X, ownRoot.Position.Y, targetRoot.Position.Z)
    if (aimAt - ownRoot.Position).Magnitude > 0.01 then
        ownRoot.CFrame = CFrame.lookAt(ownRoot.Position, aimAt)
    end
    if not self.BlockOwned then
        local ok = JJS:Fire("BlockService", "Activated", target)
        if ok then
            self.BlockOwned, self.BlockCharacter = true, char
            self.Stats.Blocks += 1
        end
    end
end

function Combat:OnBeam(remote, first, second)
    if typeof(remote) ~= "Instance"
        or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"))
        or not remote.Parent or typeof(first) ~= "Instance" or typeof(second) ~= "Instance"
        or not first.Parent or not second.Parent then return end
    if self.Beam and self.Beam.Remote == remote then return end
    self.Beam = {Remote = remote, First = first, Second = second, Next = 0,
        Character = LocalPlayer.Character, Generation = characterGeneration}
end

function Combat:StepBeam()
    local beam = self.Beam
    if not beam then return end
    if not isCurrentCharacter(beam.Character, beam.Generation)
        or not beam.Remote.Parent or not beam.First.Parent or not beam.Second.Parent then
        self.Beam = nil
        return
    end
    if not Autos.AutoBeam then return end
    local now = os.clock()
    if now < beam.Next or self:IsTyping() then return end
    beam.Next = now + Options.BeamInterval
    local ok = Runtime:Run("beam clash response", function() beam.Remote:FireServer(true) end)
    if ok then self.Stats.BeamResponses += 1 else self.Beam = nil end
end

function Combat:OwnSkill(slot)
    local char = LocalPlayer.Character
    local moveset = char and char:FindFirstChild("Moveset")
    if not moveset then return nil end
    for _, tool in ipairs(moveset:GetChildren()) do
        local key = tool:GetAttribute("Key")
        if tonumber(key) == slot and tool:GetAttribute("Service") then
            local ultimate = char:GetAttribute("InUlt") == true
            if (not tool:GetAttribute("AWK") or not ultimate)
                and (not tool:GetAttribute("AWK2") or ultimate) then return tool, key end
        end
    end
    return nil
end

function Combat:OnHit(effect, owner, target)
    if effect ~= "Hit" and effect ~= "BlackFlashHit" and effect ~= "DivergentHit"
        and effect ~= "GrabHit" and effect ~= "PerfectHit" then return end
    if owner ~= LocalPlayer.Character and owner ~= LocalPlayer then return end
    if not isActive or typeof(target) ~= "Instance" or target ~= lockedTarget then return end
    self.LastHit = {At = os.clock(), Target = target, Kind = effect}
    self.Stats.HitConfirms += 1
    if Autos.FollowUp and not self.FollowUp and os.clock() >= self.NextFollowUp then
        self.FollowUp = {Target = target, Character = LocalPlayer.Character,
            Generation = characterGeneration, Expires = os.clock() + 0.9}
    end
end

function Combat:StepFollowUp()
    local follow = self.FollowUp
    if not follow then return end
    if not Autos.FollowUp or not isCurrentCharacter(follow.Character, follow.Generation)
        or lockedTarget ~= follow.Target or not isActive or os.clock() > follow.Expires then
        self.FollowUp = nil
        return
    end
    if not self:CanAct(follow.Character, false) or self.BlockOwned or self:IsTyping()
        or not self:LockedWithin(Options.FollowUpRange) then return end
    local tool, key = self:OwnSkill(Options.FollowUpSlot)
    if not tool or not self.Tool or type(self.Tool.UseKey) ~= "function" then return end
    local readyAt = tool:GetAttribute("ReadyAt")
    if finiteNumber(readyAt) and workspace:GetServerTimeNow() < readyAt then return end
    self.FollowUp, self.NextFollowUp = nil, os.clock() + 0.8
    local controller = self.Tool
    local ok = Runtime:Run("hit-confirm follow-up", function()
        controller:UseKey(key, "Activated")
    end)
    -- Pair the native press with release, even if the activation bridge failed.
    Runtime:Run("follow-up release", function() controller:UseKey(key, "Deactivated") end)
    if ok then self.Stats.FollowUps += 1 end
end

function Combat:AttachRemote(remote)
    if typeof(remote) ~= "Instance" or self.Attached[remote]
        or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then return end
    if remote == JJS:GetRemote("BeamService", "Effects") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "beam effects", function(effect, ...)
            if Alive and effect == "ClashQTE" then self:OnBeam(...) end
        end))
    else
        for _, service in ipairs({"ItadoriService", "GojoService", "DivergentFistService",
            "FocusStrikeService", "NanamiService", "TodoService"}) do
            if remote == JJS:GetRemote(service, "Effects") then
                self.Attached[remote] = true
                track(connect(remote.OnClientEvent, "combat hit confirmation", function(effect, ...)
                    if Alive then self:OnHit(effect, ...) end
                end))
                break
            end
        end
    end
end

function Combat:ResetCharacter()
    self:ReleaseBlock()
    self.Beam, self.FollowUp, self.Threat = nil, nil, nil
    table.clear(self.Actions)
    self:DisconnectList(self.TargetConnections)
    self.WatchedTarget, self.TargetAnimator = nil, nil
end

function Combat:Destroy()
    self:ResetCharacter()
    self:RestorePatches()
    self:DisconnectList(self.UIConnections)
    table.clear(self.MouseContexts)
    self.Tool, self.Hitbox, self.Movement = nil, nil, nil
    self.Panel, self.PanelStatus, self.TargetLabel = nil, nil, nil
    self.Buttons, self.OptionLabels = {}, {}
end

function Combat:SetOption(name, value)
    local bounds = {
        AimLead = {0, 0.25}, HitboxScale = {1, 3}, BlockRange = {4, 30},
        BlockHold = {0.15, 0.7}, BeamInterval = {0.08, 0.5},
        FollowUpSlot = {1, 4}, FollowUpRange = {4, 30},
    }
    local limit = bounds[name]
    if not limit or not finiteNumber(value) then return false end
    value = math.clamp(value, limit[1], limit[2])
    if name == "FollowUpSlot" then value = math.floor(value + 0.5) end
    Options[name] = value
    self:RefreshPanel()
    return true
end

function Combat:SetFeature(name, enabled)
    if name == "SilentAim" then name = "MouseAssist" end
    if Autos[name] == nil then return false, "unknown feature" end
    Autos[name] = enabled == true
    if name == "AutoBlock" and not Autos.AutoBlock then self:ReleaseBlock() end
    if name == "AutoRatio" and not Autos.AutoRatio then self.RatioEpoch += 1 end
    if name == "FollowUp" and not Autos.FollowUp then self.FollowUp = nil end
    self:RefreshPanel()
    return true
end

function Combat:BuildPanel()
    if not GUI then return end
    self:DisconnectList(self.UIConnections)
    self.Buttons, self.OptionLabels = {}, {}
    local function new(class, props)
        local object = Instance.new(class)
        for key, value in pairs(props) do if key ~= "Parent" then object[key] = value end end
        object.Parent = props.Parent
        return object
    end
    local panel = new("Frame", {Name = "CombatControls", Size = UDim2.new(0, 310, 0, 490),
        Position = UDim2.new(0, 18, 0, 94), BackgroundColor3 = Color3.fromRGB(20, 23, 29),
        BorderSizePixel = 0, Visible = self.PanelOpen, Parent = GUI})
    self.Panel = panel
    new("UICorner", {CornerRadius = UDim.new(0, 8), Parent = panel})
    new("TextLabel", {Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 7),
        BackgroundTransparency = 1, Text = "RyuJJS  /  combat", Font = Enum.Font.SourceSansBold,
        TextSize = 21, TextColor3 = Color3.fromRGB(240, 242, 247), TextXAlignment = Enum.TextXAlignment.Left,
        Parent = panel})
    local list = new("ScrollingFrame", {Size = UDim2.new(1, -20, 1, -96),
        Position = UDim2.new(0, 10, 0, 42), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 620), ScrollBarThickness = 4, Parent = panel})
    local rows = {
        {"BlackFlash", "Black Flash timing"}, {"TodoSwap", "Todo animation follow-ups"},
        {"AutoRatio", "Nanami Ratio timing"}, {"AutoBeam", "Beam-clash responses"},
        {"PredictiveAim", "Predictive camera aim"}, {"MouseAssist", "Mouse assist (skills / targets)"},
        {"ChaseAssist", "Chase assist (multi-dash target)"},
        {"TodoSmart", "Todo special uses locked target"}, {"AutoBlock", "Reactive M1 block"},
        {"FollowUp", "Hit-confirm skill follow-up"}, {"TargetInfo", "Target state display"},
        {"ExtendedHitbox", "Extended hitbox (experimental)"},
    }
    for index, row in ipairs(rows) do
        local key = row[1]
        local button = new("TextButton", {Name = key, Size = UDim2.new(1, -4, 0, 29),
            Position = UDim2.new(0, 2, 0, (index - 1) * 32), BorderSizePixel = 0,
            Font = Enum.Font.SourceSans, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
            Parent = list})
        self.Buttons[key] = {Object = button, Label = row[2]}
        table.insert(self.UIConnections, connect(button.Activated, "feature toggle", function()
            self:SetFeature(key, not Autos[key])
        end))
    end
    local optionsStart = #rows * 32 + 12
    local options = {
        {"AimLead", "Aim lead (seconds)", 0.01, "%.2f"},
        {"HitboxScale", "Hitbox radius multiplier", 0.25, "%.2fx"},
        {"BlockRange", "Block range (studs)", 1, "%.0f"},
        {"FollowUpSlot", "Follow-up skill slot", 1, "%.0f"},
        {"BeamInterval", "Clash interval (seconds)", 0.02, "%.2f"},
    }
    for index, row in ipairs(options) do
        local y, key = optionsStart + (index - 1) * 34, row[1]
        local label = new("TextLabel", {Size = UDim2.new(1, -72, 0, 30), Position = UDim2.new(0, 4, 0, y),
            BackgroundTransparency = 1, Font = Enum.Font.SourceSans, TextSize = 15,
            TextColor3 = Color3.fromRGB(220, 226, 237), TextXAlignment = Enum.TextXAlignment.Left, Parent = list})
        self.OptionLabels[key] = {Object = label, Label = row[2], Format = row[4]}
        for _, sign in ipairs({-1, 1}) do
            local direction = sign
            local button = new("TextButton", {Size = UDim2.new(0, 29, 0, 27),
                Position = UDim2.new(1, direction == -1 and -66 or -33, 0, y + 1),
                Text = direction == -1 and "−" or "+", BackgroundColor3 = Color3.fromRGB(43, 49, 61),
                TextColor3 = Color3.fromRGB(240, 242, 247), BorderSizePixel = 0,
                Font = Enum.Font.SourceSansBold, TextSize = 18, Parent = list})
            table.insert(self.UIConnections, connect(button.Activated, "option adjustment", function()
                self:SetOption(key, Options[key] + row[3] * direction)
            end))
        end
    end
    local actionStart = optionsStart + #options * 34 + 8
    list.CanvasSize = UDim2.new(0, 0, 0, actionStart + 80)
    local swapButton = new("TextButton", {Size = UDim2.new(1, -8, 0, 29), Position = UDim2.new(0, 4, 0, actionStart),
        Text = "Todo: swap to locked target", BackgroundColor3 = Color3.fromRGB(43, 49, 61),
        TextColor3 = Color3.fromRGB(240, 242, 247), BorderSizePixel = 0,
        Font = Enum.Font.SourceSans, TextSize = 16, Parent = list})
    table.insert(self.UIConnections, connect(swapButton.Activated, "manual Todo swap", function()
        local char = LocalPlayer.Character
        local target = self:LockedWithin(100)
        if target and self:CanAct(char, true) and char:GetAttribute("Moveset") == "Todo" then
            JJS:Fire("TodoService", "RightActivated", target)
        end
    end))
    local saveButton = new("TextButton", {Size = UDim2.new(1, -8, 0, 29), Position = UDim2.new(0, 4, 0, actionStart + 35),
        Text = "Save settings", BackgroundColor3 = Color3.fromRGB(43, 49, 61),
        TextColor3 = Color3.fromRGB(240, 242, 247), BorderSizePixel = 0,
        Font = Enum.Font.SourceSans, TextSize = 16, Parent = list})
    table.insert(self.UIConnections, connect(saveButton.Activated, "save settings", function()
        local ok, reason = saveConfig()
        saveButton.Text = ok and "Settings saved" or "Save unavailable: " .. tostring(reason)
    end))
    self.PanelStatus = new("TextLabel", {Size = UDim2.new(1, -24, 0, 42),
        Position = UDim2.new(0, 12, 1, -48), BackgroundTransparency = 1,
        TextWrapped = true, Font = Enum.Font.SourceSans, TextSize = 13,
        TextColor3 = Color3.fromRGB(160, 174, 195), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel})
    local toggle = new("TextButton", {Name = "OpenControls", Size = UDim2.new(0, 167, 0, 28),
        Position = UDim2.new(0, 18, 0, 61), Text = "RyuJJS  ·  controls", BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromRGB(31, 36, 45), TextColor3 = Color3.fromRGB(240, 242, 247),
        Font = Enum.Font.SourceSansBold, TextSize = 16, Parent = GUI})
    table.insert(self.UIConnections, connect(toggle.Activated, "open controls", function()
        self.PanelOpen = not self.PanelOpen
        panel.Visible = self.PanelOpen
    end))
    self.TargetLabel = new("TextLabel", {Name = "TargetInfo", Size = UDim2.new(0, 620, 0, 26),
        Position = UDim2.new(0.5, -310, 0.84, 45), BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(220, 226, 237), TextStrokeTransparency = 0.5,
        Font = Enum.Font.SourceSans, TextSize = 16, Parent = GUI})
    self:RefreshPanel()
end

function Combat:RefreshPanel()
    for key, row in pairs(self.Buttons or {}) do
        row.Object.Text = "  " .. (Autos[key] and "ON   " or "OFF  ") .. row.Label
        row.Object.BackgroundColor3 = Autos[key] and Color3.fromRGB(31, 66, 60) or Color3.fromRGB(36, 41, 51)
        row.Object.TextColor3 = key == "ExtendedHitbox" and Color3.fromRGB(255, 187, 115)
            or Color3.fromRGB(233, 238, 246)
    end
    for key, row in pairs(self.OptionLabels or {}) do
        row.Object.Text = row.Label .. ": " .. string.format(row.Format, Options[key])
    end
    if self.PanelStatus then
        self.PanelStatus.Text = "RightShift: controls · C: lock/unlock\n" .. self.NativeStatus
    end
    local camera = workspace.CurrentCamera
    if self.Panel and camera then
        local view = camera.ViewportSize
        self.Panel.Size = UDim2.new(0, math.min(310, math.max(240, view.X - 36)),
            0, math.max(180, math.min(490, view.Y - 130)))
    end
end

function Combat:UpdateInfo()
    if not self.TargetLabel then return end
    local target, root, ownRoot = self:LockedWithin(math.huge)
    self.TargetLabel.Visible = Autos.TargetInfo and target ~= nil
    if not target then return end
    local hum = getHumanoid(target)
    local flags = {}
    for _, state in ipairs({"Block", "Stun", "Ragdoll", "InSkill"}) do
        if self:HasState(target, state) then table.insert(flags, state) end
    end
    local hit = self.LastHit and self.LastHit.Target == target and os.clock() - self.LastHit.At < 1.5
    self.TargetLabel.Text = string.format("HP %.0f  ·  %.1f studs  ·  %s%s", hum.Health,
        (root.Position - ownRoot.Position).Magnitude, #flags > 0 and table.concat(flags, " / ") or "Ready",
        hit and "  ·  hit confirmed" or "")
end

function Combat:Step()
    self:StepAnimations()
    self:StepBeam()
    self:StepDefence()
    self:StepFollowUp()
    local now = os.clock()
    if now >= self.NextWatch then
        self.NextWatch = now + 0.15
        self:WatchTarget()
        self:UpdateInfo()
    end
    if now >= self.NextDiscovery then
        self.NextDiscovery = now + 2
        self:IndexAnimations()
        if not self.Tool or not self.Hitbox or not self.Movement then self:ResolveControllers() end
        self:RefreshPanel()
    end
end

Runtime.Stage = "combat helper setup"
Combat:IndexAnimations()
Combat:BuildPanel()
track(connect(ReplicatedStorage.DescendantAdded, "combat remote discovery", function(object)
    if object:IsA("Animation") then Combat:IndexAnimation(object) end
    if object.Name == "Effects" then Combat:AttachRemote(object) end
end))
for _, service in ipairs({"BeamService", "ItadoriService", "GojoService", "DivergentFistService",
    "FocusStrikeService", "NanamiService", "TodoService"}) do
    local remote = JJS:GetRemote(service, "Effects")
    if remote then Combat:AttachRemote(remote) end
end
track(connect(RunService.Heartbeat, "combat helpers", function()
    if Alive then Combat:Step() end
end))
Combat:ResolveControllers()

Runtime.Stage = "configuration"
loadConfig()
Combat:RefreshPanel()

--==============================================================
-- JJS ANIMATION HOOKS
--==============================================================
local function setupJJS(char)
    if not Alive or char ~= LocalPlayer.Character then
        return
    end
    characterGeneration += 1
    local generation = characterGeneration
    Combat:ResetCharacter()
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
            Combat:QueueAnimation(track, delayTime, "BlackFlash", function()
                pressKey(Enum.KeyCode.Three)
            end)
        end

        if animId == todo1 and Autos.TodoSwap then
            Combat:QueueAnimation(track, 0.3, "TodoSwap", function()
                pressKey(Enum.KeyCode.Two)
            end)
        elseif animId == todo2 and Autos.TodoSwap then
            Combat:QueueAnimation(track, 0.6, "TodoSwap", function()
                pressKey(Enum.KeyCode.Two)
            end)
        end

        if Autos.TodoSwap and swapAnims[animId] then
            local len = 1
            local targetHum = getHumanoid(lockedTarget)
            if targetHum and targetHum.PlatformStand then
                len = 0.2
            end

            local ticket = Combat:QueueAnimation(track, len / 2, "TodoSwap", pressMouse1)
            pollForSwapAudio(char, generation, ticket)
        end
    end))
end

--==============================================================
-- FEATURE CONTROL
--==============================================================
local function setFeature(name, enabled)
    if name == "SilentAim" then name = "MouseAssist" end
    if Autos[name] == nil then
        return false, "unknown feature"
    end
    return Combat:SetFeature(name, enabled)
end

local function toggleFeature(name)
    if name == "SilentAim" then name = "MouseAssist" end
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

    if input.KeyCode == Enum.KeyCode.RightShift then
        Combat.PanelOpen = not Combat.PanelOpen
        if Combat.Panel then Combat.Panel.Visible = Combat.PanelOpen end
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
    Combat:ResetCharacter()
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
    Options = Options,
    SetOption = function(name, value) return Combat:SetOption(name, value) end,
    GetStats = function() return table.clone(Combat.Stats) end,
    GetStatus = function() return Combat.NativeStatus end,
    Unload = Cleanup,
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
            .. "RightShift / controls: combat settings\n"
            .. "C selects the target. Experimental hitboxes start OFF.",
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
