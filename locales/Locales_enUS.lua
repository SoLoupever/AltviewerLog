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
    REALM_CHAR_COUNT = "%d characters saved",
    CHAR_LEVEL       = "Lvl %d",
    CHAR_ILVL        = "ilvl %d",
    PLAYED_LABEL     = "Time played: %s",
    GEAR_TITLE       = "Gear & Equipment",
    TIME_AGO_DH      = "%dd %dh ago",
    TIME_AGO_HM      = "%dh %dm ago",
    TIME_AGO_M       = "%dm ago",
    TIME_DH          = "%dd %dh",
    TIME_HM          = "%dh %dm",
    TIME_M           = "%dm",

    SETTINGS_TITLE   = "Settings and Management",
    SORT_POP         = "Show most populated realms at the top",
    LANG_TITLE       = "Addon Language:",
    THEME_TITLE              = "Interface Theme:",
    EXPANSION_FILTER_TITLE   = "Expansion Display",
    EXPANSION_FILTER_TOOLTIP = "Show / hide expansions",
    EXPANSION_SHOW_ALL       = "Show all",
    EXPANSION_HIDE_ALL       = "Hide all",
    EXPANSION_CLOSE          = "Close",
    TOTAL_GOLD        = "Total gold:",
    TOTAL_TIME        = "Total time played:",
    TOTAL_CHARS       = "Total characters:",
    RELOAD_REQUIRED  = "UI reload required",

    -- Sidebar tabs
    STATS_TITLE      = "Statistics: Playtime per Class (All Realms)",
    BTN_SETTINGS     = "Settings",
    BTN_CHARS        = "Characters",
    BTN_WARBAND      = "Warband",
    BTN_PROFESSIONS  = "Professions",
    BTN_GRAPH        = "Graph",
    BTN_SEARCH       = "Search",
    BTN_DISCORD      = "Discord",
    OWNED_BY         = "Owned by:",
    WARBAND_TITLE    = "Warband Bank",
    GUILD_BANK_TITLE = "Guild Bank",
    TOOLTIP_BAG      = "Bag",
    TOOLTIP_BANK     = "Bank",
    TOOLTIP_TOTAL    = "Total",

    -- Character list
    REALM_TITLE      = "Realm: ",
    REALM_MOVE_UP    = "Move realm up",
    REALM_MOVE_DOWN  = "Move realm down",
    REALM_COLLAPSE   = "Collapse this realm",
    REALM_EXPAND     = "Expand this realm",
    ONLINE           = "Online",
    RESTED_XP        = "Rested",
    NO_DATA          = "No data available",
    CHAR_SEARCH_PLACEHOLDER = "Search a character...",
    CHAR_SEARCH_NONE        = "No character matches.",

    -- Bottom bar
    ACCOUNT_TOTAL    = "Account Total",
    TOTAL_TIME_LABEL = "Total Time",
    CHARS_COUNT      = "Chars",

    -- Search & Bags
    NO_RESULTS       = "No items found.",
    SEARCH_TEXT      = "Search...",
    SEARCH_RESULTS   = "results",
    BAG_NAME         = "Bag %d",
    BAG_REAGENT      = "Reagent Bag",
    BANK_MAIN        = "Main Bank",
    BANK_REAGENT     = "Reagent Bank",
    BANK_BAG         = "Bank Bag %d",
    SECTION_INVENTORY= "Inventory",
    SECTION_BANK     = "Bank",

    -- Misc
    TIME_FORMAT      = "%dd %dh %dm",
    TOTAL_TIME       = "Total time: ",
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
    BANK_INLINE_MODE  = "Open the bank inside the window (like the warband bank) instead of a separate window",
    DEBUG_MODE        = "Debug mode — show internal messages in chat",
    DISABLE_2D_PREVIEW= "Show 2D preview for housing items (uncheck to disable)",
    -- Bank
    BTN_BANK          = "Bank",
    BANK_WIN_TITLE    = "Bank — %s",
    BANK_NO_DATA      = "No bank data.\nVisit a banker to scan.",
    CHAR_SWITCH_TT    = "Switch character",
    -- Bag view by category
    BAG_VIEW_TITLE    = "Inventory of %s",
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
    FILTER_ALL         = "All",
    FILTER_HEAD        = "Head (slot)",
    FILTER_CLOAK       = "Back (Cloak)",
    FILTER_CONSUMABLE  = "Consumable",
    FILTER_WEAPON      = "Weapon",
    FILTER_ARMOR       = "Armor",
    FILTER_CLOTH       = "Cloth",
    FILTER_LEATHER     = "Leather",
    FILTER_MAIL        = "Mail",
    FILTER_PLATE       = "Plate",
    FILTER_QUEST       = "Quest",
    FILTER_REAGENT     = "Reagent",
    -- Professions plugin filter window
    PROF_FILTER_TITLE  = "Profession Filter",
    PROF_FILTER_TT     = "Show / hide professions",
    MOVE_HERE        = "Move here",
    -- Stuff & Gear
    BTN_GEAR         = "Gear",
    GEAR_SUBTITLE    = "Character Equipment",
    GEAR_NO_DATA     = "No equipment scanned yet.\nOpen the addon in-game to scan.",
    -- Slots
    GEAR_SLOT_1      = "Head",
    GEAR_SLOT_2      = "Neck",
    GEAR_SLOT_3      = "Shoulders",
    GEAR_SLOT_5      = "Chest",
    GEAR_SLOT_6      = "Waist",
    GEAR_SLOT_7      = "Legs",
    GEAR_SLOT_8      = "Feet",
    GEAR_SLOT_9      = "Wrists",
    GEAR_SLOT_10     = "Hands",
    GEAR_SLOT_11     = "Ring 1",
    GEAR_SLOT_12     = "Ring 2",
    GEAR_SLOT_13     = "Trinket 1",
    GEAR_SLOT_14     = "Trinket 2",
    GEAR_SLOT_15     = "Back",
    GEAR_SLOT_16     = "Main Hand",
    GEAR_SLOT_17     = "Off Hand",

    -- Gear view (status messages)
    GEAR_NO_CHAR_DATA = "No data. Log in on this character.",
    GEAR_NOT_SCANNED  = "Equipment not scanned yet.\nLog back in on this character to scan it.",

    -- Warband Bank / Characters (status messages)
    WARBAND_NO_DATA  = "No data — make sure ViewerLog is active.",
    CHARS_NO_DATA    = "No inventory data found.\nMake sure |cff00ff00ViewerLog|r|cffff9900 is active.",

    -- Misc tooltips
    TT_CATEGORY_ORDER  = "Category order",
    TT_WARBAND_NO_GOLD = "Open the warband bank to load the gold",

    -- Minimap icon
    MINIMAP_SUBTITLE  = "Inventory Log",
    MINIMAP_CLICK     = "Left-click: Open / Close",

    -- /av slash commands
    SLASH_GOLD_DBG_MISSING  = "[AVL] ns.DumpGoldDebug not available (is Debug.lua loaded?)",
    SLASH_VLDB_MISSING      = "[AVL] ViewerLogDB not found — is ViewerLog active?",
    SLASH_META_HEADER       = "AltViewerLog — /av meta dump:",
    SLASH_DEBUG_BAGS        = "AltViewerLog Debug — Bags:",
    SLASH_DEBUG_BAG_LINE    = "  Bag |cffffd700%d|r: %d slots / %d items",
    SLASH_DEBUG_GOLD_LINE   = "Warband Gold — live:|r %s   |cffff9900saved:|r %s",
    SLASH_DEBUG_BANK_CLOSED = "nil (bank not open)",
    SLASH_DEBUG_GOLD_REPORT = "→ Full gold report: /av gold",

    -- Events (ViewerLog missing warnings)
    EVENTS_VL_MISSING_1 = "[AltViewerLog]|r ViewerLog not found — the inventory will not be displayed.",
    EVENTS_VL_MISSING_2 = "[AltViewerLog]|r Make sure ViewerLog is enabled.",

    -- DataProvider status
    STATUS_VL_ACTIVE  = "ViewerLog active",
    STATUS_VL_MISSING = "ViewerLog not found",
    STATUS_VL_OUTDATED = "ViewerLog incompatible (update required)",

    -- Gold debug dump (/bv gold)
    DBG_GOLD_HEADER      = "|cffd4af37[AVL] Gold Debug — %s|r  Legend: |cff55ff55[LIVE]|r=online  |cffffd700[SAVE]|r=saved  |cff888888[ZERO]|r=0g  |cffff4444[NIL]|r=never scanned",
    DBG_DB_NOT_FOUND     = "|cffff4444  [ERROR] ViewerLogDB not found — is ViewerLog active?|r",
    DBG_CHARS_HEADER     = "|cffcccccc  CHARACTERS (%d)|r",
    DBG_NEVER_SCANNED    = "|cffff4444never scanned|r",
    DBG_DB_UPDATE_NOTE   = " |cffff9900← DB=%s (will update)|r",
    DBG_CHAR_SUBTOTAL    = "  %s Character subtotal: %s  |cff888888(%d character(s) with data)|r",
    DBG_WARBAND_HEADER   = "|cffcccccc  WARBAND BANK|r",
    DBG_RETURNS_NIL      = "|cff888888returns nil|r",
    DBG_BANK_UNAVAILABLE = "|cffff4444C_Bank unavailable|r",
    DBG_NEVER_PERSISTED  = "|cffff4444nil — never persisted|r",
    DBG_REL_OPEN_LIVE      = "|cff55ff55✔ Bank OPEN — exact live value|r",
    DBG_REL_OPENED_SESSION = "|cffffd700✔ Opened this session — reliable|r",
    DBG_REL_API_POSITIVE   = "|cffffd700~ Positive API outside session — probably reliable|r",
    DBG_REL_NEVER_OPENED   = "|cffff9900⚠ Never opened this session — value may be stale|r",
    DBG_RELIABILITY_LINE   = "  |cffcccccc[INFO]    |r Reliability                → %s",
    DBG_TOTAL_RETAINED     = "  %s Value used for total      : %s",
    DBG_GRAND_TOTAL        = "  |cffd4af37GRAND TOTAL|r  (chars + warband)  →  %s",
    DBG_APPROX_GOLD        = "  |cff888888approx. %d gold rounded|r",
    DBG_NIL_VALUE          = "|cffff4444nil|r",
    DBG_NEGATIVE_SUFFIX    = " (negative?)",
    GOLD_ABBR    = "g",
    SILVER_ABBR  = "s",
    COPPER_ABBR  = "c",

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
