local addonName, ns = ...

-- ====================================================
-- UI/SIDEBAR — Panneau latéral + boutons du menu
-- Rôle UNIQUE : créer la sidebar et tous ses boutons.
-- ====================================================

local sideBar = CreateFrame("Frame", "AVL_SideBar", ns.mainFrame, "BackdropTemplate")
sideBar:SetWidth(200)
sideBar:SetPoint("TOPLEFT",     ns.mainFrame, "TOPLEFT",     0, -30)
sideBar:SetPoint("BOTTOMLEFT",  ns.mainFrame, "BOTTOMLEFT",  0,  36)
sideBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
sideBar:SetBackdropColor(0, 0, 0, 1)

-- Séparateur vertical entre sidebar et contenu
local divider = ns.mainFrame:CreateTexture(nil, "ARTWORK")
divider:SetWidth(1)
divider:SetPoint("TOPLEFT",    sideBar, "TOPRIGHT",    0, 0)
divider:SetPoint("BOTTOMLEFT", sideBar, "BOTTOMRIGHT", 0, 0)
divider:SetColorTexture(0.20, 0.08, 0.40, 0.80)
ns._UI = ns._UI or {}
ns._UI.sideBar = sideBar
ns._UI.divider = divider

-- ── Couleur de classe ─────────────────────────────────────────────
local function GetClassHex()
    local _, classFile = UnitClass("player")
    local col = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if col then
        return string.format("%02x%02x%02x",
            math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255))
    end
    return "cc88ff"
end
local function CC(text) return "|cff"..GetClassHex()..text.."|r" end
ns.CC = CC

-- ── Factory bouton ────────────────────────────────────────────────
ns.sideButtons = {}

local function CreateMenuButton(label, anchorFrame, offsetY)
    local btn = CreateFrame("Button", nil, sideBar, "BackdropTemplate")
    btn:SetSize(160, 35)
    btn:SetPoint("TOP", anchorFrame, "BOTTOM", 0, offsetY)
    btn:SetText(label)
    btn:SetNormalFontObject("GameFontNormal")
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    btn:SetBackdropColor(0, 0, 0, 1)
    btn:SetBackdropBorderColor(0.45, 0.15, 0.70, 0.85)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.10, 0.10, 0.10, 1)
        local b = ns._themeBorder or {0.65, 0.35, 1.0}
        self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0, 0, 0, 1)
        local b = ns._themeBorder or {0.45, 0.15, 0.70}
        self:SetBackdropBorderColor(b[1], b[2], b[3], 0.85)
    end)
    ns.sideButtons[#ns.sideButtons + 1] = btn
    return btn
end

-- ── Fermeture de toutes les popups flottantes ─────────────────────
-- Définie AVANT tout SetScript qui l'utilise.
-- En Lua une closure ne peut capturer une local que si elle est déclarée
-- avant la closure — sinon Lua cherche un global introuvable (nil).
local function CloseAllPopups()
    if ns.charSelMenu and ns.charSelMenu:IsShown() then
        ns.charSelMenu:Hide()
    end
    -- Fermer le dropdown de filtre de recherche s'il est ouvert
    if ns._searchDropdown and ns._searchDropdown:IsShown() then
        ns._searchDropdown:Hide()
    end
    if ns._searchCloseW and ns._searchCloseW:IsShown() then
        ns._searchCloseW:Hide()
    end
    if ns.CloseModulePopups then ns.CloseModulePopups() end
end
ns.CloseAllPopups = CloseAllPopups  -- exposé pour les sous-modules

-- ── Boutons dans l'ordre ──────────────────────────────────────────
-- Premier bouton ancré sur la sidebar elle-même
ns.btnSearch = CreateFrame("Button", nil, sideBar, "BackdropTemplate")
ns.btnSearch:SetSize(160, 35)
ns.btnSearch:SetPoint("TOP", sideBar, "TOP", 0, -20)
ns.btnSearch:SetNormalFontObject("GameFontNormal")
ns.btnSearch:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=2 })
ns.btnSearch:SetBackdropColor(0, 0, 0, 1)
ns.btnSearch:SetBackdropBorderColor(0.45, 0.15, 0.70, 0.85)
ns.btnSearch:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.10, 0.10, 0.10, 1)
    local b = ns._themeBorder or {0.65, 0.35, 1.0}
    self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
end)
ns.btnSearch:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0, 0, 0, 1)
    local b = ns._themeBorder or {0.45, 0.15, 0.70}
    self:SetBackdropBorderColor(b[1], b[2], b[3], 0.85)
end)
ns.btnSearch:SetScript("OnClick", function() CloseAllPopups(); ns.ShowSearch() end)
ns.sideButtons[#ns.sideButtons + 1] = ns.btnSearch

local btnChars   = CreateMenuButton("...", ns.btnSearch, -10)
local btnBank    = CreateMenuButton("...", btnChars,     -10)
local btnWarband = CreateMenuButton("...", btnBank,      -10)
ns.btnGear       = CreateMenuButton("...", btnWarband,   -10)

ns.btnChars   = btnChars
ns.btnWarband = btnWarband
ns.btnBank    = btnBank

btnChars:SetScript("OnClick",   function() CloseAllPopups(); ns.activeFilterCat = nil; ns.RefreshCharacterList() end)
btnBank:SetScript("OnClick",    function() CloseAllPopups(); ns.ShowBank(ns.bankViewChar or UnitName("player"), ns.bankViewRealm or GetRealmName()) end)
btnWarband:SetScript("OnClick", function() CloseAllPopups(); ns.activeFilterCat = nil; ns.ShowWarbandBank() end)
ns.btnGear:SetScript("OnClick", function() CloseAllPopups(); ns.ShowGear() end)

-- Point d'ancrage pour les dépendances (Graph, Professions, GuildeLog…).
-- Le bouton Graphique est désormais fourni par la dépendance
-- AltViewerLog_Graph (priorité 50), plus par le core.
ns.btnLastBeforeConfig = ns.btnGear

-- Discord (toujours juste au-dessus de Paramètres, après les plugins
-- éventuels). Fait partie de la chaîne d'ancrage native : réancré
-- par RelayoutPluginButtons ci-dessous à chaque enregistrement de
-- plugin, pour rester juste avant Paramètres quoi qu'il arrive.
-- Appel du module fonctionnalite/Discord.lua de façon contrôlée
-- (aucune dépendance directe : simple vérification d'existence).
ns.btnDiscord = CreateMenuButton("...", ns.btnLastBeforeConfig, -10)
ns.btnDiscord:SetScript("OnClick", function()
    CloseAllPopups()
    if ns.ShowDiscordDialog then ns.ShowDiscordDialog() end
end)

ns.btnConfig = CreateMenuButton("...", ns.btnDiscord, -10)
ns.btnConfig:SetScript("OnClick", function() CloseAllPopups(); ns.ShowSettings() end)

-- ====================================================
-- ENREGISTREMENT DE BOUTONS SIDEBAR PAR LES PLUGINS
-- ====================================================
-- Remplace l'ancien système où chaque plugin (Professions,
-- GuildeLog, Réputations…) s'insérait via un C_Timer.After à
-- délai codé en dur (0.6s / 0.9s / 1.2s…) pour deviner l'ordre
-- d'exécution des autres plugins. Ce système était fragile :
-- l'ordre réel ne dépendait que de constantes recopiées à la
-- main dans plusieurs addons différents, sans aucune relation
-- déclarée entre eux, et toute désynchronisation échouait en
-- silence.
--
-- Désormais chaque plugin appelle ns.RegisterSidebarButton(...)
-- de façon SYNCHRONE, directement dans son propre Init.lua (pas
-- besoin de timer : à ce stade AltViewerLog est déjà entièrement
-- chargé, puisque c'est une dépendance déclarée dans le .toc du
-- plugin — le loader WoW garantit cet ordre). Le tri par priorité
-- explicite remplace l'ordre implicite basé sur le timing.
--
-- Usage :
--   core.RegisterSidebarButton(100, function(parent)
--       local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
--       -- ... style, taille, texte, OnClick ...
--       return btn  -- ne PAS l'ancrer : c'est géré ici
--   end)
--
-- Priorités utilisées par les plugins officiels (laisser de la
-- marge pour en insérer d'autres) :
--   100 = Professions, 200 = Réputations, 300 = Guilde
-- ====================================================

local _pluginButtons = {} -- { {priority=, btn=}, ... }

local function RelayoutPluginButtons()
    table.sort(_pluginButtons, function(a, b) return a.priority < b.priority end)
    local anchor = ns.btnGear
    for _, entry in ipairs(_pluginButtons) do
        entry.btn:ClearAllPoints()
        entry.btn:SetPoint("TOP", anchor, "BOTTOM", 0, -10)
        anchor = entry.btn
    end
    ns.btnLastBeforeConfig = anchor

    ns.btnDiscord:ClearAllPoints()
    ns.btnDiscord:SetPoint("TOP", anchor, "BOTTOM", 0, -10)

    ns.btnConfig:ClearAllPoints()
    ns.btnConfig:SetPoint("TOP", ns.btnDiscord, "BOTTOM", 0, -10)
end

-- Crée (via factory) et positionne un bouton de plugin dans la
-- sidebar, à l'emplacement déterminé par `priority` (plus petit
-- = plus haut, juste sous les boutons natifs de AltViewerLog).
-- Retourne le bouton créé, ou nil si les paramètres sont invalides.
function ns.RegisterSidebarButton(priority, factory)
    if type(priority) ~= "number" or type(factory) ~= "function" then
        return nil
    end
    local btn = factory(sideBar)
    if not btn then return nil end

    ns.sideButtons[#ns.sideButtons + 1] = btn
    if ns._themeBorder then
        local b = ns._themeBorder
        btn:SetBackdropBorderColor(b[1], b[2], b[3], 0.85)
    end

    _pluginButtons[#_pluginButtons + 1] = { priority = priority, btn = btn }
    RelayoutPluginButtons()
    return btn
end

-- ── Mise à jour textes (couleur de classe, localisation) ──────────
local function RefreshMenuText()
    ns.btnSearch:SetText(CC(ns.L("BTN_SEARCH")))
    btnChars:SetText(CC(ns.L("BTN_CHARS")))
    btnBank:SetText(CC(ns.L("BTN_BANK")))
    btnWarband:SetText(CC(ns.L("BTN_WARBAND")))
    ns.btnGear:SetText(CC(ns.L("BTN_GEAR")))
    ns.btnConfig:SetText(CC(ns.L("BTN_SETTINGS")))
    ns.btnDiscord:SetText(CC(ns.L("BTN_DISCORD")))
end
ns.RefreshMenuText = RefreshMenuText

-- Applique les textes au login (couleurs de classe disponibles)
local _loginFrame = CreateFrame("Frame")
_loginFrame:RegisterEvent("PLAYER_LOGIN")
_loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if ns.AVL_InitFilterCats then ns.AVL_InitFilterCats() end
    RefreshMenuText()
    local theme = AltViewerLogDB and AltViewerLogDB.settings and AltViewerLogDB.settings.theme
    if theme and ns.ApplyTheme then ns.ApplyTheme(theme) end
end)
