local addonName, ns = ...

-- ====================================================
-- THEME — Système de thème visuel de AltViewerLog
-- Rôle UNIQUE : définir les thèmes et appliquer
-- les couleurs à tous les éléments de l'UI.
--
-- Dépendances (construites par UI.lua avant ce fichier) :
--   ns.mainFrame, ns.bottomBar, ns.titleText
--   ns.sideButtons, ns.bottomBtns
-- Les variables privées (mainBG, sideBar) sont injectées
-- via ns._UI (voir UI.lua).
-- ====================================================

local BACKDROP_DEFAULT  = { bgFile = "Interface\\Buttons\\WHITE8x8" }
local BACKDROP_XALATH   = {
    bgFile   = "Interface\\AddOns\\AltViewerLog\\media\\background\\AVL_Background_Xalath.png",
    tile=false, tileSize=0, edgeSize=0,
    insets = { left=0, right=0, top=0, bottom=0 },
}
local BACKDROP_SYLVANAS = {
    bgFile   = "Interface\\AddOns\\AltViewerLog\\media\\background\\AVL_Background_Sylvanas.png",
    tile=false, tileSize=0, edgeSize=0,
    insets = { left=0, right=0, top=0, bottom=0 },
}

local THEME_BORDER = {
    default  = { 0.30, 0.30, 0.30 },
    xalath   = { 0.45, 0.15, 0.70 },
    sylvanas = { 0.70, 0.05, 0.05 },
}

-- Couleur du titre "AltViewerLog", découplée de la bordure : en thème
-- normal on veut du bleu, pas le gris de la bordure. Une teinte absente
-- ici retombe sur la couleur de bordure (xalath/sylvanas suivent donc
-- l'accent du thème, inchangés).
local THEME_TITLE = {
    default = "4da6ff",
}

-- Couleur du sous-titre "By Soloup_ever" par thème.
local THEME_SUBTITLE = {
    default  = "ff40a0",
    xalath   = "ff3333",
    sylvanas = "b266ff",
}

function ns.ApplyTheme(theme)
    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
    AltViewerLogDB.settings.theme = theme

    local border = THEME_BORDER[theme] or THEME_BORDER.default
    ns._themeBorder = border
    local br, bg, bb = border[1], border[2], border[3]

    local hex = string.format("%02x%02x%02x",
        math.floor(br*255), math.floor(bg*255), math.floor(bb*255))
    ns._themeHex = hex

    local titleHex = THEME_TITLE[theme] or hex
    local subHex   = THEME_SUBTITLE[theme] or THEME_SUBTITLE.default
    ns._themeTitleHex = titleHex

    if ns.titleText then
        ns.titleText:SetText("|cff"..titleHex.."AltViewerLog|r |cff"..subHex.."By Soloup_ever|r")
    end

    for _, btn in ipairs(ns.sideButtons or {}) do
        btn:SetBackdropBorderColor(br, bg, bb, 0.85)
    end

    -- Pouces de scrollbar (ui/ScrollArea.lua) : suivent l'accent du
    -- thème ; seule la teinte change, l'alpha de repos (0.55) reste
    -- celle gérée par ScrollArea.lua (survol/drag).
    for _, thumbTex in ipairs(ns.scrollBarThumbs or {}) do
        thumbTex:SetColorTexture(br, bg, bb, 0.55)
    end

    local bgR, bgG, bgB
    if theme == "default" then
        bgR, bgG, bgB = 0.10, 0.10, 0.10
    else
        bgR = br*0.18 + 0.03
        bgG = bg*0.12 + 0.03
        bgB = bb*0.25 + 0.06
    end
    for _, btn in ipairs(ns.bottomBtns or {}) do
        btn:SetBackdropColor(bgR, bgG, bgB, 1.0)
        btn:SetBackdropBorderColor(br, bg, bb, 1)
    end

    -- Accès aux frames privées de UI.lua
    local UI = ns._UI or {}

    -- Séparateur vertical sidebar/contenu (ui/Sidebar.lua) : même
    -- teinte que les bordures de boutons, un peu plus sombre pour
    -- rester discret (c'est un simple filet de 1px, pas un accent).
    if UI.divider then
        UI.divider:SetColorTexture(br * 0.55, bg * 0.55, bb * 0.55, 0.80)
    end

    if theme == "xalath" then
        ns.mainFrame:SetBackdrop(BACKDROP_XALATH)
        ns.mainFrame:SetBackdropColor(1, 1, 1, 1)
        if UI.mainBG  then UI.mainBG:SetBackdropColor(0, 0, 0, 0) end
        if UI.sideBar then UI.sideBar:SetBackdropColor(0, 0, 0, 0.55) end
        if ns.bottomBar then ns.bottomBar:SetBackdropColor(0, 0, 0, 0.85) end
    elseif theme == "sylvanas" then
        ns.mainFrame:SetBackdrop(BACKDROP_SYLVANAS)
        ns.mainFrame:SetBackdropColor(1, 1, 1, 1)
        if UI.mainBG  then UI.mainBG:SetBackdropColor(0, 0, 0, 0) end
        if UI.sideBar then UI.sideBar:SetBackdropColor(0, 0, 0, 0.55) end
        if ns.bottomBar then ns.bottomBar:SetBackdropColor(0, 0, 0, 0.85) end
    else
        ns.mainFrame:SetBackdrop(BACKDROP_DEFAULT)
        ns.mainFrame:SetBackdropColor(0, 0, 0, 1)
        if UI.mainBG  then UI.mainBG:SetBackdropColor(0, 0, 0, 1) end
        if UI.sideBar then UI.sideBar:SetBackdropColor(0, 0, 0, 1) end
        if ns.bottomBar then ns.bottomBar:SetBackdropColor(0, 0, 0, 1) end
    end
end
