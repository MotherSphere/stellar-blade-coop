-- The Xion recruiter's dialogue (coop recruiter, recruiter.lua) in the 23 text languages the game ships, copied byte
-- for byte from the reviewed translation table. KEYS: his 12 FText keys (namespace "") -> {line, exact Korean source};
-- the engine keeps a registered text only while that source matches the asset's, "(임시) " included. TEXT: culture ->
-- line -> text. Lines: T speaker title, Q question, J and C the Join and Cancel choices, A1 after Join, A2 after
-- Cancel, A3 the reply shown while the game's network option is on. The official terms (Night Operation, Xion,
-- Cancel, Settings) are the game's own strings in each language; the French Q keeps its no-break space before "?".
local KEYS={
    ["1369C3D149FBA96B3A868A8DDB37F6DB"]={"T","자이온 모병관"}, -- A1 title
    ["90E21C7C499D1388F4FE8398516ADE70"]={"T","자이온 모병관"}, -- A2 title
    ["1D919BC54814EE9DEA9B86A353B9FB1A"]={"T","(임시) 자이온 모병관"}, -- A3 title
    ["845B85444BEB4A1DC834AC970B04E051"]={"T","자이온 모병관"}, -- Q title
    ["4ED6720D4C01A463E14958BA0EFD74F3"]={"Q","야간작전에 참여하시겠습니까?"}, -- Q Message
    ["782D3CF24282FF4209C210AD8B19578C"]={"J","(임시) 야간작전에 참여한다(멀티플레이 참여)"}, -- graph [15]/Properties/DisplayText
    ["1EC542C44399E9B5B68A5281A10096DA"]={"J","(임시) 야간작전에 참여한다(멀티플레이 참여)"}, -- row TS_Xion01_MultiPlay_1/DisplayText
    ["17655DF64FCD86F91529FDB6E28F85DA"]={"C","(임시) 취소"}, -- graph [16]/Properties/DisplayText
    ["8684A0504021287B7FB80FA6BDE723B6"]={"C","(임시) 취소"}, -- row TS_Xion01_MultiPlay_2/DisplayText
    ["D0D5606146CF2F72244711A2943E8E11"]={"A1","행운을 빕니다."}, -- A1 Message
    ["D476C7694FDE4C24A96661809D99F648"]={"A2","(임시) 준비가 되면 다시 알려주세요."}, -- A2 Message
    ["9B0147424996337B530492A5E2F71030"]={"A3","(임시) 현재 네트워크 연결이 불가능합니다. 옵션에서 활성 해주세요"}, -- A3 Message
}
local TEXT={
    ["ko"]={
        T="자이온 모병관",
        Q="야간 작전에 참여하시겠습니까?",
        J="야간 작전에 참여한다.",
        C="취소",
        A1="행운을 빕니다.",
        A2="준비가 되면 다시 알려 주세요.",
        A3="현재 네트워크 연결이 불가능합니다. 설정에서 활성화해 주세요.",
    },
    ["en"]={
        T="Xion Recruiter",
        Q="Would you like to join the night operation?",
        J="Join the night operation",
        C="Cancel",
        A1="I wish you luck.",
        A2="Let me know when you're ready.",
        A3="Network connection is currently unavailable. Please enable it in Settings.",
    },
    ["en-GB"]={
        T="Xion Recruiter",
        Q="Would you like to join the night operation?",
        J="Join the night operation",
        C="Cancel",
        A1="I wish you luck.",
        A2="Let me know when you're ready.",
        A3="Network connection is currently unavailable. Please enable it in Settings.",
    },
    ["fr"]={
        T="Recruteur de Xion",
        Q="Veux-tu participer à l'opération nocturne ?",
        J="Participer à l'opération nocturne",
        C="Annuler",
        A1="Bonne chance.",
        A2="Reviens me voir quand tu seras prête.",
        A3="La connexion réseau est indisponible pour le moment. Active-la dans les Paramètres.",
    },
    ["de"]={
        T="Xion-Anwerber",
        Q="Willst du am nächtlichen Einsatz teilnehmen?",
        J="Am nächtlichen Einsatz teilnehmen",
        C="Abbrechen",
        A1="Viel Glück.",
        A2="Sag Bescheid, wenn du bereit bist.",
        A3="Eine Netzwerkverbindung ist zurzeit nicht möglich. Aktiviere sie in den Einstellungen.",
    },
    ["it"]={
        T="Reclutatore di Xion",
        Q="Vuoi partecipare all'operazione notturna?",
        J="Partecipa all'operazione notturna",
        C="Annulla",
        A1="Ti auguro buona fortuna.",
        A2="Avvisami quando sarai pronta.",
        A3="Al momento la connessione di rete non è disponibile. Attivala nelle Impostazioni.",
    },
    ["es"]={
        T="Reclutador de Xion",
        Q="¿Quieres participar en la operación nocturna?",
        J="Participar en la operación nocturna",
        C="Cancelar",
        A1="Te deseo suerte.",
        A2="Avísame cuando estés lista.",
        A3="La conexión de red no está disponible en este momento. Actívala en Ajustes.",
    },
    ["es-MX"]={
        T="Reclutador de Xion",
        Q="¿Quieres participar en la operación nocturna?",
        J="Participar en la operación nocturna",
        C="Cancelar",
        A1="Te deseo suerte.",
        A2="Avísame cuando estés lista.",
        A3="La conexión de red no está disponible en este momento. Actívala en Configuración.",
    },
    ["pt"]={
        T="Recrutador de Xion",
        Q="Queres participar na operação noturna?",
        J="Participar na operação noturna",
        C="Cancelar",
        A1="Desejo-te boa sorte.",
        A2="Avisa-me quando estiveres pronta.",
        A3="De momento, a ligação à internet não está disponível. Ativa-a nas Definições.",
    },
    ["pt-BR"]={
        T="Recrutador de Xion",
        Q="Você quer participar da operação noturna?",
        J="Participar da operação noturna",
        C="Cancelar",
        A1="Boa sorte.",
        A2="É só me avisar quando estiver pronta.",
        A3="No momento, a conexão de rede não está disponível. Ative-a nas Configurações.",
    },
    ["nl"]={
        T="Xion-werver",
        Q="Wil je meedoen aan de nachtelijke missie?",
        J="Doe mee aan de nachtelijke missie",
        C="Annuleren",
        A1="Ik wens je veel succes.",
        A2="Laat maar weten wanneer je klaar bent.",
        A3="Er is momenteel geen netwerkverbinding mogelijk. Schakel die in via Instellingen.",
    },
    ["da"]={
        T="Xions hverver",
        Q="Vil du deltage i natmissionen?",
        J="Deltag i natmissionen",
        C="Annullér",
        A1="Jeg ønsker dig held og lykke.",
        A2="Sig til, når du er klar.",
        A3="Netværksforbindelsen er ikke tilgængelig lige nu. Aktivér den under Indstillinger.",
    },
    ["no"]={
        T="Xions verver",
        Q="Vil du delta i nattoperasjonen?",
        J="Delta i nattoperasjonen",
        C="Avbryt",
        A1="Jeg ønsker deg lykke til.",
        A2="Bare si ifra når du er klar.",
        A3="Nettverksforbindelsen er ikke tilgjengelig akkurat nå. Aktiver den under Innstillinger.",
    },
    ["sv"]={
        T="Xions värvare",
        Q="Vill du delta i nattinsatsen?",
        J="Delta i nattinsatsen",
        C="Avbryt",
        A1="Lycka till.",
        A2="Säg till när du är redo.",
        A3="Nätverksanslutningen är inte tillgänglig just nu. Aktivera den under Inställningar.",
    },
    ["fi"]={
        T="Xionin värvääjä",
        Q="Haluatko osallistua yöoperaatioon?",
        J="Osallistu yöoperaatioon",
        C="Peruuta",
        A1="Toivotan sinulle onnea.",
        A2="Ilmoita vain, kun olet valmis.",
        A3="Verkkoyhteys ei ole tällä hetkellä käytettävissä. Ota se käyttöön Asetuksissa.",
    },
    ["pl"]={
        T="Werbownik Xionu",
        Q="Czy chcesz wziąć udział w nocnej operacji?",
        J="Weź udział w nocnej operacji",
        C="Anuluj",
        A1="Życzę ci powodzenia.",
        A2="Daj mi znać, gdy będziesz gotowa.",
        A3="Połączenie z siecią jest obecnie niedostępne. Włącz je w Ustawieniach.",
    },
    ["ru"]={
        T="Вербовщик Ксиона",
        Q="Хочешь принять участие в ночной операции?",
        J="Принять участие в ночной операции",
        C="Отменить",
        A1="Желаю удачи.",
        A2="Скажи, когда будешь готова.",
        A3="Подключение к сети сейчас недоступно. Включи его в настройках.",
    },
    ["tr"]={
        T="Xion Asker Alım Görevlisi",
        Q="Gece operasyonuna katılmak ister misin?",
        J="Gece operasyonuna katıl",
        C="İptal",
        A1="İyi şanslar.",
        A2="Hazır olduğunda bana haber ver.",
        A3="Ağ bağlantısı şu anda kullanılamıyor. Ayarlar menüsünden etkinleştir.",
    },
    ["ar"]={
        T="مسؤول التجنيد في زيون",
        Q="هل تريدين المشاركة في التشغيل الليلي؟",
        J="المشاركة في التشغيل الليلي",
        C="إلغاء",
        A1="أتمنى لكِ التوفيق.",
        A2="أخبريني عندما تكونين جاهزة.",
        A3="الاتصال بالشبكة غير متاح حاليًا. يُرجى تفعيله من الإعدادات.",
    },
    ["th"]={
        T="เจ้าหน้าที่รับสมัครแห่งไซโยน",
        Q="เธอสนใจเข้าร่วมปฏิบัติการกลางคืนไหม",
        J="เข้าร่วมปฏิบัติการกลางคืน",
        C="ยกเลิก",
        A1="ขอให้โชคดี",
        A2="ถ้าพร้อมแล้วก็มาบอกฉันอีกทีนะ",
        A3="ตอนนี้ไม่สามารถเชื่อมต่อเครือข่ายได้ โปรดเปิดใช้งานในเมนูตั้งค่า",
    },
    ["ja"]={
        T="ザイオンの募兵官",
        Q="夜間オペレーションに参加しますか？",
        J="夜間オペレーションに参加する",
        C="キャンセル",
        A1="幸運を祈ります",
        A2="準備ができたら また声をかけてください",
        A3="現在ネットワークに接続できません 設定から有効にしてください",
    },
    ["zh-Hans"]={
        T="希雍募兵官",
        Q="你要参加暗夜行动吗？",
        J="参加暗夜行动",
        C="取消",
        A1="祝你好运。",
        A2="准备好了就再来告诉我一声。",
        A3="目前无法连接网络。请在设置中启用。",
    },
    ["zh-Hant"]={
        T="曦安募兵官",
        Q="你要參加夜間行動嗎？",
        J="參加夜間行動",
        C="取消",
        A1="祝你好運。",
        A2="準備好了再來告訴我一聲吧。",
        A3="目前無法連線至網路。請在設定中啟用。",
    },
}
-- The game's text culture (GetCurrentLanguage) as one of TEXT's: its own name, else the game's fallbacks (en-* to
-- en-GB but en-US to en, es-* to es-MX but es-ES to es, zh by script or region, pt-BR, nb and nn to no), else the
-- base language, else English.
local function culture(name)
    if type(name)~='string' then return 'en' end
    if TEXT[name] then return name end
    local lang,rest=name:match('^(%a+)%-?(.*)$')
    if not lang then return 'en' end
    lang,rest=lang:lower(),rest:upper()
    if lang=='zh' then
        return (rest:find('HANT',1,true) or rest=='TW' or rest=='HK' or rest=='MO') and 'zh-Hant' or 'zh-Hans'
    end
    if lang=='en' then return (rest=='' or rest=='US') and 'en' or 'en-GB' end
    if lang=='es' then return (rest=='' or rest=='ES') and 'es' or 'es-MX' end
    if lang=='pt' then return rest=='BR' and 'pt-BR' or 'pt' end
    if lang=='nb' or lang=='nn' then return 'no' end
    return TEXT[lang] and lang or 'en'
end
return {KEYS=KEYS,TEXT=TEXT,culture=culture}
