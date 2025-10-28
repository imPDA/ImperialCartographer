assert(ImperialCartographer, 'ImperialCartographer not loaded')

local settings = {}
local LAM = LibAddonMenu2

function settings:Initialize(settingsName, settingsDisplayName, sv)
    local panelData = {
        type = 'panel',
        name = settingsDisplayName,
        author = '@impda',
        website = 'https://www.esoui.com/downloads/info4112-ImperialCartographer.html',
        version = 'v12',
    }

    local panel = LAM:RegisterAddonPanel(settingsName, panelData)

    local optionsData = {}
    optionsData[#optionsData+1] = {
        type = 'description',
        title = 'About',
        text =
[[
ImperialCartographer is an addon that shows Points of Interest (POIs) as markers within the 3D game world of The Elder Scrolls Online, providing a more immersive alternative to the standard compass or map.

It requires a manually built database because the game's API does not provide location data. Each POI must be visited and its coordinates recorded for the marker to appear.

If you see a POI in red, it means its coordinates have not been added yet. The project relies on community contributions to map the world.
]],
        -- reference = 'MyAddonDescription'
    }

    local defaultPOIsControls = {}

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = 'slider',
		name = 'Marker size',
		getFunc = function() return sv.defaultPois.markerSize end,
		setFunc = function(value)
            if value ~= sv.defaultPois.markerSize then
                sv.defaultPois.markerSize = value
                ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
            end
        end,
		min = 24,
		max = 144,
	}

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = 'slider',
		name = 'Distance meter font size',
		getFunc = function() return sv.defaultPois.fontSize end,
		setFunc = function(value)
            if value ~= sv.defaultPois.fontSize then
                sv.defaultPois.fontSize = value
                ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
            end
        end,
		min = 16,
		max = 36,
	}

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = 'slider',
		name = 'POI name font size',
		getFunc = function() return sv.defaultPois.labelFontSize end,
		setFunc = function(value)
            if value ~= sv.defaultPois.labelFontSize then
                sv.defaultPois.labelFontSize = value
                ImperialCartographer.DefaultPOIs:InitPOILabel()
            end
        end,
		min = 16,
		max = 36,
	}

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = 'slider',
		name = 'Transparency on distance',
		getFunc = function() return sv.defaultPois.maxAlpha end,
		setFunc = function(value)
            if value ~= sv.defaultPois.maxAlpha then
                sv.defaultPois.maxAlpha = value
                ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
            end
        end,
		min = 0.05,
		max = 1,
        step = 0.01,
        decimals = 2,
        clampInput = true,
        requiresReload = true,
	}

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = 'slider',
		name = 'Transparency when close',
		getFunc = function() return sv.defaultPois.minAlpha end,
		setFunc = function(value)
            if value ~= sv.defaultPois.minAlpha then
                sv.defaultPois.minAlpha = value
                ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
            end
        end,
		min = 0.05,
		max = 1,
        step = 0.01,
        decimals = 2,
        clampInput = true,
        requiresReload = true,
	}

    defaultPOIsControls[#defaultPOIsControls+1] = {
		type = 'slider',
		name = 'Max distance',
		getFunc = function() return sv.defaultPois.maxDistance / 100 end,
		setFunc = function(value)
            value = value * 100
            if value ~= sv.defaultPois.maxDistance then
                sv.defaultPois.maxDistance = value
                ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
            end
        end,
		min = 10,
		max = 700,
        -- step = 1,
        -- decimals = 2,
        clampInput = true,
        requiresReload = true,
	}

    defaultPOIsControls[#defaultPOIsControls+1] = {
        type = 'colorpicker',
        name = 'Marker color',
        getFunc = function() return unpack(sv.defaultPois.markerColor) end,
        setFunc = function(r, g, b, a)
            sv.defaultPois.markerColor = {r, g, b}
            ImperialCartographer.DefaultPOIs:TriggerFullUpdate()
        end,
        -- width = 'half',
        -- warning = 'warning text',
    }

    optionsData[#optionsData+1] = {
        type = 'submenu',
		name = 'Default points of interest (POIs)',
		-- tooltip = 'My Submenu Tooltip',
		controls = defaultPOIsControls,
		-- reference = 'MyAddonSubmenu'
    }

    local undiscoveredPOIsControls = {}

    undiscoveredPOIsControls[#undiscoveredPOIsControls+1] = {
        type = 'checkbox',
        name = 'Enabled',
        getFunc = function() return sv.undiscoveredPOIs.enabled end,
        setFunc = function(value)
            sv.undiscoveredPOIs.enabled = value
        end,
        requiresReload = true,
    }

    optionsData[#optionsData+1] = {
        type = 'submenu',
		name = 'Undiscovered points of interest (POIs)',
		tooltip = 'Points which were not added to addon yet',
		controls = undiscoveredPOIsControls,
		-- reference = 'MyAddonSubmenu'
    }

    local questTrackerControls = {}

    questTrackerControls[#questTrackerControls+1] = {
        type = 'checkbox',
        name = 'Enabled',
        getFunc = function() return sv.questTracker.enabled end,
        setFunc = function(value)
            sv.questTracker.enabled = value
        end,
        requiresReload = true,
    }

    optionsData[#optionsData+1] = {
        type = 'submenu',
		name = 'Current tracked quest marker',
		-- tooltip = 'My Submenu Tooltip',
		controls = questTrackerControls,
		-- reference = 'MyAddonSubmenu'
    }

    LAM:RegisterOptionControls(settingsName, optionsData)

    CALLBACK_MANAGER:RegisterCallback('LAM-PanelOpened', function(panelOpened)
        if panelOpened ~= panel then return end
        IMP_CART_DiscoveredPOIs:SetHidden(false)
    end)

    CALLBACK_MANAGER:RegisterCallback('LAM-PanelClosed', function(panelOpened)
        if panelOpened ~= panel then return end

        if not ImperialCartographer.sv.pinned then
            IMP_CART_DiscoveredPOIs:SetHidden(true)
        end
    end)
end

ImperialCartographer.Settings = settings
