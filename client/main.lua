local spawnedNetIds = {}

local function debugPrint(...)
    if Config.Debug then
        print(('[zrp_scooter] %s'):format(table.concat({...}, ' ')))
    end
end

local function notify(description, type)
    lib.notify({
        title = 'Scooter',
        description = description,
        type = type or 'inform'
    })
end

local function loadModel(model)
    local modelHash = type(model) == 'number' and model or joaat(model)

    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        return false, modelHash
    end

    RequestModel(modelHash)

    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > timeout then
            return false, modelHash
        end
        Wait(0)
    end

    return true, modelHash
end

local function getSpawnCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)

    return vector3(
        coords.x + (forward.x * Config.SpawnDistance),
        coords.y + (forward.y * Config.SpawnDistance),
        coords.z
    )
end

local function findGroundZ(coords)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
    if found then
        return vector3(coords.x, coords.y, groundZ + 0.02)
    end

    return coords
end

local function canSpawnAtCoords(coords)
    return not IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 2.0)
end

RegisterNetEvent('zrp_scooter:client:spawnScooter', function()
    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)
    local baseCoords = getSpawnCoords()
    local spawnCoords = findGroundZ(baseCoords)

    if not canSpawnAtCoords(spawnCoords) then
        notify(Config.Notify.AreaBlocked, 'error')
        TriggerServerEvent('zrp_scooter:server:spawnFailed')
        return
    end

    local loaded, modelHash = loadModel(Config.VehicleModel)
    if not loaded then
        notify(Config.Notify.SpawnFailed, 'error')
        TriggerServerEvent('zrp_scooter:server:spawnFailed')
        return
    end

    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, true)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(modelHash)
        notify(Config.Notify.SpawnFailed, 'error')
        TriggerServerEvent('zrp_scooter:server:spawnFailed')
        return
    end

    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleEngineOn(vehicle, Config.Vehicle.EngineOnSpawn, true, false)
    SetVehicleFuelLevel(vehicle, Config.Vehicle.Fuel)
    SetVehRadioStation(vehicle, 'OFF')
    SetVehicleDoorsLocked(vehicle, 1)

    local plate = ('%s%s'):format(
        Config.Vehicle.PlatePrefix,
        tostring(math.random(100, 999))
    )
    SetVehicleNumberPlateText(vehicle, plate)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    SetModelAsNoLongerNeeded(modelHash)

    if Config.Vehicle.WarpOntoVehicle then
        TaskWarpPedIntoVehicle(ped, vehicle, -1)
    else
        SetPedCoordsKeepVehicle(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z)
    end

    spawnedNetIds[netId] = true

    debugPrint('Spawned scooter netId:', tostring(netId))
    TriggerServerEvent('zrp_scooter:server:registerScooter', netId, plate)
end)

RegisterNetEvent('zrp_scooter:client:pickupSuccess', function(netId)
    if netId then
        spawnedNetIds[netId] = nil
    end

    notify(Config.Notify.PickedUp, 'success')
end)

RegisterNetEvent('zrp_scooter:client:deploySuccess', function()
    notify(Config.Notify.Deployed, 'success')
end)

RegisterNetEvent('zrp_scooter:client:notify', function(message, type)
    notify(message, type)
end)

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'zrp_scooter_pickup',
            icon = Config.Target.Icon,
            label = Config.Target.Label,
            distance = Config.Target.Distance,
            canInteract = function(entity, distance, coords, name, bone)
                if not DoesEntityExist(entity) then
                    return false
                end

                local state = Entity(entity).state
                if not state or not state.zrpScooter then
                    return false
                end

                return true
            end,
            onSelect = function(data)
                if not data or not data.entity or not DoesEntityExist(data.entity) then
                    return
                end

                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                if not netId or netId == 0 then
                    return
                end

                TriggerServerEvent('zrp_scooter:server:pickupScooter', netId)
            end
        }
    })
end)