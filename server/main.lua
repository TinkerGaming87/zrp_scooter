local ActiveScooters = {}
local PendingSpawns = {}

local function debugPrint(...)
    if Config.Debug then
        print(('[zrp_scooter] %s'):format(table.concat({...}, ' ')))
    end
end

local function notify(src, message, type)
    TriggerClientEvent('zrp_scooter:client:notify', src, message, type or 'inform')
end

local function getSourceId(sourceValue)
    return tonumber(sourceValue)
end

local function getPlayerIdentifier(src)
    local license = nil

    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:find('license:') == 1 then
            license = identifier
            break
        end
    end

    return license or ('source:%s'):format(src)
end

local function addScooterItem(src, count)
    return exports.ox_inventory:AddItem(src, Config.ItemName, count or 1)
end

local function removeScooterItem(src, count, slot)
    return exports.ox_inventory:RemoveItem(src, Config.ItemName, count or 1, nil, slot)
end

local function playerHasActiveScooter(src)
    local data = ActiveScooters[src]
    if not data then return false end

    local ent = NetworkGetEntityFromNetworkId(data.netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        return true
    end

    ActiveScooters[src] = nil
    return false
end

local function clearPlayerScooter(src)
    ActiveScooters[src] = nil
    PendingSpawns[src] = nil
end

exports('useScooterItem', function(event, item, inventory, slot, data)
    if event == 'usingItem' then
        local src = inventory.id

        if Config.AllowOnlyOneActive and playerHasActiveScooter(src) then
            notify(src, Config.Notify.AlreadyActive, 'error')
            return false
        end

        return true
    end

    if event ~= 'usedItem' then
        return
    end

    local src = inventory.id
    src = getSourceId(src)
    if not src then return end

    if Config.AllowOnlyOneActive and playerHasActiveScooter(src) then
        notify(src, Config.Notify.AlreadyActive, 'error')
        return
    end

    local removed = removeScooterItem(src, 1, slot)
    if not removed then
        notify(src, Config.Notify.SpawnFailed, 'error')
        return
    end

    PendingSpawns[src] = {
        identifier = getPlayerIdentifier(src),
        at = os.time()
    }

    TriggerClientEvent('zrp_scooter:client:spawnScooter', src)
end)

RegisterNetEvent('zrp_scooter:server:spawnFailed', function()
    local src = source
    local pending = PendingSpawns[src]
    if not pending then return end

    addScooterItem(src, 1)
    PendingSpawns[src] = nil
    notify(src, Config.Notify.SpawnFailed, 'error')
end)

RegisterNetEvent('zrp_scooter:server:registerScooter', function(netId, plate)
    local src = source
    local pending = PendingSpawns[src]
    if not pending then
        return
    end

    if type(netId) ~= 'number' or netId <= 0 then
        addScooterItem(src, 1)
        PendingSpawns[src] = nil
        notify(src, Config.Notify.SpawnFailed, 'error')
        return
    end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        addScooterItem(src, 1)
        PendingSpawns[src] = nil
        notify(src, Config.Notify.SpawnFailed, 'error')
        return
    end

    local model = GetEntityModel(ent)
    if model ~= joaat(Config.VehicleModel) then
        DeleteEntity(ent)
        addScooterItem(src, 1)
        PendingSpawns[src] = nil
        notify(src, Config.Notify.SpawnFailed, 'error')
        return
    end

    if Config.AllowOnlyOneActive and ActiveScooters[src] then
        local old = ActiveScooters[src]
        local oldEnt = NetworkGetEntityFromNetworkId(old.netId)
        if oldEnt and oldEnt ~= 0 and DoesEntityExist(oldEnt) then
            DeleteEntity(ent)
            addScooterItem(src, 1)
            PendingSpawns[src] = nil
            notify(src, Config.Notify.AlreadyActive, 'error')
            return
        end
    end

    local ownerId = getPlayerIdentifier(src)

    Entity(ent).state:set('zrpScooter', true, true)
    Entity(ent).state:set('zrpScooterOwner', ownerId, true)
    Entity(ent).state:set('zrpScooterSource', src, true)

    ActiveScooters[src] = {
        netId = netId,
        owner = ownerId,
        plate = plate
    }

    PendingSpawns[src] = nil
    debugPrint('Registered scooter for', tostring(src), 'netId', tostring(netId))
    TriggerClientEvent('zrp_scooter:client:deploySuccess', src)
end)

RegisterNetEvent('zrp_scooter:server:pickupScooter', function(netId)
    local src = source
    local active = ActiveScooters[src]

    if not active then
        notify(src, Config.Notify.InvalidScooter, 'error')
        return
    end

    if type(netId) ~= 'number' or netId <= 0 then
        notify(src, Config.Notify.InvalidScooter, 'error')
        return
    end

    if active.netId ~= netId then
        notify(src, Config.Notify.NotOwner, 'error')
        return
    end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then
        ActiveScooters[src] = nil
        notify(src, Config.Notify.InvalidScooter, 'error')
        return
    end

    local state = Entity(ent).state
    local ownerId = getPlayerIdentifier(src)

    if not state.zrpScooter then
        notify(src, Config.Notify.InvalidScooter, 'error')
        return
    end

    if state.zrpScooterOwner ~= ownerId then
        notify(src, Config.Notify.NotOwner, 'error')
        return
    end

    local canCarry = exports.ox_inventory:CanCarryItem(src, Config.ItemName, 1)
    if not canCarry then
        notify(src, Config.Notify.NoRoom, 'error')
        return
    end

    DeleteEntity(ent)

    local added = addScooterItem(src, 1)
    if not added then
        notify(src, Config.Notify.NoRoom, 'error')
        return
    end

    ActiveScooters[src] = nil
    debugPrint('Scooter picked up by', tostring(src), 'netId', tostring(netId))
    TriggerClientEvent('zrp_scooter:client:pickupSuccess', src, netId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    clearPlayerScooter(src)
end)