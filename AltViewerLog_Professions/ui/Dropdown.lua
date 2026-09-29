local addonName, pluginNs = ...
local core = _G.AltViewerLogAPI

local activeDropdown = nil

function pluginNs.CloseActiveDropdown()
    if activeDropdown and activeDropdown:IsShown() then
        activeDropdown:Hide()
    end
    activeDropdown = nil
end

-- ====================================================
-- DROPDOWN TIERS — bouton ▼ avec liste + ajout/suppression
-- ====================================================
function pluginNs.CreateTierDropdown(parent, anchorFrame, tiers, realmName, charName, profName)
    local BTN_W = 18
    local BAR_H = pluginNs.BAR_H

    local arrowBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    arrowBtn:SetSize(BTN_W, BAR_H)
    arrowBtn:SetPoint("LEFT", anchorFrame, "RIGHT", 2, 0)
    arrowBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    arrowBtn:SetBackdropColor(0.18, 0.15, 0.08, 1)
    arrowBtn:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)

    local gearTex = arrowBtn:CreateTexture(nil, "ARTWORK")
    gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    gearTex:SetSize(14, 14)
    gearTex:SetPoint("CENTER", 0, 0)
    gearTex:SetVertexColor(0.95, 0.82, 0.40)

    arrowBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.30, 0.24, 0.10, 1)
        self:SetBackdropBorderColor(0.85, 0.70, 0.25, 1)
        gearTex:SetVertexColor(1, 1, 0.7)
    end)
    arrowBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.18, 0.15, 0.08, 1)
        self:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)
        gearTex:SetVertexColor(0.95, 0.82, 0.40)
    end)

    local ITEM_H = 22
    local MENU_W = 260

    local menuFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menuFrame:SetSize(MENU_W, #tiers * ITEM_H + 6)
    menuFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
    menuFrame:SetBackdropBorderColor(0.45, 0.38, 0.18, 1)
    menuFrame:SetFrameStrata("DIALOG")
    menuFrame:Hide()

    for i, tier in ipairs(tiers) do
        local color  = pluginNs.GetTierColor(tier.name)
        local tpct   = (tier.max > 0) and math.min(tier.level / tier.max, 1) or 0
        local isFull = (tpct >= 1)

        local item = CreateFrame("Frame", nil, menuFrame)
        item:SetSize(MENU_W - 6, ITEM_H)
        item:SetPoint("TOPLEFT", 3, -3 - (i - 1) * ITEM_H)

        local rowBg = item:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        rowBg:SetColorTexture(0, 0, 0, 0)

        if tpct > 0 then
            local mf = item:CreateTexture(nil, "BACKGROUND")
            mf:SetPoint("TOPLEFT", 0, -1)
            mf:SetPoint("BOTTOMLEFT", 0, 1)
            mf:SetWidth(math.max(tpct * (MENU_W - 6), 2))
            mf:SetColorTexture(color.r, color.g, color.b, 0.12)
        end

        local dot = item:CreateTexture(nil, "OVERLAY")
        dot:SetSize(6, 6)
        dot:SetPoint("LEFT", 6, 0)
        dot:SetColorTexture(color.r, color.g, color.b, 1)

        local lbl = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", 18, 0)
        lbl:SetWidth(130)
        lbl:SetJustifyH("LEFT")
        lbl:SetTextColor(color.r * 0.9, color.g * 0.9, color.b * 0.9)
        lbl:SetText(tier.name .. (tier.manual and " |cff555555(m)|r" or ""))

        local val = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("RIGHT", tier.manual and -24 or -6, 0)
        val:SetJustifyH("RIGHT")
        if isFull then
            val:SetText("|cff00ff55MAX|r")
        else
            val:SetText(string.format("|cffffff00%d|r|cff444444/|r|cff777777%d|r", tier.level, tier.max))
        end

        if tier.manual then
            local capturedIdx = i

            local editBtn = CreateFrame("Button", nil, item, "BackdropTemplate")
            editBtn:SetSize(16, 16)
            editBtn:SetPoint("RIGHT", -3, 0)
            editBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                   edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            editBtn:SetBackdropColor(0.10, 0.10, 0.20, 1)
            editBtn:SetBackdropBorderColor(0.30, 0.30, 0.50, 1)

            local editLbl = editBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            editLbl:SetPoint("CENTER", 0, 0)
            editLbl:SetText("|TInterface\\Buttons\\UI-OptionsButton:12:12|t")
            editLbl:SetTextColor(0.6, 0.6, 1)

            editBtn:SetScript("OnClick", function()
                pluginNs.CloseActiveDropdown()
                pluginNs.OpenAddTierPopup(realmName, charName, profName, capturedIdx)
            end)
            editBtn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.18, 0.18, 0.35, 1)
                rowBg:SetColorTexture(1, 1, 1, 0.05)
            end)
            editBtn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.10, 0.10, 0.20, 1)
                rowBg:SetColorTexture(0, 0, 0, 0)
            end)

            local delBtn = CreateFrame("Button", nil, item, "BackdropTemplate")
            delBtn:SetSize(16, 16)
            delBtn:SetPoint("RIGHT", editBtn, "LEFT", -2, 0)
            delBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                                  edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            delBtn:SetBackdropColor(0.20, 0.06, 0.06, 1)
            delBtn:SetBackdropBorderColor(0.50, 0.10, 0.10, 1)

            local delLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            delLbl:SetPoint("CENTER", 0, 0)
            delLbl:SetText("x")
            delLbl:SetTextColor(1, 0.3, 0.3)

            delBtn:SetScript("OnClick", function()
                pluginNs.CloseActiveDropdown()
                local cd = AltViewerLogDB[realmName] and AltViewerLogDB[realmName][charName]
                if cd and cd.professions then
                    for _, p in ipairs(cd.professions) do
                        if p.name == profName then
                            table.remove(p.tiers, capturedIdx)
                            break
                        end
                    end
                end
                if pluginNs.isViewActive and core.mainFrame and core.mainFrame:IsShown() then
                    pluginNs.ShowProfessions()
                end
            end)
            delBtn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.35, 0.10, 0.10, 1)
                rowBg:SetColorTexture(1, 0.2, 0.2, 0.06)
            end)
            delBtn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.20, 0.06, 0.06, 1)
                rowBg:SetColorTexture(0, 0, 0, 0)
            end)
        end
    end

    menuFrame:SetScript("OnHide", function()
        if activeDropdown == menuFrame then activeDropdown = nil end
    end)

    arrowBtn:SetScript("OnClick", function(self)
        if menuFrame:IsShown() then
            pluginNs.CloseActiveDropdown()
        else
            pluginNs.CloseActiveDropdown()
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            menuFrame:Show()
            activeDropdown = menuFrame
        end
    end)

    return arrowBtn
end
