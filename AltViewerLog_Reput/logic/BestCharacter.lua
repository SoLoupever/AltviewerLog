local addonName, pluginNs = ...

-- LOGIC / BEST CHARACTER
-- Délégué vers ViewerLogAPI.GetBestReputationCharacter (source unique,
-- côté ViewerLog_Reput). Retourne charName, realm, classFile, data.

function pluginNs.GetBestCharacter(fid)
    local api = _G.ViewerLogAPI
    if api and api.GetBestReputationCharacter then
        return api.GetBestReputationCharacter(fid)
    end
    return nil
end
