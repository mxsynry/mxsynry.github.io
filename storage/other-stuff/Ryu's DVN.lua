-- =============================================
-- Ryu's Dummies VS Noobs
-- =============================================


--(i converted the UiLib to FluentRenewed using AI, don't shame me if it left some cheeky comments)

if _G.DVNScriptLoaded then
    pcall(_G.UnloadDVNScript)
end
_G.DVNScriptLoaded = true
local ScriptAlive = true

-- ====================================================================
-- [[ FLUENT UI LIBRARY + ADDONS (Fluent-Renewed) ]]
-- ====================================================================
local Fluent = loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau", true))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau", true))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau", true))()

local Window = Fluent:CreateWindow{
    Title = "Ryu's Dummies VS Noobs",
    SubTitle = "by mxsynry (Discord/Github)",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
}

local Tabs = {
    Weapon = Window:CreateTab{ Title = "Weapon Mods", Icon = "rbxassetid://4483362458" },
    Combat = Window:CreateTab{ Title = "Combat & Hitbox", Icon = "rbxassetid://4483362458" },
    Movement = Window:CreateTab{ Title = "Movement & Utility", Icon = "rbxassetid://4483362458" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "rbxassetid://4483362458" }
}

-- ====================================================================
-- [[ SERVICES ]]
-- ====================================================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- ====================================================================
-- [[ CONFIGURATION ]]
-- ====================================================================
local WeaponSettings = { 
    Firerate = 1000, 
    BulletSpeed = 500, 
    Spread = 0, 
    Ammo = 999, 
    Recoil = 0, 
    Kickback = 0 
}

local IgnoredWeapons = {
    ["RPG"] = true, ["Parabolic Hydra"] = true, ["Grenade Launcher"] = true,
    ["Shockwave Device"] = true, ["Intraplanar Device"] = true, ["Rocket Stormer"] = true
}

local TargetEquipment = { ["Jetpack"] = true, ["Terminal velocity"] = true, ["Aerorig"] = true }
local ToolsToAffect = {"Medical Bow", "Recurve", "Vitabow", "Mastermind's Rifle"}

local HitboxSettings = { EnemySize = 50 }
local TierDistances = { NearDistance = 20, FarDistance = 170 }
local MedicSettings = { NearSize = 5, MiddleSize = 15, FarSize = 25 }
local DynamicHeadSettings = { NearSize = 5, MiddleSize = 15, FarSize = 30 }
local BigHeadSize = 10
local NormalHeadSize = Vector3.new(1, 1, 1)

-- ====================================================================
-- [[ STATE VARIABLES ]]
-- ====================================================================
local Enabled = false
local PdcEnabled = false
local InfiniteMeterEnabled = false
local AutoDetectEnabled = false

local HitboxEnabled = false
local MedicHitboxEnabled = false
local DynamicHeadEnabled = false
local BigHeadEnabled = false
local EspEnabled = false
local HideLocallyEnabled = false 

local InfiniteJumpEnabled = false
local AntiStunEnabled = false

-- ====================================================================
-- [[ TABLES & PERFORMANCE CACHE ]]
-- ====================================================================
local CharacterConnections, BackpackConnections, ToolConnections = {}, {}, {}
local PdcConnections, MeterConnections, espCache, activeNPCs = {}, {}, {}, {}
local AutoDetectConn = nil

local UnitsFolder = ReplicatedStorage:WaitForChild("Units", 5) and ReplicatedStorage.Units:WaitForChild("Noobs", 5)
local enemyNames = UnitsFolder and UnitsFolder:GetChildren() or {}

local function updateNPCCache()
    activeNPCs = {}
    for _, v in Workspace:GetChildren() do
        if v:FindFirstChild("Head") then
            for _, x in ipairs(enemyNames) do
                if tostring(x) == v.Name then activeNPCs[v] = true; break end
            end
        end
    end
end
updateNPCCache()

Workspace.ChildAdded:Connect(function(v)
    task.wait()
    for _, x in ipairs(enemyNames) do if tostring(x) == v.Name then activeNPCs[v] = true; break end end
end)
Workspace.ChildRemoved:Connect(function(v) if activeNPCs[v] then activeNPCs[v] = nil end end)

-- ====================================================================
-- [[ WEAPON MOD ENGINE ]]
-- ====================================================================
local function ModifyTool(tool)
    if not tool:IsA("Tool") or IgnoredWeapons[tool.Name] or not Enabled then return end

    local function lockStat(attr, val) if tool:GetAttribute(attr) ~= val then tool:SetAttribute(attr, val) end end
    local function forceStats()
        lockStat("Ammo", WeaponSettings.Ammo) 
        lockStat("Firerate", WeaponSettings.Firerate) 
        lockStat("BulletSpeed", WeaponSettings.BulletSpeed)
        lockStat("Spread", WeaponSettings.Spread) 
        lockStat("Recoil", WeaponSettings.Recoil) 
        lockStat("Kickback", WeaponSettings.Kickback)
    end
    
    forceStats()
    local conn = tool.AttributeChanged:Connect(function()
        if Enabled then forceStats() else conn:Disconnect() end
    end)
    table.insert(ToolConnections, conn)
end

local function ModifyEquipment(tool)
    if not TargetEquipment[tool.Name] or not InfiniteMeterEnabled then return end
    local function lockMeter(obj)
        if not obj:IsA("ValueBase") then return end
        obj.Value = math.huge
        table.insert(MeterConnections, obj:GetPropertyChangedSignal("Value"):Connect(function()
            if InfiniteMeterEnabled then obj.Value = math.huge end
        end))
    end
    if tool:FindFirstChild("Meter") then lockMeter(tool.Meter) end
    table.insert(MeterConnections, tool.ChildAdded:Connect(function(child)
        if child.Name == "Meter" then task.defer(lockMeter, child) end
    end))
end

local function ModifyPdc(character)
    for _, conn in ipairs(PdcConnections) do conn:Disconnect() end
    PdcConnections = {}
    if not PdcEnabled or not character then return end
    local pdcItem = character:FindFirstChild("PDC kit")
    if pdcItem then
        pdcItem:SetAttribute("Charges", 999) pdcItem:SetAttribute("MaxCharges", 999) pdcItem:SetAttribute("Cooldown", 0.1)
        table.insert(PdcConnections, pdcItem:GetAttributeChangedSignal("Charges"):Connect(function() if PdcEnabled then pdcItem:SetAttribute("Charges", 999) end end))
        table.insert(PdcConnections, pdcItem:GetAttributeChangedSignal("MaxCharges"):Connect(function() if PdcEnabled then pdcItem:SetAttribute("MaxCharges", 999) end end))
    end
end

local function WatchContainer(container, connectionTable)
    for _, child in ipairs(container:GetChildren()) do ModifyTool(child) ModifyEquipment(child) end
    table.insert(connectionTable, container.ChildAdded:Connect(function(child)
        task.defer(function()
            ModifyTool(child) ModifyEquipment(child)
            if child.Name == "PDC kit" and container == LocalPlayer.Character then ModifyPdc(LocalPlayer.Character) end
        end)
    end))
end

-- ====================================================================
-- [[ AUTO DETECT WEAPON SYSTEM (Event-Based, No Lag) ]]
-- ====================================================================
local function SetupAutoDetect()
    if AutoDetectConn then AutoDetectConn:Disconnect() AutoDetectConn = nil end
    if not AutoDetectEnabled or not LocalPlayer.Character then return end

    local function onChildAdded(child)
        if not AutoDetectEnabled or not ScriptAlive then return end
        if child:IsA("Tool") and not IgnoredWeapons[child.Name] then
            Fluent:Notify{ Title = "Weapon Detected", Content = "Auto-Modding: " .. child.Name, Duration = 2 }
            task.defer(function()
                ModifyTool(child)
                ModifyEquipment(child)
            end)
        end
    end

    -- Check tools currently in character on startup
    for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
        task.defer(onChildAdded, child)
    end

    AutoDetectConn = LocalPlayer.Character.ChildAdded:Connect(onChildAdded)
end

local function SetupCharacterAutoload(Character)
    for _, conn in ipairs(ToolConnections) do if conn then conn:Disconnect() end end
    for _, conn in ipairs(CharacterConnections) do conn:Disconnect() end
    for _, conn in ipairs(BackpackConnections) do conn:Disconnect() end
    for _, conn in ipairs(PdcConnections) do conn:Disconnect() end
    for _, conn in ipairs(MeterConnections) do conn:Disconnect() end
    ToolConnections, CharacterConnections, BackpackConnections, PdcConnections, MeterConnections = {}, {}, {}, {}, {}
    
    local backpack = LocalPlayer:WaitForChild("Backpack", 5)
    if backpack then WatchContainer(backpack, BackpackConnections) end
    WatchContainer(Character, CharacterConnections)
    ModifyPdc(Character)
    
    SetupAutoDetect() -- Re-hook auto detect on character load
end

if LocalPlayer.Character then SetupCharacterAutoload(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(SetupCharacterAutoload)

-- ====================================================================
-- [[ HITBOX HELPERS ]]
-- ====================================================================
local function RemoveHitboxExtensions()
    for v, _ in pairs(activeNPCs) do
        if v and v:FindFirstChild("Head") then
            v.Head.Transparency = 0 v.Head.Size = Vector3.new(1.2, 1.2, 1.2)
            v.Head.Massless = false v.Head.CanCollide = true v.Head.LocalTransparencyModifier = 0
        end
    end
end

local function UpdateAllActiveHitboxes()
    if not HitboxEnabled then return end
    for v, _ in pairs(activeNPCs) do
        if v and v:FindFirstChild("Head") then
            v.Head.Size = Vector3.new(HitboxSettings.EnemySize, HitboxSettings.EnemySize, HitboxSettings.EnemySize)
            v.Head.Transparency = HideLocallyEnabled and 0 or 0.6
            v.Head.LocalTransparencyModifier = HideLocallyEnabled and 1 or 0
            v.Head.Massless = true v.Head.CanCollide = false
        end
    end
end

-- ====================================================================
-- [[ MAIN ENGINE LOOPS ]]
-- ====================================================================
RunService.Heartbeat:Connect(function()
    if not ScriptAlive or Fluent.Unloaded then return end

    if AntiStunEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.PlatformStand then hum.PlatformStand = false end
    end

    if not EspEnabled then
        if next(espCache) ~= nil then
            for model, highlight in pairs(espCache) do if highlight and highlight.Parent then highlight:Destroy() end end
            table.clear(espCache)
        end
    else
        for _, entity in Workspace:GetChildren() do
            if entity:IsA("Model") and entity:FindFirstChild("Humanoid") and entity:FindFirstChild("HumanoidRootPart") then
                if not espCache[entity] and entity.Name ~= LocalPlayer.Name and not Players:FindFirstChild(entity.Name) then
                    local highlight = Instance.new("Highlight")
                    highlight.FillColor = Color3.fromRGB(0, 255, 0) highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    highlight.FillTransparency = 0.5 highlight.OutlineTransparency = 0
                    highlight.Adornee = entity highlight.Parent = entity espCache[entity] = highlight
                end
            end
        end
        for model, highlight in pairs(espCache) do
            if not model.Parent or not model:FindFirstChild("Humanoid") then
                if highlight and highlight.Parent then highlight:Destroy() end espCache[model] = nil
            end
        end
    end

    if HitboxEnabled then
        for v, _ in pairs(activeNPCs) do
            if v and v:FindFirstChild("Head") then
                v.Head.Size = Vector3.new(HitboxSettings.EnemySize, HitboxSettings.EnemySize, HitboxSettings.EnemySize)
                v.Head.Transparency = HideLocallyEnabled and 0 or 0.6
                v.Head.LocalTransparencyModifier = HideLocallyEnabled and 1 or 0
                v.Head.Massless = true v.Head.CanCollide = false
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not ScriptAlive or Fluent.Unloaded then return end
    if not (BigHeadEnabled or DynamicHeadEnabled or MedicHitboxEnabled) then return end
    local myChar = LocalPlayer.Character if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart") if not myRoot then return end

    local usingBow = false
    if BigHeadEnabled then
        local equippedTool = myChar:FindFirstChildOfClass("Tool")
        if equippedTool then for _, toolName in ipairs(ToolsToAffect) do if equippedTool.Name == toolName then usingBow = true; break end end end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Character then continue end
        local head = player.Character:FindFirstChild("Head") if not head then continue end

        if usingBow then
            head.Size = Vector3.new(BigHeadSize, BigHeadSize, BigHeadSize)
            head.Transparency = HideLocallyEnabled and 0 or 0.5
            head.BrickColor = BrickColor.new("Really red") head.Material = Enum.Material.Neon
        elseif DynamicHeadEnabled then
            local dist = (head.Position - myRoot.Position).Magnitude
            local size = dist <= TierDistances.NearDistance and DynamicHeadSettings.NearSize or (dist >= TierDistances.FarDistance and DynamicHeadSettings.FarSize or DynamicHeadSettings.MiddleSize)
            head.Size = Vector3.new(size, size, size)
            head.Transparency = HideLocallyEnabled and 0 or 0.4
            head.BrickColor = BrickColor.new("Really red") head.Material = Enum.Material.Neon
        elseif MedicHitboxEnabled then
            local dist = (head.Position - myRoot.Position).Magnitude
            local size = dist <= TierDistances.NearDistance and MedicSettings.NearSize or (dist >= TierDistances.FarDistance and MedicSettings.FarSize or MedicSettings.MiddleSize)
            local color = dist <= TierDistances.NearDistance and BrickColor.new("Bright blue") or BrickColor.new("Lavender")
            head.Size = Vector3.new(size, size, size)
            head.Transparency = HideLocallyEnabled and 0 or 0.4
            head.BrickColor = color head.Material = Enum.Material.Neon
        else
            if head.Size ~= NormalHeadSize then
                head.Size = NormalHeadSize head.Transparency = 0
                head.BrickColor = BrickColor.new("Bright red") head.Material = Enum.Material.Plastic
                head.CanCollide = false head.Massless = false
            end
        end
        head.LocalTransparencyModifier = (HideLocallyEnabled and (usingBow or DynamicHeadEnabled or MedicHitboxEnabled)) and 1 or 0
        head.CanCollide = false head.Massless = true
    end
end)

UserInputService.JumpRequest:Connect(function()
    if InfiniteJumpEnabled and ScriptAlive then
        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping") end)
    end
end)

-- ====================================================================
-- [[ FLUENT UI ELEMENTS ]]
-- ====================================================================

-- WEAPON TAB
local SuperWeapons = Tabs.Weapon:CreateToggle("SuperWeapons", { Title = "Overpowers weapon stats", Default = false })
SuperWeapons:OnChanged(function()
    Enabled = Fluent.Options.SuperWeapons.Value
    if LocalPlayer.Character then SetupCharacterAutoload(LocalPlayer.Character) end
end)

-- Auto Detect Weapon Toggle
local AutoDetect = Tabs.Weapon:CreateToggle("AutoDetect", { Title = "Auto-Detect & Mod Guns", Default = false })
AutoDetect:OnChanged(function()
    AutoDetectEnabled = Fluent.Options.AutoDetect.Value
    if AutoDetectEnabled then
        -- Auto-detect forces the main weapon mod engine on
        Enabled = true
        Fluent.Options.SuperWeapons:SetValue(true)
        if LocalPlayer.Character then SetupAutoDetect() end
        Fluent:Notify{ Title = "Auto-Detect", Content = "Enabled! Picking up a gun will mod it.", Duration = 3 }
    else
        if AutoDetectConn then AutoDetectConn:Disconnect() AutoDetectConn = nil end
    end
end)

local MorePDCS = Tabs.Weapon:CreateToggle("MorePDCS", { Title = "Provides custom charge counts to PDC", Default = false })
MorePDCS:OnChanged(function()
    PdcEnabled = Fluent.Options.MorePDCS.Value
    if LocalPlayer.Character and PdcEnabled then ModifyPdc(LocalPlayer.Character) end
end)

local InfJetpack = Tabs.Weapon:CreateToggle("InfJetpack", { Title = "Locks internal meter instances", Default = false })
InfJetpack:OnChanged(function()
    InfiniteMeterEnabled = Fluent.Options.InfJetpack.Value
    if LocalPlayer.Character then SetupCharacterAutoload(LocalPlayer.Character) end
end)

Tabs.Weapon:CreateSlider("FirerateSlider", {
    Title = "Weapon fire rate delay",
    Default = 1000,
    Min = 0,
    Max = 5000,
    Rounding = 10,
    Callback = function(Value)
        WeaponSettings.Firerate = Value
        if Enabled then
            for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
                if child:IsA("Tool") and not IgnoredWeapons[child.Name] then child:SetAttribute("Firerate", Value) end
            end
        end
    end
})

Tabs.Weapon:CreateSlider("BulletSpeedSlider", {
    Title = "Projectile velocity",
    Default = 500,
    Min = 0,
    Max = 2000,
    Rounding = 10,
    Callback = function(Value)
        WeaponSettings.BulletSpeed = Value
        if Enabled then
            for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
                if child:IsA("Tool") and not IgnoredWeapons[child.Name] then child:SetAttribute("BulletSpeed", Value) end
            end
        end
    end
})

-- COMBAT TAB
local NPCHitbox = Tabs.Combat:CreateToggle("NPCHitbox", { Title = "Extends NPC head hitboxes", Default = false })
NPCHitbox:OnChanged(function()
    HitboxEnabled = Fluent.Options.NPCHitbox.Value
    if HitboxEnabled then UpdateAllActiveHitboxes() else RemoveHitboxExtensions() end
end)

Tabs.Combat:CreateSlider("NPCSizeSlider", {
    Title = "NPC Hitbox radius",
    Default = 50,
    Min = 5,
    Max = 150,
    Rounding = 1,
    Callback = function(Value)
        HitboxSettings.EnemySize = Value
        if HitboxEnabled then UpdateAllActiveHitboxes() end
    end
})

Tabs.Combat:CreateParagraph("Player Hitboxes Note", {
    Title = "Player Hitboxes",
    Content = "Note: Modifies Heads to prevent freezing teammates."
})

local MedicHitbox = Tabs.Combat:CreateToggle("MedicHitbox", { Title = "Near/Mid/Far head sizing (Blue)", Default = false })
MedicHitbox:OnChanged(function()
    MedicHitboxEnabled = Fluent.Options.MedicHitbox.Value
end)

local DynamicHead = Tabs.Combat:CreateToggle("DynamicHead", { Title = "Near/Mid/Far head sizing (Red)", Default = false })
DynamicHead:OnChanged(function()
    DynamicHeadEnabled = Fluent.Options.DynamicHead.Value
end)

local BigHead = Tabs.Combat:CreateToggle("BigHead", { Title = "Static large head holding Medic/Bow", Default = false })
BigHead:OnChanged(function()
    BigHeadEnabled = Fluent.Options.BigHead.Value
end)

local ESP = Tabs.Combat:CreateToggle("ESP", { Title = "Renders highlights across level threats", Default = false })
ESP:OnChanged(function()
    EspEnabled = Fluent.Options.ESP.Value
end)

local HideHitboxVisuals = Tabs.Combat:CreateToggle("HideHitboxVisuals", { Title = "Transparent Hitboxes", Default = false })
HideHitboxVisuals:OnChanged(function()
    HideLocallyEnabled = Fluent.Options.HideHitboxVisuals.Value
    if HitboxEnabled then UpdateAllActiveHitboxes() end
end)

-- MOVEMENT TAB
local InfJump = Tabs.Movement:CreateToggle("InfJump", { Title = "Jump infinitely in mid-air", Default = false })
InfJump:OnChanged(function()
    InfiniteJumpEnabled = Fluent.Options.InfJump.Value
end)

local AntiStun = Tabs.Movement:CreateToggle("AntiStun", { Title = "Instantly recovers from ragdolls/stuns", Default = false })
AntiStun:OnChanged(function()
    AntiStunEnabled = Fluent.Options.AntiStun.Value
end)

Tabs.Movement:CreateSlider("WalkSpeedSlider", {
    Title = "Character movement speed",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 1,
    Callback = function(Value)
        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Value end)
    end
})

Tabs.Movement:CreateSlider("JumpPowerSlider", {
    Title = "Character jump height",
    Default = 50,
    Min = 50,
    Max = 300,
    Rounding = 5,
    Callback = function(Value)
        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid").JumpPower = Value end)
    end
})

-- SETTINGS TAB
Tabs.Settings:CreateButton{
    Title = "RefreshWeapons",
    Description = "Fixes guns if attributes bug out",
    Callback = function()
        if LocalPlayer.Character then SetupCharacterAutoload(LocalPlayer.Character) end
        Fluent:Notify{ Title = "System", Content = "Weapons refreshed successfully.", Duration = 2 }
    end
}

Tabs.Settings:CreateParagraph("ServerActions", {
    Title = "Server Actions",
    Content = "Rejoin the current server or hop to a new one."
})

Tabs.Settings:CreateButton{
    Title = "Rejoin Server",
    Description = "Teleports you back into the exact same server.",
    Callback = function()
        Fluent:Notify{ Title = "Server", Content = "Rejoining...", Duration = 2 }
        task.delay(1, function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
}

Tabs.Settings:CreateButton{
    Title = "Server Hop",
    Description = "Finds a new server with available slots and joins it.",
    Callback = function()
        Fluent:Notify{ Title = "Server", Content = "Searching for a server...", Duration = 3 }
        task.spawn(function()
            local success, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
            end)
            
            if success and result and result.data then
                local servers = {}
                for _, server in ipairs(result.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, server.id)
                    end
                end
                
                if #servers > 0 then
                    task.delay(1, function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
                    end)
                else
                    Fluent:Notify{ Title = "Server Hop", Content = "Couldn't find any available servers.", Duration = 4 }
                end
            else
                Fluent:Notify{ Title = "Server Hop", Content = "Failed to fetch server list. (HTTP Error)", Duration = 4 }
            end
        end)
    end
}

Tabs.Settings:CreateButton{
    Title = "UnloadScript",
    Description = "Stops all loops, wipes ESP, resets hitboxes",
    Callback = function()
        ScriptAlive = false
        Enabled = false; EspEnabled = false; HitboxEnabled = false
        MedicHitboxEnabled = false; DynamicHeadEnabled = false; BigHeadEnabled = false
        InfiniteJumpEnabled = false; AntiStunEnabled = false; AutoDetectEnabled = false

        if AutoDetectConn then AutoDetectConn:Disconnect() end
        RemoveHitboxExtensions()
        for model, highlight in pairs(espCache) do if highlight and highlight.Parent then highlight:Destroy() end end
        table.clear(espCache)

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
                local head = player.Character.Head
                head.Size = NormalHeadSize head.Transparency = 0 head.LocalTransparencyModifier = 0
                head.Material = Enum.Material.Plastic
            end
        end

        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = 16 end)
        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid").JumpPower = 50 end)

        if Window and typeof(Window.Destroy) == "function" then
            pcall(Window.Destroy, Window)
        end

        _G.DVNScriptLoaded = false
    end
}

-- ====================================================================
-- [[ MANAGERS (Themes & Saving) ]]
-- ====================================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
Window:SelectTab(1)

-- ====================================================================
-- [[ STARTUP ]]
-- ====================================================================
Fluent:Notify{
    Title = "Ryu's DVN",
    Content = "Successfully loaded! Check Settings for Themes, Saving, and Hopping.",
    Duration = 6.5
}

SaveManager:LoadAutoloadConfig()
