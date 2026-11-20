-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's arrival and departure: a black cube appears in her right hand, spins, and folds into the NIKKE rifle (in),
-- or the rifle folds back into the cube, which shrinks away (out). Pure timing: Morph.at gives the cube's and the
-- rifle's scale, the spin and the one-off events for a moment of the morph; fight/gunmode/mode.lua applies them.
local Morph={}

Morph.IN,Morph.OUT=0.45,0.40 -- seconds

local function clamp(x) return x<0 and 0 or (x>1 and 1 or x) end
local function ease_out(x) x=clamp(x); return 1-(1-x)*(1-x) end
-- overshoots a little before it settles (the cube "pops" in)
local function back_out(x) x=clamp(x); local c=1.7; return 1+(c+1)*(x-1)^3+c*(x-1)^2 end

-- dir 'in' or 'out', t seconds since the start. Returns {cube=0..~1.1, rifle=0..~1.06, spin=deg, done=bool,
-- flash=true in the frame window where the cube turns into the rifle (fight/gunmode/mode.lua fires the effect once)}.
function Morph.at(dir,t)
    local T=dir=='in' and Morph.IN or Morph.OUT
    local u=clamp(t/T)
    if dir=='out' then u=1-u end -- out is in played backwards
    local r={done=t>=T,spin=0,cube=0,rifle=0,flash=false}
    if u<0.33 then -- the cube grows and spins
        local k=u/0.33; r.cube=back_out(k); r.spin=360*ease_out(k)
    elseif u<0.66 then -- the cube folds away while the rifle unfolds
        local k=(u-0.33)/0.33; r.cube=1-ease_out(k); r.rifle=ease_out(k); r.spin=360+90*k
        r.flash=k<0.25
    else -- the rifle settles
        local k=(u-0.66)/0.34; r.rifle=1+0.06*math.sin(math.pi*k)
    end
    return r
end

return Morph
