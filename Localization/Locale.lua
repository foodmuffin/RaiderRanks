local _, ns = ...

local locale = GetLocale()

local prototype = {
    __index = function(_, key)
        return ("[%s] %s"):format(locale, tostring(key))
    end
}

function ns:NewLocale()
    return setmetatable({}, prototype)
end
