-- ========== UTILITIES ==========
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInput = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

getgenv().TAS_CameraFollow = getgenv().TAS_CameraFollow or false
getgenv().TAS_Slowmo = getgenv().TAS_Slowmo or false

local function deepCopy(t)
    local r = {}; for k,v in pairs(t) do r[k]=type(v)=="table" and deepCopy(v) or v end; return r
end

local function showError(msg)
    warn("TAS ERROR: " .. tostring(msg))
end

local function animateToggle(toggle, state)
    local onCol = Color3.fromRGB(200,200,200)
    local offCol = Color3.fromRGB(60,60,60)
    local goal = state and onCol or offCol
    TweenService:Create(toggle, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = goal}):Play()
    TweenService:Create(toggle.Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {ImageTransparency = state and 0 or 0.6}):Play()
end

-- ========== SETTINGS ==========
local SETTINGS_PATH = "TAS_Settings.json"
local default_settings = {
    theme = "Grayscale",
    tas_key_record = Enum.KeyCode.R,
    tas_key_play = Enum.KeyCode.P,
    tas_key_stop = Enum.KeyCode.T,
    tas_key_pause = Enum.KeyCode.F,
    tas_key_frameadvance = Enum.KeyCode.Equals, -- = key (shift+equals)
    tas_key_rewind = Enum.KeyCode.Y,
    tas_key_fastforward = Enum.KeyCode.U,
    tas_profile = "default",
    profiles = {},
    camera_follow = getgenv().TAS_CameraFollow,
    slowmo = getgenv().TAS_Slowmo
}
local settings = deepCopy(default_settings)
local function saveSettings()
    local tbl = {}
    for k,v in pairs(settings) do
        if typeof(v)=="EnumItem" and v.EnumType==Enum.KeyCode then tbl[k]=v.Name
        elseif type(v)=="table" then tbl[k]=v
        else tbl[k]=v end
    end
    if writefile then
        writefile(SETTINGS_PATH, HttpService:JSONEncode(tbl))
    end
end
local function loadSettings()
    if isfile and isfile(SETTINGS_PATH) then
        local ok,dat = pcall(function() return readfile(SETTINGS_PATH) end)
        if ok and dat then
            local ok2,js=pcall(function() return HttpService:JSONDecode(dat) end)
            if ok2 and js then
                for k,v in pairs(js) do
                    if k:find("_key") then settings[k]=Enum.KeyCode[v] or settings[k]
                    elseif k=="profiles" then settings[k]=v
                    else settings[k]=v end
                end
            end
        end
    end
    -- PATCH: Write loaded settings into globals
    getgenv().TAS_CameraFollow = settings.camera_follow
    getgenv().TAS_Slowmo = settings.slowmo
end
loadSettings()

-- ========== UI ==========
local gui=Instance.new("ScreenGui",LocalPlayer.PlayerGui)
gui.Name="TAS_UI"
gui.ResetOnSpawn = false
local main=Instance.new("Frame",gui)
main.Size=UDim2.new(0,560,0,520)
main.Position=UDim2.new(0.5,-280,0.5,-260)
main.BackgroundTransparency=0
main.BackgroundColor3=Color3.fromRGB(34,34,34)
main.BorderSizePixel=0
Instance.new("UICorner",main).CornerRadius=UDim.new(0,22)
local header=Instance.new("Frame",main);header.Size=UDim2.new(1,0,0,60)
header.BackgroundColor3=Color3.fromRGB(60,60,60)
header.BackgroundTransparency=0;header.BorderSizePixel=0
Instance.new("UICorner",header).CornerRadius=UDim.new(0,22)
local title=Instance.new("TextLabel",header)
title.Text="TAS Recorder/Player"
title.Font=Enum.Font.GothamBlack
title.TextColor3=Color3.fromRGB(220,220,220)
title.TextSize=36
title.AnchorPoint=Vector2.new(0,0.5)
title.Position=UDim2.new(0.05,0,0.5,0)
title.Size=UDim2.new(1,0,1,0)
title.BackgroundTransparency=1
title.TextXAlignment=Enum.TextXAlignment.Left

local tabnames={"TAS","Profiles","Settings"}
local tabframes, tabbtns = {},{}
local tabbar=Instance.new("Frame",main)
tabbar.Position=UDim2.new(0,0,0,60)
tabbar.Size=UDim2.new(1,0,0,38)
tabbar.BackgroundTransparency=1
local tablayout=Instance.new("UIListLayout",tabbar)
tablayout.FillDirection=Enum.FillDirection.Horizontal
tablayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
tablayout.Padding=UDim.new(0,12)
for i,tabn in ipairs(tabnames) do
    local btn=Instance.new("TextButton");btn.Name=tabn;btn.Text=tabn;btn.Font=Enum.Font.GothamMedium
    btn.TextColor3=Color3.fromRGB(210,210,210)
    btn.TextSize=20
    btn.Size=UDim2.new(0,math.floor(520/#tabnames),0,30)
    btn.BackgroundColor3=Color3.fromRGB(80,80,80)
    btn.BackgroundTransparency=0
    btn.AutoButtonColor=false;btn.ZIndex=4;btn.Parent=tabbar
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,12);tabbtns[tabn]=btn
end
local contentframe=Instance.new("Frame",main)
contentframe.Position=UDim2.new(0,0,0,98)
contentframe.Size=UDim2.new(1,0,1,-98)
contentframe.BackgroundColor3=Color3.fromRGB(44,44,44)
contentframe.BackgroundTransparency=0
contentframe.BorderSizePixel=0
contentframe.ClipsDescendants=true
Instance.new("UICorner",contentframe).CornerRadius=UDim.new(0,18)
for _,tabn in ipairs(tabnames) do
    local f=Instance.new("Frame",contentframe);f.Visible=false;f.Size=UDim2.new(1,-32,1,-32);f.Position=UDim2.new(0,16,0,16);f.BackgroundTransparency=1;tabframes[tabn]=f
end
local function switchTab(tabn)
    for name,frame in pairs(tabframes) do frame.Visible=(name==tabn) end
    for name,btn in pairs(tabbtns) do
        btn.BackgroundColor3=(name==tabn) and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80)
        btn.TextColor3=(name==tabn) and Color3.fromRGB(40,40,40) or Color3.fromRGB(210,210,210)
    end
end
for name,btn in pairs(tabbtns) do btn.MouseButton1Click:Connect(function()switchTab(name)end) end
switchTab("TAS")
-- Dragging
local dragging,draginput,dragstart,startpos,velocity,lastupdate=false,nil,nil,nil,Vector2.new(0,0),tick()
header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true;dragstart=input.Position;startpos=main.Position;velocity=Vector2.new(0,0);lastupdate=tick()
        input.Changed:Connect(function()if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
header.InputChanged:Connect(function(input)if input.UserInputType==Enum.UserInputType.MouseMovement then draginput=input end end)
UserInput.InputChanged:Connect(function(input)
    if input==draginput and dragging then
        local delta=input.Position-dragstart;local dt=math.max(tick()-lastupdate,0.01)
        velocity=velocity:Lerp(Vector2.new(delta.X/dt,delta.Y/dt),0.2)
        main.Position=startpos+UDim2.new(0,delta.X,0,delta.Y);lastupdate=tick()
    end
end)
RunService.RenderStepped:Connect(function(dt)
    if not dragging and(math.abs(velocity.X)>1 or math.abs(velocity.Y)>1)then
        main.Position=main.Position+UDim2.new(0,velocity.X*dt,0,velocity.Y*dt);velocity=velocity*0.88
    end
end)

-- === Custom Grayscale Toggle ===
local function grayscaleToggle(parent, label, getValue, setValue)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(0,180,0,36)
    frame.BackgroundTransparency = 1
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0,44,0,28)
    btn.Position = UDim2.new(0,0,0,4)
    btn.BackgroundColor3 = getValue() and Color3.fromRGB(200,200,200) or Color3.fromRGB(60,60,60)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,14)
    local icon = Instance.new("ImageLabel",btn)
    icon.Name = "Icon"
    icon.Size = UDim2.new(0,18,0,18)
    icon.Position = UDim2.new(0.5,-9,0.5,-9)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://6023426923" -- checkmark icon
    icon.ImageColor3 = Color3.fromRGB(255,255,255)
    icon.ImageTransparency = getValue() and 0 or 0.6
    local txt = Instance.new("TextLabel",frame)
    txt.Text = label
    txt.Size = UDim2.new(1,-54,1,0)
    txt.Position = UDim2.new(0,54,0,0)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamBold
    txt.TextColor3 = Color3.fromRGB(210,210,210)
    txt.TextSize = 18
    btn.MouseButton1Click:Connect(function()
        setValue(not getValue())
        animateToggle(btn, getValue())
    end)
    animateToggle(btn, getValue())
    return frame
end

local function keybindPicker(parent,label,getValue,setValue)
    local picking=false
    local btn=Instance.new("TextButton")
    btn.Text=label..": ["..getValue().Name.."]"
    btn.Size=UDim2.new(0,140,0,32)
    btn.Font=Enum.Font.GothamBold
    btn.TextColor3=Color3.fromRGB(200,200,200)
    btn.BackgroundColor3=Color3.fromRGB(70,70,70)
    btn.BackgroundTransparency=0
    btn.Parent=parent
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,10)
    btn.MouseButton1Click:Connect(function()
        btn.Text=label..": [Press any key]"
        picking=true
        local startTime = tick()
        local conn
        conn = UserInput.InputBegan:Connect(function(input)
            if picking and input.UserInputType==Enum.UserInputType.Keyboard then
                setValue(input.KeyCode)
                btn.Text=label..": ["..input.KeyCode.Name.."]"
                picking=false
                saveSettings()
                conn:Disconnect()
            elseif picking and input.UserInputType~=Enum.UserInputType.Keyboard then
                -- Cancel on any mouse click elsewhere
                picking=false
                btn.Text = label .. ": [" .. getValue().Name .. "]"
                conn:Disconnect()
            end
        end)
        -- Timeout as additional safety
        spawn(function()
            wait(5)
            if picking then
                picking=false
                btn.Text = label .. ": [" .. getValue().Name .. "]"
                if conn then conn:Disconnect() end
            end
        end)
    end)
    return btn
end

-- ========== TAS CORE ==========
local tas = {
    recording = false,
    playing = false,
    paused = false,
    events = {},  -- per-frame snapshot: {t, keys, mouse, cframe}
    time0 = 0,
    frame = 1,
    len = 0,
    camera = {},
    slowmo_was = nil,
    playStartTime = 0,
}
local function resetTAS()
    tas.recording=false
    tas.playing=false
    tas.paused=false
    tas.events={}
    tas.camera={}
    tas.time0=0
    tas.frame=1
    tas.len=0
    tas.playStartTime=0
end

-- === UI: TAS Tab ===
local statusLabel
do
    local tab = tabframes["TAS"]
    local y = 0
    local recBtn = Instance.new("TextButton",tab)
    recBtn.Text = "Record"
    recBtn.Size = UDim2.new(0,100,0,38)
    recBtn.Position = UDim2.new(0,8,0,y)
    recBtn.Font = Enum.Font.GothamBold
    recBtn.TextSize = 20
    recBtn.BackgroundColor3=Color3.fromRGB(100,100,100)
    recBtn.TextColor3=Color3.fromRGB(220,220,220)
    Instance.new("UICorner",recBtn).CornerRadius=UDim.new(0,8)
    recBtn.MouseButton1Click:Connect(function()
        if not tas.recording then
            resetTAS()
            tas.recording = true
            tas.time0 = tick()
            recBtn.Text = "Recording..."
        else
            tas.recording = false
            tas.len = #tas.events
            recBtn.Text = "Record"
        end
    end)
    local playBtn = Instance.new("TextButton",tab)
    playBtn.Text = "Play"
    playBtn.Size = UDim2.new(0,100,0,38)
    playBtn.Position = UDim2.new(0,120,0,y)
    playBtn.Font = Enum.Font.GothamBold
    playBtn.TextSize = 20
    playBtn.BackgroundColor3=Color3.fromRGB(100,100,100)
    playBtn.TextColor3=Color3.fromRGB(220,220,220)
    Instance.new("UICorner",playBtn).CornerRadius=UDim.new(0,8)
    playBtn.MouseButton1Click:Connect(function()
        if not tas.playing and #tas.events > 0 then
            tas.playing = true
            tas.paused = false
            tas.frame = 1
            tas.playStartTime = tick()
            playBtn.Text = "Playing..."
        else
            tas.playing = false
            playBtn.Text = "Play"
        end
    end)
    local stopBtn = Instance.new("TextButton",tab)
    stopBtn.Text = "Stop"
    stopBtn.Size = UDim2.new(0,100,0,38)
    stopBtn.Position = UDim2.new(0,232,0,y)
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 20
    stopBtn.BackgroundColor3=Color3.fromRGB(100,100,100)
    stopBtn.TextColor3=Color3.fromRGB(220,220,220)
    Instance.new("UICorner",stopBtn).CornerRadius=UDim.new(0,8)
    stopBtn.MouseButton1Click:Connect(function()
        tas.recording = false
        tas.playing = false
        tas.paused = false
        recBtn.Text = "Record"
        playBtn.Text = "Play"
    end)
    local frameBtn = Instance.new("TextButton",tab)
    frameBtn.Text = "Frame Advance"
    frameBtn.Size = UDim2.new(0,140,0,38)
    frameBtn.Position = UDim2.new(0,344,0,y)
    frameBtn.Font = Enum.Font.GothamBold
    frameBtn.TextSize = 20
    frameBtn.BackgroundColor3=Color3.fromRGB(80,80,80)
    frameBtn.TextColor3=Color3.fromRGB(220,220,220)
    Instance.new("UICorner",frameBtn).CornerRadius=UDim.new(0,8)
    frameBtn.MouseButton1Click:Connect(function()
        if tas.playing and tas.paused then
            tas.frame=math.min(tas.frame+1, #tas.events)
            tas.playStartTime = tick() - (tas.events[tas.frame] and tas.events[tas.frame].t or 0)
        end
    end)
    y = y+44

    -- Camera Follow Toggle
    local camToggle = grayscaleToggle(tab, "Camera Follow",
        function() return getgenv().TAS_CameraFollow end,
        function(v) getgenv().TAS_CameraFollow = v; settings.camera_follow = v; saveSettings() end
    )
    camToggle.Position = UDim2.new(0,8,0,y)
    camToggle.ZIndex = 2

    -- Slowmo Toggle
    local slowmoToggle = grayscaleToggle(tab, "Slow-Mo Recording",
        function() return getgenv().TAS_Slowmo end,
        function(v) getgenv().TAS_Slowmo = v; settings.slowmo = v; saveSettings() end
    )
    slowmoToggle.Position = UDim2.new(0,200,0,y)
    slowmoToggle.ZIndex = 2

    y = y+44
    local exportBtn = Instance.new("TextButton",tab)
    exportBtn.Text = "Copy TAS (JSON)"
    exportBtn.Size = UDim2.new(0,140,0,32)
    exportBtn.Position = UDim2.new(0,8,0,y)
    exportBtn.Font = Enum.Font.GothamBold
    exportBtn.TextSize = 16
    exportBtn.BackgroundColor3=Color3.fromRGB(120,120,120)
    exportBtn.TextColor3=Color3.fromRGB(220,220,220)
    Instance.new("UICorner",exportBtn).CornerRadius=UDim.new(0,8)
    exportBtn.MouseButton1Click:Connect(function()
        setclipboard(HttpService:JSONEncode({ events = tas.events, camera = tas.camera }))
    end)
    local importBtn = Instance.new("TextButton",tab)
    importBtn.Text = "Paste TAS"
    importBtn.Size = UDim2.new(0,100,0,32)
    importBtn.Position = UDim2.new(0,160,0,y)
    importBtn.Font = Enum.Font.GothamBold
    importBtn.TextSize = 16
    importBtn.BackgroundColor3=Color3.fromRGB(120,120,120)
    importBtn.TextColor3=Color3.fromRGB(220,220,220)
    Instance.new("UICorner",importBtn).CornerRadius=UDim.new(0,8)
    importBtn.MouseButton1Click:Connect(function()
        local ok,dat = pcall(function()
            return HttpService:JSONDecode(getclipboard())
        end)
        if ok and dat then
            tas.events = dat.events or dat
            tas.camera = dat.camera or {}
            tas.len = #tas.events
            showError("TAS loaded.")
        end
    end)
    -- Status Label
    statusLabel = Instance.new("TextLabel",tab)
    statusLabel.Position = UDim2.new(0,8,0,y+36)
    statusLabel.Size = UDim2.new(0,360,0,28)
    statusLabel.Text = "Frame: 1 / 0 | Idle"
    statusLabel.TextColor3 = Color3.fromRGB(220,220,220)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 16
    statusLabel.ZIndex = 2
end

-- UI: Profiles Tab
do
    local tab = tabframes["Profiles"]
    local y=0
    local list = Instance.new("ScrollingFrame",tab)
    list.Position=UDim2.new(0,8,0,y)
    list.Size=UDim2.new(0,380,0,140)
    list.CanvasSize=UDim2.new(0,0,0,400)
    list.BackgroundTransparency=0.14
    list.BackgroundColor3=Color3.fromRGB(80,80,80)
    Instance.new("UICorner",list).CornerRadius=UDim.new(0,16)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local function updateList()
        list:ClearAllChildren()
        local n=0
        for name,_ in pairs(settings.profiles or {}) do
            n=n+1
            local btn=Instance.new("TextButton",list)
            btn.Size=UDim2.new(1,0,0,28)
            btn.Position=UDim2.new(0,0,0,(n-1)*32)
            btn.Text=name..(settings.tas_profile==name and " [ACTIVE]" or "")
            btn.Font=Enum.Font.Gotham
            btn.TextSize=16
            btn.BackgroundColor3=settings.tas_profile==name and Color3.fromRGB(200,200,200) or Color3.fromRGB(80,80,80)
            btn.BackgroundTransparency=0.1
            btn.TextColor3 = Color3.fromRGB(40,40,40)
            btn.MouseButton1Click:Connect(function()
                local dat = settings.profiles[name]
                if dat then
                    tas.events = deepCopy(dat.events or dat)
                    tas.camera = deepCopy(dat.camera or {})
                    tas.len = #tas.events
                    settings.tas_profile = name
                    saveSettings()
                    updateList()
                end
            end)
        end
    end
    updateList()
    local box = Instance.new("TextBox",tab)
    box.Text = "new_profile"
    box.Size = UDim2.new(0,180,0,28)
    box.Position = UDim2.new(0,8,0,150)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 16
    box.BackgroundColor3 = Color3.fromRGB(80,80,80)
    box.BackgroundTransparency = 0.14
    box.TextColor3 = Color3.fromRGB(210,210,210)
    Instance.new("UICorner",box).CornerRadius = UDim.new(0,10)
    local saveBtn=Instance.new("TextButton",tab)
    saveBtn.Text="Save Profile"
    saveBtn.Size=UDim2.new(0,100,0,28)
    saveBtn.Position=UDim2.new(0,200,0,150)
    saveBtn.Font=Enum.Font.GothamBold
    saveBtn.TextSize=16
    saveBtn.BackgroundColor3=Color3.fromRGB(200,200,200)
    saveBtn.TextColor3=Color3.fromRGB(40,40,40)
    saveBtn.MouseButton1Click:Connect(function()
        if box.Text and #box.Text > 0 then
            settings.profiles[box.Text]=deepCopy({events=tas.events, camera=tas.camera})
            settings.tas_profile = box.Text
            saveSettings()
            updateList()
        end
    end)
end

-- UI: Settings Tab
do
    local tab = tabframes["Settings"]
    local y = 0
    keybindPicker(tab,"Record Key",function()return settings.tas_key_record end,function(v)settings.tas_key_record=v end).Position=UDim2.new(0,8,0,y)
    keybindPicker(tab,"Play Key",function()return settings.tas_key_play end,function(v)settings.tas_key_play=v end).Position=UDim2.new(0,160,0,y)
    keybindPicker(tab,"Stop Key",function()return settings.tas_key_stop end,function(v)settings.tas_key_stop=v end).Position=UDim2.new(0,312,0,y)
    keybindPicker(tab,"Pause Key",function()return settings.tas_key_pause end,function(v)settings.tas_key_pause=v end).Position=UDim2.new(0,8,0,y+36)
    keybindPicker(tab,"FrameAdvance Key",function()return settings.tas_key_frameadvance end,function(v)settings.tas_key_frameadvance=v end).Position=UDim2.new(0,160,0,y+36)
    keybindPicker(tab,"Rewind Key",function()return settings.tas_key_rewind end,function(v)settings.tas_key_rewind=v end).Position=UDim2.new(0,312,0,y+36)
    keybindPicker(tab,"FastForward Key",function()return settings.tas_key_fastforward end,function(v)settings.tas_key_fastforward=v end).Position=UDim2.new(0,464,0,y+36)
end

-- ========== RECORDING / PLAYBACK ENGINE ==========
local slowWalk = 6
local slowJump = 25

local function getKeyState()
    local state = {}
    for _,k in ipairs(Enum.KeyCode:GetEnumItems()) do
        if k.Value > 0 then -- avoid Unknown
            state[k.Name] = UserInput:IsKeyDown(k)
        end
    end
    return state
end

-- Handle keybinds and rew/ff/pause/step
UserInput.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    -- Keybinds
    if input.KeyCode == settings.tas_key_record then
        if not tas.recording then
            resetTAS()
            tas.recording = true
            tas.time0 = tick()
        else
            tas.recording = false
            tas.len = #tas.events
        end
    elseif input.KeyCode == settings.tas_key_play then
        if not tas.playing and #tas.events > 0 then
            tas.playing = true
            tas.paused = false
            tas.frame = 1
            tas.playStartTime = tick()
        else
            tas.playing = false
            tas.paused = false
        end
    elseif input.KeyCode == settings.tas_key_stop then
        tas.recording = false
        tas.playing = false
        tas.paused = false
    elseif input.KeyCode == settings.tas_key_pause then
        if tas.playing then
            tas.paused = not tas.paused
        end
    elseif input.KeyCode == settings.tas_key_frameadvance then
        if tas.playing and tas.paused then
            tas.frame = math.min(tas.frame + 1, #tas.events)
            tas.playStartTime = tick() - (tas.events[tas.frame] and tas.events[tas.frame].t or 0)
        end
    elseif input.KeyCode == settings.tas_key_rewind then
        if tas.playing then
            tas.frame = math.max(1, tas.frame - 100)
            tas.playStartTime = tick() - (tas.events[tas.frame] and tas.events[tas.frame].t or 0)
        end
    elseif input.KeyCode == settings.tas_key_fastforward then
        if tas.playing then
            tas.frame = math.min(#tas.events, tas.frame + 100)
            tas.playStartTime = tick() - (tas.events[tas.frame] and tas.events[tas.frame].t or 0)
        end
    end
end)

-- Main loop: record per-frame, handle slowmo/camera, timestamped playback
RunService.RenderStepped:Connect(function()
    -- SLOWMO
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if tas.recording and getgenv().TAS_Slowmo and hum then
        if not tas.slowmo_was or not tas.slowmo_was.active then
            tas.slowmo_was = {WalkSpeed = hum.WalkSpeed, JumpPower = hum.JumpPower, active = true}
        end
        hum.WalkSpeed = slowWalk
        hum.JumpPower = slowJump
    elseif (not tas.recording or not getgenv().TAS_Slowmo) and hum and tas.slowmo_was and tas.slowmo_was.active then
        hum.WalkSpeed = tas.slowmo_was.WalkSpeed or 16
        hum.JumpPower = tas.slowmo_was.JumpPower or 50
        tas.slowmo_was = nil
    end

    -- RECORD per-frame snapshot (key state, mouse, camera), always 1:1
    if tas.recording then
        local keyState = getKeyState()
        local mousePos = UserInput:GetMouseLocation()
        table.insert(tas.events, {
            t = tick()-tas.time0,
            keys = deepCopy(keyState),
            mouse = {x=mousePos.X, y=mousePos.Y},
            cframe = getgenv().TAS_CameraFollow and {Camera.CFrame:GetComponents()} or nil,
        })
        tas.len = #tas.events
    end

    -- PLAYBACK frame/timestamp-accurate
    if tas.playing and tas.frame <= #tas.events and not tas.paused then
        local now = tick() - (tas.playStartTime or tick())
        while tas.frame <= #tas.events and tas.events[tas.frame].t <= now do
            local ev = tas.events[tas.frame]
            -- Example input replay (replace with VirtualInputManager if your executor supports it)
            -- local vim = game:GetService("VirtualInputManager")
            -- for k,v in pairs(ev.keys) do
            --     local kc = Enum.KeyCode[k]
            --     if kc and v then
            --         vim:SendKeyEvent(true, kc, false, game)
            --     elseif kc and not v then
            --         vim:SendKeyEvent(false, kc, false, game)
            --     end
            -- end
            -- Camera
            if getgenv().TAS_CameraFollow and ev.cframe then
                Camera.CameraType = Enum.CameraType.Scriptable
                Camera.CFrame = CFrame.new(unpack(ev.cframe))
            else
                Camera.CameraType = Enum.CameraType.Custom
            end
            tas.frame = tas.frame + 1
        end
        if tas.frame > #tas.events then
            tas.playing = false
            tas.paused = false
        end
    elseif not tas.playing then
        Camera.CameraType = Enum.CameraType.Custom
    end

    -- Update status label
    if statusLabel then
        statusLabel.Text = string.format("Frame: %d / %d | %s",
            tas.frame, tas.len or 0,
            tas.recording and "Recording"
            or (tas.playing and (tas.paused and "Paused" or "Playing") or "Idle")
        )
    end
end)

print("TAS Recorder/Player loaded! Use the UI to record/playback input. Camera Follow & Slow-Mo supported.")
