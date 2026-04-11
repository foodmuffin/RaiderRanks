local _, ns = ...

local Inspect = {
    queue = {},
    queued = {},
    cache = {},
    cacheByGUID = {},
    requestTimes = {}
}

ns.Inspect = Inspect

local inspectSlots = {
    INVSLOT_HEAD,
    INVSLOT_NECK,
    INVSLOT_SHOULDER,
    INVSLOT_CHEST,
    INVSLOT_WAIST,
    INVSLOT_LEGS,
    INVSLOT_FEET,
    INVSLOT_WRIST,
    INVSLOT_HAND,
    INVSLOT_FINGER1,
    INVSLOT_FINGER2,
    INVSLOT_TRINKET1,
    INVSLOT_TRINKET2,
    INVSLOT_BACK,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND
}

local scanUnits = {
    "player",
    "target",
    "mouseover",
    "focus"
}

for index = 1, 4 do
    scanUnits[#scanUnits + 1] = "party" .. index
end

for index = 1, 40 do
    scanUnits[#scanUnits + 1] = "raid" .. index
end

local function MatchesFullName(unit, fullName)
    if not unit or not UnitExists(unit) then
        return false
    end

    local name, realm = UnitFullName(unit)
    if not name then
        return false
    end

    return ns:ComposeFullName(name, realm) == fullName
end

local function GetDetailedLevelInfo(itemLink)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        return C_Item.GetDetailedItemLevelInfo(itemLink)
    end

    if GetDetailedItemLevelInfo then
        return GetDetailedItemLevelInfo(itemLink)
    end

    return nil
end

function Inspect:IsEnabled()
    return ns.db and ns.db.enableInspectEnrichment
end

function Inspect:Initialize()
    if not ns.db then
        return
    end

    ns.db.inspectCache = ns.db.inspectCache or {}
    ns.db.inspectCache.byName = ns.db.inspectCache.byName or {}
    ns.db.inspectCache.byGUID = ns.db.inspectCache.byGUID or {}

    self.cache = ns.db.inspectCache.byName
    self.cacheByGUID = ns.db.inspectCache.byGUID
end

function Inspect:ResolveUnit(fullName)
    if not fullName then
        return nil
    end

    for index = 1, #scanUnits do
        local unit = scanUnits[index]
        if MatchesFullName(unit, fullName) then
            return unit
        end
    end

    return nil
end

function Inspect:GetPlayerItemLevel()
    local average, equipped = GetAverageItemLevel()
    if type(equipped) == "number" and equipped > 0 then
        return equipped
    end

    if type(average) == "number" and average > 0 then
        return average
    end

    return nil
end

function Inspect:GetPlayerSpec()
    local currentSpec = GetSpecialization and GetSpecialization()
    if not currentSpec then
        return nil
    end

    local specID, specName, _, icon, role = GetSpecializationInfo(currentSpec)
    if not specID then
        return nil
    end

    return {
        specID = specID,
        specName = specName,
        specIcon = icon,
        roleBucket = role == "TANK" and "tank" or role == "HEALER" and "healer" or role == "DAMAGER" and "dps" or "unknown"
    }
end

function Inspect:GetCachedData(fullName, guid)
    if guid and self.cacheByGUID[guid] then
        return self.cacheByGUID[guid]
    end

    return self.cache[fullName]
end

function Inspect:ComputeInspectedItemLevel(unit)
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local value1, value2 = C_PaperDollInfo.GetInspectItemLevel(unit)
        local itemLevel = value2 or value1
        if type(itemLevel) == "number" and itemLevel > 0 then
            return itemLevel
        end
    end

    local total = 0
    local count = 0

    for index = 1, #inspectSlots do
        local link = GetInventoryItemLink(unit, inspectSlots[index])
        if link then
            local itemLevel = GetDetailedLevelInfo(link)
            if type(itemLevel) == "number" and itemLevel > 0 then
                total = total + itemLevel
                count = count + 1
            end
        end
    end

    if count == 0 then
        return nil
    end

    return total / count
end

function Inspect:ApplyLiveData(record)
    if not record then
        return
    end

    local unit = self:ResolveUnit(record.fullName)
    record.unitToken = unit

    if not unit then
        return
    end

    local liveRole = ns:GetRoleBucketFromGroup(unit)
    if liveRole then
        record.roleBucket = liveRole
        record.roleSource = "group"
    end

    if UnitIsUnit(unit, "player") then
        local timestamp = ns:GetCurrentTimestamp()
        local specData = self:GetPlayerSpec()
        if specData then
            record.specID = specData.specID
            record.specName = specData.specName
            record.specIcon = specData.specIcon
            record.specSource = "self"
            record.specObservedAt = timestamp
            record.specIsStale = false
            if record.roleSource ~= "group" and specData.roleBucket ~= "unknown" then
                record.roleBucket = specData.roleBucket
            end
        end

        local itemLevel = self:GetPlayerItemLevel()
        if itemLevel then
            record.equippedItemLevel = itemLevel
            record.itemLevelSource = "self"
            record.itemLevelObservedAt = timestamp
            record.itemLevelIsStale = false
        end
    end
end

function Inspect:ApplyCachedData(record)
    if not record then
        return
    end

    local cached = self:GetCachedData(record.fullName, record.guid)
    if not cached then
        return
    end

    if cached.specID and record.specSource ~= "self" then
        record.specID = cached.specID
        record.specName = cached.specName
        record.specIcon = cached.specIcon
        record.specSource = "inspect"
        record.specObservedAt = cached.specObservedAt or cached.observedAt
        record.specIsStale = ns:IsDataStale(record.specObservedAt)
    end

    if cached.itemLevel and record.itemLevelSource ~= "self" then
        record.equippedItemLevel = cached.itemLevel
        record.itemLevelSource = "inspect"
        record.itemLevelObservedAt = cached.itemLevelObservedAt or cached.observedAt
        record.itemLevelIsStale = ns:IsDataStale(record.itemLevelObservedAt)
    end

    if cached.roleBucket and record.roleSource ~= "group" then
        record.roleBucket = cached.roleBucket
    end
end

function Inspect:QueueRecord(record)
    if not record or not self:IsEnabled() then
        return
    end

    if record.itemLevelSource == "self" then
        return
    end

    local unit = record.unitToken or self:ResolveUnit(record.fullName)
    if not unit or UnitIsUnit(unit, "player") then
        return
    end

    if not CanInspect(unit, false) or not CheckInteractDistance(unit, 1) then
        return
    end

    local now = GetTime()
    if self.requestTimes[record.fullName] and now - self.requestTimes[record.fullName] < 10 then
        return
    end

    if self.queued[record.fullName] then
        return
    end

    self.queued[record.fullName] = true
    self.requestTimes[record.fullName] = now
    table.insert(self.queue, {
        unit = unit,
        fullName = record.fullName,
        guid = UnitGUID(unit)
    })

    self:ProcessQueue()
end

function Inspect:CompletePending(payload)
    local pending = self.pending
    self.pending = nil

    if pending then
        self.queued[pending.fullName] = nil
    end

    ClearInspectPlayer()

    if pending and payload and next(payload) then
        self.cache[pending.fullName] = payload
        if pending.guid then
            self.cacheByGUID[pending.guid] = payload
        end

        if ns.Data and ns.Data.OnInspectDataReady then
            ns.Data:OnInspectDataReady(pending.fullName, pending.guid, payload)
        end
    elseif pending and ns.Data and ns.Data.OnInspectTimeout then
        ns.Data:OnInspectTimeout(pending.fullName, pending.guid)
    end

    C_Timer.After(0.15, function()
        Inspect:ProcessQueue()
    end)
end

function Inspect:ProcessQueue()
    if self.pending or not self:IsEnabled() or InCombatLockdown() then
        return
    end

    local request = table.remove(self.queue, 1)
    if not request then
        return
    end

    if not MatchesFullName(request.unit, request.fullName) then
        self.queued[request.fullName] = nil
        C_Timer.After(0.05, function()
            Inspect:ProcessQueue()
        end)
        return
    end

    self.pending = request
    NotifyInspect(request.unit)

    C_Timer.After(1.5, function()
        if Inspect.pending == request then
            Inspect:CompletePending(nil)
        end
    end)
end

local function HandleInspectReady(guid)
    local pending = Inspect.pending
    if not pending or (pending.guid and guid ~= pending.guid) then
        return
    end

    local unit = pending.unit
    local payload = {}
    local observedAt = ns:GetCurrentTimestamp()
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if specID and specID > 0 then
        local _, specName, _, icon, role = GetSpecializationInfoByID(specID)
        payload.specID = specID
        payload.specName = specName
        payload.specIcon = icon
        payload.roleBucket = role == "TANK" and "tank" or role == "HEALER" and "healer" or role == "DAMAGER" and "dps" or "unknown"
        payload.specObservedAt = observedAt
    end

    local itemLevel = Inspect:ComputeInspectedItemLevel(unit)
    if itemLevel then
        payload.itemLevel = itemLevel
        payload.itemLevelObservedAt = observedAt
    end

    if next(payload) then
        payload.observedAt = observedAt
    end

    Inspect:CompletePending(payload)
end

ns:RegisterCallback("ADDON_READY", function()
    Inspect:Initialize()
end)

ns:RegisterEvent("INSPECT_READY", HandleInspectReady)
