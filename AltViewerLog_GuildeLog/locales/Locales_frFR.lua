local addonName, pluginNs = ...

pluginNs.locales = {}

-- ====================================================
-- TRADUCTIONS FRANÇAISES
-- ====================================================
pluginNs.locales["frFR"] = {
    BTN_GUILDE          = "Coffre de Guilde",
    GUILDE_TITLE        = "Coffre de Guilde",
    NO_DATA             = "Aucun coffre scanné.\nOuvrez le coffre de guilde pour scanner.",
    NO_GUILD            = "Vous n'êtes dans aucune guilde.",
    TAB_LABEL           = "Onglet %d",
    OTHER_TABS_HEADER   = "Autres onglets",
    GUILD_NAME_LABEL    = "Guilde : %s",
    GUILD_LEADER_LABEL  = "Chef : %s",
    SCAN_DATE           = "Dernière mise à jour : %s",
    NEVER_SCANNED       = "Jamais scanné",
    SETTINGS_TITLE      = "OBSOLETE",   -- géré par ViewerLog
    SETTINGS_DESC       = "OBSOLETE",   -- géré par ViewerLog
    CHAR_LABEL          = "Perso : %s (%s)",
    ITEMS_COUNT         = "(%d objets)",

    -- Erreurs / debug / slash
    ERR_API_MISSING     = "ERREUR : AltViewerLogAPI introuvable.",
    DBG_SCAN_STARTED    = "Scan du coffre lancé.",
    DBG_HELP            = "|cffffff00/avlguilde scan|r  |cffffff00/avlguilde show|r",
    DBG_LOADED          = "Plugin Coffre de Guilde chargé.",

    -- Addon Compartment (menu minimap)
    AC_TITLE            = "|cff00aaffAltViewerLog|r |cffffffff— Guilde|r",
    AC_CLICK_HINT       = "Clic : Ouvrir le coffre de guilde",
    AC_NO_CHEST_SCANNED = "Aucun coffre scanné",
}

-- Fonction de localisation locale au plugin
function pluginNs.L(key)
    local core = _G.AltViewerLogAPI
    -- Utiliser la même langue que le core
    local lang = (core and AltViewerLogDB and AltViewerLogDB.settings and AltViewerLogDB.settings.lang)
                 or GetLocale()
    local t = pluginNs.locales[lang] or pluginNs.locales["enUS"]
    return t[key] or ("[GL:" .. key .. "]")
end
