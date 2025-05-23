local Log = ImperialCartographer_Logger()

local IC = ImperialCartographer

-- ----------------------------------------------------------------------------

local function getXZDistanceTo(position)
    local pX, pY, pZ = select(2, GetUnitRawWorldPosition('player'))
    local mX, mY, mZ = unpack(position)

    local dX = mX - pX
    local dZ = mZ - pZ

    return math.sqrt(dX * dX + dZ * dZ)
end

local function updatePoint()
    local closestMarkerIndex = IC:GetClosestMarkerIndex()
    if not closestMarkerIndex then return end

    local closestMarker = IC.activeMarkers[closestMarkerIndex]

    local distance = getXZDistanceTo(closestMarker.position)
    if distance >= 5500 then
        Log('Too far %.2f', distance)
        return
    end

    -- doesn't matter if it is Raw or not since I need Y only
    local prwX, prwY, prwZ = select(2, GetUnitRawWorldPosition('player'))

    local closestPOIId = IC.markerIndexToPOIIdTable[closestMarkerIndex]

    IC.userData[closestPOIId][1][2] = prwY
    IC.userData[closestPOIId][2] = true

    closestMarker:Delete()
    IC.activeMarkers[closestMarkerIndex] = IC:Place(closestPOIId)

    Log('Point %d updated: x:%d, y:%d, z:%d', closestPOIId, unpack(IC.userData[closestPOIId][1]))

    IMP_CART_UpdateScrollListControl()
end

-- ----------------------------------------------------------------------------

SLASH_COMMANDS['/impcartupdclosest'] = updatePoint
IMP_CART_UpdatePoint = updatePoint