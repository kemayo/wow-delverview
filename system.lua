local myname, ns = ...

ns.DEBUG = C_AddOns.GetAddOnMetadata(myname, "Version") == '@'..'project-version@'

local HBDP = LibStub("HereBeDragons-Pins-2.0")

ns.validMapTypes = {
	[Enum.UIMapType.Continent] = true,
}
ns.validChildMapTypes = {
	[Enum.UIMapType.Zone] = true,
}
ns.extraChildren = {
	-- Note: this is only needed for zones where a child-of-child is relevant,
	-- and the child-of-child will have data from GetMapRectOnMap
	[2274] = { -- Khaz Algar
		2339, -- Dornogal (technically a child of Isle of Dorn)
		2346, -- Undermine (technically a child of Ringing Deeps)
	},
}
ns.allowTooltipWidgets = true

local db
EventUtil.ContinueOnAddOnLoaded(myname, function()
	local dbname = myname.."DB"
	_G[dbname] = _G[dbname] or {}
	db = _G[dbname]
	ns.db = db
end)

local PinMixin = {}
ns.PinMixin = PinMixin
function PinMixin:OnLoad()
	self:SetSize(20, 20)
	if not InCombatLockdown() then
		self:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
	end

	self.texture = self:CreateTexture(nil, "ARTWORK")
	self.texture:SetAllPoints()

	self:SetScript("OnEnter", self.OnMouseEnter)
	self:SetScript("OnLeave", self.OnMouseLeave)
end
function PinMixin:OnAcquire(info)
	self.poiInfo = info
	self.areaPoiID = info.areaPoiID
	self.name = info.name
	self.description = info.description
	self.tooltipWidgetSet = info.tooltipWidgetSet
	self.iconWidgetSet = info.iconWidgetSet
	self.textureKit = info.uiTextureKit

	self.texture:SetAtlas(info.atlasName)

	if ns.OnPinAcquired then
		ns.OnPinAcquired(self, info)
	end
end
function PinMixin:OnMouseEnter()
	-- /dump C_AreaPoiInfo.GetAreaPOIInfo(2248, 7781)
	-- see: AreaPOIPinMixin:TryShowTooltip
	local verticalPadding
	-- local isTimed, hideTimer = C_AreaPoiInfo.IsAreaPOITimed(self.areaPoiID)
	local tooltip = GetAppropriateTooltip()
	tooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip_SetTitle(tooltip, self.name, HIGHLIGHT_FONT_COLOR)
	if self.description and self.description ~= "" then
		GameTooltip_AddNormalLine(tooltip, self.description)
	end

	if ns.AddToTooltip then
		ns.AddToTooltip(tooltip, self)
	end

	if ns.allowTooltipWidgets and self.tooltipWidgetSet then
		local overflow = GameTooltip_AddWidgetSet(tooltip, self.tooltipWidgetSet, 10)
		if overflow then
			verticalPadding = -overflow
		end
	end

	if ns.DEBUG then
		tooltip:AddDoubleLine("areaPoiID", self.areaPoiID)
		tooltip:AddDoubleLine("originalMapID", self.originalMapID)
	end

	tooltip:Show()
	if verticalPadding then
		tooltip:SetPadding(0, verticalPadding)
	end

	-- Could do this, but it'd confuse listeners because these aren't on the right map
	-- EventRegistry:TriggerEvent("AreaPOIPin.MouseOver", self, true, self.poiInfo.areaPoiID, self.poiInfo.name or "")
	EventRegistry:TriggerEvent("X-ImportedAreaPOIPin.MouseOver", self, true, self.originalMapID, self.poiInfo.areaPoiID, self.poiInfo.name or "")
end
function PinMixin:OnMouseLeave()
	GetAppropriateTooltip():Hide()
end


-- frameType, parent, template, resetFunc, forbidden, frameInitializer, capacity
local pool = CreateFramePool(
	"Frame", nil, nil,
	function(_, frame)
		frame.texture:SetVertexColor(1, 1, 1, 1)
	end,
	nil,
	function(frame)
		Mixin(frame, PinMixin)
		frame:OnLoad()
	end
)

local function getMapChildrenInfo(mapID)
	local children = C_Map.GetMapChildrenInfo(mapID) or {}
	if ns.extraChildren[mapID] then
		for _, childID in ipairs(ns.extraChildren[mapID]) do
			table.insert(children, C_Map.GetMapInfo(childID))
		end
	end
	return children
end

-- ns.GetPointsFromMapInfo(mapInfo)

local function refreshMapPins(mapID)
	-- all needed data should be loaded by now
	-- print("map", mapID)
	if not mapID then return end
	local mapInfo = C_Map.GetMapInfo(mapID)
	if not (mapInfo and ns.validMapTypes[mapInfo.mapType]) then
		return
	end

	pool:ReleaseAll()
	HBDP:RemoveAllWorldMapIcons(myname)

	if ns.CVAR and not C_CVar.GetCVarBool(ns.CVAR) then
		return
	end

	for _, childInfo in ipairs(getMapChildrenInfo(mapID)) do
		if ns.validChildMapTypes[childInfo.mapType] then
			local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(childInfo.mapID, mapID)
			if minX then
				-- print(">child", childInfo.mapID)
				for poiID, info in pairs(ns.GetPointsFromMapInfo(childInfo, mapID)) do
					-- print(">>info", info.atlasName, info.name)
					local x, y = info.position:GetXY()
					local tx = Lerp(minX, maxX, x)
					local ty = Lerp(minY, maxY, y)
					info.position:SetXY(tx, ty)

					local icon = pool:Acquire()
					icon:OnAcquire(info)
					icon.originalMapID = childInfo.mapID

					HBDP:AddWorldMapIconMap(myname, icon, mapID, tx, ty)
				end
			-- else
			-- 	print(">child", childInfo.mapID, "SKIPPED no rect")
			end
		end
	end
end

EventRegistry:RegisterCallback("MapCanvas.MapSet", function(_, mapID)
	refreshMapPins(mapID)
end)

EventRegistry:RegisterFrameEventAndCallback("CVAR_UPDATE", function(_, cvar, value)
	if ns.CVAR and cvar == ns.CVAR and WorldMapFrame:IsVisible() then
		refreshMapPins(WorldMapFrame:GetMapID())
	end
end)

local function isChecked(key)
	return db[key]
end
local function setChecked(key)
	db[key] = not db[key]
	refreshMapPins(WorldMapFrame:GetMapID())
end
Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(owner, rootDescription, contextData)
	if not ns.AddToTrackingMenu then
		return
	end
	local mapInfo = C_Map.GetMapInfo(owner:GetParent():GetMapID())
	if not (mapInfo and ns.validMapTypes[mapInfo.mapType]) then
		return
	end
	ns.AddToTrackingMenu(owner, rootDescription, contextData, isChecked, setChecked)
end)
