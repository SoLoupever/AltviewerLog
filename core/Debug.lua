local addonName, ns = ...

-- ====================================================
-- CORE/DEBUG — Système de debug centralisé
-- Rôle UNIQUE : exposer ns.DBG() et AltViewerLogAPI.DBG
-- pour AltViewerLog et toutes ses dépendances.
--
-- Usage dans n'importe quel fichier (core ou dépendance) :
--   local ns = _G.AltViewerLogAPI
--   ns.DBG("[MON-ADDON] message ici")
--
-- Activé/désactivé depuis Paramètres > AltViewerLog.
-- Désactivé par défaut.
-- ====================================================

-- Lecture du flag (DB peut ne pas encore exister au load)
local function IsDebugOn()
    return AltViewerLogDB
        and AltViewerLogDB.settings
        and AltViewerLogDB.settings.debugMode == true
end

-- Point d'entrée unique pour tous les prints de debug.
-- Préfixe automatique |cff888888[AVL Debug]|r si pas déjà coloré.
function ns.DBG(msg)
    if not IsDebugOn() then return end
    local out = tostring(msg or "")
    if out:sub(1, 2) ~= "|c" then
        out = "|cff888888[AVL Debug]|r " .. out
    end
    print(out)
end

-- ====================================================
-- ns.DumpGoldDebug — Dump détaillé de l'or
-- ====================================================
-- Affiche dans le chat un rapport complet de l'or :
--   · chaque personnage (LIVE si connecté, SAVE si hors ligne,
--     ZERO si 0g enregistré, NIL si jamais scanné)
--   · banque de bataillon (valeur live API vs valeur DB sauvegardée,
--     indicateur de fiabilité)
--   · grand total
--
-- Accessible via /av gold (quel que soit l'état du mode debug).
-- ====================================================

-- Convertit des cuivres en chaîne colorée "X po Y pa Z pc" (texte pur,
-- sans texture, lisible dans n'importe quel canal de chat).
local function CopperToStr(copper)
    if not copper then return ns.L("DBG_NIL_VALUE") end
    copper = math.floor(copper)
    if copper < 0 then return "|cffff4444" .. copper .. ns.L("DBG_NEGATIVE_SUFFIX") .. "|r" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("|cffd4af37%d " .. ns.L("GOLD_ABBR") .. "|r |cffc0c0c0%d " .. ns.L("SILVER_ABBR") .. "|r |fffb6427%d " .. ns.L("COPPER_ABBR") .. "|r", g, s, c)
    elseif s > 0 then
        return string.format("|cffc0c0c0%d " .. ns.L("SILVER_ABBR") .. "|r |fffb6427%d " .. ns.L("COPPER_ABBR") .. "|r", s, c)
    else
        return string.format("|fffb6427%d " .. ns.L("COPPER_ABBR") .. "|r", c)
    end
end

-- Retourne la couleur de classe (#rrggbb) pour coloriser le nom du perso.
local function ClassHex(class)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then
        return string.format("%02x%02x%02x",
            math.floor((cc.r or 1) * 255),
            math.floor((cc.g or 1) * 255),
            math.floor((cc.b or 1) * 255))
    end
    return "aaaaaa"
end

function ns.DumpGoldDebug()
    local currentPlayer = UnitName("player")
    local currentRealm  = GetRealmName()
    local SEP = "|cff444444" .. string.rep("─", 52) .. "|r"

    print(SEP)
    print(string.format(ns.L("DBG_GOLD_HEADER"), date("%H:%M:%S")))
    print(SEP)

    -- ── Vérification DB ──────────────────────────────────────────────
    local vlDB  = ViewerLogDB
    local vlAPI = _G.ViewerLogAPI
    if not vlDB or not vlAPI then
        print(ns.L("DBG_DB_NOT_FOUND"))
        print(SEP)
        return
    end

    -- ── Collecte des personnages ──────────────────────────────────────
    local charList = {}
    for realmName, realmData in pairs(vlDB) do
        if vlAPI.IsRealm and vlAPI.IsRealm(realmName, realmData) then
            for charName, charData in pairs(realmData) do
                if type(charData) == "table" then
                    table.insert(charList, {
                        name  = charName,
                        realm = realmName,
                        class = charData.class,
                        gold  = charData.gold,  -- nil = jamais scanné
                    })
                end
            end
        end
    end

    -- Tri : perso connecté en premier, puis or décroissant, puis nom.
    table.sort(charList, function(a, b)
        local aLive = (a.name == currentPlayer and a.realm == currentRealm)
        local bLive = (b.name == currentPlayer and b.realm == currentRealm)
        if aLive ~= bLive then return aLive end
        return (a.gold or -1) > (b.gold or -1)
    end)

    -- ── Affichage ligne par ligne ─────────────────────────────────────
    print(string.format(ns.L("DBG_CHARS_HEADER"), #charList))

    local charTotal      = 0
    local charsThatCount = 0  -- persos avec gold != nil

    for _, e in ipairs(charList) do
        local isLive = (e.name == currentPlayer and e.realm == currentRealm)
        local hex    = ClassHex(e.class)
        local goldUsed
        local badge, goldStr, note

        if isLive then
            -- Perso connecté : lecture GetMoney() en temps réel.
            local liveGold = GetMoney() or 0
            goldUsed = liveGold
            badge    = "|cff55ff55[LIVE]|r"
            goldStr  = CopperToStr(liveGold)
            -- Alerte si la valeur DB diffère (scan pas encore mis à jour)
            if e.gold ~= nil and math.abs(liveGold - e.gold) > 0 then
                note = string.format(ns.L("DBG_DB_UPDATE_NOTE"), CopperToStr(e.gold))
            else
                note = ""
            end

        elseif e.gold == nil then
            goldUsed = 0
            badge    = "|cffff4444[NIL] |r"
            goldStr  = ns.L("DBG_NEVER_SCANNED")
            note     = ""

        elseif e.gold == 0 then
            goldUsed = 0
            badge    = "|cff888888[ZERO]|r"
            goldStr  = "|cff888888" .. string.format("0 %s", ns.L("GOLD_ABBR")) .. "|r"
            note     = ""

        else
            goldUsed = e.gold
            badge    = "|cffffd700[SAVE]|r"
            goldStr  = CopperToStr(e.gold)
            note     = ""
        end

        if e.gold ~= nil then charsThatCount = charsThatCount + 1 end
        charTotal = charTotal + goldUsed

        print(string.format("  %s |cff%s%-14s|r @ |cffaaaaaa%-18s|r  %s%s",
            badge, hex, e.name, e.realm, goldStr, note))
    end

    -- Sous-total persos
    print(string.format(ns.L("DBG_CHAR_SUBTOTAL"),
        string.rep(" ", 6), CopperToStr(charTotal), charsThatCount))
    print(SEP)

    -- ── Banque de Bataillon ───────────────────────────────────────────
    print(ns.L("DBG_WARBAND_HEADER"))

    local savedWB  = (ViewerLogDB and tonumber(ViewerLogDB.warbandGold)) or nil
    local liveWB   = nil
    local apiAvail = (C_Bank ~= nil and C_Bank.FetchDepositedMoney ~= nil)

    if apiAvail then
        local raw = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
        liveWB = raw and tonumber(raw)
    end

    local isOpen    = ns.IsWarbandBankOpen       and ns.IsWarbandBankOpen()
    local wasOpened = ns.WarbandOpenedThisSession and ns.WarbandOpenedThisSession()

    -- Ligne API live
    do
        local badge
        if not apiAvail then
            badge = "|cffff4444[UNAVAIL]|r"
        elseif isOpen then
            badge = "|cff55ff55[LIVE]    |r"
        elseif liveWB and liveWB > 0 then
            badge = "|cffffd700[API+]    |r"
        else
            badge = "|cff888888[API 0]   |r"
        end
        local valStr = apiAvail
            and (liveWB ~= nil and CopperToStr(liveWB) or ns.L("DBG_RETURNS_NIL"))
            or ns.L("DBG_BANK_UNAVAILABLE")
        print("  " .. badge .. " FetchDepositedMoney()      → " .. valStr)
    end

    -- Ligne valeur DB sauvegardée
    do
        local valStr = savedWB ~= nil and CopperToStr(savedWB)
            or ns.L("DBG_NEVER_PERSISTED")
        print("  |cffaaaaaa[DB]      |r ViewerLogDB.warbandGold      → " .. valStr)
    end

    -- Ligne fiabilité
    do
        local rel
        if isOpen then
            rel = ns.L("DBG_REL_OPEN_LIVE")
        elseif wasOpened then
            rel = ns.L("DBG_REL_OPENED_SESSION")
        elseif liveWB and liveWB > 0 then
            rel = ns.L("DBG_REL_API_POSITIVE")
        else
            rel = ns.L("DBG_REL_NEVER_OPENED")
        end
        print(string.format(ns.L("DBG_RELIABILITY_LINE"), rel))
    end

    -- Valeur retenue pour le total (même logique que BottomBar.ReadWarbandGold)
    local wbForTotal
    if isOpen and liveWB then
        wbForTotal = liveWB           -- banque ouverte : live = vérité absolue
    elseif liveWB and liveWB > 0 then
        wbForTotal = liveWB           -- API positive sans banque ouverte : fiable
    elseif wasOpened then
        wbForTotal = savedWB or 0     -- ouverte + live=0 → or retiré, honorer le cache
    else
        wbForTotal = savedWB or 0     -- jamais ouverte : cache possiblement périmé
    end

    print(string.format(ns.L("DBG_TOTAL_RETAINED"),
        string.rep(" ", 10), CopperToStr(wbForTotal)))
    print(SEP)

    -- ── Grand total ───────────────────────────────────────────────────
    local grandTotal = charTotal + wbForTotal
    print(string.format(ns.L("DBG_GRAND_TOTAL"),
        CopperToStr(grandTotal)))
    print(string.format(ns.L("DBG_APPROX_GOLD"),
        math.floor(grandTotal / 10000)))
    print(SEP)
end
