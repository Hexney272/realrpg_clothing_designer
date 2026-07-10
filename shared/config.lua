Config = {}

Config.Debug = false
Config.Version = '17.3.0'
Config.Locale = 'hu'
Config.Framework = 'esx' -- esx / qb-ready placeholder
Config.Command = 'clothingdesigner'
Config.ScreenshotMenuCommand = 'screenshotmenu'
Config.WardrobeCommand = 'clothingwardrobe'
Config.AdminCommand = 'clothingadmin'
Config.OrdersCommand = 'clothingorders'
Config.TemplateCommand = 'clothingtemplates'
Config.GiveClothingMenuCommand = 'giveclothingmenu'
Config.GiveRestrictedClothingMenuCommand = 'giverestrictedclothingmenu'
Config.AdminPermission = 'realrpg.clothingdesigner.admin'
Config.ResourceNameCompat = 'realrpg_clothing_designer' -- docs-parity name used in troubleshooting examples


Config.RPC = {
    enabled = true,
    requireAuthorization = true,
    publicOpenEvent = 'realrpg_clothing_designer:client:openClothingDesigner',
    realrpgOpenEvent = 'realrpg_clothing_designer:open',
    revokeOnClose = false,
    debugDeniedCalls = true
}

Config.AdminCommandsRealRPG = {
    enabled = true,
    open = 'clothingdesigner',
    stats = 'clothingdesignerstats',
    rescan = 'clothingdesignerrescan',
    restrictedOpen = 'giverestrictedclothingmenu'
}


Config.ModelEditor = {
    enabled = true,
    layout = 'preview_left_uv_center_inspector_right',
    liveTexturePreview = true,
    useDuiRuntimeTexture = true,
    textureUpdateDebounce = 120,
    defaultTextureSize = 1024,
    tools = { 'select', 'move', 'brush', 'eraser', 'image', 'text', 'fill', 'pipette', 'ai' },
    panels = { layers = true, templates = true, saved = true, slots = true },
    textureReplacement = {
        enabled = true,
        runtimeTxd = 'realrpg_runtime_cloth_txd',
        runtimeTxn = 'realrpg_runtime_cloth_txn',
        originalTxdFallback = 'realrpg_template',
        originalTxnFallback = 'texture'
    }
}



-- V16: exact clothing template files you already sent.
-- These are GTA freemode clothing component assets. Put them here:
-- templates/cloth_templates/male/jbib/<file>.ydd
-- templates/cloth_templates/male/jbib/<file>.ytd
Config.KnownClothingModels = {
    {
        key = 'male_jbib_jbib_000',
        label = 'Male Jbib 000',
        gender = 'male', component = 'jbib', previewType = 'jbib', componentId = 11,
        drawable = 0, texture = 0,
        ydd = 'jbib_000_u.ydd', ytd = 'jbib_diff_000_a_uni.ytd',
        prefixedYdd = 'mp_m_freemode_01^jbib_000_u.ydd', prefixedYtd = 'mp_m_freemode_01^jbib_diff_000_a_uni.ytd',
        txd = 'mp_m_freemode_01^jbib_diff_000_a_uni', txn = 'jbib_diff_000_a_uni'
    },
    {
        key = 'male_jbib_jbib_005',
        label = 'Male Jbib 005',
        gender = 'male', component = 'jbib', previewType = 'jbib', componentId = 11,
        drawable = 5, texture = 0,
        ydd = 'jbib_005_u.ydd', ytd = 'jbib_diff_005_a_uni.ytd',
        prefixedYdd = 'mp_m_freemode_01^jbib_005_u.ydd', prefixedYtd = 'mp_m_freemode_01^jbib_diff_005_a_uni.ytd',
        txd = 'mp_m_freemode_01^jbib_diff_005_a_uni', txn = 'jbib_diff_005_a_uni'
    },
    {
        key = 'male_jbib_jbib_007',
        label = 'Male Jbib 007',
        gender = 'male', component = 'jbib', previewType = 'jbib', componentId = 11,
        drawable = 7, texture = 0,
        ydd = 'jbib_007_u.ydd', ytd = 'jbib_diff_007_a_uni.ytd',
        prefixedYdd = 'mp_m_freemode_01^jbib_007_u.ydd', prefixedYtd = 'mp_m_freemode_01^jbib_diff_007_a_uni.ytd',
        txd = 'mp_m_freemode_01^jbib_diff_007_a_uni', txn = 'jbib_diff_007_a_uni'
    },
    {
        key = 'male_jbib_jbib_013',
        label = 'Male Jbib 013',
        gender = 'male', component = 'jbib', previewType = 'jbib', componentId = 11,
        drawable = 13, texture = 0,
        ydd = 'jbib_013_u.ydd', ytd = 'jbib_diff_013_a_uni.ytd',
        prefixedYdd = 'mp_m_freemode_01^jbib_013_u.ydd', prefixedYtd = 'mp_m_freemode_01^jbib_diff_013_a_uni.ytd',
        txd = 'mp_m_freemode_01^jbib_diff_013_a_uni', txn = 'jbib_diff_013_a_uni'
    }
}

Config.Target = {
    enabled = true,
    resource = 'ox_target',
    useTextUIFallback = true,
    textUIDistance = 2.2
}

Config.Database = {
    autoInstall = true
}

Config.StorageLimits = {
    maxCanvasJson = 18000000,
    maxImageData = 15000000,
    maxLayers = 80
}

-- V12: troubleshooting/docs parity settings. These are safe checks/helpers for our own RealRPG script.
Config.Worker = {
    Enabled = true,
    Mode = 'resource',
    Resource = 'realrpg_clothing_worker',
    Port = 33442,
    ExpectedLogs = true
}

Config.Permissions = {
    RequireUnsafeChildProcess = false, -- true only if Worker.Mode = external and your host allows it
    UnsafeChildProcessLine = 'add_unsafe_child_process_permission realrpg_clothing_worker',
    RequireFilesystemExportPermission = true,
    FilesystemPermissionLine = 'add_filesystem_permission realrpg_clothing_worker write realrpg_clothing_designer'
}

Config.Authorization = {
    Enabled = true,
    RequireGrantForExternalOpen = true,
    AllowCommandOpen = true,
    GrantTimeoutMinutes = 30,
    NotAuthorizedMessage = 'not_authorized'
}

Config.SavedDesigns = {
    Enabled = true,
    RemoteStorageProvider = 'database', -- database / custom
    RequireProviderConfig = false
}

Config.AI = {
    Enabled = false,
    Provider = 'none', -- openai / custom / none
    ApiKey = '',
    Model = '',
    QuotaHint = 'AI generation requires provider quota, billing and model access.'
}

Config.Interaction = {
    TextUI = {
        Enable = true,
        Show = function(label)
            if lib and lib.showTextUI then lib.showTextUI(label) end
        end,
        Hide = function()
            if lib and lib.hideTextUI then lib.hideTextUI() end
        end
    },
    Target = {
        Enable = true,
        Icon = 'fa-solid fa-shirt'
    }
}

Config.Inventory = {
    enabled = true,
    resource = 'ox_inventory',
    outfitItem = 'realrpg_outfit',
    clothingPartItem = 'realrpg_clothing_part',
    designItem = 'realrpg_clothing_design',
    enforceOwner = true -- az item csak a metadata.owner tulajdonosa vagy admin által használható
}

Config.Appearance = {
    -- Primary: esx_skin. Other adapters are included as safe wrappers, not full replacements for paid appearance scripts.
    system = 'esx_skin', -- esx_skin / fivem-appearance / illenium-appearance / qb-clothing / custom
    saveOnApply = true,
    restoreOnCancel = true,
    stopOtherAppearanceScripts = false, -- RealRPG safety: false by default; enable only if you want RealRPG-like aggressive stop behavior.
    characterCreationTeleport = false,
    characterCreationCoords = vec4(-1042.70, -2745.88, 21.36, 330.0),
    listModelsByGender = true
}

-- V12: docs-based compatibility options inspired by documented RealRPG Clothing V2 config names/flow.
Config.ShowAllPeds = false
Config.AllowedModels = { 'mp_m_freemode_01', 'mp_f_freemode_01' }

Config.SetCoordsAfterFinalize = {
    Enable = false,
    Coords = vec4(-1038.10, -2738.23, 20.17, 325.03)
}

Config.TeleportWhenCreatingChar = {
    Enable = false,
    Coords = vec4(-1038.10, -2738.23, 20.17, 325.03)
}

Config.CharacterFinalized = function(source)
    -- Add RealRPG custom logic here after character creation is finished.
end

Config.GiveClothingMenu = {
    Enable = true,
    Command = Config.GiveClothingMenuCommand or 'giveclothingmenu',
    RestrictedCommand = Config.GiveRestrictedClothingMenuCommand or 'giverestrictedclothingmenu',
    Description = 'Give advanced RealRPG clothing menu',
    RestrictedDescription = 'Give restricted RealRPG clothing menu',
    Group = 'admin'
}

Config.CharacterCreationMenuCategories = {
    Normal = {
        Peds = false,
        Face = true,
        FaceFeatures = true,
        Skin = true,
        Hair = true,
        Makeup = true,
        Clothing = true,
        Accessories = true,
        Body = true,
        Studio = true
    },
    Restricted = {
        Peds = false,
        Face = false,
        FaceFeatures = false,
        Skin = true,
        Hair = true,
        Makeup = false,
        Clothing = true,
        Accessories = true,
        Body = false,
        Studio = false
    }
}

Config.DefaultClothingVariations = {
    Hat = { male = -1, female = -1 },
    Masks = { male = -1, female = -1 },
    Glasses = { male = -1, female = -1 },
    Jacket = { male = 15, female = 15 },
    Bag = { male = -1, female = -1 },
    Hairs = { male = 0, female = 0 },
    Shoes = { male = 34, female = 34 },
    Pants = { male = 14, female = 14 },
    Undershirt = { male = 15, female = 15 },
    Vest = { male = 0, female = 0 },
    Decals = { male = 0, female = 0 },
    Arms = { male = 15, female = 15 }
}

Config.ClothPrices = {
    Jacket = { Default = 150, Customs = { [255] = 500, [230] = 500 } },
    Hat = { Default = 75 },
    Hairs = { Default = 95 },
    FacialHairs = { Default = 95 },
    ChestHair = { Default = 95 },
    Makeup = { Default = 75 },
    Blush = { Default = 75 },
    Lipstick = { Default = 75 },
    Eyebrows = { Default = 75 },
    Pants = { Default = 130 },
    Masks = { Default = 90 },
    Earrings = { Default = 50 },
    Glasses = { Default = 65 },
    Decals = { Default = 45 },
    Undershirt = { Default = 140 },
    Watches = { Default = 100 },
    Bags = { Default = 90 },
    ['Scarfs/Necklaces'] = { Default = 80 },
    ['Arms/Gloves'] = { Default = 70 },
    Shoes = { Default = 135, Customs = { [50] = 300, [75] = 400 } },
    Bracelets = { Default = 80 },
    Vest = { Default = 160 }
}

Config.MenuPresets = {
    clothing = { label = 'Clothing Store', categories = Config.CharacterCreationMenuCategories.Normal, previewType = 'hoodie' },
    barber = { label = 'Barber Store', categories = { Hair = true, Makeup = true, Face = true, FaceFeatures = true }, previewType = 'cap' },
    tattoo = { label = 'Tattoo Store', categories = { Body = true, Clothing = false, Accessories = false }, previewType = 'tshirt' },
    restricted = { label = 'Restricted Clothing Menu', categories = Config.CharacterCreationMenuCategories.Restricted, previewType = 'hoodie' }
}

Config.RealCoin = {
    enabled = true,
    mode = 'account', -- account / item / export / cash
    account = 'realcoin',
    item = 'realcoin',
    label = 'RC',
    exportResource = 'realrpg_rc',
    exportFunction = 'RemoveRC'
}

Config.Price = {
    SaveDesign = 250,
    ApplyDesign = 0,
    OrderOutfitItem = 500,
    OrderPartItem = 300,
    CustomDesignFee = 150,
    CaptureImage = 0,
    DuplicateDesign = 100,
    RenameDesign = 0
}

Config.Flow = {
    enableOrderStatus = true,
    defaultOrderStatus = 'pending', -- ready / pending. V12: pending = admin approval required
    allowDeleteDesign = true,
    allowRenameDesign = true,
    allowDuplicateDesign = true,
    loadSavedOnOpen = true,
    requireShopDistanceForOrder = false,
    allowPublicDesigns = true,
    allowFavoriteDesigns = true,
    allowWardrobeSearch = true,
    maxWardrobeItems = 120
}

Config.Orders = {
    enabled = true,
    requireAdminApproval = true,
    giveItemOnApprove = true,
    allowPlayerCancelPending = true,
    refundOnReject = false, -- Real Coin refund export/account is server-specific; keep false unless you wire addPayment back.
    statuses = { pending = 'Függőben', approved = 'Jóváhagyva', rejected = 'Elutasítva', ready = 'Elkészült', cancelled = 'Lemondva' }
}

Config.Admin = {
    enabled = true,
    maxList = 150,
    allowOpenForPlayers = true,
    allowGiveDesignItem = true
}

Config.V8 = {
    cleanupOnResourceStop = true,
    enableDiagnosticsCommand = true,
    optimizedControlLoop = true,
    strictPreviewFallback = true,
    uiPolish = true
}



Config.TemplateFlow = {
    enabled = true,
    -- V12 docs-parity folder rules:
    -- templates/cloth_templates/<male|female>/<component>/<component>_000_u.ydd
    autoScanTemplatesOnStart = true,
    createMissingWorkspaceDirectories = true,
    generateMissingPreviews = true,
    updateChangedManagedPreviews = true,
    cleanTemporaryPreviewCache = true,
    addonFirstExport = true,
    replaceExportEnabled = false, -- docs szerint a shipped UI-ban nincs replace export

    templateRoot = 'templates/cloth_templates',
    previewRoot = 'templates/template_previews',
    slotRoot = 'templates/template_slots',
    exportRoot = 'exports',
    mirrorExportRoot = '../realrpg_clothing_exports', -- docs szerinti mirror resource output hely
    workspaceRoot = 'data/workspace',
    tempPreviewCache = 'data/workspace/preview_cache',
    generatedPreviewExtension = 'png',

    genders = { male = true, female = true },
    supportedComponents = {
        accs = true, berd = true, decl = true, feet = true, hair = true, hand = true,
        head = true, jbib = true, lowr = true, task = true, teef = true, uppr = true
    },
    componentLabels = {
        accs = 'Accessories', berd = 'Beard', decl = 'Decals', feet = 'Shoes', hair = 'Hair',
        hand = 'Hands', head = 'Head', jbib = 'Jacket / Upper Body', lowr = 'Lower Body',
        task = 'Task / Bags', teef = 'Teeth', uppr = 'Upper'
    },
    componentToPreviewType = {
        accs = 'cap', berd = 'cap', decl = 'tshirt', feet = 'shoes', hair = 'cap', hand = 'hoodie',
        head = 'cap', jbib = 'hoodie', lowr = 'pants', task = 'hoodie', teef = 'cap', uppr = 'tshirt'
    },
    componentToSkinKey = {
        accs = 'chain_1', berd = 'beard_1', decl = 'decals_1', feet = 'shoes_1', hair = 'hair_1',
        hand = 'arms', head = 'mask_1', jbib = 'torso_1', lowr = 'pants_1', task = 'bags_1',
        teef = 'teeth_1', uppr = 'tshirt_1'
    },
    previewExtensions = { 'png', 'webp', 'jpg', 'jpeg' },
    templateExtensions = { ydd = true, ytd = true },
    slotExtensions = { ytd = true }
}

Config.ImageGenerator = {
    enabled = true,
    resource = 'screenshot-basic',
    uploadUrl = '', -- Discord webhook / upload endpoint. Empty = requestScreenshot base64 only.
    defaultEncoding = 'jpg',
    quality = 0.92,
    imageSize = { width = 768, height = 768 },
    useDefaultClothImages = {
        Skin = true,
        Hair = true,
        Makeup = true,
        Clothing = true,
        Accessories = true,
        Body = true
    }
}

Config.Studio = {
    hidePlayer = true,
    freezePlayer = true,
    spawnDistance = 2.65,
    backgroundBlur = true,
    defaultModel = 'mp_m_freemode_01',
    femaleModel = 'mp_f_freemode_01',
    defaultFocus = 'full',
    rotationSpeed = 8.0,
    zoomStep = 2.5,
    minFov = 16.0,
    maxFov = 48.0,
    maxDistanceFromShop = 30.0,
    idleAnim = { dict = 'anim@heists@heist_corona@team_idles@male_a', name = 'idle' },
    previewGroundOffset = 0.0,
    previewLighting = true,
    previewLightFrontDistance = 1.35,
    previewLightIntensity = 3.2,
    hideHudDuringPreview = true
}

-- Separated preview objects. If these models are streamed, V12 uses them as true object preview.
-- Without them, FiveM can only preview GTA clothing through a mannequin ped because clothing is ped-component based.
Config.PreviewObjects = {
    hoodie = { label = 'Hoodie', model = 'realrpg_preview_hoodie', component = 'torso', fallback = 'ped', focus = 'torso' },
    tshirt = { label = 'T-shirt', model = 'realrpg_preview_tshirt', component = 'torso', fallback = 'ped', focus = 'torso' },
    pants = { label = 'Pants', model = 'realrpg_preview_pants', component = 'pants', fallback = 'ped', focus = 'legs' },
    shoes = { label = 'Shoes', model = 'realrpg_preview_shoes', component = 'shoes', fallback = 'ped', focus = 'feet' },
    cap = { label = 'Cap', model = 'realrpg_preview_cap', component = 'hat', fallback = 'ped', focus = 'head' },
    jbib = { label = 'Jbib / Top', model = 'realrpg_preview_jbib', component = 'jbib', fallback = 'componentPed', focus = 'torso' }
}

Config.PlayerModels = {
    male = {
        { label = 'Freemode Male', model = 'mp_m_freemode_01' }
    },
    female = {
        { label = 'Freemode Female', model = 'mp_f_freemode_01' }
    }
}

Config.Shops = {
    {
        label = 'RealRPG Clothing Designer',
        type = 'designer',
        coords = vec3(72.28, -1399.10, 29.38),
        size = vec3(1.35, 1.35, 2.0),
        rotation = 0.0,
        blip = true
    }
}

Config.Focus = {
    full  = { offset = vec3(0.0, 3.10, 1.02), pointZ = 0.00, fov = 34.0 },
    head  = { offset = vec3(0.0, 1.80, 1.64), pointZ = 0.74, fov = 26.0 },
    torso = { offset = vec3(0.0, 2.02, 1.10), pointZ = 0.22, fov = 23.0 },
    legs  = { offset = vec3(0.0, 2.15, 0.56), pointZ = -0.35, fov = 28.0 },
    feet  = { offset = vec3(0.0, 1.56, 0.26), pointZ = -0.82, fov = 24.0 },
    hands = { offset = vec3(0.0, 1.78, 0.94), pointZ = 0.02, fov = 27.0 }
}

Config.Categories = {
    { key = 'Skin', label = 'Karakter', type = 'model', icon = 'user', enabled = true },
    { key = 'Clothing', label = 'Ruházat', type = 'component', icon = 'shirt', enabled = true },
    { key = 'Accessories', label = 'Kiegészítők', type = 'prop', icon = 'glasses', enabled = true },
    { key = 'Body', label = 'Test', type = 'body', icon = 'body', enabled = true },
    { key = 'Studio', label = 'Designer', type = 'canvas', icon = 'pen', enabled = true },
    { key = 'Saved', label = 'Ruhatár', type = 'saved', icon = 'save', enabled = true },
    { key = 'Orders', label = 'Rendelések', type = 'orders', icon = 'receipt', enabled = true }
}

Config.Components = {
    { id = 1, key = 'mask_1', tex = 'mask_2', label = 'Maszk', focus = 'head', off = { drawable = 0, texture = 0 } },
    { id = 3, key = 'arms', tex = 'arms_2', label = 'Karok', focus = 'torso', off = { drawable = 15, texture = 0 } },
    { id = 4, key = 'pants_1', tex = 'pants_2', label = 'Nadrág', focus = 'legs', off = { drawable = 14, texture = 0 } },
    { id = 5, key = 'bags_1', tex = 'bags_2', label = 'Táska', focus = 'torso', off = { drawable = 0, texture = 0 } },
    { id = 6, key = 'shoes_1', tex = 'shoes_2', label = 'Cipő', focus = 'feet', off = { drawable = 1, texture = 0 } },
    { id = 7, key = 'chain_1', tex = 'chain_2', label = 'Nyaklánc', focus = 'head', off = { drawable = 0, texture = 0 } },
    { id = 8, key = 'tshirt_1', tex = 'tshirt_2', label = 'Alsó felső', focus = 'torso', off = { drawable = 15, texture = 0 } },
    { id = 9, key = 'bproof_1', tex = 'bproof_2', label = 'Mellény', focus = 'torso', off = { drawable = 0, texture = 0 } },
    { id = 10, key = 'decals_1', tex = 'decals_2', label = 'Decal / Minta', focus = 'torso', off = { drawable = 0, texture = 0 } },
    { id = 11, key = 'torso_1', tex = 'torso_2', label = 'Felső / Kabát', focus = 'torso', off = { drawable = 15, texture = 0 } }
}

Config.Props = {
    { id = 0, key = 'helmet_1', tex = 'helmet_2', label = 'Sapka / Kalap', focus = 'head', off = { drawable = -1, texture = 0 } },
    { id = 1, key = 'glasses_1', tex = 'glasses_2', label = 'Szemüveg', focus = 'head', off = { drawable = -1, texture = 0 } },
    { id = 2, key = 'ears_1', tex = 'ears_2', label = 'Fül kiegészítő', focus = 'head', off = { drawable = -1, texture = 0 } },
    { id = 6, key = 'watches_1', tex = 'watches_2', label = 'Óra', focus = 'hands', off = { drawable = -1, texture = 0 } },
    { id = 7, key = 'bracelets_1', tex = 'bracelets_2', label = 'Karkötő', focus = 'hands', off = { drawable = -1, texture = 0 } }
}

Config.Presets = {
    {
        name = 'RealRPG Premium Hoodie', tag = 'premium', price = 350, preview = 'hoodie',
        components = { torso_1 = 15, torso_2 = 0, tshirt_1 = 15, tshirt_2 = 0, arms = 1, arms_2 = 0, pants_1 = 4, pants_2 = 0, shoes_1 = 1, shoes_2 = 0 }
    },
    {
        name = 'RealRPG Civil Outfit', tag = 'civil', price = 150, preview = 'tshirt',
        components = { torso_1 = 7, torso_2 = 1, tshirt_1 = 15, tshirt_2 = 0, arms = 0, arms_2 = 0, pants_1 = 10, pants_2 = 0, shoes_1 = 7, shoes_2 = 0 }
    },
    {
        name = 'RealRPG Street Pants', tag = 'street', price = 180, preview = 'pants',
        components = { pants_1 = 7, pants_2 = 0, shoes_1 = 6, shoes_2 = 0 }
    }
}

Config.Translations = {
    ['not_enough_money'] = 'Nincs elég %s.',
    ['saved'] = 'Dizájn sikeresen elmentve.',
    ['item_created'] = 'Ruházati item elkészítve.',
    ['cancelled'] = 'Módosítások elvetve.',
    ['applied'] = 'Ruha alkalmazva.',
    ['renamed'] = 'Dizájn átnevezve.',
    ['deleted'] = 'Dizájn törölve.',
    ['duplicated'] = 'Dizájn másolva.',
    ['order_created'] = 'Rendelés létrehozva.',
    ['order_cancelled'] = 'Rendelés lemondva.',
    ['order_approved'] = 'Rendelés jóváhagyva.',
    ['order_rejected'] = 'Rendelés elutasítva.',
    ['admin_only'] = 'Ehhez nincs jogosultságod.',
    ['template_scan_done'] = 'Template scan kész.',
    ['template_saved'] = 'Template elmentve.',
    ['template_deleted'] = 'Template törölve.',
    ['template_exported'] = 'Template exportálva.',
    ['menu_given'] = 'Clothing menü megnyitva a játékosnak.',
    ['invalid_target'] = 'Hibás játékos ID.',
    ['not_allowed_model'] = 'Ez a ped modell nem használhatja ezt a menüt.'
}

