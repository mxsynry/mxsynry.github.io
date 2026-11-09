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

function Runtime:StopPrevious(namespace, fallback)
    local cleanup = namespace.RyuJJS
    if type(cleanup) ~= "function" then cleanup = fallback end
    if type(cleanup) ~= "function" then
        local api = namespace.RyuJJS_API
        cleanup = type(api) == "table" and api.Unload or nil
    end
    if type(cleanup) == "function" then return self:Run("previous instance cleanup", cleanup) end
    return true
end

function Runtime:ReleaseLegacyTracking(service)
    if type(service.UnbindFromRenderStep) ~= "function" then return end
    for _, name in ipairs({"RyuJJS_CharacterTracking", "RyuJJS_HybridFacing", "RyuJJS_CameraTracking"}) do
        pcall(service.UnbindFromRenderStep, service, name)
    end
end

local previousRyuCleanup = type(_G.RyuJJS_Diagnostics) == "table" and _G.RyuJJS_Diagnostics.Cleanup or nil
_G.RyuJJS_Diagnostics = Runtime
print("[RyuJJS] bootstrap entered")

local function start()
--[[
    RyuJJS + parsed JJS place adapter
    Standalone client script with labelled runtime diagnostics

    Controls
      C = lock / unlock closest target to screen center
      M = cycle Camera / Hybrid
      V = toggle target-height tracking (visible in controls)
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
      - Garuda Rebound responds once per local Recall window with the donor's ping lead.
      - Nanami Ratio uses the native server start/duration at 7:3, with TBO timing
        as a clock fallback. Early manual timing presses are queued. Ratio chains
        require a confirmed hit, the old bar to close and the native M2 cooldown.
        Automated timing and chains stay on the C target; unlock cancels them.
        Native first R uses that selection even with Mouse Assist disabled.
      - Yuki checks R readiness once, as TBO does, and uses an optional native
        target. Pulse requests do not prove instant mass gain.
      - Auto Burst uses side/back directions only during the native anti-team
        Burst grant. Ordinary ragdoll evasive / ForceEsc are not automated.
      - Yuki R retains native input and supplements it with TBO's gated charge pulses.
        The live server determines charge gain; no charge attribute/UI is spoofed.
      - Beam clashes respond only through a server-issued ClashQTE remote.
      - TBO-style block recognises live M1 animations and directed effects/Totality.
        Auto punish uses a real BlockHit marker to release owned block and send one M1.
        Defense defaults to the manual C target; nearby mode is optional.
      - C uses a streaming-aware character index. Todo observers are removed when finished.
      - Auto Burst uses only the native anti-team Burst grant; QTE uses live minigame sessions.
      - TBO: World Slash requires the Dismantle animation, full Special and owned Rush/Open.
        Auto adapt watches nearby Infinite Void; Shut Up reverses facing for its startup.
      - Typed native air hooks force only known air booleans/table fields, preserving targets.
        Locust/Hiromi Air markers retain their character-specific follow-up routes.
      - IYR instantpp handles the prompt being held. Auto train uses the ready station button.
      - Extra emote slots expose existing controls; server equip/ownership rules still apply.
      - Autosave debounces feature/option/view changes and flushes pending settings on unload.
      - Mouse assist keeps C's locked target in the game's shared mouse-dependent
        target, skill-aim and swap routes. Chase assist supplies that target specifically
        to MovementController.DashRequest; the game still decides when extra dashes apply.
      - Mouse assist and chase assist have separate toggles and are enabled by default.
      - Native targeting, chase and sphere-hitbox edits restore their previous methods on unload.
        Extended hitboxes are experimental; successful server damage is not guaranteed.
      - Skill assist follows real dash/Decisive/Swift Kick/Interrogate windows and the
        manual C lock. It supplies the locked Model to the native hitbox query result.
      - Gojo's 0.2 Domain has a separate temporary Hitbox remote: reports retain its
        (targetModel, attackerCFrame) contract, with configurable bounded repeats.
      - Yuki's OhNo launch opens a half-second latch window. Own-root placements work
        after death and stop on the server's OhNo2 latch confirmation or cancellation.
      - RyuJJS Hitboxes now wraps the live native SphereHitbox query, retaining native
        hitbox visuals; the reconstructed query remains a fallback. TBO size defaults to
        a minimum diameter of 20 (radius 10), preserving native attacks larger than 20.
      - Guard defaults to the C target; projectile blocking and guard auto-facing are
        opt-in. Old saved defaults migrate once to this quieter guard profile.
      - Projectile checks require a supported moving object on a collision course;
        Totality requires a nearby live attack animation rather than only a Target tag.
      - Camera tracking continues through movement, skills, dashes and blocking.
        Scripted/foreign cameras and typing pause it; the first eligible frame resumes.
        Root facing alone yields to grabs, ragdoll and explicit movement helpers.
      - GetClient's separate one-CFrame reply has a scoped dash/Decisive origin
        experiment and visible request counters. Server use/acceptance is unknown.
      - M cycles Camera and Hybrid tracking. Hybrid combines this script's camera aim
        with upright Hybrid facing derived from TBO P224.
        Character facing runs before the native camera; camera aim runs after it.
      - Camera smoothing defaults on with response 72. Character response
        defaults to 72 (TBO's .7 lerp at 60 FPS) and can be set independently. Native camera movement remains the camera aim base.
        AutoRotate is restored when a lock ends, pauses, changes mode or unloads.
      - Automatic rear teleporting was removed. Gojo's report can instead carry
        a rear origin facing the victim; this is an unverified server-side attempt.
        Front dash/Decisive retain Model-only reports without fabricated fields.
      - Target-height tracking is explicit and defaults on; old hidden pitch locks
        are not restored. The smoothing switch now applies to every tracking mode.
      - Guard animation profiles retain moveset context for shared regular/finisher
        IDs. Confirmed punish waits for recovery and no longer tests attacker facing.
      - Block/punish status explains inactive gates; guard retries are bounded to
        three requests per directed attack when no block state is observed.
      - TBO attack classifications include only ReplicatedStorage.Animations.
        Native BlockService.Effects confirms blocks, including perfect blocks.
        Guard follows native Tool.Block with a target-bearing remote fallback.
        Confirmed punish releases only when ready, requests Activated(false, target),
        and restores a still-held F after the counter window.
      - Aim follows root position, filters and bounds velocity lead, and runs after
        JJS Cam. The panel shows live Yuki / Garuda / Ratio waiting reasons.
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
Runtime:StopPrevious(_G, previousRyuCleanup)
previousRyuCleanup = nil
Runtime:ReleaseLegacyTracking(RunService)

pcall(function()
    for _, old in ipairs(PlayerGui:GetChildren()) do
        if old.Name == "GameSenseHUD" then old:Destroy() end
    end
end)

pcall(function()
    for _, obj in workspace:GetChildren() do
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

local function untrackCharacter(connection)
    local index = table.find(CharacterConnections, connection)
    if index then table.remove(CharacterConnections, index) end
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
    AutoTodoBlackFlash = true,            -- TBO Brute Force input sequence
    ShowFOV = false,
    AutoBurst = true,
    AutoQTE = true,
    AutoSpawnTrain = true,
    InstantPrompts = true,
    AutoSave = true,
    ExtraEmoteSlots = true,
    AutoAdapt = true,
    AutoWorldSlash = true,
    AutoShutUp = true,
    AutoAirVariants = true,
    AutoRatio = true,
    AutoRatioChain = true,
    AutoTodoPerfect = true,
    CursedStrikeSteer = true,
    CosmeticCatalog = true,
    UnlockEmotePages = true,
    InvisibleLocal = false,
    AutoBeam = true,
    PredictiveAim = true,
    MouseAssist = true,
    ChaseAssist = true,
    TodoSmart = true,
    AutoBlock = true,
    AutoPunish = true,
    AutoGarudaRebound = true,
    YukiInstantCharge = true,
    DefenceLockedOnly = false,
    BlockProjectiles = true,
    GuardAutoFace = true,
    CameraTracking = true,
    SmoothAim = true,
    VerticalAim = true,
    HybridFacingWhileMoving = true,
    FollowUp = false,
    TargetInfo = true,
    SkillAssist = true,
    AssistFrontDash = true,
    AssistDecisive = true,
    AssistTodo = true,
    AssistGojo = true,
    GojoHitBurst = true,
    AssistYuki = true,
    AssistNanami = true,
    TBOHitbox = true,
    GojoRearOrigin = true,
    DashClientOrigin = true,
    ExtendedHitbox = false,
}

local Options = {
    CosmeticSlot = 1, -- native emote slot (1..16)
    RatioTimingOffset = 0, -- milliseconds added to the native 7:3 request
    AimLead = 0.08,
    AimResponsiveness = 72,
    CameraAimStrength = .55,
    CharacterResponsiveness = 72,
    SmoothTurnSpeed = 1440,
    AimHorizontalOffset = 0,
    HitboxScale = 1.5,
    HitboxSize = 20,
    SkillAssistRange = 60,
    GojoHitReports = 8,
    GojoHitInterval = 0.05,
    YukiLatchAttempts = 5,
    RearOriginOffset = 3,
    BlockRange = 15,
    PunishRange = 11,
    BlockHold = 0.38,
    BeamInterval = 0.12,
    QTEInterval = 0.12,
    FollowUpSlot = 1,
    FollowUpRange = 12,
}

local CONFIG_FILE = "RyuJJS_Autos.json"

--==============================================================
-- STATE
--==============================================================
local isActive = false
local currentMode = "aim"

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
local TargetIndex = {List = {}, ByModel = {}, ByPart = {}, Scans = 0, LastLockMS = 0}
local Combat = {
    Actions = {}, Patches = {}, TargetConnections = {}, UIConnections = {},
    Defenders = {}, EffectConnections = {}, Projectiles = {},
    AirContexts = setmetatable({}, {__mode = "k"}), FailedAirSignals = setmetatable({}, {__mode = "k"}),
    BurstMarkers = setmetatable({}, {__mode = "k"}), AirMarkers = setmetatable({}, {__mode = "k"}),
    QTEJobs = {}, QTEGuis = {}, AdaptJobs = {}, EmoteRecords = {},
    SuiteSeen = setmetatable({}, {__mode = "k"}), AdaptSeen = setmetatable({}, {__mode = "k"}),
    PromptBusy = setmetatable({}, {__mode = "k"}),
    NextBurst = 0, NextAdapt = 0, NextQTEInput = 0, NextTrainCheck = 0, AirEpoch = 0,
    ConfigRevision = 0, ConfigDirty = false, SaveStatus = "Idle",
    GarudaSeen = setmetatable({}, {__mode = "k"}),
    PunishSeen = setmetatable({}, {__mode = "k"}),
    Sounds = setmetatable({}, {__mode = "k"}),
    NextPunish = 0, DefencePauseUntil = 0, NextYukiCharge = 0,
    MouseContexts = setmetatable({}, {__mode = "k"}),
    Attached = setmetatable({}, {__mode = "k"}), Blockable = {}, AmbiguousAnimations = {}, AttackProfiles = {},
    PendingAnimationIds = {}, RecentAttacks = setmetatable({}, {__mode = "k"}), GuardStatus = "Waiting for directed attack", PunishStatus = "Waiting for BlockHit",
    PanelOpen = false, NativeStatus = "Waiting for game controllers",
    NextWatch = 0, NextDiscovery = 0, NextFollowUp = 0, RatioEpoch = 0,
    Stats = {HitboxCandidates = 0, HitConfirms = 0, Blocks = 0, BeamResponses = 0, FollowUps = 0,
        ChaseSelections = 0, MouseSelections = 0, MouseAimPoints = 0, MouseSwapTargets = 0,
        GarudaRebounds = 0, YukiPulses = 0, Punishes = 0,
        Bursts = 0, QTEResponses = 0, TrainRequests = 0, Prompts = 0, Adaptations = 0,
        WorldSlashes = 0, ShutUps = 0, AirOverrides = 0, AirFollowUps = 0, ConfigSaves = 0, SaveFailures = 0},
}

--==============================================================
-- BASIC HELPERS
--==============================================================
local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

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
local JJS = {RemoteCache = {}, WireStats = {CacheHits = 0, CacheMisses = 0, Requests = 0, Failures = 0}}

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
    local key = serviceName .. "/" .. remoteName
    local cached = self.RemoteCache[key]
    if cached then
        local remote, folder, service = cached.Remote, cached.Folder, cached.Service
        if remote.Parent == folder and folder.Name == "RE" and folder.Parent == service and remote.Name == remoteName
            and service.Name == serviceName and service.Parent == cached.Services and cached.Services.Name == "Services"
            and cached.Services.Parent == cached.Module and cached.Module.Name == "Knit"
            and cached.Module.Parent == cached.Package and cached.Package.Name == "Knit"
            and cached.Package.Parent == ReplicatedStorage then
            self.WireStats.CacheHits += 1
            return remote
        end
        self.RemoteCache[key] = nil
    end
    self.WireStats.CacheMisses += 1
    local service = self:GetService(serviceName)
    local folder = service and service:FindFirstChild("RE")
    local remote = folder and folder:FindFirstChild(remoteName)
    if remote then
        local services = service.Parent
        self.RemoteCache[key] = {Remote = remote, Folder = folder, Service = service,
            Services = services, Module = services.Parent, Package = services.Parent.Parent}
    end
    return remote
end

function JJS:Fire(serviceName, remoteName, ...)
    local remote = self:GetRemote(serviceName, remoteName)
    if not remote or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
        self.WireStats.Failures += 1
        self.LastFailure = serviceName .. "." .. remoteName .. ": unavailable or not an event"
        return false, "missing event remote"
    end
    -- Forward varargs directly, including nil slots. No task queue, RemoteFunction
    -- round trip, packet-rate modification or rewrite of the game's Knit package.
    local ok, err = pcall(remote.FireServer, remote, ...)
    if ok then self.WireStats.Requests += 1
    else self.WireStats.Failures += 1; self.LastFailure = tostring(err) end
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
    if Combat.ResetTracking then Combat:ResetTracking("Tracking released")
    elseif Combat.ReleaseFacing then Combat:ReleaseFacing() end
    Combat.AimHistory, Combat.AimMotion, Combat.GuardTurnTarget = nil, nil, nil
    if Combat.Hitboxes then Combat.Hitboxes:Reset() end
    if Combat.SkillAssist then Combat.SkillAssist:Reset() end
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
    if TargetIndex.Destroy then TargetIndex:Destroy() end
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

-- Only character candidates are visited by C. Effects and map Models never
-- enter this list; streaming/reparenting updates it through two world signals.
function TargetIndex:Remove(model)
    local entry = self.ByModel[model]
    if not entry then return end
    local last = self.List[#self.List]
    self.List[entry.Index] = last
    self.List[#self.List] = nil
    if last ~= model then self.ByModel[last].Index = entry.Index end
    self.ByPart[entry.Humanoid], self.ByPart[entry.Root] = nil, nil
    self.ByModel[model] = nil
end

function TargetIndex:Consider(model)
    if not model or not model:IsA("Model") then return end
    if model.Parent ~= workspace and model.Parent ~= self.Folder then
        self:Remove(model)
        return
    end
    local hum, root = getHumanoid(model), getRoot(model)
    if not hum or not root then self:Remove(model); return end
    local old = self.ByModel[model]
    if old and old.Humanoid == hum and old.Root == root then return end
    if old then self:Remove(model) end
    table.insert(self.List, model)
    self.ByModel[model] = {Index = #self.List, Humanoid = hum, Root = root}
    self.ByPart[hum], self.ByPart[root] = model, model
end

function TargetIndex:Seed(container)
    if not container then return end
    self.Scans += 1
    for _, model in ipairs(container:GetChildren()) do self:Consider(model) end
end

function TargetIndex:RefreshFolder()
    local folder = getCharactersFolder()
    if folder == self.Folder then return end
    self.Folder = folder
    for i = #self.List, 1, -1 do
        local model = self.List[i]
        if model.Parent ~= workspace and model.Parent ~= folder then self:Remove(model) end
    end
    if folder ~= workspace then self:Seed(folder) end
end

function TargetIndex:Start()
    track(connect(workspace.DescendantAdded, "character index arrival", function(object)
        if not Alive then return end
        if object.Name == "Characters" then self:RefreshFolder() end
        if object:IsA("Model") then
            self:Consider(object)
        elseif object:IsA("Humanoid") or (object:IsA("BasePart") and object.Name == "HumanoidRootPart") then
            self:Consider(object.Parent)
        end
    end))
    track(connect(workspace.DescendantRemoving, "character index departure", function(object)
        if not Alive then return end
        local model = self.ByModel[object] and object or self.ByPart[object]
        if model then self:Remove(model) end
    end))
    self:RefreshFolder()
    self:Seed(workspace)
end

function TargetIndex:Destroy()
    table.clear(self.List)
    table.clear(self.ByModel)
    table.clear(self.ByPart)
    self.Folder = nil
end

TargetIndex:Start()

local function collectTargets()
    TargetIndex:RefreshFolder()
    return TargetIndex.List
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
    local selectionStarted = os.clock()
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

        local entry = TargetIndex.ByModel[obj]
        local hum = entry and entry.Humanoid
        local part = getAimPart(obj)
        local root = entry and entry.Root

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

    TargetIndex.LastLockMS = (os.clock() - selectionStarted) * 1000
    return closest
end

--==============================================================
-- TARGET LOCK / VALIDATION
--==============================================================
local function resetTargetWork(reason)
    stopMovementSystem()
    if Combat.ClearRatio then Combat:ClearRatio(reason) end
    Combat.RatioLockStarted = nil
    if Combat.ResetDefence then Combat:ResetDefence() end
    if Combat.DisconnectList then Combat:DisconnectList(Combat.TargetConnections) end
    Combat.WatchedTarget, Combat.TargetAnimator, Combat.Threat, Combat.FollowUp = nil, nil, nil, nil
end

local function clearTarget()
    -- Revoke selection before releasing helpers; no callback may reuse it.
    isActive, lockedTarget, lockedPlayer, lockedName = false, nil, nil, nil
    resetTargetWork("C target cleared")
    updateHighlight()
end

local function lockTarget(candidate)
    if typeof(candidate) ~= "Instance" or not candidate:IsA("Model") then return false end
    if not isActive or lockedTarget ~= candidate then
        isActive, lockedTarget = false, nil
        resetTargetWork("C target changed")
        Combat.RatioLockStarted = Combat.ServerNow and Combat:ServerNow() or nil
    end
    lockedTarget = candidate
    lockedPlayer = Players:GetPlayerFromCharacter(candidate)
    lockedName = not lockedPlayer and candidate.Name or nil
    isActive = true
    Combat.NextWatch = 0
    if Combat.WatchTarget then Combat:WatchTarget() end
    updateHighlight()
    return true
end

local function validateLockedTarget()
    if not isActive then return end
    if lockedPlayer then
        if Players:GetPlayerByUserId(lockedPlayer.UserId) ~= lockedPlayer then clearTarget(); return end
        local char = lockedPlayer.Character
        if char and char.Parent and getHumanoid(char) then
            if lockedTarget ~= char then
                lockedTarget = nil
                resetTargetWork("C target respawned")
                lockedTarget = char
                Combat.RatioLockStarted = Combat.ServerNow and Combat:ServerNow() or nil
                Combat.NextWatch = 0
            end
        elseif lockedTarget then
            lockedTarget = nil
            resetTargetWork("Waiting for C target respawn")
        end
        return
    end
    -- Preserve the existing dead-NPC selection and replacement-by-name behavior.
    if not lockedTarget or not lockedTarget.Parent then
        local replacement = lockedName and findTargetByName(lockedName)
        if replacement and getHumanoid(replacement) then lockTarget(replacement)
        else clearTarget() end
        return
    end
    local hum = getHumanoid(lockedTarget)
    if not hum or hum.Health <= 0 then
        stopMovementSystem()
        if Combat.ClearRatio then Combat:ClearRatio("C target unavailable") end
    end
end

--==============================================================
-- CAMERA / STARE TRACKING
--==============================================================
-- The game owns character/camera pose during skills, grabs and cutscenes.
function Combat:PoseBusy(char, forGuard)
    local hum, root = getHumanoid(char), getRoot(char)
    if not char or not char.Parent or not hum or hum.Health <= 0 or not root
        or root.Anchored == true or hum.PlatformStand == true then return true end
    if not forGuard and hum.AutoRotate == false then return true end
    for _, state in ipairs({"Stun", "Ragdoll", "InDash", "Emote", "Spectate"}) do
        if self:HasState(char, state) then return true end
    end
    local info = char:FindFirstChild("Info")
    if info and (info:FindFirstChild("InSkill") or info:FindFirstChild("Grab")
        or info:FindFirstChild("DomainClash") or info:FindFirstChild("Cutscene")) then return true end
    return root:FindFirstChild("GrabWeld") ~= nil or root:FindFirstChild("WeldGrab") ~= nil
end

-- Apply the same smoothing switch to character and camera in all modes.
-- Bound large turns in degrees/second so fast response settings or a hitch
-- cannot turn smooth mode into an unrestricted one-frame rotation.
function Combat:SmoothAlpha(current, goal, response, dt)
    if not Autos.SmoothAim then return 1 end
    local step = math.clamp(dt or 1/60, 0, 1/30)
    local alpha = 1 - math.exp(-response * step)
    local angle = math.acos(math.clamp(current.LookVector:Dot(goal.LookVector), -1, 1))
    if angle > 0.0001 then alpha = math.min(alpha, math.rad(Options.SmoothTurnSpeed) * step / angle) end
    return alpha
end

function Combat:ReleaseFacing()
    self.FacingHistory = nil
    local owned = self.FacingOwner
    self.FacingOwner = nil
    if owned and owned.Humanoid.Parent and owned.Humanoid.AutoRotate == false then
        owned.Humanoid.AutoRotate = owned.AutoRotate
    end
end

function Combat:OwnFacing(humanoid)
    if not humanoid or not humanoid.Parent then return false end
    if self.FacingOwner and self.FacingOwner.Humanoid ~= humanoid then self:ReleaseFacing() end
    if not self.FacingOwner then
        -- A native skill can already own rotation. Do not record its false
        -- value as our restore state and leave the character stuck on unlock.
        if humanoid.AutoRotate == false then return false end
        self.FacingOwner = {Humanoid = humanoid, AutoRotate = humanoid.AutoRotate}
    end
    if humanoid.AutoRotate ~= false then humanoid.AutoRotate = false end
    return true
end

function Combat:ResetTracking(reason)
    self:ReleaseFacing()
    self.AimHistory, self.AimMotion, self.GuardTurnTarget, self.CameraRotationPending = nil, nil, nil, nil
    if reason then
        self.TrackingReason, self.FacingTrackingReason, self.CameraTrackingReason = reason, reason, reason
    end
end

function Combat:SetMode(mode)
    if mode ~= "aim" and mode ~= "hybrid" then return false end
    if currentMode ~= mode then
        self:ResetTracking("Tracking mode changed")
        currentMode = mode
        self:MarkSettingsDirty()
    end
    self:RefreshPanel()
    return true
end

function Combat:CycleMode()
    return self:SetMode(currentMode == "aim" and "hybrid" or "aim")
end

-- Camera and character ownership are independent in Hybrid mode. A native
-- grab/gyro may own the root while camera aim continues normally.
function Combat:TrackingAllowed(mode)
    mode = mode or currentMode
    local function note(reason)
        if mode == "facing" then self.FacingTrackingReason = reason
        else self.CameraTrackingReason = reason end
        self.TrackingReason = reason
    end
    local function pause(reason)
        note(reason)
        if mode == "facing" then
            self:ReleaseFacing()
        else self.AimHistory, self.AimMotion = nil, nil end
        return false
    end
    if not Alive then return pause("Unloaded") end
    if not Autos.CameraTracking then return pause("Tracking disabled") end
    if not isActive or not lockedTarget then return pause("Waiting for C target") end
    if self:IsTyping() then return pause("Typing") end
    local char, camera = LocalPlayer.Character, workspace.CurrentCamera
    local hum, root = getHumanoid(char), getRoot(char)
    local targetHum, targetRoot = getHumanoid(lockedTarget), getLockedTargetRoot()
    if not char or not char.Parent or not hum or hum.Health <= 0 or not root then return pause("Character unavailable") end
    if not targetHum or targetHum.Health <= 0 or not targetRoot or not lockedTarget.Parent then return pause("Target unavailable") end
    if not camera then return pause("Camera unavailable") end
    local subject = camera.CameraSubject
    if camera.CameraType == Enum.CameraType.Scriptable then return pause("Scripted camera") end
    if not subject then return pause("Camera subject unavailable") end
    if subject ~= char and (typeof(subject) ~= "Instance" or not subject:IsDescendantOf(char)) then
        return pause("Camera follows another subject")
    end
    local info = char:FindFirstChild("Info")
    if info and info:FindFirstChild("Cutscene") then return pause("Cutscene") end
    if mode == "facing" then
        if movementState ~= "IDLE" or self.ShutUpJob then return pause("Movement helper owns facing") end
        if root.Anchored == true or hum.PlatformStand == true or self:HasState(char, "Ragdoll") then
            return pause("Root physics owns facing")
        end
        if root:FindFirstChild("GrabWeld") or root:FindFirstChild("WeldGrab")
            or (info and info:FindFirstChild("Grab")) then return pause("Grab owns facing") end
        if root:FindFirstChildOfClass("BodyGyro") then return pause("Native gyro owns facing") end
        if hum.AutoRotate == false and (not self.FacingOwner or self.FacingOwner.Humanoid ~= hum) then
            return pause("Native rotation owns facing")
        end
        if not Autos.HybridFacingWhileMoving and typeof(hum.MoveDirection) == "Vector3"
            and hum.MoveDirection.Magnitude > 0.05 then return pause("Moving: tracking option disabled") end
    end
    note("Tracking " .. (mode == "aim" and "camera" or "facing"))
    return true, camera
end

function Combat:TrackingPoint(dt)
    local root = getLockedTargetRoot()
    if not root then return end
    local previous, frame = self.AimMotion, self.TrackingFrame or 0
    if previous and previous.Root == root and previous.Character == LocalPlayer.Character and previous.Frame == frame then return previous.Point end
    local position, velocity = root.Position, root.AssemblyLinearVelocity
    local function valid(v)
        return typeof(v) == "Vector3" and finiteNumber(v.X) and finiteNumber(v.Y) and finiteNumber(v.Z)
    end
    if not valid(position) then return end
    if not valid(velocity) then velocity = Vector3.new(0, 0, 0) end
    if velocity.Magnitude > 160 then velocity = velocity.Unit * 160 end
    if Autos.SmoothAim and previous and previous.Root == root and previous.Character == LocalPlayer.Character
        and (position - previous.Position).Magnitude < 20 then
        local alpha = 1 - math.exp(-20 * math.clamp(dt or 1/60, 0, 1/30))
        velocity = previous.Velocity + (velocity - previous.Velocity) * alpha
    end
    local offset = Autos.PredictiveAim and velocity * Options.AimLead or Vector3.new(0, 0, 0)
    local ownRoot = getRoot(LocalPlayer.Character)
    local distance = ownRoot and (position - ownRoot.Position).Magnitude or 40
    local maxLead = math.min(4, distance * 0.12)
    if offset.Magnitude > maxLead then offset = offset.Unit * maxLead end
    local point = position + offset
    self.AimMotion = {Root = root, Character = LocalPlayer.Character, Position = position,
        Velocity = velocity, Point = point, Frame = frame}
    return point
end

function Combat:TurnRoot(root, humanoid, point, dt)
    local flat = Vector3.new(point.X, root.Position.Y, point.Z)
    if (flat - root.Position).Magnitude < 0.001 then return false end
    if not self:OwnFacing(humanoid) then return false end
    local goal, base, history = CFrame.lookAt(root.Position, flat), root.CFrame, self.FacingHistory
    if history and history.Root == root and history.Target == lockedTarget and history.Mode == currentMode then
        base = CFrame.lookAt(root.Position, root.Position + history.Frame.LookVector)
    end
    root.CFrame = base:Lerp(goal, self:SmoothAlpha(base, goal, Options.CharacterResponsiveness, dt))
    self.FacingHistory = {Root = root, Target = lockedTarget, Mode = currentMode, Frame = root.CFrame}
    return true
end

function Combat:RenderGuardTurn(dt)
    local target = self.GuardTurnTarget
    if not target or not target.Parent or not Autos.CameraTracking or not Autos.AutoBlock or not Autos.GuardAutoFace or not self.BlockOwned then return false end
    local char = LocalPlayer.Character
    if self:GuardBusyReason(char) then return false end
    local root, hum = getRoot(char), getHumanoid(char)
    if not root or root:FindFirstChildOfClass("BodyGyro") then return false end
    self:TurnRoot(root, hum, target.Position, dt)
    return true
end

local function hybridFacing(dt)
    if currentMode ~= "hybrid" then Combat:ReleaseFacing(); return end
    if not Combat:TrackingAllowed("facing") then return end
    local char = LocalPlayer.Character
    local myRoot, targetRoot = getRoot(char), getLockedTargetRoot()
    local point = Combat:TrackingPoint(dt)
    if not point then Combat:ReleaseFacing(); return end
    local flat = Vector3.new(point.X, myRoot.Position.Y, point.Z)
    if (flat - myRoot.Position).Magnitude < 0.001 then
        Combat:ReleaseFacing()
        Combat.FacingTrackingReason, Combat.TrackingReason = "Target shares horizontal position", "Target shares horizontal position"
        return
    end
    Combat:TurnRoot(myRoot, getHumanoid(char), point, dt)
end

function Combat:ObserveCameraInput(input, processed)
    -- A held stick can rotate the native camera without another notification.
    if input.KeyCode == Enum.KeyCode.Thumbstick2 then
        self.CameraStickInput = not processed and input or nil
        return
    end
    if not Alive or not isActive or not Autos.CameraTracking or self:IsTyping() then return end
    local kind, delta = input.UserInputType, nil
    if kind == Enum.UserInputType.MouseMovement then
        -- Moving an unlocked cursor is not a camera rotation request.
        if UserInputService.MouseBehavior == Enum.MouseBehavior.Default
            and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        delta = input.Delta
    elseif kind == Enum.UserInputType.Touch and not processed then delta = input.Delta end
    if typeof(delta) ~= "Vector3" and typeof(delta) ~= "Vector2" then return end
    if delta.Magnitude > .15 then self.CameraRotationPending = true end
end

function Combat:CameraInputActive()
    local active = self.CameraRotationPending == true
    self.CameraRotationPending = nil
    local stick = self.CameraStickInput
    local position = stick and stick.Position
    if (typeof(position) == "Vector3" or typeof(position) == "Vector2") and position.Magnitude > .12 then
        active = true
    end
    return active
end

function Combat:CameraAlpha(current, goal, dt)
    if not Autos.SmoothAim then return 1 end
    -- Use elapsed time at low frame rates, with a bound for long hitches.
    -- Body/guard smoothing keeps its separate response and turn ownership.
    local step = math.clamp(dt or 1/60, 0, .1)
    local alpha = 1 - math.exp(-Options.AimResponsiveness * Options.CameraAimStrength * step)
    local angle = math.acos(math.clamp(current.LookVector:Dot(goal.LookVector), -1, 1))
    if angle > .0001 then alpha = math.min(alpha, math.rad(Options.SmoothTurnSpeed) * step / angle) end
    return alpha
end

local function aimTracking(dt)
    -- Consume input during typing/cutscenes too, so it cannot replay later.
    local manual = Combat:CameraInputActive()
    if currentMode ~= "aim" and currentMode ~= "hybrid" then Combat.AimHistory = nil; return end
    local allowed, camera = Combat:TrackingAllowed("aim")
    if not allowed then return end
    local targetPos = Combat:TrackingPoint(dt)
    if not targetPos then Combat.AimHistory = nil; return end
    local base = camera.CFrame
    local camPos = base.Position
    local delta = targetPos - camPos
    if delta.Magnitude < .001 then Combat.AimHistory = nil; return end
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude >= .001 then
        local right = Vector3.new(-flat.Z, 0, flat.X).Unit
        targetPos += right * math.min(Options.AimHorizontalOffset, flat.Magnitude * .15)
        delta = targetPos - camPos
        flat = Vector3.new(delta.X, 0, delta.Z)
    end
    local nativeLook = base.LookVector
    local nativeYaw = math.atan2(nativeLook.X, -nativeLook.Z)
    local nativePitch = math.asin(math.clamp(nativeLook.Y, -1, 1))
    local targetYaw = flat.Magnitude >= .001 and math.atan2(flat.X, -flat.Z) or nativeYaw
    local targetPitch = math.atan2(delta.Y, flat.Magnitude)
    local history = Combat.AimHistory
    local matching = history and history.Camera == camera and history.Character == LocalPlayer.Character
        and history.Target == lockedTarget and history.Mode == currentMode
    local yawOffset, pitchOffset = 0, 0
    if matching then
        yawOffset, pitchOffset = history.YawOffset, history.PitchOffset
        if manual then
            -- Compare with the last output only to measure native input.
            -- The current native CFrame remains the interpolation base.
            local previous = history.Frame.LookVector
            local turn = nativeYaw - math.atan2(previous.X, -previous.Z)
            yawOffset = (yawOffset + turn + math.pi) % (2 * math.pi) - math.pi
            pitchOffset += nativePitch - math.asin(math.clamp(previous.Y, -1, 1))
        else
            local decay = math.exp(-8 * math.clamp(dt or 1/60, 0, .1))
            yawOffset *= decay
            pitchOffset *= decay
        end
    elseif manual then
        yawOffset = (nativeYaw - targetYaw + math.pi) % (2 * math.pi) - math.pi
        pitchOffset = nativePitch - targetPitch
    end
    if not Autos.VerticalAim then pitchOffset = 0 end
    pitchOffset = math.clamp(pitchOffset, -math.pi, math.pi)
    local yaw = targetYaw + yawOffset
    local pitch = Autos.VerticalAim and math.clamp(targetPitch + pitchOffset, math.rad(-85), math.rad(85)) or nativePitch
    local look = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
    local goal = CFrame.lookAt(camPos, camPos + look)
    local frame = base:Lerp(goal, Combat:CameraAlpha(base, goal, dt))
    if not Autos.VerticalAim then
        local forward = Vector3.new(frame.LookVector.X, 0, frame.LookVector.Z)
        if forward.Magnitude > .001 then
            frame = CFrame.lookAt(camPos, camPos + forward.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0))
        end
    end
    camera.CFrame = frame
    Combat.AimHistory = {Camera = camera, Character = LocalPlayer.Character,
        Target = lockedTarget, Mode = currentMode, Frame = frame,
        YawOffset = yawOffset, PitchOffset = pitchOffset, ManualInput = manual}
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
    if Combat.SaveBusy then return false, "save busy" end
    local revision = Combat.ConfigRevision
    local write = getGlobalFunction("writefile")
    local ok, reason
    if type(write) ~= "function" then
        ok, reason = false, "writefile unavailable"
    else
        Combat.SaveBusy = true
        ok, reason = pcall(function()
            local encoded = HttpService:JSONEncode({RuntimeProfile = "guard-camera-v2", TrackingProfile = "continuous-v1", AimProfile = "hybrid-responsive-v1", GuardAimProfile = "guard-smooth-v1", SourceProfile = "tbo-jjs-v1", ActionProfile = "ratio-burst-v1",
                Autos = Autos, Options = Options,
                CameraProfile = "continuous-input-v2", DefenceProfile = "roster-v1", CosmeticChoice = {MVP = Combat.Cosmetics.LocalOutro}, View = {Mode = currentMode}})
            write(CONFIG_FILE, encoded)
        end)
        Combat.SaveBusy = false
    end
    if ok then
        Combat.Stats.ConfigSaves += 1
        Combat.SaveStatus = "Saved"
        if Combat.ConfigRevision == revision then
            Combat.ConfigDirty, Combat.SaveDue, Combat.SaveForced = false, nil, nil
        end
    else
        Combat.Stats.SaveFailures += 1
        Combat.SaveStatus = tostring(reason)
    end
    if Combat.SaveButton then
        Combat.SaveButton.Text = ok and (Autos.AutoSave and "Autosave: saved" or "Settings saved")
            or "Save unavailable: " .. tostring(reason)
    end
    return ok, reason
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

    Combat.LoadingConfig = true
    Combat.ConfigDirty, Combat.SaveDue = false, nil
    if type(decoded.Autos) == "table" then
        for k, v in pairs(decoded.Autos) do
            local name = Combat.FeatureAliases[k] or k
            if Autos[name] ~= nil and type(v) == "boolean"
                and not (Combat.FeatureAliases[k] and decoded.Autos[name] ~= nil) then
                if Combat.SetFeature then Combat:SetFeature(name, v) else Autos[name] = v end
            end
        end
    end
    if type(decoded.Options) == "table" and Combat.SetOption then
        for key, value in pairs(decoded.Options) do Combat:SetOption(key, value) end
    end
    if type(decoded.CosmeticChoice) == "table" and type(decoded.CosmeticChoice.MVP) == "string"
        and table.find(Combat.CosmeticCatalog.MVP, decoded.CosmeticChoice.MVP) then Combat.Cosmetics.LocalOutro = decoded.CosmeticChoice.MVP end
    if type(decoded.View) == "table" then
        Combat:SetMode(decoded.View.Mode == "hybrid" and "hybrid" or "aim")
    end
    local migrated = decoded.RuntimeProfile ~= "guard-camera-v2"
    if migrated then
        Combat:SetFeature("DefenceLockedOnly", true)
        Combat:SetFeature("BlockProjectiles", false)
        Combat:SetFeature("GuardAutoFace", false)
        if Options.BlockRange == 12 then Combat:SetOption("BlockRange", 8) end
    end
    local trackingMigrated = decoded.TrackingProfile ~= "continuous-v1"
    if trackingMigrated then Combat:SetFeature("HybridFacingWhileMoving", true) end
    local aimMigrated = decoded.AimProfile ~= "hybrid-responsive-v1"
    if aimMigrated then
        Combat:SetFeature("SmoothAim", true)
        Combat:SetOption("AimResponsiveness", math.max(Options.AimResponsiveness, 120))
    end
    local sourceMigrated = decoded.SourceProfile ~= "tbo-jjs-v1"
    if sourceMigrated then
        if Options.AimResponsiveness == 120 then Combat:SetOption("AimResponsiveness", 72) end
        if Options.CharacterResponsiveness == 180 then Combat:SetOption("CharacterResponsiveness", 72) end
        if Options.BlockRange == 8 then Combat:SetOption("BlockRange", 15) end
    end
    local behaviorMigrated = decoded.GuardAimProfile ~= "guard-smooth-v1"
    if behaviorMigrated then Combat:SetFeature("VerticalAim", true) end
    local actionMigrated = decoded.ActionProfile ~= "ratio-burst-v1"
    local rosterMigrated = decoded.DefenceProfile ~= "roster-v1"
    if rosterMigrated then
        Combat:SetFeature("DefenceLockedOnly", false)
        Combat:SetFeature("GuardAutoFace", true)
        Combat:SetFeature("BlockProjectiles", true)
    end
    local cameraMigrated = decoded.CameraProfile ~= "continuous-input-v2"
    if cameraMigrated then Combat:SetFeature("SmoothAim", true) end
    Combat.LoadingConfig = false
    if cameraMigrated or rosterMigrated or actionMigrated or migrated or trackingMigrated or aimMigrated or behaviorMigrated or sourceMigrated then Combat:MarkSettingsDirty() end
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

local function run_blackflashgojo()
    local ok = Combat:ManualBlackFlash("ReversalRedMaxService", "Reversal Red MAX")
    if ok then return JJS:Fire("GojoService", "RightActivated") end
    return false
end

local function run_blackflash()
    return Combat:ManualBlackFlash("DivergentFistService", "Divergent Fist")
end

local function run_blackflashsmg()
    return Combat:ManualBlackFlash("FocusStrikeService", "Focus Strike")
end

-- Retain the old public helper name using the native move-tool route.
local blueflash = run_blackflash

--==============================================================
-- NANAMI RATIO POINT: ONLY THE REAL SERVER-ISSUED TIMING WINDOW
--==============================================================
-- TBO application prototypes 6/204: duration * clamp(.56 - (pingMS-100)*.0009, .25, .85).
-- Keep the current dump's owner/prompt/lifecycle validation around that action.


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

-- SpawnRatio(owner, target, gui, token, duration, serverStart) animates
-- Cursor.Y = 1 - (serverNow-serverStart)/duration. 7:3 is phase .7.
-- Keep TBO's empirical delay only when the native server clock is unavailable.
function Combat:ServerNow()
    local ok, value = pcall(workspace.GetServerTimeNow, workspace)
    return ok and finiteNumber(value) and value or nil
end

function Combat:SpecialRemaining(char)
    local cooldown, last = char:GetAttribute("M2_CD"), char:GetAttribute("LastM2")
    local server = self:ServerNow()
    if finiteNumber(cooldown) then
        if cooldown <= 0 then return 0 end
        if server and finiteNumber(last) then return math.max(0, last + cooldown - server) end
    end
    local fill = self:SpecialFill()
    if fill and fill:IsA("GuiObject") then return fill.Size.X.Scale >= 0.999 and 0 or nil end
    return nil
end

function Combat:ClearRatio(reason)
    self.RatioEpoch += 1
    self.RatioJob, self.RatioMark, self.RatioChain, self.RatioStartPending = nil, nil, nil, nil
    self.RatioCorrection = 0
    self.LastRatioPacket, self.LastRatioTiming = nil, nil
    self.LastRatioAttempt = nil
    if reason then self.RatioStatus = reason end
end

function Combat:RatioTargetValid(target, char)
    if not char or not char.Parent or not isActive or lockedTarget ~= target or char ~= LocalPlayer.Character
        or typeof(target) ~= "Instance" or not target:IsA("Model") or target == char or not target.Parent then return false end
    local root, own, hum = getRoot(target), getRoot(char), getHumanoid(target)
    local ownHum = getHumanoid(char)
    return root ~= nil and own ~= nil and hum ~= nil and hum.Health > 0
        and ownHum ~= nil and ownHum.Health > 0 and (root.Position - own.Position).Magnitude <= 70
end

function Combat:RatioInputTarget()
    local char = LocalPlayer.Character
    if not Alive or not char or not Autos.AutoRatio or not hasNativeRatioRoute(char) or self:IsTyping() then return end
    local info = char:FindFirstChild("Info")
    if info and info:FindFirstChild("InstantDomainClash") then return end
    if self:RatioTargetValid(lockedTarget, char) then return lockedTarget end
end

function Combat:ConfirmRatio(job, evidence)
    if job.Confirmed or job.Epoch ~= self.RatioEpoch or not isCurrentCharacter(job.Character, job.Generation)
        or not self:RatioTargetValid(job.Target, job.Character) then return end
    job.Confirmed = true
    -- The native cursor snaps to token.CurrentTiming after success. Use that
    -- actual receipt phase to centre later attempts, never write the token.
    self:LearnRatioTiming(job)
    self.RatioMark = {Target = job.Target, Gui = job.Gui, Token = job.Token, Character = job.Character,
        Generation = job.Generation, Epoch = job.Epoch, Expires = os.clock() + 4.8}
    self.Stats.RatioConfirms = (self.Stats.RatioConfirms or 0) + 1
    self.RatioStatus = "7:3 confirmed by " .. (evidence or "native token")
end

function Combat:QueueRatioChain(target, evidence)
    if not Autos.AutoRatio or not Autos.AutoRatioChain then return end
    local mark, char = self.RatioMark, LocalPlayer.Character
    if not mark or mark.Target ~= target or mark.Character ~= char or mark.Generation ~= characterGeneration
        or mark.Epoch ~= self.RatioEpoch or os.clock() > mark.Expires or not self:RatioTargetValid(target, char) then return end
    if self.RatioChain then return end
    self.RatioChain = {Target = target, Character = char, Generation = characterGeneration, Epoch = self.RatioEpoch,
        Mark = mark, Expires = os.clock() + 6, Evidence = evidence}
    self.RatioStatus = "Chain armed by " .. evidence .. "; waiting for native R reset"
end

function Combat:OnRatioHit(owner, target)
    if owner ~= LocalPlayer and owner ~= LocalPlayer.Character then return end
    local job = self.RatioJob
    if job and job.Token and job.Token.Value == true then self:ConfirmRatio(job) end
    self:QueueRatioChain(target, "confirmed hit")
end

function Combat:OnRatioDestroyed(owner, target, gui, consumed)
    if owner ~= LocalPlayer and owner ~= LocalPlayer.Character then return end
    if not self:RatioTargetValid(target, LocalPlayer.Character) then return end
    local job, mark = self.RatioJob or self.LastRatioAttempt, self.RatioMark
    if job and (job.Epoch ~= self.RatioEpoch or not isCurrentCharacter(job.Character, job.Generation)
        or (job.SentAt and os.clock() - job.SentAt > 6)) then job = nil end
    if job and job.Target == target and (not gui or not job.Gui or job.Gui == gui)
        and ((job.Token and job.Token.Value == true) or (consumed == true and job.SentAt)) then
        self:ConfirmRatio(job, consumed == true and "native RatioBreak" or nil); mark = self.RatioMark
    end
    if not mark or mark.Target ~= target or (gui and mark.Gui and gui ~= mark.Gui) then return end
    mark.BarGone = true
    -- DestroyRatio's true branch creates the native RatioBreak effect.
    if consumed == true then
        mark.Consumed = true
        self:QueueRatioChain(target, "native RatioBreak")
    elseif not self.RatioChain then self.RatioMark = nil end
    if job and job.Target == target then self.RatioJob = nil end
end

function Combat:RatioInput()
    local char = LocalPlayer.Character
    if not char or not Autos.AutoRatio or not hasNativeRatioRoute(char) then return false end
    local info = char:FindFirstChild("Info")
    if info and info:FindFirstChild("InstantDomainClash") then return false end
    if not self:RatioTargetValid(lockedTarget, char) then
        if self.RatioJob or self.RatioMark or self.RatioChain or self.RatioStartPending then self:ClearRatio("Waiting for C target") end
        if isActive then self.RatioStatus = "C target unavailable / outside Ratio range"; return true end
        return false -- no selection: retain ordinary manual Special behavior
    end
    local job, now = self.RatioJob, os.clock()
    if job and job.Epoch == self.RatioEpoch and job.Character == char and now < job.Expires then
        self.RatioStatus = job.Sent and "R already requested; waiting for native result" or "Early R queued for 7:3"
        return true
    end
    if self.RatioChain then return true end
    local mark = self.RatioMark
    if mark and now < mark.Expires and not mark.BarGone
        and ((mark.Gui and mark.Gui.Parent) or (mark.Token and mark.Token.Parent)) then return true end
    if self.RatioStartPending and now - self.RatioStartPending < 0.6 then
        self.RatioStatus = "Waiting for native Ratio bar"; return true
    end
    self.RatioStartPending = now
    return false
end

function Combat:StepRatio()
    local now, char = os.clock(), LocalPlayer.Character
    if self.LastRatioAttempt and now - self.LastRatioAttempt.SentAt > 6 then self.LastRatioAttempt = nil end
    if self.LastRatioAttempt then self:LearnRatioTiming(self.LastRatioAttempt) end
    if not Autos.AutoRatio then
        if self.RatioJob or self.RatioMark or self.RatioChain then self:ClearRatio("Auto Ratio off") end
        return
    end
    for _, pending in ipairs({self.RatioJob or false, self.RatioMark or false, self.RatioChain or false, self.LastRatioAttempt or false}) do
        if pending and (pending.Epoch ~= self.RatioEpoch or not isCurrentCharacter(pending.Character, pending.Generation)
            or not self:RatioTargetValid(pending.Target, char)) then self:ClearRatio("Ratio target changed / unavailable"); return end
    end
    local job = self.RatioJob
    if job then
        if not isCurrentCharacter(job.Character, job.Generation) or job.Character ~= char
            or job.Epoch ~= self.RatioEpoch or not hasNativeRatioRoute(char) then
            self:ClearRatio("Ratio character changed"); return
        end
        if job.Token and job.Token.Value == true then self:ConfirmRatio(job) end
        if job.Gui and job.Gui.Parent then job.SawGui = true end
        if job.Token and job.Token.Parent then job.SawToken = true end
        local ended = (job.SawToken and not job.Token.Parent) or (job.SawGui and not job.Gui.Parent)
        if job.Confirmed or ended or now >= job.Expires then
            if ended then self:LearnRatioTiming(job) end
            self.RatioJob = nil
            if not job.Confirmed then self.RatioStatus = ended and "Native Ratio bar closed" or "Ratio result unconfirmed" end
        elseif not job.Sent then
            local due = job.Due
            if job.ServerStart then
                local server = self:ServerNow()
                if server then due = now + job.ServerStart + job.Duration * 0.7
                    - math.clamp(self:PingMilliseconds() / 2000, 0, 0.35) + job.Correction + Options.RatioTimingOffset / 1000 - server end
            end
            if now >= due then
                if now - due > job.Duration * 0.08 + 0.025 then
                    job.Sent = true; self.RatioStatus = "7:3 arrival window already passed"
                elseif self:IsTyping() then self.RatioStatus = "Ratio waits while typing"
                else
                    job.Sent, job.SentAt = true, now
                    if JJS:Fire("NanamiService", "RightActivated") then
                        self.LastRatioAttempt = job
                        self.Stats.RatioRequests = (self.Stats.RatioRequests or 0) + 1
                        self.RatioStatus = "7:3 timing requested; awaiting native token"
                    else self.RatioStatus = "Ratio R remote unavailable" end
                end
            end
        end
    end
    local chain = self.RatioChain
    if not chain then return end
    if not Autos.AutoRatioChain or not isCurrentCharacter(chain.Character, chain.Generation)
        or chain.Epoch ~= self.RatioEpoch or not hasNativeRatioRoute(char) or now > chain.Expires
        or not self:RatioTargetValid(chain.Target, char) then
        self.RatioChain = nil; self.RatioStatus = "Ratio chain cancelled"; return
    end
    local mark = chain.Mark
    if not mark.BarGone then
        if (mark.Gui and mark.Gui.Parent) or (mark.Token and mark.Token.Parent) then return end
        mark.BarGone = true
    end
    if self.RatioJob or self:IsTyping() or movementState ~= "IDLE" then return end
    local ownHumanoid = getHumanoid(char)
    if not ownHumanoid or ownHumanoid.Health <= 0 then self.RatioChain = nil; return end
    local remaining = self:SpecialRemaining(char)
    if remaining == nil or remaining > 0 then self.RatioStatus = "Chain waits for native R cooldown"; return end
    self.RatioChain, self.RatioMark = nil, nil
    self.RatioStartPending = now
    -- First R carries the target; the timing R above carries no arguments.
    if JJS:Fire("NanamiService", "RightActivated", chain.Target) then
        self.Stats.RatioChains = (self.Stats.RatioChains or 0) + 1
        self.RatioStatus = "Chain R requested; waiting for new Ratio bar"
    else self.RatioStatus = "Chain R remote unavailable" end
end

local function queueRatioPoint(owner, target, gui, resolved, duration, startedAt)
    if owner ~= LocalPlayer then return false end
    Combat.Stats.RatioEvents = (Combat.Stats.RatioEvents or 0) + 1
    local char, generation, epoch = LocalPlayer.Character, characterGeneration, Combat.RatioEpoch
    if not Autos.AutoRatio or not isCurrentCharacter(char, generation) or not hasNativeRatioRoute(char)
        or Combat:IsTyping() then Combat.RatioStatus = "Ratio paused"; return false end
    if not finiteNumber(duration) or duration <= 0 or duration > 10 then Combat.RatioStatus = "Invalid ratio duration"; return false end
    local now, server = os.clock(), Combat:ServerNow()
    local timed = finiteNumber(startedAt) and server ~= nil
    if timed and (server - startedAt < -0.2 or server - startedAt > duration + 0.15) then
        Combat.RatioStatus = "Native Ratio timestamp expired / invalid"; return false
    end
    local active = Combat.RatioJob
    if timed and active and active.ServerStart and startedAt < active.ServerStart then return false end
    if timed and Combat.RatioLockStarted and startedAt < Combat.RatioLockStarted - 0.02 then
        Combat.RatioStatus = "Ratio packet predates current C selection"; return false
    end
    if not Combat:RatioTargetValid(target, char) then
        -- A timing R has no target argument. A newer foreign bar must cancel
        -- our old timer as well, or that timer could resolve the wrong bar.
        Combat:ClearRatio(isActive and "Native Ratio target differs from C target" or "Waiting for C target")
        return false
    end
    local token = typeof(resolved) == "Instance" and resolved:IsA("BoolValue") and resolved or nil
    local panel = typeof(gui) == "Instance" and gui or nil
    local key, previous = token or panel, Combat.LastRatioPacket
    local seen = key and ratioMarkers[key] or previous
    if seen and seen.Epoch == epoch and seen.Target == target and seen.Started == startedAt and seen.Duration == duration
        and (timed or now - seen.At < 0.1 or (active and active.Id == seen.Id)) then return false end
    local factor = math.clamp(0.56 - ((math.floor(Combat:PingMilliseconds()) - 100) / 1000) * 0.9, 0.25, 0.85)
    local correction = timed and (Combat.RatioCorrection or 0) or 0
    local due = now + duration * factor + correction + Options.RatioTimingOffset / 1000
    if timed then due = now + startedAt + duration * 0.7 - math.clamp(Combat:PingMilliseconds() / 2000, 0, 0.35)
        + correction + Options.RatioTimingOffset / 1000 - server end
    Combat.RatioSerial = (Combat.RatioSerial or 0) + 1
    local job = {Id = Combat.RatioSerial, Target = target, Gui = panel, Token = token,
        InitialTiming = token and token:GetAttribute("CurrentTiming"), Duration = duration, Due = due,
        ServerStart = timed and startedAt or nil, Correction = correction, Character = char, Generation = generation, Epoch = epoch,
        Expires = now + math.max(0.15, duration - (timed and server - startedAt or 0)) + 0.3,
        SawGui = panel and panel.Parent ~= nil, SawToken = token and token.Parent ~= nil}
    -- Keep no Job/token reference in a weak-key value: it would retain its own
    -- supposedly weak key after many Ratio sessions.
    local record = {Id = job.Id, Epoch = epoch, Target = target, Started = startedAt, Duration = duration, At = now}
    if key then ratioMarkers[key] = record end
    Combat.LastRatioPacket, Combat.RatioJob = record, job
    Combat.RatioChain, Combat.RatioStartPending = nil, nil
    Combat.LastRatioAttempt = nil
    Combat.RatioStatus = timed and "Native server clock armed at 7:3" or "TBO timing fallback armed"
    if token and token.Value == true then Combat:ConfirmRatio(job) end
    return true
end

local function setupRatioPointObserver()
    local attached = setmetatable({}, {__mode = "k"})
    local function attach(remote)
        if not Alive or typeof(remote) ~= "Instance" or attached[remote] or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent"))
            or remote.Name ~= "Effects" or remote ~= JJS:GetRemote("NanamiService", "Effects") then
            return
        end
        attached[remote] = true
        track(connect(remote.OnClientEvent, "Nanami effects", function(effect, ...)
            if not Alive then return end
            if effect == "SpawnRatio" then queueRatioPoint(...)
            elseif effect == "DestroyRatio" then Combat:OnRatioDestroyed(...) end
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
-- The embedded RyuJJS hitbox module uses that contract and the native reporter.
-- Server-side range and blocking validation are absent from this client dump.

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
    return not hit or hit.Instance == character or hit.Instance:IsDescendantOf(character)
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
        Generation = characterGeneration, Target = lockedTarget, Epoch = self.RatioEpoch}
    local results = table.pack(pcall(original, ...))
    self.MouseContexts[token] = previous
    if not results[1] then error(results[2], 0) end
    return table.unpack(results, 2, results.n)
end

function Combat:MouseRouteEnabled()
    local context = self.MouseContexts[coroutine.running() or self]
    if context and context.Route == "guard" then
        local target = context.Target
        local valid = target == nil or (typeof(target) == "Instance" and target:IsA("Model") and target.Parent and getRoot(target))
        return valid and context.Character == LocalPlayer.Character and context.Generation == characterGeneration, "guard", context
    end
    if context and context.Route == "ratio" then
        return Autos.AutoRatio and context.Character == LocalPlayer.Character
            and context.Generation == characterGeneration and context.Epoch == self.RatioEpoch
            and self:RatioTargetValid(context.Target, context.Character), "ratio", context
    end
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
            local enabled, route, context = self:MouseRouteEnabled()
            if route == "ratio" or route == "guard" then
                -- Never fall through to a different mouse target in this call.
                if Alive and enabled then return context.Target end
                return nil
            end
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
                local target, root = self:MouseTargetWithin(100)
                if target and char:GetAttribute("Moveset") == "Todo" then
                    local own = getRoot(char)
                    if not own or (root.Position - own.Position).Magnitude > 60 then target = nil end
                end
                if isActive and Autos.TodoSmart and char:GetAttribute("Moveset") == "Todo" and not target then return nil end
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
    self:InstallYukiController(tool)
    self:InstallAirControllers(tool)
    self:Patch(hitbox, "SphereHitbox", function(original)
        return function(controller, ...)
            return self.Hitboxes:Intercept(original, controller, ...)
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
                if Alive then
                    self:InstallControllers(tool, hitbox, movement)
                    self.Cosmetics:InstallOutros()
                end
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

-- TBO classifier results for the supplied ReplicatedStorage.Animations assets.
-- Data only; no donor loader or obfuscated code runs in this script.
Combat.TBOAttackFlags = {
    ["rbxassetid://100040983719699"] = 16,
    ["rbxassetid://100108404823407"] = 17,
    ["rbxassetid://100164832424643"] = 17,
    ["rbxassetid://100446064103831"] = 17,
    ["rbxassetid://100474683542881"] = 22,
    ["rbxassetid://100515557795491"] = 16,
    ["rbxassetid://100778093235310"] = 17,
    ["rbxassetid://100811576955331"] = 17,
    ["rbxassetid://100835844904897"] = 22,
    ["rbxassetid://100919783371339"] = 21,
    ["rbxassetid://100962226150441"] = 16,
    ["rbxassetid://101079657277587"] = 17,
    ["rbxassetid://101107501526373"] = 21,
    ["rbxassetid://101283990868172"] = 22,
    ["rbxassetid://101617544363219"] = 17,
    ["rbxassetid://101681158700275"] = 21,
    ["rbxassetid://101862938993177"] = 22,
    ["rbxassetid://102053631728986"] = 17,
    ["rbxassetid://102085681670810"] = 22,
    ["rbxassetid://102143238290614"] = 17,
    ["rbxassetid://102221764735089"] = 17,
    ["rbxassetid://102285403332509"] = 22,
    ["rbxassetid://102532077942921"] = 17,
    ["rbxassetid://102580834319938"] = 17,
    ["rbxassetid://103013818601982"] = 25,
    ["rbxassetid://103194057617238"] = 17,
    ["rbxassetid://103493656287292"] = 16,
    ["rbxassetid://103659500760745"] = 17,
    ["rbxassetid://103798931313663"] = 22,
    ["rbxassetid://103960582499076"] = 17,
    ["rbxassetid://104082985552315"] = 17,
    ["rbxassetid://104087365067491"] = 22,
    ["rbxassetid://104137631480391"] = 21,
    ["rbxassetid://104330988826871"] = 17,
    ["rbxassetid://104390547696455"] = 22,
    ["rbxassetid://104597702149205"] = 17,
    ["rbxassetid://104749346956269"] = 17,
    ["rbxassetid://104824728032437"] = 25,
    ["rbxassetid://105028055041290"] = 16,
    ["rbxassetid://105077924973072"] = 22,
    ["rbxassetid://105121164520635"] = 17,
    ["rbxassetid://105191773344078"] = 17,
    ["rbxassetid://105287938257399"] = 21,
    ["rbxassetid://105376952884290"] = 21,
    ["rbxassetid://105405605107240"] = 17,
    ["rbxassetid://105571879949076"] = 17,
    ["rbxassetid://105801749091005"] = 17,
    ["rbxassetid://105870773841535"] = 22,
    ["rbxassetid://105878146832347"] = 21,
    ["rbxassetid://105934922038894"] = 16,
    ["rbxassetid://105961366724096"] = 22,
    ["rbxassetid://106224500692893"] = 17,
    ["rbxassetid://106245594701442"] = 22,
    ["rbxassetid://106282708121342"] = 22,
    ["rbxassetid://106474043944206"] = 22,
    ["rbxassetid://106478217686775"] = 17,
    ["rbxassetid://106607942310644"] = 17,
    ["rbxassetid://106892235857467"] = 22,
    ["rbxassetid://107029561762376"] = 22,
    ["rbxassetid://107307520827908"] = 17,
    ["rbxassetid://107554693613496"] = 16,
    ["rbxassetid://107567569618077"] = 17,
    ["rbxassetid://107825127494342"] = 22,
    ["rbxassetid://107852433150124"] = 22,
    ["rbxassetid://108027796023968"] = 22,
    ["rbxassetid://108123475959041"] = 17,
    ["rbxassetid://108374320117834"] = 17,
    ["rbxassetid://108376755316792"] = 22,
    ["rbxassetid://108407413391495"] = 25,
    ["rbxassetid://108418554887656"] = 17,
    ["rbxassetid://108449614447004"] = 22,
    ["rbxassetid://108636011034323"] = 22,
    ["rbxassetid://108686045412945"] = 22,
    ["rbxassetid://108708446862011"] = 22,
    ["rbxassetid://108865650924154"] = 17,
    ["rbxassetid://109069266611522"] = 17,
    ["rbxassetid://109299799610861"] = 17,
    ["rbxassetid://109340494549365"] = 22,
    ["rbxassetid://109432265703187"] = 22,
    ["rbxassetid://109598602517674"] = 21,
    ["rbxassetid://109718372214725"] = 22,
    ["rbxassetid://109787638891072"] = 17,
    ["rbxassetid://109825612550559"] = 17,
    ["rbxassetid://109930698075698"] = 17,
    ["rbxassetid://110146909061402"] = 22,
    ["rbxassetid://110326542726854"] = 17,
    ["rbxassetid://110425977429691"] = 21,
    ["rbxassetid://110958607174992"] = 21,
    ["rbxassetid://110978068388232"] = 17,
    ["rbxassetid://111083699259354"] = 22,
    ["rbxassetid://111720035828971"] = 17,
    ["rbxassetid://111750364977569"] = 16,
    ["rbxassetid://111847286274327"] = 17,
    ["rbxassetid://112223227323175"] = 17,
    ["rbxassetid://112445967418621"] = 17,
    ["rbxassetid://112868588878225"] = 17,
    ["rbxassetid://112945900653499"] = 22,
    ["rbxassetid://112976111828157"] = 6,
    ["rbxassetid://113359849246757"] = 17,
    ["rbxassetid://113722638806911"] = 25,
    ["rbxassetid://113963875117859"] = 22,
    ["rbxassetid://114277419400774"] = 17,
    ["rbxassetid://114321791577837"] = 17,
    ["rbxassetid://114375152692460"] = 22,
    ["rbxassetid://114562626498918"] = 16,
    ["rbxassetid://114648729358082"] = 6,
    ["rbxassetid://114723941013668"] = 17,
    ["rbxassetid://114797198964940"] = 16,
    ["rbxassetid://114822879878184"] = 25,
    ["rbxassetid://114913455544468"] = 22,
    ["rbxassetid://114985590391235"] = 22,
    ["rbxassetid://115042679536959"] = 16,
    ["rbxassetid://115097960689033"] = 17,
    ["rbxassetid://115220151812065"] = 6,
    ["rbxassetid://115446267797335"] = 21,
    ["rbxassetid://115525391286129"] = 17,
    ["rbxassetid://115557996464677"] = 17,
    ["rbxassetid://115561023870463"] = 17,
    ["rbxassetid://115580881672346"] = 17,
    ["rbxassetid://115586282387431"] = 17,
    ["rbxassetid://115589615022077"] = 17,
    ["rbxassetid://115616081167949"] = 17,
    ["rbxassetid://115781423162319"] = 22,
    ["rbxassetid://115912582567240"] = 17,
    ["rbxassetid://116119661056362"] = 17,
    ["rbxassetid://116432619539029"] = 17,
    ["rbxassetid://116737527523542"] = 17,
    ["rbxassetid://116910683335467"] = 23,
    ["rbxassetid://117081962036725"] = 17,
    ["rbxassetid://117178057848472"] = 17,
    ["rbxassetid://117318845383884"] = 17,
    ["rbxassetid://117371289990421"] = 17,
    ["rbxassetid://117465720955224"] = 17,
    ["rbxassetid://117638619792450"] = 21,
    ["rbxassetid://117831239064143"] = 23,
    ["rbxassetid://117836779292116"] = 17,
    ["rbxassetid://117901738176901"] = 21,
    ["rbxassetid://117999424328891"] = 21,
    ["rbxassetid://118076716434659"] = 17,
    ["rbxassetid://118326207788271"] = 17,
    ["rbxassetid://118433412162663"] = 22,
    ["rbxassetid://118607369830566"] = 16,
    ["rbxassetid://118634493886688"] = 21,
    ["rbxassetid://118652212972529"] = 17,
    ["rbxassetid://118813489101356"] = 17,
    ["rbxassetid://119042572747325"] = 22,
    ["rbxassetid://119152716475706"] = 17,
    ["rbxassetid://119248903710146"] = 22,
    ["rbxassetid://119434039452526"] = 17,
    ["rbxassetid://119438066502737"] = 17,
    ["rbxassetid://119455868371102"] = 17,
    ["rbxassetid://119635500264882"] = 17,
    ["rbxassetid://119713012645788"] = 17,
    ["rbxassetid://119918873304328"] = 17,
    ["rbxassetid://120136894011461"] = 17,
    ["rbxassetid://120355051037295"] = 17,
    ["rbxassetid://120480195428173"] = 16,
    ["rbxassetid://120807109229937"] = 17,
    ["rbxassetid://120904254742916"] = 22,
    ["rbxassetid://120914276661831"] = 17,
    ["rbxassetid://120951759618134"] = 17,
    ["rbxassetid://121158593063065"] = 17,
    ["rbxassetid://121239701968766"] = 17,
    ["rbxassetid://121315288429799"] = 17,
    ["rbxassetid://121322029260156"] = 22,
    ["rbxassetid://121403322067812"] = 21,
    ["rbxassetid://121415876792706"] = 17,
    ["rbxassetid://121550561336691"] = 17,
    ["rbxassetid://121800365664070"] = 22,
    ["rbxassetid://122015481201264"] = 17,
    ["rbxassetid://122074769949629"] = 22,
    ["rbxassetid://122129678566274"] = 22,
    ["rbxassetid://122170399962557"] = 22,
    ["rbxassetid://122573730331631"] = 22,
    ["rbxassetid://122607727974119"] = 17,
    ["rbxassetid://122655618588472"] = 21,
    ["rbxassetid://122952270797174"] = 17,
    ["rbxassetid://123168328205349"] = 21,
    ["rbxassetid://123171106092050"] = 16,
    ["rbxassetid://123236749567737"] = 22,
    ["rbxassetid://123414935051274"] = 22,
    ["rbxassetid://123591522021548"] = 22,
    ["rbxassetid://123778544771528"] = 17,
    ["rbxassetid://124301431492121"] = 17,
    ["rbxassetid://124340599144108"] = 25,
    ["rbxassetid://124427228784862"] = 17,
    ["rbxassetid://124726819047447"] = 21,
    ["rbxassetid://124759375124281"] = 16,
    ["rbxassetid://124760854087851"] = 17,
    ["rbxassetid://124777463468279"] = 17,
    ["rbxassetid://124862357369335"] = 22,
    ["rbxassetid://124901309160375"] = 17,
    ["rbxassetid://125120382787311"] = 22,
    ["rbxassetid://125307894046906"] = 17,
    ["rbxassetid://125437008238571"] = 17,
    ["rbxassetid://125455197945793"] = 17,
    ["rbxassetid://125564438857083"] = 17,
    ["rbxassetid://125603637184820"] = 22,
    ["rbxassetid://125689391910002"] = 22,
    ["rbxassetid://125904281673524"] = 17,
    ["rbxassetid://126277739156443"] = 22,
    ["rbxassetid://126361446385942"] = 17,
    ["rbxassetid://126362899488198"] = 17,
    ["rbxassetid://127171275866632"] = 17,
    ["rbxassetid://127457641316758"] = 17,
    ["rbxassetid://127727754867974"] = 25,
    ["rbxassetid://127851700400958"] = 23,
    ["rbxassetid://128057999506702"] = 22,
    ["rbxassetid://128247404669136"] = 21,
    ["rbxassetid://128267680345523"] = 17,
    ["rbxassetid://128318481830703"] = 17,
    ["rbxassetid://128437228548370"] = 21,
    ["rbxassetid://128537969081721"] = 17,
    ["rbxassetid://129035777318346"] = 17,
    ["rbxassetid://129064717767223"] = 17,
    ["rbxassetid://129132347098646"] = 17,
    ["rbxassetid://129385939516650"] = 17,
    ["rbxassetid://129423542571479"] = 17,
    ["rbxassetid://129583539805939"] = 17,
    ["rbxassetid://129678103897608"] = 25,
    ["rbxassetid://129876493950288"] = 17,
    ["rbxassetid://129944486689528"] = 25,
    ["rbxassetid://130013701390383"] = 17,
    ["rbxassetid://130123540243667"] = 17,
    ["rbxassetid://130135202362252"] = 17,
    ["rbxassetid://130284226842903"] = 17,
    ["rbxassetid://130659585624615"] = 22,
    ["rbxassetid://130806585141471"] = 22,
    ["rbxassetid://130834106305514"] = 17,
    ["rbxassetid://130957217409359"] = 17,
    ["rbxassetid://131031842057158"] = 17,
    ["rbxassetid://131033861605339"] = 22,
    ["rbxassetid://131158776477817"] = 16,
    ["rbxassetid://131279921755936"] = 21,
    ["rbxassetid://131506102901134"] = 25,
    ["rbxassetid://131826588098422"] = 25,
    ["rbxassetid://131904892480473"] = 17,
    ["rbxassetid://131909724908049"] = 22,
    ["rbxassetid://131917532383382"] = 17,
    ["rbxassetid://131948591638044"] = 17,
    ["rbxassetid://131967150738931"] = 22,
    ["rbxassetid://132209302689060"] = 22,
    ["rbxassetid://132281807148575"] = 16,
    ["rbxassetid://132307745371357"] = 17,
    ["rbxassetid://132615896981226"] = 16,
    ["rbxassetid://132653290201368"] = 17,
    ["rbxassetid://132855702748568"] = 17,
    ["rbxassetid://132928484483887"] = 17,
    ["rbxassetid://133042937840159"] = 17,
    ["rbxassetid://133240987753043"] = 22,
    ["rbxassetid://133447840605824"] = 22,
    ["rbxassetid://133460338652190"] = 17,
    ["rbxassetid://133869529005453"] = 17,
    ["rbxassetid://133936641185614"] = 22,
    ["rbxassetid://134243365075812"] = 17,
    ["rbxassetid://134343445195846"] = 17,
    ["rbxassetid://134345569411884"] = 17,
    ["rbxassetid://134461702265323"] = 17,
    ["rbxassetid://134509540337310"] = 17,
    ["rbxassetid://134622175293378"] = 22,
    ["rbxassetid://134622628645994"] = 17,
    ["rbxassetid://134777193523837"] = 17,
    ["rbxassetid://134917827147266"] = 17,
    ["rbxassetid://134979023659909"] = 17,
    ["rbxassetid://135048320277030"] = 17,
    ["rbxassetid://135256592475167"] = 22,
    ["rbxassetid://135300554211825"] = 17,
    ["rbxassetid://135327783612081"] = 17,
    ["rbxassetid://135411487367370"] = 17,
    ["rbxassetid://135686778593679"] = 22,
    ["rbxassetid://135805825263494"] = 22,
    ["rbxassetid://136086293922212"] = 17,
    ["rbxassetid://136338232194928"] = 17,
    ["rbxassetid://136466703751033"] = 16,
    ["rbxassetid://136523051723440"] = 17,
    ["rbxassetid://136536827155962"] = 16,
    ["rbxassetid://136658834297626"] = 17,
    ["rbxassetid://136978371933277"] = 17,
    ["rbxassetid://137007125977081"] = 17,
    ["rbxassetid://137158942150039"] = 17,
    ["rbxassetid://137451357351000"] = 17,
    ["rbxassetid://137530262243994"] = 17,
    ["rbxassetid://137638103122538"] = 17,
    ["rbxassetid://137654778575373"] = 17,
    ["rbxassetid://137816914375923"] = 17,
    ["rbxassetid://137844586546509"] = 17,
    ["rbxassetid://137865634124104"] = 17,
    ["rbxassetid://137890465172565"] = 17,
    ["rbxassetid://137919635923292"] = 22,
    ["rbxassetid://138169151223960"] = 17,
    ["rbxassetid://138489871864252"] = 22,
    ["rbxassetid://138626478088332"] = 21,
    ["rbxassetid://138826705245289"] = 16,
    ["rbxassetid://138826758216894"] = 21,
    ["rbxassetid://139105275342427"] = 17,
    ["rbxassetid://139254982813267"] = 17,
    ["rbxassetid://139280845242450"] = 17,
    ["rbxassetid://139280948741186"] = 22,
    ["rbxassetid://139336998459583"] = 17,
    ["rbxassetid://139392154233011"] = 17,
    ["rbxassetid://139549374008097"] = 22,
    ["rbxassetid://139556003259624"] = 17,
    ["rbxassetid://139595086016682"] = 17,
    ["rbxassetid://139833047658617"] = 22,
    ["rbxassetid://139899183181812"] = 22,
    ["rbxassetid://139925289573265"] = 22,
    ["rbxassetid://139956651661073"] = 17,
    ["rbxassetid://140288981168553"] = 17,
    ["rbxassetid://140487289646129"] = 6,
    ["rbxassetid://140557689031802"] = 17,
    ["rbxassetid://140588454098230"] = 22,
    ["rbxassetid://140595869234331"] = 17,
    ["rbxassetid://140597320237985"] = 17,
    ["rbxassetid://70394890117813"] = 17,
    ["rbxassetid://70619893542373"] = 17,
    ["rbxassetid://70890372338556"] = 17,
    ["rbxassetid://71186534081075"] = 17,
    ["rbxassetid://71262912144187"] = 17,
    ["rbxassetid://71784337627181"] = 22,
    ["rbxassetid://71962949153281"] = 17,
    ["rbxassetid://72063002791216"] = 17,
    ["rbxassetid://72157009600725"] = 25,
    ["rbxassetid://72211631197834"] = 4,
    ["rbxassetid://72249315151281"] = 17,
    ["rbxassetid://72343192576784"] = 17,
    ["rbxassetid://72467492674240"] = 17,
    ["rbxassetid://72475960800126"] = 17,
    ["rbxassetid://72548435296350"] = 22,
    ["rbxassetid://72575786212990"] = 22,
    ["rbxassetid://72932825817330"] = 17,
    ["rbxassetid://72933571933445"] = 17,
    ["rbxassetid://73243807139765"] = 17,
    ["rbxassetid://73456086297777"] = 17,
    ["rbxassetid://73717793648274"] = 17,
    ["rbxassetid://73845601879862"] = 17,
    ["rbxassetid://73851146667806"] = 17,
    ["rbxassetid://74130815091898"] = 17,
    ["rbxassetid://74145636023952"] = 16,
    ["rbxassetid://74462027106510"] = 17,
    ["rbxassetid://74468926196748"] = 17,
    ["rbxassetid://74550814125588"] = 22,
    ["rbxassetid://74580112757879"] = 22,
    ["rbxassetid://74676954665401"] = 17,
    ["rbxassetid://74824009481622"] = 17,
    ["rbxassetid://74958629631023"] = 17,
    ["rbxassetid://75337033003776"] = 22,
    ["rbxassetid://75425383606016"] = 6,
    ["rbxassetid://75909247131455"] = 17,
    ["rbxassetid://75961842881209"] = 6,
    ["rbxassetid://75985296743258"] = 22,
    ["rbxassetid://76118979198026"] = 16,
    ["rbxassetid://76270924601362"] = 17,
    ["rbxassetid://76273288374330"] = 17,
    ["rbxassetid://76372421343979"] = 21,
    ["rbxassetid://76470718091246"] = 17,
    ["rbxassetid://76519264603956"] = 16,
    ["rbxassetid://76957377224584"] = 17,
    ["rbxassetid://77161050579175"] = 16,
    ["rbxassetid://77200218033775"] = 17,
    ["rbxassetid://77284264481284"] = 22,
    ["rbxassetid://77583711129628"] = 22,
    ["rbxassetid://77694572381701"] = 17,
    ["rbxassetid://77833820443705"] = 16,
    ["rbxassetid://78255783808898"] = 17,
    ["rbxassetid://78300807981222"] = 17,
    ["rbxassetid://78362143871493"] = 17,
    ["rbxassetid://78453184359132"] = 17,
    ["rbxassetid://78540777177847"] = 17,
    ["rbxassetid://78540995456941"] = 17,
    ["rbxassetid://78578012001859"] = 17,
    ["rbxassetid://78636717376287"] = 17,
    ["rbxassetid://79037514387169"] = 21,
    ["rbxassetid://79086910454958"] = 22,
    ["rbxassetid://79271374075726"] = 21,
    ["rbxassetid://79436586236026"] = 22,
    ["rbxassetid://79568627671998"] = 22,
    ["rbxassetid://79718433989469"] = 21,
    ["rbxassetid://80150988150906"] = 22,
    ["rbxassetid://80465501985014"] = 17,
    ["rbxassetid://80504019426174"] = 22,
    ["rbxassetid://80552926761100"] = 16,
    ["rbxassetid://80744488373239"] = 17,
    ["rbxassetid://80809423999548"] = 22,
    ["rbxassetid://81007905598407"] = 17,
    ["rbxassetid://81210313723714"] = 17,
    ["rbxassetid://81252522461415"] = 17,
    ["rbxassetid://81426568444338"] = 21,
    ["rbxassetid://81630213087988"] = 21,
    ["rbxassetid://81666883735259"] = 22,
    ["rbxassetid://81708642912019"] = 17,
    ["rbxassetid://81747738306948"] = 17,
    ["rbxassetid://81786875517933"] = 17,
    ["rbxassetid://81953935260783"] = 17,
    ["rbxassetid://81971779090581"] = 17,
    ["rbxassetid://82149987460883"] = 17,
    ["rbxassetid://82400997593751"] = 22,
    ["rbxassetid://82405138302195"] = 17,
    ["rbxassetid://82541714192027"] = 17,
    ["rbxassetid://82952123018614"] = 17,
    ["rbxassetid://83430571986421"] = 17,
    ["rbxassetid://83782195794718"] = 17,
    ["rbxassetid://84013110352954"] = 17,
    ["rbxassetid://84039122607068"] = 17,
    ["rbxassetid://84063127664904"] = 17,
    ["rbxassetid://84080901810314"] = 22,
    ["rbxassetid://84089621542495"] = 17,
    ["rbxassetid://84359513001979"] = 22,
    ["rbxassetid://84442064935420"] = 21,
    ["rbxassetid://84547415708554"] = 22,
    ["rbxassetid://84602523265622"] = 22,
    ["rbxassetid://84737448668938"] = 17,
    ["rbxassetid://84748541392167"] = 17,
    ["rbxassetid://84784070267976"] = 17,
    ["rbxassetid://84870056161157"] = 17,
    ["rbxassetid://84970451790939"] = 17,
    ["rbxassetid://84989753395518"] = 16,
    ["rbxassetid://85024950165903"] = 17,
    ["rbxassetid://85068785050521"] = 22,
    ["rbxassetid://85148168523745"] = 22,
    ["rbxassetid://85177207486680"] = 17,
    ["rbxassetid://85699847295318"] = 17,
    ["rbxassetid://85759204747311"] = 17,
    ["rbxassetid://85887300265206"] = 21,
    ["rbxassetid://85938446097801"] = 17,
    ["rbxassetid://86045680364061"] = 17,
    ["rbxassetid://86109053396974"] = 16,
    ["rbxassetid://86293749971049"] = 16,
    ["rbxassetid://86313167610953"] = 17,
    ["rbxassetid://86362077638309"] = 17,
    ["rbxassetid://86403201308630"] = 17,
    ["rbxassetid://86463226245064"] = 17,
    ["rbxassetid://86519781516542"] = 22,
    ["rbxassetid://86568794583359"] = 16,
    ["rbxassetid://86618245908620"] = 17,
    ["rbxassetid://86626502434817"] = 17,
    ["rbxassetid://86653872725659"] = 17,
    ["rbxassetid://86918383671100"] = 22,
    ["rbxassetid://87128908378141"] = 17,
    ["rbxassetid://87284059970791"] = 17,
    ["rbxassetid://87472283043607"] = 16,
    ["rbxassetid://87481059409847"] = 17,
    ["rbxassetid://87792276744794"] = 16,
    ["rbxassetid://87794951519046"] = 17,
    ["rbxassetid://87805684702890"] = 17,
    ["rbxassetid://88005970155216"] = 17,
    ["rbxassetid://88215274584883"] = 17,
    ["rbxassetid://88849926869776"] = 22,
    ["rbxassetid://88911658010897"] = 25,
    ["rbxassetid://88959376775614"] = 17,
    ["rbxassetid://89009042593684"] = 17,
    ["rbxassetid://89041939287063"] = 17,
    ["rbxassetid://89050244840723"] = 17,
    ["rbxassetid://89092734635186"] = 25,
    ["rbxassetid://89368678158919"] = 17,
    ["rbxassetid://89394375446962"] = 17,
    ["rbxassetid://89465788843211"] = 21,
    ["rbxassetid://89537672683114"] = 22,
    ["rbxassetid://89550137926236"] = 16,
    ["rbxassetid://89582140026963"] = 17,
    ["rbxassetid://89652378115594"] = 25,
    ["rbxassetid://89888040037257"] = 17,
    ["rbxassetid://89891294371787"] = 17,
    ["rbxassetid://89977758316911"] = 17,
    ["rbxassetid://90157434123044"] = 17,
    ["rbxassetid://90781290293652"] = 25,
    ["rbxassetid://90926294837924"] = 17,
    ["rbxassetid://90981055255583"] = 4,
    ["rbxassetid://91450617822876"] = 17,
    ["rbxassetid://91633722898431"] = 17,
    ["rbxassetid://91853462087608"] = 17,
    ["rbxassetid://91885511994468"] = 16,
    ["rbxassetid://91916094481547"] = 17,
    ["rbxassetid://91990544700842"] = 22,
    ["rbxassetid://92045676155777"] = 22,
    ["rbxassetid://92081142332466"] = 25,
    ["rbxassetid://92313325989822"] = 17,
    ["rbxassetid://92595499555055"] = 25,
    ["rbxassetid://92698956945928"] = 22,
    ["rbxassetid://92796867394473"] = 22,
    ["rbxassetid://92966188946988"] = 16,
    ["rbxassetid://92971045548861"] = 17,
    ["rbxassetid://93028763593631"] = 17,
    ["rbxassetid://93265997037616"] = 17,
    ["rbxassetid://93429614171877"] = 17,
    ["rbxassetid://93433910019592"] = 17,
    ["rbxassetid://93623649598782"] = 22,
    ["rbxassetid://93751660565233"] = 17,
    ["rbxassetid://93880529089759"] = 22,
    ["rbxassetid://93901924492394"] = 17,
    ["rbxassetid://93990332433987"] = 17,
    ["rbxassetid://94093535314017"] = 17,
    ["rbxassetid://94347210073500"] = 17,
    ["rbxassetid://94503127884527"] = 17,
    ["rbxassetid://94588892125071"] = 22,
    ["rbxassetid://94781366396051"] = 16,
    ["rbxassetid://95002584969527"] = 6,
    ["rbxassetid://95077220586856"] = 17,
    ["rbxassetid://95145258027958"] = 17,
    ["rbxassetid://95295463826732"] = 22,
    ["rbxassetid://95421145178968"] = 16,
    ["rbxassetid://95437415745300"] = 17,
    ["rbxassetid://95494223368246"] = 17,
    ["rbxassetid://95518010513564"] = 17,
    ["rbxassetid://95565644999250"] = 17,
    ["rbxassetid://95738371652260"] = 22,
    ["rbxassetid://95836193950062"] = 17,
    ["rbxassetid://95852624447551"] = 16,
    ["rbxassetid://95901746347992"] = 25,
    ["rbxassetid://96047028540271"] = 17,
    ["rbxassetid://96151127318574"] = 22,
    ["rbxassetid://96185406489877"] = 22,
    ["rbxassetid://96327114254575"] = 22,
    ["rbxassetid://96397814657727"] = 25,
    ["rbxassetid://96433049733325"] = 17,
    ["rbxassetid://96466374346823"] = 25,
    ["rbxassetid://96513213736303"] = 22,
    ["rbxassetid://97207871642820"] = 22,
    ["rbxassetid://97215638330770"] = 22,
    ["rbxassetid://97504088532041"] = 21,
    ["rbxassetid://97737965308086"] = 17,
    ["rbxassetid://97868312130612"] = 22,
    ["rbxassetid://97901397284754"] = 22,
    ["rbxassetid://97972100634587"] = 17,
    ["rbxassetid://98365018553171"] = 22,
    ["rbxassetid://98577624776161"] = 22,
    ["rbxassetid://98783064085844"] = 22,
    ["rbxassetid://98816967040955"] = 17,
    ["rbxassetid://98845475810982"] = 17,
    ["rbxassetid://98920127166691"] = 17,
    ["rbxassetid://99013808819856"] = 17,
    ["rbxassetid://99180695169591"] = 17,
    ["rbxassetid://99205259396653"] = 21,
    ["rbxassetid://99249148382757"] = 17,
    ["rbxassetid://99306590177523"] = 17,
    ["rbxassetid://99451940496871"] = 17,
    ["rbxassetid://99516000246972"] = 17,
    ["rbxassetid://99710481887795"] = 22,
    ["rbxassetid://99731350629462"] = 17,
    ["rbxassetid://99818212174021"] = 16,
    ["rbxassetid://99920923658527"] = 17,
    ["rbxassetid://99942519870898"] = 22,
    ["rbxassetid://99998493953272"] = 17,
}
Combat.TBOAnimationCount = 542
Combat.TBOGroundOnly = {["rbxassetid://72467492674240"] = true}
Combat.TBOAirOnly = {["rbxassetid://122573730331631"] = true}

-- Wiki-derived catalog: Jujutsu Shenanigans Wiki contributors; adapted labels and joins.
-- Source: https://jujutsushenaniganswiki.com/wiki/ (original: https://jujutsu-shenanigans.fandom.com/)
-- Data license: https://creativecommons.org/licenses/by-sa/4.0/ ; native IDs: supplied jjs.rbxl.
Combat.Roster={["Profiles"]={["Gojo/Gojo"]={["Name"]="Gojo",["Character"]="Gojo",["Service"]="GojoService",["Block"]="unknown",["Range"]=10.0,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Gojo/ReversalRed"]={["Name"]="Reversal Red",["Character"]="Gojo",["Service"]="ReversalRedService",["Block"]="block",["AirBlock"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Red"}},["Gojo/LapseBlue"]={["Name"]="Lapse Blue",["Character"]="Gojo",["Service"]="LapseBlueService",["Block"]="all",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Gojo/RapidPunches"]={["Name"]="Rapid Punches",["Character"]="Gojo",["Service"]="RapidPunchesService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Gojo/TwofoldKick"]={["Name"]="Twofold Kick",["Character"]="Gojo",["Service"]="TwofoldKickService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing2"}},["Gojo/InfiniteVoid"]={["Name"]="Infinite Void",["Character"]="Gojo",["Service"]="InfiniteVoidService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Gojo/HollowPurple"]={["Name"]="Hollow Purple",["Character"]="Gojo",["Service"]="HollowPurpleService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Gojo/LapseBlueMax"]={["Name"]="Lapse Blue MAX",["Character"]="Gojo",["Service"]="LapseBlueMaxService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Gojo/ReversalRedMax"]={["Name"]="Reversal Red MAX",["Character"]="Gojo",["Service"]="ReversalRedMaxService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Fire","Red","Swing"}},["Itadori/Itadori"]={["Name"]="Itadori",["Character"]="Itadori",["Service"]="ItadoriService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Itadori/CrushingBlow"]={["Name"]="Crushing Blow",["Character"]="Itadori",["Service"]="CrushingBlowService",["Block"]="none",["AirBlock"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Itadori/DivergentFist"]={["Name"]="Divergent Fist",["Character"]="Itadori",["Service"]="DivergentFistService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Itadori/ManjiKick"]={["Name"]="Manji Kick",["Character"]="Itadori",["Service"]="ManjiKickService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slam","Startup","Swing"}},["Itadori/CursedStrikes"]={["Name"]="Cursed Strikes",["Character"]="Itadori",["Service"]="CursedStrikesService",["Block"]="all",["AirBlock"]="none",["Range"]=17,["Height"]=13.0,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Swing"}},["Itadori/MalevolantShrine"]={["Name"]="Malevolent Shrine",["Character"]="Itadori",["Service"]="MalevolantShrineService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Itadori/FlameArrow"]={["Name"]="Open",["Character"]="Itadori",["Service"]="FlameArrowService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Fire"}},["Itadori/Rush"]={["Name"]="Rush",["Character"]="Itadori",["Service"]="RushService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Itadori/Dismantle"]={["Name"]="Dismantle",["Character"]="Itadori",["Service"]="DismantleService",["Block"]="all",["AirBlock"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Swing"}},["Hakari/Hakari"]={["Name"]="Hakari",["Character"]="Hakari",["Service"]="HakariService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing","Swing2"}},["Hakari/ShutterDoors"]={["Name"]="Shutter Doors",["Character"]="Hakari",["Service"]="ShutterDoorService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Hakari/ReserveBall"]={["Name"]="Reserve Balls",["Character"]="Hakari",["Service"]="ReserveBallService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Fire","Swing"}},["Hakari/RoughEnergy"]={["Name"]="Rough Energy",["Character"]="Hakari",["Service"]="RoughEnergyService",["Block"]="none",["AirBlock"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup","Swing"}},["Hakari/FeverBreaker"]={["Name"]="Fever Breaker",["Character"]="Hakari",["Service"]="FeverBreakerService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup","Swing"}},["Hakari/LuckyVolley"]={["Name"]="Lucky Volley",["Character"]="Hakari",["Service"]="LuckyVolleyService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Hakari/LuckyRushdown"]={["Name"]="Lucky Rushdown",["Character"]="Hakari",["Service"]="LuckyRushdownService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Hakari/OverLuck"]={["Name"]="Overwhelming Luck",["Character"]="Hakari",["Service"]="OverLuckService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Charge","Dash","Swing"}},["Hakari/EnergySurge"]={["Name"]="Energy Surge",["Character"]="Hakari",["Service"]="EnergySurgeService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=true,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Megumi/Megumi"]={["Name"]="Megumi",["Character"]="Megumi",["Service"]="MegumiService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Megumi/RabbitEscape"]={["Name"]="Rabbit Escape",["Character"]="Megumi",["Service"]="RabbitEscapeService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Megumi/Nue"]={["Name"]="Nue",["Character"]="Megumi",["Service"]="NueService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Megumi/Toad"]={["Name"]="Toad",["Character"]="Megumi",["Service"]="ToadService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Megumi/DivineDog"]={["Name"]="Divine Dog: Totality",["Character"]="Megumi",["Service"]="DivineDogService",["Block"]="all",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Slash"}},["Megumi/ShadowSwarm"]={["Name"]="Shadow Swarm",["Character"]="Megumi",["Service"]="ShadowSwarmService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Start","Swing"}},["Megumi/MaxElephant"]={["Name"]="Max Elephant",["Character"]="Megumi",["Service"]="MaxElephantService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Megumi/GreatSerpent"]={["Name"]="Great Serpent",["Character"]="Megumi",["Service"]="GreatSerpentService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Megumi/MahoragaUse"]={["Name"]="Mahoraga",["Character"]="Megumi",["Service"]="MahoragaUseService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Megumi/Mahoraga"]={["Name"]="Mahoraga",["Character"]="Megumi",["Service"]="MahoragaService",["Block"]="unknown",["Range"]=14.0,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Megumi/DivinePummel"]={["Name"]="Divine Pummel",["Character"]="Megumi",["Service"]="DivinePummelService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Megumi/GroundPitch"]={["Name"]="Ground Pitch",["Character"]="Megumi",["Service"]="GroundPitchService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Megumi/Earthquake"]={["Name"]="Earthquake",["Character"]="Megumi",["Service"]="EarthquakeService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=true,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Megumi/Adaptation"]={["Name"]="Adaptation",["Character"]="Megumi",["Service"]="AdaptationService",["Block"]="counter",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Mahito/Mahito"]={["Name"]="Mahito",["Character"]="Mahito",["Service"]="MahitoService",["Block"]="unknown",["Range"]=10.0,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Swing","Swing2"}},["Mahito/Stockpile"]={["Name"]="Stockpile",["Character"]="Mahito",["Service"]="StockpileService",["Block"]="semi",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Mahito/Soulfire"]={["Name"]="Soul Fire",["Character"]="Mahito",["Service"]="SoulfireService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Fire"}},["Mahito/FocusStrike"]={["Name"]="Focus Strike",["Character"]="Mahito",["Service"]="FocusStrikeService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Mahito/BodyRepel"]={["Name"]="Body Repel",["Character"]="Mahito",["Service"]="BodyRepelService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=true,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Fire","Start"}},["Mahito/WideSPStrike"]={["Name"]="Widespread Strikes",["Character"]="Mahito",["Service"]="WideSPStrikesService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Mahito/FaceBlitz"]={["Name"]="Face Blitz",["Character"]="Mahito",["Service"]="FaceBlitzService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Mahito/CrushingRushdown"]={["Name"]="Crushing Rushdown",["Character"]="Mahito",["Service"]="CrushingRushdownService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Mahito/HeadSplitter"]={["Name"]="Head Splitter",["Character"]="Mahito",["Service"]="HeadSplitterService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Mahito/IdleTransfiguration"]={["Name"]="Idle Transfiguration",["Character"]="Mahito",["Service"]="IdleTransfigurationService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Start"}},["Mahito/BodyDisfigure"]={["Name"]="BodyDisfigure",["Character"]="Mahito",["Service"]="BodyDisfigureService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Swing"}},["Mahito/SelfPerfection"]={["Name"]="SelfPerfection",["Character"]="Mahito",["Service"]="SelfPerfectionService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Mahito/SpikeWrath"]={["Name"]="Spike Wrath",["Character"]="Mahito",["Service"]="SpikeWrathService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=true,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start","Startup"}},["Choso/Choso"]={["Name"]="Choso",["Character"]="Choso",["Service"]="ChosoService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Choso/Supernova"]={["Name"]="Supernova",["Character"]="Choso",["Service"]="SupernovaService",["Block"]="counter",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Choso/RedScale"]={["Name"]="Flowing Red Scale",["Character"]="Choso",["Service"]="RedScaleService",["Block"]="all",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Swing"}},["Choso/PiercingBlood"]={["Name"]="Piercing Blood",["Character"]="Choso",["Service"]="PiercingBloodService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Startup"}},["Choso/BloodEdge"]={["Name"]="Blood Edge",["Character"]="Choso",["Service"]="BloodEdgeService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Swing"}},["Choso/SlicingExorcism"]={["Name"]="Slicing Exorcism",["Character"]="Choso",["Service"]="SlicingExorcismService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Choso/BloodRain"]={["Name"]="Blood Rain",["Character"]="Choso",["Service"]="BloodRainService",["Block"]="all",["Range"]=35,["Height"]=35,["Radial"]=true,["Ranged"]=false,["Window"]=1.05,["Phases"]={"Startup","Rain"}},["Choso/WingKing"]={["Name"]="Wing King",["Character"]="Choso",["Service"]="WingKingService",["Block"]="semi",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Dash","Swing","Swing2"}},["Choso/PlasmaWave"]={["Name"]="Plasma Wave",["Character"]="Choso",["Service"]="PlasmaWaveService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Fire","Startup"}},["Todo/Todo"]={["Name"]="Boogie Woogie",["Character"]="Todo",["Service"]="TodoService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Todo/SwiftKick"]={["Name"]="Swift Kick",["Character"]="Todo",["Service"]="SwiftKickService",["Block"]="semi",["Range"]=17,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Start","Swing"}},["Todo/BruteForce"]={["Name"]="Brute Force",["Character"]="Todo",["Service"]="BruteForceService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Todo/PebbleThrow"]={["Name"]="Pebble Throw",["Character"]="Todo",["Service"]="PebbleThrowService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Todo/ElbowDrop"]={["Name"]="Elbow Drop",["Character"]="Todo",["Service"]="ElbowDropService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Todo/IdolDebut"]={["Name"]="Idol's Debut",["Character"]="Todo",["Service"]="IdolDebutService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Todo/ClimaxJump"]={["Name"]="Climax Jumping",["Character"]="Todo",["Service"]="ClimaxJumpService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Todo/Dreams"]={["Name"]="Dreams",["Character"]="Todo",["Service"]="DreamsService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start","Swing"}},["Todo/Brothers"]={["Name"]="Brothers",["Character"]="Todo",["Service"]="BrothersService",["Block"]="counter",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Heian/Heian"]={["Name"]="Heian",["Character"]="Heian",["Service"]="HeianService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing","Swing2"}},["Heian/DismantleV2"]={["Name"]="Dismantle Net",["Character"]="Heian",["Service"]="DismantleV2Service",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Heian/FurnaceArrow"]={["Name"]="Open FURNACE",["Character"]="Heian",["Service"]="FurnaceArrowService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Fire"}},["Heian/CleaveRush"]={["Name"]="Cleave Rush",["Character"]="Heian",["Service"]="CleaveRushService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Start"}},["Heian/Kamutoke"]={["Name"]="Kamutoke",["Character"]="Heian",["Service"]="KamutokeService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Strike"}},["Locust/Locust"]={["Name"]="Locust",["Character"]="Locust",["Service"]="LocustService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Locust/BlackMucus"]={["Name"]="Black Mucus",["Character"]="Locust",["Service"]="BlackMucusService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Fire","Start"}},["Locust/Clever"]={["Name"]="Clever",["Character"]="Locust",["Service"]="CleverService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Locust/CrushJaw"]={["Name"]="Crushing Jaws",["Character"]="Locust",["Service"]="CrushJawService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Locust/WingThrow"]={["Name"]="Wing Throw",["Character"]="Locust",["Service"]="WingThrowService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Hiromi/Hiromi"]={["Name"]="No Escape",["Character"]="Hiromi",["Service"]="HiromiService",["Block"]="all",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Dash","Startup","Swing","Swing2"}},["Hiromi/ExtendSwing"]={["Name"]="Extended Swings",["Character"]="Hiromi",["Service"]="ExtendSwingService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Hiromi/JusticeServed"]={["Name"]="Justice Served",["Character"]="Hiromi",["Service"]="JusticeServedService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Hiromi/PressingCharges"]={["Name"]="Pressing Charges",["Character"]="Hiromi",["Service"]="PressingChargesService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup"}},["Hiromi/JudgeReach"]={["Name"]="Judgement's Reach",["Character"]="Hiromi",["Service"]="JudgeReachService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Startup"}},["Hiromi/Execution"]={["Name"]="Execution",["Character"]="Hiromi",["Service"]="ExecutionService",["Block"]="none",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Charge"}},["Hiromi/FinalJudgement"]={["Name"]="Final Judgement",["Character"]="Hiromi",["Service"]="FinalJudgementService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Charge","Dash","Swing"}},["Hiromi/Verdict"]={["Name"]="Verdict",["Character"]="Hiromi",["Service"]="VerdictService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Hiromi/TripleSentence"]={["Name"]="Triple Sentence",["Character"]="Hiromi",["Service"]="TripleSentenceService",["Block"]="semi",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Yuki/Yuki"]={["Name"]="Yuki",["Character"]="Yuki",["Service"]="YukiService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Yuki/GarudaRebound"]={["Name"]="Garuda Rebound",["Character"]="Yuki",["Service"]="GarudaReboundService",["Block"]="all",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Startup"}},["Yuki/MassBreaker"]={["Name"]="Mass Breaker",["Character"]="Yuki",["Service"]="MassBreakerService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup"}},["Yuki/RisingRage"]={["Name"]="Rising Rage",["Character"]="Yuki",["Service"]="RisingRageService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup"}},["Yuki/GarudaStab"]={["Name"]="Garuda Stab",["Character"]="Yuki",["Service"]="GarudaStabService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing"}},["Yuta/Yuta"]={["Name"]="Yuta",["Character"]="Yuta",["Service"]="YutaService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Yuta/Revolve"]={["Name"]="Revolve",["Character"]="Yuta",["Service"]="RevolveService",["Block"]="unknown",["Range"]=11.0,["Height"]=11.0,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/ResoluteSlash"]={["Name"]="Resolute Slash",["Character"]="Yuta",["Service"]="ResoluteSlashService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash","Swing","Swing2"}},["Yuta/Veilstep"]={["Name"]="Veilstep",["Character"]="Yuta",["Service"]="VeilstepService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/SeveringPath"]={["Name"]="Severing Path",["Character"]="Yuta",["Service"]="SeveringPathService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start","Swing"}},["Yuta/Outburst"]={["Name"]="Outburst",["Character"]="Yuta",["Service"]="OutburstService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash"}},["Yuta/EnergyRipple"]={["Name"]="Energy Ripple",["Character"]="Yuta",["Service"]="EnergyRippleService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/RikaDownslam"]={["Name"]="Rika Downslam",["Character"]="Yuta",["Service"]="RikaDownslamService",["Block"]="none",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/RikaLaunch"]={["Name"]="RikaLaunch",["Character"]="Yuta",["Service"]="RikaLaunchService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/RikaHaymaker"]={["Name"]="Rika Haymaker",["Character"]="Yuta",["Service"]="RikaHaymakerService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Yuta/RikaLoveBeam"]={["Name"]="True Love Beam",["Character"]="Yuta",["Service"]="RikaLoveBeamService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Charge"}},["Yuta/RikaSlam"]={["Name"]="Rika Slam",["Character"]="Yuta",["Service"]="RikaSlamService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/RikaGrab"]={["Name"]="RikaGrab",["Character"]="Yuta",["Service"]="RikaGrabService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/RikaThrow"]={["Name"]="Rika Throw",["Character"]="Yuta",["Service"]="RikaThrowService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/LoveBeam"]={["Name"]="True Love Beam",["Character"]="Yuta",["Service"]="LoveBeamService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/MutualLove"]={["Name"]="Authentic Mutual Love",["Character"]="Yuta",["Service"]="MutualLoveService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Yuta/ElbowRush"]={["Name"]="Elbow Rush",["Character"]="Yuta",["Service"]="ElbowRushService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Yuta/Copy"]={["Name"]="Copy",["Character"]="Yuta",["Service"]="CopyService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Goku/Goku"]={["Name"]="Goku",["Character"]="Goku",["Service"]="GokuService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Goku/Kamehameha"]={["Name"]="Kamehameha",["Character"]="Goku",["Service"]="KamehamehaService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Shoot"}},["Goku/StaffUppercut"]={["Name"]="Staff Uppercut",["Character"]="Goku",["Service"]="StaffUppercutService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Goku/StaffExtend"]={["Name"]="Staff Extend",["Character"]="Goku",["Service"]="StaffExtendService",["Block"]="none",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start","Swing"}},["Goku/KiSpam"]={["Name"]="Ki Spam",["Character"]="Goku",["Service"]="KiSpamService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Shoot"}},["Charles/Charles"]={["Name"]="Charles",["Character"]="Charles",["Service"]="CharlesService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing","Swing2"}},["Charles/Despair"]={["Name"]="Despair",["Character"]="Charles",["Service"]="DespairService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing","Swing2"}},["Charles/ShutUp"]={["Name"]="Shut Up!",["Character"]="Charles",["Service"]="ShutUpService",["Block"]="block",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing"}},["Charles/EyeCatch"]={["Name"]="Eye Catching",["Character"]="Charles",["Service"]="EyeCatchService",["Block"]="counter",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Charles/Sacrilegious"]={["Name"]="Sacrilege",["Character"]="Charles",["Service"]="SacrilegiousService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup"}},["Mechamaru/Mechamaru"]={["Name"]="Offload",["Character"]="Mechamaru",["Service"]="MechamaruService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Mechamaru/Absolute"]={["Name"]="Absolute",["Character"]="Mechamaru",["Service"]="MechamaruService",["Block"]="unknown",["Range"]=13.0,["Height"]=13.0,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Mechamaru/UltraSpin"]={["Name"]="Ultra Spin",["Character"]="Mechamaru",["Service"]="UltraSpinService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Mechamaru/UltraCannon"]={["Name"]="Ultra Cannon",["Character"]="Mechamaru",["Service"]="UltraCannonService",["Block"]="all",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Start"}},["Mechamaru/BoostOn"]={["Name"]="Boost On",["Character"]="Mechamaru",["Service"]="BoostOnService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Blast","Start"}},["Mechamaru/HeatEmission"]={["Name"]="Heat Emission",["Character"]="Mechamaru",["Service"]="HeatEmissionService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=true,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Blast","Start"}},["Mechamaru/MiracleCannon"]={["Name"]="Miracle Cannon",["Character"]="Mechamaru",["Service"]="MiracleCannonService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Charge"}},["Mechamaru/PigeonViola"]={["Name"]="Pigeon Viola",["Character"]="Mechamaru",["Service"]="PigeonViolaService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Shoot","Start"}},["Mechamaru/AbsoluteDestruction"]={["Name"]="Absolute Destruction",["Character"]="Mechamaru",["Service"]="AbsoluteDestructionService",["Block"]="none",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slam","Start"}},["Mechamaru/TechniqueCharge"]={["Name"]="Technique Charge",["Character"]="Mechamaru",["Service"]="TechniqueChargeService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Naoya/Naoya"]={["Name"]="Naoya",["Character"]="Naoya",["Service"]="NaoyaService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Naoya/Bleedout"]={["Name"]="Bleedout",["Character"]="Naoya",["Service"]="BleedoutService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Naoya/DecisiveStrike"]={["Name"]="Decisive Strike",["Character"]="Naoya",["Service"]="DecisiveStrikeService",["Block"]="block",["AirBlock"]="block",["Range"]=17,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Windup"}},["Naoya/ProjectionBreaker"]={["Name"]="Projection Breaker",["Character"]="Naoya",["Service"]="ProjectionBreakerService",["Block"]="block",["Range"]=17,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Naoya/CursoryImpact"]={["Name"]="Cursory Impact",["Character"]="Naoya",["Service"]="CursoryImpactService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing","Swing2"}},["Naoya/TopSpeed"]={["Name"]="Top Speed",["Character"]="Naoya",["Service"]="TopSpeedService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Naoya/TendrilGrab"]={["Name"]="Tendril Grab",["Character"]="Naoya",["Service"]="TendrilGrabService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Naoya/TimeCellMoonPalace"]={["Name"]="TimeCellMoonPalace",["Character"]="Naoya",["Service"]="TimeCellMoonPalaceService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Naoya/FlashFreezing"]={["Name"]="Flash Freezing",["Character"]="Naoya",["Service"]="FlashFreezingService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Nanami/Nanami"]={["Name"]="Ratio Point",["Character"]="Nanami",["Service"]="NanamiService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Nanami/CleavingWhirl"]={["Name"]="Cleaving Whirlwind",["Character"]="Nanami",["Service"]="CleavingWhirlService",["Block"]="block",["Range"]=17,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Slash","Start","Swing"}},["Nanami/SeveranceKick"]={["Name"]="Severance Kick",["Character"]="Nanami",["Service"]="SeveranceKickService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Nanami/BluntCut"]={["Name"]="Blunt Cut",["Character"]="Nanami",["Service"]="BluntCutService",["Block"]="block",["Range"]=13.0,["Height"]=13.0,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Charge","Dash","Slam","Start","Swing2"}},["Nanami/Stabilize"]={["Name"]="Stabilize",["Character"]="Nanami",["Service"]="StabilizeService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Nanami/Collapse"]={["Name"]="Collapse",["Character"]="Nanami",["Service"]="CollapseService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Nanami/Sharpen"]={["Name"]="Sharpen",["Character"]="Nanami",["Service"]="SharpenService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash"}},["Nanami/Interrogate"]={["Name"]="Interrogate",["Character"]="Nanami",["Service"]="InterrogateService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Start","Swing"}},["Nanami/RatioBreaker"]={["Name"]="Ratio Breaker I",["Character"]="Nanami",["Service"]="RatioBreakerService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Slam","Slash","Start"}},["Haruta/Haruta"]={["Name"]="Haruta",["Character"]="Haruta",["Service"]="HarutaService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Haruta/CheapShot"]={["Name"]="Cheap Shot",["Character"]="Haruta",["Service"]="CheapShotService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Start"}},["Haruta/Backstab"]={["Name"]="Backstab",["Character"]="Haruta",["Service"]="BackstabService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Haruta/Ambush"]={["Name"]="Ambush",["Character"]="Haruta",["Service"]="AmbushService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Haruta/Trip"]={["Name"]="Trip",["Character"]="Haruta",["Service"]="TripService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Haruta/AnkleCutter"]={["Name"]="Ankle Cutter",["Character"]="Haruta",["Service"]="AnkleCutterService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Start"}},["Haruta/HighTime"]={["Name"]="High Time",["Character"]="Haruta",["Service"]="HighTimeService",["Block"]="all",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing"}},["Hanami/Hanami"]={["Name"]="Hanami",["Character"]="Hanami",["Service"]="HanamiService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Hanami/RootSwarm"]={["Name"]="Root Swarm",["Character"]="Hanami",["Service"]="RootSwarmService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=true,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Hanami/DefenseResponse"]={["Name"]="Defense Response",["Character"]="Hanami",["Service"]="DefenseResponseService",["Block"]="none",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Hanami/SurgingThorns"]={["Name"]="Surging Thorns",["Character"]="Hanami",["Service"]="SurgingThornsService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Hanami/BudShot"]={["Name"]="Bud Shot",["Character"]="Hanami",["Service"]="BudShotService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Startup"}},["Hanami/CursedBuds"]={["Name"]="Cursed Buds",["Character"]="Hanami",["Service"]="CursedBudsService",["Block"]="semi",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Start"}},["Hanami/FlowerBeam"]={["Name"]="Flower Beam",["Character"]="Hanami",["Service"]="FlowerBeamService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Windup"}},["Hanami/SeaOfBranches"]={["Name"]="SeaOfBranches",["Character"]="Hanami",["Service"]="SeaOfBranchesService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Hanami/RootRampage"]={["Name"]="Root Rampage",["Character"]="Hanami",["Service"]="RootRampageService",["Block"]="semi",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Windup"}},["Hanami/FlowerField"]={["Name"]="Flower Field",["Character"]="Hanami",["Service"]="FlowerFieldService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Windup"}},["MeiMei/MeiMei"]={["Name"]="MeiMei",["Character"]="MeiMei",["Service"]="MeiMeiService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["MeiMei/ImpetusUpdraft"]={["Name"]="Impetus Updraft",["Character"]="MeiMei",["Service"]="ImpetusUpdraftService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash"}},["MeiMei/Circling"]={["Name"]="Circling",["Character"]="MeiMei",["Service"]="CirclingService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["MeiMei/Murmurate"]={["Name"]="Murmurate",["Character"]="MeiMei",["Service"]="MurmurateService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Slash","Start"}},["MeiMei/BirdControl"]={["Name"]="Bird Control",["Character"]="MeiMei",["Service"]="BirdControlService",["Block"]="all",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Ryu/Ryu"]={["Name"]="Ryu",["Character"]="Ryu",["Service"]="RyuService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Ryu/Unsatisfied"]={["Name"]="Unsatisfied",["Character"]="Ryu",["Service"]="UnsatisfiedService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup"}},["Ryu/GraniteBlast"]={["Name"]="Granite Blast",["Character"]="Ryu",["Service"]="GraniteBlastService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Fire","Startup"}},["Ryu/Appetizer"]={["Name"]="Appetizer",["Character"]="Ryu",["Service"]="AppetizerService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Fire","Startup"}},["Ryu/SecondHelping"]={["Name"]="Second Helping",["Character"]="Ryu",["Service"]="SecondHelpingService",["Block"]="none",["AirBlock"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Startup","Swing"}},["Ryu/HadNoIdea"]={["Name"]="\"I had no idea...\"",["Character"]="Ryu",["Service"]="HadNoIdeaService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup","Swing"}},["Ryu/WhatAreYouAfter"]={["Name"]="\"What are you after?\"",["Character"]="Ryu",["Service"]="WhatAreYouAfterService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup"}},["Ryu/ThisDessert"]={["Name"]="\"This is what dessert is like!\"",["Character"]="Ryu",["Service"]="ThisDessertService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup","Swing"}},["Ryu/WerentInvited"]={["Name"]="\"You weren't invited.\"",["Character"]="Ryu",["Service"]="WerentInvitedService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Charge","Dash","Startup","Swing"}},["Kurourushi/Kurourushi"]={["Name"]="Kurourushi",["Character"]="Kurourushi",["Service"]="KurourushiService",["Block"]="unknown",["Range"]=10.0,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Kurourushi/FesteringStrikes"]={["Name"]="Festering Strikes",["Character"]="Kurourushi",["Service"]="FesteringStrikesService",["Block"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash"}},["Kurourushi/Chokehold"]={["Name"]="Chokehold",["Character"]="Kurourushi",["Service"]="ChokeholdService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash","Start"}},["Kurourushi/RoachSwarm"]={["Name"]="Roach Swarm",["Character"]="Kurourushi",["Service"]="RoachSwarmService",["Block"]="none",["AirBlock"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={}},["Kurourushi/Detach"]={["Name"]="Detach",["Character"]="Kurourushi",["Service"]="DetachService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Start"}},["Reggie/Reggie"]={["Name"]="Reggie",["Character"]="Reggie",["Service"]="ReggieService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Reggie/GushingWound"]={["Name"]="Gushing Wound",["Character"]="Reggie",["Service"]="GushingWoundService",["Block"]="none",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Start"}},["Reggie/PianoDrop"]={["Name"]="Piano Drop",["Character"]="Reggie",["Service"]="PianoDropService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Reggie/Homerun"]={["Name"]="Homerun",["Character"]="Reggie",["Service"]="HomerunService",["Block"]="none",["AirBlock"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Reggie/DroneStrike"]={["Name"]="Drone Strike",["Character"]="Reggie",["Service"]="DroneStrikeService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Reggie/GarageSale"]={["Name"]="Garage Sale",["Character"]="Reggie",["Service"]="GarageSaleService",["Block"]="block",["Range"]=45,["Height"]=8,["Radial"]=false,["Ranged"]=true,["Window"]=1.05,["Phases"]={"Start"}},["Reggie/BluntTrauma"]={["Name"]="Blunt Trauma",["Character"]="Reggie",["Service"]="BluntTraumaService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slash","Start"}},["Reggie/SpeedCrash"]={["Name"]="Speed Crash",["Character"]="Reggie",["Service"]="SpeedCrashService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Reggie/Fleche"]={["Name"]="Fleche",["Character"]="Reggie",["Service"]="FlecheService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash"}},["Reggie/PoleVault"]={["Name"]="Pole Vault",["Character"]="Reggie",["Service"]="PoleVaultService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Slam"}},["Reggie/Mayhem"]={["Name"]="Mayhem",["Character"]="Reggie",["Service"]="MayhemService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Start"}},["Reggie/BigMoves"]={["Name"]="BigMoves",["Character"]="Reggie",["Service"]="BigMovesService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Reggie/Arson"]={["Name"]="Arson",["Character"]="Reggie",["Service"]="ArsonService",["Block"]="unknown",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={}},["Uro/Uro"]={["Name"]="Uro",["Character"]="Uro",["Service"]="UroService",["Block"]="unknown",["Range"]=10.0,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Swing","Swing2"}},["Uro/BlindRage"]={["Name"]="Turbulence",["Character"]="Uro",["Service"]="BlindRageService",["Block"]="semi",["AirBlock"]="semi",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Dash","Startup","Swing"}},["Uro/ThinIceBreaker"]={["Name"]="Thin Ice Breaker",["Character"]="Uro",["Service"]="ThinIceBreakerService",["Block"]="none",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Uro/SkyDistortion"]={["Name"]="Sky Distortion",["Character"]="Uro",["Service"]="SkyDistortionService",["Block"]="block",["Range"]=12,["Height"]=8,["Radial"]=false,["Ranged"]=false,["Window"]=0.85,["Phases"]={"Startup"}},["Gojo/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Gojo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Gojo/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Gojo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Gojo/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Gojo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Gojo/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Gojo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Gojo/Melee/Up"]={["Name"]="Up",["Character"]="Gojo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Gojo/Melee/Down"]={["Name"]="Down",["Character"]="Gojo",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Itadori/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Itadori",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Itadori/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Itadori",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Itadori/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Itadori",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Itadori/Melee/Up"]={["Name"]="Up",["Character"]="Itadori",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Itadori/Melee/Down"]={["Name"]="Down",["Character"]="Itadori",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Itadori/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Itadori",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Choso/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Choso",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Choso/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Choso",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Choso/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Choso",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Choso/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Choso",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Choso/Melee/Down"]={["Name"]="Down",["Character"]="Choso",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Choso/Melee/Up"]={["Name"]="Up",["Character"]="Choso",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hakari/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Hakari",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hakari/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Hakari",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hakari/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Hakari",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hakari/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Hakari",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hakari/Melee/Up"]={["Name"]="Up",["Character"]="Hakari",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hakari/Melee/Down"]={["Name"]="Down",["Character"]="Hakari",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Megumi/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Megumi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Megumi/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Megumi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Megumi/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Megumi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Megumi/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Megumi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Megumi/Melee/Up"]={["Name"]="Up",["Character"]="Megumi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Megumi/Melee/Down"]={["Name"]="Down",["Character"]="Megumi",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mahito/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Mahito",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mahito/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Mahito",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mahito/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Mahito",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mahito/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Mahito",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mahito/Melee/Up"]={["Name"]="Up",["Character"]="Mahito",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mahito/Melee/Down"]={["Name"]="Down",["Character"]="Mahito",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Todo/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Todo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Todo/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Todo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Todo/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Todo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Todo/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Todo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Todo/Melee/Up"]={["Name"]="Up",["Character"]="Todo",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Todo/Melee/Down"]={["Name"]="Down",["Character"]="Todo",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Heian/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Heian",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Heian/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Heian",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Heian/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Heian",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Heian/Melee/Up"]={["Name"]="Up",["Character"]="Heian",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Heian/Melee/Down"]={["Name"]="Down",["Character"]="Heian",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Heian/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Heian",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Locust/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Locust",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Locust/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Locust",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Locust/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Locust",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Locust/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Locust",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Locust/Melee/Up"]={["Name"]="Up",["Character"]="Locust",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Locust/Melee/Down"]={["Name"]="Down",["Character"]="Locust",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hiromi/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Hiromi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hiromi/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Hiromi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hiromi/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Hiromi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hiromi/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Hiromi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hiromi/Melee/Up"]={["Name"]="Up",["Character"]="Hiromi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hiromi/Melee/Down"]={["Name"]="Down",["Character"]="Hiromi",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuki/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Yuki",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuki/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Yuki",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuki/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Yuki",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuki/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Yuki",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuki/Melee/Down"]={["Name"]="Down",["Character"]="Yuki",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuki/Melee/Up"]={["Name"]="Up",["Character"]="Yuki",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Goku/Melee/Down"]={["Name"]="Down",["Character"]="Goku",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Goku/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Goku",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Goku/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Goku",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Goku/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Goku",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Goku/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Goku",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Goku/Melee/Up"]={["Name"]="Up",["Character"]="Goku",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuta/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Yuta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuta/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Yuta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuta/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Yuta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuta/Melee/Up"]={["Name"]="Up",["Character"]="Yuta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuta/Melee/Down"]={["Name"]="Down",["Character"]="Yuta",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Yuta/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Yuta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Charles/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Charles",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Charles/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Charles",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Charles/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Charles",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Charles/Melee/Up"]={["Name"]="Up",["Character"]="Charles",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Charles/Melee/Down"]={["Name"]="Down",["Character"]="Charles",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Charles/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Charles",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mechamaru/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Mechamaru",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mechamaru/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Mechamaru",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mechamaru/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Mechamaru",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mechamaru/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Mechamaru",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mechamaru/Melee/Up"]={["Name"]="Up",["Character"]="Mechamaru",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Mechamaru/Melee/Down"]={["Name"]="Down",["Character"]="Mechamaru",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Naoya/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Naoya",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Naoya/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Naoya",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Naoya/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Naoya",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Naoya/Melee/Up"]={["Name"]="Up",["Character"]="Naoya",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Naoya/Melee/Down"]={["Name"]="Down",["Character"]="Naoya",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Naoya/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Naoya",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Nanami/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Nanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Nanami/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Nanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Nanami/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Nanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Nanami/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Nanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Nanami/Melee/Up"]={["Name"]="Up",["Character"]="Nanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Nanami/Melee/Down"]={["Name"]="Down",["Character"]="Nanami",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Haruta/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Haruta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Haruta/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Haruta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Haruta/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Haruta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Haruta/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Haruta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Haruta/Melee/Up"]={["Name"]="Up",["Character"]="Haruta",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Haruta/Melee/Down"]={["Name"]="Down",["Character"]="Haruta",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["MeiMei/Melee/Melee1"]={["Name"]="Melee1",["Character"]="MeiMei",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["MeiMei/Melee/Melee2"]={["Name"]="Melee2",["Character"]="MeiMei",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["MeiMei/Melee/Melee3"]={["Name"]="Melee3",["Character"]="MeiMei",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["MeiMei/Melee/Melee4"]={["Name"]="Melee4",["Character"]="MeiMei",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["MeiMei/Melee/Up"]={["Name"]="Up",["Character"]="MeiMei",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["MeiMei/Melee/Down"]={["Name"]="Down",["Character"]="MeiMei",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hanami/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Hanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hanami/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Hanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hanami/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Hanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hanami/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Hanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hanami/Melee/Up"]={["Name"]="Up",["Character"]="Hanami",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Hanami/Melee/Down"]={["Name"]="Down",["Character"]="Hanami",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Ryu/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Ryu",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Ryu/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Ryu",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Ryu/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Ryu",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Ryu/Melee/Up"]={["Name"]="Up",["Character"]="Ryu",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Ryu/Melee/Down"]={["Name"]="Down",["Character"]="Ryu",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Kurourushi/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Kurourushi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Kurourushi/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Kurourushi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Kurourushi/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Kurourushi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Kurourushi/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Kurourushi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Kurourushi/Melee/Up"]={["Name"]="Up",["Character"]="Kurourushi",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Kurourushi/Melee/Down"]={["Name"]="Down",["Character"]="Kurourushi",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Reggie/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Reggie",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Reggie/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Reggie",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Reggie/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Reggie",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Reggie/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Reggie",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Reggie/Melee/Up"]={["Name"]="Up",["Character"]="Reggie",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Reggie/Melee/Down"]={["Name"]="Down",["Character"]="Reggie",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Uro/Melee/Melee1"]={["Name"]="Melee1",["Character"]="Uro",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Uro/Melee/Melee2"]={["Name"]="Melee2",["Character"]="Uro",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Uro/Melee/Melee3"]={["Name"]="Melee3",["Character"]="Uro",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Uro/Melee/Melee4"]={["Name"]="Melee4",["Character"]="Uro",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Uro/Melee/Up"]={["Name"]="Up",["Character"]="Uro",["Block"]="block",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true},["Uro/Melee/Down"]={["Name"]="Down",["Character"]="Uro",["Block"]="none",["Range"]=10,["Radial"]=false,["Ranged"]=false,["Window"]=0.55,["Melee"]=true}},["ById"]={["rbxassetid://132748613906344"]={"Gojo/HollowPurple"},["rbxassetid://137654778575373"]={"Gojo/ReversalRed"},["rbxassetid://137865634124104"]={"Gojo/LapseBlue"},["rbxassetid://101162958113766"]={"Gojo/LapseBlueMax"},["rbxassetid://132725601768618"]={"Gojo/InfiniteVoid"},["rbxassetid://95421145178968"]={"Gojo/RapidPunches"},["rbxassetid://127851700400958"]={"Gojo/Melee/Melee1","Gojo/Melee/Melee4","Mahito/Melee/Melee4","Todo/Melee/Melee4"},["rbxassetid://72548435296350"]={"Gojo/Melee/Melee2"},["rbxassetid://84547415708554"]={"Gojo/Melee/Melee3"},["rbxassetid://134243365075812"]={"Gojo/Melee/Up","Itadori/Melee/Up","Choso/Melee/Up","Megumi/Melee/Up","Mahito/Melee/Up","Todo/Melee/Up","Heian/Melee/Up","Locust/Melee/Up","Yuta/Melee/Up","Charles/Melee/Up","Mechamaru/Melee/Up","Naoya/Melee/Up","Hanami/Melee/Up","Ryu/Melee/Up","Reggie/Melee/Up","Uro/Melee/Up"},["rbxassetid://92966188946988"]={"Gojo/Melee/Down","Itadori/Melee/Down","Choso/Melee/Down","Hakari/Melee/Down","Megumi/Melee/Down","Mahito/Melee/Down","Todo/Melee/Down","Heian/Melee/Down","Locust/Melee/Down","Hiromi/Melee/Down","Yuki/Melee/Down","Yuta/Melee/Down","Charles/Melee/Down","Mechamaru/Melee/Down","Naoya/Melee/Down","Nanami/Melee/Down","Hanami/Melee/Down","Ryu/Melee/Down","Reggie/Melee/Down","Uro/Melee/Down"},["rbxassetid://124937162378188"]={"Gojo/ReversalRedMax"},["rbxassetid://104749346956269"]={"Gojo/TwofoldKick"},["rbxassetid://95295463826732"]={"Itadori/Melee/Melee1","Heian/Melee/Melee1"},["rbxassetid://105077924973072"]={"Itadori/Melee/Melee2","Choso/Melee/Melee2","Heian/Melee/Melee2","Ryu/Melee/Melee1"},["rbxassetid://124862357369335"]={"Itadori/Melee/Melee3","Heian/Melee/Melee3"},["rbxassetid://81630213087988"]={"Itadori/Melee/Melee4","Heian/Melee/Melee4"},["rbxassetid://131506102901134"]={"Itadori/Dismantle"},["rbxassetid://82987093810211"]={"Itadori/ManjiKick"},["rbxassetid://121984128639453"]={"Itadori/MalevolantShrine"},["rbxassetid://137611726964398"]={"Itadori/FlameArrow"},["rbxassetid://107554693613496"]={"Itadori/Rush"},["rbxassetid://110146909061402"]={"Itadori/Melee/Melee1"},["rbxassetid://123414935051274"]={"Itadori/Melee/Melee2"},["rbxassetid://108636011034323"]={"Itadori/Melee/Melee3"},["rbxassetid://105376952884290"]={"Itadori/Melee/Melee4"},["rbxassetid://77200218033775"]={"Itadori/CursedStrikes"},["rbxassetid://124901309160375"]={"Itadori/CrushingBlow"},["rbxassetid://100962226150441"]={"Itadori/DivergentFist"},["rbxassetid://95852624447551"]={"Itadori/DivergentFist"},["rbxassetid://74145636023952"]={"Itadori/DivergentFist"},["rbxassetid://123171106092050"]={"Itadori/DivergentFist"},["rbxassetid://100446064103831"]={"Choso/BloodEdge"},["rbxassetid://127171275866632"]={"Choso/PiercingBlood"},["rbxassetid://84039122607068"]={"Choso/RedScale"},["rbxassetid://85569553424083"]={"Choso/Supernova"},["rbxassetid://87805684702890"]={"Choso/RedScale"},["rbxassetid://114321791577837"]={"Choso/SlicingExorcism"},["rbxassetid://117371289990421"]={"Choso/BloodRain"},["rbxassetid://107067953428369"]={"Choso/PlasmaWave"},["rbxassetid://95097480425566"]={"Choso/WingKing"},["rbxassetid://96185406489877"]={"Choso/Melee/Melee1","Megumi/Melee/Melee3"},["rbxassetid://119042572747325"]={"Choso/Melee/Melee3","Mahito/Melee/Melee3"},["rbxassetid://105287938257399"]={"Choso/Melee/Melee4","Megumi/Melee/Melee4"},["rbxassetid://94588892125071"]={"Hakari/Melee/Melee1"},["rbxassetid://97868312130612"]={"Hakari/Melee/Melee2"},["rbxassetid://140588454098230"]={"Hakari/Melee/Melee3"},["rbxassetid://138826758216894"]={"Hakari/Melee/Melee4"},["rbxassetid://109299799610861"]={"Hakari/Melee/Up"},["rbxassetid://72063002791216"]={"Hakari/ShutterDoors"},["rbxassetid://72467492674240"]={"Hakari/RoughEnergy"},["rbxassetid://82541714192027"]={"Hakari/ReserveBall"},["rbxassetid://95901746347992"]={"Hakari/LuckyVolley"},["rbxassetid://132281807148575"]={"Hakari/LuckyRushdown"},["rbxassetid://120480195428173"]={"Hakari/OverLuck"},["rbxassetid://108123475959041"]={"Hakari/FeverBreaker"},["rbxassetid://91984445049000"]={"Hakari/EnergySurge"},["rbxassetid://75337033003776"]={"Megumi/Melee/Melee1"},["rbxassetid://138489871864252"]={"Megumi/Melee/Melee2"},["rbxassetid://132653290201368"]={"Megumi/RabbitEscape"},["rbxassetid://111077341852080"]={"Megumi/Nue"},["rbxassetid://116432619539029"]={"Megumi/Toad"},["rbxassetid://72424828296871"]={"Megumi/ShadowSwarm"},["rbxassetid://81112033595734"]={"Megumi/DivineDog"},["rbxassetid://127843796051633"]={"Megumi/MahoragaUse"},["rbxassetid://77826020629176"]={"Megumi/ShadowSwarm"},["rbxassetid://124644660953423"]={"Megumi/ShadowSwarm"},["rbxassetid://75686211329107"]={"Megumi/ShadowSwarm"},["rbxassetid://75390215999547"]={"Megumi/GreatSerpent"},["rbxassetid://109718372214725"]={"Megumi/Melee/Melee1"},["rbxassetid://121800365664070"]={"Megumi/Melee/Melee2"},["rbxassetid://96513213736303"]={"Megumi/Melee/Melee3"},["rbxassetid://79037514387169"]={"Megumi/Melee/Melee4"},["rbxassetid://119434039452526"]={"Megumi/Melee/Up"},["rbxassetid://114797198964940"]={"Megumi/Melee/Down"},["rbxassetid://115683433001643"]={"Megumi/DivinePummel"},["rbxassetid://138852224035589"]={"Megumi/GroundPitch"},["rbxassetid://85024950165903"]={"Megumi/Earthquake"},["rbxassetid://139336998459583"]={"Megumi/Adaptation"},["rbxassetid://131219281339199"]={"Megumi/MaxElephant"},["rbxassetid://126277739156443"]={"Mahito/Melee/Melee1"},["rbxassetid://99710481887795"]={"Mahito/Melee/Melee2"},["rbxassetid://121322029260156"]={"Mahito/Melee/Melee3","Ryu/Melee/Melee3"},["rbxassetid://122655618588472"]={"Mahito/Melee/Melee4"},["rbxassetid://98845475810982"]={"Mahito/Melee/Up"},["rbxassetid://103493656287292"]={"Mahito/Stockpile"},["rbxassetid://89092734635186"]={"Mahito/Soulfire"},["rbxassetid://72475960800126"]={"Mahito/FocusStrike"},["rbxassetid://71784337627181"]={"Mahito/Melee/Melee1"},["rbxassetid://125120382787311"]={"Mahito/Melee/Melee2"},["rbxassetid://98365018553171"]={"Mahito/Melee/Melee1"},["rbxassetid://80150988150906"]={"Mahito/Melee/Melee2"},["rbxassetid://86918383671100"]={"Mahito/Melee/Melee3"},["rbxassetid://85887300265206"]={"Mahito/Melee/Melee4"},["rbxassetid://114562626498918"]={"Mahito/Melee/Down"},["rbxassetid://79568627671998"]={"Mahito/Melee/Melee1"},["rbxassetid://105870773841535"]={"Mahito/Melee/Melee2"},["rbxassetid://130659585624615"]={"Mahito/Melee/Melee3"},["rbxassetid://138626478088332"]={"Mahito/Melee/Melee4"},["rbxassetid://75736902190737"]={"Mahito/SelfPerfection"},["rbxassetid://108319980293313"]={"Mahito/BodyRepel"},["rbxassetid://76313364850487"]={"Mahito/WideSPStrike"},["rbxassetid://105068005007692"]={"Mahito/FaceBlitz"},["rbxassetid://89888040037257"]={"Mahito/CrushingRushdown"},["rbxassetid://127727754867974"]={"Mahito/SpikeWrath"},["rbxassetid://86073608599582"]={"Mahito/HeadSplitter"},["rbxassetid://96327114254575"]={"Todo/Melee/Melee1"},["rbxassetid://107029561762376"]={"Todo/Melee/Melee2"},["rbxassetid://117831239064143"]={"Todo/Melee/Melee3","Hiromi/Melee/Melee4"},["rbxassetid://84737448668938"]={"Todo/SwiftKick"},["rbxassetid://136536827155962"]={"Todo/BruteForce"},["rbxassetid://111720035828971"]={"Todo/PebbleThrow"},["rbxassetid://115042679536959"]={"Todo/ElbowDrop"},["rbxassetid://121572833341748"]={"Todo/IdolDebut"},["rbxassetid://84448423136678"]={"Todo/ClimaxJump"},["rbxassetid://89677028738408"]={"Todo/Dreams"},["rbxassetid://72828071138653"]={"Todo/Brothers"},["rbxassetid://131826588098422"]={"Heian/DismantleV2"},["rbxassetid://137007125977081"]={"Heian/Kamutoke"},["rbxassetid://85068785050521"]={"Locust/Melee/Melee1"},["rbxassetid://79086910454958"]={"Locust/Melee/Melee2"},["rbxassetid://108027796023968"]={"Locust/Melee/Melee3"},["rbxassetid://99205259396653"]={"Locust/Melee/Melee4"},["rbxassetid://129132347098646"]={"Locust/BlackMucus"},["rbxassetid://89652378115594"]={"Hiromi/ExtendSwing"},["rbxassetid://133936641185614"]={"Hiromi/Melee/Melee1"},["rbxassetid://122573730331631"]={"Hiromi/Melee/Melee2"},["rbxassetid://82400997593751"]={"Hiromi/Melee/Melee3"},["rbxassetid://118634493886688"]={"Hiromi/Melee/Melee4"},["rbxassetid://115586282387431"]={"Hiromi/Melee/Up","Yuki/Melee/Up"},["rbxassetid://76519264603956"]={"Hiromi/JusticeServed"},["rbxassetid://132704398648016"]={"Hiromi/Execution"},["rbxassetid://139280948741186"]={"Hiromi/Melee/Melee1"},["rbxassetid://109340494549365"]={"Hiromi/Melee/Melee2"},["rbxassetid://98577624776161"]={"Hiromi/Melee/Melee3"},["rbxassetid://106649604455931"]={"Hiromi/FinalJudgement"},["rbxassetid://132754851925571"]={"Hiromi/Verdict"},["rbxassetid://124243904748268"]={"Hiromi/TripleSentence"},["rbxassetid://124759375124281"]={"Hiromi/JudgeReach"},["rbxassetid://135411487367370"]={"Hiromi/PressingCharges"},["rbxassetid://133869529005453"]={"Hiromi/JudgeReach"},["rbxassetid://131909724908049"]={"Yuki/Melee/Melee1"},["rbxassetid://72575786212990"]={"Yuki/Melee/Melee2"},["rbxassetid://119248903710146"]={"Yuki/Melee/Melee3"},["rbxassetid://123168328205349"]={"Yuki/Melee/Melee4"},["rbxassetid://115097960689033"]={"Yuki/GarudaRebound"},["rbxassetid://104793932628579"]={"Yuki/MassBreaker"},["rbxassetid://77833820443705"]={"Yuki/GarudaStab"},["rbxassetid://106474043944206"]={"Yuki/Melee/Melee1"},["rbxassetid://91990544700842"]={"Yuki/Melee/Melee2"},["rbxassetid://107825127494342"]={"Yuki/Melee/Melee3"},["rbxassetid://97504088532041"]={"Yuki/Melee/Melee4"},["rbxassetid://84989753395518"]={"Goku/Melee/Down"},["rbxassetid://104087365067491"]={"Goku/Melee/Melee1"},["rbxassetid://97215638330770"]={"Goku/Melee/Melee2"},["rbxassetid://100474683542881"]={"Goku/Melee/Melee3"},["rbxassetid://131279921755936"]={"Goku/Melee/Melee4"},["rbxassetid://96433049733325"]={"Goku/Melee/Up"},["rbxassetid://81971779090581"]={"Goku/Kamehameha"},["rbxassetid://117318845383884"]={"Goku/StaffUppercut"},["rbxassetid://87481059409847"]={"Goku/StaffExtend"},["rbxassetid://128537969081721"]={"Goku/KiSpam"},["rbxassetid://123236749567737"]={"Goku/Melee/Melee1"},["rbxassetid://74550814125588"]={"Goku/Melee/Melee2"},["rbxassetid://114375152692460"]={"Goku/Melee/Melee3"},["rbxassetid://105878146832347"]={"Goku/Melee/Melee4"},["rbxassetid://88911658010897"]={"Yuta/Revolve"},["rbxassetid://89582140026963"]={"Yuta/ResoluteSlash"},["rbxassetid://104824728032437"]={"Yuta/SeveringPath"},["rbxassetid://117178057848472"]={"Yuta/Veilstep"},["rbxassetid://133240987753043"]={"Yuta/Melee/Melee1"},["rbxassetid://130806585141471"]={"Yuta/Melee/Melee2"},["rbxassetid://131967150738931"]={"Yuta/Melee/Melee3"},["rbxassetid://73456086297777"]={"Yuta/Melee/Up"},["rbxassetid://111750364977569"]={"Yuta/Melee/Down"},["rbxassetid://84442064935420"]={"Yuta/Melee/Melee4"},["rbxassetid://110326542726854"]={"Yuta/RikaDownslam"},["rbxassetid://99516000246972"]={"Yuta/RikaHaymaker"},["rbxassetid://116737527523542"]={"Yuta/LoveBeam"},["rbxassetid://93429614171877"]={"Yuta/ElbowRush"},["rbxassetid://115432081398704"]={"Yuta/Veilstep"},["rbxassetid://140595869234331"]={"Yuta/SeveringPath"},["rbxassetid://73717793648274"]={"Yuta/ResoluteSlash"},["rbxassetid://131031842057158"]={"Yuta/EnergyRipple"},["rbxassetid://109432265703187"]={"Yuta/Melee/Melee1"},["rbxassetid://137919635923292"]={"Yuta/Melee/Melee2"},["rbxassetid://135256592475167"]={"Yuta/Melee/Melee3"},["rbxassetid://121403322067812"]={"Yuta/Melee/Melee4"},["rbxassetid://95077220586856"]={"Yuta/Outburst"},["rbxassetid://139833047658617"]={"Charles/Melee/Melee3"},["rbxassetid://79271374075726"]={"Charles/Melee/Melee4"},["rbxassetid://84080901810314"]={"Charles/Melee/Melee2"},["rbxassetid://125689391910002"]={"Charles/Melee/Melee1"},["rbxassetid://79860101129549"]={"Charles/ShutUp"},["rbxassetid://103013818601982"]={"Charles/Despair"},["rbxassetid://72933571933445"]={"Charles/EyeCatch"},["rbxassetid://72932825817330"]={"Charles/Sacrilegious"},["rbxassetid://98783064085844"]={"Mechamaru/Melee/Melee1"},["rbxassetid://85148168523745"]={"Mechamaru/Melee/Melee2"},["rbxassetid://108686045412945"]={"Mechamaru/Melee/Melee3"},["rbxassetid://79718433989469"]={"Mechamaru/Melee/Melee4"},["rbxassetid://120136894011461"]={"Mechamaru/UltraSpin"},["rbxassetid://93901924492394"]={"Mechamaru/UltraCannon"},["rbxassetid://76118979198026"]={"Mechamaru/BoostOn"},["rbxassetid://80504019426174"]={"Mechamaru/Melee/Melee1"},["rbxassetid://100835844904897"]={"Mechamaru/Melee/Melee2"},["rbxassetid://101862938993177"]={"Mechamaru/Melee/Melee3"},["rbxassetid://100919783371339"]={"Mechamaru/Melee/Melee4"},["rbxassetid://139899183181812"]={"Mechamaru/Melee/Melee4"},["rbxassetid://80465501985014"]={"Mechamaru/MiracleCannon"},["rbxassetid://89009042593684"]={"Mechamaru/PigeonViola"},["rbxassetid://87472283043607"]={"Mechamaru/BoostOn"},["rbxassetid://114277419400774"]={"Mechamaru/HeatEmission"},["rbxassetid://137638103122538"]={"Mechamaru/AbsoluteDestruction"},["rbxassetid://121239701968766"]={"Mechamaru/AbsoluteDestruction"},["rbxassetid://99731350629462"]={"Mechamaru/AbsoluteDestruction"},["rbxassetid://136523051723440"]={"Mechamaru/MiracleCannon"},["rbxassetid://77583711129628"]={"Naoya/Melee/Melee3"},["rbxassetid://116910683335467"]={"Naoya/Melee/Melee4","Ryu/Melee/Melee2"},["rbxassetid://108708446862011"]={"Naoya/Melee/Melee2"},["rbxassetid://101283990868172"]={"Naoya/Melee/Melee1"},["rbxassetid://101079657277587"]={"Naoya/ProjectionBreaker"},["rbxassetid://118607369830566"]={"Naoya/Bleedout"},["rbxassetid://86045680364061"]={"Naoya/DecisiveStrike"},["rbxassetid://119211164876773"]={"Naoya/CursoryImpact"},["rbxassetid://115589615022077"]={"Naoya/FlashFreezing"},["rbxassetid://70890372338556"]={"Naoya/TopSpeed"},["rbxassetid://74580112757879"]={"Naoya/Melee/Melee3"},["rbxassetid://101107501526373"]={"Naoya/Melee/Melee4"},["rbxassetid://108376755316792"]={"Naoya/Melee/Melee2"},["rbxassetid://91853462087608"]={"Naoya/Melee/Up"},["rbxassetid://86109053396974"]={"Naoya/Melee/Down"},["rbxassetid://77284264481284"]={"Naoya/Melee/Melee1"},["rbxassetid://82149987460883"]={"Naoya/TendrilGrab"},["rbxassetid://105121164520635"]={"Naoya/ProjectionBreaker"},["rbxassetid://84359513001979"]={"Nanami/Melee/Melee1"},["rbxassetid://79436586236026"]={"Nanami/Melee/Melee2"},["rbxassetid://102285403332509"]={"Nanami/Melee/Melee3"},["rbxassetid://104137631480391"]={"Nanami/Melee/Melee4"},["rbxassetid://78540777177847"]={"Nanami/Melee/Up"},["rbxassetid://81210313723714"]={"Nanami/CleavingWhirl"},["rbxassetid://130957217409359"]={"Nanami/SeveranceKick"},["rbxassetid://113359849246757"]={"Nanami/Stabilize"},["rbxassetid://100811576955331"]={"Nanami/BluntCut"},["rbxassetid://114913455544468"]={"Nanami/Melee/Melee1"},["rbxassetid://84602523265622"]={"Nanami/Melee/Melee2"},["rbxassetid://102085681670810"]={"Nanami/Melee/Melee3"},["rbxassetid://115446267797335"]={"Nanami/Melee/Melee4"},["rbxassetid://89394375446962"]={"Nanami/Melee/Up"},["rbxassetid://94781366396051"]={"Nanami/Melee/Down"},["rbxassetid://78578012001859"]={"Nanami/RatioBreaker"},["rbxassetid://137451357351000"]={"Nanami/RatioBreaker"},["rbxassetid://86618245908620"]={"Nanami/RatioBreaker"},["rbxassetid://131948591638044"]={"Nanami/RatioBreaker"},["rbxassetid://122015481201264"]={"Nanami/Collapse"},["rbxassetid://134622628645994"]={"Nanami/Sharpen"},["rbxassetid://89891294371787"]={"Nanami/Interrogate"},["rbxassetid://133303451091615"]={"Haruta/Backstab"},["rbxassetid://133447840605824"]={"Haruta/Melee/Melee1"},["rbxassetid://113963875117859"]={"Haruta/Melee/Melee2"},["rbxassetid://106282708121342"]={"Haruta/Melee/Melee3"},["rbxassetid://101681158700275"]={"Haruta/Melee/Melee4"},["rbxassetid://119152716475706"]={"Haruta/Melee/Up"},["rbxassetid://100040983719699"]={"Haruta/Melee/Down"},["rbxassetid://103960582499076"]={"Haruta/AnkleCutter"},["rbxassetid://93028763593631"]={"Haruta/HighTime"},["rbxassetid://76957377224584"]={"Haruta/CheapShot"},["rbxassetid://102053631728986"]={"Haruta/Trip"},["rbxassetid://120914276661831"]={"Haruta/Ambush"},["rbxassetid://114985590391235"]={"MeiMei/Melee/Melee1"},["rbxassetid://108449614447004"]={"MeiMei/Melee/Melee2"},["rbxassetid://122170399962557"]={"MeiMei/Melee/Melee3"},["rbxassetid://117638619792450"]={"MeiMei/Melee/Melee4"},["rbxassetid://136978371933277"]={"MeiMei/Melee/Up"},["rbxassetid://87792276744794"]={"MeiMei/Melee/Down"},["rbxassetid://92081142332466"]={"MeiMei/ImpetusUpdraft"},["rbxassetid://90781290293652"]={"MeiMei/Circling"},["rbxassetid://81007905598407"]={"MeiMei/Murmurate"},["rbxassetid://111083699259354"]={"Hanami/Melee/Melee1"},["rbxassetid://88849926869776"]={"Hanami/Melee/Melee2"},["rbxassetid://89537672683114"]={"Hanami/Melee/Melee3"},["rbxassetid://109598602517674"]={"Hanami/Melee/Melee4"},["rbxassetid://113722638806911"]={"Hanami/RootSwarm"},["rbxassetid://102221764735089"]={"Hanami/FlowerField"},["rbxassetid://96466374346823"]={"Hanami/BudShot"},["rbxassetid://81953935260783"]={"Hanami/DefenseResponse"},["rbxassetid://92595499555055"]={"Hanami/SurgingThorns"},["rbxassetid://89977758316911"]={"Hanami/CursedBuds"},["rbxassetid://100108404823407"]={"Hanami/CursedBuds"},["rbxassetid://115781423162319"]={"Hanami/Melee/Melee1"},["rbxassetid://106245594701442"]={"Hanami/Melee/Melee2"},["rbxassetid://139925289573265"]={"Hanami/Melee/Melee3"},["rbxassetid://128437228548370"]={"Hanami/Melee/Melee4"},["rbxassetid://124427228784862"]={"Hanami/RootRampage"},["rbxassetid://92698956945928"]={"Ryu/Melee/Melee3"},["rbxassetid://73243807139765"]={"Ryu/GraniteBlast"},["rbxassetid://114822879878184"]={"Ryu/Unsatisfied"},["rbxassetid://99818212174021"]={"Ryu/HadNoIdea"},["rbxassetid://70394890117813"]={"Ryu/Appetizer"},["rbxassetid://86568794583359"]={"Ryu/WhatAreYouAfter"},["rbxassetid://138826705245289"]={"Ryu/SecondHelping"},["rbxassetid://131917532383382"]={"Ryu/ThisDessert"},["rbxassetid://86463226245064"]={"Ryu/WerentInvited"},["rbxassetid://105961366724096"]={"Kurourushi/Melee/Melee1"},["rbxassetid://86519781516542"]={"Kurourushi/Melee/Melee2"},["rbxassetid://123591522021548"]={"Kurourushi/Melee/Melee3"},["rbxassetid://124726819047447"]={"Kurourushi/Melee/Melee4"},["rbxassetid://129583539805939"]={"Kurourushi/Melee/Up"},["rbxassetid://136466703751033"]={"Kurourushi/Melee/Down"},["rbxassetid://92045676155777"]={"Kurourushi/Melee/Melee2"},["rbxassetid://75985296743258"]={"Kurourushi/Melee/Melee3"},["rbxassetid://128247404669136"]={"Kurourushi/Melee/Melee4"},["rbxassetid://90926294837924"]={"Kurourushi/Melee/Up"},["rbxassetid://105028055041290"]={"Kurourushi/Melee/Down"},["rbxassetid://83430571986421"]={"Kurourushi/FesteringStrikes"},["rbxassetid://85938446097801"]={"Kurourushi/Chokehold"},["rbxassetid://116119661056362"]={"Kurourushi/RoachSwarm"},["rbxassetid://78636717376287"]={"Kurourushi/Detach"},["rbxassetid://93880529089759"]={"Kurourushi/Melee/Melee1"},["rbxassetid://131033861605339"]={"Kurourushi/Melee/Melee2"},["rbxassetid://118433412162663"]={"Kurourushi/Melee/Melee3"},["rbxassetid://110425977429691"]={"Kurourushi/Melee/Melee4"},["rbxassetid://135686778593679"]={"Kurourushi/Melee/Melee2"},["rbxassetid://92796867394473"]={"Kurourushi/Melee/Melee3"},["rbxassetid://81426568444338"]={"Kurourushi/Melee/Melee4"},["rbxassetid://97901397284754"]={"Kurourushi/Melee/Melee1"},["rbxassetid://118813489101356"]={"Kurourushi/FesteringStrikes"},["rbxassetid://106892235857467"]={"Reggie/Melee/Melee1"},["rbxassetid://93623649598782"]={"Reggie/Melee/Melee2"},["rbxassetid://128057999506702"]={"Reggie/Melee/Melee3"},["rbxassetid://76372421343979"]={"Reggie/Melee/Melee4"},["rbxassetid://106478217686775"]={"Reggie/GushingWound"},["rbxassetid://80552926761100"]={"Reggie/Homerun"},["rbxassetid://86293749971049"]={"Reggie/PianoDrop"},["rbxassetid://108407413391495"]={"Reggie/GarageSale"},["rbxassetid://103659500760745"]={"Reggie/BluntTrauma"},["rbxassetid://133042937840159"]={"Reggie/SpeedCrash"},["rbxassetid://84063127664904"]={"Reggie/Fleche"},["rbxassetid://70619893542373"]={"Reggie/DroneStrike"},["rbxassetid://72249315151281"]={"Reggie/PoleVault"},["rbxassetid://90157434123044"]={"Reggie/Mayhem"},["rbxassetid://132307745371357"]={"Reggie/BigMoves"},["rbxassetid://98816967040955"]={"Reggie/Arson"},["rbxassetid://84784070267976"]={"Uro/BlindRage"},["rbxassetid://127457641316758"]={"Uro/ThinIceBreaker"},["rbxassetid://107852433150124"]={"Uro/Melee/Melee1"},["rbxassetid://80809423999548"]={"Uro/Melee/Melee2"},["rbxassetid://135805825263494"]={"Uro/Melee/Melee3"},["rbxassetid://110958607174992"]={"Uro/Melee/Melee4"},["rbxassetid://134622175293378"]={"Uro/Melee/Melee1"},["rbxassetid://95738371652260"]={"Uro/Melee/Melee2"},["rbxassetid://139549374008097"]={"Uro/Melee/Melee3"},["rbxassetid://89465788843211"]={"Uro/Melee/Melee4"},["rbxassetid://71262912144187"]={"Uro/ThinIceBreaker"},["rbxassetid://136658834297626"]={"Uro/ThinIceBreaker"},["rbxassetid://105191773344078"]={"Uro/SkyDistortion"}},["ByPath"]={["Gojo/HollowPurple"]={"Gojo/HollowPurple"},["Gojo/ReversalRed"]={"Gojo/ReversalRed"},["Gojo/LapseBlue"]={"Gojo/LapseBlue"},["Gojo/LapseBlueMaximum"]={"Gojo/LapseBlueMax"},["Gojo/InfiniteVoid"]={"Gojo/InfiniteVoid"},["Gojo/RapidPunches"]={"Gojo/RapidPunches"},["Gojo/Melee/Melee1"]={"Gojo/Melee/Melee1"},["Gojo/Melee/Melee2"]={"Gojo/Melee/Melee2"},["Gojo/Melee/Melee3"]={"Gojo/Melee/Melee3"},["Gojo/Melee/Melee4"]={"Gojo/Melee/Melee4"},["Gojo/Melee/Up"]={"Gojo/Melee/Up"},["Gojo/Melee/Down"]={"Gojo/Melee/Down"},["Gojo/ReversalRedMaximum"]={"Gojo/ReversalRedMax"},["Gojo/TwofoldKick"]={"Gojo/TwofoldKick"},["Itadori/Melee/Melee1"]={"Itadori/Melee/Melee1"},["Itadori/Melee/Melee2"]={"Itadori/Melee/Melee2"},["Itadori/Melee/Melee3"]={"Itadori/Melee/Melee3"},["Itadori/Melee/Up"]={"Itadori/Melee/Up"},["Itadori/Melee/Down"]={"Itadori/Melee/Down"},["Itadori/Melee/Melee4"]={"Itadori/Melee/Melee4"},["Itadori/Dismantle"]={"Itadori/Dismantle"},["Itadori/ManjiKick"]={"Itadori/ManjiKick"},["Itadori/MalevolentShrine"]={"Itadori/MalevolantShrine"},["Itadori/FlameArrow"]={"Itadori/FlameArrow"},["Itadori/Rush"]={"Itadori/Rush"},["Itadori/MeleeUlt/Melee1"]={"Itadori/Melee/Melee1"},["Itadori/MeleeUlt/Melee2"]={"Itadori/Melee/Melee2"},["Itadori/MeleeUlt/Melee3"]={"Itadori/Melee/Melee3"},["Itadori/MeleeUlt/Melee4"]={"Itadori/Melee/Melee4"},["Itadori/CursedStrike"]={"Itadori/CursedStrikes"},["Itadori/CrushingBlow"]={"Itadori/CrushingBlow"},["Itadori/Variants/DivergentFist1"]={"Itadori/DivergentFist"},["Itadori/Variants/DivergentFist2"]={"Itadori/DivergentFist"},["Itadori/Variants/DivergentFist3"]={"Itadori/DivergentFist"},["Itadori/Variants/DivergentFist4"]={"Itadori/DivergentFist"},["Choso/BloodEdge"]={"Choso/BloodEdge"},["Choso/PiercingBlood"]={"Choso/PiercingBlood"},["Choso/RedScale"]={"Choso/RedScale"},["Choso/Supernova"]={"Choso/Supernova"},["Choso/RedScaleAir"]={"Choso/RedScale"},["Choso/SlicingExorcism"]={"Choso/SlicingExorcism"},["Choso/BloodRain"]={"Choso/BloodRain"},["Choso/PlasmaWave"]={"Choso/PlasmaWave"},["Choso/WingKing"]={"Choso/WingKing"},["Choso/Melee/Melee1"]={"Choso/Melee/Melee1"},["Choso/Melee/Melee2"]={"Choso/Melee/Melee2"},["Choso/Melee/Melee3"]={"Choso/Melee/Melee3"},["Choso/Melee/Melee4"]={"Choso/Melee/Melee4"},["Choso/Melee/Down"]={"Choso/Melee/Down"},["Choso/Melee/Up"]={"Choso/Melee/Up"},["Hakari/Melee/Melee1"]={"Hakari/Melee/Melee1"},["Hakari/Melee/Melee2"]={"Hakari/Melee/Melee2"},["Hakari/Melee/Melee3"]={"Hakari/Melee/Melee3"},["Hakari/Melee/Melee4"]={"Hakari/Melee/Melee4"},["Hakari/Melee/Up"]={"Hakari/Melee/Up"},["Hakari/Melee/Down"]={"Hakari/Melee/Down"},["Hakari/ShutterDoors"]={"Hakari/ShutterDoors"},["Hakari/RoughEnergy"]={"Hakari/RoughEnergy"},["Hakari/ReserveBalls"]={"Hakari/ReserveBall"},["Hakari/LuckyVolley"]={"Hakari/LuckyVolley"},["Hakari/LuckyRushdown"]={"Hakari/LuckyRushdown"},["Hakari/OverLuck"]={"Hakari/OverLuck"},["Hakari/FeverBreaker"]={"Hakari/FeverBreaker"},["Hakari/EnergySurge"]={"Hakari/EnergySurge"},["Megumi/Melee/Melee1"]={"Megumi/Melee/Melee1"},["Megumi/Melee/Melee2"]={"Megumi/Melee/Melee2"},["Megumi/Melee/Melee3"]={"Megumi/Melee/Melee3"},["Megumi/Melee/Melee4"]={"Megumi/Melee/Melee4"},["Megumi/Melee/Up"]={"Megumi/Melee/Up"},["Megumi/Melee/Down"]={"Megumi/Melee/Down"},["Megumi/RabbitEscape"]={"Megumi/RabbitEscape"},["Megumi/Nue"]={"Megumi/Nue"},["Megumi/Toad"]={"Megumi/Toad"},["Megumi/ShadowSwarm"]={"Megumi/ShadowSwarm"},["Megumi/DivineDog"]={"Megumi/DivineDog"},["Megumi/MahoragaUse"]={"Megumi/MahoragaUse"},["Megumi/ShadowSwarm1"]={"Megumi/ShadowSwarm"},["Megumi/ShadowSwarm2"]={"Megumi/ShadowSwarm"},["Megumi/ShadowSwarmRun"]={"Megumi/ShadowSwarm"},["Megumi/GreatSerpent"]={"Megumi/GreatSerpent"},["Megumi/Mahoraga/Melee/Melee1"]={"Megumi/Melee/Melee1"},["Megumi/Mahoraga/Melee/Melee2"]={"Megumi/Melee/Melee2"},["Megumi/Mahoraga/Melee/Melee3"]={"Megumi/Melee/Melee3"},["Megumi/Mahoraga/Melee/Melee4"]={"Megumi/Melee/Melee4"},["Megumi/Mahoraga/Melee/Up"]={"Megumi/Melee/Up"},["Megumi/Mahoraga/Melee/Down"]={"Megumi/Melee/Down"},["Megumi/Mahoraga/DivinePummel"]={"Megumi/DivinePummel"},["Megumi/Mahoraga/GroundPitch"]={"Megumi/GroundPitch"},["Megumi/Mahoraga/Earthquake"]={"Megumi/Earthquake"},["Megumi/Mahoraga/Adaptation"]={"Megumi/Adaptation"},["Megumi/MaxElephant"]={"Megumi/MaxElephant"},["Mahito/Melee/Melee1"]={"Mahito/Melee/Melee1"},["Mahito/Melee/Melee2"]={"Mahito/Melee/Melee2"},["Mahito/Melee/Melee3"]={"Mahito/Melee/Melee3"},["Mahito/Melee/Melee4"]={"Mahito/Melee/Melee4"},["Mahito/Melee/Up"]={"Mahito/Melee/Up"},["Mahito/Melee/Down"]={"Mahito/Melee/Down"},["Mahito/Stockpile"]={"Mahito/Stockpile"},["Mahito/Soulfire"]={"Mahito/Soulfire"},["Mahito/FocusStrike"]={"Mahito/FocusStrike"},["Mahito/Variants/Armor/Melee1"]={"Mahito/Melee/Melee1"},["Mahito/Variants/Armor/Melee2"]={"Mahito/Melee/Melee2"},["Mahito/Variants/Armor/Melee3"]={"Mahito/Melee/Melee3"},["Mahito/Variants/Armor/Melee4"]={"Mahito/Melee/Melee4"},["Mahito/Variants/Armor/Up"]={"Mahito/Melee/Up"},["Mahito/Variants/Armor/Down"]={"Mahito/Melee/Down"},["Mahito/Variants/MeleeClub/Melee1"]={"Mahito/Melee/Melee1"},["Mahito/Variants/MeleeClub/Melee2"]={"Mahito/Melee/Melee2"},["Mahito/Variants/MeleeClub/Melee3"]={"Mahito/Melee/Melee3"},["Mahito/Variants/MeleeClub/Melee4"]={"Mahito/Melee/Melee4"},["Mahito/Variants/MeleeClub/Up"]={"Mahito/Melee/Up"},["Mahito/Variants/MeleeClub/Down"]={"Mahito/Melee/Down"},["Mahito/Variants/MeleeSword/Melee1"]={"Mahito/Melee/Melee1"},["Mahito/Variants/MeleeSword/Melee2"]={"Mahito/Melee/Melee2"},["Mahito/Variants/MeleeSword/Melee3"]={"Mahito/Melee/Melee3"},["Mahito/Variants/MeleeSword/Melee4"]={"Mahito/Melee/Melee4"},["Mahito/Variants/MeleeSword/Up"]={"Mahito/Melee/Up"},["Mahito/Variants/MeleeSword/Down"]={"Mahito/Melee/Down"},["Mahito/SelfPerfection"]={"Mahito/SelfPerfection"},["Mahito/BodyRepel"]={"Mahito/BodyRepel"},["Mahito/WideStrike"]={"Mahito/WideSPStrike"},["Mahito/FaceBlitz"]={"Mahito/FaceBlitz"},["Mahito/CrushingRushdown"]={"Mahito/CrushingRushdown"},["Mahito/SpikeWrath"]={"Mahito/SpikeWrath"},["Mahito/HeadSplitter"]={"Mahito/HeadSplitter"},["Todo/Melee/Melee1"]={"Todo/Melee/Melee1"},["Todo/Melee/Melee2"]={"Todo/Melee/Melee2"},["Todo/Melee/Melee3"]={"Todo/Melee/Melee3"},["Todo/Melee/Melee4"]={"Todo/Melee/Melee4"},["Todo/Melee/Up"]={"Todo/Melee/Up"},["Todo/Melee/Down"]={"Todo/Melee/Down"},["Todo/SwiftKick"]={"Todo/SwiftKick"},["Todo/BruteForce"]={"Todo/BruteForce"},["Todo/PebbleThrow"]={"Todo/PebbleThrow"},["Todo/ElbowDrop"]={"Todo/ElbowDrop"},["Todo/IdolDebut"]={"Todo/IdolDebut"},["Todo/ClimaxJump"]={"Todo/ClimaxJump"},["Todo/Dreams"]={"Todo/Dreams"},["Todo/Brothers"]={"Todo/Brothers"},["Heian/Dismantle"]={"Heian/DismantleV2"},["Heian/Kamutoke"]={"Heian/Kamutoke"},["Heian/Melee/Melee1"]={"Heian/Melee/Melee1"},["Heian/Melee/Melee2"]={"Heian/Melee/Melee2"},["Heian/Melee/Melee3"]={"Heian/Melee/Melee3"},["Heian/Melee/Up"]={"Heian/Melee/Up"},["Heian/Melee/Down"]={"Heian/Melee/Down"},["Heian/Melee/Melee4"]={"Heian/Melee/Melee4"},["Locust/Melee/Melee1"]={"Locust/Melee/Melee1"},["Locust/Melee/Melee2"]={"Locust/Melee/Melee2"},["Locust/Melee/Melee3"]={"Locust/Melee/Melee3"},["Locust/Melee/Melee4"]={"Locust/Melee/Melee4"},["Locust/Melee/Up"]={"Locust/Melee/Up"},["Locust/Melee/Down"]={"Locust/Melee/Down"},["Locust/BlackMucus"]={"Locust/BlackMucus"},["Hiromi/ExtendSwing"]={"Hiromi/ExtendSwing"},["Hiromi/Melee/Melee1"]={"Hiromi/Melee/Melee1"},["Hiromi/Melee/Melee2"]={"Hiromi/Melee/Melee2"},["Hiromi/Melee/Melee3"]={"Hiromi/Melee/Melee3"},["Hiromi/Melee/Melee4"]={"Hiromi/Melee/Melee4"},["Hiromi/Melee/Up"]={"Hiromi/Melee/Up"},["Hiromi/Melee/Down"]={"Hiromi/Melee/Down"},["Hiromi/JusticeServed"]={"Hiromi/JusticeServed"},["Hiromi/Execution"]={"Hiromi/Execution"},["Hiromi/Melee2/Melee1"]={"Hiromi/Melee/Melee1"},["Hiromi/Melee2/Melee2"]={"Hiromi/Melee/Melee2"},["Hiromi/Melee2/Melee3"]={"Hiromi/Melee/Melee3"},["Hiromi/Melee2/Melee4"]={"Hiromi/Melee/Melee4"},["Hiromi/Melee2/Up"]={"Hiromi/Melee/Up"},["Hiromi/Melee2/Down"]={"Hiromi/Melee/Down"},["Hiromi/FinalJudgement"]={"Hiromi/FinalJudgement"},["Hiromi/Verdict"]={"Hiromi/Verdict"},["Hiromi/TripleSentence"]={"Hiromi/TripleSentence"},["Hiromi/JudgeReach"]={"Hiromi/JudgeReach"},["Hiromi/PressingCharges"]={"Hiromi/PressingCharges"},["Hiromi/JudgeReach2"]={"Hiromi/JudgeReach"},["Yuki/Melee/Melee1"]={"Yuki/Melee/Melee1"},["Yuki/Melee/Melee2"]={"Yuki/Melee/Melee2"},["Yuki/Melee/Melee3"]={"Yuki/Melee/Melee3"},["Yuki/Melee/Melee4"]={"Yuki/Melee/Melee4"},["Yuki/Melee/Down"]={"Yuki/Melee/Down"},["Yuki/Melee/Up"]={"Yuki/Melee/Up"},["Yuki/GarudaRebound"]={"Yuki/GarudaRebound"},["Yuki/MassBreaker"]={"Yuki/MassBreaker"},["Yuki/GarudaStab"]={"Yuki/GarudaStab"},["Yuki/MeleeOld/Melee1"]={"Yuki/Melee/Melee1"},["Yuki/MeleeOld/Melee2"]={"Yuki/Melee/Melee2"},["Yuki/MeleeOld/Melee3"]={"Yuki/Melee/Melee3"},["Yuki/MeleeOld/Melee4"]={"Yuki/Melee/Melee4"},["Goku/Melee/Down"]={"Goku/Melee/Down"},["Goku/Melee/Melee1"]={"Goku/Melee/Melee1"},["Goku/Melee/Melee2"]={"Goku/Melee/Melee2"},["Goku/Melee/Melee3"]={"Goku/Melee/Melee3"},["Goku/Melee/Melee4"]={"Goku/Melee/Melee4"},["Goku/Melee/Up"]={"Goku/Melee/Up"},["Goku/Kamehameha"]={"Goku/Kamehameha"},["Goku/StaffUppercut"]={"Goku/StaffUppercut"},["Goku/StaffExtend"]={"Goku/StaffExtend"},["Goku/KiSpam"]={"Goku/KiSpam"},["Goku/MeleeUlt/Melee1"]={"Goku/Melee/Melee1"},["Goku/MeleeUlt/Melee2"]={"Goku/Melee/Melee2"},["Goku/MeleeUlt/Melee3"]={"Goku/Melee/Melee3"},["Goku/MeleeUlt/Melee4"]={"Goku/Melee/Melee4"},["Goku/MeleeUlt/Down"]={"Goku/Melee/Down"},["Goku/MeleeUlt/Up"]={"Goku/Melee/Up"},["Yuta/Revolve"]={"Yuta/Revolve"},["Yuta/ResoluteSlash"]={"Yuta/ResoluteSlash"},["Yuta/SeveringPath"]={"Yuta/SeveringPath"},["Yuta/Veilstep"]={"Yuta/Veilstep"},["Yuta/Melee/Melee1"]={"Yuta/Melee/Melee1"},["Yuta/Melee/Melee2"]={"Yuta/Melee/Melee2"},["Yuta/Melee/Melee3"]={"Yuta/Melee/Melee3"},["Yuta/Melee/Up"]={"Yuta/Melee/Up"},["Yuta/Melee/Down"]={"Yuta/Melee/Down"},["Yuta/Melee/Melee4"]={"Yuta/Melee/Melee4"},["Yuta/Rika/Downslam"]={"Yuta/RikaDownslam"},["Yuta/Rika/Haymaker"]={"Yuta/RikaHaymaker"},["Yuta/Rika/LoveBeam"]={"Yuta/LoveBeam"},["Yuta/Rika/ElbowRushRika"]={"Yuta/ElbowRush"},["Yuta/VeilstepDive"]={"Yuta/Veilstep"},["Yuta/SeveringPathAir"]={"Yuta/SeveringPath"},["Yuta/ResoluteSlashTarget"]={"Yuta/ResoluteSlash"},["Yuta/EnergyRipple"]={"Yuta/EnergyRipple"},["Yuta/MeleeUlt/Melee1"]={"Yuta/Melee/Melee1"},["Yuta/MeleeUlt/Melee2"]={"Yuta/Melee/Melee2"},["Yuta/MeleeUlt/Melee3"]={"Yuta/Melee/Melee3"},["Yuta/MeleeUlt/Melee4"]={"Yuta/Melee/Melee4"},["Yuta/MeleeUlt/Down"]={"Yuta/Melee/Down"},["Yuta/MeleeUlt/Up"]={"Yuta/Melee/Up"},["Yuta/Outburst"]={"Yuta/Outburst"},["Charles/Melee/Melee3"]={"Charles/Melee/Melee3"},["Charles/Melee/Melee4"]={"Charles/Melee/Melee4"},["Charles/Melee/Melee2"]={"Charles/Melee/Melee2"},["Charles/Melee/Up"]={"Charles/Melee/Up"},["Charles/Melee/Down"]={"Charles/Melee/Down"},["Charles/Melee/Melee1"]={"Charles/Melee/Melee1"},["Charles/ShutUp"]={"Charles/ShutUp"},["Charles/Despair"]={"Charles/Despair"},["Charles/EyeCatch"]={"Charles/EyeCatch"},["Charles/Sacrilegious"]={"Charles/Sacrilegious"},["Mechamaru/Melee/Melee1"]={"Mechamaru/Melee/Melee1"},["Mechamaru/Melee/Melee2"]={"Mechamaru/Melee/Melee2"},["Mechamaru/Melee/Melee3"]={"Mechamaru/Melee/Melee3"},["Mechamaru/Melee/Melee4"]={"Mechamaru/Melee/Melee4"},["Mechamaru/Melee/Up"]={"Mechamaru/Melee/Up"},["Mechamaru/Melee/Down"]={"Mechamaru/Melee/Down"},["Mechamaru/UltraSpin"]={"Mechamaru/UltraSpin"},["Mechamaru/UltraCannon"]={"Mechamaru/UltraCannon"},["Mechamaru/BoostOnEnd"]={"Mechamaru/BoostOn"},["Mechamaru/Absolute/Melee/Melee1"]={"Mechamaru/Melee/Melee1"},["Mechamaru/Absolute/Melee/Melee2"]={"Mechamaru/Melee/Melee2"},["Mechamaru/Absolute/Melee/Melee3"]={"Mechamaru/Melee/Melee3"},["Mechamaru/Absolute/Melee/Melee4"]={"Mechamaru/Melee/Melee4"},["Mechamaru/Absolute/Melee/Up"]={"Mechamaru/Melee/Up"},["Mechamaru/Absolute/Melee/Down"]={"Mechamaru/Melee/Down"},["Mechamaru/Absolute/Melee/Melee4ALT"]={"Mechamaru/Melee/Melee4"},["Mechamaru/MiracleCannon"]={"Mechamaru/MiracleCannon"},["Mechamaru/PigeonViola"]={"Mechamaru/PigeonViola"},["Mechamaru/BoostOn"]={"Mechamaru/BoostOn"},["Mechamaru/HeatEmission"]={"Mechamaru/HeatEmission"},["Mechamaru/AbsoluteDestruction"]={"Mechamaru/AbsoluteDestruction"},["Mechamaru/AbsoluteDestructionAir"]={"Mechamaru/AbsoluteDestruction"},["Mechamaru/AbsoluteDestructionOLD"]={"Mechamaru/AbsoluteDestruction"},["Mechamaru/MiracleCannonOneYear"]={"Mechamaru/MiracleCannon"},["Naoya/Melee/Melee3"]={"Naoya/Melee/Melee3"},["Naoya/Melee/Melee4"]={"Naoya/Melee/Melee4"},["Naoya/Melee/Melee2"]={"Naoya/Melee/Melee2"},["Naoya/Melee/Up"]={"Naoya/Melee/Up"},["Naoya/Melee/Down"]={"Naoya/Melee/Down"},["Naoya/Melee/Melee1"]={"Naoya/Melee/Melee1"},["Naoya/ProjectionBreaker"]={"Naoya/ProjectionBreaker"},["Naoya/Bleedout"]={"Naoya/Bleedout"},["Naoya/DecisiveStrike"]={"Naoya/DecisiveStrike"},["Naoya/CursoryImpact"]={"Naoya/CursoryImpact"},["Naoya/FlashFreezing"]={"Naoya/FlashFreezing"},["Naoya/TopSpeed"]={"Naoya/TopSpeed"},["Naoya/Melee2/Melee3"]={"Naoya/Melee/Melee3"},["Naoya/Melee2/Melee4"]={"Naoya/Melee/Melee4"},["Naoya/Melee2/Melee2"]={"Naoya/Melee/Melee2"},["Naoya/Melee2/Up"]={"Naoya/Melee/Up"},["Naoya/Melee2/Down"]={"Naoya/Melee/Down"},["Naoya/Melee2/Melee1"]={"Naoya/Melee/Melee1"},["Naoya/TendrilGrab"]={"Naoya/TendrilGrab"},["Naoya/OldProjectionBreaker"]={"Naoya/ProjectionBreaker"},["Nanami/Melee/Melee1"]={"Nanami/Melee/Melee1"},["Nanami/Melee/Melee2"]={"Nanami/Melee/Melee2"},["Nanami/Melee/Melee3"]={"Nanami/Melee/Melee3"},["Nanami/Melee/Melee4"]={"Nanami/Melee/Melee4"},["Nanami/Melee/Up"]={"Nanami/Melee/Up"},["Nanami/Melee/Down"]={"Nanami/Melee/Down"},["Nanami/CleavingWhirlwind"]={"Nanami/CleavingWhirl"},["Nanami/SeveranceKick"]={"Nanami/SeveranceKick"},["Nanami/Stabilize"]={"Nanami/Stabilize"},["Nanami/BluntCut"]={"Nanami/BluntCut"},["Nanami/MeleeUlt/Melee1"]={"Nanami/Melee/Melee1"},["Nanami/MeleeUlt/Melee2"]={"Nanami/Melee/Melee2"},["Nanami/MeleeUlt/Melee3"]={"Nanami/Melee/Melee3"},["Nanami/MeleeUlt/Melee4"]={"Nanami/Melee/Melee4"},["Nanami/MeleeUlt/Up"]={"Nanami/Melee/Up"},["Nanami/MeleeUlt/Down"]={"Nanami/Melee/Down"},["Nanami/RatioBreaker/RatioBreak1"]={"Nanami/RatioBreaker"},["Nanami/RatioBreaker/RatioBreak2"]={"Nanami/RatioBreaker"},["Nanami/RatioBreaker/RatioBreak3"]={"Nanami/RatioBreaker"},["Nanami/RatioBreaker/RatioBreak4"]={"Nanami/RatioBreaker"},["Nanami/Collapse"]={"Nanami/Collapse"},["Nanami/Sharpen"]={"Nanami/Sharpen"},["Nanami/Interrogate"]={"Nanami/Interrogate"},["Haruta/Backstab"]={"Haruta/Backstab"},["Haruta/Melee/Melee1"]={"Haruta/Melee/Melee1"},["Haruta/Melee/Melee2"]={"Haruta/Melee/Melee2"},["Haruta/Melee/Melee3"]={"Haruta/Melee/Melee3"},["Haruta/Melee/Melee4"]={"Haruta/Melee/Melee4"},["Haruta/Melee/Up"]={"Haruta/Melee/Up"},["Haruta/Melee/Down"]={"Haruta/Melee/Down"},["Haruta/Hand/AnkleCutter"]={"Haruta/AnkleCutter"},["Haruta/Hand/HighTime"]={"Haruta/HighTime"},["Haruta/CheapShot"]={"Haruta/CheapShot"},["Haruta/Trip"]={"Haruta/Trip"},["Haruta/Ambush"]={"Haruta/Ambush"},["MeiMei/Melee/Melee1"]={"MeiMei/Melee/Melee1"},["MeiMei/Melee/Melee2"]={"MeiMei/Melee/Melee2"},["MeiMei/Melee/Melee3"]={"MeiMei/Melee/Melee3"},["MeiMei/Melee/Melee4"]={"MeiMei/Melee/Melee4"},["MeiMei/Melee/Up"]={"MeiMei/Melee/Up"},["MeiMei/Melee/Down"]={"MeiMei/Melee/Down"},["MeiMei/ImpetusUpdraft"]={"MeiMei/ImpetusUpdraft"},["MeiMei/Circling"]={"MeiMei/Circling"},["MeiMei/Murmurate"]={"MeiMei/Murmurate"},["Hanami/Melee/Melee1"]={"Hanami/Melee/Melee1"},["Hanami/Melee/Melee2"]={"Hanami/Melee/Melee2"},["Hanami/Melee/Melee3"]={"Hanami/Melee/Melee3"},["Hanami/Melee/Melee4"]={"Hanami/Melee/Melee4"},["Hanami/Melee/Up"]={"Hanami/Melee/Up"},["Hanami/Melee/Down"]={"Hanami/Melee/Down"},["Hanami/RootSwarm"]={"Hanami/RootSwarm"},["Hanami/FlowerField"]={"Hanami/FlowerField"},["Hanami/BudShot"]={"Hanami/BudShot"},["Hanami/DefenseResponse"]={"Hanami/DefenseResponse"},["Hanami/SurgingThorns"]={"Hanami/SurgingThorns"},["Hanami/CursedBudsTree"]={"Hanami/CursedBuds"},["Hanami/CursedBuds"]={"Hanami/CursedBuds"},["Hanami/MeleeUlt/Melee1"]={"Hanami/Melee/Melee1"},["Hanami/MeleeUlt/Melee2"]={"Hanami/Melee/Melee2"},["Hanami/MeleeUlt/Melee3"]={"Hanami/Melee/Melee3"},["Hanami/MeleeUlt/Melee4"]={"Hanami/Melee/Melee4"},["Hanami/MeleeUlt/Up"]={"Hanami/Melee/Up"},["Hanami/MeleeUlt/Down"]={"Hanami/Melee/Down"},["Hanami/RootRampage"]={"Hanami/RootRampage"},["Ryu/Melee/Melee2"]={"Ryu/Melee/Melee2"},["Ryu/Melee/Melee1"]={"Ryu/Melee/Melee1"},["Ryu/Melee/Melee3"]={"Ryu/Melee/Melee3"},["Ryu/Melee/Up"]={"Ryu/Melee/Up"},["Ryu/Melee/Down"]={"Ryu/Melee/Down"},["Ryu/Melee/Melee3_2"]={"Ryu/Melee/Melee3"},["Ryu/GraniteBlast"]={"Ryu/GraniteBlast"},["Ryu/Unsatisfied"]={"Ryu/Unsatisfied"},["Ryu/HadNoIdea"]={"Ryu/HadNoIdea"},["Ryu/Appetizer"]={"Ryu/Appetizer"},["Ryu/WhatAreYouAfter"]={"Ryu/WhatAreYouAfter"},["Ryu/SecondHelping"]={"Ryu/SecondHelping"},["Ryu/ThisDessert"]={"Ryu/ThisDessert"},["Ryu/WerentInvited"]={"Ryu/WerentInvited"},["Kurourushi/Melee/Melee1"]={"Kurourushi/Melee/Melee1"},["Kurourushi/Melee/Melee2"]={"Kurourushi/Melee/Melee2"},["Kurourushi/Melee/Melee3"]={"Kurourushi/Melee/Melee3"},["Kurourushi/Melee/Melee4"]={"Kurourushi/Melee/Melee4"},["Kurourushi/Melee/Up"]={"Kurourushi/Melee/Up"},["Kurourushi/Melee/Down"]={"Kurourushi/Melee/Down"},["Kurourushi/ArmsMelee/Melee2"]={"Kurourushi/Melee/Melee2"},["Kurourushi/ArmsMelee/Melee3"]={"Kurourushi/Melee/Melee3"},["Kurourushi/ArmsMelee/Melee4"]={"Kurourushi/Melee/Melee4"},["Kurourushi/ArmsMelee/Up"]={"Kurourushi/Melee/Up"},["Kurourushi/ArmsMelee/Down"]={"Kurourushi/Melee/Down"},["Kurourushi/FesteringStrikes"]={"Kurourushi/FesteringStrikes"},["Kurourushi/Chokehold"]={"Kurourushi/Chokehold"},["Kurourushi/RoachSwarm"]={"Kurourushi/RoachSwarm"},["Kurourushi/Detach"]={"Kurourushi/Detach"},["Kurourushi/MeleeDetach/Melee1"]={"Kurourushi/Melee/Melee1"},["Kurourushi/MeleeDetach/Melee2"]={"Kurourushi/Melee/Melee2"},["Kurourushi/MeleeDetach/Melee3"]={"Kurourushi/Melee/Melee3"},["Kurourushi/MeleeDetach/Melee4"]={"Kurourushi/Melee/Melee4"},["Kurourushi/MeleeDetach/Up"]={"Kurourushi/Melee/Up"},["Kurourushi/MeleeDetach/Down"]={"Kurourushi/Melee/Down"},["Kurourushi/ArmsDetach/Melee2"]={"Kurourushi/Melee/Melee2"},["Kurourushi/ArmsDetach/Melee3"]={"Kurourushi/Melee/Melee3"},["Kurourushi/ArmsDetach/Melee4"]={"Kurourushi/Melee/Melee4"},["Kurourushi/ArmsDetach/Up"]={"Kurourushi/Melee/Up"},["Kurourushi/ArmsDetach/Down"]={"Kurourushi/Melee/Down"},["Kurourushi/ArmsDetach/Melee1"]={"Kurourushi/Melee/Melee1"},["Kurourushi/FesteringStrikesArms"]={"Kurourushi/FesteringStrikes"},["Reggie/Melee/Melee1"]={"Reggie/Melee/Melee1"},["Reggie/Melee/Melee2"]={"Reggie/Melee/Melee2"},["Reggie/Melee/Melee3"]={"Reggie/Melee/Melee3"},["Reggie/Melee/Melee4"]={"Reggie/Melee/Melee4"},["Reggie/Melee/Up"]={"Reggie/Melee/Up"},["Reggie/Melee/Down"]={"Reggie/Melee/Down"},["Reggie/GushingWound"]={"Reggie/GushingWound"},["Reggie/Homerun"]={"Reggie/Homerun"},["Reggie/PianoDrop"]={"Reggie/PianoDrop"},["Reggie/GarageSale"]={"Reggie/GarageSale"},["Reggie/BluntTrauma"]={"Reggie/BluntTrauma"},["Reggie/SpeedCrash"]={"Reggie/SpeedCrash"},["Reggie/Fleche"]={"Reggie/Fleche"},["Reggie/Drone/DroneStrikeStart"]={"Reggie/DroneStrike"},["Reggie/PoleVault"]={"Reggie/PoleVault"},["Reggie/Mayhem"]={"Reggie/Mayhem"},["Reggie/BigMoves"]={"Reggie/BigMoves"},["Reggie/Arson"]={"Reggie/Arson"},["Uro/BlindRage"]={"Uro/BlindRage"},["Uro/ThinIceBreaker"]={"Uro/ThinIceBreaker"},["Uro/Melee/Melee1"]={"Uro/Melee/Melee1"},["Uro/Melee/Melee2"]={"Uro/Melee/Melee2"},["Uro/Melee/Melee3"]={"Uro/Melee/Melee3"},["Uro/Melee/Melee4"]={"Uro/Melee/Melee4"},["Uro/Melee/Up"]={"Uro/Melee/Up"},["Uro/Melee/Down"]={"Uro/Melee/Down"},["Uro/Melee2/Melee1"]={"Uro/Melee/Melee1"},["Uro/Melee2/Melee2"]={"Uro/Melee/Melee2"},["Uro/Melee2/Melee3"]={"Uro/Melee/Melee3"},["Uro/Melee2/Melee4"]={"Uro/Melee/Melee4"},["Uro/ThinIceBreaker2"]={"Uro/ThinIceBreaker"},["Uro/ThinIceBreaker2Sky"]={"Uro/ThinIceBreaker"},["Uro/SkyDistortion"]={"Uro/SkyDistortion"}},["Services"]={["GojoService"]="Gojo/Gojo",["ReversalRedService"]="Gojo/ReversalRed",["LapseBlueService"]="Gojo/LapseBlue",["RapidPunchesService"]="Gojo/RapidPunches",["TwofoldKickService"]="Gojo/TwofoldKick",["InfiniteVoidService"]="Gojo/InfiniteVoid",["HollowPurpleService"]="Gojo/HollowPurple",["LapseBlueMaxService"]="Gojo/LapseBlueMax",["ReversalRedMaxService"]="Gojo/ReversalRedMax",["ItadoriService"]="Itadori/Itadori",["CrushingBlowService"]="Itadori/CrushingBlow",["DivergentFistService"]="Itadori/DivergentFist",["ManjiKickService"]="Itadori/ManjiKick",["CursedStrikesService"]="Itadori/CursedStrikes",["MalevolantShrineService"]="Itadori/MalevolantShrine",["FlameArrowService"]="Itadori/FlameArrow",["RushService"]="Itadori/Rush",["DismantleService"]="Itadori/Dismantle",["HakariService"]="Hakari/Hakari",["ShutterDoorService"]="Hakari/ShutterDoors",["ReserveBallService"]="Hakari/ReserveBall",["RoughEnergyService"]="Hakari/RoughEnergy",["FeverBreakerService"]="Hakari/FeverBreaker",["LuckyVolleyService"]="Hakari/LuckyVolley",["LuckyRushdownService"]="Hakari/LuckyRushdown",["OverLuckService"]="Hakari/OverLuck",["EnergySurgeService"]="Hakari/EnergySurge",["MegumiService"]="Megumi/Megumi",["RabbitEscapeService"]="Megumi/RabbitEscape",["NueService"]="Megumi/Nue",["ToadService"]="Megumi/Toad",["DivineDogService"]="Megumi/DivineDog",["ShadowSwarmService"]="Megumi/ShadowSwarm",["MaxElephantService"]="Megumi/MaxElephant",["GreatSerpentService"]="Megumi/GreatSerpent",["MahoragaUseService"]="Megumi/MahoragaUse",["MahoragaService"]="Megumi/Mahoraga",["DivinePummelService"]="Megumi/DivinePummel",["GroundPitchService"]="Megumi/GroundPitch",["EarthquakeService"]="Megumi/Earthquake",["AdaptationService"]="Megumi/Adaptation",["MahitoService"]="Mahito/Mahito",["StockpileService"]="Mahito/Stockpile",["SoulfireService"]="Mahito/Soulfire",["FocusStrikeService"]="Mahito/FocusStrike",["BodyRepelService"]="Mahito/BodyRepel",["WideSPStrikesService"]="Mahito/WideSPStrike",["FaceBlitzService"]="Mahito/FaceBlitz",["CrushingRushdownService"]="Mahito/CrushingRushdown",["HeadSplitterService"]="Mahito/HeadSplitter",["IdleTransfigurationService"]="Mahito/IdleTransfiguration",["BodyDisfigureService"]="Mahito/BodyDisfigure",["SelfPerfectionService"]="Mahito/SelfPerfection",["SpikeWrathService"]="Mahito/SpikeWrath",["ChosoService"]="Choso/Choso",["SupernovaService"]="Choso/Supernova",["RedScaleService"]="Choso/RedScale",["PiercingBloodService"]="Choso/PiercingBlood",["BloodEdgeService"]="Choso/BloodEdge",["SlicingExorcismService"]="Choso/SlicingExorcism",["BloodRainService"]="Choso/BloodRain",["WingKingService"]="Choso/WingKing",["PlasmaWaveService"]="Choso/PlasmaWave",["TodoService"]="Todo/Todo",["SwiftKickService"]="Todo/SwiftKick",["BruteForceService"]="Todo/BruteForce",["PebbleThrowService"]="Todo/PebbleThrow",["ElbowDropService"]="Todo/ElbowDrop",["IdolDebutService"]="Todo/IdolDebut",["ClimaxJumpService"]="Todo/ClimaxJump",["DreamsService"]="Todo/Dreams",["BrothersService"]="Todo/Brothers",["HeianService"]="Heian/Heian",["DismantleV2Service"]="Heian/DismantleV2",["FurnaceArrowService"]="Heian/FurnaceArrow",["CleaveRushService"]="Heian/CleaveRush",["KamutokeService"]="Heian/Kamutoke",["LocustService"]="Locust/Locust",["BlackMucusService"]="Locust/BlackMucus",["CleverService"]="Locust/Clever",["CrushJawService"]="Locust/CrushJaw",["WingThrowService"]="Locust/WingThrow",["HiromiService"]="Hiromi/Hiromi",["ExtendSwingService"]="Hiromi/ExtendSwing",["JusticeServedService"]="Hiromi/JusticeServed",["PressingChargesService"]="Hiromi/PressingCharges",["JudgeReachService"]="Hiromi/JudgeReach",["ExecutionService"]="Hiromi/Execution",["FinalJudgementService"]="Hiromi/FinalJudgement",["VerdictService"]="Hiromi/Verdict",["TripleSentenceService"]="Hiromi/TripleSentence",["YukiService"]="Yuki/Yuki",["GarudaReboundService"]="Yuki/GarudaRebound",["MassBreakerService"]="Yuki/MassBreaker",["RisingRageService"]="Yuki/RisingRage",["GarudaStabService"]="Yuki/GarudaStab",["YutaService"]="Yuta/Yuta",["RevolveService"]="Yuta/Revolve",["ResoluteSlashService"]="Yuta/ResoluteSlash",["VeilstepService"]="Yuta/Veilstep",["SeveringPathService"]="Yuta/SeveringPath",["OutburstService"]="Yuta/Outburst",["EnergyRippleService"]="Yuta/EnergyRipple",["RikaDownslamService"]="Yuta/RikaDownslam",["RikaLaunchService"]="Yuta/RikaLaunch",["RikaHaymakerService"]="Yuta/RikaHaymaker",["RikaLoveBeamService"]="Yuta/RikaLoveBeam",["RikaSlamService"]="Yuta/RikaSlam",["RikaGrabService"]="Yuta/RikaGrab",["RikaThrowService"]="Yuta/RikaThrow",["LoveBeamService"]="Yuta/LoveBeam",["MutualLoveService"]="Yuta/MutualLove",["ElbowRushService"]="Yuta/ElbowRush",["CopyService"]="Yuta/Copy",["GokuService"]="Goku/Goku",["KamehamehaService"]="Goku/Kamehameha",["StaffUppercutService"]="Goku/StaffUppercut",["StaffExtendService"]="Goku/StaffExtend",["KiSpamService"]="Goku/KiSpam",["CharlesService"]="Charles/Charles",["DespairService"]="Charles/Despair",["ShutUpService"]="Charles/ShutUp",["EyeCatchService"]="Charles/EyeCatch",["SacrilegiousService"]="Charles/Sacrilegious",["MechamaruService"]="Mechamaru/Absolute",["UltraSpinService"]="Mechamaru/UltraSpin",["UltraCannonService"]="Mechamaru/UltraCannon",["BoostOnService"]="Mechamaru/BoostOn",["HeatEmissionService"]="Mechamaru/HeatEmission",["MiracleCannonService"]="Mechamaru/MiracleCannon",["PigeonViolaService"]="Mechamaru/PigeonViola",["AbsoluteDestructionService"]="Mechamaru/AbsoluteDestruction",["TechniqueChargeService"]="Mechamaru/TechniqueCharge",["NaoyaService"]="Naoya/Naoya",["BleedoutService"]="Naoya/Bleedout",["DecisiveStrikeService"]="Naoya/DecisiveStrike",["ProjectionBreakerService"]="Naoya/ProjectionBreaker",["CursoryImpactService"]="Naoya/CursoryImpact",["TopSpeedService"]="Naoya/TopSpeed",["TendrilGrabService"]="Naoya/TendrilGrab",["TimeCellMoonPalaceService"]="Naoya/TimeCellMoonPalace",["FlashFreezingService"]="Naoya/FlashFreezing",["NanamiService"]="Nanami/Nanami",["CleavingWhirlService"]="Nanami/CleavingWhirl",["SeveranceKickService"]="Nanami/SeveranceKick",["BluntCutService"]="Nanami/BluntCut",["StabilizeService"]="Nanami/Stabilize",["CollapseService"]="Nanami/Collapse",["SharpenService"]="Nanami/Sharpen",["InterrogateService"]="Nanami/Interrogate",["RatioBreakerService"]="Nanami/RatioBreaker",["HarutaService"]="Haruta/Haruta",["CheapShotService"]="Haruta/CheapShot",["BackstabService"]="Haruta/Backstab",["AmbushService"]="Haruta/Ambush",["TripService"]="Haruta/Trip",["AnkleCutterService"]="Haruta/AnkleCutter",["HighTimeService"]="Haruta/HighTime",["HanamiService"]="Hanami/Hanami",["RootSwarmService"]="Hanami/RootSwarm",["DefenseResponseService"]="Hanami/DefenseResponse",["SurgingThornsService"]="Hanami/SurgingThorns",["BudShotService"]="Hanami/BudShot",["CursedBudsService"]="Hanami/CursedBuds",["FlowerBeamService"]="Hanami/FlowerBeam",["SeaOfBranchesService"]="Hanami/SeaOfBranches",["RootRampageService"]="Hanami/RootRampage",["FlowerFieldService"]="Hanami/FlowerField",["MeiMeiService"]="MeiMei/MeiMei",["ImpetusUpdraftService"]="MeiMei/ImpetusUpdraft",["CirclingService"]="MeiMei/Circling",["MurmurateService"]="MeiMei/Murmurate",["BirdControlService"]="MeiMei/BirdControl",["RyuService"]="Ryu/Ryu",["UnsatisfiedService"]="Ryu/Unsatisfied",["GraniteBlastService"]="Ryu/GraniteBlast",["AppetizerService"]="Ryu/Appetizer",["SecondHelpingService"]="Ryu/SecondHelping",["HadNoIdeaService"]="Ryu/HadNoIdea",["WhatAreYouAfterService"]="Ryu/WhatAreYouAfter",["ThisDessertService"]="Ryu/ThisDessert",["WerentInvitedService"]="Ryu/WerentInvited",["KurourushiService"]="Kurourushi/Kurourushi",["FesteringStrikesService"]="Kurourushi/FesteringStrikes",["ChokeholdService"]="Kurourushi/Chokehold",["RoachSwarmService"]="Kurourushi/RoachSwarm",["DetachService"]="Kurourushi/Detach",["ReggieService"]="Reggie/Reggie",["GushingWoundService"]="Reggie/GushingWound",["PianoDropService"]="Reggie/PianoDrop",["HomerunService"]="Reggie/Homerun",["DroneStrikeService"]="Reggie/DroneStrike",["GarageSaleService"]="Reggie/GarageSale",["BluntTraumaService"]="Reggie/BluntTrauma",["SpeedCrashService"]="Reggie/SpeedCrash",["FlecheService"]="Reggie/Fleche",["PoleVaultService"]="Reggie/PoleVault",["MayhemService"]="Reggie/Mayhem",["BigMovesService"]="Reggie/BigMoves",["ArsonService"]="Reggie/Arson",["UroService"]="Uro/Uro",["BlindRageService"]="Uro/BlindRage",["ThinIceBreakerService"]="Uro/ThinIceBreaker",["SkyDistortionService"]="Uro/SkyDistortion"},["Counts"]={["Profiles"]=348,["MappedIds"]=356,["NativeServices"]=204,["ClassifiedProfiles"]=316,["WikiMatchedProfiles"]=173,["MeleeProfiles"]=143,["UnknownProfiles"]=32}}
Combat.CosmeticCatalog={["Emotes"]={"1A","2026","3024","61","67","A Mimir?","ABA","Absolute Cinema","Air Drone","Aizo","Alien","Are you","Aura Monster","Awkward","Backflip","Baldi","BANG","Bang!","Basketball","Bass da da da","Bathtub","Beat It","Big Misser","Big Shoe","Billy Bounce","Bird","Birdbrain","Bizarre","Bizarre Duo","Bizarre2","Bling","Blue Sky","Boom Mic","Boombox","Bow","Bow2","Bow3","Bowedown","Boxer","Brain","Brainrot","Brazilian Calisthenics","Breakdance","Briefcase","Brightest heart","Broke","Broom","Bubble Blower","Buggin","Burger","Burnice","Cake","California girls","Camcorder","Camera","Caramelldansen","Cardboard","Carousel","Carry","Chainsaw Run","Chalk Toss","Challenger","Champion","Chaos Emerald","Chaos King","Charge","Cherry Dance","Chest Bump","Chill","Chill2","Chips Brand","Chirumiru","Chronoshift","Clap","Clash1","Clash2","Coin","Coinflip","Comedian","Competent","Confess","Conga","Cookie","Cooking","Cooking Granny","Crane","Crazy","Crow","Cry For Me","Cursed Child","Cursed Instincts","Cursed Walk","Dance Alone","DARE","Dark Zone","Dead Or Alive","Dead Wrong","Delightful","Democracy","Demon","Demon Dance","Development","Devil Hunter","Diamond in the sky","Did you see that","Die Of Death","Disobedience","Distraction","Do the bartman","Dogsync","Don't be Afraid","Doomer","Drag","Dragon","Dream Friends","Drums","Egghead's Endeavor","Eggrolled","Electro Shuffle","Endoskeleton","Entry Flow","Envelope","Equestria","Everyone Is Dancing!","Ex Provocation","Excuse me sir","Extinguish","Facepalm","Feline Finder","Finger Stand","Finger Wag","Flop","Flow","Fumo","Fumokill","Fusion Dance","Gang Flex","Gangdance","Ganon","Garbage","Garry","Gentlemen Swing","Gera Gera Po","Ghosts","Ghouls","Give it a week","Glass Heart","Gravestone","Greedler","Grillify","Ground Drone","Gubby","Guidance","Guy","Haircut","Hard Jump","Headphones","Heart","Heart111","Heartbeat Heartbreak","Hei Party","Helicopter","Hexed","High Five","Hippocampal Reload","Homelander","Honored","Hoof Shuffle","Hop On JJS","Hopping","how tze was moving","Hug","Hugo","Humming The Baseline","Hype","I Am A Human","i hate you","I Miss The Quiet","Im All Ears","Im Old","In My Mind","Insane","Insane2","Insanity","Iris Out","Iris Out2","Irishima Talk","It's Going Down","ITS NO USE","I´M REAL","Jackpot","Jackpot2","Jax Toy","Jeep","Jevil","Jiggy","Join us for a bite","Jolly","Jumper","Jumpscared","JumpStyle","Kawaii","Kazotsky Kick","Kick Back","Kikufuku","Kill Me Baby","Killbind","King Of Curses","Lag Train","Legend1","Legend2","Lemon Cookie","Lethal","Lets Groove","Liar Dancer","Lightsticks","Livesey Walk","Lob","Lonely","Looping","Lord Verity","Lost Media","Love","Low Cortisol","LuckStar","Lying Rage","Macarena","Malo Mart","Mannrobics","Mayhem","Mechanism","Meditation","Megaphone","Menacing","MESMERIZED","Message","Mew Mew","Miko","Mirror World","Miss Me","Missing","Mochi Maker","Mockery","Modulo","Moneyfan","Moneylender","Moonwalk","More","Mourning","Mozzarella","Muffin Time","Murder","Mustard","Mystery","Na na boo boo","Neco Arc","Nervous","Neurotoxin","Nevada Madness","Ninja","Nuh Uh!","Objection","Oddloop","OKTOBERFEST","Omega Flowery","ON TOP","Onion","OPP","PACED","Paradise","Paradise2","Paradise3","Party","Peace Sign","Penguin","Pepe","Perfect","Petal Dance","Photographer","Photos","Piano","Pickaxe","Piggyback","Pipebomb","Pistol Trick","Pitchfork Protest","Places","Plate of trash","Pocoyo","Pokedance","Pony Story","Popcorn","Popipo","Popstep","Potential","Potential2","Potential3","Potion","Power","Prop Hunt","Provocation","Psychic Run","Psycho","Pumpkin Carve","Pumpkin Show","Pyramid","Ragdoll","RAHHH","Rainwalk","Rat Dance","Reader","Reclassed","Retrial","Retro Party","RIA 2026","Richard","Ringtone","Roach","Rocks","Role","Role2","Saiyan Walk","Salesman","Sanitizer","Sasageyo","Science","Score","Scripture","Seat Depression","Secret Technique","Selfie","SH3NANIGANS","Ship","Shout","Show me ya moves","Shuba Duck","Shwifty","Sidepot","Silly","simply walk around it","Sinister Laugh","Sit","Sit2","Skeleton Hands","Slasher","Slipbeat","Smooth Criminal","Smug","Snake","Snap","Sneeze","Soda Pop","Spare Change","Specialist","Speed Feat","Speedster","Spider","Spin","Spin2","Split","Spoken For","Spooky Month","Spooky Skeleton","Sprint","St Solis","Stance","Stand Proud","Star Power","Starlit","Static","Stomp","Streamer Adventures","Streetcat","Stretch","Stretch2","Strike A Taunt","Strongest of History","Strongest of Today","Sturdy","Stylish","Sugawara","Sunglasses","Superstar1","Superstar2","Superstar3","Suspicious","Swap","Sword Surfing","Symbol Of Peace","Taka la","Take My Hat","Taunt","Team Create","Temmie Dance","TestEmote","Teto","The Forbidden Pen","The Great Captain","Thriller","Throne","Thunder","Tick Tock","Tiger","Tired","Tomodachi","Tomodachi2","Train","Trick or Treat","TrickyDJ","True Curse","True Self","Trumpet","Trust Me","Turbo","Turron","TV Time","UFO","Ultimate Being","Unlicensed","Unlicensed2","Unlicensed3","Unlucky","Unyeah!","Update","Upside down","Vance","Vessel","VESSELLL","Victory","Virtual Insanity","Wait","WAR GIRL","Warfstache","Watashi","We Are Here","We see the fit","Welcome Back","When","Windy","Winner","Wonderland","Worm","Worried","Woven Insight","Yamcha","Yeah!","Yo-Yo Walk"},["Titles"]={"CONTENT CREATOR","CONTRIBUTOR","DEVELOPER","GAMBLER","GRADE 1","GRADE 2","GRADE 3","HEAD MODERATOR","I AM NOT TZE","MODERATOR","OVERCOOKER","SEMI-GRADE 1","SEMI-GRADE 2","SPECIAL GRADE","TESTER","THE STRONGEST AVAILABLE","THE STRONGEST OF HISTORY","THE STRONGEST OF TODAY"},["MVP"]={"Stand Proud","King Of Curses","Domain Invasion","Watch Your Head","Phenomenal","Meditation","Stalemate Collapse","True Value"}}

Combat.RosterEffects = {}
Combat.RosterEffectKeys = setmetatable({}, {__mode = "k"})
Combat.RosterConnections = setmetatable({}, {__mode = "k"})
Combat.EnemyRatios = setmetatable({}, {__mode = "k"})

function Combat:WithGuardTarget(target, callback, ...)
    local thread = coroutine.running() or self
    local previous = self.MouseContexts[thread]
    self.MouseContexts[thread] = {Route = "guard", Target = target, Character = LocalPlayer.Character, Generation = characterGeneration}
    local result = table.pack(pcall(callback, ...))
    self.MouseContexts[thread] = previous
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end

function Combat:RosterProfile(track, target)
    local _, id = self:AttackFlags(track)
    local keys = self.Roster.ById[id]
    if not keys then return nil, id end
    local char = target and target:GetAttribute("Moveset")
    local found
    for _, key in ipairs(keys) do
        local profile = self.Roster.Profiles[key]
        if profile and (profile.Character == char or char == nil) then
            if found and found.Block ~= profile.Block then return nil, id end
            found = profile
        end
    end
    return found, id
end

function Combat:IndexRosterAnimation(animation)
    local folder = ReplicatedStorage:FindFirstChild("Animations")
    if not folder or not animation:IsDescendantOf(folder) then return end
    local pieces, cursor = {}, animation
    while cursor and cursor ~= folder do table.insert(pieces, 1, cursor.Name); cursor = cursor.Parent end
    local keys = self.Roster.ByPath[table.concat(pieces, "/")]
    if not keys then return end
    local raw = animation.AnimationId
    local digits = type(raw) == "string" and (string.match(raw, "rbxassetid://(%d+)") or string.match(raw, "[?&]id=(%d+)") or string.match(raw, "^(%d+)$"))
    if not digits or tonumber(digits) == 0 then
        if not self.PendingAnimationIds[animation] then
            self.PendingAnimationIds[animation] = connect(animation:GetPropertyChangedSignal("AnimationId"), "streamed attack asset ID", function()
                self:IndexRosterAnimation(animation)
            end)
        end
        return
    end
    local id = "rbxassetid://" .. digits
    local current = self.Roster.ById[id]
    if not current then current = {}; self.Roster.ById[id] = current; self.Stats.RuntimeAttackIds = (self.Stats.RuntimeAttackIds or 0) + 1 end
    for _, key in ipairs(keys) do if not table.find(current, key) then table.insert(current, key) end end
    local connection = self.PendingAnimationIds[animation]
    if connection then connection:Disconnect(); self.PendingAnimationIds[animation] = nil end
end

function Combat:RosterBlockClass(profile, target)
    local class = profile.Block
    local hum = getHumanoid(target)
    if profile.AirBlock and hum and hum.FloorMaterial == Enum.Material.Air then class = profile.AirBlock end
    local ratio = self.EnemyRatios[target]
    if ratio and (os.clock() > ratio.Expires or not ratio.Token.Parent or ratio.Character ~= LocalPlayer.Character) then
        self.EnemyRatios[target] = nil; ratio = nil
    end
    if ratio and ratio.Token.Value == true and profile.Character == "Nanami"
        and (profile.Name == "Cleaving Whirlwind" or profile.Name == "Blunt Cut" or profile.Name == "Stabilize") then return "none" end
    return class
end

function Combat:RosterThreatActive(threat, now)
    local track, profile = threat.Track, threat.Profile
    if not track or track.IsPlaying ~= true then return false end
    if profile then
        local class = self:RosterBlockClass(profile, threat.Target)
        if class == "none" or class == "counter" then return false end
        if threat.LiveToken and not threat.LiveToken.Parent then return false end
        if threat.EffectExpires then return now <= threat.EffectExpires end
        if class ~= "unknown" then
            local position = finiteNumber(track.TimePosition) and track.TimePosition or now - threat.Started
            local length = finiteNumber(track.Length) and track.Length > 0 and track.Length or profile.Window
            local finish = profile.Melee and math.min(length + .08, .65) or math.max(0, length - math.min(.12, length * .08))
            local lead = math.clamp(self:PingMilliseconds() / 2000, 0, .25)
            return position <= finish + lead
        end
    end
    local flags, id = self:AttackFlags(track)
    threat.Flags, threat.Label = flags, id
    if bit32.band(flags, 2) ~= 0 then return true end
    if bit32.band(flags, 1) == 0 then return false end
    local hum = getHumanoid(threat.Target)
    local air = hum and hum.FloorMaterial == Enum.Material.Air
    return (not self.TBOGroundOnly[id] or not air) and (not self.TBOAirOnly[id] or air)
        and (not finiteNumber(track.Length) or track.Length <= 0 or track.TimePosition <= track.Length + .08)
end

function Combat:RosterApproaching(threat, ownRoot, enemyRoot)
    local profile = threat.Profile
    if profile and profile.Radial then return true end
    local delta = ownRoot.Position - enemyRoot.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude < .1 then return true end
    local aim = threat.AimFrame or enemyRoot.CFrame
    local look = aim.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude < .01 then return false end
    local dot = forward.Unit:Dot(flat.Unit)
    -- A real attack animation alone does not mean its owner is attacking us.
    -- Use the native aim frame when supplied, with velocity fallback for dashes.
    local width = profile and profile.Ranged and 5 or 7
    if dot > .1 and (not profile or not profile.Ranged or flat.Magnitude * math.sqrt(math.max(0, 1-dot*dot)) <= width) then return true end
    local velocity = enemyRoot.AssemblyLinearVelocity
    if typeof(velocity) == "Vector3" then
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
        if horizontal.Magnitude > 12 and horizontal.Unit:Dot(flat.Unit) > .9 then return true end
    end
    return false
end

function Combat:OnRosterEffect(service, effect, ...)
    self:OnTodoBlackFlashEffect(service, effect, ...)
    self:OnBlackFlashEffect(service, effect, ...)
    local args, char = table.pack(...), LocalPlayer.Character
    if service == "NanamiService" and effect == "SpawnRatio" and args[2] == char then
        local owner, token = args[1], args[4]
        local model = typeof(owner) == "Instance" and (owner:IsA("Player") and owner.Character or owner) or nil
        if model and model ~= char and typeof(token) == "Instance" and token:IsA("BoolValue") then
            self.EnemyRatios[model] = {Token = token, Character = char, Expires = os.clock() + 6}
        end
        return
    end
    if service == "TodoService" then self:OnTodoSwapEffect(effect, ...) end
    if service == "CursedStrikesService" then self:OnCursedStrikeEffect(effect, ...) end
    local key = self.Roster.Services[service]
    local profile = key and self.Roster.Profiles[key]
    -- Interrogate's grab is unblockable; its unenhanced final swing has a
    -- separate native phase. p14 distinguishes the Black Flash enhancement.
    if profile and service == "InterrogateService" and effect == "FinalSwing" then
        profile = table.clone(profile)
        profile.Block, profile.Phases, profile.Window = args[3] == true and "none" or "block", {"FinalSwing"}, .35
        profile.Name = "Interrogate: final swing"
    end
    if not profile or not table.find(profile.Phases or {}, effect) then return end
    if profile.Block == "none" or profile.Block == "counter" or profile.Block == "unknown" then return end
    local actor
    for index = 1, math.min(args.n, 2) do
        local value = args[index]
        if typeof(value) == "Instance" and value:IsA("Model") and getHumanoid(value) then actor = value; break end
    end
    if not actor or actor == char or not actor.Parent then return end
    local own, enemy = getRoot(char), getRoot(actor)
    if not own or not enemy or (own.Position-enemy.Position).Magnitude > 80 then return end
    if Autos.DefenceLockedOnly and (not isActive or actor ~= lockedTarget) then return end
    local aim
    for index = 2, math.min(args.n, 4) do if typeof(args[index]) == "CFrame" then aim = args[index]; break end end
    local now = os.clock()
    local keys = self.RosterEffectKeys[actor]
    if not keys then keys = {}; self.RosterEffectKeys[actor] = keys end
    if not keys[service] then self.RosterSerial = (self.RosterSerial or 0) + 1; keys[service] = self.RosterSerial end
    local id = keys[service]
    self.RosterEffects[id] = {Target = actor, Profile = profile, Started = now, EffectExpires = now + math.min(profile.Window, 1.2),
        Label = profile.Name .. ":" .. effect, AimFrame = aim, Track = {IsPlaying = true}, NativeEffect = true}
    if service == "BloodRainService" and effect == "Rain" and typeof(args[2]) == "Instance" and args[2].Parent then
        -- The supplied controller ends the rain when this native object is removed.
        self.RosterEffects[id].LiveToken = args[2]
        self.RosterEffects[id].EffectExpires = now + 60
    end
    if not self.InDefenceStep then self:StepDefence() end
end

function Combat:AttachRosterRemote(remote)
    if typeof(remote) ~= "Instance" or self.RosterConnections[remote]
        or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) or remote.Name ~= "Effects" then return end
    local folder = remote.Parent
    local service = folder and folder.Parent
    if not service or not self.Roster.Services[service.Name] or JJS:GetRemote(service.Name, "Effects") ~= remote then return end
    local name = service.Name
    self.RosterConnections[remote] = track(connect(remote.OnClientEvent, "attack phase observer", function(effect, ...)
        if Alive then self:OnRosterEffect(name, effect, ...) end
    end))
end

function Combat:DiscoverRosterRemotes()
    for name in pairs(self.Roster.Services) do
        local remote = JJS:GetRemote(name, "Effects")
        if remote then self:AttachRosterRemote(remote) end
    end
end

function Combat:OnCursedStrikeEffect(effect, owner)
    if owner ~= LocalPlayer.Character then return end
    if effect == "Dash" or effect == "Leap" then
        if Autos.CursedStrikeSteer then
            self.CursedSteer = {Character = owner, Generation = characterGeneration, Expires = os.clock() + .8}
        end
    elseif effect == "Hit" or effect == "Crush" or effect == "FinalHit" or effect == "BlackFlashHit" then
        self.CursedSteer = nil
    end
end

function Combat:StepCursedStrike()
    local job = self.CursedSteer
    if not job then return end
    local char = job.Character
    local root, hum = getRoot(char), getHumanoid(char)
    if not Autos.CursedStrikeSteer or not isCurrentCharacter(char, job.Generation) or os.clock() > job.Expires
        or not root or root.Anchored or not hum or hum.PlatformStand or self:HasState(char, "Ragdoll")
        or char:GetAttribute("Moveset") ~= "Itadori" or self:IsTyping() or movementState ~= "IDLE"
        or root:FindFirstChild("GrabWeld") or root:FindFirstChild("WeldGrab") then self.CursedSteer = nil; return end
    local camera = workspace.CurrentCamera
    if not camera or camera.CameraType == Enum.CameraType.Scriptable then return end
    local look = camera.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < .01 then return end
    local mover = root:FindFirstChildOfClass("BodyVelocity")
    local velocity = mover and mover.Velocity or root.AssemblyLinearVelocity
    if typeof(velocity) ~= "Vector3" then return end
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    if speed < 8 or speed > 180 then return end
    local value = flat.Unit * speed + Vector3.new(0, velocity.Y, 0)
    if mover then mover.Velocity = value else root.AssemblyLinearVelocity = value end
    self.Stats.CursedSteerFrames = (self.Stats.CursedSteerFrames or 0) + 1
end

function Combat:RenderCursedStrike(dt)
    local job = self.CursedSteer
    if not job or not Autos.CursedStrikeSteer or os.clock() > job.Expires then return false end
    local root, camera = getRoot(job.Character), workspace.CurrentCamera
    if not root or not camera or not isCurrentCharacter(job.Character, job.Generation)
        or camera.CameraType == Enum.CameraType.Scriptable or self:IsTyping() then return false end
    local look = camera.CFrame.LookVector
    local point = root.Position + Vector3.new(look.X, 0, look.Z) * 20
    return self:TurnRoot(root, getHumanoid(job.Character), point, dt)
end

function Combat:RequestTodoPerfect(target, source)
    local char = LocalPlayer.Character
    if not Autos.AutoTodoPerfect or not char or char:GetAttribute("Moveset") ~= "Todo"
        or not isCurrentCharacter(char, characterGeneration) or self:IsTyping() or self:HasState(char, "Ragdoll") then return false end
    if isActive and target and target ~= lockedTarget then return false end
    if os.clock() - (self.LastTodoPerfectAt or -math.huge) < .22 then return false end
    local ok = JJS:Fire("TodoService", "Activated", false, target)
    if ok then
        self.LastTodoPerfectAt = os.clock()
        self.Stats.TodoPerfectRequests = (self.Stats.TodoPerfectRequests or 0) + 1
        self.TodoStatus = "Perfect Swap input sent"
    end
    return ok
end

function Combat:OnTodoSwapEffect(effect, owner, target)
    if owner ~= LocalPlayer.Character then return end
    if effect == "Swap" or effect == "Swap2" then
        self:RequestTodoPerfect(target, "native clap")
    elseif effect == "Perfect" then
        self.Stats.TodoPerfectConfirms = (self.Stats.TodoPerfectConfirms or 0) + 1
        self.TodoStatus = "Perfect Swap confirmed"
    elseif effect == "Fakeout" then self.TodoStatus = "Swap feinted" end
end

function Combat:ObserveTodoClap(anim, char, generation)
    local id = anim.Animation and anim.Animation.AnimationId
    if not ({["rbxassetid://131358603583212"] = true, ["rbxassetid://91074768993486"] = true,
        ["rbxassetid://116040503139675"] = true})[id] or type(anim.GetMarkerReachedSignal) ~= "function" then return end
    local done = false
    for _, name in ipairs({"Clap", "Swap"}) do
        trackCharacter(connect(anim:GetMarkerReachedSignal(name), "Todo clap marker", function()
            if done or not isCurrentCharacter(char, generation) or anim.IsPlaying ~= true then return end
            done = true
            self:RequestTodoPerfect(isActive and lockedTarget or nil, "animation marker")
        end))
    end
end

function Combat:LearnRatioTiming(job)
    if job.TimingLearned or not job.SentAt or not job.ServerStart or not job.Token then return end
    local phase = job.Token:GetAttribute("CurrentTiming")
    if not finiteNumber(phase) or phase < 0 or phase > 1 then return end
    if job.InitialTiming == phase and job.Token.Value ~= true then return end
    job.TimingLearned = true
    self.LastRatioTiming = phase
    self.RatioCorrection = math.clamp((self.RatioCorrection or 0) - (phase - .7) * job.Duration * .4, -.08, .08)
end

Combat.Cosmetics = {Rows = {}, Queue = {}, Queued = {}, Visibility = {}, ListSizes = {}, OwnedHooks = {}, NextRefresh = 0, Status = "Catalog ready"}

function Combat.Cosmetics:RestorePages()
    for object, record in pairs(self.Visibility) do
        if object.Parent and object.Visible == record.Applied then object.Visible = record.Previous end
    end
    table.clear(self.Visibility)
end

function Combat.Cosmetics:Expose(object)
    if not object or not object:IsA("GuiObject") then return end
    if not self.Visibility[object] then self.Visibility[object] = {Previous = object.Visible, Applied = true} end
    object.Visible = true
end

function Combat.Cosmetics:Request(kind, name, play)
    if Combat:IsTyping() or type(name) ~= "string" or not table.find(Combat.CosmeticCatalog[kind] or {}, name) then return false end
    local ok
    if kind == "Emotes" then
        if play then ok = JJS:Fire("EmoteService", "Emote", name)
        else ok = JJS:Fire("EmoteService", "Equip", Options.CosmeticSlot, name) end
    elseif kind == "Titles" then ok = JJS:Fire("EmoteService", "ChangeInv", name)
    elseif kind == "MVP" then
        self.LocalOutro = name
        Combat:MarkSettingsDirty()
        ok = JJS:Fire("EmoteService", "ChangeMVP", name)
    end
    if not ok then self.Status = "Cosmetic route unavailable"; return false end
    self.Pending = {Kind = kind, Name = name, Play = play, At = os.clock(), Slot = Options.CosmeticSlot}
    self.Status = "Requested " .. name .. "; waiting for game confirmation"
    return true
end

function Combat.Cosmetics:ObserveEquip(slot, name)
    local pending = self.Pending
    if pending and pending.Kind == "Emotes" and not pending.Play and pending.Slot == tonumber(slot) and pending.Name == name then
        self.Status = "Game confirmed " .. name; self.Pending = nil
    end
end

function Combat.Cosmetics:InstallOutros(module)
    if not module then
        if self.OutroModule then return end
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local source = modules and modules:FindFirstChild("MVP")
        if not source or not source:IsA("ModuleScript") then return end
        local ok, result = pcall(require, source)
        if not ok then return end
        module = result
    end
    if type(module) ~= "table" or type(module.MVP_Play) ~= "function" then return end
    self.OutroModule = module
    Combat:Patch(module, "MVP_Play", function(original)
        return function(controller, player, name, ...)
            if Alive and Autos.CosmeticCatalog and player == LocalPlayer
                and table.find(Combat.CosmeticCatalog.MVP, self.LocalOutro) then name = self.LocalOutro end
            return original(controller, player, name, ...)
        end
    end)
end

function Combat.Cosmetics:ClearRows()
    for row, record in pairs(self.Rows) do
        for _, connection in ipairs(record.Connections) do connection:Disconnect() end
        if row.Parent then row:Destroy() end
    end
    table.clear(self.Rows); table.clear(self.Queue); table.clear(self.Queued)
    for _, connection in pairs(self.OwnedHooks) do connection:Disconnect() end
    table.clear(self.OwnedHooks)
    for list, previous in pairs(self.ListSizes) do
        if list.Parent and list.AutomaticCanvasSize == Enum.AutomaticSize.Y then list.AutomaticCanvasSize = previous end
    end
    table.clear(self.ListSizes)
end

function Combat.Cosmetics:Refresh()
    local menus = PlayerGui:FindFirstChild("Menus")
    local group = menus and menus:FindFirstChild("Group")
    local inventory = group and group:FindFirstChild("Inventory")
    local items = inventory and inventory:FindFirstChild("Items")
    local emotes = PlayerGui:FindFirstChild("Emotes")
    local wheel = emotes and emotes:FindFirstChild("Emote")
    if Autos.UnlockEmotePages then
        if wheel then
            self:Expose(wheel:FindFirstChild("Switch")); self:Expose(wheel:FindFirstChild("TextBox"))
            if Autos.ExtraEmoteSlots then
                for number = 9, 16 do self:Expose(wheel:FindFirstChild(tostring(number), true)) end
            end
        end
        local emoteItems = items and items:FindFirstChild("Emotes")
        local equipped = emoteItems and emoteItems:FindFirstChild("Equipped")
        if equipped then self:Expose(equipped:FindFirstChild("Switch")) end
    elseif next(self.Visibility) then self:RestorePages() end
    if not Autos.CosmeticCatalog then if next(self.Rows) then self:ClearRows() end; return end
    if not inventory or not inventory.Visible or not items then return end
    local preset = menus:FindFirstChild("Preset")
    preset = preset and preset:FindFirstChild("Emote")
    if not preset then return end
    for _, kind in ipairs({"Emotes", "Titles", "MVP"}) do
        local page = items:FindFirstChild(kind)
        local list = page and page:FindFirstChild("List")
        if list and page.Visible then
            if self.ListSizes[list] == nil then self.ListSizes[list] = list.AutomaticCanvasSize end
            list.AutomaticCanvasSize = Enum.AutomaticSize.Y
            for _, name in ipairs(Combat.CosmeticCatalog[kind]) do
                local key = kind .. ":" .. name
                local existing = list:FindFirstChild(name)
                if kind == "MVP" and existing and not existing:GetAttribute("RyuJJS_Catalog") and not self.OwnedHooks[existing] then
                    local button = existing:FindFirstChild("EmoteName")
                    if button then self.OwnedHooks[existing] = connect(button.MouseButton1Down, "restore selected game outro", function()
                        self.LocalOutro = nil; Combat:MarkSettingsDirty()
                        self.Status = "Using the game's selected outro"
                    end) end
                end
                if not existing and not self.Queued[key] then
                    self.Queued[key] = true
                    table.insert(self.Queue, {Kind = kind, Name = name, Key = key, List = list, Preset = preset})
                end
            end
        end
    end
end

function Combat.Cosmetics:Step()
    local now = os.clock()
    if now >= self.NextRefresh then self.NextRefresh = now + .5; self:Refresh() end
    local pending = self.Pending
    if pending and pending.Kind ~= "Emotes" and LocalPlayer:GetAttribute(pending.Kind == "Titles" and "Title" or "MVP") == pending.Name then
        self.Status = "Game confirmed " .. pending.Name; self.Pending = nil
    elseif pending and now - pending.At > 2 then
        self.Status = "Game has not confirmed " .. pending.Name; self.Pending = nil
    end
    for row, record in pairs(self.Rows) do
        if not row.Parent then
            for _, connection in ipairs(record.Connections) do connection:Disconnect() end
            self.Rows[row] = nil
        end
    end
    for row, connection in pairs(self.OwnedHooks) do
        if not row.Parent then connection:Disconnect(); self.OwnedHooks[row] = nil end
    end
    for _ = 1, 10 do
        local job = table.remove(self.Queue, 1)
        if not job then break end
        self.Queued[job.Key] = nil
        if Autos.CosmeticCatalog and job.List.Parent and not job.List:FindFirstChild(job.Name) then
            local row = job.Preset:Clone()
            row.Name = job.Name
            row:SetAttribute("RyuJJS_Catalog", true)
            row.Size = UDim2.new(1, 0, 0, 30)
            row.LayoutOrder = 100000
            local button = row:FindFirstChild("EmoteName")
            if button then
                button.Text = job.Name
                local connections = {}
                table.insert(connections, connect(button.MouseButton1Down, "cosmetic selection", function()
                    self:Request(job.Kind, job.Name, false)
                end))
                if job.Kind == "Emotes" then
                    table.insert(connections, connect(button.MouseButton2Click, "play catalog emote", function()
                        self:Request(job.Kind, job.Name, true)
                    end))
                end
                self.Rows[row] = {Connections = connections, Kind = job.Kind, Name = job.Name}
                row.Parent = job.List
            else row:Destroy() end
        end
    end
end

function Combat.Cosmetics:Destroy()
    self:ClearRows(); self:RestorePages(); self.Pending = nil
end

-- TBO's invisibility path hides local parts/decals. Keep it reversible and
-- explicit: local transparency does not grant server-visible invisibility.
function Combat:ResetLocalInvisible()
    for object, record in pairs(self.LocalInvisibleParts or {}) do
        if object.Parent then
            if record.Kind == "part" and object.LocalTransparencyModifier == 1 then object.LocalTransparencyModifier = record.Value
            elseif record.Kind == "decal" and object.Transparency == 1 then object.Transparency = record.Value end
        end
    end
    self.LocalInvisibleParts = {}
end

function Combat:ObserveLocalInvisible(object)
    if not Autos.InvisibleLocal or not object:IsDescendantOf(LocalPlayer.Character) then return end
    self.LocalInvisibleParts = self.LocalInvisibleParts or {}
    if self.LocalInvisibleParts[object] then return end
    if object:IsA("BasePart") then
        self.LocalInvisibleParts[object] = {Kind = "part", Value = object.LocalTransparencyModifier}
        object.LocalTransparencyModifier = 1
    elseif object:IsA("Decal") then
        self.LocalInvisibleParts[object] = {Kind = "decal", Value = object.Transparency}; object.Transparency = 1
    end
end

function Combat:ApplyLocalInvisible()
    if not Autos.InvisibleLocal then self:ResetLocalInvisible(); return end
    local char = LocalPlayer.Character
    if char then for _, object in ipairs(char:GetDescendants()) do self:ObserveLocalInvisible(object) end end
end

-- TBO P076/P261: own CurseBuild -> clamp(.04 + dataPingMS*.0004, .045, .105)
-- -> DivergentFistService.Activated(the real Moveset tool). P269/P376 supply
-- an animation fallback with .142 timing. No virtual number-key input is used.
Combat.BlackFlashRules = {
    ["rbxassetid://100962226150441"] = {Character = "Itadori", Service = "DivergentFistService", Tool = "Divergent Fist", At = .142},
    ["rbxassetid://95852624447551"] = {Character = "Itadori", Service = "DivergentFistService", Tool = "Divergent Fist", At = .142},
    ["rbxassetid://74145636023952"] = {Character = "Itadori", Service = "DivergentFistService", Tool = "Divergent Fist", At = .142},
    ["rbxassetid://123171106092050"] = {Character = "Itadori", Service = "DivergentFistService", Tool = "Divergent Fist", At = .142},
    ["rbxassetid://72475960800126"] = {Character = "Mahito", Service = "FocusStrikeService", Tool = "Focus Strike", At = .142},
}
Combat.BlackFlashJobs = {}
Combat.BlackFlashTracks = setmetatable({}, {__mode = "k"})
Combat.BlackFlashLast = {}

function Combat:ResetBlackFlash()
    table.clear(self.BlackFlashJobs); table.clear(self.BlackFlashTracks); table.clear(self.BlackFlashLast)
end

function Combat:BlackFlashTool(service, name)
    local char = LocalPlayer.Character
    local moves = char and char:FindFirstChild("Moveset")
    local tool = moves and moves:FindFirstChild(name)
    if not tool or (tool:GetAttribute("Service") and tool:GetAttribute("Service") ~= service) then return end
    return tool
end

function Combat:SendBlackFlashInput(service, name)
    local tool = self:BlackFlashTool(service, name)
    if not tool then return false end
    local ok = JJS:Fire(service, "Activated", tool)
    if ok then self.Stats.BlackFlashRequests = (self.Stats.BlackFlashRequests or 0) + 1 end
    return ok
end

function Combat:ObserveBlackFlashAnimation(track, char, generation)
    self:ObserveTodoBlackFlash(track, char, generation)
    if not Autos.BlackFlash or not isCurrentCharacter(char, generation) or self.BlackFlashTracks[track] then return end
    local raw = track.Animation and track.Animation.AnimationId
    local digits = type(raw) == "string" and (string.match(raw, "rbxassetid://(%d+)") or string.match(raw, "[?&]id=(%d+)") or string.match(raw, "^(%d+)$"))
    local rule = digits and self.BlackFlashRules["rbxassetid://" .. digits]
    if not rule or char:GetAttribute("Moveset") ~= rule.Character then return end
    local now, previous = os.clock(), self.BlackFlashJobs[rule.Service]
    -- The effect can arrive just before AnimationPlayed. Keep the earlier
    -- native event deadline instead of replacing it with a fresh .142 wait.
    if previous and previous.Character == char and previous.NativeEffectSeen
        and now - previous.Started < .25 and not previous.Track then
        previous.Track = track; self.BlackFlashTracks[track] = true; return
    end
    self.BlackFlashTracks[track] = true
    self.BlackFlashJobs[rule.Service] = {Rule = rule, Track = track, Character = char, Generation = generation,
        Started = now, Source = "Animation", Expires = now + .6, Sent = false}
    self:StepBlackFlash()
end

function Combat:AttachBlackFlashAnimator(animator, char, generation)
    trackCharacter(connect(animator.AnimationPlayed, "Black Flash animation", function(animation)
        if Alive then self:ObserveBlackFlashAnimation(animation, char, generation) end
    end))
    for _, animation in ipairs(animator:GetPlayingAnimationTracks()) do
        self:ObserveBlackFlashAnimation(animation, char, generation)
    end
end

function Combat:OnBlackFlashEffect(service, effect, owner)
    local char = LocalPlayer.Character
    if service ~= "DivergentFistService" or owner ~= char then return end
    if effect == "BlackFlashHit" or effect == "BlackFlashHitHard" or effect == "BlackFlashChain" then
        self.Stats.BlackFlashConfirms = (self.Stats.BlackFlashConfirms or 0) + 1
        return
    end
    if effect ~= "CurseBuild" or not Autos.BlackFlash or not isCurrentCharacter(char, characterGeneration)
        or char:GetAttribute("Moveset") ~= "Itadori" then return end
    local now, job, last = os.clock(), self.BlackFlashJobs[service], self.BlackFlashLast[service]
    if job and job.Character == char and job.NativeEffectSeen and now - job.Started < .25 then return end
    if job and job.Sent then
        if last and now - last.At < .25 then return end
        job = nil
    end
    if not job and last and last.Character == char and now - last.At < .25 then return end
    if not job then
        job = {Rule = self.BlackFlashRules["rbxassetid://100962226150441"], Character = char,
            Generation = characterGeneration, Started = now, Sent = false}
        self.BlackFlashJobs[service] = job
    end
    local delay = math.clamp(.04 + self:PingMilliseconds() * .0004, .045, .105)
    local due = now + delay
    local track = job.Track
    if track and finiteNumber(track.TimePosition) and finiteNumber(track.Speed) and track.Speed > 0 then
        due = math.min(due, now + math.max(0, (job.Rule.At - track.TimePosition) / track.Speed))
    end
    job.Due, job.Expires, job.Source, job.Started = due, due + .08, "CurseBuild", now
    job.NativeEffectSeen = true
end

function Combat:StepBlackFlash()
    self:StepTodoBlackFlash()
    local now = os.clock()
    for service, job in pairs(self.BlackFlashJobs) do
        local char, track = job.Character, job.Track
        if not Autos.BlackFlash or not isCurrentCharacter(char, job.Generation)
            or char:GetAttribute("Moveset") ~= job.Rule.Character or now > job.Expires
            or (track and track.IsPlaying ~= true) or self:IsTyping()
            or self:HasState(char, "Stun") or self:HasState(char, "Ragdoll") then
            self.BlackFlashJobs[service] = nil
        elseif not job.Sent then
            local ready, late = false, false
            if job.Due then ready, late = now >= job.Due, now > job.Due + .08
            elseif track and finiteNumber(track.TimePosition) then
                ready = track.TimePosition >= job.Rule.At
                late = track.TimePosition > job.Rule.At + .08
            end
            if ready then
                -- Mark before sending: a synchronous effect/second frame must
                -- not re-enter this same activation. Expired windows are dropped.
                job.Sent = true
                if not late and self:SendBlackFlashInput(service, job.Rule.Tool) then
                    self.BlackFlashLast[service] = {Character = char, At = now, Source = job.Source}
                end
            end
        end
    end
end

function Combat:ManualBlackFlash(service, name)
    local char = LocalPlayer.Character
    if not isCurrentCharacter(char, characterGeneration) or self:IsTyping()
        or self:HasState(char, "Stun") or self:HasState(char, "Ragdoll") then return false end
    local job = self.BlackFlashJobs[service]
    if job and not job.Sent then return true end
    return self:SendBlackFlashInput(service, name)
end

-- TBO Auto Todo Blackflash: P056 -> P244 -> P372. SlidePose starts
-- BruteForceService.Activated(the owned Brute Force tool) immediately;
-- the second activation follows .75 seconds later. Never press a number key.
Combat.TodoBlackFlashTracks = setmetatable({}, {__mode = "k"})

function Combat:ResetTodoBlackFlash()
    self.TodoBlackFlashJob = nil
    table.clear(self.TodoBlackFlashTracks)
end

function Combat:TodoBlackFlashReady(char, generation)
    return Autos.AutoTodoBlackFlash and isCurrentCharacter(char, generation)
        and char:GetAttribute("Moveset") == "Todo" and not self:IsTyping()
        and not self:HasState(char, "Stun") and not self:HasState(char, "Ragdoll")
end

function Combat:ObserveTodoBlackFlash(track, char, generation)
    if not self:TodoBlackFlashReady(char, generation) or self.TodoBlackFlashTracks[track]
        or track.IsPlaying ~= true then return end
    local animation = track.Animation
    local raw = animation and animation.AnimationId
    local digits = type(raw) == "string" and (string.match(raw, "rbxassetid://(%d+)") or string.match(raw, "[?&]id=(%d+)") or string.match(raw, "^(%d+)$"))
    local matches = digits == "100081544058065"
    local assets = ReplicatedStorage:FindFirstChild("Animations")
    local todo = assets and assets:FindFirstChild("Todo")
    if not matches and typeof(animation) == "Instance" and animation.Name == "SlidePose"
        and todo and animation:IsDescendantOf(todo) then matches = true end
    if not matches then return end
    self.TodoBlackFlashTracks[track] = true
    local previous = self.TodoBlackFlashJob
    if previous and previous.Character == char and os.clock() - previous.Started < .1 then return end
    local tool = self:BlackFlashTool("BruteForceService", "Brute Force")
    if not tool then return end
    local started = os.clock()
    local job = {Character = char, Generation = generation, Tool = tool, Started = started, Due = started + .75}
    self.TodoBlackFlashJob = job
    if self:SendBlackFlashInput("BruteForceService", "Brute Force") then
        self.Stats.TodoBlackFlashRequests = (self.Stats.TodoBlackFlashRequests or 0) + 1
    else self.TodoBlackFlashJob = nil end
end

function Combat:StepTodoBlackFlash()
    local job = self.TodoBlackFlashJob
    if not job then return end
    local now = os.clock()
    if not self:TodoBlackFlashReady(job.Character, job.Generation) or now > job.Due + .12
        or self:BlackFlashTool("BruteForceService", "Brute Force") ~= job.Tool then
        self.TodoBlackFlashJob = nil; return
    end
    if now < job.Due then return end
    -- Brute Force replaces the stance animation. Its ending must not cancel
    -- this second input. Actual stun, hit completion and character changes do.
    self.TodoBlackFlashJob = nil
    if self:SendBlackFlashInput("BruteForceService", "Brute Force") then
        self.Stats.TodoBlackFlashRequests = (self.Stats.TodoBlackFlashRequests or 0) + 1
    end
end

function Combat:OnTodoBlackFlashEffect(service, effect, owner)
    if service ~= "BruteForceService" or (owner ~= LocalPlayer.Character and owner ~= LocalPlayer) then return end
    if effect == "BlackFlashHit" then
        self.Stats.TodoBlackFlashConfirms = (self.Stats.TodoBlackFlashConfirms or 0) + 1
        self.TodoBlackFlashJob = nil
    elseif effect == "Hit" then self.TodoBlackFlashJob = nil end
end

Combat.FeatureAliases = {TodoSwap = "AutoTodoBlackFlash", StareWhileMoving = "HybridFacingWhileMoving"}

function Combat:BuildModeControls(parent, create, style)
    self.ModeButtons = {}
    for index, mode in ipairs({"aim", "hybrid"}) do
        local props = {Name = mode == "aim" and "CameraMode" or "HybridMode", Text = mode == "aim" and "Camera" or "Hybrid",
            Size = UDim2.new(.5, -15, 0, 29), Position = UDim2.new((index - 1) * .5, 10, 0, 39), Parent = parent}
        for key, value in pairs(style or {}) do props[key] = value end
        local button = create("TextButton", props)
        self.ModeButtons[mode] = button
        table.insert(self.UIConnections, connect(button.Activated, "tracking mode", function() self:SetMode(mode) end))
    end
    self:RefreshModeControls()
end

function Combat:RefreshModeControls()
    for mode, button in pairs(self.ModeButtons or {}) do
        local label = mode == "aim" and "Camera" or "Hybrid"
        button.Text = mode == currentMode and (label .. "  ✓") or label
        button.BackgroundTransparency = mode == currentMode and 0 or .35
    end
end

function Combat:IndexAnimation(animation)
    if not animation:IsA("Animation") then return end
    self:IndexRosterAnimation(animation)
    local parent = animation.Parent
    if not parent or not string.match(parent.Name, "^Melee") then return end
    local name = animation.Name
    local regular = string.match(name, "^Melee[123]$") ~= nil
    local finisher = name == "Melee4" or name == "Melee4Frame" or name == "Up" or name == "Down"
    if not regular and not finisher then return end
    local id = animation.AnimationId
    if type(id) ~= "string" or id == "" then
        if not self.PendingAnimationIds[animation] then
            self.PendingAnimationIds[animation] = connect(animation:GetPropertyChangedSignal("AnimationId"), "deferred guard animation ID", function()
                self:IndexAnimation(animation)
            end)
        end
        return
    end
    if self.PendingAnimationIds[animation] then
        self.PendingAnimationIds[animation]:Disconnect()
        self.PendingAnimationIds[animation] = nil
    end
    local record = self.AttackProfiles[id]
    if not record then record = {Regular = {}, Finishers = {}}; self.AttackProfiles[id] = record end
    local moveset = parent.Parent and parent.Parent.Name or ""
    if regular then
        record.Regular[moveset] = name
        self.Blockable[id] = name
    else
        record.Finishers[moveset] = true
        self.AmbiguousAnimations[id] = true
    end
    -- A finisher sharing an ID must not delete another character's regular M1.
end

function Combat:AttackFlags(track)
    local raw = track.Animation and track.Animation.AnimationId
    if type(raw) ~= "string" then return 0 end
    local digits = string.match(raw, "^rbxassetid://(%d+)$") or string.match(raw, "[?&]id=(%d+)") or string.match(raw, "^(%d+)$")
    local id = digits and ("rbxassetid://" .. digits) or raw
    return self.TBOAttackFlags[id] or ((self.Blockable[id] or self.Blockable[raw]) and 22 or 0), id
end

function Combat:AttackLabel(track)
    local flags, id = self:AttackFlags(track)
    return bit32.band(flags, 3) ~= 0 and id or nil
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
    self.BlockAttempts, self.NextBlockRetry = 0, 0
    self.BlockAttackKey, self.GuardHoldUntil, self.GuardSentAt, self.GuardHadAck = nil, nil, nil, nil
    self.GuardRecovery, self.GuardTarget = nil, nil
    if char == LocalPlayer.Character and not UserInputService:IsKeyDown(Enum.KeyCode.F) then
        JJS:Fire("BlockService", "Deactivated")
    end
end

function Combat:OnThreat(track, target)
    target = target or lockedTarget
    if target then self:OnAdaptThreat(track, target) end
    if not Autos.AutoBlock and not Autos.AutoPunish then return end
    local watcher = target and self.Defenders[target]
    if not watcher or watcher.Tracks[track] then return end
    local profile, id = self:RosterProfile(track, target)
    watcher.Tracks[track] = {Track = track, Target = target, Started = os.clock(), Profile = profile, Label = id}
    self.Stats.AttacksObserved = (self.Stats.AttacksObserved or 0) + 1
    if not self.InDefenceStep then self:StepDefence() end
end

function Combat:SelectThreat(now)
    local selected, best = nil, math.huge
    self.InDefenceStep = true
    local function choose(threat)
        if not self:RosterThreatActive(threat, now) then return end
        local profile = threat.Profile
        local range = profile and math.clamp(profile.Range * Options.BlockRange / 15, 5, 70) or Options.BlockRange
        local target, root, own, distance = self:ThreatInRange(threat, range)
        if target and self:RosterApproaching(threat, own, root) then
            local velocity = root.AssemblyLinearVelocity
            local speed = typeof(velocity) == "Vector3" and velocity.Magnitude or 0
            local score = distance / math.max(15, speed)
            if score < best then selected, best = threat, score end
        end
    end
    for model, watcher in pairs(self.Defenders) do
        if now >= (watcher.NextPoll or 0) then
            watcher.NextPoll = now + .08
            for _, anim in ipairs(watcher.Animator:GetPlayingAnimationTracks()) do
                if not watcher.Tracks[anim] then self:OnThreat(anim, model) end
            end
        end
        for anim, threat in pairs(watcher.Tracks) do
            if not model.Parent or anim.IsPlaying ~= true then watcher.Tracks[anim] = nil
            else
                if not threat.Profile then threat.Profile, threat.Label = self:RosterProfile(anim, model) end
                choose(threat)
            end
        end
    end
    for key, threat in pairs(self.RosterEffects) do
        if not threat.Target.Parent or now > threat.EffectExpires or (threat.LiveToken and not threat.LiveToken.Parent) then
            threat.Track.IsPlaying = false; self.RosterEffects[key] = nil
        else choose(threat) end
    end
    self.InDefenceStep = false
    self.Threat = selected
    if selected then self.LastThreat = {Target = selected.Target, At = now} end
    return selected
end

function Combat:PunishDisabled(target)
    local hum = getHumanoid(target)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return false end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.IsPlaying == true and bit32.band(self:AttackFlags(track), 8) ~= 0 then return true end
    end
    return false
end

function Combat:WatchTarget()
    local ownRoot = getRoot(LocalPlayer.Character)
    local enabled = Autos.AutoBlock or Autos.AutoPunish or Autos.AutoAdapt
    local keep = {}
    if ownRoot and enabled then
        for _, model in ipairs(collectTargets()) do
            local entry = TargetIndex.ByModel[model]
            if model ~= LocalPlayer.Character and entry and entry.Humanoid.Health > 0
                and ((Autos.AutoAdapt and (entry.Root.Position - ownRoot.Position).Magnitude <= 46)
                    or ((not Autos.DefenceLockedOnly or (isActive and model == lockedTarget))
                        and (entry.Root.Position - ownRoot.Position).Magnitude <= 80)) then
                local animator = entry.Humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    keep[model] = true
                    local old = self.Defenders[model]
                    if old and old.Animator ~= animator then
                        self:DisconnectList(old.Connections)
                        self.Defenders[model] = nil
                    end
                    if not self.Defenders[model] then
                        local watcher = {Animator = animator, Tracks = {}, Connections = {}}
                        self.Defenders[model] = watcher
                        table.insert(watcher.Connections, connect(animator.AnimationPlayed, "TBO attack observer", function(track)
                            if Alive and self.Defenders[model] == watcher then self:OnThreat(track, model) end
                        end))
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do self:OnThreat(track, model) end
                    end
                end
            end
        end
    end
    for model, watcher in pairs(self.Defenders) do
        if not keep[model] then
            self:DisconnectList(watcher.Connections)
            self.Defenders[model] = nil
        end
    end
end

function Combat:ThreatInRange(threat, distance)
    if not threat or not threat.Target or not threat.Target.Parent then return end
    local target, ownRoot = threat.Target, getRoot(LocalPlayer.Character)
    if Autos.DefenceLockedOnly and (not isActive or target ~= lockedTarget) then return end
    local hum, root = getHumanoid(target), getRoot(target)
    if not hum or hum.Health <= 0 or not root or not ownRoot or self:HasState(target, "Ragdoll") then return end
    local delta = ownRoot.Position - root.Position
    local height = threat.Profile and threat.Profile.Height or 8
    if delta.Magnitude < 0.01 or math.abs(delta.Y) > height or not self:ClearLine(target, root.Position) then return end
    -- TBO applies its facing cone to AutoCounter, not AutoBlock. Use the live
    -- attack table + C scope here; replicated root yaw must not veto guard.
    if delta.Magnitude > distance then
        local ownV, enemyV = ownRoot.AssemblyLinearVelocity, root.AssemblyLinearVelocity
        if typeof(ownV) ~= "Vector3" or typeof(enemyV) ~= "Vector3" then return end
        local closing = -(ownV - enemyV):Dot(delta.Unit)
        local lead = math.clamp(self:PingMilliseconds() / 2000, 0, 0.3)
        if closing <= 0 or delta.Magnitude > distance + math.min(5, closing * lead) then return end
    end
    return target, root, ownRoot, delta.Magnitude
end

function Combat:RefreshEffects()
    local folder = workspace:FindFirstChild("Effects")
    if folder == self.EffectsFolder then return end
    self:DisconnectList(self.EffectConnections)
    table.clear(self.Projectiles)
    self.EffectsFolder = folder
    self.EffectOverlap, self.LastProjectile, self.NextProjectileCheck = nil, nil, 0
    if not folder then return end
    local function added(part)
        -- TBO's two supported projectile shapes. Decorative streaks, glow parts,
        -- dust and arbitrary effect BaseParts are not projectiles.
        if part:IsA("BasePart") and (part.Name == "Projectile" or part.Name == "Reserve") then
            self.Projectiles[part] = {Position = part.Position, At = os.clock()}
            self.NextProjectileCheck = 0
        end
    end
    table.insert(self.EffectConnections, connect(folder.ChildAdded, "projectile arrival", added))
    table.insert(self.EffectConnections, connect(folder.ChildRemoved, "projectile departure", function(part)
        self.Projectiles[part] = nil
        if self.LastProjectile == part then self.NextProjectileCheck = 0 end
    end))
    for _, part in ipairs(folder:GetChildren()) do added(part) end
end

function Combat:ProjectileOwner(part)
    local owner = part:FindFirstChild("Owner")
    local value = owner and owner:IsA("ObjectValue") and owner.Value
    if typeof(value) == "Instance" then
        if value:IsA("Player") then return value.Character end
        if value:IsA("Model") then return value end
    end
    local userId = part:GetAttribute("OwnerUserId")
    if finiteNumber(userId) then
        local player = Players:GetPlayerByUserId(userId)
        return player and player.Character
    end
end

function Combat:DirectedProjectile(part, ownRoot)
    local sample = part and self.Projectiles[part]
    if not sample or part.Parent ~= self.EffectsFolder then return end
    local owner = self:ProjectileOwner(part)
    if owner == LocalPlayer.Character then return end
    if Autos.DefenceLockedOnly and (not isActive or owner ~= lockedTarget) then return end
    local now, position = os.clock(), part.Position
    local velocity = part.AssemblyLinearVelocity
    local elapsed = now - sample.At
    if elapsed >= 0.025 then
        local measured = typeof(sample.Position) == "Vector3" and (position - sample.Position) / elapsed or Vector3.zero
        sample.Position, sample.At = position, now
        sample.Measured = measured
    end
    if typeof(velocity) ~= "Vector3" or velocity.Magnitude < 4 then velocity = sample.Measured or Vector3.zero end
    if velocity.Magnitude < 4 or velocity.Magnitude > 1500 then return end
    local delta = ownRoot.Position - position
    local range = part.Name == "Reserve" and 30 or 50
    if delta.Magnitude < 0.05 or delta.Magnitude > range then return end
    local ownVelocity = ownRoot.AssemblyLinearVelocity
    local relative = velocity - (typeof(ownVelocity) == "Vector3" and ownVelocity or Vector3.zero)
    local speedSquared = relative:Dot(relative)
    if speedSquared < 16 then return end
    local untilImpact = delta:Dot(relative) / speedSquared
    local miss = (delta - relative * untilImpact).Magnitude
    if untilImpact < 0 or untilImpact > 0.35 or miss > 4 then return end
    if self:ClearLine(part, position) then return part end
end

function Combat:ProjectileThreat()
    if not Autos.BlockProjectiles then return end
    if Autos.DefenceLockedOnly and not isActive then return end
    local ownRoot, folder = getRoot(LocalPlayer.Character), self.EffectsFolder
    if not ownRoot or not folder then return end
    -- A dog targeting us across the map or playing its idle animation is not
    -- an attack. Require a nearby live attack track from the saved Totality rig.
    local totality = folder:FindFirstChild("Totality")
    local target = totality and totality:FindFirstChild("Target")
    local dogRoot = totality and getRoot(totality)
    if not Autos.DefenceLockedOnly and target and target:IsA("ObjectValue") and target.Value == LocalPlayer.Character
        and dogRoot and (dogRoot.Position - ownRoot.Position).Magnitude <= Options.BlockRange then
        local controller = totality:FindFirstChild("AnimationController")
        local animator = controller and controller:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local id = track.Animation and track.Animation.AnimationId
                if track.IsPlaying and (id == "rbxassetid://130336833420143" or id == "rbxassetid://95250225969869"
                    or id == "rbxassetid://81688837573130") then return dogRoot end
            end
        end
    end
    local now = os.clock()
    if now < self.NextProjectileCheck then
        local active = self:DirectedProjectile(self.LastProjectile, ownRoot)
        if active then return active end
        if not self.LastProjectile then return end
    end
    self.NextProjectileCheck = now + 0.04
    self.LastProjectile = nil
    local ok, parts = pcall(function()
        if not self.EffectOverlap then
            local params = OverlapParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {folder}
            self.EffectOverlap = params
        end
        return workspace:GetPartBoundsInRadius(ownRoot.Position, 50, self.EffectOverlap)
    end)
    if ok then
        for _, part in ipairs(parts) do
            if self:DirectedProjectile(part, ownRoot) then self.LastProjectile = part; return part end
        end
    else
        for part in pairs(self.Projectiles) do
            if self:DirectedProjectile(part, ownRoot) then self.LastProjectile = part; return part end
        end
    end
end

function Combat:PunishTarget(target, distance)
    if not target or not target.Parent then return end
    if Autos.DefenceLockedOnly and (not isActive or target ~= lockedTarget) then return end
    local root, ownRoot, hum = getRoot(target), getRoot(LocalPlayer.Character), getHumanoid(target)
    if not root or not ownRoot or not hum or hum.Health <= 0 or self:HasState(target, "Ragdoll") then return end
    local delta = root.Position - ownRoot.Position
    if delta.Magnitude < 0.01 or delta.Magnitude > distance or math.abs(delta.Y) > 8
        or not self:ClearLine(target, root.Position) then return end
    -- Facing matters to an incoming guard test, not to a confirmed hit's punish.
    return target, root, ownRoot, delta.Magnitude
end

function Combat:GuardBusyReason(char, forPunish)
    local hum, root = getHumanoid(char), getRoot(char)
    if not char or not char.Parent or not hum or hum.Health <= 0 or not root then return "Character unavailable" end
    if root.Anchored or hum.PlatformStand or self:HasState(char, "Ragdoll") then return "Ragdoll / root physics" end
    if self:IsTyping() then return "Typing" end
    if movementState ~= "IDLE" then return "Movement helper active" end
    if self.YukiJob then return "Yuki charge active" end
    local info = char:FindFirstChild("Info")
    if root:FindFirstChild("GrabWeld") or root:FindFirstChild("WeldGrab") or (info and info:FindFirstChild("Grab")) then return "Grabbed" end
    if info and (info:FindFirstChild("DomainClash") or info:FindFirstChild("Cutscene")) then return "Cutscene / clash" end
    if self.ManualAttackHeld and type(UserInputService.IsMouseButtonPressed) == "function" then
        local ok, held = pcall(UserInputService.IsMouseButtonPressed, UserInputService, Enum.UserInputType.MouseButton1)
        if ok and not held then self.ManualAttackHeld = false end
    end
    if forPunish and os.clock() < (self.OffenseUntil or 0) then return "Own attack active" end
    if workspace.CurrentCamera and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return "Scripted camera" end
    -- Block can itself create recovery/skill state. Do not unblock on that state.
    if forPunish and self:HasState(char, "Stun") then return "Recovering from stun" end
end

function Combat:GuardFacing(root)
    -- Only the render loop rotates the root; Heartbeat records the intent.
    self.GuardTurnTarget = Autos.GuardAutoFace and root or nil
    return self.GuardTurnTarget ~= nil
end

function Combat:GuardRoundTrip()
    return math.clamp(self:PingMilliseconds() / 1000 + 0.06, 0.16, 2.1)
end

function Combat:RequestGuard(target)
    -- ToolController.Block preserves native targeting and emote handling.
    -- Its actual BlockService payload is the selected Model (proto19).
    if self.Tool and type(self.Tool.Block) == "function" then
        return Runtime:Run("native guard input", self.WithGuardTarget, self, target, self.Tool.Block, self.Tool)
    end
    return JJS:Fire("BlockService", "Activated", target)
end

function Combat:StepGuardResume()
    local job = self.GuardResume
    if not job then return end
    if job.Character ~= LocalPlayer.Character or job.Generation ~= characterGeneration
        or not UserInputService:IsKeyDown(Enum.KeyCode.F) then self.GuardResume = nil; return end
    if os.clock() < job.At then return end
    if self:GuardBusyReason(job.Character, true) then return end
    self.GuardResume = nil
    self:RequestGuard(job.Target)
    self.PunishStatus = "Counter requested; held F restored"
end

function Combat:ObserveGuardState(char, now)
    if self.BlockOwned and char == self.BlockCharacter and not self.GuardHadAck and self:HasState(char, "Block") then
        self.GuardHadAck = true
        self.LastGuardAckMS = self.GuardSentAt and (now - self.GuardSentAt) * 1000 or nil
        self.Stats.GuardStateAcks = (self.Stats.GuardStateAcks or 0) + 1
    end
end

function Combat:StepDefence()
    local now, char = os.clock(), LocalPlayer.Character
    local selected = self:SelectThreat(now)
    self:ObserveGuardState(char, now)
    local function stop(reason, soft)
        self.GuardTurnTarget = nil
        if soft and self.BlockOwned and not self.GuardHadAck and char == self.BlockCharacter and now < (self.GuardHoldUntil or 0) then
            self.GuardStatus = "Holding guard through delayed replication"; return
        end
        self.GuardStatus = reason
        self:ReleaseBlock()
    end
    self:StepGuardResume()
    if not Autos.AutoBlock then stop("Off"); return end
    if Autos.DefenceLockedOnly and (not isActive or not lockedTarget) then stop("Waiting for C target"); return end
    if self.BlockOwned and Autos.DefenceLockedOnly and self.GuardTarget and self.GuardTarget ~= lockedTarget then self:ReleaseBlock() end
    if self.Punish then self.GuardStatus = "Confirmed block; counter queued"; return end
    if now < self.DefencePauseUntil then stop("Own punish attack active"); return end
    local busy = self:GuardBusyReason(char)
    if busy then stop(busy); return end
    local projectile = not selected and self:ProjectileThreat()
    if not selected and not projectile then
        stop("No incoming attack", true); return
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.F) then
        self.BlockOwned, self.BlockCharacter = false, nil
        self.GuardStatus = "Manual F held; punish armed"; return
    end
    if self:HasState(char, "Block") and not self.BlockOwned then self.GuardStatus = "Existing manual block; punish armed"; return end
    local target, root, ownRoot
    if selected then
        local range = selected.Profile and math.clamp(selected.Profile.Range * Options.BlockRange / 15, 5, 70) or Options.BlockRange
        target, root, ownRoot = self:ThreatInRange(selected, range)
    else root, ownRoot = projectile, getRoot(char) end
    if not root or not ownRoot then stop("Threat unavailable", true); return end
    self:GuardFacing(root)
    self.GuardTarget = target
    if target then self.LastGuard = {Target = target, At = now} end
    local ack = self:HasState(char, "Block")
    local recovery = self:HasState(char, "Stun") or self:HasState(char, "InSkill")
    local recovered = self.GuardRecovery and not recovery
    self.GuardRecovery = recovery
    local live = projectile or (selected and selected.Track.IsPlaying == true)
    local retry = self.BlockOwned and not ack and live and (now >= (self.NextBlockRetry or 0) or recovered)
    if not self.BlockOwned or retry then
        local first = not self.BlockOwned
        if not self:RequestGuard(target) then stop("Native block route unavailable"); return end
        self.BlockOwned, self.BlockCharacter = true, char
        self.BlockAttackKey = selected and selected.Track or projectile
        self.BlockAttempts = first and 1 or (self.BlockAttempts or 0) + 1
        self.GuardSentAt = now
        self.NextBlockRetry = now + self:GuardRoundTrip()
        self.GuardHoldUntil = math.max(self.GuardHoldUntil or 0, self.NextBlockRetry)
        if first then self.Stats.Blocks += 1 else self.Stats.BlockRetries = (self.Stats.BlockRetries or 0) + 1 end
        self.LastAutoBlock = {At = now, Kind = selected and (bit32.band(selected.Flags or 0, 2) ~= 0 and "M1" or "TBO skill") or "projectile",
            Source = target and target.Name or projectile.Name, Animation = selected and selected.Label, Attempts = self.BlockAttempts}
    end
    self.GuardStatus = ack and "Blocking" or "Block input sent"
end

function Combat:OnGuardEffect(character, perfect)
    -- JJS HandicapController: BlockService.Effects(character, perfect). Its
    -- perfect branch plays sound without creating the normal BlockHit particle.
    if character ~= LocalPlayer.Character then return end
    self.LastGuardEffect = {At = os.clock(), Perfect = perfect == true}
    self:OnBlockHit({Native = true}, character, characterGeneration)
end

function Combat:OnBlockHit(marker, char, generation)
    if not Autos.AutoPunish or self.PunishSeen[marker] or self.Punish or not isCurrentCharacter(char, generation) then return end
    local now, chosen = os.clock(), nil
    if now - (self.LastBlockHitAt or -math.huge) < 0.08 then return end
    for _, recent in ipairs({self.LastGuard or false, self.LastThreat or false}) do
        if recent and now - recent.At <= 0.7 and self:PunishTarget(recent.Target, Options.PunishRange) then chosen = recent.Target; break end
    end
    if not chosen and isActive and self:PunishTarget(lockedTarget, Options.PunishRange) then chosen = lockedTarget end
    if not chosen then
        if not self.PendingBlockHit or self.PendingBlockHit.Marker ~= marker then
            self.PendingBlockHit = {Marker = marker, Character = char, Generation = generation, At = now}
        end
        self.PunishStatus = "Block confirmed; attacker unresolved / out of range"; return
    end
    if self:PunishDisabled(chosen) then self.PunishStatus = "TBO punish exclusion animation"; return end
    if now < self.NextPunish then self.PunishStatus = "Punish cooldown"; return end
    self.PunishSeen[marker], self.LastBlockHitAt, self.PendingBlockHit = true, now, nil
    self.Punish = {Target = chosen, Character = char, Generation = generation, Expires = now + 0.7}
    self.Stats.BlockConfirms = (self.Stats.BlockConfirms or 0) + 1
    self.PunishStatus = "Block confirmed; waiting for counter opening"
    self:StepPunish()
end

function Combat:StepPunish()
    local now, char = os.clock(), LocalPlayer.Character
    if not self.Punish and Autos.AutoPunish and self.PendingBlockHit then
        local pending = self.PendingBlockHit
        local marker = pending.Marker
        local present = (typeof(marker) == "Instance" and marker.Parent ~= nil)
            or (typeof(marker) == "table" and marker.Native == true)
        if now - pending.At <= math.clamp(self:GuardRoundTrip(), 0.15, 0.5) and present
            and isCurrentCharacter(pending.Character, pending.Generation) then self:OnBlockHit(pending.Marker, pending.Character, pending.Generation)
        else self.PendingBlockHit = nil end
    end
    local job = self.Punish
    if not job then if not Autos.AutoPunish then self.PunishStatus = "Off" end; return end
    if not Autos.AutoPunish or not isCurrentCharacter(job.Character, job.Generation) then self.Punish = nil; self.PunishStatus = "Cancelled"; return end
    if now > job.Expires then self.Punish = nil; self.PunishStatus = "Counter window expired"; return end
    local target, root = self:PunishTarget(job.Target, Options.PunishRange)
    if not target or root:FindFirstChild("GrabWeld") or self:PunishDisabled(target) then self.Punish = nil; self.PunishStatus = "Target unavailable / punish excluded"; return end
    -- Keep guard held until the counter can actually be sent. Releasing on the
    -- BlockHit packet and then waiting through stun leaves a hole in the combo.
    local busy = self:GuardBusyReason(job.Character, true)
    if busy then self.PunishStatus = busy; return end
    local info = char:FindFirstChild("Info")
    local item = info and info:FindFirstChild("Item")
    if char:FindFirstChild("CustomM1") or (item and item:FindFirstChild("M1")) or (info and info:FindFirstChild("DomainClash")) then
        self.Punish = nil; self.PunishStatus = "Native custom attack owns M1"; return
    end
    if now < self.NextPunish then return end
    if not JJS:Fire("BlockService", "Deactivated") then self.Punish = nil; self.PunishStatus = "Block release route unavailable"; return end
    local restoreF = UserInputService:IsKeyDown(Enum.KeyCode.F)
    self.BlockOwned, self.BlockCharacter, self.BlockAttackKey = false, nil, nil
    self.BlockAttempts, self.NextBlockRetry, self.GuardHoldUntil, self.GuardHadAck = 0, 0, nil, nil
    local moveset = char:GetAttribute("Moveset")
    -- ToolController.Melee's normal native wire is Activated(false, target).
    local ok = type(moveset) == "string" and JJS:Fire(moveset .. "Service", "Activated", false, target) or false
    if not ok and self.Tool and type(self.Tool.UseSetService) == "function" then
        ok = Runtime:Run("native confirmed block punish", function() self.Tool:UseSetService("Activated", false, target) end)
    end
    local pause = math.clamp(0.25 + self:PingMilliseconds() / 2000, 0.25, 0.7)
    self.DefencePauseUntil = now + pause
    if restoreF then self.GuardResume = {Character = char, Generation = characterGeneration, Target = target, At = now + (ok and pause or 0)} end
    self.Punish = nil
    if not ok then self.PunishStatus = "M1 route unavailable"; return end
    self.NextPunish = now + math.max(0.3, pause)
    self.Stats.Punishes += 1
    self.PunishStatus = "Native M1 counter requested"
end

function Combat:ObserveBlockHits(char, generation)
    trackCharacter(connect(char.DescendantAdded, "TBO BlockHit confirmation", function(object)
        local root = getRoot(char)
        if object.Name == "BlockHit" and (object.Parent == char or (root and object:IsDescendantOf(root))) then
            self:OnBlockHit(object, char, generation)
        end
    end))
end

function Combat:ResetDefence()
    self:ReleaseBlock()
    for _, watcher in pairs(self.Defenders) do self:DisconnectList(watcher.Connections) end
    table.clear(self.Defenders)
    table.clear(self.PunishSeen)
    self.Threat, self.Punish, self.LastGuard, self.LastThreat = nil, nil, nil, nil
    self.PendingBlockHit, self.LastBlockHitAt, self.LastGuardEffect = nil, nil, nil
    self.BlockAttackKey, self.GuardTurnTarget, self.InDefenceStep = nil, nil, false
    self.GuardResume, self.GuardHoldUntil, self.GuardSentAt, self.GuardHadAck = nil, nil, nil, nil
    self.GuardRecovery, self.GuardTarget = nil, nil
    self.LastGuardAckMS = nil
    table.clear(self.RecentAttacks)
    table.clear(self.RosterEffects); table.clear(self.RosterEffectKeys); table.clear(self.EnemyRatios)
    self.GuardStatus, self.PunishStatus = "No incoming attack", "Waiting for confirmed block"
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
    self:OnRatioHit(owner, target)
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

-- Recovered donor contracts: application prototypes 90/273 (Garuda Recall),
-- 171/329/331 (Yuki R pulses), and the native combat factory (BlockHit punish).
-- This ports those bounded actions; it does not run the donor loader/VM.
function Combat:PingMilliseconds()
    local now = os.clock()
    if self.PingAt and now - self.PingAt < 0.5 then return self.PingMS end
    local dataOK, data = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    local networkOK, seconds = pcall(function() return LocalPlayer:GetNetworkPing() end)
    -- Current Roblox API reports a round trip in seconds: convert with 1000,
    -- not 2000. Data ping additionally contains replication/processing queues.
    self.DataPingMS = dataOK and finiteNumber(data) and data >= 0 and data or nil
    self.NetworkPingMS = networkOK and finiteNumber(seconds) and seconds >= 0 and finiteNumber(seconds * 1000) and seconds * 1000 or nil
    self.PingSource = self.DataPingMS and "data" or (self.NetworkPingMS and "network" or "fallback")
    self.QueueEstimateMS = self.DataPingMS and self.NetworkPingMS and math.max(0, self.DataPingMS - self.NetworkPingMS) or nil
    self.PingMS, self.PingAt = math.clamp(self.DataPingMS or self.NetworkPingMS or 100, 0, 2000), now
    return self.PingMS
end

function Combat:OnGarudaRecall(owner, ball, destination, duration)
    if owner ~= LocalPlayer.Character then return end
    self.GarudaStatus = "Recall observed"
    self.Stats.GarudaEvents = (self.Stats.GarudaEvents or 0) + 1
    local char = owner
    if not Autos.AutoGarudaRebound or not isCurrentCharacter(char, characterGeneration)
        or char:GetAttribute("Moveset") ~= "Yuki" or self:IsTyping() then self.GarudaStatus = "Recall paused"; return end
    if not finiteNumber(duration) or duration <= 0 or duration > 3 or math.abs(duration - 0.1) < 0.0001 then
        self.GarudaStatus = "Ignoring non-return Recall"; return
    end
    if typeof(ball) ~= "Instance" then self.GarudaStatus = "Recall ball unavailable"; return end
    local seenAt = self.GarudaSeen[ball]
    if seenAt and os.clock() - seenAt < math.max(duration * 0.5, 0.12) then return end
    local moveset = char:FindFirstChild("Moveset")
    local tool = moveset and moveset:FindFirstChild("Garuda Rebound")
    if not tool then self.GarudaStatus = "Garuda Rebound asset unavailable"; return end
    self.GarudaSeen[ball] = os.clock()
    local lead = math.clamp(0.1 + math.floor(self:PingMilliseconds()) / 1000 * 0.6, 0.12, 0.35)
    self.Garuda = {Character = char, Generation = characterGeneration, Tool = tool,
        Due = os.clock() + math.max(duration - lead, 0), Expires = os.clock() + duration + 0.15}
    self.GarudaStatus = "TBO return timing armed"
end

function Combat:StepGaruda()
    local job = self.Garuda
    if not job then return end
    local now = os.clock()
    if not Autos.AutoGarudaRebound or not isCurrentCharacter(job.Character, job.Generation)
        or job.Character:GetAttribute("Moveset") ~= "Yuki" or self:IsTyping()
        or not job.Tool:IsDescendantOf(job.Character) or now > job.Expires then
        self.Garuda = nil; self.GarudaStatus = "Return cancelled"; return
    end
    if now < job.Due then return end
    self.Garuda = nil
    -- The native callback destroys the local ball visual. Its lifetime must not
    -- suppress the owner's actual return timing or require a separate idle state.
    if JJS:Fire("GarudaReboundService", "Activated", job.Tool) then
        self.Stats.GarudaRebounds += 1; self.GarudaStatus = "Rebound requested"
    else self.GarudaStatus = "Garuda return remote unavailable" end
end

function Combat:HasYukiRoute()
    local char = LocalPlayer.Character
    if not char or char:GetAttribute("Moveset") ~= "Yuki" then return false end
    local info = char:FindFirstChild("Info")
    local item = info and info:FindFirstChild("Item")
    local custom = char:FindFirstChild("CustomChar")
    return not (item and item:FindFirstChild("M2"))
        and not (custom and custom:GetAttribute("CustomSpecial"))
end

function Combat:YukiMeterFull()
    local fill = self:SpecialFill()
    return fill and fill:IsA("GuiObject") and fill.Size.X.Scale >= 0.999 or false
end

function Combat:OnYukiEffect(effect, char, value)
    if char ~= LocalPlayer.Character or char:GetAttribute("Moveset") ~= "Yuki" then return end
    if effect == "MeterVis" and typeof(value) == "Instance" and (value:IsA("NumberValue") or value:IsA("IntValue")) then
        self.YukiMass = {Character = char, Generation = characterGeneration, Meter = value}
    elseif effect == "Buildup" then
        self.Stats.YukiBuildups = (self.Stats.YukiBuildups or 0) + 1
        if self.YukiJob then self.YukiJob.NativeBuildup = true end
    end
end

function Combat:YukiReady(job)
    local char = job.Character
    if not Alive or not Autos.YukiInstantCharge or char ~= LocalPlayer.Character
        or job.Generation ~= characterGeneration or not char.Parent or not self:HasYukiRoute()
        or self:IsTyping() then return false, "Charge cancelled" end
    local root = getRoot(char)
    if not root or root:FindFirstChild("GrabOST") or root:FindFirstChild("Finish") then return false, "Native grab / finish started" end
    -- P329 checks cooldown and InSkill once, before its edge loop. Rechecking
    -- cooldown here cancels the helper on the acknowledgement of its own R.
    local mass = self.YukiMass
    if mass and mass.Character == char and mass.Generation == job.Generation and mass.Meter.Parent then
        local maximum = mass.Meter:GetAttribute("Max")
        if finiteNumber(maximum) and maximum > 0 and mass.Meter.Value >= maximum then return false, "Native mass meter full" end
    end
    return true
end

function Combat:CancelYukiCharge(reason)
    local job = self.YukiJob
    self.YukiJob = nil
    if job and job.Pressed and job.Character == LocalPlayer.Character then JJS:Fire("YukiService", "RightDeactivated") end
    if reason then self.YukiStatus = reason end
end

function Combat:BeginYukiCharge(readyBeforeNative)
    if not Autos.YukiInstantCharge or not self:HasYukiRoute() or self:IsTyping() or self.YukiJob then return false end
    local char = LocalPlayer.Character
    if readyBeforeNative == nil then
        readyBeforeNative = not self:HasState(char, "InSkill")
            and (self:SpecialRemaining(char) == 0 or self:YukiMeterFull())
    end
    if not readyBeforeNative then self.YukiStatus = "Native R; helper waits for R cooldown / skill recovery"; return false end
    if not JJS:GetRemote("YukiService", "RightActivated") or not JJS:GetRemote("YukiService", "RightDeactivated") then
        self.YukiStatus = "Yuki R remotes unavailable"; return false
    end
    -- Native Tool.Special passes GetTarget(), which can be nil. TBO's Dummy
    -- argument is optional for charging and must not prevent public-server use.
    local target
    local folder = workspace:FindFirstChild("Characters")
    local dummy = folder and folder:FindFirstChild("Dummy")
    if dummy and dummy:IsA("Model") and getRoot(dummy) then target = dummy
    elseif self.Tool and type(self.Tool.GetTarget) == "function" then
        local ok, candidate = pcall(self.Tool.GetTarget, self.Tool)
        if ok and typeof(candidate) == "Instance" and candidate:IsA("Model") then target = candidate end
    end
    local job = {Character = char, Generation = characterGeneration, Target = target,
        Started = os.clock(), Pressed = false, Sent = 0, InitialCharge = char:GetAttribute("Charge")}
    local ready, reason = self:YukiReady(job)
    if not ready then self.YukiStatus = reason; return false end
    if os.clock() < self.NextYukiCharge then return false end
    self.YukiJob, self.NextYukiCharge, self.YukiStatus = job, os.clock() + 0.15, "TBO R pulses active"
    spawn("TBO Yuki R pulses", function()
        while self.YukiJob == job and job.Sent < 32 and os.clock() - job.Started < 0.65 do
            local eligible, why = self:YukiReady(job)
            if not eligible then self:CancelYukiCharge(why); return end
            local cycleAt = os.clock()
            for index, at in ipairs({0, 0.0005, 0.001, 0.0015}) do
                local remaining = at - (os.clock() - cycleAt)
                if remaining > 0 then task.wait(remaining) end
                if self.YukiJob ~= job then return end
                local valid, stopped = self:YukiReady(job)
                if not valid then self:CancelYukiCharge(stopped); return end
                local pressed = index % 2 == 1
                job.Pressed = pressed or job.Pressed
                local ok
                if pressed then ok = JJS:Fire("YukiService", "RightActivated", target)
                else ok = JJS:Fire("YukiService", "RightDeactivated") end
                if not ok then self:CancelYukiCharge("Yuki pulse remote unavailable"); return end
                if not pressed then job.Pressed = false end
                job.Sent += 1; self.Stats.YukiPulses += 1
            end
            if os.clock() - cycleAt < 0.001 then task.wait() end
        end
        if self.YukiJob == job then
            local charge = char:GetAttribute("Charge")
            self:CancelYukiCharge("Pulse sequence complete; native Charge=" .. tostring(charge) .. "; full mass unconfirmed")
        end
    end)
    return true
end

function Combat:StepYukiCharge()
    local job = self.YukiJob
    if not job then return end
    local valid, reason = self:YukiReady(job)
    if not valid then self:CancelYukiCharge(reason) end
end

function Combat:InstallYukiController(tool)
    self:Patch(tool, "Special", function(original)
        return function(controller, ...)
            if self:RatioInput() then return end
            local char = LocalPlayer.Character
            local yukiReady = char and Autos.YukiInstantCharge and self:HasYukiRoute() and not self:IsTyping()
                and not self:HasState(char, "InSkill") and (self:SpecialRemaining(char) == 0 or self:YukiMeterFull())
            local results
            if self:RatioInputTarget() then
                -- Scope native GetTarget() only to this Nanami Special call.
                -- MouseAssist may be off; its unrelated routes stay unchanged.
                results = table.pack(self:WithMouseRoute("ratio", original, controller, ...))
            else results = table.pack(original(controller, ...)) end
            self:BeginYukiCharge(yukiReady == true)
            return table.unpack(results, 1, results.n)
        end
    end)
end

local NATIVE_AIR_TYPES = {
    ["Cursed Strikes"] = 1,
    ["Crushing Blow"] = 1,
    ["Dismantle"] = 1,
    ["Cleave"] = 1,
    ["Reversal Red MAX"] = 1,
    ["Lapse Blue MAX"] = 1,
    ["Hollow Purple"] = 1,
    ["Rough Energy"] = 1,
    ["Stockpile"] = 1,
    ["Flowing Red Scale"] = 1,
    ["Slicing Exorcism"] = 1,
    ["Swift Kick"] = 6,
    ["Kamehameha"] = 1,
    ["Ki Spam"] = 1,
    ["Staff Extend"] = 1,
    ["Execution"] = 1,
    ["Mass Breaker"] = 1,
    ["Shut Up!"] = 1,
    ["Veilstep"] = 1,
    ["Revolve"] = 1,
    ["Outburst"] = 1,
    ["Second Wind"] = 1,
    ["Resolute Slash"] = 5,
    ["Copy"] = 5,
    ["Rika Launch"] = 1,
    ["Blunt Cut"] = 1,
    ["Collapse"] = 1,
    ["Sharpen"] = 1,
    ["Ambush"] = 1,
    ["Impetus Updraft"] = 1,
    ["Circling"] = 1,
    ["Murmurate"] = 1,
    ["Bird Control"] = 5,
    ["Root Swarm"] = 1,
    ["Surging Thorns"] = 1,
    ["Defense Response"] = 1,
    ["Tracking Roots"] = 5,
    ["Root Rampage"] = 1,
    ["Granite Blast"] = 1,
    ["\"What are you after?\""] = 1,
    ["Detach"] = 1,
    ["Roach Swarm"] = 1,
    ["Sky Distortion"] = 1,
    ["Turbulence"] = 7,
    ["Transcend"] = 1,
    ["Debilitate"] = 6,
}

-- A scoped hook on the native Knit signal retains each move's real wire type.
-- Boolean air flags are forced only inside this character's UseTool call.
-- Target Models, aim points, movement vectors and unknown move contracts pass through.
function Combat:PatchAirSignal(signal)
    if type(signal) ~= "table" or type(signal.Fire) ~= "function" or self.FailedAirSignals[signal] then return end
    local ok = self:Patch(signal, "Fire", function(original)
        return function(object, ...)
            local args = table.pack(...)
            local tool, payload = args[1], args[2]
            local context = self.AirContexts[coroutine.running() or self]
            if Autos.AutoAirVariants and context and context.Tool == tool
                and context.Character == LocalPlayer.Character and context.Generation == characterGeneration
                and context.Epoch == self.AirEpoch
                and tool.Parent and tool:IsDescendantOf(context.Character) and not self:IsTyping() then
                if (context.Kind == 1 or context.Kind == 7) and (payload == nil or type(payload) == "boolean") then
                    payload = true
                    args.n = math.max(args.n, 2)
                    self.Stats.AirOverrides += 1
                elseif (context.Kind == 5 or context.Kind == 6) and type(payload) == "table" then
                    payload = table.clone(payload)
                    payload[1] = true
                    self.Stats.AirOverrides += 1
                end
            end
            args[2] = payload
            return original(object, table.unpack(args, 1, args.n))
        end
    end)
    if not ok then self.FailedAirSignals[signal] = true end
end

function Combat:InstallAirControllers(tool)
    self:Patch(tool, "GetToolService", function(original)
        return function(controller, ...)
            local results = table.pack(original(controller, ...))
            local service = results[1]
            if Autos.AutoAirVariants and type(service) == "table" then
                self:PatchAirSignal(service.Activated)
                self:PatchAirSignal(service.Deactivated)
            end
            return table.unpack(results, 1, results.n)
        end
    end)
    self:Patch(tool, "UseTool", function(original)
        return function(controller, asset, mode, ...)
            if not Autos.AutoAirVariants or typeof(asset) ~= "Instance"
                or not LocalPlayer.Character or not asset:IsDescendantOf(LocalPlayer.Character)
                or self:IsTyping() or (mode ~= "Activated" and mode ~= "Deactivated") then
                return original(controller, asset, mode, ...)
            end
            local kind = NATIVE_AIR_TYPES[asset.Name]
            if not kind then return original(controller, asset, mode, ...) end
            local token = coroutine.running() or self
            local previous = self.AirContexts[token]
            self.AirContexts[token] = {Tool = asset, Kind = kind, Character = LocalPlayer.Character,
                Generation = characterGeneration, Epoch = self.AirEpoch}
            local results = table.pack(pcall(original, controller, asset, mode, ...))
            self.AirContexts[token] = previous
            if not results[1] then error(results[2], 0) end
            return table.unpack(results, 2, results.n)
        end
    end)
end

-- TBO ports: burst 128/295, World Slash 115/381, Shut Up 19/363,
-- adaptation 168/328/390, and air follow-ups 131/298.
function Combat:OwnedTool(serviceName, fallbackName)
    local char = LocalPlayer.Character
    local moves = char and char:FindFirstChild("Moveset")
    if not moves then return end
    for _, tool in ipairs(moves:GetChildren()) do
        if tool:GetAttribute("Service") == serviceName then return tool end
    end
    return fallbackName and moves:FindFirstChild(fallbackName) or nil
end

function Combat:SpecialFill()
    local main = PlayerGui:FindFirstChild("Main")
    local controls = main and main:FindFirstChild("Controls")
    local ultimate = (controls and controls:FindFirstChild("Ultimate")) or (main and main:FindFirstChild("Ultimate"))
    local special = ultimate and ultimate:FindFirstChild("Special")
    return special and special:FindFirstChild("Fill")
end

function Combat:SpecialFull()
    local fill = self:SpecialFill()
    return fill and fill:IsA("GuiObject") and fill.Size.X.Scale >= 0.999
end

function Combat:ObserveOwnMarker(object, char)
    if object.Parent == getRoot(char) and object.Name == "BurstIcon" then
        self.BurstMarkers[object] = {Next = 0, Attempts = 0}
    end
    if object.Parent == char:FindFirstChild("Info") and string.find(object.Name, "Air", 1, true) then
        self.AirMarkers[object] = false
    end
end

function Combat:StepBurst()
    if not Autos.AutoBurst then self.BurstStatus = "Off"; self.NextBurst = 0; return end
    if self:IsTyping() or movementState ~= "IDLE" then self.BurstStatus = "Burst paused"; return end
    local char, now = LocalPlayer.Character, os.clock()
    if not isCurrentCharacter(char, characterGeneration) then return end
    local root, hum, info = getRoot(char), getHumanoid(char), char:FindFirstChild("Info")
    if not root or not hum or hum.Health <= 0 or char:GetAttribute("Dead") then self.BurstStatus = "No live character"; return end
    -- MovementController's anti-team branch (proto29, pc464-479/533)
    -- creates BurstIcon. Its separate ordinary evasive branch is not automated.
    -- A leftover visual icon alone cannot authorize another Dash request.
    local burst = char:GetAttribute("Burst") and not (info and info:GetAttribute("Burst"))
    if not burst then
        self.BurstStatus = "Waiting for anti-team Burst"; self.NextBurst = 0; return
    end
    if now < self.NextBurst then return end
    local move = hum.MoveDirection
    if typeof(move) ~= "Vector3" then move = Vector3.zero end
    local camera = workspace.CurrentCamera
    if camera then
        local ok, relative = pcall(function() return camera.CFrame:VectorToObjectSpace(move) end)
        if ok then move = relative end
    end
    -- TBO P295 substitutes Left for Front. Only side/back choices consume burst.
    local direction = "Left"
    if move.Magnitude > 0.01 then
        if math.abs(move.X) > math.abs(move.Z) then direction = move.X > 0 and "Right" or "Left"
        elseif move.Z > 0 then direction = "Back" end
    end
    -- Retry only while the native anti-team Burst grant exists.
    -- A failed three-request budget must not disable the rest of the session.
    self.NextBurst = now + 0.1
    if JJS:Fire("MovementService", "Dash", direction, true) then
        self.Stats.Bursts += 1; self.BurstStatus = "Native " .. direction .. " burst requested"
    else self.BurstStatus = "Burst Dash remote unavailable" end
end

function Combat:OnMinigameQTE(remote)
    if typeof(remote) ~= "Instance" or not remote:IsA("RemoteEvent") or not remote.Parent then return end
    if self.QTEJobs[remote] then return end
    self.QTEJobs[remote] = {Character = LocalPlayer.Character, Generation = characterGeneration,
        Gui = PlayerGui:FindFirstChild("QTE"), Next = 0, WaitGuiUntil = os.clock() + 0.5}
end

function Combat:StepQTE()
    local now = os.clock()
    local hasNative = false
    for remote, job in pairs(self.QTEJobs) do
        if not remote.Parent or not isCurrentCharacter(job.Character, job.Generation)
            or (job.Gui and job.Gui.Parent ~= PlayerGui) then self.QTEJobs[remote] = nil; continue end
        if not job.Gui then
            job.Gui = PlayerGui:FindFirstChild("QTE")
            if not job.Gui and now > job.WaitGuiUntil then self.QTEJobs[remote] = nil; continue end
        end
        hasNative = true
        if not Autos.AutoQTE or self:IsTyping() or now < job.Next or not job.Gui
            or job.Gui.Enabled == false then continue end
        job.Next = now + Options.QTEInterval
        local ok = Runtime:Run("Hiromi QTE response", function() remote:FireServer(true) end)
        if ok then self.Stats.QTEResponses += 1 else self.QTEJobs[remote] = nil end
    end
    if hasNative or not Autos.AutoQTE or self:IsTyping() or now < self.NextQTEInput then return end
    if not isCurrentCharacter(LocalPlayer.Character, characterGeneration) then return end
    for gui in pairs(self.QTEGuis) do
        if gui.Parent ~= PlayerGui then self.QTEGuis[gui] = nil; continue end
        if gui.Enabled == false or gui.Name ~= "QTE" then continue end
        local pc, mobile = gui:FindFirstChild("QTE_PC", true), gui:FindFirstChild("QTE_MOBILE", true)
        local sent = false
        if UserInputService.TouchEnabled and mobile and mobile:IsA("GuiButton") and mobile.Visible then
            local fire = getGlobalFunction("firesignal")
            if type(fire) == "function" then
                sent = pcall(fire, mobile.MouseButton1Down)
            else
                local connections = getGlobalFunction("getconnections")
                if type(connections) == "function" then
                    local ok, listeners = pcall(connections, mobile.MouseButton1Down)
                    if ok then
                        for _, listener in ipairs(listeners) do
                            if listener.Enabled ~= false and type(listener.Fire) == "function" then
                                if pcall(function() listener:Fire() end) then sent = true end
                            end
                        end
                    end
                end
            end
        elseif pc and pc:IsA("TextLabel") and pc.Visible and type(pc.Text) == "string" then
            -- These are the native QTE controllers' keyboard choices. Do not turn
            -- arbitrary UI text into synthetic keys or duplicate Beam's own session.
            local allowed = {W = true, A = true, D = true}
            if allowed[pc.Text] then sent = pressKey(Enum.KeyCode[pc.Text]) end
        end
        self.NextQTEInput = now + Options.QTEInterval
        if sent then self.Stats.QTEResponses += 1 end
        return
    end
end

function Combat:BeginWorldSlash(track)
    local char = LocalPlayer.Character
    if not Autos.AutoWorldSlash or self.WorldSlashJob or self.SuiteSeen[track] or self:IsTyping()
        or not isCurrentCharacter(char, characterGeneration) or char:GetAttribute("Moveset") ~= "Itadori"
        or not self:SpecialFull() or not self:CanAct(char, true) then return end
    local rush = self:OwnedTool("RushService", "Rush")
    local open = self:OwnedTool("FlameArrowService", "Open")
    if not rush or not open then return end
    self.SuiteSeen[track] = true
    if not JJS:Fire("RushService", "Activated", rush) then return end
    if not JJS:Fire("FlameArrowService", "Activated", open) then return end
    self.WorldSlashJob = {Character = char, Generation = characterGeneration, Due = os.clock() + 0.8,
        Expires = os.clock() + 1.2, Rush = rush, Open = open}
end

function Combat:StepWorldSlash()
    local job = self.WorldSlashJob
    if not job then return end
    if not Autos.AutoWorldSlash or not isCurrentCharacter(job.Character, job.Generation)
        or job.Character:GetAttribute("Moveset") ~= "Itadori" or self:IsTyping()
        or not self:CanAct(job.Character, true) or not job.Rush:IsDescendantOf(job.Character)
        or not job.Open:IsDescendantOf(job.Character) or os.clock() > job.Expires then self.WorldSlashJob = nil; return end
    if os.clock() < job.Due then return end
    self.WorldSlashJob = nil
    if JJS:Fire("ItadoriService", "RightActivated") then self.Stats.WorldSlashes += 1 end
end

function Combat:EndShutUp()
    local job = self.ShutUpJob
    self.ShutUpJob = nil
    if job and job.Humanoid.Parent and job.Humanoid.AutoRotate == false then
        job.Humanoid.AutoRotate = job.AutoRotate
    end
end

function Combat:BeginShutUp(track)
    local char = LocalPlayer.Character
    if not Autos.AutoShutUp or self.ShutUpJob or self.SuiteSeen[track] or self:IsTyping()
        or not isCurrentCharacter(char, characterGeneration) or char:GetAttribute("Moveset") ~= "Charles"
        or movementState ~= "IDLE" then return end
    local root, hum = getRoot(char), getHumanoid(char)
    if not root then return end
    self.SuiteSeen[track] = true
    -- Hand ownership over before saving a restore value. Hybrid's temporary
    -- AutoRotate=false must never become this helper's persistent baseline.
    self:ReleaseFacing()
    self.ShutUpJob = {Character = char, Generation = characterGeneration, Humanoid = hum,
        AutoRotate = hum.AutoRotate, Until = os.clock() + 0.5}
    hum.AutoRotate = false
    root.CFrame = CFrame.lookAt(root.Position, root.Position - root.CFrame.LookVector)
    self.Stats.ShutUps += 1
end

function Combat:StepShutUp()
    local job = self.ShutUpJob
    if job and (not Autos.AutoShutUp or not isCurrentCharacter(job.Character, job.Generation)
        or job.Character:GetAttribute("Moveset") ~= "Charles" or self:IsTyping()
        or os.clock() >= job.Until) then self:EndShutUp() end
end

function Combat:OnSuiteAnimation(track, id)
    self.SkillAssist:OnAnimation(track, id)
    if id == "rbxassetid://131506102901134" then self:BeginWorldSlash(track)
    elseif id == "rbxassetid://79860101129549" then self:BeginShutUp(track) end
end

function Combat:OnAdaptThreat(track, target)
    local char = LocalPlayer.Character
    if not Autos.AutoAdapt or not char or char:GetAttribute("Moveset") ~= "Mahoraga"
        or not track.Animation or track.Animation.AnimationId ~= "rbxassetid://132725601768618"
        or self.AdaptSeen[track] then return end
    self.AdaptSeen[track] = true
    table.insert(self.AdaptJobs, {Track = track, Target = target, Character = char,
        Generation = characterGeneration, Expires = os.clock() + 3})
end

function Combat:StepAdapt()
    for index = #self.AdaptJobs, 1, -1 do
        local job = self.AdaptJobs[index]
        local ownRoot, enemyRoot = getRoot(job.Character), getRoot(job.Target)
        if not Autos.AutoAdapt or not isCurrentCharacter(job.Character, job.Generation)
            or job.Character:GetAttribute("Moveset") ~= "Mahoraga" or not job.Target.Parent
            or not ownRoot or not enemyRoot or job.Track.IsPlaying ~= true or self:IsTyping()
            or os.clock() > job.Expires or (ownRoot.Position - enemyRoot.Position).Magnitude > 46 then
            table.remove(self.AdaptJobs, index)
        elseif job.Track.TimePosition >= 0.4 then
            table.remove(self.AdaptJobs, index)
            if os.clock() >= self.NextAdapt and JJS:Fire("MahoragaService", "RightActivated") then
                self.Stats.Adaptations += 1
                local gui = PlayerGui:FindFirstChild("Adaptation")
                local mode = gui and gui:FindFirstChild("Type")
                -- Preserve TBO's green-mode follow-up after the adaptation press.
                if mode and (mode:IsA("ImageLabel") or mode:IsA("ImageButton"))
                    and mode.ImageColor3 == Color3.fromRGB(0, 255, 0) then
                    JJS:Fire("MahoragaService", "Ultimate")
                end
                self.NextAdapt = os.clock() + 0.35
            end
        end
    end
end

function Combat:StepAirMarkers()
    if not Autos.AutoAirVariants or self:IsTyping() then return end
    local char = LocalPlayer.Character
    if not isCurrentCharacter(char, characterGeneration) then return end
    local info = char:FindFirstChild("Info")
    for marker, done in pairs(self.AirMarkers) do
        if marker.Parent ~= info then self.AirMarkers[marker] = nil; continue end
        if done then continue end
        local moveset = char:GetAttribute("Moveset")
        if moveset == "Locust" then
            self.AirMarkers[marker] = true
            if JJS:Fire("LocustService", "RightActivated") then self.Stats.AirFollowUps += 1 end
        elseif moveset == "Hiromi" then
            local tool = self:OwnedTool("JudgeReachService", "Judgement's Reach")
            if tool then
                self.AirMarkers[marker] = true
                if JJS:Fire("JudgeReachService", "Activated", tool) then self.Stats.AirFollowUps += 1 end
            end
        end
    end
end

function Combat:ResetSuiteCharacter()
    self:EndShutUp()
    self.WorldSlashJob = nil
    table.clear(self.AdaptJobs)
    for _, list in ipairs({self.SuiteSeen, self.AdaptSeen, self.BurstMarkers, self.AirMarkers, self.QTEJobs}) do table.clear(list) end
    self.NextBurst, self.NextAdapt = 0, 0
end

function Combat:MarkSettingsDirty(force)
    if self.LoadingConfig then return end
    self.ConfigRevision += 1
    self.ConfigDirty = true
    if Autos.AutoSave or force then
        if force then self.SaveForced = true end
        self.SaveDue = os.clock() + 0.6
        self.SaveStatus = "Pending"
    end
end

function Combat:StepAutoSave()
    if self.SaveDue and os.clock() >= self.SaveDue and not self.LoadingConfig then
        self.SaveDue = nil
        if self.SaveBusy then self.SaveDue = os.clock() + 0.6; return end
        saveConfig()
    end
end

function Combat:FirePrompt(prompt)
    if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") or not prompt.Parent then
        return false, "prompt unavailable"
    end
    if self.PromptBusy[prompt] then return false, "prompt busy" end
    self.PromptBusy[prompt] = true
    local fire = getGlobalFunction("fireproximityprompt")
    local ok, reason
    if type(fire) == "function" then
        ok, reason = pcall(fire, prompt)
    else
        -- Native fallback keeps the prompt's other settings and restores duration
        -- even if the bridge rejects the action. No teleport or range edits.
        local duration = prompt.HoldDuration
        ok, reason = pcall(function()
            prompt.HoldDuration = 0
            prompt:InputHoldBegin()
        end)
        local released, releaseReason = pcall(function() prompt:InputHoldEnd() end)
        if ok and not released then ok, reason = false, releaseReason end
        pcall(function() if prompt.HoldDuration == 0 then prompt.HoldDuration = duration end end)
    end
    self.PromptBusy[prompt] = nil
    if ok then self.Stats.Prompts += 1 end
    return ok, reason
end

function Combat:ConsiderTrainPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or not prompt:IsDescendantOf(workspace) then return end
    local part = prompt.Parent
    if part and part:IsA("Attachment") then part = part.Parent end
    if not part or not part:IsA("BasePart") then return end
    local cursor, trainButton, station = part, false, false
    while cursor and cursor ~= workspace do
        if cursor.Name == "ButtonTrain" then trainButton = true end
        if cursor.Name == "StationControl" then station = true end
        cursor = cursor.Parent
    end
    if not trainButton or not station then return end
    if self.TrainPrompt ~= prompt then
        self.TrainPrompt, self.TrainButton = prompt, part
        self.TrainRequested, self.NextTrainCheck = false, 0
    end
end

function Combat:DiscoverTrain()
    if self.TrainPrompt and self.TrainPrompt:IsDescendantOf(workspace) then return end
    self.TrainPrompt, self.TrainButton = nil, nil
    local map = workspace:FindFirstChild("Map")
    local destructible = map and map:FindFirstChild("Destructible")
    local station = destructible and destructible:FindFirstChild("StationControl", true)
    local button = station and station:FindFirstChild("ButtonTrain")
    local prompt = button and button:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then self:ConsiderTrainPrompt(prompt) end
end

function Combat:StepTrain()
    if not Autos.AutoSpawnTrain or os.clock() < self.NextTrainCheck then return end
    self.NextTrainCheck = os.clock() + 0.25
    local prompt, part = self.TrainPrompt, self.TrainButton
    if not prompt or not part or not prompt:IsDescendantOf(workspace) or not part.Parent then return end
    local color, brick = part.Color, part.BrickColor
    local ready = brick and brick.Name == "Shamrock"
    if typeof(color) == "Color3" then
        ready = ready or (math.abs(color.R - 91/255) < 0.005 and math.abs(color.G - 154/255) < 0.005
            and math.abs(color.B - 76/255) < 0.005)
    end
    if not ready then self.TrainRequested = false; return end
    if self.TrainRequested then return end
    local ok = self:FirePrompt(prompt)
    if ok then
        self.TrainRequested = true
        self.LastTrainRequest = os.clock()
        self.Stats.TrainRequests += 1
    else
        self.NextTrainCheck = os.clock() + 2
    end
end

function Combat:EmoteRoots()
    local emotes = PlayerGui:FindFirstChild("Emotes")
    local emote = emotes and emotes:FindFirstChild("Emote")
    local wheel = emote and emote:FindFirstChild("EmoteMenu")
    local menus = PlayerGui:FindFirstChild("Menus")
    local group = menus and menus:FindFirstChild("Group")
    local inventory = group and group:FindFirstChild("Inventory")
    local items = inventory and inventory:FindFirstChild("Items")
    local list = items and items:FindFirstChild("Emotes")
    return wheel, list and list:FindFirstChild("Equipped")
end

function Combat:ReleaseEmoteRecord(object)
    local record = self.EmoteRecords[object]
    if not record then return end
    self.EmoteRecords[object] = nil
    record.Connection:Disconnect()
    pcall(function() if object.Visible == true then object.Visible = record.Original end end)
end

function Combat:ConsiderEmote(object)
    if not Autos.ExtraEmoteSlots or not object:IsA("GuiObject") or self.EmoteRecords[object] then return end
    local slot = tonumber(object.Name)
    if not (slot and slot >= 5 and slot <= 8) and object.Name ~= "Switch" then return end
    local wheel, equipped = self:EmoteRoots()
    if not (wheel and object:IsDescendantOf(wheel)) and not (equipped and object:IsDescendantOf(equipped)) then return end
    if object.Name == "Switch" and object.Parent ~= wheel then return end
    local record = {Original = object.Visible, Busy = false}
    self.EmoteRecords[object] = record
    record.Connection = connect(object:GetPropertyChangedSignal("Visible"), "extra emote slot visibility", function()
        if not Alive or record.Busy or not Autos.ExtraEmoteSlots then return end
        record.Original = object.Visible
        record.Busy = true
        object.Visible = true
        record.Busy = false
    end)
    record.Busy = true
    object.Visible = true
    record.Busy = false
end

function Combat:RefreshEmoteSlots()
    if not Autos.ExtraEmoteSlots then
        local objects = {}
        for object in pairs(self.EmoteRecords) do table.insert(objects, object) end
        for _, object in ipairs(objects) do self:ReleaseEmoteRecord(object) end
        return
    end
    local wheel, equipped = self:EmoteRoots()
    for _, root in pairs({wheel, equipped}) do
        for _, object in ipairs(root:GetDescendants()) do self:ConsiderEmote(object) end
    end
end

function Combat:SetupConveniences()
    -- Infinite Yield Reborn instantpp: fire only the prompt the user starts holding.
    -- One listener serves existing and streamed prompts; it never activates them all.
    local ok, prompts = pcall(game.GetService, game, "ProximityPromptService")
    if ok and prompts then
        track(connect(prompts.PromptButtonHoldBegan, "IYR instant proximity prompt", function(prompt)
            if Alive and Autos.InstantPrompts and not self:IsTyping() then self:FirePrompt(prompt) end
        end))
    end
    track(connect(workspace.DescendantAdded, "train prompt arrival", function(object)
        if Alive and object:IsA("ProximityPrompt") then self:ConsiderTrainPrompt(object) end
    end))
    track(connect(PlayerGui.DescendantAdded, "emote and QTE UI arrival", function(object)
        if not Alive then return end
        if object:IsA("GuiObject") then self:ConsiderEmote(object) end
        if object.Parent == PlayerGui and object.Name == "QTE" and object:IsA("ScreenGui") then self.QTEGuis[object] = true end
    end))
    track(connect(PlayerGui.DescendantRemoving, "emote and QTE UI departure", function(object)
        self.QTEGuis[object] = nil
        if self.EmoteRecords[object] then self:ReleaseEmoteRecord(object) end
    end))
    for _, object in ipairs(PlayerGui:GetChildren()) do
        if object.Name == "QTE" and object:IsA("ScreenGui") then self.QTEGuis[object] = true end
    end
    self:DiscoverTrain()
    self:RefreshEmoteSlots()
end

function Combat:DestroyConveniences()
    local objects = {}
    for object in pairs(self.EmoteRecords) do table.insert(objects, object) end
    for _, object in ipairs(objects) do self:ReleaseEmoteRecord(object) end
    table.clear(self.PromptBusy)
    table.clear(self.QTEGuis)
    self.TrainPrompt, self.TrainButton, self.SaveButton = nil, nil, nil
end

-- RyuJJS hitbox module. Geometry and wire contract recovered from JJS
-- Combat/HitboxController: SphereHitbox(owner, offsetCFrame, diameter) -> {Model}.
-- HitboxService owns the temporary reporter and its 0.025s cadence. This module
-- adds no reporter, heartbeat listener, global namecall hook, or invented fields.
-- TBO P052/P240 supplies a replacement diameter through getgenv().Size.
-- Here 20 is a minimum diameter: larger native attacks are never reduced.
Combat.Hitboxes = {Name = "RyuJJS Hitboxes", Backend = "waiting", Queries = 0,
    Fallbacks = 0, Candidates = 0, ChaseIds = {
    ["rbxassetid://104148378077935"] = {["Misc"] = true},
    ["rbxassetid://105571879949076"] = {["Kurourushi"] = true},
    ["rbxassetid://106224500692893"] = {["Uro"] = true},
    ["rbxassetid://110978068388232"] = {["Choso"] = true, ["Gojo"] = true, ["Heian"] = true, ["Itadori"] = true, ["Mahito"] = true, ["Mahoraga"] = true, ["Mechamaru"] = true, ["Megumi"] = true, ["Reggie"] = true, ["Todo"] = true, ["Yuta"] = true},
    ["rbxassetid://120951759618134"] = {["Hiromi"] = true},
    ["rbxassetid://122074769949629"] = {["Haruta"] = true},
    ["rbxassetid://124777463468279"] = {["Goku"] = true},
    ["rbxassetid://128267680345523"] = {["MeiMei"] = true},
    ["rbxassetid://129392532939530"] = {["Misc"] = true},
    ["rbxassetid://130135202362252"] = {["Yuta"] = true},
    ["rbxassetid://130284226842903"] = {["Locust"] = true, ["Yuki"] = true},
    ["rbxassetid://132855702748568"] = {["Hiromi"] = true},
    ["rbxassetid://134917827147266"] = {["Haruta"] = true},
    ["rbxassetid://137158942150039"] = {["Toji"] = true},
    ["rbxassetid://138169151223960"] = {["Hanami"] = true},
    ["rbxassetid://140597320237985"] = {["Charles"] = true},
    ["rbxassetid://76470718091246"] = {["Kurourushi"] = true},
    ["rbxassetid://81708642912019"] = {["Nanami"] = true},
    ["rbxassetid://83782195794718"] = {["Ryu"] = true},
    ["rbxassetid://86626502434817"] = {["Goku"] = true},
    ["rbxassetid://95437415745300"] = {["Toji"] = true},
    ["rbxassetid://98920127166691"] = {["Toji"] = true},
    ["rbxassetid://99451940496871"] = {["Hakari"] = true},
}}

function Combat.Hitboxes:ValidVector(value)
    return typeof(value) == "Vector3" and finiteNumber(value.X)
        and finiteNumber(value.Y) and finiteNumber(value.Z)
end

function Combat.Hitboxes:Center(character, offset)
    if character == nil then return self:ValidVector(offset) and offset or nil end
    if typeof(character) ~= "Instance" or not character:IsA("Model") or not character.Parent
        or typeof(offset) ~= "CFrame" then return end
    local root = getRoot(character)
    if not root or not self:ValidVector(offset.Position) then return end
    local center = (root.CFrame * offset).Position
    return self:ValidVector(center) and center or nil
end

function Combat.Hitboxes:Sphere(character, offset, diameter)
    if not Alive or not finiteNumber(diameter) or diameter <= 0 or diameter > 2048 then
        return nil, "invalid diameter"
    end
    local center = self:Center(character, offset)
    if not center then return nil, "invalid origin" end
    local characters = workspace:FindFirstChild("Characters")
    if not characters then return nil, "character folder unavailable" end
    if self.Folder ~= characters or not self.Overlap then
        self.Folder = characters
        self.Overlap = OverlapParams.new()
        self.Overlap.FilterType = Enum.RaycastFilterType.Include
        self.Overlap.FilterDescendantsInstances = {characters}
    end
    local ok, parts = pcall(workspace.GetPartBoundsInRadius, workspace, center, diameter / 2, self.Overlap)
    if not ok or type(parts) ~= "table" then
        self.Backend = "native fallback"
        self.Fallbacks += 1
        return nil, "spatial query unavailable"
    end
    local result, seen = {}, {}
    for _, part in ipairs(parts) do
        -- JJS tests root parts only; hats, limbs and nested props are not hits.
        if typeof(part) == "Instance" and part:IsA("BasePart") and part.Name == "HumanoidRootPart" then
            local model = part.Parent
            local hum = model and model:IsA("Model") and getHumanoid(model)
            if model ~= character and hum and hum.Health > 0 and not seen[model]
                and model:IsDescendantOf(characters) then
                seen[model] = true
                table.insert(result, model)
            end
        end
    end
    self.Queries += 1
    self.Candidates += #result
    self.Backend = "spatial query"
    self.LastQuery = {Center = center, Diameter = diameter, Candidates = #result}
    return result
end

function Combat.Hitboxes:Intercept(original, controller, character, offset, diameter, ...)
    local assisted = Combat.SkillAssist:HasWindow(character)
    if not Alive or character ~= LocalPlayer.Character or not character
        or not finiteNumber(diameter) or diameter <= 0 or typeof(offset) ~= "CFrame"
        or not self:Center(character, offset) or Combat:IsTyping()
        or (not isCurrentCharacter(character, characterGeneration) and not assisted) then
        return original(controller, character, offset, diameter, ...)
    end
    if not Autos.TBOHitbox and not Autos.ExtendedHitbox and not assisted then
        return original(controller, character, offset, diameter, ...)
    end
    local effective = Autos.TBOHitbox and math.max(diameter, Options.HitboxSize) or diameter
    -- Call the live native function first, retaining its visualization and query.
    -- The reconstructed module is a fallback if that native route throws.
    local values = table.pack(pcall(original, controller, character, offset, effective, ...))
    local result = values[2]
    if not values[1] then
        local nativeError = values[2]
        result = self:Sphere(character, offset, effective)
        self.Fallbacks += 1
        if not result then error(nativeError, 0) end
        self.Candidates -= #result -- Sphere already counted its fallback candidates.
        values = table.pack(true, result)
        self.Backend = "reconstructed fallback"
    else
        self.Backend = "native SphereHitbox"
        if type(result) ~= "table" then return table.unpack(values, 2, values.n) end
        self.Queries += 1
        self.LastQuery = {Center = self:Center(character, offset), Diameter = effective, Candidates = #result}
    end
    -- Keep native Model semantics and remove duplicate/departed/dead candidates.
    -- A scoped assist may then add only the manually selected C target.
    local filtered, seen = {}, {}
    for _, target in ipairs(result) do
        if typeof(target) == "Instance" and target:IsA("Model") and target ~= character
            and target.Parent and not seen[target] then
            local hum = getHumanoid(target)
            if hum and hum.Health > 0 then table.insert(filtered, target); seen[target] = true end
        end
    end
    result = filtered
    if Autos.ExtendedHitbox then
        local target, root, ownRoot = Combat:LockedWithin(80)
        local radius = effective / 2
        if target and not table.find(result, target)
            and (root.Position - (ownRoot.CFrame * offset).Position).Magnitude <= math.min(radius * Options.HitboxScale, radius + 12)
            and Combat:ClearLine(target, root.Position) then
            table.insert(result, target)
            Combat.Stats.HitboxCandidates += 1
        end
    end
    result = Combat.SkillAssist:AdjustSphere(character, result)
    self.Candidates += #result
    if self.LastQuery then self.LastQuery.Candidates = #result end
    values[2] = result
    return table.unpack(values, 2, values.n)
end

function Combat.Hitboxes:Reset()
    -- No movement window: shared hit reports remain Model lists.
end

function Combat.Hitboxes:Destroy()
    self:Reset()
    self.Overlap, self.Folder, self.LastQuery = nil, nil, nil
end

-- Skill assist profiles are tied to the supplied JJS client, not wiki guesses
-- about remotes. Wiki descriptions identify move names and stages:
--   Switcher: Swift Kick; Salaryman: Interrogate; Honored One: 0.2 Domain;
--   Star Rage: Unrestricted Density (death awakening).
-- SwiftKick throws report a six-byte camera direction buffer, NOT a victim.
-- GojoController proto17 alone reports (targetModel, attackerCFrame) through
-- GojoService.Hitbox's temporary remote. Other assisted hits retain the game's
-- existing SphereHitbox reporter and cadence. None of these counters prove damage.
Combat.SkillAssist = {
    Attached = setmetatable({}, {__mode = "k"}),
    Window = nil, GojoJobs = {}, GojoSeen = setmetatable({}, {__mode = "k"}),
    AnimationSeen = setmetatable({}, {__mode = "k"}), NextGojo = 0, Status = "Waiting for C target",
    Stats = {Windows = 0, Selections = 0, GojoReports = 0, RearOriginReports = 0, LatchPlacements = 0, LatchConfirms = 0},
    Profiles = {
        FrontDash = {Feature = "AssistFrontDash", Label = "Front dash", Duration = 1.25},
        Decisive = {Feature = "AssistDecisive", Label = "Decisive Strike", Moveset = "Naoya", Duration = 1.4},
        Todo = {Feature = "AssistTodo", Label = "Swift Kick grab", Moveset = "Todo", Duration = 2},
        Nanami = {Feature = "AssistNanami", Label = "Interrogate", Moveset = "Nanami", Duration = 1.5},
        Yuki = {Feature = "AssistYuki", Label = "Black Hole latch", Moveset = "Yuki", Duration = 0.5, AllowDead = true},
        Gojo = {Feature = "AssistGojo", Label = "0.2 Domain hits", Moveset = "Gojo", Duration = 1.5},
    },
}

function Combat.SkillAssist:ValidOwn(record)
    local char = record.Character
    local profile = self.Profiles[record.Kind]
    if not Alive or not Autos.SkillAssist or not profile or not Autos[profile.Feature]
        or char ~= LocalPlayer.Character or record.Generation ~= characterGeneration
        or not char or not char.Parent or Combat:IsTyping() or movementState ~= "IDLE"
        or (profile.Moveset and char:GetAttribute("Moveset") ~= profile.Moveset)
        or os.clock() > record.Expires then return false end
    local hum = getHumanoid(char)
    if not hum or not getRoot(char) or (hum.Health <= 0 and not profile.AllowDead) then return false end
    if not profile.AllowDead and (Combat:HasState(char, "Stun") or Combat:HasState(char, "Ragdoll")) then return false end
    if record.Kind ~= "Yuki" and record.Kind ~= "Gojo" and record.Kind ~= "Nanami" then
        local info = char:FindFirstChild("Info")
        local marker = info and info:FindFirstChild("InSkill")
        if marker then record.SawSkillState = true
        elseif record.SawSkillState then return false end
    end
    return true
end

function Combat.SkillAssist:Target(record)
    if not self:ValidOwn(record) or not isActive or lockedTarget ~= record.Target
        or not record.Target or not record.Target.Parent then return end
    local root, ownRoot, hum = getRoot(record.Target), getRoot(record.Character), getHumanoid(record.Target)
    if not root or not ownRoot or not hum or hum.Health <= 0
        or (root.Position - ownRoot.Position).Magnitude > Options.SkillAssistRange then return end
    if record.NativeSession then
        local session = record.NativeSession
        if not session.Remote.Parent or (session.Gate and not session.Gate.Parent) then return end
    elseif record.Track and record.Kind ~= "Nanami" and record.Track.IsPlaying ~= true then return end
    return record.Target, root, ownRoot
end

function Combat.SkillAssist:Arm(kind, character, track, phase)
    local profile = self.Profiles[kind]
    if not profile or character ~= LocalPlayer.Character then return end
    local record = {Kind = kind, Character = character, Generation = characterGeneration,
        Target = lockedTarget, Track = track, Expires = os.clock() + profile.Duration,
        Next = 0, Placements = 0, Phase = phase or "Animation"}
    if not self:Target(record) then return end
    -- Start/animation notifications for the same launch must not reset its
    -- expiry or restore attempts while the native window is already running.
    local current = self.Window
    if current and current.Kind == kind and current.Character == character and self:Target(current)
        and not (track and current.Track and current.Track ~= track)
        and not (phase == "Dash" and current.Phase ~= "Dash") then
        if phase and kind == "Nanami" then current.Track = nil
        elseif not current.Track and track then current.Track = track end
        if phase then current.Phase = phase end
        return current
    end
    self.Window = record
    self.Stats.Windows += 1
    self.Status = profile.Label .. " ready"
    return record
end

function Combat.SkillAssist:OnAnimation(track, id)
    if self.AnimationSeen[track] then return end
    local char = LocalPlayer.Character
    local moveset = char and char:GetAttribute("Moveset")
    local chase = Combat.Hitboxes.ChaseIds[id]
    local kind = chase and chase[moveset] and "FrontDash"
        or (id == "rbxassetid://86045680364061" and moveset == "Naoya" and "Decisive")
        or (id == "rbxassetid://84737448668938" and moveset == "Todo" and "Todo")
        or (id == "rbxassetid://89891294371787" and moveset == "Nanami" and "Nanami")
    if kind and self:Arm(kind, char, track) then self.AnimationSeen[track] = true end
end

function Combat.SkillAssist:OnEffects(service, effect, owner, ...)
    if service == "SwiftKickService" and owner == LocalPlayer.Character then
        if effect == "Start" then self:Arm("Todo", owner) end
    elseif service == "InterrogateService" and owner == LocalPlayer.Character then
        self.Stats.NanamiEvents = (self.Stats.NanamiEvents or 0) + 1
        if effect == "Start" or effect == "Dash" then self:Arm("Nanami", owner, nil, effect)
        elseif effect == "Hit" or effect == "FinalSwing" then
            if self.Window and self.Window.Kind == "Nanami" then self.Window = nil; self.Status = "Interrogate contact / final phase observed" end
        end
    elseif service == "YukiService" then
        if effect == "BlackHole" and (owner == LocalPlayer.Character or owner == getRoot(LocalPlayer.Character)) then
            if self.Window and self.Window.Kind == "Yuki" then self.Window = nil end
            return
        end
        if owner ~= LocalPlayer.Character then return end
        if effect == "OhNo" then
            -- YukiController OhNo proto12 starts the native camera-led 0.5s launch.
            -- Launch proto5 is a general visual effect and must not arm this job.
            self:Arm("Yuki", owner)
        elseif effect == "OhNo2" then
            local target = ...
            local window = self.Window
            if window and window.Kind == "Yuki" and window.Character == owner
                and target == window.Target and self:Target(window) then
                self.Stats.LatchConfirms += 1
                self.Status = "Black Hole latched"
                self.Window = nil
            end
        elseif effect == "BlackHole" then
            if self.Window and self.Window.Kind == "Yuki" then self.Window = nil end
        end
    end
end

function Combat.SkillAssist:GojoEligible(target)
    local info = target and target:FindFirstChild("Info")
    -- The original selector skips targets with an active Knockback marker.
    -- Extra-hit assist intentionally keeps its selected target for the bounded
    -- repeat window. The server still decides whether each report is accepted.
    return info ~= nil
end

function Combat.SkillAssist:OnGojoHitbox(attack, character, remote)
    if typeof(attack) ~= "Instance" or not attack.Parent or character ~= LocalPlayer.Character
        or typeof(remote) ~= "Instance" or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) or not remote.Parent
        or self.GojoSeen[remote] then return end
    local profile = self.Profiles.Gojo
    local job = {Kind = "Gojo", Character = character, Generation = characterGeneration,
        Target = lockedTarget, Expires = os.clock() + profile.Duration,
        Attack = attack, Remote = remote, Reports = 0, Next = 0}
    if not self:Target(job) or not self:GojoEligible(job.Target) then return end
    self.GojoSeen[remote] = true
    self.GojoJobs[remote] = job
    self.Stats.Windows += 1
    self.Status = "0.2 Domain hit window"
end

function Combat.SkillAssist:AdjustSphere(character, result)
    local window = self.Window
    if not window or character ~= window.Character or type(result) ~= "table" then return result end
    local target = self:Target(window)
    if not target then self.Window = nil; return result end
    self.Stats.NativeQueries = (self.Stats.NativeQueries or 0) + 1
    self.LastQuery = {Kind = window.Kind, At = os.clock()}
    if table.find(result, target) then return result end
    local copy = table.clone(result)
    table.insert(copy, target)
    self.Stats.Selections += 1
    self.Status = self.Profiles[window.Kind].Label .. " targeting " .. target.Name
    return copy
end

function Combat.SkillAssist:HasWindow(character)
    local window = self.Window
    return window and window.Character == character and self:Target(window) ~= nil
end

-- Only GojoController proto17 exposes an attacker CFrame in a hit report.
-- Construct its reported origin behind the victim, looking toward the victim.
-- This never writes either character or camera. Shared Model-list reports have
-- no origin slot and are intentionally left alone; acceptance is server-owned.
function Combat.SkillAssist:RearReportFrame(targetRoot, distance)
    local position, look = targetRoot.Position, targetRoot.CFrame.LookVector
    if not Combat.Hitboxes:ValidVector(position) or not Combat.Hitboxes:ValidVector(look) then return end
    local forward = Vector3.new(look.X, 0, look.Z)
    if forward.Magnitude < 0.05 then return end
    local origin = position - forward.Unit * distance
    if not Combat.Hitboxes:ValidVector(origin) then return end
    return CFrame.lookAt(origin, position)
end

function Combat.SkillAssist:GojoReportFrame(targetRoot, ownRoot)
    if not Autos.GojoRearOrigin then return ownRoot.CFrame, false end
    local frame = self:RearReportFrame(targetRoot, Options.RearOriginOffset)
    return frame or ownRoot.CFrame, frame ~= nil
end

function Combat.SkillAssist:Step()
    local now = os.clock()
    local window = self.Window
    if window then
        local target, root, ownRoot = self:Target(window)
        if not target then self.Window = nil
        elseif not self.PhysicsLatch then self:StepLatch()
        end
    end
    for remote, job in pairs(self.GojoJobs) do
        local target, _, ownRoot = self:Target(job)
        if not target or not remote.Parent or not job.Attack.Parent or not self:GojoEligible(target)
            or job.Reports >= Options.GojoHitReports then self.GojoJobs[remote] = nil; continue end
        if now < job.Next or now < self.NextGojo then continue end
        job.Next, self.NextGojo = now + Options.GojoHitInterval, now + Options.GojoHitInterval
        local count = Autos.GojoHitBurst and (Options.GojoHitReports - job.Reports) or 1
        for _ = 1, count do
            local currentTarget, targetRoot, currentRoot = self:Target(job)
            if not currentTarget or not remote.Parent or not job.Attack.Parent then break end
            local frame, rear = self:GojoReportFrame(targetRoot, currentRoot)
            local ok = Runtime:Run("Gojo variant skill assist", function()
                -- Exact (targetModel, attackerCFrame) contract. Only this supplied
                -- frame changes; physical roots and camera remain untouched.
                remote:FireServer(currentTarget, frame)
            end)
            if not ok then self.GojoJobs[remote] = nil; break end
            job.Reports += 1
            self.Stats.GojoReports += 1
            if rear then self.Stats.RearOriginReports += 1 end
            self.LastGojoReport = {Target = currentTarget, Frame = frame, RearOrigin = rear, At = now}
        end
        self.Status = "0.2 Domain reports " .. job.Reports .. "/" .. Options.GojoHitReports
    end
end

function Combat.SkillAssist:OnNativeHitSession(character, offset, diameter, reporter, gate)
    local window = self.Window
    if not window or character ~= LocalPlayer.Character or character ~= window.Character
        or typeof(offset) ~= "CFrame" or not finiteNumber(diameter) or diameter <= 0
        or typeof(reporter) ~= "Instance" or not (reporter:IsA("RemoteEvent") or reporter:IsA("UnreliableRemoteEvent"))
        or not reporter.Parent or (gate ~= nil and (typeof(gate) ~= "Instance" or not gate.Parent)) then return end
    if not self:Target(window) or (window.NativeSession and window.NativeSession.Remote == reporter) then return end
    window.NativeSession = {Remote = reporter, Gate = gate}
    window.Phase, window.Track = "Native hit session", nil
    self.Stats.NativeSessions = (self.Stats.NativeSessions or 0) + 1
    self.LastNativeSession = {Kind = window.Kind, At = os.clock(), Diameter = diameter}
    self.Status = self.Profiles[window.Kind].Label .. " · native hit session observed"
end

function Combat.SkillAssist:StepLatch()
    local window = self.Window
    if not window or window.Kind ~= "Yuki" then return end
    local target, root, ownRoot = self:Target(window)
    if not target then self.Window = nil; return end
    local now = os.clock()
    -- Native OhNo reassigns launch velocity after each wait. Hold contact through
    -- the physics sample, without adding placements after the configured budget.
    if (ownRoot.Position - root.Position).Magnitude <= 6 then ownRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
    if now < window.Next or window.Placements >= Options.YukiLatchAttempts then return end
    window.Next, window.Placements = now + 0.05, window.Placements + 1
    ownRoot.CFrame = CFrame.lookAt(root.Position, root.Position + ownRoot.CFrame.LookVector)
    ownRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    self.Stats.LatchPlacements += 1
    self.Status = "Black Hole latch attempt " .. window.Placements
end

function Combat.SkillAssist:Attach(remote)
    if typeof(remote) ~= "Instance" or self.Attached[remote]
        or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then return end
    if remote == JJS:GetRemote("HitboxService", "Hitbox") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "native skill hit session", function(...)
            if Alive then self:OnNativeHitSession(...) end
        end))
        return
    end
    if remote == JJS:GetRemote("GojoService", "Hitbox") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "Gojo variant hit session", function(...)
            if Alive then self:OnGojoHitbox(...) end
        end))
        return
    end
    for _, service in ipairs({"SwiftKickService", "InterrogateService", "YukiService"}) do
        if remote == JJS:GetRemote(service, "Effects") then
            self.Attached[remote] = true
            track(connect(remote.OnClientEvent, service .. " skill assist", function(...)
                if Alive then self:OnEffects(service, ...) end
            end))
            return
        end
    end
end

function Combat.SkillAssist:Configure()
    if self.Window and not self:Target(self.Window) then self.Window = nil end
    for remote, job in pairs(self.GojoJobs) do if not self:Target(job) then self.GojoJobs[remote] = nil end end
    if not Autos.SkillAssist then self.Status = "Off"
    elseif not self.Window and next(self.GojoJobs) == nil then self.Status = "Waiting for skill" end
end

function Combat.SkillAssist:StatusText()
    if not Alive then return "Unloaded" end
    if not Autos.SkillAssist then return "Off" end
    if not isActive or not lockedTarget then return "Waiting for C target" end
    if self.Window or next(self.GojoJobs) ~= nil then return self.Status end
    return "Ready · last: " .. self.Status
end

function Combat.SkillAssist:Reset()
    self.Window = nil
    table.clear(self.GojoJobs)
    self.Status = Autos.SkillAssist and "Waiting for skill" or "Off"
end

function Combat.SkillAssist:Destroy()
    self:Reset()
    table.clear(self.GojoSeen)
    table.clear(self.AnimationSeen)
    self.LastGojoReport = nil
    self.Status = "Unloaded"
end

-- Static source: HitboxController proto0 receives a temporary remote from
-- ReplicatedStorage.Remotes.GetClient, then reports CurrentCamera.CFrame.
-- This is a separate route from proto2's Model-only shared hit list.
-- Its use by a dash block-direction check is NOT established by the dump.
-- We replace only that verified listener, preserve other listeners, never send
-- duplicate replies, and expose requests/rewrites for an actual in-game check.
-- Connection controls: https://docs.sunc.io/Signals/Connection/
Combat.ClientOrigin = {
    Status = "Waiting for GetClient", Requests = 0, DashRequests = 0, Rewrites = 0,
    Failures = 0, HitSessions = 0, Recent = {}, NextAttach = 0,
}

function Combat.ClientOrigin:Window()
    local assist, window = Combat.SkillAssist, Combat.SkillAssist.Window
    if not window or (window.Kind ~= "FrontDash" and window.Kind ~= "Decisive") then return end
    local target, targetRoot, ownRoot = assist:Target(window)
    if target then return window, target, targetRoot, ownRoot end
end

function Combat.ClientOrigin:Remember(record)
    table.insert(self.Recent, record)
    if #self.Recent > 8 then table.remove(self.Recent, 1) end
    self.Last = record
end

function Combat.ClientOrigin:Reply(original, ...)
    local remote = ...
    if not Alive or not Autos.DashClientOrigin or self.RestorePending or select("#", ...) ~= 1
        or typeof(remote) ~= "Instance" or not remote.Parent
        or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then return original(...) end
    local window, target, root, ownRoot = self:Window()
    if not window then return original(...) end
    local frame = Combat.SkillAssist:RearReportFrame(root, Options.RearOriginOffset)
    if not frame then return original(...) end
    local record = {At = os.clock(), Kind = window.Kind, Target = target, Frame = frame,
        OwnFrame = ownRoot.CFrame, Accepted = "unknown"}
    -- One existing server request receives one CFrame. No invented extra hit
    -- arguments, global __index spoof, physical relocation or camera relocation.
    local ok, err = pcall(remote.FireServer, remote, frame)
    if ok then
        self.Rewrites += 1
        record.Sent = true
    else
        self.Failures += 1
        record.Sent, record.Error = false, tostring(err)
    end
    self:Remember(record)
    -- An uncertain send is not retried with a second reply.
end

function Combat.ClientOrigin:Restore()
    if self.Native then
        local ok, err = pcall(function() self.Native:Enable() end)
        if not ok then
            -- Keep a delegating replacement until native re-enable succeeds.
            -- Disconnecting first would leave the game without any responder.
            self.RestorePending = true
            self.Status = "Restore pending: " .. tostring(err)
            return false
        end
        self.Native = nil
    end
    if self.Handler then self.Handler:Disconnect(); self.Handler = nil end
    self.RestorePending = nil
    return true
end

function Combat.ClientOrigin:TryAttach()
    if not Alive then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local remote = remotes and remotes:FindFirstChild("GetClient")
    if self.Remote ~= remote then
        if not self:Restore() then return end
        if self.Observer then self.Observer:Disconnect(); self.Observer = nil end
        self.Remote = remote
    end
    if not remote or not remote:IsA("RemoteEvent") then self.Status = "GetClient unavailable"; return end
    if not self.Observer then
        self.Observer = connect(remote.OnClientEvent, "observe client position request", function()
            if not Alive then return end
            self.Requests += 1
            if self:Window() then self.DashRequests += 1 end
        end)
    end
    if not Autos.DashClientOrigin then
        if self:Restore() then self.Status = "Off (observing requests)" end
        return
    end
    if self.RestorePending and not self:Restore() then return end
    if self.Handler then return end
    local connections = getGlobalFunction("getconnections")
    local constants = debug and debug.getconstants
    if type(connections) ~= "function" or type(constants) ~= "function" then
        self.Status = "Needs getconnections + debug.getconstants"; return
    end
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local controllers = scripts and scripts:FindFirstChild("Controllers")
    local combat = controllers and controllers:FindFirstChild("Combat")
    local source = combat and combat:FindFirstChild("HitboxController")
    if not source then self.Status = "Native HitboxController script unavailable"; return end
    local ok, list = pcall(connections, remote.OnClientEvent)
    if not ok or type(list) ~= "table" then self.Status = "Cannot inspect GetClient listener"; return end
    local matches = {}
    for _, connection in ipairs(list) do
        pcall(function()
            local callback = connection.Function
            if connection.Enabled ~= true or connection.ForeignState == true or type(callback) ~= "function"
                or type(connection.Disable) ~= "function" or type(connection.Enable) ~= "function" then return end
            local env = getfenv(callback)
            if type(env) ~= "table" or env.script ~= source then return end
            local keys = {}
            for _, value in pairs(constants(callback)) do if type(value) == "string" then keys[value] = true end end
            if not (keys.workspace and keys.CurrentCamera and keys.CFrame and keys.Parent and keys.FireServer) then return end
            -- The supplied callback has one non-vararg parameter and no upvalues.
            local parameters, vararg = debug.info(callback, "a")
            if parameters ~= 1 or vararg then return end
            table.insert(matches, {Connection = connection, Callback = callback})
        end)
    end
    if #matches ~= 1 then
        self.Status = #matches == 0 and "Native reply not identified" or "Ambiguous native replies"
        return
    end
    local native, callback = matches[1].Connection, matches[1].Callback
    local handler
    ok = pcall(function()
        handler = connect(remote.OnClientEvent, "client position reply", function(...) return self:Reply(callback, ...) end)
        native:Disable()
        assert(native.Enabled == false, "native listener did not disable")
    end)
    if not ok then
        if native.Enabled == false then
            self.Native, self.Handler = native, handler
            if not self:Restore() then return end
        elseif handler then handler:Disconnect() end
        self.Status = "Native reply replacement unavailable"; return
    end
    self.Native, self.Handler = native, handler
    self.Status = "Attached; server use unverified"
end

function Combat.ClientOrigin:AttachHitSessions(remote)
    if remote ~= JJS:GetRemote("HitboxService", "Hitbox") then return end
    if self.HitRemote == remote and self.HitObserver then return end
    if self.HitObserver then self.HitObserver:Disconnect() end
    self.HitRemote = remote
    self.HitObserver = connect(remote.OnClientEvent, "observe own hit session", function(character, offset, diameter, reporter)
        local window = self:Window()
        if not Alive or not window or character ~= LocalPlayer.Character or typeof(offset) ~= "CFrame"
            or not finiteNumber(diameter) or typeof(reporter) ~= "Instance" then return end
        self.HitSessions += 1
        self.LastHit = {At = os.clock(), Kind = window.Kind, Diameter = diameter, Report = "Model list"}
    end)
end

function Combat.ClientOrigin:StatusText()
    return self.Status .. " · dash requests " .. self.DashRequests .. " / changed " .. self.Rewrites
end

function Combat.ClientOrigin:Destroy()
    self:Restore()
    if self.Observer then self.Observer:Disconnect(); self.Observer = nil end
    if self.HitObserver then self.HitObserver:Disconnect(); self.HitObserver = nil end
    self.Status, self.Remote, self.HitRemote = "Unloaded", nil, nil
end

function Combat:AttachRemote(remote)
    self:AttachRosterRemote(remote)
    self.ClientOrigin:AttachHitSessions(remote)
    self.SkillAssist:Attach(remote)
    if typeof(remote) ~= "Instance" or self.Attached[remote]
        or not (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then return end
    if remote == JJS:GetRemote("BlockService", "Effects") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "native block confirmation", function(...)
            if Alive then self:OnGuardEffect(...) end
        end))
    elseif remote == JJS:GetRemote("YukiService", "Effects") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "native Yuki charge / mass meter", function(effect, ...)
            if Alive then self:OnYukiEffect(effect, ...) end
        end))
    elseif remote == JJS:GetRemote("FinalJudgementService", "Effects") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "Hiromi QTE session", function(effect, ...)
            if Alive and effect == "QTE" then self:OnMinigameQTE(...) end
        end))
    elseif remote == JJS:GetRemote("GarudaReboundService", "Effects") then
        self.Attached[remote] = true
        track(connect(remote.OnClientEvent, "Garuda return window", function(effect, ...)
            if Alive and effect == "Recall" then self:OnGarudaRecall(...) end
        end))
    elseif remote == JJS:GetRemote("BeamService", "Effects") then
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
    self:ResetBlackFlash()
    self:ResetTodoBlackFlash()
    self:ResetTracking("Character reset")
    self:ResetLocalInvisible()
    self.CursedSteer, self.LastTodoPerfectAt = nil, nil
    self.ManualAttackHeld, self.OffenseUntil, self.CameraResumeAt = false, 0, 0
    self.SkillAssist:Reset()
    self.Hitboxes:Reset()
    self:ResetSuiteCharacter()
    table.clear(self.AirContexts)
    self:ResetDefence()
    self:CancelYukiCharge()
    self.YukiIntercepted, self.Garuda, self.YukiMass = nil, nil, nil
    self:ClearRatio("Character reset")
    self.NextYukiCharge, self.NextPunish, self.DefencePauseUntil = 0, 0, 0
    table.clear(self.GarudaSeen)
    table.clear(self.Sounds)
    self.Beam, self.FollowUp, self.Threat = nil, nil, nil
    table.clear(self.Actions)
    self:DisconnectList(self.TargetConnections)
    self.WatchedTarget, self.TargetAnimator = nil, nil
end

function Combat:Destroy()
    for _, connection in pairs(self.PendingAnimationIds) do connection:Disconnect() end
    table.clear(self.PendingAnimationIds)
    if (Autos.AutoSave or self.SaveForced) and self.ConfigDirty then saveConfig() end
    self.Cosmetics:Destroy()
    self:ResetLocalInvisible()
    self:DestroyConveniences()
    self.ClientOrigin:Destroy()
    self.Hitboxes:Destroy()
    self.SkillAssist:Destroy()
    self:ResetCharacter()
    self:RestorePatches()
    self:DisconnectList(self.UIConnections)
    self:DisconnectList(self.EffectConnections)
    table.clear(self.Projectiles)
    self.EffectsFolder = nil
    table.clear(self.MouseContexts)
    table.clear(self.FailedAirSignals)
    self.Tool, self.Hitbox, self.Movement = nil, nil, nil
    self.Panel, self.PanelStatus, self.TargetLabel, self.SkillLabel, self.OriginLabel = nil, nil, nil, nil, nil
    self.Buttons, self.OptionLabels, self.ModeButtons, self.DefenceLabel = {}, {}, {}, nil
end

function Combat:SetOption(name, value)
    local bounds = {
        CosmeticSlot = {1, 16}, RatioTimingOffset = {-150, 150}, AimLead = {0, 0.25}, AimResponsiveness = {16, 240}, CameraAimStrength = {.1, 1}, CharacterResponsiveness = {32, 360},
        SmoothTurnSpeed = {360, 3600}, AimHorizontalOffset = {0, 4},
        HitboxScale = {1, 3}, HitboxSize = {1, 40},
        RearOriginOffset = {1, 6}, SkillAssistRange = {4, 200},
        GojoHitReports = {1, 20}, GojoHitInterval = {0.025, 0.25}, YukiLatchAttempts = {1, 10}, BlockRange = {4, 30}, PunishRange = {4, 11},
        BlockHold = {0.15, 0.7}, BeamInterval = {0.08, 0.5}, QTEInterval = {0.05, 0.5},
        FollowUpSlot = {1, 4}, FollowUpRange = {4, 30},
    }
    local limit = bounds[name]
    if not limit or not finiteNumber(value) then return false end
    value = math.clamp(value, limit[1], limit[2])
    if name == "CosmeticSlot" or name == "FollowUpSlot" or name == "GojoHitReports" or name == "YukiLatchAttempts" then value = math.floor(value + 0.5) end
    local changed = Options[name] ~= value
    Options[name] = value
    if changed then self:MarkSettingsDirty() end
    self:RefreshPanel()
    return true
end

function Combat:SetFeature(name, enabled)
    name = Combat.FeatureAliases[name] or name
    if name == "SilentAim" then name = "MouseAssist" end
    if Autos[name] == nil then return false, "unknown feature" end
    local changed = Autos[name] ~= (enabled == true)
    Autos[name] = enabled == true
    if name == "AutoBlock" and not Autos.AutoBlock then self:ReleaseBlock() end
    if name == "AutoRatio" and not Autos.AutoRatio then self:ClearRatio("Auto Ratio off") end
    if name == "AutoRatioChain" and not Autos.AutoRatioChain then self.RatioChain = nil end
    if name == "AutoBurst" and not Autos.AutoBurst then self.NextBurst = 0 end
    if name == "AutoPunish" and not Autos.AutoPunish then self.Punish, self.PendingBlockHit = nil, nil end
    if name == "AutoGarudaRebound" and not Autos.AutoGarudaRebound then self.Garuda = nil end
    if name == "YukiInstantCharge" and not Autos.YukiInstantCharge then
        self:CancelYukiCharge()
        self.YukiIntercepted = nil
    end
    if name == "AutoWorldSlash" and not Autos.AutoWorldSlash then self.WorldSlashJob = nil end
    if name == "AutoShutUp" and not Autos.AutoShutUp then self:EndShutUp() end
    if name == "AutoAdapt" and not Autos.AutoAdapt then table.clear(self.AdaptJobs) end
    if name == "AutoAirVariants" and not Autos.AutoAirVariants then
        self.AirEpoch += 1
        table.clear(self.AirContexts)
    end
    if name == "CameraTracking" and not Autos.CameraTracking then self:ResetTracking("Tracking disabled") end
    if name == "SmoothAim" or name == "VerticalAim" then self.AimHistory = nil end
    if name == "BlackFlash" and not Autos.BlackFlash then self:ResetBlackFlash() end
    if name == "AutoTodoBlackFlash" and not Autos.AutoTodoBlackFlash then self:ResetTodoBlackFlash() end
    if name == "InvisibleLocal" then self:ApplyLocalInvisible() end
    if name == "CursedStrikeSteer" and not Autos.CursedStrikeSteer then self.CursedSteer = nil end
    if name == "CosmeticCatalog" and not Autos.CosmeticCatalog then self.Cosmetics:ClearRows() end
    if name == "UnlockEmotePages" and not Autos.UnlockEmotePages then self.Cosmetics:RestorePages() end
    if name == "ExtraEmoteSlots" then self:RefreshEmoteSlots() end
    if name == "DashClientOrigin" then self.ClientOrigin:TryAttach() end
    if name == "SkillAssist" or string.sub(name, 1, 6) == "Assist" then self.SkillAssist:Configure() end
    if changed then self:MarkSettingsDirty(name == "AutoSave") end
    if name == "DefenceLockedOnly" then self:ResetDefence() end
    self.NextWatch = 0
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
    self:BuildModeControls(panel, new, {BackgroundColor3 = Color3.fromRGB(43, 49, 61),
        TextColor3 = Color3.fromRGB(240, 242, 247), BorderSizePixel = 0,
        Font = Enum.Font.SourceSansBold, TextSize = 15})
    local list = new("ScrollingFrame", {Size = UDim2.new(1, -20, 1, -130),
        Position = UDim2.new(0, 10, 0, 76), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 620), ScrollBarThickness = 4, Parent = panel})
    local rows = {
        {"CursedStrikeSteer", "Aim Cursed Strikes with camera"},
        {"AutoTodoPerfect", "Todo: Perfect Swap input"},
        {"CosmeticCatalog", "Show all cosmetic selections"},
        {"UnlockEmotePages", "Show emote pages and search"},
        {"InvisibleLocal", "Invisible: local view only"},
        {"SkillAssist", "Skill assist (C target)"},
        {"AssistFrontDash", "Assist: front dash"}, {"AssistDecisive", "Assist: Decisive Strike"},
        {"AssistTodo", "Assist: Todo Swift Kick grab"}, {"AssistGojo", "Assist: Gojo 0.2 Domain hits"},
        {"GojoHitBurst", "Gojo: burst extra hit attempts"},
        {"AssistYuki", "Assist: Yuki Black Hole latch"}, {"AssistNanami", "Assist: Nanami Interrogate"},
        {"AutoBurst", "Auto anti-team Burst"}, {"AutoQTE", "Auto QTE minigame"},
        {"AutoAdapt", "Auto adapt (nearby Void)"}, {"AutoWorldSlash", "Auto World Slash"},
        {"AutoShutUp", "Auto Shut Up turn"}, {"AutoAirVariants", "Auto / forced air variants"},
        {"AutoSpawnTrain", "Auto spawn train"}, {"InstantPrompts", "Instant prompts (IYR)"},
        {"ExtraEmoteSlots", "Extra emote slots"}, {"AutoSave", "Autosave settings"},
        {"BlackFlash", "Yuji / Mahito: Black Flash"}, {"AutoTodoBlackFlash", "Todo: Black Flash (TBO)"},
        {"AutoGarudaRebound", "Auto Garuda Rebound"}, {"YukiInstantCharge", "Yuki R: TBO charge pulses"},
        {"AutoRatio", "Nanami: Auto Ratio (C target)"}, {"AutoRatioChain", "Nanami: chain Ratio on C target"}, {"AutoBeam", "Beam-clash responses"},
        {"PredictiveAim", "Predictive camera aim"}, {"MouseAssist", "Mouse assist (skills / targets)"},
        {"ChaseAssist", "Chase assist (multi-dash target)"},
        {"CameraTracking", "Camera and Hybrid tracking"}, {"SmoothAim", "Smooth camera and Hybrid"},
        {"VerticalAim", "Track target height (V)"},
        {"HybridFacingWhileMoving", "Hybrid facing while moving"},
        {"TodoSmart", "Todo special uses locked target"}, {"AutoBlock", "Auto block nearby attacks"},
        {"GuardAutoFace", "Turn toward threats while blocking"},
        {"AutoPunish", "Auto punish after BlockHit"}, {"DefenceLockedOnly", "Defend only against C target"},
        {"BlockProjectiles", "TBO projectile / Totality block"},
        {"FollowUp", "Hit-confirm skill follow-up"}, {"TargetInfo", "Target state display"},
        {"TBOHitbox", "TBO hitbox size"},
        {"GojoRearOrigin", "Gojo: rear-origin report attempt"},
        {"DashClientOrigin", "Dash / Decisive: client-origin attempt"},
        {"ExtendedHitbox", "Locked target reach multiplier"},
    }
    local extraRowHeight = 0
    for index, row in ipairs(rows) do
        local key = row[1]
        local rowY = (index - 1) * 32 + extraRowHeight
        local button = new("TextButton", {Name = key, Size = UDim2.new(1, -4, 0, 29),
            Position = UDim2.new(0, 2, 0, rowY), BorderSizePixel = 0,
            Font = Enum.Font.SourceSans, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            Parent = list})
        self.Buttons[key] = {Object = button, Label = row[2]}
        table.insert(self.UIConnections, connect(button.Activated, "feature toggle", function()
            self:SetFeature(key, not Autos[key])
        end))
        if key == "AutoPunish" then
            self.DefenceLabel = new("TextLabel", {Name = "DefenceStatus", Size = UDim2.new(1, -8, 0, 42),
                Position = UDim2.new(0, 4, 0, rowY + 31), BackgroundTransparency = 1, TextWrapped = true,
                TextColor3 = Color3.fromRGB(220, 226, 237), Font = Enum.Font.SourceSans, TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = list})
            extraRowHeight += 48
        end
    end
    local optionsStart = #rows * 32 + extraRowHeight + 12
    local options = {
        {"AimLead", "Aim lead (seconds)", 0.01, "%.2f"},
        {"AimResponsiveness", "Camera aim response", 12, "%.0f"},
        {"CameraAimStrength", "Camera pull strength", .05, "%.2f"},
        {"CharacterResponsiveness", "Hybrid turn response", 12, "%.0f"},
        {"SmoothTurnSpeed", "Smooth turn limit (degrees/sec)", 120, "%.0f"},
        {"AimHorizontalOffset", "Aim sideways offset", 0.25, "%.2f"},
        {"HitboxSize", "Hitbox minimum diameter", 1, "%.0f"},
        {"SkillAssistRange", "Skill assist range", 5, "%.0f"},
        {"GojoHitReports", "Gojo reports per hit window", 1, "%.0f"},
        {"GojoHitInterval", "Gojo interval (burst off)", 0.025, "%.3f"},
        {"YukiLatchAttempts", "Yuki latch attempts", 1, "%.0f"},
        {"RatioTimingOffset", "Nanami timing offset (ms)", 5, "%.0f"},
        {"CosmeticSlot", "Catalog emote equip slot", 1, "%.0f"},
        {"HitboxScale", "Locked reach multiplier", 0.25, "%.2fx"},
        {"RearOriginOffset", "Gojo reported rear distance", 0.5, "%.1f"},
        {"BlockRange", "Block range (studs)", 1, "%.0f"},
        {"PunishRange", "Punish range", 1, "%.0f"},
        {"QTEInterval", "QTE interval", 0.01, "%.2f"},
        {"FollowUpSlot", "Follow-up skill slot", 1, "%.0f"},
        {"BeamInterval", "Clash interval (seconds)", 0.02, "%.2f"},
    }
    for index, row in ipairs(options) do
        local y, key = optionsStart + (index - 1) * 34, row[1]
        local label = new("TextLabel", {Size = UDim2.new(1, -72, 0, 30), Position = UDim2.new(0, 4, 0, y),
            BackgroundTransparency = 1, Font = Enum.Font.SourceSans, TextSize = 15, TextWrapped = true,
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
    local actionStart = optionsStart + #options * 34 + 222
    self.CharacterActionsLabel = new("TextLabel", {Name = "CharacterActionStatus", Size = UDim2.new(1, -8, 0, 126),
        Position = UDim2.new(0, 4, 0, actionStart - 218), BackgroundTransparency = 1, TextWrapped = true,
        TextColor3 = Color3.fromRGB(180, 211, 235), Font = Enum.Font.SourceSans, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = list})
    self.OriginLabel = new("TextLabel", {Name = "ClientOriginStatus", Size = UDim2.new(1, -8, 0, 42),
        Position = UDim2.new(0, 4, 0, actionStart - 88), BackgroundTransparency = 1, TextWrapped = true,
        TextColor3 = Color3.fromRGB(255, 187, 115), Font = Enum.Font.SourceSans, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = list})
    self.SkillLabel = new("TextLabel", {Name = "SkillAssistStatus", Size = UDim2.new(1, -8, 0, 38),
        Position = UDim2.new(0, 4, 0, actionStart - 44), BackgroundTransparency = 1, TextWrapped = true,
        TextColor3 = Color3.fromRGB(160, 210, 195), Font = Enum.Font.SourceSans, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = list})
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
    self.SaveButton = saveButton
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
    self:RefreshModeControls()
    for key, row in pairs(self.Buttons or {}) do
        row.Object.Text = "  " .. (Autos[key] and "ON   " or "OFF  ") .. row.Label
        row.Object.BackgroundColor3 = Autos[key] and Color3.fromRGB(31, 66, 60) or Color3.fromRGB(36, 41, 51)
        row.Object.TextColor3 = (key == "ExtendedHitbox" or key == "GojoRearOrigin") and Color3.fromRGB(255, 187, 115)
            or Color3.fromRGB(233, 238, 246)
    end
    for key, row in pairs(self.OptionLabels or {}) do
        row.Object.Text = row.Label .. ": " .. string.format(row.Format, Options[key])
    end
    if self.SkillLabel then
        local state = self.SkillAssist:StatusText()
        self.SkillLabel.Text = "Skill assist: " .. state
    end
    if self.DefenceLabel then
        self.DefenceLabel.Text = "Block: " .. self.GuardStatus .. "\nPunish: " .. self.PunishStatus
    end
    if self.OriginLabel then self.OriginLabel.Text = self.ClientOrigin:StatusText() end
    if self.PanelStatus then
        self.PanelStatus.Text = "Tracking: " .. (self.TrackingReason or "Waiting for C target") .. "\n" .. self.NativeStatus
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
    self:StepBlackFlash()
    -- Process defence before UI, disk saves and other feature callbacks.
    self:StepPunish()
    self:StepDefence()
    self:StepRatio()
    self.SkillAssist:Step()
    self.Cosmetics:Step()
    if self.CharacterActionsLabel then
        local text = "Cosmetics: " .. self.Cosmetics.Status .. "\nTodo: " .. (self.TodoStatus or "Waiting for clap") .. "\nYuki R: " .. (self.YukiStatus or "Waiting for native R") .. "\nGaruda: " .. (self.GarudaStatus or "Waiting for Recall")
            .. "\nNanami R: " .. (self.RatioStatus or "Waiting for SpawnRatio")
            .. "\nBurst: " .. (self.BurstStatus or "Waiting for native grant")
        if self.CharacterActionsLabel.Text ~= text then self.CharacterActionsLabel.Text = text end
    end
    if self.OriginLabel then
        local text = self.ClientOrigin:StatusText()
        if self.OriginLabel.Text ~= text then self.OriginLabel.Text = text end
    end
    local skillStatus = self.SkillAssist:StatusText()
    if self.SkillLabel and self.LastSkillStatus ~= skillStatus then
        self.LastSkillStatus = skillStatus
        self.SkillLabel.Text = "Skill assist: " .. skillStatus
    end
    self:StepAutoSave()
    self:StepBurst()
    self:StepQTE()
    self:StepWorldSlash()
    self:StepShutUp()
    self:StepAdapt()
    self:StepAirMarkers()
    self:StepTrain()
    self:StepAnimations()
    self:StepBeam()
    self:StepYukiCharge()
    self:StepGaruda()
    if self.DefenceLabel then
        local text = "Block: " .. self.GuardStatus .. "\nPunish: " .. self.PunishStatus
        if self.DefenceLabel.Text ~= text then self.DefenceLabel.Text = text end
    end
    self:StepFollowUp()
    local now = os.clock()
    if now >= self.NextWatch then
        self.NextWatch = now + 0.15
        self:WatchTarget()
        self:RefreshEffects()
        self:UpdateInfo()
    end
    if now >= self.NextDiscovery then
        self.NextDiscovery = now + 2
        self:IndexAnimations()
        self:DiscoverRosterRemotes()
        self:DiscoverTrain()
        self.ClientOrigin:TryAttach()
        if not self.Tool or not self.Hitbox or not self.Movement then self:ResolveControllers() end
        self:RefreshPanel()
    end
end

Runtime.Stage = "combat helper setup"
Combat:IndexAnimations()
Combat:DiscoverRosterRemotes()
local cosmeticEquip = JJS:GetRemote("EmoteService", "Equip")
if cosmeticEquip then
    track(connect(cosmeticEquip.OnClientEvent, "cosmetic equip confirmation", function(slot, name)
        if Alive then Combat.Cosmetics:ObserveEquip(slot, name) end
    end))
end
Combat:BuildPanel()
Combat:SetupConveniences()
if RunService.PreSimulation then
    Combat.SkillAssist.PhysicsLatch = true
    track(connect(RunService.PreSimulation, "Yuki launch latch before physics", function()
        if Alive then
            Combat:StepBlackFlash()
            Combat:StepRatio()
            Combat:StepCursedStrike()
            Combat.SkillAssist:StepLatch()
        end
    end))
end
Combat.ClientOrigin:TryAttach()
local sharedHitbox = JJS:GetRemote("HitboxService", "Hitbox")
if sharedHitbox then Combat:AttachRemote(sharedHitbox) end
track(connect(ReplicatedStorage.DescendantAdded, "combat remote discovery", function(object)
    if object:IsA("Animation") then Combat:IndexAnimation(object) end
    if object.Name == "Effects" or object.Name == "Hitbox" then Combat:AttachRemote(object) end
end))
track(connect(ReplicatedStorage.DescendantRemoving, "deferred animation departure", function(object)
    local connection = Combat.PendingAnimationIds[object]
    if connection then connection:Disconnect(); Combat.PendingAnimationIds[object] = nil end
end))
for _, service in ipairs({"BlockService", "FinalJudgementService", "GarudaReboundService", "BeamService", "ItadoriService", "GojoService", "DivergentFistService",
    "FocusStrikeService", "NanamiService", "TodoService"}) do
    local remote = JJS:GetRemote(service, "Effects")
    if remote then Combat:AttachRemote(remote) end
end
track(connect(RunService.Heartbeat, "combat helpers", function()
    if Alive then Combat:Step() end
end))
for _, service in ipairs({"SwiftKickService", "InterrogateService", "YukiService"}) do
    local remote = JJS:GetRemote(service, "Effects")
    if remote then Combat:AttachRemote(remote) end
end
local gojoHitbox = JJS:GetRemote("GojoService", "Hitbox")
if gojoHitbox then Combat:AttachRemote(gojoHitbox) end
Combat:ResolveControllers()

Runtime.Stage = "configuration"
if not loadConfig() and Autos.AutoSave then Combat:MarkSettingsDirty() end
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

    Combat:ObserveBlockHits(char, generation)
    Combat:AttachBlackFlashAnimator(animator, char, generation)
    Combat:ApplyLocalInvisible()
    for _, object in ipairs(char:GetDescendants()) do
        if object:IsA("Sound") then Combat.Sounds[object] = true end
        Combat:ObserveOwnMarker(object, char)
    end
    trackCharacter(connect(char.DescendantAdded, "character sound arrival", function(object)
        if object:IsA("Sound") then Combat.Sounds[object] = true end
        Combat:ObserveOwnMarker(object, char)
        Combat:ObserveLocalInvisible(object)
    end))
    trackCharacter(connect(char.DescendantRemoving, "character sound departure", function(object)
        Combat.Sounds[object] = nil
        Combat.BurstMarkers[object], Combat.AirMarkers[object] = nil, nil
    end))

    trackCharacter(connect(animator.AnimationPlayed, "animation played", function(track)
        if not isCurrentCharacter(char, generation) then
            return
        end
        local animation = track.Animation
        local animId = animation and animation.AnimationId or ""
        if Combat.Blockable[animId] then Combat.OffenseUntil = os.clock() + 0.25 end
        Combat:OnSuiteAnimation(track, animId)
        Combat:ObserveTodoClap(track, char, generation)

        -- Perfect Swap is tied to native clap markers / accepted Swap events.
        -- The former half-animation timer could turn the swap into a fakeout.

    end))
end

--==============================================================
-- FEATURE CONTROL
--==============================================================
local function setFeature(name, enabled)
    name = Combat.FeatureAliases[name] or name
    if name == "SilentAim" then name = "MouseAssist" end
    if Autos[name] == nil then
        return false, "unknown feature"
    end
    return Combat:SetFeature(name, enabled)
end

local function toggleFeature(name)
    name = Combat.FeatureAliases[name] or name
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
local nextStatusUpdate = 0
track(connect(RunService.Heartbeat, "target status", function()
    if not Alive then
        return
    end
    if os.clock() < nextStatusUpdate then return end
    nextStatusUpdate = os.clock() + 0.1
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
                local labels = {aim = "🎯 Camera aim", hybrid = "🎯 Hybrid lock"}
                statusText = labels[currentMode] .. " @ " .. lockedTarget.Name
                statusText ..= Autos.VerticalAim and " · Height ON" or " · Height OFF (V)"
                color = Color3.fromRGB(80, 180, 255)
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
-- CAMERA / HYBRID LOOP
--==============================================================
local function renderFacing(dt)
    if not Alive then return end
    Combat.TrackingFrame = (Combat.TrackingFrame or 0) + 1
    if Combat:RenderCursedStrike(dt) then return end
    if Combat:RenderGuardTurn(dt) then return end
    if currentMode == "hybrid" then hybridFacing(dt)
    else Combat:ReleaseFacing() end
end

local function renderTracking(dt)
    if not Alive then return end
    updateFOVDrawing()
    if currentMode == "aim" or currentMode == "hybrid" then aimTracking(dt)
    else Combat.AimHistory = nil end
    if currentMode == "hybrid" then
        local cameraReason = Combat.CameraTrackingReason or "Waiting for camera"
        local facingReason = Combat.FacingTrackingReason or "Waiting for character"
        Combat.TrackingReason = cameraReason == "Tracking camera" and facingReason == "Tracking facing"
            and "Tracking camera + facing" or ("Camera: " .. cameraReason .. " · Character: " .. facingReason)
    end
    if Combat.PanelStatus then
        local text = "Tracking: " .. (Combat.TrackingReason or "Waiting for C target") .. "\n" .. Combat.NativeStatus
        if Combat.PanelStatus.Text ~= text then Combat.PanelStatus.Text = text end
    end
end

-- JJS MovementController binds Cam at Camera+1 (201). Aim at Camera+10
-- so the two writers never share a render priority.
-- Turn the root before PlayerModule reads it; aim after JJS finishes its camera.
-- This prevents a rendered frame of stale facing without a second smoothing
-- pass or a heartbeat-sized wait. Both bindings are removed together.
do
    local bound = false
    local facingName, cameraName = "RyuJJS_HybridFacing", "RyuJJS_CameraTracking"
    if type(RunService.BindToRenderStep) == "function" and type(RunService.UnbindFromRenderStep) == "function" then
        bound = pcall(function()
            RunService:BindToRenderStep(facingName, Enum.RenderPriority.Camera.Value - 1, guard("character tracking", renderFacing))
            RunService:BindToRenderStep(cameraName, Enum.RenderPriority.Camera.Value + 10, guard("camera tracking", renderTracking))
        end)
        if bound then
            Combat.TrackingBackend, Combat.CharacterTrackingBackend = "after JJS Cam (priority 210)", "before native camera"
            track({Disconnect = function()
                RunService:UnbindFromRenderStep(facingName)
                RunService:UnbindFromRenderStep(cameraName)
            end})
        else
            pcall(function() RunService:UnbindFromRenderStep(facingName) end)
            pcall(function() RunService:UnbindFromRenderStep(cameraName) end)
        end
    end
    if not bound then
        Combat.TrackingBackend, Combat.CharacterTrackingBackend = "RenderStepped fallback", "RenderStepped fallback"
        track(connect(RunService.RenderStepped, "camera / character tracking", function(dt)
            renderFacing(dt)
            renderTracking(dt)
        end))
    end
end

--==============================================================
-- INPUT
--==============================================================
Runtime.Stage = "input callbacks"
track(connect(UserInputService.InputChanged, "manual camera input", function(input, processed)
    Combat:ObserveCameraInput(input, processed)
end))

track(connect(UserInputService.InputBegan, "keyboard input", function(input, gpe)
    if gpe or not Alive or Combat:IsTyping() then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Combat.ManualAttackHeld = true
        Combat.OffenseUntil = os.clock() + 0.25
        Combat:ReleaseBlock()
        return
    end
    if input.KeyCode == Enum.KeyCode.R then
        if not Combat:HasPatch(Combat.Tool, "Special") then Combat:BeginYukiCharge() end
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
        Combat:CycleMode()
        return
    end

    if input.KeyCode == LockYKey then
        Combat:SetFeature("VerticalAim", not Autos.VerticalAim)
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

track(connect(UserInputService.InputEnded, "manual attack release", function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then Combat.ManualAttackHeld = false end
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
    GetStats = function()
        local stats = table.clone(Combat.Stats)
        for key, value in pairs(Combat.SkillAssist.Stats) do stats["Skill" .. key] = value end
        stats.IndexedTargets, stats.TargetFolderScans = #TargetIndex.List, TargetIndex.Scans
        stats.LastLockMS, stats.CharacterConnections = TargetIndex.LastLockMS, #CharacterConnections
        local watchers = 0
        for _ in pairs(Combat.Defenders) do watchers += 1 end
        stats.DefenceWatchers = watchers
        return stats
    end,
    GetStatus = function() return Combat.NativeStatus end,
    Hitbox = {
        Sphere = function(character, offset, diameter) return Combat.Hitboxes:Sphere(character, offset, diameter) end,
        GetStatus = function()
            local module = Combat.Hitboxes
            return {Backend = module.Backend, Queries = module.Queries, Fallbacks = module.Fallbacks,
                Candidates = module.Candidates, Size = Options.HitboxSize,
                SharedReport = "Model list; no origin field",
                Ready = Combat:HasPatch(Combat.Hitbox, "SphereHitbox"),
                LastQuery = module.LastQuery and table.clone(module.LastQuery) or nil}
        end,
    },
    SetMode = function(mode) return Combat:SetMode(mode) end,
    CycleMode = function() Combat:CycleMode(); return currentMode end,
    GetAimStatus = function()
        return {Smooth = Autos.SmoothAim, Response = Options.AimResponsiveness, PullStrength = Options.CameraAimStrength,
            ManualInput = Combat.AimHistory and Combat.AimHistory.ManualInput or false,
            Offset = Options.AimHorizontalOffset, Backend = Combat.TrackingBackend,
            Mode = currentMode, Reason = Combat.TrackingReason or "Waiting for C target",
            CharacterResponse = Options.CharacterResponsiveness, CharacterBackend = Combat.CharacterTrackingBackend,
            VerticalAim = Autos.VerticalAim, TurnSpeed = Options.SmoothTurnSpeed,
            CharacterOwned = Combat.FacingOwner ~= nil, CameraReason = Combat.CameraTrackingReason,
            CharacterReason = Combat.FacingTrackingReason}
    end,
    GetClientOriginStatus = function()
        local bridge = Combat.ClientOrigin
        local recent = {}
        for _, record in ipairs(bridge.Recent) do table.insert(recent, table.clone(record)) end
        return {Enabled = Autos.DashClientOrigin, Attached = bridge.Handler ~= nil, Status = bridge:StatusText(),
            Requests = bridge.Requests, DashRequests = bridge.DashRequests, Rewrites = bridge.Rewrites,
            Failures = bridge.Failures, HitSessions = bridge.HitSessions, Accepted = "unknown", Recent = recent,
            LastHit = bridge.LastHit and table.clone(bridge.LastHit) or nil}
    end,
    RetryClientOrigin = function() Combat.ClientOrigin:TryAttach(); Combat:RefreshPanel() end,
    GetRearOriginStatus = function()
        local skill = Combat.SkillAssist
        return {Enabled = Autos.GojoRearOrigin, Route = "Gojo variant only; server acceptance unverified",
            SharedRoute = "Front dash / Decisive: no origin in shared Model-list report",
            Reports = skill.Stats.RearOriginReports,
            LastReport = skill.LastGojoReport and table.clone(skill.LastGojoReport) or nil}
    end,
    GetDefenceStatus = function()
        return {OwnedBlock = Combat.BlockOwned == true, LockedOnly = Autos.DefenceLockedOnly,
            Projectiles = Autos.BlockProjectiles, AutoFace = Autos.GuardAutoFace,
            LastBlock = Combat.LastAutoBlock and table.clone(Combat.LastAutoBlock) or nil,
            BlockReason = Combat.GuardStatus, PunishReason = Combat.PunishStatus,
            Backend = "TBO animation tables + JJS BlockService.Effects", AnimationEntries = Combat.TBOAnimationCount,
            LastConfirm = Combat.LastGuardEffect and table.clone(Combat.LastGuardEffect) or nil,
            GuardAckMS = Combat.LastGuardAckMS, GuardPending = Combat.BlockOwned and not Combat:HasState(LocalPlayer.Character, "Block"),
            RetryInterval = Combat:GuardRoundTrip(), ManualGuardResume = Combat.GuardResume ~= nil,
            NativeBlockControllerAvailable = Combat.Tool and type(Combat.Tool.Block) == "function" or false,
            PunishPending = Combat.Punish ~= nil, BlockAttempts = Combat.BlockAttempts or 0}
    end,
    GetSkillAssistStatus = function()
        local skill = Combat.SkillAssist
        local jobs = 0
        for _ in pairs(skill.GojoJobs) do jobs += 1 end
        return {Enabled = Autos.SkillAssist, Status = skill:StatusText(), Stats = table.clone(skill.Stats),
            Active = skill.Window and skill.Window.Kind or nil, GojoSessions = jobs,
            Phase = skill.Window and skill.Window.Phase, NativeSession = skill.Window and skill.Window.NativeSession ~= nil or false,
            LastQuery = skill.LastQuery and table.clone(skill.LastQuery) or nil,
            LastSession = skill.LastNativeSession and table.clone(skill.LastNativeSession) or nil,
            HitboxHook = Combat:HasPatch(Combat.Hitbox, "SphereHitbox")}
    end,
    GetCharacterActionStatus = function()
        return {Yuki = Combat.YukiStatus or "Waiting for native R", FullYukiMeter = Combat:YukiMeterFull(),
            YukiHelperActive = Combat.YukiJob ~= nil, NativeSpecialPreserved = true,
            Garuda = Combat.GarudaStatus or "Waiting for Recall", Ratio = Combat.RatioStatus or "Waiting for SpawnRatio",
            RatioTiming = Combat.RatioJob and (Combat.RatioJob.ServerStart and "server clock" or "TBO fallback") or nil,
            RatioChainPending = Combat.RatioChain ~= nil, RatioTimingOffset = Options.RatioTimingOffset,
            Burst = Combat.BurstStatus or "Waiting for native grant", YukiCharge = LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Charge")}
    end,
    GetContentCatalog = function() return {Moves = table.clone(Combat.Roster.Counts),
        Emotes = table.clone(Combat.CosmeticCatalog.Emotes), Titles = table.clone(Combat.CosmeticCatalog.Titles),
        Outros = table.clone(Combat.CosmeticCatalog.MVP), CosmeticStatus = Combat.Cosmetics.Status,
        LocalOutro = Combat.Cosmetics.LocalOutro, OutroHookAvailable = Combat.Cosmetics.OutroModule ~= nil,
        PermanentOwnershipChanged = false} end,
    GetBlackFlashStatus = function()
        local pending = false
        for _, job in pairs(Combat.BlackFlashJobs) do if not job.Sent then pending = true; break end end
        pending = pending or Combat.TodoBlackFlashJob ~= nil
        return {Requests = Combat.Stats.BlackFlashRequests or 0,
            ConfirmedDivergentHits = Combat.Stats.BlackFlashConfirms or 0, Pending = pending,
            TodoRequests = Combat.Stats.TodoBlackFlashRequests or 0, TodoConfirmedHits = Combat.Stats.TodoBlackFlashConfirms or 0}
    end,
    GetMoveAssistStatus = function() return {CursedStrikes = Combat.CursedSteer ~= nil,
        Todo = Combat.TodoStatus, PerfectRequests = Combat.Stats.TodoPerfectRequests or 0,
        PerfectConfirmed = Combat.Stats.TodoPerfectConfirms or 0, InvisibleLocal = Autos.InvisibleLocal,
        ServerInvisibilityVerified = false, RatioServerSuccessForced = false} end,
    RequestCosmetic = function(kind, name, play) return Combat.Cosmetics:Request(kind, name, play == true) end,
    GetNetworkStatus = function()
        local ping = Combat:PingMilliseconds()
        return {PingMS = ping, DataPingMS = Combat.DataPingMS, NetworkPingMS = Combat.NetworkPingMS,
            QueueEstimateMS = Combat.QueueEstimateMS, PingSource = Combat.PingSource,
            Transport = "Roblox remotes / Knit Comm",
            Scope = "RyuJJS adapter counters; native game/Knit traffic excluded",
            Requests = JJS.WireStats.Requests, Failures = JJS.WireStats.Failures,
            CacheHits = JJS.WireStats.CacheHits, CacheMisses = JJS.WireStats.CacheMisses,
            LastFailure = JJS.LastFailure, GuardAckMS = Combat.LastGuardAckMS,
            ServerReplicationRateChanged = false}
    end,
    GetRatioStatus = function()
        return {Reason = Combat.RatioStatus, Pending = Combat.RatioJob ~= nil, ChainPending = Combat.RatioChain ~= nil,
            Requests = Combat.Stats.RatioRequests or 0, Confirmed = Combat.Stats.RatioConfirms or 0,
            Chains = Combat.Stats.RatioChains or 0, TimingOffset = Options.RatioTimingOffset,
            NativeTiming = Combat.LastRatioTiming, LearnedOffset = (Combat.RatioCorrection or 0) * 1000}
    end,
    GetFeatureStatus = function()
        local slots = 0
        for _ in pairs(Combat.EmoteRecords) do slots += 1 end
        return {AutoSave = Combat.SaveStatus, ExtraSlotControls = slots,
            AirHook = Combat:HasPatch(Combat.Tool, "UseTool") and Combat:HasPatch(Combat.Tool, "GetToolService"),
            TrainPrompt = Combat.TrainPrompt ~= nil,
            InstantPromptBridge = type(getGlobalFunction("fireproximityprompt")) == "function"}
    end,
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
        Text = "C lock • M: Camera / Hybrid\n"
            .. "V target height • X instant rear CFrame\n"
            .. "Z rear drift / stop • RightShift controls\n"
            .. "Camera smoothing ON; separate Hybrid response.",
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
