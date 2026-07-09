Ide kerülnek majd a valódi clothing preview stream fájlok.

V10 mapping alapból ezeket keresi:
- realrpg_preview_hoodie.ydr / .ytd
- realrpg_preview_tshirt.ydr / .ytd
- realrpg_preview_pants.ydr / .ytd
- realrpg_preview_shoes.ydr / .ytd
- realrpg_preview_cap.ydr / .ytd

Ha nincs streamelt modell, a script automatikusan ped fallback preview-t használ.
A későbbi stream-integrációban a feltöltött stream assetek alapján finomhangolható lesz a modelnév, offset, kamera fókusz és textúra mapping.

---
V14 kiegészítés: valódi ruha addon-component fájlok (pl. jbib = torso/kabát, component id 11)

A fxmanifest.lua files{} blokkja mostantól tartalmazza a 'stream/*.ydd' és 'stream/*.ymt'
mintákat is (korábban csak .ydr/.ytd volt engedélyezve, a .ydd fájlokat a resource sosem
küldte volna le a klienseknek).

Két különböző, EGYMÁST KIZÁRÓ módszer van ugyanazoknak a fájloknak a streamelésére -
csak az egyiket használd egy adott drawable-höz, ne mindkettőt egyszerre:

1) "^" (caret) prefixes, meta-less addon streaming (nem kell YMT/meta fájl):
   mp_m_freemode_01^jbib_000_u.ydd
   mp_m_freemode_01^jbib_diff_000_a_uni.ytd
   -> A "pedmodel^fájlnév" formátum egy FiveM natív funkció: a runtime automatikusan
      extra drawable variánsként regisztrálja a megadott ped modell adott komponenséhez,
      YMT/meta szerkesztés nélkül. Ezt egyszerűen bemásolod a stream/ mappába, és a
      fxmanifest.lua 'stream/*.ydd' / 'stream/*.ytd' mintája már lefedi.

2) Sima (prefix nélküli) fájlnevek + saját YMT/meta (hagyományos addon-ped módszer):
   jbib_000_u.ydd
   jbib_diff_000_a_uni.ytd
   -> Ehhez szükség van egy <fullDlcName>.ymt és .meta fájlra is (data_file
      'SHOP_PED_APPAREL_META_FILE' 'stream/*.ymt'), amit a Template/Export flow
      (Config.TemplateFlow, exportAddon) generál a "clothingdesignerrescan" /
      "clothingtemplates" parancsokkal, illetve az admin Export gombbal.

Ha mindkét variánst (prefixeltet ÉS prefix nélkülit) egyszerre teszed be ugyanahhoz a
drawable indexhez, a két módszer ütközhet (duplikált drawable index). Válassz egyet:
- Gyors teszthez: használd a "^" prefixes fájlokat (nincs YMT-igény).
- Végleges, exportálható addon-hoz: használd a prefix nélkülit + a beépített
  Export/Template flow-t, ami legenerálja a YMT/meta/fxmanifest fájlokat.

A jelenlegi feltöltött 4 drawable (jbib_000/005/007/013_u) a Config.TemplateFlow
'jbib' komponensére van mappelve (lásd shared/config.lua Config.TemplateFlow.
supportedComponents.jbib és componentToSkinKey.jbib = 'torso_1'), tehát a torso_1
(id=11, "Felső / Kabát") komponens drawable listájában fognak megjelenni.
