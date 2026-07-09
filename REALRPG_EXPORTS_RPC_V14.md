# RealRPG Exports and RPC V14

This resource is fully RealRPG-named. No third-party resource names, event names, or output resource names are required.

## Correct UI Open Flow

Opening the UI alone is not enough. Grant access on the server first, then open the client UI.

```lua
local playerSource = source

if exports['realrpg_clothing_designer']:grantPlayerAccess(playerSource) then
    TriggerClientEvent('realrpg_clothing_designer:client:openClothingDesigner', playerSource)
end
```

## Server exports

```lua
exports['realrpg_clothing_designer']:getRuntimeConfig()
exports['realrpg_clothing_designer']:getTemplateCatalog()
exports['realrpg_clothing_designer']:rescanTemplates()
exports['realrpg_clothing_designer']:grantPlayerAccess(source)
exports['realrpg_clothing_designer']:revokePlayerAccess(source)
exports['realrpg_clothing_designer']:hasPlayerAccess(source)
exports['realrpg_clothing_designer']:openForPlayer(source)
```

## Public client event

```lua
TriggerClientEvent('realrpg_clothing_designer:client:openClothingDesigner', source)
```

## Admin commands

```txt
/clothingdesigner [id]
/clothingdesignerstats
/clothingdesignerrescan
```

## Export output behavior

Addon output is written to:

```txt
realrpg_clothing_designer/exports/
realrpg_clothing_exports/
realrpg_clothing_designer/data/workspace/
```

After a successful export, restart:

```txt
restart realrpg_clothing_exports
```
