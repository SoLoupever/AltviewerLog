local addonName, ns = ...

-- ====================================================
-- BANQUE BATAILLON (Warband Bank)
-- Extraite de Views.lua pour isoler la logique warband.
-- Dépendances partagées via ns :
--   ns.AcquireButton, ns.GetIcon, ns.Cat (store/ordre/résolution),
--   ns.AVL_GetSelected, ns.scrollChild, ns.GetContentWidth,
--   ns.ClearContent (+ ns.CatDnD / ns.CatManager, optionnels)
-- ====================================================

function ns.ShowWarbandBank()
    ns.currentView       = ns.ShowWarbandBank
    ns.currentViewIsBank = false
    ns.ClearContent()

    if not ns.DP_IsReady() then
        local noData = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noData:SetPoint("CENTER", ns.scrollChild, "CENTER", 0, 0)
        noData:SetText("|cffff9900" .. ns.L("WARBAND_NO_DATA") .. "|r")
        ns.scrollChild:SetHeight(150)
        return
    end

    local title = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(ns.L("WARBAND_TITLE"))
    title:SetTextColor(1, 0.8, 0)

    -- ── Or de la banque bataillon ──────────────────────────────────
    local wbGold = ns.DP_GetWarbandGold()
    if wbGold > 0 then
        local goldFrame = CreateFrame("Frame", nil, ns.scrollChild, "BackdropTemplate")
        goldFrame:SetSize(220, 26)
        goldFrame:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", -20, -17)
        ns.Skin.Frame(goldFrame, "bar")

        local goldLabel = goldFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        goldLabel:SetPoint("LEFT", 8, 0)
        goldLabel:SetText("|cffffd100" .. ns.L("TOTAL_GOLD") .. "|r " .. GetCoinTextureString(wbGold))
    end

    local warbandData = ns.DP_GetWarbandBank()
    if not warbandData or not next(warbandData) then
        local noData = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        noData:SetPoint("TOP", 0, -100)
        noData:SetText(ns.L("NO_RESULTS"))
        ns.scrollChild:SetHeight(150)
        return
    end

    -- Collecter tous les items des onglets bataillon.
    -- On itère directement les bags présents dans warbandData plutôt que
    -- des IDs hardcodés : un onglet non scanné (pas encore visité, non
    -- acheté, ou dont ScanContainerInto a retiré l'entrée faute de slots)
    -- est simplement absent de la table et ignoré proprement.
    local allItems = {}
    for _, bagSlots in pairs(warbandData) do
        for _, itemData in pairs(bagSlots) do
            local id    = type(itemData) == "table" and itemData.id    or itemData
            local count = type(itemData) == "table" and itemData.count or 1
            local link  = type(itemData) == "table" and itemData.link  or nil
            if id then
                local agg = allItems[id]
                if not agg then
                    agg = { count = 0, link = link }
                    allItems[id] = agg
                end
                agg.count = agg.count + count
                agg.link  = agg.link or link
            end
        end
    end

    local useCatMode = (ns.DP_GetSettings() or {}).useCategoryMode

    -- ── Mode sac unique (catégories désactivées) ──────────────────
    if not useCatMode then
        local baseY = -60
        local col, row = 0, 0
        for itemID, agg in pairs(allItems) do
            local b = ns.AcquireButton(ns.scrollChild)
            b:SetSize(32, 32)
            b:SetPoint("TOPLEFT", 20 + col * 35, baseY - row * 35)
            b.ico:SetTexture(ns.GetIcon(itemID))
            if agg.count > 1 then
                b.countText:SetText(agg.count); b.countText:Show()
            else
                b.countText:Hide()
            end

            local cid, clink = itemID, agg.link
            b:SetScript("OnEnter", function(s)
                if not ns.AVL_GetSelected() then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if clink then GameTooltip:SetHyperlink(clink)
                    else GameTooltip:SetItemByID(cid) end
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", function(s, btn)
                if btn == "LeftButton" then
                    GameTooltip:Hide()
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if clink then GameTooltip:SetHyperlink(clink)
                    else GameTooltip:SetItemByID(cid) end
                    GameTooltip:Show()
                end
            end)

            col = col + 1
            if col >= 14 then col = 0; row = row + 1 end
        end
        ns.scrollChild:SetHeight(math.abs(baseY) + ((row + 1) * 35) + 50)
        return
    end

    -- ── Mode catégories ────────────────────────────────────────────
    -- Store partagé avec la fenêtre de gestion et le drag & drop
    -- (customCategories = AltViewerLogDB.warbandCustomCategories).
    local store = ns.Cat.GetStore("warband")
    local refreshWarband = function() ns.ShowWarbandBank() end
    local DnD = ns.CatDnD

    local slots = {}
    for itemID, agg in pairs(allItems) do
        slots[#slots + 1] = { id = itemID, count = agg.count, link = agg.link }
    end
    local buckets, bucketOrder = ns.Cat.Distribute(store, slots)
    ns.liveWarbandBuckets, ns.liveWarbandBucketOrder = buckets, bucketOrder
    local getLive = function() return ns.liveWarbandBuckets, ns.liveWarbandBucketOrder end

    -- Bouton "Ordre des catégories" (à gauche du bandeau d'or)
    if ns.CatManager then
        local gear = ns.CatManager.CreateGearButton(ns.scrollChild, function(s)
            ns.ToggleCatOrderPanel(s, store, refreshWarband, getLive)
        end)
        gear:ClearAllPoints()
        gear:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", (wbGold > 0) and -248 or -20, -19)
    end

    local baseY = -60

    local function DrawWarbandCategory(key, title_cat, items, customCatName)
        -- Barre de titre de catégorie
        local titleBar = CreateFrame("Frame", nil, ns.scrollChild)
        titleBar:SetSize(ns.GetContentWidth() - 20, 24)
        titleBar:SetPoint("TOPLEFT", 20, baseY)

        local titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        titleFS:SetPoint("LEFT", 0, 0)
        titleFS:SetText(title_cat .. " |cff4da6ff(" .. #items .. ")|r")

        -- Bouton ✕ pour supprimer une catégorie custom
        if customCatName then
            local delBtn = CreateFrame("Button", nil, titleBar)
            delBtn:SetSize(18, 18)
            delBtn:SetPoint("LEFT", titleFS, "RIGHT", 8, 0)

            delBtn.bg = delBtn:CreateTexture(nil, "BACKGROUND")
            delBtn.bg:SetAllPoints(delBtn)
            delBtn.bg:SetColorTexture(0.5, 0.1, 0.1, 0)

            delBtn.fs = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            delBtn.fs:SetPoint("CENTER")
            delBtn.fs:SetText("|cffff4444✕|r")

            delBtn:SetScript("OnEnter", function(s) s.bg:SetColorTexture(0.5, 0.1, 0.1, 0.8) end)
            delBtn:SetScript("OnLeave", function(s) s.bg:SetColorTexture(0.5, 0.1, 0.1, 0)   end)

            local cn = customCatName
            delBtn:SetScript("OnClick", function()
                ns.Cat.RemoveCategory(store, cn)
                refreshWarband()
            end)
        end

        baseY = baseY - 28

        local col, row = 0, 0
        for _, item in ipairs(items) do
            local b = ns.AcquireButton(ns.scrollChild)
            b:SetSize(32, 32)
            b:SetPoint("TOPLEFT", 20 + col * 35, baseY - row * 35)
            b.ico:SetTexture(ns.GetIcon(item.id))
            if item.count > 1 then
                b.countText:SetText(item.count); b.countText:Show()
            else
                b.countText:Hide()
            end

            local cid, clink = item.id, item.link
            if DnD then DnD.AttachItem(b, cid, store, refreshWarband) end
            b:SetScript("OnEnter", function(s)
                if not ns.AVL_GetSelected() then
                    GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                    if clink then GameTooltip:SetHyperlink(clink)
                    else GameTooltip:SetItemByID(cid) end
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", function(s, btn)
                GameTooltip:Hide()
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                if clink then GameTooltip:SetHyperlink(clink)
                else GameTooltip:SetItemByID(cid) end
                GameTooltip:Show()
            end)

            col = col + 1
            if col >= 14 then col = 0; row = row + 1 end
        end

        -- Slot "+" : dernier emplacement de la catégorie (drop d'un item)
        if DnD then DnD.AddPlus(ns.scrollChild, 20 + col * 35, baseY - row * 35, key, store, refreshWarband) end
        baseY = baseY - ((row + 1) * 35) - 12
    end

    -- catOrder persisté d'abord, puis le reste (ns.Cat.Order)
    for _, key in ipairs(ns.Cat.Order(store, buckets, bucketOrder)) do
        local bkt = buckets[key]
        DrawWarbandCategory(key, bkt.label, bkt.items, bkt.name)
    end

    if ns.CatManager then ns.CatManager.Notify(store, refreshWarband, getLive) end

    ns.scrollChild:SetHeight(math.abs(baseY) + 50)
end
