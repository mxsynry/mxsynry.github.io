-- Ryu Racing | Ryu Nanashi
-- UI: Rayfield by Sirius. QTE layouts: UPDATE 16 / SPECIAL WEEK.
-- Hooks: https://docs.sunc.io/Closures/hookfunction/

local Env = (type(getgenv) == "function" and getgenv()) or _G
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Player = Players.LocalPlayer
if not Player then
    warn("[Ryu Racing] Run this from the local player client.")
    return
end

local function capability(name)
    local value = Env[name] or getfenv()[name]
    return type(value) == "function" and value or nil
end

local Debug = type(Env.debug) == "table" and Env.debug or (type(debug) == "table" and debug or {})
local Cap = {
    upvalues = capability("getupvalues") or Debug.getupvalues,
    getupvalue = capability("getupvalue") or Debug.getupvalue,
    setupvalue = capability("setupvalue") or Debug.setupvalue,
    constants = capability("getconstants") or Debug.getconstants,
    hook = capability("hookfunction"),
    newc = capability("newcclosure"),
    newl = capability("newlclosure"),
    hookmeta = capability("hookmetamethod"),
    namecall = capability("getnamecallmethod"),
    connections = capability("getconnections"),
    gc = capability("getgc"),
    fenv = capability("getfenv") or getfenv,
    clipboard = capability("setclipboard") or capability("toclipboard"),
    touch = capability("firetouchinterest"),
}

local R = {
    Version = "2.9.2",
    Alive = true,
    Options = {
        InfiniteStamina = false,
        AutoQTE = false,
        QTEMethod = "Spoof",
        QTEGate = true,
        QTERing = true,
        QTESkillCheck = true,
        Steering = false,
        SteeringMode = "Camera",
        SteeringMethod = "Loop",
        SteeringTurnRate = 720,
        SteeringCameraAxis = "Game",
        Velocity = false,
        VelocityMode = "Multiplier",
        Multiplier = 1,
        StaticSpeed = 50,
        Jump = false,
        JumpPower = 50,
        JumpHeight = 7.2,
        Jitter = false,
        JitterIntensity = 0.5,
        JitterThreshold = 100,
        RevealUnavailable = true,
        SpoofCharacters = false,
        SpoofTitles = false,
        SpoofMVPs = false,
        SpoofIntros = false,
        SpoofBanners = false,
        SpoofSkillAnimations = true,
        SpoofUltimateCutscene = true,
        SpoofRaceSummary = true,
        EmoteLoop = true,
        EmoteSpeed = 1,
        EmoteVolume = 1,
        EmoteSlot = "1",
        AutoReady = false,
        AutoClaimQuests = false,
        NoShake = false,
        SteadyCamera = false,
        MuteCommentary = false,
        OverrideFOV = false,
        FOV = 75,
        InfiniteSpurts = false,
        InfiniteUlt = false,
        UltReplayGap = 10,
        LocalMenuEquips = true,
        OwnedRefreshInterval = 5,
        EmoteHotkeys = true,
    },
    Connections = {},
    Tasks = {},
    Modules = {},
    Categories = {},
    Rows = {},
    Unlocks = {},
    Created = {},
    Patches = {},
    Hooks = {},
    ValuePatches = {},
    ValueOwners = {},
    Spoofs = {},
    EmoteSlots = {},
    EmoteBridge = {},
    CosmeticRemotes = {},
    RuntimeModules = {},
    Opening = {},
    TitleDisplay = {},
    CharacterEquip = {},
    SkillPresentation = { modules = {}, map = {}, mirrors = {}, ownTracks = setmetatable({}, { __mode = "k" }),
        blocked = {}, responses = 0, swaps = 0, revision = 0, lastBind = -math.huge },
    Ownership = { inventories = {}, emotes = { ready = false, names = {} }, slots = {}, lastFetch = -math.huge },
    SteeringState = { scopes = setmetatable({}, { __mode = "k" }), lastBind = -math.huge },
    RaceActions = { attempts = {}, serial = 0, spurtResponses = 0, replaySerial = 0, lastReplay = -math.huge },
    RacePresentation = { sceneCalls = 0, sceneSwaps = 0, scenesInFlight = 0, inputs = {},
        localThreads = setmetatable({}, { __mode = "k" }) },
    QuestAttempts = setmetatable({}, { __mode = "k" }),
    Controls = {},
    Status = { stamina = "Off", qte = "Off", catalog = "Loading game catalogs", emotes = "Off", quests = "Loading...", opening = "Off", skills = "No skill requests yet", spurts = "Off", ultimate = "Off", menu = "Installing menu hooks", ownership = "Reading earned items", steering = "Off", character = "Select a character, then press Equip", skillAnimations = "Equip a client character first", zoneScene = "Using your real character", raceSummary = "Using the server result" },
    Errors = {},
    QTE = {
        plans = {}, tracked = {}, lastScan = -math.huge, lastGC = -math.huge,
        calls = 0, results = 0, kinds = {}, hooks = 0, hookFailures = {},
        completed = setmetatable({}, { __mode = "k" }),
        inFlight = {}, nativeTasks = {}, ignorePause = setmetatable({}, { __mode = "k" }),
    },
    Stamina = { root = nil, system = nil, observed = nil, written = nil, lastScan = -math.huge },
    Motion = { offset = Vector3.zero, offsetRoot = nil },
    LastMaintenance = -math.huge,
    LastReport = -math.huge,
    InventoryGeneration = 0,
}

function R:Error(scope, message)
    local entry = tostring(scope) .. ": " .. tostring(message)
    if self.Errors[#self.Errors] == entry then return end
    self.Errors[#self.Errors + 1] = entry
    if #self.Errors > 12 then table.remove(self.Errors, 1) end
    warn("[Ryu Racing] " .. entry)
end

function R:Notify(title, message)
    if self.Library and self.Alive then
        pcall(function()
            self.Library:Notify({ Title = title, Content = tostring(message), Duration = 6 })
        end)
    else
        warn("[Ryu Racing] " .. title .. ": " .. tostring(message))
    end
end

function R:Spawn(fn)
    local thread
    thread = task.defer(function()
        if self.Alive then
            local ok, err = pcall(fn)
            if not ok and self.Alive then self:Error("Task", err) end
        end
        self.Tasks[thread] = nil
    end)
    self.Tasks[thread] = true
    return thread
end

function R:Connect(signal, fn)
    local connection = signal:Connect(fn)
    self.Connections[#self.Connections + 1] = connection
    return connection
end

local function child(root, name)
    return root and root:FindFirstChild(name) or nil
end

local function at(root, path)
    for _, name in ipairs(path) do
        root = child(root, name)
        if not root then return nil end
    end
    return root
end

local function finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function numberValue(instance)
    if instance and (instance:IsA("NumberValue") or instance:IsA("IntValue")) then
        local value = instance.Value
        if finite(value) then return value end
    end
    return nil
end

local function inspectFunction(fn)
    local record = R.Hooks[fn]
    return record and record.original or fn
end

local function upvalues(fn)
    if type(fn) ~= "function" then return nil end
    fn = inspectFunction(fn)
    local ok, values
    if Cap.upvalues then ok, values = pcall(Cap.upvalues, fn) end
    if (not ok or type(values) ~= "table") and Cap.getupvalue then
        values, ok = {}, true
        -- sUNC returns the value, not Lua's (name, value) pair. Walk through
        -- nil slots as they can be live connections assigned after creation.
        for index = 1, 64 do
            local success, value = pcall(Cap.getupvalue, fn, index)
            if success then values[index] = value end
        end
    end
    if not ok or type(values) ~= "table" then return nil end
    -- Numeric positions are required; named-only executor results are not
    -- silently treated as the bytecode layout used by this game.
    if values[1] == nil and next(values) ~= nil then
        local numeric = false
        for key in pairs(values) do if type(key) == "number" then numeric = true; break end end
        if not numeric then return nil end
    end
    return values
end

function R:HookFunction(fn, scope, handler, object, family)
    if self.Hooks[fn] then return self.Hooks[fn] end
    if not Cap.hook or type(fn) ~= "function" then return nil end
    local record = { target = fn, scope = scope, object = object, active = true, family = family or "QTE" }
    local replacement = function(...)
        if not record.active or not self.Alive then return record.original(...) end
        return handler(record.original, ...)
    end
    -- sUNC L-closure hooks cannot carry more upvalues than their targets.
    -- A real executor C-closure wrapper avoids that restriction and may yield.
    local wrap = Cap.newc or Cap.newl
    if wrap then
        local ok, wrapped = pcall(wrap, replacement)
        if ok and type(wrapped) == "function" then replacement = wrapped end
    end
    local ok, original = pcall(Cap.hook, fn, replacement)
    if not ok or type(original) ~= "function" then
        self.QTE.hookFailures[scope] = tostring(original)
        return nil
    end
    record.original = original
    self.Hooks[fn] = record
    self.QTE.hooks += 1
    return record
end

function R:RestoreHook(record)
    record.active = false
    -- Restore the function returned by our hook, preserving the previous
    -- implementation instead of restorefunction's first-ever original.
    local ok, err
    if record.metamethod then
        ok, err = pcall(Cap.hookmeta, game, record.metamethod, record.original)
    else
        ok, err = pcall(Cap.hook, record.target, record.original)
    end
    self.Hooks[record.target] = nil
    if not ok then self:Error("Restore " .. record.scope, err) end
end

function R:RestoreHooks(family)
    local records = {}
    for _, record in pairs(self.Hooks) do
        if not family or record.family == family then records[#records + 1] = record end
    end
    for _, record in ipairs(records) do self:RestoreHook(record) end
end

function R:RestoreQTEHooks()
    self:RestoreHooks("QTE")
    self.QTE.boundApi = nil
end

local function connections(signal)
    if not Cap.connections then return {} end
    local ok, result = pcall(Cap.connections, signal)
    return ok and type(result) == "table" and result or {}
end

local function connectionFunction(connection)
    local ok, fn = pcall(function()
        if connection.Enabled == false or connection.Connected == false then return nil end
        return connection.Function
    end)
    return ok and type(fn) == "function" and fn or nil
end

function R:Module(key, path)
    local record = self.Modules[key]
    local instance = at(ReplicatedStorage, path)
    if record and record.instance == instance and record.value then return record.value end
    if record and (record.pending or (record.instance == instance and os.clock() < record.retry)) then
        return nil
    end
    if not instance or not instance:IsA("ModuleScript") then return nil end
    record = { instance = instance, pending = true, retry = os.clock() + 10 }
    self.Modules[key] = record
    self:Spawn(function()
        local ok, value = pcall(require, instance)
        record.pending = false
        if ok and type(value) == "table" then
            record.value = value
            self.CatalogDirty = true
        else
            record.error = tostring(value)
            self:Error("Catalog " .. key, value)
        end
    end)
    return nil
end

local function guiObject(value)
    return typeof(value) == "Instance" and value:IsA("GuiObject")
end

local function visibleInPlayerGui(object)
    if not guiObject(object) or not object:IsDescendantOf(Player) then return false end
    local cursor = object
    while cursor and cursor ~= Player do
        if cursor:IsA("GuiObject") and not cursor.Visible then return false end
        if cursor:IsA("ScreenGui") and not cursor.Enabled then return false end
        cursor = cursor.Parent
    end
    return true
end

function R:Patch(target, key, value)
    local fields = self.Patches[target]
    if not fields then fields = {}; self.Patches[target] = fields end
    local saved = fields[key]
    if not saved then
        saved = { original = rawget(target, key) }
        fields[key] = saved
    end
    if table.isfrozen and table.isfrozen(target) then return false end
    saved.written = value
    rawset(target, key, value)
    return true
end

function R:RestorePatches()
    for target, fields in pairs(self.Patches) do
        for key, saved in pairs(fields) do
            if rawget(target, key) == saved.written then
                pcall(rawset, target, key, saved.original)
            end
        end
    end
    table.clear(self.Patches)
end

-- Current Sprint reads Info.Stamina into Settings.System.stamina through
-- UpdateClientStamina. Replacing the outgoing SpeedTarget with zero did not
-- change that authority and could destroy the requested movement speed.
local function sprintState(value)
    if type(value) ~= "table" then return false end
    local system, core = rawget(value, "System"), rawget(value, "Core")
    return type(system) == "table" and type(core) == "table"
        and finite(rawget(system, "stamina")) and finite(rawget(system, "MAX_STAMINA"))
        and type(rawget(system, "sprintKeys")) == "table"
        and type(rawget(system, "movingKeys")) == "table"
end

function R:StaminaSource()
    local actual = self:RealValue(at(Player, { "Info", "Stamina" }))
    return finite(actual) and actual or nil, numberValue(at(Player, { "Info", "MaxStamina" }))
end

function R:ReleaseStamina()
    local state = self.Stamina
    local observed = self:StaminaSource()
    self:RestoreHooks("Stamina")
    self:ReleaseValues("Stamina:")
    if state.system then
        local actual = self:StaminaSource()
        local restore = actual or state.observed
        if finite(restore) and rawget(state.system, "stamina") == state.written then
            pcall(rawset, state.system, "stamina", restore)
        end
    end
    if state.system and state.blockedCap and observed and observed <= 0 and rawget(state.system, "serverTargetSpeed") == nil then
        rawset(state.system, "serverTargetSpeed", state.blockedCap)
    end
    state.system, state.observed, state.written, state.blockedCap = nil, nil, nil, nil
end

function R:MaintainStamina()
    local state = self.Stamina
    if state.applying or not self.Options.InfiniteStamina or not sprintState(state.root) then return end
    local system = rawget(state.root, "System")
    local maximum = rawget(system, "MAX_STAMINA")
    if not finite(maximum) or maximum <= 0 or (table.isfrozen and table.isfrozen(system)) then return end
    state.applying = true
    -- simulateStep reads this Value directly for exhaustion; updateUI also
    -- reads it rather than System.stamina. Keep its latest real value below.
    self:ForceValue("Stamina:Read", at(Player, { "Info", "Stamina" }), maximum)
    rawset(system, "stamina", maximum)
    state.written = maximum
    local actual = self:StaminaSource()
    local low = rawget(state.root.Core, "LowStaminaSpeed")
    local cap = rawget(system, "serverTargetSpeed")
    if actual and actual <= 0 and finite(low) and finite(cap) and cap <= low then
        state.blockedCap = cap
        rawset(system, "serverTargetSpeed", nil)
    end
    state.applying = false
end

function R:BindStaminaConsumers()
    local state = self.Stamina
    local function owns(fn)
        for _, value in pairs(upvalues(fn) or {}) do if value == state.root then return true end end
        return false
    end
    for _, request in ipairs({ { "UpdateClientStamina", false }, { "UpdateSprintAuthority", true } }) do
        local remote = at(ReplicatedStorage, { "remotes", request[1] })
        if remote and remote:IsA("RemoteEvent") then
            for _, connection in pairs(connections(remote.OnClientEvent)) do
                local fn = connectionFunction(connection)
                if type(fn) == "function" and owns(fn) then
                    local authority = request[2]
                    self:HookFunction(fn, request[1], function(original, value, mode, ...)
                        if self.Options.InfiniteStamina and authority and (mode == nil or mode == false) then
                            local actual = self:StaminaSource()
                            local low = state.root and state.root.Core and state.root.Core.LowStaminaSpeed
                            if actual and actual <= 0 and finite(low) and finite(value) and value <= low then
                                state.blockedCap = value
                                self:MaintainStamina()
                                return
                            end
                        end
                        self:MaintainStamina()
                        local result = table.pack(original(value, mode, ...))
                        self:MaintainStamina()
                        return table.unpack(result, 1, result.n)
                    end, remote, "Stamina")
                end
            end
        end
    end
    -- Follow the live Heartbeat callback to frameUpdate -> simulateStep.
    -- An inactive getproto copy would never affect a race.
    local owner = at(Player, { "PlayerScripts", "Client", "Sprint" })
    local queue, seen = {}, {}
    for _, connection in pairs(connections(RunService.Heartbeat)) do
        local fn = connectionFunction(connection)
        if type(fn) == "function" and Cap.fenv then
            local ok, environment = pcall(Cap.fenv, inspectFunction(fn))
            if ok and environment and environment.script == owner and owner then queue[#queue + 1] = { fn, 0 } end
        end
    end
    local index = 1
    while index <= #queue and index <= 64 do
        local item = queue[index]; index += 1
        local fn = item[1]
        if not seen[fn] then
            seen[fn] = true
            local ok, constants = false, nil
            if Cap.constants then ok, constants = pcall(Cap.constants, inspectFunction(fn)) end
            if ok and type(constants) == "table" and owns(fn)
                and table.find(constants, "serverTargetSpeed") and table.find(constants, "LowStaminaSpeed")
                and table.find(constants, "ForcedAccel") then
                self:HookFunction(fn, "Sprint stamina read", function(original, ...)
                    self:MaintainStamina()
                    return original(...)
                end, owner, "Stamina")
            elseif item[2] < 3 then
                for _, value in pairs(upvalues(fn) or {}) do
                    if type(value) == "function" and not seen[value] then queue[#queue + 1] = { value, item[2] + 1 } end
                end
            end
        end
    end
end

function R:BindStamina(force)
    local state, now = self.Stamina, os.clock()
    if not force and now - state.lastScan < 2 then return end
    state.lastScan = now
    local remote = at(ReplicatedStorage, { "remotes", "UpdateClientStamina" })
    if remote and remote:IsA("RemoteEvent") and (Cap.upvalues or Cap.getupvalue) then
        for _, connection in pairs(connections(remote.OnClientEvent)) do
            local values = upvalues(connectionFunction(connection))
            if values then
                for _, value in pairs(values) do
                    if sprintState(value) then state.root = value; self:BindStaminaConsumers(); return end
                end
            end
        end
    end
    if sprintState(state.root) then self:BindStaminaConsumers(); return end
    -- One bounded fallback scan when the targeted connection cannot be read.
    -- Only exact Sprint state shapes are accepted; this never scans each frame.
    if Cap.gc then
        local ok, values = pcall(Cap.gc, true)
        if ok and type(values) == "table" then
            local found
            for _, value in pairs(values) do
                if sprintState(value) then
                    if found and found ~= value then
                        self.Status.stamina = "Multiple Sprint states; waiting for the active remote callback"
                        return
                    end
                    found = value
                end
            end
            if found then state.root = found; self:BindStaminaConsumers(); return end
        end
    end
    state.root = nil
end

function R:TickStamina()
    if not self.Options.InfiniteStamina then return end
    local state = self.Stamina
    self:BindStamina(false)
    if not sprintState(state.root) then
        self.Status.stamina = (Cap.upvalues or Cap.getupvalue or Cap.gc)
            and "Waiting for the race Sprint state"
            or "Unavailable: executor has no upvalue/table inspection"
        return
    end
    local system = rawget(state.root, "System")
    if system ~= state.system then
        self:ReleaseStamina()
        state.system = system
        state.observed = rawget(system, "stamina")
        self:BindStaminaConsumers()
    end
    local current, maximum = rawget(system, "stamina"), rawget(system, "MAX_STAMINA")
    if not finite(maximum) or maximum <= 0 then
        self.Status.stamina = "Waiting for MaxStamina"
        return
    end
    if current ~= state.written then state.observed = current end
    if table.isfrozen and table.isfrozen(system) then
        self.Status.stamina = "Unavailable: current Sprint state is read only"
        return
    end
    self:MaintainStamina()
    local actual = self:StaminaSource()
    self.Status.stamina = string.format("Client: %.0f/%.0f | server: %s",
        maximum, maximum, actual and string.format("%.0f", actual) or "not replicated")
end

function R:SetStamina(enabled)
    self.Options.InfiniteStamina = enabled == true
    if enabled then
        self:BindStamina(true)
        self:TickStamina()
    else
        self:ReleaseStamina()
        self.Status.stamina = "Off"
    end
end

-- QTE: capture live handlers, resolve their own finish callbacks, then
-- either spoof the result or wait for the native timing window.
function R:QTEOwner(fn)
    fn = inspectFunction(fn)
    if Cap.fenv then
        local ok, environment = pcall(Cap.fenv, fn)
        if ok and type(environment) == "table" and environment.script then
            return environment.script == self.QTEModule
        end
    end
    if Debug.info then
        local ok, source = pcall(Debug.info, fn, "s")
        if ok and type(source) == "string" then
            return string.find(source, "QuickTimeEvent", 1, true) ~= nil
        end
    end
    return false
end

local function hasConstants(fn, required)
    if not Cap.constants then return nil end
    local ok, values = pcall(Cap.constants, inspectFunction(fn))
    if not ok or type(values) ~= "table" then return nil end
    local found = {}
    for _, value in pairs(values) do
        if type(value) == "string" then found[value] = true end
    end
    for _, value in ipairs(required) do if not found[value] then return false end end
    return true
end

local function connected(handle)
    if not handle then return nil end
    local ok, state = pcall(function()
        if handle.Connected == false or handle.Enabled == false then return false end
        return handle.Connected == true or handle.Enabled == true
    end)
    return ok and state or false
end

local function liveCapturedConnection(values)
    for _, value in pairs(values or {}) do
        if (typeof(value) == "RBXScriptConnection" or type(value) == "table") then
            local ok, live = pcall(function()
                return type(value.Disconnect) == "function" and value.Connected == true
            end)
            if ok and live then return true end
        end
    end
    return false
end

function R:QTEPlan(fn, route)
    local values = upvalues(fn)
    if not values then return nil end
    local owner = self:QTEOwner(fn)
    local skillSignature = hasConstants(fn, { "Time", "Rotation", "Disconnect" })
    -- Both mobile (GUI at U5) and desktop (GUI at U6), plus the shared
    -- onInput helper (GUI at U3), capture the GUI followed by its hit arc.
    if skillSignature == true or (owner and skillSignature == nil) then
        for index, value in pairs(values) do
            if type(index) == "number" and guiObject(value)
                and child(value, "Time") and child(value, "Timeframe")
                and finite(values[index + 1]) and finite(values[index + 2]) then
                local finish
                for before = index - 1, 1, -1 do
                    if type(values[before]) == "function" then finish = values[before]; break end
                end
                if finish then
                    local signature = hasConstants(finish, { "StaminaQTEState", "Correct", "Incorrect" })
                    if signature == true or (owner and signature == nil) then
                        return {
                            fn = fn, kind = "SkillCheck", route = route, gui = value,
                            complete = finish, arc = index + 1,
                            pause = type(values[1]) == "boolean" and 1 or nil,
                        }
                    end
                end
            end
        end
    end
    local ringSignature = hasConstants(fn, { "AbsoluteSize", "X", "Y" })
    if ringSignature == true or (owner and ringSignature == nil) then
        local first, second, lastIndex
        for index = 1, 24 do
            if guiObject(values[index]) then
                if not first then first = values[index] else second = values[index] end
                lastIndex = index
            end
        end
        if first and second and first ~= second then
            local finish
            for index = (lastIndex or 0) + 1, 24 do
                if type(values[index]) == "function" then finish = values[index]; break end
            end
            if finish then
                local signature = hasConstants(finish, { "QTESuccess", "QTEFail", "Disconnect" })
                if signature == true or (owner and signature == nil) then
                    return {
                        fn = fn, kind = "Ring", route = route, gui = first,
                        ring = first, zone = second, complete = finish,
                    }
                end
            end
        end
    end
    local gateSignature = hasConstants(fn, { "QTESuccess", "AddSound", "Connected" })
    if gateSignature ~= true and not (owner and gateSignature == nil) then return nil end
    if type(values[1]) ~= "boolean" then return nil end
    -- Gate successes also update counters inline. Run the actual input
    -- callback, temporarily opening its hit-window upvalue in Spoof mode.
    if typeof(values[2]) == "EnumItem" and values[2].EnumType == Enum.KeyCode
        and type(values[3]) == "boolean" and type(values[4]) == "boolean"
        and type(values[12]) == "function" and finite(values[13]) then
        return { fn = fn, kind = "Gate", route = "keyboard", pause = 1, window = 4, key = 2 }
    end
    if type(values[2]) == "boolean" and type(values[3]) == "boolean"
        and type(values[11]) == "function" and finite(values[12]) then
        return { fn = fn, kind = "Gate", route = "jump", pause = 1, window = 3 }
    end
    return nil
end

function R:QTEEnabled(plan)
    return self.Alive and self.Options.AutoQTE
        and self.Options[plan.kind == "Gate" and "QTEGate"
            or plan.kind == "Ring" and "QTERing" or "QTESkillCheck"]
end

function R:QTEPaused(plan, values)
    if plan.pause and values[plan.pause] == true then return true end
    if self.QTE.ignorePause[plan.gui or plan.fn] then return false end
    local record = self.Modules.CutsceneSync
    local sync = record and record.value
    if sync and type(sync.IsPaused) == "function" then
        local ok, paused = pcall(sync.IsPaused)
        if ok then return paused == true end
    end
    return false
end

function R:QTEIsLive(plan, values)
    if plan.connection and connected(plan.connection) ~= true then return false end
    if plan.registry and rawget(plan.registry, plan.registryKey) ~= plan.fn then return false end
    if plan.gc and not liveCapturedConnection(values)
        and not liveCapturedConnection(upvalues(plan.complete)) then return false end
    if plan.gui and not visibleInPlayerGui(plan.gui) then return false end
    if plan.zone and not visibleInPlayerGui(plan.zone) then return false end
    if plan.complete and self.QTE.completed[plan.complete] then return false end
    return true
end

function R:HookQTEResult(plan)
    if not self.Options.AutoQTE or not plan.complete then return end
    local kind = plan.kind
    self:HookFunction(plan.complete, "QTE " .. kind, function(original, result, ...)
        if self:QTEEnabled(plan) and self.Options.QTEMethod == "Spoof"
            and not self:QTEPaused(plan, upvalues(plan.fn) or {})
            and self:QTEIsLive(plan, upvalues(plan.fn) or {})
            and type(result) == "boolean" then
            result = true
        end
        if type(result) == "boolean" then self.QTE.completed[plan.complete] = true end
        return original(result, ...)
    end, plan.gui)
end

function R:BindQTEHooks()
    if not self.Options.AutoQTE then return end
    local buttons = self.QTEButtons
    if buttons and type(buttons.connectPress) == "function" then
        self:HookFunction(buttons.connectPress, "QTE registration", function(original, callback, ...)
            local result = table.pack(original(callback, ...))
            if self.Alive and self.Options.AutoQTE and type(callback) == "function" then
                self.QTE.tracked[callback] = result[1]
                self.QTE.lastScan = -math.huge
            end
            return table.unpack(result, 1, result.n)
        end, self.QTEButtonsInstance)
    end
    -- The exported API closes over startQTE, ultQTE and StartSkillCheck.
    -- Walk those real closures, not inactive debug.getproto copies.
    if not self.QTEApi or self.QTE.boundApi == self.QTEApi then return end
    self.QTE.boundApi = self.QTEApi
    local queue, seen = {}, {}
    for _, fn in pairs(self.QTEApi or {}) do
        if type(fn) == "function" then queue[#queue + 1] = { fn, 0 } end
    end
    local index = 1
    while index <= #queue and index <= 160 do
        local item = queue[index]; index += 1
        local fn, depth = item[1], item[2]
        if not seen[fn] then
            seen[fn] = true
            local skill = hasConstants(fn, { "StaminaQTE", "Timeframe", "LastInputTypeChanged" }) == true
            local ring = hasConstants(fn, { "UltEvent", "Range", "Close", "Keybind" }) == true
            local gate = hasConstants(fn, { "JumpRequest", "InputBegan", "Delay", "Now" }) == true
            if skill or ring or gate then
                self:HookFunction(fn, "QTE start", function(original, ...)
                    local args = table.pack(...)
                    local before = {}
                    local gui = at(Player, { "PlayerGui", "QTEGui" })
                    if skill and gui then
                        for _, object in ipairs(gui:GetChildren()) do before[object] = true end
                    end
                    local result = table.pack(original(table.unpack(args, 1, args.n)))
                    if self.Alive and self.Options.AutoQTE then
                        if skill and gui then
                            for _, object in ipairs(gui:GetChildren()) do
                                if not before[object] and child(object, "Time") and child(object, "Timeframe") then
                                    self.QTE.ignorePause[object] = type(args[3]) == "table"
                                        and args[3].ignorePause == true
                                end
                            end
                        end
                        self.QTE.lastScan = -math.huge
                        self:Spawn(function() self:ScanQTE(true); self:TickQTE() end)
                    end
                    return table.unpack(result, 1, result.n)
                end, self.QTEModule)
            end
            if depth < 4 then
                for _, value in pairs(upvalues(fn) or {}) do
                    if type(value) == "function" and not seen[value] then
                        queue[#queue + 1] = { value, depth + 1 }
                    end
                end
            end
        end
    end
end

function R:ScanQTE(force)
    local now = os.clock()
    if not force and now - self.QTE.lastScan < 0.04 then return end
    self.QTE.lastScan = now
    local old, plans, seen = {}, {}, {}
    for _, plan in ipairs(self.QTE.plans) do old[plan.fn] = plan end
    local function add(fn, route, handle, registry, key, fromGC)
        if type(fn) ~= "function" or seen[fn] then return end
        local plan = self:QTEPlan(fn, route)
        if not plan then return end
        plan.connection, plan.registry, plan.registryKey, plan.gc = handle, registry, key, fromGC
        if not self:QTEIsLive(plan, upvalues(fn) or {}) then return end
        seen[fn] = true
        plan.lastCall = old[fn] and old[fn].lastCall or -math.huge
        plans[#plans + 1] = plan
        self:HookQTEResult(plan)
    end
    local buttons = self.QTEButtons
    if buttons and type(buttons.connectPress) == "function" then
        -- Find callback tables by their contents, regardless of upvalue slot.
        for _, value in pairs(upvalues(buttons.connectPress) or {}) do
            if type(value) == "table" then
                for key, fn in pairs(value) do add(fn, "press", nil, value, key) end
            end
        end
    end
    for fn, handle in pairs(self.QTE.tracked) do
        if connected(handle) == true then add(fn, "press", handle)
        else self.QTE.tracked[fn] = nil end
    end
    for _, connection in pairs(connections(UserInputService.InputBegan)) do
        add(connectionFunction(connection), "keyboard", connection)
    end
    for _, connection in pairs(connections(UserInputService.JumpRequest)) do
        add(connectionFunction(connection), "jump", connection)
    end
    -- Some mobile executors cannot enumerate signal connections. Only scan
    -- when needed, and require a current connection captured by the closure.
    if #plans == 0 and Cap.gc and now - self.QTE.lastGC >= 1 then
        self.QTE.lastGC = now
        local ok, objects = pcall(Cap.gc, false)
        if ok and type(objects) == "table" then
            for _, fn in pairs(objects) do
                if type(fn) == "function" and self:QTEOwner(fn) then add(fn, "gc", nil, nil, nil, true) end
            end
        end
    end
    self.QTE.plans = plans
    local expired = {}
    for _, record in pairs(self.Hooks) do
        if record.family == "QTE" and record.object and typeof(record.object) == "Instance"
            and not record.object:IsDescendantOf(Player) then expired[#expired + 1] = record end
    end
    for _, record in ipairs(expired) do self:RestoreHook(record) end
end

function R:QTEReady(plan, values)
    if not self:QTEEnabled(plan) or not self:QTEIsLive(plan, values)
        or self:QTEPaused(plan, values) then return false end
    if self.Options.QTEMethod == "Spoof" and (plan.kind ~= "Gate" or Cap.setupvalue) then return true end
    if plan.kind == "Ring" then
        local ring, zone = plan.ring.AbsoluteSize, plan.zone.AbsoluteSize
        return ring.X > 0 and ring.Y > 0 and zone.X > 0 and zone.Y > 0
            and ring.X <= zone.X and ring.Y <= zone.Y
    elseif plan.kind == "SkillCheck" then
        local arrow = child(plan.gui, "Time")
        local start, width = values[plan.arc], values[plan.arc + 1]
        if not arrow or not finite(arrow.Rotation) or not finite(start)
            or not finite(width) or width <= 0 or width > 360 then return false end
        return (arrow.Rotation - start) % 360 <= width
    end
    return values[plan.window] == true
end

function R:ExecuteQTE(plan)
    local values = upvalues(plan.fn)
    if not values or not self:QTEReady(plan, values) then return false end
    if plan.complete then
        -- The finish callback handles disconnects, effects and the next round
        -- on both PC and touch. No fabricated InputObject is needed here.
        self.QTE.completed[plan.complete] = true
        plan.complete(true)
        return true
    end
    local original, patched = values[plan.window], false
    local target = inspectFunction(plan.fn)
    if self.Options.QTEMethod == "Spoof" and original ~= true and Cap.setupvalue then
        local ok = pcall(Cap.setupvalue, target, plan.window, true)
        local current = upvalues(plan.fn)
        patched = ok and current and current[plan.window] == true
        if not patched then return false end
    end
    local ok, err
    if plan.route == "keyboard" then
        ok, err = pcall(plan.fn, {
            KeyCode = values[plan.key], UserInputType = Enum.UserInputType.Keyboard,
            UserInputState = Enum.UserInputState.Begin,
        }, false)
    else
        ok, err = pcall(plan.fn)
    end
    -- Keep changes the native callback made itself. Restore our temporary
    -- write only if it is still present, including when the callback errors.
    if patched then
        local current = upvalues(plan.fn)
        if current and current[plan.window] == true then
            pcall(Cap.setupvalue, target, plan.window, original)
        end
    end
    if not ok then error(err, 0) end
    return true
end

function R:QueueQTE(plan)
    local key = plan.complete or plan.fn
    if self.QTE.inFlight[key] then return end
    self.QTE.inFlight[key] = true
    local thread
    thread = task.defer(function()
        -- Once native cleanup starts, allow it to finish if the script is
        -- disabled or unloaded during a yield. Never stall RenderStepped.
        local ok, used = pcall(self.ExecuteQTE, self, plan)
        self.QTE.inFlight[key] = nil
        self.QTE.nativeTasks[thread] = nil
        if ok and used then
            self.QTE.calls += 1
            self.QTE.kinds[plan.kind] = (self.QTE.kinds[plan.kind] or 0) + 1
        elseif not ok and self.Alive then
            self:Error("Auto QTE " .. plan.kind, used)
        end
    end)
    self.QTE.nativeTasks[thread] = true
end

function R:SetAutoQTE(enabled)
    self.Options.AutoQTE = enabled == true
    self.QTE.lastScan = -math.huge
    self.QTE.plans = {}
    self.Status.qte = enabled and "Waiting for QTE" or "Off"
    if enabled then
        self:LoadPlayerModules()
        self:BindQTEHooks()
    else
        self:RestoreQTEHooks()
        table.clear(self.QTE.tracked)
    end
end

function R:TickQTE()
    if not self.Options.AutoQTE then return end
    if not (Cap.upvalues or Cap.getupvalue) then
        self.Status.qte = "Unavailable: missing getupvalues / debug.getupvalue"
        return
    end
    local gui = at(Player, { "PlayerGui", "QTEGui" })
    if not gui or not gui.Enabled then
        self.QTE.plans = {}
        self.Status.qte = "Waiting for QTE"
        return
    end
    self:ScanQTE(false)
    local now = os.clock()
    for _, plan in ipairs(self.QTE.plans) do
        local values = upvalues(plan.fn)
        if values and now - plan.lastCall >= 0.09 and self:QTEReady(plan, values) then
            plan.lastCall = now
            self:QueueQTE(plan)
        end
    end
    local count = #self.QTE.plans
    self.Status.qte = count > 0
        and string.format("%s | %d handler(s) | %d calls", self.Options.QTEMethod, count, self.QTE.calls)
        or "QTE visible; waiting for a live handler"
end

function R:LoadPlayerModules()
    local client = at(Player, { "PlayerScripts", "Client" })
    local main = child(client, "QuickTimeEvent")
    local buttons = child(client, "QTEButton")
    for _, request in ipairs({
        { instance = main, key = "QTEApi", instanceKey = "QTEModule" },
        { instance = buttons, key = "QTEButtons", instanceKey = "QTEButtonsInstance" },
    }) do
        local module = request.instance
        if module and module:IsA("ModuleScript") and module ~= self[request.instanceKey] then
            self[request.instanceKey], self[request.key] = module, nil
            self:Spawn(function()
                local ok, value = pcall(require, module)
                if self[request.instanceKey] ~= module then return end
                if ok and type(value) == "table" then
                    self[request.key] = value
                    self:BindQTEHooks()
                    self.QTE.lastScan = -math.huge
                else
                    self[request.instanceKey] = nil
                    self:Error(module.Name, value)
                end
            end)
        end
    end
    self:BindQTEHooks()
end

-- Live catalog discovery: keys and ownership-value formats come from the
-- supplied game, rather than a list of character names baked into the script.
R.Categories = {
    Characters = { label = "Characters", path = { "RollingData", "Inventory" } },
    Titles = { label = "Titles", path = { "NameTagData", "Inventory" } },
    MVPs = { label = "Outros / MVPs", path = { "MVPData", "Inventory" } },
    Intros = { label = "Openings", path = { "IntroData", "Inventory" } },
    Banners = { label = "Banners", path = { "ThumbnailData", "Inventory" } },
    Emotes = { label = "Emotes", emotes = true },
}
R.CategoryOrder = { "Characters", "Titles", "MVPs", "Intros", "Banners", "Emotes" }
for _, category in ipairs(R.CategoryOrder) do
    R.Rows[category], R.Created[category], R.Unlocks[category] = {}, {}, false
end

function R:LoadCatalogs()
    self:Module("UmaConfig", { "Package", "UmaConfig" })
    self:Module("CharactersUma", { "Package", "CharactersUma" })
    self:Module("NameTagList", { "Package", "Modules", "NameTagList" })
    self:Module("MVPList", { "Package", "Modules", "MVPList" })
    self:Module("IntroList", { "Package", "IntroList" })
    self:Module("BannerConfig", { "Package", "BannerConfig" })
    self:Module("EmoteList", { "EmoteList" })
    self:Module("CutsceneSync", { "Package", "Modules", "CutsceneSync" })
    self:Module("Works", { "Package", "MWorks" })
end

function R:RebuildCatalog()
    local rows, seen = {}, {}
    for _, category in ipairs(self.CategoryOrder) do rows[category], seen[category] = {}, {} end
    local function add(category, key, data, value)
        if type(data) ~= "table" or type(key) == "table" then return end
        key = tostring(key)
        value = tostring(value or key)
        if key == "" or value == "" or seen[category][value] then return end
        seen[category][value] = true
        local label = tostring(data.DisplayName or data.Display or data.Name or key)
        if label ~= key then label ..= " [" .. key .. "]" end
        rows[category][#rows[category] + 1] = {
            key = key, value = value, label = label, data = data, category = category,
        }
    end
    local function value(key) return self.Modules[key] and self.Modules[key].value end
    for key, data in pairs(value("UmaConfig") or {}) do
        if type(data) == "table" and type(data.Name) == "string" then
            add("Characters", key, data, data.Name)
        end
    end
    local characters = value("CharactersUma")
    for key, data in pairs(characters and characters.Characters or {}) do
        if type(data) == "table" and type(data.Name) == "string" then
            add("Characters", type(key) == "string" and key or data.Name, data, data.Name)
        end
    end
    for category, moduleName in pairs({ Titles = "NameTagList", MVPs = "MVPList", Intros = "IntroList" }) do
        local catalog = value(moduleName)
        for key, data in pairs(catalog and catalog.Tags or {}) do add(category, key, data) end
    end
    for key, data in pairs(value("BannerConfig") or {}) do
        if type(data) == "table" and data.Name ~= nil and data.Image ~= nil then
            add("Banners", data.Name or key, data, data.Name)
        end
    end
    local emoteCatalog = value("EmoteList")
    local function collectEmotes(catalog, depth)
        if type(catalog) ~= "table" or depth > 2 then return end
        for key, data in pairs(catalog) do
            if type(data) == "table" then
                if data.MainAnimation or data.IdleAnimation then
                    add("Emotes", type(key) == "string" and key or data.Name or key, data)
                elseif depth < 2 then collectEmotes(data, depth + 1) end
            end
        end
    end
    collectEmotes(emoteCatalog, 0)
    local total = 0
    for _, category in ipairs(self.CategoryOrder) do
        table.sort(rows[category], function(a, b) return a.label:lower() < b.label:lower() end)
        total += #rows[category]
    end
    self.Rows = rows
    self.Status.catalog = tostring(total) .. " catalog entries discovered"
    self.CatalogDirty = false
    self:RefreshSelectors()
    self:ApplyUnlocks()
    self:ApplySpoofs()
    self:UpdateCharacterInfo()
    self:RefreshEmoteBridge(true)
end

function R:RemoveLocalEntries(category)
    for instance in pairs(self.Created[category]) do
        pcall(function() instance:Destroy() end)
    end
    table.clear(self.Created[category])
end

function R:ApplyUnlocks()
    self:SnapshotInventories()
    self.InventoryGeneration += 1
    local generation = self.InventoryGeneration
    self:RestorePatches()
    if self.Unlocks.Characters and self.Options.RevealUnavailable then
        for _, row in ipairs(self.Rows.Characters) do
            self:Patch(row.data, "Released", true)
            self:Patch(row.data, "PublicAvailable", true)
        end
    end
    for _, category in ipairs(self.CategoryOrder) do
        if not self.Unlocks[category] then self:RemoveLocalEntries(category) end
    end
    self:Spawn(function()
        local count = 0
        for _, category in ipairs(self.CategoryOrder) do
            local definition = self.Categories[category]
            if self.Unlocks[category] and definition.path then
                local folder = at(Player, definition.path)
                if folder then
                    local existing = {}
                    for _, instance in ipairs(folder:GetChildren()) do
                        if instance:IsA("StringValue") then existing[instance.Value] = true end
                    end
                    for _, row in ipairs(self.Rows[category]) do
                        if not self.Alive or generation ~= self.InventoryGeneration
                            or not self.Unlocks[category] then return end
                        if not existing[row.value] then
                            local instance = Instance.new("StringValue")
                            -- player_card.obtainableCount uses FindFirstChild(key)
                            -- for these three catalogs; readNames also reads Value.
                            instance.Name = (category == "Titles" or category == "Intros" or category == "MVPs")
                                and row.key or "__RyuLocal_" .. row.key
                            instance.Value = row.value
                            instance:SetAttribute("RyuLocalPreview", true)
                            self.Created[category][instance] = true
                            instance.Parent = folder
                            existing[row.value] = true
                            count += 1
                            if count % 24 == 0 then task.wait() end
                        end
                    end
                end
            end
        end
    end)
end

function R:SetUnlock(category, enabled)
    if not self.Categories[category] then return end
    if enabled then
        self:RefreshRequestHooks(true)
        if not self.Hooks.EmoteNamecall then
            self.Status.menu = "Menu hook unavailable; use the script's cosmetic/emote controls"
            self:Notify("Collection", self.Status.menu)
            local control = self.UnlockControls and self.UnlockControls[category]
            if control then pcall(function() control:Set(false) end) end
            return false
        end
    end
    self.Unlocks[category] = enabled == true
    self:ApplyUnlocks()
    if category == "Emotes" then self:RefreshEmoteBridge(true) end
    self:RefreshRequestHooks()
end

function R:IsRealOwned(row)
    return row and self:IsEarned(row.category, row.value) or false
end

function R:SnapshotInventories(only)
    local state = self.Ownership
    for _, category in ipairs(self.CategoryOrder) do
        local definition = self.Categories[category]
        if definition.path and (not only or only == category) then
            local folder, names, values, count = at(Player, definition.path), {}, {}, 0
            if folder then
                for _, instance in ipairs(folder:GetChildren()) do
                    if instance:IsA("StringValue") and not self.Created[category][instance]
                        and not instance:GetAttribute("RyuLocalPreview") then
                        names[instance.Value] = true
                        if not values[instance.Value] then values[instance.Value] = true; count += 1 end
                        if category == "Titles" or category == "MVPs" or category == "Intros" then names[instance.Name] = true end
                    end
                end
                -- A real grant can share the same name/value as our preview.
                -- Remove only the preview so native FindFirstChild sees the grant.
                for instance in pairs(self.Created[category]) do
                    if names[instance.Value] then
                        self.Created[category][instance] = nil
                        pcall(function() instance:Destroy() end)
                    end
                end
            end
            state.inventories[category] = { ready = folder ~= nil, folder = folder, names = names, count = count }
        end
    end
    state.equipped = state.equipped or {}
    for category, path in pairs(self.CosmeticPaths or {}) do
        if not only or only == category then state.equipped[category] = self:RealValue(at(Player, path)) end
    end
end

function R:EmoteDataReady()
    local data = self.Ownership.emotes
    return data.ready and not data.stale and os.clock() - (data.fetched or -math.huge)
        <= math.max(30, self.Options.OwnedRefreshInterval * 3)
end

function R:IsEarned(category, key)
    if category == "Emotes" then return self.Ownership.emotes.names[key] == true end
    self:SnapshotInventories(category)
    local data = self.Ownership.inventories[category]
    return data and data.ready and data.names[key] == true or false
end

function R:RealRemote(remote, method, ...)
    -- Calling our saved original method bypasses only our projected reply.
    -- The namecall/equip guards remain installed throughout a yielding read.
    local fn = remote and remote[method]
    if type(fn) ~= "function" then error("Native remote method is unavailable") end
    return inspectFunction(fn)(remote, ...)
end

function R:CaptureEmoteOwnership(names)
    if type(names) ~= "table" then return false end
    local owned = {}
    for _, name in pairs(names) do if type(name) == "string" and name ~= "" then owned[name] = true end end
    self.Ownership.emotes = { ready = true, names = owned, fetched = os.clock(), stale = false }
    return true
end

function R:ReadEmoteOwnership()
    local getter = at(ReplicatedStorage, { "Package", "Animations", "Emotes", "Remotes", "Getter" })
    if not getter then return false end
    local ok, names = pcall(function() return self:RealRemote(getter, "InvokeServer", "GetOwnedEmotes") end)
    if ok and self:CaptureEmoteOwnership(names) then
        self:ReconcileEarnedItems()
        return true
    end
    self.Ownership.emotes.stale = true
    return false
end

function R:ReconcileEarnedItems()
    for category in pairs(self.CosmeticPaths) do
        local row = self:SpoofRow(category)
        if self.Spoofs[category] and row and self:IsRealOwned(row) then
            self:SetSpoof(category, false)
            local toggle = self.Controls["Spoof" .. category]
            if toggle then pcall(function() toggle:Set(false) end) end
        end
    end
    for slot, name in pairs(self.EmoteSlots) do
        if self:IsEarned("Emotes", name) then
            self.EmoteSlots[slot] = nil
            self:ReleaseValue("EmoteSlot:" .. slot)
        end
    end
    if self.EmoteName and self:IsEarned("Emotes", self.EmoteName) then self:StopEmote() end
end

function R:RefreshOwnedData(force)
    self:SnapshotInventories()
    self:ReconcileEarnedItems()
    local state, now = self.Ownership, os.clock()
    if state.fetching or (not force and now - state.lastFetch < self.Options.OwnedRefreshInterval) then return end
    local base = at(ReplicatedStorage, { "Package", "Animations", "Emotes", "Remotes" })
    local getter, slots = child(base, "Getter"), child(base, "EmotesGet")
    if not getter or not slots then self.Status.ownership = "Waiting for native player data"; return end
    state.fetching, state.lastFetch = true, now
    self:Spawn(function()
        local ok, names = pcall(function() return self:RealRemote(getter, "InvokeServer", "GetOwnedEmotes") end)
        if not self.Alive then return end
        local valid = ok and self:CaptureEmoteOwnership(names)
        if not valid then state.emotes.stale = true end
        local slotsOK, values = pcall(function() return self:RealRemote(slots, "InvokeServer") end)
        if not self.Alive then return end
        if slotsOK and type(values) == "table" then state.slots = table.clone(values) end
        state.fetching = false
        self:SnapshotInventories()
        self:ReconcileEarnedItems()
        local count, extra = 0, 0
        for category, data in pairs(state.inventories) do
            count += data.count
            for _, row in ipairs(self.Rows[category] or {}) do
                if not data.names[row.value] and self.Unlocks[category] then extra += 1 end
            end
        end
        local emotes = 0
        for _ in pairs(state.emotes.names) do emotes += 1 end
        if self.Unlocks.Emotes then
            for _, row in ipairs(self.Rows.Emotes) do if not state.emotes.names[row.key] then extra += 1 end end
        end
        self.Status.ownership = valid and string.format("Earned: %d items, %d emotes | client extras: %d", count, emotes, extra)
            or "Real emote read failed; waiting to refresh"
        if valid and self.Unlocks.Emotes then self:RefreshNativeEmotes() end
    end)
end

function R:RefreshSelectors()
    for category, control in pairs(self.Selectors or {}) do
        local selected = self.Selected and self.Selected[category]
        local options = {}
        for _, row in ipairs(self.Rows[category]) do options[#options + 1] = row.label end
        if #options == 0 then options = { "Catalog not available yet" } end
        pcall(function() control:Refresh(options) end)
        if selected and table.find(options, selected) then
            pcall(function() control:Set({ selected }) end)
        end
    end
end

function R:SelectedRow(category)
    local selection = self.Selected and self.Selected[category]
    for _, row in ipairs(self.Rows[category]) do
        if row.label == selection then return row end
    end
    return nil
end

function R:SpoofRow(category)
    if category == "Characters" then return self:FindRow(category, self.CharacterEquip.applied) end
    return self:SelectedRow(category)
end

-- Client cosmetics use the same Value objects as the game's storage, player
-- card and cutscene dispatchers. Each override keeps the latest real update.
R.CosmeticPaths = {
    Characters = { "CurrentCharacter" },
    Titles = { "DataFolder", "NameTag" },
    MVPs = { "DataFolder", "Banner" },
    Intros = { "DataFolder", "Opening" },
    Banners = { "DataFolder", "Thumbnail" },
}

function R:ReleaseValue(key)
    local record = self.ValuePatches[key]
    if not record then return end
    if record.connection then record.connection:Disconnect() end
    pcall(function()
        if record.read() == record.written then
            record.write(record.observed)
        end
    end)
    if self.ValueOwners[record.instance] == record then self.ValueOwners[record.instance] = nil end
    self.ValuePatches[key] = nil
end

function R:ReleaseValues(prefix)
    local keys = {}
    for key in pairs(self.ValuePatches) do
        if not prefix or string.sub(key, 1, #prefix) == prefix then keys[#keys + 1] = key end
    end
    for _, key in ipairs(keys) do self:ReleaseValue(key) end
end

function R:ForceValue(key, instance, desired, property, options)
    property = property or "Value"
    options = options or {}
    local attribute = options.attribute == true
    local record = self.ValuePatches[key]
    if record and (record.instance ~= instance or record.property ~= property or record.attribute ~= attribute) then
        self:ReleaseValue(key); record = nil
    end
    if not instance then return false end
    if not record then
        local function read()
            if attribute then return instance:GetAttribute(property) end
            return instance[property]
        end
        local function write(value)
            if attribute then instance:SetAttribute(property, value) else instance[property] = value end
        end
        local ok, original = pcall(read)
        if not ok then return false end
        record = { instance = instance, property = property, attribute = attribute,
            observed = original, desired = desired, read = read, write = write, passive = options.passive }
        self.ValuePatches[key] = record
        if property == "Value" and not attribute then self.ValueOwners[instance] = record end
        local signal = attribute and instance:GetAttributeChangedSignal(property) or instance:GetPropertyChangedSignal(property)
        record.connection = signal:Connect(function()
            if not self.Alive or record.writing then return end
            local value = record.read()
            if value == record.written then return end
            record.observed = value
            if record.passive then return end
            record.writing = true
            local success = pcall(record.write, record.desired)
            if success then record.written = record.desired end
            record.writing = false
        end)
    end
    local current = record.read()
    if current ~= record.written then record.observed = current end
    record.desired, record.writing = desired, true
    local ok = pcall(function() if current ~= desired then record.write(desired) end end)
    if ok then record.written = desired end
    record.writing = false
    return ok
end

function R:RealValue(instance)
    local record = instance and self.ValueOwners[instance]
    if record then return record.observed end
    return instance and instance.Value
end

function R:FindRow(category, selection)
    for _, row in ipairs(self.Rows[category] or {}) do
        if row.key == selection or row.value == selection or row.label == selection then return row end
    end
end

function R:ApplySpoof(category)
    local path = self.CosmeticPaths[category]
    if not path then return false end
    if not self.Spoofs[category] then self:ReleaseValues("Spoof:" .. category .. ":"); return false end
    if category == "Characters" and self.EquipPending then return false end
    local row = self:SpoofRow(category)
    if not row then
        if category == "Characters" and self.CharacterEquip.applied then self:SetSpoof(category, false) end
        return false
    end
    if self:IsRealOwned(row) then
        self:SetSpoof(category, false)
        local toggle = self.Controls["Spoof" .. category]
        if toggle then pcall(function() toggle:Set(false) end) end
        return false
    end
    local instance = at(Player, path)
    if not instance or not instance:IsA("StringValue") then return false end
    local ok = self:ForceValue("Spoof:" .. category .. ":Value", instance, row.value)
    local random = category == "MVPs" and "RandomMVP" or category == "Intros" and "RandomOpening"
    if random then
        self:ForceValue("Spoof:" .. category .. ":Random", at(Player, { "DataFolder", random }), false)
    end
    return ok
end

function R:ApplySpoofs()
    for category in pairs(self.CosmeticPaths) do self:ApplySpoof(category) end
end

function R:SetSpoof(category, enabled)
    if not self.CosmeticPaths[category] then return end
    self.Spoofs[category] = enabled == true
    self.Options["Spoof" .. category] = enabled == true
    if category == "Characters" and not enabled then
        self.CharacterEquip.applied = nil
        self.Status.character = "Using your real equipped character"
    end
    if category == "Banners" and not enabled then self:ReleaseValues("Menu:BannerNone") end
    if enabled and not self:SelectedRow(category) and self.Rows[category][1] then
        self.Selected[category] = self.Rows[category][1].label
        local control = self.Selectors and self.Selectors[category]
        if control then pcall(function() control:Set({ self.Selected[category] }) end) end
    end
    self:ApplySpoof(category)
    self:RefreshRequestHooks()
    if category == "Intros" then self:RefreshOpening() end
    if category == "Titles" then self:RefreshTitleDisplay() end
    if category == "Characters" then self:RefreshCharacterSkills(); self:RefreshRacePresentation() end
end

function R:EquipClientCharacter(selection)
    local row
    if selection ~= nil then row = self:FindRow("Characters", selection) else row = self:SelectedRow("Characters") end
    if not row then self:Notify("Character", "Pick a character first."); return false end
    if self:IsRealOwned(row) then self:Notify("Character", "You own this one. Use Equip Character to equip it normally."); return false end
    local value = child(Player, "CurrentCharacter")
    if not value or not value:IsA("StringValue") or self.EquipPending then return false end
    local unchanged = value.Value == row.value
    self.CharacterEquip.applied = row.value
    self:SetSpoof("Characters", true)
    if not self.Spoofs.Characters or value.Value ~= row.value then return false end
    local control = self.Controls.SpoofCharacters
    if control then pcall(function() control:Set(true) end) end
    self.Status.character = "Equipped locally: " .. row.value
    if unchanged then self:ReloadCharacterAnimations() end
    self:RefreshCharacterSkills(true)
    return true
end

function R:ReloadCharacterAnimations()
    local value = child(Player, "CurrentCharacter")
    local animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")
    if not value or not animator then return false end
    -- Client.Player reloadAnimations is the actual Value listener. Reuse it
    -- only on an explicit re-equip; browsing never invokes this callback.
    for _, connection in pairs(connections(value:GetPropertyChangedSignal("Value"))) do
        local fn = connectionFunction(connection)
        if fn and hasConstants(fn, { "CurrentCharacter", "WalkAnim", "SprintAnim", "IdleAnim", "LoadAnimation" }) then
            local values = upvalues(fn)
            if values and values[1] == Player and values[15] == animator then
                return pcall(fn)
            end
        end
    end
    return false
end

function R:EquipSelectedCharacter()
    local row = self:SelectedRow("Characters")
    if not row then self:Notify("Character", "Pick a character first."); return false end
    if self:IsRealOwned(row) then return self:EquipCharacter() end
    return self:EquipClientCharacter(row.value)
end

-- The native collection buttons send these raw keys, not their display names.
-- Keep a rejected local cosmetic selection in sync with the spoof dropdown.
function R:CosmeticRequest(object, method, args)
    local route = self.CosmeticRemotes[object]
    if not route then return false end
    local category, selection, operation = route.category, nil, nil
    if category == "Characters" and self.MenuServerEquip then return false end
    if route.method == "InvokeServer" and method == "InvokeServer"
        and (args[1] == "Equip" or (category == "Banners" and args[1] == "Unequip")) then
        operation, selection = args[1], args[2]
    elseif route.method == "FireServer" and method == "FireServer" then
        operation, selection = "Equip", args[1]
    else
        if (method == "FireServer" or method == "InvokeServer")
            and (self.Options.LocalMenuEquips or self.Unlocks[category] or self.Spoofs[category])
            and (args[1] == "Equip" or args[1] == "Unequip" or category == "Characters") then
            self.Status.menu = "Blocked a changed menu equip protocol"
            return true, false
        end
        return false
    end
    local row = type(selection) == "string" and self:FindRow(category, selection)
    if selection == "Random" and (category == "Intros" or category == "MVPs")
        and args.n == 2 and route.method == "InvokeServer" then
        self:SetSpoof(category, false)
        return false
    end
    if type(selection) == "string" and self:IsEarned(category, selection)
        and args.n == (route.method == "InvokeServer" and 2 or 1) then
        self:SetSpoof(category, false)
        local toggle = self.Controls["Spoof" .. category]
        if toggle then pcall(function() toggle:Set(false) end) end
        self.Status.menu = self.Categories[category].label .. " equip sent to the game"
        return false
    end
    if args.n ~= (route.method == "InvokeServer" and 2 or 1) or (not row and operation ~= "Unequip") then
        self.Status.menu = "Blocked unknown " .. category .. " equip; refresh the catalog"
        return true, false
    end
    if operation == "Unequip" then
        self:SetSpoof(category, false)
        self:ForceValue("Menu:BannerNone", at(Player, self.CosmeticPaths.Banners), "None")
        self.Status.menu = "Banner cleared locally"
        return true, true
    end
    if category == "Banners" then self:ReleaseValues("Menu:BannerNone") end
    self.Selected[category] = row.label
    if category == "Characters" then
        if not self:EquipClientCharacter(row.value) then return true, false end
    else
        self:SetSpoof(category, true)
    end
    local control = self.Selectors and self.Selectors[category]
    if control then pcall(function() control:Set({ row.label }) end) end
    local toggle = self.Controls["Spoof" .. category]
    if toggle then pcall(function() toggle:Set(true) end) end
    self.Status.menu = self.Categories[category].label .. " selected locally"
    return true, true
end

function R:RuntimeModule(key, instance, refreshed)
    local record = self.RuntimeModules[key]
    if record and record.instance == instance then
        if record.value then return record.value end
        if record.pending or os.clock() < record.retry then return nil end
    end
    if not instance or not instance:IsA("ModuleScript") then return nil end
    record = { instance = instance, pending = true, retry = os.clock() + 10 }
    self.RuntimeModules[key] = record
    self:Spawn(function()
        local ok, value = pcall(require, instance)
        if self.RuntimeModules[key] ~= record then return end
        record.pending = false
        if ok and (type(value) == "table" or type(value) == "function") then
            record.value = value
            refreshed()
        else
            self:Error("Native " .. key, value)
        end
    end)
    return nil
end

function R:TitlePacket(packet, row)
    local copy = table.clone(packet)
    local title = type(packet.Title) == "table" and table.clone(packet.Title) or nil
    if row and row.key ~= "Default" then
        title = title or {}
        title.Text = row.key
    elseif row or not title or type(title.Text) ~= "string" or title.Text == ""
        or (title.Text == "Default" and (type(title.Color) ~= "table" or not title.Color[1] or not title.Color[2])) then
        -- PlayerList supplies its complete native default only for a nil title.
        -- An empty table skips that fallback and reaches Text/Color assignments.
        title = nil
    end
    copy.Title = title
    return copy
end

function R:RefreshTitleDisplay()
    local state = self.TitleDisplay
    if not self.Spoofs.Titles then
        self:RestoreHooks("Titles")
        self:ReleaseValues("TitleUI:")
        if state.packet and state.update and state.active then
            pcall(state.update, Player.Name, state.packet)
        end
        state.active, state.lastKey = false, nil
        return
    end
    state.active = true
    local row = self:SelectedRow("Titles")
    if not row then return end
    local module = at(Player, { "PlayerGui", "Tab", "Client", "PlayerList" })
    if state.module ~= module then
        self:RestoreHooks("Titles")
        state.module, state.packet, state.update, state.styler = module, nil, nil, nil
    end
    local api = self:RuntimeModule("PlayerList", module, function() self:RefreshTitleDisplay() end)
    if type(api) == "table" and type(api.Update) == "function" then
        local record = self:HookFunction(api.Update, "Leaderboard title", function(original, name, packet, removed, ...)
            if name == Player.Name and type(packet) == "table" and not removed then
                state.packet = self:TitlePacket(packet)
                local selected = self:SelectedRow("Titles")
                if self.Spoofs.Titles and selected then
                    state.lastKey = selected.key
                    return original(name, self:TitlePacket(packet, selected), removed, ...)
                end
            end
            return original(name, packet, removed, ...)
        end, module, "Titles")
        state.update = record and record.original or api.Update
        if not state.styler then
            for _, fn in pairs(upvalues(api.Update) or {}) do
                if type(fn) == "function" and hasConstants(fn, { "Tags", "Gradient", "TextLabel", "RichText" }) then
                    state.styler = fn; break
                end
            end
        end
        if state.packet and state.lastKey ~= row.key then
            pcall(state.update, Player.Name, self:TitlePacket(state.packet, row))
            state.lastKey = row.key
        end
    end
    -- Existing rows may predate injection. Both visible title labels live
    -- here; the native packet update above handles subsequent row rebuilds.
    local holder = at(Player, { "PlayerGui", "Tab", "PlayerList", "Players", "List", Player.Name, "Info", "Title" })
    local shadow = child(holder, "Dropshadow")
    for index, label in ipairs({ shadow, child(shadow, "Title") }) do
        if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
            self:ForceValue("TitleUI:Text" .. index, label, tostring(row.data.Name or row.key), "Text")
            self:ForceValue("TitleUI:Rich" .. index, label, false, "RichText")
        end
    end
    local gradient = child(holder, "UIGradient")
    if gradient and state.styler then
        if state.styleKey ~= row.key or state.styleData ~= row.data then
            local sample = Instance.new("UIGradient")
            sample.Color = gradient.Color
            local ok = pcall(state.styler, sample, row.key)
            state.styleColor = ok and sample.Color or nil
            sample:Destroy()
            state.styleKey, state.styleData = row.key, row.data
        end
        if state.styleColor then self:ForceValue("TitleUI:Gradient", gradient, state.styleColor, "Color") end
    end
end

function R:StopOpeningAnimation()
    local track = self.Opening.track
    self.Opening.track = nil
    if self.Opening.ended then self.Opening.ended:Disconnect(); self.Opening.ended = nil end
    if track then pcall(function() track:Stop(0.1); track:Destroy() end) end
end

function R:OpeningAsset()
    local row = self:SelectedRow("Intros")
    local assets = at(ReplicatedStorage, { "Package", "Animations", "Opening" })
    local animation = row and child(assets, row.key)
    return animation and animation:IsA("Animation") and animation or nil, assets
end

function R:PlayOpeningAnimation(preview)
    local animation = self:OpeningAsset()
    local animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")
    if not animation or not animator then
        if preview then self:Notify("Opening", "Pick an opening with a loaded animation.") end
        return false
    end
    self:StopOpeningAnimation()
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    if not ok then self:Error("Opening animation", track); return false end
    self.Opening.track = track
    local played, failure = pcall(function()
        track.Looped = false
        track.Priority = Enum.AnimationPriority.Action4
        track:Play(0.1)
    end)
    if not played then self:StopOpeningAnimation(); self:Error("Opening playback", failure); return false end
    self.Opening.ended = track.Stopped:Connect(function()
        if self.Opening.track == track then self:StopOpeningAnimation() end
    end)
    self.Status.opening = (preview and "Animation preview: " or "Animation replaced: ") .. animation.Name
    return true
end

function R:RefreshOpening()
    local state = self.Opening
    if not self.Spoofs.Intros then
        self:RestoreHooks("Openings")
        if state.connection then state.connection:Disconnect(); state.connection = nil end
        state.animator = nil
        if state.enabled then self:StopOpeningAnimation(); self.Status.opening = "Off" end
        state.enabled = false
        return
    end
    state.enabled = true
    local base = at(Player, { "PlayerScripts", "Client", "Visuals", "Visuals", "Misc", "IntroCutscene" })
    if state.base ~= base then self:RestoreHooks("Openings"); state.base = base end
    local function refresh() if self.Alive then self:RefreshOpening() end end
    local native = self:RuntimeModule("OpeningDispatcher", base, refresh)
    if type(native) == "function" then
        self:HookFunction(native, "Opening dispatcher", function(original, userId, ...)
            if userId == Player.UserId and self.Spoofs.Intros then self:ApplySpoof("Intros") end
            return original(userId, ...)
        end, base, "Openings")
    end
    if base then
        for _, instance in ipairs(base:GetChildren()) do
            if instance:IsA("ModuleScript") then
                local value = self:RuntimeModule("Opening:" .. instance.Name, instance, refresh)
                if type(value) == "table" and type(value.Activate) == "function" then
                    self:HookFunction(value.Activate, "Opening " .. instance.Name, function(original, subject, ...)
                        if subject == Player and self.Spoofs.Intros then
                            local row = self:SelectedRow("Intros")
                            local selected = row and self.RuntimeModules["Opening:" .. row.key]
                            local activate = selected and selected.value and selected.value.Activate
                            if type(activate) == "function" then
                                self:ApplySpoof("Intros")
                                self.Status.opening = "Playing: " .. row.key
                                return inspectFunction(activate)(subject, ...)
                            end
                        end
                        return original(subject, ...)
                    end, instance, "Openings")
                end
            end
        end
    end
    local animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")
    if state.animator ~= animator then
        if state.connection then state.connection:Disconnect(); state.connection = nil end
        state.animator = animator
        if animator and animator.AnimationPlayed then
            -- A replicated/default opening track can outlive the Value change.
            -- Only replace known opening assets on our own Animator.
            state.connection = animator.AnimationPlayed:Connect(function(track)
                if not self.Alive or not self.Spoofs.Intros or animator ~= state.animator then return end
                local selected, assets = self:OpeningAsset()
                local played = track.Animation
                if not selected or not assets or not played then return end
                local id = tostring(played.AnimationId):match("%d+")
                if id == tostring(selected.AnimationId):match("%d+") then return end
                for _, animation in ipairs(assets:GetChildren()) do
                    if animation:IsA("Animation") and id and id == tostring(animation.AnimationId):match("%d+") then
                        if self:PlayOpeningAnimation(false) then track:Stop(0.05) end
                        return
                    end
                end
            end)
        end
    end
    if not native then self.Status.opening = "Waiting for the game's opening dispatcher"
    elseif not state.track and self.Status.opening:sub(1, 7) ~= "Playing" then
        local row = self:SelectedRow("Intros")
        self.Status.opening = "Ready: " .. (row and row.key or "pick an opening")
    end
end

function R:RefreshRequestHooks(force)
    local needed = force or self.Options.LocalMenuEquips or self.Unlocks.Emotes or self.Options.InfiniteSpurts or self.Options.InfiniteUlt
    local cosmetics, methods = {}, {}
    for _, route in ipairs({
        { "Characters", "FireServer", { "remotes", "SaveCharacter" } },
        { "Titles", "InvokeServer", { "Package", "Remotes", "NameTagMain" } },
        { "Intros", "InvokeServer", { "Package", "Remotes", "IntroMain" } },
        { "Intros", "InvokeServer", { "remotes", "IntroMain" } },
        { "MVPs", "InvokeServer", { "Package", "Remotes", "MVPMain" } },
        { "Banners", "InvokeServer", { "remotes", "Banner" } },
    }) do
        local remote = at(ReplicatedStorage, route[3])
        local expected = route[2] == "InvokeServer" and "RemoteFunction" or "RemoteEvent"
        if remote then cosmetics[remote] = { category = route[1], method = route[2] } end
        if remote and remote:IsA(expected) then
            methods[route[2]] = remote
        end
        if self.Unlocks[route[1]] or self.Spoofs[route[1]] then needed = true end
    end
    self.CosmeticRemotes = cosmetics
    if not needed then self:RestoreHooks("Requests"); return end
    self:InstallEmoteNamecall()
    local emotes = at(ReplicatedStorage, { "Package", "Animations", "Emotes", "Remotes" })
    local invoke = methods.InvokeServer or child(emotes, "Getter") or child(emotes, "EmotesGet")
    local fire = methods.FireServer or at(ReplicatedStorage, { "remotes", "Spurt" }) or child(emotes, "ComunicatorSet")
    for _, item in ipairs({ { invoke, "InvokeServer" }, { fire, "FireServer" } }) do
        if item[1] then
            local method = item[2]
            self:HookFunction(item[1][method], "Client " .. method, function(original, object, ...)
                return self:EmoteRequest(original, object, method, ...)
            end, nil, "Requests")
        end
    end
    self.Status.menu = self.Hooks.EmoteNamecall and "Earned equips use the game | client extras stay local"
        or "Menu namecall hook unavailable"
end

function R:UpdateCharacterInfo()
    if not self.CharacterInfoControl then return end
    local row = self:SelectedRow("Characters")
    local content = "Pick a character to see its kit."
    if row then
        local data = row.data
        local lines = { tostring(data.DisplayName or data.Name or row.key),
            "Rarity: " .. tostring(data.Rarity or "Unknown") .. " | Style: " .. tostring(data.RunnerType or "Unknown") }
        for _, field in ipairs({ "Ability", "Zone", "Passive" }) do
            local value = data[field]
            if type(value) == "table" then
                value = value.Name or value.Title or value.Description
            end
            if type(value) == "string" and value ~= "" then lines[#lines + 1] = field .. ": " .. value end
        end
        content = table.concat(lines, "\n")
    end
    pcall(function() self.CharacterInfoControl:Set({ Title = "Character kit", Content = content }) end)
end

-- The emote wheel asks Getter for its owned list and EmotesGet for eight
-- named slots. Local replies let the existing picker and both pages work.
function R:EmoteNames()
    local names, seen = {}, {}
    for name in pairs(self.Ownership.emotes.names) do names[#names + 1] = name; seen[name] = true end
    for _, row in ipairs(self.Rows.Emotes) do
        if not seen[row.key] then names[#names + 1] = row.key; seen[row.key] = true end
    end
    table.sort(names)
    return names
end

function R:GetEmoteSlots(native)
    local result, folder = native and table.clone(native) or {}, child(Player, "Emotes")
    for slot = 1, 8 do
        local key = tostring(slot)
        local value = child(folder, key)
        result[key] = self.EmoteSlots[key] or result[key] or self:RealValue(value) or self.Ownership.slots[key] or ""
    end
    return result
end

function R:AssignEmoteSlot(slot, name, page)
    local number = tonumber(slot)
    if not number or number % 1 ~= 0 or number < 1 or number > 8 or type(name) ~= "string"
        or (page ~= nil and page ~= "Emotes") then return false end
    -- The native writer has already converted page two into absolute slots 5–8.
    -- Its Page field names the "Emotes" data folder, not the visible wheel page.
    local row = self:FindRow("Emotes", name)
    if row then name = row.key end
    if name ~= "" and not self:EmoteDataReady() and not self:IsEarned("Emotes", name) and not self:ReadEmoteOwnership() then return false end
    local key = tostring(number)
    if name == "" or self:IsEarned("Emotes", name) then
        local getter = at(ReplicatedStorage, { "Package", "Animations", "Emotes", "Remotes", "Getter" })
        if not getter then return false end
        local result = table.pack(self:RealRemote(getter, "InvokeServer", "SetEmote", { Slot = key, EmoteName = name, Page = "Emotes" }))
        if result[1] == true then
            self.EmoteSlots[key] = nil
            self:ReleaseValue("EmoteSlot:" .. key)
            self.Ownership.slots[key] = name
        end
        return table.unpack(result, 1, result.n)
    end
    if not self.Unlocks.Emotes then return false end
    if name ~= "" then
        if not row then return false end
    end
    self.EmoteSlots[key] = name
    self:ForceValue("EmoteSlot:" .. key, at(Player, { "Emotes", key }), name)
    return true
end

function R:EmoteRequest(original, object, method, ...)
    if not self.Alive then return original(object, ...) end
    if (self.RaceActions.ultimateThread == coroutine.running() or self.RacePresentation.localThreads[coroutine.running()])
        and (method == "FireServer" or method == "InvokeServer")
        and typeof(object) == "Instance" and (object:IsA("RemoteEvent") or object:IsA("RemoteFunction")) then
        return false
    end
    local args, bridge = table.pack(...), self.EmoteBridge
    local handled, response = self:CosmeticRequest(object, method, args)
    if handled then return response end
    if self.Options.InfiniteSpurts and method == "FireServer" and args.n == 0
        and object == at(ReplicatedStorage, { "remotes", "Spurt" }) then
        self:QueueSpurtReplay()
    end
    if self.Options.InfiniteUlt and method == "FireServer" and args.n == 0
        and object == at(ReplicatedStorage, { "remotes", "Ultimate" }) then self:QueueUltimateReplay() end
    if object == bridge.getter and method == "InvokeServer" then
        if args[1] == "GetOwnedEmotes" and args.n == 1 then
            if self.Unlocks.Emotes and self:EmoteDataReady() then return self:EmoteNames() end
            local result = table.pack(self:RealRemote(object, method, ...))
            if self:CaptureEmoteOwnership(result[1]) then
                self:ReconcileEarnedItems()
                if self.Unlocks.Emotes then result[1] = self:EmoteNames() end
            end
            return table.unpack(result, 1, result.n)
        end
        if self.Unlocks.Emotes and args[1] == "SetEmote" then
            if args.n ~= 2 or type(args[2]) ~= "table" then return false end
            return self:AssignEmoteSlot(args[2].Slot, args[2].EmoteName, args[2].Page)
        end
    elseif object == bridge.slots and method == "InvokeServer" and args.n == 0 then
        local result = table.pack(self:RealRemote(object, method))
        if type(result[1]) == "table" then
            self.Ownership.slots = table.clone(result[1])
            if self.Unlocks.Emotes then result[1] = self:GetEmoteSlots(result[1]) end
        end
        return table.unpack(result, 1, result.n)
    elseif object == bridge.play and method == "FireServer" and args[1] == "PlayEmote" then
        if self.Unlocks.Emotes and (args.n ~= 2 or type(args[2]) ~= "string") then return false end
        local request = { name = args[2], time = os.clock(), native = true }
        self.LastEmoteRequest = request
        if not self.Unlocks.Emotes or self:IsEarned("Emotes", args[2]) then
            self:StopEmote()
            return self:RealRemote(object, method, ...)
        end
        local cancelled = self.EmoteCancelSerial or 0
        self:Spawn(function()
            if (self.EmoteCancelSerial or 0) == cancelled and self.LastEmoteRequest == request then self:PlayEmote(args[2], request) end
        end)
        return
    end
    return original(object, ...)
end

function R:InstallEmoteNamecall()
    local key = "EmoteNamecall"
    if self.Hooks[key] or not Cap.hookmeta or not Cap.namecall then return end
    local record = { target = key, scope = "Client requests", family = "Requests", metamethod = "__namecall", active = true }
    local replacement = function(object, ...)
        if not record.active or not self.Alive then return record.original(object, ...) end
        return self:EmoteRequest(record.original, object, Cap.namecall(), ...)
    end
    if Cap.newc then
        local ok, wrapped = pcall(Cap.newc, replacement)
        if ok and type(wrapped) == "function" then replacement = wrapped end
    end
    local ok, original = pcall(Cap.hookmeta, game, "__namecall", replacement)
    if ok and type(original) == "function" then
        record.original = original; self.Hooks[key] = record
    else
        self.QTE.hookFailures[record.scope] = tostring(original)
    end
end

function R:RefreshNativeEmotes()
    if not Cap.gc and not Cap.connections then return end
    local now = os.clock()
    if self.LastEmoteRefresh and now - self.LastEmoteRefresh < 0.2 then
        if not self.EmoteRefreshPending then
            self.EmoteRefreshPending = true
            self:Spawn(function()
                task.wait(0.21)
                self.EmoteRefreshPending = false
                self:RefreshNativeEmotes()
            end)
        end
        return
    end
    self.LastEmoteRefresh = now
    self:Spawn(function()
        local handler = at(Player, { "PlayerGui", "Emotes", "Handler" })
        if not handler then return end
        local owned, slots, seen = nil, nil, {}
        local function inspect(fn)
            if type(fn) ~= "function" or seen[fn] then return end
            seen[fn] = true
            if type(fn) == "function" then
                local own = false
                if Cap.fenv then
                    local success, environment = pcall(Cap.fenv, fn)
                    own = success and type(environment) == "table" and environment.script == handler
                end
                if own and not owned and hasConstants(fn, { "GetOwnedEmotes" }) == true then owned = fn end
                if own and not slots and hasConstants(fn, { "InvokeServer", "NecoArc", "tonumber" }) == true then
                    for _, value in pairs(upvalues(fn) or {}) do
                        if value == self.EmoteBridge.slots then slots = fn; break end
                    end
                end
                if own and hasConstants(fn, { "PlayEmote", "CutsceneOn", "FireServer" }) == true then
                    local values = upvalues(fn)
                    if values and values[6] == self.EmoteBridge.play and type(values[7]) == "function" then
                        self.EmoteBridge.closeWheel = values[7]
                    end
                end
            end
        end
        local owner = at(Player, { "Emotes", "OwnerEmotes" })
        local queue = {}
        if owner then
            for _, connection in pairs(connections(owner:GetPropertyChangedSignal("Value"))) do
                local fn = connectionFunction(connection)
                if fn then queue[#queue + 1] = { fn, 0 } end
            end
        end
        local index = 1
        while index <= #queue and index <= 100 and not (owned and slots) do
            local item = queue[index]; index += 1
            if not seen[item[1]] then
                inspect(item[1])
                if item[2] < 3 then
                    for _, fn in pairs(upvalues(item[1]) or {}) do
                        if type(fn) == "function" and not seen[fn] then queue[#queue + 1] = { fn, item[2] + 1 } end
                    end
                end
            end
        end
        if not (owned and slots) and Cap.gc then
            local ok, objects = pcall(Cap.gc, false)
            if ok and type(objects) == "table" then
                for _, fn in pairs(objects) do inspect(fn); if owned and slots then break end end
            end
        end
        self.EmoteBridge.refreshSlots = slots
        if owned then pcall(owned) end
        if slots then pcall(slots) end
    end)
end

function R:RefreshEmoteBridge(force)
    local bridge = self.EmoteBridge
    local base = at(ReplicatedStorage, { "Package", "Animations", "Emotes", "Remotes" })
    local getter, slots, play = child(base, "Getter"), child(base, "EmotesGet"), child(base, "ComunicatorSet")
    local handler = at(Player, { "PlayerGui", "Emotes", "Handler" })
    local changed = not bridge.enabled or bridge.getter ~= getter or bridge.slots ~= slots
        or bridge.play ~= play or bridge.handler ~= handler
    if bridge.handler ~= handler then bridge.refreshSlots, bridge.closeWheel = nil, nil end
    bridge.handler, bridge.getter, bridge.slots, bridge.play = handler, getter, slots, play
    self:RefreshRequestHooks()
    if not self.Unlocks.Emotes then
        if bridge.enabled then
            bridge.enabled = false
            self:StopEmote()
            self:ReleaseValues("EmoteSlot:")
            self:ReleaseValues("EmoteUI:")
            table.clear(self.EmoteSlots)
            self:RefreshNativeEmotes()
        end
        self.Status.emotes = "Off"
        return
    end
    bridge.enabled = true
    local switch = at(Player, { "PlayerGui", "Emotes", "ImageLabel", "Switch" })
    if switch then
        self:ForceValue("EmoteUI:Access", switch, true, "HasAccess", { attribute = true })
        local saved = self.ValuePatches["EmoteUI:Switch"]
        if not saved or saved.instance ~= switch then
            -- The picker hides this button temporarily. Preserve that behavior
            -- rather than forcing Visible on every frame.
            self:ForceValue("EmoteUI:Switch", switch, true, "Visible", { passive = true })
        end
    end
    for slot, name in pairs(self.EmoteSlots) do
        self:ForceValue("EmoteSlot:" .. slot, at(Player, { "Emotes", slot }), name)
    end
    local hooked = self.Hooks.EmoteNamecall ~= nil or (getter and self.Hooks[getter.InvokeServer] ~= nil)
    self.Status.emotes = getter and hooked
        and (#self.Rows.Emotes .. " emotes | picker hooked") or "Use the Emotes tab; wheel hook unavailable"
    if changed or force then self:RefreshNativeEmotes() end
end

local function animationId(id)
    if type(id) ~= "number" and type(id) ~= "string" then return nil end
    if type(id) == "number" and (not finite(id) or id <= 0 or id % 1 ~= 0) then return nil end
    local text = type(id) == "number" and string.format("%.0f", id) or id
    return text:match("^rbxassetid://%d+$") and text or (text:match("^%d+$") and "rbxassetid://" .. text or nil)
end

function R:UpdateEmotePlayback()
    if self.EmoteTrack then
        self.EmoteTrack.Looped = self.Options.EmoteLoop
        self.EmoteTrack:AdjustSpeed(self.Options.EmoteSpeed)
    end
    if self.EmoteSound then
        self.EmoteSound.Volume = (self.EmoteBaseVolume or 1) * self.Options.EmoteVolume
    end
end

function R:PlayLocalEmote(row)
    if row and (not self:EmoteDataReady() or self:IsEarned("Emotes", row.key)) then return self:PlayEmote(row.key) end
    local humanoid = self.Humanoid
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    local id = row and animationId(row.data.MainAnimation or row.data.IdleAnimation)
    if not row or not animator or not id then self:Notify("Emote", "Pick an emote while your character is loaded."); return false end
    if humanoid.Health <= 0 or humanoid.Jump or humanoid.MoveDirection.Magnitude > 0.05
        or child(game:GetService("Lighting"), "CutsceneOn") then return false end
    if child(self.Character, "PlayingEmote") and not self.EmoteMarker then return false end
    if self.EmoteName == row.key then self:StopEmote(); return true end
    self:StopEmote()
    local animation = Instance.new("Animation"); animation.AnimationId = id
    animation:SetAttribute("RyuLocalPreview", true)
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    if not ok then animation:Destroy(); self:Error("Emote", track); return false end
    self.EmoteAnimation, self.EmoteTrack = animation, track
    self.EmoteName, self.EmoteCharacter, self.EmoteHumanoid = row.key, self.Character, humanoid
    if self.Character and not child(self.Character, "PlayingEmote") then
        local marker = Instance.new("BoolValue")
        marker.Name, marker.Value = "PlayingEmote", true
        marker:SetAttribute("RyuLocalPreview", true)
        self.EmoteMarker = marker; marker.Parent = self.Character
    end
    pcall(function() track.Priority = Enum.AnimationPriority.Action4 end)
    track.Looped = self.Options.EmoteLoop
    track:Play(0.15); track:AdjustSpeed(self.Options.EmoteSpeed)
    if track.Stopped then
        self.EmoteEndedConnection = track.Stopped:Connect(function()
            if self.EmoteTrack == track then self:StopEmote() end
        end)
    end
    self.EmoteConnections = {}
    for _, property in ipairs({ "MoveDirection", "Jump", "Health" }) do
        self.EmoteConnections[#self.EmoteConnections + 1] = humanoid:GetPropertyChangedSignal(property):Connect(function()
            self:TickEmote()
        end)
    end
    local music = row.data.Music or row.data.IdleMusic
    local soundId = type(music) == "table" and animationId(music.id)
    if soundId and self.Root then
        local sound = Instance.new("Sound")
        local properties = type(music.properties) == "table" and music.properties or {}
        sound.SoundId = soundId
        sound.Looped = properties.Looped ~= false
        self.EmoteBaseVolume = finite(properties.Volume) and properties.Volume or 1
        sound.Volume = self.EmoteBaseVolume * self.Options.EmoteVolume
        for _, key in ipairs({ "PlaybackSpeed", "RollOffMaxDistance", "RollOffMinDistance", "TimePosition" }) do
            if finite(properties[key]) then pcall(function() sound[key] = properties[key] end) end
        end
        sound.Parent = self.Root; self.EmoteSound = sound; sound:Play()
    end
    return true
end

function R:PlayEmote(selection, nativeRequest)
    local row = type(selection) == "table" and selection or self:FindRow("Emotes", selection)
    local key = row and row.key or selection
    if type(key) ~= "string" or key == "" then return false end
    local character, cancelled = self.Character, self.EmoteCancelSerial or 0
    if not self:EmoteDataReady() and not self:IsEarned("Emotes", key) and not self:ReadEmoteOwnership() then return false end
    if not self.Alive or self.Character ~= character or (self.EmoteCancelSerial or 0) ~= cancelled then return false end
    self.LastEmoteRequest = nativeRequest or { name = key, time = os.clock() }
    if self:IsEarned("Emotes", key) then
        local remote = at(ReplicatedStorage, { "Package", "Animations", "Emotes", "Remotes", "ComunicatorSet" })
        if not remote then return false end
        self:StopEmote()
        self:RealRemote(remote, "FireServer", "PlayEmote", key)
        return true
    end
    return row and self:PlayLocalEmote(row) or false
end

function R:TickEmote()
    if not self.EmoteTrack then return end
    local humanoid, root = self.EmoteHumanoid, self.Root
    if not self.Alive or self.EmoteCharacter ~= self.Character or humanoid ~= self.Humanoid
        or not humanoid or not humanoid.Parent or humanoid.Health <= 0 or humanoid.Jump
        or humanoid.MoveDirection.Magnitude > 0.05 or not root or not root.Parent or root.Anchored
        or child(game:GetService("Lighting"), "CutsceneOn") then self:StopEmote(); return end
    local velocity = root.AssemblyLinearVelocity
    if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 3 then self:StopEmote() end
end

function R:EmoteKeySlot(number, wheelOpen)
    if wheelOpen and number <= 4 then
        -- refreshSlots U3 is the native page; sUNC indexes it as upvalue 4.
        local values = self.EmoteBridge.refreshSlots and upvalues(self.EmoteBridge.refreshSlots)
        if not values or values[1] ~= self.EmoteBridge.slots or (values[4] ~= 1 and values[4] ~= 2) then return nil end
        if values[4] == 2 then number += 4 end
    end
    return tostring(number)
end

function R:EmoteInput(input, processed)
    if not self.Alive then return end
    local ok, focused = pcall(function() return UserInputService:GetFocusedTextBox() end)
    if ok and focused then return end
    local key = input.KeyCode and input.KeyCode.Name
    if not key then return end
    if table.find({ "W", "A", "S", "D", "Q", "E", "Up", "Down", "Left", "Right", "Space", "LeftShift", "RightShift",
        "Escape", "Backspace", "ButtonA", "ButtonB", "ButtonL2" }, key) then
        if not processed or key == "Escape" or key == "Backspace" then self:StopEmote() end
        return
    end
    if not self.Options.EmoteHotkeys or not self.Unlocks.Emotes then return end
    local names = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight" }
    local number = table.find(names, key) or table.find(names, (key:gsub("^Keypad", "")))
    if not number then return end
    local wheel = at(Player, { "PlayerGui", "Emotes" })
    local image = child(wheel, "ImageLabel")
    local wheelOpen = wheel and wheel.Enabled ~= false and image and image.Visible == true
    if processed and not wheelOpen then return end
    local slot = self:EmoteKeySlot(number, wheelOpen)
    local name = self:GetEmoteSlots()[slot]
    if wheelOpen and number <= 4 and not slot then
        for _, frame in ipairs(image:GetDescendants()) do
            if frame.Name == tostring(number) then
                local displayed = frame:GetAttribute("EmoteKey")
                if type(displayed) == "string" and displayed ~= "" then name = displayed; break end
            end
        end
    end
    if type(name) ~= "string" or name == "" then return end
    local pressed, character, cancelled = os.clock(), self.Character, self.EmoteCancelSerial or 0
    self:Spawn(function()
        -- Let the wheel's own callback run first, including its CAS binding.
        task.wait()
        if self.Character ~= character or (self.EmoteCancelSerial or 0) ~= cancelled
            or (self.LastEmoteRequest and (self.LastEmoteRequest.time >= pressed
                or (self.LastEmoteRequest.native and self.LastEmoteRequest.time >= pressed - 0.075))) then return end
        if self:PlayEmote(name) and wheelOpen then
            if self.EmoteBridge.closeWheel then pcall(self.EmoteBridge.closeWheel)
            elseif image.Parent then image.Visible = false end
        end
    end)
end

-- Native RequestAbility takes aimData and an optional Tap/Hold variant.
-- Neither Spurt nor Ultimate takes a character argument in this client.
local SkillActorPaths = {
    Ability = { { "Ability", "Animation" }, { "Ability" }, { "Dash" }, { "dash" }, { "Normal" }, { "Roll" },
        { "Spin" }, { "Overtake1" }, { "Ability", "Jump" } },
    Startup = { { "Ability", "Startup" }, { "Startup" }, { "startup" }, { "Start" } },
    Running = { { "Ability", "Run" }, { "Run" }, { "Running" }, { "Boost" } },
    Ultimate = { { "Ultimate", "user" }, { "Ultimate", "Animation" }, { "Ult", "user" }, { "Ult", "Anims", "Player" },
        { "Zone", "User" }, { "Zone", "Anims", "Player" }, { "Zone", "Animations", "User" },
        { "AirGrooveChar" }, { "user" }, { "userwin" }, { "userlose" }, { "ZoneCutscene" },
        { "Cutscene", "Player" }, { "Player" }, { "Zone" }, { "Barou", "User" }, { "Fracture", "user" },
        { "SecondVariant", "user" }, { "SecondVariant", "userRoom" }, { "Ultimate", "user1" } },
}

-- These native kits reuse another character's assets in the supplied build.
-- Keep the alias out of visual-module routing: their argument layouts differ.
local SharedSkillAssets = { ["Haru Urara Evil"] = "Haru Urara", ["Twin Turbo"] = "Silence Suzuka", ["A Train"] = "Silence Suzuka" }

function R:CharacterAsset(root, row)
    return row and (child(root, row.value) or child(root, row.key))
end

function R:FindSkillDispatcher()
    local owner = at(Player, { "PlayerScripts", "Client", "Visuals" })
    local folder = child(owner, "Visuals")
    if not owner or not folder or not Cap.constants or not (Cap.upvalues or Cap.getupvalue) then return nil end
    local function matches(fn)
        if type(fn) ~= "function" or not hasConstants(fn, { "CurrentCharacter", "Ability", "Ultimate", "VisualEffect", "Misc" }) then return false end
        local values = upvalues(fn)
        local player, visuals = false, false
        for _, value in pairs(values or {}) do
            if value == Player then player = true end
            if value == folder then visuals = true end
        end
        return player and visuals
    end
    local state = self.SkillPresentation
    local remote = at(ReplicatedStorage, { "Package", "Remotes", "Visuals" })
    state.detached = state.detached or setmetatable({}, { __mode = "k" })
    if state.binding == "Visuals event" and state.dispatcher then
        if state.owner == owner and state.remote == remote and connected(state.connection)
            and connectionFunction(state.connection) == state.wrapper and matches(state.dispatcher) then return state.dispatcher end
        state.detached[state.dispatcher] = true
    end
    state.connection, state.wrapper, state.remote, state.binding = nil, nil, nil, nil
    -- MWorks.Remote.ConnectRemote captures the remote folder, not a callback
    -- registry. Its OnClientEvent wrapper captures the real handler as U0.
    local queue, seen, cursor = {}, {}, 1
    if remote and remote:IsA("RemoteEvent") then
        for _, connection in pairs(connections(remote.OnClientEvent)) do
            local wrapper = connectionFunction(connection)
            if wrapper then queue[#queue + 1] = { wrapper, 0, connection, wrapper } end
        end
    end
    while cursor <= #queue and cursor <= 120 do
        local item = queue[cursor]; cursor += 1
        local fn = item[1]
        if not seen[fn] then
            seen[fn] = true
            if matches(fn) then
                state.owner, state.remote, state.connection, state.wrapper = owner, remote, item[3], item[4]
                state.binding, state.detached[fn] = "Visuals event", nil
                return fn
            end
            if item[2] < 4 then
                for _, value in pairs(upvalues(fn) or {}) do
                    if type(value) == "function" and not seen[value] and #queue < 120 then
                        queue[#queue + 1] = { value, item[2] + 1, item[3], item[4] }
                    end
                end
            end
        end
    end
    if Cap.gc and Cap.fenv then
        local ok, objects = pcall(Cap.gc, false)
        if ok and type(objects) == "table" then
            for _, fn in pairs(objects) do
                if not state.detached[fn] and matches(fn) then
                    local success, environment = pcall(Cap.fenv, inspectFunction(fn))
                    if success and environment and environment.script == owner then
                        state.owner, state.binding = owner, "GC"
                        return fn
                    end
                end
            end
        end
    end
end

function R:RealSkillModule(action)
    local actual = self:RealValue(child(Player, "CurrentCharacter"))
    local row = self:FindRow("Characters", actual) or (type(actual) == "string" and { value = actual, key = actual })
    local root = at(Player, { "PlayerScripts", "Client", "Visuals", "Visuals" })
    local instance = child(self:CharacterAsset(root, row), action) or child(child(root, "Misc"), action)
    if not instance or not instance:IsA("ModuleScript") then return nil end
    local cache = self.SkillPresentation.modules
    if type(cache[instance]) == "function" then return cache[instance] end
    -- This is the same require and full argument tuple as the native dispatcher.
    -- Cross-character module arguments are never manufactured.
    local ok, fn = pcall(require, instance)
    if ok and type(fn) == "function" then cache[instance] = fn; return fn end
end

function R:SkillAnimationAssets(row, util)
    local roots = {}
    for _, name in ipairs({ "Animations", "ClientAssets" }) do
        local parent = at(ReplicatedStorage, { "Package", name })
        local own = self:CharacterAsset(parent, row)
        if own then roots[#roots + 1] = { asset = own } end
        local alias = row and SharedSkillAssets[row.value]
        local shared = alias and child(parent, alias)
        if shared and shared ~= own then
            roots[#roots + 1] = { asset = shared, ultimateOnly = row.value ~= "Haru Urara Evil" }
        end
    end
    local result = {}
    for role, paths in pairs(SkillActorPaths) do
        result[role] = {}
        local seen = {}
        for _, path in ipairs(paths) do
            for _, root in ipairs(roots) do
                local asset = (not root.ultimateOnly or role == "Ultimate") and at(root.asset, path)
                if asset and not seen[asset] and asset:IsA("Animation") then
                    seen[asset] = true
                    result[role][#result[role] + 1] = asset
                elseif asset and not seen[asset] and asset:IsA("KeyframeSequence") and util and type(util.TempAnimation) == "function" then
                    seen[asset] = true
                    local ok, animation = pcall(util.TempAnimation, asset)
                    if ok and typeof(animation) == "Instance" and animation:IsA("Animation") then
                        result[role][#result[role] + 1] = animation
                    end
                end
            end
        end
    end
    return result
end

function R:SkillAnimationKey(animation)
    local id = animation and animation.AnimationId
    if type(id) ~= "string" or id == "" then return nil end
    return id:match("^rbxassetid://(%d+)$") or id:match("[?&]id=(%d+)") or id
end

function R:StopSkillMirror(original, restore)
    local state = self.SkillPresentation
    local pair = state.mirrors[original]
    if not pair then return end
    state.mirrors[original] = nil
    if not pair.counted and self.Alive and self.Options.SpoofSkillAnimations and self.Spoofs.Characters then
        state.blocked[pair.target] = os.clock() + 15
        self.Status.skillAnimations = "Selected asset did not become ready; native animation retained"
    end
    for _, connection in ipairs(pair.connections) do pcall(function() connection:Disconnect() end) end
    if restore then
        pcall(function()
            if original.IsPlaying and original.WeightTarget <= 0.001 then original:AdjustWeight(pair.weight, 0.1) end
        end)
    end
    pcall(function() pair.track:Stop(0.1); pair.track:Destroy() end)
    state.ownTracks[pair.track] = nil
end

function R:ClearSkillMirrors()
    for original in pairs(self.SkillPresentation.mirrors) do self:StopSkillMirror(original, true) end
end

function R:SkillTrackPlayed(original)
    local state = self.SkillPresentation
    if state.starting or state.ownTracks[original] or state.mirrors[original] or not self.Alive
        or self.RacePresentation.scenesInFlight > 0
        or not self.Options.SpoofSkillAnimations or not self.Spoofs.Characters
        or not self.Character or not child(self.Character, "InfoPlaying")
        or not self.Humanoid or self.Humanoid.Health <= 0 or child(self.Character, "PlayingEmote") then return end
    local ok, animation = pcall(function() return original.Animation end)
    if not ok or not animation or animation:GetAttribute("RyuLocalPreview") then return end
    local key = self:SkillAnimationKey(animation)
    local target = state.map[key]
    if not target or self:SkillAnimationKey(target) == key then return end
    local targetKey = self:SkillAnimationKey(target)
    if not targetKey or not state.routingReady then return end
    if (state.blocked[targetKey] or 0) > os.clock() then return end
    local weight = original.WeightTarget
    if finite(weight) and weight <= 0.001 then return end
    local animator = self.Humanoid:FindFirstChildOfClass("Animator")
    if animator ~= state.animator then return end
    -- AnimationPlayed covers NAMECALL, legacy Humanoid loading and tracks
    -- cached before this script ran. The original track keeps its markers,
    -- native duration and stop lifecycle; only its visible weight is replaced.
    state.starting = true
    local loaded, track = pcall(function() return animator:LoadAnimation(target) end)
    if not loaded or not track then
        state.starting = false
        state.blocked[targetKey] = os.clock() + 15
        self.Status.skillAnimations = "Selected animation could not load; the native animation is unchanged"
        return
    end
    state.ownTracks[track] = true
    local pair = { track = track, character = self.Character, target = targetKey,
        weight = finite(weight) and weight or 1, started = os.clock(), connections = {} }
    state.mirrors[original] = pair
    local played = pcall(function()
        track.Priority, track.Looped = original.Priority, original.Looped
        track:Play(0.05, pair.weight, original.Speed)
    end)
    state.starting = false
    if not played then self:StopSkillMirror(original, true); state.blocked[targetKey] = os.clock() + 15; return end
    for _, signal in ipairs({ original.Stopped, original.Ended }) do
        if signal then pair.connections[#pair.connections + 1] = signal:Connect(function() self:StopSkillMirror(original, true) end) end
    end
    state.lastSource, state.lastTarget = key, targetKey
    self.Status.skillAnimations = "Loading the equipped character's animation"
    self:TickSkillAnimations()
end

function R:TickSkillAnimations()
    local state = self.SkillPresentation
    for original, pair in pairs(state.mirrors) do
        local valid = self.Alive and self.Options.SpoofSkillAnimations and self.Spoofs.Characters
            and self.Character == pair.character and self.Humanoid and self.Humanoid.Health > 0
            and child(self.Character, "InfoPlaying") and not child(self.Character, "PlayingEmote")
        local ok, playing = pcall(function() return original.IsPlaying end)
        if not valid or not ok or not playing then self:StopSkillMirror(original, true)
        else
            local synced = pcall(function()
                local mirror = pair.track
                if mirror.Length <= 0 then
                    if os.clock() - pair.started > 2.5 then
                        state.blocked[pair.target] = os.clock() + 15
                        self:StopSkillMirror(original, true)
                        self.Status.skillAnimations = "Selected asset did not load; native animation restored"
                    end
                    return
                end
                if not mirror.IsPlaying then
                    self:StopSkillMirror(original, true)
                    self.Status.skillAnimations = "Selected track stopped; native animation retained"
                    return
                end
                if not pair.counted then
                    pair.counted = true
                    state.swaps += 1
                    local row = self:SpoofRow("Characters")
                    self.Status.skillAnimations = "Playing " .. (row and row.value or "equipped") .. " animation | confirmed swaps: " .. state.swaps
                end
                local requested = original.WeightTarget
                if finite(requested) and requested > 0.001 then pair.weight = requested end
                original:AdjustWeight(0, 0.05); pair.hidden = true
                mirror.Priority, mirror.Looped = original.Priority, original.Looped
                local scale = original.Length > 0 and mirror.Length / original.Length or 1
                mirror:AdjustSpeed(original.Speed * scale)
                mirror:AdjustWeight(pair.weight, 0.05)
                local position = original.TimePosition * scale
                if mirror.Looped then position %= mirror.Length else position = math.clamp(position, 0, mirror.Length) end
                if math.abs(mirror.TimePosition - position) > 0.12 then mirror.TimePosition = position end
            end)
            if not synced then self:StopSkillMirror(original, true) end
        end
    end
end

function R:BindSkillAnimator(animator)
    local state = self.SkillPresentation
    if state.playbackAnimator == animator and state.animationConnection then return end
    if state.animationConnection then state.animationConnection:Disconnect(); state.animationConnection = nil end
    self:ClearSkillMirrors()
    state.playbackAnimator = animator
    if animator and animator.AnimationPlayed then
        state.animationConnection = animator.AnimationPlayed:Connect(function(track)
            if self.Alive and state.playbackAnimator == animator then self:SkillTrackPlayed(track) end
        end)
    end
end

function R:ScanPlayingSkills()
    local animator = self.SkillPresentation.animator
    if not animator then return end
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if ok then for _, track in ipairs(tracks) do self:SkillTrackPlayed(track) end end
end

function R:BindSkillModuleRoutes(row)
    local state = self.SkillPresentation
    local actual = self:RealValue(child(Player, "CurrentCharacter"))
    local identity = tostring(actual) .. "|" .. row.value
    if state.routeIdentity ~= identity then self:RestoreHooks("CharacterSkillRoutes"); state.routeIdentity = identity end
    local root = at(Player, { "PlayerScripts", "Client", "Visuals", "Visuals" })
    local kit = self:CharacterAsset(root, row)
    local actualRow = self:FindRow("Characters", actual) or { value = actual, key = actual }
    local actualKit = self:CharacterAsset(root, actualRow)
    local count = 0
    local function refresh() if self.Alive then self:RefreshCharacterSkills(true) end end
    for _, action in ipairs({ "Ability", "Ultimate", "VisualEffect" }) do
        local module = child(kit, action)
        local nativeModule = child(actualKit, action) or child(child(root, "Misc"), action)
        local selected = self:RuntimeModule("SkillRoute:" .. row.value .. ":" .. action, module, refresh)
        local native = self:RuntimeModule("RealSkillRoute:" .. tostring(actual) .. ":" .. action, nativeModule, refresh)
        if type(selected) == "function" and type(native) == "function" and selected ~= native then
            local hook = self:HookFunction(selected, "Native " .. action .. " route", function(original, subject, ...)
                local equipped = self:SpoofRow("Characters")
                if subject == self.Character and self.Spoofs.Characters and equipped and equipped.value == row.value
                    and self:RealValue(child(Player, "CurrentCharacter")) == actual then
                    state.responses += 1
                    return native(subject, ...)
                end
                return original(subject, ...)
            end, module, "CharacterSkillRoutes")
            if hook then count += 1 end
        end
    end
    return count
end

function R:RefreshCharacterSkills(force)
    local state, row = self.SkillPresentation, self:SpoofRow("Characters")
    if not self.Alive or not self.Spoofs.Characters or not row then
        self:RestoreHooks("CharacterSkills")
        self:RestoreHooks("CharacterSkillRoutes")
        self:BindSkillAnimator(nil)
        state.revision += 1
        state.dispatcher, state.identity, state.routeIdentity, state.map = nil, nil, nil, {}
        state.connection, state.wrapper, state.remote, state.binding = nil, nil, nil, nil
        state.routingReady = false
        self.Status.skillAnimations = "Equip a client character first"
        return
    end
    local now = os.clock()
    if not force and now - state.lastBind < 3 then return end
    state.lastBind = now
    local dispatcher = self:FindSkillDispatcher()
    if dispatcher then
        if state.dispatcher and state.dispatcher ~= dispatcher then
            local previous = self.Hooks[state.dispatcher]
            if previous then self:RestoreHook(previous) end
        end
        state.dispatcher = dispatcher
        self:HookFunction(dispatcher, "Equipped character skill responses", function(original, action, ...)
            local args = table.pack(...)
            if args[1] == self.Character and self.Spoofs.Characters and self:SpoofRow("Characters")
                and (action == "Ability" or action == "Ultimate" or action == "VisualEffect") then
                local native = self:RealSkillModule(action)
                if native then state.responses += 1; return native(table.unpack(args, 1, args.n)) end
                self.Status.skillAnimations = "Real " .. action .. " visual module is unavailable"
                return
            end
            return original(action, ...)
        end, state.owner, "CharacterSkills")
    end
    state.routingReady = dispatcher ~= nil and self.Hooks[dispatcher] ~= nil
    state.routing = state.routingReady and (state.binding or "dispatcher") or "waiting"
    if not state.routingReady then
        self:RestoreHooks("CharacterSkills")
        state.dispatcher = nil
        local count = self:BindSkillModuleRoutes(row)
        state.routingReady = count > 0
        if state.routingReady then state.routing = "module callbacks" end
    else
        self:RestoreHooks("CharacterSkillRoutes")
    end
    if not self.Options.SpoofSkillAnimations then
        self:ClearSkillMirrors(); state.map = {}; self.Status.skillAnimations = "Normal skill animations"; return
    end
    local actualName = self:RealValue(child(Player, "CurrentCharacter"))
    local actual = self:FindRow("Characters", actualName) or (type(actualName) == "string" and { value = actualName, key = actualName })
    local animator = self.Humanoid and self.Humanoid:FindFirstChildOfClass("Animator")
    self:BindSkillAnimator(animator)
    local util = self:RuntimeModule("SkillAnimationUtil", at(ReplicatedStorage, { "Package", "Modules", "util" }), function()
        self:RefreshCharacterSkills(true)
    end)
    local identity = actual and actual.value .. "|" .. row.value
    if state.identity ~= identity or state.animator ~= animator or force or not next(state.map) then
        if state.identity ~= identity or state.animator ~= animator then self:ClearSkillMirrors() end
        state.identity, state.animator = identity, animator
        state.revision += 1
        state.map = {}
        self.Status.skillAnimations = "Loading " .. row.value .. " skill animations"
        local revision = state.revision
        self:Spawn(function()
            local sources, targets = self:SkillAnimationAssets(actual, util), self:SkillAnimationAssets(row, util)
            local map, count, ability, zone = {}, 0, 0, 0
            for role, assets in pairs(sources) do
                local target = targets[role][1]
                if not target and (role == "Startup" or role == "Running") then target = targets.Ability[1] end
                if target then
                    for _, source in ipairs(assets) do
                        local id = self:SkillAnimationKey(source)
                        if id and self:SkillAnimationKey(target) and id ~= self:SkillAnimationKey(target) then
                            map[id] = target; count += 1
                            if role == "Ultimate" then zone += 1 else ability += 1 end
                        end
                    end
                end
            end
            if not self.Alive or state.revision ~= revision then return end
            state.map = map
            if not state.animator or not state.animationConnection then
                self.Status.skillAnimations = "Waiting for the local Animator playback signal"
                return
            end
            if not state.routingReady then
                self.Status.skillAnimations = "No native skill route bound | copy Debug Info"
                return
            end
            self.Status.skillAnimations = count > 0 and ("Armed: " .. row.value .. " | ability: " .. (ability > 0 and "mapped" or "unavailable")
                .. ", zone: " .. (zone > 0 and "mapped" or "unavailable") .. " | confirmed swaps: " .. state.swaps)
                or "No compatible actor skill animations found for this character"
            self:ScanPlayingSkills()
        end)
    end
end

-- Cutscenes.Play is the native, shared presentation boundary. Its arguments
-- are (name, character, variant, data), unlike the per-kit remote callbacks.
function R:LocalRaceEffect(fn, ...)
    local scopes, thread = self.RacePresentation.localThreads, coroutine.running()
    local previous = scopes[thread]
    scopes[thread] = true
    local result = table.pack(pcall(fn, ...))
    scopes[thread] = previous
    return table.unpack(result, 1, result.n)
end

function R:RunZoneScene(original, name, subject, variant, data, ...)
    local state, row = self.RacePresentation, self:SpoofRow("Characters")
    local actual = self:RealValue(child(Player, "CurrentCharacter"))
    local own = subject == self.Character and subject ~= nil and child(subject, "InfoPlaying")
    local selected = own and self.Spoofs.Characters and self.Options.SpoofUltimateCutscene and row
        and (name == actual or name == row.value or name == row.key)
    local swapped = selected and name ~= row.value and name ~= row.key
    if own and not state.localThreads[coroutine.running()] and name == actual then
        local ok, args = pcall(self.CopyUltimateArgs, self, table.pack(name, subject, variant, data))
        if ok then
            self.RaceActions.ultimateScene = { args = args, actual = actual, character = subject,
                race = child(subject, "InfoPlaying") }
        end
    end
    if swapped then
        local config = self.RuntimeModules.EquippedZoneScene
        if not config or config.instance ~= state.sceneModule or type(config.value) ~= "table"
            or type(config.value.Play) ~= "function" then
            self.Status.zoneScene = "Waiting for " .. row.value .. "'s zone scene"
            return original(name, subject, variant, data, ...)
        end
        -- Variants and target payloads belong to the source kit. A different
        -- kit receives its default scene, which constructs its own stand-ins.
        name, variant, data = state.sceneModule.Name, nil, nil
    end
    if not own then return original(name, subject, variant, data, ...) end
    state.sceneCalls += 1
    state.scenesInFlight += 1
    local selectedScene
    if selected then
        state.selectedSceneSerial = (state.selectedSceneSerial or 0) + 1
        selectedScene = { serial = state.selectedSceneSerial, character = subject,
            race = child(subject, "InfoPlaying"), name = name, inFlight = true }
        state.selectedScene = selectedScene
    end
    if selected then self:ClearSkillMirrors() end
    self.Status.zoneScene = "Playing local scene: " .. name
    local result = table.pack(pcall(original, name, subject, variant, data, ...))
    state.scenesInFlight -= 1
    if selectedScene then
        selectedScene.inFlight = false
        selectedScene.initialized = result[1] and type(result[2]) == "table" and result[2].Started == true
    end
    if result[1] and type(result[2]) == "table" and result[2].Started == true then
        state.sceneStarts = (state.sceneStarts or 0) + 1
        if swapped then state.sceneSwaps += 1 end
        self.Status.zoneScene = "Scene initialized: " .. name .. " | playback unverified"
    elseif result[1] then
        self.Status.zoneScene = "Scene did not start: " .. name
    else
        self.Status.zoneScene = "Scene failed: " .. name
        error(result[2], 0)
    end
    return table.unpack(result, 2, result.n)
end

function R:RefreshRaceSummaryUI()
    local state, row = self.RacePresentation, self:SpoofRow("Characters")
    local gui = at(Player, { "PlayerGui", "RaceRewards" })
    if not self.Alive or not self.Options.SpoofRaceSummary or not self.Spoofs.Characters or not row
        or not gui or gui.Enabled == false then
        self:ReleaseValues("RaceSummaryUI:")
        return
    end
    local uma = at(gui, { "root", "stage", "content", "uma" })
    local card, label = child(uma, "card"), child(uma, "name")
    if card and (card:IsA("ImageLabel") or card:IsA("ImageButton")) and type(row.data.CardImage) == "string" then
        self:ForceValue("RaceSummaryUI:Card", card, row.data.CardImage, "Image")
    end
    if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
        self:ForceValue("RaceSummaryUI:Name", label, tostring(row.data.DisplayName or row.data.Name or row.value), "Text")
    end
    local earned = state.summaryPacket
    local owner = earned and type(earned.mastery) == "table" and earned.mastery.uma or earned and earned.uma
    self.Status.raceSummary = "Local card: " .. row.value .. " | earned progress: " .. tostring(owner or "server result")
end

function R:RefreshRacePresentation()
    local state, row = self.RacePresentation, self:SpoofRow("Characters")
    if not self.Alive or ((not self.Spoofs.Characters or not row) and not self.Options.InfiniteUlt) then
        self:RestoreHooks("RacePresentation")
        self:ReleaseValues("RaceSummaryUI:")
        state.sceneModule = nil
        self.Status.zoneScene, self.Status.raceSummary = "Using your real character", "Using the server result"
        return
    end
    local function refresh() if self.Alive then self:RefreshRacePresentation() end end
    local root = at(ReplicatedStorage, { "Package", "Modules", "Cutscenes" })
    local api = self:RuntimeModule("ZoneScenes", root, refresh)
    state.sceneModule = self.Spoofs.Characters and self:CharacterAsset(root, row) or nil
    self:RuntimeModule("EquippedZoneScene", state.sceneModule, refresh)
    if type(api) == "table" and type(api.Play) == "function" then
        self:HookFunction(api.Play, "Equipped character zone scene", function(original, ...)
            return self:RunZoneScene(original, ...)
        end, root, "RacePresentation")
    end
    local module = at(Player, { "PlayerScripts", "Client", "Visuals", "Visuals", "Misc", "RaceSummary" })
    local summary = self:RuntimeModule("RaceSummary", module, refresh)
    if type(summary) == "function" then
        self:HookFunction(summary, "Race result character card", function(original, packet, ...)
            if type(packet) == "table" then
                state.summaryPacket = table.clone(packet)
                if type(packet.mastery) == "table" then state.summaryPacket.mastery = table.clone(packet.mastery) end
                -- The native result, XP and mastery-menu destination remain
                -- intact. Only the visible local card/name are substituted.
                self:Spawn(function() task.wait(); self:RefreshRaceSummaryUI() end)
            end
            return original(packet, ...)
        end, module, "RacePresentation")
    end
    self:RefreshRaceSummaryUI()
end

function R:RaceReady()
    if not self.Alive or not self.Character or not self.Root or not self.Root.Parent
        or not self.Humanoid or self.Humanoid.Health <= 0 then return false, "Character not ready" end
    if not child(self.Character, "InfoPlaying") then return false, "Join a race first" end
    local configuration = at(game:GetService("Lighting"), { "Configuration" })
    if configuration and configuration:GetAttribute("RaceStart") ~= true then return false, "Waiting for race start" end
    if self.Root.Anchored then return false, "Wait for the cutscene to finish" end
    local sync = self.Modules.CutsceneSync and self.Modules.CutsceneSync.value
    if sync and type(sync.IsPaused) == "function" then
        local ok, paused = pcall(sync.IsPaused)
        if ok and paused then return false, "Race paused" end
    end
    return true
end

function R:AbilityAim()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    local look = self.RuntimeModules.LookBack
    look = look and look.value
    if look and type(look.isActive) == "function" and look.isActive()
        and type(look.getRealCameraCFrame) == "function" then
        local cf = look.getRealCameraCFrame(camera)
        return { origin = cf.Position, direction = cf.LookVector }
    end
    local ok, ray = pcall(function()
        local position
        if UserInputService.TouchEnabled or UserInputService.GamepadEnabled then
            position = camera.ViewportSize * 0.5
        else
            position = UserInputService:GetMouseLocation()
        end
        return camera:ViewportPointToRay(position.X, position.Y)
    end)
    if ok and ray then return { origin = ray.Origin, direction = ray.Direction.Unit } end
    return { origin = camera.CFrame.Position, direction = camera.CFrame.LookVector }
end

function R:SkillObservation(action, text)
    local attempt = self.RaceActions.attempts[action]
    if attempt and not attempt.finished and attempt.character == self.Character and os.clock() <= attempt.deadline then
        attempt.observed, attempt.state = true, text
        self.Status.skills = action .. ": " .. text
    end
end

function R:RefreshRaceActions()
    local state = self.RaceActions
    if not self.Options.InfiniteSpurts and not self.Options.InfiniteUlt and os.clock() >= (state.monitorUntil or 0) then
        self:RestoreHooks("RaceActions")
        self:RefreshReplayInputs()
        return
    end
    local misc = at(Player, { "PlayerScripts", "Client", "Visuals", "Visuals", "Misc" })
    local function refresh() if self.Alive then self:RefreshRaceActions() end end
    local spurtModule = child(misc, "Spurt")
    local native = self:RuntimeModule("NativeSpurt", spurtModule, refresh)
    if type(native) == "function" then
        self:HookFunction(native, "Native spurt response", function(original, subject, route, ...)
            if subject == self.Character and route == "Client" then
                state.spurtResponses += 1
                self:SkillObservation("Spurt", "Native dash callback observed")
            end
            return original(subject, route, ...)
        end, spurtModule, "RaceActions")
    end
    local skillModule = child(misc, "SkillUi")
    local skillUI = self:RuntimeModule("NativeSkillUI", skillModule, refresh)
    if type(skillUI) == "function" then
        self:HookFunction(skillUI, "Native skill UI", function(original, subject, name, buff, kind, ...)
            if subject == self.Character then
                self:SkillObservation(kind == "Ultimate" and "Ultimate" or "Ability", "Game skill UI: " .. tostring(name))
            end
            return original(subject, name, buff, kind, ...)
        end, skillModule, "RaceActions")
    end
    self:RuntimeModule("LookBack", at(Player, { "PlayerScripts", "Client", "LookBack" }), refresh)
    self:BindUltimateReplay()
    self:RefreshReplayInputs()
end

-- Learn the actual self-client payload from a real zone activation. Targeted
-- payloads, old characters and old races are not reused.
function R:CopyUltimateArgs(args)
    local seen, count = {}, 0
    local function copy(value, depth)
        count += 1
        if count > 160 or depth > 4 then error("Zone payload is too complex") end
        local kind = typeof(value)
        if kind == "Instance" then
            if value == self.Character or value == Player or value:IsDescendantOf(self.Character) then return value end
            error("Zone payload references another actor")
        elseif kind == "function" or kind == "thread" or kind == "RBXScriptConnection" then
            error("Zone payload contains a live callback")
        elseif kind == "table" then
            if seen[value] then error("Zone payload contains a cycle") end
            seen[value] = true
            local result = {}
            for key, item in pairs(value) do
                if type(key) ~= "string" and type(key) ~= "number" then error("Unsupported zone payload key") end
                result[key] = copy(item, depth + 1)
            end
            seen[value] = nil
            return result
        end
        return value
    end
    return copy(args, 0)
end

function R:BindUltimateReplay()
    local state = self.RaceActions
    local actual = self:RealValue(child(Player, "CurrentCharacter"))
    if type(actual) ~= "string" then self.Status.ultimate = "Waiting for your real character selection"; return end
    local visuals = at(Player, { "PlayerScripts", "Client", "Visuals", "Visuals" })
    local row = self:FindRow("Characters", actual)
    local kit = child(visuals, actual) or (row and child(visuals, row.key))
    local module = child(kit, "Ultimate")
    if state.ultimateModule ~= module or state.ultimateKit ~= actual then
        local previous = self.RuntimeModules.NativeUltimate
        if previous and type(previous.value) == "function" and self.Hooks[previous.value] then
            self:RestoreHook(self.Hooks[previous.value])
        end
        state.ultimateModule, state.ultimateKit, state.ultimateRecord = module, actual, nil
        state.ultimateAllClients, state.ultimateScene = nil, nil
    end
    local native = self:RuntimeModule("NativeUltimate", module, function() self:RefreshRaceActions() end)
    if type(native) ~= "function" then
        if self.Options.InfiniteUlt then self.Status.ultimate = "Waiting for this kit's client zone module" end
        return
    end
    self:HookFunction(native, "Native zone response", function(original, subject, route, ...)
        if subject == self.Character and (route == "Client" or route == "OnAllClients")
            and self:RealValue(child(Player, "CurrentCharacter")) == actual then
            state.ultimateResponses = (state.ultimateResponses or 0) + 1
            self:SkillObservation("Ultimate", "Native zone callback observed")
            local received = table.pack(subject, route, ...)
            local ok, payload = pcall(function() return self:CopyUltimateArgs(received) end)
            if ok then
                local record = { args = payload, actual = actual, character = subject,
                    race = child(subject, "InfoPlaying"), native = native }
                if route == "Client" then state.ultimateRecord = record else state.ultimateAllClients = record end
                self.Status.ultimate = "Captured " .. tostring(actual) .. " zone / " .. route
            else
                if route == "Client" then state.ultimateRecord = nil else state.ultimateAllClients = nil end
                self.Status.ultimate = "Targeted zone cannot be replayed: " .. tostring(payload)
            end
        end
        return original(subject, route, ...)
    end, module, "RaceActions")
    if self.Options.InfiniteUlt and not state.ultimateAllClients and not state.ultimateScene
        and not (self.Spoofs.Characters and self.Options.SpoofUltimateCutscene) then
        self.Status.ultimate = "Use your real zone once to capture its scene"
    end
end

function R:RaceReplayInput(input, processed)
    if not self.Alive or processed or not (self.Options.InfiniteSpurts or self.Options.InfiniteUlt) then return end
    local ok, focused = pcall(function() return UserInputService:GetFocusedTextBox() end)
    if ok and focused then return end
    local key = input.KeyCode
    if not key or key == Enum.KeyCode.Unknown then return end
    local record = self.RuntimeModules.RaceKeybinds
    local api = record and record.value
    for _, action in ipairs({ "Spurt", "Ultimate" }) do
        local matches = false
        if type(api) == "table" and type(api.Is) == "function" then
            local success, result = pcall(api.Is, action, key)
            matches = success and result == true
        else matches = key == Enum.KeyCode[action == "Spurt" and "R" or "G"] end
        if matches then
            if action == "Spurt" and self.Options.InfiniteSpurts then self:QueueSpurtReplay() end
            if action == "Ultimate" and self.Options.InfiniteUlt then self:QueueUltimateReplay() end
            return
        end
    end
end

function R:RefreshReplayInputs()
    local state = self.RacePresentation
    local active = self.Alive and (self.Options.InfiniteSpurts or self.Options.InfiniteUlt)
    local holder = active and at(Player, { "PlayerGui", "MobileControls", "Mobile" })
    for button, record in pairs(state.inputs) do
        if not active or button.Parent ~= holder or not connected(record.connection) then
            record.connection:Disconnect(); state.inputs[button] = nil
        end
    end
    if not active then return end
    self:RuntimeModule("RaceKeybinds", at(ReplicatedStorage, { "Package", "Keybinds" }), function() end)
    for _, action in ipairs({ "Spurt", "Ultimate" }) do
        local button = child(holder, action == "Spurt" and "SpurtButton" or "UltimateButton")
        if button and button:IsA("GuiObject") and not state.inputs[button] then
            local connection = self:Connect(button.InputBegan, function(input)
                if not visibleInPlayerGui(button) then return end
                if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                if action == "Spurt" and self.Options.InfiniteSpurts then self:QueueSpurtReplay() end
                if action == "Ultimate" and self.Options.InfiniteUlt then self:QueueUltimateReplay() end
            end)
            state.inputs[button] = { connection = connection }
        end
    end
end

function R:QueueUltimateReplay()
    local state, now = self.RaceActions, os.clock()
    if not self.Options.InfiniteUlt or not self:RaceReady() then return end
    if state.ultimateQueued and now - state.ultimateQueued.sent < 0.1 then return end
    state.ultimateSerial = (state.ultimateSerial or 0) + 1
    local queued = { serial = state.ultimateSerial, character = self.Character, sent = now,
        responses = state.ultimateResponses or 0, race = child(self.Character, "InfoPlaying"),
        sceneSerial = self.RacePresentation.selectedSceneSerial or 0 }
    local equipped = self:SpoofRow("Characters")
    queued.equipped = equipped and equipped.value
    state.ultimateQueued = queued
    self:RefreshRaceActions()
    self.Status.ultimate = "Native zone request first..."
    self:Spawn(function()
        task.wait(0.45)
        if state.ultimateQueued == queued then state.ultimateQueued = nil end
        local function current()
            local equippedNow = self:SpoofRow("Characters")
            return self.Alive and state.ultimateSerial == queued.serial and self.Options.InfiniteUlt
                and self.Character == queued.character and child(self.Character, "InfoPlaying") == queued.race
                and (equippedNow and equippedNow.value) == queued.equipped
        end
        if not current() then return end
        local function handled()
            local row = self:SpoofRow("Characters")
            if not (self.Spoofs.Characters and self.Options.SpoofUltimateCutscene and row) then
                if (state.ultimateResponses or 0) ~= queued.responses then
                    self.Status.ultimate = "Native zone received"; return true
                end
                return false
            end
            local scene = self.RacePresentation.selectedScene
            if scene and scene.serial > queued.sceneSerial and scene.character == queued.character
                and scene.race == queued.race and (scene.name == row.value or scene.name == row.key)
                and (scene.inFlight or scene.initialized) then
                self.Status.ultimate = scene.inFlight and "Selected zone scene is running"
                    or "Selected zone initialized | playback unverified"
                return true
            end
            return false
        end
        if handled() then return end
        -- An actual-kit response may own the camera/root without ever calling
        -- the selected scene. Wait for its cleanup instead of dropping replay
        -- or starting two scenes over the same character.
        local deadline = os.clock() + 20
        while not self:RaceReady() do
            if not current() or handled() then return end
            if not self.Humanoid or self.Humanoid.Health <= 0 or os.clock() >= deadline then
                self.Status.ultimate = "Zone replay stopped: character or race stayed unavailable"; return
            end
            self.Status.ultimate = "Waiting for native zone cleanup..."
            task.wait(0.1)
        end
        if not current() or handled() then return end
        if state.ultimateThread or now - (state.lastUltimateReplay or -math.huge) < self.Options.UltReplayGap then
            self.Status.ultimate = "Wait for the current client zone"; return
        end
        self:RefreshRacePresentation()
        local presentation, row = self.RacePresentation, self:SpoofRow("Characters")
        local scenes = self.RuntimeModules.ZoneScenes
        local config = self.RuntimeModules.EquippedZoneScene
        local fn, args
        if self.Spoofs.Characters and self.Options.SpoofUltimateCutscene and row
            and scenes and type(scenes.value) == "table" and type(scenes.value.Play) == "function"
            and config and config.instance == presentation.sceneModule and type(config.value) == "table"
            and type(config.value.Play) == "function" then
            -- The selected scene needs no fabricated cross-kit remote payload.
            -- Calling the common presentation API also works before capture.
            fn, args = scenes.value.Play, table.pack(presentation.sceneModule.Name, self.Character, nil, nil)
        else
            local record = state.ultimateAllClients
            local function current(captured)
                return captured and captured.character == self.Character and captured.race == queued.race
                    and captured.race == child(self.Character, "InfoPlaying")
                    and captured.actual == self:RealValue(child(Player, "CurrentCharacter"))
            end
            local capturedScene = false
            if not current(record) and current(state.ultimateScene)
                and scenes and type(scenes.value) == "table" and type(scenes.value.Play) == "function" then
                record, capturedScene = state.ultimateScene, true
            end
            if not current(record) then
                self.Status.ultimate = "No replayable scene; use a real zone first or equip a local character"; return
            end
            local valid, copied = pcall(self.CopyUltimateArgs, self, record.args)
            if not valid then
                if capturedScene then state.ultimateScene = nil else state.ultimateAllClients = nil end
                self.Status.ultimate = "Captured scene is no longer valid"; return
            end
            fn, args = capturedScene and scenes.value.Play or inspectFunction(record.native), copied
        end
        state.lastUltimateReplay = os.clock()
        state.ultimateReplayUntil = os.clock() + self.Options.UltReplayGap
        state.ultimateThread = coroutine.running()
        local startsBefore = presentation.sceneStarts or 0
        local ok, result = self:LocalRaceEffect(fn, table.unpack(args, 1, args.n))
        state.ultimateThread = nil
        local started = type(result) == "table" and result.Started == true
        if ok and (started or (presentation.sceneStarts or 0) > startsBefore) then
            self.Status.ultimate = "Local zone initialized | playback and server effects unverified"
        else
            state.lastUltimateReplay, state.ultimateReplayUntil = nil, nil
            if ok then self.Status.ultimate = "Callback returned; no scene playback was confirmed"
            else self.Status.ultimate = "Local zone scene failed"; self:Error("Client zone", result) end
        end
    end)
end

function R:SetInfiniteUlt(enabled)
    self.Options.InfiniteUlt = enabled == true
    self.RaceActions.ultimateSerial = (self.RaceActions.ultimateSerial or 0) + 1
    self.RaceActions.ultimateQueued = nil
    self.Status.ultimate = enabled and "Press your zone key | equipped local scene or captured native scene" or "Off"
    self:RefreshRacePresentation()
    self:RefreshRaceActions()
    self:RefreshRequestHooks()
end

function R:UseRaceAction(action, mode)
    local remoteName = ({ Ability = "RequestAbility", Ultimate = "Ultimate", Spurt = "Spurt" })[action]
    if not remoteName then return false end
    local ready, reason = self:RaceReady()
    if not ready then self.Status.skills = reason; self:Notify("Race", reason); return false end
    local state, now = self.RaceActions, os.clock()
    local previous = state.attempts[action]
    if previous and now - previous.sent < 0.75 then return false end
    local remote = at(ReplicatedStorage, { "remotes", remoteName })
    if not remote or not remote:IsA("RemoteEvent") then
        self.Status.skills = remoteName .. " is unavailable"; return false
    end
    local actual = tostring(self:RealValue(child(Player, "CurrentCharacter")) or "Unknown")
    mode = mode or "Tap"
    if action == "Ability" then
        if mode ~= "Tap" and mode ~= "Hold" then return false end
        local config = self.Modules.UmaConfig and self.Modules.UmaConfig.value
        local data = config and config[actual:gsub("%s+", "")]
        if mode == "Hold" and not (data and data.HoldVariant == true) then
            self.Status.skills = actual .. " has no native hold variant"; return false
        end
    end
    state.serial += 1
    local attempt = { id = state.serial, character = self.Character, actual = actual,
        sent = now, deadline = now + 4, state = "Request sent; waiting for a game response",
        meter = numberValue(child(Player, "Ultimate")), cooldown = child(self.Character, "SpurtCooldown") }
    state.attempts[action], state.monitorUntil = attempt, now + 10
    self:RefreshRaceActions()
    local ok, err = pcall(function()
        if action == "Ability" then remote:FireServer(self:AbilityAim(), mode)
        else
            if action == "Spurt" and self.Options.InfiniteSpurts then self:QueueSpurtReplay() end
            if action == "Ultimate" and self.Options.InfiniteUlt then self:QueueUltimateReplay() end
            remote:FireServer()
        end
    end)
    if not ok then attempt.state = "Request error: " .. tostring(err); self:Error(action, err) end
    self.Status.skills = action .. " | " .. actual .. " | " .. attempt.state
    return ok
end

function R:QueueSpurtReplay()
    local state, now = self.RaceActions, os.clock()
    local ready = self:RaceReady()
    if not ready or not self.Options.InfiniteSpurts then return end
    -- NAMECALL and a method hook can both see the same native request.
    if state.queued and now - state.queued.sent < 0.1 then return end
    state.replaySerial += 1
    local queued = { serial = state.replaySerial, sent = now, character = self.Character,
        race = child(self.Character, "InfoPlaying"), responses = state.spurtResponses }
    state.queued = queued
    self:RefreshRaceActions()
    self.Status.spurts = "Native request first..."
    self:Spawn(function()
        task.wait(0.45)
        if state.queued == queued then state.queued = nil end
        if queued.serial ~= state.replaySerial or not self.Options.InfiniteSpurts
            or self.Character ~= queued.character or child(self.Character, "InfoPlaying") ~= queued.race
            or not self:RaceReady() then return end
        if state.spurtResponses ~= queued.responses then self.Status.spurts = "Native dash received"; return end
        if os.clock() - state.lastReplay < 2.2 or self.Root:GetAttribute("VelocityOverrideActive") then
            self.Status.spurts = "Wait for the current burst"; return
        end
        local record = self.RuntimeModules.NativeSpurt
        local native = record and record.value
        if type(native) ~= "function" then self.Status.spurts = "Waiting for the native client dash"; return end
        state.lastReplay, state.replayUntil = os.clock(), os.clock() + 2.2
        -- Verified native signature: (character, "Client", force1?, force2?).
        -- Omitted forces use that character's own SpurtForce1/2 or defaults.
        local before = self.Root.AssemblyLinearVelocity
        local ok, err = self:LocalRaceEffect(inspectFunction(native), queued.character, "Client")
        local effect = self.Root and (self.Root:GetAttribute("VelocityOverrideActive") == true
            or (self.Root.AssemblyLinearVelocity - before).Magnitude > 1)
        self.Status.spurts = ok and (effect and "Local burst started | server charges unchanged"
            or "Callback returned; no local burst was observed") or "Client dash failed"
        if not ok or not effect then state.lastReplay, state.replayUntil = -math.huge, nil end
        if not ok then state.replayUntil = nil; self:Error("Client spurt", err) end
    end)
end

function R:SetInfiniteSpurts(enabled)
    self.Options.InfiniteSpurts = enabled == true
    self.RaceActions.replaySerial += 1
    self.RaceActions.queued = nil
    self.Status.spurts = enabled and "Ready | key, touch or native request; local repeat when available" or "Off"
    self:RefreshRaceActions()
    self:RefreshRequestHooks()
end

function R:TickRaceActions()
    local latest, latestAction
    for action, attempt in pairs(self.RaceActions.attempts) do
        if not attempt.finished then
            if self.Character ~= attempt.character then
                attempt.finished, attempt.state = true, "Character changed; test ended"
            elseif not attempt.observed then
                if action == "Ultimate" then
                    local meter = numberValue(child(Player, "Ultimate"))
                    if meter and attempt.meter and meter < attempt.meter then
                        self:SkillObservation(action, "Replicated zone meter decreased")
                    end
                elseif action == "Spurt" then
                    local cooldown = child(self.Character, "SpurtCooldown")
                    if cooldown and cooldown ~= attempt.cooldown then
                        self:SkillObservation(action, "Game spurt cooldown appeared")
                    end
                end
            end
            if os.clock() >= attempt.deadline then
                attempt.finished = true
                if not attempt.observed then attempt.state = "No native response observed; request was not confirmed" end
            end
        end
        if not latest or attempt.id > latest.id then latest, latestAction = attempt, action end
    end
    if latest then self.Status.skills = latestAction .. " | " .. latest.actual .. " | " .. latest.state end
    self:RefreshRaceActions()
    if self.SkillStatusControl then
        local actual = tostring(self:RealValue(child(Player, "CurrentCharacter")) or "Unknown")
        local selected = self:SelectedRow("Characters")
        local lines = { "Server selection: " .. actual, "Local selection: " .. (selected and selected.value or actual) }
        for _, action in ipairs({ "Ability", "Ultimate", "Spurt" }) do
            local attempt = self.RaceActions.attempts[action]
            if attempt then lines[#lines + 1] = action .. " (" .. attempt.actual .. "): " .. attempt.state end
        end
        lines[#lines + 1] = "Spurts: " .. self.Status.spurts
        lines[#lines + 1] = "Zone: " .. self.Status.ultimate
        pcall(function() self.SkillStatusControl:Set({ Title = "Skill tests", Content = table.concat(lines, "\n") }) end)
    end
end

-- Optional race helpers use replicated progress and the game's own claims.
function R:ReadQuests()
    local rows = {}
    for _, kind in ipairs({ { "DailyQuests", "Daily", "ClaimQuest" }, { "WeeklyQuests", "Weekly", "ClaimWeeklyQuest" } }) do
        local folder = child(Player, kind[1])
        if folder then
            for index = 1, 10 do
                local quest = child(folder, "Quest" .. index)
                if quest and child(quest, "Progress") then
                    local function value(name, fallback)
                        local instance = child(quest, name)
                        return instance and instance.Value or fallback
                    end
                    rows[#rows + 1] = {
                        folder = quest, index = index, kind = kind[2], remote = kind[3],
                        description = tostring(value("Description", "Quest " .. index)),
                        progress = tonumber(value("Progress", 0)) or 0, goal = tonumber(value("Goal", 0)) or 0,
                        completed = value("Completed", false) == true, claimed = value("Claimed", false) == true,
                    }
                end
            end
        end
    end
    return rows
end

function R:ClaimQuests(manual)
    if self.ClaimBusy then return end
    local works = self.Modules.Works and self.Modules.Works.value
    if not works or type(works.FireRemote) ~= "function" then
        if manual then self:Notify("Quests", "Waiting for the game's quest handler.") end
        return
    end
    local ready = {}
    for _, row in ipairs(self:ReadQuests()) do
        local last = self.QuestAttempts[row.folder]
        if row.completed and not row.claimed and (not last or os.clock() - last >= 15) then
            ready[#ready + 1] = row
        end
    end
    if #ready == 0 then if manual then self:Notify("Quests", "No completed quests to claim.") end; return end
    self.ClaimBusy = true
    self:Spawn(function()
        for _, row in ipairs(ready) do
            if not self.Alive or (not manual and not self.Options.AutoClaimQuests) then break end
            local completed, claimed = child(row.folder, "Completed"), child(row.folder, "Claimed")
            if row.folder.Parent and completed and completed.Value == true and claimed and claimed.Value == false then
                self.QuestAttempts[row.folder] = os.clock()
                local ok, err = pcall(function() return works:FireRemote("Request", row.remote, row.index) end)
                if not ok then self:Error("Quest claim", err) end
                task.wait(0.2)
            end
        end
        self.ClaimBusy = false
        if manual and self.Alive then self:Notify("Quests", "Claim requests sent.") end
    end)
end

function R:TickExtras()
    for _, setting in ipairs({
        { "AutoReady", "AutoReady", true }, { "MuteCommentary", "Commentary", false },
        { "NoShake", "ScreenShake", false }, { "NoShake", "StaminaShake", false },
        { "SteadyCamera", "DynamicCamera", false }, { "SteadyCamera", "SwayCamera", false },
        { "SteadyCamera", "HeadCamera", false },
    }) do
        local key = "Setting:" .. setting[2]
        if self.Options[setting[1]] then
            self:ForceValue(key, at(Player, { "Settings", setting[2] }), setting[3])
        else self:ReleaseValue(key) end
    end
    if self.Options.NoShake then
        if not child(Player, "CameraShakeOff") then
            local marker = Instance.new("BoolValue"); marker.Name = "CameraShakeOff"
            self.ShakeMarker = marker; marker.Parent = Player
        end
    elseif self.ShakeMarker then self.ShakeMarker:Destroy(); self.ShakeMarker = nil end
    if self.Options.OverrideFOV then
        self:ForceValue("Setting:FOV", at(Player, { "DataFolder", "FOV" }), self.Options.FOV)
        self:ForceValue("Setting:CameraFOV", Workspace.CurrentCamera, self.Options.FOV, "FieldOfView")
    else self:ReleaseValue("Setting:FOV"); self:ReleaseValue("Setting:CameraFOV") end
    local quests, lines, ready = self:ReadQuests(), {}, 0
    for _, row in ipairs(quests) do
        if row.completed and not row.claimed then ready += 1 end
        if not row.claimed then
            lines[#lines + 1] = row.kind .. ": " .. row.description .. " (" .. row.progress .. "/" .. row.goal .. ")"
        end
    end
    self.Status.quests = #quests == 0 and "No quests loaded" or (#lines == 0 and "All claimed" or table.concat(lines, "\n"))
    if self.QuestStatusControl then
        local content = self.Status.quests .. "\nReady to claim: " .. ready
        if content ~= self.LastQuestText then
            self.LastQuestText = content
            pcall(function() self.QuestStatusControl:Set({ Title = "Quests", Content = content }) end)
        end
    end
    if self.Options.AutoClaimQuests then self:ClaimQuests(false) end
end

function R:UpdateRaceHUD()
    if not self.RaceHUDControl then return end
    local actual, maximum = self:StaminaSource()
    local zone = numberValue(child(Player, "Ultimate"))
    local maximumSpeed = numberValue(at(Player, { "Info", "EffectiveMaxSpeed" }))
    local speed = self.Root and self.Root.AssemblyLinearVelocity.Magnitude or 0
    local content = string.format("Speed: %.1f | Max: %s\nStamina: %s/%s | Zone: %s",
        speed, maximumSpeed and tostring(maximumSpeed) or "-", actual and tostring(actual) or "-",
        maximum and tostring(maximum) or "-", zone and tostring(zone) or "-")
    if content ~= self.LastRaceHUD then
        self.LastRaceHUD = content
        pcall(function() self.RaceHUDControl:Set({ Title = "Race info", Content = content }) end)
    end
end


function R:EquipCharacter()
    if self.EquipPending then self:Notify("Character", "Still equipping. Give it a second."); return end
    local row = self:SelectedRow("Characters")
    if not row then self:Notify("Character", "Pick a character first."); return end
    if not self:IsRealOwned(row) then self:Notify("Character", "This one is a client unlock. Press Equip Character to equip it locally."); return false end
    local current = child(Player, "CurrentCharacter")
    if current and current:IsA("StringValue") and self:RealValue(current) == row.value then
        self:SetSpoof("Characters", false)
        local control = self.Controls.SpoofCharacters
        if control then pcall(function() control:Set(false) end) end
        self:Notify("Character", row.value .. " is already equipped.")
        return true
    end
    local character = Player.Character
    if character and child(character, "InfoPlaying") then
        self:Notify("Character", "Change characters from the lobby, after the race.")
        return
    end
    local remote = at(ReplicatedStorage, { "remotes", "SaveCharacter" })
    if not current or not current:IsA("StringValue") or not remote or not remote:IsA("RemoteEvent") then
        self:Notify("Character", "Couldn't find the equip remote.")
        return
    end
    self.EquipPending = true
    self:ReleaseValues("Spoof:Characters:")
    self:Spawn(function()
        self.MenuServerEquip = true
        local ok, err = pcall(function() remote:FireServer(row.value) end)
        self.MenuServerEquip = false
        if not ok then
            self.EquipPending = false
            self:ApplySpoof("Characters")
            self:Error("Equip character", err)
            return
        end
        local deadline = os.clock() + 4
        repeat
            task.wait(0.1)
        until not self.Alive or current.Parent == nil or current.Value == row.value or os.clock() >= deadline
        self.EquipPending = false
        if not self.Alive then return end
        if current.Parent and current.Value == row.value then
            self:SetSpoof("Characters", false)
            local control = self.Controls.SpoofCharacters
            if control then pcall(function() control:Set(false) end) end
            self:Notify("Character equipped", row.value .. " equipped.")
        else
            self:Notify("Equip not confirmed",
                "The server didn't equip " .. row.value .. ". It may only be unlocked on your client.")
        end
        self:ApplySpoof("Characters")
    end)
    return true
end

function R:StopEmote()
    self.EmoteCancelSerial = (self.EmoteCancelSerial or 0) + 1
    if self.EmoteEndedConnection then self.EmoteEndedConnection:Disconnect(); self.EmoteEndedConnection = nil end
    for _, connection in ipairs(self.EmoteConnections or {}) do connection:Disconnect() end
    self.EmoteConnections = nil
    local track, animation, sound, marker = self.EmoteTrack, self.EmoteAnimation, self.EmoteSound, self.EmoteMarker
    self.EmoteTrack, self.EmoteAnimation, self.EmoteSound, self.EmoteMarker = nil, nil, nil, nil
    self.EmoteName, self.EmoteCharacter, self.EmoteHumanoid, self.EmoteBaseVolume = nil, nil, nil, nil
    if sound then pcall(function() sound:Stop(); sound:Destroy() end) end
    if track then pcall(function() track:Stop(0.1); track:Destroy() end) end
    if animation then pcall(function() animation:Destroy() end) end
    if marker then pcall(function() marker:Destroy() end) end
end

function R:PreviewEmote()
    return self:PlayEmote(self:SelectedRow("Emotes"))
end

function R:RemoveJitter()
    local motion = self.Motion
    if motion.offsetRoot and motion.offsetRoot.Parent and motion.offset.Magnitude > 0 then
        pcall(function() motion.offsetRoot.CFrame -= motion.offset end)
    end
    motion.offset, motion.offsetRoot = Vector3.zero, nil
end

function R:RestoreJump()
    local snapshot = self.JumpSnapshot
    if snapshot and snapshot.humanoid.Parent then
        pcall(function()
            if snapshot.humanoid.JumpPower == snapshot.writtenPower then
                snapshot.humanoid.JumpPower = snapshot.power
            end
            if snapshot.humanoid.JumpHeight == snapshot.writtenHeight then
                snapshot.humanoid.JumpHeight = snapshot.height
            end
        end)
    end
    self.JumpSnapshot = nil
end

function R:RestoreSteering(restoreHooks)
    local snapshot = self.SteerSnapshot
    if snapshot and snapshot.humanoid.Parent then
        pcall(function() snapshot.humanoid.AutoRotate = snapshot.autoRotate end)
    end
    self.SteerSnapshot = nil
    self.SteeringState.lastFacing, self.SteeringState.facingRoot = nil, nil
    if restoreHooks ~= false then
        self:RestoreHooks("Steering")
        self:RestoreHooks("SteeringRotation")
        self.SteeringState.rotationBindings, self.SteeringState.lastRotationBind = nil, nil
        self.SteeringState.target, self.SteeringState.helper = nil, nil
        self.SteeringState.connection, self.SteeringState.owner = nil, nil
        self.SteeringState.direction, self.SteeringState.root = nil, nil
        self.SteeringState.lastApplied = nil
        table.clear(self.SteeringState.scopes)
    end
end

function R:SteeringDirection()
    local direction = self.Humanoid and self.Humanoid.MoveDirection
    if self.Options.SteeringMode == "Camera" and Workspace.CurrentCamera then
        local record = self.RuntimeModules.SteeringLookBack or self.RuntimeModules.LookBack
        local camera, look = Workspace.CurrentCamera, self.SteeringState.look or (record and record.value)
        local cf = camera.CFrame
        if look and type(look.getRealCameraCFrame) == "function" then
            local ok, real = pcall(look.getRealCameraCFrame, camera)
            if ok and real then cf = real end
        end
        -- Native Sprint reverses the real-camera vector only in LockCenter.
        -- Free-mouse camera steering follows the camera's forward direction.
        local sign = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and -1 or 1
        if self.Options.SteeringCameraAxis == "Inverted" then sign = -sign end
        direction = cf.LookVector * sign
    end
    if not direction then return nil end
    direction = Vector3.new(direction.X, 0, direction.Z)
    return direction.Magnitude > 0.001 and direction.Unit or nil
end

function R:SteeringTurn(desired, dt)
    local state, root = self.SteeringState, self.Root
    if not desired or not root then return nil end
    local from = state.root == root and state.direction
    if not from or os.clock() - (state.lastTurn or -math.huge) > 0.25 then
        local velocity = root.AssemblyLinearVelocity
        from = Vector3.new(velocity.X, 0, velocity.Z)
        if from.Magnitude < 0.1 then
            local look = root.CFrame.LookVector
            from = Vector3.new(look.X, 0, look.Z)
        end
    end
    if from.Magnitude < 0.001 then from = desired end
    local start = math.atan2(from.X, from.Z)
    local finish = math.atan2(desired.X, desired.Z)
    local difference = (finish - start + math.pi) % (2 * math.pi) - math.pi
    local seconds = finite(dt) and dt > 0 and math.min(dt, 0.1) or 1 / 60
    local rate = tonumber(self.Options.SteeringTurnRate)
    if not finite(rate) then rate = 720 end
    local limit = math.rad(math.clamp(rate, 90, 1800)) * seconds
    local angle = start + math.clamp(difference, -limit, limit)
    local result = Vector3.new(math.sin(angle), 0, math.cos(angle))
    state.root, state.direction, state.lastTurn = root, result, os.clock()
    return result
end

function R:SteeringAllowed()
    if not self.Alive or not self.Character or not child(self.Character, "InfoPlaying")
        or not self.Root or not self.Root.Parent or self.Root.Anchored
        or not self.Humanoid or self.Humanoid.Health <= 0 or self.EmoteTrack
        or child(self.Character, "PlayingEmote") or child(self.Character, "CutsceneIFrame")
        or self.Character:GetAttribute("NoRotate") or self.Root:GetAttribute("VelocityOverrideActive") then return false end
    local lighting = game:GetService("Lighting")
    if child(lighting, "DisableRotate") then return false end
    local configuration = child(lighting, "Configuration")
    -- The movement hook already runs inside native sprint. A missing optional
    -- RaceStart attribute must not disable it; an explicit false still gates it.
    if configuration and configuration:GetAttribute("RaceStart") == false then return false end
    local record = self.Modules.CutsceneSync
    local sync = record and record.value
    if sync and type(sync.IsPaused) == "function" then
        local ok, paused = pcall(sync.IsPaused)
        if ok and paused then return false end
    end
    return true
end

function R:SteeringFacing(direction)
    local root, humanoid = self.Root, self.Humanoid
    if not root or not humanoid or not direction then return end
    if not self.SteerSnapshot or self.SteerSnapshot.humanoid ~= humanoid then
        self:RestoreSteering(false)
        self.SteerSnapshot = { humanoid = humanoid, autoRotate = humanoid.AutoRotate }
    end
    humanoid.AutoRotate = false
    root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
    self.SteeringState.lastFacing, self.SteeringState.facingRoot = os.clock(), root
end

function R:RefreshSteeringRotation(force)
    local state = self.SteeringState
    if not self.Options.Steering or not Cap.connections or not Cap.constants then
        self:RestoreHooks("SteeringRotation")
        state.rotationBindings = nil
        return
    end
    local now = os.clock()
    if not force and now - (state.lastRotationBind or -math.huge) < 1 then return end
    state.lastRotationBind = now
    local mobile = at(Player, { "PlayerScripts", "Client", "Sprint", "ShiftLockMobile" })
    local shift = at(Player, { "PlayerScripts", "PlayerModule", "CameraModule", "SmoothShiftLock" })
    local found, count = {}, 0
    for _, connection in pairs(connections(RunService.Heartbeat)) do
        count += 1
        if count > 240 then break end
        local fn = connectionFunction(connection)
        if fn and hasConstants(fn, { "DisableRotate", "NoRotate", "getRealCameraCFrame", "ToOrientation" }) then
            local values, hasPlayer, hasRoot, hasCharacter, hasState = upvalues(fn), false, false, false, false
            for _, value in pairs(values or {}) do
                if value == Player then hasPlayer = true end
                if value == self.Root then hasRoot = true end
                if value == self.Character then hasCharacter = true end
                if type(value) == "table" and rawget(value, "HumanoidRootPart") == self.Root
                    and rawget(value, "Humanoid") == self.Humanoid and self.Root then hasState = true end
            end
            local ok, environment = pcall(Cap.fenv, inspectFunction(fn))
            local owner = ok and environment and environment.script
            local native = owner and ((owner == mobile and hasRoot and hasCharacter and hasConstants(fn, { "TouchEnabled" }))
                or (owner == shift and hasState and hasConstants(fn, { "CHARACTER_SMOOTH_ROTATION" })))
            if hasPlayer and native then found[fn] = { connection = connection, root = self.Root, owner = owner } end
        end
    end
    for fn in pairs(state.rotationBindings or {}) do
        if not found[fn] and self.Hooks[fn] then self:RestoreHook(self.Hooks[fn]) end
    end
    state.rotationBindings = found
    for fn, binding in pairs(found) do
        self:HookFunction(fn, "Native steering rotation", function(original, ...)
            local current = state.rotationBindings and state.rotationBindings[fn]
            -- Only the two source-verified rotation callbacks yield ownership.
            -- No shared NoRotate attribute or Lighting marker is manufactured.
            if current and current.root == self.Root and connected(current.connection)
                and self.Options.Steering and self.SteerSnapshot and self.SteerSnapshot.humanoid == self.Humanoid
                and state.facingRoot == self.Root and os.clock() - (state.lastFacing or -math.huge) < 0.25
                and self:SteeringAllowed() then return end
            return original(...)
        end, binding.owner, "SteeringRotation")
    end
end

function R:LiveSprintMovement()
    local owner = at(Player, { "PlayerScripts", "Client", "Sprint" })
    if not owner or not Cap.connections or not (Cap.upvalues or Cap.getupvalue) or not Cap.constants then return nil end
    local cached = self.SteeringState
    if cached.owner == owner and cached.connection and connected(cached.connection)
        and cached.target and self.Hooks[cached.target] then return cached.target, owner, cached.connection end
    local queue, seen = {}, {}
    for _, connection in pairs(connections(RunService.Heartbeat)) do
        local fn = connectionFunction(connection)
        if fn then queue[#queue + 1] = { fn, 0, connection } end
    end
    local index = 1
    while index <= #queue and index <= 240 do
        local item = queue[index]; index += 1
        if not seen[item[1]] then
            seen[item[1]] = true
            if hasConstants(item[1], { "ConstantTurnSpeed", "ToOrientation", "lastMoveDirection", "AssemblyLinearVelocity" }) then
                local values = upvalues(item[1]) or {}
                local hasSettings, hasHelper = false, false
                for _, value in pairs(values) do
                    if sprintState(value) then hasSettings = true end
                    if type(value) == "function" and hasConstants(value, { "hrp", "AssemblyLinearVelocity", "clamp" }) then hasHelper = true end
                end
                if hasSettings and hasHelper then return item[1], owner, item[3] end
            end
            if item[2] < 5 then
                for _, fn in pairs(upvalues(item[1]) or {}) do
                    if type(fn) == "function" and not seen[fn] then queue[#queue + 1] = { fn, item[2] + 1, item[3] } end
                end
            end
        end
    end
end

function R:RefreshSteering(force)
    if not self.Options.Steering or self.Options.SteeringMethod ~= "Hook" then
        self:RestoreHooks("Steering")
        self:RefreshSteeringRotation(force)
        if self.Options.Steering then
            self:RuntimeModule("SteeringLookBack", at(Player, { "PlayerScripts", "Client", "LookBack" }), function() end)
        end
        self.Status.steering = self.Options.Steering and "Loop mode" or "Off"
        return
    end
    local state, now = self.SteeringState, os.clock()
    if not force and now - state.lastBind < 1 then return end
    state.lastBind = now
    local target, owner, connection = self:LiveSprintMovement()
    local values = target and upvalues(target)
    -- UPDATE 16 applyMovement U4 calls tryFastWallStop(state, direction, speed).
    -- Verify the helper as well as the entry; no global Velocity read spoof.
    local helper, settings, look
    for _, value in pairs(values or {}) do
        if type(value) == "function" and hasConstants(value, { "hrp", "AssemblyLinearVelocity", "clamp" }) then helper = value end
        if sprintState(value) then settings = value end
        if type(value) == "table" and type(rawget(value, "getRealCameraCFrame")) == "function" then look = value end
    end
    if not helper then
        self:RestoreSteering()
        self:RefreshSteeringRotation(force)
        self.Status.steering = "Native hook unavailable; Loop mode is available"
        return
    end
    if state.target ~= target or state.helper ~= helper then self:RestoreSteering(); state.target, state.helper = target, helper end
    self:RefreshSteeringRotation(force)
    state.look, state.connection, state.owner = look, connection, owner
    local helperHook = self:HookFunction(helper, "Sprint steering direction", function(original, nativeState, direction, speed, ...)
        local frame = state.scopes[coroutine.running()]
        if not frame or frame.state ~= nativeState or type(nativeState) ~= "table"
            or nativeState.char ~= self.Character or nativeState.hrp ~= self.Root then
            return original(nativeState, direction, speed, ...)
        end
        if not self.Options.Steering or self.Options.SteeringMethod ~= "Hook"
            or not finite(speed) or speed <= 3 or not self:SteeringAllowed() then
            state.direction, state.lastApplied = nil, nil
            self:RestoreSteering(false)
            return original(nativeState, direction, speed, ...)
        end
        local desired = frame.direction or self:SteeringTurn(self:SteeringDirection(), frame.dt)
        if not desired then
            state.direction, state.lastApplied = nil, nil
            self:RestoreSteering(false)
            return original(nativeState, direction, speed, ...)
        end
        frame.direction = desired
        local result = table.pack(original(nativeState, desired, speed, ...))
        if not result[1] then
            local velocity = self.Root.AssemblyLinearVelocity
            self.Root.AssemblyLinearVelocity = Vector3.new(desired.X * speed, velocity.Y, desired.Z * speed)
            self:SteeringFacing(desired)
            if settings then settings.System.lastMoveDirection = desired end
            state.hits, state.lastApplied = (state.hits or 0) + 1, os.clock()
            result[1], result.n = true, math.max(1, result.n)
        else
            state.direction, state.lastApplied = nil, nil
            self:RestoreSteering(false)
        end
        return table.unpack(result, 1, result.n)
    end, owner, "Steering")
    local entryHook = self:HookFunction(target, "Sprint movement entry", function(original, nativeState, dt, ...)
        local thread = coroutine.running()
        local previous = state.scopes[thread]
        state.scopes[thread] = { state = nativeState, dt = dt }
        local result = table.pack(pcall(original, nativeState, dt, ...))
        state.scopes[thread] = previous
        if not result[1] then error(result[2], 0) end
        return table.unpack(result, 2, result.n)
    end, owner, "Steering")
    self.Status.steering = helperHook and entryHook and ((state.hits or 0) > 0
        and ("Hook | native turns: " .. state.hits) or "Hook bound | waiting for native movement")
        or "Executor cannot hook native steering; use Loop mode"
end

function R:RestoreVelocity()
    local root, motion = self.Root, self.Motion
    if root and root.Parent and motion.lastWritten and finite(motion.baseline) then
        local velocity = root.AssemblyLinearVelocity
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
        if horizontal.Magnitude > 0.001 and (horizontal - motion.lastWritten).Magnitude < 0.05 then
            local restored = horizontal.Unit * motion.baseline
            root.AssemblyLinearVelocity = Vector3.new(restored.X, velocity.Y, restored.Z)
        end
    end
    motion.lastWritten, motion.baseline = nil, nil
end

function R:RefreshCharacterParts()
    local character = Player.Character
    if character ~= self.Character then self:CharacterChanged(character); return end
    if not character then return end
    local root = child(character, "HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if root ~= self.Root then
        self:RemoveJitter()
        self:RestoreVelocity()
        self.Root = root
    end
    if humanoid ~= self.Humanoid then
        self:RestoreJump()
        self:RestoreSteering()
        self:StopEmote()
        self:StopOpeningAnimation()
        self:BindSkillAnimator(nil)
        self.Humanoid = humanoid
    end
end

function R:CharacterChanged(character)
    self:RemoveJitter()
    self:RestoreVelocity()
    self:RestoreJump()
    self:RestoreSteering()
    self.SteeringState.lastBind = -math.huge
    self:StopEmote()
    self:StopOpeningAnimation()
    self:BindSkillAnimator(nil)
    self.SkillPresentation.revision += 1
    self.SkillPresentation.identity = nil
    if self.Opening.connection then self.Opening.connection:Disconnect(); self.Opening.connection = nil end
    self.Opening.animator = nil
    self.RaceActions.replaySerial += 1
    self.RaceActions.queued, self.RaceActions.replayUntil = nil, nil
    self.RaceActions.ultimateSerial = (self.RaceActions.ultimateSerial or 0) + 1
    self.RaceActions.ultimateQueued, self.RaceActions.ultimateRecord = nil, nil
    self.RaceActions.ultimateAllClients, self.RaceActions.ultimateScene = nil, nil
    self.RaceActions.ultimateReplayUntil = nil
    self:ReleaseStamina()
    self.Stamina.root = nil
    self.Stamina.lastScan = -math.huge
    self.Root, self.Humanoid = nil, nil
    self.Character = character
    self.Motion.lastWritten, self.Motion.baseline = nil, nil
    if character then
        self:Spawn(function()
            local humanoid = character:WaitForChild("Humanoid", 5)
            local root = character:WaitForChild("HumanoidRootPart", 5)
            if self.Alive and self.Character == character then
                self.Humanoid, self.Root = humanoid, root
                self:RefreshSteering(true)
                self:RefreshCharacterSkills(true)
            end
        end)
    end
end

function R:TickMovement()
    local root, humanoid = self.Root, self.Humanoid
    if not root or not root.Parent or not humanoid or humanoid.Health <= 0 then return end
    if self.Options.Jump then
        if not self.JumpSnapshot or self.JumpSnapshot.humanoid ~= humanoid then
            self:RestoreJump()
            self.JumpSnapshot = { humanoid = humanoid, power = humanoid.JumpPower, height = humanoid.JumpHeight }
        end
        if humanoid.UseJumpPower then
            humanoid.JumpPower = self.Options.JumpPower
            self.JumpSnapshot.writtenPower = self.Options.JumpPower
        else
            humanoid.JumpHeight = self.Options.JumpHeight
            self.JumpSnapshot.writtenHeight = self.Options.JumpHeight
        end
    elseif self.JumpSnapshot then self:RestoreJump() end
    if not self.Options.Velocity or root.Anchored then return end
    local velocity = root.AssemblyLinearVelocity
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
    if horizontal.Magnitude < 0.1 then return end
    local native = horizontal.Magnitude
    local state = self.Stamina.root
    local system = sprintState(state) and rawget(state, "System")
    if system and finite(rawget(system, "speed")) and system.speed > 0 then
        native = system.speed
    elseif self.Motion.lastWritten and (horizontal - self.Motion.lastWritten).Magnitude < 0.05 then
        native = self.Motion.baseline or native
    end
    local speed = self.Options.VelocityMode == "Static" and self.Options.StaticSpeed
        or native * self.Options.Multiplier
    speed = math.clamp(speed, 0, 250)
    local nextHorizontal = horizontal.Unit * speed
    root.AssemblyLinearVelocity = Vector3.new(nextHorizontal.X, velocity.Y, nextHorizontal.Z)
    self.Motion.lastWritten, self.Motion.baseline = nextHorizontal, native
end

function R:TickVisuals(dt)
    self:RemoveJitter()
    local root, humanoid = self.Root, self.Humanoid
    if not root or not root.Parent or not humanoid or humanoid.Health <= 0 or root.Anchored then
        if self.SteerSnapshot then self:RestoreSteering(false) end
        return
    end
    if self.Options.Steering and self:SteeringAllowed() and self.Options.SteeringMethod == "Loop" then
        local direction = self:SteeringDirection()
        if direction then
            self:SteeringFacing(direction)
            local velocity = root.AssemblyLinearVelocity
            local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
            if speed > 3 then root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed) end
        else
            self.SteeringState.direction, self.SteeringState.lastApplied = nil, nil
            self:RestoreSteering(false)
        end
    elseif self.Options.Steering and self.Options.SteeringMethod == "Hook" and self:SteeringAllowed()
        and self.SteeringState.direction and os.clock() - (self.SteeringState.lastApplied or -math.huge) < 0.25 then
        self:SteeringFacing(self.SteeringState.direction)
    elseif self.SteerSnapshot then self:RestoreSteering(false) end
    local velocity = root.AssemblyLinearVelocity.Magnitude
    if self.Options.Jitter and velocity > self.Options.JitterThreshold then
        self.Motion.positive = not self.Motion.positive
        local offset = root.CFrame.RightVector * self.Options.JitterIntensity * (velocity / 100)
            * (self.Motion.positive and 1 or -1)
        root.CFrame += offset
        self.Motion.offset, self.Motion.offsetRoot = offset, root
    end
end

function R:TouchRaceTargets()
    if self.TouchPending then return end
    if not Cap.touch then self:Notify("Touch targets", "Executor has no firetouchinterest."); return end
    if not self.Root then self:Notify("Touch targets", "Wait for your character."); return end
    local targets, seen = {}, {}
    local function add(instance)
        if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) and not seen[instance] then
            seen[instance] = true; targets[#targets + 1] = instance
        end
    end
    for _, tag in ipairs({ "Checkpoint", "RaceCheckpoint", "FinishLine", "RaceFinish" }) do
        for _, instance in ipairs(CollectionService:GetTagged(tag)) do add(instance) end
    end
    -- Preserve the original touch feature, but never touch every unrelated
    -- hazard, purchase trigger and spawn pad in Workspace.
    for _, instance in ipairs(Workspace:GetDescendants()) do
        local name = instance.Name:lower():gsub("[%s_%-]", "")
        if (name == "finish" or name == "finishline" or name == "racefinish"
            or name:match("^checkpoint%d*$")) and instance:IsA("BasePart")
            and instance:FindFirstChildOfClass("TouchTransmitter") then add(instance) end
    end
    if #targets == 0 then self:Notify("Touch targets", "No identified finish/checkpoint touch parts found."); return end
    if #targets > 64 then self:Notify("Touch targets", "Too many ambiguous targets; no touches sent."); return end
    self.TouchPending = true
    local root = self.Root
    self:Spawn(function()
        for _, target in ipairs(targets) do
            if not self.Alive or self.Root ~= root or not root.Parent then break end
            local began = pcall(Cap.touch, root, target, 0)
            task.wait(0.05)
            if began then pcall(Cap.touch, root, target, 1) end
        end
        self.TouchPending = false
        self:Notify("Touch targets", tostring(#targets) .. " finish/checkpoint parts touched.")
    end)
end

function R:Report()
    local counts = {}
    for _, category in ipairs(self.CategoryOrder) do
        local localCount = 0
        for instance in pairs(self.Created[category]) do if instance.Parent then localCount += 1 end end
        counts[#counts + 1] = category .. ": " .. #self.Rows[category] .. " entries, " .. localCount .. " local previews"
    end
    return table.concat({
        "Ryu Racing " .. self.Version .. " | place " .. tostring(game.PlaceId),
        "Stamina: " .. self.Status.stamina,
        "Auto QTE: " .. self.Status.qte,
        "Emotes: " .. self.Status.emotes,
        "Quests: " .. self.Status.quests,
        "Opening: " .. self.Status.opening,
        "Skills: " .. self.Status.skills,
        "Spurts: " .. self.Status.spurts,
        "Zone replay: " .. self.Status.ultimate,
        "Zone scene: " .. self.Status.zoneScene,
        "Race summary: " .. self.Status.raceSummary,
        "Menu: " .. self.Status.menu,
        "Ownership: " .. self.Status.ownership,
        "Steering: " .. self.Status.steering,
        "Character: " .. self.Status.character,
        "Skill animations: " .. self.Status.skillAnimations,
        "Skill route: " .. tostring(self.SkillPresentation.routing or "off") .. " | native packets: " .. self.SkillPresentation.responses
            .. " | confirmed animation swaps: " .. self.SkillPresentation.swaps,
        "Last skill animation: " .. tostring(self.SkillPresentation.lastSource) .. " -> " .. tostring(self.SkillPresentation.lastTarget),
        "QTE calls: " .. self.QTE.calls .. " | function hooks installed: " .. self.QTE.hooks,
        "Capabilities: upvalues=" .. tostring(Cap.upvalues ~= nil)
            .. ", getupvalue=" .. tostring(Cap.getupvalue ~= nil)
            .. ", setupvalue=" .. tostring(Cap.setupvalue ~= nil)
            .. ", hookfunction=" .. tostring(Cap.hook ~= nil)
            .. ", newcclosure=" .. tostring(Cap.newc ~= nil)
            .. ", connections=" .. tostring(Cap.connections ~= nil) .. ", getgc=" .. tostring(Cap.gc ~= nil),
        table.concat(counts, "\n"),
        next(self.QTE.hookFailures) and ("Hook errors: " .. (function()
            local errors = {}
            for scope, err in pairs(self.QTE.hookFailures) do errors[#errors + 1] = scope .. ": " .. err end
            return table.concat(errors, "; ")
        end)()) or "Hook errors: none",
        #self.Errors > 0 and ("Recent errors:\n" .. table.concat(self.Errors, "\n")) or "No recorded runtime errors.",
    }, "\n")
end

function R:UpdateStatus()
    if not self.StatusControl then return end
    local content = "Stamina: " .. self.Status.stamina .. "\nAuto QTE: " .. self.Status.qte
        .. "\n" .. self.Status.catalog
    if content ~= self.LastStatusText then
        self.LastStatusText = content
        pcall(function() self.StatusControl:Set({ Title = "Live status", Content = content }) end)
    end
    if self.EmoteStatusControl then
        pcall(function() self.EmoteStatusControl:Set({ Title = "Emotes", Content = self.Status.emotes }) end)
    end
    if self.QTEStatusControl then
        pcall(function() self.QTEStatusControl:Set({ Title = "QTE status", Content = self.Status.qte }) end)
    end
    if self.OpeningStatusControl then
        pcall(function() self.OpeningStatusControl:Set({ Title = "Opening", Content = self.Status.opening }) end)
    end
    if self.MenuStatusControl then
        pcall(function() self.MenuStatusControl:Set({ Title = "Game menu", Content = self.Status.menu }) end)
    end
    if self.OwnershipStatusControl then
        pcall(function() self.OwnershipStatusControl:Set({ Title = "Earned items", Content = self.Status.ownership }) end)
    end
    if self.SteeringStatusControl then
        pcall(function() self.SteeringStatusControl:Set({ Title = "Steering", Content = self.Status.steering }) end)
    end
    if self.CharacterStatusControl then
        pcall(function() self.CharacterStatusControl:Set({ Title = "Equipped character", Content = self.Status.character }) end)
    end
    if self.SkillAnimationStatusControl then
        pcall(function() self.SkillAnimationStatusControl:Set({ Title = "Skill animations", Content = self.Status.skillAnimations }) end)
    end
    if self.RacePresentationStatusControl then
        pcall(function() self.RacePresentationStatusControl:Set({ Title = "Character presentation",
            Content = self.Status.zoneScene .. "\n" .. self.Status.raceSummary }) end)
    end
end

function R:Unload(skipLibrary)
    if not self.Alive then return end
    self.Alive = false
    self:BindSkillAnimator(nil)
    self:RestoreHooks()
    self:ReleaseValues()
    if self.ShakeMarker then self.ShakeMarker:Destroy(); self.ShakeMarker = nil end
    self.InventoryGeneration += 1
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    table.clear(self.Connections)
    local currentThread = coroutine.running()
    for thread in pairs(self.Tasks) do
        -- A started native cutscene must finish its own unanchor/effect cleanup.
        if thread ~= currentThread and thread ~= self.RaceActions.ultimateThread
            and not self.RacePresentation.localThreads[thread] then pcall(task.cancel, thread) end
    end
    table.clear(self.Tasks)
    self:RemoveJitter()
    self:RestoreVelocity()
    self:RestoreSteering()
    self:RestoreJump()
    self:StopEmote()
    self:StopOpeningAnimation()
    if self.Opening.connection then self.Opening.connection:Disconnect(); self.Opening.connection = nil end
    self:ReleaseStamina()
    self:RestorePatches()
    for _, category in ipairs(self.CategoryOrder) do self:RemoveLocalEntries(category) end
    table.clear(self.QTE.plans)
    if Env.RyuRacing == self then Env.RyuRacing = nil end
    if self.Library and not skipLibrary then pcall(function() self.Library:Destroy() end) end
end

-- Rayfield is kept, with native theme/config APIs and separate feature tabs.
local loaded, library = pcall(function()
    if Env.RyuRacingTestLibrary then return Env.RyuRacingTestLibrary end
    local source = game:HttpGet("https://sirius.menu/rayfield")
    local chunk, err = loadstring(source)
    if not chunk then error(err) end
    return chunk()
end)
if not loaded or type(library) ~= "table" then
    R:Unload(true)
    warn("[Ryu Racing] Interface could not load: " .. tostring(library))
    return
end
if type(Env.RyuRacing) == "table" and type(Env.RyuRacing.Unload) == "function" then
    pcall(function() Env.RyuRacing:Unload() end)
end
R.Library = library
Env.RyuRacing = R
local originalDestroy = library.Destroy
library.Destroy = function(self, ...)
    R:Unload(true)
    return originalDestroy(self, ...)
end

local function option(value)
    if type(value) == "table" then return value[1] end
    return value
end

-- Rayfield restores saved flags in separate tasks. An empty saved single
-- selection reaches Set before our callback and assigns Text = nil there.
-- Guard this window's controls before LoadConfiguration can call them.
function R:Dropdown(tab, settings, placeholder)
    local fallback = placeholder or option(settings.CurrentOption)
    local function choices(values)
        local result, seen = {}, {}
        if placeholder then result[1], seen[placeholder] = placeholder, true end
        for _, value in ipairs(type(values) == "table" and values or {}) do
            if type(value) == "string" and value ~= "" and not seen[value] then
                result[#result + 1], seen[value] = value, true
            end
        end
        if #result == 0 then result[1] = type(fallback) == "string" and fallback or "None" end
        return result
    end
    local function selection(value, current, values)
        value, current = option(value), option(current)
        if type(value) == "string" and table.find(values, value) then return value end
        if type(current) == "string" and table.find(values, current) then return current end
        if type(fallback) == "string" and table.find(values, fallback) then return fallback end
        return values[1]
    end
    settings.Options = choices(settings.Options)
    settings.CurrentOption = { selection(settings.CurrentOption, nil, settings.Options) }
    local control = tab:CreateDropdown(settings)
    local set, refresh = control.Set, control.Refresh
    control.Options, control.CurrentOption = settings.Options, settings.CurrentOption
    control.Set = function(subject, value)
        local values = choices(subject.Options)
        local selected = selection(value, subject.CurrentOption, values)
        subject.Options, subject.CurrentOption = values, { selected }
        return set(subject, { selected })
    end
    if type(refresh) == "function" then
        control.Refresh = function(subject, values, ...)
            values = choices(values)
            subject.CurrentOption = { selection(subject.CurrentOption, nil, values) }
            subject.Options = values
            return refresh(subject, values, ...)
        end
    end
    return control
end

local uiOK, uiError = pcall(function()
    local window = library:CreateWindow({
        Name = "Ryu Racing",
        LoadingTitle = "Rachie my baby!!!",
        LoadingSubtitle = "by Ryu Nanashi",
        Theme = "Amethyst",
        ConfigurationSaving = { Enabled = true, FolderName = "Ryu_Presents", FileName = "Uma_Racing_v2" },
        Discord = { Enabled = false },
        KeySystem = false,
    })
    R.Window = window
    local racing = window:CreateTab("Racing", 4483362458)
    local qte = window:CreateTab("Auto QTE", 4483362458)
    local unlocks = window:CreateTab("Unlocks", 4483362458)
    local cosmetics = window:CreateTab("Cosmetics", 4483362458)
    local emotes = window:CreateTab("Emotes", 4483362458)
    local skills = window:CreateTab("Skills", 4483362458)
    local movement = window:CreateTab("Movement", 4483362458)
    local settings = window:CreateTab("Settings", 7734053495)
    local function toggle(tab, key, name, callback)
        local control = tab:CreateToggle({
            Name = name, CurrentValue = R.Options[key], Flag = "Ryu2_" .. key,
            Callback = function(value)
                if not R.Alive then return end
                R.Options[key] = value == true
                if callback then callback(value == true) end
            end,
        })
        R.Controls[key] = control
        return control
    end
    local function slider(tab, key, name, minimum, maximum, increment, suffix)
        local initial = R.Options[key]
        local control = tab:CreateSlider({
            Name = name, Range = { minimum, maximum }, Increment = increment, Suffix = suffix,
            CurrentValue = R.Options[key], Flag = "Ryu2_" .. key,
            Callback = function(value)
                value = tonumber(value)
                if R.Alive and finite(value) then R.Options[key] = math.clamp(value, minimum, maximum) end
            end,
        })
        local set = control.Set
        control.Set = function(subject, value)
            value = tonumber(value)
            if not finite(value) then value = tonumber(R.Options[key]) end
            if not finite(value) then value = initial end
            return set(subject, math.clamp(value, minimum, maximum))
        end
        R.Controls[key] = control
        return control
    end
    local function dropdown(tab, key, name, options, callback)
        return R:Dropdown(tab, {
            Name = name, Options = options, CurrentOption = { R.Options[key] },
            MultipleOptions = false, Flag = key == "SteeringMethod" and "Ryu292_SteeringMethod" or ("Ryu2_" .. key),
            Callback = function(value)
                if R.Alive then
                    local selected = option(value)
                    if not table.find(options, selected) then return end
                    R.Options[key] = selected
                    if callback then callback() end
                end
            end,
        })
    end

    R.RaceHUDControl = racing:CreateParagraph({ Title = "Race info", Content = "Loading..." })
    racing:CreateSection("Base exploits")
    toggle(racing, "InfiniteStamina", "Infinite Stamina (Client)", function(value) R:SetStamina(value) end)
    R.StatusControl = racing:CreateParagraph({ Title = "Live status", Content = "Loading..." })
    toggle(racing, "Steering", "Steer Control", function(value)
        if not value then R:RestoreSteering() end
        R:RefreshSteering(true)
    end)
    dropdown(racing, "SteeringMethod", "Steer Mode (Hook / Loop)", { "Hook", "Loop" }, function()
        R:RestoreSteering(); R:RefreshSteering(true)
    end)
    dropdown(racing, "SteeringMode", "Steering direction", { "Camera", "Movement" })
    slider(racing, "SteeringTurnRate", "Steering Turn Speed (Hook)", 90, 1800, 90, "deg/s")
    dropdown(racing, "SteeringCameraAxis", "Camera steering axis", { "Game", "Inverted" })
    racing:CreateButton({ Name = "Refresh Steering Hook", Callback = function() R:RestoreSteering(); R:RefreshSteering(true) end })
    R.SteeringStatusControl = racing:CreateParagraph({ Title = "Steering", Content = "Off" })
    racing:CreateKeybind({
        Name = "Toggle Steer Control", CurrentKeybind = "V", HoldToInteract = false, Flag = "Ryu2_SteerKey",
        Callback = function()
            if R.Alive then R.Controls.Steering:Set(not R.Options.Steering) end
        end,
    })
    racing:CreateButton({ Name = "Touch Finish / Checkpoints", Callback = function() R:TouchRaceTargets() end })

    skills:CreateParagraph({
        Title = "Try the real skill first",
        Content = "Uses the same requests as F / G / R. Your server character supplies the kit. Watch the result below; sending a request alone doesn't confirm a skill.",
    })
    R.SkillStatusControl = skills:CreateParagraph({ Title = "Skill tests", Content = "Join a race to test your current kit." })
    skills:CreateButton({ Name = "Try Ability (Native)", Callback = function() R:UseRaceAction("Ability", "Tap") end })
    skills:CreateButton({ Name = "Try Hold Ability (Native)", Callback = function() R:UseRaceAction("Ability", "Hold") end })
    skills:CreateButton({ Name = "Try Zone (Native)", Callback = function() R:UseRaceAction("Ultimate") end })
    skills:CreateButton({ Name = "Try Spurt (Native)", Callback = function() R:UseRaceAction("Spurt") end })
    skills:CreateSection("Equipped character animations")
    toggle(skills, "SpoofSkillAnimations", "Use Equipped Character Skill Animations", function() R:RefreshCharacterSkills(true) end)
    skills:CreateParagraph({ Title = "Skill animations", Content = "Uses available animations from the character you pressed Equip on. Your real kit still supplies skill effects, buffs and cooldowns." })
    R.SkillAnimationStatusControl = skills:CreateParagraph({ Title = "Skill animations", Content = "Equip a client character first" })
    skills:CreateButton({ Name = "Refresh Skill Animation Hooks", Callback = function() R:RefreshCharacterSkills(true) end })
    toggle(skills, "SpoofUltimateCutscene", "Use Equipped Character Zone Cutscene", function() R:RefreshRacePresentation() end)
    toggle(skills, "SpoofRaceSummary", "Use Equipped Character Summary Card", function() R:RefreshRacePresentation() end)
    R.RacePresentationStatusControl = skills:CreateParagraph({ Title = "Character presentation", Content = "Equip a client character first" })
    skills:CreateButton({ Name = "Refresh Race Hooks", Callback = function() R:RefreshRaceActions(); R:RefreshRacePresentation() end })
    skills:CreateSection("More spurts")
    toggle(skills, "InfiniteSpurts", "Repeat Spurts (Local)", function(value) R:SetInfiniteSpurts(value) end)
    skills:CreateParagraph({
        Title = "Native first, local fallback",
        Content = "Press your usual spurt key, mobile button, or Try Spurt. If the native dash doesn't arrive, repeats its local movement after the current burst. This does not refill server charges.",
    })
    skills:CreateSection("More zones")
    toggle(skills, "InfiniteUlt", "Repeat Zones (Local)", function(value) R:SetInfiniteUlt(value) end)
    slider(skills, "UltReplayGap", "Client Zone Replay Gap", 3, 120, 1, "s")
    skills:CreateParagraph({ Title = "Local zone replay",
        Content = "Press the zone key, mobile button, or Try Zone. Uses your equipped local cutscene; otherwise capture a real zone first. Scene playback does not grant server buffs. Summary cards follow your local character; earned XP, mastery and race results stay real." })

    racing:CreateSection("Race helpers")
    toggle(racing, "AutoReady", "Auto Ready", function() R:TickExtras() end)
    toggle(racing, "AutoClaimQuests", "Auto Claim Completed Quests", function() R:TickExtras() end)
    racing:CreateButton({ Name = "Claim Completed Quests", Callback = function() R:ClaimQuests(true) end })
    R.QuestStatusControl = racing:CreateParagraph({ Title = "Quests", Content = "Loading..." })

    qte:CreateSection("QTE")
    toggle(qte, "AutoQTE", "Auto QTE", function(value) R:SetAutoQTE(value) end)
    dropdown(qte, "QTEMethod", "QTE Method", { "Spoof", "Timing" })
    toggle(qte, "QTEGate", "Gate QTE")
    toggle(qte, "QTERing", "Ultimate QTE")
    toggle(qte, "QTESkillCheck", "Skill Checks")
    qte:CreateParagraph({
        Title = "QTE Method",
        Content = "Spoof forces the client result. Timing waits for the hit window. Covers gates, ultimate rings and skill checks.",
    })
    R.QTEStatusControl = qte:CreateParagraph({ Title = "QTE status", Content = "Off" })
    qte:CreateButton({
        Name = "Refresh QTE",
        Callback = function()
            R.QTE.boundApi, R.QTE.lastGC = nil, -math.huge
            R:LoadPlayerModules(); R:ScanQTE(true); R:TickQTE(); R:UpdateStatus()
        end,
    })

    toggle(unlocks, "LocalMenuEquips", "Local Game Menu Equips", function() R:RefreshRequestHooks() end)
    R.MenuStatusControl = unlocks:CreateParagraph({ Title = "Game menu", Content = "Earned items use normal equips. Client extras stay local." })
    R.OwnershipStatusControl = unlocks:CreateParagraph({ Title = "Earned items", Content = "Reading your real inventory..." })
    unlocks:CreateButton({ Name = "Refresh Earned Items", Callback = function() R:RefreshOwnedData(true) end })
    unlocks:CreateButton({
        Name = "Unlock All (Client)",
        Callback = function()
            for _, category in ipairs(R.CategoryOrder) do
                if R.UnlockControls[category] then R.UnlockControls[category]:Set(true) end
            end
            R:Notify("Unlocks", "Reopen your collection or emote picker.")
        end,
    })
    toggle(unlocks, "RevealUnavailable", "Show Unreleased Characters", function() R:ApplyUnlocks() end)
    R.UnlockControls, R.Selectors, R.Selected = {}, {}, {}
    for _, category in ipairs(R.CategoryOrder) do
        local definition = R.Categories[category]
        R.UnlockControls[category] = unlocks:CreateToggle({
            Name = "Unlock All " .. definition.label .. " (Client)",
            CurrentValue = false, Flag = "Ryu2_Unlock_" .. category,
            Callback = function(value) if R.Alive then R:SetUnlock(category, value) end end,
        })
    end
    unlocks:CreateButton({ Name = "Refresh List", Callback = function() R:LoadCatalogs(); R:RebuildCatalog() end })
    unlocks:CreateButton({
        Name = "Reset Client Unlocks",
        Callback = function()
            for _, control in pairs(R.UnlockControls) do control:Set(false) end
        end,
    })

    cosmetics:CreateParagraph({
        Title = "Client cosmetics",
        Content = "Spoofs change your local cosmetics. Saved ownership and race abilities stay server-side.",
    })
    local labels = { Characters = "Character", Titles = "Title", MVPs = "Outro / MVP", Intros = "Opening", Banners = "Banner" }
    for _, category in ipairs({ "Characters", "Titles", "MVPs", "Intros", "Banners" }) do
        cosmetics:CreateSection(labels[category])
        R.Selectors[category] = R:Dropdown(cosmetics, {
            Name = "Select " .. labels[category], Options = { "Loading..." },
            CurrentOption = {}, MultipleOptions = false, Flag = "Ryu22_Select_" .. category,
            Callback = function(value)
                if not R.Alive then return end
                local row = R:FindRow(category, option(value))
                R.Selected[category] = row and row.label or nil
                if category ~= "Characters" and R.Spoofs[category] then R:ApplySpoof(category) end
                if category == "Intros" and R.Spoofs.Intros then R:RefreshOpening() end
                if category == "Titles" and R.Spoofs.Titles then R:RefreshTitleDisplay() end
                if category == "Characters" then R:UpdateCharacterInfo() end
            end,
        }, "Select " .. labels[category])
        toggle(cosmetics, "Spoof" .. category, "Spoof " .. labels[category], function(value) R:SetSpoof(category, value) end)
        if category == "Characters" then
            R.CharacterInfoControl = cosmetics:CreateParagraph({ Title = "Character kit", Content = "Pick a character to see its kit." })
            cosmetics:CreateParagraph({ Title = "Character selection", Content = "Browse characters above, then press Equip. Owned characters equip normally in the lobby; client unlocks equip locally." })
            cosmetics:CreateButton({ Name = "Equip Character", Callback = function() R:EquipSelectedCharacter() end })
            R.CharacterStatusControl = cosmetics:CreateParagraph({ Title = "Equipped character", Content = "Select a character, then press Equip" })
        elseif category == "Intros" then
            R.OpeningStatusControl = cosmetics:CreateParagraph({ Title = "Opening", Content = "Off" })
            cosmetics:CreateButton({ Name = "Preview Opening Animation", Callback = function() R:PlayOpeningAnimation(true) end })
            cosmetics:CreateButton({ Name = "Stop Opening Preview", Callback = function() R:StopOpeningAnimation() end })
        end
    end
    cosmetics:CreateButton({
        Name = "Reset All Spoofs",
        Callback = function()
            for category in pairs(R.CosmeticPaths) do R.Controls["Spoof" .. category]:Set(false) end
        end,
    })

    emotes:CreateButton({ Name = "Unlock All Emotes", Callback = function() R.UnlockControls.Emotes:Set(true) end })
    R.Selectors.Emotes = R:Dropdown(emotes, {
        Name = "Emote", Options = { "Loading..." }, CurrentOption = {}, MultipleOptions = false, Flag = "Ryu22_Emote",
        Callback = function(value)
            if R.Alive then
                local row = R:FindRow("Emotes", option(value))
                R.Selected.Emotes = row and row.label or nil
            end
        end,
    }, "Select Emote")
    emotes:CreateButton({ Name = "Play Emote", Callback = function() R:PreviewEmote() end })
    emotes:CreateButton({ Name = "Random Emote", Callback = function()
        if #R.Rows.Emotes > 0 then R:PlayEmote(R.Rows.Emotes[math.random(1, #R.Rows.Emotes)]) end
    end })
    emotes:CreateButton({ Name = "Stop Local Emote", Callback = function() R:StopEmote() end })
    toggle(emotes, "EmoteLoop", "Loop Emote", function() R:UpdateEmotePlayback() end)
    emotes:CreateSlider({
        Name = "Emote Speed", Range = { 0.1, 3 }, Increment = 0.1, Suffix = "x", CurrentValue = R.Options.EmoteSpeed,
        Flag = "Ryu22_EmoteSpeed", Callback = function(value)
            if R.Alive then R.Options.EmoteSpeed = value; R:UpdateEmotePlayback() end
        end,
    })
    emotes:CreateSlider({
        Name = "Emote Volume", Range = { 0, 2 }, Increment = 0.1, Suffix = "x", CurrentValue = R.Options.EmoteVolume,
        Flag = "Ryu22_EmoteVolume", Callback = function(value)
            if R.Alive then R.Options.EmoteVolume = value; R:UpdateEmotePlayback() end
        end,
    })
    emotes:CreateSection("Emote wheel")
    toggle(emotes, "EmoteHotkeys", "Emote Number Keys")
    emotes:CreateParagraph({ Title = "Emote controls", Content = "1–4 follow the open wheel page. 1–8 play slots when it's closed. Move, jump or press Escape to stop a local emote." })
    dropdown(emotes, "EmoteSlot", "Wheel Slot", { "1", "2", "3", "4", "5", "6", "7", "8" })
    emotes:CreateButton({ Name = "Put Selected Emote In Slot", Callback = function()
        local row = R:SelectedRow("Emotes")
        if not row then R:Notify("Emote", "Pick an emote first."); return end
        R.UnlockControls.Emotes:Set(true)
        if R:AssignEmoteSlot(R.Options.EmoteSlot, row.key) then R:RefreshNativeEmotes() end
    end })
    emotes:CreateButton({ Name = "Reset Wheel Slots", Callback = function()
        R:ReleaseValues("EmoteSlot:"); table.clear(R.EmoteSlots); R:RefreshNativeEmotes()
    end })
    R.EmoteStatusControl = emotes:CreateParagraph({ Title = "Emotes", Content = "Off" })

    movement:CreateSection("Velocity")
    toggle(movement, "Velocity", "Velocity Control", function(value)
        R:RestoreVelocity()
        if value then R:BindStamina(true) end
    end)
    dropdown(movement, "VelocityMode", "Velocity mode", { "Multiplier", "Static" })
    slider(movement, "Multiplier", "Speed Multiplier", 1, 3, 0.1, "x")
    slider(movement, "StaticSpeed", "Static horizontal speed", 10, 200, 1, "stud/s")
    movement:CreateSection("Jump control")
    toggle(movement, "Jump", "Override jump", function(value) if not value then R:RestoreJump() end end)
    slider(movement, "JumpPower", "Jump power (UseJumpPower enabled)", 0, 150, 1, "")
    slider(movement, "JumpHeight", "Jump height (UseJumpPower disabled)", 0, 50, 0.1, "studs")
    movement:CreateSection("Visual jitter")
    toggle(movement, "Jitter", "Velocity Jitter", function(value) if not value then R:RemoveJitter() end end)
    slider(movement, "JitterIntensity", "Jitter intensity", 0.1, 2, 0.1, "x")
    slider(movement, "JitterThreshold", "Jitter activation speed", 0, 200, 5, "stud/s")

    settings:CreateSection("Camera / sound")
    toggle(settings, "NoShake", "No Screen / Stamina Shake", function() R:TickExtras() end)
    toggle(settings, "SteadyCamera", "Steady Camera", function() R:TickExtras() end)
    toggle(settings, "MuteCommentary", "Mute Commentary", function() R:TickExtras() end)
    toggle(settings, "OverrideFOV", "Lock FOV", function() R:TickExtras() end)
    settings:CreateSlider({
        Name = "FOV", Range = { 40, 120 }, Increment = 1, CurrentValue = R.Options.FOV, Flag = "Ryu22_FOV",
        Callback = function(value) if R.Alive then R.Options.FOV = value; R:TickExtras() end end,
    })
    settings:CreateSection("Interface")
    R:Dropdown(settings, {
        Name = "Interface Theme",
        Options = { "Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity" },
        CurrentOption = { "Amethyst" }, MultipleOptions = false, Flag = "Ryu22_Theme",
        Callback = function(value)
            local theme = option(value)
            if R.Alive and type(window.ModifyTheme) == "function" then window.ModifyTheme(theme) end
        end,
    })
    settings:CreateButton({
        Name = "Copy Debug Info",
        Callback = function()
            local report = R:Report()
            if Cap.clipboard then
                local ok, err = pcall(Cap.clipboard, report)
                if ok then R:Notify("Diagnostics", "Copied."); else R:Error("Clipboard", err) end
            else
                print(report); R:Notify("Diagnostics", "Clipboard unavailable; report printed to the console.")
            end
        end,
    })
    settings:CreateButton({
        Name = "Copy Discord Link",
        Callback = function()
            if Cap.clipboard then pcall(Cap.clipboard, "https://discord.gg/njy8U2kVr9")
            else R:Notify("Discord", "discord.gg/njy8U2kVr9") end
        end,
    })
    settings:CreateButton({
        Name = "Infinite Yield Reborn",
        Callback = function()
            R:Spawn(function()
                local source = game:HttpGet("https://raw.githubusercontent.com/mxsynry/infiniteyield-reborn/refs/heads/master/source")
                local chunk, err = loadstring(source)
                if not chunk then error(err) end
                chunk()
            end)
        end,
    })
    settings:CreateButton({ Name = "Unload", Callback = function() R:Unload() end })
end)
if not uiOK then
    R:Error("Interface", uiError)
    R:Unload()
    return
end

R:Connect(Player.CharacterAdded, function(character) R:CharacterChanged(character) end)
R:Connect(Player.CharacterRemoving, function(character)
    if R.Character == character then R:CharacterChanged(nil) end
end)
R:CharacterChanged(Player.Character)
R:LoadPlayerModules()
R:LoadCatalogs()
R:RefreshRequestHooks()
R:RefreshEmoteBridge(false)
R:RefreshOwnedData(true)
R:Connect(UserInputService.InputBegan, function(input, processed)
    R:EmoteInput(input, processed)
    R:RaceReplayInput(input, processed)
end)
R:Connect(UserInputService.JumpRequest, function() if R.Alive then R:StopEmote() end end)

R:Connect(RunService.PreSimulation, function()
    if R.Alive then R:TickStamina() end
end)
R:Connect(RunService.Heartbeat, function()
    if not R.Alive then return end
    R:TickStamina()
    R:TickEmote()
    R:TickSkillAnimations()
    R:RefreshRaceSummaryUI()
    R:TickMovement()
    local now = os.clock()
    if now - R.LastMaintenance >= 1 then
        R.LastMaintenance = now
        R:RefreshCharacterParts()
        R:LoadPlayerModules()
        R:LoadCatalogs()
        R:RefreshOwnedData(false)
        R:ApplySpoofs()
        R:RefreshCharacterSkills(false)
        R:RefreshRacePresentation()
        R:RefreshSteering(false)
        R:RefreshOpening()
        R:RefreshTitleDisplay()
        R:RefreshEmoteBridge(false)
        R:TickRaceActions()
        R:TickExtras()
        R:UpdateRaceHUD()
        if R.CatalogDirty then R:RebuildCatalog() end
        -- Reconcile local entries if a replicated inventory folder was replaced.
        local missing = false
        for _, category in ipairs(R.CategoryOrder) do
            if R.Unlocks[category] and R.Categories[category].path then
                local folder = at(Player, R.Categories[category].path)
                for instance in pairs(R.Created[category]) do
                    if not folder or instance.Parent ~= folder then
                        pcall(function() instance:Destroy() end)
                        R.Created[category][instance] = nil
                        missing = true
                    end
                end
                if folder ~= (R.InventoryFolders and R.InventoryFolders[category]) then missing = true end
            end
        end
        if missing then
            R.InventoryFolders = {}
            for _, category in ipairs(R.CategoryOrder) do
                local path = R.Categories[category].path
                if path then R.InventoryFolders[category] = at(Player, path) end
            end
            R:ApplyUnlocks()
        end
        R:UpdateStatus()
    end
end)
R:Connect(RunService.RenderStepped, function(dt)
    if not R.Alive then return end
    R:TickVisuals(dt)
    R:TickQTE()
end)

if type(library.LoadConfiguration) == "function" then
    R:Spawn(function()
        local deadline = os.clock() + 8
        repeat
            local pending, available = false, false
            for _, key in ipairs({ "UmaConfig", "CharactersUma", "NameTagList", "MVPList", "IntroList", "BannerConfig", "EmoteList" }) do
                local record = R.Modules[key]
                if record and record.pending then pending = true end
                if record and record.value then available = true end
            end
            if available and not pending then break end
            task.wait(0.05)
            R:LoadCatalogs()
        until os.clock() >= deadline or not R.Alive
        if not R.Alive then return end
        -- Populate live dropdown options before Rayfield applies saved choices.
        R:RebuildCatalog()
        local ok, err = pcall(function() library:LoadConfiguration() end)
        if not ok then R:Error("Saved settings", err) end
        R:RefreshSteering(true)
    end)
end
R:Notify("Script Loaded", "Oji-san is too old for racing, so i made a script for it uhehe!")
return R
