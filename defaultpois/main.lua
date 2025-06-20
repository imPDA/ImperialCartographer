local Vector = LibImplex.Vector

local EVENT_NAMESPACE = 'IMPERIAL_CARTOGRAPHER_DEFAULT_POIS_MAIN_EVENT_NAMESPACE'

local Log = ImperialCartographer_Logger()  -- TODO: hide if not loaded with debugging

-- ----------------------------------------------------------------------------

local function distanceFunction(marker, distance)
    local minDistance = 500
    local maxDistance = 23500

    local minAlpha = 1
    local maxAlpha = 0.2

    local distanceLabel = marker.distanceLabel

    if distance > maxDistance or distance < minDistance then
        marker.control:SetHidden(true)
        if distanceLabel then distanceLabel:SetHidden(true) end
        return true
    end

    local distanceSection = maxDistance - minDistance
    local alphaSection = maxAlpha - minAlpha

    local percent = (distance - minDistance) / distanceSection
    local alpha = minAlpha + percent * alphaSection
    marker.control:SetAlpha(alpha)
end

local function onReticleOver(marker)
    local poiId = marker.poiId
    if not poiId then return end

    local zoneIndex, poiIndex = GetPOIIndices(poiId)
    local objectiveName, objectiveLevel, startDescription, finishedDescription = GetPOIInfo(zoneIndex, poiIndex)

    -- ImperialCartographer_POILabel:SetAnchor(BOTTOM, marker.control, TOP)
    ImperialCartographer_POILabel:GetNamedChild('POIName'):SetText(objectiveName)
    ImperialCartographer_POILabel:SetHidden(false)
end

-- ----------------------------------------------------------------------------

local MARK_TYPE_DEFAULT_POI

local DefaultPOIs = {}

function DefaultPOIs:Initialize()
    self.data = ImperialCartographer.DefaultPOIsData

    MARK_TYPE_DEFAULT_POI = ImperialCartographer.MarksManager:AddMarkType(
        function() self:Update() end,
        true,
        distanceFunction,
        onReticleOver,
        nil
    )

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        ImperialCartographer.MarksManager:UpdateMarks(MARK_TYPE_DEFAULT_POI)
    end)

    -- ZO_PreHook(_G, 'ZO_WorldMap_RefreshWayshrines', function()
    --     Log('`ZO_WorldMap_RefreshWayshrines` prehook')
    -- end)

    -- ZO_PostHook(_G, 'ZO_WorldMap_RefreshWayshrines', function()
    --     Log('`ZO_WorldMap_RefreshWayshrines` posthook')
    -- end)

    self.discovered = {}
    local function isFreshlyDiscovered(zoneIndex, poiIndex)
        local poiNX, poiNZ, pinType, texture, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered = GetPOIMapInfo(zoneIndex, poiIndex)
        Log('%s vs %s', (self.discovered[poiIndex]), tostring(isDiscovered))
        if self.discovered[poiIndex] ~= isDiscovered then return true end
    end

    -- TODO: too heavy solution, refactor
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_POI_UPDATED, function(_, zoneIndex, poiIndex)
        if not isFreshlyDiscovered(zoneIndex, poiIndex) then return end

        Log('Updating markers because of %d', poiIndex)
        ImperialCartographer.MarksManager:UpdateMarks(MARK_TYPE_DEFAULT_POI)
    end)

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_FAST_TRAVEL_NETWORK_UPDATED, function(_, nodeIndex)
        local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
        if not isFreshlyDiscovered(zoneIndex, poiIndex) then return end

        Log('Updating markers because of %d', poiIndex)
        ImperialCartographer.MarksManager:UpdateMarks(MARK_TYPE_DEFAULT_POI)
    end)

    local currentPanel = WORLD_MAP_FILTERS.currentPanel
    local pinFilterCheckBoxes = currentPanel.pinFilterCheckBoxes

    for _, checkBox in ipairs(pinFilterCheckBoxes) do
        ZO_PostHook(checkBox, 'toggleFunction', function()
            ImperialCartographer.MarksManager:UpdateMarks(MARK_TYPE_DEFAULT_POI)
        end)
    end
end

local function getMarkerColorByPinType(pinType)
    return {1, 1, 1}
end

local function getMarkerSizeByPinType(pinType)
    return 36
end

local function getFilters()
    local isShowingWayshrines = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_WAYSHRINES)
    local isShowingDungeons = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_DUNGEONS)
    local isShowingTrials = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_TRIALS)
    local isShowingArenas = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_ARENAS)
    local isShowingHouses = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_HOUSES)
    local isShowingObjectives = ZO_WorldMap_IsPinGroupShown(MAP_FILTER_OBJECTIVES)

    local function passesFilters(zoneIndex, poiIndex)
        local poiType = GetPOIType(zoneIndex, poiIndex)
        local instanceType = GetPOIInstanceType(zoneIndex, poiIndex)
        local mapFilterOverride = GetPOIMapFilterOverride(zoneIndex, poiIndex)

        if mapFilterOverride ~= MAP_FILTER_NONE then
            if mapFilterOverride == MAP_FILTER_WAYSHRINES then
                return isShowingWayshrines
            elseif mapFilterOverride == MAP_FILTER_DUNGEONS then
                return isShowingDungeons
            elseif mapFilterOverride == MAP_FILTER_ARENAS then
                return isShowingArenas
            elseif mapFilterOverride == MAP_FILTER_TRIALS then
                return isShowingTrials
            elseif mapFilterOverride == MAP_FILTER_HOUSES then
                return isShowingHouses
            end
        elseif poiType == POI_TYPE_HOUSE then
            return isShowingHouses
        elseif poiType == POI_TYPE_WAYSHRINE then
            return isShowingWayshrines
        elseif instanceType == INSTANCE_TYPE_RAID then  -- INSTANCE_TYPE_GROUP
            return isShowingTrials
        elseif poiType == POI_TYPE_GROUP_DUNGEON then
            return isShowingDungeons
        else
            -- poiType == POI_TYPE_OBJECTIVE or poiType == POI_TYPE_PUBLIC_DUNGEON or poiType == POI_TYPE_ACHIEVEMENT
            return isShowingObjectives
        end
    end

    return passesFilters
end

function DefaultPOIs:AddPOI(zoneIndex, poiIndex)
    local poiId = ImperialCartographer.GetPOIId(zoneIndex, poiIndex)
    local objectiveName, objectiveLevel, startDescription, finishedDescription = GetPOIInfo(zoneIndex, poiIndex)

    if not poiId then return Log('%d - poiId: not in a database', poiIndex) end
    if not self.data[poiId] then return Log('%d - poiId: %d - %s - no data about position', poiIndex, poiId, objectiveName) end

    local poiData = self.data[poiId]

    if not poiData then return end

    local poiNX, poiNZ, pinType, texture, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered = GetPOIMapInfo(zoneIndex, poiIndex)
    self.discovered[poiIndex] = isDiscovered

    if not self.passesFilters(zoneIndex, poiIndex) then return Log('%d - poiId: %d - %s - Filtered', poiIndex, poiId, objectiveName) end

    local zoneId = GetZoneId(zoneIndex)
    local wX, wY, wZ = ImperialCartographer.Calculations.ConvertWtoRW(zoneId, unpack(poiData))

    local size = getMarkerSizeByPinType(pinType)
    local color = getMarkerColorByPinType(pinType)

    local mark, index = ImperialCartographer.MarksManager:AddMark(MARK_TYPE_DEFAULT_POI, {poiId}, Vector({wX, wY, wZ}), texture, size, color)
    mark.poiId = poiId  -- extra field TODO: avoid

    Log('%d - poiId: %d - %s - OK', poiIndex, poiId, objectiveName)
end

function DefaultPOIs:Update()
    ImperialCartographer.Calculations.ClearCalibrations()

    local zoneIndex = GetUnitZoneIndex('player')
    if not zoneIndex then Log('`zoneIndex` was not received for player') return end

    self.passesFilters = getFilters()

    Log('Loaded in [index:%d, id:%d] %s', zoneIndex, GetZoneId(zoneIndex), GetZoneNameByIndex(zoneIndex))

    for i, _ in pairs(self.discovered) do
        self.discovered[i] = false
    end

    for i = 1, GetNumPOIs(zoneIndex) do
        self:AddPOI(zoneIndex, i)
    end

    -- IMP_CART_UpdateScrollListControl()  -- TODO
end

assert(ImperialCartographer, 'ImperaialCartographer main.lua is not initialized')
ImperialCartographer.DefaultPOIs = DefaultPOIs
