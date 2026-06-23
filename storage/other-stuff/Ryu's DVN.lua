--i converted the UiLib to Fluent using AI, don't come crying to me saying it's unethical and lazy.
if getgenv().DVNScriptLoaded then
    pcall(getgenv().UnloadDVNScript)
end
getgenv().DVNScriptLoaded = true
local ScriptAlive = true

local Fluent = loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau", true))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau", true))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau", true))()

local Window = Fluent:CreateWindow{
    Title = "Ryu's Dummies VS Noobs",
    SubTitle = "i love my husband sm",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Rose",
    MinimizeKey = Enum.KeyCode.LeftControl
}

local Tabs = {
    Weapons = Window:CreateTab{ Title = "Weapons", Icon = "rbxassetid://4483362458" },
    Hitbox = Window:CreateTab{ Title = "Hitbox Expander", Icon = "rbxassetid://4483362458" },
    Visuals = Window:CreateTab{ Title = "ESP & Visuals", Icon = "rbxassetid://4483362458" },
    Misc = Window:CreateTab{ Title = "Solvers & Misc", Icon = "rbxassetid://4483362458" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "rbxassetid://4483362458" }
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Camera = Workspace.CurrentCamera

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

local WeaponSettings = { Firerate = 1000, BulletSpeed = 500, Spread = 0, Ammo = 999, Recoil = 0, Kickback = 0 }
local IgnoredWeapons = { ["RPG"] = true, ["Parabolic Hydra"] = true, ["Grenade Launcher"] = true, ["Shockwave Device"] = true, ["Intraplanar Device"] = true, ["Rocket Stormer"] = true }

local Farm = { Enabled = false, MaxRange = 300, GunDelay = 50, MeleeDelay = 150, MultiTarget = false }

local NPC_HB = { Enabled = false, Dynamic = false, StaticSize = 20, Min = 2, Max = 30, Near = 2, Far = 30, Part = "Random", Fallback = false }
local Player_HB = { Enabled = false, Dynamic = false, StaticSize = 20, Min = 2, Max = 30, Near = 2, Far = 30, Part = "Random", Fallback = false }

local ColorTable = {
    ["Bright Red"] = Color3.fromRGB(255, 0, 0), ["Dark Red"] = Color3.fromRGB(139, 0, 0),
    ["Bright Green"] = Color3.fromRGB(0, 255, 0), ["Bright Blue"] = Color3.fromRGB(0, 100, 255),
    ["Light Blue"] = Color3.fromRGB(135, 206, 250), ["Yellow"] = Color3.fromRGB(255, 255, 0),
    ["Purple"] = Color3.fromRGB(128, 0, 128), ["Pink"] = Color3.fromRGB(255, 105, 180),
    ["Orange"] = Color3.fromRGB(255, 165, 0), ["Cyan"] = Color3.fromRGB(0, 255, 255),
    ["White"] = Color3.fromRGB(255, 255, 255), ["Magenta"] = Color3.fromRGB(255, 0, 255)
}
local ESP_Config = { Enabled = false, EnemyColor = "Bright Red", TeamColor = "Bright Blue", OutlineColor = "White", Transparency = 0.5, OutlineTransparency = 0, ThroughWalls = false }

local LandmineESP = { Enabled = false, Color = "Bright Red", Transparency = 0.5, OutlineColor = "White" }
local landmineCache = {}

local Solvers = { Prometheus = false, Hermes = false, Platform = false, Tank = false, TridentQTE = false }
local WeaponModEnabled = false
local InfJumpEnabled = false
local AntiStunEnabled = false
local espCache = {}

local TV_Exploits = {
    SlamSpam = false, SpamDelay = 0.1, RemoveGlide = false,
    RemoveDirectCharge = false, InfiniteFuel = false,
    QKeyHeld = false, LastSlamTime = 0, GlideThrottle = 0
}

local function FindTerminalVelocity()
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and child.Name == "Terminal Velocity" then return child end
    end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") and child.Name == "Terminal Velocity" then return child end
        end
    end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            if child:FindFirstChild("Propell") and child:FindFirstChild("Slam") and child:FindFirstChild("Meter") then
                return child
            end
        end
    end
    return nil
end

local function DoSlamSpam(tool)
    if not tool or not tool.Parent then return end
    local char = LocalPlayer.Character
    if not char or not char.Parent then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local now = tick()
    if now - TV_Exploits.LastSlamTime < TV_Exploits.SpamDelay then return end
    TV_Exploits.LastSlamTime = now
    if TV_Exploits.RemoveGlide then
        local glideRem = tool:FindFirstChild("SetGlideState")
        if glideRem then pcall(function() glideRem:FireServer(false) end) end
    end
    if TV_Exploits.RemoveDirectCharge then
        local dc = root:FindFirstChild("DirectCharge")
        if dc then pcall(function() dc:Destroy() end) end
    end
    pcall(function()
        tool:SetAttribute("SlamCooldown", 0)
        tool:SetAttribute("JetCooldown", 0)
    end)
    local propell = tool:FindFirstChild("Propell")
    if propell then pcall(function() propell:FireServer(nil, false) end) end
    task.wait(0.03)
    local slam = tool:FindFirstChild("Slam")
    if slam then
        pcall(function()
            slam:FireServer((root.CFrame * CFrame.new(0, -2.5, 0)).Position, nil, false)
        end)
    end
end

local EquipExploits = { AerorigFuel = false, InfiniteJetpack = false, UnlimitedPCU = false }

local function FindEquippedToolByName(name)
    local char = LocalPlayer.Character
    if not char or not char.Parent then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and child.Name == name then return child end
    end
    return nil
end

local function ForceFuelMax(tool)
    if not tool or not tool.Parent then return end
    local meter = tool:FindFirstChild("Meter")
    if meter and meter.Value < 100 then pcall(function() meter.Value = 100 end) end
    local fuel = tool:FindFirstChild("Fuel")
    if fuel then
        local maxFuel = fuel:FindFirstChild("Max") or fuel
        if maxFuel:IsA("NumberValue") or maxFuel:IsA("IntValue") then
            if fuel.Value < maxFuel.Value then pcall(function() fuel.Value = maxFuel.Value end) end
        else
            pcall(function() fuel.Value = 100 end)
        end
    end
    local fuelAttr = tool:GetAttribute("Fuel")
    if fuelAttr ~= nil then
        local maxAttr = tool:GetAttribute("MaxFuel") or 100
        if fuelAttr < maxAttr then pcall(function() tool:SetAttribute("Fuel", maxAttr) end) end
    end
end

task.spawn(function()
    while ScriptAlive do
        if EquipExploits.AerorigFuel then
            local aeroTool = FindEquippedToolByName("Aerorig")
            if aeroTool then ForceFuelMax(aeroTool) end
        end
        if EquipExploits.InfiniteJetpack then
            local jpTool = FindEquippedToolByName("Jetpack")
            if jpTool then ForceFuelMax(jpTool) end
        end
        if EquipExploits.UnlimitedPCU then
            local pcuVal = LocalPlayer:GetAttribute("PCU")
            local maxPCU = LocalPlayer:GetAttribute("MaxPCU")
            if pcuVal ~= nil and maxPCU ~= nil then
                if pcuVal < maxPCU then pcall(function() LocalPlayer:SetAttribute("PCU", maxPCU) end) end
            end
            local char = LocalPlayer.Character
            if char and char.Parent then
                local cPcu = char:GetAttribute("PCU")
                local cMax = char:GetAttribute("MaxPCU")
                if cPcu ~= nil and cMax ~= nil then
                    if cPcu < cMax then pcall(function() char:SetAttribute("PCU", cMax) end) end
                end
            end
            local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
            if leaderstats then
                local pcuLs = leaderstats:FindFirstChild("PCU")
                local maxLs = leaderstats:FindFirstChild("MaxPCU")
                if pcuLs and maxLs then
                    if pcuLs.Value < maxLs.Value then pcall(function() pcuLs.Value = maxLs.Value end) end
                end
            end
        end
        task.wait(0.2)
    end
end)

local function FindPromptInContainer(parent, targetName)
    if not parent then return nil end
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == targetName then
            local pp = child:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then return pp end
        end
        if child:IsA("Model") or child:IsA("Folder") then
            local found = FindPromptInContainer(child, targetName)
            if found then return found end
        end
    end
    return nil
end

local function FindMapPrompt(buildingName)
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return nil, "Map folder not found in Workspace" end
    local pp = FindPromptInContainer(mapFolder, buildingName)
    if not pp then return nil, "No ProximityPrompt found inside any '" .. buildingName .. "' in Map" end
    return pp, nil
end

local HasFirePrompt = (fireproximityprompt ~= nil)
if fireproximityprompt then 
    game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
        fireproximityprompt(prompt)
    end)
end

local function FirePrompt(prompt)
    if not prompt then return false, "nil prompt" end
    if not prompt:IsA("ProximityPrompt") then return false, "not a ProximityPrompt" end

    if HasFirePrompt then
        local ok, err = pcall(fireproximityprompt, prompt)
        if ok then return true, nil end
    end

    local origHold = prompt.HoldDuration
    local origLOS = prompt.RequiresLineOfSight
    local origDist = prompt.MaxActivationDistance
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 999
    local ok, err = pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.15)
        prompt:InputHoldEnd()
    end)
    task.wait(0.05)
    prompt.HoldDuration = origHold
    prompt.RequiresLineOfSight = origLOS
    prompt.MaxActivationDistance = origDist
    if ok then return true, nil end
    return false, "manual fallback failed: " .. tostring(err)
end

local UnitsFolder = ReplicatedStorage:WaitForChild("Units", 5) and ReplicatedStorage.Units:WaitForChild("Noobs", 5)
local enemyDict = {}
if UnitsFolder then
    for _, v in ipairs(UnitsFolder:GetChildren()) do
        enemyDict[v.Name] = true
    end
end

local activeNPCs = {}
local function updateNPCCache()
    activeNPCs = {}
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("Head") and enemyDict[v.Name] then
            activeNPCs[v] = true
        end
    end
end
updateNPCCache()

Workspace.ChildAdded:Connect(function(v)
    task.wait()
    if enemyDict[v.Name] then 
        activeNPCs[v] = true
    end
end)

Workspace.ChildRemoved:Connect(function(v) 
    activeNPCs[v] = nil 
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        TV_Exploits.QKeyHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Q then
        TV_Exploits.QKeyHeld = false
    end
end)

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
    
    local targets = {}
    
    for _, ent in ipairs(Workspace:GetChildren()) do
        if ent:IsA("Model") and ent:FindFirstChild("HumanoidRootPart") and ent ~= myChar and not Players:GetPlayerFromCharacter(ent) then 
            local hum = ent:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local targetPart = GetBossTarget(ent)
                if targetPart and targetPart.Parent then
                    local dist = (myRoot.Position - targetPart.Position).Magnitude
                    if dist <= Farm.MaxRange then
                        table.insert(targets, {Part = targetPart, Hum = hum, Dist = dist})
                    end
                end
            end
        end
    end
    
    if #targets == 0 then return end
    
    if not Farm.MultiTarget then
        table.sort(targets, function(a, b) return a.Dist < b.Dist end)
        targets = {targets[1]}
    end
    
    if isGun then
        pcall(function() verifyFire:FireServer() end)
        task.delay(0.03, function()
            if not ScriptAlive then return end
            for _, t in ipairs(targets) do
                if t.Part and t.Part.Parent then
                    if Remotes.bullet then
                        local dir = (t.Part.Position - myHead.Position).Unit
                        pcall(function()
                            Remotes.bullet:FireServer(myHead.Position, dir, 3000, {
                                HighFidelitySegmentSize = 0.5, Acceleration = Vector3.new(0,0,0),
                                RaycastParams = RaycastParams.new{FilterDescendantsInstances = {myChar, Camera}, FilterType = Enum.RaycastFilterType.Exclude},
                                MaxDistance = 3000, AutoIgnoreContainer = true, HighFidelityBehavior = 1
                            })
                        end)
                    end
                    if t.Hum and t.Hum.Parent and t.Hum.Health > 0 then
                        pcall(function() verifyHit:FireServer(t.Hum, t.Part.Position, myHead.Position) end)
                    else
                        pcall(function() verifyHit:FireServer(t.Part, t.Part.Position, myHead.Position) end)
                    end
                end
            end
            if Remotes.sound then pcall(function() Remotes.sound:FireServer("rbxassetid://6731036217", math.random(90,110)/100) end) end
        end)
    else
        for _, t in ipairs(targets) do
            if t.Part and t.Part.Parent then
                if t.Hum and t.Hum.Parent and t.Hum.Health > 0 then
                    pcall(function() verifyHit:FireServer(t.Hum, t.Part.Position, myHead.Position) end)
                else
                    pcall(function() verifyHit:FireServer(t.Part, t.Part.Position, myHead.Position) end)
                end
            end
        end
        if Remotes.sound then pcall(function() Remotes.sound:FireServer("rbxassetid://6241709963", math.random(60,80)/100) end) end
    end
end

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

local function GetOrCreateHighlight(cache, obj, name, alwaysOnTop)
    if not cache[obj] then
        local h = Instance.new("Highlight")
        h.Adornee = obj
        h.Name = name
        if alwaysOnTop then
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
        h.Parent = Workspace
        cache[obj] = h
    end
    return cache[obj]
end

local function ApplyHitbox(part, size)
    if not part or not part:IsA("BasePart") then return end
    if part.Size ~= Vector3.new(size, size, size) then 
        if not part:GetAttribute("HB_OriginalSizeX") then
            part:SetAttribute("HB_OriginalSizeX", part.Size.X)
            part:SetAttribute("HB_OriginalSizeY", part.Size.Y)
            part:SetAttribute("HB_OriginalSizeZ", part.Size.Z)
        end
        part.Size = Vector3.new(size, size, size) 
    end
    if not part:GetAttribute("HB_Modified") then
        part:SetAttribute("HB_OriginalMassless", part.Massless)
        part:SetAttribute("HB_OriginalCanCollide", part.CanCollide)
        part:SetAttribute("HB_OriginalTransparency", part.Transparency)
        part:SetAttribute("HB_OriginalBrickColor", part.BrickColor.Name)
        part:SetAttribute("HB_OriginalMaterial", part.Material.Name)
        part.Massless = true
        part.CanCollide = false
        part.Transparency = 0.6
        part.BrickColor = BrickColor.new("Really red")
        part.Material = Enum.Material.Neon
        part:SetAttribute("HB_Modified", true)
    end
end

local function ResetHitbox(part)
    if part and part:IsA("BasePart") and part:GetAttribute("HB_Modified") then
        local ox = part:GetAttribute("HB_OriginalSizeX")
        local oy = part:GetAttribute("HB_OriginalSizeY")
        local oz = part:GetAttribute("HB_OriginalSizeZ")
        if ox and oy and oz then part.Size = Vector3.new(ox, oy, oz) end
        part.Massless = part:GetAttribute("HB_OriginalMassless")
        part.CanCollide = part:GetAttribute("HB_OriginalCanCollide")
        part.Transparency = part:GetAttribute("HB_OriginalTransparency")
        local bcName = part:GetAttribute("HB_OriginalBrickColor")
        if bcName then part.BrickColor = BrickColor.new(bcName) end
        local matName = part:GetAttribute("HB_OriginalMaterial")
        if matName then part.Material = Enum.Material[matName] end
        part:SetAttribute("HB_Modified", false)
        part:SetAttribute("HB_OriginalSizeX", nil)
        part:SetAttribute("HB_OriginalSizeY", nil)
        part:SetAttribute("HB_OriginalSizeZ", nil)
        part:SetAttribute("HB_OriginalMassless", nil)
        part:SetAttribute("HB_OriginalCanCollide", nil)
        part:SetAttribute("HB_OriginalTransparency", nil)
        part:SetAttribute("HB_OriginalBrickColor", nil)
        part:SetAttribute("HB_OriginalMaterial", nil)
    end
end

local function GetTargetPart(character, partName, useFallback)
    if not character then return nil end
    
    local storedTarget = character:FindFirstChild("HB_StoredTarget")
    if storedTarget and storedTarget.Value and storedTarget.Value.Parent == character then
        return storedTarget.Value
    end

    local target = nil
    
    if partName == "Random" then
        local validParts = {}
        for _, name in ipairs({"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
            local p = character:FindFirstChild(name)
            if p and p:IsA("BasePart") then table.insert(validParts, p) end
        end
        if useFallback then
            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("BasePart") and not table.find(validParts, child) then
                    table.insert(validParts, child)
                end
            end
        end
        if #validParts > 0 then
            target = validParts[math.random(1, #validParts)]
        end
    else
        local p = character:FindFirstChild(partName)
        if p and p:IsA("BasePart") then 
            target = p 
        end
    end

    if not target and useFallback then
        target = character:FindFirstChild("Torso")
        if not target or not target:IsA("BasePart") then
            target = character:FindFirstChild("HumanoidRootPart")
            if not target or not target:IsA("BasePart") then
                local parts = {}
                for _, child in ipairs(character:GetChildren()) do
                    if child:IsA("BasePart") then table.insert(parts, child) end
                end
                if #parts > 0 then
                    target = parts[math.random(1, #parts)]
                end
            end
        end
    end

    if target then
        if not storedTarget then
            storedTarget = Instance.new("ObjectValue")
            storedTarget.Name = "HB_StoredTarget"
            storedTarget.Parent = character
        end
        storedTarget.Value = target
    end

    return target
end

local function ClearStoredTargets()
    for v, _ in pairs(activeNPCs) do
        if v and v.Parent then
            local st = v:FindFirstChild("HB_StoredTarget")
            if st then st:Destroy() end
            for _, child in ipairs(v:GetDescendants()) do
                if child:IsA("BasePart") then ResetHitbox(child) end
            end
            v:SetAttribute("HB_Modified_Active", false)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character.Parent then
            local char = player.Character
            local st = char:FindFirstChild("HB_StoredTarget")
            if st then st:Destroy() end
            for _, child in ipairs(char:GetDescendants()) do
                if child:IsA("BasePart") then ResetHitbox(child) end
            end
            char:SetAttribute("HB_Modified_Active", false)
        end
    end
end

local foundMines = {}
local function ScanForLandmines()
    table.clear(foundMines)
    local landmineFolder = Workspace:FindFirstChild("Landmine")
    if landmineFolder then
        for _, child in ipairs(landmineFolder:GetChildren()) do
            if child:IsA("BasePart") and child.Name == "Hitbox" and child.Parent then
                foundMines[child] = true
            end
        end
    end
    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name == "Landmine" and child ~= landmineFolder then
            if child:IsA("BasePart") then
                foundMines[child] = true
            elseif child:IsA("Model") then
                local hitbox = child:FindFirstChild("Hitbox")
                if hitbox and hitbox:IsA("BasePart") then
                    foundMines[hitbox] = true
                else
                    foundMines[child] = true
                end
            end
        end
    end
    local mapFolder = Workspace:FindFirstChild("Map")
    if mapFolder then
        for _, child in ipairs(mapFolder:GetDescendants()) do
            if child.Name:find("Landmine") then
                if child:IsA("BasePart") then
                    foundMines[child] = true
                elseif child:IsA("Model") then
                    local hitbox = child:FindFirstChild("Hitbox")
                    if hitbox and hitbox:IsA("BasePart") then
                        foundMines[hitbox] = true
                    else
                        foundMines[child] = true
                    end
                end
            end
        end
    end
end

task.spawn(function()
    while ScriptAlive do
        if LandmineESP.Enabled then
            ScanForLandmines()
        end
        task.wait(1)
    end
end)

local espThrottle = 0

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
        if v and v.Parent and v:FindFirstChild("HumanoidRootPart") then
            if NPC_HB.Enabled then
                local targetPart = GetTargetPart(v, NPC_HB.Part, NPC_HB.Fallback)
                if targetPart then
                    local size = NPC_HB.StaticSize
                    if NPC_HB.Dynamic and myRoot then
                        local dist = (targetPart.Position - myRoot.Position).Magnitude
                        local alpha = math.clamp((dist - NPC_HB.Near) / (NPC_HB.Far - NPC_HB.Near), 0, 1)
                        alpha = alpha * alpha * (3 - 2 * alpha)
                        size = NPC_HB.Min + (NPC_HB.Max - NPC_HB.Min) * alpha
                    end
                    ApplyHitbox(targetPart, size)
                    v:SetAttribute("HB_Modified_Active", true)
                end
            else
                if v:GetAttribute("HB_Modified_Active") then
                    for _, child in ipairs(v:GetDescendants()) do
                        if child:IsA("BasePart") then ResetHitbox(child) end
                    end
                    v:SetAttribute("HB_Modified_Active", false)
                end
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local char = player.Character
            if Player_HB.Enabled then
                local targetPart = GetTargetPart(char, Player_HB.Part, Player_HB.Fallback)
                if targetPart then
                    local size = Player_HB.StaticSize
                    if Player_HB.Dynamic and myRoot then
                        local dist = (targetPart.Position - myRoot.Position).Magnitude
                        local alpha = math.clamp((dist - Player_HB.Near) / (Player_HB.Far - Player_HB.Near), 0, 1)
                        alpha = alpha * alpha * (3 - 2 * alpha)
                        size = Player_HB.Min + (Player_HB.Max - Player_HB.Min) * alpha
                    end
                    ApplyHitbox(targetPart, size)
                    char:SetAttribute("HB_Modified_Active", true)
                end
            else
                if char:GetAttribute("HB_Modified_Active") then
                    for _, child in ipairs(char:GetDescendants()) do
                        if child:IsA("BasePart") then ResetHitbox(child) end
                    end
                    char:SetAttribute("HB_Modified_Active", false)
                end
            end
        end
    end

    if ESP_Config.Enabled then
        local enemyCol = ColorTable[ESP_Config.EnemyColor] or Color3.fromRGB(255,0,0)
        local teamCol = ColorTable[ESP_Config.TeamColor] or Color3.fromRGB(0,100,255)
        local outCol = ColorTable[ESP_Config.OutlineColor] or Color3.fromRGB(255,255,255)
        
        espThrottle = espThrottle + dt
        if espThrottle >= 0.5 then
            espThrottle = 0
            for _, ent in ipairs(Workspace:GetChildren()) do
                if ent:IsA("Model") and not espCache[ent] and ent:FindFirstChildOfClass("Humanoid") and ent:FindFirstChild("HumanoidRootPart") and ent ~= LocalPlayer.Character then
                    GetOrCreateHighlight(espCache, ent, "DVN_ESP", ESP_Config.ThroughWalls)
                end
            end
        end

        for ent, h in pairs(espCache) do
            local hum = ent:FindFirstChildOfClass("Humanoid")
            if not ent.Parent or not hum or hum.Health <= 0 then
                if h and h.Parent then h:Destroy() end
                espCache[ent] = nil
            else
                local plr = Players:GetPlayerFromCharacter(ent)
                local targetCol = plr and teamCol or enemyCol
                
                if h.FillColor ~= targetCol then h.FillColor = targetCol end
                if h.OutlineColor ~= outCol then h.OutlineColor = outCol end
                if h.FillTransparency ~= ESP_Config.Transparency then h.FillTransparency = ESP_Config.Transparency end
                if h.OutlineTransparency ~= ESP_Config.OutlineTransparency then h.OutlineTransparency = ESP_Config.OutlineTransparency end
            end
        end
    end

    if LandmineESP.Enabled then
        local fillCol = ColorTable[LandmineESP.Color] or Color3.fromRGB(255, 0, 0)
        local outCol = ColorTable[LandmineESP.OutlineColor] or Color3.fromRGB(255, 255, 255)
        
        for obj, _ in pairs(foundMines) do
            if obj and obj.Parent then
                local h = GetOrCreateHighlight(landmineCache, obj, "DVN_Landmine_ESP", true)
                if h.FillColor ~= fillCol then h.FillColor = fillCol end
                if h.OutlineColor ~= outCol then h.OutlineColor = outCol end
                if h.FillTransparency ~= LandmineESP.Transparency then h.FillTransparency = LandmineESP.Transparency end
            end
        end
    end

    local tvTool = FindTerminalVelocity()
    if tvTool and tvTool.Parent then
        if TV_Exploits.InfiniteFuel then
            local meter = tvTool:FindFirstChild("Meter")
            if meter and meter.Value < 100 then pcall(function() meter.Value = 100 end) end
        end
        if TV_Exploits.RemoveGlide then
            TV_Exploits.GlideThrottle = TV_Exploits.GlideThrottle + dt
            if TV_Exploits.GlideThrottle >= 0.5 then
                TV_Exploits.GlideThrottle = 0
                local glideRem = tvTool:FindFirstChild("SetGlideState")
                if glideRem then pcall(function() glideRem:FireServer(false) end) end
            end
        end
        if TV_Exploits.SlamSpam and TV_Exploits.QKeyHeld then
            DoSlamSpam(tvTool)
        end
    end

    if TV_Exploits.RemoveDirectCharge then
        local char = LocalPlayer.Character
        if char and char.Parent then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local dc = root:FindFirstChild("DirectCharge")
                if dc then pcall(function() dc:Destroy() end) end
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
    end

    if not LandmineESP.Enabled then
        for obj, h in pairs(landmineCache) do
            if h and h.Parent then h:Destroy() end
            landmineCache[obj] = nil
        end
    else
        for obj, h in pairs(landmineCache) do
            if not obj or not obj.Parent or not foundMines[obj] then
                if h and h.Parent then h:Destroy() end
                landmineCache[obj] = nil
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
Tabs.Weapons:CreateToggle("FarmMultiTarget", {Title = "Multi-Target Farm", Default = false}):OnChanged(function() Farm.MultiTarget = Fluent.Options.FarmMultiTarget.Value end)
Tabs.Weapons:CreateSlider("FarmRange", {Title = "Max Kill Range (Studs)", Default = 300, Min = 50, Max = 1000, Rounding = 10, Callback = function(v) Farm.MaxRange = v end})
Tabs.Weapons:CreateSlider("GunDelay", {Title = "Gun Attack Delay (ms)", Default = 50, Min = 10, Max = 1000, Rounding = 10, Callback = function(v) Farm.GunDelay = v end})
Tabs.Weapons:CreateSlider("MeleeDelay", {Title = "Melee Attack Delay (ms)", Default = 150, Min = 50, Max = 2000, Rounding = 10, Callback = function(v) Farm.MeleeDelay = v end})

Tabs.Hitbox:CreateParagraph("HitboxInfo", {Title = "Dynamic Logic", Content = "Shrinks at 2 studs (melee range), expands smoothly to max size for shooting."})

Tabs.Hitbox:CreateToggle("NPC_HB", {Title = "Enable NPC Hitbox", Default = false}):OnChanged(function() NPC_HB.Enabled = Fluent.Options.NPC_HB.Value end)
Tabs.Hitbox:CreateDropdown("NPC_Part", {Title = "NPC Body Part", Values = {"Random", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, Default = 1, Callback = function(v) NPC_HB.Part = v; ClearStoredTargets() end})
Tabs.Hitbox:CreateToggle("NPC_Fallback", {Title = "NPC Use Fallback Hitboxes?", Default = false}):OnChanged(function() NPC_HB.Fallback = Fluent.Options.NPC_Fallback.Value; ClearStoredTargets() end)
Tabs.Hitbox:CreateToggle("NPC_Dynamic", {Title = "NPC Use Dynamic Size?", Default = false}):OnChanged(function() NPC_HB.Dynamic = Fluent.Options.NPC_Dynamic.Value end)
Tabs.Hitbox:CreateSlider("NPC_Static", {Title = "NPC Static Size", Default = 20, Min = 2, Max = 50, Rounding = 1, Callback = function(v) NPC_HB.StaticSize = v end})
Tabs.Hitbox:CreateSlider("NPC_Min", {Title = "NPC Min Size (Close)", Default = 2, Min = 1, Max = 10, Rounding = 1, Callback = function(v) NPC_HB.Min = v end})
Tabs.Hitbox:CreateSlider("NPC_Max", {Title = "NPC Max Size (Far)", Default = 30, Min = 10, Max = 60, Rounding = 1, Callback = function(v) NPC_HB.Max = v end})
Tabs.Hitbox:CreateSlider("NPC_Near", {Title = "NPC Shrink Threshold (Studs)", Default = 2, Min = 1, Max = 20, Rounding = 1, Callback = function(v) NPC_HB.Near = v end})
Tabs.Hitbox:CreateSlider("NPC_Far", {Title = "NPC Max Out Dist (Studs)", Default = 30, Min = 15, Max = 150, Rounding = 1, Callback = function(v) NPC_HB.Far = v end})

Tabs.Hitbox:CreateToggle("Player_HB", {Title = "Enable Player Hitbox", Default = false}):OnChanged(function() Player_HB.Enabled = Fluent.Options.Player_HB.Value end)
Tabs.Hitbox:CreateDropdown("Player_Part", {Title = "Player Body Part", Values = {"Random", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, Default = 1, Callback = function(v) Player_HB.Part = v; ClearStoredTargets() end})
Tabs.Hitbox:CreateToggle("Player_Fallback", {Title = "Player Use Fallback Hitboxes?", Default = false}):OnChanged(function() Player_HB.Fallback = Fluent.Options.Player_Fallback.Value; ClearStoredTargets() end)
Tabs.Hitbox:CreateToggle("Player_Dynamic", {Title = "Player Use Dynamic Size?", Default = false}):OnChanged(function() Player_HB.Dynamic = Fluent.Options.Player_Dynamic.Value end)
Tabs.Hitbox:CreateSlider("Player_Static", {Title = "Player Static Size", Default = 20, Min = 2, Max = 50, Rounding = 1, Callback = function(v) Player_HB.StaticSize = v end})
Tabs.Hitbox:CreateSlider("Player_Min", {Title = "Player Min Size (Close)", Default = 2, Min = 1, Max = 10, Rounding = 1, Callback = function(v) Player_HB.Min = v end})
Tabs.Hitbox:CreateSlider("Player_Max", {Title = "Player Max Size (Far)", Default = 30, Min = 10, Max = 60, Rounding = 1, Callback = function(v) Player_HB.Max = v end})
Tabs.Hitbox:CreateSlider("Player_Near", {Title = "Player Shrink Threshold (Studs)", Default = 2, Min = 1, Max = 20, Rounding = 1, Callback = function(v) Player_HB.Near = v end})
Tabs.Hitbox:CreateSlider("Player_Far", {Title = "Player Max Out Dist (Studs)", Default = 30, Min = 15, Max = 150, Rounding = 1, Callback = function(v) Player_HB.Far = v end})

Tabs.Visuals:CreateParagraph("ESPInfo", {Title = "Player vs NPC Detection", Content = "Teammate Color = Other Players. Enemy Color = NPCs/Bosses."})
Tabs.Visuals:CreateToggle("ESP", {Title = "Enable Highlight ESP", Default = false}):OnChanged(function() ESP_Config.Enabled = Fluent.Options.ESP.Value end)
Tabs.Visuals:CreateToggle("ESPThroughWalls", {Title = "ESP See Through Walls", Default = false}):OnChanged(function() 
    ESP_Config.ThroughWalls = Fluent.Options.ESPThroughWalls.Value
    for _, h in pairs(espCache) do
        if h and h.Parent then
            h.DepthMode = ESP_Config.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        end
    end
end)
Tabs.Visuals:CreateDropdown("EnemyColor", {Title = "Enemy Fill Color (NPCs)", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 1, Callback = function(v) ESP_Config.EnemyColor = v end})
Tabs.Visuals:CreateDropdown("TeamColor", {Title = "Teammate Fill Color (Players)", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 4, Callback = function(v) ESP_Config.TeamColor = v end})
Tabs.Visuals:CreateDropdown("OutlineColor", {Title = "Outline Color", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 11, Callback = function(v) ESP_Config.OutlineColor = v end})
Tabs.Visuals:CreateSlider("Transparency", {Title = "Fill Transparency", Default = 50, Min = 0, Max = 100, Rounding = 1, Callback = function(v) ESP_Config.Transparency = v / 100 end})
Tabs.Visuals:CreateSlider("OutlineTransparency", {Title = "Outline Transparency", Default = 0, Min = 0, Max = 100, Rounding = 1, Callback = function(v) ESP_Config.OutlineTransparency = v / 100 end})

Tabs.Visuals:CreateParagraph("LandmineESPHeader", {Title = "━━ Landmine ESP ━━", Content = "Scans entire workspace for landmines. Visible through walls."})
Tabs.Visuals:CreateToggle("LandmineESP", {Title = "Enable Landmine ESP", Default = false}):OnChanged(function() LandmineESP.Enabled = Fluent.Options.LandmineESP.Value end)
Tabs.Visuals:CreateDropdown("LandmineColor", {Title = "Landmine Fill Color", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 1, Callback = function(v) LandmineESP.Color = v end})
Tabs.Visuals:CreateDropdown("LandmineOutlineColor", {Title = "Landmine Outline Color", Values = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}, Default = 11, Callback = function(v) LandmineESP.OutlineColor = v end})
Tabs.Visuals:CreateSlider("LandmineTransparency", {Title = "Landmine Fill Transparency", Default = 50, Min = 0, Max = 100, Rounding = 1, Callback = function(v) LandmineESP.Transparency = v / 100 end})

Tabs.Misc:CreateParagraph("MapHeader", {Title = "━━ Map Interactions ━━", Content = "Uses " .. (HasFirePrompt and "fireproximityprompt (native)" or "manual fallback") .. " to trigger prompts."})
Tabs.Misc:CreateButton({
    Title = "Open Ammo Fabricator",
    Description = "Recursively finds AmmoFabricator in Map and fires its prompt.",
    Callback = function()
        local pp, err = FindMapPrompt("AmmoFabricator")
        if not pp then return Fluent:Notify{Title = "Ammo Fabricator", Content = err or "Not found", Duration = 5} end
        local ok, fireErr = FirePrompt(pp)
        Fluent:Notify{Title = "Ammo Fabricator", Content = ok and "Prompt fired." or fireErr or "Failed", Duration = ok and 3 or 5}
    end
})
Tabs.Misc:CreateButton({
    Title = "Open Armoury",
    Description = "Recursively finds Armoury in Map and fires its prompt.",
    Callback = function()
        local pp, err = FindMapPrompt("Armoury")
        if not pp then return Fluent:Notify{Title = "Armoury", Content = err or "Not found", Duration = 5} end
        local ok, fireErr = FirePrompt(pp)
        Fluent:Notify{Title = "Armoury", Content = ok and "Prompt fired." or fireErr or "Failed", Duration = ok and 3 or 5}
    end
})
Tabs.Misc:CreateButton({
    Title = "Open Modifier",
    Description = "Recursively finds Modifier in Map and fires its prompt.",
    Callback = function()
        local pp, err = FindMapPrompt("Modifier")
        if not pp then return Fluent:Notify{Title = "Modifier", Content = err or "Not found", Duration = 5} end
        local ok, fireErr = FirePrompt(pp)
        Fluent:Notify{Title = "Modifier", Content = ok and "Prompt fired." or fireErr or "Failed", Duration = ok and 3 or 5}
    end
})

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

Tabs.Misc:CreateParagraph("TVHeader", {Title = "━━ Terminal Velocity ━━", Content = "Hold Q to slam spam. Tool must be equipped."})
Tabs.Misc:CreateToggle("TVSlamSpam", {Title = "Slam Spam", Default = false}):OnChanged(function() TV_Exploits.SlamSpam = Fluent.Options.TVSlamSpam.Value end)
Tabs.Misc:CreateSlider("TVSpamDelay", {Title = "Spam Delay (sec)", Default = 10, Min = 1, Max = 50, Rounding = 1, Callback = function(v) TV_Exploits.SpamDelay = v / 100 end})
Tabs.Misc:CreateToggle("TVRemoveGlide", {Title = "Remove Glide", Default = false}):OnChanged(function() TV_Exploits.RemoveGlide = Fluent.Options.TVRemoveGlide.Value end)
Tabs.Misc:CreateToggle("TVRemoveDC", {Title = "Remove DirectCharge", Default = false}):OnChanged(function() TV_Exploits.RemoveDirectCharge = Fluent.Options.TVRemoveDC.Value end)
Tabs.Misc:CreateToggle("TVInfFuel", {Title = "Infinite Fuel", Default = false}):OnChanged(function() TV_Exploits.InfiniteFuel = Fluent.Options.TVInfFuel.Value end)

Tabs.Misc:CreateParagraph("EquipHeader", {Title = "━━ Equipment Exploits ━━", Content = "Aerorig & Jetpack fuel, building PCU bypass."})
Tabs.Misc:CreateToggle("AerorigFuel", {Title = "Infinite Aerorig Fuel", Default = false}):OnChanged(function() EquipExploits.AerorigFuel = Fluent.Options.AerorigFuel.Value end)
Tabs.Misc:CreateToggle("InfiniteJetpack", {Title = "Infinite Jetpack", Default = false}):OnChanged(function() EquipExploits.InfiniteJetpack = Fluent.Options.InfiniteJetpack.Value end)
Tabs.Misc:CreateToggle("UnlimitedPCU", {Title = "Unlimited PCU", Default = false}):OnChanged(function() EquipExploits.UnlimitedPCU = Fluent.Options.UnlimitedPCU.Value end)

Tabs.Misc:CreateParagraph("MiscHeader", {Title = "━━ Movement & Utility ━━", Content = ""})
Tabs.Misc:CreateToggle("InfJump", {Title = "Infinite Jump", Default = false}):OnChanged(function() InfJumpEnabled = Fluent.Options.InfJump.Value end)
Tabs.Misc:CreateToggle("AntiStun", {Title = "Anti Stun", Default = false}):OnChanged(function() AntiStunEnabled = Fluent.Options.AntiStun.Value end)
Tabs.Misc:CreateSlider("WalkSpeed", {Title = "WalkSpeed", Default = 16, Min = 16, Max = 200, Rounding = 1, Callback = function(v) pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = v end) end})

Tabs.Settings:CreateParagraph("UtilityHeader", {Title = "━━ Utilities ━━", Content = "External tools and server actions."})

Tabs.Settings:CreateButton({
    Title = "Rejoin Server",
    Description = "Teleports you back into the same game server.",
    Callback = function()
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
    end
})

Tabs.Settings:CreateButton({
    Title = "Load Dex++",
    Description = "Opens the Dex++ explorer with decompiler fix.",
    Callback = function()
        task.spawn(function()
            pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/jodta/my-scripts/refs/heads/main/Dex%2B%2B/Decompiler%20Fix.lua"))() end)
        end)
    end
})

Tabs.Settings:CreateButton({Title = "Unload Script", Description = "Safely removes everything", Callback = function()
    ScriptAlive = false
    TV_Exploits.QKeyHeld = false
    for ent, h in pairs(espCache) do if h and h.Parent then h:Destroy() end end
    espCache = {}
    for obj, h in pairs(landmineCache) do if h and h.Parent then h:Destroy() end end
    landmineCache = {}
    for v, _ in pairs(activeNPCs) do
        if v and v.Parent then
            for _, child in ipairs(v:GetDescendants()) do
                if child:IsA("BasePart") then ResetHitbox(child) end
            end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent then
            for _, child in ipairs(player.Character:GetDescendants()) do
                if child:IsA("BasePart") then ResetHitbox(child) end
            end
        end
    end
    for _, conn in ipairs(ToolConns) do if conn then conn:Disconnect() end end
    pcall(function() Window:Destroy() end)
    getgenv().DVNScriptLoaded = false
end})

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
    Farm.MultiTarget = Fluent.Options.FarmMultiTarget and Fluent.Options.FarmMultiTarget.Value or false
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
    NPC_HB.Part = Fluent.Options.NPC_Part.Value
    NPC_HB.Fallback = Fluent.Options.NPC_Fallback and Fluent.Options.NPC_Fallback.Value or false
    
    Player_HB.Enabled = Fluent.Options.Player_HB.Value
    Player_HB.Dynamic = Fluent.Options.Player_Dynamic.Value
    Player_HB.StaticSize = Fluent.Options.Player_Static.Value
    Player_HB.Min = Fluent.Options.Player_Min and Fluent.Options.Player_Min.Value or 2
    Player_HB.Max = Fluent.Options.Player_Max.Value
    Player_HB.Near = Fluent.Options.Player_Near and Fluent.Options.Player_Near.Value or 2
    Player_HB.Far = Fluent.Options.Player_Far and Fluent.Options.Player_Far.Value or 30
    Player_HB.Part = Fluent.Options.Player_Part.Value
    Player_HB.Fallback = Fluent.Options.Player_Fallback and Fluent.Options.Player_Fallback.Value or false
    
    ESP_Config.Enabled = Fluent.Options.ESP.Value
    ESP_Config.ThroughWalls = Fluent.Options.ESPThroughWalls and Fluent.Options.ESPThroughWalls.Value or false
    ESP_Config.EnemyColor = Fluent.Options.EnemyColor.Value
    ESP_Config.TeamColor = Fluent.Options.TeamColor.Value
    ESP_Config.OutlineColor = Fluent.Options.OutlineColor.Value
    ESP_Config.Transparency = Fluent.Options.Transparency.Value / 100
    ESP_Config.OutlineTransparency = Fluent.Options.OutlineTransparency and (Fluent.Options.OutlineTransparency.Value / 100) or 0
    
    LandmineESP.Enabled = Fluent.Options.LandmineESP and Fluent.Options.LandmineESP.Value or false
    LandmineESP.Color = Fluent.Options.LandmineColor and Fluent.Options.LandmineColor.Value or "Bright Red"
    LandmineESP.OutlineColor = Fluent.Options.LandmineOutlineColor and Fluent.Options.LandmineOutlineColor.Value or "White"
    LandmineESP.Transparency = Fluent.Options.LandmineTransparency and (Fluent.Options.LandmineTransparency.Value / 100) or 0.5
    
    Solvers.Prometheus = Fluent.Options.AutoPrometheus.Value
    Solvers.Hermes = Fluent.Options.AutoHermes.Value
    Solvers.Platform = Fluent.Options.AutoPlatform.Value
    Solvers.Tank = Fluent.Options.AutoTank.Value
    Solvers.TridentQTE = Fluent.Options.TridentQTE.Value
    
    TV_Exploits.SlamSpam = Fluent.Options.TVSlamSpam and Fluent.Options.TVSlamSpam.Value or false
    TV_Exploits.SpamDelay = Fluent.Options.TVSpamDelay and (Fluent.Options.TVSpamDelay.Value / 100) or 0.1
    TV_Exploits.RemoveGlide = Fluent.Options.TVRemoveGlide and Fluent.Options.TVRemoveGlide.Value or false
    TV_Exploits.RemoveDirectCharge = Fluent.Options.TVRemoveDC and Fluent.Options.TVRemoveDC.Value or false
    TV_Exploits.InfiniteFuel = Fluent.Options.TVInfFuel and Fluent.Options.TVInfFuel.Value or false
    
    EquipExploits.AerorigFuel = Fluent.Options.AerorigFuel and Fluent.Options.AerorigFuel.Value or false
    EquipExploits.InfiniteJetpack = Fluent.Options.InfiniteJetpack and Fluent.Options.InfiniteJetpack.Value or false
    EquipExploits.UnlimitedPCU = Fluent.Options.UnlimitedPCU and Fluent.Options.UnlimitedPCU.Value or false
    
    InfJumpEnabled = Fluent.Options.InfJump.Value
    AntiStunEnabled = Fluent.Options.AntiStun.Value
end

pcall(function() SaveManager:LoadAutoloadConfig() end)
SyncSavedSettings()

Window:SelectTab(1)
Fluent:Notify{Title = "By Nanashi Ryu", Content = "Made with Love.", Duration = 5}

if workspace.Camera.Folder.Body then
    workspace.Camera:ClearAllChildren()
end
