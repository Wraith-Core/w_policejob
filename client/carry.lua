-- The patient owns their ped. Keep one direct attachment as the carrier mounts or dismounts.
PoliceCarryTarget = {}
local target = PoliceCarryTarget
local current, lastSession = nil, 0

-- carryconfigdata.meta: the two human carried-by-mount data sets both use the rear slot.
local mountInjured = { bone = 'SKEL_RearSeat', dict = 'mech_carry_ped@injured@carried@mount', carried = 'carriedbymount_exp' }
local mountDead = { bone = 'PH_Carriable' }

local function yes(value) return value == true or value == 1 end

local function exists(entity)
    return entity and entity ~= 0 and yes(DoesEntityExist(entity))
end

local function carrierParent(peer)
    local player = GetPlayerFromServerId(peer)
    if not player or player < 0 or player == PlayerId() or not yes(NetworkIsPlayerActive(player)) then return end
    local rider = GetPlayerPed(player)
    if not exists(rider) or yes(IsEntityDead(rider)) then return end
    if yes(IsPedOnMount(rider)) then
        local horse = GetMount(rider)
        if exists(horse) then return horse, true end
        return
    end
    return rider, false
end

local function detach(s)
    if exists(s.ped) then
        if exists(s.parent) and yes(IsEntityAttachedToEntity(s.ped, s.parent)) then
            DetachEntity(s.ped, true, true)
        end
        if s.animation and not yes(IsEntityDead(s.ped)) then
            StopAnimTask(s.ped, s.animation.dict, s.animation.carried, -4.0)
        end
    end
    s.animation, s.parent = nil, nil
end

local function finish(s, place)
    -- A normal unload can repair a dead ped still reporting its pickup position. Only use
    -- the same patient's last observed carrier, streamed nearby throughout the trip.
    local drop
    if place and s.parent and exists(s.ped) and s.ped == PlayerPedId() and not s.missingSince then
        local parent, mounted = carrierParent(s.peer)
        local dead = yes(IsEntityDead(s.ped))
        if parent and (dead or (isHandcuffed and not s.dead)) then
            local at, beside = GetEntityCoords(s.ped), GetEntityCoords(parent)
            if #(beside - s.lastPosition) <= 12.0 and (dead or #(at - beside) <= 4.0) then
                -- Keep a living suspect's on-foot position. Ground only his height after detaching.
                drop = not dead and not mounted and at
                    or GetOffsetFromEntityInWorldCoords(parent, mounted and 1.5 or 0.9, 0.0, 0.0)
            end
        end
    end
    current = nil
    detach(s)
    if drop then
        local found, ground = GetGroundZFor_3dCoord(drop.x, drop.y, drop.z + 2.0, false)
        local z = yes(found) and math.abs(ground - drop.z) <= 3.0 and ground + 0.1 or drop.z
        SetEntityCoordsNoOffset(s.ped, drop.x, drop.y, z, false, false, false)
    end
    if s.ped then
        SetEscorted(false)
        TriggerEvent('hospital:client:isEscorted', false)
    end
end

function target.cancel()
    if not current then return false end
    local session = current.id
    finish(current, false)
    TriggerServerEvent(PoliceCarryEvents.release, session, false)
    return true
end

local function attach(s, ped, parent, mounted, profile)
    local bone = GetEntityBoneIndexByName(parent, profile.bone)
    if bone and bone >= 0 then
        AttachEntityToEntity(ped, parent, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            false, false, false, false, 0, true, false, false)
    elseif mounted then
        -- A custom horse may have neither rear-slot bone. Ride behind the saddle in root space.
        AttachEntityToEntity(ped, parent, 0, 0.0, -0.65, 0.5, 0.0, 0.0, 0.0,
            false, false, false, false, 2, true, false, false)
    else
        AttachEntityToEntity(ped, parent, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 0.0,
            false, false, false, false, 2, false)
    end
    s.ped, s.parent = ped, parent
end

function target.tick()
    local s = current
    if not s then return end
    local now, ped = GetGameTimer(), PlayerPedId()
    local parent, mounted = carrierParent(s.peer)
    if not parent or not exists(ped) then
        s.missingSince = s.missingSince or now
        if now - s.missingSince >= 3000 then target.cancel() end
        return
    end
    local dead = yes(IsEntityDead(ped))
    local position = GetEntityCoords(parent)
    local distance = #(GetEntityCoords(ped) - position)
    if (not dead and (s.dead or not isHandcuffed)) or (not s.ped and isEscorted)
        or (distance > 8.0 and (not dead or s.ped ~= ped or not s.lastPosition
            or #(position - s.lastPosition) > 12.0)) then
        target.cancel()
        return
    end
    s.lastPosition, s.missingSince = position, nil
    local profile = mounted and (dead and mountDead or mountInjured) or PoliceCarryFoot
    local changed = ped ~= s.ped or parent ~= s.parent or dead ~= s.dead
    local attached = yes(IsEntityAttachedToEntity(ped, parent))
    -- A dead ped can remain at the pickup point even while its attachment is reported.
    -- Repair it only while the authorized carrier is continuously in scope.
    local pinned = dead and distance > 4.0 and s.ped == ped
    if changed or not attached or pinned then
        if not s.ped then
            SetEscorted(true)
            TriggerEvent('hospital:client:isEscorted', true)
        end
        detach(s)
        if isHandcuffed then
            if cuffType == CUFF_HARD then FreezeEntityPosition(ped, false) end
            if not dead then SetEnableHandcuffs(ped, false, false) end
        end
        if pinned then SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false) end
        attach(s, ped, parent, mounted, profile)
    end
    s.dead = dead
    -- Dead players stay in ragdoll. A living cuffed player keeps the authored pose, and
    -- dictionary streaming never blocks a removal or replays a pose after the session ends.
    if not dead and not yes(IsEntityPlayingAnim(ped, profile.dict, profile.carried, 3)) then
        if yes(HasAnimDictLoaded(profile.dict)) then
            TaskPlayAnim(ped, profile.dict, profile.carried, 8.0, -8.0, -1, 1, 0.0, false, false, false)
            s.animation = profile
        else
            RequestAnimDict(profile.dict)
        end
    end
end

function target.start(peer, id)
    if type(peer) ~= 'number' or peer % 1 ~= 0 or peer <= 0
        or type(id) ~= 'number' or id % 1 ~= 0 or id <= lastSession then
        return false
    end
    if current then finish(current, false) end
    lastSession = id
    local s = { peer = peer, id = id }
    current = s
    if isEscorted then
        target.cancel()
        return false
    end
    target.tick()
    if current ~= s then return false end
    CreateThread(function()
        while current == s do
            Wait(150)
            if current == s then target.tick() end
        end
    end)
    return true
end

function target.stop(peer, id, placeAtCarrier)
    if type(id) ~= 'number' or id % 1 ~= 0 or id <= 0 then return false end
    lastSession = math.max(lastSession, id)
    if not current or current.peer ~= peer or current.id ~= id then return false end
    finish(current, placeAtCarrier == true)
    return true
end

function target.active() return current ~= nil end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and current then finish(current, false) end
end)
