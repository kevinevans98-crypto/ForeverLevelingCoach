ForeverLevelingCoach_Data = {
    version = "0.8.3",
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
        [220] = true,  -- Call of Water: Vial of Purest Water to Islen Waterseer
        [63] = true,   -- Call of Water: Corrupt Manifestation's Bracers / Silverpine cleanse
        [96] = true,   -- Call of Water: return Shard of Water to Islen Waterseer
        [100] = true,  -- Call of Water: speak with Minor Manifestation of Water
        [1103] = true, -- Call of Water recovery: bring Water Sapta to Tiev Mordune
        [6503] = true, -- Ashenvale Outrunners
        [6441] = true, -- Satyr Horns
        [6548] = true, -- Avenge My Village
        [1062] = true, -- Goblin Invaders
        [6543] = true, -- The Warsong Reports
        [1489] = true, -- Hamuul Runetotem
        [6981] = true, -- The Glowing Shard
    },

    -- Adaptive smart-route scoring. Higher score = better next step.
    -- These are intentionally simple and explainable so exports can show why
    -- the addon made a recommendation.
    scoring = {
        tag = {
            IMPORTANT = 1000,
            DO = 300,
            OPTIONAL = 120,
            SKIP = -500,
        },
        completedTurnIn = 180,
        currentZoneCluster = 170,
        rememberedCluster = 60,
        clusterQuest = 22,
        partialProgressMax = 80,
        waypointNearMax = 90,
        clusterPriorityMax = 30,
    },

    -- Quest clusters let the router keep you in one area and stack nearby
    -- objectives instead of bouncing between zones after every quest.
    clusters = {
        ASHENVALE_SPLINTERTREE = {
            name = "Ashenvale / Splintertree",
            zoneAliases = { "Ashenvale", "Splintertree Post" },
            note = "Stack the nearby Ashenvale objectives before leaving the area.",
        },
        STONETALON_GRIMTOTEM = {
            name = "Stonetalon / Grimtotem",
            zoneAliases = { "Stonetalon Mountains", "Stonetalon", "Camp Aparaje" },
            note = "Finish the nearby Grimtotem and Venture Co. objectives together when you are already in Stonetalon.",
        },
        SILVERPINE_WATER = {
            name = "Silverpine / Water Totem",
            zoneAliases = { "Silverpine Forest", "Silverpine" },
            note = "Stay on the Water Totem objective while you are in Silverpine.",
        },
        BARRENS_RATCHET = {
            name = "Barrens / Ratchet",
            zoneAliases = { "The Barrens", "Barrens", "Ratchet" },
            note = "Handle Ratchet/Barrens hand-ins while passing through instead of making a special trip.",
        },
        THUNDER_BLUFF = {
            name = "Thunder Bluff",
            zoneAliases = { "Thunder Bluff" },
            note = "Bundle Thunder Bluff hand-ins with trainer, bank, auction, or travel stops.",
        },
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
        {
            questID = 220,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            cluster = "BARRENS_RATCHET",
            clusterPriority = 0,
            note = "Bring the Vial of Purest Water to Islen Waterseer in the Barrens. This continues the Water Totem chain.",
            waypoint = { mapID = 1413, x = 0.658, y = 0.438, label = "Islen Waterseer" },
        },
        {
            questID = 63,
            cluster = "SILVERPINE_WATER",
            clusterPriority = 1,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Defeat the Corrupt Manifestation of Water, then use the bracers and remaining pure water at the Brazier of Everfount in Silverpine Forest.",
            waypoint = { mapID = 1421, x = 0.383, y = 0.446, label = "Brazier of Everfount" },
            travelGuide = {
                {
                    zoneAliases = { "The Barrens", "Barrens", "Ratchet" },
                    instruction = "Travel north toward Durotar and Orgrimmar. Your cross-continent route is the Orgrimmar to Undercity zeppelin.",
                },
                {
                    zoneAliases = { "Durotar", "Orgrimmar" },
                    instruction = "Go to the zeppelin tower east of the Orgrimmar entrance and take the zeppelin to Undercity.",
                    waypoint = { mapID = 1411, x = 0.508, y = 0.136, label = "Undercity Zeppelin" },
                },
                {
                    zoneAliases = { "Tirisfal Glades", "Undercity", "Ruins of Lordaeron" },
                    instruction = "From Undercity/Tirisfal, travel southwest into Silverpine Forest. Continue toward the coast west of The Sepulcher.",
                },
                {
                    zoneAliases = { "Alterac Mountains", "Misty Shore" },
                    instruction = "OFF ROUTE: you went past Silverpine into Alterac Mountains near the Misty Shore. Turn back toward Silverpine Forest. The arrow stays hidden until you are back on the verified Silverpine map so it cannot send you the wrong way.",
                },
                {
                    zoneAliases = { "Silverpine Forest", "Silverpine", "The Sepulcher" },
                    instruction = "Follow the terrain route to the hidden pool.",
                    steps = {
                        {
                            instruction = "STEP 1/2: Get to The Sepulcher and move to the west/back side of the inn and catacomb area. Look for the two large trees and rocky ledge. The arrow stays off during this approach so it cannot point you through the cliff.",
                            advanceWhenWithin = {
                                waypoint = { mapID = 1421, x = 0.383, y = 0.446, label = "Hidden pool / Brazier of Everfount" },
                                distance = 0.055,
                            },
                        },
                        {
                            instruction = "STEP 2/2: You are close enough for local guidance. Use the trees/rock ledge to climb over, carefully drop to the hidden pool, use Water Sapta, kill the Corrupt Minor Manifestation of Water, loot the bracers, then click the Brazier and speak to the water elemental.",
                            waypoint = { mapID = 1421, x = 0.383, y = 0.446, label = "Hidden pool / Brazier of Everfount" },
                        },
                    },
                },
                {
                    instruction = "Travel to Silverpine Forest. Use the Orgrimmar to Undercity zeppelin if crossing from Kalimdor, then head west of The Sepulcher.",
                },
            },
        },

        {
            questID = 96,
            cluster = "BARRENS_RATCHET",
            clusterPriority = 0,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Final Water Totem hand-in: bring the Shard of Water back to Islen Waterseer in The Barrens. Turn this in before normal leveling quests.",
            waypoint = { mapID = 1413, x = 0.658, y = 0.438, label = "Islen Waterseer - Water Totem turn-in" },
            travelGuide = {
                {
                    zoneAliases = { "Silverpine Forest", "Silverpine", "Tirisfal Glades", "Undercity", "Ruins of Lordaeron" },
                    instruction = "Return to Undercity/Tirisfal and take the zeppelin back to Orgrimmar. Then travel south into The Barrens and return to Islen Waterseer at about 65.8, 43.8.",
                },
                {
                    zoneAliases = { "Durotar", "Orgrimmar" },
                    instruction = "From Orgrimmar, travel south through Durotar into The Barrens, then head to Islen Waterseer at about 65.8, 43.8.",
                },
                {
                    zoneAliases = { "The Barrens", "Barrens", "Ratchet" },
                    instruction = "Go to Islen Waterseer at about 65.8, 43.8 and turn in the Shard of Water. This awards your Water Totem and completes this major class-quest payoff.",
                    waypoint = { mapID = 1413, x = 0.658, y = 0.438, label = "Islen Waterseer - Water Totem turn-in" },
                },
                {
                    instruction = "Return to Islen Waterseer in The Barrens at about 65.8, 43.8 and turn in the Shard of Water.",
                },
            },
        },
        {
            questID = 100,
            cluster = "SILVERPINE_WATER",
            clusterPriority = 2,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Speak with the Minor Manifestation of Water at the purified Silverpine shrine. This is part of the Water Totem chain.",
            waypoint = { mapID = 1421, x = 0.383, y = 0.446, label = "Minor Manifestation of Water" },
        },
        {
            questID = 1103,
            cluster = "SILVERPINE_WATER",
            clusterPriority = 3,
            title = "Call of Water",
            tag = "IMPORTANT",
            minLevel = 20,
            maxLevel = 30,
            note = "Recovery step: bring a Water Sapta to Tiev Mordune in Silverpine Forest. The Sapta comes from Islen Waterseer in The Barrens.",
            nextPickup = {
                title = "Water Sapta",
                role = "Quest giver",
                npc = "Islen Waterseer",
                zone = "The Barrens",
                coords = "65.8, 43.8",
                showWhileActive = true,
                useArrow = true,
                note = "Look for a separate quest named Water Sapta from Islen Waterseer. If she does not offer it, the recovery chain may need to be restarted from Tiev Mordune.",
                waypoint = { mapID = 1413, x = 0.658, y = 0.438, label = "Next quest pickup: Water Sapta" },
            },
            travelGuide = {
                {
                    zoneAliases = { "The Barrens", "Barrens", "Ratchet" },
                    instruction = "Get the Water Sapta from Islen Waterseer around 65.8, 43.8, then return to Tiev Mordune in Silverpine Forest.",
                    waypoint = { mapID = 1413, x = 0.658, y = 0.438, label = "Islen Waterseer - Water Sapta" },
                },
                {
                    zoneAliases = { "Silverpine Forest", "Silverpine" },
                    instruction = "You need a Water Sapta for Tiev Mordune. If you do not have one, return to Islen Waterseer in The Barrens around 65.8, 43.8. After obtaining it, come back to Tiev Mordune around 37.3, 44.2 in Silverpine.",
                },
                {
                    instruction = "Obtain a Water Sapta from Islen Waterseer in The Barrens, then bring it to Tiev Mordune in Silverpine Forest around 37.3, 44.2.",
                },
            },
        },

        -- Verified from the player's live Forever quest log and current Forever databases.
        -- These are Classic-era quests present in Forever, not confirmed Forever-new quests.
        {
            questID = 6543,
            cluster = "ASHENVALE_SPLINTERTREE",
            clusterPriority = 1,
            title = "The Warsong Reports",
            tag = "DO",
            minLevel = 17,
            maxLevel = 25,
            note = "Efficient while moving through Ashenvale: it naturally sends you through multiple Horde positions. Complete it alongside nearby Ashenvale quests.",
        },
        {
            questID = 6503,
            cluster = "ASHENVALE_SPLINTERTREE",
            clusterPriority = 2,
            title = "Ashenvale Outrunners",
            tag = "DO",
            minLevel = 19,
            maxLevel = 27,
            note = "Good Splintertree-area kill quest. Pair it with other nearby Ashenvale objectives instead of making a separate trip.",
        },
        {
            questID = 6441,
            cluster = "ASHENVALE_SPLINTERTREE",
            clusterPriority = 3,
            title = "Satyr Horns",
            tag = "DO",
            minLevel = 21,
            maxLevel = 29,
            note = "Worth doing while questing around Splintertree and the nearby satyr camps. Avoid a long standalone detour just for this quest.",
        },
        {
            questID = 6981,
            cluster = "BARRENS_RATCHET",
            clusterPriority = 1,
            title = "The Glowing Shard",
            tag = "DO",
            minLevel = 15,
            maxLevel = 30,
            note = "Wailing Caverns follow-up. First speak with Sputtervalve beside the Ratchet flight master; he may not show a normal quest marker.",
            personTarget = {
                role = "Quest contact",
                name = "Sputtervalve",
                zone = "Ratchet, The Barrens",
                coords = "63.0, 37.2",
                useArrow = true,
                waypoint = { mapID = 1413, x = 0.6298, y = 0.3720, label = "Quest contact: Sputtervalve" },
            },
            nextPickup = {
                title = "In Nightmares",
                role = "Quest giver",
                npc = "Falla Sagewind",
                zone = "Wailing Caverns mountain, The Barrens",
                coords = "48.2, 32.8",
                showWhileActive = false,
                useArrow = true,
                note = "After Sputtervalve advances The Glowing Shard, go to Falla Sagewind on top of the Wailing Caverns mountain for the next quest.",
                waypoint = { mapID = 1413, x = 0.4818, y = 0.3282, label = "Next quest giver: Falla Sagewind" },
            },
        },
        {
            questID = 6548,
            cluster = "STONETALON_GRIMTOTEM",
            clusterPriority = 1,
            title = "Avenge My Village",
            tag = "OPTIONAL",
            minLevel = 12,
            maxLevel = 23,
            note = "Useful if you are already entering Stonetalon, especially because it leads into another short chain step. At level 21, do not travel far out of your way for it.",
        },
        {
            questID = 1062,
            cluster = "STONETALON_GRIMTOTEM",
            clusterPriority = 2,
            title = "Goblin Invaders",
            tag = "OPTIONAL",
            minLevel = 13,
            maxLevel = 23,
            note = "Fine if you are already near the Venture Co. loggers in Stonetalon. Skip a dedicated travel detour at level 21.",
        },
        {
            questID = 1489,
            cluster = "THUNDER_BLUFF",
            clusterPriority = 1,
            title = "Hamuul Runetotem",
            tag = "OPTIONAL",
            minLevel = 12,
            maxLevel = 23,
            note = "Short Wailing Caverns chain handoff. Turn it in when Thunder Bluff fits your travel route; do not make a large standalone trip solely for this step.",
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
