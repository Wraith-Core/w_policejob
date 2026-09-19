-- Variables
local isEscorting = false
-- cuffType (client/main.lua) states
CUFF_NONE = 'none'
CUFF_HARD = 'hard'
CUFF_SOFT = 'soft'

-- the hands-up loop played by the w_smallresources keybind
local HANDS_UP_DICT <const> = 'script_proc@robberies@homestead@lonnies_shack@deception'
local HANDS_UP_ANIM <const> = 'hands_up_loop'

-- Functions
exports('IsHandcuffed', function()
    return isHandcuffed
end)

---Closest other player within `maxDistance` metres (nil when nobody is there).
---@param maxDistance? number
---@return integer? playerId, integer? playerPed
local function NearestPlayer(maxDistance)
    local playerId, playerPed = w.getClosestPlayer(GetEntityCoords(cache.ped), maxDistance or 2.5, false)
    return playerId, playerPed
end

---Ask for a positive number through the library dialog; nil when cancelled or invalid.
---@param heading string
---@param label string
---@return number?
local function AskNumber(heading, label)
    local input = w.inputDialog(heading, {
        { type = 'number', label = label, required = true, min = 1 },
    })
    if not input then return nil end
    return tonumber(input[1])
end

---@param ped integer
---@return boolean
local function HasHandsUp(ped)
    return IsEntityPlayingAnim(ped, HANDS_UP_DICT, HANDS_UP_ANIM, 3)
end

-- ── actions on a player ──────────────────────────────────────────────────────────────
-- Shared by the prompt card (client index of the followed player) and the chat commands /
-- item use (closest player). Every one of them notifies when nobody is there.

---@param player integer? client player index
---@param playerPed integer?
---@param soft boolean soft cuff lets the suspect walk
local function CuffTarget(player, playerPed, soft)
    if IsPedRagdoll(cache.ped) then return end
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    if not soft and not WCore.Functions.HasItem(Config.HandCuffItem) then
        WCore.Functions.Notify(locale("error.no_cuff"), 'error')
        return
    end
    if IsPedInAnyVehicle(playerPed, false) or IsPedInAnyVehicle(cache.ped, false) then
        WCore.Functions.Notify(locale("error.vehicle_cuff"), 'error')
        return
    end
    TriggerServerEvent("police:server:CuffPlayer", GetPlayerServerId(player), soft)
end

---@param player integer?
local function SearchTarget(player)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    local playerId = GetPlayerServerId(player)
    TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", playerId)
    TriggerServerEvent("police:server:SearchPlayer", playerId)
end

---@param player integer?
local function SeizeCashTarget(player)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    TriggerServerEvent("police:server:SeizeCash", GetPlayerServerId(player))
end

---Rob a person who keeps his hands up (anybody, not only lawmen).
---@param player integer?
---@param playerPed integer?
local function RobTarget(player, playerPed)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    if not HasHandsUp(playerPed) then return end
    local playerId = GetPlayerServerId(player)
    WCore.Functions.Progressbar("robbing_player", locale("progressbar.robbing"), math.random(5000, 7000), false, true, {
        disableMovement = true,
        disableVehicleMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        if #(GetEntityCoords(cache.ped) - GetEntityCoords(playerPed)) < 2.5 then
            TriggerServerEvent("inventory:server:OpenInventory", "otherplayer", playerId)
            TriggerServerEvent("police:server:RobPlayer", playerId)
        else
            WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        end
    end, function() -- Cancel
        WCore.Functions.Notify(locale("error.canceled"), 'error')
    end)
end

---@param player integer?
local function JailTarget(player)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    local playerId = GetPlayerServerId(player)
    local time = AskNumber(locale('info.jail_time_input'), locale('info.time_months'))
    if time and time > 0 then
        TriggerServerEvent("police:server:JailPlayer", playerId, time)
    else
        WCore.Functions.Notify(locale("error.time_higher"), 'error')
    end
end

---@param player integer?
local function BillTarget(player)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    local playerId = GetPlayerServerId(player)
    local price = AskNumber(locale('info.bill'), locale('info.amount'))
    if price and price > 0 then
        TriggerServerEvent("police:server:BillPlayer", playerId, price)
    else
        WCore.Functions.Notify(locale("error.amount_higher"), 'error')
    end
end

---Seat the (cuffed / downed) person in the nearest wagon, or pull him out of the one he sits in.
---@param player integer?
---@param playerPed integer?
local function WagonTarget(player, playerPed)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    if isHandcuffed or isEscorted then return end
    if IsPedInAnyVehicle(playerPed, false) then
        TriggerServerEvent("police:server:SetPlayerOutVehicle", GetPlayerServerId(player))
    else
        TriggerServerEvent("police:server:PutPlayerInVehicle", GetPlayerServerId(player))
    end
end

---@param player integer?
local function EscortTarget(player)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    if isHandcuffed or isEscorted then return end
    TriggerServerEvent("police:server:EscortPlayer", GetPlayerServerId(player))
end

---Carry a cuffed / downed person on the shoulder.
---@param player integer?
---@param playerPed integer?
local function CarryTarget(player, playerPed)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    if isHandcuffed or isEscorted or IsPedInAnyVehicle(playerPed, false) then return end
    TriggerServerEvent("police:server:KidnapPlayer", GetPlayerServerId(player))
end

-- ── the card on the closest player ───────────────────────────────────────────────────
-- One library prompt card follows the closest other player. A lawman on duty gets the law
-- actions; everybody else gets the civilian ones (rob a person with his hands up, escort or
-- carry a cuffed / downed person). Labels and rows follow the target's replicated state.

local TARGET_SCAN <const> = 3.0     -- metres: look for the closest player this far
local TARGET_REACH <const> = 2.0    -- metres: the card shows this close

local Target = nil   -- { id, ped, serverId, lawman, rec, labels = {}, visible = {} }

---@param t table
---@return { cuffed: boolean, escorted: boolean, down: boolean, handsUp: boolean, inWagon: boolean }
local function TargetState(t)
    local state = Player(t.serverId).state
    return {
        cuffed = state.isHandcuffed == true,
        escorted = state.isEscorted == true,
        down = IsEntityDead(t.ped) or state.isDead == true,
        handsUp = HasHandsUp(t.ped),
        inWagon = IsPedInAnyVehicle(t.ped, false),
    }
end

---The player himself must be free to act, with nothing else owning the screen.
local function CanAct()
    if isHandcuffed or isEscorted or IsEntityDead(cache.ped) or IsPedRagdoll(cache.ped) then return false end
    return ScreenIsFree()
end

local function LawmanPrompts()
    local K = Config.Keys
    return {
        { key = K.search, label = locale('prompt.search'), onComplete = function() SearchTarget(Target.id) end },
        { key = K.cuff, label = locale('prompt.cuff'), hold = 1200, onComplete = function() CuffTarget(Target.id, Target.ped, false) end },
        { key = K.escort, label = locale('prompt.escort'), onComplete = function() EscortTarget(Target.id) end },
        { key = K.wagon, label = locale('prompt.put_in_wagon'), onComplete = function() WagonTarget(Target.id, Target.ped) end },
        { key = K.jail, label = locale('prompt.jail'), hold = 1500, onComplete = function() JailTarget(Target.id) end },
        { key = K.fine, label = locale('prompt.fine'), onComplete = function() BillTarget(Target.id) end },
        { key = K.seize, label = locale('prompt.seize_cash'), hold = 1500, onComplete = function() SeizeCashTarget(Target.id) end },
        { key = K.status, label = locale('prompt.check_status'), onComplete = function() CheckStatusOf(Target.id) end },
    }
end

local function CivilianPrompts()
    local K = Config.Keys
    return {
        { key = K.rob, label = locale('prompt.rob'), hold = 1500, onComplete = function() RobTarget(Target.id, Target.ped) end },
        { key = K.escort, label = locale('prompt.escort'), onComplete = function() EscortTarget(Target.id) end },
        { key = K.carry, label = locale('prompt.carry'), onComplete = function() CarryTarget(Target.id, Target.ped) end },
    }
end

---Label / row visibility of the card for the target's current state.
---@return table<string, string> labels key → dictionary key, table<string, boolean> visible
local function CardState(t)
    local K = Config.Keys
    local s = TargetState(t)
    local labels, visible = {}, {}
    if t.lawman then
        labels[K.cuff] = s.cuffed and 'prompt.uncuff' or 'prompt.cuff'
        labels[K.escort] = s.escorted and 'prompt.release' or 'prompt.escort'
        labels[K.wagon] = s.inWagon and 'prompt.out_of_wagon' or 'prompt.put_in_wagon'
    else
        local helpless = s.cuffed or s.down
        labels[K.escort] = s.escorted and 'prompt.release' or 'prompt.escort'
        visible[K.rob] = s.handsUp
        visible[K.escort] = helpless
        visible[K.carry] = helpless and not s.inWagon
    end
    return labels, visible
end

local function DropTarget()
    if not Target then return end
    Target.rec.remove()
    Target = nil
end

local function BuildTarget(id, ped, lawman)
    local t = { id = id, ped = ped, serverId = GetPlayerServerId(id), lawman = lawman, labels = {}, visible = {} }
    t.rec = w.prompt.atEntity(ped, {
        distance = TARGET_REACH,
        title = lawman and locale('prompt.suspect') or false,
        prompts = lawman and LawmanPrompts() or CivilianPrompts(),
        canInteract = function()
            if not CanAct() then return false end
            if lawman then return true end
            -- the civilian card only has something to offer for a helpless person
            for _, shown in pairs(t.visible) do
                if shown then return true end
            end
            return false
        end,
    })
    TrackCard(t.rec, CARD_PLAYER)
    Target = t
end

---Push labels / rows that changed since the last refresh.
local function RefreshTarget(force)
    local t = Target
    local labels, visible = CardState(t)
    for key, label in pairs(labels) do
        if force or t.labels[key] ~= label then
            t.labels[key] = label
            t.rec.setLabel(key, locale(label))
        end
    end
    for key, shown in pairs(visible) do
        if force or t.visible[key] ~= shown then
            t.visible[key] = shown
            t.rec.setVisible(key, shown)
        end
    end
end

---Language switch (client/main.lua): relabel the card that is up.
function RefreshPlayerPrompt()
    if not Target then return end
    local t = Target
    if t.lawman then t.rec.setTitle(locale('prompt.suspect')) end
    local prompts = t.lawman and LawmanPrompts() or CivilianPrompts()
    for _, p in ipairs(prompts) do
        t.rec.setLabel(p.key, p.label)
    end
    RefreshTarget(true)
end

-- Doctors get their own card on the closest player from w_ambulancejob (check / treat / revive);
-- two resources cannot share one screen, so they keep escort / carry on the /escort command.
local function WantsPlayerCard()
    return LocalPlayer.state.isLoggedIn and PlayerJob.name ~= 'ambulance'
end

CreateThread(function()
    while true do
        Wait(250)
        if WantsPlayerCard() then
            local lawman = PlayerJob.name == 'police' and onDuty == true
            local id, ped = NearestPlayer(TARGET_SCAN)
            if Target and (Target.ped ~= ped or Target.lawman ~= lawman) then
                DropTarget()
            end
            if ped and not Target then
                BuildTarget(id, ped, lawman)
                RefreshTarget(true)
            elseif Target then
                RefreshTarget(false)
            end
        elseif Target then
            DropTarget()
        end
    end
end)

-- Events
-- Wagons: a cuffed or escorted player is seated in / pulled out of the nearest wagon
RegisterNetEvent('police:client:SetOutVehicle', function()
    local ped = cache.ped
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 16, 0)
    end
end)

RegisterNetEvent('police:client:PutInVehicle', function()
    local ped = cache.ped
    if isHandcuffed or isEscorted then
        local vehicle = w.getClosestVehicle(GetEntityCoords(ped), 6.0, false)
        if vehicle and DoesEntityExist(vehicle) then
            for i = GetVehicleMaxNumberOfPassengers(vehicle) - 1, 0, -1 do
                if IsVehicleSeatFree(vehicle, i) then
                    SetEscorted(false)
                    TriggerEvent('hospital:client:isEscorted', isEscorted)
                    ClearPedTasks(ped)
                    DetachEntity(ped, true, false)

                    Wait(100)
                    SetPedIntoVehicle(ped, vehicle, i)
                    return
                end
            end
        end
    end
end)

-- The command / item paths act on the closest player, like the card does on the followed one.
RegisterNetEvent('police:client:SearchPlayer', function()
    SearchTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:SeizeCash', function()
    SeizeCashTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:RobPlayer', function()
    RobTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:JailCommand', function(playerId, time)
    TriggerServerEvent("police:server:JailPlayer", playerId, tonumber(time))
end)

RegisterNetEvent('police:client:BillCommand', function(playerId, price)
    TriggerServerEvent("police:server:BillPlayer", playerId, tonumber(price))
end)

RegisterNetEvent('police:client:JailPlayer', function()
    JailTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:BillPlayer', function()
    BillTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:PutPlayerInVehicle', function()
    local player, playerPed = NearestPlayer(2.5)
    if player and IsPedInAnyVehicle(playerPed, false) then return end
    WagonTarget(player, playerPed)
end)

RegisterNetEvent('police:client:SetPlayerOutVehicle', function()
    local player, playerPed = NearestPlayer(2.5)
    if player and not IsPedInAnyVehicle(playerPed, false) then return end
    WagonTarget(player, playerPed)
end)

RegisterNetEvent('police:client:EscortPlayer', function()
    EscortTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:KidnapPlayer', function()
    CarryTarget(NearestPlayer(2.5))
end)

RegisterNetEvent('police:client:CuffPlayerSoft', function()
    local player, playerPed = NearestPlayer(1.5)
    CuffTarget(player, playerPed, true)
end)

RegisterNetEvent('police:client:CuffPlayer', function()
    local player, playerPed = NearestPlayer(1.5)
    CuffTarget(player, playerPed, false)
end)

RegisterNetEvent('police:client:GetEscorted', function(playerId)
    local ped = cache.ped
    WCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["isdead"] or isHandcuffed or PlayerData.metadata["inlaststand"] then
            if not isEscorted then
                SetEscorted(true)
                draggerId = playerId
                local dragger = GetPlayerPed(GetPlayerFromServerId(playerId))
                local bone = GetEntityBoneIndexByName(dragger, 'SKEL_Pelvis')
                if bone == -1 then bone = 0 end
                SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(dragger, 0.0, 0.45, 0.0))
                AttachEntityToEntity(ped, dragger, bone, 0.45, 0.45, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            else
                SetEscorted(false)
                DetachEntity(ped, true, false)
            end
            TriggerEvent('hospital:client:isEscorted', isEscorted)
        end
    end)
end)

RegisterNetEvent('police:client:DeEscort', function()
    SetEscorted(false)
    TriggerEvent('hospital:client:isEscorted', isEscorted)
    DetachEntity(cache.ped, true, false)
end)

RegisterNetEvent('police:client:GetKidnappedTarget', function(playerId)
    local ped = cache.ped
    WCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["isdead"] or PlayerData.metadata["inlaststand"] or isHandcuffed then
            if not isEscorted then
                SetEscorted(true)
                draggerId = playerId
                local dragger = GetPlayerPed(GetPlayerFromServerId(playerId))
                AttachEntityToEntity(ped, dragger, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
            else
                SetEscorted(false)
                DetachEntity(ped, true, false)
                ClearPedTasksImmediately(ped)
            end
            TriggerEvent('hospital:client:isEscorted', isEscorted)
        end
    end)
end)

RegisterNetEvent('police:client:GetKidnappedDragger', function(playerId)
    WCore.Functions.GetPlayerData(function()
        if not isEscorting then
            draggerId = playerId
            isEscorting = true
        else
            local dragger = cache.ped
            ClearPedSecondaryTask(dragger)
            ClearPedTasksImmediately(dragger)
            isEscorting = false
        end
        TriggerEvent('hospital:client:SetEscortingState', isEscorting)
    end)
end)

RegisterNetEvent('police:client:GetCuffed', function(playerId, isSoftcuff)
    local ped = cache.ped
    if not isHandcuffed then
        SetHandcuffed(true)
        TriggerServerEvent("police:server:SetHandcuffStatus", true)
        ClearPedTasksImmediately(ped)
        -- _GET_PED_CURRENT_HELD_WEAPON: holster whatever the suspect is holding
        if Citizen.InvokeNative(0x8425C5F057012DAB, ped) ~= `WEAPON_UNARMED` then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
        if not isSoftcuff then
            cuffType = CUFF_HARD
            WCore.Functions.Notify(locale("info.cuff"), 'inform')
        else
            cuffType = CUFF_SOFT
            WCore.Functions.Notify(locale("info.cuffed_walk"), 'inform')
        end
    else
        SetHandcuffed(false)
        SetEscorted(false)
        TriggerEvent('hospital:client:isEscorted', isEscorted)
        DetachEntity(ped, true, false)
        TriggerServerEvent("police:server:SetHandcuffStatus", false)
        ClearPedTasksImmediately(ped)
        SetEnableHandcuffs(ped, false, false)
        DisablePlayerFiring(cache.playerId, false)
        SetPedCanPlayGestureAnims(ped, true)
        w.setRadarVisible(true)
        FreezeEntityPosition(ped, false)
        cuffType = CUFF_NONE
        WCore.Functions.Notify(locale("success.uncuffed"), 'success')
    end
end)

-- Threads
CreateThread(function()
    while true do
        Wait(1)
        local ped = cache.ped
        if isEscorted or isHandcuffed then
            DisableControlAction(0, 0x295175BF, true) -- Disable break
            DisableControlAction(0, 0x6E9734E8, true) -- Disable suicide
            DisableControlAction(0, 0xD8F73058, true) -- Disable aiminair
            DisableControlAction(0, 0x4CC0E2FE, true) -- B key
            DisableControlAction(0, 0xDE794E3E, true) -- Cover
            DisableControlAction(0, 0x06052D11, true) -- Cover
            DisableControlAction(0, 0x5966D52A, true) -- Cover
            DisableControlAction(0, 0xCEFD9220, true) -- Cover
            DisableControlAction(0, 0xC75C27B0, true) -- Cover
            DisableControlAction(0, 0x41AC83D1, true) -- Cover
            DisableControlAction(0, 0xADEAF48C, true) -- Cover
            DisableControlAction(0, 0x9D2AEA88, true) -- Cover
            DisableControlAction(0, 0xE474F150, true) -- Cover
            DisableControlAction(0, 0xB2F377E8, true) -- Attack
            DisableControlAction(0, 0xC1989F95, true) -- Attack 2
            DisableControlAction(0, 0x07CE1E61, true) -- Melee Attack 1
            DisableControlAction(0, 0xF84FA74F, true) -- MOUSE2
            DisableControlAction(0, 0xCEE12B50, true) -- MOUSE3
            DisableControlAction(0, 0x8FFC75D6, true) -- Shift
            DisableControlAction(0, 0xD9D0E1C0, true) -- SPACE
            DisableControlAction(0, 0xF3830D8E, true) -- J
            DisableControlAction(0, 0x80F28E95, true) -- L
            DisableControlAction(0, 0xDB096B85, true) -- CTRL
            DisableControlAction(0, 0xE30CD707, true) -- R
        end

        if isHandcuffed and cuffType ~= CUFF_NONE then
            SetEnableHandcuffs(ped, true, false)
            DisablePlayerFiring(cache.playerId, true)
            SetPedCanPlayGestureAnims(ped, false)
            DisplayRadar(false)
            if cuffType == CUFF_HARD then
                -- hard cuff: the suspect stays where he is (unless he is escorted or seated in a
                -- wagon); soft cuff lets him walk
                FreezeEntityPosition(ped, not isEscorted and not IsPedInAnyVehicle(ped, false))
            end
        end

        if not isHandcuffed and not isEscorted then
            Wait(2000)
        end
    end
end)

-- The resource stops: the card following the closest player goes with it.
w.stopped(DropTarget)
