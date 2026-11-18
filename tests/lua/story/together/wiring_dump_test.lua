-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop story and coop-story.txt through main.lua (fixture.lua; story/together/snapshot_test tests the dump itself): the
-- module built with the mod folder and an [ST] logger; the command's words handed over and its result logged as OK or
-- STOP; the 250 ms loop's poll told whether a world is loaded, its result logged, and nothing logged when it says
-- nothing; no poll after coop off, which refuses the command too; coop story left out of the usage line.
dofile('tests/lua/main/fixture.lua')
settings_text,status_text,in_world,at_title='',plain,true,false
load_main(true)
assert(st.o and st.o.folder=='mod/StellarCoop',tostring(st.o and st.o.folder))
st.o.log('candidate x')
assert(last()=='[StellarCoop][ST] candidate x\n',last())
coop('story')
assert(#st.cmds==1 and st.cmds[1][1]==nil and last()=='[StellarCoop] OK: st nil\n',last())
coop('story','find','x')
assert(st.cmds[2][1]=='find' and st.cmds[2][2]=='x' and last()=='[StellarCoop] OK: st find\n')
-- The poll, each 250 ms: in a world, then at the title and while loading.
local lines=#printed
quarter()
assert(st.polls[#st.polls]==true)
for i=lines+1,#printed do assert(not printed[i]:find('st nil',1,true) and not printed[i]:find(' OK: nil',1,true)) end
in_world,at_title=false,true
quarter()
assert(st.polls[#st.polls]==false)
in_world,at_title=false,false
quarter()
assert(st.polls[#st.polls]==false)
in_world=true
st.says={false,'cannot remove mod/StellarCoop\\coop-story.txt: Permission denied'}
quarter()
assert(logged('STOP: cannot remove mod/StellarCoop\\coop-story.txt: Permission denied'))
st.says={true,'82 story lines written to mod/StellarCoop\\StellarCoopStory.txt'}
quarter()
assert(logged('OK: 82 story lines written to mod/StellarCoop\\StellarCoopStory.txt'))
coop('nope')
assert(not last():find('story',1,true),'Not in the usage line')
-- coop off: no more polls, and the command is refused.
coop('off')
local polls=#st.polls
quarter(); quarter()
assert(#st.polls==polls,'No poll after coop off')
coop('story')
assert(#st.cmds==2 and last()=='[StellarCoop] STOP: coop off is active until the game restarts\n',last())
io.stdout:write('main story_test ok\n')
