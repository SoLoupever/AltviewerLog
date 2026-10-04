local addonName, pluginNs = ...

pluginNs.locales = {}

-- ====================================================
-- TRADUCTIONS FRANÇAISES (frFR)
-- ====================================================
pluginNs.locales["frFR"] = {
    BTN_GRAPH   = "Graphique",
    STATS_TITLE = "Statistiques : Temps de jeu par Classe (Tous Serveurs)",
    NO_DATA     = "Aucune donnée disponible",
    STATS_HEADING = "Statistiques",
    STATS_SUB = "Temps de jeu par classe",
    ALL_REALMS = "Tous serveurs",
    STAT_TOTAL_TIME = "Temps total",
    STAT_TOP_CLASS = "Classe la plus jouée",
    STAT_CHARS = "Personnages",

    -- Erreurs / debug
    ERR_API_MISSING = "ERREUR : AltViewerLogAPI introuvable.",
    DBG_LOADED      = "Plugin Graphique chargé.",

    -- Classes
    CLASS_WARRIOR     = "Guerrier",
    CLASS_PALADIN     = "Paladin",
    CLASS_HUNTER      = "Chasseur",
    CLASS_ROGUE       = "Voleur",
    CLASS_PRIEST      = "Prêtre",
    CLASS_DEATHKNIGHT = "Chevalier de la mort",
    CLASS_SHAMAN      = "Chaman",
    CLASS_MAGE        = "Mage",
    CLASS_WARLOCK     = "Démoniste",
    CLASS_MONK        = "Moine",
    CLASS_DRUID       = "Druide",
    CLASS_DEMONHUNTER = "Chasseur de démons",
    CLASS_EVOKER      = "Évocateur",
}

-- ====================================================
-- FONCTION DE TRADUCTION
-- ====================================================
function pluginNs.L(key)
    local lang = (AltViewerLogDB and AltViewerLogDB.settings and AltViewerLogDB.settings.lang)
                 or GetLocale()
    local t = pluginNs.locales[lang] or pluginNs.locales["enUS"] or pluginNs.locales["frFR"]
    return t[key] or key
end
