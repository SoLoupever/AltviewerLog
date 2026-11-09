local addonName, ns = ...

-- ====================================================
-- CORE/EVENTS — init au login + rafraîchissement de la vue courante
-- Les événements propres aux vues (temps joué, or, banque de
-- bataillon, scan métiers) sont gérés par la dépendance concernée.
-- ====================================================

local eventFrame = CreateFrame("Frame", "AVL_CoreEventFrame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event)
    ns.player = UnitName("player")
    ns.realm  = GetRealmName()

    if event == "PLAYER_LOGIN" then
        AltViewerLogDB.settings = AltViewerLogDB.settings or {}
        AltViewerLogDB.minimap  = AltViewerLogDB.minimap or {}

        ns.InitMinimap()
        if ns.mainFrame then
            ns.mainFrame:SetSize(
                AltViewerLogDB.settings.frameWidth  or 900,
                AltViewerLogDB.settings.frameHeight or 600)
        end

        -- Avertissement si ViewerLog n'est pas détecté
        C_Timer.After(3, function()
            if not ns.DP_IsReady() then
                print("|cffff9900" .. ns.L("EVENTS_VL_MISSING_1") .. "|r")
                print("|cffff9900" .. ns.L("EVENTS_VL_MISSING_2") .. "|r")
            else
                ns.DBG("|cff66ff66[AltViewerLog]|r " .. ns.DP_GetStatusText())
            end
        end)

    else -- PLAYER_ENTERING_WORLD
        C_Timer.After(5, function()
            if ns.mainFrame and ns.mainFrame:IsShown() and ns.currentView then
                ns.currentView()
            end
        end)
    end
end)
