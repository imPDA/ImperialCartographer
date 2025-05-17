local Log = ImperialCartographer_Logger()

local addon = {}

addon.name = 'ImperialCartographer'
addon.displayName = 'Imperial Cartographer'

local EVENT_NAMESPACE = addon.name .. '_EVENT_NAMESPACE'

-- ----------------------------------------------------------------------------

local mt = {}
function mt.__index(tbl, key)
    local value = rawget(tbl, key)

    if value == nil then
        value = setmetatable({}, mt)
        rawset(tbl, key, value)
    end

    return value
end

local function AutoTable()
    return setmetatable({}, mt)
end

-- ----------------------------------------------------------------------------

addon.activeMarkers = {}
addon.markerIndexToPOIIdTable = {}

local POI
local function discoverPOI()
    local poi = AutoTable()
    POI = poi
    -- GLOBAL_POI = poi

    for i = 1, 3000 do  -- ~2800 in U45
        local zoneIndex, poiIndex = GetPOIIndices(i)

        if zoneIndex ~= 1 then
            local zoneId = GetZoneId(zoneIndex)
            poi[zoneId][poiIndex] = i
        end
    end
end

local POIMarker = ImperialCartographer.POIMarker
local UnknownPOIMarker = ImperialCartographer.UnknownPOIMarker

local function getXZDistanceTo(position)
    local pX, pY, pZ = select(2, GetUnitWorldPosition('player'))
    local mX, mY, mZ = unpack(position)

    local dX = mX - pX
    local dZ = mZ - pZ

    return math.sqrt(dX * dX + dZ * dZ)
end

function addon:GetClosestMarkerIndex()
    if #self.activeMarkers < 1 then return end

    local smallestDistance = math.huge
    local closestMarkerIndex = nil

    local playerPosition = {select(2, GetUnitWorldPosition('player'))}

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
    return {99/255, 149/255, 238/255}
end

local function getDiscoveryDistanceByPinType(pinType)
    return 235
end

local function getMarkerSizeByPinType(pinType)
    return 36
end

function addon:Place(poiId)
    Log('Placing marker for POI ID#%d, userdata: %s, default data: %s', poiId, tostring(self.userData[poiId] ~= nil), tostring(self.data[poiId] ~= nil))
    local poiData = self.userData[poiId] or self.data[poiId]

    if not poiData then return end

    local zoneIndex, i = GetPOIIndices(poiId)
    local poiNX, poiNZ, pinType, texture = GetPOIMapInfo(zoneIndex, i)

    if not poiData[2] then
        return UnknownPOIMarker(poiId, poiData[1], texture, 36, {1, 1, 0}, 3000)
    else
        return POIMarker(poiId, poiData[1], texture, getMarkerSizeByPinType(pinType), getMarkerColorByPinType(pinType), getDiscoveryDistanceByPinType(pinType))
    end
end

function addon:OnPlayerActivated(initial)
    for i = 1, #self.activeMarkers do
        self.activeMarkers[i]:Delete()
	    self.activeMarkers[i] = nil
    end

    local zoneIndex = GetUnitZoneIndex('player')
    if not zoneIndex then Log('`zoneIndex` was not received for player') return end

    for i = 1, GetNumPOIs(zoneIndex) do
        local zoneId = GetZoneId(zoneIndex)
        local poiId = POI[zoneId][i]

        if type(poiId) == 'number' then
            if not (self.data[poiId] or self.userData[poiId]) then
                local poiNX, poiNZ, pinType, texture = GetPOIMapInfo(zoneIndex, i)
                local poiX, poiZ = Lib3D:LocalToWorld(poiNX, poiNZ)

                self.userData[poiId] = {{poiX * 100, 14000, poiZ * 100}}
            end

            local nextIndex = #self.activeMarkers+1
            local newMarker = self:Place(poiId)
            self.activeMarkers[nextIndex] = newMarker
            self.markerIndexToPOIIdTable[nextIndex] = poiId
        else
            Log('POI zoneId %d index %d returned %s', zoneId, i, type(poiId))
        end
    end
end

function addon:OnLoad()
    ImperialCartographerData = ImperialCartographerData or {}
    addon.data = ImperialCartographer.DefaultData
    addon.userData = ImperialCartographerData

	discoverPOI()

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function(_, initial) self:OnPlayerActivated(initial) end)

    SLASH_COMMANDS['/impcartupdclosest'] = function()
        local closestMarkerIndex = self:GetClosestMarkerIndex()
        if not closestMarkerIndex then return end

        local closestMarker = self.activeMarkers[closestMarkerIndex]

        local distance = getXZDistanceTo(closestMarker.position)
        if distance >= 1500 then
            Log('Too far %.2f', distance)
            return
        end

        local pX, pY, pZ = select(2, GetUnitWorldPosition('player'))

        local closestPOIId = self.markerIndexToPOIIdTable[closestMarkerIndex]
        self.userData[closestPOIId][1][2] = pY
        self.userData[closestPOIId][2] = true

        closestMarker:Delete()
        self.activeMarkers[closestMarkerIndex] = self:Place(closestPOIId)
    end

    ImperialCartographer.RegisterReticlerOverEvents()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon:OnLoad()
end)

-- ImperialCartographerMain = addon