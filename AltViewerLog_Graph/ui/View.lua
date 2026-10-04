local addonName, pluginNs = ...

-- ====================================================
-- GRAPHIQUE (temps de jeu par classe)
-- Lit ViewerLogDB via _G.ViewerLogAPI et rend dans core.scrollChild.
-- Un seul frame racine, créé une fois puis réutilisé : ShowGraph()
-- peut être rappelé à chaque redimensionnement.
-- ====================================================

local core = _G.AltViewerLogAPI

local BAR_H, ROW_H = 14, 36
local selectedRealm = nil   -- nil = tous les serveurs

local root, ui = nil, nil

local function Build(sc)
    root = CreateFrame("Frame", nil, sc)
    root:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
    root:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, 0)
    ui = { rows = {}, cards = {} }

    ui.title = root:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    ui.title:SetPoint("TOPLEFT", 16, -12)
    ui.sub = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.sub:SetPoint("TOPLEFT", 16, -42)

    -- Sélecteur de serveur (liste simple, une entrée par serveur)
    ui.realmBtn = CreateFrame("Button", nil, root, "BackdropTemplate")
    ui.realmBtn:SetSize(170, 28)
    ui.realmBtn:SetPoint("TOPRIGHT", -16, -14)
    core.Skin.Button(ui.realmBtn)
    ui.realmFS = ui.realmBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.realmFS:SetPoint("CENTER", -8, 0)
    ui.realmArrow = ui.realmBtn:CreateTexture(nil, "OVERLAY")
    ui.realmArrow:SetSize(14, 14)
    ui.realmArrow:SetPoint("LEFT", ui.realmFS, "RIGHT", 4, 0)
    ui.realmArrow:SetAtlas("housing-floor-arrow-down-default")

    ui.menu = CreateFrame("Frame", nil, root, "BackdropTemplate")
    ui.menu:SetPoint("TOPRIGHT", ui.realmBtn, "BOTTOMRIGHT", 0, -2)
    ui.menu:SetFrameLevel(root:GetFrameLevel() + 20)
    core.Skin.Frame(ui.menu, "panel")
    ui.menu:Hide()
    ui.menuBtns = {}

    ui.rule = core.Skin.Rule(root)
    ui.rule:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -64)
    ui.rule:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -64)

    -- 3 cartes de synthèse
    for i = 1, 3 do
        local c = CreateFrame("Frame", nil, root, "BackdropTemplate")
        c:SetHeight(64)
        core.Skin.Frame(c, "card")
        c.label = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        c.label:SetPoint("TOPLEFT", 14, -12)
        c.value = c:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        c.value:SetPoint("TOPLEFT", 14, -30)
        ui.cards[i] = c
    end

    -- Panneau des barres
    ui.panel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    core.Skin.Frame(ui.panel, "card")

    ui.noData = root:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ui.noData:SetPoint("TOP", 0, -140)
end

local function SetRealm(realm)
    selectedRealm = realm
    ui.menu:Hide()
    pluginNs.ShowGraph()
end

local function FillMenu(realms)
    local list = { false }                   -- false = « tous »
    for _, r in ipairs(realms) do list[#list + 1] = r end
    for i, r in ipairs(list) do
        local b = ui.menuBtns[i]
        if not b then
            b = CreateFrame("Button", nil, ui.menu, "BackdropTemplate")
            b:SetSize(166, 24)
            core.Skin.Button(b)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            b.fs:SetPoint("CENTER")
            ui.menuBtns[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOP", ui.menu, "TOP", 0, -3 - (i - 1) * 26)
        b.fs:SetText(r or pluginNs.L("ALL_REALMS"))
        b:SetScript("OnClick", function() SetRealm(r or nil) end)
        b:Show()
    end
    for i = #list + 1, #ui.menuBtns do ui.menuBtns[i]:Hide() end
    ui.menu:SetSize(172, #list * 26 + 6)
end

function pluginNs.ShowGraph()
    if not core or not core.scrollChild then return end
    core.currentView       = pluginNs.ShowGraph
    core.currentViewIsBank = false
    core.ClearContent()

    local sc = core.scrollChild
    if not root then Build(sc) end
    root:Show()
    ui.menu:Hide()

    local T = core.Theme
    ui.title:SetText(pluginNs.L("STATS_HEADING"))
    ui.title:SetTextColor(unpack(T.heading))
    ui.sub:SetText(pluginNs.L("STATS_SUB"))
    ui.sub:SetTextColor(unpack(T.textDim))

    local vlAPI = _G.ViewerLogAPI
    local hasDB = vlAPI and _G.ViewerLogDB
    local realms, classTotals, charCount, total = {}, {}, 0, 0
    if hasDB then
        for realmName, realmData in pairs(ViewerLogDB) do
            if vlAPI.IsRealm(realmName, realmData) then
                realms[#realms + 1] = realmName
                if not selectedRealm or selectedRealm == realmName then
                    for _, charData in pairs(realmData) do
                        if type(charData) == "table" and charData.class then
                            local t = charData.timePlayed or 0
                            classTotals[charData.class] = (classTotals[charData.class] or 0) + t
                            total = total + t
                            charCount = charCount + 1
                        end
                    end
                end
            end
        end
    end
    table.sort(realms)
    if selectedRealm and not tContains(realms, selectedRealm) then selectedRealm = nil end

    ui.realmFS:SetText(selectedRealm or pluginNs.L("ALL_REALMS"))
    ui.realmFS:SetTextColor(unpack(T.gold))
    ui.realmBtn:SetScript("OnClick", function()
        if ui.menu:IsShown() then ui.menu:Hide() else FillMenu(realms); ui.menu:Show() end
    end)

    local sorted = {}
    for cls, t in pairs(classTotals) do sorted[#sorted + 1] = { class = cls, time = t } end
    table.sort(sorted, function(a, b) return a.time > b.time end)

    local W = root:GetWidth()
    if W <= 0 then W = core.GetContentWidth() end

    if total <= 0 then
        for _, c in ipairs(ui.cards) do c:Hide() end
        ui.panel:Hide()
        for _, r in ipairs(ui.rows) do r.frame:Hide() end
        ui.noData:SetText(pluginNs.L("NO_DATA"))
        ui.noData:Show()
        root:SetHeight(220)
        sc:SetHeight(220)
        return
    end
    ui.noData:Hide()

    -- Cartes : temps total / classe la plus jouée / personnages
    local gap = 14
    local cw = math.floor((W - 32 - gap * 2) / 3)
    local topCls = sorted[1].class
    local tc = RAID_CLASS_COLORS[topCls] or { r = 1, g = 1, b = 1 }
    local cardDefs = {
        { pluginNs.L("STAT_TOTAL_TIME"), core.FormatTime(total), T.gold },
        { pluginNs.L("STAT_TOP_CLASS"),  pluginNs.L("CLASS_" .. topCls), { tc.r, tc.g, tc.b } },
        { pluginNs.L("STAT_CHARS"),      tostring(charCount), T.text },
    }
    for i, c in ipairs(ui.cards) do
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", root, "TOPLEFT", 16 + (i - 1) * (cw + gap), -78)
        c:SetWidth(cw)
        c.label:SetText(cardDefs[i][1]:upper())
        c.label:SetTextColor(unpack(T.textDim))
        c.value:SetText(cardDefs[i][2])
        c.value:SetTextColor(unpack(cardDefs[i][3]))
        c:Show()
    end

    -- Panneau + rangées
    local panelH = #sorted * ROW_H + 20
    ui.panel:ClearAllPoints()
    ui.panel:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -156)
    ui.panel:SetSize(W - 32, panelH)
    ui.panel:Show()

    local maxTime = sorted[1].time
    local NAME_W, TIME_W, PCT_W = 170, 110, 56
    local barW = math.max(60, W - 32 - 20 - NAME_W - TIME_W - PCT_W - 20)

    for i, info in ipairs(sorted) do
        local r = ui.rows[i]
        if not r then
            r = {}
            r.frame = CreateFrame("Frame", nil, ui.panel)
            r.frame:SetHeight(ROW_H)
            r.name = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            r.name:SetPoint("LEFT", 0, 0)
            r.name:SetWidth(NAME_W - 10)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            r.bg = r.frame:CreateTexture(nil, "BACKGROUND")
            r.bg:SetHeight(BAR_H)
            r.fill = r.frame:CreateTexture(nil, "ARTWORK")
            r.fill:SetHeight(BAR_H)
            r.time = r.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.time:SetJustifyH("RIGHT")
            r.pct = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            r.pct:SetJustifyH("RIGHT")
            ui.rows[i] = r
        end
        local color = RAID_CLASS_COLORS[info.class] or { r = 0.5, g = 0.5, b = 0.5 }
        r.frame:ClearAllPoints()
        r.frame:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 10, -10 - (i - 1) * ROW_H)
        r.frame:SetWidth(W - 32 - 20)

        r.name:SetText(pluginNs.L("CLASS_" .. info.class))
        r.name:SetTextColor(color.r, color.g, color.b)

        r.bg:ClearAllPoints()
        r.bg:SetPoint("LEFT", r.frame, "LEFT", NAME_W, 0)
        r.bg:SetWidth(barW)
        r.bg:SetColorTexture(unpack(T.roles.input[1]))
        r.fill:ClearAllPoints()
        r.fill:SetPoint("LEFT", r.bg, "LEFT", 0, 0)
        r.fill:SetWidth(math.max(2, barW * info.time / maxTime))
        r.fill:SetColorTexture(color.r, color.g, color.b, 1)

        r.time:ClearAllPoints()
        r.time:SetPoint("LEFT", r.bg, "RIGHT", 8, 0)
        r.time:SetWidth(TIME_W - 8)
        r.time:SetText(core.FormatTime(info.time))
        r.time:SetTextColor(unpack(T.text))
        r.pct:ClearAllPoints()
        r.pct:SetPoint("LEFT", r.time, "RIGHT", 4, 0)
        r.pct:SetWidth(PCT_W - 4)
        r.pct:SetText(string.format("%d%%", math.floor(info.time / total * 100 + 0.5)))
        r.pct:SetTextColor(unpack(T.textDim))
        r.frame:Show()
    end
    for i = #sorted + 1, #ui.rows do ui.rows[i].frame:Hide() end

    local h = 156 + panelH + 20
    root:SetHeight(h)
    sc:SetHeight(h)
end
