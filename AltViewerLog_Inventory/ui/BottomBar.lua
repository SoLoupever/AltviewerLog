local addonName, ns = ...
local core = ns.core

-- ====================================================
-- UI/BOTTOMBAR — Items de la barre du bas : Or total / Temps / Personnages
-- Rôle UNIQUE : fournir les 3 items au conteneur du noyau
-- (core.RegisterBottomItem) et suivre l'or en temps réel.
-- ====================================================

-- ── 1. Collecte de données ────────────────────────────────────────

-- Retourne (totalCopper, detailsTable).
-- detailsTable : {{ name, realm, class, gold }, … } trié desc.
local function CountCharGold()
    if not ns.DP_IsReady() then return 0, {} end
    local total, details = 0, {}
    ns.DP_IterateChars(function(realmName, charName, charData)
        local g = charData.gold or 0
        if g > 0 then
            total = total + g
            details[#details + 1] = {
                name  = charName,
                realm = realmName,
                class = charData.class,
                gold  = g,
            }
        end
    end)
    table.sort(details, function(a, b) return a.gold > b.gold end)
    return total, details
end

-- Retourne (wbDisplay, isCached).
--   wbDisplay : valeur à afficher (live si banque ouverte, cache sinon)
--   isCached  : true si la banque n'a jamais été ouverte cette session
--
-- RÈGLE : n'appelle JAMAIS ns.UpdateBottomBar() — évite toute récursion.
local function ReadWarbandGold()
    local cached = ns.DP_IsReady() and (tonumber(ns.DP_GetWarbandGold()) or 0) or 0
    local live   = 0

    if C_Bank and C_Bank.FetchDepositedMoney then
        live = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
    end

    local isOpen            = ns.IsWarbandBankOpen and ns.IsWarbandBankOpen()
    local openedThisSession = ns.WarbandOpenedThisSession and ns.WarbandOpenedThisSession()

    -- Banque présentement ouverte : live est la vérité absolue (même si 0).
    if isOpen then
        return live, false
    end

    -- L'API renvoie une valeur positive : elle est fiable hors banque ouverte.
    if live > 0 then
        return live, not openedThisSession
    end

    -- live = 0 et banque ouverte cette session → l'or a été retiré (ou est à 0).
    -- Le cache a déjà été mis à 0 par les events ; on l'honore.
    if openedThisSession then
        return cached, false
    end

    -- live = 0 et jamais ouverte : cache potentiellement périmé, on le signale.
    return cached, true
end

local function CountTotalTime()
    if not ns.DP_IsReady() then return 0 end
    local total = 0
    ns.DP_IterateChars(function(_, _, charData)
        total = total + (charData.timePlayed or 0)
    end)
    return total
end

local function CountTotalChars()
    if not ns.DP_IsReady() then return 0 end
    local total = 0
    ns.DP_IterateChars(function() total = total + 1 end)
    return total
end

-- ── 2. Tooltips ───────────────────────────────────────────────────

local function ShowGoldTooltip(anchor)
    local charTotal, charDetails = CountCharGold()
    local wbDisplay, isCached    = ReadWarbandGold()
    local grandTotal             = charTotal + wbDisplay

    GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffffff00" .. (ns.L and ns.L("TOTAL_GOLD") or "Or total") .. "|r")
    GameTooltip:AddLine(" ")

    -- Personnages
    GameTooltip:AddLine("|cffaaaaaa── " .. (ns.L and ns.L("TOTAL_CHARS") or "Personnages") .. " ──|r")
    if #charDetails == 0 then
        GameTooltip:AddLine("|cff606060Aucun personnage|r")
    else
        for _, d in ipairs(charDetails) do
            local col = RAID_CLASS_COLORS and d.class and RAID_CLASS_COLORS[d.class]
            local r, g, b = col and col.r or 1, col and col.g or 1, col and col.b or 1
            GameTooltip:AddDoubleLine(
                string.format("|cff%02x%02x%02x%s|r |cff555555(%s)|r",
                    math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), d.name, d.realm),
                ns.FormatMoney(d.gold),
                1, 1, 1,  1, 1, 1)
        end
        GameTooltip:AddDoubleLine(
            "|cffcccccc  Sous-total|r",
            ns.FormatMoney(charTotal),
            1, 1, 1,  1, 1, 1)
    end

    GameTooltip:AddLine(" ")

    -- Banque Bataillon
    local wbTitle = "|cffaaaaaa── "
        .. ns.L("WARBAND_TITLE")
        .. " ──|r"
        .. (isCached and " |cff888888(†cache)|r" or "")
    GameTooltip:AddLine(wbTitle)

    if wbDisplay > 0 then
        GameTooltip:AddDoubleLine(
            "|cff00ccff" .. ns.L("BTN_WARBAND") .. "|r",
            ns.FormatMoney(wbDisplay),
            1, 1, 1,  1, 1, 1)
    else
        GameTooltip:AddLine(isCached
            and ("|cff606060" .. ns.L("TT_WARBAND_NO_GOLD") .. "|r")
            or  "|cff6060600 or|r")
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(
        "|cffffff00" .. ns.L("TOTAL_GOLD") .. "|r",
        ns.FormatMoney(grandTotal),
        1, 1, 0,  1, 1, 0)
    GameTooltip:Show()
end

local function ShowTimeTooltip(anchor)
    GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffffff00" .. ns.L("TOTAL_TIME") .. "|r")
    GameTooltip:AddLine(ns.FormatTime and ns.FormatTime(CountTotalTime()) or "?")
    GameTooltip:Show()
end

local function ShowCharsTooltip(anchor)
    GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffffff00" .. (ns.L and ns.L("TOTAL_CHARS") or "Personnages") .. "|r")
    GameTooltip:AddLine(tostring(CountTotalChars()))
    GameTooltip:Show()
end

-- ── 4. Enregistrement des items ───────────────────────────────────

-- Libellé (couleur de titre du thème) + valeur claire
local function Label(key, value)
    local t = ns.Theme
    return "|cff" .. t.title .. ns.L(key) .. "|r  " .. value
end

local function Val(text)
    return "|cff" .. ns.ColorHex(ns.Theme.text) .. text .. "|r"
end

core.RegisterBottomItem({
    priority = 10,
    text = function()
        local charTotal = CountCharGold()
        local wbDisplay = ReadWarbandGold()
        return Label("TOTAL_GOLD", ns.FormatMoney(charTotal + wbDisplay))
    end,
    tooltip = ShowGoldTooltip,
})

core.RegisterBottomItem({
    priority = 20,
    text = function() return Label("TOTAL_TIME", Val(ns.FormatTime(CountTotalTime()))) end,
    tooltip = ShowTimeTooltip,
})

core.RegisterBottomItem({
    priority = 30,
    text = function() return Label("TOTAL_CHARS", Val(CountTotalChars())) end,
    tooltip = ShowCharsTooltip,
})

-- ── 5. Rafraîchissement sur variation d'or ────────────────────────
-- PLAYER_MONEY : or du perso ; ACCOUNT_MONEY : or de bataillon.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_MONEY")
ev:RegisterEvent("ACCOUNT_MONEY")
ev:SetScript("OnEvent", function() core.UpdateBottomBar() end)
