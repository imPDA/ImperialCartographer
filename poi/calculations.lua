local Log = ImperialCartographer_Logger()

local ACCURACY_SQ = 0.25 * 0.25
local MAX_ITERATIONS = 100
local function normalizedToWorld(zoneIndex, nX, nZ)
    local zoneId = GetZoneId(zoneIndex)
    Log('Interpolation of %.6f %.6f in zoneIndex %d (zoneId %d)', nX, nZ, zoneIndex, zoneId)

    -- local wX_predicted, wY_predicted, wZ_predicted = 0, 0, 0
    local _, wX_predicted, wY_predicted, wZ_predicted = GetUnitWorldPosition('player')

    local K = 2

    local differenceSq = math.huge
    local iterations = 0

    while differenceSq >= ACCURACY_SQ do
        if iterations > MAX_ITERATIONS then
            Log('Iteration limit reached')
            error('Iterations limit reached')
        end

        local nX_calculated, nZ_calculated = GetNormalizedWorldPosition(zoneId, wX_predicted, wY_predicted, wZ_predicted)

        local dnX, dnZ = nX - nX_calculated, nZ - nZ_calculated
        local dwX, dwZ = wX_predicted / nX_calculated * dnX, wZ_predicted / nZ_calculated * dnZ

        wX_predicted = wX_predicted + dwX / K
        wZ_predicted = wZ_predicted + dwZ / K

        -- Log('%d, %d', wX_predicted, wZ_predicted)
        -- Log('%.8f %.8f - %.8f %.8f = %.8f %.8f', nX, nZ, nX_calculated, nZ_calculated, nX - nX_calculated, nZ - nZ_calculated)
        -- Log('%.2f %.2f', dwX / 2, dwZ / 2)

        local newDifferenceSq = dwX * dwX / K / K + dwZ * dwZ / K / K
        if newDifferenceSq > differenceSq then
            K = K * 2
        end

        differenceSq = newDifferenceSq

        iterations = iterations + 1
    end

    Log('Interpolated coordinates: %.2f, %.2f', wX_predicted, wZ_predicted, nX, nZ)

    return wX_predicted, wY_predicted, wZ_predicted
end

-- ----------------------------------------------------------------------------

ImperialCartographer = ImperialCartographer or {}
ImperialCartographer.Calculations = {
    NormalizedToWorld = normalizedToWorld,
}
