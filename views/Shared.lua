local addonName, ns = ...

-- ====================================================
-- VIEWS — Utilitaires partagés par toutes les vues
-- Rôle UNIQUE : fournir les helpers, pools de frames,
-- et la catégorisation Blizzard.
--
-- Ce qui vivait ici et a été extrait :
--   ShowBags()        → ViewBags.lua
--   DrawBagsByCategory → Categories.lua ; panneau → CategoryManager.lua
--   ShowSettings()    → Settings.lua
-- ====================================================

local GetItemClassInfo    = GetItemClassInfo
local GetItemSubClassInfo = GetItemSubClassInfo
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
local GetItemInfoInstant = GetItemInfoInstant
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

    local _, itemType, itemSubType, itemEquipLoc, _, classID, subClassID = GetItemInfoInstant(itemID)
    if not classID then return nil end

    local key, label

    if SPLIT_AT_SUBCLASS[classID] and subClassID and subClassID >= 1 then
        key   = "B_"..classID.."_"..subClassID
        local apiStr = (itemSubType and itemSubType ~= "") and itemSubType
                       or GetItemSubClassInfo(classID, subClassID)
        label = AVL_TranslateCat(classID, subClassID, apiStr)
    elseif HOUSING_CLASS[classID] then
        key   = "B_HOUSING"
        local apiStr = (itemType and itemType ~= "") and itemType
                       or GetItemClassInfo(classID)
        label = AVL_TranslateCat(classID, nil, apiStr)
    else
        key   = "B_"..classID
        local apiStr = (itemType and itemType ~= "") and itemType
                       or GetItemClassInfo(classID)
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

-- ── Sélection / déselection ──────────────────────────────────────
local AVL_selected = nil
local function AVL_Deselect() AVL_selected = nil; ns.AVL_selected = nil end
ns.AVL_GetSelected = function() return AVL_selected end
ns.AVL_Deselect    = AVL_Deselect

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

-- ── Pool de frames ────────────────────────────────────────────────
local btnPool      = {}
local activeFrames = {}

local _GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local iconCache = {}
local function GetIcon(id)
    if not iconCache[id] then iconCache[id] = _GetItemIcon(id) end
    return iconCache[id]
end
ns.GetIcon = GetIcon

local function AcquireButton(parent)
    local f = table.remove(btnPool)
    if f then
        f:SetParent(parent); f:ClearAllPoints()
    else
        f = CreateFrame("Button", nil, parent)
        f.ico = f:CreateTexture(nil, "BACKGROUND"); f.ico:SetAllPoints()
        f.countText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        f.countText:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    f:Show()
    table.insert(activeFrames, { f=f, pool=btnPool })
    return f
end
ns.AcquireButton = AcquireButton

local function ReleaseActiveFrames()
    for _, entry in ipairs(activeFrames) do
        local f = entry.f
        f:Hide()
        f:SetScript("OnClick",  nil)
        f:SetScript("OnEnter",  nil)
        f:SetScript("OnLeave",  nil)
        if ns.CatDnD then ns.CatDnD.Detach(f) end
        table.insert(entry.pool, f)
    end
    activeFrames = {}
end

-- ── ClearContent ──────────────────────────────────────────────────
function ns.ClearContent()
    if not ns.scrollChild then return end
    AVL_Deselect()
    ReleaseActiveFrames()
    if ns.CatDnD then ns.CatDnD.ReleaseFor(ns.scrollChild) end

    local regions = { ns.scrollChild:GetRegions() }
    for _, r in ipairs(regions) do if r.Hide then r:Hide() end end

    local children = { ns.scrollChild:GetChildren() }
    for _, c in ipairs(children) do c:Hide() end

    ns.scrollChild:SetHeight(1)
end

-- ── Sélecteur de personnage partagé ──────────────────────────────
local charSelMenu = CreateFrame("Frame", "AVL_CharSelMenu", UIParent, "BackdropTemplate")
charSelMenu:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
charSelMenu:SetBackdropColor(0.08, 0.08, 0.12, 0.97)
charSelMenu:SetBackdropBorderColor(0.45, 0.45, 0.6, 1)
charSelMenu:SetFrameStrata("TOOLTIP")
charSelMenu:SetClampedToScreen(true)
charSelMenu:EnableMouse(true)
charSelMenu:Hide()
charSelMenu.btns = {}
ns.charSelMenu = charSelMenu

local function OpenCharSelector(anchor, onSelect)
    local chars = {}
    -- Utilise le DataProvider pour lire ViewerLogDB (source unique des données perso)
    -- AltViewerLogDB ne contient plus d'entrées realm/perso depuis la migration.
    if ns.DP_IsReady() then
        ns.DP_IterateChars(function(realmName, charName, data)
            if data.class then
                chars[#chars+1] = { name=charName, realm=realmName, class=data.class }
            end
        end)
    end
    table.sort(chars, function(a,b)
        if a.realm ~= b.realm then return a.realm < b.realm end
        return a.name < b.name
    end)

    for _, b in ipairs(charSelMenu.btns) do b:Hide() end

    -- Grouper par realm
    local realmOrder, realmChars = {}, {}
    for _, char in ipairs(chars) do
        if not realmChars[char.realm] then
            realmChars[char.realm] = {}
            table.insert(realmOrder, char.realm)
        end
        table.insert(realmChars[char.realm], char)
    end

    -- Construire la liste aplatie avec séparateurs de realm
    local rows = {}   -- { type="realm"|"char", label, name, realm, class }
    for _, realm in ipairs(realmOrder) do
        table.insert(rows, { type="realm", label=realm })
        for _, char in ipairs(realmChars[realm]) do
            table.insert(rows, { type="char", name=char.name, realm=char.realm, class=char.class })
        end
    end

    local BTN_H    = 20
    local SEP_H    = 18
    local MAX_ROWS = 22   -- lignes par colonne (80 persos → ~3-4 colonnes)
    local MENU_W_COL = 210

    -- Calculer la hauteur totale par colonne pour le layout
    local colRows = {}  -- hauteur (en pixels) de chaque colonne
    local curColH = 0
    local colCount = 1
    for _, row in ipairs(rows) do
        local h = (row.type == "realm") and SEP_H or BTN_H
        if curColH + h > MAX_ROWS * BTN_H and curColH > 0 then
            table.insert(colRows, curColH)
            curColH = 0
            colCount = colCount + 1
        end
        curColH = curColH + h
    end
    table.insert(colRows, curColH)

    local MENU_W   = MENU_W_COL * colCount + (colCount - 1) * 2
    local MENU_H   = 0
    for _, h in ipairs(colRows) do MENU_H = math.max(MENU_H, h) end
    MENU_H = MENU_H + 6

    -- Générer les widgets
    for i, row in ipairs(rows) do
        local btn = charSelMenu.btns[i]
        if not btn then
            btn = CreateFrame("Button", nil, charSelMenu)
            btn.bg  = btn:CreateTexture(nil, "BACKGROUND"); btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0, 0, 0, 0)
            btn.fs  = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
            charSelMenu.btns[i] = btn
        end
        -- Effacer scripts précédents
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
        btn:SetScript("OnClick", nil)

        if row.type == "realm" then
            btn:SetSize(MENU_W_COL - 4, SEP_H)
            btn.fs:SetText("|cffffff00" .. row.label .. "|r")
            btn.bg:SetColorTexture(0.08, 0.06, 0.02, 1)
        else
            local c = RAID_CLASS_COLORS[row.class] or {r=1,g=1,b=1}
            btn:SetSize(MENU_W_COL - 4, BTN_H)
            btn.fs:SetText(string.format("|cff%02x%02x%02x%s|r",
                math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), row.name))
            btn:SetScript("OnEnter", function(s) s.bg:SetColorTexture(0.25, 0.35, 0.55, 0.9) end)
            btn:SetScript("OnLeave", function(s) s.bg:SetColorTexture(0, 0, 0, 0) end)
            local cn, cr = row.name, row.realm
            btn:SetScript("OnClick", function()
                charSelMenu:Hide(); onSelect(cn, cr)
            end)
        end
        btn:Show()
    end

    -- Positionner les widgets en colonnes
    local colIdx, posY = 0, 3
    for i, row in ipairs(rows) do
        local btn = charSelMenu.btns[i]
        local h = (row.type == "realm") and SEP_H or BTN_H
        if posY + h > MENU_H - 6 + 12 and i > 1 then
            colIdx = colIdx + 1; posY = 3
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 2 + colIdx * MENU_W_COL, -posY)
        posY = posY + h
    end

    charSelMenu:SetSize(MENU_W, MENU_H)
    charSelMenu:ClearAllPoints()
    charSelMenu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    charSelMenu:Show()
    do
        local _elapsed = 0
        charSelMenu:SetScript("OnUpdate", function(self, dt)
            _elapsed = _elapsed + dt
            if _elapsed < 0.05 then return end
            _elapsed = 0
            if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
            and not self:IsMouseOver() then self:Hide() end
        end)
    end
end
ns.OpenCharSelector = OpenCharSelector

-- ── Catégories de filtre (initialisées au PLAYER_LOGIN) ──────────
ns.FILTER_CATS  = {}
ns.activeFilterCat = nil

local function AVL_InitFilterCats()
    ns.FILTER_CATS = {
        { key="ALL",           label=ns.L("FILTER_ALL"),         classID=nil, subClassID=nil, invType=nil },
        { key="CONSOMABLE",    label=ns.L("FILTER_CONSUMABLE"),  classID=0,   subClassID=nil, invType=nil },
        { key="ARME",          label=ns.L("FILTER_WEAPON"),      classID=2,   subClassID=nil, invType=nil },
        { key="ARMURE",        label=ns.L("FILTER_ARMOR"),       classID=4,   subClassID=nil, invType=nil },
        { key="ARMURE_TISSU",  label=ns.L("FILTER_CLOTH"),       classID=4,   subClassID=1,   invType=nil },
        { key="ARMURE_CUIR",   label=ns.L("FILTER_LEATHER"),     classID=4,   subClassID=2,   invType=nil },
        { key="ARMURE_MAILLE", label=ns.L("FILTER_MAIL"),        classID=4,   subClassID=3,   invType=nil },
        { key="ARMURE_PLAQUE", label=ns.L("FILTER_PLATE"),       classID=4,   subClassID=4,   invType=nil },
        { key="TETE",          label=ns.L("FILTER_HEAD"),        classID=nil, subClassID=nil, invType="INVTYPE_HEAD" },
        { key="DOS",           label=ns.L("FILTER_CLOAK"),       classID=nil, subClassID=nil, invType="INVTYPE_CLOAK" },
        { key="QUETE",         label=ns.L("FILTER_QUEST"),       classID=12,  subClassID=nil, invType=nil },
        { key="REACTIF",       label=ns.L("FILTER_REAGENT"),     classID=5,   subClassID=nil, invType=nil },
    }
end
ns.AVL_InitFilterCats = AVL_InitFilterCats
