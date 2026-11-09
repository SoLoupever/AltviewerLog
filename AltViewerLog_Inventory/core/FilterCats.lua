local addonName, ns = ...

-- ====================================================
-- CORE/FILTERCATS — Catégories de filtre de la recherche
-- Initialisées au PLAYER_LOGIN (traductions disponibles).
-- ns.activeFilterCat : catégorie active (nil = toutes).
-- ====================================================

ns.FILTER_CATS    = {}
ns.activeFilterCat = nil

local function InitFilterCats()
    ns.FILTER_CATS = {
        { key="ALL",           label=ns.L("FILTER_ALL"),         classID=nil, subClassID=nil, invType=nil },
        { key="CONSOMABLE",    label=ns.L("FILTER_CONSUMABLE"),  classID=0,   subClassID=nil, invType=nil },
        { key="ARME",          label=ns.L("FILTER_WEAPON"),      classID=2,   subClassID=nil, invType=nil },
        { key="ARMURE",        label=ns.L("FILTER_ARMOR"),       classID=4,   subClassID=nil, invType=nil },
        { key="ARMURE_TISSU",  label=ns.L("FILTER_CLOTH"),       classID=4,   subClassID=1,   invType=nil },
        { key="ARMURE_CUIR",   label=ns.L("FILTER_LEATHER"),     classID=4,   subClassID=2,   invType=nil },
        { key="ARMURE_MAILLE", label=ns.L("FILTER_MAIL"),        classID=4,   subClassID=3,   invType=nil },
        { key="ARMURE_PLAQUE", label=ns.L("FILTER_PLATE"),       classID=4,   subClassID=4,   invType=nil },
        { key="TETE",          label=ns.L("FILTER_HEAD"),        classID=nil, subClassID=nil, invType="INVTYPE_HEAD" },
        { key="DOS",           label=ns.L("FILTER_CLOAK"),       classID=nil, subClassID=nil, invType="INVTYPE_CLOAK" },
        { key="QUETE",         label=ns.L("FILTER_QUEST"),       classID=12,  subClassID=nil, invType=nil },
        { key="REACTIF",       label=ns.L("FILTER_REAGENT"),     classID=5,   subClassID=nil, invType=nil },
    }
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    InitFilterCats()
end)
