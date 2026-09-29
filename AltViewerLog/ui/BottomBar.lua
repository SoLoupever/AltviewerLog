local addonName, ns = ...

-- ====================================================
-- UI/BOTTOMBAR — Barre du bas : Or Total / Temps / Personnages
-- ====================================================

-- ── 1. Constantes ─────────────────────────────────────────────────
local BTN_H   = 28
local BTN_PAD =  6

ns.bottomBtns = ns.bottomBtns or {}

-- ── 2. Collecte de données ────────────────────────────────────────

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

-- ── 3. Tooltips ───────────────────────────────────────────────────

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
                GetCoinTextureString(d.gold),
                1, 1, 1,  1, 1, 1)
        end
        GameTooltip:AddDoubleLine(
            "|cffcccccc  Sous-total|r",
            GetCoinTextureString(charTotal),
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
            GetCoinTextureString(wbDisplay),
            1, 1, 1,  1, 1, 1)
    else
        GameTooltip:AddLine(isCached
            and ("|cff606060" .. ns.L("TT_WARBAND_NO_GOLD") .. "|r")
            or  "|cff6060600 or|r")
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(
        "|cffffff00" .. ns.L("TOTAL_GOLD") .. "|r",
        GetCoinTextureString(grandTotal),
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

-- ── 4. Factory bouton ─────────────────────────────────────────────

local function MakeBottomBtn()
    local btn = CreateFrame("Button", nil, ns.bottomBar, "BackdropTemplate")
    btn:SetHeight(BTN_H)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.10, 0.10, 0.10, 1.0)
    btn:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)

    btn:SetScript("OnEnter", function(self)
        local b = ns._themeBorder or {0.30, 0.30, 0.30}
        local t = AltViewerLogDB
            and AltViewerLogDB.settings
            and AltViewerLogDB.settings.theme or "default"
        if t == "default" then
            self:SetBackdropColor(0.20, 0.20, 0.20, 1)
        else
            self:SetBackdropColor(
                b[1] * 0.30 + 0.05,
                b[2] * 0.20 + 0.03,
                b[3] * 0.35 + 0.06, 1)
        end
        self:SetBackdropBorderColor(
            math.min(b[1] * 1.5, 1),
            math.min(b[2] * 1.5, 1),
            math.min(b[3] * 1.5, 1), 1)
        if self._showTooltip then self._showTooltip(self) end
    end)

    btn:SetScript("OnLeave", function(self)
        local b = ns._themeBorder or {0.30, 0.30, 0.30}
        local t = AltViewerLogDB
            and AltViewerLogDB.settings
            and AltViewerLogDB.settings.theme or "default"
        if t == "default" then
            self:SetBackdropColor(0.10, 0.10, 0.10, 1.0)
        else
            self:SetBackdropColor(
                b[1] * 0.18 + 0.03,
                b[2] * 0.12 + 0.03,
                b[3] * 0.25 + 0.06, 1.0)
        end
        self:SetBackdropBorderColor(b[1], b[2], b[3], 1)
        GameTooltip:Hide()
    end)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    btn.fs = fs

    ns.bottomBtns[#ns.bottomBtns + 1] = btn
    return btn
end

-- ── 5. Création des 3 boutons ─────────────────────────────────────

ns.bbGold  = MakeBottomBtn()
ns.bbTime  = MakeBottomBtn()
ns.bbChars = MakeBottomBtn()

ns.bbGold._showTooltip  = nil
ns.bbTime._showTooltip  = nil
ns.bbChars._showTooltip = nil

-- ── 6. Positionnement dynamique ───────────────────────────────────

local function LayoutBtns()
    if not ns.mainFrame or not ns.bottomBar then return end
    local W    = ns.mainFrame:GetWidth()
    local btnW = math.floor((W - BTN_PAD * 4) / 3)
    local posY = math.floor((36 - BTN_H) / 2)

    ns.bbGold:ClearAllPoints()
    ns.bbGold:SetWidth(btnW)
    ns.bbGold:SetPoint("LEFT",   ns.bottomBar, "LEFT",   BTN_PAD, posY)

    ns.bbTime:ClearAllPoints()
    ns.bbTime:SetWidth(btnW)
    ns.bbTime:SetPoint("CENTER", ns.bottomBar, "CENTER", 0,       posY)

    ns.bbChars:ClearAllPoints()
    ns.bbChars:SetWidth(btnW)
    ns.bbChars:SetPoint("RIGHT",  ns.bottomBar, "RIGHT", -BTN_PAD, posY)
end

ns.mainFrame:HookScript("OnSizeChanged", LayoutBtns)

local _initFrame = CreateFrame("Frame")
_initFrame:RegisterEvent("PLAYER_LOGIN")
_initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    C_Timer.After(0.1, LayoutBtns)
end)

-- ── 7. ns.UpdateBottomBar ─────────────────────────────────────────
-- Point d'entrée unique pour rafraîchir les 3 boutons.
-- NE lit PAS via ns.GetWarbandGold() pour éviter toute récursion.

ns.UpdateBottomBar = function()
    if not (ns.bbGold and ns.bbTime and ns.bbChars) then return end

    -- Or personnages (depuis la DB, mise à jour en temps réel par PLAYER_MONEY)
    local charTotal     = CountCharGold()

    -- Or bataillon (live si banque ouverte, cache sinon)
    local wbDisplay, _  = ReadWarbandGold()

    -- Total
    local grandTotal    = charTotal + wbDisplay

    -- Bouton or
    ns.bbGold.fs:SetText(
        (ns.CC and ns.L and ns.CC(ns.L("TOTAL_GOLD")) or "Or")
        .. "  " .. GetCoinTextureString(grandTotal))

    -- Bouton temps
    ns.bbTime.fs:SetText(
        (ns.CC and ns.L and ns.CC(ns.L("TOTAL_TIME")) or "Temps")
        .. "  " .. (ns.FormatTime and ns.FormatTime(CountTotalTime()) or "?"))

    -- Bouton personnages
    ns.bbChars.fs:SetText(
        (ns.CC and ns.L and ns.CC(ns.L("TOTAL_CHARS")) or "Persos")
        .. "  " .. CountTotalChars())
end

-- Stub legacy
ns.bottomText = ns.mainFrame:CreateFontString(nil, "OVERLAY")
ns.bottomText:Hide()
