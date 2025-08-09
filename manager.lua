local Log = ImperialCartographer_Logger()

local EVENT_NAMESPACE = 'IMPERIAL_CARTOGRAPHER_MARKS_MANAGER_EVENT_NAMESPACE'
local EM = LibImplex.EVENT_MANAGER

-- ----------------------------------------------------------------------------

local MarksManager = {}

-- ----------------------------------------------------------------------------

local MARK_WITH_WAYPOINT

local function addWaypointTexture(marker)
    IMP_CART_Waypoint:SetAnchor(BOTTOM, marker.control, TOP, 0, 4)
    IMP_CART_Waypoint:SetHidden(false)

    marker:SetAlpha(1)
    marker:SetClampedToScreen(true)
    marker:SetClampedToScreenInsets(-48, -48, 48, 48)

    table.remove(marker.updateFunctions, 1)
end

function MarksManager:SetWaypointAt(wnX, wnY)
    local zoneIndex = GetCurrentMapZoneIndex()

    local closestPOIId
    local minimalDistance = math.huge

    -- TODO: improve detection
    for i = 1, GetNumPOIs(zoneIndex) do
        local nX, nY = GetPOIMapInfo(zoneIndex, i)
        local dX, dY = (nX - wnX) / nX, (nY - wnY) / nY
        local distance = math.sqrt(dX * dX + dY * dY)

        if distance < minimalDistance then
            closestPOIId = ImperialCartographer.GetPOIId(zoneIndex, i)
            minimalDistance = distance
        end
    end

    Log('Waypoint min error: %f', minimalDistance)
    if minimalDistance > 0.1 then return end

    local markType
    for type, marks in ipairs(self.marks) do
        for i, mark in ipairs(marks) do
            if self.markTags[type][i][1] == closestPOIId then
                MARK_WITH_WAYPOINT = mark
                markType = type
                break
            end
        end
    end

    if MARK_WITH_WAYPOINT then
        addWaypointTexture(MARK_WITH_WAYPOINT)

        EM.UnregisterForEvent(EVENT_NAMESPACE .. 'Waypoint', EM.EVENT_AFTER_UPDATE)  -- TODO: get rid of workaround
        EM.RegisterForEvent(EVENT_NAMESPACE .. 'Waypoint', EM.EVENT_AFTER_UPDATE, function()
            IMP_CART_Waypoint:SetHidden(MARK_WITH_WAYPOINT:IsHidden())
        end)
    end
end

function MarksManager:RemoveExistingWaypointMarker()
    if not MARK_WITH_WAYPOINT then return end

    IMP_CART_Waypoint:ClearAnchors()
    IMP_CART_Waypoint:SetHidden(true)

    MARK_WITH_WAYPOINT:SetClampedToScreen(false)

    EM.UnregisterForEvent(EVENT_NAMESPACE .. 'Waypoint', EM.EVENT_AFTER_UPDATE)

    table.insert(MARK_WITH_WAYPOINT.updateFunctions, 1, self.types[1].markerUpdateFunctions[1])

    MARK_WITH_WAYPOINT = nil
end

function MarksManager:SetWaypoint()
    local wnX, wnY = GetMapPlayerWaypoint()

    if wnX ~= 0 or wnY ~= 0 then
        self:SetWaypointAt(wnX, wnY)
    end
end

function MarksManager:SetupWaypoint()
    ZO_PostHook(_G, 'PingMap', function(pinType, mapDisplayType, nX, nY)
        if pinType ~= MAP_PIN_TYPE_PLAYER_WAYPOINT then return end

        self:RemoveExistingWaypointMarker()
        self:SetWaypointAt(nX, nY)
    end)

    ZO_PostHook(_G, 'RemovePlayerWaypoint', function() self:RemoveExistingWaypointMarker() end)
end

-- ----------------------------------------------------------------------------

local function updateDistanceLabel(marker, distance)
    local distanceLabel = marker.distanceLabel

    if distance > 100000 then
        distanceLabel:SetText(('%.1fkm'):format(distance * 0.00001))
    else
        distanceLabel:SetText(('%dm'):format(distance * 0.01))
    end

    -- local control = marker.control

    distanceLabel:SetHidden(false)
    -- distanceLabel:SetAlpha(control:GetAlpha())
    distanceLabel:SetDrawLevel(marker:GetDrawLevel())
end

local function addDistanceLabel(marker)
    if not marker.distanceLabel then return end

    marker.updateFunctions[#marker.updateFunctions+1] = updateDistanceLabel
    marker.distanceLabel:SetHidden(false)
end

-- ----------------------------------------------------------------------------

local RETICLE_OVER = nil
local RETICLE_OVER_DISTANCE = nil
local PREVIOUS_RETICLE_OVER = nil
local function checkReticleOver(marker, distance)
    local isValid, point, relTo, relPoint, offsetX, offsetY = marker:GetAnchor()

    if offsetX > -16 and offsetX < 16 then
        if offsetY > -16 and offsetY < 16 then
            if RETICLE_OVER then
                if distance < RETICLE_OVER_DISTANCE then
                    RETICLE_OVER = marker
                    RETICLE_OVER_DISTANCE = distance
                end
            else
                RETICLE_OVER = marker
                RETICLE_OVER_DISTANCE = distance
            end
        end
    end
end

local function registerReticleOverEvents()
    local EM = LibImplex.EVENT_MANAGER

    EM.RegisterForEvent('ImperialCartographerRticleOverMarker', EM.EVENT_BEFORE_UPDATE, function()
        RETICLE_OVER = nil
    end)

    EM.RegisterForEvent('ImperialCartographerRticleOverMarker', EM.EVENT_AFTER_UPDATE, function()
        if RETICLE_OVER ~= PREVIOUS_RETICLE_OVER then
            if RETICLE_OVER then
                RETICLE_OVER:reticleOverFunc()
            else
                ImperialCartographer_POILabel:SetHidden(true)
            end

            PREVIOUS_RETICLE_OVER = RETICLE_OVER
        end
    end)
end

-- ----------------------------------------------------------------------------

local function POIMarkerOnMouseEnter(self)
    local poiId = self.m_Marker.poiId
    Log('Mouse enter, poiId: %s', tostring(poiId))

    if not poiId then return end

    ImperialCartographer_POILabel:SetAnchor(BOTTOM, self, TOP)
    ImperialCartographer_POILabel:GetNamedChild('POIName'):SetText(('[POI#%d] %s\nx:%d y:%d z:%d'):format(poiId, self:GetName(), unpack(self.m_Marker.position)))
    ImperialCartographer_POILabel:SetHidden(false)
end

local function POIMarkerOnMouseExit(self)
    local poiId = self.m_Marker.poiId
    Log('Mouse exit, poiId: %s', tostring(poiId))

    ImperialCartographer_POILabel:SetHidden(true)
end

local function addMouseOverHandler(marker, poiId)
    marker.poiId = poiId
    marker:SetHandler('OnMouseEnter', POIMarkerOnMouseEnter)
    marker:SetHandler('OnMouseExit', POIMarkerOnMouseExit)
    marker:SetMouseEnabled(true)
end

-- ----------------------------------------------------------------------------

function MarksManager:Initialize()
    self.types = {}
    self.marks = {}
    self.markTags = {}

    registerReticleOverEvents()
    self:SetupWaypoint()
end

function MarksManager:AddMarkType(updateFunc, showDistanceLabel, distanceFunc, reticleOverFunc, mouseOverFunc)
    local typeIndex = #self.types + 1

    self.types[typeIndex] = {
        updateFunc = updateFunc,
        showDistanceLabel = showDistanceLabel,
        reticleOverFunc = reticleOverFunc,
        markerUpdateFunctions = {
            distanceFunc,
            mouseOverFunc
        },
    }

    self.marks[typeIndex] = {}
    self.markTags[typeIndex] = {}

    return typeIndex
end

function MarksManager:AddMark(type, tag, position, texture, size, color)
    local markTypeData = self.types[type]

    if not markTypeData then return end

    local mark = LibImplex.Marker.Marker2D(
        position,
        nil,
        texture,
        {size, size},
        color,
        unpack(markTypeData.markerUpdateFunctions)
    )

    if markTypeData.showDistanceLabel then
        addDistanceLabel(mark)
    end

    if markTypeData.reticleOverFunc then
        mark.reticleOverFunc = markTypeData.reticleOverFunc  -- extra field TODO: avoid
        mark.updateFunctions[#mark.updateFunctions+1] = checkReticleOver
    end

    local index = #self.marks[type] + 1
    self.marks[type][index] = mark
    self.markTags[type][index] = tag

    return mark, index
end

function MarksManager:RemoveMarks(type)
    local marks = self.marks[type]

    for i = 1, #marks do
        marks[i]:Delete()
        marks[i] = nil
    end
end

function MarksManager:UpdateMarks(type)
    if not type then return end

    self:RemoveMarks(type)

    self.types[type].updateFunc()
    self:SetWaypoint()
end

function MarksManager:Clear()
    local types = self.types

    for i = 1, #types do
        self:Remove(types[i])
    end
end

assert(ImperialCartographer, 'ImperaialCartographer main.lua is not initialized')
ImperialCartographer.MarksManager = MarksManager
