local addonName, pluginNs = ...

-- ====================================================
-- TRADUCTIONS ANGLAISES
-- ====================================================
pluginNs.locales["enUS"] = {
    BTN_GUILDE          = "Guild Bank",
    GUILDE_TITLE        = "Guild Bank",
    GUILDS_HEADING      = "Guilds",
    NO_DATA             = "No chest scanned yet.\nOpen the guild bank to scan.",
    NO_GUILD            = "You are not in a guild.",
    TAB_LABEL           = "Tab %d",
    OTHER_TABS_HEADER   = "Other tabs",
    GUILD_NAME_LABEL    = "Guild: %s",
    GUILD_LEADER_LABEL  = "Leader: %s",
    SCAN_DATE           = "Last update: %s",
    NEVER_SCANNED       = "Never scanned",
    SETTINGS_TITLE      = "OBSOLETE",   -- managed by ViewerLog
    SETTINGS_DESC       = "OBSOLETE",   -- managed by ViewerLog
    CHAR_LABEL          = "Char: %s (%s)",
    ITEMS_COUNT         = "(%d items)",

    -- Errors / debug / slash
    ERR_API_MISSING     = "ERROR: AltViewerLogAPI not found.",
    DBG_SCAN_STARTED    = "Guild bank scan started.",
    DBG_HELP            = "|cffffff00/avlguilde scan|r  |cffffff00/avlguilde show|r",
    DBG_LOADED          = "Guild Bank plugin loaded.",

    -- Addon Compartment (minimap menu)
    AC_TITLE            = "|cff00aaffAltViewerLog|r |cffffffff— Guild|r",
    AC_CLICK_HINT       = "Click: Open guild bank",
    AC_NO_CHEST_SCANNED = "No chest scanned",
}
