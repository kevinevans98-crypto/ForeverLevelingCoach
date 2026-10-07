ForeverLevelingCoach_Data = {
    version = "0.4.1",
    supported = {
        faction = "Horde",
        class = "SHAMAN",
        minLevel = 1,
        maxLevel = 30,
    },

    knownQuestIDs = {
        [2986] = true,
        [1534] = true,
        [1536] = true,
    },

    -- Route classifications:
    -- IMPORTANT = class unlock / major progression
    -- DO        = efficient route step
    -- OPTIONAL  = useful but skippable
    -- SKIP      = poor XP/time
    --
    -- IMPORTANT: Route by quest ID, not quest title. Forever can contain
    -- several quests with the same title.
    --
    -- Optional waypoint format for VERIFIED coordinates only:
    -- waypoint = { mapID = 123, x = 0.50, y = 0.50, label = "NPC / objective" }
    route = {
        -- Verified Horde Shaman Call of Water anchor IDs.
        -- These entries intentionally avoid invented coordinates.
        {
            questID = 2986,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Shaman Water Totem chain. Keep this quest prioritized until the chain advances.",
        },
        {
            questID = 1534,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Continue the Water Totem class chain.",
        },
        {
            questID = 1536,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Continue the Water Totem class chain.",
        },
    },

    fallback = {
        [21] = {
            tag = "DO",
            title = "Quest efficiently while we verify the 21-30 route",
            note = "Prioritize nearby yellow/orange quests and class quests. Avoid long detours for weak rewards.",
        },
        [22] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Use the synced quest log while the verified route database grows.",
        },
        [23] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Keep class quests and strong dungeon quest clusters prioritized.",
        },
        [24] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Prefer concentrated quest hubs over long single-quest travel.",
        },
        [25] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Keep worthwhile dungeon quests, class unlocks, and major gear rewards.",
        },
        [26] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Skip clearly poor XP/time detours.",
        },
        [27] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Favor efficient chains and nearby objectives.",
        },
        [28] = {
            tag = "DO",
            title = "Continue efficient questing",
            note = "Use dungeon quests when several objectives can be completed in one run.",
        },
        [29] = {
            tag = "DO",
            title = "Finish the strongest available quest chains",
            note = "Avoid grinding unless your quest options are temporarily weak.",
        },
        [30] = {
            tag = "IMPORTANT",
            title = "Level 30 reached",
            note = "Current Forever Leveling Coach beta route ends at the level cap.",
        },
    },
}
