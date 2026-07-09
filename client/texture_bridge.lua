local ESX = nil
local liveReplacements = {}
local liveCounter = 0

local function getESX()
    if ESX then return ESX end
    if GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and obj then ESX = obj return ESX end
    end
    return nil
end

CreateThread(function()
    while not getESX() do Wait(250) end
    print('[realrpg_clothing_designer][texture_bridge] ESX loaded')
end)

local function notify(msg, typ)
    typ = typ or 'info'
    if GetResourceState('realrpg_notify') == 'started' then
        exports['realrpg_notify']:Notify(typ, msg, 3500)
    else
        local esx = getESX()
        if esx and esx.ShowNotification then esx.ShowNotification(msg) else print(('[realrpg_clothing_designer][%s] %s'):format(typ, msg)) end
    end
end

local function triggerCallback(callbackName, nuiCb, ...)
    local esx = getESX()
    if not esx or not esx.TriggerServerCallback then
        nuiCb({ ok = false, error = 'esx_not_ready' })
        return
    end
    esx.TriggerServerCallback(callbackName, function(result)
        nuiCb(result or { ok = false })
    end, ...)
end

RegisterNUICallback('bridgeStatus', function(_, cb)
    triggerCallback('realrpg_clothing_designer:bridge:status', cb)
end)

RegisterNUICallback('getTemplateCatalog', function(_, cb)
    triggerCallback('realrpg_clothing_designer:getTemplateCatalog', cb)
end)

RegisterNUICallback('rescanTemplateCatalog', function(_, cb)
    triggerCallback('realrpg_clothing_designer:bridge:rescanTemplates', cb)
end)

RegisterNUICallback('extractTemplateTexture', function(data, cb)
    triggerCallback('realrpg_clothing_designer:bridge:extractTexture', function(result)
        if result and result.ok then notify('UV textúra kinyerve.', 'success') else notify((result and result.error) or 'Nem sikerült kinyerni a textúrát.', 'error') end
        cb(result or { ok = false })
    end, data and data.template or data or {})
end)

RegisterNUICallback('injectTemplateTexture', function(data, cb)
    triggerCallback('realrpg_clothing_designer:bridge:injectTexture', function(result)
        if result and result.ok then notify(('Új .ytd elkészült: %s'):format(result.outputPath or result.outputFile or 'stream'), 'success') else notify((result and result.error) or 'Nem sikerült az export.', 'error') end
        cb(result or { ok = false })
    end, data or {})
end)

RegisterNUICallback('applyLiveTexture', function(data, cb)
    data = data or {}
    local image = data.imageData or data.dataUri or data.image
    local originalTxd = data.originalTxd or data.txd or (data.template and data.template.txdName)
    local originalTxn = data.originalTxn or data.txn or data.textureName or (data.template and data.template.textureName)

    if not Config.TextureBridge or not Config.TextureBridge.livePreview or not Config.TextureBridge.livePreview.enabled then cb({ ok = false, error = 'live_preview_disabled' }) return end
    if not image or image == '' then cb({ ok = false, error = 'image_missing' }) return end
    if not originalTxd or originalTxd == '' or not originalTxn or originalTxn == '' then cb({ ok = false, error = 'original_texture_missing' }) return end

    liveCounter = liveCounter + 1
    local txdName = (Config.TextureBridge.livePreview.runtimeTxdPrefix or 'rcd_live_') .. tostring(GetPlayerServerId(PlayerId())) .. '_' .. tostring(liveCounter)
    local txnName = Config.TextureBridge.livePreview.runtimeTextureName or 'diffuse_live'

    local ok, err = pcall(function()
        local runtimeTxd = CreateRuntimeTxd(txdName)
        CreateRuntimeTextureFromImage(runtimeTxd, txnName, image)
        AddReplaceTexture(originalTxd, originalTxn, txdName, txnName)
        liveReplacements[#liveReplacements + 1] = { originalTxd = originalTxd, originalTxn = originalTxn, txdName = txdName, txnName = txnName }
    end)

    if not ok then cb({ ok = false, error = 'runtime_texture_failed', detail = tostring(err) }) return end
    cb({ ok = true, runtimeTxd = txdName, runtimeTxn = txnName })
end)

RegisterNUICallback('clearLiveTextures', function(_, cb)
    for _, item in ipairs(liveReplacements) do pcall(function() RemoveReplaceTexture(item.originalTxd, item.originalTxn) end) end
    liveReplacements = {}
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, item in ipairs(liveReplacements) do pcall(function() RemoveReplaceTexture(item.originalTxd, item.originalTxn) end) end
end)
