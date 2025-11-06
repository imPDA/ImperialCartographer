local MARK_TYPE_SKYSHARDS = nil
local EVENT_NAMESPACE = 'IMP_CART_SKYSHARDS'

local function keepOnPlayersHeight(marker, distance, prwX, prwY, prwZ)
    marker[2] = prwY + 200
end

local SKYSHARD_MARK_INDICIES = {}

local function addMarksForSkyshards()
    local zoneId, prwX, prwY, prwZ = GetUnitRawWorldPosition('player')
    local convX, convZ = ImperialCartographer.Calculations.GetNWToRNWConversionFunctions(zoneId, prwX, prwY, prwZ)

    local calibration = {ImperialCartographer.Coordinates.GetCalibration(zoneId)}
    local rwY = 0

    local texture = '/esoui/art/miscellaneous/gamepad/gp_bullet.dds'
    local size = 48
    local color = {0, 40 / 255, 40 / 255}

    local numSkyshardsInZone = GetNumSkyshardsInZone(zoneId)
    for skyshardIndex = 1, numSkyshardsInZone do
        local skyshardId = GetZoneSkyshardId(zoneId, skyshardIndex)
        local nwX, nwZ, isShownInCurrentMap = GetNormalizedPositionForSkyshardId(skyshardId)

        local rnwX, rnwZ = convX(nwX), convZ(nwZ)
        local rwX, rwZ = ImperialCartographer.Coordinates.ConvertNormalizedToWorld(rnwX, rnwZ, calibration)

        local mark, markIndex = ImperialCartographer.MarksManager:AddMark(MARK_TYPE_SKYSHARDS, {}, {rwX, rwY, rwZ}, texture, size, color)

        SKYSHARD_MARK_INDICIES[#SKYSHARD_MARK_INDICIES+1] = markIndex
    end
end

local INITIALIZED = false
EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
    -- if not ImperialCartographer.sv.questTracker.enabled then return end
    if not INITIALIZED then
        MARK_TYPE_SKYSHARDS = ImperialCartographer.MarksManager:AddMarkType(function() end, true, keepOnPlayersHeight)
        INITIALIZED = true
    end

    addMarksForSkyshards()
end)
