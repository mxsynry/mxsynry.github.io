--[[
    Block Tales | mxsynry

    Credits
    mxsynry - original script combination and optimization, persistent toggles,
        layered AutoGuard hook handling and enemy-only Godmode selection.
    TexRBLX - the Tex tab implementations: Auto Guard, Auto Sword, Auto Launcher,
        Auto Dynamite/Slingshot, Auto Superball, Auto Linebounce, collectible
        teleports, enemy targeting, Godmode, fishing, CFrame speed boost and
        premium/donator animation-flavor controls.
    7GrandDadPGN (7GrandDad) - Vape's Block Tales module implementations:
        AutoAction, MissCooldown, AntiHazard, Fly, FlyingAttack, LongJump,
        PickupTP, Speed, SpeedSpin, PickupTracers, AutoCamel, AutoCloudGrind,
        AutoFish and AutoPaint, including their original settings and timing.
    kaiserdegurechaff - the HUD color-based AutoGreen / Space-hold source.
    laryngotracheobronchitis - the upstream AlwaysPerfect script.
    testingtesting999 - the ScriptBlox publication linking to AlwaysPerfect;
        credited separately from its source author.
    Sirius - the Rayfield interface library.
    Codex, under mxsynry's direction - readable Tex source recovery, local
        embedding, Vape ports, Rayfield adapters, runtime cleanup and the
        shared climbing-aware speed backend.

    Additional credits preserved from the original script: Kronerzz,
    VeinnsDaCheesecake, CloudHub111 and @IDKWHATUSERNAME.
    Their individual source snippets were not labeled in the supplied script.

    Execute this file once, then use the separate mxsynry, Tex and Vape tabs.
    ToggleBlessed remains an alias for ToggleAutoGuardHook.
    Speed uses WalkSpeed on ladders and during an airborne ladder exit.
    Feature code is embedded; Rayfield is the only downloaded interface.
]]

-- === 1. Configuration and saved settings ===

local DEFAULT_CONFIG = {
    NotificationEnabled = true,
    FakerMonitorEnabled = false,
    Layers = 4,
    BlessedHookMode = "Layered", -- "Single" is optional, pending live testing.
    BlessedMethod = "Auto", -- Observe the first Blessed read method on faker.
    LoadTexScript = true, -- Load embedded Tex features and the Rayfield window.
    DependencyTimeout = 12,
    AutoGreenMode = "Legacy", -- Optional: "Battle", or "Auto" with fallback.
    BattleAttackEnabled = true,
    BattleBlockEnabled = true,
    PressWindowScale = 0.3,
    GodmodeMoveAllowList = {}, -- Empty = original heuristic; otherwise exact names.
    PersistSettings = true,
    SettingsFile = "mxsynry_block_tales_settings.json",
}

local ENV = type(getgenv) == "function" and getgenv() or _G
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function number(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function disconnect(connection)
    if connection then pcall(function() connection:Disconnect() end) end
end
local function child(parent, name)
    if not parent then return nil end
    local ok, result = pcall(function() return parent:FindFirstChild(name) end)
    return ok and result or nil
end
local function attribute(object, name)
    local ok, value = pcall(function() return object:GetAttribute(name) end)
    return ok and value or nil
end
local function service(name)
    local ok, result = pcall(function() return game:GetService(name) end)
    return ok and result or nil
end
local Services = {
    Players = service("Players"), ReplicatedFirst = service("ReplicatedFirst"),
    ReplicatedStorage = service("ReplicatedStorage"), RunService = service("RunService"),
    HttpService = service("HttpService"), StarterGui = service("StarterGui"),
    VirtualInputManager = service("VirtualInputManager"),
    UserInputService = service("UserInputService"), GuiService = service("GuiService"),
    CollectionService = service("CollectionService"),
}
local BT = type(ENV._BT) == "table" and ENV._BT or {}
ENV._BT = BT

-- Upgrade an already-running old copy without leaving its listeners active.
ENV.BlessedHookEnabled = false
ENV.AutoGreenEnabled = false
if type(BT.Runtime) == "table" and type(BT.Runtime.Unload) == "function" then
    BT.Runtime:Unload(true)
else
    if BT.HookedFaker and type(BT.HookGroups) ~= "table" then BT.LegacyHooksPresent = true end
    BT.GodmodeEnabled = false
    disconnect(BT.AutoGreenConnection)
    for _, connection in pairs(BT.Connections or {}) do disconnect(connection) end
    if BT.FakerMonitor then pcall(task.cancel, BT.FakerMonitor) end
    if BT.IsHoldingSpace and Services.VirtualInputManager then
        pcall(function()
            Services.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
    for move, original in pairs(BT.OriginalValues or {}) do
        pcall(function()
            if original.Damage ~= nil then move:SetAttribute("Damage", original.Damage) end
            if original.DMGTable ~= nil then move:SetAttribute("DMGTable", original.DMGTable) end
        end)
    end
end
BT.Connections, BT.OriginalValues = {}, {}
BT.AutoGreenConnection, BT.FakerMonitor, BT.IsHoldingSpace = nil, nil, false

-- Load durable settings only when no session settings exist.
if not BT.LastDefaultConfig and DEFAULT_CONFIG.PersistSettings and Services.HttpService
    and type(readfile) == "function" then
    local ok, raw = pcall(readfile, DEFAULT_CONFIG.SettingsFile)
    if ok and type(raw) == "string" and #raw < 65536 then
        local decoded, saved = pcall(function() return Services.HttpService:JSONDecode(raw) end)
        if decoded and type(saved) == "table" and saved.Version == 2 then
            BT.Config = type(saved.Config) == "table" and saved.Config or nil
            BT.LastDefaultConfig = type(saved.Defaults) == "table" and saved.Defaults or nil
            BT.UserSettings = type(saved.UserSettings) == "table" and saved.UserSettings or nil
        end
    end
end
BT.Config = type(BT.Config) == "table" and BT.Config or {}
for k, value in pairs(DEFAULT_CONFIG) do
    if BT.Config[k] == nil or (BT.LastDefaultConfig and not equal(value, BT.LastDefaultConfig[k])) then
        BT.Config[k] = copy(value)
    end
end
BT.Config.TexScriptURL = nil
BT.LastDefaultConfig = copy(DEFAULT_CONFIG)
BT.UserSettings = type(BT.UserSettings) == "table" and BT.UserSettings or {}
for k, value in pairs({Godmode = false, Blessed = true, AutoGreen = false}) do
    if type(BT.UserSettings[k]) ~= "boolean" then BT.UserSettings[k] = value end
end

-- === 2. mxsynry runtime and shared dependencies ===

local RT = {
    Alive = true, Config = BT.Config, Services = Services,
    Player = Services.Players and Services.Players.LocalPlayer,
    Scopes = {}, Tasks = {}, Loading = {}, DependencyErrors = {}, Features = {},
    Moves = nil, Variables = nil, Ambassador = nil, Faker = nil,
    GodmodeRecords = {}, HookGroups = BT.HookGroups or {},
    Input = {Down = false}, Exports = {}, AutoGreenBackend = nil,
}
BT.Runtime, BT.HookGroups = RT, RT.HookGroups

function RT:Notify(title, message)
    if not self.Alive then return end
    if self.Config.NotificationEnabled and self.Services.StarterGui then
        pcall(function()
            self.Services.StarterGui:SetCore("SendNotification", {
                Title = title, Text = message, Duration = 4,
            })
        end)
    else
        print("[Block Tales] " .. title .. ": " .. message)
    end
end
function RT:Report(feature, state, reason, announce)
    local old = self.Features[feature]
    self.Features[feature] = {
        Requested = BT.UserSettings[feature] == true,
        Active = state == "running", State = state, Reason = reason,
    }
    if announce and (not old or old.State ~= state or old.Reason ~= reason) then
        self:Notify(feature, state .. (reason and ": " .. reason or ""))
    end
end
function RT:Track(scope, key, connection)
    self.Scopes[scope] = self.Scopes[scope] or {}
    disconnect(self.Scopes[scope][key])
    self.Scopes[scope][key] = connection
    return connection
end
function RT:Clean(scope)
    for _, connection in pairs(self.Scopes[scope] or {}) do disconnect(connection) end
    self.Scopes[scope] = {}
end
function RT:Spawn(key, callback)
    if self.Tasks[key] then return end
    local ticket = {}
    self.Tasks[key] = ticket
    ticket.Thread = task.spawn(function()
        local ok, err = pcall(callback)
        if self.Tasks[key] == ticket then self.Tasks[key] = nil end
        if not ok and self.Alive then
            self.DependencyErrors[key] = tostring(err)
            self:Notify(key, tostring(err))
        end
    end)
end
function RT:Save()
    if not self.Config.PersistSettings or not self.Services.HttpService
        or type(writefile) ~= "function" then return false end
    local ok, err = pcall(function()
        local config = {}
        for k in pairs(DEFAULT_CONFIG) do config[k] = copy(self.Config[k]) end
        writefile(self.Config.SettingsFile, self.Services.HttpService:JSONEncode({
            Version = 2, Config = config, Defaults = BT.LastDefaultConfig,
            UserSettings = BT.UserSettings,
        }))
    end)
    self.SettingsSaved, self.SettingsError = ok, not ok and tostring(err) or nil
    return ok
end
function RT:Normalize()
    local c = self.Config
    for k, default in pairs(DEFAULT_CONFIG) do
        if type(c[k]) ~= type(default) then c[k] = copy(default) end
    end
    c.Layers = math.max(1, math.min(8, math.floor(number(c.Layers) and c.Layers or 4)))
    c.DependencyTimeout = math.max(1, math.min(60, number(c.DependencyTimeout) and c.DependencyTimeout or 12))
    c.PressWindowScale = math.max(0.05, math.min(1, number(c.PressWindowScale) and c.PressWindowScale or 0.3))
    if c.AutoGreenMode ~= "Legacy" and c.AutoGreenMode ~= "Battle" and c.AutoGreenMode ~= "Auto" then
        c.AutoGreenMode = "Legacy"
    end
    if c.BlessedHookMode ~= "Single" then c.BlessedHookMode = "Layered" end
    if c.SettingsFile == "" then c.SettingsFile = DEFAULT_CONFIG.SettingsFile end
end
RT:Normalize()

-- Resolve each dependency independently; no global wait for faker or the HUD.
function RT:Resolve(name)
    if not self.Alive or self.Loading[name] then return end
    if name == "Variables" and self.Variables then return end
    if name == "Ambassador" and self.Ambassador then return end
    if name == "Moves" and self.Moves then return end
    self.Loading[name], self.DependencyErrors[name] = true, nil
    self:Spawn("Resolve:" .. name, function()
        local parent = name == "Moves" and self.Services.ReplicatedStorage or self.Services.ReplicatedFirst
        local deadline = os.clock() + self.Config.DependencyTimeout
        local object
        repeat
            if not self.Alive then return end
            object = child(parent, name)
            if object then break end
            task.wait(0.05)
        until os.clock() >= deadline
        if object and name ~= "Moves" then
            local finished, succeeded, result = false, false, nil
            local requireKey = "Require:" .. name
            self:Spawn(requireKey, function()
                succeeded, result = pcall(require, object)
                finished = true
            end)
            while self.Alive and not finished and os.clock() < deadline do task.wait(0.05) end
            local ticket = self.Tasks[requireKey]
            if not finished and ticket and ticket.Thread then
                pcall(task.cancel, ticket.Thread)
                self.Tasks[requireKey] = nil
            end
            if not self.Alive then return end
            if finished and succeeded and type(result) == "table" then
                self[name] = result
            else
                self.DependencyErrors[name] = finished and tostring(result) or "module timed out"
            end
        elseif object then
            self.Moves = object
        else
            self.DependencyErrors[name] = "not available within timeout"
        end
        self.Loading[name] = nil
        if self.Alive then self:ApplyAll(false) end
    end)
end

-- === 3. mxsynry features ===

-- mxsynry's enemy-only Godmode selection and reversible damage edits.

-- Store every attribute we change, including whether the original was absent.
local PLAYER_MOVE_ATTRIBUTES = {
    "Description", "Icon", "SP", "Price", "SPrice", "MoveType", "CallWho",
    "itemsc", "ItemType", "WhatBadge",
}
function RT:IsEnemyMove(move)
    local ok, isFolder = pcall(function() return move:IsA("Folder") end)
    if not ok or not isFolder then return false end
    local allow = self.Config.GodmodeMoveAllowList
    if next(allow) ~= nil then
        if allow[move.Name] == true then return true end
        for _, name in pairs(allow) do if name == move.Name then return true end end
        return false
    end
    for _, name in ipairs(PLAYER_MOVE_ATTRIBUTES) do
        if attribute(move, name) ~= nil then return false end
    end
    return number(attribute(move, "Damage")) or type(attribute(move, "DMGTable")) == "string"
end
function RT:PatchMove(move)
    if not self.Alive or not BT.GodmodeEnabled then return end
    local record = self.GodmodeRecords[move]
    if not record then
        if not self:IsEnemyMove(move) then return end
        record = {Original = {}, Written = {}, Patched = {}, Connections = {}}
        for _, name in ipairs({"Damage", "DMGTable"}) do
            local value = attribute(move, name)
            record.Original[name] = {Exists = value ~= nil, Value = value}
        end
        self.GodmodeRecords[move], BT.OriginalValues[move] = record, record
        for _, name in ipairs({"Damage", "DMGTable"}) do
            local attributeName = name
            local ok, connection = pcall(function()
                return move:GetAttributeChangedSignal(attributeName):Connect(function()
                    if not self.Alive or not BT.GodmodeEnabled or record.Writing then return end
                    local value = attribute(move, attributeName)
                    -- Also ignore our own deferred AttributeChanged notification.
                    if record.Patched[attributeName] and value == record.Written[attributeName] then return end
                    record.Original[attributeName] = {Exists = value ~= nil, Value = value}
                    self:PatchMove(move)
                end)
            end)
            if ok then record.Connections[#record.Connections + 1] = connection end
        end
        pcall(function()
            record.Connections[#record.Connections + 1] = move.Destroying:Connect(function()
                for _, connection in ipairs(record.Connections) do disconnect(connection) end
                self.GodmodeRecords[move], BT.OriginalValues[move] = nil, nil
            end)
        end)
    end
    local changes = {}
    local damage = attribute(move, "Damage")
    if number(damage) and damage > 0 then changes.Damage = 0 end
    local encoded = attribute(move, "DMGTable")
    if type(encoded) == "string" and self.Services.HttpService then
        local ok, data = pcall(function() return self.Services.HttpService:JSONDecode(encoded) end)
        if ok and type(data) == "table" then
            local changed = false
            for k, v in pairs(data) do
                if number(v) and v > 0 then data[k], changed = 0, true end
            end
            if changed then
                local success, result = pcall(function() return self.Services.HttpService:JSONEncode(data) end)
                if success then changes.DMGTable = result end
            end
        end
    end
    for name, value in pairs(changes) do
        record.Writing, record.Written[name], record.Patched[name] = true, value, true
        local ok = pcall(function() move:SetAttribute(name, value) end)
        record.Writing = false
        if not ok then record.Patched[name] = nil end
    end
end
function RT:StopGodmode()
    BT.GodmodeEnabled = false
    self:Clean("Godmode")
    for move, record in pairs(self.GodmodeRecords) do
        for _, connection in ipairs(record.Connections) do disconnect(connection) end
        for name, original in pairs(record.Original) do
            -- Preserve a newer external value if it has not yet reached our listener.
            if record.Patched[name] and attribute(move, name) == record.Written[name] then
                pcall(function() move:SetAttribute(name, original.Exists and original.Value or nil) end)
            end
        end
    end
    self.GodmodeRecords, BT.OriginalValues = {}, {}
end
function RT:ApplyGodmode(announce)
    if not BT.UserSettings.Godmode then
        self:StopGodmode()
        self:Report("Godmode", "off", nil, announce)
        return
    end
    if not self.Moves then
        self:Report("Godmode", self.DependencyErrors.Moves and "unavailable" or "waiting", self.DependencyErrors.Moves or "Moves", announce)
        if not self.DependencyErrors.Moves then self:Resolve("Moves") end
        return
    end
    if not BT.GodmodeEnabled then
        BT.GodmodeEnabled = true
        local ok, moves = pcall(function() return self.Moves:GetChildren() end)
        if ok then for _, move in ipairs(moves) do self:PatchMove(move) end end
        self:Track("Godmode", "Added", self.Moves.ChildAdded:Connect(function(move)
            self:Spawn("Move:" .. tostring(move), function()
                task.wait(0.1) -- Allow a new move's metadata to finish populating.
                if self.Alive and BT.GodmodeEnabled and move.Parent == self.Moves then self:PatchMove(move) end
            end)
        end))
        self:Track("Godmode", "Removed", self.Moves.ChildRemoved:Connect(function(move)
            local record = self.GodmodeRecords[move]
            if record then
                for _, connection in ipairs(record.Connections) do disconnect(connection) end
                for name, original in pairs(record.Original) do
                    if record.Patched[name] and attribute(move, name) == record.Written[name] then
                        pcall(function() move:SetAttribute(name, original.Exists and original.Value or nil) end)
                    end
                end
                self.GodmodeRecords[move], BT.OriginalValues[move] = nil, nil
            end
        end))
    end
    self:Report("Godmode", "running", nil, announce)
end

-- mxsynry's layered AutoGuard hook handling; the game-side read is named Blessed.

-- Hook groups are indexed by metatable, so replacing faker cannot grow the chain.
function RT:RestoreGroup(group)
    group.Runtime = nil
    while #group.Layers > 0 do
        local layer = group.Layers[#group.Layers]
        local ok, top = pcall(function() return group.Metatable.__namecall end)
        if not ok or top ~= layer.Handler then return false end
        local restored = pcall(hookmetamethod, group.Target, "__namecall", layer.Previous)
        if not restored then return false end
        table.remove(group.Layers)
    end
    self.HookGroups[group.Metatable] = nil
    return true
end
function RT:StopAutoGuardHook()
    self.BlessedEnabled = false
    ENV.BlessedHookEnabled = false
    self:Clean("Blessed")
    local warmup = self.Tasks.FakerWarmup
    if warmup and warmup.Thread and warmup.Thread ~= coroutine.running() then pcall(task.cancel, warmup.Thread) end
    self.Tasks.FakerWarmup = nil
    for _, group in pairs(self.HookGroups) do
        if group.Runtime == self then self:RestoreGroup(group) end
    end
end
function RT:ApplyAutoGuardHook(announce)
    if not BT.UserSettings.Blessed then
        self:StopAutoGuardHook()
        self:Report("Blessed", "off", nil, announce)
        return
    end
    local hookApis = {
        getrawmetatable = getrawmetatable, hookmetamethod = hookmetamethod,
        newcclosure = newcclosure, checkcaller = checkcaller,
    }
    for _, api in ipairs({"getrawmetatable", "hookmetamethod", "newcclosure", "checkcaller"}) do
        local value = hookApis[api]
        if type(value) ~= "function" then
            self:StopAutoGuardHook()
            self:Report("Blessed", "unavailable", "missing " .. api, announce)
            return
        end
    end
    if not self.Variables then
        self:Report("Blessed", self.DependencyErrors.Variables and "unavailable" or "waiting", self.DependencyErrors.Variables or "Variables", announce)
        if not self.DependencyErrors.Variables then self:Resolve("Variables") end
        return
    end
    if self.Faker ~= self.Variables.faker then self.BlessedObservedMethod = nil end
    self.Faker = self.Variables.faker
    if not self.Faker then
        self:Report("Blessed", self.DependencyErrors.Faker and "unavailable" or "waiting", self.DependencyErrors.Faker or "faker", announce)
        if not self.DependencyErrors.Faker then
            self:Spawn("FakerWarmup", function()
                local deadline = os.clock() + self.Config.DependencyTimeout
                while self.Alive and BT.UserSettings.Blessed and self.Variables and not self.Variables.faker
                    and os.clock() < deadline do task.wait(0.05) end
                if not self.Alive or not BT.UserSettings.Blessed then return end
                if self.Variables and self.Variables.faker then
                    self:ApplyAutoGuardHook(false)
                else
                    self.DependencyErrors.Faker = "faker not available within timeout"
                    self:Report("Blessed", "unavailable", self.DependencyErrors.Faker, true)
                end
            end)
        end
    else
        self.DependencyErrors.Faker = nil
        local ok, mt = pcall(getrawmetatable, self.Faker)
        if not ok or not mt or type(mt.__namecall) ~= "function" then
            self:Report("Blessed", "unavailable", "faker namecall is unavailable", announce)
            return
        end
        local count = self.Config.BlessedHookMode == "Single" and 1 or self.Config.Layers
        local group = self.HookGroups[mt]
        if group and #group.Layers ~= count then
            if self:RestoreGroup(group) then group = nil end
        end
        if not group then
            group = {Metatable = mt, Target = self.Faker, Layers = {}}
            self.HookGroups[mt] = group
            for _ = 1, count do
                local previous = mt.__namecall
                local closureOk, handler = pcall(newcclosure, function(object, ...)
                    local runtime = group.Runtime
                    local first = ...
                    local currentFaker = runtime and runtime.Variables and runtime.Variables.faker
                    if runtime and runtime.Alive and runtime.BlessedEnabled and object == currentFaker
                        and first == "Blessed" then
                        local callerOk, isCaller = pcall(checkcaller)
                        if not callerOk or isCaller ~= false then return previous(object, ...) end
                        if runtime.Faker ~= currentFaker then
                            runtime.Faker, runtime.BlessedObservedMethod = currentFaker, nil
                            group.Target, BT.HookedFaker = currentFaker, currentFaker
                        end
                        local method
                        if type(getnamecallmethod) == "function" then
                            local methodOk, result = pcall(getnamecallmethod)
                            if methodOk then method = result end
                        end
                        -- Never turn an attribute write or a yielding child wait into a read.
                        local read = not method or method == "GetAttribute" or method == "HasTag"
                            or method == "FindFirstChild"
                        if read then
                            local wanted = runtime.Config.BlessedMethod
                            if wanted == "Auto" and method and not runtime.BlessedObservedMethod then
                                runtime.BlessedObservedMethod = method
                            end
                            wanted = wanted == "Auto" and runtime.BlessedObservedMethod or wanted
                            if not method or not wanted or method == wanted then return true end
                        end
                    end
                    return previous(object, ...)
                end)
                if not closureOk or type(handler) ~= "function" then
                    self:RestoreGroup(group)
                    self:Report("Blessed", "unavailable", "closure creation failed", announce)
                    return
                end
                local success, original = pcall(hookmetamethod, self.Faker, "__namecall", handler)
                if not success or type(original) ~= "function" then
                    if mt.__namecall == handler then
                        group.Layers[#group.Layers + 1] = {Handler = handler, Previous = previous}
                    end
                    self:RestoreGroup(group)
                    self:Report("Blessed", "unavailable", "hook installation failed", announce)
                    return
                end
                previous = original
                group.Layers[#group.Layers + 1] = {Handler = handler, Previous = original}
            end
        end
        group.Target, group.Runtime = self.Faker, self
        self.BlessedEnabled = true
        -- Old untracked hooks have no restoration handle. Keep their old global gate off.
        ENV.BlessedHookEnabled = not BT.LegacyHooksPresent
        BT.HookedFaker = self.Faker
        self:Report("Blessed", "running", #group.Layers ~= count and "layer change deferred: another hook owns the top" or nil, announce)
    end
    if self.Config.FakerMonitorEnabled and self.Services.RunService and not (self.Scopes.Blessed or {}).Monitor then
        local elapsed = 0
        self:Track("Blessed", "Monitor", self.Services.RunService.Heartbeat:Connect(function(dt)
            elapsed = elapsed + dt
            if elapsed >= 1 then elapsed = 0; self:ApplyAutoGuardHook(false) end
        end))
    elseif not self.Config.FakerMonitorEnabled then
        disconnect((self.Scopes.Blessed or {}).Monitor)
        if self.Scopes.Blessed then self.Scopes.Blessed.Monitor = nil end
    end
end

-- Legacy AutoGreen uses kaiserdegurechaff's HUD color/Space-hold approach.
-- Battle AutoGreen shares the timing adapted from 7GrandDad's AutoAction.

function RT:SendInput(down, backend, force)
    if self.Input.Down == down and not force then return true end
    if self.Input.Down and self.Input.Backend ~= backend and not self:ReleaseInput() then return false end
    local ok, err
    if backend == "Battle" then
        if not self.Ambassador or type(self.Ambassador.Fire) ~= "function" then return false end
        ok, err = pcall(self.Ambassador.Fire, "ButtonA", down and "down" or "up")
    else
        ok, err = pcall(function()
            self.Services.VirtualInputManager:SendKeyEvent(down, Enum.KeyCode.Space, false, game)
        end)
    end
    if ok then
        self.Input.Down, self.Input.Backend = down, down and backend or nil
        BT.IsHoldingSpace = down and backend == "Legacy"
    else
        self.InputError = tostring(err)
    end
    return ok
end
function RT:ReleaseInput()
    if self.Input.Down then return self:SendInput(false, self.Input.Backend, true) end
    return true
end
function RT:Pulse()
    if not self:SendInput(true, "Battle", true) then return false end
    return self:SendInput(false, "Battle", true)
end
function RT:GetBattleGui(name)
    local gui = child(self.Player, "PlayerGui")
    local hud = child(gui, "HUD")
    local battle = child(hud, "Battle")
    local prompt = child(battle, name)
    if not prompt then return nil end
    local ok, visible = pcall(function()
        if hud:IsA("ScreenGui") and not hud.Enabled then return false end
        return battle.Visible ~= false and prompt.Visible ~= false
    end)
    return ok and visible and prompt or nil
end
function RT:InputBlocked()
    if self.WindowFocused == false then return true end
    if self.Player and not self.Player.Character then return true end
    local ok, focused = pcall(function() return self.Services.UserInputService:GetFocusedTextBox() end)
    if ok and focused then return true end
    local menuOk, menu = pcall(function() return self.Services.GuiService.MenuIsOpen end)
    if menuOk and menu then return true end
    local character = self.Player and self.Player.Character
    local humanoid = child(character, "Humanoid")
    return humanoid and humanoid.Health <= 0 or false
end
function RT:UpdateLegacy()
    local prompt = self:GetBattleGui("DOITNOW")
    local div = child(child(prompt, "Meter"), "Div")
    if not div then self:ReleaseInput(); return end
    local ok, color = pcall(function() return div.ImageColor3 end)
    if not ok or color == nil then self:ReleaseInput(); return end
    if color == Color3.fromRGB(255, 0, 0) then
        self:ReleaseInput()
    else
        self:SendInput(true, "Legacy")
    end
end
function RT:UpdateBattle(attackEnabled, blockEnabled)
    local v = self.Variables
    if not v then self:ReleaseInput(); return end
    if v.faker ~= self.Faker and BT.UserSettings.Blessed then self:ApplyAutoGuardHook(false) end
    local arena, started, kind = v.arena, v.atick, v.atktype
    if attackEnabled == nil then attackEnabled = self.Config.BattleAttackEnabled end
    if blockEnabled == nil then blockEnabled = self.Config.BattleBlockEnabled end
    local enabled = v.itsme and attackEnabled or (not v.itsme and blockEnabled)
    if not v.myturn or not arena or attribute(arena, "State") ~= "Attacking" or not enabled
        or not number(started) or (kind ~= "press" and kind ~= "hold" and kind ~= "mash") then
        self:ReleaseInput(); self.Action = nil; return
    end
    local impact = number(v.timehere) and v.timehere or v.impact
    local action = self.Action
    if not action or action.Arena ~= arena or action.Started ~= started or action.Kind ~= kind
        or action.Impact ~= impact then
        self:ReleaseInput()
        action = {Arena = arena, Started = started, Kind = kind, Impact = impact, Seen = setmetatable({}, {__mode = "k"})}
        self.Action = action
    end
    local now = tick()
    local elapsed = now - started
    if kind == "press" then
        local window = v.window
        if not action.Done and number(impact) and number(window) and window > 0
            and elapsed < impact and elapsed >= impact - window * self.Config.PressWindowScale then
            action.Done = self:Pulse()
        end
    elseif kind == "hold" then
        if action.Released then return end
        if number(v.promptuheld) then
            if not number(v.holdingtime) or not number(v.loopfor) or v.loopfor <= 0
                or not number(v.greenmin) or not number(v.greenmax) or v.greenmax <= v.greenmin then
                self:ReleaseInput(); return
            end
            if elapsed > v.promptuheld + v.holdingtime then
                self:ReleaseInput(); action.Released = true; return
            end
            local phase = ((now + 0.01 - started - v.promptuheld) % v.loopfor) / v.loopfor
            if phase > 0.5 then phase = 1 - phase end
            phase = math.max(0, math.min(1, phase * 2))
            if phase > v.greenmin + (v.greenmax - v.greenmin) / 2 and phase < v.greenmax then
                action.Released = self:SendInput(false, "Battle", true)
            end
        elseif number(v.holdfrom) and number(v.holdtimeout) and v.holdtimeout >= 0 then
            if elapsed >= v.holdfrom and elapsed <= v.holdfrom + v.holdtimeout and not action.Held then
                action.Held = self:SendInput(true, "Battle")
            elseif elapsed > v.holdfrom + v.holdtimeout then
                self:ReleaseInput(); action.Released = true
            end
        else
            self:ReleaseInput()
        end
    else
        if type(v.filled) ~= "table" or not number(v.filled[1]) or now - v.filled[1] <= 0.5 then return end
        local prompt = self:GetBattleGui("DOITNOW3")
        local meter = child(prompt, "Meter")
        local checker, fill = child(meter, "checker"), child(meter, "Fill")
        if not checker or not fill then return end
        local fillPosition = fill.AbsoluteSize.X + fill.AbsolutePosition.X
        for _, target in ipairs(checker:GetChildren()) do
            if not action.Seen[target] and not attribute(target, "Skipped") then
                local position, width = target.AbsolutePosition.X - 6, target.AbsoluteSize.X
                if fillPosition > position + width / 2 and fillPosition <= position + width + 12 then
                    if self:Pulse() then action.Seen[target] = true end
                    break
                end
            end
        end
    end
end
function RT:StopAutoGreen()
    self:Clean("AutoGreen")
    BT.AutoGreenConnection = nil
    self:ReleaseInput()
    self.Action, self.AutoGreenBackend = nil, nil
end
function RT:ApplyAutoGreen(announce)
    ENV.AutoGreenEnabled = BT.UserSettings.AutoGreen
    if not BT.UserSettings.AutoGreen then
        self:StopAutoGreen()
        self:Report("AutoGreen", "off", nil, announce)
        return
    end
    local mode = self.Config.AutoGreenMode
    if mode ~= "Legacy" then
        if not self.Variables and not self.DependencyErrors.Variables then self:Resolve("Variables") end
        if not self.Ambassador and not self.DependencyErrors.Ambassador then self:Resolve("Ambassador") end
    end
    local native = self.Variables and self.Ambassador and type(self.Ambassador.Fire) == "function"
    local backend = mode == "Legacy" and "Legacy" or native and "Battle" or nil
    if mode == "Auto" and not native and (self.DependencyErrors.Variables or self.DependencyErrors.Ambassador) then backend = "Legacy" end
    if not backend then
        self:StopAutoGreen()
        self:Report("AutoGreen", (self.DependencyErrors.Variables or self.DependencyErrors.Ambassador) and "unavailable" or "waiting", "battle input dependencies", announce)
        return
    end
    if backend == "Legacy" and not self.Services.VirtualInputManager then
        self:Report("AutoGreen", "unavailable", "VirtualInputManager", announce)
        return
    end
    if not self.Services.RunService then
        self:Report("AutoGreen", "unavailable", "RunService", announce)
        return
    end
    if self.AutoGreenBackend ~= backend then self:StopAutoGreen() end
    self.AutoGreenBackend = backend
    if not (self.Scopes.AutoGreen or {}).Loop then
        local connection = self.Services.RunService.Heartbeat:Connect(function()
            if not self.Alive or not BT.UserSettings.AutoGreen or self:InputBlocked() then
                self:ReleaseInput(); self.Action = nil; return
            end
            local ok, err = pcall(function()
                if self.AutoGreenBackend == "Battle" then self:UpdateBattle() else self:UpdateLegacy() end
            end)
            if not ok or self.InputError then
                local reason = tostring(err or self.InputError)
                self.InputError = nil
                self:StopAutoGreen()
                self:Report("AutoGreen", "error", reason, true)
            end
        end)
        self:Track("AutoGreen", "Loop", connection)
        BT.AutoGreenConnection = connection
    end
    self:Report("AutoGreen", "running", backend, announce)
end
function RT:ApplyAll(announce)
    if not self.Alive then return end
    self:ApplyGodmode(announce)
    self:ApplyAutoGuardHook(announce)
    self:ApplyAutoGreen(announce)
end


-- === 4. Shared movement and Vape V4 Block Tales modules ===

-- Shared speed backend. A ladder exit stays protected until grounded again.
local function CreateMovementController(owner)
    local movement = {Owner = owner, LadderProtected = false, Backend = "off"}

    function movement:RestoreWalkSpeed(source)
        local record = self.WalkSpeedRecord
        if not record or (source and record.Source ~= source) then return end
        pcall(function()
            if record.Humanoid.WalkSpeed == record.Written then
                record.Humanoid.WalkSpeed = record.Original
            end
        end)
        self.WalkSpeedRecord = nil
    end

    function movement:Character()
        local character = owner.Player and owner.Player.Character
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        local root = child(character, "HumanoidRootPart")
        if humanoid ~= self.Humanoid then
            self:RestoreWalkSpeed()
            self.Humanoid, self.LadderProtected = humanoid, false
        end
        if not humanoid or not root or humanoid.Health <= 0 then return nil end
        return character, humanoid, root
    end

    function movement:IsLadderProtected(humanoid)
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Climbing then
            self.LadderProtected = true
        elseif self.LadderProtected then
            local groundedState = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed
            if groundedState and humanoid.FloorMaterial ~= Enum.Material.Air then
                self.LadderProtected = false
            end
        end
        return self.LadderProtected
    end

    function movement:BaseWalkSpeed(humanoid)
        local record = self.WalkSpeedRecord
        local current = humanoid.WalkSpeed
        if record and record.Humanoid == humanoid then
            if current ~= record.Written then record.Original = current end
            return record.Original
        end
        return current
    end

    function movement:SetWalkSpeed(source, humanoid, speed)
        local record = self.WalkSpeedRecord
        if record and (record.Humanoid ~= humanoid or record.Source ~= source) then
            self:RestoreWalkSpeed()
            record = nil
        end
        if not record then
            record = {Humanoid = humanoid, Source = source, Original = humanoid.WalkSpeed}
            self.WalkSpeedRecord = record
        elseif humanoid.WalkSpeed ~= record.Written then
            record.Original = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = speed
        record.Written = speed
        self.Source, self.Backend = source, "WalkSpeed"
    end

    function movement:Stop(source)
        self:RestoreWalkSpeed(source)
        if not source or self.Source == source then self.Source, self.Backend = nil, "off" end
    end

    function movement:Tick(source, backend, speed, dt)
        local character, humanoid, root = self:Character()
        if not character or owner:InputBlocked() or (owner.Variables and owner.Variables.transitioning) then
            self:Stop(source)
            return
        end
        if self:IsLadderProtected(humanoid) or backend == "WalkSpeed" then
            self:SetWalkSpeed(source, humanoid, speed)
            return
        end

        self:RestoreWalkSpeed()
        self.Source, self.Backend = source, backend
        local direction = humanoid.MoveDirection
        if backend == "CFrame" then
            -- Native walking supplies the baseline; TranslateBy supplies only the extra speed.
            local extra = math.max(0, speed - humanoid.WalkSpeed)
            if direction.Magnitude > 0 and number(dt) and dt > 0 then
                character:TranslateBy(direction * extra * math.min(dt, 0.1))
            end
        else
            local velocity = root.AssemblyLinearVelocity
            local horizontal = direction * speed
            root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
        end
    end

    function movement:TickTex(dt, multiplier)
        local character, humanoid = self:Character()
        if not character then self:Stop("Tex"); return end
        if owner.Vape and (owner.Vape:IsEnabled("Fly") or owner.Vape:IsEnabled("LongJump") or owner.Vape:IsEnabled("Speed")) then
            self:Stop("Tex")
            return
        end
        local speed = self:BaseWalkSpeed(humanoid) + math.max(0, multiplier) * 10
        self:Tick("Tex", "CFrame", speed, dt)
    end

    function movement:GetStatus()
        return {Source = self.Source, Backend = self.Backend, LadderProtected = self.LadderProtected}
    end
    return movement
end

-- 7GrandDadPGN's Vape Block Tales modules, adapted to the shared runtime.
-- Source: https://github.com/7GrandDadPGN/VapeCompiled/blob/main/games/16483433878.lua
local VAPE_FEATURES = {
    "AutoAction", "MissCooldown", "AntiHazard", "Fly", "FlyingAttack", "LongJump",
    "PickupTP", "Speed", "SpeedSpin", "PickupTracers", "AutoCamel", "AutoCloudGrind",
    "AutoFish", "AutoPaint",
}
local VAPE_DEFAULT_OPTIONS = {
    AutoActionAttacks = true,
    AutoActionBlock = true,
    FlySpeed = 50,
    FlyVerticalSpeed = 50,
    FlyUpKey = "Space",
    FlyDownKey = "LeftControl",
    LongJumpSpeed = 50,
    LongJumpAutoDisable = true,
    SpeedValue = 50,
    SpeedMode = "Velocity",
    SpeedSpinCards = 4,
    TracersColor = {R = 1, G = 0.84, B = 0},
    TracersTransparency = 0,
    TracersBuxOnly = false,
    FishKeepList = {},
}

local function CreateVapeRuntime(owner)
    local saved = type(BT.UserSettings.Vape) == "table" and BT.UserSettings.Vape or {}
    BT.UserSettings.Vape = saved
    saved.Options = type(saved.Options) == "table" and saved.Options or {}
    local runtime = {
        Alive = true,
        Owner = owner,
        Preferences = saved,
        Options = saved.Options,
        Enabled = {},
        Status = {},
        Generations = {},
        Connections = {},
        Tasks = {},
        Dependencies = {},
        Constants = {},
        Hooks = {},
        Properties = {},
        Tracers = {},
        Up = false,
        Down = false,
    }

    local function validOption(name, value)
        if VAPE_DEFAULT_OPTIONS[name] == nil then return nil, "unknown option" end
        if name == "SpeedMode" then
            if value ~= "Velocity" and value ~= "CFrame" and value ~= "WalkSpeed" then return nil, "unknown speed mode" end
        elseif name == "FlyUpKey" or name == "FlyDownKey" then
            if type(value) ~= "string" or not Enum.KeyCode[value] then return nil, "unknown key" end
        elseif name == "TracersColor" then
            if typeof(value) == "Color3" then value = {R = value.R, G = value.G, B = value.B} end
            if type(value) ~= "table" then return nil, "expected a color" end
            for _, channel in ipairs({"R", "G", "B"}) do
                if not number(value[channel]) or value[channel] < 0 or value[channel] > 1 then return nil, "invalid color" end
            end
            value = {R = value.R, G = value.G, B = value.B}
        elseif name == "FishKeepList" then
            if type(value) == "string" then
                local items = {}
                for item in value:gmatch("[^,\n]+") do
                    item = item:match("^%s*(.-)%s*$")
                    if item ~= "" then items[#items + 1] = item end
                end
                value = items
            end
            if type(value) ~= "table" then return nil, "expected fish names" end
            local items, seen = {}, {}
            for _, item in ipairs(value) do
                if type(item) ~= "string" then return nil, "expected fish names" end
                if item ~= "" and not seen[item] then items[#items + 1], seen[item] = item, true end
            end
            value = items
        elseif type(VAPE_DEFAULT_OPTIONS[name]) == "boolean" then
            if type(value) ~= "boolean" then return nil, "expected a boolean" end
        else
            if not number(value) then return nil, "expected a finite number" end
            if name == "SpeedSpinCards" then value = math.floor(math.max(0, math.min(10, value)))
            elseif name == "TracersTransparency" then value = math.max(0, math.min(1, value))
            else value = math.max(1, math.min(150, value)) end
        end
        return value
    end
    for name, default in pairs(VAPE_DEFAULT_OPTIONS) do
        local value = validOption(name, saved.Options[name])
        if value == nil then value = copy(default) end
        saved.Options[name] = value
    end
    for _, name in ipairs(VAPE_FEATURES) do
        saved[name] = saved[name] == true
        runtime.Status[name] = {Requested = saved[name], Active = false, State = "off"}
    end

    function runtime:IsEnabled(name) return self.Alive and self.Enabled[name] == true end
    function runtime:Current(name, generation)
        return self.Alive and owner.Alive and self.Enabled[name] and self.Generations[name] == generation
    end

    -- Owned tasks and connections: toggling off also cancels pending module loads.
    function runtime:Cancel(key)
        local ticket = self.Tasks[key]
        self.Tasks[key] = nil
        if ticket and ticket.Thread and ticket.Thread ~= coroutine.running() then pcall(task.cancel, ticket.Thread) end
    end

    function runtime:Spawn(key, fn, feature)
        self:Cancel(key)
        local ticket = {}
        self.Tasks[key] = ticket
        ticket.Thread = task.spawn(function()
            local ok, err = pcall(fn)
            if self.Tasks[key] == ticket then self.Tasks[key] = nil end
            if not ok and self.Alive and owner.Alive then
                if feature and self.Enabled[feature] then self:Fail(feature, tostring(err)) end
            end
        end)
        return ticket
    end

    function runtime:Connect(name, key, signal, fn)
        assert(signal, key .. " is unavailable")
        self.Connections[name] = self.Connections[name] or {}
        disconnect(self.Connections[name][key])
        local generation = self.Generations[name]
        self.Connections[name][key] = signal:Connect(function(...)
            if not self:Current(name, generation) then return end
            local ok, err = pcall(fn, ...)
            if not ok then self:Fail(name, tostring(err)) end
        end)
    end

    function runtime:Every(name, interval, fn)
        local generation = self.Generations[name]
        self:Spawn("Loop:" .. name, function()
            while self:Current(name, generation) do
                fn()
                task.wait(interval)
            end
        end, name)
    end

    function runtime:FindDependency(name)
        local first = owner.Services.ReplicatedFirst
        if name == "Variables" or name == "Ambassador" or name == "Network" then return child(first, name) end
        if name == "Shucky" then return child(child(first, "Modules"), "Shucky") end
        if name == "BattleClient" then return child(child(child(owner.Player, "PlayerScripts"), "Battle"), "BattleClient") end
        if name == "CamelDialogue" then
            local camel = child(child(workspace, "NPCs"), "Abu Baba")
            local dialogue = child(camel, "Dialogue")
            local run = dialogue and dialogue:FindFirstChild("RunScript", true)
            return child(run, "ModuleScript")
        end
    end

    function runtime:Await(name, feature)
        if (name == "Variables" or name == "Ambassador") and owner[name] then return owner[name] end
        local entry = self.Dependencies[name]
        if not entry then
            entry = {Deadline = os.clock() + owner.Config.DependencyTimeout, State = "loading", Users = {}}
            self.Dependencies[name] = entry
            self:Spawn("Dependency:" .. name, function()
                local object
                while self.Alive and owner.Alive and os.clock() < entry.Deadline do
                    object = self:FindDependency(name)
                    if object then break end
                    task.wait(0.05)
                end
                if not object then entry.State, entry.Reason = "error", name .. " is unavailable"; return end
                local ok, value
                if name == "BattleClient" then
                    if type(getsenv) ~= "function" then entry.State, entry.Reason = "error", "getsenv is unavailable"; return end
                    ok, value = pcall(getsenv, object)
                else ok, value = pcall(require, object) end
                if not self.Alive or self.Dependencies[name] ~= entry or entry.State ~= "loading" then return end
                if ok and type(value) == "table" then
                    entry.State, entry.Value = "ready", value
                    if name == "Variables" or name == "Ambassador" then owner[name] = value end
                else entry.State, entry.Reason = "error", tostring(value) end
                self:Cancel("Timeout:" .. name)
            end)
            if entry.State == "loading" then
                self:Spawn("Timeout:" .. name, function()
                    task.wait(owner.Config.DependencyTimeout)
                    if entry.State == "loading" then
                        entry.State, entry.Reason = "error", name .. " timed out"
                        self:Cancel("Dependency:" .. name)
                    end
                end)
            end
        end
        entry.Users[feature] = true
        while self:IsEnabled(feature) and owner.Alive and entry.State == "loading" and os.clock() < entry.Deadline do task.wait(0.05) end
        if not self:IsEnabled(feature) or not owner.Alive then error("feature stopped", 0) end
        if entry.State == "loading" then
            entry.State, entry.Reason = "error", name .. " timed out"
            self:Cancel("Dependency:" .. name)
        end
        assert(entry.State == "ready", entry.Reason)
        return entry.Value
    end

    -- Reusable forwarding hooks avoid adding another hook layer on every rerun.
    BT.VapeFunctionHooks = BT.VapeFunctionHooks or setmetatable({}, {__mode = "k"})
    function runtime:Hook(name, target, filter)
        assert(type(target) == "function", name .. " target is unavailable")
        assert(type(hookfunction) == "function", "hookfunction is unavailable")
        local group = BT.VapeFunctionHooks[target]
        if not group then
            group = {}
            local wrapper = function(...)
                local active = group.Runtime
                if active and active:IsEnabled(group.Feature) and active.Owner.Alive then
                    local handled, results = group.Filter(...)
                    if handled then return unpack(results, 1, results.n) end
                end
                return group.Original(...)
            end
            if type(newcclosure) == "function" then wrapper = newcclosure(wrapper) end
            local original = hookfunction(target, wrapper)
            assert(type(original) == "function", "hookfunction did not return an original function")
            group.Original = original
            BT.VapeFunctionHooks[target] = group
        end
        group.Runtime, group.Feature, group.Filter = self, name, filter
        self.Hooks[name] = group
    end

    function runtime:PatchConstant(name, target, index, expected, value)
        local get = debug and debug.getconstant or getconstant
        local set = debug and debug.setconstant or setconstant
        assert(type(get) == "function" and type(set) == "function", "constant inspection/editing is unavailable")
        assert(type(target) == "function", name .. " target is unavailable")
        local original = get(target, index)
        assert(original == expected or original == value, name .. " constant layout differs from Vape's supported version")
        local record = {Target = target, Index = index, Original = original, Written = value, Get = get, Set = set}
        self.Constants[name] = record
        if original ~= value then
            record.Changed = true
            set(target, index, value)
            assert(get(target, index) == value, name .. " constant update did not take effect")
        end
    end

    function runtime:SetProperty(name, object, property, value)
        local fields = self.Properties[name] or {}
        self.Properties[name] = fields
        fields[#fields + 1] = {Object = object, Property = property, Original = object[property], Written = value}
        object[property] = value
    end

    function runtime:RemoveTracer(pickup)
        local line = self.Tracers[pickup]
        self.Tracers[pickup] = nil
        if line then pcall(function() line.Visible = false; line:Remove() end) end
    end

    function runtime:ReturnPickupOrigin()
        local origin = self.PickupOrigin
        self.PickupOrigin = nil
        if origin and owner.Player and owner.Player.Character == origin.Character and origin.Root.Parent then
            origin.Root.CFrame = origin.CFrame
        end
    end

    function runtime:ReleaseFlyInput() self.Up, self.Down = false, false end

    function runtime:Stop(name)
        self.Enabled[name] = false
        self:Cancel("Start:" .. name)
        self:Cancel("Loop:" .. name)
        for dependency, entry in pairs(self.Dependencies) do
            entry.Users[name] = nil
            if entry.State == "loading" and not next(entry.Users) then
                self:Cancel("Dependency:" .. dependency)
                self:Cancel("Timeout:" .. dependency)
                self.Dependencies[dependency] = nil
            end
        end
        for _, connection in pairs(self.Connections[name] or {}) do disconnect(connection) end
        self.Connections[name] = nil
        local group = self.Hooks[name]
        if group and group.Runtime == self then group.Runtime, group.Filter = nil, nil end
        self.Hooks[name] = nil
        local patch = self.Constants[name]
        if patch and patch.Changed then
            pcall(function()
                if patch.Get(patch.Target, patch.Index) == patch.Written then patch.Set(patch.Target, patch.Index, patch.Original) end
            end)
        end
        self.Constants[name] = nil
        for _, record in ipairs(self.Properties[name] or {}) do
            pcall(function()
                if record.Object[record.Property] == record.Written then record.Object[record.Property] = record.Original end
            end)
        end
        self.Properties[name] = nil
        if name == "AutoAction" then owner:ReleaseInput(); owner.Action = nil end
        if name == "Speed" then owner.Movement:Stop("Vape") end
        if name == "Fly" then self:ReleaseFlyInput() end
        if name == "PickupTP" then self:ReturnPickupOrigin() end
        if name == "PickupTracers" then for pickup in pairs(self.Tracers) do self:RemoveTracer(pickup) end end
    end

    function runtime:Fail(name, reason)
        self:Stop(name)
        self.Status[name] = {Requested = self.Preferences[name], Active = false, State = "unavailable", Reason = reason}
        owner:Notify(name, reason)
    end

    -- Combat: reuse the verified battle timing, with independent Vape options.
    function runtime:StartAutoAction()
        if BT.UserSettings.AutoGreen then ENV.ToggleAutoGreen(false) end
        if owner.Tex then owner.Tex:DisableInput() end
        owner.Variables = self:Await("Variables", "AutoAction")
        owner.Ambassador = self:Await("Ambassador", "AutoAction")
        assert(type(owner.Ambassador.Fire) == "function", "Ambassador.Fire is unavailable")
        self:Connect("AutoAction", "Heartbeat", owner.Services.RunService.Heartbeat, function()
            if owner:InputBlocked() then owner:ReleaseInput(); owner.Action = nil; return end
            owner:UpdateBattle(self.Options.AutoActionAttacks, self.Options.AutoActionBlock)
            if owner.InputError then local err = owner.InputError; owner.InputError = nil; error(err, 0) end
        end)
    end

    function runtime:StartMissCooldown()
        local battle = self:Await("BattleClient", "MissCooldown")
        local index = game.PlaceId == 16483433878 and 53 or 20
        self:PatchConstant("MissCooldown", battle.input, index, 0.2, 0)
    end

    function runtime:StartAntiHazard()
        local network = self:Await("Network", "AntiHazard")
        self:Hook("AntiHazard", network.FireServer, function(event)
            if event == "TakeDamage" then return true, table.pack() end
            return false
        end)
    end

    function runtime:StartFlyingAttack()
        local shucky = self:Await("Shucky", "FlyingAttack")
        self:PatchConstant("FlyingAttack", shucky.PossibleFirst, 7, "Flying", "_Flying")
    end

    function runtime:StartSpeedSpin()
        local shucky = self:Await("Shucky", "SpeedSpin")
        self:Hook("SpeedSpin", shucky.HasBadge, function(_, badge)
            if badge == "Speed Spin" then return true, table.pack(self.Options.SpeedSpinCards) end
            return false
        end)
    end

    -- Movement: no CFrame or velocity writes during climbing or an airborne ladder exit.
    function runtime:MovementAllowed()
        local character, humanoid, root = owner.Movement:Character()
        if not character or owner:InputBlocked() or (owner.Variables and owner.Variables.transitioning) then return nil end
        if owner.Movement:IsLadderProtected(humanoid) then return nil end
        return character, humanoid, root
    end

    function runtime:StartSpeed()
        if owner.Tex and owner.Tex.UI then
            local control = owner.Tex.UI.Flags.SpeedBoostSliderFlag_Main
            if control and control.CurrentValue > 0 then control:Set(0) end
        end
        self:Connect("Speed", "PreSimulation", owner.Services.RunService.PreSimulation, function(dt)
            if self:IsEnabled("Fly") or self:IsEnabled("LongJump") then owner.Movement:Stop("Vape"); return end
            owner.Movement:Tick("Vape", self.Options.SpeedMode, self.Options.SpeedValue, dt)
        end)
    end

    function runtime:StartFly()
        self:ReleaseFlyInput()
        local input = owner.Services.UserInputService
        self:Connect("Fly", "InputBegan", input.InputBegan, function(event, processed)
            if processed or owner:InputBlocked() then return end
            if event.KeyCode == Enum.KeyCode[self.Options.FlyUpKey] then self.Up = true end
            if event.KeyCode == Enum.KeyCode[self.Options.FlyDownKey] then self.Down = true end
        end)
        self:Connect("Fly", "InputEnded", input.InputEnded, function(event)
            if event.KeyCode == Enum.KeyCode[self.Options.FlyUpKey] then self.Up = false end
            if event.KeyCode == Enum.KeyCode[self.Options.FlyDownKey] then self.Down = false end
        end)
        self:Connect("Fly", "PreSimulation", owner.Services.RunService.PreSimulation, function()
            local _, humanoid, root = self:MovementAllowed()
            if not humanoid then self:ReleaseFlyInput(); return end
            local up = self.Up
            if input.TouchEnabled then
                local touch = child(child(child(child(owner.Player, "PlayerGui"), "TouchGui"), "TouchControlFrame"), "JumpButton")
                if touch then up = touch.ImageRectOffset.X == 146 end
            end
            local direction = humanoid.MoveDirection * self.Options.FlySpeed
            local vertical = ((up and 1 or 0) + (self.Down and -1 or 0)) * self.Options.FlyVerticalSpeed
            root.AssemblyLinearVelocity = Vector3.new(direction.X, 1 + vertical, direction.Z)
        end)
    end

    function runtime:StartLongJump()
        local exempt = tick() + 0.1
        self:Connect("LongJump", "PreSimulation", owner.Services.RunService.PreSimulation, function()
            local _, humanoid, root = self:MovementAllowed()
            if not humanoid then return end
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                if tick() > exempt and self.Options.LongJumpAutoDisable then self:Set("LongJump", false); return end
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            local direction = humanoid.MoveDirection * self.Options.LongJumpSpeed
            root.AssemblyLinearVelocity = Vector3.new(direction.X, root.AssemblyLinearVelocity.Y, direction.Z)
        end)
    end

    -- Tagged pickups and tracers.
    function runtime:StartPickupTP()
        local collection = assert(owner.Services.CollectionService, "CollectionService is unavailable")
        self:Every("PickupTP", 0.4, function()
            local character, _, root = owner.Movement:Character()
            if not character then self.PickupOrigin = nil; return end
            if self.PickupOrigin and self.PickupOrigin.Character ~= character then self.PickupOrigin = nil end
            for _, pickup in ipairs(collection:GetTagged("Pickup")) do
                if pickup.Parent and not attribute(pickup, "Inactive") then
                    if not self.PickupOrigin then self.PickupOrigin = {Character = character, Root = root, CFrame = root.CFrame} end
                    root.CFrame = pickup.CFrame
                    return
                end
            end
            self:ReturnPickupOrigin()
        end)
    end

    function runtime:AddTracer(pickup)
        self:RemoveTracer(pickup)
        if self.Options.TracersBuxOnly and pickup.Name ~= "BUX" then return end
        local line = Drawing.new("Line")
        local color = self.Options.TracersColor
        line.Thickness, line.Transparency = 1, 1 - self.Options.TracersTransparency
        line.Color = Color3.new(color.R, color.G, color.B)
        self.Tracers[pickup] = line
    end

    function runtime:StartPickupTracers()
        assert(Drawing and type(Drawing.new) == "function", "Drawing is unavailable")
        local collection = assert(owner.Services.CollectionService, "CollectionService is unavailable")
        self:Connect("PickupTracers", "Added", collection:GetInstanceAddedSignal("Pickup"), function(pickup) self:AddTracer(pickup) end)
        self:Connect("PickupTracers", "Removed", collection:GetInstanceRemovedSignal("Pickup"), function(pickup) self:RemoveTracer(pickup) end)
        for _, pickup in ipairs(collection:GetTagged("Pickup")) do self:AddTracer(pickup) end
        self:Connect("PickupTracers", "RenderStepped", owner.Services.RunService.RenderStepped, function()
            local camera = workspace.CurrentCamera
            if not camera then return end
            local size = camera.ViewportSize
            local origin = Vector2.new(size.X / 2, size.Y / 2)
            for pickup, line in pairs(self.Tracers) do
                if not pickup.Parent or attribute(pickup, "Inactive") then line.Visible = false
                else
                    local position, visible = camera:WorldToViewportPoint(pickup.Position)
                    if not visible then
                        local relative = camera.CFrame:PointToObjectSpace(pickup.Position)
                        local angle = math.atan2(relative.Y, relative.X) + math.pi
                        local ray = CFrame.Angles(0, 0, angle):VectorToWorldSpace(CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1)))
                        position = camera:WorldToViewportPoint(camera.CFrame:PointToWorldSpace(ray))
                        visible = true
                    end
                    line.From, line.To, line.Visible = origin, Vector2.new(position.X, position.Y), visible
                end
            end
        end)
    end

    -- Utility automations preserve Vape's NPC, network and painting paths.
    function runtime:StartAutoCamel()
        local camel = child(child(workspace, "NPCs"), "Abu Baba")
        assert(camel, "Missing camel seller")
        local dialogue = self:Await("CamelDialogue", "AutoCamel")
        assert(type(dialogue.Run) == "function", "Camel dialogue Run is unavailable")
        self:Every("AutoCamel", 0.5, function()
            if camel.Parent and (attribute(owner.Player, "TIX") or 0) >= 30 then dialogue:Run() end
        end)
    end

    function runtime:StartAutoCloudGrind()
        local variables = self:Await("Variables", "AutoCloudGrind")
        local network = self:Await("Network", "AutoCloudGrind")
        assert(type(network.FireServer) == "function", "Network.FireServer is unavailable")
        local alerted
        self:Every("AutoCloudGrind", 0.05, function()
            local arena = variables.arena
            if not arena or attribute(arena, "State") ~= "Picking" then alerted = nil; return end
            local goons = child(arena, "Goon")
            local cards = variables.data and variables.data.CardCollection
            if not goons or type(cards) ~= "table" then return end
            local escape = true
            for _, goon in ipairs(goons:GetChildren()) do
                local drop = goon.Value and attribute(goon.Value, "Item_Drop")
                if type(drop) == "string" and drop:find("FX ", 1, true) and not cards[drop] then escape = false end
            end
            if escape then
                alerted = nil
                network.FireServer("CommitToMove", "Run Away", nil, nil)
                task.wait(3)
            elseif alerted ~= arena then
                alerted = arena
                local money = child(child(workspace, "Sounds"), "Money")
                if money then money:Play() end
            end
        end)
    end

    function runtime:StartAutoFish()
        local fishman = child(child(workspace, "NPCs"), "The Seller")
        assert(fishman, "Missing fisherman")
        local network = self:Await("Network", "AutoFish")
        assert(type(network.InvokeServer) == "function", "Network.InvokeServer is unavailable")
        local money = child(child(workspace, "Sounds"), "Money")
        if money then self:SetProperty("AutoFish", money, "Volume", 0) end
        self:Every("AutoFish", 0.03, function()
            local status = child(owner.Player, "Status")
            local fish = attribute(status, "NextFish")
            if not fish or not fishman.Parent then return end
            if network.InvokeServer("FishItem") == true and self:IsEnabled("AutoFish") then
                local keep = false
                for _, item in ipairs(self.Options.FishKeepList) do if item == fish then keep = true; break end end
                if not keep then network.InvokeServer("UseItem", fish, fishman) end
                if not self:IsEnabled("AutoFish") then return end
                local shop = child(fishman, "ShopItems")
                local bait = shop and shop:GetChildren()[1]
                if bait then network.InvokeServer("BuyItem", bait, fishman) end
            end
        end)
    end

    function runtime:StartAutoPaint()
        local variables = self:Await("Variables", "AutoPaint")
        local ambassador = self:Await("Ambassador", "AutoPaint")
        assert(type(ambassador.Fire) == "function", "Ambassador.Fire is unavailable")
        self:Every("AutoPaint", 0.05, function()
            local gui = child(child(child(owner.Player, "PlayerGui"), "HUD"), "Painter")
            local timer = gui and gui:FindFirstChild("CanvasTime", true)
            local canvasUI, picker = timer and timer.Parent, child(gui, "ColorPicker")
            local canvas = variables.canvas
            if not gui or not gui.Visible or not variables.paintingflag or not canvas or attribute(canvas, "Completed") or not canvasUI or not picker then return end
            local easel = child(canvas.Parent, "Solution Easel")
            local solution = child(easel, "solution")
            if not solution then return end
            for _, target in ipairs(solution:GetDescendants()) do
                if target:IsA("BasePart") then
                    local row = child(canvas, target.Parent.Name)
                    local current = child(row, target.Name)
                    if current and current.BrickColor ~= target.BrickColor then
                        local element = child(canvasUI, target.Parent.Name:sub(4) .. "_" .. target.Name)
                        if element then
                            for _, color in ipairs(picker:GetChildren()) do
                                if attribute(color, "BGColor") == target.BrickColor.Color then ambassador.Fire("ButtonPress", color); break end
                            end
                            ambassador.Fire("ButtonPress", element)
                        end
                        break
                    end
                end
            end
        end)
    end

    -- Public feature/option state, including unavailable executor dependencies.
    function runtime:Set(name, enabled)
        if not self.Alive or not owner.Alive then return false, "unloaded" end
        if not self.Status[name] then return false, "unknown feature" end
        if type(enabled) ~= "boolean" then return false, "expected a boolean" end
        self.Generations[name] = (self.Generations[name] or 0) + 1
        self:Stop(name)
        self.Preferences[name], self.Enabled[name] = enabled, enabled
        self.Status[name] = {Requested = enabled, Active = false, State = enabled and "waiting" or "off"}
        if self.UI and self.UI.Flags["Vape" .. name .. "Toggle"] then self.UI.Flags["Vape" .. name .. "Toggle"]:Set(enabled, true) end
        if enabled then
            local generation = self.Generations[name]
            self:Spawn("Start:" .. name, function()
                self["Start" .. name](self)
                if self:Current(name, generation) then self.Status[name] = {Requested = true, Active = true, State = "running"} end
            end, name)
        end
        owner:Save()
        return true
    end

    function runtime:SetOption(name, value)
        if not self.Alive or not owner.Alive then return false, "unloaded" end
        local normalized, err = validOption(name, value)
        if normalized == nil then return false, err end
        self.Options[name] = normalized
        if name == "FlyUpKey" or name == "FlyDownKey" then self:ReleaseFlyInput() end
        if name == "TracersBuxOnly" and self:IsEnabled("PickupTracers") then self:Set("PickupTracers", true) end
        if name == "TracersColor" or name == "TracersTransparency" then
            local color = self.Options.TracersColor
            for _, line in pairs(self.Tracers) do
                line.Color = Color3.new(color.R, color.G, color.B)
                line.Transparency = 1 - self.Options.TracersTransparency
            end
        end
        self:SyncOption(name)
        owner:Save()
        return true
    end

    function runtime:SyncOption(name)
        local control = self.OptionControls and self.OptionControls[name]
        if not control then return end
        local value = self.Options[name]
        if control.Kind == "Dropdown" then value = {value}
        elseif name == "TracersColor" then value = Color3.new(value.R, value.G, value.B)
        elseif name == "FishKeepList" then value = table.concat(value, ", ") end
        control:Set(value, true)
    end

    function runtime:RestorePreferences()
        for _, name in ipairs(VAPE_FEATURES) do if self.Preferences[name] then self:Set(name, true) end end
    end

    function runtime:Refresh()
        local enabled = {}
        for _, name in ipairs(VAPE_FEATURES) do enabled[name] = self.Preferences[name]; self:Stop(name) end
        for key in pairs(self.Tasks) do self:Cancel(key) end
        self.Dependencies = {}
        for _, name in ipairs(VAPE_FEATURES) do if enabled[name] then self:Set(name, true) end end
    end

    function runtime:GetStatus()
        local connections, tasks = 0, 0
        for _, scope in pairs(self.Connections) do for _, connection in pairs(scope) do if connection.Connected then connections = connections + 1 end end end
        for _ in pairs(self.Tasks) do tasks = tasks + 1 end
        return {Source = "Vape V4 Block Tales", FeatureCount = #VAPE_FEATURES, Features = copy(self.Status), Options = copy(self.Options), Connections = connections, Tasks = tasks}
    end

    function runtime:Unload()
        if not self.Alive then return end
        for _, name in ipairs(VAPE_FEATURES) do self:Stop(name) end
        self.Alive = false
        for key in pairs(self.Tasks) do self:Cancel(key) end
    end
    return runtime
end

-- Native Rayfield tabs keep Vape, Tex and mxsynry controls separate.
local function CreateVapeControls(runtime, ui)
    if runtime.UI == ui then return end
    runtime.UI, runtime.OptionControls = ui, {}
    local function toggle(tab, feature, label)
        return tab:CreateToggle({
            Name = label or feature,
            Flag = "Vape" .. feature .. "Toggle",
            CurrentValue = runtime.Preferences[feature],
            Callback = function(value) runtime:Set(feature, value) end,
        })
    end
    local function optionToggle(tab, option, label)
        local control = tab:CreateToggle({
            Name = label,
            Flag = "Vape" .. option,
            CurrentValue = runtime.Options[option],
            Callback = function(value) runtime:SetOption(option, value) end,
        })
        runtime.OptionControls[option] = control
    end
    local function slider(tab, option, label, range, increment, suffix)
        runtime.OptionControls[option] = tab:CreateSlider({
            Name = label,
            Flag = "Vape" .. option,
            Range = range,
            Increment = increment or 1,
            Suffix = suffix or "studs/s",
            CurrentValue = runtime.Options[option],
            Callback = function(value) runtime:SetOption(option, value) end,
        })
    end
    local function dropdown(tab, option, label, values)
        runtime.OptionControls[option] = tab:CreateDropdown({
            Name = label,
            Flag = "Vape" .. option,
            Options = values,
            CurrentOption = {runtime.Options[option]},
            MultipleOptions = false,
            Callback = function(selected) if selected[1] then runtime:SetOption(option, selected[1]) end end,
        })
    end

    local combat = ui:CreateTab("Vape Combat", 0, "Vape")
    combat:CreateSection("AutoAction")
    toggle(combat, "AutoAction", "AutoAction — Battle Timing")
    optionToggle(combat, "AutoActionAttacks", "AutoAction: Attacks")
    optionToggle(combat, "AutoActionBlock", "AutoAction: Block")
    combat:CreateSection("Combat Modifiers")
    toggle(combat, "MissCooldown", "Remove Miss Cooldown")
    toggle(combat, "FlyingAttack", "Allow Ground Attacks on Flying Enemies")
    toggle(combat, "AntiHazard", "AntiHazard — Overworld Damage")

    local movement = ui:CreateTab("Vape Movement", 0, "Vape")
    movement:CreateSection("Speed")
    toggle(movement, "Speed")
    dropdown(movement, "SpeedMode", "Speed Method", {"Velocity", "CFrame", "WalkSpeed"})
    slider(movement, "SpeedValue", "Movement Speed", {1, 150})
    movement:CreateSection("Fly")
    toggle(movement, "Fly")
    slider(movement, "FlySpeed", "Fly Speed", {1, 150})
    slider(movement, "FlyVerticalSpeed", "Fly Vertical Speed", {1, 150})
    local keyNames = {}
    for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do if key.Name ~= "Unknown" then keyNames[#keyNames + 1] = key.Name end end
    table.sort(keyNames)
    dropdown(movement, "FlyUpKey", "Fly Up Key (Hold)", keyNames)
    dropdown(movement, "FlyDownKey", "Fly Down Key (Hold)", keyNames)
    movement:CreateSection("LongJump")
    toggle(movement, "LongJump")
    slider(movement, "LongJumpSpeed", "LongJump Speed", {1, 150})
    optionToggle(movement, "LongJumpAutoDisable", "Disable LongJump after Landing")
    movement:CreateSection("SpeedSpin")
    toggle(movement, "SpeedSpin", "SpeedSpin Card Spoof")
    slider(movement, "SpeedSpinCards", "SpeedSpin Card Amount", {0, 10}, 1, "cards")

    local pickups = ui:CreateTab("Vape Pickups", 0, "Vape")
    pickups:CreateSection("PickupTP")
    toggle(pickups, "PickupTP", "Teleport to Active Pickups")
    pickups:CreateSection("PickupTracers")
    toggle(pickups, "PickupTracers", "Pickup Tracers")
    optionToggle(pickups, "TracersBuxOnly", "BUX Only")
    slider(pickups, "TracersTransparency", "Tracer Transparency", {0, 1}, 0.1, "")
    local color = runtime.Options.TracersColor
    runtime.OptionControls.TracersColor = pickups:CreateColorPicker({
        Name = "BUX Color",
        Flag = "VapeTracersColor",
        Color = Color3.new(color.R, color.G, color.B),
        Callback = function(value) runtime:SetOption("TracersColor", value) end,
    })

    local utility = ui:CreateTab("Vape Utility", 0, "Vape")
    utility:CreateSection("AutoCamel")
    toggle(utility, "AutoCamel", "Auto Buy Camels")
    utility:CreateSection("AutoCloudGrind")
    toggle(utility, "AutoCloudGrind", "Cloudie SFX Card Grind")
    utility:CreateSection("AutoFish")
    toggle(utility, "AutoFish", "AutoFish — Catch, Sell and Buy Bait")
    runtime.OptionControls.FishKeepList = utility:CreateInput({
        Name = "Fish Keep List",
        Flag = "VapeFishKeepList",
        CurrentValue = table.concat(runtime.Options.FishKeepList, ", "),
        PlaceholderText = "Fish names separated by commas",
        RemoveTextAfterFocusLost = false,
        Callback = function(value) runtime:SetOption("FishKeepList", value) end,
    })
    utility:CreateSection("AutoPaint")
    toggle(utility, "AutoPaint", "Paint from Solution Easel")
end

RT.Movement = CreateMovementController(RT)
RT.Vape = CreateVapeRuntime(RT)

-- === 5. Rayfield UI and separate control groups ===

-- Rayfield renders every control. This adapter only owns callbacks and settings.
local function CreateRayfieldUI(owner, controller)
    local UI = {
        Alive = true,
        Flags = {},
        Controls = {},
        Tabs = {},
        Order = {},
        LibraryName = "Rayfield",
    }

    local chunk = assert(loadstring(game:HttpGet("https://sirius.menu/rayfield")), "Rayfield failed to compile")
    UI.Library = assert(chunk(), "Rayfield failed to load")

    local function invoke(control, value)
        if not UI.Alive or not controller.Alive or not owner.Alive then
            return false, "unloaded"
        end
        if control.Syncing then return true end

        if control.Group == "Tex" and control.Flag and control.Kind ~= "Dropdown" and not controller.Cleaning then
            BT.UserSettings.Tex[control.Flag] = value
        end
        if control.Flag and controller.InputFlags[control.Flag] and value == true and BT.UserSettings.AutoGreen then
            ENV.ToggleAutoGreen(false)
        end
        if control.Group == "Tex" and controller.InputFlags[control.Flag] and value == true and owner.Vape and owner.Vape:IsEnabled("AutoAction") then
            owner.Vape:Set("AutoAction", false)
        end
        if control.Flag == "SpeedBoostSliderFlag_Main" and value > 0 and owner.Vape and owner.Vape:IsEnabled("Speed") then
            owner.Vape:Set("Speed", false)
        end
        if control.Flag == "GodmodeMovesDamageToggle" and value == true and BT.UserSettings.Godmode then
            ENV.ToggleGodmode(false)
        end

        local ok, err = pcall(control.Callback or function() end, value)
        if not ok then
            owner.DependencyErrors.Tex = tostring(err)
            owner:Notify("Block Tales", tostring(err))
            return false, err
        end
        if not controller.Cleaning then owner:Save() end
        return true
    end

    function UI:CreateWindow(config)
        -- Rayfield supplies the interface; the project controls branding and settings.
        self.Window = self.Library:CreateWindow(config)
        return self
    end

    function UI:CreateTab(name, icon, group)
        local rawTab = self.Window:CreateTab(name, icon)
        local tab = {Name = name, Group = group or "Tex", Raw = rawTab}
        self.Tabs[name] = tab
        self.Order[#self.Order + 1] = tab

        for _, kind in ipairs({"Section", "Divider", "Paragraph", "Label"}) do
            local method = "Create" .. kind
            tab[method] = function(_, ...) return rawTab[method](rawTab, ...) end
        end

        for _, kind in ipairs({"Toggle", "Slider", "Dropdown", "Button", "Input", "ColorPicker"}) do
            local method = "Create" .. kind
            tab[method] = function(_, config)
                local settings = {}
                for key, value in pairs(config) do settings[key] = value end
                local control = {
                    Kind = kind,
                    Name = config.Name,
                    Flag = config.Flag,
                    Group = tab.Group,
                    Tab = name,
                    Config = config,
                    Callback = config.Callback,
                    CurrentValue = kind == "ColorPicker" and config.Color or config.CurrentValue,
                    CurrentOption = config.CurrentOption,
                    Options = config.Options,
                }
                settings.Callback = function(value)
                    control.CallbackCount = (control.CallbackCount or 0) + 1
                    if kind == "Dropdown" then control.CurrentOption = value
                    elseif kind ~= "Button" then control.CurrentValue = value end
                    return invoke(control, value)
                end
                control.Raw = rawTab[method](rawTab, settings)

                function control:Set(value, silent)
                    if kind == "Toggle" and type(value) ~= "boolean" then return false, "expected a boolean" end
                    if kind == "Slider" and (type(value) ~= "number" or value ~= value) then return false, "expected a number" end
                    if kind == "Dropdown" then
                        if type(value) == "string" then value = {value} end
                        if type(value) ~= "table" then return false, "expected a selection table" end
                        self.CurrentOption = value
                    else self.CurrentValue = value end

                    if self.Setting then return true end
                    self.Setting, self.Syncing = true, silent == true
                    local callbackCount = self.CallbackCount or 0
                    local ok, err = pcall(function() self.Raw:Set(value) end)
                    if ok and kind == "ColorPicker" and callbackCount == (self.CallbackCount or 0) then invoke(self, value) end
                    self.Setting, self.Syncing = false, false
                    if not ok then return false, tostring(err) end
                    return true
                end

                if kind == "Dropdown" then
                    function control:Refresh(options, clear)
                        self.Options = options or {}
                        self.Raw:Refresh(self.Options)
                        if clear then self:Set({}, true) end
                    end
                end

                UI.Controls[#UI.Controls + 1] = control
                if control.Flag then UI.Flags[control.Flag] = control end
                return control
            end
        end
        return tab
    end

    function UI:LoadConfiguration()
        self.Library:LoadConfiguration()
        for _, control in ipairs(self.Controls) do
            local value = control.Group == "Tex" and control.Flag and BT.UserSettings.Tex[control.Flag]
            if value ~= nil and (control.Kind == "Toggle" or control.Kind == "Slider") then
                control:Set(value)
            end
        end
    end

    function UI:Notify(config) return self.Library:Notify(config) end
    function UI:Destroy()
        if not self.Alive then return end
        self.Alive = false
        self.Library:Destroy()
    end
    return UI
end

-- mxsynry's controls have their own tab. They are not inserted into Tex's Misc.
local function CreateMxsynryControls(owner, controller)
    local tab = controller.UI:CreateTab("mxsynry", 0, "mxsynry")
    tab:CreateSection("Godmode")
    tab:CreateToggle({
        Name = "Godmode", Flag = "CoreGodmodeToggle", CurrentValue = BT.UserSettings.Godmode,
        Callback = function(value) ENV.ToggleGodmode(value) end,
    })
    tab:CreateSection("AutoGuard (Hook)")
    tab:CreateToggle({
        Name = "AutoGuard (Hook)", Flag = "BlessedHookToggle", CurrentValue = BT.UserSettings.Blessed,
        Callback = function(value) ENV.ToggleAutoGuardHook(value) end,
    })
    tab:CreateSection("AutoGreen")
    tab:CreateToggle({
        Name = "AutoGreen", Flag = "CoreAutoGreenToggle", CurrentValue = BT.UserSettings.AutoGreen,
        Callback = function(value) ENV.ToggleAutoGreen(value) end,
    })
    tab:CreateDropdown({
        Name = "AutoGreen Mode", Flag = "CoreAutoGreenMode",
        Options = {"Legacy", "Battle", "Auto"}, CurrentOption = {owner.Config.AutoGreenMode},
        MultipleOptions = false,
        Callback = function(selection) if selection[1] then ENV.SetAutoGreenMode(selection[1]) end end,
    })
end

-- === 6. Tex lifecycle, input ownership and cleanup ===

local function CreateTexController(owner)
    local controller = {
        Alive = true,
        Owner = owner,
        Connections = {},
        Threads = {},
        Changes = {},
        Exports = {},
        Wrapped = setmetatable({}, {__mode = "kv"}),
        Original = setmetatable({}, {__mode = "k"}),
        InputFlags = {
            ExclamationActionToggleV1_2_1 = true,
            AutoSwordToggle = true,
            AutoLauncherToggle = true,
            AutoDynamiteToggle = true,
            AutoSuperballToggle = true,
            AutoLinebounceToggle = true,
            AutoFishToggle = true,
        },
    }
    BT.UserSettings.Tex = type(BT.UserSettings.Tex) == "table" and BT.UserSettings.Tex or {}

    -- Owned event connections and asynchronous callbacks.
    function controller:Connect(signal, callback)
        local connection = signal:Connect(function(...)
            if self.Alive and owner.Alive then return callback(...) end
        end)
        self.Connections[connection] = true
        local proxy = {}
        self.Original[proxy] = connection
        setmetatable(proxy, {
            __index = function(_, key)
                if key == "Disconnect" or key == "disconnect" then
                    return function()
                        self.Connections[connection] = nil
                        return connection:Disconnect()
                    end
                end
                return connection[key]
            end,
            __tostring = function() return tostring(connection) end,
        })
        return proxy
    end

    function controller:Spawn(callback, arguments, delay, defer)
        if not self.Alive then return nil end
        local thread
        local function run()
            if self.Alive and owner.Alive then
                local ok, err = pcall(callback, unpack(arguments, 1, arguments.n or #arguments))
                if not ok and self.Alive then owner.DependencyErrors.Tex = tostring(err) end
            end
            if thread then self.Threads[thread] = nil end
        end
        if delay then thread = task.delay(delay, run)
        elseif defer then thread = task.defer(run)
        else thread = task.spawn(run) end
        if thread and coroutine.status(thread) ~= "dead" then self.Threads[thread] = true end
        return thread
    end

    -- Track original attributes while keeping Roblox objects weakly cached.
    local function unwrap(value)
        if controller.Original[value] then return controller.Original[value] end
        if typeof(value) == "table" then
            local result = {}
            for key, item in pairs(value) do result[unwrap(key)] = unwrap(item) end
            return result
        end
        return value
    end

    local function remember(instance, name, value)
        local fields = controller.Changes[instance]
        if not fields then
            fields = {}
            controller.Changes[instance] = fields
            pcall(function()
                local connection
                connection = controller:Connect(instance.Destroying, function()
                    controller.Changes[instance] = nil
                    if connection then connection:Disconnect() end
                end)
            end)
        end
        local record = fields[name]
        local current = instance:GetAttribute(name)
        if not record then
            record = {Original = current}
            fields[name] = record
        elseif current ~= record.Written then
            record.Original = current
        end
        record.Written = value
    end

    local wrap
    wrap = function(value)
        local kind = typeof(value)
        if kind == "Instance" or kind == "RBXScriptSignal" then
            if controller.Wrapped[value] then return controller.Wrapped[value] end
            local proxy = {}
            controller.Wrapped[value] = proxy
            controller.Original[proxy] = value
            setmetatable(proxy, {
                __index = function(_, key)
                    if kind == "RBXScriptSignal" and (key == "Connect" or key == "connect") then
                        return function(_, callback)
                            return controller:Connect(value, function(...)
                                local args = {...}
                                local count = select("#", ...)
                                for index = 1, count do args[index] = wrap(args[index]) end
                                return callback(unpack(args, 1, count))
                            end)
                        end
                    end
                    local member = value[key]
                    if type(member) == "function" then
                        return function(_, ...)
                            local count = select("#", ...)
                            local args = {...}
                            for index = 1, count do args[index] = unwrap(args[index]) end
                            if key == "HttpGet" or key == "HttpGetAsync" then
                                error("Recovered feature code does not fetch scripts", 0)
                            end
                            if key == "WaitForChild" and args[2] == nil then
                                args[2], count = owner.Config.DependencyTimeout, 2
                            end
                            if key == "SetAttribute" then remember(value, args[1], args[2]) end
                            local spaceEvent = key == "SendKeyEvent" and args[2] == Enum.KeyCode.Space
                            if spaceEvent and args[1] and owner:InputBlocked() then return end
                            local results = table.pack(member(value, unpack(args, 1, count)))
                            if spaceEvent then controller.HoldingSpace = args[1] == true end
                            for index = 1, results.n do results[index] = wrap(results[index]) end
                            return unpack(results, 1, results.n)
                        end
                    end
                    return wrap(member)
                end,
                __newindex = function(_, key, newValue) value[key] = unwrap(newValue) end,
                __tostring = function() return tostring(value) end,
            })
            return proxy
        elseif kind == "table" then
            local result = {}
            for key, item in pairs(value) do result[wrap(key)] = wrap(item) end
            return result
        end
        return value
    end

    -- Tex's exports and tasks stay inside its own environment and lifecycle.
    local environment = {game = wrap(game), workspace = wrap(workspace)}
    local globals = getfenv and getfenv() or _G
    environment._G = environment
    environment.getgenv = function() return environment end
    environment.typeof = function(value) return typeof(unwrap(value)) end
    environment.task = {
        spawn = function(fn, ...) return controller:Spawn(fn, table.pack(...)) end,
        defer = function(fn, ...) return controller:Spawn(fn, table.pack(...), nil, true) end,
        delay = function(delay, fn, ...) return controller:Spawn(fn, table.pack(...), delay) end,
        cancel = function(thread)
            controller.Threads[thread] = nil
            return task.cancel(thread)
        end,
        wait = function(delay)
            if not controller.Alive then error("unloaded", 0) end
            return task.wait(delay)
        end,
    }
    setmetatable(environment, {
        __index = function(_, name)
            if name == "loadstring" or name == "load" then return nil end
            local value = ENV[name]
            if value ~= nil then return value end
            return globals[name]
        end,
        __newindex = function(self, name, value)
            rawset(self, name, value)
            if type(value) == "function" then
                local safe = function(...)
                    if controller.Alive and owner.Alive then
                        if name == "disableSpeedBoostLoop" then owner.Movement:Stop("Tex") end
                        return value(...)
                    end
                end
                controller.Exports[name] = {Previous = ENV[name], Owned = safe}
                ENV[name] = safe
                if name == "disableSpeedBoostLoop" then rawset(self, name, safe) end
            end
        end,
    })

    -- Rayfield controls and input ownership.
    function controller:Set(flag, value, silent)
        local control = self.UI and self.UI.Flags[flag]
        if not control then return false, "unknown control" end
        return control:Set(value, silent)
    end

    function controller:DisableInput()
        if not self.UI then return end
        for flag in pairs(self.InputFlags) do
            local control = self.UI.Flags[flag]
            if control and control.CurrentValue then control:Set(false) end
        end
        self:ReleaseInput()
    end

    function controller:ReleaseInput()
        if not self.HoldingSpace then return true end
        local ok, err = pcall(function()
            owner.Services.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
        if ok then self.HoldingSpace = false
        else owner.DependencyErrors.Tex = tostring(err) end
        return ok
    end

    function controller:GetStatus()
        local flags, tabs = {}, {}
        if self.UI then
            for name, control in pairs(self.UI.Flags) do
                flags[name] = control.Kind == "Dropdown" and copy(control.CurrentOption) or control.CurrentValue
            end
            for _, tab in ipairs(self.UI.Order) do tabs[#tabs + 1] = tab.Name end
        end
        local connections, threads = 0, 0
        for connection in pairs(self.Connections) do
            if connection.Connected then connections = connections + 1
            else self.Connections[connection] = nil end
        end
        for _ in pairs(self.Threads) do threads = threads + 1 end
        return {
            Alive = self.Alive,
            Source = "local-recovered",
            UILibrary = self.UI and self.UI.LibraryName,
            Tabs = tabs,
            Flags = flags,
            Connections = connections,
            Threads = threads,
            HoldingSpace = self.HoldingSpace == true,
        }
    end

    -- Stop owned work and restore values without changing saved preferences.
    function controller:Unload()
        if not self.Alive then return end
        self.Cleaning = true
        owner.Movement:Stop("Tex")
        self:DisableInput()
        if self.UI then
            for _, control in ipairs(self.UI.Controls) do
                if control.Group == "Tex" and control.Kind == "Toggle" and control.CurrentValue then
                    control:Set(false)
                end
            end
        end
        self.Alive = false
        for connection in pairs(self.Connections) do pcall(function() connection:Disconnect() end) end
        for thread in pairs(self.Threads) do
            if thread ~= coroutine.running() then pcall(task.cancel, thread) end
        end
        for instance, fields in pairs(self.Changes) do
            for name, record in pairs(fields) do
                pcall(function()
                    if instance:GetAttribute(name) == record.Written then
                        instance:SetAttribute(name, record.Original)
                    end
                end)
            end
        end
        for name, record in pairs(self.Exports) do
            if ENV[name] == record.Owned then ENV[name] = record.Previous end
        end
        if self.UI then self.UI:Destroy() end
        self.Connections, self.Threads, self.Changes, self.Wrapped, self.Original = {}, {}, {}, {}, {}
        BT.TexScriptLoaded = false
    end

    pcall(function()
        controller:Connect(owner.Services.RunService.Heartbeat, function()
            if controller.HoldingSpace and owner:InputBlocked() then controller:ReleaseInput() end
        end)
    end)
    return controller, environment
end

-- === 7. TexRBLX feature implementations ===

local function CreateRecoveredTex(owner)
    -- TexRBLX's feature logic, recovered into readable local functions.
    -- Source: https://github.com/TexRBLX/Roblox-stuff/blob/main/block%20tales/revamp.lua
    local controller, environment = CreateTexController(owner)
    owner.Tex = controller
    local rayfieldUI = CreateRayfieldUI(owner, controller)
    controller.UI = rayfieldUI

    local unpackValues = (unpack or table.unpack)

    local selectValues = select

    local function bindClosure(callback, captures)
        return function(...)
            return callback(captures, ...)
        end
    end

    -- Forward declarations for cross-feature callbacks.

    -- Shared helpers
    local enablePremiumDonatorOnlyAnimationFlavors, processBlockTales11539449, processBlockTales11775706
    local processBlockTales11890825, processBlockTales13201946, processBlockTales13360673
    local processBlockTales13557402, processBlockTales14007330, processBlockTales14632010
    local processBlockTales14674032, processBlockTales14907289, processBlockTales1552844
    local processBlockTales16391430, processBlockTales3152566, processBlockTales326220
    local processBlockTales4040501, processBlockTales4881058, processBlockTales5592902
    local processBlockTales5668365, processBlockTales59439, processBlockTales6434089
    local processBlockTales6740426, processBlockTales7736830, processBlockTales7815066
    local processBlockTales7840511, processBlockTales9400209, processBlockTales9403784

    -- Auto Guard
    local exclamationActionToggleV121, processAutoGuard10035586, processAutoGuard16187736
    local processAutoGuard5195988, processBlockTales3339382, processBlockTales7740160
    local processBlockTales9640682, setExclamationActionDelayV1_2_1

    -- Auto Sword
    local processAutoSword5439771, processAutoSword653716, processAutoSword7416568
    local processAutoSword7559693, processAutoSword7693214, processBlockTales5934225
    local processBlockTales6667748, setAutoSwordEnabled, setAutoSwordReleaseDelay

    -- Auto Launcher
    local processAutoLauncher11160503, processAutoLauncher11796690, processAutoLauncher16687945
    local processAutoLauncher3731268, processAutoLauncher5009002, processAutoLauncher608200
    local processAutoLauncher899218, processAutoLauncher9571879, processBlockTales14453497
    local processBlockTales4825171, processBlockTales5544236, setAutoLauncherEnabled

    -- Auto Dynamite
    local processAutoDynamite15368223, processAutoDynamite5778904, setAutoDynamiteEnabled

    -- Auto Superball
    local processAutoSuperball128144, processAutoSuperball14525217, processAutoSuperball15900876
    local processAutoSuperball3201318, processAutoSuperball5609324, processAutoSuperball8660765
    local processBlockTales10648731, processBlockTales16476862, processSuperballTracker12844156
    local processSuperballTracker2111291, processSuperballTracker2958784, processSuperballTracker4879227
    local setAutoSuperballDistance, setAutoSuperballEnabled

    -- Auto Linebounce
    local processAutoLinebounce13008852, processAutoLinebounce13440583, processAutoLinebounce13925999
    local processAutoLinebounce16489682, processAutoLinebounce2848273, setAutoLinebounceEnabled
    local setLinebounceDelay

    -- Collectibles
    local processBlockTales10749514, processBlockTales2703507, processBlockTales4568261
    local processBlockTales5658758, processBlockTales9884350, processCollectibleTP14642422
    local processCollectibleTP15879216, processCollectibleTP16310991, scanCollectibleCategory
    local scanCollectiblesLoop, selectCollectibleBuxTP, selectCollectibleCardTP
    local selectCollectibleItemTP, tPBack, teleportToSelectedBUX
    local teleportToSelectedCard, teleportToSelectedItem

    -- Enemy targeting
    local disableEnemyDropdownSystem, disableForceGroundEnemies, enableEnemyDropdownSystem
    local enableForceGroundEnemies, processArenaEnemies1989314, processArenaEnemies3920321
    local processBlockTales15516991, processBlockTales4924877, processBlockTales5793115
    local selectArenaEnemyTarget, setForceGroundEnemiesEnabled, updateArenaEnemies

    -- Godmode
    local applyMoveDamageSettings, processGodmodeMoves14882525, processGodmodeMoves15234720
    local setGodmodeMovesDamageEnabled

    -- Fishing
    local setAutoFishEnabled

    -- Speed Boost
    local disableSpeedBoostLoop, enableSpeedBoostLoop, updateSpeedBoostMovement
    local processBlockTales12404771, setSpeedBoost

    -- Logging
    local printDebug, printFeatureWarning, printNotificationDebug
    local showNotification, toggleDebugMessagesDevConsole, toggleNotifications

    -- Initialization
    local initializeBlockTales

    -- === Tex / Shared helpers ===

    enablePremiumDonatorOnlyAnimationFlavors = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local H
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local x
        local z
        x = environment.game
        S = x.GetService
        S = S(x, "Players")
        p = S.LocalPlayer
        d = p.PlayerGui
        c = d.HUD
        W = c.Menu
        H = W.Settings
        z = H.Middle
        e = z.Flavor2
        resultValues = e.Frame
        temporary = resultValues.Gold
        temporary.Visible = true
        x = environment.game
        S = x.GetService
        S = S(x, "Players")
        p = S.LocalPlayer
        d = p.PlayerGui
        c = d.HUD
        W = c.Menu
        H = W.Settings
        z = H.Middle
        e = z.Flavor2
        resultValues = e.Frame
        temporary = resultValues.Club
        temporary.Visible = true
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales11539449 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        z = H.Space
        resultValues = temporary.SendKeyEvent
        W = environment.game
        resultValues = resultValues(temporary, true, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales11775706 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local H, e, resultValues, temporary, z
        e = argument1
        z = argument2
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales11890825 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local branchCondition
        local H
        local I
        local M
        local Q
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            resultValues = temporary("FlyingEnemies", "Enabling 'Force Ground Enemies'. Setting 'Flying' to false.")
        else
            temporary = captures[1].value
            resultValues = temporary("FlyingEnemies", "Disabling 'Force Ground Enemies'. Restoring original 'Flying' state.")
        end
        temporary = {}
        z = temporary
        temporary = environment.pairs
        c = captures[2].value
        d = {temporary(c)}
        W = d[3]
        resultValues = d[1]
        H = d[2]
        c = resultValues
        while true do
            local exitLoop1 = false
            repeat
                W, p = c(H, W)
                branchCondition = W
                if branchCondition then
                    d = W
                    x = environment.table
                    temporary = x.insert
                    x = temporary(z, d)
                    break
                else
                end
                exitLoop1 = true
                break
            until true
            if exitLoop1 then
                break
            end
        end
        temporary = environment.ipairs
        d = captures[3].value
        p = {temporary(d)}
        H = p[1]
        c = p[3]
        W = p[2]
        while true do
            local exitLoop2 = false
            repeat
                c, p = H(W, c)
                branchCondition = c
                if branchCondition then
                    x = environment.table
                    temporary = x.insert
                    S = p.Instance
                    x = temporary(z, S)
                    break
                else
                end
                exitLoop2 = true
                break
            until true
            if exitLoop2 then
                break
            end
        end
        temporary = environment.ipairs
        d = {temporary(z)}
        H = d[1]
        c = d[3]
        W = d[2]
        while true do
            local exitLoop3 = false
            repeat
                c, p = H(W, c)
                branchCondition = c
                if branchCondition then
                    x = p
                    branchCondition = p
                    if branchCondition then
                        S = p.Parent
                        x = S
                    else
                    end
                    branchCondition = x
                    if branchCondition then
                        branchCondition = e
                        if branchCondition then
                            temporary = p.GetAttribute
                            temporary = temporary(p, "Flying")
                            S = environment.type
                            x = temporary
                            u = S(x)
                            temporary = (u == "boolean")
                            branchCondition = temporary
                            if branchCondition then
                                u = captures[2].value
                                S = u[p]
                                temporary = (S == nil)
                                branchCondition = temporary
                                if branchCondition then
                                    S = x
                                    temporary = captures[2].value
                                    temporary[p] = S
                                else
                                end
                                temporary = (x == true)
                                branchCondition = temporary
                                if branchCondition then
                                    temporary = environment.pcall
                                    s = p.SetAttribute
                                    Z = {temporary(s, p, "Flying", false)}
                                    u = Z[2]
                                    S = Z[1]
                                    temporary = (not S)
                                    branchCondition = temporary
                                    if branchCondition then
                                        temporary = captures[4].value
                                        o = p.Name
                                        M = ("Failed to set 'Flying' for %s to false: %s").format
                                        Z = {M("Failed to set 'Flying' for %s to false: %s", o, u)}
                                        s = temporary("FlyingEnemies", unpackValues(Z))
                                    else
                                    end
                                else
                                end
                            else
                            end
                        else
                            x = captures[2].value
                            temporary = x[p]
                            x = temporary
                            u = (x ~= nil)
                            S = u
                            branchCondition = u
                            if branchCondition then
                                s = environment.type
                                Q = s(x)
                                u = (Q == "boolean")
                                S = u
                            else
                            end
                            branchCondition = S
                            if branchCondition then
                                temporary = environment.pcall
                                s = p.SetAttribute
                                i = {temporary(s, p, "Flying", x)}
                                u = i[2]
                                S = i[1]
                                temporary = (not S)
                                branchCondition = temporary
                                if branchCondition then
                                    temporary = captures[4].value
                                    o = p.Name
                                    M = environment.tostring
                                    I = M(x)
                                    M = ("Failed to restore 'Flying' for %s to %s: %s").format
                                    Z = {M("Failed to restore 'Flying' for %s to %s: %s", o, I, u)}
                                    s = temporary("FlyingEnemies", unpackValues(Z))
                                else
                                end
                                temporary = captures[2].value
                                temporary[p] = nil
                            else
                            end
                        end
                    else
                        x = captures[2].value
                        temporary = x[p]
                        branchCondition = temporary
                        if branchCondition then
                            temporary = captures[2].value
                            temporary[p] = nil
                        else
                        end
                    end
                    break
                else
                end
                exitLoop3 = true
                break
            until true
            if exitLoop3 then
                break
            end
        end
        temporary = captures[5].value
        branchCondition = temporary
        if branchCondition then
            temporary = captures[6].value
            H = temporary()
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales13201946 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H
        local W
        local c
        local e
        local p
        local resultValues
        local temporary
        local x
        local z
        temporary = captures[1].value
        resultValues = temporary("Core", "UnloadScriptAndUI called.")
        temporary = captures[2].value
        branchCondition = temporary
        if branchCondition then
            temporary = captures[3].value
            resultValues = temporary()
        else
        end
        temporary = captures[4].value
        branchCondition = temporary
        if branchCondition then
            temporary = captures[5].value
            resultValues = temporary()
        else
        end
        temporary = captures[6].value
        branchCondition = temporary
        if branchCondition then
            temporary = environment.disableEnemyDropdownSystem
            resultValues = temporary()
        else
        end
        temporary = captures[7].value
        branchCondition = temporary
        if branchCondition then
            temporary = environment.disableForceGroundEnemies
            resultValues = temporary()
        else
        end
        e = captures[8].value
        resultValues = e
        branchCondition = e
        if branchCondition then
            z = captures[8].value
            e = z.Connected
            resultValues = e
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[8].value
            resultValues = temporary.Disconnect
            resultValues = resultValues(temporary)
            captures[8].value = nil
        else
        end
        z = captures[9].value
        resultValues = z
        branchCondition = z
        if branchCondition then
            H = captures[9].value
            z = H.Connected
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            resultValues = captures[9].value
            e = resultValues.Disconnect
            e = e(resultValues)
            captures[9].value = nil
        else
        end
        H = captures[10].value
        branchCondition = H
        e = H
        if branchCondition then
            W = captures[10].value
            H = W.Connected
            e = H
        else
        end
        branchCondition = e
        if branchCondition then
            e = captures[10].value
            z = e.Disconnect
            z = z(e)
            captures[10].value = nil
        else
        end
        z = captures[11].value
        branchCondition = z
        if branchCondition then
            z = captures[12].value
            H = z()
        else
        end
        z = captures[13].value
        branchCondition = z
        if branchCondition then
            z = captures[14].value
            H = z()
        else
        end
        z = captures[15].value
        branchCondition = z
        if branchCondition then
            z = captures[16].value
            H = z()
        else
        end
        z = captures[17].value
        branchCondition = z
        if branchCondition then
            z = environment.disableAutoLinebounce
            H = z()
        else
        end
        z = captures[18].value
        branchCondition = z
        if branchCondition then
            z = environment.disableSpeedBoostLoop
            H = z()
        else
        end
        z = captures[19].value
        branchCondition = z
        if branchCondition then
            z = captures[20].value
            H = z(false)
        else
        end
        z = {}
        captures[21].value = z
        H = captures[22].value
        W = H(false)
        c = captures[23].value
        branchCondition = c
        H = c
        if branchCondition then
            p = captures[24].value
            c = p
            branchCondition = p
            if branchCondition then
                x = captures[24].value
                p = x.Destroy
                c = p
            else
            end
            H = c
        else
        end
        branchCondition = H
        if branchCondition then
            H = captures[24].value
            c = captures[23].value
            W = H.Destroy
            W = W(H, c)
            H = captures[1].value
            W = H("UI", "Rayfield window destroyed.")
        else
        end
        resultValues = {}
        H = environment.print
        W = H("Script features disabled and UI unloaded (attempted).")
        return unpackValues(resultValues)
    end

    processBlockTales13360673 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local H, e, resultValues, temporary, z
        z = argument2
        e = argument1
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales13557402 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6, argument7)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6, argument7}
        local H, e, resultValues, temporary, z
        e = argument1
        z = argument2
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales14007330 = function(captures)
        local argumentValues = {}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            resultValues = environment.table
            temporary = resultValues.sort
            z = bindClosure(processBlockTales59439, {})
            e = captures[2].value
            resultValues = temporary(e, z)
            z = captures[2].value
            temporary = {}
            resultValues = (# z)
            e = temporary
            temporary = (resultValues == 0)
            branchCondition = temporary
            if branchCondition then
                resultValues = environment.table
                temporary = resultValues.insert
                resultValues = temporary(e, "- No Items Found -")
            else
                temporary = environment.ipairs
                W = captures[2].value
                c = {temporary(W)}
                z = c[2]
                H = c[3]
                resultValues = c[1]
                W = resultValues
                while true do
                    local exitLoop1 = false
                    repeat
                        H, d = W(z, H)
                        branchCondition = H
                        if branchCondition then
                            p = environment.table
                            temporary = p.insert
                            x = d.DisplayName
                            p = temporary(e, x)
                            break
                        else
                        end
                        exitLoop1 = true
                        break
                    until true
                    if exitLoop1 then
                        break
                    end
                end
            end
            z = captures[1].value
            temporary = z.CurrentOption
            z = temporary
            W = z
            H = nil
            branchCondition = z
            if branchCondition then
                x = environment.type
                S = x(z)
                p = (S == "table")
                c = p
                branchCondition = p
                if branchCondition then
                    x = (# z)
                    p = (x > 0)
                    c = p
                else
                end
                W = c
            else
            end
            branchCondition = W
            if branchCondition then
                temporary = z[1]
                H = temporary
            else
            end
            W = false
            d = (# e)
            S = captures[1].value
            x = S.Options
            p = (# x)
            c = (d ~= p)
            branchCondition = c
            if branchCondition then
                W = true
            else
                p = (# e)
                x = p
                u = (1 < 0)
                p = 0
                while true do
                    local exitLoop2 = false
                    repeat
                        s = (not u)
                        p = (p + 1)
                        d = (p <= x)
                        d = (s and d)
                        s = (p >= x)
                        s = (u and s)
                        d = (s or d)
                        temporary = (d and 14183486)
                        branchCondition = temporary
                        if branchCondition then
                            d = p
                            Q = e[d]
                            o = captures[1].value
                            Z = o.Options
                            i = Z[d]
                            s = (Q ~= i)
                            branchCondition = s
                            if branchCondition then
                                W = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop2 = true
                        break
                    until true
                    if exitLoop2 then
                        break
                    end
                end
            end
            branchCondition = W
            if branchCondition then
                d = captures[1].value
                p = d.Refresh
                p = p(d, e)
                d = captures[3].value
                p = d("ItemTP", "Item Dropdown refreshed.")
            else
            end
            S = captures[4].value
            d = false
            p = S
            branchCondition = S
            if branchCondition then
                Q = captures[2].value
                u = (# Q)
                S = (u > 0)
                p = S
            else
            end
            branchCondition = p
            if branchCondition then
                p = environment.ipairs
                Q = captures[2].value
                i = {p(Q)}
                S = i[2]
                u = i[3]
                x = i[1]
                while true do
                    local exitLoop3 = false
                    repeat
                        u, Q = x(S, u)
                        branchCondition = u
                        if branchCondition then
                            Z = Q.DisplayName
                            o = captures[4].value
                            i = (Z == o)
                            branchCondition = i
                            if branchCondition then
                                Z = captures[4].value
                                i = (H ~= Z)
                                branchCondition = i
                                if branchCondition then
                                    i = captures[1].value
                                    M = captures[4].value
                                    Z = i.Set
                                    o = {M}
                                    Z = Z(i, o)
                                else
                                end
                                i = Q.Instance
                                captures[5].value = i
                                d = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop3 = true
                        break
                    until true
                    if exitLoop3 then
                        break
                    end
                end
            else
            end
            p = (not d)
            branchCondition = p
            if branchCondition then
                p = false
                x = H
                branchCondition = H
                if branchCondition then
                    o = (H ~= "- No Items Found -")
                    branchCondition = o
                    u = o
                    if branchCondition then
                        o = (H ~= "Scanning Items...")
                        u = o
                    else
                    end
                    x = u
                else
                end
                branchCondition = x
                if branchCondition then
                    x = environment.ipairs
                    o = captures[2].value
                    M = {x(o)}
                    u = M[2]
                    Q = M[3]
                    S = M[1]
                    while true do
                        local exitLoop4 = false
                        repeat
                            Q, o = S(u, Q)
                            branchCondition = Q
                            if branchCondition then
                                I = o.DisplayName
                                M = (I == H)
                                branchCondition = M
                                if branchCondition then
                                    p = true
                                    I = o.Instance
                                    captures[5].value = I
                                else
                                    break
                                end
                            else
                            end
                            exitLoop4 = true
                            break
                        until true
                        if exitLoop4 then
                            break
                        end
                    end
                else
                end
                x = (not p)
                branchCondition = x
                if branchCondition then
                    u = e[1]
                    x = (u or "- No Items Found -")
                    Q = captures[2].value
                    u = (# Q)
                    S = (u > 0)
                    branchCondition = S
                    if branchCondition then
                        S = (H ~= x)
                        branchCondition = S
                        if branchCondition then
                            Q = {x}
                            S = captures[1].value
                            u = S.Set
                            u = u(S, Q)
                        else
                        end
                        S = (x ~= "- No Items Found -")
                        branchCondition = S
                        if branchCondition then
                            o = captures[2].value
                            Q = o[1]
                            S = Q
                            branchCondition = Q
                            if branchCondition then
                                D = captures[2].value
                                o = D[1]
                                Q = o.Instance
                                S = Q
                            else
                            end
                            captures[5].value = S
                        else
                            captures[5].value = nil
                        end
                    else
                        D = (H ~= nil)
                        branchCondition = D
                        Q = D
                        if branchCondition then
                            D = (H ~= "- No Items Found -")
                            Q = D
                        else
                        end
                        branchCondition = Q
                        if branchCondition then
                            Q = captures[1].value
                            D = {"- No Items Found -"}
                            o = Q.Set
                            o = o(Q, D)
                        else
                        end
                        captures[5].value = nil
                    end
                else
                end
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processBlockTales14632010 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local H
        local Q
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        e = argument1
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            resultValues = e
            z = nil
            branchCondition = e
            if branchCondition then
                c = e.IsA
                c = c(e, "Attachment")
                branchCondition = c
                H = c
                if branchCondition then
                    x = e.Name
                    p = (x == "Attachment")
                    branchCondition = p
                    c = p
                    if branchCondition then
                        p = e.FindFirstChild
                        p = p(e, "exclamation")
                        c = p
                    else
                    end
                    H = c
                else
                end
                resultValues = H
            else
            end
            branchCondition = resultValues
            if branchCondition then
                temporary = e
                z = temporary
            else
                resultValues = e
                branchCondition = e
                if branchCondition then
                    p = e.Name
                    d = (p == "exclamation")
                    branchCondition = d
                    W = d
                    if branchCondition then
                        x = e.Parent
                        d = x
                        branchCondition = x
                        if branchCondition then
                            u = e.Parent
                            s = u.IsA
                            s = s(u, "Attachment")
                            x = s
                            branchCondition = s
                            if branchCondition then
                                Q = e.Parent
                                s = Q.Name
                                u = (s == "Attachment")
                                x = u
                            else
                            end
                            d = x
                        else
                        end
                        W = d
                    else
                    end
                    resultValues = W
                else
                end
                branchCondition = resultValues
                if branchCondition then
                    resultValues = e.Parent
                    z = resultValues
                else
                end
            end
            branchCondition = z
            if branchCondition then
                c = captures[2].value
                W = c[z]
                H = (not W)
                branchCondition = H
                if branchCondition then
                    c = z.Parent
                    branchCondition = c
                    H = c
                    if branchCondition then
                        c = z.FindFirstChild
                        c = c(z, "exclamation")
                        H = c
                    else
                    end
                    branchCondition = H
                    if branchCondition then
                        H = captures[3].value
                        x = z.GetFullName
                        p = {x(z)}
                        W = H("Excla", "New potential Attachment found:", unpackValues(p))
                        H = captures[2].value
                        H[z] = "pending_scan"
                        W = environment.task
                        H = W.spawn
                        c = captures[4].value
                        W = H(c, z)
                    else
                    end
                else
                end
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processBlockTales14674032 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H
        local W
        local c
        local d
        local e
        local resultValues
        local temporary
        local x
        local z
        z = argument2
        e = argument1
        H = e
        temporary = environment.ipairs
        d = {temporary(z)}
        W = d[2]
        c = d[3]
        resultValues = d[1]
        d = resultValues
        while true do
            local exitLoop1 = false
            repeat
                c, x = d(W, c)
                branchCondition = c
                if branchCondition then
                    temporary = (not H)
                    branchCondition = temporary
                    if branchCondition then
                        resultValues = {nil}
                    else
                        temporary = H.FindFirstChild
                        temporary = temporary(H, x)
                        H = temporary
                        break
                    end
                else
                    resultValues = {H}
                end
                exitLoop1 = true
                break
            until true
            if exitLoop1 then
                break
            end
        end
        return unpackValues(resultValues)
    end

    processBlockTales14907289 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6, argument7)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6, argument7}
        local H, e, resultValues, temporary, z
        e = argument1
        z = argument2
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales1552844 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local e, resultValues, temporary
        e = bindClosure(processBlockTales11539449, {captures[1]})
        temporary = environment.pcall
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales16391430 = function(captures, argument1)
        local argumentValues = {argument1}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        resultValues = temporary.SendKeyEvent
        H = W.KeyCode
        z = H.Space
        W = environment.game
        resultValues = resultValues(temporary, false, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales3152566 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            z = bindClosure(processBlockTales11775706, {})
            resultValues = environment.table
            temporary = resultValues.sort
            e = captures[2].value
            resultValues = temporary(e, z)
            temporary = {}
            e = temporary
            z = captures[2].value
            resultValues = (# z)
            temporary = (resultValues == 0)
            branchCondition = temporary
            if branchCondition then
                resultValues = environment.table
                temporary = resultValues.insert
                resultValues = temporary(e, "- No BUX Found -")
            else
                temporary = environment.ipairs
                W = captures[2].value
                c = {temporary(W)}
                z = c[2]
                resultValues = c[1]
                H = c[3]
                W = resultValues
                while true do
                    local exitLoop1 = false
                    repeat
                        H, d = W(z, H)
                        branchCondition = H
                        if branchCondition then
                            p = environment.table
                            temporary = p.insert
                            x = d.DisplayName
                            p = temporary(e, x)
                            break
                        else
                        end
                        exitLoop1 = true
                        break
                    until true
                    if exitLoop1 then
                        break
                    end
                end
            end
            z = captures[1].value
            temporary = z.CurrentOption
            z = temporary
            W = z
            H = nil
            branchCondition = z
            if branchCondition then
                x = environment.type
                S = x(z)
                p = (S == "table")
                c = p
                branchCondition = p
                if branchCondition then
                    x = (# z)
                    p = (x > 0)
                    c = p
                else
                end
                W = c
            else
            end
            branchCondition = W
            if branchCondition then
                temporary = z[1]
                H = temporary
            else
            end
            W = false
            d = (# e)
            S = captures[1].value
            x = S.Options
            p = (# x)
            c = (d ~= p)
            branchCondition = c
            if branchCondition then
                W = true
            else
                p = (# e)
                x = p
                u = (1 < 0)
                p = 0
                while true do
                    local exitLoop2 = false
                    repeat
                        p = (p + 1)
                        d = (p <= x)
                        s = (not u)
                        d = (s and d)
                        s = (p >= x)
                        s = (u and s)
                        d = (s or d)
                        temporary = (d and 10943753)
                        branchCondition = temporary
                        if branchCondition then
                            d = p
                            Q = e[d]
                            o = captures[1].value
                            Z = o.Options
                            i = Z[d]
                            s = (Q ~= i)
                            branchCondition = s
                            if branchCondition then
                                W = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop2 = true
                        break
                    until true
                    if exitLoop2 then
                        break
                    end
                end
            end
            branchCondition = W
            if branchCondition then
                d = captures[1].value
                p = d.Refresh
                p = p(d, e)
                d = captures[3].value
                p = d("BuxTP", "BUX Dropdown refreshed.")
            else
            end
            d = false
            S = captures[4].value
            p = S
            branchCondition = S
            if branchCondition then
                Q = captures[2].value
                u = (# Q)
                S = (u > 0)
                p = S
            else
            end
            branchCondition = p
            if branchCondition then
                p = environment.ipairs
                Q = captures[2].value
                i = {p(Q)}
                u = i[3]
                x = i[1]
                S = i[2]
                while true do
                    local exitLoop3 = false
                    repeat
                        u, Q = x(S, u)
                        branchCondition = u
                        if branchCondition then
                            Z = Q.DisplayName
                            o = captures[4].value
                            i = (Z == o)
                            branchCondition = i
                            if branchCondition then
                                Z = captures[4].value
                                i = (H ~= Z)
                                branchCondition = i
                                if branchCondition then
                                    i = captures[1].value
                                    M = captures[4].value
                                    Z = i.Set
                                    o = {M}
                                    Z = Z(i, o)
                                else
                                end
                                i = Q.Instance
                                captures[5].value = i
                                d = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop3 = true
                        break
                    until true
                    if exitLoop3 then
                        break
                    end
                end
            else
            end
            p = (not d)
            branchCondition = p
            if branchCondition then
                p = false
                x = H
                branchCondition = H
                if branchCondition then
                    o = (H ~= "- No BUX Found -")
                    u = o
                    branchCondition = o
                    if branchCondition then
                        o = (H ~= "Scanning BUX...")
                        u = o
                    else
                    end
                    x = u
                else
                end
                branchCondition = x
                if branchCondition then
                    x = environment.ipairs
                    o = captures[2].value
                    M = {x(o)}
                    Q = M[3]
                    u = M[2]
                    S = M[1]
                    while true do
                        local exitLoop4 = false
                        repeat
                            Q, o = S(u, Q)
                            branchCondition = Q
                            if branchCondition then
                                I = o.DisplayName
                                M = (I == H)
                                branchCondition = M
                                if branchCondition then
                                    I = o.Instance
                                    captures[5].value = I
                                    p = true
                                else
                                    break
                                end
                            else
                            end
                            exitLoop4 = true
                            break
                        until true
                        if exitLoop4 then
                            break
                        end
                    end
                else
                end
                x = (not p)
                branchCondition = x
                if branchCondition then
                    u = e[1]
                    x = (u or "- No BUX Found -")
                    Q = captures[2].value
                    u = (# Q)
                    S = (u > 0)
                    branchCondition = S
                    if branchCondition then
                        S = (H ~= x)
                        branchCondition = S
                        if branchCondition then
                            S = captures[1].value
                            Q = {x}
                            u = S.Set
                            u = u(S, Q)
                        else
                        end
                        S = (x ~= "- No BUX Found -")
                        branchCondition = S
                        if branchCondition then
                            o = captures[2].value
                            Q = o[1]
                            S = Q
                            branchCondition = Q
                            if branchCondition then
                                D = captures[2].value
                                o = D[1]
                                Q = o.Instance
                                S = Q
                            else
                            end
                            captures[5].value = S
                        else
                            captures[5].value = nil
                        end
                    else
                        D = (H ~= nil)
                        Q = D
                        branchCondition = D
                        if branchCondition then
                            D = (H ~= "- No BUX Found -")
                            Q = D
                        else
                        end
                        branchCondition = Q
                        if branchCondition then
                            D = {"- No BUX Found -"}
                            Q = captures[1].value
                            o = Q.Set
                            o = o(Q, D)
                        else
                        end
                        captures[5].value = nil
                    end
                else
                end
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processBlockTales326220 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local T
        local W
        local Z
        local c
        local d
        local e
        local g
        local i
        local k
        local n
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local w
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            z = captures[2].value
            H = z()
            e = (not H)
            resultValues = e
            branchCondition = e
            if branchCondition then
            else
                z = captures[3].value
                e = (not z)
                resultValues = e
            end
            branchCondition = resultValues
            if branchCondition then
                H = captures[4].value
                z = (# H)
                e = (z > 0)
                resultValues = e
                branchCondition = e
                if branchCondition then
                else
                    z = captures[5].value
                    e = (z > 0)
                    resultValues = e
                end
                branchCondition = resultValues
                if branchCondition then
                    temporary = {}
                    captures[4].value = temporary
                    captures[5].value = 0
                    e = captures[6].value
                    branchCondition = e
                    if branchCondition then
                        e = captures[6].value
                        z = e()
                    else
                    end
                else
                end
                resultValues = {}
            else
                e = captures[7].value
                W = {"Geometry"}
                H = captures[3].value
                z = e(H, W)
                e = (not z)
                branchCondition = e
                if branchCondition then
                    d = captures[4].value
                    c = (# d)
                    W = (c > 0)
                    e = W
                    branchCondition = W
                    if branchCondition then
                    else
                        c = captures[5].value
                        W = (c > 0)
                        e = W
                    end
                    branchCondition = e
                    if branchCondition then
                        e = {}
                        captures[4].value = e
                        captures[5].value = 0
                        W = captures[6].value
                        branchCondition = W
                        if branchCondition then
                            W = captures[6].value
                            c = W()
                        else
                        end
                    else
                    end
                    resultValues = {}
                else
                    W = {}
                    c = 0
                    d = environment.ipairs
                    s = z.GetChildren
                    u = {s(z)}
                    s = {d(unpackValues(u))}
                    x = s[2]
                    p = s[1]
                    S = s[3]
                    while true do
                        local exitLoop1 = false
                        repeat
                            S, u = p(x, S)
                            branchCondition = S
                            if branchCondition then
                                Z = u.Name
                                i = (Z == "BUX")
                                s = i
                                branchCondition = i
                                if branchCondition then
                                    i = u.IsA
                                    i = i(u, "BasePart")
                                    s = i
                                else
                                end
                                branchCondition = s
                                if branchCondition then
                                    s = (c + 1)
                                    c = s
                                    o = environment.math
                                    Z = o.floor
                                    I = u.Position
                                    i = ("BUX #%d (Pos: %d,%d,%d)").format
                                    M = I.X
                                    o = Z(M)
                                    M = environment.math
                                    Z = M.floor
                                    D = u.Position
                                    I = D.Y
                                    M = Z(I)
                                    I = environment.math
                                    Z = I.floor
                                    w = u.Position
                                    D = w.Z
                                    I = {Z(D)}
                                    i = i("BUX #%d (Pos: %d,%d,%d)", c, o, M, unpackValues(I))
                                    Z = environment.table
                                    Q = Z.insert
                                    o = {
                                        DisplayName = i,
                                        Instance = u,
                                    }
                                    Z = Q(W, o)
                                else
                                end
                                break
                            else
                            end
                            exitLoop1 = true
                            break
                        until true
                        if exitLoop1 then
                            break
                        end
                    end
                    S = (# W)
                    x = (S > 0)
                    branchCondition = x
                    d = x
                    if branchCondition then
                        S = (# W)
                        u = captures[5].value
                        x = (S > u)
                        d = x
                    else
                    end
                    branchCondition = d
                    if branchCondition then
                        d = captures[8].value
                        Q = (# W)
                        Z = captures[3].value
                        i = Z.Name
                        u = ("%d BUX found in %s!").format
                        u = u("%d BUX found in %s!", Q, i)
                        p = d("Collectible Alert", u, 4)
                    else
                    end
                    d = (# W)
                    p = false
                    captures[5].value = d
                    S = (# W)
                    Q = captures[4].value
                    u = (# Q)
                    x = (S ~= u)
                    branchCondition = x
                    if branchCondition then
                        p = true
                    else
                        u = environment.table
                        S = u.sort
                        Q = bindClosure(processBlockTales5592902, {})
                        u = S(W, Q)
                        S = {}
                        u = environment.ipairs
                        o = captures[4].value
                        M = {u(o)}
                        Z = M[3]
                        i = M[2]
                        Q = M[1]
                        while true do
                            local exitLoop2 = false
                            repeat
                                Z, o = Q(i, Z)
                                branchCondition = Z
                                if branchCondition then
                                    I = environment.table
                                    M = I.insert
                                    I = M(S, o)
                                    break
                                else
                                end
                                exitLoop2 = true
                                break
                            until true
                            if exitLoop2 then
                                break
                            end
                        end
                        Q = environment.table
                        u = Q.sort
                        i = bindClosure(processBlockTales14907289, {})
                        Q = u(S, i)
                        Q = (# W)
                        i = Q
                        o = (1 < 0)
                        Q = 0
                        while true do
                            local exitLoop3 = false
                            repeat
                                Q = (Q + 1)
                                u = (Q <= i)
                                M = (not o)
                                u = (M and u)
                                M = (Q >= i)
                                M = (o and M)
                                u = (M or u)
                                temporary = (u and 15676207)
                                branchCondition = temporary
                                if branchCondition then
                                    u = Q
                                    w = S[u]
                                    D = (not w)
                                    branchCondition = D
                                    M = D
                                    if branchCondition then
                                    else
                                        g = W[u]
                                        k = g.Instance
                                        n = S[u]
                                        g = n.Instance
                                        T = (k ~= g)
                                        branchCondition = T
                                        D = T
                                        if branchCondition then
                                        else
                                            g = W[u]
                                            k = g.DisplayName
                                            n = S[u]
                                            g = n.DisplayName
                                            T = (k ~= g)
                                            D = T
                                        end
                                        M = D
                                    end
                                    branchCondition = M
                                    if branchCondition then
                                        p = true
                                    else
                                        break
                                    end
                                else
                                end
                                exitLoop3 = true
                                break
                            until true
                            if exitLoop3 then
                                break
                            end
                        end
                    end
                    branchCondition = p
                    if branchCondition then
                        S = W
                        captures[4].value = S
                        u = captures[6].value
                        branchCondition = u
                        if branchCondition then
                            u = captures[6].value
                            Q = u()
                        else
                        end
                    else
                    end
                    resultValues = {}
                end
            end
        end
        return unpackValues(resultValues)
    end

    processBlockTales4040501 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local H, W, c, d, e, resultValues, temporary, z
        e = argument1
        H = e.Name
        z = (H == "Badge")
        resultValues = z
        branchCondition = z
        if branchCondition then
            W = e.IsA
            W = W(e, "BasePart")
            branchCondition = W
            z = W
            if branchCondition then
                d = captures[1].value
                c = d[e]
                W = (not c)
                z = W
            else
            end
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[1].value
            temporary[e] = true
            temporary = e.GetAttribute
            temporary = temporary(e, "Item")
            z = temporary
            resultValues = z
            branchCondition = z
            if branchCondition then
                W = environment.type
                c = W(z)
                H = (c == "string")
                resultValues = H
            else
            end
            branchCondition = resultValues
            if branchCondition then
                W = e.Parent
                resultValues = ("%s (%s)").format
                H = W.Name
                resultValues = resultValues("%s (%s)", z, H)
                H = resultValues
                c = {
                    DisplayName = H,
                    Instance = e,
                }
                resultValues = environment.table
                temporary = resultValues.insert
                W = captures[2].value
                resultValues = temporary(W, c)
            else
            end
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales4881058 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H, W, c, e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            temporary = captures[2].value
            resultValues = temporary.FindFirstChild
            resultValues = resultValues(temporary, "PlayerGui")
            e = resultValues
            temporary = (not e)
            branchCondition = temporary
            if branchCondition then
                resultValues = {}
            else
                temporary = captures[3].value
                z = {"HUD", "Battle", "DOITNOW3"}
                resultValues = temporary(e, z)
                z = resultValues
                resultValues = z
                branchCondition = z
                if branchCondition then
                    c = z.IsA
                    c = c(z, "Frame")
                    H = c
                    branchCondition = c
                    if branchCondition then
                        c = z.Visible
                        H = c
                    else
                    end
                    resultValues = H
                else
                end
                branchCondition = resultValues
                if branchCondition then
                    temporary = captures[4].value
                    resultValues = temporary()
                    resultValues = environment.task
                    temporary = resultValues.wait
                    W = captures[5].value
                    H = (W / 2)
                    resultValues = temporary(H)
                    temporary = captures[6].value
                    resultValues = temporary()
                else
                end
                resultValues = {}
            end
        end
        return unpackValues(resultValues)
    end

    processBlockTales5592902 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local H, e, resultValues, temporary, z
        z = argument2
        e = argument1
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales5668365 = function(captures, argument1)
        local argumentValues = {argument1}
        local e, resultValues, temporary
        e = bindClosure(processBlockTales16391430, {captures[1]})
        temporary = environment.pcall
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales59439 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local H, e, resultValues, temporary, z
        e = argument1
        z = argument2
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales6434089 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local branchCondition
        local H
        local W
        local d
        local e
        local p
        local resultValues
        local temporary
        local x
        local z
        e = argument1
        temporary = e
        captures[1].value = temporary
        branchCondition = e
        if branchCondition then
            resultValues = captures[2].value
            z = resultValues("Auto Fish", "Enabled, make sure you are near the Fishing Spot.", 5)
            z = captures[3].value
            resultValues = z.Heartbeat
            z = resultValues.Connect
            H = bindClosure(processBlockTales7815066, {captures[4], captures[5]})
            z = z(resultValues, H)
            captures[6].value = z
        else
            resultValues = captures[6].value
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[6].value
                H = resultValues.Disconnect
                H = H(resultValues)
                captures[6].value = nil
                H = captures[2].value
                W = H("Auto Fish", "Disabled.", 5)
            else
            end
            H = captures[5].value
            x = environment.Enum
            p = x.KeyCode
            d = p.Space
            x = environment.game
            W = H.SendKeyEvent
            W = W(H, false, d, false, x)
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales6740426 = function(captures)
        local argumentValues = {}
        local resultValues, temporary
        temporary = environment.wait
        resultValues = temporary(2)
        temporary = captures[1].value
        resultValues = temporary()
        temporary = environment.enableEnemyDropdownSystem
        resultValues = temporary()
        temporary = captures[2].value
        resultValues = temporary()
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales7736830 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H, W, e, resultValues, temporary, z
        e = argument1
        H = environment.type
        W = H(e)
        z = (W ~= "number")
        resultValues = z
        branchCondition = z
        if branchCondition then
        else
            z = (e < 0)
            resultValues = z
        end
        branchCondition = resultValues
        if branchCondition then
            resultValues = {"00:00"}
        else
            resultValues = environment.math
            temporary = resultValues.floor
            z = (e / 60)
            resultValues = temporary(z)
            z = resultValues
            resultValues = environment.math
            temporary = resultValues.floor
            H = (e % 60)
            resultValues = temporary(H)
            H = resultValues
            resultValues = environment.string
            temporary = resultValues.format
            resultValues = {temporary("%02d:%02d", z, H)}
            resultValues = {unpackValues(resultValues)}
        end
        return unpackValues(resultValues)
    end

    processBlockTales7815066 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H, W, c, e, resultValues, temporary, z
        W = environment.game
        H = W.Players
        z = H.LocalPlayer
        e = z.PlayerGui
        resultValues = e.HUD
        temporary = resultValues.Fishing
        e = temporary
        branchCondition = e
        resultValues = e
        if branchCondition then
            z = e.Visible
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            W = e.DOITNOW
            H = W.Meter
            z = H.Div
            resultValues = z.ImageColor3
            H = environment.Color3
            z = H.fromRGB
            H = z(255, 0, 0)
            temporary = (resultValues == H)
            branchCondition = temporary
            if branchCondition then
                resultValues = environment.task
                temporary = resultValues.wait
                z = captures[1].value
                resultValues = temporary(z)
                temporary = captures[2].value
                c = environment.Enum
                W = c.KeyCode
                resultValues = temporary.SendKeyEvent
                H = W.Space
                c = environment.game
                resultValues = resultValues(temporary, false, H, false, c)
                temporary = environment.print
                resultValues = temporary("Space released!")
            else
                temporary = captures[2].value
                c = environment.Enum
                W = c.KeyCode
                H = W.Space
                resultValues = temporary.SendKeyEvent
                c = environment.game
                resultValues = resultValues(temporary, true, H, false, c)
            end
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales7840511 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            z = bindClosure(processBlockTales13360673, {})
            resultValues = environment.table
            temporary = resultValues.sort
            e = captures[2].value
            resultValues = temporary(e, z)
            temporary = {}
            z = captures[2].value
            e = temporary
            resultValues = (# z)
            temporary = (resultValues == 0)
            branchCondition = temporary
            if branchCondition then
                resultValues = environment.table
                temporary = resultValues.insert
                resultValues = temporary(e, "- No Cards Found -")
            else
                temporary = environment.ipairs
                W = captures[2].value
                c = {temporary(W)}
                resultValues = c[1]
                z = c[2]
                H = c[3]
                W = resultValues
                while true do
                    local exitLoop1 = false
                    repeat
                        H, d = W(z, H)
                        branchCondition = H
                        if branchCondition then
                            p = environment.table
                            temporary = p.insert
                            x = d.DisplayName
                            p = temporary(e, x)
                            break
                        else
                        end
                        exitLoop1 = true
                        break
                    until true
                    if exitLoop1 then
                        break
                    end
                end
            end
            z = captures[1].value
            temporary = z.CurrentOption
            z = temporary
            W = z
            H = nil
            branchCondition = z
            if branchCondition then
                x = environment.type
                S = x(z)
                p = (S == "table")
                branchCondition = p
                c = p
                if branchCondition then
                    x = (# z)
                    p = (x > 0)
                    c = p
                else
                end
                W = c
            else
            end
            branchCondition = W
            if branchCondition then
                temporary = z[1]
                H = temporary
            else
            end
            d = (# e)
            W = false
            S = captures[1].value
            x = S.Options
            p = (# x)
            c = (d ~= p)
            branchCondition = c
            if branchCondition then
                W = true
            else
                p = (# e)
                x = p
                u = (1 < 0)
                p = 0
                while true do
                    local exitLoop2 = false
                    repeat
                        p = (p + 1)
                        d = (p <= x)
                        s = (not u)
                        d = (s and d)
                        s = (p >= x)
                        s = (u and s)
                        d = (s or d)
                        temporary = (d and 427940)
                        branchCondition = temporary
                        if branchCondition then
                            d = p
                            Q = e[d]
                            o = captures[1].value
                            Z = o.Options
                            i = Z[d]
                            s = (Q ~= i)
                            branchCondition = s
                            if branchCondition then
                                W = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop2 = true
                        break
                    until true
                    if exitLoop2 then
                        break
                    end
                end
            end
            branchCondition = W
            if branchCondition then
                d = captures[1].value
                p = d.Refresh
                p = p(d, e)
                d = captures[3].value
                p = d("CardTP", "Card Dropdown refreshed.")
            else
            end
            d = false
            S = captures[4].value
            p = S
            branchCondition = S
            if branchCondition then
                Q = captures[2].value
                u = (# Q)
                S = (u > 0)
                p = S
            else
            end
            branchCondition = p
            if branchCondition then
                p = environment.ipairs
                Q = captures[2].value
                i = {p(Q)}
                x = i[1]
                S = i[2]
                u = i[3]
                while true do
                    local exitLoop3 = false
                    repeat
                        u, Q = x(S, u)
                        branchCondition = u
                        if branchCondition then
                            Z = Q.DisplayName
                            o = captures[4].value
                            i = (Z == o)
                            branchCondition = i
                            if branchCondition then
                                Z = captures[4].value
                                i = (H ~= Z)
                                branchCondition = i
                                if branchCondition then
                                    i = captures[1].value
                                    Z = i.Set
                                    M = captures[4].value
                                    o = {M}
                                    Z = Z(i, o)
                                else
                                end
                                i = Q.Instance
                                captures[5].value = i
                                d = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop3 = true
                        break
                    until true
                    if exitLoop3 then
                        break
                    end
                end
            else
            end
            p = (not d)
            branchCondition = p
            if branchCondition then
                x = H
                branchCondition = H
                p = false
                if branchCondition then
                    o = (H ~= "- No Cards Found -")
                    u = o
                    branchCondition = o
                    if branchCondition then
                        o = (H ~= "Scanning Cards...")
                        u = o
                    else
                    end
                    x = u
                else
                end
                branchCondition = x
                if branchCondition then
                    x = environment.ipairs
                    o = captures[2].value
                    M = {x(o)}
                    S = M[1]
                    Q = M[3]
                    u = M[2]
                    while true do
                        local exitLoop4 = false
                        repeat
                            Q, o = S(u, Q)
                            branchCondition = Q
                            if branchCondition then
                                I = o.DisplayName
                                M = (I == H)
                                branchCondition = M
                                if branchCondition then
                                    p = true
                                    I = o.Instance
                                    captures[5].value = I
                                else
                                    break
                                end
                            else
                            end
                            exitLoop4 = true
                            break
                        until true
                        if exitLoop4 then
                            break
                        end
                    end
                else
                end
                x = (not p)
                branchCondition = x
                if branchCondition then
                    u = e[1]
                    x = (u or "- No Cards Found -")
                    Q = captures[2].value
                    u = (# Q)
                    S = (u > 0)
                    branchCondition = S
                    if branchCondition then
                        S = (H ~= x)
                        branchCondition = S
                        if branchCondition then
                            Q = {x}
                            S = captures[1].value
                            u = S.Set
                            u = u(S, Q)
                        else
                        end
                        S = (x ~= "- No Cards Found -")
                        branchCondition = S
                        if branchCondition then
                            o = captures[2].value
                            Q = o[1]
                            S = Q
                            branchCondition = Q
                            if branchCondition then
                                D = captures[2].value
                                o = D[1]
                                Q = o.Instance
                                S = Q
                            else
                            end
                            captures[5].value = S
                        else
                            captures[5].value = nil
                        end
                    else
                        D = (H ~= nil)
                        Q = D
                        branchCondition = D
                        if branchCondition then
                            D = (H ~= "- No Cards Found -")
                            Q = D
                        else
                        end
                        branchCondition = Q
                        if branchCondition then
                            Q = captures[1].value
                            D = {"- No Cards Found -"}
                            o = Q.Set
                            o = o(Q, D)
                        else
                        end
                        captures[5].value = nil
                    end
                else
                end
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processBlockTales9400209 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local H, e, resultValues, temporary, z
        e = argument1
        z = argument2
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales9403784 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local T
        local W
        local Z
        local c
        local d
        local e
        local g
        local i
        local k
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local w
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            z = captures[2].value
            H = z()
            e = (not H)
            resultValues = e
            branchCondition = e
            if branchCondition then
            else
                z = captures[3].value
                e = (not z)
                resultValues = e
            end
            branchCondition = resultValues
            if branchCondition then
                H = captures[4].value
                z = (# H)
                e = (z > 0)
                branchCondition = e
                resultValues = e
                if branchCondition then
                else
                    z = captures[5].value
                    e = (z > 0)
                    resultValues = e
                end
                branchCondition = resultValues
                if branchCondition then
                    temporary = {}
                    captures[4].value = temporary
                    captures[5].value = 0
                    e = captures[6].value
                    branchCondition = e
                    if branchCondition then
                        e = captures[6].value
                        z = e()
                    else
                    end
                else
                end
                resultValues = {}
            else
                e = captures[7].value
                W = {"Geometry", "BadgeStand"}
                H = captures[3].value
                z = e(H, W)
                e = captures[7].value
                W = captures[3].value
                c = {"Geometry"}
                H = e(W, c)
                branchCondition = z
                e = {}
                W = {}
                c = {}
                W.value = e
                e = {}
                c.value = e
                e = bindClosure(processBlockTales4040501, {c, W})
                if branchCondition then
                    d = environment.ipairs
                    s = z.GetChildren
                    u = {s(z)}
                    s = {d(unpackValues(u))}
                    S = s[3]
                    p = s[1]
                    x = s[2]
                    while true do
                        local exitLoop1 = false
                        repeat
                            S, u = p(x, S)
                            branchCondition = S
                            if branchCondition then
                                s = e(u)
                                break
                            else
                            end
                            exitLoop1 = true
                            break
                        until true
                        if exitLoop1 then
                            break
                        end
                    end
                else
                end
                branchCondition = H
                if branchCondition then
                    d = environment.ipairs
                    s = H.GetChildren
                    u = {s(H)}
                    s = {d(unpackValues(u))}
                    S = s[3]
                    x = s[2]
                    p = s[1]
                    while true do
                        local exitLoop2 = false
                        repeat
                            S, u = p(x, S)
                            branchCondition = S
                            if branchCondition then
                                Z = u.Name
                                i = (Z == "Badge")
                                s = i
                                branchCondition = i
                                if branchCondition then
                                    Z = u.Parent
                                    i = (Z == H)
                                    s = i
                                else
                                end
                                branchCondition = s
                                if branchCondition then
                                    s = e(u)
                                else
                                end
                                break
                            else
                            end
                            exitLoop2 = true
                            break
                        until true
                        if exitLoop2 then
                            break
                        end
                    end
                else
                end
                u = W.value
                S = (# u)
                x = (S > 0)
                d = x
                branchCondition = x
                if branchCondition then
                    u = W.value
                    S = (# u)
                    u = captures[5].value
                    x = (S > u)
                    d = x
                else
                end
                branchCondition = d
                if branchCondition then
                    d = captures[8].value
                    Q = W.value
                    s = (# Q)
                    i = captures[3].value
                    Q = i.Name
                    u = ("%d Card(s) found in %s!").format
                    u = u("%d Card(s) found in %s!", s, Q)
                    p = d("Collectible Alert", u, 4)
                else
                end
                p = W.value
                d = (# p)
                captures[5].value = d
                p = false
                u = W.value
                S = (# u)
                s = captures[4].value
                u = (# s)
                x = (S ~= u)
                branchCondition = x
                if branchCondition then
                    p = true
                else
                    u = environment.table
                    Q = bindClosure(processBlockTales9400209, {})
                    S = u.sort
                    s = W.value
                    u = S(s, Q)
                    S = {}
                    u = environment.ipairs
                    Z = captures[4].value
                    o = {u(Z)}
                    Q = o[2]
                    i = o[3]
                    s = o[1]
                    while true do
                        local exitLoop3 = false
                        repeat
                            i, Z = s(Q, i)
                            branchCondition = i
                            if branchCondition then
                                M = environment.table
                                o = M.insert
                                M = o(S, Z)
                                break
                            else
                            end
                            exitLoop3 = true
                            break
                        until true
                        if exitLoop3 then
                            break
                        end
                    end
                    s = environment.table
                    u = s.sort
                    Q = bindClosure(processBlockTales13557402, {})
                    s = u(S, Q)
                    Q = W.value
                    s = (# Q)
                    Q = s
                    Z = (1 < 0)
                    s = 0
                    while true do
                        local exitLoop4 = false
                        repeat
                            s = (s + 1)
                            u = (s <= Q)
                            o = (not Z)
                            u = (o and u)
                            o = (s >= Q)
                            o = (Z and o)
                            u = (o or u)
                            temporary = (u and 2766478)
                            branchCondition = temporary
                            if branchCondition then
                                u = s
                                D = S[u]
                                I = (not D)
                                branchCondition = I
                                o = I
                                if branchCondition then
                                else
                                    g = W.value
                                    k = g[u]
                                    T = k.Instance
                                    g = S[u]
                                    k = g.Instance
                                    w = (T ~= k)
                                    I = w
                                    branchCondition = w
                                    if branchCondition then
                                    else
                                        g = W.value
                                        k = g[u]
                                        T = k.DisplayName
                                        g = S[u]
                                        k = g.DisplayName
                                        w = (T ~= k)
                                        I = w
                                    end
                                    o = I
                                end
                                branchCondition = o
                                if branchCondition then
                                    p = true
                                else
                                    break
                                end
                            else
                            end
                            exitLoop4 = true
                            break
                        until true
                        if exitLoop4 then
                            break
                        end
                    end
                end
                branchCondition = p
                if branchCondition then
                    S = W.value
                    captures[4].value = S
                    u = captures[6].value
                    branchCondition = u
                    if branchCondition then
                        u = captures[6].value
                        s = u()
                    else
                    end
                else
                end
                resultValues = {}
            end
        end
        return unpackValues(resultValues)
    end


    -- === Tex / Auto Guard ===

    exclamationActionToggleV121 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            resultValues = temporary("Warning", "You must enable the card Training Wheels in order for auto guard to work!", 6.5)
            temporary = captures[2].value
            resultValues = temporary()
        else
            temporary = captures[3].value
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoGuard10035586 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local x
        local z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            c = environment.tostring
            p = captures[3].value
            d = {c(p)}
            c = ("Action ENABLED. Delay: %s s.").format
            W = {c("Action ENABLED. Delay: %s s.", unpackValues(d))}
            e = resultValues("Auto Guard", unpackValues(W))
            resultValues = captures[4].value
            e = resultValues.FindFirstChild
            e = e(resultValues, "Terrain")
            resultValues = (not e)
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[4].value
                z = resultValues.WaitForChild
                z = z(resultValues, "Terrain", 10)
                e = z
                resultValues = (not e)
                branchCondition = resultValues
                if branchCondition then
                    resultValues = captures[5].value
                    H = resultValues("Excla", "Workspace.Terrain not found.")
                    captures[1].value = false
                    c = captures[6].value
                    branchCondition = c
                    H = c
                    if branchCondition then
                        x = captures[6].value
                        p = x.Toggles
                        c = p
                        branchCondition = p
                        if branchCondition then
                            S = captures[6].value
                            x = S.Toggles
                            p = x.ExclamationActionToggle
                            c = p
                        else
                        end
                        H = c
                    else
                    end
                    branchCondition = H
                    if branchCondition then
                        c = captures[6].value
                        W = c.Toggles
                        H = W.ExclamationActionToggle
                        W = H.Set
                        W = W(H, false)
                    else
                    end
                    resultValues = {}
                else
                    H = captures[2].value
                    W = H("Auto Guard", "Initial scan...")
                    x = e.GetDescendants
                    H = environment.ipairs
                    p = {x(e)}
                    x = {H(unpackValues(p))}
                    d = x[3]
                    c = x[2]
                    W = x[1]
                    while true do
                        local exitLoop1 = false
                        repeat
                            d, p = W(c, d)
                            branchCondition = d
                            if branchCondition then
                                x = captures[7].value
                                S = x(p)
                                break
                            else
                            end
                            exitLoop1 = true
                            break
                        until true
                        if exitLoop1 then
                            break
                        end
                    end
                    H = captures[2].value
                    W = H("Auto Guard", "Initial scan complete.")
                    c = captures[8].value
                    H = c
                    branchCondition = c
                    if branchCondition then
                        d = captures[8].value
                        c = d.Connected
                        H = c
                    else
                    end
                    branchCondition = H
                    if branchCondition then
                        H = captures[8].value
                        W = H.Disconnect
                        W = W(H)
                    else
                    end
                    H = e.DescendantAdded
                    W = H.Connect
                    c = captures[7].value
                    W = W(H, c)
                    captures[8].value = W
                    H = captures[2].value
                    c = H("Auto Guard", "Connected Terrain.DescendantAdded.")
                    p = captures[9].value
                    c = p
                    branchCondition = p
                    if branchCondition then
                        x = captures[9].value
                        p = x.Connected
                        c = p
                    else
                    end
                    H = (not c)
                    branchCondition = H
                    if branchCondition then
                        c = captures[10].value
                        H = c.Heartbeat
                        d = bindClosure(processBlockTales3339382, {captures[11]})
                        c = H.Connect
                        c = c(H, d)
                        captures[9].value = c
                    else
                    end
                    resultValues = {}
                end
            else
                H = captures[2].value
                W = H("Auto Guard", "Initial scan...")
                x = e.GetDescendants
                H = environment.ipairs
                p = {x(e)}
                x = {H(unpackValues(p))}
                d = x[3]
                c = x[2]
                W = x[1]
                while true do
                    local exitLoop2 = false
                    repeat
                        d, p = W(c, d)
                        branchCondition = d
                        if branchCondition then
                            x = captures[7].value
                            S = x(p)
                            break
                        else
                        end
                        exitLoop2 = true
                        break
                    until true
                    if exitLoop2 then
                        break
                    end
                end
                H = captures[2].value
                W = H("Auto Guard", "Initial scan complete.")
                c = captures[8].value
                H = c
                branchCondition = c
                if branchCondition then
                    d = captures[8].value
                    c = d.Connected
                    H = c
                else
                end
                branchCondition = H
                if branchCondition then
                    H = captures[8].value
                    W = H.Disconnect
                    W = W(H)
                else
                end
                H = e.DescendantAdded
                W = H.Connect
                c = captures[7].value
                W = W(H, c)
                captures[8].value = W
                H = captures[2].value
                c = H("Auto Guard", "Connected Terrain.DescendantAdded.")
                p = captures[9].value
                c = p
                branchCondition = p
                if branchCondition then
                    x = captures[9].value
                    p = x.Connected
                    c = p
                else
                end
                H = (not c)
                branchCondition = H
                if branchCondition then
                    c = captures[10].value
                    H = c.Heartbeat
                    d = bindClosure(processBlockTales3339382, {captures[11]})
                    c = H.Connect
                    c = c(H, d)
                    captures[9].value = c
                else
                end
                resultValues = {}
            end
        end
        return unpackValues(resultValues)
    end

    processAutoGuard16187736 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local H, W, e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("Auto Guard", "Action DISABLED.")
            z = captures[3].value
            branchCondition = z
            resultValues = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[3].value
                e = resultValues.Disconnect
                e = e(resultValues)
                captures[3].value = nil
            else
            end
            H = captures[4].value
            e = H
            branchCondition = H
            if branchCondition then
                W = captures[4].value
                H = W.Connected
                e = H
            else
            end
            branchCondition = e
            if branchCondition then
                e = captures[4].value
                z = e.Disconnect
                z = z(e)
                captures[4].value = nil
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processAutoGuard5195988 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H
        local Q
        local W
        local c
        local d
        local e
        local i
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        e = argument1
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            resultValues = e
            branchCondition = e
            if branchCondition then
                c = e.Parent
                branchCondition = c
                H = c
                if branchCondition then
                    c = e.FindFirstChild
                    c = c(e, "exclamation")
                    H = c
                else
                end
                resultValues = H
            else
            end
            temporary = (not resultValues)
            branchCondition = temporary
            if branchCondition then
                temporary = captures[2].value
                temporary[e] = nil
                resultValues = {}
            else
                z = captures[2].value
                resultValues = z[e]
                temporary = (resultValues == true)
                branchCondition = temporary
                if branchCondition then
                    resultValues = {}
                else
                    temporary = captures[2].value
                    c = e.GetFullName
                    temporary[e] = "pending_action"
                    temporary = captures[3].value
                    c = c(e)
                    d = captures[4].value
                    p = ("Found: %s. Delay: %.2fs...").format
                    W = {p("Found: %s. Delay: %.2fs...", c, d)}
                    resultValues = temporary("Auto Guard", unpackValues(W))
                    temporary = environment.pcall
                    H = environment.task
                    z = H.wait
                    H = captures[4].value
                    resultValues = temporary(z, H)
                    z = resultValues
                    temporary = (not z)
                    branchCondition = temporary
                    if branchCondition then
                        temporary = captures[5].value
                        resultValues = temporary("Auto Guard", "task.wait errored")
                    else
                    end
                    resultValues = captures[1].value
                    temporary = (not resultValues)
                    branchCondition = temporary
                    if branchCondition then
                        temporary = captures[2].value
                        temporary[e] = nil
                        resultValues = {}
                    else
                        resultValues = e
                        branchCondition = e
                        if branchCondition then
                            d = e.Parent
                            W = d
                            branchCondition = d
                            if branchCondition then
                                d = e.FindFirstChild
                                d = d(e, "exclamation")
                                W = d
                            else
                            end
                            resultValues = W
                        else
                        end
                        temporary = (not resultValues)
                        branchCondition = temporary
                        if branchCondition then
                            temporary = captures[3].value
                            resultValues = temporary("Auto Guard", "Attachment invalid post-delay for:", e)
                            temporary = captures[2].value
                            temporary[e] = nil
                            resultValues = {}
                        else
                            temporary = captures[3].value
                            p = e.GetFullName
                            d = {p(e)}
                            p = ("Delay done. Pressing Space for: %s").format
                            c = {p("Delay done. Pressing Space for: %s", unpackValues(d))}
                            resultValues = temporary("Auto Guard", unpackValues(c))
                            W = bindClosure(processBlockTales9640682, {captures[6]})
                            temporary = environment.pcall
                            c = {temporary(W)}
                            resultValues = c[1]
                            H = c[2]
                            W = resultValues
                            resultValues = environment.task
                            temporary = resultValues.wait
                            resultValues = temporary(0.05)
                            d = bindClosure(processBlockTales7740160, {captures[6]})
                            temporary = environment.pcall
                            p = {temporary(d)}
                            c = p[2]
                            resultValues = p[1]
                            branchCondition = W
                            d = resultValues
                            resultValues = W
                            if branchCondition then
                                resultValues = d
                            else
                            end
                            branchCondition = resultValues
                            if branchCondition then
                                temporary = captures[7].value
                                i = e.Parent
                                Q = i.Name
                                u = (Q or "object")
                                x = ("Space pressed for " .. u)
                                resultValues = temporary("Auto Guard", x, 3)
                                resultValues = captures[2].value
                                resultValues[e] = true
                            else
                                resultValues = captures[7].value
                                p = resultValues("Auto Guard Action Error", "Failed space press.", 4)
                                resultValues = captures[5].value
                                p = resultValues("Auto Guard", "Key press/release error. PressErr:", H, "ReleaseErr:", c)
                                resultValues = captures[2].value
                                resultValues[e] = nil
                            end
                            resultValues = {}
                        end
                    end
                end
            end
        end
        return unpackValues(resultValues)
    end

    processBlockTales3339382 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local x
        local z
        e = environment.tick
        z = e()
        resultValues = (z % 300)
        temporary = (resultValues == 0)
        branchCondition = temporary
        if branchCondition then
            temporary = {}
            e = temporary
            temporary = environment.pairs
            W = captures[1].value
            c = {temporary(W)}
            z = c[2]
            resultValues = c[1]
            H = c[3]
            W = resultValues
            while true do
                local exitLoop1 = false
                repeat
                    H, d = W(z, H)
                    branchCondition = H
                    if branchCondition then
                        c = H
                        p = c
                        branchCondition = c
                        if branchCondition then
                            x = c.Parent
                            p = x
                        else
                        end
                        branchCondition = p
                        if branchCondition then
                            temporary = d
                            e[c] = temporary
                        else
                        end
                        break
                    else
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
            temporary = e
            captures[1].value = temporary
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales7740160 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        resultValues = temporary.SendKeyEvent
        H = W.KeyCode
        z = H.Space
        W = environment.game
        resultValues = resultValues(temporary, false, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales9640682 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        z = H.Space
        W = environment.game
        resultValues = temporary.SendKeyEvent
        resultValues = resultValues(temporary, true, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    setExclamationActionDelayV1_2_1 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local e, resultValues, temporary
        e = argument1
        temporary = e
        resultValues = {}
        captures[1].value = temporary
        return unpackValues(resultValues)
    end


    -- === Tex / Auto Sword ===

    processAutoSword5439771 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local H
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            temporary = captures[2].value
            branchCondition = temporary
            if branchCondition then
                temporary = captures[3].value
                resultValues = temporary()
            else
            end
            resultValues = {}
            captures[4].value = false
        else
            resultValues = captures[5].value
            e = resultValues.FindFirstChild
            e = e(resultValues, "PlayerGui")
            resultValues = (not e)
            branchCondition = resultValues
            if branchCondition then
                resultValues = {}
            else
                resultValues = captures[6].value
                H = {"HUD", "Battle", "DOITNOW"}
                z = resultValues(e, H)
                resultValues = captures[6].value
                W = {"HUD", "Battle", "DOITNOW", "Meter", "Div"}
                H = resultValues(e, W)
                W = z
                branchCondition = z
                if branchCondition then
                    x = z.IsA
                    x = x(z, "Frame")
                    branchCondition = x
                    d = x
                    if branchCondition then
                        x = H
                        branchCondition = H
                        if branchCondition then
                            u = H.IsA
                            u = u(H, "ImageLabel")
                            x = u
                        else
                        end
                        d = x
                    else
                    end
                    W = d
                else
                end
                resultValues = (not W)
                branchCondition = resultValues
                if branchCondition then
                    resultValues = captures[2].value
                    branchCondition = resultValues
                    if branchCondition then
                        resultValues = captures[3].value
                        W = resultValues()
                    else
                    end
                    captures[4].value = false
                    resultValues = {}
                else
                    W = z.Visible
                    branchCondition = W
                    if branchCondition then
                        p = captures[2].value
                        d = (not p)
                        branchCondition = d
                        W = d
                        if branchCondition then
                            p = captures[4].value
                            d = (not p)
                            W = d
                        else
                        end
                        branchCondition = W
                        if branchCondition then
                            W = captures[7].value
                            c = W()
                        else
                        end
                        d = captures[2].value
                        W = d
                        branchCondition = d
                        if branchCondition then
                            p = captures[4].value
                            d = (not p)
                            W = d
                        else
                        end
                        branchCondition = W
                        if branchCondition then
                            c = H.ImageColor3
                            d = captures[8].value
                            W = (c == d)
                            branchCondition = W
                            if branchCondition then
                                W = captures[9].value
                                c = W("AutoSword", "MeterDiv turned RED. Starting release delay timer.")
                                captures[4].value = true
                                c = environment.tick
                                d = c()
                                captures[10].value = d
                            else
                            end
                        else
                        end
                        c = captures[4].value
                        branchCondition = c
                        if branchCondition then
                            x = environment.tick
                            S = x()
                            x = captures[10].value
                            p = (S - x)
                            x = captures[11].value
                            c = (p >= x)
                            branchCondition = c
                            if branchCondition then
                                c = captures[2].value
                                branchCondition = c
                                if branchCondition then
                                    c = captures[3].value
                                    p = c()
                                    c = captures[12].value
                                    p = c("Auto Sword", "Action Complete.", 3)
                                else
                                end
                                captures[4].value = false
                            else
                            end
                        else
                        end
                    else
                        p = captures[2].value
                        branchCondition = p
                        if branchCondition then
                            p = captures[3].value
                            x = p()
                        else
                        end
                        captures[4].value = false
                    end
                    resultValues = {}
                end
            end
        end
        return unpackValues(resultValues)
    end

    processAutoSword653716 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H
        local S
        local W
        local c
        local d
        local p
        local resultValues
        local temporary
        local x
        local z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            captures[2].value = false
            captures[3].value = 0
            z = captures[4].value
            p = environment.tostring
            S = captures[5].value
            x = {p(S)}
            p = ("ENABLED. Release Delay: %s s.").format
            d = {p("ENABLED. Release Delay: %s s.", unpackValues(x))}
            H = z("AutoSword", unpackValues(d))
            W = captures[6].value
            z = W
            branchCondition = W
            if branchCondition then
                c = captures[6].value
                W = c.Connected
                z = W
            else
            end
            branchCondition = z
            if branchCondition then
                z = captures[6].value
                H = z.Disconnect
                H = H(z)
            else
            end
            H = captures[7].value
            resultValues = {}
            z = H.Heartbeat
            W = captures[8].value
            H = z.Connect
            H = H(z, W)
            captures[6].value = H
            z = captures[4].value
            W = z("AutoSword", "Update loop started.")
        end
        return unpackValues(resultValues)
    end

    processAutoSword7416568 = function(captures)
        local argumentValues = {}
        local branchCondition
        local e, resultValues, temporary
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            temporary = captures[2].value
            resultValues = temporary("AutoSword", "Action: Releasing Spacebar.")
            e = bindClosure(processBlockTales6667748, {captures[3]})
            temporary = environment.pcall
            resultValues = temporary(e)
            captures[1].value = false
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processAutoSword7559693 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local e, resultValues, temporary
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            temporary = captures[2].value
            resultValues = temporary("AutoSword", "Action: Pressing Spacebar.")
            e = bindClosure(processBlockTales5934225, {captures[3]})
            temporary = environment.pcall
            resultValues = temporary(e)
            resultValues = {}
            captures[1].value = true
        end
        return unpackValues(resultValues)
    end

    processAutoSword7693214 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local H, e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("AutoSword", "DISABLED.")
            z = captures[3].value
            resultValues = z
            branchCondition = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[3].value
                e = resultValues.Disconnect
                e = e(resultValues)
                captures[3].value = nil
            else
            end
            e = captures[4].value
            branchCondition = e
            if branchCondition then
                e = captures[5].value
                z = e()
            else
            end
            resultValues = {}
            captures[6].value = false
        end
        return unpackValues(resultValues)
    end

    processBlockTales5934225 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        z = H.Space
        W = environment.game
        resultValues = temporary.SendKeyEvent
        resultValues = resultValues(temporary, true, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales6667748 = function(captures)
        local argumentValues = {}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        z = H.Space
        W = environment.game
        resultValues = temporary.SendKeyEvent
        resultValues = resultValues(temporary, false, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    setAutoSwordEnabled = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            resultValues = temporary()
        else
            temporary = captures[2].value
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    setAutoSwordReleaseDelay = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local e, resultValues, temporary
        e = argument1
        temporary = e
        captures[1].value = temporary
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Auto Launcher ===

    processAutoLauncher11160503 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local H
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            e = captures[2].value
            resultValues = e
            branchCondition = e
            if branchCondition then
                W = captures[2].value
                H = W.Parent
                branchCondition = H
                e = H
                if branchCondition then
                    c = captures[3].value
                    H = c
                    branchCondition = c
                    if branchCondition then
                        d = captures[3].value
                        c = d.Parent
                        H = c
                    else
                    end
                    e = H
                else
                end
                resultValues = e
            else
            end
            branchCondition = resultValues
            if branchCondition then
                e = captures[2].value
                resultValues = e.Position
                temporary = resultValues.X
                z = captures[3].value
                resultValues = z.Position
                e = temporary
                temporary = resultValues.X
                z = temporary
                H = environment.math
                resultValues = H.abs
                W = (e - z)
                H = resultValues(W)
                resultValues = captures[4].value
                temporary = (H < resultValues)
                branchCondition = temporary
                if branchCondition then
                    resultValues = captures[5].value
                    temporary = (not resultValues)
                    branchCondition = temporary
                    if branchCondition then
                        captures[5].value = true
                        resultValues = captures[6].value
                        p = ("Reticle (X:%.2f) and Target (X:%.2f) ALIGNED! Firing...").format
                        d = {p("Reticle (X:%.2f) and Target (X:%.2f) ALIGNED! Firing...", e, z)}
                        H = resultValues("AutoLauncher", unpackValues(d))
                        H = environment.task
                        resultValues = H.spawn
                        W = bindClosure(processBlockTales14453497, {captures[1], captures[5], captures[7], captures[8], captures[9]})
                        H = resultValues(W)
                    else
                    end
                else
                    captures[5].value = false
                end
            else
                captures[5].value = false
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processAutoLauncher11796690 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H, W, e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            e = resultValues("AutoLauncher", "Feature ENABLED.")
            captures[3].value = false
            e = captures[4].value
            z = e()
            H = captures[5].value
            e = H
            branchCondition = H
            if branchCondition then
                W = captures[5].value
                H = W.Connected
                e = H
            else
            end
            branchCondition = e
            if branchCondition then
                e = captures[5].value
                z = e.Disconnect
                z = z(e)
            else
            end
            resultValues = {}
            z = captures[6].value
            e = z.Heartbeat
            H = captures[7].value
            z = e.Connect
            z = z(e, H)
            captures[5].value = z
            e = captures[2].value
            H = e("AutoLauncher", "Alignment check loop started.")
        end
        return unpackValues(resultValues)
    end

    processAutoLauncher16687945 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        temporary = captures[1].value
        resultValues = temporary("AutoLauncher", "Initializing part monitoring...")
        temporary = captures[2].value
        e = captures[3].value
        resultValues = temporary.FindFirstChild
        resultValues = resultValues(temporary, e)
        captures[4].value = resultValues
        z = captures[4].value
        branchCondition = z
        e = z
        if branchCondition then
            z = captures[4].value
            H = z.IsA
            H = H(z, "Folder")
            e = H
        else
        end
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            c = captures[4].value
            p = c.GetFullName
            d = {p(c)}
            c = ("BattleDump folder found: %s. Setting up listeners.").format
            W = {c("BattleDump folder found: %s. Setting up listeners.", unpackValues(d))}
            e = temporary("AutoLauncher", unpackValues(W))
            temporary = captures[4].value
            e = temporary.FindFirstChild
            z = captures[5].value
            e = e(temporary, z)
            captures[6].value = e
            temporary = captures[4].value
            H = captures[7].value
            z = temporary.FindFirstChild
            z = z(temporary, H)
            captures[8].value = z
            temporary = captures[6].value
            branchCondition = temporary
            if branchCondition then
                temporary = captures[1].value
                d = captures[6].value
                x = d.GetFullName
                p = {x(d)}
                H = temporary("AutoLauncher", "Initial Reticle found:", unpackValues(p))
            else
            end
            temporary = captures[8].value
            branchCondition = temporary
            if branchCondition then
                temporary = captures[1].value
                d = captures[8].value
                x = d.GetFullName
                p = {x(d)}
                H = temporary("AutoLauncher", "Initial Target found:", unpackValues(p))
            else
            end
            W = captures[9].value
            branchCondition = W
            H = W
            if branchCondition then
                c = captures[9].value
                W = c.Connected
                H = W
            else
            end
            branchCondition = H
            if branchCondition then
                temporary = captures[9].value
                H = temporary.Disconnect
                H = H(temporary)
            else
            end
            H = captures[4].value
            temporary = H.ChildAdded
            W = captures[10].value
            H = temporary.Connect
            H = H(temporary, W)
            captures[9].value = H
            c = captures[11].value
            branchCondition = c
            W = c
            if branchCondition then
                d = captures[11].value
                c = d.Connected
                W = c
            else
            end
            branchCondition = W
            if branchCondition then
                temporary = captures[11].value
                W = temporary.Disconnect
                W = W(temporary)
            else
            end
            W = captures[4].value
            temporary = W.ChildRemoved
            c = captures[12].value
            W = temporary.Connect
            W = W(temporary, c)
            captures[11].value = W
        else
            temporary = captures[13].value
            S = captures[3].value
            u = ("BattleDump folder ('%s') not found for launcher parts.").format
            x = {u("BattleDump folder ('%s') not found for launcher parts.", S)}
            c = temporary("AutoLauncher", unpackValues(x))
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoLauncher3731268 = function(captures)
        local argumentValues = {}
        local e, resultValues, temporary
        temporary = captures[1].value
        resultValues = temporary("AutoLauncher", "Action: Pressing Spacebar.")
        temporary = environment.pcall
        e = bindClosure(processBlockTales5544236, {captures[2]})
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoLauncher5009002 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local branchCondition
        local H, W, c, d, e, resultValues, temporary, z
        e = argument1
        temporary = e.IsA
        temporary = temporary(e, "Part")
        branchCondition = temporary
        if branchCondition then
            resultValues = e.Name
            z = captures[1].value
            temporary = (resultValues == z)
            branchCondition = temporary
            if branchCondition then
                temporary = captures[2].value
                c = e.GetFullName
                W = {c(e)}
                resultValues = temporary("AutoLauncher", "Reticle part detected:", unpackValues(W))
                temporary = e
                captures[3].value = temporary
            else
                z = e.Name
                H = captures[4].value
                resultValues = (z == H)
                branchCondition = resultValues
                if branchCondition then
                    resultValues = captures[2].value
                    d = e.GetFullName
                    c = {d(e)}
                    z = resultValues("AutoLauncher", "Target part detected:", unpackValues(c))
                    resultValues = e
                    captures[5].value = resultValues
                else
                end
            end
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoLauncher608200 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local H
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("AutoLauncher", "Feature DISABLED.")
            z = captures[3].value
            resultValues = z
            branchCondition = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[3].value
                e = resultValues.Disconnect
                e = e(resultValues)
                captures[3].value = nil
            else
            end
            H = captures[4].value
            e = H
            branchCondition = H
            if branchCondition then
                W = captures[4].value
                H = W.Connected
                e = H
            else
            end
            branchCondition = e
            if branchCondition then
                e = captures[4].value
                z = e.Disconnect
                z = z(e)
                captures[4].value = nil
            else
            end
            W = captures[5].value
            z = W
            branchCondition = W
            if branchCondition then
                c = captures[5].value
                W = c.Connected
                z = W
            else
            end
            branchCondition = z
            if branchCondition then
                z = captures[5].value
                H = z.Disconnect
                H = H(z)
                captures[5].value = nil
            else
            end
            H = captures[6].value
            branchCondition = H
            if branchCondition then
                H = captures[7].value
                W = H()
                captures[6].value = false
            else
            end
            resultValues = {}
            captures[8].value = nil
            captures[9].value = nil
            d = captures[2].value
            p = d("AutoLauncher", "Monitoring stopped and state cleared.")
        end
        return unpackValues(resultValues)
    end

    processAutoLauncher899218 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local e, resultValues, temporary
        temporary = captures[1].value
        resultValues = temporary("AutoLauncher", "Action: Releasing Spacebar.")
        e = bindClosure(processBlockTales4825171, {captures[2]})
        temporary = environment.pcall
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoLauncher9571879 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local H, e, resultValues, temporary, z
        e = argument1
        resultValues = captures[1].value
        temporary = (e == resultValues)
        branchCondition = temporary
        if branchCondition then
            temporary = captures[2].value
            resultValues = temporary("AutoLauncher", "Reticle part removed.")
            captures[1].value = nil
            captures[3].value = false
        else
            H = captures[4].value
            z = (e == H)
            branchCondition = z
            if branchCondition then
                z = captures[2].value
                H = z("AutoLauncher", "Target part removed.")
                captures[4].value = nil
                captures[3].value = false
            else
            end
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales14453497 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local e, resultValues, temporary
        e = captures[1].value
        resultValues = e
        branchCondition = e
        if branchCondition then
            e = captures[2].value
            resultValues = e
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[3].value
            resultValues = temporary()
            resultValues = environment.task
            temporary = resultValues.wait
            resultValues = temporary(0.05)
            temporary = captures[4].value
            resultValues = temporary()
            temporary = captures[5].value
            resultValues = temporary("Auto Launcher", "Fired!", 2)
        else
            resultValues = captures[1].value
            temporary = (not resultValues)
            branchCondition = temporary
            if branchCondition then
                captures[2].value = false
            else
            end
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales4825171 = function(captures)
        local argumentValues = {}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        resultValues = temporary.SendKeyEvent
        H = W.KeyCode
        z = H.Space
        W = environment.game
        resultValues = resultValues(temporary, false, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales5544236 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        z = H.Space
        resultValues = temporary.SendKeyEvent
        W = environment.game
        resultValues = resultValues(temporary, true, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    setAutoLauncherEnabled = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            resultValues = temporary()
        else
            temporary = captures[2].value
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Auto Dynamite ===

    processAutoDynamite15368223 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H, e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            e = resultValues("AutoDynamite", "Feature ENABLED.")
            z = captures[3].value
            branchCondition = z
            resultValues = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[3].value
                e = resultValues.Disconnect
                e = e(resultValues)
            else
            end
            e = captures[4].value
            resultValues = e.Heartbeat
            z = captures[5].value
            e = resultValues.Connect
            e = e(resultValues, z)
            captures[3].value = e
            resultValues = captures[2].value
            z = resultValues("AutoDynamite", "Update loop started.")
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processAutoDynamite5778904 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H, e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("AutoDynamite", "Feature DISABLED.")
            z = captures[3].value
            resultValues = z
            branchCondition = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[3].value
                e = resultValues.Disconnect
                e = e(resultValues)
                captures[3].value = nil
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    setAutoDynamiteEnabled = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            resultValues = temporary()
        else
            temporary = captures[2].value
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Auto Superball ===

    processAutoSuperball128144 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local e, resultValues, temporary
        temporary = captures[1].value
        resultValues = temporary("AutoSuperball", "Action: Pressing Spacebar.")
        e = bindClosure(processBlockTales10648731, {captures[2]})
        temporary = environment.pcall
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoSuperball14525217 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local H
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local z
        resultValues = environment.task
        temporary = resultValues.wait
        e = captures[1].value
        resultValues = temporary(e)
        temporary = captures[2].value
        branchCondition = temporary
        if branchCondition then
            temporary = captures[3].value
            resultValues = temporary()
            resultValues = environment.task
            temporary = resultValues.wait
            resultValues = temporary(0.1)
            temporary = captures[4].value
            resultValues = temporary()
            temporary = captures[5].value
            resultValues = temporary("Auto Superball", "Superball Action triggered!", 3)
            temporary = captures[6].value
            resultValues = temporary("AutoSuperball", "Superball action complete. Checking to trigger Linebounce...")
            temporary = captures[6].value
            W = environment.tostring
            d = environment.linebounce_isActive
            c = W(d)
            W = environment.typeof
            p = environment.triggerLinebounce_G
            d = {W(p)}
            W = ("linebounce_isActive: %s, typeof(triggerLinebounce_G): %s").format
            H = {W("linebounce_isActive: %s, typeof(triggerLinebounce_G): %s", c, unpackValues(d))}
            resultValues = temporary("AutoSuperball", unpackValues(H))
            e = environment.linebounce_isActive
            branchCondition = e
            resultValues = e
            if branchCondition then
                z = environment.typeof
                W = environment.triggerLinebounce_G
                H = z(W)
                e = (H == "function")
                resultValues = e
            else
            end
            branchCondition = resultValues
            if branchCondition then
                temporary = captures[6].value
                resultValues = temporary("AutoSuperball", "Conditions met, calling triggerLinebounce_G().")
                temporary = environment.triggerLinebounce_G
                resultValues = temporary()
            else
                resultValues = environment.linebounce_isActive
                temporary = (not resultValues)
                branchCondition = temporary
                if branchCondition then
                    temporary = captures[6].value
                    resultValues = temporary("AutoSuperball", "Linebounce not triggered: linebounce_isActive is false.")
                else
                end
                resultValues = environment.typeof
                z = environment.triggerLinebounce_G
                e = resultValues(z)
                temporary = (e ~= "function")
                branchCondition = temporary
                if branchCondition then
                    temporary = captures[6].value
                    resultValues = temporary("AutoSuperball", "Linebounce not triggered: triggerLinebounce_G is not a function.")
                else
                end
            end
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoSuperball15900876 = function(captures, argument1)
        local argumentValues = {argument1}
        local e, resultValues, temporary
        temporary = captures[1].value
        resultValues = temporary("AutoSuperball", "Action: Releasing Spacebar.")
        e = bindClosure(processBlockTales16476862, {captures[2]})
        temporary = environment.pcall
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoSuperball3201318 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local H, e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("AutoSuperball", "Feature DISABLED.")
            z = captures[3].value
            branchCondition = z
            resultValues = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[3].value
                e = resultValues.Disconnect
                e = e(resultValues)
                captures[3].value = nil
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processAutoSuperball5609324 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local H
        local Q
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            z = captures[2].value
            e = (not z)
            resultValues = e
            branchCondition = e
            if branchCondition then
            else
                H = captures[2].value
                z = H.Parent
                e = (not z)
                resultValues = e
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = {}
            else
                z = captures[3].value
                e = (not z)
                resultValues = e
                branchCondition = e
                if branchCondition then
                else
                    H = captures[3].value
                    z = H.Parent
                    e = (not z)
                    resultValues = e
                end
                branchCondition = resultValues
                if branchCondition then
                    resultValues = {}
                else
                    e = nil
                    temporary = captures[2].value
                    z = temporary
                    temporary = z.GetAttribute
                    temporary = temporary(z, "FPos")
                    H = temporary
                    resultValues = H
                    branchCondition = H
                    if branchCondition then
                        c = environment.typeof
                        d = c(H)
                        W = (d == "Vector3")
                        resultValues = W
                    else
                    end
                    branchCondition = resultValues
                    if branchCondition then
                        temporary = H
                        e = temporary
                    else
                        resultValues = z.FindFirstChild
                        resultValues = resultValues(z, "Model")
                        W = resultValues
                        resultValues = W
                        branchCondition = W
                        if branchCondition then
                            d = W.IsA
                            d = d(W, "Model")
                            resultValues = d
                        else
                        end
                        branchCondition = resultValues
                        if branchCondition then
                            resultValues = W.FindFirstChild
                            resultValues = resultValues(W, "HumanoidRootPart")
                            c = resultValues
                            branchCondition = c
                            resultValues = c
                            if branchCondition then
                                p = c.IsA
                                p = p(c, "BasePart")
                                resultValues = p
                            else
                            end
                            branchCondition = resultValues
                            if branchCondition then
                                resultValues = c.Position
                                e = resultValues
                            else
                            end
                        else
                        end
                    end
                    d = (not e)
                    W = d
                    branchCondition = d
                    if branchCondition then
                        d = z.IsA
                        d = d(z, "BasePart")
                        W = d
                    else
                    end
                    branchCondition = W
                    if branchCondition then
                        W = z.Position
                        e = W
                    else
                    end
                    c = (not e)
                    branchCondition = c
                    if branchCondition then
                        resultValues = {}
                    else
                        d = captures[3].value
                        c = d.Position
                        p = (e - c)
                        d = p.Magnitude
                        x = captures[4].value
                        p = (d <= x)
                        branchCondition = p
                        if branchCondition then
                            S = environment.tick
                            u = S()
                            S = captures[5].value
                            x = (u - S)
                            S = captures[6].value
                            p = (x > S)
                            branchCondition = p
                            if branchCondition then
                                p = environment.print
                                s = captures[4].value
                                S = ("THE THRESHOLD IS " .. s)
                                x = p(S)
                                p = captures[7].value
                                i = captures[2].value
                                Q = i.Name
                                i = captures[4].value
                                Z = ("Enemy '%s' and Superball close (%.2f studs)! Threshold: %.2f. Action.").format
                                s = {Z("Enemy '%s' and Superball close (%.2f studs)! Threshold: %.2f. Action.", Q, d, i)}
                                x = p("AutoSuperball", unpackValues(s))
                                p = environment.tick
                                x = p()
                                captures[5].value = x
                                S = environment.task
                                p = S.spawn
                                u = bindClosure(processAutoSuperball14525217, {captures[8], captures[1], captures[9], captures[10], captures[11], captures[7]})
                                S = p(u)
                            else
                            end
                        else
                        end
                        resultValues = {}
                    end
                end
            end
        end
        return unpackValues(resultValues)
    end

    processAutoSuperball8660765 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H, W, d, e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            W = captures[3].value
            d = captures[4].value
            e = resultValues("AutoSuperball", "Feature ENABLED. Dist:", W, "Delay:", d)
            z = captures[5].value
            resultValues = z
            branchCondition = z
            if branchCondition then
                H = captures[5].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[5].value
                e = resultValues.Disconnect
                e = e(resultValues)
            else
            end
            e = captures[6].value
            resultValues = e.Heartbeat
            z = captures[7].value
            e = resultValues.Connect
            e = e(resultValues, z)
            captures[5].value = e
            resultValues = captures[2].value
            z = resultValues("AutoSuperball", "Update loop started.")
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processBlockTales10648731 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        resultValues = temporary.SendKeyEvent
        z = H.Space
        W = environment.game
        resultValues = resultValues(temporary, true, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales16476862 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local H, W, resultValues, temporary, z
        temporary = captures[1].value
        W = environment.Enum
        H = W.KeyCode
        z = H.Space
        resultValues = temporary.SendKeyEvent
        W = environment.game
        resultValues = resultValues(temporary, false, z, false, W)
        resultValues = {}
        return unpackValues(resultValues)
    end

    processSuperballTracker12844156 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H, W, c, e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            z = captures[1].value
            e = z.Parent
            resultValues = e
            branchCondition = e
            if branchCondition then
                H = captures[2].value
                e = H
                branchCondition = H
                if branchCondition then
                    c = captures[1].value
                    W = c.Parent
                    c = captures[2].value
                    H = (W == c)
                    e = H
                else
                end
                resultValues = e
            else
            end
            e = resultValues
            temporary = (not e)
            branchCondition = temporary
            if branchCondition then
                temporary = captures[3].value
                resultValues = temporary("SuperballTracker", "Tracked Superball no longer valid. Clearing ref.")
                captures[1].value = nil
            else
            end
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processSuperballTracker2111291 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H, W, c, d, e, resultValues, temporary, z
        e = argument1
        H = e.Name
        W = captures[1].value
        z = (H == W)
        branchCondition = z
        resultValues = z
        if branchCondition then
            z = e.IsA
            z = z(e, "Folder")
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            d = ("'%s' folder added. Re-initializing monitor.").format
            temporary = captures[2].value
            c = captures[1].value
            W = {d("'%s' folder added. Re-initializing monitor.", c)}
            resultValues = temporary("SuperballTracker", unpackValues(W))
            z = captures[3].value
            branchCondition = z
            resultValues = z
            if branchCondition then
                H = captures[3].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                temporary = captures[3].value
                resultValues = temporary.Disconnect
                resultValues = resultValues(temporary)
            else
            end
            temporary = captures[4].value
            resultValues = temporary()
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processSuperballTracker2958784 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local x
        local z
        e = argument1
        branchCondition = e
        resultValues = e
        if branchCondition then
            p = e.Name
            x = captures[1].value
            d = (p == x)
            W = d
            branchCondition = d
            if branchCondition then
            else
                p = e.Name
                d = (p == "Hyperball")
                W = d
            end
            z = W
            branchCondition = W
            if branchCondition then
                W = e.IsA
                W = W(e, "BasePart")
                z = W
            else
            end
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[2].value
            c = e.Name
            d = ("Potential Superball '%s' added. Updating tracked instance.").format
            W = {d("Potential Superball '%s' added. Updating tracked instance.", c)}
            resultValues = temporary("SuperballTracker", unpackValues(W))
            temporary = e
            captures[3].value = temporary
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    processSuperballTracker4879227 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H
        local Q
        local S
        local W
        local c
        local d
        local e
        local i
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        temporary = captures[1].value
        resultValues = temporary("SuperballTracker", "Initializing core monitor...")
        temporary = captures[2].value
        e = captures[3].value
        resultValues = temporary.FindFirstChild
        resultValues = resultValues(temporary, e)
        captures[4].value = resultValues
        z = captures[4].value
        e = z
        branchCondition = z
        if branchCondition then
            z = captures[4].value
            H = z.IsA
            H = H(z, "Folder")
            e = H
        else
        end
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            c = captures[4].value
            p = c.GetFullName
            d = {p(c)}
            c = ("BattleDump folder found: %s. Setting up listeners.").format
            W = {c("BattleDump folder found: %s. Setting up listeners.", unpackValues(d))}
            e = temporary("SuperballTracker", unpackValues(W))
            e = false
            temporary = environment.ipairs
            c = captures[4].value
            p = c.GetChildren
            d = {p(c)}
            c = {temporary(unpackValues(d))}
            z = c[1]
            H = c[2]
            W = c[3]
            while true do
                local exitLoop1 = false
                repeat
                    W, d = z(H, W)
                    branchCondition = W
                    if branchCondition then
                        S = d.Name
                        u = captures[5].value
                        x = (S == u)
                        p = x
                        branchCondition = x
                        if branchCondition then
                            x = d.IsA
                            x = x(d, "BasePart")
                            p = x
                        else
                        end
                        branchCondition = p
                        if branchCondition then
                            temporary = d
                            captures[6].value = temporary
                            p = captures[1].value
                            Q = d.Name
                            i = ("Found existing Superball '%s'.").format
                            s = {i("Found existing Superball '%s'.", Q)}
                            x = p("SuperballTracker", unpackValues(s))
                            e = true
                        else
                            break
                        end
                    else
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
            z = (not e)
            branchCondition = z
            if branchCondition then
                captures[6].value = nil
            else
            end
            c = captures[7].value
            branchCondition = c
            H = c
            if branchCondition then
                d = captures[7].value
                c = d.Connected
                H = c
            else
            end
            branchCondition = H
            if branchCondition then
                H = captures[7].value
                W = H.Disconnect
                W = W(H)
            else
            end
            W = captures[4].value
            H = W.ChildAdded
            W = H.Connect
            c = captures[8].value
            W = W(H, c)
            captures[7].value = W
        else
            e = captures[9].value
            u = ("'%s' folder not found. Will monitor Workspace.ChildAdded.").format
            S = captures[3].value
            x = {u("'%s' folder not found. Will monitor Workspace.ChildAdded.", S)}
            H = e("SuperballTracker", unpackValues(x))
            captures[6].value = nil
        end
        d = captures[10].value
        H = d
        branchCondition = d
        if branchCondition then
            x = captures[10].value
            d = x.Connected
            H = d
        else
        end
        branchCondition = H
        if branchCondition then
            H = captures[10].value
            c = H.Disconnect
            c = c(H)
        else
        end
        c = captures[2].value
        H = c.ChildAdded
        d = bindClosure(processSuperballTracker2111291, {captures[3], captures[1], captures[7], captures[11]})
        c = H.Connect
        c = c(H, d)
        captures[10].value = c
        x = captures[12].value
        H = x
        branchCondition = x
        if branchCondition then
            S = captures[12].value
            x = S.Connected
            H = x
        else
        end
        branchCondition = H
        if branchCondition then
            H = captures[12].value
            d = H.Disconnect
            d = d(H)
        else
        end
        d = captures[13].value
        resultValues = {}
        H = d.Heartbeat
        x = bindClosure(processSuperballTracker12844156, {captures[6], captures[4], captures[1]})
        d = H.Connect
        d = d(H, x)
        captures[12].value = d
        H = captures[1].value
        x = H("SuperballTracker", "Core monitoring initialized.")
        return unpackValues(resultValues)
    end

    setAutoSuperballDistance = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local c, d, e, resultValues, temporary, z
        e = argument1
        temporary = e
        captures[1].value = temporary
        resultValues = captures[2].value
        d = ("AutoSB dist threshold: %.1f studs").format
        c = {d("AutoSB dist threshold: %.1f studs", e)}
        z = resultValues("UI", unpackValues(c))
        resultValues = {}
        return unpackValues(resultValues)
    end

    setAutoSuperballEnabled = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = captures[1].value
            resultValues = temporary("Warning", "Auto Superball is dependent on your framerate. the higher your framerate is, the more accurate this is going to be.", 6.5)
            temporary = captures[2].value
            resultValues = temporary()
        else
            temporary = captures[3].value
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Auto Linebounce ===

    processAutoLinebounce13008852 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            temporary = captures[2].value
            resultValues = temporary("AutoLinebounce", "Sequence start: linebounce_isActive (local) is OFF. Terminating sequence.")
            resultValues = {}
        else
            resultValues = captures[3].value
            temporary = (not resultValues)
            branchCondition = temporary
            if branchCondition then
                temporary = captures[2].value
                resultValues = temporary("AutoLinebounce", "Sequence start: autoSuperball_isActive is OFF. Terminating sequence.")
                resultValues = {}
            else
                temporary = captures[2].value
                resultValues = temporary("AutoLinebounce", "Starting Linebounce sequence...")
                resultValues = environment.task
                temporary = resultValues.wait
                e = captures[4].value
                resultValues = temporary(e)
                e = captures[5].value
                z = e
                W = (1 < 0)
                e = 0
                while true do
                    local exitLoop1 = false
                    repeat
                        c = (not W)
                        e = (e + 1)
                        resultValues = (e <= z)
                        resultValues = (c and resultValues)
                        c = (e >= z)
                        c = (W and c)
                        resultValues = (c or resultValues)
                        temporary = (resultValues and 8902380)
                        branchCondition = temporary
                        if branchCondition then
                            c = e
                            p = captures[1].value
                            d = (not p)
                            branchCondition = d
                            resultValues = d
                            if branchCondition then
                            else
                                p = captures[3].value
                                d = (not p)
                                resultValues = d
                            end
                            branchCondition = resultValues
                            if branchCondition then
                                temporary = captures[2].value
                                resultValues = temporary("AutoLinebounce", "Toggled OFF or Superball OFF during sequence.")
                                resultValues = {}
                            else
                                temporary = captures[2].value
                                u = ("Linebounce press %d/%d").format
                                S = captures[5].value
                                x = {u("Linebounce press %d/%d", c, S)}
                                resultValues = temporary("AutoLinebounce", unpackValues(x))
                                temporary = captures[6].value
                                resultValues = temporary()
                                resultValues = environment.task
                                temporary = resultValues.wait
                                resultValues = temporary(0.05)
                                temporary = captures[7].value
                                resultValues = temporary()
                                resultValues = captures[5].value
                                temporary = (c < resultValues)
                                branchCondition = temporary
                                if branchCondition then
                                    temporary = captures[2].value
                                    u = ("Waiting %.2fs for next linebounce press...").format
                                    S = captures[4].value
                                    x = {u("Waiting %.2fs for next linebounce press...", S)}
                                    resultValues = temporary("AutoLinebounce", unpackValues(x))
                                    resultValues = environment.task
                                    temporary = resultValues.wait
                                    d = captures[4].value
                                    resultValues = temporary(d)
                                else
                                end
                                break
                            end
                        else
                            temporary = captures[2].value
                            resultValues = temporary("AutoLinebounce", "Linebounce sequence finished successfully.")
                            resultValues = {}
                        end
                        exitLoop1 = true
                        break
                    until true
                    if exitLoop1 then
                        break
                    end
                end
            end
        end
        return unpackValues(resultValues)
    end

    processAutoLinebounce13440583 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local W, d, e, resultValues, temporary
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            W = captures[3].value
            d = captures[4].value
            e = resultValues("AutoLinebounce", "Feature ENABLED. Delay/Interval:", W, "Presses:", d)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processAutoLinebounce13925999 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            temporary = captures[2].value
            resultValues = temporary("AutoLinebounce", "Triggered, but AutoLinebounce toggle is OFF.")
            resultValues = {}
        else
            resultValues = captures[3].value
            temporary = (not resultValues)
            branchCondition = temporary
            if branchCondition then
                temporary = captures[2].value
                resultValues = temporary("AutoLinebounce", "Triggered, but AutoSuperball toggle (dependency) is OFF.")
                resultValues = {}
            else
                temporary = captures[4].value
                branchCondition = temporary
                if branchCondition then
                    temporary = captures[2].value
                    resultValues = temporary("AutoLinebounce", "Triggered, but a linebounce sequence is ALREADY ACTIVE. Ignoring.")
                    resultValues = {}
                else
                    temporary = captures[2].value
                    resultValues = temporary("AutoLinebounce", "Linebounce sequence triggered by Superball action.")
                    captures[4].value = true
                    e = environment.task
                    resultValues = e.spawn
                    z = captures[5].value
                    e = resultValues(z)
                    resultValues = {}
                end
            end
        end
        return unpackValues(resultValues)
    end

    processAutoLinebounce16489682 = function(captures)
        local argumentValues = {}
        local branchCondition
        local H, e, resultValues, temporary, z
        temporary = captures[1].value
        resultValues = temporary("AutoLinebounce", "executeLinebounceSequence_G_Revised CALLED.")
        z = bindClosure(processAutoLinebounce13008852, {captures[2], captures[1], captures[3], captures[4], captures[5], captures[6], captures[7]})
        temporary = environment.pcall
        H = {temporary(z)}
        resultValues = H[1]
        e = H[2]
        z = resultValues
        temporary = (not z)
        branchCondition = temporary
        if branchCondition then
            temporary = captures[8].value
            resultValues = temporary("AutoLinebounce", "Error during linebounce sequence:", e)
        else
        end
        captures[9].value = false
        resultValues = captures[1].value
        H = resultValues("AutoLinebounce", "linebounce_isCurrentlyBouncing set to false.")
        resultValues = {}
        return unpackValues(resultValues)
    end

    processAutoLinebounce2848273 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local e, resultValues, temporary, z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            captures[2].value = false
            e = captures[3].value
            z = e("AutoLinebounce", "Feature DISABLED. Any active sequence should stop.")
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    setAutoLinebounceEnabled = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = environment.enableAutoLinebounce
            resultValues = temporary()
        else
            temporary = environment.disableAutoLinebounce
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    setLinebounceDelay = function(captures, argument1)
        local argumentValues = {argument1}
        local c, d, e, resultValues, temporary, z
        e = argument1
        temporary = e
        d = ("AutoLinebounce delay set to: %.2fs").format
        captures[1].value = temporary
        resultValues = captures[2].value
        c = {d("AutoLinebounce delay set to: %.2fs", e)}
        z = resultValues("UI", unpackValues(c))
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Collectibles ===

    processBlockTales10749514 = function(captures, argument1)
        local argumentValues = {argument1}
        local H, W, c, d, e, resultValues, temporary, z
        temporary = captures[1].value
        z = environment.CFrame
        e = z.new
        c = captures[2].value
        W = c.Position
        d = environment.Vector3
        c = d.new
        d = c(0, 3, 0)
        H = (W + d)
        z = e(H)
        temporary.CFrame = z
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales2703507 = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local H, e, resultValues, temporary, z
        z = argument2
        e = argument1
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales4568261 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local H, e, resultValues, temporary, z
        e = argument1
        z = argument2
        resultValues = e.DisplayName
        H = z.DisplayName
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales5658758 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local H, W, c, d, e, resultValues, temporary, z
        temporary = captures[1].value
        z = environment.CFrame
        e = z.new
        c = captures[2].value
        W = c.Position
        d = environment.Vector3
        c = d.new
        d = c(0, 3, 0)
        H = (W + d)
        z = e(H)
        temporary.CFrame = z
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales9884350 = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local H, W, c, d, e, resultValues, temporary, z
        temporary = captures[1].value
        z = environment.CFrame
        e = z.new
        c = captures[2].value
        W = c.Position
        d = environment.Vector3
        c = d.new
        d = c(0, 3, 0)
        H = (W + d)
        z = e(H)
        temporary.CFrame = z
        resultValues = {}
        return unpackValues(resultValues)
    end

    processCollectibleTP14642422 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local D
        local H
        local I
        local K
        local M
        local P
        local Q
        local S
        local T
        local W
        local Z
        local c
        local d
        local e
        local g
        local i
        local k
        local p
        local resultValues
        local s
        local temporary
        local u
        local vh
        local w
        local x
        local z
        temporary = captures[1].value
        resultValues = temporary.FindFirstChild
        resultValues = resultValues(temporary, "Map")
        e = resultValues
        branchCondition = e
        if branchCondition then
            c = e.GetChildren
            temporary = environment.ipairs
            W = {c(e)}
            c = {temporary(unpackValues(W))}
            H = c[3]
            z = c[2]
            resultValues = c[1]
            W = resultValues
            while true do
                local exitLoop1 = false
                repeat
                    H, d = W(z, H)
                    branchCondition = H
                    if branchCondition then
                        temporary = d.IsA
                        temporary = temporary(d, "Folder")
                        branchCondition = temporary
                        if branchCondition then
                            p = captures[2].value
                            temporary = (p ~= d)
                            branchCondition = temporary
                            if branchCondition then
                                temporary = captures[3].value
                                Q = d.GetFullName
                                s = {Q(d)}
                                Q = ("Map folder changed/found: %s. Resetting collectible lists.").format
                                u = {Q("Map folder changed/found: %s. Resetting collectible lists.", unpackValues(s))}
                                p = temporary("CollectibleTP", unpackValues(u))
                                temporary = {}
                                captures[4].value = temporary
                                captures[5].value = 0
                                x = captures[6].value
                                branchCondition = x
                                if branchCondition then
                                    u = {"Scanning Items..."}
                                    x = captures[6].value
                                    S = x.Refresh
                                    S = S(x, u)
                                    u = {"- No Items Found -"}
                                    x = captures[6].value
                                    S = x.Set
                                    S = S(x, u)
                                else
                                end
                                captures[7].value = nil
                                u = {}
                                captures[8].value = nil
                                captures[9].value = u
                                captures[10].value = 0
                                Q = captures[11].value
                                branchCondition = Q
                                if branchCondition then
                                    Q = captures[11].value
                                    Z = {"Scanning Cards..."}
                                    i = Q.Refresh
                                    i = i(Q, Z)
                                    Z = {"- No Cards Found -"}
                                    Q = captures[11].value
                                    i = Q.Set
                                    i = i(Q, Z)
                                else
                                end
                                Z = {}
                                captures[12].value = nil
                                captures[13].value = nil
                                captures[14].value = Z
                                captures[15].value = 0
                                M = captures[16].value
                                branchCondition = M
                                if branchCondition then
                                    M = captures[16].value
                                    I = M.Refresh
                                    D = {"Scanning BUX..."}
                                    I = I(M, D)
                                    M = captures[16].value
                                    D = {"- No BUX Found -"}
                                    I = M.Set
                                    I = I(M, D)
                                else
                                end
                                captures[17].value = nil
                                captures[18].value = nil
                                D = captures[19].value
                                branchCondition = D
                                if branchCondition then
                                    D = captures[19].value
                                    w = D()
                                else
                                end
                                D = captures[20].value
                                branchCondition = D
                                if branchCondition then
                                    D = captures[20].value
                                    w = D()
                                else
                                end
                                D = captures[21].value
                                branchCondition = D
                                if branchCondition then
                                    D = captures[21].value
                                    w = D()
                                else
                                end
                            else
                            end
                            D = d
                            captures[2].value = D
                            w = captures[2].value
                            resultValues = {w}
                        else
                            break
                        end
                    else
                        z = captures[2].value
                        branchCondition = z
                        if branchCondition then
                            z = captures[3].value
                            H = z("CollectibleTP", "Current map folder lost. Clearing lists.")
                            z = {}
                            captures[4].value = z
                            captures[5].value = 0
                            W = captures[6].value
                            branchCondition = W
                            if branchCondition then
                                W = captures[6].value
                                d = {"- No Map Folder -"}
                                c = W.Refresh
                                c = c(W, d)
                                W = captures[6].value
                                c = W.Set
                                d = {"- No Map Folder -"}
                                c = c(W, d)
                            else
                            end
                            captures[7].value = nil
                            d = {}
                            captures[8].value = nil
                            captures[9].value = d
                            captures[10].value = 0
                            T = captures[11].value
                            branchCondition = T
                            if branchCondition then
                                T = captures[11].value
                                k = T.Refresh
                                g = {"- No Map Folder -"}
                                k = k(T, g)
                                T = captures[11].value
                                g = {"- No Map Folder -"}
                                k = T.Set
                                k = k(T, g)
                            else
                            end
                            g = {}
                            captures[12].value = nil
                            captures[13].value = nil
                            captures[14].value = g
                            captures[15].value = 0
                            P = captures[16].value
                            branchCondition = P
                            if branchCondition then
                                P = captures[16].value
                                vh = {"- No Map Folder -"}
                                K = P.Refresh
                                K = K(P, vh)
                                P = captures[16].value
                                K = P.Set
                                vh = {"- No Map Folder -"}
                                K = K(P, vh)
                            else
                            end
                            captures[17].value = nil
                            captures[18].value = nil
                            captures[2].value = nil
                        else
                        end
                        resultValues = {nil}
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
        else
            z = captures[2].value
            branchCondition = z
            if branchCondition then
                z = captures[3].value
                H = z("CollectibleTP", "Current map folder lost. Clearing lists.")
                z = {}
                captures[4].value = z
                captures[5].value = 0
                W = captures[6].value
                branchCondition = W
                if branchCondition then
                    W = captures[6].value
                    d = {"- No Map Folder -"}
                    c = W.Refresh
                    c = c(W, d)
                    W = captures[6].value
                    c = W.Set
                    d = {"- No Map Folder -"}
                    c = c(W, d)
                else
                end
                captures[7].value = nil
                d = {}
                captures[8].value = nil
                captures[9].value = d
                captures[10].value = 0
                T = captures[11].value
                branchCondition = T
                if branchCondition then
                    T = captures[11].value
                    k = T.Refresh
                    g = {"- No Map Folder -"}
                    k = k(T, g)
                    T = captures[11].value
                    g = {"- No Map Folder -"}
                    k = T.Set
                    k = k(T, g)
                else
                end
                g = {}
                captures[12].value = nil
                captures[13].value = nil
                captures[14].value = g
                captures[15].value = 0
                P = captures[16].value
                branchCondition = P
                if branchCondition then
                    P = captures[16].value
                    vh = {"- No Map Folder -"}
                    K = P.Refresh
                    K = K(P, vh)
                    P = captures[16].value
                    K = P.Set
                    vh = {"- No Map Folder -"}
                    K = K(P, vh)
                else
                end
                captures[17].value = nil
                captures[18].value = nil
                captures[2].value = nil
            else
            end
            resultValues = {nil}
        end
        return unpackValues(resultValues)
    end

    processCollectibleTP15879216 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local H
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local x
        local z
        captures[1].value = false
        resultValues = captures[2].value
        e = resultValues("CollectibleTP", "Collectible Teleporter system DISABLED.")
        resultValues = {}
        captures[3].value = resultValues
        captures[4].value = 0
        z = captures[5].value
        branchCondition = z
        if branchCondition then
            W = {"- System Disabled -"}
            z = captures[5].value
            H = z.Refresh
            H = H(z, W)
            z = captures[5].value
            H = z.Set
            W = {"- System Disabled -"}
            H = H(z, W)
        else
        end
        z = {}
        captures[6].value = z
        captures[7].value = 0
        W = captures[8].value
        branchCondition = W
        if branchCondition then
            W = captures[8].value
            c = W.Refresh
            d = {"- System Disabled -"}
            c = c(W, d)
            W = captures[8].value
            d = {"- System Disabled -"}
            c = W.Set
            c = c(W, d)
        else
        end
        W = {}
        captures[9].value = W
        captures[10].value = 0
        d = captures[11].value
        branchCondition = d
        if branchCondition then
            d = captures[11].value
            p = d.Refresh
            x = {"- System Disabled -"}
            p = p(d, x)
            x = {"- System Disabled -"}
            d = captures[11].value
            p = d.Set
            p = p(d, x)
        else
        end
        captures[12].value = nil
        captures[13].value = nil
        captures[14].value = nil
        captures[15].value = nil
        resultValues = {}
        captures[16].value = nil
        captures[17].value = nil
        captures[18].value = nil
        return unpackValues(resultValues)
    end

    processCollectibleTP16310991 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            e = resultValues("CollectibleTP", "Collectible Teleporter system ENABLED.")
            e = environment.task
            resultValues = e.spawn
            z = bindClosure(scanCollectiblesLoop, {captures[2], captures[1], captures[3], captures[4], captures[5], captures[6], captures[7]})
            e = resultValues(z)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    scanCollectibleCategory = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local T
        local W
        local Z
        local c
        local d
        local e
        local g
        local i
        local k
        local n
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local w
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            z = captures[2].value
            H = z()
            e = (not H)
            resultValues = e
            branchCondition = e
            if branchCondition then
            else
                z = captures[3].value
                e = (not z)
                resultValues = e
            end
            branchCondition = resultValues
            if branchCondition then
                H = captures[4].value
                z = (# H)
                e = (z > 0)
                resultValues = e
                branchCondition = e
                if branchCondition then
                else
                    z = captures[5].value
                    e = (z > 0)
                    resultValues = e
                end
                branchCondition = resultValues
                if branchCondition then
                    temporary = {}
                    captures[4].value = temporary
                    captures[5].value = 0
                    e = captures[6].value
                    branchCondition = e
                    if branchCondition then
                        e = captures[6].value
                        z = e()
                    else
                    end
                else
                end
                resultValues = {}
            else
                e = captures[7].value
                W = {"Geometry"}
                H = captures[3].value
                z = e(H, W)
                e = (not z)
                branchCondition = e
                if branchCondition then
                    d = captures[4].value
                    c = (# d)
                    W = (c > 0)
                    branchCondition = W
                    e = W
                    if branchCondition then
                    else
                        c = captures[5].value
                        W = (c > 0)
                        e = W
                    end
                    branchCondition = e
                    if branchCondition then
                        e = {}
                        captures[4].value = e
                        captures[5].value = 0
                        W = captures[6].value
                        branchCondition = W
                        if branchCondition then
                            W = captures[6].value
                            c = W()
                        else
                        end
                    else
                    end
                    W = captures[8].value
                    resultValues = {}
                    c = W("ItemTP", "Geometry folder not found in current map.")
                else
                    W = {}
                    c = {}
                    d = z.FindFirstChild
                    d = d(z, "ItemSpawner")
                    branchCondition = d
                    if branchCondition then
                        p = environment.ipairs
                        Q = d.GetChildren
                        s = {Q(d)}
                        Q = {p(unpackValues(s))}
                        u = Q[3]
                        x = Q[1]
                        S = Q[2]
                        while true do
                            local exitLoop1 = false
                            repeat
                                u, s = x(S, u)
                                branchCondition = u
                                if branchCondition then
                                    o = s.Name
                                    Z = (o == "Item")
                                    branchCondition = Z
                                    Q = Z
                                    if branchCondition then
                                        M = s.IsA
                                        M = M(s, "BasePart")
                                        branchCondition = M
                                        Z = M
                                        if branchCondition then
                                            I = c[s]
                                            M = (not I)
                                            Z = M
                                        else
                                        end
                                        Q = Z
                                    else
                                    end
                                    branchCondition = Q
                                    if branchCondition then
                                        Q = s.GetAttribute
                                        Q = Q(s, "Item")
                                        i = Q
                                        branchCondition = Q
                                        if branchCondition then
                                            M = environment.type
                                            I = M(Q)
                                            o = (I == "string")
                                            i = o
                                        else
                                        end
                                        branchCondition = i
                                        if branchCondition then
                                            Z = ("%s (Spawner)").format
                                            Z = Z("%s (Spawner)", Q)
                                            o = environment.table
                                            i = o.insert
                                            M = {
                                                DisplayName = Z,
                                                Instance = s,
                                            }
                                            o = i(W, M)
                                            c[s] = true
                                        else
                                        end
                                    else
                                    end
                                    break
                                else
                                end
                                exitLoop1 = true
                                break
                            until true
                            if exitLoop1 then
                                break
                            end
                        end
                    else
                    end
                    p = environment.ipairs
                    Q = z.GetDescendants
                    s = {Q(z)}
                    Q = {p(unpackValues(s))}
                    S = Q[2]
                    x = Q[1]
                    u = Q[3]
                    while true do
                        local exitLoop2 = false
                        repeat
                            u, s = x(S, u)
                            branchCondition = u
                            if branchCondition then
                                o = s.Name
                                Z = (o == "Item")
                                branchCondition = Z
                                Q = Z
                                if branchCondition then
                                    M = s.IsA
                                    M = M(s, "BasePart")
                                    branchCondition = M
                                    Z = M
                                    if branchCondition then
                                        I = c[s]
                                        M = (not I)
                                        Z = M
                                    else
                                    end
                                    Q = Z
                                else
                                end
                                branchCondition = Q
                                if branchCondition then
                                    Q = s.GetAttribute
                                    Q = Q(s, "Item")
                                    branchCondition = Q
                                    i = Q
                                    if branchCondition then
                                        M = environment.type
                                        I = M(Q)
                                        o = (I == "string")
                                        i = o
                                    else
                                    end
                                    branchCondition = i
                                    if branchCondition then
                                        Z = environment.string
                                        i = Z.gsub
                                        o = s.GetFullName
                                        o = o(s)
                                        I = z.GetFullName
                                        I = I(z)
                                        M = (I .. ".")
                                        Z = i(o, M, "")
                                        o = ("%s (%s)").format
                                        o = o("%s (%s)", Q, Z)
                                        M = environment.table
                                        i = M.insert
                                        I = {
                                            DisplayName = o,
                                            Instance = s,
                                        }
                                        M = i(W, I)
                                        c[s] = true
                                    else
                                    end
                                else
                                end
                                break
                            else
                            end
                            exitLoop2 = true
                            break
                        until true
                        if exitLoop2 then
                            break
                        end
                    end
                    u = (# W)
                    S = (u > 0)
                    p = S
                    branchCondition = S
                    if branchCondition then
                        u = (# W)
                        s = captures[5].value
                        S = (u > s)
                        p = S
                    else
                    end
                    branchCondition = p
                    if branchCondition then
                        p = captures[9].value
                        Q = (# W)
                        Z = captures[3].value
                        s = ("%d Item(s) found in %s!").format
                        i = Z.Name
                        s = s("%d Item(s) found in %s!", Q, i)
                        x = p("Collectible Alert", s, 4)
                    else
                    end
                    p = (# W)
                    captures[5].value = p
                    x = false
                    u = (# W)
                    Q = captures[4].value
                    s = (# Q)
                    S = (u ~= s)
                    branchCondition = S
                    if branchCondition then
                        x = true
                    else
                        s = environment.table
                        u = s.sort
                        Q = bindClosure(processBlockTales4568261, {})
                        s = u(W, Q)
                        u = {}
                        s = environment.ipairs
                        o = captures[4].value
                        M = {s(o)}
                        i = M[2]
                        Q = M[1]
                        Z = M[3]
                        while true do
                            local exitLoop3 = false
                            repeat
                                Z, o = Q(i, Z)
                                branchCondition = Z
                                if branchCondition then
                                    I = environment.table
                                    M = I.insert
                                    I = M(u, o)
                                    break
                                else
                                end
                                exitLoop3 = true
                                break
                            until true
                            if exitLoop3 then
                                break
                            end
                        end
                        Q = environment.table
                        s = Q.sort
                        i = bindClosure(processBlockTales2703507, {})
                        Q = s(u, i)
                        Q = (# W)
                        i = Q
                        o = (1 < 0)
                        Q = 0
                        while true do
                            local exitLoop4 = false
                            repeat
                                M = (not o)
                                Q = (Q + 1)
                                s = (Q <= i)
                                s = (M and s)
                                M = (Q >= i)
                                M = (o and M)
                                s = (M or s)
                                temporary = (s and 13776826)
                                branchCondition = temporary
                                if branchCondition then
                                    s = Q
                                    w = u[s]
                                    D = (not w)
                                    branchCondition = D
                                    M = D
                                    if branchCondition then
                                    else
                                        g = W[s]
                                        k = g.Instance
                                        n = u[s]
                                        g = n.Instance
                                        T = (k ~= g)
                                        D = T
                                        branchCondition = T
                                        if branchCondition then
                                        else
                                            g = W[s]
                                            k = g.DisplayName
                                            n = u[s]
                                            g = n.DisplayName
                                            T = (k ~= g)
                                            D = T
                                        end
                                        M = D
                                    end
                                    branchCondition = M
                                    if branchCondition then
                                        x = true
                                    else
                                        break
                                    end
                                else
                                end
                                exitLoop4 = true
                                break
                            until true
                            if exitLoop4 then
                                break
                            end
                        end
                    end
                    branchCondition = x
                    if branchCondition then
                        u = W
                        captures[4].value = u
                        s = captures[6].value
                        branchCondition = s
                        if branchCondition then
                            s = captures[6].value
                            Q = s()
                        else
                        end
                    else
                    end
                    resultValues = {}
                end
            end
        end
        return unpackValues(resultValues)
    end

    scanCollectiblesLoop = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local H, e, resultValues, temporary, z
        temporary = captures[1].value
        resultValues = temporary("CollectibleTP", "Scan loop started.")
        while true do
            local exitLoop1 = false
            repeat
                temporary = captures[2].value
                branchCondition = temporary
                if branchCondition then
                    z = captures[3].value
                    e = (not z)
                    branchCondition = e
                    resultValues = e
                    if branchCondition then
                    else
                        H = captures[3].value
                        z = H.Parent
                        e = (not z)
                        resultValues = e
                    end
                    branchCondition = resultValues
                    if branchCondition then
                    else
                        temporary = captures[4].value
                        branchCondition = temporary
                        if branchCondition then
                            temporary = captures[4].value
                            resultValues = temporary()
                        else
                        end
                        temporary = captures[5].value
                        branchCondition = temporary
                        if branchCondition then
                            temporary = captures[5].value
                            resultValues = temporary()
                        else
                        end
                        temporary = captures[6].value
                        branchCondition = temporary
                        if branchCondition then
                            temporary = captures[6].value
                            resultValues = temporary()
                        else
                        end
                        resultValues = environment.task
                        temporary = resultValues.wait
                        e = captures[7].value
                        resultValues = temporary(e)
                        break
                    end
                else
                end
                exitLoop1 = true
                break
            until true
            if exitLoop1 then
                break
            end
        end
        temporary = captures[1].value
        resultValues = temporary("CollectibleTP", "Scan loop terminated.")
        resultValues = {}
        return unpackValues(resultValues)
    end

    selectCollectibleBuxTP = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        e = argument1
        resultValues = e
        branchCondition = e
        if branchCondition then
            H = (# e)
            z = (H > 0)
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = e[1]
            z = temporary
            H = (z ~= "- No BUX Found -")
            resultValues = H
            branchCondition = H
            if branchCondition then
                H = (z ~= "Scanning BUX...")
                resultValues = H
            else
            end
            branchCondition = resultValues
            if branchCondition then
                temporary = z
                captures[1].value = temporary
            else
            end
            captures[2].value = nil
            H = environment.ipairs
            p = captures[3].value
            x = {H(p)}
            W = x[1]
            d = x[3]
            c = x[2]
            while true do
                local exitLoop1 = false
                repeat
                    d, p = W(c, d)
                    branchCondition = d
                    if branchCondition then
                        S = p.DisplayName
                        x = (S == z)
                        branchCondition = x
                        if branchCondition then
                            x = p.Instance
                            captures[2].value = x
                            S = captures[4].value
                            Z = ("Selected: %s").format
                            i = {Z("Selected: %s", z)}
                            u = S("BuxTP", unpackValues(i))
                        else
                            break
                        end
                    else
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
        else
            captures[2].value = nil
            W = environment.sN
            H = (W == "- No BUX Found -")
            branchCondition = H
            if branchCondition then
                captures[1].value = nil
            else
            end
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    selectCollectibleCardTP = function(captures, argument1, argument2, argument3, argument4)
        local argumentValues = {argument1, argument2, argument3, argument4}
        local branchCondition
        local H
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        e = argument1
        resultValues = e
        branchCondition = e
        if branchCondition then
            H = (# e)
            z = (H > 0)
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = e[1]
            z = temporary
            temporary = z
            captures[1].value = temporary
            captures[2].value = nil
            H = environment.ipairs
            p = captures[3].value
            x = {H(p)}
            d = x[3]
            W = x[1]
            c = x[2]
            while true do
                local exitLoop1 = false
                repeat
                    d, p = W(c, d)
                    branchCondition = d
                    if branchCondition then
                        S = p.DisplayName
                        x = (S == z)
                        branchCondition = x
                        if branchCondition then
                            x = p.Instance
                            Z = ("Selected: %s").format
                            captures[2].value = x
                            S = captures[4].value
                            i = {Z("Selected: %s", z)}
                            u = S("CardTP", unpackValues(i))
                        else
                            break
                        end
                    else
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
        else
            captures[2].value = nil
            captures[1].value = nil
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    selectCollectibleItemTP = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local H
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local p
        local resultValues
        local temporary
        local u
        local x
        local z
        e = argument1
        resultValues = e
        branchCondition = e
        if branchCondition then
            H = (# e)
            z = (H > 0)
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = e[1]
            z = temporary
            temporary = z
            captures[1].value = temporary
            captures[2].value = nil
            H = environment.ipairs
            p = captures[3].value
            x = {H(p)}
            W = x[1]
            c = x[2]
            d = x[3]
            while true do
                local exitLoop1 = false
                repeat
                    d, p = W(c, d)
                    branchCondition = d
                    if branchCondition then
                        S = p.DisplayName
                        x = (S == z)
                        branchCondition = x
                        if branchCondition then
                            x = p.Instance
                            captures[2].value = x
                            Z = ("Selected: %s").format
                            S = captures[4].value
                            i = {Z("Selected: %s", z)}
                            u = S("ItemTP", unpackValues(i))
                        else
                            break
                        end
                    else
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
        else
            captures[2].value = nil
            captures[1].value = nil
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    tPBack = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local e, resultValues, temporary, z
        e = argument1
        temporary = environment.getgenv
        resultValues = temporary()
        z = e
        resultValues.TPBackToOriginal = z
        resultValues = {}
        return unpackValues(resultValues)
    end

    teleportToSelectedBUX = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local H
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local temporary
        local u
        local z
        z = captures[1].value
        e = (not z)
        branchCondition = e
        resultValues = e
        if branchCondition then
        else
            H = captures[1].value
            z = H.Parent
            e = (not z)
            resultValues = e
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[2].value
            resultValues = temporary("BUX TP Error", "No valid BUX selected or it disappeared.", 5)
            resultValues = {}
        else
            resultValues = captures[3].value
            temporary = resultValues.Character
            e = temporary
            resultValues = e
            branchCondition = e
            if branchCondition then
                z = e.FindFirstChild
                z = z(e, "HumanoidRootPart")
                resultValues = z
            else
            end
            z = {}
            z.value = resultValues
            resultValues = z.value
            temporary = resultValues.CFrame
            H = temporary
            W = z.value
            branchCondition = W
            resultValues = W
            if branchCondition then
                W = captures[1].value
                c = W.IsA
                c = c(W, "BasePart")
                resultValues = c
            else
            end
            branchCondition = resultValues
            if branchCondition then
                c = bindClosure(processBlockTales10749514, {z, captures[1]})
                temporary = environment.pcall
                d = {temporary(c)}
                resultValues = d[1]
                W = d[2]
                c = resultValues
                branchCondition = c
                if branchCondition then
                    temporary = captures[2].value
                    u = captures[1].value
                    S = u.Name
                    p = ("Teleported to " .. S)
                    resultValues = temporary("BUX TP Success", p, 3)
                    resultValues = environment.getgenv
                    d = resultValues()
                    temporary = d.TPBackToOriginal
                    branchCondition = temporary
                    if branchCondition then
                        resultValues = environment.task
                        temporary = resultValues.wait
                        resultValues = temporary(2)
                        d = H
                        temporary = z.value
                        temporary.CFrame = d
                    else
                    end
                else
                    temporary = captures[2].value
                    resultValues = temporary("BUX TP Failed", "Error during CFrame set.", 5)
                    temporary = captures[4].value
                    resultValues = temporary("BuxTP", "TP CFrame error:", W)
                end
            else
                temporary = captures[2].value
                resultValues = temporary("BUX TP Error", "Player HRP or target part invalid.", 5)
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    teleportToSelectedCard = function(captures)
        local argumentValues = {}
        local branchCondition
        local H
        local Q
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local s
        local temporary
        local u
        local z
        z = captures[1].value
        e = (not z)
        branchCondition = e
        resultValues = e
        if branchCondition then
        else
            H = captures[1].value
            z = H.Parent
            e = (not z)
            resultValues = e
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[2].value
            resultValues = temporary("Card TP Error", "No valid card selected or card disappeared.", 5)
            resultValues = {}
        else
            resultValues = captures[3].value
            temporary = resultValues.Character
            e = temporary
            resultValues = e
            branchCondition = e
            if branchCondition then
                z = e.FindFirstChild
                z = z(e, "HumanoidRootPart")
                resultValues = z
            else
            end
            z = {}
            z.value = resultValues
            resultValues = z.value
            temporary = resultValues.CFrame
            H = temporary
            W = z.value
            branchCondition = W
            resultValues = W
            if branchCondition then
                W = captures[1].value
                c = W.IsA
                c = c(W, "BasePart")
                resultValues = c
            else
            end
            branchCondition = resultValues
            if branchCondition then
                c = bindClosure(processBlockTales9884350, {z, captures[1]})
                temporary = environment.pcall
                d = {temporary(c)}
                resultValues = d[1]
                c = resultValues
                W = d[2]
                branchCondition = c
                if branchCondition then
                    temporary = captures[2].value
                    u = temporary
                    s = captures[1].value
                    Q = s.GetAttribute
                    Q = Q(s, "Item")
                    branchCondition = Q
                    S = Q
                    if branchCondition then
                    else
                        Q = captures[1].value
                        s = Q.Name
                        S = s
                    end
                    p = ("Teleported to " .. S)
                    temporary = u
                    resultValues = temporary("Card TP Success", p, 3)
                    resultValues = environment.getgenv
                    d = resultValues()
                    temporary = d.TPBackToOriginal
                    branchCondition = temporary
                    if branchCondition then
                        resultValues = environment.task
                        temporary = resultValues.wait
                        resultValues = temporary(2)
                        d = H
                        temporary = z.value
                        temporary.CFrame = d
                    else
                    end
                else
                    temporary = captures[2].value
                    resultValues = temporary("Card TP Failed", "Error during CFrame set.", 5)
                    temporary = captures[4].value
                    resultValues = temporary("CardTP", "TP CFrame error:", W)
                end
            else
                temporary = captures[2].value
                resultValues = temporary("Card TP Error", "Player HRP or target part invalid.", 5)
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    teleportToSelectedItem = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H
        local Q
        local S
        local W
        local c
        local d
        local e
        local p
        local resultValues
        local s
        local temporary
        local u
        local z
        z = captures[1].value
        e = (not z)
        resultValues = e
        branchCondition = e
        if branchCondition then
        else
            H = captures[1].value
            z = H.Parent
            e = (not z)
            resultValues = e
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[2].value
            resultValues = temporary("Item TP Error", "No valid item selected or item disappeared.", 5)
            resultValues = {}
        else
            resultValues = captures[3].value
            temporary = resultValues.Character
            e = temporary
            branchCondition = e
            resultValues = e
            if branchCondition then
                z = e.FindFirstChild
                z = z(e, "HumanoidRootPart")
                resultValues = z
            else
            end
            z = {}
            z.value = resultValues
            resultValues = z.value
            temporary = resultValues.CFrame
            W = z.value
            H = temporary
            resultValues = W
            branchCondition = W
            if branchCondition then
                W = captures[1].value
                c = W.IsA
                c = c(W, "BasePart")
                resultValues = c
            else
            end
            branchCondition = resultValues
            if branchCondition then
                c = bindClosure(processBlockTales5658758, {z, captures[1]})
                temporary = environment.pcall
                d = {temporary(c)}
                resultValues = d[1]
                W = d[2]
                c = resultValues
                branchCondition = c
                if branchCondition then
                    temporary = captures[2].value
                    u = temporary
                    s = captures[1].value
                    Q = s.GetAttribute
                    Q = Q(s, "Item")
                    S = Q
                    branchCondition = Q
                    if branchCondition then
                    else
                        Q = captures[1].value
                        s = Q.Name
                        S = s
                    end
                    p = ("Teleported to " .. S)
                    temporary = u
                    resultValues = temporary("Item TP Success", p, 3)
                    resultValues = environment.getgenv
                    d = resultValues()
                    temporary = d.TPBackToOriginal
                    branchCondition = temporary
                    if branchCondition then
                        resultValues = environment.task
                        temporary = resultValues.wait
                        resultValues = temporary(2)
                        d = H
                        temporary = z.value
                        temporary.CFrame = d
                    else
                    end
                else
                    temporary = captures[2].value
                    resultValues = temporary("Item TP Failed", "Error during CFrame set.", 5)
                    temporary = captures[4].value
                    resultValues = temporary("ItemTP", "TP CFrame error:", W)
                end
            else
                temporary = captures[2].value
                resultValues = temporary("Item TP Error", "Player HRP or target part invalid.", 5)
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end


    -- === Tex / Enemy targeting ===

    disableEnemyDropdownSystem = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H, W, c, e, resultValues, z
        resultValues = {}
        captures[1].value = false
        captures[2].value = resultValues
        e = captures[3].value
        branchCondition = e
        if branchCondition then
            e = captures[3].value
            z = e.Refresh
            H = {"- No Targets in Arena -"}
            z = z(e, H)
            H = {"- No Targets in Arena -"}
            e = captures[3].value
            z = e.Set
            z = z(e, H)
        else
        end
        captures[4].value = nil
        captures[5].value = nil
        captures[6].value = nil
        W = environment.forceGroundEnemies_applyOrRestore
        c = W(false)
        W = captures[7].value
        c = W("ArenaEnemies", "Enemy dropdown system DISABLED.")
        resultValues = {}
        return unpackValues(resultValues)
    end

    disableForceGroundEnemies = function(captures)
        local argumentValues = {}
        local branchCondition
        local e, resultValues, temporary
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues(false)
            resultValues = captures[3].value
            e = resultValues("Flying Enemies", "Restoring original flying states.", 4)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    enableEnemyDropdownSystem = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            e = resultValues("ArenaEnemies", "Enemy dropdown system ENABLED.")
            e = environment.task
            resultValues = e.spawn
            z = bindClosure(processArenaEnemies3920321, {captures[2], captures[1], captures[3], captures[4], captures[5]})
            e = resultValues(z)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    enableForceGroundEnemies = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local e, resultValues, temporary
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            e = resultValues(true)
            resultValues = captures[3].value
            e = resultValues("Flying Enemies", "Will attempt to ground flying enemies.", 4)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processArenaEnemies1989314 = function(captures)
        local argumentValues = {}
        local branchCondition
        local D
        local H
        local I
        local M
        local Q
        local S
        local T
        local W
        local Z
        local c
        local d
        local e
        local i
        local k
        local n
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local w
        local x
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            resultValues = environment.table
            z = bindClosure(processBlockTales5793115, {})
            temporary = resultValues.sort
            e = captures[2].value
            resultValues = temporary(e, z)
            temporary = {}
            e = temporary
            z = captures[2].value
            resultValues = (# z)
            temporary = (resultValues == 0)
            branchCondition = temporary
            if branchCondition then
                resultValues = environment.table
                temporary = resultValues.insert
                resultValues = temporary(e, "- No Targets in Arena -")
            else
                temporary = environment.ipairs
                W = captures[2].value
                c = {temporary(W)}
                H = c[3]
                z = c[2]
                resultValues = c[1]
                W = resultValues
                while true do
                    local exitLoop1 = false
                    repeat
                        H, d = W(z, H)
                        branchCondition = H
                        if branchCondition then
                            p = ""
                            temporary = d.IsFlying
                            branchCondition = temporary
                            if branchCondition then
                                p = " (Flying)"
                            else
                            end
                            S = environment.table
                            x = S.insert
                            s = d.DisplayName
                            u = (s .. p)
                            S = x(e, u)
                            break
                        else
                        end
                        exitLoop1 = true
                        break
                    until true
                    if exitLoop1 then
                        break
                    end
                end
            end
            H = captures[1].value
            z = H.CurrentOption
            branchCondition = z
            p = z
            if branchCondition then
                u = (# z)
                S = (u > 0)
                p = S
            else
            end
            c = p
            branchCondition = p
            if branchCondition then
                p = z[1]
                c = p
            else
            end
            W = false
            H = (c or nil)
            d = (# e)
            S = captures[1].value
            x = S.Options
            p = (# x)
            c = (d ~= p)
            branchCondition = c
            if branchCondition then
                W = true
            else
                p = (# e)
                x = p
                u = (1 < 0)
                p = 0
                while true do
                    local exitLoop2 = false
                    repeat
                        s = (not u)
                        p = (p + 1)
                        d = (p <= x)
                        d = (s and d)
                        s = (p >= x)
                        s = (u and s)
                        d = (s or d)
                        temporary = (d and 1624247)
                        branchCondition = temporary
                        if branchCondition then
                            d = p
                            Q = e[d]
                            o = captures[1].value
                            Z = o.Options
                            i = Z[d]
                            s = (Q ~= i)
                            branchCondition = s
                            if branchCondition then
                                W = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop2 = true
                        break
                    until true
                    if exitLoop2 then
                        break
                    end
                end
            end
            branchCondition = W
            if branchCondition then
                d = captures[1].value
                p = d.Refresh
                p = p(d, e)
                d = captures[3].value
                p = d("ArenaEnemies", "Dropdown options refreshed.")
            else
            end
            S = captures[4].value
            p = S
            d = false
            branchCondition = S
            if branchCondition then
                Q = captures[2].value
                u = (# Q)
                S = (u > 0)
                p = S
            else
            end
            branchCondition = p
            if branchCondition then
                p = environment.ipairs
                Q = captures[2].value
                i = {p(Q)}
                u = i[3]
                x = i[1]
                S = i[2]
                while true do
                    local exitLoop3 = false
                    repeat
                        u, Q = x(S, u)
                        branchCondition = u
                        if branchCondition then
                            i = Q.DisplayName
                            Z = Q.IsFlying
                            branchCondition = Z
                            if branchCondition then
                            else
                            end
                            o = captures[4].value
                            Z = (i == o)
                            branchCondition = Z
                            if branchCondition then
                                o = captures[4].value
                                Z = (H ~= o)
                                branchCondition = Z
                                if branchCondition then
                                    o = Q.DisplayName
                                    T = Q.IsFlying
                                    D = (T and " (Flying)")
                                    M = (D or "")
                                    Z = (o .. M)
                                    I = {Z}
                                    o = captures[1].value
                                    M = o.Set
                                    M = M(o, I)
                                else
                                end
                                Z = Q.Instance
                                captures[5].value = Z
                                d = true
                            else
                                break
                            end
                        else
                        end
                        exitLoop3 = true
                        break
                    until true
                    if exitLoop3 then
                        break
                    end
                end
            else
            end
            p = (not d)
            branchCondition = p
            if branchCondition then
                x = H
                p = false
                branchCondition = H
                if branchCondition then
                    i = (H ~= "- No Targets in Arena -")
                    branchCondition = i
                    u = i
                    if branchCondition then
                        i = (H ~= "Scanning new arena...")
                        u = i
                    else
                    end
                    x = u
                else
                end
                branchCondition = x
                if branchCondition then
                    x = environment.ipairs
                    i = captures[2].value
                    M = {x(i)}
                    u = M[2]
                    Q = M[3]
                    S = M[1]
                    while true do
                        local exitLoop4 = false
                        repeat
                            Q, i = S(u, Q)
                            branchCondition = Q
                            if branchCondition then
                                M = i.DisplayName
                                D = i.DisplayName
                                n = i.IsFlying
                                k = (n and " (Flying)")
                                w = (k or "")
                                I = (D .. w)
                                D = (I == H)
                                branchCondition = D
                                if branchCondition then
                                    p = true
                                    w = i.Instance
                                    captures[5].value = w
                                else
                                    break
                                end
                            else
                            end
                            exitLoop4 = true
                            break
                        until true
                        if exitLoop4 then
                            break
                        end
                    end
                else
                end
                x = (not p)
                branchCondition = x
                if branchCondition then
                    u = e[1]
                    x = (u or "- No Targets in Arena -")
                    Q = captures[2].value
                    u = (# Q)
                    S = (u > 0)
                    branchCondition = S
                    if branchCondition then
                        S = (H ~= x)
                        branchCondition = S
                        if branchCondition then
                            S = captures[1].value
                            Q = {x}
                            u = S.Set
                            u = u(S, Q)
                        else
                        end
                        S = (x ~= "- No Targets in Arena -")
                        branchCondition = S
                        if branchCondition then
                            i = captures[2].value
                            Q = i[1]
                            branchCondition = Q
                            S = Q
                            if branchCondition then
                                M = captures[2].value
                                i = M[1]
                                Q = i.Instance
                                S = Q
                            else
                            end
                            captures[5].value = S
                        else
                            captures[5].value = nil
                        end
                    else
                        M = (H ~= nil)
                        branchCondition = M
                        Q = M
                        if branchCondition then
                            M = (H ~= "- No Targets in Arena -")
                            Q = M
                        else
                        end
                        branchCondition = Q
                        if branchCondition then
                            Q = captures[1].value
                            M = {"- No Targets in Arena -"}
                            i = Q.Set
                            i = i(Q, M)
                        else
                        end
                        captures[5].value = nil
                    end
                else
                end
            else
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processArenaEnemies3920321 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H, e, resultValues, temporary, z
        temporary = captures[1].value
        resultValues = temporary("ArenaEnemies", "Enemy dropdown update loop started.")
        while true do
            local exitLoop1 = false
            repeat
                temporary = captures[2].value
                branchCondition = temporary
                if branchCondition then
                    z = captures[3].value
                    e = (not z)
                    resultValues = e
                    branchCondition = e
                    if branchCondition then
                    else
                        H = captures[3].value
                        z = H.Parent
                        e = (not z)
                        resultValues = e
                    end
                    branchCondition = resultValues
                    if branchCondition then
                    else
                        temporary = captures[4].value
                        resultValues = temporary()
                        resultValues = environment.task
                        temporary = resultValues.wait
                        e = captures[5].value
                        resultValues = temporary(e)
                        break
                    end
                else
                end
                exitLoop1 = true
                break
            until true
            if exitLoop1 then
                break
            end
        end
        temporary = captures[1].value
        resultValues = temporary("ArenaEnemies", "Enemy dropdown update loop terminated.")
        resultValues = {}
        return unpackValues(resultValues)
    end

    processBlockTales15516991 = function(captures, argument1, argument2, argument3, argument4, argument5, argument6, argument7)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6, argument7}
        local H, e, resultValues, temporary, z
        z = argument2
        e = argument1
        resultValues = e.RawDistance
        H = z.RawDistance
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales4924877 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local H, e, resultValues, temporary, z
        z = argument2
        e = argument1
        resultValues = e.RawDistance
        H = z.RawDistance
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    processBlockTales5793115 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local H, e, resultValues, temporary, z
        e = argument1
        resultValues = e.RawDistance
        z = argument2
        H = z.RawDistance
        temporary = (resultValues < H)
        resultValues = {temporary}
        return unpackValues(resultValues)
    end

    selectArenaEnemyTarget = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local branchCondition
        local H
        local M
        local Q
        local S
        local W
        local Z
        local c
        local d
        local e
        local i
        local o
        local p
        local resultValues
        local s
        local temporary
        local u
        local x
        local z
        e = argument1
        resultValues = e
        branchCondition = e
        if branchCondition then
            H = (# e)
            z = (H > 0)
            resultValues = z
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = e[1]
            z = temporary
            H = (z ~= "- No Targets -")
            resultValues = H
            branchCondition = H
            if branchCondition then
                c = (z ~= "- No Targets in Arena -")
                H = c
                branchCondition = c
                if branchCondition then
                    p = (z ~= "Scanning new arena...")
                    c = p
                    branchCondition = p
                    if branchCondition then
                        p = (z ~= "Scanning...")
                        c = p
                    else
                    end
                    H = c
                else
                end
                resultValues = H
            else
            end
            branchCondition = resultValues
            if branchCondition then
                temporary = z
                captures[1].value = temporary
            else
            end
            captures[2].value = nil
            H = environment.ipairs
            p = captures[3].value
            x = {H(p)}
            d = x[3]
            c = x[2]
            W = x[1]
            while true do
                local exitLoop1 = false
                repeat
                    d, p = W(c, d)
                    branchCondition = d
                    if branchCondition then
                        s = p.DisplayName
                        u = (s == z)
                        branchCondition = u
                        x = u
                        if branchCondition then
                        else
                            Q = p.IsFlying
                            u = Q
                            branchCondition = Q
                            if branchCondition then
                                Z = p.DisplayName
                                i = (Z .. " (Flying)")
                                Q = (i == z)
                                u = Q
                            else
                            end
                            x = u
                        end
                        branchCondition = x
                        if branchCondition then
                            x = p.Instance
                            captures[2].value = x
                            S = captures[4].value
                            Z = environment.tostring
                            M = p.Instance
                            o = {Z(M)}
                            Z = ("User selected: %s (Inst: %s)").format
                            i = {Z("User selected: %s (Inst: %s)", z, unpackValues(o))}
                            u = S("ArenaEnemies", unpackValues(i))
                        else
                            break
                        end
                    else
                    end
                    exitLoop1 = true
                    break
                until true
                if exitLoop1 then
                    break
                end
            end
            d = captures[2].value
            c = (not d)
            H = c
            branchCondition = c
            if branchCondition then
                p = (z ~= "- No Targets -")
                branchCondition = p
                c = p
                if branchCondition then
                    u = (z ~= "- No Targets in Arena -")
                    branchCondition = u
                    p = u
                    if branchCondition then
                        Q = (z ~= "Scanning new arena...")
                        branchCondition = Q
                        u = Q
                        if branchCondition then
                            Q = (z ~= "Scanning...")
                            u = Q
                        else
                        end
                        p = u
                    else
                    end
                    c = p
                else
                end
                H = c
            else
            end
            branchCondition = H
            if branchCondition then
                H = captures[4].value
                S = ("Could not find instance for: %s").format
                p = {S("Could not find instance for: %s", z)}
                W = H("ArenaEnemies", unpackValues(p))
            else
            end
        else
            captures[2].value = nil
            d = environment.sDN
            c = (d == "- No Targets -")
            H = c
            branchCondition = c
            if branchCondition then
            else
                d = environment.sDN
                c = (d == "- No Targets in Arena -")
                H = c
            end
            branchCondition = H
            if branchCondition then
                captures[1].value = nil
            else
            end
            W = captures[4].value
            c = W("ArenaEnemies", "Dropdown selection cleared or placeholder selected.")
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    setForceGroundEnemiesEnabled = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = environment.enableForceGroundEnemies
            resultValues = temporary()
        else
            temporary = environment.disableForceGroundEnemies
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    updateArenaEnemies = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local Ah
        local Ch
        local D
        local H
        local I
        local K
        local Lh
        local M
        local Nh
        local Oh
        local P
        local Q
        local Rh
        local S
        local T
        local Uh
        local Vh
        local W
        local Yh
        local Z
        local bh
        local c
        local d
        local e
        local g
        local h
        local i
        local jh
        local k
        local lh
        local n
        local o
        local p
        local resultValues
        local s
        local t
        local temporary
        local u
        local vh
        local w
        local x
        local y
        local z
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            resultValues = captures[2].value
            temporary = resultValues.Name
            e = temporary
            temporary = captures[3].value
            resultValues = temporary.FindFirstChild
            resultValues = resultValues(temporary, "FPlayers")
            z = resultValues
            temporary = (not z)
            branchCondition = temporary
            if branchCondition then
                resultValues = {}
            else
                temporary = z.FindFirstChild
                temporary = temporary(z, e)
                H = temporary
                temporary = (not H)
                branchCondition = temporary
                if branchCondition then
                    resultValues = {}
                else
                    temporary = H.FindFirstChild
                    temporary = temporary(H, "Arena")
                    W = temporary
                    resultValues = W
                    branchCondition = W
                    if branchCondition then
                        d = W.IsA
                        d = d(W, "ObjectValue")
                        resultValues = d
                    else
                    end
                    temporary = (not resultValues)
                    branchCondition = temporary
                    if branchCondition then
                        resultValues = {}
                    else
                        temporary = W.Value
                        resultValues = captures[4].value
                        c = temporary
                        temporary = (c ~= resultValues)
                        branchCondition = temporary
                        if branchCondition then
                            temporary = captures[5].value
                            S = environment.tostring
                            Q = temporary
                            i = captures[4].value
                            branchCondition = i
                            s = i
                            if branchCondition then
                                Z = captures[4].value
                                i = Z.Name
                                s = i
                            else
                            end
                            u = S(s)
                            temporary = Q
                            i = temporary
                            branchCondition = c
                            S = environment.tostring
                            Q = c
                            if branchCondition then
                                Z = c.Name
                                Q = Z
                            else
                            end
                            temporary = i
                            s = {S(Q)}
                            S = ("Arena changed. Old:%s,New:%s. Resetting.").format
                            x = {S("Arena changed. Old:%s,New:%s. Resetting.", u, unpackValues(s))}
                            resultValues = temporary("ArenaEnemies", unpackValues(x))
                            temporary = {}
                            captures[6].value = temporary
                            p = {}
                            captures[7].value = nil
                            captures[8].value = nil
                            captures[9].value = p
                            x = captures[10].value
                            branchCondition = x
                            if branchCondition then
                            else
                            end
                            x = captures[11].value
                            branchCondition = x
                            if branchCondition then
                                x = captures[11].value
                                S = x.Refresh
                                u = {"Scanning..."}
                                S = S(x, u)
                            else
                            end
                            x = c
                            captures[4].value = x
                            S = captures[12].value
                            u = S()
                        else
                        end
                        S = (not c)
                        branchCondition = S
                        if branchCondition then
                            i = captures[6].value
                            Q = (# i)
                            s = (Q > 0)
                            S = s
                            branchCondition = s
                            if branchCondition then
                            else
                                Q = captures[4].value
                                s = (Q ~= nil)
                                S = s
                            end
                            branchCondition = S
                            if branchCondition then
                                S = {}
                                captures[6].value = S
                                captures[4].value = nil
                                s = captures[12].value
                                Q = s()
                            else
                            end
                            resultValues = {}
                        else
                            s = H.GetAttribute
                            s = s(H, "FPos")
                            i = s
                            branchCondition = s
                            if branchCondition then
                                M = environment.typeof
                                I = M(s)
                                o = (I == "Vector3")
                                i = o
                            else
                            end
                            Q = (not i)
                            branchCondition = Q
                            if branchCondition then
                                s = nil
                            else
                            end
                            i = captures[3].value
                            Z = i.FindFirstChild
                            Z = Z(i, "Enemies")
                            i = (not Z)
                            branchCondition = i
                            if branchCondition then
                                M = captures[6].value
                                o = (# M)
                                i = (o > 0)
                                branchCondition = i
                                if branchCondition then
                                    i = {}
                                    captures[6].value = i
                                    o = captures[12].value
                                    M = o()
                                else
                                end
                                resultValues = {}
                            else
                                o = {}
                                k = Z.GetChildren
                                M = environment.ipairs
                                T = {k(Z)}
                                k = {M(unpackValues(T))}
                                I = k[1]
                                D = k[2]
                                w = k[3]
                                while true do
                                    local exitLoop1 = false
                                    repeat
                                        w, T = I(D, w)
                                        branchCondition = w
                                        if branchCondition then
                                            k = T.IsA
                                            k = k(T, "Actor")
                                            branchCondition = k
                                            if branchCondition then
                                                k = T.FindFirstChild
                                                k = k(T, "Arena")
                                                branchCondition = k
                                                g = k
                                                if branchCondition then
                                                    vh = k.IsA
                                                    vh = vh(k, "ObjectValue")
                                                    P = vh
                                                    branchCondition = vh
                                                    if branchCondition then
                                                        h = k.Value
                                                        vh = (h == c)
                                                        P = vh
                                                    else
                                                    end
                                                    g = P
                                                else
                                                end
                                                branchCondition = g
                                                if branchCondition then
                                                    g = T.Name
                                                    P = environment.math
                                                    t = T.GetAttribute
                                                    n = P.huge
                                                    t = t(T, "Flying")
                                                    vh = (t or false)
                                                    K = nil
                                                    t = environment.type
                                                    y = t(vh)
                                                    h = (y ~= "boolean")
                                                    branchCondition = h
                                                    if branchCondition then
                                                        vh = false
                                                    else
                                                    end
                                                    jh = captures[10].value
                                                    t = jh
                                                    branchCondition = jh
                                                    if branchCondition then
                                                        jh = (vh == true)
                                                        t = jh
                                                    else
                                                    end
                                                    branchCondition = t
                                                    if branchCondition then
                                                        jh = captures[9].value
                                                        y = jh[T]
                                                        t = (y == nil)
                                                        branchCondition = t
                                                        if branchCondition then
                                                            t = captures[9].value
                                                            t[T] = true
                                                        else
                                                        end
                                                        t = environment.pcall
                                                        Nh = T.SetAttribute
                                                        Rh = {t(Nh, T, "Flying", false)}
                                                        y = Rh[1]
                                                        jh = Rh[2]
                                                        t = (not y)
                                                        branchCondition = t
                                                        if branchCondition then
                                                            t = captures[13].value
                                                            Ch = ("Failed to set 'Flying' attribute for %s to false: %s").format
                                                            Rh = {Ch("Failed to set 'Flying' attribute for %s to false: %s", g, jh)}
                                                            Nh = t("ArenaEnemies", unpackValues(Rh))
                                                        else
                                                            t = captures[5].value
                                                            Ch = environment.tostring
                                                            Yh = {Ch(vh)}
                                                            Ch = ("Set 'Flying' for %s to false (was %s).").format
                                                            Rh = {Ch("Set 'Flying' for %s to false (was %s).", g, unpackValues(Yh))}
                                                            Nh = t("ArenaEnemies", unpackValues(Rh))
                                                        end
                                                        vh = false
                                                    else
                                                        Lh = captures[10].value
                                                        Nh = (not Lh)
                                                        y = Nh
                                                        branchCondition = Nh
                                                        if branchCondition then
                                                            bh = captures[9].value
                                                            Lh = bh[T]
                                                            Nh = (Lh == true)
                                                            y = Nh
                                                        else
                                                        end
                                                        branchCondition = y
                                                        if branchCondition then
                                                            y = environment.pcall
                                                            Lh = T.SetAttribute
                                                            Ch = {y(Lh, T, "Flying", true)}
                                                            Nh = Ch[2]
                                                            jh = Ch[1]
                                                            y = (not jh)
                                                            branchCondition = y
                                                            if branchCondition then
                                                                y = captures[13].value
                                                                Yh = ("Failed to restore 'Flying' attribute for %s to true: %s").format
                                                                Ch = {Yh("Failed to restore 'Flying' attribute for %s to true: %s", g, Nh)}
                                                                Lh = y("ArenaEnemies", unpackValues(Ch))
                                                            else
                                                                y = captures[5].value
                                                                Yh = ("Restored 'Flying' for %s to true.").format
                                                                Ch = {Yh("Restored 'Flying' for %s to true.", g)}
                                                                Lh = y("ArenaEnemies", unpackValues(Ch))
                                                            end
                                                            y = captures[9].value
                                                            y[T] = nil
                                                            vh = true
                                                        else
                                                            bh = captures[10].value
                                                            Lh = (not bh)
                                                            branchCondition = Lh
                                                            jh = Lh
                                                            if branchCondition then
                                                                Rh = captures[9].value
                                                                bh = Rh[T]
                                                                Lh = (bh == false)
                                                                jh = Lh
                                                            else
                                                            end
                                                            branchCondition = jh
                                                            if branchCondition then
                                                                jh = captures[9].value
                                                                jh[T] = nil
                                                            else
                                                            end
                                                        end
                                                    end
                                                    branchCondition = s
                                                    if branchCondition then
                                                        jh = T.GetAttribute
                                                        jh = jh(T, "FPos")
                                                        branchCondition = jh
                                                        Nh = jh
                                                        if branchCondition then
                                                            Rh = environment.typeof
                                                            Ch = Rh(jh)
                                                            bh = (Ch == "Vector3")
                                                            Nh = bh
                                                        else
                                                        end
                                                        branchCondition = Nh
                                                        if branchCondition then
                                                            Nh = jh
                                                            bh = (s - jh)
                                                            K = Nh
                                                            Lh = bh.Magnitude
                                                            n = Lh
                                                            Rh = ("%s(%.1fs)").format
                                                            Rh = Rh("%s(%.1fs)", g, n)
                                                            P = Rh
                                                        else
                                                            bh = T.FindFirstChild
                                                            bh = bh(T, "Model")
                                                            branchCondition = bh
                                                            Ch = bh
                                                            if branchCondition then
                                                                Oh = bh.IsA
                                                                Oh = Oh(bh, "Model")
                                                                Ch = Oh
                                                            else
                                                            end
                                                            branchCondition = Ch
                                                            if branchCondition then
                                                                Ch = bh.FindFirstChild
                                                                Ch = Ch(bh, "HumanoidRootPart")
                                                                branchCondition = Ch
                                                                Yh = Ch
                                                                if branchCondition then
                                                                    Vh = Ch.IsA
                                                                    Vh = Vh(Ch, "BasePart")
                                                                    Yh = Vh
                                                                else
                                                                end
                                                                branchCondition = Yh
                                                                if branchCondition then
                                                                    Yh = Ch.Position
                                                                    K = Yh
                                                                    Vh = (s - K)
                                                                    Oh = Vh.Magnitude
                                                                    Uh = ("%s(%.1fs)").format
                                                                    n = Oh
                                                                    Uh = Uh("%s(%.1fs)", g, n)
                                                                    P = Uh
                                                                else
                                                                    Vh = (g .. "(PosN/A)")
                                                                    P = Vh
                                                                end
                                                            else
                                                                Ch = (g .. "(FPos/ModelN/A)")
                                                                P = Ch
                                                            end
                                                        end
                                                    else
                                                        jh = (g .. "(PlayerFPosN/A)")
                                                        P = jh
                                                    end
                                                    Ah = environment.table
                                                    bh = Ah.insert
                                                    lh = {
                                                        DisplayName = P,
                                                        Instance = T,
                                                        RawDistance = n,
                                                        Position = K,
                                                        IsFlying = vh,
                                                    }
                                                    Ah = bh(o, lh)
                                                else
                                                end
                                            else
                                            end
                                            break
                                        else
                                        end
                                        exitLoop1 = true
                                        break
                                    until true
                                    if exitLoop1 then
                                        break
                                    end
                                end
                                M = false
                                D = (# o)
                                T = captures[6].value
                                w = (# T)
                                I = (D ~= w)
                                branchCondition = I
                                if branchCondition then
                                    M = true
                                else
                                    w = environment.table
                                    D = w.sort
                                    T = bindClosure(processBlockTales4924877, {})
                                    w = D(o, T)
                                    D = {}
                                    w = environment.ipairs
                                    n = captures[6].value
                                    P = {w(n)}
                                    g = P[3]
                                    T = P[1]
                                    k = P[2]
                                    while true do
                                        local exitLoop2 = false
                                        repeat
                                            g, n = T(k, g)
                                            branchCondition = g
                                            if branchCondition then
                                                K = environment.table
                                                P = K.insert
                                                K = P(D, n)
                                                break
                                            else
                                            end
                                            exitLoop2 = true
                                            break
                                        until true
                                        if exitLoop2 then
                                            break
                                        end
                                    end
                                    T = environment.table
                                    w = T.sort
                                    k = bindClosure(processBlockTales15516991, {})
                                    T = w(D, k)
                                    T = (# o)
                                    k = T
                                    n = (1 < 0)
                                    T = 0
                                    while true do
                                        local exitLoop3 = false
                                        repeat
                                            P = (not n)
                                            T = (T + 1)
                                            w = (T <= k)
                                            w = (P and w)
                                            P = (T >= k)
                                            P = (n and P)
                                            w = (P or w)
                                            temporary = (w and 4459013)
                                            branchCondition = temporary
                                            if branchCondition then
                                                w = T
                                                bh = D[w]
                                                vh = (not bh)
                                                P = vh
                                                branchCondition = vh
                                                if branchCondition then
                                                else
                                                    Ah = o[w]
                                                    bh = Ah.Instance
                                                    lh = D[w]
                                                    Ah = lh.Instance
                                                    vh = (bh ~= Ah)
                                                    P = vh
                                                end
                                                branchCondition = P
                                                if branchCondition then
                                                    M = true
                                                else
                                                    bh = o[w]
                                                    vh = bh.DisplayName
                                                    Ah = D[w]
                                                    bh = Ah.DisplayName
                                                    K = (vh ~= bh)
                                                    branchCondition = K
                                                    if branchCondition then
                                                        M = true
                                                    else
                                                        Ah = o[w]
                                                        bh = Ah.IsFlying
                                                        lh = D[w]
                                                        Ah = lh.IsFlying
                                                        vh = (bh ~= Ah)
                                                        branchCondition = vh
                                                        if branchCondition then
                                                            M = true
                                                        else
                                                            break
                                                        end
                                                    end
                                                end
                                            else
                                            end
                                            exitLoop3 = true
                                            break
                                        until true
                                        if exitLoop3 then
                                            break
                                        end
                                    end
                                end
                                branchCondition = M
                                if branchCondition then
                                    D = o
                                    captures[6].value = D
                                    w = captures[12].value
                                    T = w()
                                else
                                end
                                resultValues = {}
                            end
                        end
                    end
                end
            end
        end
        return unpackValues(resultValues)
    end


    -- === Tex / Godmode ===

    applyMoveDamageSettings = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local D
        local H
        local I
        local K
        local M
        local P
        local Q
        local S
        local T
        local W
        local Z
        local c
        local d
        local e
        local g
        local h
        local i
        local jh
        local k
        local n
        local o
        local p
        local resultValues
        local s
        local t
        local temporary
        local u
        local vh
        local w
        local x
        local y
        local z
        e = argument1
        temporary = captures[1].value
        p = (e and "set to 0")
        c = (p or "restore original")
        d = ("Attempting to %s move damages...").format
        W = {d("Attempting to %s move damages...", c)}
        resultValues = temporary("GodmodeMoves", unpackValues(W))
        z = environment.string
        resultValues = z.split
        H = captures[2].value
        z = resultValues(H, ".")
        resultValues = environment.game
        H = resultValues
        W = true
        resultValues = environment.ipairs
        x = {resultValues(z)}
        d = x[2]
        c = x[1]
        p = x[3]
        while true do
            local exitLoop1 = false
            repeat
                p, S = c(d, p)
                branchCondition = p
                if branchCondition then
                    x = p
                    s = (x == 1)
                    resultValues = s
                    branchCondition = s
                    if branchCondition then
                        Q = environment.game
                        s = (H == Q)
                        resultValues = s
                    else
                    end
                    branchCondition = resultValues
                    if branchCondition then
                        resultValues = H[S]
                        H = resultValues
                    else
                        u = H.FindFirstChild
                        u = u(H, S)
                        H = u
                    end
                    s = (not H)
                    branchCondition = s
                    if branchCondition then
                        W = false
                    else
                        break
                    end
                else
                end
                exitLoop1 = true
                break
            until true
            if exitLoop1 then
                break
            end
        end
        branchCondition = W
        d = W
        if branchCondition then
            x = H
            branchCondition = H
            if branchCondition then
                Q = H.IsA
                Q = Q(H, "Folder")
                x = Q
            else
            end
            d = x
        else
        end
        c = (not d)
        branchCondition = c
        if branchCondition then
            c = captures[3].value
            Q = captures[2].value
            resultValues = {}
            i = ("Moves folder at '%s' not found. Cannot apply/restore damage attributes.").format
            S = {i("Moves folder at '%s' not found. Cannot apply/restore damage attributes.", Q)}
            d = c("GodmodeMoves", unpackValues(S))
        else
            c = captures[1].value
            Q = H.GetFullName
            Q = Q(H)
            i = environment.tostring
            Z = {i(e)}
            i = ("Processing moves in: %s. Godmode Enabling: %s").format
            S = {i("Processing moves in: %s. Godmode Enabling: %s", Q, unpackValues(Z))}
            Q = H.GetChildren
            d = c("GodmodeMoves", unpackValues(S))
            c = environment.ipairs
            S = {Q(H)}
            Q = {c(unpackValues(S))}
            d = Q[1]
            p = Q[2]
            x = Q[3]
            while true do
                local exitLoop2 = false
                repeat
                    x, S = d(p, x)
                    branchCondition = x
                    if branchCondition then
                        Q = S.IsA
                        Q = Q(S, "Folder")
                        branchCondition = Q
                        if branchCondition then
                            Q = S.Name
                            i = false
                            Z = environment.ipairs
                            D = captures[4].value
                            w = {Z(D)}
                            M = w[2]
                            I = w[3]
                            o = w[1]
                            while true do
                                local exitLoop3 = false
                                repeat
                                    I, D = o(M, I)
                                    branchCondition = I
                                    if branchCondition then
                                        w = (Q == D)
                                        branchCondition = w
                                        if branchCondition then
                                            i = true
                                        else
                                            break
                                        end
                                    else
                                    end
                                    exitLoop3 = true
                                    break
                                until true
                                if exitLoop3 then
                                    break
                                end
                            end
                            Z = (not i)
                            branchCondition = Z
                            if branchCondition then
                                branchCondition = e
                                if branchCondition then
                                    Z = S.GetAttribute
                                    Z = Z(S, "Damage")
                                    M = environment.type
                                    I = M(Z)
                                    o = (I == "number")
                                    branchCondition = o
                                    if branchCondition then
                                        I = captures[5].value
                                        M = I[S]
                                        o = (M == nil)
                                        branchCondition = o
                                        if branchCondition then
                                            M = Z
                                            o = captures[5].value
                                            o[S] = M
                                            o = captures[1].value
                                            k = environment.tostring
                                            g = {k(Z)}
                                            k = ("Stored original Damage for '%s': %s").format
                                            T = {k("Stored original Damage for '%s': %s", Q, unpackValues(g))}
                                            M = o("GodmodeMoves", unpackValues(T))
                                        else
                                        end
                                        o = (Z ~= 0)
                                        branchCondition = o
                                        if branchCondition then
                                            o = environment.pcall
                                            D = S.SetAttribute
                                            g = {o(D, S, "Damage", 0)}
                                            I = g[2]
                                            M = g[1]
                                            o = (not M)
                                            branchCondition = o
                                            if branchCondition then
                                                o = captures[3].value
                                                n = environment.tostring
                                                P = {n(I)}
                                                n = ("Error setting Damage to 0 for %s: %s").format
                                                g = {n("Error setting Damage to 0 for %s: %s", Q, unpackValues(P))}
                                                D = o("GodmodeMoves", unpackValues(g))
                                            else
                                            end
                                        else
                                        end
                                    else
                                    end
                                    o = S.GetAttribute
                                    o = o(S, "DMGTable")
                                    I = environment.type
                                    D = I(o)
                                    M = (D == "string")
                                    branchCondition = M
                                    if branchCondition then
                                        M = captures[1].value
                                        g = ("Found DMGTable string for '%s': %s").format
                                        k = {g("Found DMGTable string for '%s': %s", Q, o)}
                                        I = M("GodmodeMoves", unpackValues(k))
                                        D = captures[6].value
                                        I = D[S]
                                        M = (I == nil)
                                        branchCondition = M
                                        if branchCondition then
                                            M = captures[6].value
                                            I = o
                                            M[S] = I
                                            g = ("Stored original DMGTable string for '%s'").format
                                            M = captures[1].value
                                            k = {g("Stored original DMGTable string for '%s'", Q)}
                                            I = M("GodmodeMoves", unpackValues(k))
                                        else
                                        end
                                        M = 0
                                        I = o.gsub
                                        I = I(o, "[%[%] ]", "")
                                        branchCondition = I
                                        D = I
                                        if branchCondition then
                                            g = (# I)
                                            k = (g > 0)
                                            D = k
                                        else
                                        end
                                        branchCondition = D
                                        if branchCondition then
                                            n = I.gmatch
                                            n = {n(I, "[^,]+")}
                                            k = n[3]
                                            T = n[2]
                                            D = n[1]
                                            while true do
                                                local exitLoop4 = false
                                                repeat
                                                    k = D(T, k)
                                                    branchCondition = k
                                                    if branchCondition then
                                                        n = (M + 1)
                                                        M = n
                                                        break
                                                    else
                                                    end
                                                    exitLoop4 = true
                                                    break
                                                until true
                                                if exitLoop4 then
                                                    break
                                                end
                                            end
                                        else
                                        end
                                        D = (M > 0)
                                        branchCondition = D
                                        if branchCondition then
                                            D = {}
                                            k = M
                                            K = (1 < 0)
                                            g = 0
                                            while true do
                                                local exitLoop5 = false
                                                repeat
                                                    g = (g + 1)
                                                    T = (g <= k)
                                                    vh = (not K)
                                                    T = (vh and T)
                                                    vh = (g >= k)
                                                    vh = (K and vh)
                                                    T = (vh or T)
                                                    temporary = (T and 3018661)
                                                    branchCondition = temporary
                                                    if branchCondition then
                                                        h = environment.table
                                                        vh = h.insert
                                                        h = vh(D, 0)
                                                        break
                                                    else
                                                    end
                                                    exitLoop5 = true
                                                    break
                                                until true
                                                if exitLoop5 then
                                                    break
                                                end
                                            end
                                            K = environment.table
                                            P = K.concat
                                            K = P(D, ",")
                                            g = (K .. "]")
                                            T = ("[" .. g)
                                            h = ("SUCCESS: Setting DMGTable for '%s' to string: %s").format
                                            k = captures[1].value
                                            vh = {h("SUCCESS: Setting DMGTable for '%s' to string: %s", Q, T)}
                                            g = k("GodmodeMoves", unpackValues(vh))
                                            k = environment.pcall
                                            K = S.SetAttribute
                                            h = {k(K, S, "DMGTable", T)}
                                            P = h[2]
                                            g = h[1]
                                            k = (not g)
                                            branchCondition = k
                                            if branchCondition then
                                                k = captures[3].value
                                                y = environment.tostring
                                                jh = {y(P)}
                                                y = ("Error setting DMGTable string for %s: %s").format
                                                t = {y("Error setting DMGTable string for %s: %s", Q, unpackValues(jh))}
                                                K = k("GodmodeMoves", unpackValues(t))
                                            else
                                            end
                                        else
                                            D = captures[3].value
                                            K = ("Could not determine element count for DMGTable string on move '%s'").format
                                            P = {K("Could not determine element count for DMGTable string on move '%s'", Q)}
                                            T = D("GodmodeMoves", unpackValues(P))
                                        end
                                    else
                                    end
                                else
                                    M = captures[5].value
                                    o = M[S]
                                    Z = (o ~= nil)
                                    branchCondition = Z
                                    if branchCondition then
                                        o = captures[5].value
                                        Z = o[S]
                                        o = captures[1].value
                                        k = environment.tostring
                                        g = {k(Z)}
                                        k = ("Restoring Damage for '%s' to %s.").format
                                        T = {k("Restoring Damage for '%s' to %s.", Q, unpackValues(g))}
                                        M = o("GodmodeMoves", unpackValues(T))
                                        o = environment.pcall
                                        D = S.SetAttribute
                                        k = {o(D, S, "Damage", Z)}
                                        M = k[1]
                                        I = k[2]
                                        o = (not M)
                                        branchCondition = o
                                        if branchCondition then
                                            o = captures[3].value
                                            P = environment.tostring
                                            K = {P(I)}
                                            P = ("Error restoring Damage for %s: %s").format
                                            g = {P("Error restoring Damage for %s: %s", Q, unpackValues(K))}
                                            D = o("GodmodeMoves", unpackValues(g))
                                        else
                                        end
                                        o = captures[5].value
                                        o[S] = nil
                                    else
                                    end
                                    M = captures[6].value
                                    o = M[S]
                                    Z = (o ~= nil)
                                    branchCondition = Z
                                    if branchCondition then
                                        o = captures[6].value
                                        Z = o[S]
                                        o = captures[1].value
                                        k = ("Restoring DMGTable string for '%s' to '%s'").format
                                        T = {k("Restoring DMGTable string for '%s' to '%s'", Q, Z)}
                                        M = o("GodmodeMoves", unpackValues(T))
                                        o = environment.pcall
                                        D = S.SetAttribute
                                        k = {o(D, S, "DMGTable", Z)}
                                        M = k[1]
                                        I = k[2]
                                        o = (not M)
                                        branchCondition = o
                                        if branchCondition then
                                            o = captures[3].value
                                            P = environment.tostring
                                            K = {P(I)}
                                            P = ("Error restoring DMGTable for %s: %s").format
                                            g = {P("Error restoring DMGTable for %s: %s", Q, unpackValues(K))}
                                            D = o("GodmodeMoves", unpackValues(g))
                                        else
                                        end
                                        o = captures[6].value
                                        o[S] = nil
                                    else
                                    end
                                end
                            else
                            end
                        else
                        end
                        break
                    else
                    end
                    exitLoop2 = true
                    break
                until true
                if exitLoop2 then
                    break
                end
            end
            branchCondition = e
            if branchCondition then
                c = captures[1].value
                d = c("GodmodeMoves", "Finished processing moves for Godmode ON.")
            else
                c = captures[1].value
                d = c("GodmodeMoves", "Finished processing moves for Godmode OFF (restoration complete).")
            end
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processGodmodeMoves14882525 = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local e, resultValues, temporary
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = true
            resultValues = captures[2].value
            e = resultValues("GodmodeMoves", "Godmode ENABLED by toggle.")
            resultValues = captures[3].value
            e = resultValues(true)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    processGodmodeMoves15234720 = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local e, resultValues, temporary
        resultValues = captures[1].value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("GodmodeMoves", "Godmode DISABLED by toggle.")
            resultValues = captures[3].value
            e = resultValues(false)
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    setGodmodeMovesDamageEnabled = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local branchCondition
        local e, resultValues, temporary
        e = argument1
        branchCondition = e
        if branchCondition then
            temporary = environment.enableGodmode_Moves
            resultValues = temporary()
        else
            temporary = environment.disableGodmode_Moves
            resultValues = temporary()
        end
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Fishing ===

    setAutoFishEnabled = function(captures, argument1, argument2)
        local argumentValues = {argument1, argument2}
        local e, resultValues, temporary
        temporary = captures[1].value
        e = argument1
        resultValues = temporary(e)
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Speed Boost ===

    disableSpeedBoostLoop = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local branchCondition
        local H, W, c, e, resultValues, z
        z = captures[1].value
        e = (not z)
        resultValues = e
        branchCondition = e
        if branchCondition then
            W = captures[2].value
            branchCondition = W
            z = W
            if branchCondition then
                c = captures[2].value
                W = c.Connected
                z = W
            else
            end
            e = (not z)
            resultValues = e
        else
        end
        branchCondition = resultValues
        if branchCondition then
            resultValues = {}
        else
            captures[1].value = false
            resultValues = captures[3].value
            e = resultValues("[SpeedBoost] Disabling loop.")
            z = captures[2].value
            branchCondition = z
            resultValues = z
            if branchCondition then
                H = captures[2].value
                z = H.Connected
                resultValues = z
            else
            end
            branchCondition = resultValues
            if branchCondition then
                resultValues = captures[2].value
                e = resultValues.Disconnect
                e = e(resultValues)
            else
            end
            captures[2].value = nil
            resultValues = {}
        end
        return unpackValues(resultValues)
    end

    enableSpeedBoostLoop = function(captures, argument1)
        local argumentValues = {argument1}
        local branchCondition
        local H, W, c, d, e, resultValues, temporary, z
        e = captures[1].value
        resultValues = e
        branchCondition = e
        if branchCondition then
            H = captures[2].value
            e = H
            branchCondition = H
            if branchCondition then
                W = captures[2].value
                H = W.Connected
                e = H
            else
            end
            resultValues = e
        else
        end
        branchCondition = resultValues
        if branchCondition then
            resultValues = {}
        else
            resultValues = captures[3].value
            temporary = (resultValues <= 0)
            branchCondition = temporary
            if branchCondition then
                temporary = captures[4].value
                resultValues = temporary("[SpeedBoost] Multiplier is 0 or less, not starting loop.")
                temporary = environment.disableSpeedBoostLoop
                resultValues = temporary()
                resultValues = {}
            else
                captures[1].value = true
                resultValues = captures[4].value
                W = environment.tostring
                d = captures[3].value
                c = {W(d)}
                W = ("[SpeedBoost] Enabling CFrame boost with climbing WalkSpeed fallback. Multiplier: %s").format
                H = {W("[SpeedBoost] Enabling CFrame boost with climbing WalkSpeed fallback. Multiplier: %s", unpackValues(c))}
                e = resultValues(unpackValues(H))
                z = captures[2].value
                branchCondition = z
                resultValues = z
                if branchCondition then
                    H = captures[2].value
                    z = H.Connected
                    resultValues = z
                else
                end
                branchCondition = resultValues
                if branchCondition then
                    resultValues = captures[2].value
                    e = resultValues.Disconnect
                    e = e(resultValues)
                else
                end
                e = captures[5].value
                resultValues = e.Heartbeat
                z = bindClosure(updateSpeedBoostMovement, {captures[1], captures[3], captures[2], captures[6]})
                e = resultValues.Connect
                e = e(resultValues, z)
                resultValues = {}
                captures[2].value = e
            end
        end
        return unpackValues(resultValues)
    end

    updateSpeedBoostMovement = function(captures, dt)
        local enabled, multiplier = captures[1].value, captures[2].value
        if not enabled or multiplier <= 0 then
            local connection = captures[3].value
            if connection then connection:Disconnect() end
            captures[3].value, captures[1].value = nil, false
            owner.Movement:Stop("Tex")
            return
        end
        local ok, err = pcall(function() owner.Movement:TickTex(dt, multiplier) end)
        if not ok then
            owner.DependencyErrors.Speed = tostring(err)
            environment.disableSpeedBoostLoop()
            owner:Notify("Speed Boost", tostring(err))
        end
    end

    processBlockTales12404771 = function(captures, argument1, argument2, argument3)
        local argumentValues = {argument1, argument2, argument3}
        local e, resultValues, temporary
        temporary = captures[1].value
        e = captures[2].value
        resultValues = temporary.TranslateBy
        resultValues = resultValues(temporary, e)
        resultValues = {}
        return unpackValues(resultValues)
    end

    setSpeedBoost = function(captures, argument1, argument2, argument3, argument4, argument5, argument6)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5, argument6}
        local branchCondition
        local W, c, d, e, resultValues, temporary, z
        e = argument1
        temporary = e
        captures[1].value = temporary
        resultValues = captures[2].value
        c = environment.tostring
        d = {c(e)}
        c = ("[SpeedBoost] Slider changed. New multiplier: %s").format
        W = {c("[SpeedBoost] Slider changed. New multiplier: %s", unpackValues(d))}
        z = resultValues(unpackValues(W))
        resultValues = (e > 0)
        branchCondition = resultValues
        if branchCondition then
            z = captures[3].value
            resultValues = (not z)
            branchCondition = resultValues
            if branchCondition then
                resultValues = environment.enableSpeedBoostLoop
                z = resultValues()
            else
            end
        else
            resultValues = captures[3].value
            branchCondition = resultValues
            if branchCondition then
                resultValues = environment.disableSpeedBoostLoop
                z = resultValues()
            else
            end
        end
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Logging ===

    printDebug = function(captures, ...)
        local argumentValues = {...}
        local branchCondition
        local W, e, resultValues, temporary, z
        e = argumentValues[1]
        z = {selectValues(2, unpackValues(argumentValues))}
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            temporary = environment.print
            W = ("[%s]").format
            W = W("[%s]", e)
            resultValues = temporary(W, unpackValues(z))
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    printFeatureWarning = function(captures, ...)
        local argumentValues = {...}
        local W, e, resultValues, temporary, z
        z = {selectValues(2, unpackValues(argumentValues))}
        e = argumentValues[1]
        W = ("[%s] WARNING:").format
        temporary = environment.print
        W = W("[%s] WARNING:", e)
        resultValues = temporary(W, unpackValues(z))
        resultValues = {}
        return unpackValues(resultValues)
    end

    printNotificationDebug = function(captures, ...)
        local argumentValues = {...}
        local branchCondition
        local W, e, resultValues, temporary, z
        e = argumentValues[1]
        z = {selectValues(2, unpackValues(argumentValues))}
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            temporary = environment.print
            W = ("[%s]").format
            W = W("[%s]", e)
            resultValues = temporary(W, unpackValues(z))
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    showNotification = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local H, W, d, e, p, resultValues, temporary, z
        W = captures[1].value
        branchCondition = W
        z = argument2
        resultValues = W
        H = argument3
        e = argument1
        if branchCondition then
            d = captures[2].value
            branchCondition = d
            W = d
            if branchCondition then
                p = captures[2].value
                d = p.Notify
                W = d
            else
            end
            resultValues = W
        else
        end
        branchCondition = resultValues
        if branchCondition then
            temporary = captures[2].value
            W = {
                Title = e,
                Content = z,
                Duration = H,
                Image = 4483362458,
            }
            resultValues = temporary.Notify
            resultValues = resultValues(temporary, W)
        else
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    toggleDebugMessagesDevConsole = function(captures, argument1, argument2, argument3, argument4, argument5)
        local argumentValues = {argument1, argument2, argument3, argument4, argument5}
        local branchCondition
        local e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("Debug", "Messages Disabled.", 2)
        else
            captures[1].value = true
            e = captures[2].value
            z = e("Debug", "Messages Enabled.", 2)
        end
        resultValues = {}
        return unpackValues(resultValues)
    end

    toggleNotifications = function(captures)
        local argumentValues = {}
        local branchCondition
        local e, resultValues, temporary, z
        temporary = captures[1].value
        branchCondition = temporary
        if branchCondition then
            captures[1].value = false
            resultValues = captures[2].value
            e = resultValues("Notifications", "Disabled.", 2)
        else
            captures[1].value = true
            e = captures[2].value
            z = e("Notifications", "Enabled.", 2)
        end
        resultValues = {}
        return unpackValues(resultValues)
    end


    -- === Tex / Initialization ===

    initializeBlockTales = function(captures, ...)
        local argumentValues = {...}
        local branchCondition
        local Ah
        local Bh
        local CR
        local Ch
        local D
        local Dh
        local Eh
        local Fh
        local Gh
        local H
        local HR
        local Hh
        local I
        local Ih
        local Jh
        local K
        local Kh
        local LR
        local Lh
        local Mh
        local NR
        local Nh
        local OR
        local Oh
        local P
        local Ph
        local warningLogCell
        local Qh
        local RR
        local Rh
        local notificationDebugCell
        local Sh
        local T
        local Th
        local UR
        local Uh
        local VR
        local Vh
        local runServiceCell
        local WR
        local Wh
        local Xh
        local YR
        local Yh
        local windowCell
        local Zh
        local ah
        local bR
        local bh
        local virtualInputCell
        local ch
        local dh
        local eh
        local fh
        local g
        local gh
        local h
        local hh
        local rayfieldCell
        local ih
        local jR
        local jh
        local kh
        local lR
        local lh
        local mR
        local mh
        local n
        local nh
        local o
        local oh
        local localPlayerCell
        local ph
        local qR
        local qh
        local resultValues
        local rh
        local sh
        local t
        local temporary
        local th
        local debugLogCell
        local uh
        local vR
        local vh
        local w
        local wh
        local debugEnabledCell
        local xh
        local y
        local yh
        local workspaceCell
        local zR
        local zh
        local featureState = {}

        -- Services and shared logging
        temporary = environment.print
        resultValues = temporary("Block Tales | mxsynry - Initializing...")
        temporary = environment.game
        resultValues = temporary.GetService
        resultValues = resultValues(temporary, "Workspace")
        workspaceCell = {}
        workspaceCell.value = resultValues
        temporary = environment.game
        resultValues = temporary.GetService
        resultValues = resultValues(temporary, "Players")
        H = resultValues
        localPlayerCell = {}
        temporary = environment.game
        resultValues = temporary.GetService
        resultValues = resultValues(temporary, "RunService")
        runServiceCell = {}
        runServiceCell.value = resultValues
        temporary = environment.game
        resultValues = temporary.GetService
        resultValues = resultValues(temporary, "VirtualInputManager")
        virtualInputCell = {}
        virtualInputCell.value = resultValues
        temporary = environment.game
        resultValues = temporary.GetService
        resultValues = resultValues(temporary, "ReplicatedStorage")
        temporary = H.LocalPlayer
        localPlayerCell.value = temporary
        resultValues = localPlayerCell.value
        temporary = (not resultValues)
        branchCondition = temporary
        if branchCondition then
            temporary = environment.warn
            resultValues = temporary("FATAL: LocalPlayer not found. Script cannot run.")
            resultValues = {}
        else
            debugEnabledCell = {}
            debugEnabledCell.value = true
            notificationDebugCell = {}
            debugLogCell = {}
            notificationDebugCell.value = false
            temporary = bindClosure(printDebug, {debugEnabledCell})
            warningLogCell = {}
            debugLogCell.value = temporary
            temporary = bindClosure(printNotificationDebug, {notificationDebugCell})
            temporary = bindClosure(printFeatureWarning, {})
            warningLogCell.value = temporary
            temporary = debugLogCell.value
            resultValues = temporary("Core", "Attempting to load Rayfield UI Library...")
            rayfieldCell = {value = rayfieldUI}
            resultValues = rayfieldCell.value
            temporary = (not resultValues)
            branchCondition = temporary
            if branchCondition then
                temporary = warningLogCell.value
                resultValues = temporary("Core", "FATAL: Failed to load Rayfield UI Library. Script cannot continue.")
                resultValues = {}
            else
                Qh = {}
                featureState.slot39 = bindClosure(processBlockTales5668365, {virtualInputCell})
                Mh = {}
                Ch = {}
                Jh = {}
                temporary = debugLogCell.value
                featureState.slot7 = {}
                vh = {
                    Enabled = true,
                    FolderName = "Block Tales",
                    FileName = "BlockTalesRevamp",
                }
                featureState.slot51 = {}
                resultValues = temporary("Core", "Rayfield UI Library loaded.")
                jR = {}
                qh = {}
                temporary = rayfieldCell.value
                resultValues = temporary.CreateWindow
                featureState.slot9 = {}
                hh = {}
                t = {
                    Enabled = true,
                    Invite = "38gFBKePFj",
                    RememberJoins = true,
                }

                -- Project branding; keep the established Rayfield theme and saved settings.
                windowCell = {
                    Name = "Block Tales | mxsynry",
                    LoadingTitle = "Block Tales",
                    LoadingSubtitle = "mxsynry | TexRBLX | 7GrandDad",
                    Icon = 0,
                    Theme = "DarkBlue",
                    ConfigurationSaving = vh,
                    Discord = t,
                    DisableRayfieldPrompts = true,
                    KeySystem = false,
                }
                yh = {}
                featureState.slot57 = {}
                resultValues = resultValues(temporary, windowCell)
                windowCell = {}
                windowCell.value = resultValues
                oh = {}
                temporary = debugLogCell.value
                resultValues = temporary("UI", "Rayfield Window created.")
                rh = {}
                temporary = bindClosure(processBlockTales14674032, {})
                o = {}
                featureState.slot12 = {}
                Bh = {}
                bh = {}
                o.value = temporary
                temporary = bindClosure(processBlockTales7736830, {})
                featureState.slot54 = {}
                n = {}
                YR = bindClosure(processAutoSuperball15900876, {debugLogCell, virtualInputCell})
                featureState.slot8 = {}
                y = {}
                D = {}
                Xh = {}
                Ah = {}
                h = {}
                w = {}
                T = {}
                featureState.slot87 = {}
                I = {}
                I.value = true
                t = {}
                CR = {}
                Yh = {}
                D.value = false
                vR = {}
                w.value = 0
                dh = {}
                T.value = nil
                featureState.slot64 = {}
                temporary = localPlayerCell.value
                resultValues = temporary.WaitForChild
                resultValues = resultValues(temporary, "PlayerGui")
                K = {}
                Ih = {}
                featureState.slot61 = {}
                Vh = {}
                temporary = resultValues.WaitForChild
                temporary = temporary(resultValues, "HUD")
                Uh = {}
                resultValues = temporary.WaitForChild
                resultValues = resultValues(temporary, "Fishing")
                g = {}
                temporary = resultValues.WaitForChild
                temporary = temporary(resultValues, "DOITNOW")
                P = {}
                jh = {}
                resultValues = temporary.WaitForChild
                resultValues = resultValues(temporary, "Meter")
                zh = {}
                temporary = resultValues.WaitForChild
                featureState.slot66 = {}
                ph = {}
                Lh = {}
                Dh = {}
                temporary = temporary(resultValues, "Div")
                lh = {}
                vh = {}
                g.value = false
                n.value = nil
                featureState.slot5 = {}
                P.value = 0.05
                temporary = bindClosure(showNotification, {I, rayfieldCell})
                featureState.slot6 = {}
                K.value = temporary
                featureState.slot24 = {}
                featureState.slot58 = {}
                temporary = bindClosure(processBlockTales6434089, {g, K, runServiceCell, P, virtualInputCell, n})
                vh.value = temporary
                Nh = {}
                WR = {}
                temporary = bindClosure(enableSpeedBoostLoop, {D, T, w, debugLogCell, runServiceCell, localPlayerCell})
                environment.enableSpeedBoostLoop = temporary
                ch = {}
                temporary = bindClosure(disableSpeedBoostLoop, {D, T, debugLogCell})
                environment.disableSpeedBoostLoop = temporary
                Th = {}
                th = {}
                eh = {}
                h.value = "Superball"
                wh = {}
                t.value = "BattleDump"
                y.value = nil
                jh.value = nil
                Nh.value = nil
                Rh = {}
                Lh.value = nil
                bh.value = nil
                featureState.slot27 = {}
                temporary = bindClosure(processSuperballTracker2958784, {h, debugLogCell, y})
                Rh.value = temporary
                resultValues = bindClosure(processBlockTales14632010, {Yh, Uh, debugLogCell, lh})
                Oh = {}
                Eh = {}
                Hh = bindClosure(processAutoGuard10035586, {Yh, debugLogCell, Oh, workspaceCell, warningLogCell, windowCell, eh, Vh, Ah, runServiceCell, Uh})
                featureState.slot47 = {}
                temporary = bindClosure(processSuperballTracker4879227, {debugLogCell, workspaceCell, t, jh, h, y, Nh, Rh, warningLogCell, Lh, Ch, bh, runServiceCell})
                ih = {}
                featureState.slot2 = {}
                featureState.slot46 = {}
                Ch.value = temporary
                Yh.value = false
                Oh.value = 0.05
                featureState.slot82 = bindClosure(teleportToSelectedBUX, {featureState.slot58, K, localPlayerCell, warningLogCell})
                featureState.slot63 = {}
                Vh.value = nil
                temporary = {}
                Uh.value = temporary
                Ah.value = nil
                Wh = bindClosure(processAutoGuard16187736, {Yh, debugLogCell, Vh, Ah})
                lh.value = nil
                eh.value = nil
                qh.value = nil
                featureState.slot13 = {}
                zh.value = nil
                temporary = bindClosure(processAutoGuard5195988, {Yh, Uh, debugLogCell, Oh, warningLogCell, virtualInputCell, K})
                featureState.slot53 = {}
                featureState.slot4 = {}
                xh = bindClosure(processAutoSword7416568, {Bh, debugLogCell, virtualInputCell})
                lh.value = temporary
                eh.value = resultValues
                qh.value = Hh
                zh.value = Wh
                Jh.value = false
                featureState.slot52 = {}
                Xh.value = 0.2
                Eh.value = nil
                Bh.value = false
                ah = environment.Color3
                mh = ah.fromRGB
                ah = mh(255, 0, 0)
                mh = {}
                mh.value = ah
                fh = {}
                Fh = {}
                Gh = {}
                featureState.slot3 = {}
                kh = {}
                RR = {}
                Gh.value = false
                uh = bindClosure(processAutoSword653716, {Jh, Gh, Fh, debugLogCell, Xh, Eh, runServiceCell, ch})
                Fh.value = 0
                Sh = bindClosure(processAutoSword5439771, {Jh, Bh, rh, Gh, localPlayerCell, o, fh, mh, debugLogCell, Fh, Xh, K})
                mR = {}
                fh.value = nil
                rh.value = nil
                ch.value = nil
                dh.value = nil
                featureState.slot11 = {}
                sh = bindClosure(processAutoSword7693214, {Jh, debugLogCell, Eh, Bh, rh, Gh})
                featureState.slot50 = {}
                ph.value = nil
                featureState.slot25 = {}
                ah = bindClosure(processAutoSword7559693, {Bh, debugLogCell, virtualInputCell})
                featureState.slot69 = {}
                fh.value = ah
                rh.value = xh
                ch.value = Sh
                dh.value = uh
                featureState.slot15 = bindClosure(processAutoLauncher899218, {debugLogCell, virtualInputCell})
                ph.value = sh
                ih.value = Qh
                Zh = {}
                Zh.value = nil
                oh.value = false
                HR = {}
                gh = bindClosure(processArenaEnemies1989314, {Mh, ih, debugLogCell, Ih, Zh})
                Mh.value = nil
                Ih.value = nil
                Dh.value = 0.75
                lR = {}
                wh.value = nil
                LR = {}
                Th.value = false
                Qh = {}
                kh.value = Qh
                Qh = {}
                Qh.value = gh
                gh = {}
                bR = {}
                nh = bindClosure(updateArenaEnemies, {oh, localPlayerCell, workspaceCell, wh, debugLogCell, ih, Zh, Ih, kh, Th, Mh, Qh, warningLogCell})
                gh.value = nh
                nh = bindClosure(enableEnemyDropdownSystem, {oh, debugLogCell, localPlayerCell, gh, Dh})
                featureState.slot79 = bindClosure(teleportToSelectedCard, {featureState.slot53, K, localPlayerCell, warningLogCell})
                environment.enableEnemyDropdownSystem = nh
                nh = bindClosure(disableEnemyDropdownSystem, {oh, ih, Mh, Zh, Ih, wh, debugLogCell})
                qR = {}
                environment.disableEnemyDropdownSystem = nh
                Ph = bindClosure(processBlockTales11890825, {debugLogCell, kh, ih, warningLogCell, oh, gh})
                nh = {}
                nh.value = Ph
                Ph = bindClosure(enableForceGroundEnemies, {Th, nh, K})
                environment.enableForceGroundEnemies = Ph
                NR = {}
                Ph = bindClosure(disableForceGroundEnemies, {Th, nh, K})
                environment.disableForceGroundEnemies = Ph
                Kh = {}
                OR = bindClosure(processAutoSuperball5609324, {Kh, Zh, y, hh, jR, NR, debugLogCell, th, LR, vR, K})
                Kh.value = false
                UR = bindClosure(processAutoSuperball3201318, {Kh, debugLogCell, yh})
                hh.value = 10
                th.value = 0
                yh.value = nil
                featureState.slot60 = {}
                featureState.slot1 = {}
                jR.value = 0
                featureState.slot44 = {}
                NR.value = 1.5
                LR.value = nil
                vR.value = nil
                featureState.slot38 = {}
                bR.value = nil
                featureState.slot14 = {}
                RR.value = nil
                featureState.slot56 = {}
                featureState.slot36 = {}
                CR.value = nil
                VR = bindClosure(processAutoSuperball8660765, {Kh, debugLogCell, hh, th, yh, runServiceCell, bR})
                Ph = bindClosure(processAutoSuperball128144, {debugLogCell, virtualInputCell})
                LR.value = Ph
                vR.value = YR
                featureState.slot45 = {}
                bR.value = OR
                RR.value = VR
                featureState.slot86 = {}
                CR.value = UR
                lR.value = false
                featureState.slot37 = {}
                qR.value = 0.01
                HR.value = "Reticle"
                featureState.slot10 = {}
                WR.value = "Target"
                featureState.slot16 = bindClosure(processAutoLauncher11160503, {lR, mR, featureState.slot1, qR, featureState.slot6, debugLogCell, featureState.slot7, featureState.slot8, K})
                featureState.slot59 = {}
                featureState.slot48 = {}
                featureState.slot72 = {}
                mR.value = nil
                featureState.slot1.value = nil
                featureState.slot2.value = nil
                featureState.slot20 = bindClosure(processAutoLauncher11796690, {lR, debugLogCell, featureState.slot6, featureState.slot12, featureState.slot2, runServiceCell, featureState.slot9})
                featureState.slot3.value = nil
                featureState.slot4.value = nil
                featureState.slot19 = bindClosure(processAutoLauncher16687945, {debugLogCell, workspaceCell, t, featureState.slot3, HR, mR, WR, featureState.slot1, featureState.slot4, featureState.slot10, featureState.slot5, featureState.slot11, warningLogCell})
                featureState.slot5.value = nil
                featureState.slot6.value = false
                featureState.slot7.value = nil
                featureState.slot8.value = nil
                featureState.slot9.value = nil
                featureState.slot10.value = nil
                featureState.slot11.value = nil
                featureState.slot12.value = nil
                featureState.slot17 = bindClosure(processAutoLauncher5009002, {HR, debugLogCell, mR, WR, featureState.slot1})
                featureState.slot21 = bindClosure(processAutoLauncher608200, {lR, debugLogCell, featureState.slot2, featureState.slot4, featureState.slot5, featureState.slot6, featureState.slot8, mR, featureState.slot1})
                featureState.slot13.value = nil
                featureState.slot70 = {}
                featureState.slot14.value = nil
                zR = bindClosure(processAutoLauncher3731268, {debugLogCell, virtualInputCell})
                featureState.slot35 = {}
                featureState.slot7.value = zR
                featureState.slot8.value = featureState.slot15
                featureState.slot18 = bindClosure(processAutoLauncher9571879, {mR, debugLogCell, featureState.slot6, featureState.slot1})
                featureState.slot23 = {}
                featureState.slot9.value = featureState.slot16
                featureState.slot29 = bindClosure(processAutoLinebounce13440583, {featureState.slot23, debugLogCell, featureState.slot24, featureState.slot25})
                featureState.slot10.value = featureState.slot17
                featureState.slot11.value = featureState.slot18
                featureState.slot12.value = featureState.slot19
                featureState.slot13.value = featureState.slot20
                featureState.slot14.value = featureState.slot21
                featureState.slot23.value = false
                featureState.slot24.value = 0.2
                featureState.slot25.value = 5
                featureState.slot26 = {}
                featureState.slot26.value = false
                featureState.slot83 = bindClosure(processCollectibleTP16310991, {featureState.slot44, debugLogCell, localPlayerCell, featureState.slot63, featureState.slot66, featureState.slot69, featureState.slot46})
                featureState.slot28 = bindClosure(processAutoLinebounce16489682, {debugLogCell, featureState.slot23, Kh, featureState.slot24, featureState.slot25, LR, vR, warningLogCell, featureState.slot26})
                featureState.slot27.value = featureState.slot28
                featureState.slot67 = {}
                featureState.slot28 = bindClosure(processAutoLinebounce13925999, {featureState.slot23, debugLogCell, Kh, featureState.slot26, featureState.slot27})
                environment.enableAutoLinebounce = featureState.slot29
                featureState.slot29 = bindClosure(processAutoLinebounce2848273, {featureState.slot23, featureState.slot26, debugLogCell})
                featureState.slot22 = featureState.slot28
                environment.disableAutoLinebounce = featureState.slot29
                featureState.slot30 = {}
                featureState.slot30.value = false
                featureState.slot29 = {"PlayerGui", "HUD", "Battle", "DOITNOW3"}
                featureState.slot32 = {}
                featureState.slot34 = {}
                featureState.slot32.value = nil
                featureState.slot33 = {}
                featureState.slot33.value = 0.03
                featureState.slot88 = {}
                featureState.slot55 = {}
                featureState.slot34.value = nil
                featureState.slot35.value = nil
                featureState.slot36.value = nil
                featureState.slot41 = bindClosure(processAutoDynamite15368223, {featureState.slot30, debugLogCell, featureState.slot32, runServiceCell, featureState.slot36})
                featureState.slot42 = bindClosure(processAutoDynamite5778904, {featureState.slot30, debugLogCell, featureState.slot32})
                featureState.slot37.value = nil
                featureState.slot49 = {}
                featureState.slot38.value = nil
                featureState.slot40 = bindClosure(processBlockTales4881058, {featureState.slot30, localPlayerCell, o, featureState.slot34, featureState.slot33, featureState.slot35})
                featureState.slot31 = bindClosure(processBlockTales1552844, {virtualInputCell})
                featureState.slot34.value = featureState.slot31
                featureState.slot35.value = featureState.slot39
                featureState.slot36.value = featureState.slot40
                featureState.slot37.value = featureState.slot41
                featureState.slot38.value = featureState.slot42
                featureState.slot44.value = false
                featureState.slot45.value = nil
                featureState.slot46.value = 1.5
                featureState.slot81 = bindClosure(processBlockTales3152566, {featureState.slot59, featureState.slot57, debugLogCell, featureState.slot60, featureState.slot58})
                featureState.slot43 = {}
                featureState.slot62 = {}
                featureState.slot47.value = featureState.slot43
                featureState.slot48.value = nil
                featureState.slot49.value = nil
                featureState.slot50.value = nil
                featureState.slot51.value = 0
                featureState.slot43 = {}
                featureState.slot52.value = featureState.slot43
                featureState.slot77 = bindClosure(processBlockTales9403784, {featureState.slot44, featureState.slot62, featureState.slot45, featureState.slot52, featureState.slot56, featureState.slot67, o, K})
                featureState.slot53.value = nil
                featureState.slot54.value = nil
                featureState.slot55.value = nil
                featureState.slot56.value = 0
                featureState.slot43 = {}
                featureState.slot57.value = featureState.slot43
                featureState.slot58.value = nil
                featureState.slot59.value = nil
                featureState.slot84 = bindClosure(processCollectibleTP15879216, {featureState.slot44, debugLogCell, featureState.slot47, featureState.slot51, featureState.slot49, featureState.slot52, featureState.slot56, featureState.slot54, featureState.slot57, featureState.slot61, featureState.slot59, featureState.slot48, featureState.slot50, featureState.slot53, featureState.slot55, featureState.slot58, featureState.slot60, featureState.slot45})
                featureState.slot60.value = nil
                featureState.slot78 = bindClosure(processBlockTales7840511, {featureState.slot54, featureState.slot52, debugLogCell, featureState.slot55, featureState.slot53})
                featureState.slot76 = bindClosure(teleportToSelectedItem, {featureState.slot48, K, localPlayerCell, warningLogCell})
                featureState.slot61.value = 0
                featureState.slot62.value = nil
                featureState.slot63.value = nil
                featureState.slot64.value = nil
                featureState.slot66.value = nil
                featureState.slot67.value = nil
                featureState.slot69.value = nil
                featureState.slot70.value = nil
                featureState.slot80 = bindClosure(processBlockTales326220, {featureState.slot44, featureState.slot62, featureState.slot45, featureState.slot57, featureState.slot61, featureState.slot70, o, K})
                featureState.slot72.value = nil
                featureState.slot73 = environment.getgenv
                featureState.slot74 = featureState.slot73()
                featureState.slot74.TPBackToOriginal = false
                featureState.slot73 = bindClosure(processCollectibleTP14642422, {workspaceCell, featureState.slot45, debugLogCell, featureState.slot47, featureState.slot51, featureState.slot49, featureState.slot48, featureState.slot50, featureState.slot52, featureState.slot56, featureState.slot54, featureState.slot53, featureState.slot55, featureState.slot57, featureState.slot61, featureState.slot59, featureState.slot58, featureState.slot60, featureState.slot64, featureState.slot67, featureState.slot70})
                featureState.slot62.value = featureState.slot73
                featureState.slot74 = bindClosure(scanCollectibleCategory, {featureState.slot44, featureState.slot62, featureState.slot45, featureState.slot47, featureState.slot51, featureState.slot64, o, debugLogCell, K})
                featureState.slot43 = featureState.slot76
                featureState.slot63.value = featureState.slot74
                featureState.slot75 = bindClosure(processBlockTales14007330, {featureState.slot49, featureState.slot47, debugLogCell, featureState.slot50, featureState.slot48})
                featureState.slot68 = featureState.slot82
                featureState.slot64.value = featureState.slot75
                featureState.slot65 = featureState.slot79
                featureState.slot66.value = featureState.slot77
                featureState.slot67.value = featureState.slot78
                featureState.slot69.value = featureState.slot80
                featureState.slot71 = featureState.slot84
                featureState.slot70.value = featureState.slot81
                featureState.slot72.value = featureState.slot83
                featureState.slot86.value = false
                featureState.slot85 = {}
                featureState.slot87.value = featureState.slot85
                featureState.slot85 = {}
                featureState.slot88.value = featureState.slot85
                featureState.slot85 = {"Power Stab", "Launcher", "Sword", "Ball", "Sword Toss", "Linebounce", "Slingshot", "Daze", "Fireball", "Snowball", "Minimize", "Softener", "Cannonball", "Comatose", "Power Shot", "Rocket Boots", "Infect"}
                featureState.slot89 = {}
                featureState.slot90 = {}
                featureState.slot91 = bindClosure(applyMoveDamageSettings, {debugLogCell, featureState.slot90, warningLogCell, featureState.slot89, featureState.slot87, featureState.slot88})
                featureState.slot89.value = featureState.slot85
                featureState.slot90.value = "ReplicatedStorage.Moves"
                featureState.slot85 = {}
                featureState.slot85.value = featureState.slot91
                featureState.slot91 = bindClosure(processGodmodeMoves14882525, {featureState.slot86, debugLogCell, featureState.slot85})
                environment.enableGodmode_Moves = featureState.slot91
                featureState.slot91 = bindClosure(processGodmodeMoves15234720, {featureState.slot86, debugLogCell, featureState.slot85})
                environment.disableGodmode_Moves = featureState.slot91
                featureState.slot91 = windowCell.value

                -- Tex tab: Auto Actions
                featureState.slot92 = featureState.slot91.CreateTab
                featureState.slot92 = featureState.slot92(featureState.slot91, "Auto Actions")
                featureState.slot91 = (not featureState.slot92)
                branchCondition = featureState.slot91
                if branchCondition then
                    featureState.slot91 = warningLogCell.value
                    featureState.slot93 = featureState.slot91("UI", "FATAL: Failed to create Auto Actions Tab.")
                else
                    featureState.slot91 = debugLogCell.value
                    featureState.slot93 = featureState.slot91("UI", "Auto Actions Tab created.")
                    featureState.slot91 = featureState.slot92.CreateSection
                    featureState.slot91 = featureState.slot91(featureState.slot92, "Auto Guard")
                    featureState.slot103 = bindClosure(exclamationActionToggleV121, {K, qh, zh})
                    featureState.slot93 = featureState.slot91.Set
                    featureState.slot93 = featureState.slot93(featureState.slot91, "Auto Guard (Attachment Method)")
                    featureState.slot98 = Yh.value
                    featureState.slot94 = {
                        Name = "Auto Guard",
                        CurrentValue = featureState.slot98,
                        Flag = "ExclamationActionToggleV1_2_1",
                        SectionParent = featureState.slot91,
                        Callback = featureState.slot103,
                    }
                    featureState.slot93 = featureState.slot92.CreateToggle
                    featureState.slot93 = featureState.slot93(featureState.slot92, featureState.slot94)
                    branchCondition = featureState.slot93
                    if branchCondition then
                        featureState.slot94 = featureState.slot93.CurrentValue
                        Yh.value = featureState.slot94
                        featureState.slot95 = Yh.value
                        branchCondition = featureState.slot95
                        if branchCondition then
                            featureState.slot95 = qh.value
                            featureState.slot96 = featureState.slot95()
                        else
                        end
                    else
                        featureState.slot95 = warningLogCell.value
                        featureState.slot96 = featureState.slot95("UI", "Failed Exclamation Action toggle.")
                    end
                    featureState.slot95 = featureState.slot92.CreateSlider
                    featureState.slot100 = {0, 0.1}
                    featureState.slot106 = Oh.value
                    featureState.slot111 = bindClosure(setExclamationActionDelayV1_2_1, {Oh})
                    featureState.slot96 = {
                        Name = "Auto Guard Delay (seconds)",
                        Range = featureState.slot100,
                        Increment = 0.001,
                        Suffix = "s",
                        CurrentValue = featureState.slot106,
                        Flag = "ExclamationActionDelaySliderV1_2_1",
                        SectionParent = featureState.slot91,
                        Callback = featureState.slot111,
                    }
                    featureState.slot95 = featureState.slot95(featureState.slot92, featureState.slot96)
                    branchCondition = featureState.slot95
                    if branchCondition then
                        featureState.slot96 = featureState.slot95.CurrentValue
                        Oh.value = featureState.slot96
                    else
                        featureState.slot97 = warningLogCell.value
                        featureState.slot98 = featureState.slot97("UI", "Failed Auto Guard. Action Delay Slider.")
                    end
                    featureState.slot97 = featureState.slot92.CreateDivider
                    featureState.slot97 = featureState.slot97(featureState.slot92)
                    featureState.slot97 = featureState.slot92.CreateSection
                    featureState.slot97 = featureState.slot97(featureState.slot92, "Auto Sword Helper")
                    featureState.slot98 = featureState.slot97.Set
                    featureState.slot108 = bindClosure(setAutoSwordEnabled, {dh, ph})
                    featureState.slot98 = featureState.slot98(featureState.slot97, "Auto Sword")
                    featureState.slot103 = Jh.value
                    featureState.slot99 = {
                        Name = "Auto Sword",
                        CurrentValue = featureState.slot103,
                        Flag = "AutoSwordToggle",
                        SectionParent = featureState.slot97,
                        Callback = featureState.slot108,
                    }
                    featureState.slot98 = featureState.slot92.CreateToggle
                    featureState.slot98 = featureState.slot98(featureState.slot92, featureState.slot99)
                    branchCondition = featureState.slot98
                    if branchCondition then
                        featureState.slot99 = featureState.slot98.CurrentValue
                        Jh.value = featureState.slot99
                        featureState.slot100 = Jh.value
                        branchCondition = featureState.slot100
                        if branchCondition then
                            featureState.slot100 = dh.value
                            featureState.slot101 = featureState.slot100()
                        else
                        end
                    else
                        featureState.slot100 = warningLogCell.value
                        featureState.slot101 = featureState.slot100("UI", "Failed Auto Sword toggle.")
                    end
                    featureState.slot111 = Xh.value
                    featureState.slot100 = featureState.slot92.CreateSlider
                    featureState.slot105 = {0, 1}
                    featureState.slot116 = bindClosure(setAutoSwordReleaseDelay, {Xh})
                    featureState.slot101 = {
                        Name = "Sword Release Delay (seconds)",
                        Range = featureState.slot105,
                        Increment = 0.01,
                        Suffix = "s",
                        CurrentValue = featureState.slot111,
                        Flag = "AutoSwordReleaseDelaySlider",
                        SectionParent = featureState.slot97,
                        Callback = featureState.slot116,
                    }
                    featureState.slot100 = featureState.slot100(featureState.slot92, featureState.slot101)
                    branchCondition = featureState.slot100
                    if branchCondition then
                        featureState.slot101 = featureState.slot100.CurrentValue
                        Xh.value = featureState.slot101
                    else
                        featureState.slot102 = warningLogCell.value
                        featureState.slot103 = featureState.slot102("UI", "Failed Auto Sword Release Delay Slider.")
                    end
                end
                featureState.slot107 = bindClosure(setForceGroundEnemiesEnabled, {})
                featureState.slot100 = Th.value
                featureState.slot105 = environment.ArenaTargeterSection
                featureState.slot93 = {
                    Name = "Use Sword on Flying Enemies",
                    CurrentValue = featureState.slot100,
                    Flag = "ForceGroundEnemiesToggle",
                    SectionParent = featureState.slot105,
                    Callback = featureState.slot107,
                }
                featureState.slot91 = featureState.slot92.CreateToggle
                featureState.slot91 = featureState.slot91(featureState.slot92, featureState.slot93)
                branchCondition = featureState.slot91
                if branchCondition then
                    featureState.slot93 = debugLogCell.value
                    featureState.slot95 = featureState.slot93("UI", "Ground Flying Enemies Toggle created.")
                    featureState.slot93 = featureState.slot91.CurrentValue
                    Th.value = featureState.slot93
                    featureState.slot95 = Th.value
                    branchCondition = featureState.slot95
                    if branchCondition then
                        featureState.slot95 = environment.enableForceGroundEnemies
                        featureState.slot97 = featureState.slot95()
                    else
                    end
                else
                    featureState.slot95 = warningLogCell.value
                    featureState.slot97 = featureState.slot95("UI", "Failed to create Ground Flying Enemies Toggle.")
                end
                featureState.slot95 = featureState.slot92.CreateSection
                featureState.slot95 = featureState.slot95(featureState.slot92, "Auto Launcher")
                featureState.slot109 = bindClosure(setAutoLauncherEnabled, {featureState.slot13, featureState.slot14})
                featureState.slot97 = featureState.slot95.Set
                featureState.slot97 = featureState.slot97(featureState.slot95, "Auto Launcher")
                featureState.slot104 = lR.value
                featureState.slot98 = {
                    Name = "Enable Auto Launcher",
                    CurrentValue = featureState.slot104,
                    Flag = "AutoLauncherToggle",
                    SectionParent = featureState.slot95,
                    Callback = featureState.slot109,
                }
                featureState.slot97 = featureState.slot92.CreateToggle
                featureState.slot97 = featureState.slot97(featureState.slot92, featureState.slot98)
                branchCondition = featureState.slot97
                if branchCondition then
                    featureState.slot98 = debugLogCell.value
                    featureState.slot100 = featureState.slot98("UI", "Auto Launcher Toggle created.")
                    featureState.slot98 = featureState.slot97.CurrentValue
                    lR.value = featureState.slot98
                    featureState.slot100 = lR.value
                    branchCondition = featureState.slot100
                    if branchCondition then
                        featureState.slot100 = featureState.slot13.value
                        featureState.slot102 = featureState.slot100()
                    else
                    end
                else
                    featureState.slot100 = warningLogCell.value
                    featureState.slot102 = featureState.slot100("UI", "Failed Auto Launcher Toggle.")
                end
                featureState.slot100 = featureState.slot92.CreateSection
                featureState.slot100 = featureState.slot100(featureState.slot92, "Auto Dynamite/Slingshot")
                featureState.slot102 = featureState.slot100.Set
                featureState.slot102 = featureState.slot102(featureState.slot100, "Auto Dynamite/Slingshot")
                featureState.slot107 = featureState.slot30.value
                featureState.slot112 = bindClosure(setAutoDynamiteEnabled, {featureState.slot37, featureState.slot38})
                featureState.slot102 = featureState.slot92.CreateToggle
                featureState.slot103 = {
                    Name = "Enable Auto Dynamite/Slingshot",
                    CurrentValue = featureState.slot107,
                    Flag = "AutoDynamiteToggle",
                    SectionParent = featureState.slot100,
                    Callback = featureState.slot112,
                }
                featureState.slot102 = featureState.slot102(featureState.slot92, featureState.slot103)
                branchCondition = featureState.slot102
                if branchCondition then
                    featureState.slot103 = debugLogCell.value
                    featureState.slot104 = featureState.slot103("UI", "Auto Dynamite/Slingshot Toggle created.")
                    featureState.slot103 = featureState.slot102.CurrentValue
                    featureState.slot30.value = featureState.slot103
                    featureState.slot104 = featureState.slot30.value
                    branchCondition = featureState.slot104
                    if branchCondition then
                        featureState.slot104 = featureState.slot37.value
                        featureState.slot105 = featureState.slot104()
                    else
                    end
                else
                    featureState.slot104 = warningLogCell.value
                    featureState.slot105 = featureState.slot104("UI", "Failed to create Auto Dynamite/Slingshot Toggle.")
                end
                featureState.slot104 = windowCell.value

                -- Tex tab: Auto Superball
                featureState.slot105 = featureState.slot104.CreateTab
                featureState.slot105 = featureState.slot105(featureState.slot104, "Auto Superball")
                featureState.slot104 = (not featureState.slot105)
                branchCondition = featureState.slot104
                if branchCondition then
                    featureState.slot104 = warningLogCell.value
                    featureState.slot106 = featureState.slot104("UI", "FATAL: Failed to create Auto Superball Tab.")
                else
                    featureState.slot104 = debugLogCell.value
                    featureState.slot106 = featureState.slot104("UI", "Auto Superball Tab created.")
                    featureState.slot120 = bindClosure(selectArenaEnemyTarget, {Ih, Zh, ih, debugLogCell})
                    featureState.slot104 = featureState.slot105.CreateSection
                    featureState.slot104 = featureState.slot104(featureState.slot105, "Arena Enemy Targeter")
                    featureState.slot113 = {}
                    featureState.slot106 = featureState.slot104.Set
                    featureState.slot106 = featureState.slot106(featureState.slot104, "Arena Enemy Targeter")
                    featureState.slot111 = {"Scanning..."}
                    featureState.slot106 = featureState.slot105.CreateDropdown
                    featureState.slot107 = {
                        Name = "Target Enemy",
                        Options = featureState.slot111,
                        CurrentOption = featureState.slot113,
                        MultipleOptions = false,
                        Flag = "ArenaEnemyTargetDropdown",
                        SectionParent = featureState.slot104,
                        Callback = featureState.slot120,
                    }
                    featureState.slot106 = featureState.slot106(featureState.slot105, featureState.slot107)
                    Mh.value = featureState.slot106
                    featureState.slot107 = Mh.value
                    branchCondition = featureState.slot107
                    if branchCondition then
                        featureState.slot107 = debugLogCell.value
                        featureState.slot108 = featureState.slot107("UI", "Arena Enemy Dropdown created.")
                    else
                        featureState.slot107 = warningLogCell.value
                        featureState.slot108 = featureState.slot107("UI", "Failed Arena Enemy Dropdown.")
                    end
                    featureState.slot118 = bindClosure(setAutoSuperballEnabled, {K, RR, CR})
                    featureState.slot107 = featureState.slot105.CreateDivider
                    featureState.slot107 = featureState.slot107(featureState.slot105)
                    featureState.slot107 = featureState.slot105.CreateSection
                    featureState.slot107 = featureState.slot107(featureState.slot105, "Auto Superball Action")
                    featureState.slot108 = featureState.slot107.Set
                    featureState.slot108 = featureState.slot108(featureState.slot107, "Auto Superball Action")
                    featureState.slot113 = Kh.value
                    featureState.slot109 = {
                        Name = "Enable Auto Superball",
                        CurrentValue = featureState.slot113,
                        Flag = "AutoSuperballToggle",
                        SectionParent = featureState.slot107,
                        Callback = featureState.slot118,
                    }
                    featureState.slot108 = featureState.slot105.CreateToggle
                    featureState.slot108 = featureState.slot108(featureState.slot105, featureState.slot109)
                    branchCondition = featureState.slot108
                    if branchCondition then
                        featureState.slot109 = debugLogCell.value
                        featureState.slot110 = featureState.slot109("UI", "Auto Superball Toggle created.")
                        featureState.slot109 = featureState.slot108.CurrentValue
                        Kh.value = featureState.slot109
                        featureState.slot110 = Kh.value
                        branchCondition = featureState.slot110
                        if branchCondition then
                            featureState.slot110 = RR.value
                            featureState.slot111 = featureState.slot110()
                        else
                        end
                    else
                        featureState.slot110 = warningLogCell.value
                        featureState.slot111 = featureState.slot110("UI", "Failed Auto Superball Toggle.")
                    end
                    featureState.slot115 = {0, 50}
                    featureState.slot110 = featureState.slot105.CreateSlider
                    featureState.slot121 = hh.value
                    featureState.slot126 = bindClosure(setAutoSuperballDistance, {hh, debugLogCell})
                    featureState.slot111 = {
                        Name = "Activation Distance (studs)",
                        Range = featureState.slot115,
                        Increment = 1,
                        Suffix = " studs",
                        CurrentValue = featureState.slot121,
                        Flag = "AutoSuperballDistanceSlider",
                        SectionParent = featureState.slot107,
                        Callback = featureState.slot126,
                    }
                    featureState.slot110 = featureState.slot110(featureState.slot105, featureState.slot111)
                    branchCondition = featureState.slot110
                    if branchCondition then
                        featureState.slot111 = debugLogCell.value
                        featureState.slot112 = featureState.slot111("UI", "AutoSB Distance Slider created.")
                        featureState.slot111 = featureState.slot110.CurrentValue
                        hh.value = featureState.slot111
                    else
                        featureState.slot112 = warningLogCell.value
                        featureState.slot113 = featureState.slot112("UI", "Failed AutoSB Distance Slider.")
                    end
                end
                featureState.slot104 = featureState.slot105.CreateSection
                featureState.slot104 = featureState.slot104(featureState.slot105, "Auto Linebounce (after Superball)")
                featureState.slot107 = featureState.slot104.Set
                featureState.slot119 = bindClosure(setAutoLinebounceEnabled, {})
                featureState.slot107 = featureState.slot107(featureState.slot104, "Auto Linebounce (Requires Auto Superball ON)")
                featureState.slot107 = featureState.slot105.CreateToggle
                featureState.slot114 = featureState.slot23.value
                featureState.slot108 = {
                    Name = "Enable Auto Linebounce",
                    CurrentValue = featureState.slot114,
                    Flag = "AutoLinebounceToggle",
                    SectionParent = featureState.slot104,
                    Callback = featureState.slot119,
                }
                featureState.slot107 = featureState.slot107(featureState.slot105, featureState.slot108)
                branchCondition = featureState.slot107
                if branchCondition then
                    featureState.slot108 = featureState.slot107.CurrentValue
                    featureState.slot23.value = featureState.slot108
                    featureState.slot110 = featureState.slot23.value
                    branchCondition = featureState.slot110
                    if branchCondition then
                        featureState.slot110 = environment.enableAutoLinebounce
                        featureState.slot112 = featureState.slot110()
                    else
                    end
                else
                end
                featureState.slot127 = bindClosure(setLinebounceDelay, {featureState.slot24, debugLogCell})
                featureState.slot122 = featureState.slot24.value
                featureState.slot116 = {0.1, 1}
                featureState.slot110 = featureState.slot105.CreateSlider
                featureState.slot112 = {
                    Name = "Linebounce Delay/Interval (s)",
                    Range = featureState.slot116,
                    Increment = 0.05,
                    Suffix = "s",
                    CurrentValue = featureState.slot122,
                    Flag = "LinebounceDelaySlider",
                    SectionParent = featureState.slot104,
                    Callback = featureState.slot127,
                }
                featureState.slot110 = featureState.slot110(featureState.slot105, featureState.slot112)
                branchCondition = featureState.slot110
                if branchCondition then
                    featureState.slot112 = featureState.slot110.CurrentValue
                    featureState.slot24.value = featureState.slot112
                else
                end
                featureState.slot113 = windowCell.value

                -- Tex tab: Collectibles
                featureState.slot114 = featureState.slot113.CreateTab
                featureState.slot114 = featureState.slot114(featureState.slot113, "Collectibles")
                branchCondition = featureState.slot114
                if branchCondition then
                    featureState.slot113 = debugLogCell.value
                    featureState.slot120 = {"Scanning Items..."}
                    featureState.slot129 = bindClosure(selectCollectibleItemTP, {featureState.slot50, featureState.slot48, featureState.slot47, debugLogCell})
                    featureState.slot115 = featureState.slot113("UI", "Collectibles TP Tab created.")
                    featureState.slot122 = {}
                    featureState.slot113 = featureState.slot114.CreateSection
                    featureState.slot113 = featureState.slot113(featureState.slot114, "Item Teleporter")
                    featureState.slot115 = featureState.slot113.Set
                    featureState.slot115 = featureState.slot115(featureState.slot113, "Item Teleporter")
                    featureState.slot115 = featureState.slot114.CreateDropdown
                    featureState.slot116 = {
                        Name = "Select Item",
                        Options = featureState.slot120,
                        CurrentOption = featureState.slot122,
                        MultipleOptions = false,
                        Flag = "CollectibleItemTPDropdown",
                        SectionParent = featureState.slot113,
                        Callback = featureState.slot129,
                    }
                    featureState.slot115 = featureState.slot115(featureState.slot114, featureState.slot116)
                    featureState.slot49.value = featureState.slot115
                    featureState.slot116 = featureState.slot49.value
                    branchCondition = featureState.slot116
                    if branchCondition then
                        featureState.slot116 = debugLogCell.value
                        featureState.slot117 = featureState.slot116("UI", "Item Teleport Dropdown created.")
                    else
                        featureState.slot116 = warningLogCell.value
                        featureState.slot117 = featureState.slot116("UI", "Failed to create Item Teleport Dropdown.")
                    end
                    featureState.slot122 = {"Scanning Cards..."}
                    featureState.slot116 = featureState.slot114.CreateButton
                    featureState.slot117 = {
                        Name = "Teleport to Selected Item",
                        SectionParent = featureState.slot113,
                        Callback = featureState.slot43,
                    }
                    featureState.slot116 = featureState.slot116(featureState.slot114, featureState.slot117)
                    featureState.slot131 = bindClosure(selectCollectibleCardTP, {featureState.slot55, featureState.slot53, featureState.slot52, debugLogCell})
                    featureState.slot116 = featureState.slot114.CreateDivider
                    featureState.slot124 = {}
                    featureState.slot116 = featureState.slot116(featureState.slot114)
                    featureState.slot116 = featureState.slot114.CreateSection
                    featureState.slot116 = featureState.slot116(featureState.slot114, "Card Teleporter")
                    featureState.slot117 = featureState.slot116.Set
                    featureState.slot117 = featureState.slot117(featureState.slot116, "Card Teleporter")
                    featureState.slot118 = {
                        Name = "Select Card",
                        Options = featureState.slot122,
                        CurrentOption = featureState.slot124,
                        MultipleOptions = false,
                        Flag = "CollectibleCardTPDropdown",
                        SectionParent = featureState.slot116,
                        Callback = featureState.slot131,
                    }
                    featureState.slot117 = featureState.slot114.CreateDropdown
                    featureState.slot117 = featureState.slot117(featureState.slot114, featureState.slot118)
                    featureState.slot54.value = featureState.slot117
                    featureState.slot118 = featureState.slot54.value
                    branchCondition = featureState.slot118
                    if branchCondition then
                        featureState.slot118 = debugLogCell.value
                        featureState.slot119 = featureState.slot118("UI", "Card Teleport Dropdown created.")
                    else
                        featureState.slot118 = warningLogCell.value
                        featureState.slot119 = featureState.slot118("UI", "Failed to create Card Teleport Dropdown.")
                    end
                    featureState.slot118 = featureState.slot114.CreateButton
                    featureState.slot119 = {
                        Name = "Teleport to Selected Card",
                        SectionParent = featureState.slot116,
                        Callback = featureState.slot65,
                    }
                    featureState.slot126 = {}
                    featureState.slot118 = featureState.slot118(featureState.slot114, featureState.slot119)
                    featureState.slot133 = bindClosure(selectCollectibleBuxTP, {featureState.slot60, featureState.slot58, featureState.slot57, debugLogCell})
                    featureState.slot118 = featureState.slot114.CreateDivider
                    featureState.slot124 = {"Scanning BUX..."}
                    featureState.slot118 = featureState.slot118(featureState.slot114)
                    featureState.slot118 = featureState.slot114.CreateSection
                    featureState.slot118 = featureState.slot118(featureState.slot114, "BUX Teleporter")
                    featureState.slot119 = featureState.slot118.Set
                    featureState.slot119 = featureState.slot119(featureState.slot118, "BUX Teleporter")
                    featureState.slot120 = {
                        Name = "Select BUX",
                        Options = featureState.slot124,
                        CurrentOption = featureState.slot126,
                        MultipleOptions = false,
                        Flag = "CollectibleBuxTPDropdown",
                        SectionParent = featureState.slot118,
                        Callback = featureState.slot133,
                    }
                    featureState.slot119 = featureState.slot114.CreateDropdown
                    featureState.slot119 = featureState.slot119(featureState.slot114, featureState.slot120)
                    featureState.slot59.value = featureState.slot119
                    featureState.slot120 = featureState.slot59.value
                    branchCondition = featureState.slot120
                    if branchCondition then
                        featureState.slot120 = debugLogCell.value
                        featureState.slot121 = featureState.slot120("UI", "BUX Teleport Dropdown created.")
                    else
                        featureState.slot120 = warningLogCell.value
                        featureState.slot121 = featureState.slot120("UI", "Failed to create BUX Teleport Dropdown.")
                    end
                    featureState.slot121 = {
                        Name = "Teleport to Selected BUX",
                        SectionParent = featureState.slot118,
                        Callback = featureState.slot68,
                    }
                    featureState.slot120 = featureState.slot114.CreateButton
                    featureState.slot120 = featureState.slot120(featureState.slot114, featureState.slot121)
                else
                    featureState.slot113 = warningLogCell.value
                    featureState.slot116 = featureState.slot113("UI", "Failed to create Collectibles TP Tab.")
                end
                featureState.slot113 = featureState.slot114.CreateSection
                featureState.slot113 = featureState.slot113(featureState.slot114, "Teleport Settings")
                featureState.slot123 = environment.getgenv
                featureState.slot124 = featureState.slot123()
                featureState.slot122 = featureState.slot124.TPBackToOriginal
                featureState.slot126 = bindClosure(tPBack, {})
                featureState.slot129 = bindClosure(setGodmodeMovesDamageEnabled, {})
                featureState.slot116 = {
                    Name = "Teleport Back To Original Position",
                    CurrentValue = featureState.slot122,
                    Flag = "TPBack",
                    Callback = featureState.slot126,
                }
                featureState.slot113 = featureState.slot114.CreateToggle
                featureState.slot138 = bindClosure(setSpeedBoost, {w, debugLogCell, D})
                featureState.slot113 = featureState.slot113(featureState.slot114, featureState.slot116)
                featureState.slot113 = windowCell.value

                -- Tex tab: Misc
                featureState.slot116 = featureState.slot113.CreateTab
                featureState.slot116 = featureState.slot116(featureState.slot113, "Misc")
                featureState.slot113 = featureState.slot116.CreateSection
                featureState.slot113 = featureState.slot113(featureState.slot116, "General Mods")
                featureState.slot118 = featureState.slot116.CreateToggle
                featureState.slot124 = featureState.slot86.value
                featureState.slot120 = {
                    Name = "Invincibility (Godmode)",
                    CurrentValue = featureState.slot124,
                    Flag = "GodmodeMovesDamageToggle",
                    SectionParent = featureState.slot113,
                    Callback = featureState.slot129,
                }
                featureState.slot118 = featureState.slot118(featureState.slot116, featureState.slot120)
                featureState.slot131 = w.value
                featureState.slot125 = {0, 25}
                featureState.slot121 = {
                    Name = "Speed Boost",
                    Range = featureState.slot125,
                    Increment = 0.01,
                    Suffix = "x Multiplier",
                    CurrentValue = featureState.slot131,
                    Flag = "SpeedBoostSliderFlag_Main",
                    Tooltip = "Teleport-walk style speed. 0 = Off. Higher values = faster.",
                    SectionParent = featureState.slot113,
                    Callback = featureState.slot138,
                }
                featureState.slot120 = featureState.slot116.CreateSlider
                featureState.slot120 = featureState.slot120(featureState.slot116, featureState.slot121)
                featureState.slot123 = w.value
                featureState.slot122 = (featureState.slot123 > 0)
                featureState.slot120 = featureState.slot122
                branchCondition = featureState.slot122
                if branchCondition then
                    featureState.slot123 = D.value
                    featureState.slot122 = (not featureState.slot123)
                    featureState.slot120 = featureState.slot122
                else
                end
                branchCondition = featureState.slot120
                if branchCondition then
                    featureState.slot120 = environment.enableSpeedBoostLoop
                    featureState.slot121 = featureState.slot120()
                else
                end
                featureState.slot120 = featureState.slot116.CreateToggle
                featureState.slot130 = bindClosure(setAutoFishEnabled, {vh})
                featureState.slot121 = {
                    Name = "Auto Fish",
                    CurrentValue = false,
                    Flag = "AutoFishToggle",
                    SectionParent = featureState.slot113,
                    Callback = featureState.slot130,
                }
                featureState.slot120 = featureState.slot120(featureState.slot116, featureState.slot121)
                featureState.slot126 = bindClosure(toggleNotifications, {I, K})
                featureState.slot121 = {
                    Name = "Toggle Notifications",
                    SectionParent = featureState.slot113,
                    Callback = featureState.slot126,
                }
                featureState.slot126 = bindClosure(toggleDebugMessagesDevConsole, {debugEnabledCell, K})
                featureState.slot120 = featureState.slot116.CreateButton
                featureState.slot120 = featureState.slot120(featureState.slot116, featureState.slot121)
                featureState.slot120 = featureState.slot116.CreateButton
                featureState.slot121 = {
                    Name = "Toggle Debug Messages (Dev Console)",
                    SectionParent = featureState.slot113,
                    Callback = featureState.slot126,
                }
                featureState.slot126 = bindClosure(enablePremiumDonatorOnlyAnimationFlavors, {})
                featureState.slot120 = featureState.slot120(featureState.slot116, featureState.slot121)
                featureState.slot121 = {
                    Name = "Enable Premium & Donator only Animation Flavors",
                    SectionParent = featureState.slot113,
                    Callback = featureState.slot126,
                }
                featureState.slot120 = featureState.slot116.CreateButton
                featureState.slot120 = featureState.slot120(featureState.slot116, featureState.slot121)
                featureState.slot120 = environment.print
                featureState.slot121 = featureState.slot120("Standalone Script Initialized. UI should be available.")
                featureState.slot121 = environment.task
                resultValues = {}
                featureState.slot120 = featureState.slot121.spawn
                featureState.slot122 = bindClosure(processBlockTales6740426, {Ch, featureState.slot72})
                featureState.slot121 = featureState.slot120(featureState.slot122)
                featureState.slot120 = bindClosure(processBlockTales13201946, {debugLogCell, Yh, zh, Jh, ph, oh, Th, Nh, Lh, bh, Kh, CR, lR, featureState.slot14, featureState.slot30, featureState.slot38, featureState.slot23, D, g, vh, kh, featureState.slot85, windowCell, rayfieldCell})
                environment.UnloadScriptAndUI = featureState.slot120
                featureState.slot120 = rayfieldCell.value
                featureState.slot121 = featureState.slot120.LoadConfiguration
                featureState.slot121 = featureState.slot121(featureState.slot120)
            end
        end
        return unpackValues(resultValues)
    end

    initializeBlockTales({})
    CreateMxsynryControls(owner, controller)
    if owner.Vape then CreateVapeControls(owner.Vape, rayfieldUI) end
    return controller

end

-- === 8. Startup and public controls ===

function RT:LoadTex()
    if not self.Config.LoadTexScript then
        local pending = self.Tasks.Tex
        self.Tasks.Tex = nil
        if pending and pending.Thread and pending.Thread ~= coroutine.running() then
            pcall(task.cancel, pending.Thread)
        end
        if self.Tex then self.Tex:Unload(); self.Tex = nil end
        BT.TexScriptLoaded = false
        return
    end
    if self.Tex and self.Tex.Alive then return end
    if self.Tasks.Tex then return end
    if BT.TexScriptLoaded then BT.LegacyTexPresent = true end
    self:Spawn("Tex", function()
        local ok, result = pcall(CreateRecoveredTex, self)
        if not ok then
            if self.Tex then self.Tex:Unload(); self.Tex = nil end
            self.DependencyErrors.Tex = tostring(result)
            self:Notify("Block Tales UI", "initialization failed; core controls remain available")
        elseif self.Alive and self.Config.LoadTexScript and result.Alive then
            self.Tex = result
            BT.TexScriptLoaded = true
            self.DependencyErrors.Tex = nil
        else
            result:Unload()
        end
    end)
end
function RT:Unload(preserve)
    if not self.Alive then return end
    if self.Vape then self.Vape:Unload() end
    if self.Tex then self.Tex:Unload(); self.Tex = nil end
    if self.Movement then self.Movement:Stop() end
    self:Save()
    self.Alive = false
    self:StopAutoGreen()
    self:StopAutoGuardHook()
    self:StopGodmode()
    for scope in pairs(self.Scopes) do self:Clean(scope) end
    for _, ticket in pairs(self.Tasks) do
        if ticket.Thread and ticket.Thread ~= coroutine.running() then pcall(task.cancel, ticket.Thread) end
    end
    self.Tasks = {}
    ENV.AutoGreenEnabled, ENV.BlessedHookEnabled = false, false
    BT.AutoGreenConnection, BT.FakerMonitor = nil, nil
    for name, fn in pairs(self.Exports) do if ENV[name] == fn then ENV[name] = nil end end
    if BT.Runtime == self then BT.Runtime = nil end
    if not preserve then print("[Block Tales] Local features unloaded; saved settings retained.") end
end

local function export(name, fn) ENV[name], RT.Exports[name] = fn, fn end
for feature, method in pairs({Godmode = "ApplyGodmode", Blessed = "ApplyAutoGuardHook", AutoGreen = "ApplyAutoGreen"}) do
    local featureName, methodName = feature, method
    export("Toggle" .. featureName, function(state)
        if not RT.Alive then return false, "unloaded" end
        if state ~= nil and type(state) ~= "boolean" then return nil, "expected true, false, or no argument" end
        if state == nil then
            BT.UserSettings[featureName] = not BT.UserSettings[featureName]
        else
            BT.UserSettings[featureName] = state
        end
        if featureName == "AutoGreen" and BT.UserSettings.AutoGreen and RT.Vape and RT.Vape:IsEnabled("AutoAction") then
            RT.Vape:Set("AutoAction", false)
        end
        if featureName == "AutoGreen" and BT.UserSettings.AutoGreen and RT.Tex then
            RT.Tex:DisableInput()
        end
        if featureName == "Godmode" and BT.UserSettings.Godmode and RT.Tex then
            local texGodmode = RT.Tex.UI and RT.Tex.UI.Flags.GodmodeMovesDamageToggle
            if texGodmode and texGodmode.CurrentValue then texGodmode:Set(false) end
        end
        RT[methodName](RT, true)
        if RT.Tex then
            local flags = {Godmode = "CoreGodmodeToggle", Blessed = "BlessedHookToggle", AutoGreen = "CoreAutoGreenToggle"}
            RT.Tex:Set(flags[featureName], BT.UserSettings[featureName], true)
        end
        RT:Save()
        return BT.UserSettings[featureName]
    end)
end
export("ToggleAutoGuardHook", ENV.ToggleBlessed)
export("SetBlockTalesVapeFeature", function(name, enabled)
    return RT.Vape:Set(name, enabled)
end)
export("SetBlockTalesVapeOption", function(name, value)
    return RT.Vape:SetOption(name, value)
end)
export("SetAutoGreenMode", function(mode)
    if mode ~= "Legacy" and mode ~= "Battle" and mode ~= "Auto" then return nil, "expected Legacy, Battle, or Auto" end
    RT:StopAutoGreen()
    RT.Config.AutoGreenMode = mode
    if BT.UserSettings.AutoGreen and RT.Tex then RT.Tex:DisableInput() end
    RT:ApplyAutoGreen(true)
    if RT.Tex then RT.Tex:Set("CoreAutoGreenMode", {mode}, true) end
    RT:Save()
    return mode
end)
export("ConfigureBlockTales", function(options)
    if type(options) ~= "table" then return false, "expected a config table" end
    for k, value in pairs(options) do
        if DEFAULT_CONFIG[k] == nil or type(value) ~= type(DEFAULT_CONFIG[k]) then return false, "invalid option: " .. tostring(k) end
    end
    local rebuildMoves = options.GodmodeMoveAllowList ~= nil
    local resetMethod = options.BlessedMethod ~= nil
    local resetGreen = options.AutoGreenMode ~= nil
    if rebuildMoves then RT:StopGodmode() end
    if resetGreen then RT:StopAutoGreen() end
    if resetMethod then RT.BlessedObservedMethod = nil end
    for k, value in pairs(options) do RT.Config[k] = copy(value) end
    RT:Normalize()
    RT:ApplyAll(true)
    RT:LoadTex()
    RT:Save()
    return true
end)
export("GetBlockTalesStatus", function()
    local groups, layers = 0, 0
    for _, group in pairs(RT.HookGroups) do groups, layers = groups + 1, layers + #group.Layers end
    return {
        Alive = RT.Alive, Features = copy(RT.Features),
        Config = copy(RT.Config), UserSettings = copy(BT.UserSettings),
        Dependencies = copy(RT.DependencyErrors), SettingsSaved = RT.SettingsSaved,
        SettingsError = RT.SettingsError, HookGroups = groups, HookLayers = layers,
        BlessedMethod = RT.BlessedObservedMethod, LegacyHooksPresent = BT.LegacyHooksPresent == true,
        TexLoaded = RT.Tex and RT.Tex.Alive or false,
        TexSource = "local-recovered", Tex = RT.Tex and RT.Tex:GetStatus() or nil,
        LegacyTexPresent = BT.LegacyTexPresent == true,
        AutoGuardHook = copy(RT.Features.Blessed),
        Vape = RT.Vape and RT.Vape:GetStatus() or nil,
        Movement = RT.Movement and RT.Movement:GetStatus() or nil,
    }
end)
export("RefreshBlockTales", function()
    RT:StopAutoGreen()
    RT:StopAutoGuardHook()
    for _, name in ipairs({"Variables", "Ambassador"}) do
        for _, prefix in ipairs({"Resolve:", "Require:"}) do
            local key = prefix .. name
            local ticket = RT.Tasks[key]
            if ticket and ticket.Thread then pcall(task.cancel, ticket.Thread) end
            RT.Tasks[key] = nil
        end
        RT.Loading[name], RT[name] = nil, nil
    end
    RT.DependencyErrors = {}
    local moves = child(Services.ReplicatedStorage, "Moves")
    if RT.Moves ~= moves then RT:StopGodmode(); RT.Moves = moves end
    RT.BlessedObservedMethod = nil
    if RT.Vape then RT.Vape:Refresh() end
    RT:ApplyAll(true)
    RT:LoadTex()
    return ENV.GetBlockTalesStatus()
end)
export("SetBlockTalesTexControl", function(flag, value)
    if not RT.Alive or not RT.Tex then return false, "UI unavailable" end
    return RT.Tex:Set(flag, value)
end)
export("UnloadBlockTales", function() RT:Unload(false) end)

local function releaseOwnedInput()
    RT:ReleaseInput()
    RT.Action = nil
    if RT.Tex then RT.Tex:ReleaseInput() end
    if RT.Vape then RT.Vape:ReleaseFlyInput() end
end
local inputService = RT.Services.UserInputService
pcall(function() RT:Track("Main", "TextBoxFocused", inputService.TextBoxFocused:Connect(releaseOwnedInput)) end)
pcall(function()
    RT:Track("Main", "WindowFocusReleased", inputService.WindowFocusReleased:Connect(function()
        RT.WindowFocused = false
        releaseOwnedInput()
    end))
end)
pcall(function()
    RT:Track("Main", "WindowFocused", inputService.WindowFocused:Connect(function() RT.WindowFocused = true end))
end)
pcall(function() RT:Track("Main", "MenuOpened", RT.Services.GuiService.MenuOpened:Connect(releaseOwnedInput)) end)
if RT.Player then
    pcall(function() RT:Track("Main", "CharacterRemoving", RT.Player.CharacterRemoving:Connect(releaseOwnedInput)) end)
end


if RT.Player then
    pcall(function()
        RT:Track("Main", "CharacterAdded", RT.Player.CharacterAdded:Connect(function()
            if not RT.Alive then return end
            RT:ReleaseInput(); RT.Action, RT.BlessedObservedMethod = nil, nil
            RT:ApplyAll(false)
        end))
    end)
end
RT:ApplyAll(false)
RT.Vape:RestorePreferences()
RT:LoadTex()
RT:Save()
print("[Block Tales] Loaded. Mode: " .. RT.Config.AutoGreenMode)
for _, feature in ipairs({"Godmode", "Blessed", "AutoGreen"}) do
    local status = RT.Features[feature]
    local label = feature == "Blessed" and "AutoGuard (Hook)" or feature
    print("[Block Tales] " .. label .. ": " .. (BT.UserSettings[feature] and "ON" or "OFF")
        .. " (" .. status.State .. (status.Reason and ": " .. status.Reason or "") .. ")")
end
