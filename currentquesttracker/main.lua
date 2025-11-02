local MARK_TYPE_QUEST = nil
local EVENT_NAMESPACE = 'IMP_CART_CURRENT_QUEST'

local function keepOnPlayersHeight(marker, distance, prwX, prwY, prwZ)
    marker.position[2] = prwY + 200
end

local function onReticleOver(marker)
    local questName = GetJournalQuestInfo(marker.questIndex)

    ImperialCartographer_POILabel:GetNamedChild('POIName'):SetText(questName)
    ImperialCartographer_POILabel:SetHidden(false)
end

local CURRENT_QUEST_INDEX = nil
local MARK_INDICIES = {}
local function addMarkForQuestIndex(questIndex)
    local steps = WORLD_MAP_QUEST_BREADCRUMBS.conditionDataToPosition[questIndex]

    CURRENT_QUEST_INDEX = questIndex

    if #MARK_INDICIES > 0 then
        for i = 1, #MARK_INDICIES do
            ImperialCartographer.MarksManager:RemoveMark(MARK_TYPE_QUEST, MARK_INDICIES[i])
        end
        ZO_ClearNumericallyIndexedTable(MARK_INDICIES)
    end

    if not steps then return end

    local conditions = steps[#steps]

    if not conditions then return end

    for i = 1, #conditions do
        local data = conditions[i]

        local color
        if data.insideCurrentMapWorld then
            color = ImperialCartographer.sv.questTracker.markerColor
        else
            color = ImperialCartographer.sv.questTracker.offmapMarkerColor
        end

        local nwX, nwZ = data.xLoc, data.yLoc
        -- df('nwX: %f, nwZ: %f', nwX, nwZ)

        local zoneId, prwX, prwY, prwZ = GetUnitRawWorldPosition('player')
        local convX, convZ = ImperialCartographer.Calculations.GetNWToRNWConversionFunctions(zoneId, prwX, prwY, prwZ)

        local rnwX, rnwZ = convX(nwX), convZ(nwZ)

        local calibration = {ImperialCartographer.Coordinates.GetCalibration(zoneId)}
        local rwX, rwZ = ImperialCartographer.Coordinates.ConvertNormalizedToWorld(rnwX, rnwZ, calibration)
        local rwY = 0

        local texture = ImperialCartographer.sv.questTracker.texture
        local size = ImperialCartographer.sv.defaultPois.markerSize

        local mark, markIndex = ImperialCartographer.MarksManager:AddMark(MARK_TYPE_QUEST, data, {rwX, rwY, rwZ}, texture, size, color)
        mark.questIndex = questIndex
        mark.distanceLabel:SetFont(('$(BOLD_FONT)|$(KB_%d)|soft-shadow-thick'):format(ImperialCartographer.sv.defaultPois.fontSize or 20))
        mark.control:SetClampedToScreen(true)
        mark.control:SetClampedToScreenInsets(-24, -24, 24, 48)
        -- mark.insideCurrentMapWorld = data.insideCurrentMapWorld  -- TODO: is it possible to add zone name to offmap quest?

        MARK_INDICIES[#MARK_INDICIES+1] = markIndex
    end
end

local function addQuestConditionPosition(self_, conditionData, positionData)
    local questIndex, stepIndex, conditionIndex = conditionData.questIndex, conditionData.stepIndex, conditionData.conditionIndex
    -- df('Adding quest condition position for quest with index %d', questIndex)

    if questIndex ~= CURRENT_QUEST_INDEX then return end
    -- df('Position data: %f, %f', positionData.xLoc, positionData.yLoc)

    addMarkForQuestIndex(questIndex)
end

local function track(questIndex)
    -- df('Trying to focus quest with index %s', tostring(questIndex))
    addMarkForQuestIndex(questIndex)
end

local INITIALIZED = false
EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
    if not ImperialCartographer.sv.questTracker.enabled then return end

    if not INITIALIZED then
        MARK_TYPE_QUEST = ImperialCartographer.MarksManager:AddMarkType(function() end, true, keepOnPlayersHeight, onReticleOver)

        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_LEADER_TO_FOLLOWER_SYNC, function(_, messageOrigin, syncType, currentSceneName, nextSceneName)
            if currentSceneName == 'worldMap' and nextSceneName == 'hud' then
                local zoneId = GetUnitWorldPosition('player')
                local mapIndex = GetMapIndexByZoneId(zoneId)
                ZO_WorldMap_SetMapByIndex(mapIndex)
                WORLD_MAP_QUEST_BREADCRUMBS:RefreshQuest(CURRENT_QUEST_INDEX)
                -- track(CURRENT_QUEST_INDEX)
            end
        end)

        ZO_PostHook(WORLD_MAP_QUEST_BREADCRUMBS, 'AddQuestConditionPosition', addQuestConditionPosition)

        ZO_PostHook(ZO_Tracker, 'BeginTracking', function(self_, trackType, questIndex)
            if trackType ~= TRACK_TYPE_QUEST then return end
            track(questIndex)
        end)

        INITIALIZED = true
    end

    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.tracked and FOCUSED_QUEST_TRACKER.tracked[1] and FOCUSED_QUEST_TRACKER.tracked[1].arg1 then
        track(FOCUSED_QUEST_TRACKER.tracked[1].arg1)
    end
end)
