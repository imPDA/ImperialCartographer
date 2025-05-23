local Log = ImperialCartographer_Logger()

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'ImperialCartographer'
addon.displayName = 'Imperial Cartographer'

addon.activeMarkers = {}
addon.markerIndexToPOIIdTable = {}
addon.poiIdToMarkerIndex = {}

local EVENT_NAMESPACE = addon.name .. '_EVENT_NAMESPACE'

local Vector = LibImplex.Vector

-- ----------------------------------------------------------------------------

function addon:GetClosestMarkerIndex()
    if #self.activeMarkers < 1 then return end

    local smallestDistance = math.huge
    local closestMarkerIndex = nil

    local playerPosition = {select(2, GetUnitRawWorldPosition('player'))}

    for i, marker in ipairs(self.activeMarkers) do
        local distance = marker:DistanceXZ(playerPosition)

        if distance < smallestDistance then
            smallestDistance = distance
            closestMarkerIndex = i
        end
    end

    return closestMarkerIndex
end

function addon:GetClosestMarker()
    return self.activeMarkers[self:GetClosestMarkerIndex()]
end

local function getMarkerColorByPinType(pinType)
    return {1, 1, 1}
end

local function getMarkerSizeByPinType(pinType)
    return 36
end

local NOT_ADDED = 1
local DEFAULT = 2
local ALWAYS_VISIBLE = 3
local ALWAYS_VISIBLE_NOT_ADDED = 4
addon.NOT_ADDED = NOT_ADDED
addon.DEFAULT = DEFAULT
addon.ALWAYS_VISIBLE = ALWAYS_VISIBLE
addon.ALWAYS_VISIBLE_NOT_ADDED = ALWAYS_VISIBLE_NOT_ADDED
function addon:Place(poiId, type)
    -- Log('Placing marker for POI ID#%d, userdata: %s, default data: %s', poiId, tostring(self.userData[poiId] ~= nil), tostring(self.data[poiId] ~= nil))
    local poiData = self.data[poiId] or self.userData[poiId]

    if not poiData then return end

    local zoneIndex, i = GetPOIIndices(poiId)
    local poiNX, poiNZ, pinType, texture = GetPOIMapInfo(zoneIndex, i)

    if poiId == 2549 then
        Log('Placing marker for POI ID#%d, userdata: %s, default data: %s', poiId, tostring(self.userData[poiId] ~= nil), tostring(self.data[poiId] ~= nil))
        Log('x:%d, y:%d, z:%d', unpack(poiData[1]))
    end

    -- Log('[%d]: `%s` placed', poiId, GetPOIInfo(zoneIndex, i))

    local rnX, rnZ = GetRawNormalizedWorldPosition(GetZoneId(zoneIndex), unpack(poiData[1]))
    local wX, wY, wZ = LibGPS3:LocalToWorld(rnX, rnZ)

    if not type then
        if not poiData[2] then
            type = NOT_ADDED
        else
            type = DEFAULT
        end
    elseif type == ALWAYS_VISIBLE then
        if not poiData[2] then
            type = ALWAYS_VISIBLE_NOT_ADDED
        end
    end

    local size = getMarkerSizeByPinType(pinType)
    local color = getMarkerColorByPinType(pinType)

    if type == NOT_ADDED then
        return self.UnknownPOIMarker(poiId, Vector({wX, poiData[1][2], wZ}), texture, 36, {1, 1, 0}, 3000)
    elseif type == DEFAULT then
        return self.POIMarker(poiId, Vector({wX, poiData[1][2], wZ}), texture, size, color)
    elseif type == ALWAYS_VISIBLE then
        return self.AlwaysVisiblePOIMarker(poiId, Vector({wX, poiData[1][2], wZ}), texture, size, color)
    elseif type == ALWAYS_VISIBLE_NOT_ADDED then
        return self.AlwaysVisibleUnknownPOIMarker(poiId, Vector({wX, poiData[1][2], wZ}), texture, size, {1, 1, 0})
    end
end

local function getCoordinatesViaLib3D(zoneIndex, i)
    local poiNX, poiNZ, pinType, texture = GetPOIMapInfo(zoneIndex, i)
    local poiX, poiZ = Lib3D:LocalToWorld(poiNX, poiNZ)

    Log('Normalized x:%.4f, y:%.4f', poiNX, poiNZ)
    Log('World (Lib3D) x:%d, y:%d', poiX * 100, poiZ * 100)
    Log('Global (LibGPS2) x:%d, y:%d', LibGPS2:LocalToGlobal(poiNX, poiNZ))
    Log('--------------------')

    -- local playerRawWorldPosition = Vector({select(2, GetUnitRawWorldPosition('player'))})
    -- local playerWorldPosition = Vector({select(2, GetUnitWorldPosition('player'))})
    -- local RENDER_SHIFT = playerRawWorldPosition - playerWorldPosition

    return poiX * 100, 14000, poiZ * 100
    -- return poiX * 100 + RENDER_SHIFT[1], 14000 + RENDER_SHIFT[2], poiZ * 100 + RENDER_SHIFT[3]
end

function addon:OnPlayerActivated(initial)
    for i = 1, #self.activeMarkers do
        self.activeMarkers[i]:Delete()
	    self.activeMarkers[i] = nil
    end

    local zoneIndex = GetUnitZoneIndex('player')
    if not zoneIndex then Log('`zoneIndex` was not received for player') return end

    Log('Loaded in [index:%d, id:%d] %s', zoneIndex, GetZoneId(zoneIndex), GetZoneNameByIndex(zoneIndex))
    Log('Num POIs: %d', GetNumPOIs(zoneIndex))

    for i = 1, GetNumPOIs(zoneIndex) do
        local poiId = self.GetPOIId(zoneIndex, i)

        if poiId then
            if not (self.data[poiId] or self.userData[poiId]) then
                self.userData[poiId] = {{getCoordinatesViaLib3D(zoneIndex, i)}}
            end

            local nextIndex = #self.activeMarkers+1
            local newMarker = self:Place(poiId)
            self.activeMarkers[nextIndex] = newMarker
            self.markerIndexToPOIIdTable[nextIndex] = poiId
            self.poiIdToMarkerIndex[poiId] = nextIndex

            local visited = (self.data[poiId] and true) or (self.userData[poiId][2] or false)

            local objectiveName, objectiveLevel, startDescription, finishedDescription = GetPOIInfo(zoneIndex, i)
            Log('%d -%sPOI (%s) placed', i, visited and ' ' or ' [x] ', objectiveName)
        else
            local objectiveName, objectiveLevel, startDescription, finishedDescription = GetPOIInfo(zoneIndex, i)
            Log('POI poiIndex %d (%s) is absent in databaase', i, objectiveName)
        end
    end

    IMP_CART_UpdateScrollListControl()
end

function addon:OnLoad()
    ImperialCartographerData = ImperialCartographerData or {}

    addon.data = self.DefaultData
    addon.userData = ImperialCartographerData

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function(_, initial) self:OnPlayerActivated(initial) end)

    self.RegisterReticlerOverEvents()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon:OnLoad()
end)

ImperialCartographer = addon