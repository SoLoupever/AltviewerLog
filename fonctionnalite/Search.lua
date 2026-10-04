local addonName, ns = ...

-- ====================================================
-- VUE RECHERCHE GLOBALE
-- Appelée depuis le bouton Recherche de la sidebar.
-- Barre de recherche en haut + dropdown filtre,
-- résultats par personnage sous forme de cartes
-- dont la couleur suit le thème actif.
-- ====================================================

-- ── Timer debounce (déclaré ici pour être accessible par OnEscapePressed) ──
local AVL_searchTimer = nil
-- Forward-declaration locale pour éviter que AVL_SearchRebuild soit une globale
local AVL_SearchRebuild

function ns.ShowSearch()
    ns.currentView       = ns.ShowSearch
    ns.currentViewIsBank = false
    ns.ClearContent()

    if not ns.DP_IsReady() then return end

    local FILTER_W  = 180
    local BAR_H     = 36
    local CARD_PAD  = 10
    local ICON_SZ   = 30
    local ICON_GAP  = 4
    local SIDE_PAD  = 20   -- marge gauche/droite dans scrollChild

    -- ── Couleurs thème courant ──────────────────────────────────────
    local function GetThemeBorder()
        local b = ns.Theme.heading
        return b[1], b[2], b[3]
    end

    -- ── Barre de recherche (persistante) ───────────────────────────
    local bar = CreateFrame("Frame", nil, ns.scrollChild, "BackdropTemplate")
    bar:SetHeight(BAR_H)
    bar:SetPoint("TOPLEFT",  ns.scrollChild, "TOPLEFT",   SIDE_PAD, -10)
    bar:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", -SIDE_PAD, -10)
    local bR, bG, bB = GetThemeBorder()
    ns.Skin.Frame(bar, "input")

    -- ── Bouton filtre (ancré à droite dans la barre) ───────────────
    local filterBtn = CreateFrame("Button", nil, bar, "BackdropTemplate")
    filterBtn:SetSize(FILTER_W, 28)
    filterBtn:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    ns.Skin.Button(filterBtn)
    filterBtn:SetNormalFontObject("GameFontNormal")
    filterBtn:SetText(ns.L("FILTER_ALL"))
    filterBtn:GetFontString():SetTextColor(unpack(ns.Theme.gold))

    -- ── EditBox ────────────────────────────────────────────────────
    local editBox = CreateFrame("EditBox", nil, bar)
    editBox:SetPoint("LEFT",  bar,       "LEFT",   8, 0)
    editBox:SetPoint("RIGHT", filterBtn, "LEFT",  -8, 0)
    editBox:SetHeight(28)
    editBox:SetAutoFocus(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextInsets(10, 10, 0, 0)

    local ebBg = editBox:CreateTexture(nil, "BACKGROUND")
    ebBg:SetAllPoints()
    ebBg:SetColorTexture(0, 0, 0, 0)

    local ebLine = editBox:CreateTexture(nil, "OVERLAY")
    ebLine:SetPoint("BOTTOMLEFT")
    ebLine:SetPoint("BOTTOMRIGHT")
    ebLine:SetHeight(1)
    ebLine:SetColorTexture(0, 0, 0, 0)

    editBox:SetText(ns.L("SEARCH_TEXT"))

    editBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText():lower() == ns.L("SEARCH_TEXT"):lower() then
            self:SetText("")
        end
        bar._hover = true; ns.Skin.Paint(bar)
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then self:SetText(ns.L("SEARCH_TEXT")) end
        bar._hover = false; ns.Skin.Paint(bar)
    end)

    editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(ns.L("SEARCH_TEXT"))
        self:ClearFocus()
        ns.activeFilterCat = nil
        filterBtn:SetText(ns.L("FILTER_ALL"))
        if AVL_searchTimer then AVL_searchTimer:Cancel(); AVL_searchTimer = nil end
        AVL_SearchRebuild("", nil)
    end)

    ns.itemSearchBox = editBox

    -- ── Conteneur des résultats (sous la barre) ────────────────────
    -- Tous les résultats sont enfants de ce frame :
    -- masquer ce frame masque tout le contenu d'un coup.
    local TOP_OFFSET = -(10 + BAR_H + 10)

    local resultHolder = CreateFrame("Frame", nil, ns.scrollChild)
    resultHolder:SetPoint("TOPLEFT",  ns.scrollChild, "TOPLEFT",   SIDE_PAD, TOP_OFFSET)
    resultHolder:SetPoint("TOPRIGHT", ns.scrollChild, "TOPRIGHT", -SIDE_PAD, TOP_OFFSET)
    resultHolder:SetHeight(1)

    -- ── Dropdown filtre ────────────────────────────────────────────
    local dropdown = CreateFrame("Frame", nil, ns.mainFrame, "BackdropTemplate")
    dropdown:SetWidth(FILTER_W)
    dropdown:SetFrameLevel(ns.mainFrame:GetFrameLevel() + 60)
    dropdown:SetPoint("TOPRIGHT", filterBtn, "BOTTOMRIGHT", 0, -2)
    ns.Skin.Frame(dropdown, "panel")
    dropdown:Hide()

    local closeW = CreateFrame("Frame", nil, UIParent)
    closeW:SetAllPoints(UIParent)
    closeW:EnableMouse(true)
    closeW:SetFrameLevel(ns.mainFrame:GetFrameLevel() + 59)
    closeW:SetScript("OnMouseDown", function() dropdown:Hide(); closeW:Hide() end)
    closeW:Hide()

    filterBtn:SetScript("OnClick", function()
        if dropdown:IsShown() then dropdown:Hide(); closeW:Hide()
        else dropdown:Show(); closeW:Show() end
    end)

    ns._searchDropdown = dropdown
    ns._searchCloseW   = closeW

    -- ── Lignes du dropdown ─────────────────────────────────────────
    local ROW_H   = 26
    local prevRow = nil

    for _, cat in ipairs(ns.FILTER_CATS) do
        local row = CreateFrame("Button", nil, dropdown)
        row:SetHeight(ROW_H)
        row:SetPoint("LEFT",  dropdown, "LEFT",   4, 0)
        row:SetPoint("RIGHT", dropdown, "RIGHT", -4, 0)
        if prevRow then
            row:SetPoint("TOP", prevRow, "BOTTOM", 0, -2)
        else
            row:SetPoint("TOP", dropdown, "TOP", 0, -4)
        end
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(bR, bG, bB, 0.18)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", 8, 0)
        lbl:SetText(cat.label)

        local capCat = cat
        row:SetScript("OnClick", function()
            if AVL_searchTimer then AVL_searchTimer:Cancel(); AVL_searchTimer = nil end
            ns.activeFilterCat = (capCat.key == "ALL") and nil or capCat
            filterBtn:SetText(capCat.key == "ALL" and ns.L("FILTER_ALL") or capCat.label)
            dropdown:Hide(); closeW:Hide()
            local txt     = editBox:GetText()
            local isEmpty = (txt == "" or txt:lower() == ns.L("SEARCH_TEXT"):lower())
            AVL_SearchRebuild(isEmpty and "" or txt, ns.activeFilterCat)
        end)
        prevRow = row
    end
    dropdown:SetHeight(#ns.FILTER_CATS * (ROW_H + 2) + 8)

    -- ── Vide le resultHolder ───────────────────────────────────────
    local function ClearResults()
        local children = { resultHolder:GetChildren() }
        for _, c in ipairs(children) do c:Hide() end
        local regions = { resultHolder:GetRegions() }
        for _, r in ipairs(regions) do if r.Hide then r:Hide() end end
        resultHolder:SetHeight(1)
    end

    -- ── Reconstruction des résultats ───────────────────────────────
    AVL_SearchRebuild = function(filterText, filterCat)
        ClearResults()

        local hasText = filterText and filterText ~= ""
                        and filterText:lower() ~= ns.L("SEARCH_TEXT"):lower()
        local hasCat  = filterCat and filterCat.key ~= "ALL"

        -- Couleurs thème live (peut avoir changé entre deux rebuilds)
        local tr, tg, tb = GetThemeBorder()
        local themeHex = string.format("%02x%02x%02x",
            math.floor(tr * 255), math.floor(tg * 255), math.floor(tb * 255))

        -- ── Filtre un item : répond-il aux critères ? ──────────────
        local function ItemMatches(id)
            local _, _, _, invTypeStr, _, classID, subClassID = GetItemInfoInstant(id)
            if hasText then
                local name = GetItemInfo(id)
                local nameLow  = name and name:lower()
                local textLow  = filterText:lower()
                local nameHit  = nameLow and nameLow:find(textLow, 1, true)
                local idHit    = tostring(id) == filterText
                if not nameHit and not idHit then return false end
            end
            if hasCat then
                if filterCat.invType then
                    if invTypeStr ~= filterCat.invType then return false end
                elseif filterCat.classID then
                    if classID ~= filterCat.classID then return false end
                    if filterCat.subClassID and subClassID ~= filterCat.subClassID then
                        return false
                    end
                end
            end
            return true
        end

        -- ── Collecter les résultats par personnage ─────────────────
        -- matched[itemID] = { count = total (sacs + banque), link = lien représentatif }
        local charResults = {}
        local grandTotal  = 0

        ns.DP_IterateChars(function(realmName, charName, charData)
            if type(charData) == "table" then
                local matched = {}

                -- Sacs (bags 0-5 → clés numériques, valeurs {id,count,link})
                if charData.bags then
                    for _, slots in pairs(charData.bags) do
                        if type(slots) == "table" then
                            for _, itemData in pairs(slots) do
                                local id = type(itemData) == "table"
                                           and itemData.id or itemData
                                local ct = type(itemData) == "table"
                                           and (itemData.count or 1) or 1
                                local lk = type(itemData) == "table"
                                           and itemData.link or nil
                                if id and id > 0 and ItemMatches(id) then
                                    local agg = matched[id]
                                    if not agg then
                                        agg = { count = 0, link = lk }
                                        matched[id] = agg
                                    end
                                    agg.count = agg.count + ct
                                    agg.link  = agg.link or lk
                                end
                            end
                        end
                    end
                end

                -- Banque personnelle
                if charData.bank then
                    for _, slots in pairs(charData.bank) do
                        if type(slots) == "table" then
                            for _, itemData in pairs(slots) do
                                local id = type(itemData) == "table"
                                           and itemData.id or itemData
                                local ct = type(itemData) == "table"
                                           and (itemData.count or 1) or 1
                                local lk = type(itemData) == "table"
                                           and itemData.link or nil
                                if id and id > 0 and ItemMatches(id) then
                                    local agg = matched[id]
                                    if not agg then
                                        agg = { count = 0, link = lk }
                                        matched[id] = agg
                                    end
                                    agg.count = agg.count + ct
                                    agg.link  = agg.link or lk
                                end
                            end
                        end
                    end
                end

                -- Comptage unique (items distincts)
                local count = 0
                for _ in pairs(matched) do count = count + 1 end

                if count > 0 then
                    grandTotal = grandTotal + count
                    local c = RAID_CLASS_COLORS[charData.class]
                              or { r = 0.80, g = 0.80, b = 0.80 }
                    table.insert(charResults, {
                        charName   = charName,
                        realmName  = realmName,
                        classColor = c,
                        items      = matched,
                        count      = count,
                    })
                end
            end
        end)

        -- ── Aucun résultat ─────────────────────────────────────────
        if #charResults == 0 then
            local noRes = resultHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noRes:SetPoint("TOPLEFT", 4, -14)
            noRes:SetText("|cffaaaaaa" .. ns.L("NO_RESULTS") .. "|r")
            resultHolder:SetHeight(50)
            ns.scrollChild:SetHeight(math.abs(TOP_OFFSET) + 50 + 50)
            return
        end

        -- ── Total général (en haut à droite du resultHolder) ───────
        local totalLabel = resultHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        totalLabel:SetPoint("TOPRIGHT", resultHolder, "TOPRIGHT", -4, -6)
        totalLabel:SetText(string.format(
            "|cff%s%s|r |cffffffff%d|r",
            themeHex, ns.L("SEARCH_RESULTS"), grandTotal))

        -- ── Tri : plus de résultats en premier ────────────────────
        table.sort(charResults, function(a, b) return a.count > b.count end)

        -- ── Construction des cartes ────────────────────────────────
        local cardW       = resultHolder:GetWidth()
        if cardW <= 0 then cardW = ns.GetContentWidth() - SIDE_PAD * 2 end
        local iconsPerRow = math.max(1, math.floor((cardW - CARD_PAD * 2) / (ICON_SZ + ICON_GAP)))

        local y = -26  -- commence sous le totalLabel

        for _, entry in ipairs(charResults) do
            local c      = entry.classColor
            local items  = entry.items

            -- Hauteur de la carte
            local iconRows = math.ceil(entry.count / iconsPerRow)
            local cardH    = 28 + CARD_PAD + iconRows * (ICON_SZ + ICON_GAP) + CARD_PAD

            -- ── Fond de la carte ────────────────────────────────────
            -- Teinte légèrement colorée par le thème
            local card = CreateFrame("Frame", nil, resultHolder, "BackdropTemplate")
            card:SetSize(cardW, cardH)
            card:SetPoint("TOPLEFT", resultHolder, "TOPLEFT", 0, y)
            ns.Skin.Frame(card, "card")

            -- ── Nom du personnage ─────────────────────────────────────
            local nameTxt = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameTxt:SetPoint("TOPLEFT", 10, -6)
            local classHex = string.format("%02x%02x%02x",
                math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
            nameTxt:SetText(
                "|cff" .. classHex .. entry.charName .. "|r"
                .. "  |cff" .. ns.ColorHex(ns.Theme.textDim) .. entry.realmName .. "|r"
            )

            -- ── Compteur à droite ─────────────────────────────────────
            local cntTxt = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cntTxt:SetPoint("RIGHT", card, "RIGHT", -10, (cardH * 0.5) - (cardH - 14))
            cntTxt:SetPoint("TOP",   card, "TOP",    0,  -6)
            cntTxt:SetTextColor(unpack(ns.Theme.textDim))
            cntTxt:SetText(entry.count
                .. " " .. ns.L("SEARCH_RESULTS"))
            cntTxt:SetJustifyH("RIGHT")

            -- ── Séparateur ───────────────────────────────────────────
            local sep = card:CreateTexture(nil, "OVERLAY")
            sep:SetHeight(1)
            sep:SetPoint("TOPLEFT",  card, "TOPLEFT",   3, -26)
            sep:SetPoint("TOPRIGHT", card, "TOPRIGHT",  -3, -26)
            sep:SetColorTexture(tr, tg, tb, 0.25)

            -- ── Icônes des items ──────────────────────────────────────
            local col = 0
            local row = 0
            for id, agg in pairs(items) do
                local stack = agg.count
                local bx = CARD_PAD + col * (ICON_SZ + ICON_GAP)
                local by = -(28 + CARD_PAD + row * (ICON_SZ + ICON_GAP))

                local btn = CreateFrame("Button", nil, card)
                btn:SetSize(ICON_SZ, ICON_SZ)
                btn:SetPoint("TOPLEFT", card, "TOPLEFT", bx, by)

                -- Fond sombre derrière l'icône
                local iconBg = btn:CreateTexture(nil, "BACKGROUND")
                iconBg:SetAllPoints()
                iconBg:SetColorTexture(0, 0, 0, 0.55)

                -- Texture de l'item
                local ico = btn:CreateTexture(nil, "BORDER")
                ico:SetPoint("TOPLEFT",     btn, "TOPLEFT",     1, -1)
                ico:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
                ico:SetTexture(ns.GetIcon(id))
                ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                -- Quantité si > 1
                if stack > 1 then
                    local stk = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                    stk:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 3)
                    stk:SetText(stack)
                end

                -- Tooltip
                local capturedID, capturedLink = id, agg.link
                btn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if capturedLink then
                        GameTooltip:SetHyperlink(capturedLink)
                    else
                        GameTooltip:SetItemByID(capturedID)
                    end
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                col = col + 1
                if col >= iconsPerRow then
                    col = 0
                    row = row + 1
                end
            end

            y = y - cardH - 8
        end

        -- Mise à jour hauteur totale du scroll
        resultHolder:SetHeight(math.abs(y) + 10)
        ns.scrollChild:SetHeight(math.abs(TOP_OFFSET) + math.abs(y) + 10 + 50)
    end

    -- ── Debounce texte ─────────────────────────────────────────────
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        if AVL_searchTimer then AVL_searchTimer:Cancel(); AVL_searchTimer = nil end
        AVL_searchTimer = C_Timer.NewTimer(0.30, function()
            AVL_searchTimer = nil
            local txt     = self:GetText()
            local isEmpty = (txt == "" or txt:lower() == ns.L("SEARCH_TEXT"):lower())
            local hasCat  = ns.activeFilterCat and ns.activeFilterCat.key ~= "ALL"
            if isEmpty and not hasCat then
                ClearResults()
                ns.scrollChild:SetHeight(120)
            else
                AVL_SearchRebuild(isEmpty and "" or txt, ns.activeFilterCat)
            end
        end)
    end)

    -- Hauteur initiale (barre seule, pas encore de résultats)
    ns.scrollChild:SetHeight(120)
end
