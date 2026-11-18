-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- core/actors.lua: the Doro look's assets by key, its reload counts starting at 0 and the display helpers
-- race/doro_test.lua drives through race/doro.lua.
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
-- spawns a plain /Script/Engine.Actor (race/run_test.lua's section 15 checks the race files that reach it).
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
print('core/actors_test: ok')
