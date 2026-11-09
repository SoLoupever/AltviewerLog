local addonName, ns = ...

-- ====================================================
-- CORE/SLASHCMD — Commande slash /av
-- Rôle UNIQUE : déclarer /av et router ses sous-commandes.
--   /av        → ouvre / ferme la fenêtre
--   /av meta   → dump restedXP + guilde
-- Les dépendances ajoutent les leurs via ns.RegisterSlashSub.
-- ====================================================

local subs = {}

-- name : sous-commande en minuscules, fn : callback sans argument
function ns.RegisterSlashSub(name, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then return end
    subs[name] = fn
end

-- /av meta : dump restedXP + guild de tous les persos en DB
ns.RegisterSlashSub("meta", function()
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.IsReady() then
        print("|cffff4444" .. ns.L("SLASH_VLDB_MISSING") .. "|r")
        return
    end
    print("|cff00ccff" .. ns.L("SLASH_META_HEADER") .. "|r")
    vlAPI.ForEachCharacter(function(charName, realmName, data)
        local restedStr = "nil"
        local r = data.rested
        if type(r) == "table" then
            local pct = vlAPI.GetEstimatedRestedPct and vlAPI.GetEstimatedRestedPct(charName, realmName)
            local ago = r.updatedAt and (time() - r.updatedAt) or nil
            restedStr = string.format("raw=%d maxXP=%d resting=%s pct=%s ago=%ss",
                r.currentRestedXP or 0,
                r.maxXP or 0,
                tostring(r.isRestingArea),
                tostring(pct),
                tostring(ago))
        end
        print(string.format(
            "  |cffffd700%s|r @ %s  guild=|cff88ff88%s|r  rested={%s}",
            charName, realmName,
            tostring(data.guild),
            restedStr))
    end)
end)

SLASH_ALTVIEWER1 = "/av"
SlashCmdList["ALTVIEWER"] = function(msg)
    msg = msg and strtrim(msg:lower()) or ""
    local fn = subs[msg]
    if fn then fn() else ns.ToggleMainFrame() end
end
