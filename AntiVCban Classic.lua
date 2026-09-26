if _G.FlowNotifActive then

    return

end

_G.FlowNotifActive = true



local clonereference = cloneref or function(...) return ... end

local clonefunction  = clonefunction or function(...) return ... end



local voicechatservice  = clonereference(game:GetService("VoiceChatService"))

local voicechatinternal = clonereference(game:GetService("VoiceChatInternal"))

local coregui           = game:GetService("CoreGui")

local players           = game:GetService("Players")

local localplayer       = players.LocalPlayer

local getconnectionsfunc = clonefunction(getconnections)



local mutedimage   = "rbxasset://textures/ui/VoiceChat/MicLight/Muted.png"

local ismuted      = true

local hiddenfolder = Instance.new("Folder", game:GetService("RobloxReplicatedStorage"))



-- Buscador flexible compatible contigo y con tu amigo (doble método)

local function findMicElements(maxSeconds)

    maxSeconds = maxSeconds or 30

    local elapsed = 0

    local topbarapp = nil



    while elapsed < maxSeconds do

        local t1 = coregui:FindFirstChild("TopBarApp")

        if t1 then

            local t2 = t1:FindFirstChild("TopBarApp")

            if t2 then

                topbarapp = t2

                break

            end

        end

        task.wait(0.5)

        elapsed = elapsed + 0.5

    end

    if not topbarapp then

        return nil, nil

    end



    local unibarleft = nil

    while elapsed < maxSeconds do

        unibarleft = topbarapp:FindFirstChild("UnibarLeftFrame")

        if unibarleft then

            break

        end

        task.wait(0.5)

        elapsed = elapsed + 0.5

    end

    if not unibarleft then

        return nil, nil

    end



    local unibarmenu = nil

    while elapsed < maxSeconds do

        local um = unibarleft:FindFirstChild("UnibarMenu")

        if um then

            unibarmenu = um

            break

        end

        local cm = unibarleft:FindFirstChild("ChromeMenu")

        if cm then

            unibarmenu = cm

            break

        end

        task.wait(0.5)

        elapsed = elapsed + 0.5

    end

    if not unibarmenu then

        return nil, nil

    end



    -- Método A: Búsqueda exacta de tus carpetas numéricas ("2" -> "3")

    local three = nil

    local two = unibarmenu:FindFirstChild("2")

    if two then

        three = two:FindFirstChild("3")

    end



    -- Método B (Respaldo para tu amigo): Si no encuentra la estructura exacta, busca directamente el botón o cualquier frame contenedor

    local micbtn = nil

    if three then

        micbtn = three:FindFirstChild("toggle_mic_mute")

        return three, micbtn

    else

        -- Si tu amigo tiene otra estructura, buscamos "toggle_mic_mute" en todo el menú de la izquierda directamente

        micbtn = unibarmenu:FindFirstChild("toggle_mic_mute", true)

        if micbtn then

            return micbtn.Parent, micbtn

        end

        return unibarmenu, nil

    end

end



local unibarcontainer, micmutebutton = findMicElements(20)



local function geticonlabel(button)

    button = button or micmutebutton

    if not button then

        return nil

    end

    local iconFrame = button:WaitForChild("IntegrationIconFrame", 15)

    if iconFrame then

        local icon = iconFrame:WaitForChild("IntegrationIcon", 15)

        if icon then

            if icon:IsA("ImageLabel") then

                return icon

            end

            local child1 = icon:FindFirstChild("1")

            if child1 then

                return child1

            end

            return icon:FindFirstChildWhichIsA("ImageLabel", true)

        end

    end

    return button:FindFirstChildWhichIsA("ImageLabel", true)

end



local function getAudioInput()

    local audi = localplayer:FindFirstChildWhichIsA("AudioDeviceInput", true)

    if not audi then

        pcall(function()

            voicechatservice:joinVoice()

        end)

        task.wait(0.5)

        audi = localplayer:FindFirstChildWhichIsA("AudioDeviceInput", true)

    end

    return audi

end



local function muteNow()

    local audi = getAudioInput()

    if audi then

        pcall(function()

            audi.Muted = true

        end)

    end

    pcall(function()

        voicechatinternal:PublishPause(true)

    end)

end



local function unmuteNow()

    local audi = getAudioInput()

    if audi then

        pcall(function()

            audi.Muted = false

        end)

    end

    pcall(function()

        voicechatinternal:PublishPause(false)

    end)

end



local watchdogRunning = false

local function startWatchdog()

    if watchdogRunning then

        return

    end

    watchdogRunning = true

    task.spawn(function()

        while watchdogRunning do

            task.wait(1)

            local audi = localplayer:FindFirstChildWhichIsA("AudioDeviceInput", true)

            if audi then

                local desired = ismuted

                if audi.Muted ~= desired then

                    pcall(function()

                        audi.Muted = desired

                    end)

                    pcall(function()

                        voicechatinternal:PublishPause(desired)

                    end)

                end

            end

        end

    end)

end



if not micmutebutton then

    voicechatservice:joinVoice()

    task.wait(2)

    unibarcontainer, micmutebutton = findMicElements(15)

end



local TweenService  = game:GetService("TweenService")

local Camera        = workspace.CurrentCamera



local targetGui = coregui

local coreOk = pcall(function()

    return coregui.Name

end)

if not coreOk then

    targetGui = localplayer:WaitForChild("PlayerGui")

end



local existingGui = targetGui:FindFirstChild("FlowNotif")

if existingGui then

    existingGui:Destroy()

end



local NOTIF_W       = 290

local NOTIF_H       = 70

local ANIM_DUR      = 0.2

local FILL_DUR      = 2.2

local HOLD_AFTER    = 1.2

local CORNER_RADIUS = 16

local MARGIN_RIGHT  = 20

local MARGIN_BOTTOM = 30

local STICKER_ID    = "rbxthumb://type=Asset&id=89920409024621&w=150&h=150"



local GLASS_BG     = Color3.fromRGB(0, 0, 0)

local TEXT_PRIMARY = Color3.fromRGB(255, 255, 255)

local TEXT_DIM     = Color3.fromRGB(100, 100, 115)

local FILL_COLOR   = Color3.fromRGB(60, 255, 130)



local TitleFont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local BodyFont  = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular)



local viewportSize = Camera.ViewportSize

local finalX       = viewportSize.X - NOTIF_W - MARGIN_RIGHT

local finalY       = viewportSize.Y - NOTIF_H - MARGIN_BOTTOM

local offscreenX   = viewportSize.X + 20



local function Tween(obj, props, duration, style, dir)

    if not obj then

        return

    end

    local info = TweenInfo.new(

        duration or ANIM_DUR,

        style or Enum.EasingStyle.Quad,

        dir or Enum.EasingDirection.Out

    )

    local t = TweenService:Create(obj, info, props)

    t:Play()

    return t

end



local Gui = Instance.new("ScreenGui")

Gui.Name           = "FlowNotif"

Gui.ResetOnSpawn   = false

Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

Gui.IgnoreGuiInset = true

Gui.Parent         = targetGui



local Container = Instance.new("Frame")

Container.Size                   = UDim2.new(0, NOTIF_W, 0, NOTIF_H)

Container.Position               = UDim2.new(0, offscreenX, 0, finalY)

Container.BackgroundTransparency = 1

Container.Parent                 = Gui



local DropShadow = Instance.new("Frame")

DropShadow.Name                   = "DropShadow"

DropShadow.Size                   = UDim2.new(1, 8, 1, 8)

DropShadow.Position               = UDim2.new(0.5, 0, 0.5, 0)

DropShadow.AnchorPoint            = Vector2.new(0.5, 0.5)

DropShadow.BackgroundColor3       = Color3.new(0, 0, 0)

DropShadow.BackgroundTransparency = 1

DropShadow.ZIndex                 = 0

DropShadow.Parent                 = Container

Instance.new("UICorner", DropShadow).CornerRadius = UDim.new(0, CORNER_RADIUS + 2)



local Win = Instance.new("Frame")

Win.Size                   = UDim2.new(1, 0, 1, 0)

Win.Position               = UDim2.new(0.5, 0, 0.5, 0)

Win.AnchorPoint            = Vector2.new(0.5, 0.5)

Win.BackgroundColor3       = GLASS_BG

Win.BackgroundTransparency = 1

Win.ClipsDescendants       = true

Win.ZIndex                 = 1

Win.Parent                 = Container

Instance.new("UICorner", Win).CornerRadius = UDim.new(0, CORNER_RADIUS)



local GlassStroke = Instance.new("UIStroke", Win)

GlassStroke.Color        = Color3.new(1, 1, 1)

GlassStroke.Transparency = 1

GlassStroke.Thickness    = 1.2



local StickerHolder = Instance.new("Frame")

StickerHolder.Size                   = UDim2.new(0, 48, 0, 48)

StickerHolder.Position               = UDim2.new(0, 11, 0.5, -24)

StickerHolder.BackgroundTransparency = 1

StickerHolder.ZIndex                 = 5

StickerHolder.Parent                 = Win



local StickerBase = Instance.new("ImageLabel")

StickerBase.Size                   = UDim2.new(1, 0, 1, 0)

StickerBase.BackgroundTransparency = 1

StickerBase.Image                  = STICKER_ID

StickerBase.ScaleType              = Enum.ScaleType.Fit

StickerBase.ImageTransparency      = 1

StickerBase.ImageColor3            = Color3.fromRGB(100, 100, 110)

StickerBase.ZIndex                 = 5

StickerBase.Parent                 = StickerHolder



local FillMask = Instance.new("Frame")

FillMask.AnchorPoint            = Vector2.new(0, 1)

FillMask.Position               = UDim2.new(0, 0, 1, 0)

FillMask.Size                   = UDim2.new(1, 0, 0, 0)

FillMask.BackgroundTransparency = 1

FillMask.ClipsDescendants       = true

FillMask.ZIndex                 = 6

FillMask.Parent                 = StickerHolder



local StickerEnergy = Instance.new("ImageLabel")

StickerEnergy.AnchorPoint            = Vector2.new(0, 1)

StickerEnergy.Position               = UDim2.new(0, 0, 1, 0)

StickerEnergy.Size                   = UDim2.new(0, 48, 0, 48)

StickerEnergy.BackgroundTransparency = 1

StickerEnergy.Image                  = STICKER_ID

StickerEnergy.ScaleType              = Enum.ScaleType.Fit

StickerEnergy.ImageTransparency      = 1

StickerEnergy.ImageColor3            = FILL_COLOR

StickerEnergy.ZIndex                 = 6

StickerEnergy.Parent                 = FillMask



local TitleLabel = Instance.new("TextLabel")

TitleLabel.Size                   = UDim2.new(1, -75, 0, 18)

TitleLabel.Position               = UDim2.new(0, 68, 0, 12)

TitleLabel.BackgroundTransparency = 1

TitleLabel.Text                   = "AntiVCBan System"

TitleLabel.FontFace               = TitleFont

TitleLabel.TextSize               = 13

TitleLabel.TextColor3             = TEXT_PRIMARY

TitleLabel.TextXAlignment         = Enum.TextXAlignment.Left

TitleLabel.TextTransparency       = 1

TitleLabel.ZIndex                 = 3

TitleLabel.Parent                 = Win



local ContentLabel = Instance.new("TextLabel")

ContentLabel.Size                   = UDim2.new(1, -75, 0, 32)

ContentLabel.Position               = UDim2.new(0, 68, 0, 30)

ContentLabel.BackgroundTransparency = 1

ContentLabel.Text                   = "Unmute your microphone to activate AntiVCBan System"

ContentLabel.FontFace               = BodyFont

ContentLabel.TextSize               = 11

ContentLabel.TextColor3             = TEXT_DIM

ContentLabel.TextXAlignment         = Enum.TextXAlignment.Left

ContentLabel.TextYAlignment         = Enum.TextYAlignment.Top

ContentLabel.TextWrapped            = true

ContentLabel.TextTransparency       = 1

ContentLabel.ZIndex                 = 3

ContentLabel.Parent                 = Win



pcall(function()

    game:GetService("ContentProvider"):PreloadAsync({StickerBase, StickerEnergy})

end)



Tween(Container,    {Position = UDim2.new(0, finalX, 0, finalY)}, ANIM_DUR)

Tween(Win,          {BackgroundTransparency = 0.35},               ANIM_DUR)

Tween(GlassStroke,  {Transparency = 0.85},                         ANIM_DUR)

Tween(DropShadow,   {BackgroundTransparency = 0.82},               ANIM_DUR)

Tween(TitleLabel,   {TextTransparency = 0},                        ANIM_DUR)

Tween(ContentLabel, {TextTransparency = 0},                        ANIM_DUR)

Tween(StickerBase,  {ImageTransparency = 0.4},                     ANIM_DUR)



local function hideNotif()

    Tween(Container,    {Position = UDim2.new(0, offscreenX, 0, finalY)}, ANIM_DUR)

    Tween(Win,          {BackgroundTransparency = 1},                      ANIM_DUR)

    Tween(GlassStroke,  {Transparency = 1},                                ANIM_DUR)

    Tween(DropShadow,   {BackgroundTransparency = 1},                      ANIM_DUR)

    Tween(TitleLabel,   {TextTransparency = 1},                            ANIM_DUR)

    Tween(ContentLabel, {TextTransparency = 1},                            ANIM_DUR)

    Tween(StickerBase,  {ImageTransparency = 1},                           ANIM_DUR)

    Tween(StickerEnergy,{ImageTransparency = 1},                           ANIM_DUR)

    task.wait(ANIM_DUR + 0.1)

    if Gui and Gui.Parent then

        Gui:Destroy()

    end

end



local function playFillAndHide()

    Tween(ContentLabel, {TextTransparency = 1}, 0.15)

    task.wait(0.15)

    ContentLabel.Text = "Microphone detected. Activating protection..."

    Tween(ContentLabel, {TextTransparency = 0}, 0.15)

    StickerEnergy.ImageTransparency = 0

    Tween(

        FillMask,

        {Size = UDim2.new(1, 0, 1, 0)},

        FILL_DUR,

        Enum.EasingStyle.Quart,

        Enum.EasingDirection.Out

    )

    task.wait(FILL_DUR + HOLD_AFTER)

    hideNotif()

end



-- ================= LÓGICA PRINCIPAL =================



repeat

    task.wait(2)

    local icon = geticonlabel()

until icon and icon.Image ~= mutedimage



task.spawn(playFillAndHide)

task.wait(1)



voicechatservice:leaveVoice()

task.wait(2)



local connections = getconnectionsfunc(voicechatinternal.StateChanged)

for i = 7, #connections do

    if connections[i] then

        connections[i]:Disable()

    end

end



task.wait(1)

voicechatservice:joinVoice()



getAudioInput()

task.wait(1)



ismuted = true

muteNow()

startWatchdog()

task.wait(2)



unibarcontainer, micmutebutton = findMicElements(30)



if unibarcontainer then

    local clonedmutebutton = nil

    local iconhitarea = nil

    local clonedicon = nil

    local hasSavedImage = false

    local savedImage = "rbxasset://textures/ui/VoiceChat/MicLight/Unmuted.png"



    if micmutebutton then

        pcall(function()

            clonedmutebutton = micmutebutton:Clone()

            for _, v in ipairs(clonedmutebutton:GetDescendants()) do

                if v:IsA("LocalScript") or v:IsA("Script") then

                    v:Destroy()

                end

            end

            iconhitarea = clonedmutebutton:FindFirstChild("IconHitArea_toggle_mic_mute", true)

            if iconhitarea then

                for _, conn in ipairs(getconnectionsfunc(iconhitarea.Activated)) do

                    conn:Disconnect()

                end

            end

            micmutebutton.Parent = hiddenfolder

            clonedmutebutton.Name = "toggle_mic_mute_new"

            clonedmutebutton.Parent = unibarcontainer

            clonedicon = geticonlabel(clonedmutebutton)

            local originalicon = geticonlabel(micmutebutton)

            if originalicon and originalicon.Image and string.len(originalicon.Image) > 0 then

                savedImage = originalicon.Image

                hasSavedImage = true

            end

        end)

    end



    -- SISTEMA DE RESPALDO (FALLBACK) para asegurar que a tu amigo también le aparezca siempre

    if not clonedmutebutton or not iconhitarea or not clonedicon then

        if clonedmutebutton then clonedmutebutton:Destroy() end

        

        clonedmutebutton = Instance.new("Frame")

        clonedmutebutton.Name = "toggle_mic_mute_fallback"

        clonedmutebutton.Size = UDim2.new(0, 36, 0, 36)

        clonedmutebutton.BackgroundTransparency = 1

        clonedmutebutton.Parent = unibarcontainer



        clonedicon = Instance.new("ImageLabel")

        clonedicon.Name = "IntegrationIcon"

        clonedicon.Size = UDim2.new(0, 24, 0, 24)

        clonedicon.Position = UDim2.new(0.5, -12, 0.5, -12)

        clonedicon.BackgroundTransparency = 1

        clonedicon.Image = savedImage

        clonedicon.Parent = clonedmutebutton



        iconhitarea = Instance.new("TextButton")

        iconhitarea.Name = "IconHitArea_toggle_mic_mute"

        iconhitarea.Size = UDim2.new(1, 0, 1, 0)

        iconhitarea.BackgroundTransparency = 1

        iconhitarea.Text = ""

        iconhitarea.Parent = clonedmutebutton

    end



    ismuted = false



    if clonedicon then

        clonedicon.Image = savedImage

        clonedicon.ImageColor3 = Color3.fromRGB(255, 255, 255)

    end



    unmuteNow()



    if iconhitarea then

        iconhitarea.Activated:Connect(function()

            ismuted = not ismuted

            if ismuted then

                muteNow()

                if clonedicon then

                    clonedicon.Image = mutedimage

                    clonedicon.ImageColor3 = Color3.fromRGB(255, 255, 255)

                end

            else

                unmuteNow()

                if clonedicon then

                    clonedicon.Image = savedImage

                    clonedicon.ImageColor3 = Color3.fromRGB(255, 255, 255)

                end

            end

        end)

    end

end
