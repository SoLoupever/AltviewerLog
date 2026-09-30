local addonName, ns = ...

-- ====================================================
-- ALTVIEWERLOG — EVENTS (v2 — sans scans d'inventaire)
-- Les scans de sacs, banque et warband sont désormais
-- gérés par ViewerLog (ou Syndicator).
-- BVL s'occupe uniquement de :
--   · Initialisation des settings
--   · Mise à jour de l'UI quand les données changent
--   · Scan de l'équipement (pour la vue Gear)
-- ====================================================

local eventFrame = CreateFrame("Frame", "AVL_CoreEventFrame")

-- Callback enregistré sur ViewerLog : rafraîchit la liste de personnages
-- chaque fois que ScanBasicProfessions() écrit de nouvelles données
-- (SKILL_LINES_CHANGED, /vl scan). Ne s'exécute que si la fenêtre est
-- ouverte sur la vue liste — pas de travail inutile sinon.
local function OnVLProfessionsScanned()
    if ns.mainFrame and ns.mainFrame:IsShown()
    and ns.currentView == ns.RefreshCharacterList then
        ns.RefreshCharacterList()
    end
end

-- L'enregistrement se fait après PLAYER_LOGIN car ViewerLogAPI peut
-- ne pas encore être exposé au moment du chargement du fichier.
--
-- Depuis ViewerLog v1.2, le mécanisme privilégié est RegisterProfessionsCallback
-- (multi-listener). L'ancienne assignation directe `vlAPI.OnProfessionsScanned = fn`
-- n'est conservée qu'en fallback pour les versions antérieures de ViewerLog.
local _profCallbackRegistered = false
local function TryRegisterProfCallback()
    if _profCallbackRegistered then return end
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI then return end
    if vlAPI.RegisterProfessionsCallback then
        -- Nouveau système multi-listener (ViewerLog >= 1.2)
        vlAPI.RegisterProfessionsCallback(OnVLProfessionsScanned)
    else
        -- Fallback single-listener pour les anciennes versions
        vlAPI.OnProfessionsScanned = OnVLProfessionsScanned
    end
    _profCallbackRegistered = true
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("TIME_PLAYED_MSG")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("ACCOUNT_MONEY")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

eventFrame:SetScript("OnEvent", function(self, event, ...)

    if event == "PLAYER_LOGIN" then
        ns.player = UnitName("player")
        ns.realm  = GetRealmName()

        AltViewerLogDB.settings = AltViewerLogDB.settings or {}
        if AltViewerLogDB.settings.sortByPop == nil then
            AltViewerLogDB.settings.sortByPop = false
        end
        AltViewerLogDB.minimap = AltViewerLogDB.minimap or {}

        ns.InitMinimap()
        if ns.mainFrame then
            ns.mainFrame:SetSize(
                AltViewerLogDB.settings.frameWidth  or 900,
                AltViewerLogDB.settings.frameHeight or 600)
        end

        TryRegisterProfCallback()

        -- Avertissement si ViewerLog n'est pas détecté
        C_Timer.After(3, function()
            if not ns.DP_IsReady() then
                print("|cffff9900" .. ns.L("EVENTS_VL_MISSING_1") .. "|r")
                print("|cffff9900" .. ns.L("EVENTS_VL_MISSING_2") .. "|r")
            else
                ns.DBG("|cff66ff66[AltViewerLog]|r " .. ns.DP_GetStatusText())
            end
        end)

        -- ViewerLog scanne les métiers à +8 s. On rafraîchit la liste des
        -- personnages à +10 s pour que les icônes de métiers apparaissent
        -- si la fenêtre est déjà ouverte. Sans ce timer, PLAYER_ENTERING_WORLD
        -- (+5 s) rafraîchirait la liste AVANT que ViewerLog ait écrit les données.
        C_Timer.After(10, function()
            if ns.mainFrame and ns.mainFrame:IsShown()
            and ns.currentView == ns.RefreshCharacterList then
                ns.RefreshCharacterList()
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.player = UnitName("player")
        ns.realm  = GetRealmName()
        -- Rafraîchir l'UI si elle est ouverte
        C_Timer.After(5, function()
            if ns.mainFrame and ns.mainFrame:IsShown() and ns.currentView then
                ns.currentView()
            end
        end)

    elseif event == "TIME_PLAYED_MSG" then
        -- Données gérées par ViewerLog — rafraîchit l'UI si la liste perso est visible
        if ns.mainFrame and ns.mainFrame:IsShown()
        and ns.currentView == ns.RefreshCharacterList then
            ns.RefreshCharacterList()
        end

    elseif event == "PLAYER_MONEY" then
        -- Mise à jour de la barre du bas
        if ns.UpdateBottomBar then ns.UpdateBottomBar() end

    elseif event == "ACCOUNT_MONEY" then
        -- Or banque de bataillon — mis à jour par ViewerLog
        if ns.UpdateBottomBar then ns.UpdateBottomBar() end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.AccountBank then
            -- L'UI de la banque de bataillon dans BVL
            if ns.OnWarbandBankOpened then ns.OnWarbandBankOpened() end
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.AccountBank then
            if ns.OnWarbandBankClosed then ns.OnWarbandBankClosed() end
            -- Rafraîchir la vue warband si ouverte
            if ns.mainFrame and ns.mainFrame:IsShown()
            and ns.currentView == ns.ShowWarbandBank then
                ns.ShowWarbandBank()
            end
        end
    end
end)
