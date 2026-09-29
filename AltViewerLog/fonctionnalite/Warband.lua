local addonName, ns = ...

-- ====================================================
-- BANQUE BATAILLON (Warband Bank)
-- Extraite de Views.lua pour isoler la logique warband.
-- Dépendances partagées via ns :
--   ns.AcquireButton, ns.GetIcon, ns.AVL_GetBlizzardCategory,
--   ns.AVL_CAT_CACHE, ns.AVL_GetSelected, ns.scrollChild,
--   ns.GetContentWidth, ns.ClearContent
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
        goldFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,
        })
        goldFrame:SetBackdropColor(0.05, 0.05, 0.08, 1)
        local br, bg, bb = unpack(ns._themeBorder or { 0.45, 0.15, 0.70 })
        goldFrame:SetBackdropBorderColor(br, bg, bb, 0.8)

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
    local wbCats = ns.DP_GetWarbandCustomCategories()
    local refreshWarband = function() ns.ShowWarbandBank() end

    -- Reverse lookup : itemID → nom de catégorie custom
    local itemToCustom = {}
    for catName, catData in pairs(wbCats) do
        for itemID in pairs(catData.items or {}) do
            itemToCustom[itemID] = catName
        end
    end

    -- Buckets : un par catégorie custom + un par catégorie Blizzard
    local buckets = {}
    for catName in pairs(wbCats) do
        buckets["__c__" .. catName] = {}
    end

    for itemID, agg in pairs(allItems) do
        local slot = { id = itemID, count = agg.count, link = agg.link }
        if itemToCustom[itemID] then
            local key = "__c__" .. itemToCustom[itemID]
            buckets[key] = buckets[key] or {}
            buckets[key][#buckets[key] + 1] = slot
        else
            local catInfo = ns.AVL_GetBlizzardCategory(itemID)
            local key     = catInfo and catInfo.key or "B_AUTRE"
            buckets[key]  = buckets[key] or {}
            buckets[key][#buckets[key] + 1] = slot
        end
    end

    -- Rendu des catégories
    local baseY = -60

    local function DrawWarbandCategory(title_cat, items, customCatName)
        if not items or #items == 0 then return end

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
                wbCats[cn] = nil
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

        baseY = baseY - ((row + 1) * 35) - 12
    end

    -- Catégories custom en premier
    for catName in pairs(wbCats) do
        DrawWarbandCategory("|cffffff00" .. catName .. "|r",
            buckets["__c__" .. catName], catName)
    end

    -- Catégories Blizzard (dynamiques)
    local rendered = {}
    for catName in pairs(wbCats) do rendered["__c__" .. catName] = true end

    for key, bkt in pairs(buckets) do
        if bkt and #bkt > 0 and not rendered[key] and not key:find("^__c__") then
            rendered[key] = true
            local firstID = bkt[1] and bkt[1].id or 0
            local catInfo = ns.AVL_CAT_CACHE[firstID]
            local lbl     = catInfo and catInfo.label or key
            DrawWarbandCategory(lbl, bkt, nil)
        end
    end

    -- Catégories custom encore une fois (pour les items redéposés après coup)
    for catName in pairs(wbCats) do
        DrawWarbandCategory("|cffffff00" .. catName .. "|r",
            buckets["__c__" .. catName], catName)
    end

    ns.scrollChild:SetHeight(math.abs(baseY) + 50)
end
