local Vector = LibImplex.Vector
local _350_CM = Vector({0, 350, 0})

-- ----------------------------------------------------------------------------

--[[
local MarkerPOI = LibImplex.Marker.subclass()

function MarkerPOI:__init(position, texture, size, color, minDistance, maxDistance, minAlpha, maxAlpha, ...)
    assert(minDistance ~= maxDistance, 'Min and max distance must be different!')

    local distanceSection = maxDistance - minDistance
    local alphaSection = maxAlpha - minAlpha

    -- local x, y, z = position[1], position[2], position[3]
    -- local b1, b2, b3, b4 = x + maxDistance * 100, x - maxDistance * 100, z + maxDistance * 100, z - maxDistance * 100

    local maxDistanceSq = maxDistance * maxDistance * 10000
    local minDistanceSq = minDistance * minDistance * 10000

    local updateFunctions = {...}

    local function update(marker)
        local x, y, z = position[1], position[2], position[3]
        local markerControl = marker.control

        -- for the future
        -- if pX > b1 or pX < b2 or pZ > b3 or pZ < b4 then
        --     markerControl:SetHidden(true)
        --     return
        -- end

        -- --------------------------------------------------------------------

        local diffX = pX - x
        local diffY = pY - y
        local diffZ = pZ - z

        local distanceSq = diffX * diffX + diffY * diffY + diffZ * diffZ

        if distanceSq > maxDistanceSq or distanceSq < minDistanceSq then
            markerControl:SetHidden(true)
            return
        end

        local distance = sqrt(distanceSq) * 0.01

        local dX, dY, dZ = x - cX, y - cY, z - cZ
        local Z = fX * dX + fY * dY + fZ * dZ

        if Z < 0 then
            markerControl:SetHidden(true)
            return
        end

        markerControl:SetHidden(false)

        local percent = (distance - minDistance) / distanceSection
        markerControl:SetAlpha(minAlpha + percent * alphaSection)

        if distance > 1000 then
            marker.distanceLabel:SetText(string.format('%.1fkm', distance * 0.001))
        else
            marker.distanceLabel:SetText(string.format('%dm', distance))
        end

        -- --------------------------------------------------------------------

        local X = rX * dX + rZ * dZ
        local Y = uX * dX + uY * dY + uZ * dZ

        local w, h = GetWorldDimensionsOfViewFrustumAtDepth(Z)
        local scaleW = UI_WIDTH / w
        local scaleH = UI_HEIGHT / h

        -- another interesting way to do the same, a bit faster, but with limitations
        -- local scale = UI_HEIGHT_K / Z

        markerControl:SetAnchor(CENTER, GuiRoot, CENTER, X * scaleW, Y * scaleH)

        markerControl:SetDrawLevel(-Z)
        marker.distanceLabel:SetDrawLevel(-Z)

        if #updateFunctions > 0 then
            for i = 1, #updateFunctions do
                updateFunctions[i](marker, distance, pX, pY, pZ, fX, fY, fZ, rX, rY, rZ, uX, uY, uZ)
            end
        end
    end

    self.base.__init(self, position, nil, texture, size, color, update)

    local control = self.control

    if size then control:SetDimensions(unpack(size)) end
end
--]]

-- ----------------------------------------------------------------------------

local function visibleAt(minDistance, maxDistance)
    local function inner(marker, distance)
        if distance > maxDistance or distance < minDistance then
            marker.control:SetHidden(true)
            return true
        end
    end

    return inner
end

local function changeAlphaWithDistance(minDistance, maxDistance, minAlpha, maxAlpha)
    local distanceSection = maxDistance - minDistance
    local alphaSection = maxAlpha - minAlpha

    local function inner(marker, distance)
        if distance >= maxDistance then
            marker.control:SetAlpha(maxAlpha)
            return
        end

        if distance <= minDistance then
            marker.control:SetAlpha(minAlpha)
            return
        end

        local percent = (distance - minDistance) / distanceSection
        marker.control:SetAlpha(minAlpha + percent * alphaSection)
    end

    return inner
end

local function addDistanceLabel(marker)
    local existedLabel = marker.control:GetNamedChild('DistanceLabel')
    if existedLabel then
        marker.distanceLabel = existedLabel
        existedLabel:SetHidden(false)
    else
        marker.distanceLabel = CreateControlFromVirtual('$(parent)DistanceLabel', marker.control, 'ImperialCartographer_DistanceLabelTemplate')
    end
end

local function updateDistanceLabel(marker, distance)
    if distance > 100000 then
        marker.distanceLabel:SetText(string.format('%.1fkm', distance * 0.00001))
    else
        marker.distanceLabel:SetText(string.format('%dm', distance * 0.01))
    end
end

local function updateY(marker, distance, pX, pY, pZ)
    marker.position[2] = pY + 150
end

-- ----------------------------------------------------------------------------

local updateVisibilityPOIMarker = visibleAt(500, 23500)
local updateAlphaPOIMarker = changeAlphaWithDistance(500, 23500, 1, 0.2)
local function POIMarker(position, texture, size, color, hideAfter_M)
    local poiMarker = LibImplex.Marker.Marker2D(
        position,
        nil,
        texture,
        {size, size},
        color,
        updateVisibilityPOIMarker,
        updateDistanceLabel,
        updateAlphaPOIMarker
    )

    addDistanceLabel(poiMarker)

    return poiMarker
end

local updateVisibilityUnknownPOIMarker = visibleAt(0, 300000)
local updateAlphaUnknownPOIMarker = changeAlphaWithDistance(0, 100000, 1, 0.1)
local function UnknownPOIMarker(position, texture, size, color, hideAfter_M)
    local poiMarker = LibImplex.Marker.Marker2D(
        position,
        nil,
        texture,
        {size, size},
        color,
        updateVisibilityUnknownPOIMarker,
        updateDistanceLabel,
        updateAlphaUnknownPOIMarker,
        updateY
    )

    addDistanceLabel(poiMarker)

    return poiMarker
end

ImperialCartographer = ImperialCartographer or {}
ImperialCartographer.POIMarker = POIMarker
ImperialCartographer.UnknownPOIMarker = UnknownPOIMarker
