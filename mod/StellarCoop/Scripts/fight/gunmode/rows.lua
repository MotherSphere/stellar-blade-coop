-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's rounds batch as native/src/fight/gunmode/nikke_rows.h writes it, for core/enemy.lua's read-back: ROWS
-- {table, name, ID, checks}, each check {field, kind, value, changed} (core/enemy.lua's kinds).
-- tests/lua/fight/gunmode/nikke_test.lua checks that it says what the header writes. ROUND: the rifle's round, SB's own
-- ItemTable row. PRICE: gold a round costs in the camp vending machines.
local R={}
R.ROUND='Bullet_Nikke'
R.PRICE=2
local function drop(id,rate,min,max)
    return {'RewardGroupTable',tostring(id),id,{{'ItemAlias','n',R.ROUND,true},{'DropRate','i',rate,true},
        {'ItemMinCount','i',min,true},{'ItemMaxCount','i',max,true}}}
end
local CAMP='Camp_HP_Potion_Buy|Camp_HP_Potion_Small_Buy|Camp_Bullet_Package_Dummy_Buy|Camp_Bullet_Normal_Buy|'
    ..'Camp_Bullet_Scatter_Buy|Camp_Bullet_Explosive_Buy|Camp_Bullet_Missile_Buy|Camp_Bullet_Railgun_Buy|'
    ..'Camp_Bullet_Nikke_Buy|Camp_ConcussionGrenade_Buy|Camp_PulseGrenade_Buy|Camp_FlashGrenade_Buy|'
    ..'Camp_TrapGrenade_Buy|Camp_HealGrenade_Buy|Camp_SPInitializer_Buy'
R.ROWS={
    drop(31114,1500,15,30),drop(31115,2000,20,40),drop(31116,1000,10,20),drop(31117,1500,15,30),
    drop(31118,3000,30,60),drop(31119,3000,30,60),drop(31120,1000,10,20),drop(31121,5000,20,40),
    {'ShopItemTable','Camp_Bullet_Nikke_Buy',37,{{'ItemAlias','n',R.ROUND,true},{'MoneyItemCount1','i',R.PRICE,true},
        {'CheckConditionGroup','n','None',true},{'FriendShip','f',R.PRICE,true}}},
    {'ShopTable','Shop_SimpleCamp',1001,{{'ShopItems','N','Camp_ResurrectionItem_x3_Buy|'..CAMP,true}}},
    {'ShopTable','Shop_FullCamp',1002,{{'ShopItems','N','Camp_ResurrectionItem_x3_Buy|'..CAMP,true}}},
    {'ShopTable','Shop_NestCamp',1003,{{'ShopItems','N','Camp_ResurrectionItem_Buy|'..CAMP,true}}},
}
return R
