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

function ns:GetDataAgeText(timestamp)
    local age = self:GetDataAge(timestamp)
    if not age then
        return nil
    end

    if type(SecondsToTimeAbbrev) == "function" then
        return SecondsToTimeAbbrev(age)
    end

    if age >= 86400 then
        return self.L.CACHE_AGE_DAYS:format(math.floor(age / 86400))
    end

    if age >= 3600 then
        return self.L.CACHE_AGE_HOURS:format(math.floor(age / 3600))
    end

    return self.L.CACHE_AGE_MINUTES:format(math.max(1, math.floor(age / 60)))
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
