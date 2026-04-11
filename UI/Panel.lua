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

local rankIcons = {
    [1] = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t",
    [2] = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t",
    [3] = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
}

local selfEntryTexture = "Interface\\CharacterFrame\\UI-Player-PlayTimeUnhealthy"
local currentKeyFallbackTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
local currentKeyCheckTexture = "Interface\\Buttons\\UI-CheckBox-Check"
local friendSourceTexture = "Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon"

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

local function CreateNativeHeaderCell(parent, text)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetHeight(parent:GetHeight())

    cell.background = cell:CreateTexture(nil, "BACKGROUND")
    cell.background:SetAllPoints()
    cell.background:SetColorTexture(0.08, 0.08, 0.09, 0.92)

    cell.topBorder = cell:CreateTexture(nil, "BORDER")
    cell.topBorder:SetPoint("TOPLEFT", 0, 0)
    cell.topBorder:SetPoint("TOPRIGHT", 0, 0)
    cell.topBorder:SetHeight(1)
    cell.topBorder:SetColorTexture(0.82, 0.82, 0.86, 0.18)

    cell.bottomBorder = cell:CreateTexture(nil, "BORDER")
    cell.bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    cell.bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.bottomBorder:SetHeight(1)
    cell.bottomBorder:SetColorTexture(0, 0, 0, 0.7)

    cell.leftBorder = cell:CreateTexture(nil, "BORDER")
    cell.leftBorder:SetPoint("TOPLEFT", 0, 0)
    cell.leftBorder:SetPoint("BOTTOMLEFT", 0, 0)
    cell.leftBorder:SetWidth(1)
    cell.leftBorder:SetColorTexture(0.72, 0.72, 0.76, 0.12)

    cell.rightBorder = cell:CreateTexture(nil, "BORDER")
    cell.rightBorder:SetPoint("TOPRIGHT", 0, 0)
    cell.rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.rightBorder:SetWidth(1)
    cell.rightBorder:SetColorTexture(0.72, 0.72, 0.76, 0.22)

    cell.highlight = cell:CreateTexture(nil, "ARTWORK")
    cell.highlight:SetPoint("TOPLEFT", 1, -1)
    cell.highlight:SetPoint("TOPRIGHT", -1, -1)
    cell.highlight:SetHeight(8)
    cell.highlight:SetColorTexture(1, 1, 1, 0.06)

    cell.label = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cell.label:SetPoint("LEFT", 8, 0)
    cell.label:SetPoint("RIGHT", -6, 0)
    cell.label:SetJustifyH("LEFT")
    cell.label:SetText(text or "")

    return cell
end

local function GetControlWidth(control)
    if not control then
        return 0
    end

    local width = control.GetWidth and control:GetWidth() or 0
    local label = control.Text
    if label and label.GetStringWidth then
        width = math.max(width, math.ceil(label:GetStringWidth()) + 30)
    end

    return math.max(width, 1)
end

local function GetControlHeight(control)
    if not control then
        return 0
    end

    return math.max(control.GetHeight and control:GetHeight() or 0, 22)
end

local function LayoutFlowRow(parent, controls, startX, rightLimit, topY, columnSpacing, rowSpacing)
    local x = startX
    local y = topY
    local rowHeight = 0
    local bottomY = topY

    for index = 1, #controls do
        local control = controls[index]
        if control then
            local width = GetControlWidth(control)
            local height = GetControlHeight(control)

            if x > startX and (x + width) > rightLimit then
                x = startX
                y = y - rowHeight - rowSpacing
                rowHeight = 0
            end

            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

            x = x + width + columnSpacing
            rowHeight = math.max(rowHeight, height)
            bottomY = y - rowHeight
        end
    end

    return bottomY
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

local function ShouldShowFriendSourceIcon(record)
    if not record then
        return false
    end

    if ns.Config:Get("sourceFilter") ~= "all" then
        return false
    end

    if record.source ~= "friend" then
        return false
    end

    return true
end

local function ApplyScoreColor(fontString, score)
    if not fontString then
        return
    end

    local color = ns:GetScoreColor(score or 0)
    fontString:SetTextColor(color:GetRGB())
end

local function ApplyItemLevelPresentation(fontString, itemLevel, isStale)
    if not fontString then
        return
    end

    if isStale then
        fontString:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    else
        fontString:SetTextColor(ns:GetItemLevelColor(itemLevel):GetRGB())
    end
end

local function ApplyRunCountPresentation(fontString, count)
    if not fontString then
        return
    end

    fontString:SetTextColor(ns:GetRunCountColor(count):GetRGB())
end

local function ApplyRankPresentation(fontString, rank)
    if not fontString then
        return
    end

    if rankIcons[rank] then
        fontString:SetText(rankIcons[rank])
        fontString:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    else
        fontString:SetText(rank)
        fontString:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    end
end

local function ApplyCurrentKeyStatusIndicator(indicator, status)
    if not indicator or not indicator.primary or not indicator.secondary or not indicator.tertiary then
        return
    end

    indicator.primary:Hide()
    indicator.secondary:Hide()
    indicator.tertiary:Hide()
    if not status then
        return
    end

    local r, g, b = 1, 0.82, 0.12
    if status == "timed" or status == "plus2" or status == "plus3" then
        r, g, b = 0.25, 1, 0.25
    end

    indicator.primary:SetTexture(currentKeyCheckTexture)
    indicator.primary:SetVertexColor(r, g, b)
    indicator.primary:Show()

    if status == "plus2" then
        indicator.secondary:SetTexture(currentKeyCheckTexture)
        indicator.secondary:SetVertexColor(r, g, b)
        indicator.secondary:Show()
    elseif status == "plus3" then
        indicator.secondary:SetTexture(currentKeyCheckTexture)
        indicator.secondary:SetVertexColor(r, g, b)
        indicator.secondary:Show()
        indicator.tertiary:SetTexture(currentKeyCheckTexture)
        indicator.tertiary:SetVertexColor(r, g, b)
        indicator.tertiary:Show()
    end
end

local function UpdateCurrentKeyHeader(header)
    if not header or not header.icon or not header.level then
        return
    end

    local context = ns.Data:GetCurrentKeyContext() or {}
    if context.mapID and context.level then
        local texture = context.texture or context.backgroundTexture or currentKeyFallbackTexture

        header.icon:Show()
        header.icon:SetTexture(texture)
        header.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        header.icon:SetDesaturated(false)
        header.icon:SetVertexColor(1, 1, 1, 1)

        header.level:ClearAllPoints()
        header.level:SetPoint("LEFT", header.icon, "RIGHT", 2, 0)
        header.level:SetWidth(20)
        header.level:SetJustifyH("LEFT")
        header.level:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        header.level:SetText("+" .. context.level)
    else
        header.icon:SetTexture(nil)
        header.icon:Hide()

        header.level:ClearAllPoints()
        header.level:SetPoint("CENTER", header, "CENTER", 0, 0)
        header.level:SetWidth(header:GetWidth())
        header.level:SetJustifyH("CENTER")
        header.level:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        header.level:SetText("-")
    end
end

local function BuildCurrentKeyTooltipIcons(count, red, green, blue)
    local icons = {}
    local r = math.floor((red or 1) * 255 + 0.5)
    local g = math.floor((green or 1) * 255 + 0.5)
    local b = math.floor((blue or 1) * 255 + 0.5)

    for index = 1, count do
        icons[index] = ("|T%s:12:12:0:0:64:64:0:64:0:64:%d:%d:%d:255|t"):format(currentKeyCheckTexture, r, g, b)
    end

    return table.concat(icons, "")
end

local function ShowCurrentKeyHeaderTooltip(owner)
    if not owner then
        return
    end

    local context = ns.Data:GetCurrentKeyContext() or {}
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if context.mapID and context.level then
        GameTooltip:SetText(ns.L.CURRENT_KEY_TOOLTIP_LEVEL:format(context.mapName or ns.L.CURRENT_KEY, context.level))
        GameTooltip:AddLine(("%s %s"):format(BuildCurrentKeyTooltipIcons(3, 0.25, 1, 0.25), ns.L.CURRENT_KEY_PLUS_THREE), 0.25, 1, 0.25)
        GameTooltip:AddLine(("%s %s"):format(BuildCurrentKeyTooltipIcons(2, 0.25, 1, 0.25), ns.L.CURRENT_KEY_PLUS_TWO), 0.25, 1, 0.25)
        GameTooltip:AddLine(("%s %s"):format(BuildCurrentKeyTooltipIcons(1, 0.25, 1, 0.25), ns.L.CURRENT_KEY_TIMED), 0.25, 1, 0.25)
        GameTooltip:AddLine(("%s %s"):format(BuildCurrentKeyTooltipIcons(1, 1, 0.82, 0.12), ns.L.CURRENT_KEY_COMPLETED), 1, 0.82, 0.12)
    else
        GameTooltip:SetText(ns.L.NO_CURRENT_KEY)
    end
    GameTooltip:Show()
end

local function ShowTimedBucketHeaderTooltip(owner, bucketKey)
    if not owner or not bucketKey then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(ns:GetTimedBucketLabel(bucketKey))

    local bucketName = ns:GetTimedBucketName(bucketKey)
    if bucketName then
        GameTooltip:AddLine(bucketName, HIGHLIGHT_FONT_COLOR:GetRGB())
    end

    GameTooltip:Show()
end

local function ConfigureTimedBucketHeaderCell(cell, bucketKey)
    if not cell or not cell.label then
        return
    end

    local iconTexture = ns:GetTimedBucketIcon(bucketKey)
    cell.bucketKey = bucketKey

    if iconTexture then
        if not cell.icon then
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(14, 14)
        end

        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self)
            ShowTimedBucketHeaderTooltip(self, self.bucketKey)
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)

        cell.icon:ClearAllPoints()
        cell.icon:SetPoint("CENTER", 0, 0)
        cell.icon:SetTexture(iconTexture)
        cell.icon:Show()

        cell.label:SetText("")
    else
        if cell.icon then
            cell.icon:SetTexture(nil)
            cell.icon:Hide()
        end
        cell:EnableMouse(false)
        cell:SetScript("OnEnter", nil)
        cell:SetScript("OnLeave", nil)
        cell.label:SetText(ns:GetTimedBucketLabel(bucketKey))
        cell.label:ClearAllPoints()
        cell.label:SetPoint("LEFT", 8, 0)
        cell.label:SetPoint("RIGHT", -6, 0)
    end
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
        showUnscored = false,
        classFilter = ns.Config:Get("classFilter"),
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

function Panel:EnsureClassDropdown()
    if not self.frame or not self.frame.classLabel then
        return nil
    end

    if self.frame.classDropdown then
        return self.frame.classDropdown
    end

    local dropdown = _G[addonName .. "ClassDropdown"]
    if not dropdown then
        dropdown = CreateFrame("Frame", addonName .. "ClassDropdown", self.frame, "UIDropDownMenuTemplate")
    end

    if dropdown then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("LEFT", self.frame.classLabel, "RIGHT", -8, -2)
        self.frame.classDropdown = dropdown
    end

    return dropdown
end

function Panel:SetClassDropdownText(text)
    local dropdown = self:EnsureClassDropdown()
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

function Panel:BuildClassDropdown()
    local dropdown = self:EnsureClassDropdown()
    if not dropdown or not UIDropDownMenu_Initialize then
        return
    end

    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 150)
    end

    if UIDropDownMenu_JustifyText then
        UIDropDownMenu_JustifyText(dropdown, "LEFT")
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        if level ~= 1 then
            return
        end

        local info = UIDropDownMenu_CreateInfo()
        info.text = ns.L.ALL_CLASSES
        info.value = "all"
        info.checked = ns.Config:Get("classFilter") == "all"
        info.isNotRadio = false
        info.func = function()
            ns.Config:Set("classFilter", "all")
        end
        UIDropDownMenu_AddButton(info, level)

        local options = ns.Data:GetClassOptions()
        for index = 1, #options do
            local classInfo = options[index]
            info = UIDropDownMenu_CreateInfo()
            info.text = classInfo.className
            info.value = classInfo.classFile
            info.checked = ns.Config:Get("classFilter") == classInfo.classFile
            info.isNotRadio = false
            info.func = function()
                ns.Config:Set("classFilter", classInfo.classFile)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function Panel:CreateHeader(frame)
    frame.description = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.description:SetPoint("TOPLEFT", 12, -12)
    frame.description:SetJustifyH("LEFT")
    frame.description:SetWordWrap(false)
    frame.description:SetWidth(620)
    frame.description:SetText("")
    frame.description:Hide()

    frame.allButton = self:CreateSourceButton(frame, ns.L.ALL, "all")
    frame.allButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 84, -34)

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
    frame.groupByRole:SetPoint("LEFT", frame.onlineOnly, "RIGHT", 6, 0)

    frame.classLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.classLabel:SetPoint("TOPLEFT", frame.allButton, "BOTTOMLEFT", 0, -14)
    frame.classLabel:SetText(ns.L.CLASS_FILTER)
    frame.classLabel:Hide()

    frame.classDropdown = self:EnsureClassDropdown()

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

function Panel:ApplyListRowLayout(row)
    local layout = self.listColumnLayout
    local markerGutterWidth = 26
    if not row or not layout then
        return
    end

    row:SetHeight(self.rowHeight)
    row:SetWidth(layout.contentWidth)

    row.rank:SetWidth(layout.rankWidth)
    row.rank:SetJustifyH("CENTER")
    row.rank:ClearAllPoints()
    row.rank:SetPoint("LEFT", layout.xRank, 0)

    row.markerGutter:ClearAllPoints()
    row.markerGutter:SetPoint("LEFT", layout.xName, 0)
    row.markerGutter:SetSize(markerGutterWidth, 12)

    row.name:SetWidth(math.max(80, layout.nameWidth - markerGutterWidth - 4))
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.markerGutter, "RIGHT", 4, 0)

    row.roleIcon:ClearAllPoints()
    row.roleIcon:SetPoint("LEFT", layout.xRole + math.floor((layout.roleWidth - 14) / 2), 0)

    row.roleText:ClearAllPoints()
    row.roleText:SetPoint("LEFT", layout.xRole + layout.roleWidth, 0)
    row.roleText:SetWidth(1)

    row.specIcon:ClearAllPoints()
    row.specIcon:SetPoint("LEFT", layout.xSpec, 0)

    row.spec:SetWidth(math.max(60, layout.specWidth - 18))
    row.spec:ClearAllPoints()
    row.spec:SetPoint("LEFT", row.specIcon, "RIGHT", 4, 0)

    row.score:SetWidth(layout.scoreWidth)
    row.score:SetJustifyH("RIGHT")
    row.score:ClearAllPoints()
    row.score:SetPoint("LEFT", layout.xScore, 0)

    row.ilvl:SetWidth(layout.itemLevelWidth)
    row.ilvl:SetJustifyH("RIGHT")
    row.ilvl:ClearAllPoints()
    row.ilvl:SetPoint("LEFT", layout.xItemLevel, 0)

    row.best:SetWidth(layout.bestWidth)
    row.best:SetJustifyH("RIGHT")
    row.best:ClearAllPoints()
    row.best:SetPoint("LEFT", layout.xBest, 0)

    row.currentKey:ClearAllPoints()
    row.currentKey:SetPoint("LEFT", layout.xCurrentKey, 0)
    row.currentKey:SetSize(layout.currentKeyWidth, 14)

    row.timed20:SetWidth(layout.timed20Width)
    row.timed20:SetJustifyH("RIGHT")
    row.timed20:ClearAllPoints()
    row.timed20:SetPoint("LEFT", layout.xTimed20, 0)

    row.timed15:SetWidth(layout.timed15Width)
    row.timed15:SetJustifyH("RIGHT")
    row.timed15:ClearAllPoints()
    row.timed15:SetPoint("LEFT", layout.xTimed15, 0)

    row.timed11_14:SetWidth(layout.timed11_14Width)
    row.timed11_14:SetJustifyH("RIGHT")
    row.timed11_14:ClearAllPoints()
    row.timed11_14:SetPoint("LEFT", layout.xTimed11_14, 0)

    row.timed9_10:SetWidth(layout.timed9_10Width)
    row.timed9_10:SetJustifyH("RIGHT")
    row.timed9_10:ClearAllPoints()
    row.timed9_10:SetPoint("LEFT", layout.xTimed9_10, 0)

    row.timed4_8:SetWidth(layout.timed4_8Width)
    row.timed4_8:SetJustifyH("RIGHT")
    row.timed4_8:ClearAllPoints()
    row.timed4_8:SetPoint("LEFT", layout.xTimed4_8, 0)

    row.timed2_3:SetWidth(layout.timed2_3Width)
    row.timed2_3:SetJustifyH("RIGHT")
    row.timed2_3:ClearAllPoints()
    row.timed2_3:SetPoint("LEFT", layout.xTimed2_3, 0)
end

function Panel:InitializeListRow(row)
    if not row or row.RaiderRanksInitialized then
        return
    end

    row.RaiderRanksInitialized = true
    row:RegisterForClicks("LeftButtonUp")
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
        if self.hover then
            self.hover:Show()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not ns:ShowProfileTooltip(GameTooltip, self.data.name, self.data.realm) then
            GameTooltip:SetText(ns:GetRecordDisplayName(self.data))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.hover then
            self.hover:Hide()
        end
        GameTooltip_Hide()
    end)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(0, 0, 0, 0.1)

    row.selfGlow = row:CreateTexture(nil, "ARTWORK")
    row.selfGlow:SetAllPoints()
    row.selfGlow:SetColorTexture(1, 0.82, 0.12, 0.055)
    row.selfGlow:Hide()

    row.hover = row:CreateTexture(nil, "ARTWORK")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.035)
    row.hover:Hide()

    row.selection = row:CreateTexture(nil, "ARTWORK")
    row.selection:SetAllPoints()
    row.selection:SetColorTexture(0.22, 0.45, 0.8, 0.17)
    row.selection:Hide()

    row.separator = row:CreateTexture(nil, "BORDER")
    row.separator:SetPoint("BOTTOMLEFT", 6, 0)
    row.separator:SetPoint("BOTTOMRIGHT", -6, 0)
    row.separator:SetHeight(1)
    row.separator:SetColorTexture(1, 1, 1, 0.05)

    row.selfAccent = row:CreateTexture(nil, "BORDER")
    row.selfAccent:SetPoint("TOPLEFT", 0, 0)
    row.selfAccent:SetPoint("BOTTOMLEFT", 0, 0)
    row.selfAccent:SetWidth(3)
    row.selfAccent:SetColorTexture(1, 0.82, 0.12, 0.85)
    row.selfAccent:Hide()

    row.rank = CreateInlineText(row, 24, "LEFT")
    row.markerGutter = CreateFrame("Frame", nil, row)
    row.markerGutter:SetSize(26, 12)

    row.selfMarker = row.markerGutter:CreateTexture(nil, "ARTWORK")
    row.selfMarker:SetSize(12, 12)
    row.selfMarker:SetTexture(selfEntryTexture)
    row.selfMarker:Hide()

    row.friendMarker = row.markerGutter:CreateTexture(nil, "ARTWORK")
    row.friendMarker:SetSize(12, 12)
    row.friendMarker:SetTexture(friendSourceTexture)
    row.friendMarker:Hide()

    row.name = CreateInlineText(row, 140, "LEFT")

    row.roleIcon = row:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(14, 14)
    row.roleText = CreateInlineText(row, 28, "LEFT")

    row.specIcon = row:CreateTexture(nil, "ARTWORK")
    row.specIcon:SetSize(14, 14)
    row.spec = CreateInlineText(row, 68, "LEFT")

    row.score = CreateInlineText(row, 48, "LEFT")
    row.ilvl = CreateInlineText(row, 42, "LEFT")
    row.best = CreateInlineText(row, 78, "LEFT")

    row.currentKey = CreateFrame("Frame", nil, row)
    row.currentKey.primary = row.currentKey:CreateTexture(nil, "ARTWORK")
    row.currentKey.primary:SetPoint("RIGHT", 0, 0)
    row.currentKey.primary:SetSize(14, 14)
    row.currentKey.secondary = row.currentKey:CreateTexture(nil, "ARTWORK")
    row.currentKey.secondary:SetPoint("RIGHT", row.currentKey.primary, "LEFT", 3, 0)
    row.currentKey.secondary:SetSize(14, 14)
    row.currentKey.tertiary = row.currentKey:CreateTexture(nil, "ARTWORK")
    row.currentKey.tertiary:SetPoint("RIGHT", row.currentKey.secondary, "LEFT", 3, 0)
    row.currentKey.tertiary:SetSize(14, 14)

    row.timed20 = CreateInlineText(row, 30, "LEFT")
    row.timed15 = CreateInlineText(row, 30, "LEFT")
    row.timed11_14 = CreateInlineText(row, 30, "LEFT")
    row.timed9_10 = CreateInlineText(row, 30, "LEFT")
    row.timed4_8 = CreateInlineText(row, 30, "LEFT")
    row.timed2_3 = CreateInlineText(row, 30, "LEFT")

    self.frame.rows = self.frame.rows or {}
    self.frame.rows[#self.frame.rows + 1] = row
    self:ApplyListRowLayout(row)
end

function Panel:ApplyListRowData(row, data)
    if not row then
        return
    end

    row.data = data
    if not data then
        row:Hide()
        return
    end

    row:Show()
    if row.hover then
        row.hover:Hide()
    end
    row.selection:SetShown(data.fullName and data.fullName == self.selectedFullName)
    row.separator:SetShown(not data.isHeader)

    if data.isHeader then
        row.selfGlow:Hide()
        row.selfAccent:Hide()
        row.selfMarker:Hide()
        row.friendMarker:Hide()
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
        ApplyCurrentKeyStatusIndicator(row.currentKey, nil)
        row.timed20:SetText("")
        row.timed15:SetText("")
        row.timed11_14:SetText("")
        row.timed9_10:SetText("")
        row.timed4_8:SetText("")
        row.timed2_3:SetText("")
        row.background:SetColorTexture(0.12, 0.12, 0.14, 0.96)
        row.separator:Hide()
        return
    end

    local stripeIndex = data.displayRank or data.displayIndex or 1
    local isPlayerEntry = data.fullName and ns.playerFullName and data.fullName == ns.playerFullName
    local showFriendMarker = ShouldShowFriendSourceIcon(data)
    row.background:SetColorTexture(0, 0, 0, stripeIndex % 2 == 0 and 0.05 or 0.1)
    row.selfGlow:SetShown(isPlayerEntry)
    row.selfAccent:SetShown(isPlayerEntry)
    row.selfMarker:SetShown(isPlayerEntry)
    row.friendMarker:SetShown(showFriendMarker)

    row.selfMarker:ClearAllPoints()
    row.friendMarker:ClearAllPoints()
    row.selfMarker:SetPoint("LEFT", row.markerGutter, "LEFT", 0, 0)
    if showFriendMarker then
        if isPlayerEntry then
            row.friendMarker:SetPoint("LEFT", row.selfMarker, "RIGHT", 2, 0)
        else
            row.friendMarker:SetPoint("LEFT", row.markerGutter, "LEFT", 0, 0)
        end
    end

    ApplyRankPresentation(row.rank, data.roleRank or data.displayRank or 0)
    row.name:SetText(ns:GetRecordDisplayName(data))
    row.name:SetTextColor(ns:GetClassColor(data.classFile):GetRGB())

    row.roleIcon:SetAtlas(ns:GetRoleAtlas(data.roleBucket), true)
    row.roleIcon:Show()
    row.roleText:SetText("")

    if data.specIcon then
        row.specIcon:SetAtlas(nil)
        row.specIcon:SetTexture(data.specIcon)
    else
        row.specIcon:SetTexture(nil)
        row.specIcon:SetAtlas("classhall-icon-noglow", true)
    end
    row.specIcon:Show()
    if data.specName then
        row.spec:SetText(data.specName)
        row.spec:SetTextColor((data.specIsStale and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
        if row.specIcon.SetDesaturated then
            row.specIcon:SetDesaturated(data.specIsStale)
        end
    else
        row.spec:SetText(ns.L.UNKNOWN_SPEC_SHORT)
        row.spec:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        if row.specIcon.SetDesaturated then
            row.specIcon:SetDesaturated(true)
        end
    end

    row.score:SetText(data.currentScore > 0 and data.currentScore or "-")
    ApplyScoreColor(row.score, data.currentScore)

    if ns.Config:Get("showItemLevel") and data.equippedItemLevel then
        row.ilvl:SetText(ns:GetItemLevelText(data.equippedItemLevel))
        ApplyItemLevelPresentation(row.ilvl, data.equippedItemLevel, data.itemLevelIsStale)
    else
        row.ilvl:SetText("-")
        row.ilvl:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    end

    row.best:SetText(BuildBestRunText(data))
    ApplyCurrentKeyStatusIndicator(row.currentKey, data.currentKeyStatus)
    row.timed20:SetText(data.timed20 > 0 and data.timed20 or "-")
    row.timed15:SetText(data.timed15 > 0 and data.timed15 or "-")
    row.timed11_14:SetText(data.timed11_14 > 0 and data.timed11_14 or "-")
    row.timed9_10:SetText(data.timed9_10 > 0 and data.timed9_10 or "-")
    row.timed4_8:SetText(data.timed4_8 > 0 and data.timed4_8 or "-")
    row.timed2_3:SetText(data.timed2_3 > 0 and data.timed2_3 or "-")
    ApplyRunCountPresentation(row.timed20, data.timed20)
    ApplyRunCountPresentation(row.timed15, data.timed15)
    ApplyRunCountPresentation(row.timed11_14, data.timed11_14)
    ApplyRunCountPresentation(row.timed9_10, data.timed9_10)
    ApplyRunCountPresentation(row.timed4_8, data.timed4_8)
    ApplyRunCountPresentation(row.timed2_3, data.timed2_3)

    ns.Inspect:QueueRecord(data)
end

function Panel:PrepareDisplayRows(rows)
    rows = rows or {}

    local displayRank = 0
    local roleRank = 0
    for index = 1, #rows do
        local data = rows[index]
        data.displayIndex = index

        if data.isHeader then
            data.displayRank = nil
            data.roleRank = nil
            roleRank = 0
        else
            displayRank = displayRank + 1
            roleRank = roleRank + 1
            data.displayRank = displayRank
            data.roleRank = roleRank
        end
    end

    return rows
end

function Panel:CreateList(frame)
    frame.list = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -92)
    frame.list:SetPoint("BOTTOMLEFT", 0, 0)
    if frame.list.SetClipsChildren then
        frame.list:SetClipsChildren(true)
    end

    frame.list.header = CreateFrame("Frame", nil, frame.list)
    frame.list.header:SetPoint("TOPLEFT", 8, -8)
    frame.list.header:SetPoint("TOPRIGHT", -34, -8)
    frame.list.header:SetHeight(24)

    local headerColumns = {
        { key = "rank", text = ns.L.RANK, width = 24, x = 0 },
        { key = "name", text = ns.L.NAME, width = 140, x = 30 },
        { key = "role", text = ns.L.ROLE, width = 46, x = 174 },
        { key = "spec", text = ns.L.SPEC, width = 84, x = 226 },
        { key = "score", text = ns.L.SCORE, width = 48, x = 314 },
        { key = "ilvl", text = ns.L.ITEM_LEVEL, width = 42, x = 368 },
        { key = "best", text = ns.L.BEST, width = 78, x = 416 },
        { key = "timed20", text = ns.L.TIMED_20, width = 42, x = 542 },
        { key = "timed15", text = ns.L.TIMED_15, width = 34, x = 580 },
        { key = "timed11_14", text = ns.L.TIMED_11_14, width = 40, x = 618 },
        { key = "timed9_10", text = ns.L.TIMED_9_10, width = 40, x = 662 },
        { key = "timed4_8", text = ns.L.TIMED_4_8, width = 40, x = 706 },
        { key = "timed2_3", text = ns.L.TIMED_2_3, width = 40, x = 750 }
    }

    for index = 1, #headerColumns do
        local info = headerColumns[index]
        local cell = CreateNativeHeaderCell(frame.list.header, info.text)
        cell:SetPoint("LEFT", info.x, 0)
        cell:SetWidth(info.width)
        frame.list.header[info.key] = cell
        if info.key:match("^timed") then
            ConfigureTimedBucketHeaderCell(cell, info.key)
        end
    end

    frame.list.header.currentKeyCell = CreateNativeHeaderCell(frame.list.header, "")
    frame.list.header.currentKeyCell:SetPoint("LEFT", 500, 0)
    frame.list.header.currentKeyCell:SetWidth(54)
    frame.list.header.currentKey = CreateFrame("Button", nil, frame.list.header.currentKeyCell)
    frame.list.header.currentKey:SetPoint("LEFT", 6, 0)
    frame.list.header.currentKey:SetSize(44, 18)
    frame.list.header.currentKey.icon = frame.list.header.currentKey:CreateTexture(nil, "ARTWORK")
    frame.list.header.currentKey.icon:SetPoint("LEFT", 0, 0)
    frame.list.header.currentKey.icon:SetSize(18, 18)
    frame.list.header.currentKey.level = frame.list.header.currentKey:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.list.header.currentKey.level:SetPoint("LEFT", frame.list.header.currentKey.icon, "RIGHT", 2, 0)
    frame.list.header.currentKey.level:SetWidth(20)
    frame.list.header.currentKey.level:SetJustifyH("LEFT")
    frame.list.header.currentKey:SetScript("OnEnter", function(self)
        ShowCurrentKeyHeaderTooltip(self)
    end)
    frame.list.header.currentKey:SetScript("OnLeave", GameTooltip_Hide)

    CreateDivider(frame.list, frame.list.header, -1)

    frame.list.body = CreateFrame("Frame", nil, frame.list)
    frame.list.body:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 8, -34)
    frame.list.body:SetPoint("BOTTOMRIGHT", frame.list, "BOTTOMRIGHT", -8, 8)
    if frame.list.body.SetClipsChildren then
        frame.list.body:SetClipsChildren(true)
    end

    frame.list.emptyText = frame.list.body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.list.emptyText:SetPoint("CENTER", frame.list.body, "CENTER", 0, 0)
    frame.list.emptyText:SetText(ns.L.NO_DATA)
    frame.list.emptyText:Hide()

    local scrollBarInset = 6
    local scrollBarGap = 6

    frame.scrollBox = CreateFrame("Frame", nil, frame.list.body, "WowScrollBoxList")
    frame.scrollBox:SetPoint("TOPLEFT", frame.list.body, "TOPLEFT", 0, 0)

    frame.scrollBar = CreateFrame("EventFrame", nil, frame.list.body, "MinimalScrollBar")
    frame.scrollBar:SetPoint("TOPRIGHT", frame.list.body, "TOPRIGHT", -scrollBarInset, 0)
    frame.scrollBar:SetPoint("BOTTOMRIGHT", frame.list.body, "BOTTOMRIGHT", -scrollBarInset, 0)

    frame.scrollBox:SetPoint("BOTTOMRIGHT", frame.scrollBar, "BOTTOMLEFT", -scrollBarGap, 0)
    frame.scrollBox:SetPoint("TOPRIGHT", frame.scrollBar, "TOPLEFT", -scrollBarGap, 0)

    if frame.scrollBox.SetInterpolateScroll then
        frame.scrollBox:SetInterpolateScroll(true)
    end
    if frame.scrollBar.SetInterpolateScroll then
        frame.scrollBar:SetInterpolateScroll(true)
    end

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(self.rowHeight)
    if view.SetPadding then
        view:SetPadding(0, 0, 0, 0, 0)
    end
    view:SetElementInitializer("Button", function(button, elementData)
        Panel:InitializeListRow(button)
        Panel:ApplyListRowLayout(button)
        Panel:ApplyListRowData(button, elementData)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(frame.scrollBox, frame.scrollBar, view)
    frame.listDataProvider = CreateDataProvider()
    frame.scrollBox:SetDataProvider(frame.listDataProvider)
    frame.rows = {}
end

function Panel:CreateDetail(frame)
    if ns.DetailPanel then
        return ns.DetailPanel:Create(frame)
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

    if PVEFrame.GetFrameStrata and frame.SetFrameStrata then
        frame:SetFrameStrata(PVEFrame:GetFrameStrata())
    end

    frame:SetFrameLevel(math.max(PVEFrame:GetFrameLevel() + 100, 100))
    if frame.SetClipsChildren then
        frame:SetClipsChildren(true)
    end

    frame.fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.fill:SetAllPoints()
    frame.fill:SetColorTexture(0.03, 0.03, 0.04, 1)

    frame.background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.background:SetAllPoints()
    frame.background:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
    frame.background:SetHorizTile(true)
    frame.background:SetVertTile(true)
    frame.background:SetVertexColor(0.72, 0.72, 0.72, 0.95)

    frame.shade = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.shade:SetAllPoints()
    frame.shade:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
    frame.shade:SetHorizTile(true)
    frame.shade:SetVertTile(true)
    frame.shade:SetVertexColor(1, 1, 1, 0.18)

    frame.topFade = frame:CreateTexture(nil, "BORDER")
    frame.topFade:SetPoint("TOPLEFT", 0, 0)
    frame.topFade:SetPoint("TOPRIGHT", 0, 0)
    frame.topFade:SetHeight(54)
    frame.topFade:SetColorTexture(0, 0, 0, 0.18)

    frame:Hide()
    frame:SetScript("OnShow", function()
        Panel:Refresh()
    end)
    frame:SetScript("OnSizeChanged", function()
        Panel:ApplyLayout()
    end)

    self:CreateHeader(frame)
    self:CreateDetail(frame)
    self:CreateList(frame)

    self:BuildClassDropdown()
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
    if not frame or not frame.detail or not frame.list then
        return
    end

    local width = math.max(frame:GetWidth(), 900)
    local detailWidth = math.floor(math.max(330, math.min(420, width * 0.31)))
    local leftInset = 84
    local rightInset = 12
    local headerTop = -34
    local spacing = 12

    frame.settingsButton:ClearAllPoints()
    frame.settingsButton:SetPoint("TOPRIGHT", -rightInset, headerTop)

    local settingsLeft = width - rightInset - GetControlWidth(frame.settingsButton)
    local descriptionRightInset = math.max(rightInset + 8, width - settingsLeft + 8)
    frame.description:ClearAllPoints()
    frame.description:SetPoint("TOPLEFT", leftInset, -14)
    frame.description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -descriptionRightInset, -14)
    frame.description:Hide()

    frame.classLabel:Hide()

    local dropdown = self:EnsureClassDropdown()
    local toolbarBottom = LayoutFlowRow(
        frame,
        { frame.allButton, frame.guildButton, frame.friendsButton, frame.onlineOnly, frame.groupByRole, dropdown },
        leftInset,
        settingsLeft - 16,
        headerTop,
        8,
        6
    )

    local topOffset = toolbarBottom - 12

    frame.detail:ClearAllPoints()
    frame.detail:SetPoint("TOPRIGHT", 0, topOffset)
    frame.detail:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.detail:SetWidth(detailWidth)

    frame.list:ClearAllPoints()
    frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, topOffset)
    frame.list:SetPoint("TOPRIGHT", frame.detail, "TOPLEFT", -spacing, 0)
    frame.list:SetPoint("BOTTOMLEFT", 0, 0)
    frame.list:SetPoint("BOTTOMRIGHT", frame.detail, "BOTTOMLEFT", -spacing, 0)

    if ns.DetailPanel then
        ns.DetailPanel:ApplyLayout(frame, detailWidth)
    end

    self:ApplyListColumns()
end

function Panel:ApplyListColumns()
    local frame = self.frame
    if not frame or not frame.list or not frame.list.header or not frame.rows then
        return
    end

    local scrollContentWidth = frame.scrollBox and frame.scrollBox.GetWidth and frame.scrollBox:GetWidth() or frame.list.header:GetWidth()
    local contentWidth = math.max(620, math.floor(math.min(frame.list.header:GetWidth(), scrollContentWidth)))
    local gap = 4
    local rankWidth = 48
    local roleWidth = 44
    local scoreWidth = 46
    local itemLevelWidth = 38
    local bestWidth = 50
    local currentKeyWidth = 50
    local timed20Width = 42
    local timed15Width = 34
    local timed11_14Width = 40
    local timed9_10Width = 40
    local timed4_8Width = 40
    local timed2_3Width = 40
    local fixedWidths = rankWidth + roleWidth + scoreWidth + itemLevelWidth + bestWidth + currentKeyWidth + timed20Width + timed15Width + timed11_14Width + timed9_10Width + timed4_8Width + timed2_3Width
    local fixedGaps = gap * 13
    local remaining = math.max(128, contentWidth - fixedWidths - fixedGaps)
    local specWidth = math.max(66, math.min(92, math.floor(remaining * 0.34)))
    local nameWidth = remaining - specWidth
    if nameWidth < 96 then
        specWidth = math.max(60, specWidth - (96 - nameWidth))
        nameWidth = remaining - specWidth
    end

    local xRank = 0
    local xName = xRank + rankWidth + gap
    local xRole = xName + nameWidth + gap
    local xSpec = xRole + roleWidth + gap
    local xScore = xSpec + specWidth + gap
    local xItemLevel = xScore + scoreWidth + gap
    local xBest = xItemLevel + itemLevelWidth + gap
    local xCurrentKey = xBest + bestWidth + gap
    local xTimed20 = xCurrentKey + currentKeyWidth + gap
    local xTimed15 = xTimed20 + timed20Width + gap
    local xTimed11_14 = xTimed15 + timed15Width + gap
    local xTimed9_10 = xTimed11_14 + timed11_14Width + gap
    local xTimed4_8 = xTimed9_10 + timed9_10Width + gap
    local xTimed2_3 = xTimed4_8 + timed4_8Width + gap

    self.listColumnLayout = {
        contentWidth = contentWidth,
        rankWidth = rankWidth,
        nameWidth = nameWidth,
        roleWidth = roleWidth,
        specWidth = specWidth,
        scoreWidth = scoreWidth,
        itemLevelWidth = itemLevelWidth,
        bestWidth = bestWidth,
        currentKeyWidth = currentKeyWidth,
        timedWidth = timed15Width,
        timed20Width = timed20Width,
        timed15Width = timed15Width,
        timed11_14Width = timed11_14Width,
        timed9_10Width = timed9_10Width,
        timed4_8Width = timed4_8Width,
        timed2_3Width = timed2_3Width,
        xRank = xRank,
        xName = xName,
        xRole = xRole,
        xSpec = xSpec,
        xScore = xScore,
        xItemLevel = xItemLevel,
        xBest = xBest,
        xCurrentKey = xCurrentKey,
        xTimed20 = xTimed20,
        xTimed15 = xTimed15,
        xTimed11_14 = xTimed11_14,
        xTimed9_10 = xTimed9_10,
        xTimed4_8 = xTimed4_8,
        xTimed2_3 = xTimed2_3
    }

    frame.list.header.rank:ClearAllPoints()
    frame.list.header.rank:SetPoint("LEFT", xRank, 0)
    frame.list.header.rank:SetWidth(rankWidth)

    frame.list.header.name:ClearAllPoints()
    frame.list.header.name:SetPoint("LEFT", xName, 0)
    frame.list.header.name:SetWidth(nameWidth)

    frame.list.header.role:ClearAllPoints()
    frame.list.header.role:SetPoint("LEFT", xRole, 0)
    frame.list.header.role:SetWidth(roleWidth)

    frame.list.header.spec:ClearAllPoints()
    frame.list.header.spec:SetPoint("LEFT", xSpec, 0)
    frame.list.header.spec:SetWidth(specWidth)

    frame.list.header.score:ClearAllPoints()
    frame.list.header.score:SetPoint("LEFT", xScore, 0)
    frame.list.header.score:SetWidth(scoreWidth)

    frame.list.header.ilvl:ClearAllPoints()
    frame.list.header.ilvl:SetPoint("LEFT", xItemLevel, 0)
    frame.list.header.ilvl:SetWidth(itemLevelWidth)

    frame.list.header.best:ClearAllPoints()
    frame.list.header.best:SetPoint("LEFT", xBest, 0)
    frame.list.header.best:SetWidth(bestWidth)

    frame.list.header.currentKeyCell:ClearAllPoints()
    frame.list.header.currentKeyCell:SetPoint("LEFT", xCurrentKey, 0)
    frame.list.header.currentKeyCell:SetWidth(currentKeyWidth)

    frame.list.header.currentKey:ClearAllPoints()
    frame.list.header.currentKey:SetPoint("LEFT", frame.list.header.currentKeyCell, "LEFT", 6, 0)
    frame.list.header.currentKey:SetSize(currentKeyWidth - 10, 18)

    frame.list.header.timed20:ClearAllPoints()
    frame.list.header.timed20:SetPoint("LEFT", xTimed20, 0)
    frame.list.header.timed20:SetWidth(timed20Width)

    frame.list.header.timed15:ClearAllPoints()
    frame.list.header.timed15:SetPoint("LEFT", xTimed15, 0)
    frame.list.header.timed15:SetWidth(timed15Width)

    frame.list.header.timed11_14:ClearAllPoints()
    frame.list.header.timed11_14:SetPoint("LEFT", xTimed11_14, 0)
    frame.list.header.timed11_14:SetWidth(timed11_14Width)

    frame.list.header.timed9_10:ClearAllPoints()
    frame.list.header.timed9_10:SetPoint("LEFT", xTimed9_10, 0)
    frame.list.header.timed9_10:SetWidth(timed9_10Width)

    frame.list.header.timed4_8:ClearAllPoints()
    frame.list.header.timed4_8:SetPoint("LEFT", xTimed4_8, 0)
    frame.list.header.timed4_8:SetWidth(timed4_8Width)

    frame.list.header.timed2_3:ClearAllPoints()
    frame.list.header.timed2_3:SetPoint("LEFT", xTimed2_3, 0)
    frame.list.header.timed2_3:SetWidth(timed2_3Width)

    for index = 1, #frame.rows do
        self:ApplyListRowLayout(frame.rows[index])
    end
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

function Panel:SelectIntegratedTab()
    if not self:EnsureCreated() then
        return
    end

    self:ExpandPVEFrame()
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

    frame.description:SetText("")
    frame.description:Hide()

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
    frame.groupByRole:SetChecked(ns.Config:Get("groupByRole"))
    UpdateCurrentKeyHeader(frame.list and frame.list.header and frame.list.header.currentKey)

    self:SetClassDropdownText(ns.L.ALL_CLASSES)
    local classFilter = ns.Config:Get("classFilter")
    if classFilter ~= "all" then
        local options = ns.Data:GetClassOptions()
        for index = 1, #options do
            local classInfo = options[index]
            if classInfo.classFile == classFilter then
                self:SetClassDropdownText(classInfo.className)
                break
            end
        end
    end
end

function Panel:RefreshRows()
    if not self.frame or not self.frame.scrollBox or not self.frame.listDataProvider then
        return
    end

    local totalRows = #self.displayRows
    self.frame.list.emptyText:SetShown(totalRows == 0)
    if totalRows == 0 then
        self.frame.list.emptyText:SetText(ns:IsRaiderIOAvailable() and ns.L.NO_DATA or ns.L.RAIDERIO_MISSING)
    end

    self.frame.listDataProvider:Flush()
    if totalRows > 0 then
        self.frame.listDataProvider:InsertTable(self.displayRows)
    end
end

function Panel:RefreshDetail()
    if ns.DetailPanel then
        ns.DetailPanel:Refresh(self)
    end
end

function Panel:Refresh()
    if self.frame then
        self:BuildClassDropdown()
        self:RefreshHeaderControls()
        self.displayRows = self:PrepareDisplayRows(ns.Data:GetRecords(self:GetFilters()))
        self:EnsureSelected()
        self:RefreshRows()
        self:RefreshDetail()
    end

    self:RefreshInline()
end

function Panel:GetInlineValues(record)
    if not record then
        return "-", "-", nil, nil, nil, false
    end

    local scoreText = record.currentScore > 0 and tostring(record.currentScore) or "-"
    local itemLevelText = "-"
    local itemLevelValue = nil
    if ns.Config:Get("showItemLevel") and record.equippedItemLevel then
        itemLevelText = ns:GetItemLevelText(record.equippedItemLevel)
        itemLevelValue = record.equippedItemLevel
    end

    local atlas = nil
    local texture = nil
    if record.specIcon then
        texture = record.specIcon
    else
        atlas = ns:GetRoleAtlas(record.roleBucket)
    end

    return scoreText, itemLevelText, atlas, texture, itemLevelValue, record.itemLevelIsStale
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

    if not record or record.profileState ~= "ready" or (record.currentScore or 0) <= 0 then
        widget:Hide()
        return
    end

    local scoreText, itemLevelText, atlas, texture, itemLevelValue, itemLevelIsStale = self:GetInlineValues(record)
    widget.score:SetText(scoreText)
    ApplyScoreColor(widget.score, record and record.currentScore or 0)
    widget.ilvl:SetText(itemLevelText)
    ApplyItemLevelPresentation(widget.ilvl, itemLevelValue, itemLevelIsStale)

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
