local addonName, ns = ...

-- ====================================================
-- VUE CATÉGORIES — affichage des sacs groupés par catégorie
-- Rôle UNIQUE : dessiner la vue sacs en mode catégorie.
-- Données / ordre : ns.Cat (CategoryStore.lua)
-- Fenêtre de gestion : CategoryManager.lua
-- Drag & drop + slot "+" : CategoryDnD.lua
--
-- API publique :
--   ns.DrawBagsByCategory(data, baseY) → retourne le baseY final
--
-- Dépendances :
--   ns.Cat, ns.AcquireButton, ns.GetIcon, ns.GetContentWidth,
--   ns.scrollChild (+ ns.CatDnD / ns.CatManager, optionnels)
-- ====================================================

local pairs   = pairs
local ipairs  = ipairs
local type    = type

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

    local slots = {}
    for itemID, agg in pairs(allItems) do
        slots[#slots+1] = { id = itemID, count = agg.count, link = agg.link }
    end
    local dynBuckets, dynBucketOrder = ns.Cat.Distribute(data, slots)
    ns.liveDynBuckets     = dynBuckets
    ns.liveDynBucketOrder = dynBucketOrder
    local orderedKeys = ns.Cat.Order(data, dynBuckets, dynBucketOrder)

    local refresh = function()
        ns.ShowBags(ns.bagViewData, ns.bagViewChar, ns.bagViewRealm)
    end
    local DnD = ns.CatDnD

    -- Dessiner chaque catégorie
    local function DrawCategory(key, bkt)
        local items = bkt.items

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
            if DnD then DnD.AttachItem(b, capturedID, data, refresh) end
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
        -- Slot "+" : dernier emplacement de la catégorie (drop d'un item)
        if DnD then DnD.AddPlus(ns.scrollChild, 20 + col*35, baseY - row*35, key, data, refresh) end
        baseY = baseY - ((row+1)*35) - 14
    end

    for _, key in ipairs(orderedKeys) do
        DrawCategory(key, dynBuckets[key])
    end

    if ns.CatManager then
        ns.CatManager.Notify(data, refresh, function() return ns.liveDynBuckets, ns.liveDynBucketOrder end)
    end

    return baseY
end
