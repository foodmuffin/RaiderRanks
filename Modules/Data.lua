local _, ns = ...

local Data = {
    records = {},
    recordsByKey = {},
    specCatalog = {},
    currentKeyContext = {
        mapID = nil,
        mapName = nil,
        level = nil,
        texture = nil,
        backgroundTexture = nil,
        qualifiedCount = 0,
        qualifiedByRole = {
            tank = 0,
            healer = 0,
            dps = 0,
            unknown = 0
        },
        qualifiedMembers = {},
        bestByRole = {}
    }
}

ns.Data = Data

local difficultyLabels = {
    [1] = NORMAL,
    [2] = HEROIC,
    [3] = MYTHIC
}

local function GetEmptyQualifiedByRole()
    return {
        tank = 0,
        healer = 0,
        dps = 0,
        unknown = 0
    }
end

local function CountTimedRunsAtOrAbove(sortedDungeons, threshold)
    local count = 0
    for index = 1, #(sortedDungeons or {}) do
        local dungeonProfile = sortedDungeons[index]
        if dungeonProfile
            and (dungeonProfile.level or 0) >= threshold
            and (dungeonProfile.chests or 0) > 0 then
            count = count + 1
        end
    end
    return count
end

local function CountCompletedRunsAtOrAbove(sortedDungeons, threshold)
    local count = 0
    for index = 1, #(sortedDungeons or {}) do
        local dungeonProfile = sortedDungeons[index]
        if dungeonProfile and (dungeonProfile.level or 0) >= threshold then
            count = count + 1
        end
    end
    return count
end

local function CountTimedRunsInRange(sortedDungeons, minimumLevel, maximumLevel)
    local count = 0
    for index = 1, #(sortedDungeons or {}) do
        local dungeonProfile = sortedDungeons[index]
        local level = dungeonProfile and (dungeonProfile.level or 0) or 0
        if dungeonProfile
            and level >= minimumLevel
            and level <= maximumLevel
            and (dungeonProfile.chests or 0) > 0 then
            count = count + 1
        end
    end

    return count
end

local function CountCompletedRunsInRange(sortedDungeons, minimumLevel, maximumLevel)
    local count = 0
    for index = 1, #(sortedDungeons or {}) do
        local dungeonProfile = sortedDungeons[index]
        local level = dungeonProfile and (dungeonProfile.level or 0) or 0
        if dungeonProfile and level >= minimumLevel and level <= maximumLevel then
            count = count + 1
        end
    end

    return count
end

local function PopulateRunSummary(record)
    local sortedDungeons = record and record.sortedDungeons or {}
    record.timed20 = CountTimedRunsAtOrAbove(sortedDungeons, 20)
    record.timed15 = CountTimedRunsAtOrAbove(sortedDungeons, 15)
    record.timed11_14 = CountTimedRunsInRange(sortedDungeons, 11, 14)
    record.timed9_10 = CountTimedRunsInRange(sortedDungeons, 9, 10)
    record.timed4_8 = CountTimedRunsInRange(sortedDungeons, 4, 8)
    record.timed2_3 = CountTimedRunsInRange(sortedDungeons, 2, 3)
    record.completed20 = CountCompletedRunsAtOrAbove(sortedDungeons, 20)
    record.completed15 = CountCompletedRunsAtOrAbove(sortedDungeons, 15)
    record.completed11_14 = CountCompletedRunsInRange(sortedDungeons, 11, 14)
    record.completed9_10 = CountCompletedRunsInRange(sortedDungeons, 9, 10)
    record.completed4_8 = CountCompletedRunsInRange(sortedDungeons, 4, 8)
    record.completed2_3 = CountCompletedRunsInRange(sortedDungeons, 2, 3)
end

local function ApplySnapshotRunSummary(record, snapshot)
    record.timed20 = snapshot.timed20 or 0
    record.timed15 = snapshot.timed15 or 0
    record.timed11_14 = snapshot.timed11_14 or 0
    record.timed9_10 = snapshot.timed9_10 or 0
    record.timed4_8 = snapshot.timed4_8 or 0
    record.timed2_3 = snapshot.timed2_3 or 0
    record.completed20 = snapshot.completed20 ~= nil and (snapshot.completed20 or 0) or math.max(record.completed20 or 0, record.timed20 or 0)
    record.completed15 = snapshot.completed15 ~= nil and (snapshot.completed15 or 0) or math.max(record.completed15 or 0, record.timed15 or 0)
    record.completed11_14 = snapshot.completed11_14 ~= nil and (snapshot.completed11_14 or 0) or math.max(record.completed11_14 or 0, record.timed11_14 or 0)
    record.completed9_10 = snapshot.completed9_10 ~= nil and (snapshot.completed9_10 or 0) or math.max(record.completed9_10 or 0, record.timed9_10 or 0)
    record.completed4_8 = snapshot.completed4_8 ~= nil and (snapshot.completed4_8 or 0) or math.max(record.completed4_8 or 0, record.timed4_8 or 0)
    record.completed2_3 = snapshot.completed2_3 ~= nil and (snapshot.completed2_3 or 0) or math.max(record.completed2_3 or 0, record.timed2_3 or 0)
end

local function ApplyMilestoneDisplayFloors(record)
    if not record then
        return
    end

    if type(record.displayTimed15) == "number" then
        record.timed15 = math.max(record.timed15 or 0, record.displayTimed15)
        record.completed15 = math.max(record.completed15 or 0, record.displayTimed15)
    end

    if type(record.displayTimed2_3) == "number" then
        record.timed2_3 = math.max(record.timed2_3 or 0, record.displayTimed2_3)
        record.completed2_3 = math.max(record.completed2_3 or 0, record.displayTimed2_3)
    end
end

local function ResolveSharedSpecInfo(data, specID)
    if type(specID) ~= "number" or specID <= 0 then
        return nil, nil
    end

    local cached = data.specCatalog[specID]
    if cached then
        return cached.specName, cached.specIcon
    end

    if type(GetSpecializationInfoByID) == "function" then
        local _, specName, _, specIcon = GetSpecializationInfoByID(specID)
        if specName then
            return specName, specIcon
        end
    end

    return nil, nil
end

local function HasSharedMythicData(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    return (snapshot.currentScore or 0) > 0
        or (snapshot.mainCurrentScore or 0) > 0
        or (snapshot.maxDungeonLevel or 0) > 0
        or (snapshot.timed20 or 0) > 0
        or (snapshot.timed15 or 0) > 0
        or (snapshot.timed11_14 or 0) > 0
        or (snapshot.timed9_10 or 0) > 0
        or (snapshot.timed4_8 or 0) > 0
        or (snapshot.timed2_3 or 0) > 0
        or (snapshot.completed20 or 0) > 0
        or (snapshot.completed15 or 0) > 0
        or (snapshot.completed11_14 or 0) > 0
        or (snapshot.completed9_10 or 0) > 0
        or (snapshot.completed4_8 or 0) > 0
        or (snapshot.completed2_3 or 0) > 0
end

function Data:CreateBlankRecord(name, realm)
    local fullName = ns:ComposeFullName(name, realm)
    return {
        source = nil,
        isGuild = false,
        isFriend = false,
        fullName = fullName,
        name = name,
        realm = realm,
        classFile = nil,
        classID = nil,
        level = 0,
        online = false,
        battleTag = nil,
        guildRank = nil,
        guid = nil,
        currentScore = 0,
        previousScore = 0,
        mainCurrentScore = nil,
        maxDungeonLevel = 0,
        timed20 = 0,
        timed15 = 0,
        timed11_14 = 0,
        timed9_10 = 0,
        timed4_8 = 0,
        timed2_3 = 0,
        displayTimed15 = nil,
        displayTimed2_3 = nil,
        completed20 = 0,
        completed15 = 0,
        completed11_14 = 0,
        completed9_10 = 0,
        completed4_8 = 0,
        completed2_3 = 0,
        sortedDungeons = {},
        equippedItemLevel = nil,
        itemLevelSource = "unknown",
        itemLevelObservedAt = nil,
        itemLevelIsStale = false,
        scoreSource = "local",
        scoreObservedAt = nil,
        roleBucket = "unknown",
        roleSource = "unknown",
        roleObservedAt = nil,
        specID = nil,
        specName = nil,
        specIcon = nil,
        specSource = "unknown",
        specObservedAt = nil,
        specIsStale = false,
        profileState = ns:IsRaiderIOAvailable() and "unscored" or "missing_dependency",
        raidSummary = {},
        unitToken = nil,
        hasRenderableProfile = false,
        isQualifiedForCurrentKey = false,
        currentKeyStatus = nil,
        currentKeyLevel = nil,
        currentKeyChests = nil,
        reportedKey = nil,
        activeRun = nil
    }
end

function Data:AddOrUpdateRecord(incoming)
    if not incoming or not incoming.name then
        return
    end

    local fullName = ns:ComposeFullName(incoming.name, incoming.realm)
    if not fullName then
        return
    end

    local record = self.recordsByKey[fullName]
    if not record then
        record = self:CreateBlankRecord(incoming.name, incoming.realm)
        self.recordsByKey[fullName] = record
    end

    record.name = incoming.name or record.name
    record.realm = incoming.realm or record.realm
    record.fullName = fullName
    record.classFile = incoming.classFile or record.classFile
    record.classID = incoming.classID or record.classID
    record.level = math.max(record.level or 0, incoming.level or 0)
    record.online = record.online or not not incoming.online
    record.guildRank = incoming.guildRank or record.guildRank
    record.battleTag = incoming.battleTag or record.battleTag
    record.guid = incoming.guid or record.guid

    if incoming.source == "guild" then
        record.isGuild = true
    elseif incoming.source == "friend" then
        record.isFriend = true
    end

    if record.isGuild and record.isFriend then
        record.source = "guild_friend"
    elseif record.isGuild then
        record.source = "guild"
    elseif record.isFriend then
        record.source = "friend"
    else
        record.source = ns:ChoosePreferredSource(record.source, incoming.source)
    end
end

function Data:ResetRecords()
    wipe(self.records)
    wipe(self.recordsByKey)
    wipe(self.specCatalog)
end

function Data:CollectGuild()
    if not IsInGuild() then
        return
    end

    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end

    if type(GetNumGuildMembers) ~= "function" or type(GetGuildRosterInfo) ~= "function" then
        return
    end

    local count = GetNumGuildMembers(true)
    for index = 1, count do
        local name, _, rankIndex, level, _, _, _, _, online, _, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(index)
        if name then
            local memberName, realm = ns:SplitNameRealm(name, ns.playerRealm)
            self:AddOrUpdateRecord({
                source = "guild",
                name = memberName,
                realm = realm,
                classFile = classFileName,
                level = tonumber(level) or 0,
                online = online,
                guildRank = rankIndex and (rankIndex + 1) or nil,
                guid = guid
            })
        end
    end
end

function Data:CollectFriends()
    local numFriends = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or GetNumFriends()
    for index = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(index)
        if info and info.name then
            local name, realm = ns:SplitNameRealm(info.name, ns.playerRealm)
            self:AddOrUpdateRecord({
                source = "friend",
                name = name,
                realm = realm,
                level = info.level or 0,
                online = info.connected,
                classFile = info.className and select(2, GetClassInfo(info.classID or 0)) or nil
            })
        end
    end
end

function Data:CollectBNetFriends()
    local retailProjectID = WOW_PROJECT_ID or 1
    local numFriends = BNGetNumFriends and BNGetNumFriends() or 0
    for accountIndex = 1, numFriends do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(accountIndex)
        if accountInfo then
            local accountName = accountInfo.accountName
            local battleTag = accountInfo.battleTag
            local gameAccounts = 1
            if C_BattleNet.GetFriendNumGameAccounts then
                gameAccounts = C_BattleNet.GetFriendNumGameAccounts(accountIndex)
            elseif not accountInfo.gameAccountInfo then
                gameAccounts = 0
            end

            for gameIndex = 1, gameAccounts do
                local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo and C_BattleNet.GetFriendGameAccountInfo(accountIndex, gameIndex) or accountInfo.gameAccountInfo
                if gameAccountInfo
                    and gameAccountInfo.clientProgram == BNET_CLIENT_WOW
                    and (not gameAccountInfo.wowProjectID or gameAccountInfo.wowProjectID == retailProjectID) then
                    local name = gameAccountInfo.characterName
                    local realm = gameAccountInfo.realmName or gameAccountInfo.realmDisplayName
                    if name and realm then
                        self:AddOrUpdateRecord({
                            source = "friend",
                            name = name,
                            realm = realm,
                            level = gameAccountInfo.characterLevel or 0,
                            online = true,
                            battleTag = battleTag or accountName,
                            classFile = select(2, GetClassInfo(gameAccountInfo.classID or 0))
                        })
                    end
                end
            end
        end
    end
end

function Data:ApplyRaiderIO(record)
    record.currentScore = 0
    record.previousScore = 0
    record.mainCurrentScore = nil
    record.maxDungeonLevel = 0
    record.timed20 = 0
    record.timed15 = 0
    record.timed11_14 = 0
    record.timed9_10 = 0
    record.timed4_8 = 0
    record.timed2_3 = 0
    record.displayTimed15 = nil
    record.displayTimed2_3 = nil
    record.completed20 = 0
    record.completed15 = 0
    record.completed11_14 = 0
    record.completed9_10 = 0
    record.completed4_8 = 0
    record.completed2_3 = 0
    record.sortedDungeons = {}
    record.raidSummary = {}
    record.hasRenderableProfile = false

    if not ns:IsRaiderIOAvailable() then
        record.profileState = "missing_dependency"
        return
    end

    local ok, profile = pcall(_G.RaiderIO.GetProfile, record.name, record.realm)
    if not ok or not profile or not profile.success then
        record.profileState = "unscored"
        return
    end

    local mythic = profile.mythicKeystoneProfile
    if not mythic then
        record.profileState = "unscored"
    elseif mythic.hasRenderableData == false then
        record.profileState = "stale"
    else
        record.profileState = "ready"
        record.hasRenderableProfile = true
        record.currentScore = ns:Round(mythic.currentScore or 0)
        record.previousScore = ns:Round(mythic.previousScore or 0)
        record.mainCurrentScore = mythic.mainCurrentScore and ns:Round(mythic.mainCurrentScore) or nil
        record.maxDungeonLevel = mythic.maxDungeonLevel or 0
        record.sortedDungeons = mythic.sortedDungeons or {}
        PopulateRunSummary(record)
        if type(mythic.keystoneMilestone15) == "number" then
            record.displayTimed15 = mythic.keystoneMilestone15
        end
        if type(mythic.keystoneMilestone2) == "number" then
            record.displayTimed2_3 = mythic.keystoneMilestone2
        end
        ApplyMilestoneDisplayFloors(record)

        local currentRoles = mythic.mplusCurrent and mythic.mplusCurrent.roles
        if type(currentRoles) == "table" and currentRoles[1] and currentRoles[1][1] then
            record.roleBucket = currentRoles[1][1]
            record.roleSource = "raiderio"
        end
    end

    local raid = profile.raidProfile
    if raid and raid.hasRenderableData ~= false and type(raid.progress) == "table" then
        for index = 1, #raid.progress do
            local progress = raid.progress[index]
            local raidInfo = progress.raid
            if progress and raidInfo then
                table.insert(record.raidSummary, {
                    label = difficultyLabels[progress.difficulty] or tostring(progress.difficulty),
                    shortName = raidInfo.shortName or raidInfo.name,
                    progressCount = progress.progressCount or 0,
                    bossCount = raidInfo.bossCount or 0
                })
            end
        end
    end
end

function Data:ApplyEnrichment(record)
    record.itemLevelSource = "unknown"
    record.itemLevelObservedAt = nil
    record.itemLevelIsStale = false
    record.scoreSource = "local"
    record.scoreObservedAt = nil
    record.specSource = "unknown"
    record.specObservedAt = nil
    record.specIsStale = false
    record.roleObservedAt = nil
    if record.roleSource ~= "raiderio" then
        record.roleSource = "unknown"
    end

    ns.Inspect:ApplyLiveData(record)
    ns.Inspect:ApplyCachedData(record)

    if record.specID and record.specName then
        self.specCatalog[record.specID] = {
            specID = record.specID,
            specName = record.specName,
            specIcon = record.specIcon
        }
    end

    if not record.itemLevelSource then
        record.itemLevelSource = "unknown"
    end

    if not record.specSource then
        record.specSource = "unknown"
    end

    if not record.roleBucket then
        record.roleBucket = "unknown"
    end
end

function Data:ApplyCommOverlay(record)
    record.activeRun = nil

    local comm = ns.Comm
    if not comm or not comm.IsEnabled or not comm:IsEnabled() then
        return
    end

    local snapshot = comm:GetSnapshot(record.fullName)
    if snapshot and comm:IsSnapshotPreferred(snapshot, record) and HasSharedMythicData(snapshot) then
        record.currentScore = snapshot.currentScore or 0
        record.mainCurrentScore = (snapshot.mainCurrentScore or 0) > 0 and snapshot.mainCurrentScore or nil
        record.maxDungeonLevel = snapshot.maxDungeonLevel or 0
        ApplySnapshotRunSummary(record, snapshot)
        record.profileState = "ready"
        record.scoreSource = "shared"
        record.scoreObservedAt = snapshot.observedAt
    end

    if snapshot and record.itemLevelSource ~= "self" and record.itemLevelSource ~= "inspect" then
        if type(snapshot.itemLevel) == "number" and snapshot.itemLevel > 0 then
            record.equippedItemLevel = snapshot.itemLevel
            record.itemLevelSource = "shared"
            record.itemLevelObservedAt = snapshot.observedAt
            record.itemLevelIsStale = ns:IsDataStale(record.itemLevelObservedAt)
        end
    end

    if snapshot and record.specSource ~= "self" and record.specSource ~= "inspect" then
        if type(snapshot.specID) == "number" and snapshot.specID > 0 then
            local specName, specIcon = ResolveSharedSpecInfo(self, snapshot.specID)
            record.specID = snapshot.specID
            record.specName = specName or record.specName
            record.specIcon = specIcon or record.specIcon
            record.specSource = "shared"
            record.specObservedAt = snapshot.observedAt
            record.specIsStale = ns:IsDataStale(record.specObservedAt)

            if specName then
                self.specCatalog[snapshot.specID] = {
                    specID = snapshot.specID,
                    specName = specName,
                    specIcon = specIcon
                }
            end
        end
    end

    if snapshot
        and snapshot.roleBucket
        and snapshot.roleBucket ~= "unknown"
        and record.roleSource ~= "group" then
        local sharedObservedAt = snapshot.observedAt or 0
        local inspectObservedAt = record.roleSource == "inspect" and (record.roleObservedAt or 0) or 0
        if record.roleSource ~= "inspect" or sharedObservedAt > inspectObservedAt then
            record.roleBucket = snapshot.roleBucket
            record.roleSource = "shared"
            record.roleObservedAt = snapshot.observedAt
        end
    end

    record.activeRun = comm:GetActiveRun(record.fullName)
    ApplyMilestoneDisplayFloors(record)
end

function Data:ApplyAstralKeys(record)
    record.reportedKey = nil
    if not ns.AstralKeys then
        return
    end

    record.reportedKey = ns.AstralKeys:GetUnitKey(record.fullName)
end

local function AreReportedKeysEqual(left, right)
    if not left and not right then
        return true
    elseif not left or not right then
        return false
    end

    return left.mapID == right.mapID and left.level == right.level
end

function Data:RefreshAstralKeys(reason)
    local changed = false

    if ns.AstralKeys and ns.AstralKeys:IsAvailable() then
        ns.AstralKeys:RefreshIndex()
    end

    for index = 1, #self.records do
        local record = self.records[index]
        local previousKey = record.reportedKey
        self:ApplyAstralKeys(record)
        if not AreReportedKeysEqual(previousKey, record.reportedKey) then
            changed = true
        end
    end

    if changed then
        ns:FireCallback("DATA_UPDATED", reason or "astralkeys")
    end
end

function Data:BuildFlatRecords()
    wipe(self.records)
    for _, record in pairs(self.recordsByKey) do
        table.insert(self.records, record)
    end
end

function Data:IsRecordQualifiedForMap(record, mapID, keyLevel)
    return self:GetRecordCurrentKeyStatus(record, mapID, keyLevel) ~= nil
end

function Data:GetRecordCurrentKeyStatus(record, mapID, keyLevel)
    if not record or not mapID or not keyLevel then
        return nil, nil
    end

    local bestProfile = nil
    local bestStatusRank = 0
    for index = 1, #(record.sortedDungeons or {}) do
        local dungeonProfile = record.sortedDungeons[index]
        local dungeon = dungeonProfile and dungeonProfile.dungeon
        if dungeon then
            local isMatch = dungeon.keystone_instance == mapID
                or dungeon.id == mapID
                or dungeon.instance_map_id == mapID
                or dungeon.index == mapID
            if isMatch and (dungeonProfile.level or 0) >= keyLevel then
                local chests = dungeonProfile.chests or 0
                local statusRank = chests >= 3 and 4 or chests >= 2 and 3 or chests >= 1 and 2 or 1
                if not bestProfile
                    or statusRank > bestStatusRank
                    or (statusRank == bestStatusRank and (dungeonProfile.level or 0) > (bestProfile.level or 0))
                    or (statusRank == bestStatusRank and (dungeonProfile.level or 0) == (bestProfile.level or 0) and chests > (bestProfile.chests or 0)) then
                    bestProfile = dungeonProfile
                    bestStatusRank = statusRank
                end
            end
        end
    end

    if not bestProfile then
        return nil, nil
    end

    local chests = bestProfile.chests or 0
    if chests >= 3 then
        return "plus3", bestProfile
    elseif chests >= 2 then
        return "plus2", bestProfile
    elseif chests >= 1 then
        return "timed", bestProfile
    end

    return "completed", bestProfile
end

function Data:UpdateCurrentKeyContext()
    local mapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    local mapName, _, _, texture, backgroundTexture
    if mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        mapName, _, _, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapID)
    end
    local context = {
        mapID = mapID,
        mapName = mapName,
        level = level,
        texture = texture,
        backgroundTexture = backgroundTexture,
        qualifiedCount = 0,
        qualifiedByRole = GetEmptyQualifiedByRole(),
        qualifiedMembers = {},
        bestByRole = {}
    }

    if not mapID or not level then
        for index = 1, #self.records do
            self.records[index].isQualifiedForCurrentKey = false
            self.records[index].currentKeyStatus = nil
            self.records[index].currentKeyLevel = nil
            self.records[index].currentKeyChests = nil
        end
        self.currentKeyContext = context
        return
    end

    for index = 1, #self.records do
        local record = self.records[index]
        local status, dungeonProfile = self:GetRecordCurrentKeyStatus(record, mapID, level)
        record.isQualifiedForCurrentKey = status ~= nil
        record.currentKeyStatus = status
        record.currentKeyLevel = dungeonProfile and dungeonProfile.level or nil
        record.currentKeyChests = dungeonProfile and dungeonProfile.chests or nil
        if status then
            context.qualifiedCount = context.qualifiedCount + 1
            context.qualifiedByRole[record.roleBucket or "unknown"] = (context.qualifiedByRole[record.roleBucket or "unknown"] or 0) + 1
            table.insert(context.qualifiedMembers, record)
        end
    end

    table.sort(context.qualifiedMembers, function(left, right)
        return Data:CompareRecords(left, right)
    end)

    for index = 1, #context.qualifiedMembers do
        local record = context.qualifiedMembers[index]
        local role = record.roleBucket or "unknown"
        if not context.bestByRole[role] then
            context.bestByRole[role] = record
        end
    end

    self.currentKeyContext = context
end

function Data:CompareRecords(left, right)
    if (left.currentScore or 0) ~= (right.currentScore or 0) then
        return (left.currentScore or 0) > (right.currentScore or 0)
    end

    if (left.maxDungeonLevel or 0) ~= (right.maxDungeonLevel or 0) then
        return (left.maxDungeonLevel or 0) > (right.maxDungeonLevel or 0)
    end

    if (left.timed20 or 0) ~= (right.timed20 or 0) then
        return (left.timed20 or 0) > (right.timed20 or 0)
    end

    if (left.timed15 or 0) ~= (right.timed15 or 0) then
        return (left.timed15 or 0) > (right.timed15 or 0)
    end

    if (left.equippedItemLevel or 0) ~= (right.equippedItemLevel or 0) then
        return (left.equippedItemLevel or 0) > (right.equippedItemLevel or 0)
    end

    return (left.fullName or "") < (right.fullName or "")
end

function Data:Refresh(reason)
    self:ResetRecords()
    self:CollectGuild()
    self:CollectFriends()
    self:CollectBNetFriends()
    self:BuildFlatRecords()

    if ns.AstralKeys then
        ns.AstralKeys:RefreshIndex()
    end

    for index = 1, #self.records do
        local record = self.records[index]
        self:ApplyRaiderIO(record)
        self:ApplyEnrichment(record)
        self:ApplyAstralKeys(record)
        self:ApplyCommOverlay(record)
    end

    table.sort(self.records, function(left, right)
        return Data:CompareRecords(left, right)
    end)

    self:UpdateCurrentKeyContext()
    ns:FireCallback("DATA_UPDATED", reason or "manual")
end

function Data:OnInspectDataReady(fullName, guid, payload)
    local record = self.recordsByKey[fullName]
    if not record then
        return
    end

    if payload.specID then
        record.specID = payload.specID
        record.specName = payload.specName
        record.specIcon = payload.specIcon
        record.specSource = "inspect"
        record.specObservedAt = payload.specObservedAt or payload.observedAt
        record.specIsStale = ns:IsDataStale(record.specObservedAt)
        self.specCatalog[payload.specID] = {
            specID = payload.specID,
            specName = payload.specName,
            specIcon = payload.specIcon
        }
    end

    if payload.itemLevel then
        record.equippedItemLevel = payload.itemLevel
        record.itemLevelSource = "inspect"
        record.itemLevelObservedAt = payload.itemLevelObservedAt or payload.observedAt
        record.itemLevelIsStale = ns:IsDataStale(record.itemLevelObservedAt)
    end

    if payload.roleBucket and record.roleSource ~= "group" then
        record.roleBucket = payload.roleBucket
        record.roleSource = "inspect"
        record.roleObservedAt = payload.specObservedAt or payload.observedAt
    end

    if guid and not record.guid then
        record.guid = guid
    end

    self:ApplyCommOverlay(record)
    self:UpdateCurrentKeyContext()
    ns:FireCallback("DATA_UPDATED", "inspect")
end

function Data:OnInspectTimeout()
    ns:FireCallback("DATA_UPDATED", "inspect_timeout")
end

function Data:GetClassOptions()
    local options = {}
    local count = GetNumClasses and GetNumClasses() or 0
    for classID = 1, count do
        local className, classFile = GetClassInfo(classID)
        if className and classFile then
            options[#options + 1] = {
                classID = classID,
                classFile = classFile,
                className = className
            }
        end
    end

    return options
end

function Data:GetRecords(filters)
    filters = filters or {}
    local output = {}

    for index = 1, #self.records do
        local record = self.records[index]
        local hasScore = (record.currentScore or 0) > 0 and record.profileState == "ready"
        local passes = ns:SourceMatches(record, filters.sourceFilter or "all")
            and ((filters.showOffline ~= false) or record.online)
            and ((filters.showUnscored == true) or hasScore)
            and ((filters.qualifiedOnly ~= true) or record.isQualifiedForCurrentKey)

        if passes then
            if filters.classFilter and filters.classFilter ~= "all" then
                passes = filters.classFilter == record.classFile
            end
        end

        if passes then
            table.insert(output, record)
        end
    end

    table.sort(output, function(left, right)
        return Data:CompareRecords(left, right)
    end)

    if not filters.groupByRole then
        return output
    end

    local grouped = {}
    local buckets = {
        { id = "tank", label = ns.L.ROLE_TANK },
        { id = "healer", label = ns.L.ROLE_HEALER },
        { id = "dps", label = ns.L.ROLE_DPS },
        { id = "unknown", label = ns.L.ROLE_UNKNOWN }
    }

    for bucketIndex = 1, #buckets do
        local bucket = buckets[bucketIndex]
        local insertedHeader = false
        for recordIndex = 1, #output do
            local record = output[recordIndex]
            if (record.roleBucket or "unknown") == bucket.id then
                if not insertedHeader then
                    table.insert(grouped, {
                        isHeader = true,
                        roleBucket = bucket.id,
                        label = bucket.label
                    })
                    insertedHeader = true
                end

                table.insert(grouped, record)
            end
        end
    end

    return grouped
end

function Data:GetRecord(fullName)
    return self.recordsByKey[fullName]
end

function Data:GetCurrentKeyContext()
    return self.currentKeyContext
end

local function RefreshRoster()
    if not ns.db then
        return
    end

    Data:Refresh("event")
end

ns:RegisterCallback("PLAYER_LOGIN", function()
    Data:Refresh("login")
end)

ns:RegisterEvent("ADDON_LOADED", function(name)
    if name == "AstralKeys" and ns.db then
        Data:Refresh("astralkeys_loaded")
    end
end)

ns:RegisterEvent("CHAT_MSG_ADDON", function(prefix)
    if prefix == "AstralKeys" and ns.db then
        Data:RefreshAstralKeys("astralkeys_sync")
    end
end)

ns:RegisterEvent("FRIENDLIST_UPDATE", RefreshRoster)
ns:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", RefreshRoster)
ns:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE", RefreshRoster)
ns:RegisterEvent("BN_FRIEND_INFO_CHANGED", RefreshRoster)
ns:RegisterEvent("GUILD_ROSTER_UPDATE", RefreshRoster)
ns:RegisterEvent("PLAYER_ROLES_ASSIGNED", RefreshRoster)
ns:RegisterEvent("GROUP_ROSTER_UPDATE", RefreshRoster)
ns:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", RefreshRoster)
ns:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE", RefreshRoster)
ns:RegisterEvent("BAG_UPDATE_DELAYED", RefreshRoster)
