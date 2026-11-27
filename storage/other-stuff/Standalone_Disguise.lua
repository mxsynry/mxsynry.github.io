-- == Standalone Vape V4 Disguise Script ==
--959028788 atpaster Fleureavery, 2293855847 imCherry511 mxsynry, 7303329167 VampireRachie extar, 1942779387 kanphurich12345 NJ1, 2814169921 whywhywhywhyjustwhya sharkfallen,10394362390 ultimateaura27 SushiSigma, 8625608859 zxwnvc nuvn, 10747085267 Teto_Shenanigans Teto_Shenanigans, 5729496417 BumblingAnne BumblingAnne, 5365226172 BiGG BIGGAMING144, 1120303861 Petchji Petch_ji

-- ========== CONFIGURATION ==========
local DISGUISE_USER_ID = "BIGGAMING144"             -- e.g. "Builderman" or 156

-- Use username/UserId for ambiguous in-server display names.
local TARGET_PLAYER_IN_SERVER = nil             -- nil = use DISGUISE_USER_ID above
local TARGET_PLAYER_MATCH = "auto"             -- "auto", "username", "displayName", "userId"

local SHOW_STATUS_PANEL = false
local UPDATE_PLAYER_CARD = true             -- Update the player card after clicking a player entry
local UPDATE_CHAT_PREFIX = true
local UPDATE_SETTINGS_PEOPLE = true
local CHAT_BODY_GAP = 0 -- PrefixText and BodyText share an edge by default
local CHAT_COLOR_MODE = "target" -- "target" (Roblox palette) or "preserve"
local CHAT_PREFIX_DEBUG = true -- Bounded history in getgenv().Ryu_Disguise.ChatPrefixLog
local CHAT_PREFIX_LOG_LIMIT = 120
local STATUS_PANEL_SECONDS = 8
local LOCAL_TEXT_LABEL_PATHS = {
    -- "HUD.PlayerName",
}
-- Optional cosmetic UI fields, relative to PlayerGui or character.
local LOCAL_THUMBNAIL_FIELDS = {
    -- {root="playerGui", path="AvatarPreview.Portrait", kind="HeadShot", size=150},
    -- {root="character", path="Head.PreviewBillboard.Portrait", kind="HeadShot", size=150},
}
local QUIT = false                            -- Set true to revert everything and stop
local MODE = 5                                -- 1=avatar + presentation, 2=presentation only, 3=avatar only, 4=GUI text only, 5=avatar + GUI text
local USE_PRESET = false
local SELECTED_PRESET = "Sh4rkle"             -- or "CAC_Avatar", "Sh4rkle", "don_tachyon", or 1, 2, 3, 4
local FACELESS = true
local HEADLESS = true
local SPOOF_HUMANOID_NAMETAG = true           -- Set true if you want the nametag, false if it breaks the game
-- Old Workspace blacklist workaround (removed in QuietScoped):
-- ["Workspace"] = true, -- I DONT KNOW WHY THIS FIXES BLOCK TALE'S ERROR BUT DISABLE THIS IF YOU WANT NAMETAGS AND BILLBOARD GUI CREDENTIAL SPOOFING TO WORK!!
local RIG_READY_TIMEOUT = 15  -- Essential body parts only
local APPEARANCE_READY_TIMEOUT = 1  -- R6 only
local LIVE_TARGET_TIMEOUT = 1  -- Live target snapshot wait
local CACHE_TARGET_AVATAR = true
local AVATAR_CACHE_SECONDS = 300
local AVATAR_PREPARE_TIMEOUT = 10
local R15_PREFER_LIVE_APPEARANCE = true
local R15_ALIGN_FEET = true
local R15_FIRST_PERSON_FADE = true
local R15_SCALE_OVERRIDES = {                -- Empty = preserve target scales
    -- HeightScale = 1.05,
    -- WidthScale = 0.85,
    -- DepthScale = 0.85,
    -- HeadScale = 0.95,
    -- BodyTypeScale = 0.7,
    -- ProportionScale = 0.5,
}
local WATCH_LATE_APPEARANCE = true
local LATE_ASSET_WINDOW_SECONDS = 12

local PLAY_INTRO = true
local FORCE_REPLAY_INTRO = false
local INTRO_TITLE = "RYU DISGUISE"
local INTRO_SHOW_TARGET = true


-- ========== VERIFICATION BADGE ==========
local FORCE_VERIFIED = true                   -- Set true to show verified badge for disguised user
-- Fallback when PlayerIcon has no measurable geometry.
local BADGE_COLUMN_OFFSET = 20
local BADGE_VERTICAL_OFFSET = 1.5  -- Move badge down
local SHOW_BADGE_ON_REVERT = false            -- Set true to also show badge for your original account after revert

-- Badge keys accept UserIds, usernames, or display:Name.
-- auto uses readable status; other styles are local decorations.
local CUSTOM_PLAYER_BADGES = {
    -- [123456789] = {style="auto"},
    -- ["SomeUsername"] = {style="verified"},
    -- ["display:BIGG"] = {style="badges", badges={"verified","star"}},
    -- ["@SomeOtherUser"] = {style="badges", badges={"star", "premium"}},
    -- ["AnotherUser"] = {style="employee"},
    -- ["EmojiUser"] = {style="emoji", value="🧌"},
    -- ["ImageUser"] = {style="image", value="rbxassetid://123456789"},
    -- [1234567890] = {style="none"},
}
local CUSTOM_PLAYER_DISPLAY_NAMES = {
    -- ["SomeUsername"] = "Custom display name",
    -- ["display:BIGG"] = "Custom name for any in-server player showing BIGG",
    -- [123456789] = "Custom display name",
}
local MATCH_DISGUISED_ACCOUNT_BADGE = true
-- Avoid duplicating Roblox's native badge.
local MIRROR_REAL_VERIFIED_FOR_OTHERS = false
-- Group membership is only a hint, not proof of a creator/staff badge.
local AUTO_DETECT_VIDEO_STARS_GROUP = false
local AUTO_DETECT_ROBLOX_OFFICIAL_GROUP = false


--^^ i couldn't get this to work so if somebody ever get hold of this script pls help me, you can search "PlayerImage" on Dex and find the correct location to put badge textures.


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

pcall(function()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    local previous = pg and pg:FindFirstChild("RyuStatusPanel")
    if previous then previous:Destroy() end
end)
local statusGui, statusText, statusVersion
local statusRecent = {}
local statusLast = {}
local statusColors = {info="#8CB8FF", ok="#77E0B5", warning="#FFCD79", error="#FF8585"}
local statusEnabled = true
local function statusEscape(value)
    return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function status(level, ...)
    if not SHOW_STATUS_PANEL or not statusEnabled then return end
    local values = table.pack(...)
    local pieces = {}
    for i = 1, values.n do pieces[i] = tostring(values[i]) end
    local message = table.concat(pieces, " "):gsub("^Ryu Disguise:%s*", "")
    if #message > 240 then message = message:sub(1, 237) .. "..." end
    local now = os.clock()
    if statusLast[message] and now - statusLast[message] < 8 then return end
    if #statusRecent >= 4 then table.remove(statusRecent, 1) end
    for key, time in pairs(statusLast) do if now - time >= 8 then statusLast[key] = nil end end
    local count = 0
    for _ in pairs(statusLast) do count = count + 1 end
    if count >= 32 then statusLast = {} end
    statusLast[message] = now
    statusRecent[#statusRecent+1] = {level=level, message=message}
    pcall(function()
        local pg = player:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        if not statusGui or not statusGui.Parent then
            local previous = pg:FindFirstChild("RyuStatusPanel")
            if previous then previous:Destroy() end
            statusGui = Instance.new("ScreenGui")
            statusGui.Name = "RyuStatusPanel"
            statusGui.ResetOnSpawn = false
            statusGui.DisplayOrder = 10001
            statusGui.Parent = pg
            statusText = Instance.new("TextLabel")
            statusText.Name = "Status"
            statusText.AnchorPoint = Vector2.new(1, 1)
            statusText.Position = UDim2.new(1, -16, 1, -20)
            statusText.Size = UDim2.fromOffset(320, 100)
            statusText.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
            statusText.BackgroundTransparency = 0.12
            statusText.BorderSizePixel = 0
            statusText.TextColor3 = Color3.fromRGB(235, 240, 250)
            statusText.Font = Enum.Font.GothamMedium
            statusText.TextSize = 12
            statusText.TextWrapped = true
            statusText.RichText = true
            statusText.TextXAlignment = Enum.TextXAlignment.Left
            statusText.TextYAlignment = Enum.TextYAlignment.Center
            statusText.Parent = statusGui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = statusText
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 12)
            pad.PaddingRight = UDim.new(0, 12)
            pad.Parent = statusText
        end
        local lines = {}
        for _, entry in ipairs(statusRecent) do
            lines[#lines+1] = '<font color="' .. (statusColors[entry.level] or statusColors.info) .. '">' .. string.upper(entry.level) .. '</font>  ' .. statusEscape(entry.message)
        end
        statusText.Text = table.concat(lines, "\n")
        statusGui.Enabled = true
        statusVersion = (statusVersion or 0) + 1
        local version = statusVersion
        task.delay(STATUS_PANEL_SECONDS, function()
            if version == statusVersion and statusGui and statusGui.Parent then statusGui.Enabled = false end
        end)
    end)
end
local function stopStatus()
    statusEnabled = false
    statusVersion = (statusVersion or 0) + 1
    if statusGui then pcall(function() statusGui:Destroy() end) end
    statusGui, statusText = nil, nil
end

local function resolveAccountUserId(identifier)
    if type(identifier) == "number" and identifier > 0 then return identifier end
    if type(identifier) ~= "string" then return nil, "expected UserId or username" end
    local key = identifier:gsub("^@", "")
    if key:match("^%d+$") then return tonumber(key) end
    if key == "" then return nil, "empty username" end
    for _, existing in ipairs(Players:GetPlayers()) do
        if existing.Name:lower() == key:lower() then return existing.UserId end
    end
    local ok, result = pcall(function() return Players:GetUserIdFromNameAsync(key) end)
    if ok and type(result) == "number" then return result end
    return nil, tostring(result)
end

-- Usernames take precedence; duplicate display names are rejected.
local function resolveServerTarget(query, match)
    if typeof(query) == "Instance" and query:IsA("Player") then
        if query == player then return nil, "target must be another player" end
        if not query:IsDescendantOf(Players) then return nil, "player is not in this server" end
        return query
    end
    local needle = tostring(query or ""):match("^%s*(.-)%s*$")
    if needle == "" then return nil, "empty server target" end
    local kind = (match or "auto"):lower()
    local prefix, value = needle:match("^(%a+):%s*(.+)$")
    if prefix then
        prefix = prefix:lower()
        if prefix == "display" or prefix == "displayname" then kind = "displayname"
        elseif prefix == "username" or prefix == "name" then kind = "username"
        elseif prefix == "id" or prefix == "userid" then kind = "userid"
        else return nil, "unknown target prefix: " .. prefix end
        needle = value:match("^%s*(.-)%s*$")
    elseif needle:sub(1,1) == "@" then
        kind, needle = "username", needle:sub(2)
    end
    if kind ~= "auto" and kind ~= "username" and kind ~= "displayname" and kind ~= "userid" then
        return nil, "invalid TARGET_PLAYER_MATCH: " .. tostring(match)
    end
    local lowered = needle:lower()
    local numeric = tonumber(needle)
    local others = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then others[#others+1] = other end
    end
    if kind == "auto" or kind == "userid" then
        if numeric and numeric > 0 and numeric % 1 == 0 then
            for _, other in ipairs(others) do
                if other.UserId == numeric then return other end
            end
        end
        if kind == "userid" then return nil, "no player with UserId " .. needle end
    end
    if kind == "auto" or kind == "username" then
        for _, other in ipairs(others) do
            if other.Name:lower() == lowered then return other end
        end
        if kind == "username" then return nil, "no player with username " .. needle end
    end
    local matches = {}
    for _, other in ipairs(others) do
        if other.DisplayName:lower() == lowered then matches[#matches+1] = other end
    end
    if #matches == 1 then return matches[1] end
    if #matches > 1 then
        local names = {}
        for _, other in ipairs(matches) do names[#names+1] = "@" .. other.Name .. " (" .. other.UserId .. ")" end
        table.sort(names)
        return nil, "display name '" .. needle .. "' is ambiguous: " .. table.concat(names, ", ")
    end
    return nil, "no player matched '" .. needle .. "' in the current server"
end

local IN_SERVER_TARGET_PLAYER = nil
if not QUIT then
    local requested = DISGUISE_USER_ID
    if TARGET_PLAYER_IN_SERVER ~= nil and TARGET_PLAYER_IN_SERVER ~= "" then
        local target, err = resolveServerTarget(TARGET_PLAYER_IN_SERVER, TARGET_PLAYER_MATCH)
        if not target then status("error", err); return end
        IN_SERVER_TARGET_PLAYER = target
        requested = target.UserId
        status("info", "Ryu Disguise: in-server target @" .. target.Name .. " (" .. target.UserId .. ")")
    end
    local id, err = resolveAccountUserId(requested)
    if not id then status("error", "Target profile could not be resolved:", err); return end
    DISGUISE_USER_ID = id
end

-- ========== PERSISTENT STORAGE ==========
if not getgenv().Ryu_Disguise then
    getgenv().Ryu_Disguise = {
        Original = {
            Name = player.Name,
            DisplayName = player.DisplayName,
            UserId = player.UserId,
            Desc = (function()
                local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId) end)
                return ok and desc or nil
            end)()
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
        Desc = (function()
                local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId) end)
                return ok and desc or nil
            end)()
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
local DISGUISED_ACCOUNT_IS_VERIFIED = false
if IN_SERVER_TARGET_PLAYER then
    -- Player objects still work when UserService lookup fails.
    DISGUISE_NAME = IN_SERVER_TARGET_PLAYER.Name
    DISGUISE_DISPLAY = IN_SERVER_TARGET_PLAYER.DisplayName
    local ok, verified = pcall(function() return IN_SERVER_TARGET_PLAYER.HasVerifiedBadge end)
    DISGUISED_ACCOUNT_IS_VERIFIED = ok and verified == true
end
pcall(function()
    local infos = game:GetService("UserService"):GetUserInfosByUserIdsAsync({DISGUISE_USER_ID})
    if infos and #infos > 0 then
        DISGUISE_NAME = infos[1].Username
        DISGUISE_DISPLAY = infos[1].DisplayName
        DISGUISED_ACCOUNT_IS_VERIFIED = infos[1].HasVerifiedBadge == true
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


-- Player list
-- PlayerEntry_<UserId> always uses the real account ID.
local playerListWatcher = nil
local playerListConnections = {}
local playerListRootConnections = {}
local dropdownRowHooks = setmetatable({}, {__mode = "k"})
local dropdownSelectedId, dropdownSelectedAt
local playerListRootWatched = nil
local playerListQueued = false
STATE.BadgePendingEntries = setmetatable({}, {__mode = "k"})
STATE.BadgeLabelHooks = setmetatable({}, {__mode = "k"})
STATE.PlayerListOriginalText = setmetatable({}, {__mode = "k"})

local function stopPlayerListWatcher()
    STATE.PlayerListToken = nil
    if STATE.PlayerListTask then pcall(task.cancel, STATE.PlayerListTask); STATE.PlayerListTask = nil end
    STATE.RefreshPlayerListRules = nil
    for _, conn in ipairs(playerListConnections) do
        pcall(function() conn:Disconnect() end)
    end
    for _, conn in ipairs(playerListRootConnections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(playerListConnections)
    table.clear(playerListRootConnections)
    for _, hooks in pairs(dropdownRowHooks) do
        for _, conn in ipairs(hooks) do pcall(function() conn:Disconnect() end) end
    end
    dropdownRowHooks = setmetatable({}, {__mode = "k"})
    dropdownSelectedId, dropdownSelectedAt = nil, nil
    playerListRootWatched = nil
    playerListQueued = false
    if playerListWatcher then
        pcall(function() playerListWatcher:Disconnect() end)
        playerListWatcher = nil
    end
end

local function getPlayerListRoot()
    local ok, result = pcall(function()
        return CoreGui:FindFirstChild("PlayerList")
    end)
    return ok and result or nil
end

local function replacePlain(haystack, needle, replacement)
    if type(haystack) ~= "string" or type(needle) ~= "string" or needle == "" then
        return haystack
    end
    local out, start = {}, 1
    while true do
        local first, last = haystack:find(needle, start, true)
        if not first then break end
        out[#out + 1] = haystack:sub(start, first - 1)
        out[#out + 1] = tostring(replacement or "")
        start = last + 1
    end
    out[#out + 1] = haystack:sub(start)
    return table.concat(out)
end

local function entryIdFromName(entry)
    if not entry or not entry.Name then return nil end
    return tonumber(entry.Name:match("^PlayerEntry_(%d+)$"))
end

local function hasOtherPlayerWithId(id)
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.UserId == id then return true end
    end
    return false
end

local function isLocalPlayerEntry(entryId, oldId, newId)
    return entryId == ORIG.UserId
end

local entryPartsCache = setmetatable({}, {__mode = "k"})
local function locateNameLabel(entry)
    local cached = entryPartsCache[entry]
    if cached and cached.label and cached.frame and cached.label.Parent
        and cached.frame.Parent and cached.label:IsDescendantOf(entry)
        and cached.frame:IsDescendantOf(entry) then
        return cached.label, cached.frame
    end
    local content = entry:FindFirstChild("PlayerEntryContentFrame") or entry
    local nameFrame = content:FindFirstChild("NameFrame", true)
    if not nameFrame then return nil, nil end
    for _, descendant in ipairs(nameFrame:GetDescendants()) do
        if descendant.Name == "PlayerName" and
           (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) then
            entryPartsCache[entry] = {label=descendant, frame=nameFrame}
            return descendant, nameFrame
        end
    end
    for _, descendant in ipairs(nameFrame:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Text ~= "" then
            entryPartsCache[entry] = {label=descendant, frame=nameFrame}
            return descendant, nameFrame
        end
    end
    return nil, nameFrame
end

-- Resolve username rules asynchronously.
local BADGE_OVERRIDES_BY_ID = {}
local NAME_OVERRIDES_BY_ID = {}
-- display: rules apply to every match; use UserId for a single player.
local BADGE_OVERRIDES_BY_DISPLAY = {}
local NAME_OVERRIDES_BY_DISPLAY = {}
local function displayRuleKey(key)
    if type(key) ~= "string" then return nil end
    local prefix, body = key:match("^(%a+):%s*(.-)%s*$")
    if prefix and (prefix:lower() == "display" or prefix:lower() == "displayname") and body ~= "" then
        return body:lower()
    end
    return nil
end
local function getDisplayRuleForEntry(rules, userId, localRow)
    local shown
    if localRow then
        shown = DISGUISE_DISPLAY
    else
        local real = Players:GetPlayerByUserId(userId)
        if real and real ~= player then shown = real.DisplayName end
    end
    return shown and rules[shown:lower()] or nil
end
local BADGE_RULE_PRIORITY = {}
local NAME_RULE_PRIORITY = {}

local function installRule(targetTable, priorities, key, value, refresh)
    local function install(id)
        if not id then return end
        local priority = type(key) == "number" and 2 or 1
        if priority < (priorities[id] or 0) then return end
        priorities[id] = priority
        targetTable[id] = value
        if refresh and STATE.PlayerListToken and STATE.RefreshPlayerListRules then
            task.defer(STATE.RefreshPlayerListRules)
        end
    end
    if type(key) == "number" then
        install(key)
    elseif type(key) == "string" and key:match("^@?%d+$") then
        install(tonumber(key:gsub("^@", "")))
    elseif type(key) == "string" then
        task.spawn(function()
            local id, err = resolveAccountUserId(key)
            if id then
                install(id)
                if playerListWatcher then
                    task.defer(function()
                        if STATE.RefreshPlayerListRules then STATE.RefreshPlayerListRules() end
                    end)
                end
            else
                status("warning", "Ryu Disguise: badge username not resolved:", key, err)
            end
        end)
    end
end

for key, value in pairs(CUSTOM_PLAYER_BADGES) do
    local display = displayRuleKey(key)
    if display then
        BADGE_OVERRIDES_BY_DISPLAY[display] = value
    else
        installRule(BADGE_OVERRIDES_BY_ID, BADGE_RULE_PRIORITY, key, value, true)
    end
end
for key, value in pairs(CUSTOM_PLAYER_DISPLAY_NAMES) do
    local display = displayRuleKey(key)
    if display then
        NAME_OVERRIDES_BY_DISPLAY[display] = value
    else
        installRule(NAME_OVERRIDES_BY_ID, NAME_RULE_PRIORITY, key, value, true)
    end
end

local GROUP_MEMBERSHIP_HINTS = {}
local GROUP_MEMBERSHIP_PENDING = {}
local function getGroupMembershipHints(userId)
    if not (AUTO_DETECT_VIDEO_STARS_GROUP or AUTO_DETECT_ROBLOX_OFFICIAL_GROUP) then return nil end
    if GROUP_MEMBERSHIP_HINTS[userId] then return GROUP_MEMBERSHIP_HINTS[userId] end
    if GROUP_MEMBERSHIP_PENDING[userId] then return nil end
    GROUP_MEMBERSHIP_PENDING[userId] = true
    task.spawn(function()
        local ok, groups = pcall(function()
            return game:GetService("GroupService"):GetGroupsAsync(userId)
        end)
        local hints = {videoStarsCommunity=false, robloxOfficialCommunity=false}
        if ok and type(groups) == "table" then
            for _, group in ipairs(groups) do
                if group.Id == 4199740 then hints.videoStarsCommunity = true end
                if group.Id == 1200769 then hints.robloxOfficialCommunity = true end
            end
        else
            status("warning", "Ryu Disguise: group status unavailable:", userId, groups)
        end
        GROUP_MEMBERSHIP_HINTS[userId] = hints
        GROUP_MEMBERSHIP_PENDING[userId] = nil
        if STATE.RefreshPlayerListRules then
            task.defer(STATE.RefreshPlayerListRules)
        end
    end)
    return nil
end

local function autoBadgeForPlayer(userId, localRow)
    local verified, subscribed = false, false
    if localRow then
        verified = DISGUISED_ACCOUNT_IS_VERIFIED
    else
        local other = Players:GetPlayerByUserId(userId)
        if not other then return nil end
        local okV, v = pcall(function() return other.HasVerifiedBadge end)
        verified = okV and v == true
        local okS, s = pcall(function() return other.HasRobloxSubscription end)
        subscribed = okS and s == true
        if not okS then
            local okM, membership = pcall(function() return other.MembershipType end)
            subscribed = okM and membership == Enum.MembershipType.Premium
        end
    end
    local choices = {}
    if verified then choices[#choices+1] = "verified" end
    if subscribed then choices[#choices+1] = "subscription" end
    local profileId = localRow and DISGUISE_USER_ID or userId
    local hints = getGroupMembershipHints(profileId)
    if hints then
        if AUTO_DETECT_VIDEO_STARS_GROUP and hints.videoStarsCommunity then
            choices[#choices+1] = "star"
        end
        if AUTO_DETECT_ROBLOX_OFFICIAL_GROUP and hints.robloxOfficialCommunity then
            choices[#choices+1] = "official_group"
        end
    end
    if #choices == 0 then return nil end
    return {style="badges", badges=choices}
end

local function getRequestedBadge(entryId, localRow, isRevert)
    local override = BADGE_OVERRIDES_BY_ID[entryId]
    if localRow and not override then
        override = BADGE_OVERRIDES_BY_ID[DISGUISE_USER_ID]
    end
    if not override then
        override = getDisplayRuleForEntry(BADGE_OVERRIDES_BY_DISPLAY, entryId, localRow)
    end
    if override then
        if override.style == "auto" then return autoBadgeForPlayer(entryId, localRow) end
        return override
    end
    if localRow then
        if isRevert then return SHOW_BADGE_ON_REVERT and {style="verified"} or nil end
        if FORCE_VERIFIED or (MATCH_DISGUISED_ACCOUNT_BADGE and DISGUISED_ACCOUNT_IS_VERIFIED) then
            return {style = "verified"}
        end
    end
    if MIRROR_REAL_VERIFIED_FOR_OTHERS then
        local other = Players:GetPlayerByUserId(entryId)
        if other then
            local ok, verified = pcall(function() return other.HasVerifiedBadge end)
            if ok and verified == true then return {style="verified"} end
        end
    end
    return nil
end

local function normalizeBadgeList(spec)
    if spec.style ~= "badges" then return {spec} end
    local badges = {}
    for _, item in ipairs(spec.badges or {}) do
        local badge = type(item) == "string" and {style=item} or item
        if type(badge) == "table" and badge.style ~= "none" then
            badges[#badges+1] = badge
        end
    end
    return badges
end

local function setBadgeVisual(holder, badgeSpec)
    local badges = normalizeBadgeList(badgeSpec)
    if #badges == 0 then return false end
    local maxBadges = math.min(#badges, 6)
    local keyparts = {}
    for i=1,maxBadges do
        keyparts[#keyparts+1] = tostring(badges[i].style) .. ":" .. tostring(badges[i].value)
    end
    local renderKey = table.concat(keyparts, "|")
    holder:SetAttribute("RyuBadgeCount", maxBadges)
    if holder:GetAttribute("RyuRenderKey") == renderKey then return true end
    holder.Size = UDim2.fromOffset(maxBadges * 19, 17)
    holder:ClearAllChildren()
    local glyphs = {
        verified = utf8.char(0xE000),
        premium = utf8.char(0xE001),
        plus = utf8.char(0xE003),
        subscription = utf8.char(0xE001),
        star = "★",
        employee = "🛡",
        official_group = "◈",
    }
    for i=1,maxBadges do
        local spec = badges[i]
        local style, value = spec.style or "emoji", spec.value
        local visual
        if style == "image" then
            if type(value) ~= "string" or not
               (value:match("^rbxassetid://%d+$") or value:match("^rbxasset://")) then
                status("warning", "Ryu Disguise: invalid badge image asset URL", value)
                continue
            end
            visual = Instance.new("ImageLabel")
            visual.Image = value
            visual.ScaleType = Enum.ScaleType.Fit
        else
            local glyph = glyphs[style] or (style == "emoji" and type(value) == "string" and value)
            if not glyph then
                status("warning", "Ryu Disguise: unknown badge style", style)
                continue
            end
            visual = Instance.new("TextLabel")
            visual.Font = Enum.Font.GothamBold
            visual.Text = glyph
            visual.TextSize = style == "emoji" and 16 or 18
            visual.TextScaled = false
            visual.TextColor3 = Color3.fromRGB(255, 255, 255)
            visual.TextXAlignment = Enum.TextXAlignment.Center
            visual.TextYAlignment = Enum.TextYAlignment.Center
        end
        visual.Name = "Visual" .. i
        visual.Position = UDim2.fromOffset((i-1)*19, 0)
        visual.Size = UDim2.fromOffset(19,17)
        visual.BackgroundTransparency = 1
        visual.BorderSizePixel = 0
        visual.ZIndex = 101
        visual.Parent = holder
    end
    holder:SetAttribute("RyuRenderKey", renderKey)
    return #holder:GetChildren() > 0
end

-- PlayerIcon still has geometry when its image is empty.
-- Keep the last offset while Roblox rebuilds the row.
local nativeBadgeCalibration = nil
local nativeCalibrationRoot = nil
local rowCache = setmetatable({}, {__mode = "v"})
local rowCacheRoot = nil

local function nativeIconGeometry(nameFrame, nameLabel)
    if not (nameFrame and nameLabel and nameFrame.Parent and nameLabel.Parent) then return nil end
    local slot = nameFrame:FindFirstChild("PlayerIcon") or nameFrame:FindFirstChild("PlayerImage")
    if not slot or not slot:IsA("GuiObject") then return nil end
    local slotSize, labelSize = slot.AbsoluteSize, nameLabel.AbsoluteSize
    if slotSize.X < 1 or slotSize.Y < 1 or labelSize.Y < 1 then return nil end
    local dx = (slot.AbsolutePosition.X + slotSize.X * 0.5 - nameLabel.AbsolutePosition.X) / labelSize.Y
    local dy = (slot.AbsolutePosition.Y + slotSize.Y * 0.5 - nameLabel.AbsolutePosition.Y) / labelSize.Y
    if math.abs(dx) > 10 or math.abs(dy) > 5 then return nil end
    return {x=dx, y=dy, source=slot, label=nameLabel}
end

local function refreshNativeBadgeCalibration(list, entries)
    if nativeCalibrationRoot ~= list then
        nativeCalibrationRoot, nativeBadgeCalibration = list, nil
    end
    local chosen
    for _, entry in ipairs(entries) do
        if entryIdFromName(entry) == ORIG.UserId then
            local label, frame = locateNameLabel(entry)
            chosen = label and nativeIconGeometry(frame, label)
            if chosen then break end
        end
    end
    if not chosen then
        for _, entry in ipairs(entries) do
            local label, frame = locateNameLabel(entry)
            chosen = label and nativeIconGeometry(frame, label)
            if chosen then break end
        end
    end
    if chosen then
        nativeBadgeCalibration = chosen
    elseif nativeBadgeCalibration and nativeBadgeCalibration.source
        and not nativeBadgeCalibration.source:IsDescendantOf(list) then
        nativeBadgeCalibration = nil
    end
end

local function positionBadge(holder, nameLabel, nameFrame)
    if nameLabel.AbsoluteSize.Y < 1 then return end
    local sample = nativeIconGeometry(nameFrame, nameLabel) or nativeBadgeCalibration
    if sample then
        local count = holder:GetAttribute("RyuBadgeCount") or 1
        local source = sample.source
        local nativeSize = source and source.AbsoluteSize
        if nativeSize and nativeSize.X >= 1 and nativeSize.Y >= 1 then
            local width = math.clamp(math.floor(nativeSize.X + 0.5), 10, 40)
            local height = math.clamp(math.floor(nativeSize.Y + 0.5), 10, 40)
            if holder.Size.X.Offset ~= count * width or holder.Size.Y.Offset ~= height then
                holder.Size = UDim2.fromOffset(count * width, height)
                for i, visual in ipairs(holder:GetChildren()) do
                    if visual:IsA("GuiObject") then
                        visual.Position = UDim2.fromOffset((i - 1) * width, 0)
                        visual.Size = UDim2.fromOffset(width, height)
                        if visual:IsA("TextLabel") then
                            visual.TextSize = math.floor(18 * height / 17 + 0.5)
                        end
                    end
                end
            end
        end
        holder.AnchorPoint = Vector2.new(0.5 / count, 0.5)
        holder.Position = UDim2.fromOffset(
            sample.x * nameLabel.AbsoluteSize.Y,
            sample.y * nameLabel.AbsoluteSize.Y
        )
        return
    end
    local count = holder:GetAttribute("RyuBadgeCount") or 1
    holder.AnchorPoint = Vector2.new(1 - 0.5 / count, 0.5)
    holder.Position = UDim2.new(0, -BADGE_COLUMN_OFFSET, 0.5, BADGE_VERTICAL_OFFSET)
end

local function replacePlayerListEntry(entry, oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
    local entryId = entryIdFromName(entry)
    if not entryId then return end
    local localRow = isLocalPlayerEntry(entryId, oldId, newId)
    local otherNameOverride = NAME_OVERRIDES_BY_ID[entryId]
    if not otherNameOverride then
        otherNameOverride = getDisplayRuleForEntry(NAME_OVERRIDES_BY_DISPLAY, entryId, localRow)
    end
    local badgeSpec = getRequestedBadge(entryId, localRow, isRevert)
    if not localRow and not otherNameOverride and not badgeSpec then return end

    local label, nameFrame = locateNameLabel(entry)
    if not label or not nameFrame then return end

    local oldText = label.Text
    local newText = oldText
    if otherNameOverride and not localRow and not isRevert then
        newText = tostring(otherNameOverride)
    elseif localRow and oldName and newName then
        if oldText == oldDisplay or oldText == oldName then
            newText = newDisplay or newName
        end
    end
    if newText ~= oldText then
        if STATE.PlayerListOriginalText[label] == nil then
            STATE.PlayerListOriginalText[label] = oldText
        end
        pcall(function() label.Text = newText end)
    end

    -- Old NameFrame overlays displaced the text through UIListLayout.
    local legacyHolder = nameFrame:FindFirstChild("RyuLocalBadge")
    if legacyHolder then legacyHolder:Destroy() end

    local holder = label:FindFirstChild("RyuLocalBadge")
    if badgeSpec and badgeSpec.style ~= "none" then
        if holder and not holder:IsA("Frame") then holder:Destroy() holder = nil end
        if not holder then
            holder = Instance.new("Frame")
            holder.Name = "RyuLocalBadge"
            holder.BackgroundTransparency = 1
            holder.BorderSizePixel = 0
            holder.Size = UDim2.fromOffset(19, 17)
            holder.ZIndex = math.max(10, label.ZIndex + 1)
            holder.Active = false
            holder.Parent = label
        end
        if setBadgeVisual(holder, badgeSpec) then
            positionBadge(holder, label, nameFrame)
        else
            holder:Destroy()
            holder = nil
        end
    elseif holder then
        holder:Destroy()
        holder = nil
    end


end

-- The dropdown is shared. Its active row is identified by PlayerEntry_<UserId>.
local dropdownHooks = setmetatable({}, {__mode = "k"})
local dropdownOriginals = setmetatable({}, {__mode = "k"})
local dropdownCached
local dropdownBusy = false
local updateLocalDropdown

local function dropdownParts(list)
    local dropdown = dropdownCached and dropdownCached.dropdown
    if not (dropdown and dropdown.Parent and dropdown:IsDescendantOf(list)) then
        local body = list
        for _, name in ipairs({"Children", "OffsetFrame", "PlayerScrollList", "SizeOffsetFrame", "Column", "Body"}) do
            body = body and body:FindFirstChild(name)
        end
        dropdown = (body and body:FindFirstChild("PlayerDropDown"))
            or list:FindFirstChild("PlayerDropDown", true)
    end
    if not dropdown then return nil end
    local inner = dropdown:FindFirstChild("InnerFrame")
    local header = (inner and inner:FindFirstChild("PlayerHeader"))
        or dropdown:FindFirstChild("PlayerHeader", true)
    if not header then return nil end
    local background = header:FindFirstChild("Background")
    local textFrame = background and background:FindFirstChild("TextContainerFrame")
    local display = textFrame and textFrame:FindFirstChild("DisplayName")
    local name = textFrame and textFrame:FindFirstChild("PlayerName")
    local avatar = header:FindFirstChild("AvatarImage")
    if display and not (display:IsA("TextLabel") or display:IsA("TextButton")) then display = nil end
    if name and not (name:IsA("TextLabel") or name:IsA("TextButton")) then name = nil end
    if avatar and not (avatar:IsA("ImageLabel") or avatar:IsA("ImageButton")) then avatar = nil end
    if not (display or name or avatar) then return nil end
    -- Re-resolve the three fields every time: Roblox replaces them independently.
    dropdownCached = {dropdown=dropdown, display=display, name=name, avatar=avatar}
    return dropdownCached
end

local function dropdownPlain(value)
    return tostring(value or ""):gsub("<[^>]*>", ""):match("^%s*(.-)%s*$")
end

local function thumbnailUserId(image)
    if type(image) ~= "string" then return nil end
    return tonumber(image:match("[?&]id=(%d+)"))
end

local function setDropdownValue(obj, property, replacement)
    if obj[property] == replacement then return end
    local original = dropdownOriginals[obj]
    if not original or obj[property] ~= original.applied then
        original = {property=property, value=obj[property]}
        dropdownOriginals[obj] = original
    end
    original.applied = replacement
    obj[property] = replacement
end

local function observeDropdownRow(entry)
    if not UPDATE_PLAYER_CARD or dropdownRowHooks[entry] then return end
    local id = entryIdFromName(entry)
    if not id or not entry:IsA("GuiObject") then return end

    local hooks = {}
    local attached = setmetatable({}, {__mode = "k"})
    local function selectRow()
        if not STATE.PlayerListToken then return end
        if dropdownSelectedId == id and dropdownSelectedAt
            and os.clock() - dropdownSelectedAt < 0.04 then return end
        dropdownSelectedId, dropdownSelectedAt = id, os.clock()
        task.defer(function()
            if STATE.PlayerListToken and playerListRootWatched and updateLocalDropdown then
                updateLocalDropdown(playerListRootWatched)
            end
        end)
    end
    local function hookClick(obj)
        if not obj:IsA("GuiObject") or attached[obj] then return end
        attached[obj] = true
        hooks[#hooks+1] = obj.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                selectRow()
            end
        end)
        if obj:IsA("GuiButton") then
            hooks[#hooks+1] = obj.Activated:Connect(selectRow)
        end
    end

    hookClick(entry)
    for _, obj in ipairs(entry:GetDescendants()) do hookClick(obj) end
    hooks[#hooks+1] = entry.DescendantAdded:Connect(hookClick)
    dropdownRowHooks[entry] = hooks
end

local dropdownTrace = {attempts=0, last=nil, history={}}
STATE.DropdownTrace = dropdownTrace

updateLocalDropdown = function(list)
    if not UPDATE_PLAYER_CARD or dropdownBusy then return end
    local card = dropdownParts(list)
    if not card then return end

    -- A targeted fallback for native code resetting an existing field.
    for _, item in ipairs({
        {card.display, "Text"}, {card.name, "Text"}, {card.avatar, "Image"},
        {card.dropdown, "Visible"},
    }) do
        local obj, property = item[1], item[2]
        if obj and not dropdownHooks[obj] then
            dropdownHooks[obj] = obj:GetPropertyChangedSignal(property):Connect(function()
                if STATE.PlayerListToken then
                    task.defer(function()
                        if STATE.PlayerListToken then updateLocalDropdown(list) end
                    end)
                end
            end)
        end
    end

    local username = card.name and dropdownPlain(card.name.Text) or ""
    local display = card.display and dropdownPlain(card.display.Text) or ""
    local usernameNoAt = username:gsub("^@", "")
    local sourceId = card.avatar and thumbnailUserId(card.avatar.Image) or nil
    local selectedLocal = dropdownSelectedId == ORIG.UserId
    local lastImage = card.avatar and dropdownOriginals[card.avatar]
    local appliedHere = lastImage and lastImage.applied == card.avatar.Image
        and sourceId == DISGUISE_USER_ID

    -- The dropdown can still contain the previous player's header after a click.
    local originalNameShown = usernameNoAt ~= ""
        and usernameNoAt:lower() == ORIG.Name:lower()
    local originalDisplayShown = display ~= ""
        and display:lower() == ORIG.DisplayName:lower()
    local lastName = card.name and dropdownOriginals[card.name]
    local previouslyDisguised = appliedHere
        or (lastName and lastName.applied == card.name.Text
            and usernameNoAt:lower() == DISGUISE_NAME:lower())
    local owns = selectedLocal and (
        sourceId == ORIG.UserId or originalNameShown
        or originalDisplayShown or previouslyDisguised
    )

    local snapshot = {
        name=card.name and card.name.Text or nil,
        display=card.display and card.display.Text or nil,
        image=card.avatar and card.avatar.Image or nil,
        imageId=sourceId, matched=owns,
        selected=dropdownSelectedId,
        reason=not selectedLocal and "not clicked local row"
            or owns and "local card" or "waiting for local card content",
    }
    dropdownTrace.attempts += 1
    if not dropdownTrace.last or dropdownTrace.last.name ~= snapshot.name
        or dropdownTrace.last.display ~= snapshot.display
        or dropdownTrace.last.image ~= snapshot.image
        or dropdownTrace.last.matched ~= snapshot.matched
        or dropdownTrace.last.selected ~= snapshot.selected then
        dropdownTrace.history[#dropdownTrace.history+1] = snapshot
        if #dropdownTrace.history > 24 then table.remove(dropdownTrace.history, 1) end
    end
    dropdownTrace.last = snapshot
    if not owns then return end

    dropdownBusy = true
    local errors = {}
    local function apply(obj, property, value)
        if not obj then return end
        local ok, err = pcall(setDropdownValue, obj, property, value)
        if not ok then errors[#errors+1] = tostring(err) end
    end
    apply(card.display, "Text", DISGUISE_DISPLAY)
    apply(card.name, "Text", "@" .. DISGUISE_NAME)
    if card.avatar then
        local image = card.avatar.Image
        local changed, n = image:gsub("([?&]id=)%d+", function(idPrefix)
            return idPrefix .. tostring(DISGUISE_USER_ID)
        end, 1)
        if n == 0 then
            changed = string.format(
                "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", DISGUISE_USER_ID)
        end
        apply(card.avatar, "Image", changed)
    end
    dropdownBusy = false
    if #errors > 0 then
        dropdownTrace.last.reason = "write error: " .. table.concat(errors, "; ")
        dropdownCached = nil
    end
end

local function replacePlayerList(oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
    local list = getPlayerListRoot()
    if not list then return end
    if rowCacheRoot ~= list then
        rowCacheRoot = list
        rowCache = setmetatable({}, {__mode = "v"})
        entryPartsCache = setmetatable({}, {__mode = "k"})
        for _, desc in ipairs(list:GetDescendants()) do
            if desc:IsA("Frame") then
                local id = entryIdFromName(desc)
                if id then rowCache[id] = desc end
            end
        end
    end
    local entries = {}
    for id, entry in pairs(rowCache) do
        if entry and entry.Parent and entry:IsDescendantOf(list) then
            entries[#entries+1] = entry
            observeDropdownRow(entry)
        else
            rowCache[id] = nil
        end
    end
    refreshNativeBadgeCalibration(list, entries)
    for _, entry in ipairs(entries) do
        replacePlayerListEntry(entry, oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert)
        local id = entryIdFromName(entry)
        local localRow = id == ORIG.UserId
        local watched = localRow or NAME_OVERRIDES_BY_ID[id]
            or getDisplayRuleForEntry(NAME_OVERRIDES_BY_DISPLAY, id, false)
            or BADGE_OVERRIDES_BY_ID[id]
            or getDisplayRuleForEntry(BADGE_OVERRIDES_BY_DISPLAY, id, false)
        local label, frame = watched and locateNameLabel(entry)
        if label and not STATE.BadgeLabelHooks[label] then
            local busy = false
            local function redo()
                if busy or not STATE.PlayerListToken then return end
                busy = true
                pcall(replacePlayerListEntry, entry, oldName, newName,
                    oldDisplay, newDisplay, oldId, newId, false)
                busy = false
            end
            local hooks = {
                label:GetPropertyChangedSignal("Text"):Connect(redo),
                label:GetPropertyChangedSignal("AbsoluteSize"):Connect(redo),
                label:GetPropertyChangedSignal("AbsolutePosition"):Connect(redo),
            }
            local slot = frame:FindFirstChild("PlayerIcon") or frame:FindFirstChild("PlayerImage")
            if slot and slot:IsA("GuiObject") then
                hooks[#hooks+1] = slot:GetPropertyChangedSignal("AbsoluteSize"):Connect(redo)
                hooks[#hooks+1] = slot:GetPropertyChangedSignal("AbsolutePosition"):Connect(redo)
            end
            STATE.BadgeLabelHooks[label] = hooks
        end
    end
    updateLocalDropdown(list)
end

local function watchPlayerList(oldName, newName, oldDisplay, newDisplay, oldId, newId)
    stopPlayerListWatcher()
    local token = {}
    STATE.PlayerListToken = token
    local function refresh()
        if STATE.PlayerListToken ~= token then return end
        local ok, err = pcall(replacePlayerList, oldName, newName,
            oldDisplay, newDisplay, oldId, newId, false)
        if not ok then
            status("warning", "Player list unavailable:", err)
        end
    end
    STATE.RefreshPlayerListRules = refresh
    local function queueRefresh()
        if STATE.PlayerListToken ~= token or playerListQueued then return end
        playerListQueued = true
        task.defer(function()
            playerListQueued = false
            if STATE.PlayerListToken == token then refresh() end
        end)
    end
    local function attach(root)
        if STATE.PlayerListToken ~= token or not root or playerListRootWatched == root then return end
        for _, conn in ipairs(playerListRootConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(playerListRootConnections)
        for _, hooks in pairs(dropdownRowHooks) do
            for _, conn in ipairs(hooks) do pcall(function() conn:Disconnect() end) end
        end
        dropdownRowHooks = setmetatable({}, {__mode = "k"})
        playerListRootWatched = root
        dropdownCached = nil
        dropdownSelectedId, dropdownSelectedAt = nil, nil
        rowCacheRoot = nil
        table.insert(playerListRootConnections, root.DescendantAdded:Connect(function(desc)
            local id = entryIdFromName(desc)
            if id and desc:IsA("Frame") then rowCache[id] = desc end
            if desc.Name == "PlayerDropDown" or desc.Name == "PlayerHeader"
                or desc.Name == "TextContainerFrame" or desc.Name == "DisplayName"
                or desc.Name == "AvatarImage" or desc.Name == "PlayerName" then
                dropdownCached = nil
            end
            if id or desc.Name == "PlayerName" or desc.Name == "NameFrame"
                or desc.Name == "PlayerIcon" or desc.Name == "PlayerImage"
                or desc.Name == "PlayerDropDown" or desc.Name == "PlayerHeader"
                or desc.Name == "TextContainerFrame" or desc.Name == "DisplayName"
                or desc.Name == "AvatarImage" then
                queueRefresh()
            end
        end))
        table.insert(playerListRootConnections, root.DescendantRemoving:Connect(function(desc)
            local id = entryIdFromName(desc)
            if id and rowCache[id] == desc then rowCache[id] = nil end
            if desc == (dropdownCached and dropdownCached.name)
                or desc == (dropdownCached and dropdownCached.display)
                or desc == (dropdownCached and dropdownCached.avatar)
                or desc.Name == "PlayerDropDown" then dropdownCached = nil end
            if id or desc.Name == "PlayerDropDown" then queueRefresh() end
        end))
        queueRefresh()
    end
    table.insert(playerListConnections, CoreGui.ChildAdded:Connect(function(child)
        if child.Name == "PlayerList" then attach(child) end
    end))
    table.insert(playerListConnections, CoreGui.ChildRemoved:Connect(function(child)
        if child == playerListRootWatched then
            playerListRootWatched = nil
            dropdownCached = nil
            dropdownSelectedId, dropdownSelectedAt = nil, nil
            rowCacheRoot = nil
        end
    end))
    local root = getPlayerListRoot()
    if root then attach(root) end
    refresh()
    -- Only the three dropdown fields are checked; no CoreGui tree scan.
    local cardClock = 0
    table.insert(playerListConnections, game:GetService("RunService").Heartbeat:Connect(function(dt)
        if STATE.PlayerListToken ~= token or not UPDATE_PLAYER_CARD then return end
        cardClock += dt
        if cardClock < 0.075 then return end
        cardClock = 0
        if playerListRootWatched and dropdownSelectedId then
            updateLocalDropdown(playerListRootWatched)
        end
    end))
    -- Catches CoreGui changes missed by descendant events.
    STATE.PlayerListTask = task.spawn(function()
        while STATE.PlayerListToken == token do
            task.wait(8)
            local nextRoot = getPlayerListRoot()
            if nextRoot and nextRoot ~= playerListRootWatched then attach(nextRoot) end
            refresh()
        end
    end)
end

local function restorePlayerListVisuals()
    for label, originalText in pairs(STATE.PlayerListOriginalText or {}) do
        if label and label.Parent then pcall(function() label.Text = originalText end) end
    end
    STATE.PlayerListOriginalText = setmetatable({}, {__mode = "k"})
    for obj, original in pairs(dropdownOriginals) do
        pcall(function()
            if obj and obj.Parent and obj[original.property] == original.applied then
                obj[original.property] = original.value
            end
        end)
    end
    for obj, conn in pairs(dropdownHooks) do
        pcall(function() conn:Disconnect() end)
    end
    for _, hooks in pairs(STATE.BadgeLabelHooks) do
        for _, conn in ipairs(hooks) do pcall(function() conn:Disconnect() end) end
    end
    dropdownOriginals = setmetatable({}, {__mode = "k"})
    dropdownHooks = setmetatable({}, {__mode = "k"})
    dropdownCached = nil
    STATE.BadgeLabelHooks = setmetatable({}, {__mode = "k"})
    pcall(function()
        local list = getPlayerListRoot()
        if list then
            for _, descendant in ipairs(list:GetDescendants()) do
                if descendant.Name == "RyuLocalBadge" then descendant:Destroy() end
            end
        end
    end)
end

-- Chat rows get recycled; only PrefixText and its visible name matter.
local chatConnections = {}
local chatRootConnections = {}
local chatLabelHooks = setmetatable({}, {__mode = "k"})
local chatOriginals = setmetatable({}, {__mode = "k"})
local chatLayoutHooks = setmetatable({}, {__mode = "k"})
local chatLayoutOriginals = setmetatable({}, {__mode = "k"})
local chatLayoutRefresh = setmetatable({}, {__mode = "k"})
local chatRootWatched
local chatToken

STATE.ChatPrefixLog = {}
STATE.ChatPrefixLive = setmetatable({}, {__mode = "k"})

local function logChatPrefix(event, label, raw, result)
    if not CHAT_PREFIX_DEBUG then return end
    local history = STATE.ChatPrefixLog
    history[#history + 1] = {
        event = event,
        name = label and label.Parent and label.Parent.Parent and label.Parent.Parent.Name or "?",
        prefix = tostring(raw or ""):sub(1, 200),
        result = tostring(result or ""):sub(1, 200),
    }
    if #history > CHAT_PREFIX_LOG_LIMIT then table.remove(history, 1) end
end

local CHAT_NAME_COLORS = {
    Color3.fromRGB(253, 41, 67),
    Color3.fromRGB(1, 162, 255),
    Color3.fromRGB(2, 184, 87),
    BrickColor.new("Bright violet").Color,
    BrickColor.new("Bright orange").Color,
    BrickColor.new("Bright yellow").Color,
    BrickColor.new("Light reddish violet").Color,
    BrickColor.new("Brick yellow").Color,
}

local function chatNameColor(username, targetId)
    local target = Players:GetPlayerByUserId(targetId or -1)
    if target and target.Team then return target.TeamColor.Color end
    local value, count = 0, #username
    for i = 1, count do
        local n = string.byte(username, i)
        local reverse = count - i + 1
        if count % 2 == 1 then reverse -= 1 end
        if reverse % 4 >= 2 then n = -n end
        value += n
    end
    return CHAT_NAME_COLORS[(value % #CHAT_NAME_COLORS) + 1]
end

local function chatSpeaker(prefix)
    local plain = prefix:gsub("<[^>]*>", "")
    plain = plain:match("^%s*(.-)%s*$") or ""
    for _ = 1, 4 do
        local after = plain:gsub("^%b[]%s*", "", 1)
        if after == plain then break end
        plain = after
    end
    local speaker = plain:match("^(.-)%s*:%s*$")
    if not speaker and not plain:find(":", 1, true) then speaker = plain end
    if not speaker or speaker == "" then return nil end
    speaker = speaker:match("^%s*(.-)%s*$")
    return speaker ~= "" and speaker or nil
end

local function chatReplacement(speaker)
    local normalized = speaker:gsub("^@", ""):lower()
    if normalized == ORIG.Name:lower() or normalized == ORIG.DisplayName:lower() then
        return DISGUISE_DISPLAY or DISGUISE_NAME, DISGUISE_NAME, DISGUISE_USER_ID
    end
    local matchName, matchPlayer, ambiguous
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and (other.Name:lower() == normalized or other.DisplayName:lower() == normalized) then
            local override = NAME_OVERRIDES_BY_ID[other.UserId]
                or getDisplayRuleForEntry(NAME_OVERRIDES_BY_DISPLAY, other.UserId, false)
            if override then
                if matchPlayer then ambiguous = true; break end
                matchPlayer, matchName = other, tostring(override)
            end
        end
    end
    if ambiguous or not matchPlayer then return nil end
    return matchName, matchName, matchPlayer.UserId
end

local function escapeChatText(text)
    return tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

local function rewrittenChatPrefix(original, oldSpeaker, alias, hexColor, richText)
    local visible = original:gsub("<[^>]*>", "")
    local first, last, cursor
    cursor = 1
    while true do
        local x, y = visible:find(oldSpeaker, cursor, true)
        if not x then break end
        local left = x == 1 and "" or visible:sub(x - 1, x - 1)
        local right = visible:sub(y + 1)
        if (left == "" or left:match("[%s%]%)]")) and
            (right:match("^%s*:%s*$") or right:match("^%s*$")) then
            first, last = x, y
            break
        end
        cursor = y + 1
    end
    if not first then return nil end
    local wanted = oldSpeaker:sub(1, 1) == "@" and ("@" .. alias) or alias
    local replacement = richText and
        ('<font color="#' .. hexColor .. '">' .. escapeChatText(wanted) .. '</font>') or wanted
    local parts, rawAt, visibleAt, inserted = {}, 1, 1, false
    while rawAt <= #original do
        local tagAt = original:find("<", rawAt, true) or (#original + 1)
        local chunk = original:sub(rawAt, tagAt - 1)
        if chunk ~= "" then
            local chunkEnd = visibleAt + #chunk - 1
            if chunkEnd < first or visibleAt > last then
                parts[#parts + 1] = chunk
            else
                local keepLeft = math.max(0, first - visibleAt)
                local keepRight = math.max(0, chunkEnd - last)
                if keepLeft > 0 then parts[#parts + 1] = chunk:sub(1, keepLeft) end
                if not inserted then parts[#parts + 1] = replacement; inserted = true end
                if keepRight > 0 then parts[#parts + 1] = chunk:sub(#chunk - keepRight + 1) end
            end
            visibleAt = chunkEnd + 1
        end
        if tagAt > #original then break end
        local tagEnd = original:find(">", tagAt, true)
        if not tagEnd then parts[#parts + 1] = original:sub(tagAt); break end
        parts[#parts + 1] = original:sub(tagAt, tagEnd)
        rawAt = tagEnd + 1
    end
    return inserted and table.concat(parts) or nil
end

local function getChatScrollView(root)
    local node = root
    for _, name in ipairs({"appLayout", "chatWindow", "contentFrame", "scrollingView", "bottomLockedScrollView", "scrollView"}) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

local chatLayoutObserved = setmetatable({}, {__mode = "k"})
STATE.ChatLayoutObserved = chatLayoutObserved

local function chatTextWidth(label, content)
    local plain = tostring(content or ""):gsub("<[^>]*>", "")
    plain = plain:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '\"'):gsub("&amp;", "&")
    local ok, bounds = pcall(function()
        return game:GetService("TextService"):GetTextSize(
            plain, label.TextSize, label.Font, Vector2.new(10000, 10000))
    end)
    return ok and bounds.X or 0
end

local function restoreChatLayout(prefix)
    local old = chatLayoutOriginals[prefix]
    if not old then return end
    pcall(function()
        if prefix.Parent then
            prefix.Size = old.prefixSize
            prefix.AutomaticSize = old.prefixAutomaticSize
        end
        if old.body and old.body.Parent then
            old.body.Position = old.bodyPosition
        end
    end)
end

local function bindChatLayout(prefix, sourceText, replacementText)
    local row = prefix.Parent
    local body = row and row:FindFirstChild("BodyText")
    if not (row and body and prefix:IsA("TextLabel") and body:IsA("TextLabel")) then return end

    local cached = chatLayoutOriginals[prefix]
    if cached and cached.body ~= body then
        local connections = chatLayoutHooks[prefix] or {}
        for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
        restoreChatLayout(prefix)
        chatLayoutHooks[prefix] = nil
        chatLayoutOriginals[prefix] = nil
        chatLayoutRefresh[prefix] = nil
        cached = nil
    end

    if not cached then
        local layout = row:FindFirstChild("RyuChatFlow")
        if layout and layout:IsA("UIListLayout") then layout:Destroy() end
        local scale = 1
        local parent = prefix
        while parent do
            local uiScale = parent:FindFirstChildOfClass("UIScale")
            if uiScale then scale *= uiScale.Scale end
            parent = parent.Parent
        end
        cached = {
            body = body,
            prefixSize = prefix.Size,
            prefixAutomaticSize = prefix.AutomaticSize,
            prefixAbsoluteWidth = prefix.AbsoluteSize.X / math.max(scale, 0.01),
            bodyPosition = body.Position,
            nativeLayout = row:FindFirstChildOfClass("UIListLayout"),
            sourceText = sourceText,
            replacementText = replacementText,
        }
        chatLayoutOriginals[prefix] = cached
    else
        cached.replacementText = replacementText or cached.replacementText
    end

    if chatLayoutRefresh[prefix] then return chatLayoutRefresh[prefix] end

    local pending, adjusting = false, false
    local function adjust()
        local old = chatLayoutOriginals[prefix]
        if adjusting or not chatToken or not old or prefix.Parent ~= row or body.Parent ~= row then return end
        adjusting = true
        pcall(function()
            local oldWidth = chatTextWidth(prefix, old.sourceText)
            local newWidth = chatTextWidth(prefix, old.replacementText)
            if oldWidth <= 0 or newWidth <= 0 then return end
            local delta = newWidth - oldWidth
            local x, y = old.prefixSize.X, old.prefixSize.Y
            local prefixX

            if old.prefixAutomaticSize == Enum.AutomaticSize.X or
                old.prefixAutomaticSize == Enum.AutomaticSize.XY then
                local originalWidth = old.prefixAbsoluteWidth > 0 and old.prefixAbsoluteWidth or oldWidth
                -- Keep the original auto-sized width as the starting point.
                prefixX = UDim.new(0, math.max(1, math.floor(originalWidth + delta + 0.5)))
                local autoY = old.prefixAutomaticSize == Enum.AutomaticSize.XY
                    and Enum.AutomaticSize.Y or Enum.AutomaticSize.None
                if prefix.AutomaticSize ~= autoY then prefix.AutomaticSize = autoY end
            else
                prefixX = UDim.new(x.Scale, math.floor(x.Offset + delta + 0.5))
            end

            local wantedSize = UDim2.new(prefixX.Scale, prefixX.Offset, y.Scale, y.Offset)
            if prefix.Size ~= wantedSize then prefix.Size = wantedSize end

            -- Native UIListLayout moves BodyText when PrefixText changes size.
            -- Otherwise shift the original BodyText position by the same delta.
            if not old.nativeLayout then
                local p = old.bodyPosition
                local wantedPos = UDim2.new(p.X.Scale, p.X.Offset + math.floor(delta + CHAT_BODY_GAP + 0.5),
                    p.Y.Scale, p.Y.Offset)
                if body.Position ~= wantedPos then body.Position = wantedPos end
            end
            chatLayoutObserved[prefix] = {
                prefix = prefix.Text,
                bodyText = body.Text,
                prefixPosition = {prefix.AbsolutePosition.X, prefix.AbsolutePosition.Y},
                bodyPosition = {body.AbsolutePosition.X, body.AbsolutePosition.Y},
                delta = delta,
                layout = old.nativeLayout and "native" or "position",
            }
        end)
        adjusting = false
    end
    local function request()
        if pending or adjusting or not chatToken then return end
        pending = true
        task.defer(function()
            pending = false
            if chatToken and prefix.Parent == row then adjust() end
        end)
    end
    chatLayoutHooks[prefix] = {
        prefix:GetPropertyChangedSignal("Size"):Connect(request),
        prefix:GetPropertyChangedSignal("AutomaticSize"):Connect(request),
        body:GetPropertyChangedSignal("Position"):Connect(request),
        row:GetPropertyChangedSignal("AbsoluteSize"):Connect(request),
    }
    chatLayoutRefresh[prefix] = request
    request()
    return request
end

local function detachChatLabel(label)
    local hooks = chatLabelHooks[label]
    if hooks then
        for _, conn in ipairs(hooks) do pcall(function() conn:Disconnect() end) end
    end
    local layoutHooks = chatLayoutHooks[label]
    if layoutHooks then
        for _, conn in ipairs(layoutHooks) do pcall(function() conn:Disconnect() end) end
    end
    restoreChatLayout(label)
    chatLayoutHooks[label] = nil
    chatLayoutOriginals[label] = nil
    chatLayoutObserved[label] = nil
    chatLayoutRefresh[label] = nil
    chatLabelHooks[label] = nil
    chatOriginals[label] = nil
    STATE.ChatPrefixLive[label] = nil
end

local function bindChatPrefix(label, scroll)
    if not (label and label.Name == "PrefixText" and
        (label:IsA("TextLabel") or label:IsA("TextButton"))) then return end
    local message = label.Parent
    if not message or message.Name ~= "TextMessage" or not message:IsDescendantOf(scroll) then return end
    if chatLabelHooks[label] then return end
    local busy = false
    local function refresh()
        if busy or not chatToken or not label:IsDescendantOf(scroll) then return end
        local raw = label.Text
        local speaker = chatSpeaker(raw)
        local alias, colorName, userId = speaker and chatReplacement(speaker)
        STATE.ChatPrefixLive[label] = {prefix=raw, speaker=speaker, matched=alias ~= nil}
        if not alias then logChatPrefix("seen", label, raw, "no match"); return end

        local hex, targetColor
        if CHAT_COLOR_MODE ~= "preserve" then
            local ok, color = pcall(chatNameColor, colorName, userId)
            if ok and color then
                targetColor = color
                hex = color:ToHex()
            end
        end
        local replacement = rewrittenChatPrefix(raw, speaker, alias, hex, hex ~= nil and label.RichText)
        if not replacement or replacement == raw then
            logChatPrefix("seen", label, raw, "no editable name span")
            return
        end
        local previous = chatOriginals[label]
        if not previous or raw ~= previous.applied then
            previous = {text=raw, color=label.TextColor3}
            chatOriginals[label] = previous
        end
        previous.applied = replacement
        local requestLayout = bindChatLayout(label, raw, replacement)
        busy = true
        local ok = pcall(function()
            if hex and not label.RichText then
                label.TextColor3 = targetColor
            end
            label.Text = replacement
        end)
        busy = false
        if ok then
            if requestLayout then requestLayout() end
            STATE.ChatPrefixLive[label] = {prefix=replacement, speaker=speaker, matched=true}
            logChatPrefix("changed", label, raw, replacement)
        end
    end
    local hooks = {}
    hooks[#hooks + 1] = label:GetPropertyChangedSignal("Text"):Connect(refresh)
    hooks[#hooks + 1] = label.AncestryChanged:Connect(function()
        if not label:IsDescendantOf(scroll) then
            logChatPrefix("purged", label, label.Text, "")
            detachChatLabel(label)
        end
    end)
    chatLabelHooks[label] = hooks
    refresh()
end

local function stopChatPrefixWatcher()
    chatToken = nil
    for _, conn in ipairs(chatConnections) do pcall(function() conn:Disconnect() end) end
    for _, conn in ipairs(chatRootConnections) do pcall(function() conn:Disconnect() end) end
    table.clear(chatConnections)
    table.clear(chatRootConnections)
    for label, original in pairs(chatOriginals) do
        if label and label.Parent and label.Text == original.applied then
            pcall(function()
                label.Text = original.text
                label.TextColor3 = original.color
            end)
        end
    end
    for prefix in pairs(chatLayoutOriginals) do restoreChatLayout(prefix) end
    for label in pairs(chatLabelHooks) do detachChatLabel(label) end
    chatLabelHooks = setmetatable({}, {__mode = "k"})
    chatOriginals = setmetatable({}, {__mode = "k"})
    chatLayoutHooks = setmetatable({}, {__mode = "k"})
    chatLayoutOriginals = setmetatable({}, {__mode = "k"})
    chatLayoutRefresh = setmetatable({}, {__mode = "k"})
    STATE.ChatPrefixLive = setmetatable({}, {__mode = "k"})
    chatRootWatched = nil
end

local function watchChatPrefixes()
    if not UPDATE_CHAT_PREFIX then return end
    stopChatPrefixWatcher()
    local token = {}
    chatToken = token
    local function scan(root)
        local scroll = root and getChatScrollView(root)
        if not scroll then return end
        for _, desc in ipairs(scroll:GetDescendants()) do
            if desc.Name == "PrefixText" then bindChatPrefix(desc, scroll) end
        end
    end
    local function attach(root)
        if not root or chatRootWatched == root or chatToken ~= token then return end
        for _, conn in ipairs(chatRootConnections) do pcall(function() conn:Disconnect() end) end
        table.clear(chatRootConnections)
        chatRootWatched = root
        chatRootConnections[#chatRootConnections + 1] = root.DescendantAdded:Connect(function(desc)
            if chatToken ~= token then return end
            if desc.Name == "PrefixText" then
                local scroll = getChatScrollView(root)
                if scroll then bindChatPrefix(desc, scroll) end
            elseif desc.Name == "BodyText" and desc.Parent then
                local prefix = desc.Parent:FindFirstChild("PrefixText")
                if prefix then
                    local scroll = getChatScrollView(root)
                    if scroll then bindChatPrefix(prefix, scroll) end
                    if chatOriginals[prefix] then
                        local current = chatLayoutOriginals[prefix]
                        if current and current.body ~= desc then
                            local hooks = chatLayoutHooks[prefix] or {}
                            for _, conn in ipairs(hooks) do pcall(function() conn:Disconnect() end) end
                            restoreChatLayout(prefix)
                            chatLayoutHooks[prefix] = nil
                            chatLayoutOriginals[prefix] = nil
                            chatLayoutRefresh[prefix] = nil
                        end
                        local original = chatOriginals[prefix]
                        local request = bindChatLayout(prefix,
                            original and original.text or prefix.Text,
                            original and original.applied or prefix.Text)
                        if request then request() end
                    end
                end
            elseif desc.Name == "scrollView" then
                task.defer(function() if chatToken == token then scan(root) end end)
            end
        end)
        scan(root)
    end
    chatConnections[#chatConnections + 1] = CoreGui.ChildAdded:Connect(function(child)
        if child.Name == "ExperienceChat" then attach(child) end
    end)
    chatConnections[#chatConnections + 1] = CoreGui.ChildRemoved:Connect(function(child)
        if child == chatRootWatched then
            chatRootWatched = nil
            for label in pairs(chatLabelHooks) do detachChatLabel(label) end
        end
    end)
    attach(CoreGui:FindFirstChild("ExperienceChat"))
end


-- Captures what Roblox actually displays; read-only and bounded.
STATE.GetUISnapshot = function()
    local result = {
        identity={originalName=ORIG.Name, originalDisplay=ORIG.DisplayName,
            originalId=ORIG.UserId, targetName=DISGUISE_NAME,
            targetDisplay=DISGUISE_DISPLAY, targetId=DISGUISE_USER_ID},
        dropdown=dropdownTrace.last, dropdownAttempts=dropdownTrace.attempts,
        dropdownHistory=dropdownTrace.history, chat={},
    }
    local list = getPlayerListRoot()
    if list then
        local card = dropdownParts(list)
        if card then
            result.dropdownNow = {
                username=card.name and card.name.Text or nil,
                display=card.display and card.display.Text or nil,
                avatar=card.avatar and card.avatar.Image or nil,
                avatarUserId=card.avatar and thumbnailUserId(card.avatar.Image) or nil,
                usernameClass=card.name and card.name.ClassName or nil,
                displayClass=card.display and card.display.ClassName or nil,
                avatarClass=card.avatar and card.avatar.ClassName or nil,
                cardVisible=card.dropdown:IsA("GuiObject") and card.dropdown.Visible or nil,
            }
        else
            result.dropdownMissing = true
        end
    else
        result.playerListMissing = true
    end
    for prefix, details in pairs(chatLayoutObserved) do
        if prefix.Parent then
            result.chat[#result.chat+1] = details
            if #result.chat >= 8 then break end
        end
    end
    return result
end
STATE.CopyUISnapshot = function()
    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(STATE.GetUISnapshot())
    end)
    if not ok then return nil, json end
    if type(setclipboard) == "function" then pcall(setclipboard, json) end
    return json
end

-- Scoped GUI fields
local scopedOriginals = setmetatable({}, {__mode="k"})
local scopedThread
local thumbnailCache = {}
local thumbnailKinds = {
    HeadShot="AvatarHeadShot", AvatarBust="AvatarBust", AvatarThumbnail="Avatar",
}
local function thumbnailUrl(id, kind, size)
    local name = thumbnailKinds[kind]
    if not name then return nil end
    local allowed = {[60]=true,[100]=true,[150]=true,[180]=true,[352]=true,[420]=true}
    if kind == "AvatarBust" then allowed[50]=true; allowed[75]=true
    else allowed[48]=true; if kind == "AvatarThumbnail" then allowed[720]=true end end
    size = tonumber(size) or 150
    if not allowed[size] then size = 150 end
    local key = tostring(id) .. ":" .. kind .. ":" .. tostring(size)
    if not thumbnailCache[key] then
        thumbnailCache[key] = string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", name, id, size, size)
    end
    return thumbnailCache[key]
end
local function restoreScopedText()
    for obj, original in pairs(scopedOriginals) do
        pcall(function()
            if obj.Parent and obj[original.property] == original.applied then
                obj[original.property] = original.value
            end
        end)
    end
    scopedOriginals = setmetatable({}, {__mode="k"})
end
local function resolveLocalField(path, root)
    if type(path) ~= "string" then return nil end
    local base
    if root == "character" then base = player.Character
    elseif root == nil or root == "playerGui" then base = player:FindFirstChildOfClass("PlayerGui")
    else return nil end
    local current = base
    for component in path:gmatch("[^%.]+") do
        if not current then return nil end
        current = current:FindFirstChild(component)
    end
    if current and base and current:IsDescendantOf(base) then return current end
end
local function setScopedValue(obj, property, replacement)
    local current = obj[property]
    if current == replacement then return end
    local original = scopedOriginals[obj]
    if not original or current ~= original.applied then
        original = {property=property, value=current}
        scopedOriginals[obj] = original
    end
    original.applied = replacement
    obj[property] = replacement
end
local function replaceGlobally(oldName, newName, oldDisplay, newDisplay, oldId, newId, isRevert, skipWatchers)
    if isRevert then restoreScopedText() return end
    if #LOCAL_TEXT_LABEL_PATHS == 0 and #LOCAL_THUMBNAIL_FIELDS == 0 then return end
    local function refresh()
        for _, rule in ipairs(LOCAL_TEXT_LABEL_PATHS) do
            local path = type(rule) == "table" and rule.path or rule
            local root = type(rule) == "table" and rule.root or nil
            local label = resolveLocalField(path, root)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                local current = label.Text
                local replacement
                if current == oldName then replacement = newName
                elseif current == oldDisplay then replacement = newDisplay
                elseif current == "@" .. oldName then replacement = "@" .. newName end
                if replacement then setScopedValue(label, "Text", replacement) end
            end
        end
        for _, rule in ipairs(LOCAL_THUMBNAIL_FIELDS) do
            if type(rule) == "table" then
                local obj = resolveLocalField(rule.path, rule.root)
                local replacement = thumbnailUrl(newId, rule.kind or "HeadShot", rule.size)
                if obj and replacement and (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then
                    setScopedValue(obj, "Image", replacement)
                end
            end
        end
    end
    pcall(refresh)
    if not skipWatchers and not scopedThread then
        scopedThread = task.spawn(function()
            while true do task.wait(0.75); pcall(refresh) end
        end)
    end
end
local settingsPeopleConnections = {}
local settingsPeopleFieldHooks = setmetatable({}, {__mode="k"})
local settingsPeopleOriginals = setmetatable({}, {__mode="k"})
local settingsPeopleRoot
local settingsPeopleToken
local settingsPeopleQueued = false

local function getSettingsPeopleItem()
    local gui = CoreGui:FindFirstChild("RobloxGui")
    local page = gui and gui:FindFirstChild("peoplepage", true)
    return page and page:FindFirstChild("VirtualizedItem_1", true)
end

local function getSettingsPeopleFields()
    local item = getSettingsPeopleItem()
    if not item then return end
    local content = item:FindFirstChild("Item")
    content = content and content:FindFirstChild("CardContent")
    if not content then return end
    local thumbnail = content:FindFirstChild("CardThumbnail")
    thumbnail = thumbnail and thumbnail:FindFirstChild("AvatarThumbnailContainer")
    thumbnail = thumbnail and thumbnail:FindFirstChild("AvatarThumbnail")
    local details = content:FindFirstChild("CardDetails")
    local names = details and details:FindFirstChild("NameContainer")
    return names and names:FindFirstChild("Name"),
        names and names:FindFirstChild("Handle"), thumbnail
end

local refreshSettingsPeople
local function setSettingsPeopleValue(obj, prop, value)
    if not obj or obj[prop] == value then return end
    local old = settingsPeopleOriginals[obj]
    if not old or obj[prop] ~= old.applied then
        old = {property=prop, value=obj[prop]}
        settingsPeopleOriginals[obj] = old
    end
    old.applied = value
    obj[prop] = value
end

refreshSettingsPeople = function()
    if not UPDATE_SETTINGS_PEOPLE or not settingsPeopleToken then return end
    local display, handle, avatar = getSettingsPeopleFields()
    local function setField(obj, prop, desired)
        if not obj then return end
        if prop == "Text" then
            if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
        elseif not (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) then
            return
        end
        if not settingsPeopleFieldHooks[obj] then
            local writing = false
            settingsPeopleFieldHooks[obj] = obj:GetPropertyChangedSignal(prop):Connect(function()
                if writing or not settingsPeopleToken or not obj.Parent then return end
                writing = true
                if prop == "Image" then
                    local image = obj.Image
                    local replacement, count = image:gsub("([?&]id=)%d+", function(prefix)
                        return prefix .. tostring(DISGUISE_USER_ID)
                    end, 1)
                    if count == 0 then replacement = thumbnailUrl(DISGUISE_USER_ID, "AvatarThumbnail", 150) end
                    pcall(setSettingsPeopleValue, obj, prop, replacement)
                else
                    pcall(setSettingsPeopleValue, obj, prop, desired)
                end
                writing = false
            end)
        end
        pcall(setSettingsPeopleValue, obj, prop, desired)
    end
    setField(display, "Text", DISGUISE_DISPLAY)
    setField(handle, "Text", "@" .. DISGUISE_NAME)
    if avatar then
        local image = avatar.Image
        local replacement, count = image:gsub("([?&]id=)%d+", function(prefix)
            return prefix .. tostring(DISGUISE_USER_ID)
        end, 1)
        if count == 0 then replacement = thumbnailUrl(DISGUISE_USER_ID, "AvatarThumbnail", 150) end
        if replacement then setField(avatar, "Image", replacement) end
    end
end

local function stopSettingsPeopleWatcher()
    settingsPeopleToken = nil
    settingsPeopleQueued = false
    for _, conn in ipairs(settingsPeopleConnections) do pcall(function() conn:Disconnect() end) end
    table.clear(settingsPeopleConnections)
    for obj, conn in pairs(settingsPeopleFieldHooks) do pcall(function() conn:Disconnect() end) end
    for obj, old in pairs(settingsPeopleOriginals) do
        pcall(function()
            if obj.Parent and obj[old.property] == old.applied then
                obj[old.property] = old.value
            end
        end)
    end
    settingsPeopleFieldHooks = setmetatable({}, {__mode="k"})
    settingsPeopleOriginals = setmetatable({}, {__mode="k"})
    settingsPeopleRoot = nil
end

local function watchSettingsPeople()
    if not UPDATE_SETTINGS_PEOPLE then return end
    stopSettingsPeopleWatcher()
    local token = {}
    settingsPeopleToken = token
    local function queueRefresh()
        if settingsPeopleQueued or settingsPeopleToken ~= token then return end
        settingsPeopleQueued = true
        task.defer(function()
            settingsPeopleQueued = false
            if settingsPeopleToken == token then pcall(refreshSettingsPeople) end
        end)
    end
    local function attach(root)
        if not root or settingsPeopleRoot == root or settingsPeopleToken ~= token then return end
        settingsPeopleRoot = root
        settingsPeopleConnections[#settingsPeopleConnections+1] = root.DescendantAdded:Connect(function(desc)
            if desc.Name == "VirtualizedItem_1" or desc.Name == "peoplepage" then
                queueRefresh()
                task.delay(0.15, function()
                    if settingsPeopleToken == token then queueRefresh() end
                end)
            elseif desc.Name == "AvatarThumbnail" or desc.Name == "Handle" or desc.Name == "Name" then
                local item = getSettingsPeopleItem()
                if item and desc:IsDescendantOf(item) then queueRefresh() end
            end
        end)
        queueRefresh()
    end
    settingsPeopleConnections[#settingsPeopleConnections+1] = CoreGui.ChildAdded:Connect(function(obj)
        if obj.Name == "RobloxGui" then attach(obj) end
    end)
    attach(CoreGui:FindFirstChild("RobloxGui"))
end
local function clearWatchers()
    stopChatPrefixWatcher()
    if scopedThread then pcall(task.cancel, scopedThread); scopedThread = nil end
    restoreScopedText()
    stopPlayerListWatcher()
end

-- Badge compatibility
local badgeData = {active = false}

local function stopVerifiedBadgeProtection()
    badgeData.active = false
    restorePlayerListVisuals()
end

local function startVerifiedBadgeProtection(userId)
    badgeData.active = true
    if not STATE.PlayerListToken then
        watchPlayerList(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    else
        -- Refresh through the protected, scoped callback.
        if STATE.RefreshPlayerListRules then STATE.RefreshPlayerListRules() end
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

-- R15 visual rig
-- Keep original character physics; render the target rig separately.
local function stopR15Visual()
    local old = STATE.R15Visual
    if old then old.stop() end
end

local R15_SKELETON = {
        {"HumanoidRootPart", "LowerTorso", "Root"},
        {"LowerTorso", "UpperTorso", "Waist"},
        {"UpperTorso", "Head", "Neck"},
        {"UpperTorso", "LeftUpperArm", "LeftShoulder"},
        {"LeftUpperArm", "LeftLowerArm", "LeftElbow"},
        {"LeftLowerArm", "LeftHand", "LeftWrist"},
        {"UpperTorso", "RightUpperArm", "RightShoulder"},
        {"RightUpperArm", "RightLowerArm", "RightElbow"},
        {"RightLowerArm", "RightHand", "RightWrist"},
        {"LowerTorso", "LeftUpperLeg", "LeftHip"},
        {"LeftUpperLeg", "LeftLowerLeg", "LeftKnee"},
        {"LeftLowerLeg", "LeftFoot", "LeftAnkle"},
        {"LowerTorso", "RightUpperLeg", "RightHip"},
        {"RightUpperLeg", "RightLowerLeg", "RightKnee"},
        {"RightLowerLeg", "RightFoot", "RightAnkle"},
    }


local R15_SCALE_PROPERTIES = {
    HeightScale="BodyHeightScale", WidthScale="BodyWidthScale", DepthScale="BodyDepthScale",
    HeadScale="HeadScale", BodyTypeScale="BodyTypeScale", ProportionScale="BodyProportionScale",
}
local function hasScaleOverrides()
    for name, value in pairs(R15_SCALE_OVERRIDES) do
        if R15_SCALE_PROPERTIES[name] and type(value) == "number" then return true end
    end
    return false
end
local function applyScaleOverrides(desc)
    for name, value in pairs(R15_SCALE_OVERRIDES) do
        if R15_SCALE_PROPERTIES[name] and type(value) == "number" then
            pcall(function() desc[name] = value end)
        end
    end
end
local function targetPlayerNow()
    if IN_SERVER_TARGET_PLAYER and IN_SERVER_TARGET_PLAYER.Parent == Players then
        return IN_SERVER_TARGET_PLAYER
    end
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.UserId == DISGUISE_USER_ID then return other end
    end
end
local R15_BODY_NAMES = {HumanoidRootPart=true}
for _, edge in ipairs(R15_SKELETON) do R15_BODY_NAMES[edge[2]] = true end

local function validateR15Model(model)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then return false, "not a model" end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then return false, "not R15" end
    for name in pairs(R15_BODY_NAMES) do
        local part = model:FindFirstChild(name)
        if not part or not part:IsA("BasePart") then return false, "missing part " .. name end
    end
    local joints = {}
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("Motor6D") or obj:IsA("AnimationConstraint") then
            local ok, p0, p1, c0, c1 = pcall(function() return obj.Part0, obj.Part1, obj.C0, obj.C1 end)
            if ok and p0 and p1 and p0.Parent == model and p1.Parent == model
                and typeof(c0) == "CFrame" and typeof(c1) == "CFrame" then
                joints[p0.Name .. ":" .. p1.Name] = true
            end
        end
    end
    for _, edge in ipairs(R15_SKELETON) do
        if not joints[edge[1] .. ":" .. edge[2]] then
            local a = model[edge[1]]:FindFirstChild(edge[3] .. "RigAttachment")
            local b = model[edge[2]]:FindFirstChild(edge[3] .. "RigAttachment")
            if not (a and b and a:IsA("Attachment") and b:IsA("Attachment")) then
                return false, "missing joint frames " .. edge[3]
            end
        end
    end
    return true
end

local function sanitizeR15Model(model)
    for _, child in ipairs(model:GetChildren()) do
        if not ((R15_BODY_NAMES[child.Name] and child:IsA("BasePart"))
            or child:IsA("Humanoid") or child:IsA("Accessory") or child:IsA("BodyColors")
            or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")) then
            child:Destroy()
        end
    end
    local function inside(obj) return obj and obj:IsDescendantOf(model) end
    for _, obj in ipairs(model:GetDescendants()) do
        if obj.Parent then
            if obj:IsA("BaseScript") or obj:IsA("ModuleScript") or obj:IsA("Animator")
                or obj:IsA("Sound") or obj:IsA("GuiBase2d") or obj:IsA("ParticleEmitter")
                or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke")
                or obj:IsA("Sparkles") or obj:IsA("BodyMover") or obj:IsA("Tool")
                or obj:IsA("ForceField") or obj:IsA("ProximityPrompt") or obj:IsA("ClickDetector") then
                obj:Destroy()
            elseif obj:IsA("JointInstance") or obj:IsA("WeldConstraint") then
                if not (inside(obj.Part0) and inside(obj.Part1)) then obj:Destroy() end
            elseif obj:IsA("Constraint") then
                if not (obj:IsA("AnimationConstraint") or obj:IsA("RigidConstraint"))
                    or not (inside(obj.Attachment0) and inside(obj.Attachment1)) then obj:Destroy() end
            elseif obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
                pcall(function() obj.LocalTransparencyModifier = 0 end)
            end
        end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        -- Keep the generated rig from re-scaling when parented.
        hum.AutomaticScalingEnabled = false
    end
end

local function cloneLiveAppearance(targetCharacter)
    -- Temporarily enable Archivable to clone a live character.
    local previous = targetCharacter.Archivable
    local ok, model = pcall(function()
        targetCharacter.Archivable = true
        return targetCharacter:Clone()
    end)
    pcall(function() targetCharacter.Archivable = previous end)
    if not ok or not model then return nil end
    -- Clone can omit non-Archivable descendants.
    local function appearanceCounts(rig)
        local counts = {}
        for _, obj in ipairs(rig:GetDescendants()) do
            if obj:IsA("Accessory") or obj:IsA("MeshPart") or obj:IsA("SpecialMesh")
                or obj:IsA("WrapLayer") or obj:IsA("WrapTarget") or obj:IsA("SurfaceAppearance") then
                if not obj:FindFirstAncestorOfClass("Tool") then
                    local key = obj.ClassName .. ":" .. obj.Name
                    counts[key] = (counts[key] or 0) + 1
                end
            end
        end
        return counts
    end
    local expected, actual = appearanceCounts(targetCharacter), appearanceCounts(model)
    for key, count in pairs(expected) do
        if (actual[key] or 0) < count then
            model:Destroy()
            return nil
        end
    end
    return model
end

local function liveDescription(humanoid)
    local ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
    if not ok or not desc then return nil end
    -- Games can change scale NumberValues without ApplyDescription.
    for name, valueName in pairs(R15_SCALE_PROPERTIES) do
        local value = humanoid:FindFirstChild(valueName)
        if value and value:IsA("NumberValue") then
            pcall(function() desc[name] = value.Value end)
        end
    end
    return desc
end

local function acquireR15Model(presetDescription, valid)
    local function attempt(label, fn)
        if not valid() then return nil end
        local ok, candidate = pcall(fn)
        if not ok or not candidate then
            status("warning", "Ryu Disguise: R15 source unavailable [" .. label .. "]:", candidate)
            return nil
        end
        if not valid() then candidate:Destroy() return nil end
        local checked, accepted, reason = pcall(function()
            sanitizeR15Model(candidate)
            return validateR15Model(candidate)
        end)
        if not checked or not accepted then
            status("warning", "Ryu Disguise: R15 source rejected [" .. label .. "]:", reason or accepted)
            candidate:Destroy()
            return nil
        end
        return candidate, label
    end
    local function fromDescription(desc)
        applyScaleOverrides(desc)
        return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
    end
    if presetDescription then
        return attempt("preset description", function() return fromDescription(presetDescription) end)
    end
    local model, label
    local target = R15_PREFER_LIVE_APPEARANCE and targetPlayerNow() or nil
    if target then
        local deadline = os.clock() + LIVE_TARGET_TIMEOUT
        local live, hum
        while valid() and target.Parent == Players do
            live = target.Character
            hum = live and live:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local ok, loaded = pcall(function() return target:HasAppearanceLoaded() end)
                local noDefault = false
                pcall(function() noDefault = not target.CanLoadCharacterAppearance end)
                if (not ok or loaded or noDefault or os.clock() >= deadline)
                    and (hum.RigType ~= Enum.HumanoidRigType.R15 or validateR15Model(live)) then break end
            end
            if os.clock() >= deadline then break end
            game:GetService("RunService").Heartbeat:Wait()
        end
        if valid() and target.Parent == Players and live and hum and hum.Health > 0 and target.Character == live then
            if not hasScaleOverrides() and hum.RigType == Enum.HumanoidRigType.R15 and validateR15Model(live) then
                model, label = attempt("live replicated rig", function() return cloneLiveAppearance(live) end)
                if model then return model, label end
            end
            model, label = attempt("live applied description + scales", function()
                local desc = liveDescription(hum)
                if not desc then return nil end
                local ok, result = pcall(fromDescription, desc)
                desc:Destroy()
                if not ok then error(result) end
                return result
            end)
            if model then return model, label end
        end
    end
    if not hasScaleOverrides() then
        model, label = attempt("public avatar model", function()
            return Players:CreateHumanoidModelFromUserIdAsync(DISGUISE_USER_ID)
        end)
        if model then return model, label end
    end
    return attempt("public description forced to R15", function()
        local desc = Players:GetHumanoidDescriptionFromUserIdAsync(DISGUISE_USER_ID)
        local ok, result = pcall(fromDescription, desc)
        desc:Destroy()
        if not ok then error(result) end
        return result
    end)
end

local avatarCache = {epoch=0, running=false, closed=false}
local function invalidateAvatarCache(close)
    avatarCache.epoch += 1
    avatarCache.running = false
    avatarCache.closed = close == true
    if avatarCache.model then avatarCache.model:Destroy() end
    avatarCache.model = nil
    avatarCache.label = nil
    avatarCache.targetCharacter = nil
    avatarCache.expires = nil
    avatarCache.failedAt = nil
end
local function newPresetDescription()
    if not USE_PRESET then return nil end
    local preset = getSelectedPreset()
    if not preset then return nil end
    local desc = Instance.new("HumanoidDescription")
    for k, v in pairs(preset) do pcall(function() desc[k] = v end) end
    return desc
end
local function cacheTargetCharacter()
    if USE_PRESET or not R15_PREFER_LIVE_APPEARANCE then return nil end
    local target = targetPlayerNow()
    return target and target.Character or nil
end
local function prepareR15Cache()
    if not CACHE_TARGET_AVATAR or avatarCache.closed then return end
    local targetCharacter = cacheTargetCharacter()
    if avatarCache.model and (avatarCache.targetCharacter ~= targetCharacter or os.clock() >= avatarCache.expires) then
        invalidateAvatarCache(false)
    end
    if avatarCache.running or avatarCache.model then return end
    if avatarCache.failedAt and os.clock() - avatarCache.failedAt < 3 then return end
    avatarCache.running = true
    local epoch = avatarCache.epoch
    local function valid() return not avatarCache.closed and avatarCache.epoch == epoch end
    task.spawn(function()
        local desc = newPresetDescription()
        local ok, model, label = pcall(acquireR15Model, desc, valid)
        if desc then desc:Destroy() end
        if not valid() then
            if ok and model then model:Destroy() end
            return
        end
        avatarCache.running = false
        if ok and model then
            model.Archivable = true
            avatarCache.model = model
            avatarCache.label = label
            avatarCache.targetCharacter = targetCharacter
            avatarCache.expires = os.clock() + AVATAR_CACHE_SECONDS
        else
            avatarCache.failedAt = os.clock()
        end
    end)
end
local function getPreparedR15Model(description, valid)
    if not CACHE_TARGET_AVATAR then return acquireR15Model(description, valid) end
    prepareR15Cache()
    local deadline = os.clock() + AVATAR_PREPARE_TIMEOUT
    local warned = false
    while valid() and avatarCache.running do
        if not warned and os.clock() >= deadline then
            warned = true
            status("info", "Avatar request still pending; original character remains visible")
        end
        game:GetService("RunService").Heartbeat:Wait()
    end
    if not valid() then return nil end
    if avatarCache.model then
        local ok, clone = pcall(function() return avatarCache.model:Clone() end)
        if ok and clone then
            local checked, accepted = pcall(validateR15Model, clone)
            if checked and accepted then return clone, avatarCache.label .. " (cached template)" end
            clone:Destroy()
        end
        invalidateAvatarCache(false)
    end
    if avatarCache.failedAt then return nil end
    return acquireR15Model(description, valid)
end

local function preloadR15Model(model, valid)
    return valid() -- No explicit preloading; use native asset streaming.
end

local function applyAppearanceR15(character, description, isDisguise, generation)
    if not isDisguise then stopR15Visual() return true end
    local run = game:GetService("RunService")
    local sourceHum = character:FindFirstChildOfClass("Humanoid")
    local sourceRoot = character:FindFirstChild("HumanoidRootPart")
    if not sourceHum or not sourceRoot then return false end
    local function valid()
        return player.Character == character and character.Parent ~= nil
            and STATE.AvatarGeneration == generation and sourceHum.Health > 0
    end
    if not valid() then return false end

    local model, sourceLabel = getPreparedR15Model(description, valid)
    if not model then
        if valid() then status("warning", "Ryu Disguise: all R15 appearance sources failed") end
        return false
    end
    if not preloadR15Model(model, valid) then model:Destroy() return false end
    status("info", "Ryu Disguise: R15 appearance source:", sourceLabel)
    local visualHum = model:FindFirstChildOfClass("Humanoid")
    local visualRoot = model:FindFirstChild("HumanoidRootPart")
    if not visualHum or not visualRoot then model:Destroy() return false end

    local function jointMap(rig)
        local map = {}
        for _, obj in ipairs(rig:GetDescendants()) do
            if obj:IsA("Motor6D") or obj:IsA("AnimationConstraint") then
                local success, p0, p1 = pcall(function() return obj.Part0, obj.Part1 end)
                if success and p0 and p1 then
                    map[p0.Name .. ":" .. p1.Name] = obj
                end
            end
        end
        return map
    end
    local function frames(map, p0, p1, jointName)
        local j = map[p0.Name .. ":" .. p1.Name]
        if j then
            local success, c0, c1 = pcall(function() return j.C0, j.C1 end)
            if success and typeof(c0) == "CFrame" and typeof(c1) == "CFrame" then
                return c0, c1, j
            end
        end
        local key = jointName .. "RigAttachment"
        local a0, a1 = p0:FindFirstChild(key), p1:FindFirstChild(key)
        if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
            return a0.CFrame, a1.CFrame, nil
        end
        return nil
    end
    local sourceJoints, visualJoints = jointMap(character), jointMap(model)
    local pairsByJoint, body = {}, {[visualRoot] = true}
    for _, edge in ipairs(R15_SKELETON) do
        local sp0, sp1 = character:FindFirstChild(edge[1]), character:FindFirstChild(edge[2])
        local vp0, vp1 = model:FindFirstChild(edge[1]), model:FindFirstChild(edge[2])
        if not (sp0 and sp1 and vp0 and vp1 and sp0:IsA("BasePart") and sp1:IsA("BasePart")
                and vp0:IsA("BasePart") and vp1:IsA("BasePart")) then
            model:Destroy()
            status("warning", "Ryu Disguise: incomplete R15 skeleton at", edge[2])
            return false
        end
        local sc0, sc1, sj = frames(sourceJoints, sp0, sp1, edge[3])
        local vc0, vc1 = frames(visualJoints, vp0, vp1, edge[3])
        if not (sc0 and sc1 and vc0 and vc1) then
            model:Destroy()
            status("warning", "Ryu Disguise: missing R15 joint frames at", edge[3])
            return false
        end
        body[vp1] = true
        pairsByJoint[#pairsByJoint + 1] = {
            sp0=sp0, sp1=sp1, vp0=vp0, vp1=vp1,
            sc0=sc0, sc1=sc1, sj=sj, vc0=vc0, vc1=vc1,
            jointName=edge[3],
        }
    end

    -- Hide only visuals, not physics or gameplay components.
    local hidden = {}
    local visible = {}
    local originalBody = {[sourceRoot] = true}
    for _, j in ipairs(pairsByJoint) do originalBody[j.sp1] = true end
    local function isAvatarSurface(obj)
        if obj:FindFirstAncestorOfClass("Tool") then return false end
        if originalBody[obj] then return true end
        if obj:FindFirstAncestorOfClass("Accessory") then return true end
        if obj:IsA("Decal") or obj:IsA("Texture") then
            return originalBody[obj.Parent] == true
        end
        return false
    end
    local function hideOriginal(obj)
        if not isAvatarSurface(obj) then return end
        if not (obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture")) then return end
        if hidden[obj] == nil then
            local success, value = pcall(function() return obj.LocalTransparencyModifier end)
            if not success then return end
            hidden[obj] = value
        end
        pcall(function() obj.LocalTransparencyModifier = 1 end)
    end

    model.Name = "RyuR15Visual"
    model:SetAttribute("RyuLocalVisual", true)
    -- Disable proxy humanoid simulation before parenting.
    visualHum.EvaluateStateMachine = false
    visualHum.AutoRotate = false
    local proxyParts = {}
    local function enforceProxyPart(part)
        if not part:IsDescendantOf(model) then return end
        if part.CanCollide then part.CanCollide = false end
        if part.CanTouch then part.CanTouch = false end
        if part.CanQuery then part.CanQuery = false end
        if not part.Massless then part.Massless = true end
        if body[part] and not part.Anchored then part.Anchored = true end
    end
    local function enforceProxyPhysics()
        if visualHum.Parent and visualHum.EvaluateStateMachine then
            visualHum.EvaluateStateMachine = false
        end
        for part in pairs(proxyParts) do
            if part:IsDescendantOf(model) then
                enforceProxyPart(part)
            else
                proxyParts[part] = nil
            end
        end
    end
    -- Keep accessory welds; discard duplicate body joints.
    for _, obj in ipairs(model:GetDescendants()) do
        local p0, p1
        if obj:IsA("JointInstance") or obj:IsA("WeldConstraint") then
            p0, p1 = obj.Part0, obj.Part1
        elseif obj:IsA("AnimationConstraint") or obj:IsA("RigidConstraint") then
            local a0, a1 = obj.Attachment0, obj.Attachment1
            p0, p1 = a0 and a0.Parent, a1 and a1.Parent
        end
        if p0 and p1 and body[p0] and body[p1] then obj:Destroy() end
    end
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("BaseScript") or obj:IsA("Animator") then
            obj:Destroy()
        elseif obj:IsA("BasePart") then
            proxyParts[obj] = true
            enforceProxyPart(obj)
            obj.Anchored = body[obj] == true
            visible[#visible + 1] = obj
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            visible[#visible + 1] = obj
        end
    end
    visualHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    visualHum.AutoRotate = false
    pcall(function() visualHum.EvaluateStateMachine = false end)
    visualHum.BreakJointsOnDeath = false
    visualRoot.Transparency = 1
    local visualHead = model:FindFirstChild("Head")
    if FACELESS and visualHead then
        for _, obj in ipairs(visualHead:GetChildren()) do
            if obj:IsA("Decal") and (obj.Name:lower() == "face" or obj.Name:lower() == "facegraphic") then
                obj.Transparency = 1
            end
        end
        if HEADLESS then visualHead.Transparency = 1 end
    end

    stopR15Visual()
    local session = {model=model, character=character, generation=generation, appearanceSource=sourceLabel}
    local connections = {}
    local bindName = "RyuR15Visual_" .. tostring(generation)
    local stopped = false
    function session.stop()
        if stopped then return end
        stopped = true
        pcall(function() run:UnbindFromRenderStep(bindName) end)
        for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
        for obj, value in pairs(hidden) do
            pcall(function() obj.LocalTransparencyModifier = value end)
        end
        table.clear(hidden)
        model:Destroy()
        if STATE.R15Visual == session then STATE.R15Visual = nil end
    end
    STATE.R15Visual = session

    local function pose()
        if not valid() or not model.Parent or not sourceRoot.Parent then session.stop() return end
        local heightOffset = 0
        if R15_ALIGN_FEET and not sourceHum.Sit then
            heightOffset = visualHum.HipHeight + visualRoot.Size.Y * 0.5
                - sourceHum.HipHeight - sourceRoot.Size.Y * 0.5
        end
        visualRoot.CFrame = sourceRoot.CFrame + Vector3.new(0, heightOffset, 0)
        for _, j in ipairs(pairsByJoint) do
            -- Copy evaluated poses so custom animations work too.
            local sc0, sc1 = j.sc0, j.sc1
            if j.sj and j.sj.Parent then
                local success, a, b = pcall(function() return j.sj.C0, j.sj.C1 end)
                if success then sc0, sc1 = a, b end
            else
                local a, b = frames(sourceJoints, j.sp0, j.sp1, j.jointName)
                if a and b then sc0, sc1 = a, b end
            end
            local delta = sc0:Inverse() * j.sp0.CFrame:ToObjectSpace(j.sp1.CFrame) * sc1
            -- Preserve target limb translations; transfer rotation only.
            j.vp1.CFrame = j.vp0.CFrame * j.vc0 * delta.Rotation * j.vc1:Inverse()
        end
        for obj in pairs(hidden) do
            if obj.Parent then
                if obj.LocalTransparencyModifier ~= 1 then obj.LocalTransparencyModifier = 1 end
            else hidden[obj] = nil end
        end
        local fade = 0
        local camera = workspace.CurrentCamera
        local sourceHead = character:FindFirstChild("Head")
        if R15_FIRST_PERSON_FADE and camera and sourceHead
            and (camera.CameraSubject == sourceHum or camera.CameraSubject == sourceHead) then
            local distance = (camera.CFrame.Position - sourceHead.Position).Magnitude
            fade = math.clamp((1.5 - distance) / 0.8, 0, 1)
        end
        for _, obj in ipairs(visible) do
            if obj.Parent then pcall(function()
                if obj.LocalTransparencyModifier ~= fade then obj.LocalTransparencyModifier = fade end
            end) end
        end
    end
    local success, err = pcall(function()
        -- Roblox may restore torso collisions after parenting.
        connections[#connections + 1] = model.DescendantAdded:Connect(function(obj)
            if stopped or not obj:IsA("BasePart") then return end
            proxyParts[obj] = true
            enforceProxyPart(obj)
        end)
        model.Parent = workspace
        enforceProxyPhysics()
        connections[#connections + 1] = run.PreSimulation:Connect(function()
            if stopped then return end
            if not valid() or not model.Parent then session.stop() return end
            local ok, reason = pcall(enforceProxyPhysics)
            if not ok then
                status("warning", "Ryu Disguise: visual collision guard stopped:", reason)
                session.stop()
            end
        end)
        pose() -- complete initial pose before hiding the original
        if stopped then return end
        for _, obj in ipairs(character:GetDescendants()) do hideOriginal(obj) end
        connections[#connections + 1] = character.DescendantAdded:Connect(function(obj)
            if not stopped then hideOriginal(obj) end
        end)
        connections[#connections + 1] = sourceHum.Died:Connect(session.stop)
        connections[#connections + 1] = character.AncestryChanged:Connect(function(_, parent)
            if not parent then session.stop() end
        end)
        run:BindToRenderStep(bindName, Enum.RenderPriority.Character.Value + 1, function()
            local worked, reason = pcall(pose)
            if not worked then
                status("warning", "Ryu Disguise: R15 pose stopped:", reason)
                session.stop()
            end
        end)
    end)
    if not success then
        session.stop()
        status("warning", "Ryu Disguise: R15 setup failed:", err)
        return false
    end
    return not stopped
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
    for _, acc in character:GetChildren() do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
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

    for _, child in tempChar:GetChildren() do
        if child:IsA("CharacterMesh") then
            local clone = child:Clone()
            if isDisguise then clone:SetAttribute("Disguise", true) end
            clone.Parent = character
        end
    end
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
local function applyAppearance(character, description, isDisguise, generation)
    if isR15(character) then return applyAppearanceR15(character, description, isDisguise, generation) end
    applyAppearanceR6(character, description, isDisguise)
    return true
end

-- ========== DISGUISE / REVERT WRAPPERS ==========
-- CharacterAppearanceLoaded is server-only; use local readiness checks.
STATE.AvatarGeneration = STATE.AvatarGeneration or 0

local function currentSpawn(character, generation)
    -- CharacterAdded may fire before the model enters Workspace.
    return STATE.AvatarGeneration == generation
       and player.Character == character
end

local function waitForClientAppearance(character, generation)
    local started = os.clock()
    local appearanceStarted
    local warned = false
    while currentSpawn(character, generation) do
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")
        local root = character:FindFirstChild("HumanoidRootPart")
        local ready = humanoid and head and root and character.Parent
        if ready and humanoid.RigType == Enum.HumanoidRigType.R15 then
            for _, name in ipairs({"LowerTorso", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}) do
                if not character:FindFirstChild(name) then ready = false break end
            end
        end
        if ready then
            if humanoid.RigType == Enum.HumanoidRigType.R15 then return humanoid end
            appearanceStarted = appearanceStarted or os.clock()
            local ok, loaded = pcall(function() return player:HasAppearanceLoaded() end)
            local skipDefault = false
            pcall(function() skipDefault = player.CanLoadCharacterAppearance == false end)
            if (ok and loaded) or skipDefault then
                return humanoid
            end
            if not ok and not warned then
                warned = true
                status("warning", "Ryu Disguise: HasAppearanceLoaded unavailable; falling back to rig-ready check")
                return humanoid
            end
            if os.clock() - appearanceStarted >= APPEARANCE_READY_TIMEOUT then
                status("warning", "Ryu Disguise: appearance readiness timeout; applying to ready rig with late-asset protection")
                return humanoid
            end
        end
        if not ready and os.clock() - started >= RIG_READY_TIMEOUT then
            status("warning", "Ryu Disguise: character rig readiness timed out")
            return nil
        end
        game:GetService("RunService").Heartbeat:Wait()
    end
    return nil
end

local function protectFromLateOriginalAssets(character, generation)
    if not WATCH_LATE_APPEARANCE then return end
    local function isNativeAppearance(obj)
        return obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants")
            or obj:IsA("ShirtGraphic") or obj:IsA("BodyColors")
            or obj:IsA("CharacterMesh")
    end
    track(character.ChildAdded:Connect(function(child)
        if not currentSpawn(character, generation) then return end
        if not STATE.AppliedAvatar or STATE.AppliedAvatar.character ~= character then return end
        if os.clock() - STATE.AppliedAvatar.appliedAt > LATE_ASSET_WINDOW_SECONDS then return end
        if not isNativeAppearance(child) or child:GetAttribute("Disguise") then return end
        task.defer(function()
            if currentSpawn(character, generation) and child.Parent == character
               and child:GetAttribute("Disguise") ~= true then
                pcall(function() child:Destroy() end)
            end
        end)
    end))
    local head = character:FindFirstChild("Head")
    if head and FACELESS then
        track(head.ChildAdded:Connect(function(child)
            if not currentSpawn(character, generation) then return end
            if child:IsA("Decal") and (child.Name:lower() == "face" or child.Name:lower() == "facegraphic") then
                child.Transparency = 1
            end
        end))
    end
end

local function applyAvatarDisguise(character, generation)
    local humanoid = waitForClientAppearance(character, generation)
    if not humanoid or not currentSpawn(character, generation) then return end
    local desc
    if USE_PRESET then
        local preset = getSelectedPreset()
        if preset then
            desc = Instance.new("HumanoidDescription")
            for k, v in pairs(preset) do pcall(function() desc[k] = v end) end
        end
    end
    local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
    if not r15 then
        if not desc then
            local ok, result = pcall(function()
                return Players:GetHumanoidDescriptionFromUserIdAsync(DISGUISE_USER_ID)
            end)
            if not ok or not result then
                status("warning", "Ryu Disguise: cannot fetch appearance from target:", result)
                return
            end
            desc = result
        end
        local hd = ensureHumanoidDescription(humanoid)
        pcall(function() desc.HeightScale = hd.HeightScale end)
    end
    if not currentSpawn(character, generation) then
        if desc then desc:Destroy() end
        return
    end
    local ok, result = pcall(applyAppearance, character, desc, true, generation)
    if desc then desc:Destroy() end
    if not ok then status("warning", "Ryu Disguise: appearance failed:", result) return end
    if not result or not currentSpawn(character, generation) then return end
    STATE.AppliedAvatar = {character=character, generation=generation, appliedAt=os.clock()}
    if r15 then return end
    local originalAssetClasses = {
        Accessory=true, Shirt=true, Pants=true, ShirtGraphic=true,
        BodyColors=true, CharacterMesh=true,
    }
    for _, child in ipairs(character:GetChildren()) do
        if originalAssetClasses[child.ClassName] and child:GetAttribute("Disguise") ~= true then
            pcall(function() child:Destroy() end)
        end
    end
    protectFromLateOriginalAssets(character, generation)
end

local function scheduleAvatarDisguise(character)
    stopR15Visual()
    STATE.AvatarGeneration += 1
    local generation = STATE.AvatarGeneration
    STATE.AppliedAvatar = nil
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.RigType == Enum.HumanoidRigType.R15 then prepareR15Cache() end
    task.spawn(function()
        local ok, err = pcall(applyAvatarDisguise, character, generation)
        if not ok then status("warning", "Ryu Disguise: avatar task failed:", err) end
    end)
end

local function revertAvatar()
    STATE.AvatarGeneration += 1
    STATE.AppliedAvatar = nil
    stopR15Visual()
    local character = player.Character
    if not character or isR15(character) then return end
    local originalDesc = ORIG.Desc
    if not originalDesc then status("warning", "No original description stored") return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local hd = ensureHumanoidDescription(humanoid)
        pcall(function() originalDesc.HeightScale = hd.HeightScale end)
    end
    applyAppearance(character, originalDesc, false)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") and child:GetAttribute("Disguise") then child:Destroy() end
    end
end

-- ========== REVERT IDENTITY ==========
local function revertIdentity()
    clearWatchers()
    stopSettingsPeopleWatcher()
    stopPlayerListWatcher()
    
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
-- ========== MAIN EXECUTION ==========
if QUIT then
    if getgenv().Ryu_Disguise and getgenv().Ryu_Disguise.cleanup then
        pcall(getgenv().Ryu_Disguise.cleanup)
        getgenv().Ryu_Disguise.cleanup = nil
    end
    status("info", "🔄 Reverting all changes...")
    revertIdentity()
    revertAvatar()
    clearWatchers()
    stopSettingsPeopleWatcher()
    stopPlayerListWatcher()
    stopVerifiedBadgeProtection()
    if SHOW_BADGE_ON_REVERT then
        pcall(replacePlayerList, ORIG.Name, ORIG.Name, ORIG.DisplayName, ORIG.DisplayName, ORIG.UserId, ORIG.UserId, true)
    end
    getgenv().Ryu_Disguise.Active = false
    getgenv().Ryu_Disguise.Disguised = nil
    status("info", "✅ Revert complete.")
    return
end

-- MODE 4 & 5: GUI text replacement + nametag spoof (no game.Players changes)
if MODE == 4 or MODE == 5 then
    status("info", "✅ GUI text replacement active")
    replaceGlobally(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    watchPlayerList(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    if FORCE_VERIFIED or MATCH_DISGUISED_ACCOUNT_BADGE then startVerifiedBadgeProtection(DISGUISE_USER_ID) end
    
    local function onGuiChar(char)
        local h = char:WaitForChild("Humanoid", 8)
            if h and SPOOF_HUMANOID_NAMETAG then
        pcall(function() h.DisplayName = DISGUISE_DISPLAY or DISGUISE_NAME end)
    end
    end
    if player.Character then onGuiChar(player.Character) end
    track(player.CharacterAdded:Connect(onGuiChar))
end

if MODE == 1 or MODE == 2 then
    status("info", "Local presentation mode")
    replaceGlobally(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    watchPlayerList(ORIG.Name, DISGUISE_NAME, ORIG.DisplayName, DISGUISE_DISPLAY, ORIG.UserId, DISGUISE_USER_ID)
    if FORCE_VERIFIED or MATCH_DISGUISED_ACCOUNT_BADGE then startVerifiedBadgeProtection(DISGUISE_USER_ID) end
end

if MODE == 1 or MODE == 2 or MODE == 4 or MODE == 5 then
    watchChatPrefixes()
    watchSettingsPeople()
end

-- MODE 1/3/5: Avatar spoof
if MODE == 1 or MODE == 3 or MODE == 5 then
    if not player.Character then prepareR15Cache() end
    track(player.CharacterAdded:Connect(scheduleAvatarDisguise))
    if player.Character then scheduleAvatarDisguise(player.Character) end
end

-- Nametag spoof for modes 1, 2 (modes 4/5 handled above, mode 3 has no nametag spoof)
if MODE == 1 or MODE == 2 then
    local function spoofNametag(character)
    local humanoid = character:WaitForChild("Humanoid", 8)
        if humanoid and SPOOF_HUMANOID_NAMETAG then
            if ORIG.HumanoidDisplayName == nil then ORIG.HumanoidDisplayName = humanoid.DisplayName end
            pcall(function() humanoid.DisplayName = DISGUISE_DISPLAY or DISGUISE_NAME end)
        end
    end
    if player.Character then spoofNametag(player.Character) end
    track(player.CharacterAdded:Connect(spoofNametag))
end

-- Hide root part for all modes except pure GUI-only (mode 4)
if player.Character and MODE ~= 4 and not isR15(player.Character) then
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then rootPart.Transparency = 1 end
end

-- Store active state and cleanup
getgenv().Ryu_Disguise.Active = true
getgenv().Ryu_Disguise.cleanup = function()
    stopStatus()
    invalidateAvatarCache(true)
    if STATE.IntroCleanup then pcall(STATE.IntroCleanup) end
    stopR15Visual()
    STATE.AvatarGeneration += 1
    STATE.AppliedAvatar = nil
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
    if SHOW_BADGE_ON_REVERT then
        pcall(replacePlayerList, ORIG.Name, ORIG.Name, ORIG.DisplayName, ORIG.DisplayName, ORIG.UserId, ORIG.UserId, true)
    end
    getgenv().Ryu_Disguise.Active = false
    getgenv().Ryu_Disguise.Disguised = nil
end

-- Tesseract intro
-- Screen-space 4D projection, with no external assets or audio.
local function startTesseractIntro()
    if STATE.IntroCleanup then pcall(STATE.IntroCleanup) end
    local GUI_NAME = "RyuTesseractIntro"
    for _, parent in ipairs({player:FindFirstChildOfClass("PlayerGui")}) do
        if parent then
            local old = parent:FindFirstChild(GUI_NAME)
            if old then pcall(function() old:Destroy() end) end
        end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 10000
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then gui:Destroy() return end
    gui.Parent = pg

    local panel = Instance.new("Frame")
    panel.Name = "CenterOverlay"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0.9, 0, 0, 230)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = false
    panel.Parent = gui
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(620, 230)
    constraint.MinSize = Vector2.new(220, 180)
    constraint.Parent = panel

    local title = Instance.new("TextLabel")
    title.Name = "FinalTitle"
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.5)
    title.Size = UDim2.new(1, -10, 0, 58)
    title.BackgroundTransparency = 1
    title.Text = INTRO_TITLE
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(234, 247, 255)
    title.TextStrokeColor3 = Color3.fromRGB(7, 16, 25)
    title.TextStrokeTransparency = 0.85
    title.TextTransparency = 1
    title.ZIndex = 50
    title.Parent = panel
    local titleConstraint = Instance.new("UITextSizeConstraint")
    titleConstraint.MaxTextSize = 39
    titleConstraint.Parent = title

    local caption = Instance.new("TextLabel")
    caption.Name = "TargetCaption"
    caption.AnchorPoint = Vector2.new(0.5, 0.5)
    caption.Position = UDim2.new(0.5, 0, 0.5, 49)
    caption.Size = UDim2.new(1, -12, 0, 22)
    caption.BackgroundTransparency = 1
    caption.Font = Enum.Font.Code
    caption.Text = INTRO_SHOW_TARGET and ("TARGET  /  " .. tostring(DISGUISE_DISPLAY)) or ""
    caption.TextSize = 13
    caption.TextColor3 = Color3.fromRGB(115, 200, 252)
    caption.TextTransparency = 1
    caption.ZIndex = 51
    caption.Parent = panel

    local font = {
        A={{0,1,0,0.15},{0,0.15,0.4,0},{0.4,0,0.8,0.15},{0.8,0.15,0.8,1},{0,0.55,0.8,0.55}},
        B={{0,0,0,1},{0,0,0.75,0},{0.75,0,0.85,0.18},{0.85,0.18,0.75,0.45},{0.75,0.45,0,0.45},{0.75,0.45,0.85,0.75},{0.85,0.75,0.75,1},{0.75,1,0,1}},
        C={{0.85,0.1,0.7,0},{0.7,0,0.1,0},{0.1,0,0,0.12},{0,0.12,0,0.88},{0,0.88,0.1,1},{0.1,1,0.7,1},{0.7,1,0.85,0.9}},
        D={{0,0,0,1},{0,0,0.55,0},{0.55,0,0.9,0.26},{0.9,0.26,0.9,0.75},{0.9,0.75,0.55,1},{0.55,1,0,1}},
        E={{0.85,0,0,0},{0,0,0,1},{0,0.5,0.7,0.5},{0,1,0.85,1}},
        F={{0,0,0,1},{0,0,0.85,0},{0,0.5,0.68,0.5}},
        G={{0.85,0.15,0.7,0},{0.7,0,0.1,0},{0.1,0,0,0.15},{0,0.15,0,0.85},{0,0.85,0.1,1},{0.1,1,0.75,1},{0.75,1,0.85,0.75},{0.85,0.75,0.85,0.52},{0.85,0.52,0.45,0.52}},
        H={{0,0,0,1},{0.85,0,0.85,1},{0,0.5,0.85,0.5}},
        I={{0,0,0.8,0},{0.4,0,0.4,1},{0,1,0.8,1}},
        J={{0.8,0,0.8,0.88},{0.8,0.88,0.65,1},{0.65,1,0.1,1},{0.1,1,0,0.85}},
        K={{0,0,0,1},{0.85,0,0,0.55},{0,0.55,0.85,1}},
        L={{0,0,0,1},{0,1,0.85,1}},
        M={{0,1,0,0},{0,0,0.45,0.5},{0.45,0.5,0.9,0},{0.9,0,0.9,1}},
        N={{0,1,0,0},{0,0,0.85,1},{0.85,1,0.85,0}},
        O={{0.1,0,0.75,0},{0.75,0,0.85,0.12},{0.85,0.12,0.85,0.88},{0.85,0.88,0.75,1},{0.75,1,0.1,1},{0.1,1,0,0.88},{0,0.88,0,0.12},{0,0.12,0.1,0}},
        P={{0,1,0,0},{0,0,0.75,0},{0.75,0,0.85,0.15},{0.85,0.15,0.85,0.45},{0.85,0.45,0,0.45}},
        Q={{0,0.1,0.1,0},{0.1,0,0.7,0},{0.7,0,0.85,0.1},{0.85,0.1,0.85,0.87},{0.85,0.87,0.7,1},{0.7,1,0.1,1},{0.1,1,0,0.87},{0,0.87,0,0.1},{0.5,0.65,0.95,1.08}},
        R={{0,1,0,0},{0,0,0.75,0},{0.75,0,0.85,0.17},{0.85,0.17,0.8,0.43},{0.8,0.43,0,0.43},{0,0.43,0.87,1}},
        S={{0.85,0.1,0.72,0},{0.72,0,0.1,0},{0.1,0,0,0.17},{0,0.17,0.75,0.52},{0.75,0.52,0.85,0.8},{0.85,0.8,0.72,1},{0.72,1,0.1,1},{0.1,1,0,0.9}},
        T={{0,0,0.9,0},{0.45,0,0.45,1}},
        U={{0,0,0,0.84},{0,0.84,0.14,1},{0.14,1,0.7,1},{0.7,1,0.85,0.84},{0.85,0.84,0.85,0}},
        V={{0,0,0.43,1},{0.43,1,0.85,0}},
        W={{0,0,0.18,1},{0.18,1,0.45,0.5},{0.45,0.5,0.72,1},{0.72,1,0.9,0}},
        X={{0,0,0.85,1},{0.85,0,0,1}},
        Y={{0,0,0.42,0.5},{0.85,0,0.42,0.5},{0.42,0.5,0.42,1}},
        Z={{0,0,0.85,0},{0.85,0,0,1},{0,1,0.85,1}},
    }
    local rawGlyphs = {}
    local cursor = 0
    local titleString = tostring(INTRO_TITLE):upper()
    for i=1,#titleString do
        local letter = titleString:sub(i,i)
        local segments = font[letter]
        if segments then
            for _, seg in ipairs(segments) do
                rawGlyphs[#rawGlyphs+1] = {cursor + seg[1], seg[2], cursor + seg[3], seg[4]}
            end
            cursor += 1.14
        elseif letter == " " then
            cursor += 0.66
        else
            cursor += 1.14
        end
    end
    if #rawGlyphs == 0 then rawGlyphs = {{0,0,1,1}} cursor = 1 end

    local vertices = {}
    for a=-1,1,2 do
        for b=-1,1,2 do
            for c=-1,1,2 do
                for d=-1,1,2 do
                    vertices[#vertices+1] = {a,b,c,d}
                end
            end
        end
    end
    local edges = {}
    for i=1,16 do
        for j=i+1,16 do
            local differences = 0
            for k=1,4 do
                if vertices[i][k] ~= vertices[j][k] then differences += 1 end
            end
            if differences == 1 then edges[#edges+1] = {i,j} end
        end
    end
    local lineCount = math.max(#edges, #rawGlyphs)
    local lines = {}
    for i=1,lineCount do
        local line = Instance.new("Frame")
        line.Name = "WireStroke_" .. i
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Size = UDim2.fromOffset(1,2)
        line.BackgroundTransparency = 1
        line.BackgroundColor3 = Color3.fromRGB(111,212,255)
        line.BorderSizePixel = 0
        line.ZIndex = 40
        line.Parent = panel
        lines[i] = line
    end
    local dots = {}
    for i=1,16 do
        local dot = Instance.new("Frame")
        dot.Name = "Vertex_" .. i
        dot.AnchorPoint = Vector2.new(0.5,0.5)
        dot.Size = UDim2.fromOffset(4,4)
        dot.BackgroundColor3 = Color3.fromRGB(219,245,255)
        dot.BackgroundTransparency = 1
        dot.BorderSizePixel = 0
        dot.ZIndex = 41
        dot.Parent = panel
        dots[i] = dot
    end

    local function smoothstep(x)
        x = math.clamp(x, 0, 1)
        return x*x*(3-2*x)
    end
    local function project4(vertex, elapsed, scale)
        local x,y,z,w = vertex[1],vertex[2],vertex[3],vertex[4]
        local function rotate(a,b,angle)
            local sine, cosine = math.sin(angle), math.cos(angle)
            return a*cosine-b*sine, a*sine+b*cosine
        end
        x,w = rotate(x,w,elapsed*1.65+0.23)
        y,w = rotate(y,w,elapsed*1.08+0.52)
        z,w = rotate(z,w,elapsed*0.71)
        x,y = rotate(x,y,elapsed*0.39)
        local perspective4 = 3.4/(3.4-w)
        x,y,z = x*perspective4,y*perspective4,z*perspective4
        local perspective3 = 4.4/(4.4-z)
        return x*perspective3*scale, y*perspective3*scale
    end
    local function drawSegment(line, x1,y1,x2,y2,thickness,opacity,color)
        local dx,dy = x2-x1,y2-y1
        line.Position = UDim2.fromOffset((x1+x2)*0.5, (y1+y2)*0.5)
        line.Size = UDim2.fromOffset(math.max(0.1, math.sqrt(dx*dx+dy*dy)), thickness)
        line.Rotation = math.deg(math.atan2(dy,dx))
        line.BackgroundTransparency = 1-math.clamp(opacity,0,1)
        line.BackgroundColor3 = color
    end
    local started = os.clock()
    local runService = game:GetService("RunService")
    local connection
    local running = true
    local function stop()
        if not running then return end
        running = false
        if connection then connection:Disconnect() connection = nil end
        if gui then pcall(function() gui:Destroy() end) end
        if STATE.IntroCleanup == stop then STATE.IntroCleanup = nil end
    end
    STATE.IntroCleanup = stop
    connection = runService.RenderStepped:Connect(function()
        if not running or not gui.Parent then stop() return end
        local elapsed = os.clock() - started
        if elapsed >= 3.85 then stop() return end
        local size = panel.AbsoluteSize
        if size.X < 30 then return end
        local centerX, centerY = size.X*0.5, size.Y*0.5
        local outerScale = math.min(47, size.X*0.16, size.Y*0.32)
        local letterScale = math.min(34, (size.X-24)/math.max(1,cursor))
        local appear = smoothstep((elapsed-0.02)/0.4)
        local unfold = smoothstep((elapsed-1.45)/0.95)
        local fadeWire = 1-smoothstep((elapsed-2.75)/0.66)
        local currentVertices = {}
        for i=1,#vertices do
            local vx, vy = project4(vertices[i], elapsed, outerScale)
            currentVertices[i] = {centerX+vx, centerY+vy}
            dots[i].Position = UDim2.fromOffset(centerX+vx, centerY+vy)
            dots[i].BackgroundTransparency = 1-appear*(1-unfold)*0.86
        end
        for i=1,lineCount do
            local edge = edges[((i-1)%#edges)+1]
            local fromA,fromB = currentVertices[edge[1]], currentVertices[edge[2]]
            local glyph = rawGlyphs[((i-1)%#rawGlyphs)+1]
            local gx1 = centerX + (glyph[1]-cursor*0.5)*letterScale
            local gy1 = centerY + (glyph[2]-0.5)*letterScale
            local gx2 = centerX + (glyph[3]-cursor*0.5)*letterScale
            local gy2 = centerY + (glyph[4]-0.5)*letterScale
            local x1 = fromA[1]+(gx1-fromA[1])*unfold
            local y1 = fromA[2]+(gy1-fromA[2])*unfold
            local x2 = fromB[1]+(gx2-fromB[1])*unfold
            local y2 = fromB[2]+(gy2-fromB[2])*unfold
            local visible = appear * fadeWire * ((i<=#edges) and 1 or unfold)
            drawSegment(lines[i],x1,y1,x2,y2,2.1,visible*0.96,
                Color3.fromRGB(80,176,255):Lerp(Color3.fromRGB(238,250,255),unfold))
        end
        local wordOpacity = smoothstep((elapsed-2.6)/0.42) *
            (1-smoothstep((elapsed-3.38)/0.42))
        title.TextTransparency = 1-wordOpacity
        caption.TextTransparency = 1-(smoothstep((elapsed-2.7)/0.35) *
            (1-smoothstep((elapsed-3.36)/0.42)) * 0.84)
    end)
end

-- Separate this intro flag from the old sound intro.
if FORCE_REPLAY_INTRO then
    getgenv().Ryu_Disguise_TesseractIntroPlayed = nil
end
if PLAY_INTRO and not getgenv().Ryu_Disguise_TesseractIntroPlayed then
    getgenv().Ryu_Disguise_TesseractIntroPlayed = true
    local ok, err = pcall(startTesseractIntro)
    if not ok then
        getgenv().Ryu_Disguise_TesseractIntroPlayed = nil
        if STATE.IntroCleanup then pcall(STATE.IntroCleanup) end
        for _, host in ipairs({player:FindFirstChildOfClass("PlayerGui")}) do
            if host then
                local stray = host:FindFirstChild("RyuTesseractIntro")
                if stray then pcall(function() stray:Destroy() end) end
            end
        end
        status("warning", "Ryu Disguise: intro failed:", err)
    end
end

status("ok", string.format("Ready | Mode %d | %s (@%s)", MODE, DISGUISE_DISPLAY, DISGUISE_NAME))
