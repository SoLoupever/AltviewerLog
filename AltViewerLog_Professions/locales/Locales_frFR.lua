local addonName, pluginNs = ...

pluginNs.locales = {}

-- ====================================================
-- TRADUCTIONS FRANÇAISES
-- ====================================================
pluginNs.locales["frFR"] = {
    BTN_PROFESSIONS      = "Métiers",
    PROFESSIONS_TITLE    = "Métiers",

    -- Erreurs / debug / slash
    ERR_API_MISSING      = "ERREUR : AltViewerLogAPI introuvable.",
    DBG_LOADED           = "Plugin Métiers chargé.",
    DBG_HELP             = "|cffffff00/avlprof scan|r  |cffffff00/avlprof show|r",

    -- Scanner
    DBG_PROF_REMOVED        = "Métier(s) retiré(s) : %s",
    DBG_PROF_SAVED_BASIC    = "%s sauvegardé (basique) : %d/%d",
    DBG_PROF_SCANNED        = "%s scanné : %s",
    DBG_FULL_SCAN_DONE      = "Scan complet terminé.",
    DBG_SCAN_IN_PROGRESS    = "Scan déjà en cours...",
    DBG_NO_PROFESSION_FOUND = "Aucun métier trouvé.",
    DBG_SCAN_START          = "Début du scan (%d métier(s))...",
    DBG_FIRST_SCAN          = "Premier scan des métiers...",
    DBG_PROGRESS_RESCAN     = "Progression détectée — rescan de %d métier(s)...",
    DBG_PASSIVE_SCAN        = "Scan passif : %s",
    DBG_WARBAND_SCANNED     = "Banque de bataillon scannée.",

    -- Tooltips
    TT_WARBAND_SCAN_HINT = "Ouvrez la banque de bataillon pour scanner.",
    WOOD_PANEL_HIDE = "Cliquez pour masquer la barre de bois",
    WOOD_PANEL_SHOW = "Cliquez pour afficher la barre de bois",

    -- Barre "Recettes" (ui/RecipesBar.lua — dépend de ViewerLog_Recette,
    -- invisible si cette dépendance n'est pas active)

    -- Barre Housing (données fournies par ViewerLog_Housing)
    HOUSING_LABEL         = "Housing %d / %d",
    HOUSING_FOLD          = "Replier",
    HOUSING_UNFOLD        = "Déplier",
    HOUSING_KNOWN         = "%d / %d connues",
    HOUSING_SECTION_LABEL = "Recettes %s",
    RBAR_LABEL   = "Recettes %d / %d",
    RBAR_NO_DATA = "Aucune donnée — ouvrez ce métier une fois",
    RBAR_TOOLTIP = "%d / %d recettes connues",
    RBAR_FOLD    = "Replier",
    RBAR_UNFOLD  = "Déplier",
    RBAR_OTHER   = "Autres",

    -- Recherche de recette (ui/View.lua + ui/RecipesBar.lua)
    RECIPE_SEARCH_PLACEHOLDER = "Rechercher une recette...",

    -- Barre de chargement de la grille de recettes (ui/RecipesBar.lua)
    RBAR_LOADING = "Chargement des recettes…",
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
    return t[key] or ("[PROF:" .. key .. "]")
end
