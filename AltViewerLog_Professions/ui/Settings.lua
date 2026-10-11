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
    -- Aucune option pour l'instant : y inchangé = carte masquée.
    -- Ajouter les futures options Métiers ici.
    return y
end
