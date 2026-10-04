local addonName, ns = ...

-- ====================================================
-- UI/SIDEBAR — Panneau latéral + boutons du menu
-- Rôle UNIQUE : créer la sidebar et tous ses boutons.
-- ====================================================

local LAYOUT = ns.LAYOUT

local sideBar = CreateFrame("Frame", "AVL_SideBar", ns.mainFrame, "BackdropTemplate")
sideBar:SetWidth(LAYOUT.sideW)
sideBar:SetPoint("TOPLEFT",    ns.mainFrame, "TOPLEFT",    LAYOUT.pad, -LAYOUT.titleH)
sideBar:SetPoint("BOTTOMLEFT", ns.mainFrame, "BOTTOMLEFT", LAYOUT.pad,  LAYOUT.bottomH)
ns.Skin.Frame(sideBar, "panel")
ns._UI = ns._UI or {}
ns._UI.sideBar = sideBar

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

local BTN_W, BTN_H, BTN_GAP = LAYOUT.sideW - 24, 34, 8

local function CreateMenuButton(label, anchorFrame, offsetY)
    local btn = CreateFrame("Button", nil, sideBar, "BackdropTemplate")
    btn:SetSize(BTN_W, BTN_H)
    btn:SetPoint("TOP", anchorFrame, "BOTTOM", 0, offsetY)
    ns.Skin.SideButton(btn)
    btn:SetText(label)
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
ns.btnSearch:SetSize(BTN_W, BTN_H)
ns.btnSearch:SetPoint("TOP", sideBar, "TOP", 0, -12)
ns.Skin.SideButton(ns.btnSearch)
ns.btnSearch:SetScript("OnClick", function() CloseAllPopups(); ns.ShowSearch() end)
ns.sideButtons[#ns.sideButtons + 1] = ns.btnSearch

local btnChars   = CreateMenuButton("...", ns.btnSearch, -BTN_GAP)
local btnBank    = CreateMenuButton("...", btnChars,     -BTN_GAP)
local btnWarband = CreateMenuButton("...", btnBank,      -BTN_GAP)
ns.btnGear       = CreateMenuButton("...", btnWarband,   -BTN_GAP)

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
ns.btnDiscord = CreateMenuButton("...", ns.btnLastBeforeConfig, -BTN_GAP)
ns.btnDiscord:SetScript("OnClick", function()
    CloseAllPopups()
    if ns.ShowDiscordDialog then ns.ShowDiscordDialog() end
end)

ns.btnConfig = CreateMenuButton("...", ns.btnDiscord, -BTN_GAP)
ns.btnConfig:SetScript("OnClick", function() CloseAllPopups(); ns.ShowSettings() end)

-- Bouton actif : toutes les vues natives (Discord ouvre juste un dialogue)
for _, b in ipairs({ ns.btnSearch, btnChars, btnBank, btnWarband, ns.btnGear, ns.btnConfig }) do
    b:HookScript("OnClick", function(self) ns.Skin.SetActive(self) end)
end

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
        entry.btn:SetPoint("TOP", anchor, "BOTTOM", 0, -BTN_GAP)
        anchor = entry.btn
    end
    ns.btnLastBeforeConfig = anchor

    ns.btnDiscord:ClearAllPoints()
    ns.btnDiscord:SetPoint("TOP", anchor, "BOTTOM", 0, -BTN_GAP)

    ns.btnConfig:ClearAllPoints()
    ns.btnConfig:SetPoint("TOP", ns.btnDiscord, "BOTTOM", 0, -BTN_GAP)
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

    -- Le look des boutons de sidebar appartient au core : taille, skin
    -- et bouton actif sont appliqués ici, les plugins n'ont rien à gérer.
    btn:SetSize(BTN_W, BTN_H)
    ns.Skin.SideButton(btn)
    -- Bouton actif : le plugin pose son OnClick après l'enregistrement, ce
    -- qui écraserait un HookScript. On enveloppe donc SetScript lui-même.
    local rawSetScript = btn.SetScript
    btn.SetScript = function(self, name, fn)
        if name == "OnClick" and fn then
            local user = fn
            fn = function(s, ...) ns.Skin.SetActive(s); return user(s, ...) end
        end
        return rawSetScript(self, name, fn)
    end
    local existing = btn:GetScript("OnClick")
    if existing then btn:SetScript("OnClick", existing) end

    ns.sideButtons[#ns.sideButtons + 1] = btn

    _pluginButtons[#_pluginButtons + 1] = { priority = priority, btn = btn }
    RelayoutPluginButtons()
    return btn
end

-- ── Mise à jour textes (couleur de classe, localisation) ──────────
local function RefreshMenuText()
    ns.btnSearch:SetText(ns.L("BTN_SEARCH"))
    btnChars:SetText(ns.L("BTN_CHARS"))
    btnBank:SetText(ns.L("BTN_BANK"))
    btnWarband:SetText(ns.L("BTN_WARBAND"))
    ns.btnGear:SetText(ns.L("BTN_GEAR"))
    ns.btnConfig:SetText(ns.L("BTN_SETTINGS"))
    ns.btnDiscord:SetText(ns.L("BTN_DISCORD"))
end
ns.RefreshMenuText = RefreshMenuText

-- À l'ouverture : surligne le bouton de la vue native courante
-- (une vue de plugin garde son surlignage posé au clic).
ns.mainFrame:HookScript("OnShow", function()
    local v = ns.currentView
    local map = {
        [ns.RefreshCharacterList or 0] = btnChars,
        [ns.ShowSearch or 0]           = ns.btnSearch,
        [ns.ShowGear or 0]             = ns.btnGear,
        [ns.ShowWarbandBank or 0]      = btnWarband,
        [ns.ShowSettings or 0]         = ns.btnConfig,
    }
    if not v then ns.Skin.SetActive(btnChars)
    elseif map[v] then ns.Skin.SetActive(map[v]) end
end)

-- Applique les textes au login (couleurs de classe disponibles)
local _loginFrame = CreateFrame("Frame")
_loginFrame:RegisterEvent("PLAYER_LOGIN")
_loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if ns.AVL_InitFilterCats then ns.AVL_InitFilterCats() end
    RefreshMenuText()
    ns.ApplyTheme(ns.GetThemeKey())
end)
