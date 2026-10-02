local addonName, ns = ...

-- ====================================================
-- CATEGORY MANAGER — fenêtre "Ordre des catégories"
-- Rôle UNIQUE : fenêtre (dans mainFrame) pour ajouter / supprimer /
-- réordonner les catégories et y assigner des items par ID.
-- Toute la donnée passe par ns.Cat ; la fenêtre ne connaît pas les
-- vues : elle reçoit (store, refreshFn, getLive) à l'ouverture et
-- se re-synchronise via ns.CatManager.Notify depuis la vue active.
--
-- API :
--   ns.ToggleCatOrderPanel(anchor, store, refreshFn, liveBuckets, liveOrder)
--       liveBuckets : table de buckets OU fonction → buckets, order
--   ns.CatManager.CreateGearButton(parent, onClick) → bouton (mis en cache)
--   ns.CatManager.Notify(store, refreshFn, getLive)  (vue → fenêtre)
-- ====================================================

local CatManager = {}
ns.CatManager = CatManager

local WHITE = "Interface\\Buttons\\WHITE8x8"
local ARROW = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"
local W, H        = 440, 530
local ROW_H       = 26
local LIST_H      = 230
local ICON, ICON_GAP, ICON_COLS, ICON_ROWS = 24, 2, 15, 3

local win, ctx
local rows, itemBtns = {}, {}
local keys = {}
local listScroll, dropLine
local justDragged = false
local errFS, itemErrFS, listChild, itemTitleFS, moreFS, nameEdit, itemEdit

local function Cat() return ns.Cat end

local function GetLive()
    if not ctx or not ctx.getLive then return {}, {} end
    local b, o = ctx.getLive()
    return b or {}, o or {}
end

local function ItemInfoOK(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    return f and f(id) ~= nil
end

local Rebuild  -- déclarée plus bas

local function Refresh()
    if ctx and ctx.refresh then ctx.refresh() end
    Rebuild()
end

local function MoveKey(from, to)
    if from == to or not keys[from] then return end
    local k = table.remove(keys, from)
    table.insert(keys, to, k)
    Cat().SetOrder(ctx.store, keys)
    Refresh()
end

-- ── Style commun ────────────────────────────────────────────────
local function Backdrop(f, r, g, b, a, br, bg, bb, ba)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br, bg, bb, ba)
end

local function MiniButton(parent, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 1, 1, 0.18)
    return b
end

-- ── Ghost de drag d'une ligne ───────────────────────────────────
local rowGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
rowGhost:SetSize(220, 22)
rowGhost:SetFrameStrata("TOOLTIP")
rowGhost:EnableMouse(false)
Backdrop(rowGhost, 0.18, 0.18, 0.22, 0.95, 0.40, 0.40, 0.50, 0.9)
rowGhost.fs = rowGhost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rowGhost.fs:SetPoint("LEFT", 8, 0)
rowGhost:Hide()
local rowDrag = CreateFrame("Frame")
local dragFrom

local function RowDragEnd()
    if not dragFrom then return end
    local from = dragFrom
    dragFrom = nil
    rowDrag:SetScript("OnUpdate", nil)
    rowGhost:Hide()
    if dropLine then dropLine:Hide() end
    if rows[from] then rows[from]:SetAlpha(1) end
    for j = 1, #keys do
        local r = rows[j]
        if r and r:IsShown() and r:IsMouseOver() then MoveKey(from, j); return end
    end
end

local function RowDragTick()
    local s = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    rowGhost:ClearAllPoints()
    rowGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / s, cy / s)
    if not IsMouseButtonDown("LeftButton") then RowDragEnd(); return end

    -- Défilement auto quand le curseur approche des bords de la liste
    local top, bottom = listScroll:GetTop(), listScroll:GetBottom()
    local y = cy / listScroll:GetEffectiveScale()
    local range = listScroll:GetVerticalScrollRange() or 0
    if top and range > 0 then
        local cur = listScroll:GetVerticalScroll()
        if y > top - 14 then listScroll:SetVerticalScroll(math.max(0, cur - 6))
        elseif y < bottom + 14 then listScroll:SetVerticalScroll(math.min(range, cur + 6)) end
    end

    -- Repère d'insertion : au-dessus de la ligne visée si on monte, en dessous si on descend
    dropLine:Hide()
    for j = 1, #keys do
        local r = rows[j]
        if r and r:IsShown() and r:IsMouseOver() and j ~= dragFrom then
            dropLine:ClearAllPoints()
            local edge = (j < dragFrom) and "TOPLEFT" or "BOTTOMLEFT"
            local edgeR = (j < dragFrom) and "TOPRIGHT" or "BOTTOMRIGHT"
            dropLine:SetPoint("LEFT", r, edge, 0, 0)
            dropLine:SetPoint("RIGHT", r, edgeR, 0, 0)
            dropLine:Show()
            break
        end
    end
end

-- ── Lignes de la liste ──────────────────────────────────────────
local function GetRow(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, listChild)
    row:SetHeight(ROW_H - 2)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    row.fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.fs:SetPoint("LEFT", 8, 0)
    row.fs:SetJustifyH("LEFT")

    row.del = MiniButton(row, 18, 18)
    row.del:SetPoint("RIGHT", -4, 0)
    row.del.fs = row.del:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.del.fs:SetPoint("CENTER", 0, 1); row.del.fs:SetText("|cffcc4444x|r")

    row.down = MiniButton(row, 18, 18)
    row.down:SetPoint("RIGHT", -26, 0)
    row.down.tex = row.down:CreateTexture(nil, "ARTWORK"); row.down.tex:SetAllPoints()
    row.down.tex:SetTexture(ARROW)

    row.up = MiniButton(row, 18, 18)
    row.up:SetPoint("RIGHT", -46, 0)
    row.up.tex = row.up:CreateTexture(nil, "ARTWORK"); row.up.tex:SetAllPoints()
    row.up.tex:SetTexture(ARROW); row.up.tex:SetTexCoord(0, 1, 1, 0)   -- flèche vers le haut

    row.fs:SetPoint("RIGHT", row.up, "LEFT", -4, 0)

    local function tip(btn, key)
        btn:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.L(key), 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
    end
    tip(row.up, "CATMGR_MOVE_UP"); tip(row.down, "CATMGR_MOVE_DOWN"); tip(row.del, "CATMGR_DELETE")

    row.up:SetScript("OnClick",   function() MoveKey(row.idx, row.idx - 1) end)
    row.down:SetScript("OnClick", function() MoveKey(row.idx, row.idx + 1) end)
    row.del:SetScript("OnClick", function()
        local k = keys[row.idx]
        if not k or not Cat().IsCustomKey(k) then return end
        Cat().RemoveCategory(ctx.store, Cat().CustomName(k))
        if ctx.selected == k then ctx.selected = nil end
        Refresh()
    end)
    -- Sélection au relâchement : reconstruire la liste au mouse down
    -- cacherait la ligne attrapée et annulerait le drag.
    row:SetScript("OnMouseDown", function() justDragged = false end)
    row:SetScript("OnMouseUp", function(s, btn)
        if btn ~= "LeftButton" or justDragged then return end
        ctx.selected = keys[s.idx]
        Rebuild()
    end)
    row:SetScript("OnDragStart", function(s)
        justDragged = true
        dragFrom = s.idx
        s:SetAlpha(0.4)
        rowGhost.fs:SetText(s.fs:GetText())
        rowGhost:Show()
        rowDrag:SetScript("OnUpdate", RowDragTick)
    end)
    row:SetScript("OnDragStop", RowDragEnd)
    rows[i] = row
    return row
end

-- ── Grille d'items de la catégorie sélectionnée ─────────────────
local function GetItemBtn(i)
    local b = itemBtns[i]
    if b then return b end
    b = CreateFrame("Button", nil, win)
    b:SetSize(ICON, ICON)
    b.ico = b:CreateTexture(nil, "BACKGROUND"); b.ico:SetAllPoints()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 0.3, 0.3, 0.35)
    local col, row = (i - 1) % ICON_COLS, math.floor((i - 1) / ICON_COLS)
    b:SetPoint("TOPLEFT", win, "TOPLEFT", 14 + col * (ICON + ICON_GAP), -386 - row * (ICON + ICON_GAP))
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(s.itemID)
        GameTooltip:AddLine(ns.L("CATMGR_ITEM_REMOVE_TT"), 1, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(s)
        GameTooltip:Hide()
        Cat().Unassign(ctx.store, s.itemID)
        Refresh()
    end)
    itemBtns[i] = b
    return b
end

local function RebuildItems()
    for _, b in ipairs(itemBtns) do b:Hide() end
    moreFS:SetText("")
    local sel = ctx.selected
    if not sel then
        itemTitleFS:SetText("|cff888888" .. ns.L("CATMGR_SELECT_HINT") .. "|r")
        return
    end
    local buckets = GetLive()
    local b = buckets[sel]
    local label = b and b.label or (Cat().IsCustomKey(sel) and Cat().CustomLabel(Cat().CustomName(sel)))
                  or Cat().LabelForKey(sel)
    itemTitleFS:SetText(ns.L("CATMGR_ITEMS_OF"):format(label))
    local ids = Cat().ItemsOf(ctx.store, sel)
    local cap = ICON_COLS * ICON_ROWS
    for i = 1, math.min(#ids, cap) do
        local btn = GetItemBtn(i)
        btn.itemID = ids[i]
        btn.ico:SetTexture(ns.GetIcon(ids[i]))
        btn:Show()
    end
    if #ids > cap then moreFS:SetText(ns.L("CATMGR_MORE"):format(#ids - cap)) end
end

-- ── Reconstruction complète ─────────────────────────────────────
Rebuild = function()
    if not win or not win:IsShown() or not ctx then return end
    local buckets, order = GetLive()
    keys = Cat().Order(ctx.store, buckets, order)
    -- catégories custom connues du store mais absentes des buckets live
    local present = {}
    for _, k in ipairs(keys) do present[k] = true end
    for name in pairs(ctx.store.customCategories) do
        local k = Cat().CustomKey(name)
        if not present[k] then keys[#keys + 1] = k end
    end
    if ctx.selected and not present[ctx.selected]
       and not (Cat().IsCustomKey(ctx.selected)
                and ctx.store.customCategories[Cat().CustomName(ctx.selected)]) then
        ctx.selected = nil
    end

    for i = #keys + 1, #rows do rows[i]:Hide() end
    for i, k in ipairs(keys) do
        local row = GetRow(i)
        local b = buckets[k]
        local isCustom = Cat().IsCustomKey(k)
        local label = b and b.label
            or (isCustom and Cat().CustomLabel(Cat().CustomName(k)))
            or Cat().LabelForKey(k)
        row.idx = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", -2, -(i - 1) * ROW_H)
        row.fs:SetText(label .. (b and (" |cff4da6ff(" .. #b.items .. ")|r") or ""))
        if ctx.selected == k then row.bg:SetColorTexture(0.22, 0.20, 0.08, 0.85)
        else row.bg:SetColorTexture(0.10, 0.10, 0.12, 0.60) end
        row.del:SetShown(isCustom)
        row.up:SetAlpha(i == 1 and 0.25 or 1)
        row.down:SetAlpha(i == #keys and 0.25 or 1)
        row:Show()
    end
    listChild:SetHeight(math.max(1, #keys * ROW_H))
    RebuildItems()
end

-- ── Création de la fenêtre (à la première ouverture) ────────────
local function Build()
    win = CreateFrame("Frame", "AVL_CatManager", ns.mainFrame, "BackdropTemplate")
    win:SetSize(W, H)
    win:SetPoint("CENTER", ns.mainFrame, "CENTER", 0, 0)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(s) s:StartMoving() end)
    win:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    Backdrop(win, 0.06, 0.06, 0.08, 0.98, 0.45, 0.35, 0.10, 1)
    win:Hide()

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffd0d0ff" .. ns.L("CATMGR_TITLE") .. "|r")

    local close = MiniButton(win, 18, 18)
    close:SetPoint("TOPRIGHT", -6, -6)
    close.fs = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    close.fs:SetPoint("CENTER", 0, 1); close.fs:SetText("|cffcc4444x|r")
    close:SetScript("OnClick", function() win:Hide() end)

    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 14, -32)
    hint:SetText(ns.L("CATMGR_HINT"))

    -- Liste des catégories
    local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -52)
    scroll:SetSize(W - 38, LIST_H)
    listChild = CreateFrame("Frame", nil, scroll)
    listChild:SetSize(W - 38, 1)
    scroll:SetScrollChild(listChild)
    listScroll = scroll
    dropLine = listChild:CreateTexture(nil, "OVERLAY")
    dropLine:SetHeight(2)
    dropLine:SetColorTexture(1, 0.82, 0.1, 1)
    dropLine:Hide()
    if ns.SkinScrollBar then ns.SkinScrollBar(scroll) end

    -- Ajout d'une catégorie
    local nameLbl = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameLbl:SetPoint("TOPLEFT", 14, -292)
    nameLbl:SetText(ns.L("CATMGR_NEW_NAME"))

    nameEdit = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
    nameEdit:SetSize(280, 22)
    nameEdit:SetPoint("TOPLEFT", 20, -308)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(30)

    local addBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    addBtn:SetSize(110, 22)
    addBtn:SetPoint("LEFT", nameEdit, "RIGHT", 8, 0)
    addBtn:SetText(ns.L("CATMGR_ADD_BTN"))

    errFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    errFS:SetPoint("TOPLEFT", 14, -334)

    local function DoAdd()
        local key, err = Cat().AddCategory(ctx.store, nameEdit:GetText())
        if not key then errFS:SetText("|cffff5555" .. ns.L(err) .. "|r"); return end
        errFS:SetText("")
        nameEdit:SetText(""); nameEdit:ClearFocus()
        ctx.selected = key
        Refresh()
    end
    addBtn:SetScript("OnClick", DoAdd)
    nameEdit:SetScript("OnEnterPressed", DoAdd)

    -- Séparateur + section items
    local sep = win:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 12, -354); sep:SetPoint("TOPRIGHT", -12, -354)
    sep:SetHeight(1); sep:SetColorTexture(0.35, 0.30, 0.12, 0.8)

    itemTitleFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemTitleFS:SetPoint("TOPLEFT", 14, -364)
    moreFS = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moreFS:SetPoint("TOPRIGHT", -14, -364)

    -- Ajout d'un item par ID
    local idLbl = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idLbl:SetPoint("TOPLEFT", 14, -474)
    idLbl:SetText(ns.L("CATMGR_ITEM_ID"))

    itemEdit = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
    itemEdit:SetSize(150, 22)
    itemEdit:SetPoint("TOPLEFT", 104, -468)
    itemEdit:SetAutoFocus(false)
    itemEdit:SetMaxLetters(80)   -- ID seul ou lien d'item collé

    local itemBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    itemBtn:SetSize(150, 22)
    itemBtn:SetPoint("LEFT", itemEdit, "RIGHT", 8, 0)
    itemBtn:SetText(ns.L("CATMGR_ITEM_ADD"))

    itemErrFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemErrFS:SetPoint("TOPLEFT", 14, -496)

    local function DoAddItem()
        local text = itemEdit:GetText() or ""
        local id = tonumber(text) or tonumber(text:match("item:(%d+)"))
        if not ctx.selected then itemErrFS:SetText("|cffff5555" .. ns.L("CATMGR_ERR_NO_SEL") .. "|r"); return end
        if not id or not ItemInfoOK(id) then itemErrFS:SetText("|cffff5555" .. ns.L("CATMGR_ERR_BAD_ITEM") .. "|r"); return end
        itemErrFS:SetText("")
        Cat().Assign(ctx.store, id, ctx.selected)
        itemEdit:SetText(""); itemEdit:ClearFocus()
        Refresh()
    end
    itemBtn:SetScript("OnClick", DoAddItem)
    itemEdit:SetScript("OnEnterPressed", DoAddItem)

    win:SetScript("OnHide", function()
        rowDrag:SetScript("OnUpdate", nil); rowGhost:Hide(); dropLine:Hide()
        if dragFrom and rows[dragFrom] then rows[dragFrom]:SetAlpha(1) end
        dragFrom = nil
    end)
end

-- ── API publique ────────────────────────────────────────────────
local function Bind(store, refresh, live1, live2)
    local getLive = live1
    if type(live1) ~= "function" then
        getLive = function() return live1, live2 end
    end
    local sameStore = ctx and ctx.store == store
    ctx = { store = store, refresh = refresh, getLive = getLive,
            selected = sameStore and ctx.selected or nil }
    Cat().Ensure(store)
end

function ns.OpenCatOrderPanel(anchor, store, refresh, live1, live2)
    if not win then Build() end
    Bind(store, refresh, live1, live2)
    errFS:SetText(""); itemErrFS:SetText("")
    win:Show()
    Rebuild()
end

function ns.ToggleCatOrderPanel(anchor, store, refresh, live1, live2)
    if win and win:IsShown() and ctx and ctx.store == store then
        win:Hide()
    else
        ns.OpenCatOrderPanel(anchor, store, refresh, live1, live2)
    end
end

-- Une vue qui vient de se (re)dessiner re-synchronise la fenêtre
-- si elle est ouverte (changement de personnage, de banque…).
function CatManager.Notify(store, refresh, getLive)
    if not (win and win:IsShown()) then return end
    Bind(store, refresh, getLive)
    Rebuild()
end

-- Bouton engrenage partagé (un seul par parent, recyclé entre rendus).
function CatManager.CreateGearButton(parent, onClick)
    local b = parent._avlCatGear
    if not b then
        b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        b:SetSize(22, 22)
        Backdrop(b, 0.20, 0.18, 0.10, 0.9, 0.70, 0.60, 0.25, 0.9)
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 3, -3); t:SetPoint("BOTTOMRIGHT", -3, 3)
        t:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        t:SetVertexColor(1, 0.85, 0)
        b:SetScript("OnEnter", function(s)
            s:SetBackdropColor(0.32, 0.28, 0.12, 1)
            GameTooltip:SetOwner(s, "ANCHOR_LEFT")
            GameTooltip:AddLine(ns.L("TT_CATEGORY_ORDER"), 1, 1, 0.5)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropColor(0.20, 0.18, 0.10, 0.9)
            GameTooltip:Hide()
        end)
        parent._avlCatGear = b
    end
    b:SetScript("OnClick", onClick)
    b:Show()
    return b
end

-- Fermeture avec les autres popups (changement de vue via la sidebar),
-- chaîné sans écraser un handler existant.
local _prevClose = ns.CloseModulePopups
ns.CloseModulePopups = function()
    if _prevClose then _prevClose() end
    if win and win:IsShown() then win:Hide() end
end
