-- Variables
isHandcuffed = false
cuffType = 'none' -- CUFF_NONE / CUFF_HARD / CUFF_SOFT (client/interactions.lua)
isEscorted = false
draggerId = 0
PlayerJob = {}
onDuty = false
local DutyBlips = {}

-- Functions
---Cuff flag: the local state plus a replicated state bag, so the other clients can label the
---prompt card that follows this player (cuff / uncuff).
---@param state boolean
function SetHandcuffed(state)
    isHandcuffed = state
    LocalPlayer.state:set('isHandcuffed', state, true)
end

---Escort flag, replicated the same way (escort / release).
---@param state boolean
function SetEscorted(state)
    isEscorted = state
    LocalPlayer.state:set('isEscorted', state, true)
end

local function RemoveDutyBlips()
    for _, blip in pairs(DutyBlips) do
        RemoveBlip(blip)
    end
    DutyBlips = {}
end

local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local pos = vector3(playerLocation.x, playerLocation.y, playerLocation.z)
    playerLabel = tostring(playerLabel or playerJob or '')
    local blip
    -- playerId is -1 when the lawman is not streamed in: pin the last known location instead
    if playerId ~= -1 and NetworkIsPlayerActive(playerId) then
        local ped = GetPlayerPed(playerId)
        -- another resource already marks that ped: leave it alone (as before)
        if DoesBlipExist(GetBlipFromEntity(ped)) then return end
        blip = w.blip.create(ped, playerLabel, 54149631, nil, nil, 0.7)
    end
    if not blip then
        blip = w.blip.create(pos, playerLabel, 54149631, nil, nil, 0.7)
    end
    DutyBlips[#DutyBlips + 1] = blip
end

---Resolve an alert payload: a plain string, or { key, args } translated in the viewer's language.
---@param text string | { key: string, args?: table }
---@return string
function ResolveAlertText(text)
    if type(text) == 'table' then
        return locale(text.key, table.unpack(text.args or {}))
    end
    return tostring(text)
end

-- Resource (re)start while the player is already in: OnPlayerLoaded will not fire again,
-- so pick up the current job here (client/job.lua builds the prompts from it).
if LocalPlayer.state.isLoggedIn then
    local player = WCore.Functions.GetPlayerData()
    if player and player.job then
        PlayerJob = player.job
        onDuty = player.job.onduty or false
    end
end

-- Events
AddEventHandler('WCore:Client:OnPlayerLoaded', function()
    local player = WCore.Functions.GetPlayerData() or {}
    PlayerJob = player.job or {}
    onDuty = PlayerJob.onduty or false
    SetHandcuffed(false)
    SetEscorted(false)
    -- the server clears its own cuff flag when the character loads (server/main.lua); w_core no
    -- longer takes a client's word on it (WCore:Server:SetMetaData), and this report is a no-op
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    TriggerServerEvent("police:server:UpdateCurrentCops")

    if PlayerJob and PlayerJob.name ~= "police" then
        RemoveDutyBlips()
    end

    if PlayerJob and PlayerJob.name == 'police' then
        CreatePrompts()
    end
end)

RegisterNetEvent('WCore:Client:OnPlayerUnload', function()
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    TriggerServerEvent("police:server:UpdateCurrentCops")
    SetHandcuffed(false)
    SetEscorted(false)
    onDuty = false
    ClearPedTasks(cache.ped)
    DetachEntity(cache.ped, true, false)
    RemoveDutyBlips()
    RemovePrompts()
end)

RegisterNetEvent('WCore:Client:OnJobUpdate', function(JobInfo)
    local becomesLawman = JobInfo.name == "police" and PlayerJob.name ~= "police"
    if becomesLawman then
        CreatePrompts()
    end

    if JobInfo.name ~= "police" then
        RemoveDutyBlips()
        RemovePrompts()
    end
    PlayerJob = JobInfo
    onDuty = JobInfo.onduty == true
    -- a new lawman starts off duty (he signs in at the station). 2026-11-12: this used to set onDuty = false
    -- BEFORE the line above put it back to true, so the client said on duty while the server was off, and every
    -- station toggle after that was inverted. The server's answer (WCore:Client:SetDuty) sets it now.
    if becomesLawman and onDuty then
        onDuty = false
        TriggerServerEvent("WCore:ToggleDuty")
    end
end)

-- The server's duty (w_core server/events.lua, after WCore:ToggleDuty): the one source of onDuty.
RegisterNetEvent('WCore:Client:SetDuty', function(duty)
    onDuty = duty == true
    if PlayerJob then PlayerJob.onduty = onDuty end
    TriggerServerEvent("police:server:UpdateCurrentCops")
end)

-- Server-side notices arrive as dictionary keys + format args and are translated here,
-- so every player reads them in his own language.
RegisterNetEvent('police:client:notify', function(key, style, ...)
    WCore.Functions.Notify(locale(key, ...), style or 'inform')
end)

RegisterNetEvent('police:client:UpdateBlips', function(players)
    if Config.ShowBlips then
        if PlayerJob and (PlayerJob.name == 'police' or PlayerJob.name == 'doctor') and onDuty then
            RemoveDutyBlips()
            if players then
                for _, data in pairs(players) do
                    if data.source ~= cache.serverId then -- never a blip on ourselves
                        CreateDutyBlips(GetPlayerFromServerId(data.source), data.label, data.job, data.location)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    text = ResolveAlertText(text)
    WCore.Functions.Notify({ text = locale('info.new_call'), caption = text }, 'law')
    local blipText = locale('info.blip_text', text)
    local pos = vector3(coords.x, coords.y, coords.z)
    local blip = w.blip.create(pos, blipText, -693644997, nil, 'BLIP_MODIFIER_AREA_PULSE', 0.8)
    local area = w.blip.create(pos, blipText, -184692826, nil, 'BLIP_MODIFIER_AREA_PULSE', 2.0)
    -- the alert stays on the map for three minutes
    Wait(180000)
    RemoveBlip(blip)
    RemoveBlip(area)
end)

RegisterNetEvent('police:client:SendToJail', function(time)
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    SetHandcuffed(false)
    SetEscorted(false)
    ClearPedTasks(cache.ped)
    DetachEntity(cache.ped, true, false)
    TriggerEvent("prison:client:Enter", time)
end)

RegisterNetEvent('police:client:SendPoliceEmergencyAlert', function()
    local Player = WCore.Functions.GetPlayerData()
    -- both slots filled: a nil inside the array would be dropped by msgpack and break the format
    local args = { tostring(Player.charinfo.lastname or '-'), tostring(Player.metadata.callsign or '-') }
    -- lawmen translate the key themselves; the ambulance alert takes a plain string
    TriggerServerEvent('police:server:policeAlert', { key = 'info.officer_down', args = args })
    TriggerServerEvent('hospital:server:ambulanceAlert', locale('info.officer_down', table.unpack(args)))
end)

-- Live language switch: reload the dictionary, then rebuild what was built with the old texts.
AddEventHandler('w_lib:setLocale', function(key)
    w.locale(key)
    RefreshPrompts()
    RefreshPlayerPrompt()
    CreateStationBlips()
    RefreshEvidencePrompts()
end)
