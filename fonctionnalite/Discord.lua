local addonName, ns = ...

-- ====================================================
-- DISCORD — popup avec le lien du serveur Discord communautaire.
-- Rôle UNIQUE : fournir la popup de partage du lien.
--
-- Isolation : ce module n'a aucune dépendance vers un autre —
-- il expose uniquement ns.ShowDiscordDialog(). Le bouton sidebar
-- (ui/Sidebar.lua) l'appelle de façon contrôlée, via une simple
-- vérification d'existence (if ns.ShowDiscordDialog then ...) :
-- si ce fichier est retiré ou modifié, aucun autre module ne casse.
--
-- Fenêtre custom, PAS StaticPopupDialogs : sur le client actuel,
-- l'EditBox d'une StaticPopup est exposé via self.EditBox (majuscule,
-- cf. Blizzard_StaticPopup_Game/GameDialog.lua) et non plus
-- self.editBox — ce champ est désormais nil et fait planter tout
-- code qui l'utilise encore (OnShow/OnHide). Portage du popup déjà
-- éprouvé ailleurs dans l'écosystème (ViewerLog-Classic
-- ui/DiscordButton.lua, MatchViewerLog ui/dialogs/DiscordDialog.lua) :
-- une simple fenêtre déplaçable avec son propre EditBox, sans aucune
-- dépendance à l'API StaticPopup.
--
-- Pas d'API WoW pour ouvrir une URL dans le navigateur : "actionnable"
-- = lien pré-sélectionné dans l'EditBox, prêt pour Ctrl+C.
-- ====================================================

local LINK = "https://discord.gg/2gfEKGAT46"

local dlg

-- Construction paresseuse : la fenêtre n'est créée qu'au premier
-- appel, une seule fois (pas de recréation à chaque clic).
local function EnsureDialog()
    if dlg then return dlg end

    dlg = CreateFrame("Frame", "AVL_DiscordDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(360, 112)
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("DIALOG")
    dlg:SetToplevel(true)
    ns.Skin.Frame(dlg, "window")
    dlg:EnableMouse(true)
    dlg:SetMovable(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving)
    dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "AVL_DiscordDialog") -- fermable à l'Échap

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)

    local close = ns.Skin.CloseButton(dlg, function() dlg:Hide() end)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -8, -8)

    dlg.hintFS = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.hintFS:SetPoint("TOP", 0, -38)

    local box = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 16, -58)
    box:SetPoint("TOPRIGHT", -16, -58)
    box:SetHeight(22)
    ns.Skin.Frame(box, "input")
    dlg.box = box

    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 6, 0)
    edit:SetPoint("BOTTOMRIGHT", -6, 0)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    dlg.edit = edit

    return dlg
end

-- Chaîné sur CloseModulePopups (sans écraser un handler déjà posé par
-- un autre module) : la popup Discord se ferme comme les autres
-- popups flottantes (menu de sélection de perso, dropdown de
-- recherche…) dès qu'un autre bouton sidebar est cliqué. Même patron
-- que ns.btnConfig/ns.btnSearch dans ui/Sidebar.lua.
local _prevModuleClose = ns.CloseModulePopups
ns.CloseModulePopups = function()
    if _prevModuleClose then _prevModuleClose() end
    if dlg and dlg:IsShown() then dlg:Hide() end
end

function ns.ShowDiscordDialog()
    EnsureDialog()

    dlg.title:SetTextColor(unpack(ns.Theme.heading))

    -- Textes relus à chaque ouverture pour suivre un éventuel
    -- changement de langue en cours de session (AltViewerLogDB.settings.lang).
    dlg.title:SetText(ns.L("BTN_DISCORD"))
    dlg.hintFS:SetText(ns.L("DISCORD_HINT"))

    dlg.edit:SetText(LINK)
    dlg:Show()
    dlg:Raise()
    dlg.edit:SetFocus()
    dlg.edit:HighlightText()
end
