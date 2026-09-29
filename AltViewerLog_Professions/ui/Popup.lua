local addonName, pluginNs = ...
local core = _G.AltViewerLogAPI

local addTierPopup         = nil
local selectedExpansionIdx = 1

local function CreateAddTierPopup()
    if addTierPopup then return addTierPopup end

    local popup = CreateFrame("Frame", "BVLAddTierPopup", UIParent, "BackdropTemplate")
    popup:SetSize(320, 280)
    popup:SetPoint("CENTER")
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.06, 0.06, 0.10, 0.98)
    popup:SetBackdropBorderColor(0.50, 0.42, 0.18, 1)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop",  popup.StopMovingOrSizing)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(core.L("POPUP_ADD"))
    title:SetTextColor(1, 0.85, 0.20)
    popup.title = title

    local sep = popup:CreateTexture(nil, "ARTWORK")
    sep:SetSize(290, 1)
    sep:SetPoint("TOP", 0, -44)
    sep:SetColorTexture(1, 0.82, 0, 0.25)

    local extLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    extLabel:SetPoint("TOPLEFT", 18, -58)
    extLabel:SetText(core.L("POPUP_EXT_LABEL"))

    local extBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    extBtn:SetSize(222, 22)
    extBtn:SetPoint("TOPLEFT", 18, -76)
    extBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                         edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    extBtn:SetBackdropColor(0.12, 0.10, 0.06, 1)
    extBtn:SetBackdropBorderColor(0.40, 0.34, 0.14, 1)
    popup.extBtn = extBtn

    local extBtnLabel = extBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    extBtnLabel:SetPoint("LEFT", 8, 0)
    extBtnLabel:SetWidth(185)
    extBtnLabel:SetJustifyH("LEFT")
    extBtnLabel:SetText(pluginNs.EXPANSION_LIST[1].name)
    popup.extBtnLabel = extBtnLabel

    local extArrow = extBtn:CreateTexture(nil, "ARTWORK")
    extArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown")
    extArrow:SetSize(10, 7)
    extArrow:SetPoint("RIGHT", -4, 0)
    extArrow:SetVertexColor(0.8, 0.7, 0.3)

    local extMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    extMenu:SetSize(232, #pluginNs.EXPANSION_LIST * 20 + 4)
    extMenu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                          edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    extMenu:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
    extMenu:SetBackdropBorderColor(0.45, 0.38, 0.18, 1)
    extMenu:SetFrameStrata("TOOLTIP")
    extMenu:Hide()
    popup.extMenu = extMenu

    for idx, exp in ipairs(pluginNs.EXPANSION_LIST) do
        local color = pluginNs.GetTierColor(exp.name)
        local item  = CreateFrame("Button", nil, extMenu)
        item:SetSize(228, 20)
        item:SetPoint("TOPLEFT", 2, -2 - (idx - 1) * 20)

        local bg = item:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)

        local lbl = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", 8, 0)
        lbl:SetTextColor(color.r, color.g, color.b)
        lbl:SetText(exp.name)

        item:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, 0.08) end)
        item:SetScript("OnLeave", function() bg:SetColorTexture(0, 0, 0, 0) end)

        local capturedIdx = idx
        item:SetScript("OnClick", function()
            selectedExpansionIdx = capturedIdx
            extBtnLabel:SetText(pluginNs.EXPANSION_LIST[capturedIdx].name)
            popup.maxBox:SetText(tostring(pluginNs.EXPANSION_LIST[capturedIdx].defaultMax))
            extMenu:Hide()
        end)
    end

    extBtn:SetScript("OnClick", function(self)
        if extMenu:IsShown() then extMenu:Hide()
        else
            extMenu:ClearAllPoints()
            extMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            extMenu:Show()
        end
    end)

    local lvlLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lvlLabel:SetPoint("TOPLEFT", 18, -112)
    lvlLabel:SetText(core.L("POPUP_LEVEL"))

    local lvlBox = CreateFrame("EditBox", nil, popup, "BackdropTemplate")
    lvlBox:SetSize(80, 22)
    lvlBox:SetPoint("TOPLEFT", 18, -130)
    lvlBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                         edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    lvlBox:SetBackdropColor(0.08, 0.08, 0.12, 1)
    lvlBox:SetBackdropBorderColor(0.35, 0.35, 0.50, 1)
    lvlBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    lvlBox:SetTextColor(1, 1, 0.5)
    lvlBox:SetTextInsets(6, 6, 0, 0)
    lvlBox:SetNumeric(true)
    lvlBox:SetMaxLetters(4)
    lvlBox:SetAutoFocus(false)
    lvlBox:SetText("0")
    popup.lvlBox = lvlBox

    local slash = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    slash:SetPoint("LEFT", lvlBox, "RIGHT", 8, 0)
    slash:SetText("/")
    slash:SetTextColor(0.5, 0.5, 0.5)

    local maxLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    maxLabel:SetPoint("TOPLEFT", 130, -112)
    maxLabel:SetText(core.L("POPUP_MAX"))

    local maxBox = CreateFrame("EditBox", nil, popup, "BackdropTemplate")
    maxBox:SetSize(80, 22)
    maxBox:SetPoint("TOPLEFT", 130, -130)
    maxBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                         edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    maxBox:SetBackdropColor(0.08, 0.08, 0.12, 1)
    maxBox:SetBackdropBorderColor(0.35, 0.35, 0.50, 1)
    maxBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    maxBox:SetTextColor(1, 1, 0.5)
    maxBox:SetTextInsets(6, 6, 0, 0)
    maxBox:SetNumeric(true)
    maxBox:SetMaxLetters(4)
    maxBox:SetAutoFocus(false)
    maxBox:SetText("100")
    popup.maxBox = maxBox

    local previewLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewLabel:SetPoint("TOPLEFT", 18, -170)
    previewLabel:SetText(core.L("POPUP_PREVIEW"))
    previewLabel:SetTextColor(0.5, 0.5, 0.5)

    local previewBg = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    previewBg:SetSize(280, 14)
    previewBg:SetPoint("TOPLEFT", 18, -186)
    previewBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    previewBg:SetBackdropColor(0.07, 0.07, 0.07, 1)
    popup.previewBg = previewBg

    local previewFill = CreateFrame("Frame", nil, previewBg, "BackdropTemplate")
    previewFill:SetSize(1, 14)
    previewFill:SetPoint("LEFT")
    previewFill:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    previewFill:SetBackdropColor(0.4, 0.85, 1, 0.9)
    popup.previewFill = previewFill

    local function UpdatePreview()
        local lvl = tonumber(lvlBox:GetText()) or 0
        local mx  = tonumber(maxBox:GetText()) or 1
        if mx < 1 then mx = 1 end
        local pct   = math.min(lvl / mx, 1)
        local color = pluginNs.GetTierColor(pluginNs.EXPANSION_LIST[selectedExpansionIdx].name)
        previewFill:SetWidth(math.max(pct * 280, 2))
        previewFill:SetBackdropColor(color.r, color.g, color.b, 0.9)
    end
    lvlBox:SetScript("OnTextChanged", UpdatePreview)
    maxBox:SetScript("OnTextChanged", UpdatePreview)
    popup.UpdatePreview = UpdatePreview

    local confirmBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    confirmBtn:SetSize(120, 26)
    confirmBtn:SetPoint("BOTTOMLEFT", 18, 18)
    confirmBtn:SetText(core.L("POPUP_CONFIRM"))
    confirmBtn:SetNormalFontObject("GameFontNormal")
    confirmBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                              edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    confirmBtn:SetBackdropColor(0.08, 0.28, 0.08, 1)
    confirmBtn:SetBackdropBorderColor(0, 0.5, 0, 1)
    confirmBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.12, 0.40, 0.12, 1) end)
    confirmBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.08, 0.28, 0.08, 1) end)
    popup.confirmBtn = confirmBtn

    local cancelBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    cancelBtn:SetSize(120, 26)
    cancelBtn:SetPoint("BOTTOMRIGHT", -18, 18)
    cancelBtn:SetText(core.L("POPUP_CANCEL"))
    cancelBtn:SetNormalFontObject("GameFontNormal")
    cancelBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                             edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    cancelBtn:SetBackdropColor(0.28, 0.08, 0.08, 1)
    cancelBtn:SetBackdropBorderColor(0.5, 0, 0, 1)
    cancelBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.40, 0.12, 0.12, 1) end)
    cancelBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.28, 0.08, 0.08, 1) end)
    cancelBtn:SetScript("OnClick", function()
        extMenu:Hide()
        popup:Hide()
    end)

    addTierPopup = popup
    return popup
end

function pluginNs.OpenAddTierPopup(realmName, charName, profName, editTierIdx)
    local popup = CreateAddTierPopup()
    popup.extMenu:Hide()

    selectedExpansionIdx = 1
    popup.extBtnLabel:SetText(pluginNs.EXPANSION_LIST[1].name)
    popup.lvlBox:SetText("0")
    popup.maxBox:SetText(tostring(pluginNs.EXPANSION_LIST[1].defaultMax))

    local isEdit = (editTierIdx ~= nil)
    popup.title:SetText(isEdit
        and string.format(core.L("POPUP_EDIT"), profName)
        or  string.format(core.L("POPUP_ADD_PROF"), profName))

    if not popup.subTitle then
        local sub = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        sub:SetPoint("TOP", popup.title, "BOTTOM", 0, -2)
        sub:SetTextColor(0.60, 0.60, 0.60)
        popup.subTitle = sub
    end
    popup.subTitle:SetText(charName .. "  |cff444444" .. realmName .. "|r")

    if isEdit then
        local charData = AltViewerLogDB[realmName] and AltViewerLogDB[realmName][charName]
        if charData and charData.professions then
            for _, p in ipairs(charData.professions) do
                if p.name == profName then
                    local tier = p.tiers[editTierIdx]
                    if tier then
                        for idx, exp in ipairs(pluginNs.EXPANSION_LIST) do
                            if tier.name:find(exp.name, 1, true) or exp.name:find(tier.name, 1, true) then
                                selectedExpansionIdx = idx
                                popup.extBtnLabel:SetText(exp.name)
                                break
                            end
                        end
                        popup.lvlBox:SetText(tostring(tier.level))
                        popup.maxBox:SetText(tostring(tier.max))
                    end
                end
            end
        end
    end

    popup.UpdatePreview()

    popup.confirmBtn:SetScript("OnClick", function()
        local expName = pluginNs.EXPANSION_LIST[selectedExpansionIdx].name
        local lvl = tonumber(popup.lvlBox:GetText()) or 0
        local mx  = tonumber(popup.maxBox:GetText()) or pluginNs.EXPANSION_LIST[selectedExpansionIdx].defaultMax
        if mx < 1 then mx = 1 end

        local charData = AltViewerLogDB[realmName] and AltViewerLogDB[realmName][charName]
        if charData and charData.professions then
            for _, p in ipairs(charData.professions) do
                if p.name == profName then
                    if isEdit then
                        p.tiers[editTierIdx].name  = expName
                        p.tiers[editTierIdx].level = lvl
                        p.tiers[editTierIdx].max   = mx
                    else
                        local alreadyExists = false
                        for _, t in ipairs(p.tiers) do
                            if t.name == expName then
                                alreadyExists = true
                                t.level = lvl
                                t.max   = mx
                                break
                            end
                        end
                        if not alreadyExists then
                            table.insert(p.tiers, { name = expName, level = lvl, max = mx, manual = true })
                        end
                    end
                    break
                end
            end
        end

        popup.extMenu:Hide()
        popup:Hide()
        if pluginNs.isViewActive and core.mainFrame and core.mainFrame:IsShown() then
            pluginNs.ShowProfessions()
        end
    end)

    popup:Show()
    popup.lvlBox:SetFocus()
end
