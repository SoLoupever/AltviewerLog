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
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(44, 22)
    btn:SetPoint("LEFT", realmTitle, "RIGHT", arrowOffsetX, 2)
    ns.Skin.Button(btn)

    -- Texte ON / OFF centré
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    btn.label = label

    -- ON (replié) = rouge, OFF (déplié) = vert ; fond/bordure via le skin
    local function ApplyState(self)
        if ns.IsRealmCollapsed(realmName) then
            self.label:SetText("|cffff4444ON|r")
        else
            self.label:SetText("|cff44ff44OFF|r")
        end
    end

    ApplyState(btn)

    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if ns.IsRealmCollapsed(realmName) then
            GameTooltip:SetText(ns.L("REALM_EXPAND"), 0.5, 1, 0.5)
        else
            GameTooltip:SetText(ns.L("REALM_COLLAPSE"), 1, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)

    btn:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        ToggleRealm(realmName)
    end)

    return btn
end
