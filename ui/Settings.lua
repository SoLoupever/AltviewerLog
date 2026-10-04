local addonName, ns = ...

-- ====================================================
-- UI/SETTINGS — Panneau de paramètres AltViewerLog
-- Rôle UNIQUE : options PROPRES à AltViewerLog.
-- Les options des dépendances sont injectées via
-- ns.RegisterSettingsSection(fn) depuis leur Init.lua :
-- fn(parent, y) dessine dans une carte dédiée (y relatif
-- au coin haut-gauche de la carte) et retourne le nouveau y.
-- ====================================================

ns._settingsSections = ns._settingsSections or {}

function ns.RegisterSettingsSection(fn)
    ns._settingsSections[#ns._settingsSections + 1] = fn
end

local MARGIN = 12   -- marge des cartes dans le scrollChild
local PAD    = 14   -- marge interne des cartes

local function Settings()
    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
    return AltViewerLogDB.settings
end

-- ── Widgets ───────────────────────────────────────────────────────
local function MakeCard(parent, y)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT",  parent, "TOPLEFT",  MARGIN, y)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN, y)
    ns.Skin.Frame(card, "card")
    return card
end

local function MakeCheckbox(parent, y, labelText, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("TOPLEFT", PAD, y)
    ns.Skin.Button(cb, "input")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetChecked(get())

    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 10, 0)
    fs:SetText(labelText)
    fs:SetTextColor(unpack(ns.Theme.text))

    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    return y - 28
end

-- Bouton de choix (langue / thème) : doré quand actif
local function MakeChoice(parent, label, active, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(110, 26)
    ns.Skin.Button(btn)
    btn._active = active
    ns.Skin.Paint(btn)
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    local c = active and ns.Theme.gold or ns.Theme.text
    fs:SetTextColor(c[1], c[2], c[3])
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Ligne « libellé : [choix] [choix] »
local function MakeChoiceRow(parent, y, labelText, choices)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", PAD, y - 5)
    lbl:SetText(labelText)
    lbl:SetTextColor(unpack(ns.Theme.textDim))

    local prev
    for _, c in ipairs(choices) do
        local b = MakeChoice(parent, c.label, c.active, c.onClick)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        else
            b:SetPoint("TOPLEFT", PAD + 170, y)
        end
        prev = b
    end
    return y - 34
end

local function StaticReload()
    if not StaticPopupDialogs["ALTVIEWER_RELOAD_UI"] then
        StaticPopupDialogs["ALTVIEWER_RELOAD_UI"] = {
            text      = ns.L("RELOAD_REQUIRED"),
            button1   = OKAY, button2 = NO,
            OnAccept  = ReloadUI,
            timeout   = 0, whileDead = true, hideOnEscape = true,
        }
    end
    StaticPopup_Show("ALTVIEWER_RELOAD_UI")
end

-- ── ShowSettings ──────────────────────────────────────────────────
function ns.ShowSettings()
    ns.currentView       = ns.ShowSettings
    ns.currentViewIsBank = false
    if not ns.scrollChild then return end
    ns.ClearContent()

    local sc = ns.scrollChild
    local t  = ns.Theme
    local y  = -10

    -- Titre + filet
    local title = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", MARGIN + 4, y)
    title:SetText(ns.L("SETTINGS_TITLE"))
    title:SetTextColor(unpack(t.heading))
    y = y - 34
    local rule = ns.Skin.Rule(sc)
    rule:SetPoint("TOPLEFT",  sc, "TOPLEFT",  MARGIN, y)
    rule:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -MARGIN, y)
    y = y - 14

    -- ── Carte AltViewerLog ────────────────────────────────────────
    local card = MakeCard(sc, y)
    local cy = -PAD

    local sec = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sec:SetPoint("TOPLEFT", PAD, cy)
    sec:SetText("|cff" .. t.title .. ns.L("UI_TITLE") .. "|r")
    cy = cy - 30

    cy = MakeCheckbox(card, cy, ns.L("SORT_POP"),
        function() return Settings().sortByPop or false end,
        function(v) Settings().sortByPop = v end)
    cy = MakeCheckbox(card, cy, ns.L("CAT_MODE"),
        function() return Settings().useCategoryMode or false end,
        function(v) Settings().useCategoryMode = v end)
    cy = MakeCheckbox(card, cy, ns.L("BANK_INLINE_MODE"),
        function() return Settings().bankInline or false end,
        function(v) Settings().bankInline = v end)
    cy = MakeCheckbox(card, cy, ns.L("DEBUG_MODE"),
        function() return Settings().debugMode == true end,
        function(v) Settings().debugMode = v end)

    cy = cy - 6
    local sep = ns.Skin.Rule(card)
    sep:SetPoint("TOPLEFT",  card, "TOPLEFT",  PAD, cy)
    sep:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, cy)
    cy = cy - 14

    local lang = Settings().lang
    cy = MakeChoiceRow(card, cy, ns.L("LANG_TITLE"), {
        { label = ns.L("LANG_NAME_FR"), active = (lang == "frFR"),
          onClick = function() Settings().lang = "frFR"; StaticReload() end },
        { label = ns.L("LANG_NAME_EN"), active = (lang == "enUS"),
          onClick = function() Settings().lang = "enUS"; StaticReload() end },
    })

    local choices = {}
    for _, key in ipairs(ns.THEME_ORDER) do
        choices[#choices + 1] = {
            label   = ns.L("THEME_NAME_" .. key:upper()),
            active  = (ns.GetThemeKey() == key),
            onClick = function() ns.ApplyTheme(key); ns.ShowSettings() end,
        }
    end
    cy = MakeChoiceRow(card, cy, ns.L("THEME_TITLE"), choices)

    card:SetHeight(-cy + PAD - 6)
    y = y - card:GetHeight() - 12

    -- ═══ SECTIONS DÉPENDANCES — injectées dynamiquement ═══════════
    -- Section absente si la dépendance est désactivée.
    for _, sectionFn in ipairs(ns._settingsSections) do
        local c  = MakeCard(sc, y)
        local sy = sectionFn(c, -PAD) or -PAD
        if sy == -PAD then
            c:Hide()                       -- section vide : pas de carte
        else
            c:SetHeight(-sy + PAD)
            y = y - c:GetHeight() - 12
        end
    end

    sc:SetHeight(math.abs(y) + 20)
end
