local addonName, ns = ...

-- Formatage monétaire (le global GetCoinTextureString n'existe plus)
function ns.FormatMoney(amount)
    amount = amount or 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(amount)
    end
    return math.floor(amount / 10000) .. "g"
end
