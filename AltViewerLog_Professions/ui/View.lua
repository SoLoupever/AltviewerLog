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
        profRowPool[i].card:Hide()
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

    -- ── En-tête : titre, scan, filtres, recherche ───────────────────────
    local sc = core.scrollChild
    local T  = core.Theme
    local PADX = 16

    local title = sc._profTitle
    if not title then
        title = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        sc._profTitle = title
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", PADX, -14)
    title:SetText(core.L("BTN_PROFESSIONS"))
    title:SetTextColor(unpack(T.heading))
    title:Show()

    local function HeaderButton(key, w)
        local b = sc[key]
        if not b then
            b = CreateFrame("Button", nil, sc, "BackdropTemplate")
            sc[key] = b
            b:SetSize(w, 28)
            core.Skin.Button(b)
        end
        return b
    end

    local scanBtn = HeaderButton("_profScanBtn", 160)
    if not scanBtn.fs then
        scanBtn.fs = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scanBtn.fs:SetPoint("CENTER")
        scanBtn:SetScript("OnClick", pluginNs.ScanAllProfessions)
    end
    scanBtn.fs:SetText(core.L("SCAN_BTN"))
    scanBtn.fs:SetTextColor(unpack(T.gold))
    scanBtn:ClearAllPoints()
    scanBtn:SetPoint("LEFT", title, "RIGHT", 16, 0)
    scanBtn:Show()

    -- Filtre extensions (engrenage)
    local filterBtn = HeaderButton("_profFilterBtn", 28)
    if not filterBtn.gearTex then
        local gearTex = filterBtn:CreateTexture(nil, "ARTWORK")
        filterBtn.gearTex = gearTex
        gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        gearTex:SetSize(16, 16)
        gearTex:SetPoint("CENTER", 0, 0)
        gearTex:SetVertexColor(0.95, 0.82, 0.40)
        filterBtn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(core.L("EXPANSION_FILTER_TOOLTIP"), 1, 0.85, 0.20)
            GameTooltip:Show()
        end)
        filterBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        filterBtn:SetScript("OnClick", function(self)
            if professionFilterPopup and professionFilterPopup:IsShown() then
                professionFilterPopup:Hide()
            end
            ToggleExpansionFilterPopup(self)
        end)
    end
    filterBtn:ClearAllPoints()
    filterBtn:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)
    filterBtn:Show()

    -- Filtre métiers (marteau)
    local profFilterBtn = HeaderButton("_profFilterBtn2", 28)
    if not profFilterBtn.hammerTex then
        local hammerTex = profFilterBtn:CreateTexture(nil, "ARTWORK")
        profFilterBtn.hammerTex = hammerTex
        hammerTex:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
        hammerTex:SetSize(18, 18)
        hammerTex:SetPoint("CENTER", 0, 0)
        profFilterBtn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(core.L("PROF_FILTER_TT"), 1, 0.85, 0.20)
            GameTooltip:Show()
        end)
        profFilterBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        profFilterBtn:SetScript("OnClick", function(self)
            if expansionFilterPopup and expansionFilterPopup:IsShown() then
                expansionFilterPopup:Hide()
            end
            ToggleProfessionFilterPopup(self)
        end)
    end
    profFilterBtn:ClearAllPoints()
    profFilterBtn:SetPoint("LEFT", filterBtn, "RIGHT", 6, 0)
    profFilterBtn:Show()

    -- Recherche de recette (>= 2 caractères : déplie et filtre les grilles).
    -- ShowProfessions() se rappelle à chaque frappe : le focus est restauré.
    local searchBox = sc._profSearchBox
    if not searchBox then
        searchBox = CreateFrame("EditBox", nil, sc, "BackdropTemplate")
        sc._profSearchBox = searchBox
        searchBox:SetAutoFocus(false)
        searchBox:SetSize(230, 28)
        searchBox:SetFontObject("GameFontHighlightSmall")
        searchBox:SetTextInsets(28, 22, 0, 0)
        core.Skin.Frame(searchBox, "input")
        searchBox:HookScript("OnEditFocusGained", function(s) s._hover = true;  core.Skin.Paint(s) end)
        searchBox:HookScript("OnEditFocusLost",   function(s) s._hover = false; core.Skin.Paint(s) end)

        local ico = searchBox:CreateTexture(nil, "OVERLAY")
        ico:SetSize(14, 14); ico:SetPoint("LEFT", 8, 0)
        ico:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

        local ph = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        ph:SetPoint("LEFT", 28, 0)
        ph:SetText(pluginNs.L("RECIPE_SEARCH_PLACEHOLDER"))
        searchBox._placeholder = ph

        local clr = CreateFrame("Button", nil, searchBox)
        clr:SetSize(14, 14); clr:SetPoint("RIGHT", -5, 0)
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
    searchBox:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -PADX, -14)
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
        local BTN_GAP    = 8
        local BTN_H      = 50
        local AREA_LEFT  = 16
        local AREA_RIGHT = contentW - 16
        local usableW    = AREA_RIGHT - AREA_LEFT
        local N_PER_ROW  = 1
        for n = 6, 2, -1 do
            local w = math.floor((usableW - (n - 1) * BTN_GAP) / n)
            if w >= 65 then N_PER_ROW = n; break end
        end
        local BTN_W   = math.floor((usableW - (N_PER_ROW - 1) * BTN_GAP) / N_PER_ROW)
        local START_Y = -56

        local woodSectionTitle = core.scrollChild._profWoodTitle
        if not woodSectionTitle then
            woodSectionTitle = core.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            core.scrollChild._profWoodTitle = woodSectionTitle
        end
        woodSectionTitle:ClearAllPoints()
        woodSectionTitle:SetPoint("TOPLEFT", AREA_LEFT, START_Y)
        woodSectionTitle:SetText(core.L("WOOD_BANK_TITLE"))
        woodSectionTitle:SetTextColor(unpack(core.Theme.textDim))
        woodSectionTitle:SetShown(#woodExpansions > 0)

        local curX = AREA_LEFT; local curY = START_Y - 22; local colIdx = 0

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
        woodSectionBottomY = (#woodExpansions > 0) and (curY - BTN_H - 14) or (START_Y + 6)
    end

    local sep = sc._profSep
    if not sep then
        sep = sc:CreateTexture(nil, "ARTWORK")
        sc._profSep = sep
    end
    sep:ClearAllPoints()
    sep:SetColorTexture(T.heading[1], T.heading[2], T.heading[3], 0.30)
    sep:SetSize(contentW - PADX * 2, 1); sep:SetPoint("TOPLEFT", PADX, woodSectionBottomY)
    sep:Show()

    -- ── Collecte et tri des personnages ──────────────
    -- Données dans ViewerLogDB ; clés réservées filtrées via vlAPI.IsRealm().
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
        local hint = sc:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        hint:SetPoint("TOP", 0, -120); hint:SetText(core.L("NO_CHARS")); hint:SetJustifyH("CENTER")
        sc:SetHeight(200)
        HideUnusedPools()
        return
    end

    -- ── Grille de cartes métier (2 colonnes, 1 si l'espace manque) ──
    local GAP        = 14
    local CARD_PAD   = 12
    local BAR_H      = 22
    local ncols      = 2
    local cardW      = math.floor((contentW - PADX * 2 - GAP) / 2)
    if cardW < 300 then ncols = 1; cardW = contentW - PADX * 2 end
    local innerW     = cardW - CARD_PAD * 2
    local halfW      = math.floor((innerW - 10) / 2)

    local offsetY = woodSectionBottomY - 16

    local function ColorTierBar(tSlot, isFull, pct)
        tSlot.bg._avlRole = "input"
        core.Skin.Paint(tSlot.bg)
        if pct > 0 then
            tSlot.fill:SetWidth(math.max((innerW - 2) * pct, 2))
            if isFull then tSlot.fill:SetColorTexture(0.10, 0.58, 0.28, 1)
            else tSlot.fill:SetColorTexture(0.18, 0.42, 0.80, 1) end
            tSlot.fill:Show()
        else
            tSlot.fill:Hide()
        end
    end

    for _, entry in ipairs(charList) do
        local charName  = entry.name
        local realmName = entry.realm
        local charData  = entry.data
        local c = RAID_CLASS_COLORS[charData.class] or { r=1, g=1, b=1 }

        -- Métiers visibles : principaux puis secondaires
        local visibleProfs = {}
        for _, p in ipairs(charData.professions) do
            if not p.secondary and not IsProfessionHidden(p.name) then visibleProfs[#visibleProfs + 1] = p end
        end
        for _, p in ipairs(charData.professions) do
            if p.secondary and not IsProfessionHidden(p.name) then visibleProfs[#visibleProfs + 1] = p end
        end

        if #visibleProfs > 0 then

        -- Bandeau personnage
        charRowUsed = charRowUsed + 1
        local rowSlot = charRowPool[charRowUsed]
        if not rowSlot then
            rowSlot = {}
            rowSlot.charBlock = CreateFrame("Frame", nil, sc, "BackdropTemplate")
            rowSlot.charBlock:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            rowSlot.charLabel = rowSlot.charBlock:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            rowSlot.charLabel:SetPoint("LEFT", 14, 0)
            rowSlot.lvlFS = rowSlot.charBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            rowSlot.lvlFS:SetPoint("RIGHT", -14, 0)
            charRowPool[charRowUsed] = rowSlot
        end
        local charBlock, charLabel = rowSlot.charBlock, rowSlot.charLabel
        charBlock:ClearAllPoints()
        charBlock:SetSize(contentW - PADX * 2, 32)
        charBlock:SetPoint("TOPLEFT", PADX, offsetY)
        charBlock:SetBackdropColor(c.r*0.22 + 0.05, c.g*0.22 + 0.05, c.b*0.22 + 0.05, 1)
        charBlock:Show()

        charLabel:SetTextColor(c.r, c.g, c.b)
        charLabel:SetText(string.format("%s |cff%s%s|r", charName, core.ColorHex(T.textDim), realmName))
        if charData.level then
            rowSlot.lvlFS:SetText(core.L("LEVEL_SHORT") .. charData.level)
            rowSlot.lvlFS:SetTextColor(unpack(T.textDim))
            rowSlot.lvlFS:Show()
        else
            rowSlot.lvlFS:Hide()
        end
        offsetY = offsetY - 32 - 12

        -- Données housing (module ViewerLog_Housing, lecture seule). nil si absent.
        local housingData = (vlAPI and vlAPI.GetHousingRecipes)
            and vlAPI.GetHousingRecipes(charName, realmName) or nil

        local rowTop, rowH, deferred = offsetY, 0, {}

        for idx, profData in ipairs(visibleProfs) do
            local col = (idx - 1) % ncols
            if col == 0 then rowTop, rowH, deferred = offsetY, 0, {} end
            local cardX = PADX + col * (cardW + GAP)

            -- Paliers visibles (filtre extensions)
            local tiers = {}
            for _, tier in ipairs(profData.tiers or {}) do
                if not IsExpansionHidden(tier.name) then tiers[#tiers + 1] = tier end
            end
            local cardH = 58 + #tiers * (BAR_H + 3) + (#tiers > 0 and 8 or 0) + 24 + CARD_PAD

            profRowUsed = profRowUsed + 1
            local pSlot = profRowPool[profRowUsed]
            if not pSlot then
                pSlot = {}
                pSlot.card = CreateFrame("Frame", nil, sc, "BackdropTemplate")
                core.Skin.Frame(pSlot.card, "card")
                pSlot.ic = pSlot.card:CreateTexture(nil, "ARTWORK")
                pSlot.ic:SetSize(34, 34)
                pSlot.ic:SetPoint("TOPLEFT", CARD_PAD, -CARD_PAD)
                pSlot.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                pSlot.pName = pSlot.card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                pSlot.pName:SetPoint("LEFT", pSlot.ic, "RIGHT", 10, 0)
                profRowPool[profRowUsed] = pSlot
            end
            local card = pSlot.card
            card:ClearAllPoints()
            card:SetSize(cardW, cardH)
            card:SetPoint("TOPLEFT", sc, "TOPLEFT", cardX, rowTop)
            card:SetFrameLevel(sc:GetFrameLevel() + 1)
            core.Skin.Paint(card)
            card:Show()
            local lvl = card:GetFrameLevel() + 1

            pSlot.ic:SetTexture(profData.icon)
            pSlot.pName:SetText(GetProfDisplayName(profData.name))
            pSlot.pName:SetTextColor(unpack(T.text))

            -- Barres de paliers
            local y = -58
            for _, tier in ipairs(tiers) do
                local safeMax = (tier.max and tier.max > 0) and tier.max or 1
                local safeCur = tier.level or 0
                local pct     = math.min(safeCur / safeMax, 1)
                local isFull  = (safeCur >= safeMax)

                tierBarUsed = tierBarUsed + 1
                local tSlot = tierBarPool[tierBarUsed]
                if not tSlot then
                    tSlot = {}
                    tSlot.bg = CreateFrame("Frame", nil, card, "BackdropTemplate")
                    core.Skin.Frame(tSlot.bg, "input")
                    tSlot.fill = tSlot.bg:CreateTexture(nil, "ARTWORK")
                    tSlot.fill:SetPoint("TOPLEFT", 1, -1); tSlot.fill:SetPoint("BOTTOMLEFT", 1, 1)
                    tSlot.nameFS = tSlot.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    tSlot.nameFS:SetPoint("LEFT", 8, 0); tSlot.nameFS:SetPoint("RIGHT", -56, 0)
                    tSlot.nameFS:SetJustifyH("LEFT"); tSlot.nameFS:SetWordWrap(false)
                    tSlot.rankFS = tSlot.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    tSlot.rankFS:SetPoint("RIGHT", -8, 0); tSlot.rankFS:SetJustifyH("RIGHT")
                    tierBarPool[tierBarUsed] = tSlot
                end
                tSlot.bg:SetParent(card)
                tSlot.bg:SetFrameLevel(lvl)
                tSlot.bg:ClearAllPoints()
                tSlot.bg:SetSize(innerW, BAR_H)
                tSlot.bg:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, y)
                tSlot.fill:SetDrawLayer("ARTWORK")
                ColorTierBar(tSlot, isFull, pct)
                tSlot.bg:Show()

                tSlot.nameFS:SetTextColor(1, 1, 1, 1)
                tSlot.nameFS:SetText(tier.name or "")
                if isFull then tSlot.rankFS:SetTextColor(1, 1, 1, 1); tSlot.rankFS:SetText("MAX")
                else tSlot.rankFS:SetTextColor(1, 1, 1, 1); tSlot.rankFS:SetText(safeCur .. " / " .. safeMax) end
                y = y - (BAR_H + 3)
            end
            if #tiers > 0 then y = y - 8 end

            -- Ligne du bas : Housing | Recettes (côte à côte)
            local hp = housingData and housingData[profData.name]
            local toggleBtn = nil
            if hp then
                local rKey = recipeKey(realmName, charName, profData.name)
                local isExpanded = pluginNs.recipeExpanded[rKey] or false
                local totalRecipes, knownCount = hp.total or 0, hp.knownCount or 0

                recipeToggleUsed = recipeToggleUsed + 1
                local rSlot = recipeTogglePool[recipeToggleUsed]
                if not rSlot then
                    rSlot = {}
                    rSlot.toggleBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
                    core.Skin.Button(rSlot.toggleBtn, "bar")
                    rSlot.arrowTex = rSlot.toggleBtn:CreateTexture(nil, "OVERLAY")
                    rSlot.arrowTex:SetSize(14, 14); rSlot.arrowTex:SetPoint("LEFT", 6, 0)
                    rSlot.recipeFS = rSlot.toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    rSlot.recipeFS:SetPoint("LEFT", 24, 0)
                    rSlot.miniBarBg = rSlot.toggleBtn:CreateTexture(nil, "BACKGROUND")
                    rSlot.miniBarBg:SetSize(50, 4); rSlot.miniBarBg:SetPoint("RIGHT", -8, 0)
                    rSlot.miniBarFill = rSlot.toggleBtn:CreateTexture(nil, "ARTWORK")
                    rSlot.miniBarFill:SetPoint("LEFT", rSlot.miniBarBg, "LEFT", 0, 0)
                    recipeTogglePool[recipeToggleUsed] = rSlot
                end
                toggleBtn = rSlot.toggleBtn
                toggleBtn:SetParent(card)
                toggleBtn:SetFrameLevel(lvl)
                toggleBtn:ClearAllPoints()
                toggleBtn:SetSize(halfW, 24)
                toggleBtn:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, y)
                toggleBtn:Show()

                rSlot.arrowTex:SetAtlas(isExpanded and "housing-floor-arrow-down-default" or "housing-floor-arrow-up-default")
                rSlot.recipeFS:SetTextColor(unpack(T.text))
                rSlot.recipeFS:SetText(string.format(pluginNs.L("HOUSING_LABEL"), knownCount, totalRecipes))
                rSlot.miniBarBg:SetColorTexture(unpack(T.roles.input[1]))
                if totalRecipes > 0 then
                    local pctR = knownCount / totalRecipes
                    rSlot.miniBarFill:SetSize(math.max(math.floor(pctR * 50), 1), 4)
                    rSlot.miniBarFill:SetColorTexture(pctR>=1 and 0 or 0.45, pctR>=1 and 0.85 or 0.55, pctR>=1 and 0.35 or 1.00, 0.9)
                    rSlot.miniBarBg:Show(); rSlot.miniBarFill:Show()
                else
                    rSlot.miniBarBg:Hide(); rSlot.miniBarFill:Hide()
                end

                toggleBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(isExpanded and pluginNs.L("HOUSING_FOLD") or pluginNs.L("HOUSING_UNFOLD"), 0.8, 0.8, 1)
                    GameTooltip:AddLine(string.format(pluginNs.L("HOUSING_KNOWN"), knownCount, totalRecipes), 1, 1, 1)
                    GameTooltip:Show()
                end)
                toggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                local capturedKey = rKey
                toggleBtn:SetScript("OnClick", function()
                    pluginNs.recipeExpanded[capturedKey] = not pluginNs.recipeExpanded[capturedKey]
                    pluginNs.ShowProfessions()
                end)

                if isExpanded then
                    local capDefs, capKnown = hp.defs, hp.known
                    deferred[#deferred + 1] = function(parent, yy)
                        return pluginNs.RenderRecipeGrid(parent, capDefs, capKnown, PADX - 14, yy, contentW)
                    end
                end
            end

            -- Barre « Recettes » (ViewerLog_Recette) : à droite de Housing, ou
            -- à sa place si le métier n'a pas de recettes housing.
            local _, gridFn = pluginNs.RenderRecipeBar(card, profData, realmName, charName,
                toggleBtn, PADX - 14, y, contentW, true, halfW)
            if gridFn then deferred[#deferred + 1] = gridFn end

            rowH = math.max(rowH, cardH)

            -- Fin de ligne : on avance, puis grilles dépliées sous la ligne
            if col == ncols - 1 or idx == #visibleProfs then
                offsetY = rowTop - rowH - 12
                for _, fn in ipairs(deferred) do offsetY = fn(sc, offsetY) end
            end
        end

        offsetY = offsetY - 10
        end -- #visibleProfs
    end

    sc:SetHeight(math.abs(offsetY) + 60)
    HideUnusedPools()
end
