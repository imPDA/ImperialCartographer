local Log = ImperialCartographer_Logger()

local IC = ImperialCartographer

-- ----------------------------------------------------------------------------

local function clearPoints()
    local zoneIndex = GetUnitZoneIndex('player')
    if not zoneIndex then Log('`zoneIndex` was not received for player') return end

    for i = 1, GetNumPOIs(zoneIndex) do
        local poiId = IC.GetPOIId(zoneIndex, i)

        if poiId then
            IC.userData[poiId] = nil
        end
    end
end

SLASH_COMMANDS['/impcartclrpoints'] = clearPoints