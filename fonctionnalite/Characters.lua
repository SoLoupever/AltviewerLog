local addonName, ns = ...

local math_floor = math.floor

-- ====================================================
-- UTILITAIRES LOCAUX : temps écoulé / temps joué (clés de traduction)
-- ====================================================
local function FormatTimeSince(lastLogin)
    if not lastLogin or lastLogin <= 0 then return "?" end
    local elapsed = math.max(0, time() - lastLogin)
    local d = math_floor(elapsed / 86400)
    local h = math_floor((elapsed % 86400) / 3600)
    local m = math_floor((elapsed % 3600) / 60)
    if d > 0 then return ns.L("TIME_AGO_DH"):format(d, h) end
    if h > 0 then return ns.L("TIME_AGO_HM"):format(h, m) end
    return ns.L("TIME_AGO_M"):format(m)
end

local function FormatTimePlayed(seconds)
    if not seconds or seconds <= 0 then return "" end
    local d = math_floor(seconds / 86400)
    local h = math_floor((seconds % 86400) / 3600)
    local m = math_floor((seconds % 3600) / 60)
    if d > 0 then return ns.L("TIME_DH"):format(d, h) end
    if h > 0 then return ns.L("TIME_HM"):format(h, m) end
    return ns.L("TIME_M"):format(m)
end

-- ====================================================
-- POOL LOCAL : cartes personnage
-- ====================================================
local ROW_H     = 62
local ROW_GAP   = 8
local PROF_SZ   = 30
local RIGHT_PAD = 12 + PROF_SZ + 6 + PROF_SZ + 16   -- colonne or/temps ancrée à gauche des métiers
local RIGHT_W   = 190                               -- largeur réservée à la colonne or/temps

local cardPool = {}
local activeCharFrames = {}

local function MakeProfBox(f)
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetSize(PROF_SZ, PROF_SZ)
    ns.Skin.Frame(box, "input")
    box.tex = box:CreateTexture(nil, "ARTWORK")
    box.tex:SetPoint("TOPLEFT", 2, -2)
    box.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    box.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return box
end

local function AcquireCard(parent)
    local f = table.remove(cardPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
    else
        f = CreateFrame("Button", nil, parent, "BackdropTemplate")
        ns.Skin.Frame(f, "card")

        -- Anneau de classe + icône de faction (cercles)
        f.fact = f:CreateTexture(nil, "ARTWORK")
        f.fact:SetSize(38, 38)
        f.fact:SetPoint("LEFT", 12, 0)

        f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.nameText:SetPoint("TOPLEFT", 62, -11)
        f.nameText:SetJustifyH("LEFT")
        f.nameText:SetWordWrap(false)

        f.guildText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.guildText:SetPoint("LEFT", f.nameText, "RIGHT", 8, 0)
        f.guildText:SetJustifyH("LEFT")
        f.guildText:SetWordWrap(false)

        f.infoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.infoText:SetPoint("TOPLEFT", 62, -35)
        f.infoText:SetJustifyH("LEFT")

        -- Statut connexion : icône de pierre (inchangée) + texte
        f.trackingIcon = CreateFrame("Button", nil, f)
        f.trackingIcon:SetSize(16, 16)
        f.trackingIcon:SetPoint("LEFT", f.infoText, "RIGHT", 12, 0)

        f.statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.statusText:SetPoint("LEFT", f.trackingIcon, "RIGHT", 5, 0)
        f.statusText:SetWidth(110)
        f.statusText:SetJustifyH("LEFT")

        f.restedText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.restedText:SetPoint("LEFT", f.statusText, "RIGHT", 6, 0)
        f.restedText:SetWidth(100)
        f.restedText:SetJustifyH("LEFT")

        -- Colonne droite : or (haut) / temps joué (bas)
        f.goldText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.goldText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT_PAD, -12)
        f.goldText:SetJustifyH("RIGHT")

        f.timeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.timeText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -RIGHT_PAD, -35)
        f.timeText:SetJustifyH("RIGHT")

        f.prof2Frame = MakeProfBox(f)
        f.prof2Frame:SetPoint("RIGHT", -12, 0)
        f.prof2Tex = f.prof2Frame.tex
        f.prof1Frame = MakeProfBox(f)
        f.prof1Frame:SetPoint("RIGHT", f.prof2Frame, "LEFT", -6, 0)
        f.prof1Tex = f.prof1Frame.tex
    end
    f:Show()
    table.insert(activeCharFrames, f)
    return f
end

local function ReleaseCharFrames()
    for _, f in ipairs(activeCharFrames) do
        f:Hide()
        f:SetScript("OnClick", nil)
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
        f._hover = false
        table.insert(cardPool, f)
    end
    activeCharFrames = {}
end

-- Boîte métier : icône + tooltip, ou masquée
local function FillProfBox(box, prof)
    if not prof then
        box:Hide()
        box:SetScript("OnEnter", nil)
        box:SetScript("OnLeave", nil)
        return
    end
    box.tex:SetTexture(prof.icon)
    box:Show()
    box:EnableMouse(true)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(prof.name, 1, 0.85, 0)
        if prof.tiers and prof.tiers[1] then
            local t = prof.tiers[1]
            GameTooltip:AddLine(string.format("%s : %d / %d", t.name, t.level, t.max), 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", GameTooltip_Hide)
end

-- ====================================================
-- BARRE DE RECHERCHE DE PERSONNAGE
-- Parentée à la ScrollFrame (pas au scrollChild) : ClearContent()
-- ne vide QUE le scrollChild, donc la barre garde son focus et son
-- texte pendant qu'on tape (un rebuild du scrollChild ne la masque
-- pas). Un hook sur ns.ClearContent la cache dès qu'une AUTRE vue
-- s'affiche ; RefreshCharacterList la ré-affiche.
-- ====================================================
local function EnsureCharSearchBox()
    if ns._charSearchBox then return ns._charSearchBox end
    if not ns.scrollFrame then return nil end

    local box = CreateFrame("EditBox", nil, ns.scrollFrame, "BackdropTemplate")
    box:SetAutoFocus(false)
    box:SetSize(220, 28)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(28, 22, 0, 0)
    ns.Skin.Frame(box, "input")
    box:SetFrameLevel(ns.scrollFrame:GetFrameLevel() + 20)
    box:SetPoint("TOPRIGHT", ns.scrollFrame, "TOPRIGHT", -14, -10)
    box:HookScript("OnEditFocusGained", function(s) s._hover = true;  ns.Skin.Paint(s) end)
    box:HookScript("OnEditFocusLost",   function(s) s._hover = false; ns.Skin.Paint(s) end)

    local ico = box:CreateTexture(nil, "OVERLAY")
    ico:SetSize(14, 14)
    ico:SetPoint("LEFT", 8, 0)
    ico:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    local ph = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 28, 0)
    ph:SetText(ns.L("CHAR_SEARCH_PLACEHOLDER"))
    box._placeholder = ph

    local clr = CreateFrame("Button", nil, box)
    clr:SetSize(14, 14)
    clr:SetPoint("RIGHT", -5, 0)
    -- Texture (pas un glyphe : la police WoW n'a pas le caractère ✕).
    local clrTex = clr:CreateTexture(nil, "OVERLAY")
    clrTex:SetAllPoints()
    clrTex:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    clr:SetScript("OnClick", function()
        box:SetText("")
        box:ClearFocus()
    end)
    clr:Hide()
    box._clear = clr

    box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
    box:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)
    box:SetScript("OnTextChanged", function(s)
        local t = s:GetText() or ""
        ns._charSearchQuery = t
        s._placeholder:SetShown(t == "")
        s._clear:SetShown(t ~= "")
        ns.RefreshCharacterList()
    end)

    ns._charSearchBox = box
    return box
end

-- Cache la barre quand une autre vue vide le contenu ; RefreshCharacterList
-- lève ce drapeau le temps de son propre ClearContent pour la garder visible.
do
    local _origClearContent = ns.ClearContent
    if _origClearContent and not ns._charSearchClearHooked then
        ns._charSearchClearHooked = true
        ns.ClearContent = function(...)
            if ns._charSearchBox and not ns._charSearchRefreshing then
                ns._charSearchBox:Hide()
            end
            return _origClearContent(...)
        end
    end
end

-- Test de correspondance (nom de perso ou nom de serveur).
local function CharMatchesQuery(charName, realmName, query)
    if query == "" then return true end
    return (charName and charName:lower():find(query, 1, true) ~= nil)
        or (realmName and realmName:lower():find(query, 1, true) ~= nil)
end

-- ====================================================
-- HELPER : Groupe les personnages par realm depuis le DataProvider
-- ====================================================
local function BuildRealmMap()
    local realmMap = {}  -- { [realmName] = { {name=charName, data=charData}, ... } }
    for _, entry in ipairs(ns.DP_GetAllChars()) do
        realmMap[entry.realm] = realmMap[entry.realm] or {}
        table.insert(realmMap[entry.realm], { name = entry.char, data = entry.data })
    end
    return realmMap
end

-- Petit bouton flèche (monter / descendre un serveur)
local function MakeArrowButton(parent, anchor, offsetX, atlas, tipKey, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(22, 22)
    btn:SetPoint("LEFT", anchor, "RIGHT", offsetX, 2)
    ns.Skin.Button(btn)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetSize(14, 14)
    tex:SetPoint("CENTER")
    tex:SetAtlas(atlas)
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L(tipKey), 1, 1, 0.5)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Remplit une carte personnage
local function FillCard(btn, rowW, offsetY, charName, realmName, data, isOnline)
    local t = ns.Theme
    btn:SetSize(rowW, ROW_H)
    btn:SetPoint("TOPLEFT", 10, offsetY)

    local class = data and data.class
    local c = (class and RAID_CLASS_COLORS[class]) or { r = 1, g = 1, b = 1 }
    local dimHex = ns.ColorHex(t.textDim)

    -- Anneau (couleur de classe) + faction
    local faction = data and data.faction
    btn.fact:SetTexture(faction == "Horde"
        and "Interface\\Icons\\PVPCurrency-Honor-Horde"
        or  "Interface\\Icons\\PVPCurrency-Honor-Alliance")
    btn.fact:SetDesaturated(false)
    btn.fact:SetVertexColor(1, 1, 1)

    -- Nom + guilde
    btn.nameText:SetText(charName)
    btn.nameText:SetTextColor(c.r, c.g, c.b)
    local guild = data and data.guild
    if guild and guild ~= "" then
        btn.guildText:SetText("[" .. guild .. "]")
        btn.guildText:SetTextColor(c.r, c.g, c.b)
        local room = rowW - 62 - RIGHT_W - RIGHT_PAD - btn.nameText:GetStringWidth() - 8
        btn.guildText:SetWidth(math.max(40, room))
        btn.guildText:Show()
    else
        btn.guildText:SetText("")
        btn.guildText:Hide()
    end

    -- Niveau | ilvl
    btn.infoText:SetText(string.format("%s  |cff%s|||r  %s",
        ns.L("CHAR_LEVEL"):format((data and data.level) or 0), dimHex,
        ns.L("CHAR_ILVL"):format((data and data.ilvl) or 0)))
    btn.infoText:SetTextColor(t.text[1], t.text[2], t.text[3])

    -- Statut connexion
    if isOnline then
        btn.trackingIcon:SetNormalAtlas("DungeonStoneCheckpoint")
        btn.trackingIcon:SetAlpha(1)
        btn.statusText:SetText("|cff33ff55" .. ns.L("ONLINE") .. "|r")
    else
        btn.trackingIcon:SetNormalAtlas("DungeonStoneCheckpointDeactivated")
        btn.trackingIcon:SetAlpha(0.3)
        btn.statusText:SetText("|cff" .. dimHex
            .. FormatTimeSince(data and data.lastLogin) .. "|r")
    end

    -- XP reposé — règle (masqué au niveau max, accès ViewerLog)
    -- centralisée dans DataProvider pour que toute future vue
    -- en hérite automatiquement sans dupliquer la logique.
    local restedPct = ns.DP_GetRestedPct(charName, realmName, data)
    if restedPct and restedPct > 0 then
        btn.restedText:SetText("|cff88ddff" .. restedPct .. "% " .. ns.L("RESTED_XP") .. "|r")
        btn.restedText:Show()
    else
        btn.restedText:SetText("")
        btn.restedText:Hide()
    end

    -- Or + temps joué
    btn.goldText:SetText(GetCoinTextureString((data and data.gold) or 0))
    local played = FormatTimePlayed((data and data.timePlayed) or nil)
    btn.timeText:SetText(played ~= "" and ("|cff" .. dimHex
        .. ns.L("PLAYED_LABEL"):format(played) .. "|r") or "")

    -- Métiers
    local profs = {}
    if data and data.professions then
        for _, p in ipairs(data.professions) do
            if not p.secondary and p.icon then
                table.insert(profs, p)
                if #profs >= 2 then break end
            end
        end
    end
    FillProfBox(btn.prof1Frame, profs[1])
    FillProfBox(btn.prof2Frame, profs[2])

    -- Click & hover
    btn._hover = false
    ns.Skin.Paint(btn)
    btn:SetScript("OnClick", function() ns.ShowBags(data, charName, realmName) end)
    btn:SetScript("OnEnter", function(s) s._hover = true;  ns.Skin.Paint(s) end)
    btn:SetScript("OnLeave", function(s) s._hover = false; ns.Skin.Paint(s) end)
end

-- ====================================================
-- AFFICHAGE LISTE DES PERSONNAGES
-- ====================================================
function ns.RefreshCharacterList()
    if not ns.scrollChild then return end
    ns.currentView = ns.RefreshCharacterList
    ns.currentViewIsBank = false
    -- Garde la barre de recherche visible pendant NOTRE ClearContent.
    ns._charSearchRefreshing = true
    ns.ClearContent()
    ns._charSearchRefreshing = false
    ReleaseCharFrames()

    -- Barre de recherche (toujours affichée sur la vue Personnages).
    local searchBox = EnsureCharSearchBox()
    if searchBox then searchBox:Show() end
    local query = (ns._charSearchQuery or ""):gsub("^%s*(.-)%s*$", "%1"):lower()

    -- Message si aucune source de données
    if not ns.DP_IsReady() then
        local msg = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("CENTER", ns.scrollChild, "CENTER", 0, 0)
        msg:SetText("|cffff9900" .. ns.L("CHARS_NO_DATA") .. "|r")
        ns.scrollChild:SetHeight(200)
        return
    end

    local t = ns.Theme
    local settings = ns.DP_GetSettings() or {}
    local offsetY = -14
    local startOffsetY = offsetY   -- repère pour détecter "aucun résultat"
    local rowW = math.max(200, ns.scrollChild:GetWidth() - 20)

    -- ── Grouper les personnages par realm ────────────────────────
    local realmMap = BuildRealmMap()

    -- ── Construire la liste des serveurs ─────────────────────────
    local realmDataList = {}
    for realmName, chars in pairs(realmMap) do
        table.insert(realmDataList, { name = realmName, charCount = #chars })
    end

    -- Tri : alphabétique ou par population
    table.sort(realmDataList, function(a, b)
        if settings.sortByPop then
            if a.charCount ~= b.charCount then return a.charCount > b.charCount end
        end
        return a.name < b.name
    end)

    -- Appliquer l'ordre personnalisé des serveurs
    local savedOrder = settings.realmOrder
    if savedOrder and #savedOrder > 0 then
        local lookup = {}
        for _, info in ipairs(realmDataList) do lookup[info.name] = info end
        local ordered = {}
        for _, rName in ipairs(savedOrder) do
            if lookup[rName] then
                table.insert(ordered, lookup[rName])
                lookup[rName] = nil
            end
        end
        for _, info in ipairs(realmDataList) do
            if lookup[info.name] then table.insert(ordered, info) end
        end
        realmDataList = ordered
    end

    local totalRealms = #realmDataList

    -- Réordonne un serveur (delta = -1 monte, +1 descend)
    local function MoveRealm(idx, delta)
        local order = {}
        for _, ri in ipairs(realmDataList) do table.insert(order, ri.name) end
        order[idx], order[idx + delta] = order[idx + delta], order[idx]
        AltViewerLogDB.settings = AltViewerLogDB.settings or {}
        AltViewerLogDB.settings.realmOrder = order
        ns.RefreshCharacterList()
    end

    for realmIdx, realmInfo in ipairs(realmDataList) do
      -- repeat/until true : idiome "continue" (Lua 5.1 n'a pas goto).
      repeat
        local realmName = realmInfo.name

        -- ── Filtrage par recherche ───────────────────────────────────
        -- shownChars = personnages retenus (tous si recherche vide).
        local realmChars = realmMap[realmName] or {}
        local shownChars = realmChars
        if query ~= "" then
            shownChars = {}
            for _, ce in ipairs(realmChars) do
                if CharMatchesQuery(ce.name, realmName, query) then
                    shownChars[#shownChars + 1] = ce
                end
            end
            -- Aucun perso ne correspond sur ce serveur : on l'omet.
            if #shownChars == 0 then break end
        end
        local displayCount = (query ~= "") and #shownChars or realmInfo.charCount

        -- ── En-tête du serveur : nom, compteur, contrôles, filet ─────
        local realmTitle = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        realmTitle:SetPoint("TOPLEFT", 14, offsetY)
        realmTitle:SetText(realmName)
        realmTitle:SetTextColor(unpack(t.heading))

        local realmSub = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        realmSub:SetPoint("TOPLEFT", 14, offsetY - 26)
        realmSub:SetText(ns.L("REALM_CHAR_COUNT"):format(displayCount))
        realmSub:SetTextColor(unpack(t.textDim))

        do
            local capturedIdx = realmIdx
            local ox = 12
            if realmIdx > 1 then
                MakeArrowButton(ns.scrollChild, realmTitle, ox,
                    "housing-floor-arrow-up-default", "REALM_MOVE_UP",
                    function() MoveRealm(capturedIdx, -1) end)
                ox = ox + 26
            end
            if realmIdx < totalRealms then
                MakeArrowButton(ns.scrollChild, realmTitle, ox,
                    "housing-floor-arrow-down-default", "REALM_MOVE_DOWN",
                    function() MoveRealm(capturedIdx, 1) end)
                ox = ox + 26
            end
            ns.CreateRealmToggleButton(ns.scrollChild, realmTitle, realmName, ox)
        end

        local rule = ns.Skin.Rule(ns.scrollChild)
        rule:SetPoint("TOPLEFT", ns.scrollChild, "TOPLEFT", 10, offsetY - 46)
        rule:SetWidth(rowW)

        offsetY = offsetY - 58

        -- ── Personnages (masqués si le serveur est replié) ────────────
        -- Pendant une recherche, on ignore l'état replié pour montrer
        -- directement les résultats.
        if (query ~= "") or (not ns.IsRealmCollapsed(realmName)) then
            local charList = shownChars
            local currentPlayer = UnitName("player")
            local currentRealm  = GetRealmName()

            table.sort(charList, function(a, b)
                local aOnline = (a.name == currentPlayer and realmName == currentRealm)
                local bOnline = (b.name == currentPlayer and realmName == currentRealm)
                if aOnline ~= bOnline then return aOnline end
                local aTime = (a.data and a.data.lastLogin) or 0
                local bTime = (b.data and b.data.lastLogin) or 0
                return aTime > bTime
            end)

            for _, charEntry in ipairs(charList) do
                local isOnline = (charEntry.name == currentPlayer and realmName == currentRealm)
                local btn = AcquireCard(ns.scrollChild)
                FillCard(btn, rowW, offsetY, charEntry.name, realmName, charEntry.data, isOnline)
                offsetY = offsetY - ROW_H - ROW_GAP
            end
        end
        offsetY = offsetY - 14
      until true
    end

    -- Message si la recherche ne retourne rien.
    if query ~= "" and offsetY == startOffsetY then
        local none = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        none:SetPoint("TOPLEFT", 15, offsetY)
        none:SetText("|cffff9900" .. ns.L("CHAR_SEARCH_NONE") .. "|r")
        offsetY = offsetY - 30
    end

    ns.scrollChild:SetHeight(math.abs(offsetY) + 30)
    ns.UpdateBottomBar()
end
