--[[
    One prompt card at a time.

    Every interaction of this resource is a library proximity card (w.prompt.at / atEntity).
    The library draws one group at a time and its records do not arbitrate between themselves:
    when two of them are inside at once (a lawman at the duty point beside another player, a
    handful of casings dropped on the same spot, two station points whose reach overlaps) the
    record that displayed last wins and the other still believes it is on screen until the
    player walks away from it. Every card built here is registered with a priority; every tick
    the best candidate (highest priority, then the closest) is the only one kept up and the
    others are suspended for as long as they overlap it.
]]

CARD_CARRY = 4       -- put down the person already being carried
CARD_STATION = 3     -- station points (duty, garage, stash, armory, evidence drawer)
CARD_EVIDENCE = 2    -- evidence lying on the ground
CARD_PLAYER = 1      -- the card that follows the closest player

local cards = {}            -- rec → priority

---Nothing else owns the screen: no NUI focus, menu, context menu, dialog or progress bar.
---Part of every card's canInteract, so a card never sits under an open inventory or menu.
---@return boolean
function ScreenIsFree()
    if IsNuiFocused() then return false end
    if w.getOpenMenu() or w.getOpenContextMenu() or w.progressActive() then return false end
    return true
end

---Register a library prompt record with the arbiter; rec.remove() unregisters it.
---@param rec table record of w.prompt.at / w.prompt.atEntity
---@param priority integer CARD_STATION / CARD_EVIDENCE / CARD_PLAYER
---@return table rec
function TrackCard(rec, priority)
    cards[rec] = priority
    local remove = rec.remove
    function rec.remove()
        cards[rec] = nil
        remove()
    end
    return rec
end

---Metres between the player and the card (a point's measured distance, or the entity's).
---@param rec table
---@return number
local function CardDistance(rec)
    if rec.point then return rec.point.currentDistance or math.huge end
    if rec.entity and DoesEntityExist(rec.entity) then
        return #(GetEntityCoords(cache.ped) - GetEntityCoords(rec.entity))
    end
    return math.huge
end

---The card is inside its range and allowed to show.
---@param rec table
---@return boolean
local function WantsScreen(rec)
    if not rec.inside then return false end
    return not rec.canInteract or rec.canInteract() == true
end

CreateThread(function()
    while true do
        Wait(100)
        if next(cards) then
            local winner, bestPriority, bestDistance
            for rec, priority in pairs(cards) do
                if WantsScreen(rec) then
                    local distance = CardDistance(rec)
                    if not winner or priority > bestPriority or (priority == bestPriority and distance < bestDistance) then
                        winner, bestPriority, bestDistance = rec, priority, distance
                    end
                end
            end

            -- only a card that overlaps the winner is held back; a record is never left
            -- suspended once the player has walked out of it (its next entry would be lost)
            for rec in pairs(cards) do
                local hold = rec.inside == true and rec ~= winner
                if (rec.suspended or false) ~= hold then rec.suspend(hold) end
            end

            -- a card that displayed after the winner pushed it off the screen: bring it back
            if winner and winner.shown and not winner.group.isVisible() then
                winner.suspend(true)
                winner.suspend(false)
            end
        end
    end
end)
