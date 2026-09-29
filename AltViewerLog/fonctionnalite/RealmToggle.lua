local addonName, ns = ...

-- ====================================================
-- REALM TOGGLE : Bouton pour replier / déplier un serveur
--
-- État sauvegardé dans :
--   AltViewerLogDB.settings.realmCollapsed[realmName] = true/false
--
-- true  = serveur replié  (bouton actif / rouge)
-- false = serveur déplié  (bouton inactif / vert, comportement par défaut)
-- ====================================================

-- Retourne true si le serveur est replié
function ns.IsRealmCollapsed(realmName)
    local s = AltViewerLogDB and AltViewerLogDB.settings
    if not s or not s.realmCollapsed then return false end
    return s.realmCollapsed[realmName] == true
end

-- Bascule l'état replié du serveur et rafraîchit la liste
local function ToggleRealm(realmName)
    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
    AltViewerLogDB.settings.realmCollapsed = AltViewerLogDB.settings.realmCollapsed or {}
    local current = AltViewerLogDB.settings.realmCollapsed[realmName]
    AltViewerLogDB.settings.realmCollapsed[realmName] = not current
    ns.RefreshCharacterList()
end

-- ====================================================
-- Crée le bouton toggle et le place après les flèches
-- Appelé depuis Characters.lua après la création des flèches
-- ====================================================
function ns.CreateRealmToggleButton(parent, realmTitle, realmName, arrowOffsetX)
    local collapsed = ns.IsRealmCollapsed(realmName)

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(32, 16)
    btn:SetPoint("LEFT", realmTitle, "RIGHT", arrowOffsetX, 2)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    -- Texte ON / OFF centré
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    btn.label = label

    -- Applique la couleur selon l'état
    local function ApplyState(self, isHover)
        local col = ns.IsRealmCollapsed(realmName)
        if col then
            -- Replié → rouge
            if isHover then
                self:SetBackdropColor(0.45, 0.10, 0.10, 1)
                self:SetBackdropBorderColor(1.00, 0.35, 0.35, 1)
            else
                self:SetBackdropColor(0.25, 0.08, 0.08, 1)
                self:SetBackdropBorderColor(0.70, 0.20, 0.20, 1)
            end
            self.label:SetText("|cffff4444ON|r")
        else
            -- Déplié → vert
            if isHover then
                self:SetBackdropColor(0.10, 0.35, 0.10, 1)
                self:SetBackdropBorderColor(0.35, 1.00, 0.35, 1)
            else
                self:SetBackdropColor(0.08, 0.20, 0.08, 1)
                self:SetBackdropBorderColor(0.20, 0.60, 0.20, 1)
            end
            self.label:SetText("|cff44ff44OFF|r")
        end
    end

    ApplyState(btn, false)

    btn:SetScript("OnEnter", function(self)
        ApplyState(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if ns.IsRealmCollapsed(realmName) then
            GameTooltip:SetText(ns.L("REALM_EXPAND"), 0.5, 1, 0.5)
        else
            GameTooltip:SetText(ns.L("REALM_COLLAPSE"), 1, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        ApplyState(self, false)
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        ToggleRealm(realmName)
    end)

    return btn
end
