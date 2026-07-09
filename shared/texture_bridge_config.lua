-- RealRPG Clothing Designer V14.1 texture bridge settings.
-- This file is loaded after shared/config.lua, so it only adds bridge-specific config.

Config.TextureBridge = Config.TextureBridge or {}

Config.TextureBridge.enabled = true
Config.TextureBridge.workerResource = 'realrpg_clothing_worker'
Config.TextureBridge.endpoint = GetConvar('realrpg_clothing_worker_endpoint', 'http://127.0.0.1:' .. GetConvar('realrpg_clothing_worker_port', '33442'))
Config.TextureBridge.token = GetConvar('realrpg_clothing_bridge_token', '')
Config.TextureBridge.requestTimeout = tonumber(GetConvar('realrpg_clothing_bridge_timeout', '45000')) or 45000
Config.TextureBridge.maxImageDataLength = tonumber(GetConvar('realrpg_clothing_bridge_max_image_data', '18000000')) or 18000000
Config.TextureBridge.allowNonAdminEditor = false

Config.TextureBridge.defaultOutput = {
    resource = 'realrpg_clothing_designer',
    folder = 'stream',
    filePrefix = 'realrpg_custom_'
}

Config.TextureBridge.livePreview = {
    enabled = true,
    runtimeTxdPrefix = 'rcd_live_',
    runtimeTextureName = 'diffuse_live'
}
