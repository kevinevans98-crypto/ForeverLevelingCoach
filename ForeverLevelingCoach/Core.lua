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
    height = 170,
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
    travelHintPoint = "TOP",
    travelHintRelativePoint = "TOP",
    travelHintX = 0,
    travelHintY = -190,
    travelHintWidth = 300,
    travelHintHeight = 90,
    autoFlight = false,
    gearAdvisor = true,
    displayMode = "COMPACT",
    relicAdvisor = true,
    lazyMode = true,
    autoAccept = true,
    autoTurnIn = true,
    rogueTalentSpec = "Combat",
    shamanTalentSpec = "Enhancement",
    warriorTalentSpec = "Protection",
    hunterTalentSpec = "Beast Mastery",
    mageTalentSpec = "Frost",
    warlockTalentSpec = "Affliction",
    priestTalentSpec = "Shadow",
    paladinTalentSpec = "Retribution",
    druidTalentSpec = "Feral",
    lastClassTrainerLevel = 0,
    lastUIVersion = "0.16.1",
    lastCluster = nil,
    pendingHubChain = nil,
}

local TAG_LABELS = {
    IMPORTANT = "IMPORTANT",
    DO = "DO",
    OPTIONAL = "OPTIONAL",
    SKIP = "SKIP",
}

local function getClassProfile()
    local className, classFile = UnitClass("player")
    local configured = Data.classProfiles and Data.classProfiles[classFile] or nil
    return {
        classFile = classFile,
        className = (configured and configured.name) or className or classFile or "Unknown",
        optimized = configured and configured.optimized == true or false,
        usesRelics = configured and configured.usesRelics == true or false,
        weaponPreference = configured and configured.weaponPreference and Data[configured.weaponPreference] or nil,
        gearProfile = configured and configured.gearProfile and Data[configured.gearProfile] or nil,
        talentBuilds = configured and configured.talentData and Data[configured.talentData] or nil,
        talentSetting = configured and configured.talentSetting or nil,
    }
end

local function flcTalentRecommendation()
    local profile = getClassProfile()
    local builds = profile and profile.talentBuilds
    if not builds then return nil, nil end

    local defaultSpec = builds.defaultSpec
    local selectedSpec = profile.talentSetting and DB and DB[profile.talentSetting] or nil
    local spec = selectedSpec or defaultSpec
    local build = spec and builds[spec] or nil
    if not build and defaultSpec then build = builds[defaultSpec] end
    if not build then return nil, nil end

    local level = UnitLevel("player") or 1
    if level < 10 then
        return build.name, "Talents unlock at level 10"
    end

    local pick = build.talentsByLevel and build.talentsByLevel[level]
    if pick then
        local text = string.format("%s %d/%d", pick.talent, pick.rank or 1, pick.maxRank or 1)
        if pick.note then text = tostring(pick.note) .. " — " .. text end
        return build.name, text
    end

    if level >= 30 then
        return build.name, tostring(build.final30 or "Level 30 build complete")
    end

    for l = level, 10, -1 do
        pick = build.talentsByLevel and build.talentsByLevel[l]
        if pick then
            local text = string.format("%s %d/%d", pick.talent, pick.rank or 1, pick.maxRank or 1)
            if pick.note then text = tostring(pick.note) .. " — " .. text end
            return build.name, text
        end
    end

    return build.name, nil
end

local function copyDefaults()
    ForeverLevelingCoachDB = ForeverLevelingCoachDB or {}
    ForeverLevelingCoachDB.characters = ForeverLevelingCoachDB.characters or {}

    local charName = UnitName("player") or "Unknown"
    local realmName = GetRealmName and GetRealmName() or "Realm"
    local charKey = charName .. "-" .. realmName
    local charDB = ForeverLevelingCoachDB.characters[charKey] or {}
    ForeverLevelingCoachDB.characters[charKey] = charDB

    for k, v in pairs(defaults) do
        if charDB[k] == nil then
            -- Preserve existing UI/user toggles for the first migrated character,
            -- but never inherit character progression state such as flight paths.
            if ForeverLevelingCoachDB[k] ~= nil
                and k ~= "lastClassTrainerLevel"
                and k ~= "lastCluster" then
                charDB[k] = ForeverLevelingCoachDB[k]
            else
                charDB[k] = v
            end
        end
    end

    charDB.discoveredQuests = charDB.discoveredQuests or {}
    charDB.knownFlightPaths = charDB.knownFlightPaths or {}
    charDB.navigationProgress = charDB.navigationProgress or {}

    if charDB.lastUIVersion ~= "0.26.1" then
        if not charDB.width or charDB.width < 410 then
            charDB.width = 430
        end
        if not charDB.height or charDB.height < 180 then
            charDB.height = 190
        end
        charDB.alpha = 1
        charDB.lastUIVersion = "0.26.1"
    end

    if charDB.lastCompactUIVersion ~= "0.29.4" then
        if not charDB.height or (charDB.height >= 180 and charDB.height <= 205) then
            charDB.height = 170
        end
        charDB.lastCompactUIVersion = "0.29.4"
    end

    DB = charDB
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
local currentNavigationStepIndex = nil
local currentNavigationStepCount = nil
local currentFastTravelSuggestion = nil
local currentFastTravelMode = nil
local currentNextQuestPickup = nil
local currentPickupSuggestions = {}
local currentQuickPickupSuggestion = nil
local currentArrivalState = nil
local currentTurnInDecision = nil
local currentTurnInDecisionReason = nil
local currentTurnInBatch = nil
local currentBatchTurnInTarget = nil
local currentHubChainPickup = nil
local currentRouteDataGaps = {}
local currentRouteReadiness = {}
local currentQuestCleanup = {}
local currentPersonTarget = nil
local currentObjectiveTarget = nil
local currentTravelTarget = nil
local currentTrainingTarget = nil
local currentTrainingDue = false
local flcRelicStatus
local currentTrainerAvailableCount = nil
local currentTaxiOptions = {}
local currentAutoFlightTarget = nil
local currentAutoFlightStatus = "idle"
local taxiOpenSerial = 0
local exportSnapshot
local syncQuests
local getBestObjectiveTarget
local flcGearScanSnapshot
local applySettings

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
        and Data.supported.classes
        and Data.supported.classes[classFile] == true
        and level >= Data.supported.minLevel
        and level <= Data.supported.maxLevel
end

local function getStepByQuestID(questID)
    for _, step in ipairs(Data.route or {}) do
        if step.questID == questID then return step end
    end
    return nil
end


local function scanCompletedRouteDataGaps()
    local gaps = {}
    for _, q in ipairs(currentQuests or {}) do
        if q.isComplete and isKnownQuest(q.questID) and not isQuestCompleted(q.questID) then
            local step = getStepByQuestID(q.questID)
            local reason = nil

            if not step then
                reason = "KNOWN QUEST HAS NO ROUTE ENTRY"
            elseif not step.turnInTarget then
                reason = "ROUTE ENTRY MISSING TURN-IN TARGET"
            elseif not step.turnInTarget.waypoint
                or not step.turnInTarget.waypoint.mapID
                or not step.turnInTarget.waypoint.x
                or not step.turnInTarget.waypoint.y then
                reason = "TURN-IN TARGET MISSING VERIFIED WAYPOINT"
            end

            if reason then
                gaps[#gaps + 1] = {
                    questID = q.questID,
                    title = q.title,
                    reason = reason,
                    hasRouteEntry = step and true or false,
                }
            end
        end
    end

    table.sort(gaps, function(a, b)
        return (tonumber(a.questID) or 0) < (tonumber(b.questID) or 0)
    end)

    currentRouteDataGaps = gaps
    return gaps
end

local function hasVerifiedWaypoint(target)
    return target and target.waypoint
        and target.waypoint.mapID
        and target.waypoint.x
        and target.waypoint.y
        and true or false
end

local function addRouteReadinessIssue(list, q, step, severity, code, detail)
    list[#list + 1] = {
        questID = q and q.questID or (step and step.questID),
        title = (q and q.title) or (step and step.title) or "Unknown Quest",
        severity = severity or "INFO",
        code = code or "UNKNOWN",
        detail = detail or "Route data needs review",
    }
end

local function scanRouteReadiness()
    local issues = {}
    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil

    for _, q in ipairs(currentQuests or {}) do
        if isKnownQuest(q.questID) and not isQuestCompleted(q.questID) then
            local step = getStepByQuestID(q.questID)

            if not step then
                addRouteReadinessIssue(issues, q, nil, "BLOCKER", "NO_ROUTE_ENTRY",
                    "Known active quest has no route entry")
            else
                -- Pickup metadata is useful for future route reconstruction and
                -- hub chaining, but it is non-blocking after the quest is active.
                if not step.pickupTarget then
                    addRouteReadinessIssue(issues, q, step, "INFO", "PICKUP_DATA_MISSING",
                        "Active quest has no pickupTarget metadata")
                end

                -- Every routed quest should know how to finish cleanly. A text-only
                -- turn-in is better than nothing, but a verified waypoint is preferred.
                if not step.turnInTarget then
                    addRouteReadinessIssue(issues, q, step, "WARN", "TURNIN_TARGET_MISSING",
                        "Route entry has no turn-in target")
                elseif not hasVerifiedWaypoint(step.turnInTarget) then
                    addRouteReadinessIssue(issues, q, step, "WARN", "TURNIN_WAYPOINT_MISSING",
                        "Turn-in target has no verified waypoint")
                end

                if not q.isComplete then
                    local unfinishedCount = 0
                    for _, obj in ipairs(q.objectives or {}) do
                        if not obj.finished then unfinishedCount = unfinishedCount + 1 end
                    end

                    if unfinishedCount > 0 then
                        local hasObjectiveGuidance =
                            (step.objectiveTargets and #step.objectiveTargets > 0)
                            or hasVerifiedWaypoint(step)
                            or step.personTarget
                            or step.travelGuide

                        if not hasObjectiveGuidance then
                            addRouteReadinessIssue(issues, q, step, "BLOCKER", "OBJECTIVE_GUIDANCE_MISSING",
                                "Unfinished quest has no objective target, waypoint, person target, or travel guide")
                        end
                    end

                    if step.dungeon then
                        local hasDungeonGuidance =
                            (step.objectiveTargets and #step.objectiveTargets > 0)
                            or step.personTarget
                            or step.travelGuide
                        if not hasDungeonGuidance then
                            addRouteReadinessIssue(issues, q, step, "WARN", "DUNGEON_GUIDANCE_MISSING",
                                "Dungeon quest has no entrance/objective instructions")
                        end
                    end

                    -- Detect known cross-map objectives that lack a route bridge.
                    -- A flight target, travel guide, or explicit person/entrance
                    -- target counts as cross-zone support.
                    if playerMapID and step.objectiveTargets then
                        local foundRemote = false
                        for _, target in ipairs(step.objectiveTargets) do
                            if hasVerifiedWaypoint(target)
                                and target.waypoint.mapID ~= playerMapID then
                                foundRemote = true
                                break
                            end
                        end
                        if foundRemote
                            and not step.travelGuide
                            and not step.flightTarget
                            and not step.personTarget then
                            addRouteReadinessIssue(issues, q, step, "WARN", "CROSS_ZONE_TRAVEL_MISSING",
                                "Remote objective has no travelGuide, flightTarget, or entrance/person target")
                        end
                    end
                end
            end
        end
    end

    local severityRank = { BLOCKER = 1, WARN = 2, INFO = 3 }
    table.sort(issues, function(a, b)
        local ar = severityRank[a.severity] or 9
        local br = severityRank[b.severity] or 9
        if ar ~= br then return ar < br end
        if (a.questID or 0) ~= (b.questID or 0) then
            return (a.questID or 0) < (b.questID or 0)
        end
        return tostring(a.code or "") < tostring(b.code or "")
    end)

    currentRouteReadiness = issues
    return issues
end

local function getPlayerRaceKeys()
    local raceName, raceFile = UnitRace("player")
    local keys = {}
    if raceName and raceName ~= "" then keys[string.upper(raceName)] = true end
    if raceFile and raceFile ~= "" then keys[string.upper(raceFile)] = true end

    -- Forever's custom race token may differ between client builds. Matching
    -- both the localized race name and raceFile keeps Skyborne routing safe.
    if raceName and string.find(string.lower(raceName), "skyborne", 1, true) then
        keys.SKYBORNE = true
    end
    if raceFile and string.find(string.lower(raceFile), "skyborne", 1, true) then
        keys.SKYBORNE = true
    end
    return keys
end

local function routeStepEligible(step, level, playerClass)
    if not step then return false end

    -- SKIP is a hard routing exclusion, not merely a low score. Keep SKIP
    -- entries in data for classification/export purposes, but never surface
    -- them as the recommended next step or count them toward cluster density.
    if (step.tag or "DO") == "SKIP" then
        return false
    end

    level = level or (UnitLevel("player") or 1)
    if level < (step.minLevel or 1) or level > (step.maxLevel or 999) then
        return false
    end

    -- Optional quest cleanup: once the player reaches an OPTIONAL quest's
    -- route cutoff level, stop spending route time on it. This prevents old
    -- side quests from competing with current-level DO/IMPORTANT work.
    if (step.tag or "DO") == "OPTIONAL"
        and tonumber(step.maxLevel)
        and level >= tonumber(step.maxLevel) then
        return false
    end

    if not playerClass then
        local _, classFile = UnitClass("player")
        playerClass = classFile
    end

    if step.class and step.class ~= playerClass then
        return false
    end

    if step.races then
        local raceKeys = getPlayerRaceKeys()
        local matched = false
        for raceKey, enabled in pairs(step.races) do
            if enabled and raceKeys[string.upper(raceKey)] then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end

    return true
end


local function scanQuestCleanup()
    local cleanup = {}
    local level = UnitLevel("player") or 1

    for _, q in ipairs(currentQuests or {}) do
        if not q.isComplete then
            local step = getStepByQuestID(q.questID)
            if step and (step.tag or "DO") == "OPTIONAL"
                and tonumber(step.maxLevel)
                and level >= tonumber(step.maxLevel) then
                cleanup[#cleanup + 1] = {
                    questID = q.questID,
                    title = q.title or step.title,
                    reason = string.format("OPTIONAL quest reached route cutoff level %d", tonumber(step.maxLevel)),
                    recommendation = "SAFE TO IGNORE / ABANDON",
                }
            end
        end
    end

    table.sort(cleanup, function(a, b)
        return (tonumber(a.questID) or 0) < (tonumber(b.questID) or 0)
    end)

    currentQuestCleanup = cleanup
    return cleanup
end

local function zoneMatchesCluster(clusterID)
    local cluster = Data.clusters and Data.clusters[clusterID]
    if not cluster then return false end

    local zone = string.lower((GetZoneText and GetZoneText()) or "")
    local subZone = string.lower((GetSubZoneText and GetSubZoneText()) or "")

    -- Some clusters share one large parent zone but represent very different
    -- leveling hubs. localAliases keeps the large current-area score scoped to
    -- the actual hub instead of treating the entire parent zone as "nearby".
    local aliases = cluster.localAliases or cluster.zoneAliases or {}
    for _, alias in ipairs(aliases) do
        local a = string.lower(alias)
        if zone == a or subZone == a
            or string.find(zone, a, 1, true)
            or string.find(subZone, a, 1, true) then
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

local function waypointDistanceNormalized(waypoint)
    if not waypoint or not waypoint.mapID or not waypoint.x or not waypoint.y then return nil end
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID ~= waypoint.mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local px, py = pos:GetXY()
    local dx, dy = waypoint.x - px, waypoint.y - py
    return math.sqrt(dx * dx + dy * dy)
end


local function pickupBaseEligible(step)
    if not step or not step.questID or not step.pickupTarget then return false end

    local level = UnitLevel("player") or 1
    if level < (step.minLevel or 1) or level > (step.maxLevel or 999) then return false end

    local _, playerClass = UnitClass("player")
    if step.class and step.class ~= playerClass then return false end

    if step.races then
        local raceKeys = getPlayerRaceKeys()
        local matched = false
        for raceKey, enabled in pairs(step.races) do
            if enabled and raceKeys[string.upper(raceKey)] then
                matched = true
                break
            end
        end
        if not matched then return false end
    end

    for _, prereqID in ipairs(step.pickupPrereqQuestIDs or {}) do
        if not isQuestCompleted(prereqID) then return false end
    end

    return true
end

local function getPickupSuggestions(byID, routeStep)
    local suggestions = {}
    byID = byID or {}

    for _, step in ipairs(Data.route or {}) do
        if pickupBaseEligible(step)
            and not byID[step.questID]
            and not isQuestCompleted(step.questID) then

            local pickup = step.pickupTarget
            local localCluster = step.cluster and zoneMatchesCluster(step.cluster) or false
            local distance = pickup and pickup.waypoint and waypointDistanceNormalized(pickup.waypoint) or nil
            local near = distance and distance <= (step.pickupNearDistance or 0.08) or false
            local sameRouteCluster = routeStep and routeStep.cluster and step.cluster == routeStep.cluster
            local tag = step.tag or "DO"
            local classification = nil

            if tag == "SKIP" then
                if localCluster or near then classification = "SKIP" end
            elseif tag == "IMPORTANT" or tag == "DO" then
                if localCluster or near then
                    classification = "PICK UP NOW"
                elseif sameRouteCluster then
                    classification = "PICK UP IF NEARBY"
                end
            elseif tag == "OPTIONAL" then
                if localCluster or near or sameRouteCluster then
                    classification = "PICK UP IF NEARBY"
                end
            end

            if classification then
                local rank = classification == "PICK UP NOW" and 1
                    or classification == "PICK UP IF NEARBY" and 2
                    or 3
                suggestions[#suggestions + 1] = {
                    questID = step.questID,
                    title = step.title or ("Quest " .. tostring(step.questID)),
                    classification = classification,
                    rank = rank,
                    distance = distance,
                    pickup = pickup,
                    step = step,
                }
            end
        end
    end

    table.sort(suggestions, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.distance and b.distance and a.distance ~= b.distance then
            return a.distance < b.distance
        elseif a.distance and not b.distance then
            return true
        elseif b.distance and not a.distance then
            return false
        end
        local ap = (a.step and a.step.clusterPriority) or 999
        local bp = (b.step and b.step.clusterPriority) or 999
        if ap ~= bp then return ap < bp end
        return tostring(a.title) < tostring(b.title)
    end)

    return suggestions
end

local function getNavigationStep(step, travel)
    if not travel or not travel.steps or #travel.steps == 0 then
        return travel and travel.instruction or nil, travel and travel.waypoint or nil, nil, nil
    end

    DB.navigationProgress = DB.navigationProgress or {}
    local key = tostring(step.questID or step.title or "route")
    local index = tonumber(DB.navigationProgress[key]) or 1
    if index < 1 then index = 1 end
    if index > #travel.steps then index = #travel.steps end

    local nav = travel.steps[index]

    -- Auto-advance only from a verified same-map proximity check.
    if nav and nav.advanceWhenWithin and index < #travel.steps then
        local distance = waypointDistanceNormalized(nav.advanceWhenWithin.waypoint)
        if distance and distance <= (nav.advanceWhenWithin.distance or 0.03) then
            index = index + 1
            DB.navigationProgress[key] = index
            nav = travel.steps[index]
        end
    end

    DB.navigationProgress[key] = index
    return nav and nav.instruction or travel.instruction,
           nav and nav.waypoint or travel.waypoint,
           index,
           #travel.steps
end

local function getHearthStatus()
    local status = {
        hasStone = false,
        ready = false,
        cooldown = 0,
        bind = (GetBindLocation and GetBindLocation()) or "Unknown",
    }

    if GetItemCount then
        status.hasStone = (GetItemCount(6948) or 0) > 0
    end

    if GetItemCooldown then
        local startTime, duration, enabled = GetItemCooldown(6948)
        if enabled == 1 and duration then
            if duration == 0 then
                status.ready = status.hasStone
                status.cooldown = 0
            else
                local remaining = math.max(0, (startTime or 0) + duration - GetTime())
                status.cooldown = remaining
                status.ready = status.hasStone and remaining <= 0
            end
        end
    end

    return status
end

local function getFastTravelSuggestion(step, travelInstruction)
    local zone = (GetZoneText and GetZoneText()) or ""
    local hearth = getHearthStatus()

    -- Route-specific verified fast-travel advice. We only recommend shortcuts
    -- whose destination is known to be useful for the active route.
    local ratchetRoute = step and (step.questID == 96 or step.questID == 1103 or step.questID == 6981)
    if ratchetRoute then
        if zoneMatchesAliases({ "Orgrimmar" }) then
            if hearth.ready and hearth.bind and string.find(string.lower(hearth.bind), "ratchet", 1, true) then
                return "FASTEST: Hearthstone to Ratchet, then ride south along the coast to Islen Waterseer around 65.8, 43.8.", "hearth"
            end
            if step.questID == 6981 then
                return "FASTEST: Use the Orgrimmar flight master and fly to Ratchet if the route is available. Your quest contact Sputtervalve is in Ratchet, so this skips the long ride through Durotar and The Barrens.", "flight"
            else
                return "FASTEST: Use the Orgrimmar flight master and fly to Ratchet if the route is available. From Ratchet, ride south along the coast to Islen Waterseer around 65.8, 43.8.", "flight"
            end
        elseif zoneMatchesAliases({ "The Barrens", "Barrens", "Ratchet" }) then
            if step.questID == 6981 then
                if currentNextQuestPickup and currentNextQuestPickup.npc == "Falla Sagewind" then
                    local d = currentNextQuestPickup.waypoint and waypointDistanceNormalized(currentNextQuestPickup.waypoint)
                    if d and d <= 0.08 then
                        return "LOCAL ROUTE: You are already close to Falla Sagewind on the Wailing Caverns mountain. Follow the arrow to the next quest giver; do not return to Sputtervalve or take a flight.", "local-next-pickup"
                    end
                    return "LOCAL ROUTE: The Ratchet step is done. Head to Falla Sagewind on top of the Wailing Caverns mountain around 48.2, 32.8 for the next quest.", "local-next-pickup"
                end
                return "LOCAL ROUTE: If The Glowing Shard is not complete yet, stay in Ratchet and speak with Sputtervalve near the flight master.", "local"
            else
                return "LOCAL ROUTE: If you are in Ratchet, head south along the coast. Islen Waterseer is around 65.8, 43.8.", "local"
            end
        elseif hearth.ready then
            return string.format("HEARTH READY: Bound to %s. Use it only if that destination puts you closer to Ratchet/The Barrens than your current route.", hearth.bind or "Unknown"), "hearth-check"
        end
    end

    if hearth.hasStone then
        if hearth.ready then
            return string.format("Hearthstone ready (bound to %s). Use it if that bind is closer to the current objective.", hearth.bind or "Unknown"), "hearth-check"
        elseif hearth.cooldown and hearth.cooldown > 0 then
            return string.format("Hearthstone on cooldown: about %d min remaining.", math.ceil(hearth.cooldown / 60)), "hearth-cooldown"
        end
    end

    return nil, nil
end

local function getTravelInstruction(step)
    if not step then return nil, nil, nil, nil end
    if step.travelGuide then
        local fallback
        for _, travel in ipairs(step.travelGuide) do
            if travel.zoneAliases then
                if zoneMatchesAliases(travel.zoneAliases) then
                    return getNavigationStep(step, travel)
                end
            else
                fallback = travel
            end
        end
        if fallback then return getNavigationStep(step, fallback) end
    end
    return nil, step.waypoint, nil, nil
end

local function getObjectiveProgress(active)
    if not active or not active.objectives or #active.objectives == 0 then
        return 0
    end

    local totalProgress = 0
    local objectiveCount = 0

    for _, obj in ipairs(active.objectives) do
        objectiveCount = objectiveCount + 1

        if obj.finished then
            totalProgress = totalProgress + 1
        else
            local text = obj.text or ""
            local current, required = string.match(text, "(%d+)%s*/%s*(%d+)")
            current = tonumber(current)
            required = tonumber(required)

            if current and required and required > 0 then
                totalProgress = totalProgress + math.max(0, math.min(current / required, 1))
            end
        end
    end

    if objectiveCount == 0 then return 0 end
    return totalProgress / objectiveCount
end

local function getActiveClusterCounts(byID)
    local counts = {}
    local level = UnitLevel("player") or 1
    local _, playerClass = UnitClass("player")

    for _, step in ipairs(Data.route or {}) do
        local active = byID[step.questID]
        if active and routeStepEligible(step, level, playerClass)
            and step.cluster and not isQuestCompleted(step.questID) then
            counts[step.cluster] = (counts[step.cluster] or 0) + 1
        end
    end
    return counts
end

local function getWaypointProximityBonus(step, active)
    local weights = Data.scoring or {}
    local maxBonus = weights.waypointNearMax or 0

    -- Score the place the player actually needs to go next. For completed
    -- quests this is the turn-in, not the original quest/objective waypoint.
    local waypoint = nil
    local targetLabel = "verified target"
    if step and active and active.isComplete and step.turnInTarget and step.turnInTarget.waypoint then
        waypoint = step.turnInTarget.waypoint
        targetLabel = "turn-in nearby"
    elseif step and active and not active.isComplete and getBestObjectiveTarget then
        local objectiveTarget = getBestObjectiveTarget(step, active)
        if objectiveTarget and objectiveTarget.waypoint then
            waypoint = objectiveTarget.waypoint
            targetLabel = "next objective nearby"
        else
            waypoint = step.waypoint
        end
    elseif step then
        waypoint = step.waypoint
    end

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
        return bonus, string.format("%s (+%d)", targetLabel, bonus)
    end
    return 0, nil
end

local function hasIncompletePrimaryInCluster(step)
    if not step or not step.cluster or not currentByID then return false end

    local cluster = Data.clusters and Data.clusters[step.cluster]
    if not cluster or not cluster.finishBeforeTurnIn then return false end

    local level = UnitLevel("player") or 1
    local _, playerClass = UnitClass("player")
    for _, otherStep in ipairs(Data.route or {}) do
        if otherStep.questID ~= step.questID
            and otherStep.cluster == step.cluster
            and not otherStep.backgroundQuest
            and routeStepEligible(otherStep, level, playerClass) then
            local otherActive = currentByID[otherStep.questID]
            if otherActive and not otherActive.isComplete and not isQuestCompleted(otherStep.questID) then
                return true
            end
        end
    end

    return false
end

local function getNearestUnfinishedClusterObjective(step)
    if not step or not step.cluster or not currentByID then return nil, nil end

    local level = UnitLevel("player") or 1
    local _, playerClass = UnitClass("player")
    local bestStep, bestDistance = nil, nil

    for _, otherStep in ipairs(Data.route or {}) do
        if otherStep.questID ~= step.questID
            and otherStep.cluster == step.cluster
            and not otherStep.backgroundQuest
            and routeStepEligible(otherStep, level, playerClass)
            and not isQuestCompleted(otherStep.questID) then

            local otherActive = currentByID[otherStep.questID]
            if otherActive and not otherActive.isComplete then
                local target = getBestObjectiveTarget and getBestObjectiveTarget(otherStep, otherActive) or nil
                local waypoint = target and target.waypoint or otherStep.waypoint
                local distance = waypoint and waypointDistanceNormalized(waypoint) or nil
                if distance and (not bestDistance or distance < bestDistance) then
                    bestStep, bestDistance = otherStep, distance
                end
            end
        end
    end

    return bestStep, bestDistance
end

local function normalizeTurnInHub(zone)
    zone = tostring(zone or "")
    local hub = string.match(zone, "^%s*([^,]+)") or zone
    hub = string.gsub(hub, "^%s+", "")
    hub = string.gsub(hub, "%s+$", "")
    return hub
end

local function getCompletedTurnInBatch(byID, anchorStep)
    local batch = {
        hub = nil,
        mapID = nil,
        entries = {},
    }
    if not byID or not anchorStep or not anchorStep.turnInTarget
        or not anchorStep.turnInTarget.waypoint then
        return nil
    end

    local anchorHub = normalizeTurnInHub(anchorStep.turnInTarget.zone)
    local anchorMapID = anchorStep.turnInTarget.waypoint.mapID
    if anchorHub == "" or not anchorMapID then return nil end

    local level = UnitLevel("player") or 1
    local _, playerClass = UnitClass("player")

    for _, routeStep in ipairs(Data.route or {}) do
        local active = byID[routeStep.questID]
        local target = routeStep.turnInTarget
        if active and active.isComplete
            and not isQuestCompleted(routeStep.questID)
            and routeStepEligible(routeStep, level, playerClass)
            and target and target.waypoint
            and target.waypoint.mapID == anchorMapID
            and normalizeTurnInHub(target.zone) == anchorHub then

            batch.entries[#batch.entries + 1] = {
                step = routeStep,
                active = active,
                target = target,
                distance = waypointDistanceNormalized(target.waypoint),
            }
        end
    end

    if #batch.entries < 2 then return nil end

    table.sort(batch.entries, function(a, b)
        if a.distance and b.distance and a.distance ~= b.distance then
            return a.distance < b.distance
        elseif a.distance and not b.distance then
            return true
        elseif b.distance and not a.distance then
            return false
        end
        local ap = (a.step and a.step.clusterPriority) or 999
        local bp = (b.step and b.step.clusterPriority) or 999
        if ap ~= bp then return ap < bp end
        return tostring(a.step and a.step.title or "") < tostring(b.step and b.step.title or "")
    end)

    batch.hub = anchorHub
    batch.mapID = anchorMapID
    batch.count = #batch.entries
    batch.first = batch.entries[1]
    return batch
end

local function getWorthwhileCurrentMapObjective(excludeQuestID)
    if not currentByID or not C_Map or not C_Map.GetBestMapForUnit then return nil end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then return nil end

    local level = UnitLevel("player") or 1
    local _, playerClass = UnitClass("player")
    local weights = Data.scoring or {}
    local tagScores = weights.tag or {}
    local clusterCounts = getActiveClusterCounts(currentByID)
    local bestStep, bestWaypoint, bestScore = nil, nil, nil

    for _, otherStep in ipairs(Data.route or {}) do
        local otherActive = currentByID[otherStep.questID]
        local tag = otherStep.tag or "DO"

        if otherStep.questID ~= excludeQuestID
            and otherActive
            and not otherActive.isComplete
            and not otherStep.backgroundQuest
            and (tag == "IMPORTANT" or tag == "DO")
            and routeStepEligible(otherStep, level, playerClass)
            and not isQuestCompleted(otherStep.questID) then

            local target = getBestObjectiveTarget and getBestObjectiveTarget(otherStep, otherActive) or nil
            local waypoint = target and target.waypoint or otherStep.waypoint

            if waypoint and waypoint.mapID == playerMapID then
                -- Mirror the normal unfinished-quest scoring path without
                -- calling scoreRouteStep(), which would recurse back through
                -- completed-turn-in deferral.
                local score = tagScores[tag] or 0

                local progress = getObjectiveProgress(otherActive)
                if progress > 0 then
                    score = score + math.floor((weights.partialProgressMax or 0) * progress)
                end

                if otherStep.cluster then
                    local count = clusterCounts[otherStep.cluster] or 1
                    if count > 1 then
                        score = score + ((count - 1) * (weights.clusterQuest or 0))
                    end
                    if zoneMatchesCluster(otherStep.cluster) then
                        score = score + (weights.currentZoneCluster or 0)
                    elseif DB and DB.lastCluster == otherStep.cluster then
                        score = score + (weights.rememberedCluster or 0)
                    end
                end

                if otherStep.clusterPriority then
                    local maxPriority = weights.clusterPriorityMax or 0
                    score = score + math.max(0, maxPriority - ((otherStep.clusterPriority - 1) * 5))
                end

                local waypointBonus = getWaypointProximityBonus(otherStep, otherActive)
                score = score + (waypointBonus or 0)

                if otherStep.speedXP and tonumber(otherStep.speedXP) and tonumber(otherStep.speedXP) > 0 then
                    score = score + math.min(weights.speedXPMax or 120, tonumber(otherStep.speedXP))
                end

                if otherStep.questLevel then
                    local freeLevels = weights.staleQuestFreeLevels or 4
                    local over = level - (tonumber(otherStep.questLevel) or level) - freeLevels
                    if over > 0 then
                        score = score - (over * (weights.staleQuestPenaltyPerLevel or 35))
                    end
                end

                if not bestScore or score > bestScore then
                    bestStep, bestWaypoint, bestScore = otherStep, waypoint, score
                elseif score == bestScore and bestStep then
                    local currentPriority = tonumber(otherStep.clusterPriority) or 999
                    local bestPriority = tonumber(bestStep.clusterPriority) or 999
                    if currentPriority < bestPriority then
                        bestStep, bestWaypoint = otherStep, waypoint
                    end
                end
            end
        end
    end

    return bestStep, bestWaypoint, bestScore
end

local function getCompletedTurnInDecision(step, active, quickPickup)
    if not step or not active or not active.isComplete then return nil, nil end

    if quickPickup
        and quickPickup.classification == "PICK UP NOW"
        and quickPickup.distance
        and quickPickup.distance <= 0.05 then
        return "QUICK PICKUP FIRST", "verified worthwhile pickup is right beside you"
    end

    -- Do not leave the current map just to cash in a normal completed quest
    -- while worthwhile DO/IMPORTANT field work is still available here.
    -- IMPORTANT completed quests are exempt so class/progression steps can win.
    local turnWaypoint = step.turnInTarget and step.turnInTarget.waypoint or nil
    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if (step.tag or "DO") ~= "IMPORTANT"
        and turnWaypoint and turnWaypoint.mapID
        and playerMapID and turnWaypoint.mapID ~= playerMapID then
        local localStep = getWorthwhileCurrentMapObjective(step.questID)
        if localStep then
            return "DEFER TURN-IN", "finish current-zone " .. tostring(localStep.title or "route work") .. " before cross-zone turn-in"
        end
    end

    if step.deferTurnInForQuestIDs then
        for _, deferQuestID in ipairs(step.deferTurnInForQuestIDs) do
            local deferActive = currentByID and currentByID[deferQuestID]
            if deferActive and not deferActive.isComplete and not isQuestCompleted(deferQuestID) then
                return "DEFER TURN-IN", "finish specified nearby route objective first"
            end
        end
    end

    local cluster = step.cluster and Data.clusters and Data.clusters[step.cluster] or nil
    if cluster and cluster.finishBeforeTurnIn and hasIncompletePrimaryInCluster(step) then
        return "DEFER TURN-IN", "finish this local quest cluster before leaving"
    end

    local turnDistance = step.turnInTarget
        and step.turnInTarget.waypoint
        and waypointDistanceNormalized(step.turnInTarget.waypoint)
        or nil
    local nearbyStep, nearbyDistance = getNearestUnfinishedClusterObjective(step)

    local weights = Data.scoring or {}
    local nearbyLimit = tonumber(weights.turnInDeferNearbyDistance) or 0.08
    local detourMargin = tonumber(weights.turnInDeferMargin) or 0.03
    if nearbyStep and nearbyDistance and nearbyDistance <= nearbyLimit
        and turnDistance and (nearbyDistance + detourMargin) < turnDistance then
        return "DEFER TURN-IN", "nearby " .. tostring(nearbyStep.title or "route objective") .. " is better before backtracking"
    end

    return "TURN IN NOW", "turn-in is the best immediate completed-quest action"
end

local function getEventUrgencyBonus(step, active)
    if not step or not active or active.isComplete or not step.eventUrgency then
        return 0, nil
    end

    local target = getBestObjectiveTarget and getBestObjectiveTarget(step, active) or nil
    local waypoint = target and target.waypoint or step.waypoint
    if not waypoint then return 0, nil end

    local distance = waypointDistanceNormalized(waypoint)
    if not distance then return 0, nil end

    local weights = Data.scoring or {}
    local maxDistance = tonumber(step.eventUrgencyDistance)
        or tonumber(weights.eventUrgencyDistance)
        or 0.08
    if distance > maxDistance then return 0, nil end

    local maxBonus = tonumber(step.eventUrgencyBonus)
        or tonumber(weights.eventUrgencyMax)
        or 0
    if maxBonus <= 0 then return 0, nil end

    -- Full urgency when right on top of the event start; taper smoothly to 0
    -- at the configured radius so escorts do not dominate from far away.
    local normalized = 1 - math.max(0, math.min(distance / maxDistance, 1))
    local bonus = math.floor((maxBonus * normalized) + 0.5)
    if bonus <= 0 then return 0, nil end

    return bonus, string.format("nearby escort/event — do before leaving (+%d)", bonus)
end

local function getTurnInChainBonus(step)
    if not step or not step.nextPickup or not step.nextPickup.questID then
        return 0, nil
    end

    local pickup = step.nextPickup
    local nextQuestID = tonumber(pickup.questID)
    if not nextQuestID or isQuestCompleted(nextQuestID) then
        return 0, nil
    end

    local nextStep = getStepByQuestID(nextQuestID)
    if nextStep and not routeStepEligible(nextStep) then
        return 0, nil
    end

    if nextStep and nextStep.pickupPrereqQuestIDs then
        for _, prereqID in ipairs(nextStep.pickupPrereqQuestIDs) do
            if tonumber(prereqID) ~= tonumber(step.questID) and not isQuestCompleted(prereqID) then
                return 0, nil
            end
        end
    end

    local weights = Data.scoring or {}
    local bonus = tonumber(weights.chainFollowupTurnIn) or 0
    local sameNPC = false

    local turnIn = step.turnInTarget
    if turnIn then
        local turnInName = string.lower(tostring(turnIn.name or turnIn.npc or ""))
        local pickupName = string.lower(tostring(pickup.npc or pickup.name or ""))
        if turnInName ~= "" and pickupName ~= "" and turnInName == pickupName then
            sameNPC = true
        else
            local a = turnIn.waypoint
            local b = pickup.waypoint
            if a and b and a.mapID == b.mapID and a.x and a.y and b.x and b.y then
                local dx, dy = a.x - b.x, a.y - b.y
                sameNPC = math.sqrt(dx * dx + dy * dy) <= 0.01
            end
        end
    end

    if sameNPC then
        bonus = bonus + (tonumber(weights.sameNpcFollowupTurnIn) or 0)
    end

    if bonus <= 0 then return 0, nil end

    if sameNPC then
        return bonus, string.format("unlocks same-NPC follow-up (+%d)", bonus)
    end
    return bonus, string.format("unlocks follow-up quest (+%d)", bonus)
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

        local decision, decisionReason = getCompletedTurnInDecision(step, active, nil)
        if decision == "DEFER TURN-IN" then
            local penalty = weights.smartTurnInDeferPenalty or weights.finishClusterBeforeTurnInPenalty or 400
            if decisionReason and string.find(decisionReason, "cross-zone", 1, true) then
                penalty = weights.crossZoneTurnInDeferPenalty or penalty
            end
            score = score - penalty
            reasons[#reasons + 1] = string.format("defer turn-in: %s (-%d)", tostring(decisionReason or "finish nearby work first"), penalty)
        else
            local chainBonus, chainReason = getTurnInChainBonus(step)
            if chainBonus > 0 then
                score = score + chainBonus
                reasons[#reasons + 1] = chainReason
            end
        end
    else
        local progress = getObjectiveProgress(active)
        if progress > 0 then
            local bonus = math.floor((weights.partialProgressMax or 0) * progress)
            score = score + bonus
            reasons[#reasons + 1] = string.format("quest progress %d%% (+%d)", math.floor((progress * 100) + 0.5), bonus)
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

    local waypointBonus, waypointReason = getWaypointProximityBonus(step, active)
    if waypointBonus > 0 then
        score = score + waypointBonus
        reasons[#reasons + 1] = waypointReason
    end

    local eventBonus, eventReason = getEventUrgencyBonus(step, active)
    if eventBonus > 0 then
        score = score + eventBonus
        reasons[#reasons + 1] = eventReason
    end

    -- Speed-first tuning. Data.speedXP is a curated XP/min value (0..120),
    -- used only to break ties between otherwise valid routed quests.
    if step.speedXP and tonumber(step.speedXP) and tonumber(step.speedXP) > 0 then
        local bonus = math.min(weights.speedXPMax or 120, tonumber(step.speedXP))
        score = score + bonus
        reasons[#reasons + 1] = string.format("fast XP/min (+%d)", bonus)
    end

    -- Quests far below the player's level lose value quickly. Keep a small
    -- grace band so efficient green quests in the same cluster still finish.
    if step.questLevel then
        local playerLevel = UnitLevel("player") or 1
        local freeLevels = weights.staleQuestFreeLevels or 4
        local over = playerLevel - (tonumber(step.questLevel) or playerLevel) - freeLevels
        if over > 0 then
            local penalty = over * (weights.staleQuestPenaltyPerLevel or 35)
            score = score - penalty
            reasons[#reasons + 1] = string.format("low XP for level (-%d)", penalty)
        end
    end

    return score, reasons
end

local function getNearbyClusterQuestNames(step, byID)
    local names = {}
    if not step or not step.cluster or not byID then return names end

    local _, playerClass = UnitClass("player")
    for _, routeStep in ipairs(Data.route or {}) do
        if routeStep.cluster == step.cluster and routeStep.questID ~= step.questID then
            local active = byID[routeStep.questID]
            if active and routeStepEligible(routeStep, UnitLevel("player") or 1, playerClass)
                and not isQuestCompleted(routeStep.questID) then
                local queueScore = nil
                if not routeStep.backgroundQuest then
                    local clusterCounts = getActiveClusterCounts(byID)
                    queueScore = select(1, scoreRouteStep(routeStep, active, clusterCounts))
                end
                names[#names + 1] = {
                    title = routeStep.title or active.title or ("Quest " .. tostring(routeStep.questID)),
                    priority = routeStep.clusterPriority or 999,
                    complete = active.isComplete and true or false,
                    background = routeStep.backgroundQuest and true or false,
                    score = queueScore,
                    step = routeStep,
                    active = active,
                }
            end
        end
    end

    table.sort(names, function(a, b)
        local function queueRank(item)
            if item.complete then return 3 end
            if item.background then return 1 end
            return 2
        end

        local rankA, rankB = queueRank(a), queueRank(b)
        if rankA ~= rankB then return rankA < rankB end

        -- Background quests stay directly behind STEP 1. Real unfinished
        -- quests are then ordered by live route score so proximity/progress
        -- can reshape the queue as the player moves.
        if rankA == 2 then
            local scoreA, scoreB = a.score or -999999, b.score or -999999
            if scoreA ~= scoreB then return scoreA > scoreB end
        end

        if a.priority ~= b.priority then return a.priority < b.priority end
        return tostring(a.title) < tostring(b.title)
    end)

    return names
end

local function getCurrentDungeonCluster()
    for clusterID, cluster in pairs(Data.clusters or {}) do
        if cluster.dungeon and zoneMatchesCluster(clusterID) then
            return clusterID
        end
    end
    return nil
end

local function chooseRouteStep(byID)
    local level = UnitLevel("player") or 1
    currentCluster = nil
    currentClusterCount = 0
    currentRouteScore = nil
    currentRouteReasons = {}

    local clusterCounts = getActiveClusterCounts(byID)
    local bestStep, bestActive, bestScore, bestReasons = nil, nil, -999999, nil
    local insideDungeonCluster = getCurrentDungeonCluster()

    if insideDungeonCluster then
        for _, step in ipairs(Data.route or {}) do
            local active = byID[step.questID]
            local _, playerClass = UnitClass("player")
            if step.dungeon and step.cluster == insideDungeonCluster and active
                and routeStepEligible(step, level, playerClass)
                and not step.backgroundQuest
                and not active.isComplete and not isQuestCompleted(step.questID) then
                local score, reasons = scoreRouteStep(step, active, clusterCounts)
                score = score + 1000
                reasons[#reasons + 1] = "inside this dungeon (+1000)"
                if score > bestScore then
                    bestStep, bestActive, bestScore, bestReasons = step, active, score, reasons
                end
            end
        end
    end

    if not bestStep then
    for _, step in ipairs(Data.route or {}) do
        local active = byID[step.questID]
        local _, playerClass = UnitClass("player")
        if active and routeStepEligible(step, level, playerClass)
            and not step.backgroundQuest
            and not isQuestCompleted(step.questID) then
            local score, reasons = scoreRouteStep(step, active, clusterCounts)
            if score > bestScore then
                bestStep = step
                bestActive = active
                bestScore = score
                bestReasons = reasons
            end
        end
    end
    end

    -- GPS-style anti-flip-flop: keep the current primary quest when it is
    -- still valid and the new candidate is only marginally better. A meaningful
    -- proximity/progress advantage will still switch the route automatically.
    if bestStep and currentRouteStep and currentRouteStep.questID
        and currentRouteStep.questID ~= bestStep.questID
        and not currentRouteStep.backgroundQuest then
        local previousActive = byID[currentRouteStep.questID]
        local _, playerClass = UnitClass("player")
        if previousActive
            and routeStepEligible(currentRouteStep, level, playerClass)
            and not isQuestCompleted(currentRouteStep.questID) then
            local previousScore, previousReasons = scoreRouteStep(currentRouteStep, previousActive, clusterCounts)
            local margin = (Data.scoring and Data.scoring.routeSwitchMargin) or 20
            if bestScore - previousScore < margin then
                bestStep, bestActive, bestScore, bestReasons =
                    currentRouteStep, previousActive, previousScore, previousReasons
                bestReasons[#bestReasons + 1] = string.format("route stability: challenger under %d-point switch margin", margin)
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

    local fallback
    local _, playerClass = UnitClass("player")
    if playerClass == "SHAMAN" and Data.shamanRaceFallback then
        local raceKeys = getPlayerRaceKeys()
        local raceFallback
        if raceKeys.ORC or raceKeys.TROLL then
            raceFallback = Data.shamanRaceFallback.DUROTAR
        elseif raceKeys.TAUREN then
            raceFallback = Data.shamanRaceFallback.MULGORE
        elseif raceKeys.SKYBORNE then
            raceFallback = Data.shamanRaceFallback.ZEPHRAS
        end
        fallback = raceFallback and raceFallback[level]
    end
    fallback = fallback or (Data.fallback and Data.fallback[level])

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
frame:SetResizeBounds(340, 140, 700, 300)
frame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
frame:SetBackdropColor(0.035, 0.045, 0.055, 0.96)
frame:SetBackdropBorderColor(0.16, 0.20, 0.23, 1.0)

local headerBar = frame:CreateTexture(nil, "BACKGROUND")
headerBar:SetPoint("TOPLEFT", 1, -1)
headerBar:SetPoint("TOPRIGHT", -1, -1)
headerBar:SetHeight(28)
headerBar:SetTexture("Interface/Buttons/WHITE8x8")
headerBar:SetVertexColor(0.055, 0.070, 0.082, 1.0)

local headerAccent = frame:CreateTexture(nil, "ARTWORK")
headerAccent:SetPoint("BOTTOMLEFT", headerBar, "BOTTOMLEFT", 0, 0)
headerAccent:SetPoint("BOTTOMRIGHT", headerBar, "BOTTOMRIGHT", 0, 0)
headerAccent:SetHeight(2)
headerAccent:SetTexture("Interface/Buttons/WHITE8x8")
headerAccent:SetVertexColor(0.20, 0.82, 0.74, 0.95)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 14, -11)
title:SetText("|cff64d8c8Forever Leveling Coach|r")

local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
subtitle:SetPoint("LEFT", title, "RIGHT", 6, 0)
subtitle:SetText("|cff73808aHorde • 1-30|r")

local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
versionText:SetPoint("TOPRIGHT", -12, -11)
versionText:SetText("v" .. tostring(Data.version or "?"))

local function focusCurrentQuest()
    local questID = currentRouteStep and currentRouteStep.questID
    if not questID then
        print("|cffffcc00FLC:|r no active routed quest to open.")
        return
    end

    local tracked = false
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        local ok = pcall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        tracked = ok
    end

    local opened = false
    if type(QuestMapFrame_OpenToQuestDetails) == "function" then
        opened = pcall(QuestMapFrame_OpenToQuestDetails, questID)
    elseif C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
        pcall(C_QuestLog.SetSelectedQuest, questID)
        if type(ToggleQuestLog) == "function" then
            opened = pcall(ToggleQuestLog)
        elseif type(OpenQuestLog) == "function" then
            opened = pcall(OpenQuestLog)
        end
    elseif type(ToggleQuestLog) == "function" then
        opened = pcall(ToggleQuestLog)
    end

    if tracked and opened then
        print("|cff33ff99FLC:|r tracking and opened " .. tostring(currentRouteStep.title or questID) .. ".")
    elseif tracked then
        print("|cff33ff99FLC:|r tracking " .. tostring(currentRouteStep.title or questID) .. ".")
    elseif opened then
        print("|cff33ff99FLC:|r opened quest details.")
    else
        print("|cffffcc00FLC:|r this Forever client did not expose a supported quest-focus API.")
    end
end

local function flcStyleFlatButton(button, accent)
    if not button then return end
    local normal = button:GetNormalTexture()
    local highlight = button:GetHighlightTexture()
    local pushed = button:GetPushedTexture()

    if button.Left then button.Left:Hide() end
    if button.Middle then button.Middle:Hide() end
    if button.Right then button.Right:Hide() end
    if button.LeftDisabled then button.LeftDisabled:Hide() end
    if button.MiddleDisabled then button.MiddleDisabled:Hide() end
    if button.RightDisabled then button.RightDisabled:Hide() end

    button:SetNormalTexture("Interface/Buttons/WHITE8x8")
    button:SetHighlightTexture("Interface/Buttons/WHITE8x8", "ADD")
    button:SetPushedTexture("Interface/Buttons/WHITE8x8")
    normal = button:GetNormalTexture()
    highlight = button:GetHighlightTexture()
    pushed = button:GetPushedTexture()

    if normal then normal:SetVertexColor(0.075, 0.095, 0.11, 1.0) end
    if highlight then highlight:SetVertexColor(accent and 0.20 or 0.11, accent and 0.82 or 0.16, accent and 0.74 or 0.20, 0.22) end
    if pushed then pushed:SetVertexColor(0.10, 0.16, 0.17, 1.0) end

    local text = button:GetFontString()
    if text then
        text:SetTextColor(accent and 0.42 or 0.82, accent and 0.92 or 0.86, accent and 0.86 or 0.89)
    end
end

local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
exportButton:SetSize(54, 20)
exportButton:SetPoint("TOPRIGHT", -10, -32)
exportButton:SetText("Export")
flcStyleFlatButton(exportButton, false)

local goButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
goButton:SetSize(36, 20)
goButton:SetPoint("RIGHT", exportButton, "LEFT", -4, 0)
goButton:SetText("Go")
flcStyleFlatButton(goButton, true)
goButton:SetScript("OnClick", focusCurrentQuest)

local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
settingsButton:SetSize(58, 20)
settingsButton:SetPoint("RIGHT", goButton, "LEFT", -4, 0)
settingsButton:SetText("Settings")
flcStyleFlatButton(settingsButton, false)

exportButton:SetScript("OnClick", function()
    syncQuests()
    exportSnapshot()
end)

local routeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
routeLabel:SetPoint("TOPLEFT", 14, -34)
routeLabel:SetText("|cff6f7f88CURRENT OBJECTIVE|r")

local objectiveHighlight = frame:CreateTexture(nil, "BACKGROUND")
objectiveHighlight:SetPoint("TOPLEFT", 10, -46)
objectiveHighlight:SetPoint("TOPRIGHT", -10, -46)
objectiveHighlight:SetHeight(24)
objectiveHighlight:SetTexture("Interface/Buttons/WHITE8x8")
objectiveHighlight:SetVertexColor(0.060, 0.078, 0.090, 0.95)

local objectiveAccent = frame:CreateTexture(nil, "ARTWORK")
objectiveAccent:SetPoint("TOPLEFT", objectiveHighlight, "TOPLEFT", 0, 0)
objectiveAccent:SetPoint("BOTTOMLEFT", objectiveHighlight, "BOTTOMLEFT", 0, 0)
objectiveAccent:SetWidth(3)
objectiveAccent:SetTexture("Interface/Buttons/WHITE8x8")
objectiveAccent:SetVertexColor(0.20, 0.82, 0.74, 1.0)

local routeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
routeText:SetPoint("TOPLEFT", 14, -50)
routeText:SetPoint("TOPRIGHT", -14, -50)
routeText:SetJustifyH("LEFT")
routeText:SetText("Loading route...")
routeText:SetTextColor(0.38, 0.82, 0.76)

local routeClickButton = CreateFrame("Button", nil, frame)
routeClickButton:SetPoint("TOPLEFT", routeText, "TOPLEFT", -2, 4)
routeClickButton:SetPoint("BOTTOMRIGHT", routeText, "BOTTOMRIGHT", 2, -4)
routeClickButton:RegisterForClicks("LeftButtonUp")
routeClickButton:SetScript("OnClick", focusCurrentQuest)
routeClickButton:SetScript("OnEnter", function()
    if GameTooltip then
        GameTooltip:SetOwner(routeClickButton, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Click to track/open this quest")
        GameTooltip:Show()
    end
end)
routeClickButton:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
end)

local mainScroll = CreateFrame("ScrollFrame", "ForeverLevelingCoachMainScroll", frame, "UIPanelScrollFrameTemplate")
mainScroll:SetPoint("TOPLEFT", routeText, "BOTTOMLEFT", 0, -6)
mainScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 10)
mainScroll:EnableMouseWheel(true)

local mainScrollChild = CreateFrame("Frame", nil, mainScroll)
mainScrollChild:SetSize(1, 1)
mainScroll:SetScrollChild(mainScrollChild)
if mainScroll.ScrollBar and mainScroll.ScrollBar.SetAlpha then
    mainScroll.ScrollBar:SetAlpha(0.38)
end
local legacyScrollBar = _G["ForeverLevelingCoachMainScrollScrollBar"]
if legacyScrollBar and legacyScrollBar.SetAlpha then
    legacyScrollBar:SetAlpha(0.38)
end

local questCards = {}

local function isQuestInCleanup(questID)
    questID = tonumber(questID)
    if not questID then return false end
    for _, item in ipairs(currentQuestCleanup or {}) do
        if tonumber(item.questID) == questID then
            return true
        end
    end
    return false
end

local function abandonCleanupQuest(questID)
    questID = tonumber(questID)
    if not questID or not isQuestInCleanup(questID) then
        print("|cffffcc00FLC:|r That quest is no longer marked safe to drop.")
        return
    end
    if not currentByID or not currentByID[questID] then
        print("|cffffcc00FLC:|r That quest is no longer in your quest log.")
        return
    end

    local selected = false
    if C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
        local ok = pcall(C_QuestLog.SetSelectedQuest, questID)
        selected = ok and true or false
    end

    local prepared = false
    if C_QuestLog and type(C_QuestLog.SetAbandonQuest) == "function" then
        prepared = pcall(C_QuestLog.SetAbandonQuest)
    elseif type(SetAbandonQuest) == "function" then
        prepared = pcall(SetAbandonQuest)
    end

    local abandoned = false
    if C_QuestLog and type(C_QuestLog.AbandonQuest) == "function" then
        abandoned = pcall(C_QuestLog.AbandonQuest)
    elseif type(AbandonQuest) == "function" then
        abandoned = pcall(AbandonQuest)
    end

    if abandoned then
        print("|cff33ff99FLC:|r Dropped " .. tostring(currentByID[questID] and currentByID[questID].title or ("Quest " .. tostring(questID))) .. ".")
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.2, function()
                if syncQuests then syncQuests() end
            end)
        elseif syncQuests then
            syncQuests()
        end
    elseif selected or prepared then
        print("|cffffcc00FLC:|r The client did not allow FLC to finish abandoning this quest automatically.")
    else
        print("|cffffcc00FLC:|r Quest abandon API is unavailable on this client.")
    end
end

if StaticPopupDialogs then
    StaticPopupDialogs["FLC_CONFIRM_DROP_QUEST"] = {
        text = "Drop %s?\n\nForever Leveling Coach marked this optional quest safe to abandon.",
        button1 = "Drop Quest",
        button2 = "Cancel",
        OnAccept = function(_, data)
            if data and data.questID then
                abandonCleanupQuest(data.questID)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function createQuestCard(index)
    local card = CreateFrame("Frame", nil, mainScrollChild, "BackdropTemplate")
    card:SetHeight(index == 1 and 50 or 42)
    card:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    card:SetBackdropColor(index == 1 and 0.055 or 0.043, index == 1 and 0.078 or 0.055, index == 1 and 0.090 or 0.064, 0.98)
    card:SetBackdropBorderColor(0.10, 0.13, 0.15, 0.92)

    card.accent = card:CreateTexture(nil, "ARTWORK")
    card.accent:SetPoint("TOPLEFT", 0, 0)
    card.accent:SetPoint("BOTTOMLEFT", 0, 0)
    card.accent:SetWidth(index == 1 and 3 or 2)
    card.accent:SetTexture("Interface/Buttons/WHITE8x8")

    card.step = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.step:SetPoint("TOPLEFT", 9, -5)

    card.status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("LEFT", card.step, "RIGHT", 6, 0)

    card.title = card:CreateFontString(nil, "OVERLAY", index == 1 and "GameFontNormal" or "GameFontHighlightSmall")
    card.title:SetPoint("TOPLEFT", 9, index == 1 and -19 or -17)
    card.title:SetPoint("TOPRIGHT", -7, index == 1 and -19 or -17)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)

    card.action = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.action:SetPoint("TOPLEFT", 9, index == 1 and -34 or -29)
    card.action:SetPoint("TOPRIGHT", -7, index == 1 and -34 or -29)
    card.action:SetJustifyH("LEFT")
    card.action:SetWordWrap(false)

    card.dropButton = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    card.dropButton:SetSize(50, 20)
    card.dropButton:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    card.dropButton:SetText("DROP")
    card.dropButton:Hide()
    card.dropButton:SetScript("OnClick", function(self)
        local questID = self.questID
        if not questID then return end

        local title = currentByID and currentByID[questID] and currentByID[questID].title
            or ("Quest " .. tostring(questID))
        if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs["FLC_CONFIRM_DROP_QUEST"] then
            StaticPopup_Show("FLC_CONFIRM_DROP_QUEST", title, nil, { questID = questID })
        else
            abandonCleanupQuest(questID)
        end
    end)
    card.dropButton:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Drop this quest")
            GameTooltip:AddLine("Only shown for quests FLC currently marks safe to abandon.", 0.75, 0.82, 0.85, true)
            GameTooltip:Show()
        end
    end)
    card.dropButton:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    card:Hide()
    return card
end

for i = 1, 8 do
    questCards[i] = createQuestCard(i)
end

local cardListHeight = 0

local function renderQuestCards(cards)
    local previous = nil
    local shown = 0
    for i, card in ipairs(questCards) do
        local info = cards and cards[i] or nil
        card:ClearAllPoints()
        if info then
            shown = shown + 1
            local primary = i == 1
            card:SetHeight(primary and 50 or 42)
            if previous then
                card:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
                card:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -4)
            else
                card:SetPoint("TOPLEFT", mainScrollChild, "TOPLEFT", 0, 0)
                card:SetPoint("TOPRIGHT", mainScrollChild, "TOPRIGHT", 0, 0)
            end

            card.step:SetText(info.label or ("STEP " .. tostring(info.step or i)))
            card.status:SetText(info.status or "")
            card.title:SetText(info.title or "")
            card.action:SetText(info.action or "")
            card.action:SetShown(info.action and info.action ~= "")

            local showDrop = info.dropQuestID and true or false
            card.dropButton.questID = showDrop and tonumber(info.dropQuestID) or nil
            card.dropButton:SetShown(showDrop)
            card.title:SetPoint("TOPRIGHT", showDrop and -62 or -7, primary and -19 or -17)
            card.action:SetPoint("TOPRIGHT", showDrop and -62 or -7, primary and -34 or -29)

            if primary then
                card.accent:SetVertexColor(0.20, 0.82, 0.74, 1.0)
                card.step:SetTextColor(0.38, 0.82, 0.76)
                card.status:SetTextColor(0.46, 0.90, 0.69)
                card.title:SetTextColor(0.95, 0.97, 0.98)
                card.action:SetTextColor(0.76, 0.82, 0.85)
            elseif info.pickup then
                local pickupNow = info.pickupClass == "PICK UP NOW"
                card.accent:SetVertexColor(pickupNow and 0.20 or 0.32, pickupNow and 0.82 or 0.58, pickupNow and 0.74 or 0.58, pickupNow and 0.95 or 0.65)
                card.step:SetTextColor(pickupNow and 0.38 or 0.55, pickupNow and 0.82 or 0.68, pickupNow and 0.76 or 0.68)
                card.status:SetTextColor(pickupNow and 0.46 or 0.62, pickupNow and 0.90 or 0.72, pickupNow and 0.69 or 0.72)
                card.title:SetTextColor(0.86, 0.91, 0.92)
                card.action:SetTextColor(0.66, 0.74, 0.76)
            elseif info.dataGap then
                card.accent:SetVertexColor(0.92, 0.58, 0.20, 0.95)
                card.step:SetTextColor(0.92, 0.64, 0.28)
                card.status:SetTextColor(1.00, 0.72, 0.30)
                card.title:SetTextColor(0.92, 0.91, 0.86)
                card.action:SetTextColor(0.72, 0.70, 0.64)
            elseif info.background then
                card.accent:SetVertexColor(0.32, 0.38, 0.41, 0.55)
                card.step:SetTextColor(0.42, 0.48, 0.51)
                card.status:SetTextColor(0.45, 0.52, 0.55)
                card.title:SetTextColor(0.55, 0.60, 0.62)
                card.action:SetTextColor(0.45, 0.50, 0.52)
            else
                card.accent:SetVertexColor(0.24, 0.42, 0.43, 0.70)
                card.step:SetTextColor(0.45, 0.52, 0.55)
                card.status:SetTextColor(0.55, 0.66, 0.69)
                card.title:SetTextColor(0.76, 0.81, 0.83)
                card.action:SetTextColor(0.58, 0.64, 0.67)
            end

            card:Show()
            previous = card
        else
            card.dropButton.questID = nil
            card.dropButton:Hide()
            card:Hide()
        end
    end

    if shown == 0 then
        cardListHeight = 0
    else
        cardListHeight = 50 + math.max(0, shown - 1) * 46
    end
end

local detailText = mainScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
detailText:SetPoint("TOPLEFT", mainScrollChild, "TOPLEFT", 0, -4)
detailText:SetPoint("TOPRIGHT", mainScrollChild, "TOPRIGHT", 0, -4)
detailText:SetJustifyH("LEFT")
detailText:SetJustifyV("TOP")
detailText:SetText("")

local questText = mainScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
questText:SetText("")
questText:Hide()

local function refreshMainScroll()
    local width = math.max(120, mainScroll:GetWidth())
    mainScrollChild:SetWidth(width)

    detailText:ClearAllPoints()
    if cardListHeight > 0 then
        local lastVisible = nil
        for _, card in ipairs(questCards) do
            if card:IsShown() then lastVisible = card end
        end
        if lastVisible then
            detailText:SetPoint("TOPLEFT", lastVisible, "BOTTOMLEFT", 4, -8)
            detailText:SetPoint("TOPRIGHT", lastVisible, "BOTTOMRIGHT", -4, -8)
        end
    else
        detailText:SetPoint("TOPLEFT", mainScrollChild, "TOPLEFT", 0, 0)
        detailText:SetPoint("TOPRIGHT", mainScrollChild, "TOPRIGHT", 0, 0)
    end

    local detailHeight = detailText:IsShown() and (detailText:GetStringHeight() or 0) or 0
    local contentHeight = cardListHeight + (detailHeight > 0 and (detailHeight + 12) or 0)
    mainScrollChild:SetHeight(math.max(mainScroll:GetHeight(), contentHeight))

    local needsScroll = contentHeight > (mainScroll:GetHeight() + 1)
    if mainScroll.ScrollBar then
        mainScroll.ScrollBar:SetShown(needsScroll)
    end
    if legacyScrollBar then
        legacyScrollBar:SetShown(needsScroll)
    end
    if not needsScroll then
        mainScroll:SetVerticalScroll(0)
    end
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
arrowFrame:SetSize(180, 96)
arrowFrame:SetMovable(true)
arrowFrame:EnableMouse(true)
arrowFrame:SetClampedToScreen(true)
arrowFrame:SetFrameStrata("HIGH")

-- Single-piece FLC navigation arrow. One texture, one rotation, no geometry drift.
local arrowTexture = arrowFrame:CreateTexture(nil, "ARTWORK")
arrowTexture:SetSize(46, 46)
arrowTexture:SetPoint("TOP", 0, 0)
arrowTexture:SetTexture("Interface\\AddOns\\ForeverLevelingCoach\\Media\\FLCArrow.tga")
arrowTexture:SetAlpha(0.92)

local arrowLabel = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
arrowLabel:SetPoint("TOP", arrowTexture, "BOTTOM", 0, -6)
arrowLabel:SetWidth(178)
arrowLabel:SetJustifyH("CENTER")
arrowLabel:SetTextColor(0.88, 0.94, 0.95)
arrowLabel:SetShadowOffset(1, -1)
arrowLabel:SetText("")

local arrowDistance = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
arrowDistance:SetPoint("TOP", arrowLabel, "BOTTOM", 0, -1)
arrowDistance:SetWidth(178)
arrowDistance:SetJustifyH("CENTER")
arrowDistance:SetTextColor(0.38, 0.82, 0.76)
arrowDistance:SetShadowOffset(1, -1)
arrowDistance:SetText("")

local travelHintFrame = CreateFrame("Frame", "ForeverLevelingCoachTravelHintFrame", UIParent, "BackdropTemplate")
travelHintFrame:SetSize(300, 90)
travelHintFrame:SetPoint("TOP", UIParent, "TOP", 0, -190)
travelHintFrame:SetFrameStrata("HIGH")
travelHintFrame:SetMovable(true)
travelHintFrame:SetResizable(true)
travelHintFrame:EnableMouse(true)
travelHintFrame:SetClampedToScreen(true)
travelHintFrame:SetResizeBounds(220, 70, 560, 260)
travelHintFrame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
travelHintFrame:SetBackdropColor(0.035, 0.045, 0.055, 0.94)
travelHintFrame:SetBackdropBorderColor(0.16, 0.20, 0.23, 1.0)

local travelHintTitle = travelHintFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
travelHintTitle:SetPoint("TOPLEFT", 10, -8)
travelHintTitle:SetPoint("TOPRIGHT", -10, -8)
travelHintTitle:SetJustifyH("LEFT")
travelHintTitle:SetText("Travel")

local travelHintText = travelHintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
travelHintText:SetPoint("TOPLEFT", travelHintTitle, "BOTTOMLEFT", 0, -4)
travelHintText:SetPoint("TOPRIGHT", travelHintFrame, "TOPRIGHT", -10, -26)
travelHintText:SetJustifyH("LEFT")
travelHintText:SetJustifyV("TOP")
travelHintText:SetWordWrap(true)
travelHintText:SetText("")

local travelHintResizeGrip = CreateFrame("Button", nil, travelHintFrame)
travelHintResizeGrip:SetSize(18, 18)
travelHintResizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
travelHintResizeGrip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
travelHintResizeGrip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
travelHintResizeGrip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")

local function saveTravelHintPosition()
    if not DB then return end
    local point, _, relativePoint, x, y = travelHintFrame:GetPoint(1)
    DB.travelHintPoint = point
    DB.travelHintRelativePoint = relativePoint
    DB.travelHintX = x
    DB.travelHintY = y
    DB.travelHintWidth = travelHintFrame:GetWidth()
    DB.travelHintHeight = travelHintFrame:GetHeight()
end

travelHintFrame:RegisterForDrag("LeftButton")
travelHintFrame:SetScript("OnDragStart", function(self)
    if DB and not DB.locked then self:StartMoving() end
end)
travelHintFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveTravelHintPosition()
end)

travelHintResizeGrip:SetScript("OnMouseDown", function()
    if DB and not DB.locked then travelHintFrame:StartSizing("BOTTOMRIGHT") end
end)
travelHintResizeGrip:SetScript("OnMouseUp", function()
    travelHintFrame:StopMovingOrSizing()
    saveTravelHintPosition()
end)

travelHintFrame:Hide()

local settingsFrame = CreateFrame("Frame", "ForeverLevelingCoachSettingsFrame", UIParent, "BackdropTemplate")
settingsFrame:SetSize(300, 430)
settingsFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:SetClampedToScreen(true)
settingsFrame:EnableMouse(true)
settingsFrame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8x8",
    edgeFile = "Interface/Buttons/WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
settingsFrame:SetBackdropColor(0.035, 0.045, 0.055, 0.98)
settingsFrame:SetBackdropBorderColor(0.16, 0.20, 0.23, 1.0)
settingsFrame:Hide()

local settingsTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
settingsTitle:SetPoint("TOPLEFT", 14, -14)
settingsTitle:SetText("FLC Settings")

local settingsClose = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
settingsClose:SetPoint("TOPRIGHT", -3, -3)

local settingsButtons = {}
local refreshSettingsPanel

local function addSettingsSection(text, y)
    local fs = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    local line = settingsFrame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    line:SetPoint("RIGHT", settingsFrame, "RIGHT", -16, 0)
    line:SetHeight(1)
    line:SetTexture("Interface/Buttons/WHITE8x8")
    line:SetVertexColor(0.20, 0.82, 0.74, 0.28)
    return fs
end

local function settingStateText(label, enabled)
    return tostring(label) .. "  [" .. (enabled and "|cff33ff99ON|r" or "|cffff5555OFF|r") .. "]"
end

local function makeSettingsToggle(label, key, x, y, width, onChanged)
    local button = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    button:SetSize(width or 126, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetScript("OnClick", function()
        if not DB then return end
        DB[key] = not DB[key]
        if onChanged then onChanged(DB[key]) end
        if syncQuests then syncQuests() end
        if refreshSettingsPanel then refreshSettingsPanel() end
    end)
    flcStyleFlatButton(button, false)
    settingsButtons[key] = { button = button, label = label }
    return button
end

addSettingsSection("GUIDE", -44)
makeSettingsToggle("Lazy Mode", "lazyMode", 16, -68, 128)
makeSettingsToggle("Beginner", "beginner", 154, -68, 128)
makeSettingsToggle("Auto Accept", "autoAccept", 16, -98, 128)
makeSettingsToggle("Auto Turn-In", "autoTurnIn", 154, -98, 128)

addSettingsSection("NAVIGATION", -136)
makeSettingsToggle("Arrow", "arrowVisible", 16, -160, 128)
makeSettingsToggle("Flight Assist", "autoFlight", 154, -160, 128)

addSettingsSection("ADVISORS", -198)
makeSettingsToggle("Gear Advice", "gearAdvisor", 16, -222, 128)
makeSettingsToggle("Relic Advisor", "relicAdvisor", 154, -222, 128)

addSettingsSection("INTERFACE", -260)

local displayModeButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
displayModeButton:SetSize(128, 24)
flcStyleFlatButton(displayModeButton, false)
displayModeButton:SetPoint("TOPLEFT", 16, -284)
displayModeButton:SetScript("OnClick", function()
    if not DB then return end
    DB.displayMode = (DB.displayMode == "DETAILED") and "COMPACT" or "DETAILED"
    if syncQuests then syncQuests() end
    if refreshSettingsPanel then refreshSettingsPanel() end
end)

local lockButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
lockButton:SetSize(128, 24)
flcStyleFlatButton(lockButton, false)
lockButton:SetPoint("TOPLEFT", 154, -284)
lockButton:SetScript("OnClick", function()
    if not DB then return end
    DB.locked = not DB.locked
    resizeGrip:SetShown(not DB.locked)
    arrowFrame:EnableMouse(not DB.locked)
    travelHintResizeGrip:SetShown(not DB.locked)
    if refreshSettingsPanel then refreshSettingsPanel() end
end)

local resetUIButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
resetUIButton:SetSize(128, 24)
flcStyleFlatButton(resetUIButton, false)
resetUIButton:SetPoint("TOPLEFT", 16, -314)
resetUIButton:SetText("Reset UI")
resetUIButton:SetScript("OnClick", function()
    if not DB then return end

    DB.point = defaults.point
    DB.relativePoint = defaults.relativePoint
    DB.x = defaults.x
    DB.y = defaults.y
    DB.width = defaults.width
    DB.height = defaults.height
    DB.scale = defaults.scale
    DB.alpha = defaults.alpha

    DB.arrowPoint = defaults.arrowPoint
    DB.arrowRelativePoint = defaults.arrowRelativePoint
    DB.arrowX = defaults.arrowX
    DB.arrowY = defaults.arrowY
    DB.arrowScale = defaults.arrowScale

    DB.travelHintPoint = defaults.travelHintPoint
    DB.travelHintRelativePoint = defaults.travelHintRelativePoint
    DB.travelHintX = defaults.travelHintX
    DB.travelHintY = defaults.travelHintY
    DB.travelHintWidth = defaults.travelHintWidth
    DB.travelHintHeight = defaults.travelHintHeight

    applySettings()
    if syncQuests then syncQuests() end
    print("|cff33ff99FLC:|r UI positions and sizes reset.")
end)

local gearSummaryButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
gearSummaryButton:SetSize(128, 24)
flcStyleFlatButton(gearSummaryButton, false)
gearSummaryButton:SetPoint("TOPLEFT", 154, -314)
gearSummaryButton:SetText("Gear Summary")
gearSummaryButton:SetScript("OnClick", function()
    local scan = flcGearScanSnapshot and flcGearScanSnapshot() or nil
    print("|cff33ff99FLC:|r gear upgrade summary:")
    local shown = 0
    for _, item in ipairs((scan and scan.priorities) or {}) do
        if shown >= 3 then break end
        if item.status ~= "OPTIONAL EMPTY" and item.status ~= "NOT EXPECTED YET" then
            local line = tostring(item.slotName) .. " — " .. tostring(item.status)
            if item.upgrade and item.upgrade.target then
                line = line .. ": " .. tostring(item.upgrade.target.name)
                    .. string.format(" (~+%d%%)", math.floor((item.upgrade.pct or 0) + 0.5))
            end
            print(line)
            shown = shown + 1
        end
    end
    if shown == 0 then print("|cff33ff99No urgent gear upgrades found.|r") end
end)

addSettingsSection("ACTIONS", -352)

local trainedButton = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
trainedButton:SetSize(266, 24)
flcStyleFlatButton(trainedButton, true)
trainedButton:SetPoint("TOPLEFT", 16, -376)
trainedButton:SetText("Mark Class Training Done")
trainedButton:SetScript("OnClick", function()
    if not DB then return end
    DB.lastClassTrainerLevel = UnitLevel("player") or DB.lastClassTrainerLevel or 0
    currentTrainingDue = false
    if syncQuests then syncQuests() end
    print("|cff33ff99FLC:|r marked class training complete for level " .. tostring(DB.lastClassTrainerLevel) .. ".")
end)

refreshSettingsPanel = function()
    if not DB then return end
    for key, entry in pairs(settingsButtons) do
        entry.button:SetText(settingStateText(entry.label, DB[key] and true or false))
    end
    displayModeButton:SetText("View: " .. tostring(DB.displayMode or "COMPACT"))
    lockButton:SetText(DB.locked and "Unlock UI" or "Lock UI")
end

settingsButton:SetScript("OnClick", function()
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        refreshSettingsPanel()
        settingsFrame:ClearAllPoints()
        settingsFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
        settingsFrame:Show()
    end
end)

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

local function nextUnfinishedObjective(active)
    if not active or not active.objectives then return nil end
    for _, obj in ipairs(active.objectives) do
        if not obj.finished and obj.text and obj.text ~= "" then
            return obj.text
        end
    end
    return nil
end

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

local currentArrowState = "hidden"
local currentArrowDebug = {}

local function updateTravelHint(message, state)
    if not travelHintFrame then return end
    if currentRouteStep and currentRouteStep.dungeon and zoneMatchesAliases({ "Wailing Caverns" }) then
        travelHintFrame:Hide()
        return
    end
    if message and message ~= "" and state ~= "active-same-map" then
        local hint = message
        if currentFastTravelSuggestion and currentFastTravelSuggestion ~= "" then
            if hint and hint ~= "" then
                hint = currentFastTravelSuggestion .. "\n" .. hint
            else
                hint = currentFastTravelSuggestion
            end
        end
        travelHintText:SetText(hint or "")
        travelHintFrame:Show()
    else
        travelHintFrame:Hide()
    end
end

local function updateArrow()
    if not DB or DB.arrowVisible == false or not currentRouteStep then
        currentArrowState = "hidden-disabled"
        currentArrowDebug = {}
        arrowFrame:Hide()
        updateTravelHint(currentTravelInstruction, currentArrowState)
        return
    end

    local _, waypoint, navIndex, navCount = getTravelInstruction(currentRouteStep)
    if currentNextQuestPickup and currentNextQuestPickup.useArrow and currentNextQuestPickup.waypoint then
        waypoint = currentNextQuestPickup.waypoint
    elseif currentPersonTarget and currentPersonTarget.useArrow and currentPersonTarget.waypoint then
        waypoint = currentPersonTarget.waypoint
    end
    currentNavigationWaypoint = waypoint
    currentNavigationStepIndex = navIndex
    currentNavigationStepCount = navCount
    if not waypoint or not waypoint.mapID or not waypoint.x or not waypoint.y then
        currentArrowState = "hidden-no-waypoint"
        currentArrowDebug = {}
        arrowFrame:Hide()
        updateTravelHint(currentTravelInstruction, currentArrowState)
        return
    end

    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not playerMapID then
        currentArrowState = "hidden-no-player-map"
        currentArrowDebug = {}
        arrowFrame:Hide()
        updateTravelHint(currentTravelInstruction, currentArrowState)
        return
    end

    -- Safety rule: never point across map/zone IDs. Cross-zone world-space
    -- conversion proved unreliable in the Forever beta and can send the player
    -- the wrong direction. Only point when player and target share a verified map.
    if playerMapID ~= waypoint.mapID then
        currentArrowState = "hidden-different-map"
        currentArrowDebug = {}
        arrowFrame:Hide()
        updateTravelHint(currentTravelInstruction, currentArrowState)
        return
    end

    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not pos then
        currentArrowState = "hidden-no-position"
        currentArrowDebug = {}
        arrowFrame:Hide()
        updateTravelHint(currentTravelInstruction, currentArrowState)
        return
    end

    local px, py = pos:GetXY()
    local dx, dy = waypoint.x - px, waypoint.y - py
    local targetAngle = atan2Safe(-dx, -dy)
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local relativeAngle = targetAngle - facing
    while relativeAngle > math.pi do relativeAngle = relativeAngle - (2 * math.pi) end
    while relativeAngle < -math.pi do relativeAngle = relativeAngle + (2 * math.pi) end

    currentArrowDebug = {
        playerMapID = playerMapID,
        playerX = px,
        playerY = py,
        targetMapID = waypoint.mapID,
        targetX = waypoint.x,
        targetY = waypoint.y,
        facing = facing,
        targetAngle = targetAngle,
        relativeAngle = relativeAngle,
    }

    local meters = getWaypointDistanceMeters(playerMapID, px, py, waypoint.x, waypoint.y)

    -- Arrival handling for Quick Pickup: once the player is close enough to
    -- interact, the arrow becomes visual noise. Hide it and turn the live HUD
    -- into a direct interaction prompt. If the player backs away, restore the
    -- normal Quick Pickup presentation automatically.
    local quickPickupArrival = currentQuickPickupSuggestion
        and currentPersonTarget
        and currentPersonTarget.waypoint == waypoint
        and meters
        and meters <= 8

    if quickPickupArrival then
        currentArrivalState = "quick-pickup-interact"
        currentArrowState = "arrived-quick-pickup"
        arrowFrame:Hide()
        updateTravelHint(nil, currentArrowState)

        routeText:SetText("Interact now")
        local topCard = questCards and questCards[1]
        if topCard and topCard:IsShown() then
            topCard.status:SetText("INTERACT NOW")
            local npc = currentQuickPickupSuggestion.pickup and currentQuickPickupSuggestion.pickup.npc
            topCard.action:SetText(npc and ("TALK TO " .. string.upper(tostring(npc))) or "INTERACT WITH QUEST GIVER")
            topCard.action:Show()
        end
        return
    end

    if currentArrivalState == "quick-pickup-interact" then
        currentArrivalState = nil
        if currentQuickPickupSuggestion then
            routeText:SetText(currentHubChainPickup and "Pick up follow-up" or "Quick pickup")
            local topCard = questCards and questCards[1]
            if topCard and topCard:IsShown() then
                topCard.status:SetText(currentHubChainPickup and "PICK UP NEXT" or "PICK UP NOW")
                local npc = currentQuickPickupSuggestion.pickup and currentQuickPickupSuggestion.pickup.npc
                topCard.action:SetText(npc and ("TALK TO " .. string.upper(tostring(npc))) or "PICK UP QUEST")
                topCard.action:Show()
            end
        end
    end

    arrowFrame:Show()
    currentArrowState = "active-same-map"
    updateTravelHint(nil, currentArrowState)
    arrowTexture:SetRotation(relativeAngle)

    local label = waypoint.label or currentRouteStep.title or "Route target"
    arrowLabel:SetText(label)
    if meters then
        if meters >= 1000 then
            arrowDistance:SetText(string.format("%.2f km", meters / 1000))
        else
            arrowDistance:SetText(string.format("%d m", math.floor(meters + 0.5)))
        end
    else
        local mapDistance = math.sqrt(dx * dx + dy * dy) * 100
        arrowDistance:SetText(string.format("%.1f%% map distance", mapDistance))
    end
end

local arrowElapsed = 0
arrowFrame:SetScript("OnUpdate", function(_, elapsed)
    arrowElapsed = arrowElapsed + elapsed
    if arrowElapsed >= 0.03 then
        arrowElapsed = 0
        updateArrow()
    end
end)

local function formatNextQuestPickup(pickup)
    if not pickup then return nil end
    local parts = {}
    if pickup.title then parts[#parts + 1] = pickup.title end
    if pickup.npc then parts[#parts + 1] = "from " .. pickup.npc end
    if pickup.zone then parts[#parts + 1] = "in " .. pickup.zone end
    if pickup.coords then parts[#parts + 1] = "around " .. pickup.coords end
    return table.concat(parts, " ")
end

local function normalizeTaxiName(name)
    return string.lower((name or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function taxiNameMatches(name, target)
    if not name or not target then return false end
    local n = normalizeTaxiName(name)
    local t = normalizeTaxiName(target)
    return n == t or string.find(n, t, 1, true) ~= nil
end

local function scanTaxiMapAndAutoFly()
    currentTaxiOptions = {}
    currentAutoFlightStatus = currentAutoFlightTarget and "waiting-for-flight-master" or "no-target"

    if not DB or not NumTaxiNodes or not TaxiNodeName or not TaxiNodeGetType then
        currentAutoFlightStatus = "taxi-api-unavailable"
        return
    end

    DB.knownFlightPaths = DB.knownFlightPaths or {}
    local count = NumTaxiNodes() or 0
    local targetReachable = false

    for i = 1, count do
        local name = TaxiNodeName(i)
        local nodeType = TaxiNodeGetType(i)
        if name and name ~= "" then
            local usable = nodeType == "REACHABLE" or nodeType == "CURRENT"
            if usable then
                currentTaxiOptions[#currentTaxiOptions + 1] = name
                DB.knownFlightPaths[name] = true
            end
            if currentAutoFlightTarget and nodeType == "REACHABLE" and taxiNameMatches(name, currentAutoFlightTarget) then
                targetReachable = true
            end
        end
    end

    if not currentAutoFlightTarget then
        currentAutoFlightStatus = "no-target"
        return
    end

    if targetReachable then
        currentAutoFlightStatus = "target-reachable-click"
        if DB.autoFlight then
            print("|cff33ff99FLC:|r Flight ready: click " .. tostring(currentAutoFlightTarget) .. ".")
        end
    else
        currentAutoFlightStatus = "target-not-reachable-here"
    end
end

getBestObjectiveTarget = function(step, active)
    if not step or not active or not step.objectiveTargets or not active.objectives then return nil end

    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local bestTarget, bestDistance

    for _, obj in ipairs(active.objectives) do
        if not obj.finished and obj.text and obj.text ~= "" then
            local objectiveLower = string.lower(obj.text)
            for _, target in ipairs(step.objectiveTargets) do
                local match = target.objectiveContains and string.lower(target.objectiveContains)
                if match and string.find(objectiveLower, match, 1, true) then
                    local itemGateOK = true
                    if target.requireItemID and type(GetItemCount) == "function" then
                        local okCount, count = pcall(GetItemCount, target.requireItemID)
                        count = (okCount and count) or 0
                        if target.requireItemPresent and count <= 0 then itemGateOK = false end
                        if target.requireItemMissing and count > 0 then itemGateOK = false end
                    end
                    if itemGateOK then
                    local distance = nil
                    if target.waypoint and playerMapID and target.waypoint.mapID == playerMapID then
                        distance = waypointDistanceNormalized(target.waypoint)
                    end

                    -- On the same map, prefer the closest unfinished verified objective.
                    -- Otherwise preserve the route-data order.
                    if not bestTarget
                        or (distance and (not bestDistance or distance < bestDistance)) then
                        bestTarget = target
                        bestDistance = distance
                    end
                    end
                end
            end
        end
    end

    return bestTarget
end

local function getClassTrainerData()
    local profile = getClassProfile()
    if not profile then return nil, nil end
    local configured = Data.classProfiles and Data.classProfiles[profile.classFile]
    local trainerKey = configured and configured.trainerData
    return trainerKey and Data[trainerKey] or nil, configured
end

local function isClassTrainingDue()
    if not DB then return false end
    local trainers, configured = getClassTrainerData()
    if not trainers or not configured then return false end

    local level = UnitLevel("player") or 1
    local startLevel = tonumber(configured.trainingStart)
    local interval = tonumber(configured.trainingInterval)
    if not startLevel or not interval or interval <= 0 then return false end
    if level < startLevel or ((level - startLevel) % interval) ~= 0 then return false end

    return (tonumber(DB.lastClassTrainerLevel) or 0) < level
end

local function getNearestClassTrainer()
    local trainers = getClassTrainerData()
    if not trainers then return nil end

    if trainers.locations then
        for _, trainer in ipairs(trainers.locations) do
            if trainer.aliases and zoneMatchesAliases(trainer.aliases) then
                return trainer
            end
        end
        return trainers.locations[1]
    end

    if trainers.thunderBluff
        and zoneMatchesAliases({ "Thunder Bluff", "Mulgore", "Stonetalon Mountains", "Stonetalon" }) then
        return trainers.thunderBluff
    end

    return trainers.orgrimmar or trainers.thunderBluff
end

local function getTrainingStep()
    local trainer = getNearestClassTrainer()
    if not trainer then return nil end

    local profile = getClassProfile()
    local className = profile and profile.className or "Class"
    local inTrainerCity = zoneMatchesAliases({ trainer.city })
    return {
        questID = nil,
        training = true,
        title = "Train " .. className,
        tag = "IMPORTANT",
        flightTarget = inTrainerCity and nil or trainer.city,
        personTarget = {
            role = "Class trainer",
            name = trainer.name,
            zone = trainer.zone,
            coords = trainer.coords,
            locationType = string.upper(className) .. " TRAINER",
            locationNote = "Buy your new " .. className .. " abilities/ranks for this level.",
            approach = "Go to the class trainer and learn the available upgrades.",
            useArrow = true,
            waypoint = {
                mapID = trainer.mapID,
                x = trainer.x,
                y = trainer.y,
                label = className .. " Trainer",
            },
        },
        note = "Class training is due at this level.",
    }, trainer
end

local function scanCurrentClassTrainer()
    if not DB then return end
    local npcName = UnitName and UnitName("npc")
    local trainers = getClassTrainerData()
    if not npcName or not trainers or not trainers.names or not trainers.names[npcName] then return end

    local available = 0
    local level = UnitLevel("player") or 1

    if type(GetNumTrainerServices) == "function" and type(GetTrainerServiceType) == "function" then
        local okCount, count = pcall(GetNumTrainerServices)
        if okCount and count then
            for i = 1, count do
                local okType, serviceType = pcall(GetTrainerServiceType, i)
                local levelReq = 0
                if type(GetTrainerServiceLevelReq) == "function" then
                    local okReq, req = pcall(GetTrainerServiceLevelReq, i)
                    if okReq and req then levelReq = req end
                end
                if okType and serviceType == "available" and levelReq <= level then
                    available = available + 1
                end
            end

            currentTrainerAvailableCount = available
            if available == 0 then
                DB.lastClassTrainerLevel = level
                currentTrainingDue = false
            end
        end
    end
end

local function getLazyTravelTarget(step, flightTarget)
    flightTarget = flightTarget or (step and step.flightTarget)
    if not DB or DB.lazyMode == false or not step or not flightTarget then return nil end

    -- If the flight destination already matches the player's current zone/subzone,
    -- there is nothing to fly to. Continue with the local quest objective instead.
    if zoneMatchesAliases({ tostring(flightTarget) }) then
        return nil
    end

    -- Lazy Mode never points an arrow blindly across maps. Instead it converts
    -- cross-zone travel into the next local action the player can actually do.
    if zoneMatchesAliases({ "Splintertree Post" }) then
        return {
            role = "Travel",
            name = "Splintertree Flight Master",
            zone = "Splintertree Post, Ashenvale",
            coords = "around 74, 63",
            locationType = "LOCAL TRAVEL STEP",
            locationNote = "Use the Horde flight master at Splintertree Post.",
            approach = "Follow the local arrow to the flight master, open the taxi map, then choose the route destination.",
            instruction = "Click " .. tostring(flightTarget) .. " on the flight map",
            action = "CLICK " .. string.upper(tostring(flightTarget)),
            useArrow = true,
            waypoint = {
                mapID = 1440,
                x = 0.74,
                y = 0.63,
                label = "Splintertree Flight Master",
            },
        }
    end

    if zoneMatchesAliases({ "Zoram'gar Outpost" }) and flightTarget ~= "Splintertree Post" then
        return {
            role = "Travel",
            name = "Zoram'gar Flight Master",
            zone = "Zoram'gar Outpost, Ashenvale",
            coords = "around 12.2, 33.8",
            locationType = "LOCAL TRAVEL STEP",
            locationNote = "Use the Horde flight master at Zoram'gar Outpost.",
            approach = "The flight master is inside Zoram'gar Outpost near the Warsong Runner.",
            instruction = "Fly to " .. tostring(flightTarget),
            action = "FLY TO " .. string.upper(tostring(flightTarget)),
            useArrow = true,
            waypoint = {
                mapID = 1440,
                x = 0.122,
                y = 0.338,
                label = "Zoram'gar Flight Master",
            },
        }
    end

    if zoneMatchesAliases({ "Ashenvale" }) and flightTarget == "Orgrimmar" then
        return {
            role = "Travel",
            name = "Splintertree Flight Master",
            zone = "Splintertree Post, Ashenvale",
            coords = "around 74, 63",
            locationType = "LOCAL TRAVEL STEP",
            locationNote = "Use the Horde flight master at Splintertree Post.",
            approach = "Follow the arrow to Splintertree Post, then fly to Orgrimmar.",
            instruction = "Fly to Orgrimmar",
            action = "FLY TO ORGRIMMAR",
            useArrow = true,
            waypoint = {
                mapID = 1440,
                x = 0.74,
                y = 0.63,
                label = "Splintertree Flight Master",
            },
        }
    end

    if zoneMatchesAliases({ "Orgrimmar" }) then
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if mapID then
            return {
                role = "Travel",
                name = "Flight Master",
                zone = "Orgrimmar",
                coords = "45, 64",
                locationType = "LOCAL TRAVEL STEP",
                locationNote = "Go to Doras, then fly directly to the route destination.",
                approach = "Follow the arrow to the Orgrimmar flight master.",
                instruction = "Fly to " .. tostring(flightTarget),
                action = "FLY TO " .. string.upper(tostring(flightTarget)),
                useArrow = true,
                waypoint = {
                    mapID = mapID,
                    x = 0.45,
                    y = 0.64,
                    label = "Flight Master",
                },
            }
        end
    end

    return nil
end

local function clearPendingHubChain()
    if DB then DB.pendingHubChain = nil end
    currentHubChainPickup = nil
end

local function capturePendingHubChain(turnedInQuestID)
    if not DB or not turnedInQuestID then return end
    local sourceStep = getStepByQuestID(tonumber(turnedInQuestID))
    local pickup = sourceStep and sourceStep.nextPickup or nil
    if not pickup or not pickup.questID or not pickup.waypoint then
        return
    end

    local nextStep = getStepByQuestID(pickup.questID)
    if nextStep and not routeStepEligible(nextStep) then
        return
    end

    DB.pendingHubChain = {
        sourceQuestID = tonumber(turnedInQuestID),
        questID = tonumber(pickup.questID),
        title = pickup.title,
        npc = pickup.npc,
        role = pickup.role,
        zone = pickup.zone,
        coords = pickup.coords,
        locationType = pickup.locationType or "FOLLOW-UP QUEST",
        locationNote = pickup.locationNote,
        approach = pickup.approach,
        waypoint = pickup.waypoint,
        createdAt = GetTime and GetTime() or 0,
    }
end

local function getPendingHubChainSuggestion(byID)
    if not DB or not DB.pendingHubChain then return nil end
    local pending = DB.pendingHubChain
    local questID = tonumber(pending.questID)
    if not questID then
        clearPendingHubChain()
        return nil
    end

    if (byID and byID[questID]) or isQuestCompleted(questID) then
        clearPendingHubChain()
        return nil
    end

    local createdAt = tonumber(pending.createdAt) or 0
    if GetTime and createdAt > 0 and (GetTime() - createdAt) > 600 then
        clearPendingHubChain()
        return nil
    end

    local nextStep = getStepByQuestID(questID)
    if nextStep and not routeStepEligible(nextStep) then
        clearPendingHubChain()
        return nil
    end

    local waypoint = pending.waypoint
    local distance = waypoint and waypointDistanceNormalized(waypoint) or nil
    if not waypoint or not distance or distance > 0.08 then
        return nil
    end

    return {
        questID = questID,
        title = pending.title or (nextStep and nextStep.title) or ("Quest " .. tostring(questID)),
        classification = "PICK UP NOW",
        rank = 0,
        distance = distance,
        hubChain = true,
        pickup = {
            npc = pending.npc,
            role = pending.role or "Quest giver",
            zone = pending.zone,
            coords = pending.coords,
            locationType = pending.locationType or "FOLLOW-UP QUEST",
            locationNote = pending.locationNote,
            approach = pending.approach,
            waypoint = waypoint,
        },
        step = nextStep,
    }
end

local function render()
    if not playerSupported() then
        routeText:SetText("Current build: Horde classes levels 1–30")
        renderQuestCards({})
        detailText:SetText("This character is outside the currently supported faction/level range.")
        detailText:Show()
        questText:SetText("")
        questText:Hide()
        return
    end

    currentTrainingDue = isClassTrainingDue()
    currentTrainingTarget = currentTrainingDue and getNearestClassTrainer() or nil

    local step, active = chooseRouteStep(currentByID)
    local inTrainerCity = zoneMatchesAliases({ "Orgrimmar", "Thunder Bluff" })
    local shouldTrainNow = currentTrainingDue
        and not zoneMatchesAliases({ "Wailing Caverns" })
        and (inTrainerCity or not step or (currentRouteScore or 0) < 250)

    if shouldTrainNow then
        step, currentTrainingTarget = getTrainingStep()
        active = nil
        currentRouteScore = 2000
        currentRouteReasons = { "class training due at level " .. tostring(UnitLevel("player") or "?") }
        currentCluster = nil
        currentClusterCount = 0
    end
    currentRouteStep = step
    currentPickupSuggestions = getPickupSuggestions(currentByID, step)
    currentHubChainPickup = getPendingHubChainSuggestion(currentByID)
    currentQuickPickupSuggestion = nil
    currentArrivalState = nil

    if currentHubChainPickup then
        currentQuickPickupSuggestion = currentHubChainPickup
    else
        for _, suggestion in ipairs(currentPickupSuggestions or {}) do
            if suggestion.classification == "PICK UP NOW"
                and suggestion.pickup
                and suggestion.pickup.waypoint
                and suggestion.distance
                and suggestion.distance <= 0.05 then
                currentQuickPickupSuggestion = suggestion
                break
            end
        end
    end
    currentTurnInDecision = nil
    currentTurnInDecisionReason = nil
    currentTurnInBatch = nil
    currentBatchTurnInTarget = nil
    if active and active.isComplete then
        currentTurnInDecision, currentTurnInDecisionReason =
            getCompletedTurnInDecision(step, active, currentQuickPickupSuggestion)

        if not currentQuickPickupSuggestion then
            currentTurnInBatch = getCompletedTurnInBatch(currentByID, step)
            if currentTurnInBatch and currentTurnInBatch.first then
                currentBatchTurnInTarget = currentTurnInBatch.first.target
                currentTurnInDecision = "TURN IN NOW"
                currentTurnInDecisionReason = string.format(
                    "batch %d completed quests at %s",
                    currentTurnInBatch.count or #currentTurnInBatch.entries,
                    tostring(currentTurnInBatch.hub or "same hub")
                )
            end
        end
    end

    local routeFlightTarget = step and step.flightTarget or nil
    if active and active.isComplete and step and step.turnInFlightTarget then
        routeFlightTarget = step.turnInFlightTarget
    end
    currentAutoFlightTarget = routeFlightTarget
    currentAutoFlightStatus = currentAutoFlightTarget and "waiting-for-flight-master" or "no-target"
    currentPersonTarget = step and step.personTarget or nil
    if active and active.isComplete and step and step.turnInTarget then
        currentPersonTarget = step.turnInTarget
    end
    if currentBatchTurnInTarget then
        currentPersonTarget = currentBatchTurnInTarget
    end
    currentObjectiveTarget = nil
    currentTravelTarget = nil
    currentNextQuestPickup = nil
    if step and step.nextPickup then
        if step.nextPickup.showWhileActive or (active and active.isComplete) then
            currentNextQuestPickup = step.nextPickup
            if step.nextPickup.waypoint then
                currentPersonTarget = {
                    role = step.nextPickup.role or "Quest giver",
                    name = step.nextPickup.npc,
                    zone = step.nextPickup.zone,
                    coords = step.nextPickup.coords,
                    locationType = step.nextPickup.locationType,
                    locationNote = step.nextPickup.locationNote,
                    approach = step.nextPickup.approach,
                    waypoint = step.nextPickup.waypoint,
                }
            end
        end
    end
    local travelInstruction, navigationWaypoint = getTravelInstruction(step)
    currentTravelInstruction = travelInstruction
    currentNavigationWaypoint = navigationWaypoint
    currentFastTravelSuggestion, currentFastTravelMode = getFastTravelSuggestion(step, travelInstruction)

    if active and active.isComplete then
        currentObjectiveTarget = nil
    else
        currentObjectiveTarget = getBestObjectiveTarget(step, active)
    end
    currentTravelTarget = getLazyTravelTarget(step, routeFlightTarget)

    if currentObjectiveTarget and currentObjectiveTarget.waypoint
        and C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetBestMapForUnit("player") == currentObjectiveTarget.waypoint.mapID then
        currentAutoFlightTarget = nil
        currentAutoFlightStatus = "local-objective"
        currentTravelTarget = nil
        currentNavigationWaypoint = currentObjectiveTarget.waypoint
        if currentObjectiveTarget.instruction then
            currentTravelInstruction = currentObjectiveTarget.instruction
        end
    elseif active and active.isComplete
        and ((currentBatchTurnInTarget and currentBatchTurnInTarget.waypoint)
            or (step and step.turnInTarget and step.turnInTarget.waypoint)) then
        local target = currentBatchTurnInTarget or step.turnInTarget
        if C_Map and C_Map.GetBestMapForUnit
            and C_Map.GetBestMapForUnit("player") == target.waypoint.mapID then
            currentAutoFlightTarget = nil
            currentAutoFlightStatus = currentTurnInBatch and "local-batch-turn-in" or "local-turn-in"
            currentNavigationWaypoint = target.waypoint
            currentTravelInstruction = target.instruction
        end
    end

    if currentTravelTarget then
        currentPersonTarget = {
            role = currentTravelTarget.role,
            name = currentTravelTarget.name,
            zone = currentTravelTarget.zone,
            coords = currentTravelTarget.coords,
            locationType = currentTravelTarget.locationType,
            locationNote = currentTravelTarget.locationNote,
            approach = currentTravelTarget.approach,
            useArrow = currentTravelTarget.useArrow,
            waypoint = currentTravelTarget.waypoint,
        }
        currentTravelInstruction = currentTravelTarget.instruction
        currentNavigationWaypoint = currentTravelTarget.waypoint
        currentFastTravelSuggestion = nil
        currentFastTravelMode = "lazy-local-travel"
    elseif active and active.isComplete and step and step.turnInTarget then
        local target = currentBatchTurnInTarget or step.turnInTarget
        currentPersonTarget = target
        if target.instruction then
            currentTravelInstruction = target.instruction
        end
        if target.waypoint then
            currentNavigationWaypoint = target.waypoint
        end
    elseif currentObjectiveTarget then
        currentPersonTarget = {
            role = currentObjectiveTarget.role or "Quest objective",
            name = currentObjectiveTarget.name,
            zone = currentObjectiveTarget.zone,
            coords = currentObjectiveTarget.coords,
            locationType = currentObjectiveTarget.locationType,
            locationNote = currentObjectiveTarget.locationNote,
            approach = currentObjectiveTarget.approach,
            useArrow = currentObjectiveTarget.useArrow ~= false,
            waypoint = currentObjectiveTarget.waypoint,
        }
        if currentObjectiveTarget.instruction then
            currentTravelInstruction = currentObjectiveTarget.instruction
        end
        if currentObjectiveTarget.waypoint then
            currentNavigationWaypoint = currentObjectiveTarget.waypoint
        end
    end

    if currentQuickPickupSuggestion
        and currentQuickPickupSuggestion.pickup
        and currentQuickPickupSuggestion.pickup.waypoint
        and C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetBestMapForUnit("player") == currentQuickPickupSuggestion.pickup.waypoint.mapID then

        local pickup = currentQuickPickupSuggestion.pickup
        currentNavigationWaypoint = pickup.waypoint
        currentTravelTarget = nil
        currentFastTravelSuggestion = nil
        currentFastTravelMode = "quick-pickup"
        currentAutoFlightTarget = nil
        currentAutoFlightStatus = "quick-pickup"
        currentPersonTarget = {
            role = pickup.role or "Quest giver",
            name = pickup.npc or currentQuickPickupSuggestion.title,
            zone = pickup.zone,
            coords = pickup.coords,
            locationType = pickup.locationType or "QUICK PICKUP",
            locationNote = pickup.locationNote,
            approach = pickup.approach,
            useArrow = true,
            waypoint = pickup.waypoint,
        }
        currentTravelInstruction = "Quick pickup: " .. tostring(currentQuickPickupSuggestion.title or "quest")
    end

    local insideDungeonRoute = step and step.dungeon and step.cluster and zoneMatchesCluster(step.cluster)
    local insideDungeonObjectiveMode = insideDungeonRoute and active and not active.isComplete
    if insideDungeonObjectiveMode then
        currentObjectiveTarget = nil
        currentTravelTarget = nil
        currentNavigationWaypoint = nil
        currentFastTravelSuggestion = nil
        currentFastTravelMode = nil
        currentAutoFlightTarget = nil
        currentAutoFlightStatus = "inside-dungeon"
        currentPersonTarget = {
            role = "Dungeon objective",
            name = "Current boss/objective",
            zone = (GetZoneText and GetZoneText()) or "Dungeon",
            locationType = "INSIDE DUNGEON",
            locationNote = "Stay inside and complete the next unfinished objective.",
        }
    end
    local tag = TAG_LABELS[step.tag] or step.tag or "DO"

    routeClickButton:Show()

    -- Lazy play UI: show only the quest/task name plus ONE immediate action.
    -- Location is communicated by the safe same-zone arrow/local travel handoff.
    if currentHubChainPickup then
        routeText:SetText("Pick up follow-up")
    elseif currentQuickPickupSuggestion then
        routeText:SetText("Quick pickup")
    elseif currentTurnInBatch then
        routeText:SetText("Return to " .. tostring(currentTurnInBatch.hub or "turn-in hub"))
    elseif currentTurnInDecision == "DEFER TURN-IN" then
        routeText:SetText("Finish nearby first")
    elseif currentTravelTarget and DB and DB.lazyMode ~= false then
        routeText:SetText("Travel")
    elseif active and active.isComplete then
        routeText:SetText("Turn in quest")
    elseif step and step.training then
        routeText:SetText("Class training")
    else
        routeText:SetText("Current route")
    end

    local obj = objectiveSummary(active)
    local action = nil

    if currentTravelTarget and DB and DB.lazyMode ~= false then
        action = currentTravelTarget.action or currentTravelTarget.instruction or "Follow the arrow"
    elseif step and step.training then
        local _, classFile = UnitClass("player")
        action = "TRAIN " .. tostring(classFile or "CLASS")
    elseif active and active.isComplete then
        action = (step.turnInTarget and step.turnInTarget.action)
            or ("TURN IN " .. string.upper(step.title or "QUEST"))
    elseif step and step.dungeon then
        local nextObj = nextUnfinishedObjective(active)
        action = nextObj or "COMPLETE REMAINING DUNGEON OBJECTIVES"
    elseif currentObjectiveTarget and currentObjectiveTarget.action then
        action = currentObjectiveTarget.action
    elseif obj then
        action = obj
    elseif currentNextQuestPickup and currentNextQuestPickup.title then
        action = "PICK UP " .. string.upper(currentNextQuestPickup.title)
    else
        action = "FOLLOW THE ARROW"
    end

    local primaryState
    if active and active.isComplete then
        primaryState = currentTurnInDecision or "TURN IN NOW"
    else
        primaryState = "DO NOW"
    end
    local cardData = {}
    local stepNumber = 1

    if currentQuickPickupSuggestion then
        local pickup = currentQuickPickupSuggestion.pickup or {}
        cardData[#cardData + 1] = {
            label = currentHubChainPickup and "FOLLOW-UP" or "QUICK",
            step = 1,
            status = currentHubChainPickup and "PICK UP NEXT" or "PICK UP NOW",
            title = tostring(currentQuickPickupSuggestion.title or "Quest"),
            action = pickup.npc and ("TALK TO " .. string.upper(tostring(pickup.npc))) or "PICK UP QUEST",
            pickup = true,
            pickupClass = "PICK UP NOW",
            background = false,
        }

        cardData[#cardData + 1] = {
            label = "ROUTE",
            step = 2,
            status = primaryState,
            title = step.title or "Next step",
            action = tostring(action or ""),
            background = false,
        }
        stepNumber = 3
    elseif currentTurnInBatch and currentTurnInBatch.first then
        local first = currentTurnInBatch.first
        local firstTarget = first.target or {}
        cardData[#cardData + 1] = {
            label = "RETURN",
            step = 1,
            status = tostring(currentTurnInBatch.count or #currentTurnInBatch.entries) .. " TURN-INS",
            title = tostring(currentTurnInBatch.hub or "Turn-in hub"),
            action = firstTarget.name
                and ("FIRST: TALK TO " .. string.upper(tostring(firstTarget.name)))
                or tostring(firstTarget.action or "TURN IN QUESTS"),
            background = false,
        }
        stepNumber = 2
    else
        cardData[#cardData + 1] = {
            step = 1,
            status = primaryState,
            title = step.title or "Next step",
            action = tostring(action or ""),
            background = false,
        }
        stepNumber = 2
    end

    local detailLines = {}
    local specName, talentPick = flcTalentRecommendation()
    if specName and talentPick then
        detailLines[#detailLines + 1] = "|cff6bb8d9Talent:|r " .. tostring(specName) .. " — " .. tostring(talentPick)
    end

    if DB and DB.lazyMode ~= false and step and step.cluster then
        local clusterQuests = getNearbyClusterQuestNames(step, currentByID)
        for _, q in ipairs(clusterQuests) do
            if #cardData >= #questCards then break end

            local inTurnInBatch = false
            if currentTurnInBatch and q.step and q.active and q.active.isComplete then
                for _, batchEntry in ipairs(currentTurnInBatch.entries or {}) do
                    if batchEntry.step and batchEntry.step.questID == q.step.questID then
                        inTurnInBatch = true
                        break
                    end
                end
            end

            local qAction = nil
            if q.active and q.active.isComplete then
                qAction = (q.step and q.step.turnInTarget and q.step.turnInTarget.action)
                    or ("TURN IN " .. string.upper(q.title or "QUEST"))
            elseif q.active then
                local qTarget = getBestObjectiveTarget(q.step, q.active)
                qAction = (qTarget and qTarget.action) or objectiveSummary(q.active)
            end

            local statusLabel
            if q.background then
                statusLabel = "WHILE QUESTING"
            elseif q.active and q.active.isComplete then
                statusLabel = "TURN IN"
            else
                statusLabel = "NEXT"
            end

            local showAction = qAction and qAction ~= ""
                and ((DB and DB.displayMode == "DETAILED") or not q.background)

            if not inTurnInBatch then
                cardData[#cardData + 1] = {
                    step = stepNumber,
                    status = statusLabel,
                    title = tostring(q.title or "Quest"),
                    action = showAction and tostring(qAction) or "",
                    background = q.background and true or false,
                }
                stepNumber = stepNumber + 1
            end
        end
    end

    if DB and DB.lazyMode ~= false and currentPickupSuggestions then
        for _, suggestion in ipairs(currentPickupSuggestions) do
            if #cardData >= #questCards then break end
            if suggestion ~= currentQuickPickupSuggestion and suggestion.classification ~= "SKIP" then
                local pickup = suggestion.pickup or {}
                local actionText = "PICK UP QUEST"
                if pickup.npc then
                    actionText = "TALK TO " .. string.upper(tostring(pickup.npc))
                end

                cardData[#cardData + 1] = {
                    label = "PICKUP",
                    step = stepNumber,
                    status = suggestion.classification,
                    title = tostring(suggestion.title or "Quest"),
                    action = actionText,
                    pickup = true,
                    pickupClass = suggestion.classification,
                    background = false,
                }
                stepNumber = stepNumber + 1
            end
        end
    end

    if currentRouteDataGaps and #currentRouteDataGaps > 0 then
        for _, gap in ipairs(currentRouteDataGaps) do
            if #cardData >= #questCards then break end
            cardData[#cardData + 1] = {
                label = "DATA",
                step = stepNumber,
                status = "ROUTE DATA GAP",
                title = tostring(gap.title or ("Quest " .. tostring(gap.questID or "?"))),
                action = tostring(gap.reason or "TURN-IN DATA NEEDS VERIFICATION"),
                dataGap = true,
                background = false,
            }
            stepNumber = stepNumber + 1
        end
    end

    if currentRouteReadiness and #currentRouteReadiness > 0 then
        local readinessShown = 0
        for _, issue in ipairs(currentRouteReadiness) do
            if #cardData >= #questCards or readinessShown >= 2 then break end
            if issue.severity == "BLOCKER" or issue.severity == "WARN" then
                cardData[#cardData + 1] = {
                    label = "READY",
                    step = stepNumber,
                    status = issue.severity == "BLOCKER" and "ROUTE BLOCKER" or "ROUTE WARNING",
                    title = tostring(issue.title or ("Quest " .. tostring(issue.questID or "?"))),
                    action = tostring(issue.code or "ROUTE DATA NEEDS REVIEW"),
                    dataGap = true,
                    background = false,
                }
                stepNumber = stepNumber + 1
                readinessShown = readinessShown + 1
            end
        end
    end

    if currentQuestCleanup and #currentQuestCleanup > 0 then
        for _, item in ipairs(currentQuestCleanup) do
            if #cardData >= #questCards then break end
            cardData[#cardData + 1] = {
                label = "CLEANUP",
                step = stepNumber,
                status = "SAFE TO DROP",
                title = tostring(item.title or ("Quest " .. tostring(item.questID or "?"))),
                action = "Optional quest is below route value",
                background = true,
                dropQuestID = item.questID,
            }
            stepNumber = stepNumber + 1
        end
    end

    if DB and DB.gearAdvisor ~= false and DB.displayMode == "DETAILED" and flcGearScanSnapshot then
        local scan = flcGearScanSnapshot()
        local shown = 0
        for _, item in ipairs((scan and scan.priorities) or {}) do
            if shown >= 2 then break end
            if item.status ~= "OPTIONAL EMPTY" and item.status ~= "NOT EXPECTED YET" then
                if shown == 0 then
                    detailLines[#detailLines + 1] = ""
                    detailLines[#detailLines + 1] = "|cff64d8c8GEAR UPGRADES|r"
                end

                detailLines[#detailLines + 1] = string.format(
                    "%s — %s: %s",
                    tostring(item.slotName or "?"),
                    tostring(item.status or "?"),
                    tostring(item.itemName or "EMPTY")
                )

                if item.upgrade and item.upgrade.target then
                    local target = item.upgrade.target
                    local sourceState = ""
                    if target.questID then
                        if currentByID and currentByID[target.questID] then
                            sourceState = " | ACTIVE QUEST"
                        elseif isQuestCompleted(target.questID) then
                            sourceState = " | COMPLETED"
                        else
                            sourceState = " | QUEST SOURCE"
                        end
                    elseif target.routeFriendly then
                        sourceState = " | ROUTE-FRIENDLY"
                    end

                    detailLines[#detailLines + 1] = string.format(
                        "  -> %s (~+%d%%)",
                        tostring(target.name or "?"),
                        math.floor((item.upgrade.pct or 0) + 0.5)
                    )
                    detailLines[#detailLines + 1] = "  " .. tostring(target.source or "Unknown source") .. sourceState
                else
                    detailLines[#detailLines + 1] = "  No verified worthwhile replacement yet."
                end
                shown = shown + 1
            end
        end
    end

    renderQuestCards(cardData)
    detailText:SetText(table.concat(detailLines, "\n"))
    detailText:SetShown(#detailLines > 0)
    refreshMainScroll()

    -- Lazy window is an ordered checklist. STEP 1 is the live routed objective
    -- and owns the navigation arrow; later steps are queued quests in the same cluster.
    -- Full diagnostics remain available through /flc export.
    questText:SetText("")
    questText:Hide()
    updateArrow()
end

syncQuests = function()
    currentQuests, currentByID = getQuestLogSnapshot()
    scanUnknownQuests()
    scanCompletedRouteDataGaps()
    scanRouteReadiness()
    scanQuestCleanup()
    render()
end

applySettings = function()
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

    travelHintFrame:ClearAllPoints()
    travelHintFrame:SetPoint(DB.travelHintPoint or "TOP", UIParent, DB.travelHintRelativePoint or "TOP", DB.travelHintX or 0, DB.travelHintY or -190)
    travelHintFrame:SetSize(DB.travelHintWidth or 300, DB.travelHintHeight or 90)
    travelHintResizeGrip:SetShown(not DB.locked)
    if DB.arrowVisible == false then
        arrowFrame:Hide()
    else
        updateArrow()
    end
    if settingsFrame and settingsFrame:IsShown() and refreshSettingsPanel then
        refreshSettingsPanel()
    end
end

local function flcTalentSpellName(spellID, overrideName)
    if overrideName and overrideName ~= "" then return overrideName end
    if spellID then
        if C_Spell and type(C_Spell.GetSpellName) == "function" then
            local ok, name = pcall(C_Spell.GetSpellName, spellID)
            if ok and name and name ~= "" then return name end
        end
        if type(GetSpellInfo) == "function" then
            local ok, name = pcall(GetSpellInfo, spellID)
            if ok and name and name ~= "" then return name end
        end
    end
    return spellID and ("Spell " .. tostring(spellID)) or "Unknown Talent"
end

local function flcTalentExportSnapshot()
    local snapshot = {
        trees = {},
        spent = {},
        totalSpent = 0,
        available = false,
        api = "none",
    }

    -- Legacy Classic talent API, when exposed by the client.
    if type(GetNumTalentTabs) == "function"
        and type(GetTalentTabInfo) == "function"
        and type(GetNumTalents) == "function"
        and type(GetTalentInfo) == "function" then

        local okTabs, numTabs = pcall(GetNumTalentTabs)
        if okTabs and numTabs and numTabs > 0 then
            snapshot.available = true
            snapshot.api = "classic"

            for tab = 1, numTabs do
                local tabName = "Tree " .. tostring(tab)
                local okTab, _, name, _, _, pointsSpent = pcall(GetTalentTabInfo, tab)
                if okTab then
                    if name and name ~= "" then tabName = name end
                    pointsSpent = tonumber(pointsSpent) or 0
                else
                    pointsSpent = 0
                end

                snapshot.trees[#snapshot.trees + 1] = { name = tabName, points = pointsSpent }
                snapshot.totalSpent = snapshot.totalSpent + pointsSpent

                local okCount, numTalents = pcall(GetNumTalents, tab)
                if okCount and numTalents then
                    for talentIndex = 1, numTalents do
                        local okTalent, talentName, _, tier, column, rank, maxRank = pcall(GetTalentInfo, tab, talentIndex)
                        if okTalent and talentName and tonumber(rank) and tonumber(rank) > 0 then
                            snapshot.spent[#snapshot.spent + 1] = {
                                tree = tabName,
                                name = talentName,
                                rank = tonumber(rank) or 0,
                                maxRank = tonumber(maxRank) or 0,
                                tier = tonumber(tier) or 0,
                                column = tonumber(column) or 0,
                            }
                        end
                    end
                end
            end

            return snapshot
        end
    end

    -- WoW Forever 1.60.1 uses the newer SharedTraits/ClassTalents API.
    if C_ClassTalents and type(C_ClassTalents.GetActiveConfigID) == "function"
        and C_Traits
        and type(C_Traits.GetConfigInfo) == "function"
        and type(C_Traits.GetTreeNodes) == "function"
        and type(C_Traits.GetNodeInfo) == "function"
        and type(C_Traits.GetEntryInfo) == "function"
        and type(C_Traits.GetDefinitionInfo) == "function" then

        local okConfig, configID = pcall(C_ClassTalents.GetActiveConfigID)
        if okConfig and configID then
            local okInfo, configInfo = pcall(C_Traits.GetConfigInfo, configID)
            if okInfo and configInfo and configInfo.treeIDs then
                snapshot.available = true
                snapshot.api = "traits"

                for treeIndex, treeID in ipairs(configInfo.treeIDs) do
                    local treeName = "Trait Tree " .. tostring(treeIndex)
                    if type(C_Traits.GetTreeInfo) == "function" then
                        local okTree, treeInfo = pcall(C_Traits.GetTreeInfo, configID, treeID)
                        if okTree and treeInfo and treeInfo.titleText and treeInfo.titleText ~= "" then
                            treeName = treeInfo.titleText
                        end
                    end

                    local treePoints = 0
                    local okNodes, nodes = pcall(C_Traits.GetTreeNodes, treeID)
                    if okNodes and nodes then
                        for _, nodeID in ipairs(nodes) do
                            local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                            if okNode and nodeInfo then
                                local committed = nodeInfo.entryIDsWithCommittedRanks or {}
                                local rank = tonumber(nodeInfo.currentRank) or tonumber(nodeInfo.activeRank) or 0
                                if #committed > 0 and rank > 0 then
                                    treePoints = treePoints + rank

                                    local entryID = committed[1]
                                    local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                                    if okEntry and entryInfo and entryInfo.definitionID then
                                        local okDef, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                                        if okDef and defInfo then
                                            local talentName = flcTalentSpellName(defInfo.spellID, defInfo.overrideName)
                                            snapshot.spent[#snapshot.spent + 1] = {
                                                tree = treeName,
                                                name = talentName,
                                                rank = rank,
                                                maxRank = tonumber(nodeInfo.maxRanks) or tonumber(entryInfo.maxRanks) or rank,
                                                tier = 0,
                                                column = 0,
                                                nodeID = nodeID,
                                                spellID = defInfo.spellID,
                                            }
                                        end
                                    end
                                end
                            end
                        end
                    end

                    snapshot.trees[#snapshot.trees + 1] = { name = treeName, points = treePoints }
                    snapshot.totalSpent = snapshot.totalSpent + treePoints
                end

                table.sort(snapshot.spent, function(a, b)
                    if a.tree ~= b.tree then return a.tree < b.tree end
                    return a.name < b.name
                end)

                return snapshot
            end
        end
    end

    return snapshot
end


exportSnapshot = function()
    if not DB then copyDefaults() end
    local _, classFile = UnitClass("player")
    local classProfile = getClassProfile()
    local specName, talentRecommendation = flcTalentRecommendation()
    local talentSnapshot = flcTalentExportSnapshot()
    local equippedRelic, knownRelicTarget, relicStatus = flcRelicStatus()
    local lines = {
        "Forever Leveling Coach Export",
        "AddonVersion=" .. tostring(Data.version or "?"),
        "Character=" .. tostring(UnitName("player") or "?"),
        "Level=" .. tostring(UnitLevel("player") or "?"),
        "Class=" .. tostring(classFile or "?"),
        "Faction=" .. tostring(UnitFactionGroup("player") or "?"),
        "RecommendedStep=" .. tostring(currentRouteStep and currentRouteStep.title or "?"),
        "RecommendedQuestID=" .. tostring(currentRouteStep and currentRouteStep.questID or "none"),
        "DungeonMode=" .. tostring(
            currentRouteStep and currentRouteStep.dungeon
            and currentCluster and zoneMatchesCluster(currentCluster)
            and currentByID[currentRouteStep.questID] and not currentByID[currentRouteStep.questID].isComplete
            and "active" or "none"
        ),
        "RecommendedCluster=" .. tostring(currentCluster or "none"),
        "ClusterActiveQuestCount=" .. tostring(currentClusterCount or 0),
        "RecommendedScore=" .. tostring(currentRouteScore or 0),
        "RecommendedReasons=" .. table.concat(currentRouteReasons or {}, " | "),
        "QueuePolicy=STEP 1 primary navigation | STEP 2 background while-questing when available | then next primary objectives | deferred turn-ins last",
        "DynamicLocalOrdering=enabled | objective waypoint proximity + progress + route switch margin",
        "CurrentZone=" .. tostring((GetZoneText and GetZoneText()) or "?"),
        "CurrentSubZone=" .. tostring((GetSubZoneText and GetSubZoneText()) or "?"),
        "CurrentTravelStep=" .. tostring(currentTravelInstruction or "none"),
        "NavigationTarget=" .. tostring(currentNavigationWaypoint and currentNavigationWaypoint.label or "none"),
        "NavigationStep=" .. tostring(currentNavigationStepIndex and (tostring(currentNavigationStepIndex) .. "/" .. tostring(currentNavigationStepCount or "?")) or "none"),
        "ArrowState=" .. tostring(currentArrowState or "unknown"),
        "ArrowMode=" .. tostring(currentArrowState == "active-same-map" and "same-map-safe" or "hidden"),
        "TravelHintState=" .. tostring(currentRouteStep and currentRouteStep.dungeon and zoneMatchesAliases({ "Wailing Caverns" }) and "hidden" or (currentArrowState ~= "active-same-map" and currentTravelInstruction and "shown" or "hidden")),
        "FastTravelMode=" .. tostring(currentFastTravelMode or "none"),
        "FastTravelSuggestion=" .. tostring(currentFastTravelSuggestion or "none"),
        "LazyModeEnabled=" .. tostring(DB and DB.lazyMode ~= false or false),
        "ClassTrainingDue=" .. tostring(currentTrainingDue and true or false),
        "ClassTrainerTarget=" .. tostring(currentTrainingTarget and currentTrainingTarget.name or "none"),
        "LastClassTrainerLevel=" .. tostring(DB and DB.lastClassTrainerLevel or 0),
        "TrainerAvailableCount=" .. tostring(currentTrainerAvailableCount or "unknown"),
        "AutoAcceptEnabled=" .. tostring(DB and DB.autoAccept ~= false or false),
        "AutoTurnInEnabled=" .. tostring(DB and DB.autoTurnIn ~= false or false),
        "LazyTravelTarget=" .. tostring(currentTravelTarget and currentTravelTarget.name or "none"),
        "GearAdvisorEnabled=" .. tostring(DB and DB.gearAdvisor ~= false or false),
        "GearScanEnabled=true",
        "GearTopPriority=" .. tostring((function()
            local scan = flcGearScanSnapshot and flcGearScanSnapshot() or nil
            local top = scan and scan.priorities and scan.priorities[1]
            return top and (tostring(top.slotName) .. " | " .. tostring(top.status) .. " | " .. tostring(top.reason)) or "none"
        end)()),
        "ClassOptimization=" .. tostring(classProfile.optimized and "optimized" or "generic-core"),
        "WeaponPreference=" .. tostring((classProfile.weaponPreference and classProfile.weaponPreference.label) or "class-default"),
        "RecommendedSpec=" .. tostring(specName or "none"),
        "TalentRecommendation=" .. tostring(talentRecommendation or "none"),
        "TalentAPI=" .. tostring(talentSnapshot.api or "none"),
        "TalentPointsSpent=" .. tostring(talentSnapshot.totalSpent or 0),
        "TalentBuild=" .. ((function()
            if not talentSnapshot.available or #talentSnapshot.trees == 0 then return "unavailable" end
            local parts = {}
            for _, tree in ipairs(talentSnapshot.trees) do
                parts[#parts + 1] = tostring(tree.name) .. "=" .. tostring(tree.points or 0)
            end
            return table.concat(parts, " | ")
        end)()),
        "RelicAdvisorEnabled=" .. tostring(DB and DB.relicAdvisor ~= false or false),
        "EquippedRelic=" .. tostring(equippedRelic or (relicStatus == "not-applicable" and "not-applicable" or "none")),
        "KnownRelicTarget=" .. tostring(knownRelicTarget or (relicStatus == "not-applicable" and "not-applicable" or "none")),
        "RelicStatus=" .. tostring(relicStatus or "unknown"),
        "AutoFlightEnabled=" .. tostring(DB and DB.autoFlight ~= false or false),
        "AutoFlightTarget=" .. tostring(currentAutoFlightTarget or "none"),
        "AutoFlightStatus=" .. tostring(currentAutoFlightStatus or "none"),
        "CurrentFlightOptions=" .. (#currentTaxiOptions > 0 and table.concat(currentTaxiOptions, " | ") or "none"),
        "NextQuestPickup=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.title or "none"),
        "NextQuestPickupNPC=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.npc or "none"),
        "NextQuestPickupZone=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.zone or "none"),
        "NextQuestPickupCoords=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.coords or "none"),
        "PickupSuggestionCount=" .. tostring(#(currentPickupSuggestions or {})),
        "QuickPickup=" .. tostring(currentQuickPickupSuggestion and currentQuickPickupSuggestion.title or "none"),
        "QuickPickupQuestID=" .. tostring(currentQuickPickupSuggestion and currentQuickPickupSuggestion.questID or "none"),
        "ArrivalState=" .. tostring(currentArrivalState or "none"),
        "TurnInDecision=" .. tostring(currentTurnInDecision or "none"),
        "TurnInDecisionReason=" .. tostring(currentTurnInDecisionReason or "none"),
        "CrossZoneDeferBestLocal=" .. tostring((function()
            if currentRouteStep and currentByID and currentByID[currentRouteStep.questID]
                and currentByID[currentRouteStep.questID].isComplete then
                local localStep = getWorthwhileCurrentMapObjective(currentRouteStep.questID)
                return localStep and localStep.title or "none"
            end
            return "none"
        end)()),
        "TurnInBatchHub=" .. tostring(currentTurnInBatch and currentTurnInBatch.hub or "none"),
        "TurnInBatchCount=" .. tostring(currentTurnInBatch and currentTurnInBatch.count or 0),
        "TurnInBatchNext=" .. tostring(currentTurnInBatch and currentTurnInBatch.first and currentTurnInBatch.first.step and currentTurnInBatch.first.step.title or "none"),
        "HubChainPickup=" .. tostring(currentHubChainPickup and currentHubChainPickup.title or "none"),
        "HubChainQuestID=" .. tostring(currentHubChainPickup and currentHubChainPickup.questID or "none"),
        "HubChainSourceQuestID=" .. tostring(DB and DB.pendingHubChain and DB.pendingHubChain.sourceQuestID or "none"),
        "RouteDataGapCount=" .. tostring(#(currentRouteDataGaps or {})),
        "RouteDataGapTop=" .. tostring(currentRouteDataGaps and currentRouteDataGaps[1] and currentRouteDataGaps[1].title or "none"),
        "RouteReadinessIssueCount=" .. tostring(#(currentRouteReadiness or {})),
        "RouteReadinessBlockerCount=" .. tostring((function()
            local count = 0
            for _, issue in ipairs(currentRouteReadiness or {}) do
                if issue.severity == "BLOCKER" then count = count + 1 end
            end
            return count
        end)()),
        "RouteReadinessWarningCount=" .. tostring((function()
            local count = 0
            for _, issue in ipairs(currentRouteReadiness or {}) do
                if issue.severity == "WARN" then count = count + 1 end
            end
            return count
        end)()),
        "RouteReadinessTop=" .. tostring(currentRouteReadiness and currentRouteReadiness[1] and currentRouteReadiness[1].title or "none"),
        "QuestCleanupCount=" .. tostring(#(currentQuestCleanup or {})),
        "QuestCleanupTop=" .. tostring(currentQuestCleanup and currentQuestCleanup[1] and currentQuestCleanup[1].title or "none"),
        "MarkedPersonRole=" .. tostring(currentPersonTarget and currentPersonTarget.role or "none"),
        "MarkedPersonName=" .. tostring(currentPersonTarget and currentPersonTarget.name or "none"),
        "MarkedPersonZone=" .. tostring(currentPersonTarget and currentPersonTarget.zone or "none"),
        "MarkedPersonCoords=" .. tostring(currentPersonTarget and currentPersonTarget.coords or "none"),
        "MarkedPersonLocationType=" .. tostring(currentPersonTarget and currentPersonTarget.locationType or "none"),
        "MarkedPersonLocationNote=" .. tostring(currentPersonTarget and currentPersonTarget.locationNote or "none"),
        "MarkedPersonApproach=" .. tostring(currentPersonTarget and currentPersonTarget.approach or "none"),
        "ArrowPlayerMapID=" .. tostring(currentArrowDebug.playerMapID or "none"),
        "ArrowPlayerXY=" .. (currentArrowDebug.playerX and string.format("%.4f,%.4f", currentArrowDebug.playerX, currentArrowDebug.playerY) or "none"),
        "ArrowTargetMapID=" .. tostring(currentArrowDebug.targetMapID or "none"),
        "ArrowTargetXY=" .. (currentArrowDebug.targetX and string.format("%.4f,%.4f", currentArrowDebug.targetX, currentArrowDebug.targetY) or "none"),
        "ArrowFacingDeg=" .. (currentArrowDebug.facing and string.format("%.1f", math.deg(currentArrowDebug.facing)) or "none"),
        "ArrowTargetHeadingDeg=" .. (currentArrowDebug.targetAngle and string.format("%.1f", math.deg(currentArrowDebug.targetAngle)) or "none"),
        "ArrowRotationDeg=" .. (currentArrowDebug.relativeAngle and string.format("%.1f", math.deg(currentArrowDebug.relativeAngle)) or "none"),
    }

    lines[#lines + 1] = "GearScan:"
    local gearScan = flcGearScanSnapshot and flcGearScanSnapshot() or nil
    if not gearScan or not gearScan.slots then
        lines[#lines + 1] = "- unavailable"
    else
        lines[#lines + 1] = string.format("- playerLevel=%d | weakCount=%d | emptyExpected=%d",
            tonumber(gearScan.playerLevel) or 0,
            tonumber(gearScan.weakCount) or 0,
            tonumber(gearScan.emptyExpected) or 0)
        for _, item in ipairs(gearScan.priorities or {}) do
            lines[#lines + 1] = string.format("- PRIORITY | %s | %s | %s | item=%s | ilvl=%s | gap=%s",
                tostring(item.slotName or "?"),
                tostring(item.status or "?"),
                tostring(item.reason or "?"),
                tostring(item.itemName or "EMPTY"),
                tostring(item.itemLevel or "none"),
                tostring(item.levelGap or "none"))
        end
        lines[#lines + 1] = "GearSlots:"
        for _, item in ipairs(gearScan.slots or {}) do
            lines[#lines + 1] = string.format("- %s | %s | item=%s | ilvl=%s | gap=%s | score=%.1f | %s",
                tostring(item.slotName or "?"),
                tostring(item.status or "?"),
                tostring(item.itemName or "EMPTY"),
                tostring(item.itemLevel or "none"),
                tostring(item.levelGap or "none"),
                tonumber(item.score) or 0,
                tostring(item.reason or ""))
            if item.upgrade and item.upgrade.target then
                local target = item.upgrade.target
                lines[#lines + 1] = string.format("  upgrade=%s | estBetter=+%d%% | sourceType=%s | source=%s | routeFriendly=%s | %s",
                    tostring(target.name or "?"),
                    math.floor((item.upgrade.pct or 0) + 0.5),
                    tostring(target.sourceType or "?"),
                    tostring(target.source or "?"),
                    tostring(target.routeFriendly and true or false),
                    tostring(target.sourceNote or ""))
            end
        end
    end

    lines[#lines + 1] = "SpentTalents:"
    if not talentSnapshot.available then
        lines[#lines + 1] = "- unavailable on this client/API"
    elseif #talentSnapshot.spent == 0 then
        lines[#lines + 1] = "- none"
    else
        for _, talent in ipairs(talentSnapshot.spent) do
            local extra = ""
            if talent.nodeID or talent.spellID then
                extra = string.format(" | node=%s | spell=%s", tostring(talent.nodeID or "none"), tostring(talent.spellID or "none"))
            end
            lines[#lines + 1] = string.format(
                "- %s | %s | %d/%d | tier=%d | column=%d%s",
                tostring(talent.tree),
                tostring(talent.name),
                tonumber(talent.rank) or 0,
                tonumber(talent.maxRank) or 0,
                tonumber(talent.tier) or 0,
                tonumber(talent.column) or 0,
                extra
            )
        end
    end

    lines[#lines + 1] = "KnownFlightPaths:"
    local knownFlights = {}
    if DB and DB.knownFlightPaths then
        for name, known in pairs(DB.knownFlightPaths) do
            if known then knownFlights[#knownFlights + 1] = name end
        end
    end
    table.sort(knownFlights)
    if #knownFlights == 0 then
        lines[#lines + 1] = "- none learned yet; open flight masters so FLC can learn them"
    else
        for _, name in ipairs(knownFlights) do
            lines[#lines + 1] = "- " .. name
        end
    end

    lines[#lines + 1] = "TurnInBatch:"
    if not currentTurnInBatch then
        lines[#lines + 1] = "- none"
    else
        for index, entry in ipairs(currentTurnInBatch.entries or {}) do
            lines[#lines + 1] = string.format("- %d | %d | %s | npc=%s | hub=%s | coords=%s%s",
                index,
                tonumber(entry.step and entry.step.questID) or 0,
                tostring(entry.step and entry.step.title or "?"),
                tostring(entry.target and entry.target.name or "unknown"),
                tostring(currentTurnInBatch.hub or "unknown"),
                tostring(entry.target and entry.target.coords or "unknown"),
                entry.distance and string.format(" | mapDistance=%.3f", entry.distance) or "")
        end
    end

    lines[#lines + 1] = "PickupSuggestions:"
    if not currentPickupSuggestions or #currentPickupSuggestions == 0 then
        lines[#lines + 1] = "- none"
    else
        for _, suggestion in ipairs(currentPickupSuggestions) do
            local pickup = suggestion.pickup or {}
            lines[#lines + 1] = string.format("- %d | %s | %s | npc=%s | zone=%s | coords=%s%s",
                tonumber(suggestion.questID) or 0,
                tostring(suggestion.title or "?"),
                tostring(suggestion.classification or "?"),
                tostring(pickup.npc or "unknown"),
                tostring(pickup.zone or "unknown"),
                tostring(pickup.coords or "unknown"),
                suggestion.distance and string.format(" | mapDistance=%.3f", suggestion.distance) or "")
        end
    end

    lines[#lines + 1] = "ScoredCandidates:"
    local clusterCounts = getActiveClusterCounts(currentByID)
    local scored = {}
    for _, step in ipairs(Data.route or {}) do
        local active = currentByID[step.questID]
        local level = UnitLevel("player") or 1
        local _, playerClass = UnitClass("player")
        if active and routeStepEligible(step, level, playerClass) and not isQuestCompleted(step.questID) then
            local score, reasons = scoreRouteStep(step, active, clusterCounts)
            scored[#scored + 1] = {
                step = step,
                score = score,
                reasons = reasons,
                candidateType = step.backgroundQuest and "BACKGROUND | not eligible for STEP 1" or "PRIMARY",
            }
        end
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    for _, item in ipairs(scored) do
        lines[#lines + 1] = string.format("- %d | %s | %s | score=%d | %s",
            item.step.questID or 0,
            item.step.title or "?",
            item.candidateType or "PRIMARY",
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

    lines[#lines + 1] = "QuestCleanupDropButtons=" .. tostring(currentQuestCleanup and #currentQuestCleanup > 0 and "enabled" or "none")
    lines[#lines + 1] = "QuestCleanup:"
    if not currentQuestCleanup or #currentQuestCleanup == 0 then
        lines[#lines + 1] = "- none"
    else
        for _, item in ipairs(currentQuestCleanup) do
            lines[#lines + 1] = string.format("- %d | %s | %s | %s",
                tonumber(item.questID) or 0,
                tostring(item.title or "?"),
                tostring(item.recommendation or "IGNORE"),
                tostring(item.reason or "low route value"))
        end
    end

    lines[#lines + 1] = "RouteReadiness:"
    if not currentRouteReadiness or #currentRouteReadiness == 0 then
        lines[#lines + 1] = "- READY | all active known quests passed readiness checks"
    else
        for _, issue in ipairs(currentRouteReadiness) do
            lines[#lines + 1] = string.format("- %s | %d | %s | %s | %s",
                tostring(issue.severity or "INFO"),
                tonumber(issue.questID) or 0,
                tostring(issue.title or "?"),
                tostring(issue.code or "UNKNOWN"),
                tostring(issue.detail or ""))
        end
    end

    lines[#lines + 1] = "RouteDataGaps:"
    if not currentRouteDataGaps or #currentRouteDataGaps == 0 then
        lines[#lines + 1] = "- none"
    else
        for _, gap in ipairs(currentRouteDataGaps) do
            lines[#lines + 1] = string.format("- %d | %s | %s | routeEntry=%s",
                tonumber(gap.questID) or 0,
                tostring(gap.title or "?"),
                tostring(gap.reason or "UNKNOWN DATA GAP"),
                gap.hasRouteEntry and "yes" or "no")
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


-- Gear Advisor ---------------------------------------------------------------
-- Class-optimized weights are used only where FLC has verified class logic.
-- Every other class gets conservative neutral weights so the shared Gear
-- Advisor does not accidentally apply Shaman priorities to a Mage/Priest/etc.
local FLC_GEAR_WEIGHTS = {
    GENERIC = {
        ITEM_MOD_STRENGTH_SHORT = 1.0,
        ITEM_MOD_AGILITY_SHORT = 1.0,
        ITEM_MOD_STAMINA_SHORT = 0.8,
        ITEM_MOD_INTELLECT_SHORT = 1.0,
        ITEM_MOD_SPIRIT_SHORT = 0.6,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.25,
        ITEM_MOD_CRIT_RATING_SHORT = 0.4,
        ITEM_MOD_HIT_RATING_SHORT = 0.4,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.2,
        ITEM_MOD_SPELL_POWER_SHORT = 0.4,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5.0,
    },
    DRUID = {
        ITEM_MOD_STRENGTH_SHORT = 0.9,
        ITEM_MOD_AGILITY_SHORT = 1.8,
        ITEM_MOD_STAMINA_SHORT = 0.8,
        ITEM_MOD_INTELLECT_SHORT = 0.5,
        ITEM_MOD_SPIRIT_SHORT = 0.4,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_CRIT_RATING_SHORT = 0.7,
        ITEM_MOD_HIT_RATING_SHORT = 0.7,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.4,
        ITEM_MOD_SPELL_POWER_SHORT = 0.15,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.0,
    },
    PALADIN = {
        ITEM_MOD_STRENGTH_SHORT = 2.0,
        ITEM_MOD_AGILITY_SHORT = 0.8,
        ITEM_MOD_STAMINA_SHORT = 0.7,
        ITEM_MOD_INTELLECT_SHORT = 0.6,
        ITEM_MOD_SPIRIT_SHORT = 0.4,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_CRIT_RATING_SHORT = 0.7,
        ITEM_MOD_HIT_RATING_SHORT = 0.7,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.3,
        ITEM_MOD_SPELL_POWER_SHORT = 0.25,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.0,
    },
    PRIEST = {
        ITEM_MOD_STRENGTH_SHORT = 0,
        ITEM_MOD_AGILITY_SHORT = 0.1,
        ITEM_MOD_STAMINA_SHORT = 0.6,
        ITEM_MOD_INTELLECT_SHORT = 1.3,
        ITEM_MOD_SPIRIT_SHORT = 1.1,
        ITEM_MOD_ATTACK_POWER_SHORT = 0,
        ITEM_MOD_CRIT_RATING_SHORT = 0.4,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0,
        ITEM_MOD_SPELL_POWER_SHORT = 1.8,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.0,
    },
    WARLOCK = {
        ITEM_MOD_STRENGTH_SHORT = 0,
        ITEM_MOD_AGILITY_SHORT = 0.1,
        ITEM_MOD_STAMINA_SHORT = 0.8,
        ITEM_MOD_INTELLECT_SHORT = 1.3,
        ITEM_MOD_SPIRIT_SHORT = 0.5,
        ITEM_MOD_ATTACK_POWER_SHORT = 0,
        ITEM_MOD_CRIT_RATING_SHORT = 0.5,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.5,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0,
        ITEM_MOD_SPELL_POWER_SHORT = 2.0,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 1.0,
    },
    MAGE = {
        ITEM_MOD_STRENGTH_SHORT = 0,
        ITEM_MOD_AGILITY_SHORT = 0.1,
        ITEM_MOD_STAMINA_SHORT = 0.5,
        ITEM_MOD_INTELLECT_SHORT = 1.5,
        ITEM_MOD_SPIRIT_SHORT = 0.7,
        ITEM_MOD_ATTACK_POWER_SHORT = 0,
        ITEM_MOD_CRIT_RATING_SHORT = 0.5,
        ITEM_MOD_HIT_RATING_SHORT = 0.7,
        ITEM_MOD_HASTE_RATING_SHORT = 0.5,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0,
        ITEM_MOD_SPELL_POWER_SHORT = 2.0,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 1.0,
    },
    HUNTER = {
        ITEM_MOD_STRENGTH_SHORT = 0.2,
        ITEM_MOD_AGILITY_SHORT = 2.0,
        ITEM_MOD_STAMINA_SHORT = 0.7,
        ITEM_MOD_INTELLECT_SHORT = 0.4,
        ITEM_MOD_SPIRIT_SHORT = 0.2,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_CRIT_RATING_SHORT = 0.6,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.5,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.4,
        ITEM_MOD_SPELL_POWER_SHORT = 0,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.0,
    },
    WARRIOR = {
        ITEM_MOD_STRENGTH_SHORT = 2.0,
        ITEM_MOD_AGILITY_SHORT = 0.7,
        ITEM_MOD_STAMINA_SHORT = 0.9,
        ITEM_MOD_INTELLECT_SHORT = 0,
        ITEM_MOD_SPIRIT_SHORT = 0.1,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_CRIT_RATING_SHORT = 0.6,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.4,
        ITEM_MOD_SPELL_POWER_SHORT = 0,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.0,
    },
    SHAMAN = {
        ITEM_MOD_STRENGTH_SHORT = 2.0,
        ITEM_MOD_AGILITY_SHORT = 1.4,
        ITEM_MOD_STAMINA_SHORT = 0.7,
        ITEM_MOD_INTELLECT_SHORT = 0.5,
        ITEM_MOD_SPIRIT_SHORT = 0.2,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_CRIT_RATING_SHORT = 0.6,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.4,
        ITEM_MOD_SPELL_POWER_SHORT = 0.15,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.0,
    },
    ROGUE = {
        ITEM_MOD_STRENGTH_SHORT = 0.5,
        ITEM_MOD_AGILITY_SHORT = 2.2,
        ITEM_MOD_STAMINA_SHORT = 0.8,
        ITEM_MOD_INTELLECT_SHORT = 0,
        ITEM_MOD_SPIRIT_SHORT = 0,
        ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
        ITEM_MOD_CRIT_RATING_SHORT = 0.6,
        ITEM_MOD_HIT_RATING_SHORT = 0.8,
        ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 0.4,
        ITEM_MOD_SPELL_POWER_SHORT = 0,
        ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10.0,
    },
}

local function flcGearWeights()
    local _, classFile = UnitClass("player")
    return FLC_GEAR_WEIGHTS[classFile] or FLC_GEAR_WEIGHTS.GENERIC
end

local FLC_EQUIP_SLOTS = {
    INVTYPE_HEAD = {1},
    INVTYPE_NECK = {2},
    INVTYPE_SHOULDER = {3},
    INVTYPE_BODY = {4},
    INVTYPE_CHEST = {5},
    INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7},
    INVTYPE_FEET = {8},
    INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12},
    INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16},
    INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_SHIELD = {17},
    INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18},
    INVTYPE_RANGEDRIGHT = {18},
    INVTYPE_RELIC = {18},
}

local flcGearScanTooltip = CreateFrame("GameTooltip", "ForeverLevelingCoachGearScanTooltip", UIParent, "GameTooltipTemplate")
flcGearScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function flcTooltipWeaponDPS(tooltip)
    if not tooltip then return 0 end
    local minDamage, maxDamage, speed, explicitDPS
    local name = tooltip:GetName()
    local count = tooltip:NumLines() or 0
    for i = 2, count do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local text = ((left and left:GetText()) or "") .. " " .. ((right and right:GetText()) or "")
        local lo, hi = string.match(text, "(%d+)%s*%-%s*(%d+)%s+[Dd]amage")
        if lo and hi then
            minDamage, maxDamage = tonumber(lo), tonumber(hi)
        end
        local spd = string.match(text, "[Ss]peed%s+([%d%.]+)")
        if spd then speed = tonumber(spd) end
        local dps = string.match(text, "([%d%.]+)%s+[Dd]amage%s+[Pp]er%s+[Ss]econd")
        if dps then explicitDPS = tonumber(dps) end
    end
    if explicitDPS then return explicitDPS end
    if minDamage and maxDamage and speed and speed > 0 then
        return ((minDamage + maxDamage) / 2) / speed
    end
    return 0
end

local function flcItemID(link)
    if not link then return nil end
    local id = string.match(link, "item:(%d+)")
    return id and tonumber(id) or nil
end

local function flcKnownRelicScore(link)
    local classProfile = getClassProfile()
    if not classProfile or not classProfile.usesRelics then return 0, nil end
    local itemID = flcItemID(link)
    local relic = itemID and Data.shamanRelics and Data.shamanRelics[itemID]
    if relic then return tonumber(relic.score) or 0, relic end
    return 0, nil
end

local function flcSafeGetItemInfo(link)
    if not link then return nil end

    if type(GetItemInfo) == "function" then
        local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q = pcall(GetItemInfo, link)
        if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q end
    end

    if C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q = pcall(C_Item.GetItemInfo, link)
        if ok then return a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q end
    end

    return nil
end

local function flcItemScore(link, tooltip)
    if not link then return 0 end
    local score = 0
    local stats = nil
    if type(GetItemStats) == "function" then
        local ok, value = pcall(GetItemStats, link)
        if ok then stats = value end
    elseif C_Item and type(C_Item.GetItemStats) == "function" then
        local ok, value = pcall(C_Item.GetItemStats, link)
        if ok then stats = value end
    end
    local weights = flcGearWeights()
    if stats then
        for stat, value in pairs(stats) do
            local weight = weights[stat]
            if weight and value then
                score = score + (value * weight)
            end
        end
    end

    local _, _, _, itemLevel, _, _, _, _, equipLoc = flcSafeGetItemInfo(link)
    if itemLevel then score = score + (itemLevel * 0.08) end

    local relicScore = flcKnownRelicScore(link)
    score = score + (relicScore or 0)

    if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND"
        or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" then
        local dps = flcTooltipWeaponDPS(tooltip)
        score = score + (dps * 10)
    end

    return score
end

local function flcStaticUpgradeScore(target)
    if not target then return 0 end
    local stats = target.stats or {}
    local score = 0
    local liveWeights = flcGearWeights()
    local keyByName = {
        Strength = "ITEM_MOD_STRENGTH_SHORT",
        Agility = "ITEM_MOD_AGILITY_SHORT",
        Stamina = "ITEM_MOD_STAMINA_SHORT",
        Intellect = "ITEM_MOD_INTELLECT_SHORT",
        Spirit = "ITEM_MOD_SPIRIT_SHORT",
        AttackPower = "ITEM_MOD_ATTACK_POWER_SHORT",
        Crit = "ITEM_MOD_CRIT_RATING_SHORT",
        Hit = "ITEM_MOD_HIT_RATING_SHORT",
        Haste = "ITEM_MOD_HASTE_RATING_SHORT",
        ArmorPen = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
        SpellPower = "ITEM_MOD_SPELL_POWER_SHORT",
        DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
    }

    local function weight(name)
        return liveWeights[keyByName[name]] or 0
    end

    for statName, value in pairs(stats) do
        score = score + ((tonumber(value) or 0) * weight(statName))
    end

    score = score + ((tonumber(target.itemLevel) or 0) * 0.08)
    return score
end

local function flcBestUpgradeTarget(slot, currentScore)
    local _, playerClass = UnitClass("player")
    local classTargets = Data.gearUpgradeTargets and Data.gearUpgradeTargets[playerClass]
    local targets = classTargets and classTargets[slot]
    if not targets then return nil end

    local playerLevel = UnitLevel("player") or 1
    local best, bestValue = nil, -999999

    for _, target in ipairs(targets) do
        if playerLevel >= (target.requiredLevel or 1) then
            local targetScore = flcStaticUpgradeScore(target)
            local delta = targetScore - (currentScore or 0)
            local denom = math.max(targetScore, currentScore or 0, 1)
            local pct = (delta / denom) * 100

            -- Source practicality breaks near-ties, but never makes a worse
            -- item into an "upgrade". Route-friendly quest rewards are favored
            -- over optional farms when their actual gear value is comparable.
            if pct >= 1 and not (target.questID and isQuestCompleted(target.questID)) then
                local practicalBonus = 0
                if target.routeFriendly then
                    practicalBonus = (target.questID and currentByID and currentByID[target.questID]) and 20 or 15
                end
                local sourceBonus = (tonumber(target.sourcePriority) or 0) * 0.05
                local value = pct + practicalBonus + sourceBonus
                if value > bestValue then
                    bestValue = value
                    best = {
                        target = target,
                        score = targetScore,
                        pct = pct,
                    }
                end
            end
        end
    end

    return best
end

local function flcEquippedScore(slot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not link then return 0, nil end
    flcGearScanTooltip:ClearLines()
    flcGearScanTooltip:SetInventoryItem("player", slot)
    return flcItemScore(link, flcGearScanTooltip), link
end


local FLC_GEAR_SCAN_SLOTS = {
    { slot = 1,  name = "Head",      expectedLevel = 28, optionalEmpty = true },
    { slot = 2,  name = "Neck",      expectedLevel = 30, optionalEmpty = true },
    { slot = 3,  name = "Shoulders", expectedLevel = 18 },
    { slot = 5,  name = "Chest",     expectedLevel = 1 },
    { slot = 6,  name = "Waist",     expectedLevel = 8 },
    { slot = 7,  name = "Legs",      expectedLevel = 1 },
    { slot = 8,  name = "Feet",      expectedLevel = 1 },
    { slot = 9,  name = "Wrist",     expectedLevel = 8 },
    { slot = 10, name = "Hands",     expectedLevel = 1 },
    { slot = 11, name = "Ring 1",    expectedLevel = 18 },
    { slot = 12, name = "Ring 2",    expectedLevel = 22 },
    { slot = 13, name = "Trinket 1", expectedLevel = 28, optionalEmpty = true },
    { slot = 14, name = "Trinket 2", expectedLevel = 35, optionalEmpty = true },
    { slot = 15, name = "Back",      expectedLevel = 8 },
    { slot = 16, name = "Weapon",    expectedLevel = 1, weapon = true },
    { slot = 17, name = "Off Hand",  expectedLevel = 1, optionalFor2H = true },
    { slot = 18, name = "Relic/Ranged", expectedLevel = 18, relic = true },
}

local function flcEquippedItemLevel(link)
    if not link then return nil end
    if type(GetDetailedItemLevelInfo) == "function" then
        local ok, value = pcall(GetDetailedItemLevelInfo, link)
        if ok and value then return tonumber(value) end
    end
    if type(GetItemInfo) == "function" then
        local _, _, _, itemLevel = flcSafeGetItemInfo(link)
        return tonumber(itemLevel)
    end
    return nil
end

local function flcGearSlotStatus(slotDef, playerLevel)
    local slot = slotDef.slot
    local score, link = flcEquippedScore(slot)
    local classProfile = getClassProfile()
    local weaponPreference = classProfile and classProfile.weaponPreference

    if slotDef.optionalFor2H and weaponPreference and weaponPreference.mode == "2H_ONLY" then
        local mainLink = GetInventoryItemLink and GetInventoryItemLink("player", 16)
        if mainLink and GetItemInfo then
            local _, _, _, _, _, itemType, _, _, equipLoc = flcSafeGetItemInfo(mainLink)
            if itemType == "Weapon" and equipLoc == "INVTYPE_2HWEAPON" then
                return {
                    slot = slot, slotName = slotDef.name, status = "N/A",
                    reason = "2H weapon equipped; off-hand correctly empty",
                    score = score or 0,
                }
            end
        end
    end

    if not link then
        local expected = playerLevel >= (slotDef.expectedLevel or 1)

        if slotDef.optionalEmpty and not expected then
            return {
                slot = slot,
                slotName = slotDef.name,
                status = "OPTIONAL EMPTY",
                reason = "Nice to fill when a worthwhile upgrade appears",
                score = 0,
                priority = 10,
                expected = false,
                optionalEmpty = true,
            }
        end

        if expected then
            local priority = slotDef.weapon and 140 or (slotDef.relic and 90 or 85)
            if slotDef.optionalEmpty then
                priority = 35
            end
            return {
                slot = slot,
                slotName = slotDef.name,
                status = slotDef.optionalEmpty and "OPTIONAL EMPTY" or "EMPTY",
                reason = slotDef.optionalEmpty
                    and "Useful upgrade slot, but do not detour for a mediocre item"
                    or "Expected leveling slot is empty",
                score = 0,
                priority = priority,
                expected = true,
                optionalEmpty = slotDef.optionalEmpty and true or false,
            }
        end

        return {
            slot = slot, slotName = slotDef.name, status = "NOT EXPECTED YET",
            reason = "Empty slot is normal at this level",
            score = 0,
            expected = false,
        }
    end

    local itemName = select(1, flcSafeGetItemInfo(link)) or link
    local itemLevel = flcEquippedItemLevel(link)
    local gap = itemLevel and math.max(0, playerLevel - itemLevel) or nil

    local status, reason, priority = "OK", "Item level is reasonable for your level", 0
    if gap then
        if slotDef.weapon then
            if gap >= 7 then
                status, reason, priority = "CRITICAL", "Weapon is far behind your character level", 130 + gap
            elseif gap >= 4 then
                status, reason, priority = "WEAK", "Weapon is behind your character level", 105 + gap
            elseif gap >= 2 then
                status, reason, priority = "WATCH", "Weapon is starting to fall behind", 55 + gap
            end
        else
            if gap >= 10 then
                status, reason, priority = "CRITICAL", "Item is far behind your character level", 100 + gap
            elseif gap >= 6 then
                status, reason, priority = "WEAK", "Item is behind your character level", 75 + gap
            elseif gap >= 4 then
                status, reason, priority = "WATCH", "Item is starting to fall behind", 40 + gap
            end
        end
    end

    if slotDef.relic then
        local _, knownRelic = flcKnownRelicScore(link)
        if knownRelic then
            status = "OK"
            reason = "Known Shaman relic equipped"
            priority = 0
        end
    end

    local upgrade = flcBestUpgradeTarget(slot, score or 0)
    if (status == "WEAK" or status == "WATCH") and not upgrade then
        status = "HOLD"
        reason = "Item level is behind, but no verified worthwhile replacement currently beats its leveling score"
        priority = 0
    end

    return {
        slot = slot,
        slotName = slotDef.name,
        status = status,
        reason = reason,
        link = link,
        itemName = itemName,
        itemLevel = itemLevel,
        levelGap = gap,
        score = score or 0,
        priority = priority,
        expected = true,
        upgrade = upgrade,
    }
end

flcGearScanSnapshot = function()
    local playerLevel = UnitLevel("player") or 1
    local snapshot = {
        playerLevel = playerLevel,
        slots = {},
        priorities = {},
        weakCount = 0,
        emptyExpected = 0,
    }

    for _, slotDef in ipairs(FLC_GEAR_SCAN_SLOTS) do
        local item = flcGearSlotStatus(slotDef, playerLevel)
        snapshot.slots[#snapshot.slots + 1] = item

        if item.status == "EMPTY" then
            snapshot.emptyExpected = snapshot.emptyExpected + 1
            snapshot.weakCount = snapshot.weakCount + 1
            snapshot.priorities[#snapshot.priorities + 1] = item
        elseif item.status == "OPTIONAL EMPTY" then
            if item.expected then
                snapshot.emptyExpected = snapshot.emptyExpected + 1
            end
            snapshot.priorities[#snapshot.priorities + 1] = item
        elseif item.status == "CRITICAL" or item.status == "WEAK" or item.status == "WATCH" then
            snapshot.weakCount = snapshot.weakCount + 1
            snapshot.priorities[#snapshot.priorities + 1] = item
        end
    end

    table.sort(snapshot.priorities, function(a, b)
        local pa, pb = tonumber(a.priority) or 0, tonumber(b.priority) or 0
        if pa ~= pb then return pa > pb end
        return tostring(a.slotName) < tostring(b.slotName)
    end)

    return snapshot
end

local function flcItemUsabilityReason(link, sourceTooltip)
    if not link then return nil end

    -- Prefer the game's own usability check so weapon/armor proficiency,
    -- class restrictions, and other character-specific restrictions win over scoring.
    if type(IsUsableItem) == "function" then
        local ok, usable = pcall(IsUsableItem, link)
        if ok and usable == false then
            return "Your character cannot use this item"
        end
    end

    -- Forever beta fallback: inspect red requirement text on the primary tooltip.
    if sourceTooltip and sourceTooltip.GetName and sourceTooltip.NumLines then
        local name = sourceTooltip:GetName()
        local count = sourceTooltip:NumLines() or 0
        for i = 2, count do
            local left = _G[name .. "TextLeft" .. i]
            local text = left and left:GetText()
            local r, g, b = left and left:GetTextColor()
            if text and r and g and b and r > 0.8 and g < 0.35 and b < 0.35 then
                local lower = string.lower(text)
                if string.find(lower, "cannot use", 1, true)
                    or string.find(lower, "requires", 1, true)
                    or string.find(lower, "classes:", 1, true) then
                    return text
                end
            end
        end
    end

    return nil
end

local function flcClassGearReason(itemType, itemSubType, equipLoc)
    local classProfile = getClassProfile()
    local profile = classProfile and classProfile.gearProfile
    if not profile then return nil end

    if itemType == "Armor" then
        local accessory = equipLoc == "INVTYPE_CLOAK" or equipLoc == "INVTYPE_NECK"
            or equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_TRINKET"
        if accessory then return nil end

        if profile.armorAllowed and not profile.armorAllowed[itemSubType] then
            return "UNUSABLE", tostring(classProfile.className) .. " cannot use this armor type"
        end
        if equipLoc == "INVTYPE_SHIELD" or itemSubType == "Shields" then return nil end
        if profile.armorPreferred and itemSubType ~= profile.armorPreferred then
            return "PREFERENCE", tostring(profile.armorPreferred) .. " is preferred for "
                .. tostring(classProfile.className) .. " leveling"
        end
    elseif itemType == "Weapon" then
        local ranged = equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
            or equipLoc == "INVTYPE_THROWN"
        local allowed = ranged and profile.rangedWeapons or profile.meleeWeapons
        if allowed and not allowed[itemSubType] then
            return "UNUSABLE", tostring(classProfile.className) .. " cannot use this weapon for this slot"
        end
    end

    return nil
end

local function flcGearEvaluateItem(link, sourceTooltip)
    if not link then return nil end
    local _, _, _, _, requiredLevel, itemType, itemSubType, _, equipLoc = flcSafeGetItemInfo(link)
    if not equipLoc or equipLoc == "" then return nil end

    local slots = FLC_EQUIP_SLOTS[equipLoc]
    if not slots then return nil end

    local classGrade, classReason = flcClassGearReason(itemType, itemSubType, equipLoc)
    if classGrade then return classGrade, classReason end

    local classProfile = getClassProfile()
    local weaponPreference = classProfile and classProfile.weaponPreference
    if weaponPreference and weaponPreference.mode == "2H_ONLY" and itemType == "Weapon" then
        local allowed = equipLoc == "INVTYPE_2HWEAPON"
            and weaponPreference.allowedSubTypes
            and weaponPreference.allowedSubTypes[itemSubType]
        if not allowed then
            return "PREFERENCE", "Build target: " .. tostring(weaponPreference.label or "2H Axe / 2H Mace")
        end
    end

    if requiredLevel and requiredLevel > (UnitLevel("player") or 1) then
        return "LOCKED", "Requires level " .. tostring(requiredLevel)
    end

    local unusableReason = flcItemUsabilityReason(link, sourceTooltip)
    if unusableReason then
        return "UNUSABLE", unusableReason
    end

    local candidateScore = flcItemScore(link, sourceTooltip)
    local equippedScore, equippedLink
    for _, slot in ipairs(slots) do
        local score, eqLink = flcEquippedScore(slot)
        if equippedScore == nil or score < equippedScore then
            equippedScore, equippedLink = score, eqLink
        end
    end
    equippedScore = equippedScore or 0

    if not equippedLink then
        return "MAJOR", "Empty slot — equip it"
    end

    local delta = candidateScore - equippedScore
    local denom = math.max(candidateScore, equippedScore, 1)
    local pct = (delta / denom) * 100

    if pct >= 1 then
        return "BETTER", string.format("+%d%% better for leveling", math.floor(pct + 0.5))
    elseif pct <= -1 then
        return "WORSE", string.format("%d%% worse for leveling", math.floor(pct - 0.5))
    end
    return "SAME", "About the same"
end

local function flcAddGearAdvice(tooltip, tooltipData)
    if not DB or DB.gearAdvisor == false or not tooltip or tooltip == flcGearScanTooltip or tooltip.__flcGearBusy then return end

    -- Comparison/shopping tooltips on the Forever beta client do not always
    -- implement GetItem(). Skip them safely; the primary item tooltip is enough
    -- for the quick upgrade verdict.
    local link = nil
    if type(tooltip.GetItem) == "function" then
        local _, itemLink = tooltip:GetItem()
        link = itemLink
    end
    if not link and tooltipData then
        link = tooltipData.hyperlink
        if not link and tooltipData.id and C_Item and C_Item.GetItemLinkByID then
            link = C_Item.GetItemLinkByID(tooltipData.id)
        end
    end
    if not link then return end
    if tooltip.__flcGearLink == link then return end

    tooltip.__flcGearBusy = true
    local grade, reason = flcGearEvaluateItem(link, tooltip)
    local _, knownRelic = flcKnownRelicScore(link)
    if grade then
        tooltip:AddLine(" ")
        if grade == "BETTER" then
            tooltip:AddLine("FLC: " .. (reason or "BETTER"), 0.2, 1.0, 0.2)
            reason = nil
        elseif grade == "WORSE" then
            tooltip:AddLine("FLC: " .. (reason or "WORSE"), 1.0, 0.35, 0.35)
            reason = nil
        elseif grade == "SAME" then
            tooltip:AddLine("FLC: ABOUT THE SAME", 1.0, 0.82, 0.2)
            reason = nil
        elseif grade == "LOCKED" then
            tooltip:AddLine("FLC: NOT USABLE YET", 1.0, 0.55, 0.2)
        elseif grade == "UNUSABLE" then
            tooltip:AddLine("FLC: CANNOT USE", 1.0, 0.25, 0.25)
        elseif grade == "PREFERENCE" then
            tooltip:AddLine("FLC: CLASS PREFERENCE", 1.0, 0.82, 0.2)
        else
            tooltip:AddLine("FLC: KEEP CURRENT ITEM", 1.0, 0.35, 0.35)
        end
        if reason then tooltip:AddLine(reason, 0.75, 0.75, 0.75) end
        if knownRelic then
            tooltip:AddLine("FLC RELIC: " .. tostring(knownRelic.name), 0.35, 0.8, 1.0)
            tooltip:AddLine(tostring(knownRelic.effect or ""), 0.75, 0.75, 0.75)
        end
        tooltip:Show()
        tooltip.__flcGearLink = link
    end
    tooltip.__flcGearBusy = false
end

local function flcHookGearTooltipLegacy(tooltip)
    if not tooltip or tooltip.__flcGearHooked then return end
    if tooltip.HasScript and not tooltip:HasScript("OnTooltipSetItem") then return end
    tooltip.__flcGearHooked = true
    if tooltip.HookScript then
        tooltip:HookScript("OnTooltipSetItem", function(self)
            self.__flcGearLink = nil
            flcAddGearAdvice(self)
        end)
        if not tooltip.HasScript or tooltip:HasScript("OnTooltipCleared") then
            tooltip:HookScript("OnTooltipCleared", function(self)
                self.__flcGearLink = nil
            end)
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
        if tooltip and tooltip ~= flcGearScanTooltip then
            -- Do not process comparison shopping tooltips; they are missing
            -- parts of the normal GameTooltip API on this client.
            local tooltipName = tooltip.GetName and tooltip:GetName() or ""
            if not string.find(tooltipName or "", "ShoppingTooltip", 1, true) then
                tooltip.__flcGearLink = nil
                flcAddGearAdvice(tooltip, tooltipData)
            end
        end
    end)
else
    flcHookGearTooltipLegacy(GameTooltip)
    if ItemRefTooltip then flcHookGearTooltipLegacy(ItemRefTooltip) end
end
-- End Gear Advisor -----------------------------------------------------------

flcRelicStatus = function()
    local classProfile = getClassProfile()
    if not classProfile or not classProfile.usesRelics then
        return nil, nil, "not-applicable"
    end
    local equipped = GetInventoryItemLink and GetInventoryItemLink("player", 18)
    local equippedID = flcItemID(equipped)
    local known = equippedID and Data.shamanRelics and Data.shamanRelics[equippedID]
    if known then
        return equipped, known.name, "equipped-known"
    end

    if Data.shamanRelics and GetItemCount then
        for itemID, relic in pairs(Data.shamanRelics) do
            local ok, count = pcall(GetItemCount, itemID)
            if ok and count and count > 0 then
                return equipped, relic.name, "known-relic-in-bags"
            end
        end
    end

    return equipped, nil, equipped and "other-equipped" or "empty"
end

-- Lazy quest automation ------------------------------------------------------
local function flcCurrentDialogQuestID()
    if type(GetQuestID) == "function" then
        local ok, questID = pcall(GetQuestID)
        if ok and questID and questID > 0 then return questID end
    end
    return nil
end

local function flcShouldAutoAcceptQuest(questID)
    if not DB or DB.autoAccept == false then return false end
    if not questID then return false end
    local step = getStepByQuestID(questID)
    if not step then return false end
    return (step.tag or "DO") ~= "SKIP"
end

local function flcShouldAutoTurnInQuest(questID)
    if not DB or DB.autoTurnIn == false then return false end
    if not questID then return false end
    local step = getStepByQuestID(questID)
    if not step then return false end
    return (step.tag or "DO") ~= "SKIP"
end

local function flcHandleQuestDetail()
    local questID = flcCurrentDialogQuestID()
    if not flcShouldAutoAcceptQuest(questID) then return end
    if type(AcceptQuest) == "function" then
        local ok = pcall(AcceptQuest)
        if ok then
            local step = getStepByQuestID(questID)
            print("|cff33ff99FLC:|r auto-accepted " .. tostring(step and step.title or ("quest " .. tostring(questID))) .. ".")
        end
    end
end

local function flcHandleQuestProgress()
    local questID = flcCurrentDialogQuestID()
    if not flcShouldAutoTurnInQuest(questID) then return end
    if type(IsQuestCompletable) == "function" and not IsQuestCompletable() then return end
    if type(CompleteQuest) == "function" then
        pcall(CompleteQuest)
    end
end

local function flcHandleQuestComplete()
    local questID = flcCurrentDialogQuestID()
    if not flcShouldAutoTurnInQuest(questID) then return end

    local choices = 0
    if type(GetNumQuestChoices) == "function" then
        local ok, value = pcall(GetNumQuestChoices)
        if ok and value then choices = value end
    end

    -- Never guess a reward. If there is a choice, stop so Gear Advisor/user can decide.
    if choices and choices > 0 then
        print("|cffffcc00FLC:|r reward choice detected — pick the best item, then finish the turn-in.")
        return
    end

    if type(GetQuestReward) == "function" then
        local ok = pcall(GetQuestReward, 0)
        if ok then
            print("|cff33ff99FLC:|r auto-turned in quest.")
        end
    end
end
-- End Lazy quest automation --------------------------------------------------

SLASH_FOREVERLEVELINGCOACH1 = "/flc"
SlashCmdList.FOREVERLEVELINGCOACH = function(msg)
    msg = (msg or ""):lower()

    if msg == "relic" then
        DB.relicAdvisor = not DB.relicAdvisor
        render()
        print("|cff33ff99FLC:|r relic advisor " .. (DB.relicAdvisor and "enabled." or "disabled."))
    elseif msg == "trained" then
        DB.lastClassTrainerLevel = UnitLevel("player") or DB.lastClassTrainerLevel or 0
        currentTrainingDue = false
        render()
        print("|cff33ff99FLC:|r marked Shaman training complete for level " .. tostring(DB.lastClassTrainerLevel) .. ".")
    elseif msg == "autoaccept" then
        DB.autoAccept = not DB.autoAccept
        print("|cff33ff99FLC:|r auto accept " .. (DB.autoAccept and "enabled." or "disabled."))
    elseif msg == "autoturnin" then
        DB.autoTurnIn = not DB.autoTurnIn
        print("|cff33ff99FLC:|r auto turn-in " .. (DB.autoTurnIn and "enabled." or "disabled."))
    elseif msg == "lazy" then
        DB.lazyMode = not DB.lazyMode
        render()
        print("|cff33ff99FLC:|r Lazy Mode " .. (DB.lazyMode and "enabled." or "disabled."))
    elseif msg == "go" then
        syncQuests()
        focusCurrentQuest()
    elseif msg == "sync" then
        syncQuests()
        print("|cff33ff99FLC:|r quest log synced.")
    elseif msg == "export" then
        syncQuests()
        exportSnapshot()
    elseif msg == "spec" then
        local profile = getClassProfile()
        local builds, setting = profile.talentBuilds, profile.talentSetting
        if not builds or not setting then
            print("|cffffcc00FLC:|r no class-specific talent guide is configured for " .. tostring(profile.className) .. " yet.")
        else
            local specs = {}
            for name, build in pairs(builds) do
                if name ~= "defaultSpec" and type(build) == "table" then specs[#specs + 1] = name end
            end
            table.sort(specs)
            local current = DB[setting] or builds.defaultSpec or "none"
            print("|cff33ff99FLC:|r " .. tostring(profile.className) .. " talent spec: "
                .. tostring(current) .. ". Available: " .. table.concat(specs, ", ") .. ".")
        end
    elseif msg:match("^spec%s+") then
        local profile = getClassProfile()
        local builds, setting = profile.talentBuilds, profile.talentSetting
        local wanted = string.lower(msg:match("^spec%s+(%S+)") or "")
        local chosen = nil
        if builds then
            for name, build in pairs(builds) do
                if name ~= "defaultSpec" and type(build) == "table" and string.lower(name) == wanted then
                    chosen = name
                    break
                end
            end
            if not chosen and wanted == "sub" and builds.Subtlety then chosen = "Subtlety" end
            if not chosen and wanted == "assa" and builds.Assassination then chosen = "Assassination" end
        end
        if chosen and setting then
            DB[setting] = chosen
            render()
            print("|cff33ff99FLC:|r " .. tostring(profile.className) .. " talent guide set to " .. chosen .. ".")
        else
            print("|cffffcc00FLC:|r that class/spec guide is not configured yet. Use /flc spec to see available specs.")
        end
    elseif msg == "gearscan" then
        local scan = flcGearScanSnapshot and flcGearScanSnapshot() or nil
        print("|cff33ff99FLC:|r gear upgrade summary:")
        local shown = 0
        for _, item in ipairs((scan and scan.priorities) or {}) do
            if shown >= 3 then break end
            if item.status ~= "OPTIONAL EMPTY" and item.status ~= "NOT EXPECTED YET" then
                local text = tostring(item.slotName) .. " — " .. tostring(item.status)
                if item.upgrade and item.upgrade.target then
                    text = text .. ": " .. tostring(item.upgrade.target.name)
                        .. string.format(" (~+%d%%) — %s", math.floor((item.upgrade.pct or 0) + 0.5), tostring(item.upgrade.target.source or "?"))
                else
                    text = text .. ": no verified worthwhile replacement yet"
                end
                print(text)
                shown = shown + 1
            end
        end
        if shown == 0 then
            print("|cff33ff99No urgent gear upgrades found.|r")
        end
    elseif msg == "gear" then
        DB.gearAdvisor = not DB.gearAdvisor
        print("|cff33ff99FLC:|r gear advisor " .. (DB.gearAdvisor and "enabled." or "disabled."))
    elseif msg == "autoflight" then
        DB.autoFlight = not DB.autoFlight
        print("|cff33ff99FLC:|r flight assist " .. (DB.autoFlight and "enabled." or "disabled.") .. " (assist only; never auto-clicks a route).")
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
        settingsFrame:Hide()
    elseif msg == "settings" then
        DB.visible = true
        frame:Show()
        refreshSettingsPanel()
        settingsFrame:Show()
    elseif msg == "show" or msg == "" then
        DB.visible = true
        frame:Show()
        syncQuests()
    else
        print("|cff33ff99Forever Leveling Coach v" .. tostring(Data.version) .. "|r")
        print("/flc show, hide, settings, go, lazy, spec, relic, trained, autoaccept, autoturnin, sync, export, gear, gearscan, autoflight, arrow, lock, unlock, beginner")
    end
end

FLC:RegisterEvent("ADDON_LOADED")
FLC:RegisterEvent("PLAYER_LOGIN")
FLC:RegisterEvent("QUEST_LOG_UPDATE")
FLC:RegisterEvent("QUEST_DETAIL")
FLC:RegisterEvent("QUEST_PROGRESS")
FLC:RegisterEvent("QUEST_COMPLETE")
FLC:RegisterEvent("QUEST_ACCEPTED")
FLC:RegisterEvent("QUEST_REMOVED")
FLC:RegisterEvent("QUEST_TURNED_IN")
FLC:RegisterEvent("PLAYER_LEVEL_UP")
FLC:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
FLC:RegisterEvent("ZONE_CHANGED_NEW_AREA")
FLC:RegisterEvent("ZONE_CHANGED")
FLC:RegisterEvent("ZONE_CHANGED_INDOORS")
FLC:RegisterEvent("TAXIMAP_OPENED")
FLC:RegisterEvent("TRAINER_SHOW")
FLC:RegisterEvent("TRAINER_UPDATE")

FLC:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        copyDefaults()
        applySettings()
    elseif event == "PLAYER_LOGIN" then
        syncQuests()
        if C_Timer and C_Timer.NewTicker then
            FLC.ticker = C_Timer.NewTicker(15, syncQuests)
        end
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        scanCurrentClassTrainer()
        syncQuests()
    elseif event == "QUEST_DETAIL" then
        flcHandleQuestDetail()
        syncQuests()
    elseif event == "QUEST_PROGRESS" then
        flcHandleQuestProgress()
        syncQuests()
    elseif event == "QUEST_COMPLETE" then
        flcHandleQuestComplete()
        syncQuests()
    elseif event == "QUEST_TURNED_IN" then
        capturePendingHubChain(arg1)
        syncQuests()
    elseif event == "QUEST_ACCEPTED" then
        if DB and DB.pendingHubChain and tonumber(arg1) == tonumber(DB.pendingHubChain.questID) then
            clearPendingHubChain()
        end
        syncQuests()
    elseif event == "TAXIMAP_OPENED" then
        taxiOpenSerial = taxiOpenSerial + 1
        syncQuests()
        scanTaxiMapAndAutoFly()
    else
        syncQuests()
    end
end)
