local _, ns = ...

local DetailPanel = {}
ns.DetailPanel = DetailPanel

local panelBackgroundTexture = "Interface\\FrameGeneral\\UI-Background-Marble"
local panelShadowTexture = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local marbleTexture = "Interface\\FrameGeneral\\UI-Background-Marble"
local fallbackSpecTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
local solidTexture = "Interface\\Buttons\\WHITE8X8"
local dungeonFallbackTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
local warningIconAtlas = "services-icon-warning"

local timedBucketKeys = {
    "timed20",
    "timed15",
    "timed11_14",
    "timed9_10",
    "timed4_8",
    "timed2_3"
}

local timedBucketMinimumLevels = {
    timed20 = 20,
    timed15 = 15,
    timed11_14 = 11,
    timed9_10 = 9,
    timed4_8 = 4,
    timed2_3 = 2
}

-- Score thresholds for "just timed" and "just over time" projections.
local dungeonScoreThresholds = {
    [2] = {155, 139.962},
    [3] = {170, 154.962},
    [4] = {185, 169.962},
    [5] = {215, 199.962},
    [6] = {230, 214.962},
    [7] = {260, 244.962},
    [8] = {275, 259.962},
    [9] = {290, 274.962},
    [10] = {320, 304.962},
    [11] = {335, 304.962},
    [12] = {365, 319.962},
    [13] = {380, 319.962},
    [14] = {395, 319.962},
    [15] = {410, 319.962},
    [16] = {425, 319.962},
    [17] = {440, 319.962},
    [18] = {455, 319.962},
    [19] = {470, 319.962},
    [20] = {485, 319.962},
    [21] = {500, 319.962},
    [22] = {515, 319.962},
    [23] = {530, 319.962},
    [24] = {545, 319.962},
    [25] = {560, 319.962},
    [26] = {575, 319.962},
    [27] = {590, 319.962},
    [28] = {605, 319.962},
    [29] = {620, 319.962},
    [30] = {635, 319.962},
    [31] = {650, 319.962},
    [32] = {665, 319.962},
    [33] = {680, 319.962},
    [34] = {695, 319.962},
    [35] = {710, 319.962},
    [36] = {725, 319.962},
    [37] = {740, 319.962},
    [38] = {755, 319.962},
    [39] = {770, 319.962},
}

local dungeonTextureCache = {}

local function CreateDivider(parent)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    return divider
end

local function CreateBorder(parent, pointA, pointB, width, height)
    local border = parent:CreateTexture(nil, "BORDER")
    border:SetTexture(solidTexture)
    border:SetPoint(pointA, parent, pointA, 0, 0)
    border:SetPoint(pointB, parent, pointB, 0, 0)
    if width then
        border:SetWidth(width)
    end
    if height then
        border:SetHeight(height)
    end
    border:SetVertexColor(1, 1, 1, 0.08)
    return border
end

local function CreateSection(parent, titleText)
    local section = CreateFrame("Frame", nil, parent)
    section.title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    section.title:SetPoint("TOPLEFT", 0, 0)
    section.title:SetJustifyH("LEFT")
    section.title:SetText(titleText or "")

    section.divider = CreateDivider(section)
    section.divider:SetPoint("TOPLEFT", section.title, "BOTTOMLEFT", 0, -4)
    section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, -18)

    return section
end

local function CreateValueRow(parent, labelText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetText(labelText or "")

    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.value:SetPoint("TOPLEFT", row.label, "TOPRIGHT", 10, 0)
    row.value:SetPoint("RIGHT", 0, 0)
    row.value:SetJustifyH("LEFT")
    row.value:SetWordWrap(false)

    return row
end

local function CreateKeyTabButton(parent, labelText, tabID)
    local button = CreateFrame("Button", nil, parent)
    button.tabID = tabID
    button:SetHeight(20)
    if button.SetMotionScriptsWhileDisabled then
        button:SetMotionScriptsWhileDisabled(true)
    end

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetTexture(solidTexture)

    button.topBorder = button:CreateTexture(nil, "BORDER")
    button.topBorder:SetPoint("TOPLEFT", 0, 0)
    button.topBorder:SetPoint("TOPRIGHT", 0, 0)
    button.topBorder:SetHeight(1)
    button.topBorder:SetTexture(solidTexture)

    button.bottomBorder = button:CreateTexture(nil, "BORDER")
    button.bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    button.bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    button.bottomBorder:SetHeight(1)
    button.bottomBorder:SetTexture(solidTexture)
    button.bottomBorder:SetVertexColor(0, 0, 0, 0.7)

    button.leftBorder = button:CreateTexture(nil, "BORDER")
    button.leftBorder:SetPoint("TOPLEFT", 0, 0)
    button.leftBorder:SetPoint("BOTTOMLEFT", 0, 0)
    button.leftBorder:SetWidth(1)
    button.leftBorder:SetTexture(solidTexture)
    button.leftBorder:SetVertexColor(1, 1, 1, 0.08)

    button.rightBorder = button:CreateTexture(nil, "BORDER")
    button.rightBorder:SetPoint("TOPRIGHT", 0, 0)
    button.rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    button.rightBorder:SetWidth(1)
    button.rightBorder:SetTexture(solidTexture)
    button.rightBorder:SetVertexColor(1, 1, 1, 0.08)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetAllPoints()
    button.highlight:SetTexture(solidTexture)
    button.highlight:SetVertexColor(1, 1, 1, 0.04)

    button.selected = button:CreateTexture(nil, "ARTWORK")
    button.selected:SetPoint("BOTTOMLEFT", 0, 0)
    button.selected:SetPoint("BOTTOMRIGHT", 0, 0)
    button.selected:SetHeight(2)
    button.selected:SetTexture(solidTexture)
    button.selected:Hide()

    button.text = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", 6, 0)
    button.text:SetPoint("RIGHT", -20, 0)
    button.text:SetJustifyH("CENTER")
    button.text:SetText(labelText or "")

    return button
end

local function CreateInlineInfoButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(14, 14)
    if button.SetMotionScriptsWhileDisabled then
        button:SetMotionScriptsWhileDisabled(true)
    end
    if button.SetHitRectInsets then
        button:SetHitRectInsets(-4, -4, -4, -4)
    end
    button:SetNormalTexture("Interface\\Common\\help-i")
    button:SetHighlightTexture("Interface\\Common\\help-i", "ADD")
    button:SetPushedTexture("Interface\\Common\\help-i")
    button:GetNormalTexture():SetAllPoints()
    button:GetHighlightTexture():SetAllPoints()
    button:GetHighlightTexture():SetAlpha(0.2)
    button:GetPushedTexture():SetAllPoints()
    button:GetPushedTexture():SetVertexColor(0.9, 0.9, 0.9, 1)
    return button
end

local function CreateHeaderCell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell.background = cell:CreateTexture(nil, "BACKGROUND")
    cell.background:SetAllPoints()
    cell.background:SetTexture(solidTexture)
    cell.background:SetVertexColor(0.08, 0.08, 0.09, 0.92)

    cell.topBorder = cell:CreateTexture(nil, "BORDER")
    cell.topBorder:SetPoint("TOPLEFT", 0, 0)
    cell.topBorder:SetPoint("TOPRIGHT", 0, 0)
    cell.topBorder:SetHeight(1)
    cell.topBorder:SetTexture(solidTexture)
    cell.topBorder:SetVertexColor(0.82, 0.82, 0.86, 0.18)

    cell.bottomBorder = cell:CreateTexture(nil, "BORDER")
    cell.bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    cell.bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.bottomBorder:SetHeight(1)
    cell.bottomBorder:SetTexture(solidTexture)
    cell.bottomBorder:SetVertexColor(0, 0, 0, 0.7)

    cell.leftBorder = cell:CreateTexture(nil, "BORDER")
    cell.leftBorder:SetPoint("TOPLEFT", 0, 0)
    cell.leftBorder:SetPoint("BOTTOMLEFT", 0, 0)
    cell.leftBorder:SetWidth(1)
    cell.leftBorder:SetTexture(solidTexture)
    cell.leftBorder:SetVertexColor(0.72, 0.72, 0.76, 0.12)

    cell.rightBorder = cell:CreateTexture(nil, "BORDER")
    cell.rightBorder:SetPoint("TOPRIGHT", 0, 0)
    cell.rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.rightBorder:SetWidth(1)
    cell.rightBorder:SetTexture(solidTexture)
    cell.rightBorder:SetVertexColor(0.72, 0.72, 0.76, 0.22)

    cell.highlight = cell:CreateTexture(nil, "ARTWORK")
    cell.highlight:SetPoint("TOPLEFT", 1, -1)
    cell.highlight:SetPoint("TOPRIGHT", -1, -1)
    cell.highlight:SetHeight(8)
    cell.highlight:SetTexture(solidTexture)
    cell.highlight:SetVertexColor(1, 1, 1, 0.06)

    cell.label = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cell.label:SetPoint("LEFT", 6, 0)
    cell.label:SetPoint("RIGHT", -6, 0)
    cell.label:SetJustifyH("CENTER")

    return cell
end

local function CreateMatrixCell(parent)
    local cell = CreateFrame("Button", nil, parent)
    cell.background = cell:CreateTexture(nil, "BACKGROUND")
    cell.background:SetPoint("TOPLEFT", 0, -1)
    cell.background:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.background:SetTexture(solidTexture)
    cell.background:SetVertexColor(1, 1, 1, 0.01)

    cell.highlight = cell:CreateTexture(nil, "ARTWORK")
    cell.highlight:SetAllPoints(cell.background)
    cell.highlight:SetTexture(solidTexture)
    cell.highlight:SetVertexColor(1, 1, 1, 0.06)
    cell.highlight:Hide()

    cell.value = cell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    cell.value:SetPoint("LEFT", 3, 0)
    cell.value:SetPoint("RIGHT", -3, 0)
    cell.value:SetJustifyH("CENTER")
    cell.value:SetWordWrap(false)

    cell.marker = cell:CreateTexture(nil, "ARTWORK")
    cell.marker:SetSize(11, 11)
    cell.marker:SetPoint("CENTER")
    cell.marker:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cell.marker:SetVertexColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    cell.marker:Hide()

    cell.testedTop = cell:CreateTexture(nil, "OVERLAY")
    cell.testedTop:SetPoint("TOPLEFT", 0, 0)
    cell.testedTop:SetPoint("TOPRIGHT", 0, 0)
    cell.testedTop:SetHeight(1)
    cell.testedTop:SetTexture(solidTexture)
    cell.testedTop:Hide()

    cell.testedBottom = cell:CreateTexture(nil, "OVERLAY")
    cell.testedBottom:SetPoint("BOTTOMLEFT", 0, 0)
    cell.testedBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.testedBottom:SetHeight(1)
    cell.testedBottom:SetTexture(solidTexture)
    cell.testedBottom:Hide()

    cell.testedLeft = cell:CreateTexture(nil, "OVERLAY")
    cell.testedLeft:SetPoint("TOPLEFT", 0, 0)
    cell.testedLeft:SetPoint("BOTTOMLEFT", 0, 0)
    cell.testedLeft:SetWidth(1)
    cell.testedLeft:SetTexture(solidTexture)
    cell.testedLeft:Hide()

    cell.testedRight = cell:CreateTexture(nil, "OVERLAY")
    cell.testedRight:SetPoint("TOPRIGHT", 0, 0)
    cell.testedRight:SetPoint("BOTTOMRIGHT", 0, 0)
    cell.testedRight:SetWidth(1)
    cell.testedRight:SetTexture(solidTexture)
    cell.testedRight:Hide()

    return cell
end

local function CreateMatrixRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(20)

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetTexture(solidTexture)

    row.topBorder = row:CreateTexture(nil, "BORDER")
    row.topBorder:SetPoint("TOPLEFT", 0, 0)
    row.topBorder:SetPoint("TOPRIGHT", 0, 0)
    row.topBorder:SetHeight(1)
    row.topBorder:SetTexture(solidTexture)
    row.topBorder:SetVertexColor(1, 1, 1, 0.04)

    row.bottomBorder = row:CreateTexture(nil, "BORDER")
    row.bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    row.bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    row.bottomBorder:SetHeight(1)
    row.bottomBorder:SetTexture(solidTexture)
    row.bottomBorder:SetVertexColor(0, 0, 0, 0.5)

    row.highlight = row:CreateTexture(nil, "ARTWORK")
    row.highlight:SetAllPoints()
    row.highlight:SetTexture(solidTexture)
    row.highlight:SetVertexColor(1, 1, 1, 0.04)
    row.highlight:Hide()

    row.keyAccent = row:CreateTexture(nil, "ARTWORK")
    row.keyAccent:SetPoint("LEFT", 0, 0)
    row.keyAccent:SetWidth(2)
    row.keyAccent:SetHeight(18)
    row.keyAccent:SetTexture(solidTexture)
    row.keyAccent:Hide()

    row.nameCell = CreateFrame("Button", nil, row)
    row.nameCell.icon = row.nameCell:CreateTexture(nil, "ARTWORK")
    row.nameCell.icon:SetSize(18, 18)
    row.nameCell.icon:SetPoint("LEFT", 4, 0)
    row.nameCell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameCell.label = row.nameCell:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.nameCell.label:SetPoint("LEFT", row.nameCell.icon, "RIGHT", 5, 0)
    row.nameCell.label:SetPoint("RIGHT", -4, 0)
    row.nameCell.label:SetJustifyH("LEFT")
    row.nameCell.label:SetWordWrap(false)

    row.cells = {}
    for index = 1, #timedBucketKeys do
        row.cells[index] = CreateMatrixCell(row)
        row.cells[index].bucketKey = timedBucketKeys[index]
        row.cells[index].row = row
    end

    return row
end

local function BuildBestRunText(record)
    local dungeonProfile = record and record.sortedDungeons and record.sortedDungeons[1]
    if not dungeonProfile or (dungeonProfile.level or 0) <= 0 then
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

local function BuildObservedSourceLabel(sourceLabel, observedAt)
    local ageText = ns:GetDataAgeText(observedAt)
    if ageText and ageText ~= "" then
        return ("%s, %s"):format(sourceLabel, ageText)
    end

    return sourceLabel
end

local function BuildTextureMarkup(texture, size)
    local icon = texture or fallbackSpecTexture
    size = size or 16
    return ("|T%s:%d:%d:0:0|t"):format(icon, size, size)
end

local function BuildRoleSourceLabel(record)
    if record.roleSource == "group" then
        return ns.L.ROLE_SOURCE_GROUP
    elseif record.roleSource == "inspect" then
        return BuildObservedSourceLabel(ns.L.ROLE_SOURCE_INSPECT, record.roleObservedAt)
    elseif record.roleSource == "raiderio" then
        return ns.L.ROLE_SOURCE_RAIDERIO
    elseif record.roleSource == "shared" then
        return BuildObservedSourceLabel(ns.L.ROLE_SOURCE_SHARED, record.roleObservedAt)
    end

    return ns.L.ROLE_SOURCE_UNKNOWN
end

local function BuildSpecSourceLabel(record)
    local label
    if record.specSource == "self" then
        label = ns.L.SPEC_SOURCE_SELF
    elseif record.specSource == "inspect" then
        label = ns.L.SPEC_SOURCE_INSPECT
    elseif record.specSource == "shared" then
        label = ns.L.SPEC_SOURCE_SHARED
    else
        label = ns.L.SPEC_SOURCE_UNKNOWN
    end

    if record.specSource == "inspect" or record.specSource == "shared" then
        label = BuildObservedSourceLabel(label, record.specObservedAt)
    end

    return label
end

local function BuildItemLevelSourceLabel(record)
    local label
    if record.itemLevelSource == "self" then
        label = ns.L.SELF_ITEM_LEVEL
    elseif record.itemLevelSource == "inspect" then
        label = ns.L.INSPECT_ITEM_LEVEL
    elseif record.itemLevelSource == "shared" then
        label = ns.L.ITEM_LEVEL_SOURCE_SHARED
    else
        label = ns.L.UNKNOWN
    end

    if record.itemLevelSource == "inspect" or record.itemLevelSource == "shared" then
        label = BuildObservedSourceLabel(label, record.itemLevelObservedAt)
    end

    return label
end

local function BuildLiveRunMembersText(activity)
    if not activity or type(activity.members) ~= "table" or #activity.members == 0 then
        return ns.L.DETAIL_LIVE_RUN_NONE
    end

    local members = {}
    for index = 1, #activity.members do
        local name, realm = ns:SplitNameRealm(activity.members[index], ns.playerRealm)
        members[#members + 1] = ns:GetDisplayName(name, realm)
    end

    return table.concat(members, ", ")
end

local function BuildLiveRunReportedText(activity)
    if not activity or not activity.senderFullName then
        return ns.L.UNKNOWN
    end

    local name, realm = ns:SplitNameRealm(activity.senderFullName, ns.playerRealm)
    return BuildObservedSourceLabel(ns:GetDisplayName(name, realm), activity.observedAt)
end

local function SetSectionHeight(section, height)
    if not section then
        return
    end

    section:SetShown(height > 0)
    section:SetHeight(height)
end

local function UpdateKeyTabButton(button, isSelected, isEnabled)
    if not button then
        return
    end

    button.isTabEnabled = isEnabled
    button:SetEnabled(isEnabled)

    if isSelected and isEnabled then
        button.background:SetVertexColor(1, 1, 1, 0.08)
        button.topBorder:SetVertexColor(1, 1, 1, 0.16)
        button.selected:SetVertexColor(1, 0.82, 0.12, 0.95)
        button.selected:Show()
        button.text:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    elseif isEnabled then
        button.background:SetVertexColor(1, 1, 1, 0.03)
        button.topBorder:SetVertexColor(1, 1, 1, 0.08)
        button.selected:Hide()
        button.text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    else
        button.background:SetVertexColor(1, 1, 1, 0.015)
        button.topBorder:SetVertexColor(1, 1, 1, 0.04)
        button.selected:Hide()
        button.text:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end
end

local function ShowKeyTabTooltip(owner)
    if not owner or not owner.tooltipText or owner.tooltipText == "" then
        return
    end

    local titleR, titleG, titleB = HIGHLIGHT_FONT_COLOR:GetRGB()
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(owner.tooltipTitle or owner.text:GetText() or "", titleR, titleG, titleB)
    GameTooltip:AddLine(owner.tooltipText, titleR, titleG, titleB, true)
    GameTooltip:Show()
end

local function ShowScoreOverrideTooltip(owner, record)
    if not owner
        or not record
        or record.scoreSource ~= "local"
        or not record.raiderIOHasOverrideScore then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(ns.L.DETAIL_SCORE_OVERRIDE_TITLE)
    GameTooltip:AddLine(ns.L.DETAIL_SCORE_OVERRIDE_TOOLTIP, NORMAL_FONT_COLOR:GetRGB(), true)

    if type(record.raiderIOOriginalScore) == "number" then
        GameTooltip:AddDoubleLine(
            ns.L.DETAIL_SCORE_OVERRIDE_ORIGINAL,
            tostring(record.raiderIOOriginalScore),
            1, 1, 1,
            NORMAL_FONT_COLOR:GetRGB()
        )
    end

    if record.raiderIOHasOverrideDungeonRuns then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.L.DETAIL_SCORE_OVERRIDE_RUNS, NORMAL_FONT_COLOR:GetRGB(), true)
    end

    GameTooltip:Show()
end

local function ResolveActiveKeyTab(detail, canShowTheirKey)
    if detail.activeKeyTab == "their" and canShowTheirKey then
        return "their"
    end

    detail.activeKeyTab = "your"
    return "your"
end

local function OnKeyTabButtonClicked(self)
    local detail = self and self.detail
    if not detail or not self:IsEnabled() or detail.activeKeyTab == self.tabID then
        return
    end

    detail.activeKeyTab = self.tabID
    if detail.panel then
        DetailPanel:Refresh(detail.panel)
    end
end

local function GetDungeonTexture(dungeon)
    if not dungeon then
        return dungeonFallbackTexture
    end

    local cacheKey = dungeon.keystone_instance or dungeon.instance_map_id or dungeon.id or dungeon.name
    if dungeonTextureCache[cacheKey] then
        return dungeonTextureCache[cacheKey]
    end

    local texture
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local _, _, _, mapTexture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(dungeon.keystone_instance or dungeon.instance_map_id or 0)
        texture = mapTexture or backgroundTexture
    end

    texture = texture or dungeonFallbackTexture
    dungeonTextureCache[cacheKey] = texture
    return texture
end

local function GetDungeonBucketKey(level)
    if not level or level <= 0 then
        return nil
    elseif level >= 20 then
        return "timed20"
    elseif level >= 15 then
        return "timed15"
    elseif level >= 11 then
        return "timed11_14"
    elseif level >= 9 then
        return "timed9_10"
    elseif level >= 4 then
        return "timed4_8"
    end

    return "timed2_3"
end

local function DoesDungeonMeetBucket(dungeonProfile, bucketKey)
    if not dungeonProfile or (dungeonProfile.chests or 0) <= 0 then
        return false
    end

    local minimumLevel = timedBucketMinimumLevels[bucketKey]
    return minimumLevel ~= nil and (dungeonProfile.level or 0) >= minimumLevel
end

local function SetMatrixCellTested(cell, isTested)
    if not cell then
        return
    end

    local testedR, testedG, testedB = 1, 0.82, 0.12
    cell.testedTop:SetVertexColor(testedR, testedG, testedB, isTested and 0.95 or 0)
    cell.testedBottom:SetVertexColor(testedR, testedG, testedB, isTested and 0.95 or 0)
    cell.testedLeft:SetVertexColor(testedR, testedG, testedB, isTested and 0.95 or 0)
    cell.testedRight:SetVertexColor(testedR, testedG, testedB, isTested and 0.95 or 0)

    if isTested then
        cell.testedTop:Show()
        cell.testedBottom:Show()
        cell.testedLeft:Show()
        cell.testedRight:Show()
    else
        cell.testedTop:Hide()
        cell.testedBottom:Hide()
        cell.testedLeft:Hide()
        cell.testedRight:Hide()
    end
end

local function GetRunStatusLabel(chests)
    local L = ns.L
    if (chests or 0) >= 3 then
        return L.DETAIL_RUN_PLUS_THREE
    elseif (chests or 0) >= 2 then
        return L.DETAIL_RUN_PLUS_TWO
    elseif (chests or 0) >= 1 then
        return L.DETAIL_RUN_TIMED
    end

    return L.DETAIL_RUN_COMPLETED
end

local function GetRunStatusColor(chests)
    if (chests or 0) >= 2 then
        return GREEN_FONT_COLOR
    elseif (chests or 0) >= 1 then
        return HIGHLIGHT_FONT_COLOR
    end

    return GRAY_FONT_COLOR
end

local function BuildRaiderIORunText(level, chests)
    if not level or level <= 0 then
        return ns.L.DETAIL_NO_RECORDED_RUN
    end

    local plusPrefix = ""
    if (chests or 0) >= 3 then
        plusPrefix = "+++"
    elseif (chests or 0) >= 2 then
        plusPrefix = "++"
    elseif (chests or 0) >= 1 then
        plusPrefix = "+"
    end

    if (chests or 0) <= 0 then
        return tostring(level)
    end

    return ("%s%d %s"):format(plusPrefix, level, ns.L.DETAIL_RUN_TIMED)
end

local function BuildRunSummaryText(dungeonProfile)
    if not dungeonProfile or (dungeonProfile.level or 0) <= 0 then
        return ns.L.DETAIL_NO_RECORDED_RUN
    end

    return BuildRaiderIORunText(dungeonProfile.level or 0, dungeonProfile.chests or 0)
end

local function GetKeystoneLevelColor(level)
    if level and C_ChallengeMode and C_ChallengeMode.GetKeystoneLevelRarityColor then
        local color = C_ChallengeMode.GetKeystoneLevelRarityColor(level)
        if color then
            return color
        end
    end

    return HIGHLIGHT_FONT_COLOR
end

local function BuildKeystoneDisplayText(texture, level, mapName)
    return ("%s +%d %s"):format(
        BuildTextureMarkup(texture or dungeonFallbackTexture, 16),
        level or 0,
        mapName or ns.L.UNKNOWN
    )
end

local function FindDungeonProfile(record, mapID)
    if not record or not mapID then
        return nil
    end

    for index = 1, #(record.sortedDungeons or {}) do
        local dungeonProfile = record.sortedDungeons[index]
        local dungeon = dungeonProfile and dungeonProfile.dungeon
        if dungeon and (
            dungeon.keystone_instance == mapID
            or dungeon.id == mapID
            or dungeon.instance_map_id == mapID
            or dungeon.index == mapID
        ) then
            return dungeonProfile
        end
    end

    return nil
end

local function GetDungeonScoreThreshold(level)
    local scoreData = level and dungeonScoreThresholds[level]
    if scoreData then
        return scoreData[1], scoreData[2]
    end

    if level and level > 39 and dungeonScoreThresholds[39] then
        return dungeonScoreThresholds[39][1] + ((level - 39) * 15), dungeonScoreThresholds[39][2]
    end

    return nil, nil
end

local function HasPreciseFractionalTime(dungeonProfile)
    local fractionalTime = dungeonProfile and dungeonProfile.fractionalTime
    return type(fractionalTime) == "number" and fractionalTime ~= math.floor(fractionalTime)
end

local function GetProjectedDungeonScore(level, fractionalTime, forceResult)
    local justInTimeScore, justOutOfTimeScore = GetDungeonScoreThreshold(level)
    if not justInTimeScore then
        return 0
    end

    if forceResult == "timed" then
        return justInTimeScore
    elseif forceResult == "completed" then
        return justOutOfTimeScore or 0
    end

    if type(fractionalTime) ~= "number" then
        return justInTimeScore
    end

    if fractionalTime <= 1 then
        return justInTimeScore + (math.min(0.4, 1 - fractionalTime) * 37.5)
    elseif fractionalTime < 1.4 then
        return justInTimeScore - 15 + ((1 - fractionalTime) * 37.5)
    end

    return 0
end

local function GetBestDungeonScore(bestProfile)
    if not bestProfile or (bestProfile.level or 0) <= 0 then
        return 0
    end

    if HasPreciseFractionalTime(bestProfile) then
        return GetProjectedDungeonScore(bestProfile.level, bestProfile.fractionalTime)
    end

    if (bestProfile.chests or 0) > 0 then
        return GetProjectedDungeonScore(bestProfile.level, nil, "timed")
    end

    return GetProjectedDungeonScore(bestProfile.level, nil, "completed")
end

local function GetKeyScoreImpact(bestProfile, targetLevel, isTimed)
    if not targetLevel then
        return 0
    end

    local candidateScore = GetProjectedDungeonScore(targetLevel, nil, isTimed and "timed" or "completed")
    local currentScore = GetBestDungeonScore(bestProfile)
    return math.max(0, candidateScore - currentScore)
end

local function BuildKeyScoreImpactText(bestProfile, targetLevel, isTimed)
    local impact = ns:Round(GetKeyScoreImpact(bestProfile, targetLevel, isTimed))
    if impact <= 0 then
        return ns.L.DETAIL_KEY_NO_SCORE_CHANGE
    end

    return ("%+d"):format(impact)
end

local function GetKeyScoreImpactColor(bestProfile, targetLevel, isTimed)
    if ns:Round(GetKeyScoreImpact(bestProfile, targetLevel, isTimed)) > 0 then
        return GREEN_FONT_COLOR
    end

    return GRAY_FONT_COLOR
end

function DetailPanel:GetReportedKeyScoreImpact(record, reportedKey, isTimed)
    if not record
        or type(reportedKey) ~= "table"
        or not reportedKey.mapID
        or not reportedKey.level then
        return 0
    end

    local bestProfile = FindDungeonProfile(record, reportedKey.mapID)
    return ns:Round(GetKeyScoreImpact(bestProfile, reportedKey.level, isTimed ~= false))
end

local function BuildCurrentKeyStatusLabel(status)
    local L = ns.L
    if status == "plus3" then
        return L.DETAIL_KEY_STATUS_PLUS_THREE
    elseif status == "plus2" then
        return L.DETAIL_KEY_STATUS_PLUS_TWO
    elseif status == "timed" then
        return L.DETAIL_KEY_STATUS_TIMED
    elseif status == "completed" then
        return L.DETAIL_KEY_STATUS_COMPLETED
    end

    return L.DETAIL_KEY_STATUS_NONE
end

local function ShowTimedBucketHeaderTooltip(owner, bucketKey)
    if not owner or not bucketKey then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(ns:GetTimedBucketLabel(bucketKey))
    local bucketName = ns.GetTimedBucketName and ns:GetTimedBucketName(bucketKey)
    if bucketName then
        GameTooltip:AddLine(bucketName, HIGHLIGHT_FONT_COLOR:GetRGB())
    end
    GameTooltip:Show()
end

local function ShowDungeonCellTooltip(owner, row, bucketKey)
    if not owner or not row then
        return
    end

    local dungeonProfile = row.dungeonProfile
    local dungeon = dungeonProfile and dungeonProfile.dungeon
    if not dungeon then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(dungeon.name or dungeon.shortNameLocale or dungeon.shortName or DUNGEONS)

    local bestBucketKey = GetDungeonBucketKey(dungeonProfile.level)
    local selectedBucketKey = row.keyContext and row.keyContext.level and GetDungeonBucketKey(row.keyContext.level) or nil
    local hasBucketNote = false

    if (dungeonProfile.level or 0) > 0 then
        GameTooltip:AddDoubleLine(ns.L.DETAIL_BEST_RUN, BuildRunSummaryText(dungeonProfile), 1, 1, 1, GetRunStatusColor(dungeonProfile.chests or 0):GetRGB())
        GameTooltip:AddDoubleLine(ns.L.STATUS_TEXT, GetRunStatusLabel(dungeonProfile.chests or 0), 1, 1, 1, 1, 1, 1)

        if bucketKey and bucketKey ~= bestBucketKey and DoesDungeonMeetBucket(dungeonProfile, bucketKey) then
            local bucketR, bucketG, bucketB = NORMAL_FONT_COLOR:GetRGB()
            GameTooltip:AddLine(ns.L.DETAIL_DUNGEON_BUCKET_COVERED:format(ns:GetTimedBucketLabel(bucketKey)), bucketR, bucketG, bucketB, true)
            hasBucketNote = true
        end
    else
        GameTooltip:AddLine(ns.L.DETAIL_NO_RECORDED_RUN, GRAY_FONT_COLOR:GetRGB())
    end

    if bucketKey and row.isCurrentKeyRow and bucketKey == selectedBucketKey then
        if hasBucketNote then
            GameTooltip:AddLine(" ")
        end
        GameTooltip:AddLine(ns.L.DETAIL_DUNGEON_BUCKET_SELECTED_KEY, 1, 0.82, 0.12, true)
    end

    GameTooltip:Show()
end

local function ShowHeroInfoTooltip(owner, record)
    if not owner or not record then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(ns:GetRecordDisplayName(record))
    GameTooltip:AddDoubleLine(ns.L.SOURCE, GetSourceLabel(record), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(ns.L.PROFILE_STATE, BuildProfileStateLabel(record), 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
end

local function ShowHeroRoleTooltip(owner, record)
    if not owner or not record then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(ns:GetRoleLabel(record.roleBucket))
    GameTooltip:AddLine(BuildRoleSourceLabel(record), NORMAL_FONT_COLOR:GetRGB(), true)
    GameTooltip:Show()
end

function DetailPanel:Create(frame)
    if not frame or frame.detail then
        return frame and frame.detail
    end

    frame.detail = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.detail:SetPoint("TOPRIGHT", -8, -92)
    frame.detail:SetPoint("BOTTOMRIGHT", -8, 4)
    frame.detail:SetWidth(312)
    if frame.detail.SetClipsChildren then
        frame.detail:SetClipsChildren(true)
    end

    local detail = frame.detail

    detail.background = detail:CreateTexture(nil, "BACKGROUND")
    detail.background:SetPoint("TOPLEFT", 3, -3)
    detail.background:SetPoint("BOTTOMRIGHT", -3, 3)
    detail.background:SetTexture(panelBackgroundTexture)
    detail.background:SetVertexColor(0.92, 0.9, 0.84)
    detail.background:SetAlpha(0.92)

    detail.noise = detail:CreateTexture(nil, "BORDER")
    detail.noise:SetAllPoints(detail.background)
    detail.noise:SetTexture(panelShadowTexture)
    detail.noise:SetAlpha(0.18)
    if detail.noise.SetHorizTile then
        detail.noise:SetHorizTile(false)
        detail.noise:SetVertTile(false)
    end

    detail.warmWash = detail:CreateTexture(nil, "ARTWORK")
    detail.warmWash:SetAllPoints(detail.background)
    detail.warmWash:SetTexture(solidTexture)
    detail.warmWash:SetVertexColor(0.62, 0.55, 0.42, 0.08)

    detail.marbleDetail = detail:CreateTexture(nil, "ARTWORK")
    detail.marbleDetail:SetAllPoints(detail.background)
    detail.marbleDetail:SetTexture(marbleTexture)
    detail.marbleDetail:SetAlpha(0.12)
    if detail.marbleDetail.SetHorizTile then
        detail.marbleDetail:SetHorizTile(true)
        detail.marbleDetail:SetVertTile(true)
    end

    detail.topGlow = detail:CreateTexture(nil, "ARTWORK")
    detail.topGlow:SetPoint("TOPLEFT", detail.background, "TOPLEFT", 0, 0)
    detail.topGlow:SetPoint("TOPRIGHT", detail.background, "TOPRIGHT", 0, 0)
    detail.topGlow:SetHeight(56)
    detail.topGlow:SetTexture(solidTexture)
    detail.topGlow:SetVertexColor(0.96, 0.92, 0.8, 0.05)

    detail.bottomShade = detail:CreateTexture(nil, "ARTWORK")
    detail.bottomShade:SetPoint("BOTTOMLEFT", detail.background, "BOTTOMLEFT", 0, 0)
    detail.bottomShade:SetPoint("BOTTOMRIGHT", detail.background, "BOTTOMRIGHT", 0, 0)
    detail.bottomShade:SetHeight(72)
    detail.bottomShade:SetTexture(solidTexture)
    detail.bottomShade:SetVertexColor(0, 0, 0, 0.06)

    detail.leftShade = detail:CreateTexture(nil, "ARTWORK")
    detail.leftShade:SetPoint("TOPLEFT", 1, -1)
    detail.leftShade:SetPoint("BOTTOMLEFT", 1, 1)
    detail.leftShade:SetWidth(1)
    detail.leftShade:SetTexture(solidTexture)
    detail.leftShade:SetVertexColor(1, 1, 1, 0.025)

    detail.rightShade = detail:CreateTexture(nil, "ARTWORK")
    detail.rightShade:SetPoint("TOPRIGHT", -1, -1)
    detail.rightShade:SetPoint("BOTTOMRIGHT", -1, 1)
    detail.rightShade:SetWidth(1)
    detail.rightShade:SetTexture(solidTexture)
    detail.rightShade:SetVertexColor(0, 0, 0, 0.025)

    detail.hero = CreateFrame("Frame", nil, detail)
    detail.hero.background = detail.hero:CreateTexture(nil, "BACKGROUND")
    detail.hero.background:SetAllPoints()
    detail.hero.background:SetTexture(panelBackgroundTexture)
    detail.hero.background:SetAlpha(0)

    detail.hero.marble = detail.hero:CreateTexture(nil, "ARTWORK")
    detail.hero.marble:SetAllPoints()
    detail.hero.marble:SetTexture(marbleTexture)
    detail.hero.marble:SetAlpha(0)
    if detail.hero.marble.SetHorizTile then
        detail.hero.marble:SetHorizTile(true)
        detail.hero.marble:SetVertTile(true)
    end

    detail.hero.tint = detail.hero:CreateTexture(nil, "ARTWORK")
    detail.hero.tint:SetAllPoints()
    detail.hero.tint:SetTexture(solidTexture)
    detail.hero.tint:SetVertexColor(1, 1, 1, 0)

    detail.hero.topAccent = detail.hero:CreateTexture(nil, "OVERLAY")
    detail.hero.topAccent:SetPoint("TOPLEFT", 0, 0)
    detail.hero.topAccent:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.topAccent:SetHeight(2)
    detail.hero.topAccent:SetTexture(solidTexture)
    detail.hero.topAccent:SetVertexColor(1, 1, 1, 0)

    detail.hero.topBorder = CreateBorder(detail.hero, "TOPLEFT", "TOPRIGHT", nil, 1)
    detail.hero.bottomBorder = CreateBorder(detail.hero, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    detail.hero.leftBorder = CreateBorder(detail.hero, "TOPLEFT", "BOTTOMLEFT", 1, nil)
    detail.hero.rightBorder = CreateBorder(detail.hero, "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
    detail.hero.topBorder:Hide()
    detail.hero.bottomBorder:Hide()
    detail.hero.leftBorder:Hide()
    detail.hero.rightBorder:Hide()

    detail.hero.nameRibbon = CreateFrame("Frame", nil, detail.hero)
    detail.hero.nameRibbon.shadow = detail.hero.nameRibbon:CreateTexture(nil, "BACKGROUND")
    detail.hero.nameRibbon.shadow:SetPoint("TOPLEFT", 1, -1)
    detail.hero.nameRibbon.shadow:SetPoint("BOTTOMRIGHT", 1, -1)
    detail.hero.nameRibbon.shadow:SetTexture(solidTexture)
    detail.hero.nameRibbon.shadow:SetVertexColor(0, 0, 0, 0.14)

    detail.hero.nameRibbon.background = detail.hero.nameRibbon:CreateTexture(nil, "ARTWORK")
    detail.hero.nameRibbon.background:SetAllPoints()
    detail.hero.nameRibbon.background:SetTexture(solidTexture)
    detail.hero.nameRibbon.background:SetVertexColor(1, 1, 1, 0.1)

    detail.hero.nameRibbon.topEdge = detail.hero.nameRibbon:CreateTexture(nil, "OVERLAY")
    detail.hero.nameRibbon.topEdge:SetPoint("TOPLEFT", 0, 0)
    detail.hero.nameRibbon.topEdge:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.nameRibbon.topEdge:SetHeight(1)
    detail.hero.nameRibbon.topEdge:SetTexture(solidTexture)
    detail.hero.nameRibbon.topEdge:SetVertexColor(1, 1, 1, 0.16)

    detail.hero.nameRibbon.bottomEdge = detail.hero.nameRibbon:CreateTexture(nil, "OVERLAY")
    detail.hero.nameRibbon.bottomEdge:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.nameRibbon.bottomEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.hero.nameRibbon.bottomEdge:SetHeight(1)
    detail.hero.nameRibbon.bottomEdge:SetTexture(solidTexture)
    detail.hero.nameRibbon.bottomEdge:SetVertexColor(0, 0, 0, 0.55)

    detail.hero.nameRibbon.leftCap = detail.hero.nameRibbon:CreateTexture(nil, "BORDER")
    detail.hero.nameRibbon.leftCap:SetPoint("TOPLEFT", 0, 0)
    detail.hero.nameRibbon.leftCap:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.nameRibbon.leftCap:SetWidth(2)
    detail.hero.nameRibbon.leftCap:SetTexture(solidTexture)
    detail.hero.nameRibbon.leftCap:SetVertexColor(1, 1, 1, 0.3)

    detail.hero.nameRibbon.rightCap = detail.hero.nameRibbon:CreateTexture(nil, "BORDER")
    detail.hero.nameRibbon.rightCap:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.nameRibbon.rightCap:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.hero.nameRibbon.rightCap:SetWidth(1)
    detail.hero.nameRibbon.rightCap:SetTexture(solidTexture)
    detail.hero.nameRibbon.rightCap:SetVertexColor(1, 1, 1, 0.08)

    detail.hero.name = detail.hero.nameRibbon:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Large")
    detail.hero.name:SetJustifyH("LEFT")
    detail.hero.name:SetWordWrap(false)

    detail.hero.roleBadge = CreateFrame("Button", nil, detail.hero.nameRibbon)
    detail.hero.roleBadge:SetSize(14, 14)
    detail.hero.roleBadge.background = detail.hero.roleBadge:CreateTexture(nil, "BACKGROUND")
    detail.hero.roleBadge.background:SetAllPoints()
    detail.hero.roleBadge.background:SetTexture(solidTexture)
    detail.hero.roleBadge.background:SetVertexColor(1, 1, 1, 0)
    detail.hero.roleBadge.topBorder = detail.hero.roleBadge:CreateTexture(nil, "BORDER")
    detail.hero.roleBadge.topBorder:SetPoint("TOPLEFT", 0, 0)
    detail.hero.roleBadge.topBorder:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.roleBadge.topBorder:SetHeight(1)
    detail.hero.roleBadge.topBorder:SetTexture(solidTexture)
    detail.hero.roleBadge.topBorder:SetVertexColor(1, 1, 1, 0)
    detail.hero.roleBadge.bottomBorder = detail.hero.roleBadge:CreateTexture(nil, "BORDER")
    detail.hero.roleBadge.bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.roleBadge.bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.hero.roleBadge.bottomBorder:SetHeight(1)
    detail.hero.roleBadge.bottomBorder:SetTexture(solidTexture)
    detail.hero.roleBadge.bottomBorder:SetVertexColor(0, 0, 0, 0)
    detail.hero.roleBadge.leftBorder = detail.hero.roleBadge:CreateTexture(nil, "BORDER")
    detail.hero.roleBadge.leftBorder:SetPoint("TOPLEFT", 0, 0)
    detail.hero.roleBadge.leftBorder:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.roleBadge.leftBorder:SetWidth(1)
    detail.hero.roleBadge.leftBorder:SetTexture(solidTexture)
    detail.hero.roleBadge.leftBorder:SetVertexColor(1, 1, 1, 0)
    detail.hero.roleBadge.rightBorder = detail.hero.roleBadge:CreateTexture(nil, "BORDER")
    detail.hero.roleBadge.rightBorder:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.roleBadge.rightBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.hero.roleBadge.rightBorder:SetWidth(1)
    detail.hero.roleBadge.rightBorder:SetTexture(solidTexture)
    detail.hero.roleBadge.rightBorder:SetVertexColor(1, 1, 1, 0)
    detail.hero.roleBadge.highlight = detail.hero.roleBadge:CreateTexture(nil, "HIGHLIGHT")
    detail.hero.roleBadge.highlight:SetAllPoints()
    detail.hero.roleBadge.highlight:SetTexture(solidTexture)
    detail.hero.roleBadge.highlight:SetVertexColor(1, 1, 1, 0.08)
    detail.hero.roleBadge.icon = detail.hero.roleBadge:CreateTexture(nil, "ARTWORK")
    detail.hero.roleBadge.icon:SetPoint("CENTER")
    detail.hero.roleBadge.icon:SetSize(14, 14)
    detail.hero.roleBadge:SetScript("OnEnter", function(self)
        ShowHeroRoleTooltip(self, self.record)
    end)
    detail.hero.roleBadge:SetScript("OnLeave", GameTooltip_Hide)

    detail.hero.meta = detail.hero:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.hero.meta:SetPoint("TOPLEFT", detail.hero.name, "BOTTOMLEFT", 0, -4)
    detail.hero.meta:SetJustifyH("LEFT")
    detail.hero.meta:Hide()

    detail.hero.scorePlate = CreateFrame("Frame", nil, detail.hero)
    detail.hero.scorePlate.background = detail.hero.scorePlate:CreateTexture(nil, "BACKGROUND")
    detail.hero.scorePlate.background:SetAllPoints()
    detail.hero.scorePlate.background:SetTexture(solidTexture)
    detail.hero.scorePlate.background:SetVertexColor(0.12, 0.11, 0.1, 0.24)

    detail.hero.scorePlate.glow = detail.hero.scorePlate:CreateTexture(nil, "ARTWORK")
    detail.hero.scorePlate.glow:SetPoint("TOPLEFT", 1, -1)
    detail.hero.scorePlate.glow:SetPoint("BOTTOMRIGHT", -1, 1)
    detail.hero.scorePlate.glow:SetTexture(solidTexture)
    detail.hero.scorePlate.glow:SetVertexColor(1, 1, 1, 0.02)

    detail.hero.scorePlate.sideAccent = detail.hero.scorePlate:CreateTexture(nil, "ARTWORK")
    detail.hero.scorePlate.sideAccent:SetPoint("TOPLEFT", 0, 0)
    detail.hero.scorePlate.sideAccent:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.scorePlate.sideAccent:SetWidth(3)
    detail.hero.scorePlate.sideAccent:SetTexture(solidTexture)
    detail.hero.scorePlate.sideAccent:SetVertexColor(1, 1, 1, 0.85)

    detail.hero.scorePlate.topEdge = detail.hero.scorePlate:CreateTexture(nil, "OVERLAY")
    detail.hero.scorePlate.topEdge:SetPoint("TOPLEFT", 0, 0)
    detail.hero.scorePlate.topEdge:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.scorePlate.topEdge:SetHeight(1)
    detail.hero.scorePlate.topEdge:SetTexture(solidTexture)
    detail.hero.scorePlate.topEdge:SetVertexColor(1, 1, 1, 0.06)

    detail.hero.scorePlate.bottomEdge = detail.hero.scorePlate:CreateTexture(nil, "OVERLAY")
    detail.hero.scorePlate.bottomEdge:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.scorePlate.bottomEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.hero.scorePlate.bottomEdge:SetHeight(1)
    detail.hero.scorePlate.bottomEdge:SetTexture(solidTexture)
    detail.hero.scorePlate.bottomEdge:SetVertexColor(0, 0, 0, 0.22)

    detail.hero.scorePlate.leftEdge = detail.hero.scorePlate:CreateTexture(nil, "OVERLAY")
    detail.hero.scorePlate.leftEdge:SetPoint("TOPLEFT", 0, 0)
    detail.hero.scorePlate.leftEdge:SetPoint("BOTTOMLEFT", 0, 0)
    detail.hero.scorePlate.leftEdge:SetWidth(1)
    detail.hero.scorePlate.leftEdge:SetTexture(solidTexture)
    detail.hero.scorePlate.leftEdge:SetVertexColor(1, 1, 1, 0.03)

    detail.hero.scorePlate.rightEdge = detail.hero.scorePlate:CreateTexture(nil, "OVERLAY")
    detail.hero.scorePlate.rightEdge:SetPoint("TOPRIGHT", 0, 0)
    detail.hero.scorePlate.rightEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.hero.scorePlate.rightEdge:SetWidth(1)
    detail.hero.scorePlate.rightEdge:SetTexture(solidTexture)
    detail.hero.scorePlate.rightEdge:SetVertexColor(1, 1, 1, 0.03)

    detail.hero.scoreLabel = detail.hero.scorePlate:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.hero.scoreLabel:SetJustifyH("CENTER")
    detail.hero.scoreLabel:SetText(ns.L.DETAIL_SCORE)
    detail.hero.scoreLabel:SetTextColor(NORMAL_FONT_COLOR:GetRGB())

    detail.hero.scoreWarningButton = CreateFrame("Button", nil, detail.hero.scorePlate)
    detail.hero.scoreWarningButton:SetSize(14, 14)
    if detail.hero.scoreWarningButton.SetMotionScriptsWhileDisabled then
        detail.hero.scoreWarningButton:SetMotionScriptsWhileDisabled(true)
    end
    if detail.hero.scoreWarningButton.SetHitRectInsets then
        detail.hero.scoreWarningButton:SetHitRectInsets(-4, -4, -4, -4)
    end
    detail.hero.scoreWarningButton.icon = detail.hero.scoreWarningButton:CreateTexture(nil, "ARTWORK")
    detail.hero.scoreWarningButton.icon:SetAllPoints()
    detail.hero.scoreWarningButton.icon:SetAtlas(warningIconAtlas, true)
    detail.hero.scoreWarningButton.icon:SetVertexColor(1, 0.82, 0.12, 1)
    detail.hero.scoreWarningButton:SetScript("OnEnter", function(self)
        ShowScoreOverrideTooltip(self, self.record)
    end)
    detail.hero.scoreWarningButton:SetScript("OnLeave", GameTooltip_Hide)
    detail.hero.scoreWarningButton:Hide()

    detail.hero.scoreValue = detail.hero.scorePlate:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Huge3")
    detail.hero.scoreValue:SetJustifyH("CENTER")
    detail.hero.scoreValue:SetWordWrap(false)

    detail.hero.bestRun = detail.hero:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    detail.hero.bestRun:SetPoint("TOPLEFT", detail.hero.scoreValue, "BOTTOMLEFT", 0, -8)
    detail.hero.bestRun:SetJustifyH("LEFT")
    detail.hero.bestRun:Hide()

    detail.hero.mainScore = detail.hero.scorePlate:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.hero.mainScore:SetJustifyH("CENTER")

    detail.hero.infoButton = CreateFrame("Button", nil, detail.hero.nameRibbon)
    detail.hero.infoButton:SetSize(16, 16)
    detail.hero.infoButton:SetNormalTexture("Interface\\Common\\help-i")
    detail.hero.infoButton:SetHighlightTexture("Interface\\Common\\help-i", "ADD")
    detail.hero.infoButton:SetPushedTexture("Interface\\Common\\help-i")
    detail.hero.infoButton:GetNormalTexture():SetAllPoints()
    detail.hero.infoButton:GetHighlightTexture():SetAllPoints()
    detail.hero.infoButton:GetHighlightTexture():SetAlpha(0.2)
    detail.hero.infoButton:GetPushedTexture():SetAllPoints()
    detail.hero.infoButton:GetPushedTexture():SetVertexColor(0.9, 0.9, 0.9, 1)
    detail.hero.infoButton:SetScript("OnEnter", function(self)
        ShowHeroInfoTooltip(self, self.record)
    end)
    detail.hero.infoButton:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
    end)

    detail.hero.emptyState = detail.hero:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
    detail.hero.emptyState:SetPoint("CENTER")
    detail.hero.emptyState:SetJustifyH("CENTER")
    detail.hero.emptyState:SetText(ns.L.NO_SELECTION)
    detail.hero.emptyState:Hide()

    detail.summarySection = CreateSection(detail, ns.L.DETAIL_CHARACTER)
    detail.summaryRows = {
        CreateValueRow(detail.summarySection, ns.L.SPEC),
        CreateValueRow(detail.summarySection, ns.L.ITEM_LEVEL),
        CreateValueRow(detail.summarySection, ns.L.DETAIL_REPORTED_KEY)
    }

    detail.summaryRows[1]:SetPoint("TOPLEFT", detail.summarySection.divider, "BOTTOMLEFT", 0, -6)
    detail.summaryRows[2]:SetPoint("TOPLEFT", detail.summaryRows[1], "BOTTOMLEFT", 0, -4)
    detail.summaryRows[3]:SetPoint("TOPLEFT", detail.summaryRows[2], "BOTTOMLEFT", 0, -4)

    detail.liveRunSection = CreateSection(detail, ns.L.DETAIL_LIVE_RUN)
    detail.liveRunRows = {
        CreateValueRow(detail.liveRunSection, ns.L.DETAIL_LIVE_RUN_KEY),
        CreateValueRow(detail.liveRunSection, ns.L.DETAIL_LIVE_RUN_MEMBERS),
        CreateValueRow(detail.liveRunSection, ns.L.DETAIL_LIVE_RUN_REPORTED)
    }

    detail.liveRunRows[1]:SetPoint("TOPLEFT", detail.liveRunSection.divider, "BOTTOMLEFT", 0, -6)
    detail.liveRunRows[2]:SetPoint("TOPLEFT", detail.liveRunRows[1], "BOTTOMLEFT", 0, -4)
    detail.liveRunRows[3]:SetPoint("TOPLEFT", detail.liveRunRows[2], "BOTTOMLEFT", 0, -4)

    detail.keySection = CreateSection(detail, ns.L.DETAIL_AVAILABLE_KEYS)
    detail.keyTabBar = CreateFrame("Frame", nil, detail.keySection)
    detail.keyTabBar:SetHeight(20)
    detail.keyTabBar.buttons = {
        CreateKeyTabButton(detail.keyTabBar, ns.L.DETAIL_YOUR_KEY, "your"),
        CreateKeyTabButton(detail.keyTabBar, ns.L.DETAIL_THEIR_KEY, "their")
    }
    detail.keyTabs = {
        your = detail.keyTabBar.buttons[1],
        their = detail.keyTabBar.buttons[2]
    }
    detail.keyTabInfoButtons = {
        your = CreateInlineInfoButton(detail.keyTabBar),
        their = CreateInlineInfoButton(detail.keyTabBar)
    }

    for index = 1, #detail.keyTabBar.buttons do
        local button = detail.keyTabBar.buttons[index]
        button.detail = detail
        button:SetScript("OnClick", OnKeyTabButtonClicked)
        button:SetScript("OnEnter", function(self)
            ShowKeyTabTooltip(self)
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end

    for _, infoButton in pairs(detail.keyTabInfoButtons) do
        infoButton:SetScript("OnEnter", function(self)
            ShowKeyTabTooltip(self)
        end)
        infoButton:SetScript("OnLeave", GameTooltip_Hide)
    end

    detail.keyCard = CreateFrame("Frame", nil, detail.keySection)
    detail.keyCard.background = detail.keyCard:CreateTexture(nil, "BACKGROUND")
    detail.keyCard.background:SetAllPoints()
    detail.keyCard.background:SetTexture(solidTexture)
    detail.keyCard.background:SetVertexColor(1, 1, 1, 0.03)

    detail.keyCard.topAccent = detail.keyCard:CreateTexture(nil, "BORDER")
    detail.keyCard.topAccent:SetPoint("TOPLEFT", 0, 0)
    detail.keyCard.topAccent:SetPoint("TOPRIGHT", 0, 0)
    detail.keyCard.topAccent:SetHeight(1)
    detail.keyCard.topAccent:SetTexture(solidTexture)
    detail.keyCard.topAccent:SetVertexColor(1, 1, 1, 0.14)

    detail.keyCard.bottomBorder = detail.keyCard:CreateTexture(nil, "BORDER")
    detail.keyCard.bottomBorder:SetPoint("BOTTOMLEFT", 0, 0)
    detail.keyCard.bottomBorder:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.keyCard.bottomBorder:SetHeight(1)
    detail.keyCard.bottomBorder:SetTexture(solidTexture)
    detail.keyCard.bottomBorder:SetVertexColor(0, 0, 0, 0.6)

    detail.keyCard.icon = detail.keyCard:CreateTexture(nil, "ARTWORK")
    detail.keyCard.icon:SetSize(22, 22)
    detail.keyCard.icon:SetPoint("TOPLEFT", 8, -8)
    detail.keyCard.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    detail.keyCard.name = detail.keyCard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    detail.keyCard.name:SetPoint("TOPLEFT", detail.keyCard.icon, "TOPRIGHT", 6, 0)
    detail.keyCard.name:SetJustifyH("LEFT")

    detail.keyCard.level = detail.keyCard:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detail.keyCard.level:SetPoint("TOPLEFT", detail.keyCard.name, "BOTTOMLEFT", 0, -2)
    detail.keyCard.level:SetJustifyH("LEFT")

    detail.keyRows = {
        CreateValueRow(detail.keyCard, ns.L.DETAIL_KEY_BEST_DUNGEON),
        CreateValueRow(detail.keyCard, ns.L.DETAIL_KEY_AT_LEVEL),
        CreateValueRow(detail.keyCard, ns.L.DETAIL_KEY_IF_TIMED),
        CreateValueRow(detail.keyCard, ns.L.DETAIL_KEY_IF_COMPLETED)
    }

    detail.keyRows[1]:SetPoint("TOPLEFT", detail.keyCard.icon, "BOTTOMLEFT", 0, -8)
    detail.keyRows[2]:SetPoint("TOPLEFT", detail.keyRows[1], "BOTTOMLEFT", 0, -4)
    detail.keyRows[3]:SetPoint("TOPLEFT", detail.keyRows[2], "BOTTOMLEFT", 0, -4)
    detail.keyRows[4]:SetPoint("TOPLEFT", detail.keyRows[3], "BOTTOMLEFT", 0, -4)

    detail.keyEmpty = detail.keySection:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    detail.keyEmpty:SetPoint("TOPLEFT", detail.keyTabBar, "BOTTOMLEFT", 0, -6)
    detail.keyEmpty:SetJustifyH("LEFT")
    detail.keyEmpty:SetText(ns.L.NO_CURRENT_KEY)

    detail.dungeonSection = CreateSection(detail, ns.L.DETAIL_DUNGEON_EXPERIENCE)
    detail.dungeonHeader = CreateFrame("Frame", nil, detail.dungeonSection)
    detail.dungeonHeader:SetHeight(20)
    detail.dungeonHeader.name = CreateHeaderCell(detail.dungeonHeader)
    detail.dungeonHeader.name.label:SetText(DUNGEONS)

    detail.dungeonHeader.bucketCells = {}
    for index = 1, #timedBucketKeys do
        local cell = CreateHeaderCell(detail.dungeonHeader)
        cell.bucketKey = timedBucketKeys[index]
        local iconTexture = ns:GetTimedBucketIcon(timedBucketKeys[index])
        if iconTexture then
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(12, 12)
            cell.icon:SetPoint("CENTER")
            cell.icon:SetTexture(iconTexture)
        else
            cell.label:SetText(ns:GetTimedBucketLabel(timedBucketKeys[index]))
        end
        cell:SetScript("OnEnter", function(self)
            ShowTimedBucketHeaderTooltip(self, self.bucketKey)
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)
        detail.dungeonHeader.bucketCells[index] = cell
    end

    detail.dungeonRows = {}
    for index = 1, 8 do
        local row = CreateMatrixRow(detail.dungeonSection)
        row.index = index
        row.nameCell.row = row
        row.nameCell:SetScript("OnEnter", function(self)
            if self.row then
                self.row.highlight:Show()
            end
            ShowDungeonCellTooltip(self, self.row)
        end)
        row.nameCell:SetScript("OnLeave", function(self)
            if self.row then
                self.row.highlight:Hide()
            end
            GameTooltip_Hide()
        end)
        for cellIndex = 1, #row.cells do
            local cell = row.cells[cellIndex]
            cell:SetScript("OnEnter", function(self)
                if self.row then
                    self.row.highlight:Show()
                end
                self.highlight:Show()
                ShowDungeonCellTooltip(self, self.row, self.bucketKey)
            end)
            cell:SetScript("OnLeave", function(self)
                self.highlight:Hide()
                if self.row then
                    self.row.highlight:Hide()
                end
                GameTooltip_Hide()
            end)
        end
        detail.dungeonRows[index] = row
    end

    detail.dungeonEmpty = detail.dungeonSection:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    detail.dungeonEmpty:SetJustifyH("LEFT")
    detail.dungeonEmpty:SetText(ns.L.DETAIL_NO_DUNGEON_DATA)

    return detail
end

function DetailPanel:ApplyLayout(frame, detailWidth)
    local detail = frame and frame.detail
    if not detail then
        return
    end

    local inset = 14
    local heroTopInset = 10
    local sectionSpacing = 10
    local contentWidth = math.max(220, detailWidth - (inset * 2))
    local labelWidth = math.max(78, math.min(94, math.floor(contentWidth * 0.29)))
    local matrixGap = 4
    local nameWidth = math.max(96, math.min(128, math.floor(contentWidth * 0.34)))
    local bucketWidth = math.max(28, math.floor((contentWidth - nameWidth - (matrixGap * #timedBucketKeys)) / #timedBucketKeys))
    nameWidth = contentWidth - (bucketWidth * #timedBucketKeys) - (matrixGap * #timedBucketKeys)

    local heroCardGap = 8
    local heroCardHeight = 46
    local heroCardBottomInset = 2
    local scoreCardWidth = math.max(118, math.min(156, math.floor(contentWidth * 0.34)))
    local minNameCardWidth = 96
    if contentWidth < (scoreCardWidth + heroCardGap + minNameCardWidth) then
        scoreCardWidth = math.max(100, contentWidth - heroCardGap - minNameCardWidth)
    end
    local nameCardWidth = contentWidth - scoreCardWidth - heroCardGap

    detail.hero:ClearAllPoints()
    detail.hero:SetPoint("TOPLEFT", detail, "TOPLEFT", inset - 2, -heroTopInset)
    detail.hero:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -(inset + 2), -heroTopInset)
    detail.hero:SetHeight(heroCardHeight)

    detail.hero.nameRibbon:ClearAllPoints()
    detail.hero.nameRibbon:SetPoint("TOPLEFT", detail.hero, "TOPLEFT", 0, 0)
    detail.hero.nameRibbon:SetPoint("BOTTOMLEFT", detail.hero, "BOTTOMLEFT", 0, heroCardBottomInset)
    detail.hero.nameRibbon:SetWidth(nameCardWidth)

    detail.hero.roleBadge:ClearAllPoints()
    detail.hero.roleBadge:SetPoint("LEFT", detail.hero.nameRibbon, "LEFT", 8, 0)

    detail.hero.infoButton:ClearAllPoints()
    detail.hero.infoButton:SetPoint("RIGHT", detail.hero.nameRibbon, "RIGHT", -6, 0)

    detail.hero.name:ClearAllPoints()
    detail.hero.name:SetPoint("LEFT", detail.hero.roleBadge, "RIGHT", 8, 0)
    detail.hero.name:SetPoint("RIGHT", detail.hero.infoButton, "LEFT", -8, 0)

    detail.hero.scorePlate:ClearAllPoints()
    detail.hero.scorePlate:SetPoint("TOPRIGHT", detail.hero, "TOPRIGHT", 0, 0)
    detail.hero.scorePlate:SetPoint("BOTTOMRIGHT", detail.hero, "BOTTOMRIGHT", 0, heroCardBottomInset)
    detail.hero.scorePlate:SetWidth(scoreCardWidth)

    detail.hero.scoreLabel:ClearAllPoints()
    detail.hero.scoreLabel:SetPoint("TOP", detail.hero.scorePlate, "TOP", 0, -4)

    detail.hero.scoreValue:ClearAllPoints()
    detail.hero.scoreValue:SetPoint("TOP", detail.hero.scoreLabel, "BOTTOM", 0, -2)

    detail.hero.scoreWarningButton:ClearAllPoints()
    detail.hero.scoreWarningButton:SetPoint("LEFT", detail.hero.scoreValue, "RIGHT", 4, 0)

    detail.hero.mainScore:ClearAllPoints()
    detail.hero.mainScore:SetPoint("TOP", detail.hero.scoreValue, "BOTTOM", 0, -2)

    detail.hero.emptyState:SetWidth(contentWidth - 20)

    detail.summarySection:ClearAllPoints()
    detail.summarySection:SetPoint("TOPLEFT", detail.hero, "BOTTOMLEFT", 0, -sectionSpacing)
    detail.summarySection:SetPoint("TOPRIGHT", detail.hero, "BOTTOMRIGHT", 0, -sectionSpacing)

    detail.keySection:ClearAllPoints()
    detail.keySection:SetPoint("TOPLEFT", detail.summarySection, "BOTTOMLEFT", 0, -sectionSpacing)
    detail.keySection:SetPoint("TOPRIGHT", detail.summarySection, "BOTTOMRIGHT", 0, -sectionSpacing)

    detail.dungeonSection:ClearAllPoints()
    detail.dungeonSection:SetPoint("TOPLEFT", detail.keySection, "BOTTOMLEFT", 0, -sectionSpacing)
    detail.dungeonSection:SetPoint("TOPRIGHT", detail.keySection, "BOTTOMRIGHT", 0, -sectionSpacing)

    detail.liveRunSection:ClearAllPoints()
    detail.liveRunSection:SetPoint("TOPLEFT", detail.dungeonSection, "BOTTOMLEFT", 0, -sectionSpacing)
    detail.liveRunSection:SetPoint("TOPRIGHT", detail.dungeonSection, "BOTTOMRIGHT", 0, -sectionSpacing)

    for index = 1, #detail.summaryRows do
        local row = detail.summaryRows[index]
        row:SetWidth(contentWidth)
        row.label:SetWidth(labelWidth)
        row.value:SetWidth(contentWidth - labelWidth - 12)
    end

    for index = 1, #detail.liveRunRows do
        local row = detail.liveRunRows[index]
        row:SetWidth(contentWidth)
        row.label:SetWidth(labelWidth)
        row.value:SetWidth(contentWidth - labelWidth - 12)
    end

    detail.keyTabBar:ClearAllPoints()
    detail.keyTabBar:SetPoint("TOPLEFT", detail.keySection.divider, "BOTTOMLEFT", 0, -6)
    detail.keyTabBar:SetPoint("TOPRIGHT", detail.keySection.divider, "BOTTOMRIGHT", 0, -6)

    local tabGap = 4
    local tabWidth = math.floor((contentWidth - tabGap) / 2)
    detail.keyTabs.your:ClearAllPoints()
    detail.keyTabs.your:SetPoint("TOPLEFT", detail.keyTabBar, "TOPLEFT", 0, 0)
    detail.keyTabs.your:SetPoint("BOTTOMLEFT", detail.keyTabBar, "BOTTOMLEFT", 0, 0)
    detail.keyTabs.your:SetWidth(tabWidth)

    detail.keyTabs.their:ClearAllPoints()
    detail.keyTabs.their:SetPoint("TOPLEFT", detail.keyTabs.your, "TOPRIGHT", tabGap, 0)
    detail.keyTabs.their:SetPoint("BOTTOMRIGHT", detail.keyTabBar, "BOTTOMRIGHT", 0, 0)

    detail.keyTabInfoButtons.your:ClearAllPoints()
    detail.keyTabInfoButtons.your:SetPoint("RIGHT", detail.keyTabs.your, "RIGHT", -4, 0)
    detail.keyTabInfoButtons.your:SetFrameLevel(detail.keyTabs.your:GetFrameLevel() + 5)

    detail.keyTabInfoButtons.their:ClearAllPoints()
    detail.keyTabInfoButtons.their:SetPoint("RIGHT", detail.keyTabs.their, "RIGHT", -4, 0)
    detail.keyTabInfoButtons.their:SetFrameLevel(detail.keyTabs.their:GetFrameLevel() + 5)

    detail.keyCard:ClearAllPoints()
    detail.keyCard:SetPoint("TOPLEFT", detail.keyTabBar, "BOTTOMLEFT", 0, -6)
    detail.keyCard:SetPoint("TOPRIGHT", detail.keyTabBar, "BOTTOMRIGHT", 0, -6)
    detail.keyCard:SetHeight(128)
    detail.keyCard.name:SetWidth(contentWidth - 40)
    detail.keyCard.level:SetWidth(contentWidth - 40)

    for index = 1, #detail.keyRows do
        local row = detail.keyRows[index]
        row:SetWidth(contentWidth - 16)
        row.label:SetWidth(labelWidth)
        row.value:SetWidth(contentWidth - labelWidth - 28)
    end

    detail.keyEmpty:SetWidth(contentWidth)

    detail.dungeonHeader:ClearAllPoints()
    detail.dungeonHeader:SetPoint("TOPLEFT", detail.dungeonSection.divider, "BOTTOMLEFT", 0, -6)
    detail.dungeonHeader:SetPoint("TOPRIGHT", detail.dungeonSection.divider, "BOTTOMRIGHT", 0, -6)

    detail.dungeonHeader.name:ClearAllPoints()
    detail.dungeonHeader.name:SetPoint("TOPLEFT", detail.dungeonHeader, "TOPLEFT", 0, 0)
    detail.dungeonHeader.name:SetPoint("BOTTOMLEFT", detail.dungeonHeader, "BOTTOMLEFT", 0, 0)
    detail.dungeonHeader.name:SetWidth(nameWidth)

    local x = nameWidth + matrixGap
    for index = 1, #detail.dungeonHeader.bucketCells do
        local cell = detail.dungeonHeader.bucketCells[index]
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", detail.dungeonHeader, "TOPLEFT", x, 0)
        cell:SetPoint("BOTTOMLEFT", detail.dungeonHeader, "BOTTOMLEFT", x, 0)
        cell:SetWidth(bucketWidth)
        x = x + bucketWidth + matrixGap
    end

    local previous = detail.dungeonHeader
    for index = 1, #detail.dungeonRows do
        local row = detail.dungeonRows[index]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, index == 1 and -2 or -1)
        row:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, index == 1 and -2 or -1)

        row.nameCell:ClearAllPoints()
        row.nameCell:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.nameCell:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.nameCell:SetWidth(nameWidth)

        x = nameWidth + matrixGap
        for cellIndex = 1, #row.cells do
            local cell = row.cells[cellIndex]
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
            cell:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 0)
            cell:SetWidth(bucketWidth)
            x = x + bucketWidth + matrixGap
        end

        previous = row
    end

    detail.dungeonEmpty:ClearAllPoints()
    detail.dungeonEmpty:SetPoint("TOPLEFT", detail.dungeonHeader, "BOTTOMLEFT", 0, -8)
    detail.dungeonEmpty:SetWidth(contentWidth)
end

function DetailPanel:Refresh(panel)
    local frame = panel and panel.frame
    if not frame or not frame.detail then
        return
    end

    local detail = frame.detail
    detail.panel = panel
    local record = panel.selectedFullName and ns.Data:GetRecord(panel.selectedFullName)
    if not record then
        detail.hero.nameRibbon:Hide()
        detail.hero.scorePlate:Hide()
        detail.hero.name:Hide()
        detail.hero.roleBadge:Hide()
        detail.hero.scoreLabel:Hide()
        detail.hero.scoreWarningButton:Hide()
        detail.hero.scoreValue:Hide()
        detail.hero.bestRun:Hide()
        detail.hero.mainScore:Hide()
        detail.hero.infoButton:Hide()
        detail.hero.emptyState:Show()
        detail.hero.tint:SetVertexColor(1, 1, 1, 0)
        detail.hero.topAccent:SetVertexColor(1, 1, 1, 0)

        SetSectionHeight(detail.summarySection, 0)
        SetSectionHeight(detail.liveRunSection, 0)
        SetSectionHeight(detail.keySection, 0)
        SetSectionHeight(detail.dungeonSection, 0)

        for index = 1, #detail.summaryRows do
            detail.summaryRows[index].value:SetText("")
        end

        for index = 1, #detail.liveRunRows do
            detail.liveRunRows[index].value:SetText("")
        end

        detail.keyEmpty:Hide()
        detail.keyCard:Hide()
        detail.dungeonHeader:Hide()
        detail.dungeonEmpty:Hide()

        for index = 1, #detail.dungeonRows do
            detail.dungeonRows[index]:Hide()
        end
        return
    end

    local classColor = ns:GetClassColor(record.classFile)
    local scoreColor = ns:GetScoreColor(record.currentScore)
    local classR, classG, classB = classColor:GetRGB()
    local scoreR, scoreG, scoreB = scoreColor:GetRGB()
    local playerRecord = ns.playerFullName and ns.Data:GetRecord(ns.playerFullName) or nil
    local yourKeyContext = ns.Data:GetCurrentKeyContext() or {}
    local reportedKey = record.reportedKey
    local isBrowsingSelf = ns:GetFullNameKey(record.fullName, ns.playerRealm) == ns:GetFullNameKey(ns.playerFullName, ns.playerRealm)
    local canShowTheirKey = not isBrowsingSelf
        and playerRecord
        and reportedKey
        and reportedKey.mapID
        and reportedKey.level
    local theirKeyTooltip = nil
    if isBrowsingSelf then
        theirKeyTooltip = ns.L.DETAIL_THEIR_KEY_DISABLED_SELF
    elseif not playerRecord then
        theirKeyTooltip = ns.L.DETAIL_THEIR_KEY_DISABLED_NO_SELF
    elseif not canShowTheirKey then
        theirKeyTooltip = ns.L.DETAIL_THEIR_KEY_DISABLED_NO_KEY
    end
    local activeKeyTab = ResolveActiveKeyTab(detail, canShowTheirKey)
    local selectedKeyContext = activeKeyTab == "their" and reportedKey or yourKeyContext
    local projectionRecord = activeKeyTab == "their" and playerRecord or record
    local selectedBestKeyProfile = projectionRecord and selectedKeyContext.mapID and FindDungeonProfile(projectionRecord, selectedKeyContext.mapID) or nil
    local selectedKeyStatus = nil

    if projectionRecord and selectedKeyContext.mapID and selectedKeyContext.level then
        selectedKeyStatus = ns.Data:GetRecordCurrentKeyStatus(projectionRecord, selectedKeyContext.mapID, selectedKeyContext.level)
    end

    detail.keyTabInfoButtons.your.tooltipTitle = ns.L.DETAIL_YOUR_KEY
    detail.keyTabInfoButtons.your.tooltipText = ns.L.DETAIL_KEY_SUBTITLE_YOUR
    detail.keyTabInfoButtons.their.tooltipTitle = ns.L.DETAIL_THEIR_KEY
    detail.keyTabInfoButtons.their.tooltipText = canShowTheirKey and ns.L.DETAIL_KEY_SUBTITLE_THEIR or theirKeyTooltip
    detail.keyTabs.your.tooltipTitle = ns.L.DETAIL_YOUR_KEY
    detail.keyTabs.your.tooltipText = ns.L.DETAIL_KEY_SUBTITLE_YOUR
    detail.keyTabs.their.tooltipTitle = ns.L.DETAIL_THEIR_KEY
    detail.keyTabs.their.tooltipText = canShowTheirKey and ns.L.DETAIL_KEY_SUBTITLE_THEIR or theirKeyTooltip

    UpdateKeyTabButton(detail.keyTabs.your, activeKeyTab == "your", true)
    UpdateKeyTabButton(detail.keyTabs.their, activeKeyTab == "their", canShowTheirKey)

    detail.hero.nameRibbon:Show()
    detail.hero.scorePlate:Show()
    detail.hero.name:Show()
    detail.hero.roleBadge:Show()
    detail.hero.scoreLabel:Show()
    detail.hero.scoreValue:Show()
    detail.hero.bestRun:Hide()
    detail.hero.infoButton:Show()
    detail.hero.emptyState:Hide()
    detail.hero.infoButton.record = record
    detail.hero.roleBadge.record = record

    detail.hero.tint:SetVertexColor(classR, classG, classB, 0)
    detail.hero.topAccent:SetVertexColor(classR, classG, classB, 0)
    detail.hero.nameRibbon.shadow:SetVertexColor(0, 0, 0, 0.1)
    detail.hero.nameRibbon.background:SetVertexColor(classR, classG, classB, 0.14)
    detail.hero.nameRibbon.leftCap:SetVertexColor(classR, classG, classB, 0.28)
    detail.hero.nameRibbon.rightCap:SetVertexColor(1, 1, 1, 0.05)
    detail.hero.scorePlate.glow:SetVertexColor(scoreR, scoreG, scoreB, 0.025)
    detail.hero.scorePlate.sideAccent:SetVertexColor(scoreR, scoreG, scoreB, 0.85)

    detail.hero.name:SetText(ns:GetRecordDisplayName(record))
    detail.hero.name:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    detail.hero.roleBadge.icon:SetAtlas(ns:GetRoleAtlas(record.roleBucket))
    detail.hero.roleBadge.icon:SetSize(14, 14)
    detail.hero.scoreLabel:SetText(ns.L.DETAIL_SCORE)
    detail.hero.scoreLabel:SetTextColor(1, 0.84, 0.18)
    detail.hero.scoreWarningButton.record = record
    detail.hero.scoreWarningButton:SetShown(record.scoreSource == "local" and record.raiderIOHasOverrideScore)
    detail.hero.scoreValue:SetText(tostring(record.currentScore or 0))
    detail.hero.scoreValue:SetTextColor(scoreR, scoreG, scoreB)

    if record.mainCurrentScore and record.mainCurrentScore > (record.currentScore or 0) then
        detail.hero.mainScore:SetText(("%s: %d"):format(ns.L.DETAIL_MAIN_SCORE, record.mainCurrentScore))
        detail.hero.mainScore:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        detail.hero.mainScore:Show()
    else
        detail.hero.mainScore:SetText("")
        detail.hero.mainScore:Hide()
    end

    local reportedKeyRow = detail.summaryRows[3]
    SetSectionHeight(detail.summarySection, 90)

    local specRow = detail.summaryRows[1]
    if record.specName then
        specRow.value:SetText(("%s %s (%s)"):format(
            BuildTextureMarkup(record.specIcon, 16),
            record.specName,
            BuildSpecSourceLabel(record)
        ))
        specRow.value:SetTextColor((record.specIsStale and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
    else
        specRow.value:SetText(("%s %s"):format(BuildTextureMarkup(fallbackSpecTexture, 16), ns.L.UNKNOWN_SPEC_SHORT))
        specRow.value:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end

    local itemLevelRow = detail.summaryRows[2]
    if ns.Config:Get("showItemLevel") then
        local itemLevelText = record.equippedItemLevel and (record.itemLevelIsStale and ns:GetItemLevelText(record.equippedItemLevel) or ns:GetColoredItemLevelText(record.equippedItemLevel)) or ns.L.UNKNOWN_ITEM_LEVEL
        itemLevelRow.value:SetText(("%s (%s)"):format(itemLevelText, BuildItemLevelSourceLabel(record)))
        itemLevelRow.value:SetTextColor((record.itemLevelIsStale and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
    else
        itemLevelRow.value:SetText("-")
        itemLevelRow.value:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    end

    reportedKeyRow:SetShown(true)
    if reportedKey and reportedKey.level and reportedKey.mapID then
        local texture = reportedKey.texture or reportedKey.backgroundTexture or dungeonFallbackTexture
        reportedKeyRow.value:SetText(BuildKeystoneDisplayText(texture, reportedKey.level, reportedKey.mapName))
        reportedKeyRow.value:SetTextColor(GetKeystoneLevelColor(reportedKey.level):GetRGB())
    else
        reportedKeyRow.value:SetText(ns.L.DETAIL_NO_REPORTED_KEY)
        reportedKeyRow.value:SetTextColor(GRAY_FONT_COLOR:GetRGB())
    end

    local showLiveRun = ns.Config:Get("enableGuildSyncChannel")
        and ns.Config:Get("showLiveKeyActivity")
        and record.activeRun

    if showLiveRun then
        local activity = record.activeRun
        SetSectionHeight(detail.liveRunSection, 90)
        detail.liveRunRows[1].value:SetText(BuildKeystoneDisplayText(
            activity.texture or activity.backgroundTexture or dungeonFallbackTexture,
            activity.level,
            activity.mapName
        ))
        detail.liveRunRows[1].value:SetTextColor(GetKeystoneLevelColor(activity.level):GetRGB())
        detail.liveRunRows[2].value:SetText(BuildLiveRunMembersText(activity))
        detail.liveRunRows[2].value:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        detail.liveRunRows[3].value:SetText(BuildLiveRunReportedText(activity))
        detail.liveRunRows[3].value:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    else
        SetSectionHeight(detail.liveRunSection, 0)
        for index = 1, #detail.liveRunRows do
            detail.liveRunRows[index].value:SetText("")
        end
    end

    if projectionRecord and selectedKeyContext.mapID and selectedKeyContext.level then
        local selectedKeyName = selectedKeyContext.mapName
        if (not selectedKeyName or selectedKeyName == "") and selectedBestKeyProfile and selectedBestKeyProfile.dungeon then
            local dungeon = selectedBestKeyProfile.dungeon
            selectedKeyName = dungeon.shortNameLocale or dungeon.shortName or dungeon.name
        end

        local selectedKeyTexture = selectedKeyContext.texture
            or selectedKeyContext.backgroundTexture
            or (selectedBestKeyProfile and GetDungeonTexture(selectedBestKeyProfile.dungeon))
            or dungeonFallbackTexture

        SetSectionHeight(detail.keySection, 180)
        detail.keyCard:Show()
        detail.keyEmpty:Hide()
        detail.keyCard.icon:SetTexture(selectedKeyTexture)
        detail.keyCard.name:SetText(("+%d %s"):format(selectedKeyContext.level, selectedKeyName or ns.L.UNKNOWN))
        detail.keyCard.name:SetTextColor(GetKeystoneLevelColor(selectedKeyContext.level):GetRGB())
        detail.keyCard.level:SetText("")
        detail.keyRows[1].value:SetText(BuildRunSummaryText(selectedBestKeyProfile))
        detail.keyRows[1].value:SetTextColor(GetRunStatusColor(selectedBestKeyProfile and selectedBestKeyProfile.chests or 0):GetRGB())
        detail.keyRows[2].value:SetText(BuildCurrentKeyStatusLabel(selectedKeyStatus))
        detail.keyRows[2].value:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        detail.keyRows[3].value:SetText(BuildKeyScoreImpactText(selectedBestKeyProfile, selectedKeyContext.level, true))
        detail.keyRows[3].value:SetTextColor(GetKeyScoreImpactColor(selectedBestKeyProfile, selectedKeyContext.level, true):GetRGB())
        detail.keyRows[4].value:SetText(BuildKeyScoreImpactText(selectedBestKeyProfile, selectedKeyContext.level, false))
        detail.keyRows[4].value:SetTextColor(GetKeyScoreImpactColor(selectedBestKeyProfile, selectedKeyContext.level, false):GetRGB())
    else
        SetSectionHeight(detail.keySection, 62)
        detail.keyCard:Hide()
        detail.keyEmpty:Show()
        detail.keyEmpty:SetText(ns.L.NO_CURRENT_KEY)
    end

    local selectedKeyBucket = selectedKeyContext.level and GetDungeonBucketKey(selectedKeyContext.level) or nil
    local visibleDungeonRows = math.min(#detail.dungeonRows, #(record.sortedDungeons or {}))
    if visibleDungeonRows > 0 then
        SetSectionHeight(detail.dungeonSection, 44 + (visibleDungeonRows * 20))
        detail.dungeonHeader:Show()
        detail.dungeonEmpty:Hide()

        for index = 1, #detail.dungeonRows do
            local row = detail.dungeonRows[index]
            local dungeonProfile = record.sortedDungeons[index]
            if index <= visibleDungeonRows and dungeonProfile and dungeonProfile.dungeon then
                local bucketKey = GetDungeonBucketKey(dungeonProfile.level)
                local dungeon = dungeonProfile.dungeon
                local isCurrentKeyRow = selectedKeyContext.mapID and (
                    dungeon.keystone_instance == selectedKeyContext.mapID
                    or dungeon.id == selectedKeyContext.mapID
                    or dungeon.instance_map_id == selectedKeyContext.mapID
                    or dungeon.index == selectedKeyContext.mapID
                ) or false

                row:Show()
                row.record = record
                row.keyContext = selectedKeyContext
                row.dungeonProfile = dungeonProfile
                row.isCurrentKeyRow = isCurrentKeyRow
                row:SetHeight(20)
                row.keyAccent:SetHeight(18)
                row.background:SetVertexColor(1, 1, 1, index % 2 == 0 and 0.03 or 0.015)
                if isCurrentKeyRow then
                    row.keyAccent:SetVertexColor(1, 0.82, 0.12, 0.9)
                    row.keyAccent:Show()
                else
                    row.keyAccent:Hide()
                end

                local nameColor = isCurrentKeyRow and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR
                row.nameCell.icon:SetTexture(GetDungeonTexture(dungeon))
                row.nameCell.label:SetText(dungeon.shortNameLocale or dungeon.shortName or dungeon.name)
                row.nameCell.label:SetTextColor(nameColor:GetRGB())

                for cellIndex = 1, #row.cells do
                    local cell = row.cells[cellIndex]
                    cell.marker:Hide()
                    SetMatrixCellTested(cell, isCurrentKeyRow and selectedKeyBucket and cell.bucketKey == selectedKeyBucket)
                    if bucketKey and cell.bucketKey == bucketKey then
                        cell.value:SetText(dungeonProfile.level and tostring(dungeonProfile.level) or "-")
                        cell.value:SetTextColor(GetRunStatusColor(dungeonProfile.chests or 0):GetRGB())
                    elseif DoesDungeonMeetBucket(dungeonProfile, cell.bucketKey) then
                        cell.value:SetText("")
                        cell.marker:SetVertexColor(NORMAL_FONT_COLOR:GetRGB())
                        cell.marker:Show()
                    else
                        cell.value:SetText("-")
                        cell.value:SetTextColor(GRAY_FONT_COLOR:GetRGB())
                    end
                end
            else
                row:Hide()
            end
        end
    else
        SetSectionHeight(detail.dungeonSection, 56)
        detail.dungeonHeader:Hide()
        detail.dungeonEmpty:Show()
        for index = 1, #detail.dungeonRows do
            detail.dungeonRows[index]:Hide()
        end
    end

    ns.Inspect:QueueRecord(record)
end
