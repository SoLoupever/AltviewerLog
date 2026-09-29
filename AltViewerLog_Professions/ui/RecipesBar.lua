local addonName, pluginNs = ...

-- ============================================================
-- BARRE "RECETTES" — dépend de ViewerLog_Recette
--
-- Fichier séparé de ui/View.lua (qui gère la barre Housing) : cette
-- fonctionnalité reste isolée dans son propre fichier au sein de cet
-- addon. Une injection cross-addon complète (ViewerLog_Recette
-- dessinant lui-même dans cette vue) a été tentée avant : trop
-- fragile en pratique (pas de hook propre côté hôte pour savoir
-- quand une passe de rendu ShowProfessions() commence/finit, sans un
-- bricolage à base de minuteur à délai 0). Revenu à du code direct
-- dans ce même addon, juste dans un fichier à part — le lien avec
-- ViewerLog_Recette reste isolé et contrôlé : uniquement une lecture
-- de _G.ViewerLogAPI.GetRecipes(), rien de plus.
--
-- pluginNs.RenderRecipeBar(...) ne dessine RIEN et se rend
-- invisible si ViewerLog_Recette n'est pas actif — vérifié à chaque
-- appel (pas seulement au chargement, pour refléter correctement un
-- /reload après avoir désactivé la dépendance depuis le panneau
-- ViewerLog).
--
-- Coordination avec ui/View.lua : ce fichier a ses propres pools
-- (privés, pas posés sur pluginNs) mais expose deux fonctions pour
-- que ui/View.lua les intègre dans son propre cycle
-- ShowProfessions()/HideUnusedPools() déjà existant, plutôt que de
-- dupliquer ce mécanisme :
--   • pluginNs.ResetRecipeBarPools()      — en tête de ShowProfessions()
--   • pluginNs.HideUnusedRecipeBarPools() — dans HideUnusedPools()
-- ============================================================

pluginNs.recipeExpandedBar = pluginNs.recipeExpandedBar or {}

local barPool,    barUsed    = {}, 0
local headerPool, headerUsed = {}, 0

-- Grille de recettes : rendu asynchrone (par lots) pour ne pas geler le client
-- quand un métier a des centaines de recettes (dépliage "toutes extensions").
-- Les icônes ont leur propre pool piloté par le job async, hors du cycle
-- synchrone barPool/headerPool. Une seule grille dépliée à la fois.
local gridIconPool = {}
local gridJob      = nil    -- timer du lot en cours
local gridGen      = 0      -- incrémenté à chaque rendu → invalide le job précédent
local gridProgress = nil    -- barre de progression (créée à la volée)

local GRID_SYNC_THRESHOLD = 80   -- en dessous : rendu direct (aucune latence)
local GRID_CHUNK          = 40   -- icônes dessinées par frame au-delà du seuil

local function RecipeBarKey(realmName, charName, profName)
    return realmName .. "||" .. charName .. "||" .. profName
end

local function HideAllGridIcons()
    for i = 1, #gridIconPool do gridIconPool[i]:Hide() end
end

local function HideGridProgress()
    if gridProgress then gridProgress:Hide() end
end

-- Annule le rendu de grille en cours et masque icônes + barre. Appelé en tête
-- de chaque passe ShowProfessions (via ResetRecipeBarPools) : une grille
-- repliée ne laisse donc aucune icône résiduelle.
local function CancelGridRender()
    gridGen = gridGen + 1
    if gridJob then gridJob:Cancel(); gridJob = nil end
    HideAllGridIcons()
    HideGridProgress()
end

function pluginNs.ResetRecipeBarPools()
    barUsed, headerUsed = 0, 0
    CancelGridRender()
end

function pluginNs.HideUnusedRecipeBarPools()
    for i = barUsed + 1, #barPool do barPool[i].bg:Hide() end
    for i = headerUsed + 1, #headerPool do
        headerPool[i].sep:Hide(); headerPool[i].fs:Hide()
    end
end

-- Rattache un nom de palier (capturé par ViewerLog_Recette) à
-- l'entrée canonique de pluginNs.EXPANSION_LIST — même table (avec
-- alias FR/EN) que celle qui colore déjà le housing — pour un ordre
-- et une couleur cohérents. nil si aucune correspondance : groupe
-- "Autres".
local function MatchExpansion(tierName)
    if not tierName or not pluginNs.EXPANSION_LIST then return nil end
    -- Insensible à la casse : les noms de ligne de métier varient (EN/FR,
    -- majuscules) et le simple find sensible à la casse ratait beaucoup de
    -- paliers (Northrend, Outland, Pandaria, Kul Tiran/Zandalari…).
    local lt = tierName:lower()
    for _, exp in ipairs(pluginNs.EXPANSION_LIST) do
        if lt:find(exp.name:lower(), 1, true) then return exp.name end
        for _, alias in ipairs(exp.aliases or {}) do
            if lt:find(alias:lower(), 1, true) then return exp.name end
        end
    end
    return nil
end

-- Grille dépliée : toutes les recettes (connues ET non connues, code
-- couleur vert/rouge comme pluginNs.RenderRecipeGrid pour le
-- housing), groupées par extension. Icônes/en-têtes poolés — un
-- métier peut avoir plusieurs centaines de recettes (contre une
-- trentaine pour le housing curé), sans pooling ça fait grossir le
-- nombre de régions de core.scrollChild sans limite à chaque
-- rafraîchissement (déjà provoqué un crash avant le pooling).
-- query (optionnel, déjà en minuscules) : ne garde que les recettes dont
-- le nom contient la chaîne recherchée. nil = aucune restriction.
-- Dessine (ou recycle) une icône de recette du pool à l'index i, à sa
-- position absolue pré-calculée. Extrait de RenderGrid pour être réutilisable
-- en synchrone (petite grille) comme en asynchrone (lots).
local function DrawGridIcon(parent, i, desc, iconSize)
    local f = gridIconPool[i]
    if not f then
        f = CreateFrame("Button", nil, parent, "BackdropTemplate")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        f.tex = f:CreateTexture(nil, "ARTWORK")
        f.tex:SetPoint("TOPLEFT", 2, -2); f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
        f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        gridIconPool[i] = f
    end
    f:SetParent(parent)
    f:SetSize(iconSize, iconSize)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", desc.x, desc.y)
    f.tex:SetTexture(desc.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    if desc.learned then
        f:SetBackdropBorderColor(0.10, 0.85, 0.20, 1)
        f:SetBackdropColor(0.04, 0.14, 0.04, 1)
        f.tex:SetVertexColor(1, 1, 1)
    else
        f:SetBackdropBorderColor(0.70, 0.10, 0.10, 0.9)
        f:SetBackdropColor(0.14, 0.04, 0.04, 1)
        f.tex:SetVertexColor(0.35, 0.35, 0.35)
    end
    local rName = desc.name or "?"
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(rName, 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:Show()
end

-- Barre de progression (singleton). Placée au-dessus de la grille pendant le
-- dessin par lots ; frame level relevé pour rester visible sous les icônes.
local function GetGridProgress(parent)
    if not gridProgress then
        local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        p:SetHeight(14)
        p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        p:SetBackdropColor(0.06, 0.06, 0.10, 0.95)
        p:SetBackdropBorderColor(0.30, 0.30, 0.45, 1)
        p.fill = p:CreateTexture(nil, "ARTWORK")
        p.fill:SetPoint("TOPLEFT", 1, -1); p.fill:SetPoint("BOTTOMLEFT", 1, 1)
        p.fill:SetColorTexture(0.35, 0.55, 1.0, 0.9)
        p.label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.label:SetPoint("CENTER")
        gridProgress = p
    end
    gridProgress:SetParent(parent)
    gridProgress:SetFrameLevel(parent:GetFrameLevel() + 10)
    return gridProgress
end

local function UpdateGridProgress(done, total, width)
    local p = gridProgress
    if not p then return end
    local frac = (total > 0) and (done / total) or 1
    p.fill:SetWidth(math.max((width - 2) * frac, 1))
    p.label:SetText(string.format("%s  %d/%d", pluginNs.L("RBAR_LOADING"), done, total))
end

-- Grille dépliée : toutes les recettes (connues ET non connues, code couleur
-- vert/rouge), groupées par extension. Un métier peut avoir des centaines de
-- recettes : au-delà de GRID_SYNC_THRESHOLD, les icônes sont dessinées par
-- lots sur plusieurs frames (barre de progression) pour ne pas geler le
-- client. La hauteur finale (offsetY) est calculée immédiatement de façon
-- déterministe → la mise en page sous la grille reste correcte pendant que
-- les icônes se remplissent.
-- query (optionnel, déjà en minuscules) : ne garde que les recettes dont le
-- nom contient la chaîne recherchée. nil = aucune restriction.
local function RenderGrid(parent, profRecipes, LEFT_PAD, offsetY, contentW, query)
    contentW = contentW or 660
    local gridLeft   = LEFT_PAD + 14
    local gridAvailW = contentW - gridLeft - 10
    local ICON_SIZE, ICON_GAP = 30, 4
    local ICONS_PER_ROW = math.max(4, math.min(16,
        math.floor((gridAvailW + ICON_GAP) / (ICON_SIZE + ICON_GAP))
    ))

    local OTHER_KEY = "__other__"
    local groups, groupOrder = {}, {}
    if pluginNs.EXPANSION_LIST then
        for _, exp in ipairs(pluginNs.EXPANSION_LIST) do
            groups[exp.name] = {}
            groupOrder[#groupOrder + 1] = exp.name
        end
    end
    groups[OTHER_KEY] = {}
    groupOrder[#groupOrder + 1] = OTHER_KEY

    local anyEntry = false
    for recipeID, e in pairs(profRecipes.entries or {}) do
        if (not query) or (e.name and e.name:lower():find(query, 1, true)) then
            anyEntry = true
            local expName = MatchExpansion(e.tier) or OTHER_KEY
            local g = groups[expName]
            g[#g + 1] = { id = recipeID, name = e.name, icon = e.icon, learned = e.learned }
        end
    end
    if not anyEntry then return offsetY end

    offsetY = offsetY - 6
    local gridTopY = offsetY   -- pour placer la barre de progression

    -- Respecte le filtre d'extensions du bouton engrenage (même table
    -- AltViewerLogDB.hiddenExpansions, clé = nom canonique d'extension).
    -- OTHER_KEY (extension inconnue) n'a pas de case et reste toujours visible.
    local hiddenExp = AltViewerLogDB and AltViewerLogDB.hiddenExpansions or {}

    -- Descripteurs d'icônes (positions absolues pré-calculées). Les en-têtes,
    -- peu nombreux, sont dessinés tout de suite ; seules les icônes passent par
    -- le rendu par lots.
    local iconDescs = {}

    for _, expName in ipairs(groupOrder) do
        local list = groups[expName]
        local filteredOut = (expName ~= OTHER_KEY) and hiddenExp[expName]
        if #list > 0 and not filteredOut then
            table.sort(list, function(a, b)
                if a.learned ~= b.learned then return a.learned end
                return (a.name or "") < (b.name or "")
            end)

            local known = 0
            for _, r in ipairs(list) do if r.learned then known = known + 1 end end

            local color = (expName ~= OTHER_KEY and pluginNs.GetTierColor and pluginNs.GetTierColor(expName))
                or { r = 0.5, g = 0.5, b = 0.5 }
            local label = (expName ~= OTHER_KEY) and expName or pluginNs.L("RBAR_OTHER")

            headerUsed = headerUsed + 1
            local hSlot = headerPool[headerUsed]
            if not hSlot then
                hSlot = {}
                hSlot.sep = parent:CreateTexture(nil, "ARTWORK")
                hSlot.sep:SetHeight(1)
                hSlot.fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                headerPool[headerUsed] = hSlot
            end

            hSlot.sep:ClearAllPoints()
            hSlot.sep:SetPoint("TOPLEFT", gridLeft, offsetY)
            hSlot.sep:SetWidth(gridAvailW)
            hSlot.sep:SetColorTexture(color.r, color.g, color.b, 0.5)
            hSlot.sep:Show()

            hSlot.fs:ClearAllPoints()
            hSlot.fs:SetPoint("TOPLEFT", gridLeft, offsetY - 2)
            hSlot.fs:SetTextColor(color.r, color.g, color.b)
            hSlot.fs:SetText(string.format("%s  %d/%d", label, known, #list))
            hSlot.fs:Show()

            offsetY = offsetY - 16

            local col, row = 0, 0
            for _, r in ipairs(list) do
                iconDescs[#iconDescs + 1] = {
                    x = gridLeft + col * (ICON_SIZE + ICON_GAP),
                    y = offsetY - row * (ICON_SIZE + ICON_GAP),
                    icon = r.icon, learned = r.learned, name = r.name,
                }
                col = col + 1
                if col >= ICONS_PER_ROW then col = 0; row = row + 1 end
            end

            local totalRows = math.ceil(#list / ICONS_PER_ROW)
            offsetY = offsetY - totalRows * (ICON_SIZE + ICON_GAP) - 10
        end
    end

    -- ── Rendu des icônes (direct ou par lots) ────────────────────────────
    local total = #iconDescs
    -- Nouveau rendu : invalide tout job précédent et repart à zéro.
    gridGen = gridGen + 1
    local myGen = gridGen
    if gridJob then gridJob:Cancel(); gridJob = nil end
    HideAllGridIcons()

    if total <= GRID_SYNC_THRESHOLD then
        HideGridProgress()
        for i = 1, total do DrawGridIcon(parent, i, iconDescs[i], ICON_SIZE) end
    else
        local prog = GetGridProgress(parent)
        prog:ClearAllPoints()
        prog:SetPoint("TOPLEFT", gridLeft, gridTopY)
        prog:SetWidth(gridAvailW)
        prog:Show()
        UpdateGridProgress(0, total, gridAvailW)

        local drawn = 0
        local function DrawChunk()
            if myGen ~= gridGen then return end   -- rendu remplacé entre-temps
            local stop = math.min(drawn + GRID_CHUNK, total)
            for i = drawn + 1, stop do DrawGridIcon(parent, i, iconDescs[i], ICON_SIZE) end
            drawn = stop
            UpdateGridProgress(drawn, total, gridAvailW)
            if drawn < total then
                gridJob = C_Timer.NewTimer(0, DrawChunk)
            else
                gridJob = nil
                HideGridProgress()
            end
        end
        DrawChunk()
    end

    return offsetY
end

--- Dessine la barre "Recettes" pour ce métier, à droite de anchorFrame
--- (le bouton Housing) si fourni, sinon à sa place (métier sans
--- recettes housing curées). Ne fait rien — et cache le pool à
--- l'index courant — si ViewerLog_Recette n'est pas actif.
--- @return number  nouveau offsetY
function pluginNs.RenderRecipeBar(parent, profData, realmName, charName, anchorFrame, LEFT_PAD, offsetY, contentW)
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetRecipes then
        -- ViewerLog_Recette pas actif : rien à afficher. Le pool ne
        -- gagne pas d'index ici (pas de barUsed = barUsed + 1) — ce
        -- qui reste au-delà du dernier index utilisé par un appel
        -- précédent est déjà masqué par HideUnusedRecipeBarPools().
        return offsetY
    end

    barUsed = barUsed + 1
    local bSlot = barPool[barUsed]
    if not bSlot then
        bSlot = {}
        bSlot.bg = CreateFrame("Button", nil, parent, "BackdropTemplate")
        bSlot.bg:SetSize(280, 18)
        bSlot.bg:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1 })
        bSlot.bg:SetBackdropColor(0.08, 0.08, 0.12, 0.85); bSlot.bg:SetBackdropBorderColor(0.28, 0.28, 0.38, 1)

        -- Même agencement que le bouton Housing (arrowTex / texte /
        -- mini-barre), mêmes atlas de flèche pour une identité
        -- visuelle cohérente entre les deux barres.
        bSlot.arrowTex = bSlot.bg:CreateTexture(nil, "OVERLAY")
        bSlot.arrowTex:SetSize(14, 14); bSlot.arrowTex:SetPoint("LEFT", 3, 0)

        bSlot.textFS = bSlot.bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        bSlot.textFS:SetPoint("LEFT", 21, 0); bSlot.textFS:SetTextColor(0.65, 0.65, 0.85)

        bSlot.miniBarBg = bSlot.bg:CreateTexture(nil, "BACKGROUND")
        bSlot.miniBarBg:SetSize(60, 4); bSlot.miniBarBg:SetPoint("RIGHT", -6, 0); bSlot.miniBarBg:SetColorTexture(0.15, 0.15, 0.20, 1)
        bSlot.miniBarFill = bSlot.bg:CreateTexture(nil, "ARTWORK")
        bSlot.miniBarFill:SetPoint("LEFT", bSlot.miniBarBg, "LEFT", 0, 0)

        barPool[barUsed] = bSlot
    end

    bSlot.bg:ClearAllPoints()
    if anchorFrame then
        bSlot.bg:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 10, 0)
    else
        -- Pas de bouton Housing pour ce métier : la barre Recettes
        -- prend sa place plutôt que de ne jamais s'afficher.
        bSlot.bg:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT_PAD + 14, offsetY)
    end
    bSlot.bg:Show()

    local rKey        = RecipeBarKey(realmName, charName, profData.name)
    local isExpanded  = pluginNs.recipeExpandedBar[rKey] or false
    local recipeData  = vlAPI.GetRecipes(charName, realmName)
    local profRecipes = recipeData and recipeData[profData.name]
    local hasData     = profRecipes and profRecipes.entries and profRecipes.total and profRecipes.total > 0

    -- Recherche de recette (>= 2 caractères) : déplie et filtre les métiers
    -- qui contiennent au moins une correspondance, sans toucher à l'état
    -- déplié/replié manuel de l'utilisateur.
    local query = pluginNs._recipeQuery
    query = query and query:gsub("^%s*(.-)%s*$", "%1"):lower() or ""
    local searching = #query >= 2
    local matchCount = 0
    if searching and hasData then
        -- Ignore les recettes d'extensions masquées (filtre engrenage) pour
        -- ne pas déplier une grille qui serait entièrement filtrée.
        local hiddenExp = AltViewerLogDB and AltViewerLogDB.hiddenExpansions or {}
        for _, e in pairs(profRecipes.entries) do
            if e.name and e.name:lower():find(query, 1, true) then
                local expName = MatchExpansion(e.tier)
                if not (expName and hiddenExp[expName]) then
                    matchCount = matchCount + 1
                end
            end
        end
    end
    -- Déplié effectif : forcé par la recherche (si ≥1 match), sinon état manuel.
    local effExpanded = searching and (matchCount > 0) or (not searching and isExpanded)

    if hasData then
        local rKnown, rTotal = profRecipes.known or 0, profRecipes.total

        bSlot.arrowTex:SetAtlas(effExpanded and "housing-floor-arrow-down-default" or "housing-floor-arrow-up-default")
        bSlot.textFS:SetText(string.format(pluginNs.L("RBAR_LABEL"), rKnown, rTotal))

        if rTotal > 0 then
            local fillW = math.max(math.floor((rKnown / rTotal) * 60), 1)
            bSlot.miniBarFill:SetSize(fillW, 4)
            local pct = rKnown / rTotal
            bSlot.miniBarFill:SetColorTexture(pct>=1 and 0 or 0.45, pct>=1 and 0.85 or 0.55, pct>=1 and 0.35 or 1.00, 0.9)
            bSlot.miniBarBg:Show(); bSlot.miniBarFill:Show()
        else
            bSlot.miniBarBg:Hide(); bSlot.miniBarFill:Hide()
        end

        bSlot.bg:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.45, 0.45, 0.65, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format(pluginNs.L("RBAR_TOOLTIP"), rKnown, rTotal), 1, 1, 1)
            GameTooltip:AddLine(isExpanded and pluginNs.L("RBAR_FOLD") or pluginNs.L("RBAR_UNFOLD"), 0.8, 0.8, 1)
            GameTooltip:Show()
        end)
        bSlot.bg:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.28, 0.28, 0.38, 1)
            GameTooltip:Hide()
        end)

        local capturedKey = rKey
        bSlot.bg:SetScript("OnClick", function()
            -- Une seule grille dépliée à la fois : cf. commentaire de
            -- tête, déjà source d'un crash à deux grosses grilles
            -- ouvertes ensemble.
            local willExpand = not pluginNs.recipeExpandedBar[capturedKey]
            wipe(pluginNs.recipeExpandedBar)
            if willExpand then pluginNs.recipeExpandedBar[capturedKey] = true end
            pluginNs.ShowProfessions()
        end)
    else
        bSlot.arrowTex:SetTexture(nil)
        bSlot.miniBarBg:Hide(); bSlot.miniBarFill:Hide()
        bSlot.textFS:SetTextColor(0.5, 0.5, 0.5, 1)
        bSlot.textFS:SetText(pluginNs.L("RBAR_NO_DATA"))
        bSlot.bg:SetScript("OnEnter", nil)
        bSlot.bg:SetScript("OnLeave", nil)
        bSlot.bg:SetScript("OnClick", nil)
    end

    if hasData and effExpanded then
        -- Démarrer la grille SOUS la rangée de boutons (barre Recettes/Housing,
        -- ~18px) : sinon le 1er groupe (en-tête + compteur) se dessine à la
        -- hauteur des boutons et passe derrière eux.
        offsetY = RenderGrid(parent, profRecipes, LEFT_PAD, offsetY - 24, contentW,
                             searching and query or nil)
    end

    return offsetY
end
