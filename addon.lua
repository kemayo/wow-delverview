local myname, ns = ...

ns.CVAR = 'showDelveEntrancesOnMap'

-- ns.allowTooltipWidgets = false
-- function ns.AddToTooltip(tooltip, pin)
-- 	print('AddToTooltip', tooltip, pin)
-- end

function ns.GetPointsFromMapInfo(mapInfo, parentMapID)
	local parentDelves = {}
	for _, delveID in ipairs(C_AreaPoiInfo.GetDelvesForMap(parentMapID)) do
		local info = C_AreaPoiInfo.GetAreaPOIInfo(mapInfo.mapID, delveID)
		if info then
			parentDelves[info.name] = delveID
		end
	end

	local delves = {}
	for _, delveID in ipairs(C_AreaPoiInfo.GetDelvesForMap(mapInfo.mapID)) do
		local info = C_AreaPoiInfo.GetAreaPOIInfo(mapInfo.mapID, delveID)
		if info and (info.atlasName == "delves-bountiful" or not ns.db.only_bountiful) and not parentDelves[info.name] then
			delves[delveID] = info
		end
	end
	return delves
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
