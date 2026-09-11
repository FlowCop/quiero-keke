print("[Flow] Build DIAG · script cargado e iniciando...")

local SUPABASE_URL = "https://asmgmjwdkgdhlhhfzhvo.supabase.co"
local SUPABASE_KEY = "sb_publishable_O-8d5H3vtNHW-p_luKh0ig_znoqwM6P"
local TABLE_NAME   = "Flow"

local BRAND = {
    Icon          = "rbxassetid://107907121398756",
    Background    = "rbxassetid://116385930353094",
    TriggerRange  = 65,
    MinimizeRange = 85,
    SyncInterval  = 5,
    ToggleKey     = Enum.KeyCode.RightAlt,
    JoinToasts    = true,
}

local ROLES = {
    -- [123456789] = { Label = "FOUNDER" },
}

local THEME = {
    Height     = 44,
    Collapsed  = 44,
    MiniSize   = 44,
    MinWidth   = 132,
    MaxWidth   = 278,

    Background = Color3.fromRGB(10, 10, 11),
    Primary    = Color3.fromRGB(255, 255, 255),
    Secondary  = Color3.fromRGB(215, 215, 224),
    Accent     = Color3.fromRGB(255, 255, 255),
}


local Lighting        = game:GetService("Lighting")
local TweenService    = game:GetService("TweenService")
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local Debris          = game:GetService("Debris")
local CoreGui         = game:GetService("CoreGui")
local HttpService     = game:GetService("HttpService")
local TextService     = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local SoundService    = game:GetService("SoundService")
local Workspace       = game:GetService("Workspace")

local monotonic = (typeof(time) == "function" and time) or tick

local LocalPlayer = Players.LocalPlayer
local playersInDatabase = {}
local tracked = {}

local httpRequest = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)

local guiName = "FlowAFEM_FinalGUI"
local hostName = guiName .. "_Tags"
local targetParent
do
    if typeof(gethui) == "function" then
        targetParent = gethui()
    elseif pcall(function() return CoreGui:GetChildren() end) then
        targetParent = CoreGui
    else
        targetParent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local EXPAND_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FADE_INFO   = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local NAME_FONT, NAME_SIZE = Enum.Font.GothamBold, 11
local SUB_FONT,  SUB_SIZE  = Enum.Font.Gotham, 10
local CONTENT_X = 50
local RIGHT_INSET = 16

local function create(class, props, parent)
    local inst = Instance.new(class)
    for prop, value in pairs(props) do inst[prop] = value end
    inst.Parent = parent
    return inst
end

local function measure(text, size, font)
    return TextService:GetTextSize(text, size, font, Vector2.new(2000, 100)).X
end

local function RemoveFromSupabase()
    if not httpRequest then return end
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "/rest/v1/" .. TABLE_NAME .. "?user_id=eq." .. LocalPlayer.UserId,
            Method = "DELETE",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
            },
        })
    end)
end

local function AddToSupabase()
    if not httpRequest then return end
    pcall(function()
        httpRequest({
            Url = SUPABASE_URL .. "/rest/v1/" .. TABLE_NAME,
            Method = "POST",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                ["Content-Type"] = "application/json",
                ["Prefer"] = "return=minimal",
            },
            Body = HttpService:JSONEncode({
                ["user_id"]      = LocalPlayer.UserId,
                ["username"]     = LocalPlayer.Name,
                ["display_name"] = LocalPlayer.DisplayName,
                ["active"]       = true,
            }),
        })
    end)
end

local function RefreshDatabaseList()
    if not httpRequest then return end
    local success, response = pcall(function()
        return httpRequest({
            Url = SUPABASE_URL .. "/rest/v1/" .. TABLE_NAME .. "?select=user_id",
            Method = "GET",
            Headers = {
                ["apikey"] = SUPABASE_KEY,
                ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            },
        })
    end)
    if success and response and response.StatusCode == 200 then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and type(data) == "table" then
            local newList = {}
            for _, entry in ipairs(data) do
                local id = tonumber(entry.user_id)
                if id then newList[id] = true end
            end
            newList[LocalPlayer.UserId] = true
            playersInDatabase = newList
        end
    end
end

local function main()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local mouse = LocalPlayer:GetMouse()
    local existingMain = targetParent:FindFirstChild(guiName)
    local existingHost = playerGui:FindFirstChild(hostName)
    if existingMain or existingHost then
        if existingMain then existingMain:Destroy() end
        if existingHost then existingHost:Destroy() end
        RemoveFromSupabase()
        return "closed"
    end

    playersInDatabase[LocalPlayer.UserId] = true
    task.spawn(AddToSupabase)
    RefreshDatabaseList()

    local MainGui = create("ScreenGui", {
        Name = guiName,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    }, targetParent)

    local TagHost

    local function ensureTagHost()
        if TagHost and TagHost.Parent then return end
        for _, st in pairs(tracked) do
            if st.charConn then st.charConn:Disconnect() end
        end
        table.clear(tracked)
        TagHost = create("ScreenGui", {
            Name = hostName,
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            IgnoreGuiInset = true,
        }, playerGui)
    end

    ensureTagHost()

    local function playSound(id, vol, speed)
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol
            s.PlaybackSpeed = speed
            s.Parent = SoundService
            SoundService:PlayLocalSound(s)
            Debris:AddItem(s, 5)
        end)
    end

    local activeToasts = 0
    local function showToast(title, body)
        if not BRAND.JoinToasts then return end
        task.spawn(function()
            local slot = activeToasts
            activeToasts += 1

            local w = math.max(measure(title, 12, NAME_FONT), measure(body, 10, SUB_FONT)) + 76
            local targetY = 60 + slot * 54

            local Toast = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, targetY - 18),
                Size = UDim2.new(0, w, 0, 44),
                BackgroundColor3 = THEME.Background,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 50,
            }, MainGui)
            create("UICorner", { CornerRadius = UDim.new(0, 14) }, Toast)
            local stroke = create("UIStroke", { Thickness = 1, Transparency = 1, Color = Color3.fromRGB(255, 255, 255) }, Toast)

            local sideAccent = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 8, 0.5, 0),
                Size = UDim2.new(0, 3, 1, -18),
                BackgroundColor3 = THEME.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 51,
            }, Toast)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, sideAccent)
            create("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.5, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }, sideAccent)

            local iconBox = create("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 19, 0.5, 0),
                Size = UDim2.new(0, 26, 0, 26),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 51,
            }, Toast)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, iconBox)
            local iconStroke = create("UIStroke", { Thickness = 1.5, Transparency = 1, Color = Color3.fromRGB(0, 0, 0) }, iconBox)
            local iconScale = create("UIScale", { Scale = 0 }, iconBox)
            local icon = create("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 15, 0, 15),
                BackgroundTransparency = 1,
                Image = BRAND.Icon,
                ImageTransparency = 1,
                ZIndex = 52,
            }, iconBox)

            local t1 = create("TextLabel", {
                Position = UDim2.new(0, 53, 0, 8),
                Size = UDim2.new(1, -64, 0, 15),
                BackgroundTransparency = 1,
                Font = NAME_FONT, TextSize = 12,
                TextColor3 = THEME.Primary,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = title, TextTransparency = 1, ZIndex = 51,
            }, Toast)
            local t2 = create("TextLabel", {
                Position = UDim2.new(0, 53, 0, 24),
                Size = UDim2.new(1, -64, 0, 12),
                BackgroundTransparency = 1,
                Font = SUB_FONT, TextSize = 10,
                TextColor3 = THEME.Secondary,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = body, TextTransparency = 1, ZIndex = 51,
            }, Toast)

            local progress = create("Frame", {
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new(0, 14, 1, -4),
                Size = UDim2.new(1, -28, 0, 2),
                BackgroundColor3 = THEME.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 51,
            }, Toast)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, progress)

            local inInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            TweenService:Create(Toast, inInfo, { Position = UDim2.new(0.5, 0, 0, targetY), BackgroundTransparency = 0.22 }):Play()
            TweenService:Create(stroke, inInfo, { Transparency = 0.7 }):Play()
            TweenService:Create(sideAccent, inInfo, { BackgroundTransparency = 0.25 }):Play()
            TweenService:Create(iconStroke, inInfo, { Transparency = 0.25 }):Play()
            TweenService:Create(icon, inInfo, { ImageTransparency = 0 }):Play()
            TweenService:Create(t1, inInfo, { TextTransparency = 0 }):Play()
            TweenService:Create(t2, inInfo, { TextTransparency = 0 }):Play()
            TweenService:Create(iconScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            TweenService:Create(progress, inInfo, { BackgroundTransparency = 0.45 }):Play()

            task.wait(0.5)
            TweenService:Create(progress, TweenInfo.new(2.7, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()

            task.wait(3.2)

            local outInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
            TweenService:Create(Toast, outInfo, { Position = UDim2.new(0.5, 0, 0, targetY - 14), BackgroundTransparency = 1 }):Play()
            TweenService:Create(stroke, outInfo, { Transparency = 1 }):Play()
            TweenService:Create(sideAccent, outInfo, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(iconStroke, outInfo, { Transparency = 1 }):Play()
            TweenService:Create(icon, outInfo, { ImageTransparency = 1 }):Play()
            TweenService:Create(t1, outInfo, { TextTransparency = 1 }):Play()
            TweenService:Create(t2, outInfo, { TextTransparency = 1 }):Play()
            TweenService:Create(progress, outInfo, { BackgroundTransparency = 1 }):Play()
            task.wait(0.45)
            Toast:Destroy()
            activeToasts = math.max(0, activeToasts - 1)
        end)
    end

    local function playTeleportFX(performTP)
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not root then
            performTP()
            return
        end

        local function setAllVis(c, v)
            for _, obj in ipairs(c:GetDescendants()) do
                if obj:IsA("BasePart") then
                    obj.LocalTransparencyModifier = v
                elseif obj:IsA("Decal") then
                    obj.Transparency = v
                elseif obj:IsA("Accessory") then
                    local h = obj:FindFirstChild("Handle")
                    if h then h.LocalTransparencyModifier = v end
                end
            end
        end

        setAllVis(char, 1)

        task.delay(0.05, function()
            performTP()

            task.delay(0.15, function()
                local nc = LocalPlayer.Character
                if nc then
                    setAllVis(nc, 0)
                end
            end)
        end)
    end

    local tagHits = {}

    local function removeTag(player)
        local state = tracked[player.UserId]
        if state then
            if state.charConn then state.charConn:Disconnect() end
            tracked[player.UserId] = nil
        end
        tagHits[player.UserId] = nil
        local tag = TagHost:FindFirstChild("FlowTag_" .. player.UserId)
        if tag then tag:Destroy() end
    end

    local function applyTagToPlayer(player)
        if tracked[player.UserId] then return end
        ensureTagHost()

        local state = {}
        tracked[player.UserId] = state

        local role    = ROLES[player.UserId]
        local tagline = (((role and role.Label) or "FLOW") .. " USER"):upper()
        local displayName = (player.DisplayName ~= "" and player.DisplayName) or player.Name or "Flow"

        local textW = math.max(
            measure(tagline, NAME_SIZE, NAME_FONT),
            measure(displayName, SUB_SIZE, SUB_FONT)
        )
        local expandedW = math.clamp(CONTENT_X + textW + 22, THEME.MinWidth, THEME.MaxWidth)

        local function apply(character)
            local head = character:WaitForChild("Head", 5)
            if not head then return end

            local previous = TagHost:FindFirstChild("FlowTag_" .. player.UserId)
            if previous then previous:Destroy() end

            local Billboard = create("BillboardGui", {
                Name = "FlowTag_" .. player.UserId,
                Adornee = head,
                Size = UDim2.new(0, 360, 0, 110),
                StudsOffset = Vector3.new(0, 2.25, 0),
                AlwaysOnTop = true,
                LightInfluence = 0,
            }, TagHost)

            local Root = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, THEME.Collapsed, 0, THEME.Height),
                BackgroundColor3 = THEME.Background,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, Billboard)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, Root)
            local Scale = create("UIScale", { Scale = 0 }, Root)

            local bgLayers = {
                { dx = 0,  dy = 0,  t = 0.15 },
                { dx = 0,  dy = -1, t = 0.82 },
                { dx = 0,  dy = 1,  t = 0.82 },
                { dx = -1, dy = 0,  t = 0.82 },
                { dx = 1,  dy = 0,  t = 0.82 },
            }
            for _, l in ipairs(bgLayers) do
                local img = create("ImageLabel", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(0.5, l.dx, 0.5, l.dy),
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Image = BRAND.Background,
                    ScaleType = Enum.ScaleType.Crop,
                    ImageTransparency = l.t,
                    BorderSizePixel = 0,
                    ZIndex = 1,
                }, Root)
                create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, img)
            end

            local BgDark = create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0.85,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, Root)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, BgDark)

            local Sheen = create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, Root)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, Sheen)
            create("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 40, 40)),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.95),
                    NumberSequenceKeypoint.new(0.5, 1),
                    NumberSequenceKeypoint.new(1, 0.975),
                }),
            }, Sheen)

            local Stroke = create("UIStroke", {
                Thickness = 1.2,
                Transparency = 0.3,
                Color = Color3.fromRGB(210, 210, 225),
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, Root)
            local StrokeGradient = create("UIGradient", {
                Rotation = -22,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.466, 0),
                    NumberSequenceKeypoint.new(0.947, 0.906),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }, Stroke)

            local LogoBox = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, THEME.Collapsed / 2, 0.5, 0),
                Size = UDim2.new(0, 38, 0, 38),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 4,
            }, Root)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, LogoBox)
            local LogoScale = create("UIScale", { Scale = 0 }, LogoBox)

            create("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 22, 0, 22),
                BackgroundTransparency = 1,
                Image = BRAND.Icon,
                ImageColor3 = Color3.fromRGB(255, 255, 255),
                ZIndex = 5,
            }, LogoBox)

            local Content = create("Frame", {
                Position = UDim2.new(0, CONTENT_X, 0, 0),
                Size = UDim2.new(1, -(CONTENT_X + RIGHT_INSET), 1, 0),
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                ZIndex = 4,
            }, Root)

            local TopText = create("TextLabel", {
                Position = UDim2.new(0, 0, 0, 5),
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,
                Font = NAME_FONT,
                TextSize = NAME_SIZE,
                TextColor3 = THEME.Primary,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = "",
                TextTransparency = 1,
                ZIndex = 4,
            }, Content)

            local Subtitle = create("TextLabel", {
                Position = UDim2.new(0, 3, 0, 17),
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundTransparency = 1,
                Font = SUB_FONT,
                TextSize = SUB_SIZE,
                TextColor3 = THEME.Secondary,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = displayName,
                TextTransparency = 1,
                ZIndex = 4,
            }, Content)

            pcall(function()
                local hum = character:FindFirstChildOfClass("Humanoid")
                if hum then hum.NameDisplayDistance = 0 end
            end)

            local expanded = false
            local minimized = false

            local function teleportToTarget()
                local myChar = LocalPlayer.Character
                local targetChar = player.Character
                if not (myChar and targetChar) then return end
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Head")
                if not targetRoot then return end

                local behindDir = -targetRoot.CFrame.LookVector
                local pos = targetRoot.Position + behindDir * 4
                local lookAt = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
                local targetCF = CFrame.lookAt(pos, lookAt)

                pcall(function()
                    myChar:PivotTo(targetCF)
                end)
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    pcall(function()
                        myRoot.CFrame = targetCF
                    end)
                end
            end

            local hoverOn = false

            local function setHover(on)
                if hoverOn == on then return end
                hoverOn = on
                if on then
                    TweenService:Create(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quint), { Scale = 1.05 }):Play()
                    TweenService:Create(Stroke, TweenInfo.new(0.18), { Transparency = 0.08 }):Play()
                else
                    TweenService:Create(Scale, TweenInfo.new(0.22, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
                    TweenService:Create(Stroke, TweenInfo.new(0.22), { Transparency = 0.42 }):Play()
                end
            end

            local function activate()
                playTeleportFX(teleportToTarget)
            end

            local hitEntry = {
                userId = player.UserId,
                setHover = setHover,
                activate = activate,
                cx = 0,
                cy = 0,
                hw = 0,
                hh = 0,
            }
            tagHits[player.UserId] = hitEntry

            local function setMinimized(state)
                if minimized == state then return end
                minimized = state

                if state then
                    local info = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    TweenService:Create(Root, info, { Size = UDim2.new(0, THEME.MiniSize, 0, THEME.MiniSize), BackgroundTransparency = 0.14 }):Play()
                    TweenService:Create(LogoBox, info, { Position = UDim2.new(0.5, 0, 0.5, 0) }):Play()
                    TweenService:Create(Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Thickness = 2.2 }):Play()
                else
                    local targetW = expanded and expandedW or THEME.Collapsed
                    local logoX = expanded and 23 or THEME.Collapsed / 2
                    local info = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                    TweenService:Create(Root, info, { Size = UDim2.new(0, targetW, 0, THEME.Height), BackgroundTransparency = 0.30 }):Play()
                    TweenService:Create(LogoBox, info, { Position = UDim2.new(0, logoX, 0.5, 0) }):Play()
                    TweenService:Create(Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Thickness = 1.5 }):Play()
                end
            end

            local function setExpanded(state)
                if expanded == state then return end
                expanded = state

                if state then
                    if minimized then setMinimized(false) end
                    TweenService:Create(Root, EXPAND_INFO, { Size = UDim2.new(0, expandedW, 0, THEME.Height) }):Play()
                    TweenService:Create(LogoBox, EXPAND_INFO, { Position = UDim2.new(0, 23, 0.5, 0) }):Play()
                    TweenService:Create(TopText, FADE_INFO, { TextTransparency = 0 }):Play()
                    TweenService:Create(Subtitle, FADE_INFO, { TextTransparency = 0 }):Play()
                else
                    if not minimized then
                        TweenService:Create(Root, EXPAND_INFO, { Size = UDim2.new(0, THEME.Collapsed, 0, THEME.Height) }):Play()
                        TweenService:Create(LogoBox, EXPAND_INFO, { Position = UDim2.new(0, THEME.Collapsed / 2, 0.5, 0) }):Play()
                    end
                    TweenService:Create(TopText, FADE_INFO, { TextTransparency = 1 }):Play()
                    TweenService:Create(Subtitle, FADE_INFO, { TextTransparency = 1 }):Play()
                    Cursor.TextTransparency = 1
                    TopText.Text = ""
                end
            end

            task.wait(0.1)
            if not Billboard.Parent then
                tagHits[player.UserId] = nil
                return
            end
            TweenService:Create(Scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
            TweenService:Create(Root, TweenInfo.new(0.4, Enum.EasingStyle.Quart), { BackgroundTransparency = 0.30 }):Play()
            TweenService:Create(Stroke, TweenInfo.new(0.4), { Transparency = 0.42 }):Play()
            LogoScale.Scale = 1

            local Cursor = create("TextLabel", {
                Position = UDim2.new(0, 0, 0, 5),
                Size = UDim2.new(0, 0, 0, 12),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = NAME_FONT,
                TextSize = NAME_SIZE,
                TextColor3 = THEME.Primary,
                Text = "|",
                TextTransparency = 1,
                ZIndex = 4,
            }, Content)

            task.spawn(function()
                while Billboard.Parent do
                    if not expanded then
                        Cursor.TextTransparency = 1
                        task.wait(0.1)
                    else
                        TopText.Text = ""
                        Cursor.TextTransparency = 0
                        for i = 1, #tagline do
                            if not Billboard.Parent or not expanded then break end
                            TopText.Text = string.sub(tagline, 1, i)
                            task.wait(0.05)
                        end
                        if Billboard.Parent and expanded then
                            TopText.Text = tagline
                        end
                        for c = 1, 3 do
                            if not Billboard.Parent or not expanded then break end
                            Cursor.TextTransparency = 0
                            task.wait(0.4)
                            Cursor.TextTransparency = 1
                            task.wait(0.4)
                        end
                        if not expanded then
                            Cursor.TextTransparency = 1
                        end
                        task.wait(0.5)
                        for i = #tagline, 0, -1 do
                            if not Billboard.Parent or not expanded then break end
                            TopText.Text = (i > 0 and string.sub(tagline, 1, i) or "")
                            task.wait(0.03)
                        end
                        task.wait(1.5)
                    end
                end
            end)

            local renderConn
            renderConn = RunService.RenderStepped:Connect(function()
                if not Billboard.Parent then
                    renderConn:Disconnect()
                    return
                end
                if not playersInDatabase[player.UserId] then
                    renderConn:Disconnect()
                    removeTag(player)
                    return
                end

                local now = monotonic()
                local bob = math.sin(now * 0.9) * 0.09 + math.sin(now * 0.42 + 2.0) * 0.045

                local cam = Workspace.CurrentCamera
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot and head.Parent then
                    local dist = (head.Position - myRoot.Position).Magnitude
                    setExpanded(dist < BRAND.TriggerRange)
                    setMinimized(dist >= BRAND.MinimizeRange)

                    if hitEntry == tagHits[player.UserId] then
                        local sp, onScreen = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2.25 + bob, 0))
                        if onScreen then
                            hitEntry.cx = sp.X
                            hitEntry.cy = sp.Y
                            local as = Root.AbsoluteSize
                            hitEntry.hw = as.X * 0.5 + 18
                            hitEntry.hh = as.Y * 0.5 + 14
                        else
                            hitEntry.hw = 0
                        end
                    end
                else
                    hitEntry.hw = 0
                end

                Billboard.StudsOffset = Vector3.new(math.sin(now * 0.31) * 0.035, 2.25 + bob, 0)

                StrokeGradient.Offset = Vector2.new(math.sin(now * 0.8) * 0.3, 0)

                if expanded then
                    local tb = TopText.TextBounds
                    Cursor.Position = UDim2.new(0, math.max(0, tb.X), 0, 5)
                else
                    Cursor.TextTransparency = 1
                end
            end)

            Billboard.Destroying:Connect(function()
                if renderConn then renderConn:Disconnect() end
                if tagHits[player.UserId] == hitEntry then
                    tagHits[player.UserId] = nil
                end
            end)
        end

        state.charConn = player.CharacterAdded:Connect(function(newChar)
            if playersInDatabase[player.UserId] and TagHost.Parent then
                task.spawn(apply, newChar)
            end
        end)
        if player.Character then task.spawn(apply, player.Character) end
    end

    local function findTagAt(x, y)
        local best, bestDist = nil, math.huge
        for _, e in pairs(tagHits) do
            if e.hw > 0 and e.userId ~= LocalPlayer.UserId then
                local dx = math.abs(x - e.cx)
                local dy = math.abs(y - e.cy)
                if dx <= e.hw and dy <= e.hh then
                    local d = dx * dx + dy * dy
                    if d < bestDist then
                        best, bestDist = e, d
                    end
                end
            end
        end
        return best
    end

    local hoveredEntry = nil
    local function setHovered(entry)
        if hoveredEntry == entry then return end
        if hoveredEntry then
            pcall(hoveredEntry.setHover, false)
        end
        hoveredEntry = entry
        local icon = entry and "rbxasset://SystemCursors/PointingHand.png" or ""
        pcall(function()
            UserInputService.MouseIcon = icon
        end)
        pcall(function()
            mouse.Icon = icon
        end)
        if entry then
            pcall(entry.setHover, true)
        end
    end

    local hoverConn = RunService.RenderStepped:Connect(function()
        if not MainGui.Parent or not MainGui.Enabled then
            setHovered(nil)
            return
        end
        local m = UserInputService:GetMouseLocation()
        setHovered(findTagAt(m.X, m.Y))
    end)

    local clickConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local m = UserInputService:GetMouseLocation()
            local e = findTagAt(m.X, m.Y)
            if e then
                setHovered(e)
                pcall(e.activate)
            end
        elseif input.UserInputType == Enum.UserInputType.Touch then
            local p = input.Position
            local e = findTagAt(p.X, p.Y)
            if e then
                pcall(e.activate)
            end
        end
    end)

    local firstSyncDone = false
    local function syncPass()
        for _, plr in ipairs(Players:GetPlayers()) do
            if playersInDatabase[plr.UserId] then
                if not tracked[plr.UserId] then
                    applyTagToPlayer(plr)
                    if firstSyncDone and plr ~= LocalPlayer then
                        local dn = (plr.DisplayName ~= "" and plr.DisplayName) or plr.Name
                        showToast(dn, "Miembro Flow en tu servidor")
                    end
                end
            elseif tracked[plr.UserId] then
                removeTag(plr)
            end
        end
        firstSyncDone = true
    end

    syncPass()

    task.spawn(function()
        while MainGui.Parent do
            task.wait(BRAND.SyncInterval)
            if not MainGui.Parent then break end
            RefreshDatabaseList()
            ensureTagHost()
            syncPass()
        end
    end)

    local joinConn = Players.PlayerAdded:Connect(function()
        task.wait(2)
        if not MainGui.Parent then return end
        RefreshDatabaseList()
        ensureTagHost()
        syncPass()
    end)

    local leaveConn = Players.PlayerRemoving:Connect(function(user)
        if user == LocalPlayer then
            RemoveFromSupabase()
        else
            removeTag(user)
        end
    end)

    local keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == BRAND.ToggleKey then
            MainGui.Enabled = not MainGui.Enabled
            if TagHost then
                TagHost.Enabled = MainGui.Enabled
            end
            if not MainGui.Enabled then
                setHovered(nil)
            end
        end
    end)

    MainGui.Destroying:Connect(function()
        joinConn:Disconnect()
        leaveConn:Disconnect()
        keyConn:Disconnect()
        hoverConn:Disconnect()
        clickConn:Disconnect()
        pcall(function()
            UserInputService.MouseIcon = ""
        end)
        pcall(function()
            mouse.Icon = ""
        end)
        for _, state in pairs(tracked) do
            if state.charConn then state.charConn:Disconnect() end
        end
        table.clear(tracked)
        table.clear(tagHits)
        if TagHost then
            TagHost:Destroy()
        end
    end)

    return "open"
end

local ok, result = xpcall(main, function(e)
    local where = ""
    pcall(function() where = " · línea " .. tostring(debug.info(2, "l")) end)
    return tostring(e) .. where
end)

if not ok then
    warn("[Flow] ERROR: " .. tostring(result))
    warn("[Flow] Copia ese error y envíamelo para arreglarlo exactamente.")
elseif result == "closed" then
    warn("[Flow] Había una interfaz anterior abierta y se ha CERRADO. Ejecuta el script OTRA VEZ para abrirla de nuevo.")
else
    print("[Flow] Interfaz ACTIVA · teletransporte de sombras renovado · polvo más visible · " .. BRAND.ToggleKey.Name .. " para ocultar.")
end
