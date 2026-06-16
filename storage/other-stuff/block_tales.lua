--[[
    Funny Block Tales Script
    Credits: Kronerzz, VeinnsDaCheesecake, laryngotracheobronchitis, 
             TexRBLX, CloudHub111 on GitHub | @IDKWHATUSERNAME on RScript.net 
             TexRBLX, testingtesting999, kaiserdegurechaff on ScriptBlox 

			 Combination and optimizating for these scripts by mxsynry on Github and Discord

    HOW TO USE:
    1. Execute the entire script once
    2. Use the toggle functions below to enable/disable features

    Toggle Functions:
    - getgenv().ToggleGodmode()     -- Toggles godmode (default: OFF)
    - getgenv().ToggleBlessed()     -- Toggles auto-guard (default: ON)
    - getgenv().ToggleAutoGreen()   -- Toggles auto green bar (default: ON)

    You can also pass true/false:
    - getgenv().ToggleGodmode(true)   -- Force ON
    - getgenv().ToggleGodmode(false)  -- Force OFF
]]

--[[ my specs:
System Information
Motherboard: Gigabyte GA-B250M-Gaming 3 (Intel B250 chipset, supports 6th/7th gen Intel CPUs)
CPU: Intel Core i5-7400 (4 cores / 4 threads, base 3.00 GHz, turbo up to 3.50 GHz, 6 MB cache, 65W TDP)
RAM: 16 GB DDR4 (dual channel capable)
]]


-- CONFIG TABLE: Edit these values before executing.
-- On re-execution, if you change these, the new values take effect.
-- If you don't change them, previously persisted values are used.
local DEFAULT_CONFIG = {
    NotificationEnabled = true,
    FakerMonitorEnabled = false, -- Set to false to disable resource monitoring, saves fps when not in battle
    Layers = 4, -- Set this to 5 for high to medium end, 4 or 3 for low to medium end, how many hook layers should it use
}

-- Persistent storage across re-executions
getgenv()._BT = getgenv()._BT or {}

-- Determine if user edited the config table since last execution
local configChanged = false
if not getgenv()._BT.LastDefaultConfig then
    configChanged = true
else
    for k, v in pairs(DEFAULT_CONFIG) do
        if getgenv()._BT.LastDefaultConfig[k] ~= v then
            configChanged = true
            break
        end
    end
    if not configChanged then
        for k, v in pairs(getgenv()._BT.LastDefaultConfig) do
            if DEFAULT_CONFIG[k] ~= v then
                configChanged = true
                break
            end
        end
    end
end

if configChanged then
    getgenv()._BT.Config = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        getgenv()._BT.Config[k] = v
    end
    getgenv()._BT.LastDefaultConfig = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        getgenv()._BT.LastDefaultConfig[k] = v
    end
else
    if not getgenv()._BT.Config then
        getgenv()._BT.Config = {}
        for k, v in pairs(DEFAULT_CONFIG) do
            getgenv()._BT.Config[k] = v
        end
    end
end

-- FIX: Ensure all required runtime fields exist even if _BT was initialized as {} earlier
getgenv()._BT.GodmodeEnabled = getgenv()._BT.GodmodeEnabled or false
getgenv()._BT.Connections = getgenv()._BT.Connections or {}
getgenv()._BT.OriginalValues = getgenv()._BT.OriginalValues or {}
getgenv()._BT.UserSettings = getgenv()._BT.UserSettings or {
    Godmode = false,
    Blessed = true,
    AutoGreen = false
}
getgenv()._BT.HookedFaker = getgenv()._BT.HookedFaker or nil
getgenv()._BT.FakerMonitor = getgenv()._BT.FakerMonitor or nil
getgenv()._BT.AutoGreenConnection = getgenv()._BT.AutoGreenConnection or nil
getgenv()._BT.IsHoldingSpace = getgenv()._BT.IsHoldingSpace or false

local NotificationEnabled = getgenv()._BT.Config.NotificationEnabled
local FakerMonitorEnabled = getgenv()._BT.Config.FakerMonitorEnabled
local layers = getgenv()._BT.Config.Layers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local function Notify(title, text, duration)
    if NotificationEnabled then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration or 3
            })
        end)
	else
		print(title, text)
	end
end

-- Load Tex's script (auto-guard, etc.)
if not getgenv()._BT.TexScriptLoaded then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TexRBLX/Roblox-stuff/refs/heads/main/block%20tales/revamp.lua"))()
    getgenv()._BT.TexScriptLoaded = true
else
    print("TexRBLX script already loaded, skipping re-load.")
end

-- fix for auto guard below, for me it works and doesnt lag on Madium, not sure for other execs though, especially mobile
-- perform best on stable executor and a good cpu
local Variables = require(ReplicatedFirst:WaitForChild("Variables"))
repeat task.wait() until Variables.faker
local faker = Variables.faker

-- _BT is already fully initialized above, just grab the reference
local BT = getgenv()._BT

-- Ensure flags are initialized for the hook and auto-green systems
getgenv().BlessedHookEnabled = BT.UserSettings.Blessed
getgenv().AutoGreenEnabled = BT.UserSettings.AutoGreen

-- FIXED: Stack multiple hooks rapidly on the same object, exactly like the original.
-- Each layer captures the previous one, creating a deep chain.
-- This reduces latency and prevents the hook from being bypassed.
local function StackBlessedHooks(targetFaker, layerCount)
    if not targetFaker then return false end
    layerCount = layerCount or 4

    local mt = getrawmetatable(targetFaker)
    if not (mt and mt.__namecall) then
        return false
    end

    for i = 1, layerCount do
        local original
        local hookFunc = newcclosure(function(self, ...)
            local args = {...}
            if not checkcaller() and args[1] == "Blessed" and getgenv().BlessedHookEnabled then
                return true
            end
            return original(self, ...)
        end)
        original = hookmetamethod(targetFaker, "__namecall", hookFunc)
    end

    BT.HookedFaker = targetFaker
    return true
end

-- Initial hook: stack layers only if faker changed or never hooked
if BT.HookedFaker ~= faker then
    local hooked = false
    for attempt = 1, layers do
        if hooked then break end
        hooked = StackBlessedHooks(faker, layers)
        if not hooked then task.wait() end
    end
else
    print("Blessed hooks already active on current faker object, skipping re-hook.")
end

local PLAYER_MOVE_ATTRIBUTES = {
    "Description", "Icon", "SP", "Price", "SPrice", 
    "MoveType", "CallWho", "itemsc", "ItemType", "WhatBadge"
}

local movesFolder = ReplicatedStorage:WaitForChild("Moves")

-- Check if a move is an enemy move (not player move)
local function IsEnemyMove(move)
    for _, attr in ipairs(PLAYER_MOVE_ATTRIBUTES) do
        if move:GetAttribute(attr) ~= nil then
            return false
        end
    end
    return true
end

local function PatchMove(move)
    if not move:IsA("Folder") or not IsEnemyMove(move) then return end

    if not BT.OriginalValues[move] then
        BT.OriginalValues[move] = {
            Damage = move:GetAttribute("Damage"),
            DMGTable = move:GetAttribute("DMGTable")
        }
    end

    local dmg = move:GetAttribute("Damage")
    if type(dmg) == "number" and dmg > 0 then
        move:SetAttribute("Damage", 0)
    end

    local dmgTbl = move:GetAttribute("DMGTable")
    if type(dmgTbl) == "string" then
        local ok, parsed = pcall(function() return HttpService:JSONDecode(dmgTbl) end)
        if ok and type(parsed) == "table" then
            local changed = false
            for k, v in pairs(parsed) do
                if type(v) == "number" and v > 0 then
                    parsed[k] = 0
                    changed = true
                end
            end
            if changed then
                move:SetAttribute("DMGTable", HttpService:JSONEncode(parsed))
            end
        end
    end
end

local function RestoreMove(move)
    if not move:IsA("Folder") or not IsEnemyMove(move) then return end

    local orig = BT.OriginalValues[move]
    if orig then
        if orig.Damage ~= nil then move:SetAttribute("Damage", orig.Damage) end
        if orig.DMGTable ~= nil then move:SetAttribute("DMGTable", orig.DMGTable) end
    end
end

-- Handle a single move (patch or restore based on state)
local function HandleMove(move)
    if not move:IsA("Folder") then return end

    if BT.GodmodeEnabled then
        PatchMove(move)

        local c1 = move:GetAttributeChangedSignal("Damage"):Connect(function()
            if BT.GodmodeEnabled then PatchMove(move) end
        end)
        local c2 = move:GetAttributeChangedSignal("DMGTable"):Connect(function()
            if BT.GodmodeEnabled then PatchMove(move) end
        end)

        table.insert(BT.Connections, c1)
        table.insert(BT.Connections, c2)
    else
        RestoreMove(move)
    end
end

local function ClearConnections()
    for _, conn in ipairs(BT.Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(BT.Connections)
end

local function EnableGodmode()
    BT.GodmodeEnabled = true
    ClearConnections()

    for _, move in ipairs(movesFolder:GetChildren()) do
        HandleMove(move)
    end

    local newMoveConn = movesFolder.ChildAdded:Connect(function(move)
        if BT.GodmodeEnabled then
            task.wait(0.1)
            HandleMove(move)
        end
    end)
    table.insert(BT.Connections, newMoveConn)

    Notify("God Mode", "Enabled! Enemy damage is now 0.", 4)
end

local function DisableGodmode(clearHistory)
    BT.GodmodeEnabled = false
    ClearConnections()

    for _, move in ipairs(movesFolder:GetChildren()) do
        RestoreMove(move)
    end

    if clearHistory ~= false then
        table.clear(BT.OriginalValues)
    end
    Notify("God Mode", "Disabled! Original damage restored.", 4)
end

local LocalPlayer = Players.LocalPlayer

local function StartAutoGreen()
    local DOITNOW = LocalPlayer:WaitForChild("PlayerGui").HUD.Battle.DOITNOW
    local Div = DOITNOW.Meter.Div

    BT.AutoGreenConnection = RunService.Heartbeat:Connect(function()
        if not getgenv().AutoGreenEnabled then
            if BT.IsHoldingSpace then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                BT.IsHoldingSpace = false
            end
            return
        end

        if not DOITNOW.Visible then
            if BT.IsHoldingSpace then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                BT.IsHoldingSpace = false
            end
            return
        end

        if Div.ImageColor3 == Color3.fromRGB(255, 0, 0) then
            if BT.IsHoldingSpace then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                BT.IsHoldingSpace = false
            end
        else
            if not BT.IsHoldingSpace then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                BT.IsHoldingSpace = true
            end
        end
    end)
end

local function StopAutoGreen()
    if BT.AutoGreenConnection then
        BT.AutoGreenConnection:Disconnect()
        BT.AutoGreenConnection = nil
    end
    if BT.IsHoldingSpace then
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        BT.IsHoldingSpace = false
    end
end

-- Internal apply functions (used by monitor + toggles)
-- These do NOT touch UserSettings so the monitor can pause/resume safely.
local function ApplyGodmode(enabled)
    if enabled then
        EnableGodmode()
    else
        DisableGodmode(false) -- preserve OriginalValues for temp disable
    end
end

local function ApplyBlessed(enabled)
    getgenv().BlessedHookEnabled = enabled
    Notify("Blessed Hook", enabled and "Auto-Guard ON" or "Auto-Guard OFF", 3)
    print("BlessedHook:", enabled and "ON" or "OFF")
end

local function ApplyAutoGreen(enabled)
    getgenv().AutoGreenEnabled = enabled
    if enabled then
        if not BT.AutoGreenConnection then
            StartAutoGreen()
        end
        Notify("Auto Green", "Enabled! Auto-holding space on green bar.", 3)
    else
        StopAutoGreen()
        Notify("Auto Green", "Disabled! Manual timing restored.", 3)
    end
    print("AutoGreen:", enabled and "ON" or "OFF")
end

--[[
    Toggle Functions (use these in your executor console):
    These are stored in getgenv() so they persist across re-execution / rejoin.

    getgenv().ToggleGodmode()       -- Toggles godmode ON/OFF (default: OFF)
    getgenv().ToggleBlessed()       -- Toggles auto-guard ON/OFF (default: ON)
    getgenv().ToggleAutoGreen()     -- Toggles auto green bar ON/OFF (default: ON)

    You can also pass true/false:
    getgenv().ToggleGodmode(true)   -- Force godmode ON
    getgenv().ToggleGodmode(false)  -- Force godmode OFF
    getgenv().ToggleBlessed(true)   -- Force auto-guard ON
    getgenv().ToggleBlessed(false)  -- Force auto-guard OFF
    getgenv().ToggleAutoGreen(true) -- Force auto green bar ON
    getgenv().ToggleAutoGreen(false)-- Force auto green bar OFF
]]

getgenv().ToggleGodmode = function(state)
    if state == nil then
        BT.UserSettings.Godmode = not BT.UserSettings.Godmode
    else
        BT.UserSettings.Godmode = state
    end

    if BT.UserSettings.Godmode then
        EnableGodmode()
    else
        DisableGodmode(true) -- intentional disable; clear history
    end

    print("Godmode:", BT.GodmodeEnabled and "ON" or "OFF")
    return BT.UserSettings.Godmode
end

getgenv().ToggleBlessed = function(state)
    if state == nil then
        BT.UserSettings.Blessed = not BT.UserSettings.Blessed
    else
        BT.UserSettings.Blessed = state
    end

    ApplyBlessed(BT.UserSettings.Blessed)
    return BT.UserSettings.Blessed
end

getgenv().ToggleAutoGreen = function(state)
    if state == nil then
        BT.UserSettings.AutoGreen = not BT.UserSettings.AutoGreen
    else
        BT.UserSettings.AutoGreen = state
    end

    ApplyAutoGreen(BT.UserSettings.AutoGreen)
    return BT.UserSettings.AutoGreen
end

-- Cancel previous monitor if re-executing
if BT.FakerMonitor then
    pcall(function() task.cancel(BT.FakerMonitor) end)
end

-- MODIFIED: Faker availability monitor (Option 2 + Option 1 disable)
-- Only manages hook integrity. NEVER disables Blessed/AutoGreen/Godmode.
-- When faker is replaced, it re-stacks hooks just like initial load.
BT.FakerMonitor = task.spawn(function()
    while true do
        if not FakerMonitorEnabled then
            -- Option 1: Monitor completely disabled. Do nothing.
            task.wait(1)
        else
            -- Option 2: Non-disruptive monitoring
            local success, currentFaker = pcall(function()
                return Variables and Variables.faker
            end)
            
            if success and currentFaker then
                -- Faker exists. Ensure our hooks are on the CURRENT object.
                if BT.HookedFaker ~= currentFaker then
                    -- Faker object was replaced (new memory address).
                    -- Re-stack hooks without touching feature toggles.
                    StackBlessedHooks(currentFaker, layers)
                    if NotificationEnabled then
                        Notify("Hook Updated", "Re-stacked "..layers.." hooks on new faker object", 3)
                    end
                end
            end
            -- If faker is nil, we do NOT disable anything.
            -- The old hooks may still catch calls if the object is cached.
            -- When faker returns, we'll detect the new object and re-hook.
            
            task.wait(1)
        end
    end
end)

-- Cleanup previous execution
ClearConnections()
StopAutoGreen()

-- Initialize (faker is already confirmed available from the repeat loop above)
getgenv().ToggleAutoGreen(BT.UserSettings.AutoGreen)
getgenv().ToggleBlessed(BT.UserSettings.Blessed)
-- Godmode stays off by default unless user toggles it

Notify("Script Loaded!", "Block Tales but funny | Godmode: OFF | Blessed: ON | AutoGreen: ON", 5)

print("=" .. string.rep("=", 50))
print("Funny Block Tales Script Loaded")
print("Godmode:", BT.GodmodeEnabled and "ON" or "OFF", "(default: OFF)")
print("BlessedHook:", getgenv().BlessedHookEnabled and "ON" or "OFF", "(default: ON)")
print("AutoGreen:", getgenv().AutoGreenEnabled and "ON" or "OFF", "(default: ON)")
print("FakerMonitor:", FakerMonitorEnabled and "ON" or "OFF", "(default: ON)")
print("Layers:", layers)
print("=" .. string.rep("=", 50))

print("\nHOW TO USE:")
print("  getgenv().ToggleGodmode()       - Toggle godmode ON/OFF")
print("  getgenv().ToggleBlessed()       - Toggle auto-guard ON/OFF")
print("  getgenv().ToggleAutoGreen()     - Toggle auto green bar ON/OFF")
print("  getgenv().ToggleGodmode(true)   - Force godmode ON")
print("  getgenv().ToggleGodmode(false)  - Force godmode OFF")
print("  getgenv().ToggleBlessed(true)   - Force auto-guard ON")
print("  getgenv().ToggleBlessed(false)  - Force auto-guard OFF")
print("  getgenv().ToggleAutoGreen(true) - Force auto green bar ON")
print("  getgenv().ToggleAutoGreen(false)- Force auto green bar OFF")

print("\nNOTE: FakerMonitor only repairs hook integrity. It no longer pauses modules.")

--[[
    END OF SCRIPT

    RECAP OF TOGGLE FUNCTIONS:
    getgenv().ToggleGodmode()       - Toggles godmode (default: OFF)
    getgenv().ToggleBlessed()       - Toggles auto-guard (default: ON)
    getgenv().ToggleAutoGreen()     - Toggles auto green bar (default: ON)

    NOTES:
    - Godmode OFF by default to avoid suspicion
    - Blessed hook ON by default for auto-guard
    - AutoGreen ON by default for perfect timing
    - If using hook guarding, put TEX's autoguard on 0.049s on hardmode to no-hit The Ancients
    - Set to 0.045s in Block Tales Battle Simulator (TEX)
    - fix for auto guard: works on medium, not sure for other execs especially mobile
    - perform best on stable executor and a good cpu
    - All toggles are now in getgenv() and persist across re-execution
    - FakerMonitor now only re-hooks when faker is replaced; never disrupts combat
    - Set FakerMonitorEnabled = false in the DEFAULT_CONFIG table to disable monitoring entirely
    - Edit the DEFAULT_CONFIG table at the top of the script to change settings between executions
]]
