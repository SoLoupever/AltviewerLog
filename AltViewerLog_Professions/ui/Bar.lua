local addonName, pluginNs = ...

-- ====================================================
-- BARRE DE PROGRESSION STYLE BLIZZARD NATIF
-- Utilise les mêmes textures que l'UI Blizzard :
--   ProfessionsBook           → fond + embouts gauche/droite
--   Professions-Progress-Fill → remplissage
--
-- Retourne (barContainer, pct)
-- ====================================================
function pluginNs.CreateNativeProgressBar(parent, x, y, current, maxVal, rankText, barWidth)
    local BAR_H   = pluginNs.BAR_H  -- 16px
    local safeMax = (maxVal and maxVal > 0) and maxVal or 1
    local safeCur = current or 0
    local pct     = math.min(safeCur / safeMax, 1)
    local isFull  = (pct >= 1)

    -- Conteneur principal
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(barWidth, BAR_H)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    -- ── Fond central (milieu de la barre) ─────────────
    local bgMid = container:CreateTexture(nil, "BACKGROUND")
    bgMid:SetAllPoints()
    bgMid:SetTexture("Interface\\Spellbook\\ProfessionsBook")
    bgMid:SetTexCoord(0.00000000, 1.00000000, 0.00781250, 0.13281250)

    -- ── Embout gauche fond ────────────────────────────
    local bgLeft = container:CreateTexture(nil, "BACKGROUND")
    bgLeft:SetSize(16, 16)
    bgLeft:SetPoint("RIGHT", container, "LEFT", 0, 2)
    bgLeft:SetTexture("Interface\\Spellbook\\ProfessionsBook")
    bgLeft:SetTexCoord(0.00390625, 0.06640625, 0.48437500, 0.60937500)

    -- ── Embout droit fond ─────────────────────────────
    local bgRight = container:CreateTexture(nil, "BACKGROUND")
    bgRight:SetSize(16, 16)
    bgRight:SetPoint("LEFT", container, "RIGHT", 0, 2)
    bgRight:SetTexture("Interface\\Spellbook\\ProfessionsBook")
    bgRight:SetTexCoord(0.00390625, 0.06640625, 0.62500000, 0.75000000)

    -- ── StatusBar (remplissage natif Blizzard) ────────
    local bar = CreateFrame("StatusBar", nil, container)
    bar:SetAllPoints()
    bar:SetStatusBarTexture("Interface\\Spellbook\\Professions-Progress-Fill")
    bar:SetMinMaxValues(0, safeMax)
    bar:SetValue(safeCur)

    -- ── Embout gauche overlay ─────────────────────────
    local ovLeft = container:CreateTexture(nil, "OVERLAY")
    ovLeft:SetSize(12, 12)
    ovLeft:SetPoint("RIGHT", container, "LEFT", 0, 2)
    ovLeft:SetTexture("Interface\\Spellbook\\ProfessionsBook")
    ovLeft:SetTexCoord(0.00390625, 0.05078125, 0.87500000, 0.96875000)

    -- ── Embout droit overlay (affiché seulement au max) ──
    local ovRight = container:CreateTexture(nil, "OVERLAY")
    ovRight:SetSize(12, 12)
    ovRight:SetPoint("LEFT", container, "RIGHT", 0, 2)
    ovRight:SetTexture("Interface\\Spellbook\\ProfessionsBook")
    ovRight:SetTexCoord(0.00390625, 0.05078125, 0.76562500, 0.85937500)
    ovRight:SetShown(isFull)

    -- ── Texte centré sur la barre ─────────────────────
    local rankFS = container:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    rankFS:SetPoint("CENTER", 0, 2)
    rankFS:SetText(rankText or string.format("%d/%d", safeCur, safeMax))

    return container, pct
end

-- ====================================================
-- ALIAS : conserve la compatibilité avec les anciens
-- appels CreateBlizzardStyleBar (si encore utilisés).
-- ====================================================
function pluginNs.CreateBlizzardStyleBar(parent, x, y, tier, barWidth)
    local rankStr
    if (tier.max > 0) and (tier.level >= tier.max) then
        rankStr = (tier.name or "") .. "  MAX ✓"
    else
        rankStr = string.format("%s  %d/%d", tier.name or "", tier.level or 0, tier.max or 0)
    end
    return pluginNs.CreateNativeProgressBar(
        parent, x, y,
        tier.level or 0,
        tier.max   or 0,
        rankStr,
        barWidth)
end
