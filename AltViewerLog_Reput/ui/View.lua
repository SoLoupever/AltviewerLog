local addonName, pluginNs = ...

-- ====================================================
-- REPUT / UI / VIEW — Affichage des réputations
--
-- Affiche toutes les réputations d'un personnage sous
-- forme de liste scrollable avec barres de progression.
--
-- Structure d'une ligne :
--   [Nom (200px)] [======Barre======] [Réaction/Renom]
--
-- Tri : factions majeures en premier (renom desc),
--       puis factions classiques (réaction desc, nom asc).
--
-- Types gérés :
--   • Classique  – réaction 1-8, barre de palier
--   • Majeure    – renom X/Y, barre du niveau courant
--   • Paragon    – barre paragon + niveau cumulé
-- ====================================================

local core = nil   -- initialisé dans pluginNs.ShowReput

-- ── Dimensions ────────────────────────────────────────────────────
local NAME_W     = 200   -- largeur colonne nom
local REACTION_W = 140   -- largeur colonne réaction/renom (droite)
local ROW_H      = 22    -- hauteur d'une ligne
local ROW_GAP    = 3     -- espace entre les lignes
local MARGIN_L   = 22    -- marge gauche
local HEADER_H   = 96    -- espace réservé au-dessus de la liste

-- ── Couleurs par niveau de réaction ──────────────────────────────
local REACTION_COLOR = {
    [1] = { 0.70, 0.10, 0.10 },   -- Détesté    rouge foncé
    [2] = { 0.90, 0.25, 0.25 },   -- Hostile    rouge
    [3] = { 0.90, 0.55, 0.15 },   -- Inamical   orange
    [4] = { 0.80, 0.80, 0.40 },   -- Neutre     jaune
    [5] = { 0.30, 0.80, 0.35 },   -- Amical     vert clair
    [6] = { 0.10, 0.75, 0.55 },   -- Estimé     vert-cyan
    [7] = { 0.35, 0.60, 1.00 },   -- Révéré     bleu
    [8] = { 0.80, 0.40, 1.00 },   -- Exalté     violet
}
-- Couleur spéciale pour les factions majeures (renom)
local MAJOR_COLOR = { 0.40, 0.80, 1.00 }    -- bleu ciel (texte renom)
local MAJOR_BAR   = { 0.89, 0.67, 0.00 }    -- or (barre renom)
local ACCENT      = { 0.60, 0.32, 0.85 }    -- violet (titre, en-têtes)
local PARAGON_BAR = { 1.00, 0.75, 0.00 }    -- or (barre paragon)

-- ── Catégories par extension ──────────────────────────────────────
local EXP_HEADER_H     = 26
local EXP_HEADER_COLOR = { 0.90, 0.86, 0.95 }

-- ── Pools ───────────────────────────────────────────────────────────
-- Les objets (FontString/Texture/Frame) sont créés une seule fois puis
-- réutilisés/repositionnés d'un rafraîchissement à l'autre — plus de
-- recréation à chaque DrawReputView() (déclenché entre autres par
-- UPDATE_FACTION tant que la vue est active, donc potentiellement
-- fréquent). *Used est remis à 0 en tête de DrawReputView() ; tout
-- slot au-delà de *Used après le rendu est masqué par HideUnusedPoolSlots().
local expHeaderPool, expHeaderUsed = {}, 0
local rowPool,       rowUsed       = {}, 0

local function HideUnusedPoolSlots()
    for i = rowUsed + 1, #rowPool do
        local s = rowPool[i]
        s.accent:Hide(); s.nameFS:Hide(); s.bg:Hide(); s.fill:Hide(); s.rightFS:Hide(); s.hit:Hide()
    end
    for i = expHeaderUsed + 1, #expHeaderPool do
        local s = expHeaderPool[i]
        s.bg:Hide(); s.acc:Hide(); s.fs:Hide()
    end
end

local function DrawExpansionHeader(scrollChild, rowY, barW, label)
    local totalW = NAME_W + barW + REACTION_W
    local T = core.Theme

    expHeaderUsed = expHeaderUsed + 1
    local slot = expHeaderPool[expHeaderUsed]
    if not slot then
        slot = {}
        slot.bg  = scrollChild:CreateTexture(nil, "BACKGROUND")
        slot.acc = scrollChild:CreateTexture(nil, "ARTWORK")
        slot.fs  = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        slot.fs:SetJustifyH("LEFT")
        slot.fs:SetJustifyV("MIDDLE")
        expHeaderPool[expHeaderUsed] = slot
    end

    slot.bg:ClearAllPoints()
    slot.bg:SetPoint("TOPLEFT", MARGIN_L - 6, rowY)
    slot.bg:SetSize(totalW + 6, EXP_HEADER_H)
    slot.bg:SetColorTexture(ACCENT[1] * 0.22 + 0.04, ACCENT[2] * 0.14 + 0.04, ACCENT[3] * 0.30 + 0.05, 1)

    slot.acc:ClearAllPoints()
    slot.acc:SetPoint("TOPLEFT", MARGIN_L - 6, rowY)
    slot.acc:SetSize(3, EXP_HEADER_H)
    slot.acc:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)

    slot.fs:ClearAllPoints()
    slot.fs:SetPoint("TOPLEFT", MARGIN_L + 8, rowY)
    slot.fs:SetSize(totalW, EXP_HEADER_H)
    slot.fs:SetText(label:upper())
    slot.fs:SetTextColor(EXP_HEADER_COLOR[1], EXP_HEADER_COLOR[2], EXP_HEADER_COLOR[3])

    slot.bg:Show(); slot.acc:Show(); slot.fs:Show()
end

-- ── État courant de la vue ────────────────────────────────────────
pluginNs.isViewActive   = false
pluginNs.currentCharName = nil   -- exposé pour Init.lua (compartment tooltip)
pluginNs.currentRealm    = nil

-- ── Sélection du personnage par défaut ────────────────────────────
-- Priorité : personnage connecté (s'il a des réputations),
-- puis premier personnage trouvé avec des données.
local function GetDefaultChar()
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.IsReady() then return nil, nil end

    local player = UnitName("player")
    local realm  = GetRealmName()

    local myReps = vlAPI.GetReputations(player, realm)
    if myReps and next(myReps) then
        return player, realm
    end

    -- GetAllCharacters() applique déjà le filtre IsRealm en interne
    -- (clés réservées comme guilds/settings exclues) : pas besoin de
    -- le refaire ici.
    for _, key in ipairs(vlAPI.GetAllCharacters()) do
        local cData = vlAPI.GetCharacterByKey(key)
        if cData and cData.reputations and next(cData.reputations) then
            local charName, realmName = key:match("^(.+)@(.+)$")
            if charName then return charName, realmName end
        end
    end
    return nil, nil
end

-- ── Calcul du % de remplissage de la barre ───────────────────────
local function GetBarPct(d)
    -- Paragon : priorité sur tout (barre de progression dans le palier)
    if d.paragonValue and d.paragonCap and d.paragonCap > 0 then
        return d.paragonValue / d.paragonCap, true   -- true = mode paragon
    end
    -- Faction majeure : progression dans le niveau de renom courant
    if d.isMajor then
        if d.renownCap and d.renownCap > 0 then
            return (d.renownEarned or 0) / d.renownCap, false
        end
        return 1, false   -- max atteint
    end
    -- Exalté (sans paragon) : barre pleine
    if d.reaction == 8 then
        return 1, false
    end
    -- Cas normal
    local range = (d.top or 0) - (d.bottom or 0)
    if range <= 0 then return 0, false end
    return math.max(0, math.min(((d.standing or 0) - (d.bottom or 0)) / range, 1)), false
end

-- ── Tri des factions ──────────────────────────────────────────────
-- 1. Majeures d'abord → renom desc
-- 2. Classiques → réaction desc → nom asc
local function SortFactions(a, b)
    local ad, bd = a.data, b.data
    if ad.isMajor and not bd.isMajor then return true  end
    if not ad.isMajor and bd.isMajor then return false end
    if ad.isMajor and bd.isMajor then
        local ar = (ad.renown or 0) + (ad.paragonLevel or 0)
        local br = (bd.renown or 0) + (bd.paragonLevel or 0)
        if ar ~= br then return ar > br end
        return (ad.name or "") < (bd.name or "")
    end
    local ar = ad.reaction or 0
    local br = bd.reaction or 0
    if ar ~= br then return ar > br end
    return (ad.name or "") < (bd.name or "")
end

-- ── Dessin d'une ligne de faction ────────────────────────────────
local function DrawRow(scrollChild, rowY, barW, fid, d)
    local L     = pluginNs.L
    local name  = d.name or "???"
    local pct, isParagon = GetBarPct(d)

    -- Couleur principale de la ligne
    local col
    if d.isMajor then
        col = MAJOR_COLOR
    else
        col = REACTION_COLOR[d.reaction] or REACTION_COLOR[4]
    end
    local r, g, b = col[1], col[2], col[3]

    rowUsed = rowUsed + 1
    local slot = rowPool[rowUsed]
    if not slot then
        slot = {}
        slot.accent = scrollChild:CreateTexture(nil, "BACKGROUND")

        slot.nameFS = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        slot.nameFS:SetJustifyH("LEFT")
        slot.nameFS:SetJustifyV("MIDDLE")
        slot.nameFS:SetWordWrap(false)

        slot.bg = scrollChild:CreateTexture(nil, "BACKGROUND")

        slot.fill = scrollChild:CreateTexture(nil, "ARTWORK")

        slot.rightFS = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.rightFS:SetJustifyH("LEFT")
        slot.rightFS:SetJustifyV("MIDDLE")

        slot.hit = CreateFrame("Frame", nil, scrollChild)
        slot.hit:EnableMouse(true)

        rowPool[rowUsed] = slot
    end

    -- ── Nom (texte clair, filet d'accent à gauche) ───────────────
    local T = core.Theme
    slot.accent:ClearAllPoints()
    slot.accent:SetPoint("TOPLEFT", MARGIN_L - 6, rowY)
    slot.accent:SetSize(2, ROW_H)
    slot.accent:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
    slot.accent:Show()

    slot.nameFS:ClearAllPoints()
    slot.nameFS:SetPoint("TOPLEFT", MARGIN_L + 4, rowY)
    slot.nameFS:SetSize(NAME_W - 10, ROW_H)
    slot.nameFS:SetText(name)
    slot.nameFS:SetTextColor(T.text[1], T.text[2], T.text[3])

    -- ── Barre de progression ──────────────────────────────────────
    local barX = MARGIN_L + NAME_W

    slot.bg:ClearAllPoints()
    slot.bg:SetPoint("TOPLEFT", barX, rowY - 4)
    slot.bg:SetSize(barW, ROW_H - 8)
    slot.bg:SetColorTexture(T.roles.input[1][1], T.roles.input[1][2], T.roles.input[1][3], 1)

    -- Remplissage
    if pct > 0 then
        local fillW = math.max(2, math.floor(barW * pct))
        slot.fill:ClearAllPoints()
        slot.fill:SetPoint("TOPLEFT", barX, rowY - 4)
        slot.fill:SetSize(fillW, ROW_H - 8)
        if isParagon then
            slot.fill:SetColorTexture(PARAGON_BAR[1], PARAGON_BAR[2], PARAGON_BAR[3], 0.85)
        elseif d.isMajor then
            slot.fill:SetColorTexture(MAJOR_BAR[1], MAJOR_BAR[2], MAJOR_BAR[3], 0.95)
        else
            slot.fill:SetColorTexture(r, g, b, 0.90)
        end
        slot.fill:Show()
    else
        slot.fill:Hide()
    end

    -- ── Label droite : réaction ou renom ──────────────────────────
    local labelX = barX + barW + 8
    local rightText

    if d.isMajor then
        local maxR = (d.maxRenown and d.maxRenown > 0) and d.maxRenown or "?"
        if d.renown == d.maxRenown and d.maxRenown then
            rightText = L("RENOWN_MAX")
        else
            rightText = L("RENOWN_LABEL"):format(d.renown or 0, maxR)
        end
        -- Indicateur paragon (renom max + paragon)
        if d.paragonLevel and d.paragonLevel > 0 then
            rightText = rightText .. " / " .. d.paragonLevel
        end
    elseif d.paragonLevel and d.paragonLevel > 0 then
        rightText = L("REACTION_8") .. " / " .. d.paragonLevel
        if d.paragonReady then
            rightText = rightText .. " |cff00ff80✦|r"
        end
    else
        rightText = L("REACTION_" .. (d.reaction or 4))
    end

    slot.rightFS:ClearAllPoints()
    slot.rightFS:SetPoint("TOPLEFT", labelX, rowY)
    slot.rightFS:SetSize(REACTION_W - 8, ROW_H)
    slot.rightFS:SetText(rightText)
    if d.isMajor then
        slot.rightFS:SetTextColor(MAJOR_COLOR[1], MAJOR_COLOR[2], MAJOR_COLOR[3])
    else
        slot.rightFS:SetTextColor(r, g, b)
    end

    -- ── Cadre invisible pour le tooltip ───────────────────────────
    -- Le script OnEnter est réassigné (pas seulement repositionné) :
    -- son contenu capture "d" par fermeture, qui change à chaque ligne
    -- réutilisant ce slot du pool. Un simple repositionnement laisserait
    -- un tooltip obsolète (données de l'ancienne ligne à cette position).
    local totalW = NAME_W + barW + REACTION_W
    slot.hit:ClearAllPoints()
    slot.hit:SetPoint("TOPLEFT", MARGIN_L, rowY)
    slot.hit:SetSize(totalW, ROW_H + ROW_GAP)

    local capName, capD, capFid = name, d, fid

    slot.hit:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        -- Titre
        GameTooltip:AddLine(capName, 1, 1, 1)

        if capD.isAccountWide then
            GameTooltip:AddLine(L("TT_ACCOUNT_WIDE"), 0.60, 0.80, 1.00)
        end

        GameTooltip:AddLine(" ")

        if capD.isMajor then
            -- Renom
            local maxR = capD.maxRenown or "?"
            local cr, cg, cb = MAJOR_COLOR[1], MAJOR_COLOR[2], MAJOR_COLOR[3]
            GameTooltip:AddLine(L("TT_RENOWN"):format(capD.renown or 0, maxR), cr, cg, cb)
            if capD.renownCap and capD.renownCap > 0 then
                GameTooltip:AddLine(L("TT_RENOWN_EARNED"):format(capD.renownEarned or 0, capD.renownCap),
                    0.70, 0.70, 0.70)
            end
        else
            -- Réaction classique
            local reactCol = REACTION_COLOR[capD.reaction] or REACTION_COLOR[4]
            local reactName = L("REACTION_" .. (capD.reaction or 4))
            GameTooltip:AddLine(L("TT_REACTION"):format(reactName),
                reactCol[1], reactCol[2], reactCol[3])

            -- Progression dans le palier
            if capD.reaction and capD.reaction < 8 then
                local cur   = (capD.standing or 0) - (capD.bottom or 0)
                local total = (capD.top or 0)      - (capD.bottom or 0)
                if total > 0 then
                    GameTooltip:AddLine(L("TT_PROGRESS"):format(cur, total), 0.70, 0.70, 0.70)
                end
            elseif capD.reaction == 8 and not capD.paragonLevel then
                GameTooltip:AddLine(L("TT_PROGRESS"):format(1, 1), 0.70, 0.70, 0.70)
            end
        end

        -- Paragon
        if capD.paragonLevel and capD.paragonLevel > 0 then
            GameTooltip:AddLine(" ")
            local pColor = { PARAGON_BAR[1], PARAGON_BAR[2], PARAGON_BAR[3] }
            GameTooltip:AddLine(
                L("TT_PARAGON"):format(capD.paragonLevel, capD.paragonValue or 0, capD.paragonCap or 0),
                pColor[1], pColor[2], pColor[3])
            if capD.paragonReady then
                GameTooltip:AddLine(L("PARAGON_READY"), 0.10, 1.00, 0.50)
            end
        end

        -- Date de mise à jour
        if capD.updatedAt and capD.updatedAt > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(
                L("TT_LAST_UPDATE"):format(date("%d/%m/%Y %H:%M", capD.updatedAt)),
                0.40, 0.40, 0.40)
        end

        -- Personnage le plus avancé (tout le compte) — pas de sens si
        -- account-wide (valeur partagée) ou si c'est déjà celui affiché
        if not capD.isAccountWide then
            local bChar, bRealm, bClass, bData = pluginNs.GetBestCharacter(capFid)
            if bChar and (bChar ~= pluginNs.currentCharName or bRealm ~= pluginNs.currentRealm) then
                local cc = (bClass and RAID_CLASS_COLORS[bClass]) or { r = 1, g = 1, b = 1 }
                local bLabel = bData.isMajor
                    and L("RENOWN_LABEL"):format(bData.renown or 0, bData.maxRenown or "?")
                    or L("REACTION_" .. (bData.reaction or 4))

                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(L("TT_BEST_CHAR"), L("CHAR_LABEL"):format(bChar, bRealm),
                    0.70, 0.70, 0.70, cc.r, cc.g, cc.b)
                GameTooltip:AddLine(bLabel, 0.70, 0.70, 0.70)
            end
        end

        GameTooltip:Show()
    end)

    slot.hit:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    slot.nameFS:Show()
    slot.bg:Show()
    slot.rightFS:Show()
    slot.hit:Show()
end

-- ── Affichage principal ───────────────────────────────────────────
local function DrawReputView()
    if not core then core = _G.AltViewerLogAPI end
    if not core then return end

    core.ClearContent()
    local scrollChild = core.scrollChild
    local L = pluginNs.L

    -- Remis à 0 à chaque rafraîchissement : DrawRow/DrawExpansionHeader
    -- les incrémentent, HideUnusedPoolSlots() masque tout au-delà.
    rowUsed, expHeaderUsed = 0, 0

    -- ── Titre ─────────────────────────────────────────────────────
    local T = core.Theme
    local title = scrollChild._reputTitle
    if not title then
        title = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        scrollChild._reputTitle = title
    end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", MARGIN_L, -14)
    title:SetText(L("REPUT_TITLE"))
    title:SetTextColor(0.75, 0.40, 1.00)
    title:Show()

    local rule = scrollChild._reputRule
    if not rule then
        rule = core.Skin.Rule(scrollChild)
        scrollChild._reputRule = rule
    end
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", MARGIN_L - 6, -76)
    rule:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -12, -76)
    rule:Show()

    -- ── Vérification ViewerLog ────────────────────────────────────
    if not _G.ViewerLogAPI or not _G.ViewerLogAPI.IsReady() then
        local err = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        err:SetPoint("TOP", 0, -100)
        err:SetText(L("NO_DATA"))
        scrollChild:SetHeight(200)
        HideUnusedPoolSlots()
        return
    end

    -- ── Sélection du personnage ───────────────────────────────────
    if not pluginNs.currentCharName or not pluginNs.currentRealm then
        pluginNs.currentCharName, pluginNs.currentRealm = GetDefaultChar()
    end

    if not pluginNs.currentCharName then
        local nd = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        nd:SetPoint("TOP", 0, -100)
        nd:SetText(L("NO_DATA"))
        scrollChild:SetHeight(200)
        HideUnusedPoolSlots()
        return
    end

    local charData = _G.ViewerLogAPI.GetCharacter(pluginNs.currentCharName, pluginNs.currentRealm)
    local reps     = charData and charData.reputations

    -- ── Nom du personnage + bouton sélecteur ──────────────────────
    local charLabel = scrollChild._reputCharLabel
    if not charLabel then
        charLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        scrollChild._reputCharLabel = charLabel
    end
    charLabel:ClearAllPoints()
    charLabel:SetPoint("TOPLEFT", MARGIN_L, -46)
    charLabel:SetText(L("CHAR_LABEL"):format(pluginNs.currentCharName, pluginNs.currentRealm))
    -- Couleur de classe si disponible, sinon blanc
    local classColor = charData and charData.class
                       and RAID_CLASS_COLORS[charData.class]
    if classColor then
        charLabel:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        charLabel:SetTextColor(1, 1, 1)
    end
    charLabel:Show()

    -- Bouton pour changer de personnage (même style que la banque)
    -- Contenu et scripts statiques (ne dépendent d'aucune donnée de la
    -- ligne courante) : création unique suffit, pas besoin de les
    -- réassigner à chaque rafraîchissement comme pour le tooltip de ligne.
    local selBtn = scrollChild._reputSelBtn
    if not selBtn then
        selBtn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        scrollChild._reputSelBtn = selBtn
        selBtn:SetSize(28, 28)
        core.Skin.Button(selBtn)
        selBtn.ico = selBtn:CreateTexture(nil, "ARTWORK")
        selBtn.ico:SetPoint("TOPLEFT", 4, -4)
        selBtn.ico:SetPoint("BOTTOMRIGHT", -4, 4)
        selBtn.ico:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
        selBtn:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_LEFT")
            GameTooltip:AddLine(core.L and core.L("CHAR_SWITCH_TT") or pluginNs.L("CHAR_SWITCH_TT"), 1, 1, 1)
            GameTooltip:Show()
        end)
        selBtn:SetScript("OnLeave", function(s)
            GameTooltip:Hide()
        end)
        selBtn:SetScript("OnClick", function(s)
            if core.OpenCharSelector then
                core.OpenCharSelector(s, function(newChar, newRealm)
                    pluginNs.currentCharName = newChar
                    pluginNs.currentRealm    = newRealm
                    DrawReputView()
                end)
            end
        end)
    end
    selBtn:ClearAllPoints()
    selBtn:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -14, -18)
    selBtn:Show()

    -- ── Données manquantes ────────────────────────────────────────
    if not reps or not next(reps) then
        local nd = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        nd:SetPoint("TOP", 0, -100)
        nd:SetText(L("NO_SCAN_YET"))
        scrollChild:SetHeight(200)
        HideUnusedPoolSlots()
        return
    end

    -- ── Construction et tri de la liste ──────────────────────────
    local sorted = {}
    for fid, d in pairs(reps) do
        if type(d) == "table" and d.name then
            sorted[#sorted + 1] = { fid = fid, data = d }
        end
    end
    table.sort(sorted, SortFactions)

    -- ── Largeur dynamique de la barre ────────────────────────────
    local contentW = core.GetContentWidth and core.GetContentWidth() or 660
    local barW     = math.max(60, contentW - MARGIN_L - NAME_W - REACTION_W - MARGIN_L)

    -- ── Lecture du groupe d'extension depuis les données stockées ──
    for _, entry in ipairs(sorted) do
        entry.expansionGroup = entry.data.expansionGroup or "???"
        entry.expansionOrder = entry.data.expansionOrder or math.huge
    end

    -- ── Regroupement par groupe d'extension ──────────────────────
    local byExp      = {}
    local expOrder   = {}
    local expOrdVal  = {}   -- expansionOrder pour le tri

    for _, entry in ipairs(sorted) do
        local grp = entry.expansionGroup
        if not byExp[grp] then
            byExp[grp]            = {}
            expOrder[#expOrder+1] = grp
            expOrdVal[grp]        = entry.expansionOrder
        end
        byExp[grp][#byExp[grp]+1] = entry
    end
    -- Ordre Blizzard : expansionOrder=1 = plus recent → tri ascendant
    -- "???" (math.huge) part en dernier
    table.sort(expOrder, function(a, b)
        return (expOrdVal[a] or math.huge) < (expOrdVal[b] or math.huge)
    end)

    -- ── Rendu des lignes groupées par extension ───────────────────
    local rowY = -(HEADER_H)

    for i, grp in ipairs(expOrder) do
        DrawExpansionHeader(scrollChild, rowY, barW, grp)
        rowY = rowY - EXP_HEADER_H - 4

        for _, entry in ipairs(byExp[grp]) do
            DrawRow(scrollChild, rowY, barW, entry.fid, entry.data)
            rowY = rowY - ROW_H - ROW_GAP
        end

        if i < #expOrder then
            rowY = rowY - 10   -- espace entre groupes
        end
    end

    scrollChild:SetHeight(math.abs(rowY) + 40)
    HideUnusedPoolSlots()
end

-- ── API publique du plugin ────────────────────────────────────────

-- Rafraîchit la vue si elle est active (appelé après un scan)
function pluginNs.RefreshView()
    if pluginNs.isViewActive then
        DrawReputView()
    end
end

-- Point d'entrée principal (appelé par le bouton sidebar)
function pluginNs.ShowReput()
    core = _G.AltViewerLogAPI
    if not core then return end

    pluginNs.isViewActive = true
    core.currentView        = pluginNs.ShowReput
    core.currentViewIsBank  = false
    DrawReputView()
end
