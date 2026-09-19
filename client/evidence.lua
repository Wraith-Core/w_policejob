-- Variables
local CurrentStatusList = {}
local Casings = {}          -- casingId → { type, serie, coords, rec }
local Blooddrops = {}       -- bloodId → { citizenid, bloodtype, coords, rec }
local Fingerprints = {}     -- fingerId → { fingerprint, coords, rec }
local shotAmount = 0

-- Status texts are stored as dictionary keys: the suspect syncs keys to the server and the
-- officer who reads them translates in his own language (client/job.lua CheckStatus).
local StatusList = {
    ['fight'] = 'evidence.red_hands',
    ['widepupils'] = 'evidence.wide_pupils',
    ['redeyes'] = 'evidence.red_eyes',
    ['weedsmell'] = 'evidence.weed_smell',
    ['gunpowder'] = 'evidence.gunpowder',
    ['chemicals'] = 'evidence.chemicals',
    ['heavybreath'] = 'evidence.heavy_breathing',
    ['sweat'] = 'evidence.sweat',
    ['handbleed'] = 'evidence.handbleed',
    ['confused'] = 'evidence.confused',
    ['alcohol'] = 'evidence.alcohol',
    ["heavyalcohol"] = 'evidence.heavy_alcohol',
    ["agitated"] = 'evidence.agitated'
}

-- Only firearms eject casings: the catalogue names of the held weapon decide (bows, lassos,
-- thrown weapons and melee tools leave nothing behind).
local CasingWeaponPrefixes = { 'weapon_pistol', 'weapon_revolver', 'weapon_repeater', 'weapon_rifle', 'weapon_shotgun', 'weapon_sniperrifle' }

-- Every piece of evidence on the ground is a library proximity prompt (Config.Keys.collect):
-- the card names the evidence and offers "Collect" while an on-duty lawman holds his lantern up.
-- Casings land on top of each other: client/cards.lua keeps the closest piece's card up.
local EVIDENCE_RANGE <const> = 1.5

-- Functions
local function DropsCasing(weapon)
    local info = Config.WeaponHashes[weapon]
    if not info or not info.weaponName then return false end
    for i = 1, #CasingWeaponPrefixes do
        if info.weaponName:find(CasingWeaponPrefixes[i], 1, true) == 1 then
            return true
        end
    end
    return false
end

---Evidence only shows up to a lawman on duty holding his lantern.
local function CanCollect()
    if PlayerJob.name ~= 'police' or not onDuty or not ScreenIsFree() then return false end
    return Citizen.InvokeNative(0x8425C5F057012DAB, cache.ped) == `WEAPON_MELEE_LANTERN` -- _GET_PED_CURRENT_HELD_WEAPON
end

---Ammo label (translated fallback) and ammo item name of a weapon hash.
local function AmmoLabel(weaponHash)
    local info = Config.WeaponHashes[weaponHash]
    return (info and info.weaponAmmoLabel) or locale('info.unknown'), info and info.weaponAmmo or nil
end

local function DnaHash(s)
    local h = string.gsub(s, '.', function(c)
        return string.format('%02x', string.byte(c))
    end)
    return h
end

---Card title of a piece of evidence (what the lawman sees next to the "Collect" prompt).
---@param kind 'casing'|'blood'|'fingerprint'
---@param entry table
---@return string
local function EvidenceTitle(kind, entry)
    if kind == 'casing' then
        return locale('info.bullet_casing', (AmmoLabel(entry.type)))
    elseif kind == 'blood' then
        return locale('info.blood_text', DnaHash(entry.citizenid))
    end
    return locale('info.fingerprint_text')
end

---The satchel entry sent to the server when a piece of evidence is collected.
---@param kind 'casing'|'blood'|'fingerprint'
---@param entry table
---@return table
local function EvidenceInfo(kind, entry)
    if kind == 'casing' then
        local ammoLabel, ammoType = AmmoLabel(entry.type)
        return {
            label = locale('info.casing'),
            type = 'casing',
            ammolabel = ammoLabel,
            ammotype = ammoType,
            serie = entry.serie or locale('evidence.serial_not_visible'),
        }
    elseif kind == 'blood' then
        return {
            label = locale('info.blood'),
            type = 'blood',
            dnalabel = DnaHash(entry.citizenid),
            bloodtype = entry.bloodtype,
        }
    end
    return {
        label = locale('info.fingerprint'),
        type = 'fingerprint',
        fingerprint = entry.fingerprint,
    }
end

local CollectEvents = {
    casing = 'evidence:server:AddCasingToInventory',
    blood = 'evidence:server:AddBlooddropToInventory',
    fingerprint = 'evidence:server:AddFingerprintToInventory',
}

---Attach the "Collect" prompt to a piece of evidence.
---@param kind 'casing'|'blood'|'fingerprint'
---@param id integer
---@param entry table
local function AttachEvidencePrompt(kind, id, entry)
    entry.kind = kind
    entry.rec = w.prompt.at({
        coords = vector3(entry.coords.x, entry.coords.y, entry.coords.z),
        distance = EVIDENCE_RANGE,
        title = EvidenceTitle(kind, entry),
        prompts = {
            {
                key = Config.Keys.collect,
                label = locale('prompt.collect_evidence'),
                onComplete = function()
                    TriggerServerEvent(CollectEvents[kind], id, EvidenceInfo(kind, entry))
                end,
            },
        },
        canInteract = CanCollect,
    })
    TrackCard(entry.rec, CARD_EVIDENCE)
end

---Drop a piece of evidence and its prompt.
---@param list table
---@param id integer
local function RemoveEvidence(list, id)
    local entry = list[id]
    if not entry then return end
    if entry.rec then entry.rec.remove() end
    list[id] = nil
end

---Language switch (client/main.lua): retitle / relabel every evidence card.
function RefreshEvidencePrompts()
    for _, list in ipairs({ Casings, Blooddrops, Fingerprints }) do
        for _, entry in pairs(list) do
            if entry.rec then
                entry.rec.setTitle(EvidenceTitle(entry.kind, entry))
                entry.rec.setLabel(Config.Keys.collect, locale('prompt.collect_evidence'))
            end
        end
    end
end

local function DropBulletCasing(weapon, ped)
    local randX = math.random() + math.random(-1, 1)
    local randY = math.random() + math.random(-1, 1)
    local coords = GetOffsetFromEntityInWorldCoords(ped, randX, randY, 0)
    TriggerServerEvent('evidence:server:CreateCasing', weapon, coords)
    Wait(300)
end

-- Events
RegisterNetEvent('evidence:client:SetStatus', function(statusId, time)
    if time > 0 and StatusList[statusId] then
        if (CurrentStatusList == nil or CurrentStatusList[statusId] == nil) or
            (CurrentStatusList[statusId] and CurrentStatusList[statusId].time < 20) then
            CurrentStatusList[statusId] = {
                text = StatusList[statusId],
                time = time
            }
            WCore.Functions.Notify(locale(CurrentStatusList[statusId].text), 'inform')
        end
    elseif StatusList[statusId] then
        CurrentStatusList[statusId] = nil
    end
    TriggerServerEvent('evidence:server:UpdateStatus', CurrentStatusList)
end)

RegisterNetEvent('evidence:client:AddBlooddrop', function(bloodId, citizenid, bloodtype, coords)
    RemoveEvidence(Blooddrops, bloodId)
    Blooddrops[bloodId] = {
        citizenid = citizenid,
        bloodtype = bloodtype,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z - 0.9
        }
    }
    AttachEvidencePrompt('blood', bloodId, Blooddrops[bloodId])
end)

RegisterNetEvent('evidence:client:RemoveBlooddrop', function(bloodId)
    RemoveEvidence(Blooddrops, bloodId)
end)

RegisterNetEvent('evidence:client:AddFingerPrint', function(fingerId, fingerprint, coords)
    RemoveEvidence(Fingerprints, fingerId)
    Fingerprints[fingerId] = {
        fingerprint = fingerprint,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z - 0.9
        }
    }
    AttachEvidencePrompt('fingerprint', fingerId, Fingerprints[fingerId])
end)

RegisterNetEvent('evidence:client:RemoveFingerprint', function(fingerId)
    RemoveEvidence(Fingerprints, fingerId)
end)

RegisterNetEvent('evidence:client:ClearBlooddropsInArea', function()
    local pos = GetEntityCoords(cache.ped)
    local blooddropList = {}
    WCore.Functions.Progressbar('clear_blooddrops', locale("progressbar.blood_clear"), 5000, false, true, {
        disableMovement = false,
        disableVehicleMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {}, {}, {}, function() -- Done
        if Blooddrops and next(Blooddrops) then
            for bloodId, v in pairs(Blooddrops) do
                if #(pos - vector3(v.coords.x, v.coords.y, v.coords.z)) < 10.0 then
                    blooddropList[#blooddropList + 1] = bloodId
                end
            end
            TriggerServerEvent('evidence:server:ClearBlooddrops', blooddropList)
            WCore.Functions.Notify(locale("success.blood_clear"), 'success')
        end
    end, function() -- Cancel
        WCore.Functions.Notify(locale("error.blood_not_cleared"), 'error')
    end)
end)

RegisterNetEvent('evidence:client:AddCasing', function(casingId, weapon, coords, serie)
    RemoveEvidence(Casings, casingId)
    Casings[casingId] = {
        type = weapon,
        serie = serie, -- nil = serial not readable (translated when shown)
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z - 0.9
        }
    }
    AttachEvidencePrompt('casing', casingId, Casings[casingId])
end)

RegisterNetEvent('evidence:client:RemoveCasing', function(casingId)
    RemoveEvidence(Casings, casingId)
end)

RegisterNetEvent('evidence:client:ClearCasingsInArea', function()
    local pos = GetEntityCoords(cache.ped)
    local casingList = {}
    WCore.Functions.Progressbar('clear_casings', locale("progressbar.bullet_casing"), 5000, false, true, {
        disableMovement = false,
        disableVehicleMovement = false,
        disableMouse = false,
        disableCombat = true
    }, {}, {}, {}, function() -- Done
        if Casings and next(Casings) then
            for casingId, v in pairs(Casings) do
                if #(pos - vector3(v.coords.x, v.coords.y, v.coords.z)) < 10.0 then
                    casingList[#casingList + 1] = casingId
                end
            end
            TriggerServerEvent('evidence:server:ClearCasings', casingList)
            WCore.Functions.Notify(locale("success.bullet_casing_removed"), 'success')
        end
    end, function() -- Cancel
        WCore.Functions.Notify(locale("error.bullet_casing_not_removed"), 'error')
    end)
end)

-- Threads

CreateThread(function()
    while true do
        Wait(10000)
        if LocalPlayer.state.isLoggedIn then
            if CurrentStatusList and next(CurrentStatusList) then
                for k in pairs(CurrentStatusList) do
                    if CurrentStatusList[k].time > 0 then
                        CurrentStatusList[k].time = CurrentStatusList[k].time - 10
                    else
                        CurrentStatusList[k].time = 0
                    end
                end
                TriggerServerEvent('evidence:server:UpdateStatus', CurrentStatusList)
            end
            if shotAmount > 0 then
                shotAmount = 0
            end
        end
    end
end)

CreateThread(function() -- Gunpowder Status when shooting
    while true do
        Wait(1)
        local ped = cache.ped
        if IsPedShooting(ped) then
            local weapon = Citizen.InvokeNative(0x8425C5F057012DAB, ped) -- _GET_PED_CURRENT_HELD_WEAPON
            if DropsCasing(weapon) then
                shotAmount = shotAmount + 1
                if shotAmount > 5 and (CurrentStatusList == nil or CurrentStatusList['gunpowder'] == nil) then
                    if math.random(1, 10) <= 7 then
                        TriggerEvent('evidence:client:SetStatus', 'gunpowder', 200)
                    end
                end
                DropBulletCasing(weapon, ped)
            end
        end
    end
end)

-- The resource stops: every evidence card (and its point record) goes with it.
w.stopped(function()
    for _, list in ipairs({ Casings, Blooddrops, Fingerprints }) do
        for id in pairs(list) do
            RemoveEvidence(list, id)
        end
    end
end)
