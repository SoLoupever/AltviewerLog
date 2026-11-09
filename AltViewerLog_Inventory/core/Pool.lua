local addonName, ns = ...
local core = ns.core

-- ====================================================
-- CORE/POOL — Pool de boutons d'items + sélection
-- Rôle UNIQUE : recycler les boutons des vues d'items.
-- Libération branchée sur ClearContent du noyau.
-- ====================================================

-- ── Sélection ─────────────────────────────────────────────────────
local selected = nil
function ns.AVL_GetSelected() return selected end
function ns.AVL_Deselect() selected = nil end

-- ── Pool ──────────────────────────────────────────────────────────
local btnPool, activeFrames = {}, {}

function ns.AcquireButton(parent)
    local f = table.remove(btnPool)
    if f then
        f:SetParent(parent); f:ClearAllPoints()
    else
        f = CreateFrame("Button", nil, parent)
        f.ico = f:CreateTexture(nil, "BACKGROUND"); f.ico:SetAllPoints()
        f.countText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        f.countText:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    f:Show()
    activeFrames[#activeFrames + 1] = f
    return f
end

local function ReleaseActiveFrames()
    for _, f in ipairs(activeFrames) do
        f:Hide()
        f:SetScript("OnClick",  nil)
        f:SetScript("OnEnter",  nil)
        f:SetScript("OnLeave",  nil)
        if core.CatDnD then core.CatDnD.Detach(f) end
        btnPool[#btnPool + 1] = f
    end
    activeFrames = {}
end

core.RegisterContentCleaner(function()
    ns.AVL_Deselect()
    ReleaseActiveFrames()
end)
