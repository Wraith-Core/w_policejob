"""Run the shoulder-carry server events with real reach/permission checks in Lua 5.4."""
from pathlib import Path
import unittest

from lupa import lua54


ROOT = Path(__file__).resolve().parents[1]
STUBS = """
local function noop() end
local handlers = {}
function AddEventHandler(name, handler)
    handlers[name] = handlers[name] or {}
    table.insert(handlers[name], handler)
end
RegisterNetEvent = AddEventHandler
function send(src, name, ...)
    source = src
    for _, handler in ipairs(assert(handlers[name], name)) do handler(...) end
end
events = {}
function TriggerClientEvent(...) table.insert(events, table.pack(...)) end
function locale(key) return key end
function GetGameTimer() return 100 end
CreateThread = noop
Config = {}
w = {print={debug=noop}, notify=noop}
players = {}
local pos = {__sub=function(a,b) return setmetatable({x=a.x-b.x}, getmetatable(a)) end,
             __len=function(a) return math.abs(a.x) end}
function GetPlayerPed(src) return src end
function GetEntityCoords(src) return setmetatable({x=players[src].x}, pos) end
function GetPlayerRoutingBucket(src) return players[src].bucket end
function GetVehiclePedIsIn() return 0 end
function addPlayer(id, x, bucket)
    local data = {source=id, metadata={}, job={name='civilian', onduty=false}}
    players[id] = {x=x, bucket=bucket, PlayerData=data, Functions={
        GetItemByName=function() return true end,
        SetMetaData=function(key,value) data.metadata[key]=value end
    }}
end
WCore = {Commands={Add=noop}, Functions={GetPlayer=function(id) return players[id] end,
    CreateCallback=noop, CreateUseableItem=noop}}
addPlayer(1, 0, 0); addPlayer(2, 1, 0); addPlayer(3, 2, 0); addPlayer(4, 3, 0)
players[2].PlayerData.metadata.inlaststand = true
players[4].PlayerData.metadata.ishandcuffed = true
"""


class PatientCarryServer(unittest.TestCase):
    def setUp(self):
        self.lua = lua54.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(STUBS)
        for name in ('shared/carry.lua', 'server/main.lua'):
            self.lua.execute((ROOT / name).read_text(encoding='utf-8-sig'))
        self.g = self.lua.globals()
        self.names = self.g.PoliceCarryEvents

    def send(self, src, name, *args):
        self.g.send(src, name, *args)

    def events(self):
        return [tuple(e[i] for i in range(1, e.n + 1)) for e in self.g.events.values()]

    def start(self):
        self.send(1, self.names.begin, 2)
        target, carrier = self.events()[-2:]
        token = target[4]
        self.assertIsInstance(token, int)
        self.assertEqual(target[:5], (self.names.target, 2, 1, True, token))
        self.assertEqual(carrier, (self.names.carrier, 1, 2, True, token))
        return token

    def assert_released(self, token, place):
        self.assertEqual(self.events()[-2:], [
            (self.names.target, 2, 1, False, token, place),
            (self.names.carrier, 1, 2, False, token),
        ])

    def test_new_pickups_check_range_bucket_target_and_condition(self):
        self.send(1, self.names.begin, 3)  # upright
        self.send(1, self.names.begin, 1)
        self.send(1, self.names.begin, 99)
        self.lua.execute('players[2].x=6')
        self.send(1, self.names.begin, 2)
        self.lua.execute('players[2].x=1; players[2].bucket=7')
        self.send(1, self.names.begin, 2)
        self.assertEqual(self.events(), [])
        self.lua.execute('players[2].bucket=0')
        self.start()

    def test_duplicate_pickups_and_overlapping_pairs_do_not_toggle(self):
        token = self.start()
        before = self.events()
        for actor, patient in ((1, 2), (3, 2), (1, 4), (2, 4)):
            self.send(actor, self.names.begin, patient)
        self.send(3, self.names.release, token)
        self.assertEqual(self.events(), before)
        self.send(3, self.names.begin, 4)
        self.assertNotEqual(self.events()[-1][4], token)

    def test_cuffed_or_injured_carrier_cannot_begin(self):
        for condition in ('ishandcuffed', 'isdead', 'inlaststand'):
            with self.subTest(condition=condition):
                meta = self.g.players[1].PlayerData.metadata
                meta[condition] = True
                self.send(1, self.names.begin, 2)
                self.assertEqual(self.events(), [])
                meta[condition] = False
        self.start()

    def test_release_from_either_side_is_independent_of_position_and_idempotent(self):
        token = self.start()
        self.lua.execute('players[2].x=600')
        self.send(1, self.names.release, token)
        self.assert_released(token, True)
        self.send(2, self.names.release, token)
        self.assertEqual(len(self.events()), 4)
        self.lua.execute('players[2].x=1')
        newer = self.start()
        self.assertNotEqual(token, newer)
        self.send(1, self.names.release, token)
        self.assertEqual(len(self.events()), 6)
        self.send(2, self.names.release, newer, False)
        self.assert_released(newer, False)

    def test_patient_can_release_across_buckets_without_being_placed_at_carrier(self):
        token = self.start()
        self.lua.execute('players[2].bucket=9')
        self.send(2, self.names.release, token)
        self.assert_released(token, False)

    def test_disconnect_and_character_unload_clear_both_slots(self):
        token = self.start()
        self.send(2, 'playerDropped')
        self.assert_released(token, False)
        token = self.start()
        self.send(0, 'WCore:Server:OnPlayerUnload', 1)
        self.assert_released(token, False)
        self.start()

    def test_authorized_foot_escort_ends_the_shoulder_carry_first(self):
        token = self.start()
        self.send(3, 'police:server:EscortPlayer', 2)
        self.assertEqual(len(self.events()), 2)
        self.send(1, 'police:server:EscortPlayer', 2)
        self.assertEqual(self.events()[-3:], [
            (self.names.target, 2, 1, False, token, False),
            (self.names.carrier, 1, 2, False, token),
            ('police:client:GetEscorted', 2, 1),
        ])

    def test_uncuff_does_not_leave_the_carrier_holding_a_released_player(self):
        self.lua.execute('players[2].PlayerData.metadata.ishandcuffed=true')
        token = self.start()
        self.send(3, 'police:server:CuffPlayer', 2, False)
        self.assertEqual(self.events()[-3:], [
            (self.names.target, 2, 1, False, token, False),
            (self.names.carrier, 1, 2, False, token),
            ('police:client:GetCuffed', 2, 3, False, False),
        ])

    def test_wagon_request_preserves_carry_until_patient_confirms_transfer(self):
        self.lua.execute('players[2].PlayerData.metadata.isdead=true')
        token = self.start()
        self.send(3, 'police:server:PutPlayerInVehicle', 2)
        self.assertEqual(len(self.events()), 2)
        self.lua.execute("players[3].PlayerData.job={name='police',onduty=true}")
        self.send(3, 'police:server:PutPlayerInVehicle', 2)
        self.assertEqual(self.events()[2:], [('police:client:PutInVehicle', 2)])
        self.send(2, self.names.release, token, False)
        self.assert_released(token, False)
