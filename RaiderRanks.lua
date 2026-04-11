local addonName, ns = ...

_G[addonName] = ns

ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"
ns.private = ns.private or {}
ns.callbacks = ns.callbacks or {}
ns.playerRealm = GetRealmName()
ns.playerFullName = nil

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

function ns:Round(value, precision)
    local multiplier = 10 ^ (precision or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
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
