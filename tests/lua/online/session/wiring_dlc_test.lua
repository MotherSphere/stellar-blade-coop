-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The DLC notice through main.lua (fixture.lua): when her installed DLCs differ from ours (link.dlcs()), one notice a
-- session names hers we lack and ours she lacks, in the menu's words with its English beside; the same DLCs, or no list
-- yet, say nothing.
dofile('tests/lua/main/fixture.lua')
in_world=true
settings_text,status_text='shared_enemies=off\n',COOP
load_main(true)
local THEIRS,YOURS="Kaanta has DLCs you don't have: ","You have DLCs Kaanta doesn't have: "
local function dlcs(same,missing,extra) return {same=same,ours=#extra,hers=#missing,missing=missing,extra=extra} end
link_mode='host'
assert(dlcs_tick(nil)=='' and dlcs_tick(dlcs(true,{},{}))=='')
local got=dlcs_tick(dlcs(false,{'Alpha'},{'Beta','Gamma'}))
assert(got==THEIRS..'Alpha. '..YOURS..'Beta, Gamma.',got)
assert(dlcs_tick(dlcs(false,{'Alpha'},{}))=='','Once a session')
link_mode='none'
assert(dlcs_tick(nil)=='')
link_mode,kit_language='guest','fr-FR'
got=dlcs_tick(dlcs(false,{},{'Beta'}))
assert(got=="Vous avez des DLC que Kaanta n'a pas : Beta.",got)
local at=#said
while not said[at]:find('DLC',1,true) do at=at-1 end -- Before the fake link's own notices.
assert(said_en[at]==YOURS..'Beta.',tostring(said_en[at]))
io.stdout:write('dlc_test ok\n')
