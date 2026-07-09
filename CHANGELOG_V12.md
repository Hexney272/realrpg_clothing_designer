# Changelog V12

Docs troubleshooting parity update:
- Added Config.Worker block with external/inprocess mode, PowerShell path, worker file and tools folder.
- Added Config.Permissions helper lines for child process and filesystem export permissions.
- Added Config.Authorization with grant/access check flow and `not_authorized` handling.
- Added exports: `grantPlayerAccess`, `revokePlayerAccess`, `hasPlayerAccess`.
- Added `/rcd_troubleshoot` command and troubleshooting bundle callback.
- Added SavedDesigns and AI config blocks matching the troubleshooting checks.
- Added placeholder `worker/fivemRpcWorker.cjs` and worker tools README.
- README expanded with worker, PowerShell, Linux pwsh, export, template, preview and saved design troubleshooting.
