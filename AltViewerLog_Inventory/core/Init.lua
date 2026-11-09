local addonName, ns = ...

-- ====================================================
-- CORE/INIT — Namespace de la dépendance Inventaire
-- Lecture : repli sur le noyau (AltViewerLogAPI) via __index.
-- Écriture : toujours locale à cet addon. L'état du noyau
-- (currentView…) est modifié explicitement via ns.core.
-- ====================================================

local core = _G.AltViewerLogAPI
ns.core = core
setmetatable(ns, { __index = core })
