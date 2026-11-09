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

-- ── Factory bouton ───────────────────────────────────────────────
ns.sideButtons = {}

local BTN_W, BTN_H, BTN_GAP, TOP_OFF = LAYOUT.sideW - 24, 34, 8, 12

-- Bouton natif (Discord, Paramètres) : ancré par RelayoutButtons.
local function CreateMenuButton()
    local btn = CreateFrame("Button", nil, sideBar, "BackdropTemplate")
    btn:SetSize(BTN_W, BTN_H)
    ns.Skin.SideButton(btn)
    ns.sideButtons[#ns.sideButtons + 1] = btn
    return btn
end

-- ── Fermeture de toutes les popups flottantes ────────────────────
-- Définie AVANT tout SetScript qui l'utilise (closure sur une local).
-- Les dépendances chaînent ns.CloseModulePopups pour ajouter les leurs.
local function CloseAllPopups()
    if ns.charSelMenu and ns.charSelMenu:IsShown() then
        ns.charSelMenu:Hide()
    end
    if ns.CloseModulePopups then ns.CloseModulePopups() end
end
ns.CloseAllPopups = CloseAllPopups  -- exposé pour les sous-modules

-- ── Boutons natifs : Discord, puis Paramètres (toujours en dernier) ──
-- Discord : appel du module fonctionnalite/Discord.lua de façon contrôlée
-- (aucune dépendance directe : simple vérification d'existence).
ns.btnDiscord = CreateMenuButton()
ns.btnDiscord:SetScript("OnClick", function()
    CloseAllPopups()
    if ns.ShowDiscordDialog then ns.ShowDiscordDialog() end
end)

ns.btnConfig = CreateMenuButton()
ns.btnConfig:SetScript("OnClick", function() CloseAllPopups(); ns.ShowSettings() end)

-- Bouton actif : Paramètres (Discord ouvre juste un dialogue)
ns.btnConfig:HookScript("OnClick", function(self) ns.Skin.SetActive(self) end)

-- ====================================================
-- ENREGISTREMENT DE BOUTONS SIDEBAR PAR LES DÉPENDANCES
-- ====================================================
-- Chaque dépendance (Inventaire, Graphique, Métiers…) appelle
-- ns.RegisterSidebarButton(...) de façon SYNCHRONE depuis son propre
-- fichier : AltViewerLog est déclaré dans son .toc, le loader WoW
-- garantit donc qu'il est déjà entièrement chargé. L'ordre vient de
-- la priorité explicite, jamais du timing.
--
-- Usage :
--   core.RegisterSidebarButton(100, function(parent)
--       local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
--       return btn  -- ne PAS l'ancrer : c'est géré ici
--   end, MaFonctionDeVue)  -- vue optionnelle : surlignage à l'ouverture
--
-- Priorités :
--   10-14 = Inventaire, 50 = Graphique, 100 = Métiers,
--   200 = Réputations, 300 = Guilde
-- ====================================================

local _pluginButtons = {} -- { {priority=, btn=}, ... }
local _viewButtons   = {} -- [fonction de vue] = bouton

local function RelayoutButtons()
    table.sort(_pluginButtons, function(a, b) return a.priority < b.priority end)
    local anchor
    for _, entry in ipairs(_pluginButtons) do
        entry.btn:ClearAllPoints()
        if anchor then
            entry.btn:SetPoint("TOP", anchor, "BOTTOM", 0, -BTN_GAP)
        else
            entry.btn:SetPoint("TOP", sideBar, "TOP", 0, -TOP_OFF)
        end
        anchor = entry.btn
    end

    ns.btnDiscord:ClearAllPoints()
    if anchor then
        ns.btnDiscord:SetPoint("TOP", anchor, "BOTTOM", 0, -BTN_GAP)
    else
        ns.btnDiscord:SetPoint("TOP", sideBar, "TOP", 0, -TOP_OFF)
    end

    ns.btnConfig:ClearAllPoints()
    ns.btnConfig:SetPoint("TOP", ns.btnDiscord, "BOTTOM", 0, -BTN_GAP)
end
RelayoutButtons()

-- Crée (via factory) et positionne un bouton de dépendance, à
-- l'emplacement déterminé par `priority` (plus petit = plus haut).
-- `view` (optionnel) : fonction de vue affichée par le bouton, pour le
-- surlignage à l'ouverture. Retourne le bouton, ou nil si invalide.
function ns.RegisterSidebarButton(priority, factory, view)
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
    if type(view) == "function" then _viewButtons[view] = btn end

    _pluginButtons[#_pluginButtons + 1] = { priority = priority, btn = btn }
    RelayoutButtons()
    return btn
end

-- Vue affichée à l'ouverture de la fenêtre (fournie par une dépendance).
-- Sans vue d'accueil, l'ouverture tombe sur Paramètres.
function ns.SetHomeView(fn)
    if type(fn) == "function" then ns.homeView = fn end
end

-- Surligne le bouton de la vue courante (ou de la vue d'accueil).
function ns.HighlightCurrentView()
    local v = ns.currentView or ns.homeView or ns.ShowSettings
    local btn = (v == ns.ShowSettings) and ns.btnConfig or _viewButtons[v]
    if btn then ns.Skin.SetActive(btn) end
end

-- ── Mise à jour textes (couleur de classe, localisation) ─────────
local function RefreshMenuText()
    ns.btnConfig:SetText(ns.L("BTN_SETTINGS"))
    ns.btnDiscord:SetText(ns.L("BTN_DISCORD"))
end
ns.RefreshMenuText = RefreshMenuText

-- À l'ouverture : une vue de dépendance garde son surlignage posé au clic.
ns.mainFrame:HookScript("OnShow", ns.HighlightCurrentView)

-- Applique les textes au login (couleurs de classe disponibles)
local _loginFrame = CreateFrame("Frame")
_loginFrame:RegisterEvent("PLAYER_LOGIN")
_loginFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    RefreshMenuText()
    ns.ApplyTheme(ns.GetThemeKey())
end)
