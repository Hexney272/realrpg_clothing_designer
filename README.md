> **Megjegyzés a repo struktúráról:** a resource forráskódja innentől kicsomagolva, sima
> fájlokként van a repo gyökerében (`client/`, `server/`, `shared/`, `html/`, `stream/`,
> stb.) - ezt húzd be a FXServer `resources/` mappájába, nincs szükség kicsomagolásra.
> A `realrpg_clothing_designer_v14_realrpg_named.zip` csak archív/letölthető csomagként
> van megtartva a repo gyökerében, a kicsomagolt fájlok a hiteles verzió.
>
> Ez a fájl és a többi dokumentum a **V14** verziót írja le (a régebbi V12-es cím a fájl
> tartalmában megmaradt eredeti dokumentációs szövegként).

# RealRPG Clothing Designer V12 Docs/Troubleshooting Parity

V12 cél: a realrpg_clothing_designer docs alapján továbbépített RealRPG saját script, külön fókuszban a troubleshooting flow-val: worker, PowerShell/pwsh, filesystem permission, template hibák, saved design, AI, addon export és server-side authorization.

## Fő parancsok
```txt
/clothingdesigner
/screenshotmenu
/clothingwardrobe
/clothingorders
/clothingadmin
/clothingtemplates
/rcd_check
/rcd_troubleshoot
```

## Server.cfg
```cfg
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure screenshot-basic
ensure es_extended
ensure realrpg_clothing_designer

add_ace group.admin realrpg.clothingdesigner.admin allow
```

Ha external worker kell:
```cfg
add_unsafe_child_process_permission realrpg_clothing_designer
```

Ha addon export írja a mirror resource-t:
```cfg
add_filesystem_permission realrpg_clothing_designer write realrpg_clothing_exports
```

## Template folder rules
```txt
templates/cloth_templates/
  male/
  female/
```

Támogatott component mappák:
```txt
accs
berd
decl
feet
hair
hand
head
jbib
lowr
task
teef
uppr
```

Jó példa:
```txt
templates/cloth_templates/male/jbib/jbib_015_u.ydd
```

Rossz példa:
```txt
templates/cloth_templates/male/jbib/feet_015_u.ydd
```

## Preview images
Saját preview képek:
```txt
templates/template_previews/<gender>/<component>/<file>.png
```

Példa:
```txt
templates/template_previews/male/jbib/jbib_015_u.png
```

Ha módosítasz preview képet futó szerveren:
```cfg
refresh
restart realrpg_clothing_designer
```

## Slot YTD layout
```txt
templates/template_slots/<template_key>/
```

Példa:
```txt
templates/template_slots/male_jbib_jbib_015/
```

## Export flow
A V12 addon-first export működést használ:
- replace export nincs bekapcsolva
- export JSON készül
- addon resource folder készül
- mirror output előkészítve: `../realrpg_clothing_exports/`

Sikeres export után:
```cfg
restart realrpg_clothing_exports
```

## Worker config
```lua
Config.Worker = {
    Enabled = true,
    Mode = 'inprocess', -- external / inprocess
    NodePath = 'node',
    PowerShellPath = '',
    RequiredFile = 'worker/fivemRpcWorker.cjs',
    ToolsFolder = 'worker/tools'
}
```

Fast fallback:
```lua
Config.Worker.Mode = 'inprocess'
```

## Authorization flow
Ha külső scriptből nyitod meg a designert, előtte adj hozzáférést:

```lua
exports['realrpg_clothing_designer']:grantPlayerAccess(source)
TriggerClientEvent('realrpg_clothing_designer:open', source)
```

Ha nem kapott hozzáférést, a kliens `not_authorized` üzenetet ad.

## Új V12 exportok
```lua
exports['realrpg_clothing_designer']:grantPlayerAccess(source, minutes)
exports['realrpg_clothing_designer']:revokePlayerAccess(source)
exports['realrpg_clothing_designer']:hasPlayerAccess(source)
```

## Template exportok
```lua
exports['realrpg_clothing_designer']:scanTemplateFolders()
exports['realrpg_clothing_designer']:scanStreamTemplates()
exports['realrpg_clothing_designer']:listTemplates(category, gender)
exports['realrpg_clothing_designer']:registerTemplate(data)
exports['realrpg_clothing_designer']:exportTemplateJson(id)
exports['realrpg_clothing_designer']:exportAddon(id, addonName)
```

## AI / Saved Designs
A docs troubleshooting alapján bekerültek a config blokkok:

```lua
Config.SavedDesigns.Enabled = true
Config.AI.Enabled = false
```

Az AI nincs bekapcsolva alapból, mert API provider, kulcs, quota és billing kell hozzá.

## Debug
```txt
/rcd_check
/rcd_troubleshoot
```

A részletes leírás: `TROUBLESHOOTING_V12.md`.


## V14 Exports/RPC

A V14 már a docs szerinti nyitási flow-t követi:

```lua
if exports['realrpg_clothing_designer']:grantPlayerAccess(source) then
    TriggerClientEvent('realrpg_clothing_designer:client:openClothingDesigner', source)
end
```

Admin parancsok:

```txt
/clothingdesigner [id]
/clothingdesignerstats
/clothingdesignerrescan
```

Részletek: `EXPORTS_RPC_V14.md`.
