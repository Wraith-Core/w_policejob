"""Run both sides of the scripted shoulder carry in Lua, without a RedM client."""
from pathlib import Path
import unittest

from lupa import lua54


ROOT = Path(__file__).resolve().parents[1]

# The rider and patient have different server IDs, player indices and ped handles.
# The mock deliberately does not drag an attached child by itself: release must
# use the actual carrier's current position even if the last patient position is old.
WORLD = """
local function ignore() end
PATIENT, RIDER, HORSE = 100, 200, 300
PATIENT_ID, RIDER_ID = 10, 20
local indices = { [PATIENT_ID] = 1, [RIDER_ID] = 2 }
local peds = { [1] = PATIENT, [2] = RIDER }
positions = { [PATIENT] = {x=0,y=0,z=3}, [RIDER] = {x=1,y=0,z=3}, [HORSE] = {x=2,y=0,z=3} }
parent, attachedToBone, mounts, events, serverCalls = {}, {}, {}, {}, {}
animations, taskClears = {}, {}
now, attachCount = 0, 0
isHandcuffed, isEscorted, cuffType = false, false, 'none'
metadata = {isdead=true, inlaststand=false}
cache = {ped=PATIENT, playerId=1}
Config = {Keys={carry='F'}}
LocalPlayer = {state={isLoggedIn=true, set=function(self,k,v) self[k] = v end}}
PlayerJob = {name='civilian'}
function locale(key) return key end
function PlayerPedId() return cache.ped end
function PlayerId() return cache.playerId end
function Player() return { state={isDead=true} } end
function GetPlayerFromServerId(id) return indices[id] or -1 end
function GetPlayerServerId(index) return index == 1 and PATIENT_ID or RIDER_ID end
function GetPlayerPed(index) return peds[index] or 0 end
function NetworkIsPlayerActive(index) return peds[index] and 1 or 0 end
function DoesEntityExist(ped) return positions[ped] and 1 or 0 end
function IsEntityDead(ped) return ped == PATIENT and metadata.isdead and 1 or 0 end
function IsPedOnMount(ped) return mounts[ped] and 1 or 0 end
function GetMount(ped) return mounts[ped] or 0 end
function IsEntityAttachedToEntity(ped, other) return parent[ped] == other and 1 or 0 end
function IsEntityAttached(ped) return parent[ped] and 1 or 0 end
function GetEntityAttachedTo(ped) return parent[ped] or 0 end
function GetEntityBoneIndexByName(ped, name)
    if ped == RIDER and name == 'PH_L_CarriableShoulder' then return 11 end
    if ped == HORSE and name == 'PH_Carriable' then return 12 end
    if ped == HORSE and name == 'SKEL_RearSeat' then return 13 end
    return -1
end
function AttachEntityToEntity(ped, other, bone)
    assert(ped == PATIENT, 'only the local patient should be attached')
    parent[ped], attachedToBone[ped] = other, bone
    attachCount = attachCount + 1
end
function DetachEntity(ped) parent[ped] = nil end
local xyz = {}
xyz.__sub = function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z}, xyz) end
xyz.__len = function(a) return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z) end
function GetEntityCoords(ped) return setmetatable(assert(positions[ped], 'unknown ped position'), xyz) end
function GetOffsetFromEntityInWorldCoords(ped, x, y, z)
    local p = GetEntityCoords(ped)
    return {x=p.x+x, y=p.y+y, z=p.z+z}
end
function SetEntityCoords(ped,x,y,z)
    positions[ped] = type(x) == 'table' and x or {x=x,y=y,z=z}
end
SetEntityCoordsNoOffset = SetEntityCoords
function GetGroundZFor_3dCoord() return true, 3.0 end
function HasAnimDictLoaded() return true end
function IsEntityPlayingAnim(ped, dict, clip) return animations[ped] == clip and 1 or 0 end
function TaskPlayAnim(ped, dict, clip) animations[ped] = clip end
function ClearPedTasksImmediately(ped)
    animations[ped] = nil
    taskClears[ped] = (taskClears[ped] or 0) + 1
end
ClearPedTasks = ClearPedTasksImmediately
function StopAnimTask(ped,dict,clip) if animations[ped] == clip then animations[ped] = nil end end
ClearPedSecondaryTask, RequestAnimDict, SetEnableHandcuffs = ignore, ignore, ignore
function FreezeEntityPosition(ped, yes) frozen = yes end
function GetGameTimer() return now end
function Wait(ms) now = now + math.max(ms, 1) end
function RegisterNetEvent(name, fn) events[name] = fn end
AddEventHandler = RegisterNetEvent
function TriggerServerEvent(name, ...) table.insert(serverCalls, {name, ...}) end
TriggerEvent, exports, CreateThread = ignore, ignore, ignore
function IsNuiFocused() return false end
function SetEscorted(on) isEscorted = on end
WCore = {Functions={GetPlayerData=function(cb)
    local data = {metadata=metadata}
    if cb then cb(data) end
    return data
end}}
w = {
    stopped=ignore,
    getOpenMenu=ignore, getOpenContextMenu=ignore, progressActive=ignore,
    getClosestPlayer=function() error('must release the paired patient without a nearest-player search') end,
    prompt={atEntity=function(ped, opts)
        card = {ped=ped, opts=opts, remove=function() card=nil end}
        return card
    end}
}
"""


def runtime(rider=False):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(WORLD)
    if rider:
        lua.execute("cache.ped, cache.playerId = RIDER, 2")
    for name in ('shared/carry.lua', 'client/carry.lua', 'client/cards.lua', 'client/interactions.lua'):
        source = (ROOT / name).read_text(encoding='utf-8-sig')
        # Cfx's compile-time hash literal in the unrelated handcuff handler.
        lua.execute(source.replace('`WEAPON_UNARMED`', '0xA2719263'), name=name)
    return lua


class PatientCarryClient(unittest.TestCase):
    def test_owner_keeps_patient_on_the_correct_parent_through_a_ride(self):
        lua = runtime()
        lua.execute("events[PoliceCarryEvents.target](RIDER_ID, true, 7)")
        self.assertEqual(lua.eval('parent[PATIENT]'), 200)
        self.assertEqual(lua.eval('attachedToBone[PATIENT]'), 11)
        lua.execute("mounts[RIDER] = HORSE; now=now+1000; PoliceCarryTarget.tick()")
        self.assertEqual(lua.eval('parent[PATIENT]'), 300)
        self.assertEqual(lua.eval('attachedToBone[PATIENT]'), 12)
        self.assertIsNone(lua.eval('animations[PATIENT]'))
        lua.execute("parent[PATIENT] = nil; now=now+1000; PoliceCarryTarget.tick()")
        self.assertEqual(lua.eval('parent[PATIENT]'), 300)
        lua.execute("mounts[RIDER] = nil; now=now+1000; PoliceCarryTarget.tick()")
        self.assertEqual(lua.eval('parent[PATIENT]'), 200)
        self.assertTrue(lua.eval('metadata.isdead'))

    def test_living_cuffed_passenger_keeps_the_injured_pose(self):
        lua = runtime()
        lua.execute("""
            metadata.isdead, isHandcuffed, cuffType = false, true, CUFF_HARD
            events[PoliceCarryEvents.target](RIDER_ID, true, 7)
        """)
        self.assertEqual(lua.eval('animations[PATIENT]'), 'carriedbyhuman_exp')
        self.assertFalse(lua.eval('frozen'))
        lua.execute("mounts[RIDER]=HORSE; now=now+150; PoliceCarryTarget.tick()")
        self.assertEqual(lua.eval('attachedToBone[PATIENT]'), 13)
        self.assertEqual(lua.eval('animations[PATIENT]'), 'carriedbymount_exp')
        self.assertTrue(lua.eval('isHandcuffed'))
        lua.execute("""
            mounts[RIDER] = nil
            now=now+150; PoliceCarryTarget.tick()
            positions[PATIENT] = {x=1.3,y=0.4,z=3.5}
            events[PoliceCarryEvents.target](RIDER_ID, false, 7, true)
        """)
        self.assertEqual(lua.eval('positions[PATIENT].x'), 1.3)
        self.assertEqual(lua.eval('positions[PATIENT].y'), 0.4)
        self.assertAlmostEqual(lua.eval('positions[PATIENT].z'), 3.1)

    def test_release_drops_the_actual_patient_at_the_destination(self):
        lua = runtime()
        lua.execute("""
            events[PoliceCarryEvents.target](RIDER_ID, true, 7)
            mounts[RIDER] = HORSE
            for i=1,90 do
                positions[HORSE] = {x=9*i,y=3*i,z=4}
                positions[RIDER] = positions[HORSE]
                now=now+150; PoliceCarryTarget.tick()
            end
            positions[PATIENT] = {x=0,y=0,z=3}
            events[PoliceCarryEvents.target](RIDER_ID, false, 6, true)
        """)
        self.assertEqual(lua.eval('parent[PATIENT]'), 300)
        lua.execute("events[PoliceCarryEvents.target](RIDER_ID, false, 7, true)")
        self.assertIsNone(lua.eval('parent[PATIENT]'))
        self.assertFalse(lua.eval('isEscorted'))
        self.assertLess(abs(lua.eval('positions[PATIENT].x') - 810), 4)
        self.assertLess(abs(lua.eval('positions[PATIENT].y') - 270), 4)
        self.assertAlmostEqual(lua.eval('positions[PATIENT].z'), 3.1)
        self.assertTrue(lua.eval('metadata.isdead'))
        lua.execute("now=now+1000; PoliceCarryTarget.tick()")
        self.assertIsNone(lua.eval('parent[PATIENT]'))

    def test_late_put_down_cannot_undo_a_hospital_revive(self):
        lua = runtime()
        lua.execute("""
            events[PoliceCarryEvents.target](RIDER_ID, true, 7)
            events['hospital:client:Revive']()
            metadata.isdead = false
            positions[PATIENT] = {x=300,y=200,z=9}
            events[PoliceCarryEvents.target](RIDER_ID, false, 7, true)
            now=now+150; PoliceCarryTarget.tick()
        """)
        self.assertIsNone(lua.eval('parent[PATIENT]'))
        self.assertEqual(lua.eval('positions[PATIENT].x'), 300)
        self.assertFalse(lua.eval('PoliceCarryTarget.active()'))
        self.assertEqual(lua.eval('serverCalls[1][2]'), 7)
        self.assertFalse(lua.eval('serverCalls[1][3]'))

    def test_late_pickup_after_revive_does_not_attach_the_player(self):
        lua = runtime()
        lua.execute("metadata.isdead=false; events[PoliceCarryEvents.target](RIDER_ID, true, 7)")
        self.assertFalse(lua.eval('PoliceCarryTarget.active()'))
        self.assertIsNone(lua.eval('parent[PATIENT]'))
        self.assertFalse(lua.eval('isEscorted'))
        self.assertEqual(lua.eval('serverCalls[1][2]'), 7)

    def test_existing_foot_escort_is_preserved_when_pickup_arrives(self):
        lua = runtime()
        lua.execute("isEscorted=true; events[PoliceCarryEvents.target](RIDER_ID, true, 7)")
        self.assertFalse(lua.eval('PoliceCarryTarget.active()'))
        self.assertTrue(lua.eval('isEscorted'))
        self.assertEqual(lua.eval('attachCount'), 0)

    def test_lost_carrier_cancels_in_place(self):
        lua = runtime()
        lua.execute("""
            events[PoliceCarryEvents.target](RIDER_ID, true, 7)
            positions[RIDER] = nil
            now=now+150; PoliceCarryTarget.tick()
            now=now+3100; PoliceCarryTarget.tick()
            events[PoliceCarryEvents.target](RIDER_ID, false, 7, true)
        """)
        self.assertFalse(lua.eval('PoliceCarryTarget.active()'))
        self.assertEqual(lua.eval('positions[PATIENT].x'), 0)
        self.assertFalse(lua.eval('isEscorted'))
        self.assertFalse(lua.eval('serverCalls[1][3]'))

    def test_rider_has_a_release_action_independent_of_the_patient_position(self):
        lua = runtime(rider=True)
        lua.execute("events[PoliceCarryEvents.carrier](PATIENT_ID, true, 7)")
        self.assertEqual(lua.eval('card.ped'), 200)
        self.assertEqual(lua.eval('card.opts.prompts[1].key'), 'F')
        lua.execute("""
            mounts[RIDER] = HORSE
            positions[RIDER] = {x=810,y=290,z=4}
            events[PoliceCarryEvents.carrier](PATIENT_ID, false, 6)
            assert(card.opts.canInteract(), 'the mounted rider can use the card')
            card.opts.prompts[1].onComplete()
            events['police:client:EscortPlayer']()
        """)
        self.assertEqual(lua.eval('serverCalls[1][1]'), 'police:server:ReleaseCarry')
        self.assertEqual(lua.eval('serverCalls[1][2]'), 7)
        self.assertEqual(lua.eval('serverCalls[2][2]'), 7)
        lua.execute("events[PoliceCarryEvents.carrier](PATIENT_ID, false, 7)")
        self.assertIsNone(lua.eval('card'))
        self.assertIsNone(lua.eval('taskClears[RIDER]'))


if __name__ == '__main__':
    unittest.main()
