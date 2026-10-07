local ADDON_NAME = ...
local Data = ForeverLevelingCoach_Data

local FLC = CreateFrame("Frame")
local DB

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 430,
    height = 185,
    scale = 1,
    alpha = 0.95,
    locked = false,
    beginner = true,
    visible = true,
    arrowVisible = true,
    arrowPoint = "TOP",
    arrowRelativePoint = "TOP",
    arrowX = 0,
    arrowY = -90,
    arrowScale = 1,
    lastUIVersion = "0.4.2",
}

local TAG_LABELS = {
    IMPORTANT = "IMPORTANT",
    DO = "DO",
    OPTIONAL = "OPTIONAL",
    SKIP = "SKIP",
}

local function copyDefaults()
    ForeverLevelingCoachDB = ForeverLevelingCoachDB or {}
    for k, v in pairs(defaults) do
        if ForeverLevelingCoachDB[k] == nil then
            ForeverLevelingCoachDB[k] = v
        end
    end
    ForeverLevelingCoachDB.discoveredQuests = ForeverLevelingCoachDB.discoveredQuests or {}

    -- One-time v0.4.2 UI cleanup: compact, see-through current-step panel.
    if ForeverLevelingCoachDB.lastUIVersion ~= "0.4.2" then
        ForeverLevelingCoachDB.width = 410
        ForeverLevelingCoachDB.height = 185
        ForeverLevelingCoachDB.alpha = 1
        ForeverLevelingCoachDB.lastUIVersion = "0.4.2"
    end

    DB = ForeverLevelingCoachDB
end

local function safeQuestTitle(info)
    if not info then return nil end
    return info.title or info.questLogTitle
end

local function getQuestLogSnapshot()
    local quests = {}
    local byID = {}

    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then
        return quests, byID
    end

    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local q = {
                questID = info.questID,
                title = safeQuestTitle(info) or ("Quest " .. tostring(info.questID)),
                isComplete = false,
                objectives = {},
            }

            if C_QuestLog.IsComplete then
                q.isComplete = C_QuestLog.IsComplete(info.questID) and true or false
            end

            if C_QuestLog.GetQuestObjectives then
                local objectives = C_QuestLog.GetQuestObjectives(info.questID)
                if objectives then
                    for _, obj in ipairs(objectives) do
                        q.objectives[#q.objectives + 1] = {
                            text = obj.text or "",
                            finished = obj.finished and true or false,
                        }
                    end
                end
            end

            quests[#quests + 1] = q
            byID[q.questID] = q
        end
    end

    return quests, byID
end

local function isQuestCompleted(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
    end
    return false
end

local currentQuests = {}
local currentByID = {}
local currentRouteStep = nil
local currentCluster = nil
local currentClusterCount = 0
local exportSnapshot
local syncQuests

local function isKnownQuest(questID)
    if Data.knownQuestIDs and Data.knownQuestIDs[questID] then return true end
    for _, step in ipairs(Data.route or {}) do
        if step.questID == questID then return true end
    end
    return false
end

local function scanUnknownQuests()
    if not DB then return end
    local level = UnitLevel("player") or 1
    for _, q in ipairs(currentQuests or {}) do
        if not isKnownQuest(q.questID) then
            local key = tostring(q.questID)
            local firstSeen = DB.discoveredQuests[key] == nil
            DB.discoveredQuests[key] = DB.discoveredQuests[key] or {
                questID = q.questID,
                title = q.title,
                firstSeenLevel = level,
                seenCount = 0,
            }
            local r = DB.discoveredQuests[key]
            r.title = q.title
            r.lastSeenLevel = level
            r.seenCount = (r.seenCount or 0) + 1
            r.objectives = {}
            for _, obj in ipairs(q.objectives or {}) do
                r.objectives[#r.objectives + 1] = obj.text or ""
            end
            if firstSeen then
                print(string.format("|cffffcc00FLC NEW / UNVERIFIED:|r %s (Quest ID %d)", q.title, q.questID))
            end
        end
    end
end

local function playerSupported()
    local faction = UnitFactionGroup("player")
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player") or 1

    return faction == Data.supported.faction
        and classFile == Data.supported.class
        and level >= Data.supported.minLevel
        and level <= Data.supported.maxLevel
end

local function getStepByQuestID(questID)
    for _, step in ipairs(Data.route or {}) do
        if step.questID == questID then return step end
    end
    return nil
end

local function zoneMatchesCluster(clusterID)
    local cluster = Data.clusters and Data.clusters[clusterID]
    if not cluster then return false end

    local zone = (GetZoneText and GetZoneText()) or ""
    local subZone = (GetSubZoneText and GetSubZoneText()) or ""
    zone = string.lower(zone or "")
    subZone = string.lower(subZone or "")

    for _, alias in ipairs(cluster.zoneAliases or {}) do
        local a = string.lower(alias)
        if zone == a or subZone == a or string.find(zone, a, 1, true) or string.find(subZone, a, 1, true) then
            return true
        end
    end
    return false
end

local function buildActiveClusters(byID)
    local clusters = {}
    local level = UnitLevel("player") or 1

    for _, step in ipairs(Data.route or {}) do
        local active = byID[step.questID]
        local inRange = level >= (step.minLevel or 1) and level <= (step.maxLevel or 999)
        if active and inRange and step.cluster and not isQuestCompleted(step.questID) then
            clusters[step.cluster] = clusters[step.cluster] or {}
            table.insert(clusters[step.cluster], { step = step, active = active })
        end
    end

    for _, entries in pairs(clusters) do
        table.sort(entries, function(a, b)
            local pa = a.step.clusterPriority or 99
            local pb = b.step.clusterPriority or 99
            if pa == pb then
                return (a.step.questID or 0) < (b.step.questID or 0)
            end
            return pa < pb
        end)
    end

    return clusters
end

local function chooseBestCluster(clusters)
    local bestID, bestEntries, bestScore = nil, nil, -1

    for clusterID, entries in pairs(clusters) do
        local score = #entries
        if zoneMatchesCluster(clusterID) then
            score = score + 100
        end

        -- Prefer DO clusters over clusters containing only OPTIONAL steps.
        for _, entry in ipairs(entries) do
            if entry.step.tag == "DO" then score = score + 5 end
        end

        if score > bestScore then
            bestScore = score
            bestID = clusterID
            bestEntries = entries
        end
    end

    return bestID, bestEntries
end

local function chooseRouteStep(byID)
    local level = UnitLevel("player") or 1
    currentCluster = nil
    currentClusterCount = 0

    -- Class/unlock quests always stay above normal area clustering.
    for _, step in ipairs(Data.route or {}) do
        local inRange = level >= (step.minLevel or 1) and level <= (step.maxLevel or 999)
        local active = byID[step.questID]
        if inRange and active and step.tag == "IMPORTANT" and not isQuestCompleted(step.questID) then
            return step, active
        end
    end

    -- Group active quests by area. Prefer the cluster matching the player's
    -- current zone; otherwise prefer the cluster with the most active work.
    local clusters = buildActiveClusters(byID)
    local clusterID, entries = chooseBestCluster(clusters)
    if clusterID and entries and #entries > 0 then
        currentCluster = clusterID
        currentClusterCount = #entries
        return entries[1].step, entries[1].active
    end

    -- Fall back to the normal verified route order for non-clustered steps.
    for _, step in ipairs(Data.route or {}) do
        local inRange = level >= (step.minLevel or 1) and level <= (step.maxLevel or 999)
        if inRange and not isQuestCompleted(step.questID) then
            local active = byID[step.questID]
            if active then
                return step, active
            end
        end
    end

    local fallback = Data.fallback and Data.fallback[level]
    if fallback then
        return {
            questID = nil,
            title = fallback.title,
            tag = fallback.tag,
            note = fallback.note,
        }, nil
    end

    return {
        questID = nil,
        title = "Continue efficient leveling",
        tag = "DO",
        note = "No verified automatic route step is available for this level yet.",
    }, nil
end

local frame = CreateFrame("Frame", "ForeverLevelingCoachFrame", UIParent, "BackdropTemplate")
frame:SetSize(defaults.width, defaults.height)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:SetResizable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:SetResizeBounds(340, 150, 700, 420)
frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 7, right = 7, top = 7, bottom = 7 },
})
frame:SetBackdropColor(0.05, 0.05, 0.05, 0.58)
frame:SetBackdropBorderColor(0.72, 0.55, 0.20, 0.95)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("Forever Leveling Coach")

local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
versionText:SetPoint("TOPRIGHT", -14, -15)
versionText:SetText("v" .. tostring(Data.version or "?"))

local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
exportButton:SetSize(72, 22)
exportButton:SetPoint("TOPRIGHT", -12, -38)
exportButton:SetText("Export")
exportButton:SetScript("OnClick", function()
    syncQuests()
    exportSnapshot()
end)

local routeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
routeText:SetPoint("TOPLEFT", 14, -45)
routeText:SetPoint("TOPRIGHT", -94, -45)
routeText:SetJustifyH("LEFT")
routeText:SetText("Loading route...")

local detailText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
detailText:SetPoint("TOPLEFT", routeText, "BOTTOMLEFT", 0, -12)
detailText:SetPoint("TOPRIGHT", routeText, "BOTTOMRIGHT", 0, -12)
detailText:SetJustifyH("LEFT")
detailText:SetJustifyV("TOP")
detailText:SetText("")

local questText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
questText:SetPoint("TOPLEFT", detailText, "BOTTOMLEFT", 0, -14)
questText:SetPoint("BOTTOMRIGHT", -14, 18)
questText:SetJustifyH("LEFT")
questText:SetJustifyV("TOP")
questText:SetText("")
questText:Hide()

local resizeGrip = CreateFrame("Button", nil, frame)
resizeGrip:SetSize(18, 18)
resizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
resizeGrip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")

local arrowFrame = CreateFrame("Frame", "ForeverLevelingCoachArrowFrame", UIParent, "BackdropTemplate")
arrowFrame:SetSize(150, 120)
arrowFrame:SetMovable(true)
arrowFrame:EnableMouse(true)
arrowFrame:SetClampedToScreen(true)
arrowFrame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 18,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
arrowFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.48)
arrowFrame:SetBackdropBorderColor(0.72, 0.55, 0.20, 0.90)

local arrowTexture = arrowFrame:CreateTexture(nil, "ARTWORK")
arrowTexture:SetSize(58, 58)
arrowTexture:SetPoint("TOP", 0, -8)
arrowTexture:SetTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Up")
arrowTexture:SetAlpha(0.30)

local arrowLabel = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
arrowLabel:SetPoint("TOPLEFT", 8, -70)
arrowLabel:SetPoint("TOPRIGHT", -8, -70)
arrowLabel:SetJustifyH("CENTER")
arrowLabel:SetText("No verified waypoint")

local function saveArrowPosition()
    local point, _, relativePoint, x, y = arrowFrame:GetPoint(1)
    DB.arrowPoint = point
    DB.arrowRelativePoint = relativePoint
    DB.arrowX = x
    DB.arrowY = y
end

arrowFrame:RegisterForDrag("LeftButton")
arrowFrame:SetScript("OnDragStart", function(self)
    if not DB.locked then self:StartMoving() end
end)
arrowFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveArrowPosition()
end)

local function savePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    DB.point = point
    DB.relativePoint = relativePoint
    DB.x = x
    DB.y = y
    DB.width = frame:GetWidth()
    DB.height = frame:GetHeight()
end

frame:SetScript("OnDragStart", function(self)
    if not DB.locked then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition()
end)
frame:RegisterForDrag("LeftButton")

resizeGrip:SetScript("OnMouseDown", function()
    if not DB.locked then frame:StartSizing("BOTTOMRIGHT") end
end)
resizeGrip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    savePosition()
end)

local function objectiveSummary(active)
    if not active then return nil end
    if active.isComplete then return "Quest objectives complete — turn it in." end
    if not active.objectives or #active.objectives == 0 then return "Quest is active." end

    local lines = {}
    for _, obj in ipairs(active.objectives) do
        local mark = obj.finished and "[done]" or "[ ]"
        lines[#lines + 1] = mark .. " " .. (obj.text or "")
    end
    return table.concat(lines, "\n")
end

local function updateArrow()
    if not DB or DB.arrowVisible == false then
        arrowFrame:Hide()
        return
    end

    arrowFrame:Show()
    local step = currentRouteStep
    local waypoint = step and step.waypoint

    if not waypoint or not waypoint.mapID or not waypoint.x or not waypoint.y then
        arrowTexture:SetRotation(0)
        arrowTexture:SetAlpha(0.30)
        arrowLabel:SetText("No verified waypoint\nfor this step yet")
        return
    end

    arrowTexture:SetAlpha(1)
    local label = waypoint.label or step.title or "Route target"
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID or mapID ~= waypoint.mapID then
        arrowTexture:SetRotation(0)
        arrowLabel:SetText(label .. "\nTravel to target zone")
        return
    end

    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(waypoint.mapID, "player")
    if not pos then
        arrowTexture:SetRotation(0)
        arrowLabel:SetText(label .. "\nPosition unavailable")
        return
    end

    local px, py = pos:GetXY()
    local dx, dy = waypoint.x - px, waypoint.y - py
    local targetAngle = math.atan2 and math.atan2(dx, -dy) or 0
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    arrowTexture:SetRotation(targetAngle - facing)

    local mapDistance = math.sqrt(dx * dx + dy * dy) * 100
    arrowLabel:SetText(string.format("%s\n%.1f map%% away", label, mapDistance))
end

local function render()
    if not playerSupported() then
        routeText:SetText("Current build: Horde Shaman levels 1–30")
        detailText:SetText("This character is outside the currently supported route.")
        questText:SetText("")
        questText:Hide()
        return
    end

    local step, active = chooseRouteStep(currentByID)
    currentRouteStep = step
    local tag = TAG_LABELS[step.tag] or step.tag or "DO"

    routeText:SetText(tag .. ": " .. (step.title or "Next step"))

    local details = {}
    if step.questID then
        details[#details + 1] = "Quest ID: " .. tostring(step.questID)
    end
    if step.note then
        details[#details + 1] = step.note
    end
    if currentCluster and currentClusterCount > 1 then
        local cluster = Data.clusters and Data.clusters[currentCluster]
        local clusterName = cluster and cluster.name or currentCluster
        details[#details + 1] = string.format("Area stack: %d active quests in %s. Stay in this area and let FLC advance through them.", currentClusterCount, clusterName)
    end
    local obj = objectiveSummary(active)
    if obj then
        details[#details + 1] = obj
    end
    detailText:SetText(table.concat(details, "\n\n"))

    -- Keep the visible guide uncluttered: only the current recommended step
    -- and its objective/instruction are shown. Full quest data remains available
    -- through /flc export and the background scanner.
    questText:SetText("")
    questText:Hide()
    updateArrow()
end

syncQuests = function()
    currentQuests, currentByID = getQuestLogSnapshot()
    scanUnknownQuests()
    render()
end

local function applySettings()
    frame:ClearAllPoints()
    frame:SetPoint(DB.point or "CENTER", UIParent, DB.relativePoint or "CENTER", DB.x or 0, DB.y or 0)
    frame:SetSize(DB.width or defaults.width, DB.height or defaults.height)
    frame:SetScale(DB.scale or 1)
    frame:SetAlpha(DB.alpha or defaults.alpha)
    if DB.visible == false then frame:Hide() else frame:Show() end
    resizeGrip:SetShown(not DB.locked)

    arrowFrame:ClearAllPoints()
    arrowFrame:SetPoint(DB.arrowPoint or "TOP", UIParent, DB.arrowRelativePoint or "TOP", DB.arrowX or 0, DB.arrowY or -90)
    arrowFrame:SetScale(DB.arrowScale or 1)
    if DB.arrowVisible == false then arrowFrame:Hide() else arrowFrame:Show() end
end

exportSnapshot = function()
    local _, classFile = UnitClass("player")
    local lines = {
        "Forever Leveling Coach Export",
        "AddonVersion=" .. tostring(Data.version or "?"),
        "Character=" .. tostring(UnitName("player") or "?"),
        "Level=" .. tostring(UnitLevel("player") or "?"),
        "Class=" .. tostring(classFile or "?"),
        "Faction=" .. tostring(UnitFactionGroup("player") or "?"),
        "RecommendedStep=" .. tostring(currentRouteStep and currentRouteStep.title or "?"),
        "RecommendedQuestID=" .. tostring(currentRouteStep and currentRouteStep.questID or "none"),
        "RecommendedCluster=" .. tostring(currentCluster or "none"),
        "ClusterActiveQuestCount=" .. tostring(currentClusterCount or 0),
        "Quests:",
    }

    for _, q in ipairs(currentQuests) do
        local routeStatus = isKnownQuest(q.questID) and "KNOWN" or "NEW/UNVERIFIED"
        lines[#lines + 1] = string.format("- %d | %s | %s | %s", q.questID, q.title, q.isComplete and "complete" or "active", routeStatus)
        for _, obj in ipairs(q.objectives or {}) do
            lines[#lines + 1] = string.format("  %s %s", obj.finished and "[done]" or "[ ]", obj.text or "")
        end
    end

    lines[#lines + 1] = "DiscoveredUnknownQuests:"
    for _, record in pairs(DB.discoveredQuests or {}) do
        lines[#lines + 1] = string.format("- %d | %s | firstLevel=%s | lastLevel=%s",
            record.questID or 0,
            record.title or "?",
            tostring(record.firstSeenLevel or "?"),
            tostring(record.lastSeenLevel or "?"))
        for _, objective in ipairs(record.objectives or {}) do
            lines[#lines + 1] = "  objective: " .. objective
        end
    end

    local text = table.concat(lines, "\n")

    if not FLCExportFrame then
        local export = CreateFrame("Frame", "FLCExportFrame", UIParent, "BackdropTemplate")
        export:SetSize(560, 420)
        export:SetPoint("CENTER")
        export:SetFrameStrata("DIALOG")
        export:EnableMouse(true)
        export:SetMovable(true)
        export:RegisterForDrag("LeftButton")
        export:SetScript("OnDragStart", export.StartMoving)
        export:SetScript("OnDragStop", export.StopMovingOrSizing)
        export:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })

        local scroll = CreateFrame("ScrollFrame", nil, export, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -12)
        scroll:SetPoint("BOTTOMRIGHT", -30, 42)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(500)
        edit:SetScript("OnEscapePressed", function() export:Hide() end)
        scroll:SetScrollChild(edit)
        export.edit = edit

        local close = CreateFrame("Button", nil, export, "UIPanelButtonTemplate")
        close:SetSize(90, 24)
        close:SetPoint("BOTTOM", 0, 10)
        close:SetText("Close")
        close:SetScript("OnClick", function() export:Hide() end)
    end

    FLCExportFrame.edit:SetText(text)
    FLCExportFrame.edit:HighlightText()
    FLCExportFrame:Show()
    FLCExportFrame.edit:SetFocus()
end

SLASH_FOREVERLEVELINGCOACH1 = "/flc"
SlashCmdList.FOREVERLEVELINGCOACH = function(msg)
    msg = (msg or ""):lower()

    if msg == "sync" then
        syncQuests()
        print("|cff33ff99FLC:|r quest log synced.")
    elseif msg == "export" then
        syncQuests()
        exportSnapshot()
    elseif msg == "arrow" then
        DB.arrowVisible = not DB.arrowVisible
        updateArrow()
        print("|cff33ff99FLC:|r arrow " .. (DB.arrowVisible and "enabled." or "disabled."))
    elseif msg == "lock" then
        DB.locked = true
        resizeGrip:Hide()
        print("|cff33ff99FLC:|r window locked.")
    elseif msg == "unlock" then
        DB.locked = false
        resizeGrip:Show()
        print("|cff33ff99FLC:|r window unlocked.")
    elseif msg == "beginner" then
        DB.beginner = not DB.beginner
        render()
        print("|cff33ff99FLC:|r Beginner Mode " .. (DB.beginner and "enabled." or "disabled."))
    elseif msg == "hide" then
        DB.visible = false
        frame:Hide()
    elseif msg == "show" or msg == "" then
        DB.visible = true
        frame:Show()
        syncQuests()
    else
        print("|cff33ff99Forever Leveling Coach v" .. tostring(Data.version) .. "|r")
        print("/flc show, hide, sync, export, arrow, lock, unlock, beginner")
    end
end

FLC:RegisterEvent("ADDON_LOADED")
FLC:RegisterEvent("PLAYER_LOGIN")
FLC:RegisterEvent("QUEST_LOG_UPDATE")
FLC:RegisterEvent("QUEST_ACCEPTED")
FLC:RegisterEvent("QUEST_REMOVED")
FLC:RegisterEvent("QUEST_TURNED_IN")
FLC:RegisterEvent("PLAYER_LEVEL_UP")
FLC:RegisterEvent("ZONE_CHANGED_NEW_AREA")
FLC:RegisterEvent("ZONE_CHANGED")
FLC:RegisterEvent("ZONE_CHANGED_INDOORS")

FLC:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        copyDefaults()
        applySettings()
    elseif event == "PLAYER_LOGIN" then
        syncQuests()
        if C_Timer and C_Timer.NewTicker then
            FLC.ticker = C_Timer.NewTicker(15, syncQuests)
        end
    else
        syncQuests()
    end
end)
