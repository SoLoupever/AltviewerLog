local addonName, pluginNs = ...
local core  = _G.AltViewerLogAPI
local vlAPI = _G.ViewerLogAPI   -- accès en lecture à ViewerLogDB + IsRealm()

-- BVL compat : AltViewerLog n'expose pas GetContentWidth — fallback 660px
local function GetContentWidth()
    return core.GetContentWidth and core.GetContentWidth() or 660
end

local function GetProfDisplayName(name)
    if not name then return name end
    local lang = AltViewerLogDB
          and AltViewerLogDB.settings
          and AltViewerLogDB.settings.lang
    if lang == "enUS" and pluginNs.PROF_EN_NAME then
        local en = pluginNs.PROF_EN_NAME[name]
        if en then return en end
        local key = pluginNs.PROF_RECIPE_KEY and pluginNs.PROF_RECIPE_KEY[name]
        if key then return pluginNs.PROF_EN_NAME[key] or name end
    elseif lang == "frFR" and pluginNs.PROF_FR_NAME then
        local fr = pluginNs.PROF_FR_NAME[name]
        if fr then return fr end
    end
    return name
end

pluginNs.isViewActive = false
pluginNs.recipeExpanded  = pluginNs.recipeExpanded  or {}

local function recipeKey(realmName, charName, profName)
    return realmName .. "||" .. charName .. "||" .. profName
end

-- ====================================================
-- POOLS — ShowProfessions() est potentiellement rappelé souvent
-- (scan, toggle de filtre, expand/collapse recette) et itère
-- royaume × personnage × métier × palier : sans pool, chaque appel
-- recréait tous les objets et abandonnait les précédents. Même
-- principe que Reput/GuildeLog : compteur remis à 0 en tête de
-- ShowProfessions(), incrémenté à chaque widget dessiné, tout
-- slot au-delà du compteur final est masqué par HideUnusedPools().
-- Les closures qui dépendent des données de la ligne (tooltips,
-- OnClick) sont réassignées à chaque passage, pas seulement
-- repositionnées.
-- ====================================================
local woodBtnPool,      woodBtnUsed      = {}, 0
local charRowPool,      charRowUsed      = {}, 0
local profRowPool,      profRowUsed      = {}, 0
local tierBarPool,      tierBarUsed      = {}, 0
local recipeTogglePool, recipeToggleUsed = {}, 0

local function HideUnusedPools()
    for i = woodBtnUsed + 1, #woodBtnPool do
        local s = woodBtnPool[i]
        s.btn:Hide()
    end
    for i = charRowUsed + 1, #charRowPool do
        local s = charRowPool[i]
        s.charBlock:Hide()
        if s.charSep then s.charSep:Hide() end
    end
    for i = profRowUsed + 1, #profRowPool do
        local s = profRowPool[i]
        s.ic:Hide(); s.pName:Hide()
        if s.profSep then s.profSep:Hide() end
    end
    for i = tierBarUsed + 1, #tierBarPool do
        local s = tierBarPool[i]
        s.bg:Hide()
    end
    for i = recipeToggleUsed + 1, #recipeTogglePool do
        local s = recipeTogglePool[i]
        s.toggleBtn:Hide()
    end
    if pluginNs.HideUnusedRecipeBarPools then pluginNs.HideUnusedRecipeBarPools() end
end

-- ====================================================
-- POPUP FILTRE DES EXTENSIONS
-- Créé une seule fois, parenté à core.mainFrame.
-- Auto-masqué quand la fenêtre principale se ferme.
-- ====================================================
local expansionFilterPopup = nil

local function GetOrCreateExpansionFilterPopup()
    if expansionFilterPopup then return expansionFilterPopup end

    local pop = CreateFrame("Frame", "BVLExpansionFilterPopup", core.mainFrame, "BackdropTemplate")
    pop:SetFrameStrata("DIALOG")
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", pop.StartMoving)
    pop:SetScript("OnDragStop",  pop.StopMovingOrSizing)
    pop:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pop:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
    pop:SetBackdropBorderColor(0.45, 0.38, 0.18, 1)
    pop:SetClampedToScreen(true)
    pop:Hide()

    local titleFS = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", 0, -12)
    titleFS:SetText(core.L("EXPANSION_FILTER_TITLE"))
    titleFS:SetTextColor(1, 0.85, 0.20)

    local sep = pop:CreateTexture(nil, "ARTWORK")
    sep:SetSize(220, 1)
    sep:SetPoint("TOP", 0, -32)
    sep:SetColorTexture(1, 0.82, 0, 0.25)

    local ITEM_H = 22
    local rows   = {}
    -- Bascule "Tout afficher / Tout masquer" (assigné après la création du bouton).
    local updateShowAllExp

    for i, exp in ipairs(pluginNs.EXPANSION_LIST) do
        local color = pluginNs.GetTierColor(exp.name)
        local row   = CreateFrame("Frame", nil, pop)
        row:SetSize(230, ITEM_H)
        row:SetPoint("TOPLEFT", 14, -40 - (i - 1) * ITEM_H)

        local dot = row:CreateTexture(nil, "ARTWORK")
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", 0, 0)
        dot:SetColorTexture(color.r, color.g, color.b, 1)

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", 16, 0)
        nameFS:SetWidth(150)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetTextColor(color.r * 0.9, color.g * 0.9, color.b * 0.9)
        nameFS:SetText(exp.name)

        local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
        btn:SetSize(38, 16)
        btn:SetPoint("RIGHT", 0, 0)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                          edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })

        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnLabel:SetPoint("CENTER", 0, 0)

        local capturedName  = exp.name
        local capturedColor = color
        local capturedDot   = dot
        local capturedLabel = nameFS

        local function RefreshRow()
            AltViewerLogDB.hiddenExpansions = AltViewerLogDB.hiddenExpansions or {}
            local hidden = AltViewerLogDB.hiddenExpansions[capturedName]
            if hidden then
                btn:SetBackdropColor(0.25, 0.06, 0.06, 1)
                btn:SetBackdropBorderColor(0.55, 0.10, 0.10, 1)
                btnLabel:SetText("|cffff6666OFF|r")
                capturedDot:SetColorTexture(capturedColor.r * 0.3, capturedColor.g * 0.3, capturedColor.b * 0.3, 0.5)
                capturedLabel:SetTextColor(0.30, 0.30, 0.30)
            else
                btn:SetBackdropColor(0.06, 0.22, 0.06, 1)
                btn:SetBackdropBorderColor(0.15, 0.50, 0.15, 1)
                btnLabel:SetText("|cff55ff55ON |r")
                capturedDot:SetColorTexture(capturedColor.r, capturedColor.g, capturedColor.b, 1)
                capturedLabel:SetTextColor(capturedColor.r * 0.9, capturedColor.g * 0.9, capturedColor.b * 0.9)
            end
        end

        row.RefreshRow = RefreshRow
        table.insert(rows, row)

        btn:SetScript("OnClick", function()
            AltViewerLogDB.hiddenExpansions = AltViewerLogDB.hiddenExpansions or {}
            local hidden = AltViewerLogDB.hiddenExpansions[capturedName]
            AltViewerLogDB.hiddenExpansions[capturedName] = (not hidden) or nil
            RefreshRow()
            if updateShowAllExp then updateShowAllExp() end
            if pluginNs.isViewActive and core.mainFrame and core.mainFrame:IsShown() then
                pluginNs.ShowProfessions()
            end
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.15, 1)
        end)
        btn:SetScript("OnLeave", function() RefreshRow() end)
    end

    -- Bouton bascule Tout afficher / Tout masquer.
    -- Tout affiché (rien de masqué) → libellé "Tout masquer" (le clic masque tout).
    -- Au moins une extension masquée → libellé "Tout afficher" (le clic ré-affiche tout).
    local showAllBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
    showAllBtn:SetSize(100, 20)
    showAllBtn:SetPoint("BOTTOMLEFT", 14, 12)
    showAllBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                              edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local showAllLbl = showAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showAllLbl:SetPoint("CENTER")

    -- Rien de masqué = tout affiché.
    local function AllExpShown()
        local h = AltViewerLogDB and AltViewerLogDB.hiddenExpansions
        return not h or next(h) == nil
    end

    updateShowAllExp = function()
        if AllExpShown() then
            showAllBtn:SetBackdropColor(0.20, 0.06, 0.06, 1)
            showAllBtn:SetBackdropBorderColor(0.55, 0.10, 0.10, 1)
            showAllLbl:SetText(core.L("EXPANSION_HIDE_ALL") or "Tout masquer")
        else
            showAllBtn:SetBackdropColor(0.08, 0.18, 0.08, 1)
            showAllBtn:SetBackdropBorderColor(0.20, 0.45, 0.20, 1)
            showAllLbl:SetText(core.L("EXPANSION_SHOW_ALL") or "Tout afficher")
        end
    end
    pop.UpdateShowAll = updateShowAllExp

    showAllBtn:SetScript("OnClick", function()
        if AllExpShown() then
            AltViewerLogDB.hiddenExpansions = {}
            for _, exp in ipairs(pluginNs.EXPANSION_LIST) do
                AltViewerLogDB.hiddenExpansions[exp.name] = true
            end
        else
            AltViewerLogDB.hiddenExpansions = {}
        end
        for _, row in ipairs(rows) do row.RefreshRow() end
        updateShowAllExp()
        if pluginNs.isViewActive and core.mainFrame and core.mainFrame:IsShown() then
            pluginNs.ShowProfessions()
        end
    end)

    -- Bouton Fermer
    local closeBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
    closeBtn:SetSize(60, 20)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    closeBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    closeBtn:SetBackdropColor(0.20, 0.20, 0.20, 1)
    closeBtn:SetBackdropBorderColor(0.40, 0.40, 0.40, 1)
    local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeLbl:SetPoint("CENTER")
    closeLbl:SetText(core.L("EXPANSION_CLOSE"))
    closeBtn:SetScript("OnClick", function() pop:Hide() end)

    local totalH = 50 + #pluginNs.EXPANSION_LIST * ITEM_H + 40
    pop:SetSize(260, totalH)
    pop.rows = rows
    expansionFilterPopup = pop
    return pop
end

local function ToggleExpansionFilterPopup(anchorFrame)
    local pop = GetOrCreateExpansionFilterPopup()
    if pop:IsShown() then
        pop:Hide()
    else
        AltViewerLogDB.hiddenExpansions = AltViewerLogDB.hiddenExpansions or {}
        for _, row in ipairs(pop.rows) do row.RefreshRow() end
        if pop.UpdateShowAll then pop.UpdateShowAll() end
        pop:ClearAllPoints()
        pop:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
        pop:Show()
    end
end

function pluginNs.CloseExpansionFilterPopup()
    if expansionFilterPopup and expansionFilterPopup:IsShown() then
        expansionFilterPopup:Hide()
    end
end

-- ====================================================
-- POPUP FILTRE DES MÉTIERS
-- Copie exacte du mécanisme du popup extensions :
--   • Créé une seule fois (jamais détruit/recréé)
--   • Parenté à core.mainFrame → auto-masqué à la fermeture
--   • Même Toggle / Close public / ClampedToScreen
-- Seul l'intérieur change : liste des métiers de la DB
-- avec toggle ON/OFF dans AltViewerLogDB.hiddenProfessions.
-- ====================================================
local professionFilterPopup = nil

local function GetOrCreateProfessionFilterPopup()
    if professionFilterPopup then return professionFilterPopup end

    -- Collecter une fois les métiers présents dans ViewerLogDB
    local seen, profNames = {}, {}
    local vlDB = _G.ViewerLogDB
    if vlDB and vlAPI then
        for realmName, realmData in pairs(vlDB) do
            if vlAPI.IsRealm(realmName, realmData) then
                for _, charData in pairs(realmData) do
                    if type(charData) == "table" and charData.professions then
                        for _, p in ipairs(charData.professions) do
                            if p.name and not seen[p.name] then
                                seen[p.name] = true
                                table.insert(profNames, p.name)
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(profNames)
    if #profNames == 0 then return nil end

    -- ── Frame : même construction que expansionFilterPopup ──────────────
    local pop = CreateFrame("Frame", "BVLProfessionFilterPopup", core.mainFrame, "BackdropTemplate")
    pop:SetFrameStrata("DIALOG")
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", pop.StartMoving)
    pop:SetScript("OnDragStop",  pop.StopMovingOrSizing)
    pop:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    pop:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
    pop:SetBackdropBorderColor(0.20, 0.38, 0.60, 1)
    pop:SetClampedToScreen(true)
    pop:Hide()

    -- ── Titre ────────────────────────────────────────────────────────────
    local titleFS = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("TOP", 0, -12)
    titleFS:SetText(core.L("PROF_FILTER_TITLE"))
    titleFS:SetTextColor(0.55, 0.80, 1.0)

    local sep = pop:CreateTexture(nil, "ARTWORK")
    sep:SetSize(220, 1)
    sep:SetPoint("TOP", 0, -32)
    sep:SetColorTexture(0.40, 0.65, 1.0, 0.25)

    -- ── Lignes ON/OFF ────────────────────────────────────────────────────
    local ITEM_H = 22
    local rows   = {}
    -- Bascule "Tout afficher / Tout masquer" (assigné après la création du bouton).
    local updateShowAllProf

    for i, profName in ipairs(profNames) do
        local row = CreateFrame("Frame", nil, pop)
        row:SetSize(230, ITEM_H)
        row:SetPoint("TOPLEFT", 14, -40 - (i - 1) * ITEM_H)

        local dot = row:CreateTexture(nil, "ARTWORK")
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", 0, 0)
        dot:SetColorTexture(0.45, 0.70, 1.0, 1)

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", 16, 0)
        nameFS:SetWidth(150)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetTextColor(0.75, 0.90, 1.0)
        nameFS:SetText(GetProfDisplayName(profName))

        local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
        btn:SetSize(38, 16)
        btn:SetPoint("RIGHT", 0, 0)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                          edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })

        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnLabel:SetPoint("CENTER", 0, 0)

        local capturedName  = profName
        local capturedDot   = dot
        local capturedLabel = nameFS

        local function RefreshRow()
            AltViewerLogDB.hiddenProfessions = AltViewerLogDB.hiddenProfessions or {}
            local hidden = AltViewerLogDB.hiddenProfessions[capturedName]
            if hidden then
                btn:SetBackdropColor(0.25, 0.06, 0.06, 1)
                btn:SetBackdropBorderColor(0.55, 0.10, 0.10, 1)
                btnLabel:SetText("|cffff6666OFF|r")
                capturedDot:SetColorTexture(0.15, 0.15, 0.15, 0.5)
                capturedLabel:SetTextColor(0.30, 0.30, 0.30)
            else
                btn:SetBackdropColor(0.06, 0.22, 0.06, 1)
                btn:SetBackdropBorderColor(0.15, 0.50, 0.15, 1)
                btnLabel:SetText("|cff55ff55ON |r")
                capturedDot:SetColorTexture(0.45, 0.70, 1.0, 1)
                capturedLabel:SetTextColor(0.75, 0.90, 1.0)
            end
        end

        row.RefreshRow = RefreshRow
        table.insert(rows, row)

        btn:SetScript("OnClick", function()
            AltViewerLogDB.hiddenProfessions = AltViewerLogDB.hiddenProfessions or {}
            local hidden = AltViewerLogDB.hiddenProfessions[capturedName]
            AltViewerLogDB.hiddenProfessions[capturedName] = (not hidden) or nil
            RefreshRow()
            if updateShowAllProf then updateShowAllProf() end
            if pluginNs.isViewActive and core.mainFrame and core.mainFrame:IsShown() then
                pluginNs.ShowProfessions()
            end
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.15, 0.15, 0.15, 1)
        end)
        btn:SetScript("OnLeave", function() RefreshRow() end)
    end

    -- ── Bouton bascule Tout afficher / Tout masquer ──────────────────────
    -- Rien de masqué (tout affiché) → "Tout masquer" (le clic masque tout).
    -- Au moins un métier masqué → "Tout afficher" (le clic ré-affiche tout).
    local showAllBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
    showAllBtn:SetSize(100, 20)
    showAllBtn:SetPoint("BOTTOMLEFT", 14, 12)
    showAllBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                              edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    local showAllLbl = showAllBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    showAllLbl:SetPoint("CENTER")

    -- Rien de masqué = tout affiché.
    local function AllProfShown()
        local h = AltViewerLogDB and AltViewerLogDB.hiddenProfessions
        return not h or next(h) == nil
    end

    updateShowAllProf = function()
        if AllProfShown() then
            showAllBtn:SetBackdropColor(0.20, 0.06, 0.06, 1)
            showAllBtn:SetBackdropBorderColor(0.55, 0.10, 0.10, 1)
            showAllLbl:SetText(core.L("EXPANSION_HIDE_ALL") or "Tout masquer")
        else
            showAllBtn:SetBackdropColor(0.08, 0.18, 0.08, 1)
            showAllBtn:SetBackdropBorderColor(0.20, 0.45, 0.20, 1)
            showAllLbl:SetText(core.L("EXPANSION_SHOW_ALL") or "Tout afficher")
        end
    end
    pop.UpdateShowAll = updateShowAllProf

    showAllBtn:SetScript("OnClick", function()
        if AllProfShown() then
            AltViewerLogDB.hiddenProfessions = {}
            for _, pName in ipairs(profNames) do
                AltViewerLogDB.hiddenProfessions[pName] = true
            end
        else
            AltViewerLogDB.hiddenProfessions = {}
        end
        for _, row in ipairs(rows) do row.RefreshRow() end
        updateShowAllProf()
        if pluginNs.isViewActive and core.mainFrame and core.mainFrame:IsShown() then
            pluginNs.ShowProfessions()
        end
    end)

    -- ── Bouton Fermer ────────────────────────────────────────────────────
    local closeBtn = CreateFrame("Button", nil, pop, "BackdropTemplate")
    closeBtn:SetSize(60, 20)
    closeBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    closeBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                            edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    closeBtn:SetBackdropColor(0.20, 0.20, 0.20, 1)
    closeBtn:SetBackdropBorderColor(0.40, 0.40, 0.40, 1)
    local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    closeLbl:SetPoint("CENTER")
    closeLbl:SetText(core.L("EXPANSION_CLOSE"))
    closeBtn:SetScript("OnClick", function() pop:Hide() end)

    local totalH = 50 + #profNames * ITEM_H + 40
    pop:SetSize(260, totalH)
    pop.rows = rows
    professionFilterPopup = pop
    return pop
end

-- Même signature que ToggleExpansionFilterPopup — copie carbone
local function ToggleProfessionFilterPopup(anchorFrame)
    local pop = GetOrCreateProfessionFilterPopup()
    if not pop then return end
    if pop:IsShown() then
        pop:Hide()
    else
        AltViewerLogDB.hiddenProfessions = AltViewerLogDB.hiddenProfessions or {}
        for _, row in ipairs(pop.rows) do row.RefreshRow() end
        if pop.UpdateShowAll then pop.UpdateShowAll() end
        pop:ClearAllPoints()
        pop:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
        pop:Show()
    end
end

function pluginNs.CloseProfessionFilterPopup()
    if professionFilterPopup and professionFilterPopup:IsShown() then
        professionFilterPopup:Hide()
    end
end

-- ====================================================
-- HELPERS FILTRAGE (utilisés par ShowProfessions)
-- ====================================================
local function IsProfessionHidden(profName)
    if not AltViewerLogDB or not AltViewerLogDB.hiddenProfessions then return false end
    return AltViewerLogDB.hiddenProfessions[profName] == true
end

local function IsExpansionHidden(tierName)
    if not AltViewerLogDB or not AltViewerLogDB.hiddenExpansions or not tierName then return false end
    local lt = tierName:lower()  -- comparaison insensible à la casse (cf. MatchExpansion)
    for _, exp in ipairs(pluginNs.EXPANSION_LIST) do
        if AltViewerLogDB.hiddenExpansions[exp.name] then
            -- Le nom canonique anglais (cas où le client tourne en anglais)
            if lt:find(exp.name:lower(), 1, true) then return true end
            -- Les alias localisés (ex: client FR -> "Bataille pour Azeroth")
            if exp.aliases then
                for _, alias in ipairs(exp.aliases) do
                    if lt:find(alias:lower(), 1, true) then return true end
                end
            end
        end
    end
    return false
end

-- ====================================================
-- AFFICHAGE PRINCIPAL DE LA VUE MÉTIERS
-- ====================================================
function pluginNs.ShowProfessions()
    pluginNs.isViewActive = true   -- avant ClearContent pour protéger les popups
    pluginNs._refreshing  = true   -- indique au hook ClearContent qu'on se rafraîchit
    core.ClearContent()
    pluginNs._refreshing  = false  -- rafraîchissement terminé

    -- Remis à 0 à chaque rafraîchissement : les boucles ci-dessous les
    -- incrémentent, HideUnusedPools() masque tout au-delà en sortie.
    woodBtnUsed, charRowUsed, profRowUsed, tierBarUsed, recipeToggleUsed = 0, 0, 0, 0, 0
    if pluginNs.ResetRecipeBarPools then pluginNs.ResetRecipeBarPools() end

    if not AltViewerLogDB then HideUnusedPools(); return end
    local vlDB = _G.ViewerLogDB
    if not vlDB then HideUnusedPools(); return end

    -- Les données personnages (class, professions…) vivent dans ViewerLogDB,
    -- pas dans AltViewerLogDB qui n'héberge que les préférences UI.
    local playerClassData = core.realm and core.player
        and vlDB[core.realm]
        and vlDB[core.realm][core.player]
    local playerClassColor = (playerClassData and playerClassData.class and RAID_CLASS_COLORS[playerClassData.class])
        or { r = 1, g = 0.82, b = 0 }

    local contentW = GetContentWidth()

    -- ── Titre + bouton scan ──────────────────────────────────────────────
    local title = core.scrollChild._profTitle
    if not title then
        title = core.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        core.scrollChild._profTitle = title
        title:SetTextColor(1, 0.82, 0)
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText(core.L("BTN_PROFESSIONS"))
    title:Show()

    local scanBtn = core.scrollChild._profScanBtn
    if not scanBtn then
        scanBtn = CreateFrame("Button", nil, core.scrollChild, "BackdropTemplate")
        core.scrollChild._profScanBtn = scanBtn
        scanBtn:SetSize(150, 22)
        scanBtn:SetText(core.L("SCAN_BTN"))
        scanBtn:SetNormalFontObject("GameFontNormalSmall")
        scanBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                              edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        scanBtn:SetBackdropColor(0.20, 0.20, 0.20, 0.85)
        scanBtn:SetBackdropBorderColor(0.40, 0.40, 0.40, 1)
        scanBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.30, 0.30, 0.30, 0.95) end)
        scanBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.20, 0.20, 0.20, 0.85) end)
        scanBtn:SetScript("OnClick", pluginNs.ScanAllProfessions)
    end
    scanBtn:ClearAllPoints()
    scanBtn:SetPoint("LEFT", title, "RIGHT", 15, 0)
    scanBtn:Show()

    -- ── Bouton engrenage : filtre extensions ────────────────────────────
    local filterBtn = core.scrollChild._profFilterBtn
    if not filterBtn then
        filterBtn = CreateFrame("Button", nil, core.scrollChild, "BackdropTemplate")
        core.scrollChild._profFilterBtn = filterBtn
        filterBtn:SetSize(22, 22)
        filterBtn:SetBackdrop({ bgFile   = "Interface\\Buttons\\WHITE8x8",
                                 edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        filterBtn:SetBackdropColor(0.18, 0.15, 0.08, 1)
        filterBtn:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)

        local gearTex = filterBtn:CreateTexture(nil, "ARTWORK")
        filterBtn.gearTex = gearTex
        gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        gearTex:SetSize(16, 16)
        gearTex:SetPoint("CENTER", 0, 0)
        gearTex:SetVertexColor(0.95, 0.82, 0.40)

        filterBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.30, 0.24, 0.10, 1)
            self:SetBackdropBorderColor(0.85, 0.70, 0.25, 1)
            gearTex:SetVertexColor(1, 1, 0.7)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(core.L("EXPANSION_FILTER_TOOLTIP"), 1, 0.85, 0.20)
            GameTooltip:Show()
        end)
        filterBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.18, 0.15, 0.08, 1)
            self:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)
            gearTex:SetVertexColor(0.95, 0.82, 0.40)
            GameTooltip:Hide()
        end)
        filterBtn:SetScript("OnClick", function(self)
            -- Fermer l'autre popup avant d'ouvrir celui-ci
            if professionFilterPopup and professionFilterPopup:IsShown() then
                professionFilterPopup:Hide()
            end
            ToggleExpansionFilterPopup(self)
        end)
    end
    filterBtn:ClearAllPoints()
    filterBtn:SetPoint("LEFT", scanBtn, "RIGHT", 6, 0)
    filterBtn:Show()

    -- ── Bouton marteau : filtre métiers (même mécanisme que engrenage) ───
    local profFilterBtn = core.scrollChild._profFilterBtn2
    if not profFilterBtn then
        profFilterBtn = CreateFrame("Button", nil, core.scrollChild, "BackdropTemplate")
        core.scrollChild._profFilterBtn2 = profFilterBtn
        profFilterBtn:SetSize(22, 22)
        profFilterBtn:SetBackdrop({ bgFile   = "Interface\\Buttons\\WHITE8x8",
                                     edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        profFilterBtn:SetBackdropColor(0.08, 0.12, 0.20, 1)
        profFilterBtn:SetBackdropBorderColor(0.20, 0.38, 0.60, 1)

        local hammerTex = profFilterBtn:CreateTexture(nil, "ARTWORK")
        hammerTex:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
        hammerTex:SetSize(16, 16)
        hammerTex:SetPoint("CENTER", 0, 0)

        profFilterBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.12, 0.20, 0.35, 1)
            self:SetBackdropBorderColor(0.40, 0.65, 1.0, 1)
            hammerTex:SetVertexColor(0.7, 0.9, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(core.L("PROF_FILTER_TT"), 0.55, 0.80, 1.0)
            GameTooltip:Show()
        end)
        profFilterBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.08, 0.12, 0.20, 1)
            self:SetBackdropBorderColor(0.20, 0.38, 0.60, 1)
            hammerTex:SetVertexColor(1, 1, 1)
            GameTooltip:Hide()
        end)
        profFilterBtn:SetScript("OnClick", function(self)
            -- Fermer l'autre popup avant d'ouvrir celui-ci
            if expansionFilterPopup and expansionFilterPopup:IsShown() then
                expansionFilterPopup:Hide()
            end
            ToggleProfessionFilterPopup(self)
        end)
    end
    profFilterBtn:ClearAllPoints()
    profFilterBtn:SetPoint("LEFT", filterBtn, "RIGHT", 4, 0)
    profFilterBtn:Show()

    -- ── Barre de recherche de recette ───────────────────────────────
    -- Enfant de core.scrollChild (à côté des boutons de filtre, comme
    -- demandé). ShowProfessions() se rappelle à chaque frappe et vide le
    -- scrollChild : on restaure le focus juste après pour permettre une
    -- saisie continue. La recherche (>= 2 caractères) déplie et filtre
    -- automatiquement les grilles de recettes correspondantes.
    local searchBox = core.scrollChild._profSearchBox
    if not searchBox then
        searchBox = CreateFrame("EditBox", nil, core.scrollChild, "BackdropTemplate")
        core.scrollChild._profSearchBox = searchBox
        searchBox:SetAutoFocus(false)
        searchBox:SetSize(190, 22)
        searchBox:SetFontObject("GameFontHighlightSmall")
        searchBox:SetTextInsets(22, 18, 0, 0)
        searchBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        searchBox:SetBackdropColor(0.08, 0.10, 0.14, 0.95)
        searchBox:SetBackdropBorderColor(0.30, 0.45, 0.60, 1)

        local ico = searchBox:CreateTexture(nil, "OVERLAY")
        ico:SetSize(14, 14); ico:SetPoint("LEFT", 5, 0)
        ico:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

        local ph = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        ph:SetPoint("LEFT", 22, 0)
        ph:SetText(pluginNs.L("RECIPE_SEARCH_PLACEHOLDER"))
        searchBox._placeholder = ph

        local clr = CreateFrame("Button", nil, searchBox)
        clr:SetSize(14, 14); clr:SetPoint("RIGHT", -4, 0)
        -- Texture (pas un glyphe : la police WoW n'a pas le caractère ✕).
        local clrTex = clr:CreateTexture(nil, "OVERLAY")
        clrTex:SetAllPoints()
        clrTex:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        clr:SetScript("OnClick", function() searchBox:SetText(""); searchBox:ClearFocus() end)
        clr:Hide()
        searchBox._clear = clr

        searchBox:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
        searchBox:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)
        searchBox:SetScript("OnTextChanged", function(s)
            local t = s:GetText() or ""
            pluginNs._recipeQuery = t
            s._placeholder:SetShown(t == "")
            s._clear:SetShown(t ~= "")
            pluginNs._recipeSearchWantFocus = true
            pluginNs.ShowProfessions()
        end)
    end
    searchBox:ClearAllPoints()
    searchBox:SetPoint("LEFT", profFilterBtn, "RIGHT", 10, 0)
    searchBox:Show()
    if pluginNs._recipeSearchWantFocus then
        pluginNs._recipeSearchWantFocus = false
        searchBox:SetFocus()
        searchBox:SetCursorPosition(#(searchBox:GetText() or ""))
    end

    -- ── Section bois banque de bataillon ──────────────
    local woodSectionBottomY
    do
        -- Source unique : bois fourni par ViewerLog_Professions via l'API partagée
        -- (plus de wood tracker propre à cet addon). Absent → pas de section bois.
        local vlWoodAPI      = _G.ViewerLogAPI
        local woodExpansions = (vlWoodAPI and vlWoodAPI.GetWoodExpansions and vlWoodAPI.GetWoodExpansions()) or {}
        local woodDetail     = {}
        if vlWoodAPI and vlWoodAPI.GetWoodCounts then
            local _, d = vlWoodAPI.GetWoodCounts()
            woodDetail = d or {}
        end
        local WoodName = (vlWoodAPI and vlWoodAPI.GetWoodItemName) or function() return "?" end
        local BTN_GAP    = 4
        local BTN_H      = 44
        local AREA_LEFT  = 10
        local AREA_RIGHT = contentW - 10
        local usableW    = AREA_RIGHT - AREA_LEFT
        local N_PER_ROW  = 1
        for n = 7, 2, -1 do
            local w = math.floor((usableW - (n - 1) * BTN_GAP) / n)
            if w >= 65 then N_PER_ROW = n; break end
        end
        local BTN_W   = math.floor((usableW - (N_PER_ROW - 1) * BTN_GAP) / N_PER_ROW)
        local START_Y = -52

        local woodSectionTitle = core.scrollChild._profWoodTitle
        if not woodSectionTitle then
            woodSectionTitle = core.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            core.scrollChild._profWoodTitle = woodSectionTitle
        end
        woodSectionTitle:ClearAllPoints()
        woodSectionTitle:SetPoint("TOPLEFT", AREA_LEFT, START_Y)
        woodSectionTitle:SetText("|cffcca060" .. core.L("WOOD_BANK_TITLE") .. "|r")
        woodSectionTitle:SetShown(#woodExpansions > 0)

        local curX = AREA_LEFT; local curY = START_Y - 18; local colIdx = 0

        for _, expBlock in ipairs(woodExpansions) do
            if colIdx > 0 and colIdx % N_PER_ROW == 0 then
                curX = AREA_LEFT; curY = curY - BTN_H - BTN_GAP
            end
            local expQty = 0
            for _, item in ipairs(expBlock.items) do
                expQty = expQty + (woodDetail[item.id] or 0)
            end
            local cr, cg, cb = expBlock.color[1], expBlock.color[2], expBlock.color[3]
            local hasStock = expQty > 0

            woodBtnUsed = woodBtnUsed + 1
            local slot = woodBtnPool[woodBtnUsed]
            if not slot then
                slot = {}
                slot.btn = CreateFrame("Button", nil, core.scrollChild, "BackdropTemplate")
                slot.btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                slot.nameFs = slot.btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                slot.nameFs:SetPoint("TOPLEFT", 4, -6); slot.nameFs:SetPoint("TOPRIGHT", -4, -6)
                slot.nameFs:SetJustifyH("CENTER"); slot.nameFs:SetWordWrap(false)
                slot.qtyFs = slot.btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                slot.qtyFs:SetPoint("BOTTOM", 0, 5)
                woodBtnPool[woodBtnUsed] = slot
            end
            local btn, nameFs, qtyFs = slot.btn, slot.nameFs, slot.qtyFs

            btn:ClearAllPoints()
            btn:SetSize(BTN_W, BTN_H)
            btn:SetPoint("TOPLEFT", curX, curY)
            if hasStock then
                btn:SetBackdropColor(cr*0.28, cg*0.28, cb*0.28, 1)
                btn:SetBackdropBorderColor(cr*0.85, cg*0.85, cb*0.85, 1)
            else
                btn:SetBackdropColor(0.09, 0.09, 0.09, 1)
                btn:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
            end
            if hasStock then nameFs:SetTextColor(math.min(cr*0.70+0.38,1), math.min(cg*0.70+0.38,1), math.min(cb*0.70+0.38,1))
            else nameFs:SetTextColor(0.30, 0.30, 0.30) end
            nameFs:SetText(expBlock.expansion)
            if hasStock then
                local col = expQty>=200 and "|cff55ff55" or expQty>=50 and "|cffffff55" or "|cffff8855"
                qtyFs:SetText(col..expQty.."|r")
            else qtyFs:SetText("|cff252525".."0".."|r") end

            -- Réassigné à chaque tirage : cr/cg/cb/capBlock/capDetail/capStock
            -- varient (les quantités de bois changent d'un scan à l'autre)
            -- même si le nombre de boutons (liste d'extensions) est fixe.
            local capBlock, capDetail, capStock = expBlock, woodDetail, hasStock
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(capStock and cr*0.42 or 0.16, capStock and cg*0.42 or 0.16, capStock and cb*0.42 or 0.16, 1)
                self:SetBackdropBorderColor(capStock and math.min(cr,1) or 0.35, capStock and math.min(cg,1) or 0.35, capStock and math.min(cb,1) or 0.35, 1)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:ClearLines()
                GameTooltip:AddLine("|cffffd700"..capBlock.expansion.."|r"); GameTooltip:AddLine(" ")
                for _, item in ipairs(capBlock.items) do
                    local qty = capDetail[item.id] or 0
                    GameTooltip:AddDoubleLine("|cffccaa60"..WoodName(item.id).."|r", (qty>0 and "|cffffffff" or "|cff555555")..qty.."|r", 1,1,1,1,1,1)
                end
                if not capStock then GameTooltip:AddLine(" "); GameTooltip:AddLine("|cff555555" .. (core.L and core.L("WARBAND_SCAN_TIP") or pluginNs.L("TT_WARBAND_SCAN_HINT")) .. "|r") end
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(capStock and cr*0.28 or 0.09, capStock and cg*0.28 or 0.09, capStock and cb*0.28 or 0.09, 1)
                self:SetBackdropBorderColor(capStock and cr*0.85 or 0.22, capStock and cg*0.85 or 0.22, capStock and cb*0.85 or 0.22, 1)
                GameTooltip:Hide()
            end)
            btn:Show()
            curX = curX + BTN_W + BTN_GAP; colIdx = colIdx + 1
        end
        woodSectionBottomY = (#woodExpansions > 0) and (curY - BTN_H - 10) or START_Y
    end

    local sep = core.scrollChild._profSep
    if not sep then
        sep = core.scrollChild:CreateTexture(nil, "ARTWORK")
        core.scrollChild._profSep = sep
        sep:SetColorTexture(1, 0.82, 0, 0.3)
    end
    sep:ClearAllPoints()
    sep:SetSize(contentW - 20, 1); sep:SetPoint("TOPLEFT", 10, woodSectionBottomY)
    sep:Show()

    -- ── Collecte et tri des personnages ──────────────
    -- Les données de personnage (class, professions…) sont dans ViewerLogDB.
    -- AltViewerLogDB ne contient que les préférences UI (hiddenExpansions…).
    -- On filtre les clés réservées de ViewerLog via vlAPI.IsRealm().
    local charList = {}
    for realmName, realmData in pairs(vlDB) do
        if vlAPI and vlAPI.IsRealm(realmName, realmData) then
            for charName, charData in pairs(realmData) do
                if type(charData) == "table" and charData.class and charData.professions and #charData.professions > 0 then
                    table.insert(charList, { realm=realmName, name=charName, data=charData })
                end
            end
        end
    end
    table.sort(charList, function(a, b)
        local aIsCurrent = (a.name==core.player and a.realm==core.realm)
        local bIsCurrent = (b.name==core.player and b.realm==core.realm)
        if aIsCurrent ~= bIsCurrent then return aIsCurrent end
        if a.realm == b.realm then return a.name < b.name end
        return a.realm < b.realm
    end)

    if #charList == 0 then
        local hint = core.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        hint:SetPoint("TOP", 0, -120); hint:SetText(core.L("NO_CHARS")); hint:SetJustifyH("CENTER")
        core.scrollChild:SetHeight(200)
        HideUnusedPools()
        return
    end

    local offsetY  = woodSectionBottomY - 16
    local BAR_WIDTH = 280
    local LEFT_PAD  = 20

    for _, entry in ipairs(charList) do
        local charName  = entry.name
        local realmName = entry.realm
        local charData  = entry.data
        local isCurrent = (charName == core.player and realmName == core.realm)
        local c = RAID_CLASS_COLORS[charData.class] or { r=1, g=1, b=1 }

        local hasVisibleProf = false
        for _, p in ipairs(charData.professions) do
            if not IsProfessionHidden(p.name) then
                hasVisibleProf = true; break
            end
        end
        if hasVisibleProf then

        charRowUsed = charRowUsed + 1
        local rowSlot = charRowPool[charRowUsed]
        if not rowSlot then
            rowSlot = {}
            rowSlot.charBlock = CreateFrame("Frame", nil, core.scrollChild, "BackdropTemplate")
            rowSlot.charBlock:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            rowSlot.stoneBtn = CreateFrame("Button", nil, rowSlot.charBlock)
            rowSlot.stoneBtn:SetSize(16, 16); rowSlot.stoneBtn:SetPoint("LEFT", 4, 0)

            rowSlot.charLabel = rowSlot.charBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            rowSlot.charLabel:SetPoint("LEFT", 24, 0)

            rowSlot.lvlFS = rowSlot.charBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rowSlot.lvlFS:SetPoint("RIGHT", -10, 0); rowSlot.lvlFS:SetTextColor(0.6, 0.6, 0.6)

            charRowPool[charRowUsed] = rowSlot
        end
        local charBlock, stoneBtn, charLabel = rowSlot.charBlock, rowSlot.stoneBtn, rowSlot.charLabel

        charBlock:ClearAllPoints()
        charBlock:SetSize(LEFT_PAD + BAR_WIDTH, 24)
        charBlock:SetPoint("TOPLEFT", LEFT_PAD, offsetY)
        charBlock:SetBackdropColor(c.r*0.22 + 0.06, c.g*0.22 + 0.06, c.b*0.22 + 0.06, 0.92)
        charBlock:Show()

        if isCurrent then stoneBtn:SetNormalAtlas("DungeonStoneCheckpoint"); stoneBtn:SetAlpha(1)
        else stoneBtn:SetNormalAtlas("DungeonStoneCheckpointDeactivated"); stoneBtn:SetAlpha(0.3) end

        local classHex = string.format("%02x%02x%02x",
            math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
        charLabel:SetTextColor(c.r, c.g, c.b)
        charLabel:SetText(string.format("%s  |cff%s%s|r", charName, classHex, realmName))

        if charData.level then
            rowSlot.lvlFS:SetText(core.L("LEVEL_SHORT") .. charData.level)
            rowSlot.lvlFS:Show()
        else
            rowSlot.lvlFS:Hide()
        end
        offsetY = offsetY - 28

        do
            local mainProfs, secProfs = {}, {}
            for _, p in ipairs(charData.professions) do
                if p.secondary then table.insert(secProfs, p) else table.insert(mainProfs, p) end
            end

            -- Données housing fournies par le module ViewerLog_Housing
            -- (lecture seule via _G.ViewerLogAPI). nil si le module est
            -- absent/désactivé -> la barre housing ne s'affiche pas.
            local housingData = (vlAPI and vlAPI.GetHousingRecipes)
                and vlAPI.GetHousingRecipes(charName, realmName) or nil

            local function renderProfList(list)
                local visible = {}
                for _, p in ipairs(list) do
                    if not IsProfessionHidden(p.name) then
                        table.insert(visible, p)
                    end
                end
                if #visible == 0 then return end

                for profIdx, profData in ipairs(visible) do
                    profRowUsed = profRowUsed + 1
                    local pSlot = profRowPool[profRowUsed]
                    if not pSlot then
                        pSlot = {}
                        pSlot.profSep = core.scrollChild:CreateTexture(nil, "ARTWORK")
                        pSlot.profSep:SetColorTexture(0.3, 0.3, 0.3, 0.25)

                        pSlot.ic = core.scrollChild:CreateTexture(nil, "OVERLAY")

                        pSlot.pName = core.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

                        profRowPool[profRowUsed] = pSlot
                    end

                    if profIdx > 1 then
                        pSlot.profSep:ClearAllPoints()
                        pSlot.profSep:SetSize(contentW - LEFT_PAD - 14, 1)
                        pSlot.profSep:SetPoint("TOPLEFT", LEFT_PAD + 14, offsetY - 2)
                        pSlot.profSep:Show()
                        offsetY = offsetY - 8
                    else
                        pSlot.profSep:Hide()
                    end

                    pSlot.ic:ClearAllPoints()
                    pSlot.ic:SetSize(22, 22); pSlot.ic:SetPoint("TOPLEFT", LEFT_PAD + 14, offsetY)
                    pSlot.ic:SetTexture(profData.icon)
                    pSlot.ic:Show()

                    pSlot.pName:ClearAllPoints()
                    pSlot.pName:SetPoint("LEFT", pSlot.ic, "RIGHT", 7, 1)
                    pSlot.pName:SetText(GetProfDisplayName(profData.name))
                    pSlot.pName:SetTextColor(playerClassColor.r, playerClassColor.g, playerClassColor.b)
                    pSlot.pName:Show()

                    offsetY = offsetY - 28

                    if profData.tiers and #profData.tiers > 0 then
                        for _, tier in ipairs(profData.tiers) do
                            if not IsExpansionHidden(tier.name) then
                                local safeMax = (tier.max and tier.max > 0) and tier.max or 1
                                local safeCur = tier.level or 0
                                local pct     = math.min(safeCur / safeMax, 1)
                                local isFull  = (safeCur >= safeMax)
                                local BAR_H   = 18

                                tierBarUsed = tierBarUsed + 1
                                local tSlot = tierBarPool[tierBarUsed]
                                if not tSlot then
                                    tSlot = {}
                                    tSlot.bg = CreateFrame("Frame", nil, core.scrollChild, "BackdropTemplate")
                                    tSlot.bg:SetSize(BAR_WIDTH, BAR_H)
                                    tSlot.bg:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
                                    tSlot.bg:SetBackdropColor(0.12, 0.12, 0.15, 0.95); tSlot.bg:SetBackdropBorderColor(0.32, 0.32, 0.38, 1)

                                    tSlot.fill = tSlot.bg:CreateTexture(nil, "ARTWORK")
                                    tSlot.fill:SetPoint("TOPLEFT", 1, -1); tSlot.fill:SetPoint("BOTTOMLEFT", 1, 1)

                                    tSlot.nameFS = tSlot.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                    tSlot.nameFS:SetPoint("LEFT", 6, 0); tSlot.nameFS:SetPoint("RIGHT", -52, 0)
                                    tSlot.nameFS:SetJustifyH("LEFT")

                                    tSlot.rankFS = tSlot.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                    tSlot.rankFS:SetPoint("RIGHT", -6, 0); tSlot.rankFS:SetJustifyH("RIGHT")

                                    tierBarPool[tierBarUsed] = tSlot
                                end

                                tSlot.bg:ClearAllPoints()
                                tSlot.bg:SetPoint("TOPLEFT", LEFT_PAD + 14, offsetY)
                                tSlot.bg:Show()

                                if pct > 0 then
                                    tSlot.fill:SetWidth(math.max((BAR_WIDTH - 2) * pct, 2))
                                    if isFull then tSlot.fill:SetColorTexture(0.10, 0.65, 0.30, 1)
                                    else tSlot.fill:SetColorTexture(0.20, 0.45, 0.80, 0.85) end
                                    tSlot.fill:Show()
                                else
                                    tSlot.fill:Hide()
                                end

                                tSlot.nameFS:SetTextColor(1, 1, 1, 1)
                                tSlot.nameFS:SetText(tier.name or "")

                                if isFull then tSlot.rankFS:SetTextColor(0.20, 1, 0.50, 1); tSlot.rankFS:SetText("MAX")
                                else tSlot.rankFS:SetTextColor(0.75, 0.75, 0.75, 1); tSlot.rankFS:SetText(safeCur.." / "..safeMax) end

                                offsetY = offsetY - (BAR_H + 2)
                            end
                        end
                        offsetY = offsetY - 6
                    end

                    -- ── Barre Housing (données fournies par ViewerLog_Housing) ──
                    -- Même schéma que la barre Recettes : les données viennent
                    -- d'un module externe via _G.ViewerLogAPI (ici GetHousingRecipes),
                    -- et c'est cette vue qui dessine la barre + la grille. Si le
                    -- module est absent, housingData est nil -> pas de barre housing.
                    local hp = housingData and housingData[profData.name]
                    local hasHousingRecipes = hp ~= nil
                    local toggleBtn  = nil
                    local isExpanded = false

                    if hasHousingRecipes then
                        local rKey = recipeKey(realmName, charName, profData.name)
                        isExpanded = pluginNs.recipeExpanded[rKey] or false

                        local totalRecipes = hp.total or 0
                        local knownCount   = hp.knownCount or 0

                        recipeToggleUsed = recipeToggleUsed + 1
                        local rSlot = recipeTogglePool[recipeToggleUsed]
                        if not rSlot then
                            rSlot = {}
                            rSlot.toggleBtn = CreateFrame("Button", nil, core.scrollChild, "BackdropTemplate")
                            rSlot.toggleBtn:SetSize(280, 18)
                            rSlot.toggleBtn:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
                            rSlot.toggleBtn:SetBackdropColor(0.08, 0.08, 0.12, 0.85); rSlot.toggleBtn:SetBackdropBorderColor(0.28, 0.28, 0.38, 1)

                            rSlot.arrowTex = rSlot.toggleBtn:CreateTexture(nil, "OVERLAY")
                            rSlot.arrowTex:SetSize(14, 14); rSlot.arrowTex:SetPoint("LEFT", 3, 0)

                            rSlot.recipeFS = rSlot.toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                            rSlot.recipeFS:SetPoint("LEFT", 21, 0); rSlot.recipeFS:SetTextColor(0.65, 0.65, 0.85)

                            rSlot.miniBarBg = rSlot.toggleBtn:CreateTexture(nil, "BACKGROUND")
                            rSlot.miniBarBg:SetSize(60, 4); rSlot.miniBarBg:SetPoint("RIGHT", -6, 0); rSlot.miniBarBg:SetColorTexture(0.15, 0.15, 0.20, 1)
                            rSlot.miniBarFill = rSlot.toggleBtn:CreateTexture(nil, "ARTWORK")
                            rSlot.miniBarFill:SetPoint("LEFT", rSlot.miniBarBg, "LEFT", 0, 0)

                            recipeTogglePool[recipeToggleUsed] = rSlot
                        end
                        toggleBtn = rSlot.toggleBtn

                        toggleBtn:ClearAllPoints()
                        toggleBtn:SetPoint("TOPLEFT", LEFT_PAD + 14, offsetY)
                        toggleBtn:Show()

                        rSlot.arrowTex:SetAtlas(isExpanded and "housing-floor-arrow-down-default" or "housing-floor-arrow-up-default")
                        rSlot.recipeFS:SetText(string.format(pluginNs.L("HOUSING_LABEL"), knownCount, totalRecipes))

                        if totalRecipes > 0 then
                            local fillW = math.max(math.floor((knownCount / totalRecipes) * 60), 1)
                            rSlot.miniBarFill:SetSize(fillW, 4)
                            local pctR = knownCount / totalRecipes
                            rSlot.miniBarFill:SetColorTexture(pctR>=1 and 0 or 0.45, pctR>=1 and 0.85 or 0.55, pctR>=1 and 0.35 or 1.00, 0.9)
                            rSlot.miniBarBg:Show(); rSlot.miniBarFill:Show()
                        else
                            rSlot.miniBarBg:Hide(); rSlot.miniBarFill:Hide()
                        end

                        toggleBtn:SetScript("OnEnter", function(self)
                            self:SetBackdropColor(0.14, 0.14, 0.22, 1); self:SetBackdropBorderColor(0.45, 0.45, 0.65, 1)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(isExpanded and pluginNs.L("HOUSING_FOLD") or pluginNs.L("HOUSING_UNFOLD"), 0.8, 0.8, 1)
                            GameTooltip:AddLine(string.format(pluginNs.L("HOUSING_KNOWN"), knownCount, totalRecipes), 1, 1, 1)
                            GameTooltip:Show()
                        end)
                        toggleBtn:SetScript("OnLeave", function(self)
                            self:SetBackdropColor(0.08, 0.08, 0.12, 0.85); self:SetBackdropBorderColor(0.28, 0.28, 0.38, 1)
                            GameTooltip:Hide()
                        end)
                        local capturedKey = rKey
                        toggleBtn:SetScript("OnClick", function()
                            pluginNs.recipeExpanded[capturedKey] = not pluginNs.recipeExpanded[capturedKey]
                            pluginNs.ShowProfessions()
                        end)
                    end

                    -- ── Barre "Recettes" (ViewerLog_Recette) ────────────
                    -- RenderRecipeBar() se rend elle-même invisible si
                    -- ViewerLog_Recette n'est pas actif. Ancrée à droite du
                    -- bouton Housing s'il existe, sinon prend sa place.
                    offsetY = pluginNs.RenderRecipeBar(core.scrollChild, profData, realmName, charName, toggleBtn, LEFT_PAD, offsetY, contentW)

                    offsetY = offsetY - 24
                    if hasHousingRecipes and isExpanded then
                        offsetY = pluginNs.RenderRecipeGrid(core.scrollChild, hp.defs, hp.known, LEFT_PAD, offsetY, contentW)
                    end
                    offsetY = offsetY - 4
                end
            end

            renderProfList(mainProfs)
            if #secProfs > 0 then offsetY = offsetY - 4; renderProfList(secProfs) end
        end

        rowSlot.charSep = rowSlot.charSep or core.scrollChild:CreateTexture(nil, "ARTWORK")
        rowSlot.charSep:ClearAllPoints()
        rowSlot.charSep:SetSize(contentW - LEFT_PAD, 1); rowSlot.charSep:SetPoint("TOPLEFT", LEFT_PAD, offsetY - 4)
        rowSlot.charSep:SetColorTexture(1, 1, 1, 0.06)
        rowSlot.charSep:Show()
        offsetY = offsetY - 16
        end -- hasVisibleProf
    end

    core.scrollChild:SetHeight(math.abs(offsetY) + 60)
    HideUnusedPools()
end
