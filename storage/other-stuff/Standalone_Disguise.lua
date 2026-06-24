-- == Standalone Vape V4 Disguise Script ==
--959028788 atpaster Fleureavery, 2293855847 imCherry511 mxsynry, 7303329167 VampireRachie extar, 1942779387 kanphurich12345 NJ1, 2814169921 whywhywhywhyjustwhya sharkfallen,10394362390 ultimateaura27 SushiSigma, 8625608859 zxwnvc nuvn, 10747085267 Teto_Shenanigans Teto_Shenanigans, 5729496417 BumblingAnne BumblingAnne, 5365226172 BiGG BIGGAMING144, 1120303861 Petchji Petch_ji

-- ========== CONFIGURATION ==========
local DISGUISE_USER_ID = 8625608859            -- Used only if USE_PRESET = false
local QUIT = false                            -- Set true to revert everything and stop
local MODE = 1                                -- 1=both, 2=identity only, 3=avatar only, 4=gui text only, 5=avatar + gui text
local USE_PRESET = false
local SELECTED_PRESET = "Sh4rkle"             -- or "CAC_Avatar", "Sh4rkle", "don_tachyon", or 1, 2, 3, 4
local FACELESS = true
local HEADLESS = true
local SPOOF_HUMANOID_NAMETAG = true           -- Set true if you want the nametag, false if it breaks the game
local AVATAR_DELAY = 0.5                      -- Seconds to wait after spawning before applying avatar disguise (0 = instant)

local PLAY_INTRO = true                       -- Set false to disable intro completely
local FORCE_REPLAY_INTRO = false              -- Set true to show intro again (even if already shown)

-- ========== VERIFICATION BADGE ==========
local FORCE_VERIFIED = true                   -- Set true to show verified badge for disguised user
local SHOW_BADGE_ON_REVERT = false            -- Set true to also show badge for your original account after revert

--^^ i couldn't get this to work so if somebody ever get hold of this script pls help me, you can search "PlayerImage" on Dex and find the correct location to put badge textures.

-- ========== PATH BLACKLIST ==========
-- BLACKLIST_EXACT_PATHS: Skip replacing properties on these exact instances, but still process their children
local BLACKLIST_EXACT_PATHS = {
    "game.Players.LocalPlayer.PlayerGui.HUD.Battle.Players.mxsynry_alts2.PlrCard.Label",
    "game.Players.LocalPlayer.Character",
    "workspace.Players.mxsynry_alts2",
}

-- BLACKLIST_DESCENDANT_PATHS: Skip these instances AND all their children/descendants entirely
local BLACKLIST_DESCENDANT_PATHS = {
    "workspace.Players",
    "game.CoreGui.DevConsole",
    "game.CoreGui.DevConsoleMaster",
}

-- AVATAR_PRESETS: To make an avatar preset, join Catalog AVatar Creator and use remote spy to log remotes, load an avatar and find a specific remote that have a bunch of appearance descriptions, copy the code and just ask an AI to reformat the code to look like these below for you.
-- ========== PRESETS ==========
local AVATAR_PRESETS = {
    CAC_Avatar = {["HatAccessory"]="17611043485",["MoodAnimation"]=0,["Face"]=0,["ProportionScale"]=0,["ClimbAnimation"]=619509955,["Shirt"]=4526951969,["FaceAccessory"]="14474077611,17536225311",["RightArmColor"]=Color3.fromRGB(248,248,248),["HairAccessory"]="18310540072",["RightArm"]=79712891959327,["Head"]=0,["FallAnimation"]=619511417,["TorsoColor"]=Color3.fromRGB(248,248,248),["DepthScale"]=1,["LeftArm"]=85238692471952,["HeightScale"]=1,["LeftLeg"]=108412038720643,["RightLegColor"]=Color3.fromRGB(248,248,248),["LeftLegColor"]=Color3.fromRGB(248,248,248),["WidthScale"]=1,["BodyTypeScale"]=0,["RunAnimation"]=619512153,["LeftArmColor"]=Color3.fromRGB(248,248,248),["Pants"]=15173496336,["StaticFacialAnimation"]=false,["RightLeg"]=73471950784562,["GraphicTShirt"]=9331793031,["AccessoryRefinements"]={["18310540072"]={["Position"]=Vector3.new(0,0.0579986572265625,0)},["17255867321"]={["Scale"]=Vector3.new(1.13,1.13,1.13),["Rotation"]=Vector3.new(4.89,0,0),["Position"]=Vector3.new(0,-0.22,0.11)}},["JumpAnimation"]=619511974,["FrontAccessory"]="",["Torso"]=48474356,["SwimAnimation"]=619512450,["BackAccessory"]="",["NeckAccessory"]="17255867321",["HeadColor"]=Color3.fromRGB(248,248,248),["IdleAnimation"]=619511648,["WalkAnimation"]=619512767,["HeadScale"]=1,["ShouldersAccessory"]="",["LayeredAccessories"]={},["WaistAccessory"]="7485988593"},
    Sh4rkle = {["HatAccessory"]="15130937205,89310278438015",["MoodAnimation"]=10647852134,["Face"]=0,["ProportionScale"]=0.5,["ClimbAnimation"]=0,["Shirt"]=122227289060476,["FaceAccessory"]="18755661953,93436334523577",["RightArmColor"]=Color3.fromRGB(205,143,106),["HairAccessory"]="13580731569,115651461024258,86697704334862,17332687862,82961371754797",["RightArm"]=0,["Head"]=14488197116,["FallAnimation"]=0,["TorsoColor"]=Color3.fromRGB(205,143,106),["DepthScale"]=0.85,["LeftArm"]=0,["HeightScale"]=0.9,["LeftLeg"]=0,["RightLegColor"]=Color3.fromRGB(205,143,106),["LeftLegColor"]=Color3.fromRGB(205,143,106),["WidthScale"]=0.7,["BodyTypeScale"]=0,["RunAnimation"]=0,["LeftArmColor"]=Color3.fromRGB(205,143,106),["Pants"]=85132175619863,["MakeupItems"]={},["StaticFacialAnimation"]=false,["RightLeg"]=0,["GraphicTShirt"]=0,["AccessoryRefinements"]={},["JumpAnimation"]=0,["WalkAnimation"]=0,["Torso"]=48474356,["SwimAnimation"]=0,["BackAccessory"]="",["NeckAccessory"]="",["HeadColor"]=Color3.fromRGB(205,143,106),["IdleAnimation"]=0,["FrontAccessory"]="",["HeadScale"]=0.95,["ShouldersAccessory"]="",["LayeredAccessories"]={},["WaistAccessory"]="127936022542178"},
    reimu = {["HatAccessory"]="112641415774147,125212675822009,86490835589304",["MoodAnimation"]=0,["Face"]=0,["ProportionScale"]=0,["ClimbAnimation"]=0,["Shirt"]=18981403307,["FaceAccessory"]="123908132457572,13263627763,16820830631",["RightArmColor"]=Color3.fromRGB(248,248,248),["HairAccessory"]="82278523219175",["RightArm"]=79712891959327,["Head"]=0,["FallAnimation"]=0,["TorsoColor"]=Color3.fromRGB(248,248,248),["DepthScale"]=1,["LeftArm"]=85238692471952,["HeightScale"]=1,["LeftLeg"]=108412038720643,["RightLegColor"]=Color3.fromRGB(248,248,248),["LeftLegColor"]=Color3.fromRGB(248,248,248),["WidthScale"]=1,["BodyTypeScale"]=0,["RunAnimation"]=0,["LeftArmColor"]=Color3.fromRGB(248,248,248),["Pants"]=14825545392,["MakeupItems"]={},["StaticFacialAnimation"]=false,["RightLeg"]=73471950784562,["GraphicTShirt"]=0,["AccessoryRefinements"]={["123908132457572"]={["Position"]=Vector3.new(0,-0.038,0)},["16820830631"]={["Position"]=Vector3.new(0,0.049,0)}},["JumpAnimation"]=0,["WalkAnimation"]=0,["Torso"]=48474356,["SwimAnimation"]=0,["BackAccessory"]="",["NeckAccessory"]="77895440821091",["HeadColor"]=Color3.fromRGB(248,248,248),["IdleAnimation"]=0,["FrontAccessory"]="",["HeadScale"]=1,["ShouldersAccessory"]="107811170784889,140584645828066,102455462492142,79563359216751",["LayeredAccessories"]={},["WaistAccessory"]="132465627842809,99218342605390"},
    don_tachyon = {["HatAccessory"]="",["MoodAnimation"]=10647852134,["Face"]=0,["ProportionScale"]=0.5,["ClimbAnimation"]=104741822987331,["Shirt"]=99874075549741,["FaceAccessory"]="124900743243806,138438969829415",["RightArmColor"]=Color3.fromRGB(255,229,213),["HairAccessory"]="107765335190311",["RightArm"]=0,["Head"]=14488197116,["FallAnimation"]=658831500,["TorsoColor"]=Color3.fromRGB(255,229,213),["DepthScale"]=0.9,["LeftArm"]=0,["HeightScale"]=0.95,["LeftLeg"]=0,["RightLegColor"]=Color3.fromRGB(255,229,213),["LeftLegColor"]=Color3.fromRGB(255,229,213),["WidthScale"]=0.75,["BodyTypeScale"]=0,["RunAnimation"]=0,["LeftArmColor"]=Color3.fromRGB(255,229,213),["Pants"]=128356678900185,["MakeupItems"]={},["StaticFacialAnimation"]=false,["RightLeg"]=0,["GraphicTShirt"]=0,["AccessoryRefinements"]={},["JumpAnimation"]=658832070,["WalkAnimation"]=0,["Torso"]=48474356,["SwimAnimation"]=128475661806875,["BackAccessory"]="94628588417130",["NeckAccessory"]="",["HeadColor"]=Color3.fromRGB(255,229,213),["IdleAnimation"]=18538150608,["FrontAccessory"]="120643177202605",["HeadScale"]=1,["ShouldersAccessory"]="",["LayeredAccessories"]={},["WaistAccessory"]="109642007614829"},
}

local function getSelectedPreset()
    if type(SELECTED_PRESET)=="string" then return AVATAR_PRESETS[SELECTED_PRESET] end
    if type(SELECTED_PRESET)=="number" then local i=1 for _,p in pairs(AVATAR_PRESETS) do if i==SELECTED_PRESET then return p end i=i+1 end end
    return nil
end

-- ========== SERVICES ==========
local Players=game:GetService("Players")
local CoreGui=game:GetService("CoreGui")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer

-- ========== PERSISTENT STORAGE ==========
if not getgenv().Ryu_Disguise then
    getgenv().Ryu_Disguise = {
        Original = {
            Name = player.Name,
            DisplayName = player.DisplayName,
            UserId = player.UserId,
            Desc = Players:GetHumanoidDescriptionFromUserId(player.UserId)
        },
        Disguised = nil,
        Active = false
    }
end

if not getgenv().Ryu_Disguise.Original then
    getgenv().Ryu_Disguise.Original = {
        Name = player.Name,
        DisplayName = player.DisplayName,
        UserId = player.UserId,
        Desc = Players:GetHumanoidDescriptionFromUserId(player.UserId)
    }
end

-- ========== GLOBAL LIFECYCLE (prevents stacking across executions) ==========
local STATE = getgenv().Ryu_Disguise

-- Wipe previous execution's hooks before this run creates new ones
if STATE.cleanup then
    pcall(STATE.cleanup)
    STATE.cleanup = nil
end
if STATE.Connections then
    for _, conn in ipairs(STATE.Connections) do
        pcall(function() if conn.Connected then conn:Disconnect() end end)
    end
end

STATE.Connections = {}
STATE.Watched     = setmetatable({}, {__mode = "k"})
STATE.Scanned     = setmetatable({}, {__mode = "k"})
STATE.Pending     = {}

local function track(conn)
    if conn then table.insert(STATE.Connections, conn) end
    return conn
end

local function clearGlobalWatchers()
    STATE.Watched = setmetatable({}, {__mode = "k"})
    STATE.Scanned = setmetatable({}, {__mode = "k"})
    STATE.Pending = {}
end

local ORIG = getgenv().Ryu_Disguise.Original

-- ========== SPOOF SETTINGS ==========
local DISGUISE_NAME = "DisguisedPlayer"
local DISGUISE_DISPLAY = nil
pcall(function()
    local infos = game:GetService("UserService"):GetUserInfosByUserIdsAsync({DISGUISE_USER_ID})
    if infos and #infos > 0 then
        DISGUISE_NAME = infos[1].Username
        DISGUISE_DISPLAY = infos[1].DisplayName
    end
end)
DISGUISE_DISPLAY = DISGUISE_DISPLAY or DISGUISE_NAME

-- Preserve previous disguise data before overwriting (used for switching disguises mid-session)
local PREVIOUS_DISGUISED = getgenv().Ryu_Disguise.Disguised

getgenv().Ryu_Disguise.Disguised = {
    Name = DISGUISE_NAME,
    DisplayName = DISGUISE_DISPLAY,
    UserId = DISGUISE_USER_ID
}

local DISGUISED = getgenv().Ryu_Disguise.Disguised

-- ========== IDENTITY ELEVATION ==========
local function elevateIdentity()
    local LogService = game:GetService("LogService")
    local highest = 2
    for level = 2, 8 do
        pcall(setthreadidentity, level)
        pcall(setidentity, level)
        pcall(function() syn.set_thread_identity(level) end)
        pcall(set_thread_identity, level)
        task.wait(0.05)
        
        local conn
        conn = LogService.MessageOut:Connect(function(msg)
            if msg:find("Current identity is") then
                highest = tonumber(msg:match("%d+")) or highest
                pcall(function() if conn then conn:Disconnect() end end)
            end
        end)
        
        printidentity()
        task.wait(0.1)
        pcall(function() if conn then conn:Disconnect() end end)
        
        print(string.format("🔁 Attempted level %d | Achieved identity: %d", level, highest))
        
        if highest >= 8 then break end
    end
    print("✅ Final elevated identity:", highest)
    return highest
end
local newIdentity = elevateIdentity()

-- ========== PATH BLACKLIST RESOLUTION ==========
local resolvedExact = {}
local resolvedDescendants = {}

local function addExact(inst)
    if inst and typeof(inst) == "Instance" then
        table.insert(resolvedExact, inst)
    end
end

local function addDescendant(inst)
    if inst and typeof(inst) == "Instance" then
        table.insert(resolvedDescendants, inst)
    end
end

-- Resolve string paths to actual instances.
-- Uses GetService for services (immune to renaming) and FindFirstChild for everything else.
local function resolvePath(path)
    local parts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    
    local current = game
    for i, part in ipairs(parts) do
        if part == "game" and i == 1 then
            current = game
        elseif current == game then
            -- Try GetService first (works even if the service was renamed)
            local ok, svc = pcall(function() return game:GetService(part) end)
            if ok and svc then
                current = svc
            elseif part:lower() == "workspace" then
                -- Global 'workspace' always points to the Workspace service
                current = workspace
            elseif current:FindFirstChild(part) then
                current = current:FindFirstChild(part)
            else
                return nil
            end
        elseif current and current:FindFirstChild(part) then
            current = current:FindFirstChild(part)
        else
            return nil
        end
    end
    return current
end

local function initPathBlacklists()
    for _, path in ipairs(BLACKLIST_EXACT_PATHS) do
        local inst = resolvePath(path)
        if inst then addExact(inst) end
    end
    for _, path in ipairs(BLACKLIST_DESCENDANT_PATHS) do
        local inst = resolvePath(path)
        if inst then addDescendant(inst) end
    end
end

-- Dynamic blacklists for things that may not exist at script start or get recreated later
local function initDynamicBlacklists()
    -- 1. Local character (current + future respawns)
    if player.Character then
        addExact(player.Character)
    end
    track(player.CharacterAdded:Connect(function(char)
        addExact(char)
    end))

    -- 2. workspace.Players folder (blocks the entire tree + this user's folder explicitly)
    local function checkWorkspacePlayers()
        local wsPlayers = workspace:FindFirstChild("Players")
        if wsPlayers then
            addDescendant(wsPlayers)
            local myFolder = wsPlayers:FindFirstChild(player.Name)
            if myFolder then
                addExact(myFolder)
            end
        end
    end
    checkWorkspacePlayers()

    -- 3. DevConsole / Developer Console (preserve real error output)
    local function checkDevConsole()
        local devConsoleNames = {"DevConsole", "DevConsoleMaster", "DeveloperConsole", "DevConsoleWindow"}
        for _, name in ipairs(devConsoleNames) do
            local inst = CoreGui:FindFirstChild(name)
            if inst then
                addDescendant(inst)
                print("🛡️ Blacklisted DevConsole:", name)
            end
        end
    end
    checkDevConsole()

    track(CoreGui.ChildAdded:Connect(function(c)
        if c.Name == "DevConsole" or c.Name == "DevConsoleMaster" or c.Name == "DeveloperConsole" or c.Name == "DevConsoleWindow" then
            addDescendant(c)
            print("🛡️ Blacklisted spawned DevConsole:", c.Name)
        end
    end))

    track(workspace.ChildAdded:Connect(function(c)
        if c.Name == "Players" then
            task.wait() -- let children populate
            checkWorkspacePlayers()
            track(c.ChildAdded:Connect(function(child)
                if child.Name == player.Name then
                    addExact(child)
                end
            end))
        end
    end))
end

initPathBlacklists()
initDynamicBlacklists()

local function isPathBlacklisted(instance)
    for _, exact in ipairs(resolvedExact) do
        if instance == exact then return "exact" end
    end
    for _, desc in ipairs(resolvedDescendants) do
        if instance == desc or instance:IsDescendantOf(desc) then return "descendant" end
    end
    return nil
end

-- ========== LEADERBOARD / PLAYERLIST HANDLER ==========
local playerListWatcher = nil

local function stopPlayerListWatcher()
    if playerListWatcher then
        pcall(function() playerListWatcher:Disconnect() end)
        playerListWatcher = nil
    end
end

local function getPlayerListOffsetUndoFrame()
    local success, result = pcall(function()
        return game:GetService("CoreGui")
            :FindFirstChild("PlayerList")
            :FindFirstChild("Children")
            :FindFirstChild("OffsetFrame")
            :FindFirstChild("PlayerScrollList")
            :FindFirstChild("SizeOffsetFrame")
            :FindFirstChild("ScrollingFrameContainer")
            :FindFirstChild("ScrollingFrameClippingFrame")
            :FindFirstChild("ScrollingFrame")
            :FindFirstChild("OffsetUndoFrame")
    end)
    return success and result --or error(tostring(result))
end

local function replacePlayerListEntry(entry, oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
    if not entry or not entry.Name:match("^PlayerEntry_") then return end
    
    -- Check if this entry belongs to us (original or disguise ID)
    local entryId = entry.Name:match("PlayerEntry_(%d+)")
    if not entryId then return end
    entryId = tonumber(entryId)
    
    local isOurEntry = (entryId == oldId) or (entryId == ORIG.UserId) or (entryId == newId)
    if not isOurEntry then return end
    
    local content = entry:FindFirstChild("PlayerEntryContentFrame")
    if not content then return end
    
    local overlay = content:FindFirstChild("OverlayFrame")
    if not overlay then return end
    
    local nameFrame = overlay:FindFirstChild("NameFrame")
    if not nameFrame then return end
    
    -- PlayerIcon (ImageLabel) — where verified badge goes
    local playerIcon = nameFrame:FindFirstChild("PlayerIcon")
    if playerIcon and playerIcon:IsA("ImageLabel") then
        local img = playerIcon.Image or ""
        local changed = false
        if oldId and tostring(oldId) ~= "" and img:find(tostring(oldId), 1, true) then
            img = img:gsub(tostring(oldId), tostring(newId))
            changed = true
        end
        if changed then pcall(function() playerIcon.Image = img end) end
        
        -- Verified badge injection
        if FORCE_VERIFIED and not isRevert then
            local badge = playerIcon:FindFirstChild("RyuBadge") or Instance.new("ImageLabel")
            badge.Name = "RyuBadge"
            badge.BackgroundTransparency = 1
            badge.BorderSizePixel = 0
            badge.Image = "rbxassetid://16224683372"
            badge.ZIndex = 50
            badge.Size = UDim2.new(0, 12, 0, 12)
            badge.Position = UDim2.new(1, -2, 1, -2)
            badge.AnchorPoint = Vector2.new(1, 1)
            badge.Parent = playerIcon
        elseif isRevert then
            local existing = playerIcon:FindFirstChild("RyuBadge")
            if existing then pcall(function() existing:Destroy() end) end
        end
    end
    
    -- PlayerName (TextLabel)
    local playerName = nameFrame:FindFirstChild("PlayerName")
    if playerName and (playerName:IsA("TextLabel") or playerName:IsA("TextButton")) then
        local nameLbl = playerName:FindFirstChild("PlayerName")
        if nameLbl and (nameLbl:IsA("TextLabel") or nameLbl:IsA("TextButton")) then
            local txt = nameLbl.Text or ""
            local changed = false
            if oldDisplay and oldDisplay ~= "" and txt:find(oldDisplay, 1, true) then
                txt = txt:gsub(oldDisplay, newDisplay)
                changed = true
            elseif oldName and oldName ~= "" and txt:find(oldName, 1, true) then
                txt = txt:gsub(oldName, newDisplay or newName)
                changed = true
            end
            if changed then pcall(function() nameLbl.Text = txt end) end
        end
    end
end

local function replacePlayerList(oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
    local offsetUndo = getPlayerListOffsetUndoFrame()
    if not offsetUndo then return end
    
    for _, child in ipairs(offsetUndo:GetDescendants()) do
        if child:IsA("Frame") and child.Name:match("^PlayerEntry_") then
            replacePlayerListEntry(child, oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
        end
    end
end

local function watchPlayerList(oldName, newName, oldDisplay, newDisplay, oldId, newId)
    stopPlayerListWatcher()
    
    -- Immediate replace on current UI
    replacePlayerList(oldName, newName, oldDisplay, newDisplay, oldId, newId, false)
    
    -- Watch entire CoreGui for PlayerList or PlayerEntry spawning
    playerListWatcher = track(CoreGui.DescendantAdded:Connect(function(d)
        if d.Name == "PlayerList" then
            task.wait(0.1)
            replacePlayerList(oldName, newName, oldDisplay, newDisplay, oldId, newId, false)
            return
        end
        
        if d.Name:match("^PlayerEntry_") then
            task.wait(0.05)
            replacePlayerListEntry(d, oldName, newName, oldDisplay, newDisplay, oldId, newId, false)
            return
        end
        
        -- If a child of PlayerEntry gets added (like when entry populates)
        if d.Parent and d.Parent.Name:match("^PlayerEntry_") then
            task.wait(0.05)
            replacePlayerListEntry(d.Parent, oldName, newName, oldDisplay, newDisplay, oldId, newId, false)
            return
        end
    end))
end

-- ========== SETTINGS PEOPLE PAGE HANDLER ==========
local settingsPeopleWatcher = nil

local function stopSettingsPeopleWatcher()
    if settingsPeopleWatcher then
        pcall(function() settingsPeopleWatcher:Disconnect() end)
        settingsPeopleWatcher = nil
    end
end

local function getSettingsPeopleContainer()
    local success, result = pcall(function()
        return game:GetService("CoreGui")
            :FindFirstChild("RobloxGui")
            :FindFirstChild("SettingsClippingShield")
            :FindFirstChild("SettingsShield")
            :FindFirstChild("MenuContainer")
            :FindFirstChild("Page")
            :FindFirstChild("PageViewClipper")
            :FindFirstChild("PageView")
            :FindFirstChild("PageViewInnerFrame")
            :FindFirstChild("peoplepage")
            :FindFirstChild("FocusRoot")
            :FindFirstChild("PeopleReactView")
            :FindFirstChild("People")
    end)
    return success and result or nil
end

-- Replace VirtualizedItem_1 specifically (first item = local player)
local function replaceSettingsPeoplePage(oldName, newName, oldDisplay, newDisplay, oldId, newId)
    local people = getSettingsPeopleContainer()
    if not people then return end
    
    -- Only target VirtualizedItem_1 (local player is always first in the list)
    local item = people:FindFirstChild("VirtualizedItem_1")
    if not item then return end
    
    local card = item:FindFirstChild("Item")
    if not card then return end
    
    local content = card:FindFirstChild("CardContent")
    if not content then return end
    
    -- Name & Handle
    local details = content:FindFirstChild("CardDetails")
    if details then
        local nameContainer = details:FindFirstChild("NameContainer")
        if nameContainer then
            local nameLabel = nameContainer:FindFirstChild("Name")
            if nameLabel and (nameLabel:IsA("TextLabel") or nameLabel:IsA("TextButton")) then
                local txt = nameLabel.Text or ""
                local changed = false
                if oldDisplay and oldDisplay ~= "" and txt:find(oldDisplay, 1, true) then
                    txt = txt:gsub(oldDisplay, newDisplay)
                    changed = true
                elseif oldName and oldName ~= "" and txt:find(oldName, 1, true) then
                    txt = txt:gsub(oldName, newDisplay or newName)
                    changed = true
                end
                if changed then pcall(function() nameLabel.Text = txt end) end
            end
            
            local handle = nameContainer:FindFirstChild("Handle")
            if handle and (handle:IsA("TextLabel") or handle:IsA("TextButton")) then
                local txt = handle.Text or ""
                local changed = false
                -- Preserve @ prefix, replace only the username part
                if oldName and oldName ~= "" and txt:find("@" .. oldName, 1, true) then
                    txt = txt:gsub("@" .. oldName, "@" .. newName)
                    changed = true
                elseif oldDisplay and oldDisplay ~= oldName and oldDisplay ~= "" and txt:find("@" .. oldDisplay, 1, true) then
                    txt = txt:gsub("@" .. oldDisplay, "@" .. newName)
                    changed = true
                end
                if changed then pcall(function() handle.Text = txt end) end
            end
        end
    end
    
    -- Avatar Thumbnail
    local thumbnail = content:FindFirstChild("CardThumbnail")
    if thumbnail then
        local container = thumbnail:FindFirstChild("AvatarThumbnailContainer")
        if container then
            local imgLabel = container:FindFirstChild("AvatarThumbnail")
            if imgLabel and imgLabel:IsA("ImageLabel") then
                local img = imgLabel.Image or ""
                if oldId and tostring(oldId) ~= "" and img:find(tostring(oldId), 1, true) then
                    pcall(function() imgLabel.Image = img:gsub(tostring(oldId), tostring(newId)) end)
                end
            end
        end
    end
end

local function watchSettingsPeoplePage(oldName, newName, oldDisplay, newDisplay, oldId, newId)
    stopSettingsPeopleWatcher()
    
    -- Immediate replace on current UI
    replaceSettingsPeoplePage(oldName, newName, oldDisplay, newDisplay, oldId, newId)
    
    -- Watch entire CoreGui for SettingsShield spawning or VirtualizedItem_1 changing
    settingsPeopleWatcher = track(CoreGui.DescendantAdded:Connect(function(d)
        -- If People container just appeared, do full replace
        if d.Name == "People" and d.Parent and d.Parent.Name == "PeopleReactView" then
            task.wait(0.1)
            replaceSettingsPeoplePage(oldName, newName, oldDisplay, newDisplay, oldId, newId)
            return
        end
        
        -- If VirtualizedItem_1 appears anywhere (or gets recreated), replace it
        if d.Name == "VirtualizedItem_1" then
            task.wait(0.05)
            replaceSettingsPeoplePage(oldName, newName, oldDisplay, newDisplay, oldId, newId)
            return
        end
        
        -- If any child of VirtualizedItem_1 gets added (like when the card populates), replace
        if d.Parent and d.Parent.Name == "VirtualizedItem_1" then
            task.wait(0.05)
            replaceSettingsPeoplePage(oldName, newName, oldDisplay, newDisplay, oldId, newId)
            return
        end
    end))
end

-- ========== UNIFIED REPLACEMENT ENGINE ==========
local scanHeartbeat = nil
local coreGuiWatcher = nil
local playerGuiWatcher = nil
local workspaceWatcher = nil

-- Service name blacklist: only block at ROOT level, don't block recursion inside workspace
local ROOT_BLACKLIST = {
    ["Workspace"] = true, -- I DONT KNOW WHY THIS FIXES BLOCK TALE'S ERROR BUT DISABLE THIS IF YOU WANT NAMETAGS AND BILLBOARD GUI CREDENTIAL SPOOFING TO WORK!!
    ["Players"] = true,
    ["Lighting"] = true,
    ["ReplicatedStorage"] = true,
    ["ReplicatedFirst"] = true,
    ["ServerStorage"] = true,
    ["ServerScriptService"] = true,
    ["StarterGui"] = true,
    ["StarterPack"] = true,
    ["StarterPlayer"] = true,
    ["SoundService"] = true,
    ["Chat"] = true,
    ["LocalizationService"] = true,
    ["HttpService"] = true,
    ["RunService"] = true,
    ["TweenService"] = true,
    ["UserInputService"] = true,
    ["ContextActionService"] = true,
    ["MarketplaceService"] = true,
    ["BadgeService"] = true,
    ["PointsService"] = true,
    ["AnalyticsService"] = true,
    ["SocialService"] = true,
    ["GamePassService"] = true,
    ["GroupService"] = true,
    ["InsertService"] = true,
    ["TeleportService"] = true,
    ["AssetService"] = true,
    ["PhysicsService"] = true,
    ["CollectionService"] = true,
    ["DataStoreService"] = true,
    ["MessagingService"] = true,
    ["MemoryStoreService"] = true,
    ["TextChatService"] = true,
    ["VoiceChatService"] = true,
    ["AvatarChatService"] = true,
    ["ExperienceAuthService"] = true,
    ["SafetyService"] = true,
    ["OpenCloudService"] = true,
}

-- Check if an instance is a root-level service that should be skipped entirely
local function isRootBlacklisted(instance)
    if instance == game then return false end
    if instance.Name == "Workspace" and instance.Parent == game then return true end
    if instance == Players then return true end
    if instance:IsA("Player") then return true end
    if ROOT_BLACKLIST[instance.Name] and instance.Parent == game then return true end
    return false
end

-- Unified watcher: handles ALL property types for ANY gui/text/image instance
local function setupWatchers(root, oldName, newName, oldDisplay, newDisplay, oldId, newId)
    if STATE.Watched[root] then return end
    STATE.Watched[root] = true

    local conn = nil

    if root:IsA("TextLabel") or root:IsA("TextButton") or root:IsA("TextBox") then
        conn = root:GetPropertyChangedSignal("Text"):Connect(function()
            local current = root.Text
            if type(current) ~= "string" then return end
            local changed = false
            if oldName and current:find(oldName, 1, true) then current = current:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and current:find(oldDisplay, 1, true) then current = current:gsub(oldDisplay, newDisplay) changed = true end
            if changed then root.Text = current end
        end)
    elseif root:IsA("ImageLabel") or root:IsA("ImageButton") then
        conn = root:GetPropertyChangedSignal("Image"):Connect(function()
            local current = root.Image
            if type(current) ~= "string" then return end
            local changed = false
            if oldName and current:find(oldName, 1, true) then current = current:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and current:find(oldDisplay, 1, true) then current = current:gsub(oldDisplay, newDisplay) changed = true end
            if oldId and current:find(tostring(oldId), 1, true) then current = current:gsub(tostring(oldId), tostring(newId)) changed = true end
            if changed then root.Image = current end
        end)
    elseif root:IsA("Decal") or root:IsA("Texture") then
        conn = root:GetPropertyChangedSignal("Texture"):Connect(function()
            local current = root.Texture
            if type(current) ~= "string" then return end
            local changed = false
            if oldName and current:find(oldName, 1, true) then current = current:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and current:find(oldDisplay, 1, true) then current = current:gsub(oldDisplay, newDisplay) changed = true end
            if oldId and current:find(tostring(oldId), 1, true) then current = current:gsub(tostring(oldId), tostring(newId)) changed = true end
            if changed then root.Texture = current end
        end)
    elseif root:IsA("MeshPart") then
        conn = root:GetPropertyChangedSignal("TextureID"):Connect(function()
            local current = root.TextureID
            if type(current) ~= "string" then return end
            local changed = false
            if oldName and current:find(oldName, 1, true) then current = current:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and current:find(oldDisplay, 1, true) then current = current:gsub(oldDisplay, newDisplay) changed = true end
            if oldId and current:find(tostring(oldId), 1, true) then current = current:gsub(tostring(oldId), tostring(newId)) changed = true end
            if changed then root.TextureID = current end
        end)
    end

    if conn then track(conn) end
end

local function replaceInInstance(root, oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
    if not root:IsA("Instance") then return end
    if root == game then return end
    if isRootBlacklisted(root) then return end

    -- Cache: don't rescan same instance multiple times per 2 seconds
    local now = tick()
    local lastScan = STATE.Scanned[root]
    if lastScan and (now - lastScan) < 2 then return end
    STATE.Scanned[root] = now

    local pathBlacklist = isPathBlacklisted(root)
    if pathBlacklist == "descendant" then return end
    local isExactBlacklisted = (pathBlacklist == "exact")

    -- Name replacement
    if not isExactBlacklisted then
        local currentName = root.Name
        if currentName == oldName then 
            pcall(function() root.Name = newName end) 
        elseif oldDisplay and oldDisplay ~= oldName and currentName == oldDisplay then 
            pcall(function() root.Name = newDisplay end) 
        end
    end

    -- Class-specific property checks (zero pcall overhead for wrong classes)
    local className = root.ClassName
    local prop, val, changed, newVal

    if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
        prop = "Text"
        val = root.Text
        if val ~= "" then
            newVal = val
            changed = false
            if oldName and newVal:find(oldName, 1, true) then newVal = newVal:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and newVal:find(oldDisplay, 1, true) then newVal = newVal:gsub(oldDisplay, newDisplay) changed = true end
        end
    elseif className == "ImageLabel" or className == "ImageButton" then
        prop = "Image"
        val = root.Image
        if val ~= "" then
            newVal = val
            changed = false
            if oldName and newVal:find(oldName, 1, true) then newVal = newVal:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and newVal:find(oldDisplay, 1, true) then newVal = newVal:gsub(oldDisplay, newDisplay) changed = true end
            if oldId and newVal:find(tostring(oldId), 1, true) then newVal = newVal:gsub(tostring(oldId), tostring(newId)) changed = true end
        end
    elseif className == "Decal" or className == "Texture" then
        prop = "Texture"
        val = root.Texture
        if val ~= "" then
            newVal = val
            changed = false
            if oldName and newVal:find(oldName, 1, true) then newVal = newVal:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and newVal:find(oldDisplay, 1, true) then newVal = newVal:gsub(oldDisplay, newDisplay) changed = true end
            if oldId and newVal:find(tostring(oldId), 1, true) then newVal = newVal:gsub(tostring(oldId), tostring(newId)) changed = true end
        end
    elseif className == "MeshPart" then
        prop = "TextureID"
        val = root.TextureID
        if val ~= "" then
            newVal = val
            changed = false
            if oldName and newVal:find(oldName, 1, true) then newVal = newVal:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and newVal:find(oldDisplay, 1, true) then newVal = newVal:gsub(oldDisplay, newDisplay) changed = true end
            if oldId and newVal:find(tostring(oldId), 1, true) then newVal = newVal:gsub(tostring(oldId), tostring(newId)) changed = true end
        end
    elseif className == "StringValue" then
        prop = "Value"
        val = root.Value
        if val ~= "" then
            newVal = val
            changed = false
            if oldName and newVal:find(oldName, 1, true) then newVal = newVal:gsub(oldName, newName) changed = true end
            if oldDisplay and oldDisplay ~= oldName and newVal:find(oldDisplay, 1, true) then newVal = newVal:gsub(oldDisplay, newDisplay) changed = true end
        end
    end

    if changed and newVal then
        pcall(function() root[prop] = newVal end)
        if not isRevert and not isExactBlacklisted then
            setupWatchers(root, oldName, newName, oldDisplay, newDisplay, oldId, newId)
        end
    end

    local children = root:GetChildren()
    for i = 1, #children do
        replaceInInstance(children[i], oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
    end
end

-- Batch DescendantAdded scans via Heartbeat (stops FPS stutter from rapid spawning)
local function queueScan(instance, oldName, newName, oldDisplay, newDisplay, oldId, newId)
    STATE.Pending[instance] = {oldName, newName, oldDisplay, newDisplay, oldId, newId}
    if scanHeartbeat then return end
    scanHeartbeat = game:GetService("RunService").Heartbeat:Connect(function()
        scanHeartbeat:Disconnect()
        scanHeartbeat = nil
        local batch = STATE.Pending
        STATE.Pending = {}
        for inst, args in pairs(batch) do
            pcall(replaceInInstance, inst, args[1], args[2], args[3], args[4], args[5], args[6], false)
        end
    end)
end

local function replaceGlobally(oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert, skipWatchers)
    if not oldName or not newName then return end

    local settingsShield = nil
    pcall(function()
        settingsShield = CoreGui:FindFirstChild("RobloxGui") and CoreGui.RobloxGui:FindFirstChild("SettingsClippingShield") and CoreGui.RobloxGui.SettingsClippingShield:FindFirstChild("SettingsShield")
    end)

    -- Skip workspace entirely if root-blacklisted (massive performance save)
    local scanWorkspace = not isRootBlacklisted(workspace)

    local containers = {}
    if scanWorkspace then table.insert(containers, workspace) end
    local pg = player:FindFirstChild("PlayerGui")
    if pg then table.insert(containers, pg) end
    table.insert(containers, CoreGui)
    if settingsShield then table.insert(containers, settingsShield) end

    for _, container in ipairs(containers) do
        if container then 
            task.defer(function()
                pcall(replaceInInstance, container, oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
            end)
        end
    end

    if not isRevert and not skipWatchers then
        local robloxGui = CoreGui:FindFirstChild("RobloxGui")
        local modules = robloxGui and robloxGui:FindFirstChild("Modules")
        if modules and not coreGuiWatcher then
            coreGuiWatcher = track(modules.DescendantAdded:Connect(function(descendant)
                queueScan(descendant, oldName, newName, oldDisplay, newDisplay, oldId, newId)
            end))
        end

        if pg and not playerGuiWatcher then
            playerGuiWatcher = track(pg.DescendantAdded:Connect(function(descendant)
                queueScan(descendant, oldName, newName, oldDisplay, newDisplay, oldId, newId)
            end))
        end

        -- Only watch workspace if we actually scan it
        if scanWorkspace and not workspaceWatcher then
            workspaceWatcher = track(workspace.DescendantAdded:Connect(function(descendant)
                queueScan(descendant, oldName, newName, oldDisplay, newDisplay, oldId, newId)
            end))
        end
    end

    pcall(function()
        local players = CoreGui.RobloxGui.SettingsClippingShield.SettingsShield.MenuContainer.Page.PageViewClipper.PageView.PageViewInnerFrame.Players
        for _, child in ipairs(players:GetChildren()) do
            if child:IsA("ImageLabel") then child:Destroy() end
        end
    end)
end

local function clearWatchers()
    clearGlobalWatchers()
    if scanHeartbeat then pcall(function() scanHeartbeat:Disconnect() end) scanHeartbeat = nil end
    if coreGuiWatcher then pcall(function() coreGuiWatcher:Disconnect() end) coreGuiWatcher = nil end
    if playerGuiWatcher then pcall(function() playerGuiWatcher:Disconnect() end) playerGuiWatcher = nil end
    if workspaceWatcher then pcall(function() workspaceWatcher:Disconnect() end) workspaceWatcher = nil end
    if playerListWatcher then pcall(function() playerListWatcher:Disconnect() end) playerListWatcher = nil end
    if settingsPeopleWatcher then pcall(function() settingsPeopleWatcher:Disconnect() end) settingsPeopleWatcher = nil end
end

-- ========== BADGE HANDLER (LEGACY — now integrated into playerList handler) ==========
local badgeData = { active = false, fallbackThread = nil, connections = {} }

local function stopVerifiedBadgeProtection()
    badgeData.active = false
    if badgeData.fallbackThread then pcall(function() task.cancel(badgeData.fallbackThread) end) badgeData.fallbackThread = nil end
    for _, conn in ipairs(badgeData.connections) do pcall(function() if conn.Connected then conn:Disconnect() end end) end
    badgeData.connections = {}
    local pl = CoreGui:FindFirstChild("PlayerList", true)
    if pl then for _, d in ipairs(pl:GetDescendants()) do if d.Name:find("RyuBadge") then pcall(function() d:Destroy() end) end end end
end

-- Kept for backward compatibility but playerList watcher now does the actual badge work
local function startVerifiedBadgeProtection(userId)
    stopVerifiedBadgeProtection()
    badgeData.active = true
    -- The playerList watcher handles badge injection automatically
    -- This function now just ensures the playerList watcher is active
    if not playerListWatcher then
        watchPlayerList(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    end
end

-- ========== AVATAR HELPERS ==========
local function isR15(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
end

local function ensureHumanoidDescription(humanoid)
    if not humanoid then return nil end
    local desc = humanoid:FindFirstChildOfClass("HumanoidDescription")
    if desc then return desc end
    desc = Instance.new("HumanoidDescription")
    desc.Parent = humanoid
    return desc
end

local function stripCharacter(char)
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("BodyColors") or obj:IsA("CharacterMesh") then
            pcall(function() obj:Destroy() end)
        end
        if obj:IsA("Decal") and (obj.Name:lower() == "face" or obj.Name:lower() == "facegraphic") then
            pcall(function() obj:Destroy() end)
        end
    end
    for _, name in ipairs({"LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","UpperTorso","LowerTorso","Torso","LeftArm","RightArm","LeftLeg","RightLeg"}) do
        local part = char:FindFirstChild(name)
        if part and part:IsA("MeshPart") then pcall(function() part.MeshId = "" part.TextureID = "" end) end
    end
end

-- ========== R15 APPEARANCE ==========
local function applyAppearanceR15(character, description, isDisguise)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 5)
    local head = character:WaitForChild("Head", 5)
    if not humanoid or not head then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local originalCFrame = rootPart and rootPart.CFrame

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
            child:Destroy()
        end
    end

    character.Archivable = true
    local tempChar = character:Clone()
    tempChar.Name = isDisguise and "TempDisguiseR15" or "TempRevertR15"
    tempChar.Parent = workspace

    for _, child in tempChar:GetChildren() do
        if child:IsA("Accessory") or child:IsA("ShirtGraphic") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("BodyColors") then
            child:Destroy()
        end
    end

    pcall(function()
        local h = tempChar:FindFirstChildOfClass("Humanoid")
        if h then ensureHumanoidDescription(h) h:ApplyDescription(description) end
    end)

    for _, child in tempChar:GetChildren() do
        if child:IsA("Accessory") then
            local clone = child:Clone()
            if isDisguise then clone:SetAttribute("Disguise", true) end
            for _, weld in clone:GetDescendants() do
                if weld:IsA("Weld") and weld.Part1 then
                    local realPart = character:FindFirstChild(weld.Part1.Name)
                    if realPart then weld.Part1 = realPart end
                end
            end
            clone.Parent = character
        elseif child:IsA("BodyColors") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
            child:Clone().Parent = character
        end
    end

    local srcAnim = tempChar:FindFirstChild("Animate")
    local tgtAnim = character:FindFirstChild("Animate")
    if srcAnim and tgtAnim then
        for _, anim in srcAnim:GetChildren() do
            if anim:IsA("StringValue") or anim:IsA("Animation") then
                local existing = tgtAnim:FindFirstChild(anim.Name)
                if existing then existing:Destroy() end
                anim:Clone().Parent = tgtAnim
            end
        end
    end

    for _, mesh in tempChar:GetChildren() do
        if mesh:IsA("CharacterMesh") then mesh:Clone().Parent = character end
    end

    if FACELESS then
        local realHead = character:FindFirstChild("Head")
        if realHead then
            for _, decal in realHead:GetChildren() do
                if decal:IsA("Decal") and (decal.Name:lower() == "face" or decal.Name:lower() == "facegraphic") then
                    decal.Transparency = 1
                end
            end
            if HEADLESS and realHead:IsA("BasePart") then realHead.Transparency = 1 end
        end
    end

    tempChar:Destroy()
    if rootPart and originalCFrame then TweenService:Create(rootPart, TweenInfo.new(0.3), {CFrame = originalCFrame}):Play() end
    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") and part:CanSetNetworkOwnership() then pcall(function() part:SetNetworkOwner(player) end) end
    end
end

-- ========== R6 APPEARANCE ==========
local function isLayeredClothingAccessory(acc)
    if not acc:IsA("Accessory") then return false end
    local at = acc.AccessoryType
    return at == Enum.AccessoryType.Shirt or at == Enum.AccessoryType.Pants or at == Enum.AccessoryType.Jacket
        or at == Enum.AccessoryType.Sweater or at == Enum.AccessoryType.DressSkirt or at == Enum.AccessoryType.TShirt
end

local function hasWrapLayer(part)
    for _, child in part:GetChildren() do if child:IsA("WrapLayer") then return true end end
    return false
end

local function copyAttributes(source, target)
    if not (source and target and source:IsA("BasePart") and target:IsA("BasePart")) then return end
    for _, prop in ipairs({"Material","Transparency","Reflectance","Color","Anchored","CanCollide","Size","Shape","CastShadow","CollisionGroup","Massless"}) do
        pcall(function() target[prop] = source[prop] end)
    end
    for _, child in source:GetChildren() do
        if not child:IsA("Attachment") then
            local existing = target:FindFirstChild(child.Name)
            if existing and (child:IsA("Decal") or child:IsA("Texture")) then
                pcall(function() existing.Face = child.Face existing.Transparency = child.Transparency existing.Color3 = child.Color3 end)
            elseif not existing then
                if not (child:IsA("WrapLayer") or child.ClassName == "BaseWrap") then
                    pcall(function() child:Clone().Parent = target end)
                end
            end
        end
    end
end

local function getReplaceableCategories(model)
    local cats = {Accessory=false, CharacterMesh=false, BodyColors=false, Shirt=false, Pants=false, ShirtGraphic=false, ShirtLayeredClothing=false, PantsLayeredClothing=false, LayeredClothingAccessory=false, MeshPartHair=false, FaceDecal=false, FaceAccessory=false, FaceControls=false, MeshPartFace=false}
    for _, child in model:GetChildren() do
        if child:IsA("Accessory") then
            cats.Accessory = true
            if isLayeredClothingAccessory(child) then cats.LayeredClothingAccessory = true end
            if child.AccessoryType == Enum.AccessoryType.Face then cats.FaceAccessory = true end
        elseif child:IsA("CharacterMesh") then cats.CharacterMesh = true
        elseif child:IsA("BodyColors") then cats.BodyColors = true
        elseif child:IsA("Shirt") then cats.Shirt = true
        elseif child:IsA("Pants") then cats.Pants = true
        elseif child:IsA("ShirtGraphic") then cats.ShirtGraphic = true
        elseif child:IsA("ShirtLayeredClothing") then cats.ShirtLayeredClothing = true
        elseif child:IsA("PantsLayeredClothing") then cats.PantsLayeredClothing = true
        elseif child:IsA("MeshPart") then
            if child.Name == "Hair" or child.Name:lower():find("hair") then cats.MeshPartHair = true end
            if child.Name:lower():find("face") or hasWrapLayer(child) then cats.MeshPartFace = true end
        elseif child:IsA("FaceControls") then cats.FaceControls = true
        elseif child:IsA("Decal") and child.Name:lower() == "face" then cats.FaceDecal = true end
    end
    local head = model:FindFirstChild("Head")
    if head then
        for _, hc in head:GetChildren() do
            if hc:IsA("Decal") and hc.Name:lower() == "face" then cats.FaceDecal = true
            elseif hc:IsA("FaceControls") then cats.FaceControls = true
            elseif hc:IsA("MeshPart") and (hc.Name:lower():find("face") or hasWrapLayer(hc)) then cats.MeshPartFace = true
            elseif hc:IsA("Accessory") and isLayeredClothingAccessory(hc) then cats.LayeredClothingAccessory = true end
        end
    end
    return cats
end

local function clearHeadTexture(character)
    local head = character:FindFirstChild("Head")
    if not head then return end
    if head:IsA("MeshPart") then pcall(function() head.TextureID = "" end) end
    local mesh = head:FindFirstChildOfClass("SpecialMesh")
    if mesh then pcall(function() mesh.TextureId = "" end) end
    for _, child in head:GetChildren() do
        if child:IsA("Decal") and (child.Name:lower() == "face" or child.Name:lower() == "facegraphic") then child:Destroy() end
    end
end

local function removeAllAccessoriesAndClothing(character)
    local toRemove = {}
    for _, child in character:GetChildren() do
        if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("ShirtLayeredClothing") or child:IsA("PantsLayeredClothing") or child:IsA("BodyColors") then
            table.insert(toRemove, child)
        end
    end
    local head = character:FindFirstChild("Head")
    if head then
        for _, child in head:GetChildren() do if child:IsA("Accessory") then table.insert(toRemove, child) end end
    end
    for _, obj in toRemove do if obj and obj.Parent then obj:Destroy() end end
    clearHeadTexture(character)
end

local function clearNonHeadBodyMeshes(character)
    local bodyParts = {"Torso","LeftArm","RightArm","LeftLeg","RightLeg","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
    for _, partName in ipairs(bodyParts) do
        local part = character:FindFirstChild(partName)
        if part then
            pcall(function()
                if part:IsA("MeshPart") then part.MeshId = "" part.TextureID = ""
                else local m = part:FindFirstChildOfClass("SpecialMesh") if m then m:Destroy() end end
            end)
        end
    end
end

local function deleteAllCharacterMeshes(character)
    for _, child in character:GetChildren() do if child:IsA("CharacterMesh") then child:Destroy() end end
end

local function copyAllBodyMeshes(source, target)
    local bodyParts = {"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
    for _, partName in ipairs(bodyParts) do
        local srcPart = source:FindFirstChild(partName)
        local tgtPart = target:FindFirstChild(partName)
        if srcPart and tgtPart then
            if partName ~= "Head" then
                pcall(function()
                    if tgtPart:IsA("MeshPart") then tgtPart.MeshId = "" tgtPart.TextureID = ""
                    else local m = tgtPart:FindFirstChildOfClass("SpecialMesh") if m then m:Destroy() end end
                end)
            end
            pcall(function()
                if srcPart:IsA("MeshPart") then
                    if partName == "Head" and tgtPart:IsA("MeshPart") then
                        local newHead = Instance.new("Part")
                        newHead.Name = "Head"
                        newHead.Size = srcPart.Size
                        newHead.CFrame = tgtPart.CFrame
                        newHead.Material = srcPart.Material
                        newHead.Color = srcPart.Color
                        newHead.Transparency = srcPart.Transparency
                        newHead.Anchored = false
                        newHead.CanCollide = true
                        newHead.Parent = target
                        local mesh = Instance.new("SpecialMesh")
                        mesh.MeshId = srcPart.MeshId
                        mesh.TextureId = srcPart.TextureID
                        mesh.MeshType = Enum.MeshType.FileMesh
                        mesh.Scale = srcPart.Size
                        mesh.Parent = newHead
                        local oldWeld = tgtPart:FindFirstChildWhichIsA("Weld")
                        if oldWeld then oldWeld:Destroy() end
                        local weld = Instance.new("Weld")
                        local torso = target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso")
                        if torso then weld.Part0 = torso weld.Part1 = newHead weld.C0 = CFrame.new(0, 1.5, 0) weld.Parent = newHead end
                        tgtPart:Destroy()
                        tgtPart = newHead
                    else
                        tgtPart.MeshId = srcPart.MeshId
                        tgtPart.TextureID = srcPart.TextureID
                        tgtPart.Material = srcPart.Material
                        tgtPart.Size = srcPart.Size
                    end
                else
                    local srcMesh = srcPart:FindFirstChildOfClass("SpecialMesh")
                    if srcMesh then
                        local tgtMesh = tgtPart:FindFirstChildOfClass("SpecialMesh")
                        if not tgtMesh then tgtMesh = Instance.new("SpecialMesh") tgtMesh.Parent = tgtPart end
                        tgtMesh.MeshType = srcMesh.MeshType
                        tgtMesh.MeshId = srcMesh.MeshId
                        tgtMesh.TextureId = srcMesh.TextureId
                        tgtMesh.Scale = srcMesh.Scale
                    end
                end
            end)
        end
    end
end

local function applyFaceTransparency(character)
    if not FACELESS then return end
    local head = character:FindFirstChild("Head")
    if head then
        for _, child in head:GetChildren() do
            if child:IsA("Decal") and (child.Name:lower() == "face" or child.Name:lower() == "facegraphic") then child.Transparency = 1 end
        end
        if head:IsA("MeshPart") and HEADLESS then pcall(function() head.Transparency = 1 end)
        else pcall(function() head.Transparency = 0 end) end
    end
end

local function replaceAnimations(source, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    local srcAnim = source:FindFirstChildOfClass("Animator")
    local srcCtrl = source:FindFirstChildOfClass("AnimationController")
    if not (srcAnim or srcCtrl) then return false end
    local curAnim = character:FindFirstChildOfClass("Animator")
    local curCtrl = character:FindFirstChildOfClass("AnimationController")
    if curAnim then curAnim:Destroy() end
    if curCtrl then curCtrl:Destroy() end
    if srcCtrl then srcCtrl:Clone().Parent = character if srcAnim then srcAnim:Clone().Parent = character end return true end
    return false
end

local function copyBodyAttributes(source, target)
    local parts = {"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
    for _, name in ipairs(parts) do
        local src = source:FindFirstChild(name)
        local tgt = target:FindFirstChild(name)
        if src and tgt then copyAttributes(src, tgt) end
    end
end

local function setNetworkOwnership(character)
    for _, part in character:GetDescendants() do if part:IsA("BasePart") and part:CanSetNetworkOwnership() then part:SetNetworkOwner(player) end end
    for _, acc in character:GetChildren() do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") and handle:CanSetNetworkOwnership() then handle:SetNetworkOwner(player) end
        end
    end
end

local function reWeldAccessory(acc, character)
    for _, weld in acc:GetDescendants() do
        if weld:IsA("Weld") and weld.Part1 then
            local target = character:FindFirstChild(weld.Part1.Name)
            if target then weld.Part1 = target end
        end
    end
    local handle = acc:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then handle.Massless = true end
end

local function copyAnimate(source, character)
    local srcAnim = source:FindFirstChild("Animate")
    local tgtAnim = character:FindFirstChild("Animate")
    if srcAnim and tgtAnim then
        for _, child in srcAnim:GetChildren() do
            if child:IsA("StringValue") or child:IsA("Animation") then
                local existing = tgtAnim:FindFirstChild(child.Name)
                if existing then existing:Destroy() end
                child:Clone().Parent = tgtAnim
            end
        end
    end
end

local function applyAppearanceR6(character, description, isDisguise)
    if not character then return end
    local humanoid = character:WaitForChild("Humanoid", 5)
    local head = character:WaitForChild("Head", 5)
    if not humanoid or not head then return end
    task.wait() task.wait()
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local originalCFrame = rootPart and rootPart.CFrame
    task.wait()

    removeAllAccessoriesAndClothing(character)
    deleteAllCharacterMeshes(character)
    clearNonHeadBodyMeshes(character)

    character.Archivable = true
    local tempChar = character:Clone()
    tempChar.Name = isDisguise and "TempDisguise" or "TempRevert"
    tempChar.Parent = workspace

    for _, child in pairs(tempChar:GetChildren()) do
        if child:IsA("Accessory") or child:IsA("ShirtGraphic") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("BodyColors") then child:Destroy() end
    end

    pcall(function()
        local h = tempChar:FindFirstChildOfClass("Humanoid")
        if h then ensureHumanoidDescription(h) h:ApplyDescription(description) end
    end)

    local categories = getReplaceableCategories(tempChar)
    copyBodyAttributes(tempChar, character)
    copyAllBodyMeshes(tempChar, character)

    for _, child in tempChar:GetChildren() do if child:IsA("CharacterMesh") then child:Clone().Parent = character end end
    replaceAnimations(tempChar, character)
    copyAnimate(tempChar, character)

    if categories.Accessory or categories.LayeredClothingAccessory or categories.FaceAccessory then
        for _, child in tempChar:GetChildren() do
            if child:IsA("Accessory") then
                local clone = child:Clone()
                if isDisguise then clone:SetAttribute("Disguise", true) end
                reWeldAccessory(clone, character)
                clone.Parent = character
            end
        end
    end

    for _, child in tempChar:GetChildren() do
        if child:IsA("BodyColors") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("ShirtLayeredClothing") or child:IsA("PantsLayeredClothing") then
            local clone = child:Clone()
            if isDisguise then clone:SetAttribute("Disguise", true) end
            clone.Parent = character
        end
    end

    local realFace = character:FindFirstChild("face", true)
    local tempFace = tempChar:FindFirstChild("face", true)
    if realFace and tempFace then realFace.Parent = nil tempFace.Parent = character.Head end

    applyFaceTransparency(character)

    pcall(function()
        local hd = ensureHumanoidDescription(humanoid)
        hd:SetEmotes(description:GetEmotes())
        hd:SetEquippedEmotes(description:GetEquippedEmotes())
    end)

    tempChar:Destroy()
    setNetworkOwnership(character)
    if rootPart and originalCFrame then TweenService:Create(rootPart, TweenInfo.new(0.3), {CFrame = originalCFrame}):Play() end
end

-- ========== DISPATCHER ==========
local function applyAppearance(character, description, isDisguise)
    if isR15(character) then applyAppearanceR15(character, description, isDisguise)
    else applyAppearanceR6(character, description, isDisguise) end
end

-- ========== DISGUISE / REVERT WRAPPERS ==========
local function applyAvatarDisguise(character)
    if AVATAR_DELAY > 0 then
        task.wait(AVATAR_DELAY)
    end
    if not character or not character.Parent then return end
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then task.wait(1) return applyAvatarDisguise(character) end
    local desc
    if USE_PRESET then
        local preset = getSelectedPreset()
        if not preset then desc = Players:GetHumanoidDescriptionFromUserId(DISGUISE_USER_ID)
        else desc = Instance.new("HumanoidDescription") for k, v in pairs(preset) do pcall(function() desc[k] = v end) end end
    else desc = Players:GetHumanoidDescriptionFromUserId(DISGUISE_USER_ID) end

    local hd = ensureHumanoidDescription(humanoid)
    pcall(function() desc.HeightScale = hd.HeightScale end)
    applyAppearance(character, desc, true)
end

local function revertAvatar()
    local character = player.Character
    if not character then return end
    local originalDesc = ORIG.Desc
    if not originalDesc then warn("No original description stored") return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local hd = ensureHumanoidDescription(humanoid)
        pcall(function() originalDesc.HeightScale = hd.HeightScale end)
    end
    applyAppearance(character, originalDesc, false)
    task.wait(0.2)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") and child:GetAttribute("Disguise") then child:Destroy() end
    end
end

-- ========== REVERT IDENTITY ==========
local function revertIdentity()
    clearWatchers()
    stopSettingsPeopleWatcher()
    stopPlayerListWatcher()
    
    pcall(function() player.Name = ORIG.Name end)
    pcall(function() player.DisplayName = ORIG.DisplayName end)
    pcall(function() player.UserId = ORIG.UserId end)
    if player.Character then
        local h = player.Character:FindFirstChild("Humanoid")
        if h then pcall(function() h.DisplayName = ORIG.DisplayName end) end
    end
    
    local lastDisguised = getgenv().Ryu_Disguise.Disguised
    if lastDisguised then
        replaceGlobally(
            lastDisguised.Name, ORIG.Name, 
            lastDisguised.DisplayName, ORIG.DisplayName, 
            lastDisguised.UserId, ORIG.UserId, 
            true
        )
    else
        replaceGlobally(DISGUISE_NAME, ORIG.Name, DISGUISE_DISPLAY, ORIG.DisplayName, DISGUISE_USER_ID, ORIG.UserId, true)
    end
end

-- ========== DISGUISE SWITCH HELPER ==========
local function switchDisguiseCleanup()
    if getgenv().Ryu_Disguise.Active and PREVIOUS_DISGUISED then
        if PREVIOUS_DISGUISED.UserId ~= DISGUISE_USER_ID then
            print("🔄 Switching disguise: cleaning previous traces...")
            -- One-time replacement of previous disguise -> new disguise (no watchers)
            replaceGlobally(PREVIOUS_DISGUISED.Name, DISGUISE_NAME, PREVIOUS_DISGUISED.DisplayName, DISGUISE_DISPLAY, PREVIOUS_DISGUISED.UserId, DISGUISE_USER_ID, false, true)
            -- One-time Settings page cleanup from previous -> new
            replaceSettingsPeoplePage(PREVIOUS_DISGUISED.Name, DISGUISE_NAME, PREVIOUS_DISGUISED.DisplayName, DISGUISE_DISPLAY, PREVIOUS_DISGUISED.UserId, DISGUISE_USER_ID)
            -- One-time PlayerList cleanup from previous -> new
            replacePlayerList(PREVIOUS_DISGUISED.Name, DISGUISE_NAME, PREVIOUS_DISGUISED.DisplayName, DISGUISE_DISPLAY, PREVIOUS_DISGUISED.UserId, DISGUISE_USER_ID, false)
        end
    end
end

-- ========== MAIN EXECUTION ==========
if QUIT then
    if getgenv().Ryu_Disguise and getgenv().Ryu_Disguise.cleanup then
        pcall(getgenv().Ryu_Disguise.cleanup)
        getgenv().Ryu_Disguise.cleanup = nil
    end
    print("🔄 Reverting all changes...")
    revertIdentity()
    revertAvatar()
    clearWatchers()
    stopSettingsPeopleWatcher()
    stopPlayerListWatcher()
    stopVerifiedBadgeProtection()
    getgenv().Ryu_Disguise.Active = false
    getgenv().Ryu_Disguise.Disguised = nil
    print("✅ Revert complete.")
    return
end

-- MODE 4 & 5: GUI text replacement + nametag spoof (no game.Players changes)
if MODE == 4 or MODE == 5 then
    print("✅ GUI text replacement active")
    switchDisguiseCleanup()
    replaceGlobally(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    watchSettingsPeoplePage(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    watchPlayerList(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    if FORCE_VERIFIED then startVerifiedBadgeProtection(DISGUISE_USER_ID) end
    
    local function onGuiChar(char)
        local h = char:WaitForChild("Humanoid")
            if h and SPOOF_HUMANOID_NAMETAG then
        pcall(function() h.DisplayName = DISGUISE_DISPLAY or DISGUISE_NAME end)
    end
    end
    if player.Character then onGuiChar(player.Character) end
    track(player.CharacterAdded:Connect(onGuiChar))
end

-- MODE 1/2: Full identity spoof (game.Players properties + text)
if MODE == 1 or MODE == 2 then
    if newIdentity >= 7 then
        player.Name = DISGUISE_NAME
        player.DisplayName = DISGUISE_DISPLAY
        player.UserId = DISGUISE_USER_ID
        print(string.format("✅ Identity spoof → Name: %s | Display: %s | ID: %d", DISGUISE_NAME, DISGUISE_DISPLAY, DISGUISE_USER_ID))
        switchDisguiseCleanup()
        replaceGlobally(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
        watchSettingsPeoplePage(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
        watchPlayerList(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
        if FORCE_VERIFIED then startVerifiedBadgeProtection(DISGUISE_USER_ID) end
    else
        print("⚠️ ThreadIdentity too low (", newIdentity, ") – cannot spoof identity.")
    end
end

-- MODE 1/3/5: Avatar spoof
if MODE == 1 or MODE == 3 or MODE == 5 then
    if player.Character then applyAvatarDisguise(player.Character) end
    track(player.CharacterAdded:Connect(applyAvatarDisguise))
end

-- Nametag spoof for modes 1, 2 (modes 4/5 handled above, mode 3 has no nametag spoof)
if MODE == 1 or MODE == 2 then
    local function spoofNametag(character)
    local humanoid = character:WaitForChild("Humanoid")
        if humanoid and SPOOF_HUMANOID_NAMETAG then
            if ORIG.HumanoidDisplayName == nil then ORIG.HumanoidDisplayName = humanoid.DisplayName end
            humanoid.DisplayName = DISGUISE_DISPLAY or DISGUISE_NAME
        end
    end
    if player.Character then spoofNametag(player.Character) end
    track(player.CharacterAdded:Connect(spoofNametag))
end

-- Hide root part for all modes except pure GUI-only (mode 4)
if player.Character and MODE ~= 4 then
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then rootPart.Transparency = 1 end
end

-- Store active state and cleanup
getgenv().Ryu_Disguise.Active = true
getgenv().Ryu_Disguise.cleanup = function()
    for _, conn in ipairs(STATE.Connections) do
        pcall(function() if conn.Connected then conn:Disconnect() end end)
    end
    STATE.Connections = {}
    clearWatchers()
    stopSettingsPeopleWatcher()
    stopPlayerListWatcher()
    stopVerifiedBadgeProtection()
end
getgenv().Ryu_Disguise.revert = function()
    revertIdentity()
    revertAvatar()
    getgenv().Ryu_Disguise.cleanup()
    getgenv().Ryu_Disguise.Active = false
    getgenv().Ryu_Disguise.Disguised = nil
end

-- ========== INTRO (conditional, minified) ==========
if FORCE_REPLAY_INTRO then
    getgenv().Ryu_Disguise_IntroPlayed = nil
end

if PLAY_INTRO and not getgenv().Ryu_Disguise_IntroPlayed then
   getgenv().Ryu_Disguise_IntroPlayed = true
   loadstring([==[local v="v1.0.4"warn(v)local function s(t)game.StarterGui:SetCore("ChatMakeSystemMessage",{Text=t,Color=Color3.fromRGB(43,98,255),Font=Enum.Font.Ubuntu})end s("Current Version: "..v)local function l()game:GetService("ContentProvider"):PreloadAsync({"http://www.roblox.com/asset/?id=8955607825"})task.wait()local g=Instance.new("ScreenGui")local i=Instance.new("ImageLabel")local t=Instance.new("TextLabel")local b=Instance.new("BlurEffect")b.Size=0 b.Parent=game:GetService("Lighting")g.Parent=game:GetService("CoreGui")g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling local s0=Instance.new("Sound")local s1=Instance.new("Sound")local s2=Instance.new("Sound")s0.Name="Swish Suck Reversed Metallic Swoosh Impact 2 (SFX)"s0.Parent=workspace s0.SoundId="rbxassetid://9119707271"s0.Volume=10 s1.Name="Swoosh"s1.Parent=workspace s1.SoundId="rbxassetid://9125527144"s1.Volume=10 s2.Name="Typewriter 4 (SFX)"s2.Parent=workspace s2.SoundId="rbxassetid://9113880610"s2.Volume=10 i.Parent=g i.AnchorPoint=Vector2.new(0.5,0.5)i.BackgroundColor3=Color3.fromRGB(255,255,255)i.BackgroundTransparency=1 i.Position=UDim2.new(0.5,0,1.5,0)i.Size=UDim2.new(0,200,0,200)i.Image="http://www.roblox.com/asset/?id=11478378840"t.Parent=g t.AnchorPoint=Vector2.new(0.5,0.5)t.BackgroundColor3=Color3.fromRGB(255,255,255)t.BackgroundTransparency=1 t.Position=UDim2.new(0.5,0,0.699999988,0)t.Size=UDim2.new(0,200,0,50)t.Font=Enum.Font.Ubuntu t.Text=""t.TextColor3=Color3.fromRGB(43,97,191)t.TextSize=52 t.TextStrokeColor3=Color3.fromRGB(21,23,30)t.TextStrokeTransparency=0.5 local bi=game:GetService("TweenService"):Create(b,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0),{Size=56})bi:Play()workspace.Swoosh:Play()i:TweenPosition(UDim2.new(0.5,0,0.5,0),Enum.EasingDirection.Out,Enum.EasingStyle.Back,1)task.wait(1.25)local function ty(tx,ob)for _ in string.gmatch(tx,".")do workspace["Typewriter 4 (SFX)"]:Play()ob.Text=ob.Text.._ task.wait(0.05)end end bi:Pause()ty("Credits:\nScript created by Ryu Nanashi\nmxsynry on Discord and Github.",t)task.wait(1)workspace["Swish Suck Reversed Metallic Swoosh Impact 2 (SFX)"]:Play()local function tt(obj,time,props)game:GetService("TweenService"):Create(obj,TweenInfo.new(time,Enum.EasingStyle.Exponential,Enum.EasingDirection.InOut),props):Play()end tt(t,workspace["Swish Suck Reversed Metallic Swoosh Impact 2 (SFX)"].TimeLength,{TextTransparency=1,TextStrokeTransparency=1})tt(i,workspace["Swish Suck Reversed Metallic Swoosh Impact 2 (SFX)"].TimeLength,{ImageTransparency=1})game:GetService("TweenService"):Create(b,TweenInfo.new(1,Enum.EasingStyle.Exponential,Enum.EasingDirection.InOut,0),{Size=0}):Play()task.wait(2)print("Intro done.")end l()]==])()
end

print(string.format("✅ Ryu's Disguise Script loaded – Mode %d | Identity: %d | User: %s (%s) | ID: %d | Avatar Delay: %.2fs",
    MODE, newIdentity, DISGUISE_NAME, DISGUISE_DISPLAY, DISGUISE_USER_ID, AVATAR_DELAY)