local addonName, ns = ...

local math_floor = math.floor

-- ====================================================
-- UTILITAIRE LOCAL : Temps écoulé depuis lastLogin
-- ====================================================
local function FormatTimeSince(lastLogin)
    if not lastLogin or lastLogin <= 0 then return "?" end
    local elapsed = time() - lastLogin
    if elapsed < 0 then elapsed = 0 end
    local d = math.floor(elapsed / 86400)
    local h = math.floor((elapsed % 86400) / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local isFR = ns.L("TIME_FORMAT"):find("j")
    if d > 0 then
        return string.format(isFR and "il y a %dj %dh" or "%dd %dh ago", d, h)
    elseif h > 0 then
        return string.format(isFR and "il y a %dh %dm" or "%dh %dm ago", h, m)
    else
        return string.format(isFR and "il y a %dm" or "%dm ago", m)
    end
end

-- ====================================================
-- UTILITAIRE LOCAL : Temps total joué (timePlayed en secondes)
-- ====================================================
local function FormatTimePlayed(seconds)
    if not seconds or seconds <= 0 then return "" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    if d > 0 then return string.format("%dj %dh", d, h) end
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

-- ====================================================
-- POOL LOCAL : Boutons backdrop pour les lignes de perso
-- ====================================================
local backdropBtnPool = {}
local activeCharFrames = {}

local function AcquireBackdropButton(parent)
    local f = table.remove(backdropBtnPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
    else
        f = CreateFrame("Button", nil, parent, "BackdropTemplate")

        f.fact = f:CreateTexture(nil, "OVERLAY")
        f.fact:SetSize(25, 25)
        f.fact:SetPoint("LEFT", 10, 5)

        f.txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.txt:SetPoint("TOPLEFT", 45, -8)
        f.txt:SetPoint("RIGHT", -110, 0)
        f.txt:SetJustifyH("LEFT")
        f.txt:SetWordWrap(false)

        f.trackingIcon = CreateFrame("Button", nil, f)
        f.trackingIcon:SetSize(16, 16)
        f.trackingIcon:SetPoint("BOTTOMLEFT", 45, 7)

        f.statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.statusText:SetPoint("LEFT", f.trackingIcon, "RIGHT", 5, 0)
        f.statusText:SetWidth(140)
        f.statusText:SetJustifyH("LEFT")

        f.restedText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.restedText:SetPoint("LEFT", f.statusText, "RIGHT", 10, 0)
        f.restedText:SetWidth(100)
        f.restedText:SetJustifyH("LEFT")

        f.prof2Frame = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.prof2Frame:SetSize(28, 28)
        f.prof2Frame:SetPoint("RIGHT", -8, 4)
        f.prof2Frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                    edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f.prof2Frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        f.prof2Frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        f.prof2Tex = f.prof2Frame:CreateTexture(nil, "ARTWORK")
        f.prof2Tex:SetPoint("TOPLEFT", 2, -2)
        f.prof2Tex:SetPoint("BOTTOMRIGHT", -2, 2)
        f.prof2Tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        f.prof1Frame = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.prof1Frame:SetSize(28, 28)
        f.prof1Frame:SetPoint("RIGHT", f.prof2Frame, "LEFT", -4, 0)
        f.prof1Frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                    edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f.prof1Frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        f.prof1Frame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        f.prof1Tex = f.prof1Frame:CreateTexture(nil, "ARTWORK")
        f.prof1Tex:SetPoint("TOPLEFT", 2, -2)
        f.prof1Tex:SetPoint("BOTTOMRIGHT", -2, 2)
        f.prof1Tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
        table.insert(backdropBtnPool, f)
    end
    activeCharFrames = {}
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
    box:SetSize(180, 24)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(24, 20, 0, 0)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                      edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    box:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
    box:SetBackdropBorderColor(0.35, 0.30, 0.55, 1)
    box:SetFrameLevel(ns.scrollFrame:GetFrameLevel() + 20)
    box:SetPoint("TOPRIGHT", ns.scrollFrame, "TOPRIGHT", -14, -10)

    local ico = box:CreateTexture(nil, "OVERLAY")
    ico:SetSize(14, 14)
    ico:SetPoint("LEFT", 6, 0)
    ico:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    local ph = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 24, 0)
    ph:SetText(ns.L("CHAR_SEARCH_PLACEHOLDER"))
    box._placeholder = ph

    local clr = CreateFrame("Button", nil, box)
    clr:SetSize(14, 14)
    clr:SetPoint("RIGHT", -4, 0)
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

    local settings = ns.DP_GetSettings() or {}
    local offsetY = -20
    local startOffsetY = offsetY   -- repère pour détecter "aucun résultat"

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

        -- ── Titre du serveur ─────────────────────────────────────────
        local realmTitle = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        realmTitle:SetPoint("TOPLEFT", 15, offsetY)
        realmTitle:SetText(ns.L("REALM_TITLE") .. realmName .. " (" .. displayCount .. ")")
        realmTitle:SetTextColor(1, 0.8, 0)

        -- ── Boutons ▲ ▼ pour réordonner les serveurs ─────────────────
        do
            local capturedIdx = realmIdx
            local arrowOffsetX = 8

            if realmIdx > 1 then
                local upBtn = CreateFrame("Button", nil, ns.scrollChild, "BackdropTemplate")
                upBtn:SetSize(18, 16)
                upBtn:SetPoint("LEFT", realmTitle, "RIGHT", arrowOffsetX, 2)
                upBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                    edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                upBtn:SetBackdropColor(0.10, 0.15, 0.25, 1)
                upBtn:SetBackdropBorderColor(0.30, 0.45, 0.70, 1)
                local upTex = upBtn:CreateTexture(nil, "OVERLAY")
                upTex:SetSize(14, 14)
                upTex:SetPoint("CENTER")
                upTex:SetAtlas("housing-floor-arrow-up-default")
                upBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.18, 0.28, 0.45, 1)
                    self:SetBackdropBorderColor(0.50, 0.70, 1.00, 1)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(ns.L("REALM_MOVE_UP") or "Monter ce serveur", 1, 1, 0.5)
                    GameTooltip:Show()
                end)
                upBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0.10, 0.15, 0.25, 1)
                    self:SetBackdropBorderColor(0.30, 0.45, 0.70, 1)
                    GameTooltip:Hide()
                end)
                upBtn:SetScript("OnClick", function()
                    local order = {}
                    for _, ri in ipairs(realmDataList) do table.insert(order, ri.name) end
                    local i = capturedIdx
                    order[i], order[i-1] = order[i-1], order[i]
                    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
                    AltViewerLogDB.settings.realmOrder = order
                    ns.RefreshCharacterList()
                end)
                arrowOffsetX = arrowOffsetX + 22
            end

            if realmIdx < totalRealms then
                local downBtn = CreateFrame("Button", nil, ns.scrollChild, "BackdropTemplate")
                downBtn:SetSize(18, 16)
                downBtn:SetPoint("LEFT", realmTitle, "RIGHT", arrowOffsetX, 2)
                downBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                      edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                downBtn:SetBackdropColor(0.10, 0.15, 0.25, 1)
                downBtn:SetBackdropBorderColor(0.30, 0.45, 0.70, 1)
                local downTex = downBtn:CreateTexture(nil, "OVERLAY")
                downTex:SetSize(14, 14)
                downTex:SetPoint("CENTER")
                downTex:SetAtlas("housing-floor-arrow-down-default")
                downBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.18, 0.28, 0.45, 1)
                    self:SetBackdropBorderColor(0.50, 0.70, 1.00, 1)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(ns.L("REALM_MOVE_DOWN") or "Descendre ce serveur", 1, 1, 0.5)
                    GameTooltip:Show()
                end)
                downBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0.10, 0.15, 0.25, 1)
                    self:SetBackdropBorderColor(0.30, 0.45, 0.70, 1)
                    GameTooltip:Hide()
                end)
                downBtn:SetScript("OnClick", function()
                    local order = {}
                    for _, ri in ipairs(realmDataList) do table.insert(order, ri.name) end
                    local i = capturedIdx
                    order[i], order[i+1] = order[i+1], order[i]
                    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
                    AltViewerLogDB.settings.realmOrder = order
                    ns.RefreshCharacterList()
                end)
                arrowOffsetX = arrowOffsetX + 22
            end

            ns.CreateRealmToggleButton(ns.scrollChild, realmTitle, realmName, arrowOffsetX)
        end

        offsetY = offsetY - 40

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
                local charName, data = charEntry.name, charEntry.data
                local isOnline = (charName == currentPlayer and realmName == currentRealm)

                local btn = AcquireBackdropButton(ns.scrollChild)
                local rowW = math.max(200, ns.scrollChild:GetWidth() - 20)
                btn:SetSize(rowW, 58)
                btn:SetPoint("TOPLEFT", 10, offsetY)
                btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                btn:SetBackdropColor(0.10, 0.10, 0.10, 0.96)

                -- Icône de faction
                local faction = data and data.faction
                btn.fact:SetTexture(faction == "Horde"
                    and "Interface\\Icons\\PVPCurrency-Honor-Horde"
                    or  "Interface\\Icons\\PVPCurrency-Honor-Alliance")

                -- Texte ligne du haut
                local class = data and data.class
                local c = (class and RAID_CLASS_COLORS[class]) or { r = 1, g = 1, b = 1 }
                btn.txt:SetTextColor(c.r, c.g, c.b)
                local guildStr = ""
                if data and data.guild and data.guild ~= "" then
                    local cr = string.format("%02x%02x%02x",
                        math_floor((c.r or 1) * 255),
                        math_floor((c.g or 1) * 255),
                        math_floor((c.b or 1) * 255))
                    guildStr = "  |cff" .. cr .. "[" .. data.guild .. "]|r"
                end
                btn.txt:SetText(string.format("%s  Lv%d  ilvl %d  %s  %s%s",
                    charName,
                    (data and data.level) or 0,
                    (data and data.ilvl)  or 0,
                    GetCoinTextureString((data and data.gold) or 0),
                    FormatTimePlayed((data and data.timePlayed) or nil),
                    guildStr))

                -- Statut connexion
                if isOnline then
                    btn.trackingIcon:SetNormalAtlas("DungeonStoneCheckpoint")
                    btn.trackingIcon:SetAlpha(1)
                    btn.statusText:SetText("|cff33ff55" .. ns.L("ONLINE") .. "|r")
                else
                    btn.trackingIcon:SetNormalAtlas("DungeonStoneCheckpointDeactivated")
                    btn.trackingIcon:SetAlpha(0.3)
                    local lastLogin = data and data.lastLogin
                    btn.statusText:SetText("|cffcc88ff" .. FormatTimeSince(lastLogin) .. "|r")
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

                if profs[1] then
                    btn.prof1Tex:SetTexture(profs[1].icon)
                    btn.prof1Frame:Show()
                    btn.prof1Frame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(profs[1].name, 1, 0.85, 0)
                        if profs[1].tiers and profs[1].tiers[1] then
                            local t = profs[1].tiers[1]
                            GameTooltip:AddLine(string.format("%s : %d / %d", t.name, t.level, t.max), 0.7, 0.7, 0.7)
                        end
                        GameTooltip:Show()
                    end)
                    btn.prof1Frame:SetScript("OnLeave", GameTooltip_Hide)
                    btn.prof1Frame:EnableMouse(true)
                else
                    btn.prof1Frame:Hide()
                    btn.prof1Frame:SetScript("OnEnter", nil)
                    btn.prof1Frame:SetScript("OnLeave", nil)
                end

                if profs[2] then
                    btn.prof2Tex:SetTexture(profs[2].icon)
                    btn.prof2Frame:Show()
                    btn.prof2Frame:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(profs[2].name, 1, 0.85, 0)
                        if profs[2].tiers and profs[2].tiers[1] then
                            local t = profs[2].tiers[1]
                            GameTooltip:AddLine(string.format("%s : %d / %d", t.name, t.level, t.max), 0.7, 0.7, 0.7)
                        end
                        GameTooltip:Show()
                    end)
                    btn.prof2Frame:SetScript("OnLeave", GameTooltip_Hide)
                    btn.prof2Frame:EnableMouse(true)
                else
                    btn.prof2Frame:Hide()
                    btn.prof2Frame:SetScript("OnEnter", nil)
                    btn.prof2Frame:SetScript("OnLeave", nil)
                end

                -- Click & hover
                local capturedData, capturedChar, capturedRealm = data, charName, realmName
                btn:SetScript("OnClick",  function() ns.ShowBags(capturedData, capturedChar, capturedRealm) end)
                btn:SetScript("OnEnter",  function(s) s:SetBackdropColor(0.18, 0.18, 0.22, 0.96) end)
                btn:SetScript("OnLeave",  function(s) s:SetBackdropColor(0.10, 0.10, 0.10, 0.96) end)

                offsetY = offsetY - 63
            end
            offsetY = offsetY - 20
        end
      until true
    end

    -- Message si la recherche ne retourne rien.
    if query ~= "" and offsetY == startOffsetY then
        local none = ns.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        none:SetPoint("TOPLEFT", 15, offsetY)
        none:SetText("|cffff9900" .. ns.L("CHAR_SEARCH_NONE") .. "|r")
        offsetY = offsetY - 30
    end

    ns.scrollChild:SetHeight(math.abs(offsetY) + 50)
    ns.UpdateBottomBar()
end
