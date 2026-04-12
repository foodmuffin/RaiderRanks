local _, ns = ...

local Comm = {
    prefix = "RaiderRanks",
    protocol = "RR1",
    snapshotTTLSeconds = 7 * 24 * 60 * 60,
    activeRunTTLSeconds = 90 * 60,
    outboundQueue = {},
    lastSentSignatures = {},
    activeRunSources = {},
    activeRunParticipants = {},
    sessionReporters = {},
    sessionReporterCount = 0,
    newerManifestBySender = {},
    refreshPending = false,
    refreshReason = nil,
    state = {
        grouped = false,
        inInstance = false,
        instanceType = "none",
        challengeActive = false,
        ownedKeySignature = ""
    }
}

ns.Comm = Comm

local roleCodeByBucket = {
    tank = "T",
    healer = "H",
    dps = "D",
    unknown = "U"
}

local roleBucketByCode = {
    T = "tank",
    H = "healer",
    D = "dps",
    U = "unknown"
}

local regionCodeByName = {
    Americas = "A",
    Europe = "E",
    Korea = "K",
    Taiwan = "T",
    China = "C"
}

local regionNameByCode = {
    A = "Americas",
    E = "Europe",
    K = "Korea",
    T = "Taiwan",
    C = "China"
}

local typeCodeByName = {
    ["Mythic Plus"] = "M",
    Raiding = "R",
    Recruitment = "C"
}

local typeNameByCode = {
    M = "Mythic Plus",
    R = "Raiding",
    C = "Recruitment"
}

local snapshotFieldCount = 17
local activityFieldCount = 7

local function IsGrouped()
    return IsInGroup() or IsInRaid()
end

local function IsChallengeActive()
    return C_ChallengeMode
        and type(C_ChallengeMode.IsChallengeModeActive) == "function"
        and C_ChallengeMode.IsChallengeModeActive()
        or false
end

local function GetInstanceState()
    local inInstance, instanceType = IsInInstance()
    return not not inInstance, instanceType or "none"
end

local function GetChallengeMapInfo(mapID)
    if not mapID
        or not C_ChallengeMode
        or type(C_ChallengeMode.GetMapUIInfo) ~= "function" then
        return nil, nil, nil
    end

    local mapName, _, _, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapID)
    return mapName, texture, backgroundTexture
end

local function BuildOwnedKeySignature(keyInfo)
    local mapID = keyInfo and tonumber(keyInfo.mapID) or nil
    local level = keyInfo and tonumber(keyInfo.level) or nil
    if not mapID or mapID <= 0 or not level or level <= 0 then
        return ""
    end

    return ("%d:%d"):format(mapID, level)
end

local function FormatManifestTimestamp(raw)
    if type(raw) ~= "string" then
        return nil
    end

    local year, month, day, hour, minute = raw:match("^(%d%d%d%d)(%d%d)(%d%d)(%d%d)(%d%d)$")
    if not year then
        return nil
    end

    return ("%s-%s-%s %s:%s"):format(year, month, day, hour, minute)
end

local function SortDatasets(datasets)
    table.sort(datasets, function(left, right)
        local leftKey = ("%s|%s"):format(left.region or "", left.dataType or "")
        local rightKey = ("%s|%s"):format(right.region or "", right.dataType or "")
        return leftKey < rightKey
    end)
end

local function BuildNewestManifestEntryMap(datasets)
    local stampByKey = {}
    local entryByKey = {}
    if type(datasets) ~= "table" then
        return stampByKey, entryByKey
    end

    for index = 1, #datasets do
        local dataset = datasets[index]
        local region = dataset and dataset.region
        local dataType = dataset and dataset.dataType
        local stamp = dataset and dataset.stamp or 0
        if type(region) == "string" and region ~= ""
            and type(dataType) == "string" and dataType ~= ""
            and type(stamp) == "number" and stamp > 0 then
            local key = ("%s|%s"):format(region, dataType)
            if stamp > (stampByKey[key] or 0) then
                stampByKey[key] = stamp
                entryByKey[key] = dataset
            end
        end
    end

    return stampByKey, entryByKey
end

local function AddUniqueFullName(list, seen, fullName)
    if type(fullName) ~= "string" or fullName == "" or seen[fullName] then
        return
    end

    seen[fullName] = true
    list[#list + 1] = fullName
end

function Comm:IsEnabled()
    return ns.Config and ns.Config:Get("enableGuildSyncChannel")
end

function Comm:IsLiveActivityVisible()
    return self:IsEnabled() and ns.Config and ns.Config:Get("showLiveKeyActivity")
end

function Comm:IsWarningVisible()
    return self:IsEnabled() and ns.Config and ns.Config:Get("showNewerRaiderIOWarning")
end

function Comm:InitializeState()
    local inInstance, instanceType = GetInstanceState()
    self.state.grouped = IsGrouped()
    self.state.inInstance = inInstance
    self.state.instanceType = instanceType
    self.state.challengeActive = IsChallengeActive()
    self.state.ownedKeySignature = self:GetLocalOwnedKeySignature()
end

function Comm:Initialize()
    if not ns.db then
        return
    end

    ns.db.commCache = ns.db.commCache or {}
    ns.db.commCache.sharedSnapshots = ns.db.commCache.sharedSnapshots or {}
    self.sharedSnapshots = ns.db.commCache.sharedSnapshots
    self:InitializeState()
    self:PruneSnapshots()

    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
    end
end

function Comm:PruneSnapshots()
    if type(self.sharedSnapshots) ~= "table" then
        return
    end

    local now = ns:GetCurrentTimestamp()
    if type(now) ~= "number" or now <= 0 then
        return
    end

    local cutoff = now - self.snapshotTTLSeconds
    for fullName, snapshot in pairs(self.sharedSnapshots) do
        if type(snapshot) ~= "table"
            or type(snapshot.observedAt) ~= "number"
            or snapshot.observedAt <= cutoff then
            self.sharedSnapshots[fullName] = nil
            self.newerManifestBySender[fullName] = nil
        end
    end
end

function Comm:ClearExpiredActivity()
    local now = ns:GetCurrentTimestamp()
    if type(now) ~= "number" or now <= 0 then
        return
    end

    local expired = {}
    for senderFullName, activity in pairs(self.activeRunSources) do
        if type(activity) ~= "table"
            or type(activity.observedAt) ~= "number"
            or (now - activity.observedAt) > self.activeRunTTLSeconds then
            expired[#expired + 1] = senderFullName
        end
    end

    for index = 1, #expired do
        self:ClearActivitySource(expired[index])
    end
end

function Comm:ResetRuntimeState()
    wipe(self.outboundQueue)
    wipe(self.lastSentSignatures)
    wipe(self.activeRunSources)
    wipe(self.activeRunParticipants)
    wipe(self.sessionReporters)
    self.sessionReporterCount = 0
    wipe(self.newerManifestBySender)
    self.state.ownedKeySignature = self:GetLocalOwnedKeySignature()

    if self.queueTicker then
        self.queueTicker:Cancel()
        self.queueTicker = nil
    end
end

function Comm:RequestDataRefresh(reason)
    self.refreshReason = reason or self.refreshReason or "comm"
    if self.refreshPending then
        return
    end

    self.refreshPending = true
    C_Timer.After(0.2, function()
        Comm.refreshPending = false
        local refreshReason = Comm.refreshReason or "comm"
        Comm.refreshReason = nil
        if ns.Data and type(ns.Data.Refresh) == "function" then
            ns.Data:Refresh(refreshReason)
        end
    end)
end

function Comm:EncodeManifest(datasets)
    if type(datasets) ~= "table" or #datasets == 0 then
        return ""
    end

    local encoded = {}
    for index = 1, #datasets do
        local dataset = datasets[index]
        local regionCode = regionCodeByName[dataset.region]
        local typeCode = typeCodeByName[dataset.dataType]
        local stampRaw = dataset.stampRaw
        if regionCode and typeCode and type(stampRaw) == "string" and stampRaw ~= "" then
            encoded[#encoded + 1] = ("%s%s%s"):format(regionCode, typeCode, stampRaw)
        end
    end

    table.sort(encoded)
    return table.concat(encoded, ",")
end

function Comm:DecodeManifest(text)
    local datasets = {}
    if type(text) ~= "string" or text == "" or text == "_" then
        return datasets
    end

    for token in string.gmatch(text, "[^,]+") do
        local regionCode, typeCode, stampRaw = token:match("^(%u)(%u)(%d+)$")
        local region = regionNameByCode[regionCode]
        local dataType = typeNameByCode[typeCode]
        local stamp = tonumber(stampRaw)
        if region and dataType and stamp then
            datasets[#datasets + 1] = {
                region = region,
                dataType = dataType,
                stamp = stamp,
                stampRaw = stampRaw,
                timestampText = FormatManifestTimestamp(stampRaw)
            }
        end
    end

    SortDatasets(datasets)
    return datasets
end

function Comm:GetNewerManifestEntries(manifestDatasets)
    if type(manifestDatasets) ~= "table" or #manifestDatasets == 0 then
        return {}
    end

    local localMetadata = ns:GetRaiderIOMetadata()
    local localStampByKey = BuildNewestManifestEntryMap(localMetadata.datasets or {})
    local remoteStampByKey, remoteEntryByKey = BuildNewestManifestEntryMap(manifestDatasets)

    local newer = {}
    for key, remoteStamp in pairs(remoteStampByKey) do
        local localStamp = localStampByKey[key]
        if localStamp and remoteStamp > localStamp then
            newer[#newer + 1] = remoteEntryByKey[key]
        end
    end

    SortDatasets(newer)
    return newer
end

function Comm:UpdateNewerManifestState(senderFullName, manifestDatasets)
    local newerEntries = self:GetNewerManifestEntries(manifestDatasets)
    if #newerEntries > 0 then
        self.newerManifestBySender[senderFullName] = {
            senderFullName = senderFullName,
            observedAt = ns:GetCurrentTimestamp(),
            entries = newerEntries
        }
    else
        self.newerManifestBySender[senderFullName] = nil
    end
end

function Comm:IsSnapshotPreferred(snapshot, record)
    if not self:IsEnabled() or type(snapshot) ~= "table" then
        return false
    end

    if not record then
        return true
    end

    if record.profileState ~= "ready" or (record.currentScore or 0) <= 0 then
        return true
    end

    local newerEntries = self:GetNewerManifestEntries(snapshot.manifestDatasets or {})
    return #newerEntries > 0
end

function Comm:CollectGroupMembers()
    local members = {}
    local seen = {}

    local function AddUnit(unit)
        if not unit or not UnitExists(unit) then
            return
        end

        local name, realm = ns:GetUnitNameRealm(unit, ns.playerRealm)
        local fullName = ns:ComposeFullName(name, realm)
        if type(fullName) == "string" and not ns:IsSecretValue(fullName) then
            AddUniqueFullName(members, seen, fullName)
        end
    end

    AddUnit("player")

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            AddUnit("raid" .. index)
        end
    elseif IsInGroup() then
        for index = 1, GetNumSubgroupMembers() do
            AddUnit("party" .. index)
        end
    end

    return members
end

function Comm:GetLocalOwnedKey()
    local mapID = C_MythicPlus
        and type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function"
        and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        or nil
    local level = C_MythicPlus
        and type(C_MythicPlus.GetOwnedKeystoneLevel) == "function"
        and C_MythicPlus.GetOwnedKeystoneLevel()
        or nil

    if not mapID or mapID <= 0 or not level or level <= 0 then
        return nil
    end

    local mapName, texture, backgroundTexture = GetChallengeMapInfo(mapID)
    return {
        mapID = mapID,
        level = level,
        mapName = mapName,
        texture = texture,
        backgroundTexture = backgroundTexture,
        timeStamp = ns:GetCurrentTimestamp()
    }
end

function Comm:GetLocalOwnedKeySignature()
    return BuildOwnedKeySignature(self:GetLocalOwnedKey())
end

function Comm:BuildSnapshot()
    if not ns.playerFullName or not ns.Data or type(ns.Data.CreateBlankRecord) ~= "function" then
        return nil
    end

    local name, realm, guid = ns:GetUnitNameRealm("player", ns.playerRealm)
    if type(name) ~= "string" then
        return nil
    end

    local record = ns.Data:CreateBlankRecord(name, realm or ns.playerRealm)
    record.guid = guid

    ns.Data:ApplyRaiderIO(record)
    ns.Data:ApplyEnrichment(record)

    local metadata = ns:GetRaiderIOMetadata()
    local ownedKey = self:GetLocalOwnedKey()
    return {
        senderFullName = record.fullName,
        observedAt = ns:GetCurrentTimestamp(),
        currentScore = record.currentScore or 0,
        mainCurrentScore = record.mainCurrentScore or 0,
        maxDungeonLevel = record.maxDungeonLevel or 0,
        timed20 = record.timed20 or 0,
        timed15 = record.timed15 or 0,
        timed11_14 = record.timed11_14 or 0,
        timed9_10 = record.timed9_10 or 0,
        timed4_8 = record.timed4_8 or 0,
        timed2_3 = record.timed2_3 or 0,
        completed20 = record.completed20 or 0,
        completed15 = record.completed15 or 0,
        completed11_14 = record.completed11_14 or 0,
        completed9_10 = record.completed9_10 or 0,
        completed4_8 = record.completed4_8 or 0,
        completed2_3 = record.completed2_3 or 0,
        itemLevel = ns:GetDisplayedItemLevel(record.equippedItemLevel) or 0,
        specID = record.specID or 0,
        roleBucket = record.roleBucket or "unknown",
        manifestDatasets = metadata.datasets or {},
        keyMapID = ownedKey and ownedKey.mapID or 0,
        keyLevel = ownedKey and ownedKey.level or 0,
        keyTimeStamp = ownedKey and ownedKey.timeStamp or 0
    }
end

function Comm:BuildActivity()
    if not ns.playerFullName or not IsChallengeActive() then
        return nil
    end

    local mapID = C_ChallengeMode and type(C_ChallengeMode.GetActiveChallengeMapID) == "function" and C_ChallengeMode.GetActiveChallengeMapID() or nil
    local level = C_ChallengeMode and type(C_ChallengeMode.GetActiveKeystoneInfo) == "function" and select(1, C_ChallengeMode.GetActiveKeystoneInfo()) or nil
    if not mapID or not level then
        return nil
    end

    local members = self:CollectGroupMembers()
    if #members == 0 then
        members[1] = ns.playerFullName
    end

    local mapName, texture, backgroundTexture = GetChallengeMapInfo(mapID)

    return {
        senderFullName = ns.playerFullName,
        observedAt = ns:GetCurrentTimestamp(),
        mapID = mapID,
        mapName = mapName,
        texture = texture,
        backgroundTexture = backgroundTexture,
        level = level,
        members = members
    }
end

function Comm:SerializeSnapshot(snapshot)
    local manifestText = self:EncodeManifest(snapshot.manifestDatasets)
    if manifestText == "" then
        manifestText = "_"
    end

    return table.concat({
        self.protocol,
        "S",
        snapshot.senderFullName or "",
        tostring(snapshot.observedAt or 0),
        tostring(snapshot.currentScore or 0),
        tostring(snapshot.mainCurrentScore or 0),
        tostring(snapshot.maxDungeonLevel or 0),
        tostring(snapshot.timed20 or 0),
        tostring(snapshot.timed15 or 0),
        tostring(snapshot.timed11_14 or 0),
        tostring(snapshot.timed9_10 or 0),
        tostring(snapshot.timed4_8 or 0),
        tostring(snapshot.timed2_3 or 0),
        tostring(snapshot.itemLevel or 0),
        tostring(snapshot.specID or 0),
        roleCodeByBucket[snapshot.roleBucket] or "U",
        manifestText,
        tostring(snapshot.completed20 or 0),
        tostring(snapshot.completed15 or 0),
        tostring(snapshot.completed11_14 or 0),
        tostring(snapshot.completed9_10 or 0),
        tostring(snapshot.completed4_8 or 0),
        tostring(snapshot.completed2_3 or 0),
        tostring(snapshot.keyMapID or 0),
        tostring(snapshot.keyLevel or 0),
        tostring(snapshot.keyTimeStamp or 0)
    }, "\t")
end

function Comm:SerializeActivity(activity)
    return table.concat({
        self.protocol,
        "A",
        activity.senderFullName or "",
        tostring(activity.observedAt or 0),
        tostring(activity.mapID or 0),
        tostring(activity.level or 0),
        table.concat(activity.members or {}, ",")
    }, "\t")
end

function Comm:SerializeClear(senderFullName)
    return table.concat({
        self.protocol,
        "X",
        senderFullName or "",
        tostring(ns:GetCurrentTimestamp() or 0)
    }, "\t")
end

function Comm:DeserializeSnapshot(fields)
    if #fields < (snapshotFieldCount - 1) then
        return nil
    end

    local senderFullName = fields[3]
    local observedAt = tonumber(fields[4])
    if not senderFullName or senderFullName == "" or not observedAt then
        return nil
    end

    local keyMapID = fields[24] and (tonumber(fields[24]) or 0) or 0
    local keyLevel = fields[25] and (tonumber(fields[25]) or 0) or 0
    local keyTimeStamp = fields[26] and (tonumber(fields[26]) or 0) or 0

    if keyMapID <= 0 or keyLevel <= 0 then
        keyMapID = nil
        keyLevel = nil
        keyTimeStamp = nil
    elseif not keyTimeStamp or keyTimeStamp <= 0 then
        keyTimeStamp = observedAt
    end

    return {
        senderFullName = senderFullName,
        observedAt = observedAt,
        currentScore = tonumber(fields[5]) or 0,
        mainCurrentScore = tonumber(fields[6]) or 0,
        maxDungeonLevel = tonumber(fields[7]) or 0,
        timed20 = tonumber(fields[8]) or 0,
        timed15 = tonumber(fields[9]) or 0,
        timed11_14 = tonumber(fields[10]) or 0,
        timed9_10 = tonumber(fields[11]) or 0,
        timed4_8 = tonumber(fields[12]) or 0,
        timed2_3 = tonumber(fields[13]) or 0,
        itemLevel = tonumber(fields[14]) or 0,
        specID = tonumber(fields[15]) or 0,
        roleBucket = roleBucketByCode[fields[16]] or "unknown",
        manifestDatasets = self:DecodeManifest(fields[17]),
        completed20 = fields[18] and (tonumber(fields[18]) or 0) or nil,
        completed15 = fields[19] and (tonumber(fields[19]) or 0) or nil,
        completed11_14 = fields[20] and (tonumber(fields[20]) or 0) or nil,
        completed9_10 = fields[21] and (tonumber(fields[21]) or 0) or nil,
        completed4_8 = fields[22] and (tonumber(fields[22]) or 0) or nil,
        completed2_3 = fields[23] and (tonumber(fields[23]) or 0) or nil,
        keyMapID = keyMapID,
        keyLevel = keyLevel,
        keyTimeStamp = keyTimeStamp
    }
end

function Comm:DeserializeActivity(fields)
    if #fields < activityFieldCount then
        return nil
    end

    local senderFullName = fields[3]
    local observedAt = tonumber(fields[4])
    local mapID = tonumber(fields[5])
    local level = tonumber(fields[6])
    if not senderFullName or senderFullName == "" or not observedAt or not mapID or not level then
        return nil
    end

    local members = {}
    local seen = {}
    for token in string.gmatch(fields[7] or "", "[^,]+") do
        AddUniqueFullName(members, seen, token)
    end
    AddUniqueFullName(members, seen, senderFullName)

    local mapName, texture, backgroundTexture = GetChallengeMapInfo(mapID)

    return {
        senderFullName = senderFullName,
        observedAt = observedAt,
        mapID = mapID,
        mapName = mapName,
        texture = texture,
        backgroundTexture = backgroundTexture,
        level = level,
        members = members
    }
end

function Comm:IsSenderMatch(sender, payloadFullName)
    if type(sender) ~= "string" or sender == "" or type(payloadFullName) ~= "string" or payloadFullName == "" then
        return false
    end

    local payloadName, payloadRealm = ns:SplitNameRealm(payloadFullName, ns.playerRealm)
    local senderName, senderRealm = ns:SplitNameRealm(sender, ns.playerRealm)
    return payloadName == senderName and ns:TrimRealmName(payloadRealm) == ns:TrimRealmName(senderRealm)
end

function Comm:GetSnapshot(fullName)
    if not self:IsEnabled() or type(fullName) ~= "string" or fullName == "" then
        return nil
    end

    self:PruneSnapshots()
    return self.sharedSnapshots and self.sharedSnapshots[fullName] or nil
end

function Comm:GetActiveRun(fullName)
    if not self:IsEnabled() or type(fullName) ~= "string" or fullName == "" then
        return nil
    end

    self:ClearExpiredActivity()
    local sources = self.activeRunParticipants[fullName]
    if not sources then
        return nil
    end

    local newest = nil
    for senderFullName in pairs(sources) do
        local activity = self.activeRunSources[senderFullName]
        if activity and (not newest or (activity.observedAt or 0) > (newest.observedAt or 0)) then
            newest = activity
        end
    end

    return newest
end

function Comm:HasNewerRaiderIOData()
    if not self:IsEnabled() then
        return false
    end

    return next(self.newerManifestBySender) ~= nil
end

function Comm:GetNewerRaiderIOSources()
    if not self:IsEnabled() then
        return {}
    end

    local sources = {}
    for _, entry in pairs(self.newerManifestBySender) do
        sources[#sources + 1] = entry
    end

    table.sort(sources, function(left, right)
        if (left.observedAt or 0) ~= (right.observedAt or 0) then
            return (left.observedAt or 0) > (right.observedAt or 0)
        end

        return (left.senderFullName or "") < (right.senderFullName or "")
    end)

    return sources
end

function Comm:GetSessionReporterCount()
    if not self:IsEnabled() then
        return 0
    end

    return self.sessionReporterCount or 0
end

function Comm:ClearActivitySource(senderFullName)
    local activity = self.activeRunSources[senderFullName]
    if not activity then
        return false
    end

    self.activeRunSources[senderFullName] = nil
    for index = 1, #(activity.members or {}) do
        local fullName = activity.members[index]
        local sources = self.activeRunParticipants[fullName]
        if sources then
            sources[senderFullName] = nil
            if not next(sources) then
                self.activeRunParticipants[fullName] = nil
            end
        end
    end

    return true
end

function Comm:StoreActivity(activity)
    self:ClearExpiredActivity()
    self:ClearActivitySource(activity.senderFullName)

    self.activeRunSources[activity.senderFullName] = activity
    for index = 1, #(activity.members or {}) do
        local fullName = activity.members[index]
        local sources = self.activeRunParticipants[fullName]
        if not sources then
            sources = {}
            self.activeRunParticipants[fullName] = sources
        end
        sources[activity.senderFullName] = true
    end
end

function Comm:EnqueueMessage(key, message, signature, delaySeconds)
    if not self:IsEnabled() or not IsInGuild() or type(message) ~= "string" or message == "" then
        return
    end

    local now = GetTime()
    local lastSent = self.lastSentSignatures[signature]
    if lastSent and (now - lastSent) < 5 then
        return
    end

    local item = {
        key = key,
        message = message,
        signature = signature,
        notBefore = now + (delaySeconds or 0)
    }

    local replaced = false
    for index = 1, #self.outboundQueue do
        if self.outboundQueue[index].key == key then
            self.outboundQueue[index] = item
            replaced = true
            break
        end
    end

    if not replaced then
        self.outboundQueue[#self.outboundQueue + 1] = item
    end

    if not self.queueTicker then
        self.queueTicker = C_Timer.NewTicker(0.2, function()
            Comm:ProcessQueue()
        end)
    end
end

function Comm:ProcessQueue()
    if not self:IsEnabled() or not IsInGuild() then
        wipe(self.outboundQueue)
        if self.queueTicker then
            self.queueTicker:Cancel()
            self.queueTicker = nil
        end
        return
    end

    local item = self.outboundQueue[1]
    if not item then
        if self.queueTicker then
            self.queueTicker:Cancel()
            self.queueTicker = nil
        end
        return
    end

    if GetTime() < (item.notBefore or 0) then
        return
    end

    table.remove(self.outboundQueue, 1)
    if C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function" then
        local ok = pcall(C_ChatInfo.SendAddonMessage, self.prefix, item.message, "GUILD")
        if ok then
            self.lastSentSignatures[item.signature] = GetTime()
        end
    end
end

function Comm:QueueSnapshot(reason, delaySeconds)
    local snapshot = self:BuildSnapshot()
    if not snapshot then
        return
    end

    self.state.ownedKeySignature = BuildOwnedKeySignature({
        mapID = snapshot.keyMapID,
        level = snapshot.keyLevel
    })

    local message = self:SerializeSnapshot(snapshot)
    self:EnqueueMessage("snapshot", message, "snapshot:" .. message, delaySeconds or 0.75)
end

function Comm:QueueActivity(reason, delaySeconds)
    local activity = self:BuildActivity()
    if not activity then
        return
    end

    local message = self:SerializeActivity(activity)
    self:EnqueueMessage("activity", message, "activity:" .. message, delaySeconds or 0.3)
end

function Comm:QueueActivityClear(reason, delaySeconds)
    if not ns.playerFullName then
        return
    end

    local message = self:SerializeClear(ns.playerFullName)
    self:EnqueueMessage("activity_clear", message, "activity_clear:" .. message, delaySeconds or 0.1)
end

function Comm:HandleSnapshot(snapshot)
    self.sharedSnapshots = self.sharedSnapshots or {}
    self.sharedSnapshots[snapshot.senderFullName] = snapshot
    if not self.sessionReporters[snapshot.senderFullName] then
        self.sessionReporters[snapshot.senderFullName] = true
        self.sessionReporterCount = (self.sessionReporterCount or 0) + 1
    end
    self:UpdateNewerManifestState(snapshot.senderFullName, snapshot.manifestDatasets)
    ns:FireCallback("COMM_SNAPSHOT_UPDATED", snapshot.senderFullName, snapshot)
    self:RequestDataRefresh("comm_snapshot")
end

function Comm:HandleActivity(activity)
    self:StoreActivity(activity)
    ns:FireCallback("COMM_ACTIVITY_UPDATED", activity.senderFullName, activity)
    self:RequestDataRefresh("comm_activity")
end

function Comm:HandleActivityClear(senderFullName)
    if self:ClearActivitySource(senderFullName) then
        ns:FireCallback("COMM_ACTIVITY_UPDATED", senderFullName, nil)
        self:RequestDataRefresh("comm_activity_clear")
    end
end

function Comm:HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= self.prefix or channel ~= "GUILD" or not self:IsEnabled() then
        return
    end

    local fields = { strsplit("\t", message or "") }
    if fields[1] ~= self.protocol then
        return
    end

    local kind = fields[2]
    if kind == "S" then
        local snapshot = self:DeserializeSnapshot(fields)
        if snapshot
            and snapshot.senderFullName ~= ns.playerFullName
            and self:IsSenderMatch(sender, snapshot.senderFullName) then
            self:HandleSnapshot(snapshot)
        end
    elseif kind == "A" then
        local activity = self:DeserializeActivity(fields)
        if activity
            and activity.senderFullName ~= ns.playerFullName
            and self:IsSenderMatch(sender, activity.senderFullName) then
            self:HandleActivity(activity)
        end
    elseif kind == "X" then
        local senderFullName = fields[3]
        if senderFullName
            and senderFullName ~= ns.playerFullName
            and self:IsSenderMatch(sender, senderFullName) then
            self:HandleActivityClear(senderFullName)
        end
    end
end

function Comm:HandlePlayerLogin()
    self:InitializeState()
    if not self:IsEnabled() then
        return
    end

    C_Timer.After(1.5, function()
        Comm:QueueSnapshot("login", 0)
    end)
end

function Comm:HandleGroupRosterUpdate()
    local grouped = IsGrouped()
    local challengeActive = IsChallengeActive()

    if grouped ~= self.state.grouped then
        if grouped then
            self:QueueSnapshot("group_join", 0.75)
        else
            self:QueueActivityClear("group_leave", 0.1)
            self:QueueSnapshot("group_leave", 0.75)
        end
    elseif challengeActive then
        self:QueueActivity("group_change", 0.3)
    end

    self.state.grouped = grouped
    self.state.challengeActive = challengeActive
end

function Comm:HandleWorldStateChange()
    local inInstance, instanceType = GetInstanceState()
    local challengeActive = IsChallengeActive()
    local wasInInstance = self.state.inInstance
    local wasChallengeActive = self.state.challengeActive

    if (wasInInstance or wasChallengeActive) and not (inInstance or challengeActive) then
        self:QueueActivityClear("instance_leave", 0.1)
        self:QueueSnapshot("instance_leave", 0.9)
    end

    self.state.inInstance = inInstance
    self.state.instanceType = instanceType
    self.state.challengeActive = challengeActive
end

function Comm:HandleBagUpdateDelayed()
    local ownedKeySignature = self:GetLocalOwnedKeySignature()
    if ownedKeySignature == (self.state.ownedKeySignature or "") then
        return
    end

    self.state.ownedKeySignature = ownedKeySignature
    if self:IsEnabled() then
        self:QueueSnapshot("bag_update", 0.5)
    end
end

ns:RegisterCallback("ADDON_READY", function()
    Comm:Initialize()
end)

ns:RegisterCallback("PLAYER_LOGIN", function()
    Comm:HandlePlayerLogin()
end)

ns:RegisterCallback("CONFIG_CHANGED", function(key, value)
    if key ~= "enableGuildSyncChannel" then
        return
    end

    if value then
        Comm:Initialize()
        Comm:RequestDataRefresh("comm_gate_enabled")
        C_Timer.After(0.75, function()
            if Comm:IsEnabled() then
                Comm:QueueSnapshot("enabled", 0)
                if IsChallengeActive() then
                    Comm:QueueActivity("enabled", 0.15)
                end
            end
        end)
    else
        Comm:ResetRuntimeState()
        Comm:RequestDataRefresh("comm_gate_disabled")
    end
end)

ns:RegisterEvent("CHAT_MSG_ADDON", function(prefix, message, channel, sender)
    Comm:HandleAddonMessage(prefix, message, channel, sender)
end)

ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
    Comm:HandleGroupRosterUpdate()
end)

ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Comm:HandleWorldStateChange()
end)

ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
    Comm:HandleWorldStateChange()
end)

ns:RegisterEvent("CHALLENGE_MODE_START", function()
    Comm.state.challengeActive = true
    Comm:QueueSnapshot("challenge_start", 0.2)
    Comm:QueueActivity("challenge_start", 0.15)
end)

ns:RegisterEvent("CHALLENGE_MODE_COMPLETED", function()
    Comm.state.challengeActive = false
    Comm:QueueActivityClear("challenge_completed", 0.1)
    Comm:QueueSnapshot("challenge_completed", 0.4)
end)

ns:RegisterEvent("CHALLENGE_MODE_RESET", function()
    Comm.state.challengeActive = false
    Comm:QueueActivityClear("challenge_reset", 0.1)
    Comm:QueueSnapshot("challenge_reset", 0.4)
end)

ns:RegisterEvent("BAG_UPDATE_DELAYED", function()
    Comm:HandleBagUpdateDelayed()
end)
