local addonName, ns = ...

-- ====================================================
-- CATEGORY DnD — drag & drop d'items entre catégories
-- Rôle UNIQUE : drag d'une icône d'item + slot "+" en fin de
-- catégorie. Ne connaît ni les vues ni la fenêtre de gestion :
-- les vues appellent AttachItem / AddPlus (gardés par `if ns.CatDnD`),
-- le résultat passe par ns.Cat.Assign puis le refresh fourni.
--
-- API :
--   ns.CatDnD.AttachItem(btn, itemID, store, refresh)
--   ns.CatDnD.Detach(btn)
--   ns.CatDnD.AddPlus(parent, x, y, key, store, refresh)
--   ns.CatDnD.ReleaseFor(parent)
-- Le "+" accepte aussi un item de l'inventaire réel (curseur).
-- ====================================================

local DnD = {}
ns.CatDnD = DnD

local SZ    = 32
local WHITE = "Interface\\Buttons\\WHITE8x8"

local session            -- { id, store }
local pool, active = {}, {}

-- ── Fantôme suivant le curseur ───────────────────────────────────
local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(SZ, SZ)
ghost:SetFrameStrata("TOOLTIP")
ghost:EnableMouse(false)
ghost.ico = ghost:CreateTexture(nil, "ARTWORK")
ghost.ico:SetAllPoints()
ghost:SetAlpha(0.85)
ghost:Hide()

-- ── Visuel d'un slot "+" : nil | "armed" | "hover" ───────────────
local function SetState(s, state)
    if s._state == state then return end
    s._state = state
    if state == "hover" then
        s:SetBackdropColor(0.10, 0.40, 0.10, 0.90)
        s:SetBackdropBorderColor(0.30, 1, 0.30, 1)
        s.fs:SetAlpha(1)
    elseif state == "armed" then
        s:SetBackdropColor(0.20, 0.17, 0.05, 0.85)
        s:SetBackdropBorderColor(1, 0.82, 0.10, 1)
        s.fs:SetAlpha(1)
    else
        s:SetBackdropColor(0.08, 0.08, 0.10, 0.55)
        s:SetBackdropBorderColor(0.35, 0.30, 0.12, 0.70)
        s.fs:SetAlpha(0.55)
    end
end

local function Commit(store, itemID, key, refresh)
    if ns.Cat.Assign(store, itemID, key) and refresh then
        C_Timer.After(0, refresh)   -- hors du handler : les frames sont recyclées au refresh
    end
end

-- Drop d'un item pris dans l'inventaire réel du jeu.
local function ReceiveCursor(self)
    if session or not self.store then return end
    local kind, id = GetCursorInfo()
    if kind == "item" and id then
        ClearCursor()
        Commit(self.store, id, self.key, self.refresh)
    end
end

local function NewPlus(parent)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(SZ, SZ)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f.fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.fs:SetPoint("CENTER", 0, 1)
    f.fs:SetText("+")
    f:RegisterForClicks("LeftButtonUp")
    f:SetScript("OnReceiveDrag", ReceiveCursor)
    f:SetScript("OnClick", ReceiveCursor)
    f:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.L("CATDND_PLUS_TT"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)
    return f
end

function DnD.AddPlus(parent, x, y, key, store, refresh)
    local f = table.remove(pool) or NewPlus(parent)
    f:SetParent(parent)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", x, y)
    f.key, f.store, f.refresh = key, store, refresh
    f._state = "?"                      -- force l'application du visuel
    SetState(f, session and session.store == store and "armed" or nil)
    f:Show()
    active[#active + 1] = f
    return f
end

function DnD.ReleaseFor(parent)
    for i = #active, 1, -1 do
        local f = active[i]
        if f:GetParent() == parent then
            f:Hide()
            f.store, f.refresh, f.key = nil, nil, nil
            table.remove(active, i)
            pool[#pool + 1] = f
        end
    end
end

-- ── Session de drag ──────────────────────────────────────────────
local driver = CreateFrame("Frame")

local function Tick()
    local s = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / s, cy / s)
    if not IsMouseButtonDown("LeftButton") then
        DnD._End(); return
    end
    for _, f in ipairs(active) do
        if f.store == session.store then
            SetState(f, f:IsShown() and f:IsMouseOver() and "hover" or "armed")
        end
    end
end

function DnD._End()
    local sess = session
    if not sess then return end
    session = nil
    driver:SetScript("OnUpdate", nil)
    ghost:Hide()
    local target
    for _, f in ipairs(active) do
        if not target and f.store == sess.store and f:IsShown() and f:IsMouseOver() then
            target = f
        end
        SetState(f, nil)
    end
    if target then Commit(sess.store, sess.id, target.key, target.refresh) end
end

local function Begin(itemID, store)
    GameTooltip:Hide()
    session = { id = itemID, store = store }
    ghost.ico:SetTexture(ns.GetIcon(itemID))
    ghost:Show()
    for _, f in ipairs(active) do
        if f.store == store then SetState(f, "armed") end
    end
    driver:SetScript("OnUpdate", Tick)
end

-- ── Branchement sur une icône d'item ─────────────────────────────
function DnD.AttachItem(btn, itemID, store, refresh)
    btn._avlDnD = true
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function() Begin(itemID, store) end)
    btn:SetScript("OnDragStop",  DnD._End)
end

-- Appelé par les pools avant recyclage d'une icône.
function DnD.Detach(btn)
    if not btn._avlDnD then return end
    btn._avlDnD = nil
    btn:RegisterForDrag()
    btn:SetScript("OnDragStart", nil)
    btn:SetScript("OnDragStop",  nil)
end
