local Log = ImperialCartographer_Logger()

local EVENT_NAMESPACE = 'IMPERIAL_CARTOGRAPHER_MAIN_EVENT_NAMESPACE'

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'ImperialCartographer'
addon.displayName = 'Imperial Cartographer'

local DEFAULT_SETTINGS = {
    pinned = false,
    defaultPois = {
        markerSize = 36,
        markerColor = {1, 1, 1},
        fontSize = 20,
        minDistance = 500,
        maxDistance = 23500,
        minAlpha = 1,
        maxAlpha = 0.2,
        labelFontSize = 24,
    }
}

-- ----------------------------------------------------------------------------

function addon:OnLoad()
    Log('Loading %s', self.displayName)

    ImperialCartographerData = ImperialCartographerData or {}

    self.sv = ZO_SavedVars:NewAccountWide('ImperialCartographerSV', 1, nil, DEFAULT_SETTINGS)

    -- addon.userData = ImperialCartographerData
    self.Settings:Initialize(addon.name .. 'SettingsControl', addon.displayName, self.sv)

    self.MarksManager:Initialize()
    self.DefaultPOIs:Initialize(addon)
    self.UndiscoveredPOIs:Initialize()

    SLASH_COMMANDS['/impcartgetclose'] = ImperialCartographer.UndiscoveredPOIs.GetCloseMark
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon:OnLoad()
end)

ImperialCartographer = addon