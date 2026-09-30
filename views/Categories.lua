local addonName, ns = ...

-- ====================================================
-- VUE CATÉGORIES — Système de groupement des items par type
-- Rôle UNIQUE : tout ce qui concerne le tri/affichage
-- des items par catégorie dans la vue sacs.
--
-- API publique :
--   ns.DrawBagsByCategory(data, baseY) → retourne le baseY final
--   ns.OpenCatOrderPanel(...)          → panneau de réordonnancement
--   ns.ToggleCatOrderPanel(...)
--
-- Dépendances :
--   ns.AVL_GetBlizzardCategory  (Views.lua)
--   ns.AcquireButton, ns.GetIcon, ns.GetContentWidth, ns.scrollChild
-- ====================================================

local pairs   = pairs
local ipairs  = ipairs
local type    = type

-- ── Popup "créer une catégorie" ───────────────────────────────────
local function ShowAddCatPopup()
    if not StaticPopupDialogs["ALTVIEWER_ADD_CATEGORY"] then
        StaticPopupDialogs["ALTVIEWER_ADD_CATEGORY"] = {
            hasEditBox = 1, maxLetters = 30,
            OnAccept = function(self)
                local name = self.editBox:GetText():match("^%s*(.-)%s*$")
                if name == "" or not ns.bagViewData then return end
                local d = ns.bagViewData
                d.customCategories = d.customCategories or {}
                d.customCategories[name] = d.customCategories[name] or { items = {} }
                if ns.pendingCatItemID then
                    for _, cd in pairs(d.customCategories) do
                        if cd.items then cd.items[ns.pendingCatItemID] = nil end
                    end
                    d.customCategories[name].items[ns.pendingCatItemID] = true
                    ns.pendingCatItemID = nil
                end
                local fn = ns.pendingCatRefresh or function()
                    ns.ShowBags(d, ns.bagViewChar, ns.bagViewRealm)
                end
                ns.pendingCatRefresh = nil
                fn()
            end,
            OnCancel = function() ns.pendingCatItemID = nil; ns.pendingCatRefresh = nil end,
            EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
            timeout = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopupDialogs["ALTVIEWER_ADD_CATEGORY"].text    = ns.L("CAT_ADD_TITLE")
    StaticPopupDialogs["ALTVIEWER_ADD_CATEGORY"].button1 = ns.L("POPUP_CONFIRM")
    StaticPopupDialogs["ALTVIEWER_ADD_CATEGORY"].button2 = ns.L("POPUP_CANCEL")
    StaticPopup_Show("ALTVIEWER_ADD_CATEGORY")
end

-- ── Panneau de réordonnancement ───────────────────────────────────
local catOrderPanel = CreateFrame("Frame", "AVL_CatOrderPanel", UIParent, "BackdropTemplate")
catOrderPanel:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
catOrderPanel:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
catOrderPanel:SetBackdropBorderColor(0.20, 0.20, 0.24, 1)
catOrderPanel:SetFrameStrata("DIALOG")
catOrderPanel:SetClampedToScreen(true)
catOrderPanel:EnableMouse(true)
catOrderPanel:SetMovable(true)
catOrderPanel:RegisterForDrag("LeftButton")
catOrderPanel:SetScript("OnDragStart", function(self) self:StartMoving() end)
catOrderPanel:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
catOrderPanel:Hide()
catOrderPanel.rows = {}

local panelTitle = catOrderPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
panelTitle:SetPoint("TOP", 0, -8)
panelTitle:SetText("|cffd0d0ff" .. ns.L("TT_CATEGORY_ORDER") .. "|r")

local panelClose = CreateFrame("Button", nil, catOrderPanel)
panelClose:SetSize(16, 16)
panelClose:SetPoint("TOPRIGHT", -4, -5)
local pcHL = panelClose:CreateTexture(nil, "HIGHLIGHT")
pcHL:SetAllPoints(); pcHL:SetColorTexture(0.65, 0.10, 0.10, 0.80)
local pcFS = panelClose:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pcFS:SetPoint("CENTER", 0, 1); pcFS:SetText("|cffcc4444x|r")
panelClose:SetScript("OnClick", function() catOrderPanel:Hide() end)

-- Fantôme de drag
local rowGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
rowGhost:SetSize(224, 24)
rowGhost:SetFrameStrata("TOOLTIP")
rowGhost:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
rowGhost:SetBackdropColor(0.18, 0.18, 0.22, 0.95)
rowGhost:SetBackdropBorderColor(0.40, 0.40, 0.50, 0.90)
local rowGhostFS = rowGhost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rowGhostFS:SetPoint("LEFT", 8, 0)
rowGhost:Hide()

local rowDrag = { active=false, srcIdx=nil, pData=nil, pRefresh=nil, pAnchor=nil }

local rowDragPoll = CreateFrame("Frame", nil, UIParent)
do
    local _dt = 0
    rowDragPoll:SetScript("OnUpdate", function(self, dt)
        _dt = _dt + dt
        if _dt < 0.016 then return end
        _dt = 0
        if not rowDrag.active then return end
        local sc = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx/sc, cy/sc
        rowGhost:ClearAllPoints()
        rowGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
        if not IsMouseButtonDown("LeftButton") then
            local tgt = rowDrag.srcIdx
            for j, r in ipairs(catOrderPanel.rows) do
                if r:IsShown() then
                    local rl = r:GetLeft()
                    if rl and cx>=rl and cx<=r:GetRight()
                    and cy>=r:GetBottom() and cy<=r:GetTop() then
                        tgt = j; break
                    end
                end
            end
            rowDrag.active = false
            rowGhost:Hide()
            if tgt ~= rowDrag.srcIdx then
                local d    = rowDrag.pData
                -- Réordonner la liste RÉELLEMENT affichée (les clés du
                -- panneau), pas BuildOrderList qui ignorait les catégories
                -- Blizzard live : c'est ce décalage d'index qui empêchait
                -- de déplacer les catégories.
                local keys  = catOrderPanel._orderedKeys or {}
                local moved = table.remove(keys, rowDrag.srcIdx)
                if moved then
                    table.insert(keys, tgt, moved)
                    -- Ordre affiché d'abord, puis les clés persistées
                    -- absentes de la vue courante (conservées à la suite
                    -- pour ne pas perdre leur préférence d'ordre).
                    local inDisplay, newOrder = {}, {}
                    for _, k in ipairs(keys) do
                        inDisplay[k] = true
                        newOrder[#newOrder+1] = k
                    end
                    for _, k in ipairs(d.catOrder or {}) do
                        if not inDisplay[k] then newOrder[#newOrder+1] = k end
                    end
                    d.catOrder = newOrder
                end
                rowDrag.pRefresh()
                -- Rouvrir AVEC les buckets live pour que le panneau
                -- réaffiche les catégories Blizzard.
                ns.OpenCatOrderPanel(rowDrag.pAnchor, d, rowDrag.pRefresh,
                    catOrderPanel._liveBuckets, catOrderPanel._liveBucketOrder)
            end
        end
    end)
end

-- ── OpenCatOrderPanel ─────────────────────────────────────────────
function ns.OpenCatOrderPanel(anchor, data, refreshFn, liveBuckets, liveBucketOrder)
    local ROW_H, PAD_Y, PAN_W = 26, 26, 236

    local ordered, placed = {}, {}

    local function entryLabel(key, isCustom, name)
        if isCustom then return "|cffffff00"..name.."|r" end
        if liveBuckets and liveBuckets[key] then return liveBuckets[key].label end
        if key:find("^B_") then
            for _, ci in pairs(ns.AVL_CAT_CACHE or {}) do
                if ci.key == key then return ci.label end
            end
        end
        return ns.L(key) or key
    end

    for _, k in ipairs(data.catOrder or {}) do
        if not placed[k] then
            local isCustom = k:find("^__c__") ~= nil
            local name = isCustom and k:sub(6) or nil
            if (liveBuckets and liveBuckets[k]) or isCustom then
                ordered[#ordered+1] = { key=k, isCustom=isCustom, name=name, label=entryLabel(k,isCustom,name) }
                placed[k] = true
            end
        end
    end
    if liveBucketOrder then
        for _, k in ipairs(liveBucketOrder) do
            if not placed[k] and liveBuckets[k] and #liveBuckets[k].items > 0 then
                local bkt = liveBuckets[k]
                ordered[#ordered+1] = { key=k, isCustom=bkt.isCustom, name=bkt.name, label=bkt.label }
                placed[k] = true
            end
        end
    end
    for catName in pairs(data.customCategories or {}) do
        local k = "__c__"..catName
        if not placed[k] then
            ordered[#ordered+1] = { key=k, isCustom=true, name=catName, label="|cffffff00"..catName.."|r" }
        end
    end

    -- Mémoriser l'ordre affiché et les buckets live : le drop du drag
    -- (rowDragPoll) réordonne cette liste et rouvre le panneau avec ces
    -- mêmes buckets.
    catOrderPanel._orderedKeys = {}
    for i, info in ipairs(ordered) do catOrderPanel._orderedKeys[i] = info.key end
    catOrderPanel._liveBuckets     = liveBuckets
    catOrderPanel._liveBucketOrder = liveBucketOrder

    for _, r in ipairs(catOrderPanel.rows) do r:Hide() end
    catOrderPanel:SetSize(PAN_W, PAD_Y + #ordered * ROW_H + 8)

    for i, info in ipairs(ordered) do
        local row = catOrderPanel.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, catOrderPanel, "BackdropTemplate")
            row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.10, 0.10, 0.12, 0.50)
            row.labelFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.labelFS:SetPoint("LEFT", 8, 0)
            row.labelFS:SetPoint("RIGHT", -6, 0)
            row.labelFS:SetJustifyH("LEFT")
            row:EnableMouse(true)
            catOrderPanel.rows[i] = row
        end
        row:SetSize(PAN_W-8, ROW_H-2)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, -(PAD_Y + (i-1)*ROW_H))
        row.labelFS:SetText(info.label)
        row.bg:SetColorTexture(0.10, 0.10, 0.12, 0.50)
        local ci = i
        row:SetScript("OnEnter", function(s)
            if not rowDrag.active then s.bg:SetColorTexture(0.18, 0.18, 0.24, 0.80) end
        end)
        row:SetScript("OnLeave", function(s)
            if not rowDrag.active then s.bg:SetColorTexture(0.10, 0.10, 0.12, 0.50) end
        end)
        row:SetScript("OnMouseDown", function(s, btn)
            if btn ~= "LeftButton" then return end
            rowDrag.active  = true
            rowDrag.srcIdx  = ci
            rowDrag.pData   = data
            rowDrag.pRefresh= refreshFn
            rowDrag.pAnchor = anchor
            rowGhostFS:SetText(info.label)
            rowGhost:Show()
        end)
        row:Show()
    end

    catOrderPanel:ClearAllPoints()
    catOrderPanel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    catOrderPanel:Show()
    do
        local _elapsed = 0
        catOrderPanel:SetScript("OnUpdate", function(self, dt)
            _elapsed = _elapsed + dt
            if _elapsed < 0.05 then return end
            _elapsed = 0
            if rowDrag.active then return end
            if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
            and not self:IsMouseOver() then
                self:Hide()
            end
        end)
    end
end

function ns.ToggleCatOrderPanel(anchor, data, refreshFn, liveBuckets, liveBucketOrder)
    if catOrderPanel:IsShown() then
        catOrderPanel:Hide()
    else
        ns.OpenCatOrderPanel(anchor, data, refreshFn, liveBuckets, liveBucketOrder)
    end
end

-- ── DrawBagsByCategory ────────────────────────────────────────────
-- Appelée par ViewBags.lua en mode catégorie.
-- Retourne le baseY final pour que ShowBags puisse SetHeight.
function ns.DrawBagsByCategory(data, baseY)
    -- Collecter les items des sacs 0-5
    local allItems = {}
    for _, bag in ipairs({0,1,2,3,4,5}) do
        if data.bags and data.bags[bag] then
            for _, itemData in pairs(data.bags[bag]) do
                local id    = type(itemData)=="table" and itemData.id    or itemData
                local count = type(itemData)=="table" and itemData.count or 1
                local link  = type(itemData)=="table" and itemData.link  or nil
                if id then
                    local agg = allItems[id]
                    if not agg then
                        agg = { count = 0, link = link }
                        allItems[id] = agg
                    end
                    agg.count = agg.count + count
                    -- Premier lien rencontré conservé comme représentatif :
                    -- si le même itemID existe à plusieurs niveaux
                    -- d'amélioration, le tooltip du groupe montrera l'un
                    -- d'eux plutôt qu'une version générique sans aucun
                    -- niveau d'amélioration.
                    agg.link = agg.link or link
                end
            end
        end
    end

    data.customCategories = data.customCategories or {}
    local itemToCustom = {}
    for catName, catData in pairs(data.customCategories) do
        for itemID in pairs(catData.items or {}) do itemToCustom[itemID] = catName end
    end

    -- Distribution dynamique
    local dynBuckets     = {}
    local dynBucketOrder = {}

    local function GetOrCreateBucket(key, label, isCustom, customName)
        if not dynBuckets[key] then
            dynBuckets[key] = { label=label, isCustom=isCustom, name=customName, items={} }
            dynBucketOrder[#dynBucketOrder+1] = key
        end
        return dynBuckets[key]
    end

    ns.liveDynBuckets     = dynBuckets
    ns.liveDynBucketOrder = dynBucketOrder

    for itemID, agg in pairs(allItems) do
        local slot = { id = itemID, count = agg.count, link = agg.link }
        if itemToCustom[itemID] then
            local cn  = itemToCustom[itemID]
            local key = "__c__"..cn
            GetOrCreateBucket(key, "|cffffff00"..cn.."|r", true, cn).items[#dynBuckets[key].items+1] = slot
        else
            local catInfo = ns.AVL_GetBlizzardCategory(itemID)
            if catInfo then
                GetOrCreateBucket(catInfo.key, catInfo.label, false, nil).items[#dynBuckets[catInfo.key].items+1] = slot
            else
                GetOrCreateBucket("B_AUTRE", ns.L("CAT_AUTRE"), false, nil).items[#dynBuckets["B_AUTRE"].items+1] = slot
            end
        end
    end

    -- Respecter catOrder
    local orderedKeys, placed = {}, {}
    for _, k in ipairs(data.catOrder or {}) do
        if dynBuckets[k] then orderedKeys[#orderedKeys+1] = k; placed[k] = true end
    end
    for _, k in ipairs(dynBucketOrder) do
        if not placed[k] then orderedKeys[#orderedKeys+1] = k end
    end

    -- Dessiner chaque catégorie
    local function DrawCategory(bkt)
        local items = bkt.items
        if not items or #items == 0 then return end

        local titleBar = CreateFrame("Frame", nil, ns.scrollChild, "BackdropTemplate")
        titleBar:SetSize(ns.GetContentWidth() - 20, 26)
        titleBar:SetPoint("TOPLEFT", 20, baseY)
        titleBar:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
        titleBar:SetBackdropColor(0, 0, 0, 0)
        titleBar:SetBackdropBorderColor(0, 0, 0, 0)

        -- Libellé Blizzard en blanc (GameFontHighlight), comme la vue
        -- Bataillon ; les catégories custom portent leur propre code
        -- couleur (jaune) et restent jaunes. Compteur en bleu.
        local titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        titleFS:SetPoint("LEFT", 10, 0)
        titleFS:SetText(bkt.label .. " |cff4da6ff(" .. #items .. ")|r")
        baseY = baseY - 30

        local col, row = 0, 0
        for _, item in ipairs(items) do
            local b = ns.AcquireButton(ns.scrollChild)
            b:SetSize(32, 32)
            b:SetPoint("TOPLEFT", 20 + col*35, baseY - row*35)
            b.ico:SetTexture(ns.GetIcon(item.id))
            if item.count > 1 then b.countText:SetText(item.count); b.countText:Show()
            else b.countText:Hide() end
            local capturedID, capturedLink = item.id, item.link
            b:SetScript("OnEnter", function(s)
                if not ns.AVL_GetSelected() then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if capturedLink then
                        GameTooltip:SetHyperlink(capturedLink)
                    else
                        GameTooltip:SetItemByID(capturedID)
                    end
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", GameTooltip_Hide)
            b:RegisterForClicks("LeftButtonUp")
            b:SetScript("OnClick", function(s, btn)
                GameTooltip:Hide()
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                if capturedLink then
                    GameTooltip:SetHyperlink(capturedLink)
                else
                    GameTooltip:SetItemByID(capturedID)
                end
                GameTooltip:Show()
            end)
            col = col + 1
            if col >= 14 then col = 0; row = row + 1 end
        end
        baseY = baseY - ((row+1)*35) - 14
    end

    for _, key in ipairs(orderedKeys) do
        DrawCategory(dynBuckets[key])
    end

    return baseY
end
