local addonName, pluginNs = ...

-- ====================================================
-- INIT — Réputations Plugin
--
-- Injecte le bouton "Réputations" dans la sidebar via
-- core.RegisterSidebarButton(200, ...) — priorité explicite,
-- placé entre Professions (100) et Guilde (300) quel que soit
-- l'ordre de chargement réel des plugins.
-- ====================================================

local core = _G.AltViewerLogAPI
if not core then
    print("|cffff4444[AVL-Reput]|r " .. pluginNs.L("ERR_API_MISSING"))
    return
end

-- ── Auto-refresh après UPDATE_FACTION ────────────────────────────
-- ViewerLog debounce le scan 2 s ; on attend 2.5 s pour être sûr
-- que ViewerLogDB est à jour avant de redessiner la vue.
do
    local _refreshTimer = nil
    local _evFrame = CreateFrame("Frame")
    _evFrame:RegisterEvent("UPDATE_FACTION")
    _evFrame:SetScript("OnEvent", function()
        if not pluginNs.isViewActive then return end
        if _refreshTimer then _refreshTimer:Cancel() end
        _refreshTimer = C_Timer.NewTimer(2.5, function()
            _refreshTimer = nil
            pluginNs.RefreshView()
        end)
    end)
end

-- ====================================================
-- INJECTION DU BOUTON DANS LA SIDEBAR
-- Enregistrement synchrone via core.RegisterSidebarButton :
-- AltViewerLog est une dépendance déclarée dans notre .toc, donc
-- core et core.RegisterSidebarButton existent forcément déjà ici.
-- La priorité 200 fixe la position (sous Professions = 100, au-
-- dessus de Guilde = 300) indépendamment de l'ordre de chargement
-- réel des plugins.
-- ====================================================
if core.RegisterSidebarButton then
    local btnReput = core.RegisterSidebarButton(200, function(parent)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(160, 35)
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
            local b = core._themeBorder or { 0.65, 0.35, 1.0 }
            self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 1)
            local b = core._themeBorder or { 0.45, 0.15, 0.70 }
            self:SetBackdropBorderColor(b[1], b[2], b[3], 0.85)
        end)
        return btn
    end)

    if btnReput then
        local function GetClassHex()
            local _, classFile = UnitClass("player")
            local col = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
            if col then
                return string.format("%02x%02x%02x",
                    math.floor(col.r * 255),
                    math.floor(col.g * 255),
                    math.floor(col.b * 255))
            end
            return "a040ff"
        end
        local function CC(text) return "|cff" .. GetClassHex() .. text .. "|r" end

        -- Texte couleur de classe : dépend de UnitClass("player"),
        -- légitimement indisponible avant PLAYER_LOGIN. Dépendance
        -- interne à cet addon, pas un couplage envers un autre addon.
        local function ApplyBtnText()
            btnReput:SetText(CC(pluginNs.L("BTN_REPUT")))
        end
        C_Timer.After(0.3, ApplyBtnText)
        local _loginFrame = CreateFrame("Frame")
        _loginFrame:RegisterEvent("PLAYER_LOGIN")
        _loginFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_LOGIN")
            ApplyBtnText()
        end)

        -- Clic → ouvre la vue réputations
        btnReput:SetScript("OnClick", function()
            -- Fermer toutes les popups flottantes : sélecteur de guilde,
            -- dropdowns Métiers, charSelMenu… via la chaîne CloseModulePopups.
            if core.CloseAllPopups then core.CloseAllPopups() end
            pluginNs.isViewActive = true
            pluginNs.ShowReput()
        end)

        -- Désactiver isViewActive quand un autre bouton sidebar est cliqué
        for _, btn in ipairs(core.sideButtons or {}) do
            if btn and btn ~= btnReput then
                btn:HookScript("OnClick", function()
                    pluginNs.isViewActive = false
                end)
            end
        end
        for _, btn in ipairs({ core.btnGear, core.btnGraph, core.btnConfig }) do
            if btn then
                btn:HookScript("OnClick", function()
                    pluginNs.isViewActive = false
                end)
            end
        end

        -- Masquer isViewActive quand la fenêtre principale se ferme
        if core.mainFrame then
            core.mainFrame:HookScript("OnHide", function()
                pluginNs.isViewActive = false
            end)
        end
    end
end

-- ── Slash command /avlreput ────────────────────────────────────────
SLASH_AVLREPUT1 = "/avlreput"
SlashCmdList["AVLREPUT"] = function(msg)
    msg = msg and strtrim(msg:lower()) or ""
    if msg == "show" then
        if core.mainFrame then core.mainFrame:Show() end
        pluginNs.isViewActive = true
        pluginNs.ShowReput()
    elseif msg == "scan" then
        if _G.ViewerLogAPI and _G.ViewerLogAPI.ScanReputations then
            _G.ViewerLogAPI.ScanReputations()
            core.DBG("|cffa040ff[AVL-Reput]|r " .. pluginNs.L("DBG_SCAN_STARTED"))
        else
            core.DBG("|cffff4444[AVL-Reput]|r " .. pluginNs.L("DBG_SCAN_FN_MISSING"))
        end
    else
        core.DBG("|cffa040ff[AVL-Reput]|r" .. pluginNs.L("DBG_HELP_SHOW"))
        core.DBG("|cffa040ff[AVL-Reput]|r" .. pluginNs.L("DBG_HELP_SCAN"))
    end
end

core.DBG("|cffa040ff[AVL-Reput]|r " .. pluginNs.L("DBG_LOADED"))

-- ── Addon Compartment (menu minimap) ─────────────────────────────
function AVL_Reput_OnCompartmentClick()
    if not core or not core.mainFrame then return end
    if core.mainFrame:IsShown() then
        pluginNs.isViewActive = true
        pluginNs.ShowReput()
    else
        core.mainFrame:Show()
        C_Timer.After(0.05, function()
            pluginNs.isViewActive = true
            pluginNs.ShowReput()
        end)
    end
end

function AVL_Reput_OnCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:AddLine(pluginNs.L("AC_TITLE"))
    local charName = pluginNs.currentCharName
    local realm    = pluginNs.currentRealm
    local reps = charName and realm and _G.ViewerLogAPI
                 and _G.ViewerLogAPI.GetReputations(charName, realm)
    if reps then
        local count = 0
        for _ in pairs(reps) do
            count = count + 1
        end
        GameTooltip:AddLine(string.format(pluginNs.L("AC_CHAR_REPUT_COUNT"), charName, count), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff808080" .. pluginNs.L("AC_CLICK_HINT") .. "|r")
    GameTooltip:Show()
end

function AVL_Reput_OnCompartmentLeave()
    GameTooltip:Hide()
end
