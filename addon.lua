local myname, ns = ...

ns.CVAR = 'showDelveEntrancesOnMap'
ns.allowTooltipWidgets = false

local parentDelvesCache = {}
-- Only care about bountiful delves ticking over, so just refresh this every 10 minutes
C_Timer.NewTimer(600, function() wipe(parentDelvesCache) end)

function ns.GetPointsFromMapInfo(mapInfo, parentMapID)
	if not parentDelvesCache[parentMapID] then
		parentDelvesCache[parentMapID] = {}
		for _, delveID in ipairs(C_AreaPoiInfo.GetDelvesForMap(parentMapID)) do
			local info = C_AreaPoiInfo.GetAreaPOIInfo(parentMapID, delveID)
			if info then
				parentDelvesCache[parentMapID][info.name] = delveID
			end
		end
	end
	local parentDelves = parentDelvesCache[parentMapID] or {}

	local delves = {}
	for _, delveID in ipairs(C_AreaPoiInfo.GetDelvesForMap(mapInfo.mapID)) do
		local info = C_AreaPoiInfo.GetAreaPOIInfo(mapInfo.mapID, delveID)
		if info and (info.atlasName == "delves-bountiful" or not ns.db.only_bountiful) and not parentDelves[info.name] then
			delves[delveID] = info
		end
	end
	return delves
end

function ns.OnPinAcquired(pin, info)
	pin:SetSize(28, 28)
end

local extractVariantFromWidgetSet = function(widgetSetID)
    -- This is basically ripped from the chain of calls that GameTooltip_AddWidgetSet does
    local widgets = widgetSetID and C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
    if not widgets then return end
    local variant, fullVariant, description, isBountiful
    for _, widget in ipairs(widgets) do
        -- this is the only type I've ever seen for delve entrances, but just in case...
        if widget.widgetType == Enum.UIWidgetVisualizationType.TextWithState then
            local info = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widget.widgetID)
            -- orderIndex is the only way to work out which is which; 0 is
            -- the variant, 1 is the description with your coffer keys
            -- and the timer. Annoyingly, this timer isn't mirrored into
            -- GetAreaPOISecondsLeft...
            -- That said, presence of the second widget is currently a
            -- semi-useful proxy for whether the delve is bountiful
            if info and info.orderIndex == 0 then
                -- text="Story Variant: |cnWHITE_FONT_COLOR:Waygate Wiles",
                fullVariant = info.text
                -- TODO: work out whether there's *actually* any
                -- localization where looking for the |r terminated
                -- version is necessary
                variant = string.match(fullVariant, "|cnWHITE_FONT_COLOR:(.+)|r") or string.match(fullVariant, "|cnWHITE_FONT_COLOR:(.+)$") or fullVariant
            elseif info and info.orderIndex == 1 then
                description = info.text
                isBountiful = true
            end
        end
    end
    return variant, isBountiful, fullVariant, description
end
function ns.AddToTooltip(tooltip, pin)
	-- GameTooltip_AddWidgetSet runs into secret issues, so we're going to extract some useful information...
    local variant, isBountiful, fullVariant, description = extractVariantFromWidgetSet(pin.tooltipWidgetSet)
    if variant then
        -- TODO: Could check completion against the relevant achievement's criteria, I guess?
        tooltip:AddLine(fullVariant)
    end
    if description then
        GameTooltip_AddColoredLine(tooltip, description, NORMAL_FONT_COLOR, true)
    end
end

function ns.AddToTrackingMenu(owner, rootDescription, contextData, isChecked, setChecked)
	-- "%s Only"
	local title = RACE_CLASS_ONLY:format(C_QuestLog.GetTitleForQuestID(81514) or "Bountiful Delves")
	rootDescription:CreateDivider()
	local check = rootDescription:CreateCheckbox(title, isChecked, setChecked, "only_bountiful")
	check:SetTooltip(function(tooltip, elementDescription)
		-- this display style is from BlizzardWorldMapTemplates.lua,
		-- altered to account for SetTooltip not giving us access to the
		-- same things that SetOnEnter does.
		local owner = tooltip:GetOwner()
		tooltip:ClearAllPoints()
		tooltip:SetPoint("RIGHT", owner, "LEFT", -3, 0)
		tooltip:SetOwner(owner, "ANCHOR_PRESERVE")

		GameTooltip_SetTitle(tooltip, title)
		GameTooltip_AddNormalLine(tooltip, DELVES_GREAT_VAULT_DESCRIPTION_SEASON_STARTED)
		tooltip:AddDoubleLine(" ", myname, 1, 1, 1, 0, 1, 1)
	end)
end
