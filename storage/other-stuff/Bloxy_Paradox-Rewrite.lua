-- ============================================================================
-- BLOXY PARADOX PROJECT V2 - FINAL STABLE BUILD
-- ============================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================================
-- SAFE TWEEN ENGINE (Prevents executor null crashes)
-- ============================================================================
local ActiveTweens = {}

local function SafeTween(instance, tweenInfo, properties)
    if not instance or not instance.Parent then return nil end
    local success, tween = pcall(function()
        return TweenService:Create(instance, tweenInfo, properties)
    end)
    if success and tween then
        table.insert(ActiveTweens, tween)
        pcall(function() tween:Play() end)
        tween.Completed:Connect(function()
            local idx = table.find(ActiveTweens, tween)
            if idx then table.remove(ActiveTweens, idx) end
        end)
        return tween
    end
    return nil
end

local function SafeProperty(instance, property, value)
    if not instance or not instance.Parent then return end
    pcall(function() instance[property] = value end)
end

local function CancelAllTweens()
    for _, t in ipairs(ActiveTweens) do
        pcall(function() t:Cancel() end)
    end
    ActiveTweens = {}
end

-- ============================================================================
-- THEME SYSTEM
-- ============================================================================
local IsDark = false
local Themes = {
    Light = {
        Surface = Color3.fromRGB(255, 255, 255), Background = Color3.fromRGB(245, 245, 245), InputBg = Color3.fromRGB(240, 240, 240),
        TextPrimary = Color3.fromRGB(25, 25, 25), TextSecondary = Color3.fromRGB(80, 80, 80), TextMuted = Color3.fromRGB(150, 150, 150), TextOnPrimary = Color3.fromRGB(255, 255, 255),
        Border = Color3.fromRGB(215, 215, 215), Primary = Color3.fromRGB(0, 162, 255), PrimaryDark = Color3.fromRGB(0, 120, 200), PrimarySubtle = Color3.fromRGB(230, 243, 255),
        Success = Color3.fromRGB(76, 175, 80), Hover = Color3.fromRGB(230, 230, 230), CloseBtn = Color3.fromRGB(235, 235, 235),
        ToggleOff = Color3.fromRGB(200, 200, 200), ToggleOn = Color3.fromRGB(0, 162, 255), OverlayTransparency = 0.35,
    },
    Dark = {
        Surface = Color3.fromRGB(30, 30, 36), Background = Color3.fromRGB(40, 40, 48), InputBg = Color3.fromRGB(35, 35, 42),
        TextPrimary = Color3.fromRGB(240, 240, 245), TextSecondary = Color3.fromRGB(170, 170, 180), TextMuted = Color3.fromRGB(100, 100, 115), TextOnPrimary = Color3.fromRGB(255, 255, 255),
        Border = Color3.fromRGB(55, 55, 68), Primary = Color3.fromRGB(0, 162, 255), PrimaryDark = Color3.fromRGB(0, 130, 220), PrimarySubtle = Color3.fromRGB(20, 30, 45),
        Success = Color3.fromRGB(76, 175, 80), Hover = Color3.fromRGB(50, 50, 60), CloseBtn = Color3.fromRGB(50, 50, 60),
        ToggleOff = Color3.fromRGB(60, 60, 75), ToggleOn = Color3.fromRGB(0, 162, 255), OverlayTransparency = 0.55,
    }
}
local T = Themes.Light

-- ============================================================================
-- STATE & DATA
-- ============================================================================
local State = { CurrentStep = 0, TotalSteps = 8, Selections = {}, IsComplete = false }
local Steps = {
    {id = "topbar", title = "Topbar Style", question = "Which topbar do you prefer?", type = "dropdown"},
    {id = "safechat", title = "Safe Chat", question = "Enable safe chat? (PC only)", type = "yesno"},
    {id = "backpack", title = "Backpack", question = "Choose a backpack style:", type = "triple"},
    {id = "animations", title = "Animations", question = "Choose your animations:", type = "dynamic"},
    {id = "sounds", title = "Sounds", question = "Use classic footsteps/sounds?", type = "yesno"},
    {id = "textures", title = "Textures", question = "Choose texture style:", type = "triple"},
    {id = "forcefield", title = "Forcefield", question = "Use classic bubble forcefield?", type = "yesno"},
    {id = "emotes", title = "Emotes", question = "Unlock better emotes?", type = "yesno"},
}

-- Script Database
local Scripts = {
    Topbar_2020 = [[local Players=game:GetService("Players")local TweenService=game:GetService("TweenService")local CoreGui=game:GetService("CoreGui")local StarterGui=game:GetService("StarterGui")local LocalizationService=game:GetService("LocalizationService")local GuiService=game:GetService("GuiService")local VirtualInputManager=game:GetService("VirtualInputManager")local TextChatService=game:GetService("TextChatService")local LocalPlayer=Players.LocalPlayer local PlayerGui=LocalPlayer:WaitForChild("PlayerGui")local RobloxGui=CoreGui:WaitForChild("RobloxGui")pcall(function()if CoreGui:FindFirstChild("TopBarApp")then CoreGui.TopBarApp:Destroy()end if CoreGui:FindFirstChild("ExperienceChat")then CoreGui.ExperienceChat:Destroy()end end)if PlayerGui:FindFirstChild("Chat")then PlayerGui.Chat:Destroy()end if not game:IsLoaded()then game.Loaded:Wait()end game:GetObjects("rbxassetid://122252029612413")[1].Parent=workspace local rbxmSuite=loadstring(game:HttpGetAsync("https://github.com/richie0866/rbxm-suite/releases/latest/download/rbxm-suite.lua"))()task.wait()rbxmSuite.launch("rbxassetid://111872120766790",{runscripts=true,deferred=true,nocache=false,nocirculardeps=true,debug=true,verbose=false})local SettingsRoot=Instance.new("Frame")SettingsRoot.Name="SettingsRoot"SettingsRoot.Parent=RobloxGui SettingsRoot.Position=UDim2.new(0,0,0,-60)SettingsRoot.Size=UDim2.new(1,0,1,0)SettingsRoot.BackgroundTransparency=1 SettingsRoot.ZIndex=4 local SettingsShield=Instance.new("Frame")SettingsShield.Name="SettingsShield"SettingsShield.Parent=SettingsRoot SettingsShield.Active=true SettingsShield.Size=UDim2.new(1,0,1,60)SettingsShield.BackgroundColor3=Color3.fromRGB(41,41,41)SettingsShield.BackgroundTransparency=0.2 SettingsShield.ZIndex=5 local shieldH=SettingsShield.AbsoluteSize.Y SettingsShield.Position=UDim2.new(0,0,0,-shieldH)local DontorNo=Instance.new("Frame")DontorNo.Name="DontorNo"DontorNo.Parent=SettingsShield DontorNo.Position=UDim2.new(0.18,0,0.5,0)DontorNo.Size=UDim2.new(0,520,0,70)DontorNo.BackgroundTransparency=1 DontorNo.Visible=false DontorNo.ZIndex=1 local BottomFrame=Instance.new("Frame")BottomFrame.Name="BottomButtons"BottomFrame.Parent=SettingsShield BottomFrame.Position=UDim2.new(0.5,-400,1,-84)BottomFrame.Size=UDim2.new(0,800,0,60)BottomFrame.BackgroundTransparency=1 BottomFrame.ZIndex=6 local function MakeBtn(n,x,t,p)p=p or BottomFrame local b=Instance.new("ImageButton")b.Name=n b.Parent=p b.Position=UDim2.new(0.5,x,0.5,-25)b.Size=UDim2.new(0,260,0,70)b.BackgroundTransparency=1 b.Image="rbxasset://textures/ui/Settings/MenuBarAssets/MenuButton.png"b.ScaleType=Enum.ScaleType.Slice b.SliceCenter=Rect.new(6,6,46,44)b.ZIndex=7 local l=Instance.new("TextLabel")l.Parent=b l.Size=UDim2.new(1,0,1,0)l.BackgroundTransparency=1 l.Text=t l.TextColor3=Color3.new(1,1,1)l.Font=Enum.Font.SourceSansBold l.TextSize=28 l.ZIndex=8 b.MouseEnter:Connect(function()b.Image="rbxasset://textures/ui/Settings/MenuBarAssets/MenuButtonSelected.png"end)b.MouseLeave:Connect(function()b.Image="rbxasset://textures/ui/Settings/MenuBarAssets/MenuButton.png"end)return b end local LeaveBtn=MakeBtn("LeaveGameButton",-400,"Leave Game")local ResetBtn=MakeBtn("ResetCharacterButton",-130,"Reset Character")local ResumeBtn=MakeBtn("ResumeButton",140,"Resume")local DontResetBtn=MakeBtn("DontReset",-150,"Don't Reset",DontorNo)local ConfirmResetBtn=MakeBtn("ConfirmReset",150,"Reset",DontorNo)local DontLeaveBtn=MakeBtn("DontLeave",-150,"Don't Leave",DontorNo)local ConfirmLeaveBtn=MakeBtn("ConfirmLeave",150,"Leave",DontorNo)local TopBar=Instance.new("Frame")TopBar.Name="TopBarContainer"TopBar.Parent=RobloxGui TopBar.Size=UDim2.new(1,0,0,50)TopBar.Position=UDim2.new(0,0,0,-45)TopBar.BackgroundTransparency=1 TopBar.ZIndex=10 local SettingsApp=Instance.new("ImageButton")SettingsApp.Name="Settings"SettingsApp.Parent=TopBar SettingsApp.Position=UDim2.new(0,5,0,0)SettingsApp.Size=UDim2.new(0,38,0,38)SettingsApp.BackgroundTransparency=0.5 SettingsApp.BackgroundColor3=Color3.new(0,0,0)SettingsApp.ZIndex=11 local SIcon=Instance.new("ImageLabel")SIcon.Parent=SettingsApp SIcon.Size=UDim2.new(1,-7,1,-7)SIcon.Position=UDim2.new(0,3,0,3)SIcon.BackgroundTransparency=1 SIcon.Image="rbxassetid://14874733468"SIcon.ZIndex=12 Instance.new("UICorner",SettingsApp).CornerRadius=UDim.new(0.2,0)local CloseBtn=Instance.new("TextButton")CloseBtn.Name="CloseButton"CloseBtn.Parent=TopBar CloseBtn.Size=UDim2.new(0,38,0,38)CloseBtn.Position=UDim2.new(0,5,0,0)CloseBtn.BackgroundColor3=Color3.new(1,1,1)CloseBtn.Text="X"CloseBtn.Visible=false CloseBtn.TextColor3=Color3.new(0,0,0)CloseBtn.Font=Enum.Font.SourceSansBold CloseBtn.TextSize=25 CloseBtn.ZIndex=16 Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0.2,0)local chatOpen=false local chatContainer=PlayerGui:WaitForChild("Chat")local realFrame=chatContainer:WaitForChild("Frame")realFrame.Visible=false local ChatApp=Instance.new("ImageButton")ChatApp.Name="Chat"ChatApp.Parent=TopBar ChatApp.Position=UDim2.new(0,55,0,0)ChatApp.Size=UDim2.new(0,38,0,38)ChatApp.BackgroundTransparency=0.5 ChatApp.BackgroundColor3=Color3.new(0,0,0)ChatApp.ZIndex=11 local CIcon=Instance.new("ImageLabel")CIcon.Parent=ChatApp CIcon.Size=UDim2.new(1,0,1,0)CIcon.BackgroundTransparency=1 CIcon.Image="rbxassetid://15839118471"CIcon.ZIndex=12 Instance.new("UICorner",ChatApp).CornerRadius=UDim.new(0.2,0)local unread=0 local Badge=Instance.new("Frame")Badge.Size=UDim2.new(0,20,0,20)Badge.Position=UDim2.new(1,-13,0,-6)Badge.BackgroundColor3=Color3.fromRGB(0,0,0)Badge.Visible=false Badge.ZIndex=14 Badge.Parent=ChatApp Instance.new("UICorner",Badge).CornerRadius=UDim.new(1,0)local BadgeIn=Instance.new("Frame")BadgeIn.Size=UDim2.new(1,-3,1,-3)BadgeIn.Position=UDim2.new(0.5,0,0.5,0)BadgeIn.AnchorPoint=Vector2.new(0.5,0.5)BadgeIn.BackgroundColor3=Color3.fromRGB(255,255,255)BadgeIn.ZIndex=15 BadgeIn.Parent=Badge Instance.new("UICorner",BadgeIn).CornerRadius=UDim.new(1,0)local BadgeTxt=Instance.new("TextLabel")BadgeTxt.Size=UDim2.new(1,0,1,0)BadgeTxt.Position=UDim2.new(0.5,0,0.5,-1)BadgeTxt.AnchorPoint=Vector2.new(0.5,0.5)BadgeTxt.BackgroundTransparency=1 BadgeTxt.Text="0"BadgeTxt.TextColor3=Color3.fromRGB(0,0,0)BadgeTxt.Font=Enum.Font.SourceSansBold BadgeTxt.TextSize=15 BadgeTxt.ZIndex=16 BadgeTxt.Parent=BadgeIn local function updBadge()if chatOpen or unread==0 then Badge.Visible=false else Badge.Visible=true BadgeTxt.Text=unread>=100 and "99+" or tostring(unread)end end if chatContainer:FindFirstChild("MessageLogDisplay")then chatContainer.MessageLogDisplay.ChildAdded:Connect(function()if not chatOpen then unread=unread+1;updBadge()end end)end TextChatService.MessageReceived:Connect(function()if not chatOpen then unread=unread+1;updBadge()end end)ChatApp.MouseButton1Click:Connect(function()chatOpen=not chatOpen;realFrame.Visible=chatOpen;if chatOpen then unread=0;updBadge()end;CIcon.Image=chatOpen and "rbxassetid://15839116089" or "rbxassetid://15839118471"end)local MoreOpen=false local MoreApp=Instance.new("ImageButton")MoreApp.Name="More"MoreApp.Parent=TopBar MoreApp.Position=UDim2.new(1,-43,0,0)MoreApp.Size=UDim2.new(0,38,0,38)MoreApp.BackgroundTransparency=0.5 MoreApp.BackgroundColor3=Color3.new(0,0,0)MoreApp.ZIndex=11 local MIcon=Instance.new("ImageLabel")MIcon.Parent=MoreApp MIcon.Size=UDim2.new(1,-2,1,-2)MIcon.Position=UDim2.new(0,1,0,1)MIcon.BackgroundTransparency=1 MIcon.Image="rbxassetid://136279431647973"MIcon.ZIndex=12 Instance.new("UICorner",MoreApp).CornerRadius=UDim.new(0.2,0)local Wip=Instance.new("ScreenGui")Wip.Name="Wip"Wip.Parent=MoreApp Wip.Enabled=false local MFrame=Instance.new("ScrollingFrame")MFrame.Size=UDim2.new(0,300,0,150)MFrame.Position=UDim2.new(1,-305,0,0)MFrame.BackgroundColor3=Color3.fromRGB(0,0,0)MFrame.BackgroundTransparency=0.3 MFrame.CanvasSize=UDim2.new(0,0,0,200)MFrame.Parent=Wip Instance.new("UICorner",MFrame).CornerRadius=UDim.new(0.1,0)local function MakeMore(p,n,i,t,y)local b=Instance.new("ImageButton")b.Name=n b.Size=UDim2.new(1,0,0,50)b.Position=UDim2.new(0,0,0,y)b.BackgroundTransparency=1 b.Parent=p local ic=Instance.new("ImageLabel")ic.Size=UDim2.new(0,45,0,45)ic.Position=UDim2.new(0,10,0,0)ic.BackgroundTransparency=1 ic.Image=i ic.Parent=b local l=Instance.new("TextLabel")l.Parent=b l.Size=UDim2.new(1,-70,0,50)l.Position=UDim2.new(0,70,0,0)l.BackgroundTransparency=1 l.Text=t l.Font=Enum.Font.GothamBold l.TextSize=18 l.TextColor3=Color3.fromRGB(230,230,230)l.TextXAlignment=Enum.TextXAlignment.Left l.TextYAlignment=Enum.TextYAlignment.Center return b end MakeMore(MFrame,"Leaderboard","rbxassetid://81047217774682","Leaderboard",10)MakeMore(MFrame,"Inventory","rbxassetid://7743874651","Inventory",65)local EmotesBtn=MakeMore(MFrame,"Emotes","rbxassetid://6031071050","Emotes",120)MoreApp.MouseButton1Click:Connect(function()MoreOpen=not MoreOpen;Wip.Enabled=MoreOpen;MIcon.Image=MoreOpen and "rbxassetid://110209751814466" or "rbxassetid://136279431647973"end)EmotesBtn.MouseButton1Click:Connect(function()pcall(function()local o=GuiService:GetEmotesMenuOpen();GuiService:SetEmotesMenuOpen(not o)end);MoreOpen=false;Wip.Enabled=false;MIcon.Image="rbxassetid://136279431647973"end)local HubBar=Instance.new("ImageLabel")HubBar.Name="HubBar"HubBar.Parent=SettingsShield HubBar.SliceCenter=Rect.new(4,4,6,6)HubBar.Image="rbxasset://textures/ui/Settings/MenuBarAssets/MenuBackground.png"HubBar.Position=UDim2.new(0.5,-400,0,65)HubBar.Size=UDim2.new(0,800,0,60)HubBar.BackgroundTransparency=1 HubBar.ScaleType=Enum.ScaleType.Slice HubBar.ZIndex=7 local Clipper=Instance.new("Frame")Clipper.Parent=SettingsShield Clipper.Position=UDim2.new(0.5,-400,0.5,-228.5)Clipper.Size=UDim2.new(0,800,0,490)Clipper.BackgroundTransparency=1 Clipper.ZIndex=7 local PageView=Instance.new("Frame")PageView.Parent=Clipper PageView.Size=UDim2.new(1,0,1,0)PageView.BackgroundTransparency=1 local ThumbCache={}local PlayersPage=Instance.new("ScrollingFrame")PlayersPage.Parent=PageView PlayersPage.Position=UDim2.new(0,0,0,10)PlayersPage.Size=UDim2.new(1,0,1,-10)PlayersPage.CanvasSize=UDim2.new(0,0,0,0)PlayersPage.ScrollBarImageTransparency=0.3 PlayersPage.BackgroundTransparency=1 local pLayout=Instance.new("UIListLayout")pLayout.Padding=UDim.new(0,10)pLayout.Parent=PlayersPage pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()PlayersPage.CanvasSize=UDim2.new(0,0,0,pLayout.AbsoluteContentSize.Y+10)end)local function getThumb(id)if ThumbCache[id]then return ThumbCache[id]end local img=Players:GetUserThumbnailAsync(id,Enum.ThumbnailType.AvatarThumbnail,Enum.ThumbnailSize.Size352x352)ThumbCache[id]=img return img end local function CreatePlayerEntry(p)if p==Players.LocalPlayer then return end local R=Instance.new("Frame")R.Size=UDim2.new(1,0,0,60)R.BackgroundTransparency=1 R.Parent=PlayersPage local BG=Instance.new("ImageLabel")BG.Size=UDim2.new(1,0,1,0)BG.Image="rbxasset://textures/ui/dialog_white.png"BG.ScaleType=Enum.ScaleType.Slice BG.SliceCenter=Rect.new(10,10,10,10)BG.ImageTransparency=0.85 BG.BackgroundTransparency=1 BG.Parent=R local I=Instance.new("ImageLabel")I.Size=UDim2.new(0,36,0,36)I.Position=UDim2.new(0,12,0.5,-18)I.BackgroundTransparency=1 I.Parent=R task.spawn(function()I.Image=getThumb(p.UserId)end)local N=Instance.new("TextLabel")N.Size=UDim2.new(0.5,0,1,0)N.Position=UDim2.new(0,60,0,0)N.BackgroundTransparency=1 N.Text=p.DisplayName N.TextXAlignment=Enum.TextXAlignment.Left N.TextColor3=Color3.new(1,1,1)N.TextSize=20 N.Font=Enum.Font.SourceSansBold N.Parent=R p.AncestryChanged:Connect(function(_,par)if not par then R:Destroy()end end)end for _,p in ipairs(Players:GetPlayers())do CreatePlayerEntry(p)end Players.PlayerAdded:Connect(CreatePlayerEntry)local SettingsPage=Instance.new("ScrollingFrame")SettingsPage.Name="SettingsPage"SettingsPage.Parent=PageView SettingsPage.Position=UDim2.new(0,0,0,15)SettingsPage.Size=UDim2.new(1,0,0,360)SettingsPage.CanvasSize=UDim2.new(0,0,0,380)SettingsPage.BackgroundTransparency=1 SettingsPage.ZIndex=7 local ReportPage=Instance.new("Frame")ReportPage.Name="ReportAbusePage"ReportPage.Parent=PageView ReportPage.Size=UDim2.new(1,0,0,450)ReportPage.BackgroundTransparency=1 ReportPage.ZIndex=7 local HelpPage=Instance.new("Frame")HelpPage.Name="HelpPage"HelpPage.Parent=PageView HelpPage.Size=UDim2.new(1,0,0,231)HelpPage.BackgroundTransparency=1 local function MakeTab(n,i,t,pos)local Tab=Instance.new("TextButton")Tab.Name=n Tab.Parent=HubBar Tab.Position=pos Tab.Size=UDim2.new(0,169,1,0)Tab.BackgroundTransparency=1 Tab.Text="" Tab.ZIndex=7 local Ic=Instance.new("ImageLabel")Ic.Name="Icon"Ic.Parent=Tab Ic.Image=i Ic.Position=UDim2.new(0,15,0.5,-22)Ic.Size=UDim2.new(0,45,0,45)Ic.BackgroundTransparency=1 Ic.ZIndex=7 local Ti=Instance.new("TextLabel")Ti.Name="Title"Ti.Parent=Ic Ti.Position=UDim2.new(1.2,0,0,0)Ti.Size=UDim2.new(1.2,0,1,0)Ti.BackgroundTransparency=1 Ti.Text=t Ti.TextSize=24 Ti.Font=Enum.Font.SourceSansBold Ti.TextXAlignment=Enum.TextXAlignment.Left Ti.TextColor3=Color3.new(1,1,1)Ti.TextTransparency=0.5 Ti.ZIndex=8 local Sel=Instance.new("ImageLabel")Sel.Name="TabSelection"Sel.Parent=Tab Sel.SliceCenter=Rect.new(3,1,4,5)Sel.Image="rbxasset://textures/ui/Settings/MenuBarAssets/MenuSelection.png"Sel.Position=UDim2.new(0,0,1,-6)Sel.Size=UDim2.new(1,0,0,6)Sel.BackgroundTransparency=1 Sel.Visible=false Sel.ScaleType=Enum.ScaleType.Slice Sel.ZIndex=7 return Tab end local PlayersTab=MakeTab("PlayersTab","rbxasset://textures/ui/Settings/MenuBarIcons/PlayersTabIcon.png","Players",UDim2.new(0.167,-120,0,0))local SettingsTab=MakeTab("GameSettingsTab","rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png","Settings",UDim2.new(0.167,80,0,0))local ReportTab=MakeTab("ReportAbuseTab","rbxasset://textures/ui/Settings/MenuBarIcons/ReportAbuseTab.png","Report",UDim2.new(0.167,280,0,0))local HelpTab=MakeTab("HelpTab","rbxasset://textures/ui/Settings/MenuBarIcons/HelpTab.png","Help",UDim2.new(0.167,480,0,0))local TabList={{Tab=PlayersTab,Page=PlayersPage},{Tab=SettingsTab,Page=SettingsPage},{Tab=ReportTab,Page=ReportPage},{Tab=HelpTab,Page=HelpPage}}local function SetActive(sel)for _,t in ipairs(TabList)do t.Tab.TabSelection.Visible=(t.Tab==sel);t.Tab.Icon.ImageTransparency=(t.Tab==sel)and 0 or 0.5;t.Tab.Icon.Title.TextTransparency=(t.Tab==sel)and 0 or 0.5;t.Page.Visible=(t.Tab==sel)end end SetActive(PlayersTab)for _,t in ipairs(TabList)do t.Tab.MouseButton1Click:Connect(function()SetActive(t.Tab)end)end local chatFix=Instance.new("ScreenGui")chatFix.Name="ChatWindow"chatFix.Parent=RobloxGui local chatCont=Instance.new("Frame")chatCont.Name="Frame"chatCont.Size=UDim2.new(1,0,1,0)chatCont.BackgroundTransparency=1 chatCont.Parent=chatFix local oldChat=PlayerGui.Chat.Frame oldChat.Parent=chatCont local closeTween=TweenService:Create(SettingsShield,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=UDim2.new(0,0,0,-shieldH)})local isOpen=false local function simEsc()VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.Escape,false,game);task.wait(0.05);VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.Escape,false,game)end SettingsApp.MouseButton1Click:Connect(simEsc)local function CloseMenu()if not isOpen then return end;closeTween:Play();CloseBtn.Visible=false;chatFix.Enabled=true;HubBar.Visible=false;PageView.Visible=false;BottomFrame.Visible=false;SettingsApp.Visible=true;ChatApp.Visible=true;MoreApp.Visible=true;isOpen=false end CloseBtn.MouseButton1Click:Connect(CloseMenu)ResumeBtn.MouseButton1Click:Connect(CloseMenu)LeaveBtn.MouseButton1Click:Connect(function()DontorNo.Visible=true;ConfirmLeaveBtn.Visible=true;DontLeaveBtn.Visible=true;BottomFrame.Visible=false;HubBar.Visible=false;PageView.Visible=false end)DontLeaveBtn.MouseButton1Click:Connect(function()DontorNo.Visible=false;ConfirmLeaveBtn.Visible=false;DontLeaveBtn.Visible=false;BottomFrame.Visible=true;HubBar.Visible=true;PageView.Visible=true end)ConfirmLeaveBtn.MouseButton1Click:Connect(function()game:Shutdown()end)ResetBtn.MouseButton1Click:Connect(function()if not isOpen then return end;BottomFrame.Visible=false;ConfirmLeaveBtn.Visible=false;DontLeaveBtn.Visible=false;DontResetBtn.Visible=true;ConfirmResetBtn.Visible=true;HubBar.Visible=false;DontorNo.Visible=true;PageView.Visible=false end)DontResetBtn.MouseButton1Click:Connect(function()DontorNo.Visible=false;ConfirmLeaveBtn.Visible=false;DontLeaveBtn.Visible=false;DontResetBtn.Visible=false;ConfirmResetBtn.Visible=false;BottomFrame.Visible=true;HubBar.Visible=true;PageView.Visible=true end)ConfirmResetBtn.MouseButton1Click:Connect(function()if LocalPlayer.Character then LocalPlayer.Character:BreakJoints()end;DontorNo.Visible=false;BottomFrame.Visible=true;chatFix.Enabled=true;CloseBtn.Visible=false;HubBar.Visible=true;SettingsApp.Visible=true;ChatApp.Visible=true;MoreApp.Visible=true;PageView.Visible=true;DontResetBtn.Visible=false;ConfirmResetBtn.Visible=false;closeTween:Play();isOpen=false end)local ChatBar=CoreGui.RobloxGui.ChatWindow.Frame.Frame.ChatBarParentFrame ChatBar.Size=UDim2.new(1,-44,ChatBar.Size.Y.Scale,ChatBar.Size.Y.Offset)if not game:IsLoaded()then game.Loaded:Wait()end local S,E=pcall(function()loadstring(game:HttpGet("https://raw.githubusercontent.com/xaviersupreme/Project2016/main/modules/settings.lua"))()end)if S then print("2020 PC Esc UI injected!")else warn("Failed:",E)end]],
    Topbar_2016_A = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-BEST-2016-COREUI-WORKING-60721"))()]],
    Topbar_2016_S = [[getgenv().LegacySettings={Year=2016,OldGraphics=true,HideDisplayName=true} loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/Legacy/refs/heads/main/Source.luau"))()]],
    Topbar_2014 = [[getgenv().LegacySettings={Year=2014,OldGraphics=true,HideDisplayName=true} loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/Legacy/refs/heads/main/Source.luau"))()]],
    Topbar_2013 = [[getgenv().LegacySettings={Year=2013,OldGraphics=true,HideDisplayName=true} loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/Legacy/refs/heads/main/Source.luau"))()]],
    Topbar_2012 = [[getgenv().LegacySettings={Year=2012,OldGraphics=true,HideDisplayName=true} loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/Legacy/refs/heads/main/Source.luau"))()]],
    Topbar_OldChat = [[loadstring(game:HttpGet("https://pastebin.com/raw/9AQrDua1"))()]],
    SafeChat = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-OG-Safe-Chat-for-Roblox-30941"))()]],
    Backpack_Simple = [[loadstring(game:HttpGet("https://peeky.pythonanywhere.com/CustomBackpack"))()]],
    Backpack_Advanced = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Custom-Mobile-Backpack-38376"))()]],
    Anims_R6_2008 = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-r15-to-r6-or-from-already-r6-to-2008-r6-76462"))()]],
    Anims_R6_2006 = [[local P=game:GetService("Players").LocalPlayer local IDs={Idle="rbxassetid://107407916979702",Walk="rbxassetid://103979922296239",Run="rbxassetid://103979922296239",Jump="rbxassetid://119095524735341",Fall="rbxassetid://119095524735341",Climb="rbxassetid://132639392250396"} local R={} for n,i in pairs(IDs)do R[n]=i;pcall(function()for _,o in ipairs(game:GetObjects(i))do if o:IsA("Animation")then R[n]=o.AnimationId end end end)end local function Inj(c)local h=c:WaitForChild("Humanoid",10)local a=c:WaitForChild("Animate",10)if not h or not a then return end local function s(n,ch,id)local x=a:FindFirstChild(n)if x then local t=x:FindFirstChild(ch)if t and t:IsA("Animation")then t.AnimationId=id end end end s("idle","Animation1",R.Idle)s("idle","Animation2",R.Idle)s("walk","WalkAnim",R.Walk)s("run","RunAnim",R.Run)s("jump","JumpAnim",R.Jump)s("fall","FallAnim",R.Fall)s("climb","ClimbAnim",R.Climb)local an=h:FindFirstChildOfClass("Animator")if an then for _,t in ipairs(an:GetPlayingAnimationTracks())do t:Stop(0)end end a.Disabled=true;task.wait(0.05);a.Disabled=false end task.wait(1)if P.Character then task.spawn(Inj,P.Character)end P.CharacterAdded:Connect(function(c)task.spawn(function()task.wait(0.5);Inj(c)end)end)]],
    Anims_R15_2008 = [[local P=game:GetService("Players").LocalPlayer local IDs={Idle="rbxassetid://107407916979702",Walk="rbxassetid://103979922296239",Run="rbxassetid://103979922296239",Jump="rbxassetid://119095524735341",Fall="rbxassetid://119095524735341",Climb="rbxassetid://132639392250396"} local R={} for n,i in pairs(IDs)do R[n]=i;pcall(function()for _,o in ipairs(game:GetObjects(i))do if o:IsA("Animation")then R[n]=o.AnimationId end end end)end local function Inj(c)local h=c:WaitForChild("Humanoid",10)local a=c:WaitForChild("Animate",10)if not h or not a then return end local function s(n,ch,id)local x=a:FindFirstChild(n)if x then local t=x:FindFirstChild(ch)if t and t:IsA("Animation")then t.AnimationId=id end end end s("idle","Animation1",R.Idle)s("idle","Animation2",R.Idle)s("walk","WalkAnim",R.Walk)s("run","RunAnim",R.Run)s("jump","JumpAnim",R.Jump)s("fall","FallAnim",R.Fall)s("climb","ClimbAnim",R.Climb)local an=h:FindFirstChildOfClass("Animator")if an then for _,t in ipairs(an:GetPlayingAnimationTracks())do t:Stop(0)end end a.Disabled=true;task.wait(0.05);a.Disabled=false end task.wait(1)if P.Character then task.spawn(Inj,P.Character)end P.CharacterAdded:Connect(function(c)task.spawn(function()task.wait(0.5);Inj(c)end)end)]],
    Anims_R15_Old = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Old-R15-Animations-100039"))()]],
    OldSounds = [[local P=game:GetService("Players").LocalPlayer local RS=game:GetService("RunService")local function apply(c)local h=c:WaitForChild("Humanoid")local r=c:WaitForChild("HumanoidRootPart")if c:FindFirstChild("Sound")then c.Sound:Destroy()end for _,s in pairs(r:GetChildren())do if s:IsA("Sound")then s:Destroy()end end local st=Instance.new("Sound",r)st.SoundId="rbxassetid://174960816"st.Volume=0 st.Looped=true st:Play()local j=Instance.new("Sound",r)j.SoundId="rbxassetid://2428506580"j.Volume=1 local d=Instance.new("Sound",r)d.SoundId="rbxassetid://17755696142"d.Volume=1 local cl=Instance.new("Sound",r)cl.SoundId="rbxassetid://7593297942"cl.Volume=0.8 cl.Looped=true RS.Heartbeat:Connect(function()if not h or h.Health<=0 then st.Volume=0;cl:Stop();return end local sp=r.Velocity.Magnitude local st2=h:GetState()if st2==Enum.HumanoidStateType.Climbing then st.Volume=0;if not cl.IsPlaying then cl:Play()end elseif sp>1.5 and st2~=Enum.HumanoidStateType.Freefall then cl:Stop();st.Volume=0.8 else st.Volume=0;cl:Stop()end end)h.StateChanged:Connect(function(_,n)if n==Enum.HumanoidStateType.Jumping then st.Volume=0;j:Play()end end)h.Died:Connect(function()st.Volume=0;cl:Stop();d:Play()end)end if P.Character then apply(P.Character)end P.CharacterAdded:Connect(function(c)repeat task.wait()until c:FindFirstChild("HumanoidRootPart")and c:FindFirstChild("Humanoid");apply(c)end)]],
    Textures_2006 = [[for _,v in pairs(workspace:GetDescendants())do if v:IsA("BasePart")then local d=Instance.new("Texture",v)d.Texture="rbxassetid://48715260"d.Face="Top"d.StudsPerTileU="1"d.StudsPerTileV="1"v.Material="Plastic"local d2=Instance.new("Texture",v)d2.Texture="rbxassetid://20299774"d2.Face="Bottom"d2.StudsPerTileU="1"d2.StudsPerTileV="1"v.Material="Plastic"end end game.Lighting.ClockTime=12;game.Lighting.GlobalShadows=false;game.Lighting.Outlines=false for _,v in pairs(game.Lighting:GetDescendants())do if v:IsA("Sky")then v:Destroy()end end local s=Instance.new("Sky",game.Lighting)s.SkyboxBk="rbxassetid://161781263";s.SkyboxDn="rbxassetid://161781258";s.SkyboxFt="rbxassetid://161781261";s.SkyboxLf="rbxassetid://161781267";s.SkyboxRt="rbxassetid://161781268";s.SkyboxUp="rbxassetid://161781260"]],
    Textures_2016 = [[for _,e in pairs(game:GetService("Lighting"):GetChildren())do if e:IsA("DepthOfFieldEffect")or e:IsA("Atmosphere")then e:Destroy()end end pcall(function()sethiddenproperty(game:GetService("Lighting"),"Technology",Enum.Technology.Compatibility)end)game:GetService("Lighting").Brightness=2 for _,v in ipairs(game:GetDescendants())do if v:IsA("BasePart")and v.Material==Enum.Material.Plastic and v.TopSurface==Enum.SurfaceType.Studs and not v:FindFirstChildOfClass("Texture")and not v.Parent:FindFirstChild("Humanoid")then local s=Instance.new("Texture")s.Parent=v s.Face=Enum.NormalId.Top s.Texture="rbxassetid://7027211371"s.Color3=Color3.new(v.Color.R*2,v.Color.G*2,v.Color.B*2)end end]],
    Forcefield = [[local P=game:GetService("Players").LocalPlayer local RS=game:GetService("RunService")local TS=game:GetService("TweenService")local folder=Instance.new("Folder")folder.Name="FFClone"folder.Parent=workspace local function torso(c)return c:FindFirstChild("UpperTorso")or c:FindFirstChild("Torso")or c:FindFirstChild("HumanoidRootPart")end local function build()local m=Instance.new("Model")m.Name="FF2012"m.Parent=folder local mc=Instance.new("Part")mc.Anchored=true mc.CanCollide=false mc.CastShadow=false mc.Color=Color3.fromRGB(0,0,128)mc.Material=Enum.Material.Neon mc.Transparency=0.6 mc.Size=Vector3.new(0.9,0.9,0.9)mc.Parent=m Instance.new("SpecialMesh",mc).MeshType=Enum.MeshType.Sphere mc.SpecialMesh.Scale=Vector3.new(7,7,7)local oc=Instance.new("Part")oc.Anchored=true oc.CanCollide=false oc.CastShadow=false oc.Color=Color3.fromRGB(0,0,128)oc.Material=Enum.Material.Neon oc.Transparency=0.95 oc.Size=Vector3.new(0.9,0.9,0.9)oc.Parent=m Instance.new("SpecialMesh",oc).MeshType=Enum.MeshType.Sphere oc.SpecialMesh.Scale=Vector3.new(7.7,7.7,7.7)task.spawn(function()while m.Parent do TS:Create(mc,TweenInfo.new(0.55,Enum.EasingStyle.Sine),{Transparency=0.95}):Play();TS:Create(oc,TweenInfo.new(0.7,Enum.EasingStyle.Sine),{Transparency=0.6}):Play();task.wait(0.55);TS:Create(oc,TweenInfo.new(0.5,Enum.EasingStyle.Sine),{Transparency=0.95}):Play();TS:Create(mc,TweenInfo.new(0.5,Enum.EasingStyle.Sine),{Transparency=0.6}):Play();task.wait(0.35)end end)return m end local cur=nil local char=P.Character or P.CharacterAdded:Wait()task.spawn(function()while true do local ff=char and char:FindFirstChildOfClass("ForceField")if ff then ff.Visible=false;if not cur then cur=build()end else if cur then cur:Destroy();cur=nil end end task.wait(0.1)end end)RS.PreRender:Connect(function()if not cur or not char then return end local t=torso(char)if not t then return end local cf=t.CFrame for _,p in ipairs(cur:GetDescendants())do if p:IsA("BasePart")then p.CFrame=cf end end end)P.CharacterAdded:Connect(function(c)char=c;if cur then cur:Destroy();cur=nil end end)]],
    BetterEmotes = [[loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-7yd7-I-Emote-Script-48024"))()]],
}

local ScriptMap = {
    topbar = {["2020"]="Topbar_2020",["2016_Adv"]="Topbar_2016_A",["2016_Simp"]="Topbar_2016_S",["2014"]="Topbar_2014",["2013"]="Topbar_2013",["2012"]="Topbar_2012",["Old_Chat"]="Topbar_OldChat"},
    safechat = {["true"]="SafeChat"}, backpack = {["simple"]="Backpack_Simple",["advanced"]="Backpack_Advanced"},
    animations = {["R6_2008"]="Anims_R6_2008",["R6_2006"]="Anims_R6_2006",["R15_2008"]="Anims_R15_2008",["R15_Old"]="Anims_R15_Old"},
    sounds = {["true"]="OldSounds"}, textures = {["2006"]="Textures_2006",["2016"]="Textures_2016"},
    forcefield = {["true"]="Forcefield"}, emotes = {["true"]="BetterEmotes"},
}

-- ============================================================================
-- SOUNDS & GUI SETUP
-- ============================================================================
local ClickSnd = Instance.new("Sound") ClickSnd.SoundId = "rbxassetid://12221967" ClickSnd.Volume = 0.5 ClickSnd.Parent = SoundService
local function PlayClick() pcall(function() ClickSnd:Stop(); ClickSnd:Play() end) end

local Gui = Instance.new("ScreenGui") Gui.Name = "BloxyParadoxV2" Gui.ResetOnSpawn = false Gui.Parent = PlayerGui
local Overlay = Instance.new("Frame") Overlay.Size = UDim2.new(1, 0, 1, 0) Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) Overlay.BackgroundTransparency = T.OverlayTransparency Overlay.ZIndex = 50 Overlay.Parent = Gui

-- Scaled Up Main Container (560x500)
local Main = Instance.new("Frame") Main.Size = UDim2.new(0, 560, 0, 500) Main.Position = UDim2.new(0.5, -280, 0.5, 300) Main.BackgroundColor3 = T.Surface Main.BorderSizePixel = 0 Main.ClipsDescendants = true Main.ZIndex = 100 Main.Parent = Gui Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local ProgBg = Instance.new("Frame") ProgBg.Size = UDim2.new(1, 0, 0, 5) ProgBg.BackgroundColor3 = T.Border ProgBg.BorderSizePixel = 0 ProgBg.ZIndex = 110 ProgBg.Parent = Main
local ProgFill = Instance.new("Frame") ProgFill.Size = UDim2.new(0, 0, 1, 0) ProgFill.BackgroundColor3 = T.Primary ProgFill.BorderSizePixel = 0 ProgFill.ZIndex = 111 ProgFill.Parent = ProgBg

local Header = Instance.new("Frame") Header.Size = UDim2.new(1, 0, 0, 70) Header.BackgroundTransparency = 1 Header.ZIndex = 105 Header.Parent = Main
local Logo = Instance.new("ImageLabel") Logo.Size = UDim2.new(0, 55, 0, 55) Logo.Position = UDim2.new(0, 20, 0, 8) Logo.BackgroundTransparency = 1 Logo.Image = "rbxthumb://type=Asset&id=131822012703327&w=420&h=420" Logo.ZIndex = 106 Logo.Parent = Header
local Title = Instance.new("TextLabel") Title.Size = UDim2.new(0.6, 0, 0, 26) Title.Position = UDim2.new(0, 85, 0, 8) Title.BackgroundTransparency = 1 Title.Text = "Bloxy Paradox" Title.Font = Enum.Font.GothamBold Title.TextSize = 22 Title.TextColor3 = T.TextPrimary Title.TextXAlignment = Enum.TextXAlignment.Left Title.ZIndex = 106 Title.Parent = Header
local StepTxt = Instance.new("TextLabel") StepTxt.Size = UDim2.new(0.6, 0, 0, 20) StepTxt.Position = UDim2.new(0, 85, 0, 38) StepTxt.BackgroundTransparency = 1 StepTxt.Text = "Step 1 of 8" StepTxt.Font = Enum.Font.Gotham StepTxt.TextSize = 13 StepTxt.TextColor3 = T.TextMuted StepTxt.TextXAlignment = Enum.TextXAlignment.Left StepTxt.ZIndex = 106 StepTxt.Parent = Header

-- Dark Mode Toggle
local Toggle = Instance.new("TextButton") Toggle.Size = UDim2.new(0, 50, 0, 28) Toggle.Position = UDim2.new(1, -65, 0, 22) Toggle.BackgroundColor3 = T.ToggleOff Toggle.Text = IsDark and "🌙" or "☀️" Toggle.TextSize = 16 Toggle.TextColor3 = Color3.new(1, 1, 1) Toggle.Font = Enum.Font.Gotham Toggle.AutoButtonColor = false Toggle.BorderSizePixel = 0 Toggle.ZIndex = 110 Toggle.Parent = Header Instance.new("UICorner", Toggle).CornerRadius = UDim.new(1, 0)

Toggle.MouseButton1Click:Connect(function()
    PlayClick() IsDark = not IsDark T = IsDark and Themes.Dark or Themes.Light Toggle.Text = IsDark and "🌙" or "☀️"
    SafeTween(Toggle, TweenInfo.new(0.2), {BackgroundColor3 = IsDark and T.ToggleOn or T.ToggleOff})
    SafeTween(Main, TweenInfo.new(0.25), {BackgroundColor3 = T.Surface})
    SafeTween(Overlay, TweenInfo.new(0.25), {BackgroundTransparency = T.OverlayTransparency})
    SafeTween(ProgBg, TweenInfo.new(0.25), {BackgroundColor3 = T.Border})
    SafeTween(Title, TweenInfo.new(0.2), {TextColor3 = T.TextPrimary})
    SafeTween(StepTxt, TweenInfo.new(0.2), {TextColor3 = T.TextMuted})
    SafeTween(Question, TweenInfo.new(0.2), {TextColor3 = T.TextSecondary})
    if State.CurrentStep > 0 then ShowStep(State.CurrentStep) end
end)

local Question = Instance.new("TextLabel") Question.Size = UDim2.new(1, -40, 0, 35) Question.Position = UDim2.new(0, 20, 0, 80) Question.BackgroundTransparency = 1 Question.Text = "" Question.Font = Enum.Font.GothamMedium Question.TextSize = 17 Question.TextColor3 = T.TextSecondary Question.TextWrapped = true Question.ZIndex = 105 Question.Parent = Main

local Content = Instance.new("Frame") Content.Size = UDim2.new(1, -40, 0, 140) Content.Position = UDim2.new(0, 20, 0, 120) Content.BackgroundTransparency = 1 Content.ClipsDescendants = true Content.ZIndex = 105 Content.Parent = Main
local BtnArea = Instance.new("Frame") BtnArea.Size = UDim2.new(1, -40, 0, 44) BtnArea.Position = UDim2.new(0, 20, 1, -60) BtnArea.BackgroundTransparency = 1 BtnArea.ZIndex = 105 BtnArea.Parent = Main

-- ============================================================================
-- BUTTON FACTORY
-- ============================================================================
local function MakeBtn(props)
    local btn = Instance.new("TextButton")
    btn.Size = props.size or UDim2.new(0, 100, 0, 44)
    btn.Position = props.pos or UDim2.new(0, 0, 0, 0)
    btn.BackgroundColor3 = props.bg or T.Primary
    btn.TextColor3 = props.fg or T.TextOnPrimary
    btn.Text = props.text or "" btn.Font = Enum.Font.GothamMedium btn.TextSize = props.textSize or 15
    btn.AutoButtonColor = false btn.BorderSizePixel = 0 btn.ZIndex = 106 btn.Parent = props.parent or BtnArea
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    
    btn.MouseEnter:Connect(function() if btn.Active then SafeTween(btn, TweenInfo.new(0.15), {BackgroundColor3 = props.hover or T.PrimaryDark}) end end)
    btn.MouseLeave:Connect(function() SafeTween(btn, TweenInfo.new(0.15), {BackgroundColor3 = props.bg or T.Primary}) end)
    btn.MouseButton1Click:Connect(function() PlayClick() if props.onClick then props.onClick() end end)
    return btn
end

-- Navigation Buttons
local BackBtn = MakeBtn({size=UDim2.new(0, 100, 0, 44), pos=UDim2.new(0, 0, 0, 0), bg=T.Border, fg=T.TextSecondary, hover=T.Hover, text="← Back"})
BackBtn.Visible = false

local SkipBtn = MakeBtn({size=UDim2.new(0, 100, 0, 44), pos=UDim2.new(0, 110, 0, 0), bg=T.Border, fg=T.TextMuted, hover=T.Hover, text="Skip →"})

local NextBtn = MakeBtn({size=UDim2.new(0, 120, 0, 44), pos=UDim2.new(1, -230, 0, 0), bg=T.Primary, hover=T.PrimaryDark, text="Continue →"})

-- CLOSE BUTTON (Bottom Right) - FIXED POSITIONING
local CloseXBtn = MakeBtn({
    size = UDim2.new(0, 44, 0, 44), 
    pos = UDim2.new(1, -54, 0, 0), -- Offset -54 pushes it back inside the left edge by 54px (44px width + 10px padding)
    bg = T.CloseBtn, 
    fg = T.TextMuted, 
    hover = Color3.fromRGB(200, 80, 80),
    text = "✕", 
    textSize = 20
})

-- ============================================================================
-- CLEANUP & CLOSE WIZARD
-- ============================================================================
local function CloseWizard()
    CancelAllTweens()
    SafeTween(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0.5, -280, 0.5, 300), Size = UDim2.new(0, 560, 0, 0)})
    SafeTween(Overlay, TweenInfo.new(0.4), {BackgroundTransparency = 1})
    task.delay(0.45, function() pcall(function() Gui:Destroy() end) end)
end

CloseXBtn.MouseButton1Click:Connect(CloseWizard)

-- ============================================================================
-- STEP BUILDERS
-- ============================================================================
local function ClearContent() for _, c in ipairs(Content:GetChildren()) do c:Destroy() end end

local function UpdateProgress()
    SafeTween(ProgFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(State.CurrentStep / State.TotalSteps, 0, 1, 0)})
    StepTxt.Text = string.format("Step %d of %d", State.CurrentStep, State.TotalSteps)
    BackBtn.Visible = State.CurrentStep > 1
    SkipBtn.Visible = State.CurrentStep < State.TotalSteps
    NextBtn.Visible = not State.IsComplete
    CloseXBtn.Visible = true
    
    SafeProperty(BackBtn, "BackgroundColor3", T.Border) SafeProperty(BackBtn, "TextColor3", T.TextSecondary)
    SafeProperty(SkipBtn, "BackgroundColor3", T.Border) SafeProperty(SkipBtn, "TextColor3", T.TextMuted)
    SafeProperty(NextBtn, "BackgroundColor3", T.Primary) SafeProperty(NextBtn, "TextColor3", T.TextOnPrimary)
    SafeProperty(CloseXBtn, "BackgroundColor3", T.CloseBtn) SafeProperty(CloseXBtn, "TextColor3", T.TextMuted)
end

local DropdownOpts = {
    {text = "2020 PC", id = "2020"}, {text = "2016 (No Chat)", id = "2016_Adv"}, {text = "2016 Simple", id = "2016_Simp"},
    {text = "2014", id = "2014"}, {text = "2013", id = "2013"}, {text = "2012", id = "2012"},
    {text = "Old Chat Only", id = "Old_Chat"}, {text = "None", id = "none"},
}

local function BuildDropdown()
    ClearContent()
    local sel = State.Selections.topbar or "none" 
    local selIdx = 1
    for i, o in ipairs(DropdownOpts) do if o.id == sel then selIdx = i; break end end

    local dd = Instance.new("TextButton") dd.Size = UDim2.new(1, 0, 0, 44) dd.BackgroundColor3 = T.InputBg dd.TextColor3 = T.TextPrimary dd.Text = "  " .. DropdownOpts[selIdx].text dd.Font = Enum.Font.GothamMedium dd.TextSize = 16 dd.TextXAlignment = Enum.TextXAlignment.Left dd.AutoButtonColor = false dd.BorderSizePixel = 1 dd.BorderColor3 = T.Border dd.ZIndex = 106 dd.Parent = Content Instance.new("UICorner", dd).CornerRadius = UDim.new(0, 10) Instance.new("UIPadding", dd).PaddingLeft = UDim.new(0, 12)

    local open = false
    local list = Instance.new("Frame") list.Size = UDim2.new(1, 0, 0, 0) list.Position = UDim2.new(0, 0, 1, 4) list.BackgroundColor3 = T.Surface list.BorderSizePixel = 1 list.BorderColor3 = T.Border list.ClipsDescendants = true list.Visible = false list.ZIndex = 110 list.Parent = dd Instance.new("UICorner", list).CornerRadius = UDim.new(0, 10)

    local scroll = Instance.new("ScrollingFrame") scroll.Size = UDim2.new(1, -6, 1, -6) scroll.Position = UDim2.new(0, 3, 0, 3) scroll.BackgroundTransparency = 1 scroll.ScrollBarThickness = 4 scroll.ScrollBarImageColor3 = T.Primary scroll.CanvasSize = UDim2.new(0, 0, 0, #DropdownOpts * 38) scroll.ZIndex = 111 scroll.Parent = list Instance.new("UIListLayout", scroll)

    for i, opt in ipairs(DropdownOpts) do
        local ob = Instance.new("TextButton") ob.Size = UDim2.new(1, 0, 0, 38) ob.BackgroundTransparency = 1 ob.Text = "  " .. opt.text ob.Font = Enum.Font.Gotham ob.TextSize = 15 ob.TextColor3 = opt.id == sel and T.Primary or T.TextPrimary ob.TextXAlignment = Enum.TextXAlignment.Left ob.AutoButtonColor = false ob.ZIndex = 112 ob.Parent = scroll Instance.new("UIPadding", ob).PaddingLeft = UDim.new(0, 10)

        ob.MouseEnter:Connect(function() SafeTween(ob, TweenInfo.new(0.1), {BackgroundTransparency = 0, BackgroundColor3 = T.Hover}) end)
        ob.MouseLeave:Connect(function() SafeProperty(ob, "BackgroundTransparency", 1) end)
        
        ob.MouseButton1Click:Connect(function()
            PlayClick()
            sel = opt.id
            State.Selections.topbar = opt.id -- SAVED PROPERLY
            dd.Text = "  " .. opt.text
            open = false; list.Visible = false
            for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then SafeProperty(c, "TextColor3", T.TextPrimary) end end
            SafeProperty(ob, "TextColor3", T.Primary)
        end)
    end

    dd.MouseButton1Click:Connect(function()
        PlayClick() open = not open list.Visible = open
        SafeTween(list, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, open and math.min(#DropdownOpts * 38, 180) or 0)})
    end)
end

local function BuildYesNo()
    ClearContent()
    local w = (560 - 80) / 2 - 10
    local stepId = Steps[State.CurrentStep].id
    local val = State.Selections[stepId]
    
    local yes = Instance.new("TextButton") yes.Size = UDim2.new(0, w, 0, 44) yes.Position = UDim2.new(0, 0, 0, 0) yes.BackgroundColor3 = val == "true" and T.Primary or T.Background yes.TextColor3 = val == "true" and T.TextOnPrimary or T.TextSecondary yes.Text = "Yes" yes.Font = Enum.Font.GothamMedium yes.TextSize = 16 yes.AutoButtonColor = false yes.BorderSizePixel = 0 yes.ZIndex = 106 yes.Parent = Content Instance.new("UICorner", yes).CornerRadius = UDim.new(0, 10)

    local no = Instance.new("TextButton") no.Size = UDim2.new(0, w, 0, 44) no.Position = UDim2.new(1, -w, 0, 0) no.BackgroundColor3 = val == "false" and T.Primary or T.Background no.TextColor3 = val == "false" and T.TextOnPrimary or T.TextSecondary no.Text = "No" no.Font = Enum.Font.GothamMedium no.TextSize = 16 no.AutoButtonColor = false no.BorderSizePixel = 1 no.BorderColor3 = T.Border no.ZIndex = 106 no.Parent = Content Instance.new("UICorner", no).CornerRadius = UDim.new(0, 10)

    local function update(yesSel)
        SafeTween(yes, TweenInfo.new(0.2), {BackgroundColor3 = yesSel and T.Primary or T.Background, TextColor3 = yesSel and T.TextOnPrimary or T.TextSecondary})
        SafeTween(no, TweenInfo.new(0.2), {BackgroundColor3 = not yesSel and T.Primary or T.Background, TextColor3 = not yesSel and T.TextOnPrimary or T.TextSecondary, BorderSizePixel = not yesSel and 0 or 1})
    end

    yes.MouseButton1Click:Connect(function() PlayClick() State.Selections[stepId] = "true" update(true) end)
    no.MouseButton1Click:Connect(function() PlayClick() State.Selections[stepId] = "false" update(false) end)
end

local function BuildTriple(labels, values)
    ClearContent()
    local stepId = Steps[State.CurrentStep].id
    local val = State.Selections[stepId]
    local w = (560 - 80) / 3 - 10

    for i, label in ipairs(labels) do
        local btn = Instance.new("TextButton") btn.Size = UDim2.new(0, w, 0, 44) btn.Position = UDim2.new(0, i * (w + 10) - w - 10, 0, 0)
        btn.BackgroundColor3 = val == values[i] and T.Primary or T.Background btn.TextColor3 = val == values[i] and T.TextOnPrimary or T.TextSecondary
        btn.Text = label btn.Font = Enum.Font.GothamMedium btn.TextSize = 13 btn.TextWrapped = true btn.AutoButtonColor = false
        btn.BorderSizePixel = val == values[i] and 0 or 1 btn.BorderColor3 = T.Border btn.ZIndex = 106 btn.Parent = Content Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        btn.MouseButton1Click:Connect(function()
            PlayClick() State.Selections[stepId] = values[i]
            for _, sib in ipairs(Content:GetChildren()) do if sib:IsA("TextButton") then SafeTween(sib, TweenInfo.new(0.15), {BackgroundColor3 = T.Background, TextColor3 = T.TextSecondary, BorderSizePixel = 1}) end end
            SafeTween(btn, TweenInfo.new(0.15), {BackgroundColor3 = T.Primary, TextColor3 = T.TextOnPrimary, BorderSizePixel = 0})
        end)
    end
end

local function BuildAnims()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local isR6 = hum.RigType == Enum.HumanoidRigType.R6
    if isR6 then BuildTriple({"2008 W.I.P", "2006 W.I.P", "Normal"}, {"R6_2008", "R6_2006", "normal"})
    else BuildTriple({"2008 R15", "Old R15", "Normal"}, {"R15_2008", "R15_Old", "normal"}) end
    local rig = Instance.new("TextLabel") rig.Size = UDim2.new(1, 0, 0, 20) rig.Position = UDim2.new(0, 0, 1, -24) rig.BackgroundTransparency = 1 rig.Text = isR6 and "R6 Rig Detected" or "R15 Rig Detected" rig.Font = Enum.Font.Gotham rig.TextSize = 12 rig.TextColor3 = T.TextMuted rig.ZIndex = 106 rig.Parent = Content
end

-- ============================================================================
-- SHOW STEP & COMPLETE
-- ============================================================================
function ShowStep(num)
    State.CurrentStep = num
    local step = Steps[num]
    Title.Text = step.title Question.Text = step.question
    UpdateProgress()

    if step.type == "dropdown" then BuildDropdown()
    elseif step.type == "yesno" then BuildYesNo()
    elseif step.type == "triple" then
        if step.id == "backpack" then BuildTriple({"No", "Simple 2008", "Advanced"}, {"none", "simple", "advanced"})
        elseif step.id == "textures" then BuildTriple({"2006 Textures", "2016 Textures", "Normal"}, {"2006", "2016", "normal"})
        end
    elseif step.type == "dynamic" then BuildAnims() end
    
    SafeProperty(Content, "Position", UDim2.new(0, 20, 0, 128))
    SafeTween(Content, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 20, 0, 120)})
end

local function ShowComplete()
    State.IsComplete = true ClearContent()
    Title.Text = "Setup Complete!" Question.Text = "Review your choices below:" StepTxt.Text = "All Done"
    BackBtn.Visible = false SkipBtn.Visible = false NextBtn.Visible = false
    Content.Size = UDim2.new(1, -40, 0, 200)
    
    local scroll = Instance.new("ScrollingFrame") scroll.Size = UDim2.new(1, 0, 1, 0) scroll.BackgroundTransparency = 1 scroll.ScrollBarThickness = 4 scroll.ScrollBarImageColor3 = T.Primary scroll.CanvasSize = UDim2.new(0, 0, 0, 0) scroll.ZIndex = 106 scroll.Parent = Content
    local lay = Instance.new("UIListLayout") lay.Padding = UDim.new(0, 6) lay.Parent = scroll

    local labels = {
        topbar = {none="None",["2020"]="2020 PC",["2016_Adv"]="2016 No Chat",["2016_Simp"]="2016 Simple",["2014"]="2014",["2013"]="2013",["2012"]="2012",["Old_Chat"]="Old Chat"},
        safechat = {["true"]="Yes",["false"]="No"}, backpack = {none="Default",simple="Simple",advanced="Advanced"},
        animations = {normal="Default",["R6_2008"]="2008 R6",["R6_2006"]="2006 R6",["R15_2008"]="2008 R15",["R15_Old"]="Old R15"},
        sounds = {["true"]="Yes",["false"]="No"}, textures = {normal="Default",["2006"]="2006",["2016"]="2016"},
        forcefield = {["true"]="Yes",["false"]="No"}, emotes = {["true"]="Yes",["false"]="No"},
    }

    for _, step in ipairs(Steps) do
        local v = State.Selections[step.id]
        local display = v and (labels[step.id] and labels[step.id][v] or v) or "Not set"
        local isDef = v == "none" or v == "false" or v == "normal"
        
        local row = Instance.new("Frame") row.Size = UDim2.new(1, 0, 0, 32) row.BackgroundColor3 = isDef and T.Background or T.PrimarySubtle row.BorderSizePixel = 0 row.ZIndex = 107 row.Parent = scroll Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local n = Instance.new("TextLabel") n.Size = UDim2.new(0.4, 0, 1, 0) n.Position = UDim2.new(0, 12, 0, 0) n.BackgroundTransparency = 1 n.Text = step.title n.Font = Enum.Font.GothamMedium n.TextSize = 14 n.TextColor3 = T.TextSecondary n.TextXAlignment = Enum.TextXAlignment.Left n.ZIndex = 108 n.Parent = row
        local vl = Instance.new("TextLabel") vl.Size = UDim2.new(0.6, -12, 1, 0) vl.Position = UDim2.new(0.4, 0, 0, 0) vl.BackgroundTransparency = 1 vl.Text = display vl.Font = Enum.Font.GothamBold vl.TextSize = 14 vl.TextColor3 = isDef and T.TextMuted or T.Primary vl.TextXAlignment = Enum.TextXAlignment.Right vl.ZIndex = 108 vl.Parent = row
    end
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y) end)

    MakeBtn({size=UDim2.new(0.48, -10, 0, 44), pos=UDim2.new(0, 0, 0, 0), bg=T.Success, hover=Color3.fromRGB(56, 142, 60), text="✓ Apply All", parent=BtnArea, onClick=function()
        for _, step in ipairs(Steps) do
            local v = State.Selections[step.id]
            if v and v ~= "none" and v ~= "false" and v ~= "normal" then
                local map = ScriptMap[step.id]
                if map and map[v] and Scripts[map[v]] then pcall(function() loadstring(Scripts[map[v]])() end) task.wait(0.2) end
            end
        end
        PlayClick() CloseXBtn.Text = "✓" CloseXBtn.Active = false
    end})

        MakeBtn({
        size = UDim2.new(0.5, -5, 0, 44),
        pos = UDim2.new(0.5, 5, 0, 0),   -- right half with a 5px gap
        bg = T.Border,
        fg = T.TextSecondary,
        hover = T.Hover,
        text = "Close",
        parent = BtnArea,
        onClick = CloseWizard
    })
end

-- ============================================================================
-- NAVIGATION LOGIC
-- ============================================================================
BackBtn.MouseButton1Click:Connect(function() if State.CurrentStep > 1 then ShowStep(State.CurrentStep - 1) end end)
SkipBtn.MouseButton1Click:Connect(function() if State.CurrentStep < State.TotalSteps then ShowStep(State.CurrentStep + 1) end end)
NextBtn.MouseButton1Click:Connect(function() if State.CurrentStep < State.TotalSteps then ShowStep(State.CurrentStep + 1) else ShowComplete() end end)

game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Escape then CloseWizard()
    elseif input.KeyCode == Enum.KeyCode.Return then
        if not State.IsComplete then
            if State.CurrentStep < State.TotalSteps then ShowStep(State.CurrentStep + 1) else ShowComplete() end
        end
    end
end)

-- ============================================================================
-- ENTRANCE ANIMATION
-- ============================================================================
Main.Size = UDim2.new(0, 560, 0, 0) Main.Position = UDim2.new(0.5, -280, 0.5, 250)
task.wait(0.1)
SafeTween(Main, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 560, 0, 500), Position = UDim2.new(0.5, -280, 0.5, -250)})
SafeTween(Overlay, TweenInfo.new(0.5), {BackgroundTransparency = T.OverlayTransparency})

task.wait(0.6)
ShowStep(1)
