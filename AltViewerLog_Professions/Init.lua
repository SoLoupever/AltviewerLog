local addonName, pluginNs = ...

local core = _G.AltViewerLogAPI
if not core then
    print("|cffff0000[AVL-Prof]|r " .. pluginNs.L("ERR_API_MISSING"))
    return
end

core.DBG("|cff00ff00[AVL-Prof]|r " .. pluginNs.L("DBG_LOADED"))

-- ====================================================
-- INJECTION DU BOUTON DANS LA SIDEBAR
-- Enregistrement synchrone via core.RegisterSidebarButton :
-- AltViewerLog est une dépendance déclarée dans notre .toc, donc
-- core et core.RegisterSidebarButton existent forcément déjà ici
-- (plus besoin de C_Timer.After pour "attendre" qu'ils existent).
-- La priorité 100 fixe la position dans la sidebar indépendamment
-- de l'ordre de chargement des autres plugins.
-- ====================================================
if core.RegisterSidebarButton then
    local btnProf = core.RegisterSidebarButton(100, function(parent)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(160, 35)
        btn:SetText(core.L("BTN_PROFESSIONS"))
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
            local b = core._themeBorder or {0.65, 0.35, 1.0}
            self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 1)
            local b = core._themeBorder or {0.45, 0.15, 0.70}
            self:SetBackdropBorderColor(b[1], b[2], b[3], 0.85)
        end)
        return btn
    end)

    if btnProf then
        local function ApplyProfBtnColor()
            local _, classFile = UnitClass("player")
            local col = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
            local hex = "cc88ff"
            if col then
                hex = string.format("%02x%02x%02x",
                    math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255))
            end
            btnProf:SetText("|cff"..hex..core.L("BTN_PROFESSIONS").."|r")
        end
        -- Couleur de classe : dépend de UnitClass("player"), légitimement
        -- indisponible avant PLAYER_LOGIN. Ceci est une dépendance interne
        -- à cet addon (pas un couplage envers un autre addon).
        C_Timer.After(1, ApplyProfBtnColor)
        local _profColorFrame = CreateFrame("Frame")
        _profColorFrame:RegisterEvent("PLAYER_LOGIN")
        _profColorFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_LOGIN")
            ApplyProfBtnColor()
        end)

        btnProf:SetScript("OnClick", function()
            -- Fermer toutes les popups flottantes (charSelMenu, etc.)
            if core.CloseAllPopups then core.CloseAllPopups() end
            pluginNs.isViewActive = true
            pluginNs.ShowProfessions()
        end)

        if core.mainFrame then
            core.mainFrame:HookScript("OnHide", function()
                if pluginNs.CloseActiveDropdown then pluginNs.CloseActiveDropdown() end
                if pluginNs.CloseExpansionFilterPopup then pluginNs.CloseExpansionFilterPopup() end
                if pluginNs.CloseProfessionFilterPopup then pluginNs.CloseProfessionFilterPopup() end
            end)
        end

        -- ── Branchement dans CloseAllPopups de la sidebar principale ──────────
        -- Permet à chaque bouton sidebar (Search, Personnages, Banque…) de fermer
        -- automatiquement les popups du module Métiers, exactement comme
        -- CloseAllFilterPopups() le fait dans ProfessionViewerLog/core/Frame.lua.
        -- Chaîner (pas écraser) CloseModulePopups : préserver les handlers
        -- enregistrés par les plugins chargés avant (ex. AltViewerLog_GuildeLog).
        -- Un écrasement simple débrancherait silencieusement leurs callbacks.
        local _prevModuleClose = core.CloseModulePopups
        core.CloseModulePopups = function()
            if _prevModuleClose then _prevModuleClose() end
            if pluginNs.CloseActiveDropdown        then pluginNs.CloseActiveDropdown() end
            if pluginNs.CloseExpansionFilterPopup  then pluginNs.CloseExpansionFilterPopup() end
            if pluginNs.CloseProfessionFilterPopup then pluginNs.CloseProfessionFilterPopup() end
        end

        -- Hooker ClearContent : appelé par TOUTES les vues à chaque changement d'onglet.
        -- Ferme les popups si on quitte la vue Métiers (isViewActive=false).
        -- Ne remet PAS isViewActive à false ici : ShowProfessions() l'a mis à true
        -- juste avant d'appeler ClearContent pour un rafraîchissement interne.
        -- Le remettre à false ici casserait la détection "je suis encore actif"
        -- lors du retour des popups ON/OFF métiers.
        local _origClearContent = core.ClearContent
        core.ClearContent = function(...)
            if not pluginNs._refreshing then
                -- Navigation réelle vers un autre onglet : fermer les popups et désactiver la vue
                pluginNs.isViewActive = false
                if pluginNs.CloseExpansionFilterPopup  then pluginNs.CloseExpansionFilterPopup() end
                if pluginNs.CloseProfessionFilterPopup then pluginNs.CloseProfessionFilterPopup() end
            end
            -- Si _refreshing=true : ShowProfessions() se rafraîchit, on ne touche à rien
            return _origClearContent(...)
        end
    end
end

-- ====================================================
-- SLASH COMMANDS
-- ====================================================
SLASH_AVLPROF1 = "/avlprof"
SlashCmdList["AVLPROF"] = function(msg)
    msg = msg and strtrim(msg:lower()) or ""
    if msg == "scan" then
        pluginNs.ScanAllProfessions()
    elseif msg == "show" then
        pluginNs.isViewActive = true
        pluginNs.ShowProfessions()
        if core.mainFrame then core.mainFrame:Show() end
    else
        core.DBG("|cff00ff00[AVL-Prof]|r " .. pluginNs.L("DBG_HELP"))
    end
end

-- ── Enregistrement de la section Settings ────────────────────────
-- Injecte les options Métiers dans le panneau Paramètres de AltViewerLog.
-- Appel synchrone : ui/Settings.lua de AltViewerLog (qui définit
-- RegisterSettingsSection) est chargé avant Init.lua de ce plugin,
-- car AltViewerLog est une dépendance déclarée dans notre .toc.
if core.RegisterSettingsSection then
    core.RegisterSettingsSection(function(scrollChild, y)
        if pluginNs.InjectProfSettings then
            return pluginNs.InjectProfSettings(scrollChild, y)
        end
        return y
    end)
end

