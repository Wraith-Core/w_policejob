-- Variables
local ObjectList = {}

-- Kneeling animation played while a lawman places or removes an object
local PLACE_ANIM <const> = {
    animDict = 'amb_work@world_human_crouch_inspect@male_a@idle_a',
    anim = 'idle_a',
    flags = 1,
}

-- Functions
local function GetClosestPoliceObject()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil

    for id, data in pairs(ObjectList) do
        local dist2 = #(pos - data.coords)
        if not current or dist2 < dist then
            current = id
            dist = dist2
        end
    end
    return current, dist
end

-- Events
RegisterNetEvent('police:client:spawnPObj', function(item)
    WCore.Functions.Progressbar("spawn_object", locale("progressbar.place_object"), 2500, false, true, {
        disableMovement = true,
        disableVehicleMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, PLACE_ANIM, {}, {}, function() -- Done
        ClearPedTasks(cache.ped)
        TriggerServerEvent("police:server:spawnObject", item)
    end, function() -- Cancel
        ClearPedTasks(cache.ped)
        WCore.Functions.Notify(locale("error.canceled"), 'error')
    end)
end)

RegisterNetEvent('police:client:deleteObject', function()
    local objectId, dist = GetClosestPoliceObject()
    if objectId and dist < 5.0 then
        WCore.Functions.Progressbar("remove_object", locale('progressbar.remove_object'), 2500, false, true, {
            disableMovement = true,
            disableVehicleMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, PLACE_ANIM, {}, {}, function() -- Done
            ClearPedTasks(cache.ped)
            TriggerServerEvent("police:server:deleteObject", objectId)
        end, function() -- Cancel
            ClearPedTasks(cache.ped)
            WCore.Functions.Notify(locale("error.canceled"), 'error')
        end)
    end
end)

RegisterNetEvent('police:client:removeObject', function(objectId)
    local entry = ObjectList[objectId]
    if not entry then return end
    w.entity.requestControl(entry.object, 2000)
    w.entity.delete(entry.object)
    ObjectList[objectId] = nil
end)

RegisterNetEvent('police:client:spawnObject', function(objectId, type, player)
    local placer = GetPlayerPed(GetPlayerFromServerId(player))
    local coords = GetEntityCoords(placer)
    local heading = GetEntityHeading(placer)
    local forward = GetEntityForwardVector(placer)
    local x, y, z = table.unpack(coords + forward * 0.5)
    local spawnedObj = w.entity.create(Config.Objects[type].model, vector3(x, y, z), heading, true)
    if not spawnedObj then return end
    PlaceObjectOnGroundProperly(spawnedObj)
    FreezeEntityPosition(spawnedObj, Config.Objects[type].freeze)
    ObjectList[objectId] = {
        id = objectId,
        object = spawnedObj,
        coords = vector3(x, y, z - 0.3),
    }
end)
