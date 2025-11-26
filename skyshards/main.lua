local PI = math.pi

local MARK_TYPE_SKYSHARDS_UNKNOWN, MARK_TYPE_SKYSHARDS_KNOWN
local EVENT_NAMESPACE = 'IMP_CART_SKYSHARDS'

local Vector = LibImplex.Vector

local RI = LibImplex.RayIntersection()
local EM = LibImplex.EVENT_MANAGER

local UNMARKED_SKYSHARD_NEARBY_ID
local UNMARKER_SKYSHARD_LINE
local UNMARKED_SKYSHARD_ARROW

local function detectUnmarkedSkyshradNearby(mark, distance)
    if distance <= 5000 then
       UNMARKED_SKYSHARD_NEARBY_ID = mark.skyshardId
    end
end

local function keepOnPlayersHeightAndHideIfTooFar(marker, distance_, prwX, prwY, prwZ)
    marker[2] = prwY + 200

    local distanceLabel = marker.distanceLabel

    if distance_ >= 5000 then
        marker:SetHidden(true)
        if distanceLabel then distanceLabel:SetHidden(true) end
        return true
    end
end

local function keepOnPlayersHeight(marker, distance_, prwX, prwY, prwZ)
    marker[2] = prwY + 200
end

local function onReticleOver(marker)
    local skyshardId = marker.skyshardId
    if not skyshardId then return end

    ImperialCartographer_POILabel:GetNamedChild('POIName'):SetText(skyshardId)
    ImperialCartographer_POILabel:SetHidden(false)
end

local SKYSHARD_MARKS = {}

local function getSkyshardMarkById(skyshardId)
    for i = 1, #SKYSHARD_MARKS do
        local skyshardMark = SKYSHARD_MARKS[i]
        if skyshardMark.id == skyshardId then
            return skyshardMark
        end
    end
end

local function clearMarksForSkyshards()
    if #SKYSHARD_MARKS == 0 then return end

    for i = 1, #SKYSHARD_MARKS do
        local index = SKYSHARD_MARKS[i].index
        local type = SKYSHARD_MARKS[i].type
        ImperialCartographer.MarksManager:RemoveMark(type, index)
    end
    ZO_ClearNumericallyIndexedTable(SKYSHARD_MARKS)
end

local function getSkyshardCoordinates(skyshardId)
    return ImperialCartographer.userData.skyshards[skyshardId]
end

local function addMarksForSkyshards()
    clearMarksForSkyshards()

    local zoneId, prwX, prwY, prwZ = GetUnitRawWorldPosition('player')
    local convX, convZ = ImperialCartographer.Calculations.GetNWToRNWConversionFunctions(zoneId, prwX, prwY, prwZ)

    local calibration = {ImperialCartographer.Coordinates.GetCalibration(zoneId)}
    local rwY = 0

    local texture = '/esoui/art/tutorial/gamepad/achievement_categoryicon_skyshards.dds'
    local size = 36
    local colorKnown = {1, 1, 1}
    local colorUnknown = {0, 0, 150 / 255}

    local numSkyshardsInZone = GetNumSkyshardsInZone(zoneId)
    df('There are %d Skyshards in current zone', numSkyshardsInZone)
    for skyshardIndex = 1, numSkyshardsInZone do
        local skyshardId = GetZoneSkyshardId(zoneId, skyshardIndex) 

        -- -----------------------
        local nwX, nwZ, isInCurrentMap = GetNormalizedPositionForSkyshardId(skyshardId)

        if isInCurrentMap then
            local rnwX, rnwZ = convX(nwX), convZ(nwZ)
            local rwX, rwZ = ImperialCartographer.Coordinates.ConvertNormalizedToWorld(rnwX, rnwZ, calibration)

            local calculatedS = {rwX, rwY, rwZ}
            -- -----------------------

            local S = getSkyshardCoordinates(skyshardId)  -- TODO: extract all calculations to separate function
            local color = colorKnown
            local type = MARK_TYPE_SKYSHARDS_KNOWN

            if not S then
                color = colorUnknown
                type = MARK_TYPE_SKYSHARDS_UNKNOWN
            end

            local mark, markIndex = ImperialCartographer.MarksManager:AddMark(type, {}, S or calculatedS, texture, size, color)
            mark.skyshardId = skyshardId

            local nextIndex = #SKYSHARD_MARKS+1
            SKYSHARD_MARKS[nextIndex] = {
                type = type,
                index = markIndex,
                coordinate = Vector(calculatedS),
                id = skyshardId,
                -- mark = mark,
            }
        end
    end
end

local function findIndexOfClosestSkyshardMark()
    local minDistance = math.huge
    local index = nil

    local _, prwX, prwY, prwZ = GetUnitRawWorldPosition('player')

    local P = Vector({prwX, prwY, prwZ})

    for i = 1, #SKYSHARD_MARKS do
        local S = SKYSHARD_MARKS[i].coordinate
        S[2] = prwY
        local distance = (P - S):len()
        if distance < minDistance and distance < 500 then
            minDistance = distance
            index = i
        end
    end

    return index
end

local function measureLookingAtSkyshard()
    local index = findIndexOfClosestSkyshardMark()
    if not index then return end

    local skyshardMark = SKYSHARD_MARKS[index]
    local skyshardId = skyshardMark.id

    RI:ClearMeasurements()
    RI:AddMeasurement(skyshardMark.coordinate, {0, 1, 0})
    RI:AddCameraForwardRayToMeasurements()

    if not RI.intersection then return end

    local avgDistance = RI:CalculateAverageDistanceToIntersection()
    if avgDistance > 2 then d('Too far') return end

    -- if ImperialCartographer.userData.skyshards[skysharId] then
    --     d('This skyshard already has measured coordinates')
    -- end

    ImperialCartographer.userData.skyshards[skyshardId] = RI.intersection

    -- d('Intersection:')
    -- d(RI.intersection)
    -- d('-----------------')

    addMarksForSkyshards()
end

-- ------------------------------------------------------------------

local UPDATER_NAMESPACE = EVENT_NAMESPACE .. '_UPDATER'

local cameraFX, cameraFY, cameraFZ
local previousCameraFX, previousCameraFY, previousCameraFZ
local distance, D, P, previousDistance

local function stopUpdater()
    EVENT_MANAGER:UnregisterForUpdate(UPDATER_NAMESPACE)
    previousCameraFX, previousCameraFY, previousCameraFZ = nil, nil, nil
end

local DURATION = 4000
local startMs = 0
local laterId
local function startTimer()
    startMs = GetGameTimeMilliseconds()
    if laterId then zo_removeCallLater(laterId) end
    laterId = zo_callLater(measureLookingAtSkyshard, DURATION)
end

local function stopTimer()
    if laterId then
        zo_removeCallLater(laterId)
        laterId = nil
    end
end

local function ticking()
    return laterId ~= nil
end

local DO_NOT_MOVE = 'Do not move for %.1f seconds!'
local COME_CLOSER = 'Come closer (|c00AA00<5m|r): |cFFAA00%.1fm|r'
local EMOTE = false
local function heartbeat()
    cameraFX, cameraFY, cameraFZ = LibImplex_2DMarkers:Get3DRenderSpaceForward()
    local _, prwX, prwY, prwZ = GetUnitRawWorldPosition('player')

    P = Vector({prwX, prwY, prwZ})

    local skyshardMark = getSkyshardMarkById(UNMARKED_SKYSHARD_NEARBY_ID)
    D = skyshardMark.coordinate - P
    D[2] = 0

    distance = D:len()

    D = D:unit()

    if not (previousCameraFX == cameraFX and previousCameraFY == cameraFY and previousCameraFZ == cameraFZ and previousDistance == distance) then
        previousCameraFX, previousCameraFY, previousCameraFZ, previousDistance = cameraFX, cameraFY, cameraFZ, distance

        if distance >= 500 then
            ImperialCartographer_UnmarkedSkyshardCountdown:SetText(COME_CLOSER:format(distance / 100))
            stopTimer()
            EMOTE = false
            return
        end

        local pitchD = math.atan2(D[1], D[3])
        local pitchC = math.atan2(cameraFX, cameraFZ)

        if math.abs(pitchD - pitchC) > 0.005 then
            ImperialCartographer_UnmarkedSkyshardCountdown:SetText('Look directly at skyshard')
            stopTimer()
            EMOTE = false
            return
        end

        startTimer()
    end

    if ticking() then
        local secondsLeft = (DURATION - (GetGameTimeMilliseconds() - startMs)) / 1000
        d(secondsLeft)
        ImperialCartographer_UnmarkedSkyshardCountdown:SetText(DO_NOT_MOVE:format(secondsLeft))

        if not EMOTE and secondsLeft <= 3.3 then
            PlayEmoteByIndex(125)
            EMOTE = true
        end
    end

    -- if secondsLeft <= 0 then stopUpdater() end
end

local function startUpdater()
    EVENT_MANAGER:RegisterForUpdate(UPDATER_NAMESPACE, 10, heartbeat)
end

local function hideIfTooFar(marker, distance_)
    local distanceLabel = marker.distanceLabel

    if distance_ >= 15000 then
        marker:SetHidden(true)
        if distanceLabel then distanceLabel:SetHidden(true) end
        return true
    end
end

local INITIALIZED = false
EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
    -- if not ImperialCartographer.sv.questTracker.enabled then return end
    if not INITIALIZED then
        MARK_TYPE_SKYSHARDS_UNKNOWN = ImperialCartographer.MarksManager:AddMarkType(function() end, true, keepOnPlayersHeight, onReticleOver, detectUnmarkedSkyshradNearby)
        MARK_TYPE_SKYSHARDS_KNOWN = ImperialCartographer.MarksManager:AddMarkType(function() end, true, hideIfTooFar, onReticleOver)
        INITIALIZED = true

        if not ImperialCartographer.userData.skyshards then
            ImperialCartographer.userData.skyshards = {}
        end

        -- EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_COMBAT_EVENT, function(_, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
        --     if abilityId == 55146 then measureLookingAtSkyshard() end
        -- end)

        local PREVIOUS = nil
        EM.RegisterForEvent(EVENT_NAMESPACE, EM.EVENT_BEFORE_UPDATE, function()
            PREVIOUS = UNMARKED_SKYSHARD_NEARBY_ID
            UNMARKED_SKYSHARD_NEARBY_ID = nil
        end)

        local VERTICAL = Vector({0, 10000, 0})
        local function getPointsUnderAndAboveUnmarkedSkyshard()
            local unmarkedSkyshard = getSkyshardMarkById(UNMARKED_SKYSHARD_NEARBY_ID)
            if not unmarkedSkyshard then return end

            local _, prwX, prwY, prwZ = GetUnitRawWorldPosition('player')
            local S = unmarkedSkyshard.coordinate
            S[2] = prwY

            return S - VERTICAL, S + VERTICAL
        end

        local function keepAbovePlayer(object, distance, prwX, prwY, prwZ)
            object:Move({prwX, prwY + 250, prwZ})
        end

        local function pointToSkyshard(object)
            local pitch = math.atan2(D[1], D[3])
            object:Orient({PI / 2, pitch + PI / 2, 0})
        end

        local METER_AND_A_HALF = Vector({0, 150, 0})
        local function keepInFrontOfPlayer(object)
            object:Move(P + METER_AND_A_HALF + D * 150)
        end

        local function precalculateVectorTo(coordinates)
            local function inner(marker, distance_, prwX, prwY, prwZ, fX, fY, fZ)
                cameraFX, cameraFY, cameraFZ = fX, fY, fZ

                P = Vector({prwX, prwY, prwZ})
                D = coordinates - P
                D[2] = 0

                distance = D:len()

                D = D:unit()
            end

            return inner
        end

        EM.RegisterForEvent(EVENT_NAMESPACE, EM.EVENT_AFTER_UPDATE, function()
            if UNMARKED_SKYSHARD_NEARBY_ID ~= PREVIOUS then
                ImperialCartographer_UnmarkedSkyshard:SetHidden(UNMARKED_SKYSHARD_NEARBY_ID == nil)

                if UNMARKED_SKYSHARD_ARROW then
                    UNMARKED_SKYSHARD_ARROW:Delete()
                    UNMARKED_SKYSHARD_ARROW = nil
                end

                stopUpdater()

                if UNMARKED_SKYSHARD_NEARBY_ID then
                    --[[
                    local skyshardMark = getSkyshardMarkById(UNMARKED_SKYSHARD_NEARBY_ID)

                    UNMARKED_SKYSHARD_ARROW = LibImplex.Marker.Marker3D(
                        {0, 0, 0},
                        {0, 0, 0, true},
                        '/esoui/art/housing/direction_arrow.dds',
                        -- '/esoui/art/housing/direction_perspective_arrow.dds',
                        {4, 2},
                        -- {25 / 255, 69 / 255, 0},
                        {1, 1, 1},
                        -- keepAbovePlayer,
                        precalculateVectorTo(skyshardMark.coordinate),
                        keepInFrontOfPlayer,
                        pointToSkyshard
                    )
                    --]]

                    startUpdater()
                end

                --[[
                if UNMARKER_SKYSHARD_LINE then
                    UNMARKER_SKYSHARD_LINE:Delete()
                    UNMARKER_SKYSHARD_LINE = nil
                end

                if UNMARKED_SKYSHARD_NEARBY_ID then
                    local under, above = getPointsUnderAndAboveUnmarkedSkyshard()
                    d(under, above)
                    UNMARKER_SKYSHARD_LINE = LibImplex.Lines.Line(under, above)
                end
                ]]--
            end
        end)
    end

    addMarksForSkyshards()
end)
