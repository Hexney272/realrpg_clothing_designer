# Bugfix notes (V14 review)

A teljes V14 szkript átnézése után a következő hibákat találtam és javítottam:

## Kritikus
1. **`fx_version '14.0.0'` (fxmanifest.lua és az addon-export sablon a server/main.lua-ban)**
   – az `fx_version` mezője a FiveM-ben egy kódnév (`'cerulean'`), nem verziószám. Egy
   érvénytelen `fx_version` érték miatt a resource (és minden exportált addon resource)
   egyáltalán nem indul el. Javítva `'cerulean'`-ra mindkét helyen.
2. **Két teljesen különálló, egymást nem ismerő authorization tároló** – a régi
   `grantedAccess` (amit az `openDesigner()` / `checkAccess` RPC használt) és az új
   `rcdAuthorizedPlayers` (amit a V14 `client:openClothingDesigner` / `rpcHasAccess` flow
   használt) két külön Lua táblában tartották számon, kik jogosultak. Ha valakinek az egyik
   API-n (pl. `exports:grantPlayerAccess`) keresztül adtál jogot, a másik rendszer
   (`rpcHasAccess`) ezt nem látta, és fordítva. Ez azt jelentette, hogy a dokumentált
   "grant then open" flow (lásd REALRPG_EXPORTS_RPC_V14.md) megbízhatatlanul működött.
   Javítva: egy közös `sharedAccess` táblára lettek húzva mindkét réteg.
3. **`readAllFiles()` (server/main.lua) `io.popen` shell parancsokkal** – ugyanaz a hiba,
   mint a V11-ben: a FXServer sandbox csak az emulált `ls`/`dir`-t engedi, `find` mindig
   "Permission denied"-et adott, így a template auto-scan soha nem talált fájlt. Javítva
   `io.readdir()`-re.

## Közepes
4. **Duplikált `grantPlayerAccess` / `revokePlayerAccess` / `hasPlayerAccess` exportok** –
   mindhárom kétszer volt regisztrálva (egyszer a régi, egyszer az új RPC réteg mellett), a
   második regisztráció csendben felülírta az elsőt. A duplikátum eltávolítva.
5. **Duplikált `ESX.RegisterServerCallback('realrpg_clothing_designer:getSkin:server', ...)`**
   – szó szerint kétszer regisztrálva. A redundáns törölve.
6. **`Config.AllowedModels` nem volt érvényesítve** a `setModel` NUI callbackben – bárki
   bármilyen model hash-re állíthatta a karaktert. Javítva `isModelAllowed()` ellenőrzéssel.
7. **`Config.TeleportWhenCreatingChar`, `Config.SetCoordsAfterFinalize`,
   `Config.CharacterFinalized`** deklarálva voltak, de sosem lettek felhasználva. Bekötve az
   `openDesigner()` / `closeDesigner()` flow-ba, plusz egy új
   `realrpg_clothing_designer:characterFinalized` net event hívja a szerver oldali hookot.
8. **`originalCoords` dead variable (client)** – most visszaállítja a játékos pozícióját, ha
   karakterkészítés közben megszakítják a designer-t.

## Apró
9. `parseTemplatePath`-ban egy no-op `:gsub('/','/')` eltávolítva.

Módosított fájlok: `fxmanifest.lua`, `server/main.lua`, `client/main.lua`.



## 2. kör (a felhasználó által megadott jbib stream fájlok kapcsán feltárt további hibák)

10. **`fxmanifest.lua` `files{}` nem tartalmazott `stream/*.ydd` / `stream/*.ymt` mintát** –
    ugyanaz a hiba, mint V11-ben. Javítva.
11. **`Config.ShowAllPeds`** bekötve az `isModelAllowed()`-be (v11-hez hasonlóan).
12. **`Config.RPC.publicOpenEvent` / `realrpgOpenEvent` / `enabled` / `debugDeniedCalls`**
    csak deklarált mezők voltak, a kód mindenhol hardcode-olt event neveket használt, és
    sosem nézte meg az `enabled`/`debugDeniedCalls` flageket. Most a kliens a configból
    olvassa ki az event neveket, a szerver figyelembe veszi `RPC.enabled`-et (kikapcsolva
    teljesen bypassolja az authorization-t), és logolja a megtagadott RPC hívásokat, ha
    `debugDeniedCalls = true`.
13. **`Config.Permissions.RequireFilesystemExportPermission`** – az addon export mirror
    írása (`../realrpg_clothing_exports` mappába, ami a resource mappáján KÍVÜL van) most
    ehhez a flaghez van kötve, és `pcall`-lal védett, hogy hiányzó
    `add_filesystem_permission` esetén ne omoljon össze az egész export, csak a mirror
    írás maradjon ki (ezt jelzi is az export eredménye `mirrorError` mezőben).
14. **`Config.Worker.Mode = 'external'` – valódi technikai korlát dokumentálva, NEM
    hamis implementáció**: FXServer Lua resource-okból (mint ez is) nincs mód valódi
    child process indítására – `os.execute()` teljesen blokkolt, `io.popen()` csak az
    emulált `ls`/`dir` parancsokat engedi. Az `add_unsafe_child_process_permission` a
    FiveM JS/Node runtime resource-okra vonatkozik, NEM a Lua resource-okra, tehát ez a
    `worker/fivemRpcWorker.cjs` placeholder soha nem lett volna elindítható innen, még a
    permission hozzáadásával sem. Ahelyett, hogy egy működésképtelen spawn-implementációt
    adnék hozzá, most a resource induláskor egyértelmű, hangos figyelmeztetést ír a
    konzolba, ha valaki `Mode = 'external'`-t próbál használni, és elmagyarázza, hogy egy
    külön Node/JS runtime resource-ra és exports/HTTP-alapú kommunikációra lenne szükség.
    A diagnosztikai parancsok (`rcd_check`, `rcd_troubleshoot`) is jelzik ezt az
    "UNSUPPORTED" állapotot.



## 3. kör (élesben tesztelés közben jelentett hibák: rcore_clothing kompatibilitás + adatbázis hiba)

15. **KRITIKUS - `Unknown column 'name' in 'SELECT'` (SQL hiba élesben)**: a
    `installDatabase()` `CREATE TABLE IF NOT EXISTS`-t használ, ami NEM módosítja a
    táblát, ha az már létezik. Ha a `realrpg_clothing_designs` (vagy
    `realrpg_clothing_orders`) tábla korábban hiányos oszlopokkal jött létre a
    szervereden, a script sosem pótolta utólag a hiányzó oszlopokat (`name`, `gender`,
    `preview_type`, `skin`, `components`, `props`, `canvas`, `image`) - csak az
    `is_public` oszlopra volt öngyógyító `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
    Javítva: mindkét tábla összes oszlopára hozzáadva a hiányzó `ALTER TABLE`
    migrációkat, így egy hiányos tábla automatikusan kijavítja magát a resource
    következő indításakor.
16. **KRITIKUS - `rcore_clothing` kompatibilitás hiánya**: a `getSkin()`,
    `applySkinToPlayer()`, a `wearOnOff` event és az "Alkalmazás" gomb
    (`applyPreviewToPlayer`) mind feltétel nélkül `skinchanger:getSkin` /
    `skinchanger:loadSkin` / `esx_skin:save` eventeket hívtak minden olyan esetben, ami
    nem kifejezetten `fivem-appearance` vagy `illenium-appearance` volt - beleértve a
    configban beállított `rcore_clothing`-ot is. Mivel az `rcore_clothing` nem hallgat
    ezekre az eventekre, ez pontosan azt okozta, hogy:
    - a preview "Alkalmazás" után a ruha nem jelent meg a valódi karakteren,
    - a mentés (`saveOnApply`) csendben semmit nem csinált / rossz táblába írt.
    Javítva: `Config.Appearance.system == 'esx_skin'` esetén továbbra is a
    `skinchanger` eventeket használja (ha az `esx_skin`/`skinchanger` resource fut),
    minden más esetben (`rcore_clothing` és bármilyen egyéb/ismeretlen rendszer)
    natív ped-component natívokra (`GetPedDrawableVariation`/`SetPedComponentVariation`
    stb.) esik vissza, amelyek framework-függetlenek és mindig működnek, plusz a saját
    `realrpg_clothing_designer:saveAppearanceSkin` eventünkön keresztül perzisztálja az
    adatot (nem a nem-létező `esx_skin:save` listenerre bízva).
    A `Config.Appearance.system` alapértéke `'rcore_clothing'`-ra állítva, dokumentálva
    a natív fallback működését.
