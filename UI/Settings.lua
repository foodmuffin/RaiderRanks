local _, ns = ...

local SettingsPanel = {
    categoryID = nil
}

ns.Settings = SettingsPanel

local function CreateWrappedText(parent, template, anchor, offsetY)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template)
    fontString:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    fontString:SetWidth(620)
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")
    fontString:SetWordWrap(true)
    return fontString
end

local function CreateCheckbox(parent, anchor, offsetY, label, settingKey)
    local button = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
    button.Text:SetText(label)
    button.settingKey = settingKey
    button:SetScript("OnClick", function(self)
        ns.Config:Set(self.settingKey, not not self:GetChecked())
    end)
    return button
end

local function SetCheckboxEnabled(button, enabled)
    if not button then
        return
    end

    button:SetEnabled(enabled)
    if button.Text then
        if enabled then
            button.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        else
            button.Text:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        end
    end
end

function SettingsPanel:RefreshRaiderIOMetadata()
    if not self.panel or not self.panel.raiderIOStatus then
        return
    end

    local metadata = ns:GetRaiderIOMetadata()
    local statusLabel = metadata.status == "detected"
        and ns.L.SETTINGS_RAIDERIO_DETECTED
        or ns.L.SETTINGS_RAIDERIO_NOT_DETECTED

    self.panel.raiderIOStatus:SetText(ns.L.SETTINGS_RAIDERIO_STATUS_FORMAT:format(statusLabel))
    self.panel.raiderIORegions:SetText(ns.L.SETTINGS_RAIDERIO_REGIONS_FORMAT:format(metadata.loadedRegionText))
    self.panel.raiderIOVersion:SetText(ns.L.SETTINGS_RAIDERIO_VERSION_FORMAT:format(metadata.versionText))
    self.panel.raiderIOTimestamp:SetText(ns.L.SETTINGS_RAIDERIO_TIMESTAMP_FORMAT:format(metadata.timestampText))
end

function SettingsPanel:RefreshAstralKeysMetadata()
    if not self.panel or not self.panel.astralKeysStatus then
        return
    end

    local metadata = ns.AstralKeys and ns.AstralKeys:GetMetadata() or {
        status = "missing",
        versionText = ns.L.UNKNOWN,
        entryCount = 0
    }
    local statusLabel = metadata.status == "detected"
        and ns.L.SETTINGS_ASTRALKEYS_DETECTED
        or ns.L.SETTINGS_ASTRALKEYS_NOT_DETECTED

    self.panel.astralKeysStatus:SetText(ns.L.SETTINGS_ASTRALKEYS_STATUS_FORMAT:format(statusLabel))
    self.panel.astralKeysVersion:SetText(ns.L.SETTINGS_ASTRALKEYS_VERSION_FORMAT:format(metadata.versionText or ns.L.UNKNOWN))
    self.panel.astralKeysEntries:SetText(ns.L.SETTINGS_ASTRALKEYS_ENTRIES_FORMAT:format(metadata.entryCount or 0))
end

function SettingsPanel:RefreshGuildSyncMetadata()
    if not self.panel or not self.panel.guildSyncSessionReporters then
        return
    end

    local channelEnabled = ns.Config:Get("enableGuildSyncChannel")
    local reporterCount = channelEnabled
        and ns.Comm
        and type(ns.Comm.GetSessionReporterCount) == "function"
        and ns.Comm:GetSessionReporterCount()
        or 0

    self.panel.guildSyncSessionReporters:SetText(
        ns.L.SETTINGS_GUILD_SYNC_SESSION_REPORTERS_FORMAT:format(reporterCount or 0)
    )

    if channelEnabled then
        self.panel.guildSyncSessionReporters:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    else
        self.panel.guildSyncSessionReporters:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end
end

function SettingsPanel:RefreshControls()
    if not self.panel then
        return
    end

    local channelEnabled = ns.Config:Get("enableGuildSyncChannel")
    if self.panel.groupByRoleToggle then
        self.panel.groupByRoleToggle:SetChecked(ns.Config:Get("groupByRole"))
    end
    if self.panel.completedRunsToggle then
        self.panel.completedRunsToggle:SetChecked(ns.Config:Get("includeCompletedRuns"))
    end
    if self.panel.guildSyncMaster then
        self.panel.guildSyncMaster:SetChecked(channelEnabled)
    end
    if self.panel.newerWarningToggle then
        self.panel.newerWarningToggle:SetChecked(ns.Config:Get("showNewerRaiderIOWarning"))
    end
    if self.panel.liveActivityToggle then
        self.panel.liveActivityToggle:SetChecked(ns.Config:Get("showLiveKeyActivity"))
    end

    SetCheckboxEnabled(self.panel.newerWarningToggle, channelEnabled)
    SetCheckboxEnabled(self.panel.liveActivityToggle, channelEnabled)
    if self.panel.guildSyncDisabled then
        self.panel.guildSyncDisabled:SetShown(not channelEnabled)
    end
end

function SettingsPanel:RefreshAll()
    self:RefreshControls()
    self:RefreshGuildSyncMetadata()
    self:RefreshRaiderIOMetadata()
    self:RefreshAstralKeysMetadata()
end

function SettingsPanel:Open()
    if not self.panel then
        self:Create()
    end

    if not self.categoryID then
        return
    end

    self:RefreshAll()
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

    panel.panelHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.panelHeader:SetPoint("TOPLEFT", panel.description, "BOTTOMLEFT", 0, -20)
    panel.panelHeader:SetText(ns.L.SETTINGS_PANEL_HEADER)

    panel.panelDescription = CreateWrappedText(panel, "GameFontHighlightSmall", panel.panelHeader, -10)
    panel.panelDescription:SetText(ns.L.SETTINGS_PANEL_DESCRIPTION)

    panel.groupByRoleToggle = CreateCheckbox(
        panel,
        panel.panelDescription,
        -12,
        ns.L.SETTING_GROUP_BY_ROLE,
        "groupByRole"
    )

    panel.completedRunsToggle = CreateCheckbox(
        panel,
        panel.groupByRoleToggle,
        -8,
        ns.L.SETTING_INCLUDE_COMPLETED_RUNS,
        "includeCompletedRuns"
    )

    panel.guildSyncHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.guildSyncHeader:SetPoint("TOPLEFT", panel.completedRunsToggle, "BOTTOMLEFT", 0, -20)
    panel.guildSyncHeader:SetText(ns.L.SETTINGS_GUILD_SYNC_HEADER)

    panel.guildSyncDescription = CreateWrappedText(panel, "GameFontHighlightSmall", panel.guildSyncHeader, -10)
    panel.guildSyncDescription:SetText(ns.L.SETTINGS_GUILD_SYNC_DESCRIPTION)

    panel.guildSyncMaster = CreateCheckbox(
        panel,
        panel.guildSyncDescription,
        -12,
        ns.L.SETTING_ENABLE_GUILD_SYNC_CHANNEL,
        "enableGuildSyncChannel"
    )

    panel.newerWarningToggle = CreateCheckbox(
        panel,
        panel.guildSyncMaster,
        -8,
        ns.L.SETTING_SHOW_NEWER_RAIDERIO_WARNING,
        "showNewerRaiderIOWarning"
    )

    panel.liveActivityToggle = CreateCheckbox(
        panel,
        panel.newerWarningToggle,
        -8,
        ns.L.SETTING_SHOW_LIVE_KEY_ACTIVITY,
        "showLiveKeyActivity"
    )

    panel.guildSyncSessionReporters = CreateWrappedText(panel, "GameFontHighlightSmall", panel.liveActivityToggle, -8)

    panel.guildSyncDisabled = CreateWrappedText(panel, "GameFontDisableSmall", panel.guildSyncSessionReporters, -6)
    panel.guildSyncDisabled:SetText(ns.L.SETTINGS_GUILD_SYNC_DISABLED)

    panel.raiderIOHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.raiderIOHeader:SetPoint("TOPLEFT", panel.guildSyncDisabled, "BOTTOMLEFT", 0, -20)
    panel.raiderIOHeader:SetText(ns.L.SETTINGS_RAIDERIO_HEADER)

    panel.raiderIOStatus = CreateWrappedText(panel, "GameFontHighlightSmall", panel.raiderIOHeader, -10)
    panel.raiderIORegions = CreateWrappedText(panel, "GameFontHighlightSmall", panel.raiderIOStatus, -8)
    panel.raiderIOVersion = CreateWrappedText(panel, "GameFontHighlightSmall", panel.raiderIORegions, -8)
    panel.raiderIOTimestamp = CreateWrappedText(panel, "GameFontHighlightSmall", panel.raiderIOVersion, -8)

    panel.astralKeysHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.astralKeysHeader:SetPoint("TOPLEFT", panel.raiderIOTimestamp, "BOTTOMLEFT", 0, -20)
    panel.astralKeysHeader:SetText(ns.L.SETTINGS_ASTRALKEYS_HEADER)

    panel.astralKeysStatus = CreateWrappedText(panel, "GameFontHighlightSmall", panel.astralKeysHeader, -10)
    panel.astralKeysVersion = CreateWrappedText(panel, "GameFontHighlightSmall", panel.astralKeysStatus, -8)
    panel.astralKeysEntries = CreateWrappedText(panel, "GameFontHighlightSmall", panel.astralKeysVersion, -8)

    panel:SetScript("OnShow", function()
        SettingsPanel:RefreshAll()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.L.ADDON_TITLE, ns.L.ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
    self.categoryID = category.ID

    self:RefreshAll()
end

ns:RegisterCallback("PLAYER_LOGIN", function()
    SettingsPanel:Create()
end)

ns:RegisterCallback("CONFIG_CHANGED", function()
    SettingsPanel:RefreshAll()
end)

ns:RegisterCallback("COMM_SNAPSHOT_UPDATED", function()
    SettingsPanel:RefreshGuildSyncMetadata()
end)

ns:RegisterEvent("ADDON_LOADED", function(name)
    if name == "RaiderIO" or (type(name) == "string" and name:match("^RaiderIO_DB_")) then
        SettingsPanel:RefreshRaiderIOMetadata()
    elseif name == "AstralKeys" then
        SettingsPanel:RefreshAstralKeysMetadata()
    end
end)
