-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The pack catalogue (closet/packs.lua): the DLL's pack list (coop-cns-packs.txt), the read of each pack, the stamp
-- cache, the log said once and the catalogue by UniqueFitID. Samples are written here; no creator's pack is copied.
local run=dofile('tests/lua/closet/run.lua')
local Packs=require('closet.packs')

local PAKS='C:\\SB\\Content\\Paks'
local LIST='C:\\SB\\Binaries\\Win64\\Mods\\StellarCoop\\coop-cns-packs.txt'

local function pack(id,name,extra)
    return ('[{"UniqueFitID":"%s","DisplayName":"%s","OutfitPaths":["/Game/M/A.A"]%s}]'):format(id,name,extra or '')
end

-- A loader on fake files: list = the list file's text (nil: no file), files = {[path from Content\Paks] = text or
-- false for a file io.open cannot open}, copies = {[name] = text} of the DLL's copies beside the list. Returns the
-- loader, the log lines and the reads by full path.
local DIR=LIST:match('^(.*)\\')
local function fake(list,files,copies)
    local env={list_text=list,files=files,copies=copies or {},logs={},reads={}}
    env.loader=Packs.new({paks=PAKS,list=LIST,log=function(m) env.logs[#env.logs+1]=m end,
        read=function(path,limit)
            env.reads[path]=(env.reads[path] or 0)+1
            if path==LIST then
                if env.list_text==nil then return nil,LIST..': No such file or directory',2 end
                return env.list_text
            end
            local text
            if path:sub(1,#DIR+1)==DIR..'\\' then text=env.copies[path:sub(#DIR+2)]
            else text=env.files[path:sub(#PAKS+2)] end
            if not text then return nil,path..': Invalid argument',22 end
            return limit and text:sub(1,limit) or text
        end})
    return env
end

local function count(logs,needle)
    local n=0
    for _,m in ipairs(logs) do if m:find(needle,1,true) then n=n+1 end end
    return n
end

local A='~mods\\A\\a.dekcns.json'
local B='~mods\\B\\b.dekcns.json'

local tests={
    entries_parse_filter_and_sort=function()
        local e=Packs.entries('9 20 ~mods\\Z Pack\\z.dekcns.json\r\n'..
            '123 456 ~mods\\A\\a.dekcns.json\n'..
            'not a line\n'..
            '5 6 ~mods\\CustomNanosuitSystem\\Cosmetics\\DekCNS-Hairs.dekcns.json\n'..
            '7 8 ~mods/CustomNanosuitSystem/Repacked/X/X.dekcns.json\n'..
            '1 2 ~mods\\N\\NoDotDekcns.json\n'..
            '3 4 ~mods\\R\\readme.json\n')
        same(e,{{path='~mods/CustomNanosuitSystem/Repacked/X/X.dekcns.json',size=7,time=8},
            {path='~mods\\A\\a.dekcns.json',size=123,time=456},
            {path='~mods\\N\\NoDotDekcns.json',size=1,time=2},
            {path='~mods\\Z Pack\\z.dekcns.json',size=9,time=20}},'kept, sorted by path, space and case kept')
        same(Packs.entries(''),{},'empty list')
        -- A path the DLL copied (a byte outside ASCII): a tab, then the copy's name; any other name is no copy.
        local U='~mods\\Tenues d\'\195\169t\195\169\\robe.dekcns.json'
        same(Packs.entries('5 6 '..U..'\tcoop-cns-pack-12.json\n7 8 ~mods\\B\\b.dekcns.json\t..\\x.json\n'),
            {{path='~mods\\B\\b.dekcns.json',size=7,time=8},{path=U,size=5,time=6,copy='coop-cns-pack-12.json'}},
            'the copy named, the path without it')
        same(Packs.entries(nil),{},'no text')
    end,
    scan_builds_catalogue_by_unique_fit_id=function()
        local env=fake('1 1 '..A..'\n2 2 '..B..'\n',{[A]=pack('a.suit','Suit A'),[B]=pack('b.hair','Hair B',
            ',"FitMeshType":"Hair"')})
        local cat,report=env.loader.scan()
        eq(cat['a.suit'].DisplayName,'Suit A') eq(cat['a.suit'].File,A,'File') eq(cat['b.hair'].Slot,'Hair')
        eq(env.reads[PAKS..'\\'..A],1,'read at Content\\Paks plus the listed path')
        same({report.packs,report.reused,report.items},{2,0,2},'report') same(report.failed,{},'no failure')
        eq(env.loader.catalogue(),cat,'catalogue() is the last scan')
    end,
    a_copied_pack_is_read_from_its_copy=function()
        -- Lua's io.open cannot open the UTF-8 path (false: the fake refuses it), so the copy beside the list is read;
        -- the pack keeps its own path in the catalogue and the report.
        local U='~mods\\Tenues d\'\195\169t\195\169\\robe.dekcns.json'
        local env=fake('5 6 '..U..'\tcoop-cns-pack-1.json\n1 1 '..A..'\n',{[U]=false,[A]=pack('a.suit','Suit A')},
            {['coop-cns-pack-1.json']=pack('e.robe','Robe')})
        local cat,report=env.loader.scan()
        eq(cat['e.robe'].DisplayName,'Robe') eq(cat['e.robe'].File,U,'File is the pack, not the copy')
        eq(env.reads[DIR..'\\coop-cns-pack-1.json'],1,'the copy read') eq(env.reads[PAKS..'\\'..U],nil,'never the path')
        eq(env.reads[PAKS..'\\'..A],1,'an ASCII path still read in place')
        same({report.packs,report.items},{2,2}) same(report.failed,{},'no failure')
        -- A copy that is missing fails that pack alone, logged once with the copy's name.
        env=fake('5 7 '..U..'\tcoop-cns-pack-1.json\n',{[U]=false},{})
        cat,report=env.loader.scan()
        ok(report.failed[U]) eq(count(env.logs,'coop-cns-pack-1.json'),1,'logged with the copy')
    end,
    catalogue_is_empty_before_the_first_scan=function()
        same(fake('',{}).loader.catalogue(),{})
    end,
    equal_stamp_reuses_without_a_read=function()
        local env=fake('1 1 '..A..'\n',{[A]=pack('a','A')})
        env.loader.scan()
        local cat,report=env.loader.scan()
        eq(env.reads[PAKS..'\\'..A],1,'one read') eq(report.reused,1,'reused') eq(cat.a.DisplayName,'A')
        eq(env.reads[LIST],2,'the list is read at each scan')
    end,
    changed_stamp_rereads=function()
        local env=fake('1 1 '..A..'\n',{[A]=pack('a','Old')})
        env.loader.scan()
        env.list_text='1 2 '..A..'\n' env.files[A]=pack('a','New')
        local cat,report=env.loader.scan()
        eq(env.reads[PAKS..'\\'..A],2,'read again') eq(report.reused,0) eq(cat.a.DisplayName,'New')
        env.list_text='2 2 '..A..'\n' env.files[A]=pack('a','Size')
        eq(env.loader.scan().a.DisplayName,'Size','a size change re-reads too')
    end,
    gone_file_leaves_the_catalogue=function()
        local env=fake('1 1 '..A..'\n1 1 '..B..'\n',{[A]=pack('a','A'),[B]=pack('b','B')})
        env.loader.scan()
        env.list_text='1 1 '..A..'\n'
        local cat,report=env.loader.scan()
        eq(cat.b,nil,'b gone') eq(cat.a.DisplayName,'A') eq(report.packs,1)
    end,
    parse_error_logged_once_per_path_and_stamp=function()
        local env=fake('1 1 '..A..'\n1 1 '..B..'\n',{[A]='[{"UniqueFitID": ',[B]=pack('b','B')})
        local cat,report=env.loader.scan()
        eq(cat.b.DisplayName,'B','the other pack loads') ok(report.failed[A],'failed names the pack')
        env.loader.scan()
        eq(count(env.logs,A..': json'),1,'logged once over two scans')
        env.list_text='1 2 '..A..'\n1 1 '..B..'\n'
        env.loader.scan()
        eq(count(env.logs,A..': json'),2,'a new stamp logs again')
    end,
    entry_errors_are_logged_and_the_good_entries_load=function()
        local env=fake('1 1 '..A..'\n',{[A]='['..pack('a','A'):sub(2,-2)..',{"DisplayName":"no id"}]'})
        local cat,report=env.loader.scan()
        eq(cat.a.DisplayName,'A') eq(report.failed[A],nil,'a pack with one good outfit did not fail')
        eq(count(env.logs,'no UniqueFitID'),1,'the bad entry is logged')
    end,
    duplicate_id_keeps_the_first_and_warns_once=function()
        local env=fake('1 1 '..B..'\n1 1 '..A..'\n',{[A]=pack('same','From A'),[B]=pack('same','From B')})
        local cat,report=env.loader.scan()
        eq(cat.same.DisplayName,'From A','first by sorted path') eq(cat.same.File,A) eq(report.items,1)
        env.loader.scan()
        eq(count(env.logs,'same'),1,'one warning over two scans')
        ok(env.logs[1]:find(A,1,true) and env.logs[1]:find(B,1,true),'it names both files: '..env.logs[1])
    end,
    unopenable_path_logged_once=function()
        local env=fake('1 1 '..A..'\n1 1 '..B..'\n',{[A]=false,[B]=pack('b','B')})
        local cat,report=env.loader.scan()
        eq(cat.b.DisplayName,'B') ok(report.failed[A],'failed')
        env.loader.scan()
        eq(count(env.logs,'Invalid argument'),1,'logged once over two scans')
    end,
    too_large_pack_skipped=function()
        local big=pack('big','Big')..(' '):rep(Packs.MAX_BYTES)
        local env=fake('1 1 '..A..'\n',{[A]=big})
        local cat,report=env.loader.scan()
        eq(cat.big,nil,'not parsed') ok(report.failed[A],'failed') eq(count(env.logs,'larger than'),1)
    end,
    items_by_slot_sorted_by_name=function()
        local env=fake('1 1 '..A..'\n1 1 '..B..'\n',{
            [A]='['..pack('z','Zeta'):sub(2,-2)..','..pack('h','Hair',',"FitMeshType":"Hair"'):sub(2,-2)..']',
            [B]='['..pack('m','alpha'):sub(2,-2)..','..pack('a2','Beta'):sub(2,-2)..','..
                pack('a1','Beta'):sub(2,-2)..']'})
        env.loader.scan()
        local ids={}
        for _,item in ipairs(env.loader.items('FullOutfit')) do ids[#ids+1]=item.UniqueFitID end
        same(ids,{'m','a1','a2','z'},'alpha, Beta (a1 then a2), Zeta: by name in any case, then by id')
        eq(#env.loader.items('Hair'),1) same(env.loader.items('Face'),{})
    end,
    object_instead_of_list_reads_as_empty=function()
        local env=fake('1 1 '..A..'\n',{[A]=pack('a','A',',"UserConfigs":{"VectorControls":{},'..
            '"ScalarControls":{"Name":"x"},"MaterialToggles":[{"DisplayName":"Boots","MaterialIndex":1}]}')})
        local item=env.loader.scan().a
        same(item.UserConfigs.VectorControls,{}) same(item.UserConfigs.ScalarControls,{})
        eq(#item.UserConfigs.MaterialToggles,1)
    end,
    no_list_file_is_an_empty_catalogue_said_once=function()
        local env=fake(nil,{})
        local cat,report=env.loader.scan()
        same(cat,{}) eq(report.why,'no pack list') eq(report.packs,0)
        env.loader.scan()
        eq(count(env.logs,'no pack list'),1,'said once')
        local none=Packs.new({list=LIST,read=function() error('no read without a pack folder') end,log=function() end})
        eq(select(2,none.scan()).why,'no pack folder','no folder, no read')
    end,
    rescan_picks_up_a_new_list=function()
        local env=fake(nil,{[A]=pack('a','A')})
        env.loader.scan()
        env.list_text='1 1 '..A..'\n'
        local cat,report=env.loader.scan()
        eq(cat.a.DisplayName,'A') eq(report.why,nil)
    end,
    report_line=function()
        eq(Packs.line({packs=3,reused=1,items=5,failed={[A]='x'}}),
            'closet packs: 3 packs (1 reused), 5 outfits, 1 failed')
        eq(Packs.line({packs=0,reused=0,items=0,failed={},why='no pack list'}),
            'closet packs: no pack list (coop-cns-packs.txt: an older DLL or no start yet)')
    end,
}
run('packs_test',tests)
