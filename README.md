# w_policejob

## 1.0.6 (2026-11-01)

- الغرامة من بطاقة الشريف (K) تطلب المبلغ **والسبب** معًا (3 أحرف على الأقل، `Config.Fine.reasonMin`)، ويُكتب السبب
  في سجل الشخص في دفتر الشريف (MDT). أكبر غرامة 5000$، ولا يغرّم الشريف الشخص نفسه إلا مرة كل 5 دقائق (`Config.Fine`).
- السرقة لم تعد تأخذ كل نقود الشخص: تأخذ نصف ما يحمله بحد أقصى 500$، ولا يسرق اللص الشخص نفسه إلا مرة كل 30 دقيقة
  (`Config.Robbery`). كل سرقة ومبلغها تُكتب في السجل.
- رسائل الرفض تقول السبب: ليس في الخدمة، لا أحد قريب، لا يملك ما يكفي في البنك، لا يحمل نقودًا، لا مكان في الحقيبة،
  غرّمته أو سرقته قبل قليل (مع الدقائق الباقية). ويصل الشريف تأكيد عند أخذ الغرامة أو مصادرة النقود.

## 1.0.5 (2026-11-01)

- سرقة من يرفع يديه (X) تأخذ ماله الآن، بعد أن كانت لا تعمل إلا مع المقيّد أو المصاب.
- يجب أن تقف قريبًا منه (1.8 متر) حتى تفتح حقيبته عند انتهاء السرقة.

## 1.0.4 (2026-10-30)

- مواقع الشريف والأطباء في الدوام تظهر للمصرح لهم في العالم نفسه فقط.
- النداءات تقبل رسائل واضحة محدودة، مع منع التكرار السريع والبيانات غير الصالحة.
- اختبار داخل اللعبة: تحقق من مواقع الدوام بحساب شريف أو طبيب، ثم بحساب مدني وفي عالم منفصل. أرسل نداءً عاديًا وتأكد من وصوله مرة واحدة.

Law enforcement job for the Wraith Core (RedM) server.

1.0.2: الخبرة من جدول `w_level`: رجل الأمن يكسب عند سجن مطلوب (`police_jail`) وعند مخالفة يدفعها صاحبها (`police_fine`)، والمسجون يُخصم منه حسب مدة الحكم (`jailed`). إعادة سجن المسجون أو سجن النفس لا تُحسب، ونفس الشخص لا يُحسب إلا بعد مدة.

1.0.1: مفتاح الخزنة الشخصية في المركز صار H بدل E، ومفتاح التفتيش صار Y بدل E (لأن E يمسك اللاعب القريب، وJ مستعمل للدوام والسجن).

## Dependencies
- w_lib (library: prompts, language, dialogs, blips, notifications, entities)
- w_core (framework: players, jobs, commands)
- w_inventory (stashes, armory, evidence items)

## Language
The library controls the language: `setr w_lib:locale "ar"` in server.cfg and the player's own
choice in the `/w_lib` dialog. The dictionaries live in `locales/ar.json` and `locales/en.json`
(same key set in both). Prompt labels, blip names and menus are rebuilt live when the player
switches language. Server-side notices are sent as dictionary keys and translated on the client.

## Features
- On duty / off duty, personal stash, armory and evidence drawers at every sheriff office
- Wagon garage per job grade (RDR2 wagons, e.g. the police wagon)
- Bullet casings (firearms only), blood drops, fingerprints and a status list (gunpowder, alcohol, ...);
  evidence shows up while the lawman holds his lantern and is collected through the library prompt (Config.Keys.collect)
- A library prompt card follows the closest player: an on-duty lawman gets search, cuff/uncuff (held), escort,
  seat in / take out of a wagon, jail (held), fine, seize cash (held) and check condition; everybody else gets
  rob (held, hands up), escort and carry for a cuffed or downed person. Keys live in Config.Keys.
  Doctors keep their own patient card (w_ambulancejob) and use /escort instead
- One card at a time: station cards, evidence cards and the player card are arbitrated by
  client/cards.lua (station > evidence > player, then the closest), and every card steps aside
  while a menu, dialog, progress bar or the inventory is open
- Handcuffs (item or command): a hard cuff pins the suspect, a soft cuff (/sc) lets him walk; escort, search,
  seize cash, jail and fines; cuffed suspects can be seated in a wagon
- The server checks every action on a nearby player (cuff, escort, carry, wagon in/out, search, jail, fine,
  seize cash, rob) itself: the man is in the game and is not the sender, both are in the same routing bucket
  and within 5 m (8 m to take him out of a wagon, measured at the wagon too), the sender has the job on duty
  or the handcuffs the action needs (search and wagons: lawman on duty; a hard cuff: the handcuffs), and the
  man is cuffed or down where the action needs it. A modified client cannot act on a player across the map
- The cuff flag those checks read is the server's: a suspect's client only confirms the cuff or uncuff the
  server just sent him (10 s), or drops the cuffs of a dead man at the hospital; loading, logging out and
  the jail clear it on the server. A client can no longer cuff or uncuff itself
- Placeable objects (wooden barricade, tent, torch post, lantern)
- Lawmen see each other on the map; alerts drop a pulsing blip

## Commands
- /pobject [barricade/tent/torch/lantern/delete] - places or removes an object
- /cuff - cuffs/uncuffs the nearby player
- /sc - soft cuff
- /escort - escorts the nearby player
- /callsign [text] - sets your callsign
- /clearcasings - clears nearby bullet casings
- /clearblood - clears nearby blood drops
- /jail [id] [months] - sends a player to jail
- /unjail [id] - releases a player
- /seizecash - seizes the nearby player's cash into a money bag
- /takedna [id] - takes a DNA sample (empty evidence bag needed)
