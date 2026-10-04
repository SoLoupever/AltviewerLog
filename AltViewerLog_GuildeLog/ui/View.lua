local addonName, pluginNs = ...

-- ==================================================
-- GUILDE/UI/VIEW — Affichage du coffre de guilde
-- Grille d'icônes façon ShowWarbandBank, sélecteur de
-- guilde à droite, barre d'onglets, tooltip natif WoW.
-- Contient : DrawGuildView, RefreshView, ShowGuildBank
-- ==================================================

local core = _G.AltViewerLogAPI   -- dépendance déclarée dans le .toc

-- ── Thème ────────────────────────────────────────────────────────
-- Couleurs et skin viennent du core (ns.Theme / ns.Skin).
local BLUE = { 0.30, 0.65, 1.00 }   -- titre de la vue (maquette)

function pluginNs.GetThemeBorder()
    return core.Theme.heading
end

-- ── Pool de frames (réutilisées entre affichages) ──────────────────
local iconPool    = {}
local activeIcons = {}

local function AcquireIcon(parent)
    local f = table.remove(iconPool)
    if f then
        f:SetParent(parent); f:ClearAllPoints()
    else
        f = CreateFrame("Button", nil, parent, "BackdropTemplate")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0, 0, 0, 0.6)
        f.ico = f:CreateTexture(nil, "ARTWORK")
        f.ico:SetPoint("TOPLEFT", 1, -1); f.ico:SetPoint("BOTTOMRIGHT", -1, 1)
        f.ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.countText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        f.countText:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    f:Show()
    activeIcons[#activeIcons + 1] = f
    return f
end

local function ReleaseAllIcons()
    for _, f in ipairs(activeIcons) do
        f:Hide(); f:ClearAllPoints()
        f:SetScript("OnEnter", nil); f:SetScript("OnLeave", nil); f:SetScript("OnClick", nil)
        if core and core.CatDnD then core.CatDnD.Detach(f) end
        iconPool[#iconPool + 1] = f
    end
    wipe(activeIcons)
end

-- ── Pool d'en-têtes de catégorie (mode catégorie) ──────────────────
-- Même principe que le pool d'icônes : évite de recréer une FontString
-- par catégorie à chaque affichage. Parent fixe = scrollChild.
local catHeaderPool    = {}
local activeCatHeaders = {}

local function AcquireCatHeader(parent)
    local fs = table.remove(catHeaderPool)
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    end
    fs:Show()
    activeCatHeaders[#activeCatHeaders + 1] = fs
    return fs
end

local function ReleaseCatHeaders()
    for _, fs in ipairs(activeCatHeaders) do
        fs:Hide(); fs:ClearAllPoints()
        catHeaderPool[#catHeaderPool + 1] = fs
    end
    wipe(activeCatHeaders)
end

-- ── Sélecteur de guilde (affiché à droite, dans mainFrame) ────────
local SELECTOR_W = 160

local selectorButtons  = {}

local currentGuildKey = nil  -- guilde actuellement affichée
local currentTabIndex = 1    -- onglet actuellement affiché

-- Forward declaration ; définie plus bas.
local function DrawGuildView()  end

-- Forward declaration ; réassignée dans GetOrCreateSelectorFrame.
local function RefreshSelectorButtons() end

-- ── Création du panneau sélecteur de guilde ──────────────────────
-- Reste dans ce fichier : accède aux locaux SELECTOR_W, selectorButtons,
-- currentGuildKey/TabIndex, DrawGuildView, RefreshSelectorButtons.
function pluginNs.GetOrCreateSelectorFrame()
    if pluginNs._selectorScroll then return pluginNs._selectorScroll end
    if not core or not core.mainFrame then return end

    local scroll = CreateFrame("ScrollFrame", "AVL_GuildSelector", core.mainFrame, "UIPanelScrollFrameTemplate")
    scroll:SetWidth(SELECTOR_W)
    local L = core.LAYOUT or { pad = 0, titleH = 30, bottomH = 36 }
    scroll:SetPoint("TOPRIGHT",    core.mainFrame, "TOPRIGHT",    -(L.pad + 4), -(L.titleH + 6))
    scroll:SetPoint("BOTTOMRIGHT", core.mainFrame, "BOTTOMRIGHT", -(L.pad + 4),  L.bottomH + 6)

    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetWidth(SELECTOR_W); inner:SetHeight(1)
    scroll:SetScrollChild(inner)
    scroll:Hide()

    pluginNs._selectorInner  = inner
    pluginNs._selectorScroll = scroll

    -- Remplace RefreshSelectorButtons pour utiliser l'inner scroll
    local _origRefresh = RefreshSelectorButtons
    -- Titre « GUILDES » (créé une fois)
    local head = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", 4, -6)
    pluginNs._selectorHead = head

    RefreshSelectorButtons = function()
        for _, btn in ipairs(selectorButtons) do btn:Hide() end
        wipe(selectorButtons)
        head:SetText(pluginNs.L("GUILDS_HEADING"):upper())
        head:SetTextColor(unpack(core.Theme.textDim))
        if not ViewerLogDB.guilds then return end

        local offsetY = -28
        for guildKey, gData in pairs(ViewerLogDB.guilds) do
            if type(gData) == "table" and gData.guildName then
                local btn = CreateFrame("Button", nil, inner, "BackdropTemplate")
                btn:SetSize(SELECTOR_W - 24, 36)
                btn:SetPoint("TOPLEFT", inner, "TOPLEFT", 4, offsetY)
                core.Skin.Button(btn)
                btn._active = (guildKey == currentGuildKey)
                core.Skin.Paint(btn)

                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fs:SetPoint("CENTER")
                fs:SetText(gData.guildName)
                local c = btn._active and core.Theme.gold or core.Theme.text
                fs:SetTextColor(c[1], c[2], c[3])

                local capturedKey = guildKey
                btn:SetScript("OnClick", function()
                    currentGuildKey = capturedKey
                    currentTabIndex = 1
                    DrawGuildView()
                    RefreshSelectorButtons()
                end)

                selectorButtons[#selectorButtons + 1] = btn
                offsetY = offsetY - 44
            end
        end
        inner:SetHeight(math.max(1, math.abs(offsetY) + 10))
    end

    return scroll
end

-- ── Onglets du coffre (barre horizontale sous le titre) ────────────
local tabButtons   = {}
local tabBtnPool   = {}   -- pool de réutilisation, comme iconPool

local TAB_BTN_W = 110
local TAB_BTN_H = 40
local TAB_Y     = -112

local function ReleaseTabs()
    for _, tb in ipairs(tabButtons) do
        tb:Hide(); tb:ClearAllPoints()
        tb:SetScript("OnMouseDown", nil)
        if tb._arrow then tb._arrow:Hide() end
        tb._onEnter = nil
        tabBtnPool[#tabBtnPool + 1] = tb
    end
    wipe(tabButtons)
end

-- 8 = nombre max d'onglets de banque de guilde côté Blizzard.
local MAX_VISIBLE_TABS = 8
local MAX_TAB_W        = 140

local function AcquireTab(parent, w, h)
    local tb = table.remove(tabBtnPool)
    if tb then
        tb:SetParent(parent); tb:ClearAllPoints()
    else
        tb = CreateFrame("Button", nil, parent, "BackdropTemplate")
        core.Skin.Button(tb)
        tb._nameFS = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tb._nameFS:SetPoint("LEFT", 14, 0)
        tb._nameFS:SetJustifyH("LEFT")
        tb._nameFS:SetWordWrap(false)
    end
    tb._active, tb._hover = false, false
    tb._nameFS:SetText("")
    tb._nameFS:Show()
    tb:SetSize(w or TAB_BTN_W, h or TAB_BTN_H)
    tb._nameFS:SetWidth((w or TAB_BTN_W) - 20)
    tb:Show()
    return tb
end

local function RefreshTabButtons(gData, scrollChild)
    ReleaseTabs()
    if not gData or not gData.tabs then return end

    local totalTabs = 0
    for i = 1, 8 do if gData.tabs[i] then totalTabs = i end end

    local contentW = core and core.GetContentWidth and core.GetContentWidth() or 660
    local avail = contentW - 40
    local visibleCount = math.min(totalTabs, MAX_VISIBLE_TABS)
    local computedW = visibleCount > 0
        and math.floor((avail - (visibleCount - 1) * 8) / visibleCount)
        or TAB_BTN_W
    local tabW = math.min(computedW, MAX_TAB_W)

    if not gData._tabOffset then gData._tabOffset = 0 end
    if currentTabIndex > gData._tabOffset + MAX_VISIBLE_TABS then
        gData._tabOffset = currentTabIndex - MAX_VISIBLE_TABS
    elseif currentTabIndex <= gData._tabOffset then
        gData._tabOffset = currentTabIndex - 1
    end
    gData._tabOffset = math.max(0, math.min(gData._tabOffset, totalTabs - MAX_VISIBLE_TABS))

    local startTab = gData._tabOffset + 1
    local endTab   = math.min(gData._tabOffset + MAX_VISIBLE_TABS, totalTabs)

    local offsetX = 20
    for i = startTab, endTab do
        local tabData = gData.tabs[i]
        if tabData then
            local tb = AcquireTab(scrollChild, tabW, TAB_BTN_H)
            tb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", offsetX, TAB_Y)
            tb._nameFS:SetText(tabData.name or pluginNs.L("TAB_LABEL"):format(i))

            tb._active = (i == currentTabIndex)
            core.Skin.Paint(tb)
            local c = tb._active and core.Theme.gold or core.Theme.text
            tb._nameFS:SetTextColor(c[1], c[2], c[3])

            local capturedIndex = i
            tb:SetScript("OnMouseDown", function(_, btn)
                if btn == "LeftButton" then
                    currentTabIndex = capturedIndex
                    DrawGuildView()
                end
            end)

            tabButtons[#tabButtons + 1] = tb
            offsetX = offsetX + tabW + 8
        end
    end

    -- Flèche de défilement (si plus de MAX_VISIBLE_TABS onglets)
    if totalTabs > MAX_VISIBLE_TABS then
        local arrowBtn = AcquireTab(scrollChild, TAB_BTN_H, TAB_BTN_H)
        arrowBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", offsetX, TAB_Y)
        arrowBtn._nameFS:Hide()
        core.Skin.Paint(arrowBtn)

        if not arrowBtn._arrow then
            arrowBtn._arrow = arrowBtn:CreateTexture(nil, "ARTWORK")
            arrowBtn._arrow:SetSize(28, 28)
            arrowBtn._arrow:SetPoint("CENTER", 0, 0)
            arrowBtn._arrow:SetAtlas("housing-floor-arrow-right-default")
            arrowBtn:HookScript("OnEnter", function(self)
                if not self._hiddenTabs then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(pluginNs.L("OTHER_TABS_HEADER"), 1, 0.82, 0)
                for _, line in ipairs(self._hiddenTabs) do
                    GameTooltip:AddLine(line.text, line.active and 1 or 0.6, line.active and 0.82 or 0.6, line.active and 0 or 0.6)
                end
                GameTooltip:Show()
            end)
            arrowBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        arrowBtn._arrow:Show()
        arrowBtn._hiddenTabs = {}
        for j = endTab + 1, totalTabs do
            local td = gData.tabs[j]
            if td then
                arrowBtn._hiddenTabs[#arrowBtn._hiddenTabs + 1] = {
                    text = td.name or pluginNs.L("TAB_LABEL"):format(j), active = (j == currentTabIndex) }
            end
        end
        arrowBtn:SetScript("OnMouseDown", function(_, btn)
            if btn == "LeftButton" then
                local nxt = endTab + 1
                if nxt > totalTabs then nxt = 1 end
                currentTabIndex = nxt
                gData._tabOffset = math.max(0, nxt - MAX_VISIBLE_TABS)
                DrawGuildView()
            end
        end)
        tabButtons[#tabButtons + 1] = arrowBtn
    end
end

-- ── Affichage principal ────────────────────────────────────────────
DrawGuildView = function()
    if not core then return end
    core.ClearContent()
    ReleaseAllIcons()
    ReleaseCatHeaders()
    ReleaseTabs()

    local scrollChild = core.scrollChild
    local L = pluginNs.L

    -- ── En-tête : titre (bleu), guilde / chef, date, filet ───────────
    local T = core.Theme
    local title = scrollChild._guildeLogTitle
    if not title then
        title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        scrollChild._guildeLogTitle = title
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", 20, -14)
    title:SetText(L("GUILDE_TITLE")); title:SetTextColor(BLUE[1], BLUE[2], BLUE[3])
    title:Show()

    local rule = scrollChild._guildeLogRule
    if not rule then
        rule = core.Skin.Rule(scrollChild)
        scrollChild._guildeLogRule = rule
    end
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, -96)
    rule:SetWidth(math.max(100, (core.GetContentWidth and core.GetContentWidth() or 660) - 40))
    rule:Show()

    if not ViewerLogDB.guilds or not next(ViewerLogDB.guilds) then
        local nd = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        nd:SetPoint("TOP", 0, -100); nd:SetText(L("NO_DATA"))
        scrollChild:SetHeight(200)
        return
    end

    -- Choisir la guilde à afficher (par défaut : la première dispo ou la courante)
    if not currentGuildKey or not ViewerLogDB.guilds[currentGuildKey] then
        currentGuildKey = next(ViewerLogDB.guilds)
        currentTabIndex = 1
    end

    local gData = ViewerLogDB.guilds[currentGuildKey]
    if not gData then
        scrollChild:SetHeight(200); return
    end

    -- Ligne 2 : nom de la guilde, puis son chef (ancré sur le bord
    -- droit de guildLabel pour s'adapter à la longueur du nom)
    local guildLabel = scrollChild._guildeLogGuildLabel
    if not guildLabel then
        guildLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scrollChild._guildeLogGuildLabel = guildLabel
    end
    guildLabel:ClearAllPoints()
    guildLabel:SetPoint("TOPLEFT", 20, -48)
    guildLabel:SetText(L("GUILD_NAME_LABEL"):format("|cffffffff" .. (gData.guildName or "?") .. "|r"))
    guildLabel:SetTextColor(T.text[1], T.text[2], T.text[3])
    guildLabel:Show()

    local leaderLabel = scrollChild._guildeLogLeaderLabel
    if not leaderLabel then
        leaderLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scrollChild._guildeLogLeaderLabel = leaderLabel
    end
    leaderLabel:ClearAllPoints()
    leaderLabel:SetPoint("LEFT", guildLabel, "RIGHT", 28, 0)
    -- Libellé clair, nom du chef en rose
    leaderLabel:SetTextColor(T.text[1], T.text[2], T.text[3])
    leaderLabel:SetText(L("GUILD_LEADER_LABEL"):format(
        "|cffff66b3" .. (gData.guildLeader or "?") .. "|r"))
    leaderLabel:Show()

    -- Ligne 3 : date de dernière mise à jour, sur sa propre ligne
    -- (la largeur de la ligne 2 varie selon les noms)
    local scanLabel = scrollChild._guildeLogScanLabel
    if not scanLabel then
        scanLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        scrollChild._guildeLogScanLabel = scanLabel
    end
    scanLabel:ClearAllPoints()
    scanLabel:SetPoint("TOPLEFT", 20, -72)
    scanLabel:SetTextColor(T.textDim[1], T.textDim[2], T.textDim[3])
    if gData.scanTime and gData.scanTime > 0 then
        local dateStr = date("%d/%m/%Y %H:%M", gData.scanTime)
        scanLabel:SetText(L("SCAN_DATE"):format(dateStr))
    else
        scanLabel:SetText(L("NEVER_SCANNED"))
    end
    scanLabel:Show()

    -- Barre d'onglets
    RefreshTabButtons(gData, scrollChild)

    local tabData = gData.tabs and gData.tabs[currentTabIndex]
    if not tabData or not tabData.items then
        local nd = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        nd:SetPoint("TOPLEFT", 20, -100); nd:SetText(L("NO_DATA"))
        scrollChild:SetHeight(200); return
    end

    -- Trier les slots pour un affichage propre
    local sortedSlots = {}
    for slot, iData in pairs(tabData.items) do
        if iData and iData.id then
            sortedSlots[#sortedSlots + 1] = {
                slot = slot, id = iData.id, count = iData.count or 1, link = iData.link,
            }
        end
    end
    table.sort(sortedSlots, function(a, b) return a.slot < b.slot end)

    local MAX_COLS = math.max(6, math.floor(((core.GetContentWidth and core.GetContentWidth() or 660) - 40) / 38))
    local baseY = -176

    -- Placement d'un item : centralise icône + tooltip, partagé par les
    -- deux modes d'affichage.
    -- dnd = { store=, refresh= } en mode catégorie : l'icône devient draggable.
    local function DrawItemButton(entry, x, y, dnd)
        local b = AcquireIcon(scrollChild)
        b:SetSize(34, 34)
        b:SetPoint("TOPLEFT", x, y)
        local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(entry.link or entry.id)
        local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if qc then b:SetBackdropBorderColor(qc.r, qc.g, qc.b, 1)
        else b:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end

        -- Icône via GetItemIcon / C_Item.GetItemIconByID
        local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id))
                     or (GetItemIcon and GetItemIcon(entry.id))
        b.ico:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        if entry.count > 1 then
            b.countText:SetText(entry.count); b.countText:Show()
        else
            b.countText:Hide()
        end

        local cid, clink = entry.id, entry.link
        local function ShowItemTooltip(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            -- Lien complet capturé au scan (cf. scanner/Guild.lua) : reflète
            -- les vraies stats de l'item, contrairement à un lien reconstruit
            -- depuis l'itemID seul.
            if clink then
                GameTooltip:SetHyperlink(clink)
            else
                GameTooltip:SetItemByID(cid)
            end
            GameTooltip:Show()
        end
        if dnd and core.CatDnD then core.CatDnD.AttachItem(b, cid, dnd.store, dnd.refresh) end
        b:SetScript("OnEnter", ShowItemTooltip)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", ShowItemTooltip)
    end

    -- Même réglage que le reste de l'addon (source unique via le core).
    local useCatMode = core.DP_GetSettings and (core.DP_GetSettings() or {}).useCategoryMode

    if not useCatMode then
        -- ── Grille simple (identique à ShowWarbandBank) ────────────────
        local col, row = 0, 0
        for _, entry in ipairs(sortedSlots) do
            DrawItemButton(entry, 20 + col * 38, baseY - row * 38)
            col = col + 1
            if col >= MAX_COLS then col = 0; row = row + 1 end
        end
        scrollChild:SetHeight(math.abs(baseY) + ((row + 1) * 38) + 60)
    else
        -- ── Mode catégorie : moteur partagé du core (core.Cat) ────────
        -- Même store / ordre / drag & drop que sacs, banque et bataillon ;
        -- libellé blanc + compteur bleu, comme la vue Bataillon.
        local store   = core.Cat.GetStore("guild")
        local refresh = function() DrawGuildView() end
        local buckets, order = core.Cat.Distribute(store, sortedSlots)
        pluginNs.liveBuckets, pluginNs.liveOrder = buckets, order
        local getLive = function() return pluginNs.liveBuckets, pluginNs.liveOrder end
        local dnd = { store = store, refresh = refresh }

        -- Bouton "Ordre des catégories" (coin haut droit de la zone contenu)
        if core.CatManager then
            local gear = core.CatManager.CreateGearButton(scrollChild, function(s)
                core.ToggleCatOrderPanel(s, store, refresh, getLive)
            end)
            gear:ClearAllPoints()
            gear:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", (core.GetContentWidth and core.GetContentWidth() or 660) - 40, -16)
        end

        for _, key in ipairs(core.Cat.Order(store, buckets, order)) do
            local bkt = buckets[key]
            local hdr = AcquireCatHeader(scrollChild)
            hdr:SetPoint("TOPLEFT", 20, baseY)
            hdr:SetText(bkt.label:upper() .. " |cff4da6ff(" .. #bkt.items .. ")|r")
            hdr:SetTextColor(T.heading[1], T.heading[2], T.heading[3])
            baseY = baseY - 26

            local col, row = 0, 0
            for _, entry in ipairs(bkt.items) do
                DrawItemButton(entry, 20 + col * 38, baseY - row * 38, dnd)
                col = col + 1
                if col >= MAX_COLS then col = 0; row = row + 1 end
            end
            -- Slot "+" : dernier emplacement de la catégorie (drop d'un item)
            if core.CatDnD then
                core.CatDnD.AddPlus(scrollChild, 20 + col * 38, baseY - row * 38, key, store, refresh)
            end
            baseY = baseY - ((row + 1) * 38) - 14
        end
        scrollChild:SetHeight(math.abs(baseY) + 60)
        if core.CatManager then core.CatManager.Notify(store, refresh, getLive) end
    end
    RefreshSelectorButtons()
end

-- Expose pour Scanner.lua (refresh si la vue est ouverte)
function pluginNs.RefreshView()
    if pluginNs.isViewActive then
        DrawGuildView()
    end
end

-- Point d'entrée principal
function pluginNs.ShowGuildBank()
    pluginNs.isViewActive = true
    core.currentView     = pluginNs.ShowGuildBank
    core.currentViewIsBank = false
    DrawGuildView()
    RefreshSelectorButtons()
end
