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
    lastCluster = nil,
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
local currentRouteScore = nil
local currentRouteReasons = {}
local currentTravelInstruction = nil
local currentNavigationWaypoint = nil
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

local function zoneMatchesAliases(aliases)
    if not aliases then return false end
    local zone = string.lower((GetZoneText and GetZoneText()) or "")
    local subZone = string.lower((GetSubZoneText and GetSubZoneText()) or "")
    for _, alias in ipairs(aliases) do
        local a = string.lower(alias)
        if zone == a or subZone == a or string.find(zone, a, 1, true) or string.find(subZone, a, 1, true) then
            return true
        end
    end
    return false
end

local function getTravelInstruction(step)
    if not step then return nil, nil end
    if step.travelGuide then
        local fallback
        for _, travel in ipairs(step.travelGuide) do
            if travel.zoneAliases then
                if zoneMatchesAliases(travel.zoneAliases) then
                    return travel.instruction, travel.waypoint
                end
            else
                fallback = travel
            end
        end
        if fallback then return fallback.instruction, fallback.waypoint end
    end
    return nil, step.waypoint
end

local function getObjectiveProgress(active)
    if not active or not active.objectives or #active.objectives == 0 then
        return 0
    end

    local finished = 0
    for _, obj in ipairs(active.objectives) do
        if obj.finished then finished = finished + 1 end
    end
    return finished / #active.objectives
end

local function getActiveClusterCounts(byID)
    local counts = {}
    local level = UnitLevel("player") or 1

    for _, step in ipairs(Data.route or {}) do
        local active = byID[step.questID]
        local inRange = level >= (step.minLevel or 1) and level <= (step.maxLevel or 999)
        if active and inRange and step.cluster and not isQuestCompleted(step.questID) then
            counts[step.cluster] = (counts[step.cluster] or 0) + 1
        end
    end
    return counts
end

local function getWaypointProximityBonus(step)
    local weights = Data.scoring or {}
    local maxBonus = weights.waypointNearMax or 0
    local waypoint = step and step.waypoint
    if not waypoint or not waypoint.mapID or not waypoint.x or not waypoint.y then
        return 0, nil
    end
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return 0, nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID ~= waypoint.mapID then
        return 0, nil
    end

    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return 0, nil end

    local px, py = pos:GetXY()
    local dx, dy = waypoint.x - px, waypoint.y - py
    local distance = math.sqrt(dx * dx + dy * dy)
    local normalized = math.max(0, 1 - math.min(distance / 0.35, 1))
    local bonus = math.floor(maxBonus * normalized)
    if bonus > 0 then
        return bonus, string.format("verified target nearby (+%d)", bonus)
    end
    return 0, nil
end

local function scoreRouteStep(step, active, clusterCounts)
    local weights = Data.scoring or {}
    local score = 0
    local reasons = {}

    local tagScores = weights.tag or {}
    local tagScore = tagScores[step.tag or "DO"] or 0
    score = score + tagScore
    reasons[#reasons + 1] = string.format("%s priority (%+d)", step.tag or "DO", tagScore)

    if active and active.isComplete then
        local bonus = weights.completedTurnIn or 0
        score = score + bonus
        reasons[#reasons + 1] = string.format("ready to turn in (+%d)", bonus)
    else
        local progress = getObjectiveProgress(active)
        if progress > 0 then
            local bonus = math.floor((weights.partialProgressMax or 0) * progress)
            score = score + bonus
            reasons[#reasons + 1] = string.format("partly complete (+%d)", bonus)
        end
    end

    if step.cluster then
        local count = clusterCounts[step.cluster] or 1
        if count > 1 then
            local bonus = (count - 1) * (weights.clusterQuest or 0)
            score = score + bonus
            reasons[#reasons + 1] = string.format("%d nearby stacked quests (+%d)", count, bonus)
        end

        if zoneMatchesCluster(step.cluster) then
            local bonus = weights.currentZoneCluster or 0
            score = score + bonus
            reasons[#reasons + 1] = string.format("you are in this area (+%d)", bonus)
        elseif DB and DB.lastCluster == step.cluster then
            local bonus = weights.rememberedCluster or 0
            score = score + bonus
            reasons[#reasons + 1] = string.format("stay with current route cluster (+%d)", bonus)
        end
    end

    if step.clusterPriority then
        local maxPriority = weights.clusterPriorityMax or 0
        local bonus = math.max(0, maxPriority - ((step.clusterPriority - 1) * 5))
        if bonus > 0 then
            score = score + bonus
            reasons[#reasons + 1] = string.format("good local order (+%d)", bonus)
        end
    end

    local waypointBonus, waypointReason = getWaypointProximityBonus(step)
    if waypointBonus > 0 then
        score = score + waypointBonus
        reasons[#reasons + 1] = waypointReason
    end

    return score, reasons
end

local function chooseRouteStep(byID)
    local level = UnitLevel("player") or 1
    currentCluster = nil
    currentClusterCount = 0
    currentRouteScore = nil
    currentRouteReasons = {}

    local clusterCounts = getActiveClusterCounts(byID)
    local bestStep, bestActive, bestScore, bestReasons = nil, nil, -999999, nil

    for _, step in ipairs(Data.route or {}) do
        local active = byID[step.questID]
        local inRange = level >= (step.minLevel or 1) and level <= (step.maxLevel or 999)

        if active and inRange and not isQuestCompleted(step.questID) then
            local score, reasons = scoreRouteStep(step, active, clusterCounts)
            if score > bestScore then
                bestStep = step
                bestActive = active
                bestScore = score
                bestReasons = reasons
            end
        end
    end

    if bestStep then
        currentRouteScore = bestScore
        currentRouteReasons = bestReasons or {}
        currentCluster = bestStep.cluster
        currentClusterCount = bestStep.cluster and (clusterCounts[bestStep.cluster] or 1) or 0
        if DB and bestStep.cluster then
            DB.lastCluster = bestStep.cluster
        end
        return bestStep, bestActive
    end

    local fallback = Data.fallback and Data.fallback[level]
    if fallback then
        currentRouteScore = 0
        currentRouteReasons = { "fallback guidance: no scored verified active quest" }
        return {
            questID = nil,
            title = fallback.title,
            tag = fallback.tag,
            note = fallback.note,
        }, nil
    end

    currentRouteScore = 0
    currentRouteReasons = { "fallback guidance: no scored verified active quest" }
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

local mainScroll = CreateFrame("ScrollFrame", "ForeverLevelingCoachMainScroll", frame, "UIPanelScrollFrameTemplate")
mainScroll:SetPoint("TOPLEFT", routeText, "BOTTOMLEFT", 0, -10)
mainScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 18)
mainScroll:EnableMouseWheel(true)

local mainScrollChild = CreateFrame("Frame", nil, mainScroll)
mainScrollChild:SetSize(1, 1)
mainScroll:SetScrollChild(mainScrollChild)

local detailText = mainScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
detailText:SetPoint("TOPLEFT", 0, 0)
detailText:SetPoint("TOPRIGHT", 0, 0)
detailText:SetJustifyH("LEFT")
detailText:SetJustifyV("TOP")
detailText:SetText("")

local questText = mainScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
questText:SetPoint("TOPLEFT", detailText, "BOTTOMLEFT", 0, -14)
questText:SetPoint("TOPRIGHT", detailText, "BOTTOMRIGHT", 0, -14)
questText:SetJustifyH("LEFT")
questText:SetJustifyV("TOP")
questText:SetText("")
questText:Hide()

local function refreshMainScroll()
    local width = math.max(120, mainScroll:GetWidth())
    mainScrollChild:SetWidth(width)
    detailText:SetWidth(width)
    local contentHeight = (detailText:GetStringHeight() or 0) + 18
    mainScrollChild:SetHeight(math.max(mainScroll:GetHeight(), contentHeight))
end

mainScroll:SetScript("OnSizeChanged", refreshMainScroll)
mainScroll:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll() or 0
    local maxScroll = math.max(0, (mainScrollChild:GetHeight() or 0) - (self:GetHeight() or 0))
    local nextScroll = current - (delta * 32)
    if nextScroll < 0 then nextScroll = 0 end
    if nextScroll > maxScroll then nextScroll = maxScroll end
    self:SetVerticalScroll(nextScroll)
end)

local resizeGrip = CreateFrame("Button", nil, frame)
resizeGrip:SetSize(18, 18)
resizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
resizeGrip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")

local arrowFrame = CreateFrame("Frame", "ForeverLevelingCoachArrowFrame", UIParent)
arrowFrame:SetSize(120, 92)
arrowFrame:SetMovable(true)
arrowFrame:EnableMouse(true)
arrowFrame:SetClampedToScreen(true)
arrowFrame:SetFrameStrata("HIGH")

-- Floating WoW-style navigation arrow: no window/background.
local arrowTexture = arrowFrame:CreateTexture(nil, "ARTWORK")
arrowTexture:SetSize(64, 64)
arrowTexture:SetPoint("TOP", 0, 0)
arrowTexture:SetTexture("Interface/Minimap/MinimapArrow")
arrowTexture:SetAlpha(1)

local arrowLabel = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrowLabel:SetPoint("TOP", arrowTexture, "BOTTOM", 0, -2)
arrowLabel:SetWidth(180)
arrowLabel:SetJustifyH("CENTER")
arrowLabel:SetShadowOffset(1, -1)
arrowLabel:SetText("")

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

arrowFrame:SetScript("OnEnter", function()
    if DB and not DB.locked and GameTooltip then
        GameTooltip:SetOwner(arrowFrame, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Forever Leveling Coach Arrow")
        GameTooltip:AddLine("Drag to move. /flc lock to lock it.", 1, 1, 1)
        GameTooltip:Show()
    end
end)
arrowFrame:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
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

local function getWaypointDistanceMeters(mapID, px, py, tx, ty)
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local playerVec = CreateVector2D(px, py)
        local targetVec = CreateVector2D(tx, ty)
        local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, playerVec)
        local targetContinent, targetWorld = C_Map.GetWorldPosFromMapPos(mapID, targetVec)

        if playerWorld and targetWorld and playerContinent == targetContinent then
            local wx1, wy1 = playerWorld:GetXY()
            local wx2, wy2 = targetWorld:GetXY()
            local yards = math.sqrt((wx2 - wx1) * (wx2 - wx1) + (wy2 - wy1) * (wy2 - wy1))
            return yards * 0.9144
        end
    end
    return nil
end

local function atan2Safe(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function updateArrow()
    if not DB or DB.arrowVisible == false or not currentRouteStep then
        arrowFrame:Hide()
        return
    end

    local _, waypoint = getTravelInstruction(currentRouteStep)
    currentNavigationWaypoint = waypoint
    if not waypoint or not waypoint.mapID or not waypoint.x or not waypoint.y then
        arrowFrame:Hide()
        return
    end

    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not playerMapID or not C_Map.GetPlayerMapPosition or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then
        arrowFrame:Hide()
        return
    end

    local playerMapPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerMapPos then
        arrowFrame:Hide()
        return
    end

    local px, py = playerMapPos:GetXY()
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(playerMapID, CreateVector2D(px, py))
    local targetContinent, targetWorld = C_Map.GetWorldPosFromMapPos(waypoint.mapID, CreateVector2D(waypoint.x, waypoint.y))

    if not playerWorld or not targetWorld or playerContinent ~= targetContinent then
        arrowFrame:Hide()
        return
    end

    local pwx, pwy = playerWorld:GetXY()
    local twx, twy = targetWorld:GetXY()
    local dx, dy = twx - pwx, twy - pwy

    arrowFrame:Show()
    local targetAngle = atan2Safe(dx, -dy)
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    arrowTexture:SetRotation(targetAngle - facing)

    local yards = math.sqrt(dx * dx + dy * dy)
    local meters = yards * 0.9144
    local label = waypoint.label or currentRouteStep.title or "Route target"
    if meters >= 1000 then
        arrowLabel:SetText(string.format("%s  •  %.2f km", label, meters / 1000))
    else
        arrowLabel:SetText(string.format("%s  •  %d m", label, math.floor(meters + 0.5)))
    end
end

local arrowElapsed = 0
arrowFrame:SetScript("OnUpdate", function(_, elapsed)
    arrowElapsed = arrowElapsed + elapsed
    if arrowElapsed >= 0.05 then
        arrowElapsed = 0
        updateArrow()
    end
end)

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
    local travelInstruction, navigationWaypoint = getTravelInstruction(step)
    currentTravelInstruction = travelInstruction
    currentNavigationWaypoint = navigationWaypoint
    local tag = TAG_LABELS[step.tag] or step.tag or "DO"

    routeText:SetText(tag .. ": " .. (step.title or "Next step"))

    local details = {}
    if step.questID then
        details[#details + 1] = "Quest ID: " .. tostring(step.questID)
    end
    if step.note then
        details[#details + 1] = step.note
    end
    if currentTravelInstruction then
        details[#details + 1] = "Travel step: " .. currentTravelInstruction
    end
    if currentCluster and currentClusterCount > 1 then
        local cluster = Data.clusters and Data.clusters[currentCluster]
        local clusterName = cluster and cluster.name or currentCluster
        details[#details + 1] = string.format("Area stack: %d active quests in %s. Stay in this area and let FLC advance through them.", currentClusterCount, clusterName)
    end
    if currentRouteScore then
        details[#details + 1] = string.format("Smart score: %d", currentRouteScore)
    end
    local obj = objectiveSummary(active)
    if obj then
        details[#details + 1] = obj
    end
    detailText:SetText(table.concat(details, "\n\n"))
    refreshMainScroll()

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
    arrowFrame:EnableMouse(not DB.locked)

    arrowFrame:ClearAllPoints()
    arrowFrame:SetPoint(DB.arrowPoint or "TOP", UIParent, DB.arrowRelativePoint or "TOP", DB.arrowX or 0, DB.arrowY or -90)
    arrowFrame:SetScale(DB.arrowScale or 1)
    if DB.arrowVisible == false then
        arrowFrame:Hide()
    else
        updateArrow()
    end
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
        "RecommendedScore=" .. tostring(currentRouteScore or 0),
        "RecommendedReasons=" .. table.concat(currentRouteReasons or {}, " | "),
        "CurrentZone=" .. tostring((GetZoneText and GetZoneText()) or "?"),
        "CurrentSubZone=" .. tostring((GetSubZoneText and GetSubZoneText()) or "?"),
        "CurrentTravelStep=" .. tostring(currentTravelInstruction or "none"),
        "NavigationTarget=" .. tostring(currentNavigationWaypoint and currentNavigationWaypoint.label or "none"),
        "ArrowMode=" .. tostring(currentNavigationWaypoint and "world-space" or "hidden"),
    }

    lines[#lines + 1] = "ScoredCandidates:"
    local clusterCounts = getActiveClusterCounts(currentByID)
    local scored = {}
    for _, step in ipairs(Data.route or {}) do
        local active = currentByID[step.questID]
        local level = UnitLevel("player") or 1
        local inRange = level >= (step.minLevel or 1) and level <= (step.maxLevel or 999)
        if active and inRange and not isQuestCompleted(step.questID) then
            local score, reasons = scoreRouteStep(step, active, clusterCounts)
            scored[#scored + 1] = { step = step, score = score, reasons = reasons }
        end
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    for _, item in ipairs(scored) do
        lines[#lines + 1] = string.format("- %d | %s | score=%d | %s",
            item.step.questID or 0,
            item.step.title or "?",
            item.score,
            table.concat(item.reasons or {}, " | "))
    end

    lines[#lines + 1] = "Quests:"
    for _, q in ipairs(currentQuests) do
        local routeStatus = isKnownQuest(q.questID) and "KNOWN" or "NEW/UNVERIFIED"
        lines[#lines + 1] = string.format("- %d | %s | %s | %s", q.questID, q.title, q.isComplete and "complete" or "active", routeStatus)
        for _, obj in ipairs(q.objectives or {}) do
            lines[#lines + 1] = string.format("  %s %s", obj.finished and "[done]" or "[ ]", obj.text or "")
        end
    end

    lines[#lines + 1] = "UnresolvedUnknownQuests:"
    local unresolvedUnknownCount = 0
    for _, record in pairs(DB.discoveredQuests or {}) do
        if record.questID and not isKnownQuest(record.questID) then
            unresolvedUnknownCount = unresolvedUnknownCount + 1
            lines[#lines + 1] = string.format("- %d | %s | firstLevel=%s | lastLevel=%s",
                record.questID or 0,
                record.title or "?",
                tostring(record.firstSeenLevel or "?"),
                tostring(record.lastSeenLevel or "?"))
            for _, objective in ipairs(record.objectives or {}) do
                lines[#lines + 1] = "  objective: " .. objective
            end
        end
    end
    if unresolvedUnknownCount == 0 then
        lines[#lines + 1] = "- none"
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
        arrowFrame:EnableMouse(false)
        print("|cff33ff99FLC:|r window locked.")
    elseif msg == "unlock" then
        DB.locked = false
        resizeGrip:Show()
        arrowFrame:EnableMouse(true)
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
