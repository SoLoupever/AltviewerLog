local addonName, ns = ...

-- ====================================================
-- UI/SETTINGS — Panneau de paramètres AltViewerLog
-- Rôle UNIQUE : options PROPRES à AltViewerLog.
-- Les options des dépendances sont injectées via
-- ns.RegisterSettingsSection(fn) depuis leur Init.lua.
-- Si une dépendance est désactivée → section absente.
-- ====================================================

ns._settingsSections = ns._settingsSections or {}

function ns.RegisterSettingsSection(fn)
    ns._settingsSections[#ns._settingsSections + 1] = fn
end

-- ── Helpers visuels ───────────────────────────────────────────────
local function MakeSeparator(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetSize(600, 1)
    line:SetPoint("TOPLEFT", 20, y)
    line:SetColorTexture(1, 1, 1, 0.2)
    return y - 18
end

local function StyliserBouton(btn, texte)
    btn:SetSize(90, 25)
    if not btn.bg then
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints(btn)
    end
    btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    if not btn.label then
        btn.label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        btn.label:SetPoint("CENTER")
    end
    btn.label:SetText(texte)
    btn.label:SetTextColor(1, 1, 1)
    btn:SetScript("OnEnter",     function(s) s.bg:SetColorTexture(0.4, 0.4, 0.4, 0.9) end)
    btn:SetScript("OnLeave",     function(s) s.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8) end)
    btn:SetScript("OnMouseDown", function(s) s.bg:SetColorTexture(0.1, 0.1, 0.1, 1)   end)
    btn:SetScript("OnMouseUp",   function(s) s.bg:SetColorTexture(0.4, 0.4, 0.4, 0.9) end)
end

-- ── Helper : largeur exacte d'un texte rendu ─────────────────────
-- Crée une FontString temporaire invisible, mesure, puis la détruit.
local _measureFS
local function TextWidth(text, fontObj)
    if not _measureFS then
        _measureFS = UIParent:CreateFontString(nil, "ARTWORK", fontObj or "GameFontHighlight")
    else
        _measureFS:SetFontObject(fontObj or "GameFontHighlight")
    end
    _measureFS:SetText(text)
    return math.ceil(_measureFS:GetStringWidth())
end

local function MakeCheckbox(parent, y, labelText, getState, setState)
    -- Largeur = checkbox (26) + gap (5) + texte + padding droit (16)
    local rowW = 26 + 5 + TextWidth(labelText, "GameFontHighlight") + 16

    -- Fond gris par ligne
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(rowW, 28)
    row:SetPoint("TOPLEFT", 20, y)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(0.10, 0.10, 0.10, 0.88)

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", row, "LEFT", 6, 0)
    cb:SetSize(20, 20)
    cb:SetChecked(getState())
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    fs:SetText(labelText)
    cb.Text = fs
    cb:SetScript("OnClick", function(self) setState(self:GetChecked()) end)

    return y - 32   -- 28 hauteur + 4 gap entre les lignes
end

-- ── ShowSettings ──────────────────────────────────────────────────
function ns.ShowSettings()
    ns.currentView       = ns.ShowSettings
    ns.currentViewIsBank = false
    if not ns.scrollChild then return end
    ns.ClearContent()

    local sc = ns.scrollChild
    local y  = -20

    -- ── Titre ─────────────────────────────────────────────────────
    local title = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, y)
    title:SetText(ns.L("SETTINGS_TITLE"))
    y = y - 38

    -- ── Section AltViewerLog ──────────────────────────────────────
    local secLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    secLabel:SetPoint("TOPLEFT", 20, y)
    secLabel:SetText("|cff00ccff[AltViewerLog]|r")
    y = y - 26

    -- Tri par popularité des serveurs
    y = MakeCheckbox(sc, y,
        ns.L("SORT_POP"),
        function()
            return AltViewerLogDB.settings and AltViewerLogDB.settings.sortByPop or false
        end,
        function(v)
            AltViewerLogDB.settings = AltViewerLogDB.settings or {}
            AltViewerLogDB.settings.sortByPop = v
        end)

    -- Mode catégorie
    y = MakeCheckbox(sc, y,
        ns.L("CAT_MODE"),
        function()
            return AltViewerLogDB.settings and AltViewerLogDB.settings.useCategoryMode or false
        end,
        function(v)
            AltViewerLogDB.settings = AltViewerLogDB.settings or {}
            AltViewerLogDB.settings.useCategoryMode = v
        end)

    -- Banque intégrée (au lieu d'une fenêtre séparée)
    y = MakeCheckbox(sc, y,
        ns.L("BANK_INLINE_MODE"),
        function()
            return AltViewerLogDB.settings and AltViewerLogDB.settings.bankInline or false
        end,
        function(v)
            AltViewerLogDB.settings = AltViewerLogDB.settings or {}
            AltViewerLogDB.settings.bankInline = v
        end)

    -- Mode debug
    y = MakeCheckbox(sc, y,
        ns.L("DEBUG_MODE"),
        function()
            return AltViewerLogDB.settings and AltViewerLogDB.settings.debugMode == true
        end,
        function(v)
            AltViewerLogDB.settings = AltViewerLogDB.settings or {}
            AltViewerLogDB.settings.debugMode = v
        end)

    y = y - 8

    -- ── Langue ────────────────────────────────────────────────────
    y = MakeSeparator(sc, y)
    -- Largeur : label + gap + bouton FR + gap + bouton EN + padding
    local langLabelW = TextWidth(ns.L("LANG_TITLE"), "GameFontHighlight")
    local langRowW   = 10 + langLabelW + 15 + 90 + 10 + 90 + 10

    local langRow = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    langRow:SetSize(langRowW, 32)
    langRow:SetPoint("TOPLEFT", 20, y)
    langRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    langRow:SetBackdropColor(0.10, 0.10, 0.10, 0.88)

    local langLabel = langRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    langLabel:SetPoint("LEFT", 10, 0)
    langLabel:SetText(ns.L("LANG_TITLE"))

    if not StaticPopupDialogs["ALTVIEWER_RELOAD_UI"] then
        StaticPopupDialogs["ALTVIEWER_RELOAD_UI"] = {
            text      = ns.L("RELOAD_REQUIRED"),
            button1   = "OK", button2 = "No",
            OnAccept  = ReloadUI,
            timeout   = 0, whileDead = true, hideOnEscape = true,
        }
    end

    local btnFR = CreateFrame("Button", nil, langRow)
    btnFR:SetPoint("LEFT", langLabel, "RIGHT", 15, 0)
    StyliserBouton(btnFR, "Français")
    btnFR:SetScript("OnClick", function()
        AltViewerLogDB.settings.lang = "frFR"
        StaticPopup_Show("ALTVIEWER_RELOAD_UI")
    end)

    local btnEN = CreateFrame("Button", nil, langRow)
    btnEN:SetPoint("LEFT", btnFR, "RIGHT", 10, 0)
    StyliserBouton(btnEN, "English")
    btnEN:SetScript("OnClick", function()
        AltViewerLogDB.settings.lang = "enUS"
        StaticPopup_Show("ALTVIEWER_RELOAD_UI")
    end)
    y = y - 36

    -- ── Thème ─────────────────────────────────────────────────────
    y = MakeSeparator(sc, y)
    -- Largeur : label + gap + 3 boutons (90px chacun) + 2 gaps (10px) + padding
    local themeLabelW = TextWidth(ns.L("THEME_TITLE"), "GameFontHighlight")
    local themeRowW   = 10 + themeLabelW + 15 + 90 + 10 + 90 + 10 + 90 + 10

    local themeRow = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    themeRow:SetSize(themeRowW, 32)
    themeRow:SetPoint("TOPLEFT", 20, y)
    themeRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    themeRow:SetBackdropColor(0.10, 0.10, 0.10, 0.88)

    local themeLabel = themeRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    themeLabel:SetPoint("LEFT", 10, 0)
    themeLabel:SetText(ns.L("THEME_TITLE"))

    local function MakeThemeBtn(label, theme, anchorLeft, offsetX)
        local btn = CreateFrame("Button", nil, themeRow)
        btn:SetPoint("LEFT", anchorLeft, "RIGHT", offsetX, 0)
        StyliserBouton(btn, label)
        local function Refresh()
            local active = (AltViewerLogDB.settings and AltViewerLogDB.settings.theme or "default") == theme
            if active then
                btn.bg:SetColorTexture(0.35, 0.15, 0.60, 1)
                btn.label:SetTextColor(1, 0.85, 1)
            else
                btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
                btn.label:SetTextColor(1, 1, 1)
            end
        end
        Refresh()
        btn:SetScript("OnClick", function() ns.ApplyTheme(theme); ns.ShowSettings() end)
        return btn
    end

    local btnN = MakeThemeBtn("Normal",   "default",  themeLabel, 15)
    local btnX = MakeThemeBtn("Xalath",   "xalath",   btnN,       10)
                 MakeThemeBtn("Sylvanas", "sylvanas", btnX,       10)
    y = y - 36

    -- ═══ SECTIONS DÉPENDANCES — injectées dynamiquement ═══════════
    -- Chaque dépendance active enregistre sa section via Init.lua.
    -- Si elle est désactivée : section absente, menu s'adapte seul.
    for _, sectionFn in ipairs(ns._settingsSections) do
        y = MakeSeparator(sc, y)
        y = sectionFn(sc, y) or y
    end

    sc:SetHeight(math.abs(y) + 60)
end
