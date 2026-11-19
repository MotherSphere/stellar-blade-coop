-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/actors.lua: the Doro look's assets by key, its reload counts starting at 0 and the display helpers
-- online/modes/race/doro_test.lua drives through online/modes/race/doro.lua.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Doro=require('core.actors')
local DIR='/Game/DLC_2/Art/Character/NPC/CH_NPC_Dororong/'
assert(Doro.ASSETS.mesh==DIR..'CH_NPC_Dororong.CH_NPC_Dororong')
assert(Doro.ASSETS.four==DIR..'BlendSpace/IdleRun_BS_Peaceful_1.IdleRun_BS_Peaceful_1')
assert(Doro.reloads.n==0 and Doro.reloads.ms==0)
for _,k in ipairs({'same','resolve','attach','detach','spawn','sweep','remove','apply'}) do
    assert(type(Doro[k])=='function',k)
end
-- The source names no achievement, reward, item, quest, save, possession or console command call; its one SpawnActor
-- spawns a plain /Script/Engine.Actor (online/modes/race/run_test.lua's section 15 checks the race files that reach
-- it).
do
    local f=assert(io.open('mod/StellarCoop/Scripts/core/actors.lua','rb'))
    local src=f:read('a')
    f:close()
    for call in src:gmatch('[:.]([%a_][%w_]*)%s*%(') do
        for _,word in ipairs({'Achiev','Reward','Item','Quest','Save','ExecuteConsoleCommand','Possess','Spawn',
            'CreateActor','Destroy'}) do
            if call:find(word) then assert(call=='SpawnActor' or call:find('^K2_Destroy'),call) end
        end
    end
    local spawns=0
    for class in src:gmatch(':SpawnActor%(find%(\'([^\']+)\'%)') do
        spawns=spawns+1
        assert(class=='/Script/Engine.Actor',class)
    end
    assert(spawns==1 and select(2,src:gsub(':SpawnActor%(',''))==1,'One SpawnActor, of a plain Actor')
    assert(not src:find('ExecuteConsoleCommand') and not src:find('Achievement') and not src:find('Reward'))
end
-- The keep (core/keep.lua): Doro's assets are object paths the keep takes. A path the keep serves comes from it and
-- never reaches LoadAsset, nil when it is not in memory; before the keep settled (or for a path it does not keep)
-- the find and the load as before.
do
    local Keep=require('core.keep')
    for _,p in pairs(Doro.ASSETS) do assert(Keep.path_ok(p),p) end
    Keep.reset()
    local KEPT,GONE,OTHER='/Game/T/Kept.Kept','/Game/T/Gone.Gone','/Game/T/Other.Other'
    local mem,loads={},{}
    local function asset(path)
        return {type=function() return 'UObject' end,IsValid=function() return true end,
            GetFullName=function() return 'AnimSequence '..path end,IsA=function() return true end}
    end
    StaticFindObject=function(p) if p:find('^/Script/') then return asset(p) end return mem[p] end
    LoadAsset=function(p) loads[#loads+1]=p; mem[p]=asset(p); return mem[p] end
    local kst='engine=on keep=0 0 0'
    Keep.setup({write=function() return true end,status=function() return kst end,log=function() end,
        find=function(p) return mem[p],true end})
    Keep.want({KEPT,GONE})
    Keep.slow()
    assert(Doro.resolve(KEPT)~=nil and #loads==1 and loads[1]==KEPT,'Before the keep settled: as before')
    mem[GONE]=nil
    kst='engine=on keep=2 2 1'
    Keep.slow()
    loads={}
    assert(Doro.resolve(KEPT)==mem[KEPT] and Doro.resolve(GONE)==nil and #loads==0,'The keep serves them: no load')
    assert(Doro.resolve(OTHER)~=nil and loads[1]==OTHER,'A path the keep does not hold: as before')
    Keep.reset()
end
print('core/actors_test: ok')
