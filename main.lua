local Log = ImperialCartographer_Logger()

local EVENT_NAMESPACE = 'IMPERIAL_CARTOGRAPHER_MAIN_EVENT_NAMESPACE'

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'ImperialCartographer'
addon.displayName = 'Imperial Cartographer'

local DEFAULT_SETTINGS = {
    pinned = false,
}

-- ----------------------------------------------------------------------------

function addon:OnLoad()
    Log('Loading %s', self.displayName)

    ImperialCartographerData = ImperialCartographerData or {}

    self.sv = ZO_SavedVars:NewAccountWide('ImperialCartographerSV', 1, nil, DEFAULT_SETTINGS)

    -- addon.userData = ImperialCartographerData
    self.Settings:Initialize(addon.name .. 'SettingsControl', addon.displayName)

    self.MarksManager:Initialize()
    self.DefaultPOIs:Initialize()
    self.UndiscoveredPOIs:Initialize()

    SLASH_COMMANDS['/impcartgetclose'] = ImperialCartographer.UndiscoveredPOIs.GetCloseMark
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon:OnLoad()
end)

ImperialCartographer = addon