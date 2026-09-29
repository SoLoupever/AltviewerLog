local addonName, ns = ...

-- ============================================================
-- DATA PROVIDER
-- Couche d'accès aux données d'inventaire stockées par ViewerLog.
-- AltViewerLog est un addon d'affichage : il ne scanne rien
-- lui-même. Toutes ses vues passent par ce module.
--
-- Prérequis : l'addon ViewerLog doit être actif.
-- ============================================================

-- Version du contrat d'API ViewerLog (ns.API_VERSION côté ViewerLog)
-- à laquelle cette version de AltViewerLog a été développée/testée.
-- Si ViewerLog expose une version inférieure (build trop ancien)
-- ou n'expose pas API_VERSION du tout (ancien ViewerLog non
-- versionné), DP_IsReady() bascule en mode dégradé plutôt que de
-- laisser un appel à une fonction renommée/supprimée planter en
-- pleine partie. À relever si l'on commence sciemment à dépendre
-- d'une nouvelle version du contrat d'API de ViewerLog.
local REQUIRED_VL_API_VERSION = 1

-- ── État ─────────────────────────────────────────────────────────

-- Retourne true si ViewerLog est chargé, prêt, ET expose une
-- version d'API compatible avec celle attendue par AltViewerLog.
function ns.DP_IsReady()
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not _G.ViewerLogDB then return false end
    local vlVersion = vlAPI.API_VERSION
    if type(vlVersion) ~= "number" or vlVersion < REQUIRED_VL_API_VERSION then
        return false
    end
    return true
end

-- Indique pourquoi DP_IsReady() a échoué, pour affichage diagnostic
-- (barre du bas, /bvl debug). Distingue "ViewerLog absent" de
-- "ViewerLog présent mais incompatible", deux situations qui
-- demandent des actions différentes de l'utilisateur.
function ns.DP_GetUnreadyReason()
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not _G.ViewerLogDB then
        return "MISSING"
    end
    local vlVersion = vlAPI.API_VERSION
    if type(vlVersion) ~= "number" or vlVersion < REQUIRED_VL_API_VERSION then
        return "OUTDATED"
    end
    return nil
end

-- ── Accès aux personnages ─────────────────────────────────────────

-- Une entrée peut être une simple coquille vide ({}) sans jamais avoir
-- été réellement scannée : le pattern "table[x] = table[x] or {}"
-- utilisé par ViewerLog (GetCurrentCharData et consorts) recrée une
-- table dès que n'importe quel handler d'événement s'exécute — y
-- compris juste après une suppression manuelle du personnage
-- actuellement connecté (ViewerLog > Characters > Delete). Sans ce
-- filtre, ça affichait une ligne "personnage" fantôme : nom en blanc,
-- Lv0, ilvl 0, 0 or. data.class est renseigné dès le tout premier
-- scan réel (ScanCharacterMeta) et jamais effacé ensuite, donc c'est
-- un signal fiable de "ce personnage a vraiment été scanné au moins
-- une fois".
local function IsValidCharEntry(charData)
    return charData.class ~= nil
end

-- Retourne la liste { {realm, char, data}, ... } de tous les personnages.
function ns.DP_GetAllChars()
    if not ns.DP_IsReady() then return {} end

    local result = {}
    for realmName, realmData in pairs(ViewerLogDB) do
        if ViewerLogAPI.IsRealm(realmName, realmData) then
            for charName, charData in pairs(realmData) do
                if type(charData) == "table" and IsValidCharEntry(charData) then
                    result[#result + 1] = {
                        realm = realmName,
                        char  = charName,
                        data  = charData,
                    }
                end
            end
        end
    end
    return result
end

-- Retourne les données d'un personnage spécifique.
function ns.DP_GetCharData(realmName, charName)
    if not ns.DP_IsReady() then return nil end
    return ViewerLogDB[realmName] and ViewerLogDB[realmName][charName]
end

-- Itère tous les personnages via un callback cb(realm, char, data).
function ns.DP_IterateChars(cb)
    if not ns.DP_IsReady() then return end
    for realmName, realmData in pairs(ViewerLogDB) do
        if ViewerLogAPI.IsRealm(realmName, realmData) then
            for charName, charData in pairs(realmData) do
                if type(charData) == "table" and IsValidCharEntry(charData) then
                    cb(realmName, charName, charData)
                end
            end
        end
    end
end

-- ── XP de repos ──────────────────────────────────────────────────

-- Point d'entrée UNIQUE pour l'XP de repos : toute vue qui veut
-- l'afficher doit passer par ici plutôt que d'interroger ViewerLogAPI
-- directement, afin que la règle « pas d'XP de repos au niveau max »
-- s'applique uniformément à toutes les vues actuelles et futures
-- (liste de personnages, future fiche détaillée, tooltip, etc.)
-- sans avoir à être dupliquée à chaque nouvel endroit d'affichage.
--
-- Retourne un nombre (0-100) si l'info est pertinente à afficher,
-- ou nil sinon (ViewerLog indisponible, niveau inconnu, ou personnage
-- au niveau maximum — auquel cas maxXP = 0 côté ViewerLog et l'XP de
-- repos n'a plus de sens).
function ns.DP_GetRestedPct(charName, realmName, data)
    if not ns.DP_IsReady() then return nil end

    local charLevel = data and data.level or 0
    if charLevel <= 0 or charLevel >= GetMaxPlayerLevel() then
        return nil
    end

    local vlAPI = _G.ViewerLogAPI
    if vlAPI.GetEstimatedRestedPct then
        return vlAPI.GetEstimatedRestedPct(charName, realmName)
    elseif data and data.rested and vlAPI.EstimateRestedPct then
        return vlAPI.EstimateRestedPct(data.rested, data.maxXP)
    end
    return nil
end

-- ── Banque de bataillon ───────────────────────────────────────────

function ns.DP_GetWarbandBank()
    if not ns.DP_IsReady() then return nil end
    return ViewerLogDB.warbandBank
end

function ns.DP_GetWarbandGold()
    if not ns.DP_IsReady() then return 0 end
    return ViewerLogDB.warbandGold or 0
end

-- ── Settings & catégories ─────────────────────────────────────────

-- Les paramètres de AltViewerLog restent dans AltViewerLogDB.
function ns.DP_GetSettings()
    return AltViewerLogDB.settings
end

-- Les catégories personnalisées de la warband sont propres à
-- l'interface de AltViewerLog.
function ns.DP_GetWarbandCustomCategories()
    AltViewerLogDB.warbandCustomCategories =
        AltViewerLogDB.warbandCustomCategories or {}
    return AltViewerLogDB.warbandCustomCategories
end

-- ── Diagnostic ───────────────────────────────────────────────────

-- Retourne un texte d'état lisible (pour la barre du bas ou les logs).
function ns.DP_GetStatusText()
    local reason = ns.DP_GetUnreadyReason()
    if not reason then
        return "|cff66ff66" .. ns.L("STATUS_VL_ACTIVE") .. "|r"
    elseif reason == "OUTDATED" then
        return "|cffff9900" .. ns.L("STATUS_VL_OUTDATED") .. "|r"
    end
    return "|cffff9900" .. ns.L("STATUS_VL_MISSING") .. "|r"
end
