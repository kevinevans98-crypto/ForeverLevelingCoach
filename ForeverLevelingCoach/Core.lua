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
    height = 310,
    scale = 1,
    alpha = 0.95,
    locked = false,
    beginner = true,
    visible = true,
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

local function playerSupported()
    local faction = UnitFactionGroup("player")
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player") or 1

    return faction == Data.supported.faction
        and classFile == Data.supported.class
        and level >= Data.supported.minLevel
        and level <= Data.supported.maxLevel
end

local function chooseRouteStep(byID)
    local level = UnitLevel("player") or 1

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
frame:SetResizeBounds(340, 230, 700, 650)
frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("Forever Leveling Coach")

local versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
versionText:SetPoint("TOPRIGHT", -14, -15)
versionText:SetText("v" .. tostring(Data.version or "?"))

local routeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
routeText:SetPoint("TOPLEFT", 14, -45)
routeText:SetPoint("TOPRIGHT", -14, -45)
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

local resizeGrip = CreateFrame("Button", nil, frame)
resizeGrip:SetSize(18, 18)
resizeGrip:SetPoint("BOTTOMRIGHT", -3, 3)
resizeGrip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")

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

local currentQuests = {}
local currentByID = {}

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

local function render()
    if not playerSupported() then
        routeText:SetText("Current build: Horde Shaman levels 1–30")
        detailText:SetText("This character is outside the currently supported route.")
        questText:SetText("The addon can still be expanded later for additional Horde classes.")
        return
    end

    local step, active = chooseRouteStep(currentByID)
    local tag = TAG_LABELS[step.tag] or step.tag or "DO"

    routeText:SetText(tag .. ": " .. (step.title or "Next step"))

    local details = {}
    if step.questID then
        details[#details + 1] = "Quest ID: " .. tostring(step.questID)
    end
    if step.note then
        details[#details + 1] = step.note
    end
    local obj = objectiveSummary(active)
    if obj then
        details[#details + 1] = obj
    end
    detailText:SetText(table.concat(details, "\n\n"))

    local lines = {"Synced quest log:"}
    local maxShown = DB.beginner and 8 or 4
    for i, q in ipairs(currentQuests) do
        if i > maxShown then
            lines[#lines + 1] = "...and " .. tostring(#currentQuests - maxShown) .. " more"
            break
        end
        local status = q.isComplete and "complete" or "active"
        lines[#lines + 1] = string.format("• %s (%d) — %s", q.title, q.questID, status)
    end
    if #currentQuests == 0 then
        lines[#lines + 1] = "No active quests detected."
    end
    questText:SetText(table.concat(lines, "\n"))
end

local function syncQuests()
    currentQuests, currentByID = getQuestLogSnapshot()
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
end

local function exportSnapshot()
    local _, classFile = UnitClass("player")
    local lines = {
        "Forever Leveling Coach Export",
        "AddonVersion=" .. tostring(Data.version or "?"),
        "Character=" .. tostring(UnitName("player") or "?"),
        "Level=" .. tostring(UnitLevel("player") or "?"),
        "Class=" .. tostring(classFile or "?"),
        "Faction=" .. tostring(UnitFactionGroup("player") or "?"),
        "Quests:",
    }

    for _, q in ipairs(currentQuests) do
        lines[#lines + 1] = string.format("- %d | %s | %s", q.questID, q.title, q.isComplete and "complete" or "active")
        for _, obj in ipairs(q.objectives or {}) do
            lines[#lines + 1] = string.format("  %s %s", obj.finished and "[done]" or "[ ]", obj.text or "")
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
        print("/flc show, hide, sync, export, lock, unlock, beginner")
    end
end

FLC:RegisterEvent("ADDON_LOADED")
FLC:RegisterEvent("PLAYER_LOGIN")
FLC:RegisterEvent("QUEST_LOG_UPDATE")
FLC:RegisterEvent("QUEST_ACCEPTED")
FLC:RegisterEvent("QUEST_REMOVED")
FLC:RegisterEvent("QUEST_TURNED_IN")
FLC:RegisterEvent("PLAYER_LEVEL_UP")

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
