local _, ns = ...

-- ====================================================
-- TRADUCTIONS ANGLAISES (enUS)
-- ====================================================
ns.locales["enUS"] = {
    -- Settings & management
    -- Interface / themes
    UI_TITLE         = "ALTVIEWERLOG",
    UI_AUTHOR        = "By Soloup_ever",
    LANG_NAME_FR     = "Français",
    LANG_NAME_EN     = "English",
    THEME_NAME_AVL      = "AltViewerLog",
    THEME_NAME_BLIZZARD = "Blizzard",

    SETTINGS_TITLE   = "Settings and Management",
    LANG_TITLE       = "Addon Language:",
    THEME_TITLE              = "Interface Theme:",
    EXPANSION_FILTER_TITLE   = "Expansion Display",
    EXPANSION_FILTER_TOOLTIP = "Show / hide expansions",
    EXPANSION_SHOW_ALL       = "Show all",
    EXPANSION_HIDE_ALL       = "Hide all",
    EXPANSION_CLOSE          = "Close",
    RELOAD_REQUIRED  = "UI reload required",

    -- Sidebar tabs
    STATS_TITLE      = "Statistics: Playtime per Class (All Realms)",
    BTN_SETTINGS     = "Settings",
    BTN_PROFESSIONS  = "Professions",
    BTN_GRAPH        = "Graph",
    BTN_DISCORD      = "Discord",
    OWNED_BY         = "Owned by:",
    GUILD_BANK_TITLE = "Guild Bank",
    TOOLTIP_BAG      = "Bag",
    TOOLTIP_BANK     = "Bank",
    TOOLTIP_TOTAL    = "Total",

    -- Character list
    REALM_TITLE      = "Realm: ",
    NO_DATA          = "No data available",

    -- Bottom bar
    ACCOUNT_TOTAL    = "Account Total",
    TOTAL_TIME_LABEL = "Total Time",
    CHARS_COUNT      = "Chars",

    -- Search & Bags
    SECTION_INVENTORY= "Inventory",

    -- Misc
    TIME_FORMAT      = "%dd %dh %dm",
    CLASS_WARRIOR    = "Warrior",
    CLASS_PALADIN    = "Paladin",
    CLASS_HUNTER     = "Hunter",
    CLASS_ROGUE      = "Rogue",
    CLASS_PRIEST     = "Priest",
    CLASS_DEATHKNIGHT= "Death Knight",
    CLASS_SHAMAN     = "Shaman",
    CLASS_MAGE       = "Mage",
    CLASS_WARLOCK    = "Warlock",
    CLASS_MONK       = "Monk",
    CLASS_DRUID      = "Druid",
    CLASS_DEMONHUNTER= "Demon Hunter",
    CLASS_EVOKER     = "Evoker",

    -- Professions plugin
    SCAN_BTN          = "Scan my professions",
    NO_CHARS          = "No characters found.",
    LEVEL_SHORT       = "Lvl. ",
    ADD_TIER          = "Add an expansion",
    SECTION_MAIN      = "Main",
    SECTION_SECONDARY = "Secondary",
    RECIPES_LABEL     = "Recipes  |cff888888%d / %d|r",
    RECIPES_FOLD      = "Collapse recipes",
    RECIPES_UNFOLD    = "Expand recipes",
    RECIPES_KNOWN     = "%d/%d recipes learned",
    RECIPES_ALT_CLICK = "Alt+Click to toggle manually",
    RECIPE_KNOWN_TT   = "|cff00cc33\xE2\x9C\x93 Recipe learned|r",
    RECIPE_UNKNOWN_TT = "|cffcc3333\xE2\x9C\x97 Recipe not learned|r",
    RECIPE_TOGGLE_TT  = "|cff666666Alt + Left click to toggle|r",
    POPUP_ADD         = "Add an expansion",
    POPUP_EDIT        = "Edit \xe2\x80\x94 %s",
    POPUP_ADD_PROF    = "Add \xe2\x80\x94 %s",
    POPUP_EXT_LABEL   = "Expansion:",
    POPUP_LEVEL       = "Current level:",
    POPUP_MAX         = "Maximum:",
    POPUP_PREVIEW     = "Preview:",
    POPUP_CONFIRM     = "Confirm",
    POPUP_CANCEL      = "Cancel",
    -- Settings
    VL_OPEN_SETTINGS  = "Open ViewerLog Settings",
    VL_SECTION_DESC   = "Tooltips, characters, and guilds are managed in ViewerLog.",
    CAT_MODE          = "Display bags by item category (instead of bag by bag)",
    DEBUG_MODE        = "Debug mode — show internal messages in chat",
    DISABLE_2D_PREVIEW= "Show 2D preview for housing items (uncheck to disable)",
    -- Bank
    BANK_WIN_TITLE    = "Bank — %s",
    CHAR_SWITCH_TT    = "Switch character",
    CHAR_SEL_SEARCH_PH = "Search a character...",
    CHAR_SEL_ALL_REALMS = "All realms",
    CHAR_SEL_NO_RESULT = "No character found",
    -- Bag view by category
    CAT_ARMURE        = "Armor",
    CAT_ARME          = "Weapon",
    CAT_CONSOMMABLE   = "Consumable",
    CAT_COMPOSANT     = "Crafting Components",
    CAT_MATERIAUX     = "Materials",
    CAT_RECETTE       = "Recipes",
    CAT_HOUSING       = "Housing",
    CAT_QUETE         = "Quest",
    CAT_AUTRE         = "Other",

    -- Blizzard item categories, translated to the addon language (used when
    -- it differs from the client; otherwise the WoW API string wins).
    -- Stable keys per classID / subclass. Not covered → API string fallback.
    ICAT_0  = "Consumable",
    ICAT_1  = "Container",
    ICAT_2  = "Weapon",
    ICAT_3  = "Gem",
    ICAT_4  = "Armor",
    ICAT_5  = "Reagent",
    ICAT_7  = "Trade Goods",
    ICAT_8  = "Item Enhancement",
    ICAT_9  = "Recipe",
    ICAT_12 = "Quest",
    ICAT_13 = "Key",
    ICAT_15 = "Miscellaneous",
    ICAT_16 = "Glyph",
    ICAT_19 = "Profession",
    ICATSUB_4_1 = "Cloth",
    ICATSUB_4_2 = "Leather",
    ICATSUB_4_3 = "Mail",
    ICATSUB_4_4 = "Plate",
    ICATSUB_4_5 = "Cosmetic",
    ICATSUB_4_6 = "Shield",
    CAT_ADD           = "Add a category",
    CAT_ADD_TITLE     = "New category name:",
    CAT_ASSIGN        = "Assign to:",
    CAT_REMOVE_ASSIGN = "Remove from category",

    -- Category management ("Category order" window) + drag & drop
    CATMGR_TITLE         = "Category management",
    CATMGR_HINT          = "Drag a row or use the arrows to reorder",
    CATMGR_MOVE_UP       = "Move up",
    CATMGR_MOVE_DOWN     = "Move down",
    CATMGR_DELETE        = "Delete category",
    CATMGR_NEW_NAME      = "New category:",
    CATMGR_ADD_BTN       = "Add",
    CATMGR_ERR_EMPTY     = "The name cannot be empty.",
    CATMGR_ERR_EXISTS    = "This category already exists.",
    CATMGR_SELECT_HINT   = "Select a category to manage its items",
    CATMGR_ITEMS_OF      = "Items assigned to %s",
    CATMGR_MORE          = "+%d more",
    CATMGR_ITEM_REMOVE_TT = "Click: remove from category",
    CATMGR_ITEM_ID       = "Item ID:",
    CATMGR_ITEM_ADD      = "Add item",
    CATMGR_ERR_NO_SEL    = "Select a category first.",
    CATMGR_ERR_BAD_ITEM  = "Invalid item ID.",
    CATDND_PLUS_TT       = "Drop an item here to add it to this category",

    -- Wood Tracker (Professions plugin)
    WOOD_PANEL_HIDE       = "Click to hide the wood bar",
    WOOD_PANEL_SHOW       = "Click to show the wood bar",
    WOOD_TITLE           = "Wood",
    WOOD_BANK_TITLE      = "Wood — Warband Bank",
    WOOD_ITEM_245586     = "Ironwood Lumber",
    WOOD_ITEM_242691     = "Olemba Wood",
    WOOD_ITEM_251762     = "Coldwind Lumber",
    WOOD_ITEM_251764     = "Ash Wood",
    WOOD_ITEM_251763     = "Bamboo Wood",
    WOOD_ITEM_251766     = "Shadowmoon Lumber",
    WOOD_ITEM_251767     = "Corruption-Touched Wood",
    WOOD_ITEM_251768     = "Somberwood Lumber",
    WOOD_ITEM_251772     = "Ardenwood",
    WOOD_ITEM_251773     = "Dragon's Tooth Lumber",
    WOOD_ITEM_256963     = "Thalassian Lumber",

    -- Search filters
    WARBAND_SCAN_TIP   = "Open the Warband Bank to scan.",
    -- Professions plugin filter window
    PROF_FILTER_TITLE  = "Profession Filter",
    PROF_FILTER_TT     = "Show / hide professions",
    MOVE_HERE        = "Move here",
    -- Stuff & Gear
    GEAR_NO_DATA     = "No equipment scanned yet.\nOpen the addon in-game to scan.",

    -- Misc tooltips
    TT_CATEGORY_ORDER  = "Category order",

    -- Minimap icon
    MINIMAP_SUBTITLE  = "Inventory Log",
    MINIMAP_CLICK     = "Left-click: Open / Close",

    -- /av slash commands
    SLASH_VLDB_MISSING      = "[AVL] ViewerLogDB not found — is ViewerLog active?",
    SLASH_META_HEADER       = "AltViewerLog — /av meta dump:",

    -- Events (ViewerLog missing warnings)
    EVENTS_VL_MISSING_1 = "[AltViewerLog]|r ViewerLog not found — the inventory will not be displayed.",
    EVENTS_VL_MISSING_2 = "[AltViewerLog]|r Make sure ViewerLog is enabled.",

    -- DataProvider status
    STATUS_VL_ACTIVE  = "ViewerLog active",
    STATUS_VL_MISSING = "ViewerLog not found",
    STATUS_VL_OUTDATED = "ViewerLog incompatible (update required)",

    -- Discord
    DISCORD_HINT  = "Select all (Ctrl+A) then copy (Ctrl+C).",

    -- Wood (Professions plugin — WoodTracker), named to match each expansion's theme
    WOOD_ITEM_245586 = "Ironwood Lumber",          -- Classic
    WOOD_ITEM_242691 = "Olemba Wood",              -- Burning Crusade (Outland)
    WOOD_ITEM_251762 = "Coldwind Wood",            -- Wrath of the Lich King
    WOOD_ITEM_251764 = "Ash Wood",                 -- Cataclysm
    WOOD_ITEM_251763 = "Bamboo Wood",              -- Mists of Pandaria
    WOOD_ITEM_251766 = "Shadowmoon Wood",          -- Warlords of Draenor
    WOOD_ITEM_251767 = "Corruption-Touched Wood",  -- Legion
    WOOD_ITEM_251768 = "Darkpine Wood",            -- Battle for Azeroth
    WOOD_ITEM_251772 = "Ardenweald Wood",          -- Shadowlands
    WOOD_ITEM_251773 = "Dragon Pine Wood",         -- Dragonflight
    WOOD_ITEM_256963 = "Thalassian Wood",          -- Midnight
}
