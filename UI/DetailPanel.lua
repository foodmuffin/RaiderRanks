local addonName, ns = ...

local DetailPanel = {}
ns.DetailPanel = DetailPanel

local function HideTexture(texture)
    if texture then
        texture:SetTexture(nil)
        texture:Hide()
    end
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

local function BuildObservedSourceLabel(sourceLabel, observedAt)
    local ageText = ns:GetDataAgeText(observedAt)
    if ageText and ageText ~= "" then
        return ("%s, %s"):format(sourceLabel, ageText)
    end

    return sourceLabel
end

local function BuildTimedRunsText(record)
    local lineOne = ("%s %s   %s %s   %s %s %s"):format(
        ns:GetTimedBucketLabel("timed20"),
        ns:GetColoredRunCountText(record.timed20 or 0),
        ns:GetTimedBucketLabel("timed15"),
        ns:GetColoredRunCountText(record.timed15 or 0),
        ns:GetTimedBucketMarkup("timed11_14", 14),
        ns:GetTimedBucketLabel("timed11_14"),
        ns:GetColoredRunCountText(record.timed11_14 or 0)
    )

    local lineTwo = ("%s %s %s   %s %s %s   %s %s %s"):format(
        ns:GetTimedBucketMarkup("timed9_10", 14),
        ns:GetTimedBucketLabel("timed9_10"),
        ns:GetColoredRunCountText(record.timed9_10 or 0),
        ns:GetTimedBucketMarkup("timed4_8", 14),
        ns:GetTimedBucketLabel("timed4_8"),
        ns:GetColoredRunCountText(record.timed4_8 or 0),
        ns:GetTimedBucketMarkup("timed2_3", 14),
        ns:GetTimedBucketLabel("timed2_3"),
        ns:GetColoredRunCountText(record.timed2_3 or 0)
    )

    return ("%s: %s\n%s"):format(ns.L.DETAIL_TIMED_RUNS, lineOne, lineTwo)
end

function DetailPanel:Create(frame)
    if not frame or frame.detail then
        return frame and frame.detail
    end

    frame.detail = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    frame.detail:SetPoint("TOPRIGHT", 0, -92)
    frame.detail:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.detail:SetWidth(312)
    if frame.detail.SetClipsChildren then
        frame.detail:SetClipsChildren(true)
    end

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

    return frame.detail
end

function DetailPanel:ApplyLayout(frame, detailWidth)
    local detail = frame and frame.detail
    if not detail then
        return
    end

    local detailTextWidth = math.max(220, detailWidth - 28)
    detail.name:SetWidth(detailTextWidth)
    detail.source:SetWidth(detailTextWidth)
    detail.role:SetWidth(detailTextWidth)
    detail.spec:SetWidth(math.max(180, detailTextWidth - 22))
    detail.score:SetWidth(detailTextWidth)
    detail.mainScore:SetWidth(detailTextWidth)
    detail.itemLevel:SetWidth(detailTextWidth)
    detail.profileState:SetWidth(detailTextWidth)
    detail.bestRun:SetWidth(detailTextWidth)
    detail.timedRuns:SetWidth(detailTextWidth)

    for index = 1, #detail.raidRows do
        detail.raidRows[index]:SetWidth(detailTextWidth)
    end

    for index = 1, #detail.dungeonRows do
        detail.dungeonRows[index]:SetWidth(detailTextWidth)
    end
end

function DetailPanel:Refresh(panel)
    local frame = panel and panel.frame
    if not frame or not frame.detail then
        return
    end

    local detail = frame.detail
    local record = panel.selectedFullName and ns.Data:GetRecord(panel.selectedFullName)
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

    detail.name:SetText(ns:GetRecordDisplayName(record))
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

    if record.specName then
        local specSourceLabel = record.specSource == "self" and ns.L.SPEC_SOURCE_SELF or record.specSource == "inspect" and ns.L.SPEC_SOURCE_INSPECT or ns.L.SPEC_SOURCE_UNKNOWN
        if record.specSource == "inspect" then
            specSourceLabel = BuildObservedSourceLabel(specSourceLabel, record.specObservedAt)
        end

        detail.spec:SetText(("%s (%s)"):format(record.specName, specSourceLabel))
        detail.spec:SetTextColor((record.specIsStale and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
        if detail.specIcon.SetDesaturated then
            detail.specIcon:SetDesaturated(record.specIsStale)
        end
    else
        detail.spec:SetText(ns.L.UNKNOWN_SPEC_SHORT)
        detail.spec:SetTextColor(GRAY_FONT_COLOR:GetRGB())
        if detail.specIcon.SetDesaturated then
            detail.specIcon:SetDesaturated(true)
        end
    end

    detail.score:SetText(("%s: %d"):format(ns.L.DETAIL_SCORE, record.currentScore or 0))
    detail.score:SetTextColor(ns:GetScoreColor(record.currentScore):GetRGB())

    if record.mainCurrentScore and record.mainCurrentScore > (record.currentScore or 0) then
        detail.mainScore:SetText(("Main: %d"):format(record.mainCurrentScore))
        detail.mainScore:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    else
        detail.mainScore:SetText("")
    end

    if ns.Config:Get("showItemLevel") then
        local itemLevelText = record.equippedItemLevel and (record.itemLevelIsStale and ns:GetItemLevelText(record.equippedItemLevel) or ns:GetColoredItemLevelText(record.equippedItemLevel)) or ns.L.UNKNOWN_ITEM_LEVEL
        local itemLevelSourceLabel = record.itemLevelSource == "self" and ns.L.SELF_ITEM_LEVEL or record.itemLevelSource == "inspect" and ns.L.INSPECT_ITEM_LEVEL or ns.L.UNKNOWN
        if record.itemLevelSource == "inspect" then
            itemLevelSourceLabel = BuildObservedSourceLabel(itemLevelSourceLabel, record.itemLevelObservedAt)
        end

        detail.itemLevel:SetText(("%s: %s (%s)"):format(
            ns.L.ITEM_LEVEL,
            itemLevelText,
            itemLevelSourceLabel
        ))
        detail.itemLevel:SetTextColor((record.itemLevelIsStale and GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR):GetRGB())
    else
        detail.itemLevel:SetText(("%s: -"):format(ns.L.ITEM_LEVEL))
        detail.itemLevel:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
    end

    detail.profileState:SetText(("%s: %s"):format(ns.L.PROFILE_STATE, BuildProfileStateLabel(record)))
    detail.bestRun:SetText(("%s: %s"):format(ns.L.DETAIL_BEST_RUN, BuildBestRunText(record)))
    detail.timedRuns:SetText(BuildTimedRunsText(record))

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

    for index = 1, #detail.dungeonRows do
        local dungeonInfo = record.sortedDungeons[index]
        local row = detail.dungeonRows[index]
        if dungeonInfo and dungeonInfo.dungeon then
            local dungeon = dungeonInfo.dungeon
            row:SetText(("%s %d"):format(dungeon.shortNameLocale or dungeon.shortName or dungeon.name, dungeonInfo.level or 0))
            row:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        else
            row:SetText("")
            row:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        end
    end

    ns.Inspect:QueueRecord(record)
end
