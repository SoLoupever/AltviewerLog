local addonName, pluginNs = ...

-- ==================================================
-- GUILDE/UI/VIEW — Affichage du coffre de guilde
-- Grille d'icônes façon ShowWarbandBank, sélecteur de
-- guilde à droite, barre d'onglets, tooltip natif WoW.
-- Contient : DrawGuildView, RefreshView, ShowGuildBank
-- ==================================================

local core = _G.AltViewerLogAPI   -- dépendance déclarée dans le .toc

-- ── Thème ────────────────────────────────────────────────────────
-- Couleur d'accent (bordure) du thème actif dans AltViewerLog,
-- avec repli si le thème n'est pas encore défini.
local DEFAULT_BORDER = { 0.45, 0.15, 0.70 }
function pluginNs.GetThemeBorder()
    return (core and core._themeBorder) or DEFAULT_BORDER
end

-- Fond teinté à partir de la couleur d'accent du thème (version
-- assombrie, même principe que Theme.lua). intensity (0-1) : plus
-- vif au survol.
function pluginNs.GetThemeFill(intensity)
    intensity = intensity or 0.35
    local b = pluginNs.GetThemeBorder()
    return b[1]*intensity + 0.05, b[2]*intensity + 0.05, b[3]*intensity + 0.05
end

-- Léger relief (dégradé + filet clair) sur un bouton avec backdrop.
-- Appelé une fois par frame physique (frames recyclées via les pools
-- ci-dessous) pour ne jamais empiler les textures entre deux refresh.
local function ApplySheen(frame)
    if frame._sheen then return end
    local grad = frame:CreateTexture(nil, "ARTWORK")
    grad:SetPoint("TOPLEFT", 1, -1)
    grad:SetPoint("BOTTOMRIGHT", -1, 1)
    if grad.SetGradient and CreateColor then
        grad:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.16), CreateColor(1, 1, 1, 0))
    elseif grad.SetGradientAlpha then
        grad:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.16, 1, 1, 1, 0)
    end
    local topLine = frame:CreateTexture(nil, "OVERLAY")
    topLine:SetPoint("TOPLEFT", 1, -1)
    topLine:SetPoint("TOPRIGHT", -1, -1)
    topLine:SetHeight(1)
    topLine:SetColorTexture(1, 1, 1, 0.35)
    frame._sheen = true
end
pluginNs.ApplySheen = ApplySheen

-- ── Pool de frames (réutilisées entre affichages) ──────────────────
local iconPool    = {}
local activeIcons = {}

local function AcquireIcon(parent)
    local f = table.remove(iconPool)
    if f then
        f:SetParent(parent); f:ClearAllPoints()
    else
        f = CreateFrame("Button", nil, parent)
        f.ico = f:CreateTexture(nil, "BACKGROUND"); f.ico:SetAllPoints()
        f.countText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
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
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
    scroll:SetPoint("TOPRIGHT",    core.mainFrame, "TOPRIGHT",    0, -30)
    scroll:SetPoint("BOTTOMRIGHT", core.mainFrame, "BOTTOMRIGHT", 0,  36)

    local inner = CreateFrame("Frame", nil, scroll)
    inner:SetWidth(SELECTOR_W); inner:SetHeight(1)
    scroll:SetScrollChild(inner)
    scroll:Hide()

    pluginNs._selectorInner  = inner
    pluginNs._selectorScroll = scroll

    -- Remplace RefreshSelectorButtons pour utiliser l'inner scroll
    local _origRefresh = RefreshSelectorButtons
    RefreshSelectorButtons = function()
        for _, btn in ipairs(selectorButtons) do btn:Hide() end
        wipe(selectorButtons)
        if not ViewerLogDB.guilds then return end

        local offsetY = -10
        for guildKey, gData in pairs(ViewerLogDB.guilds) do
            if type(gData) == "table" and gData.guildName then
                local btn = CreateFrame("Button", nil, inner, "BackdropTemplate")
                btn:SetSize(SELECTOR_W - 20, 32)
                btn:SetPoint("TOPLEFT", inner, "TOPLEFT", 5, offsetY)
                btn:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                btn:SetNormalFontObject("GameFontNormalSmall")
                btn:SetText(gData.guildName)
                ApplySheen(btn)

                local isActive = (guildKey == currentGuildKey)
                if isActive then
                    local b = pluginNs.GetThemeBorder()
                    local r, g, bl = pluginNs.GetThemeFill(0.35)
                    btn:SetBackdropColor(r, g, bl, 1)
                    btn:SetBackdropBorderColor(b[1], b[2], b[3], 1)
                else
                    btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
                    btn:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
                end

                btn:SetScript("OnEnter", function(self)
                    local r, g, bl = pluginNs.GetThemeFill(0.5)
                    self:SetBackdropColor(r, g, bl, 1)
                    local b = pluginNs.GetThemeBorder()
                    self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
                end)
                btn:SetScript("OnLeave", function(self)
                    local active = (currentGuildKey == guildKey)
                    if active then
                        local b = pluginNs.GetThemeBorder()
                        local r, g, bl = pluginNs.GetThemeFill(0.35)
                        self:SetBackdropColor(r, g, bl, 1)
                        self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
                    else
                        self:SetBackdropColor(0.12, 0.12, 0.12, 1)
                        self:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
                    end
                end)

                local capturedKey = guildKey
                btn:SetScript("OnClick", function()
                    currentGuildKey = capturedKey
                    currentTabIndex = 1
                    DrawGuildView()
                    RefreshSelectorButtons()
                end)

                selectorButtons[#selectorButtons + 1] = btn
                offsetY = offsetY - 38
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

local function ReleaseTabs()
    for _, tb in ipairs(tabButtons) do
        tb:Hide(); tb:ClearAllPoints()
        tb:SetScript("OnEnter",    nil)
        tb:SetScript("OnLeave",    nil)
        tb:SetScript("OnMouseDown", nil)
        tabBtnPool[#tabBtnPool + 1] = tb
    end
    wipe(tabButtons)
end

-- 8 = nombre max d'onglets de banque de guilde côté Blizzard.
-- La pagination (flèche + tooltip) reste en place si cette limite
-- change un jour.
local MAX_VISIBLE_TABS = 8
local MAX_TAB_W        = 140   -- largeur maximale par onglet

local function AcquireTab(parent, w, h)
    w = w or TAB_BTN_W
    h = h or TAB_BTN_H
    local tb = table.remove(tabBtnPool)
    if tb then
        tb:SetParent(parent); tb:ClearAllPoints()
        -- Réinitialiser le backdrop à neutre (sera re-coloré juste après par le caller)
        tb:SetBackdropColor(0.10, 0.10, 0.10, 1)
        tb:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        -- Remettre à zéro les textes réutilisables
        if tb._nameFS   then tb._nameFS:SetText(""); tb._nameFS:Show() end
    else
        tb = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        tb:EnableMouse(true)
        tb:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        -- Créer les FontStrings une seule fois, stockées sur le frame
        tb._nameFS = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tb._nameFS:SetPoint("TOPLEFT", 6, -6)

        ApplySheen(tb)
    end
    tb:SetSize(w, h)
    -- Mettre à jour la largeur du nameFS selon la taille actuelle
    tb._nameFS:SetWidth(w - 10)
    tb:Show()
    return tb
end

local function RefreshTabButtons(gData, scrollChild)
    ReleaseTabs()
    if not gData or not gData.tabs then return end

    -- Compter les onglets réels
    local totalTabs = 0
    for i = 1, 8 do if gData.tabs[i] then totalTabs = i end end

    -- Largeur dynamique : distribuée entre les onglets visibles, plafonnée à MAX_TAB_W
    local contentW = core and core.GetContentWidth and core.GetContentWidth() or 660
    local visibleCount = math.min(totalTabs, MAX_VISIBLE_TABS)
    local computedW = visibleCount > 0
        and math.floor((contentW - 40 - (visibleCount - 1) * 6) / visibleCount)
        or TAB_BTN_W
    local tabW = math.min(computedW, MAX_TAB_W)

    -- Décalage d'affichage : quel onglet commence la fenêtre visible
    if not gData._tabOffset then gData._tabOffset = 0 end
    -- S'assurer que l'onglet actif est toujours visible
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
            tb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", offsetX, -92)

            -- Réutilise les FontStrings créées une seule fois dans AcquireTab
            tb._nameFS:SetText(tabData.name or pluginNs.L("TAB_LABEL"):format(i))
            tb._nameFS:SetJustifyH("LEFT")

            local isActive = (i == currentTabIndex)
            if isActive then
                local b = pluginNs.GetThemeBorder()
                local r, g, bl = pluginNs.GetThemeFill(0.35)
                tb:SetBackdropColor(r, g, bl, 1)
                tb:SetBackdropBorderColor(b[1], b[2], b[3], 1)
            else
                tb:SetBackdropColor(0.10, 0.10, 0.10, 1)
                tb:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
            end

            local capturedIndex = i   -- déclaré ICI pour être accessible dans OnLeave et OnMouseDown
            tb:SetScript("OnEnter", function(self)
                local r, g, bl = pluginNs.GetThemeFill(0.5)
                self:SetBackdropColor(r, g, bl, 1)
                local b = pluginNs.GetThemeBorder()
                self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
            end)
            tb:SetScript("OnLeave", function(self)
                -- Compare avec capturedIndex (pas i, qui peut changer en fin de boucle)
                if currentTabIndex == capturedIndex then
                    local b = pluginNs.GetThemeBorder()
                    local r, g, bl = pluginNs.GetThemeFill(0.35)
                    self:SetBackdropColor(r, g, bl, 1)
                    self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
                else
                    self:SetBackdropColor(0.10, 0.10, 0.10, 1)
                    self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
                end
            end)

            tb:SetScript("OnMouseDown", function(self, btn)
                if btn == "LeftButton" then
                    currentTabIndex = capturedIndex
                    DrawGuildView()
                end
            end)

            tabButtons[#tabButtons + 1] = tb
            offsetX = offsetX + tabW + 6
        end
    end

    -- Flèche de défilement (si plus de MAX_VISIBLE_TABS onglets)
    if totalTabs > MAX_VISIBLE_TABS then
        local arrowBtn = AcquireTab(scrollChild, TAB_BTN_H, TAB_BTN_H)  -- carré
        arrowBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", offsetX, -92)
        do
            local b = pluginNs.GetThemeBorder()
            arrowBtn:SetBackdropColor(0.10, 0.10, 0.15, 1)
            arrowBtn:SetBackdropBorderColor(b[1], b[2], b[3], 1)
        end

        local arrowTex = arrowBtn:CreateTexture(nil, "ARTWORK")
        arrowTex:SetSize(28, 28)
        arrowTex:SetPoint("CENTER", 0, 0)
        arrowTex:SetAtlas("housing-floor-arrow-right-default")

        -- Tooltip : liste les onglets cachés
        arrowBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.20, 0.12, 0.32, 1)
            local b = pluginNs.GetThemeBorder()
            self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cffffff00" .. pluginNs.L("OTHER_TABS_HEADER") .. "|r")
            for j = endTab + 1, totalTabs do
                local td = gData.tabs[j]
                if td then
                    local active = (j == currentTabIndex)
                    local col = active and "|cffc060ff" or "|cff888888"
                    GameTooltip:AddLine(col .. (td.name or pluginNs.L("TAB_LABEL"):format(j)) .. "|r")
                end
            end
            GameTooltip:Show()
        end)
        arrowBtn:SetScript("OnLeave", function(self)
            local b = pluginNs.GetThemeBorder()
            self:SetBackdropColor(0.10, 0.10, 0.15, 1)
            self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
            GameTooltip:Hide()
        end)
        arrowBtn:SetScript("OnMouseDown", function(self, btn)
            if btn == "LeftButton" then
                -- Cycle parmi les onglets cachés
                local next = endTab + 1
                if next > totalTabs then next = 1 end
                currentTabIndex = next
                gData._tabOffset = math.max(0, next - MAX_VISIBLE_TABS)
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

    -- ── En-tête ────────────────────────────────────────────────────
    -- Bandeau de fond + filet d'accent thème, posés directement sur
    -- scrollChild et mis en cache (masqués par ClearContent(), pas
    -- recréés à chaque refresh).
    local HEADER_H = 78
    local header = scrollChild._guildeLogHeaderPanel
    if not header then
        header = scrollChild:CreateTexture(nil, "BACKGROUND")
        scrollChild._guildeLogHeaderPanel = header
    end
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
    header:SetSize(core and core.GetContentWidth and core.GetContentWidth() or 660, HEADER_H)
    header:SetColorTexture(0.02, 0.02, 0.04, 0.72)
    header:Show()

    local headerEdge = scrollChild._guildeLogHeaderEdge
    if not headerEdge then
        headerEdge = scrollChild:CreateTexture(nil, "BORDER")
        scrollChild._guildeLogHeaderEdge = headerEdge
    end
    headerEdge:ClearAllPoints()
    headerEdge:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    headerEdge:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerEdge:SetHeight(2)
    do
        local b = pluginNs.GetThemeBorder()
        headerEdge:SetColorTexture(b[1], b[2], b[3], 0.9)
    end
    headerEdge:Show()

    -- Ligne 1 : titre, seul sur sa ligne
    local title = scrollChild._guildeLogTitle
    if not title then
        title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        scrollChild._guildeLogTitle = title
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetText(L("GUILDE_TITLE")); title:SetTextColor(0, 0.67, 1)
    title:Show()

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
        guildLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        scrollChild._guildeLogGuildLabel = guildLabel
    end
    guildLabel:ClearAllPoints()
    guildLabel:SetPoint("TOPLEFT", 20, -42)
    guildLabel:SetText(L("GUILD_NAME_LABEL"):format(gData.guildName or "?"))
    guildLabel:Show()

    local leaderLabel = scrollChild._guildeLogLeaderLabel
    if not leaderLabel then
        leaderLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        scrollChild._guildeLogLeaderLabel = leaderLabel
    end
    leaderLabel:ClearAllPoints()
    leaderLabel:SetPoint("LEFT", guildLabel, "RIGHT", 20, 0)
    if gData.guildLeader then
        leaderLabel:SetText(L("GUILD_LEADER_LABEL"):format(gData.guildLeader))
        leaderLabel:SetTextColor(1, 0.40, 0.70)  -- rose
    else
        leaderLabel:SetText(L("GUILD_LEADER_LABEL"):format("?"))
        leaderLabel:SetTextColor(0.5, 0.5, 0.5)
    end
    leaderLabel:Show()

    -- Ligne 3 : date de dernière mise à jour, sur sa propre ligne
    -- (la largeur de la ligne 2 varie selon les noms)
    local scanLabel = scrollChild._guildeLogScanLabel
    if not scanLabel then
        scanLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        scrollChild._guildeLogScanLabel = scanLabel
    end
    scanLabel:ClearAllPoints()
    scanLabel:SetPoint("TOPLEFT", 20, -64)
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

    local MAX_COLS = 14
    local baseY = -147

    -- Placement d'un item : centralise icône + tooltip, partagé par les
    -- deux modes d'affichage.
    local function DrawItemButton(entry, x, y)
        local b = AcquireIcon(scrollChild)
        b:SetSize(32, 32)
        b:SetPoint("TOPLEFT", x, y)

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
            DrawItemButton(entry, 20 + col * 35, baseY - row * 35)
            col = col + 1
            if col >= MAX_COLS then col = 0; row = row + 1 end
        end
        scrollChild:SetHeight(math.abs(baseY) + ((row + 1) * 35) + 60)
    else
        -- ── Mode catégorie : groupement par type Blizzard sur l'onglet
        -- affiché. Réutilise la catégorisation du core (AltViewerLog) ;
        -- libellé blanc + compteur bleu, comme la vue Bataillon.
        local buckets, order = {}, {}
        local function Bucket(key, label)
            local bkt = buckets[key]
            if not bkt then
                bkt = { label = label, items = {} }
                buckets[key] = bkt
                order[#order + 1] = key
            end
            return bkt
        end

        for _, entry in ipairs(sortedSlots) do
            local catInfo = core.AVL_GetBlizzardCategory
                        and core.AVL_GetBlizzardCategory(entry.id)
            if catInfo then
                local bkt = Bucket(catInfo.key, catInfo.label)
                bkt.items[#bkt.items + 1] = entry
            else
                -- core (AltViewerLog) est une dépendance requise → core.L
                -- toujours disponible ; réutilise sa clé CAT_AUTRE.
                local bkt = Bucket("B_AUTRE", core.L("CAT_AUTRE"))
                bkt.items[#bkt.items + 1] = entry
            end
        end

        for _, key in ipairs(order) do
            local bkt = buckets[key]
            if #bkt.items > 0 then
                local hdr = AcquireCatHeader(scrollChild)
                hdr:SetPoint("TOPLEFT", 20, baseY)
                hdr:SetText(bkt.label .. " |cff4da6ff(" .. #bkt.items .. ")|r")
                baseY = baseY - 26

                local col, row = 0, 0
                for _, entry in ipairs(bkt.items) do
                    DrawItemButton(entry, 20 + col * 35, baseY - row * 35)
                    col = col + 1
                    if col >= MAX_COLS then col = 0; row = row + 1 end
                end
                baseY = baseY - ((row + 1) * 35) - 12
            end
        end
        scrollChild:SetHeight(math.abs(baseY) + 60)
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
