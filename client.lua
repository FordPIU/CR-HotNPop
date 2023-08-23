local hotnpopVehicles = {
	[`pdkn1`] = true,
	[`pdkn2`] = true,
	[`pdkn3`] = true,
	[`pdkn4`] = true,
	[`pdkn5`] = true,
	[`pdkn6`] = true,
	[`pdkn7`] = true,
	[`pdkn8`] = true,
	[`pdkn9`] = true,
	[`pdkns1`] = true,
	[`pdkns2`] = true,
	[`pdkns3`] = true,
	[`pdkns4`] = true,
	[`pdkns5`] = true,
	[`pdkns6`] = true,
	[`pdkns7`] = true,
	[`pdkns8`] = true,
	[`pdkns9`] = true,
}

local function areWindowsUp(vehicle)
	local window_lf = IsVehicleWindowIntact(vehicle, 0)
	local window_rf = IsVehicleWindowIntact(vehicle, 1)
	local window_lr = IsVehicleWindowIntact(vehicle, 2)
	local window_rr = IsVehicleWindowIntact(vehicle, 3)
	local window_wf = IsVehicleWindowIntact(vehicle, 6)
	local window_wr = IsVehicleWindowIntact(vehicle, 7)

	if window_lf == 1 and window_rf == 1 and window_lr == 1 and window_rr == 1 and window_wf == 1 and window_wr == 1 then
		return true
	else
		return false
	end
end

local function areDoorsClosed(vehicle)
	local numOfDoors = GetNumberOfVehicleDoors(vehicle)
	for doorIndex = 0, numOfDoors do
		if GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0.0 then
			return false
		end
	end

	return true
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

local AirConditioningMultiupliers = {
	[1] = 2.0,
	[2] = 3.5,
	[3] = 5.0
}
local function CalculateInternalTemperatureChangeRate(currentTemp, engineOn, windowsDown, airConditioning)
	local temperatureChangeRate = 0.075 -- Base change rate

	if engineOn and airConditioning ~= 0 then
		temperatureChangeRate = temperatureChangeRate * AirConditioningMultiupliers[airConditioning]
	end

	if airConditioning > 0 or windowsDown then
		if currentTemp > 70 then
			temperatureChangeRate = temperatureChangeRate * (1 + (currentTemp - 70) / 50)
		elseif currentTemp < 40 then
			temperatureChangeRate = temperatureChangeRate * (1 + (40 - currentTemp) / 60)
		end
	end

	return temperatureChangeRate
end

local function triggerHotNPop(vehicle)
	-- Siren
	local tone = exports.lvc:GetToneAtPos(6)
	exports.lvc:SetLxSirenStateForVeh(vehicle, tone)
	SetVehicleSiren(vehicle, true)

	-- Rear Windows
	RollDownWindow(vehicle, 2)
	RollDownWindow(vehicle, 3)
end

local Storage = {}
Citizen.CreateThread(function()
	while true do
		Wait(1000)

		for _, vehicle in pairs(GetGamePool("CVehicle")) do
			if hotnpopVehicles[GetEntityModel(vehicle)] and NetworkGetEntityOwner(vehicle) == PlayerId() then
				local dogInVeh = isDogInVehicle(vehicle)
				local windowsUp = areWindowsUp(vehicle)
				local doorsClosed = areDoorsClosed(vehicle)
				local engineOff = not GetIsVehicleEngineRunning(vehicle)
				local currentTemp = exports["CR-Temperature"]:GetTemperature()

				Storage[vehicle] = Storage[vehicle] or {
					temperature = (currentTemp / 1.25),
					active = false
				}

				local vehicleData = Storage[vehicle]
				local airCondData = Entity(vehicle).state.AirCond or { 0, 0 }
				local airCond = airCondData[2]

				if (windowsUp and doorsClosed and doorsClosed and engineOff) or vehicleData.temperature < 70 then
					Storage[vehicle].temperature = vehicleData.temperature +
						CalculateInternalTemperatureChangeRate(currentTemp, not engineOff, not windowsUp, airCond)
				else
					Storage[vehicle].temperature = vehicleData.temperature -
						CalculateInternalTemperatureChangeRate(currentTemp, not engineOff, not windowsUp, airCond)
				end

				if dogInVeh and Storage[vehicle].temperature > 100 then
					triggerHotNPop(vehicle)
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

local function DrawTemp(temp, acLvl)
	local rgb = TemperatureToRGB(temp)

	if acLvl == 0 then
		acLvl = "Off"
	else
		acLvl = "On (" .. tostring(acLvl) .. ")"
	end

	SetTextFont(0)
	SetTextProportional(1)
	SetTextScale(0.35, 0.35)
	SetTextColour(rgb[1], rgb[2], rgb[3], 255)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextEdge(2, 0, 0, 0, 150)
	SetTextDropShadow()
	SetTextOutline()
	SetTextEntry("STRING")
	AddTextComponentString("Vehicle: " .. tostring(temp) .. "F - A/C: " .. acLvl)
	DrawText(0.25, 0.78)
end

Citizen.CreateThread(function()
	while true do
		Wait(0)

		local playerVeh = GetVehiclePedIsIn(PlayerPedId(), true)

		if DoesEntityExist(playerVeh) and hotnpopVehicles[GetEntityModel(playerVeh)] and Storage[playerVeh] then
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
	local acValue = tonumber(args[1])
	local plrVeh = GetVehiclePedIsIn(PlayerPedId(), false)

	if plrVeh == nil or not DoesEntityExist(plrVeh) or IsEntityDead(plrVeh) or Storage[plrVeh] == nil then return end

	if acValue ~= 0 and acValue ~= 1 and acValue ~= 2 and acValue ~= 3 then
		acValue = 0
	end

	local soundId = tostring(plrVeh) .. "_AC"
	TriggerServerEvent("ACSoundFX", acValue, NetworkGetNetworkIdFromEntity(plrVeh), soundId)
end, false)

TriggerEvent("chat:addSuggestion", "/ac", "In-Car Climate Control", {
	{ name = "AC Level", help = "0 = Off, 1 = Low, 2 = Med, 3 = High" },
})
