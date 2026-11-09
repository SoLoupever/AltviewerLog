local addonName, ns = ...
local core = ns.core

-- ====================================================
-- UI/BANKWINDOW — Fenêtre banque flottante
-- Rôle UNIQUE : créer ns.bankWin / ns.bankScrollChild
-- (contenu rempli par fonctionnalite/Bank.lua).
-- ====================================================

-- ── Fenêtre banque flottante ──────────────────────────────────────
ns.bankWin = CreateFrame("Frame", "AVL_BankWin", UIParent, "BackdropTemplate")
ns.bankWin:SetSize(720, 540)
ns.bankWin:SetPoint("CENTER", UIParent, "CENTER", 360, 0)
ns.Skin.Frame(ns.bankWin, "window")
ns.bankWin:SetMovable(true)
ns.bankWin:EnableMouse(false)
ns.bankWin:SetClampedToScreen(true)
ns.bankWin:SetFrameStrata("HIGH")
ns.bankWin:Hide()
table.insert(UISpecialFrames, "AVL_BankWin")

local bankTitleBar = CreateFrame("Frame", nil, ns.bankWin)
bankTitleBar:SetHeight(ns.LAYOUT.titleH)
bankTitleBar:SetPoint("TOPLEFT",  ns.bankWin, "TOPLEFT",  0, 0)
bankTitleBar:SetPoint("TOPRIGHT", ns.bankWin, "TOPRIGHT", 0, 0)
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
ns.bankWin.titleText:SetPoint("LEFT", 16, 0)
ns.bankWin.titleText:SetText("|cff" .. ns.Theme.title .. ns.L("UI_TITLE") .. "|r |cffaaaaaa-|r |cffffd100" .. ns.L("BTN_BANK") .. "|r")

local bankClose = ns.Skin.CloseButton(bankTitleBar, function() ns.bankWin:Hide() end)
bankClose:SetPoint("RIGHT", -12, 0)

local bankSF = CreateFrame("ScrollFrame", nil, ns.bankWin, "UIPanelScrollFrameTemplate")
bankSF:SetPoint("TOPLEFT",     ns.bankWin, "TOPLEFT",     12, -ns.LAYOUT.titleH - 4)
bankSF:SetPoint("BOTTOMRIGHT", ns.bankWin, "BOTTOMRIGHT", -28,  10)

ns.bankScrollChild = CreateFrame("Frame", nil, bankSF)
ns.bankScrollChild:SetSize(650, 1)
bankSF:SetScrollChild(ns.bankScrollChild)
ns.SkinScrollBar(bankSF)

-- Hôte pour le sélecteur de personnage (placement + fermeture)
core.RegisterHostFrame(ns.bankWin)
