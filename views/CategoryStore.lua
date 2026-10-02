local addonName, ns = ...

-- ====================================================
-- CATEGORY STORE — moteur de données des catégories
-- Rôle UNIQUE : stocker / résoudre / ordonner les catégories.
-- Aucun widget ici : l'UI (CategoryManager) et le drag&drop
-- (CategoryDnD) passent par cette API, les vues aussi.
--
-- Un "store" = table { customCategories, catOrder, pins } :
--   · sacs / banque : la table data du personnage (inchangé)
--   · bataillon     : Cat.GetStore("warband")
--   · guilde        : Cat.GetStore("guild")
-- customCategories[nom] = { items = { [itemID]=true } }
-- pins[itemID]          = clé de catégorie Blizzard forcée
-- ====================================================

local Cat = {}
ns.Cat = Cat

local PREFIX   = "__c__"
local MAX_NAME = 30
local CUSTOM_COLOR = "|cffffff00"

function Cat.IsCustomKey(key) return key:sub(1, #PREFIX) == PREFIX end
function Cat.CustomKey(name)  return PREFIX .. name end
function Cat.CustomName(key)  return key:sub(#PREFIX + 1) end

function Cat.Ensure(store)
    store.customCategories = store.customCategories or {}
    store.catOrder         = store.catOrder or {}
    store.pins             = store.pins or {}
    return store
end

-- Stores hors personnage (AltViewerLogDB : préférences d'interface).
function Cat.GetStore(scope)
    local db = AltViewerLogDB
    if scope == "warband" then
        db.warbandCatStore = db.warbandCatStore or {}
        local s = db.warbandCatStore
        -- même table que DP_GetWarbandCustomCategories : compat totale
        s.customCategories = ns.DP_GetWarbandCustomCategories()
        return Cat.Ensure(s)
    elseif scope == "guild" then
        db.guildCatStore = db.guildCatStore or {}
        return Cat.Ensure(db.guildCatStore)
    end
end

-- ── Libellés ─────────────────────────────────────────────────────
local labelByKey = {}

function Cat.LabelForKey(key)
    local l = labelByKey[key]
    if l then return l end
    if key == "B_AUTRE" then return ns.L("CAT_AUTRE") end
    for _, ci in pairs(ns.AVL_CAT_CACHE or {}) do labelByKey[ci.key] = ci.label end
    return labelByKey[key] or ns.L(key)
end

function Cat.CustomLabel(name) return CUSTOM_COLOR .. name .. "|r" end

-- ── Résolution item → catégorie ──────────────────────────────────
-- Retourne une fonction itemID → key, label, isCustom, name.
-- L'index inverse est construit une seule fois par rendu.
function Cat.NewResolver(store)
    Cat.Ensure(store)
    local toCustom = {}
    for name, cd in pairs(store.customCategories) do
        for id in pairs(cd.items or {}) do toCustom[id] = name end
    end
    local pins = store.pins
    local GetBliz = ns.AVL_GetBlizzardCategory
    return function(itemID)
        local cn = toCustom[itemID]
        if cn then return PREFIX .. cn, Cat.CustomLabel(cn), true, cn end
        local pin = pins[itemID]
        if pin then return pin, Cat.LabelForKey(pin), false, nil end
        local ci = GetBliz(itemID)
        if ci then
            labelByKey[ci.key] = ci.label
            return ci.key, ci.label, false, nil
        end
        return "B_AUTRE", ns.L("CAT_AUTRE"), false, nil
    end
end

local function SortedCustomNames(store)
    local names = {}
    for name in pairs(store.customCategories) do names[#names + 1] = name end
    table.sort(names)
    return names
end

-- slots : liste { id=, count=, link=, ... } → buckets, bucketOrder
-- Toutes les catégories custom existent (même vides) pour pouvoir
-- recevoir un drop.
function Cat.Distribute(store, slots)
    Cat.Ensure(store)
    local resolve = Cat.NewResolver(store)
    local buckets, order = {}, {}
    local function Bucket(key, label, isCustom, name)
        local b = buckets[key]
        if not b then
            b = { label = label, isCustom = isCustom, name = name, items = {} }
            buckets[key] = b
            order[#order + 1] = key
        end
        return b
    end
    for _, name in ipairs(SortedCustomNames(store)) do
        Bucket(PREFIX .. name, Cat.CustomLabel(name), true, name)
    end
    for _, s in ipairs(slots) do
        local key, label, isCustom, name = resolve(s.id)
        local b = Bucket(key, label, isCustom, name)
        b.items[#b.items + 1] = s
    end
    return buckets, order
end

-- Ordre d'affichage : catOrder persisté d'abord, puis le reste.
-- Les catégories Blizzard vides sont ignorées, les custom vides gardées.
function Cat.Order(store, buckets, bucketOrder)
    Cat.Ensure(store)
    local keys, placed = {}, {}
    local function Add(k)
        local b = buckets[k]
        if b and not placed[k] and (b.isCustom or #b.items > 0) then
            keys[#keys + 1] = k; placed[k] = true
        end
    end
    for _, k in ipairs(store.catOrder) do Add(k) end
    for _, k in ipairs(bucketOrder or {}) do Add(k) end
    return keys
end

-- Persiste l'ordre affiché ; conserve les clés absentes de la vue courante.
function Cat.SetOrder(store, keys)
    local seen, new = {}, {}
    for _, k in ipairs(keys) do seen[k] = true; new[#new + 1] = k end
    for _, k in ipairs(store.catOrder or {}) do
        if not seen[k] then new[#new + 1] = k end
    end
    store.catOrder = new
end

-- ── Catégories custom ────────────────────────────────────────────
-- Retourne key | nil, errKeyLocale
function Cat.AddCategory(store, name)
    Cat.Ensure(store)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then return nil, "CATMGR_ERR_EMPTY" end
    name = name:sub(1, MAX_NAME)
    if store.customCategories[name] then return nil, "CATMGR_ERR_EXISTS" end
    store.customCategories[name] = { items = {} }
    return PREFIX .. name
end

function Cat.RemoveCategory(store, name)
    Cat.Ensure(store)
    store.customCategories[name] = nil
    local key, new = PREFIX .. name, {}
    for _, k in ipairs(store.catOrder) do
        if k ~= key then new[#new + 1] = k end
    end
    store.catOrder = new
end

-- ── Assignation d'un item ────────────────────────────────────────
-- key custom  → customCategories[nom].items
-- key Blizzard → pins (sauf si c'est déjà sa catégorie naturelle)
function Cat.Unassign(store, itemID)
    Cat.Ensure(store)
    for _, cd in pairs(store.customCategories) do
        if cd.items then cd.items[itemID] = nil end
    end
    store.pins[itemID] = nil
end

function Cat.Assign(store, itemID, key)
    Cat.Unassign(store, itemID)
    if Cat.IsCustomKey(key) then
        local cd = store.customCategories[Cat.CustomName(key)]
        if not cd then return false end
        cd.items = cd.items or {}
        cd.items[itemID] = true
    else
        local ci = ns.AVL_GetBlizzardCategory(itemID)
        if (ci and ci.key or "B_AUTRE") ~= key then store.pins[itemID] = key end
    end
    return true
end

-- Liste triée des itemID assignés manuellement à une catégorie.
function Cat.ItemsOf(store, key)
    Cat.Ensure(store)
    local ids = {}
    if Cat.IsCustomKey(key) then
        local cd = store.customCategories[Cat.CustomName(key)]
        for id in pairs(cd and cd.items or {}) do ids[#ids + 1] = id end
    else
        for id, k in pairs(store.pins) do
            if k == key then ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    return ids
end
