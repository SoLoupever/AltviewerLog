local addonName, ns = ...

-- ====================================================
-- VUE SACS — ns.ShowBags
-- Affiche le contenu des sacs d'un personnage.
-- Deux modes selon le paramètre useCategoryMode :
--   · Mode classique : sac par sac
--   · Mode catégorie : groupé par type (délégué à ViewCategories.lua)
--
-- Dépendances (fournies avant ce fichier) :
--   ns.ClearContent, ns.AcquireButton, ns.GetIcon
--   ns.GetContentWidth, ns.scrollChild
--   ns.OpenCharSelector, ns.charSelMenu
--   ns.liveDynBuckets, ns.liveDynBucketOrder (écrits ici, lus par ViewCategories)
--   ns.ToggleCatOrderPanel (ViewCategories.lua)
-- ====================================================

-- Contexte conservé pour les popups et menus
ns.bagViewData      = nil
ns.bagViewChar      = nil
ns.bagViewRealm     = nil
ns.pendingCatItemID = nil

function ns.ShowBags(data, charName, realmName)
    if not ns.scrollChild then return end
    ns.currentView = function() ns.ShowBags(data, charName, realmName) end
    ns.currentViewIsBank = false
    ns.ClearContent()

    ns.bagViewData  = data
    ns.bagViewChar  = charName
    ns.bagViewRealm = realmName

    local baseY = -15
    local useCatMode = (ns.DP_GetSettings() or {}).useCategoryMode

    -- ── En-tête personnage + bouton sélecteur ─────────────────────
    if charName then
        local header = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", 20, baseY)
        local c = RAID_CLASS_COLORS[data.class] or { r=1, g=1, b=1 }
        header:SetTextColor(c.r, c.g, c.b)
        header:SetText(string.format(ns.L("BAG_VIEW_TITLE"), charName))

        -- Bouton sélecteur de personnage
        local selBtn = CreateFrame("Button", nil, ns.scrollChild, "BackdropTemplate")
        selBtn:SetSize(22, 22)
        selBtn:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", -30, baseY + 3)
        selBtn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
        selBtn:SetBackdropColor(0.15, 0.25, 0.45, 0.9)
        selBtn:SetBackdropBorderColor(0.4, 0.6, 1, 0.8)
        if not selBtn.ico then
            selBtn.ico = selBtn:CreateTexture(nil, "ARTWORK")
            selBtn.ico:SetAllPoints()
            selBtn.ico:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
        end
        selBtn:SetScript("OnEnter", function(s)
            s:SetBackdropColor(0.25, 0.4, 0.7, 1)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.L("CHAR_SWITCH_TT"), 1, 1, 1)
            GameTooltip:Show()
        end)
        selBtn:SetScript("OnLeave", function(s)
            s:SetBackdropColor(0.15, 0.25, 0.45, 0.9)
            GameTooltip:Hide()
        end)
        selBtn:SetScript("OnClick", function(s)
            ns.OpenCharSelector(s, function(newChar, newRealm)
                local newData = ns.DP_GetCharData(newRealm, newChar)
                if newData then ns.ShowBags(newData, newChar, newRealm) end
            end)
        end)

        -- Bouton engrenage (mode catégorie uniquement)
        if useCatMode then
            local gearBtn = CreateFrame("Button", nil, ns.scrollChild, "BackdropTemplate")
            gearBtn:SetSize(22, 22)
            gearBtn:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", -56, baseY + 3)
            gearBtn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
            gearBtn:SetBackdropColor(0.20, 0.18, 0.10, 0.9)
            gearBtn:SetBackdropBorderColor(0.70, 0.60, 0.25, 0.9)
            local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
            gearTex:SetPoint("TOPLEFT", 3, -3)
            gearTex:SetPoint("BOTTOMRIGHT", -3, 3)
            gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
            gearTex:SetVertexColor(1, 0.85, 0)
            gearBtn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(0.32, 0.28, 0.12, 1)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:AddLine(ns.L("TT_CATEGORY_ORDER"), 1, 1, 0.5)
                GameTooltip:Show()
            end)
            gearBtn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(0.20, 0.18, 0.10, 0.9)
                GameTooltip:Hide()
            end)
            local capData, capChar, capRealm = data, charName, realmName
            gearBtn:SetScript("OnClick", function(s)
                ns.ToggleCatOrderPanel(s, capData,
                    function() ns.ShowBags(capData, capChar, capRealm) end,
                    ns.liveDynBuckets, ns.liveDynBucketOrder)
            end)
        end

        baseY = baseY - 30
    end

    -- ── Dispatch mode ─────────────────────────────────────────────
    if not useCatMode then
        -- ── MODE CLASSIQUE : sac par sac ──────────────────────────
        local function DrawSection(_, bagList, dataTable)
            if not dataTable then return end
            local hasItems = false
            for _, bag in ipairs(bagList) do
                if dataTable[bag] and next(dataTable[bag]) then hasItems = true; break end
            end
            if not hasItems then return end

            for _, bag in ipairs(bagList) do
                local slots = dataTable[bag]
                if slots and next(slots) then
                    local bagName
                    if bag == 5         then bagName = ns.L("BAG_REAGENT")
                    elseif bag == -1    then bagName = ns.L("BANK_MAIN")
                    elseif bag == -3    then bagName = ns.L("BANK_REAGENT")
                    elseif bag >= 6 and bag <= 11 then bagName = string.format(ns.L("BANK_BAG"), bag-5)
                    else   bagName = string.format(ns.L("BAG_NAME"), bag) end

                    local bagTitle = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    bagTitle:SetPoint("TOPLEFT", 20, baseY)
                    bagTitle:SetText(bagName)
                    baseY = baseY - 25

                    local col, row = 0, 0
                    for _, itemData in pairs(slots) do
                        local id    = type(itemData) == "table" and itemData.id    or itemData
                        local count = type(itemData) == "table" and itemData.count or 1
                        local link  = type(itemData) == "table" and itemData.link  or nil
                        local b = ns.AcquireButton(ns.scrollChild)
                        b:SetSize(32, 32)
                        b:SetPoint("TOPLEFT", 20 + col*35, baseY - row*35)
                        b.ico:SetTexture(ns.GetIcon(id))
                        if count > 1 then b.countText:SetText(count); b.countText:Show()
                        else b.countText:Hide() end
                        local capturedID, capturedLink = id, link
                        b:SetScript("OnEnter", function(s)
                            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                            -- Le lien complet reflète l'état réel de cette instance
                            -- (niveau d'amélioration, scaling bataillon, etc.) ;
                            -- repli sur l'ID seul si l'objet a été scanné avant
                            -- l'ajout de cette capture (donnée existante sans link).
                            if capturedLink then
                                GameTooltip:SetHyperlink(capturedLink)
                            else
                                GameTooltip:SetItemByID(capturedID)
                            end
                            GameTooltip:Show()
                        end)
                        b:SetScript("OnLeave", GameTooltip_Hide)
                        col = col + 1
                        if col >= 14 then col = 0; row = row + 1 end
                    end
                    baseY = baseY - ((row+1)*35) - 20
                end
            end
        end

        DrawSection(nil, {0,1,2,3,4,5}, data.bags)

    else
        -- ── MODE CATÉGORIE : délégué à ViewCategories.lua ─────────
        baseY = ns.DrawBagsByCategory(data, baseY)
    end

    ns.scrollChild:SetHeight(math.abs(baseY) + 50)
end
