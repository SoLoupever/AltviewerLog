local addonName, pluginNs = ...

-- ====================================================
-- PANNEAU BOIS — collé à droite de ProfessionsFrame
-- S'affiche / se cache avec la fenêtre métier Blizzard
-- ====================================================

local PANEL_W   = 175
local BTN_W     = PANEL_W - 16
local BTN_H     = 36
local BTN_GAP   = 4
local TOP_PAD   = 38   -- espace sous le titre de la section

-- Bac à sable pour détacher les enfants sans les détruire
local trashBin = CreateFrame("Frame", nil, UIParent)
trashBin:Hide()

-- Cadre principal du panneau (créé une seule fois)
local panel = CreateFrame("Frame", "BVLBlizzWoodPanel", UIParent, "BackdropTemplate")
panel:SetWidth(PANEL_W)
panel:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
panel:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
panel:SetBackdropBorderColor(0.50, 0.42, 0.12, 1)
panel:SetFrameStrata("HIGH")
panel:Hide()

-- Titre fixe du panneau
local panelTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panelTitle:SetPoint("TOPLEFT", 8, -10)
-- panelTitle text is set in ShowPanel() once core is available

-- Séparateur sous le titre
local titleSep = panel:CreateTexture(nil, "ARTWORK")
titleSep:SetSize(PANEL_W - 10, 1)
titleSep:SetPoint("TOPLEFT", 5, -26)
titleSep:SetColorTexture(0.50, 0.42, 0.12, 0.6)

-- ====================================================
-- CONTENU DYNAMIQUE (reconstruction à chaque refresh)
-- ====================================================
local contentFrame = nil

local function RebuildContent()
    -- Détache l'ancien contenu dans le bac à sable
    if contentFrame then
        contentFrame:SetParent(trashBin)
        contentFrame:Hide()
    end

    contentFrame = CreateFrame("Frame", nil, panel)
    contentFrame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, 0)
    contentFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)

    -- Source unique : bois fourni par ViewerLog via l'API partagée
    -- (même source que ui/View.lua — pas de tracker parallèle ici).
    local vlWoodAPI      = _G.ViewerLogAPI
    local woodExpansions = (vlWoodAPI and vlWoodAPI.GetWoodExpansions and vlWoodAPI.GetWoodExpansions()) or {}
    local woodDetail      = {}
    if vlWoodAPI and vlWoodAPI.GetWoodCounts then
        local _, d = vlWoodAPI.GetWoodCounts()
        woodDetail = d or {}
    end
    local WoodName = (vlWoodAPI and vlWoodAPI.GetWoodItemName) or function() return "?" end

    local curY = -(TOP_PAD)

    for _, expBlock in ipairs(woodExpansions) do
        local expQty = 0
        for _, item in ipairs(expBlock.items) do
            expQty = expQty + (woodDetail[item.id] or 0)
        end

        local cr, cg, cb = expBlock.color[1], expBlock.color[2], expBlock.color[3]
        local hasStock    = expQty > 0

        -- ── Bouton expansion ──────────────────────────
        local btn = CreateFrame("Button", nil, contentFrame, "BackdropTemplate")
        btn:SetSize(BTN_W, BTN_H)
        btn:SetPoint("TOPLEFT", 8, curY)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        if hasStock then
            btn:SetBackdropColor(cr * 0.18, cg * 0.18, cb * 0.18, 1)
            btn:SetBackdropBorderColor(cr * 0.65, cg * 0.65, cb * 0.65, 1)
        else
            btn:SetBackdropColor(0.08, 0.08, 0.08, 1)
            btn:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)
        end

        -- Nom de l'extension (gauche)
        local nameFs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("TOPLEFT", 5, -9)
        nameFs:SetPoint("TOPRIGHT", -38, -9)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetWordWrap(false)
        if hasStock then
            nameFs:SetTextColor(
                cr * 0.80 + 0.20,
                cg * 0.80 + 0.20,
                cb * 0.80 + 0.20)
        else
            nameFs:SetTextColor(0.30, 0.30, 0.30)
        end
        nameFs:SetText(expBlock.expansion)

        -- Quantité (droite, ligne du bas)
        local qtyFs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        qtyFs:SetPoint("BOTTOM", 0, 5)
        qtyFs:SetJustifyH("CENTER")
        if hasStock then
            local col = expQty >= 200 and "|cff00ff00"
                     or expQty >= 50  and "|cffffff00"
                     or                   "|cffff8060"
            qtyFs:SetText(col .. expQty .. "|r")
        else
            qtyFs:SetText("|cff2a2a2a0|r")
        end

        -- Tooltip
        local capBlock  = expBlock
        local capDetail = woodDetail
        local capStock  = hasStock
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(
                capStock and cr * 0.28 or 0.14,
                capStock and cg * 0.28 or 0.14,
                capStock and cb * 0.28 or 0.14, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("|cffffd700" .. capBlock.expansion .. "|r")
            GameTooltip:AddLine(" ")
            for _, item in ipairs(capBlock.items) do
                local qty = capDetail[item.id] or 0
                GameTooltip:AddDoubleLine(
                    "|cffccaa60" .. WoodName(item.id) .. "|r",
                    (qty > 0 and "|cffffffff" or "|cff555555") .. qty .. "|r",
                    1, 1, 1, 1, 1, 1)
            end
            if not capStock then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff555555" .. pluginNs.L("TT_WARBAND_SCAN_HINT") .. "|r")
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(
                capStock and cr * 0.18 or 0.08,
                capStock and cg * 0.18 or 0.08,
                capStock and cb * 0.18 or 0.08, 1)
            GameTooltip:Hide()
        end)

        curY = curY - BTN_H - BTN_GAP
    end

    -- Ajuste la hauteur du panneau selon le contenu
    local totalH = math.abs(curY) + 14
    panel:SetHeight(math.max(totalH, 80))
    contentFrame:SetHeight(totalH)
end

-- ====================================================
-- POSITIONNEMENT — collé à droite de ProfessionsFrame
-- ====================================================
local function RepositionPanel()
    if not ProfessionsFrame then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 4, 0)
end

local function IsWoodPanelEnabled()
    return AltViewerLogDB.woodPanelEnabled ~= false  -- true par défaut
end

local function ShowPanel()
    if not ProfessionsFrame or not ProfessionsFrame:IsShown() then return end
    if not IsWoodPanelEnabled() then return end
    -- Titre localisé : résolu ici pour que core soit garanti disponible
    local _core = _G.AltViewerLogAPI
    panelTitle:SetText("|cffcca060" .. (_core and _core.L and _core.L("WOOD_TITLE") or "Bois") .. "|r")
    RepositionPanel()
    RebuildContent()
    panel:Show()
end

local function HidePanel()
    panel:Hide()
end

-- ====================================================
-- BOUTON TOGGLE DANS ProfessionsFrame (UI Blizzard)
-- ====================================================
local toggleBtn = nil

local function UpdateToggleBtn()
    if not toggleBtn then return end
    -- Actif : logo pleine opacité ; masqué : logo semi-transparent
    if IsWoodPanelEnabled() then
        toggleBtn.logoTex:SetVertexColor(1, 1, 1, 1)
    else
        toggleBtn.logoTex:SetVertexColor(0.4, 0.4, 0.4, 0.55)
    end
end

local function CreateToggleButton()
    if toggleBtn then return end
    if not ProfessionsFrame then return end

    toggleBtn = CreateFrame("Button", "PVLWoodToggleBtn", ProfessionsFrame)
    toggleBtn:SetSize(22, 22)
    -- Ancré à gauche du bouton MaximizeMinimize, dans la barre de titre
    if ProfessionsFrame.MaximizeMinimize then
        toggleBtn:SetPoint("RIGHT", ProfessionsFrame.MaximizeMinimize, "LEFT", -4, 0)
    else
        toggleBtn:SetPoint("TOPRIGHT", ProfessionsFrame, "TOPRIGHT", -115, -4)
    end
    toggleBtn:SetFrameStrata("HIGH")
    toggleBtn:SetFrameLevel(ProfessionsFrame:GetFrameLevel() + 20)

    -- Logo de l'addon comme icône du bouton
    local logoTex = toggleBtn:CreateTexture(nil, "ARTWORK")
    logoTex:SetAllPoints()
    logoTex:SetTexture("Interface\\AddOns\\AltViewerLog\\Logo_Alt.blp")
    toggleBtn.logoTex = logoTex

    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cff00ff00AltViewerLog|r |cff00ff00Professions|r")
        if IsWoodPanelEnabled() then
            local _c = _G.AltViewerLogAPI; GameTooltip:AddLine("|cffaaaaaa" .. (_c and _c.L and _c.L("WOOD_PANEL_HIDE") or pluginNs.L("WOOD_PANEL_HIDE")) .. "|r")
        else
            local _c = _G.AltViewerLogAPI; GameTooltip:AddLine("|cffaaaaaa" .. (_c and _c.L and _c.L("WOOD_PANEL_SHOW") or pluginNs.L("WOOD_PANEL_SHOW")) .. "|r")
        end
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    toggleBtn:SetScript("OnClick", function()
        AltViewerLogDB.woodPanelEnabled = not IsWoodPanelEnabled()
        UpdateToggleBtn()
        if IsWoodPanelEnabled() then
            ShowPanel()
        else
            HidePanel()
        end
    end)

    UpdateToggleBtn()
end

-- ====================================================
-- HOOKS SUR ProfessionsFrame (chargé à la demande)
-- ====================================================
local function HookProfessionsFrame()
    if not ProfessionsFrame then return false end

    CreateToggleButton()

    ProfessionsFrame:HookScript("OnShow", function()
        UpdateToggleBtn()
        C_Timer.After(0.05, ShowPanel)
    end)
    ProfessionsFrame:HookScript("OnHide", HidePanel)

    -- Si la fenêtre est déjà ouverte au chargement de l'addon
    if ProfessionsFrame:IsShown() then
        C_Timer.After(0.1, ShowPanel)
    end
    return true
end

-- L'addon Blizzard_Professions est chargé À LA DEMANDE (quand on ouvre la fenêtre).
-- ProfessionsFrame est nil jusqu'à ce chargement → on écoute ADDON_LOADED avec arg1 exact.
local hookDone = false
local hookWatcher = CreateFrame("Frame")
hookWatcher:RegisterEvent("ADDON_LOADED")
hookWatcher:SetScript("OnEvent", function(self, event, arg1)
    if hookDone then return end
    -- Cas 1 : Blizzard_Professions vient de se charger
    if arg1 == "Blizzard_Professions" then
        C_Timer.After(0.2, function()
            if HookProfessionsFrame() then
                hookDone = true
                self:UnregisterAllEvents()
            end
        end)
        return
    end
    -- Cas 2 : déjà chargé (rare, mais possible si d'autres addons le forcent)
    if ProfessionsFrame and HookProfessionsFrame() then
        hookDone = true
        self:UnregisterAllEvents()
    end
end)
