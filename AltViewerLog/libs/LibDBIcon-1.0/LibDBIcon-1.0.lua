-- LibDBIcon-1.0 (r44 / public domain)
local DBICON10, DBICON10_MINOR = "LibDBIcon-1.0", 44
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects    = lib.objects    or {}
lib.notCreated = lib.notCreated or {}

local function updatePosition(btn, db)
    local angle = math.rad(db.minimapPos or 225)
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function onDragStart(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function(s)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        local angle  = math.atan2(py / scale - my, px / scale - mx)
        s:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
        s.db.minimapPos = math.deg(angle) % 360
    end)
end

local function onDragStop(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end

local function createButton(name, object, db)
    local btn = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetSize(31, 31)
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Bordure circulaire minimap
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    -- Icône
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 1)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetTexture(object.icon)
    btn.icon = icon

    btn:SetScript("OnEnter", function(self)
        if object.OnTooltipShow then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            object.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave",    function() GameTooltip:Hide() end)
    btn:SetScript("OnClick",    function(self, b) if object.OnClick then object.OnClick(self, b) end end)
    btn:SetScript("OnDragStart", onDragStart)
    btn:SetScript("OnDragStop",  onDragStop)

    btn.db = db
    updatePosition(btn, db)
    btn:Show()
    return btn
end

function lib:Register(name, object, db)
    assert(type(name) == "string")
    assert(type(object) == "table")
    db = db or {}
    db.minimapPos = db.minimapPos or 225
    if db.hide then
        lib.notCreated[name] = { object = object, db = db }
        return
    end
    local btn = createButton(name, object, db)
    lib.objects[name] = { button = btn, db = db, object = object }
    return btn
end

function lib:Show(name)
    if lib.objects[name] then lib.objects[name].button:Show() end
end

function lib:Hide(name)
    if lib.objects[name] then lib.objects[name].button:Hide() end
end

function lib:IsRegistered(name)
    return lib.objects[name] ~= nil or lib.notCreated[name] ~= nil
end

function lib:Refresh(name, db)
    local data = lib.objects[name]
    if not data then return end
    if db then data.db = db end
    updatePosition(data.button, data.db)
    if data.db.hide then data.button:Hide() else data.button:Show() end
end

function lib:GetMinimapButton(name)
    return lib.objects[name] and lib.objects[name].button
end
