
if _G.DVNScriptLoaded then
    pcall(_G.UnloadDVNScript)
end
_G.DVNScriptLoaded = true
local ScriptAlive = true

-- ====================================================================
-- [[ FLUENT UI LIBRARY ]]
-- ====================================================================
local Fluent = loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau", true))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau", true))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau", true))()

local Window = Fluent:CreateWindow{
    Title = "Ryu's Dummies VS Noobs",
    SubTitle = "I love my husband fr",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
}

local Tabs = {
    Weapons = Window:CreateTab{ Title = "Weapons", Icon = "rbxassetid://4483362458" },
    Hitbox = Window:CreateTab{ Title = "Hitbox Expander", Icon = "rbxassetid://4483362458" },
    Visuals = Window:CreateTab{ Title = "ESP & Visuals", Icon = "rbxassetid://4483362458" },
    Misc = Window:CreateTab{ Title = "Solvers & Misc", Icon = "rbxassetid://4483362458" },
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
local TeleportService = game:GetService("TeleportService")
local Camera = Workspace.CurrentCamera

-- ====================================================================
-- [[ DVN BOSS LOGIC ]]
-- ====================================================================
local Remotes = {bullet=nil, sound=nil}

local function SetupRemotes()
    local ok, rem = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("Replication", 5)
    end)
    if ok and rem then
        Remotes.bullet = rem:FindFirstChild("ReplicateBullet")
        Remotes.sound = rem:FindFirstChild("ReplicateSound")
    end
end

SetupRemotes()
ReplicatedStorage.ChildAdded:Connect(function(c)
    if c.Name == "Remotes" then
        task.wait(1)
        SetupRemotes()
    end
end)

local function GetBossTarget(entity)
    if not entity or not entity.Parent then return nil, nil, nil end
    
    if entity.Name == "Prometheus" then
        local prom = Workspace:FindFirstChild("Prometheus")
        if prom then
            local tankNames = {"PropaneTank", "PropaneTank2", "PropaneTank 2"}
            for _, tn in ipairs(tankNames) do
                local t = prom:FindFirstChild(tn)
                if t and t.Parent then
                    local h = t:FindFirstChild("Hitbox")
                    if h and h.Parent then return h, "Tank", nil end
                end
            end
        end
        return entity:FindFirstChild("Head"), "Main", entity:FindFirstChildOfClass("Humanoid")
        
    elseif entity.Name == "Hermes" then
        local launchers = {"Launcher1", "Launcher2", "Launcher3", "Launcher4"}
        for _, ln in ipairs(launchers) do
            local l = entity:FindFirstChild(ln)
            if l and l.Parent then
                local p = l:IsA("BasePart") and l or l:FindFirstChildOfClass("BasePart")
                if p then return p, ln, nil end
            end
        end
        return entity:FindFirstChild("Hitbox"), "Hitbox", nil
        
    elseif entity.Name == "Platform" then
        for i = 1, 4 do
            local e = entity:FindFirstChild("Emplacement"..i)
            if e and e.Parent then
                local h = e:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local gun = e:FindFirstChild("GunBase"..i) or e:FindFirstChildOfClass("BasePart")
                    if gun then return gun, "Emp", h end
                end
            end
        end
        return entity:FindFirstChild("AmmoStorage"), "Ammo", nil
        
    elseif entity.Name == "Tank" then
        for _, c in ipairs(entity:GetChildren()) do
            if c.Name == "PropaneTank" and c.Parent then
                local h = c:FindFirstChildOfClass("Humanoid")
                if not h or h.Health > 0 then
                    return c:FindFirstChild("Hitbox") or c:FindFirstChildOfClass("BasePart"), "Tank", h
                end
            end
        end
        
    elseif entity.Name == "APU" then
        local p = entity:FindFirstChild("Pilot")
        if p then
            local h = p:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return p:FindFirstChild("Head"), nil, h end
        end
    end
    
    return entity:FindFirstChild("Head"), nil, entity:FindFirstChildOfClass("Humanoid")
end

-- ====================================================================
-- [[ CONFIGURATIONS ]]
-- ====================================================================
local WeaponSettings = { Firerate = 1000, BulletSpeed = 500, Spread = 0, Ammo = 999, Recoil = 0, Kickback = 0 }
local IgnoredWeapons = { ["RPG"] = true, ["Parabolic Hydra"] = true, ["Grenade Launcher"] = true, ["Shockwave Device"] = true, ["Intraplanar Device"] = true, ["Rocket Stormer"] = true }

local Farm = { Enabled = false, MaxRange = 300, GunDelay = 50, MeleeDelay = 150 }

local NPC_HB = { Enabled = false, Dynamic = false, StaticSize = 20, Min = 2, Max = 30, Near = 2, Far = 30 }
local Player_HB = { Enabled = false, Dynamic = false, StaticSize = 20, Min = 2, Max = 30, Near = 2, Far = 30 }

local ColorTable = {
    ["Bright Red"] = Color3.fromRGB(255, 0, 0), ["Dark Red"] = Color3.fromRGB(139, 0, 0),
    ["Bright Green"] = Color3.fromRGB(0, 255, 0), ["Bright Blue"] = Color3.fromRGB(0, 100, 255),
    ["Light Blue"] = Color3.fromRGB(135, 206, 250), ["Yellow"] = Color3.fromRGB(255, 255, 0),
    ["Purple"] = Color3.fromRGB(128, 0, 128), ["Pink"] = Color3.fromRGB(255, 105, 180),
    ["Orange"] = Color3.fromRGB(255, 165, 0), ["Cyan"] = Color3.fromRGB(0, 255, 255),
    ["White"] = Color3.fromRGB(255, 255, 255), ["Magenta"] = Color3.fromRGB(255, 0, 255)
}
local ESP_Config = { Enabled = false, EnemyColor = "Bright Red", TeamColor = "Bright Blue", OutlineColor = "White", Transparency = 0.5, OutlineTransparency = 0 }

local Solvers = { Prometheus = false, Hermes = false, Platform = false, Tank = false, TridentQTE = false }
local WeaponModEnabled = false
local InfJumpEnabled = false
local AntiStunEnabled = false
local espCache = {}

-- ====================================================================
-- [[ NPC CACHE ]]
-- ====================================================================
local UnitsFolder = ReplicatedStorage:WaitForChild("Units", 5) and ReplicatedStorage.Units:WaitForChild("Noobs", 5)
local enemyNames = UnitsFolder and UnitsFolder:GetChildren() or {}

local activeNPCs = {}
local function updateNPCCache()
    activeNPCs = {}
    for _, v in Workspace:GetChildren() do
        if v:FindFirstChild("Head") then
            for _, x in ipairs(enemyNames) do
                if tostring(x) == v.Name then 
                    activeNPCs[v] = true
                    break 
                end
            end
        end
    end
end
updateNPCCache()

Workspace.ChildAdded:Connect(function(v)
    task.wait()
    for _, x in ipairs(enemyNames) do 
        if tostring(x) == v.Name then 
            activeNPCs[v] = true
            break 
        end 
    end
end)

Workspace.ChildRemoved:Connect(function(v) 
    if activeNPCs[v] then 
        activeNPCs[v] = nil 
    end 
end)

-- ====================================================================
-- [[ CORE LOGIC ]]
-- ====================================================================
local lastAttackTime = 0

local function AutoAttack()
    if not Farm.Enabled or not ScriptAlive then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end
    
    local myHead = myChar:FindFirstChild("Head")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myHead or not myRoot then return end
    
    local tool = myChar:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    local isGun = tool:FindFirstChild("VerifyFire") ~= nil
    local verifyHit = tool:FindFirstChild("VerifyHit")
    local verifyFire = tool:FindFirstChild("VerifyFire")
    if not verifyHit then return end 
    
    local bestPart, bestHum, bestDist = nil, nil, math.huge
    
    -- SYNTAX FIX: Removed "continue" statements for executor compatibility
    for _, ent in ipairs(Workspace:GetChildren()) do
        if ent:IsA("Model") and ent:FindFirstChild("HumanoidRootPart") and ent ~= myChar and not Players:GetPlayerFromCharacter(ent) then 
            local hum = ent:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local targetPart = GetBossTarget(ent)
                if targetPart and targetPart.Parent then
                    local dist = (myRoot.Position - targetPart.Position).Magnitude
                    if dist <= Farm.MaxRange and dist < bestDist then
                        bestDist = dist
                        bestPart = targetPart
                        bestHum = hum
                    end
                end
            end
        end
    end
    
    if not bestPart then return end
    
    if isGun then
        pcall(function() verifyFire:FireServer() end)
        task.delay(0.03, function()
            if not ScriptAlive or not bestPart or not bestPart.Parent then return end
            if Remotes.bullet then
                local dir = (bestPart.Position - myHead.Position).Unit
                pcall(function()
                    Remotes.bullet:FireServer(myHead.Position, dir, 3000, {
                        HighFidelitySegmentSize = 0.5, Acceleration = Vector3.new(0,0,0),
                        RaycastParams = RaycastParams.new{FilterDescendantsInstances = {myChar, Camera}, FilterType = Enum.RaycastFilterType.Exclude},
                        MaxDistance = 3000, AutoIgnoreContainer = true, HighFidelityBehavior = 1
                    })
                end)
            end
            if bestHum and bestHum.Parent and bestHum.Health > 0 then
                pcall(function() verifyHit:FireServer(bestHum, bestPart.Position, myHead.Position) end)
            else
                pcall(function() verifyHit:FireServer(bestPart, bestPart.Position, myHead.Position) end)
            end
            if Remotes.sound then pcall(function() Remotes.sound:FireServer("rbxassetid://6731036217", math.random(90,110)/100) end) end
        end)
    else
        if bestHum and bestHum.Parent and bestHum.Health > 0 then
            pcall(function() verifyHit:FireServer(bestHum, bestPart.Position, myHead.Position) end)
        else
            pcall(function() verifyHit:FireServer(bestPart, bestPart.Position, myHead.Position) end)
        end
        if Remotes.sound then pcall(function() Remotes.sound:FireServer("rbxassetid://6241709963", math.random(60,80)/100) end) end
    end
end

-- ====================================================================
-- [[ WEAPON MOD ENGINE ]]
-- ====================================================================
local ToolConns = {}

local function ModifyTool(tool)
    if not tool:IsA("Tool") or IgnoredWeapons[tool.Name] or not WeaponModEnabled then return end
    local function lock(attr, val) if tool:GetAttribute(attr) ~= val then tool:SetAttribute(attr, val) end end
    local function force() lock("Ammo", WeaponSettings.Ammo) lock("Firerate", WeaponSettings.Firerate) lock("BulletSpeed", WeaponSettings.BulletSpeed) lock("Spread", WeaponSettings.Spread) lock("Recoil", WeaponSettings.Recoil) lock("Kickback", WeaponSettings.Kickback) end
    force()
    table.insert(ToolConns, tool.AttributeChanged:Connect(function() if WeaponModEnabled then force() end end))
end

local function WatchContainer(c) 
    for _, ch in ipairs(c:GetChildren()) do ModifyTool(ch) end 
    table.insert(ToolConns, c.ChildAdded:Connect(function(ch) task.defer(ModifyTool, ch) end)) 
end

local function SetupWeaponWatcher()
    for _, conn in ipairs(ToolConns) do if conn then conn:Disconnect() end end
    ToolConns = {}
    if not WeaponModEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    WatchContainer(char)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then WatchContainer(backpack) end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    SetupWeaponWatcher()
end)

-- ====================================================================
-- [[ MAIN LOOPS ]]
-- ====================================================================
RunService.Heartbeat:Connect(function(dt)
    if not ScriptAlive then return end
    if AntiStunEnabled and LocalPlayer.Character then 
        local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid") 
        if h and h.PlatformStand then h.PlatformStand = false end 
    end

    if Farm.Enabled then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        local isGun = tool and tool:FindFirstChild("VerifyFire") ~= nil
        local delaySec = (isGun and Farm.GunDelay or Farm.MeleeDelay) / 1000
        if tick() - lastAttackTime > delaySec then AutoAttack() lastAttackTime = tick() end
    end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    for v, _ in pairs(activeNPCs) do
        if v and v:FindFirstChild("Head") and v:FindFirstChild("HumanoidRootPart") then
            local head = v.Head
            if NPC_HB.Enabled then
                local size = NPC_HB.StaticSize
                if NPC_HB.Dynamic and myRoot then
                    local dist = (head.Position - myRoot.Position).Magnitude
                    local alpha = math.clamp((dist - NPC_HB.Near) / (NPC_HB.Far - NPC_HB.Near), 0, 1)
                    alpha = alpha * alpha * (3 - 2 * alpha)
                    size = NPC_HB.Min + (NPC_HB.Max - NPC_HB.Min) * alpha
                end
                head.Size = Vector3.new(size, size, size)
                head.Massless = true
                head.CanCollide = false
                head.Transparency = 0.6
                head.LocalTransparencyModifier = 1 
                head.BrickColor = BrickColor.new("Really red")
                head.Material = Enum.Material.Neon
            else
                if head.Size ~= Vector3.new(1,1,1) then 
                    head.Size = Vector3.new(1,1,1)
                    head.Transparency = 0
                    head.LocalTransparencyModifier = 0
                    head.Material = Enum.Material.Plastic
                    head.BrickColor = BrickColor.new("Medium stone grey")
                    head.Massless = false
                    head.CanCollide = true 
                end
            end
        end
    end

    -- PING BUG FIX: Strictly loop ONLY players for player hitboxes
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("HumanoidRootPart") then
            local head = player.Character.Head
            if Player_HB.Enabled then
                local size = Player_HB.StaticSize
                if Player_HB.Dynamic and myRoot then
                    local dist = (head.Position - myRoot.Position).Magnitude
                    local alpha = math.clamp((dist - Player_HB.Near) / (Player_HB.Far - Player_HB.Near), 0, 1)
                    alpha = alpha * alpha * (3 - 2 * alpha)
                    size = Player_HB.Min + (Player_HB.Max - Player_HB.Min) * alpha
                end
                head.Size = Vector3.new(size, size, size)
                head.Massless = true
                head.CanCollide = false
                head.Transparency = 0.6
                head.LocalTransparencyModifier = 1 
                head.BrickColor = BrickColor.new("Really red")
                head.Material = Enum.Material.Neon
            else
                if head.Size ~= Vector3.new(1,1,1) then 
                    head.Size = Vector3.new(1,1,1)
                    head.Transparency = 0
                    head.LocalTransparencyModifier = 0
                    head.Material = Enum.Material.Plastic
                    head.BrickColor = BrickColor.new("Medium stone grey")
                    head.Massless = false
                    head.CanCollide = true 
                end
            end
        end
    end

    if ESP_Config.Enabled then
        local enemyCol = ColorTable[ESP_Config.EnemyColor] or Color3.fromRGB(255,0,0)
        local teamCol = ColorTable[ESP_Config.TeamColor] or Color3.fromRGB(0,100,255)
        local outCol = ColorTable[ESP_Config.OutlineColor] or Color3.fromRGB(255,255,255)

        for _, ent in ipairs(Workspace:GetChildren()) do
            if ent:IsA("Model") and ent:FindFirstChildOfClass("Humanoid") and ent:FindFirstChild("HumanoidRootPart") and ent ~= LocalPlayer.Character then
                local hum = ent:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    if not espCache[ent] then
                        local h = Instance.new("Highlight")
                        h.Adornee = ent
                        h.Name = "DVN_ESP"
                        h.Parent = Workspace
                        espCache[ent] = h
                    end

                    local plr = Players:GetPlayerFromCharacter(ent)
                    local isPlayerTeammate = plr ~= nil

                    espCache[ent].FillColor = isPlayerTeammate and teamCol or enemyCol
                    espCache[ent].OutlineColor = outCol
                    espCache[ent].FillTransparency = ESP_Config.Transparency
                    espCache[ent].OutlineTransparency = ESP_Config.OutlineTransparency
                else
                    if espCache[ent] then 
                        espCache[ent]:Destroy()
                        espCache[ent] = nil 
                    end
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not ESP_Config.Enabled then
        for ent, h in pairs(espCache) do 
            if h and h.Parent then h:Destroy() end
            espCache[ent] = nil 
        end
    else
        for ent, h in pairs(espCache) do
            if not ent.Parent or not ent:FindFirstChildOfClass("Humanoid") or ent:FindFirstChildOfClass("Humanoid").Health <= 0 then
                if h and h.Parent then h:Destroy() end
                espCache[ent] = nil
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function() 
    if InfJumpEnabled and ScriptAlive then 
        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping") end) 
    end 
end)

Tabs.Weapons:CreateToggle("WeaponMods", {Title = "Super Weapons", Default = false}):OnChanged(function() WeaponModEnabled = Fluent.Options.WeaponMods.Value; SetupWeaponWatcher() end)
Tabs.Weapons:CreateSlider("Firerate", {Title = "Weapon Fire Rate", Default = 1000, Min = 0, Max = 5000, Rounding = 10, Callback = function(v) WeaponSettings.Firerate = v end})
Tabs.Weapons:CreateSlider("BulletSpeed", {Title = "Projectile Velocity", Default = 500, Min = 0, Max = 2000, Rounding = 10, Callback = function(v) WeaponSettings.BulletSpeed = v end})

Tabs.Weapons:CreateParagraph("FarmHeader", {Title = "━━ Silent Auto-Farm (NPCs Only) ━━", Content = "Automatically attacks nearest NPC. Hold a gun or melee."})
Tabs.Weapons:CreateToggle("AutoFarm", {Title = "Enable Auto-Farm", Default = false}):OnChanged(function() Farm.Enabled = Fluent.Options.AutoFarm.Value end)
Tabs.Weapons:CreateSlider("FarmRange", {Title = "Max Kill Range (Studs)", Default = 300, Min = 50, Max = 1000, Rounding = 10, Callback = function(v) Farm.MaxRange = v end})
Tabs.Weapons:CreateSlider("GunDelay", {Title = "Gun Attack Delay (ms)", Default = 50, Min = 10, Max = 1000, Rounding = 10, Callback = function(v) Farm.GunDelay = v end})
Tabs.Weapons:CreateSlider("MeleeDelay", {Title = "Melee Attack Delay (ms)", Default = 150, Min = 50, Max = 2000, Rounding = 10, Callback = function(v) Farm.MeleeDelay = v end})

Tabs.Hitbox:CreateParagraph("HitboxInfo", {Title = "Dynamic Logic", Content = "Shrinks at 2 studs (melee range), expands smoothly to max size for shooting."})

Tabs.Hitbox:CreateToggle("NPC_HB", {Title = "Enable NPC Hitbox", Default = false}):OnChanged(function() NPC_HB.Enabled = Fluent.Options.NPC_HB.Value end)
Tabs.Hitbox:CreateToggle("NPC_Dynamic", {Title = "NPC Use Dynamic Size?", Default = false}):OnChanged(function() NPC_HB.Dynamic = Fluent.Options.NPC_Dynamic.Value end)
Tabs.Hitbox:CreateSlider("NPC_Static", {Title = "NPC Static Size", Default = 20, Min = 2, Max = 50, Rounding = 1, Callback = function(v) NPC_HB.StaticSize = v end})
Tabs.Hitbox:CreateSlider("NPC_Min", {Title = "NPC Min Size (Close)", Default = 2, Min = 1, Max = 10, Rounding = 1, Callback = function(v) NPC_HB.Min = v end})
Tabs.Hitbox:CreateSlider("NPC_Max", {Title = "NPC Max Size (Far)", Default = 30, Min = 10, Max = 60, Rounding = 1, Callback = function(v) NPC_HB.Max = v end})
Tabs.Hitbox:CreateSlider("NPC_Near", {Title = "NPC Shrink Threshold (Studs)", Default = 2, Min = 1, Max = 20, Rounding = 1, Callback = function(v) NPC_HB.Near = v end})
Tabs.Hitbox:CreateSlider("NPC_Far", {Title = "NPC Max Out Dist (Studs)", Default = 30, Min = 15, Max = 150, Rounding = 1, Callback = function(v) NPC_HB.Far = v end})

Tabs.Hitbox:CreateToggle("Player_HB", {Title = "Enable Player Hitbox", Default = false}):OnChanged(function() Player_HB.Enabled = Fluent.Options.Player_HB.Value end)
Tabs.Hitbox:CreateToggle("Player_Dynamic", {Title = "Player Use Dynamic Size?", Default = false}):OnChanged(function() Player_HB.Dynamic = Fluent.Options.Player_Dynamic.Value end)
Tabs.Hitbox:CreateSlider("Player_Static", {Title = "Player Static Size", Default = 20, Min = 2, Max = 50, Rounding = 1, Callback = function(v) Player_HB.StaticSize = v end})
Tabs.Hitbox:CreateSlider("Player_Min", {Title = "Player Min Size (Close)", Default = 2, Min = 1, Max = 10, Rounding = 1, Callback = function(v) Player_HB.Min = v end})
Tabs.Hitbox:CreateSlider("Player_Max", {Title = "Player Max Size (Far)", Default = 30, Min = 10, Max = 60, Rounding = 1, Callback = function(v) Player_HB.Max = v end})
Tabs.Hitbox:CreateSlider("Player_Near", {Title = "Player Shrink Threshold (Studs)", Default = 2, Min = 1, Max = 20, Rounding = 1, Callback = function(v) Player_HB.Near = v end})
Tabs.Hitbox:CreateSlider("Player_Far", {Title = "Player Max Out Dist (Studs)", Default = 30, Min = 15, Max = 150, Rounding = 1, Callback = function(v) Player_HB.Far = v end})

Tabs.Visuals:CreateParagraph("ESPInfo", {Title = "Player vs NPC Detection", Content = "Teammate Color = Other Players. Enemy Color = NPCs/Bosses."})
Tabs.Visuals:CreateToggle("ESP", {Title = "Enable Highlight ESP", Default = false}):OnChanged(function() ESP_Config.Enabled = Fluent.Options.ESP.Value end)
Tabs.Visuals:CreateDropdown("EnemyColor", {Title = "Enemy Fill Color (NPCs)", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 1, Callback = function(v) ESP_Config.EnemyColor = v end})
Tabs.Visuals:CreateDropdown("TeamColor", {Title = "Teammate Fill Color (Players)", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 4, Callback = function(v) ESP_Config.TeamColor = v end})
Tabs.Visuals:CreateDropdown("OutlineColor", {Title = "Outline Color", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 11, Callback = function(v) ESP_Config.OutlineColor = v end})
Tabs.Visuals:CreateSlider("Transparency", {Title = "Fill Transparency", Default = 50, Min = 0, Max = 100, Rounding = 1, Callback = function(v) ESP_Config.Transparency = v / 100 end})
Tabs.Visuals:CreateSlider("OutlineTransparency", {Title = "Outline Transparency", Default = 0, Min = 0, Max = 100, Rounding = 1, Callback = function(v) ESP_Config.OutlineTransparency = v / 100 end})

Tabs.Misc:CreateParagraph("BossHeader", {Title = "━━ Auto Boss Solvers ━━", Content = "Automatically targets boss weakpoints."})
Tabs.Misc:CreateToggle("AutoPrometheus", {Title = "Auto Prometheus", Default = false}):OnChanged(function() Solvers.Prometheus = Fluent.Options.AutoPrometheus.Value end)
Tabs.Misc:CreateToggle("AutoHermes", {Title = "Auto Hermes", Default = false}):OnChanged(function() Solvers.Hermes = Fluent.Options.AutoHermes.Value end)
Tabs.Misc:CreateToggle("AutoPlatform", {Title = "Auto Platform", Default = false}):OnChanged(function() Solvers.Platform = Fluent.Options.AutoPlatform.Value end)
Tabs.Misc:CreateToggle("AutoTank", {Title = "Auto Tank", Default = false}):OnChanged(function() Solvers.Tank = Fluent.Options.AutoTank.Value end)

Tabs.Misc:CreateToggle("TridentQTE", {Title = "Trident Auto-QTE", Default = false}):OnChanged(function(v)
    Solvers.TridentQTE = v
    if v then
        task.spawn(function()
            local ok, rem = pcall(function()
                return ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("Replication", 5):WaitForChild("Trident_QTE_Task", 5)
            end)
            if not ok or not rem then return end
            
            rem.OnClientEvent:Connect(function(active)
                if not active or not Solvers.TridentQTE then return end
                local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
                for i = 1, 5 do
                    task.wait(0.15)
                    pcall(function()
                        local k = keys[math.random(1,4)]
                        UserInputService:SendKeyEvent(true, k, false, game)
                        task.wait(0.05)
                        UserInputService:SendKeyEvent(false, k, false, game)
                    end)
                end
                task.wait(0.1)
                pcall(function()
                    local successRem = rem.Parent:FindFirstChild("Trident_QTE_Success")
                    if successRem then successRem:FireServer() end
                end)
            end)
        end)
    end
end)

Tabs.Misc:CreateParagraph("MiscHeader", {Title = "━━ Movement & Utility ━━", Content = ""})
Tabs.Misc:CreateToggle("InfJump", {Title = "Infinite Jump", Default = false}):OnChanged(function() InfJumpEnabled = Fluent.Options.InfJump.Value end)
Tabs.Misc:CreateToggle("AntiStun", {Title = "Anti Stun", Default = false}):OnChanged(function() AntiStunEnabled = Fluent.Options.AntiStun.Value end)
Tabs.Misc:CreateSlider("WalkSpeed", {Title = "WalkSpeed", Default = 16, Min = 16, Max = 200, Rounding = 1, Callback = function(v) pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = v end) end})

Tabs.Settings:CreateButton({Title = "Unload Script", Description = "Safely removes everything", Callback = function()
    ScriptAlive = false
    for ent, h in pairs(espCache) do 
        if h and h.Parent then h:Destroy() end 
    end
    espCache = {}
    
    for v, _ in pairs(activeNPCs) do
        if v and v:FindFirstChild("Head") then
            local h = v.Head
            h.Size = Vector3.new(1,1,1)
            h.Transparency = 0
            h.LocalTransparencyModifier = 0
            h.Material = Enum.Material.Plastic
            h.BrickColor = BrickColor.new("Medium stone grey")
            h.Massless = false
            h.CanCollide = true
        end
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            local h = player.Character.Head
            h.Size = Vector3.new(1,1,1)
            h.Transparency = 0
            h.LocalTransparencyModifier = 0
            h.Material = Enum.Material.Plastic
            h.BrickColor = BrickColor.new("Medium stone grey")
            h.Massless = false
            h.CanCollide = true
        end
    end
    
    for _, conn in ipairs(ToolConns) do 
        if conn then conn:Disconnect() end 
    end
    pcall(function() Window:Destroy() end)
    _G.DVNScriptLoaded = false
end})

-- ====================================================================
-- [[ INIT & SAVE SYNC ]]
-- ====================================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

local function SyncSavedSettings()
    WeaponModEnabled = Fluent.Options.WeaponMods.Value
    WeaponSettings.Firerate = Fluent.Options.Firerate.Value
    WeaponSettings.BulletSpeed = Fluent.Options.BulletSpeed and Fluent.Options.BulletSpeed.Value or 500
    Farm.Enabled = Fluent.Options.AutoFarm.Value
    Farm.MaxRange = Fluent.Options.FarmRange.Value
    Farm.GunDelay = Fluent.Options.GunDelay.Value
    Farm.MeleeDelay = Fluent.Options.MeleeDelay.Value
    
    NPC_HB.Enabled = Fluent.Options.NPC_HB.Value
    NPC_HB.Dynamic = Fluent.Options.NPC_Dynamic.Value
    NPC_HB.StaticSize = Fluent.Options.NPC_Static.Value
    NPC_HB.Min = Fluent.Options.NPC_Min and Fluent.Options.NPC_Min.Value or 2
    NPC_HB.Max = Fluent.Options.NPC_Max.Value
    NPC_HB.Near = Fluent.Options.NPC_Near and Fluent.Options.NPC_Near.Value or 2
    NPC_HB.Far = Fluent.Options.NPC_Far and Fluent.Options.NPC_Far.Value or 30
    
    Player_HB.Enabled = Fluent.Options.Player_HB.Value
    Player_HB.Dynamic = Fluent.Options.Player_Dynamic.Value
    Player_HB.StaticSize = Fluent.Options.Player_Static.Value
    Player_HB.Min = Fluent.Options.Player_Min and Fluent.Options.Player_Min.Value or 2
    Player_HB.Max = Fluent.Options.Player_Max.Value
    Player_HB.Near = Fluent.Options.Player_Near and Fluent.Options.Player_Near.Value or 2
    Player_HB.Far = Fluent.Options.Player_Far and Fluent.Options.Player_Far.Value or 30
    
    ESP_Config.Enabled = Fluent.Options.ESP.Value
    ESP_Config.EnemyColor = Fluent.Options.EnemyColor.Value
    ESP_Config.TeamColor = Fluent.Options.TeamColor.Value
    ESP_Config.OutlineColor = Fluent.Options.OutlineColor.Value
    ESP_Config.Transparency = Fluent.Options.Transparency.Value / 100
    ESP_Config.OutlineTransparency = Fluent.Options.OutlineTransparency and (Fluent.Options.OutlineTransparency.Value / 100) or 0
    
    Solvers.Prometheus = Fluent.Options.AutoPrometheus.Value
    Solvers.Hermes = Fluent.Options.AutoHermes.Value
    Solvers.Platform = Fluent.Options.AutoPlatform.Value
    Solvers.Tank = Fluent.Options.AutoTank.Value
    Solvers.TridentQTE = Fluent.Options.TridentQTE.Value
    
    InfJumpEnabled = Fluent.Options.InfJump.Value
    AntiStunEnabled = Fluent.Options.AntiStun.Value
end

pcall(function() SaveManager:LoadAutoloadConfig() end)
SyncSavedSettings()

Window:SelectTab(1)
Fluent:Notify{Title = "By Nanashi Ryu", Content = "Made with Love.", Duration = 5}

if workspace.Camera.Folder.Body then
    workspace.Camera.Folder.Body:Destroy()
end
