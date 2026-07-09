local ESX = exports['es_extended']:getSharedObject()

local uiOpen, screenshotOpen, cam, previewPed, previewObject = false, false, nil, nil, nil
local currentFov, currentFocus = Config.Focus[Config.Studio.defaultFocus].fov, Config.Studio.defaultFocus
local oldSkin, originalCoords, currentShopCoords = nil, nil, nil
local previewState = { skin = {}, components = {}, props = {}, canvas = {}, previewType = 'hoodie', mode = 'ped_fallback' }

-- BUGFIX (V14): Config.RPC.publicOpenEvent/realrpgOpenEvent were declared but the event
-- names were hardcoded everywhere instead of reading them from config. Defined here (top
-- of file, before any usage below) so both the RPC-gated event and the legacy direct-open
-- alias are registered using the configured names, letting server owners actually rename
-- them via config as the docs imply.
local rpcPublicOpenEvent = (Config.RPC and Config.RPC.publicOpenEvent) or 'realrpg_clothing_designer:client:openClothingDesigner'
local rpcLegacyOpenEvent = (Config.RPC and Config.RPC.realrpgOpenEvent) or 'realrpg_clothing_designer:open'

local function dbg(...)
    if Config.Debug then print('[realrpg_clothing_designer:v10]', ...) end
end

local function notify(msg, typ)
    typ = typ or 'info'
    if GetResourceState('realrpg_notify') == 'started' then
        exports['realrpg_notify']:Notify(typ, msg, 3500)
    elseif ESX and ESX.ShowNotification then
        ESX.ShowNotification(msg)
    else
        print(('[%s] %s'):format(typ, msg))
    end
end

local function t(key, ...)
    local str = Config.Translations[key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then return nil end
    end
    return hash
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then return false end
    end
    return true
end

local function getGender()
    local model = GetEntityModel(PlayerPedId())
    if model == joaat('mp_f_freemode_01') then return 'female' end
    return 'male'
end

local function getPreviewPedModel()
    return getGender() == 'female' and Config.Studio.femaleModel or Config.Studio.defaultModel
end

local function componentByKey(key)
    for _, c in ipairs(Config.Components) do
        if c.key == key or c.tex == key then return c end
    end
    return nil
end

local function propByKey(key)
    for _, p in ipairs(Config.Props) do
        if p.key == key or p.tex == key then return p end
    end
    return nil
end

local function exportSkinFromPed(ped)
    local skin = {}
    for _, c in ipairs(Config.Components) do
        skin[c.key] = GetPedDrawableVariation(ped, c.id)
        skin[c.tex] = GetPedTextureVariation(ped, c.id)
    end
    for _, p in ipairs(Config.Props) do
        skin[p.key] = GetPedPropIndex(ped, p.id)
        skin[p.tex] = GetPedPropTextureIndex(ped, p.id)
    end
    return skin
end

local function importSkinToPed(ped, skin)
    skin = skin or {}
    for _, c in ipairs(Config.Components) do
        if skin[c.key] ~= nil then
            SetPedComponentVariation(ped, c.id, tonumber(skin[c.key]) or 0, tonumber(skin[c.tex]) or 0, 2)
        end
    end
    for _, p in ipairs(Config.Props) do
        if skin[p.key] ~= nil then
            local drawable = tonumber(skin[p.key]) or -1
            local texture = tonumber(skin[p.tex]) or 0
            if drawable < 0 then ClearPedProp(ped, p.id) else SetPedPropIndex(ped, p.id, drawable, texture, true) end
        end
    end
end

local function getSkin(cb)
    if Config.Appearance.system == 'fivem-appearance' and GetResourceState('fivem-appearance') == 'started' then
        cb(exports['fivem-appearance']:getPedAppearance(PlayerPedId()))
    elseif Config.Appearance.system == 'illenium-appearance' and GetResourceState('illenium-appearance') == 'started' then
        cb(exports['illenium-appearance']:getPedAppearance(PlayerPedId()))
    else
        TriggerEvent('skinchanger:getSkin', function(skin) cb(skin or exportSkinFromPed(PlayerPedId())) end)
    end
end

local function applySkinToPlayer(skin, save)
    if not skin then return end
    if Config.Appearance.system == 'fivem-appearance' and GetResourceState('fivem-appearance') == 'started' then
        exports['fivem-appearance']:setPedAppearance(PlayerPedId(), skin)
        if save then TriggerServerEvent('realrpg_clothing_designer:saveAppearanceSkin', skin) end
    elseif Config.Appearance.system == 'illenium-appearance' and GetResourceState('illenium-appearance') == 'started' then
        exports['illenium-appearance']:setPedAppearance(PlayerPedId(), skin)
        if save then TriggerServerEvent('realrpg_clothing_designer:saveAppearanceSkin', skin) end
    else
        TriggerEvent('skinchanger:loadSkin', skin)
        if save then TriggerServerEvent('esx_skin:save', skin) end
    end
end

local function makeBaseMannequin(ped)
    SetPedDefaultComponentVariation(ped)
    ClearAllPedProps(ped)
    SetPedComponentVariation(ped, 1, 0, 0, 2)
    SetPedComponentVariation(ped, 3, 15, 0, 2)
    SetPedComponentVariation(ped, 4, 14, 0, 2)
    SetPedComponentVariation(ped, 5, 0, 0, 2)
    SetPedComponentVariation(ped, 6, 1, 0, 2)
    SetPedComponentVariation(ped, 7, 0, 0, 2)
    SetPedComponentVariation(ped, 8, 15, 0, 2)
    SetPedComponentVariation(ped, 9, 0, 0, 2)
    SetPedComponentVariation(ped, 10, 0, 0, 2)
    SetPedComponentVariation(ped, 11, 15, 0, 2)
    SetEntityAlpha(ped, 255, false)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    if Config.Studio.idleAnim and loadAnim(Config.Studio.idleAnim.dict) then
        TaskPlayAnim(ped, Config.Studio.idleAnim.dict, Config.Studio.idleAnim.name, 2.0, 2.0, -1, 1, 0.0, false, false, false)
    end
end

local function getSpawnCoords()
    local playerPed = PlayerPedId()
    local pcoords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    return pcoords + forward * Config.Studio.spawnDistance, GetEntityHeading(playerPed) + 180.0
end

local function createPreviewPed()
    local coords, heading = getSpawnCoords()
    local hash = loadModel(getPreviewPedModel())
    if not hash then return nil end
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(ped, true, true)
    makeBaseMannequin(ped)
    return ped
end

local function createPreviewObject(kind)
    local data = Config.PreviewObjects[kind or 'hoodie']
    if not data then return nil end
    local hash = loadModel(data.model)
    if not hash then return nil end
    local coords, heading = getSpawnCoords()
    local obj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z + 0.05, false, false, false)
    SetEntityHeading(obj, heading)
    SetEntityAsMissionEntity(obj, true, true)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function deleteEntities()
    if previewPed and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
    if previewObject and DoesEntityExist(previewObject) then DeleteEntity(previewObject) end
    previewPed, previewObject = nil, nil
end

local function activeEntity()
    if previewObject and DoesEntityExist(previewObject) then return previewObject end
    if previewPed and DoesEntityExist(previewPed) then return previewPed end
    return nil
end

local function focusCamera(mode, fovOverride)
    local ent = activeEntity()
    if not ent then return end
    mode = mode or currentFocus or Config.Studio.defaultFocus
    currentFocus = mode
    local cfg = Config.Focus[mode] or Config.Focus.full
    local coords = GetEntityCoords(ent)
    local heading = math.rad(GetEntityHeading(ent))
    local off = cfg.offset
    local camX = coords.x + math.sin(heading) * off.y + math.cos(heading) * off.x
    local camY = coords.y - math.cos(heading) * off.y + math.sin(heading) * off.x
    local camZ = coords.z + off.z
    if not cam then cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetCamCoord(cam, camX, camY, camZ)
    PointCamAtEntity(cam, ent, 0.0, 0.0, cfg.pointZ, true)
    currentFov = fovOverride or currentFov or cfg.fov
    currentFov = math.max(Config.Studio.minFov, math.min(Config.Studio.maxFov, currentFov))
    SetCamFov(cam, currentFov)
    RenderScriptCams(true, true, 350, true, true)
end

local function destroyCam()
    if cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function setPlayerPreviewState(state)
    local ped = PlayerPedId()
    if state then originalCoords = GetEntityCoords(ped) end
    if Config.Studio.freezePlayer then FreezeEntityPosition(ped, state) end
    SetEntityInvincible(ped, state)
    if Config.Studio.hidePlayer then SetEntityVisible(ped, not state, false) end
end

local function buildLimits()
    local ped = previewPed or PlayerPedId()
    local components, props = {}, {}
    for _, c in ipairs(Config.Components) do
        local drawable = GetPedDrawableVariation(ped, c.id)
        components[#components + 1] = {
            id = c.id, key = c.key, tex = c.tex, label = c.label, focus = c.focus or 'full',
            drawable = drawable, texture = GetPedTextureVariation(ped, c.id),
            maxDrawable = math.max(GetNumberOfPedDrawableVariations(ped, c.id) - 1, 0),
            maxTexture = math.max(GetNumberOfPedTextureVariations(ped, c.id, drawable) - 1, 0),
            off = c.off
        }
    end
    for _, p in ipairs(Config.Props) do
        local drawable = GetPedPropIndex(ped, p.id)
        props[#props + 1] = {
            id = p.id, key = p.key, tex = p.tex, label = p.label, focus = p.focus or 'head',
            drawable = drawable, texture = GetPedPropTextureIndex(ped, p.id),
            maxDrawable = math.max(GetNumberOfPedPropDrawableVariations(ped, p.id) - 1, 0),
            maxTexture = math.max(GetNumberOfPedPropTextureVariations(ped, p.id, math.max(drawable, 0)) - 1, 0),
            off = p.off
        }
    end
    return components, props
end

local function applyPresetToPreview(preset)
    if not preset or not previewPed then return end
    local skin = preset.components or {}
    for _, c in ipairs(Config.Components) do
        if skin[c.key] ~= nil then
            local drawable, texture = tonumber(skin[c.key]) or 0, tonumber(skin[c.tex]) or 0
            SetPedComponentVariation(previewPed, c.id, drawable, texture, 2)
            previewState.components[tostring(c.id)] = { key = c.key, tex = c.tex, drawable = drawable, texture = texture, id = c.id }
            previewState.skin[c.key] = drawable; previewState.skin[c.tex] = texture
        end
    end
end

local function collectPreviewSkin()
    if previewPed and DoesEntityExist(previewPed) then
        previewState.skin = exportSkinFromPed(previewPed)
    end
    return previewState.skin
end

local function applyPreviewToPlayer(save)
    local skin = collectPreviewSkin()
    if oldSkin and type(oldSkin) == 'table' then
        for k, v in pairs(skin) do oldSkin[k] = v end
        applySkinToPlayer(oldSkin, save)
    else
        importSkinToPed(PlayerPedId(), skin)
        if save then getSkin(function(s) TriggerServerEvent('esx_skin:save', s) end) end
    end
    notify(t('applied'), 'success')
end

local function setupPreview(kind, keepSkin)
    local previousSkin = keepSkin and collectPreviewSkin() or nil
    deleteEntities()
    previewState.previewType = kind or previewState.previewType or 'hoodie'
    previewObject = createPreviewObject(previewState.previewType)
    if previewObject then
        previewState.mode = 'separate_object'
    else
        previewPed = createPreviewPed()
        previewState.mode = 'ped_fallback'
        if previousSkin and previewPed then importSkinToPed(previewPed, previousSkin) end
    end
    currentFov = (Config.Focus[Config.Studio.defaultFocus] or Config.Focus.full).fov
    local data = Config.PreviewObjects[previewState.previewType]
    focusCamera((data and data.focus) or Config.Studio.defaultFocus)
end

local function sendOpenMessage(mode)
    local components, props = buildLimits()
    SendNUIMessage({
        action = mode or 'open',
        playerName = GetPlayerName(PlayerId()),
        gender = getGender(),
        mode = previewState.mode,
        categories = Config.Categories,
        components = components,
        props = props,
        presets = Config.Presets,
        previewObjects = Config.PreviewObjects,
        playerModels = Config.PlayerModels,
        prices = Config.Price,
        realCoin = Config.RealCoin,
        imageGenerator = Config.ImageGenerator,
        flow = Config.Flow,
        isAdmin = false,
        backgroundBlur = Config.Studio.backgroundBlur
    })
    ESX.TriggerServerCallback('realrpg_clothing_designer:isAdmin', function(isAdmin)
        if isAdmin then SendNUIMessage({ action = 'adminState', isAdmin = true }) end
    end)
end

local function openDesigner(options)
    if uiOpen then return end
    options = options or {}
    if Config.Authorization and Config.Authorization.Enabled and Config.Authorization.RequireGrantForExternalOpen and not options._authorized then
        ESX.TriggerServerCallback('realrpg_clothing_designer:checkAccess', function(result)
            if result and result.ok then
                options._authorized = true
                openDesigner(options)
            else
                notify((result and result.error) or (Config.Authorization.NotAuthorizedMessage or 'not_authorized'), 'error')
            end
        end, options.context or 'external')
        return
    end
    uiOpen = true
    screenshotOpen = options.screenshotMode == true
    currentShopCoords = options.coords
    previewState = { skin = {}, components = {}, props = {}, canvas = {}, previewType = options.previewType or 'hoodie', mode = 'ped_fallback', characterCreation = options.characterCreation == true or options.creation == true }
    getSkin(function(skin) oldSkin = skin end)
    if Config.Appearance.characterCreationTeleport and options.creation then
        SetEntityCoords(PlayerPedId(), Config.Appearance.characterCreationCoords.x, Config.Appearance.characterCreationCoords.y, Config.Appearance.characterCreationCoords.z)
        SetEntityHeading(PlayerPedId(), Config.Appearance.characterCreationCoords.w)
    end
    -- BUGFIX (V14): Config.TeleportWhenCreatingChar was declared but never applied.
    if previewState.characterCreation and Config.TeleportWhenCreatingChar and Config.TeleportWhenCreatingChar.Enable and not options.skipTeleport then
        local c = Config.TeleportWhenCreatingChar.Coords
        SetEntityCoords(PlayerPedId(), c.x, c.y, c.z, false, false, false, true)
        SetEntityHeading(PlayerPedId(), c.w)
    end
    setPlayerPreviewState(true)
    setupPreview(previewState.previewType)
    if not activeEntity() then
        setPlayerPreviewState(false)
        uiOpen = false
        notify('Nem sikerült létrehozni a 3D clothing preview-t.', 'error')
        return
    end
    SetNuiFocus(true, true)
    sendOpenMessage(screenshotOpen and 'openScreenshot' or 'open')
end

local function closeDesigner(apply, save)
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    if apply then
        applyPreviewToPlayer(save)
    elseif oldSkin and Config.Appearance.restoreOnCancel then
        applySkinToPlayer(oldSkin, false)
        notify(t('cancelled'), 'info')
    end
    -- BUGFIX (V14): originalCoords was captured on open but never used anywhere. Now that
    -- character-creation teleports are actually wired up (see below), restore the player's
    -- original position when the designer is cancelled without applying.
    if not apply and previewState.characterCreation and originalCoords then
        SetEntityCoords(PlayerPedId(), originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, true)
    end
    -- BUGFIX (V14): Config.SetCoordsAfterFinalize / Config.TeleportWhenCreatingChar and
    -- Config.CharacterFinalized were declared but never used anywhere. Wire them up so
    -- character-creation flows can actually teleport the player and run the server hook.
    if previewState.characterCreation then
        if apply and Config.SetCoordsAfterFinalize and Config.SetCoordsAfterFinalize.Enable then
            local c = Config.SetCoordsAfterFinalize.Coords
            SetEntityCoords(PlayerPedId(), c.x, c.y, c.z, false, false, false, true)
            SetEntityHeading(PlayerPedId(), c.w)
        end
        if apply then TriggerServerEvent('realrpg_clothing_designer:characterFinalized') end
    end
    destroyCam()
    deleteEntities()
    setPlayerPreviewState(false)
    SendNUIMessage({ action = 'hide' })
end

exports('openDesigner', openDesigner)
exports('openClothingDesigner', openDesigner)
exports('openScreenshotMenu', function() openDesigner({ screenshotMode = true }) end)
exports('openWardrobe', function() openDesigner({ previewType = 'hoodie', context = 'command' }); Wait(250); SendNUIMessage({ action = 'forceSection', section = 'Saved' }) end)
exports('openOrders', function() openDesigner({ previewType = 'hoodie', context = 'command' }); Wait(250); SendNUIMessage({ action = 'forceSection', section = 'Orders' }) end)

RegisterNetEvent('realrpg_clothing_designer:open', openDesigner)
-- BUGFIX (V14): also register the configurable legacy alias name from
-- Config.RPC.realrpgOpenEvent (falls back to the same literal above when unset/default).
-- rpcLegacyOpenEvent/rpcPublicOpenEvent are defined near the top of this file.
if rpcLegacyOpenEvent ~= 'realrpg_clothing_designer:open' then
    RegisterNetEvent(rpcLegacyOpenEvent, openDesigner)
end
RegisterNetEvent('realrpg_clothing_designer:openStore', function(kind) openDesigner({ previewType = kind or 'hoodie' }) end)
RegisterNetEvent('realrpg_clothing_designer:openScreenshotMenu', function() openDesigner({ screenshotMode = true }) end)
RegisterNetEvent('realrpg_clothing_designer:openOrders', function() openDesigner({ previewType = 'hoodie', context = 'command' }); Wait(250); SendNUIMessage({ action = 'forceSection', section = 'Orders' }) end)

-- Optional RealRPG-like compatibility aliases for migration convenience.
RegisterNetEvent('realrpg_clothing_designer:openCharacterCreationMenu', function(skipReset, skipTeleport, cb)
    openDesigner({ creation = true, skipReset = skipReset, skipTeleport = skipTeleport })
    if cb then cb(true) end
end)
RegisterNetEvent('realrpg_clothing_designer:openCharacterCreationMenuWithoutReset', function(cb)
    openDesigner({ creation = true, skipReset = true, skipTeleport = true })
    if cb then cb(true) end
end)

RegisterCommand(Config.Command, function() openDesigner({ context = 'command' }) end, false)
RegisterCommand(Config.ScreenshotMenuCommand, function() openDesigner({ screenshotMode = true, context = 'command' }) end, false)

RegisterNetEvent('realrpg_clothing_designer:wearOnOff', function(kind, data)
    local ped = PlayerPedId()
    data = data or {}
    if kind == 'prop' then
        local p = propByKey(data.key) or { id = tonumber(data.id), off = { drawable = -1, texture = 0 } }
        if not p.id then return end
        if GetPedPropIndex(ped, p.id) >= 0 then
            ClearPedProp(ped, p.id)
        else
            SetPedPropIndex(ped, p.id, tonumber(data.drawable) or 0, tonumber(data.texture) or 0, true)
        end
    else
        local c = componentByKey(data.key) or { id = tonumber(data.id), off = { drawable = 0, texture = 0 } }
        if not c.id then return end
        local current = GetPedDrawableVariation(ped, c.id)
        local drawable = tonumber(data.drawable) or 0
        if current == drawable then
            SetPedComponentVariation(ped, c.id, tonumber((c.off or {}).drawable) or 0, tonumber((c.off or {}).texture) or 0, 2)
        else
            SetPedComponentVariation(ped, c.id, drawable, tonumber(data.texture) or 0, 2)
        end
    end
    if Config.Appearance.saveOnApply then getSkin(function(skin) TriggerServerEvent('esx_skin:save', skin) end) end
end)

RegisterNetEvent('realrpg_clothing_designer:applyMetadataOutfit', function(metadata)
    metadata = metadata or {}
    local skin = metadata.skin or metadata.components or {}
    if next(skin) then
        getSkin(function(base)
            if type(base) ~= 'table' then base = {} end
            for k, v in pairs(skin) do
                if type(v) == 'table' and v.key then
                    base[v.key] = v.drawable; if v.tex then base[v.tex] = v.texture end
                else
                    base[k] = v
                end
            end
            applySkinToPlayer(base, true)
        end)
    end
end)

RegisterNUICallback('close', function(data, cb)
    closeDesigner(data and data.apply, data and data.save)
    cb({ ok = true })
end)

RegisterNUICallback('rotate', function(data, cb)
    local ent = activeEntity()
    if ent then
        SetEntityHeading(ent, GetEntityHeading(ent) + (tonumber(data.delta) or 0.0))
        focusCamera(data.focus)
    end
    cb({ ok = true })
end)

RegisterNUICallback('zoom', function(data, cb)
    currentFov = currentFov + (tonumber(data.delta) or 0.0)
    focusCamera(currentFocus, currentFov)
    cb({ ok = true, fov = currentFov })
end)

RegisterNUICallback('focus', function(data, cb)
    focusCamera(data and data.focus or Config.Studio.defaultFocus)
    cb({ ok = true })
end)

RegisterNUICallback('changePreviewType', function(data, cb)
    setupPreview(data and data.kind or 'hoodie', true)
    sendOpenMessage('refreshLimits')
    cb({ ok = activeEntity() ~= nil, mode = previewState.mode })
end)

-- BUGFIX (V14): Config.AllowedModels was declared but never checked, so the NUI could
-- request any model hash and setPlayerModel would happily switch the player's ped to it.
-- Also wires up Config.ShowAllPeds (declared but unused): when true it bypasses the
-- AllowedModels allow-list entirely and permits any ped model.
local function isModelAllowed(model)
    if Config.ShowAllPeds then return true end
    if not Config.AllowedModels or #Config.AllowedModels == 0 then return true end
    local modelStr = tostring(model)
    for _, allowed in ipairs(Config.AllowedModels) do
        if tostring(allowed):lower() == modelStr:lower() then return true end
    end
    return false
end

RegisterNUICallback('setModel', function(data, cb)
    local model = data and data.model
    if not isModelAllowed(model) then
        cb({ ok = false, error = t('not_allowed_model') })
        return
    end
    local hash = model and loadModel(model)
    if hash then
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        Wait(300)
        setPlayerPreviewState(true)
        setupPreview(previewState.previewType, false)
        sendOpenMessage('refreshLimits')
        cb({ ok = true })
    else
        cb({ ok = false, error = 'Invalid model' })
    end
end)

RegisterNUICallback('setComponent', function(data, cb)
    local ped = previewPed
    local id = tonumber(data.id)
    local drawable = tonumber(data.drawable) or 0
    local texture = tonumber(data.texture) or 0
    if ped and DoesEntityExist(ped) and id then
        SetPedComponentVariation(ped, id, drawable, texture, 2)
        local cfg = componentByKey(data.key) or {}
        previewState.components[tostring(id)] = { id = id, key = data.key or cfg.key, tex = data.tex or cfg.tex, drawable = drawable, texture = texture }
        if cfg.key then previewState.skin[cfg.key] = drawable; previewState.skin[cfg.tex] = texture end
        if data.focus then focusCamera(data.focus) end
        cb({ ok = true, maxTexture = math.max(GetNumberOfPedTextureVariations(ped, id, drawable) - 1, 0) })
    else
        cb({ ok = false, error = 'object_mode_requires_stream_assets_or_ped_fallback' })
    end
end)

RegisterNUICallback('setProp', function(data, cb)
    local ped = previewPed
    local id = tonumber(data.id)
    local drawable = tonumber(data.drawable) or -1
    local texture = tonumber(data.texture) or 0
    if ped and DoesEntityExist(ped) and id then
        if drawable < 0 then ClearPedProp(ped, id) else SetPedPropIndex(ped, id, drawable, texture, true) end
        local cfg = propByKey(data.key) or {}
        previewState.props[tostring(id)] = { id = id, key = data.key or cfg.key, tex = data.tex or cfg.tex, drawable = drawable, texture = texture }
        if cfg.key then previewState.skin[cfg.key] = drawable; previewState.skin[cfg.tex] = texture end
        if data.focus then focusCamera(data.focus) end
        cb({ ok = true, maxTexture = math.max(GetNumberOfPedPropTextureVariations(ped, id, math.max(drawable, 0)) - 1, 0) })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local preset = Config.Presets[(tonumber(data.index) or 0) + 1]
    if not preset then cb({ ok = false }) return end
    if preset.preview then setupPreview(preset.preview, true) end
    applyPresetToPreview(preset)
    focusCamera('torso')
    cb({ ok = true })
end)

RegisterNUICallback('saveDesign', function(data, cb)
    local skin = collectPreviewSkin()
    previewState.canvas = data.canvas or previewState.canvas or {}
    ESX.TriggerServerCallback('realrpg_clothing_designer:saveDesign', function(result)
        notify(result and result.ok and t('saved') or (result and result.error or 'Nem sikerült menteni.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, {
        name = data.name or 'RealRPG Design',
        gender = getGender(),
        previewType = previewState.previewType,
        skin = skin,
        components = previewState.components,
        props = previewState.props,
        canvas = previewState.canvas,
        image = data.image
    })
end)

RegisterNUICallback('orderItem', function(data, cb)
    data = data or {}
    data.previewType = previewState.previewType
    data.canvas = data.canvas or previewState.canvas or {}
    data.skin = collectPreviewSkin()
    data.components = previewState.components
    data.props = previewState.props
    data.gender = getGender()
    ESX.TriggerServerCallback('realrpg_clothing_designer:orderItem', function(result)
        notify(result and result.ok and t('item_created') or (result and result.error or 'Nem sikerült itemet készíteni.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('loadMyDesigns', function(_, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:getMyDesigns', function(rows)
        cb({ ok = true, designs = rows or {} })
    end)
end)

RegisterNUICallback('applySavedDesign', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:getDesign', function(row)
        if not row then cb({ ok = false }) return end
        if row.preview_type then setupPreview(row.preview_type, false) end
        if previewPed and row.skin then importSkinToPed(previewPed, row.skin) end
        previewState.skin = row.skin or {}
        previewState.components = row.components or {}
        previewState.props = row.props or {}
        previewState.canvas = row.canvas or {}
        focusCamera('full')
        cb({ ok = true, canvas = previewState.canvas, image = row.image })
    end, tonumber(data.id))
end)


RegisterCommand(Config.WardrobeCommand or 'clothingwardrobe', function()
    openDesigner({ previewType = 'hoodie' })
    Wait(250)
    SendNUIMessage({ action = 'forceSection', section = 'Saved' })
end, false)


RegisterCommand(Config.OrdersCommand or 'clothingorders', function()
    openDesigner({ previewType = 'hoodie' })
    Wait(250)
    SendNUIMessage({ action = 'forceSection', section = 'Orders' })
end, false)

RegisterCommand(Config.AdminCommand or 'clothingadmin', function()
    ESX.TriggerServerCallback('realrpg_clothing_designer:isAdmin', function(isAdmin)
        if isAdmin then
            openDesigner({ previewType = 'hoodie' })
            Wait(250)
            SendNUIMessage({ action = 'adminState', isAdmin = true })
            SendNUIMessage({ action = 'forceSection', section = 'Admin' })
        else
            notify(t('admin_only'), 'error')
        end
    end)
end, false)

RegisterNUICallback('applySavedDesignToPlayer', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:getDesign', function(row)
        if row and row.skin then applySkinToPlayer(row.skin, true); cb({ ok = true }) else cb({ ok = false }) end
    end, tonumber(data.id))
end)

RegisterNUICallback('renameDesign', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:renameDesign', function(result)
        notify(result and result.ok and t('renamed') or (result and result.error or 'Nem sikerült.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id), data.name)
end)

RegisterNUICallback('deleteDesign', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:deleteDesign', function(result)
        notify(result and result.ok and t('deleted') or (result and result.error or 'Nem sikerült.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id))
end)

RegisterNUICallback('duplicateDesign', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:duplicateDesign', function(result)
        notify(result and result.ok and t('duplicated') or (result and result.error or 'Nem sikerült.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id))
end)

RegisterNUICallback('orderSavedDesignItem', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:orderSavedDesignItem', function(result)
        notify(result and result.ok and t('item_created') or (result and result.error or 'Nem sikerült itemet készíteni.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id), data.itemType or 'outfit')
end)

RegisterNUICallback('loadMyOrders', function(_, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:getMyOrders', function(rows)
        cb({ ok = true, orders = rows or {} })
    end)
end)

RegisterNUICallback('cancelOrder', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:cancelOrder', function(result)
        notify(result and result.ok and t('order_cancelled') or (result and result.error or 'Nem sikerült lemondani a rendelést.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id))
end)

RegisterNUICallback('adminListOrders', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminListOrders', function(rows)
        cb({ ok = true, orders = rows or {} })
    end, data and data.status or 'pending')
end)

RegisterNUICallback('adminSetOrderStatus', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminSetOrderStatus', function(result)
        local msg = result and result.ok and ('Státusz frissítve: '..(result.status or data.status or '')) or (result and result.error or 'Nem sikerült.')
        notify(msg, result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id), data.status, data.note)
end)

RegisterNUICallback('adminDeliverOrder', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminDeliverOrder', function(result)
        notify(result and result.ok and 'Item kiadva.' or (result and result.error or 'Nem sikerült itemet kiadni.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id))
end)

RegisterNUICallback('adminListDesigns', function(_, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminListDesigns', function(rows)
        cb({ ok = true, designs = rows or {} })
    end)
end)

RegisterNUICallback('adminLoadDesign', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminGetDesign', function(row)
        if not row then cb({ ok = false }) return end
        if row.preview_type then setupPreview(row.preview_type, false) end
        if previewPed and row.skin then importSkinToPed(previewPed, row.skin) end
        previewState.skin = row.skin or {}
        previewState.components = row.components or {}
        previewState.props = row.props or {}
        previewState.canvas = row.canvas or {}
        cb({ ok = true, canvas = previewState.canvas, image = row.image })
    end, tonumber(data.id))
end)

RegisterNUICallback('adminGiveDesignItem', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminGiveDesignItem', function(result)
        notify(result and result.ok and t('item_created') or (result and result.error or 'Nem sikerült itemet adni.'), result and result.ok and 'success' or 'error')
        cb(result or { ok = false })
    end, tonumber(data.id))
end)

RegisterNUICallback('adminOpenForPlayer', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminOpenForPlayer', function(result)
        cb(result or { ok = false })
    end, tonumber(data.target))
end)

RegisterNUICallback('captureImage', function(data, cb)
    if not Config.ImageGenerator.enabled or GetResourceState(Config.ImageGenerator.resource) ~= 'started' then
        cb({ ok = false, error = 'screenshot-basic nincs elindítva.' })
        return
    end
    local options = { encoding = Config.ImageGenerator.defaultEncoding or 'jpg', quality = Config.ImageGenerator.quality or 0.92 }
    if Config.ImageGenerator.uploadUrl and Config.ImageGenerator.uploadUrl ~= '' then
        exports[Config.ImageGenerator.resource]:requestScreenshotUpload(Config.ImageGenerator.uploadUrl, 'files[]', options, function(result)
            TriggerServerEvent('realrpg_clothing_designer:saveCaptureMeta', data.name or 'capture', data.category, data.drawable, data.texture, result or '')
            cb({ ok = true, result = result })
        end)
    else
        exports[Config.ImageGenerator.resource]:requestScreenshot(options, function(dataUri)
            TriggerServerEvent('realrpg_clothing_designer:saveCaptureMeta', data.name or 'capture', data.category, data.drawable, data.texture, dataUri or '')
            cb({ ok = true, result = dataUri })
        end)
    end
end)

CreateThread(function()
    if Config.Target.enabled and GetResourceState(Config.Target.resource) == 'started' then
        for i, shop in ipairs(Config.Shops) do
            exports.ox_target:addBoxZone({
                coords = shop.coords,
                size = shop.size,
                rotation = shop.rotation,
                debug = Config.Debug,
                options = {{
                    name = 'realrpg_clothing_designer_'..i,
                    icon = 'fa-solid fa-shirt',
                    label = shop.label,
                    onSelect = function() currentShopCoords = shop.coords; openDesigner({ coords = shop.coords }) end
                }}
            })
        end
    elseif Config.Target.useTextUIFallback then
        local shown = false
        while true do
            local wait = 900
            local p = GetEntityCoords(PlayerPedId())
            local near = nil
            for _, shop in ipairs(Config.Shops) do
                if #(p - shop.coords) <= Config.Target.textUIDistance then near = shop break end
            end
            if near and not uiOpen then
                wait = 0
                if not shown and lib and lib.showTextUI then lib.showTextUI('[E] '..near.label); shown = true end
                if IsControlJustPressed(0, 38) then currentShopCoords = near.coords; openDesigner({ coords = near.coords }) end
            else
                if shown and lib and lib.hideTextUI then lib.hideTextUI(); shown = false end
            end
            Wait(wait)
        end
    end
end)



-- V12 safety cleanup and low-cost control loop.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    destroyCam()
    deleteEntities()
    if Config.Studio.hidePlayer then SetEntityVisible(PlayerPedId(), true, false) end
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    if lib and lib.hideTextUI then lib.hideTextUI() end
end)

RegisterNUICallback('getDiagnostics', function(_, cb)
    cb({
        ok = true,
        version = Config.Version or '12.0.0',
        resources = {
            es_extended = GetResourceState('es_extended'),
            oxmysql = GetResourceState('oxmysql'),
            ox_inventory = GetResourceState(Config.Inventory.resource or 'ox_inventory'),
            screenshot_basic = GetResourceState(Config.ImageGenerator.resource or 'screenshot-basic'),
            target = GetResourceState(Config.Target.resource or 'ox_target')
        },
        previewMode = previewState.mode,
        uiOpen = uiOpen,
        activePreview = activeEntity() ~= nil
    })
end)

CreateThread(function()
    while true do
        if uiOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            local ent = activeEntity()
            if ent and IsControlPressed(0, 44) then -- Q
                SetEntityHeading(ent, GetEntityHeading(ent) - Config.Studio.rotationSpeed)
                focusCamera(currentFocus)
            elseif ent and IsControlPressed(0, 38) then -- E
                SetEntityHeading(ent, GetEntityHeading(ent) + Config.Studio.rotationSpeed)
                focusCamera(currentFocus)
            end
            if currentShopCoords and #(GetEntityCoords(PlayerPedId()) - currentShopCoords) > Config.Studio.maxDistanceFromShop then
                closeDesigner(false, false)
            end
            Wait(0)
        else
            Wait(650)
        end
    end
end)

CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        if shop.blip then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, 73)
            SetBlipScale(blip, 0.75)
            SetBlipColour(blip, 27)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(shop.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)


-- V12 template flow helper command
RegisterCommand(Config.TemplateCommand or 'clothingtemplates', function()
    ESX.TriggerServerCallback('realrpg_clothing_designer:scanTemplates', function(result)
        if not result or result.ok == false then
            notify((result and result.error) or 'Nem sikerült template scan-t futtatni.', 'error')
            return
        end
        notify(('Template scan kész. Scanned: %s, registered: %s'):format(result.scanned or 0, result.registered or 0), 'success')
    end)
end, false)

exports('openTemplateManager', function()
    openDesigner({ previewType = 'hoodie' })
    Wait(250)
    SendNUIMessage({ action = 'forceSection', section = 'Studio' })
end)


-- V12 docs-based compatibility layer: RealRPG-style aliases and restricted menu presets.
local wearAliasMap = {
    masks = { kind = 'component', key = 'mask_1' },
    mask = { kind = 'component', key = 'mask_1' },
    hair = { kind = 'component', key = 'hair_1' },
    arms = { kind = 'component', key = 'arms' },
    gloves = { kind = 'component', key = 'arms' },
    pants = { kind = 'component', key = 'pants_1' },
    shoes = { kind = 'component', key = 'shoes_1' },
    undershirt = { kind = 'component', key = 'tshirt_1' },
    vest = { kind = 'component', key = 'bproof_1' },
    torso = { kind = 'component', key = 'torso_1' },
    jacket = { kind = 'component', key = 'torso_1' },
    bag = { kind = 'component', key = 'bags_1' },
    decals = { kind = 'component', key = 'decals_1' },
    hat = { kind = 'prop', key = 'helmet_1' },
    glass = { kind = 'prop', key = 'glasses_1' },
    glasses = { kind = 'prop', key = 'glasses_1' },
    ear = { kind = 'prop', key = 'ears_1' },
    earrings = { kind = 'prop', key = 'ears_1' },
    watch = { kind = 'prop', key = 'watches_1' },
    bracelet = { kind = 'prop', key = 'bracelets_1' }
}

local function offDataForAlias(alias)
    local m = wearAliasMap[tostring(alias or ''):lower()]
    if not m then return nil end
    if m.kind == 'component' then
        for _, c in ipairs(Config.Components or {}) do
            if c.key == m.key then return { kind = 'component', key = c.key, drawable = c.off and c.off.drawable or 0, texture = c.off and c.off.texture or 0 } end
        end
    else
        for _, p in ipairs(Config.Props or {}) do
            if p.key == m.key then return { kind = 'prop', key = p.key, drawable = p.off and p.off.drawable or -1, texture = p.off and p.off.texture or 0 } end
        end
    end
    return nil
end

RegisterNetEvent('realrpg_clothing:wearOnOff:client', function(alias)
    local data = offDataForAlias(alias)
    if not data then notify(('Ismeretlen ruhadarab: %s'):format(tostring(alias)), 'error') return end
    TriggerEvent('realrpg_clothing_designer:wearOnOff', data.kind, data)
end)

RegisterNetEvent('realrpg_clothing:openCharacterCreationMenu', function(skipReset, skipTeleport, cb)
    openDesigner({ characterCreation = true, skipReset = skipReset == true, skipTeleport = skipTeleport == true, menuType = 'character', categories = Config.CharacterCreationMenuCategories and Config.CharacterCreationMenuCategories.Normal })
    if cb then cb(true) end
end)

RegisterNetEvent('realrpg_clothing:openCharacterCreationMenuWithoutReset', function(cb)
    TriggerEvent('realrpg_clothing:openCharacterCreationMenu', true, true, cb)
end)

RegisterNetEvent('realrpg_clothing_designer:openPresetMenu', function(menuType, restricted)
    local preset = Config.MenuPresets and Config.MenuPresets[menuType or 'clothing'] or nil
    openDesigner({ previewType = preset and preset.previewType or 'hoodie', menuType = menuType or 'clothing', restricted = restricted == true, categories = preset and preset.categories or nil })
end)

RegisterNetEvent('realrpg_clothing:client:loadPlayerClothing', function(skin, ped)
    skin = skin or {}
    ped = ped or PlayerPedId()
    if ped == PlayerPedId() then
        applySkinToPlayer(skin, true)
    else
        importSkinToPed(ped, skin)
    end
end)

exports('openClothStore', function(storeType)
    TriggerEvent('realrpg_clothing_designer:openPresetMenu', storeType or 'clothing', false)
end)

exports('openCharacterCreationMenu', function(skipReset, skipTeleport, cb)
    TriggerEvent('realrpg_clothing:openCharacterCreationMenu', skipReset, skipTeleport, cb)
end)

exports('openCharacterCreationMenuWithoutReset', function(cb)
    TriggerEvent('realrpg_clothing:openCharacterCreationMenuWithoutReset', cb)
end)


RegisterCommand('rcd_troubleshoot', function()
    ESX.TriggerServerCallback('realrpg_clothing_designer:getTroubleshootingBundle', function(bundle)
        if not bundle or bundle.ok == false then
            notify((bundle and bundle.error) or 'Nem sikerült troubleshooting bundle-t lekérni.', 'error')
            return
        end
        notify(('Troubleshooting: worker=%s, AI=%s, saved=%s'):format((bundle.worker and bundle.worker.Mode) or 'n/a', (bundle.ai and bundle.ai.provider) or 'none', (bundle.savedDesigns and bundle.savedDesigns.Enabled) and 'on' or 'off'), 'info')
        print('[RCD Troubleshooting]', json.encode(bundle))
    end)
end, false)


-- V14: RealRPG-compatible public client event.
-- Server must grant access first via exports['realrpg_clothing_designer']:grantPlayerAccess(source)
RegisterNetEvent(rpcPublicOpenEvent, function(options)
    if Config.RPC and Config.RPC.enabled == false then
        openDesigner(options or { previewType = 'hoodie' })
        return
    end
    ESX.TriggerServerCallback('realrpg_clothing_designer:rpcHasAccess', function(hasAccess)
        if not hasAccess then notify('not_authorized', 'error') return end
        openDesigner(options or { previewType = 'hoodie' })
    end)
end)

RegisterNetEvent('realrpg_clothing_designer:notify', function(message, type)
    notify(message or 'Értesítés', type or 'inform')
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then TriggerServerEvent('realrpg_clothing_designer:server:uiClosed') end
end)
