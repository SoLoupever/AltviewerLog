local addonName, ns = ...

-- Wrappers API item (globals retirés → C_Item)
local C = C_Item or {}

local function Pick(name)
    local f = C[name] or _G[name]
    return function(...)
        if f then return f(...) end
    end
end

ns.GetItemInfoInstant  = Pick("GetItemInfoInstant")
ns.GetItemInfo         = Pick("GetItemInfo")
ns.GetItemClassInfo    = Pick("GetItemClassInfo")
ns.GetItemSubClassInfo = Pick("GetItemSubClassInfo")
