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
        if v and (v.PlayerData.job.name == "police" or v.PlayerData.job.name == "ambulance") and v.PlayerData.job.onduty then
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

WCore.Commands.Add("jail", locale("commands.jail_player"), {{name = "id", help = locale('info.player_id')}, {name = "time", help = locale('info.jail_time')}}, true, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        local playerId = tonumber(args[1])
        local time = tonumber(args[2])
        if time and time > 0 then
            TriggerClientEvent("police:client:JailCommand", src, playerId, time)
        else
            w.notify(src, { description = 'info.jail_time_no', type = 'inform' })
        end
    else
        w.notify(src, { description = 'error.on_duty_police_only', type = 'error' })
    end
end)

WCore.Commands.Add("unjail", locale("commands.unjail_player"), {{name = "id", help = locale('info.player_id')}}, true, function(source, args)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
        local playerId = tonumber(args[1])
        TriggerClientEvent("prison:client:UnjailPerson", playerId)
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
    local OtherPlayer = WCore.Functions.GetPlayer(tonumber(args[1]))
    if ((Player.PlayerData.job.name == "police") and Player.PlayerData.job.onduty) and OtherPlayer then
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
    cb(Player.PlayerData.metadata["isdead"])
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

RegisterNetEvent('police:server:CuffPlayer', function(playerId, isSoftcuff)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local CuffedPlayer = WCore.Functions.GetPlayer(playerId)
    if CuffedPlayer then
        if Player.Functions.GetItemByName("handcuffs") or Player.PlayerData.job.name == "police" then
            TriggerClientEvent("police:client:GetCuffed", CuffedPlayer.PlayerData.source, Player.PlayerData.source, isSoftcuff)
        end
    end
end)

RegisterNetEvent('police:server:EscortPlayer', function(playerId)
    local src = source
    local Player = WCore.Functions.GetPlayer(source)
    local EscortPlayer = WCore.Functions.GetPlayer(playerId)
    if EscortPlayer then
        if (Player.PlayerData.job.name == "police" or Player.PlayerData.job.name == "ambulance") or (EscortPlayer.PlayerData.metadata["ishandcuffed"] or EscortPlayer.PlayerData.metadata["isdead"] or EscortPlayer.PlayerData.metadata["inlaststand"]) then
            TriggerClientEvent("police:client:GetEscorted", EscortPlayer.PlayerData.source, Player.PlayerData.source)
        else
            w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
        end
    end
end)

RegisterNetEvent('police:server:KidnapPlayer', function(playerId)
    local src = source
    local Player = WCore.Functions.GetPlayer(source)
    local EscortPlayer = WCore.Functions.GetPlayer(playerId)
    if EscortPlayer then
        if EscortPlayer.PlayerData.metadata["ishandcuffed"] or EscortPlayer.PlayerData.metadata["isdead"] or
            EscortPlayer.PlayerData.metadata["inlaststand"] then
            TriggerClientEvent("police:client:GetKidnappedTarget", EscortPlayer.PlayerData.source, Player.PlayerData.source)
            TriggerClientEvent("police:client:GetKidnappedDragger", Player.PlayerData.source, EscortPlayer.PlayerData.source)
        else
            w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
        end
    end
end)

RegisterNetEvent('police:server:SetPlayerOutVehicle', function(playerId)
    local src = source
    local Player = WCore.Functions.GetPlayer(source)
    local EscortPlayer = WCore.Functions.GetPlayer(playerId)
    if EscortPlayer then
        if EscortPlayer.PlayerData.metadata["ishandcuffed"] or EscortPlayer.PlayerData.metadata["isdead"] then
            TriggerClientEvent("police:client:SetOutVehicle", EscortPlayer.PlayerData.source)
        else
            w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
        end
    end
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(playerId)
    local src = source
    local EscortPlayer = WCore.Functions.GetPlayer(playerId)
    if EscortPlayer then
        if EscortPlayer.PlayerData.metadata["ishandcuffed"] or EscortPlayer.PlayerData.metadata["isdead"] then
            TriggerClientEvent("police:client:PutInVehicle", EscortPlayer.PlayerData.source)
        else
            w.notify(src, { description = 'error.not_cuffed_dead', type = 'error' })
        end
    end
end)

RegisterNetEvent('police:server:BillPlayer', function(playerId, price)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local OtherPlayer = WCore.Functions.GetPlayer(playerId)
    if Player.PlayerData.job.name == "police" then
        if OtherPlayer then
            price = tonumber(price)
            if not closePlayers(Player, OtherPlayer) or not price or price ~= price or price <= 0 or price == math.huge or not economyReady() then return end
            if not exports.w_centralbank:EnsureAccount('society:police', 'police', 'society') then return end
            if not exports.w_centralbank:Transfer('player:' .. OtherPlayer.PlayerData.citizenid .. ':bank', 'society:police', price, 'police-bill') then return end
            TriggerClientEvent('police:client:notify', OtherPlayer.PlayerData.source, 'info.fine_received', 'inform', price)
        end
    end
end)

RegisterNetEvent('police:server:JailPlayer', function(playerId, time)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    local OtherPlayer = WCore.Functions.GetPlayer(playerId)
    local currentDate = os.date("*t")
    if currentDate.day == 31 then
        currentDate.day = 30
    end

    if Player.PlayerData.job.name == "police" then
        if OtherPlayer then
            OtherPlayer.Functions.SetMetaData("injail", time)
            OtherPlayer.Functions.SetMetaData("criminalrecord", {
                ["hasRecord"] = true,
                ["date"] = currentDate
            })
            TriggerClientEvent("police:client:SendToJail", OtherPlayer.PlayerData.source, time)
            TriggerClientEvent('police:client:notify', src, 'info.sent_jail_for', 'inform', time)
        end
    end
end)

RegisterNetEvent('police:server:SetHandcuffStatus', function(isHandcuffed)
    local src = source
    local Player = WCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMetaData("ishandcuffed", isHandcuffed)
    end
end)

RegisterNetEvent('police:server:SearchPlayer', function(playerId)
    local src = source
    local SearchedPlayer = WCore.Functions.GetPlayer(playerId)
    if SearchedPlayer then
        TriggerClientEvent('police:client:notify', src, 'info.cash_found', 'inform', SearchedPlayer.PlayerData.money["cash"])
        w.notify(SearchedPlayer.PlayerData.source, { description = 'info.being_searched', type = 'inform' })
    end
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
