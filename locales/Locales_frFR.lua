local _, ns = ...

ns.locales = {}

-- ====================================================
-- TRADUCTIONS FRANÇAISES (frFR)
-- ====================================================
ns.locales["frFR"] = {
    -- Paramètres & gestion
    SETTINGS_TITLE   = "Paramètres et Gestion",
    SORT_POP         = "Afficher les serveurs les plus peuplés en haut",
    LANG_TITLE       = "Langue de l'addon :",
    THEME_TITLE              = "Thème de l'interface :",
    EXPANSION_FILTER_TITLE   = "Affichage des extensions",
    EXPANSION_FILTER_TOOLTIP = "Afficher / masquer les extensions",
    EXPANSION_SHOW_ALL       = "Tout afficher",
    EXPANSION_HIDE_ALL       = "Tout masquer",
    EXPANSION_CLOSE          = "Fermer",
    TOTAL_GOLD        = "Total or :",
    TOTAL_TIME        = "Total temps joué :",
    TOTAL_CHARS       = "Total personnages :",
    RELOAD_REQUIRED  = "Rechargement de l'interface requis",

    -- Onglets sidebar
    STATS_TITLE      = "Statistiques : Temps de jeu par Classe (Tous Serveurs)",
    BTN_SETTINGS     = "Paramètres",
    BTN_CHARS        = "Personnages",
    BTN_WARBAND      = "Bataillon",
    BTN_PROFESSIONS  = "Métiers",
    BTN_GRAPH        = "Graphique",
    BTN_SEARCH       = "Recherche",
    BTN_DISCORD      = "Discord",
    OWNED_BY         = "Possédé par :",
    WARBAND_TITLE    = "Banque de Bataillon",
    GUILD_BANK_TITLE = "Banque de Guilde",
    TOOLTIP_BAG      = "Sac",
    TOOLTIP_BANK     = "Banque",
    TOOLTIP_TOTAL    = "Total",

    -- Vue personnages
    REALM_TITLE      = "Serveur : ",
    REALM_MOVE_UP    = "Monter ce serveur",
    REALM_MOVE_DOWN  = "Descendre ce serveur",
    REALM_COLLAPSE   = "Replier ce serveur",
    REALM_EXPAND     = "Déplier ce serveur",
    ONLINE           = "En ligne",
    RESTED_XP        = "Repos",
    NO_DATA          = "Aucune donnée disponible",
    CHAR_SEARCH_PLACEHOLDER = "Rechercher un perso...",
    CHAR_SEARCH_NONE        = "Aucun personnage ne correspond.",

    -- Barre du bas
    ACCOUNT_TOTAL    = "Total Compte",
    TOTAL_TIME_LABEL = "Temps total",
    CHARS_COUNT      = "Persos",

    -- Recherche et Sacs
    NO_RESULTS       = "Aucun objet trouvé.",
    SEARCH_TEXT      = "Rechercher...",
    SEARCH_RESULTS   = "résultats",
    BAG_NAME         = "Sac %d",
    BAG_REAGENT      = "Sac de Composants",
    BANK_MAIN        = "Banque Principale",
    BANK_REAGENT     = "Banque de Composants",
    BANK_BAG         = "Sac de Banque %d",
    SECTION_INVENTORY= "Inventaire",
    SECTION_BANK     = "Banque",

    -- Divers
    TIME_FORMAT      = "%d j %d h %d m",
    TOTAL_TIME       = "Temps total : ",
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
    BANK_INLINE_MODE  = "Ouvrir la banque dans la fenêtre (comme la banque de bataillon) au lieu d'une fenêtre séparée",
    DEBUG_MODE        = "Mode debug — afficher les messages internes dans le chat",
    DISABLE_2D_PREVIEW= "Afficher l'aperçu 2D des objets de housing (décocher pour désactiver)",
    -- Banque
    BTN_BANK          = "Banque",
    BANK_WIN_TITLE    = "Banque — %s",
    BANK_NO_DATA      = "Aucune donnée de banque.\nVisite un banquier pour scanner.",
    CHAR_SWITCH_TT    = "Changer de personnage",
    -- Vue sacs par catégorie
    BAG_VIEW_TITLE    = "Inventaire de %s",
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
    FILTER_ALL         = "Tout",
    FILTER_HEAD        = "Tête (emplacement)",
    FILTER_CLOAK       = "Dos (Cape)",
    FILTER_CONSUMABLE  = "Consommable",
    FILTER_WEAPON      = "Arme",
    FILTER_ARMOR       = "Armure",
    FILTER_CLOTH       = "Tissu",
    FILTER_LEATHER     = "Cuir",
    FILTER_MAIL        = "Maille",
    FILTER_PLATE       = "Plaques",
    FILTER_QUEST       = "Quête",
    FILTER_REAGENT     = "Composant",
    -- Fenêtre filtre métiers (plugin Professions)
    PROF_FILTER_TITLE  = "Filtre des métiers",
    PROF_FILTER_TT     = "Afficher / masquer des métiers",
    MOVE_HERE        = "Déplacer ici",
    -- Stuff & Gear
    BTN_GEAR         = "Stuff",
    GEAR_SUBTITLE    = "Équipement du personnage",
    GEAR_NO_DATA     = "Aucun équipement scanné.\nOuvrez l'addon en jeu pour scanner.",
    -- Slots
    GEAR_SLOT_1      = "Tête",
    GEAR_SLOT_2      = "Cou",
    GEAR_SLOT_3      = "Épaules",
    GEAR_SLOT_5      = "Torse",
    GEAR_SLOT_6      = "Ceinture",
    GEAR_SLOT_7      = "Jambes",
    GEAR_SLOT_8      = "Pieds",
    GEAR_SLOT_9      = "Poignets",
    GEAR_SLOT_10     = "Mains",
    GEAR_SLOT_11     = "Bague 1",
    GEAR_SLOT_12     = "Bague 2",
    GEAR_SLOT_13     = "Bijou 1",
    GEAR_SLOT_14     = "Bijou 2",
    GEAR_SLOT_15     = "Dos",
    GEAR_SLOT_16     = "Main droite",
    GEAR_SLOT_17     = "Main gauche",

    -- Vue Stuff & Gear (messages d'état)
    GEAR_NO_CHAR_DATA = "Aucune donnée. Connectez-vous sur ce personnage.",
    GEAR_NOT_SCANNED  = "Équipement non encore scanné.\nReconnectez-vous sur ce personnage pour le scanner.",

    -- Banque de Bataillon / Personnages (messages d'état)
    WARBAND_NO_DATA  = "Aucune donnée — assurez-vous que ViewerLog est activé.",
    CHARS_NO_DATA    = "Aucune donnée d'inventaire.\nAssurez-vous que |cff00ff00ViewerLog|r|cffff9900 est activé.",

    -- Tooltips divers
    TT_CATEGORY_ORDER  = "Ordre des catégories",
    TT_WARBAND_NO_GOLD = "Ouvre la banque bataillon pour charger l'or",

    -- Icône minimap
    MINIMAP_SUBTITLE  = "Journal d'inventaire",
    MINIMAP_CLICK     = "Clic gauche : Ouvrir / Fermer",

    -- Commandes slash /bv
    SLASH_GOLD_DBG_MISSING  = "[AVL] ns.DumpGoldDebug non disponible (Debug.lua chargé ?)",
    SLASH_VLDB_MISSING      = "[AVL] ViewerLogDB introuvable — ViewerLog est-il actif ?",
    SLASH_META_HEADER       = "AltViewerLog — /av meta dump :",
    SLASH_DEBUG_BAGS        = "AltViewerLog Debug — Sacs :",
    SLASH_DEBUG_BAG_LINE    = "  Sac |cffffd700%d|r : %d emplacements / %d objets",
    SLASH_DEBUG_GOLD_LINE   = "Or Bataillon — live :|r %s   |cffff9900persisté :|r %s",
    SLASH_DEBUG_BANK_CLOSED = "nil (banque non ouverte)",
    SLASH_DEBUG_GOLD_REPORT = "→ Rapport or complet : /av gold",

    -- Événements (avertissements ViewerLog manquant)
    EVENTS_VL_MISSING_1 = "[AltViewerLog]|r ViewerLog introuvable — l'inventaire ne sera pas affiché.",
    EVENTS_VL_MISSING_2 = "[AltViewerLog]|r Assurez-vous que ViewerLog est activé.",

    -- Statut DataProvider
    STATUS_VL_ACTIVE  = "ViewerLog actif",
    STATUS_VL_MISSING = "ViewerLog introuvable",
    STATUS_VL_OUTDATED = "ViewerLog incompatible (mise à jour requise)",

    -- Dump de débogage de l'or (/bv gold)
    DBG_GOLD_HEADER      = "|cffd4af37[AVL] Débogage de l'or — %s|r  Légende : |cff55ff55[LIVE]|r=connecté  |cffffd700[SAVE]|r=sauvegardé  |cff888888[ZERO]|r=0g  |cffff4444[NIL]|r=jamais scanné",
    DBG_DB_NOT_FOUND     = "|cffff4444  [ERREUR] ViewerLogDB introuvable — ViewerLog est-il actif ?|r",
    DBG_CHARS_HEADER     = "|cffcccccc  PERSONNAGES (%d)|r",
    DBG_NEVER_SCANNED    = "|cffff4444jamais scanné|r",
    DBG_DB_UPDATE_NOTE   = " |cffff9900← DB=%s (sera mis à jour)|r",
    DBG_CHAR_SUBTOTAL    = "  %s Sous-total persos : %s  |cff888888(%d perso(s) avec données)|r",
    DBG_WARBAND_HEADER   = "|cffcccccc  BANQUE DE BATAILLON|r",
    DBG_RETURNS_NIL      = "|cff888888retourne nil|r",
    DBG_BANK_UNAVAILABLE = "|cffff4444C_Bank indisponible|r",
    DBG_NEVER_PERSISTED  = "|cffff4444nil — jamais persisté|r",
    DBG_REL_OPEN_LIVE      = "|cff55ff55✔ Banque OUVERTE — valeur live exacte|r",
    DBG_REL_OPENED_SESSION = "|cffffd700✔ Ouverte cette session — fiable|r",
    DBG_REL_API_POSITIVE   = "|cffffd700~ API positive hors session — probablement fiable|r",
    DBG_REL_NEVER_OPENED   = "|cffff9900⚠ Jamais ouverte cette session — valeur peut être ancienne|r",
    DBG_RELIABILITY_LINE   = "  |cffcccccc[INFO]    |r Fiabilité                 → %s",
    DBG_TOTAL_RETAINED     = "  %s Valeur retenue pour total  : %s",
    DBG_GRAND_TOTAL        = "  |cffd4af37GRAND TOTAL|r  (persos + bataillon)  →  %s",
    DBG_APPROX_GOLD        = "  |cff888888soit environ %d po en valeur arrondie|r",
    DBG_NIL_VALUE          = "|cffff4444nil|r",
    DBG_NEGATIVE_SUFFIX    = " (négatif ?)",
    GOLD_ABBR    = "po",
    SILVER_ABBR  = "pa",
    COPPER_ABBR  = "pc",

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

function ns.L(key)
    local currentLang = "frFR"
    if AltViewerLogDB and AltViewerLogDB.settings and AltViewerLogDB.settings.lang then
        currentLang = AltViewerLogDB.settings.lang
    elseif ns.locales[_cachedLocale] then
        currentLang = _cachedLocale
    end
    local tableLangue = ns.locales[currentLang] or ns.locales["frFR"]
    return tableLangue[key] or key
end
