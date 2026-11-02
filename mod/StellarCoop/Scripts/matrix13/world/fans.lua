-- The fan room's three fans in world 2800 (experimental, untested in game): each stays still until its lever reads On.
-- The cooked rotors (Z4_Z4R10_S_Fan1_Rotor to Fan3_Rotor in MXIII_Z4_Fans) carry a RotatingMovementComponent that turns
-- from level load, and no row or sequence drives it, so this file holds the component off at run time and needs no cook
-- change: SetActive(false) stops its tick [inference: UActorComponent's own call, never run on these]. Levers 023, 024
-- and 025 start disabled and the Lion's EventOnDead enables them (data/mxiii-world.json, DLC02_40_E_EnvC_631 to 633);
-- their row state On is saved, so a reload finds the fans it left running. Once a second, only within NEAR of the room:
-- the components are looked for by a walk of every object (25 to 80 ms, no path assumed for a streamed level's objects),
-- at most every FIND s and only while one is missing, then held, and a level streamed back in gets a fresh object that
-- turns for at most FIND s before the next walk. One [MXFAN] line a change. If nothing is found the fans keep turning.
local U=require('core.unreal')
local Fans={}
Fans.LEVERS={{env='DLC02_40_EnvS_023',rotor='Z4_Z4R10_S_Fan1_Rotor'},{env='DLC02_40_EnvS_024',rotor='Z4_Z4R10_S_Fan2_Rotor'},
    {env='DLC02_40_EnvS_025',rotor='Z4_Z4R10_S_Fan3_Rotor'}}
-- World cm: the room's middle (plan -132.5, 15, 15 m above its floor), and within this of it the room and its doors.
Fans.CENTER,Fans.NEAR={X=40246,Y=48945,Z=-14633},7000
Fans.EVERY,Fans.FIND=1,10
-- o: log (the [MXFAN] lines), here (EVE when she stands in world 2800, else nil).
function Fans.new(o)
    local log,here=o.log,o.here
    local self={}
    local next_pass,next_find=0,-math.huge
    local rotors,levers={},{} -- By rotor name, by env row name: the objects held.
    local said=nil -- The last message said.
    local function say(m)
        if m~=said then said=m; log(m) end
    end
    -- A held object while it still is what it was found as: after a reload another object can sit at its address, and
    -- U.valid alone passes it. A call it lacks raises, and that too means no.
    local function rotor_of(f)
        local ok,c=pcall(function()
            local c=U.valid(rotors[f.rotor])
            return c and U.text(c:GetOwner():GetFName())==f.rotor and c or nil
        end)
        return ok and c or nil
    end
    local function lever_of(f)
        local ok,x=pcall(function()
            local x=U.valid(levers[f.env])
            return x and U.text(x.EnvActorName)==f.env and x or nil
        end)
        return ok and x or nil
    end
    local function near(eve)
        local v,c=U.value_of(eve:K2_GetActorLocation()),Fans.CENTER
        return (v.X-c.X)^2+(v.Y-c.Y)^2+(v.Z-c.Z)^2<=Fans.NEAR^2
    end
    local function look(eve,now)
        next_find=now+Fans.FIND
        U.each(FindAllOf('RotatingMovementComponent') or {},function(_,c)
            c=U.valid(c)
            local owner=c and U.valid(c:GetOwner())
            if owner then rotors[U.text(owner:GetFName())]=c end
        end)
        for _,x in ipairs((U.actors_of(U.find('/Script/SB.SBZoneEnvActor'),'SBZoneEnvActor',eve))) do
            local ok,name=pcall(function() return U.text(x.EnvActorName) end)
            if ok then levers[name]=x end
        end
    end
    local function pass(now)
        local eve=here()
        if not eve then
            rotors,levers,next_find={},{},-math.huge
            return
        end
        if not near(eve) then return end
        local missing=false
        for _,f in ipairs(Fans.LEVERS) do
            missing=missing or not rotor_of(f) or not lever_of(f)
        end
        if missing and now>=next_find then look(eve,now) end
        local found=0
        for _,f in ipairs(Fans.LEVERS) do
            local rotor,lever=rotor_of(f),lever_of(f)
            if rotor then
                found=found+1
                -- No lever read yet: still. A fan must never run ahead of its lever.
                local on=lever~=nil and U.text(lever:GetStateTagname())=='On'
                if rotor:IsActive()~=on then
                    rotor:SetActive(on,false)
                    log(string.format('%s %s: lever %s %s',f.rotor,on and 'runs' or 'held still',f.env,
                        on and 'is On' or 'is not On'))
                end
            end
        end
        if found==0 then say('STOP: no fan rotor found: the fans keep their cooked turning') end
    end
    function self.tick()
        local now=os.clock()
        if now<next_pass then return end
        next_pass=now+Fans.EVERY
        local ok,why=pcall(pass,now)
        if not ok then say('STOP: '..tostring(why)) end
    end
    return self
end
return Fans
