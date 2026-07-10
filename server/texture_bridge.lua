local ESX = exports['es_extended']:getSharedObject()

local editorCooldown = {}

local function rateLimit(src, seconds)
    if src == 0 then return false end
    local now = os.time()
    local untilAt = editorCooldown[src] or 0
    if untilAt > now then return true end
    editorCooldown[src] = now + (seconds or 2)
    return false
end

AddEventHandler('playerDropped', function() editorCooldown[source] = nil end)

local function bridgeCfg()
    Config.TextureBridge = Config.TextureBridge or {}
    return Config.TextureBridge
end

local function isBridgeAllowed(src)
    local cfg = bridgeCfg()
    if cfg.allowNonAdminEditor then return true end
    if src == 0 then return true end
    if Config.Admin and Config.Admin.enabled and IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then return true end
    return false
end

-- Template rescan is safe to run from the editor. Raw YTD extract/inject stays admin-only below.
local function isEditorAllowed(src)
    -- Reading/extracting a configured server template is required for player-side design.
    -- File injection remains admin-only through isBridgeAllowed.
    return src == 0 or src > 0
end

local function isTemplateRescanAllowed(src)
    if src == 0 then return true end
    if Config.TextureBridge and Config.TextureBridge.allowNonAdminEditor then return true end
    return IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin')
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
    if endpoint == '' then cb({ ok = false, error = 'texture_bridge_endpoint_missing' }) return end

    PerformHttpRequest(endpoint .. path, function(status, body)
        local decoded = safeJsonDecode(body)
        if status < 200 or status >= 300 then
            cb(decoded or { ok = false, error = ('bridge_http_%s'):format(status), body = body })
            return
        end
        cb(decoded or { ok = false, error = 'bridge_invalid_json' })
    end, 'GET', '', bridgeHeaders())
end

local function slash(path)
    return tostring(path or ''):gsub('\\', '/'):gsub('//+', '/')
end

local function joinPath(...)
    local out = {}
    for i = 1, select('#', ...) do
        local p = tostring(select(i, ...) or '')
        p = p:gsub('\\', '/')
        if p ~= '' then
            if #out == 0 then
                out[#out + 1] = p:gsub('/+$', '')
            else
                out[#out + 1] = p:gsub('^/+', ''):gsub('/+$', '')
            end
        end
    end
    return table.concat(out, '/')
end

local function lowerExt(path)
    return (tostring(path or ''):lower():match('%.([%w_]+)$') or '')
end

local function baseName(path)
    return tostring(path or ''):gsub('\\', '/'):match('([^/]+)$') or tostring(path or '')
end

local function stripExt(file)
    return tostring(file or ''):gsub('%.[^.]+$', '')
end

local function stripAddonPrefix(file)
    return (tostring(file or ''):match('%^(.+)$')) or tostring(file or '')
end

local function relativeToResource(path)
    path = slash(path)
    local res = GetCurrentResourceName()
    local root = slash(GetResourcePath(res) or '')
    local atRoot = '@' .. res .. '/'

    if root ~= '' and path:sub(1, #root) == root then
        return path:sub(#root + 2)
    end

    if path:sub(1, #atRoot) == atRoot then
        return path:sub(#atRoot + 1)
    end

    local idx = path:find('templates/cloth_templates', 1, true)
    if idx then return path:sub(idx) end

    return path
end

-- FXServer/Windows quirk:
-- io.readdir(file.ydd) can return a valid empty handle, so checking io.readdir() first
-- makes real files look like empty folders. We must classify known file extensions first.
local function collectTemplateFiles(root)
    root = slash(root)
    local files = {}
    local visited = {}

    local function walk(dir)
        dir = slash(dir)
        if visited[dir] then return end
        visited[dir] = true

        local handle = io.readdir(dir)
        if not handle then return end

        for name in handle:lines() do
            if name and name ~= '' and name ~= '.' and name ~= '..' then
                local full = slash(joinPath(dir, name))
                local ext = lowerExt(name)

                if ext == 'ydd' or ext == 'ytd' then
                    files[#files + 1] = full
                elseif name ~= '.keep' then
                    walk(full)
                end
            end
        end

        handle:close()
    end

    walk(root)
    return files
end

local function getRootCandidates()
    local res = GetCurrentResourceName()
    local resourceRoot = slash(GetResourcePath(res) or '')
    local configured = Config.TemplateFlow and Config.TemplateFlow.templateRoot or 'templates/cloth_templates'
    configured = slash(configured)

    local candidates = {}
    if resourceRoot ~= '' then candidates[#candidates + 1] = joinPath(resourceRoot, configured) end
    candidates[#candidates + 1] = '@' .. res .. '/' .. configured
    candidates[#candidates + 1] = configured
    candidates[#candidates + 1] = './' .. configured

    local seen, out = {}, {}
    for _, c in ipairs(candidates) do
        c = slash(c)
        if c ~= '' and not seen[c] then
            seen[c] = true
            out[#out + 1] = c
        end
    end
    return out
end

local function supportedGender(gender)
    local genders = Config.TemplateFlow and Config.TemplateFlow.genders or { male = true, female = true }
    return genders[tostring(gender or ''):lower()] == true
end

local function supportedComponent(component)
    local comps = Config.TemplateFlow and Config.TemplateFlow.supportedComponents or {}
    return comps[tostring(component or ''):lower()] == true
end

local function parseTemplateFile(fullPath)
    local rel = relativeToResource(fullPath)
    local gender, component, fileName = slash(rel):match('^templates/cloth_templates/([^/]+)/([^/]+)/([^/]+)$')
    if not gender then
        return nil, 'wrong_folder_structure', rel
    end

    gender = gender:lower()
    component = component:lower()

    if not supportedGender(gender) then return nil, 'top_folder_must_be_male_or_female', rel end
    if not supportedComponent(component) then return nil, 'unsupported_component_folder', rel end

    local ext = lowerExt(fileName)
    if ext ~= 'ydd' and ext ~= 'ytd' then return nil, 'unsupported_file_type', rel end

    local logicalFile = stripAddonPrefix(fileName)
    local logicalStem = stripExt(logicalFile):lower()

    if logicalStem:sub(1, #component) ~= component then
        return nil, 'file_prefix_must_match_component', rel
    end

    local drawable = tonumber(logicalStem:match('_(%d+)_')) or tonumber(logicalStem:match('_(%d+)$')) or 0
    local texture = tonumber(logicalStem:match('_a_(%d+)')) or 0
    local tf = Config.TemplateFlow or {}

    local templateKey = ('%s_%s_%s'):format(gender, component, logicalStem:gsub('_[ur]$', ''))
    return {
        rel = rel,
        full = slash(fullPath),
        fileName = fileName,
        logicalFile = logicalFile,
        stem = logicalStem,
        ext = ext,
        gender = gender,
        component = component,
        drawable = drawable,
        texture = texture,
        previewType = (tf.componentToPreviewType and tf.componentToPreviewType[component]) or 'hoodie',
        templateKey = templateKey,
        slotPath = joinPath(tf.slotRoot or 'templates/template_slots', templateKey)
    }, nil, rel
end

local function chooseYddTemplates(files, result)
    local allYtdByFolder = {}
    local yddByKey = {}

    for _, full in ipairs(files) do
        result.filesFound = result.filesFound + 1
        local parsed, reason, rel = parseTemplateFile(full)
        if parsed then
            if parsed.ext == 'ytd' then
                local folder = slash(parsed.rel):gsub('/[^/]+$', '')
                allYtdByFolder[folder] = allYtdByFolder[folder] or {}
                allYtdByFolder[folder][#allYtdByFolder[folder] + 1] = parsed.rel
            elseif parsed.ext == 'ydd' then
                local key = parsed.gender .. '/' .. parsed.component .. '/' .. parsed.stem
                local old = yddByKey[key]
                -- Prefer the freemode-prefixed stream name (mp_m_freemode_01^...) when both variants exist.
                -- FiveM replacement clothing is streamed reliably with the collection/ped prefix intact.
                local oldPrefixed = old and old.fileName:find('^', 1, true) ~= nil
                local newPrefixed = parsed.fileName:find('^', 1, true) ~= nil
                if not old or (newPrefixed and not oldPrefixed) then
                    yddByKey[key] = parsed
                end
            end
        else
            result.skipped = result.skipped + 1
            result.skippedFiles[#result.skippedFiles + 1] = { path = rel or tostring(full), reason = reason }
        end
    end

    local out = {}
    for _, ydd in pairs(yddByKey) do
        local folder = slash(ydd.rel):gsub('/[^/]+$', '')
        local wanted = ydd.component .. '_diff_' .. string.format('%03d', ydd.drawable)
        local ytds = allYtdByFolder[folder] or {}
        local bestYtd = nil

        local wantsPrefix = ydd.fileName:find('^', 1, true) ~= nil
        local function pick(matchText)
            local fallback = nil
            for _, ytd in ipairs(ytds) do
                local bn = baseName(ytd):lower()
                if bn:find(matchText, 1, true) then
                    fallback = fallback or ytd
                    local hasPrefix = baseName(ytd):find('^', 1, true) ~= nil
                    if hasPrefix == wantsPrefix then return ytd end
                end
            end
            return fallback
        end
        bestYtd = pick(wanted)
        if not bestYtd then bestYtd = pick(ydd.component .. '_diff') end

        if bestYtd then
            ydd.texturePath = bestYtd
            out[#out + 1] = ydd
        else
            result.skipped = result.skipped + 1
            result.skippedFiles[#result.skippedFiles + 1] = {
                path = ydd.rel,
                reason = 'matching_diffuse_ytd_missing'
            }
        end
    end

    table.sort(out, function(a, b)
        return (a.gender .. a.component .. string.format('%04d', a.drawable) .. a.fileName) < (b.gender .. b.component .. string.format('%04d', b.drawable) .. b.fileName)
    end)

    return out
end

local function registerTemplateRow(t)
    local meta = {
        source = 'bridge-filetype-safe-scan',
        templateKey = t.templateKey,
        templatePath = t.rel,
        ytdPath = t.texturePath,
        texturePath = t.texturePath,
        slotPath = t.slotPath,
        docs = 'templates/cloth_templates/<gender>/<component>/<file>.ydd + matching *_diff_*.ytd'
    }

    local image = nil
    local previewPath = nil
    local name = t.stem
    local fileType = 'ydd'
    local category = t.component
    local componentKey = t.component
    local modelName = stripExt(t.logicalFile)
    local textureName = t.texturePath and stripAddonPrefix(stripExt(baseName(t.texturePath))) or (t.component .. '_diff_' .. string.format('%03d', t.drawable) .. '_a_uni')
    local active = 1
    local managedPreview = 0
    local skippedReason = nil

    local exists = MySQL.single.await(
        'SELECT id FROM realrpg_clothing_templates WHERE file_name = ? AND gender = ? AND category = ? LIMIT 1',
        { t.fileName, t.gender, category }
    )

    if exists and exists.id then
        MySQL.update.await([[
            UPDATE realrpg_clothing_templates
            SET name = ?, file_type = ?, preview_type = ?, component_key = ?, model_name = ?, texture_name = ?,
                drawable = ?, texture = ?, image = ?, meta = ?, active = ?, template_key = ?, template_path = ?,
                preview_path = ?, slot_path = ?, managed_preview = ?, skipped_reason = ?, updated_at = NOW()
            WHERE id = ?
        ]], {
            name, fileType, t.previewType, componentKey, modelName, textureName,
            t.drawable, t.texture, image, json.encode(meta), active, t.templateKey, t.rel,
            previewPath, t.slotPath, managedPreview, skippedReason, exists.id
        })
        return exists.id, 'updated'
    end

    local id = MySQL.insert.await([[
        INSERT INTO realrpg_clothing_templates
        (name, file_name, file_type, category, gender, preview_type, component_key, model_name, texture_name,
         drawable, texture, image, meta, active, template_key, template_path, preview_path, slot_path,
         managed_preview, skipped_reason, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        name, t.fileName, fileType, category, t.gender, t.previewType, componentKey, modelName, textureName,
        t.drawable, t.texture, image, json.encode(meta), active, t.templateKey, t.rel, previewPath, t.slotPath,
        managedPreview, skippedReason
    })

    return id, 'inserted'
end

local function getCatalog()
    local rows = MySQL.query.await([[
        SELECT id, name, file_name, file_type, category, gender, preview_type, component_key, model_name,
               texture_name, drawable, texture, image, meta, active, template_key, template_path,
               preview_path, slot_path, managed_preview, skipped_reason, updated_at
        FROM realrpg_clothing_templates
        WHERE active = 1
        ORDER BY gender, category, drawable, file_name
    ]], {}) or {}

    for _, row in ipairs(rows) do
        row.meta = safeJsonDecode(row.meta) or {}
        row.template_key = row.template_key or row.meta.templateKey
        row.template_path = row.template_path or row.meta.templatePath
        row.texture_path = row.meta.texturePath or row.meta.ytdPath
        row.ytd_path = row.meta.ytdPath or row.meta.texturePath
    end

    return rows
end

local function performTemplateRescan()
    local result = {
        ok = true,
        roots = {},
        filesFound = 0,
        yddTemplates = 0,
        registered = 0,
        inserted = 0,
        updated = 0,
        skipped = 0,
        skippedFiles = {},
        registeredFiles = {}
    }

    local allFiles = {}
    local seenFiles = {}

    for _, root in ipairs(getRootCandidates()) do
        local files = collectTemplateFiles(root)
        result.roots[#result.roots + 1] = { root = root, count = #files }

        for _, f in ipairs(files) do
            local rel = relativeToResource(f)
            if not seenFiles[rel] then
                seenFiles[rel] = true
                allFiles[#allFiles + 1] = f
            end
        end
    end

    local templates = chooseYddTemplates(allFiles, result)
    result.yddTemplates = #templates

    -- Deactivate previously scanned rows first so deleted/renamed files cannot remain selectable.
    MySQL.update.await([[UPDATE realrpg_clothing_templates
        SET active = 0, updated_at = NOW()
        WHERE template_path LIKE 'templates/cloth_templates/%']])

    for _, t in ipairs(templates) do
        local ok, idOrErr, mode = pcall(registerTemplateRow, t)
        if ok and idOrErr then
            result.registered = result.registered + 1
            if mode == 'updated' then result.updated = result.updated + 1 else result.inserted = result.inserted + 1 end
            result.registeredFiles[#result.registeredFiles + 1] = {
                id = idOrErr,
                path = t.rel,
                ytd = t.texturePath,
                drawable = t.drawable,
                component = t.component,
                gender = t.gender
            }
        else
            result.skipped = result.skipped + 1
            result.skippedFiles[#result.skippedFiles + 1] = { path = t.rel, reason = tostring(idOrErr) }
        end
    end

    result.catalog = getCatalog()
    print(('[RCD][template-scan-v15.2] files=%s ydd=%s registered=%s inserted=%s updated=%s skipped=%s catalog=%s'):format(
        result.filesFound, result.yddTemplates, result.registered, result.inserted, result.updated, result.skipped, #result.catalog
    ))

    return result
end

CreateThread(function()
    Wait(3600)
    if Config.TemplateFlow and Config.TemplateFlow.enabled and Config.TemplateFlow.autoScanTemplatesOnStart then
        local ok, result = pcall(performTemplateRescan)
        if not ok then
            print('[RCD][template-scan] automatic scan failed: ' .. tostring(result))
        end
    end
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:status', function(source, cb)
    if not isEditorAllowed(source) then cb({ ok = false, error = 'not_allowed' }) return end

    bridgeGet('/status', function(status)
        status = status or { ok = false, error = 'bridge_no_response' }

        if not isBridgeAllowed(source) then
            -- Players only need readiness/capability information. Never expose server paths.
            status.designerRoot = nil
            status.workerRoot = nil
            status.bridgePath = nil
            status.texconvPath = nil
            status.outputDir = nil
            status.workDir = nil
        end

        cb(status)
    end)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:rescanTemplates', function(source, cb)
    if not isTemplateRescanAllowed(source) then cb({ ok = false, error = 'admin_only' }) return end

    local ok, result = pcall(performTemplateRescan)
    if not ok then
        cb({ ok = false, error = 'rescan_failed', detail = tostring(result) })
        return
    end

    cb({ ok = true, rescan = result, catalog = result.catalog or {} })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:bridge:extractTexture', function(source, cb, template)
    if not isEditorAllowed(source) then cb({ ok = false, error = 'not_allowed' }) return end
    if rateLimit(source, 2) then cb({ ok = false, error = 'rate_limited' }) return end
    template = template or {}

    -- Non-admin users may only extract templates registered by the scanner.
    if source > 0 and not IsPlayerAceAllowed(source, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then
        local id = tonumber(template.id)
        if not id then cb({ ok = false, error = 'template_id_required' }) return end
        local row = MySQL.single.await('SELECT * FROM realrpg_clothing_templates WHERE id = ? AND active = 1 LIMIT 1', { id })
        if not row then cb({ ok = false, error = 'template_not_found' }) return end
        local meta = safeJsonDecode(row.meta) or {}
        template = {
            id = row.id, name = row.name, gender = row.gender, component = row.component_key or row.category,
            category = row.category, drawable = row.drawable, texture = row.texture,
            templatePath = row.template_path or meta.templatePath,
            yddPath = row.template_path or meta.templatePath,
            ytdPath = meta.ytdPath or meta.texturePath,
            texturePath = meta.texturePath or meta.ytdPath,
            textureName = row.texture_name
        }
    end

    bridgePost('/extract', { source = source, template = template }, cb)
end)

local function findTextureKey(component)
    component = tostring(component or ''):lower()
    local skinKey = Config.TemplateFlow and Config.TemplateFlow.componentToSkinKey and Config.TemplateFlow.componentToSkinKey[component]
    if not skinKey then return nil, nil end
    for _, entry in ipairs(Config.Components or {}) do
        if entry.key == skinKey then return entry.key, entry.tex end
    end
    for _, entry in ipairs(Config.Props or {}) do
        if entry.key == skinKey then return entry.key, entry.tex end
    end
    return skinKey, skinKey:gsub('_1$', '_2')
end

local function updateExportedDesign(payload, result)
    local textureIndex = tonumber(result and result.textureIndex)
    if textureIndex == nil then return false, 'generated_texture_has_no_clothing_slot' end

    local template = payload.template or {}
    local component = template.component or template.category or template.component_key
    local drawableKey, textureKey = findTextureKey(component)
    if not drawableKey or not textureKey then return false, 'component_skin_mapping_missing' end

    local customTexture = {
        outputFile = result.outputFile,
        outputPath = result.outputPath,
        textureName = result.textureName,
        textureIndex = textureIndex,
        slotLetter = result.slotLetter,
        component = component,
        drawable = tonumber(template.drawable) or 0,
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }

    local orderId = tonumber(payload.orderId)
    local designId = tonumber(payload.designId)
    local order = nil
    if orderId then
        order = MySQL.single.await('SELECT * FROM realrpg_clothing_orders WHERE id = ? LIMIT 1', { orderId })
        if order and not designId then designId = tonumber(order.design_id) end
    end

    if designId then
        local design = MySQL.single.await('SELECT skin, components FROM realrpg_clothing_designs WHERE id = ? LIMIT 1', { designId })
        if design then
            local skin = safeJsonDecode(design.skin) or {}
            local components = safeJsonDecode(design.components) or {}
            skin[drawableKey] = tonumber(template.drawable) or skin[drawableKey] or 0
            skin[textureKey] = textureIndex
            components[drawableKey] = skin[drawableKey]
            components[textureKey] = textureIndex
            MySQL.update.await('UPDATE realrpg_clothing_designs SET skin = ?, components = ? WHERE id = ?', { json.encode(skin), json.encode(components), designId })
        end
    end

    if order then
        local metadata = safeJsonDecode(order.metadata) or {}
        metadata.skin = metadata.skin or {}
        metadata.components = metadata.components or {}
        metadata.skin[drawableKey] = tonumber(template.drawable) or metadata.skin[drawableKey] or 0
        metadata.skin[textureKey] = textureIndex
        metadata.components[drawableKey] = metadata.skin[drawableKey]
        metadata.components[textureKey] = textureIndex
        metadata.customTexture = customTexture
        metadata.requiresTextureExport = false
        metadata.designId = designId or metadata.designId
        MySQL.update.await('UPDATE realrpg_clothing_orders SET metadata = ?, design_id = ? WHERE id = ?', { json.encode(metadata), designId, orderId })
    end

    return true, customTexture
end

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
    }, function(result)
        if result and result.ok and (payload.orderId or payload.designId) then
            local updated, detail = updateExportedDesign(payload, result)
            result.mappingReady = updated
            if updated then
                result.customTexture = detail
            else
                result.warning = detail
            end
        end
        cb(result)
    end)
end)

RegisterCommand('rcd_bridge_rescan', function(src)
    if src > 0 and not isTemplateRescanAllowed(src) then return end

    local ok, result = pcall(performTemplateRescan)
    if not ok then
        local msg = '[RCD] bridge rescan failed: ' .. tostring(result)
        if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', msg } }) else print(msg) end
        return
    end

    local msg = ('Bridge template rescan: files=%s ydd=%s registered=%s inserted=%s updated=%s skipped=%s catalog=%s'):format(
        result.filesFound or 0,
        result.yddTemplates or 0,
        result.registered or 0,
        result.inserted or 0,
        result.updated or 0,
        result.skipped or 0,
        result.catalog and #result.catalog or 0
    )

    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', msg } }) else print('[RCD] ' .. msg) end
end, true)

RegisterCommand('rcd_scan_debug', function(src)
    if src > 0 and not isTemplateRescanAllowed(src) then return end

    local result = performTemplateRescan()
    local lines = {
        ('files=%s ydd=%s registered=%s inserted=%s updated=%s skipped=%s catalog=%s'):format(result.filesFound, result.yddTemplates, result.registered, result.inserted, result.updated, result.skipped, result.catalog and #result.catalog or 0),
        'Roots:'
    }

    for _, r in ipairs(result.roots or {}) do
        lines[#lines + 1] = ('- %s | files=%s'):format(r.root, r.count)
    end

    if result.registeredFiles and #result.registeredFiles > 0 then
        lines[#lines + 1] = 'Registered examples:'
        for i = 1, math.min(10, #result.registeredFiles) do
            local f = result.registeredFiles[i]
            lines[#lines + 1] = ('- %s | ytd=%s'):format(f.path or '?', f.ytd or 'missing')
        end
    end

    if result.skippedFiles and #result.skippedFiles > 0 then
        lines[#lines + 1] = 'Skipped examples:'
        for i = 1, math.min(10, #result.skippedFiles) do
            local f = result.skippedFiles[i]
            lines[#lines + 1] = ('- %s | %s'):format(f.path or '?', f.reason or '?')
        end
    end

    for _, line in ipairs(lines) do
        if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', line } }) else print('[RCD][scan-debug] ' .. line) end
    end
end, true)

exports('textureBridgeStatus', function(cb)
    bridgeGet('/status', cb or function() end)
end)

exports('extractTexture', function(template, cb)
    bridgePost('/extract', { template = template or {} }, cb or function() end)
end)

exports('injectTexture', function(payload, cb)
    bridgePost('/inject', payload or {}, cb or function() end)
end)

exports('bridgeRescanTemplates', function()
    return performTemplateRescan()
end)
