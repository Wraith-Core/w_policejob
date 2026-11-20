Config = {}

Config.ShowBlips = true

-- Keys of the library prompts (keyboard key names of the w_lib rawKeys vocabulary, upper-case).
-- Station points that stand within reach of each other share one prompt card, so every kind
-- of station point needs its own key.
Config.Keys = {
    -- station points
    duty = 'J',
    garage = 'R',
    stash = 'H',      -- not E (E grabs the player next to you); J is duty in this same card
    armory = 'F',
    evidence = 'G',
    -- evidence lying on the ground (casings, blood, fingerprints)
    collect = 'G',
    -- the card that follows the closest player: lawman on duty
    search = 'Y',     -- not E (E grabs the player next to you); J is jail in this same card
    cuff = 'G',       -- held
    escort = 'H',
    wagon = 'B',      -- seat in / take out of the nearest wagon
    jail = 'J',       -- held
    fine = 'K',
    seize = 'U',      -- held
    status = 'N',
    -- the card that follows the closest player: everybody else (escort shares Config.Keys.escort)
    rob = 'G',        -- held, only while the person has his hands up
    carry = 'F',      -- carry a cuffed / downed person
}

-- Objects a lawman can place with /pobject (RDR2 props). freeze = true pins the prop in place.
Config.Objects = {
    ["barricade"] = {model = `p_barricadewood_lrg01x`, freeze = true},
    ["tent"] = {model = `p_ambtentgrass01x`, freeze = true},
    ["torch"] = {model = `p_torchpostalwayson01x`, freeze = true},
    ["lantern"] = {model = `p_oillantern01x`, freeze = false},
}

Config.HandCuffItem = 'handcuffs'

Config.Locations = {
    ["duty"] = {
        [1] = vector3(1362.05, -1301.83, 77.77), -- Rhodes
        [2] = vector3(2507.53, -1301.41, 48.95), -- Saint Denis
        [3] = vector3(-768.03, -1266.37, 44.05), -- Blackwater
        [4] = vector3(-1812.03, -354.09, 164.65), -- Strawberry
        [5] = vector3(-277.86, 807.47, 119.38), --valentine
    },
    ["stash"] = {
        [1] = vector3(1359.24, -1299.65, 77.76), -- Rhodes
        [2] = vector3(2497.01, -1301.2, 48.96), -- Saint Denis
        [3] = vector3(-766.55, -1271.61, 44.05), -- Blackwater
        [4] = vector3(-1812.43, -355.87, 164.65), -- Strawberry
        [5] = vector3(-277.57, 810.22, 119.38) --valentine
    },
    ["vehicle"] = {
        [1] = vector4(-278.82, 826.41, 119.33, 7.5), -- Valentine Stable
        [2] = vector4(2493.22, -1321.87, 48.87, 271.06), -- Saint Denis
        [3] = vector4(1380.34, -1329.07, 77.64, 176.64), -- Rhodes
        [4] = vector4(-1801.48, -354.12, 164.13, 222.05), -- Strawberry
        [5] = vector4(-769.05, -1254.9, 43.4, 358.53) -- Blackwater
    },
    ["armory"] = {
        [1] = vector3(1361.16, -1305.7, 77.76), -- Rhodes
        [2] = vector3(2494.53, -1304.32, 48.95), -- Saint Denis
        [3] = vector3(-764.86, -1272.4, 44.04), -- Blackwater
        [4] = vector3(-1814.01, -354.93, 164.65), -- Strawberry
        [5] = vector3(-278.38, 805.15, 119.38), --valentine
    },
    ["evidence"] = {
        [1] = vector3(1361.39, -1303.77, 77.77), -- Rhodes
        [2] = vector3(2494.44, -1313.39, 48.95), -- Saint Denis
        [3] = vector3(-761.98, -1272.62, 44.05), -- Blackwater
        [4] = vector3(-1812.43, -355.87, 164.65), -- Strawberry
        [5] = vector3(-278.61, 807.48, 119.38) --valentine
    },
    ["stations"] = {
        -- label = locale key (locales/{ar,en}.json), translated when the blip is built
        [1] = {label = "blip.sheriff", coords = vector3(1360.88, -1301.53, 77.77)}, -- Rhodes
        [2] = {label = "blip.sheriff_hq", coords = vector3(2501.83, -1309.04, 48.95)}, -- Saint Denis
        [3] = {label = "blip.sheriff", coords = vector3(-760.47, -1269.14, 44.04)}, -- Blackwater
        [4] = {label = "blip.sheriff", coords = vector3(-1810.57, -350.91, 164.66)}, -- Strawberry
        [5] = {label = "blip.sheriff", coords = vector3(-275.65, 808.62, 119.38)}, --valentine
    },
}

-- Wagons the lawmen can take out of the station garage, per job grade.
-- model (an RDR2 wagon) = locale key of the label shown in the garage menu
Config.AuthorizedVehicles = {
	-- Grade 0
	[0] = {
		["policewagon01x"] = "vehicle.police_wagon",
	},
	-- Grade 1
	[1] = {
		["policewagon01x"] = "vehicle.police_wagon",
	},
	-- Grade 2
	[2] = {
		["policewagon01x"] = "vehicle.police_wagon",
	},
	-- Grade 3
	[3] = {
		["policewagon01x"] = "vehicle.police_wagon",
	},
	-- Grade 4
	[4] = {
		["policewagon01x"] = "vehicle.police_wagon",
	}
}

-- Filled at start from the framework weapon catalogue (hash -> name / label / ammo item)
Config.WeaponHashes = {}

Config.Items = {
    label = "menu.pol_armory", -- locale key
    slots = 6,
    items = {
        {
            name = "weapon_revolver_cattleman",
            price = 0,
            amount = 1,
            info = {
                serie = "",
            },
            type = "weapon",
            slot = 1,
            authorizedJobGrades = {0, 1, 2, 3, 4}
        },
        {
            name = "weapon_repeater_winchester",
            price = 0,
            amount = 1,
            info = {
                serie = "",
            },
            type = "weapon",
            slot = 2,
            authorizedJobGrades = {0, 1, 2, 3, 4}
        },
        {
            name = "weapon_melee_lantern",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 3,
            authorizedJobGrades = {0, 1, 2, 3, 4}
        },
        {
            name = "weapon_lasso",
            price = 0,
            amount = 1,
            info = {},
            type = "weapon",
            slot = 4,
            authorizedJobGrades = {0, 1, 2, 3, 4}
        },
        {
            name = "ammo_revolver",
            price = 0,
            amount = 5,
            info = {},
            type = "item",
            slot = 5,
            authorizedJobGrades = {0, 1, 2, 3, 4}
        },
        {
            name = "ammo_repeater",
            price = 0,
            amount = 5,
            info = {},
            type = "item",
            slot = 6,
            authorizedJobGrades = {0, 1, 2, 3, 4}
        },
    }
}

---------------------------------------------

-- The prison (Sisika). A sentence is counted in months; the server takes one month off every
-- monthSeconds of play and lets the man out at Saint Denis when it reaches 0 (server/main.lua,
-- "the prison"). Until 2026-10-14 there was no prison at all: SendToJail fired prison:client:Enter
-- and nothing listened, so a sentence was a number on the file and the man walked off.
-- 2026-11-12: the old cell (3425, -610) was in the water outside the walls and the release point's ground
-- search started 25 m up, so it found the HQ roof. Both points now come from measured jail configs.
-- If a prisoner lands wrong, stand where they
--    should be and replace `cell` (the ground height is looked up under the point anyway).
Config.Prison = {
    cell = vector4(3357.41, -679.26, 46.26, 165.59),     -- Sisika, the middle of the yard (inside the walls)
    release = vector4(2491.12, -1309.90, 48.86, 90.0),   -- Saint Denis, on the street by the sheriff's office
    radius = 150.0,      -- metres from `cell`: walk out of it and you are brought back
    monthSeconds = 60,   -- one month of sentence = one minute of play
    maxMonths = 120,     -- the longest sentence a lawman (or the MDT) can hand out
}

-- The largest fine one bill can take (police:server:BillPlayer). There was no ceiling: a lawman
-- standing next to a man could bill his whole bank account into the police society.
Config.MaxFine = 5000

-- 1.0.6 (2026-11-01, owner): the card's fine also needs a reason of at least `reasonMin` letters (it is
-- written on the man's MDT record), and one officer may fine the same man once every `cooldownMinutes`.
Config.Fine = { reasonMin = 3, cooldownMinutes = 5 }

-- 1.0.6: a robbery (the civilian card on a man with his hands up, cuffed or down) took ALL the cash he
-- carried. Now it takes `share` of it (0.5 = half) and never more than `max` dollars, and the same robber
-- may rob the same man once every `cooldownMinutes`. Every robbery and its amount goes to w_logs.
Config.Robbery = { share = 0.5, max = 500, cooldownMinutes = 30 }

---------------------------------------------

local function normalizeItemSlot(row)
    if type(row) ~= 'table' then return nil end
    if row.info == nil and type(row.metadata) == 'table' then
        row.info = row.metadata
    end
    return row
end

WCore = {
    Shared = {
        GetWeapons = function()
            return exports.w_lib:FwGetSharedWeapons() or {}
        end,
        GetItem = function(name)
            return exports.w_lib:FwGetSharedItem(name)
        end,
    },
    Functions = {},
    Commands = {},
}

if IsDuplicityVersion() then
    local function wrapPlayer(pd, isOffline)
        if type(pd) ~= 'table' or (not pd.citizenid and not pd.source) then return nil end
        local src = pd.source
        local cid = pd.citizenid
        return {
            PlayerData = pd,
            Functions = {
                SetMetaData = function(key, val)
                    pd.metadata = pd.metadata or {}
                    pd.metadata[key] = val
                    if isOffline or not src then
                        return exports.w_lib:FwSetOfflineMetadata(cid, { [key] = val })
                    end
                    return exports.w_lib:FwSetMetadata(src, key, val)
                end,
                AddItem = function(item, amount, _slot, info)
                    if isOffline or not src then return false end
                    return exports.w_lib:InvAddItem(src, item, amount or 1, info)
                end,
                RemoveItem = function(item, amount, slot)
                    if isOffline or not src then return false end
                    return exports.w_lib:InvRemoveItem(src, item, amount or 1, nil, slot)
                end,
                GetItemByName = function(item)
                    if isOffline or not src then return nil end
                    return normalizeItemSlot(exports.w_lib:InvGetSlotWithItem(src, item))
                end,
                GetItemBySlot = function(slot)
                    if isOffline or not src then return nil end
                    return normalizeItemSlot(exports.w_lib:InvGetSlot(src, slot))
                end,
                Save = function()
                    if isOffline or not src then return true end
                    return exports.w_lib:FwSavePlayer(src)
                end,
            },
        }
    end

    WCore.Functions.GetPlayer = function(src)
        return wrapPlayer(exports.w_lib:FwGetPlayerData(src), false)
    end
    WCore.Functions.GetWPlayers = function()
        local out = {}
        for src, pd in pairs(exports.w_lib:FwGetOnlinePlayers() or {}) do
            local wrapped = wrapPlayer(pd, false)
            if wrapped then out[src] = wrapped end
        end
        return out
    end
    WCore.Functions.GetOfflinePlayerByCitizenId = function(cid)
        return wrapPlayer(exports.w_lib:FwGetOfflinePlayer(cid), true)
    end
    WCore.Functions.CreateCallback = function(name, cb)
        w.callback.register(name, function(src, ...)
            local p = promise.new()
            cb(src, function(...)
                p:resolve(table.pack(...))
            end, ...)
            local res = Citizen.Await(p)
            return table.unpack(res, 1, res.n)
        end)
    end
    WCore.Functions.CreateUseableItem = function(item, cb)
        exports.w_lib:InvRegisterUsableItem(item, false, function(src, data)
            local norm = type(data) == 'table' and normalizeItemSlot(data) or { name = item }
            cb(src, norm)
        end)
    end
    WCore.Commands.Add = function(name, help, params, argsRequired, cb, perm)
        return exports.w_lib:FwAddCommand(name, help, params, argsRequired, cb, perm)
    end
else
    WCore.Functions.GetPlayerData = function(cb)
        local pd = exports.w_lib:FwGetPlayerData() or {}
        if type(cb) == 'function' then cb(pd) end
        return pd
    end
    WCore.Functions.HasItem = function(item, amount)
        return exports.w_lib:InvHasItem(item, amount or 1)
    end
    WCore.Functions.Notify = function(msg, kind, duration)
        if type(msg) == 'table' then
            w.notify({ title = msg.text, description = msg.caption, type = kind or 'inform', duration = duration })
        else
            w.notify({ description = tostring(msg or ''), type = kind or 'inform', duration = duration })
        end
    end
    WCore.Functions.Progressbar = function(_name, label, duration, useWhileDead, canCancel, disableControls, animation, _prop, _propTwo, onFinish, onCancel)
        CreateThread(function()
            local disable = type(disableControls) == 'table' and {
                move = disableControls.disableMovement == true,
                car = disableControls.disableVehicleMovement == true,
                mouse = disableControls.disableMouse == true,
                combat = disableControls.disableCombat == true,
            } or nil
            local anim = (type(animation) == 'table' and animation.animDict and animation.anim) and {
                dict = animation.animDict,
                clip = animation.anim,
                flag = animation.flags,
            } or nil
            local done = w.progressBar({
                duration = tonumber(duration) or 1000,
                label = label or '',
                useWhileDead = useWhileDead == true,
                canCancel = canCancel ~= false,
                disable = disable,
                anim = anim,
            })
            if done then
                if type(onFinish) == 'function' then onFinish() end
            else
                if type(onCancel) == 'function' then onCancel() end
            end
        end)
    end
    WCore.Functions.TriggerCallback = function(name, cb, ...)
        local args = table.pack(...)
        CreateThread(function()
            local res = table.pack(w.callback.await(name, false, table.unpack(args, 1, args.n)))
            if type(cb) == 'function' then
                cb(table.unpack(res, 1, res.n))
            end
        end)
    end
end