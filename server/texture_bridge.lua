local ESX = exports['es_extended']:getSharedObject()

local function bridgeCfg()
    Config.TextureBridge = Config.TextureBridge or {}
    return Config.TextureBridge
end

local function isBridgeAllowed(src)
    local cfg = bridgeCfg()
    if cfg.allowNonAdminEditor then return true end
    if src == 0 then return true end
    if Config.Admin and Config.Admin.enabled and IsPlayerAceAllowed(src, Config.AdminPermission) then return true end
    -- If the main authorization flow granted the user the designer, the NUI can still save normal designs,
    -- but raw .ytd injection stays admin-only by default because it writes streamable files.
    return false
end

local function normalizeBaseUrl(url)
    url = tostring(url or '')
    url = url:gsub('/+$', '')
    return url
end

local function safeJsonDecode(body)
    if not body or body == '' then return nil end
    local ok, data = pcall(json.decode, body)
    if ok then return data end
    return nil
end

local function bridgeHeaders()
    local token = bridgeCfg().token or ''
    local headers = { ['Content-Type'] = 'application/json' }
    if token ~= '' then headers['X-RealRPG-Bridge-Token'] = token end
    return headers
end

local function bridgePost(path, payload, cb)
    local cfg = bridgeCfg()
    if not cfg.enabled then cb({ ok = false, error = 'texture_bridge_disabled' }) return end
    local endpoint = normalizeBaseUrl(cfg.endpoint)
    if endpoint == '' then cb({ ok = false, error = 'texture_bridge_endpoint_missing' }) return end

    PerformHttpRequest(endpoint .. path, function(status, body)
        local decoded = safeJsonDecode(body)
        if status < 200 or status >= 300 then
            cb(decoded or { ok = false, error = ('bridge_http_%s'):format(status), body = body })
            return
        end
        cb(decoded or { ok = false, error = 'bridge_invalid_json' })
    end, 'POST', json.encode(payload or {}), bridgeHeaders())
end

local function bridgeGet(path, cb)
    local cfg = bridgeCfg()
    if not cfg.enabled then cb({ ok = false, error = 'texture_bridge_disabled' }) return end
    local endpoint = normalizeBaseUrl(cfg.endpoint)
    PerformHttpRequest(endpoint .. path, function(status, body)
        local decoded = safeJsonDecode(body)
        if status < 200 or status >= 300 then
            cb(decoded or { ok = false, error = ('bridge_http_%s'):format(status), body = body })
            return
        end
        cb(decoded or { ok = false, error = 'bridge_invalid_json' })
    end, 'GET', '', bridgeHeaders())
end

ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:status', function(source, cb)
    if not isBridgeAllowed(source) then cb({ ok = false, error = 'admin_only' }) return end
    bridgeGet('/status', cb)
end)


ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:rescanTemplates', function(source, cb)
    if not isBridgeAllowed(source) then cb({ ok = false, error = 'admin_only' }) return end

    local rescanResult = nil
    local ok, err = pcall(function()
        rescanResult = exports[GetCurrentResourceName()]:rescanTemplates()
    end)

    if not ok then
        cb({ ok = false, error = 'rescan_failed', detail = tostring(err) })
        return
    end

    local catalog = {}
    local okCatalog, catalogErr = pcall(function()
        catalog = exports[GetCurrentResourceName()]:getTemplateCatalog() or {}
    end)

    if not okCatalog then
        cb({ ok = false, error = 'catalog_after_rescan_failed', detail = tostring(catalogErr), rescan = rescanResult })
        return
    end

    cb({ ok = true, rescan = rescanResult, catalog = catalog })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:extractTexture', function(source, cb, template)
    if not isBridgeAllowed(source) then cb({ ok = false, error = 'admin_only' }) return end
    bridgePost('/extract', {
        source = source,
        template = template or {}
    }, cb)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:injectTexture', function(source, cb, payload)
    if not isBridgeAllowed(source) then cb({ ok = false, error = 'admin_only' }) return end
    payload = payload or {}
    local imageData = tostring(payload.imageData or payload.dataUri or '')
    local maxLen = bridgeCfg().maxImageDataLength or 18000000
    if imageData == '' then cb({ ok = false, error = 'image_missing' }) return end
    if #imageData > maxLen then cb({ ok = false, error = 'image_too_large', max = maxLen }) return end

    bridgePost('/inject', {
        source = source,
        template = payload.template or {},
        imageData = imageData,
        outputName = payload.outputName,
        outputPath = payload.outputPath
    }, cb)
end)

exports('textureBridgeStatus', function(cb)
    bridgeGet('/status', cb or function() end)
end)

exports('extractTexture', function(template, cb)
    bridgePost('/extract', { template = template or {} }, cb or function() end)
end)

exports('injectTexture', function(payload, cb)
    bridgePost('/inject', payload or {}, cb or function() end)
end)
