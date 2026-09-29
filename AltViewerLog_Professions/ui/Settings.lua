local addonName, pluginNs = ...

-- ====================================================
-- PROFESSIONS/UI/SETTINGS — Section paramètres Métiers
-- Injectée dans le menu Paramètres de AltViewerLog
-- via ns.RegisterSettingsSection (depuis Init.lua).
-- ====================================================

-- Helper local : mesure la largeur d'un texte rendu
local _profMeasureFS
local function TextWidth(text, fontObj)
    if not _profMeasureFS then
        _profMeasureFS = UIParent:CreateFontString(nil, "ARTWORK", fontObj or "GameFontHighlight")
    else
        _profMeasureFS:SetFontObject(fontObj or "GameFontHighlight")
    end
    _profMeasureFS:SetText(text)
    return math.ceil(_profMeasureFS:GetStringWidth())
end

function pluginNs.InjectProfSettings(scrollChild, y)
    -- En-tête de section — point d'extension conservé pour les futures
    -- options Métiers. L'ancienne option « Aperçu 2D housing » a migré
    -- dans le module ViewerLog_Housing (ui/Settings.lua), qui enregistre
    -- sa propre section via core.RegisterSettingsSection.
    local secLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    secLabel:SetPoint("TOPLEFT", 20, y)
    secLabel:SetText("|cff00ff00AltViewerLog_Prof|r")
    y = y - 26

    -- Ajouter ici d'autres options Métiers à l'avenir

    return y
end
