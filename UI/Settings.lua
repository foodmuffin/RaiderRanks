local _, ns = ...

local SettingsPanel = {
    categoryID = nil
}

ns.Settings = SettingsPanel

function SettingsPanel:Open()
    if not self.panel then
        self:Create()
    end

    if not self.categoryID then
        return
    end

    Settings.OpenToCategory(self.categoryID)
    Settings.OpenToCategory(self.categoryID)
end

function SettingsPanel:Create()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame")
    self.panel = panel
    panel.name = ns.L.ADDON_TITLE

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -16)
    panel.title:SetText(ns.L.SETTINGS_HEADER)

    panel.version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.version:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -12)
    panel.version:SetText(("%s: %s"):format(VERSION or "Version", ns.version))

    panel.description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.description:SetPoint("TOPLEFT", panel.version, "BOTTOMLEFT", 0, -12)
    panel.description:SetWidth(620)
    panel.description:SetJustifyH("LEFT")
    panel.description:SetJustifyV("TOP")
    panel.description:SetWordWrap(true)
    panel.description:SetText(ns.L.ADDON_DESCRIPTION)

    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.L.ADDON_TITLE, ns.L.ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
    self.categoryID = category.ID
end

ns:RegisterCallback("PLAYER_LOGIN", function()
    SettingsPanel:Create()
end)
