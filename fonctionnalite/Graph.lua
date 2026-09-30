local addonName, ns = ...

-- ====================================================
-- GRAPHIQUE (temps de jeu par classe)
-- Extrait de Views.lua
-- ====================================================

-- ====================================================
-- Graphique

function ns.ShowGraph()
    ns.currentView = ns.ShowGraph
    ns.currentViewIsBank = false
    ns.ClearContent()

    local title = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20); title:SetText(ns.L("STATS_TITLE"))

    -- Les données (timePlayed, class) sont dans ViewerLogDB depuis la migration.
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not ViewerLogDB then
        local noData = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        noData:SetPoint("TOP", 0, -100); noData:SetText(ns.L("NO_DATA"))
        return
    end

    local classTotals = {}
    for realmName, realmData in pairs(ViewerLogDB) do
        if vlAPI.IsRealm(realmName, realmData) then
            for _, charData in pairs(realmData) do
                if type(charData) == "table" and charData.class then
                    classTotals[charData.class] = (classTotals[charData.class] or 0) + (charData.timePlayed or 0)
                end
            end
        end
    end

    local maxTime, sorted = 0, {}
    for cls, t in pairs(classTotals) do
        table.insert(sorted, { class = cls, time = t })
        if t > maxTime then maxTime = t end
    end
    table.sort(sorted, function(a, b) return a.time > b.time end)

    if maxTime == 0 then
        local noData = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        noData:SetPoint("TOP", 0, -100); noData:SetText(ns.L("NO_DATA"))
        return
    end

    local offsetY = -80
    for _, info in ipairs(sorted) do
        local color = RAID_CLASS_COLORS[info.class] or { r = 0.5, g = 0.5, b = 0.5 }
        local label = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 25, offsetY)
        label:SetText(string.format("%s : %s", ns.L("CLASS_" .. info.class), ns.FormatTime(info.time)))

        local bgBar = CreateFrame("Frame", nil, ns.scrollChild, "BackdropTemplate")
        bgBar:SetSize(550, 15); bgBar:SetPoint("TOPLEFT", 25, offsetY - 18)
        bgBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        bgBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

        local bar = CreateFrame("Frame", nil, bgBar, "BackdropTemplate")
        bar:SetSize(math.max((info.time / maxTime) * 550, 1), 15); bar:SetPoint("LEFT")
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        bar:SetBackdropColor(color.r, color.g, color.b, 1)

        offsetY = offsetY - 50
    end
    ns.scrollChild:SetHeight(math.abs(offsetY) + 50)
end
