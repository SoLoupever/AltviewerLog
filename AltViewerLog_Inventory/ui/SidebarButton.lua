local addonName, ns = ...
local core = ns.core

-- ====================================================
-- UI/SIDEBARBUTTON — Helper d'enregistrement des boutons sidebar
-- Rôle UNIQUE : factoriser core.RegisterSidebarButton pour les
-- modules de l'Inventaire (priorités 10-14, avant Graphique = 50).
-- ====================================================

-- view (optionnel) : fonction de vue, pour le surlignage à l'ouverture
function ns.AddSidebarButton(priority, labelKey, onClick, view)
    local btn = core.RegisterSidebarButton(priority, function(parent)
        return CreateFrame("Button", nil, parent, "BackdropTemplate")
    end, view)
    if not btn then return nil end
    btn:SetText(ns.L(labelKey))
    btn:SetScript("OnClick", function() core.CloseAllPopups(); onClick() end)
    return btn
end
