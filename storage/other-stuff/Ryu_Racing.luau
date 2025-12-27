local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FVelocity = Vector3.new(0, 0, 0)
local SCSetting = false 
local SCModeLoop = false 
local ISSetting = false
local VMSetting = 1
local SVSetting = 50
local isDynamicVelocity = true

local JPSetting = false
local JPSliderValue = 50
local JPConnection = nil

local JitterSetting = false
local JitterIntensity = 1
local JitterLastOffset = Vector3.new(0, 0, 0)
local JitterToggleState = false
local JitterThreshold = 100

local function SmoothVelocity(Velocity)
    if isDynamicVelocity then
        if Velocity > 250 or math.random(1, 7) == 1 then
            return 1
        end
        return Velocity * VMSetting
    else
        return SVSetting
    end
end

local function MaintainJP(jpower)
    local player = Players.LocalPlayer
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if humanoid.UseJumpPower then
        humanoid.JumpPower = jpower
    else
        humanoid.JumpHeight = jpower
    end
end

local function JPLoop()
    if JPConnection then task.cancel(JPConnection) end 

    JPConnection = task.spawn(function()
        local player = Players.LocalPlayer
        local lastChar = player.Character

        while JPSetting do
            local currentJP = JPSetting and JPSliderValue or 0
            
            MaintainJP(currentJP)
            
            if player.Character ~= lastChar and player.Character then
                lastChar = player.Character
                player.Character:WaitForChild("Humanoid", 5) 
                MaintainJP(currentJP) 
            end

            task.wait(0.1)
        end
        MaintainJP(0) 
    end)
end

RunService.RenderStepped:Connect(function()
    local player = Players.LocalPlayer
    if not player or not player.Character then return end
    
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    if SCSetting and SCModeLoop then
        local camera = Workspace.CurrentCamera
        if camera then
            local camLook = camera.CFrame.LookVector
            local lookTarget = rootPart.Position + Vector3.new(camLook.X, 0, camLook.Z)
            rootPart.CFrame = CFrame.lookAt(rootPart.Position, lookTarget)
        end
    end

    local currentSpeed = rootPart.AssemblyLinearVelocity.Magnitude

    if JitterSetting and currentSpeed > JitterThreshold then
        local dynamicShift = JitterIntensity * (currentSpeed / 100)

        JitterToggleState = not JitterToggleState
        local direction = JitterToggleState and 1 or -1
        
        local currentOffset = rootPart.CFrame.RightVector * (dynamicShift * direction)

        local stableCFrame = rootPart.CFrame - JitterLastOffset
        rootPart.CFrame = stableCFrame + currentOffset
        
        JitterLastOffset = currentOffset
    else
        if JitterLastOffset ~= Vector3.zero then
            rootPart.CFrame = rootPart.CFrame - JitterLastOffset
            JitterLastOffset = Vector3.zero
        end
    end
end)

local function HookCheck(var)
    if not getgenv().hookmetamethod or not getgenv().getnamecallmethod then
        Rayfield:Notify({
           Title = "Compatibility Error",
           Content = "Cannot enable " .. var .. ". Your executor lacks required functions (hookmetamethod/getnamecallmethod).",
           Duration = 5,
           Image = nil,
        })
        return false
    end
    return true
end

local oldindex;
if getgenv().hookmetamethod and getgenv().getnamecallmethod then
    oldindex = hookmetamethod(game, "__index", function(v1, v2)
        if SCSetting and not SCModeLoop and v2 == "Velocity" and getnamecallmethod() == "ToOrientation" then
            return FVelocity
        end
        return oldindex(v1, v2)
    end)
end

local oldnewindex;
if getgenv().hookmetamethod then
    oldnewindex = hookmetamethod(game, "__newindex", function(v1, v2, v3)
        if v2 == "AssemblyLinearVelocity" then
            local newSpeed = SmoothVelocity(math.abs((v3).Magnitude))
            
            local horizontalVelocity = Vector3.new(v3.X, 0, v3.Z)
            
            if horizontalVelocity.Magnitude > 0.001 then
                local newVelocity = horizontalVelocity.Unit * newSpeed
                return oldnewindex(v1, v2, newVelocity)
            else
                return oldnewindex(v1, v2, v3)
            end
        end
        return oldnewindex(v1, v2, v3)
    end)
end

local oldnamecall;
if getgenv().hookmetamethod and getgenv().getnamecallmethod then
    oldnamecall = hookmetamethod(game, "__namecall", function(v1, v2, ...)
        if ISSetting and getnamecallmethod() == "FireServer" and v2 == "SpeedTarget" then
            return oldnamecall(v1, v2, 0)
        end
        return oldnamecall(v1, v2, ...)
    end)
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local RayfieldLibrary = RayfieldLibrary

local Window = Rayfield:CreateWindow({
   Name = "Ryu Racing",
   LoadingTitle = "Rachie my baby!!!",
   LoadingSubtitle = "by Ryu Nanashi",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "Ryu_Presents",
      FileName = "Uma_Racing"
   },
   Discord = {
      Enabled = true,
      Invite = "njy8U2kVr9",
      RememberJoins = true 
   },
   KeySystem = false,
})

Rayfield:Notify({
   Title = "Script Loaded",
   Content = "Oji-san is too old for racing, so i made a script for it uhehe!",
   Duration = 5,
   Image = nil,
})

local function ChangeTheme(ThemeName)
    if not RayfieldLibrary or not RayfieldLibrary.Theme then return end
    
    local SelectedTheme = RayfieldLibrary.Theme[ThemeName]
    if not SelectedTheme then return end 

    if Window.Main:FindFirstChild("Topbar") then
        Window.Main.Topbar.BackgroundColor3 = SelectedTheme.Topbar
    end
    
    for _, obj in ipairs(Window:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
            obj.TextColor3 = SelectedTheme.TextColor
            if SelectedTheme.TextFont and SelectedTheme.TextFont ~= "Default" then
                obj.Font = SelectedTheme.TextFont
            end
        elseif obj:IsA("Frame") then
            if obj.Name ~= "Placeholder" and obj.Name ~= "SectionSpacing" and obj.Name ~= "SectionTitle" then
                obj.BackgroundColor3 = SelectedTheme.ElementBackground
            end
            local uiStroke = obj:FindFirstChildOfClass("UIStroke")
            if uiStroke then
                uiStroke.Color = SelectedTheme.ElementStroke
            end
        end
    end
    
    Rayfield:Notify({
        Title = "Theme Applied",
        Content = "Switched to the '" .. ThemeName .. "' theme.",
        Duration = 3,
        Image = nil,
    })
end

local MainTab = Window:CreateTab("Main", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 7734053495)

MainTab:CreateSection("Base exploits")

local ToggleSC 
ToggleSC = MainTab:CreateToggle({
   Name = "Steer Control",
   CurrentValue = false,
   Flag = "SnapControl",
   Callback = function(Bool)
      if Bool and not SCModeLoop and not HookCheck("Steer Control") then
          ToggleSC:Set(false) 
          return
      end
      SCSetting = Bool
   end,
})

MainTab:CreateKeybind({
    Name = "Toggle Steer Control",
    CurrentKeybind = "Q",
    HoldToInteract = false,
    Flag = "SnapKeybind",
    Callback = function(KeybindHeld)
        local newState = not SCSetting
        SCSetting = newState
        if ToggleSC then
            ToggleSC:Set(newState)
        end
    end,
})

MainTab:CreateToggle({
    Name = "Steer Mode (Hook/Loop)",
    CurrentValue = false,
    Flag = "SnapModeToggle",
    Callback = function(Bool)
        SCModeLoop = Bool
        local modeName = Bool and "Camera Loop (No Hook)" or "Velocity Hook"
        Rayfield:Notify({
            Title = "Steer Mode Changed",
            Content = "Switched to: " .. modeName,
            Duration = 3,
            Image = nil,
        })
    end,
})

local ToggleIS = MainTab:CreateToggle({
   Name = "Infinite Stamina",
   CurrentValue = false,
   Flag = "InfStamina",
   Callback = function(Bool)
      if Bool and not HookCheck("Infinite Stamina") then
          ToggleIS:Set(false)
          return
      end
      ISSetting = Bool
   end,
})

MainTab:CreateSection("Velocity Control")

local SliderSV = MainTab:CreateSlider({
    Name = "Static Velocity Amount",
    Range = {10, 200},
    Increment = 1,
    Suffix = " stud/s",
    CurrentValue = 50,
    Flag = "StaticVelocityValue",
    Callback = function(Value)
        SVSetting = Value
    end,
})

local ToggleVMMode = MainTab:CreateToggle({
    Name = "Velocity Mode (Multiplier/Static)",
    CurrentValue = true,
    Flag = "DynamicModeToggle",
    Callback = function(Bool)
        isDynamicVelocity = Bool
        local mode = Bool and "Multiplier" or "Fixed"
        Rayfield:Notify({
            Title = "Velocity Mode Changed",
            Content = "Switched to: " .. mode,
            Duration = 3,
            Image = nil,
        })
    end,
})

local SliderVM = MainTab:CreateSlider({
   Name = "Dynamic Velocity Multiplier",
   Range = {1, 3},
   Increment = 0.1,
   Suffix = "x",
   CurrentValue = 2,
   Flag = "VelocityMult",
   Callback = function(Value)
      VMSetting = Value
   end,
})

MainTab:CreateSection("Jump Control") 

local ToggleJP = MainTab:CreateToggle({
    Name = "Toggle Jump Power",
    CurrentValue = false,
    Flag = "JumpPowerToggle",
    Callback = function(Bool)
        JPSetting = Bool
        if Bool then
            JPLoop()
        else
            if JPConnection then task.cancel(JPConnection) end 
            MaintainJP(0) 
        end
    end,
})

local SliderJP = MainTab:CreateSlider({
    Name = "Jump Power/Height Value",
    Range = {0, 30},
    Increment = 1,
    Suffix = " units",
    CurrentValue = 10,
    Flag = "JumpPowerValue",
    Callback = function(Value)
        JPSliderValue = Value
        if JPSetting then
            MaintainJP(Value)
        end
    end,
})

MainTab:CreateSection("Fun Features")

MainTab:CreateToggle({
    Name = "Velocity Jitter (Visual)",
    CurrentValue = false,
    Flag = "JitterToggle",
    Callback = function(Bool)
        JitterSetting = Bool
        if not Bool and JitterLastOffset ~= Vector3.zero then
            local p = Players.LocalPlayer
            if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                 p.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame - JitterLastOffset
                 JitterLastOffset = Vector3.zero
            end
        end
    end,
})

MainTab:CreateSlider({
    Name = "Jitter Intensity",
    Range = {0.1, 2.0},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 0.5,
    Flag = "JitterIntensity",
    Callback = function(Value)
        JitterIntensity = Value
    end,
})

MainTab:CreateSection("TouchInterests")

MainTab:CreateButton({
   Name = "Skip stage (Vulnerable)",
   Interact = 'Click',
   Callback = function()
      if not getgenv().firetouchinterest then
        Rayfield:Notify({
           Title = "Compatibility Error",
           Content = "Cannot execute Skip stage. Your executor lacks the 'firetouchinterest' function.",
           Duration = 5,
           Image = nil,
        })
        return
      end

      for _, v in pairs(workspace:GetDescendants()) do
          if v.Name == "TouchInterest" and v.Parent then
              firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, v.Parent, 0)
              task.wait(0.05)
              firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, v.Parent, 1)
          end
      end
   end,
})

MainTab:CreateSection("Info and Warnings")

MainTab:CreateParagraph({
    Title = "Velocity Jitter",
    Content = "<font color=\"rgb(100, 255, 100)\">This is a visual effect that shakes your character based on how fast you are going. It only activates when your speed is > 50. It uses RenderStepped for smooth local visuals and scales intensity with speed.</font>",
})

MainTab:CreateParagraph({
    Title = "Skip Stage Warning",
    Content = "<font color=\"rgb(255, 0, 0)\">This feature uses touch interest events to trick the game into thinking you hit the stage goal. You should only use this in private servers or sparingly in public servers. The delay must be reasonable, or the game will kick you and potentially flag your account.</font>",
})

MainTab:CreateParagraph({
    Title = "Optimal Skip Usage",
    Content = "<font color=\"rgb(255, 215, 0)\">This function skips roughly half of the round's progression. To avoid instant kicks, only use it after some time has passed since the start, or when you observe opponents are already making good progress. Use your opponents' positions as a measurement on when to trigger the skip.</font>",
})

MainTab:CreateParagraph({
    Title = "Steer Control",
    Content = "<font color=\"rgb(255, 255, 255)\">Steer control helps you steer more easily but it costs a lot of performance by using hookmetamethod which is highly unoptimized and unstable in most executors. I recommend using the keybind to toggle mid-race so you can save performance strategically.</font>",
})

MainTab:CreateParagraph({
    Title = "Performance Usage",
    Content = "<font color=\"rgb(255, 255, 255)\">Since performance degrades heavily when running multiple hookmetamethod exploits (like Steer Control Hook Mode and Infinite Stamina), consider switching to alternatives. You can maintain speed and control with minimal lag by pairing Static Velocity (non-hook based) with the Steer Control Loop Method. This combination uses fewer hooks, offering better stability and potentially a smoother experience.</font>",
})

MainTab:CreateParagraph({
    Title = "Features",
    Content = "<font color=\"rgb(200, 200, 200)\">Infinite Stamina: Prevents stamina bar depletion.\nStatic Velocity: Overrides physics with fixed speed.\nDynamic Velocity: Multiplies native speed.\nJump Toggle: Enables custom jump height (default 0, disabled by game).</font>",
})

MainTab:CreateSection("Misc")

local ButtonDiscord = MainTab:CreateButton({
   Name = "Copy Discord Link",
   Interact = 'Click',
   Callback = function()
    setclipboard("https://discord.gg/njy8U2kVr9")
    Rayfield:Notify({
        Title = "Discord",
        Content = "Link copied to clipboard!",
        Duration = 3,
        Image = nil,
     })
   end,
})

local ButtonIYR = MainTab:CreateButton({
   Name = "Infinite Yield Reborn",
   Interact = 'Click',
   Callback = function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/mxsynry/infiniteyield-reborn/refs/heads/master/source'))()
   end,
})

local themes = {}
if RayfieldLibrary and RayfieldLibrary.Theme then
    for name, _ in pairs(RayfieldLibrary.Theme) do
        table.insert(themes, name)
    end
else
    themes = {"Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity"}
end

SettingsTab:CreateDropdown({
   Name = "Interface Theme",
   Options = themes,
   CurrentOption = "Default",
   MultipleOptions = false,
   Flag = "ThemeDropdown",
   Callback = function(Option)
      ChangeTheme(Option)
   end,
})

SettingsTab:CreateButton({
   Name = "Destroy UI",
   Interact = 'Click',
   Callback = function()
      Rayfield:Destroy()
   end,
})