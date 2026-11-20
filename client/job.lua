-- Variables
local currentGarage = 1
-- PlayerJob / onDuty are the globals owned by client/main.lua
local StationPrompts = {}   -- library prompt records built by CreatePrompts (relabelled on a language switch)
local StationBlips = {}

local STATION_RANGE <const> = 1.5   -- metres the lawman stands from a station point
local MERGE_RANGE <const> = 2.5     -- points closer than this share one prompt card

-- Functions
---Spawn a station wagon at the current garage point and seat the lawman on the box.
---@param model string RDR2 wagon model (Config.AuthorizedVehicles)
function TakeOutVehicle(model)
    local coords = Config.Locations["vehicle"][currentGarage]
    if not coords then return end
    if not IsModelInCdimage(joaat(model)) or not IsModelAVehicle(joaat(model)) then
        w.print.error(('wagon model %s does not exist'):format(model))
        return
    end
    local veh = w.entity.create(model, coords, true)
    if not veh then return end
    SetVehicleOnGroundProperly(veh, 0)
    SetEntityAsMissionEntity(veh, true, true)
    TaskWarpPedIntoVehicle(cache.ped, veh, -1)
end

function MenuGarage()
    local vehicleMenu = {}

    local authorizedVehicles = Config.AuthorizedVehicles[WCore.Functions.GetPlayerData().job.grade.level] or {}
    for veh, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            title = locale(label),
            event = "police:client:TakeOutVehicle",
            args = { vehicle = veh }
        }
    end

    -- options is a flat array of rows; no parent menu is registered, so no back target
    w.registerContext({
        id = 'lawmen_vehicles',
        title = locale('menu.garage_title'),
        options = vehicleMenu
    })
    w.showContext('lawmen_vehicles')
end

---Station blips; rebuilt on a language switch so the names follow the dictionary.
function CreateStationBlips()
    for _, blip in pairs(StationBlips) do
        RemoveBlip(blip)
    end
    StationBlips = {}
    for _, v in pairs(Config.Locations["stations"]) do
        StationBlips[#StationBlips + 1] = w.blip.create(v.coords, locale(v.label), -693644997, nil, nil, 0.7)
    end
end

-- ── station prompts ──────────────────────────────────────────────────────────────────
-- Every station point (duty, garage, evidence, stash, armory) is a library proximity prompt.
-- Points of one office that stand within reach of each other are merged into a single card
-- (that is why each kind has its own key, Config.Keys); cards whose reach still overlaps are
-- arbitrated by client/cards.lua (the closest one is shown).

---One entry per configured point: kind, coords, key, dictionary key of the label and the action.
local function StationEntries()
    local entries = {}
    local function add(kind, coords, label, onComplete)
        entries[#entries + 1] = { kind = kind, coords = coords, key = Config.Keys[kind], label = label, onComplete = onComplete }
    end

    for _, v in pairs(Config.Locations['duty']) do
        add('duty', v, 'prompt.toggle_duty', function() TriggerEvent('w_policejob:ToggleDuty') end)
    end
    for k, v in pairs(Config.Locations['vehicle']) do
        add('garage', vector3(v.x, v.y, v.z), 'prompt.garage', function() TriggerEvent('police:client:promptVehicle', k) end)
    end
    for k, v in pairs(Config.Locations['evidence']) do
        add('evidence', v, 'prompt.evidence', function() TriggerEvent('police:client:EvidenceStashDrawer', k) end)
    end
    for _, v in pairs(Config.Locations['stash']) do
        add('stash', v, 'prompt.stash', function() TriggerEvent('police:client:OpenPersonalStash') end)
    end
    for _, v in pairs(Config.Locations['armory']) do
        add('armory', v, 'prompt.armory', function() TriggerEvent('police:client:OpenArmory') end)
    end
    return entries
end

---Group the entries by proximity: one card per cluster, centred on its members and wide
---enough to reach the farthest of them.
local function ClusterEntries(entries)
    local clusters = {}
    for _, entry in ipairs(entries) do
        local cluster
        for _, c in ipairs(clusters) do
            if #(c.coords - entry.coords) < MERGE_RANGE then
                cluster = c
                break
            end
        end
        if not cluster then
            cluster = { coords = entry.coords, members = {} }
            clusters[#clusters + 1] = cluster
        end
        cluster.members[#cluster.members + 1] = entry
    end

    for _, c in ipairs(clusters) do
        local sum = vector3(0.0, 0.0, 0.0)
        for _, entry in ipairs(c.members) do sum = sum + entry.coords end
        c.coords = sum / #c.members
        local spread = 0.0
        for _, entry in ipairs(c.members) do
            local d = #(c.coords - entry.coords)
            if d > spread then spread = d end
        end
        c.distance = STATION_RANGE + spread
    end
    return clusters
end

---Build the station prompt cards (once; lawmen only).
function CreatePrompts()
    if #StationPrompts > 0 then return end

    for _, cluster in ipairs(ClusterEntries(StationEntries())) do
        local prompts = {}
        for i, entry in ipairs(cluster.members) do
            prompts[i] = { key = entry.key, label = locale(entry.label), onComplete = entry.onComplete }
        end
        local rec = w.prompt.at({
            coords = cluster.coords,
            distance = cluster.distance,
            title = false,
            prompts = prompts,
            -- lawmen only; the card steps aside while a menu / the inventory is open
            canInteract = function() return PlayerJob.name == 'police' and ScreenIsFree() end,
        })
        rec.members = cluster.members
        StationPrompts[#StationPrompts + 1] = TrackCard(rec, CARD_STATION)
    end
end

---Drop the station prompt cards (the lawman left the job or the character).
function RemovePrompts()
    for _, rec in ipairs(StationPrompts) do
        rec.remove()
    end
    StationPrompts = {}
end

---Language switch: relabel the cards in place.
function RefreshPrompts()
    for _, rec in ipairs(StationPrompts) do
        for _, entry in ipairs(rec.members) do
            rec.setLabel(entry.key, locale(entry.label))
        end
    end
end

RegisterNetEvent('police:client:promptVehicle', function(k)
    WCore.Functions.GetPlayerData(function(PlayerData)
        PlayerJob = PlayerData.job
        onDuty = PlayerData.job.onduty
        local ped = cache.ped

        if PlayerJob.name == "police" then
            if IsPedInAnyVehicle(ped, false) then
                -- riding a wagon into the garage point stores it
                local wagon = GetVehiclePedIsIn(ped, false)
                w.entity.requestControl(wagon, 2000)
                w.entity.delete(wagon)
            else
                MenuGarage()
                currentGarage = k
            end
        else
            WCore.Functions.Notify(locale('error.not_lawman'), 'error')
        end
    end)
end)

---Read the status list (gunpowder, alcohol, ...) of a player; entries are dictionary keys.
---@param player integer client player index (nil = the closest one within 5 m)
function CheckStatusOf(player)
    if PlayerJob.name ~= 'police' then return end
    player = player or w.getClosestPlayer(GetEntityCoords(cache.ped), 5.0, false)
    if not player then
        WCore.Functions.Notify(locale("error.none_nearby"), 'error')
        return
    end
    WCore.Functions.TriggerCallback('police:GetPlayerStatus', function(result)
        if result then
            -- entries are dictionary keys: translated in the officer's language
            for _, v in pairs(result) do
                WCore.Functions.Notify(locale(v), 'inform')
            end
        end
    end, GetPlayerServerId(player))
end

RegisterNetEvent('police:client:CheckStatus', function()
    CheckStatusOf(nil)
end)

-- The station prompt is the proximity guard: it only completes while the lawman stands at the drawer.
RegisterNetEvent('police:client:EvidenceStashDrawer', function(k)
    local currentEvidence = k
    if not Config.Locations["evidence"][currentEvidence] then return end

    local input = w.inputDialog(locale('info.evidence_stash'), {
        { type = 'number', label = locale('info.slot'), required = true, min = 1 },
    })
    local drawer = input and tonumber(input[1])
    if drawer and drawer >= 1 then
        -- 2026-11-13: the server opens the drawer (it checks the job and the office point);
        -- the old QBCore event 'inventory:server:OpenInventory' was never answered on w_core
        TriggerServerEvent('w_policejob:server:openEvidence', currentEvidence, math.floor(drawer))
    end
end)

-- Toggle Duty in an event.
-- 2026-11-12: the duty is the server's (w_core server/events.lua answers WCore:Client:SetDuty, client/main.lua
-- takes it). Flipping it here as well drifted the moment the two disagreed once (a job set while on duty, see
-- OnJobUpdate): from then on the law card came up only while the station said off duty.
RegisterNetEvent('w_policejob:ToggleDuty', function()
    exports.w_lib:FwToggleDuty()
end)

RegisterNetEvent('police:client:TakeOutVehicle', function(data)
    TakeOutVehicle(data.vehicle)
end)

RegisterNetEvent('police:client:OpenPersonalStash', function()
    TriggerServerEvent('w_policejob:server:openStash')
end)

RegisterNetEvent('police:client:OpenPersonalTrash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policetrash", {
        label = locale('info.police_trash'),
        maxweight = 4000000,
        slots = 300,
    })
end)

-- The armory is a shop of the bag that the server registers (its rows, the grades and the job check
-- are the server's; every firearm gets its serial number from the bag when it is taken)
RegisterNetEvent('police:client:OpenArmory', function()
    TriggerServerEvent('w_policejob:server:openArmory')
end)

-- Threads
CreateThread(function()
    if LocalPlayer.state.isLoggedIn and PlayerJob.name == 'police' then
        CreatePrompts()
    end

    CreateStationBlips()

    for _, v in pairs(WCore.Shared.GetWeapons()) do
        local weaponName = v.name
        local weaponLabel = v.label
        local weaponHash = GetHashKey(v.name)
        local weaponAmmo, weaponAmmoLabel = nil, nil -- nil label = 'info.unknown' when displayed
        if v.ammotype then
            weaponAmmo = v.ammotype:lower()
            local ammoItem = WCore.Shared.GetItem(weaponAmmo)
            if ammoItem then weaponAmmoLabel = ammoItem.label end
        end

        Config.WeaponHashes[weaponHash] = {
            weaponName = weaponName,
            weaponLabel = weaponLabel,
            weaponAmmo = weaponAmmo,
            weaponAmmoLabel = weaponAmmoLabel
        }
    end
end)

-- The resource stops: the station cards (and their point records) go with it.
w.stopped(RemovePrompts)
