--[[
    ============================================================
    MANOIR v6.0 — LocalScript StarterPlayerScripts
    Touche RightShift : ouvrir / fermer
    Refonte totale — ordre corrigé + Team Check global
    Suppression : Korblox / Headless / Kick Attempt
    ============================================================
]]

print("[Manoir] Démarrage v6.0...")

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

--==============================================================
-- PALETTE
--==============================================================
local C = {
    noir            = Color3.fromRGB(10, 10, 12),
    noirClair       = Color3.fromRGB(18, 18, 20),
    noirCarte       = Color3.fromRGB(24, 24, 27),
    noirElement     = Color3.fromRGB(32, 32, 36),
    gris            = Color3.fromRGB(90, 90, 95),
    grisClair       = Color3.fromRGB(150, 150, 155),
    grisPale        = Color3.fromRGB(200, 200, 205),
    grisTresClair   = Color3.fromRGB(230, 230, 235),
    blanc           = Color3.fromRGB(255, 255, 255),
    blancCasse      = Color3.fromRGB(245, 245, 248),
    separateur      = Color3.fromRGB(48, 48, 52),
    texte           = Color3.fromRGB(240, 240, 245),
    texteFaible     = Color3.fromRGB(150, 150, 155),
    texteTresFaible = Color3.fromRGB(95, 95, 100),
    succes          = Color3.fromRGB(120, 220, 130),
    erreur          = Color3.fromRGB(220, 80, 90),
    jaune           = Color3.fromRGB(240, 200, 90),
}

local POLICE       = Enum.Font.Gotham
local POLICE_MED   = Enum.Font.GothamMedium
local POLICE_BOLD  = Enum.Font.GothamBold
local POLICE_BLACK = Enum.Font.GothamBlack

--==============================================================
-- CONFIG GLOBAL
--==============================================================
local config = {
    esp_color      = Color3.fromRGB(255, 255, 255),
    chams_color    = Color3.fromRGB(200, 200, 205),
    tracer_color   = Color3.fromRGB(255, 255, 255),
    box_color      = Color3.fromRGB(255, 255, 255),
    headdot_color  = Color3.fromRGB(255, 80, 80),
    particles_color= Color3.fromRGB(255, 255, 255),
    ball717_color  = Color3.fromRGB(255, 220, 80),
    accent_color   = Color3.fromRGB(255, 255, 255),
    team_check     = false,   -- GLOBAL team check
}

local keysDown     = {}
local lastSafePos  = Vector3.new(0, 50, 0)
local flyVelocity  = nil
local selectedPlayer = nil

--==============================================================
-- HELPERS
--==============================================================
local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- TEAM CHECK GLOBAL
local function sameTeam(plr)
    if not config.team_check then return false end
    if not plr then return false end
    local myTeam = LocalPlayer.Team
    local pTeam  = plr.Team
    if myTeam == nil or pTeam == nil then return false end
    return myTeam == pTeam
end

--==============================================================
-- UTILITAIRES UI
--==============================================================
local function n(instance, props)
    local o = Instance.new(instance)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end

local function tw(obj, duree, style, dir, props)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(duree or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function coin(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, couleur, ep, transp)
    local s = Instance.new("UIStroke")
    s.Color = couleur or C.separateur
    s.Thickness = ep or 1
    s.Transparency = transp or 0.4
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent = parent
    return p
end

local function toHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

local function fromHex(s)
    s = s:gsub("#", "")
    if #s == 3 then
        s = s:sub(1,1):rep(2) .. s:sub(2,2):rep(2) .. s:sub(3,3):rep(2)
    end
    if #s ~= 6 then return nil end
    local ok, r, g, b = pcall(function()
        return tonumber(s:sub(1,2), 16), tonumber(s:sub(3,4), 16), tonumber(s:sub(5,6), 16)
    end)
    if not ok or not r or not g or not b then return nil end
    return Color3.fromRGB(r, g, b)
end

--==============================================================
-- NETTOYAGE
--==============================================================
local ancien = PlayerGui:FindFirstChild("ManoirMenu")
if ancien then ancien:Destroy() end

local ecran = n("ScreenGui", {
    Name = "ManoirMenu",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    Parent = PlayerGui,
})

--##############################################################
-- NOTIFICATIONS
--##############################################################
local notifHolder = n("Frame", {
    Size = UDim2.new(0, 300, 0, 400),
    Position = UDim2.new(1, -320, 0, 80),
    BackgroundTransparency = 1,
    Parent = ecran,
})
n("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = notifHolder,
})

local function notify(msg)
    if config.notifications == false then return end
    local card = n("Frame", {
        Size = UDim2.fromOffset(280, 40),
        BackgroundColor3 = C.noirCarte,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.1,
        LayoutOrder = -math.floor(os.clock() * 1000),
        Parent = notifHolder,
    })
    coin(card, 10)
    stroke(card, C.separateur, 1, 0.4)
    local dot = n("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0, 12, 0.5, -3),
        BackgroundColor3 = C.blanc,
        BorderSizePixel = 0,
        Parent = card,
    })
    coin(dot, 3)
    n("TextLabel", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1,
        Font = POLICE_MED,
        Text = msg,
        TextColor3 = C.texte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    card.Position = UDim2.new(1, 20, 0, 0)
    tw(card, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = UDim2.new(0, 0, 0, 0) })
    task.delay(2.5, function()
        local a = tw(card, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In, {
            Position = UDim2.new(1, 20, 0, 0),
            BackgroundTransparency = 1,
        })
        a.Completed:Connect(function() card:Destroy() end)
    end)
end

--##############################################################
-- COLOR PICKER
--##############################################################
local PRESETS = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 220, 220), Color3.fromRGB(180, 180, 180),
    Color3.fromRGB(140, 140, 140), Color3.fromRGB(100, 100, 100), Color3.fromRGB(60,  60,  60),
    Color3.fromRGB(20,  20,  20),  Color3.fromRGB(255, 80,  80),  Color3.fromRGB(255, 140, 60),
    Color3.fromRGB(255, 220, 80),  Color3.fromRGB(120, 255, 120), Color3.fromRGB(80,  220, 220),
    Color3.fromRGB(80,  140, 255), Color3.fromRGB(160, 100, 255), Color3.fromRGB(255, 100, 200),
    Color3.fromRGB(255, 180, 180), Color3.fromRGB(120, 60,  60),  Color3.fromRGB(60,  80,  40),
    Color3.fromRGB(40,  60,  100), Color3.fromRGB(80,  40,  120), Color3.fromRGB(255, 60,  120),
    Color3.fromRGB(0,   255, 160), Color3.fromRGB(0,   200, 255), Color3.fromRGB(255, 200, 0),
    Color3.fromRGB(180, 255, 0),   Color3.fromRGB(255, 0,   200), Color3.fromRGB(120, 0,   255),
    Color3.fromRGB(0,   120, 60),  Color3.fromRGB(200, 80,  0),   Color3.fromRGB(255, 100, 0),
}

local colorModal
local colorModalCurrentSetter = nil
local colorModalCurrentKey = nil
local colorModalPreview = nil
local colorModalHexBox = nil

local function openColorPicker(nom, initialColor, configKey, onChange)
    colorModalCurrentSetter = onChange
    colorModalCurrentKey = configKey

    if not colorModal then
        colorModal = n("Frame", {
            Size = UDim2.fromOffset(340, 380),
            Position = UDim2.new(0.5, -170, 0.5, -190),
            BackgroundColor3 = C.noirCarte,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 500,
            Parent = ecran,
        })
        coin(colorModal, 14)
        stroke(colorModal, C.separateur, 1, 0.3)

        local head = n("Frame", {
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundColor3 = C.noirClair,
            BorderSizePixel = 0,
            Parent = colorModal,
        })
        coin(head, 14)
        n("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.new(0, 0, 1, -20),
            BackgroundColor3 = C.noirClair,
            BorderSizePixel = 0,
            Parent = head,
        })

        n("TextLabel", {
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 16, 0, 0),
            BackgroundTransparency = 1,
            Font = POLICE_BOLD,
            Text = "Couleur",
            TextColor3 = C.texte,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = head,
        })

        local closeBtn = n("TextButton", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.new(1, -34, 0.5, -13),
            BackgroundColor3 = C.noirElement,
            BorderSizePixel = 0,
            Text = "×",
            Font = POLICE_BLACK,
            TextColor3 = C.grisClair,
            TextSize = 14,
            AutoButtonColor = false,
            Parent = head,
        })
        coin(closeBtn, 8)
        closeBtn.MouseButton1Click:Connect(function() colorModal.Visible = false end)

        local grid = n("Frame", {
            Size = UDim2.new(1, -24, 0, 180),
            Position = UDim2.new(0, 12, 0, 54),
            BackgroundTransparency = 1,
            Parent = colorModal,
        })
        n("UIGridLayout", {
            CellSize = UDim2.fromOffset(34, 34),
            CellPadding = UDim2.fromOffset(4, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = grid,
        })
        for i, col in ipairs(PRESETS) do
            local sw = n("TextButton", {
                Size = UDim2.fromOffset(34, 34),
                BackgroundColor3 = col,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = grid,
            })
            coin(sw, 8)
            stroke(sw, C.separateur, 1, 0.5)
            sw.MouseEnter:Connect(function() tw(sw, 0.15, nil, nil, { Size = UDim2.fromOffset(36, 36) }) end)
            sw.MouseLeave:Connect(function() tw(sw, 0.15, nil, nil, { Size = UDim2.fromOffset(34, 34) }) end)
            sw.MouseButton1Click:Connect(function()
                if colorModalPreview then colorModalPreview.BackgroundColor3 = col end
                if colorModalHexBox then colorModalHexBox.Text = toHex(col) end
            end)
        end

        local previewFrame = n("Frame", {
            Size = UDim2.fromOffset(60, 44),
            Position = UDim2.new(0, 14, 0, 246),
            BackgroundColor3 = initialColor,
            BorderSizePixel = 0,
            Parent = colorModal,
        })
        coin(previewFrame, 10)
        stroke(previewFrame, C.separateur, 1, 0.4)
        colorModalPreview = previewFrame

        local hexBox = n("TextBox", {
            Size = UDim2.new(1, -110, 0, 44),
            Position = UDim2.new(0, 84, 0, 246),
            BackgroundColor3 = C.noirElement,
            BorderSizePixel = 0,
            Font = POLICE_BOLD,
            Text = toHex(initialColor),
            PlaceholderText = "#FFFFFF",
            PlaceholderColor3 = C.texteTresFaible,
            TextColor3 = C.texte,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Center,
            ClearTextOnFocus = false,
            Parent = colorModal,
        })
        coin(hexBox, 10)
        stroke(hexBox, C.separateur, 1, 0.4)
        colorModalHexBox = hexBox

        hexBox:GetPropertyChangedSignal("Text"):Connect(function()
            local c = fromHex(hexBox.Text)
            if c and colorModalPreview then
                colorModalPreview.BackgroundColor3 = c
            end
        end)

        local applyBtn = n("TextButton", {
            Size = UDim2.new(0.5, -18, 0, 38),
            Position = UDim2.new(0, 12, 1, -52),
            BackgroundColor3 = C.blanc,
            BorderSizePixel = 0,
            Text = "Appliquer",
            Font = POLICE_BOLD,
            TextColor3 = C.noir,
            TextSize = 12,
            AutoButtonColor = false,
            Parent = colorModal,
        })
        coin(applyBtn, 10)
        applyBtn.MouseButton1Click:Connect(function()
            local c = fromHex(colorModalHexBox.Text) or (colorModalPreview and colorModalPreview.BackgroundColor3)
            if c and colorModalCurrentKey then
                config[colorModalCurrentKey] = c
            end
            if colorModalCurrentSetter then colorModalCurrentSetter(c) end
            colorModal.Visible = false
        end)

        local cancelBtn = n("TextButton", {
            Size = UDim2.new(0.5, -18, 0, 38),
            Position = UDim2.new(0.5, 6, 1, -52),
            BackgroundColor3 = C.noirElement,
            BorderSizePixel = 0,
            Text = "Annuler",
            Font = POLICE_BOLD,
            TextColor3 = C.texte,
            TextSize = 12,
            AutoButtonColor = false,
            Parent = colorModal,
        })
        coin(cancelBtn, 10)
        cancelBtn.MouseButton1Click:Connect(function() colorModal.Visible = false end)

        do
            local dragging, dragStart, startPos = false, nil, nil
            head.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = colorModal.Position
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if not dragging then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                    local delta = input.Position - dragStart
                    colorModal.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + delta.X,
                        startPos.Y.Scale, startPos.Y.Offset + delta.Y
                    )
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
        end
    end

    if colorModalPreview then colorModalPreview.BackgroundColor3 = initialColor end
    if colorModalHexBox then colorModalHexBox.Text = toHex(initialColor) end
    colorModal.Visible = true
end

local function creerColorRow(parent, nom, desc, defaut, ordre, configKey)
    config[configKey] = config[configKey] or defaut

    local ligne = n("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 42 or 34),
        BackgroundTransparency = 1,
        LayoutOrder = ordre,
        Parent = parent,
    })
    coin(ligne, 6)

    n("TextLabel", {
        Size = UDim2.new(1, -110, 0, desc and 18 or 34),
        Position = UDim2.new(0, 10, 0, desc and 4 or 0),
        BackgroundTransparency = 1,
        Font = POLICE_MED,
        Text = nom,
        TextColor3 = C.texte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ligne,
    })

    if desc then
        n("TextLabel", {
            Size = UDim2.new(1, -110, 0, 14),
            Position = UDim2.new(0, 10, 0, 22),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = desc,
            TextColor3 = C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = ligne,
        })
    end

    local swatch = n("TextButton", {
        Size = UDim2.fromOffset(70, 26),
        Position = UDim2.new(1, -80, 0.5, -13),
        BackgroundColor3 = config[configKey],
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = ligne,
    })
    coin(swatch, 8)
    stroke(swatch, C.separateur, 1, 0.4)

    local hexLbl = n("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Font = POLICE_BOLD,
        Text = toHex(config[configKey]),
        TextColor3 = C.noir,
        TextSize = 10,
        TextStrokeTransparency = 0.6,
        TextStrokeColor3 = C.blanc,
        Parent = swatch,
    })

    swatch.MouseEnter:Connect(function() tw(swatch, 0.18, nil, nil, { Size = UDim2.fromOffset(74, 28) }) end)
    swatch.MouseLeave:Connect(function() tw(swatch, 0.18, nil, nil, { Size = UDim2.fromOffset(70, 26) }) end)
    swatch.MouseButton1Click:Connect(function()
        openColorPicker(nom, config[configKey], configKey, function(c)
            if c then
                swatch.BackgroundColor3 = c
                hexLbl.Text = toHex(c)
            end
        end)
    end)
    return ligne
end

--##############################################################
-- CHARGEMENT
--##############################################################
local chargement = n("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = C.noir,
    BorderSizePixel = 0,
    ZIndex = 200,
    Parent = ecran,
})
local carte = n("Frame", {
    Size = UDim2.fromOffset(180, 180),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.noirCarte,
    BorderSizePixel = 0,
    ZIndex = 202,
    Parent = chargement,
})
coin(carte, 90)
stroke(carte, C.separateur, 1, 0.3)
n("TextLabel", {
    Size = UDim2.new(1, 0, 0, 26),
    Position = UDim2.new(0, 0, 0.5, -13),
    BackgroundTransparency = 1,
    Font = POLICE_BLACK,
    Text = "MANOIR",
    TextColor3 = C.grisPale,
    TextSize = 20,
    ZIndex = 205,
    Parent = carte,
})
local points = n("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 0.5, 16),
    BackgroundTransparency = 1,
    Font = POLICE,
    Text = "Chargement",
    TextColor3 = C.texteTresFaible,
    TextSize = 10,
    ZIndex = 205,
    Parent = carte,
})
task.spawn(function()
    local etats = {"Chargement", "Chargement.", "Chargement..", "Chargement..."}
    local i = 1
    while points.Parent do
        points.Text = etats[i]
        i = i % #etats + 1
        task.wait(0.35)
    end
end)
carte.Size = UDim2.fromOffset(0, 0)
tw(carte, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(180, 180) })
task.wait(1.8)
local sortie = tw(chargement, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
tw(carte, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In, { Size = UDim2.fromOffset(0, 0) })
sortie.Completed:Connect(function() if chargement and chargement.Parent then chargement:Destroy() end end)
task.delay(4, function() if chargement and chargement.Parent then chargement:Destroy() end end)

--##############################################################
-- BOUTON FLOTTANT
--##############################################################
local boutonFlottant = n("TextButton", {
    Size = UDim2.fromOffset(0, 0),
    Position = UDim2.new(0, 22, 0, 22),
    BackgroundColor3 = C.noirCarte,
    BorderSizePixel = 0,
    Text = "M",
    Font = POLICE_BLACK,
    TextColor3 = C.blanc,
    TextSize = 22,
    TextTransparency = 1,
    AutoButtonColor = false,
    Parent = ecran,
})
coin(boutonFlottant, 27)
stroke(boutonFlottant, C.separateur, 1, 0.2)
tw(boutonFlottant, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(54, 54) })
tw(boutonFlottant, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0 })

do
    local dragging, dragStart, startPos = false, nil, nil
    boutonFlottant.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = boutonFlottant.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            boutonFlottant.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--##############################################################
-- FENÊTRE
--##############################################################
local fenetre = n("Frame", {
    Size = UDim2.fromOffset(700, 500),
    Position = UDim2.new(0.5, -350, 0.5, -250),
    BackgroundColor3 = C.noir,
    BorderSizePixel = 0,
    Visible = false,
    ClipsDescendants = true,
    Parent = ecran,
})
coin(fenetre, 18)
stroke(fenetre, C.separateur, 1, 0.4)

local barreTitre = n("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = C.noirClair,
    BorderSizePixel = 0,
    Parent = fenetre,
})
coin(barreTitre, 18)
n("Frame", {
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.new(0, 0, 1, -20),
    BackgroundColor3 = C.noirClair,
    BorderSizePixel = 0,
    Parent = barreTitre,
})

local logo = n("Frame", {
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(0, 18, 0.5, -15),
    BackgroundColor3 = C.blanc,
    BorderSizePixel = 0,
    Parent = barreTitre,
})
coin(logo, 15)
n("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = POLICE_BLACK,
    Text = "M",
    TextColor3 = C.noir,
    TextSize = 16,
    Parent = logo,
})

n("TextLabel", {
    Size = UDim2.new(0, 130, 1, 0),
    Position = UDim2.new(0, 58, 0, 0),
    BackgroundTransparency = 1,
    Font = POLICE_BLACK,
    Text = "MANOIR",
    TextColor3 = C.grisPale,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barreTitre,
})
n("TextLabel", {
    Size = UDim2.new(0, 240, 1, 0),
    Position = UDim2.new(0, 165, 0, 0),
    BackgroundTransparency = 1,
    Font = POLICE,
    Text = "ce script a etais cree pour niquer la  mere au crea de school rp",
    TextColor3 = C.texteTresFaible,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barreTitre,
})
n("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = C.separateur,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = barreTitre,
})

local boutonReduire = n("TextButton", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(1, -88, 0.5, -17),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Text = "—",
    Font = POLICE_BOLD,
    TextColor3 = C.grisClair,
    TextSize = 14,
    AutoButtonColor = false,
    Parent = barreTitre,
})
coin(boutonReduire, 10)

local boutonFermer = n("TextButton", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(1, -48, 0.5, -17),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Text = "×",
    Font = POLICE_BLACK,
    TextColor3 = C.grisClair,
    TextSize = 18,
    AutoButtonColor = false,
    Parent = barreTitre,
})
coin(boutonFermer, 10)

do
    local dragging, dragStart, startPos = false, nil, nil
    barreTitre.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            local abs = barreTitre.AbsolutePosition
            local taille = barreTitre.AbsoluteSize
            local souris = UserInputService:GetMouseLocation()
            if (souris.X - abs.X) > taille.X - 130 then return end
            dragging = true
            dragStart = input.Position
            startPos = fenetre.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            fenetre.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--##############################################################
-- SIDEBAR
--##############################################################
local barreOnglets = n("Frame", {
    Size = UDim2.new(0, 180, 1, -54),
    Position = UDim2.new(0, 0, 0, 54),
    BackgroundColor3 = C.noirClair,
    BorderSizePixel = 0,
    Parent = fenetre,
})
n("Frame", {
    Size = UDim2.new(0, 1, 1, 0),
    Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = C.separateur,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = barreOnglets,
})

local profilCard = n("Frame", {
    Size = UDim2.new(1, -20, 0, 66),
    Position = UDim2.new(0, 10, 0, 12),
    BackgroundColor3 = C.noirCarte,
    BorderSizePixel = 0,
    Parent = barreOnglets,
})
coin(profilCard, 12)
stroke(profilCard, C.separateur, 1, 0.6)

local cadreAvatar = n("Frame", {
    Size = UDim2.fromOffset(44, 44),
    Position = UDim2.new(0, 11, 0.5, -22),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Parent = profilCard,
})
coin(cadreAvatar, 22)
stroke(cadreAvatar, C.gris, 1.5, 0.3)
local avImg = n("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = "",
    Parent = cadreAvatar,
})
coin(avImg, 22)
pcall(function()
    avImg.Image = Players:GetUserThumbnailAsync(
        LocalPlayer.UserId,
        Enum.ThumbnailType.HeadShot,
        Enum.ThumbnailSize.Size100x100
    )
end)

n("TextLabel", {
    Size = UDim2.new(1, -70, 0, 17),
    Position = UDim2.new(0, 64, 0, 12),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = LocalPlayer.DisplayName or LocalPlayer.Name,
    TextColor3 = C.blancCasse,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = profilCard,
})
n("TextLabel", {
    Size = UDim2.new(1, -70, 0, 13),
    Position = UDim2.new(0, 64, 0, 30),
    BackgroundTransparency = 1,
    Font = POLICE,
    Text = "@" .. LocalPlayer.Name,
    TextColor3 = C.texteFaible,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Parent = profilCard,
})
local badge = n("Frame", {
    Size = UDim2.fromOffset(48, 14),
    Position = UDim2.new(0, 64, 0, 46),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Parent = profilCard,
})
coin(badge, 4)
n("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "PRIVÉ",
    TextColor3 = C.grisPale,
    TextSize = 9,
    Parent = badge,
})

n("TextLabel", {
    Size = UDim2.new(1, -20, 0, 16),
    Position = UDim2.new(0, 18, 0, 92),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "N A V I G A T I O N",
    TextColor3 = C.texteTresFaible,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = barreOnglets,
})

local listeOnglets = n("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -170),
    Position = UDim2.new(0, 8, 0, 114),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.gris,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = barreOnglets,
})
n("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = listeOnglets,
})

local piedBarre = n("Frame", {
    Size = UDim2.new(1, -20, 0, 48),
    Position = UDim2.new(0, 10, 1, -58),
    BackgroundColor3 = C.noirCarte,
    BorderSizePixel = 0,
    Parent = barreOnglets,
})
coin(piedBarre, 10)
stroke(piedBarre, C.separateur, 1, 0.6)
local indicateurStatut = n("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.new(0, 12, 0, 14),
    BackgroundColor3 = C.succes,
    BorderSizePixel = 0,
    Parent = piedBarre,
})
coin(indicateurStatut, 4)
n("TextLabel", {
    Size = UDim2.new(1, -30, 0, 14),
    Position = UDim2.new(0, 26, 0, 11),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "Connecté",
    TextColor3 = C.succes,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = piedBarre,
})
n("TextLabel", {
    Size = UDim2.new(1, -30, 0, 12),
    Position = UDim2.new(0, 26, 0, 26),
    BackgroundTransparency = 1,
    Font = POLICE,
    Text = "Session sécurisée",
    TextColor3 = C.texteFaible,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = piedBarre,
})

local zoneContenu = n("Frame", {
    Size = UDim2.new(1, -180, 1, -54),
    Position = UDim2.new(0, 180, 0, 54),
    BackgroundColor3 = C.noir,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = fenetre,
})

--##############################################################
-- ONGLETS FRAMEWORK
--##############################################################
local onglets = {}
local pages = {}
local ongletActif = nil

local function creerBoutonOnglet(nom, ordre)
    local b = n("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.noirCarte,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = ordre,
        Parent = listeOnglets,
    })
    coin(b, 10)

    local barreSel = n("Frame", {
        Size = UDim2.new(0, 3, 0, 0),
        Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.blanc,
        BorderSizePixel = 0,
        Parent = b,
    })
    coin(barreSel, 2)
    local point = n("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0, 14, 0.5, -3),
        BackgroundColor3 = C.texteTresFaible,
        BorderSizePixel = 0,
        Parent = b,
    })
    coin(point, 3)
    local txt = n("TextLabel", {
        Size = UDim2.new(1, -34, 1, 0),
        Position = UDim2.new(0, 28, 0, 0),
        BackgroundTransparency = 1,
        Font = POLICE_BOLD,
        Text = nom,
        TextColor3 = C.texteFaible,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = b,
    })
    onglets[nom] = { bouton = b, selection = barreSel, texte = txt, point = point }
    return b
end

local function creerPage(nom)
    local p = n("ScrollingFrame", {
        Name = nom,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.gris,
        ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = zoneContenu,
    })
    padding(p, 18, 18, 18, 16)
    n("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = p,
    })
    pages[nom] = p
    return p
end

local function afficherOnglet(nom)
    if ongletActif == nom then return end
    for cle, page in pairs(pages) do
        if cle == nom then
            page.Visible = true
            page.Position = UDim2.new(0, 30, 0, 0)
            tw(page, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
                Position = UDim2.new(0, 0, 0, 0),
            })
        elseif page.Visible then
            local a = tw(page, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.In, {
                Position = UDim2.new(0, -30, 0, 0),
            })
            a.Completed:Connect(function() page.Visible = false end)
        end
    end
    for cle, d in pairs(onglets) do
        if cle == nom then
            tw(d.bouton, 0.2, nil, nil, { BackgroundTransparency = 0.2, BackgroundColor3 = C.noirCarte })
            tw(d.selection, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.new(0, 3, 0.65, 0) })
            tw(d.texte, 0.2, nil, nil, { TextColor3 = C.blanc })
            tw(d.point, 0.2, nil, nil, { BackgroundColor3 = C.blanc })
        else
            tw(d.bouton, 0.2, nil, nil, { BackgroundTransparency = 1 })
            tw(d.selection, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.new(0, 3, 0, 0) })
            tw(d.texte, 0.2, nil, nil, { TextColor3 = C.texteFaible })
            tw(d.point, 0.2, nil, nil, { BackgroundColor3 = C.texteTresFaible })
        end
    end
    ongletActif = nom
end

--##############################################################
-- COMPOSANTS
--##############################################################
local function creerSection(parent, titreSection, sousTitre)
    local cadre = n("Frame", {
        Size = UDim2.new(1, 0, 0, sousTitre and 44 or 30),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    n("TextLabel", {
        Size = UDim2.new(1, -20, 0, sousTitre and 20 or 30),
        Position = UDim2.new(0, 2, 0, 0),
        BackgroundTransparency = 1,
        Font = POLICE_BLACK,
        Text = string.upper(titreSection),
        TextColor3 = C.blanc,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = sousTitre and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        Parent = cadre,
    })
    if sousTitre then
        n("TextLabel", {
            Size = UDim2.new(1, -20, 0, 14),
            Position = UDim2.new(0, 2, 0, 16),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = sousTitre,
            TextColor3 = C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = cadre,
        })
    end
    n("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = C.separateur,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        Parent = cadre,
    })
    return cadre
end

local function creerConteneur(parent)
    local c = n("Frame", {
        Size = UDim2.new(1, -4, 0, 0),
        BackgroundColor3 = C.noirCarte,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parent,
    })
    coin(c, 12)
    stroke(c, C.separateur, 1, 0.55)
    padding(c, 8, 8, 8, 8)
    n("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = c,
    })
    return c
end

local function creerToggle(parent, nom, desc, defaut, ordre, configKey)
    if configKey then config[configKey] = config[configKey] == nil and defaut or config[configKey] end

    local ligne = n("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 42 or 34),
        BackgroundTransparency = 1,
        LayoutOrder = ordre,
        Parent = parent,
    })
    coin(ligne, 6)

    n("TextLabel", {
        Size = UDim2.new(1, -60, 0, desc and 18 or 34),
        Position = UDim2.new(0, 10, 0, desc and 4 or 0),
        BackgroundTransparency = 1,
        Font = POLICE_MED,
        Text = nom,
        TextColor3 = C.texte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ligne,
    })

    if desc then
        n("TextLabel", {
            Size = UDim2.new(1, -60, 0, 14),
            Position = UDim2.new(0, 10, 0, 21),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = desc,
            TextColor3 = C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = ligne,
        })
    end

    local etat = config[configKey]
    local piste = n("Frame", {
        Size = UDim2.fromOffset(38, 20),
        Position = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = etat and C.blanc or C.noirElement,
        BorderSizePixel = 0,
        Parent = ligne,
    })
    coin(piste, 10)
    stroke(piste, C.separateur, 1, 0.4)
    local cercle = n("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = etat and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = etat and C.noir or C.grisClair,
        BorderSizePixel = 0,
        Parent = piste,
    })
    coin(cercle, 8)

    local bouton = n("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        Parent = ligne,
    })
    bouton.MouseEnter:Connect(function()
        tw(ligne, 0.18, nil, nil, { BackgroundColor3 = C.noirElement, BackgroundTransparency = 0.4 })
    end)
    bouton.MouseLeave:Connect(function()
        tw(ligne, 0.18, nil, nil, { BackgroundTransparency = 1 })
    end)
    bouton.MouseButton1Click:Connect(function()
        etat = not etat
        if configKey then config[configKey] = etat end
        if etat then
            tw(piste, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundColor3 = C.blanc })
            tw(cercle, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
                Position = UDim2.new(1, -18, 0.5, -8),
                BackgroundColor3 = C.noir,
            })
        else
            tw(piste, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { BackgroundColor3 = C.noirElement })
            tw(cercle, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
                Position = UDim2.new(0, 2, 0.5, -8),
                BackgroundColor3 = C.grisClair,
            })
        end
    end)
    return ligne
end

local function creerSlider(parent, nom, desc, min, max, defaut, ordre, suffixe, configKey)
    suffixe = suffixe or ""
    if configKey then config[configKey] = config[configKey] or defaut end

    local valeur = config[configKey]
    local cadre = n("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 60 or 48),
        BackgroundTransparency = 1,
        LayoutOrder = ordre,
        Parent = parent,
    })

    n("TextLabel", {
        Size = UDim2.new(1, -110, 0, 18),
        Position = UDim2.new(0, 10, 0, desc and 4 or 6),
        BackgroundTransparency = 1,
        Font = POLICE_MED,
        Text = nom,
        TextColor3 = C.texte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = cadre,
    })
    local valeurTxt = n("TextLabel", {
        Size = UDim2.new(0, 100, 0, 18),
        Position = UDim2.new(1, -110, 0, desc and 4 or 6),
        BackgroundTransparency = 1,
        Font = POLICE_BOLD,
        Text = tostring(valeur) .. suffixe,
        TextColor3 = C.blanc,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = cadre,
    })

    if desc then
        n("TextLabel", {
            Size = UDim2.new(1, -20, 0, 14),
            Position = UDim2.new(0, 10, 0, 22),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = desc,
            TextColor3 = C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = cadre,
        })
    end

    local rail = n("Frame", {
        Size = UDim2.new(1, -20, 0, 5),
        Position = UDim2.new(0, 10, 0, desc and 44 or 34),
        BackgroundColor3 = C.noirElement,
        BorderSizePixel = 0,
        Parent = cadre,
    })
    coin(rail, 3)

    local p = (valeur - min) / (max - min)
    local remplissage = n("Frame", {
        Size = UDim2.new(p, 0, 1, 0),
        BackgroundColor3 = C.blanc,
        BorderSizePixel = 0,
        Parent = rail,
    })
    coin(remplissage, 3)
    local poignee = n("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(p, -8, 0.5, -8),
        BackgroundColor3 = C.blanc,
        BorderSizePixel = 0,
        Parent = rail,
    })
    coin(poignee, 8)
    stroke(poignee, C.noir, 2, 0)

    local glisse = false
    local btn = n("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.new(0, 0, 0, -9),
        BackgroundTransparency = 1,
        Text = "",
        Parent = rail,
    })
    btn.MouseButton1Down:Connect(function()
        glisse = true
        tw(poignee, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(20, 20) })
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            if glisse then
                tw(poignee, 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Size = UDim2.fromOffset(16, 16) })
            end
            glisse = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if glisse then
            local souris = UserInputService:GetMouseLocation()
            local xAbs = rail.AbsolutePosition.X
            local larg = rail.AbsoluteSize.X
            local ratio = math.clamp((souris.X - xAbs) / larg, 0, 1)
            valeur = math.floor(min + (max - min) * ratio + 0.5)
            valeurTxt.Text = tostring(valeur) .. suffixe
            remplissage.Size = UDim2.new(ratio, 0, 1, 0)
            poignee.Position = UDim2.new(ratio, -10, 0.5, -10)
            if configKey then config[configKey] = valeur end
        end
    end)
    return cadre
end

local function creerBouton(parent, texte, desc, couleurTexte, ordre, callback)
    couleurTexte = couleurTexte or C.texte

    local ligne = n("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = ordre,
        Parent = parent,
    })
    local btn = n("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.noirElement,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = ligne,
    })
    coin(btn, 10)
    stroke(btn, C.separateur, 1, 0.55)
    n("TextLabel", {
        Size = UDim2.new(0.6, -16, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Font = POLICE_BOLD,
        Text = texte,
        TextColor3 = couleurTexte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn,
    })
    if desc then
        n("TextLabel", {
            Size = UDim2.new(0.4, -14, 1, 0),
            Position = UDim2.new(0.6, 0, 0, 0),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = desc,
            TextColor3 = C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = btn,
        })
    end
    btn.MouseEnter:Connect(function()
        tw(btn, 0.18, nil, nil, { BackgroundColor3 = Color3.fromRGB(46, 46, 50) })
    end)
    btn.MouseLeave:Connect(function()
        tw(btn, 0.18, nil, nil, { BackgroundColor3 = C.noirElement })
    end)
    btn.MouseButton1Click:Connect(function()
        tw(btn, 0.1, nil, nil, { BackgroundColor3 = C.blanc })
        task.delay(0.14, function()
            tw(btn, 0.28, nil, nil, { BackgroundColor3 = C.noirElement })
        end)
        if callback then callback() end
    end)
    return ligne
end

local function creerKeybind(parent, nom, desc, toucheDefaut, ordre, configKey)
    if configKey then config[configKey] = config[configKey] or toucheDefaut end

    local ligne = n("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 42 or 34),
        BackgroundTransparency = 1,
        LayoutOrder = ordre,
        Parent = parent,
    })
    coin(ligne, 6)
    n("TextLabel", {
        Size = UDim2.new(1, -110, 0, desc and 18 or 34),
        Position = UDim2.new(0, 10, 0, desc and 4 or 0),
        BackgroundTransparency = 1,
        Font = POLICE_MED,
        Text = nom,
        TextColor3 = C.texte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ligne,
    })
    if desc then
        n("TextLabel", {
            Size = UDim2.new(1, -110, 0, 14),
            Position = UDim2.new(0, 10, 0, 22),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = desc,
            TextColor3 = C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = ligne,
        })
    end
    local btn = n("TextButton", {
        Size = UDim2.fromOffset(88, 26),
        Position = UDim2.new(1, -98, 0.5, -13),
        BackgroundColor3 = C.noirElement,
        BorderSizePixel = 0,
        Text = config[configKey],
        Font = POLICE_BOLD,
        TextColor3 = C.blanc,
        TextSize = 11,
        AutoButtonColor = false,
        Parent = ligne,
    })
    coin(btn, 8)
    stroke(btn, C.separateur, 1, 0.5)
    local enAttente = false
    btn.MouseButton1Click:Connect(function()
        enAttente = true
        btn.Text = "..."
        tw(btn, 0.18, nil, nil, { BackgroundColor3 = C.blanc, TextColor3 = C.noir })
    end)
    UserInputService.InputBegan:Connect(function(input)
        if not enAttente then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        enAttente = false
        btn.Text = input.KeyCode.Name
        if configKey then config[configKey] = input.KeyCode.Name end
        tw(btn, 0.28, nil, nil, { BackgroundColor3 = C.noirElement, TextColor3 = C.blanc })
    end)
    return ligne
end

local function creerLigneInfo(parent, nom, valeur, ordre)
    local ligne = n("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = ordre,
        Parent = parent,
    })
    n("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Font = POLICE_MED,
        Text = nom,
        TextColor3 = C.texte,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ligne,
    })
    local val = n("TextLabel", {
        Size = UDim2.new(0, 180, 1, 0),
        Position = UDim2.new(1, -190, 0, 0),
        BackgroundTransparency = 1,
        Font = POLICE_BOLD,
        Text = valeur,
        TextColor3 = C.blanc,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = ligne,
    })
    return ligne, val
end

--##############################################################
-- PAGE : COMBAT
--##############################################################
local pageCombat = creerPage("Combat")

creerSection(pageCombat, "Aimbot", "Système de visée automatique")
local cAim = creerConteneur(pageCombat)
creerToggle(cAim, "Aimbot", "Active la visée automatique", false, 1, "aimbot")
creerToggle(cAim, "Visée tête", "Cible la tête plutôt que le torse", true, 2, "aimbot_head")
creerToggle(cAim, "Silent Aim", "Lerp instantané", false, 3, "silent_aim")
creerToggle(cAim, "Visible seulement", "Ignore les cibles cachées par un mur", false, 4, "aimbot_visible")
creerToggle(cAim, "Team Check", "Ignore les membres de ta team", false, 5, "aim_team_check")
creerKeybind(cAim, "Touche d'activation", "Maintenir pour viser", "E", 6, "aimbot_key")
creerSlider(cAim, "FOV Aimbot", "Champ de vision", 10, 800, 150, 7, " px", "aimbot_fov")
creerSlider(cAim, "Smoothness", "Vitesse d'alignement (bas = lent)", 1, 100, 35, 8, " %", "aimbot_smooth")

creerSection(pageCombat, "Triggerbot")
local cTrig = creerConteneur(pageCombat)
creerToggle(cTrig, "Triggerbot", "Tire automatiquement sur la cible sous le curseur", false, 1, "triggerbot")
creerToggle(cTrig, "Instantané", "Ignore les délais", false, 2, "triggerbot_instant")
creerToggle(cTrig, "Team Check", "Ignore les membres de ta team", false, 3, "trig_team_check")
creerSlider(cTrig, "Délai de réaction", "Latence avant tir", 0, 500, 50, 4, " ms", "triggerbot_delay")

creerSection(pageCombat, "Répartition des tirs")
local cTir = creerConteneur(pageCombat)
creerToggle(cTir, "No Recoil", "Supprime le recul", false, 1, "no_recoil")
creerToggle(cTir, "Rapid Fire", "Cadence augmentée", false, 2, "rapid_fire")
creerSlider(cTir, "Vitesse Rapid Fire", "Intervalle entre tirs", 20, 500, 80, 3, " ms", "rapidfire_speed")

creerSection(pageCombat, "Hitbox")
local cHit = creerConteneur(pageCombat)
creerToggle(cHit, "Hitbox Expander", "Étend la zone de détection", false, 1, "hitbox_expand")
creerToggle(cHit, "Team Check", "Ignore les membres de ta team", false, 2, "hit_team_check")
creerSlider(cHit, "Taille de la hitbox", "Multiplicateur de taille", 1, 20, 3, 3, "x", "hitbox_size")

creerSection(pageCombat, "Extensions Combat", "Options avancées de combat")
local cCombatExt = creerConteneur(pageCombat)
creerToggle(cCombatExt, "Aim Through Walls", "Vise même à travers les murs", false, 1, "aim_walls")
creerToggle(cCombatExt, "Auto Shoot", "Tire en continu sur la cible valide", false, 2, "auto_shoot")
creerToggle(cCombatExt, "Sticky Aim", "Verrouille la cible jusqu'à mort", false, 3, "sticky_aim")
creerSlider(cCombatExt, "FOV Circle Size", "Taille du cercle FOV visuel", 20, 600, 150, 4, " px", "fov_circle")

--##############################################################
-- PAGE : DÉPLACEMENT
--##############################################################
local pageDepl = creerPage("Deplacement")

creerSection(pageDepl, "Vitesse")
local cVit = creerConteneur(pageDepl)
creerToggle(cVit, "Speed Hack", "Modifie la vitesse", false, 1, "speed_hack")
creerSlider(cVit, "Walkspeed", "Vitesse de marche", 16, 500, 32, 2, " u/s", "walkspeed")
creerToggle(cVit, "Infinite Jump", "Sauter sans limite", false, 3, "infinite_jump")
creerSlider(cVit, "Jump Power", "Puissance de saut", 50, 500, 80, 4, " u", "jump_power")

creerSection(pageDepl, "Vol & Noclip")
local cVol = creerConteneur(pageDepl)
creerToggle(cVol, "Fly", "Vol libre (WASD + Space/Ctrl)", false, 1, "fly")
creerToggle(cVol, "Noclip", "Traverser les obstacles", false, 2, "noclip")
creerKeybind(cVol, "Touche Fly", "Basculer le vol", "F", 3, "fly_key")
creerSlider(cVol, "Vitesse de vol", "Vitesse en vol", 20, 1000, 120, 4, " u/s", "fly_speed")

creerSection(pageDepl, "Extensions Mouvement", "Physique avancée")
local cDeplExt = creerConteneur(pageDepl)
creerToggle(cDeplExt, "Bunny Hop", "Saut automatique en rythme", false, 1, "bhop")
creerToggle(cDeplExt, "Auto Sprint", "Course permanente", false, 2, "auto_sprint")
creerToggle(cDeplExt, "Wall Climb", "Grimpe sur les murs verticaux", false, 3, "wall_climb")
creerSlider(cDeplExt, "Slide Speed", "Vitesse de glissade", 20, 400, 80, 4, " u/s", "slide_speed")
creerSlider(cDeplExt, "Air Control", "Contrôle en l'air", 0, 100, 50, 5, " %", "air_control")

--##############################################################
-- PAGE : VISUEL
--##############################################################
local pageVisuel = creerPage("Visuel")

creerSection(pageVisuel, "ESP Joueurs", "Affiche les informations des joueurs")
local cEsp = creerConteneur(pageVisuel)
creerToggle(cEsp, "ESP Activé", "Activer l'affichage", false, 1, "esp")
creerToggle(cEsp, "Team Check", "Ignore les membres de ta team", false, 2, "esp_team_check")
creerToggle(cEsp, "Nom du joueur", "Affiche le pseudo", true, 3, "esp_name")
creerToggle(cEsp, "Barre de vie", "Affiche les PV", true, 4, "esp_health")
creerToggle(cEsp, "Distance", "Affiche la distance", true, 5, "esp_dist")
creerToggle(cEsp, "Boîte de collision", "Contour du personnage", true, 6, "esp_box")
creerToggle(cEsp, "Lignes de traçage", "Ligne vers la cible", false, 7, "esp_tracer")
creerToggle(cEsp, "Rainbow ESP", "Couleur qui tourne", false, 8, "esp_rainbow")
creerColorRow(cEsp, "Couleur ESP", "Couleur de la boîte et du contour", C.blanc, 9, "esp_color")
creerColorRow(cEsp, "Couleur traçage", "Lignes de traçage", C.blanc, 10, "tracer_color")
creerSlider(cEsp, "Distance max ESP", "Portée d'affichage", 100, 3000, 1500, 11, " u", "esp_range")

creerSection(pageVisuel, "Chams")
local cChams = creerConteneur(pageVisuel)
creerToggle(cChams, "Chams Activés", "Coloration des personnages", false, 1, "chams")
creerToggle(cChams, "Team Check", "Ignore les membres de ta team", false, 2, "chams_team_check")
creerColorRow(cChams, "Couleur Chams", "Teinte d'affichage", C.grisPale, 3, "chams_color")
creerSlider(cChams, "Transparence", "Opacité de la couleur", 0, 100, 30, 4, " %", "chams_alpha")

creerSection(pageVisuel, "Ambiance")
local cAmb = creerConteneur(pageVisuel)
creerToggle(cAmb, "Fullbright", "Éclairage maximal", true, 1, "fullbright")
creerToggle(cAmb, "No Fog", "Supprime le brouillard", false, 2, "no_fog")
creerSlider(cAmb, "Luminosité", "Intensité lumineuse", 0, 100, 50, 3, " %", "brightness")

creerSection(pageVisuel, "Extensions Visuel", "Options d'affichage avancées")
local cVisExt = creerConteneur(pageVisuel)
creerToggle(cVisExt, "Skeleton ESP", "Affiche le squelette (lignes os)", false, 1, "esp_skeleton")
creerToggle(cVisExt, "Head Dot", "Point sur la tête des cibles", false, 2, "esp_headdot")
creerColorRow(cVisExt, "Couleur Head Dot", "Teinte du point tête", Color3.fromRGB(255, 80, 80), 3, "headdot_color")
creerSlider(cVisExt, "Outline Thickness", "Épaisseur du contour ESP", 1, 5, 1, 4, " px", "esp_outline")

--##############################################################
-- PAGE : MONDE
--##############################################################
local pageMonde = creerPage("Monde")

creerSection(pageMonde, "Temps")
local cTemps = creerConteneur(pageMonde)
creerSlider(cTemps, "Heure", "Heure de la journée", 0, 24, 12, 1, " h", "clock_time")
creerToggle(cTemps, "Verrouiller", "Figer le temps", false, 2, "clock_lock")

creerSection(pageMonde, "Environnement")
local cEnv = creerConteneur(pageMonde)
creerToggle(cEnv, "Walk on Water", "Marcher sur l'eau", false, 1, "walk_water")
creerToggle(cEnv, "Anti Collision", "Aucun dégât de collision", false, 2, "anti_collision")

creerSection(pageMonde, "Informations serveur")
local cInfo = creerConteneur(pageMonde)
local _, lblId      = creerLigneInfo(cInfo, "Identifiant serveur", tostring(game.JobId):sub(1, 14) .. "…", 1)
local _, lblJoueurs = creerLigneInfo(cInfo, "Joueurs", "0 / 0", 2)
local _, lblPing    = creerLigneInfo(cInfo, "Ping moyen", "0 ms", 3)

creerSection(pageMonde, "Extensions Monde", "Contrôle physique et environnement")
local cMondeExt = creerConteneur(pageMonde)
creerToggle(cMondeExt, "Gravity Hack", "Réduit la gravité", false, 1, "gravity_hack")
creerSlider(cMondeExt, "Gravité", "Multiplicateur de gravité", 0, 200, 100, 2, " %", "gravity_val")
creerToggle(cMondeExt, "Freeze Time", "Fige les animations du monde", false, 3, "freeze_time")
creerToggle(cMondeExt, "Remove Fog", "Brouillard complètement retiré", false, 4, "remove_fog")
creerToggle(cMondeExt, "Disable Shadows", "Retire les ombres globales", false, 5, "disable_shadows")

task.spawn(function()
    while ecran.Parent do
        if lblJoueurs then lblJoueurs.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers end
        if lblPing then
            local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
            if ok then lblPing.Text = string.format("%d ms", ping) end
        end
        task.wait(1)
    end
end)

--##############################################################
-- PAGE : INTERFACE
--##############################################################
local pageInter = creerPage("Interface")

creerSection(pageInter, "Affichage")
local cAff = creerConteneur(pageInter)
creerToggle(cAff, "Watermark", "Affiche le logo en jeu", true, 1, "watermark")
creerToggle(cAff, "FPS Counter", "Compteur d'images", false, 2, "fps_counter")
creerToggle(cAff, "Ping Display", "Affiche la latence", false, 3, "ping_display")
creerToggle(cAff, "Notifications", "Messages d'état", true, 4, "notifications")

creerSection(pageInter, "Raccourcis")
local cRac = creerConteneur(pageInter)
creerKeybind(cRac, "Ouvrir / Fermer", "Afficher ce menu", "RightShift", 1, "menu_key")
creerKeybind(cRac, "Toggle principal", "Activer / désactiver", "Delete", 2, "toggle_key")

creerSection(pageInter, "Extensions Interface", "Personnalisation UI")
local cInterExt = creerConteneur(pageInter)
creerKeybind(cInterExt, "Panic Key", "Coupe tous les cheats instantanément", "End", 1, "panic_key")
creerToggle(cInterExt, "FPS Cap 60", "Limite à 60 FPS", false, 2, "fps_cap_60")
creerToggle(cInterExt, "Hide GUI on Screenshot", "Cache l'UI pour screenshots", false, 3, "hide_screenshot")
creerSlider(cInterExt, "UI Scale", "Échelle de l'interface", 50, 150, 100, 4, " %", "ui_scale")
creerColorRow(cInterExt, "Couleur accent", "Teinte d'accent UI", C.blanc, 5, "accent_color")

--##############################################################
-- PAGE : PLAYER
--##############################################################
local pagePlayer = creerPage("Player")

local forceTPActive  = false
local forceTPConn    = nil
local followActive   = false
local followConn     = nil
local dropOpen       = false

creerSection(pagePlayer, "Cible sélectionnée", "Choisis un joueur dans la liste")
local cSel = creerConteneur(pagePlayer)
local _, lblCible = creerLigneInfo(cSel, "Joueur", "Aucun", 1)
local _, lblDist  = creerLigneInfo(cSel, "Distance", "— u", 2)
local _, lblHP    = creerLigneInfo(cSel, "Vie", "— / —", 3)

creerSection(pagePlayer, "Liste des joueurs", "Clique pour dérouler / sélectionner")
local cListe = creerConteneur(pagePlayer)

local dropHeader = n("TextButton", {
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    LayoutOrder = 1,
    Parent = cListe,
})
coin(dropHeader, 10)
stroke(dropHeader, C.separateur, 1, 0.5)

local dropArrow = n("TextLabel", {
    Size = UDim2.fromOffset(22, 22),
    Position = UDim2.new(1, -30, 0.5, -11),
    BackgroundTransparency = 1,
    Font = POLICE_BLACK,
    Text = "▼",
    TextColor3 = C.blanc,
    TextSize = 11,
    Parent = dropHeader,
})
local dropLabel = n("TextLabel", {
    Size = UDim2.new(1, -50, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "Dérouler la liste  (0 joueur)",
    TextColor3 = C.texte,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = dropHeader,
})

local listWrap = n("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.gris,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ClipsDescendants = true,
    LayoutOrder = 2,
    Parent = cListe,
})
n("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 3),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = listWrap,
})

local function refreshListeJoueurs()
    for _, child in ipairs(listWrap:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local cnt = 0
    for i, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        cnt = cnt + 1
        local isSel = (selectedPlayer == plr)

        local btn = n("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = isSel and C.blanc or C.noirElement,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = i,
            Parent = listWrap,
        })
        coin(btn, 8)
        stroke(btn, C.separateur, 1, 0.45)

        local dot = n("Frame", {
            Size = UDim2.fromOffset(8, 8),
            Position = UDim2.new(0, 12, 0.5, -4),
            BackgroundColor3 = isSel and C.noir or C.succes,
            BorderSizePixel = 0,
            Parent = btn,
        })
        coin(dot, 4)

        n("TextLabel", {
            Size = UDim2.new(1, -40, 0, 16),
            Position = UDim2.new(0, 28, 0, 3),
            BackgroundTransparency = 1,
            Font = POLICE_BOLD,
            Text = plr.DisplayName or plr.Name,
            TextColor3 = isSel and C.noir or C.texte,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = btn,
        })
        n("TextLabel", {
            Size = UDim2.new(1, -40, 0, 12),
            Position = UDim2.new(0, 28, 0, 19),
            BackgroundTransparency = 1,
            Font = POLICE,
            Text = "@" .. plr.Name,
            TextColor3 = isSel and Color3.fromRGB(60, 60, 60) or C.texteTresFaible,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = btn,
        })

        btn.MouseButton1Click:Connect(function()
            selectedPlayer = plr
            lblCible.Text = (plr.DisplayName or plr.Name) .. "  (@" .. plr.Name .. ")"
            notify("Cible: " .. (plr.DisplayName or plr.Name))
            refreshListeJoueurs()
        end)
    end

    dropLabel.Text = string.format("Dérouler la liste  (%d joueur%s)", cnt, cnt > 1 and "s" or "")
    listWrap.Size = UDim2.new(1, 0, 0, dropOpen and math.min(cnt * 37, 260) or 0)
end

dropHeader.MouseButton1Click:Connect(function()
    dropOpen = not dropOpen
    dropArrow.Text = dropOpen and "▲" or "▼"
    refreshListeJoueurs()
end)

Players.PlayerAdded:Connect(function() refreshListeJoueurs() end)
Players.PlayerRemoving:Connect(function(plr)
    if selectedPlayer == plr then
        selectedPlayer = nil
        lblCible.Text = "Aucun"
    end
    task.defer(refreshListeJoueurs)
end)
refreshListeJoueurs()

task.spawn(function()
    while ecran.Parent do
        if selectedPlayer then
            local myHRP = getHRP()
            local tChar = selectedPlayer.Character
            local tHRP  = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum  = tChar and tChar:FindFirstChildOfClass("Humanoid")
            if myHRP and tHRP then
                lblDist.Text = string.format("%d u", math.floor((myHRP.Position - tHRP.Position).Magnitude))
            else
                lblDist.Text = "— u"
            end
            if tHum then
                lblHP.Text = string.format("%d / %d", math.floor(tHum.Health), math.floor(tHum.MaxHealth))
            else
                lblHP.Text = "— / —"
            end
        else
            lblDist.Text = "— u"
            lblHP.Text   = "— / —"
        end
        task.wait(0.25)
    end
end)

creerSection(pagePlayer, "Force TP", "Orbite forcée autour de la cible")
local cFTP = creerConteneur(pagePlayer)

config.force_tp_radius = config.force_tp_radius or 6
config.force_tp_speed  = config.force_tp_speed  or 3
config.force_tp_height = config.force_tp_height or 2

local ftpBtn = n("TextButton", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Text = "Force TP: OFF",
    Font = POLICE_BOLD,
    TextColor3 = C.texte,
    TextSize = 12,
    AutoButtonColor = false,
    LayoutOrder = 1,
    Parent = cFTP,
})
coin(ftpBtn, 10)
stroke(ftpBtn, C.separateur, 1, 0.55)

local function stopForceTP()
    forceTPActive = false
    if forceTPConn then forceTPConn:Disconnect() forceTPConn = nil end
    ftpBtn.Text = "Force TP: OFF"
    tw(ftpBtn, 0.2, nil, nil, { BackgroundColor3 = C.noirElement, TextColor3 = C.texte })
end

local function startForceTP()
    if not selectedPlayer then notify("Aucune cible sélectionnée") return end
    if forceTPActive then return end
    forceTPActive = true
    ftpBtn.Text = "Force TP: ON"
    tw(ftpBtn, 0.2, nil, nil, { BackgroundColor3 = C.blanc, TextColor3 = C.noir })

    forceTPConn = RunService.RenderStepped:Connect(function()
        if not forceTPActive then return end
        if not selectedPlayer or not selectedPlayer.Character then return end
        local tHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = getHRP()
        if not tHRP or not myHRP then return end

        local radius = config.force_tp_radius or 6
        local h      = config.force_tp_height or 2
        local spd    = config.force_tp_speed  or 3
        local t      = tick() * spd
        local offset = Vector3.new(math.cos(t) * radius, h, math.sin(t) * radius)

        myHRP.CFrame = CFrame.new(tHRP.Position + offset, tHRP.Position)
        myHRP.AssemblyLinearVelocity  = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero
    end)
end

ftpBtn.MouseButton1Click:Connect(function()
    if forceTPActive then stopForceTP() else startForceTP() end
end)

creerSlider(cFTP, "Rayon", "Distance d'orbite", 2, 30, 6, 2, " u", "force_tp_radius")
creerSlider(cFTP, "Vitesse", "Vitesse d'orbite", 1, 20, 3, 3, "x", "force_tp_speed")
creerSlider(cFTP, "Hauteur", "Décalage vertical", 0, 15, 2, 4, " u", "force_tp_height")

creerSection(pagePlayer, "TP vers joueur", "Téléportation avec bypass anti-distance")
local cTP = creerConteneur(pagePlayer)

config.tp_distance = config.tp_distance or 3

local function tpToPlayer(bypass)
    if not selectedPlayer then notify("Aucune cible sélectionnée") return end
    if not selectedPlayer.Character then notify("Cible sans personnage") return end

    local myHRP = getHRP()
    local tHRP  = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP or not tHRP then notify("HRP introuvable") return end

    myHRP.AssemblyLinearVelocity  = Vector3.zero
    myHRP.AssemblyAngularVelocity = Vector3.zero

    local behind = config.tp_distance or 3
    local start  = myHRP.CFrame
    local dest   = tHRP.CFrame * CFrame.new(0, 0, behind)

    if not bypass then
        myHRP.CFrame = CFrame.new(dest.Position, tHRP.Position)
        myHRP.AssemblyLinearVelocity = Vector3.zero
        notify("TP direct → " .. (selectedPlayer.DisplayName or selectedPlayer.Name))
        return
    end

    local dist  = (start.Position - dest.Position).Magnitude
    local steps = math.clamp(math.ceil(dist / 50), 1, 12)

    task.spawn(function()
        for i = 1, steps do
            if not myHRP or not myHRP.Parent then return end
            local a     = i / steps
            local eased = a * a * (3 - 2 * a)
            local cf    = start:Lerp(dest, eased)
            myHRP.CFrame = CFrame.new(cf.Position, tHRP.Position)
            myHRP.AssemblyLinearVelocity  = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
            RunService.RenderStepped:Wait()
        end
        myHRP.CFrame = CFrame.new(dest.Position, tHRP.Position)
        notify("TP bypass → " .. (selectedPlayer.DisplayName or selectedPlayer.Name))
    end)
end

creerBouton(cTP, "TP vers joueur", "bypass activé", C.blanc, 1, function() tpToPlayer(true)  end)
creerBouton(cTP, "TP direct",      "sans bypass",   C.texte, 2, function() tpToPlayer(false) end)
creerSlider(cTP, "Distance d'arrivée", "Studs derrière la cible", 1, 20, 3, 3, " u", "tp_distance")

creerSection(pagePlayer, "Troll", "Options basées sur le Force TP")
local cTroll = creerConteneur(pagePlayer)

local followBtn = n("TextButton", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.noirElement,
    BorderSizePixel = 0,
    Text = "Follow: OFF",
    Font = POLICE_BOLD,
    TextColor3 = C.texte,
    TextSize = 12,
    AutoButtonColor = false,
    LayoutOrder = 1,
    Parent = cTroll,
})
coin(followBtn, 10)
stroke(followBtn, C.separateur, 1, 0.55)

local function stopFollow()
    followActive = false
    if followConn then followConn:Disconnect() followConn = nil end
    followBtn.Text = "Follow: OFF"
    tw(followBtn, 0.2, nil, nil, { BackgroundColor3 = C.noirElement, TextColor3 = C.texte })
end

local function startFollow()
    if not selectedPlayer then notify("Aucune cible sélectionnée") return end
    if followActive then return end
    followActive = true
    followBtn.Text = "Follow: ON"
    tw(followBtn, 0.2, nil, nil, { BackgroundColor3 = C.blanc, TextColor3 = C.noir })

    followConn = RunService.RenderStepped:Connect(function()
        if not followActive then return end
        if not selectedPlayer or not selectedPlayer.Character then return end
        local tHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = getHRP()
        if not tHRP or not myHRP then return end
        local dest = tHRP.CFrame * CFrame.new(0, 0, config.tp_distance or 3)
        myHRP.CFrame = myHRP.CFrame:Lerp(CFrame.new(dest.Position, tHRP.Position), 0.35)
    end)
end

followBtn.MouseButton1Click:Connect(function()
    if followActive then stopFollow() else startFollow() end
end)

creerBouton(cTroll, "Snap au-dessus", "te place 10u au-dessus de la cible", C.texte, 2, function()
    if not selectedPlayer or not selectedPlayer.Character then notify("Aucune cible") return end
    local myHRP = getHRP()
    local tHRP  = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP or not tHRP then return end
    myHRP.CFrame = CFrame.new(tHRP.Position + Vector3.new(0, 10, 0), tHRP.Position)
end)

creerBouton(cTroll, "Orbite serrée rapide", "radius 3u, vitesse 12x", C.texte, 3, function()
    config.force_tp_radius = 3
    config.force_tp_speed  = 12
    config.force_tp_height = 3
    if not forceTPActive then startForceTP() end
    notify("Orbite serrée enclenchée")
end)

creerBouton(cTroll, "Stop Trolls", "coupe Force TP + Follow", C.erreur, 4, function()
    stopForceTP()
    stopFollow()
    notify("Trolls coupés")
end)

creerSection(pagePlayer, "Extensions Player", "Options avancées de ciblage")
local cPlayerExt = creerConteneur(pagePlayer)
creerToggle(cPlayerExt, "Spectate", "Vue caméra sur la cible", false, 1, "spectate")
creerToggle(cPlayerExt, "Copy Appearance", "Clone l'apparence de la cible", false, 2, "copy_appearance")
creerToggle(cPlayerExt, "Track Position", "Log la position dans la console", false, 3, "track_pos")
creerSlider(cPlayerExt, "Chase Speed", "Vitesse de poursuite", 50, 1000, 200, 4, " u/s", "chase_speed")

LocalPlayer.CharacterAdded:Connect(function()
    if forceTPActive then stopForceTP() end
    if followActive then stopFollow() end
end)

--##############################################################
-- PAGE : DIVERS
--##############################################################
local pageDivers = creerPage("Divers")

creerSection(pageDivers, "Balle 717", "Sphère roulante (WASD pour bouger)")
local cBalle = creerConteneur(pageDivers)
creerToggle(cBalle, "Balle 717", "Enclenche la sphère autour de toi", false, 1, "ball717")
creerColorRow(cBalle, "Couleur balle", "Teinte de la sphère", Color3.fromRGB(255, 220, 80), 2, "ball717_color")
creerSlider(cBalle, "Taille balle", "Rayon de la sphère", 3, 15, 6, 3, " u", "ball717_size")
creerSlider(cBalle, "Vitesse balle", "Vitesse de roulade", 20, 300, 90, 4, " u/s", "ball717_speed")
creerToggle(cBalle, "Balle fantôme", "Traverse les murs", false, 5, "ball717_ghost")

creerSection(pageDivers, "Corps")
local cCorps = creerConteneur(pageDivers)
creerToggle(cCorps, "Big Head", "Tête géante", false, 1, "big_head")
creerSlider(cCorps, "Taille tête", "Multiplicateur tête", 1, 10, 3, 2, "x", "big_head_size")
creerToggle(cCorps, "Long Neck", "Cou allongé", false, 3, "long_neck")
creerSlider(cCorps, "Longueur cou", "Étirement du cou", 1, 8, 3, 4, "x", "long_neck_size")
creerToggle(cCorps, "Giant Player", "Personnage entier géant", false, 5, "giant")
creerSlider(cCorps, "Échelle joueur", "Multiplicateur global", 1, 10, 2, 6, "x", "giant_size")
creerToggle(cCorps, "Rainbow Body", "Couleur qui tourne sur le corps", false, 7, "rainbow")
creerToggle(cCorps, "Transparent", "Personnage invisible (client)", false, 8, "invisible")

creerSection(pageDivers, "FOV", "Champ de vision forcé (client-side)")
local cFov = creerConteneur(pageDivers)

config.fov_value       = config.fov_value       or 90
config.fov_bypass      = config.fov_bypass      == true
config.fov_bypass_val  = config.fov_bypass_val  or 120

creerToggle(cFov, "FOV Bypass", "Force le FOV en permanence", false, 1, "fov_bypass")
creerSlider(cFov, "Valeur Bypass", "FOV forcé quand bypass actif", 60, 160, 120, 2, "°", "fov_bypass_val")
creerSlider(cFov, "FOV Normal", "FOV quand bypass désactivé", 60, 160, 90, 3, "°", "fov_value")

creerSection(pageDivers, "Automatisation")
local cAuto = creerConteneur(pageDivers)
creerToggle(cAuto, "Anti AFK", "Empêche l'inactivité", true, 1, "anti_afk")
creerToggle(cAuto, "Auto Respawn", "Réapparition rapide", false, 2, "auto_respawn")

creerSection(pageDivers, "Protection")
local cProt = creerConteneur(pageDivers)
creerToggle(cProt, "Anti-Fling", "Prévient les projections", true, 1, "anti_fling")
creerToggle(cProt, "Anti-Void", "Empêche les chutes hors carte", true, 2, "anti_void")

creerSection(pageDivers, "Fun")
local cFun = creerConteneur(pageDivers)
creerToggle(cFun, "Effets de particules", "Trail coloré", false, 1, "particles")
creerColorRow(cFun, "Couleur particules", "Teinte du trail", C.blanc, 2, "particles_color")
creerToggle(cFun, "Zombie Walk", "Démarche zombie", false, 3, "zombie")
creerToggle(cFun, "Ragdoll", "Tomber mou", false, 4, "ragdoll")

creerSection(pageDivers, "Extensions Divers", "Options fantaisie avancées")
local cDivExt = creerConteneur(pageDivers)
creerToggle(cDivExt, "Spam Emote", "Joue une emote en boucle", false, 1, "spam_emote")
creerToggle(cDivExt, "Fake Lag", "Simule du lag", false, 2, "fake_lag")
creerSlider(cDivExt, "Fake Lag Intensity", "Intensité du lag simulé", 50, 500, 150, 3, " ms", "fake_lag_val")
creerToggle(cDivExt, "Trail Coloré", "Trail de mouvement coloré", false, 4, "trail_color")
creerSlider(cDivExt, "Trail Lifetime", "Durée du trail", 0.2, 3, 1, 5, " s", "trail_life")

--##############################################################
-- PAGE : À PROPOS
--##############################################################
local pageAPropos = creerPage("APropos")

local carteLogo = n("Frame", {
    Size = UDim2.new(1, 0, 0, 160),
    BackgroundColor3 = C.noirCarte,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    Parent = pageAPropos,
})
coin(carteLogo, 16)
stroke(carteLogo, C.separateur, 1, 0.5)
local logoAPropos = n("Frame", {
    Size = UDim2.fromOffset(60, 60),
    Position = UDim2.new(0.5, -30, 0, 24),
    BackgroundColor3 = C.blanc,
    BorderSizePixel = 0,
    Parent = carteLogo,
})
coin(logoAPropos, 30)
n("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Font = POLICE_BLACK,
    Text = "M",
    TextColor3 = C.noir,
    TextSize = 34,
    Parent = logoAPropos,
})
n("TextLabel", {
    Size = UDim2.new(1, 0, 0, 26),
    Position = UDim2.new(0, 0, 0, 96),
    BackgroundTransparency = 1,
    Font = POLICE_BLACK,
    Text = "MANOIR",
    TextColor3 = C.grisPale,
    TextSize = 22,
    Parent = carteLogo,
})
n("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    Position = UDim2.new(0, 0, 0, 124),
    BackgroundTransparency = 1,
    Font = POLICE,
    Text = "Version 6.0.0 — Refonte + Team Check",
    TextColor3 = C.texteTresFaible,
    TextSize = 12,
    Parent = carteLogo,
})

creerSection(pageAPropos, "Informations")
local cInfos = creerConteneur(pageAPropos)
creerLigneInfo(cInfos, "Version", "6.0.0", 1)
creerLigneInfo(cInfos, "Build", "2026.10.04", 2)
creerLigneInfo(cInfos, "Canal", "Stable", 3)
creerLigneInfo(cInfos, "Licence", "Privée", 4)
creerLigneInfo(cInfos, "Modules actifs", "65 / 65", 5)

--##############################################################
-- ENREGISTREMENT ONGLETS
--##############################################################
local ongletsNoms = {"Combat", "Deplacement", "Visuel", "Monde", "Interface", "Divers", "Player", "APropos"}
for i, nom in ipairs(ongletsNoms) do
    creerBoutonOnglet(nom, i)
end
for nom, d in pairs(onglets) do
    d.bouton.MouseButton1Click:Connect(function() afficherOnglet(nom) end)
end
print("[Manoir] Onglets enregistrés :", #ongletsNoms)

--##############################################################
-- INPUT TRACKING
--##############################################################
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        keysDown[input.KeyCode.Name] = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        keysDown[input.KeyCode.Name] = false
    end
end)
local function kd(name) return name and keysDown[name] == true end

--==============================================================
-- WATERMARK / HUD
--==============================================================
local watermark = n("Frame", {
    Size = UDim2.fromOffset(200, 26),
    Position = UDim2.new(0, 20, 0, 20),
    BackgroundColor3 = C.noirCarte,
    BorderSizePixel = 0,
    BackgroundTransparency = 0.1,
    Visible = true,
    Parent = ecran,
})
coin(watermark, 8)
stroke(watermark, C.separateur, 1, 0.4)
n("TextLabel", {
    Size = UDim2.new(1, -12, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "MANOIR  ·  v6.0",
    TextColor3 = C.blanc,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = watermark,
})

local infoHud = n("Frame", {
    Size = UDim2.fromOffset(160, 26),
    Position = UDim2.new(0, 20, 0, 52),
    BackgroundTransparency = 1,
    Parent = ecran,
})
local fpsLbl = n("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "60 FPS",
    TextColor3 = C.blanc,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false,
    Parent = infoHud,
})
local pingLbl = n("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0.5, 0, 0, 0),
    BackgroundTransparency = 1,
    Font = POLICE_BOLD,
    Text = "0 ms",
    TextColor3 = C.blanc,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Visible = false,
    Parent = infoHud,
})
task.spawn(function()
    while ecran.Parent do
        local f = 0
        local t0 = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function() f = f + 1 end)
        task.wait(1)
        conn:Disconnect()
        local fps = math.floor(f / (tick() - t0))
        fpsLbl.Text = fps .. " FPS"
        local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
        if ok then pingLbl.Text = string.format("%d ms", ping) end
    end
end)
RunService.RenderStepped:Connect(function()
    fpsLbl.Visible = config.fps_counter == true
    pingLbl.Visible = config.ping_display == true
    watermark.Visible = config.watermark == true
end)

--==============================================================
-- GET TARGETS (filtre Team Check global)
--==============================================================
local function getTargets()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        table.insert(list, { player = plr, char = char, hrp = hrp, hum = hum })
    end
    return list
end

--==============================================================
-- AIMBOT
--==============================================================
local function hasLineOfSight(hrp)
    local cam = workspace.CurrentCamera
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local dir = (hrp.Position - cam.CFrame.Position)
    local result = workspace:Raycast(cam.CFrame.Position, dir, params)
    return result == nil or result.Instance:IsDescendantOf(hrp.Parent)
end

local lastStickyTarget = nil

local function bestTarget()
    local cam = workspace.CurrentCamera
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local fov = config.aimbot_fov or 150
    local best, bestD = nil, math.huge

    if config.sticky_aim and lastStickyTarget and lastStickyTarget.char and lastStickyTarget.char.Parent then
        local hum = lastStickyTarget.char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local isTeam = sameTeam(lastStickyTarget.player)
            local kill = (config.aim_team_check and isTeam)
            if not kill then
                if not (config.aimbot_visible and not config.aim_walls and not hasLineOfSight(lastStickyTarget.hrp)) then
                    return lastStickyTarget
                end
            end
        end
        lastStickyTarget = nil
    end

    for _, t in ipairs(getTargets()) do
        if config.aim_team_check and sameTeam(t.player) then continue end
        if config.aimbot_visible and not config.aim_walls and not hasLineOfSight(t.hrp) then continue end
        local sp, onScr = cam:WorldToViewportPoint(t.hrp.Position)
        if not onScr then continue end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d < fov and d < bestD then
            best, bestD = t, d
        end
    end
    if config.sticky_aim then lastStickyTarget = best end
    return best
end

RunService:BindToRenderStep("ManoirAimbot", 210, function(dt)
    if not config.aimbot then return end
    local active = true
    if config.aimbot_key and config.aimbot_key ~= "" then
        active = kd(config.aimbot_key)
    end
    if not active then return end

    local target = bestTarget()
    if not target then return end

    local cam = workspace.CurrentCamera
    local aimPos = target.hrp.Position
    if config.aimbot_head then
        local head = target.char:FindFirstChild("Head")
        if head then aimPos = head.Position end
    end

    local targetCF = CFrame.lookAt(cam.CFrame.Position, aimPos)
    if config.silent_aim then
        cam.CFrame = targetCF
    else
        local smooth = (config.aimbot_smooth or 35) / 100
        local alpha = math.clamp(1 - smooth, 0.05, 1)
        alpha = math.max(alpha, 0.08)
        cam.CFrame = cam.CFrame:Lerp(targetCF, alpha)
    end
end)

--==============================================================
-- TRIGGERBOT
--==============================================================
task.spawn(function()
    local mouse = LocalPlayer:GetMouse()
    while ecran.Parent do
        if config.triggerbot then
            local target = mouse.Target
            if target then
                local model = target:FindFirstAncestorOfClass("Model")
                local plr = model and Players:GetPlayerFromCharacter(model)
                if plr and plr ~= LocalPlayer then
                    local skip = config.trig_team_check and sameTeam(plr)
                    if not skip then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            if not config.triggerbot_instant then
                                task.wait((config.triggerbot_delay or 50) / 1000)
                            end
                            local char = getChar()
                            local tool = char and char:FindFirstChildOfClass("Tool")
                            if tool then pcall(function() tool:Activate() end) end
                        end
                    end
                end
            end
        end
        task.wait(0.02)
    end
end)

--==============================================================
-- AUTO SHOOT
--==============================================================
task.spawn(function()
    while ecran.Parent do
        if config.auto_shoot and config.aimbot then
            local target = bestTarget()
            if target then
                local char = getChar()
                local tool = char and char:FindFirstChildOfClass("Tool")
                if tool then pcall(function() tool:Activate() end) end
            end
            task.wait(0.05)
        else
            task.wait(0.15)
        end
    end
end)

--==============================================================
-- RAPID FIRE
--==============================================================
task.spawn(function()
    while ecran.Parent do
        if config.rapid_fire then
            local char = getChar()
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
            task.wait((config.rapidfire_speed or 80) / 1000)
        else
            task.wait(0.1)
        end
    end
end)

--==============================================================
-- NO RECOIL
--==============================================================
local lastCamCF = nil
RunService.RenderStepped:Connect(function()
    if not config.no_recoil then lastCamCF = nil return end
    local cam = workspace.CurrentCamera
    if not lastCamCF then lastCamCF = cam.CFrame return end
    local delta = (cam.CFrame.LookVector - lastCamCF.LookVector).Magnitude
    if delta > 0.02 then
        cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + lastCamCF.LookVector)
    end
    lastCamCF = cam.CFrame
end)

--==============================================================
-- HITBOX EXPANDER
--==============================================================
local originalSizes = {}
RunService.Heartbeat:Connect(function()
    if not config.hitbox_expand then
        for hrp, size in pairs(originalSizes) do
            if hrp and hrp.Parent then hrp.Size = size end
        end
        originalSizes = {}
        return
    end
    local mult = config.hitbox_size or 3
    for _, t in ipairs(getTargets()) do
        if config.hit_team_check and sameTeam(t.player) then continue end
        if not originalSizes[t.hrp] then originalSizes[t.hrp] = t.hrp.Size end
        t.hrp.Size = Vector3.new(2 * mult, 2 * mult, 1 * mult)
        t.hrp.Transparency = 0.7
        t.hrp.CanCollide = false
    end
end)

--==============================================================
-- ESP / CHAMS / TRACERS
--==============================================================
local espData = {}
local espTracers = {}

local function createTracer(plr)
    local line = Drawing and Drawing.new("Line") or nil
    if line then
        line.Thickness = 1
        line.Transparency = 0.5
        line.Visible = false
        espTracers[plr] = line
    end
    return line
end

local function ensureHighlight(plr)
    local d = espData[plr]
    if d and d.highlight and d.highlight.Parent then return d.highlight end
    local char = plr.Character
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Name = "ManoirESP"
    hl.Adornee = char
    hl.FillColor = config.esp_color or C.blanc
    hl.OutlineColor = config.esp_color or C.blanc
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    espData[plr] = espData[plr] or {}
    espData[plr].highlight = hl
    return hl
end

local function ensureBillboard(plr)
    local d = espData[plr]
    if d and d.billboard and d.billboard.Parent then return d.billboard end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ManoirInfo"
    bb.Size = UDim2.fromOffset(200, 60)
    bb.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head
    local nameLbl = n("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = POLICE_BOLD,
        Text = plr.Name,
        TextColor3 = C.blanc,
        TextSize = 13,
        TextStrokeTransparency = 0.2,
        TextStrokeColor3 = Color3.new(0,0,0),
        Parent = bb,
    })
    local distLbl = n("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = POLICE,
        Text = "0m",
        TextColor3 = C.blancCasse,
        TextSize = 11,
        TextStrokeTransparency = 0.2,
        TextStrokeColor3 = Color3.new(0,0,0),
        Parent = bb,
    })
    local hpBg = n("Frame", {
        Size = UDim2.new(0, 100, 0, 5),
        Position = UDim2.new(0.5, -50, 0, 32),
        BackgroundColor3 = Color3.fromRGB(30,30,30),
        BorderSizePixel = 0,
        Parent = bb,
    })
    coin(hpBg, 2)
    local hpFill = n("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = C.succes,
        BorderSizePixel = 0,
        Parent = hpBg,
    })
    coin(hpFill, 2)

    local headDot = n("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0.5, -3, 0, 50),
        BackgroundColor3 = config.headdot_color or Color3.fromRGB(255, 80, 80),
        BorderSizePixel = 0,
        Visible = false,
        Parent = bb,
    })
    coin(headDot, 3)

    espData[plr] = espData[plr] or {}
    espData[plr].billboard = bb
    espData[plr].nameLbl = nameLbl
    espData[plr].distLbl = distLbl
    espData[plr].hpFill = hpFill
    espData[plr].hpBg = hpBg
    espData[plr].headDot = headDot
    return bb
end

local function clearESP(plr)
    local d = espData[plr]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        espData[plr] = nil
    end
    local t = espTracers[plr]
    if t then t:Remove() espTracers[plr] = nil end
end

local skeletonLines = {}
local function clearSkeleton(plr)
    local set = skeletonLines[plr]
    if set then
        for _, l in ipairs(set) do
            pcall(function() l:Remove() end)
        end
        skeletonLines[plr] = nil
    end
end

local SKELETON_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    local myHRP = getHRP()
    local espCol = config.esp_color or C.blanc

    if config.esp_rainbow then
        local t = tick() * 0.3
        espCol = Color3.fromHSV(t % 1, 1, 1)
    end

    local vp = cam.ViewportSize
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if config.esp_team_check and sameTeam(plr) then
            clearESP(plr)
            clearSkeleton(plr)
            continue
        end

        local d = espData[plr]

        if not (config.esp or config.chams or config.esp_skeleton) then
            if d then
                if d.highlight then d.highlight.Enabled = false end
                if d.billboard then d.billboard.Enabled = false end
            end
            local t = espTracers[plr]
            if t then t.Visible = false end
            clearSkeleton(plr)
            continue
        end

        local char = plr.Character
        if not char then clearESP(plr) clearSkeleton(plr) continue end
        local head = char:FindFirstChild("Head")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not head or not hrp or not hum then continue end

        if config.esp then
            local hl = ensureHighlight(plr)
            if hl then
                hl.Enabled = true
                hl.FillColor = espCol
                hl.OutlineColor = espCol
                hl.FillTransparency = config.esp_box and 0.55 or 1
                hl.OutlineTransparency = config.esp_box and 0 or 1
            end
            local bb = ensureBillboard(plr)
            if bb and espData[plr] then
                local e = espData[plr]
                if myHRP then
                    local dist = (myHRP.Position - hrp.Position).Magnitude
                    local maxR = config.esp_range or 1500
                    if dist > maxR then
                        bb.Enabled = false
                    else
                        bb.Enabled = true
                        e.nameLbl.Visible = config.esp_name == true
                        e.distLbl.Visible = config.esp_dist == true
                        e.hpBg.Visible = config.esp_health == true
                        e.nameLbl.TextColor3 = espCol
                        e.distLbl.TextColor3 = espCol
                        e.nameLbl.Text = plr.Name
                        e.distLbl.Text = string.format("%dm", math.floor(dist))
                        e.hpFill.Size = UDim2.new(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 0, 1, 0)
                        e.hpFill.BackgroundColor3 = hum.Health > hum.MaxHealth * 0.5
                            and C.succes
                            or (hum.Health > hum.MaxHealth * 0.25 and Color3.fromRGB(240, 200, 90) or C.erreur)
                        if e.headDot then
                            e.headDot.Visible = config.esp_headdot == true
                            e.headDot.BackgroundColor3 = config.headdot_color or Color3.fromRGB(255, 80, 80)
                        end
                    end
                end
            end

            if config.esp_tracer and Drawing then
                local line = espTracers[plr] or createTracer(plr)
                if line then
                    local sp, onScr = cam:WorldToViewportPoint(hrp.Position)
                    if onScr then
                        line.From = Vector2.new(vp.X / 2, vp.Y)
                        line.To = Vector2.new(sp.X, sp.Y)
                        line.Color = config.tracer_color or C.blanc
                        line.Thickness = 1
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                end
            else
                local t = espTracers[plr]
                if t then t.Visible = false end
            end
        else
            if d then
                if d.highlight and not config.chams then d.highlight.Enabled = false end
                if d.billboard then d.billboard.Enabled = false end
            end
            local t = espTracers[plr]
            if t then t.Visible = false end
        end

        if config.chams then
            if not (config.chams_team_check and sameTeam(plr)) then
                local hl = ensureHighlight(plr)
                if hl then
                    hl.Enabled = true
                    hl.FillColor = config.chams_color or C.grisPale
                    hl.FillTransparency = math.clamp((config.chams_alpha or 30) / 100, 0, 1)
                    hl.OutlineColor = config.chams_color or C.grisPale
                    hl.OutlineTransparency = 0.3
                end
            end
        end

        if config.esp_skeleton and Drawing then
            local lines = skeletonLines[plr]
            if not lines then
                lines = {}
                for i = 1, #SKELETON_BONES do
                    local l = Drawing.new("Line")
                    l.Thickness = 1
                    l.Transparency = 0.7
                    l.Color = espCol
                    l.Visible = false
                    table.insert(lines, l)
                end
                skeletonLines[plr] = lines
            end
            for i, pair in ipairs(SKELETON_BONES) do
                local a = char:FindFirstChild(pair[1])
                local b = char:FindFirstChild(pair[2])
                local l = lines[i]
                if a and b and l then
                    local sa, on1 = cam:WorldToViewportPoint(a.Position)
                    local sb, on2 = cam:WorldToViewportPoint(b.Position)
                    if on1 and on2 then
                        l.From = Vector2.new(sa.X, sa.Y)
                        l.To   = Vector2.new(sb.X, sb.Y)
                        l.Color = espCol
                        l.Visible = true
                    else
                        l.Visible = false
                    end
                elseif l then
                    l.Visible = false
                end
            end
        else
            clearSkeleton(plr)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) clearESP(p) clearSkeleton(p) end)

--==============================================================
-- SPEED / JUMP / FLY / NOCLIP
--==============================================================
RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if config.speed_hack then
        hum.WalkSpeed = config.walkspeed or 32
    else
        if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
    end
    hum.UseJumpPower = true
    if config.jump_power then hum.JumpPower = config.jump_power end
end)

RunService.Heartbeat:Connect(function()
    if not config.auto_sprint then return end
    local hum = getHum()
    if hum then hum.WalkSpeed = math.max(hum.WalkSpeed, 22) end
end)

UserInputService.JumpRequest:Connect(function()
    if config.infinite_jump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

task.spawn(function()
    while ecran.Parent do
        if config.bhop then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            task.wait(0.15)
        else
            task.wait(0.2)
        end
    end
end)

task.spawn(function()
    while ecran.Parent do
        if config.wall_climb then
            local char = getChar()
            local hrp = getHRP()
            if char and hrp then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { char }
                local dirs = {
                    hrp.CFrame.LookVector,
                    hrp.CFrame.RightVector * -1,
                    hrp.CFrame.RightVector,
                }
                for _, d in ipairs(dirs) do
                    local hit = workspace:Raycast(hrp.Position, d * 3, rp)
                    if hit and math.abs(hit.Normal.Y) < 0.3 then
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            hrp.AssemblyLinearVelocity.X,
                            40,
                            hrp.AssemblyLinearVelocity.Z
                        )
                        break
                    end
                end
            end
        end
        task.wait(0.08)
    end
end)

local function ensureFlyVelocity()
    local hrp = getHRP()
    if not hrp then return end
    if not flyVelocity or flyVelocity.Parent ~= hrp then
        if flyVelocity then flyVelocity:Destroy() end
        flyVelocity = Instance.new("BodyVelocity")
        flyVelocity.Name = "ManoirFly"
        flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyVelocity.Velocity = Vector3.zero
        flyVelocity.Parent = hrp
    end
end

local function removeFly()
    if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
end

RunService.RenderStepped:Connect(function()
    if not config.fly then removeFly() return end
    local hrp = getHRP()
    if not hrp then removeFly() return end
    ensureFlyVelocity()
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if kd("W") then dir = dir + cam.CFrame.LookVector end
    if kd("S") then dir = dir - cam.CFrame.LookVector end
    if kd("A") then dir = dir - cam.CFrame.RightVector end
    if kd("D") then dir = dir + cam.CFrame.RightVector end
    if kd("Space") then dir = dir + Vector3.new(0, 1, 0) end
    if kd("LeftControl") then dir = dir - Vector3.new(0, 1, 0) end
    local speed = config.fly_speed or 120
    if dir.Magnitude > 0 then dir = dir.Unit end
    flyVelocity.Velocity = dir * speed
end)

RunService.Stepped:Connect(function()
    if not config.noclip then return end
    local char = getChar()
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
    end
end)

--==============================================================
-- AMBIANCE
--==============================================================
local ambOrig = {
    brightness = Lighting.Brightness,
    ambient = Lighting.Ambient,
    outdoorAmbient = Lighting.OutdoorAmbient,
    fogEnd = Lighting.FogEnd,
    fogStart = Lighting.FogStart,
    globalShadows = Lighting.GlobalShadows,
}
RunService.Heartbeat:Connect(function()
    if config.fullbright then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = ambOrig.brightness
        Lighting.Ambient = ambOrig.ambient
        Lighting.OutdoorAmbient = ambOrig.outdoorAmbient
        Lighting.GlobalShadows = ambOrig.globalShadows
    end
    if config.no_fog or config.remove_fog then
        Lighting.FogEnd = 1e6
        Lighting.FogStart = 1e6
    else
        Lighting.FogEnd = ambOrig.fogEnd
        Lighting.FogStart = ambOrig.fogStart
    end
    local bright = (config.brightness or 50) / 50
    if not config.fullbright then
        Lighting.Brightness = ambOrig.brightness * bright
    end
    if config.clock_lock or config.freeze_time then
        Lighting.ClockTime = config.clock_time or 12
    end
    if config.disable_shadows then
        Lighting.GlobalShadows = false
    end
end)

--==============================================================
-- MONDE : Gravity, Walk on water
--==============================================================
RunService.Heartbeat:Connect(function()
    if config.gravity_hack then
        workspace.Gravity = 196.2 * ((config.gravity_val or 100) / 100)
    else
        if workspace.Gravity ~= 196.2 then workspace.Gravity = 196.2 end
    end
end)

task.spawn(function()
    local platform
    while ecran.Parent do
        if config.walk_water then
            local hrp = getHRP()
            if hrp then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = { getChar() }
                local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rp)
                if not hit then
                    if not platform or not platform.Parent then
                        platform = Instance.new("Part")
                        platform.Name = "ManoirWaterPlat"
                        platform.Size = Vector3.new(8, 1, 8)
                        platform.Anchored = true
                        platform.CanCollide = true
                        platform.Transparency = 1
                        platform.Parent = workspace
                    end
                    platform.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3.5, 0))
                else
                    if platform and platform.Parent then
                        platform.CFrame = CFrame.new(hit.Position - Vector3.new(0, 2.5, 0))
                    end
                end
            end
        else
            if platform then platform:Destroy() platform = nil end
        end
        task.wait(0.1)
    end
end)

RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if config.anti_collision then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end)
    end
end)

--==============================================================
-- BALLE 717
--==============================================================
local ball717 = nil
local ballVel = nil
local ballWeld = nil

local function destroyBall()
    if ballVel then ballVel:Destroy() ballVel = nil end
    if ballWeld then ballWeld:Destroy() ballWeld = nil end
    if ball717 then ball717:Destroy() ball717 = nil end
end

local function createBall()
    destroyBall()
    local hrp = getHRP()
    if not hrp then return end

    local size = config.ball717_size or 6
    local ball = Instance.new("Part")
    ball.Name = "ManoirBall717"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(size, size, size)
    ball.Material = Enum.Material.Neon
    ball.Color = config.ball717_color or Color3.fromRGB(255, 220, 80)
    ball.Transparency = 0.2
    ball.Anchored = false
    ball.CanCollide = not config.ball717_ghost
    ball.TopSurface = Enum.SurfaceType.Smooth
    ball.BottomSurface = Enum.SurfaceType.Smooth
    ball.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.2, 1, 1)
    ball.CFrame = hrp.CFrame
    ball.Parent = workspace

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = ball
    weld.Parent = ball

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, 0, math.huge)
    bv.P = 1e5
    bv.Velocity = Vector3.zero
    bv.Parent = ball

    ball717 = ball
    ballVel = bv
    ballWeld = weld
end

RunService.Heartbeat:Connect(function()
    if config.ball717 then
        if not ball717 or not ball717.Parent then createBall() end
    else
        if ball717 then destroyBall() end
        return
    end
    if not ball717 or not ballVel then return end

    local hrp = getHRP()
    if not hrp then return end
    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if kd("W") then dir = dir + cam.CFrame.LookVector end
    if kd("S") then dir = dir - cam.CFrame.LookVector end
    if kd("A") then dir = dir - cam.CFrame.RightVector end
    if kd("D") then dir = dir + cam.CFrame.RightVector end
    if dir.Magnitude > 0 then dir = dir.Unit end
    local speed = config.ball717_speed or 90
    ballVel.Velocity = dir * speed

    ball717.CanCollide = not config.ball717_ghost
    ball717.Color = config.ball717_color or ball717.Color
    local wantSize = config.ball717_size or 6
    if ball717.Size.X ~= wantSize then
        ball717.Size = Vector3.new(wantSize, wantSize, wantSize)
    end

    if dir.Magnitude > 0.05 then
        local axis = Vector3.new(-dir.Z, 0, dir.X).Unit
        local rotSpeed = speed / (wantSize / 2)
        ball717.CFrame = ball717.CFrame * CFrame.fromAxisAngle(axis, rotSpeed * 0.016)
    end
end)

--==============================================================
-- BIG HEAD / LONG NECK / GIANT / RAINBOW / INVISIBLE
--==============================================================
local bodyOriginals = {}

local function captureOriginals(char)
    if bodyOriginals[char] then return end
    local t = {}
    for _, name in ipairs({"Head", "Torso", "UpperTorso", "LowerTorso", "Left Arm", "Right Arm",
        "Left Leg", "Right Leg", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
        "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"}) do
        local p = char:FindFirstChild(name)
        if p then
            t[name] = { size = p.Size, transparency = p.Transparency, color = p.Color }
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        local neck = head:FindFirstChild("Neck") or char:FindFirstChild("Neck", true)
        if neck and neck:IsA("Motor6D") then
            t._neckC0 = neck.C0
        end
    end
    bodyOriginals[char] = t
end

local function applyBigHead(head, originalSize)
    local s = config.big_head_size or 3
    local applied = false
    for _, m in ipairs(head:GetChildren()) do
        if m:IsA("SpecialMesh") then
            m.Scale = Vector3.new(s, s, s)
            applied = true
        end
    end
    if not applied then
        head.Size = Vector3.new(originalSize.X * s, originalSize.Y * s, originalSize.Z * s)
    end
end

local function resetBigHead(head, originalSize)
    for _, m in ipairs(head:GetChildren()) do
        if m:IsA("SpecialMesh") then
            m.Scale = Vector3.new(1, 1, 1)
        end
    end
    head.Size = originalSize
end

RunService.Heartbeat:Connect(function()
    local char = getChar()
    if not char then return end
    captureOriginals(char)

    local head = char:FindFirstChild("Head")
    if head then
        local orig = bodyOriginals[char] and bodyOriginals[char].Head
        local baseSize = orig and orig.size or Vector3.new(2, 1, 1)
        if config.big_head then
            applyBigHead(head, baseSize)
        else
            resetBigHead(head, baseSize)
        end
    end

    local neck = char:FindFirstChild("Neck", true)
    if neck and neck:IsA("Motor6D") and bodyOriginals[char] and bodyOriginals[char]._neckC0 then
        if config.long_neck then
            local s = config.long_neck_size or 3
            local baseC0 = bodyOriginals[char]._neckC0
            neck.C0 = baseC0 + Vector3.new(0, (s - 1) * 0.8, 0)
        else
            neck.C0 = bodyOriginals[char]._neckC0
        end
    end

    if config.giant then
        local s = config.giant_size or 2
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                local orig = bodyOriginals[char] and bodyOriginals[char][p.Name]
                if orig then
                    p.Size = orig.size * s
                end
            end
        end
    else
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                local orig = bodyOriginals[char] and bodyOriginals[char][p.Name]
                if orig and p.Size ~= orig.size then
                    p.Size = orig.size
                end
            end
        end
    end

    if config.rainbow then
        local h = tick() * 0.4 % 1
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Color = Color3.fromHSV((h + (p.Position.Y % 5) / 5) % 1, 0.85, 1)
            end
        end
    end

    if config.invisible then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 1
                p.Transparency = 1
            elseif p:IsA("Decal") then
                p.Transparency = 1
            end
        end
    end
end)

--==============================================================
-- SPECTATE / TRACK / CHASE / COPY APPEARANCE
--==============================================================
RunService.RenderStepped:Connect(function()
    if config.spectate and selectedPlayer and selectedPlayer.Character then
        local head = selectedPlayer.Character:FindFirstChild("Head")
        local cam = workspace.CurrentCamera
        if head then
            cam.CFrame = CFrame.new(head.Position - head.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), head.Position)
        end
    end
end)

task.spawn(function()
    while ecran.Parent do
        if config.track_pos and selectedPlayer and selectedPlayer.Character then
            local hrp = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                print(string.format("[Manoir Track] %s → %.1f, %.1f, %.1f",
                    selectedPlayer.Name, hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
            end
        end
        task.wait(2)
    end
end)

task.spawn(function()
    while ecran.Parent do
        if config.chase_speed and selectedPlayer and selectedPlayer.Character then
            local myHRP = getHRP()
            local tHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if myHRP and tHRP then
                myHRP.CFrame = myHRP.CFrame:Lerp(
                    CFrame.new(tHRP.Position, myHRP.Position),
                    0.1
                )
            end
        end
        task.wait(0.05)
    end
end)

-- COPY APPEARANCE — copie les vêtements et accessoires
task.spawn(function()
    while ecran.Parent do
        if config.copy_appearance and selectedPlayer and selectedPlayer.Character then
            local myChar = getChar()
            local tChar = selectedPlayer.Character
            if myChar and tChar then
                -- supprime les anciens vêtements copies
                for _, item in ipairs(myChar:GetChildren()) do
                    if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                        if item:GetAttribute("ManoirCopy") then item:Destroy() end
                    end
                end
                -- copie
                for _, item in ipairs(tChar:GetChildren()) do
                    if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                        local c = item:Clone()
                        c:SetAttribute("ManoirCopy", true)
                        c.Parent = myChar
                    end
                end
            end
        end
        task.wait(1.5)
    end
end)

--==============================================================
-- AUTOMATISATION / PROTECTION / FUN
--==============================================================
LocalPlayer.Idled:Connect(function()
    if config.anti_afk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

task.spawn(function()
    while ecran.Parent do
        if config.auto_respawn then
            local hum = getHum()
            if hum and hum.Health <= 0 then
                task.wait(0.5)
                pcall(function() LocalPlayer:LoadCharacter() end)
            end
        end
        task.wait(1)
    end
end)

RunService.Heartbeat:Connect(function()
    local hrp = getHRP()
    if not hrp then return end
    if config.anti_void then
        if hrp.Position.Y > -50 and hrp.Position.Y < 10000 then
            lastSafePos = hrp.Position
        end
        if hrp.Position.Y < -100 or hrp.Position.Y > 100000 then
            pcall(function()
                hrp.CFrame = CFrame.new(lastSafePos + Vector3.new(0, 5, 0))
            end)
        end
    end
    if config.anti_fling then
        local vel = hrp.AssemblyLinearVelocity
        if vel.Magnitude > 500 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end)

-- PARTICULES
local particleEmitter
RunService.Heartbeat:Connect(function()
    local hrp = getHRP()
    if not hrp then return end
    if config.particles then
        if not particleEmitter or particleEmitter.Parent ~= hrp then
            if particleEmitter then particleEmitter:Destroy() end
            particleEmitter = Instance.new("ParticleEmitter")
            particleEmitter.Name = "ManoirTrail"
            particleEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            particleEmitter.Rate = 30
            particleEmitter.Lifetime = NumberRange.new(0.8, 1.4)
            particleEmitter.Speed = NumberRange.new(0.5, 1.5)
            particleEmitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.4),
                NumberSequenceKeypoint.new(1, 0),
            })
            particleEmitter.LightEmission = 0.5
            particleEmitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            })
            particleEmitter.Parent = hrp
        end
        local col = config.particles_color or C.blanc
        particleEmitter.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, col),
            ColorSequenceKeypoint.new(1, col),
        })
    else
        if particleEmitter then particleEmitter:Destroy() particleEmitter = nil end
    end
end)

-- TRAIL COLORÉ
local trailAttachment0, trailAttachment1, trailObj
task.spawn(function()
    while ecran.Parent do
        local char = getChar()
        local hrp = getHRP()
        if char and hrp then
            if config.trail_color then
                if not trailObj or not trailObj.Parent then
                    local a0 = Instance.new("Attachment")
                    a0.Name = "ManoirTrailA0"
                    a0.Position = Vector3.new(0, 1, 0)
                    a0.Parent = hrp
                    local a1 = Instance.new("Attachment")
                    a1.Name = "ManoirTrailA1"
                    a1.Position = Vector3.new(0, -1, 0)
                    a1.Parent = hrp
                    local trail = Instance.new("Trail")
                    trail.Attachment0 = a0
                    trail.Attachment1 = a1
                    trail.Lifetime = config.trail_life or 1
                    trail.MinLength = 0
                    trail.LightEmission = 0.5
                    trail.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, config.accent_color or C.blanc),
                        ColorSequenceKeypoint.new(1, config.accent_color or C.blanc),
                    })
                    trail.Parent = hrp
                    trailAttachment0 = a0
                    trailAttachment1 = a1
                    trailObj = trail
                else
                    trailObj.Lifetime = config.trail_life or 1
                    trailObj.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, config.accent_color or C.blanc),
                        ColorSequenceKeypoint.new(1, config.accent_color or C.blanc),
                    })
                end
            else
                if trailObj then trailObj:Destroy() trailObj = nil end
                if trailAttachment0 then trailAttachment0:Destroy() trailAttachment0 = nil end
                if trailAttachment1 then trailAttachment1:Destroy() trailAttachment1 = nil end
            end
        end
        task.wait(0.3)
    end
end)

RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if config.zombie then
        hum.WalkSpeed = math.min(hum.WalkSpeed, 6)
    end
end)

RunService.Heartbeat:Connect(function()
    local hum = getHum()
    if not hum then return end
    if config.ragdoll then
        if not hum.PlatformStand then hum.PlatformStand = true end
    else
        if hum.PlatformStand then hum.PlatformStand = false end
    end
end)

-- SPAM EMOTE
task.spawn(function()
    while ecran.Parent do
        if config.spam_emote then
            local hum = getHum()
            if hum then
                pcall(function()
                    local anim = Instance.new("Animation")
                    anim.AnimationId = "rbxassetid://5077768795"
                    local track = hum:LoadAnimation(anim)
                    track:Play(0.1, 1, 1)
                    task.wait(2)
                    track:Stop()
                end)
            end
        end
        task.wait(0.2)
    end
end)

-- FAKE LAG
task.spawn(function()
    while ecran.Parent do
        if config.fake_lag then
            local hrp = getHRP()
            if hrp then
                local saved = hrp.CFrame
                task.wait((config.fake_lag_val or 150) / 1000)
                if hrp and hrp.Parent then
                    hrp.CFrame = saved
                end
            end
        end
        task.wait(0.05)
    end
end)

--==============================================================
-- FOV BYPASS
--==============================================================
RunService:BindToRenderStep("ManoirFOVBypass", Enum.RenderPriority.Camera.Value + 1, function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    if config.fov_bypass then
        cam.FieldOfView = config.fov_bypass_val or 120
    else
        if cam.FieldOfView ~= (config.fov_value or 90) then
            cam.FieldOfView = config.fov_value or 90
        end
    end
end)

-- FOV Circle Drawing
task.spawn(function()
    local circle = Drawing and Drawing.new("Circle") or nil
    if not circle then return end
    circle.Thickness = 1
    circle.Transparency = 0.6
    circle.NumSides = 64
    circle.Filled = false
    circle.Color = Color3.fromRGB(255, 255, 255)
    RunService.RenderStepped:Connect(function()
        circle.Visible = config.aimbot == true
        circle.Radius = config.fov_circle or 150
        circle.Position = workspace.CurrentCamera.ViewportSize / 2
    end)
end)

--==============================================================
-- OUVERTURE / FERMETURE
--==============================================================
local estOuvert = false

local function ouvrir()
    if estOuvert then return end
    estOuvert = true
    fenetre.Visible = true
    fenetre.Size = UDim2.fromOffset(660, 460)
    fenetre.Position = UDim2.new(0.5, -330, 0.5, -230)
    fenetre.BackgroundTransparency = 1
    tw(fenetre, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
        Size = UDim2.fromOffset(700, 500),
        Position = UDim2.new(0.5, -350, 0.5, -250),
        BackgroundTransparency = 0,
    })
    logo.Rotation = -25
    tw(logo, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Rotation = 0 })
    barreTitre.Position = UDim2.new(0, 0, 0, -54)
    tw(barreTitre, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = UDim2.new(0, 0, 0, 0) })
    barreOnglets.Position = UDim2.new(0, -180, 0, 54)
    tw(barreOnglets, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = UDim2.new(0, 0, 0, 54) })
    zoneContenu.Position = UDim2.new(0, 230, 0, 54)
    tw(zoneContenu, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { Position = UDim2.new(0, 180, 0, 54) })
    if not ongletActif then
        task.wait(0.15)
        afficherOnglet("Combat")
    end
end

local function fermer()
    if not estOuvert then return end
    estOuvert = false
    tw(barreOnglets, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { Position = UDim2.new(0, -180, 0, 54) })
    tw(zoneContenu, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { Position = UDim2.new(0, 230, 0, 54) })
    tw(barreTitre, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In, { Position = UDim2.new(0, 0, 0, -54) })
    local a = tw(fenetre, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In, {
        Size = UDim2.fromOffset(660, 460),
        Position = UDim2.new(0.5, -330, 0.5, -230),
        BackgroundTransparency = 1,
    })
    a.Completed:Connect(function()
        fenetre.Visible = false
        barreTitre.Position = UDim2.new(0, 0, 0, 0)
        barreOnglets.Position = UDim2.new(0, 0, 0, 54)
        zoneContenu.Position = UDim2.new(0, 180, 0, 54)
    end)
end

boutonFlottant.MouseButton1Click:Connect(function()
    if estOuvert then fermer() else ouvrir() end
end)
boutonFermer.MouseButton1Click:Connect(fermer)
boutonReduire.MouseButton1Click:Connect(fermer)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode.Name == (config.menu_key or "RightShift") then
        if estOuvert then fermer() else ouvrir() end
    end
    if input.KeyCode.Name == (config.panic_key or "End") then
        for k in pairs(config) do
            if type(config[k]) == "boolean" and k ~= "watermark" and k ~= "notifications" then
                config[k] = false
            end
        end
        notify("PANIC — tous les cheats coupés")
    end
end)

--==============================================================
-- EFFETS UI
--==============================================================
task.spawn(function()
    while indicateurStatut.Parent do
        tw(indicateurStatut, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { BackgroundTransparency = 0.5 })
        task.wait(1.2)
        tw(indicateurStatut, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { BackgroundTransparency = 0 })
        task.wait(1.2)
    end
end)
task.spawn(function()
    while logo.Parent do
        logo.Rotation = math.sin(os.clock() * 1.2) * 4
        task.wait(0.03)
    end
end)

print("[Manoir] Prêt v6.0. RightShift pour ouvrir/fermer.")
notify("MANOIR v6.0 chargé")
