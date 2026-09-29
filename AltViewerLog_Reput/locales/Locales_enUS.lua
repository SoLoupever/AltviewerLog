local addonName, pluginNs = ...

-- ====================================================
-- TRADUCTIONS ANGLAISES
-- ====================================================
pluginNs.locales["enUS"] = {
    BTN_REPUT           = "Reputations",
    REPUT_TITLE         = "Reputations",
    NO_DATA             = "No reputation data found.\nMake sure ViewerLog is active.",
    NO_SCAN_YET         = "No reputations scanned yet.\nUse /vl reput or re-login.",
    CHAR_LABEL          = "%s  (%s)",

    REACTION_1          = "Hated",
    REACTION_2          = "Hostile",
    REACTION_3          = "Unfriendly",
    REACTION_4          = "Neutral",
    REACTION_5          = "Friendly",
    REACTION_6          = "Honored",
    REACTION_7          = "Revered",
    REACTION_8          = "Exalted",

    RENOWN_LABEL        = "Renown %d / %d",
    RENOWN_MAX          = "Max renown",

    PARAGON_READY       = "Chest available!",

    TT_REACTION         = "Reputation: %s",
    TT_PROGRESS         = "Progress: %d / %d",
    TT_RENOWN           = "Renown: %d / %d",
    TT_RENOWN_EARNED    = "Renown XP: %d / %d",
    TT_PARAGON          = "Paragon lvl %d  (%d / %d)",
    TT_ACCOUNT_WIDE     = "Account-wide reputation",
    TT_LAST_UPDATE      = "Updated on %s",
    TT_BEST_CHAR        = "Most advanced:",

    FILTER_ALL          = "All",
    FILTER_MAJOR        = "Major",
    FILTER_EXALTED      = "Exalted",

    -- Errors / debug / slash
    ERR_API_MISSING     = "ERROR: AltViewerLogAPI not found.",
    DBG_SCAN_STARTED    = "Reputation scan started.",
    DBG_SCAN_FN_MISSING = "ViewerLogAPI.ScanReputations not found.",
    DBG_HELP_SHOW       = "  /avlreput |cffffff00show|r  — opens the view",
    DBG_HELP_SCAN       = "  /avlreput |cffffff00scan|r  — forces a scan",
    DBG_LOADED          = "Reputations plugin loaded.",
    CHAR_SWITCH_TT      = "Switch character",

    -- Addon Compartment (minimap menu)
    AC_TITLE            = "|cffa040ffAltViewerLog|r |cffffffff— Reputations|r",
    AC_CHAR_REPUT_COUNT = "%s — %d reputations",
    AC_CLICK_HINT       = "Click: Open reputations",
}
