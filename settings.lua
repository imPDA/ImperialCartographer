assert(ImperialCartographer, 'ImperialCartographer not loaded')

local settings = {}
local LAM = LibAddonMenu2

function settings:Initialize(settingsName, settingsDisplayName, sv)
    local panelData = {
        type = 'panel',
        name = settingsDisplayName,
        author = '@impda',
        website = 'https://www.esoui.com/downloads/info4112-ImperialCartographer.html',
        version = 'v8',
    }

    local panel = LAM:RegisterAddonPanel(settingsName, panelData)

    local optionsData = {}
    optionsData[#optionsData+1] = {
        type = "description",
        title = "About",
        text =
[[
ImperialCartographer is an addon that shows Points of Interest (POIs) as markers within the 3D game world of The Elder Scrolls Online, providing a more immersive alternative to the standard compass or map.

It requires a manually built database because the game's API does not provide location data. Each POI must be visited and its coordinates recorded for the marker to appear.

If you see a POI in red, it means its coordinates have not been added yet. The project relies on community contributions to map the world.
]],
        -- reference = "MyAddonDescription"
    }

    local defaultPOIsControls = {}
    optionsData[#optionsData+1] = {
        type = "submenu",
		name = "Default points of interest (POIs)",
		-- tooltip = "My Submenu Tooltip",
		controls = defaultPOIsControls,
		-- reference = "MyAddonSubmenu"
    }

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = "slider",
		name = "POI size",
		getFunc = function() return sv.defaultPois.markerSize end,
		setFunc = function(value)
            if value ~= sv.defaultPois.markerSize then
                sv.defaultPois.markerSize = value
                ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
            end
        end,
		min = 24,
		max = 72,
		-- reference = "MyAddonSlider"
	}

    LAM:RegisterOptionControls(settingsName, optionsData)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panelOpened)
        if panelOpened ~= panel then return end
        IMP_CART_DiscoveredPOIs:SetHidden(false)
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panelOpened)
        if panelOpened ~= panel then return end

        if not ImperialCartographer.sv.pinned then
            IMP_CART_DiscoveredPOIs:SetHidden(true)
        end
    end)
end

ImperialCartographer.Settings = settings
