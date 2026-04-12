local addonName, ns = ...

_G[addonName] = ns

ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
ns.private = ns.private or {}
ns.callbacks = ns.callbacks or {}
ns.playerRealm = GetRealmName()
ns.playerFullName = nil
ns.inspectStaleAgeSeconds = 24 * 60 * 60

local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame
ns.eventRegistry = {}

local roleMarkup = {
    tank = CreateAtlasMarkup("roleicon-tiny-tank", 14, 14),
    healer = CreateAtlasMarkup("roleicon-tiny-healer", 14, 14),
    dps = CreateAtlasMarkup("roleicon-tiny-dps", 14, 14),
    unknown = CreateAtlasMarkup("common-icon-rotateright", 14, 14)
}

local roleAtlases = {
    tank = "roleicon-tiny-tank",
    healer = "roleicon-tiny-healer",
    dps = "roleicon-tiny-dps",
    unknown = "common-icon-rotateright"
}

local timedBucketLabels = {
    timed20 = "TIMED_20",
    timed15 = "TIMED_15",
    timed11_14 = "TIMED_11_14",
    timed9_10 = "TIMED_9_10",
    timed4_8 = "TIMED_4_8",
    timed2_3 = "TIMED_2_3"
}

local timedBucketNames = {
    timed11_14 = "TIMED_BUCKET_MYTH",
    timed9_10 = "TIMED_BUCKET_MYTH",
    timed4_8 = "TIMED_BUCKET_HERO",
    timed2_3 = "TIMED_BUCKET_CHAMPION"
}

local timedBucketIcons = {
    timed9_10 = "Interface\\Icons\\inv_120_crest_myth",
    timed4_8 = "Interface\\Icons\\inv_120_crest_hero",
    timed2_3 = "Interface\\Icons\\inv_120_crest_champion"
}

local sourcePriority = {
    guild = 1,
    friend = 2,
    guild_friend = 3
}

local raiderIORegionOrder = {
    Americas = 1,
    Europe = 2,
    Korea = 3,
    Taiwan = 4,
    China = 5
}

local raiderIOTypeOrder = {
    ["Mythic Plus"] = 1,
    Raiding = 2,
    Recruitment = 3
}

local function OnEvent(_, event, ...)
    local handlers = ns.eventRegistry[event]
    if not handlers then
        return
    end

    for index = 1, #handlers do
        local handler = handlers[index]
        local ok, err = pcall(handler, ...)
        if not ok then
            geterrorhandler()(("%s event failure (%s): %s"):format(addonName, event, err))
        end
    end
end

eventFrame:SetScript("OnEvent", OnEvent)

function ns:RegisterEvent(event, handler)
    if not ns.eventRegistry[event] then
        ns.eventRegistry[event] = {}
        eventFrame:RegisterEvent(event)
    end

    table.insert(ns.eventRegistry[event], handler)
end

function ns:RegisterCallback(event, handler)
    if not ns.callbacks[event] then
        ns.callbacks[event] = {}
    end

    table.insert(ns.callbacks[event], handler)
end

function ns:FireCallback(event, ...)
    local handlers = ns.callbacks[event]
    if not handlers then
        return
    end

    for index = 1, #handlers do
        local ok, err = pcall(handlers[index], ...)
        if not ok then
            geterrorhandler()(("%s callback failure (%s): %s"):format(addonName, event, err))
        end
    end
end

function ns:TrimRealmName(realm)
    if type(realm) ~= "string" then
        return ns.playerRealm
    end

    realm = realm:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if realm == "" then
        return ns.playerRealm
    end

    return realm
end

function ns:SplitNameRealm(fullName, fallbackRealm)
    if type(fullName) ~= "string" or fullName == "" then
        return nil, nil
    end

    local name, realm = strsplit("-", fullName, 2)
    realm = realm or fallbackRealm or ns.playerRealm

    return name, ns:TrimRealmName(realm)
end

function ns:ComposeFullName(name, realm)
    if not name or name == "" then
        return nil
    end

    realm = ns:TrimRealmName(realm)
    return ("%s-%s"):format(name, realm)
end

function ns:GetDisplayName(name, realm)
    if not name or name == "" then
        return ""
    end

    realm = ns:TrimRealmName(realm)
    if not realm or realm == "" or realm == ns.playerRealm then
        return name
    end

    return ("%s-%s"):format(name, realm)
end

function ns:GetRecordDisplayName(record)
    if not record then
        return ""
    end

    return ns:GetDisplayName(record.name, record.realm)
end

function ns:Round(value, precision)
    local multiplier = 10 ^ (precision or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

function ns:GetCurrentTimestamp()
    if type(GetServerTime) == "function" then
        local timestamp = GetServerTime()
        if type(timestamp) == "number" and timestamp > 0 then
            return timestamp
        end
    end

    if type(time) == "function" then
        local timestamp = time()
        if type(timestamp) == "number" and timestamp > 0 then
            return timestamp
        end
    end

    return nil
end

function ns:GetDataAge(timestamp)
    if type(timestamp) ~= "number" or timestamp <= 0 then
        return nil
    end

    local now = self:GetCurrentTimestamp()
    if type(now) ~= "number" or now <= 0 then
        return nil
    end

    return math.max(0, now - timestamp)
end

function ns:IsDataStale(timestamp)
    local age = self:GetDataAge(timestamp)
    return age ~= nil and age > self.inspectStaleAgeSeconds or false
end

local function FormatDataAgeFallback(self, age)
    if age >= 86400 then
        return self.L.CACHE_AGE_DAYS:format(math.floor(age / 86400))
    end

    if age >= 3600 then
        return self.L.CACHE_AGE_HOURS:format(math.floor(age / 3600))
    end

    return self.L.CACHE_AGE_MINUTES:format(math.max(1, math.floor(age / 60)))
end

function ns:GetDataAgeText(timestamp)
    local age = self:GetDataAge(timestamp)
    if not age then
        return nil
    end

    if type(SecondsToTimeAbbrev) == "function" then
        local ageText = SecondsToTimeAbbrev(age)
        if type(ageText) == "string" and ageText ~= "" and not ageText:find("%%") then
            return ageText
        end
    end

    return FormatDataAgeFallback(self, age)
end

local function NormalizeColorResult(a, b, c)
    if type(a) == "table" then
        if a.GetRGB then
            return a
        end

        if type(a.r) == "number" and type(a.g) == "number" and type(a.b) == "number" then
            return CreateColor(a.r, a.g, a.b, a.a or 1)
        end
    end

    if type(a) == "number" and type(b) == "number" and type(c) == "number" then
        return CreateColor(a, b, c)
    end

    return nil
end

local function AppendUnique(list, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
        return
    end

    seen[value] = true
    list[#list + 1] = value
end

local function SortStrings(values, orderMap)
    table.sort(values, function(left, right)
        local leftOrder = orderMap and orderMap[left] or nil
        local rightOrder = orderMap and orderMap[right] or nil
        if leftOrder and rightOrder and leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end

        if leftOrder and not rightOrder then
            return true
        end

        if rightOrder and not leftOrder then
            return false
        end

        return left < right
    end)
end

local function GetRaiderIOVersionStamp(version)
    if type(version) ~= "string" then
        return nil, nil
    end

    local raw = version:match("v(%d%d%d%d%d%d%d%d%d%d%d%d)")
    if not raw then
        return nil, nil
    end

    local year, month, day, hour, minute = raw:match("(%d%d%d%d)(%d%d)(%d%d)(%d%d)(%d%d)")
    if not year then
        return raw, nil
    end

    return raw, ("%s-%s-%s %s:%s"):format(year, month, day, hour, minute)
end

local function ParseRaiderIOVersionTimestamp(version)
    local _, timestampText = GetRaiderIOVersionStamp(version)
    return timestampText
end

function ns:GetDisplayedItemLevel(itemLevel)
    if type(itemLevel) ~= "number" or itemLevel <= 0 then
        return nil
    end

    return math.floor(itemLevel + 0.5)
end

function ns:GetItemLevelText(itemLevel)
    local displayed = self:GetDisplayedItemLevel(itemLevel)
    if not displayed then
        return "-"
    end

    return tostring(displayed)
end

function ns:GetItemLevelColor(itemLevel)
    local displayed = self:GetDisplayedItemLevel(itemLevel)
    if not displayed then
        return HIGHLIGHT_FONT_COLOR
    end

    local color = nil

    if C_PaperDollInfo and type(C_PaperDollInfo.GetItemLevelColor) == "function" then
        local a, b, c = C_PaperDollInfo.GetItemLevelColor(displayed)
        color = NormalizeColorResult(a, b, c)
    end

    if not color and type(PaperDollFrame_GetItemLevelColor) == "function" then
        local a, b, c = PaperDollFrame_GetItemLevelColor(displayed)
        color = NormalizeColorResult(a, b, c)
    end

    if not color and type(GetItemLevelColor) == "function" then
        local a, b, c = GetItemLevelColor(displayed)
        color = NormalizeColorResult(a, b, c)
    end

    return color or HIGHLIGHT_FONT_COLOR
end

function ns:GetColoredItemLevelText(itemLevel)
    local text = self:GetItemLevelText(itemLevel)
    local color = self:GetItemLevelColor(itemLevel)
    if color and color.WrapTextInColorCode then
        return color:WrapTextInColorCode(text)
    end

    return text
end

function ns:GetRunCountColor(count)
    local quality = 1
    if type(count) == "number" then
        if count >= 9 then
            quality = 5
        elseif count >= 7 then
            quality = 4
        elseif count >= 5 then
            quality = 3
        elseif count >= 3 then
            quality = 2
        else
            quality = 1
        end
    end

    if type(GetItemQualityColor) == "function" then
        local r, g, b = GetItemQualityColor(quality)
        local color = NormalizeColorResult(r, g, b)
        if color then
            return color
        end
    end

    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local entry = ITEM_QUALITY_COLORS[quality]
        local color = NormalizeColorResult(entry)
            or NormalizeColorResult(entry.color)
            or NormalizeColorResult(entry.r, entry.g, entry.b)
        if color then
            return color
        end
    end

    return NORMAL_FONT_COLOR
end

function ns:GetColoredRunCountText(count)
    local text = tostring(count or 0)
    local color = self:GetRunCountColor(count)
    if color and color.WrapTextInColorCode then
        return color:WrapTextInColorCode(text)
    end

    return text
end

function ns:GetRoleBucketFromGroup(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local role = UnitGroupRolesAssigned(unit)
    if role == "TANK" then
        return "tank"
    elseif role == "HEALER" then
        return "healer"
    elseif role == "DAMAGER" then
        return "dps"
    end

    return nil
end

function ns:GetRoleLabel(roleBucket)
    local L = ns.L
    if roleBucket == "tank" then
        return L.ROLE_TANK
    elseif roleBucket == "healer" then
        return L.ROLE_HEALER
    elseif roleBucket == "dps" then
        return L.ROLE_DPS
    end

    return L.ROLE_UNKNOWN
end

function ns:GetRoleMarkup(roleBucket)
    return roleMarkup[roleBucket or "unknown"] or roleMarkup.unknown
end

function ns:GetRoleAtlas(roleBucket)
    return roleAtlases[roleBucket or "unknown"] or roleAtlases.unknown
end

function ns:GetTimedBucketLabel(bucketKey)
    local labelKey = timedBucketLabels[bucketKey]
    return labelKey and ns.L[labelKey] or ""
end

function ns:GetTimedBucketIcon(bucketKey)
    return timedBucketIcons[bucketKey]
end

function ns:GetTimedBucketName(bucketKey)
    local labelKey = timedBucketNames[bucketKey]
    return labelKey and ns.L[labelKey] or nil
end

function ns:GetTimedBucketMarkup(bucketKey, size)
    local texture = self:GetTimedBucketIcon(bucketKey)
    if not texture then
        return ""
    end

    size = size or 14
    return ("|T%s:%d:%d:0:0|t"):format(texture, size, size)
end

function ns:GetClassColor(classFile)
    if classFile and RAID_CLASS_COLORS[classFile] then
        return RAID_CLASS_COLORS[classFile]
    end

    return NORMAL_FONT_COLOR
end

function ns:GetScoreColor(score)
    if _G.RaiderIO and type(_G.RaiderIO.GetScoreColor) == "function" then
        local r, g, b = _G.RaiderIO.GetScoreColor(score or 0)
        return CreateColor(r, g, b)
    end

    local rarityColor = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor and C_ChallengeMode.GetDungeonScoreRarityColor(score or 0)
    return rarityColor or NORMAL_FONT_COLOR
end

function ns:GetDungeonLevelText(level)
    if type(level) ~= "number" or level <= 0 then
        return "-"
    end

    return ("%d"):format(level)
end

function ns:SourceMatches(record, filter)
    if filter == "all" then
        return true
    end

    if filter == "guild" then
        return record.isGuild
    elseif filter == "friends" then
        return record.isFriend
    end

    return false
end

function ns:ChoosePreferredSource(current, incoming)
    if not current then
        return incoming
    end

    if sourcePriority[incoming] and sourcePriority[current] and sourcePriority[incoming] > sourcePriority[current] then
        return incoming
    end

    return current
end

function ns:IsRaiderIOAvailable()
    return _G.RaiderIO
        and type(_G.RaiderIO.GetProfile) == "function"
        and type(_G.RaiderIO.ShowProfile) == "function"
end

function ns:GetAddOnMetadata(addon, field)
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata(addon, field)
    end

    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(addon, field)
    end

    return nil
end

function ns:IsAddOnLoaded(addon)
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        return not not C_AddOns.IsAddOnLoaded(addon)
    end

    if type(IsAddOnLoaded) == "function" then
        return not not IsAddOnLoaded(addon)
    end

    return false
end

function ns:GetAddOnCount()
    if C_AddOns and type(C_AddOns.GetNumAddOns) == "function" then
        return C_AddOns.GetNumAddOns()
    end

    if type(GetNumAddOns) == "function" then
        return GetNumAddOns()
    end

    return 0
end

function ns:GetAddOnName(index)
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        local info = C_AddOns.GetAddOnInfo(index)
        if type(info) == "table" then
            return info.name
        end

        return info
    end

    if type(GetAddOnInfo) == "function" then
        local name = GetAddOnInfo(index)
        return name
    end

    return nil
end

function ns:GetRaiderIOMetadata()
    local metadata = {
        status = ns:IsRaiderIOAvailable() and "detected" or "missing",
        coreVersion = ns:GetAddOnMetadata("RaiderIO", "Version"),
        loadedRegions = {},
        loadedVersions = {},
        loadedTimestamps = {},
        datasets = {},
        loadedRegionText = (ns.L and ns.L.SETTINGS_RAIDERIO_NONE) or (NONE or "None"),
        versionText = (ns.L and ns.L.UNKNOWN) or (UNKNOWN or "Unknown"),
        timestampText = (ns.L and ns.L.UNKNOWN) or (UNKNOWN or "Unknown")
    }

    local loadedRegionMap = {}
    local loadedRegionSeen = {}
    local loadedVersionSeen = {}
    local loadedTimestampSeen = {}
    local datasetSeen = {}

    for index = 1, ns:GetAddOnCount() do
        local addonName = ns:GetAddOnName(index)
        if type(addonName) == "string"
            and addonName:match("^RaiderIO_DB_")
            and ns:IsAddOnLoaded(addonName) then
            local region = ns:GetAddOnMetadata(addonName, "X-Region")
            local dataType = ns:GetAddOnMetadata(addonName, "X-Type")
            local version = ns:GetAddOnMetadata(addonName, "Version")
            local stampRaw, timestampText = GetRaiderIOVersionStamp(version)

            if region then
                local regionData = loadedRegionMap[region]
                if not regionData then
                    regionData = {
                        types = {},
                        typeSeen = {}
                    }
                    loadedRegionMap[region] = regionData
                end

                AppendUnique(metadata.loadedRegions, loadedRegionSeen, region)
                AppendUnique(regionData.types, regionData.typeSeen, dataType)
            end

            AppendUnique(metadata.loadedVersions, loadedVersionSeen, version)
            AppendUnique(metadata.loadedTimestamps, loadedTimestampSeen, timestampText)

            if region and dataType and stampRaw then
                local datasetKey = ("%s|%s|%s"):format(region, dataType, stampRaw)
                if not datasetSeen[datasetKey] then
                    datasetSeen[datasetKey] = true
                    metadata.datasets[#metadata.datasets + 1] = {
                        key = ("%s|%s"):format(region, dataType),
                        region = region,
                        dataType = dataType,
                        version = version,
                        stampRaw = stampRaw,
                        stamp = tonumber(stampRaw),
                        timestampText = timestampText
                    }
                end
            end
        end
    end

    if #metadata.loadedRegions > 0 then
        SortStrings(metadata.loadedRegions, raiderIORegionOrder)

        local regionEntries = {}
        for index = 1, #metadata.loadedRegions do
            local region = metadata.loadedRegions[index]
            local regionData = loadedRegionMap[region]
            local entry = region

            if regionData and #regionData.types > 0 then
                SortStrings(regionData.types, raiderIOTypeOrder)
                entry = ("%s (%s)"):format(region, table.concat(regionData.types, ", "))
            end

            regionEntries[#regionEntries + 1] = entry
        end

        metadata.loadedRegionText = table.concat(regionEntries, "; ")
    end

    local fallbackTimestamp = ParseRaiderIOVersionTimestamp(metadata.coreVersion)
    if #metadata.loadedVersions > 0 then
        metadata.versionText = table.concat(metadata.loadedVersions, ", ")
    elseif metadata.coreVersion and metadata.coreVersion ~= "" then
        metadata.versionText = metadata.coreVersion
    end

    if #metadata.loadedTimestamps > 0 then
        metadata.timestampText = table.concat(metadata.loadedTimestamps, ", ")
    elseif fallbackTimestamp then
        metadata.timestampText = fallbackTimestamp
    end

    table.sort(metadata.datasets, function(left, right)
        local leftRegionOrder = raiderIORegionOrder[left.region] or math.huge
        local rightRegionOrder = raiderIORegionOrder[right.region] or math.huge
        if leftRegionOrder ~= rightRegionOrder then
            return leftRegionOrder < rightRegionOrder
        end

        local leftTypeOrder = raiderIOTypeOrder[left.dataType] or math.huge
        local rightTypeOrder = raiderIOTypeOrder[right.dataType] or math.huge
        if leftTypeOrder ~= rightTypeOrder then
            return leftTypeOrder < rightTypeOrder
        end

        return (left.stamp or 0) < (right.stamp or 0)
    end)

    return metadata
end

function ns:ShowProfileTooltip(tooltip, name, realm)
    if not tooltip or not ns:IsRaiderIOAvailable() then
        return false
    end

    return _G.RaiderIO.ShowProfile(tooltip, name, realm) or false
end

function ns:BuildRecordKey(record)
    if not record then
        return nil
    end

    return ns:ComposeFullName(record.name, record.realm)
end

function ns:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(("|cff00c0ff%s|r: %s"):format(addonName, tostring(message)))
end

local function HandleAddonLoaded(loadedName)
    if loadedName ~= addonName then
        return
    end

    ns:FireCallback("ADDON_READY")
end

local function HandlePlayerLogin()
    local name, realm = UnitFullName("player")
    ns.playerRealm = realm or GetRealmName()
    ns.playerFullName = ns:ComposeFullName(name, ns.playerRealm)

    ns:FireCallback("PLAYER_LOGIN")
end

ns:RegisterEvent("ADDON_LOADED", HandleAddonLoaded)
ns:RegisterEvent("PLAYER_LOGIN", HandlePlayerLogin)
