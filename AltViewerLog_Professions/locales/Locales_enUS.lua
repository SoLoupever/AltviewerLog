local addonName, pluginNs = ...

-- ====================================================
-- TRADUCTIONS ANGLAISES
-- ====================================================
pluginNs.locales["enUS"] = {
    BTN_PROFESSIONS      = "Professions",
    PROFESSIONS_TITLE    = "Professions",

    -- Errors / debug / slash
    ERR_API_MISSING      = "ERROR: AltViewerLogAPI not found.",
    DBG_LOADED           = "Professions plugin loaded.",
    DBG_HELP             = "|cffffff00/avlprof scan|r  |cffffff00/avlprof show|r",

    -- Scanner
    DBG_PROF_REMOVED        = "Profession(s) removed: %s",
    DBG_PROF_SAVED_BASIC    = "%s saved (basic): %d/%d",
    DBG_PROF_SCANNED        = "%s scanned: %s",
    DBG_FULL_SCAN_DONE      = "Full scan complete.",
    DBG_SCAN_IN_PROGRESS    = "Scan already in progress...",
    DBG_NO_PROFESSION_FOUND = "No profession found.",
    DBG_SCAN_START          = "Starting scan (%d profession(s))...",
    DBG_FIRST_SCAN          = "First profession scan...",
    DBG_PROGRESS_RESCAN     = "Progress detected — rescanning %d profession(s)...",
    DBG_PASSIVE_SCAN        = "Passive scan: %s",
    DBG_WARBAND_SCANNED     = "Warband bank scanned.",

    -- Tooltips
    TT_WARBAND_SCAN_HINT = "Open the Warband Bank to scan.",
    WOOD_PANEL_HIDE = "Click to hide the wood bar",
    WOOD_PANEL_SHOW = "Click to show the wood bar",

    -- "Recipes" bar (ui/RecipesBar.lua — depends on ViewerLog_Recette,
    -- invisible if that dependency isn't active)

    -- Housing bar (data provided by ViewerLog_Housing)
    HOUSING_LABEL         = "Housing %d / %d",
    HOUSING_FOLD          = "Collapse",
    HOUSING_UNFOLD        = "Expand",
    HOUSING_KNOWN         = "%d / %d known",
    HOUSING_SECTION_LABEL = "Recipes %s",
    RBAR_LABEL   = "Recipes %d / %d",
    RBAR_NO_DATA = "No data yet — open this profession once",
    RBAR_TOOLTIP = "%d / %d known recipes",
    RBAR_FOLD    = "Collapse",
    RBAR_UNFOLD  = "Expand",
    RBAR_OTHER   = "Other",

    -- Recipe search (ui/View.lua + ui/RecipesBar.lua)
    RECIPE_SEARCH_PLACEHOLDER = "Search a recipe...",

    -- Recipe grid loading bar (ui/RecipesBar.lua)
    RBAR_LOADING = "Loading recipes…",
}
