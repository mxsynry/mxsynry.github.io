--[[
    Vanity Fallback Loader

    Usage examples:
      local V = getgenv().Vanity
      V.load("Fission")                           -- set getgenv().decompile to Fission wrapper
      V.load("LuaExpert")                         -- set getgenv().decompile to lua.expert wrapper
      print(V.decompile(scriptInstance))          -- try the default fallback chain
      print(V.disassemble(scriptInstance))        -- try disassembly fallback chain where supported

    Default fallback chain:
      1) StudioSource                             -> returns .Source when accessible in Studio
      2) Fission                                  -> rbxcli.decompile(..., {DecompilationKind="Luau"})
      3) LuaExpert                                -> https://api.lua.expert/decompile
      4) AdvancedV3                               -> w-a-e Advanced-Decompiler-V3
      5) Konstant                                 -> plusgiant5 Konstant API
      6) LunaUX                                   -> self-hosted local LunaUX server
      7) ShinyMedal                               -> self-hosted local Shiny/Medal server

    Not in default chain:
      BetterDecompiler                            -> cleanup wrapper; requires an existing base decompile()
      PseudoLua                                   -> runtime tracer; explicit only
      KurbyHub                                    -> clean reconstructed KurbyHub dump-style module; explicit only
]]

--[[
    EDIT SETTINGS HERE.

    This config block is intentionally placed before the embedded KurbyHub
    reconstruction so users do not need to scroll through the whole source.

    Common edits:
      Config.DefaultChain
      Config.LuaExpert.API
      Config.Fission.DecompilationKind
      Config.Konstant.API
      Config.KurbyHub.Settings
]]

-- ==================== GLOBAL / ENV FALLBACK ====================
local G = (getgenv and getgenv()) or _G
G.Vanity = G.Vanity or {}
local Vanity = G.Vanity

-- ==================== NOTIFICATION FALLBACK ====================
local function notify(title, message)
    title, message = tostring(title), tostring(message)
    local ok = false
    if syn and syn.toast_notification then
        pcall(function() syn.toast_notification(title, message, 5) end); ok = true
    elseif fluxus and fluxus.notify then
        pcall(function() fluxus.notify(title, message, 5) end); ok = true
    elseif rbxcli and rbxcli.display_notification then
        pcall(function() rbxcli.display_notification(title .. ": " .. message, 5) end); ok = true
    end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title, Text = message, Duration = 5
        })
        ok = true
    end)
    if not ok then print(string.format("[%s] %s", title, message)) end
end

local function warnf(fmt, ...)
    warn(string.format(fmt, ...))
end

-- ==================== USER SETTINGS / CONFIG - EDIT THIS FIRST ====================
Vanity.Config = Vanity.Config or {}
local Config = Vanity.Config

Config.DefaultChain = Config.DefaultChain or {
    "StudioSource",
    "Fission",
    "LuaExpert",
    "AdvancedV3",
    "Konstant",
    "LunaUX",
    "ShinyMedal",
}

-- StudioSource: not a decompiler; useful in Studio where .Source is readable.
Config.StudioSource = Config.StudioSource or {
    Enabled = true,
    AcceptModuleScripts = true,
    AcceptLocalScripts = true,
    AcceptClientRunContextScripts = true,
}

-- Fission / rbxcli settings.
Config.Fission = Config.Fission or {
    Enabled = true,
    DecompilationKind = "Luau", -- "Luau" or "IR"
}

-- lua.expert settings.
Config.LuaExpert = Config.LuaExpert or {
    Enabled = true,
    API = "https://api.lua.expert/decompile",
    RateLimit = 0.13, -- docs say 500/min; 0.13s is conservative.
    ContentType = "application/json",
}

-- Advanced Decompiler V3 settings.
Config.AdvancedV3 = Config.AdvancedV3 or {
    Enabled = true,
    InitUrl = "https://raw.githubusercontent.com/w-a-e/Advanced-Decompiler-V3/main/init.lua",
    Options = {
        ShowDebugInformation = false,
        ShowInstructionLines = false,
        ShowOperationNames = false,
        ShowTrivialOperations = false,
        UseTypeInfo = true,
        ListUsedGlobals = true,
        ReturnElapsedTime = false,
    }
}

-- Konstant settings.
Config.Konstant = Config.Konstant or {
    Enabled = true,
    API = "http://api.plusgiant5.com",
    RateLimit = 0.5,
}

-- LunaUX settings: run its local server first, then use this wrapper.
Config.LunaUX = Config.LunaUX or {
    Enabled = false, -- local server must be running; enable manually when available
    API = "http://127.0.0.1:8000",
    Options = {
        Semicolons = false,
        StringInterpolation = true,
        UpvalueComment = true,
        ShowLineDefined = true,
        ShowFunctionId = false,
        PreserveForStep = false,
        UseIfExpression = true,
    }
}

-- Shiny/Medal settings: run `medal serve`/`shiny serve` first.
Config.ShinyMedal = Config.ShinyMedal or {
    Enabled = false, -- local server must be running; enable manually when available
    API = "http://localhost:3000",
    DecompilePath = "/luau/decompile",
}

-- BetterDecompiler settings: cleanup wrapper, not a true bytecode engine.
Config.BetterDecompiler = Config.BetterDecompiler or {
    Enabled = false,
    Url = "https://raw.githubusercontent.com/OfficiallyMelon/BetterDecompiler/refs/heads/main/main.lua",
    UseAI = true,
    CleanupServer = "http://localhost:5000/fix_script",
}

-- PseudoLua settings: runtime tracer. Keep explicit/manual, not default.
Config.PseudoLua = Config.PseudoLua or {
    Enabled = false,
    Url = "https://raw.githubusercontent.com/LegoHacker1337/PseudoLuaDecompiler/refs/heads/main/Decompiler.lua",
}

-- KurbyHub settings.
-- wYnFuscate was only the protection layer in the recovered sample.
Config.KurbyHub = Config.KurbyHub or {
    Enabled = false,
    Settings = {
        ignoreOthers = true,
        ignoreRobloxModules = true,
        modules = true,
        localScripts = true,
        regularScripts = true,
        ignoreDuplicates = true,
        ignoreRemotes = false,
        writeToFile = true,
        useVanityFallback = true,
    }
}

-- ==================== EMBEDDED KURBYHUB RECONSTRUCTION ====================
-- Do not edit this block unless you are maintaining the KurbyHub reconstruction.
-- User-facing settings are above.

local __KURBYHUB_RECONSTRUCTED_SOURCE = [=[--[[
Vanity / KurbyHub reconstructed decompiler-dumper

This is a clean, open-source reconstruction of the Kurby's Hub decompiler.lua
behavior recovered from the obfuscated sample. It is not the exact original
pre-obfuscation source; the protected sample was virtualized by wYnFuscate.

Recovered behavior implemented here:
  * _G settings: ignoreOthers, ignoreRobloxModules, modules, localScripts,
    regularScripts, ignoreDuplicates, ignoreRemotes
  * scan LocalScript / ModuleScript / Script containers
  * reference server Scripts instead of forcing decompilation when configured
  * use .Source when available in Studio
  * fall back to an external decompile() / Vanity chain when .Source is blocked
  * record RemoteEvent / RemoteFunction references and nearby source segments
  * return a full dump string and a structured result table
]]

local G = (getgenv and getgenv()) or _G

local KurbyHub = {}
KurbyHub.Name = "KurbyHub"
KurbyHub.Version = "Vanity-2026.06-reconstructed"

KurbyHub.DEFAULT_SETTINGS = {
    ignoreOthers = true,
    ignoreRobloxModules = true,
    modules = true,
    localScripts = true,
    regularScripts = true,
    ignoreDuplicates = true,
    ignoreRemotes = false,

    -- Extra open-source reconstruction settings.
    roots = nil,                  -- nil means {game}; can be Instance or {Instance,...}
    outputFile = nil,             -- default generated filename when writefile exists
    writeToFile = true,
    duplicateMode = "name_class", -- "name_class" approximates the recovered comment
    contextLines = 3,
    maxSegmentChars = 1200,
    includeEmptySource = false,
    useVanityFallback = true,
    vanityChain = {"StudioSource", "Fission", "LuaExpert", "AdvancedV3", "Konstant", "LunaUX", "ShinyMedal"},
}

local function copy(t)
    local out = {}
    if type(t) == "table" then
        for k, v in pairs(t) do out[k] = v end
    end
    return out
end

local function merge(a, b)
    local out = copy(a)
    if type(b) == "table" then
        for k, v in pairs(b) do out[k] = v end
    end
    return out
end

local function apply_global_settings(settings)
    for k, v in pairs(settings) do
        if KurbyHub.DEFAULT_SETTINGS[k] ~= nil then
            G[k] = v
            _G[k] = v
        end
    end
end

function KurbyHub.configure(settings)
    KurbyHub.Settings = merge(KurbyHub.DEFAULT_SETTINGS, settings or {})
    apply_global_settings(KurbyHub.Settings)
    return KurbyHub.Settings
end

local function get_settings(settings)
    if not KurbyHub.Settings then
        local seeded = {}
        for k, default in pairs(KurbyHub.DEFAULT_SETTINGS) do
            local gv = rawget(_G, k)
            if gv == nil and G ~= _G then gv = rawget(G, k) end
            seeded[k] = (gv == nil) and default or gv
        end
        KurbyHub.configure(seeded)
    end
    if settings then
        return merge(KurbyHub.Settings, settings)
    end
    return KurbyHub.Settings
end

function KurbyHub.getSettings()
    return copy(get_settings())
end

local function class_name(x)
    local ok, res = pcall(function() return x.ClassName end)
    if ok then return tostring(res) end
    return type(x)
end

local function safe_name(x)
    local ok, res = pcall(function() return x.Name end)
    if ok and res ~= nil then return tostring(res) end
    return tostring(x)
end

local function safe_full_name(x)
    local ok, res = pcall(function() return x:GetFullName() end)
    if ok and res then return tostring(res) end
    return safe_name(x)
end

local function is_a(x, class)
    local ok, res = pcall(function() return x:IsA(class) end)
    return ok and res == true
end

local function get_children(x)
    local ok, res = pcall(function() return x:GetChildren() end)
    if ok and type(res) == "table" then return res end
    return {}
end

local function get_descendants(x)
    local ok, res = pcall(function() return x:GetDescendants() end)
    if ok and type(res) == "table" then return res end
    local out = {}
    local function walk(node)
        for _, child in ipairs(get_children(node)) do
            out[#out + 1] = child
            walk(child)
        end
    end
    walk(x)
    return out
end

local function get_service(name)
    if not game or not game.GetService then return nil end
    local ok, svc = pcall(function() return game:GetService(name) end)
    if ok then return svc end
    return nil
end

local function is_lua_container(inst)
    return is_a(inst, "LuaSourceContainer") or is_a(inst, "LocalScript") or is_a(inst, "ModuleScript") or is_a(inst, "Script")
end

local function get_roots(settings)
    local roots = settings.roots
    if roots == nil then
        if game then return {game} end
        return {}
    end
    if type(roots) == "table" and roots[1] ~= nil then return roots end
    return {roots}
end

function KurbyHub.isRobloxModule(inst)
    local path = safe_full_name(inst)
    local cls = class_name(inst)
    if cls == "CoreScript" then return true end
    local needles = {
        "CoreGui",
        "CorePackages",
        "RobloxGui",
        "RobloxReplicatedStorage",
        "PlayerScripts.PlayerModule",
        "PlayerScripts.ChatScript",
        "PlayerScripts.RbxCharacterSounds",
        "PlayerScripts.ControlScript",
        "PlayerScripts.CameraScript",
        "ChatScript",
        "RbxCharacterSounds",
    }
    for _, needle in ipairs(needles) do
        if string.find(path, needle, 1, true) then return true end
    end
    return false
end

function KurbyHub.isOtherPlayerScript(inst)
    local players = get_service("Players")
    local localPlayer = players and players.LocalPlayer
    if not players or not localPlayer then return false end
    local node = inst
    while node do
        if node == localPlayer then return false end
        local parentOk, parent = pcall(function() return node.Parent end)
        if not parentOk then break end
        if parent == players then
            return node ~= localPlayer
        end
        node = parent
    end
    return false
end

local function should_include(inst, settings)
    local cls = class_name(inst)
    if settings.ignoreRobloxModules and KurbyHub.isRobloxModule(inst) then
        return false, "roblox_module"
    end
    if settings.ignoreOthers and KurbyHub.isOtherPlayerScript(inst) then
        return false, "other_player"
    end
    if cls == "ModuleScript" and not settings.modules then
        return false, "modules_disabled"
    end
    if cls == "LocalScript" and not settings.localScripts then
        return false, "localscripts_disabled"
    end
    if cls == "Script" and not settings.regularScripts then
        return false, "scripts_disabled"
    end
    return true
end

local function duplicate_key(inst, settings)
    if settings.duplicateMode == "full_name" then
        return class_name(inst) .. ":" .. safe_full_name(inst)
    end
    return class_name(inst) .. ":" .. safe_name(inst)
end

function KurbyHub.collectScripts(rootOrSettings, maybeSettings)
    local settings
    local roots
    if rootOrSettings and not is_lua_container(rootOrSettings) and type(rootOrSettings) == "table" and not rootOrSettings.GetDescendants then
        settings = get_settings(rootOrSettings)
        roots = get_roots(settings)
    else
        settings = get_settings(maybeSettings)
        roots = rootOrSettings and {rootOrSettings} or get_roots(settings)
    end

    local scripts = {}
    local skipped = {}
    local seen = {}
    for _, root in ipairs(roots) do
        local candidates = {}
        if is_lua_container(root) then candidates[#candidates + 1] = root end
        for _, item in ipairs(get_descendants(root)) do candidates[#candidates + 1] = item end
        for _, inst in ipairs(candidates) do
            if is_lua_container(inst) then
                local ok, reason = should_include(inst, settings)
                if ok then
                    if settings.ignoreDuplicates then
                        local key = duplicate_key(inst, settings)
                        if seen[key] then
                            skipped[#skipped + 1] = {instance = inst, reason = "duplicate", duplicateOf = seen[key]}
                            ok = false
                        else
                            seen[key] = safe_full_name(inst)
                        end
                    end
                end
                if ok then
                    scripts[#scripts + 1] = inst
                elseif reason then
                    skipped[#skipped + 1] = {instance = inst, reason = reason}
                end
            end
        end
    end
    table.sort(scripts, function(a, b) return safe_full_name(a) < safe_full_name(b) end)
    return scripts, skipped
end

local function read_source(inst)
    local ok, src = pcall(function() return inst.Source end)
    if ok and type(src) == "string" then
        return src, "Source"
    end
    return nil, tostring(src)
end

local function call_vanity(target, settings)
    if not settings.useVanityFallback then return nil, "Vanity fallback disabled" end
    local V = G.Vanity or _G.Vanity
    if type(V) ~= "table" or type(V.decompile) ~= "function" then
        return nil, "Vanity.decompile unavailable"
    end
    local ok, result, meta = pcall(function()
        return V.decompile(target, {chain = settings.vanityChain})
    end)
    if ok and type(result) == "string" and result ~= "" and not string.find(result, "All decompiler fallbacks failed", 1, true) then
        return result, "Vanity", meta
    end
    return nil, tostring(result or meta)
end

local function call_global_decompile(target)
    local fn = rawget(G, "decompile") or rawget(_G, "decompile")
    if type(fn) ~= "function" then return nil, "global decompile unavailable" end
    local ok, result = pcall(fn, target)
    if ok and type(result) == "string" and result ~= "" then return result, "decompile" end
    return nil, tostring(result)
end

function KurbyHub.decompileScript(inst, settings)
    settings = get_settings(settings)
    local cls = class_name(inst)
    local entry = {
        instance = inst,
        name = safe_name(inst),
        className = cls,
        path = safe_full_name(inst),
        status = "pending",
        source = nil,
        sourceKind = nil,
        error = nil,
    }

    if cls == "Script" and settings.regularScripts then
        entry.status = "referenced"
        entry.error = "regularScripts=true: server Script referenced, not forced through bytecode decompile"
        return entry
    end

    local src, kindOrErr = read_source(inst)
    if src and (settings.includeEmptySource or src ~= "") then
        entry.status = "ok"
        entry.source = src
        entry.sourceKind = kindOrErr
        return entry
    end

    src, kindOrErr = call_vanity(inst, settings)
    if src then
        entry.status = "ok"
        entry.source = src
        entry.sourceKind = kindOrErr
        return entry
    end

    src, kindOrErr = call_global_decompile(inst)
    if src then
        entry.status = "ok"
        entry.source = src
        entry.sourceKind = kindOrErr
        return entry
    end

    entry.status = "failed"
    entry.error = tostring(kindOrErr or "no source/decompiler available")
    return entry
end

function KurbyHub.collectRemotes(rootOrSettings, maybeSettings)
    local settings
    local roots
    if rootOrSettings and type(rootOrSettings) == "table" and not rootOrSettings.GetDescendants then
        settings = get_settings(rootOrSettings)
        roots = get_roots(settings)
    else
        settings = get_settings(maybeSettings)
        roots = rootOrSettings and {rootOrSettings} or get_roots(settings)
    end
    if settings.ignoreRemotes then return {} end
    local remotes = {}
    for _, root in ipairs(roots) do
        local candidates = {}
        if is_a(root, "RemoteEvent") or is_a(root, "RemoteFunction") then candidates[#candidates + 1] = root end
        for _, item in ipairs(get_descendants(root)) do candidates[#candidates + 1] = item end
        for _, item in ipairs(candidates) do
            if is_a(item, "RemoteEvent") or is_a(item, "RemoteFunction") then
                remotes[#remotes + 1] = {
                    instance = item,
                    name = safe_name(item),
                    className = class_name(item),
                    path = safe_full_name(item),
                }
            end
        end
    end
    table.sort(remotes, function(a, b) return a.path < b.path end)
    return remotes
end

local function split_lines(source)
    local lines = {}
    source = tostring(source or "")
    source = source:gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in (source .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function make_segment(lines, index, settings)
    local radius = tonumber(settings.contextLines) or 3
    local startLine = math.max(1, index - radius)
    local endLine = math.min(#lines, index + radius)
    local out = {}
    for i = startLine, endLine do
        out[#out + 1] = string.format("%5d | %s", i, lines[i])
    end
    local text = table.concat(out, "\n")
    local maxChars = tonumber(settings.maxSegmentChars) or 1200
    if #text > maxChars then text = text:sub(1, maxChars) .. "\n-- <segment truncated>" end
    return text, startLine, endLine
end

local remote_methods = {
    "FireServer", "InvokeServer", "FireClient", "InvokeClient", "FireAllClients",
    "OnServerEvent", "OnClientEvent", "OnServerInvoke", "OnClientInvoke",
}

function KurbyHub.findRemoteReferences(results, remotes, settings)
    settings = get_settings(settings)
    if settings.ignoreRemotes then return {} end
    local refs = {}
    local remoteNames = {}
    for _, remote in ipairs(remotes or {}) do remoteNames[remote.name] = true end

    for _, result in ipairs(results or {}) do
        if result.source and result.source ~= "" then
            local lines = split_lines(result.source)
            for i, line in ipairs(lines) do
                local matched = false
                local reason = nil
                for _, method in ipairs(remote_methods) do
                    if string.find(line, method, 1, true) then
                        matched = true
                        reason = method
                        break
                    end
                end
                if not matched then
                    for name in pairs(remoteNames) do
                        if name ~= "" and string.find(line, name, 1, true) then
                            matched = true
                            reason = "remote name: " .. name
                            break
                        end
                    end
                end
                if matched then
                    local segment, firstLine, lastLine = make_segment(lines, i, settings)
                    refs[#refs + 1] = {
                        script = result.path,
                        scriptClass = result.className,
                        line = i,
                        reason = reason,
                        firstLine = firstLine,
                        lastLine = lastLine,
                        segment = segment,
                    }
                end
            end
        end
    end
    return refs
end

local function comment_block(text)
    text = tostring(text or "")
    text = text:gsub("%]%]", "] ]")
    return "--[[\n" .. text .. "\n--]]"
end

local function timestamp()
    if os and os.date then return os.date("%Y%m%d_%H%M%S") end
    return tostring(math.floor((tick and tick()) or 0))
end

local function default_output_file()
    return "Vanity_KurbyHub_Dump_" .. timestamp() .. ".lua"
end

function KurbyHub.formatDump(bundle, settings)
    settings = get_settings(settings)
    local lines = {}
    lines[#lines + 1] = "-- Vanity / KurbyHub reconstructed dump"
    lines[#lines + 1] = "-- Generated: " .. timestamp()
    lines[#lines + 1] = "-- This file is an audit dump; it is not guaranteed to be directly runnable."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "-- Settings:"
    for _, key in ipairs({"ignoreOthers", "ignoreRobloxModules", "modules", "localScripts", "regularScripts", "ignoreDuplicates", "ignoreRemotes"}) do
        lines[#lines + 1] = string.format("--   %s = %s", key, tostring(settings[key]))
    end
    lines[#lines + 1] = ""

    for index, result in ipairs(bundle.results or {}) do
        lines[#lines + 1] = string.rep("-", 78)
        lines[#lines + 1] = string.format("-- [%03d] %s | %s", index, result.className or "?", result.path or "?")
        lines[#lines + 1] = string.format("-- Status: %s%s", tostring(result.status), result.sourceKind and (" via " .. tostring(result.sourceKind)) or "")
        if result.status == "ok" and result.source then
            lines[#lines + 1] = result.source
        else
            lines[#lines + 1] = comment_block(result.error or "No source returned")
        end
        lines[#lines + 1] = ""
    end

    if not settings.ignoreRemotes then
        lines[#lines + 1] = string.rep("=", 78)
        lines[#lines + 1] = "-- Remote instances discovered"
        for _, remote in ipairs(bundle.remotes or {}) do
            lines[#lines + 1] = string.format("-- %s | %s", remote.className, remote.path)
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- Remote references / call-site segments"
        for _, ref in ipairs(bundle.remoteReferences or {}) do
            lines[#lines + 1] = string.rep("-", 78)
            lines[#lines + 1] = string.format("-- %s:%s (%s)", ref.script, tostring(ref.line), tostring(ref.reason))
            lines[#lines + 1] = comment_block(ref.segment)
        end
        lines[#lines + 1] = ""
    end

    if bundle.skipped and #bundle.skipped > 0 then
        lines[#lines + 1] = string.rep("=", 78)
        lines[#lines + 1] = "-- Skipped scripts"
        for _, skip in ipairs(bundle.skipped) do
            lines[#lines + 1] = string.format("-- %s | %s", tostring(skip.reason), safe_full_name(skip.instance))
        end
    end
    return table.concat(lines, "\n")
end

function KurbyHub.dump(rootOrSettings, maybeSettings)
    local settings
    local root
    if rootOrSettings and type(rootOrSettings) == "table" and not rootOrSettings.GetDescendants then
        settings = get_settings(rootOrSettings)
        root = nil
    else
        settings = get_settings(maybeSettings)
        root = rootOrSettings
    end

    local scripts, skipped = KurbyHub.collectScripts(root or settings, settings)
    local results = {}
    for _, inst in ipairs(scripts) do
        results[#results + 1] = KurbyHub.decompileScript(inst, settings)
    end
    local remotes = KurbyHub.collectRemotes(root or settings, settings)
    local remoteReferences = KurbyHub.findRemoteReferences(results, remotes, settings)
    local bundle = {
        settings = settings,
        scripts = scripts,
        skipped = skipped,
        results = results,
        remotes = remotes,
        remoteReferences = remoteReferences,
    }
    local output = KurbyHub.formatDump(bundle, settings)
    bundle.output = output

    if settings.writeToFile ~= false and type(writefile) == "function" then
        local fileName = settings.outputFile or default_output_file()
        local ok, err = pcall(writefile, fileName, output)
        bundle.outputFile = ok and fileName or nil
        bundle.writeError = ok and nil or tostring(err)
    end
    return output, bundle
end

function KurbyHub.run(rootOrSettings, maybeSettings)
    return KurbyHub.dump(rootOrSettings, maybeSettings)
end

G.KurbyHub = KurbyHub
G.load_kurbyhub_decompiler = function(rootOrSettings, maybeSettings)
    return KurbyHub.dump(rootOrSettings, maybeSettings)
end

KurbyHub.configure()
return KurbyHub
]=]
__KURBYHUB_RECONSTRUCTED_FACTORY = function()
    local fn, err = loadstring(__KURBYHUB_RECONSTRUCTED_SOURCE, "Vanity.KurbyHub.Reconstructed")
    if not fn then error(err) end
    return fn()
end


-- ==================== GLOBAL COMPATIBILITY EXPORTS ====================
-- Important:
--   Vanity.Config is for Vanity's own wrappers.
--   Third-party decompilers usually do NOT read Vanity.Config directly.
--   This shim mirrors the compatibility-facing API/settings into getgenv(), _G,
--   and the current _ENV so loaders that look for bare globals can still find them.

local function mirror_global(name, value)
    if value == nil then return end
    pcall(function() rawset(G, name, value) end)
    pcall(function() rawset(_G, name, value) end)
    if _ENV and type(_ENV) == "table" then
        pcall(function() rawset(_ENV, name, value) end)
    end
end

function Vanity.syncGlobals()
    mirror_global("Vanity", Vanity)

    -- Compatibility API names.
    if type(Vanity.load) == "function" then mirror_global("load_decompile", Vanity.load) end
    if type(G.decompile) == "function" then mirror_global("decompile", G.decompile) end
    if type(G.disassemble) == "function" then mirror_global("disassemble", G.disassemble) end

    -- KurbyHub recovered settings were originally global _G flags.
    local kh = Config.KurbyHub and Config.KurbyHub.Settings
    if type(kh) == "table" then
        for _, key in ipairs({
            "ignoreOthers",
            "ignoreRobloxModules",
            "modules",
            "localScripts",
            "regularScripts",
            "ignoreDuplicates",
            "ignoreRemotes",
        }) do
            mirror_global(key, kh[key])
        end
    end

    return true
end

-- ==================== BASIC HELPERS ====================
local HttpService = nil
pcall(function() HttpService = game:GetService("HttpService") end)

local function get_request()
    return (syn and syn.request)
        or (http and http.request)
        or http_request
        or (fluxus and fluxus.request)
        or request
end

local function http_get(url)
    if game and game.HttpGet then
        local ok, res = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(res) == "string" then return true, res end
        return false, res
    end
    local req = get_request()
    if req then
        local ok, res = pcall(req, {Url = url, Method = "GET"})
        if ok and res and (res.StatusCode == nil or (res.StatusCode >= 200 and res.StatusCode < 300)) then
            return true, res.Body or res.body or ""
        end
        return false, res and (res.Body or res.body or res.StatusMessage or res.StatusCode) or res
    end
    return false, "no HttpGet/request function available"
end

local function http_post(url, body, headers)
    local req = get_request()
    if req then
        local ok, res = pcall(req, {
            Url = url,
            Method = "POST",
            Body = body,
            Headers = headers or {},
        })
        if not ok then return false, tostring(res), 0 end
        local status = tonumber(res.StatusCode or res.status_code or res.Status or 0) or 0
        local text = res.Body or res.body or ""
        if status == 0 or (status >= 200 and status < 300) then return true, text, status end
        return false, text, status
    end
    if HttpService and HttpService.PostAsync then
        local ok, res = pcall(function()
            return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false)
        end)
        if ok then return true, res, 200 end
        return false, tostring(res), 0
    end
    return false, "no request/PostAsync function available", 0
end

local function now_clock()
    return (os and os.clock and os.clock()) or tick()
end

local function wait_seconds(s)
    if s and s > 0 then
        if task and task.wait then task.wait(s) else wait(s) end
    end
end

local function is_script_instance(x)
    if typeof and typeof(x) == "Instance" then
        return x:IsA("LuaSourceContainer") or x:IsA("LocalScript") or x:IsA("ModuleScript") or x:IsA("Script")
    end
    return false
end

local function is_client_decompilable_script(x)
    if not (typeof and typeof(x) == "Instance") then return false end
    if x:IsA("LocalScript") or x:IsA("ModuleScript") then return true end
    if x:IsA("Script") then
        local ok, rc = pcall(function() return x.RunContext end)
        return ok and tostring(rc):find("Client") ~= nil
    end
    return false
end

local function safe_name(x)
    local ok, full = pcall(function() return x:GetFullName() end)
    if ok then return full end
    ok, full = pcall(function() return x.Name end)
    if ok then return tostring(full) end
    return tostring(x)
end

local function try_get_source(x)
    if not is_script_instance(x) then return nil, "not a LuaSourceContainer" end
    local ok, source = pcall(function() return x.Source end)
    if ok and type(source) == "string" and source ~= "" then return source end
    return nil, "Source not accessible or empty"
end

local function try_get_bytecode(x)
    if type(x) == "string" then return true, x end
    if not getscriptbytecode then return false, "getscriptbytecode missing" end
    if not is_client_decompilable_script(x) then
        return false, "target is not a LocalScript, ModuleScript, or client RunContext Script"
    end
    local ok, bytecode = pcall(getscriptbytecode, x)
    if not ok then return false, tostring(bytecode) end
    if type(bytecode) ~= "string" then return false, "bytecode is not a string" end
    if bytecode == "" then return false, "empty bytecode" end
    return true, bytecode
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function pure_base64_encode(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. ((b % 2^i - b % 2^(i-1) > 0) and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + ((x:sub(i,i) == '1') and 2^(6-i) or 0) end
        return b64chars:sub(c+1,c+1)
    end) .. ({'', '==', '='})[#data % 3 + 1])
end

local function base64_encode(data)
    local candidates = {
        function() return crypt and crypt.base64 and crypt.base64.encode and crypt.base64.encode(data) end,
        function() return crypt and crypt.base64encode and crypt.base64encode(data) end,
        function() return crypt and crypt.base64 and crypt.base64.encode and crypt.base64.encode(data) end,
        function() return base64encode and base64encode(data) end,
        function() return syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.encode and syn.crypt.base64.encode(data) end,
    }
    for _, f in ipairs(candidates) do
        local ok, res = pcall(f)
        if ok and type(res) == "string" and res ~= "" then return res end
    end
    return pure_base64_encode(data)
end

local function json_encode(tbl)
    if HttpService then
        local ok, res = pcall(function() return HttpService:JSONEncode(tbl) end)
        if ok then return res end
    end
    -- Small JSON encoder enough for these simple option/body tables.
    local function esc(s)
        return tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')
    end
    local function enc(v)
        local t = type(v)
        if t == "string" then return '"' .. esc(v) .. '"' end
        if t == "number" or t == "boolean" then return tostring(v) end
        if t == "table" then
            local parts = {}
            for k, val in pairs(v) do table.insert(parts, '"' .. esc(k) .. '":' .. enc(val)) end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return "null"
    end
    return enc(tbl)
end

local function looks_like_success(text)
    return type(text) == "string" and text ~= "" and not text:match("^%s*%-%-%[%[") and not text:lower():match("failed")
end

-- ==================== ENGINE: StudioSource ====================
local function Decompile_StudioSource(target, options)
    if Config.StudioSource.Enabled == false then return nil, "StudioSource disabled" end
    local source, err = try_get_source(target)
    if source then
        return source, {engine = "StudioSource", note = "Returned .Source directly"}
    end
    return nil, err
end

-- ==================== ENGINE: Fission / rbxcli ====================
local function Decompile_Fission(target, options)
    if Config.Fission.Enabled == false then return nil, "Fission disabled" end
    if not (rbxcli and type(rbxcli.decompile) == "function") then
        return nil, "rbxcli.decompile unavailable"
    end
    local kind = (options and options.DecompilationKind) or Config.Fission.DecompilationKind or "Luau"
    local ok, result = pcall(function()
        return rbxcli.decompile(target, { DecompilationKind = kind })
    end)
    if ok and type(result) == "string" and result ~= "" then
        return result, {engine = "Fission", kind = kind}
    end
    return nil, tostring(result)
end

local function Disassemble_Fission(target, options)
    local opts = {}
    if options then for k,v in pairs(options) do opts[k] = v end end
    opts.DecompilationKind = "IR"
    return Decompile_Fission(target, opts)
end

-- ==================== ENGINE: lua.expert ====================
local luaexpert_last_call = 0
local function Decompile_LuaExpert(target, options)
    if Config.LuaExpert.Enabled == false then return nil, "LuaExpert disabled" end
    local okByte, bytecode = try_get_bytecode(target)
    if not okByte then return nil, bytecode end

    local elapsed = now_clock() - luaexpert_last_call
    if elapsed < Config.LuaExpert.RateLimit then wait_seconds(Config.LuaExpert.RateLimit - elapsed) end

    local payload = json_encode({ script = base64_encode(bytecode) })
    local okPost, body, status = http_post(Config.LuaExpert.API, payload, {
        ["Content-Type"] = "application/json",
    })
    luaexpert_last_call = now_clock()
    if okPost and type(body) == "string" and body ~= "" then
        return body, {engine = "LuaExpert", status = status}
    end
    return nil, string.format("HTTP %s: %s", tostring(status), tostring(body))
end

-- ==================== ENGINE: Advanced Decompiler V3 ====================
local AdvancedV3_Loaded = false
local AdvancedV3_Base = nil
local function Load_AdvancedV3()
    if AdvancedV3_Loaded and AdvancedV3_Base then return true end
    local ok, src = http_get(Config.AdvancedV3.InitUrl)
    if not ok then return false, "fetch failed: " .. tostring(src) end
    local fn, compileErr = loadstring(src, "Advanced-Decompiler-V3")
    if not fn then return false, "loadstring failed: " .. tostring(compileErr) end
    local priorEnvDecompile = _ENV and _ENV.decompile
    local priorGlobalDecompile = G.decompile
    local runOk, runErr = pcall(fn)
    if not runOk then return false, "execution failed: " .. tostring(runErr) end
    AdvancedV3_Base = (_ENV and _ENV.decompile) or G.decompile or decompile
    if type(AdvancedV3_Base) ~= "function" then
        _ENV.decompile = priorEnvDecompile
        G.decompile = priorGlobalDecompile
        return false, "decompile not registered by AdvancedV3"
    end
    AdvancedV3_Loaded = true
    return true
end

local function Decompile_AdvancedV3(target, options)
    if Config.AdvancedV3.Enabled == false then return nil, "AdvancedV3 disabled" end
    local ok, err = Load_AdvancedV3()
    if not ok then return nil, err end
    local opts = options or Config.AdvancedV3.Options
    local runOk, result = pcall(AdvancedV3_Base, target, opts)
    if runOk and type(result) == "string" and result ~= "" then
        return result, {engine = "AdvancedV3"}
    end
    return nil, tostring(result)
end

-- ==================== ENGINE: Konstant ====================
local konstant_last_call = 0
local function Konstant_Call(endpoint, target)
    local okByte, bytecode = try_get_bytecode(target)
    if not okByte then return nil, bytecode end
    local elapsed = now_clock() - konstant_last_call
    if elapsed < Config.Konstant.RateLimit then wait_seconds(Config.Konstant.RateLimit - elapsed) end
    local okPost, body, status = http_post(Config.Konstant.API .. endpoint, bytecode, {
        ["Content-Type"] = "text/plain",
    })
    konstant_last_call = now_clock()
    if okPost and type(body) == "string" and body ~= "" then
        return body, {engine = "Konstant", status = status}
    end
    return nil, string.format("HTTP %s: %s", tostring(status), tostring(body))
end

local function Decompile_Konstant(target, options)
    if Config.Konstant.Enabled == false then return nil, "Konstant disabled" end
    return Konstant_Call("/konstant/decompile", target)
end

local function Disassemble_Konstant(target, options)
    if Config.Konstant.Enabled == false then return nil, "Konstant disabled" end
    return Konstant_Call("/konstant/disassemble", target)
end

-- ==================== ENGINE: LunaUX local server ====================
local function LunaUX_Call(branch, target)
    if Config.LunaUX.Enabled == false then return nil, "LunaUX disabled" end
    local okByte, bytecode = try_get_bytecode(target)
    if not okByte then return nil, bytecode end
    local payload = {
        bytecode = base64_encode(bytecode),
        filename = (typeof and typeof(target) == "Instance") and target.Name or "bytecode.luau",
    }
    for k, v in pairs(Config.LunaUX.Options or {}) do payload[k] = v end
    local okPost, body, status = http_post(Config.LunaUX.API .. "/" .. branch, json_encode(payload), {
        ["Content-Type"] = "application/json",
    })
    if okPost and type(body) == "string" and body ~= "" then
        return body, {engine = "LunaUX", status = status}
    end
    return nil, string.format("HTTP %s: %s", tostring(status), tostring(body))
end

local function Decompile_LunaUX(target, options) return LunaUX_Call("decompile", target) end
local function Disassemble_LunaUX(target, options) return LunaUX_Call("disassemble", target) end

-- ==================== ENGINE: Shiny / Medal local server ====================
local function Decompile_ShinyMedal(target, options)
    if Config.ShinyMedal.Enabled == false then return nil, "ShinyMedal disabled" end
    local okByte, bytecode = try_get_bytecode(target)
    if not okByte then return nil, bytecode end
    local okPost, body, status = http_post(Config.ShinyMedal.API .. Config.ShinyMedal.DecompilePath, base64_encode(bytecode), {
        ["Content-Type"] = "text/plain",
    })
    if okPost and type(body) == "string" and body ~= "" then
        return body, {engine = "ShinyMedal", status = status}
    end
    return nil, string.format("HTTP %s: %s", tostring(status), tostring(body))
end

-- ==================== WRAPPER: BetterDecompiler ====================
local Better_Loaded = false
local Better_Base = nil
local function Load_BetterDecompiler()
    if Better_Loaded and Better_Base then return true end
    if type(G.decompile) ~= "function" and type(decompile) ~= "function" then
        return false, "BetterDecompiler requires an existing decompile function first"
    end
    local ok, src = http_get(Config.BetterDecompiler.Url)
    if not ok then return false, "fetch failed: " .. tostring(src) end
    local fn, compileErr = loadstring(src, "BetterDecompiler")
    if not fn then return false, "loadstring failed: " .. tostring(compileErr) end
    local runOk, result = pcall(fn)
    if not runOk then return false, "execution failed: " .. tostring(result) end
    if type(result) == "table" and type(result.decompile) == "function" then
        Better_Base = result.decompile
        Better_Loaded = true
        return true
    end
    return false, "unexpected BetterDecompiler return type"
end

local function Decompile_BetterDecompiler(target, options)
    if Config.BetterDecompiler.Enabled == false then return nil, "BetterDecompiler disabled" end
    local ok, err = Load_BetterDecompiler()
    if not ok then return nil, err end
    local useAI = Config.BetterDecompiler.UseAI
    local cleanupServer = Config.BetterDecompiler.CleanupServer
    local runOk, result = pcall(Better_Base, target, useAI, cleanupServer)
    if runOk and type(result) == "string" and result ~= "" then
        return result, {engine = "BetterDecompiler"}
    end
    return nil, tostring(result)
end

-- ==================== ENGINE: PseudoLuaDecompiler runtime tracer ====================
local function Load_PseudoLuaDecompiler()
    if Config.PseudoLua.Enabled == false then return false, "PseudoLua disabled" end
    local ok, src = http_get(Config.PseudoLua.Url)
    if not ok then return false, "fetch failed: " .. tostring(src) end
    local fn, compileErr = loadstring(src, "PseudoLuaDecompiler")
    if not fn then return false, "loadstring failed: " .. tostring(compileErr) end
    local runOk, runErr = pcall(fn)
    if not runOk then return false, "execution failed: " .. tostring(runErr) end
    return type(G.decompile) == "function" or type(decompile) == "function"
end

-- ==================== ENGINE: KurbyHub reconstructed dump module ====================
local KurbyHub_Module = nil
local function Load_KurbyHub()
    if Config.KurbyHub.Enabled == false then return false, "KurbyHub disabled" end
    local ok, moduleOrErr = pcall(__KURBYHUB_RECONSTRUCTED_FACTORY)
    if not ok then return false, "factory failed: " .. tostring(moduleOrErr) end
    KurbyHub_Module = moduleOrErr
    if type(KurbyHub_Module) ~= "table" then return false, "factory did not return a module" end
    if type(KurbyHub_Module.configure) == "function" then
        KurbyHub_Module.configure(Config.KurbyHub.Settings or {})
    end
    G.KurbyHub = KurbyHub_Module
    Vanity.KurbyHub = KurbyHub_Module
    G.kurbyhub_decompile = function(rootOrSettings, maybeSettings)
        return KurbyHub_Module.dump(rootOrSettings, maybeSettings)
    end
    return true, KurbyHub_Module
end

local function Decompile_KurbyHub(target, options)
    local ok, err = Load_KurbyHub()
    if not ok then return nil, err end
    if not KurbyHub_Module or type(KurbyHub_Module.decompileScript) ~= "function" then return nil, "KurbyHub module unavailable" end
    local entry = KurbyHub_Module.decompileScript(target, options or Config.KurbyHub.Settings)
    if entry and entry.status == "ok" and type(entry.source) == "string" then
        return entry.source, {engine = "KurbyHub", entry = entry}
    end
    return nil, entry and entry.error or "KurbyHub returned no source"
end

-- ==================== REGISTRY ====================
local Engines = {
    StudioSource = {decompile = Decompile_StudioSource, load = function() return true end},
    Fission = {decompile = Decompile_Fission, disassemble = Disassemble_Fission, load = function()
        if rbxcli and type(rbxcli.decompile) == "function" then
            G.decompile = function(target, opts) return assert(Decompile_Fission(target, opts)) end
            G.disassemble = function(target, opts) return assert(Disassemble_Fission(target, opts)) end
            return true
        end
        return false, "rbxcli.decompile unavailable"
    end},
    LuaExpert = {decompile = Decompile_LuaExpert, load = function()
        G.decompile = function(target, opts) return assert(Decompile_LuaExpert(target, opts)) end
        return true
    end},
    AdvancedV3 = {decompile = Decompile_AdvancedV3, load = function()
        local ok, err = Load_AdvancedV3()
        if ok then
            G.decompile = function(target, opts)
                return AdvancedV3_Base(target, opts or Config.AdvancedV3.Options)
            end
        end
        return ok, err
    end},
    Konstant = {decompile = Decompile_Konstant, disassemble = Disassemble_Konstant, load = function()
        G.decompile = function(target, opts) return assert(Decompile_Konstant(target, opts)) end
        G.disassemble = function(target, opts) return assert(Disassemble_Konstant(target, opts)) end
        return true
    end},
    LunaUX = {decompile = Decompile_LunaUX, disassemble = Disassemble_LunaUX, load = function()
        G.decompile = function(target, opts) return assert(Decompile_LunaUX(target, opts)) end
        G.disassemble = function(target, opts) return assert(Disassemble_LunaUX(target, opts)) end
        return true
    end},
    ShinyMedal = {decompile = Decompile_ShinyMedal, load = function()
        G.decompile = function(target, opts) return assert(Decompile_ShinyMedal(target, opts)) end
        return true
    end},
    BetterDecompiler = {decompile = Decompile_BetterDecompiler, load = function()
        local ok, err = Load_BetterDecompiler()
        if ok then G.decompile = Better_Base end
        return ok, err
    end},
    PseudoLua = {load = Load_PseudoLuaDecompiler},
    KurbyHub = {decompile = Decompile_KurbyHub, load = Load_KurbyHub},
}

local EngineAliases = {
    [1] = "StudioSource",
    [2] = "Fission",
    [3] = "LuaExpert",
    [4] = "AdvancedV3",
    [5] = "Konstant",
    [6] = "LunaUX",
    [7] = "ShinyMedal",
    [8] = "BetterDecompiler",
    [9] = "PseudoLua",
    [10] = "KurbyHub",
    studio = "StudioSource",
    source = "StudioSource",
    fission = "Fission",
    rbxcli = "Fission",
    luaexpert = "LuaExpert",
    expert = "LuaExpert",
    adv = "AdvancedV3",
    advanced = "AdvancedV3",
    advancedv3 = "AdvancedV3",
    konstant = "Konstant",
    lunaux = "LunaUX",
    shiny = "ShinyMedal",
    medal = "ShinyMedal",
    better = "BetterDecompiler",
    pseudo = "PseudoLua",
    kurby = "KurbyHub",
    kurbyhub = "KurbyHub",
    kurbyshub = "KurbyHub",
    decompilerlua = "KurbyHub",
    first = "KurbyHub",
}

local function resolve_engine(name)
    if type(name) == "number" then return EngineAliases[name] end
    if type(name) == "string" then
        return Engines[name] and name or EngineAliases[name:lower()]
    end
    return nil
end

function Vanity.list()
    return {
        "1 StudioSource (.Source direct, Studio)",
        "2 Fission/rbxcli (Luau or IR)",
        "3 lua.expert API",
        "4 Advanced Decompiler V3",
        "5 Konstant API",
        "6 LunaUX local server",
        "7 Shiny/Medal local server",
        "8 BetterDecompiler cleanup wrapper",
        "9 PseudoLua runtime tracer, explicit only",
        "10 KurbyHub reconstructed dump module, explicit only",
    }
end

function Vanity.load(name)
    local engineName = resolve_engine(name)
    if not engineName then
        notify("Loader Error", "Unknown engine. Use Vanity.list().")
        return false
    end
    local engine = Engines[engineName]
    if not engine or not engine.load then
        notify("Loader Error", engineName .. " has no load function")
        return false
    end
    local ok, a, b = pcall(engine.load)
    if not ok then
        notify("Loader Crash", tostring(a))
        return false
    end
    if a then
        if type(Vanity.syncGlobals) == "function" then Vanity.syncGlobals() end
        notify("Loaded", engineName .. " ready")
        return true, b
    end
    notify(engineName .. " Error", tostring(b or a))
    return false, b
end

local function run_chain(kind, target, options)
    options = options or {}
    local chain = options.chain or Config.DefaultChain
    local errors = {}
    for _, name in ipairs(chain) do
        local engineName = resolve_engine(name) or name
        local engine = Engines[engineName]
        local fn = engine and engine[kind]
        if fn then
            local ok, result, meta = pcall(fn, target, options[engineName] or options)
            if ok and looks_like_success(result) then
                return result, {engine = engineName, meta = meta, errors = errors}
            end
            errors[#errors + 1] = string.format("%s: %s", tostring(engineName), tostring(ok and result or result))
        else
            errors[#errors + 1] = string.format("%s: no %s function", tostring(engineName), kind)
        end
    end
    return table.concat({"-- All decompiler fallbacks failed for " .. safe_name(target), "--", table.concat(errors, "\n")}, "\n"), {engine = nil, errors = errors}
end

function Vanity.decompile(target, options)
    return run_chain("decompile", target, options)
end

function Vanity.disassemble(target, options)
    return run_chain("disassemble", target, options)
end

-- Compatibility API: set a default decompile/disassemble that uses the fallback chain.
G.decompile = function(target, options)
    local result = Vanity.decompile(target, options)
    return result
end
G.disassemble = function(target, options)
    local result = Vanity.disassemble(target, options)
    return result
end
G.load_decompile = Vanity.load

if type(Vanity.syncGlobals) == "function" then Vanity.syncGlobals() end

notify("Vanity", "Fallback loader ready. Use Vanity.list() or decompile(script).")
return Vanity
