local Log = ImperialCartographer_Logger()

local EVENT_NAMESPACE = 'IMPERIAL_CARTOGRAPHER_MAIN_EVENT_NAMESPACE'

-- ----------------------------------------------------------------------------

local addon = {}

addon.name = 'ImperialCartographer'
addon.displayName = 'Imperial Cartographer'

-- ----------------------------------------------------------------------------

function addon:OnLoad()
    Log('Loading %s', self.displayName)

    ImperialCartographerData = ImperialCartographerData or {}

    -- addon.userData = ImperialCartographerData

    self.MarksManager:Initialize()
    self.DefaultPOIs:Initialize()
    self.UndiscoveredPOIs:Initialize()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= addon.name then return end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon:OnLoad()
end)

ImperialCartographer = addon