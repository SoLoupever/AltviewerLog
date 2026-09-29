local addonName, pluginNs = ...
local vlAPI = _G.ViewerLogAPI

-- ====================================================
-- GRILLE DE RECETTES HOUSING (rendu inline dans la vue Métiers)
--
-- Les DONNÉES (définitions de recettes + carte connu/non connu) ne
-- vivent plus ici : elles sont fournies par le module ViewerLog_Housing
-- via _G.ViewerLogAPI.GetHousingRecipes(). Ce fichier ne fait QUE le
-- rendu — exactement le même schéma que ui/RecipesBar.lua vis-à-vis de
-- ViewerLog_Recette. L'aperçu 3D est lui aussi délégué au module
-- (vlAPI.OpenHousingModelViewer / HideHousingModelViewer).
--
-- RenderRecipeGrid(parent, defs, knownMap, LEFT_PAD, offsetY, contentW)
--   defs     : table  extension -> liste de recettes {name,itemID,spellID,decorID}
--   knownMap : table  [itemID] = bool
-- ====================================================

local ICON_SIZE = 30
local ICON_GAP  = 4

-- Ordre d'affichage des extensions (du plus récent au plus ancien)
local EXPANSION_ORDER = {
    "Midnight", "Khaz Algar", "Dragon Isles", "Shadowlands", "Battle for Azeroth",
    "Legion", "Warlords of Draenor", "Mists of Pandaria", "Cataclysm",
    "Wrath of the Lich King", "Burning Crusade", "Classic",
}

function pluginNs.RenderRecipeGrid(parent, defs, knownMap, LEFT_PAD, offsetY, contentW)
    contentW = contentW or 660
    if not defs then return offsetY end
    knownMap = knownMap or {}

    local gridLeft    = LEFT_PAD + 14
    local gridAvailW  = contentW - gridLeft - 10
    local ICONS_PER_ROW = math.max(4, math.min(12,
        math.floor((gridAvailW + ICON_GAP) / (ICON_SIZE + ICON_GAP))
    ))

    for _, expName in ipairs(EXPANSION_ORDER) do
        local recipes = defs[expName]
        if recipes and #recipes > 0 then
            local color = pluginNs.GetTierColor(expName)

            -- Trait de séparation
            local sepLine = parent:CreateTexture(nil, "ARTWORK")
            sepLine:SetSize(gridAvailW, 1)
            sepLine:SetPoint("TOPLEFT", LEFT_PAD + 14, offsetY - 4)
            sepLine:SetColorTexture(color.r, color.g, color.b, 0.15)
            offsetY = offsetY - 14

            -- Label extension + compteur appris/total
            local knownCount = 0
            for _, recipe in ipairs(recipes) do
                if knownMap[recipe.itemID] then knownCount = knownCount + 1 end
            end

            local secLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            secLabel:SetPoint("TOPLEFT", LEFT_PAD + 14, offsetY)
            secLabel:SetTextColor(color.r * 0.8, color.g * 0.8, color.b * 0.8)
            secLabel:SetText(
                string.format(pluginNs.L("HOUSING_SECTION_LABEL"), expName)
                .. string.format("  |cff555555%d/%d|r", knownCount, #recipes)
            )
            offsetY = offsetY - 20

            local col, row = 0, 0
            for _, recipe in ipairs(recipes) do
                local capturedRecipe = recipe
                local isKnown = knownMap[recipe.itemID] or false

                local iconFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
                iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
                iconFrame:SetPoint(
                    "TOPLEFT",
                    LEFT_PAD + 14 + col * (ICON_SIZE + ICON_GAP),
                    offsetY - row * (ICON_SIZE + ICON_GAP)
                )
                iconFrame:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 2,
                })

                local tex = iconFrame:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", -2, 2)
                tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                local itemIcon = (C_Item.GetItemIconByID and C_Item.GetItemIconByID(recipe.itemID))
                    or (GetItemIcon and GetItemIcon(recipe.itemID))
                tex:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark")

                if isKnown then
                    iconFrame:SetBackdropBorderColor(0.10, 0.85, 0.20, 1)
                    iconFrame:SetBackdropColor(0.04, 0.14, 0.04, 1)
                    tex:SetVertexColor(1, 1, 1)
                else
                    iconFrame:SetBackdropBorderColor(0.70, 0.10, 0.10, 0.9)
                    iconFrame:SetBackdropColor(0.14, 0.04, 0.04, 1)
                    tex:SetVertexColor(0.35, 0.35, 0.35)
                end

                -- Survol -> aperçu 3D fourni par le module ViewerLog_Housing
                iconFrame:SetScript("OnEnter", function(self)
                    if vlAPI and vlAPI.OpenHousingModelViewer then
                        vlAPI.OpenHousingModelViewer(capturedRecipe, self)
                    end
                end)
                iconFrame:SetScript("OnLeave", function()
                    if vlAPI and vlAPI.HideHousingModelViewer then
                        vlAPI.HideHousingModelViewer()
                    end
                end)

                col = col + 1
                if col >= ICONS_PER_ROW then col = 0; row = row + 1 end
            end

            local totalRows = math.ceil(#recipes / ICONS_PER_ROW)
            offsetY = offsetY - totalRows * (ICON_SIZE + ICON_GAP) - 8
        end
    end

    offsetY = offsetY - 4
    return offsetY
end
