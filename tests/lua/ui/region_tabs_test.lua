-- The teleport screen's extra tabs (ui/region_tabs.lua) over fakes. Covered: nothing before the game is ready; the
-- classes loaded when not in memory, the keeper made once, the focus hook registered before the Construct hook; tabs 8 to
-- 10 made collapsed with their count, name, slot and number, the trailing spacer last, the row clipped with its bar; a
-- second Construct adds nothing; a row of another shape, a tab that keeps no name or a failed hook leaves 7 tabs with one
-- log line; focus on tab 8 sends its name to the screen, focus on tab 7 sends nothing, a failed send collapses the tab,
-- and focus still sends after coop off, which stops new tabs.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function object(fields)
    fields=fields or {}
    fields.type=function() return 'UObject' end
    fields.IsValid=function() return true end
    return fields
end
local logs,hooks,objects,loaded,constructed={},{},{},{},{}
local refuse_name,refuse_hook,refuse_send,sent=false,nil,false,{}
local function reset()
    logs,hooks,objects,loaded,constructed={},{},{},{},{}
    refuse_name,refuse_hook,refuse_send,sent=false,nil,false,{}
end
local missing=setmetatable({},{__index=function(_,k)
    if k=='type' then return function() return 'UObject' end end
    if k=='IsValid' then return function() return false end end
end})
StaticFindObject=function(path) return objects[path] or missing end
LoadAsset=function(path)
    loaded[#loaded+1]=path
    objects[path..'_C']=object({GetOuter=function() return object() end})
end
StaticConstructObject=function(class,outer,name,flags,internal)
    constructed[#constructed+1]={class=class,outer=outer,name=name,flags=flags,internal=internal}
    return object()
end
FName=function(s) return s end
RegisterHook=function(path,f)
    if refuse_hook and path:find(refuse_hook,1,true) then error('no such function',0) end
    hooks[#hooks+1]={path=path,f=f}
end
local Tabs=require('ui.region_tabs')
local SET='/Game/Art/UI/Widget/GameMenu/Teleport/WB_AreaTeleport_Set.WB_AreaTeleport_Set'
local TAB='/Game/Art/UI/Widget/GameMenu/Teleport/WB_AreaTeleport_Tab.WB_AreaTeleport_Tab'
local function log(line) logs[#logs+1]=line end
local function new(ready)
    return Tabs.new({log=log,ready=function() return ready==nil or ready end})
end

-- A screen with a row of n children.
local function screen(n)
    local children={}
    local root
    local tab_class=object()
    local set
    for i=1,n do children[i]=object({name='child'..i}) end
    root=object({
        GetChildrenCount=function() return #children end,
        GetChildAt=function(_,i) return children[i+1] end,
        RemoveChild=function(_,c)
            for i,x in ipairs(children) do if x==c then table.remove(children,i); return true end end
        end,
        AddChild=function(_,c) children[#children+1]=c; return object() end,
        SetClipping=function(self,v) self.clipping=v end,
        SetScrollBarVisibility=function(self,v) self.bar=v end,
        SetScrollbarThickness=function(self,v) self.thickness=v end,
    })
    set=object({
        HB_AreaTeleportRoot=root,
        WB_AreaTeleport_Tab_1=object({GetClass=function() return tab_class end}),
        CreateDynamicChildUserWidget=function(_,class,panel)
            assert(class==tab_class and panel==root)
            local slot=object({
                SetPadding=function(self,v) self.padding=v end,
                SetHorizontalAlignment=function(self,v) self.h=v end,
                SetVerticalAlignment=function(self,v) self.v=v end,
            })
            local name=''
            local t=setmetatable(object({
                Slot=slot,ParentWidget=object({NotifyBlueprint=function(_,s)
                    if refuse_send then error('refused',0) end
                    sent[#sent+1]=s
                end}),
                SetVisibility=function(self,v) self.visibility=v end,
                PreConstruct=function(self,v) self.pre=v end,
            }),{__index=function(_,k) if k=='TabName' then return name end end,
                __newindex=function(self,k,v)
                    if k=='TabName' then name=refuse_name and '' or v else rawset(self,k,v) end
                end})
            children[#children+1]=t
            return t
        end,
    })
    return set,root,children
end

-- Nothing before the game is ready, and no load.
reset()
local notyet=new(false)
notyet.tick()
assert(#hooks==0 and #loaded==0 and #constructed==0)

-- The install: loaded, kept, focus first, and once.
reset()
local tabs=new()
tabs.tick()
tabs.tick()
assert(table.concat(loaded,' ')==SET..' '..TAB)
assert(#constructed==1 and constructed[1].class==objects[SET..'_C'] and constructed[1].internal==0x40000000)
assert(#hooks==2 and hooks[1].path==TAB..'_C:EventWidgetFocusActive' and hooks[2].path==SET..'_C:Construct')
assert(#logs==1 and logs[1]:find('hooks on',1,true))
local on_focus,on_construct=hooks[1].f,hooks[2].f

-- Construct: three tabs, the spacer last, the row clipped with its bar.
local set,root,children=screen(9)
local spacer=children[9]
on_construct(set)
assert(#children==12 and children[12]==spacer)
for i=9,11 do
    local t,n=children[i],i-1
    assert(t.visibility==1 and t.TabCount==n and t.TabName=='WB_AreaTeleport_Tab_'..n and t.pre==false)
    assert(t.Slot.padding.Left==-20 and t.Slot.padding.Top==20 and t.Slot.h==2 and t.Slot.v==2)
end
assert(root.clipping==1 and root.bar==0 and root.thickness.X==24)
-- Again on the same screen: nothing more, and no log line.
on_construct(set)
assert(#children==12 and #logs==1)

-- Focus: tab 8 sends its name; a vanilla tab sends nothing; a failed send collapses the tab.
on_focus(children[9])
assert(#sent==1 and sent[1]=='WB_AreaTeleport_Tab_8')
on_focus(object({TabCount=7}))
assert(#sent==1)
children[10].visibility=4
refuse_send=true
on_focus(children[10])
assert(children[10].visibility==1 and #logs==2 and logs[2]:find('STOP',1,true))
-- That failure stops new tabs on the next screen, but keeps a tab on screen sending.
refuse_send=false
local later=screen(9)
on_construct(later)
assert(later.HB_AreaTeleportRoot.clipping==nil)
on_focus(children[11])
assert(sent[#sent]=='WB_AreaTeleport_Tab_10')

-- A row of another shape: 7 tabs left, one line, and no more tries.
reset()
tabs=new()
tabs.tick()
local odd,odd_root=screen(8)
hooks[2].f(odd)
assert(odd_root:GetChildrenCount()==8 and #logs==2 and logs[2]:find('8 children',1,true))
hooks[2].f(odd)
assert(#logs==2)

-- A tab that keeps no name: none stays, the spacer is back, one line.
reset()
tabs=new()
tabs.tick()
refuse_name=true
local unnamed,_,unnamed_children=screen(9)
local last=unnamed_children[9]
hooks[2].f(unnamed)
assert(#unnamed_children==9 and unnamed_children[9]==last and #logs==2 and logs[2]:find('kept no name',1,true))

-- The Construct hook refused: the focus hook alone, one line.
reset()
refuse_hook=':Construct'
tabs=new()
tabs.tick()
assert(#hooks==1 and #logs==1 and logs[1]:find('STOP',1,true))
-- The focus hook refused: no Construct hook, so no tab can exist without it.
reset()
refuse_hook=':EventWidgetFocusActive'
tabs=new()
tabs.tick()
assert(#hooks==0 and #logs==1)

-- Classes in memory load nothing; a kept keeper is not made again.
reset()
objects[SET..'_C']=object({GetOuter=function() return object() end})
objects[TAB..'_C']=object()
objects['/Game/Art/UI/Widget/GameMenu/Teleport/WB_AreaTeleport_Set.StellarCoop_RegionTabsKeeper']=object()
tabs=new()
tabs.tick()
assert(#loaded==0 and #constructed==0 and #hooks==2)

-- coop off: no new tabs, while a tab on screen keeps sending.
reset()
tabs=new()
tabs.tick()
local before,_,before_children=screen(9)
hooks[2].f(before)
tabs.stop()
local after,_,after_children=screen(9)
hooks[2].f(after)
assert(#after_children==9)
hooks[1].f(before_children[9])
assert(sent[1]=='WB_AreaTeleport_Tab_8')
print('region_tabs_test: ok')
