local addonName, pluginNs = ...

-- ====================================================
-- GRAPHIQUE (temps de jeu par classe)
-- Anciennement AltViewerLog/fonctionnalite/Graph.lua — extrait en
-- dépendance isolée. Lit les données via _G.ViewerLogAPI /
-- ViewerLogDB (même source que le core) et rend dans core.scrollChild.
--
-- Éléments poolés : ShowGraph() peut être rappelé à chaque
-- redimensionnement de la fenêtre ; sans pool, chaque passe ajoutait
-- des régions à core.scrollChild sans jamais les libérer.
-- ====================================================

local core = _G.AltViewerLogAPI

local BAR_W = 550

-- Éléments réutilisés entre deux passes de rendu.
local titleFS, noDataFS
local rowPool = {}   -- { { label, bgBar, bar }, ... }

-- Rendu principal du graphique.
function pluginNs.ShowGraph()
    if not core or not core.scrollChild then return end

    core.currentView       = pluginNs.ShowGraph
    core.currentViewIsBank = false
    core.ClearContent()

    local sc = core.scrollChild

    if not titleFS then
        titleFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    end
    titleFS:ClearAllPoints()
    titleFS:SetPoint("TOPLEFT", 20, -20)
    titleFS:SetText(pluginNs.L("STATS_TITLE"))
    titleFS:Show()

    local function ShowNoData()
        if not noDataFS then
            noDataFS = sc:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        end
        noDataFS:ClearAllPoints()
        noDataFS:SetPoint("TOP", 0, -100)
        noDataFS:SetText(pluginNs.L("NO_DATA"))
        noDataFS:Show()
        sc:SetHeight(200)
    end

    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not _G.ViewerLogDB then
        ShowNoData()
        return
    end

    -- Agrégation du temps joué par classe (tous royaumes).
    local classTotals = {}
    for realmName, realmData in pairs(ViewerLogDB) do
        if vlAPI.IsRealm(realmName, realmData) then
            for _, charData in pairs(realmData) do
                if type(charData) == "table" and charData.class then
                    classTotals[charData.class] =
                        (classTotals[charData.class] or 0) + (charData.timePlayed or 0)
                end
            end
        end
    end

    local maxTime, sorted = 0, {}
    for cls, t in pairs(classTotals) do
        sorted[#sorted + 1] = { class = cls, time = t }
        if t > maxTime then maxTime = t end
    end
    table.sort(sorted, function(a, b) return a.time > b.time end)

    if noDataFS then noDataFS:Hide() end

    if maxTime == 0 then
        ShowNoData()
        return
    end

    local offsetY = -80
    for i, info in ipairs(sorted) do
        local color = RAID_CLASS_COLORS[info.class] or { r = 0.5, g = 0.5, b = 0.5 }

        local slot = rowPool[i]
        if not slot then
            slot = {}
            slot.label = sc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

            slot.bgBar = CreateFrame("Frame", nil, sc, "BackdropTemplate")
            slot.bgBar:SetSize(BAR_W, 15)
            slot.bgBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            slot.bar = CreateFrame("Frame", nil, slot.bgBar, "BackdropTemplate")
            slot.bar:SetHeight(15)
            slot.bar:SetPoint("LEFT")
            slot.bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            rowPool[i] = slot
        end

        slot.label:ClearAllPoints()
        slot.label:SetPoint("TOPLEFT", 25, offsetY)
        slot.label:SetText(string.format("%s : %s",
            pluginNs.L("CLASS_" .. info.class), core.FormatTime(info.time)))
        slot.label:Show()

        slot.bgBar:ClearAllPoints()
        slot.bgBar:SetPoint("TOPLEFT", 25, offsetY - 18)
        slot.bgBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        slot.bgBar:Show()

        slot.bar:SetWidth(math.max((info.time / maxTime) * BAR_W, 1))
        slot.bar:SetBackdropColor(color.r, color.g, color.b, 1)
        slot.bar:Show()

        offsetY = offsetY - 50
    end

    -- Masque les rangées en trop (moins de classes qu'à une passe précédente).
    for i = #sorted + 1, #rowPool do
        local slot = rowPool[i]
        slot.label:Hide()
        slot.bgBar:Hide()
        slot.bar:Hide()
    end

    sc:SetHeight(math.abs(offsetY) + 50)
end
