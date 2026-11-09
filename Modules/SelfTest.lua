-- Dev-only diagnostics.  Run /routes selftest in game.
-- This module is read-only: it does not create routes, change settings, or
-- touch SavedVariables.  Remove it from Routes.toc for release builds if the
-- extra slash subcommand is not wanted, or set ENABLED = false below.
-- Diagnostic labels are intentionally English/dev-only and are not part of the
-- user-facing options UI.

local Routes = LibStub("AceAddon-3.0"):GetAddon("Routes")
local SelfTest = Routes:NewModule("SelfTest", "AceEvent-3.0")

-- Set to false in release builds to keep the slash subcommand out of the UI.
local ENABLED = true

function SelfTest:IsEnabled()
	return ENABLED
end

local function Print(fmt, ...)
	local message = select("#", ...) > 0 and fmt:format(...) or fmt
	Routes:Print("|cff33ff99[selftest]|r " .. message)
end

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e, f
end

local function CountTable(t)
	local count = 0
	if type(t) == "table" then
		for _ in pairs(t) do count = count + 1 end
	end
	return count
end

local function GetPlayerMapPositionSafe(zoneID)
	if not zoneID or not C_Map or not C_Map.GetPlayerMapPosition then return nil end
	local ok, position = pcall(C_Map.GetPlayerMapPosition, zoneID, "player")
	if not ok or not position then return nil end
	local x, y = SafeCall(position.GetXY, position)
	if not x or not y then return nil end
	if Routes.IsSecretValue(x) or Routes.IsSecretValue(y) then return nil end
	return x, y
end

function SelfTest:Run()
	Print("Routes self-test on %s", tostring(GetBuildInfo and select(1, GetBuildInfo()) or "unknown"))

	local _, build, buildDate, tocVersion = GetBuildInfo()
	local projectID = WOW_PROJECT_ID
	Print("client build=%s interface=%s date=%s projectID=%s camelot=%s",
		tostring(build), tostring(tocVersion), tostring(buildDate), tostring(projectID),
		tostring(projectID == WOW_PROJECT_CAMELOT))

	-- Map data / HereBeDragons -------------------------------------------------
	local dragons = Routes.Dragons
	local mapData = dragons and dragons.mapData
	local zoneCount = 0
	if type(mapData) == "table" then
		for _, data in pairs(mapData) do
			if data and (data.mapType == Enum.UIMapType.Zone or data.mapType == Enum.UIMapType.Continent) then
				zoneCount = zoneCount + 1
			end
		end
	end
	local hbdVersion = "embedded (vendor script enforces 2.18+)"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, version = pcall(C_AddOns.GetAddOnMetadata, "HereBeDragons", "Version")
		if ok and version and version ~= "" then
			hbdVersion = version
		end
	end
	Print("HereBeDragons version=%s mapData entries=%s zones/continents=%s worldMapData entries=%s",
		tostring(hbdVersion), tostring(CountTable(mapData)), tostring(zoneCount),
		tostring(CountTable(dragons and dragons.worldMapData)))

	local zoneID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	local zoneName = zoneID and Routes.GetZoneName(zoneID) or nil
	local zoneW, zoneH = nil, nil
	if zoneID and dragons and dragons.GetZoneSize then
		zoneW, zoneH = SafeCall(dragons.GetZoneSize, dragons, zoneID)
	end
	local px, py = GetPlayerMapPositionSafe(zoneID)
	local mappedID = zoneName and Routes.LZName[zoneName] or nil
	if mappedID == 0 then mappedID = nil end
	Print("zone id=%s name=%s size=%sx%s player=%s,%s LZName round-trip=%s",
		tostring(zoneID), tostring(zoneName), tostring(zoneW), tostring(zoneH),
		px and ("%.4f"):format(px) or "restricted",
		py and ("%.4f"):format(py) or "restricted",
		tostring(mappedID))

	-- Minimap -----------------------------------------------------------------
	local shape = Routes.GetMinimapShape and Routes.GetMinimapShape() or "unknown"
	local cropL, cropR, cropT, cropB = 0, 0, 0, 0
	if Routes.GetMinimapCropInsets then
		cropL, cropR, cropT, cropB = Routes.GetMinimapCropInsets()
	end
	local zoom = Minimap and SafeCall(Minimap.GetZoom, Minimap)
	local scale = Minimap and SafeCall(Minimap.GetScale, Minimap)
	local width = Minimap and SafeCall(Minimap.GetWidth, Minimap)
	local height = Minimap and SafeCall(Minimap.GetHeight, Minimap)
	local viewRadius = C_Minimap and SafeCall(C_Minimap.GetViewRadius)
	local indoors = SafeCall(IsIndoors)
	local rotate = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("rotateMinimap")
	Print("minimap shape=%s crop=l%s r%s t%s b%s zoom=%s scale=%s size=%sx%s viewRadius=%s indoors=%s rotate=%s",
		tostring(shape), tostring(cropL), tostring(cropR), tostring(cropT), tostring(cropB),
		tostring(zoom), tostring(scale), tostring(width), tostring(height),
		tostring(viewRadius), tostring(indoors), tostring(rotate))

	-- Professions and tracking -------------------------------------------------
	if GetProfessions and GetProfessionInfo then
		local names = {}
		for _, index in pairs({ GetProfessions() }) do
			if index then
				local name = SafeCall(GetProfessionInfo, index)
				if name then names[#names + 1] = name end
			end
		end
		Print("professions: %s", #names > 0 and table.concat(names, ", ") or "none")
	else
		Print("professions: API unavailable")
	end

	if C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo then
		local active = {}
		local total = C_Minimap.GetNumTrackingTypes()
		for i = 1, total do
			local info = C_Minimap.GetTrackingInfo(i)
			if info and info.active then
				active[#active + 1] = ("%s(%s)"):format(tostring(info.name), tostring(info.spellID))
			end
		end
		Print("tracking types=%s active=%s", tostring(total),
			#active > 0 and table.concat(active, ", ") or "none")
	else
		Print("tracking: API unavailable")
	end

	-- GatherMate2 --------------------------------------------------------------
	local gm = Routes.plugins and Routes.plugins.GatherMate2
	if gm and gm.IsActive and gm.IsActive() and _G.GatherMate2 and _G.GatherMate2.gmdbs then
		local gmZone = zoneName and Routes.LZName[zoneName]
		if gmZone == 0 then gmZone = nil end
		local total = 0
		local parts = {}
		for dbType, dbData in pairs(_G.GatherMate2.gmdbs) do
			local count = 0
			if gmZone and type(dbData) == "table" and dbData[gmZone] then
				count = CountTable(dbData[gmZone])
			end
			total = total + count
			if count > 0 then
				parts[#parts + 1] = ("%s=%d"):format(tostring(dbType), count)
			end
		end
		table.sort(parts)
		Print("GatherMate2 active=%s zone=%s nodes=%d %s",
			tostring(zoneName), tostring(gmZone), total,
			#parts > 0 and table.concat(parts, ", ") or "(no nodes in this zone)")
	else
		Print("GatherMate2 active=%s", tostring(gm and gm.IsActive and gm.IsActive() or false))
	end

	-- World map provider -------------------------------------------------------
	local mapFrameShown = WorldMapFrame and SafeCall(WorldMapFrame.IsShown, WorldMapFrame)
	local mapFrameID = WorldMapFrame and SafeCall(WorldMapFrame.GetMapID, WorldMapFrame)
	Print("WorldMapFrame shown=%s mapID=%s provider=%s battlefieldProvider=%s pin=%s",
		tostring(mapFrameShown), tostring(mapFrameID),
		tostring(Routes.DataProvider ~= nil), tostring(Routes.BattleFieldDataProvider ~= nil),
		tostring(Routes.DataProvider and Routes.DataProvider.pin ~= nil))

	-- Route storage round-trip -------------------------------------------------
	local coord = Routes:getID(0.1234, 0.5678)
	local rx, ry = Routes:getXY(coord)
	local roundTrip = math.abs(rx - 0.1234) < 0.0001 and math.abs(ry - 0.5678) < 0.0001
	Print("route storage round-trip=%s (%s -> %.4f,%.4f)", tostring(roundTrip),
		tostring(coord), rx, ry)

	-- TSP smoke test ----------------------------------------------------------
	if zoneID and zoneW and zoneW > 0 and Routes.TSP and Routes.TSP.SolveTSP then
		local nodes = {}
		for i = 1, 8 do
			local x = 0.20 + ((i - 1) % 4) * 0.15
			local y = 0.20 + math.floor((i - 1) / 4) * 0.30
			nodes[i] = Routes:getID(x, y)
		end
		local parameters = Routes.db.global.defaults.tsp
		local ok, path, metadata, length, iterations, seconds =
			pcall(Routes.TSP.SolveTSP, Routes.TSP, nodes, nil, {}, zoneID, parameters, nil, false)
		if ok and path then
			Print("TSP 8 nodes: length=%.1f iterations=%s time=%.3fs result=%d nodes",
				length or 0, tostring(iterations), seconds or 0, #path)
		else
			Print("TSP 8 nodes: FAILED (%s)", tostring(path))
		end
	else
		Print("TSP smoke test: skipped (no zone size or TSP API)")
	end

	-- TomTom and keybinds ------------------------------------------------------
	local tt = _G.TomTom
	local ttVersion = "unknown"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, version = pcall(C_AddOns.GetAddOnMetadata, "TomTom", "Version")
		if ok and version then ttVersion = version end
	end
	Print("TomTom present=%s version=%s SetCustomWaypoint=%s RemoveWaypoint=%s module=%s",
		tostring(tt ~= nil), tostring(ttVersion),
		tostring(tt and type(tt.SetCustomWaypoint) == "function"),
		tostring(tt and type(tt.RemoveWaypoint) == "function"),
		tostring(Routes.GetModule and Routes:GetModule("TomTom", true) ~= nil))

	local function Binding(action)
		local getKey = rawget(_G, "GetBindingKey")
		if not getKey then return "API unavailable" end
		local ok, key = pcall(getKey, action)
		if not ok or not key then return "unbound" end
		return key
	end
	Print("keybinds start=%s stop=%s change=%s",
		Binding("ROUTESTTSTART"), Binding("ROUTESTTSTOP"), Binding("ROUTESTTCHANGEDIR"))

	Print("done")
end

-- vim: ts=4 noexpandtab
