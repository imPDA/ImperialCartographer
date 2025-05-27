local SCROLL_LIST_CONTROL

local IC = ImperialCartographer

local CURRENT_ZONE_NAME_COLOR = {0, 1, 0}
local DEFAULT_ZONE_NAME_COLOR = {1, 1, 1}

local function CreateScrollListDataType(listControl)
    local function LayoutRow(rowControl, data, scrollList)
        local zoneIndex = data.zoneIndex
        local poiDiscovered = data.poiDiscovered
        local poiTotal = data.poiTotal
        local poiTotalV2 = GetNumPOIs(zoneIndex)

        local characterZoneIndex = GetUnitZoneIndex('player')
        local currentZone = characterZoneIndex == zoneIndex
        local color = currentZone and CURRENT_ZONE_NAME_COLOR or DEFAULT_ZONE_NAME_COLOR

        GetControl(rowControl, 'Index'):SetText(zoneIndex)
        GetControl(rowControl, 'Index'):SetColor(unpack(color))
        GetControl(rowControl, 'Name'):SetText(GetZoneNameByIndex(zoneIndex))
        GetControl(rowControl, 'Name'):SetColor(unpack(color))
        GetControl(rowControl, 'Discovered'):SetText(('%d / %d (%d)'):format(poiDiscovered, poiTotal, poiTotalV2))

        if poiDiscovered == poiTotal and poiTotal ~= 0 then
            GetControl(rowControl, 'Discovered'):SetColor(0, 1, 0)
        elseif poiDiscovered >= poiTotal * 0.8 and poiTotal ~= 0 then
            GetControl(rowControl, 'Discovered'):SetColor(1, 65/255, 0)
        else
            GetControl(rowControl, 'Discovered'):SetColor(1, 0, 0)
        end

        local missingPOIs = {}
        for i = 1, GetNumPOIs(zoneIndex) do
            local poiId = IC.GetPOIId(zoneIndex, i)

            if poiId then
                local visited = (IC.data[poiId] and true) or (IC.userData[poiId] and IC.userData[poiId][2] or false)
                if not visited then
                    local objectiveName, objectiveLevel, startDescription, finishedDescription = GetPOIInfo(zoneIndex, i)
                    missingPOIs[#missingPOIs+1] = ('[%d] %s'):format(i, objectiveName)
                end
            end
        end

        if #missingPOIs > 0 then
            local tooltip = table.concat(missingPOIs, '\n')
            rowControl:SetHandler('OnMouseEnter', function()
                ZO_Tooltips_ShowTextTooltip(rowControl, RIGHT, tooltip)
            end)
            rowControl:SetHandler('OnMouseExit', function() ZO_Tooltips_HideTextTooltip() end)
        else
            rowControl:SetHandler('OnMouseEnter', nil)
            rowControl:SetHandler('OnMouseExit', nil)
        end
    end

	local control = listControl
	local typeId = 1
	local templateName = 'IMP_CART_DiscoveredPOIRowTemplate'
	local height = 32
	local setupFunction = LayoutRow
	local hideCallback = nil
	local dataTypeSelectSound = nil
	local resetControlCallback = nil

	ZO_ScrollList_AddDataType(control, typeId, templateName, height, setupFunction, hideCallback, dataTypeSelectSound, resetControlCallback)

    -- local selectTemplate = 'ZO_ThinListHighlight'
	-- local selectCallback = nil
	-- ZO_ScrollList_EnableSelection(control, selectTemplate, selectCallback)

    SCROLL_LIST_CONTROL = listControl
end

local SUMMARY_TABLE = {}
local function updateSummary()
    -- ZO_ClearTable(SUMMARY_TABLE)

    for i = 1, GetNumZones() do
        if not SUMMARY_TABLE[i] then SUMMARY_TABLE[i] = {} end
        SUMMARY_TABLE[i][1] = 0
        SUMMARY_TABLE[i][2] = 0
    end

    for poiId, poiData in pairs(ImperialCartographer.DefaultData) do
        local zoneIndex, poiIndex = GetPOIIndices(poiId)
        -- if not SUMMARY_TABLE[zoneIndex] then SUMMARY_TABLE[zoneIndex] = {0, 0} end
        SUMMARY_TABLE[zoneIndex][1] = SUMMARY_TABLE[zoneIndex][1] + (poiData[2] == true and 1 or 0)
        SUMMARY_TABLE[zoneIndex][2] = SUMMARY_TABLE[zoneIndex][2] + 1
    end

    for poiId, poiData in pairs(ImperialCartographerData) do
        if not ImperialCartographer.DefaultData[poiId] then
            local zoneIndex, poiIndex = GetPOIIndices(poiId)
            -- if not SUMMARY_TABLE[zoneIndex] then SUMMARY_TABLE[zoneIndex] = {0, 0} end
            SUMMARY_TABLE[zoneIndex][1] = SUMMARY_TABLE[zoneIndex][1] + (poiData[2] == true and 1 or 0)
            SUMMARY_TABLE[zoneIndex][2] = SUMMARY_TABLE[zoneIndex][2] + 1
        end
    end

    local totalDiscovered = 0
    local grandTotal = 0
    for zoneIndex, zoneStats in pairs(SUMMARY_TABLE) do
        totalDiscovered = totalDiscovered + zoneStats[1]
        grandTotal = grandTotal + zoneStats[2]
    end

    IMP_CART_DiscoveredPOIsHeaderTotalDiscoveredLabel:SetText(('(total: %d/%d)'):format(totalDiscovered, grandTotal))
end

-- ----------------------------------------------------------------------------

function IMP_CART_UpdateScrollListControl()
    local scrollList = SCROLL_LIST_CONTROL
	local dataList = ZO_ScrollList_GetDataList(scrollList)

    updateSummary()

    local function CreateAndAddDataEntry(zoneIndex, poiData)
        local value = {zoneIndex = zoneIndex, poiDiscovered = poiData[1], poiTotal = poiData[2]}
        local entry = ZO_ScrollList_CreateDataEntry(1, value)

		table.insert(dataList, entry)
    end

    ZO_ScrollList_Clear(scrollList)

    for zoneIndex, poiData in pairs(SUMMARY_TABLE) do
        if GetNumPOIs(zoneIndex) > 0 then
            CreateAndAddDataEntry(zoneIndex, poiData)
        end
    end

    table.sort(dataList, function(a, b) return a.data.zoneIndex < b.data.zoneIndex end)

    ZO_ScrollList_Commit(scrollList)
end

function IMP_CART_DiscoveredPOIs_OnInitialised(control)
    CreateScrollListDataType(control:GetNamedChild('ScrollableList'))
end
