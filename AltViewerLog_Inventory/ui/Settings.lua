local addonName, ns = ...
local core = ns.core

-- ====================================================
-- UI/SETTINGS — Section paramètres de l'Inventaire
-- Injectée dans Paramètres via core.RegisterSettingsSection.
-- ====================================================

local function Settings()
    AltViewerLogDB.settings = AltViewerLogDB.settings or {}
    return AltViewerLogDB.settings
end

core.RegisterSettingsSection(function(card, y)
    local UI = core.SettingsUI
    y = UI.Header(card, y, ns.L("SETTINGS_INV_TITLE"))
    y = UI.Checkbox(card, y, ns.L("SORT_POP"),
        function() return Settings().sortByPop or false end,
        function(v) Settings().sortByPop = v end)
    y = UI.Checkbox(card, y, ns.L("BANK_INLINE_MODE"),
        function() return Settings().bankInline or false end,
        function(v) Settings().bankInline = v end)
    return y
end)
