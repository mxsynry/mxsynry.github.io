--i converted the UiLib to Fluent using AI, don't come crying to me saying it's unethical and lazy.
--[[
    Dummies VS Noobs Hub
    open source, don't reupload or obfuscate ty, or else i'll come and remove your sigma license
]]

if getgenv().DVNScriptLoaded then
    pcall(getgenv().UnloadDVNScript)
end
getgenv().DVNScriptLoaded = true
local ScriptAlive = true

local Connections = {}
local Highlights = {}

local function SafeConnect(signal, handler)
    local conn = signal:Connect(handler)
    table.insert(Connections, conn)
    return conn
end

local function SafeDisconnect(conn)
    if conn and conn.Connected then conn:Disconnect() end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local State = {
    WeaponMods = {
        Enabled = true, Firerate = 250, BulletSpeed = 2000, Spread = 0, Ammo = 999, Recoil = 0, Kickback = 0,
    },
    IgnoredWeapons = {
        ["RPG"] = true, ["Parabolic Hydra"] = true, ["Grenade Launcher"] = true,
        ["Shockwave Device"] = true, ["Intraplanar Device"] = true, ["Rocket Stormer"] = true,
    },
    Farm = { Enabled = false, MaxRange = 1000, GunDelay = 10, MeleeDelay = 50, MultiTarget = true, LastAttack = 0 },
    Hitbox = {
        NPC = { Enabled = true, Dynamic = true, Static = 2, Min = 3, Max = 30, Near = 1, Far = 30, Part = "Torso", Fallback = false },
        Player = { Enabled = true, Dynamic = false, Static = 10, Min = 2, Max = 25, Near = 2, Far = 30, Part = "Head", Fallback = false },
    },
    ESP = { Enabled = true, EnemyColor = "Orange", TeamColor = "Bright Green", OutlineColor = "White", Transparency = 0.7, OutlineTransparency = 1, ThroughWalls = true },
    LandmineDestroyer = { Enabled = true, ScanInterval = 1, DeleteMethod = "Destroy" },
    Solvers = { Prometheus = true, Hermes = true, Platform = true, Tank = true, TridentQTE = true },
    TV = { SlamSpam = true, SpamDelay = 0.11, RemoveGlide = true, RemoveDirectCharge = true, InfiniteFuel = true, QKeyHeld = false, LastSlamTime = 0, GlideThrottle = 0 },
    Equip = { AerorigFuel = true, InfiniteJetpack = true, UnlimitedPCU = true },
    Misc = { InfJump = false, AntiStun = true, WalkSpeed = 40, WalkSpeedEnabled = false },
}

local Colors = {
    ["Bright Red"] = Color3.fromRGB(255, 0, 0), ["Dark Red"] = Color3.fromRGB(139, 0, 0),
    ["Bright Green"] = Color3.fromRGB(0, 255, 0), ["Bright Blue"] = Color3.fromRGB(0, 100, 255),
    ["Light Blue"] = Color3.fromRGB(135, 206, 250), ["Yellow"] = Color3.fromRGB(255, 255, 0),
    ["Purple"] = Color3.fromRGB(128, 0, 128), ["Pink"] = Color3.fromRGB(255, 105, 180),
    ["Orange"] = Color3.fromRGB(255, 165, 0), ["Cyan"] = Color3.fromRGB(0, 255, 255),
    ["White"] = Color3.fromRGB(255, 255, 255), ["Magenta"] = Color3.fromRGB(255, 0, 255),
}

local Remotes = { bullet = nil, sound = nil, trident_qte = nil }

local function SetupRemotes()
    local ok, rem = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Replication", 10)
    end)
    if ok and rem then
        Remotes.bullet = rem:FindFirstChild("ReplicateBullet")
        Remotes.sound = rem:FindFirstChild("ReplicateSound")
        Remotes.trident_qte = rem:FindFirstChild("Trident_QTE_Task")
    end
end

SetupRemotes()
SafeConnect(ReplicatedStorage.ChildAdded, function(c)
    if c.Name == "Remotes" then
        task.wait(0.5)
        SetupRemotes()
    end
end)

task.spawn(function()
    while ScriptAlive do
        if not Remotes.bullet then SetupRemotes() end
        task.wait(30)
    end
end)

local enemyDict = {}
task.spawn(function()
    local ok, units = pcall(function()
        return ReplicatedStorage:WaitForChild("Units", 15):WaitForChild("Noobs", 15)
    end)
    if ok and units then
        for _, v in ipairs(units:GetChildren()) do
            enemyDict[v.Name] = true
        end
    end
    task.wait(5)
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:FindFirstChild("Head") and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(v) then
            enemyDict[v.Name] = true
        end
    end
end)

local activeNPCs = {}

local function refreshNPCCache()
    local fresh = {}
    for _, v in ipairs(Workspace:GetChildren()) do
        local hum = v:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and v:FindFirstChild("HumanoidRootPart") then
            if enemyDict[v.Name] or (v:FindFirstChild("Head") and not Players:GetPlayerFromCharacter(v)) then
                fresh[v] = true
            end
        end
    end
    activeNPCs = fresh
end
refreshNPCCache()

SafeConnect(Workspace.ChildAdded, function(v)
    task.wait(0.1)
    local hum = v:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and v:FindFirstChild("HumanoidRootPart") then
        if enemyDict[v.Name] or (v:FindFirstChild("Head") and not Players:GetPlayerFromCharacter(v)) then
            activeNPCs[v] = true
        end
    end
end)
SafeConnect(Workspace.ChildRemoved, function(v)
    activeNPCs[v] = nil
end)

task.spawn(function()
    while ScriptAlive do
        task.wait(5)
        if ScriptAlive then refreshNPCCache() end
    end
end)

local function GetBossTarget(entity)
    if not entity or not entity.Parent then return nil end

    if entity.Name == "Prometheus" then
        local prom = Workspace:FindFirstChild("Prometheus")
        if prom then
            for _, tn in ipairs({"PropaneTank", "PropaneTank2", "PropaneTank 2"}) do
                local t = prom:FindFirstChild(tn)
                if t and t.Parent then
                    local h = t:FindFirstChild("Hitbox")
                    if h and h.Parent then return h end
                end
            end
        end
        return entity:FindFirstChild("Head")
    elseif entity.Name == "Hermes" then
        for _, ln in ipairs({"Launcher1", "Launcher2", "Launcher3", "Launcher4"}) do
            local l = entity:FindFirstChild(ln)
            if l and l.Parent then
                return l:IsA("BasePart") and l or l:FindFirstChildOfClass("BasePart")
            end
        end
        return entity:FindFirstChild("Hitbox")
    elseif entity.Name == "Platform" then
        for i = 1, 4 do
            local e = entity:FindFirstChild("Emplacement" .. i)
            if e and e.Parent then
                local h = e:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    return e:FindFirstChild("GunBase" .. i) or e:FindFirstChildOfClass("BasePart")
                end
            end
        end
        return entity:FindFirstChild("AmmoStorage")
    elseif entity.Name == "Tank" then
        for _, c in ipairs(entity:GetChildren()) do
            if c.Name == "PropaneTank" and c.Parent then
                return c:FindFirstChild("Hitbox") or c:FindFirstChildOfClass("BasePart")
            end
        end
    elseif entity.Name == "APU" then
        local pilot = entity:FindFirstChild("Pilot")
        if pilot then return pilot:FindFirstChild("Head") end
    end

    return entity:FindFirstChild("Head")
end

local function ApplyHitbox(part, size)
    if not part or not part:IsA("BasePart") then return end
    if part.Size == Vector3.new(size, size, size) then return end
    if not part:GetAttribute("DVNH_Orig") then
        part:SetAttribute("DVNH_Orig", true)
        part:SetAttribute("DVNH_SX", part.Size.X)
        part:SetAttribute("DVNH_SY", part.Size.Y)
        part:SetAttribute("DVNH_SZ", part.Size.Z)
        part:SetAttribute("DVNH_Massless", part.Massless)
        part:SetAttribute("DVNH_CanCollide", part.CanCollide)
        part:SetAttribute("DVNH_Transp", part.Transparency)
        part:SetAttribute("DVNH_BrickColor", part.BrickColor.Name)
        part:SetAttribute("DVNH_Material", part.Material.Name)
    end
    part.Size = Vector3.new(size, size, size)
    part.Massless = true
    part.CanCollide = false
    part.Transparency = 0.6
    part.BrickColor = BrickColor.new("Really red")
    part.Material = Enum.Material.Neon
end

local function ResetHitbox(part)
    if not part or not part:IsA("BasePart") then return end
    if not part:GetAttribute("DVNH_Orig") then return end
    local sx = part:GetAttribute("DVNH_SX")
    local sy = part:GetAttribute("DVNH_SY")
    local sz = part:GetAttribute("DVNH_SZ")
    if sx and sy and sz then part.Size = Vector3.new(sx, sy, sz) end
    part.Massless = part:GetAttribute("DVNH_Massless")
    part.CanCollide = part:GetAttribute("DVNH_CanCollide")
    part.Transparency = part:GetAttribute("DVNH_Transp")
    local bc = part:GetAttribute("DVNH_BrickColor")
    if bc then part.BrickColor = BrickColor.new(bc) end
    local mat = part:GetAttribute("DVNH_Material")
    if mat and Enum.Material[mat] then part.Material = Enum.Material[mat] end
    for _, key in ipairs({"DVNH_Orig","DVNH_SX","DVNH_SY","DVNH_SZ","DVNH_Massless","DVNH_CanCollide","DVNH_Transp","DVNH_BrickColor","DVNH_Material"}) do
        part:SetAttribute(key, nil)
    end
end

local function GetTargetPart(character, partName, useFallback)
    if not character then return nil end

    if partName == "Random" then
        local valid = {}
        for _, name in ipairs({"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
            local p = character:FindFirstChild(name)
            if p and p:IsA("BasePart") then table.insert(valid, p) end
        end
        if useFallback then
            for _, child in ipairs(character:GetChildren()) do
                if child:IsA("BasePart") and not table.find(valid, child) then
                    table.insert(valid, child)
                end
            end
        end
        if #valid > 0 then return valid[math.random(1, #valid)] end
    else
        local p = character:FindFirstChild(partName)
        if p and p:IsA("BasePart") then return p end
    end

    if useFallback then
        return character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
            or character:FindFirstChildOfClass("BasePart")
    end
    return nil
end

local function ClearAllHitboxes()
    for v, _ in pairs(activeNPCs) do
        if v and v.Parent then
            for _, child in ipairs(v:GetDescendants()) do
                if child:IsA("BasePart") then ResetHitbox(child) end
            end
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character.Parent then
            for _, child in ipairs(player.Character:GetDescendants()) do
                if child:IsA("BasePart") then ResetHitbox(child) end
            end
        end
    end
end

local espCache = {}
local espScanTimer = 0
local mineScanTimer = 0

local function GetOrCreateHighlight(cache, obj, name, alwaysOnTop)
    if cache[obj] then return cache[obj] end
    local h = Instance.new("Highlight")
    h.Adornee = obj
    h.Name = name
    h.DepthMode = alwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    h.Parent = Workspace
    cache[obj] = h
    table.insert(Highlights, h)
    return h
end

local function DestroyHighlight(cache, obj)
    if cache[obj] then
        if cache[obj].Parent then cache[obj]:Destroy() end
        cache[obj] = nil
    end
end

local function RemoveTouchInterests(obj)
    if not obj then return end
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TouchInterest") or child:IsA("TouchTransmitter") then
            pcall(function() child:Destroy() end)
        end
    end
    if obj:IsA("TouchInterest") or obj:IsA("TouchTransmitter") then
        pcall(function() obj:Destroy() end)
    end
end

local function DestroyLandmines()
    local mapFolder = Workspace:FindFirstChild("Map")
    for _, child in ipairs(Workspace:GetChildren()) do
        if child.Name == "Landmine" or child.Name == "Hitbox" then
            RemoveTouchInterests(child)
            if child:IsA("BasePart") then
                pcall(function()
                    if State.LandmineDestroyer.DeleteMethod == "Destroy" then
                        child:Destroy()
                    elseif State.LandmineDestroyer.DeleteMethod == "Clear" then
                        child:ClearAllChildren()
                        child:Destroy()
                    else
                        child.Parent = nil
                    end
                end)
            elseif child:IsA("Model") then
                local hb = child:FindFirstChild("Hitbox")
                if hb and hb:IsA("BasePart") then
                    RemoveTouchInterests(hb)
                    pcall(function()
                        if State.LandmineDestroyer.DeleteMethod == "Destroy" then
                            hb:Destroy()
                        elseif State.LandmineDestroyer.DeleteMethod == "Clear" then
                            hb:ClearAllChildren()
                            hb:Destroy()
                        else
                            hb.Parent = nil
                        end
                    end)
                else
                    RemoveTouchInterests(child)
                    pcall(function()
                        if State.LandmineDestroyer.DeleteMethod == "Destroy" then
                            child:Destroy()
                        elseif State.LandmineDestroyer.DeleteMethod == "Clear" then
                            child:ClearAllChildren()
                            child:Destroy()
                        else
                            child.Parent = nil
                        end
                    end)
                end
            end
        end
    end
    if mapFolder then
        for _, child in ipairs(mapFolder:GetDescendants()) do
            if child.Name:find("Landmine") then
                RemoveTouchInterests(child)
                if child:IsA("BasePart") then
                    pcall(function()
                        if State.LandmineDestroyer.DeleteMethod == "Destroy" then
                            child:Destroy()
                        elseif State.LandmineDestroyer.DeleteMethod == "Clear" then
                            child:ClearAllChildren()
                            child:Destroy()
                        else
                            child.Parent = nil
                        end
                    end)
                elseif child:IsA("Model") then
                    local hb = child:FindFirstChild("Hitbox")
                    if hb and hb:IsA("BasePart") then
                        RemoveTouchInterests(hb)
                        pcall(function()
                            if State.LandmineDestroyer.DeleteMethod == "Destroy" then
                                hb:Destroy()
                            elseif State.LandmineDestroyer.DeleteMethod == "Clear" then
                                hb:ClearAllChildren()
                                hb:Destroy()
                            else
                                hb.Parent = nil
                            end
                        end)
                    else
                        pcall(function()
                            if State.LandmineDestroyer.DeleteMethod == "Destroy" then
                                child:Destroy()
                            elseif State.LandmineDestroyer.DeleteMethod == "Clear" then
                                child:ClearAllChildren()
                                child:Destroy()
                            else
                                child.Parent = nil
                            end
                        end)
                    end
                end
            end
        end
    end
end

local function AutoAttack()
    if not State.Farm.Enabled or not ScriptAlive then return end
    local myChar = LocalPlayer.Character
    if not myChar then return end

    local myHead = myChar:FindFirstChild("Head")
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myHead or not myRoot then return end

    local tool = myChar:FindFirstChildOfClass("Tool")
    if not tool then return end

    local verifyHit = tool:FindFirstChild("VerifyHit")
    if not verifyHit then return end

    local verifyFire = tool:FindFirstChild("VerifyFire")
    local isGun = verifyFire ~= nil

    local targets = {}
    for ent, _ in pairs(activeNPCs) do
        if ent and ent.Parent and ent:FindFirstChild("HumanoidRootPart") then
            local hum = ent:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local targetPart = GetBossTarget(ent) or ent:FindFirstChild("Head") or ent:FindFirstChild("HumanoidRootPart")
                if targetPart and targetPart.Parent then
                    local dist = (myRoot.Position - targetPart.Position).Magnitude
                    if dist <= State.Farm.MaxRange then
                        table.insert(targets, { Part = targetPart, Hum = hum, Dist = dist })
                    end
                end
            end
        end
    end

    if #targets == 0 then return end

    if not State.Farm.MultiTarget then
        table.sort(targets, function(a, b) return a.Dist < b.Dist end)
        targets = { targets[1] }
    end

    if isGun then
        pcall(function() verifyFire:FireServer() end)
        task.delay(0.03, function()
            if not ScriptAlive then return end
            for _, t in ipairs(targets) do
                if t.Part and t.Part.Parent and t.Hum and t.Hum.Parent and t.Hum.Health > 0 then
                    if Remotes.bullet then
                        local dir = (t.Part.Position - myHead.Position).Unit
                        pcall(function()
                            Remotes.bullet:FireServer(myHead.Position, dir, 3000, {
                                HighFidelitySegmentSize = 0.5, Acceleration = Vector3.new(0,0,0),
                                RaycastParams = RaycastParams.new {
                                    FilterDescendantsInstances = { myChar, Camera },
                                    FilterType = Enum.RaycastFilterType.Exclude
                                },
                                MaxDistance = 3000, AutoIgnoreContainer = true, HighFidelityBehavior = 1
                            })
                        end)
                    end
                    pcall(function() verifyHit:FireServer(t.Hum, t.Part.Position, myHead.Position) end)
                end
            end
            if Remotes.sound then
                pcall(function() Remotes.sound:FireServer("rbxassetid://6731036217", math.random(90,110)/100) end)
            end
        end)
    else
        for _, t in ipairs(targets) do
            if t.Part and t.Part.Parent and t.Hum and t.Hum.Parent and t.Hum.Health > 0 then
                pcall(function() verifyHit:FireServer(t.Hum, t.Part.Position, myHead.Position) end)
            end
        end
        if Remotes.sound then
            pcall(function() Remotes.sound:FireServer("rbxassetid://6241709963", math.random(60,80)/100) end)
        end
    end
end

local ToolConns = {}

local function ModifyTool(tool)
    if not tool:IsA("Tool") then return end
    if State.IgnoredWeapons[tool.Name] then return end
    if not State.WeaponMods.Enabled then return end
    local S = State.WeaponMods
    local function lock(attr, val)
        if tool:GetAttribute(attr) ~= val then tool:SetAttribute(attr, val) end
    end
    lock("Ammo", S.Ammo)
    lock("Firerate", S.Firerate)
    lock("BulletSpeed", S.BulletSpeed)
    lock("Spread", S.Spread)
    lock("Recoil", S.Recoil)
    lock("Kickback", S.Kickback)
end

local function WatchContainer(container)
    for _, ch in ipairs(container:GetChildren()) do ModifyTool(ch) end
    local conn = container.ChildAdded:Connect(function(ch) task.defer(ModifyTool, ch) end)
    table.insert(ToolConns, conn)
end

local function SetupWeaponWatcher()
    for _, conn in ipairs(ToolConns) do SafeDisconnect(conn) end
    ToolConns = {}
    if not State.WeaponMods.Enabled then return end
    local char = LocalPlayer.Character
    if char then WatchContainer(char) end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then WatchContainer(backpack) end
end

SafeConnect(LocalPlayer.CharacterAdded, function(char)
    task.wait(1)
    SetupWeaponWatcher()
end)

local function FindTerminalVelocity()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and child.Name == "Terminal Velocity" then return child end
        if child:IsA("Tool") and child:FindFirstChild("Propell") and child:FindFirstChild("Slam") and child:FindFirstChild("Meter") then
            return child
        end
    end
    return nil
end

local function DoSlamSpam(tool)
    if not tool or not tool.Parent then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local now = tick()
    if now - State.TV.LastSlamTime < State.TV.SpamDelay then return end
    State.TV.LastSlamTime = now

    if State.TV.RemoveGlide then
        local glideRem = tool:FindFirstChild("SetGlideState")
        if glideRem then pcall(function() glideRem:FireServer(false) end) end
    end
    if State.TV.RemoveDirectCharge then
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
        if State.Equip.AerorigFuel then
            local t = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Aerorig")
            if t and t:IsA("Tool") then ForceFuelMax(t) end
        end
        if State.Equip.InfiniteJetpack then
            local t = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Jetpack")
            if t and t:IsA("Tool") then ForceFuelMax(t) end
        end
        if State.Equip.UnlimitedPCU then
            local maxPCU = LocalPlayer:GetAttribute("MaxPCU")
            if maxPCU then
                if (LocalPlayer:GetAttribute("PCU") or 0) < maxPCU then
                    pcall(function() LocalPlayer:SetAttribute("PCU", maxPCU) end)
                end
            end
            local char = LocalPlayer.Character
            if char then
                local cMax = char:GetAttribute("MaxPCU")
                if cMax and (char:GetAttribute("PCU") or 0) < cMax then
                    pcall(function() char:SetAttribute("PCU", cMax) end)
                end
            end
        end
        task.wait(0.2)
    end
end)

local HasFirePrompt = (fireproximityprompt ~= nil)
if HasFirePrompt then
    SafeConnect(ProximityPromptService.PromptButtonHoldBegan, function(prompt)
        fireproximityprompt(prompt)
    end)
end

local function FirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    if HasFirePrompt then
        local ok = pcall(fireproximityprompt, prompt)
        if ok then return true end
    end
    local origHold = prompt.HoldDuration
    local origLOS = prompt.RequiresLineOfSight
    local origDist = prompt.MaxActivationDistance
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 999
    local ok = pcall(function()
        prompt:InputHoldBegin()
        task.wait(0.15)
        prompt:InputHoldEnd()
    end)
    prompt.HoldDuration = origHold
    prompt.RequiresLineOfSight = origLOS
    prompt.MaxActivationDistance = origDist
    return ok
end

local function FindMapPrompt(buildingName)
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    for _, desc in ipairs(map:GetDescendants()) do
        if desc.Name == buildingName then
            local pp = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
            if pp then return pp end
        end
    end
    return nil
end

-- Q key is now handled by SlamSpamBind keybind (Hold mode), see UI section
SafeConnect(UserInputService.JumpRequest, function()
    if State.Misc.InfJump and ScriptAlive then
        pcall(function() LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping") end)
    end
end)

SafeConnect(RunService.Heartbeat, function(dt)
    if not ScriptAlive then return end

    if State.Misc.AntiStun then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h and h.PlatformStand then h.PlatformStand = false end
    end

    if State.Farm.Enabled then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        local isGun = tool and tool:FindFirstChild("VerifyFire") ~= nil
        local delaySec = (isGun and State.Farm.GunDelay or State.Farm.MeleeDelay) / 1000
        if tick() - State.Farm.LastAttack > delaySec then
            AutoAttack()
            State.Farm.LastAttack = tick()
        end
    end

    if State.Misc.WalkSpeedEnabled and State.Misc.WalkSpeed ~= 16 then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed = State.Misc.WalkSpeed end) end
    end

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for v, _ in pairs(activeNPCs) do
        if v and v.Parent and v:FindFirstChild("HumanoidRootPart") then
            if State.Hitbox.NPC.Enabled then
                local targetPart = GetTargetPart(v, State.Hitbox.NPC.Part, State.Hitbox.NPC.Fallback)
                if targetPart then
                    local size = State.Hitbox.NPC.Static
                    if State.Hitbox.NPC.Dynamic and myRoot then
                        local dist = (targetPart.Position - myRoot.Position).Magnitude
                        local alpha = math.clamp((dist - State.Hitbox.NPC.Near) / (State.Hitbox.NPC.Far - State.Hitbox.NPC.Near), 0, 1)
                        alpha = alpha * alpha * (3 - 2 * alpha)
                        size = State.Hitbox.NPC.Min + (State.Hitbox.NPC.Max - State.Hitbox.NPC.Min) * alpha
                    end
                    ApplyHitbox(targetPart, size)
                end
            end
        end
    end

    if State.Hitbox.Player.Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local targetPart = GetTargetPart(player.Character, State.Hitbox.Player.Part, State.Hitbox.Player.Fallback)
                if targetPart then
                    local size = State.Hitbox.Player.Static
                    if State.Hitbox.Player.Dynamic and myRoot then
                        local dist = (targetPart.Position - myRoot.Position).Magnitude
                        local alpha = math.clamp((dist - State.Hitbox.Player.Near) / (State.Hitbox.Player.Far - State.Hitbox.Player.Near), 0, 1)
                        alpha = alpha * alpha * (3 - 2 * alpha)
                        size = State.Hitbox.Player.Min + (State.Hitbox.Player.Max - State.Hitbox.Player.Min) * alpha
                    end
                    ApplyHitbox(targetPart, size)
                end
            end
        end
    end

    if State.ESP.Enabled then
        espScanTimer = espScanTimer + dt
        if espScanTimer >= 0.3 then
            espScanTimer = 0
            for _, ent in ipairs(Workspace:GetChildren()) do
                if ent:IsA("Model") and ent:FindFirstChildOfClass("Humanoid") and ent:FindFirstChild("HumanoidRootPart") and ent ~= LocalPlayer.Character then
                    if not espCache[ent] then
                        GetOrCreateHighlight(espCache, ent, "DVN_ESP", State.ESP.ThroughWalls)
                    end
                end
            end
        end

        local enemyCol = Colors[State.ESP.EnemyColor] or Color3.fromRGB(255, 0, 0)
        local teamCol = Colors[State.ESP.TeamColor] or Color3.fromRGB(0, 100, 255)
        local outCol = Colors[State.ESP.OutlineColor] or Color3.fromRGB(255, 255, 255)
        for ent, h in pairs(espCache) do
            local hum = ent:FindFirstChildOfClass("Humanoid")
            if not ent.Parent or not hum or hum.Health <= 0 then
                DestroyHighlight(espCache, ent)
            else
                local isPlayer = Players:GetPlayerFromCharacter(ent) ~= nil
                local col = isPlayer and teamCol or enemyCol
                if h.FillColor ~= col then h.FillColor = col end
                if h.OutlineColor ~= outCol then h.OutlineColor = outCol end
                if h.FillTransparency ~= State.ESP.Transparency then h.FillTransparency = State.ESP.Transparency end
                if h.OutlineTransparency ~= State.ESP.OutlineTransparency then h.OutlineTransparency = State.ESP.OutlineTransparency end
            end
        end
    end

    mineScanTimer = mineScanTimer + dt
    if State.LandmineDestroyer.Enabled and mineScanTimer >= State.LandmineDestroyer.ScanInterval then
        mineScanTimer = 0
        DestroyLandmines()
    end

    local tvTool = FindTerminalVelocity()
    if tvTool and tvTool.Parent then
        if State.TV.InfiniteFuel then
            local meter = tvTool:FindFirstChild("Meter")
            if meter and meter.Value < 100 then pcall(function() meter.Value = 100 end) end
        end
        if State.TV.RemoveGlide then
            State.TV.GlideThrottle = State.TV.GlideThrottle + dt
            if State.TV.GlideThrottle >= 0.5 then
                State.TV.GlideThrottle = 0
                local glideRem = tvTool:FindFirstChild("SetGlideState")
                if glideRem then pcall(function() glideRem:FireServer(false) end) end
            end
        end
        if State.TV.SlamSpam and State.TV.QKeyHeld then
            DoSlamSpam(tvTool)
        end
    end

    if State.TV.RemoveDirectCharge then
        local char = LocalPlayer.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local dc = root:FindFirstChild("DirectCharge")
                if dc then pcall(function() dc:Destroy() end) end
            end
        end
    end
end)

task.spawn(function()
    while ScriptAlive do
        task.wait(2)
        if not State.Hitbox.NPC.Enabled then
            for v, _ in pairs(activeNPCs) do
                if v and v.Parent then
                    for _, child in ipairs(v:GetDescendants()) do
                        if child:IsA("BasePart") and child:GetAttribute("DVNH_Orig") then
                            ResetHitbox(child)
                        end
                    end
                end
            end
        end
        if not State.Hitbox.Player.Enabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, child in ipairs(player.Character:GetDescendants()) do
                        if child:IsA("BasePart") and child:GetAttribute("DVNH_Orig") then
                            ResetHitbox(child)
                        end
                    end
                end
            end
        end
        if not State.ESP.Enabled then
            for ent, _ in pairs(espCache) do DestroyHighlight(espCache, ent) end
        end
    end
end)

task.spawn(function()
    local ok, rem = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 10):WaitForChild("Replication", 10):WaitForChild("Trident_QTE_Task", 10)
    end)
    if ok and rem then
        SafeConnect(rem.OnClientEvent, function(active)
            if not active or not State.Solvers.TridentQTE then return end
            local keys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}
            for i = 1, 5 do
                task.wait(0.15)
                pcall(function()
                    local k = keys[math.random(1, 4)]
                    UserInputService:SendKeyEvent(true, k, false, game)
                    task.wait(0.05)
                    UserInputService:SendKeyEvent(false, k, false, game)
                end)
            end
            task.wait(0.1)
            pcall(function()
                local successRem = rem.Parent and rem.Parent:FindFirstChild("Trident_QTE_Success")
                if successRem then successRem:FireServer() end
            end)
        end)
    end
end)

if workspace.Camera and workspace.Camera:FindFirstChild("Folder") and workspace.Camera.Folder:FindFirstChild("Body") then
    pcall(function() workspace.Camera:ClearAllChildren() end)
end

local Fluent = loadstring(game:HttpGet("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau", true))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau", true))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau", true))()

local Window = Fluent:CreateWindow({
    Title = "Ryu's Dummies VS Noobs",
    SubTitle = "i love my husband sm",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Weapons = Window:CreateTab{ Title = "Weapons", Icon = "rbxassetid://4483362458" },
    Hitbox = Window:CreateTab{ Title = "Hitbox Expander", Icon = "rbxassetid://4483362458" },
    Visuals = Window:CreateTab{ Title = "ESP & Visuals", Icon = "rbxassetid://4483362458" },
    Misc = Window:CreateTab{ Title = "Solvers & Misc", Icon = "rbxassetid://4483362458" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "rbxassetid://4483362458" }
}

Tabs.Weapons:CreateToggle("WeaponMods", {Title = "Super Weapons", Default = true}):OnChanged(function() State.WeaponMods.Enabled = Fluent.Options.WeaponMods.Value; SetupWeaponWatcher() end)
Tabs.Weapons:CreateSlider("Firerate", {Title = "Weapon Fire Rate", Default = 250, Min = 0, Max = 5000, Rounding = 10, Callback = function(v) State.WeaponMods.Firerate = v end})
Tabs.Weapons:CreateSlider("BulletSpeed", {Title = "Projectile Velocity", Default = 2000, Min = 0, Max = 2000, Rounding = 10, Callback = function(v) State.WeaponMods.BulletSpeed = v end})

Tabs.Weapons:CreateParagraph("FarmHeader", {Title = "━━ Silent Auto-Farm (NPCs Only) ━━", Content = "Automatically attacks nearest NPC. Hold a gun or melee."})
Tabs.Weapons:CreateToggle("AutoFarm", {Title = "Enable Auto-Farm", Default = false}):OnChanged(function() State.Farm.Enabled = Fluent.Options.AutoFarm.Value end)
Tabs.Weapons:CreateToggle("FarmMultiTarget", {Title = "Multi-Target Farm", Default = true}):OnChanged(function() State.Farm.MultiTarget = Fluent.Options.FarmMultiTarget.Value end)
Tabs.Weapons:CreateSlider("FarmRange", {Title = "Max Kill Range (Studs)", Default = 1000, Min = 50, Max = 1000, Rounding = 10, Callback = function(v) State.Farm.MaxRange = v end})
Tabs.Weapons:CreateSlider("GunDelay", {Title = "Gun Attack Delay (ms)", Default = 10, Min = 10, Max = 1000, Rounding = 10, Callback = function(v) State.Farm.GunDelay = v end})
Tabs.Weapons:CreateSlider("MeleeDelay", {Title = "Melee Attack Delay (ms)", Default = 50, Min = 50, Max = 2000, Rounding = 10, Callback = function(v) State.Farm.MeleeDelay = v end})

Tabs.Hitbox:CreateParagraph("HitboxInfo", {Title = "Dynamic Logic", Content = "Shrinks at 2 studs (melee range), expands smoothly to max size for shooting."})

local function MakeHitboxUI(prefix, tab, cfg, defs)
    tab:CreateToggle(prefix.."_HB", {Title = "Enable "..prefix.." Hitbox", Default = cfg.Enabled}):OnChanged(function() cfg.Enabled = Fluent.Options[prefix.."_HB"].Value end)
    local partIdx = defs and defs.PartIndex or 1
    tab:CreateDropdown(prefix.."_Part", {Title = prefix.." Body Part", Values = {"Random", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, Default = partIdx, Callback = function(v) cfg.Part = v; ClearAllHitboxes() end})
    tab:CreateToggle(prefix.."_Fallback", {Title = prefix.." Use Fallback Hitboxes?", Default = cfg.Fallback}):OnChanged(function() cfg.Fallback = Fluent.Options[prefix.."_Fallback"].Value; ClearAllHitboxes() end)
    tab:CreateToggle(prefix.."_Dynamic", {Title = prefix.." Use Dynamic Size?", Default = cfg.Dynamic}):OnChanged(function() cfg.Dynamic = Fluent.Options[prefix.."_Dynamic"].Value end)
    tab:CreateSlider(prefix.."_Static", {Title = prefix.." Static Size", Default = cfg.Static, Min = 2, Max = 50, Rounding = 1, Callback = function(v) cfg.Static = v end})
    tab:CreateSlider(prefix.."_Min", {Title = prefix.." Min Size (Close)", Default = cfg.Min, Min = 1, Max = 10, Rounding = 1, Callback = function(v) cfg.Min = v end})
    tab:CreateSlider(prefix.."_Max", {Title = prefix.." Max Size (Far)", Default = cfg.Max, Min = 10, Max = 60, Rounding = 1, Callback = function(v) cfg.Max = v end})
    tab:CreateSlider(prefix.."_Near", {Title = prefix.." Shrink Threshold (Studs)", Default = cfg.Near, Min = 1, Max = 20, Rounding = 1, Callback = function(v) cfg.Near = v end})
    tab:CreateSlider(prefix.."_Far", {Title = prefix.." Max Out Dist (Studs)", Default = cfg.Far, Min = 15, Max = 150, Rounding = 1, Callback = function(v) cfg.Far = v end})
end
MakeHitboxUI("NPC", Tabs.Hitbox, State.Hitbox.NPC, {PartIndex = 3})
MakeHitboxUI("Player", Tabs.Hitbox, State.Hitbox.Player, {PartIndex = 2})

local colorNames = {"Bright Red", "Dark Red", "Bright Green", "Bright Blue", "Light Blue", "Yellow", "Purple", "Pink", "Orange", "Cyan", "White", "Magenta"}

Tabs.Visuals:CreateParagraph("ESPInfo", {Title = "Player vs NPC Detection", Content = "Teammate Color = Other Players. Enemy Color = NPCs/Bosses."})
Tabs.Visuals:CreateToggle("ESP", {Title = "Enable Highlight ESP", Default = true}):OnChanged(function() State.ESP.Enabled = Fluent.Options.ESP.Value end)
Tabs.Visuals:CreateToggle("ESPThroughWalls", {Title = "ESP See Through Walls", Default = true}):OnChanged(function()
    State.ESP.ThroughWalls = Fluent.Options.ESPThroughWalls.Value
    for _, h in pairs(espCache) do
        if h and h.Parent then
            h.DepthMode = State.ESP.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        end
    end
end)
Tabs.Visuals:CreateDropdown("EnemyColor", {Title = "Enemy Fill Color (NPCs)", Values = colorNames, Default = 9, Callback = function(v) State.ESP.EnemyColor = v end})
Tabs.Visuals:CreateDropdown("TeamColor", {Title = "Teammate Fill Color (Players)", Values = colorNames, Default = 3, Callback = function(v) State.ESP.TeamColor = v end})
Tabs.Visuals:CreateDropdown("OutlineColor", {Title = "Outline Color", Values = colorNames, Default = 11, Callback = function(v) State.ESP.OutlineColor = v end})
Tabs.Visuals:CreateSlider("Transparency", {Title = "Fill Transparency", Default = 70, Min = 0, Max = 100, Rounding = 1, Callback = function(v) State.ESP.Transparency = v / 100 end})
Tabs.Visuals:CreateSlider("OutlineTransparency", {Title = "Outline Transparency", Default = 100, Min = 0, Max = 100, Rounding = 1, Callback = function(v) State.ESP.OutlineTransparency = v / 100 end})

Tabs.Visuals:CreateParagraph("LandmineDestroyerHeader", {Title = "━━ Anti Landmine ━━", Content = "Automatically destroys landmines and their TouchInterests."})
Tabs.Visuals:CreateToggle("LandmineDestroyer", {Title = "Enable Anti Landmine", Default = true}):OnChanged(function() State.LandmineDestroyer.Enabled = Fluent.Options.LandmineDestroyer.Value end)
Tabs.Visuals:CreateDropdown("LandmineDeleteMethod", {Title = "Delete Method", Values = {"Destroy", "Clear", "Parent"}, Default = 1, Callback = function(v) State.LandmineDestroyer.DeleteMethod = v end})
Tabs.Visuals:CreateSlider("LandmineScanInterval", {Title = "Scan Interval (sec)", Default = 1, Min = 0.5, Max = 10, Rounding = 1, Callback = function(v) State.LandmineDestroyer.ScanInterval = v end})

Tabs.Misc:CreateParagraph("MapHeader", {Title = "━━ Map Interactions ━━", Content = "Uses " .. (HasFirePrompt and "fireproximityprompt (native)" or "manual fallback") .. " to trigger prompts."})
for _, building in ipairs({"AmmoFabricator", "Armoury", "Modifier"}) do
    Tabs.Misc:CreateButton({
        Title = "Open " .. building,
        Description = "Recursively finds " .. building .. " in Map and fires its prompt.",
        Callback = function()
            local pp = FindMapPrompt(building)
            if not pp then return Fluent:Notify{Title = building, Content = "Not found in Map", Duration = 5} end
            local ok = FirePrompt(pp)
            Fluent:Notify{Title = building, Content = ok and "Prompt fired." or "Failed", Duration = ok and 3 or 5}
        end
    })
end

Tabs.Misc:CreateButton({
    Title = "Clear Landmines Now",
    Description = "Instantly destroys all landmines and removes their TouchInterests recursively.",
    Callback = function()
        DestroyLandmines()
        Fluent:Notify{Title = "Landmine Cleaner", Content = "Cleared all landmines.", Duration = 3}
    end
})

Tabs.Misc:CreateParagraph("BossHeader", {Title = "━━ Auto Boss Solvers ━━", Content = "Automatically targets boss weakpoints."})
Tabs.Misc:CreateToggle("AutoPrometheus", {Title = "Auto Prometheus", Default = true}):OnChanged(function() State.Solvers.Prometheus = Fluent.Options.AutoPrometheus.Value end)
Tabs.Misc:CreateToggle("AutoHermes", {Title = "Auto Hermes", Default = true}):OnChanged(function() State.Solvers.Hermes = Fluent.Options.AutoHermes.Value end)
Tabs.Misc:CreateToggle("AutoPlatform", {Title = "Auto Platform", Default = true}):OnChanged(function() State.Solvers.Platform = Fluent.Options.AutoPlatform.Value end)
Tabs.Misc:CreateToggle("AutoTank", {Title = "Auto Tank", Default = true}):OnChanged(function() State.Solvers.Tank = Fluent.Options.AutoTank.Value end)

Tabs.Misc:CreateToggle("TridentQTE", {Title = "Trident Auto-QTE", Default = true}):OnChanged(function(v) State.Solvers.TridentQTE = v end)

Tabs.Misc:CreateParagraph("TVHeader", {Title = "━━ Terminal Velocity ━━", Content = "Hold Q to slam spam. Tool must be equipped."})
Tabs.Misc:CreateToggle("TVSlamSpam", {Title = "Slam Spam", Default = true}):OnChanged(function() State.TV.SlamSpam = Fluent.Options.TVSlamSpam.Value end)
Tabs.Misc:CreateSlider("TVSpamDelay", {Title = "Spam Delay (sec)", Default = 11, Min = 1, Max = 50, Rounding = 1, Callback = function(v) State.TV.SpamDelay = v / 100 end})
Tabs.Misc:CreateToggle("TVRemoveGlide", {Title = "Remove Glide", Default = true}):OnChanged(function() State.TV.RemoveGlide = Fluent.Options.TVRemoveGlide.Value end)
Tabs.Misc:CreateToggle("TVRemoveDC", {Title = "Remove DirectCharge", Default = true}):OnChanged(function() State.TV.RemoveDirectCharge = Fluent.Options.TVRemoveDC.Value end)
Tabs.Misc:CreateToggle("TVInfFuel", {Title = "Infinite Fuel", Default = true}):OnChanged(function() State.TV.InfiniteFuel = Fluent.Options.TVInfFuel.Value end)

Tabs.Misc:CreateParagraph("EquipHeader", {Title = "━━ Equipment Exploits ━━", Content = "Aerorig & Jetpack fuel, building PCU bypass."})
Tabs.Misc:CreateToggle("AerorigFuel", {Title = "Infinite Aerorig Fuel", Default = true}):OnChanged(function() State.Equip.AerorigFuel = Fluent.Options.AerorigFuel.Value end)
Tabs.Misc:CreateToggle("InfiniteJetpack", {Title = "Infinite Jetpack", Default = true}):OnChanged(function() State.Equip.InfiniteJetpack = Fluent.Options.InfiniteJetpack.Value end)
Tabs.Misc:CreateToggle("UnlimitedPCU", {Title = "Unlimited PCU", Default = true}):OnChanged(function() State.Equip.UnlimitedPCU = Fluent.Options.UnlimitedPCU.Value end)

Tabs.Misc:CreateParagraph("MiscHeader", {Title = "━━ Movement & Utility ━━", Content = ""})
Tabs.Misc:CreateToggle("InfJump", {Title = "Infinite Jump", Default = false}):OnChanged(function() State.Misc.InfJump = Fluent.Options.InfJump.Value end)
Tabs.Misc:CreateToggle("AntiStun", {Title = "Anti Stun", Default = true}):OnChanged(function() State.Misc.AntiStun = Fluent.Options.AntiStun.Value end)
Tabs.Misc:CreateToggle("WalkSpeedToggle", {Title = "Custom WalkSpeed", Default = false}):OnChanged(function()
    State.Misc.WalkSpeedEnabled = Fluent.Options.WalkSpeedToggle.Value
    if not State.Misc.WalkSpeedEnabled then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed = 16 end) end
    end
end)
Tabs.Misc:CreateSlider("WalkSpeed", {Title = "WalkSpeed", Default = 40, Min = 16, Max = 200, Rounding = 1, Callback = function(v) State.Misc.WalkSpeed = v end})

Tabs.Misc:CreateParagraph("KeybindsHeader", {Title = "━━ Keybinds ━━", Content = "Click the key button to rebind. Supports Toggle and Hold modes."})
Tabs.Misc:CreateKeybind("AutoFarmBind", {Title = "Auto-Farm", Mode = "Toggle", Default = "LeftAlt", Callback = function(v)
    State.Farm.Enabled = v
    Fluent.Options.AutoFarm:SetValue(v)
end})
Tabs.Misc:CreateKeybind("InfJumpBind", {Title = "Infinite Jump", Mode = "Toggle", Default = "Backspace", Callback = function(v)
    State.Misc.InfJump = v
    Fluent.Options.InfJump:SetValue(v)
end})
Tabs.Misc:CreateKeybind("AntiStunBind", {Title = "Anti Stun", Mode = "Toggle", Default = "K", Callback = function(v)
    State.Misc.AntiStun = v
    Fluent.Options.AntiStun:SetValue(v)
end})
Tabs.Misc:CreateKeybind("WalkSpeedBind", {Title = "Custom WalkSpeed", Mode = "Toggle", Default = "J", Callback = function(v)
    State.Misc.WalkSpeedEnabled = v
    Fluent.Options.WalkSpeedToggle:SetValue(v)
    if not v then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed = 16 end) end
    end
end})
Tabs.Misc:CreateKeybind("ESPBind", {Title = "ESP Toggle", Mode = "Toggle", Default = "B", Callback = function(v)
    State.ESP.Enabled = v
    Fluent.Options.ESP:SetValue(v)
end})
Tabs.Misc:CreateKeybind("NPCHitboxBind", {Title = "NPC Hitbox", Mode = "Toggle", Default = "H", Callback = function(v)
    State.Hitbox.NPC.Enabled = v
    Fluent.Options.NPC_HB:SetValue(v)
end})
Tabs.Misc:CreateKeybind("SlamSpamBind", {Title = "TV Slam Spam", Mode = "Hold", Default = "Q", Callback = function(v)
    State.TV.QKeyHeld = v
end})

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

getgenv().UnloadDVNScript = function()
    ScriptAlive = false
    State.TV.QKeyHeld = false
    -- reset walkspeed back to normal
    if State.Misc.WalkSpeedEnabled then
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h.WalkSpeed = 16 end) end
    end
    for _, conn in ipairs(Connections) do SafeDisconnect(conn) end
    Connections = {}
    for _, conn in ipairs(ToolConns) do SafeDisconnect(conn) end
    ToolConns = {}
    for ent, _ in pairs(espCache) do DestroyHighlight(espCache, ent) end
    for _, h in ipairs(Highlights) do if h.Parent then h:Destroy() end end
    ClearAllHitboxes()
    pcall(function() Window:Destroy() end)
    getgenv().DVNScriptLoaded = false
end

Tabs.Settings:CreateButton({Title = "Unload Script", Description = "Safely removes everything", Callback = getgenv().UnloadDVNScript})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

pcall(function() SaveManager:LoadAutoloadConfig() end)

Window:SelectTab(1)
Fluent:Notify{Title = "By Nanashi Ryu", Content = "Made with Love.", Duration = 5}

if workspace.Camera.Folder and workspace.Camera.Folder.Body then
    workspace.Camera:ClearAllChildren()
end
