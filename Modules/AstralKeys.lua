local _, ns = ...

local AstralKeysAdapter = {
    unitIndex = {},
    indexBuilt = false,
    entryCount = 0
}

ns.AstralKeys = AstralKeysAdapter

local function NormalizeUnitKey(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return nil
    end

    local name, realm = ns:SplitNameRealm(fullName, ns.playerRealm)
    if not name or not realm then
        return nil
    end

    realm = realm:gsub("%s+", "")
    return ("%s-%s"):format(strlower(name), strlower(realm))
end

function AstralKeysAdapter:IsAvailable()
    return ns:IsAddOnLoaded("AstralKeys") and type(_G.AstralKeys) == "table"
end

function AstralKeysAdapter:RefreshIndex()
    wipe(self.unitIndex)
    self.indexBuilt = true
    self.entryCount = 0

    if not self:IsAvailable() then
        return
    end

    for index = 1, #_G.AstralKeys do
        local entry = _G.AstralKeys[index]
        local unitKey = entry and NormalizeUnitKey(entry.unit)
        local mapID = entry and tonumber(entry.dungeon_id)
        local level = entry and tonumber(entry.key_level)
        if unitKey and mapID and level then
            if not self.unitIndex[unitKey] then
                self.entryCount = self.entryCount + 1
            end
            self.unitIndex[unitKey] = entry
        end
    end
end

local function GetMapInfo(mapID)
    if not mapID or not C_ChallengeMode or not C_ChallengeMode.GetMapUIInfo then
        return nil, nil, nil
    end

    local mapName, _, _, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(mapID)
    return mapName, texture, backgroundTexture
end

function AstralKeysAdapter:GetUnitKey(fullName)
    if not self.indexBuilt then
        self:RefreshIndex()
    end

    local unitKey = NormalizeUnitKey(fullName)
    local entry = unitKey and self.unitIndex[unitKey] or nil
    if not entry then
        return nil
    end

    local mapID = tonumber(entry.dungeon_id)
    local level = tonumber(entry.key_level)
    local mapName, texture, backgroundTexture = GetMapInfo(mapID)

    return {
        unit = entry.unit,
        mapID = mapID,
        level = level,
        mapName = mapName or ns.L.UNKNOWN,
        texture = texture,
        backgroundTexture = backgroundTexture,
        weeklyBest = tonumber(entry.weekly_best),
        mplusScore = tonumber(entry.mplus_score),
        timeStamp = tonumber(entry.time_stamp),
        source = "astralkeys"
    }
end

function AstralKeysAdapter:GetMetadata()
    self:RefreshIndex()

    return {
        status = self:IsAvailable() and "detected" or "missing",
        versionText = ns:GetAddOnMetadata("AstralKeys", "Version") or ns.L.UNKNOWN,
        entryCount = self.entryCount
    }
end

ns:RegisterEvent("ADDON_LOADED", function(name)
    if name == "AstralKeys" then
        AstralKeysAdapter.indexBuilt = false
    end
end)
