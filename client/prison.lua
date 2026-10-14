-- ── the prison (Sisika) ─────────────────────────────────────────────────────────────────
-- The server holds the sentence (metadata 'injail', counted down in server/main.lua "the prison")
-- and decides when a man goes in and comes out. This file only moves him: into the yard on
-- prison:client:Enter (SendToJail, w_mdt, or the server bringing back a man who left the walls),
-- and out to Saint Denis on prison:client:UnjailPerson. Until 2026-10-14 nothing listened to
-- either event, so a jailed man stayed where he stood.

local jailed = false

--- The ground under (x, y), searched from a little above the stored height: the stored z may sit
--- a few metres off on this map. nil when the collision did not load in time.
local function groundAt(x, y, z)
    local ped = cache.ped
    RequestCollisionAtCoord(x, y, z)
    local deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 25.0, false)
    if found then return groundZ end
    return nil
end

local function moveTo(pos)
    if not pos then return end
    DoScreenFadeOut(600)
    local deadline = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end

    local ped = cache.ped
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    local z = groundAt(pos.x, pos.y, pos.z)
    if z then SetEntityCoords(ped, pos.x, pos.y, z, false, false, false, false) end
    if pos.w then SetEntityHeading(ped, pos.w) end

    Wait(250)
    DoScreenFadeIn(600)
end

RegisterNetEvent('prison:client:Enter', function(months, returned)
    local P = Config.Prison or {}
    if not P.cell then return end
    jailed = true
    moveTo(P.cell)
    months = math.ceil(tonumber(months) or 0)
    WCore.Functions.Notify(locale(returned and 'info.prison_returned' or 'info.prison_entered', months),
        returned and 'error' or 'inform')
end)

RegisterNetEvent('prison:client:UnjailPerson', function()
    local P = Config.Prison or {}
    local wasJailed = jailed
    jailed = false
    -- inside the walls (brought in this session, or a login that landed him back in the yard): out
    -- to Saint Denis -- Sisika is an island. Released while elsewhere (an officer's /unjail before
    -- he was ever brought in): he stays where he stands.
    local inside = P.cell and #(GetEntityCoords(cache.ped) - vector3(P.cell.x, P.cell.y, P.cell.z)) <= (tonumber(P.radius) or 150.0)
    if wasJailed or inside then moveTo(P.release) end
end)

--- Down, or in a hospital bed (w_medic): not the moment to be carried back to the yard --
--- the server brings him back once he is up and about again.
local function inMedicalCare()
    if GetResourceState('w_medic') ~= 'started' then return IsEntityDead(cache.ped) end
    local ok, care = pcall(function()
        return exports.w_medic:IsDead() or exports.w_medic:InHospitalBed()
    end)
    return (ok and care == true) or IsEntityDead(cache.ped)
end

-- The walls, on this side: a man who walks out is put back at once. The server checks again
-- every month of the sentence, so a client that skips this is still brought back.
CreateThread(function()
    while true do
        Wait(2000)
        local P = Config.Prison
        if jailed and P and P.cell and not inMedicalCare() then
            local here = GetEntityCoords(cache.ped)
            if #(here - vector3(P.cell.x, P.cell.y, P.cell.z)) > (tonumber(P.radius) or 150.0) then
                moveTo(P.cell)
            end
        end
    end
end)
