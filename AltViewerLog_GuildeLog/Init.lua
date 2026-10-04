local addonName, pluginNs = ...

-- ====================================================
-- INIT — Plugin Guilde
-- Injecte le bouton "Coffre de Guilde" dans la sidebar
-- (priorité 300, après Professions/100 et Réputations/200).
-- ====================================================

local core = _G.AltViewerLogAPI
if not core then
    print("|cffff0000[AVL-Guilde]|r " .. pluginNs.L("ERR_API_MISSING"))
    return
end

pluginNs.isViewActive = false

-- ── Injection du bouton sidebar ───────────────────────────────────
if core.RegisterSidebarButton then
    local function GetClassHex()
        local _, classFile = UnitClass("player")
        local col = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if col then
            return string.format("%02x%02x%02x",
                math.floor(col.r*255), math.floor(col.g*255), math.floor(col.b*255))
        end
        return "cc88ff"
    end
    local function CC(text) return "|cff"..GetClassHex()..text.."|r" end

    local btnGuilde = core.RegisterSidebarButton(300, function(parent)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        return btn
    end)

    if btnGuilde then
        local function ApplyBtnColor()
            btnGuilde:SetText(CC(pluginNs.L("BTN_GUILDE")))
        end
        -- Couleur de classe indisponible avant PLAYER_LOGIN : retry différé.
        C_Timer.After(0.3, ApplyBtnColor)
        local _colorFrame = CreateFrame("Frame")
        _colorFrame:RegisterEvent("PLAYER_LOGIN")
        _colorFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_LOGIN")
            ApplyBtnColor()
        end)

        btnGuilde:SetScript("OnClick", function()
            pluginNs.isViewActive = true
            pluginNs.ShowGuildBank()
        end)

        -- ── Sélecteur de guilde ───────────────────────────────────────
        pluginNs.GetOrCreateSelectorFrame()

        local function HideSelector()
            pluginNs.isViewActive = false
            if pluginNs._selectorScroll then pluginNs._selectorScroll:Hide() end
        end

        -- Chaîne sur CloseModulePopups sans écraser le handler existant :
        -- tout appelant de core.CloseAllPopups() ferme aussi ce sélecteur.
        local _prevModuleClose = core.CloseModulePopups
        core.CloseModulePopups = function()
            if _prevModuleClose then _prevModuleClose() end
            HideSelector()
        end

        local _origShow = pluginNs.ShowGuildBank
        pluginNs.ShowGuildBank = function()
            if pluginNs._selectorScroll then pluginNs._selectorScroll:Show() end
            _origShow()
        end

        if core.mainFrame then
            core.mainFrame:HookScript("OnHide", function()
                pluginNs.isViewActive = false
                if pluginNs._selectorScroll then pluginNs._selectorScroll:Hide() end
            end)
        end

        local SELECTOR_W = 160
        local _origGetContentWidth = core.GetContentWidth
        core.GetContentWidth = function()
            if pluginNs.isViewActive and pluginNs._selectorScroll
            and pluginNs._selectorScroll:IsShown() then
                return math.max(300, _origGetContentWidth() - 10 - SELECTOR_W)
            end
            return _origGetContentWidth()
        end
    end
end

-- ── Enregistrement section Settings ──────────────────────────────
-- AltViewerLog (RegisterSettingsSection) est chargé avant ce plugin,
-- dépendance déclarée dans le .toc.
if core.RegisterSettingsSection then
    core.RegisterSettingsSection(function(scrollChild, offsetY)
        if pluginNs.InjectGuildSettings then
            return pluginNs.InjectGuildSettings(scrollChild, offsetY)
        end
        return offsetY
    end)
end

-- ── Délégation du scan vers ViewerLog ────────────────────────────
-- Le scan est géré par ViewerLog ; ce proxy maintient la compatibilité.
function pluginNs.ScanGuildBank()
    if _G.ViewerLogAPI and _G.ViewerLogAPI.ScanGuildBank then
        _G.ViewerLogAPI.ScanGuildBank()
    end
end

-- ── Slash command ─────────────────────────────────────────────────
SLASH_AVLGUILDE1 = "/avlguilde"
SlashCmdList["AVLGUILDE"] = function(msg)
    msg = msg and strtrim(msg:lower()) or ""
    if msg == "scan" then
        pluginNs.ScanGuildBank()
        core.DBG("|cff00aaff[AVL-Guilde]|r " .. pluginNs.L("DBG_SCAN_STARTED"))
    elseif msg == "show" then
        pluginNs.isViewActive = true
        pluginNs.ShowGuildBank()
        if core.mainFrame then core.mainFrame:Show() end
    else
        core.DBG("|cff00aaff[AVL-Guilde]|r " .. pluginNs.L("DBG_HELP"))
    end
end

core.DBG("|cff00aaff[AVL-Guilde]|r " .. pluginNs.L("DBG_LOADED"))

-- ── Addon Compartment ─────────────────────────────────────────────
function AVL_GuildeLog_OnCompartmentClick()
    if not core or not core.mainFrame then return end
    if core.mainFrame:IsShown() then
        pluginNs.isViewActive = true
        pluginNs.ShowGuildBank()
    else
        core.mainFrame:Show()
        if core.RefreshCharacterList then core.RefreshCharacterList() end
        C_Timer.After(0.05, function()
            pluginNs.isViewActive = true
            pluginNs.ShowGuildBank()
        end)
    end
end

function AVL_GuildeLog_OnCompartmentEnter(addonName, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:AddLine(pluginNs.L("AC_TITLE"))
    -- Icône de guilde si disponible
    local guildIcon = GetGuildLogoInfo and GetGuildLogoInfo()
    if not guildIcon then
        -- Fallback : tenter GetGuildInfo pour vérifier qu'on est en guilde
        local gName = GetGuildInfo("player")
        if gName then
            guildIcon = "Interface\\GuildFrame\\GuildEmblems_01"
        end
    end
    if guildIcon then
        GameTooltip:AddLine("|T"..guildIcon..":20:20:0:0|t  " ..
            (GetGuildInfo("player") or ""), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff808080" .. pluginNs.L("AC_CLICK_HINT") .. "|r")
    if ViewerLogDB.guilds then
        local count = 0
        for _, gData in pairs(ViewerLogDB.guilds) do
            if type(gData) == "table" and gData.guildName then
                count = count + 1
                local dateStr = gData.scanTime and gData.scanTime > 0
                    and date("%d/%m %H:%M", gData.scanTime) or "?"
                GameTooltip:AddLine(
                    "|cffffd700"..gData.guildName.."|r"..
                    " |cff606060("..(gData.realm or "?")..")|r"..
                    " |cff404040— "..dateStr.."|r")
            end
        end
        if count == 0 then
            GameTooltip:AddLine("|cff606060" .. pluginNs.L("AC_NO_CHEST_SCANNED") .. "|r")
        end
    end
    GameTooltip:Show()
end

function AVL_GuildeLog_OnCompartmentLeave()
    GameTooltip:Hide()
end
