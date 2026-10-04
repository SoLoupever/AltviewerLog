local addonName, ns = ...

-- ====================================================
-- THEME — Thèmes visuels (AltViewerLog / Blizzard)
-- Rôle UNIQUE : palettes + registre de skin + ApplyTheme.
--
-- Shell statique (fenêtre, sidebar, barre du bas…) : frames
-- enregistrées via ns.Skin.*, repeintes par ApplyTheme.
-- Vues dynamiques : lisent ns.Theme à la construction.
-- ====================================================

local WHITE = "Interface\\Buttons\\WHITE8x8"
local floor = math.floor
local unpack = unpack

local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

-- { bg, edge, hoverBg, hoverEdge }
local THEMES = {
    avl = {
        key      = "avl",
        title    = "4da6ff",
        sub      = "ff40a0",
        accent   = { 0.55, 0.45, 0.18 },
        thumb    = { 0.65, 0.52, 0.18 },
        text     = { 0.92, 0.92, 0.92 },
        textDim  = { 0.60, 0.60, 0.62 },
        heading  = { 0.95, 0.76, 0.25 },
        gold     = { 1.00, 0.82, 0.00 },
        sideText = nil, -- couleur de classe
        roles = {
            window = { { 0.03, 0.03, 0.04, 1 }, { 0.30, 0.24, 0.10, 1 } },
            panel  = { { 0.04, 0.04, 0.05, 1 }, { 0.22, 0.19, 0.10, 1 } },
            bar    = { { 0.035, 0.035, 0.045, 1 }, { 0.22, 0.19, 0.10, 1 },
                       { 0.08, 0.08, 0.10, 1 }, { 0.60, 0.50, 0.20, 1 } },
            card   = { { 0.05, 0.05, 0.065, 1 }, { 0.16, 0.15, 0.12, 1 },
                       { 0.09, 0.09, 0.12, 1 }, { 0.35, 0.30, 0.15, 1 } },
            input  = { { 0.02, 0.02, 0.03, 1 }, { 0.30, 0.26, 0.12, 1 },
                       { 0.04, 0.04, 0.05, 1 }, { 1.00, 0.82, 0.00, 1 } },
            button = { { 0.02, 0.02, 0.03, 1 }, { 0.30, 0.26, 0.12, 1 },
                       { 0.07, 0.07, 0.09, 1 }, { 0.60, 0.50, 0.20, 1 } },
            active = { { 0.10, 0.08, 0.04, 1 }, { 1.00, 0.82, 0.00, 1 } },
        },
    },
    blizzard = {
        key      = "blizzard",
        title    = "4da6ff",
        sub      = "ff40a0",
        accent   = { 0.55, 0.44, 0.22 },
        thumb    = { 0.60, 0.48, 0.22 },
        text     = { 0.93, 0.88, 0.75 },
        textDim  = { 0.62, 0.57, 0.47 },
        heading  = { 0.98, 0.78, 0.30 },
        gold     = { 1.00, 0.82, 0.00 },
        sideText = { 0.89, 0.82, 0.65 },
        roles = {
            window = { { 0.075, 0.06, 0.045, 1 }, { 0.42, 0.33, 0.17, 1 } },
            panel  = { { 0.055, 0.045, 0.035, 1 }, { 0.30, 0.24, 0.13, 1 } },
            bar    = { { 0.08, 0.065, 0.05, 1 }, { 0.33, 0.27, 0.15, 1 },
                       { 0.12, 0.10, 0.07, 1 }, { 0.65, 0.52, 0.25, 1 } },
            card   = { { 0.09, 0.075, 0.06, 1 }, { 0.24, 0.19, 0.10, 1 },
                       { 0.13, 0.11, 0.08, 1 }, { 0.45, 0.36, 0.18, 1 } },
            input  = { { 0.04, 0.035, 0.03, 1 }, { 0.30, 0.24, 0.13, 1 },
                       { 0.06, 0.05, 0.04, 1 }, { 1.00, 0.82, 0.00, 1 } },
            button = { { 0.06, 0.05, 0.04, 1 }, { 0.30, 0.24, 0.13, 1 },
                       { 0.12, 0.10, 0.07, 1 }, { 0.65, 0.52, 0.25, 1 } },
            active = { { 0.14, 0.11, 0.05, 1 }, { 1.00, 0.82, 0.00, 1 } },
        },
    },
}

ns.THEMES      = THEMES
ns.THEME_ORDER = { "avl", "blizzard" }
ns.Theme       = THEMES.avl

local function Hex(c)
    return string.format("%02x%02x%02x",
        floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255))
end
ns.ColorHex = Hex

-- Ancien thème (default / xalath / sylvanas) → avl
local function Normalize(key)
    return THEMES[key] and key or "avl"
end

-- ── Couleur de classe du joueur ───────────────────────────────────
local function ClassColor()
    local _, classFile = UnitClass("player")
    local col = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if col then return { col.r, col.g, col.b } end
    return { 0.80, 0.53, 1.00 }
end

-- ── Listeners (modules qui doivent réagir à un changement) ────────
local listeners = {}
function ns.RegisterThemeListener(fn)
    if type(fn) == "function" then listeners[#listeners + 1] = fn end
end

-- ── Registre de skin ──────────────────────────────────────────────
local registry = setmetatable({}, { __mode = "k" })
local sideBtns = {}
local Skin = {}
ns.Skin = Skin

local function Paint(f)
    local t    = ns.Theme
    local role = f._avlRole
    local r    = t.roles[role]
    if not r then return end
    local bg, edge = r[1], r[2]
    if role == "button" and f._active then
        bg, edge = t.roles.active[1], t.roles.active[2]
    elseif f._hover and r[3] then
        bg, edge = r[3], r[4]
    end
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(edge))
end
Skin.Paint = Paint

function Skin.Frame(f, role)
    f:SetBackdrop(BACKDROP)
    f._avlRole = role
    registry[f] = true
    Paint(f)
    return f
end

function Skin.Button(f, role)
    Skin.Frame(f, role or "button")
    f:HookScript("OnEnter", function(self) self._hover = true;  Paint(self) end)
    f:HookScript("OnLeave", function(self) self._hover = false; Paint(self) end)
    return f
end

-- Libellé de bouton de sidebar : FontString propre au skin (la couleur
-- ne repasse pas par les états du Button). Les codes |cff…|r passés
-- par les plugins sont retirés, la couleur est gérée ici.
local function PaintSideText(btn)
    local fs = btn._avlLabel
    if not fs then return end
    local t = ns.Theme
    local c = btn._active and t.gold or t.sideText or ClassColor()
    fs:SetTextColor(c[1], c[2], c[3])
end

function Skin.SideButton(btn)
    if btn._avlSide then return btn end
    btn._avlSide = true
    Skin.Button(btn)

    -- Texte éventuellement déjà posé par la factory d'un plugin : repris
    -- dans notre FontString, le natif est masqué.
    local initial = btn:GetText()
    local nfs = btn:GetFontString()
    if nfs then nfs:SetText(""); nfs:Hide() end

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    btn._avlLabel = fs

    btn.SetText = function(self, txt)
        txt = (txt or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        self._text = txt
        fs:SetText(txt)
        PaintSideText(self)
    end
    btn.GetText = function(self) return self._text or "" end
    if initial and initial ~= "" then btn:SetText(initial) end

    sideBtns[#sideBtns + 1] = btn
    return btn
end

-- Filet horizontal 1px (couleur de titre du thème), à ancrer par l'appelant
function Skin.Rule(parent)
    local tx = parent:CreateTexture(nil, "ARTWORK")
    local h = ns.Theme.heading
    tx:SetHeight(1)
    tx:SetColorTexture(h[1], h[2], h[3], 0.35)
    return tx
end

-- Bouton fermer carré (« X ») commun à toutes les fenêtres
function Skin.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(26, 26)
    Skin.Button(b)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER", 0, 1)
    fs:SetText("X")
    local function Tint(c) fs:SetTextColor(c[1], c[2], c[3]) end
    Tint(ns.Theme.text)
    b:SetScript("OnClick", onClick)
    b:HookScript("OnEnter", function() Tint(ns.Theme.gold) end)
    b:HookScript("OnLeave", function() Tint(ns.Theme.text) end)
    ns.RegisterThemeListener(function(t) Tint(t.text) end)
    return b
end

-- Bouton actif de la sidebar (un seul à la fois)
function Skin.SetActive(btn)
    for _, b in ipairs(sideBtns) do
        if b._active or b == btn then
            b._active = (b == btn)
            Paint(b)
            PaintSideText(b)
        end
    end
end

-- ── ApplyTheme ────────────────────────────────────────────────────
function ns.ApplyTheme(theme)
    local key = Normalize(theme)
    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
    AltViewerLogDB.settings.theme = key

    local t = THEMES[key]
    ns.Theme = t

    -- Exports conservés pour les plugins (accent de bordure / titre)
    ns._themeBorder   = t.accent
    ns._themeHex      = Hex(t.accent)
    ns._themeTitleHex = t.title

    if ns.titleText then
        ns.titleText:SetText("|cff" .. t.title .. ns.L("UI_TITLE") .. "|r  |cff"
            .. t.sub .. ns.L("UI_AUTHOR") .. "|r")
    end

    for f in pairs(registry) do Paint(f) end
    for _, b in ipairs(sideBtns) do PaintSideText(b) end

    for _, thumbTex in ipairs(ns.scrollBarThumbs or {}) do
        thumbTex:SetColorTexture(t.thumb[1], t.thumb[2], t.thumb[3], 0.55)
    end

    if ns.UpdateBottomBar then ns.UpdateBottomBar() end
    for _, fn in ipairs(listeners) do fn(t) end
end

-- Thème courant (clé normalisée)
function ns.GetThemeKey()
    local s = AltViewerLogDB and AltViewerLogDB.settings
    return Normalize(s and s.theme)
end
