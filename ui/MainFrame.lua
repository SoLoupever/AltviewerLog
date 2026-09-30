local addonName, ns = ...

-- ====================================================
-- UI/MAINFRAME — Frame principale + titleBar + resizeGrip
-- Rôle UNIQUE : créer ns.mainFrame et sa barre de titre.
-- ====================================================

ns.mainFrame = CreateFrame("Frame", "AltViewerLogFrame", UIParent, "BackdropTemplate")
ns.mainFrame:SetSize(900, 600)
ns.mainFrame:SetPoint("CENTER")
ns.mainFrame:SetFrameStrata("HIGH")
ns.mainFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
ns.mainFrame:SetBackdropColor(0, 0, 0, 1)
ns.mainFrame:SetMovable(true)
ns.mainFrame:EnableMouse(false)
ns.mainFrame:SetClampedToScreen(true)
ns.mainFrame:Hide()
ns.mainFrame:SetResizable(true)
ns.mainFrame:SetResizeBounds(500, 350, 1800, 1000)
table.insert(UISpecialFrames, "AltViewerLogFrame")

-- ── Barre de titre (INTÉRIEURE à mainFrame) ──────────────────────
local titleBar = CreateFrame("Frame", nil, ns.mainFrame, "BackdropTemplate")
titleBar:SetHeight(30)
titleBar:SetPoint("TOPLEFT",  ns.mainFrame, "TOPLEFT",  0, 0)
titleBar:SetPoint("TOPRIGHT", ns.mainFrame, "TOPRIGHT", 0, 0)
titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
titleBar:SetBackdropColor(0, 0, 0, 1)
titleBar:SetFrameLevel(ns.mainFrame:GetFrameLevel() + 5)
titleBar:EnableMouse(true)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() ns.mainFrame:StartMoving() end)
titleBar:SetScript("OnDragStop", function()
    ns.mainFrame:StopMovingOrSizing()
    local x, y = ns.mainFrame:GetLeft(), ns.mainFrame:GetTop()
    ns.mainFrame:ClearAllPoints()
    ns.mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
end)

ns.titleBar = titleBar
ns._UI = ns._UI or {}
ns._UI.titleBar = titleBar
local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", 15, 0)
titleText:SetText("|cff4da6ffAltViewerLog|r |cffff40a0By Soloup_ever|r")
ns.titleText = titleText

local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
closeBtn:SetPoint("RIGHT", -5, 0)
closeBtn:SetScript("OnClick", function() ns.mainFrame:Hide() end)

-- ── Fond principal (zone contenu, à droite de la sidebar) ─────────
local mainBG = CreateFrame("Frame", nil, ns.mainFrame, "BackdropTemplate")
mainBG:SetPoint("TOPLEFT",     ns.mainFrame, "TOPLEFT",     200, -30)
mainBG:SetPoint("BOTTOMRIGHT", ns.mainFrame, "BOTTOMRIGHT",   0, 0)
mainBG:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
mainBG:SetBackdropColor(0, 0, 0, 1)

-- Exposition pour Theme.lua
ns._UI = ns._UI or {}
ns._UI.mainBG = mainBG

-- ── Poignée de redimensionnement ─────────────────────────────────
local resizeGrip = CreateFrame("Frame", nil, ns.mainFrame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", ns.mainFrame, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetFrameLevel(ns.mainFrame:GetFrameLevel() + 10)
resizeGrip:EnableMouse(true)

local rN = resizeGrip:CreateTexture(nil, "OVERLAY")
rN:SetAllPoints()
rN:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
local rH = resizeGrip:CreateTexture(nil, "HIGHLIGHT")
rH:SetAllPoints()
rH:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

-- Fond ultra-simple utilisé le temps d'un redimensionnement actif.
-- StartSizing() est géré nativement par le moteur du jeu (pas de
-- rappel Lua à chaque frame pendant le geste) : Lua n'y peut rien.
-- Mais le moteur de rendu doit quand même ré-étaler le fond du thème
-- à la nouvelle taille à chaque frame tant que le geste est en cours
-- — et le fond réel (JPEG 1672x941, cf. ui/Theme.lua) coûte plus cher
-- à ré-étaler en continu qu'une simple couleur unie. D'où les
-- micro-freezes signalés pendant le redimensionnement.
local BACKDROP_RESIZE_TEMP = { bgFile = "Interface\\Buttons\\WHITE8x8" }

resizeGrip:SetScript("OnMouseDown", function(self, btn)
    if btn == "LeftButton" then
        ns.mainFrame:SetBackdrop(BACKDROP_RESIZE_TEMP)
        ns.mainFrame:SetBackdropColor(0, 0, 0, 1)
        ns.mainFrame:StartSizing("BOTTOMRIGHT")
    end
end)
resizeGrip:SetScript("OnMouseUp", function(self, btn)
    if btn == "LeftButton" then
        ns.mainFrame:StopMovingOrSizing()
        -- Restaure le fond réel du thème actif (ApplyTheme recolore
        -- aussi sideBar/boutons/scrollbar au passage : réutilise le
        -- point d'application unique du thème plutôt que de dupliquer
        -- juste la partie "fond" ici).
        if ns.ApplyTheme then
            local theme = (AltViewerLogDB and AltViewerLogDB.settings
                          and AltViewerLogDB.settings.theme) or "default"
            ns.ApplyTheme(theme)
        end
        if AltViewerLogDB and AltViewerLogDB.settings then
            AltViewerLogDB.settings.frameWidth  = ns.mainFrame:GetWidth()
            AltViewerLogDB.settings.frameHeight = ns.mainFrame:GetHeight()
        end
        ns.scrollChild:SetWidth(ns.GetContentWidth())
        if ns.currentView and not ns.currentViewIsBank then
            ns.currentView()
        else
            ns.RefreshCharacterList()
        end
    end
end)
ns.mainFrame.resizeGrip = resizeGrip

-- ── Barre du bas ──────────────────────────────────────────────────
-- Créée ici car c'est une partie de mainFrame.
-- Les boutons (bbGold, bbTime, bbChars) sont ajoutés par BottomBar.lua.
ns.bottomBar = CreateFrame("Frame", "AVL_BottomBar", ns.mainFrame, "BackdropTemplate")
ns.bottomBar:SetHeight(36)
ns.bottomBar:SetPoint("BOTTOMLEFT",  ns.mainFrame, "BOTTOMLEFT",  0, 0)
ns.bottomBar:SetPoint("BOTTOMRIGHT", ns.mainFrame, "BOTTOMRIGHT", 0, 0)
ns.bottomBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
ns.bottomBar:SetBackdropColor(0, 0, 0, 1)
-- Stub : updated by Theme.lua when ApplyTheme is called
ns._UI = ns._UI or {}
ns._UI.mainBG = ns._UI.mainBG  -- déjà défini plus haut

-- Auto-fermeture du charSelMenu (parenté UIParent) quand l'addon se ferme
ns.mainFrame:HookScript("OnHide", function()
    if ns.charSelMenu and ns.charSelMenu:IsShown() then
        ns.charSelMenu:Hide()
    end
end)
