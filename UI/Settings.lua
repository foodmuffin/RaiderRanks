local _, ns = ...

local SettingsPanel = {
    categoryID = nil
}

ns.Settings = SettingsPanel

local settingsScrollBarInset = 6
local settingsScrollBarGap = 6

local function CreateWrappedText(parent, template, anchor, offsetY, offsetX, width)
    local fontString = parent:CreateFontString(nil, "ARTWORK", template)
    fontString:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX or 0, offsetY)
    fontString:SetWidth(width or 620)
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

function SettingsPanel:UpdateScrollBounds()
    local panel = self.panel
    if not panel
        or not panel:IsShown()
        or not panel.scrollBox
        or not panel.scrollContent
        or not panel.scrollContentBottom then
        return
    end

    local contentTop = panel.scrollContent:GetTop()
    local contentBottom = panel.scrollContentBottom:GetBottom()
    if not contentTop or not contentBottom then
        return
    end

    local contentHeight = math.max(1, math.ceil(contentTop - contentBottom))
    local scrollBoxWidth = panel.scrollBox:GetWidth() or 0
    panel.scrollContent:SetHeight(contentHeight)
    if scrollBoxWidth > 0 then
        panel.scrollContent:SetWidth(math.max(1, scrollBoxWidth - 18))
    end

    if panel.scrollBox.FullUpdate then
        panel.scrollBox:FullUpdate(true)
    end
end

function SettingsPanel:QueueScrollUpdate()
    if self.scrollUpdateQueued then
        return
    end

    self.scrollUpdateQueued = true
    C_Timer.After(0, function()
        SettingsPanel.scrollUpdateQueued = false
        SettingsPanel:UpdateScrollBounds()
    end)
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
    self:QueueScrollUpdate()
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
    panel.scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBox")
    panel.scrollBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    panel.scrollBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)

    panel.scrollBar = CreateFrame("EventFrame", nil, panel.scrollBox, "MinimalScrollBar")
    panel.scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -settingsScrollBarInset, -16)
    panel.scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -settingsScrollBarInset, 16)

    panel.scrollBox:SetPoint("TOPRIGHT", panel.scrollBar, "TOPLEFT", -settingsScrollBarGap, 0)
    panel.scrollBox:SetPoint("BOTTOMRIGHT", panel.scrollBar, "BOTTOMLEFT", -settingsScrollBarGap, 0)

    if panel.scrollBox.SetInterpolateScroll then
        panel.scrollBox:SetInterpolateScroll(true)
    end
    if panel.scrollBar.SetInterpolateScroll then
        panel.scrollBar:SetInterpolateScroll(true)
    end
    if panel.scrollBar.SetHideIfUnscrollable then
        panel.scrollBar:SetHideIfUnscrollable(true)
    end

    panel.scrollContent = CreateFrame("Frame", nil, panel.scrollBox)
    panel.scrollContent:SetPoint("TOPLEFT", panel.scrollBox, "TOPLEFT", 0, 0)
    panel.scrollContent:SetPoint("TOPRIGHT", panel.scrollBox, "TOPRIGHT", 0, 0)
    panel.scrollContent:SetHeight(1)
    panel.scrollContent.scrollable = true

    local view = CreateScrollBoxLinearView()
    if view.SetPanExtent then
        view:SetPanExtent(60)
    end
    ScrollUtil.InitScrollBoxWithScrollBar(panel.scrollBox, panel.scrollBar, view)

    local content = panel.scrollContent

    panel.title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 0, 0)
    panel.title:SetText(ns.L.SETTINGS_HEADER)

    panel.version = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.version:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -12)
    panel.version:SetText(("%s: %s"):format(VERSION or "Version", ns.version))

    panel.description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.description:SetPoint("TOPLEFT", panel.version, "BOTTOMLEFT", 0, -12)
    panel.description:SetWidth(620)
    panel.description:SetJustifyH("LEFT")
    panel.description:SetJustifyV("TOP")
    panel.description:SetWordWrap(true)
    panel.description:SetText(ns.L.ADDON_DESCRIPTION)

    panel.panelHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.panelHeader:SetPoint("TOPLEFT", panel.description, "BOTTOMLEFT", 0, -20)
    panel.panelHeader:SetText(ns.L.SETTINGS_PANEL_HEADER)

    panel.panelDescription = CreateWrappedText(content, "GameFontHighlightSmall", panel.panelHeader, -10)
    panel.panelDescription:SetText(ns.L.SETTINGS_PANEL_DESCRIPTION)

    panel.groupByRoleToggle = CreateCheckbox(
        content,
        panel.panelDescription,
        -12,
        ns.L.SETTING_GROUP_BY_ROLE,
        "groupByRole"
    )

    panel.completedRunsToggle = CreateCheckbox(
        content,
        panel.groupByRoleToggle,
        -8,
        ns.L.SETTING_INCLUDE_COMPLETED_RUNS,
        "includeCompletedRuns"
    )

    panel.completedRunsDescription = CreateWrappedText(
        content,
        "GameFontHighlightSmall",
        panel.completedRunsToggle,
        -2,
        30,
        590
    )
    panel.completedRunsDescription:SetText(ns.L.SETTING_INCLUDE_COMPLETED_RUNS_DESCRIPTION)

    panel.guildSyncHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.guildSyncHeader:SetPoint("TOPLEFT", panel.completedRunsDescription, "BOTTOMLEFT", -30, -20)
    panel.guildSyncHeader:SetText(ns.L.SETTINGS_GUILD_SYNC_HEADER)

    panel.guildSyncDescription = CreateWrappedText(content, "GameFontHighlightSmall", panel.guildSyncHeader, -10)
    panel.guildSyncDescription:SetText(ns.L.SETTINGS_GUILD_SYNC_DESCRIPTION)

    panel.guildSyncMaster = CreateCheckbox(
        content,
        panel.guildSyncDescription,
        -12,
        ns.L.SETTING_ENABLE_GUILD_SYNC_CHANNEL,
        "enableGuildSyncChannel"
    )

    panel.newerWarningToggle = CreateCheckbox(
        content,
        panel.guildSyncMaster,
        -8,
        ns.L.SETTING_SHOW_NEWER_RAIDERIO_WARNING,
        "showNewerRaiderIOWarning"
    )

    panel.liveActivityToggle = CreateCheckbox(
        content,
        panel.newerWarningToggle,
        -8,
        ns.L.SETTING_SHOW_LIVE_KEY_ACTIVITY,
        "showLiveKeyActivity"
    )

    panel.guildSyncSessionReporters = CreateWrappedText(content, "GameFontHighlightSmall", panel.liveActivityToggle, -8)

    panel.guildSyncDisabled = CreateWrappedText(content, "GameFontDisableSmall", panel.guildSyncSessionReporters, -6)
    panel.guildSyncDisabled:SetText(ns.L.SETTINGS_GUILD_SYNC_DISABLED)

    panel.raiderIOHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.raiderIOHeader:SetPoint("TOPLEFT", panel.guildSyncDisabled, "BOTTOMLEFT", 0, -20)
    panel.raiderIOHeader:SetText(ns.L.SETTINGS_RAIDERIO_HEADER)

    panel.raiderIOStatus = CreateWrappedText(content, "GameFontHighlightSmall", panel.raiderIOHeader, -10)
    panel.raiderIORegions = CreateWrappedText(content, "GameFontHighlightSmall", panel.raiderIOStatus, -8)
    panel.raiderIOVersion = CreateWrappedText(content, "GameFontHighlightSmall", panel.raiderIORegions, -8)
    panel.raiderIOTimestamp = CreateWrappedText(content, "GameFontHighlightSmall", panel.raiderIOVersion, -8)

    panel.astralKeysHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    panel.astralKeysHeader:SetPoint("TOPLEFT", panel.raiderIOTimestamp, "BOTTOMLEFT", 0, -20)
    panel.astralKeysHeader:SetText(ns.L.SETTINGS_ASTRALKEYS_HEADER)

    panel.astralKeysStatus = CreateWrappedText(content, "GameFontHighlightSmall", panel.astralKeysHeader, -10)
    panel.astralKeysVersion = CreateWrappedText(content, "GameFontHighlightSmall", panel.astralKeysStatus, -8)
    panel.astralKeysEntries = CreateWrappedText(content, "GameFontHighlightSmall", panel.astralKeysVersion, -8)

    panel.scrollContentBottom = CreateFrame("Frame", nil, content)
    panel.scrollContentBottom:SetSize(1, 1)
    panel.scrollContentBottom:SetPoint("TOPLEFT", panel.astralKeysEntries, "BOTTOMLEFT", 0, -24)

    panel:SetScript("OnShow", function()
        SettingsPanel:RefreshAll()
    end)
    panel:SetScript("OnSizeChanged", function()
        SettingsPanel:QueueScrollUpdate()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.L.ADDON_TITLE, ns.L.ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
    self.categoryID = category.ID

    self:RefreshAll()
    self:QueueScrollUpdate()
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
