local function temperatureBlendWithRND(a, b, stepSize)
	if a > b then
		return -stepSize
	elseif a < b then
		return stepSize
	else
		return stepSize
	end
end

local function getWindowsUp(vehicle)
	local windows = { 0, 1, 2, 3, 6, 7 }
	local windowsUp = 0

	for _, windowIndex in ipairs(windows) do
		if IsVehicleWindowIntact(vehicle, windowIndex) == 1 then
			windowsUp = (windowsUp or 0) + 1
		end
	end

	return windowsUp
end

local function getDoorsClosed(vehicle)
	local numOfDoors = GetNumberOfVehicleDoors(vehicle)
	local doorsClosed = numOfDoors

	for doorIndex = 0, numOfDoors do
		if GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0.0 then
			doorsClosed = (doorsClosed or 0) - 1
		end
	end

	return numOfDoors, doorsClosed
end

local function isDogInVehicle(vehicle)
	local leftRear = GetPedInVehicleSeat(vehicle, 1)
	local rightRear = GetPedInVehicleSeat(vehicle, 2)

	if leftRear ~= nil and DoesEntityExist(leftRear) and GetEntityModel(leftRear) == `a_c_shepherd` then
		return true
	end

	if rightRear ~= nil and DoesEntityExist(rightRear) and GetEntityModel(rightRear) == `a_c_shepherd` then
		return true
	end

	return false
end

local function triggerHotNPop(vehicle)
	-- Siren
	local tone = exports.lvc:GetToneAtPos(6)
	exports.lvc:SetLxSirenStateForVeh(vehicle, tone)
	SetVehicleSiren(vehicle, true)

	-- Rear Windows
	RollDownWindow(vehicle, 2)
	RollDownWindow(vehicle, 3)

	-- Text to Speech Alert
	--TriggerServerEvent("HotNPopAlert", GetEntityCoords(vehicle), tostring(vehicle))
end

local WINDOW_CONFIG = CONFIG.SIM_WINDOW
local function CalculateWindowTemperatureChange(numOfWindowsUp, currentExtTemperature, currentIntTemperature)
	local temperatureChange = 0

	if numOfWindowsUp < 6 then
		local coolingFactor = WINDOW_CONFIG.COOLING_FACTOR + ((6 - numOfWindowsUp) * WINDOW_CONFIG.OPEN_FACTOR)

		temperatureChange = temperatureBlendWithRND(currentIntTemperature, currentExtTemperature, coolingFactor)
	end

	print("Window Change: " .. temperatureChange)

	return temperatureChange
end

local DOOR_CONFIG = CONFIG.SIM_DOOR
local function CalculateDoorTemperatureChange(numOfDoors, numOfDoorsClosed, currentExtTemperature, currentIntTemperature)
	local temperatureChange = 0

	if numOfDoors > numOfDoorsClosed then
		local coolingFactor = DOOR_CONFIG.COOLING_FACTOR +
			((numOfDoors - numOfDoorsClosed) * DOOR_CONFIG.OPEN_FACTOR)

		temperatureChange = temperatureBlendWithRND(currentIntTemperature, currentExtTemperature, coolingFactor)
	end

	print("Door Change: " .. temperatureChange)

	return temperatureChange
end

local function CalculateEngineTemperatureChange(engineOn)
	if engineOn then
		print("Engine Change: 0.005")

		return 0.005
	else
		return 0
	end
end

local AC_CONFIG = CONFIG.SIM_AIRCONDITIONING
local function CalculateAirConditioningTemperatureChange(engineOn, airCond, numOfWindowsUp, numOfDoors, numOfDoorsClosed)
	local temperatureChange = 0

	if engineOn and airCond ~= 0 then
		local acMultiplier = AC_CONFIG.MULTIPLIERS[airCond]
		local coolingFactor = AC_CONFIG.COOLING_FACTOR
		local baseCooling = acMultiplier * coolingFactor

		-- Window Dampening
		local windowDampeningFactor = (6 - numOfWindowsUp) * AC_CONFIG.WINDOW_OPEN_FACTOR

		-- Door Dampening
		local doorDampeningFactor = (numOfDoors - numOfDoorsClosed) * AC_CONFIG.DOOR_OPEN_FACTOR

		if windowDampeningFactor > 0 then
			baseCooling = baseCooling + windowDampeningFactor
		end
		if doorDampeningFactor > 0 then
			baseCooling = baseCooling + doorDampeningFactor
		end

		temperatureChange = baseCooling

		-- Make sure A/C cant flip
		if airCond <= 3 then
			if temperatureChange > 0 then temperatureChange = 0 end
		else
			if temperatureChange < 0 then temperatureChange = 0 end
		end

		print("AC Change: " .. temperatureChange)

		return temperatureChange
	else
		return temperatureChange
	end
end

local function CalculateAmbientTemperatureChange(weatherCondition)
	local timeOfDay = GetClockHours()
	local timeOfDayFactor = (timeOfDay >= 6 and timeOfDay < 18) and CONFIG.SIM_AMBIENT.DAY or CONFIG.SIM_AMBIENT.NIGHT
	local weatherFactor = CONFIG.SIM_AMBIENT.WEATHERS[weatherCondition] or 0
	local temperatureChange = (timeOfDayFactor + weatherFactor) * CONFIG.SIM_AMBIENT.FACTOR

	print("Ambient Change: " .. temperatureChange)

	return temperatureChange
end

local Storage = {}
Citizen.CreateThread(function()
	while true do
		Wait(1000)

		for _, vehicle in pairs(GetGamePool("CVehicle")) do
			if CONFIG.VEHICLES[GetEntityModel(vehicle)] and NetworkGetEntityOwner(vehicle) == PlayerId() then
				print("\n")
				local dogInVehicle = isDogInVehicle(vehicle)
				local numOfWindowsUp = getWindowsUp(vehicle)
				local numOfDoors, numOfDoorsClosed = getDoorsClosed(vehicle)
				local currentExtTemperature = exports["CR-Temperature"]:GetTemperature()
				local isEngineOn = GetIsVehicleEngineRunning(vehicle)

				Storage[vehicle] = Storage[vehicle] or {
					temperature = (currentExtTemperature * 1.25),
					lastActive = 0
				}

				local vehicleData = Storage[vehicle]
				local airCondData = Entity(vehicle).state.AirCond or { 0, 0 }
				local airCond = airCondData[2]
				local currentIntTemperature = vehicleData.temperature

				currentIntTemperature = currentIntTemperature +
					CalculateWindowTemperatureChange(numOfWindowsUp, currentExtTemperature,
						currentIntTemperature)

				currentIntTemperature = currentIntTemperature +
					CalculateDoorTemperatureChange(numOfDoors, numOfDoorsClosed, currentExtTemperature,
						currentIntTemperature)

				currentIntTemperature = currentIntTemperature +
					CalculateAirConditioningTemperatureChange(isEngineOn, airCond, numOfWindowsUp, numOfDoors,
						numOfDoorsClosed)

				currentIntTemperature = currentIntTemperature +
					CalculateAmbientTemperatureChange(GetPrevWeatherTypeHashName())

				currentIntTemperature = currentIntTemperature + CalculateEngineTemperatureChange(isEngineOn)

				print("Current Temperature: " ..
					vehicleData.temperature .. ", New Temperature: " .. currentIntTemperature)

				vehicleData.temperature = currentIntTemperature

				if dogInVehicle and vehicleData.temperature > 100 and GetGameTimer() > vehicleData.lastActive then
					triggerHotNPop(vehicle)
					vehicleData.lastActive = GetGameTimer() + 30000
				end
			end
		end
	end
end)

----------------- HUD ELEMENT -----------------

local function RoundToDecimal(number, decimalPlaces)
	local multiplier = 10 ^ decimalPlaces
	return math.floor(number * multiplier + 0.5) / multiplier
end

local function TemperatureToRGB(temperature)
	local minTemp = 69
	local maxTemp = 100

	-- Ensure the temperature is within the valid range
	temperature = math.min(maxTemp, math.max(minTemp, temperature))

	-- Calculate the lerp factor for blue to red (0 to 1)
	local lerpFactor = (temperature - minTemp) / (maxTemp - minTemp)

	-- Lerp between a colder blue (60, 90, 255) and a warmer red (255, 60, 60)
	local r = math.floor(lerpFactor * 255 + (1 - lerpFactor) * 60)
	local g = math.floor(lerpFactor * 60 + (1 - lerpFactor) * 255)
	local b = 90

	return { r, g, b }
end

local function GetACString(aclvl)
	if aclvl == nil or aclvl == 0 then
		return "Off"
	elseif aclvl <= 3 then
		return tostring(aclvl) .. " (C)"
	else
		return tostring(aclvl - 3) .. " (H)"
	end
end

local function DrawTemp(temp, acLvl)
	local rgb = TemperatureToRGB(temp)
	local acs = GetACString(acLvl)

	SetTextFont(0)
	SetTextProportional(1)
	SetTextScale(0.35, 0.35)
	SetTextColour(rgb[1], rgb[2], rgb[3], 255)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextEdge(2, 0, 0, 0, 150)
	SetTextDropShadow()
	SetTextOutline()
	SetTextEntry("STRING")
	AddTextComponentString("Vehicle: " .. tostring(temp) .. "F - A/C: " .. acs)
	DrawText(0.25, 0.78)
end

Citizen.CreateThread(function()
	while true do
		Wait(0)

		local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)

		if DoesEntityExist(playerVeh) and CONFIG.VEHICLES[GetEntityModel(playerVeh)] and Storage[playerVeh] then
			local vehAirCond = Entity(playerVeh).state.AirCond or { 0, 0 }
			DrawTemp(RoundToDecimal(Storage[playerVeh].temperature, 1) or 70.0, vehAirCond[2])
		end
	end
end)

----------------- AIR CONDITIONING -----------------

local vehicleStates = {}
Citizen.CreateThread(function()
	repeat
		Wait(0)
	until DoesEntityExist(PlayerPedId())
	TriggerServerEvent("ACSoundFXRESET")

	while true do
		Wait(100)

		local playerPed = PlayerPedId()
		local currentVehicle = GetVehiclePedIsIn(playerPed, false)
		local lastVehicle = GetVehiclePedIsIn(playerPed, true)
		local vehicleToUpdate = nil
		local dynamicMode = nil

		if currentVehicle ~= nil and currentVehicle ~= 0 then
			vehicleToUpdate = currentVehicle
			dynamicMode = false
		elseif lastVehicle ~= nil and lastVehicle ~= 0 then
			vehicleToUpdate = lastVehicle
			dynamicMode = true
		end

		if vehicleToUpdate ~= nil then
			local ACState = Entity(vehicleToUpdate).state.AirCond
			vehicleStates[vehicleToUpdate] = vehicleStates[vehicleToUpdate] or {}

			if dynamicMode ~= nil and ACState ~= nil then
				local acSoundId = ACState[1]
				local acSoundLvl = ACState[2]
				local acUID = tostring(acSoundId) .. tostring(acSoundLvl)

				if vehicleStates[vehicleToUpdate][2] ~= acUID or vehicleStates[vehicleToUpdate][1] ~= dynamicMode then
					Wait(1000)
					exports.xsound:setSoundDynamic(acSoundId, dynamicMode)
					vehicleStates[vehicleToUpdate][1] = dynamicMode
					vehicleStates[vehicleToUpdate][2] = acUID
				end
			elseif ACState == nil then
				vehicleStates[vehicleToUpdate] = {}
			end
		end
	end
end)

RegisterCommand("ac", function(src, args, raw)
	local acType = tostring(args[1]):lower()
	local acValue = tonumber(args[2])
	local plrVeh = GetVehiclePedIsIn(PlayerPedId(), false)

	if acType == nil or (acType ~= "c" and acType ~= "h") then
		acValue = 0
	elseif acType == 'h' and acValue ~= 0 then
		acValue = acValue + 3
	end
	if plrVeh == nil or not DoesEntityExist(plrVeh) or IsEntityDead(plrVeh) or Storage[plrVeh] == nil then return end

	if acValue ~= 0 and not AC_CONFIG.MULTIPLIERS[acValue] then
		acValue = 0
	end

	local soundId = tostring(plrVeh) .. "_AC"
	TriggerServerEvent("ACSoundFX", acValue, NetworkGetNetworkIdFromEntity(plrVeh), soundId)
end, false)

TriggerEvent("chat:addSuggestion", "/ac", "In-Car Climate Control", {
	{ name = "AC Type",  help = "H = Hot, C = Cold" },
	{ name = "AC Level", help = "0 = Off, 1 = Low, 2 = Med, 3 = High" },
})
