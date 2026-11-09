local addonName, ns = ...

-- ====================================================
-- VIEWS — Utilitaires partagés par toutes les vues
-- Rôle UNIQUE : helpers partagés (ClearContent, icônes, temps)
-- et catégorisation Blizzard.
--
-- Pool de boutons, sélection, filtres de recherche et vues
-- (sacs, banque…) : dépendance AltViewerLog_Inventory.
-- ====================================================

local select              = select
local pairs               = pairs
local ipairs              = ipairs
local type                = type

-- ── Cache catégorie Blizzard ──────────────────────────────────────
-- itemID → { key, label, classID, subClassID, invType }
local AVL_CAT_CACHE = {}
ns.AVL_CAT_CACHE = AVL_CAT_CACHE

local SPLIT_AT_SUBCLASS = { [4]=true, [2]=true }
local HOUSING_CLASS     = { [20]=true }
local GetLocale          = GetLocale

-- Traduit un libellé de catégorie selon la LANGUE DE L'ADDON, pas celle du
-- client. Les chaînes de l'API WoW (itemType / GetItemClassInfo…) sont
-- toujours renvoyées dans la langue du client : si l'addon est réglé sur
-- une autre langue, le libellé restait dans la langue du client. On passe
-- donc par la table de traduction (clés stables ICAT_<class> /
-- ICATSUB_<class>_<sub>). Quand langue addon == langue client, la chaîne de
-- l'API fait foi (aucune régression, pas de traduction approximative).
local function AVL_TranslateCat(classID, subClassID, apiStr)
    local lang = (AltViewerLogDB.settings and AltViewerLogDB.settings.lang) or GetLocale()
    if lang == GetLocale() and apiStr and apiStr ~= "" then
        return apiStr
    end
    local key = subClassID and ("ICATSUB_%d_%d"):format(classID, subClassID)
                           or  ("ICAT_%d"):format(classID)
    local t = ns.L(key)
    if t ~= key then return t end                 -- ns.L renvoie la clé telle quelle si absente
    return (apiStr and apiStr ~= "" and apiStr) or ns.L("CAT_AUTRE")
end

local function AVL_GetBlizzardCategory(itemID)
    if AVL_CAT_CACHE[itemID] then return AVL_CAT_CACHE[itemID] end

    local _, itemType, itemSubType, itemEquipLoc, _, classID, subClassID = ns.GetItemInfoInstant(itemID)
    if not classID then return nil end

    local key, label

    if SPLIT_AT_SUBCLASS[classID] and subClassID and subClassID >= 1 then
        key   = "B_"..classID.."_"..subClassID
        local apiStr = (itemSubType and itemSubType ~= "") and itemSubType
                       or ns.GetItemSubClassInfo(classID, subClassID)
        label = AVL_TranslateCat(classID, subClassID, apiStr)
    elseif HOUSING_CLASS[classID] then
        key   = "B_HOUSING"
        local apiStr = (itemType and itemType ~= "") and itemType
                       or ns.GetItemClassInfo(classID)
        label = AVL_TranslateCat(classID, nil, apiStr)
    else
        key   = "B_"..classID
        local apiStr = (itemType and itemType ~= "") and itemType
                       or ns.GetItemClassInfo(classID)
        label = AVL_TranslateCat(classID, nil, apiStr)
    end

    local result = { key=key, label=label, classID=classID, subClassID=subClassID, invType=itemEquipLoc }
    AVL_CAT_CACHE[itemID] = result
    return result
end
ns.AVL_GetBlizzardCategory = AVL_GetBlizzardCategory

-- ── Clés non-realm dans AltViewerLogDB ───────────────────────────
local IGNORED_KEYS = {
    minimap=true, settings=true, warbandBank=true,
    profFileIDs=true, disable2DPreview=true,
    warbandCustomCategories=true, woodPanelEnabled=true,
    hiddenExpansions=true, hiddenProfessions=true, warbandGold=true,
    warbandCatStore=true, guildCatStore=true,
}
ns.IGNORED_KEYS = IGNORED_KEYS

local function IsRealm(k, v)
    return not IGNORED_KEYS[k] and type(v) == "table"
end
ns.IsRealm = IsRealm

-- ── Formatage du temps ────────────────────────────────────────────
function ns.FormatTime(totalSeconds)
    if not totalSeconds or totalSeconds <= 0 then return "0m" end
    local d = math.floor(totalSeconds / 86400)
    local h = math.floor((totalSeconds % 86400) / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    local dayLabel = (ns.L("TIME_FORMAT"):find("j")) and "j" or "d"
    if d > 0 then
        return string.format("%d%s %dh %dm", d, dayLabel, h, m)
    elseif h > 0 then
        return string.format("%dh %dm", h, m)
    else
        return string.format("%dm", m)
    end
end

-- ── Icônes (cache) ────────────────────────────────────────────────
local _GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local iconCache = {}
local function GetIcon(id)
    if not iconCache[id] then iconCache[id] = _GetItemIcon(id) end
    return iconCache[id]
end
ns.GetIcon = GetIcon

-- ── ClearContent ──────────────────────────────────────────────────
-- Les dépendances enregistrent leur nettoyage (pools, sélection…)
-- via ns.RegisterContentCleaner ; appelés avant le masquage.
local cleaners = {}

function ns.RegisterContentCleaner(fn)
    if type(fn) == "function" then cleaners[#cleaners + 1] = fn end
end

function ns.ClearContent()
    if not ns.scrollChild then return end
    for _, fn in ipairs(cleaners) do fn() end
    if ns.CatDnD then ns.CatDnD.ReleaseFor(ns.scrollChild) end

    local regions = { ns.scrollChild:GetRegions() }
    for _, r in ipairs(regions) do if r.Hide then r:Hide() end end

    local children = { ns.scrollChild:GetChildren() }
    for _, c in ipairs(children) do c:Hide() end

    ns.scrollChild:SetHeight(1)
end
