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

local function triggerHotNPop(vehicle)
	local tone = exports.lvc:GetToneAtPos(6)
	exports.lvc:SetLxSirenStateForVeh(vehicle, tone)
	SetVehicleSiren(vehicle, true)
end

local Storage = {}
local activation_time = 60 * 5
Citizen.CreateThread(function()
	while true do
		Wait(1000)
		for _, vehicle in pairs(GetGamePool("CVehicle")) do
			if hotnpopVehicles[GetEntityModel(vehicle)] then
				local dogInVeh = isDogInVehicle(vehicle)
				local windowsUp = areWindowsUp(vehicle)
				local doorsClosed = areDoorsClosed(vehicle)
				local engineOff = not GetIsVehicleEngineRunning(vehicle)

				if dogInVeh and windowsUp and doorsClosed and doorsClosed and engineOff then
					Storage[vehicle] = Storage[vehicle] or {
						timer = 0,
						reset = false
					}
					Storage[vehicle].timer = Storage[vehicle].timer + 1

					if Storage[vehicle].timer > activation_time and Storage[vehicle].reset == false then
						triggerHotNPop(vehicle)
						Storage[vehicle].reset = true
					end
				else
					Storage[vehicle] = {
						timer = 0,
						reset = false
					}
				end
			end
		end
	end
end)
