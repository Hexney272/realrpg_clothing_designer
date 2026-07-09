# RealRPG Clothing Designer V12 Troubleshooting

This file mirrors the setup/debug flow you provided from the realrpg_clothing_designer docs, adapted to this RealRPG resource.

## External worker does not start
Check:
- `Config.Worker.Mode = 'external'`
- worker startup logs are visible
- child process permission exists in server.cfg
- PowerShell or pwsh works on the host
- `worker/fivemRpcWorker.cjs` exists

Expected style of logs:
```txt
[realrpg_clothing_designer][worker] mode=external
[realrpg_clothing_designer][worker] external daemon started
```

Fast fallback:
```lua
Config.Worker.Mode = 'inprocess'
```

## Windows PowerShell access denied
Test full system path:
```bat
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"
```
Then set:
```lua
Config.Worker.PowerShellPath = 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'
```

## Linux pwsh missing
Install PowerShell and set:
```lua
Config.Worker.PowerShellPath = '/usr/bin/pwsh'
```

## child spawn not allowed
Add to server.cfg only if you use external worker:
```cfg
add_unsafe_child_process_permission realrpg_clothing_designer
```

## Export fails with access denied
Add:
```cfg
add_filesystem_permission realrpg_clothing_designer write realrpg_clothing_exports
```

## Templates do not appear
Check:
- files are in `templates/cloth_templates/male/...` or `templates/cloth_templates/female/...`
- second folder is supported component key
- file prefix matches component folder
- run `refresh` and `restart realrpg_clothing_designer`

Good:
```txt
templates/cloth_templates/male/jbib/jbib_015_u.ydd
```
Bad:
```txt
templates/cloth_templates/male/jbib/feet_015_u.ydd
```

## Preview image changed but UI old
Run:
```cfg
refresh
restart realrpg_clothing_designer
```

## Saved designs fail
Check:
- SQL imported / autoInstall enabled
- oxmysql running
- `Config.SavedDesigns.Enabled = true`
- remote provider config if you switch away from database

## AI generation fails
Check:
- `Config.AI.Enabled = true`
- provider selected
- API key set
- quota / billing / model access exists

## Export succeeds but clothing does not load
Check:
- `realrpg_clothing_exports` is ensured
- restart `realrpg_clothing_exports` after export
- your server build supports the addon clothing count

## Player gets not_authorized
Grant access before opening externally:
```lua
exports['realrpg_clothing_designer']:grantPlayerAccess(source)
TriggerClientEvent('realrpg_clothing_designer:open', source)
```

RealRPG migration style:
```lua
exports['realrpg_clothing_designer']:grantPlayerAccess(source)
TriggerClientEvent('realrpg_clothing_designer:open', source)
```

## Debug bundle
Use:
```txt
/rcd_check
/rcd_troubleshoot
```
