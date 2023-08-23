local SoundStorage = {}
local Volumes = {
    [1] = 0.1,
    [2] = 0.2,
    [3] = 0.3
}
RegisterNetEvent("ACSoundFX", function(soundLevel, entityNet, soundId)
    if soundLevel == 0 then
        exports.xsound:Destroy(-1, soundId)

        Entity(NetworkGetEntityFromNetworkId(entityNet)).state.AirCond = nil
    else
        Entity(NetworkGetEntityFromNetworkId(entityNet)).state.AirCond = { soundId, soundLevel }
        SoundStorage[entityNet] = {
            id = soundId,
            lvl = soundLevel,
            new = true
        }
    end
end)

RegisterNetEvent("ACSoundFXRESET", function()
    for entityNet, data in pairs(SoundStorage) do
        exports.xsound:Destroy(data.id)
        data.new = false
        Entity(NetworkGetEntityFromNetworkId(entityNet)).state.AirCond = nil
    end

    for _, veh in pairs(GetAllVehicles()) do
        Entity(veh).state.AirCond = nil
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)

        for entityNet, data in pairs(SoundStorage) do
            local entity = NetworkGetEntityFromNetworkId(entityNet)

            if not GetIsVehicleEngineRunning(entity) then
                exports.xsound:Destroy(-1, data.id)

                Entity(NetworkGetEntityFromNetworkId(entityNet)).state.AirCond = nil
            else
                if data.new then
                    exports.xsound:PlayUrlPos(-1, data.id, "https://www.youtube.com/watch?v=EmadKRKURbo",
                        Volumes[data.lvl],
                        GetEntityCoords(entity), true)
                    exports.xsound:Distance(-1, data.id, 2.0)
                    SoundStorage[entityNet].new = false
                else
                    exports.xsound:Position(-1, data.id, GetEntityCoords(entity))
                end
            end
        end
    end
end)
