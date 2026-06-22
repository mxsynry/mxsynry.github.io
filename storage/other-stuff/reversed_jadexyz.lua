-- Deobfuscated https://protector-production-3a49.up.railway.app/loader/jade-xyz and lightly renamed static output.
-- jadexyz extractor by mxsynry
-- Behavior summary: contacts a remote Protector API, verifies a key/HWID/user, then executes server-supplied Lua via loadstring/load.
-- payload extraction logging.

repeat task.wait(0.1) until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local PlayersService = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local localPlayer = PlayersService.LocalPlayer or PlayersService.PlayerAdded:Wait()

local protector = {}
protector.project_id = "jade-xyz"
protector.api_url = "https://protector-production-3a49.up.railway.app"
protector.protect = false
protector.protect_https = false

local globalEnv = (getgenv and getgenv()) or _G

local function normalize_key(candidateKey)
    if type(candidateKey) ~= "string" then return nil end
    local trimmedKey = candidateKey:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmedKey == "" then return nil end
    return trimmedKey
end

function protector.set_key(newKey)
    local cleanKey = normalize_key(newKey) or ""
    if globalEnv then
        globalEnv.script_key = cleanKey
        globalEnv.key = cleanKey
        globalEnv._KEY = cleanKey
        globalEnv.licenseKey = cleanKey
    end
    if _G then
        _G.script_key = cleanKey
        _G.key = cleanKey
        _G._KEY = cleanKey
        _G.licenseKey = cleanKey
    end
    pcall(function() script_key = cleanKey end)
    return cleanKey
end

function protector.get_key(providedKey)
    local directKey = normalize_key(providedKey)
    if directKey then return directKey end
    local candidateKeys = {}
    local okScriptKey, scriptKeyValue = pcall(function() return script_key end)
    if okScriptKey then table.insert(candidateKeys, scriptKeyValue) end
    local okKey, keyValue = pcall(function() return key end)
    if okKey then table.insert(candidateKeys, keyValue) end
    table.insert(candidateKeys, globalEnv and globalEnv.script_key)
    table.insert(candidateKeys, globalEnv and globalEnv.key)
    table.insert(candidateKeys, globalEnv and globalEnv._KEY)
    table.insert(candidateKeys, globalEnv and globalEnv.licenseKey)
    table.insert(candidateKeys, _G and _G.script_key)
    table.insert(candidateKeys, _G and _G.key)
    table.insert(candidateKeys, _G and _G._KEY)
    table.insert(candidateKeys, _G and _G.licenseKey)
    local okSharedKey, sharedKeyValue = pcall(function() return shared and shared.key end)
    if okSharedKey then table.insert(candidateKeys, sharedKeyValue) end
    for index, candidate in ipairs(candidateKeys) do
        local normalizedCandidate = normalize_key(candidate)
        if normalizedCandidate then return normalizedCandidate end
    end
    return ""
end

function protector.get_hwid()
    local okHwid, hwid = pcall(function()
        return game["GetService"](game,"RbxAnalyticsService"):GetClientId()
    end)
    if not okHwid or not hwid then
        hwid = "UNKNOWN_" .. tostring(localPlayer and localPlayer.UserId or 0)
    end
    return tostring(hwid)
end

function protector.get_region_code()
    local okLocale, localeId = pcall(function()
        return LocalizationService.RobloxLocaleId or LocalizationService.SystemLocaleId or ""
    end)
    if not okLocale or type(localeId) ~= "string" then
        return ""
    end
    local region = localeId:match("%-([A-Za-z][A-Za-z])$") or localeId:match("_([A-Za-z][A-Za-z])$")
    if region then
        return string.upper(region)
    end
    return ""
end

function protector.request_func()
    return (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
end

function protector.now_ms()
    local okClock, clockValue = pcall(function()
        return os.clock()
    end)
    if okClock and type(clockValue) == "number" then
        return math.floor(clockValue * 1000)
    end
    return 0
end

local function normalize_license_tier(tier)
    local normalizedTier = tostring(tier or ""):lower()
    if normalizedTier == "premium" then return "premium" end
    if normalizedTier == "keyless" then return "keyless" end
    if normalizedTier == "free" then return "free" end
    return "free"
end

local function normalize_required_tier(requiredTier)
    local normalizedRequiredTier = tostring(requiredTier or ""):lower()
    if normalizedRequiredTier == "premium" then return "premium" end
    if normalizedRequiredTier == "free" or normalizedRequiredTier == "keyless" or normalizedRequiredTier == "any" then return "free" end
    return "premium"
end

function protector.set_license_tier(tierInput)
    local licenseTier = normalize_license_tier(tierInput)
    if globalEnv then
        globalEnv.__PX_LICENSE_TIER = licenseTier
    end
    if _G then
        _G.__PX_LICENSE_TIER = licenseTier
    end
    return licenseTier
end

function protector.get_license_tier()
    return normalize_license_tier((globalEnv and globalEnv.__PX_LICENSE_TIER) or (_G and _G.__PX_LICENSE_TIER))
end

function protector.license_gate(gateRequirement)
    local requiredTierLevel = normalize_required_tier(gateRequirement)
    local currentTier = protector.get_license_tier()
    if requiredTierLevel == "premium" then
        return currentTier == "premium"
    end
    return currentTier == "free" or currentTier == "premium" or currentTier == "keyless"
end

local function install_license_globals()
    local gateFn = function(_0xryv)
        return protector.license_gate(_0xryv)
    end
    local tierFn = function()
        return protector.get_license_tier()
    end
    local premiumFn = function()
        return protector.license_gate("premium")
    end
    if globalEnv then
        globalEnv.PX_Gate = gateFn
        globalEnv.PX_LicenseTier = tierFn
        globalEnv.PX_IsPremium = premiumFn
    end
    if _G then
        _G.PX_Gate = gateFn
        _G.PX_LicenseTier = tierFn
        _G.PX_IsPremium = premiumFn
    end
end

install_license_globals()

local requestMarkerWeakMap = setmetatable({}, { ["__mode"] = "k" })

function protector.post(path, payload)
    local requestFn = protector.request_func()
    if not requestFn then
        return { ["verified"] = false, ["code"] = "NO_HTTP_REQUEST", ["message"] = "Executor has no HTTP request support." }
    end

    local okRequest, response = pcall(function()
        local requestOptions = {
            ["Url"] = protector.api_url .. path,
            ["Method"] = "POST",
            ["Headers"] = {
                ["Content-Type"] = "application/json",
                ["ngrok-skip-browser-warning"] = "true",
                ["Bypass-Tunnel-Reminder"] = "true"
            },
            ["Body"] = HttpService:JSONEncode(payload or {})
        }

        requestMarkerWeakMap[requestOptions] = true

        return requestFn(requestOptions)
    end)

    if not okRequest or type(response) ~= "table" then
        return { ["verified"] = false, ["code"] = "CONNECTION_ERROR", ["message"] = "Connection failed: " .. tostring(response) }
    end

    local responseBody = response.Body or response.body or ""
    
    -- !!! SPY LOG 1: RAW HTTP RESPONSE !!!
    warn("\n[PROTECTOR-SPY] Raw HTTP Response from " .. path .. ":\n" .. responseBody .. "\n")

    local decodedResponse
    local okDecode = pcall(function()
        decodedResponse = HttpService:JSONDecode(responseBody)
    end)
    if not okDecode or type(decodedResponse) ~= "table" then
        return { ["verified"] = false, ["code"] = "BAD_RESPONSE", ["message"] = "Bad server response." }
    end
    return decodedResponse
end



function protector.report_security(eventType, details, extra)
    return { ["ok"] = true, ["disabled"] = true, ["riskLevel"] = "DISABLED", ["eventType"] = tostring(eventType or "PROTECT_DISABLED") }
end

local function disabled_security_hook(arg1, arg2, arg3)
    return nil
end

function protector.security_probe(probeContext)
    return {
        ["ok"] = true,
        ["skipped"] = true,
        ["disabled"] = true,
        ["riskLevel"] = "DISABLED",
        ["code"] = "PROTECT_DISABLED",
        ["message"] = "Security protection is disabled by server environment Protect=false."
    }
end


local function normalize_verify_response(verifyResponse)
    if type(verifyResponse) ~= "table" then
        return { ["code"] = "BAD_RESPONSE", ["message"] = "Bad server response." }
    end
    if verifyResponse.verified then
        return {
            ["code"] = verifyResponse.code or "KEY_VALID",
            ["message"] = verifyResponse.message or "Key valid.",
            ["data"] = verifyResponse.data or {
                ["auth_expire"] = verifyResponse.expiry or 0,
                ["total_executions"] = verifyResponse.injectCount or 0,
                ["license_tier"] = verifyResponse.licenseTier or "keyless",
                type = verifyResponse.type or "",
                ["note"] = verifyResponse.note or verifyResponse.type or ""
            },
            ["raw"] = verifyResponse
        }
    end
    return {
        ["code"] = verifyResponse.code or "KEY_INCORRECT",
        ["message"] = verifyResponse.message or "Verification failed.",
        ["data"] = verifyResponse.data,
        ["raw"] = verifyResponse
    }
end

function protector.check_key(keyToCheck)
    local securityProbeResult = protector.security_probe("check_key")
    if type(securityProbeResult) == "table" and securityProbeResult.blocked then
        return securityProbeResult
    end
    local verificationKey = protector.get_key(keyToCheck)
    local verifyDryRunResponse = protector.post("/verify", {
        ["projectId"] = protector.project_id,
        ["gameId"] = tostring(game.PlaceId),
        ["universeId"] = tostring(game.GameId),
        ["hwid"] = protector.get_hwid(),
        ["userId"] = localPlayer and localPlayer.UserId or 0,
        ["clientRegion"] = protector.get_region_code(),
        ["key"] = verificationKey,
        ["dryRun"] = true
    })
    return normalize_verify_response(verifyDryRunResponse)
end

local function install_runtime_metadata(verifySuccessResponse)
    local runtimeLicenseTier = protector.set_license_tier(verifySuccessResponse.licenseTier or (verifySuccessResponse.data and verifySuccessResponse.data.license_tier) or "keyless")
    install_license_globals()
    if getgenv then
        local genv = getgenv()
        genv.__PX_RUNTIME_TOKEN = verifySuccessResponse.runtimeToken
        genv.__PX_SCRIPT_ID = verifySuccessResponse.scriptId
        genv.__PX_PROJECT_ID = protector.project_id
        genv.__PX_API_URL = protector.api_url
        genv.__PX_LICENSE_TIER = runtimeLicenseTier
    else
        _G.__PX_RUNTIME_TOKEN = verifySuccessResponse.runtimeToken
        _G.__PX_SCRIPT_ID = verifySuccessResponse.scriptId
        _G.__PX_PROJECT_ID = protector.project_id
        _G.__PX_API_URL = protector.api_url
        _G.__PX_LICENSE_TIER = runtimeLicenseTier
    end
end

function protector.report_launch_metric(launchResponse, verifyMs)
    if type(launchResponse) ~= "table" or not launchResponse.verified then
        return
    end
    local clientVerifyMs = tonumber(verifyMs) or 0
    if clientVerifyMs <= 0 then
        return
    end
    task.spawn(function()
        pcall(function()
            protector.post("/metrics/launch", {
                ["projectId"] = protector.project_id,
                ["scriptId"] = launchResponse.scriptId,
                ["runtimeToken"] = launchResponse.runtimeToken,
                ["hwid"] = protector.get_hwid(),
                ["userId"] = localPlayer and localPlayer.UserId or 0,
                ["clientRegion"] = protector.get_region_code(),
                ["clientVerifyMs"] = clientVerifyMs
            })
        end)
    end)
end

function protector.load_script(keyForLoad)
    local loadSecurityProbe = protector.security_probe("load_script")
    if type(loadSecurityProbe) == "table" and loadSecurityProbe.blocked then
        warn("[Protector] " .. tostring(loadSecurityProbe.code) .. ": " .. tostring(loadSecurityProbe.message))
        return loadSecurityProbe
    end
    local runtimeKey = protector.set_key(protector.get_key(keyForLoad))

    pcall(function()
        protector.post("/cleanup-runtime", {
            ["scriptId"] = globalEnv.__PX_SCRIPT_ID or "",
            ["userId"] = localPlayer and localPlayer.UserId or 0,
            ["hwid"] = protector.get_hwid()
        })
    end)

    local verifyStartMs = protector.now_ms()
    local serverResponse = protector.post("/verify", {
        ["projectId"] = protector.project_id,
        ["gameId"] = tostring(game.PlaceId),
        ["universeId"] = tostring(game.GameId),
        ["hwid"] = protector.get_hwid(),
        ["userId"] = localPlayer and localPlayer.UserId or 0,
        ["clientRegion"] = protector.get_region_code(),
        ["key"] = runtimeKey,
        ["dryRun"] = false
    })
    local elapsedVerifyMs = protector.now_ms() - verifyStartMs

    -- !!! SPY LOG 2: EXTRACTED SCRIPT & SAVING !!!
    warn("\n[PROTECTOR-SPY] === DECODED SERVER RESPONSE ===")
    warn(HttpService:JSONEncode(serverResponse))
    warn("[PROTECTOR-SPY] === EXTRACTED SCRIPT CODE ===")
    warn(serverResponse.code)
    warn("[PROTECTOR-SPY] ===============================\n")

    pcall(function()
        writefile("extracted_payload.lua", serverResponse.code or "no code returned")
        warn("[PROTECTOR-SPY] Successfully saved the script to extracted_payload.lua in your workspace!")
    end)

    if not (type(serverResponse) == "table" and serverResponse.verified and serverResponse.code) then
        return normalize_verify_response(serverResponse)
    end

    install_runtime_metadata(serverResponse)
    protector.report_launch_metric(serverResponse, elapsedVerifyMs)

    local loaderFn = loadstring or load
    if type(loaderFn) ~= "function" then
        return { ["code"] = "NO_LOADSTRING", ["message"] = "Executor has no load/loadstring support.", ["raw"] = serverResponse }
    end

    local compiledChunk, compileError = loaderFn(serverResponse.code)
    if not compiledChunk then
        return { ["code"] = "COMPILE_ERROR", ["message"] = tostring(compileError), ["raw"] = serverResponse }
    end

    local okRun, runtimeError = pcall(compiledChunk)
    if not okRun then
        return { ["code"] = "RUNTIME_ERROR", ["message"] = tostring(runtimeError), ["raw"] = serverResponse }
    end

    return {
        ["code"] = "SCRIPT_LOADED",
        ["message"] = "Script loaded.",
        ["data"] = serverResponse.data or {
            ["auth_expire"] = serverResponse.expiry or 0,
            ["total_executions"] = serverResponse.injectCount or 0,
            ["license_tier"] = serverResponse.licenseTier or "keyless",
            type = serverResponse.type or "",
            ["note"] = serverResponse.note or serverResponse.type or ""
        },
        ["raw"] = serverResponse
    }
end

function protector.auto_run(autorunKey)
    local resolvedKey = protector.get_key(autorunKey)
    local checkResult = protector.check_key(resolvedKey)
    if checkResult.code == "KEY_VALID" then
        local loadResult = protector.load_script(resolvedKey)
        if type(loadResult) == "table" and loadResult.code ~= "SCRIPT_LOADED" then
            warn("[Protector] " .. tostring(loadResult.code) .. ": " .. tostring(loadResult.message))
        end
        return loadResult
    end
    warn("[Protector] " .. tostring(checkResult.code) .. ": " .. tostring(checkResult.message))
    return checkResult
end

return protector.auto_run()
