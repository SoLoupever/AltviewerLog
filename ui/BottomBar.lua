local addonName, ns = ...

-- ====================================================
-- UI/BOTTOMBAR — Barre du bas : conteneur + registre d'items
-- Rôle UNIQUE : afficher les items enregistrés par les
-- dépendances, répartis à largeur égale.
--
-- ns.RegisterBottomItem({
--     priority = 10,                    -- ordre gauche → droite
--     text     = function() return "…" end,   -- libellé (codes couleur OK)
--     tooltip  = function(anchor) … end,      -- optionnel
-- })
-- ====================================================

local BTN_H = 32

local items = {}  -- { priority=, btn=, text= }

local function LayoutBtns()
    local n = #items
    if n == 0 or not ns.mainFrame then return end
    local pad  = ns.LAYOUT.pad
    local btnW = math.floor((ns.mainFrame:GetWidth() - pad * (n + 1)) / n)
    local prev
    for _, it in ipairs(items) do
        it.btn:ClearAllPoints()
        it.btn:SetWidth(btnW)
        if prev then
            it.btn:SetPoint("LEFT", prev, "RIGHT", pad, 0)
        else
            it.btn:SetPoint("LEFT", ns.bottomBar, "LEFT", pad, 0)
        end
        prev = it.btn
    end
end

function ns.RegisterBottomItem(def)
    if type(def) ~= "table" or type(def.text) ~= "function" then return nil end

    local btn = CreateFrame("Button", nil, ns.bottomBar, "BackdropTemplate")
    btn:SetHeight(BTN_H)
    ns.Skin.Button(btn, "bar")

    btn:HookScript("OnEnter", function(self)
        if def.tooltip then def.tooltip(self) end
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetTextColor(unpack(ns.Theme.text))
    btn.fs = fs

    items[#items + 1] = { priority = def.priority or 100, btn = btn, text = def.text }
    table.sort(items, function(a, b) return a.priority < b.priority end)
    LayoutBtns()
    return btn
end

ns.mainFrame:HookScript("OnSizeChanged", LayoutBtns)

local _initFrame = CreateFrame("Frame")
_initFrame:RegisterEvent("PLAYER_LOGIN")
_initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    C_Timer.After(0.1, LayoutBtns)
end)

-- Point d'entrée unique pour rafraîchir tous les items.
function ns.UpdateBottomBar()
    for _, it in ipairs(items) do
        it.btn.fs:SetText(it.text())
    end
end
