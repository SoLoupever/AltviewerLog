local addonName, ns = ...

-- ====================================================
-- CORE/MINIMAP — Icône minimap (LibDBIcon)
-- Rôle UNIQUE : enregistrer l'icône minimap.
-- ====================================================

function ns.InitMinimap()
    local LibDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LibDBIcon then return end
    LibDBIcon:Register("AltViewerLog", {
        icon = "Interface\\AddOns\\AltViewerLog\\Logo_Alt.blp",
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cffffd700AltViewerLog|r")
            tooltip:AddLine("|cffffffff" .. ns.L("MINIMAP_SUBTITLE") .. "|r")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff808080" .. ns.L("MINIMAP_CLICK") .. "|r")
        end,
        OnClick = function()
            if not ns.mainFrame then return end
            if ns.mainFrame:IsShown() then
                ns.mainFrame:Hide()
            else
                ns.mainFrame:Show()
                ns.RefreshCharacterList()
            end
        end,
    }, AltViewerLogDB.minimap)
end
