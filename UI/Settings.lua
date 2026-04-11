local _, ns = ...

local SettingsPanel = {
    categoryID = nil
}

ns.Settings = SettingsPanel

function SettingsPanel:CreateCheckbox(parent, label, tooltip, anchor, getter, setter)
    local button = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    button.Text:SetText(label)
    button.tooltipText = tooltip
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    button:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)
    button.GetCheckedState = getter
    return button
end

function SettingsPanel:Refresh()
    if not self.panel then
        return
    end

    local checkboxes = self.panel.checkboxes
    for index = 1, #checkboxes do
        local button = checkboxes[index]
        button:SetChecked(button.GetCheckedState())
    end
end

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

    panel.subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -8)
    panel.subtitle:SetWidth(620)
    panel.subtitle:SetJustifyH("LEFT")
    panel.subtitle:SetText(ns.L.SETTINGS_SEARCH_HINT)

    panel.checkboxes = {}

    local function AddCheckbox(label, key)
        local anchor = panel.checkboxes[#panel.checkboxes] or panel.subtitle
        local button = SettingsPanel:CreateCheckbox(
            panel,
            label,
            nil,
            anchor,
            function()
                return ns.Config:Get(key)
            end,
            function(value)
                ns.Config:Set(key, value)
            end
        )
        panel.checkboxes[#panel.checkboxes + 1] = button
        return button
    end

    AddCheckbox(ns.L.SETTING_ENABLE_GUILD_INLINE, "enableGuildInline")
    AddCheckbox(ns.L.SETTING_ENABLE_FRIENDS_INLINE, "enableFriendsInline")
    AddCheckbox(ns.L.SETTING_SHOW_ITEM_LEVEL, "showItemLevel")
    AddCheckbox(ns.L.SETTING_ENABLE_INSPECT, "enableInspectEnrichment")
    AddCheckbox(ns.L.SETTING_SHOW_RAID_CONTEXT, "showRaidContext")
    AddCheckbox(ns.L.SETTING_GROUP_BY_ROLE, "groupByRole")
    AddCheckbox(ns.L.SETTING_SHOW_CURRENT_KEY_HELPER, "showCurrentKeyHelper")

    panel:SetScript("OnShow", function()
        SettingsPanel:Refresh()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.L.ADDON_TITLE, ns.L.ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
    self.categoryID = category.ID
end

ns:RegisterCallback("PLAYER_LOGIN", function()
    SettingsPanel:Create()
end)
