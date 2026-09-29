local addonName, pluginNs = ...

-- ==================================================
-- GUILDE/UI/SETTINGS — Section paramètres guilde
-- Injectée dans le menu Settings de AltViewerLog
-- via ns.RegisterSettingsSection (Init.lua).
-- ==================================================

-- Helper local : mesure la largeur d'un texte rendu
local _guildMeasureFS
local function TextWidth(text, fontObj)
    if not _guildMeasureFS then
        _guildMeasureFS = UIParent:CreateFontString(nil, "ARTWORK", fontObj or "GameFontHighlightSmall")
    else
        _guildMeasureFS:SetFontObject(fontObj or "GameFontHighlightSmall")
    end
    _guildMeasureFS:SetText(text)
    return math.ceil(_guildMeasureFS:GetStringWidth())
end

-- Gestion des guildes déportée vers le panneau de paramètres de
-- ViewerLog. Fonction conservée pour l'appel existant dans Init.lua.
function pluginNs.InjectGuildSettings(scrollChild, startOffsetY)
    return startOffsetY
end
