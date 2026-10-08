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
    height = 138,
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
    mainView = "GUIDE",
    relicAdvisor = true,
    lazyMode = true,
    autoAccept = true,
    autoTurnIn = true,
    rogueTalentSpec = "Combat",
    lastClassTrainerLevel = 0,
    lastUIVersion = "0.16.1",
    lastCluster = nil,
}

local TAG_LABELS = {
    IMPORTANT = "IMPORTANT",
    DO = "DO",
    OPTIONAL = "OPTIONAL",
    SKIP = "SKIP",
}

local function getClassProfile()
    local _, classFile = UnitClass("player")
    if classFile == "SHAMAN" then
        return {
            classFile = classFile,
            weaponPreference = Data.shamanWeaponPreference,
            usesRelics = true,
        }
    elseif classFile == "ROGUE" then
        return {
            classFile = classFile,
            weaponPreference = nil,
            usesRelics = false,
            rogueGearProfile = Data.rogueGearProfile,
        }
    end
    return {
        classFile = classFile,
        weaponPreference = nil,
        usesRelics = false,
    }
end

local function flcTalentRecommendation()
    local level = UnitLevel("player") or 1
    local _, classFile = UnitClass("player")
    if classFile ~= "ROGUE" then return nil, nil end

    local builds = Data.rogueTalentBuilds
    if not builds then return nil, nil end

    local spec = (DB and DB.rogueTalentSpec) or builds.defaultSpec or "Combat"
    local build = builds[spec] or builds.Combat
    if not build then return nil, nil end

    if level < 10 then
        return build.name, "Talents unlock at level 10"
    end

    local pick = build.talentsByLevel and build.talentsByLevel[level]
    if pick then
        return build.name, string.format("%s %d/%d", pick.talent, pick.rank or 1, pick.maxRank or 1)
    end

    if level >= 30 then
        return build.name, tostring(build.final30 or "Level 30 build complete")
    end

    for l = level, 10, -1 do
        pick = build.talentsByLevel and build.talentsByLevel[l]
        if pick then
            return build.name, string.format("%s %d/%d", pick.talent, pick.rank or 1, pick.maxRank or 1)
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

    if charDB.lastUIVersion ~= "0.16.1" then
        charDB.width = 410
        charDB.height = 138
        charDB.alpha = 1
        charDB.lastUIVersion = "0.16.1"
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
local flcRenderGearScannerView

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

        if step.deferTurnInForQuestIDs then
            for _, deferQuestID in ipairs(step.deferTurnInForQuestIDs) do
                local deferActive = currentByID and currentByID[deferQuestID]
                if deferActive and not deferActive.isComplete and not isQuestCompleted(deferQuestID) then
                    score = score - 400
                    reasons[#reasons + 1] = "finish nearby objective before leaving (-400)"
                    break
                end
            end
        end

        if hasIncompletePrimaryInCluster(step) then
            local penalty = weights.finishClusterBeforeTurnInPenalty or 400
            score = score - penalty
            reasons[#reasons + 1] = string.format("finish local cluster before turn-in (-%d)", penalty)
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
frame:SetResizeBounds(340, 120, 700, 300)
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

local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
exportButton:SetSize(72, 22)
exportButton:SetPoint("TOPRIGHT", -12, -38)
exportButton:SetText("Export")

local goButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
goButton:SetSize(42, 22)
goButton:SetPoint("RIGHT", exportButton, "LEFT", -4, 0)
goButton:SetText("Go")
goButton:SetScript("OnClick", focusCurrentQuest)

local gearViewButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
gearViewButton:SetSize(52, 22)
gearViewButton:SetPoint("RIGHT", goButton, "LEFT", -4, 0)
gearViewButton:SetText("Gear")
gearViewButton:SetScript("OnClick", function()
    if not DB then return end
    DB.mainView = (DB.mainView == "GEAR") and "GUIDE" or "GEAR"
    gearViewButton:SetText(DB.mainView == "GEAR" and "Guide" or "Gear")
    if syncQuests then syncQuests() end
end)

exportButton:SetScript("OnClick", function()
    syncQuests()
    exportSnapshot()
end)

local routeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
routeText:SetPoint("TOPLEFT", 14, -45)
routeText:SetPoint("TOPRIGHT", -202, -45)
routeText:SetJustifyH("LEFT")
routeText:SetText("Loading route...")

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
arrowTexture:SetTexture("Interface/Buttons/UI-ScrollBar-ScrollUpButton-Up")
arrowTexture:SetAlpha(1)

local arrowLabel = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrowLabel:SetPoint("TOP", arrowTexture, "BOTTOM", 0, -2)
arrowLabel:SetWidth(180)
arrowLabel:SetJustifyH("CENTER")
arrowLabel:SetShadowOffset(1, -1)
arrowLabel:SetText("")

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
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
})
travelHintFrame:SetBackdropColor(0.03, 0.03, 0.03, 0.82)
travelHintFrame:SetBackdropBorderColor(0.72, 0.55, 0.20, 0.95)

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

    arrowFrame:Show()
    currentArrowState = "active-same-map"
    updateTravelHint(nil, currentArrowState)
    arrowTexture:SetRotation(relativeAngle)

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
    local label = waypoint.label or currentRouteStep.title or "Route target"
    if meters then
        if meters >= 1000 then
            arrowLabel:SetText(string.format("%s  •  %.2f km", label, meters / 1000))
        else
            arrowLabel:SetText(string.format("%s  •  %d m", label, math.floor(meters + 0.5)))
        end
    else
        local mapDistance = math.sqrt(dx * dx + dy * dy) * 100
        arrowLabel:SetText(string.format("%s  •  %.1f%%", label, mapDistance))
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

local function isClassTrainingDue()
    if not DB then return false end
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player") or 1
    if classFile ~= "SHAMAN" then return false end

    -- Live Forever Beta verification: at level 22 the spellbook's
    -- What's Training panel shows 0 available and the next Shaman ranks at 24.
    -- For the current 22-30 route, only begin reminders at 24.
    if level < 24 or (level % 2) ~= 0 then return false end
    return (tonumber(DB.lastClassTrainerLevel) or 0) < level
end

local function getNearestShamanTrainer()
    local trainers = Data.shamanTrainers or {}

    -- Prefer Thunder Bluff when already in/near Mulgore or Stonetalon.
    if zoneMatchesAliases({ "Thunder Bluff", "Mulgore", "Stonetalon Mountains", "Stonetalon" }) then
        return trainers.thunderBluff
    end

    -- Ashenvale, Durotar and The Barrens naturally feed into Orgrimmar.
    return trainers.orgrimmar
end

local function getTrainingStep()
    local trainer = getNearestShamanTrainer()
    if not trainer then return nil end

    local inTrainerCity = zoneMatchesAliases({ trainer.city })
    return {
        questID = nil,
        training = true,
        title = "Train Shaman",
        tag = "IMPORTANT",
        flightTarget = inTrainerCity and nil or trainer.city,
        personTarget = {
            role = "Class trainer",
            name = trainer.name,
            zone = trainer.zone,
            coords = trainer.coords,
            locationType = "SHAMAN TRAINER",
            locationNote = "Buy your new Shaman abilities/ranks for this level.",
            approach = "Go to the Shaman trainers and learn the available upgrades.",
            useArrow = true,
            waypoint = {
                mapID = trainer.mapID,
                x = trainer.x,
                y = trainer.y,
                label = "Shaman Trainer",
            },
        },
        note = "Class training is due at this level.",
    }, trainer
end

local function scanCurrentClassTrainer()
    if not DB then return end
    local npcName = UnitName and UnitName("npc")
    local trainers = Data.shamanTrainers or {}
    if not npcName or not trainers.names or not trainers.names[npcName] then return end

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

local function render()
    if not playerSupported() then
        routeText:SetText("Current build: Horde Shaman + Rogue levels 1–30")
        detailText:SetText("This character is outside the currently supported route.")
        questText:SetText("")
        questText:Hide()
        return
    end

    currentTrainingDue = isClassTrainingDue()
    currentTrainingTarget = currentTrainingDue and getNearestShamanTrainer() or nil

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
    elseif active and active.isComplete and step and step.turnInTarget and step.turnInTarget.waypoint
        and C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetBestMapForUnit("player") == step.turnInTarget.waypoint.mapID then
        currentAutoFlightTarget = nil
        currentAutoFlightStatus = "local-turn-in"
        currentNavigationWaypoint = step.turnInTarget.waypoint
        currentTravelInstruction = step.turnInTarget.instruction
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
        currentPersonTarget = step.turnInTarget
        if step.turnInTarget.instruction then
            currentTravelInstruction = step.turnInTarget.instruction
        end
        if step.turnInTarget.waypoint then
            currentNavigationWaypoint = step.turnInTarget.waypoint
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

    if gearViewButton then
        gearViewButton:SetText(DB and DB.mainView == "GEAR" and "Guide" or "Gear")
    end

    if DB and DB.mainView == "GEAR" and flcRenderGearScannerView then
        routeClickButton:Hide()
        flcRenderGearScannerView()
        updateArrow()
        return
    end
    routeClickButton:Show()

    -- Lazy play UI: show only the quest/task name plus ONE immediate action.
    -- Location is communicated by the safe same-zone arrow/local travel handoff.
    if DB and DB.lazyMode ~= false then
        routeText:SetText("STEP 1: " .. (step.title or "Next step"))
    else
        routeText:SetText(tag .. ": " .. (step.title or "Next step"))
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

    local detailLines = { "DO: " .. tostring(action) }

    local specName, talentPick = flcTalentRecommendation()
    if specName and talentPick then
        detailLines[#detailLines + 1] = "TALENT: " .. tostring(specName) .. " — " .. tostring(talentPick)
    end

    if DB and DB.lazyMode ~= false and step and step.cluster then
        local clusterQuests = getNearbyClusterQuestNames(step, currentByID)
        local stepNumber = 2
        for _, q in ipairs(clusterQuests) do
            local qAction = nil
            if q.active and q.active.isComplete then
                qAction = (q.step and q.step.turnInTarget and q.step.turnInTarget.action)
                    or ("TURN IN " .. string.upper(q.title or "QUEST"))
            elseif q.active then
                local qTarget = getBestObjectiveTarget(q.step, q.active)
                qAction = (qTarget and qTarget.action) or objectiveSummary(q.active)
            end

            detailLines[#detailLines + 1] = ""
            local queueLabel = q.background and " (WHILE QUESTING)" or ""
            detailLines[#detailLines + 1] = "STEP " .. tostring(stepNumber) .. ": " .. tostring(q.title or "Quest") .. queueLabel
            if qAction and qAction ~= "" then
                detailLines[#detailLines + 1] = "DO: " .. tostring(qAction)
            end
            stepNumber = stepNumber + 1
        end
    end

    detailText:SetText(table.concat(detailLines, "\n"))
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

    travelHintFrame:ClearAllPoints()
    travelHintFrame:SetPoint(DB.travelHintPoint or "TOP", UIParent, DB.travelHintRelativePoint or "TOP", DB.travelHintX or 0, DB.travelHintY or -190)
    travelHintFrame:SetSize(DB.travelHintWidth or 300, DB.travelHintHeight or 90)
    travelHintResizeGrip:SetShown(not DB.locked)
    if DB.arrowVisible == false then
        arrowFrame:Hide()
    else
        updateArrow()
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
    local talentSnapshot = flcTalentExportSnapshot()
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
        "WeaponPreference=" .. tostring((getClassProfile().weaponPreference and getClassProfile().weaponPreference.label) or "class-default"),
        "RecommendedSpec=" .. tostring(select(1, flcTalentRecommendation()) or "none"),
        "TalentRecommendation=" .. tostring(select(2, flcTalentRecommendation()) or "none"),
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
        "EquippedRelic=" .. tostring(select(1, flcRelicStatus()) or (select(3, flcRelicStatus()) == "not-applicable" and "not-applicable" or "none")),
        "KnownRelicTarget=" .. tostring(select(2, flcRelicStatus()) or (select(3, flcRelicStatus()) == "not-applicable" and "not-applicable" or "none")),
        "RelicStatus=" .. tostring(select(3, flcRelicStatus()) or "unknown"),
        "AutoFlightEnabled=" .. tostring(DB and DB.autoFlight ~= false or false),
        "AutoFlightTarget=" .. tostring(currentAutoFlightTarget or "none"),
        "AutoFlightStatus=" .. tostring(currentAutoFlightStatus or "none"),
        "CurrentFlightOptions=" .. (#currentTaxiOptions > 0 and table.concat(currentTaxiOptions, " | ") or "none"),
        "NextQuestPickup=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.title or "none"),
        "NextQuestPickupNPC=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.npc or "none"),
        "NextQuestPickupZone=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.zone or "none"),
        "NextQuestPickupCoords=" .. tostring(currentNextQuestPickup and currentNextQuestPickup.coords or "none"),
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
-- Lightweight leveling heuristic for Horde Shaman. The goal is a quick
-- "equip / keep" answer on hover, not a full endgame simulator.
local FLC_GEAR_WEIGHTS = {
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
}

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

local function flcItemScore(link, tooltip)
    if not link then return 0 end
    local score = 0
    local stats = GetItemStats and GetItemStats(link)
    if stats then
        for stat, value in pairs(stats) do
            local weight = FLC_GEAR_WEIGHTS[stat]
            if classFile == "ROGUE" then
                if stat == "ITEM_MOD_AGILITY_SHORT" then weight = 2.2 end
                if stat == "ITEM_MOD_STAMINA_SHORT" then weight = 0.8 end
                if stat == "ITEM_MOD_STRENGTH_SHORT" then weight = 0.5 end
                if stat == "ITEM_MOD_INTELLECT_SHORT" then weight = 0 end
                if stat == "ITEM_MOD_SPIRIT_SHORT" then weight = 0 end
            end
            if weight and value then
                score = score + (value * weight)
            end
        end
    end

    local _, _, _, itemLevel, _, _, _, _, equipLoc = GetItemInfo(link)
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
    local _, playerClass = UnitClass("player")

    local function weight(name)
        if playerClass == "ROGUE" then
            if name == "Agility" then return 2.2 end
            if name == "Stamina" then return 0.8 end
            if name == "Strength" then return 0.5 end
            if name == "Intellect" or name == "Spirit" then return 0 end
        end

        local weights = {
            Strength = 2.0,
            Agility = 1.4,
            Stamina = 0.7,
            Intellect = 0.5,
            Spirit = 0.2,
            AttackPower = 0.5,
            Crit = 0.6,
            Hit = 0.8,
            Haste = 0.4,
            ArmorPen = 0.4,
            SpellPower = 0.15,
            DPS = 10.0,
        }
        return weights[name] or 0
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
        local _, _, _, itemLevel = GetItemInfo(link)
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
            local _, _, _, _, _, itemType, _, _, equipLoc = GetItemInfo(mainLink)
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

    local itemName = GetItemInfo and select(1, GetItemInfo(link)) or link
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

flcRenderGearScannerView = function()
    local scan = flcGearScanSnapshot and flcGearScanSnapshot() or nil
    local _, playerClass = UnitClass("player")
    local level = UnitLevel("player") or 1

    routeText:SetText("GEAR SCANNER — Level " .. tostring(level) .. " " .. tostring(playerClass or ""))

    if not scan then
        detailText:SetText("Gear scan is unavailable on this client.")
        questText:SetText("")
        questText:Hide()
        refreshMainScroll()
        return
    end

    local lines = {}
    if #scan.priorities == 0 then
        lines[#lines + 1] = "|cff33ff99No obvious weak slots found.|r"
        lines[#lines + 1] = "Your equipped gear looks reasonable for your current level."
    else
        lines[#lines + 1] = "|cffffcc00TOP UPGRADE PRIORITIES|r"
        local limit = math.min(5, #scan.priorities)
        for i = 1, limit do
            local item = scan.priorities[i]
            local statusColor = "|cffffcc00"
            if item.status == "CRITICAL" or item.status == "EMPTY" then
                statusColor = "|cffff5555"
            elseif item.status == "WEAK" then
                statusColor = "|cffff9933"
            elseif item.status == "OPTIONAL EMPTY" then
                statusColor = "|cffaaaaaa"
            end
            lines[#lines + 1] = string.format(
                "%d. %s — %s%s|r",
                i,
                tostring(item.slotName or "?"),
                statusColor,
                tostring(item.status or "?")
            )
            lines[#lines + 1] = "   " .. tostring(item.itemName or "EMPTY")
            lines[#lines + 1] = "   " .. tostring(item.reason or "")
            if item.upgrade and item.upgrade.target then
                local target = item.upgrade.target
                lines[#lines + 1] = string.format(
                    "   UPGRADE: %s  (~+%d%%)",
                    tostring(target.name or "?"),
                    math.floor((item.upgrade.pct or 0) + 0.5)
                )
                lines[#lines + 1] = "   SOURCE: " .. tostring(target.source or "unknown")
                lines[#lines + 1] = "   " .. (target.routeFriendly and "|cff33ff99ROUTE-FRIENDLY|r" or "|cffffcc00OPTIONAL FARM/AH|r")
                if target.sourceNote then
                    lines[#lines + 1] = "   " .. tostring(target.sourceNote)
                end
            end
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffcc00EQUIPPED SLOTS|r"

    for _, item in ipairs(scan.slots or {}) do
        local status = tostring(item.status or "?")
        local itemName = tostring(item.itemName or "EMPTY")
        local suffix = ""
        if item.itemLevel then
            suffix = "  (iLvl " .. tostring(item.itemLevel) .. ")"
        end

        local color = "|cffaaaaaa"
        if status == "OK" or status == "N/A" or status == "NOT EXPECTED YET" or status == "HOLD" then
            color = "|cff33ff99"
        elseif status == "OPTIONAL EMPTY" then
            color = "|cffaaaaaa"
        elseif status == "CRITICAL" or status == "EMPTY" then
            color = "|cffff5555"
        elseif status == "WEAK" then
            color = "|cffff9933"
        elseif status == "WATCH" then
            color = "|cffffcc00"
        end

        lines[#lines + 1] = string.format(
            "%s%s: %s — %s%s|r",
            color,
            tostring(item.slotName or "?"),
            status,
            itemName,
            suffix
        )
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Gear Advisor: " .. ((DB and DB.gearAdvisor ~= false) and "ON" or "OFF")
    lines[#lines + 1] = "Click Guide above to return to the leveling route."

    detailText:SetText(table.concat(lines, "\n"))
    questText:SetText("")
    questText:Hide()
    mainScroll:SetVerticalScroll(0)
    refreshMainScroll()
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

local function flcRogueGearReason(itemType, itemSubType, equipLoc)
    local _, classFile = UnitClass("player")
    if classFile ~= "ROGUE" then return nil end
    local profile = Data.rogueGearProfile or {}

    if itemType == "Armor" then
        if itemSubType == "Leather" then
            return nil
        elseif itemSubType == "Cloth" then
            return "ROGUE_CLOTH", "Leather is preferred for Rogue leveling"
        elseif equipLoc ~= "INVTYPE_CLOAK" and equipLoc ~= "INVTYPE_NECK"
            and equipLoc ~= "INVTYPE_FINGER" and equipLoc ~= "INVTYPE_TRINKET" then
            return "UNUSABLE", "Rogues cannot use this armor type"
        end
    elseif itemType == "Weapon" then
        local ranged = equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN"
        if ranged then
            if profile.rangedWeapons and profile.rangedWeapons[itemSubType] then return nil end
            return "UNUSABLE", "Rogue ranged weapons: thrown, bows, crossbows, guns"
        end
        if equipLoc == "INVTYPE_2HWEAPON" then
            return "UNUSABLE", "Rogues cannot use two-handed weapons"
        end
        if profile.meleeWeapons and profile.meleeWeapons[itemSubType] then
            return nil
        end
        return "UNUSABLE", "Rogue melee: daggers, 1H swords, 1H maces, fist weapons"
    end
    return nil
end

local function flcGearEvaluateItem(link, sourceTooltip)
    if not link or not GetItemInfo then return nil end
    local _, _, _, _, requiredLevel, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
    if not equipLoc or equipLoc == "" then return nil end

    local slots = FLC_EQUIP_SLOTS[equipLoc]
    if not slots then return nil end

    local rogueGrade, rogueReason = flcRogueGearReason(itemType, itemSubType, equipLoc)
    if rogueGrade then return rogueGrade, rogueReason end

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
            tooltip:AddLine("FLC: NOT YOUR 2H TARGET", 1.0, 0.82, 0.2)
        elseif grade == "ROGUE_CLOTH" then
            tooltip:AddLine("FLC: SKIP — LEATHER IS BETTER", 1.0, 0.82, 0.2)
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
        DB.mainView = "GUIDE"
        gearViewButton:SetText("Gear")
        syncQuests()
        focusCurrentQuest()
    elseif msg == "sync" then
        syncQuests()
        print("|cff33ff99FLC:|r quest log synced.")
    elseif msg == "export" then
        syncQuests()
        exportSnapshot()
    elseif msg == "spec" then
        local current = DB.rogueTalentSpec or "Combat"
        print("|cff33ff99FLC:|r Rogue talent spec: " .. tostring(current) .. ". Use /flc spec combat, assassination, or subtlety.")
    elseif msg:match("^spec%s+") then
        local wanted = msg:match("^spec%s+(%S+)")
        local map = {
            combat = "Combat",
            assassination = "Assassination",
            subtlety = "Subtlety",
            sub = "Subtlety",
            assa = "Assassination",
        }
        local chosen = map[wanted or ""]
        if chosen and Data.rogueTalentBuilds and Data.rogueTalentBuilds[chosen] then
            DB.rogueTalentSpec = chosen
            render()
            print("|cff33ff99FLC:|r Rogue talent guide set to " .. chosen .. ".")
        else
            print("|cffffcc00FLC:|r use /flc spec combat, assassination, or subtlety.")
        end
    elseif msg == "gearscan" then
        DB.mainView = "GEAR"
        DB.visible = true
        frame:Show()
        gearViewButton:SetText("Guide")
        syncQuests()
        print("|cff33ff99FLC:|r gear scanner opened in the main window.")
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
    elseif msg == "show" or msg == "" then
        DB.visible = true
        frame:Show()
        syncQuests()
    else
        print("|cff33ff99Forever Leveling Coach v" .. tostring(Data.version) .. "|r")
        print("/flc show, hide, go, lazy, spec, relic, trained, autoaccept, autoturnin, sync, export, gear, gearscan, autoflight, arrow, lock, unlock, beginner")
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
    elseif event == "TAXIMAP_OPENED" then
        taxiOpenSerial = taxiOpenSerial + 1
        syncQuests()
        scanTaxiMapAndAutoFly()
    else
        syncQuests()
    end
end)
