-- Overture Basic
-- Targets the controller and fields recovered from the supplied Overture place.
-- Paste this entire file into your executor while inside Overture.
-- F4 / the OT button: show or hide. Unload: stop and remove the menu.
-- Local client controls; live server acceptance has not been verified.
-- Optional settings before execution: getgenv().OvertureBasicOptions = { ShowUI = false }
-- Settings automatically save to OvertureBasic.settings.json in the executor's
-- file sandbox. Saved values load first; the optional table above overrides them.
-- First-run / Conservative preset: gameplay overrides and the combo key are off.
-- Potions are opt-in: Water selected, base strength, one total effect by default.
-- Normal potion effects count toward the auto budget and are never removed.
-- Resolver: environments -> scoped callback/upvalue graph -> filtergc -> getgc.
-- Upvalue slots are discovered by identity, never fixed numeric offsets.
-- Overture stores resources on its captured controller table; setupvalue is not
-- needed to replace that shared table or to modify its numeric fields.
-- API: getgenv().OvertureBasic.InspectSkills() returns capture evidence/capabilities.
-- G / Cast all: queued class moves. NoStun suppresses hitstun and bypasses the
-- next-move entry lock on normal controls and the combo. MoveStacking enables
-- that entry bypass separately. Overture still has a single ActionState.
-- All-class combo mode rotates enabled native class choices and respawns
-- between them, waiting for a matching living controller before every kit.
-- Practice or ComboAllowClassResets permits this; normal lives still apply.
-- It leaves the final class active and stops on failed/mismatched spawns.
-- MaxBuffs enables both recovered upgrades for each beneficial potion and
-- maintains capped bonuses per copy. Optional stacking uses PotionStacks copies
-- per type with a positive, finite total budget. Both counts are capped at
-- 1,000; zero/unlimited is removed. The default is one effect, with automation
-- off. This is an input cap, not a ban-safe range. Potions are blatant.
-- These statuses do not have numeric levels. No preset guarantees ban avoidance.
-- SecretRequirements covers talent/resource gates plus recovered Sinner, Epik,
-- Sol and CCaz readiness checks. Other state/target/server checks are unverified.
-- UnlockAllCharacters adds loaded choices to the native and Classes menus.
-- Choosing uses ClassSelection.SelectConfirm and the native Update dispatch,
-- preserving its debounce, phase checks and chromashift slider. Preview,
-- chosen class, dispatched request and active controller are separate states.
-- InspectCharacterSelection() reports them. A live controller confirms active
-- gameplay; exposing a choice does not grant a permanent account unlock.
-- Players tab: select a teammate, inspect, then choose a native potion-hit
-- request or direct application to existing local gameplay data. Native
-- hits use eight-second, source-renewing statuses, one per selected type.
-- Players has an independent, saved effect profile. Direct mode does not need
-- your own character and survives your respawn; native hits need a living ally
-- source. A cosmetic animator is never promoted into a gameplay controller.
-- A stats/potion actor does not need skill/cooldown fields; capability reports
-- list only the data that exists. Unavailable components are never fabricated.
-- Recipient/server effects and account progression are not confirmed by either
-- method. Selection and active target modes are never restored from settings.
-- Legacy out-of-range potion counts disable automatic potions on migration.
-- Finite counts remain adjustable, including above eight; no ban-safe count is
-- established. The eight-addition work batch is unrelated to detection rules.
-- Class upgrades are temporary, until class reload. Respawn requests remain
-- subject to server rules; this script does not provide infinite server lives.
-- ForceRespawn runs the native DieBase teardown, releases the old controller,
-- and waits for a fresh living controller. RequestRespawn() keeps its dead-only
-- guard. A pending class choice is dispatched before a forced reset starts.
-- InspectRespawn() exposes progress; sending a request is not completion.
-- Menu controls use both native activation and a paired-click fallback. Tab
-- navigation and reopening stay available if a gameplay status refresh fails.
-- F4 also restores a hidden/disabled menu when the game consumes that key.
-- The owned menu lives in PlayerGui so callbacks do not need protected CoreGui
-- instance access. Native game UI and other scripts' permissions are untouched.
-- Classes separates browsing from choosing, includes account/hidden filters,
-- and offers an explicit choose-and-reset action subject to normal spawn rules.
-- Unsupported target actions stay disabled. No server bypass or ban-safe potion
-- values have been verified. Optional startup Players profile:
-- getgenv().OvertureBasicOptions = { PlayerSettings = { InfiniteStamina = true } }
-- World: KillAllNPCs / BringAllNPCs use normal hit and source-relative knockback
-- requests. They recheck player exclusion at dispatch and report observations,
-- never local fake health/position changes. NPCDamage respects the recovered
-- client clamp of 800. AutoWinRound clears enemies; the server decides victory.
-- SkipRound uses the zero-argument VoteSkip request; one recorded vote per
-- observed phase. There is no discovered forced-win or forced-skip handler.
-- References: https://docs.sunc.io/Debug/getupvalues/
-- https://docs.sunc.io/Environment/filtergc/
-- https://robloxapi.github.io/ref/class/RunService.html

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
assert(player, "Overture Basic must run on the client.")

local shared = type(getgenv) == "function" and getgenv() or _G
local previous = shared.OvertureBasic
if type(previous) == "table" and type(previous.Unload) == "function" then
    previous.Unload()
end

local defaults = {
    InfiniteStamina = false,
    InfiniteCharges = false,
    NoCooldown = false,
    NoStun = false,
    MoveStacking = false,
    ComboEnabled = false,
    ComboAllClasses = false,
    ComboAllowClassResets = false,
    ComboKey = "G",
    ComboDelay = 0.25,
    ComboWaitTimeout = 6,
    IncludeDash = false,
    AttributeBuffs = false,
    PotionBuffs = false,
    MaxBuffs = false,
    StackPotions = false,
    PotionStacks = 1,
    PotionLimit = 1,
    PotionWater = true,
    PotionCrystal = false,
    PotionEarth = false,
    PotionWind = false,
    PotionBlood = false,
    SecretRequirements = false,
    UnlockAllCharacters = false,
    AutoRespawn = false,
    SpeedEnabled = false,
    WalkSpeed = 18,
    NoCameraShake = false,
    EnemyESP = false,
    AutoWinRound = false,
    NPCIncludeAllies = false,
    NPCDamage = 800,
    NPCRetries = 8,
    ShowUI = true,
}
local settings = table.clone(defaults)
local playerDefaults = {}
for _, key in ipairs({ "InfiniteStamina", "InfiniteCharges", "NoCooldown", "NoStun", "MoveStacking",
    "SecretRequirements", "AttributeBuffs", "PotionBuffs", "MaxBuffs", "StackPotions", "PotionStacks",
    "PotionLimit", "PotionWater", "PotionCrystal", "PotionEarth", "PotionWind", "PotionBlood",
    "SpeedEnabled", "WalkSpeed" }) do playerDefaults[key] = defaults[key] end
local playerSettings = table.clone(playerDefaults)
local maxPotionCount = 1000
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function potionCount(value)
    return finite(value) and value >= 1 and math.min(maxPotionCount, math.floor(value)) or 1
end
local function migratePotionBounds(values, original)
    if type(original) ~= "table" then return false end
    local limit, stacks = original.PotionLimit, original.PotionStacks
    local invalidLimit = type(limit) == "number" and (not finite(limit) or limit < 1 or limit > maxPotionCount)
    local invalidStacks = type(stacks) == "number" and (not finite(stacks) or stacks < 1 or stacks > maxPotionCount)
    if not invalidLimit and not invalidStacks then return false end
    values.PotionBuffs = false; values.StackPotions = false
    values.PotionLimit = potionCount(limit or values.PotionLimit)
    values.PotionStacks = potionCount(stacks or values.PotionStacks)
    return true
end
local function validateSetting(key, value)
    local expected = defaults[key]
    if expected == nil or type(value) ~= type(expected) then return nil end
    if type(value) == "number" and not finite(value) then return nil end
    if key == "WalkSpeed" then return math.clamp(value, 8, 80)
    elseif key == "NPCDamage" then return math.clamp(math.floor(value), 1, 800)
    elseif key == "NPCRetries" then return math.clamp(math.floor(value), 1, 30)
    elseif key == "PotionStacks" then return math.clamp(math.floor(value), 1, maxPotionCount)
    elseif key == "PotionLimit" then return value >= 1 and math.min(maxPotionCount, math.floor(value)) or nil
    elseif key == "ComboDelay" then return math.clamp(value, 0.03, 1)
    elseif key == "ComboWaitTimeout" then return math.clamp(value, 1, 20)
    elseif key == "ComboKey" then
        local ok, code = pcall(function() return Enum.KeyCode[value] end)
        if not ok or not code or value == "Unknown" or value == "F4" then return nil end
    end
    return value
end
local function mergeSettings(target, values)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do
        local validated = validateSetting(key, value)
        if validated ~= nil then target[key] = validated end
    end
end
local function mergePlayerSettings(target, values)
    if type(values) ~= "table" then return end
    for key, value in pairs(values) do
        if playerDefaults[key] ~= nil then
            local validated = validateSetting(key, value)
            if validated ~= nil then target[key] = validated end
        end
    end
end

-- JSON data only: no loadfile/loadstring and no game objects or callbacks saved.
local config = {
    Path = "OvertureBasic.settings.json", Version = 1,
    Readable = type(readfile) == "function", Writable = type(writefile) == "function",
    Loaded = false, Dirty = false, Status = "Conservative defaults", SaveCount = 0,
}
local saveDue
local function readSettings()
    if not config.Readable then return nil, "readfile unavailable" end
    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, config.Path)
        if not ok then return nil, "Could not check settings file" end
        if not exists then return nil, "No saved settings", true end
    end
    local ok, bytes = pcall(readfile, config.Path)
    if not ok or type(bytes) ~= "string" then return nil, "Could not read settings" end
    if #bytes > 65536 then return nil, "Settings file is too large" end
    local decodedOK, data = pcall(HttpService.JSONDecode, HttpService, bytes)
    if not decodedOK or type(data) ~= "table" or data.Format ~= "OvertureBasic"
        or data.Version ~= config.Version or type(data.Settings) ~= "table" then
        return nil, "Invalid or unsupported settings file"
    end
    local values = table.clone(defaults)
    mergeSettings(values, data.Settings)
    local migrated = migratePotionBounds(values, data.Settings)
    if not values.PotionBuffs then values.StackPotions = false end
    local targetValues = table.clone(playerDefaults)
    mergePlayerSettings(targetValues, data.PlayerSettings)
    local targetMigrated = migratePotionBounds(targetValues, data.PlayerSettings)
    if not targetValues.PotionBuffs then targetValues.StackPotions = false end
    return values, nil, nil, migrated or targetMigrated, targetValues
end
do
    local loaded, message, missing, migrated, targetValues = readSettings()
    if loaded then
        mergeSettings(settings, loaded); mergePlayerSettings(playerSettings, targetValues)
        config.Loaded = true; config.Status = "Saved settings loaded"
        if migrated then
            config.PotionNotice = "Saved potion counts adjusted to 1-1,000; automatic potions were disabled."
            config.Dirty = true; saveDue = 0
        end
    elseif config.Readable and config.Writable then
        config.Status = message
        if not missing then config.LastError = message end
        if missing then config.Dirty = true; saveDue = 0 end
    else
        config.Status = "Session only: executor file support unavailable"
    end
end
local supplied = shared.OvertureBasicOptions
mergeSettings(settings, supplied)
if migratePotionBounds(settings, supplied) then
    config.PotionNotice = "Startup potion counts adjusted to 1-1,000; automatic potions were disabled."
    config.Dirty = true; saveDue = 0
end
if type(supplied) == "table" then
    -- Explicit startup values override the saved file and become the next save.
    for key in pairs(supplied) do
        if defaults[key] ~= nil and validateSetting(key, supplied[key]) ~= nil then config.Dirty = true; saveDue = 0; break end
    end
end
if type(supplied) == "table" and supplied.PotionBuffs == false then
    settings.StackPotions = false
elseif settings.StackPotions then settings.PotionBuffs = true end
if type(supplied) == "table" and type(supplied.PlayerSettings) == "table" then
    mergePlayerSettings(playerSettings, supplied.PlayerSettings)
    if migratePotionBounds(playerSettings, supplied.PlayerSettings) then
        config.PotionNotice = "Target potion counts adjusted to 1-1,000; automatic potions were disabled."
    end
    if supplied.PlayerSettings.PotionBuffs == false then playerSettings.StackPotions = false
    elseif playerSettings.StackPotions then playerSettings.PotionBuffs = true end
    config.Dirty = true; saveDue = 0
end

local api = { Running = true, Settings = settings, Defaults = table.clone(defaults),
    PlayerSettings = playerSettings, PlayerDefaults = table.clone(playerDefaults),
    PotionMaximum = maxPotionCount,
    Config = config, Status = "Looking for Overture..." }
if config.PotionNotice then api.ActionMessage = config.PotionNotice; api.ActionMessageTime = os.clock() end
shared.OvertureBasic = api
local connections, overrides, highlights = {}, {}, {}
local root, controller, binding, screen, highlightFolder
local updateMenu = function() end
local lastSearch, lastGC, lastUI, lastESP, lastWarning = -math.huge, -math.huge, 0, 0, -math.huge
local accessMethod = ""
local actorProof
local comboToken, comboBusy, lastRespawnRequest = 0, false, -math.huge
local comboFlow = { Transition = false }
local worldFlow = { Pending = nil, NextHit = 0, NextScan = 0, NextAuto = 0, Epoch = 0,
    Audit = setmetatable({}, { __mode = "k" }), Stage = "Idle" }
local deathObserved, characterRemovedAt = false, nil
local respawnFlow = { Pending = nil, AutoAttempted = false }
local capturingComboKey = false
local toggleMenuHotkey = function() end
local buffRecords, statTargets, buffFailures = {}, {}, {}
local buffSequence = 0
local potionWork = {}
local moveRecords, nativeRoster = {}, nil
local classFlow = {}
local maintainMoves = function() end
local maintainRequirements = function() end
local requirementRecords = {}
local targetSupport = { Active = nil, Selected = nil, Cache = {}, Reservations = setmetatable({}, { __mode = "k" }), NextHit = 0 }
local function actorSettings(actor)
    local active = targetSupport.Active
    return active and active.Active and active.Actor == actor and playerSettings or settings
end
local maintainRoster = function() end
local lastRosterUpdate, lastClassRequest = -math.huge, -math.huge
local statKey = {} -- a separate modifier entry; never overwrite a class modifier
-- Modifier caps recovered from the actual status modules, not arbitrary boosts.
-- Defense is damage taken (lower is better); StunTimeMultiplier is resistance.
local attributeSpecs = {
    Power = { 4, 4.4 }, Defense = { 4, 0.5, "lower" }, Speed = { 4, 3.15 },
    HealingMultiplier = { 4, 1.5 }, CooldownRate = { 4, 1.5 },
    KnockbackMultiplier = { 4, 0, "lower" }, StunTimeMultiplier = { 4, 4 },
    HealthRegen = { 3, 6.25 },
}
local potionSpecs = {
    { "SubjectWater", 2, 1, { "Talent3", "Talent4" }, "PotionWater" },
    { "SubjectCrystal", 3, 50, { "Talent5", "Talent6" }, "PotionCrystal" },
    { "SubjectEarth", 4, 1, { "Talent7", "Talent8" }, "PotionEarth" },
    { "SubjectWind", 5, 1, { "Talent9", "Talent10" }, "PotionWind" },
    { "SubjectBlood", 6, 1, { "Talent11", "Talent12" }, "PotionBlood" },
}
local debugAPI = type(debug) == "table" and debug or {}
api.Capabilities = {
    Environments = type(getsenv) == "function" or type(getrenv) == "function",
    Upvalues = type(debugAPI.getupvalues) == "function" or type(debugAPI.getupvalue) == "function",
    FilterGC = type(filtergc) == "function",
    Connections = type(getconnections) == "function",
    GC = type(getgc) == "function",
}
api.Discovery = { Route = "pending", FunctionsInspected = 0, Ambiguous = false }
api.BuffProfile = {
    Kind = "Both potion upgrades plus capped conditional bonuses",
    Wiki = "https://overture.miraheze.org/wiki/Subject",
    VerifiedWikiRows = { "Atlantic Dust", "Inverted Rainwater", "Tempest Cloud" },
    NumericSource = "Subject status modules in the supplied place; full wiki fetch blocked",
    Caps = { WaterRegen = 6.25, HealingMultiplier = 1.5, CrystalShield = 50,
        DefenseMultiplier = 0.5, WindSpeedMultiplier = 3.15,
        CooldownRate = 1.5, BloodPowerMultiplier = 4.4, StunResistance = 4 },
}
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
local function report(err)
    api.LastError = tostring(err)
    if os.clock() - lastWarning >= 10 then
        lastWarning = os.clock()
        warn("[Overture Basic] " .. tostring(err))
    end
end

-- Only persistent preferences are restored. Resource consumption resumes when disabled.
local function override(target, key, value)
    local records = overrides[target]
    if not records then records = {}; overrides[target] = records end
    local record = records[key]
    local current = rawget(target, key)
    if not record then
        record = { Before = current }; records[key] = record
    elseif current ~= record.Last then
        record.Before = current
    end
    record.Last = value
    rawset(target, key, value)
end
local function release(target, key)
    local records = overrides[target]
    local record = records and records[key]
    if not record then return end
    if rawget(target, key) == record.Last then rawset(target, key, record.Before) end
    records[key] = nil
    if not next(records) then overrides[target] = nil end
end

local function clearStatBuffs(actor)
    local targets = statTargets[actor]
    if not targets then return end
    for target in pairs(targets) do release(target, statKey) end
    statTargets[actor] = nil
end
local function removeOwnedPotion(actor, status, entry, statuses)
    if entry.Owned and type(statuses) == "table" and rawget(statuses, entry.Id) == status then
        local ok, err = pcall(function()
            if type(status.Die) == "function" then status:Die(actor) end
        end)
        if not ok then report(err) end
        if rawget(statuses, entry.Id) == status then statuses[entry.Id] = nil end
    end
end
local function clearPotionBuffs(actor)
    buffFailures[actor] = nil
    potionWork[actor] = nil
    local records = buffRecords[actor]
    if not records then return end
    local statuses = rawget(actor, "Status")
    for status, entry in pairs(records) do
        removeOwnedPotion(actor, status, entry, statuses)
    end
    buffRecords[actor] = nil
end
local function setStatusModifier(actor, status, statName, field, amount, slot)
    local stat = type(actor.Stats) == "table" and rawget(actor.Stats, statName)
    local modifiers = type(stat) == "table" and rawget(stat, slot or 4)
    local index = rawget(status, field)
    if type(modifiers) == "table" and index ~= nil and finite(rawget(modifiers, index)) then
        modifiers[index] = amount
    end
end
local function maintainMaxPotion(actor, status)
    local name = status.Name
    if name == "SubjectWater" then
        setStatusModifier(actor, status, "HealthRegen", "StatMod", 6.25, 3)
    elseif name == "SubjectCrystal" then
        local shield = type(actor.Shields) == "table" and rawget(actor.Shields, status.Shield)
        if type(shield) == "table" and finite(shield.Amount) then shield.Amount = math.max(shield.Amount, 50) end
    elseif name == "SubjectWind" then
        status.StillBonus = 0.75; status.MoveBonus = 1
        setStatusModifier(actor, status, "Speed", "StatMod", 3.15)
    elseif name == "SubjectBlood" then
        setStatusModifier(actor, status, "Power", "StatMod", 4.4)
    end
end
local function attributeAmount(modifiers, spec)
    local others = spec[1] == 3 and 0 or 1
    for key, value in pairs(modifiers) do
        if key ~= statKey and finite(value) then
            others = spec[1] == 3 and (others + value) or (others * value)
        end
    end
    if spec[1] == 3 then return math.max(0, spec[2] - others) end
    if not finite(others) or others <= 0 then return 1 end
    local needed = spec[2] / others
    return spec[3] == "lower" and math.min(1, needed) or math.max(1, needed)
end
local function maintainBuffs(actor)
    local settings = actorSettings(actor)
    if actor.Dead then return end
    if settings.AttributeBuffs and type(actor.Stats) == "table" then
        local targets = statTargets[actor] or {}; statTargets[actor] = targets
        local keep = {}
        for name, spec in pairs(attributeSpecs) do
            local stat = rawget(actor.Stats, name)
            local modifiers = type(stat) == "table" and rawget(stat, spec[1])
            if type(modifiers) == "table" then
                keep[modifiers] = true; targets[modifiers] = true
                -- Fill the gap to the same potion cap. Do not multiply a potion's
                -- existing full bonus by another arbitrary attribute boost.
                override(modifiers, statKey, attributeAmount(modifiers, spec))
            end
        end
        for target in pairs(targets) do
            if not keep[target] then release(target, statKey); targets[target] = nil end
        end
    else
        clearStatBuffs(actor)
    end
    if not settings.PotionBuffs then clearPotionBuffs(actor); return end
    local statuses = rawget(actor, "Status")
    if type(statuses) ~= "table" or not root or type(root.Statuses) ~= "table"
        or type(actor.ApplyStatus) ~= "function" then return end
    local records = buffRecords[actor] or {}; buffRecords[actor] = records
    local failures = buffFailures[actor] or {}; buffFailures[actor] = failures
    local desired = settings.StackPotions and potionCount(settings.PotionStacks) or 1
    local groups, naturalTotal = {}, 0
    for _, spec in ipairs(potionSpecs) do
        groups[spec[1]] = { Own = {}, Natural = 0, Target = 0, Kept = 0 }
    end
    for id, status in pairs(statuses) do
        local group = type(status) == "table" and groups[status.Name]
        if group then
            local entry = records[status]
            if entry and entry.Owned and entry.Id == id then
                table.insert(group.Own, status)
            else
                group.Natural += 1; naturalTotal += 1
            end
        end
    end
    -- Count all normal beneficial potions, including unselected types. Other
    -- players remain free to apply effects; only our own copies are limited.
    local remaining = math.max(0, potionCount(settings.PotionLimit) - naturalTotal)
    for _, spec in ipairs(potionSpecs) do
        local group = groups[spec[1]]
        if settings[spec[5]] and not failures[spec[1]] and type(rawget(root.Statuses, spec[1])) == "table" then
            group.Target = math.min(remaining, math.max(0, desired - group.Natural))
            remaining -= group.Target
        end
        table.sort(group.Own, function(a, b) return records[a].Sequence < records[b].Sequence end)
        for _, status in ipairs(group.Own) do
            local entry = records[status]
            if entry.Max ~= settings.MaxBuffs or group.Kept >= group.Target then
                removeOwnedPotion(actor, status, entry, statuses)
                records[status] = nil
            else
                group.Kept += 1
                if finite(status.Duration) then status.Duration = math.max(status.Duration, 60) end
                if settings.MaxBuffs then maintainMaxPotion(actor, status) end
            end
        end
    end
    -- Remove every excess copy before adding replacements, so changing selected
    -- types or lowering the budget cannot briefly double the auto effects.
    local now = os.clock()
    local work = potionWork[actor]
    if not work or now >= work.NextAt then
        work = { Remaining = 8, NextAt = now + 0.05 }; potionWork[actor] = work
    end
    for _, spec in ipairs(potionSpecs) do
        local group = groups[spec[1]]
        -- A large requested count never becomes an unbounded loop in one update.
        -- This limits creation work per interval, not the requested potion count.
        local additions = math.min(work.Remaining, group.Target - group.Kept)
        for _ = 1, additions do
            work.Remaining -= 1
            local colors = rawget(root, "SubjectPotionColors")
            local color = type(colors) == "table" and rawget(colors, spec[2])
            local options = {
                Name = spec[1], Source = actor.Character, Duration = 60, Renew = false,
                Amount = spec[1] == "SubjectCrystal" and not settings.MaxBuffs and 25 or spec[3],
                Color = color or Color3.fromRGB(170, 220, 255),
            }
            if settings.MaxBuffs then for _, flag in ipairs(spec[4]) do options[flag] = true end end
            local ok, id = pcall(actor.ApplyStatus, actor, options)
            local status = ok and id ~= nil and rawget(statuses, id)
            if type(status) == "table" and not records[status] then
                buffSequence += 1
                records[status] = { Id = id, Owned = true, Max = settings.MaxBuffs, Sequence = buffSequence }
                if settings.MaxBuffs then maintainMaxPotion(actor, status) end
            else
                failures[spec[1]] = ok and "ApplyStatus did not create a distinct status" or tostring(id)
                report(spec[1] .. ": " .. failures[spec[1]])
                break
            end
        end
    end
    for status, entry in pairs(records) do
        if rawget(statuses, entry.Id) ~= status then
            records[status] = nil
        end
    end
    -- Refresh the attribute compensation after changing a real potion modifier.
    if settings.AttributeBuffs and type(actor.Stats) == "table" then
        for name, spec in pairs(attributeSpecs) do
            local stat = rawget(actor.Stats, name)
            local modifiers = type(stat) == "table" and rawget(stat, spec[1])
            if type(modifiers) == "table" then override(modifiers, statKey, attributeAmount(modifiers, spec)) end
        end
    end
end

local function prepareStats(actor)
    local settings = actorSettings(actor)
    if actor.Dead then return end
    if settings.PotionBuffs and settings.MaxBuffs then
        local statuses = rawget(actor, "Status")
        for status, entry in pairs(buffRecords[actor] or {}) do
            if type(statuses) == "table" and rawget(statuses, entry.Id) == status and entry.Max then
                maintainMaxPotion(actor, status)
            end
        end
    end
    if settings.AttributeBuffs and type(actor.Stats) == "table" then
        for name, spec in pairs(attributeSpecs) do
            local stat = rawget(actor.Stats, name)
            local modifiers = type(stat) == "table" and rawget(stat, spec[1])
            if type(modifiers) == "table" then override(modifiers, statKey, attributeAmount(modifiers, spec)) end
        end
    end
end
local function applyNoStun(actor)
    local settings = actorSettings(actor)
    if actor.Dead or not settings.NoStun then return end
    if finite(rawget(actor, "StunTime")) then actor.StunTime = 0 end
    if type(rawget(actor, "PlayKnockback")) == "boolean" then actor.PlayKnockback = false end
    local state = rawget(actor, "ActionState")
    local reaction = type(state) == "string" and (state == "Knockback"
        or (type(actor.StunState) == "string" and state == actor.StunState)
        or (type(actor.StaggerState) == "string" and state == actor.StaggerState))
    if not reaction then return end
    if type(actor.InterruptBase) == "function" and type(actor.RunState) == "string" then
        actor:InterruptBase(actor.RunState, true, true)
    else
        local animations = rawget(actor, "Animations")
        local animation = type(animations) == "table" and rawget(animations, state)
        if type(animation) == "table" and type(animation.Stop) == "function" then animation:Stop() end
    end
    -- Clear a hit reaction only; never advance an ordinary attack's animation.
    if actor.ActionState == state then actor.ActionState = "" end
    actor.ActionPlaying = false
    if type(rawget(actor, "FacingDefault")) == "boolean" then actor.Facing = actor.FacingDefault end
    if finite(rawget(actor, "FacingMultiplierDefault")) then actor.FacingMultiplier = actor.FacingMultiplierDefault end
    if finite(rawget(actor, "SpeedMultiplier")) then actor.SpeedMultiplier = 1 end
end
-- These are game tables, not guessed NumberValues or UI-only stamina bars.
local function applyResources(actor)
    local settings = actorSettings(actor)
    if actor.Dead then return end
    applyNoStun(actor)
    if settings.InfiniteStamina and finite(rawget(actor, "Stamina")) then
        local maximum = rawget(actor, "MaxStamina")
        -- Sinner/Den/Caz/Epik/CCaz expose MaxStamina; other stamina classes use 0..1.
        actor.Stamina = finite(maximum) and maximum > 0 and maximum or 1
        if rawget(actor, "UpdateStaminaBar") ~= nil then actor.UpdateStaminaBar = true end
    end
    local cooldowns = rawget(actor, "Cooldowns")
    if type(cooldowns) == "table" and (settings.InfiniteCharges or settings.NoCooldown) then
        for _, skill in pairs(cooldowns) do
            if type(skill) == "table" then
                local maximum = rawget(skill, "MaxCharges")
                if finite(maximum) and maximum > 0 then
                    -- The game's own NoCooldowns branch also refills Charges.
                    if finite(rawget(skill, "Charges")) then skill.Charges = maximum end
                    if settings.NoCooldown and finite(rawget(skill, "Cooldown")) then
                        skill.Cooldown = 0
                    end
                end
            end
        end
    end
end
local function applyPreferences(actor, external)
    local settings = actorSettings(actor)
    if actor then
        if settings.NoStun and type(rawget(actor, "Unstoppable")) == "boolean" and not actor.Dead then
            override(actor, "Unstoppable", true)
        else
            release(actor, "Unstoppable")
        end
        if settings.SpeedEnabled and finite(rawget(actor, "WalkSpeed")) and not actor.Dead then
            override(actor, "WalkSpeed", settings.WalkSpeed)
        else
            release(actor, "WalkSpeed")
        end
    end
    if root and not external then
        if settings.NoCameraShake and finite(rawget(root, "ScreenShakeMultiplier")) then
            override(root, "ScreenShakeMultiplier", 0)
        else
            release(root, "ScreenShakeMultiplier")
        end
    end
end
local function safeApply(actor, external)
    local ok, err = pcall(function()
        if actor and actor.Dead and not external then deathObserved = true end
        applyPreferences(actor, external)
        if actor then applyResources(actor); maintainBuffs(actor); maintainRequirements(actor); maintainMoves(actor) end
    end)
    if not ok then report(err) end
end

local function isGameRoot(candidate)
    return type(candidate) == "table"
        and rawget(candidate, "IsClient") == true
        and rawget(candidate, "Assets") == ReplicatedStorage
        and type(rawget(candidate, "CreatureBase")) == "table"
end
local function fromEnvironment(environment)
    if type(environment) ~= "table" then return nil end
    local candidate = environment._G
    if isGameRoot(candidate) then return candidate end
    if isGameRoot(environment) then return environment end
    return nil
end
local function isController(candidate)
    return type(candidate) == "table" and player.Character ~= nil
        and rawget(candidate, "Character") == player.Character
        and type(rawget(candidate, "Cooldowns")) == "table"
        and type(rawget(candidate, "SkillFunctions")) == "table"
        and type(rawget(candidate, "UpdateBase")) == "function"
end
local function readUpvalues(fn)
    if type(debugAPI.getupvalues) == "function" then
        local ok, values = pcall(debugAPI.getupvalues, fn)
        if ok and type(values) == "table" then return values end
    end
    local values = {}
    if type(debugAPI.getupvalue) == "function" then
        for index = 1, 64 do
            local ok, value = pcall(debugAPI.getupvalue, fn, index)
            if not ok then break end
            -- Nil slots do not end the scan; later upvalues may still exist.
            values[index] = value
        end
    end
    return values
end
local function proofValid(proof)
    if not proof or not isController(proof.Actor) then return false end
    if proof.Anchor then
        local ok, attached = pcall(function()
            return proof.Anchor:IsDescendantOf(player:FindFirstChildOfClass("PlayerGui"))
        end)
        if not ok or not attached then return false end
    end
    return readUpvalues(proof.Function)[proof.Index] == proof.Actor
end
local function currentActor()
    if root then
        local actor = rawget(root, "v0")
        return isController(actor) and actor or nil
    end
    return proofValid(actorProof) and actorProof.Actor or nil
end
local function managedActor(actor)
    local active = targetSupport.Active
    return currentActor() == actor or (active ~= nil and active.Active and active.Actor == actor
        and active.Player.Character == active.Character and actor.Character == active.Character)
end
local function clearMoves(actor)
    local records = moveRecords[actor]
    if not records then return end
    for _, record in pairs(records.ByOriginal) do record.Active = false end
    for key, record in pairs(records.Keys) do
        if rawget(records.Table, key) == record.Wrapper then rawset(records.Table, key, record.Original) end
    end
    moveRecords[actor] = nil
end
local function clearRequirements(actor)
    local record = requirementRecords[actor]
    if not record then return end
    for target, keys in pairs(record.Overrides) do for key in pairs(keys) do release(target, key) end end
    requirementRecords[actor] = nil
end
maintainRequirements = function(actor)
    local settings = actorSettings(actor)
    if not settings.SecretRequirements or actor.Dead then clearRequirements(actor); return end
    local record = requirementRecords[actor]
    if not record then
        record = { Overrides = {}, Fields = {}, UpgradeAttempted = false }; requirementRecords[actor] = record
    end
    local function ready(key, value, expected)
        if type(rawget(actor, key)) ~= expected then return end
        local keys = record.Overrides[actor] or {}; record.Overrides[actor] = keys; keys[key] = true
        override(actor, key, value); record.Fields[key] = value
    end
    local definitions = root and type(root.Upgrades) == "table" and rawget(root.Upgrades, actor.Name)
    if not record.UpgradeAttempted and type(definitions) == "table" and type(root.GiveTalent) == "function"
        and type(api.GrantUpgrades) == "function" then
        record.UpgradeAttempted = true -- set before callbacks; GrantUpgrades can re-enter safeApply
        record.UpgradesGranted = api.GrantUpgrades(actor)
    end
    -- Common, existing resource gates. Do not turn deliberately disabled skill
    -- entries with MaxCharges=0 into invented moves.
    local maximum = rawget(actor, "MaxStamina")
    if finite(rawget(actor, "Stamina")) then actor.Stamina = finite(maximum) and maximum > 0 and maximum or 1 end
    for _, skill in pairs(type(actor.Cooldowns) == "table" and actor.Cooldowns or {}) do
        if type(skill) == "table" and finite(skill.MaxCharges) and skill.MaxCharges > 0 then
            if finite(skill.Charges) then skill.Charges = skill.MaxCharges end
            if finite(skill.Cooldown) then skill.Cooldown = 0 end
        end
    end
    if actor.Name == "ClassSinner" then
        -- E.G.O Bodysack checks the sum of these three two-hit requirements.
        for _, key in ipairs({ "SkillSackBatBashReq", "SkillSackSmackdownReq", "SkillSackUpheavalReq" }) do ready(key, 2, "number") end
    elseif actor.Name == "ClassEpik" then
        ready("GoldenCounter", true, "boolean")
        ready("LungeComboTimer", 0.75, "number") -- selects the follow-up lunge variant
    elseif actor.Name == "ClassSol" then
        ready("MP", 100, "number") -- the cap used by AddMP; includes Magic Burst's resource gate
    elseif actor.Name == "ClassCCaz" and type(actor.Talents) == "table" and type(actor.DarksteelElements) == "table" then
        -- Darksteel variant prerequisites. The two enabling upgrades are 11/16;
        -- each elemental prerequisite is checked separately, matching the kit.
        local variants = {
            { "Amethyst", 11 }, { "Ocherous", 11, 1 }, { "Crimson", 11, 2 },
            { "Grimgold", 11, 6 }, { "Ivory", 11, 7 },
            { "Jade", 11, 8 }, { "Tear", 11, 9 },
            { "Noir", 16, 4 }, { "Jade", 16, 8 }, { "Tear", 16, 9 },
        }
        for _, variant in ipairs(variants) do
            if actor.Talents[variant[2]] and (not variant[3] or actor.Talents[variant[3]])
                and not table.find(actor.DarksteelElements, variant[1]) then table.insert(actor.DarksteelElements, variant[1]) end
        end
    end
end
local function originalMove(actor, fn)
    local records = moveRecords[actor]
    local record = records and records.ByWrapper[fn]
    return record and record.Original or fn
end
maintainMoves = function(actor)
    local settings = actorSettings(actor)
    local skills = rawget(actor, "SkillFunctions")
    if actor.Dead or not (settings.MoveStacking or settings.NoStun or settings.SecretRequirements) or type(skills) ~= "table" then
        clearMoves(actor); return
    end
    local records = moveRecords[actor]
    if records and records.Table ~= skills then clearMoves(actor); records = nil end
    if not records then
        records = { Table = skills, Keys = {}, ByOriginal = {}, ByWrapper = {} }; moveRecords[actor] = records
    end
    for key, fn in pairs(skills) do
        if type(fn) == "function" and not records.ByWrapper[fn] then
            local record = records.ByOriginal[fn]
            if not record then
                record = { Original = fn, Active = true }
                record.Wrapper = function(...)
                    local active = record.Active and api.Running and managedActor(actor) and not actor.Dead
                    if not active or not (settings.MoveStacking or settings.NoStun or settings.SecretRequirements) then return record.Original(...) end
                    if settings.SecretRequirements then maintainRequirements(actor) end
                    if settings.NoStun then applyNoStun(actor) end
                    local playing, state = actor.ActionPlaying, actor.ActionState
                    local bypass = settings.MoveStacking or settings.NoStun
                    if bypass and type(playing) == "boolean" then actor.ActionPlaying = false end
                    local results = table.pack(pcall(record.Original, ...))
                    if bypass and type(playing) == "boolean" and (not results[1] or actor.ActionState == state) then actor.ActionPlaying = playing end
                    if not results[1] then error(results[2], 0) end
                    return table.unpack(results, 2, results.n)
                end
                records.ByOriginal[fn] = record; records.ByWrapper[record.Wrapper] = record
            end
            rawset(skills, key, record.Wrapper); records.Keys[key] = record
        elseif type(fn) == "function" then
            records.Keys[key] = records.ByWrapper[fn]
        end
    end
    for key, record in pairs(records.Keys) do
        if rawget(skills, key) ~= record.Wrapper then records.Keys[key] = nil end
    end
end
local function inspectCallbackGraph()
    if not api.Capabilities.Connections then return end
    local queue, visited, proposals = {}, {}, {}
    local function addSignal(signal, anchor)
        if not signal then return end
        local ok, list = pcall(getconnections, signal)
        if not ok or type(list) ~= "table" then return end
        for index, connection in ipairs(list) do
            if index > 24 or #queue >= 96 then break end
            local readable, fn = pcall(function() return connection.Function end)
            if readable and type(fn) == "function" then
                table.insert(queue, { Function = fn, Depth = 0, Anchor = anchor })
            end
        end
    end
    local gui = player:FindFirstChildOfClass("PlayerGui")
    gui = gui and gui:FindFirstChild("OvertureGui")
    local gameGui = gui and gui:FindFirstChild("Game")
    if gameGui then
        for _, name in ipairs({ "Skills", "DashSkills" }) do
            local container = gameGui:FindFirstChild(name)
            if container then
                for index, frame in ipairs(container:GetChildren()) do
                    if index > 48 then break end
                    local button = frame:FindFirstChild("Button", true)
                    if button and button:IsA("GuiButton") then addSignal(button.Activated, button) end
                end
            end
        end
    end
    -- Scope reflection to Overture signals, never every RunService connection.
    local remote = ReplicatedStorage:FindFirstChild("SetClass")
    if remote and remote:IsA("RemoteEvent") then addSignal(remote.OnClientEvent, nil) end
    local cursor, inspected = 1, 0
    while cursor <= #queue and inspected < 96 do
        local item = queue[cursor]; cursor += 1
        local fn = item.Function
        if not visited[fn] then
            visited[fn] = true; inspected += 1
            if type(getfenv) == "function" then
                local ok, found = pcall(function() return fromEnvironment(getfenv(fn)) end)
                if ok and found then root = found; accessMethod = "callback environment"; break end
            end
            for index, value in pairs(readUpvalues(fn)) do
                if isGameRoot(value) then root = value; accessMethod = "captured globals"; break end
                if isController(value) and item.Anchor then
                    proposals[value] = { Actor = value, Function = fn, Index = index, Anchor = item.Anchor }
                elseif type(value) == "function" and item.Depth < 4 and #queue < 96 then
                    table.insert(queue, { Function = value, Depth = item.Depth + 1, Anchor = item.Anchor })
                end
            end
            if root then break end
        end
    end
    api.Discovery.FunctionsInspected = inspected
    local count, selected = 0, nil
    for _, proof in pairs(proposals) do count += 1; selected = proof end
    api.Discovery.Ambiguous = count > 1
    if not root and count == 1 and proofValid(selected) then
        actorProof = selected; accessMethod = "skill callback upvalue"
    end
end
local function discover(now)
    if root and not isGameRoot(root) then
        release(root, "ScreenShakeMultiplier"); root = nil
    end
    if isGameRoot(root) or proofValid(actorProof) then return end
    actorProof = nil
    if now - lastSearch < 1 then return end
    lastSearch = now
    local ok, found = pcall(fromEnvironment, { _G = _G })
    if ok and found then root = found; accessMethod = "shared environment"; return end
    if type(getrenv) == "function" then
        ok, found = pcall(function() return fromEnvironment(getrenv()) end)
        if ok and found then root = found; accessMethod = "getrenv"; return end
    end
    if type(getsenv) == "function" then
        local gui = player:FindFirstChildOfClass("PlayerGui")
        gui = gui and gui:FindFirstChild("OvertureGui")
        local main = gui and gui:FindFirstChild("OvertureLocal")
        local scripts = ReplicatedStorage:FindFirstChild("Scripts")
        local base = scripts and scripts:FindFirstChild("BaseScripts")
        local module = base and base:FindFirstChild("CreatureBase")
        -- getsenv may throw before a script has started. No game module is required here.
        for _, target in pairs({ main, module }) do
            ok, found = pcall(function() return fromEnvironment(getsenv(target)) end)
            if ok and found then root = found; accessMethod = "getsenv"; return end
        end
    end
    inspectCallbackGraph()
    if root or proofValid(actorProof) then return end
    if now - lastGC >= 15 then
        lastGC = now
        if api.Capabilities.FilterGC then
            ok, found = pcall(function()
                local matches = filtergc("table", {
                    Keys = { "CreatureBase", "Assets", "IsClient" },
                    KeyValuePairs = { Assets = ReplicatedStorage, IsClient = true },
                }, false)
                local selected
                if type(matches) ~= "table" then return nil end
                for _, candidate in pairs(matches) do
                    if isGameRoot(candidate) then
                        if selected and selected ~= candidate then return nil end
                        selected = candidate
                    end
                end
                return selected
            end)
            if ok and found then root = found; accessMethod = "filtergc table signature"; return end
        end
        if not api.Capabilities.GC then return end
        ok, found = pcall(function()
            local selected
            for _, candidate in pairs(getgc(true)) do
                if isGameRoot(candidate) then
                    if selected and selected ~= candidate then return nil end
                    selected = candidate
                end
            end
            return selected
        end)
        if ok and found then root = found; accessMethod = "getgc" end
    end
end
local function detach(preserveCombo)
    if not preserveCombo then
        if comboFlow.Token == comboToken and comboFlow.Report then
            comboFlow.Report.Cancelled = true; comboFlow.Report.Stage = "Class rotation stopped after a controller change"
        end
        comboToken += 1; comboBusy = false; api.ComboRunning = false
        comboFlow.Transition = false; comboFlow.Token = nil; comboFlow.FromCharacter = nil
    end
    if binding then
        binding.Active = false
        if rawget(binding.Actor, "UpdateBase") == binding.Wrapper then
            rawset(binding.Actor, "UpdateBase", binding.Original)
        end
        if binding.StatWrapper and rawget(binding.Actor, "CalculateStats") == binding.StatWrapper then
            rawset(binding.Actor, "CalculateStats", binding.StatBefore)
        end
        release(binding.Actor, "WalkSpeed")
        release(binding.Actor, "Unstoppable")
        clearMoves(binding.Actor)
        clearRequirements(binding.Actor)
        clearStatBuffs(binding.Actor)
        clearPotionBuffs(binding.Actor)
        binding = nil
    end
    controller = nil
end
local function bind(actor)
    if binding and binding.Actor == actor and rawget(actor, "UpdateBase") == binding.Wrapper then
        return
    end
    detach(comboFlow.Transition and comboFlow.Token == comboToken)
    if not actor then return end
    controller = actor
    local original = rawget(actor, "UpdateBase")
    if type(original) ~= "function" then return end
    local current = { Actor = actor, Original = original, Active = true }
    current.Wrapper = function(self, ...)
        local active = api.Running and current.Active and self == actor
            and currentActor() == actor
        if active then safeApply(actor) end
        -- Keep the original state machine, animation timing, arguments and return values.
        local results = table.pack(original(self, ...))
        if active and api.Running and current.Active then safeApply(actor) end
        return table.unpack(results, 1, results.n)
    end
    rawset(actor, "UpdateBase", current.Wrapper)
    if type(actor.CalculateStats) == "function" then
        local calculate = actor.CalculateStats
        current.StatBefore = rawget(actor, "CalculateStats")
        current.StatWrapper = function(self, ...)
            if api.Running and current.Active and self == actor and currentActor() == actor then
                local ok, err = pcall(prepareStats, actor)
                if not ok then report(err) end
            end
            return calculate(self, ...)
        end
        -- Status.Update runs before CalculateStats. Apply caps at this boundary
        -- so the resolved stat values, not just their table entries, use them.
        rawset(actor, "CalculateStats", current.StatWrapper)
    end
    binding = current
    safeApply(actor)
end

local function clearHighlights()
    for model, highlight in pairs(highlights) do
        highlight:Destroy(); highlights[model] = nil
    end
    if highlightFolder then highlightFolder:Destroy(); highlightFolder = nil end
end
local function refreshHighlights()
    local char = player.Character
    local team = char and char:GetAttribute("DamageTeam")
    local center = char and char:FindFirstChild("HumanoidRootPart")
    local entities = Workspace:FindFirstChild("OT_Entities")
    if not settings.EnemyESP or not center or team == nil or not entities then
        clearHighlights(); return
    end
    if not highlightFolder then
        highlightFolder = Instance.new("Folder")
        highlightFolder.Name = "OvertureBasicHighlights"
        highlightFolder.Parent = Workspace
    end
    local candidates = {}
    for _, model in ipairs(entities:GetChildren()) do
        if model:IsA("Model") and model ~= char and not model:GetAttribute("Dead") then
            local otherTeam = model:GetAttribute("DamageTeam")
            local part = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            if otherTeam ~= nil and otherTeam ~= team and part and part:IsA("BasePart") then
                table.insert(candidates, { Model = model, Distance = (part.Position - center.Position).Magnitude })
            end
        end
    end
    table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
    local keep = {}
    for index = 1, math.min(24, #candidates) do keep[candidates[index].Model] = true end
    for model, highlight in pairs(highlights) do
        if not keep[model] then highlight:Destroy(); highlights[model] = nil end
    end
    for model in pairs(keep) do
        if not highlights[model] then
            local highlight = Instance.new("Highlight")
            highlight.Name = "OvertureBasicEnemy"
            highlight.Adornee = model
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.FillColor = Color3.fromRGB(255, 116, 103)
            highlight.OutlineColor = Color3.fromRGB(255, 194, 143)
            highlight.FillTransparency = 0.86
            highlight.OutlineTransparency = 0.1
            highlight.Parent = highlightFolder
            highlights[model] = highlight
        end
    end
end

local function actionMessage(value)
    api.ActionMessage = value
    api.ActionMessageTime = os.clock()
    updateMenu()
end
-- Bulk commands use the recovered hit path; they never write a fake win,
-- NPC health, NPC positions, or a server timer on the client.
function worldFlow.attribute(name)
    local ok, value = pcall(function() return ReplicatedStorage:GetAttribute(name) end)
    return ok and value or nil
end
function worldFlow.phase()
    local parts = {}
    for _, key in ipairs({ "GameState", "Round", "RoundId", "Stage", "Wave" }) do
        local value = worldFlow.attribute(key)
        if value ~= nil then table.insert(parts, key .. "=" .. tostring(value)) end
    end
    return table.concat(parts, " / ")
end
function worldFlow.retries()
    return finite(settings.NPCRetries) and math.clamp(math.floor(settings.NPCRetries), 1, 30) or 8
end
function worldFlow.source()
    local actor = currentActor()
    if not actor or actor.Dead or not player.Character then return nil, "A living class is required as the hit source" end
    local character = actor.Character
    local part = character:FindFirstChild("HumanoidRootPart")
    local humanoid = rawget(actor, "Humanoid") or character:FindFirstChildOfClass("Humanoid")
    if not part or not humanoid or not finite(humanoid.Health) or humanoid.Health <= 0 then return nil, "Your hit source is unavailable" end
    if not root or type(root.ProcessHit) ~= "function" or type(actor.Stats) ~= "table" then return nil, "The game hit handler is unavailable" end
    local team = character:GetAttribute("DamageTeam")
    if team == nil then return nil, "Your damage team is unavailable" end
    return { Actor = actor, Character = character, Part = part, Team = team, Root = root }
end
function worldFlow.playerCharacters()
    local characters = { [player.Character or player] = true }
    local ok, players = pcall(function() return Players:GetPlayers() end)
    if not ok or type(players) ~= "table" then return nil end
    for _, other in ipairs(players) do if other.Character then characters[other.Character] = true end end
    return characters
end
function worldFlow.target(model, characters, team, includeAllies)
    if not model or not model.Parent or characters[model] or not model:IsA("Model") then return nil end
    local ok, owner = pcall(function() return Players:GetPlayerFromCharacter(model) end)
    if ok and owner then return nil end
    if model:GetAttribute("Dead") or model:GetAttribute("Untargetable") then return nil end
    local otherTeam = model:GetAttribute("DamageTeam")
    if otherTeam == nil or (not includeAllies and (team == nil or otherTeam == team)) then return nil end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local part = model:FindFirstChild("HumanoidRootPart")
    if not humanoid or not finite(humanoid.Health) or humanoid.Health <= 0 or not part or not part:IsA("BasePart") then return nil end
    return { Model = model, Humanoid = humanoid, Part = part, Team = otherTeam }
end
function worldFlow.scan(source)
    local folder = Workspace:FindFirstChild("OT_Entities")
    local characters = worldFlow.playerCharacters()
    if not characters then return {}, "Player roster unavailable; NPCs cannot be distinguished reliably" end
    if not folder then return {}, "No loaded OT_Entities folder" end
    local targets = {}
    for _, model in ipairs(folder:GetChildren()) do
        local target = worldFlow.target(model, characters, source and source.Team, settings.NPCIncludeAllies)
        if target then table.insert(targets, target) end
    end
    table.sort(targets, function(a, b) return tostring(a.Model.Name) < tostring(b.Model.Name) end)
    return targets
end
function worldFlow.cancel(reason)
    local request = worldFlow.Pending
    if request then
        request.Cancelled = true; request.Stage = reason or "Stopped; earlier hit requests remain unconfirmed"
        worldFlow.Pending = nil
    end
    worldFlow.Stage = reason or "Stopped"
end
function worldFlow.observe(request)
    local defeated, removed, gathered = 0, 0, 0
    for _, target in ipairs(request.Targets) do
        local model, humanoid = target.Model, target.Humanoid
        if request == worldFlow.Pending and model.Parent then
            local progressed = request.Kind == "Kill" and target.LastHealth and humanoid.Health < target.LastHealth
            target.LastHealth = humanoid.Health
            if target.Goal then
                local distance = (target.Part.Position - target.Goal).Magnitude
                progressed = progressed or (target.LastDistance and distance < target.LastDistance - 1)
                target.LastDistance = distance
            end
            if progressed then target.Attempts = 0; request.ProgressAt = os.clock() end
        end
        if humanoid.Health <= 0 or model:GetAttribute("Dead") then defeated += 1
        elseif not model.Parent then removed += 1
        elseif target.Goal then
            local delta = target.Part.Position - target.Goal
            if delta.Magnitude <= 8 then gathered += 1 end
        end
    end
    request.ObservedDefeats = defeated; request.ObservedRemovals = removed; request.ObservedBrought = gathered
end
function worldFlow.start(kind, automatic)
    if not api.Running then return false, "Unloaded" end
    if worldFlow.Pending then return false, "An NPC command is running; Stop cancels it" end
    local source, reason = worldFlow.source()
    if not source then if not automatic then actionMessage(reason) end; return false, reason end
    local targets, scanReason = worldFlow.scan(source)
    if #targets == 0 then
        worldFlow.Stage = scanReason or "No eligible living NPCs are loaded"
        if not automatic then actionMessage(worldFlow.Stage) end
        return false, worldFlow.Stage
    end
    if not automatic then worldFlow.Audit = setmetatable({}, { __mode = "k" }) end
    local eligible = {}
    for index, target in ipairs(targets) do
        local audit = worldFlow.Audit[target.Model]
        if not automatic or not audit or audit.Health ~= target.Humanoid.Health or audit.Count < worldFlow.retries() then
            target.Attempts = 0
            target.LastHealth = target.Humanoid.Health
            if kind == "Bring" then
                local angle = (index - 1) * math.pi * 2 / math.min(#targets, 8)
                local radius = 6 + 4 * math.floor((index - 1) / 8)
                target.Goal = source.Part.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                target.LastDistance = (target.Part.Position - target.Goal).Magnitude
            end
            table.insert(eligible, target)
        end
    end
    if #eligible == 0 then worldFlow.Stage = "NPC attempts paused: no health change was observed"; return false, worldFlow.Stage end
    local request = { Kind = kind, Automatic = automatic == true, Source = source, Targets = eligible,
        Targeted = #eligible, Index = 1, Requested = 0, Failed = 0, StartedAt = os.clock(), Phase = worldFlow.phase(),
        Confirmed = false, Stage = kind == "Bring" and "Queued native NPC pulls" or "Queued native NPC damage requests" }
    worldFlow.Pending = request; api.LastNPCAction = request; worldFlow.Stage = request.Stage
    if not automatic then actionMessage(request.Stage .. "; game/server result unconfirmed") end
    return true, request.Stage
end
function api.KillAllNPCs() return worldFlow.start("Kill", false) end
function api.BringAllNPCs() return worldFlow.start("Bring", false) end
function api.StopWorldCommands()
    worldFlow.cancel("Stopped; earlier NPC requests remain unconfirmed")
    worldFlow.cancelVote("Stopped; earlier skip vote delivery remains unconfirmed")
    if settings.AutoWinRound then api.Set("AutoWinRound", false) end
    actionMessage(worldFlow.Stage)
    return true
end
function api.SkipRound()
    if not api.Running then return false, "Unloaded" end
    local previous = api.LastRoundSkip
    if previous and previous.Pending then return false, "A skip vote request is pending" end
    if previous and os.clock() - previous.RequestedAt < 3 then return false, "Skip vote is rate limited" end
    if previous and previous.VoteAccepted and previous.Epoch == worldFlow.Epoch then return false, "Your skip vote is already recorded for this phase" end
    if previous and previous.DeliveryUnknown and previous.Epoch == worldFlow.Epoch then return false, "Skip delivery is unknown; inspect the native vote before trying again" end
    local remote = ReplicatedStorage:FindFirstChild("VoteSkip")
    if not remote or not remote:IsA("RemoteFunction") then actionMessage("The native skip vote is unavailable"); return false, "VoteSkip unavailable" end
    local request = { Pending = true, RequestedAt = os.clock(), Epoch = worldFlow.Epoch,
        Confirmed = false, Phase = worldFlow.phase(), Stage = "Requesting the native skip vote" }
    api.LastRoundSkip = request
    task.spawn(function()
        if not api.Running or request.Cancelled then return end
        -- Exact zero-argument request recovered from Intermission/Skip.
        local ok, result = pcall(remote.InvokeServer, remote)
        if not api.Running or request.Cancelled or api.LastRoundSkip ~= request then return end
        request.Pending = false; request.VoteAccepted = ok and not not result
        request.Stage = not ok and ("Skip vote error: " .. tostring(result))
            or (request.VoteAccepted and "Server recorded the vote; phase advance remains unconfirmed" or "Skip vote was not accepted")
        actionMessage(request.Stage)
    end)
    actionMessage(request.Stage)
    return true, request.Stage
end
function worldFlow.cancelVote(reason)
    local vote = api.LastRoundSkip
    if vote and vote.Pending then
        vote.Pending = false; vote.Cancelled = true; vote.DeliveryUnknown = true; vote.Stage = reason
    end
end
function api.InspectWorld()
    local source, reason = worldFlow.source()
    local targets, scanReason = worldFlow.scan(source)
    local request = api.LastNPCAction
    if request then worldFlow.observe(request) end
    local voteRemote = ReplicatedStorage:FindFirstChild("VoteSkip")
    return { SourceAvailable = source ~= nil, SourceReason = reason, NPCs = #targets, ScanReason = scanReason,
        Phase = worldFlow.phase(), AutoWinRound = settings.AutoWinRound,
        Stage = worldFlow.Stage, Pending = worldFlow.Pending ~= nil,
        NativeSkipAvailable = voteRemote ~= nil and voteRemote:IsA("RemoteFunction"),
        Requested = request and request.Requested or 0, Failed = request and request.Failed or 0,
        ObservedDefeats = request and request.ObservedDefeats or 0,
        ObservedRemovals = request and request.ObservedRemovals or 0,
        ObservedBrought = request and request.ObservedBrought or 0,
        LastSkip = api.LastRoundSkip, ForcedWinAvailable = false, ServerResultConfirmed = false }
end
function worldFlow.tick(now)
    local phase, timer = worldFlow.phase(), worldFlow.attribute("Timer")
    if phase ~= worldFlow.Phase or (finite(timer) and finite(worldFlow.Timer) and timer > worldFlow.Timer + 1) then
        worldFlow.Epoch += 1; worldFlow.Phase = phase
        worldFlow.Audit = setmetatable({}, { __mode = "k" })
        if worldFlow.Pending then worldFlow.cancel("Round phase changed; earlier requests remain unconfirmed") end
        worldFlow.cancelVote("Round phase changed; earlier skip vote delivery remains unconfirmed")
    end
    worldFlow.Timer = timer
    local vote = api.LastRoundSkip
    if vote and vote.Pending and now - vote.RequestedAt > 15 then
        vote.Pending = false; vote.Cancelled = true; vote.DeliveryUnknown = true; vote.Stage = "Skip vote timed out; delivery remains unknown"
    end
    local source, reason = worldFlow.source()
    if source and source.Actor ~= worldFlow.SourceActor then
        worldFlow.SourceActor = source.Actor; worldFlow.Audit = setmetatable({}, { __mode = "k" })
    end
    local request = worldFlow.Pending
    if request then
        if not source or request.Source.Root ~= root or request.Source.Actor ~= source.Actor or request.Source.Character ~= source.Character then
            worldFlow.cancel(reason or "Source class changed; earlier NPC requests remain unconfirmed"); return
        end
        worldFlow.observe(request)
        if now - (request.ProgressAt or request.StartedAt) > 30 then worldFlow.cancel("NPC command timed out without progress; inspect observed results before retrying"); return end
        if request.Busy or now < worldFlow.NextHit then return end
        local characters = worldFlow.playerCharacters()
        if not characters then worldFlow.cancel("Player roster unavailable; NPC requests stopped"); return end
        local sent = 0
        for _ = 1, #request.Targets do
            local target = request.Targets[request.Index]
            request.Index = request.Index % #request.Targets + 1
            local valid = worldFlow.target(target.Model, characters, source.Team, settings.NPCIncludeAllies)
            if valid and target.Attempts < worldFlow.retries() then
                local damage = finite(settings.NPCDamage) and math.clamp(settings.NPCDamage, 1, 800) or 800
                local hit = { Name = "Attack", Type = "Normal", Amount = damage,
                    Knockback = {}, Status = {}, Sound = {}, Events = {}, Stagger = false, Stun = 0,
                    ScreenShake = 0, Lifesteal = 0, LifestealMult = 0,
                    TargetType = target.Team == source.Team and "Ally" or "Enemy" }
                if request.Kind == "Bring" then
                    local delta = target.Part.Position - target.Goal
                    local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
                    if delta.Magnitude <= 8 then target.Attempts = worldFlow.retries()
                    elseif not target.Model:FindFirstChild("Torso") then target.Attempts = worldFlow.retries()
                    else
                        hit.Amount = 0
                        hit.Knockback = { { "Source", { Knockback = Vector3.new(0, math.clamp(-delta.Y / 0.5, -180, 180), -math.min(180, distance / 0.5)),
                            Duration = 0.5, DecayAmount = 0, Stoppable = true, Interrupt = true,
                            Source = source.Character }, target.Goal } }
                    end
                end
                if target.Attempts < worldFlow.retries() then
                    target.Attempts += 1; request.Requested += 1
                    local audit = worldFlow.Audit[target.Model]
                    if not audit or audit.Health ~= target.Humanoid.Health then audit = { Count = 0, Health = target.Humanoid.Health } end
                    audit.Count += 1; worldFlow.Audit[target.Model] = audit
                    request.Busy = true; worldFlow.NextHit = now + 0.25
                    local ok, err = pcall(root.ProcessHit, { Source = source.Actor, Part = target.Part, HitBoxPart = source.Part, HitBox = hit })
                    request.Busy = false
                    if worldFlow.Pending ~= request or not api.Running then return end
                    if not ok then
                        request.Failed += 1; request.Error = tostring(err)
                        worldFlow.cancel("Game hit callback failed; earlier requests remain unconfirmed")
                        if settings.AutoWinRound then api.Set("AutoWinRound", false) end
                        return
                    end
                    sent += 1
                    if sent >= 2 then break end
                end
            end
        end
        if sent == 0 then
            worldFlow.observe(request); request.Finished = true
            request.Stage = string.format("%s: %d attempts / %d defeats / %d gathered observed; server outcome unconfirmed",
                request.Kind, request.Requested, request.ObservedDefeats, request.ObservedBrought)
            worldFlow.Stage = request.Stage; worldFlow.Pending = nil; worldFlow.NextAuto = now + 0.5
            if not request.Automatic then actionMessage(request.Stage) end
        end
    elseif settings.AutoWinRound and now >= worldFlow.NextAuto then
        worldFlow.NextAuto = now + 0.75
        local state = worldFlow.attribute("GameState")
        local paused = state == "Intermission" or state == "Selection" or state == "Victory" or state == "Defeat"
        if paused then worldFlow.Stage = "Auto win: waiting for an active round"
        elseif source then worldFlow.start("Kill", true) else worldFlow.Stage = reason end
    end
end

function api.CancelCombo()
    if comboFlow.Token == comboToken and comboFlow.Report then
        comboFlow.Report.Cancelled = true
        comboFlow.Report.Stage = "Cancelled; an earlier class choice or reset may still complete"
    end
    local request = respawnFlow.Pending
    if request and request.ComboToken == comboToken and not request.AttemptedAt then
        respawnFlow.cancel("Combo cancelled before the class reset started")
    end
    comboFlow.Transition = false; comboFlow.RequestingReset = false; comboFlow.Token = nil; comboFlow.FromCharacter = nil
    comboToken += 1; comboBusy = false; api.ComboRunning = false
end
function api.CastSkill(name)
    local actor = currentActor()
    if not api.Running or not actor or actor.Dead then return false, "No living class controller" end
    safeApply(actor)
    if finite(actor.StunTime) and actor.StunTime > 0 then return false, "Stunned" end
    local fn = rawget(actor.SkillFunctions, name)
    if type(fn) ~= "function" then return false, "Unknown move: " .. tostring(name) end
    if actor.ActionPlaying and not (settings.MoveStacking or settings.NoStun) then return false, "Another move is playing" end
    -- Recovered callbacks take no arguments and already capture the controller.
    local ok, err = pcall(fn)
    safeApply(actor)
    if not ok then report(err); return false, tostring(err) end
    -- A successful call is not proof that an animation or server effect occurred.
    return true, "Callback dispatched"
end
function comboFlow.castClasses()
    local first = currentActor()
    if not api.Running or not first or first.Dead then actionMessage("Choose a living class first"); return false end
    if type(first.Name) ~= "string" then actionMessage("The active class name is unavailable"); return false end
    if respawnFlow.Pending then actionMessage("Finish the current respawn before starting class rotation"); return false end
    local classes, seen = { first.Name }, { [first.Name] = true }
    for _, class in ipairs(api.ListCharacters()) do
        if not seen[class.Name] and (class.Unlocked or settings.UnlockAllCharacters) then
            seen[class.Name] = true; table.insert(classes, class.Name)
        end
    end
    if #classes <= 1 then actionMessage("Other enabled class choices are unavailable; check Classes first"); return false end
    if not settings.ComboAllowClassResets and worldFlow.attribute("Practice") ~= true then
        actionMessage("All-class rotation changes classes and respawns. Use Practice or enable Allow class resets; normal lives apply.")
        return false
    end
    comboToken += 1
    local token, owner = comboToken, root
    local record = { Mode = "Class rotation", ClassesPlanned = #classes, ClassesActivated = 0,
        Dispatched = 0, Skipped = 0, Failed = 0, Total = 0, Stage = "Starting with the active class",
        Confirmed = false, Completed = false, StartedAt = os.clock() }
    api.LastCombo = record; comboFlow.Report = record; comboFlow.Token = token
    comboBusy = true; api.ComboRunning = true
    task.spawn(function()
        local function active() return api.Running and token == comboToken and root == owner end
        local function requireActive()
            if not active() then error("Class rotation cancelled") end
            if not settings.ComboAllowClassResets and worldFlow.attribute("Practice") ~= true then
                api.CancelCombo(); record.Stage = "Practice ended; remaining class rotation stopped"
                error(record.Stage)
            end
        end
        local function cast(actor)
            local moves, functions = {}, {}
            for name, fn in pairs(actor.SkillFunctions) do
                if type(name) == "string" and type(fn) == "function" and not functions[fn]
                    and (settings.IncludeDash or not string.find(string.lower(name), "dash", 1, true)) then
                    functions[fn] = true; table.insert(moves, name)
                end
            end
            table.sort(moves); record.Total += #moves
            record.ClassesActivated += 1; record.CurrentClass = actor.Name
            record.Stage = "Casting native moves: " .. tostring(actor.Name)
            for _, name in ipairs(moves) do
                requireActive()
                if currentActor() ~= actor or actor.Dead then error("Active class changed outside the combo") end
                local deadline = os.clock() + settings.ComboWaitTimeout
                while actor.ActionPlaying and not (settings.MoveStacking or settings.NoStun) and os.clock() < deadline do
                    requireActive(); task.wait(0.04)
                end
                requireActive()
                if currentActor() ~= actor or actor.Dead then error("Class became unavailable before a move") end
                local ok, why = api.CastSkill(name)
                if ok then record.Dispatched += 1
                elseif why == "Another move is playing" or why == "Stunned" then record.Skipped += 1
                else record.Failed += 1 end
                task.wait((settings.MoveStacking or settings.NoStun) and 0 or settings.ComboDelay)
            end
        end
        local ok, err = pcall(function()
            cast(first)
            for index = 2, #classes do
                requireActive()
                local before = currentActor()
                if not before or before.Dead then error("No living class remains for the next reset") end
                while os.clock() - lastRespawnRequest < 3 or os.clock() - lastClassRequest < 1.1 do
                    requireActive(); task.wait(0.05)
                end
                requireActive()
                if currentActor() ~= before then error("Character changed before the next class choice") end
                local name = classes[index]
                record.Stage = "Choosing " .. name .. " and waiting for its actual controller"
                comboFlow.Transition = true; comboFlow.FromCharacter = before.Character
                local chosen, message = api.SelectCharacter(name)
                if not chosen then error(message or "Class choice failed") end
                local choice = api.LastCharacterRequest
                comboFlow.RequestingReset = true
                local resetCall = table.pack(pcall(api.ForceRespawn))
                comboFlow.RequestingReset = false
                if not resetCall[1] or not resetCall[2] then error(tostring(resetCall[1] and resetCall[3] or resetCall[2])) end
                local request = api.LastRespawnRequest
                local deadline = os.clock() + 20
                local nextActor
                repeat
                    requireActive()
                    if choice and (api.LastCharacterRequest ~= choice or choice.Cancelled or choice.Failed) then error("Class choice was replaced or failed") end
                    if request and (request.Failed or request.Cancelled or request.TimedOut) then error(request.Stage or "Respawn was not confirmed") end
                    nextActor = currentActor()
                    if nextActor and nextActor ~= before and not nextActor.Dead then
                        local humanoid = rawget(nextActor, "Humanoid") or nextActor.Character:FindFirstChildOfClass("Humanoid")
                        if humanoid and humanoid.Health > 0 then
                            if nextActor.Name ~= name then error("Spawned class does not match " .. name .. "; rotation stopped") end
                            break
                        end
                    end
                    nextActor = nil; task.wait(0.05)
                until os.clock() >= deadline
                if not nextActor then error("No matching living controller appeared for " .. name) end
                comboFlow.Transition = false; comboFlow.FromCharacter = nil
                cast(nextActor)
            end
        end)
        if token ~= comboToken then return end
        comboFlow.Transition = false; comboFlow.RequestingReset = false; comboFlow.Token = nil; comboFlow.FromCharacter = nil
        comboBusy = false; api.ComboRunning = false
        record.Completed = ok; record.FinishedAt = os.clock()
        record.Stage = ok and string.format("%d/%d classes activated; %d native callbacks dispatched; server effects unconfirmed",
            record.ClassesActivated, record.ClassesPlanned, record.Dispatched)
            or ("Class rotation stopped: " .. tostring(err))
        record.Error = not ok and tostring(err) or nil
        actionMessage(record.Stage)
    end)
    return true, "Native class rotation started; class changes and normal respawn rules apply"
end

function api.CastAll()
    if comboBusy then api.CancelCombo(); actionMessage("Combo cancelled"); return false end
    if not settings.ComboEnabled then actionMessage("Enable the all-moves combo first"); return false end
    if settings.ComboAllClasses then return comboFlow.castClasses() end
    local actor = currentActor()
    if not api.Running or not actor or actor.Dead then actionMessage("Choose a living class first"); return false end
    local moves, seen = {}, {}
    for name, fn in pairs(actor.SkillFunctions) do
        if type(name) == "string" and type(fn) == "function" and not seen[fn]
            and (settings.IncludeDash or not string.find(string.lower(name), "dash", 1, true)) then
            table.insert(moves, name); seen[fn] = true
        end
    end
    table.sort(moves)
    if #moves == 0 then actionMessage("No move callbacks found"); return false end
    comboToken += 1
    local token = comboToken
    comboBusy = true; api.ComboRunning = true
    task.spawn(function()
        local dispatched, skipped, failures = 0, 0, 0
        local ok, err = pcall(function()
            for _, name in ipairs(moves) do
                if not api.Running or token ~= comboToken or currentActor() ~= actor or actor.Dead then break end
                local deadline = os.clock() + settings.ComboWaitTimeout
                while not (settings.MoveStacking or settings.NoStun) and actor.ActionPlaying and os.clock() < deadline do
                    if not api.Running or token ~= comboToken or currentActor() ~= actor or actor.Dead then return end
                    task.wait(0.04)
                end
                if not api.Running or token ~= comboToken or currentActor() ~= actor or actor.Dead then break end
                local called, reason = api.CastSkill(name)
                if called then dispatched += 1
                elseif reason == "Another move is playing" or reason == "Stunned" then skipped += 1
                else failures += 1 end
                task.wait((settings.MoveStacking or settings.NoStun) and 0 or settings.ComboDelay)
            end
        end)
        if token ~= comboToken then return end
        comboBusy = false; api.ComboRunning = false
        api.LastCombo = { Dispatched = dispatched, Skipped = skipped, Failed = failures, Total = #moves }
        if not ok then report(err); actionMessage("Combo error: " .. tostring(err))
        else actionMessage(string.format("Combo: %d callbacks dispatched, %d skipped, %d failed", dispatched, skipped, failures)) end
    end)
    return true
end
function api.GrantUpgrades(selectedActor)
    local actor = type(selectedActor) == "table" and selectedActor or currentActor()
    local upgrades = root and rawget(root, "Upgrades")
    local definitions = type(upgrades) == "table" and rawget(upgrades, actor and actor.Name)
    if not api.Running or not actor or not managedActor(actor) or actor.Dead or type(definitions) ~= "table"
        or type(root.GiveTalent) ~= "function" or type(actor.Talents) ~= "table" then
        actionMessage("Class upgrade definitions unavailable"); return false
    end
    local indices = {}
    for index, definition in pairs(definitions) do
        if type(index) == "number" and type(definition) == "table" then table.insert(indices, index) end
    end
    table.sort(indices)
    local granted, failed = 0, 0
    for _, index in ipairs(indices) do
        if not actor.Talents[index] then
            -- Temp=true follows the game's own temporary-talent path and avoids
            -- altering its persistent talent selection bookkeeping.
            local ok, err = pcall(root.GiveTalent, actor, index, true)
            if ok and actor.Talents[index] then granted += 1
            else failed += 1; if not ok then report(err) end end
        end
    end
    api.LastUpgrades = { Granted = granted, Failed = failed, Temporary = true, Class = actor.Name }
    safeApply(actor, actor ~= currentActor())
    actionMessage(string.format("Class upgrades: %d granted, %d failed; until class reload", granted, failed))
    return failed == 0 and #indices > 0
end
function respawnFlow.finish(request, stage, failed)
    request.Stage = stage; request.Failed = failed or nil
    if respawnFlow.Pending == request then respawnFlow.Pending = nil end
    actionMessage(stage)
end
function respawnFlow.perform(request)
    if not api.Running or respawnFlow.Pending ~= request then return false, "Cancelled" end
    if request.Root ~= root then respawnFlow.finish(request, "Game environment changed; reconnect before resetting", true); return false, request.Stage end
    local actor = request.Actor
    if actor and root and rawget(root, "v0") ~= actor then
        request.Stage = "Controller is already changing; waiting for the new spawn"
        request.WaitSelection = nil
        return true, request.Stage
    end
    request.Busy = true; request.AttemptedAt = os.clock()
    local preserveCombo = request.ComboToken == comboToken and comboFlow.Transition
    if not preserveCombo then api.CancelCombo() end
    targetSupport.cancelHits("Your character is resetting; earlier hit attempts remain unconfirmed")
    worldFlow.cancel("Source character is resetting; previous NPC requests remain unconfirmed")
    detach(preserveCombo) -- remove our resource, move and potion hooks before game teardown
    if actor then
        request.Route = "Game DieBase teardown / Respawn"
        local sameCharacter = actor.Character ~= nil and actor.Character == player.Character
        local ok, err = pcall(request.Native, actor)
        request.Busy = false; actorProof = nil
        if not api.Running or respawnFlow.Pending ~= request then return false, "Tracking cancelled; native teardown may already have executed" end
        if not ok then
            request.Error = tostring(err); request.DeliveryUnknown = true
            respawnFlow.finish(request, "Game teardown failed: " .. request.Error, true)
            return false, request.Stage
        end
        if root and rawget(root, "v0") == actor then
            respawnFlow.finish(request, "Game teardown did not release the old controller; reset is unconfirmed", true)
            return false, request.Stage
        end
        request.ControllerReleased = root ~= nil and rawget(root, "v0") ~= actor or nil
        -- The native client branch sends Respawn only when it owns the current
        -- character. A stale controller is cleaned without sending that call.
        if not sameCharacter and (not root or rawget(root, "v0") == nil) then
            local sent, sendError = pcall(request.Remote.FireServer, request.Remote)
            if not sent then
                request.Error = tostring(sendError); request.DeliveryUnknown = true
                respawnFlow.finish(request, "Respawn dispatch failed: " .. request.Error, true)
                return false, request.Stage
            end
            request.Route = "Stale controller teardown / explicit Respawn"
        end
    else
        request.Route = "Respawn; no old controller remains"
        local ok, err = pcall(request.Remote.FireServer, request.Remote)
        request.Busy = false
        if not ok then
            request.Error = tostring(err); request.DeliveryUnknown = true
            respawnFlow.finish(request, "Respawn dispatch failed: " .. request.Error, true)
            return false, request.Stage
        end
    end
    request.Sent = true; request.SentAt = os.clock(); request.WaitSelection = nil
    request.Stage = "Respawn flow dispatched; waiting for a fresh living controller"
    lastSearch = -math.huge
    actionMessage(request.Stage)
    return true, request.Stage
end
function api.RequestRespawn(force)
    if not api.Running then return false, "Unloaded" end
    force = force == true -- a GuiButton's InputObject is not permission to force a reset
    if respawnFlow.Pending then actionMessage(respawnFlow.Pending.Stage); return false, "Respawn is already pending" end
    local actor = root and rawget(root, "v0") or currentActor()
    if type(actor) ~= "table" then actor = nil end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local dead = (actor and actor.Dead) or (humanoid and humanoid.Health <= 0) or deathObserved
    if not force and not dead then actionMessage("Use Force respawn to reset a living character"); return false, "Still alive" end
    if os.clock() - lastRespawnRequest < 3 then return false, "Waiting for server" end
    local remote = ReplicatedStorage:FindFirstChild("Respawn")
    if not remote or not remote:IsA("RemoteEvent") then actionMessage("Respawn event unavailable"); return false end
    local base = root and rawget(root, "CreatureBase")
    local native = type(base) == "table" and base.DieBase or nil
    if type(native) ~= "function" then native = actor and actor.DieBase end
    if actor and type(native) ~= "function" then
        actionMessage("Game teardown is unavailable; reconnect before resetting the existing controller")
        return false, "Native DieBase unavailable"
    end
    lastRespawnRequest = os.clock()
    local selection = root and rawget(root, "ClassSelection")
    local request = { RequestedAt = lastRespawnRequest, Actor = actor, Root = root,
        Character = player.Character, Native = native, Remote = remote, Forced = force,
        DesiredClass = type(selection) == "table" and selection.CurrentClass or actor and actor.Name,
        Confirmed = false, Sent = false, Stage = "Preparing game respawn flow",
        ComboToken = comboFlow.RequestingReset and comboFlow.Token or nil }
    api.LastRespawnRequest = request; respawnFlow.Pending = request; respawnFlow.AutoAttempted = true
    local choice = api.LastCharacterRequest
    local waitingChoice = not actor and choice and choice.Chosen and not choice.Sent
        and not choice.Failed and not choice.Cancelled and choice.Selection == selection
        and type(selection) == "table" and choice.Name == selection.CurrentClass
    if force and type(selection) == "table" and ((actor and selection.CurrentClass ~= actor.Name) or waitingChoice)
        and selection.ClassChanged == false and type(selection.Update) == "function" then
        local ok, err = pcall(selection.Update, selection, 0)
        if not ok then
            request.Error = tostring(err); respawnFlow.finish(request, "Class choice failed; reset was not started: " .. request.Error, true)
            return false, request.Stage
        end
        if selection.ClassChanged == false then
            request.WaitSelection = selection
            request.Stage = "Waiting for the chosen class to dispatch before resetting"
            actionMessage(request.Stage); return true, request.Stage
        end
    end
    return respawnFlow.perform(request)
end
function api.ForceRespawn() return api.RequestRespawn(true) end
function api.InspectRespawn()
    local request = api.LastRespawnRequest
    if not request then return { Pending = false, Stage = "No respawn requested" } end
    return { Pending = respawnFlow.Pending == request, Forced = request.Forced, Stage = request.Stage,
        Route = request.Route, Sent = request.Sent, Confirmed = request.Confirmed, Failed = request.Failed,
        TimedOut = request.TimedOut, Error = request.Error, ControllerReleased = request.ControllerReleased,
        DesiredClass = request.DesiredClass, ActiveClass = request.ActiveClass,
        ClassMatched = request.ClassMatched, CharacterChanged = request.CharacterChanged }
end
function respawnFlow.tick(now, actor)
    local request = respawnFlow.Pending
    local late = false
    if not request then
        request = api.LastRespawnRequest
        if not request or (not request.TimedOut and not request.DeliveryUnknown) or request.Cancelled or request.Confirmed then return end
        late = true
    end
    if request.Busy then return end
    local humanoid = actor and (rawget(actor, "Humanoid") or actor.Character:FindFirstChildOfClass("Humanoid"))
    if actor and actor ~= request.Actor and not actor.Dead and humanoid and humanoid.Health > 0 then
        request.Confirmed = true; request.ConfirmedAt = now; request.ActiveClass = actor.Name
        request.CharacterChanged = actor.Character ~= request.Character
        request.ClassMatched = request.DesiredClass == nil or actor.Name == request.DesiredClass
        respawnFlow.AutoAttempted = false
        respawnFlow.finish(request, "Fresh living controller confirmed: " .. tostring(actor.Name)
            .. (request.ClassMatched and "" or "; the chosen class is not active"))
        return
    end
    if late then return end
    if request.WaitSelection then
        local selection = root and rawget(root, "ClassSelection")
        if selection ~= request.WaitSelection or selection.CurrentClass ~= request.DesiredClass then
            respawnFlow.finish(request, "Class choice changed; reset was not started", true); return
        end
        if selection.ClassChanged == true then respawnFlow.perform(request); return end
    end
    local start = request.SentAt or request.AttemptedAt or request.RequestedAt
    if now - start > 15 then
        request.TimedOut = true
        respawnFlow.finish(request, request.WaitSelection and "Class choice has not dispatched; reset was not started"
            or "No fresh controller observed; respawn remains unconfirmed. Retry manually if needed.")
    end
end
function respawnFlow.cancel(reason)
    local request = respawnFlow.Pending
    if request then
        request.Stage = reason; request.Cancelled = true; respawnFlow.Pending = nil
    end
end

-- Teammate experiments. Native hits keep the game's actual source and go
-- through ProcessHit; direct mode requires an existing, complete controller.
-- A successful local callback is never treated as a server acknowledgement.
function api.ListPlayers()
    local list = {}
    if type(Players.GetPlayers) ~= "function" then return list end
    local ok, players = pcall(Players.GetPlayers, Players)
    if not ok or type(players) ~= "table" then return list end
    for _, other in ipairs(players) do
        if other ~= player then
            table.insert(list, { UserId = other.UserId, Name = other.Name, DisplayName = other.DisplayName,
                Selected = targetSupport.Selected == other.UserId, HasCharacter = other.Character ~= nil })
        end
    end
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end
function targetSupport.player(id)
    id = id or targetSupport.Selected
    if not finite(id) or type(Players.GetPlayers) ~= "function" then return nil end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.UserId == id then return other end
    end
end
function targetSupport.context(id, needsSource)
    local other = targetSupport.player(id)
    if not other then return nil, "Select a connected player first" end
    local character = other.Character
    if not character or not character.Parent then return nil, "Target character is unavailable" end
    local part = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or character:GetAttribute("Dead") then
        return nil, "Target must have a living character"
    end
    local actor = currentActor()
    if needsSource then
        if not part then return nil, "The target root part is unavailable for a potion hit" end
        if not actor or actor.Dead or actor.Character ~= player.Character then
            return nil, "Potion hit requests need your living character as the hit source; direct local edits do not"
        end
        local team = actor.Character:GetAttribute("DamageTeam")
        if team == nil or character:GetAttribute("DamageTeam") ~= team then return nil, "Potion hit requests require the same DamageTeam" end
    end
    return { Player = other, Character = character, Part = part, Source = actor }
end
function targetSupport.editableActor(candidate, character)
    if type(candidate) ~= "table" or rawget(candidate, "Character") ~= character
        or type(rawget(candidate, "UpdateBase")) ~= "function" or candidate.Dead then return false end
    local stats = rawget(candidate, "Stats")
    local power = type(stats) == "table" and rawget(stats, "Power")
    -- Each effect needs its own real data, not every field of the local player
    -- controller. Never invent cooldowns, statuses or skill functions on a
    -- cosmetic animator merely to make it pass this check.
    return (type(rawget(candidate, "Cooldowns")) == "table" and type(rawget(candidate, "SkillFunctions")) == "table")
        or finite(rawget(candidate, "Stamina"))
        or (type(power) == "table" and type(rawget(power, 3)) == "table" and type(rawget(power, 4)) == "table")
        or (type(rawget(candidate, "Status")) == "table" and type(candidate.ApplyStatus) == "function")
end
function targetSupport.findActor(other, refresh)
    local character = other.Character
    local cached = targetSupport.Cache[other.UserId]
    if not refresh then
        if cached and cached.Character == character and targetSupport.editableActor(cached.Actor, character) then return cached.Actor, cached.Route end
        if cached and cached.Character == character and cached.Failure then return nil, cached.Failure end
        return nil, "Inspect the selected player to check available gameplay data"
    end
    local found, count, inspected = {}, 0, 0
    local function offer(candidate, route)
        if targetSupport.editableActor(candidate, character) and not found[candidate] then
            found[candidate] = route; count += 1
        end
    end
    local configTable = root and rawget(root, "Config")
    for _, collection in ipairs({ "ClientEntities", "Entities", "Animators" }) do
        local entities = type(configTable) == "table" and rawget(configTable, collection)
        for _, candidate in pairs(type(entities) == "table" and entities or {}) do
            inspected += 1; if inspected > 4096 then break end
            offer(candidate, "Config." .. collection)
        end
    end
    if type(filtergc) == "function" then
        local ok, matches = pcall(filtergc, "table", {
            Keys = { "Character", "UpdateBase" },
            KeyValuePairs = { Character = character },
        }, false)
        if ok and type(matches) == "table" then
            for index, candidate in pairs(matches) do
                inspected += 1; if inspected > 8192 then break end
                offer(candidate, "filtergc character signature")
            end
        end
    end
    if count == 0 and type(getgc) == "function" then
        local ok, matches = pcall(getgc, true)
        if ok and type(matches) == "table" then
            for _, candidate in pairs(matches) do
                inspected += 1; if inspected > 100000 then break end
                offer(candidate, "bounded getgc character search")
            end
        end
    end
    targetSupport.Cache[other.UserId] = nil
    if count ~= 1 then
        local reason = count > 1 and "More than one gameplay controller matched; direct edits are unavailable"
            or "Target gameplay data is unavailable on this client; direct skill and resource edits are unsupported"
        targetSupport.Cache[other.UserId] = { Character = character, Failure = reason }
        return nil, reason
    end
    for actor, route in pairs(found) do
        targetSupport.Cache[other.UserId] = { Character = character, Actor = actor, Route = route }
        return actor, route
    end
end
function targetSupport.cancelHits(reason)
    if targetSupport.Pending and api.LastPlayerRequest then
        api.LastPlayerRequest.Stage = reason or "Cancelled; earlier hit attempts remain unconfirmed"
        api.LastPlayerRequest.Remaining = 0
    end
    targetSupport.Pending = nil
end
function api.StopPlayerEffects(silent)
    targetSupport.cancelHits()
    local active = targetSupport.Active
    targetSupport.Active = nil
    if active then
        active.Active = false
        local actor = active.Actor
        if rawget(actor, "UpdateBase") == active.Wrapper then rawset(actor, "UpdateBase", active.Original) end
        if active.StatWrapper and rawget(actor, "CalculateStats") == active.StatWrapper then rawset(actor, "CalculateStats", active.StatBefore) end
        release(actor, "WalkSpeed"); release(actor, "Unstoppable")
        clearMoves(actor); clearRequirements(actor); clearStatBuffs(actor); clearPotionBuffs(actor)
    end
    if not silent then actionMessage("Player attempts stopped. Previously requested effects expire through the game; talents need class reload.") end
    return true
end
function api.SelectPlayer(id)
    local other = targetSupport.player(id)
    if not api.Running or not other then return false, "Player is unavailable" end
    if targetSupport.Selected ~= id then api.StopPlayerEffects(true) end
    targetSupport.Selected = id
    local result = api.InspectPlayer(id, true)
    actionMessage("Selected " .. other.Name .. (result.DirectAvailable and "; local gameplay data available" or "; check target capabilities below"))
    return true
end
function api.InspectPlayer(id, refresh)
    local context, message = targetSupport.context(id)
    if not context then return { Available = false, Reason = message, ServerConfirmed = false } end
    local actor, route = targetSupport.findActor(context.Player, refresh == true)
    local hitContext, hitReason = targetSupport.context(context.Player.UserId, true)
    local hitAvailable = hitContext ~= nil and root ~= nil and type(root.ProcessHit) == "function"
    local report = { Available = true, UserId = context.Player.UserId, Name = context.Player.Name,
        FullController = actor ~= nil and type(rawget(actor, "Cooldowns")) == "table"
            and type(rawget(actor, "SkillFunctions")) == "table",
        DirectAvailable = actor ~= nil, ControllerRoute = route,
        NativeHitAvailable = hitAvailable,
        NativeHitReason = not hitAvailable and (hitReason or "Game hit handler is unavailable") or nil,
        DirectRequiresOwnCharacter = false,
        Capabilities = { Skills = actor ~= nil and type(rawget(actor, "SkillFunctions")) == "table"
                and type(rawget(actor, "Cooldowns")) == "table",
            Resources = actor ~= nil and finite(rawget(actor, "Stamina")),
            Attributes = actor ~= nil and type(actor.Stats) == "table",
            Potions = actor ~= nil and type(actor.Status) == "table" and type(actor.ApplyStatus) == "function",
            Talents = actor ~= nil and type(actor.Talents) == "table" and root ~= nil and type(root.GiveTalent) == "function" },
        DirectActive = actor ~= nil and targetSupport.Active ~= nil and targetSupport.Active.Actor == actor,
        ServerConfirmed = false, PersistentProgressSupported = false,
        Pending = targetSupport.Pending ~= nil, LastRequest = api.LastPlayerRequest }
    api.PlayerReport = report
    return report
end
function api.ApplyPlayerOverrides(id)
    if not api.Running then return false, "Unloaded" end
    local context, message = targetSupport.context(id)
    if not context then actionMessage(message); return false, message end
    local actor, route = targetSupport.findActor(context.Player, true)
    if not actor then actionMessage(route); return false, route end
    api.StopPlayerEffects(true)
    local current = { Actor = actor, Player = context.Player, Character = context.Character, Name = actor.Name,
        Original = actor.UpdateBase, Active = true, Route = route }
    targetSupport.Active = current
    current.Wrapper = function(self, ...)
        local active = api.Running and current.Active and self == actor and managedActor(actor)
        if active then safeApply(actor, true) end
        local results = table.pack(current.Original(self, ...))
        if active and api.Running and current.Active then safeApply(actor, true) end
        return table.unpack(results, 1, results.n)
    end
    rawset(actor, "UpdateBase", current.Wrapper)
    if type(actor.CalculateStats) == "function" then
        local calculate = actor.CalculateStats
        current.StatBefore = rawget(actor, "CalculateStats")
        current.StatWrapper = function(self, ...)
            if api.Running and current.Active and self == actor and managedActor(actor) then
                local ok, err = pcall(prepareStats, actor); if not ok then report(err) end
            end
            return calculate(self, ...)
        end
        rawset(actor, "CalculateStats", current.StatWrapper)
    end
    safeApply(actor, true)
    api.PlayerReport = api.InspectPlayer(context.Player.UserId)
    actionMessage("Applied Players settings to " .. context.Player.Name .. "'s local controller; recipient/server result unconfirmed")
    return true, "Local controller changed; server result unconfirmed"
end
function api.GrantPlayerUpgrades()
    local active = targetSupport.Active
    if not api.Running or not active or not managedActor(active.Actor) then
        actionMessage("Start direct mode on an available target gameplay controller first"); return false
    end
    return api.GrantUpgrades(active.Actor)
end
function targetSupport.count(character)
    local now, total, reservations = os.clock(), 0, targetSupport.Reservations[character] or {}
    local keep = {}
    for _, expires in ipairs(reservations) do
        if expires > now then total += 1; table.insert(keep, expires) end
    end
    targetSupport.Reservations[character] = #keep > 0 and keep or nil
    local actor
    if type(Players.GetPlayers) == "function" then
        for _, other in ipairs(Players:GetPlayers()) do
            if other.Character == character then actor = targetSupport.findActor(other, false); break end
        end
    end
    if actor then
        for _, status in pairs(actor.Status) do
            if type(status) == "table" then
                for _, spec in ipairs(potionSpecs) do if status.Name == spec[1] then total += 1; break end end
            end
        end
    end
    -- Reflected requests can be counted twice. This deliberately overestimates
    -- unknown delivery rather than creating unbounded retries or extra copies.
    return total
end
function api.RequestPlayerPotions(id)
    if not api.Running then return false, "Unloaded" end
    local context, message = targetSupport.context(id, true)
    if not context then actionMessage(message); return false, message end
    if not root or type(root.ProcessHit) ~= "function" then actionMessage("Game ProcessHit is unavailable"); return false end
    if targetSupport.Pending then actionMessage("A potion request is already queued; Stop cancels it"); return false end
    if targetSupport.count(context.Character) >= potionCount(playerSettings.PotionLimit) then
        actionMessage("Target effect budget is occupied by observed effects or recent unconfirmed requests"); return false
    end
    local specs = {}
    for _, spec in ipairs(potionSpecs) do if playerSettings[spec[5]] then table.insert(specs, spec) end end
    if #specs == 0 then actionMessage("Select target potion effects in Players first"); return false end
    targetSupport.Pending = { Context = context, Specs = specs, Index = 1, SourceName = context.Source.Name, Busy = false }
    api.LastPlayerRequest = { UserId = context.Player.UserId, Attempted = 0, Remaining = #specs,
        Confirmed = false, Stage = "Queued; one native application per selected type" }
    actionMessage("Queued potion hit attempts for " .. context.Player.Name .. "; server result unconfirmed")
    return true, "Queued; no acknowledgement"
end
function targetSupport.tick(now)
    local active = targetSupport.Active
    if active then
        local context = targetSupport.context(active.Player.UserId)
        if not context or context.Character ~= active.Character or not targetSupport.editableActor(active.Actor, active.Character)
            or active.Actor.Name ~= active.Name
            or rawget(active.Actor, "UpdateBase") ~= active.Wrapper then
            api.StopPlayerEffects(true)
        else safeApply(active.Actor, true) end
    end
    local pending = targetSupport.Pending
    if not pending or pending.Busy or now < targetSupport.NextHit then return end
    local context = targetSupport.context(pending.Context.Player.UserId, true)
    if not context or context.Character ~= pending.Context.Character or context.Source ~= pending.Context.Source
        or context.Source.Name ~= pending.SourceName then
        targetSupport.Pending = nil
        api.LastPlayerRequest.Stage = "Cancelled after character/class change; earlier attempts unconfirmed"
        api.LastPlayerRequest.Remaining = 0
        actionMessage("Potion queue cancelled after character/class change"); return
    end
    if targetSupport.count(context.Character) >= potionCount(playerSettings.PotionLimit) then
        targetSupport.Pending = nil; api.LastPlayerRequest.Stage = "Stopped at positive total budget"
        api.LastPlayerRequest.Remaining = 0; return
    end
    local spec = pending.Specs[pending.Index]
    if not spec then targetSupport.Pending = nil; return end
    local talents = type(context.Source.Talents) == "table" and context.Source.Talents or {}
    local colors = root and root.SubjectPotionColors
    local status = { Name = spec[1], Duration = 8, Renew = true,
        Color = type(colors) == "table" and colors[spec[2]] or Color3.fromRGB(170, 220, 255) }
    for _, flag in ipairs(spec[4]) do status[flag] = playerSettings.MaxBuffs or talents[tonumber(string.match(flag, "%d+"))] == true end
    if spec[1] == "SubjectCrystal" then status.Amount = status.Talent6 and 30 or 25 end
    local hit = { Name = "SkillSplash", Type = "Status", Amount = 0, Status = { status },
        Knockback = {}, Sound = {}, Events = {}, Stagger = false, Stun = 0,
        ScreenShake = 0, Lifesteal = false, LifestealMult = 0, TargetType = "Ally" }
    local reservations = targetSupport.Reservations[context.Character] or {}
    targetSupport.Reservations[context.Character] = reservations
    table.insert(reservations, now + 8) -- keep even after an error: the request may already have left the client
    pending.Busy = true; targetSupport.NextHit = now + 0.25
    local ok, err = pcall(root.ProcessHit, { Source = context.Source, Part = context.Part,
        HitBoxPart = context.Source.Character:FindFirstChild("HumanoidRootPart"), HitBox = hit })
    pending.Busy = false
    if targetSupport.Pending ~= pending then return end
    pending.Index += 1
    api.LastPlayerRequest.Attempted += 1; api.LastPlayerRequest.Remaining = #pending.Specs - pending.Index + 1
    api.LastPlayerRequest.Stage = ok and "Game hit callback returned; server result unconfirmed" or ("Hit callback error: " .. tostring(err))
    if not ok or pending.Index > #pending.Specs then targetSupport.Pending = nil end
    actionMessage(api.LastPlayerRequest.Stage)
end

-- Character availability: overlay the local selector, then use the game's
-- normal SetClass request. Never write badges, gamepasses or unlock tags.
local function classUnlocked(name, owner)
    local unlocks = owner and rawget(owner, "Unlocks")
    if not unlocks then return false end
    local ok, unlocked = pcall(function() return unlocks:HasTag(name) end)
    return ok and unlocked == true
end
function api.ListCharacters()
    local database = root and rawget(root, "ClassDatabase")
    if type(database) ~= "table" then return {} end
    local names, seen, extras = {}, {}, {}
    local function add(name)
        if type(name) == "string" and string.match(name, "^Class[%w_]+$")
            and type(rawget(database, name)) == "table" and not seen[name] then
            seen[name] = true; table.insert(names, name)
        end
    end
    if type(root.ClassOrder) == "table" then for _, name in ipairs(root.ClassOrder) do add(name) end end
    for name, definition in pairs(database) do
        if type(name) == "string" and type(definition) == "table" and type(definition.Script) == "string" and not seen[name] then
            table.insert(extras, name)
        end
    end
    table.sort(extras); for _, name in ipairs(extras) do add(name) end
    local actor, list = currentActor(), {}
    local selection = rawget(root, "ClassSelection")
    local chosen = type(selection) == "table" and rawget(selection, "CurrentClass")
    for index, name in ipairs(names) do
        local definition = database[name]
        table.insert(list, {
            Name = name, Title = tostring(definition.Title or name), Index = index,
            Unlocked = classUnlocked(name, root), Active = actor ~= nil and actor.Name == name,
            Chosen = chosen == name, Hidden = definition.Hidden == true,
            Description = type(definition.Description) == "string" and definition.Description
                or type(definition.Desc) == "string" and definition.Desc or "",
            Browsing = classFlow.PreviewName == name,
        })
    end
    return list
end
local function setSelectorProperty(record, object, key, value)
    if not object then return end
    local ok, before = pcall(function() return object[key] end)
    if not ok then return end
    local properties = record.Properties[object]
    if not properties then properties = {}; record.Properties[object] = properties end
    local entry = properties[key]
    if not entry then entry = { Before = before }; properties[key] = entry
    elseif before ~= entry.Last then entry.Before = before end
    local written = pcall(function() object[key] = value end)
    if written then entry.Last = value end
end
local function clearSelectorControl(name, record, state)
    if record.Connection then record.Connection:Disconnect() end
    local legitimate = classUnlocked(name, state.Owner)
    if legitimate and record.NeedsNativeHandler and record.Button.Parent == record.Parent then
        -- A placeholder/clone that becomes legitimately unlocked must keep a
        -- working game-owned handler after our overlay disconnects its own.
        local adopted = false
        if type(state.Selection.AddClassButton) == "function" then
            adopted = pcall(state.Selection.AddClassButton, state.Selection, name)
        end
        if not adopted then
            local selection = state.Selection
            record.Button.Activated:Connect(function()
                local index = type(selection.ClassOrder) == "table" and table.find(selection.ClassOrder, name)
                if index then
                    selection.SelectedIndex = index
                    if type(selection.UpdateSelect) == "function" then selection:UpdateSelect() end
                end
            end)
        end
    elseif record.Created and not legitimate and record.Button.Parent == record.Parent then
        record.Button:Destroy()
    elseif not legitimate then
        for object, properties in pairs(record.Properties) do
            for key, entry in pairs(properties) do
                pcall(function() if object[key] == entry.Last then object[key] = entry.Before end end)
            end
        end
    end
end
local function clearNativeRoster()
    local state = nativeRoster
    if not state then return end
    nativeRoster = nil
    for name, record in pairs(state.Controls) do clearSelectorControl(name, record, state) end
    local selection, order = state.Selection, state.Order
    local selected = order[selection.SelectedIndex or 1]
    for index = #order, 1, -1 do
        if state.Added[order[index]] and not classUnlocked(order[index], state.Owner) then table.remove(order, index) end
    end
    if selection.ClassOrder == order and #order > 0 then
        selection.SelectedIndex = table.find(order, selected) or table.find(order, selection.CurrentClass) or 1
        if type(selection.UpdateSelect) == "function" then pcall(selection.UpdateSelect, selection) end
    end
end
maintainRoster = function()
    if not settings.UnlockAllCharacters or not api.Running or not root then clearNativeRoster(); return end
    local selection = rawget(root, "ClassSelection")
    if type(selection) ~= "table" or type(selection.ClassOrder) ~= "table" then clearNativeRoster(); return end
    local order = selection.ClassOrder
    local previousPreview = order[selection.SelectedIndex or 1]
    local info = rawget(selection, "ClassInfo")
    local ok, list = pcall(function() return info and info:FindFirstChild("List") end)
    if not ok then list = nil end -- the model can be ready before its GUI
    if nativeRoster and (nativeRoster.Selection ~= selection or nativeRoster.Order ~= order or nativeRoster.List ~= list) then clearNativeRoster() end
    if not nativeRoster then
        nativeRoster = { Owner = root, Selection = selection, Order = order, List = list, Added = {}, Controls = {} }
    end
    local state, changed = nativeRoster, false
    local selected = previousPreview or order[selection.SelectedIndex or 1]
    local classes = api.ListCharacters()
    for _, class in ipairs(classes) do
        local name = class.Name
        if not table.find(order, name) then
            table.insert(order, math.min(class.Index, #order + 1), name)
            state.Added[name] = true; changed = true
        end
        local button = list and list:FindFirstChild(name)
        local record = state.Controls[name]
        if record and record.Button ~= button then
            clearSelectorControl(name, record, state); state.Controls[name] = nil; record = nil
        end
        local created = false
        if not button and list and selection.ClassButton then
            button = selection.ClassButton:Clone(); button.Name = name; button.Parent = list; created = true
        end
        if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
            local title = button:FindFirstChild("TextLabel")
            if not record then
                record = { Button = button, Parent = list, Created = created, Properties = {},
                    NeedsNativeHandler = created or not class.Unlocked or (title and title.Text == "LOCKED") }; state.Controls[name] = record
                if record.NeedsNativeHandler then
                    record.Connection = button.Activated:Connect(function()
                        if not api.Running or not settings.UnlockAllCharacters or nativeRoster ~= state then return end
                        local index = table.find(selection.ClassOrder, name)
                        if index and selection.SelectedIndex ~= index then
                            selection.SelectedIndex = index
                            if type(selection.UpdateSelect) == "function" then selection:UpdateSelect() end
                        end
                    end)
                end
            end
            local definition = root.ClassDatabase[name]
            local color = definition.BaseColor or Color3.fromRGB(255, 255, 255)
            setSelectorProperty(record, button, "Visible", true)
            setSelectorProperty(record, button, "Active", true)
            setSelectorProperty(record, button, "Interactable", true)
            setSelectorProperty(record, button, "Selectable", true)
            setSelectorProperty(record, button, "LayoutOrder", class.Index)
            setSelectorProperty(record, title, "Text", string.upper(class.Title))
            setSelectorProperty(record, title, "TextColor3", color)
            setSelectorProperty(record, button:FindFirstChild("Frame"), "BackgroundColor3", color)
            local image = button:FindFirstChild("ImageLabel")
            if definition.FullImage or definition.Image then setSelectorProperty(record, image, "Image", definition.FullImage or definition.Image) end
            setSelectorProperty(record, image, "ImageColor3", Color3.fromRGB(255, 255, 255))
        end
    end
    if selected and table.find(order, selected) then selection.SelectedIndex = table.find(order, selected) end
    api.CharacterAvailability = { Entries = #classes, LocalSelector = true, PersistentUnlocks = false,
        SelectionRoute = "Native chosen-class state and confirmation" }
    if changed and type(selection.UpdateSelect) == "function" and #order > 0 then pcall(selection.UpdateSelect, selection) end
end
function api.UnlockCharacters()
    if not api.Running then return false end
    api.Set("UnlockAllCharacters", true)
    local count = #api.ListCharacters()
    actionMessage(count > 0 and (tostring(count) .. " character choices available in the selector; choose a class to request it") or "Waiting for the class database")
    return count > 0
end
function classFlow.chroma(selection)
    local ok, value = pcall(function()
        local panel = selection and selection.ClassInfo and selection.ClassInfo:FindFirstChild("Chroma")
        local bar = panel and panel:FindFirstChild("Bar")
        return panel and panel.Visible and bar and bar.Position.X.Scale or false
    end)
    return ok and finite(value) and math.clamp(value, 0, 1) or false
end
function classFlow.unwatch(expected)
    local watch = classFlow.Watch
    if not watch or (expected and watch ~= expected) then return end
    classFlow.Watch = nil
    if rawget(watch.Selection, "Update") == watch.Wrapper then
        rawset(watch.Selection, "Update", watch.Before)
    end
end
function classFlow.cancel(reason)
    classFlow.unwatch()
    local request = api.LastCharacterRequest
    if request and not request.Confirmed and not request.Cancelled and not request.Failed then
        request.Cancelled = true; request.Stage = reason or "Cancelled"
    end
end
function classFlow.watch(selection, request)
    classFlow.unwatch()
    local original = selection and selection.Update
    if type(original) ~= "function" then return false end
    local watch = { Selection = selection, Before = rawget(selection, "Update"), Request = request }
    watch.Wrapper = function(self, ...)
        local tracking = api.Running and self == selection and classFlow.Watch == watch
            and api.LastCharacterRequest == request and not request.Cancelled
        local pending = tracking and self.CurrentClass == request.Name and self.ClassChanged == false
        local beforeTimer = self.ChangeClassTimer
        local results = table.pack(pcall(original, self, ...))
        if not results[1] then
            if tracking then
                request.Failed = true; request.Error = tostring(results[2]); request.Stage = "Native selector error"
                classFlow.unwatch(watch)
            end
            error(results[2], 0)
        end
        if pending and api.LastCharacterRequest == request and self.CurrentClass == request.Name
            and self.ClassChanged == true and self.ChangeClassTimer ~= beforeTimer then
            request.Sent = true; request.SentAt = os.clock(); request.Chroma = classFlow.chroma(selection)
            request.Stage = "Native selector dispatched; waiting for class activation"
            classFlow.unwatch(watch)
        end
        return table.unpack(results, 2, results.n)
    end
    classFlow.Watch = watch
    rawset(selection, "Update", watch.Wrapper)
    return true
end
function api.InspectCharacterSelection()
    local selection = root and rawget(root, "ClassSelection")
    local actor = currentActor()
    return {
        Chosen = type(selection) == "table" and selection.CurrentClass or nil, Browsing = classFlow.PreviewName,
        Preview = type(selection) == "table" and type(selection.ClassOrder) == "table"
            and selection.ClassOrder[selection.SelectedIndex or 1] or nil,
        Active = actor and actor.Name, Chroma = classFlow.chroma(selection),
        NativeConfirm = type(selection) == "table" and type(selection.SelectConfirm) == "function",
        NativeUpdate = type(selection) == "table" and type(selection.Update) == "function",
        LastRequest = api.LastCharacterRequest, PersistentUnlocks = false,
    }
end
function api.PreviewCharacter(name)
    if not api.Running then return false, "Unloaded" end
    local found
    for _, class in ipairs(api.ListCharacters()) do if class.Name == name then found = class; break end end
    if not found then return false, "Unknown or unloaded character" end
    classFlow.PreviewName = name
    local selection = root and rawget(root, "ClassSelection")
    if type(selection) == "table" and type(selection.ClassOrder) == "table" then
        if settings.UnlockAllCharacters then maintainRoster() end
        local index = table.find(selection.ClassOrder, name)
        if index then
            local ok, err = pcall(function()
                selection.SelectedIndex = index
                if type(selection.UpdateSelect) == "function" then selection:UpdateSelect() end
            end)
            if not ok then actionMessage("Local class preview available; native preview failed: " .. tostring(err)) end
        end
    end
    updateMenu()
    return true, "Preview only; chosen class unchanged"
end
function api.SelectCharacter(name)
    if not api.Running then return false, "Unloaded" end
    local found
    for _, class in ipairs(api.ListCharacters()) do if class.Name == name then found = class; break end end
    if not found then return false, "Unknown or unloaded character" end
    classFlow.PreviewName = name
    if not settings.UnlockAllCharacters and not found.Unlocked then actionMessage("Enable All character choices first"); return false, "Local selector locked" end
    local selection = root and rawget(root, "ClassSelection")
    if found.Active and (type(selection) ~= "table" or selection.CurrentClass == name) then
        actionMessage(found.Title .. " is already active"); return true, "Already active"
    end
    if os.clock() - lastClassRequest < 1.1 then return false, "Class request is rate limited" end
    classFlow.cancel("Replaced by another class choice")
    lastClassRequest = os.clock()
    local request = { Name = name, Title = found.Title, RequestedAt = lastClassRequest,
        Confirmed = false, Chosen = false, Sent = false, Selection = selection, Stage = "Choosing" }
    api.LastCharacterRequest = request
    if type(selection) == "table" and type(selection.ClassOrder) == "table" then
        if settings.UnlockAllCharacters then maintainRoster() end
        local index = table.find(selection.ClassOrder, name)
        if not index then
            request.Failed = true; request.Stage = "Class is absent from the live selector"
            actionMessage(request.Stage); return false, request.Stage
        end
        local ok, err = pcall(function()
            selection.SelectedIndex = index
            if type(selection.UpdateSelect) == "function" then selection:UpdateSelect() end
            if type(selection.SelectConfirm) == "function" then selection:SelectConfirm()
            else
                -- Same state transition recovered from SelectConfirm; used
                -- when the game exposes a partial selector table.
                selection.CurrentClass = name; selection.ClassChanged = false; selection.SkipVisible = true
            end
        end)
        if not ok or selection.CurrentClass ~= name then
            request.Failed = true; request.Error = not ok and tostring(err) or "Native selector did not accept the choice"
            request.Stage = "Choice failed in the native selector"; actionMessage(request.Error)
            return false, request.Error
        end
        request.Chosen = true
        if selection.ClassChanged == true and not currentActor() then
            request.Stage = "Already chosen in the native selector; activation unconfirmed"
            actionMessage(found.Title .. " is chosen in the native selector")
            updateMenu(); return true, request.Stage
        end
        if classFlow.watch(selection, request) then
            request.Route = "Native SelectConfirm / Update"
            request.Stage = "Chosen; waiting for the native selector to dispatch"
            -- The real update owns its timer and phase checks. Call it once;
            -- later game updates handle a legitimate debounce/phase wait.
            local updated, updateError = pcall(selection.Update, selection, 0)
            if not updated then
                request.Failed = true; request.Error = tostring(updateError)
                actionMessage("Native selector error: " .. request.Error); return false, request.Error
            end
            actionMessage(found.Title .. (request.Sent and " chosen and dispatched; activation unconfirmed" or " chosen; waiting for the game's selection window"))
            updateMenu()
            return true, request.Stage
        end
    end
    local remote = ReplicatedStorage:FindFirstChild("SetClass")
    if not remote or not remote:IsA("RemoteEvent") then
        request.Failed = true; request.Stage = "SetClass event unavailable"
        actionMessage(request.Stage); return false, request.Stage
    end
    request.Route = "SetClass fallback; native update unavailable"
    request.Chroma = classFlow.chroma(selection)
    local ok, err = pcall(function() remote:FireServer(name, request.Chroma) end)
    if not ok then
        request.Failed = true; request.Error = tostring(err); request.Stage = "Class request failed"
        report(err); actionMessage(request.Error); return false, request.Error
    end
    if type(selection) == "table" then selection.ClassChanged = true end
    request.Sent = true; request.SentAt = os.clock(); request.Stage = "Request dispatched; waiting for class activation"
    actionMessage("Requested " .. found.Title .. "; activation unconfirmed")
    updateMenu()
    return true, request.Stage
end
function classFlow.tick(now, actor)
    local request = api.LastCharacterRequest
    if not request or request.Confirmed or request.Cancelled then return end
    if actor and actor.Name == request.Name then
        request.Confirmed = true; request.ConfirmedAt = now; request.Stage = "Active controller confirmed"
        classFlow.unwatch()
        actionMessage(request.Title .. " confirmed by its live controller")
        return
    end
    if request.Failed then return end
    if request.Selection then
        local selection = root and rawget(root, "ClassSelection")
        if selection ~= request.Selection then
            classFlow.cancel("Native selector was replaced; choose the class again"); return
        end
        if request.Chosen and selection.CurrentClass ~= request.Name then
            classFlow.cancel("Replaced by another native class choice"); return
        end
        local watch = classFlow.Watch
        if watch and rawget(selection, "Update") ~= watch.Wrapper then
            classFlow.cancel("Native selector update changed; choose the class again"); return
        end
    end
    if request.Sent and now - request.SentAt > 12 and not request.TimedOut then
        request.TimedOut = true; request.AwaitingSpawn = true
        request.Stage = "Choice sent; no matching live controller observed"
        actionMessage(request.Title .. " was chosen and sent. Activation has not been observed; it may require the next spawn.")
    elseif not request.Sent and now - request.RequestedAt > 12 and not request.Waiting then
        request.Waiting = true
        request.Stage = "Chosen; native dispatch has not been observed"
        actionMessage(request.Title .. " is chosen; waiting for the game's selector to dispatch it")
    end
end
local function inspectPotions(actor, settings)
    local result = { AutoEnabled = settings.PotionBuffs, Limit = potionCount(settings.PotionLimit), Maximum = maxPotionCount, UnlimitedBudget = false,
        CopiesPerType = settings.StackPotions and potionCount(settings.PotionStacks) or 1,
        Script = 0, Natural = 0, Selected = {}, ByType = {}, NaturalEffectsUnchanged = true }
    for _, spec in ipairs(potionSpecs) do
        result.ByType[spec[1]] = { Script = 0, Natural = 0 }
        if settings[spec[5]] then table.insert(result.Selected, spec[1]) end
    end
    local records = actor and buffRecords[actor] or {}
    local statuses = actor and rawget(actor, "Status")
    for id, status in pairs(type(statuses) == "table" and statuses or {}) do
        local counts = type(status) == "table" and result.ByType[status.Name]
        if counts then
            local entry = records[status]
            local key = entry and entry.Owned and entry.Id == id and "Script" or "Natural"
            counts[key] += 1; result[key] += 1
        end
    end
    result.Total = result.Script + result.Natural
    local remaining = math.max(0, result.Limit - result.Natural)
    result.TargetScript = 0; result.Pending = 0
    for _, spec in ipairs(potionSpecs) do
        local counts = result.ByType[spec[1]]
        local target = settings.PotionBuffs and settings[spec[5]]
            and math.min(remaining, math.max(0, result.CopiesPerType - counts.Natural)) or 0
        remaining -= target
        result.TargetScript += target
        result.Pending += math.max(0, target - counts.Script)
    end
    return result
end
function api.InspectPotions() return inspectPotions(currentActor(), settings) end
function api.InspectPlayerPotions()
    local other = targetSupport.player()
    local actor = other and targetSupport.findActor(other, false)
    return inspectPotions(actor, playerSettings)
end
function api.GetAnalysisState()
    local actor = currentActor()
    return {
        Controller = actor, Discovery = api.Discovery, Capabilities = api.Capabilities,
        ClassUpgrades = root and root.Upgrades and actor and root.Upgrades[actor.Name],
        StatusDefinitions = root and root.Statuses, PotionColors = root and root.SubjectPotionColors,
        PersistentUnlocks = root and root.Unlocks, LastCombo = api.LastCombo,
        LastUpgrades = api.LastUpgrades,
        Settings = settings, PlayerSettings = playerSettings, TargetPotions = api.InspectPlayerPotions(),
        Config = config, UISkin = api.UISkin, LastError = api.LastError, LastUIError = api.LastUIError,
        PlayerSupport = api.PlayerReport, LastPlayerRequest = api.LastPlayerRequest, Respawn = api.InspectRespawn(),
        World = api.InspectWorld(),
        PotionFailures = actor and buffFailures[actor],
        Potions = api.InspectPotions(), BuffProfile = api.BuffProfile, Characters = api.ListCharacters(),
        Requirements = api.InspectRequirements(),
        CharacterAvailability = api.CharacterAvailability, LastCharacterRequest = api.LastCharacterRequest,
        Limits = { InfiniteServerLives = false, PersistentUnlocks = false, IndependentMoveTimelines = false },
    }
end
local function queueSettingsSave()
    config.Revision = (config.Revision or 0) + 1
    config.Dirty = true
    if config.Readable and config.Writable then
        saveDue = os.clock() + 0.5; config.Status = "Unsaved changes"
    else
        saveDue = nil; config.Status = "Session only: executor file support unavailable"
    end
end
function api.SaveSettings()
    if not api.Running then return false, "Unloaded" end
    if config.Saving then return false, "A settings save is already running" end
    saveDue = nil
    if not config.Readable or not config.Writable then
        config.Status = "Session only: executor file support unavailable"
        return false, config.Status
    end
    local snapshot = table.clone(defaults)
    mergeSettings(snapshot, settings)
    if not snapshot.PotionBuffs then snapshot.StackPotions = false end
    local playerSnapshot = table.clone(playerDefaults)
    mergePlayerSettings(playerSnapshot, playerSettings)
    if not playerSnapshot.PotionBuffs then playerSnapshot.StackPotions = false end
    local revision = config.Revision or 0
    config.Saving = true
    local ok, err = pcall(function()
        local bytes = HttpService:JSONEncode({ Format = "OvertureBasic", Version = config.Version,
            Settings = snapshot, PlayerSettings = playerSnapshot })
        writefile(config.Path, bytes)
    end)
    config.Saving = false
    if not ok then
        config.LastError = tostring(err); config.Status = "Settings save failed"; config.Dirty = true
        updateMenu()
        return false, config.LastError
    end
    config.LastError = nil; config.LastSavedAt = os.clock(); config.SaveCount += 1
    config.Dirty = (config.Revision or 0) ~= revision
    config.Status = config.Dirty and "Unsaved changes" or "Saved"
    if config.Dirty then saveDue = os.clock() + 0.5 end
    updateMenu()
    return true
end
local function applyConfiguration(values, targetValues)
    api.CancelCombo()
    worldFlow.cancel("Settings changed; previous NPC requests remain unconfirmed")
    worldFlow.cancelVote("Settings changed; previous skip delivery remains unconfirmed")
    api.StopPlayerEffects(true)
    for key, value in pairs(defaults) do settings[key] = value end
    mergeSettings(settings, values)
    if not settings.PotionBuffs then settings.StackPotions = false end
    if targetValues then
        for key, value in pairs(playerDefaults) do playerSettings[key] = value end
        mergePlayerSettings(playerSettings, targetValues)
        if not playerSettings.PotionBuffs then playerSettings.StackPotions = false end
    end
    safeApply(controller)
    maintainRoster(); lastRosterUpdate = -math.huge
    if not settings.EnemyESP then clearHighlights() end
    updateMenu()
end
function api.LoadSettings()
    if not api.Running or config.Saving then return false, "Unavailable while unloaded or saving" end
    local loaded, message, _, migrated, targetValues = readSettings()
    if not loaded then
        config.LastError = message; config.Status = message
        actionMessage(message)
        return false, message
    end
    applyConfiguration(loaded, targetValues)
    config.Loaded = true; config.Dirty = false; config.LastError = nil
    config.Revision = (config.Revision or 0) + 1; saveDue = nil
    config.Status = "Saved settings loaded"
    if migrated then
        config.PotionNotice = "Out-of-range potion profile disabled; counts adjusted to 1-1,000."
        queueSettingsSave()
    end
    actionMessage("Saved settings loaded")
    return true
end
function api.ApplyConservativePreset()
    if not api.Running then return false end
    local values = table.clone(defaults)
    values.ShowUI = settings.ShowUI -- menu construction is chosen at startup
    applyConfiguration(values, playerDefaults)
    queueSettingsSave()
    actionMessage("Conservative preset applied; gameplay overrides are off")
    return true
end
function api.Set(key, value)
    if not api.Running then return false end
    local validated = validateSetting(key, value)
    if validated == nil then return false end
    settings[key] = validated
    if key == "StackPotions" and value then settings.PotionBuffs = true end
    if key == "PotionBuffs" and not value then settings.StackPotions = false end
    if key == "ComboEnabled" and not value then api.CancelCombo() end
    if (key == "ComboAllClasses" or key == "ComboAllowClassResets") and not value then api.CancelCombo() end
    if key == "AutoWinRound" and not value then worldFlow.cancel("Automatic NPC clearing stopped") end
    if key == "NPCIncludeAllies" then worldFlow.cancel("NPC filter changed; start the command again") end
    queueSettingsSave()
    safeApply(controller)
    if key == "UnlockAllCharacters" then maintainRoster(); lastRosterUpdate = -math.huge end
    if key == "EnemyESP" and not value then clearHighlights() end
    updateMenu()
    return true
end
function api.SetPlayerSetting(key, value)
    if not api.Running or playerDefaults[key] == nil then return false end
    local validated = validateSetting(key, value)
    if validated == nil then return false end
    playerSettings[key] = validated
    if key == "StackPotions" and value then playerSettings.PotionBuffs = true end
    if key == "PotionBuffs" and not value then playerSettings.StackPotions = false end
    targetSupport.cancelHits("Target settings changed; request potions again manually")
    queueSettingsSave()
    if targetSupport.Active then safeApply(targetSupport.Active.Actor, true) end
    updateMenu()
    return true
end
function api.ResetPlayerSettings()
    if not api.Running then return false end
    api.StopPlayerEffects(true)
    for key, value in pairs(playerDefaults) do playerSettings[key] = value end
    queueSettingsSave(); updateMenu()
    actionMessage("Players settings reset; target attempts stopped")
    return true
end
local function setPotions(names, target)
    if not api.Running or type(names) ~= "table" then return false, "Expected a list of potion names" end
    local selected = {}
    for index, name in pairs(names) do
        if type(index) ~= "number" or index < 1 or index % 1 ~= 0 or type(name) ~= "string" then
            return false, "Expected a list of potion names"
        end
        local found
        for _, spec in ipairs(potionSpecs) do
            if string.lower(name) == string.lower(spec[1]) or string.lower(name) == string.lower(string.sub(spec[1], 8)) then
                selected[spec[5]] = true; found = true; break
            end
        end
        if not found then return false, "Unknown potion: " .. name end
    end
    local profile = target and playerSettings or settings
    for _, spec in ipairs(potionSpecs) do profile[spec[5]] = selected[spec[5]] == true end
    queueSettingsSave()
    if target then
        targetSupport.cancelHits("Target potion selection changed; request again manually")
        if targetSupport.Active then safeApply(targetSupport.Active.Actor, true) end
    else safeApply(controller) end
    updateMenu()
    return true
end
function api.SetPotions(names) return setPotions(names, false) end
function api.SetPlayerPotions(names) return setPotions(names, true) end
function api.InspectRequirements()
    local actor = currentActor()
    local record = actor and requirementRecords[actor]
    return {
        Enabled = settings.SecretRequirements, Class = actor and actor.Name,
        AppliedFields = record and table.clone(record.Fields) or {},
        UpgradeAttempted = record and record.UpgradeAttempted or false,
        UpgradeGrantSucceeded = record and record.UpgradesGranted or false,
        Coverage = { "Existing skill charges and stamina", "Available class talents",
            "Sinner Bodysack counters", "Epik golden counter and follow-up lunge",
            "Sol MP", "CCaz Darksteel elemental upgrade prerequisites" },
        Unverified = { "Other class-specific conditions", "Target, range and cutscene checks", "Server-side validation" },
        TalentEffectsLastUntilClassReload = true,
    }
end
function api.Refresh()
    if not api.Running then return end
    api.CancelCombo()
    worldFlow.cancel("Reconnecting; previous NPC requests remain unconfirmed")
    worldFlow.cancelVote("Reconnecting; previous skip delivery remains unconfirmed")
    respawnFlow.cancel("Respawn tracking stopped for reconnect; earlier dispatch may still complete")
    classFlow.cancel("Selection tracking stopped for reconnect")
    api.StopPlayerEffects(true); table.clear(targetSupport.Cache)
    if root then release(root, "ScreenShakeMultiplier") end
    clearNativeRoster()
    detach(); root = nil; actorProof = nil; lastSearch = -math.huge; lastGC = -math.huge
    api.Status = "Reconnecting..."
    updateMenu()
end
function api.InspectSkills()
    local actor = currentActor()
    local result = {
        Route = accessMethod, Capabilities = api.Capabilities, Skills = {},
        FeatureSupport = {
            Resources = actor ~= nil,
            Movement = actor ~= nil and finite(rawget(actor, "WalkSpeed")),
            CameraShake = root ~= nil and finite(rawget(root, "ScreenShakeMultiplier")),
            MoveChaining = actor ~= nil,
            NoStun = actor ~= nil and finite(rawget(actor, "StunTime")),
            NormalControlChaining = actor ~= nil and type(actor.SkillFunctions) == "table",
            IndependentMoveTimelines = false,
            AttributeBuffs = actor ~= nil and type(actor.Stats) == "table",
            PotionBuffs = root ~= nil and type(root.Statuses) == "table"
                and actor ~= nil and type(actor.ApplyStatus) == "function",
            TemporaryClassUpgrades = root ~= nil and type(root.GiveTalent) == "function",
            InfiniteServerLives = false,
            PersistentUnlocks = false,
            LocalCharacterSelector = root ~= nil and type(root.ClassDatabase) == "table",
            NativeClassRotation = root ~= nil and type(root.ClassDatabase) == "table",
            UnrestrictedClassMixing = false,
            NativeNPCCommands = root ~= nil and type(root.ProcessHit) == "function",
            ForcedRoundWin = false,
        },
    }
    if not actor then return result end
    for name, fn in pairs(actor.SkillFunctions) do
        if type(fn) == "function" then
            local slots = {}
            for index, value in pairs(readUpvalues(originalMove(actor, fn))) do
                if value == actor then table.insert(slots, index) end
            end
            table.sort(slots)
            table.insert(result.Skills, { Name = tostring(name), ControllerUpvalues = slots })
        end
    end
    table.sort(result.Skills, function(a, b) return a.Name < b.Name end)
    return result
end
function api.Unload()
    api.StopPlayerEffects(true)
    if not api.Running then return end
    respawnFlow.cancel("Respawn tracking stopped on unload; earlier dispatch may still complete")
    classFlow.cancel("Selection tracking stopped on unload")
    if config.Dirty then api.SaveSettings() end
    api.Running = false
    api.CancelCombo()
    worldFlow.cancel("Unloaded; previous NPC requests remain unconfirmed")
    worldFlow.cancelVote("Unloaded; previous skip delivery remains unconfirmed")
    clearNativeRoster()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    detach()
    for target, records in pairs(overrides) do
        for key, record in pairs(records) do
            if rawget(target, key) == record.Last then rawset(target, key, record.Before) end
        end
    end
    table.clear(overrides)
    clearHighlights()
    if screen then screen:Destroy(); screen = nil end
    if shared.OvertureBasic == api then shared.OvertureBasic = nil end
    api.Status = "Unloaded"
end

-- Native Overture settings appearance, read from the supplied place. The menu
-- owns all its controls; the real game GUI and its input handlers are untouched.
local function buildMenu()
    local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    local function child(parent, name) return parent and parent:FindFirstChild(name) end
    local native = child(playerGui, "OvertureGui")
    local nativeOptions = child(child(child(native, "Main"), "Settings"), "Options")
    local nativeList = child(nativeOptions, "List")
    local titleTemplate = child(child(nativeList, "MusicVolume"), "Title")
    local descTemplate = child(child(nativeList, "MusicVolume"), "Desc")
    local nativeStroke = child(nativeOptions, "UIStroke")
    local textColor = titleTemplate and titleTemplate.TextColor3 or Color3.fromRGB(255, 255, 255)
    local muted = descTemplate and descTemplate.TextColor3 or Color3.fromRGB(200, 200, 200)
    local black, lineColor = Color3.fromRGB(0, 0, 0), Color3.fromRGB(50, 50, 50)
    local bodyFont, titleFont
    local fontOK = pcall(function()
        bodyFont = titleTemplate and titleTemplate.FontFace
            or Font.new("rbxassetid://12187375422", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        titleFont = Font.new(bodyFont.Family, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
    end)
    if not fontOK then bodyFont = nil; titleFont = nil end
    api.UISkin = { Name = "Overture settings", FontFamily = bodyFont and bodyFont.Family or "SourceSans",
        Source = titleTemplate and "Live game settings" or "Supplied game GUI properties" }
    local function set(object, key, value) if object[key] ~= value then object[key] = value end end
    local function create(class, parent, properties)
        local object = Instance.new(class)
        for key, value in pairs(properties or {}) do object[key] = value end
        object.Parent = parent
        return object
    end
    local function stroke(object, color, thickness, transparency)
        return create("UIStroke", object, { Color = color or lineColor, Thickness = thickness or 1,
            Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
    end
    local function font(object, heading)
        object.Font = Enum.Font.SourceSans
        if bodyFont then object.FontFace = heading and titleFont or bodyFont end
    end
    local function label(parent, text, position, size, color, textSize, heading)
        local object = create("TextLabel", parent, {
            Text = text, Position = position, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0,
            TextSize = textSize or 14, TextColor3 = color or textColor, TextStrokeColor3 = black,
            TextStrokeTransparency = 0.75, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
        })
        font(object, heading)
        return object
    end
    local function button(parent, text, position, size)
        local object = create("TextButton", parent, {
            Text = text, Position = position, Size = size, BackgroundColor3 = black,
            BackgroundTransparency = 0.5, BorderSizePixel = 0, TextSize = 14, TextColor3 = textColor,
            TextStrokeColor3 = black, TextStrokeTransparency = 0.75, AutoButtonColor = true,
            Active = true, Interactable = true, Selectable = true,
        })
        font(object, false); stroke(object, lineColor, 1, 0.15)
        return object
    end
    local function press(object, callback)
        local lastChannel, lastTime
        local function dispatch(channel)
            if not api.Running then return end
            local now = os.clock()
            -- Some clients emit both events for one press. Consume the pair
            -- without debouncing repeated presses on the same input channel.
            if lastChannel and lastChannel ~= channel and now - lastTime < 0.08 then
                lastChannel = nil
                return
            end
            lastChannel = channel; lastTime = now
            callback()
        end
        connect(object.Activated, function() dispatch("Activated") end)
        connect(object.MouseButton1Click, function() dispatch("Click") end)
    end
    local function enableButton(control, enabled)
        set(control, "Active", enabled); set(control, "Interactable", enabled); set(control, "Selectable", enabled)
        set(control, "AutoButtonColor", enabled); set(control, "TextColor3", enabled and textColor or muted)
    end
    local function input(parent, text, position, size)
        local object = create("TextBox", parent, {
            Text = text, Position = position, Size = size, BackgroundColor3 = black,
            BackgroundTransparency = 0.5, BorderSizePixel = 0, TextSize = 16, TextColor3 = textColor,
            PlaceholderColor3 = muted, ClearTextOnFocus = false,
            TextStrokeColor3 = black, TextStrokeTransparency = 0.75,
        })
        font(object, false); stroke(object)
        return object
    end
    -- Game/event callbacks may lack permission to read an executor's protected
    -- CoreGui instance. Keep our own controls in the normal player UI container.
    assert(playerGui, "PlayerGui is unavailable; wait for the player's UI to load")
    api.UIParent = "PlayerGui"
    screen = create("ScreenGui", playerGui, { Name = "OvertureBasic", ResetOnSpawn = false,
        Enabled = true, DisplayOrder = 10000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    local panel = create("Frame", screen, { Name = "Menu", Position = UDim2.fromOffset(20, 70),
        Size = UDim2.fromOffset(560, 620), BackgroundColor3 = nativeOptions and nativeOptions.BackgroundColor3 or black,
        BackgroundTransparency = nativeOptions and nativeOptions.BackgroundTransparency or 0.25, BorderSizePixel = 0 })
    stroke(panel, nativeStroke and nativeStroke.Color or lineColor,
        nativeStroke and nativeStroke.Thickness or 1.5, nativeStroke and nativeStroke.Transparency or 0.5)
    create("Frame", panel, { Name = "TopRule", Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = textColor, BorderSizePixel = 0 })
    local header = create("Frame", panel, { Name = "DragHeader", Size = UDim2.new(1, -62, 0, 40),
        BackgroundTransparency = 1, Active = true, ZIndex = 10 })
    label(header, "O V E R T U R E", UDim2.fromOffset(14, 6), UDim2.new(1, -16, 0, 30), textColor, 22, true)
    local hide = button(panel, "−", UDim2.new(1, -48, 0, 8), UDim2.fromOffset(34, 28))
    hide.Name = "HideMenu"; hide.ZIndex = 10
    local status = label(panel, api.Status, UDim2.fromOffset(14, 42), UDim2.new(1, -28, 0, 34), muted, 13)
    status.TextWrapped = true
    local tabs = create("Frame", panel, { Name = "Tabs", Position = UDim2.fromOffset(14, 84),
        Size = UDim2.new(1, -28, 0, 32), BackgroundTransparency = 1, ZIndex = 10 })
    local tabButtons, tabRules = {}, {}
    local tabNames = { "Skills", "Buffs", "Players", "Classes", "Progress", "World", "Extras" }
    for index, name in ipairs(tabNames) do
        local control = button(tabs, string.upper(name), UDim2.new((index - 1) / #tabNames, 0, 0, 0), UDim2.new(1 / #tabNames, -3, 1, 0))
        control.Name = name .. "Tab"; control.TextSize = 12; control.BackgroundTransparency = 1
        tabButtons[name] = control
        tabRules[name] = create("Frame", control, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
            BackgroundColor3 = textColor, BorderSizePixel = 0, Visible = false })
    end
    local search = input(panel, "", UDim2.fromOffset(14, 126), UDim2.new(1, -28, 0, 32))
    search.Name = "Search"; search.PlaceholderText = "SEARCH THIS TAB..."; search.TextXAlignment = Enum.TextXAlignment.Left
    search.ZIndex = 10
    create("UIPadding", search, { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) })
    local body = create("ScrollingFrame", panel, { Name = "Options", Position = UDim2.fromOffset(14, 170),
        Size = UDim2.new(1, -28, 1, -220), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = muted, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true, Active = true })
    create("UIListLayout", body, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
    create("UIPadding", body, { PaddingBottom = UDim.new(0, 12), PaddingRight = UDim.new(0, 6) })
    local activeTab, entries, rows, numbers = "Skills", {}, {}, {}
    local query = ""
    local potionPickers = {}
    local refreshClassRows = function() end
    local refreshPlayerRows = function() end
    local function register(frame, title, description, tab)
        local entry = { Frame = frame, Tab = tab, Search = string.lower(title .. " " .. description), Available = true }
        table.insert(entries, entry)
        return entry
    end
    local function potionWarning(tab, prefix)
        local red = Color3.fromRGB(255, 70, 70)
        local frame = create("Frame", body, { Name = prefix .. "PotionWarning", Size = UDim2.new(1, -3, 0, 120),
            BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.1, BorderSizePixel = 0, LayoutOrder = -100 })
        stroke(frame, red, 2, 0)
        register(frame, "Potion ban warning", "Blatant potion mods ban risk 1000 maximum", tab).Sticky = true
        label(frame, "POTIONS ARE BLATANT", UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 28), red, 20, true)
        local warning = label(frame, "BAN RISK. Any potion mod can get you banned.\nNo amount is verified safe. Default: 1. Cap: 1,000.",
            UDim2.fromOffset(10, 40), UDim2.new(1, -20, 0, 72), red, 14, true)
        warning.TextWrapped = true; warning.TextYAlignment = Enum.TextYAlignment.Top
    end
    potionWarning("Buffs", "")
    potionWarning("Players", "Player")
    local function settingFrame(title, description, tab, order, height, controlWidth)
        local frame = create("Frame", body, { Name = title, Size = UDim2.new(1, -3, 0, height or 74),
            BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order })
        local reserve = (controlWidth or 84) + 12
        local heading = label(frame, string.upper(title), UDim2.fromOffset(8, 3), UDim2.new(1, -reserve, 0, 26), textColor, 15, true)
        heading.TextWrapped = true
        local desc = label(frame, description, UDim2.fromOffset(8, 30), UDim2.new(1, -reserve, 0, (height or 74) - 34), muted, 13)
        desc.TextWrapped = true; desc.TextYAlignment = Enum.TextYAlignment.Top
        create("Frame", frame, { Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 1, -1),
            BackgroundColor3 = lineColor, BackgroundTransparency = 0.3, BorderSizePixel = 0 })
        local entry = register(frame, title, description, tab)
        entry.Heading = heading; entry.Description = desc; entry.BaseHeight = height or 74; entry.Reserve = reserve
        return frame, desc, entry
    end
    local function row(title, description, key, tab, order, profile, setter, prefix)
        profile = profile or settings; setter = setter or api.Set
        local frame = settingFrame(title, description, tab, order)
        local toggle = button(frame, "", UDim2.new(1, -74, 0.5, -17), UDim2.fromOffset(68, 34))
        toggle.Name = (prefix or "") .. key
        press(toggle, function() setter(key, not profile[key]) end)
        table.insert(rows, { Toggle = toggle, Key = key, Profile = profile })
    end
    local function actionRow(title, description, tab, order, caption, callback)
        local frame, info, entry = settingFrame(title, description, tab, order, 78, 100)
        local control = button(frame, caption, UDim2.new(1, -92, 0.5, -17), UDim2.fromOffset(86, 34))
        if callback then press(control, callback)
        else
            control.AutoButtonColor = false; control.TextColor3 = muted
            control.Active = false; control.Interactable = false; control.Selectable = false
        end
        return control, info, entry
    end
    local function numberRow(title, description, key, tab, order, profile, setter, prefix)
        profile = profile or settings; setter = setter or api.Set
        local frame = settingFrame(title, description, tab, order, 86, 132)
        local minus = button(frame, "−", UDim2.new(1, -128, 0.5, -17), UDim2.fromOffset(28, 34))
        local value = input(frame, tostring(profile[key]), UDim2.new(1, -96, 0.5, -17), UDim2.fromOffset(58, 34))
        value.Name = (prefix or "") .. key .. "Input"
        local plus = button(frame, "+", UDim2.new(1, -34, 0.5, -17), UDim2.fromOffset(28, 34))
        press(minus, function() setter(key, profile[key] - 1) end)
        press(plus, function() setter(key, profile[key] + 1) end)
        connect(value.FocusLost, function()
            local parsed = tonumber(value.Text)
            if not parsed or not setter(key, parsed) then
                actionMessage((key == "PotionLimit" or key == "PotionStacks") and "Enter a finite count from 1 to 1,000; 0/unlimited is disabled" or ("Enter a finite number for " .. string.lower(title)))
            end
            value.Text = tostring(profile[key])
        end)
        table.insert(numbers, { Input = value, Key = key, Profile = profile })
    end
    row("Infinite stamina", "Keeps the current class's stamina full.", "InfiniteStamina", "Skills", 1)
    row("Unlimited skill charges", "Refills enabled skills, including talent skills.", "InfiniteCharges", "Skills", 2)
    row("No skill cooldown", "Clears recharge timers and refills charges.", "NoCooldown", "Skills", 3)
    row("No stun / move recovery", "Suppresses hitstun and bypasses move entry locks.", "NoStun", "Skills", 4)
    row("Secret move prerequisites", "Verified local talent, resource and counter gates. Class reload resets granted talents.", "SecretRequirements", "Skills", 5)
    row("Enable all-moves combo", "Enables the cast button and bound key. Off by default.", "ComboEnabled", "Skills", 6)
    local castButton = actionRow("All moves", "Dispatch the class's moves. Press again to cancel.", "Skills", 7, "CAST ALL", api.CastAll)
    row("Move stacking", "Bypasses entry locks. A new move can replace the current action.", "MoveStacking", "Skills", 8)
    row("Include dash", "Includes dash callbacks in the combo.", "IncludeDash", "Skills", 9)
    local bindButton = actionRow("Combo key", "Press to bind a key. F4 stays the menu key; Escape cancels.", "Skills", 10, settings.ComboKey, function()
        capturingComboKey = true; actionMessage("Press a combo key; Escape cancels")
    end)
    row("All classes' moves", "Rotate enabled classes and cast their native moves after each real spawn.", "ComboAllClasses", "Skills", 11)
    row("Allow class resets", "Rotation respawns between classes and leaves the last active. Normal lives apply.", "ComboAllowClassResets", "Skills", 12)
    local comboStatusFrame = create("Frame", body, { Name = "ComboStatus", Size = UDim2.new(1, -3, 0, 116), BackgroundTransparency = 1, LayoutOrder = 13 })
    register(comboStatusFrame, "Combo status", "Native moves current all class rotation callbacks progress", "Skills")
    local comboStatusLabel = label(comboStatusFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    comboStatusLabel.TextWrapped = true
    row("Maximum attribute bonuses", "Compensates up to recovered potion bonuses without multiplying the same bonus twice.", "AttributeBuffs", "Buffs", 9)
    row("Automatic potion effects", "Maintains the selected effects. Normal potions take priority and are never removed.", "PotionBuffs", "Buffs", 1)
    local function potionPicker(tab, order, prefix, profile, setter, selectPotions)
        local picker = { Open = false, Profile = profile, Options = {} }
        picker.Frame = create("Frame", body, { Name = prefix .. "PotionDropdown", Size = UDim2.new(1, -3, 0, 80),
            BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order })
        register(picker.Frame, prefix == "" and "Active potion effects" or "Target potion effects",
            "Water Crystal Earth Wind Blood regeneration shield defense speed power selection", tab)
        label(picker.Frame, prefix == "" and "ACTIVE POTION EFFECTS" or "TARGET POTION EFFECTS",
            UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 26), textColor, 15, true)
        picker.Button = button(picker.Frame, "", UDim2.fromOffset(8, 30), UDim2.new(1, -16, 0, 38))
        picker.Button.Name = prefix .. "PotionSelection"
        picker.List = create("Frame", picker.Frame, { Name = prefix .. "Choices", Position = UDim2.fromOffset(8, 74),
            Size = UDim2.new(1, -16, 0, 228), BackgroundColor3 = black, BackgroundTransparency = 0.15,
            BorderSizePixel = 0, Visible = false })
        stroke(picker.List)
        local descriptions = { "Regeneration", "Shield", "Defense", "Movement speed", "Power" }
        for index, spec in ipairs(potionSpecs) do
            local key, name = spec[5], string.upper(string.sub(spec[1], 8))
            local option = button(picker.List, "", UDim2.fromOffset(6, 6 + (index - 1) * 36), UDim2.new(1, -12, 0, 32))
            option.Name = prefix .. key .. "Option"
            local box = create("Frame", option, { Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(14, 14),
                BackgroundColor3 = textColor, BorderSizePixel = 0 })
            stroke(box, muted)
            label(option, name .. "  /  " .. descriptions[index], UDim2.fromOffset(33, 0), UDim2.new(1, -41, 1, 0), textColor, 14)
            press(option, function() setter(key, not profile[key]) end)
            table.insert(picker.Options, { Box = box, Button = option, Key = key })
        end
        local all = button(picker.List, "ALL", UDim2.new(0, 6, 1, -36), UDim2.new(1 / 3, -8, 0, 30))
        local none = button(picker.List, "NONE", UDim2.new(1 / 3, 3, 1, -36), UDim2.new(1 / 3, -8, 0, 30))
        local done = button(picker.List, "DONE", UDim2.new(2 / 3, 0, 1, -36), UDim2.new(1 / 3, -8, 0, 30))
        press(picker.Button, function() picker.Open = not picker.Open; updateMenu() end)
        press(all, function()
            local selected = {}; for _, spec in ipairs(potionSpecs) do table.insert(selected, spec[1]) end
            selectPotions(selected)
        end)
        press(none, function() selectPotions({}) end)
        press(done, function() picker.Open = false; updateMenu() end)
        function picker:Refresh()
            local selected = {}
            for _, spec in ipairs(potionSpecs) do if profile[spec[5]] then table.insert(selected, string.upper(string.sub(spec[1], 8))) end end
            local caption = #selected == 0 and "NO EFFECTS SELECTED" or (#selected == 1 and selected[1] or (#selected .. " EFFECTS SELECTED"))
            set(self.Button, "Text", caption .. (self.Open and "  −" or "  +"))
            set(self.List, "Visible", self.Open)
            set(self.Frame, "Size", UDim2.new(1, -3, 0, self.Open and 310 or 80))
            for _, item in ipairs(self.Options) do
                set(item.Box, "BackgroundTransparency", profile[item.Key] and 0 or 1)
                set(item.Button, "BackgroundTransparency", profile[item.Key] and 0.2 or 0.7)
            end
        end
        table.insert(potionPickers, picker)
        return picker
    end
    potionPicker("Buffs", 0, "", settings, api.Set, api.SetPotions)
    row("Potion upgrades", "Applies both recovered upgrades and conditional bonuses to added copies. Off by default.", "MaxBuffs", "Buffs", 4)
    row("Stack potion effects", "Uses the per-type target below. Normal copies of the same type count toward it.", "StackPotions", "Buffs", 5)
    numberRow("Copies per type", "1-1,000 copies when stacking is enabled. The cap does not make potions safe.", "PotionStacks", "Buffs", 6)
    numberRow("Total effect budget", "1-1,000 total effects, including normal potions. Zero/unlimited is disabled.", "PotionLimit", "Buffs", 7)
    local potionSummaryFrame = create("Frame", body, { Name = "PotionSummary", Size = UDim2.new(1, -3, 0, 60),
        BackgroundTransparency = 1, LayoutOrder = 8 })
    register(potionSummaryFrame, "Potion status", "Normal active queued automatic effects", "Buffs")
    local potionSummary = label(potionSummaryFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    potionSummary.TextWrapped = true
    local playerDropdownOpen, playerChoices = false, {}
    local playerFrame = create("Frame", body, { Name = "PlayerDropdown", Size = UDim2.new(1, -3, 0, 80),
        BackgroundTransparency = 1, LayoutOrder = 0 })
    register(playerFrame, "Selected player", "Teammate target player potion controller support", "Players")
    label(playerFrame, "SELECTED PLAYER", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 0, 26), textColor, 15, true)
    local playerSelect = button(playerFrame, "SELECT A PLAYER", UDim2.fromOffset(8, 30), UDim2.new(1, -16, 0, 38))
    playerSelect.Name = "PlayerSelection"
    local playerList = create("ScrollingFrame", playerFrame, { Name = "PlayerChoices", Position = UDim2.fromOffset(8, 74),
        Size = UDim2.new(1, -16, 0, 180), BackgroundColor3 = black, BackgroundTransparency = 0.2,
        BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false })
    create("UIListLayout", playerList, { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
    refreshPlayerRows = function()
        local available, selectedName = {}, "SELECT A PLAYER"
        for index, other in ipairs(api.ListPlayers()) do
            available[other.UserId] = true
            if other.Selected then selectedName = other.Name end
            local option = playerChoices[other.UserId]
            if not option then
                local id = other.UserId
                option = button(playerList, "", UDim2.new(), UDim2.new(1, -6, 0, 32))
                option.Name = "PlayerOption_" .. tostring(id); playerChoices[id] = option
                press(option, function()
                    api.SelectPlayer(id); playerDropdownOpen = false; updateMenu()
                end)
            end
            set(option, "Visible", true); set(option, "LayoutOrder", index)
            set(option, "Text", (other.Selected and "> " or "") .. other.Name)
        end
        for id, option in pairs(playerChoices) do if not available[id] then set(option, "Visible", false) end end
        set(playerSelect, "Text", selectedName .. (playerDropdownOpen and "  −" or "  +"))
        set(playerList, "Visible", playerDropdownOpen)
        set(playerFrame, "Size", UDim2.new(1, -3, 0, playerDropdownOpen and 262 or 80))
    end
    press(playerSelect, function() playerDropdownOpen = not playerDropdownOpen; updateMenu() end)
    local targetControls = {}
    targetControls.Inspect = actionRow("Inspect selected player", "Checks this client's target data without sending a game request.", "Players", 2, "INSPECT", function()
        local result = api.InspectPlayer(nil, true)
        actionMessage(result.Available and (result.DirectAvailable and "Target gameplay data found locally" or result.ControllerRoute) or result.Reason)
    end)
    targetControls.Direct = actionRow("Apply target settings", "Use Players settings on an available local controller. Your character is not required.",
        "Players", 3, "APPLY", function() api.ApplyPlayerOverrides() end)
    targetControls.Direct.Name = "ApplyTargetSettings"
    targetControls.Hit = actionRow("Request target potions", "Manual potion hit from your living allied character. Uses the target budget; server result unconfirmed.",
        "Players", 4, "REQUEST", function() api.RequestPlayerPotions() end)
    targetControls.Hit.Name = "RequestTargetPotions"
    targetControls.Upgrades = actionRow("Target class upgrades", "Temporary talents for the active local target. Does not grant account progression.",
        "Players", 5, "GRANT", api.GrantPlayerUpgrades)
    targetControls.Upgrades.Name = "GrantTargetUpgrades"
    actionRow("Stop player attempts", "Cancel queued hits and restore direct edits. Previously sent effects expire through the game.", "Players", 6, "STOP", function() api.StopPlayerEffects(false) end)
    actionRow("Reset target settings", "Reset the Players controls and stop target attempts. Keeps your own settings.",
        "Players", 7, "RESET", api.ResetPlayerSettings)
    local playerReportFrame = create("Frame", body, { Name = "PlayerReport", Size = UDim2.new(1, -3, 0, 186), BackgroundTransparency = 1, LayoutOrder = 1 })
    register(playerReportFrame, "Target capabilities", "Player target availability local direct effects hit request status", "Players").Sticky = true
    local playerReportLabel = label(playerReportFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    playerReportLabel.TextWrapped = true
    for index, spec in ipairs({
        { "Target stamina", "Keep the target controller's stamina full.", "InfiniteStamina" },
        { "Target skill charges", "Refill the target's enabled skill charges.", "InfiniteCharges" },
        { "Target cooldowns", "Clear target recharge timers and refill enabled skills.", "NoCooldown" },
        { "Target stun recovery", "Suppress target hitstun and move entry locks.", "NoStun" },
        { "Target move stacking", "Bypass the target controller's move entry locks.", "MoveStacking" },
        { "Target secret prerequisites", "Local class gates and temporary talents; class reload resets them.", "SecretRequirements" },
        { "Target attribute bonuses", "Apply recovered potion attribute caps to target stats.", "AttributeBuffs" },
        { "Target movement speed", "Enable the separate target speed value below.", "SpeedEnabled" },
    }) do row(spec[1], spec[2], spec[3], "Players", index + 9, playerSettings, api.SetPlayerSetting, "Player") end
    numberRow("Target base speed", "Used only by the target movement speed toggle.", "WalkSpeed", "Players", 18, playerSettings, api.SetPlayerSetting, "Player")
    potionPicker("Players", 20, "Player", playerSettings, api.SetPlayerSetting, api.SetPlayerPotions)
    row("Target automatic potions", "Maintain selected target effects only while direct local mode is active. Does not repeat native hit requests.", "PotionBuffs", "Players", 21, playerSettings, api.SetPlayerSetting, "Player")
    row("Target potion upgrades", "Apply recovered upgrades to added target copies or a manually requested hit.", "MaxBuffs", "Players", 22, playerSettings, api.SetPlayerSetting, "Player")
    row("Target potion stacking", "Use the target copies-per-type value in direct local mode.", "StackPotions", "Players", 23, playerSettings, api.SetPlayerSetting, "Player")
    numberRow("Target copies per type", "1-1,000 copies; independent of your own potion count. No amount is verified safe.", "PotionStacks", "Players", 24, playerSettings, api.SetPlayerSetting, "Player")
    numberRow("Target total effect budget", "1-1,000 total, including normal potions and recent requests. Zero is disabled.", "PotionLimit", "Players", 25, playerSettings, api.SetPlayerSetting, "Player")
    local targetSummaryFrame = create("Frame", body, { Name = "TargetPotionSummary", Size = UDim2.new(1, -3, 0, 78), BackgroundTransparency = 1, LayoutOrder = 26 })
    register(targetSummaryFrame, "Target potion status", "Target added normal queued positive budget", "Players")
    local targetPotionSummary = label(targetSummaryFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    targetPotionSummary.TextWrapped = true
    local classFilter, classFilters = "All", {}
    local browser = create("Frame", body, { Name = "ClassBrowser", Size = UDim2.new(1, -3, 0, 198), BackgroundTransparency = 1, LayoutOrder = 1 })
    register(browser, "Browse characters", "Class character preview choose filter unlocked locked hidden", "Classes").Sticky = true
    label(browser, "ALL LOADED CHOICES", UDim2.fromOffset(8, 0), UDim2.new(1, -88, 0, 24), textColor, 13, true)
    local allClasses = button(browser, "", UDim2.new(1, -74, 0, 0), UDim2.fromOffset(68, 24))
    allClasses.Name = "UnlockAllCharacters"
    press(allClasses, function() api.Set("UnlockAllCharacters", not settings.UnlockAllCharacters) end)
    table.insert(rows, { Toggle = allClasses, Key = "UnlockAllCharacters", Profile = settings })
    local previewTitle = label(browser, "BROWSE A CHARACTER", UDim2.fromOffset(8, 28), UDim2.new(1, -16, 0, 24), textColor, 17, true)
    local previewInfo = label(browser, "Select a class below to preview it.", UDim2.fromOffset(8, 54), UDim2.new(1, -16, 0, 48), muted, 12)
    previewInfo.TextWrapped = true
    local chooseClass = button(browser, "CHOOSE", UDim2.fromOffset(8, 108), UDim2.new(0.5, -12, 0, 30))
    chooseClass.Name = "ChoosePreviewedClass"
    local chooseReset = button(browser, "CHOOSE + RESET", UDim2.new(0.5, 4, 0, 108), UDim2.new(0.5, -12, 0, 30))
    chooseReset.Name = "ChooseAndRespawn"
    press(chooseClass, function() api.SelectCharacter(classFlow.PreviewName) end)
    press(chooseReset, function()
        local ok = api.SelectCharacter(classFlow.PreviewName)
        if ok then api.ForceRespawn() end
    end)
    for index, name in ipairs({ "All", "Unlocked", "Locked", "Hidden" }) do
        local filterName = name
        local control = button(browser, string.upper(name), UDim2.new((index - 1) / 4, 8, 0, 146), UDim2.new(0.25, -12, 0, 26))
        control.Name = "ClassFilter_" .. name; control.TextSize = 12; classFilters[name] = control
        press(control, function() classFilter = filterName; body.CanvasPosition = Vector2.zero; updateMenu() end)
    end
    local classCounts = label(browser, "", UDim2.fromOffset(8, 178), UDim2.new(1, -16, 0, 20), muted, 11)
    local classStatusFrame = create("Frame", body, { Name = "ClassSelectionStatus", Size = UDim2.new(1, -3, 0, 90),
        BackgroundTransparency = 1, LayoutOrder = 2 })
    register(classStatusFrame, "Class selection status", "Chosen requested active activation native selector", "Classes").Sticky = true
    local classStatus = label(classStatusFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    classStatus.TextWrapped = true
    local classRows = {}
    refreshClassRows = function()
        local seen, loaded, unlocked, hidden, filtered = {}, api.ListCharacters(), 0, 0, 0
        local selected
        for _, class in ipairs(loaded) do
            if class.Name == classFlow.PreviewName then selected = class end
            if class.Unlocked then unlocked += 1 end
            if class.Hidden then hidden += 1 end
        end
        if not selected then
            for _, class in ipairs(loaded) do if class.Chosen or class.Active then selected = class; break end end
            selected = selected or loaded[1]
            classFlow.PreviewName = selected and selected.Name or nil
        end
        for _, class in ipairs(loaded) do
            seen[class.Name] = true
            if not classRows[class.Name] then
                local name = class.Name
                local control, _, entry = actionRow(class.Title, name .. " / preview class", "Classes", class.Index + 10, "VIEW", function() api.PreviewCharacter(name) end)
                control.Name = "Choose_" .. name
                classRows[name] = { Button = control, Entry = entry }
            end
            local item = classRows[class.Name]
            local matches = classFilter == "All" or (classFilter == "Unlocked" and class.Unlocked)
                or (classFilter == "Locked" and not class.Unlocked) or (classFilter == "Hidden" and class.Hidden)
            item.Entry.Available = matches; item.Entry.Frame.LayoutOrder = class.Index + 10
            item.Entry.Search = string.lower(class.Title .. " " .. class.Name
                .. (class.Hidden and " hidden" or "") .. (class.Unlocked and " unlocked" or " locked"))
            if matches and (query == "" or string.find(item.Entry.Search, query, 1, true)) then filtered += 1 end
            local request = api.LastCharacterRequest
            local pending = request and request.Name == class.Name and not request.Confirmed and not request.Cancelled and not request.Failed
            local caption = class.Active and class.Chosen and "ACTIVE"
                or (pending and request.Sent and "REQUESTED") or (class.Chosen and "CHOSEN")
                or (classFlow.PreviewName == class.Name and "VIEWING") or "VIEW"
            set(item.Button, "Text", caption)
            set(item.Button, "BackgroundTransparency", classFlow.PreviewName == class.Name and 0.15 or 0.5)
            set(item.Entry.Description, "Text", "Account " .. (class.Unlocked and "unlocked" or "locked")
                .. (class.Hidden and " / hidden" or "") .. (class.Active and " / active now" or "")
                .. (class.Chosen and " / chosen for spawn" or "") .. " / " .. class.Name)
        end
        for name, item in pairs(classRows) do if not seen[name] then item.Entry.Available = false end end
        local canChoose = selected ~= nil and (settings.UnlockAllCharacters or selected.Unlocked)
        enableButton(chooseClass, canChoose); enableButton(chooseReset, canChoose)
        set(chooseClass, "Text", canChoose and "CHOOSE" or "LOCKED")
        set(previewTitle, "Text", selected and string.upper(selected.Title) or "WAITING FOR CLASSES")
        local detail = selected and (selected.Name .. (selected.Hidden and " / HIDDEN" or "")
            .. "\nAccount " .. (selected.Unlocked and "unlocked" or "locked / local choices only")
            .. (selected.Description ~= "" and ("\n" .. string.sub(selected.Description, 1, 60)) or ""))
            or "The loaded game class database will appear here."
        set(previewInfo, "Text", detail)
        set(classCounts, "Text", #loaded .. " LOADED / " .. unlocked .. " UNLOCKED / " .. hidden .. " HIDDEN / " .. filtered .. " SHOWN")
        for name, control in pairs(classFilters) do set(control, "BackgroundTransparency", classFilter == name and 0.15 or 0.7) end
        local state = api.InspectCharacterSelection()
        local request = state.LastRequest
        set(classStatus, "Text", "CHOSEN: " .. tostring(state.Chosen or "none") .. "\nACTIVE: " .. tostring(state.Active or "none")
            .. "\n" .. (request and request.Stage or "Viewing does not choose. Choose uses the native selector; reset spends a normal spawn.")
            .. "\nAccount unlocks and activation still depend on the game.")
    end
    actionRow("All class upgrades", "Grants current-class talents. Their effects reset on class reload.", "Progress", 1, "GRANT", api.GrantUpgrades)
    local forceReset = actionRow("Force respawn", "Runs the game's class teardown before requesting a fresh spawn, including while alive. Game rules and remaining lives apply.", "Progress", 2, "RESET", api.ForceRespawn)
    forceReset.Name = "ForceRespawn"
    local revive = actionRow("Respawn after death", "Uses native cleanup for a dead controller, then waits for an actual new controller.", "Progress", 3, "REQUEST", function() api.RequestRespawn(false) end)
    revive.Name = "RespawnAfterDeath"
    row("Auto respawn request", "One attempt per death. Waits for a new controller instead of repeatedly sending requests.", "AutoRespawn", "Progress", 4)
    local respawnStatusFrame = create("Frame", body, { Name = "RespawnStatus", Size = UDim2.new(1, -3, 0, 104), BackgroundTransparency = 1, LayoutOrder = 5 })
    register(respawnStatusFrame, "Respawn status", "Reset cleanup request confirmation controller", "Progress")
    local respawnStatusLabel = label(respawnStatusFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    respawnStatusLabel.TextWrapped = true
    actionRow("Infinite lives", "Lives are server controlled; no working bypass was established.", "Progress", 6, "UNAVAILABLE", nil)
    actionRow("Permanent unlocks", "Local choices and temporary talents do not grant account unlocks.", "Progress", 7, "UNVERIFIED", nil)
    local worldStatusFrame = create("Frame", body, { Name = "WorldStatus", Size = UDim2.new(1, -3, 0, 164), BackgroundTransparency = 1, LayoutOrder = 0 })
    register(worldStatusFrame, "NPC and round status", "NPC kill bring auto win round skip vote requests observed", "World").Sticky = true
    local worldStatusLabel = label(worldStatusFrame, "", UDim2.fromOffset(8, 0), UDim2.new(1, -16, 1, 0), muted, 13)
    worldStatusLabel.TextWrapped = true
    local worldControls = {}
    worldControls.Kill = actionRow("Kill all NPCs", "Requests native damage against loaded NPCs; players are excluded. Results are observed below.", "World", 1, "KILL", api.KillAllNPCs)
    worldControls.Kill.Name = "KillAllNPCs"
    worldControls.Bring = actionRow("Bring all NPCs", "Requests source-relative pulls toward your position. Immunity and server rules still apply.", "World", 2, "BRING", api.BringAllNPCs)
    worldControls.Bring.Name = "BringAllNPCs"
    row("Auto win / clear enemies", "Repeated NPC clearing with progress checks. The game decides the round result.", "AutoWinRound", "World", 3)
    worldControls.Skip = actionRow("Skip round vote", "Uses the native skip vote. A recorded vote does not force phase or round advancement.", "World", 4, "VOTE", api.SkipRound)
    worldControls.Skip.Name = "SkipRound"
    actionRow("Stop world commands", "Stop NPC attempts and automatic clearing. Earlier requests may still complete.", "World", 5, "STOP", api.StopWorldCommands)
    row("Include allied NPCs", "Include allied NPCs in bulk commands. Player characters are always excluded.", "NPCIncludeAllies", "World", 6)
    numberRow("NPC damage per attempt", "1-800, matching the native hit handler's clamp. This is not a detection-safe range.", "NPCDamage", "World", 7)
    numberRow("NPC attempt budget", "1-30 attempts without progress. NPC clearing pauses when health does not change.", "NPCRetries", "World", 8)
    local saveButton, saveInfo = actionRow("Saved settings", config.Status, "Extras", -3, "SAVE NOW", function()
        local ok, message = api.SaveSettings(); actionMessage(ok and "Settings saved" or message)
    end)
    actionRow("Load saved settings", "Reload saved toggles, selected potions, counts and combo key.", "Extras", -2, "LOAD", api.LoadSettings)
    actionRow("Conservative preset", "Disables gameplay overrides. Previously granted talents need a class reload to reset.", "Extras", -1, "APPLY", api.ApplyConservativePreset)
    row("Movement speed", "Changes base speed while keeping action slowdowns.", "SpeedEnabled", "Extras", 1)
    numberRow("Base movement speed", "Used only when movement speed is enabled.", "WalkSpeed", "Extras", 2)
    row("No camera shake", "Disables the game's camera shake multiplier.", "NoCameraShake", "Extras", 3)
    row("Enemy ESP", "Highlights up to 24 nearby opposing entities.", "EnemyESP", "Extras", 4)
    local noResults = label(body, "NO MATCHING OPTIONS", UDim2.new(), UDim2.new(1, -8, 0, 46), muted, 14)
    noResults.Name = "NoResults"; noResults.LayoutOrder = 1000000; noResults.Visible = false
    local footer = create("Frame", panel, { Position = UDim2.new(0, 14, 1, -40),
        Size = UDim2.new(1, -28, 0, 28), BackgroundTransparency = 1, ZIndex = 10 })
    local hint = label(footer, "F4 / SHOW OR HIDE", UDim2.fromOffset(0, 0), UDim2.new(1, -192, 1, 0), muted, 11)
    local reconnect = button(footer, "RECONNECT", UDim2.new(1, -186, 0, 0), UDim2.fromOffset(100, 28))
    local unload = button(footer, "UNLOAD", UDim2.new(1, -80, 0, 0), UDim2.fromOffset(80, 28))
    press(reconnect, api.Refresh); press(unload, api.Unload)
    local opener = button(screen, "OT", UDim2.new(1, -56, 0, 88), UDim2.fromOffset(42, 40))
    opener.Name = "Opener"; opener.ZIndex = 20
    local function layout()
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
        local width, height = math.min(560, math.max(1, viewport.X - 24)), math.min(620, math.max(1, viewport.Y - 52))
        set(panel, "Size", UDim2.fromOffset(width, height))
        set(panel, "Position", UDim2.fromOffset(math.clamp(panel.Position.X.Offset, 8, math.max(8, viewport.X - width - 8)),
            math.clamp(panel.Position.Y.Offset, 8, math.max(8, viewport.Y - height - 32))))
        set(hint, "Text", width < 400 and "F4" or "F4 / SHOW OR HIDE")
        local tabWidth = (width - 28) / #tabNames - 3
        for _, control in pairs(tabButtons) do set(control, "TextSize", tabWidth < 50 and 10 or 12) end
        local narrow = width < 400
        for _, entry in ipairs(entries) do
            if entry.BaseHeight then
                local rowHeight = entry.BaseHeight + (narrow and 20 or 0)
                set(entry.Frame, "Size", UDim2.new(1, -3, 0, rowHeight))
                set(entry.Heading, "Size", UDim2.new(1, -entry.Reserve, 0, narrow and 32 or 26))
                set(entry.Description, "Position", UDim2.fromOffset(8, narrow and 38 or 30))
                set(entry.Description, "Size", UDim2.new(1, -entry.Reserve, 0, rowHeight - (narrow and 42 or 34)))
            end
        end
    end
    local function navigation()
        -- Never put gameplay inspection before the controls needed to recover
        -- the menu. This also runs before and after dynamic rows are added.
        set(screen, "Enabled", true)
        set(opener, "Visible", not panel.Visible)
        local visible = 0
        for _, entry in ipairs(entries) do
            local show = entry.Available and entry.Tab == activeTab and (entry.Sticky or query == "" or string.find(entry.Search, query, 1, true) ~= nil)
            set(entry.Frame, "Visible", show)
            if show and not entry.Sticky then visible += 1 end
        end
        set(noResults, "Visible", visible == 0)
        for name, control in pairs(tabButtons) do
            set(control, "TextColor3", activeTab == name and textColor or muted)
            set(tabRules[name], "Visible", activeTab == name)
        end
        layout()
    end
    local function menuVisible(visible)
        if not api.Running or not screen then return false end
        panel.Visible = visible
        if not visible then
            capturingComboKey = false; playerDropdownOpen = false
            for _, picker in ipairs(potionPickers) do picker.Open = false end
            pcall(function()
                local focused = UserInputService:GetFocusedTextBox()
                local ancestor = focused
                while ancestor and ancestor ~= panel do ancestor = ancestor.Parent end
                if ancestor == panel then focused:ReleaseFocus() end
            end)
        end
        navigation(); updateMenu()
        return true
    end
    function api.ShowMenu() return menuVisible(true) end
    function api.HideMenu() return menuVisible(false) end
    function api.ToggleMenu() return menuVisible(not panel.Visible) end
    function api.SelectTab(name)
        if not api.Running or not tabButtons[name] then return false end
        activeTab = name; playerDropdownOpen = false; capturingComboKey = false
        for _, picker in ipairs(potionPickers) do picker.Open = false end
        query = ""; search.Text = ""; body.CanvasPosition = Vector2.zero
        navigation(); updateMenu()
        return true
    end
    toggleMenuHotkey = api.ToggleMenu
    press(hide, api.HideMenu); press(opener, api.ShowMenu)
    local uiErrors = {}
    api.UIErrors = uiErrors
    local function refreshPart(name, callback)
        local ok, err = pcall(callback)
        if ok then uiErrors[name] = nil
        else
            local message = tostring(err)
            if uiErrors[name] ~= message then warn("[Overture Basic UI / " .. name .. "] " .. message) end
            uiErrors[name] = message
        end
    end
    updateMenu = function()
        if not screen or not api.Running then return end
        navigation()
        local message = api.Status
        if api.ActionMessage and os.clock() - (api.ActionMessageTime or 0) < 8 then message = api.ActionMessage end
        set(status, "Text", message)
        refreshPart("Classes", refreshClassRows)
        refreshPart("Players", refreshPlayerRows)
        refreshPart("Respawn status", function()
            local respawn = api.InspectRespawn()
            set(respawnStatusLabel, "Text", respawn.Stage .. (respawn.Route and ("\n" .. respawn.Route) or "")
                .. (respawn.Confirmed and "\nFRESH CONTROLLER CONFIRMED" or (respawn.Pending and "\nWAITING FOR A FRESH CONTROLLER" or "")))
        end)
        refreshPart("World status", function()
            local state = api.InspectWorld()
            enableButton(worldControls.Kill, state.SourceAvailable and not state.Pending)
            enableButton(worldControls.Bring, state.SourceAvailable and not state.Pending)
            enableButton(worldControls.Skip, state.NativeSkipAvailable and not (state.LastSkip and state.LastSkip.Pending))
            set(worldStatusLabel, "Text", "LOADED NPCs: " .. state.NPCs .. " / " .. (state.Phase ~= "" and state.Phase or "phase not exposed")
                .. "\n" .. (state.SourceAvailable and state.Stage or state.SourceReason)
                .. "\n" .. state.Requested .. " HIT ATTEMPTS / " .. state.ObservedDefeats .. " DEFEATS / " .. state.ObservedBrought .. " GATHERED OBSERVED"
                .. "\n" .. (state.LastSkip and state.LastSkip.Stage or "No skip vote requested")
                .. "\nAuto win clears NPCs. Server round completion remains unconfirmed.")
        end)
        refreshPart("Player status", function()
            local target = api.InspectPlayer()
            local request = api.LastPlayerRequest
            local capabilities = target.Capabilities or {}
            enableButton(targetControls.Inspect, targetSupport.player() ~= nil)
            enableButton(targetControls.Direct, target.DirectAvailable == true)
            enableButton(targetControls.Hit, target.NativeHitAvailable == true and not target.Pending)
            enableButton(targetControls.Upgrades, target.DirectActive == true and capabilities.Talents == true)
            set(targetControls.Direct, "Text", target.DirectActive and "ACTIVE" or (target.DirectAvailable and "APPLY" or "UNAVAILABLE"))
            set(targetControls.Hit, "Text", target.Pending and "QUEUED" or (target.NativeHitAvailable and "REQUEST" or "UNAVAILABLE"))
            local supported = {}
            for _, spec in ipairs({ { "Skills", "skills" }, { "Resources", "stamina" }, { "Attributes", "stats" }, { "Potions", "potions" }, { "Talents", "talents" } }) do
                if capabilities[spec[1]] then table.insert(supported, spec[2]) end
            end
            set(playerReportLabel, "Text", target.Available and (target.Name .. " / " .. (target.DirectActive and "DIRECT LOCAL MODE ACTIVE"
                or (target.DirectAvailable and "LOCAL EDITS AVAILABLE" or "DIRECT EDITS UNSUPPORTED"))
                .. "\n" .. (target.DirectAvailable and ("Available locally: " .. table.concat(supported, ", ")) or target.ControllerRoute)
                .. "\nHIT REQUEST: " .. (target.NativeHitAvailable and "available; manual request only" or target.NativeHitReason)
                .. "\n" .. (request and request.UserId == target.UserId and request.Stage or "No hit request sent")
                .. "\nPlayers settings are separate. Recipient/server effects remain unconfirmed.") or (target.Reason or "Select a player"))
            local potions = api.InspectPlayerPotions()
            set(targetPotionSummary, "Text", potions.Script .. " TARGET COPIES ADDED / " .. potions.Natural .. " NORMAL"
                .. "\nTARGET BUDGET: " .. potions.Limit .. " / " .. potions.Pending .. " LOCAL COPIES PENDING"
                .. "\nApplies only after starting direct mode. Hit requests remain manual.")
        end)
        for _, item in ipairs(rows) do
            local enabled = item.Profile[item.Key]
            set(item.Toggle, "Text", enabled and "ON" or "OFF")
            set(item.Toggle, "BackgroundColor3", enabled and Color3.fromRGB(0, 20, 0) or Color3.fromRGB(20, 0, 0))
            set(item.Toggle, "TextColor3", enabled and textColor or muted)
        end
        for _, item in ipairs(numbers) do
            if UserInputService:GetFocusedTextBox() ~= item.Input then set(item.Input, "Text", tostring(item.Profile[item.Key])) end
        end
        set(castButton, "Text", comboBusy and "CANCEL" or "CAST ALL")
        local combo = api.LastCombo
        set(comboStatusLabel, "Text", "MODE: " .. (settings.ComboAllClasses and "CLASS ROTATION" or "CURRENT CLASS")
            .. "\n" .. (combo and combo.Mode == "Class rotation" and (combo.ClassesActivated .. "/" .. combo.ClassesPlanned .. " CLASSES ACTIVATED / ") or "")
            .. (combo and tostring(combo.Dispatched) or "0") .. " NATIVE CALLBACKS DISPATCHED"
            .. "\n" .. (combo and string.sub(combo.Stage or "Game/server effects remain unconfirmed", 1, 180)
                or "Enable the combo, choose its mode, then press CAST ALL. Rotation uses normal respawns."))
        set(bindButton, "Text", capturingComboKey and "PRESS KEY" or settings.ComboKey)
        for _, picker in ipairs(potionPickers) do picker:Refresh() end
        refreshPart("Potion status", function()
            local potions = api.InspectPotions()
            local queued = potions.Pending > 0 and (" / " .. tostring(potions.Pending) .. " queued") or ""
            set(potionSummary, "Text", potions.Script .. " ADDED / " .. potions.Natural .. " NORMAL" .. queued
                .. "\nBUDGET: " .. potions.Limit .. " / NORMAL EFFECTS REMAIN UNCHANGED")
        end)
        set(saveButton, "Text", config.Saving and "SAVING" or (config.Dirty and "SAVE NOW" or "SAVED"))
        set(saveInfo, "Text", config.Status .. "\n" .. config.Path)
        api.LastUIError = nil
        for name, err in pairs(uiErrors) do api.LastUIError = name .. ": " .. err; break end
        navigation()
    end
    connect(search:GetPropertyChangedSignal("Text"), function()
        query = string.lower(search.Text); body.CanvasPosition = Vector2.zero; updateMenu()
    end)
    for name, control in pairs(tabButtons) do
        local tabName = name
        press(control, function() api.SelectTab(tabName) end)
    end
    local dragging, startPointer, startPosition
    connect(header.InputBegan, function(pointer)
        if pointer.UserInputType == Enum.UserInputType.MouseButton1 or pointer.UserInputType == Enum.UserInputType.Touch then
            dragging = pointer; startPointer = pointer.Position; startPosition = panel.Position
        end
    end)
    connect(UserInputService.InputChanged, function(pointer)
        if dragging and (pointer == dragging or pointer.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = pointer.Position - startPointer
            panel.Position = UDim2.fromOffset(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y)
            layout()
        end
    end)
    connect(UserInputService.InputEnded, function(pointer) if pointer == dragging then dragging = nil end end)
    updateMenu()
end
toggleMenuHotkey = function() if not screen and api.Running then buildMenu() end end
if settings.ShowUI then buildMenu() end

if UserInputService.InputBegan then
    connect(UserInputService.InputBegan, function(input, processed)
        local key = input.KeyCode
        -- F4 is a recovery control even if a game handler consumes the key or
        -- the menu's search field still has focus. Gameplay hotkeys keep guards.
        if key == Enum.KeyCode.F4 then toggleMenuHotkey(); return end
        if processed or UserInputService:GetFocusedTextBox() then return end
        if capturingComboKey then
            if key == Enum.KeyCode.Escape then capturingComboKey = false; actionMessage("Key binding cancelled")
            elseif key and key ~= Enum.KeyCode.Unknown and api.Set("ComboKey", key.Name) then
                capturingComboKey = false; actionMessage("All moves bound to " .. settings.ComboKey)
            end
            return
        end
        if settings.ComboEnabled and key == Enum.KeyCode[settings.ComboKey] then api.CastAll() end
    end)
end

local function tick()
    if not api.Running then return end
    local now = os.clock()
    if saveDue and now >= saveDue then api.SaveSettings() end
    discover(now)
    local actor = currentActor()
    respawnFlow.tick(now, actor)
    actor = currentActor() -- a queued force reset can tear down the previous actor in this tick
    bind(actor)
    local targetOK, targetError = pcall(targetSupport.tick, now)
    if not targetOK then api.StopPlayerEffects(true); report(targetError) end
    local worldOK, worldError = pcall(worldFlow.tick, now)
    if not worldOK then worldFlow.cancel("NPC maintenance error; earlier requests remain unconfirmed"); report(worldError) end
    local humanoid = actor and rawget(actor, "Humanoid")
    local actorDead = actor and (actor.Dead or (humanoid and humanoid.Health <= 0))
    if actor and not actorDead then
        deathObserved = false; characterRemovedAt = nil
        if not respawnFlow.Pending then respawnFlow.AutoAttempted = false end
    end
    if actorDead then deathObserved = true end
    if settings.AutoRespawn and deathObserved
        and not respawnFlow.Pending and not respawnFlow.AutoAttempted
        and (not characterRemovedAt or now - characterRemovedAt >= 2)
        and now - lastRespawnRequest >= 3 then
        respawnFlow.AutoAttempted = true
        api.RequestRespawn(false)
        actor = currentActor(); bind(actor)
    end
    -- The controller wrapper handles resources at the actual update boundary.
    -- Heartbeat is maintenance/fallback, not another compulsory resource write loop.
    if binding then applyPreferences(actor) else safeApply(actor) end
    if actor then maintainMoves(actor) end
    if now - lastRosterUpdate >= 0.75 then
        lastRosterUpdate = now
        maintainRoster()
    end
    classFlow.tick(now, actor)
    api.Discovery.Route = accessMethod
    if now - lastUI >= 0.25 then
        lastUI = now
        if actor then
            local ready, total = 0, 0
            for _, skill in pairs(actor.Cooldowns) do
                if type(skill) == "table" and finite(skill.MaxCharges) and skill.MaxCharges > 0 then
                    total += 1
                    if finite(skill.Charges) and skill.Charges > 0 then ready += 1 end
                end
            end
            local stamina = finite(actor.Stamina) and (" · stamina " .. string.format("%.2f", actor.Stamina)) or ""
            api.Status = tostring(actor.Name or "Class") .. " · " .. ready .. "/" .. total .. " skills ready" .. stamina
                .. "\nConnected via " .. accessMethod
            if settings.NoCameraShake and not root then
                api.Status = tostring(actor.Name or "Class") .. " · connected\nCamera shake needs global-table access."
            end
        elseif root then
            api.Status = "Connected · waiting for your class / respawn."
        else
            api.Status = "Waiting for Overture. If this persists, use Reconnect."
            if not api.Capabilities.Environments and not api.Capabilities.GC
                and not api.Capabilities.FilterGC and not (api.Capabilities.Connections and api.Capabilities.Upvalues) then
                api.Status = "Client table unavailable. Missing environment / reflection functions."
            end
        end
        updateMenu()
    end
    if now - lastESP >= 0.35 then lastESP = now; refreshHighlights() end
end
connect(RunService.Heartbeat, function()
    local ok, err = pcall(tick)
    if not ok then report(err) end
end)
connect(player.CharacterRemoving, function(removedCharacter)
    -- Character removal alone can also mean a class change. Auto mode is armed
    -- only if the controller or humanoid was observed dead before removal.
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    deathObserved = deathObserved or (controller and controller.Dead == true) or (humanoid and humanoid.Health <= 0) or false
    characterRemovedAt = os.clock()
    targetSupport.cancelHits("Your character was removed; earlier potion requests remain unconfirmed")
    worldFlow.cancel("Source character removed; earlier NPC requests remain unconfirmed")
    detach(comboFlow.Transition and comboFlow.Token == comboToken
        and (removedCharacter == nil or removedCharacter == comboFlow.FromCharacter))
    actorProof = nil; clearHighlights()
end)
if player.OnTeleport then
    connect(player.OnTeleport, function()
        if config.Dirty then api.SaveSettings() end
    end)
end
tick()
return api
