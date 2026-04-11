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
        timed10 = 0,
        timed5 = 0,
        sortedDungeons = {},
        equippedItemLevel = nil,
        itemLevelSource = "unknown",
        roleBucket = "unknown",
        roleSource = "unknown",
        specID = nil,
        specName = nil,
        specIcon = nil,
        specSource = "unknown",
        profileState = ns:IsRaiderIOAvailable() and "unscored" or "missing_dependency",
        raidSummary = {},
        unitToken = nil,
        hasRenderableProfile = false,
        isQualifiedForCurrentKey = false,
        currentKeyStatus = nil,
        currentKeyLevel = nil,
        currentKeyChests = nil
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
    record.timed10 = 0
    record.timed5 = 0
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
        record.timed20 = mythic.keystoneTwentyPlus or 0
        record.timed15 = mythic.keystoneFifteenPlus or 0
        record.timed10 = mythic.keystoneTenPlus or 0
        record.timed5 = mythic.keystoneFivePlus or 0
        record.sortedDungeons = mythic.sortedDungeons or {}

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
    record.specSource = "unknown"
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
    for index = 1, #(record.sortedDungeons or {}) do
        local dungeonProfile = record.sortedDungeons[index]
        local dungeon = dungeonProfile and dungeonProfile.dungeon
        if dungeon then
            local isMatch = dungeon.keystone_instance == mapID
                or dungeon.id == mapID
                or dungeon.instance_map_id == mapID
                or dungeon.index == mapID
            if isMatch and (dungeonProfile.level or 0) >= keyLevel then
                if not bestProfile
                    or (dungeonProfile.level or 0) > (bestProfile.level or 0)
                    or ((dungeonProfile.level or 0) == (bestProfile.level or 0) and (dungeonProfile.chests or 0) > (bestProfile.chests or 0)) then
                    bestProfile = dungeonProfile
                end
            end
        end
    end

    if not bestProfile then
        return nil, nil
    end

    local chests = bestProfile.chests or 0
    if chests >= 2 then
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

    for index = 1, #self.records do
        local record = self.records[index]
        self:ApplyRaiderIO(record)
        self:ApplyEnrichment(record)
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
        self.specCatalog[payload.specID] = {
            specID = payload.specID,
            specName = payload.specName,
            specIcon = payload.specIcon
        }
    end

    if payload.itemLevel then
        record.equippedItemLevel = payload.itemLevel
        record.itemLevelSource = "inspect"
    end

    if payload.roleBucket and record.roleSource ~= "group" then
        record.roleBucket = payload.roleBucket
    end

    if guid and not record.guid then
        record.guid = guid
    end

    self:UpdateCurrentKeyContext()
    ns:FireCallback("DATA_UPDATED", "inspect")
end

function Data:OnInspectTimeout()
    ns:FireCallback("DATA_UPDATED", "inspect_timeout")
end

function Data:GetSpecOptions()
    local options = {}
    for _, specInfo in pairs(self.specCatalog) do
        table.insert(options, specInfo)
    end

    table.sort(options, function(left, right)
        return left.specName < right.specName
    end)

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
            if filters.specFilter and filters.specFilter ~= "all" then
                passes = tonumber(filters.specFilter) == tonumber(record.specID)
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
