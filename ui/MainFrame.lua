local addonName, ns = ...

-- ====================================================
-- UI/MAINFRAME — Frame principale, barre de titre, panneau contenu
-- Rôle UNIQUE : créer ns.mainFrame, sa barre de titre, le panneau
-- de contenu et la poignée de redimensionnement.
-- ====================================================

-- Géométrie partagée (sidebar, scroll, barre du bas, plugins)
local LAYOUT = {
    pad     = 8,
    titleH  = 40,
    bottomH = 44,
    sideW   = 190,
}
LAYOUT.contentLeft = LAYOUT.pad + LAYOUT.sideW + LAYOUT.pad  -- bord gauche du panneau contenu
ns.LAYOUT = LAYOUT

local mainFrame = CreateFrame("Frame", "AltViewerLogFrame", UIParent, "BackdropTemplate")
ns.mainFrame = mainFrame
mainFrame:SetSize(900, 600)
mainFrame:SetPoint("CENTER")
mainFrame:SetFrameStrata("HIGH")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(false)
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()
mainFrame:SetResizable(true)
mainFrame:SetResizeBounds(560, 380, 1800, 1000)
ns.Skin.Frame(mainFrame, "window")
table.insert(UISpecialFrames, "AltViewerLogFrame")

-- ── Barre de titre ────────────────────────────────────────────────
local titleBar = CreateFrame("Frame", nil, mainFrame)
titleBar:SetHeight(LAYOUT.titleH)
titleBar:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  0, 0)
titleBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
titleBar:SetFrameLevel(mainFrame:GetFrameLevel() + 5)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
titleBar:SetScript("OnDragStop", function()
    mainFrame:StopMovingOrSizing()
    local x, y = mainFrame:GetLeft(), mainFrame:GetTop()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end)
ns.titleBar = titleBar
ns._UI = ns._UI or {}
ns._UI.titleBar = titleBar

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", 18, 0)
ns.titleText = titleText

-- Bouton fermer (carré bordé, sans numéro de version)
local closeBtn = ns.Skin.CloseButton(titleBar, function() mainFrame:Hide() end)
closeBtn:SetPoint("RIGHT", -12, 0)

-- ── Panneau contenu (à droite de la sidebar) ──────────────────────
local mainBG = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
mainBG:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     LAYOUT.contentLeft, -LAYOUT.titleH)
mainBG:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -LAYOUT.pad,          LAYOUT.bottomH)
ns.Skin.Frame(mainBG, "panel")
ns.contentPanel = mainBG
ns._UI.mainBG = mainBG

-- ── Poignée de redimensionnement ─────────────────────────────────
local resizeGrip = CreateFrame("Frame", nil, mainFrame)
resizeGrip:SetSize(14, 14)
resizeGrip:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetFrameLevel(mainFrame:GetFrameLevel() + 10)
resizeGrip:EnableMouse(true)

local rN = resizeGrip:CreateTexture(nil, "OVERLAY")
rN:SetAllPoints()
rN:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
local rH = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
rH:SetAllPoints()
rH:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

resizeGrip:SetScript("OnMouseDown", function(_, btn)
    if btn == "LeftButton" then mainFrame:StartSizing("BOTTOMRIGHT") end
end)
resizeGrip:SetScript("OnMouseUp", function(_, btn)
    if btn ~= "LeftButton" then return end
    mainFrame:StopMovingOrSizing()
    if AltViewerLogDB and AltViewerLogDB.settings then
        AltViewerLogDB.settings.frameWidth  = mainFrame:GetWidth()
        AltViewerLogDB.settings.frameHeight = mainFrame:GetHeight()
    end
    ns.scrollChild:SetWidth(ns.GetContentWidth())
    if ns.currentView and not ns.currentViewIsBank then
        ns.currentView()
    else
        ns.RefreshCharacterList()
    end
end)
mainFrame.resizeGrip = resizeGrip

-- ── Barre du bas (conteneur ; les 3 boutons sont dans BottomBar.lua)
ns.bottomBar = CreateFrame("Frame", "AVL_BottomBar", mainFrame)
ns.bottomBar:SetHeight(LAYOUT.bottomH)
ns.bottomBar:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",  0, 0)
ns.bottomBar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)

-- Auto-fermeture du charSelMenu (parenté UIParent) quand l'addon se ferme
mainFrame:HookScript("OnHide", function()
    if ns.charSelMenu and ns.charSelMenu:IsShown() then
        ns.charSelMenu:Hide()
    end
end)
