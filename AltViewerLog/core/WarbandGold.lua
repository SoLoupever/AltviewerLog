local addonName, ns = ...

-- ====================================================
-- CORE/WARBANDGOLD — État banque bataillon
--
-- Ce fichier ne fait QUE gérer l'état ouvert/fermé et
-- persister l'or dans AltViewerLogDB.warbandGold.
-- La LECTURE pour l'affichage est faite par BottomBar
-- via sa fonction locale ReadWarbandGold() qui appelle
-- directement C_Bank.FetchDepositedMoney — comme
-- en appelant directement C_Bank.FetchDepositedMoney.
--
-- API publique :
--   ns.IsWarbandBankOpen()        → bool
--   ns.WarbandOpenedThisSession() → bool
--   ns.OnWarbandBankOpened()      → appelé par Events.lua
--   ns.OnWarbandBankClosed()      → appelé par Events.lua
--   ns.GetWarbandGold()           → (live, isCached)
-- ====================================================

local _isOpen            = false
local _openedThisSession = false

function ns.IsWarbandBankOpen()
    return _isOpen
end

function ns.WarbandOpenedThisSession()
    return _openedThisSession
end

function ns.OnWarbandBankOpened()
    _isOpen            = true
    _openedThisSession = true
    -- Persister immédiatement + une seconde passe (cache parfois pas encore peuplé)
    if C_Bank and C_Bank.FetchDepositedMoney and AltViewerLogDB then
        local live = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
        AltViewerLogDB.warbandGold = live
    end
    C_Timer.After(0.8, function()
        if _isOpen and C_Bank and C_Bank.FetchDepositedMoney and AltViewerLogDB then
            local live = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
            AltViewerLogDB.warbandGold = live
            if ns.UpdateBottomBar then ns.UpdateBottomBar() end
        end
    end)
    if ns.UpdateBottomBar then ns.UpdateBottomBar() end
end

function ns.OnWarbandBankClosed()
    -- Lecture finale avant fermeture : cache encore chaud
    if C_Bank and C_Bank.FetchDepositedMoney and AltViewerLogDB then
        local live = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
        AltViewerLogDB.warbandGold = live
    end
    C_Timer.After(0.3, function()
        _isOpen = false
        if ns.UpdateBottomBar then ns.UpdateBottomBar() end
    end)
end

-- Conservé pour compatibilité avec les éventuels appels externes.
-- N'appelle PAS ns.UpdateBottomBar — laisse l'appelant le faire.
-- IMPORTANT : ne persiste dans la DB que si la valeur est fiable, c.-à-d. :
--   · banque ouverte cette session (live = vérité absolue), OU
--   · live > 0 (l'API a renvoyé une vraie valeur même hors banque ouverte).
-- Sans ce garde, un appel à froid (banque jamais ouverte) écrase la valeur
-- sauvegardée de la session précédente avec 0.
function ns.GetWarbandGold()
    local live = 0
    if C_Bank and C_Bank.FetchDepositedMoney then
        live = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
    end
    if AltViewerLogDB and (_openedThisSession or live > 0) then
        AltViewerLogDB.warbandGold = live
    end
    return live, not _openedThisSession
end

