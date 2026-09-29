local addonName, pluginNs = ...

pluginNs.locales = {}

-- ====================================================
-- TRADUCTIONS FRANÇAISES
-- ====================================================
pluginNs.locales["frFR"] = {
    BTN_REPUT           = "Réputations",
    REPUT_TITLE         = "Réputations",
    NO_DATA             = "Aucune donnée de réputation.\nOuvrez le jeu avec ViewerLog actif.",
    NO_SCAN_YET         = "Aucune réputation scannée.\nUtilisez /vl reput ou reconnectez-vous.",
    CHAR_LABEL          = "%s  (%s)",

    -- Réactions (noms officiels WoW FR)
    REACTION_1          = "Détesté",
    REACTION_2          = "Hostile",
    REACTION_3          = "Inamical",
    REACTION_4          = "Neutre",
    REACTION_5          = "Amical",
    REACTION_6          = "Honoré",
    REACTION_7          = "Révéré",
    REACTION_8          = "Exalté",

    -- Factions majeures (renom)
    RENOWN_LABEL        = "Renom %d / %d",
    RENOWN_MAX          = "Renom max",

    -- Paragon
    PARAGON_READY       = "Coffre disponible !",

    -- Tooltip
    TT_REACTION         = "Réputation : %s",
    TT_PROGRESS         = "Progression : %d / %d",
    TT_RENOWN           = "Renom : %d / %d",
    TT_RENOWN_EARNED    = "XP renom : %d / %d",
    TT_PARAGON          = "Paragon niv. %d  (%d / %d)",
    TT_ACCOUNT_WIDE     = "Réputation de compte",
    TT_LAST_UPDATE      = "Mis à jour le %s",
    TT_BEST_CHAR        = "Plus avancé :",

    -- Interface
    FILTER_ALL          = "Tout",
    FILTER_MAJOR        = "Majeures",
    FILTER_EXALTED      = "Exaltés",

    -- Erreurs / debug / slash
    ERR_API_MISSING     = "ERREUR : AltViewerLogAPI introuvable.",
    DBG_SCAN_STARTED    = "Scan des réputations lancé.",
    DBG_SCAN_FN_MISSING = "ViewerLogAPI.ScanReputations introuvable.",
    DBG_HELP_SHOW       = "  /avlreput |cffffff00show|r  — ouvre la vue",
    DBG_HELP_SCAN       = "  /avlreput |cffffff00scan|r  — force un scan",
    DBG_LOADED          = "Plugin Réputations chargé.",
    CHAR_SWITCH_TT      = "Changer de personnage",

    -- Addon Compartment (menu minimap)
    AC_TITLE            = "|cffa040ffAltViewerLog|r |cffffffff— Réputations|r",
    AC_CHAR_REPUT_COUNT = "%s — %d réputations",
    AC_CLICK_HINT       = "Clic : Ouvrir les réputations",
}

-- ====================================================
-- FONCTION DE TRADUCTION
-- ====================================================
function pluginNs.L(key)
    local core = _G.AltViewerLogAPI
    local lang = (core and AltViewerLogDB and AltViewerLogDB.settings
                  and AltViewerLogDB.settings.lang)
                 or GetLocale()
    local t = pluginNs.locales[lang] or pluginNs.locales["enUS"]
    return t[key] or ("[REPUT:" .. key .. "]")
end
