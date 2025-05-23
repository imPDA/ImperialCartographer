local function exportPOI()
    ImperialCartographerData = ImperialCartographerData or {}
    ImperialCartographerExport = {}

    local data = ImperialCartographer.DefaultData
    local userData = ImperialCartographerData

    local export = ImperialCartographerExport

    ZO_DeepTableCopy(data, export)

    for poiId, poiData in pairs(userData) do
        if not export[poiId] and poiData[2] then
            export[poiId] = poiData
        end
    end

    if Zgoo then
        GLOBAL_IMP_CART_EXPORT = export
        Zgoo.CommandHandler('{GLOBAL_IMP_CART_EXPORT}')
    end
end

SLASH_COMMANDS['/impcartgenexport'] = exportPOI
