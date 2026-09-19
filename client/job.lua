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

---A fresh serial number for every armory firearm (rows whose info carries a `serie`).
local function SetWeaponSeries()
    for _, item in pairs(Config.Items.items) do
        if item.type == 'weapon' and item.info and item.info.serie ~= nil then
            item.info.serie = tostring(WCore.Shared.RandomInt(2) .. WCore.Shared.RandomStr(3) .. WCore.Shared.RandomInt(1) .. WCore.Shared.RandomStr(2) .. WCore.Shared.RandomInt(3) .. WCore.Shared.RandomStr(4))
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
        drawer = math.floor(drawer) -- '2', never '2.0': the id is a DB key
        -- stash id, not a label: fixed so every language opens the same drawer
        local stashName = ('%d | Drawer %d'):format(currentEvidence, drawer)
        TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, {
            label = locale('info.evidence_drawer', drawer, currentEvidence),
            maxweight = 4000000,
            slots = 500,
        })
    end
end)

-- Toggle Duty in an event.
RegisterNetEvent('w_policejob:ToggleDuty', function()
    onDuty = not onDuty
    TriggerServerEvent("police:server:UpdateCurrentCops")
    TriggerServerEvent("WCore:ToggleDuty")
end)

RegisterNetEvent('police:client:TakeOutVehicle', function(data)
    TakeOutVehicle(data.vehicle)
end)

RegisterNetEvent('police:client:OpenPersonalStash', function()
    local stashName = "policestash_" .. WCore.Functions.GetPlayerData().citizenid
    TriggerServerEvent("inventory:server:OpenInventory", "stash", stashName, {
        label = locale('info.personal_stash'),
    })
end)

RegisterNetEvent('police:client:OpenPersonalTrash', function()
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "policetrash", {
        label = locale('info.police_trash'),
        maxweight = 4000000,
        slots = 300,
    })
end)

RegisterNetEvent('police:client:OpenArmory', function()
    WCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.job.name == "police" then
            local authorizedItems = {
                label = locale('menu.pol_armory'),
                slots = 30,
                items = {}
            }
            local index = 1
            for _, armoryItem in pairs(Config.Items.items) do
                for i = 1, #armoryItem.authorizedJobGrades do
                    if armoryItem.authorizedJobGrades[i] == PlayerData.job.grade.level then
                        authorizedItems.items[index] = armoryItem
                        authorizedItems.items[index].slot = index
                        index = index + 1
                    end
                end
            end
            SetWeaponSeries()
            TriggerServerEvent("inventory:server:OpenInventory", "shop", "police", authorizedItems)
        else
            WCore.Functions.Notify(locale('error.law_only'), 'error')
        end
    end)
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
