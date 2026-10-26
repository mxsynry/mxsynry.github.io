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
    connections = capability("getconnections"),
    gc = capability("getgc"),
    fenv = capability("getfenv") or getfenv,
    clipboard = capability("setclipboard") or capability("toclipboard"),
    touch = capability("firetouchinterest"),
}

local R = {
    Version = "2.1.0",
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
    Controls = {},
    Status = { stamina = "Off", qte = "Off", catalog = "Loading game catalogs" },
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

function R:HookFunction(fn, scope, handler, object)
    if self.Hooks[fn] then return self.Hooks[fn] end
    if not Cap.hook or type(fn) ~= "function" then return nil end
    local record = { target = fn, scope = scope, object = object, active = true }
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
    local ok, err = pcall(Cap.hook, record.target, record.original)
    self.Hooks[record.target] = nil
    if not ok then self:Error("Restore " .. record.scope, err) end
end

function R:RestoreQTEHooks()
    local records = {}
    for _, record in pairs(self.Hooks) do records[#records + 1] = record end
    for _, record in ipairs(records) do self:RestoreHook(record) end
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
    return numberValue(at(Player, { "Info", "Stamina" })),
        numberValue(at(Player, { "Info", "MaxStamina" }))
end

function R:ReleaseStamina()
    local state = self.Stamina
    if state.system then
        local actual = self:StaminaSource()
        local restore = actual or state.observed
        if finite(restore) and rawget(state.system, "stamina") == state.written then
            pcall(rawset, state.system, "stamina", restore)
        end
    end
    state.system, state.observed, state.written = nil, nil, nil
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
                    if sprintState(value) then state.root = value; return end
                end
            end
        end
    end
    if sprintState(state.root) then return end
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
            if found then state.root = found; return end
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
    rawset(system, "stamina", maximum)
    state.written = maximum
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
        if record.object and typeof(record.object) == "Instance"
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
    MVPs = { label = "MVP animations", path = { "MVPData", "Inventory" } },
    Intros = { label = "Race intros", path = { "IntroData", "Inventory" } },
    Banners = { label = "Banners", path = { "ThumbnailData", "Inventory" } },
    Emotes = { label = "Emote previews", previewOnly = true },
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
end

function R:RemoveLocalEntries(category)
    for instance in pairs(self.Created[category]) do
        pcall(function() instance:Destroy() end)
    end
    table.clear(self.Created[category])
end

function R:ApplyUnlocks()
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
                            instance.Name = "__RyuLocal_" .. row.key
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
    self.Unlocks[category] = enabled == true
    self:ApplyUnlocks()
end

function R:IsRealOwned(row)
    local definition = self.Categories[row.category]
    local folder = definition.path and at(Player, definition.path)
    if not folder then return false end
    for _, instance in ipairs(folder:GetChildren()) do
        if instance:IsA("StringValue") and instance.Value == row.value
            and not self.Created[row.category][instance] then return true end
    end
    return false
end

function R:RefreshSelectors()
    for category, control in pairs(self.Selectors or {}) do
        local options = {}
        for _, row in ipairs(self.Rows[category]) do options[#options + 1] = row.label end
        if #options == 0 then options = { "Catalog not available yet" } end
        pcall(function() control:Refresh(options) end)
    end
end

function R:SelectedRow(category)
    local selection = self.Selected and self.Selected[category]
    for _, row in ipairs(self.Rows[category]) do
        if row.label == selection then return row end
    end
    return nil
end

function R:EquipCharacter()
    if self.EquipPending then self:Notify("Character", "Still equipping. Give it a second."); return end
    local row = self:SelectedRow("Characters")
    if not row then self:Notify("Character", "Pick a character first."); return end
    local character = Player.Character
    if character and child(character, "InfoPlaying") then
        self:Notify("Character", "Change characters from the lobby, after the race.")
        return
    end
    local current = child(Player, "CurrentCharacter")
    local remote = at(ReplicatedStorage, { "remotes", "SaveCharacter" })
    if not current or not current:IsA("StringValue") or not remote or not remote:IsA("RemoteEvent") then
        self:Notify("Character", "Couldn't find the equip remote.")
        return
    end
    if current.Value == row.value then self:Notify("Character", row.value .. " is already equipped."); return end
    self.EquipPending = true
    self:Spawn(function()
        local ok, err = pcall(function() remote:FireServer(row.value) end)
        if not ok then
            self.EquipPending = false
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
            self:Notify("Character equipped", row.value .. " equipped.")
        else
            self:Notify("Equip not confirmed",
                "The server didn't equip " .. row.value .. ". It may only be unlocked on your client.")
        end
    end)
end

function R:StopEmote()
    if self.EmoteTrack then pcall(function() self.EmoteTrack:Stop(0.15); self.EmoteTrack:Destroy() end) end
    if self.EmoteAnimation then pcall(function() self.EmoteAnimation:Destroy() end) end
    self.EmoteTrack, self.EmoteAnimation = nil, nil
end

function R:PreviewEmote()
    local row = self:SelectedRow("Emotes")
    local humanoid = self.Humanoid
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not row or not animator then self:Notify("Emote", "Choose an emote while your character is loaded."); return end
    local id = row.data.MainAnimation or row.data.IdleAnimation
    if type(id) ~= "number" and type(id) ~= "string" then self:Notify("Emote", "No playable animation in this entry."); return end
    self:StopEmote()
    local animation = Instance.new("Animation")
    animation.AnimationId = tostring(id):match("^rbxassetid://") and tostring(id) or "rbxassetid://" .. tostring(id)
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    if not ok then animation:Destroy(); self:Error("Emote preview", track); return end
    self.EmoteAnimation, self.EmoteTrack = animation, track
    track.Looped = true
    track:Play(0.15)
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

function R:RestoreSteering()
    local snapshot = self.SteerSnapshot
    if snapshot and snapshot.humanoid.Parent then
        pcall(function() snapshot.humanoid.AutoRotate = snapshot.autoRotate end)
    end
    self.SteerSnapshot = nil
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
        self.Humanoid = humanoid
    end
end

function R:CharacterChanged(character)
    self:RemoveJitter()
    self:RestoreVelocity()
    self:RestoreJump()
    self:RestoreSteering()
    self:StopEmote()
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
            if self.Alive and self.Character == character then self.Humanoid, self.Root = humanoid, root end
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

function R:TickVisuals()
    self:RemoveJitter()
    local root, humanoid = self.Root, self.Humanoid
    if not root or not root.Parent or not humanoid or humanoid.Health <= 0 or root.Anchored then
        if self.SteerSnapshot then self:RestoreSteering() end
        return
    end
    if self.Options.Steering then
        local direction = humanoid.MoveDirection
        if self.Options.SteeringMode == "Camera" and Workspace.CurrentCamera then
            direction = Workspace.CurrentCamera.CFrame.LookVector
        end
        direction = Vector3.new(direction.X, 0, direction.Z)
        if direction.Magnitude > 0.001 then
            if not self.SteerSnapshot then self.SteerSnapshot = { humanoid = humanoid, autoRotate = humanoid.AutoRotate } end
            humanoid.AutoRotate = false
            root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
        end
    elseif self.SteerSnapshot then self:RestoreSteering() end
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
        "QTE calls: " .. self.QTE.calls .. " | hooks installed: " .. self.QTE.hooks,
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
    if self.QTEStatusControl then
        pcall(function() self.QTEStatusControl:Set({ Title = "QTE status", Content = self.Status.qte }) end)
    end
end

function R:Unload(skipLibrary)
    if not self.Alive then return end
    self.Alive = false
    self:RestoreQTEHooks()
    self.InventoryGeneration += 1
    for _, connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    table.clear(self.Connections)
    local currentThread = coroutine.running()
    for thread in pairs(self.Tasks) do if thread ~= currentThread then pcall(task.cancel, thread) end end
    table.clear(self.Tasks)
    self:RemoveJitter()
    self:RestoreVelocity()
    self:RestoreSteering()
    self:RestoreJump()
    self:StopEmote()
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
    return type(value) == "table" and value[1] or value
end

local uiOK, uiError = pcall(function()
    local window = library:CreateWindow({
        Name = "Ryu Racing",
        LoadingTitle = "Rachie my baby!!!",
        LoadingSubtitle = "by Ryu Nanashi",
        Theme = "Default",
        ConfigurationSaving = { Enabled = true, FolderName = "Ryu_Presents", FileName = "Uma_Racing_v2" },
        Discord = { Enabled = false },
        KeySystem = false,
    })
    R.Window = window
    local racing = window:CreateTab("Racing", 4483362458)
    local qte = window:CreateTab("Auto QTE", 4483362458)
    local unlocks = window:CreateTab("Unlocks", 4483362458)
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
        return tab:CreateSlider({
            Name = name, Range = { minimum, maximum }, Increment = increment, Suffix = suffix,
            CurrentValue = R.Options[key], Flag = "Ryu2_" .. key,
            Callback = function(value) if R.Alive then R.Options[key] = value end end,
        })
    end
    local function dropdown(tab, key, name, options)
        return tab:CreateDropdown({
            Name = name, Options = options, CurrentOption = { R.Options[key] },
            MultipleOptions = false, Flag = "Ryu2_" .. key,
            Callback = function(value) if R.Alive then R.Options[key] = option(value) end end,
        })
    end

    racing:CreateSection("Base exploits")
    toggle(racing, "InfiniteStamina", "Infinite Stamina", function(value) R:SetStamina(value) end)
    R.StatusControl = racing:CreateParagraph({ Title = "Live status", Content = "Loading..." })
    toggle(racing, "Steering", "Steer Control", function(value) if not value then R:RestoreSteering() end end)
    dropdown(racing, "SteeringMode", "Steering direction", { "Camera", "Movement" })
    racing:CreateKeybind({
        Name = "Toggle Steer Control", CurrentKeybind = "V", HoldToInteract = false, Flag = "Ryu2_SteerKey",
        Callback = function()
            if R.Alive then R.Controls.Steering:Set(not R.Options.Steering) end
        end,
    })
    racing:CreateButton({ Name = "Touch Finish / Checkpoints", Callback = function() R:TouchRaceTargets() end })

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

    unlocks:CreateParagraph({
        Title = "Unlocks",
        Content = "Shows everything on your client. Saved ownership and equipping still depend on the server.",
    })
    unlocks:CreateButton({
        Name = "Unlock All (Client)",
        Callback = function()
            for _, category in ipairs(R.CategoryOrder) do
                if category ~= "Emotes" then
                    R.Unlocks[category] = true
                    if R.UnlockControls[category] then R.UnlockControls[category]:Set(true) end
                end
            end
            R:ApplyUnlocks()
            R:Notify("Unlocks", "Reopen your collection to see everything.")
        end,
    })
    toggle(unlocks, "RevealUnavailable", "Show Unreleased Characters", function() R:ApplyUnlocks() end)
    R.UnlockControls, R.Selectors, R.Selected = {}, {}, {}
    for _, category in ipairs(R.CategoryOrder) do
        local definition = R.Categories[category]
        unlocks:CreateSection(definition.label)
        if definition.path then
            R.UnlockControls[category] = unlocks:CreateToggle({
                Name = "Unlock All " .. definition.label .. " (Client)",
                CurrentValue = false, Flag = "Ryu2_Unlock_" .. category,
                Callback = function(value) if R.Alive then R:SetUnlock(category, value) end end,
            })
        end
        R.Selectors[category] = unlocks:CreateDropdown({
            Name = "Browse " .. definition.label:lower(), Options = { "Catalog not available yet" },
            CurrentOption = {}, MultipleOptions = false,
            Callback = function(value) R.Selected[category] = option(value) end,
        })
        if category == "Characters" then
            unlocks:CreateButton({ Name = "Equip Character", Callback = function() R:EquipCharacter() end })
        elseif category == "Emotes" then
            unlocks:CreateButton({ Name = "Play Emote", Callback = function() R:PreviewEmote() end })
            unlocks:CreateButton({ Name = "Stop Emote", Callback = function() R:StopEmote() end })
        end
    end
    unlocks:CreateButton({
        Name = "Refresh List",
        Callback = function() R:LoadCatalogs(); R:RebuildCatalog() end,
    })
    unlocks:CreateButton({
        Name = "Reset Client Unlocks",
        Callback = function()
            for _, category in ipairs(R.CategoryOrder) do
                R.Unlocks[category] = false
                if R.UnlockControls[category] then R.UnlockControls[category]:Set(false) end
            end
            R:ApplyUnlocks()
        end,
    })

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

    settings:CreateDropdown({
        Name = "Interface Theme",
        Options = { "Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity" },
        CurrentOption = { "Default" }, MultipleOptions = false, Flag = "Ryu2_Theme",
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

R:Connect(RunService.PreSimulation, function()
    if R.Alive then R:TickStamina() end
end)
R:Connect(RunService.Heartbeat, function()
    if not R.Alive then return end
    R:TickStamina()
    R:TickMovement()
    local now = os.clock()
    if now - R.LastMaintenance >= 1 then
        R.LastMaintenance = now
        R:RefreshCharacterParts()
        R:LoadPlayerModules()
        R:LoadCatalogs()
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
R:Connect(RunService.RenderStepped, function()
    if not R.Alive then return end
    R:TickVisuals()
    R:TickQTE()
end)

if type(library.LoadConfiguration) == "function" then
    local ok, err = pcall(function() library:LoadConfiguration() end)
    if not ok then R:Error("Saved settings", err) end
end
R:Notify("Script Loaded", "Oji-san is too old for racing, so i made a script for it uhehe!")
return R
