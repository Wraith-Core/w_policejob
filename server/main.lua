local function economyReady()
    return GetResourceState('w_centralbank') == 'started' and exports.w_centralbank:IsReady()
end
local function closePlayers(a, b)
    if not a or not b then return false end
    local x, y = a.PlayerData.source, b.PlayerData.source
    local px, py = GetPlayerPed(x), GetPlayerPed(y)
    return px ~= 0 and py ~= 0 and GetPlayerRoutingBucket(x) == GetPlayerRoutingBucket(y)
        and #(GetEntityCoords(px) - GetEntityCoords(py)) <= 5.0
end
local function cashAccount(player)
    return 'player:' .. player.PlayerData.citizenid .. ':cash'
end
-- Variables
local PlayerStatus = {}
local Casings = {}
local BloodDrops = {}
local FingerDrops = {}
local Objects = {}

-- Functions
local function UpdateBlips()
    local dutyPlayers = {}
    local players = WCore.Functions.GetWPlayers()
    for _, v in pairs(players) do
        if v and (v.PlayerData.job.name == "police" or v.PlayerData.job.name == "doctor") and v.PlayerData.job.onduty then
            local coords = GetEntityCoords(GetPlayerPed(v.PlayerData.source))
            local heading = GetEntityHeading(GetPlayerPed(v.PlayerData.source))
            dutyPlayers[#dutyPlayers+1] = {
                source = v.PlayerData.source,
                label = v.PlayerData.metadata["callsign"],
                job = v.PlayerData.job.name,
                location = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    w = heading
                }
            }
        end
    end
    TriggerClientEvent("police:client:UpdateBlips", -1, dutyPlayers)
end

local function CreateBloodId()
    if BloodDrops then
        local bloodId = math.random(10000, 99999)
        while BloodDrops[bloodId] do
            bloodId = math.random(10000, 99999)
        end
        return bloodId
    else
        local bloodId = math.random(10000, 99999)
        return bloodId
    end
end

local function CreateFingerId()
    if FingerDrops then
        local fingerId = math.random(10000, 99999)
        while FingerDrops[fingerId] do
            fingerId = math.random(10000, 99999)
        end
        return fingerId
    else
        local fingerId = math.random(10000, 99999)
        return fingerId
    end
end

local function CreateCasingId()
    if Casings then
        local caseId = math.random(10000, 99999)
        while Casings[caseId] do
            caseId = math.random(10000, 99999)
        end
        return caseId
    else
        local caseId = math.random(10000, 99999)
        return caseId
    end
end

local function CreateObjectId()
    if Objects then
        local objectId = math.random(10000, 99999)
        while Objects[objectId] do
            objectId = math.random(10000, 99999)
        end
        return objectId
    else
        local objectId = math.random(10000, 99999)
        return objectId
    end
end

local function GetCurrentCops()
    local amount = 0
    local players = WCore.Functions.GetWPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    return amount
end

local function DnaHash(s)
    local h = string.gsub(s, ".", function(c)
        return string.format("%02x", string.byte(c))
    end)
    return h
end

-- ── the citizen id ───────────────────────────────────────────────────────────
-- /jail, /unjail and /takedna name the suspect by his citizen id (players.citizenid: '12', a
-- vanity '777', an old 'OMG95204'), the one id that never changes; '#5' still means server id 5
-- on purpose. A server id changes on every connection and, since the citizen id is plain digits,
-- the two collided: "/jail 12 5" jailed whoever held server id 12, or nobody. w.citizen says who
-- the id is and whether he is in the game (then his server id comes with the answer).

--- Tell the officer why the id names nobody he can act on; `offline` (a target) names the man.
---@param src integer
---@param reason string|nil 'invalid_id' | 'not_found' | 'offline'
---@param offline table|nil
local function refuseTarget(src, reason, offline)
    local text = w.citizen.reasonText(reason, src)
    if offline then text = ('%s: %s'):format(w.citizen.label(offline), text) end
    w.notify(src, { description = text, type = 'error' })
end

--- The record a sentence leaves on the file (the day is kept below 31 as it always was).
local function jailRecord()
    local currentDate = os.date("*t")
    if currentDate.day == 31 then
        currentDate.day = 30
    end
    return { ["hasRecord"] = true, ["date"] = currentDate }
end

--- A character who is not in the game: w_core's own offline player (his saved row), the same
--- SetMetaData as in play, then saved, so what is set here is on his file when he logs in.
---@param citizenid string
---@param values table<string, any>
---@return boolean
local function setOfflineMetadata(citizenid, values)
    local ok, player = pcall(function() return WCore.Functions.GetOfflinePlayerByCitizenId(citizenid) end)
    if not ok or type(player) ~= 'table' or type(player.Functions) ~= 'table' then return false end
    -- the Functions are funcrefs into w_core: a failed call is a "could not" for the officer, not
    -- an error that leaves him with no answer
    return (pcall(function()
        for key, value in pairs(values) do player.Functions.SetMetaData(key, value) end
        player.Functions.Save()
    end))
end

--- 1.0.2: XP through w_level's activity table (w_level/config/xp_rules.lua decides the amount and the caps;
--- we only say what happened). Never yields, never throws.
local function levelXp(src, activity, ctx, key)
    if not src or GetResourceState('w_level') ~= 'started' then return end
    pcall(function() exports.w_level:Award(src, activity, ctx, key) end)
end

--- Jail a character in play: the sentence and the record on his file, then his client drops the
--- cuffs and escort and enters the prison.
---@param src integer the officer
---@param OtherPlayer table the suspect's core player
---@param time number months
local function jailInPlay(src, OtherPlayer, time)
    -- any finite number used to pass (1e300 months): a sentence has a ceiling now
    time = math.min(tonumber(time) or 0, tonumber(Config.Prison and Config.Prison.maxMonths) or 120)
    if time <= 0 then return end
    -- 1.0.2: the level counts a fresh sentence only (a re-jail rewrites the time, it is not a new arrest)
    local before = tonumber((OtherPlayer.PlayerData.metadata or {}).injail) or 0
    OtherPlayer.Functions.SetMetaData("injail", time)
    OtherPlayer.Functions.SetMetaData("criminalrecord", jailRecord())
    -- his client drops the cuffs on SendToJail; the server clears its own flag (see SetHandcuffStatus)
    OtherPlayer.Functions.SetMetaData("ishandcuffed", false)
    TriggerClientEvent("police:client:SendToJail", OtherPlayer.PlayerData.source, time)
    TriggerClientEvent('police:client:notify', src, 'info.sent_jail_for', 'inform', time)
    -- 1.0.2: the level (w_level's table): the officer for the arrest (the same man counts once in a while),
    -- the convict loses some by the length of the sentence. Never for jailing oneself.
    local suspect = OtherPlayer.PlayerData.source
    if before <= 0 and suspect ~= src then
        local key = ('jail:%s:%d'):format(tostring(OtherPlayer.PlayerData.citizenid), os.time())
        levelXp(src, 'police_jail', { target = suspect }, key)
        levelXp(suspect, 'jailed', { count = math.floor(time) }, key)
    end
end

-- Commands
WCore.Commands.Add("pobject", locale("commands.place_object"), {{name = "type",help = locale("info.poobject_object")}}, true, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local type = tostring(args[1] or ''):lower()
    if Player.PlayerData.job.name ~= "police" or not Player.PlayerData.job.onduty then
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
        return
    end

    if type == "delete" then
        TriggerClientEvent("police:client:deleteObject", src)
        return
    end

    if Config.Objects[type] then
        TriggerClientEvent("police:client:spawnPObj", src, type)
    end

end)

WCore.Commands.Add("cuff", locale("commands.cuff_player"), {}, false, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:CuffPlayer", src)
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("escort", locale("commands.escort"), {}, false, function(source, args)
    local src = source
    TriggerClientEvent("police:client:EscortPlayer", src)
end)

WCore.Commands.Add("callsign", locale("commands.callsign"), {{name = "name", help = locale('info.callsign_name')}}, false, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    Player.Functions.SetMetaData("callsign", table.concat(args, " "))
end)

WCore.Commands.Add("clearcasings", locale("commands.clear_casign"), {}, false, function(source)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        TriggerClientEvent("evidence:client:ClearCasingsInArea", src)
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

-- The command resolves the id here and jails directly. It used to bounce the number through the
-- officer's client (police:client:JailCommand -> police:server:JailPlayer), which is now the
-- walk-up card's event only and checks that the suspect stands next to the officer.
WCore.Commands.Add("jail", locale("commands.jail_player"), {{name = "id", help = locale('info.player_id')}, {name = "time", help = locale('info.jail_time')}}, true, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        local time = tonumber(args[2])
        if not time or time ~= time or time <= 0 or time == math.huge then
            return w.notify(src, { description = 'info.jail_time_no', type = 'inform' })
        end
        time = math.min(time, tonumber(Config.Prison and Config.Prison.maxMonths) or 120)
        local target, reason = w.citizen.resolve(args[1], { self = src })
        if not target then return refuseTarget(src, reason) end
        if target.online then
            local OtherPlayer = WCore.Functions.GetPlayer(target.source)
            if not OtherPlayer then return refuseTarget(src, 'not_found') end
            return jailInPlay(src, OtherPlayer, time)
        end
        -- not in the game: the sentence and the record go on his file now, the same metadata a
        -- jail in play sets (what the MDT and a prison script read)
        if setOfflineMetadata(target.citizenid, { injail = time, criminalrecord = jailRecord() }) then
            TriggerClientEvent('police:client:notify', src, 'info.jailed_offline', 'inform', w.citizen.label(target), time)
        else
            TriggerClientEvent('police:client:notify', src, 'error.record_failed', 'error', w.citizen.label(target))
        end
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("unjail", locale("commands.unjail_player"), {{name = "id", help = locale('info.player_id')}}, true, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        local target, reason = w.citizen.resolve(args[1], { self = src })
        if not target then return refuseTarget(src, reason) end
        if target.online then
            local OtherPlayer = WCore.Functions.GetPlayer(target.source)
            if not OtherPlayer then return refuseTarget(src, 'not_found') end
            -- the sentence is cleared here: the client event only reaches a prison script, when
            -- one runs, and it used to be the whole release (fired at an unchecked number)
            OtherPlayer.Functions.SetMetaData("injail", 0)
            TriggerClientEvent("prison:client:UnjailPerson", target.source)
            TriggerClientEvent('police:client:notify', src, 'info.unjailed', 'success', w.citizen.label(target))
        elseif setOfflineMetadata(target.citizenid, { injail = 0 }) then
            TriggerClientEvent('police:client:notify', src, 'info.unjailed_offline', 'success', w.citizen.label(target))
        else
            TriggerClientEvent('police:client:notify', src, 'error.record_failed', 'error', w.citizen.label(target))
        end
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("clearblood", locale("commands.clearblood"), {}, false, function(source)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        TriggerClientEvent("evidence:client:ClearBlooddropsInArea", src)
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("seizecash", locale("commands.seizecash"), {}, false, function(source)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:SeizeCash", src)
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("sc", locale("commands.softcuff"), {}, false, function(source)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        TriggerClientEvent("police:client:CuffPlayerSoft", src)
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("takedna", locale("commands.takedna"), {{name = "id", help = locale('info.player_id')}}, true, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "police" or not Player.PlayerData.job.onduty then
        return w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
    -- a sample is taken from a man who is there: an offline character is refused by name
    local target, reason, offline = w.citizen.requireOnline(args[1], { self = src })
    if not target then return refuseTarget(src, reason, offline) end
    local OtherPlayer = WCore.Functions.GetPlayer(target.source)
    if not OtherPlayer then return refuseTarget(src, 'not_found') end
    if Player.Functions.RemoveItem("satchel", 1) then
        local info = {
            label = locale('info.dna_sample'),
            type = "dna",
            dnalabel = DnaHash(OtherPlayer.PlayerData.citizenid)
        }
        Player.Functions.AddItem("evidence_satchel", 1, false, info)
    else
        w.notify(src, { description = 'error.have_evidence_bag', type = 'error' })
    end
end)

-- Items
WCore.Functions.CreateUseableItem("handcuffs", function(source, item)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.Functions.GetItemByName(item.name) then
        TriggerClientEvent("police:client:CuffPlayerSoft", src)
    end
end)

WCore.Functions.CreateUseableItem("moneybag", function(source, item)
    local player = WCore.Functions.GetPlayer(source)
    if not player or not economyReady() then return end
    local bag = player.Functions.GetItemBySlot(item.slot)
    local info = bag and bag.info
    -- Legacy or administrator-created cash metadata is not a redeemable banknote.
    local id = type(info) == 'table' and info.economyClaim
    if not bag or bag.name ~= 'moneybag' or type(id) ~= 'string' or not id:match('^moneybag:%x+:cash$') then return end
    local amount = exports.w_centralbank:GetBalance(id)
    if not amount or amount <= 0 then return end
    if not player.Functions.RemoveItem('moneybag', 1, item.slot) then return end
    if not exports.w_centralbank:Transfer(id, cashAccount(player), amount, 'moneybag-redeemed', 'redeem:' .. id) then
        player.Functions.AddItem('moneybag', 1, item.slot, info)
    end
end)

WCore.Functions.CreateUseableItem("evidence_satchel", function(source, item)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.Functions.GetItemByName(item.name) then
        if item.info and item.info ~= "" then
            local details
            if item.info.type == 'dna' then
                details = item.info.dnalabel
            elseif item.info.type == 'casing' then
                details = ('%s - %s'):format(item.info.serie, item.info.ammolabel)
            elseif item.info.type == 'blood' then
                details = ('%s (%s)'):format(item.info.dnalabel, item.info.bloodtype)
            elseif item.info.type == 'fingerprint' then
                details = item.info.fingerprint
            end
            if details then
                w.notify(src, { title = 'info.evidence', description = 'info.evidence_readout', args = { item.info.label, details }, type = 'inform', duration = 8000 })
            end
            w.print.debug(item.info)
        end
    end
end)

-- Callbacks
WCore.Functions.CreateCallback('police:server:isPlayerDead', function(source, cb, playerId)
    local Player = WCore.Functions.GetPlayer(playerId)
    -- a player who left meanwhile is answered, not an error that leaves the caller waiting
    cb(Player and Player.PlayerData.metadata["isdead"] or false)
end)

WCore.Functions.CreateCallback('police:GetPlayerStatus', function(source, cb, playerId)
    local Player = WCore.Functions.GetPlayer(playerId)
    local statList = {}
    if Player then
        if PlayerStatus[Player.PlayerData.source] and next(PlayerStatus[Player.PlayerData.source]) then
            for k, v in pairs(PlayerStatus[Player.PlayerData.source]) do
                statList[#statList+1] = PlayerStatus[Player.PlayerData.source][k].text
            end
        end
    end
    cb(statList)
end)

WCore.Functions.CreateCallback('police:GetDutyPlayers', function(source, cb)
    local dutyPlayers = {}
    local players = WCore.Functions.GetWPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            dutyPlayers[#dutyPlayers+1] = {
                source = v.PlayerData.source,
                label = v.PlayerData.metadata["callsign"],
                job = v.PlayerData.job.name
            }
        end
    end
    cb(dutyPlayers)
end)

WCore.Functions.CreateCallback('police:GetCops', function(source, cb)
    local amount = 0
    local players = WCore.Functions.GetWPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
end)

WCore.Functions.CreateCallback('police:server:IsPoliceForcePresent', function(source, cb)
    local retval = false
    local players = WCore.Functions.GetWPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.grade.level >= 2 then
            retval = true
            break
        end
    end
    cb(retval)
end)

-- Events
-- `text` is a plain string, or { key = 'dict.key', args = { ... } } translated on every lawman's client
RegisterNetEvent('police:server:policeAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = WCore.Functions.GetWPlayers()
    for k,v in pairs(players) do
        if v.PlayerData.job.name == 'police' and v.PlayerData.job.onduty then
            TriggerClientEvent('police:client:policeAlert', v.PlayerData.source, coords, text)
        end
    end
end)

-- ── acting on the man in front of you ────────────────────────────────────────────────
-- The card on the closest player, the /cuff, /sc and /escort commands and the handcuffs item pick
-- the man on the sender's client (the closest player within 1.5-2.5 m) and send his server id.
-- A modified client can send any id: cuff a man across the map, walk him out of another routing
-- bucket, read anybody's cash. So the events below check what the server itself knows: the man is
-- in the game and is not the sender, both stand in the same routing bucket and within reach, the
-- sender has the job on duty (or the handcuffs) the action needs, and the man is cuffed or down
-- where the action needs it. The card and the commands pass every check as before; the jail, fine,
-- seizure and robbery events have their own checks (closePlayers) above and below.

--- metres between the two, measured on the server. The client picks within 2.5 m; the server's
--- positions trail the clients' a little, so it allows the same 5 m as the jail and fine checks.
local REACH = 5.0
--- metres for taking a man out of a wagon: he may sit at the far end of a long prison wagon
local WAGON_REACH = 8.0

--- On duty in one of these jobs (the job is the server's own record, not the client's word).
---@param player table core player
---@param ... string job names
---@return boolean
local function onDutyAs(player, ...)
    local job = player.PlayerData.job
    if type(job) ~= 'table' or not job.onduty then return false end
    for i = 1, select('#', ...) do
        if job.name == select(i, ...) then return true end
    end
    return false
end

--- Cuffed, dead or in last stand: a man who cannot walk away (his core metadata).
---@param player table core player
---@return boolean
local function isHelpless(player)
    local meta = player.PlayerData.metadata or {}
    return (meta.ishandcuffed or meta.isdead or meta.inlaststand) and true or false
end

--- Where the server places a player: his ped, and the wagon he sits in when he sits in one (a
--- seated man is measured at his wagon too).
---@param src integer
---@return vector3[]|nil
local function placesOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local places = { GetEntityCoords(ped) }
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then places[2] = GetEntityCoords(vehicle) end
    return places
end

--- Both in the same routing bucket and within `reach` metres of each other.
---@param a integer server id
---@param b integer server id
---@param reach number metres
---@return boolean
local function withinReach(a, b, reach)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return false end
    local from, to = placesOf(a), placesOf(b)
    if not from or not to then return false end
    for _, p in ipairs(from) do
        for _, q in ipairs(to) do
            if #(p - q) <= reach then return true end
        end
    end
    return false
end

--- Refuse an action: a debug line for the server owner and, when `key` is given, the reason to
--- the sender (a dictionary key, translated on his client).
---@param src integer
---@param event string
---@param why string
---@param key string|nil
local function refuseAct(src, event, why, key)
    w.print.debug(('police:server:%s from %s refused: %s'):format(event, tostring(src), why))
    if key then w.notify(src, { description = key, type = 'error' }) end
end

--- The sender and the man he acts on (core players), or nothing when that man is not in the
--- game, is the sender himself, or does not stand next to him.
---@param src integer the sender
---@param playerId any the man's server id, as the client sent it
---@param event string the event name, for the debug line
---@param reach number|nil metres (REACH)
---@return table|nil actor, table|nil target
local function nearTarget(src, playerId, event, reach)
    local actor = WCore.Functions.GetPlayer(src)
    if not actor then return end
    -- a number only: WCore.Functions.GetPlayer reads a string as a license / identifier
    local id = tonumber(playerId)
    local target = id and id ~= src and WCore.Functions.GetPlayer(id) or nil
    if not target then
        return refuseAct(src, event, ('no other player %s'):format(tostring(playerId)), 'error.none_nearby')
    end
    reach = reach or REACH
    if not withinReach(src, target.PlayerData.source, reach) then
        return refuseAct(src, event, ('player %s is not within %s m in the same bucket'):format(tostring(id), tostring(reach)),
            'error.none_nearby')
    end
    return actor, target
end

-- ── the cuff flag ────────────────────────────────────────────────────────────────────────
-- The core metadata 'ishandcuffed' is what the escort, wagon and robbery checks here and the
-- inventory's item use read. It used to be whatever the man's own client reported through
-- police:server:SetHandcuffStatus: a cuffed man cleared it and slipped out of those checks, and
-- anybody could set it on himself. Now the server decides when it may change:
--   * CuffPlayer (checked: the reach, the handcuffs or a lawman on duty) sends the man GetCuffed
--     and grants his client one answer within CUFF_ANSWER_MS. His client toggles its own cuffs
--     and answers with what it did (true cuffed, false uncuffed: the same card cuffs and uncuffs),
--     so the flag follows the man's real state;
--   * without such a grant a client may only clear the flag while the server knows him dead or in
--     last stand and in a hospital bed (w_ambulancejob's hospital respawn takes the cuffs off a
--     dead man on his client, right after it put him in the bed);
--   * the character loading or logging out and the jail clear it on the server itself (below and
--     jailInPlay): the client still reports those, harmlessly, as the flag is already false.
local CUFF_ANSWER_MS = 10000
local cuffGrants = {} -- [server id] = { n = answers still owed, expires = GetGameTimer() deadline }

--- CuffPlayer sent this man GetCuffed: his client owes one answer.
---@param target integer
---@param wanted boolean the state the server sent him to (true cuffed, false free)
local function grantCuffAnswer(target, wanted)
    local now = GetGameTimer()
    local grant = cuffGrants[target]
    if not grant or grant.expires <= now then
        grant = { n = 0 }
        cuffGrants[target] = grant
    end
    grant.n = grant.n + 1
    grant.wanted = wanted
    grant.expires = now + CUFF_ANSWER_MS
end

--- Use up one owed answer, if this man has one: true and the state the server sent him to.
---@param src integer
---@return boolean, boolean?
local function takeCuffAnswer(src)
    local grant = cuffGrants[src]
    if not grant then return false end
    if grant.expires <= GetGameTimer() then
        cuffGrants[src] = nil
        return false
    end
    grant.n = grant.n - 1
    if grant.n <= 0 then cuffGrants[src] = nil end
    return true, grant.wanted
end

-- Cuff / uncuff (the man's client toggles). The handcuffs item cuffs anybody, hard or soft, in
-- any job; without it only a lawman on duty soft-cuffs (/sc). The hard cuff of the card and of
-- /cuff asks for the handcuffs on the client as well.
RegisterNetEvent('police:server:CuffPlayer', function(playerId, isSoftcuff)
    local src = source
    local Player, CuffedPlayer = nearTarget(src, playerId, 'CuffPlayer')
    if not Player then return end
    local soft = isSoftcuff == true
    if not Player.Functions.GetItemByName(Config.HandCuffItem or 'handcuffs') and not (soft and onDutyAs(Player, 'police')) then
        return refuseAct(src, 'CuffPlayer', soft and 'no handcuffs and not a lawman on duty' or 'no handcuffs', 'error.no_cuff')
    end
    -- the server decides the new state and sends it: his client applies it rather than toggling its
    -- own, so the two can never drift apart (a toggle on a stale flag inverted it for good)
    local wanted = not ((CuffedPlayer.PlayerData.metadata or {}).ishandcuffed == true)
    grantCuffAnswer(CuffedPlayer.PlayerData.source, wanted)
    TriggerClientEvent("police:client:GetCuffed", CuffedPlayer.PlayerData.source, src, soft, wanted)
end)

-- Escort / release (the man's client toggles, and follows only while he is cuffed or down). A
-- lawman or a doctor on duty walks anybody; everybody else a cuffed, dead or downed man.
RegisterNetEvent('police:server:EscortPlayer', function(playerId)
    local src = source
    local Player, EscortPlayer = nearTarget(src, playerId, 'EscortPlayer')
    if not Player then return end
    if onDutyAs(Player, 'police', 'doctor') or isHelpless(EscortPlayer) then
        TriggerClientEvent("police:client:GetEscorted", EscortPlayer.PlayerData.source, src)
    else
        w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
    end
end)

-- Carry on the shoulder / put down: anybody, a cuffed, dead or downed man only.
RegisterNetEvent('police:server:KidnapPlayer', function(playerId)
    local src = source
    local Player, EscortPlayer = nearTarget(src, playerId, 'KidnapPlayer')
    if not Player then return end
    if isHelpless(EscortPlayer) then
        TriggerClientEvent("police:client:GetKidnappedTarget", EscortPlayer.PlayerData.source, src)
        TriggerClientEvent("police:client:GetKidnappedDragger", src, EscortPlayer.PlayerData.source)
    else
        w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
    end
end)

-- Wagons: the lawman card only (on duty), a cuffed or dead man only.
RegisterNetEvent('police:server:SetPlayerOutVehicle', function(playerId)
    local src = source
    local Player, EscortPlayer = nearTarget(src, playerId, 'SetPlayerOutVehicle', WAGON_REACH)
    if not Player then return end
    if not onDutyAs(Player, 'police') then
        return refuseAct(src, 'SetPlayerOutVehicle', 'not a lawman on duty', 'error.on_duty_police_only')
    end
    if EscortPlayer.PlayerData.metadata["ishandcuffed"] or EscortPlayer.PlayerData.metadata["isdead"] then
        TriggerClientEvent("police:client:SetOutVehicle", EscortPlayer.PlayerData.source)
    else
        w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
    end
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(playerId)
    local src = source
    local Player, EscortPlayer = nearTarget(src, playerId, 'PutPlayerInVehicle')
    if not Player then return end
    if not onDutyAs(Player, 'police') then
        return refuseAct(src, 'PutPlayerInVehicle', 'not a lawman on duty', 'error.on_duty_police_only')
    end
    if EscortPlayer.PlayerData.metadata["ishandcuffed"] or EscortPlayer.PlayerData.metadata["isdead"] then
        TriggerClientEvent("police:client:PutInVehicle", EscortPlayer.PlayerData.source)
    else
        w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
    end
end)

RegisterNetEvent('police:server:BillPlayer', function(playerId, price)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    -- a number only: GetPlayer reads a string as a license / identifier
    local OtherPlayer = tonumber(playerId) and WCore.Functions.GetPlayer(tonumber(playerId)) or nil
    -- on duty (an off-duty lawman billed a man's whole bank), and a ceiling on the fine
    if Player and onDutyAs(Player, 'police') then
        if OtherPlayer then
            price = tonumber(price)
            if not closePlayers(Player, OtherPlayer) or not price or price ~= price or price <= 0 or price == math.huge or not economyReady() then return end
            price = math.min(price, tonumber(Config.MaxFine) or 5000)
            if not exports.w_centralbank:EnsureAccount('society:police', 'police', 'society') then return end
            if not exports.w_centralbank:Transfer('player:' .. OtherPlayer.PlayerData.citizenid .. ':bank', 'society:police', price, 'police-bill') then return end
            TriggerClientEvent('police:client:notify', OtherPlayer.PlayerData.source, 'info.fine_received', 'inform', price)
            -- 1.0.2: the level (w_level's table): a fine paid, never one's own
            if OtherPlayer.PlayerData.source ~= src then levelXp(src, 'police_fine', { target = OtherPlayer.PlayerData.source }) end
        end
    end
end)

-- The walk-up card's jail (client/interactions.lua JailTarget: the suspect in front of the officer).
-- The server id comes from that proximity pick, so the suspect must still stand next to the
-- officer: the /jail command no longer comes through here, and a remote id is refused.
RegisterNetEvent('police:server:JailPlayer', function(playerId, time)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local OtherPlayer = WCore.Functions.GetPlayer(tonumber(playerId))
    time = tonumber(time)
    if not time or time ~= time or time <= 0 or time == math.huge then return end

    if Player and onDutyAs(Player, 'police') then
        if OtherPlayer and closePlayers(Player, OtherPlayer) then
            jailInPlay(src, OtherPlayer, time)
        end
    end
end)

--- A dead man's respawn at the hospital: w_medic puts him in a bed (hospital:server:
--- RespawnAtHospital) before his client drops the cuffs, and his events arrive in that order. The
--- death itself is only his client's word (hospital:server:SetDeathStatus), so without the bed a
--- cuffed man sent "dead", then "uncuffed", then "alive", and walked out of the cuffs where he stood.
---@param src integer
---@return boolean
local function respawnedAtHospital(src)
    if GetResourceState('w_medic') ~= 'started' then return true end -- no bed to check
    -- ★ The bed alone was not proof: a living man reported "dead", asked for the respawn, got a bed
    --   for the price of the bill, and dropped his cuffs. RespawnedDead answers true only for a
    --   respawn after the full bleed-out, as the death screen allows it (w_medic).
    local ok, respawned = pcall(function() return exports.w_medic:RespawnedDead(src) end)
    -- an export that fails (w_medic restarting) must not keep a respawned man cuffed
    return not ok or respawned == true
end

-- The man's own client reports its cuffs (see "the cuff flag" above for what is honoured).
RegisterNetEvent('police:server:SetHandcuffStatus', function(isHandcuffed)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if not Player or type(isHandcuffed) ~= 'boolean' then return end
    local meta = Player.PlayerData.metadata or {}
    local granted, wanted = takeCuffAnswer(src)
    if granted then
        -- ★ The state is the one CuffPlayer sent him to, not his answer: the man's client used to
        --   choose, and a modified one answered false to every cuff and stayed free in every check
        --   that reads the flag.
        local cuffed = wanted
        if cuffed == nil then cuffed = not (meta.ishandcuffed == true) end
        if isHandcuffed ~= cuffed then
            refuseAct(src, 'SetHandcuffStatus', ('answered %s to a cuff, the server holds %s'):format(tostring(isHandcuffed), tostring(cuffed)))
        end
        Player.Functions.SetMetaData("ishandcuffed", cuffed)
    elseif not isHandcuffed and meta.ishandcuffed and (meta.isdead or meta.inlaststand) and respawnedAtHospital(src) then
        Player.Functions.SetMetaData("ishandcuffed", false)
    elseif isHandcuffed ~= (meta.ishandcuffed == true) then
        refuseAct(src, 'SetHandcuffStatus', ('%s without a cuff from the server'):format(tostring(isHandcuffed)))
    end
end)

--- Clear a player's cuff flag on the server (his client has dropped the cuffs).
---@param src integer
local function clearCuffFlag(src)
    local Player = WCore.Functions.GetPlayer(src)
    if Player and (Player.PlayerData.metadata or {}).ishandcuffed then
        Player.Functions.SetMetaData("ishandcuffed", false)
    end
end

-- A character loading or logging out comes free of the cuffs (client/main.lua drops them on his
-- client), as before; the flag is cleared here now instead of on his client's word.
AddEventHandler('WCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and tonumber(Player.PlayerData.source)
    if not src then return end
    cuffGrants[src] = nil
    clearCuffFlag(src)
end)

AddEventHandler('WCore:Server:OnPlayerUnload', function(src)
    src = tonumber(src)
    if not src then return end
    cuffGrants[src] = nil
    clearCuffFlag(src)
end)

AddEventHandler('playerDropped', function()
    cuffGrants[source] = nil
end)

-- ── the prison ───────────────────────────────────────────────────────────────────────────
-- The sentence is the core metadata 'injail' (months), set by jailInPlay, /jail and w_mdt. The
-- server serves it: every Config.Prison.monthSeconds it takes a month off each jailed man in
-- play, sends him back inside if he stands beyond the radius (an escape, or a fresh login: a
-- sentence follows the character), and lets him out at 0. The client (client/prison.lua) only
-- moves him. Offline time does not count -- the sentence waits for him.
CreateThread(function()
    local P = Config.Prison or {}
    local cell = P.cell and vector3(P.cell.x, P.cell.y, P.cell.z)
    if not cell then return end
    local radius = tonumber(P.radius) or 150.0
    local maxMonths = tonumber(P.maxMonths) or 120
    while true do
        Wait(math.max(10, tonumber(P.monthSeconds) or 60) * 1000)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            local Player = src and WCore.Functions.GetPlayer(src)
            local left = Player and tonumber((Player.PlayerData.metadata or {}).injail) or 0
            if left ~= left then left = 0 end
            if left > 0 then
                left = math.min(left, maxMonths) - 1
                if left <= 0 then
                    Player.Functions.SetMetaData('injail', 0)
                    TriggerClientEvent('prison:client:UnjailPerson', src)
                    TriggerClientEvent('police:client:notify', src, 'info.prison_released', 'success')
                else
                    Player.Functions.SetMetaData('injail', left)
                    local ped = GetPlayerPed(src)
                    local meta = Player.PlayerData.metadata or {}
                    -- down or in a hospital bed: brought back once he is up again, not out of the bed
                    local inCare = meta.isdead == true or meta.inlaststand == true
                    if not inCare and GetResourceState('w_medic') == 'started' then
                        local ok, bed = pcall(function() return exports.w_medic:InHospitalBed(src) end)
                        inCare = ok and bed == true
                    end
                    if not inCare and ped and ped ~= 0 and #(GetEntityCoords(ped) - cell) > radius then
                        TriggerClientEvent('prison:client:Enter', src, left, true)
                    end
                end
            end
        end
    end
end)

-- The lawman card's search (on duty): the cash he finds, and the man is told he is searched.
RegisterNetEvent('police:server:SearchPlayer', function(playerId)
    local src = source
    local Player, SearchedPlayer = nearTarget(src, playerId, 'SearchPlayer')
    if not Player then return end
    if not onDutyAs(Player, 'police') then
        return refuseAct(src, 'SearchPlayer', 'not a lawman on duty', 'error.on_duty_police_only')
    end
    TriggerClientEvent('police:client:notify', src, 'info.cash_found', 'inform', SearchedPlayer.PlayerData.money["cash"])
    w.notify(SearchedPlayer.PlayerData.source, { description = 'info.being_searched', type = 'inform' })
end)

RegisterNetEvent('police:server:SeizeCash', function(playerId)
    local officer = WCore.Functions.GetPlayer(source)
    local victim = WCore.Functions.GetPlayer(tonumber(playerId))
    if not closePlayers(officer, victim) or officer.PlayerData.citizenid == victim.PlayerData.citizenid or officer.PlayerData.job.name ~= 'police'
        or not officer.PlayerData.job.onduty or not economyReady() then return end
    local amount = exports.w_centralbank:GetBalance(cashAccount(victim))
    if not amount or amount <= 0 then return end
    local token = ('%08x%08x%08x%08x'):format(math.random(0,0x7fffffff),math.random(0,0x7fffffff),math.random(0,0x7fffffff),math.random(0,0x7fffffff))
    local claim = 'moneybag:' .. token .. ':cash'
    if not exports.w_centralbank:EnsureAccount(claim, officer.PlayerData.citizenid, 'bearer-cash') then return end
    if not exports.w_centralbank:Transfer(cashAccount(victim), claim, amount, 'police-cash-seized') then return end
    if not officer.Functions.AddItem('moneybag', 1, false, {cash=amount, economyClaim=claim}) then
        exports.w_centralbank:Transfer(claim, cashAccount(victim), amount, 'seizure-cancelled')
        return
    end
    w.notify(victim.PlayerData.source, {description='info.cash_confiscated', type='inform'})
end)

RegisterNetEvent('police:server:RobPlayer', function(playerId)
    local robber = WCore.Functions.GetPlayer(source)
    local victim = WCore.Functions.GetPlayer(tonumber(playerId))
    if not closePlayers(robber, victim) or robber.PlayerData.citizenid == victim.PlayerData.citizenid or not economyReady() then return end
    local state = victim.PlayerData.metadata or {}
    if not state.ishandcuffed and not state.isdead and not state.inlaststand then return end
    local amount = exports.w_centralbank:GetBalance(cashAccount(victim))
    if not amount or amount <= 0 or not exports.w_centralbank:Transfer(cashAccount(victim), cashAccount(robber), amount, 'player-robbery') then return end
    TriggerClientEvent('police:client:notify', victim.PlayerData.source, 'info.cash_robbed', 'inform', amount)
    TriggerClientEvent('police:client:notify', robber.PlayerData.source, 'info.stolen_money', 'inform', amount)
end)

RegisterNetEvent('police:server:spawnObject', function(type)
    local src = source
    local objectId = CreateObjectId()
    Objects[objectId] = type
    TriggerClientEvent("police:client:spawnObject", src, objectId, type, src)
end)

RegisterNetEvent('police:server:deleteObject', function(objectId)
    TriggerClientEvent('police:client:removeObject', -1, objectId)
end)

RegisterNetEvent('evidence:server:UpdateStatus', function(data)
    local src = source
    PlayerStatus[src] = data
end)

RegisterNetEvent('evidence:server:CreateBloodDrop', function(citizenid, bloodtype, coords)
    local bloodId = CreateBloodId()
    BloodDrops[bloodId] = {
        dna = citizenid,
        bloodtype = bloodtype
    }
    TriggerClientEvent("evidence:client:AddBlooddrop", -1, bloodId, citizenid, bloodtype, coords)
end)

RegisterNetEvent('evidence:server:CreateFingerDrop', function(coords)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local fingerId = CreateFingerId()
    FingerDrops[fingerId] = Player.PlayerData.metadata["fingerprint"]
    TriggerClientEvent("evidence:client:AddFingerPrint", -1, fingerId, Player.PlayerData.metadata["fingerprint"], coords)
end)

RegisterNetEvent('evidence:server:ClearBlooddrops', function(blooddropList)
    if blooddropList and next(blooddropList) then
        for k, v in pairs(blooddropList) do
            TriggerClientEvent("evidence:client:RemoveBlooddrop", -1, v)
            BloodDrops[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddBlooddropToInventory', function(bloodId, bloodInfo)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.Functions.RemoveItem("satchel", 1) then
        if Player.Functions.AddItem("evidence_satchel", 1, false, bloodInfo) then
            TriggerClientEvent("evidence:client:RemoveBlooddrop", -1, bloodId)
            BloodDrops[bloodId] = nil
        end
    else
        w.notify(src, { description = 'error.have_evidence_bag', type = 'error' })
    end
end)

RegisterNetEvent('evidence:server:AddFingerprintToInventory', function(fingerId, fingerInfo)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.Functions.RemoveItem("satchel", 1) then
        if Player.Functions.AddItem("evidence_satchel", 1, false, fingerInfo) then
            TriggerClientEvent("evidence:client:RemoveFingerprint", -1, fingerId)
            FingerDrops[fingerId] = nil
        end
    else
        w.notify(src, { description = 'error.have_evidence_bag', type = 'error' })
    end
end)

RegisterNetEvent('evidence:server:CreateCasing', function(weapon, coords)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local casingId = CreateCasingId()
    local weaponInfo = WCore.Shared.GetWeapons()[weapon] -- catalogue keyed by weapon hash
    local serieNumber = nil
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo["name"])
        if weaponItem then
            if weaponItem.info and weaponItem.info ~= "" then
                serieNumber = weaponItem.info.serie
            end
        end
    end
    TriggerClientEvent("evidence:client:AddCasing", -1, casingId, weapon, coords, serieNumber)
end)

RegisterNetEvent('police:server:UpdateCurrentCops', function()
    local amount = 0
    local players = WCore.Functions.GetWPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    TriggerClientEvent("police:SetCopCount", -1, amount)
end)

RegisterNetEvent('evidence:server:ClearCasings', function(casingList)
    if casingList and next(casingList) then
        for k, v in pairs(casingList) do
            TriggerClientEvent("evidence:client:RemoveCasing", -1, v)
            Casings[v] = nil
        end
    end
end)

RegisterNetEvent('evidence:server:AddCasingToInventory', function(casingId, casingInfo)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.Functions.RemoveItem("satchel", 1) then
        if Player.Functions.AddItem("evidence_satchel", 1, false, casingInfo) then
            TriggerClientEvent("evidence:client:RemoveCasing", -1, casingId)
            Casings[casingId] = nil
        end
    else
        w.notify(src, { description = 'error.have_evidence_bag', type = 'error' })
    end
end)

-- Threads
CreateThread(function()
    while true do
        Wait(1000 * 60 * 10)
        local curCops = GetCurrentCops()
        TriggerClientEvent("police:SetCopCount", -1, curCops)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        UpdateBlips()
    end
end)
