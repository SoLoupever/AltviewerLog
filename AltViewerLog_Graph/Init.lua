local addonName, pluginNs = ...

local core = _G.AltViewerLogAPI
if not core then
    print("|cffff0000[AVL-Graph]|r " .. pluginNs.L("ERR_API_MISSING"))
    return
end

core.DBG("|cff4da6ff[AVL-Graph]|r " .. pluginNs.L("DBG_LOADED"))

-- ====================================================
-- INJECTION DU BOUTON DANS LA SIDEBAR
-- Enregistrement synchrone via core.RegisterSidebarButton (même
-- mécanisme que AltViewerLog_Professions). Priorité 50 : place le
-- bouton juste sous les boutons natifs d'AltViewerLog, avant les
-- autres plugins (Métiers=100, Réputations=200, Guilde=300), pour
-- conserver la position historique du bouton Graphique.
-- ====================================================
if core.RegisterSidebarButton then
    local btnGraph = core.RegisterSidebarButton(50, function(parent)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(160, 35)
        btn:SetText(pluginNs.L("BTN_GRAPH"))
        btn:SetNormalFontObject("GameFontNormal")
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        btn:SetBackdropColor(0, 0, 0, 1)
        btn:SetBackdropBorderColor(0.45, 0.15, 0.70, 0.85)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 1)
            local b = core._themeBorder or {0.65, 0.35, 1.0}
            self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 1)
            local b = core._themeBorder or {0.45, 0.15, 0.70}
            self:SetBackdropBorderColor(b[1], b[2], b[3], 0.85)
        end)
        return btn
    end)

    if btnGraph then
        -- Couleur de classe (comme les boutons natifs de la sidebar).
        local function ApplyGraphBtnColor()
            local _, classFile = UnitClass("player")
            local col = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
            local hex = "cc88ff"
            if col then
                hex = string.format("%02x%02x%02x",
                    math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255))
            end
            btnGraph:SetText("|cff"..hex..pluginNs.L("BTN_GRAPH").."|r")
        end
        C_Timer.After(1, ApplyGraphBtnColor)
        local _colorFrame = CreateFrame("Frame")
        _colorFrame:RegisterEvent("PLAYER_LOGIN")
        _colorFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_LOGIN")
            ApplyGraphBtnColor()
        end)

        btnGraph:SetScript("OnClick", function()
            if core.CloseAllPopups then core.CloseAllPopups() end
            pluginNs.ShowGraph()
        end)
    end
end

-- ====================================================
-- SLASH COMMAND
-- ====================================================
SLASH_AVLGRAPH1 = "/avlgraph"
SlashCmdList["AVLGRAPH"] = function()
    if core.CloseAllPopups then core.CloseAllPopups() end
    pluginNs.ShowGraph()
    if core.mainFrame then core.mainFrame:Show() end
end
