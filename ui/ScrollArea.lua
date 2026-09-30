local addonName, ns = ...

-- ====================================================
-- UI/SCROLLAREA — Zone de défilement principale + fenêtre banque
-- Rôle UNIQUE : créer ns.scrollFrame / ns.scrollChild
-- et ns.bankWin / ns.bankScrollChild.
-- ====================================================

-- ── Scrollbar moderne ────────────────────────────────────────────
-- Remplace le rendu Blizzard par défaut (boutons haut/bas + slider
-- gris épais) par une piste fine + un pouce coloré selon le thème
-- actif. Un seul système de skin pour toute la ScrollFrame de
-- l'addon (scroll principal ET fenêtre banque) — pas de variante
-- par usage. Ne touche qu'au visuel : le scroll lui-même reste
-- géré nativement par la ScrollFrame (SetVerticalScroll /
-- GetVerticalScrollRange), rien n'est réimplémenté côté logique.
local BAR_W = 8

function ns.SkinScrollBar(scrollFrame)
    -- Masque la scrollbar Blizzard native fournie par le template
    -- (le frame ScrollFrame lui-même garde toute sa logique de scroll,
    -- seul son widget visuel enfant est caché).
    local nativeBar = scrollFrame.ScrollBar
        or (scrollFrame:GetName() and _G[scrollFrame:GetName() .. "ScrollBar"])
    if nativeBar then
        nativeBar:Hide()
        nativeBar:EnableMouse(false)
        nativeBar.Show = function() end
    end

    local track = CreateFrame("Frame", nil, scrollFrame)
    track:SetWidth(BAR_W)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", BAR_W - 2, -2)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", BAR_W - 2, 2)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints()
    trackTex:SetColorTexture(0, 0, 0, 0.25)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(BAR_W)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    if thumbTex.SetMask then
        pcall(thumbTex.SetMask, thumbTex, "Interface\\Masks\\CircleMaskScalable")
    end

    local function ThumbColor(alpha)
        local b = ns._themeBorder or { 0.45, 0.15, 0.70 }
        thumbTex:SetColorTexture(b[1], b[2], b[3], alpha)
    end
    ThumbColor(0.55)

    ns.scrollBarThumbs = ns.scrollBarThumbs or {}
    table.insert(ns.scrollBarThumbs, thumbTex)

    -- Recalcule taille/position du pouce à partir de l'état natif
    -- de la ScrollFrame (aucune donnée dupliquée, juste relue).
    local function Update()
        local range  = scrollFrame:GetVerticalScrollRange() or 0
        local trackH = track:GetHeight() or 1

        if range <= 0 then
            track:Hide()
            return
        end
        track:Show()

        local visH   = scrollFrame:GetHeight() or 1
        local thumbH = math.max(24, trackH * (visH / (visH + range)))
        thumb:SetHeight(thumbH)

        local scroll     = scrollFrame:GetVerticalScroll() or 0
        local maxOffset  = math.max(0, trackH - thumbH)
        local pos        = (range > 0) and (scroll / range) * maxOffset or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -pos)
    end

    -- Hooks natifs : pas de OnUpdate en boucle, seulement recalcul
    -- quand quelque chose a réellement changé (taille, contenu, scroll).
    scrollFrame:HookScript("OnScrollRangeChanged", Update)
    scrollFrame:HookScript("OnVerticalScroll", Update)
    scrollFrame:HookScript("OnSizeChanged", Update)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        if range <= 0 then return end
        local cur = self:GetVerticalScroll() or 0
        local step = 45
        self:SetVerticalScroll(math.min(range, math.max(0, cur - delta * step)))
    end)

    -- Survol : piste/pouce plus visibles (effet "overlay scrollbar")
    local function OnEnterArea()
        if thumb.dragging then return end
        ThumbColor(0.8)
        trackTex:SetColorTexture(0, 0, 0, 0.35)
    end
    local function OnLeaveArea()
        if thumb.dragging then return end
        ThumbColor(0.55)
        trackTex:SetColorTexture(0, 0, 0, 0.25)
    end
    scrollFrame:HookScript("OnEnter", OnEnterArea)
    scrollFrame:HookScript("OnLeave", OnLeaveArea)
    thumb:SetScript("OnEnter", OnEnterArea)
    thumb:SetScript("OnLeave", OnLeaveArea)

    -- Drag du pouce
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        ThumbColor(0.95)
    end)
    thumb:SetScript("OnDragStop", function(self)
        self.dragging = false
        OnLeaveArea()
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local range = scrollFrame:GetVerticalScrollRange() or 0
        if range <= 0 then return end
        local trackH = track:GetHeight() or 1
        local thumbH = self:GetHeight() or 1
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end

        local scale = track:GetEffectiveScale()
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / scale

        local offset = (track:GetTop() or 0) - cursorY - (thumbH / 2)
        offset = math.max(0, math.min(maxOffset, offset))
        scrollFrame:SetVerticalScroll((offset / maxOffset) * range)
    end)

    Update()
end

-- ── Scroll principal ─────────────────────────────────────────────
local scrollFrame = CreateFrame("ScrollFrame", "AVL_ScrollFrame",
    ns.mainFrame, "UIPanelScrollFrameTemplate")
ns.scrollFrame = scrollFrame
scrollFrame:SetPoint("TOPLEFT",     ns._UI.sideBar,  "TOPRIGHT",     10, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", ns.mainFrame, "BOTTOMRIGHT", -22, 36)

ns.scrollChild = CreateFrame("Frame", nil, scrollFrame)
ns.scrollChild:SetSize(650, 1)
scrollFrame:SetScrollChild(ns.scrollChild)
ns.SkinScrollBar(scrollFrame)

function ns.GetContentWidth()
    return math.max(300, ns.mainFrame:GetWidth() - 200 - 10 - 22)
end
ns.mainFrame:HookScript("OnSizeChanged", function()
    ns.scrollChild:SetWidth(ns.GetContentWidth())
    if ns.currentView and not ns.currentViewIsBank then
        ns.currentView()
    end
end)

-- ── Fenêtre banque flottante ──────────────────────────────────────
ns.bankWin = CreateFrame("Frame", "AVL_BankWin", UIParent, "BackdropTemplate")
ns.bankWin:SetSize(720, 540)
ns.bankWin:SetPoint("CENTER", UIParent, "CENTER", 360, 0)
ns.bankWin:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
ns.bankWin:SetBackdropColor(0, 0, 0, 1)
ns.bankWin:SetBackdropBorderColor(0.15, 0.15, 0.15, 1)
ns.bankWin:SetMovable(true)
ns.bankWin:EnableMouse(false)
ns.bankWin:SetClampedToScreen(true)
ns.bankWin:SetFrameStrata("HIGH")
ns.bankWin:Hide()
table.insert(UISpecialFrames, "AVL_BankWin")

local bankTitleBar = CreateFrame("Frame", nil, ns.bankWin, "BackdropTemplate")
bankTitleBar:SetHeight(30)
bankTitleBar:SetPoint("TOPLEFT",  ns.bankWin, "TOPLEFT",  0, 0)
bankTitleBar:SetPoint("TOPRIGHT", ns.bankWin, "TOPRIGHT", 0, 0)
bankTitleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
bankTitleBar:SetBackdropColor(0, 0, 0, 1)
bankTitleBar:SetFrameLevel(ns.bankWin:GetFrameLevel() + 2)
bankTitleBar:EnableMouse(true)
bankTitleBar:RegisterForDrag("LeftButton")
bankTitleBar:SetScript("OnDragStart", function() ns.bankWin:StartMoving() end)
bankTitleBar:SetScript("OnDragStop", function()
    ns.bankWin:StopMovingOrSizing()
    local x, y = ns.bankWin:GetLeft(), ns.bankWin:GetTop()
    ns.bankWin:ClearAllPoints()
    ns.bankWin:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end)

ns.bankWin.titleText = bankTitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ns.bankWin.titleText:SetPoint("LEFT", 14, 0)
ns.bankWin.titleText:SetText("|cffcc88ffAltViewerLog|r |cffaaaaaa—|r |cff4da6ff" .. ns.L("BTN_BANK") .. "|r")

local bankClose = CreateFrame("Button", nil, bankTitleBar, "UIPanelCloseButton")
bankClose:SetPoint("RIGHT", -5, 0)
bankClose:SetScript("OnClick", function() ns.bankWin:Hide() end)

local bankSF = CreateFrame("ScrollFrame", nil, ns.bankWin, "UIPanelScrollFrameTemplate")
bankSF:SetPoint("TOPLEFT",     ns.bankWin, "TOPLEFT",     12, -40)
bankSF:SetPoint("BOTTOMRIGHT", ns.bankWin, "BOTTOMRIGHT", -28,  10)

ns.bankScrollChild = CreateFrame("Frame", nil, bankSF)
ns.bankScrollChild:SetSize(650, 1)
bankSF:SetScrollChild(ns.bankScrollChild)
ns.SkinScrollBar(bankSF)
