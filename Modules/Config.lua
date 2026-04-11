local _, ns = ...

local Config = {}
ns.Config = Config

local defaults = {
    enableGuildInline = true,
    enableFriendsInline = true,
    showItemLevel = true,
    enableInspectEnrichment = true,
    showRaidContext = true,
    groupByRole = true,
    classFilter = "all",
    showOffline = true,
    showUnscored = false,
    sourceFilter = "all",
    sortKey = "score",
    sortAscending = false,
    inspectCache = {
        byName = {},
        byGUID = {}
    },
    migrations = {},
    windowPoint = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0
    }
}

local function CopyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Config:GetDefaults()
    return defaults
end

function Config:Initialize()
    if type(_G.RaiderRanksDB) ~= "table" then
        _G.RaiderRanksDB = {}
    end

    CopyDefaults(_G.RaiderRanksDB, defaults)

    if not _G.RaiderRanksDB.migrations.hideUnscoredEntries then
        _G.RaiderRanksDB.showUnscored = false
        _G.RaiderRanksDB.migrations.hideUnscoredEntries = true
    end

    if not _G.RaiderRanksDB.migrations.classFilterEnabled then
        _G.RaiderRanksDB.classFilter = "all"
        _G.RaiderRanksDB.migrations.classFilterEnabled = true
    end

    ns.db = _G.RaiderRanksDB
end

function Config:Get(key)
    if not ns.db then
        return defaults[key]
    end

    local value = ns.db[key]
    if value == nil then
        return defaults[key]
    end

    return value
end

function Config:Set(key, value)
    if not ns.db then
        return
    end

    ns.db[key] = value
    ns:FireCallback("CONFIG_CHANGED", key, value)
end

function Config:Toggle(key)
    self:Set(key, not self:Get(key))
end

function Config:GetWindowPoint()
    local point = self:Get("windowPoint")
    if type(point) ~= "table" then
        return defaults.windowPoint
    end

    return point
end

function Config:SetWindowPoint(point, relativePoint, x, y)
    if not ns.db then
        return
    end

    ns.db.windowPoint = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y
    }

    ns:FireCallback("CONFIG_CHANGED", "windowPoint", ns.db.windowPoint)
end

ns:RegisterCallback("ADDON_READY", function()
    Config:Initialize()
end)
