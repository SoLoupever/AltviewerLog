local addonName, ns = ...

-- ====================================================
-- CHAR SELECTOR : panneau latéral de choix de personnage
--
-- Point d'entrée : ns.OpenCharSelector(anchor, onSelect)
--   onSelect(charName, realmName)
-- Données : DataProvider uniquement. Aucun état sauvegardé.
-- ====================================================

local PANEL_W  = 300
local GAP      = 4
local PAD      = 8
local BAR_H    = 26
local REALM_W  = 110
local ROW_H    = 22
local HEAD_H   = 20
local ICON     = 16
local TOP_OFF  = PAD + BAR_H + PAD

local ROW_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }

local FACTION_ICON = {
    Horde    = "Interface\\Icons\\PVPCurrency-Honor-Horde",
    Alliance = "Interface\\Icons\\PVPCurrency-Honor-Alliance",
}

local panel = CreateFrame("Frame", "AVL_CharSelPanel", UIParent, "BackdropTemplate")
panel:SetWidth(PANEL_W)
panel:SetFrameStrata("DIALOG")
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
ns.Skin.Frame(panel, "window")
panel:Hide()
ns.charSelMenu = panel

local chars        = {}    -- { name, lname, realm, class, faction } trié realm/nom
local realms       = {}    -- noms de serveurs triés
local realmFilter  = nil   -- nil = tous les serveurs
local curOnSelect
local built        = false
local hooked       = {}

local box, realmBtn, realmLabel, scroll, child, emptyFS, realmMenu
local rows, realmRows = {}, {}

-- ── Données ───────────────────────────────────────────────────────
local function Collect()
    wipe(chars); wipe(realms)
    local seen = {}
    ns.DP_IterateChars(function(realm, name, data)
        chars[#chars + 1] = {
            name = name, lname = name:lower(), realm = realm,
            class = data.class, faction = data.faction,
        }
        if not seen[realm] then seen[realm] = true; realms[#realms + 1] = realm end
    end)
    table.sort(chars, function(a, b)
        if a.realm ~= b.realm then return a.realm < b.realm end
        return a.lname < b.lname
    end)
    table.sort(realms)
    if realmFilter and not seen[realmFilter] then realmFilter = nil end
end

local function ClassHex(class)
    local c = RAID_CLASS_COLORS[class]
    if not c then return "ffffff" end
    return string.format("%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

-- ── Lignes ────────────────────────────────────────────────────────
local function Select(name, realm)
    local cb = curOnSelect
    panel:Hide()
    if cb then cb(name, realm) end
end

local function RowRest(r)
    r:SetBackdropColor(0, 0, 0, 0)
    r:SetBackdropBorderColor(0, 0, 0, 0)
end

local function NewRow(parent)
    local r = CreateFrame("Button", nil, parent, "BackdropTemplate")
    r:SetHeight(ROW_H)
    r:SetBackdrop(ROW_BACKDROP)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
    r.fac = r:CreateTexture(nil, "ARTWORK")
    r.fac:SetSize(ICON, ICON)
    r.fac:SetPoint("LEFT", 6, 0)
    r.fs = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.fs:SetJustifyH("LEFT")
    r.fs:SetWordWrap(false)
    r:SetScript("OnEnter", function(s)
        if not s.pick then return end
        local card = ns.Theme.roles.card
        s:SetBackdropColor(unpack(card[3]))
        s:SetBackdropBorderColor(unpack(card[4]))
    end)
    r:SetScript("OnLeave", RowRest)
    r:SetScript("OnClick", function(s) if s.pick then s.pick(s) end end)
    return r
end

local function GetRow(pool, parent, i)
    local r = pool[i]
    if not r then r = NewRow(parent); pool[i] = r end
    RowRest(r)
    r:ClearAllPoints()
    return r
end

local function RowPlace(r, parent, y)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    r:Show()
end

-- ── Liste personnages ─────────────────────────────────────────────
local function PickChar(r) Select(r.charName, r.realmName) end

local function Rebuild()
    local q = (box:GetText() or ""):lower()
    local n, y, lastRealm = 0, 0, nil
    local bar = ns.Theme.roles.bar[1]

    for _, c in ipairs(chars) do
        if (not realmFilter or c.realm == realmFilter)
        and (q == "" or c.lname:find(q, 1, true)) then
            if not realmFilter and c.realm ~= lastRealm then
                lastRealm = c.realm
                n = n + 1
                local r = GetRow(rows, child, n)
                r:SetHeight(HEAD_H)
                r.pick = nil
                r.fac:Hide()
                r.bg:SetColorTexture(bar[1], bar[2], bar[3], 1)
                r.fs:ClearAllPoints()
                r.fs:SetPoint("LEFT", 8, 0); r.fs:SetPoint("RIGHT", -4, 0)
                local g = ns.Theme.gold
                r.fs:SetTextColor(g[1], g[2], g[3])
                r.fs:SetText(c.realm)
                RowPlace(r, child, y)
                y = y + HEAD_H
            end
            n = n + 1
            local r = GetRow(rows, child, n)
            r:SetHeight(ROW_H)
            r.bg:SetColorTexture(0, 0, 0, 0)
            local ico = FACTION_ICON[c.faction]
            if ico then r.fac:SetTexture(ico); r.fac:Show() else r.fac:Hide() end
            r.fs:ClearAllPoints()
            r.fs:SetPoint("LEFT", 8 + ICON + 6, 0); r.fs:SetPoint("RIGHT", -4, 0)
            r.fs:SetTextColor(1, 1, 1)
            r.fs:SetText("|cff" .. ClassHex(c.class) .. c.name .. "|r")
            r.charName, r.realmName, r.pick = c.name, c.realm, PickChar
            RowPlace(r, child, y)
            y = y + ROW_H
        end
    end

    for i = n + 1, #rows do rows[i]:Hide() end
    emptyFS:SetShown(n == 0)
    child:SetHeight(math.max(1, y))
    scroll:SetVerticalScroll(0)
end

-- ── Menu serveur ──────────────────────────────────────────────────
local function UpdateRealmLabel()
    realmLabel:SetText(realmFilter or ns.L("CHAR_SEL_ALL_REALMS"))
end

local function PickRealm(r)
    realmFilter = r.realmValue
    realmMenu:Hide()
    UpdateRealmLabel()
    Rebuild()
end

local function BuildRealmMenu()
    local list = { false }                    -- false = tous les serveurs
    for _, realm in ipairs(realms) do list[#list + 1] = realm end

    for i, realm in ipairs(list) do
        local r = GetRow(realmRows, realmMenu.child, i)
        r:SetHeight(ROW_H)
        r.fac:Hide()
        r.bg:SetColorTexture(0, 0, 0, 0)
        r.fs:ClearAllPoints()
        r.fs:SetPoint("LEFT", 8, 0); r.fs:SetPoint("RIGHT", -4, 0)
        local value = realm or nil
        local sel = (value == realmFilter)
        local c = sel and ns.Theme.gold or ns.Theme.text
        r.fs:SetTextColor(c[1], c[2], c[3])
        r.fs:SetText(realm or ns.L("CHAR_SEL_ALL_REALMS"))
        r.realmValue, r.pick = value, PickRealm
        RowPlace(r, realmMenu.child, (i - 1) * ROW_H)
    end
    for i = #list + 1, #realmRows do realmRows[i]:Hide() end

    local contentH = #list * ROW_H
    realmMenu.child:SetHeight(contentH)
    local maxH = math.max(ROW_H, (panel:GetHeight() or 300) - TOP_OFF - PAD)
    realmMenu:SetHeight(math.min(contentH, maxH) + 4)
    realmMenu.sf:SetVerticalScroll(0)
end

local function ToggleRealmMenu()
    if realmMenu:IsShown() then realmMenu:Hide(); return end
    BuildRealmMenu()
    realmMenu:Show()
end

-- ── Construction (1 seule fois) ───────────────────────────────────
local function MakeScroll(parent, childW)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local ch = CreateFrame("Frame", nil, sf)
    ch:SetSize(childW, 1)
    sf:SetScrollChild(ch)
    ns.SkinScrollBar(sf)
    return sf, ch
end

local function Build()
    built = true

    -- Recherche
    box = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
    box:SetAutoFocus(false)
    box:SetHeight(BAR_H)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(26, 20, 0, 0)
    ns.Skin.Frame(box, "input")
    box:SetPoint("TOPLEFT", PAD, -PAD)
    box:HookScript("OnEditFocusGained", function(s) s._hover = true;  ns.Skin.Paint(s) end)
    box:HookScript("OnEditFocusLost",   function(s) s._hover = false; ns.Skin.Paint(s) end)

    local ico = box:CreateTexture(nil, "OVERLAY")
    ico:SetSize(14, 14)
    ico:SetPoint("LEFT", 7, 0)
    ico:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    local ph = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 26, 0)
    ph:SetPoint("RIGHT", -20, 0)
    ph:SetJustifyH("LEFT")
    ph:SetWordWrap(false)
    box.ph = ph

    local clr = CreateFrame("Button", nil, box)
    clr:SetSize(14, 14)
    clr:SetPoint("RIGHT", -4, 0)
    local clrTex = clr:CreateTexture(nil, "OVERLAY")
    clrTex:SetAllPoints()
    clrTex:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
    clr:SetScript("OnClick", function() box:SetText(""); box:ClearFocus() end)
    clr:Hide()

    box:SetScript("OnEscapePressed", function(s) s:SetText(""); s:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    box:SetScript("OnTextChanged", function(s)
        local t = s:GetText() or ""
        ph:SetShown(t == "")
        clr:SetShown(t ~= "")
        Rebuild()
    end)

    -- Bouton serveur
    realmBtn = CreateFrame("Button", nil, panel, "BackdropTemplate")
    realmBtn:SetSize(REALM_W, BAR_H)
    realmBtn:SetPoint("TOPRIGHT", -PAD, -PAD)
    ns.Skin.Button(realmBtn)
    realmLabel = realmBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    realmLabel:SetPoint("LEFT", 6, 0); realmLabel:SetPoint("RIGHT", -6, 0)
    realmLabel:SetWordWrap(false)
    realmBtn:SetScript("OnClick", ToggleRealmMenu)
    box:SetPoint("RIGHT", realmBtn, "LEFT", -6, 0)

    -- Liste
    scroll, child = MakeScroll(panel, PANEL_W - PAD - 20)
    scroll:SetPoint("TOPLEFT", PAD, -TOP_OFF)
    scroll:SetPoint("BOTTOMRIGHT", -20, PAD)

    emptyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyFS:SetPoint("TOP", scroll, "TOP", 0, -20)
    emptyFS:Hide()

    -- Menu serveur (dans les limites du panneau)
    realmMenu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    realmMenu:SetFrameLevel(panel:GetFrameLevel() + 30)
    realmMenu:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -TOP_OFF + 2)
    realmMenu:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -TOP_OFF + 2)
    ns.Skin.Frame(realmMenu, "panel")
    realmMenu:EnableMouse(true)
    realmMenu:Hide()
    local sf, ch = MakeScroll(realmMenu, PANEL_W - 2 * PAD - 14)
    sf:SetPoint("TOPLEFT", 2, -2)
    sf:SetPoint("BOTTOMRIGHT", -12, 2)
    realmMenu.sf, realmMenu.child = sf, ch

    ns.RegisterThemeListener(function()
        if panel:IsShown() then Rebuild(); UpdateRealmLabel() end
    end)
end

-- ── Placement ─────────────────────────────────────────────────────
-- Fenêtres hôtes en plus de la fenêtre principale (ex. banque flottante).
-- Une fenêtre hôte doit exposer .titleText (barre de titre).
local hostFrames = {}
function ns.RegisterHostFrame(frame)
    if frame then hostFrames[frame] = true end
end

local function ResolveHost(anchor)
    local f = anchor
    while f do
        if f == ns.mainFrame or hostFrames[f] then return f end
        f = f:GetParent()
    end
    return ns.mainFrame
end

local function PlacePanel(host)
    panel:ClearAllPoints()
    local right = host:GetRight()
    local uiRight = UIParent:GetRight()
    local sc = host:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if right and uiRight and (right * sc + GAP + PANEL_W) > uiRight then
        panel:SetPoint("TOPRIGHT",    host, "TOPLEFT",    -GAP, 0)
        panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMLEFT", -GAP, 0)
    else
        panel:SetPoint("TOPLEFT",    host, "TOPRIGHT",    GAP, 0)
        panel:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", GAP, 0)
    end
end

-- ── Fermeture ─────────────────────────────────────────────────────
panel:SetScript("OnHide", function(s)
    s:SetScript("OnUpdate", nil)
    if built then realmMenu:Hide(); box:ClearFocus() end
end)

local function HostTitleBar(host)
    if host == ns.mainFrame then return ns.titleBar end
    return host and host.titleText and host.titleText:GetParent()
end

local function OnPoll(self, dt)
    self._t = (self._t or 0) + dt
    if self._t < 0.05 then return end
    self._t = 0
    if not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then return end
    if realmMenu:IsShown() and not realmMenu:IsMouseOver() and not realmBtn:IsMouseOver() then
        realmMenu:Hide()
    end
    if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then return end
    local tb = HostTitleBar(self.host)
    if tb and tb:IsMouseOver() then return end
    self:Hide()
end

-- ── API ───────────────────────────────────────────────────────────
function ns.OpenCharSelector(anchor, onSelect)
    if panel:IsShown() and panel.anchor == anchor then panel:Hide(); return end
    if not built then Build() end

    local host = ResolveHost(anchor)
    if not hooked[host] then
        hooked[host] = true
        host:HookScript("OnHide", function() panel:Hide() end)
    end

    curOnSelect, panel.anchor, panel.host = onSelect, anchor, host
    Collect()
    box.ph:SetText(ns.L("CHAR_SEL_SEARCH_PH"))
    emptyFS:SetText(ns.L("CHAR_SEL_NO_RESULT"))
    box:SetText("")
    UpdateRealmLabel()
    Rebuild()

    PlacePanel(host)
    panel:SetFrameLevel(host:GetFrameLevel() + 20)
    panel:Show()
    panel:SetScript("OnUpdate", OnPoll)
    box:SetFocus()
end
