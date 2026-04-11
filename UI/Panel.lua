local addonName, ns = ...

local Panel = {
    rowCount = 13,
    rowHeight = 22,
    displayRows = {},
    selectedFullName = nil,
    guildInlineHooked = false,
    friendsInlineHooked = false,
    addonCompartmentRegistered = false,
    baseTabCount = nil,
    tabID = nil
}

ns.Panel = Panel

local friendButtonPrefixes = {
    "FriendsFrameFriendsScrollFrameButton",
    "FriendsListFrameScrollFrameButton",
    "FriendsFrameFriendsButton",
    "FriendsListButton"
}

local pveAddonNames = {
    "Blizzard_GroupFinder",
    "Blizzard_ChallengesUI",
    "Blizzard_PVE",
    "Blizzard_PVEUI"
}

local framesToHideOnSelect = {
    "GroupFinderFrame",
    "ChallengesFrame",
    "DungeonFinderFrame",
    "RaidFinderFrame",
    "ScenarioFinderFrame"
}

local expandedPVEFrame = {
    width = 1360,
    height = 840,
    paddingX = 80,
    paddingY = 120
}

local tabTemplates = {
    "CharacterFrameTabTemplate",
    "CharacterFrameTabButtonTemplate",
    "PanelTopTabButtonTemplate",
    "PanelTabButtonTemplate"
}

local function CreateDivider(parent, topAnchor, topOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, topOffset)
    divider:SetPoint("TOPRIGHT", topAnchor, "BOTTOMRIGHT", 0, topOffset)
    return divider
end

local function CreateInlineText(parent, width, justify, fontObject)
    local text = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormalSmall")
    text:SetWidth(width or 0)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

local function BuildBestRunText(record)
    local dungeonProfile = record and record.sortedDungeons and record.sortedDungeons[1]
    if not dungeonProfile then
        return "-"
    end

    local dungeon = dungeonProfile.dungeon
    local name = dungeon and (dungeon.shortNameLocale or dungeon.shortName or dungeon.name) or DUNGEONS
    return ("%s %d"):format(name, dungeonProfile.level or 0)
end

local function BuildProfileStateLabel(record)
    local L = ns.L
    if record.profileState == "ready" then
        return L.READY
    elseif record.profileState == "stale" then
        return L.STALE
    elseif record.profileState == "missing_dependency" then
        return L.MISSING_DEPENDENCY
    end

    return L.UNSCORED
end

local function GetSourceLabel(record)
    local L = ns.L
    if record.source == "guild_friend" then
        return L.SOURCE_GUILD_FRIEND
    elseif record.source == "guild" then
        return L.SOURCE_GUILD
    elseif record.source == "friend" then
        return L.SOURCE_FRIEND
    end

    return L.UNKNOWN
end

local function ApplyScoreColor(fontString, score)
    if not fontString then
        return
    end

    local color = ns:GetScoreColor(score or 0)
    fontString:SetTextColor(color:GetRGB())
end

local function GetPVEContentAnchor()
    if _G.ChallengesFrame then
        return _G.ChallengesFrame
    end

    if _G.GroupFinderFrame then
        return _G.GroupFinderFrame
    end

    return _G.PVEFrame
end

local function HideTexture(texture)
    if texture then
        texture:SetTexture(nil)
        texture:Hide()
    end
end

local function CreateNativeTabButton(name, parent)
    for index = 1, #tabTemplates do
        local template = tabTemplates[index]
        local ok, frame = pcall(CreateFrame, "Button", name, parent, template)
        if ok and frame then
            frame.RaiderRanksTemplate = template
            return frame
        end
    end

    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetHeight(24)
    button.RaiderRanksTemplate = "UIPanelButtonTemplate"
    return button
end

function Panel:GetFilters()
    return {
        sourceFilter = ns.Config:Get("sourceFilter"),
        showOffline = ns.Config:Get("showOffline"),
        showUnscored = ns.Config:Get("showUnscored"),
        specFilter = ns.Config:Get("specFilter"),
        groupByRole = ns.Config:Get("groupByRole")
    }
end

function Panel:SetSourceFilter(sourceFilter)
    ns.Config:Set("sourceFilter", sourceFilter)
end

function Panel:EnsurePVEFrameLoaded()
    if PVEFrame then
        return true
    end

    if type(PVEFrame_LoadUI) == "function" then
        pcall(PVEFrame_LoadUI)
    end

    if not PVEFrame and type(UIParentLoadAddOn) == "function" then
        for index = 1, #pveAddonNames do
            pcall(UIParentLoadAddOn, pveAddonNames[index])
            if PVEFrame then
                break
            end
        end
    end

    if not PVEFrame and C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        for index = 1, #pveAddonNames do
            pcall(C_AddOns.LoadAddOn, pveAddonNames[index])
            if PVEFrame then
                break
            end
        end
    end

    return PVEFrame ~= nil
end

function Panel:ShowPVEFrame()
    if not self:EnsurePVEFrameLoaded() then
        return false
    end

    if type(PVEFrame_ShowFrame) == "function" then
        pcall(PVEFrame_ShowFrame, "ChallengesFrame")
    elseif type(PVEFrame_ToggleFrame) == "function" then
        if not PVEFrame:IsShown() then
            pcall(PVEFrame_ToggleFrame, "ChallengesFrame")
        end
    elseif type(ShowUIPanel) == "function" then
        ShowUIPanel(PVEFrame)
    else
        PVEFrame:Show()
    end

    return true
end

function Panel:Toggle()
    if PVEFrame and PVEFrame:IsShown() and self.frame and self.frame:IsShown() then
        if type(HideUIPanel) == "function" then
            HideUIPanel(PVEFrame)
        else
            PVEFrame:Hide()
        end
        return
    end

    self:Open()
end

function Panel:Open()
    if not self:ShowPVEFrame() then
        return
    end

    C_Timer.After(0, function()
        if Panel:EnsureCreated() then
            Panel:SelectIntegratedTab()
        end
    end)
end

function Panel:EnsureSelected()
    if self.selectedFullName then
        for index = 1, #self.displayRows do
            local row = self.displayRows[index]
            if not row.isHeader and row.fullName == self.selectedFullName then
                return
            end
        end
    end

    for index = 1, #self.displayRows do
        local row = self.displayRows[index]
        if not row.isHeader then
            self.selectedFullName = row.fullName
            return
        end
    end

    self.selectedFullName = nil
end

function Panel:CreateSourceButton(parent, label, sourceFilter)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText(label)
    button:SetWidth(math.max(84, button:GetTextWidth() + 24))
    button:SetHeight(22)
    button:SetScript("OnClick", function()
        Panel:SetSourceFilter(sourceFilter)
    end)
    button.sourceFilter = sourceFilter
    return button
end

function Panel:CreateCheckButton(parent, label, tooltip, getter, setter)
    local button = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    button.Text:SetText(label)
    button.tooltipText = tooltip
    button:SetScript("OnClick", function(self)
        setter(self:GetChecked())
    end)
    button.GetCheckedState = getter
    return button
end

function Panel:EnsureSpecDropdown()
    if not self.frame or not self.frame.specLabel then
        return nil
    end

    if self.frame.specDropdown then
        return self.frame.specDropdown
    end

    local dropdown = _G[addonName .. "SpecDropdown"]
    if not dropdown then
        dropdown = CreateFrame("Frame", addonName .. "SpecDropdown", self.frame, "UIDropDownMenuTemplate")
    end

    if dropdown then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("LEFT", self.frame.specLabel, "RIGHT", -8, -2)
        self.frame.specDropdown = dropdown
    end

    return dropdown
end

function Panel:SetSpecDropdownText(text)
    local dropdown = self:EnsureSpecDropdown()
    if not dropdown then
        return
    end

    local textRegion = dropdown.Text or _G[dropdown:GetName() .. "Text"]
    if textRegion and textRegion.SetText then
        textRegion:SetText(text or "")
    elseif UIDropDownMenu_SetText then
        pcall(UIDropDownMenu_SetText, dropdown, text or "")
    end
end

function Panel:BuildSpecDropdown()
    local dropdown = self:EnsureSpecDropdown()
    if not dropdown or not UIDropDownMenu_Initialize then
        return
    end

    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 150)
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local info = UIDropDownMenu_CreateInfo()
        info.text = ns.L.ALL_SPECS
        info.value = "all"
        info.checked = ns.Config:Get("specFilter") == "all"
        info.func = function()
            ns.Config:Set("specFilter", "all")
        end
        UIDropDownMenu_AddButton(info, level)

        local options = ns.Data:GetSpecOptions()
        for index = 1, #options do
            local specInfo = options[index]
            info = UIDropDownMenu_CreateInfo()
            info.text = specInfo.specName
            info.value = specInfo.specID
            info.checked = tonumber(ns.Config:Get("specFilter")) == tonumber(specInfo.specID)
            info.func = function()
                ns.Config:Set("specFilter", specInfo.specID)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function Panel:CreateHeader(frame)
    frame.description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.description:SetPoint("TOPLEFT", 12, -12)
    frame.description:SetJustifyH("LEFT")
    frame.description:SetWidth(620)

    frame.allButton = self:CreateSourceButton(frame, ns.L.ALL, "all")
    frame.allButton:SetPoint("TOPLEFT", frame.description, "BOTTOMLEFT", 0, -10)

    frame.guildButton = self:CreateSourceButton(frame, ns.L.GUILD_ONLY, "guild")
    frame.guildButton:SetPoint("LEFT", frame.allButton, "RIGHT", 8, 0)

    frame.friendsButton = self:CreateSourceButton(frame, ns.L.FRIENDS_ONLY, "friends")
    frame.friendsButton:SetPoint("LEFT", frame.guildButton, "RIGHT", 8, 0)

    frame.onlineOnly = self:CreateCheckButton(
        frame,
        ns.L.ONLINE_ONLY,
        nil,
        function()
            return not ns.Config:Get("showOffline")
        end,
        function(value)
            ns.Config:Set("showOffline", not value)
        end
    )
    frame.onlineOnly:SetPoint("LEFT", frame.friendsButton, "RIGHT", 12, 0)

    frame.showUnscored = self:CreateCheckButton(
        frame,
        ns.L.SHOW_UNSCORED,
        nil,
        function()
            return ns.Config:Get("showUnscored")
        end,
        function(value)
            ns.Config:Set("showUnscored", value)
        end
    )
    frame.showUnscored:SetPoint("LEFT", frame.onlineOnly, "RIGHT", 6, 0)

    frame.groupByRole = self:CreateCheckButton(
        frame,
        ns.L.GROUP_BY_ROLE,
        nil,
        function()
            return ns.Config:Get("groupByRole")
        end,
        function(value)
            ns.Config:Set("groupByRole", value)
        end
    )
    frame.groupByRole:SetPoint("LEFT", frame.showUnscored, "RIGHT", 6, 0)

    frame.specLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.specLabel:SetPoint("TOPLEFT", frame.allButton, "BOTTOMLEFT", 0, -14)
    frame.specLabel:SetText(ns.L.SPEC_FILTER)

    frame.specDropdown = self:EnsureSpecDropdown()

    frame.settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.settingsButton:SetText(ns.L.OPEN_SETTINGS)
    frame.settingsButton:SetWidth(math.max(96, frame.settingsButton:GetTextWidth() + 24))
    frame.settingsButton:SetHeight(22)
    frame.settingsButton:SetPoint("TOPRIGHT", -12, -34)
    frame.settingsButton:SetScript("OnClick", function()
        if ns.Settings then
            ns.Settings:Open()
        end
    end)
end

function Panel:CreateHelper(frame)
    frame.helper = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.helper:SetPoint("TOPLEFT", 0, -92)
    frame.helper:SetHeight(118)

    frame.helper.title = frame.helper:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.helper.title:SetPoint("TOPLEFT", 12, -10)
    frame.helper.title:SetText(ns.L.CURRENT_KEY)

    frame.helper.status = frame.helper:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.helper.status:SetPoint("TOPLEFT", frame.helper.title, "BOTTOMLEFT", 0, -8)
    frame.helper.status:SetJustifyH("LEFT")

    frame.helper.counts = frame.helper:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.helper.counts:SetPoint("TOPLEFT", frame.helper.status, "BOTTOMLEFT", 0, -8)
    frame.helper.counts:SetJustifyH("LEFT")

    frame.helper.matchesLabel = frame.helper:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.helper.matchesLabel:SetPoint("TOPLEFT", frame.helper.counts, "BOTTOMLEFT", 0, -8)
    frame.helper.matchesLabel:SetText(ns.L.TOP_MATCHES)

    frame.helper.matches = frame.helper:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.helper.matches:SetPoint("TOPLEFT", frame.helper.matchesLabel, "BOTTOMLEFT", 0, -2)
    frame.helper.matches:SetJustifyH("LEFT")

    frame.helper.roles = {}
    local previous = frame.helper.matches
    for index = 1, 4 do
        local roleText = frame.helper:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        roleText:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, index == 1 and -8 or -2)
        roleText:SetJustifyH("LEFT")
        frame.helper.roles[index] = roleText
        previous = roleText
    end
end

function Panel:CreateList(frame)
    frame.list = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.list:SetPoint("TOPLEFT", frame.helper, "BOTTOMLEFT", 0, -10)
    frame.list:SetPoint("BOTTOMLEFT", 0, 0)

    frame.list.header = CreateFrame("Frame", nil, frame.list)
    frame.list.header:SetPoint("TOPLEFT", 8, -8)
    frame.list.header:SetPoint("TOPRIGHT", -28, -8)
    frame.list.header:SetHeight(18)

    local headerColumns = {
        { key = "rank", text = ns.L.RANK, width = 24, x = 0 },
        { key = "name", text = ns.L.NAME, width = 140, x = 30 },
        { key = "role", text = ns.L.ROLE, width = 46, x = 174 },
        { key = "spec", text = ns.L.SPEC, width = 84, x = 226 },
        { key = "score", text = ns.L.SCORE, width = 48, x = 314 },
        { key = "ilvl", text = ns.L.ITEM_LEVEL, width = 42, x = 368 },
        { key = "best", text = ns.L.BEST, width = 78, x = 416 },
        { key = "timed20", text = ns.L.TIMED_20, width = 30, x = 500 },
        { key = "timed15", text = ns.L.TIMED_15, width = 30, x = 534 }
    }

    for index = 1, #headerColumns do
        local info = headerColumns[index]
        local fontString = frame.list.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fontString:SetPoint("LEFT", info.x, 0)
        fontString:SetWidth(info.width)
        fontString:SetJustifyH("LEFT")
        fontString:SetText(info.text)
        frame.list.header[info.key] = fontString
    end

    CreateDivider(frame.list, frame.list.header, -2)

    frame.list.emptyText = frame.list:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.list.emptyText:SetPoint("CENTER", 0, -10)
    frame.list.emptyText:SetText(ns.L.NO_DATA)
    frame.list.emptyText:Hide()

    frame.scrollFrame = CreateFrame("ScrollFrame", addonName .. "PanelScrollFrame", frame.list, "FauxScrollFrameTemplate")
    frame.scrollFrame:SetPoint("TOPLEFT", frame.list.header, "BOTTOMLEFT", -2, -2)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -24, 8)
    frame.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, Panel.rowHeight, function()
            Panel:RefreshRows()
        end)
    end)

    frame.rows = {}
    for index = 1, self.rowCount do
        local row = CreateFrame("Button", nil, frame.list)
        row:SetPoint("TOPLEFT", frame.list.header, "BOTTOMLEFT", 0, -4 - ((index - 1) * self.rowHeight))
        row:SetPoint("RIGHT", frame.list, "RIGHT", -28, 0)
        row:SetHeight(self.rowHeight)
        row:RegisterForClicks("LeftButtonUp")
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:SetScript("OnClick", function(self)
            if not self.data or self.data.isHeader then
                return
            end
            Panel.selectedFullName = self.data.fullName
            Panel:RefreshRows()
            Panel:RefreshDetail()
        end)
        row:SetScript("OnEnter", function(self)
            if not self.data or self.data.isHeader then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if not ns:ShowProfileTooltip(GameTooltip, self.data.name, self.data.realm) then
                GameTooltip:SetText(self.data.fullName)
            end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)

        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(0, 0, 0, index % 2 == 0 and 0.05 or 0.12)

        row.selection = row:CreateTexture(nil, "ARTWORK")
        row.selection:SetAllPoints()
        row.selection:SetColorTexture(0.15, 0.35, 0.75, 0.18)
        row.selection:Hide()

        row.rank = CreateInlineText(row, 24, "LEFT")
        row.rank:SetPoint("LEFT", 0, 0)
        row.name = CreateInlineText(row, 140, "LEFT")
        row.name:SetPoint("LEFT", 30, 0)

        row.roleIcon = row:CreateTexture(nil, "ARTWORK")
        row.roleIcon:SetSize(14, 14)
        row.roleIcon:SetPoint("LEFT", 174, 0)
        row.roleText = CreateInlineText(row, 28, "LEFT")
        row.roleText:SetPoint("LEFT", row.roleIcon, "RIGHT", 3, 0)

        row.specIcon = row:CreateTexture(nil, "ARTWORK")
        row.specIcon:SetSize(14, 14)
        row.specIcon:SetPoint("LEFT", 226, 0)
        row.spec = CreateInlineText(row, 68, "LEFT")
        row.spec:SetPoint("LEFT", row.specIcon, "RIGHT", 3, 0)

        row.score = CreateInlineText(row, 48, "LEFT")
        row.score:SetPoint("LEFT", 314, 0)
        row.ilvl = CreateInlineText(row, 42, "LEFT")
        row.ilvl:SetPoint("LEFT", 368, 0)
        row.best = CreateInlineText(row, 78, "LEFT")
        row.best:SetPoint("LEFT", 416, 0)
        row.timed20 = CreateInlineText(row, 30, "LEFT")
        row.timed20:SetPoint("LEFT", 500, 0)
        row.timed15 = CreateInlineText(row, 30, "LEFT")
        row.timed15:SetPoint("LEFT", 534, 0)

        frame.rows[index] = row
    end
end

function Panel:CreateDetail(frame)
    frame.detail = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.detail:SetPoint("TOPRIGHT", 0, -92)
    frame.detail:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.detail:SetWidth(312)

    frame.detail.name = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    frame.detail.name:SetPoint("TOPLEFT", 12, -12)
    frame.detail.name:SetJustifyH("LEFT")
    frame.detail.name:SetWidth(284)

    frame.detail.source = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.detail.source:SetPoint("TOPLEFT", frame.detail.name, "BOTTOMLEFT", 0, -6)
    frame.detail.source:SetJustifyH("LEFT")
    frame.detail.source:SetWidth(284)

    frame.detail.role = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.role:SetPoint("TOPLEFT", frame.detail.source, "BOTTOMLEFT", 0, -10)
    frame.detail.role:SetJustifyH("LEFT")
    frame.detail.role:SetWidth(284)

    frame.detail.specIcon = frame.detail:CreateTexture(nil, "ARTWORK")
    frame.detail.specIcon:SetSize(16, 16)
    frame.detail.specIcon:SetPoint("TOPLEFT", frame.detail.role, "BOTTOMLEFT", 0, -10)

    frame.detail.spec = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.spec:SetPoint("LEFT", frame.detail.specIcon, "RIGHT", 5, 0)
    frame.detail.spec:SetJustifyH("LEFT")
    frame.detail.spec:SetWidth(262)

    frame.detail.score = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.score:SetPoint("TOPLEFT", frame.detail.spec, "BOTTOMLEFT", -21, -10)
    frame.detail.score:SetJustifyH("LEFT")
    frame.detail.score:SetWidth(284)

    frame.detail.mainScore = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.detail.mainScore:SetPoint("TOPLEFT", frame.detail.score, "BOTTOMLEFT", 0, -6)
    frame.detail.mainScore:SetJustifyH("LEFT")
    frame.detail.mainScore:SetWidth(284)

    frame.detail.itemLevel = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.itemLevel:SetPoint("TOPLEFT", frame.detail.mainScore, "BOTTOMLEFT", 0, -8)
    frame.detail.itemLevel:SetJustifyH("LEFT")
    frame.detail.itemLevel:SetWidth(284)

    frame.detail.profileState = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.profileState:SetPoint("TOPLEFT", frame.detail.itemLevel, "BOTTOMLEFT", 0, -8)
    frame.detail.profileState:SetJustifyH("LEFT")
    frame.detail.profileState:SetWidth(284)

    frame.detail.bestRun = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.bestRun:SetPoint("TOPLEFT", frame.detail.profileState, "BOTTOMLEFT", 0, -8)
    frame.detail.bestRun:SetJustifyH("LEFT")
    frame.detail.bestRun:SetWidth(284)

    frame.detail.timedRuns = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.detail.timedRuns:SetPoint("TOPLEFT", frame.detail.bestRun, "BOTTOMLEFT", 0, -8)
    frame.detail.timedRuns:SetJustifyH("LEFT")
    frame.detail.timedRuns:SetWidth(284)

    frame.detail.raidHeader = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.detail.raidHeader:SetPoint("TOPLEFT", frame.detail.timedRuns, "BOTTOMLEFT", 0, -12)
    frame.detail.raidHeader:SetText(ns.L.DETAIL_RAID_CONTEXT)

    frame.detail.raidRows = {}
    local previous = frame.detail.raidHeader
    for index = 1, 4 do
        local row = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, index == 1 and -4 or -2)
        row:SetJustifyH("LEFT")
        row:SetWidth(284)
        frame.detail.raidRows[index] = row
        previous = row
    end

    frame.detail.dungeonHeader = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.detail.dungeonHeader:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
    frame.detail.dungeonHeader:SetText(ns.L.DETAIL_DUNGEONS)

    frame.detail.dungeonRows = {}
    previous = frame.detail.dungeonHeader
    for index = 1, 8 do
        local row = frame.detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, index == 1 and -4 or -2)
        row:SetJustifyH("LEFT")
        row:SetWidth(284)
        frame.detail.dungeonRows[index] = row
        previous = row
    end
end

function Panel:HookNativeTabs()
    if self.nativeTabsHooked or not PVEFrame or not self.baseTabCount then
        return
    end

    for tabIndex = 1, self.baseTabCount do
        local tab = _G["PVEFrameTab" .. tabIndex]
        if tab and not tab.RaiderRanksHooked then
            tab:HookScript("OnClick", function()
                Panel:HideIntegratedFrame()
            end)
            tab.RaiderRanksHooked = true
        end
    end

    self.nativeTabsHooked = true
end

function Panel:EnsureTab()
    if self.tab and self.tabID then
        if PanelTemplates_SetNumTabs then
            PanelTemplates_SetNumTabs(PVEFrame, self.tabID)
        end
        return true
    end

    if not PVEFrame then
        return false
    end

    local existingTabs = PanelTemplates_GetNumTabs and PanelTemplates_GetNumTabs(PVEFrame) or PVEFrame.numTabs or 0
    self.baseTabCount = existingTabs
    self.tabID = existingTabs + 1

    local tabName = "PVEFrameTab" .. self.tabID
    local tab = _G[tabName] or CreateNativeTabButton(tabName, PVEFrame)
    self.tab = tab
    tab:SetID(self.tabID)
    tab:SetText(ns.L.ADDON_TITLE)
    tab:SetScript("OnClick", function()
        Panel:SelectIntegratedTab()
    end)

    local anchor = _G["PVEFrameTab" .. existingTabs]
    if anchor then
        tab:SetPoint("LEFT", anchor, "RIGHT", -16, 0)
    else
        tab:SetPoint("TOPLEFT", PVEFrame, "BOTTOMLEFT", 12, 2)
    end

    if PanelTemplates_TabResize and tab.RaiderRanksTemplate ~= "UIPanelButtonTemplate" then
        pcall(PanelTemplates_TabResize, tab, 0)
    elseif tab.Text and tab.Text.GetStringWidth then
        tab:SetWidth(math.max(84, tab.Text:GetStringWidth() + 32))
    elseif tab.GetTextWidth then
        tab:SetWidth(math.max(84, tab:GetTextWidth() + 32))
    end

    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(PVEFrame, self.tabID)
    else
        PVEFrame.numTabs = self.tabID
    end

    self:HookNativeTabs()
    return true
end

function Panel:EnsureCreated()
    if self.frame then
        self:EnsureTab()
        return true
    end

    if not self:EnsurePVEFrameLoaded() or not self:EnsureTab() then
        return false
    end

    local anchor = GetPVEContentAnchor()
    local frame = CreateFrame("Frame", addonName .. "IntegratedFrame", PVEFrame)
    self.frame = frame

    if anchor and anchor ~= PVEFrame then
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    else
        frame:SetPoint("TOPLEFT", PVEFrame, "TOPLEFT", 12, -58)
        frame:SetPoint("BOTTOMRIGHT", PVEFrame, "BOTTOMRIGHT", -32, 36)
    end

    frame:SetFrameLevel(PVEFrame:GetFrameLevel() + 5)
    if frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end
    frame:Hide()
    frame:SetScript("OnShow", function()
        Panel:Refresh()
    end)
    frame:SetScript("OnSizeChanged", function()
        Panel:ApplyLayout()
    end)

    self:CreateHeader(frame)
    self:CreateDetail(frame)
    self:CreateHelper(frame)
    self:CreateList(frame)

    self:BuildSpecDropdown()
    self:HookPVEFrame()
    self:ApplyLayout()
    return true
end

function Panel:HookPVEFrame()
    if self.pveHooked or not PVEFrame then
        return
    end

    PVEFrame:HookScript("OnHide", function()
        Panel:HideIntegratedFrame()
    end)

    self.pveHooked = true
end

function Panel:ApplyLayout()
    local frame = self.frame
    if not frame or not frame.detail or not frame.list or not frame.helper then
        return
    end

    local width = math.max(frame:GetWidth(), 900)
    local detailWidth = math.floor(math.max(320, math.min(430, width * 0.32)))
    local topOffset = -92
    local spacing = 12

    frame.detail:ClearAllPoints()
    frame.detail:SetPoint("TOPRIGHT", 0, topOffset)
    frame.detail:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.detail:SetWidth(detailWidth)

    frame.helper:ClearAllPoints()
    frame.helper:SetPoint("TOPLEFT", 0, topOffset)
    frame.helper:SetPoint("TOPRIGHT", frame.detail, "TOPLEFT", -spacing, 0)
    frame.helper:SetHeight(132)

    frame.list:ClearAllPoints()
    if ns.Config:Get("showCurrentKeyHelper") then
        frame.list:SetPoint("TOPLEFT", frame.helper, "BOTTOMLEFT", 0, -10)
        frame.list:SetPoint("TOPRIGHT", frame.helper, "BOTTOMRIGHT", 0, -10)
    else
        frame.list:SetPoint("TOPLEFT", 0, topOffset)
        frame.list:SetPoint("TOPRIGHT", frame.detail, "TOPLEFT", -spacing, topOffset)
    end
    frame.list:SetPoint("BOTTOMLEFT", 0, 0)
    frame.list:SetPoint("BOTTOMRIGHT", frame.detail, "BOTTOMLEFT", -spacing, 0)

    local detailTextWidth = math.max(220, detailWidth - 28)
    frame.detail.name:SetWidth(detailTextWidth)
    frame.detail.source:SetWidth(detailTextWidth)
    frame.detail.role:SetWidth(detailTextWidth)
    frame.detail.spec:SetWidth(math.max(180, detailTextWidth - 22))
    frame.detail.score:SetWidth(detailTextWidth)
    frame.detail.mainScore:SetWidth(detailTextWidth)
    frame.detail.itemLevel:SetWidth(detailTextWidth)
    frame.detail.profileState:SetWidth(detailTextWidth)
    frame.detail.bestRun:SetWidth(detailTextWidth)
    frame.detail.timedRuns:SetWidth(detailTextWidth)

    for index = 1, #frame.detail.raidRows do
        frame.detail.raidRows[index]:SetWidth(detailTextWidth)
    end

    for index = 1, #frame.detail.dungeonRows do
        frame.detail.dungeonRows[index]:SetWidth(detailTextWidth)
    end

    local helperWidth = math.max(200, frame.helper:GetWidth() - 24)
    frame.helper.status:SetWidth(helperWidth)
    frame.helper.counts:SetWidth(helperWidth)
    frame.helper.matches:SetWidth(helperWidth)
    for index = 1, #frame.helper.roles do
        frame.helper.roles[index]:SetWidth(helperWidth)
    end

    local settingsWidth = frame.settingsButton and frame.settingsButton:GetWidth() or 0
    frame.description:ClearAllPoints()
    frame.description:SetPoint("TOPLEFT", 12, -12)
    frame.description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(settingsWidth + 24), -12)
end

function Panel:ExpandPVEFrame()
    if not PVEFrame then
        return
    end

    if not self.originalPVEFrameSize then
        self.originalPVEFrameSize = {
            width = PVEFrame:GetWidth(),
            height = PVEFrame:GetHeight()
        }
    end

    local width = expandedPVEFrame.width
    local height = expandedPVEFrame.height
    if UIParent then
        width = math.min(width, math.max(900, UIParent:GetWidth() - expandedPVEFrame.paddingX))
        height = math.min(height, math.max(650, UIParent:GetHeight() - expandedPVEFrame.paddingY))
    end

    if PVEFrame:GetWidth() ~= width or PVEFrame:GetHeight() ~= height then
        PVEFrame:SetSize(width, height)
    end
end

function Panel:RestorePVEFrame()
    if not PVEFrame or not self.originalPVEFrameSize then
        return
    end

    PVEFrame:SetSize(self.originalPVEFrameSize.width, self.originalPVEFrameSize.height)
end

function Panel:HideIntegratedFrame()
    if self.frame then
        self.frame:Hide()
    end

    self:RestorePVEFrame()
end

function Panel:UpdatePVEFrameTitle()
    if not PVEFrame then
        return
    end

    local titleText = PVEFrame.TitleText
    if not titleText and PVEFrame.TitleContainer then
        titleText = PVEFrame.TitleContainer.TitleText
    end

    if titleText and titleText.SetText then
        titleText:SetText(ns.L.ADDON_TITLE)
    end
end

function Panel:HideBuiltInPVEFrames()
    for index = 1, #framesToHideOnSelect do
        local frame = _G[framesToHideOnSelect[index]]
        if frame and frame:IsShown() then
            frame:Hide()
        end
    end
end

function Panel:SelectIntegratedTab()
    if not self:EnsureCreated() then
        return
    end

    self:ExpandPVEFrame()
    self:HideBuiltInPVEFrames()
    self:UpdatePVEFrameTitle()

    if PanelTemplates_SetTab and self.tabID then
        PanelTemplates_SetTab(PVEFrame, self.tabID)
    elseif self.tabID then
        PVEFrame.selectedTab = self.tabID
    end

    self.frame:Show()
    self:Refresh()
end

function Panel:RefreshHeaderControls()
    local frame = self.frame
    if not frame or not frame.allButton or not frame.onlineOnly then
        return
    end

    frame.description:SetText(ns:IsRaiderIOAvailable() and ns.L.ADDON_DESCRIPTION or ns.L.RAIDERIO_MISSING)

    local sourceFilter = ns.Config:Get("sourceFilter")
    local buttons = { frame.allButton, frame.guildButton, frame.friendsButton }
    for index = 1, #buttons do
        local button = buttons[index]
        if button then
            local selected = button.sourceFilter == sourceFilter
            button:SetEnabled(not selected)
            if selected then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
        end
    end

    frame.onlineOnly:SetChecked(not ns.Config:Get("showOffline"))
    frame.showUnscored:SetChecked(ns.Config:Get("showUnscored"))
    frame.groupByRole:SetChecked(ns.Config:Get("groupByRole"))

    self:SetSpecDropdownText(ns.L.ALL_SPECS)
    local specFilter = ns.Config:Get("specFilter")
    if specFilter ~= "all" then
        local record = ns.Data.specCatalog[tonumber(specFilter)]
        if record then
            self:SetSpecDropdownText(record.specName)
        end
    end
end

function Panel:RefreshHelper()
    local frame = self.frame
    if not frame or not frame.helper then
        return
    end

    local helper = frame.helper
    if not ns.Config:Get("showCurrentKeyHelper") then
        helper:Hide()
        self:ApplyLayout()
        return
    end

    helper:Show()
    self:ApplyLayout()

    local context = ns.Data:GetCurrentKeyContext()
    if not context.mapID or not context.level then
        helper.status:SetText(ns.L.NO_CURRENT_KEY)
        helper.counts:SetText("")
        helper.matches:SetText("")
        for index = 1, #helper.roles do
            helper.roles[index]:SetText("")
        end
        return
    end

    helper.status:SetText(("%s (%d)"):format(context.mapName or ns.L.CURRENT_KEY, context.level))
    helper.counts:SetText(("%s: %d    %s    %s    %s    %s"):format(
        ns.L.QUALIFIED,
        context.qualifiedCount,
        ns.L.HELPER_ROLE_COUNT:format(ns:GetRoleMarkup("tank"), context.qualifiedByRole.tank or 0),
        ns.L.HELPER_ROLE_COUNT:format(ns:GetRoleMarkup("healer"), context.qualifiedByRole.healer or 0),
        ns.L.HELPER_ROLE_COUNT:format(ns:GetRoleMarkup("dps"), context.qualifiedByRole.dps or 0),
        ns.L.HELPER_ROLE_COUNT:format(ns:GetRoleMarkup("unknown"), context.qualifiedByRole.unknown or 0)
    ))

    if context.qualifiedCount == 0 then
        helper.matches:SetText(ns.L.NO_QUALIFIED_MATCHES)
    else
        local names = {}
        for index = 1, math.min(5, #context.qualifiedMembers) do
            local record = context.qualifiedMembers[index]
            names[#names + 1] = ("%s %s"):format(ns:GetRoleMarkup(record.roleBucket), record.name)
        end
        helper.matches:SetText(table.concat(names, ", "))
    end

    local orderedRoles = { "tank", "healer", "dps", "unknown" }
    for index = 1, #orderedRoles do
        local role = orderedRoles[index]
        local best = context.bestByRole[role]
        if best then
            helper.roles[index]:SetText(("%s %s"):format(ns:GetRoleMarkup(role), best.fullName))
        else
            helper.roles[index]:SetText(("%s -"):format(ns:GetRoleMarkup(role)))
        end
    end
end

function Panel:RefreshRows()
    if not self.frame or not self.frame.scrollFrame then
        return
    end

    local totalRows = #self.displayRows
    self.frame.list.emptyText:SetShown(totalRows == 0)
    if totalRows == 0 then
        self.frame.list.emptyText:SetText(ns:IsRaiderIOAvailable() and ns.L.NO_DATA or ns.L.RAIDERIO_MISSING)
    end

    local offset = FauxScrollFrame_GetOffset(self.frame.scrollFrame)
    FauxScrollFrame_Update(self.frame.scrollFrame, totalRows, self.rowCount, self.rowHeight)

    local rank = 0
    for displayIndex = 1, offset do
        local hiddenRow = self.displayRows[displayIndex]
        if hiddenRow and not hiddenRow.isHeader then
            rank = rank + 1
        end
    end

    for rowIndex = 1, self.rowCount do
        local row = self.frame.rows[rowIndex]
        local dataIndex = rowIndex + offset
        local data = self.displayRows[dataIndex]
        row.data = data

        if not data then
            row:Hide()
        else
            row:Show()
            row.selection:SetShown(data.fullName and data.fullName == self.selectedFullName)

            if data.isHeader then
                row.rank:SetText("")
                row.name:SetText(("%s %s"):format(ns:GetRoleMarkup(data.roleBucket), data.label))
                row.name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
                HideTexture(row.roleIcon)
                row.roleText:SetText("")
                HideTexture(row.specIcon)
                row.spec:SetText("")
                row.score:SetText("")
                row.ilvl:SetText("")
                row.best:SetText("")
                row.timed20:SetText("")
                row.timed15:SetText("")
                row.background:SetColorTexture(0.13, 0.13, 0.18, 0.85)
            else
                rank = rank + 1
                row.background:SetColorTexture(0, 0, 0, rowIndex % 2 == 0 and 0.05 or 0.12)
                row.rank:SetText(rank)
                row.name:SetText(data.fullName)
                row.name:SetTextColor(ns:GetClassColor(data.classFile):GetRGB())

                row.roleIcon:SetAtlas(ns:GetRoleAtlas(data.roleBucket), true)
                row.roleIcon:Show()
                row.roleText:SetText(ns:GetRoleLabel(data.roleBucket))

                if data.specIcon then
                    row.specIcon:SetAtlas(nil)
                    row.specIcon:SetTexture(data.specIcon)
                else
                    row.specIcon:SetTexture(nil)
                    row.specIcon:SetAtlas("classhall-icon-noglow", true)
                end
                row.specIcon:Show()
                row.spec:SetText(data.specName or ns.L.UNKNOWN_SPEC)

                row.score:SetText(data.currentScore > 0 and data.currentScore or "-")
                ApplyScoreColor(row.score, data.currentScore)

                if ns.Config:Get("showItemLevel") and data.equippedItemLevel then
                    row.ilvl:SetText(ns.L.ITEM_LEVEL_ROW:format(data.equippedItemLevel))
                else
                    row.ilvl:SetText("-")
                end
                row.ilvl:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())

                row.best:SetText(BuildBestRunText(data))
                row.timed20:SetText(data.timed20 > 0 and data.timed20 or "-")
                row.timed15:SetText(data.timed15 > 0 and data.timed15 or "-")
                row.timed20:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
                row.timed15:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

                ns.Inspect:QueueRecord(data)
            end
        end
    end
end

function Panel:RefreshDetail()
    local frame = self.frame
    if not frame or not frame.detail then
        return
    end

    local detail = frame.detail
    local record = self.selectedFullName and ns.Data:GetRecord(self.selectedFullName)
    if not record then
        detail.name:SetText(ns.L.NO_SELECTION)
        detail.source:SetText("")
        detail.role:SetText("")
        HideTexture(detail.specIcon)
        detail.spec:SetText("")
        detail.score:SetText("")
        detail.mainScore:SetText("")
        detail.itemLevel:SetText("")
        detail.profileState:SetText("")
        detail.bestRun:SetText("")
        detail.timedRuns:SetText("")
        for index = 1, #detail.raidRows do
            detail.raidRows[index]:SetText("")
        end
        for index = 1, #detail.dungeonRows do
            detail.dungeonRows[index]:SetText("")
        end
        return
    end

    detail.name:SetText(record.fullName)
    detail.name:SetTextColor(ns:GetClassColor(record.classFile):GetRGB())
    detail.source:SetText(("%s: %s"):format(ns.L.SOURCE, GetSourceLabel(record)))
    detail.role:SetText(("%s %s (%s)"):format(
        ns:GetRoleMarkup(record.roleBucket),
        ns:GetRoleLabel(record.roleBucket),
        record.roleSource == "group" and ns.L.ROLE_SOURCE_GROUP or record.roleSource == "raiderio" and ns.L.ROLE_SOURCE_RAIDERIO or ns.L.ROLE_SOURCE_UNKNOWN
    ))

    if record.specIcon then
        detail.specIcon:SetAtlas(nil)
        detail.specIcon:SetTexture(record.specIcon)
    else
        detail.specIcon:SetTexture(nil)
        detail.specIcon:SetAtlas("classhall-icon-noglow", true)
    end
    detail.specIcon:Show()

    detail.spec:SetText(("%s (%s)"):format(
        record.specName or ns.L.UNKNOWN_SPEC,
        record.specSource == "self" and ns.L.SPEC_SOURCE_SELF or record.specSource == "inspect" and ns.L.SPEC_SOURCE_INSPECT or ns.L.SPEC_SOURCE_UNKNOWN
    ))

    detail.score:SetText(("%s: %d"):format(ns.L.DETAIL_SCORE, record.currentScore or 0))
    detail.score:SetTextColor(ns:GetScoreColor(record.currentScore):GetRGB())

    if record.mainCurrentScore and record.mainCurrentScore > (record.currentScore or 0) then
        detail.mainScore:SetText(("Main: %d"):format(record.mainCurrentScore))
        detail.mainScore:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    else
        detail.mainScore:SetText("")
    end

    if ns.Config:Get("showItemLevel") then
        local itemLevelText = record.equippedItemLevel and ns.L.ITEM_LEVEL_ROW:format(record.equippedItemLevel) or ns.L.UNKNOWN_ITEM_LEVEL
        detail.itemLevel:SetText(("%s: %s (%s)"):format(
            ns.L.ITEM_LEVEL,
            itemLevelText,
            record.itemLevelSource == "self" and ns.L.SELF_ITEM_LEVEL or record.itemLevelSource == "inspect" and ns.L.INSPECT_ITEM_LEVEL or ns.L.UNKNOWN
        ))
    else
        detail.itemLevel:SetText(("%s: -"):format(ns.L.ITEM_LEVEL))
    end

    detail.profileState:SetText(("%s: %s"):format(ns.L.PROFILE_STATE, BuildProfileStateLabel(record)))
    detail.bestRun:SetText(("%s: %s"):format(ns.L.DETAIL_BEST_RUN, BuildBestRunText(record)))
    detail.timedRuns:SetText(("%s: 20+ %d   15+ %d   10+ %d   5+ %d"):format(
        ns.L.DETAIL_TIMED_RUNS,
        record.timed20 or 0,
        record.timed15 or 0,
        record.timed10 or 0,
        record.timed5 or 0
    ))

    detail.raidHeader:SetShown(ns.Config:Get("showRaidContext"))
    for index = 1, #detail.raidRows do
        local row = detail.raidRows[index]
        local raidInfo = record.raidSummary[index]
        row:SetShown(ns.Config:Get("showRaidContext"))
        if ns.Config:Get("showRaidContext") and raidInfo then
            row:SetText(("%s %s %d/%d"):format(raidInfo.label, raidInfo.shortName, raidInfo.progressCount, raidInfo.bossCount))
        else
            row:SetText("")
        end
    end

    local context = ns.Data:GetCurrentKeyContext()
    for index = 1, #detail.dungeonRows do
        local dungeonInfo = record.sortedDungeons[index]
        local row = detail.dungeonRows[index]
        if dungeonInfo and dungeonInfo.dungeon then
            local dungeon = dungeonInfo.dungeon
            row:SetText(("%s %d"):format(dungeon.shortNameLocale or dungeon.shortName or dungeon.name, dungeonInfo.level or 0))
            local isCurrentKeyDungeon = context.mapID and (
                dungeon.keystone_instance == context.mapID
                or dungeon.id == context.mapID
                or dungeon.instance_map_id == context.mapID
                or dungeon.index == context.mapID
            )
            if isCurrentKeyDungeon and (dungeonInfo.level or 0) >= (context.level or 0) then
                row:SetTextColor(0.35, 1, 0.35)
            else
                row:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            end
        else
            row:SetText("")
        end
    end

    ns.Inspect:QueueRecord(record)
end

function Panel:Refresh()
    if self.frame then
        self:BuildSpecDropdown()
        self:RefreshHeaderControls()
        self:RefreshHelper()
        self.displayRows = ns.Data:GetRecords(self:GetFilters())
        self:EnsureSelected()
        self:RefreshRows()
        self:RefreshDetail()
    end

    self:RefreshInline()
end

function Panel:GetInlineValues(record)
    if not record then
        return "-", "-", nil, nil
    end

    local scoreText = record.currentScore > 0 and tostring(record.currentScore) or "-"
    local itemLevelText = "-"
    if ns.Config:Get("showItemLevel") and record.equippedItemLevel then
        itemLevelText = ns.L.ITEM_LEVEL_ROW:format(record.equippedItemLevel)
    end

    local atlas = nil
    local texture = nil
    if record.specIcon then
        texture = record.specIcon
    else
        atlas = ns:GetRoleAtlas(record.roleBucket)
    end

    return scoreText, itemLevelText, atlas, texture
end

function Panel:SetupInlineWidget(button)
    if button.RaiderRanksInline then
        return button.RaiderRanksInline
    end

    local widget = CreateFrame("Frame", nil, button)
    widget:SetSize(124, 16)
    widget:SetPoint("RIGHT", -8, 0)

    widget.icon = widget:CreateTexture(nil, "OVERLAY")
    widget.icon:SetSize(14, 14)
    widget.icon:SetPoint("RIGHT", 0, 0)

    widget.ilvl = CreateInlineText(widget, 42, "RIGHT")
    widget.ilvl:SetPoint("RIGHT", widget.icon, "LEFT", -4, 0)

    widget.score = CreateInlineText(widget, 56, "RIGHT")
    widget.score:SetPoint("RIGHT", widget.ilvl, "LEFT", -4, 0)

    button.RaiderRanksInline = widget
    return widget
end

function Panel:PopulateInlineWidget(widget, record)
    if not widget then
        return
    end

    local scoreText, itemLevelText, atlas, texture = self:GetInlineValues(record)
    widget.score:SetText(scoreText)
    ApplyScoreColor(widget.score, record and record.currentScore or 0)
    widget.ilvl:SetText(itemLevelText)
    widget.ilvl:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())

    if atlas then
        widget.icon:SetTexture(nil)
        widget.icon:SetAtlas(atlas, true)
    elseif texture then
        widget.icon:SetAtlas(nil)
        widget.icon:SetTexture(texture)
    else
        widget.icon:SetTexture(nil)
        widget.icon:SetAtlas("common-icon-rotateright", true)
    end

    widget:Show()
end

function Panel:UpdateGuildInlineButton(button)
    if not ns.Config:Get("enableGuildInline") then
        if button.RaiderRanksInline then
            button.RaiderRanksInline:Hide()
        end
        return
    end

    local index = button.index or button.guildIndex
    if not index or type(GetGuildRosterInfo) ~= "function" then
        return
    end

    local fullName = GetGuildRosterInfo(index)
    if not fullName then
        return
    end

    local name, realm = ns:SplitNameRealm(fullName, ns.playerRealm)
    local record = ns.Data:GetRecord(ns:ComposeFullName(name, realm))
    local widget = self:SetupInlineWidget(button)
    self:PopulateInlineWidget(widget, record)
    if record then
        ns.Inspect:QueueRecord(record)
    end
end

function Panel:UpdateGuildInline(buttons)
    if not buttons then
        return
    end

    for index = 1, #buttons do
        self:UpdateGuildInlineButton(buttons[index])
    end
end

function Panel:HookGuildInline()
    if self.guildInlineHooked then
        return
    end

    if GuildRosterContainer and ScrollBoxUtil then
        ScrollBoxUtil:OnViewFramesChanged(GuildRosterContainer, function(buttons)
            Panel:UpdateGuildInline(buttons)
        end)
        ScrollBoxUtil:OnViewScrollChanged(GuildRosterContainer, function(scrollBox)
            if scrollBox and scrollBox.GetFrames then
                Panel:UpdateGuildInline(scrollBox:GetFrames())
            end
        end)
        self.guildInlineHooked = true
    end
end

function Panel:GetFriendButtons()
    local buttons = {}
    for prefixIndex = 1, #friendButtonPrefixes do
        local prefix = friendButtonPrefixes[prefixIndex]
        for index = 1, 50 do
            local button = _G[prefix .. index]
            if button then
                buttons[#buttons + 1] = button
            end
        end
    end
    return buttons
end

function Panel:GetFriendRecordFromButton(button)
    if not button or not button.id then
        return nil
    end

    if button.buttonType == FRIENDS_BUTTON_TYPE_WOW and C_FriendList and C_FriendList.GetFriendInfoByIndex then
        local info = C_FriendList.GetFriendInfoByIndex(button.id)
        if info and info.name then
            local name, realm = ns:SplitNameRealm(info.name, ns.playerRealm)
            return ns.Data:GetRecord(ns:ComposeFullName(name, realm))
        end
    elseif button.buttonType == FRIENDS_BUTTON_TYPE_BNET and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local accountInfo = C_BattleNet.GetFriendAccountInfo(button.id)
        local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo
        if gameAccountInfo and gameAccountInfo.characterName and gameAccountInfo.realmName then
            return ns.Data:GetRecord(ns:ComposeFullName(gameAccountInfo.characterName, gameAccountInfo.realmName))
        end
    end

    return nil
end

function Panel:UpdateFriendsInline()
    local buttons = self:GetFriendButtons()
    for index = 1, #buttons do
        local button = buttons[index]
        if not ns.Config:Get("enableFriendsInline") then
            if button.RaiderRanksInline then
                button.RaiderRanksInline:Hide()
            end
        else
            local widget = self:SetupInlineWidget(button)
            local record = self:GetFriendRecordFromButton(button)
            self:PopulateInlineWidget(widget, record)
            if record then
                ns.Inspect:QueueRecord(record)
            end
        end
    end
end

function Panel:HookFriendsInline()
    if self.friendsInlineHooked then
        return
    end

    if type(FriendsFrame_UpdateFriends) == "function" then
        hooksecurefunc("FriendsFrame_UpdateFriends", function()
            Panel:UpdateFriendsInline()
        end)
    end

    if type(FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", function()
            Panel:UpdateFriendsInline()
        end)
    end

    self.friendsInlineHooked = true
end

function Panel:RefreshInline()
    self:HookGuildInline()
    self:HookFriendsInline()

    if GuildRosterContainer and GuildRosterContainer.GetFrames then
        self:UpdateGuildInline(GuildRosterContainer:GetFrames())
    end

    self:UpdateFriendsInline()
end

function Panel:RegisterSlashCommands()
    _G.SLASH_RAIDERRANKS1 = "/raideranks"
    _G.SLASH_RAIDERRANKS2 = "/rranks"
    SlashCmdList.RAIDERRANKS = function(text)
        text = (text or ""):lower()
        if text and text:match("^%s*refresh") then
            ns.Data:Refresh("slash")
        elseif text and text:match("^%s*settings") and ns.Settings then
            ns.Settings:Open()
        else
            Panel:Toggle()
        end
    end
end

function Panel:RegisterAddonCompartment()
    if self.addonCompartmentRegistered or not AddonCompartmentFrame then
        return
    end

    AddonCompartmentFrame:RegisterAddon({
        text = ns.L.ADDON_TITLE,
        icon = C_AddOns.GetAddOnMetadata(addonName, "IconTexture"),
        notCheckable = true,
        registerForAnyClick = true,
        func = function(_, inputData)
            if inputData.buttonName == "RightButton" then
                if ns.Settings then
                    ns.Settings:Open()
                end
            else
                Panel:Open()
            end
        end,
        funcOnEnter = function(menuItem)
            GameTooltip:SetOwner(menuItem, "ANCHOR_RIGHT")
            GameTooltip:SetText(ns.L.ADDON_TITLE)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns.L.COMPARTMENT_TOOLTIP, 1, 1, 1, true)
            GameTooltip:Show()
        end,
        funcOnLeave = function()
            GameTooltip:Hide()
        end
    })

    self.addonCompartmentRegistered = true
end

ns:RegisterCallback("PLAYER_LOGIN", function()
    Panel:RegisterSlashCommands()
    Panel:RegisterAddonCompartment()
    Panel:HookGuildInline()
    Panel:HookFriendsInline()
    C_Timer.After(0, function()
        Panel:EnsureCreated()
    end)
    C_Timer.After(1, function()
        if not Panel.tab then
            Panel:EnsureCreated()
        end
    end)
end)

ns:RegisterCallback("DATA_UPDATED", function()
    Panel:Refresh()
end)

ns:RegisterCallback("CONFIG_CHANGED", function()
    Panel:Refresh()
end)

ns:RegisterEvent("ADDON_LOADED", function(name)
    if name == "Blizzard_GuildUI" or name == "Blizzard_FriendsFrame" then
        C_Timer.After(0, function()
            Panel:RefreshInline()
        end)
    end

    for index = 1, #pveAddonNames do
        if name == pveAddonNames[index] and not Panel.frame then
            C_Timer.After(0, function()
                Panel:EnsureCreated()
            end)
            break
        end
    end
end)
