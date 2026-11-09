local _, ns = ...

ns.locales = {}

-- ====================================================
-- TRADUCTIONS FRANÇAISES (frFR)
-- ====================================================
ns.locales["frFR"] = {
    -- Paramètres & gestion
    -- Interface / thèmes
    UI_TITLE         = "ALTVIEWERLOG",
    UI_AUTHOR        = "By Soloup_ever",
    LANG_NAME_FR     = "Français",
    LANG_NAME_EN     = "English",
    THEME_NAME_AVL      = "AltViewerLog",
    THEME_NAME_BLIZZARD = "Blizzard",

    SETTINGS_TITLE   = "Paramètres et Gestion",
    LANG_TITLE       = "Langue de l'addon :",
    THEME_TITLE              = "Thème de l'interface :",
    EXPANSION_FILTER_TITLE   = "Affichage des extensions",
    EXPANSION_FILTER_TOOLTIP = "Afficher / masquer les extensions",
    EXPANSION_SHOW_ALL       = "Tout afficher",
    EXPANSION_HIDE_ALL       = "Tout masquer",
    EXPANSION_CLOSE          = "Fermer",
    RELOAD_REQUIRED  = "Rechargement de l'interface requis",

    -- Onglets sidebar
    STATS_TITLE      = "Statistiques : Temps de jeu par Classe (Tous Serveurs)",
    BTN_SETTINGS     = "Paramètres",
    BTN_PROFESSIONS  = "Métiers",
    BTN_GRAPH        = "Graphique",
    BTN_DISCORD      = "Discord",
    OWNED_BY         = "Possédé par :",
    GUILD_BANK_TITLE = "Banque de Guilde",
    TOOLTIP_BAG      = "Sac",
    TOOLTIP_BANK     = "Banque",
    TOOLTIP_TOTAL    = "Total",

    -- Vue personnages
    REALM_TITLE      = "Serveur : ",
    NO_DATA          = "Aucune donnée disponible",

    -- Barre du bas
    ACCOUNT_TOTAL    = "Total Compte",
    TOTAL_TIME_LABEL = "Temps total",
    CHARS_COUNT      = "Persos",

    -- Recherche et Sacs
    SECTION_INVENTORY= "Inventaire",

    -- Divers
    TIME_FORMAT      = "%d j %d h %d m",
    CLASS_WARRIOR    = "Guerrier",
    CLASS_PALADIN    = "Paladin",
    CLASS_HUNTER     = "Chasseur",
    CLASS_ROGUE      = "Voleur",
    CLASS_PRIEST     = "Prêtre",
    CLASS_DEATHKNIGHT= "Chevalier de la mort",
    CLASS_SHAMAN     = "Chaman",
    CLASS_MAGE       = "Mage",
    CLASS_WARLOCK    = "Démoniste",
    CLASS_MONK       = "Moine",
    CLASS_DRUID      = "Druide",
    CLASS_DEMONHUNTER= "Chasseur de démons",
    CLASS_EVOKER     = "Évocateur",

    -- Plugin Métiers
    SCAN_BTN          = "Scanner mes métiers",
    NO_CHARS          = "Aucun personnage trouvé.",
    LEVEL_SHORT       = "Niv. ",
    ADD_TIER          = "Ajouter une extension",
    SECTION_MAIN      = "Principaux",
    SECTION_SECONDARY = "Secondaires",
    RECIPES_LABEL     = "Recettes  |cff888888%d / %d|r",
    RECIPES_FOLD      = "Replier les recettes",
    RECIPES_UNFOLD    = "Déplier les recettes",
    RECIPES_KNOWN     = "%d/%d recettes apprises",
    RECIPES_ALT_CLICK = "Alt+Clic pour basculer manuellement",
    RECIPE_KNOWN_TT   = "|cff00cc33\xE2\x9C\x93 Recette apprise|r",
    RECIPE_UNKNOWN_TT = "|cffcc3333\xE2\x9C\x97 Recette non apprise|r",
    RECIPE_TOGGLE_TT  = "|cff666666Alt + Clic gauche pour basculer|r",
    POPUP_ADD         = "Ajouter une extension",
    POPUP_EDIT        = "Modifier \xe2\x80\x94 %s",
    POPUP_ADD_PROF    = "Ajouter \xe2\x80\x94 %s",
    POPUP_EXT_LABEL   = "Extension :",
    POPUP_LEVEL       = "Niveau actuel :",
    POPUP_MAX         = "Maximum :",
    POPUP_PREVIEW     = "Aperçu :",
    POPUP_CONFIRM     = "Confirmer",
    POPUP_CANCEL      = "Annuler",
    -- Paramètres
    VL_OPEN_SETTINGS  = "Ouvrir les paramètres ViewerLog",
    VL_SECTION_DESC   = "Les infobulles, personnages et guildes se gèrent dans ViewerLog.",
    CAT_MODE          = "Afficher les sacs par catégorie d'item (au lieu de sac par sac)",
    DEBUG_MODE        = "Mode debug — afficher les messages internes dans le chat",
    DISABLE_2D_PREVIEW= "Afficher l'aperçu 2D des objets de housing (décocher pour désactiver)",
    -- Banque
    BANK_WIN_TITLE    = "Banque — %s",
    CHAR_SWITCH_TT    = "Changer de personnage",
    CHAR_SEL_SEARCH_PH = "Rechercher un perso...",
    CHAR_SEL_ALL_REALMS = "Tous les serveurs",
    CHAR_SEL_NO_RESULT = "Aucun personnage",
    -- Vue sacs par catégorie
    CAT_ARMURE        = "Armure",
    CAT_ARME          = "Arme",
    CAT_CONSOMMABLE   = "Consommable",
    CAT_COMPOSANT     = "Composants d'artisanat",
    CAT_MATERIAUX     = "Matériaux",
    CAT_RECETTE       = "Recettes",
    CAT_HOUSING       = "Housing",
    CAT_QUETE         = "Quête",
    CAT_AUTRE         = "Autre",

    -- Catégories d'objets Blizzard, traduites selon la langue de l'addon
    -- (utilisées quand elle diffère de celle du client ; sinon l'API WoW
    -- fait foi). Clés stables par classID / sous-classe. Non couvert →
    -- repli sur la chaîne de l'API.
    ICAT_0  = "Consommable",
    ICAT_1  = "Conteneur",
    ICAT_2  = "Arme",
    ICAT_3  = "Gemme",
    ICAT_4  = "Armure",
    ICAT_5  = "Composant",
    ICAT_7  = "Artisanat",
    ICAT_8  = "Amélioration d'objet",
    ICAT_9  = "Recette",
    ICAT_12 = "Quête",
    ICAT_13 = "Clé",
    ICAT_15 = "Divers",
    ICAT_16 = "Glyphe",
    ICAT_19 = "Métier",
    ICATSUB_4_1 = "Tissu",
    ICATSUB_4_2 = "Cuir",
    ICATSUB_4_3 = "Mailles",
    ICATSUB_4_4 = "Plaques",
    ICATSUB_4_5 = "Cosmétique",
    ICATSUB_4_6 = "Bouclier",
    CAT_ADD           = "Ajouter une catégorie",
    CAT_ADD_TITLE     = "Nom de la nouvelle catégorie :",
    CAT_ASSIGN        = "Assigner à :",
    CAT_REMOVE_ASSIGN = "Retirer de la catégorie",

    -- Gestion des catégories (fenêtre « Ordre des catégories ») + drag & drop
    CATMGR_TITLE         = "Gestion des catégories",
    CATMGR_HINT          = "Glissez une ligne ou utilisez les flèches pour réordonner",
    CATMGR_MOVE_UP       = "Monter",
    CATMGR_MOVE_DOWN     = "Descendre",
    CATMGR_DELETE        = "Supprimer la catégorie",
    CATMGR_NEW_NAME      = "Nouvelle catégorie :",
    CATMGR_ADD_BTN       = "Ajouter",
    CATMGR_ERR_EMPTY     = "Le nom ne peut pas être vide.",
    CATMGR_ERR_EXISTS    = "Cette catégorie existe déjà.",
    CATMGR_SELECT_HINT   = "Sélectionnez une catégorie pour gérer ses objets",
    CATMGR_ITEMS_OF      = "Objets assignés à %s",
    CATMGR_MORE          = "+%d autres",
    CATMGR_ITEM_REMOVE_TT = "Clic : retirer de la catégorie",
    CATMGR_ITEM_ID       = "ID d'objet :",
    CATMGR_ITEM_ADD      = "Ajouter l'objet",
    CATMGR_ERR_NO_SEL    = "Sélectionnez d'abord une catégorie.",
    CATMGR_ERR_BAD_ITEM  = "ID d'objet invalide.",
    CATDND_PLUS_TT       = "Déposez un objet ici pour l'ajouter à cette catégorie",

    -- Tracker de Bois (plugin Métiers)
    WOOD_PANEL_HIDE       = "Cliquez pour masquer la barre de bois",
    WOOD_PANEL_SHOW       = "Cliquez pour afficher la barre de bois",
    WOOD_TITLE           = "Bois",
    WOOD_BANK_TITLE      = "Bois — banque de bataillon",
    WOOD_ITEM_245586     = "Bois de bois-de-fer",
    WOOD_ITEM_242691     = "Bois d'olemba",
    WOOD_ITEM_251762     = "Bois de Vent-froid",
    WOOD_ITEM_251764     = "Bois de fr\xc3\xaane",
    WOOD_ITEM_251763     = "Bois de bambou",
    WOOD_ITEM_251766     = "Bois d'Ombrelune",
    WOOD_ITEM_251767     = "Bois touch\xc3\xa9 par la corruption",
    WOOD_ITEM_251768     = "Bois de sombrepin",
    WOOD_ITEM_251772     = "Bois d'Arden",
    WOOD_ITEM_251773     = "Bois de pin-des-dragons",
    WOOD_ITEM_256963     = "Bois thalass\xc3\xa9en",

    -- Filtres de recherche
    WARBAND_SCAN_TIP   = "Ouvrez la banque de bataillon pour scanner.",
    -- Fenêtre filtre métiers (plugin Professions)
    PROF_FILTER_TITLE  = "Filtre des métiers",
    PROF_FILTER_TT     = "Afficher / masquer des métiers",
    MOVE_HERE        = "Déplacer ici",
    -- Stuff & Gear
    GEAR_NO_DATA     = "Aucun équipement scanné.\nOuvrez l'addon en jeu pour scanner.",

    -- Tooltips divers
    TT_CATEGORY_ORDER  = "Ordre des catégories",

    -- Icône minimap
    MINIMAP_SUBTITLE  = "Journal d'inventaire",
    MINIMAP_CLICK     = "Clic gauche : Ouvrir / Fermer",

    -- Commandes slash /bv
    SLASH_VLDB_MISSING      = "[AVL] ViewerLogDB introuvable — ViewerLog est-il actif ?",
    SLASH_META_HEADER       = "AltViewerLog — /av meta dump :",

    -- Événements (avertissements ViewerLog manquant)
    EVENTS_VL_MISSING_1 = "[AltViewerLog]|r ViewerLog introuvable — l'inventaire ne sera pas affiché.",
    EVENTS_VL_MISSING_2 = "[AltViewerLog]|r Assurez-vous que ViewerLog est activé.",

    -- Statut DataProvider
    STATUS_VL_ACTIVE  = "ViewerLog actif",
    STATUS_VL_MISSING = "ViewerLog introuvable",
    STATUS_VL_OUTDATED = "ViewerLog incompatible (mise à jour requise)",

    -- Discord
    DISCORD_HINT  = "Sélectionne tout (Ctrl+A) puis copie (Ctrl+C).",

    -- Bois (plugin Professions — WoodTracker)
    WOOD_ITEM_245586 = "Bois de bois-de-fer",
    WOOD_ITEM_242691 = "Bois d'olemba",
    WOOD_ITEM_251762 = "Bois de Vent-froid",
    WOOD_ITEM_251764 = "Bois de frêne",
    WOOD_ITEM_251763 = "Bois de bambou",
    WOOD_ITEM_251766 = "Bois d'Ombrelune",
    WOOD_ITEM_251767 = "Bois touché par la corruption",
    WOOD_ITEM_251768 = "Bois de sombrepin",
    WOOD_ITEM_251772 = "Bois d'Arden",
    WOOD_ITEM_251773 = "Bois de pin-des-dragons",
    WOOD_ITEM_256963 = "Bois thalasséen",
}

-- ====================================================
-- FONCTION DE TRADUCTION
-- ====================================================
-- GetLocale() est immuable pendant une session : on le cache au chargement.
local _cachedLocale = GetLocale()

-- Langue active : réglage de l'addon, sinon langue du client si supportée.
function ns.GetLang()
    if AltViewerLogDB and AltViewerLogDB.settings and AltViewerLogDB.settings.lang then
        return AltViewerLogDB.settings.lang
    elseif ns.locales[_cachedLocale] then
        return _cachedLocale
    end
    return "frFR"
end

function ns.L(key)
    local tableLangue = ns.locales[ns.GetLang()] or ns.locales["frFR"]
    return tableLangue[key] or key
end
