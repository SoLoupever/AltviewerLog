local addonName, ns = ...

-- ====================================================
-- CORE/DEBUG — Système de debug centralisé
-- Rôle UNIQUE : exposer ns.DBG() et AltViewerLogAPI.DBG
-- pour AltViewerLog et toutes ses dépendances.
--
-- Usage dans n'importe quel fichier (core ou dépendance) :
--   local ns = _G.AltViewerLogAPI
--   ns.DBG("[MON-ADDON] message ici")
--
-- Activé/désactivé depuis Paramètres > AltViewerLog.
-- Désactivé par défaut.
-- ====================================================

-- Lecture du flag (DB peut ne pas encore exister au load)
local function IsDebugOn()
    return AltViewerLogDB
        and AltViewerLogDB.settings
        and AltViewerLogDB.settings.debugMode == true
end

-- Point d'entrée unique pour tous les prints de debug.
-- Préfixe automatique |cff888888[AVL Debug]|r si pas déjà coloré.
function ns.DBG(msg)
    if not IsDebugOn() then return end
    local out = tostring(msg or "")
    if out:sub(1, 2) ~= "|c" then
        out = "|cff888888[AVL Debug]|r " .. out
    end
    print(out)
end
