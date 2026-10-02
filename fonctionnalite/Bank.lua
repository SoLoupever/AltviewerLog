local addonName, ns = ...

-- ====================================================
-- VUE BANQUE PERSONNELLE
-- Extraite de Views.lua
--
-- Deux modes d'affichage (réglés dans Paramètres > AltViewerLog) :
--   · Fenêtre séparée (ns.bankWin) — comportement historique.
--   · Intégré — rendu dans la zone contenu principale (ns.scrollChild),
--     comme la banque de bataillon.
-- Le rendu est identique dans les deux cas : seul le conteneur cible
-- (`target`) change, ce qui évite de dupliquer toute la logique.
-- ====================================================

-- ── Pool de boutons d'objets ──────────────────────────────────────
-- Évite de recréer des frames à chaque rafraîchissement (changement
-- de personnage, de catégorie, drag&drop...). Pool local et dédié à
-- la banque pour ne pas interférer avec le pool de la vue sacs
-- (Views/Shared.lua), qui peut être affichée en même temps.
local bankBtnPool    = {}
local bankActiveBtns = {}

local function AcquireBankItemButton(parent)
    local b = table.remove(bankBtnPool)
    if b then
        b:SetParent(parent)
        b:ClearAllPoints()
    else
        b = CreateFrame("Button", nil, parent)
        b:SetSize(32, 32)
        b.ico = b:CreateTexture(nil, "BACKGROUND"); b.ico:SetAllPoints()
        b.countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.countText:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    b:Show()
    bankActiveBtns[#bankActiveBtns+1] = b
    return b
end

local function ReleaseBankItemButtons()
    for _, b in ipairs(bankActiveBtns) do
        b:Hide()
        b:SetScript("OnEnter", nil)
        b:SetScript("OnLeave", nil)
        b:SetScript("OnClick", nil)
        if ns.CatDnD then ns.CatDnD.Detach(b) end
        bankBtnPool[#bankBtnPool+1] = b
    end
    bankActiveBtns = {}
end

function ns.ClearBankContent()
    if not ns.bankScrollChild then return end
    ns.AVL_Deselect()
    ReleaseBankItemButtons()
    if ns.CatDnD then ns.CatDnD.ReleaseFor(ns.bankScrollChild) end
    local regions = { ns.bankScrollChild:GetRegions() }
    for _, r in ipairs(regions) do if r.Hide then r:Hide() end end
    local children = { ns.bankScrollChild:GetChildren() }
    for _, c in ipairs(children) do c:Hide() end
    ns.bankScrollChild:SetHeight(1)
end

function ns.ShowBank(charName, realmName)
    -- Mode d'affichage : intégré (zone contenu) ou fenêtre séparée.
    local inline = (ns.DP_GetSettings() or {}).bankInline and true or false

    -- Conteneur cible du rendu selon le mode choisi.
    local target
    if inline then
        if not ns.scrollChild then return end
        ns.currentView       = function() ns.ShowBank(charName, realmName) end
        ns.currentViewIsBank = false
        ReleaseBankItemButtons()
        ns.ClearContent()
        if ns.AVL_Deselect then ns.AVL_Deselect() end
        target = ns.scrollChild
    else
        if not ns.bankWin then return end
        ns.currentView       = function() ns.ShowBank(charName, realmName) end
        ns.currentViewIsBank = true
        ns.ClearBankContent()
        target = ns.bankScrollChild
    end
    if ns.charSelMenu then ns.charSelMenu:Hide() end

    ns.bankViewChar  = charName
    ns.bankViewRealm = realmName

    -- Titre (barre de fenêtre en mode fenêtre, FontString en mode intégré)
    local themeHex = ns._themeTitleHex or ns._themeHex or "ffffff"
    local appName  = "|cff" .. themeHex .. "AltViewerLog|r"
    local bankLbl  = "|cff4da6ff" .. ns.L("BTN_BANK") .. "|r"

    local titleStr
    if charName then
        local charData  = ns.DP_GetCharData and ns.DP_GetCharData(realmName, charName)
        local classColor = (charData and charData.class and RAID_CLASS_COLORS[charData.class]) or { r = 1, g = 1, b = 1 }
        local classHex   = string.format("%02x%02x%02x",
            math.floor(classColor.r * 255),
            math.floor(classColor.g * 255),
            math.floor(classColor.b * 255))
        local coloredChar = "|cff" .. classHex .. charName .. "|r"
        titleStr = bankLbl .. " |cffaaaaaa—|r " .. coloredChar
    else
        titleStr = bankLbl
    end

    local fullTitle = appName .. " |cffaaaaaa—|r " .. titleStr
    if inline then
        local t = target:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", 20, -15)
        t:SetText(fullTitle)
    else
        ns.bankWin.titleText:SetText(fullTitle)
    end

    -- Bouton sélecteur de personnage dans la banque
    local bankSelBtn = CreateFrame("Button", nil, target, "BackdropTemplate")
    bankSelBtn:SetSize(22, 22)
    bankSelBtn:SetPoint("TOPRIGHT", target, "TOPRIGHT", -5, -5)
    bankSelBtn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    bankSelBtn:SetBackdropColor(0.15, 0.25, 0.45, 0.9)
    bankSelBtn:SetBackdropBorderColor(0.4, 0.6, 1, 0.8)
    if not bankSelBtn.ico then
        bankSelBtn.ico = bankSelBtn:CreateTexture(nil, "ARTWORK"); bankSelBtn.ico:SetAllPoints()
        bankSelBtn.ico:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
    end
    bankSelBtn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(0.25, 0.4, 0.7, 1)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.L("CHAR_SWITCH_TT"), 1, 1, 1)
        GameTooltip:Show()
    end)
    bankSelBtn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(0.15, 0.25, 0.45, 0.9)
        GameTooltip:Hide()
    end)
    bankSelBtn:SetScript("OnClick", function(s)
        ns.OpenCharSelector(s, function(newChar, newRealm)
            ns.ShowBank(newChar, newRealm)
        end)
    end)

    -- Bouton engrenage banque
    local bankGearBtn = CreateFrame("Button", nil, target, "BackdropTemplate")
    bankGearBtn:SetSize(22, 22)
    bankGearBtn:SetPoint("TOPRIGHT", target, "TOPRIGHT", -32, -5)
    bankGearBtn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
    bankGearBtn:SetBackdropColor(0.20, 0.18, 0.10, 0.9)
    bankGearBtn:SetBackdropBorderColor(0.70, 0.60, 0.25, 0.9)
    local bankGearTex = bankGearBtn:CreateTexture(nil, "ARTWORK")
    bankGearTex:SetPoint("TOPLEFT", 3, -3)
    bankGearTex:SetPoint("BOTTOMRIGHT", -3, 3)
    bankGearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    bankGearTex:SetVertexColor(1, 0.85, 0)
    bankGearBtn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(0.32, 0.28, 0.12, 1)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.L("TT_CATEGORY_ORDER"), 1, 1, 0.5)
        GameTooltip:Show()
    end)
    bankGearBtn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(0.20, 0.18, 0.10, 0.9)
        GameTooltip:Hide()
    end)
    local capBankChar, capBankRealm = charName, realmName

    -- Récupérer les données du personnage via le DataProvider
    local data = charName and realmName
              and ns.DP_GetCharData(realmName, charName)

    local function ShowBankMessage(msg)
        local fs = target:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOP", 0, -80)
        fs:SetWidth(500)
        fs:SetJustifyH("CENTER")
        fs:SetText("|cffaaaaaa"..msg.."|r")
        target:SetHeight(200)
    end

    if not data then
        ShowBankMessage(ns.L("BANK_NO_DATA"))
        if not inline then ns.bankWin:Show() end
        return
    end

    if not data.bank or not next(data.bank) then
        ShowBankMessage(ns.L("BANK_NO_DATA"))
        if not inline then ns.bankWin:Show() end
        return
    end

    -- Décalage de départ : laisse la place au titre en mode intégré.
    local baseY = inline and -50 or -15
    local refreshBank = function() ns.ShowBank(charName, realmName) end
    local useCatMode = (ns.DP_GetSettings() or {}).useCategoryMode

    if not useCatMode then
        -- ================================================================
        -- MODE CLASSIQUE : affichage sac par sac pour la banque
        -- ================================================================
        -- Masquer le bouton engrenage en mode classique
        bankGearBtn:Hide()

        local function DrawBankSection(title, bagList)
            local hasItems = false
            for _, bag in ipairs(bagList) do
                if data.bank[bag] and next(data.bank[bag]) then hasItems = true; break end
            end
            if not hasItems then return end

            local t = target:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            t:SetPoint("TOPLEFT", 20, baseY)
            t:SetText(title)
            baseY = baseY - 35

            for _, bag in ipairs(bagList) do
                local slots = data.bank[bag]
                if slots and next(slots) then
                    local bagName
                    if bag == -1 then
                        bagName = ns.L("BANK_MAIN")
                    elseif bag == -3 then
                        bagName = ns.L("BANK_REAGENT")
                    elseif bag >= 6 and bag <= 11 then
                        bagName = string.format(ns.L("BANK_BAG"), bag - 5)
                    else
                        bagName = tostring(bag)
                    end

                    local bagTitle = target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    bagTitle:SetPoint("TOPLEFT", 20, baseY)
                    bagTitle:SetText(bagName)
                    baseY = baseY - 25

                    local col, row = 0, 0
                    for _, itemData in pairs(slots) do
                        local id    = type(itemData) == "table" and itemData.id    or itemData
                        local count = type(itemData) == "table" and itemData.count or 1
                        local link  = type(itemData) == "table" and itemData.link  or nil

                        local b = AcquireBankItemButton(target)
                        b:SetPoint("TOPLEFT", 20 + (col * 35), baseY - (row * 35))
                        b.ico:SetTexture(ns.GetIcon(id))
                        if count > 1 then b.countText:SetText(count); b.countText:Show()
                        else b.countText:Hide() end

                        local capturedID, capturedLink = id, link
                        b:SetScript("OnEnter", function(s)
                            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                            if capturedLink then
                                GameTooltip:SetHyperlink(capturedLink)
                            else
                                GameTooltip:SetItemByID(capturedID)
                            end
                            GameTooltip:Show()
                        end)
                        b:SetScript("OnLeave", function() GameTooltip:Hide() end)

                        col = col + 1
                        if col >= 14 then col = 0; row = row + 1 end
                    end
                    baseY = baseY - ((row + 1) * 35) - 20
                end
            end
        end

        DrawBankSection(" " .. ns.L("SECTION_BANK"), { -1, 6, 7, 8, 9, 10, 11, -3 })

    else
        -- ================================================================
        -- MODE CATÉGORIE : groupement par type d'item pour la banque
        -- ================================================================

        -- Connecter l'engrenage maintenant que data et refreshBank sont disponibles
        if data then
            local capBankData = data
            bankGearBtn:SetScript("OnClick", function(s)
                -- ns.liveBankBuckets rempli après le calcul des buckets (plus bas)
                ns.ToggleCatOrderPanel(s, capBankData, refreshBank,
                    function() return ns.liveBankBuckets, ns.liveBankBucketOrder end)
            end)
        end

        -- Collecter les items de la banque (-1, 6-11, -3)
        local allItems = {}
        for _, bag in ipairs({ -1, 6, 7, 8, 9, 10, 11, -3 }) do
            if data.bank[bag] then
                for _, itemData in pairs(data.bank[bag]) do
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
                        agg.link  = agg.link or link
                    end
                end
            end
        end

        -- Catégories (partagées avec l'inventaire via le store du personnage)
        local slots = {}
        for itemID, agg in pairs(allItems) do
            slots[#slots+1] = { id = itemID, count = agg.count, link = agg.link }
        end
        local bankBuckets, bankBucketOrder = ns.Cat.Distribute(data, slots)

        -- Exposer pour le bouton engrenage
        ns.liveBankBuckets     = bankBuckets
        ns.liveBankBucketOrder = bankBucketOrder

        local DnD = ns.CatDnD

        local function DrawBankCategory(key, title, items, customCatName)

            local titleBar = CreateFrame("Frame", nil, target, "BackdropTemplate")
            titleBar:SetHeight(26)
            titleBar:SetPoint("TOPLEFT",  target, "TOPLEFT",  20, baseY)
            titleBar:SetPoint("TOPRIGHT", target, "TOPRIGHT", -20, baseY)
            titleBar:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            if customCatName then
                titleBar:SetBackdropColor(0, 0, 0, 0)
                titleBar:SetBackdropBorderColor(0.55, 0.40, 0.08, 0.5)
            else
                titleBar:SetBackdropColor(0, 0, 0, 0)
                titleBar:SetBackdropBorderColor(0, 0, 0, 0)
            end
            -- Libellé Blizzard en blanc (comme Bataillon), custom en jaune
            -- via son propre code couleur ; compteur en bleu.
            local titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            titleFS:SetPoint("LEFT", 10, 0)
            titleFS:SetText(title .. " |cff4da6ff(" .. #items .. ")|r")

            if customCatName then
                local delBtn = CreateFrame("Button", nil, target)
                delBtn:SetSize(18, 18)
                delBtn:SetPoint("LEFT", titleFS, "RIGHT", 8, 0)
                if not delBtn.bg then
                    delBtn.bg = delBtn:CreateTexture(nil, "BACKGROUND"); delBtn.bg:SetAllPoints(delBtn)
                    delBtn.bg:SetColorTexture(0.5, 0.1, 0.1, 0)
                end
                if not delBtn.fs then
                    delBtn.fs = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    delBtn.fs:SetPoint("CENTER"); delBtn.fs:SetText("|cffff4444✕|r")
                end
                delBtn:SetScript("OnEnter", function(s) s.bg:SetColorTexture(0.5,0.1,0.1,0.8) end)
                delBtn:SetScript("OnLeave", function(s) s.bg:SetColorTexture(0.5,0.1,0.1,0) end)
                local cn = customCatName
                delBtn:SetScript("OnClick", function()
                    ns.Cat.RemoveCategory(data, cn)
                    refreshBank()
                end)
            end

            baseY = baseY - 28

            local col, row = 0, 0
            for _, item in ipairs(items) do
                local b = AcquireBankItemButton(target)
                b:SetPoint("TOPLEFT", 20 + col*35, baseY - row*35)
                b.ico:SetTexture(ns.GetIcon(item.id))
                if item.count > 1 then b.countText:SetText(item.count); b.countText:Show()
                else b.countText:Hide() end

                local cid, clink = item.id, item.link
                if DnD then DnD.AttachItem(b, cid, data, refreshBank) end
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
                        GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
                        if clink then GameTooltip:SetHyperlink(clink)
                        else GameTooltip:SetItemByID(cid) end
                        GameTooltip:Show()
                    end
                end)

                col = col + 1
                if col >= 14 then col = 0; row = row + 1 end
            end

            -- Slot "+" : dernier emplacement de la catégorie (drop d'un item)
            if DnD then DnD.AddPlus(target, 20 + col*35, baseY - row*35, key, data, refreshBank) end
            baseY = baseY - ((row+1)*35) - 4
        end

        -- Rendu : catOrder persisté d'abord, puis le reste (ns.Cat.Order)
        for _, k in ipairs(ns.Cat.Order(data, bankBuckets, bankBucketOrder)) do
            local bkt = bankBuckets[k]
            DrawBankCategory(k, bkt.label, bkt.items, bkt.name)
        end

        if ns.CatManager then
            ns.CatManager.Notify(data, refreshBank,
                function() return ns.liveBankBuckets, ns.liveBankBucketOrder end)
        end
    end

    target:SetHeight(math.abs(baseY) + 50)
    if not inline then ns.bankWin:Show() end
end
