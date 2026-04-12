local _, ns = ...

local locale = GetLocale()

local prototype = {
    __index = function(_, key)
        return ("[%s] %s"):format(locale, tostring(key))
    end
}

function ns:NewLocale(localeCode)
    if type(localeCode) ~= "string" or localeCode == "" then
        return nil
    end

    if not self.L then
        self.L = setmetatable({}, prototype)
    end

    if localeCode == "enUS" or localeCode == locale then
        return self.L
    end

    return nil
end
