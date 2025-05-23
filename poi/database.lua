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

local db = AutoTable()

local function fillPOIDatabase()
    for i = 1, 3000 do  -- ~2800 in U45
        local zoneIndex, poiIndex = GetPOIIndices(i)

        if zoneIndex ~= 1 then
            -- local zoneId = GetZoneId(zoneIndex)
            -- db[zoneId][poiIndex] = i
            db[zoneIndex][poiIndex] = i
        end
    end
end

local function getPOIId(zoneIndex, poiIndex)
    local poiId = db[zoneIndex][poiIndex]

    if type(poiId) == 'table' then return nil end

    return poiId
end

-- ----------------------------------------------------------------------------

do
    fillPOIDatabase()
end

ImperialCartographer.GetPOIId = getPOIId
