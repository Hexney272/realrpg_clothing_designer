local ESX = exports['es_extended']:getSharedObject()

local uiOpen, screenshotOpen, cam, previewPed, previewObject = false, false, nil, nil, nil
local currentFov, currentFocus = Config.Focus[Config.Studio.defaultFocus].fov, Config.Studio.defaultFocus
local oldSkin, originalCoords, currentShopCoords = nil, nil, nil
local previewState = { skin = {}, components = {}, props = {}, canvas = {}, previewType = 'hoodie', mode = 'ped_preview' }

local function dbg(...)
    if Config.Debug then print('[realrpg_clothing_designer:v17.3]', ...) end
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
    local distance = tonumber(Config.Studio.spawnDistance) or 2.65
    return pcoords + forward * distance, GetEntityHeading(playerPed) + 180.0
end

local function createPreviewPed()
    local coords, heading = getSpawnCoords()
    local hash = loadModel(getPreviewPedModel())
    if not hash then
        dbg('Preview model could not be loaded:', getPreviewPedModel())
        return nil
    end

    -- Create ped at spawn position with proper ground offset
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, heading, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        dbg('CreatePed failed for preview model')
        return nil
    end

    -- Find ground level and place ped properly
    local groundZ = coords.z
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, false)
    if foundGround then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, groundZ + (tonumber(Config.Studio.previewGroundOffset) or 0.0), false, false, false)
    end
    
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityCollision(ped, true, true)
    SetEntityHeading(ped, heading)
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    SetEntityLodDist(ped, 1000)
    
    makeBaseMannequin(ped)
    
    -- Ensure ped is visible for preview
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    
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
    if not ent or not DoesEntityExist(ent) then return end
    mode = mode or currentFocus or Config.Studio.defaultFocus
    currentFocus = mode
    local cfg = Config.Focus[mode] or Config.Focus.full
    local off = cfg.offset

    -- GTA local Y points forward. The preview entity faces the camera, therefore
    -- this places the camera in front of the mannequin instead of behind it.
    local camCoords = GetOffsetFromEntityInWorldCoords(ent, off.x, off.y, off.z)
    local pointCoords = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, cfg.pointZ or 0.0)

    if not cam then cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetCamActive(cam, true)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(cam, pointCoords.x, pointCoords.y, pointCoords.z)
    SetCamNearClip(cam, 0.03)
    SetCamFarClip(cam, 250.0)
    currentFov = fovOverride or currentFov or cfg.fov
    currentFov = math.max(Config.Studio.minFov, math.min(Config.Studio.maxFov, currentFov))
    SetCamFov(cam, currentFov)
    SetFocusEntity(ent)
    RenderScriptCams(true, true, 250, true, true)
end

local function destroyCam()
    if cam then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
    ClearFocus()
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
    
    -- For clothing components (jbib, etc), always use ped preview
    -- Objects would require separate 3D model exports
    previewPed = createPreviewPed()
    if previewPed then
        previewState.mode = 'ped_preview'
        if previousSkin and previewPed then 
            importSkinToPed(previewPed, previousSkin) 
        end
        -- Make sure the preview ped is visible
        SetEntityVisible(previewPed, true, false)
        SetEntityAlpha(previewPed, 255, false)
    else
        previewState.mode = 'failed'
        return
    end
    
    currentFov = (Config.Focus[Config.Studio.defaultFocus] or Config.Focus.full).fov
    local data = Config.PreviewObjects[previewState.previewType]
    Wait(75)
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
    previewState = { skin = {}, components = {}, props = {}, canvas = {}, previewType = options.previewType or 'hoodie', mode = 'ped_preview' }
    getSkin(function(skin) oldSkin = skin end)
    if Config.Appearance.characterCreationTeleport and options.creation then
        SetEntityCoords(PlayerPedId(), Config.Appearance.characterCreationCoords.x, Config.Appearance.characterCreationCoords.y, Config.Appearance.characterCreationCoords.z)
        SetEntityHeading(PlayerPedId(), Config.Appearance.characterCreationCoords.w)
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
    destroyCam()
    deleteEntities()
    setPlayerPreviewState(false)
    SendNUIMessage({ action = 'hide' })
end

-- Keep the GTA preview readable at night and prevent the game HUD from bleeding
-- through the transparent NUI preview window. These natives run only while open.
CreateThread(function()
    while true do
        if uiOpen then
            if Config.Studio.hideHudDuringPreview ~= false then
                HideHudAndRadarThisFrame()
            end

            local ent = activeEntity()
            if ent and DoesEntityExist(ent) and Config.Studio.previewLighting ~= false then
                local coords = GetEntityCoords(ent)
                local forward = GetEntityForwardVector(ent)
                local frontDistance = tonumber(Config.Studio.previewLightFrontDistance) or 1.35
                local intensity = tonumber(Config.Studio.previewLightIntensity) or 3.2
                DrawLightWithRange(
                    coords.x + forward.x * frontDistance,
                    coords.y + forward.y * frontDistance,
                    coords.z + 1.25,
                    205, 220, 255, 5.0, intensity
                )
                DrawLightWithRange(
                    coords.x - forward.x * 0.55,
                    coords.y - forward.y * 0.55,
                    coords.z + 1.55,
                    139, 92, 246, 3.0, 1.65
                )
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

exports('openDesigner', openDesigner)
exports('openClothingDesigner', openDesigner)
exports('openScreenshotMenu', function() openDesigner({ screenshotMode = true }) end)
exports('openWardrobe', function() openDesigner({ previewType = 'hoodie', context = 'command' }); Wait(250); SendNUIMessage({ action = 'forceSection', section = 'Saved' }) end)
exports('openOrders', function() openDesigner({ previewType = 'hoodie', context = 'command' }); Wait(250); SendNUIMessage({ action = 'forceSection', section = 'Orders' }) end)

RegisterNetEvent('realrpg_clothing_designer:open', openDesigner)
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

RegisterNUICallback('setModel', function(data, cb)
    local model = data and data.model
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

RegisterNUICallback('adminLoadOrder', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:adminGetOrder', function(row)
        if not row or not row.metadata then cb({ ok = false }) return end
        local md = row.metadata
        if md.previewType then setupPreview(md.previewType, false) end
        if previewPed and md.skin then importSkinToPed(previewPed, md.skin) end
        previewState.skin = md.skin or {}
        previewState.components = md.components or {}
        previewState.props = md.props or {}
        previewState.canvas = md.canvas or {}
        cb({ ok = true, id = row.id, designId = row.design_id or md.designId, canvas = previewState.canvas, image = md.image, name = md.label, customTexture = md.customTexture })
    end, tonumber(data.id))
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


-- ox_inventory client item exports (current supported integration).
-- Add client.export entries from ox_items.lua to ox_inventory/data/items.lua.
local function canUseOwnedMetadata(metadata, cb)
    metadata = metadata or {}
    ESX.TriggerServerCallback('realrpg_clothing_designer:canUseOwnedItem', function(allowed)
        if not allowed then
            notify('Ez a ruhadarab más játékos tulajdona.', 'error')
            cb(false)
            return
        end
        cb(true)
    end, metadata.owner)
end

exports('useOutfit', function(data, slot)
    if GetResourceState(Config.Inventory.resource or 'ox_inventory') ~= 'started' then return end
    local metadata = (slot and slot.metadata) or (data and data.metadata) or {}
    canUseOwnedMetadata(metadata, function(allowed)
        if not allowed then return end
        exports[Config.Inventory.resource or 'ox_inventory']:useItem(data, function(used)
            if not used then return end
            TriggerEvent('realrpg_clothing_designer:applyMetadataOutfit', metadata)
        end)
    end)
end)

exports('useClothingPart', function(data, slot)
    if GetResourceState(Config.Inventory.resource or 'ox_inventory') ~= 'started' then return end
    local md = (slot and slot.metadata) or (data and data.metadata) or {}
    canUseOwnedMetadata(md, function(allowed)
        if not allowed then return end
        exports[Config.Inventory.resource or 'ox_inventory']:useItem(data, function(used)
            if not used then return end
            local skin = md.skin or md.components or {}
            for _, component in ipairs(Config.Components or {}) do
                if skin[component.key] ~= nil then
                    TriggerEvent('realrpg_clothing_designer:wearOnOff', 'component', {
                        key = component.key, id = component.id, drawable = skin[component.key], texture = skin[component.tex] or 0
                    })
                    return
                end
            end
            for _, prop in ipairs(Config.Props or {}) do
                if skin[prop.key] ~= nil then
                    TriggerEvent('realrpg_clothing_designer:wearOnOff', 'prop', {
                        key = prop.key, id = prop.id, drawable = skin[prop.key], texture = skin[prop.tex] or 0
                    })
                    return
                end
            end
        end)
    end)
end)

exports('useDesignToken', function(data, slot)
    if GetResourceState(Config.Inventory.resource or 'ox_inventory') ~= 'started' then return end
    exports[Config.Inventory.resource or 'ox_inventory']:useItem(data, function(used)
        if used then openDesigner({ previewType = 'hoodie', context = 'item', _authorized = true }) end
    end)
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
                    onSelect = function() currentShopCoords = shop.coords; openDesigner({ coords = shop.coords, context = 'shop' }) end
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
                if IsControlJustPressed(0, 38) then currentShopCoords = near.coords; openDesigner({ coords = near.coords, context = 'shop' }) end
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
    
    -- Cleanup runtime texture resources
    if runtimeDui then
        DestroyDui(runtimeDui)
        runtimeDui = nil
    end
    
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
    ESX.TriggerServerCallback('realrpg_clothing_designer:bridge:rescanTemplates', function(result)
        if not result or result.ok == false then
            notify((result and result.error) or 'Nem sikerült template scan-t futtatni.', 'error')
            return
        end
        local scan = result.rescan or result
        notify(('Template scan kész. Fájl: %s, YDD: %s, regisztrálva: %s'):format(
            scan.filesFound or 0, scan.yddTemplates or 0, scan.registered or 0
        ), 'success')
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
RegisterNetEvent('realrpg_clothing_designer:client:openClothingDesigner', function(options)
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


-- V15: true model texture editor bridge
local selectedTemplateModel = nil

local currentRuntimeTexture = { lastImage = nil, template = nil }

-- Runtime texture handling with DUI
local runtimeDui = nil
local runtimeTxd = nil
local runtimeTxn = 'realrpg_runtime_txn'

local function createRuntimeTexture(width, height)
    width = width or 1024
    height = height or 1024
    
    -- Create DUI object for runtime texture
    if runtimeDui then
        DestroyDui(runtimeDui)
    end
    
    runtimeDui = CreateDui('about:blank', width, height)
    
    -- Create runtime TXD if not exists
    if not runtimeTxd then
        runtimeTxd = CreateRuntimeTxd('realrpg_runtime_txd')
    end
    
    -- Get DUI texture handle
    local duiHandle = GetDuiHandle(runtimeDui)
    
    -- Create runtime texture from DUI
    local txdHandle = CreateRuntimeTextureFromDuiHandle(runtimeTxd, runtimeTxn, duiHandle)
    
    return txdHandle
end

local function applyRuntimeTextureToPreview(data)
    if not data or not data.image then return false end
    
    currentRuntimeTexture.lastImage = data.image
    currentRuntimeTexture.template = selectedTemplateModel or data.template
    
    -- Create or update runtime texture
    if not runtimeDui then
        createRuntimeTexture(data.width or 1024, data.height or 1024)
    end
    
    -- Update DUI with new image
    if runtimeDui then
        -- Convert base64 PNG to DUI displayable HTML
        local htmlContent = ('<html><body style="margin:0;padding:0;overflow:hidden;"><img src="%s" style="width:100%%;height:100%%;object-fit:fill;"></body></html>'):format(data.image)
        
        SetDuiUrl(runtimeDui, 'data:text/html;charset=utf-8,' .. htmlContent)
        
        -- Apply to preview ped if available
        if previewPed and DoesEntityExist(previewPed) and selectedTemplateModel then
            local componentId = tonumber(selectedTemplateModel.componentId) or 11
            local drawable = tonumber(selectedTemplateModel.drawable) or 0
            
            -- Replace ped drawable texture with runtime texture
            -- Note: This requires the component to be already set on the ped
            SetPedComponentVariation(previewPed, componentId, drawable, 0, 2)
            
            dbg('Applied runtime texture to component', componentId, drawable)
        end
    end
    
    SendNUIMessage({ action = 'liveTextureAccepted', template = data.template })
    return true
end

RegisterNUICallback('liveTextureUpdate', function(data, cb)
    cb({ ok = applyRuntimeTextureToPreview(data) })
end)

RegisterNUICallback('editorTool', function(data, cb)
    cb({ ok = true, tool = data and data.tool or 'select' })
end)

RegisterNUICallback('loadTemplateForPreview', function(data, cb)
    selectedTemplateModel = data or nil
    if data and data.preview_type then
        previewState.previewType = data.preview_type
    elseif data and data.category then
        local map = { jbib = 'jbib', uppr = 'tshirt', lowr = 'pants', feet = 'shoes', accs = 'cap', berd = 'cap', head = 'cap' }
        previewState.previewType = map[data.category] or previewState.previewType
    end
    if uiOpen then
        setupPreview(previewState.previewType, true)
        
        -- Apply the clothing component to the preview ped
        if previewPed and DoesEntityExist(previewPed) then
            local componentId = tonumber(data.componentId) or 11
            local drawable = tonumber(data.drawable) or 0
            local texture = tonumber(data.texture) or 0
            
            -- For jbib category, always use component 11 (torso)
            if data.category == 'jbib' then
                componentId = 11
            end
            
            -- Apply the component variation
            SetPedComponentVariation(previewPed, componentId, drawable, texture, 2)
            
            -- Make absolutely sure the ped is visible
            SetEntityVisible(previewPed, true, false)
            SetEntityAlpha(previewPed, 255, false)
            
            dbg('Applied component:', componentId, drawable, texture)
        end
        
        -- Ensure camera focuses on the correct area after loading template
        Wait(100)
        local previewData = Config.PreviewObjects[previewState.previewType]
        if previewData and previewData.focus then
            focusCamera(previewData.focus)
        else
            focusCamera('torso')
        end
    end
    cb({ ok = true })
end)

RegisterNUICallback('rescanTemplates', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:bridge:rescanTemplates', function(result)
        cb(result or { ok = false, catalog = {} })
    end)
end)

RegisterNUICallback('exportCurrentAddon', function(data, cb)
    ESX.TriggerServerCallback('realrpg_clothing_designer:exportCurrentAddon', function(result)
        cb(result or { ok = false })
    end, data)
end)
