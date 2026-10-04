local addonName, ns = ...

-- ====================================================
-- STUFF & GEAR — Vue équipement par personnage
--  Item:CreateFromItemLink + ContinueOnItemLoad
-- ====================================================

local RARITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
}

-- Noms lisibles des slots — récupérés depuis l'API Blizzard (langue du client)
-- GetEquipmentSlotName(slotName) retourne le label localisé + le slotID.
-- Fallback français au cas où l'API retourne nil (hors-jeu / environnement test).
local _SLOT_LABELS_FALLBACK = {
    HEADSLOT          = ns.L("GEAR_SLOT_1"),
    NECKSLOT          = ns.L("GEAR_SLOT_2"),
    SHOULDERSLOT      = ns.L("GEAR_SLOT_3"),
    BACKSLOT          = ns.L("GEAR_SLOT_15"),
    CHESTSLOT         = ns.L("GEAR_SLOT_5"),
    WRISTSLOT         = ns.L("GEAR_SLOT_9"),
    HANDSSLOT         = ns.L("GEAR_SLOT_10"),
    WAISTSLOT         = ns.L("GEAR_SLOT_6"),
    LEGSSLOT          = ns.L("GEAR_SLOT_7"),
    FEETSLOT          = ns.L("GEAR_SLOT_8"),
    FINGER0SLOT       = ns.L("GEAR_SLOT_11"),
    FINGER1SLOT       = ns.L("GEAR_SLOT_12"),
    TRINKET0SLOT      = ns.L("GEAR_SLOT_13"),
    TRINKET1SLOT      = ns.L("GEAR_SLOT_14"),
    MAINHANDSLOT      = ns.L("GEAR_SLOT_16"),
    SECONDARYHANDSLOT = ns.L("GEAR_SLOT_17"),
}
local SLOT_LABELS = {}
for slotName, fallback in pairs(_SLOT_LABELS_FALLBACK) do
    local label = GetEquipmentSlotName and GetEquipmentSlotName(slotName)
    SLOT_LABELS[slotName] = (label and label ~= "") and label or fallback
end

-- Ordre gauche / droite
local LEFT_SLOTS  = { "HEADSLOT","SHOULDERSLOT","CHESTSLOT","WRISTSLOT","HANDSSLOT","WAISTSLOT","LEGSSLOT","FEETSLOT","MAINHANDSLOT" }
local RIGHT_SLOTS = { "NECKSLOT","BACKSLOT","FINGER0SLOT","FINGER1SLOT","TRINKET0SLOT","TRINKET1SLOT","SECONDARYHANDSLOT" }

local IGNORED_KEYS = {
    minimap=true, settings=true, warbandBank=true,
    profFileIDs=true, disable2DPreview=true,
    warbandCustomCategories=true, woodPanelEnabled=true,
    warbandCatStore=true, guildCatStore=true,
}

local ICON_SIZE  = 42
local COL1_X     = 10
local COL2_X     = 335
local COL_TEXT_W = 250

-- Tooltip caché pour lire le nom de l'enchantement depuis le link.
-- DOIT être appelé après ContinueOnItemLoad (item en cache obligatoire).
local AVL_GearTip
local function GetEnchantNameFromLink(itemString)
    if not itemString then return nil end
    local enchantID = tonumber(itemString:match("^item:%d+:(%d+):"))
    if not enchantID or enchantID == 0 then return nil end

    if not AVL_GearTip then
        AVL_GearTip = CreateFrame("GameTooltip", "AVL_GearScanTip", UIParent, "GameTooltipTemplate")
        AVL_GearTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    AVL_GearTip:ClearLines()
    AVL_GearTip:SetHyperlink(itemString)

    for i = 2, AVL_GearTip:NumLines() do
        local left = _G["AVL_GearScanTipTextLeft"..i]
        if left then
            local txt = left:GetText() or ""
            local name = txt:match("^[^:]+:%s*(.+)$")
            if name and txt:find("nchant") then
                return name
            end
        end
    end
    return nil
end

-- ── Lecture de la structure de l'itemString SANS cache ───────────────
-- Format : item:itemID:enchantID:gem1:gem2:gem3:gem4:...
-- Retourne hasEnchant (bool) + gemIDs (tableau des IDs validés).
-- En TWW, les positions 4-7 peuvent contenir des IDs non-gemmes
-- (réactifs d'artisanat, améliorations de pièce…). On valide
-- chaque ID via GetItemInfoInstant : seul classID == 3 (LE_ITEM_CLASS_GEM)
-- est accepté comme vraie gemme.
local function ParseItemStringStructure(itemString)
    local parts = {}
    for p in itemString:gmatch("[^:]+") do parts[#parts+1] = p end
    -- parts[1]="item"  parts[2]=itemID  parts[3]=enchantID
    -- parts[4..7]=gem1..4 (0 = pas de gemme, >0 = potentiel gemID)
    local hasEnchant = (tonumber(parts[3]) or 0) > 0
    local gemIDs = {}
    for i = 4, 7 do
        local id = tonumber(parts[i]) or 0
        if id > 0 then
            -- GetItemInfoInstant est synchrone : lit le cache statique du client
            -- sans requête réseau. classID 3 = LE_ITEM_CLASS_GEM.
            local _, _, _, _, _, classID = GetItemInfoInstant(id)
            if classID == 3 then
                gemIDs[#gemIDs + 1] = id
            end
        end
    end
    return hasEnchant, gemIDs
end

-- ====================================================
-- RenderSlot — icône + nom + ilvl + enchant + gemmes
-- Tout ce qui nécessite le cache WoW (nom, rareté, enchant, gemmes)
-- est rempli à l'intérieur de ContinueOnItemLoad.
-- La mise en page (positions, hauteur) est calculée depuis la
-- structure de l'itemString, qui ne nécessite aucun cache.
-- ====================================================
local function RenderSlot(slotName, colX, colY, charData, classColor)
    local cc = classColor or { r=0.55, g=0.55, b=0.55 }
    local lblFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblFS:SetPoint("TOPLEFT", colX, colY)
    lblFS:SetTextColor(cc.r, cc.g, cc.b)
    lblFS:SetText(SLOT_LABELS[slotName] or slotName)
    colY = colY - 16

    local itemString = charData.gear and charData.gear[slotName]

    if not itemString then
        local emptyF = CreateFrame("Frame", nil, ns.scrollChild, "BackdropTemplate")
        emptyF:SetSize(ICON_SIZE, ICON_SIZE)
        emptyF:SetPoint("TOPLEFT", colX, colY)
        emptyF:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        emptyF:SetBackdropColor(unpack(ns.Theme.roles.card[1]))
        local emptyFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyFS:SetPoint("LEFT", colX + ICON_SIZE + 6, colY - ICON_SIZE/2 + 6)
        emptyFS:SetTextColor(0.35, 0.35, 0.35)
        emptyFS:SetText("—")
        return colY - ICON_SIZE - 6
    end

    -- ── Détection structure sans cache ─────────────────────────────
    local hasEnchant, gemIDs = ParseItemStringStructure(itemString)
    local gemCount = #gemIDs

    -- ── Icône ──────────────────────────────────────────────────────
    local iconBtn = CreateFrame("Button", nil, ns.scrollChild)
    iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
    iconBtn:SetPoint("TOPLEFT", colX, colY)

    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    local border = CreateFrame("Frame", nil, iconBtn, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

    -- ── Fond texte (taille calculée après les pré-allocations) ─────
    local textBgTex = ns.scrollChild:CreateTexture(nil, "BACKGROUND", nil, -8)
    textBgTex:SetColorTexture(unpack(ns.Theme.roles.card[1]))
    textBgTex:SetPoint("TOPLEFT", colX + ICON_SIZE + 3, colY + 2)
    textBgTex:SetSize(COL_TEXT_W + 2, ICON_SIZE)  -- mis à jour plus bas

    -- ── Nom (rempli async) ─────────────────────────────────────────
    local nameFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("TOPLEFT", colX + ICON_SIZE + 6, colY)
    nameFS:SetWidth(COL_TEXT_W)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetTextColor(0.55, 0.55, 0.55)
    nameFS:SetText("...")

    -- ── ilvl (dispo immédiatement depuis la DB) ────────────────────
    local ilvl = (charData.equipIlvl and charData.equipIlvl[slotName]) or 0
    local ilvlFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlFS:SetPoint("TOPLEFT", colX + ICON_SIZE + 6, colY - 13)
    ilvlFS:SetWidth(COL_TEXT_W)
    ilvlFS:SetJustifyH("LEFT")
    ilvlFS:SetTextColor(0.60, 0.60, 0.60)
    ilvlFS:SetText(ilvl > 0 and ("ilvl " .. ilvl) or "")

    -- ── Pré-allocation enchant + gemmes (positions fixes, noms async) ──
    -- On sait depuis la structure de l'itemString combien de lignes il faut.
    -- Les FontStrings sont créés maintenant (positions correctes),
    -- leurs textes seront remplis dans ContinueOnItemLoad.
    local textY = colY - 27

    local enchantFS = nil
    if hasEnchant then
        enchantFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        enchantFS:SetPoint("TOPLEFT", colX + ICON_SIZE + 6, textY)
        enchantFS:SetWidth(COL_TEXT_W)
        enchantFS:SetJustifyH("LEFT")
        enchantFS:SetTextColor(0.28, 0.85, 0.85)
        enchantFS:SetText("")   -- rempli dans ContinueOnItemLoad
        textY = textY - 13
    end

    local gemFSList = {}
    for _ = 1, gemCount do
        local gemFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        gemFS:SetPoint("TOPLEFT", colX + ICON_SIZE + 6, textY)
        gemFS:SetWidth(COL_TEXT_W)
        gemFS:SetJustifyH("LEFT")
        gemFS:SetTextColor(0.85, 0.50, 0.90)
        gemFS:SetText("")   -- rempli dans ContinueOnItemLoad
        gemFSList[#gemFSList + 1] = gemFS
        textY = textY - 13
    end

    -- textH = hauteur réelle occupée par le texte (nom + ilvl + enchant + gemmes).
    -- Le fond s'adapte à ce contenu (± 3 px de marge haut/bas) plutôt que de
    -- forcer la hauteur de l'icône, ce qui laissait du vide pour les items sans
    -- enchantement ni gemme.
    local textH = math.abs(textY - colY)
    local slotH = math.max(ICON_SIZE, textH) + 8   -- espacement inter-slot inchangé
    textBgTex:SetSize(COL_TEXT_W + 2, textH + 6)   -- fond = contenu + 3 px haut/bas

    -- ── ContinueOnItemLoad : remplit TOUT ce qui nécessite le cache ─
    local item = Item:CreateFromItemLink(itemString)
    item:ContinueOnItemLoad(function()
        -- Icône, nom, rareté
        local itemName, _, itemRarity, _, _, _, _, _, itemEquipLoc, itemTexture = GetItemInfo(itemString)

        -- Garde rétrocompat : données corrompues ou legacy (sac, ammo, misc…)
        -- Le scanner valide désormais à la source, mais des entrées
        -- anciennes peuvent encore exister en SavedVariables.
        local INVALID_EQUIP_LOC = {
            INVTYPE_BAG=true, INVTYPE_QUIVER=true,
            INVTYPE_AMMO=true, INVTYPE_NON_EQUIP_IGNORE=true,
        }
        if not itemEquipLoc or itemEquipLoc == "" or INVALID_EQUIP_LOC[itemEquipLoc] then
            iconBtn:Hide()
            border:Hide()
            textBgTex:Hide()
            nameFS:SetText("|cff888888—|r")
            ilvlFS:SetText("")
            if enchantFS then enchantFS:SetText("") end
            for _, fs in ipairs(gemFSList) do fs:SetText("") end
            return
        end

        if itemTexture then iconTex:SetTexture(itemTexture) end
        if itemName   then nameFS:SetText(itemName) end
        local rc = RARITY_COLORS[itemRarity or 1] or RARITY_COLORS[1]
        nameFS:SetTextColor(rc[1], rc[2], rc[3])
        border:SetBackdropBorderColor(rc[1], rc[2], rc[3], 0.9)

        -- Enchant (item en cache → SetHyperlink retourne des lignes)
        if enchantFS then
            enchantFS:SetText(GetEnchantNameFromLink(itemString) or "")
        end

        -- Gemmes : chargement indépendant par gemID.
        -- GetItemGem() exige que les gemmes soient dans le cache client,
        -- ce qui n'est jamais garanti pour un perso hors-ligne.
        -- On charge chaque gemme individuellement via ContinueOnItemLoad.
        for i, fs in ipairs(gemFSList) do
            local gemID = gemIDs[i]
            if gemID then
                local gemItem = Item:CreateFromItemID(gemID)
                gemItem:ContinueOnItemLoad(function()
                    fs:SetText(GetItemInfo(gemID) or "")
                end)
            end
        end
    end)

    -- ── Tooltip ────────────────────────────────────────────────────
    iconBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemString)
        GameTooltip:Show()
    end)
    iconBtn:SetScript("OnLeave", GameTooltip_Hide)

    return colY - slotH
end

-- ====================================================
-- Séparateur horizontal
-- ====================================================
local function DrawSeparator(y)
    local sep = ns.scrollChild:CreateTexture(nil, "OVERLAY")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  6, y)
    sep:SetPoint("TOPRIGHT", -6, y)
    sep:SetColorTexture(unpack(ns.Theme.roles.card[2]))
end

-- ====================================================
-- ns.ShowGear
-- ====================================================
function ns.ShowGear(selectedChar, selectedRealm)
    ns.currentView       = ns.ShowGear
    ns.currentViewIsBank = false
    ns.ClearContent()
    if ns.scrollFrame then ns.scrollFrame:SetVerticalScroll(0) end
    if not ns.DP_IsReady() then return end

    selectedChar  = selectedChar  or UnitName("player")
    selectedRealm = selectedRealm or GetRealmName()

    local offsetY = -12

    -- Titre
    local titleFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOPLEFT", 10, offsetY)
    titleFS:SetTextColor(unpack(ns.Theme.heading))
    titleFS:SetText("|TInterface\\Icons\\inv_misc_bag_16:18:18:0:0|t  " .. ns.L("GEAR_TITLE"))
    offsetY = offsetY - 32

    -- Sélecteur de personnage (dropdown, comme dans Sacs/Banque)
    local selBtn = CreateFrame("Button", nil, ns.scrollChild, "BackdropTemplate")
    selBtn:SetSize(22, 22)
    selBtn:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", -5, -12)
    ns.Skin.Button(selBtn)
    local selIco = selBtn:CreateTexture(nil, "ARTWORK"); selIco:SetAllPoints()
    selIco:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    selBtn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.L("CHAR_SWITCH_TT"), 1, 1, 1)
        GameTooltip:Show()
    end)
    selBtn:SetScript("OnLeave", function(s)
        GameTooltip:Hide()
    end)
    selBtn:SetScript("OnClick", function(s)
        ns.OpenCharSelector(s, function(newChar, newRealm)
            ns.ShowGear(newChar, newRealm)
        end)
    end)

    -- Afficher le perso sélectionné dans le titre
    local selLabel = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    selLabel:SetPoint("TOPRIGHT", selBtn, "TOPLEFT", -6, -4)
    local selData = ns.DP_GetCharData(selectedRealm, selectedChar)
    local selClass = selData and selData.class
    local selC = selClass and RAID_CLASS_COLORS[selClass] or {r=1,g=1,b=1}
    local selHex = string.format("%02x%02x%02x", math.floor(selC.r*255), math.floor(selC.g*255), math.floor(selC.b*255))
    selLabel:SetTextColor(selC.r, selC.g, selC.b)
    selLabel:SetText(string.format("|cff%s%s|r |cff%s(%s)|r", selHex, selectedChar, selHex, selectedRealm))

    DrawSeparator(offsetY)
    offsetY = offsetY - 18

    -- Données du perso sélectionné
    local charData = ns.DP_GetCharData(selectedRealm, selectedChar)

    if not charData then
        local fs = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 10, offsetY)
        fs:SetTextColor(1, 0.35, 0.35)
        fs:SetText(ns.L("GEAR_NO_CHAR_DATA"))
        ns.scrollChild:SetHeight(math.abs(offsetY) + 80)
        return
    end

    -- En-tête du perso sélectionné
    local isOnline = (selectedChar == UnitName("player") and selectedRealm == GetRealmName())
    local hdrStone = CreateFrame("Button", nil, ns.scrollChild)
    hdrStone:SetSize(28, 28)
    hdrStone:SetPoint("TOPLEFT", 8, offsetY - 1)
    hdrStone:SetNormalAtlas(isOnline and "DungeonStoneCheckpoint" or "DungeonStoneCheckpointDeactivated")
    hdrStone:SetAlpha(isOnline and 1 or 0.45)

    local c = charData.class and RAID_CLASS_COLORS[charData.class] or {r=1,g=1,b=1}
    local cHex = string.format("%02x%02x%02x", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
    local hdrFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdrFS:SetPoint("TOPLEFT", 42, offsetY)
    hdrFS:SetTextColor(c.r, c.g, c.b)
    hdrFS:SetText(string.format("|cff%s%s  — Lv.%d — ilvl %d|r",
        cHex, selectedChar, charData.level or 0, charData.ilvl or 0))
    offsetY = offsetY - 36

    local subFS = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subFS:SetPoint("TOPLEFT", 10, offsetY)
    subFS:SetTextColor(0.7, 0.7, 0.7)
    subFS:SetText(ns.L("GEAR_SUBTITLE"))
    offsetY = offsetY - 20

    DrawSeparator(offsetY)
    offsetY = offsetY - 14

    if not charData.gear or not next(charData.gear) then
        local fs = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 10, offsetY)
        fs:SetWidth(560)
        fs:SetTextColor(0.9, 0.75, 0.2)
        fs:SetText(ns.L("GEAR_NOT_SCANNED"))
        ns.scrollChild:SetHeight(math.abs(offsetY) + 80)
        ns.UpdateBottomBar()
        return
    end

    -- Rendu deux colonnes
    local col1Y, col2Y = offsetY, offsetY

    for _, slotName in ipairs(LEFT_SLOTS) do
        col1Y = RenderSlot(slotName, COL1_X, col1Y, charData, c)
    end
    for _, slotName in ipairs(RIGHT_SLOTS) do
        col2Y = RenderSlot(slotName, COL2_X, col2Y, charData, c)
    end

    ns.scrollChild:SetHeight(math.abs(math.min(col1Y, col2Y)) + 60)
    ns.UpdateBottomBar()
end
