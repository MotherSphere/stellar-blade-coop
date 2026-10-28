-- Roxanne's four Night Operation choices (nightop/roxanne.lua) in the 23 text languages the game ships, in the form
-- nightop/recruiter_text.lua has. KEYS: the FText keys (namespace "") of the four shipped test rows that carry them ->
-- {line, exact Korean source}, the DisplayText a row gets back when her choices go off. TEXT: culture -> line -> text;
-- the game language's line is written into each row's DisplayText. Lines: E, N and H the Easy, Normal and Hard levels, S the shop's screen. Night Operation is
-- each language's own term from the game's strings (ui/text.lua's night title); the levels' words are ours.
local KEYS={
    ["C8A59F404A1B66555B5265ACCF31FCFD"]={"E","1번 선택"}, -- row Temp_TS_Select_Test_1/DisplayText
    ["CD80DD9243FF6B46E77860B442659254"]={"N","2번 선택"}, -- row Temp_TS_Select_Test_2/DisplayText
    ["2EF677E140813CB4F455019EBF8EF827"]={"H","3번 선택"}, -- row Temp_TS_Select_Test_3/DisplayText
    ["9E5E7E6644D9B537F9CAFF9BB2233462"]={"S","루프 선택지"}, -- row TS_GoToTest_1/DisplayText
}
local TEXT={
    ["ko"]={E="야간 작전 (쉬움)",N="야간 작전 (보통)",H="야간 작전 (어려움)",S="야간 작전 보급품"},
    ["en"]={E="Night Operation (Easy)",N="Night Operation (Normal)",H="Night Operation (Hard)",
        S="Night Operation supplies"},
    ["en-GB"]={E="Night Operation (Easy)",N="Night Operation (Normal)",H="Night Operation (Hard)",
        S="Night Operation supplies"},
    ["fr"]={E="Opération nocturne (facile)",N="Opération nocturne (normale)",H="Opération nocturne (difficile)",
        S="Ravitaillement de l'opération nocturne"},
    ["de"]={E="Nächtlicher Einsatz (leicht)",N="Nächtlicher Einsatz (normal)",H="Nächtlicher Einsatz (schwer)",
        S="Ausrüstung für den nächtlichen Einsatz"},
    ["it"]={E="Operazione notturna (facile)",N="Operazione notturna (normale)",H="Operazione notturna (difficile)",
        S="Rifornimenti per l'operazione notturna"},
    ["es"]={E="Operación nocturna (fácil)",N="Operación nocturna (normal)",H="Operación nocturna (difícil)",
        S="Suministros de la operación nocturna"},
    ["es-MX"]={E="Operación nocturna (fácil)",N="Operación nocturna (normal)",H="Operación nocturna (difícil)",
        S="Suministros de la operación nocturna"},
    ["pt"]={E="Operação noturna (fácil)",N="Operação noturna (normal)",H="Operação noturna (difícil)",
        S="Abastecimento da operação noturna"},
    ["pt-BR"]={E="Operação Noturna (fácil)",N="Operação Noturna (normal)",H="Operação Noturna (difícil)",
        S="Suprimentos da Operação Noturna"},
    ["nl"]={E="Nachtelijke missie (makkelijk)",N="Nachtelijke missie (normaal)",H="Nachtelijke missie (moeilijk)",
        S="Voorraden voor de nachtelijke missie"},
    ["da"]={E="Natmission (let)",N="Natmission (normal)",H="Natmission (svær)",S="Forsyninger til natmissionen"},
    ["no"]={E="Nattoperasjon (lett)",N="Nattoperasjon (normal)",H="Nattoperasjon (vanskelig)",
        S="Forsyninger til nattoperasjonen"},
    ["sv"]={E="Nattinsats (lätt)",N="Nattinsats (normal)",H="Nattinsats (svår)",S="Förnödenheter för nattinsatsen"},
    ["fi"]={E="Yöoperaatio (helppo)",N="Yöoperaatio (normaali)",H="Yöoperaatio (vaikea)",S="Yöoperaation tarvikkeet"},
    ["pl"]={E="Nocna operacja (łatwa)",N="Nocna operacja (normalna)",H="Nocna operacja (trudna)",
        S="Zaopatrzenie na nocną operację"},
    ["ru"]={E="Ночная операция (легкая)",N="Ночная операция (обычная)",H="Ночная операция (сложная)",
        S="Снаряжение для ночной операции"},
    ["tr"]={E="Gece Operasyonu (kolay)",N="Gece Operasyonu (normal)",H="Gece Operasyonu (zor)",
        S="Gece Operasyonu malzemeleri"},
    ["ar"]={E="التشغيل الليلي (سهل)",N="التشغيل الليلي (عادي)",H="التشغيل الليلي (صعب)",S="إمدادات التشغيل الليلي"},
    ["th"]={E="ปฏิบัติการกลางคืน (ง่าย)",N="ปฏิบัติการกลางคืน (ปกติ)",H="ปฏิบัติการกลางคืน (ยาก)",
        S="เสบียงปฏิบัติการกลางคืน"},
    ["ja"]={E="夜間オペレーション（イージー）",N="夜間オペレーション（ノーマル）",H="夜間オペレーション（ハード）",
        S="夜間オペレーションの補給品"},
    ["zh-Hans"]={E="暗夜行动（简单）",N="暗夜行动（普通）",H="暗夜行动（困难）",S="暗夜行动补给"},
    ["zh-Hant"]={E="夜間行動（簡單）",N="夜間行動（普通）",H="夜間行動（困難）",S="夜間行動補給"},
}
return {KEYS=KEYS,TEXT=TEXT,culture=require('nightop.recruiter_text').culture}
