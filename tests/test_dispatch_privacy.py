"""Local execution of the resource's real privacy and dispatch handlers; no game or database."""
from pathlib import Path
import unittest
from lupa import lua54

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'server/main.lua').read_text(encoding='utf-8-sig')

STUB = '''
NOW=1000; E={}; H={}; Config={ShowBlips=true}; source=4
function GetGameTimer() return NOW end
function GetPlayerPed(id) return id==99 and 0 or id end
function GetEntityCoords(id) return {x=id,y=0,z=0} end
function GetEntityHeading() return 0 end
function GetPlayerRoutingBucket(id) return id==3 and 2 or 1 end
function TriggerClientEvent(name,target,...) E[#E+1]={name=name,target=target,args={...}} end
function RegisterNetEvent(name,fn) H[name]=fn end
function AddEventHandler() end
function locale(key,...) if key=='info.test' then return string.format('Call %s',...) end return key end
PLAYERS={}
local roles={'police','doctor','police','citizen','police'}
for id,job in ipairs(roles) do PLAYERS[id]={PlayerData={source=id,job={name=job,onduty=id~=5},metadata={callsign='Unit'}}} end
WCore={Functions={GetWPlayers=function() return PLAYERS end}}
'''

def context():
    runtime=lua54.LuaRuntime(unpack_returned_tuples=True)
    runtime.execute(STUB)
    return runtime

class DispatchPrivacy(unittest.TestCase):
    def test_locations_reach_only_duty_viewers_in_their_bucket(self):
        lua=context()
        chunk=SOURCE[SOURCE.index('local function UpdateBlips()'):SOURCE.index('local function CreateBloodId()')]
        lua.execute(chunk+'\nUpdateBlips()')
        events=lua.globals().E
        self.assertEqual(len(events),3)
        self.assertEqual({events[i]['target'] for i in range(1,4)},{1,2,3})
        for i in range(1,4):
            event=events[i]
            ids={row['source'] for _,row in event['args'][1].items()}
            self.assertEqual(ids,{3} if event['target']==3 else {1,2})

    def load_dispatch(self):
        lua=context()
        begin=SOURCE.index('-- Dispatch accepts')
        end=SOURCE.index('-- ── acting on',begin)
        lua.execute(SOURCE[begin:end])
        return lua

    def test_dispatch_accepts_existing_formats_and_filters_recipients(self):
        lua=self.load_dispatch()
        lua.execute("H['police:server:policeAlert']('Emergency')")
        self.assertEqual(len(lua.globals().E),1)
        self.assertEqual(lua.globals().E[1]['target'],1)
        lua.execute("NOW=5000; H['police:server:policeAlert']({key='info.test',args={'Town'}})")
        self.assertEqual(len(lua.globals().E),2)

    def test_dispatch_rejects_bad_shapes_and_bounds_repetition(self):
        lua=self.load_dispatch()
        lua.execute("for _,v in ipairs({42,{}, {key='missing'}, {key='info.test',args={{}}}, {key='info.test',args={[1]='a',[3]='b'}}, string.rep('x',501)}) do H['police:server:policeAlert'](v) end")
        self.assertEqual(len(lua.globals().E),0)
        lua.execute("for i=1,50 do H['police:server:policeAlert']('Emergency') end")
        self.assertEqual(len(lua.globals().E),1)
        lua.execute("NOW=5000; source=99; H['police:server:policeAlert']('Emergency')")
        self.assertEqual(len(lua.globals().E),1)

if __name__=='__main__': unittest.main()
