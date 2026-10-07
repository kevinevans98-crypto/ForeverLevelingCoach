ForeverLevelingCoach_Data = {
    version = "0.13.1",
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
        [6571] = true, -- Warsong Supplies (live-discovered in Forever)
        [6921] = true, -- Amongst the Ruins (live-discovered in Forever)
        [6563] = true, -- The Essence of Aku'Mai (live-discovered in Forever)
        [6462] = true, -- Troll Charm (live-discovered in Forever)
        [216] = true, -- Between a Rock and a Thistlefur (live-discovered in Forever)
        [6641] = true, -- Vorsha the Lasher (live-discovered in Forever)
        [6442] = true, -- Naga at the Zoram Strand (live-discovered in Forever)
        [1489] = true, -- Hamuul Runetotem
        [1483] = true, -- Ziz Fizziks (live-discovered in Forever)
        [6981] = true, -- The Glowing Shard
        [3369] = true, -- In Nightmares (live-discovered in Forever)
        [914] = true,  -- Leaders of the Fang (live-discovered in Forever)
        [1490] = true, -- Nara Wildmane (live-discovered in Forever)
    },

    shamanTrainers = {
        names = {
            ["Kardris Dreamseeker"] = true,
            ["Sagorne Creststrider"] = true,
            ["Sian'tsu"] = true,
            ["Beram Skychaser"] = true,
            ["Siln Skychaser"] = true,
            ["Tigor Skychaser"] = true,
            ["Swart"] = true,
            ["Narm Skychaser"] = true,
            ["Shikrik"] = true,
            ["Meela Dawnstrider"] = true,
        },
        orgrimmar = {
            city = "Orgrimmar",
            name = "Kardris / Sagorne / Sian'tsu",
            zone = "Valley of Wisdom, Orgrimmar",
            coords = "38.9, 36.4",
            mapID = 1454,
            x = 0.389,
            y = 0.364,
        },
        thunderBluff = {
            city = "Thunder Bluff",
            name = "Beram / Siln / Tigor Skychaser",
            zone = "Spirit Rise, Thunder Bluff",
            coords = "22.0, 18.8",
            mapID = 1456,
            x = 0.220,
            y = 0.188,
        },
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
        ASHENVALE_ZORAM = {
            name = "Ashenvale / Zoram Strand",
            zoneAliases = { "Ashenvale", "Zoram'gar Outpost", "Zoram Strand" },
            note = "Bundle Zoram Strand naga/event quests while you are already on the west coast.",
        },
        ASHENVALE_THISTLEFUR = {
            name = "Ashenvale / Thistlefur",
            zoneAliases = { "Ashenvale", "Thistlefur Village", "Thistlefur Hold" },
            note = "Bundle Thistlefur kills, Troll Charms, and Logging Rope when moving through central-west Ashenvale.",
        },
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
        WAILING_CAVERNS = {
            name = "Wailing Caverns",
            zoneAliases = { "Wailing Caverns" },
            note = "Dungeon cluster: full area bonus only while inside Wailing Caverns; outside, entrance proximity is used instead.",
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
            flightTarget = "Ratchet",
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
            flightTarget = "Ratchet",
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

        {
            questID = 914,
            dungeon = true,
            flightTarget = "Ratchet",
            cluster = "WAILING_CAVERNS",
            clusterPriority = 0,
            title = "Leaders of the Fang",
            tag = "DO",
            minLevel = 18,
            maxLevel = 30,
            note = "Wailing Caverns dungeon quest. Complete all four Fang leaders in one run.",
            waypoint = { mapID = 1413, x = 0.460, y = 0.360, label = "Wailing Caverns cave entrance" },
            personTarget = {
                role = "Dungeon",
                name = "Wailing Caverns",
                zone = "The Barrens",
                coords = "46.0, 36.0",
                locationType = "DUNGEON — enter the cave first",
                locationNote = "The dungeon is inside the Wailing Caverns cave near Lushwater Oasis.",
                approach = "Go to the cave around 46.0, 36.0, enter it, then follow the cave inward to the dungeon portal. Do not climb onto the mountain for this quest.",
                useArrow = true,
                waypoint = { mapID = 1413, x = 0.460, y = 0.360, label = "Wailing Caverns cave entrance" },
            },
            travelGuide = {
                {
                    zoneAliases = { "The Barrens", "Barrens" },
                    instruction = "Go to the Wailing Caverns cave entrance around 46.0, 36.0 near Lushwater Oasis. Enter the cave and follow it inward to the dungeon portal.",
                    waypoint = { mapID = 1413, x = 0.460, y = 0.360, label = "Wailing Caverns cave entrance" },
                },
                {
                    zoneAliases = { "Wailing Caverns" },
                    instruction = "You are inside Wailing Caverns. Stay in the dungeon and complete the remaining Fang leader objectives.",
                },
                {
                    instruction = "If a flight master offers Ratchet, fly there. Then travel west/northwest to the Wailing Caverns cave entrance around 46.0, 36.0.",
                },
            },
        },

        -- Verified from the player's live Forever quest log and current Forever databases.
        -- These are Classic-era quests present in Forever, not confirmed Forever-new quests.
        {
            questID = 6442,
            title = "Naga at the Zoram Strand",
            tag = "DO",
            minLevel = 14,
            maxLevel = 24,
            cluster = "ASHENVALE_ZORAM",
            clusterPriority = 1,
            note = "Fast local kill quest while at Zoram'gar. Kill Wrathtail naga on the nearby coast.",
            objectiveTargets = {
                {
                    objectiveContains = "Wrathtail Head",
                    role = "Kill / loot",
                    name = "Wrathtail Naga",
                    zone = "Zoram Strand, Ashenvale",
                    coords = "around 10, 21",
                    locationType = "MOBS — along the coast",
                    locationNote = "Kill nearby Wrathtail naga and loot their heads.",
                    approach = "Ride north along the coast from Zoram'gar Outpost.",
                    instruction = "Kill Wrathtail naga along Zoram Strand around 10, 21.",
                    action = "LOOT 20 WRATHTAIL HEADS",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.10, y = 0.21, label = "Wrathtail Naga" },
                },
            },
        },
        {
            questID = 6641,
            title = "Vorsha the Lasher",
            tag = "OPTIONAL",
            minLevel = 20,
            maxLevel = 27,
            cluster = "ASHENVALE_ZORAM",
            clusterPriority = 2,
            note = "Elite escort/event. Good if you have help; skip if solo time is tight.",
            objectiveTargets = {
                {
                    objectiveContains = "Vorsha the Lasher",
                    role = "Escort / elite event",
                    name = "Muglash",
                    zone = "Zoram Strand, Ashenvale",
                    coords = "around 12.1, 34.6",
                    locationType = "ELITE EVENT — bring help if needed",
                    locationNote = "Escort Muglash to the brazier, extinguish it, then defend against naga and Vorsha.",
                    approach = "Start with Muglash at Zoram'gar and follow the escort north along the coast.",
                    instruction = "Start Muglash's escort at Zoram'gar; defeat Vorsha when she appears.",
                    action = "ESCORT MUGLASH / KILL VORSHA",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.121, y = 0.346, label = "Muglash — Vorsha event" },
                },
            },
        },
        {
            questID = 216,
            title = "Between a Rock and a Thistlefur",
            tag = "DO",
            minLevel = 21,
            maxLevel = 28,
            cluster = "ASHENVALE_THISTLEFUR",
            clusterPriority = 1,
            note = "Efficient kill quest that stacks with Troll Charm and Logging Rope.",
            objectiveTargets = {
                {
                    objectiveContains = "Thistlefur",
                    role = "Kill",
                    name = "Thistlefur Village",
                    zone = "Ashenvale",
                    coords = "around 35, 39",
                    locationType = "MOBS — furbolg village",
                    locationNote = "Kill Thistlefur Avengers and Shamans here.",
                    approach = "Travel east from Zoram'gar toward Thistlefur Village.",
                    instruction = "Kill Thistlefur mobs around 35, 39.",
                    action = "KILL THISTLEFUR AVENGERS / SHAMANS",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.35, y = 0.39, label = "Thistlefur Village" },
                },
            },
        },
        {
            questID = 6462,
            title = "Troll Charm",
            tag = "DO",
            minLevel = 19,
            maxLevel = 29,
            cluster = "ASHENVALE_THISTLEFUR",
            clusterPriority = 2,
            note = "Stacks with Thistlefur kills; collect charms from chests in Thistlefur Hold.",
            objectiveTargets = {
                {
                    objectiveContains = "Troll Charm",
                    role = "Loot",
                    name = "Troll Charm chests",
                    zone = "Thistlefur Hold, Ashenvale",
                    coords = "around 41, 33",
                    locationType = "CHESTS — inside Thistlefur Hold",
                    locationNote = "Loot the troll charm chests in the cave.",
                    approach = "Enter Thistlefur Hold at the end of the village and look for charm chests.",
                    instruction = "Loot Troll Charms in Thistlefur Hold around 41, 33.",
                    action = "LOOT 8 TROLL CHARMS",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.41, y = 0.33, label = "Thistlefur Hold" },
                },
            },
        },
        {
            questID = 6563,
            title = "The Essence of Aku'Mai",
            tag = "OPTIONAL",
            minLevel = 17,
            maxLevel = 28,
            note = "Blackfathom Deeps dungeon objective. Save it for a BFD run instead of making a standalone trip.",
        },
        {
            questID = 6921,
            title = "Amongst the Ruins",
            tag = "OPTIONAL",
            minLevel = 20,
            maxLevel = 30,
            note = "Blackfathom Deeps dungeon objective. Get the Fathom Core during the same BFD run as other dungeon work.",
        },
        {
            questID = 6543,
            flightTarget = "Splintertree Post",
            cluster = "ASHENVALE_SPLINTERTREE",
            clusterPriority = 1,
            title = "The Warsong Reports",
            tag = "DO",
            minLevel = 17,
            maxLevel = 25,
            note = "Efficient while moving through Ashenvale: it naturally sends you through multiple Horde positions. Complete it alongside nearby Ashenvale quests.",
            objectiveTargets = {
                {
                    objectiveContains = "Warsong Scout Update",
                    role = "Report contact",
                    name = "Warsong Scout",
                    zone = "Ashenvale — near Splintertree Post",
                    coords = "71.1, 68.4",
                    locationType = "OUTDOOR — tower near Splintertree Post",
                    locationNote = "The Scout is at the tower just outside Splintertree Post.",
                    approach = "Go to the tower near Splintertree Post and speak to the Warsong Scout.",
                    instruction = "Head to the tower near Splintertree Post around 71.1, 68.4.",
                    action = "Deliver the Scout report",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.7105, y = 0.6836, label = "Warsong Scout" },
                },
                {
                    objectiveContains = "Warsong Outrider Update",
                    role = "Report contact",
                    name = "Warsong Outrider",
                    zone = "Ashenvale — east road",
                    coords = "patrols around 84, 50",
                    locationType = "MOVING NPC — mounted on a wolf",
                    locationNote = "The Outrider patrols the road toward Warsong Lumber Camp/Azshara and may not have an obvious quest marker.",
                    approach = "Follow the east road around 84, 50 and look for the mounted Warsong Outrider moving along the road.",
                    instruction = "Look along the east road around 84, 50 for the mounted Warsong Outrider; she patrols instead of standing still.",
                    action = "Deliver the Outrider report",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.8400, y = 0.5000, label = "Warsong Outrider patrol road" },
                },
                {
                    objectiveContains = "Warsong Runner Update",
                    role = "Report contact",
                    name = "Warsong Runner",
                    zone = "Zoram'gar Outpost, Ashenvale",
                    coords = "12.2, 34.2",
                    locationType = "OUTDOOR — Horde outpost",
                    locationNote = "The Runner is at Zoram'gar Outpost near the flight master and may not show a normal quest marker.",
                    approach = "Travel west to Zoram'gar Outpost and speak directly to the Warsong Runner near the flight master.",
                    instruction = "Travel to Zoram'gar Outpost on the west coast around 12.2, 34.2.",
                    action = "Deliver the Runner report",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.1221, y = 0.3420, label = "Warsong Runner" },
                },
            },
        },
        {
            questID = 6571,
            title = "Warsong Supplies",
            tag = "OPTIONAL",
            minLevel = 22,
            maxLevel = 30,
            note = "Long multi-zone supply quest. Do local Ashenvale pieces opportunistically; do not let it interrupt a stronger route.",
            objectiveTargets = {
                {
                    objectiveContains = "Warsong Oil",
                    role = "Quest object",
                    name = "Warsong Oil",
                    zone = "Night Run, Ashenvale",
                    coords = "around 66, 55",
                    locationType = "GROUND OBJECT — small green bottle",
                    locationNote = "The oil is found in the satyr camps. Night Run is the preferred lower-risk location.",
                    approach = "Search the Night Run satyr camp for the clickable oil bottle.",
                    instruction = "Search Night Run around 66, 55 for Warsong Oil.",
                    action = "LOOT WARSONG OIL",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.66, y = 0.55, label = "Warsong Oil — Night Run" },
                },
                {
                    objectiveContains = "Logging Rope",
                    role = "Kill / loot",
                    name = "Foulweald Furbolgs",
                    zone = "Greenpaw Village, Ashenvale",
                    coords = "around 55, 61",
                    locationType = "MOB DROP",
                    locationNote = "Logging Rope drops from Ashenvale furbolgs.",
                    approach = "Kill Foulweald furbolgs while nearby until Logging Rope drops.",
                    instruction = "Kill Foulweald furbolgs around 55, 61 for Logging Rope.",
                    action = "LOOT LOGGING ROPE",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.55, y = 0.61, label = "Logging Rope — Foulweald" },
                },
                {
                    objectiveContains = "Warsong Saw Blades",
                    role = "Supply exchange",
                    name = "Pixel",
                    zone = "Splintertree Post, Ashenvale",
                    coords = "around 73, 61",
                    locationType = "NPC — requires Deadly Blunderbuss",
                    locationNote = "Pixel gives the saw blades in exchange for a Deadly Blunderbuss.",
                    approach = "Bring a Deadly Blunderbuss to Pixel near Splintertree Post.",
                    instruction = "Get a Deadly Blunderbuss, then bring it to Pixel near Splintertree Post.",
                    action = "TRADE DEADLY BLUNDERBUSS FOR SAW BLADES",
                    useArrow = true,
                    waypoint = { mapID = 1440, x = 0.73, y = 0.61, label = "Pixel — Saw Blades" },
                },
            },
        },
        {
            questID = 6503,
            flightTarget = "Splintertree Post",
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
            flightTarget = "Splintertree Post",
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
            flightTarget = "Ratchet",
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
                locationType = "OUTSIDE — Ratchet",
                locationNote = "Sputtervalve stands beside the Ratchet flight master and may not show a normal quest marker.",
                approach = "Stay in Ratchet; go to the flight master area and speak directly to Sputtervalve.",
                useArrow = true,
                waypoint = { mapID = 1413, x = 0.6298, y = 0.3720, label = "Quest contact: Sputtervalve" },
            },
            nextPickup = {
                title = "In Nightmares",
                role = "Quest giver",
                npc = "Falla Sagewind",
                zone = "Wailing Caverns mountain, The Barrens",
                coords = "48.2, 32.8",
                locationType = "OUTSIDE — on top of the Wailing Caverns mountain, NOT inside the dungeon",
                locationNote = "Falla Sagewind is in a small hut on top of the mountain above Wailing Caverns.",
                approach = "Do not enter the Wailing Caverns instance. Approach the mountain from the outside, climb up onto the top, then follow the arrow to Falla around 48.2, 32.8.",
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
            flightTarget = "Thunder Bluff",
            cluster = "THUNDER_BLUFF",
            clusterPriority = 1,
            title = "Hamuul Runetotem",
            tag = "OPTIONAL",
            minLevel = 12,
            maxLevel = 23,
            note = "Short Wailing Caverns chain handoff. Turn it in when Thunder Bluff fits your travel route; do not make a large standalone trip solely for this step.",
        },
        {
            questID = 3369,
            flightTarget = "Thunder Bluff",
            cluster = "THUNDER_BLUFF",
            clusterPriority = 0,
            title = "In Nightmares",
            tag = "DO",
            minLevel = 18,
            maxLevel = 30,
            note = "Your live Forever quest log confirms this step is complete. Bring the Nightmare Shard to Hamuul Runetotem on Elder Rise in Thunder Bluff.",
            personTarget = {
                role = "Quest turn-in",
                name = "Hamuul Runetotem",
                zone = "Elder Rise, Thunder Bluff",
                locationType = "CITY — Elder Rise, Thunder Bluff",
                locationNote = "Hamuul Runetotem is on Elder Rise in Thunder Bluff. This is a city turn-in, not a dungeon objective.",
                approach = "Travel to Thunder Bluff, enter the city lifts, then go to Elder Rise and find Hamuul Runetotem. Use a flight path to Thunder Bluff if your current flight master offers it.",
            },
            travelGuide = {
                {
                    zoneAliases = { "The Barrens", "Barrens", "Ratchet" },
                    instruction = "FAST ROUTE: Use the nearest flight master and fly to Thunder Bluff if that destination is available. If not, travel southwest through The Barrens into Mulgore, enter Thunder Bluff by lift, then go to Elder Rise and turn In Nightmares in to Hamuul Runetotem.",
                },
                {
                    zoneAliases = { "Mulgore" },
                    instruction = "Head to Thunder Bluff, take a city lift up, then go to Elder Rise and find Hamuul Runetotem.",
                },
                {
                    zoneAliases = { "Thunder Bluff" },
                    instruction = "You are in Thunder Bluff. Go to Elder Rise and find Hamuul Runetotem to turn in In Nightmares.",
                },
                {
                    instruction = "Travel to Thunder Bluff and go to Elder Rise. Turn In Nightmares in to Hamuul Runetotem.",
                },
            },
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
