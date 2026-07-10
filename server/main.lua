local ESX = exports['es_extended']:getSharedObject()

local function dbg(...)
    if Config.Debug then print('[realrpg_clothing_designer:v17]', ...) end
end

local function identifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function safeJsonDecode(value)
    if not value or value == '' then return {} end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded then return decoded end
    return {}
end

local function normalizePlayerDesignPayload(data)
    data = type(data) == 'table' and data or {}
    local limits = Config.StorageLimits or {}
    local canvas = type(data.canvas) == 'table' and data.canvas or {}
    local layers = canvas.layers

    if layers ~= nil and type(layers) ~= 'table' then
        return nil, 'Hibás réteglista.'
    end
    if type(layers) == 'table' and #layers > (tonumber(limits.maxLayers) or 80) then
        return nil, 'Túl sok réteg van a tervben.'
    end

    local image = data.image and tostring(data.image) or nil
    if image and #image > (tonumber(limits.maxImageData) or 15000000) then
        return nil, 'A preview kép túl nagy.'
    end

    local encodedOk, encodedCanvas = pcall(json.encode, canvas)
    if not encodedOk then return nil, 'A canvas nem menthető.' end
    if #encodedCanvas > (tonumber(limits.maxCanvasJson) or 18000000) then
        return nil, 'A canvas adata túl nagy.'
    end

    if canvas.template ~= nil then
        local templateId = tonumber(type(canvas.template) == 'table' and canvas.template.id or nil)
        if not templateId then return nil, 'Érvénytelen ruhasablon.' end

        local row = MySQL.single.await('SELECT * FROM realrpg_clothing_templates WHERE id = ? AND active = 1 LIMIT 1', { templateId })
        if not row then return nil, 'A kiválasztott ruhasablon nem található.' end

        local meta = safeJsonDecode(row.meta)
        local ytdPath = meta.ytdPath or meta.texturePath
        local yddPath = row.template_path or meta.templatePath
        local ytdFile = tostring(ytdPath or ''):gsub('\\', '/'):match('([^/]+)$') or ''
        local txdName = ytdFile:gsub('%.ytd$', '')

        canvas.template = {
            id = row.id,
            name = row.name,
            fileName = row.file_name,
            fileType = row.file_type,
            gender = row.gender,
            component = row.component_key or row.category,
            category = row.category,
            drawable = tonumber(row.drawable) or 0,
            texture = tonumber(row.texture) or 0,
            templatePath = yddPath,
            yddPath = yddPath,
            ytdPath = ytdPath,
            texturePath = ytdPath,
            textureName = row.texture_name,
            originalTxn = row.texture_name,
            txdName = txdName
        }
    end

    data.canvas = canvas
    data.image = image
    return data
end


local grantedAccess = {}

local function now()
    return os.time()
end

local function hasGrantedAccess(src)
    if not (Config.Authorization and Config.Authorization.Enabled) then return true end
    if Config.Authorization.AllowCommandOpen and IsPlayerAceAllowed(src, Config.AdminPermission) then return true end
    local expires = grantedAccess[tonumber(src)]
    return expires and expires > now()
end

local function grantAccess(src, minutes)
    src = tonumber(src)
    if not src then return false end
    local ttl = tonumber(minutes) or (Config.Authorization and Config.Authorization.GrantTimeoutMinutes) or 30
    grantedAccess[src] = now() + (ttl * 60)
    return true
end

local function revokeAccess(src)
    grantedAccess[tonumber(src)] = nil
end

local function takePayment(src, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local rc = Config.RealCoin
    if not rc.enabled or rc.mode == 'cash' then
        if xPlayer.getMoney() >= amount then xPlayer.removeMoney(amount); return true end
        return false
    end
    if rc.mode == 'account' then
        local acc = xPlayer.getAccount(rc.account)
        if acc and acc.money >= amount then xPlayer.removeAccountMoney(rc.account, amount); return true end
        return false
    end
    if rc.mode == 'item' then
        local item = xPlayer.getInventoryItem(rc.item)
        if item and item.count >= amount then xPlayer.removeInventoryItem(rc.item, amount); return true end
        return false
    end
    if rc.mode == 'export' and rc.exportResource and rc.exportFunction and GetResourceState(rc.exportResource) == 'started' then
        return exports[rc.exportResource][rc.exportFunction](src, amount) == true
    end
    return false
end

local function givePayment(src, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local rc = Config.RealCoin
    if not rc.enabled or rc.mode == 'cash' then xPlayer.addMoney(amount); return true end
    if rc.mode == 'account' then xPlayer.addAccountMoney(rc.account, amount); return true end
    if rc.mode == 'item' then xPlayer.addInventoryItem(rc.item, amount); return true end
    return false
end

local function installDatabase()
    if not Config.Database.autoInstall then return end
    local queries = {
        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_designs` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `identifier` varchar(80) NOT NULL,
          `name` varchar(80) NOT NULL DEFAULT 'RealRPG Design',
          `gender` varchar(20) NOT NULL DEFAULT 'unknown',
          `preview_type` varchar(40) NOT NULL DEFAULT 'hoodie',
          `skin` longtext DEFAULT NULL,
          `components` longtext DEFAULT NULL,
          `props` longtext DEFAULT NULL,
          `canvas` longtext DEFAULT NULL,
          `image` mediumtext DEFAULT NULL,
          `is_public` tinyint(1) NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          PRIMARY KEY (`id`),
          KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]],
        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_orders` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `identifier` varchar(80) NOT NULL,
          `design_id` int(11) DEFAULT NULL,
          `name` varchar(80) NOT NULL DEFAULT 'RealRPG Outfit',
          `type` varchar(30) NOT NULL DEFAULT 'outfit',
          `metadata` longtext DEFAULT NULL,
          `status` varchar(30) NOT NULL DEFAULT 'pending',
          `price` int(11) NOT NULL DEFAULT 0,
          `reviewed_by` varchar(80) DEFAULT NULL,
          `reviewed_at` datetime DEFAULT NULL,
          `note` varchar(255) DEFAULT NULL,
          `item_delivered` tinyint(1) NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          PRIMARY KEY (`id`),
          KEY `identifier` (`identifier`),
          KEY `design_id` (`design_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]],
        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_captures` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `identifier` varchar(80) NOT NULL,
          `name` varchar(80) NOT NULL DEFAULT 'capture',
          `category` varchar(50) DEFAULT NULL,
          `drawable` int(11) DEFAULT NULL,
          `texture` int(11) DEFAULT NULL,
          `result` mediumtext DEFAULT NULL,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          PRIMARY KEY (`id`),
          KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]],
        [[CREATE TABLE IF NOT EXISTS `realrpg_clothing_templates` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `name` varchar(120) NOT NULL DEFAULT 'template',
          `file_name` varchar(180) NOT NULL,
          `file_type` varchar(10) NOT NULL DEFAULT 'ydd',
          `category` varchar(50) NOT NULL DEFAULT 'other',
          `gender` varchar(20) NOT NULL DEFAULT 'unisex',
          `preview_type` varchar(40) NOT NULL DEFAULT 'hoodie',
          `component_key` varchar(60) DEFAULT NULL,
          `model_name` varchar(120) DEFAULT NULL,
          `texture_name` varchar(120) DEFAULT NULL,
          `drawable` int(11) NOT NULL DEFAULT 0,
          `texture` int(11) NOT NULL DEFAULT 0,
          `image` mediumtext DEFAULT NULL,
          `meta` longtext DEFAULT NULL,
          `active` tinyint(1) NOT NULL DEFAULT 1,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `template_identity` (`gender`,`category`,`file_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]]
    }
    for _, q in ipairs(queries) do MySQL.query.await(q) end
    MySQL.query.await('ALTER TABLE realrpg_clothing_designs ADD COLUMN IF NOT EXISTS is_public tinyint(1) NOT NULL DEFAULT 0')
    MySQL.query.await("ALTER TABLE realrpg_clothing_orders ADD COLUMN IF NOT EXISTS status varchar(30) NOT NULL DEFAULT 'pending'")
    MySQL.query.await('ALTER TABLE realrpg_clothing_orders ADD COLUMN IF NOT EXISTS price int(11) NOT NULL DEFAULT 0')
    MySQL.query.await('ALTER TABLE realrpg_clothing_orders ADD COLUMN IF NOT EXISTS reviewed_by varchar(80) DEFAULT NULL')
    MySQL.query.await('ALTER TABLE realrpg_clothing_orders ADD COLUMN IF NOT EXISTS reviewed_at datetime DEFAULT NULL')
    MySQL.query.await('ALTER TABLE realrpg_clothing_orders ADD COLUMN IF NOT EXISTS note varchar(255) DEFAULT NULL')
    MySQL.query.await('ALTER TABLE realrpg_clothing_orders ADD COLUMN IF NOT EXISTS item_delivered tinyint(1) NOT NULL DEFAULT 0')
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `realrpg_clothing_access` (`identifier` varchar(80) NOT NULL, `expires_at` int(11) NOT NULL DEFAULT 0, `granted_by` varchar(80) DEFAULT NULL, `created_at` timestamp NOT NULL DEFAULT current_timestamp(), PRIMARY KEY (`identifier`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;]])
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS file_type varchar(10) NOT NULL DEFAULT 'ydd'")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS category varchar(50) NOT NULL DEFAULT 'other'")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS gender varchar(20) NOT NULL DEFAULT 'unisex'")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS preview_type varchar(40) NOT NULL DEFAULT 'hoodie'")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS component_key varchar(60) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS model_name varchar(120) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS texture_name varchar(120) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS drawable int(11) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS texture int(11) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS image mediumtext DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS meta longtext DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS active tinyint(1) NOT NULL DEFAULT 1")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS updated_at datetime DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS template_key varchar(180) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS template_path varchar(255) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS preview_path varchar(255) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS slot_path varchar(255) DEFAULT NULL")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS managed_preview tinyint(1) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE realrpg_clothing_templates ADD COLUMN IF NOT EXISTS skipped_reason varchar(255) DEFAULT NULL")
    MySQL.query.await('ALTER TABLE realrpg_clothing_templates DROP INDEX IF EXISTS `file_name`')
    MySQL.query.await('ALTER TABLE realrpg_clothing_templates ADD UNIQUE INDEX IF NOT EXISTS `template_identity` (`gender`,`category`,`file_name`)')
    dbg('Database auto install done')
end

CreateThread(function()
    Wait(1200)
    installDatabase()
end)

local function addItem(src, itemName, metadata)
    if not Config.Inventory.enabled or GetResourceState(Config.Inventory.resource) ~= 'started' then
        return false, 'ox_inventory nincs elindítva.'
    end
    local ok = exports.ox_inventory:AddItem(src, itemName, 1, metadata)
    if ok then return true end
    return false, 'Nem sikerült itemet hozzáadni.'
end

local function compactItemMetadata(metadata, orderId, ownerIdentifier)
    metadata = metadata or {}
    return {
        label = tostring(metadata.label or 'RealRPG Outfit'):sub(1, 80),
        description = tostring(metadata.description or 'Egyedi RealRPG ruházat'):sub(1, 180),
        gender = metadata.gender,
        itemType = metadata.itemType or 'outfit',
        previewType = metadata.previewType,
        skin = metadata.skin or {},
        components = metadata.components or {},
        props = metadata.props or {},
        designId = metadata.designId,
        orderId = orderId,
        owner = ownerIdentifier,
        customTexture = metadata.customTexture,
        createdAt = metadata.createdAt or os.date('%Y-%m-%d %H:%M:%S')
    }
end

ESX.RegisterServerCallback('realrpg_clothing_designer:canUseOwnedItem', function(source, cb, ownerIdentifier)
    if not (Config.Inventory and Config.Inventory.enforceOwner) then cb(true) return end
    ownerIdentifier = ownerIdentifier and tostring(ownerIdentifier) or ''
    if ownerIdentifier == '' then cb(true) return end
    cb(identifier(source) == ownerIdentifier or IsPlayerAceAllowed(source, Config.AdminPermission))
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:saveDesign', function(source, cb, data)
    local idf = identifier(source)
    if not idf then cb({ ok = false, error = 'Nincs játékos azonosító.' }) return end
    local normalized, validationError = normalizePlayerDesignPayload(data)
    if not normalized then cb({ ok = false, error = validationError }) return end
    data = normalized
    if not takePayment(source, Config.Price.SaveDesign) then cb({ ok = false, error = ('Nincs elég %s.'):format(Config.RealCoin.label or 'pénz') }) return end
    local name = tostring(data.name or 'RealRPG Design'):sub(1, 80)
    local inserted = MySQL.insert.await('INSERT INTO realrpg_clothing_designs (identifier, name, gender, preview_type, skin, components, props, canvas, image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        idf,
        name,
        tostring(data.gender or 'unknown'),
        tostring(data.previewType or 'hoodie'),
        json.encode(data.skin or {}),
        json.encode(data.components or {}),
        json.encode(data.props or {}),
        json.encode(data.canvas or {}),
        data.image and tostring(data.image):sub(1, 15000000) or nil
    })
    cb({ ok = true, id = inserted })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getMyDesigns', function(source, cb)
    local idf = identifier(source)
    if not idf then cb({}) return end
    cb(MySQL.query.await('SELECT id, name, gender, preview_type, created_at FROM realrpg_clothing_designs WHERE identifier = ? ORDER BY id DESC LIMIT 100', { idf }) or {})
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getDesign', function(source, cb, id)
    local idf = identifier(source)
    if not idf or not id then cb(nil) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? AND identifier = ? LIMIT 1', { id, idf })
    if not row then cb(nil) return end
    row.skin = safeJsonDecode(row.skin)
    row.components = safeJsonDecode(row.components)
    row.props = safeJsonDecode(row.props)
    row.canvas = safeJsonDecode(row.canvas)
    cb(row)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:orderItem', function(source, cb, data)
    local idf = identifier(source)
    if not idf then cb({ ok = false, error = 'Nincs játékos azonosító.' }) return end

    data = type(data) == 'table' and data or {}
    local designId = tonumber(data.designId)

    if designId then
        local ownedDesign = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? AND identifier = ? LIMIT 1', { designId, idf })
        if not ownedDesign then cb({ ok = false, error = 'A hivatkozott terv nem a játékos tulajdona.' }) return end
        data = {
            name = ownedDesign.name,
            itemType = data.itemType,
            type = data.type,
            designId = designId,
            gender = ownedDesign.gender,
            previewType = ownedDesign.preview_type,
            skin = safeJsonDecode(ownedDesign.skin),
            components = safeJsonDecode(ownedDesign.components),
            props = safeJsonDecode(ownedDesign.props),
            canvas = safeJsonDecode(ownedDesign.canvas),
            image = ownedDesign.image
        }
    end

    local normalized, validationError = normalizePlayerDesignPayload(data)
    if not normalized then cb({ ok = false, error = validationError }) return end
    data = normalized

    local itemType = (data.itemType == 'part' or data.type == 'part') and 'part' or 'outfit'
    local requiresTextureExport = data.canvas and type(data.canvas.layers) == 'table' and #data.canvas.layers > 0 and data.canvas.template ~= nil
    local price = itemType == 'part' and Config.Price.OrderPartItem or Config.Price.OrderOutfitItem
    if requiresTextureExport then price = price + (Config.Price.CustomDesignFee or 0) end

    if not takePayment(source, price) then cb({ ok = false, error = ('Nincs elég %s.'):format(Config.RealCoin.label or 'pénz') }) return end

    if not designId then
        designId = MySQL.insert.await('INSERT INTO realrpg_clothing_designs (identifier, name, gender, preview_type, skin, components, props, canvas, image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            idf, tostring(data.name or 'RealRPG Design'):sub(1, 80), tostring(data.gender or 'unknown'),
            tostring(data.previewType or 'hoodie'), json.encode(data.skin or {}), json.encode(data.components or {}),
            json.encode(data.props or {}), json.encode(data.canvas or {}), data.image and tostring(data.image):sub(1, 15000000) or nil
        })
    end

    local metadata = {
        label = tostring(data.name or (itemType == 'part' and 'RealRPG Clothing Part' or 'RealRPG Outfit')):sub(1, 80),
        description = itemType == 'part' and 'Fel/le vehető RealRPG ruhadarab' or 'RealRPG Clothing Designer outfit',
        gender = data.gender,
        itemType = itemType,
        previewType = data.previewType,
        skin = data.skin or {},
        components = data.components or {},
        props = data.props or {},
        designId = designId,
        requiresTextureExport = requiresTextureExport == true,
        orderPrice = price,
        createdAt = os.date('%Y-%m-%d %H:%M:%S')
    }

    local status = (requiresTextureExport or (Config.Orders and Config.Orders.requireAdminApproval)) and 'pending' or (Config.Flow.defaultOrderStatus or 'ready')
    local orderId = MySQL.insert.await('INSERT INTO realrpg_clothing_orders (identifier, design_id, name, type, metadata, status, price) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        idf, designId, metadata.label, itemType, json.encode(metadata), status, price
    })

    if status == 'pending' then
        cb({ ok = true, pending = true, orderId = orderId, status = status, price = price })
        return
    end

    local itemName = itemType == 'part' and Config.Inventory.clothingPartItem or Config.Inventory.outfitItem
    local itemMetadata = compactItemMetadata(metadata, orderId, idf)
    local ok, err = addItem(source, itemName, itemMetadata)
    if ok then MySQL.update('UPDATE realrpg_clothing_orders SET status = ?, item_delivered = 1 WHERE id = ?', { 'ready', orderId }) end
    cb({ ok = ok, error = err, metadata = ok and itemMetadata or nil, orderId = orderId, status = ok and 'ready' or status })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getSkin:server', function(source, cb)
    local idf = identifier(source)
    if not idf then cb(nil) return end
    local row = MySQL.single.await('SELECT skin FROM users WHERE identifier = ? LIMIT 1', { idf })
    if row and row.skin then cb(safeJsonDecode(row.skin)) else cb(nil) end
end)

RegisterNetEvent('realrpg_clothing_designer:saveAppearanceSkin', function(skin)
    local src = source
    local idf = identifier(src)
    if not idf then return end
    MySQL.update('UPDATE users SET skin = ? WHERE identifier = ?', { json.encode(skin or {}), idf })
end)

RegisterNetEvent('realrpg_clothing_designer:saveCaptureMeta', function(name, category, drawable, texture, result)
    local src = source
    local idf = identifier(src)
    if not idf then return end
    MySQL.insert('INSERT INTO realrpg_clothing_captures (identifier, name, category, drawable, texture, result) VALUES (?, ?, ?, ?, ?, ?)', {
        idf,
        tostring(name or 'capture'):sub(1, 80),
        category and tostring(category):sub(1, 50) or nil,
        tonumber(drawable),
        tonumber(texture),
        tostring(result or ''):sub(1, 16000000)
    })
end)


local function isAdmin(src)
    if src == 0 then return true end
    return Config.Admin.enabled and IsPlayerAceAllowed(src, Config.AdminPermission)
end

ESX.RegisterServerCallback('realrpg_clothing_designer:isAdmin', function(source, cb)
    cb(isAdmin(source))
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:renameDesign', function(source, cb, id, name)
    if not Config.Flow.allowRenameDesign then cb({ ok=false, error='Átnevezés letiltva.' }) return end
    local idf = identifier(source); if not idf or not id then cb({ ok=false }) return end
    if not takePayment(source, Config.Price.RenameDesign or 0) then cb({ ok=false, error=('Nincs elég %s.'):format(Config.RealCoin.label or 'pénz') }) return end
    local affected = MySQL.update.await('UPDATE realrpg_clothing_designs SET name = ? WHERE id = ? AND identifier = ?', { tostring(name or 'RealRPG Design'):sub(1,80), id, idf })
    cb({ ok = (affected or 0) > 0 })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:deleteDesign', function(source, cb, id)
    if not Config.Flow.allowDeleteDesign then cb({ ok=false, error='Törlés letiltva.' }) return end
    local idf = identifier(source); if not idf or not id then cb({ ok=false }) return end
    local affected = MySQL.update.await('DELETE FROM realrpg_clothing_designs WHERE id = ? AND identifier = ?', { id, idf })
    cb({ ok = (affected or 0) > 0 })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:duplicateDesign', function(source, cb, id)
    if not Config.Flow.allowDuplicateDesign then cb({ ok=false, error='Másolás letiltva.' }) return end
    local idf = identifier(source); if not idf or not id then cb({ ok=false }) return end
    if not takePayment(source, Config.Price.DuplicateDesign or 0) then cb({ ok=false, error=('Nincs elég %s.'):format(Config.RealCoin.label or 'pénz') }) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? AND identifier = ? LIMIT 1', { id, idf })
    if not row then cb({ ok=false }) return end
    local newId = MySQL.insert.await('INSERT INTO realrpg_clothing_designs (identifier, name, gender, preview_type, skin, components, props, canvas, image, is_public) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        idf, (row.name or 'Design') .. ' másolat', row.gender, row.preview_type, row.skin, row.components, row.props, row.canvas, row.image, 0
    })
    cb({ ok=true, id=newId })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:orderSavedDesignItem', function(source, cb, id, itemType)
    local idf = identifier(source); if not idf or not id then cb({ ok=false }) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? AND identifier = ? LIMIT 1', { id, idf })
    if not row then cb({ ok=false }) return end
    local data = { name=row.name, itemType=itemType or 'outfit', designId=id, gender=row.gender, previewType=row.preview_type, skin=safeJsonDecode(row.skin), components=safeJsonDecode(row.components), props=safeJsonDecode(row.props), canvas=safeJsonDecode(row.canvas), image=row.image }
    local requiresTextureExport = data.canvas and type(data.canvas.layers) == 'table' and #data.canvas.layers > 0 and data.canvas.template ~= nil
    local price = data.itemType == 'part' and Config.Price.OrderPartItem or Config.Price.OrderOutfitItem
    if requiresTextureExport then price = price + (Config.Price.CustomDesignFee or 0) end
    if not takePayment(source, price) then cb({ ok=false, error=('Nincs elég %s.'):format(Config.RealCoin.label or 'pénz') }) return end
    local metadata = { label=tostring(data.name or 'RealRPG Outfit'):sub(1,80), description='RealRPG Clothing Designer mentett dizájn', gender=data.gender, itemType=data.itemType, previewType=data.previewType, skin=data.skin, components=data.components, props=data.props, designId=id, requiresTextureExport=requiresTextureExport == true, orderPrice=price, createdAt=os.date('%Y-%m-%d %H:%M:%S') }
    local status = (requiresTextureExport or (Config.Orders and Config.Orders.requireAdminApproval)) and 'pending' or 'ready'
    local orderId = MySQL.insert.await('INSERT INTO realrpg_clothing_orders (identifier, design_id, name, type, metadata, status, price) VALUES (?, ?, ?, ?, ?, ?, ?)', { idf, id, metadata.label, data.itemType, json.encode(metadata), status, price })
    if status == 'pending' then cb({ ok=true, pending=true, orderId=orderId, status=status, price=price }) return end
    local itemName = data.itemType == 'part' and Config.Inventory.clothingPartItem or Config.Inventory.outfitItem
    local itemMetadata = compactItemMetadata(metadata, orderId, idf)
    local ok, err = addItem(source, itemName, itemMetadata)
    if ok then MySQL.update('UPDATE realrpg_clothing_orders SET status = ?, item_delivered = 1 WHERE id = ?', { 'ready', orderId }) end
    cb({ ok=ok, error=err, orderId=orderId, status=ok and 'ready' or status })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getMyOrders', function(source, cb)
    local idf = identifier(source); if not idf then cb({}) return end
    cb(MySQL.query.await('SELECT id, design_id, name, type, status, price, note, reviewed_at, created_at FROM realrpg_clothing_orders WHERE identifier = ? ORDER BY id DESC LIMIT 100', { idf }) or {})
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminListDesigns', function(source, cb)
    if not isAdmin(source) then cb({}) return end
    cb(MySQL.query.await('SELECT id, identifier, name, gender, preview_type, created_at FROM realrpg_clothing_designs ORDER BY id DESC LIMIT ?', { Config.Admin.maxList or 150 }) or {})
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminGetDesign', function(source, cb, id)
    if not isAdmin(source) or not id then cb(nil) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? LIMIT 1', { id })
    if not row then cb(nil) return end
    row.skin = safeJsonDecode(row.skin); row.components = safeJsonDecode(row.components); row.props = safeJsonDecode(row.props); row.canvas = safeJsonDecode(row.canvas)
    cb(row)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminGiveDesignItem', function(source, cb, id)
    if not isAdmin(source) or not id then cb({ ok=false, error='Nincs jogosultság.' }) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? LIMIT 1', { id })
    if not row then cb({ ok=false }) return end
    local metadata = compactItemMetadata({ label=row.name, description='Admin által kiadott RealRPG outfit', gender=row.gender, itemType='outfit', previewType=row.preview_type, skin=safeJsonDecode(row.skin), components=safeJsonDecode(row.components), props=safeJsonDecode(row.props), designId=row.id }, nil, identifier(source))
    local ok, err = addItem(source, Config.Inventory.outfitItem, metadata)
    cb({ ok=ok, error=err })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminOpenForPlayer', function(source, cb, target)
    if not isAdmin(source) or not Config.Admin.allowOpenForPlayers then cb({ ok=false }) return end
    target = tonumber(target)
    if not target or not GetPlayerName(target) then cb({ ok=false, error='Hibás player ID.' }) return end
    TriggerClientEvent('realrpg_clothing_designer:open', target)
    cb({ ok=true })
end)


local function findOnlineByIdentifier(idf)
    for _, sid in ipairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(tonumber(sid))
        if xPlayer and xPlayer.identifier == idf then return tonumber(sid) end
    end
    return nil
end

ESX.RegisterServerCallback('realrpg_clothing_designer:cancelOrder', function(source, cb, id)
    local idf = identifier(source); if not idf or not id then cb({ ok=false }) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_orders WHERE id = ? AND identifier = ? LIMIT 1', { id, idf })
    if not row or row.status ~= 'pending' or not (Config.Orders and Config.Orders.allowPlayerCancelPending) then cb({ ok=false, error='Ez a rendelés már nem mondható le.' }) return end
    MySQL.update('UPDATE realrpg_clothing_orders SET status = ?, note = ? WHERE id = ?', { 'cancelled', 'Játékos által lemondva', id })
    cb({ ok=true })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminListOrders', function(source, cb, status)
    if not isAdmin(source) then cb({}) return end
    status = tostring(status or 'pending')
    local q, params
    if status == 'all' then
        q = 'SELECT id, identifier, design_id, name, type, status, price, note, item_delivered, reviewed_by, reviewed_at, created_at FROM realrpg_clothing_orders ORDER BY id DESC LIMIT ?'
        params = { Config.Admin.maxList or 150 }
    else
        q = 'SELECT id, identifier, design_id, name, type, status, price, note, item_delivered, reviewed_by, reviewed_at, created_at FROM realrpg_clothing_orders WHERE status = ? ORDER BY id DESC LIMIT ?'
        params = { status, Config.Admin.maxList or 150 }
    end
    cb(MySQL.query.await(q, params) or {})
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminGetOrder', function(source, cb, id)
    if not isAdmin(source) or not id then cb(nil) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_orders WHERE id = ? LIMIT 1', { id })
    if not row then cb(nil) return end
    row.metadata = safeJsonDecode(row.metadata)
    if row.design_id then
        local design = MySQL.single.await('SELECT * FROM realrpg_clothing_designs WHERE id = ? LIMIT 1', { row.design_id })
        if design then
            row.metadata.skin = safeJsonDecode(design.skin)
            row.metadata.components = safeJsonDecode(design.components)
            row.metadata.props = safeJsonDecode(design.props)
            row.metadata.canvas = safeJsonDecode(design.canvas)
            row.metadata.image = design.image
            row.metadata.previewType = design.preview_type
            row.metadata.gender = design.gender
            row.metadata.label = design.name or row.metadata.label
            row.metadata.designId = design.id
        end
    end
    cb(row)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminSetOrderStatus', function(source, cb, id, status, note)
    if not isAdmin(source) or not id then cb({ ok=false, error='Nincs jogosultság.' }) return end
    status = tostring(status or 'pending')
    if not ({pending=true, approved=true, rejected=true, ready=true, cancelled=true})[status] then cb({ ok=false, error='Hibás státusz.' }) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_orders WHERE id = ? LIMIT 1', { id })
    if not row then cb({ ok=false, error='Rendelés nem található.' }) return end
    local currentMetadata = safeJsonDecode(row.metadata)
    if (status == 'approved' or status == 'ready') and currentMetadata.requiresTextureExport and not currentMetadata.customTexture then
        cb({ ok=false, error='A rendeléshez előbb exportálni kell az egyedi YTD textúrát.' })
        return
    end
    MySQL.update('UPDATE realrpg_clothing_orders SET status = ?, reviewed_by = ?, reviewed_at = NOW(), note = ? WHERE id = ?', { status, GetPlayerName(source) or 'admin', tostring(note or ''):sub(1,255), id })

    if status == 'ready' and Config.Orders and Config.Orders.giveItemOnApprove then
        if tonumber(row.item_delivered or 0) == 1 then
            cb({ ok=true, delivered=false, alreadyDelivered=true, status='ready', message='Az item már ki lett adva.' })
            return
        end
        local target = findOnlineByIdentifier(row.identifier)
        if target then
            local metadata = safeJsonDecode(row.metadata)
            local itemName = row.type == 'part' and Config.Inventory.clothingPartItem or Config.Inventory.outfitItem
            local itemMetadata = compactItemMetadata(metadata, id, row.identifier)
            local ok, err = addItem(target, itemName, itemMetadata)
            if ok then MySQL.update('UPDATE realrpg_clothing_orders SET status = ?, item_delivered = 1 WHERE id = ?', { 'ready', id }) end
            cb({ ok = ok, delivered = ok, error = err, status = ok and 'ready' or status })
            return
        end
        cb({ ok=true, delivered=false, offline=true, status=status, message='A játékos offline, item jóváhagyva, de kézzel kell kiadni vagy online állapotban újra jóváhagyni.' })
        return
    elseif status == 'rejected' and Config.Orders and Config.Orders.refundOnReject then
        local target = findOnlineByIdentifier(row.identifier)
        if target then givePayment(target, row.price or 0) end
    end
    cb({ ok=true, status=status })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:adminDeliverOrder', function(source, cb, id)
    if not isAdmin(source) or not id then cb({ ok=false, error='Nincs jogosultság.' }) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_orders WHERE id = ? LIMIT 1', { id })
    if not row then cb({ ok=false, error='Rendelés nem található.' }) return end
    if tonumber(row.item_delivered or 0) == 1 then cb({ ok=false, alreadyDelivered=true, error='Az item már ki lett adva.' }) return end
    local target = findOnlineByIdentifier(row.identifier)
    if not target then cb({ ok=false, offline=true, error='A játékos nincs fent.' }) return end
    local metadata = safeJsonDecode(row.metadata)
    if metadata.requiresTextureExport and not metadata.customTexture then
        cb({ ok=false, error='A rendeléshez előbb exportálni kell az egyedi YTD textúrát.' })
        return
    end
    local itemName = row.type == 'part' and Config.Inventory.clothingPartItem or Config.Inventory.outfitItem
    local itemMetadata = compactItemMetadata(metadata, id, row.identifier)
    local ok, err = addItem(target, itemName, itemMetadata)
    if ok then MySQL.update('UPDATE realrpg_clothing_orders SET status = ?, item_delivered = 1, reviewed_by = ?, reviewed_at = NOW(), note = ? WHERE id = ?', { 'ready', GetPlayerName(source) or 'admin', 'Item kiadva', id }) end
    cb({ ok=ok, error=err })
end)

-- ox_inventory item usage is implemented with client exports in client/main.lua.
-- Do not use RegisterUsableItem here; current ox_inventory versions use item client/server exports.



-- V12 server diagnostics / install checker. Use /rcd_check in console or as admin.
local function resourceState(name)
    if not name or name == '' then return 'missing' end
    return GetResourceState(name)
end

local function runDiagnostics(src)
    local lines = {
        ('^5[RealRPG Clothing Designer V%s]^7 Diagnosztika:'):format(Config.Version or '17.0.0'),
        ('  es_extended: %s'):format(resourceState('es_extended')),
        ('  oxmysql: %s'):format(resourceState('oxmysql')),
        ('  %s: %s'):format(Config.Inventory.resource or 'ox_inventory', resourceState(Config.Inventory.resource or 'ox_inventory')),
        ('  %s: %s'):format(Config.ImageGenerator.resource or 'screenshot-basic', resourceState(Config.ImageGenerator.resource or 'screenshot-basic')),
        ('  %s: %s'):format(Config.Target.resource or 'ox_target', resourceState(Config.Target.resource or 'ox_target')),
        ('  appearance: %s'):format(Config.Appearance.system or 'esx_skin'),
        ('  admin ace: %s'):format(Config.AdminPermission or 'realrpg.clothingdesigner.admin'),
        ('  worker mode: %s'):format((Config.Worker and Config.Worker.Mode) or 'resource'),
        ('  worker resource: %s'):format(resourceState((Config.Worker and Config.Worker.Resource) or 'realrpg_clothing_worker')),
        ('  filesystem permission line: %s'):format((Config.Permissions and Config.Permissions.FilesystemPermissionLine) or 'n/a'),
        ('  authorization: %s'):format((Config.Authorization and Config.Authorization.Enabled) and 'enabled' or 'disabled'),
        ('  saved designs: %s'):format((Config.SavedDesigns and Config.SavedDesigns.Enabled) and 'enabled' or 'disabled'),
        ('  AI: %s/%s'):format((Config.AI and Config.AI.Enabled) and 'enabled' or 'disabled', (Config.AI and Config.AI.Provider) or 'none')
    }
    for _, line in ipairs(lines) do
        if src and src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', line:gsub('%^%d',''):gsub('%^7','') } }) else print(line) end
    end
end

ESX.RegisterServerCallback('realrpg_clothing_designer:getDiagnostics', function(source, cb)
    cb({
        ok = true,
        version = Config.Version or '17.0.0',
        isAdmin = isAdmin and isAdmin(source) or false,
        resources = {
            es_extended = resourceState('es_extended'),
            oxmysql = resourceState('oxmysql'),
            inventory = resourceState(Config.Inventory.resource or 'ox_inventory'),
            screenshot = resourceState(Config.ImageGenerator.resource or 'screenshot-basic'),
            target = resourceState(Config.Target.resource or 'ox_target')
        },
        worker = {
            mode = Config.Worker and Config.Worker.Mode or 'resource',
            resource = Config.Worker and Config.Worker.Resource or 'realrpg_clothing_worker',
            state = resourceState((Config.Worker and Config.Worker.Resource) or 'realrpg_clothing_worker'),
            childProcessLine = Config.Permissions and Config.Permissions.UnsafeChildProcessLine or '',
            filesystemLine = Config.Permissions and Config.Permissions.FilesystemPermissionLine or ''
        },
        authorization = {
            enabled = Config.Authorization and Config.Authorization.Enabled or false,
            hasAccess = hasGrantedAccess(source),
            notAuthorizedMessage = Config.Authorization and Config.Authorization.NotAuthorizedMessage or 'not_authorized'
        },
        savedDesigns = Config.SavedDesigns or {},
        ai = { enabled = Config.AI and Config.AI.Enabled or false, provider = Config.AI and Config.AI.Provider or 'none' }
    })
end)

RegisterCommand('rcd_check', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    runDiagnostics(src)
end, true)

RegisterCommand('rcd_givedesign', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    local target = tonumber(args[1])
    if not target then return end
    TriggerClientEvent('realrpg_clothing_designer:open', target)
end, true)



-- V12 docs-parity template folder rules / preview generation / slot YTD layout / addon-first export flow.
local function pathJoin(...)
    local out = table.concat({ ... }, '/')
    out = out:gsub('/+', '/')
    return out
end

local function baseName(path)
    return tostring(path or ''):match('([^/\\]+)$') or tostring(path or '')
end

local function stemName(file)
    return baseName(file):gsub('%.[^.]+$', '')
end

local function lowerExt(file)
    return (tostring(file or ''):lower():match('%.([^.]+)$') or '')
end

local function stripResourceRoot(full, root)
    full = tostring(full or ''):gsub('\\','/')
    root = tostring(root or ''):gsub('\\','/')
    if full:sub(1, #root) == root then
        return full:sub(#root + 2)
    end
    return full
end

local function readAllFiles(folder)
    local files, visited = {}, {}
    local knownFileExtensions = {
        ydd = true, ytd = true, ymt = true, ydr = true,
        png = true, webp = true, jpg = true, jpeg = true,
        json = true, lua = true, txt = true
    }

    local function walk(dir)
        dir = tostring(dir or ''):gsub('\\', '/')
        if dir == '' or visited[dir] then return end
        visited[dir] = true

        local handle = io and io.readdir and io.readdir(dir) or nil
        if not handle then return end

        for name in handle:lines() do
            if name and name ~= '' and name ~= '.' and name ~= '..' then
                local full = pathJoin(dir, name)
                local ext = lowerExt(name)
                if knownFileExtensions[ext] then
                    files[#files + 1] = full
                elseif name ~= '.keep' then
                    walk(full)
                end
            end
        end
        handle:close()
    end

    walk(folder)
    return files
end

local function ensureWorkspaceFolders()
    if not (Config.TemplateFlow and Config.TemplateFlow.createMissingWorkspaceDirectories) then return end
    local folders = {
        Config.TemplateFlow.templateRoot,
        Config.TemplateFlow.previewRoot,
        Config.TemplateFlow.slotRoot,
        Config.TemplateFlow.exportRoot,
        Config.TemplateFlow.workspaceRoot,
        Config.TemplateFlow.tempPreviewCache
    }
    for _, rel in ipairs(folders) do
        SaveResourceFile(GetCurrentResourceName(), pathJoin(rel, '.keep'), '', -1)
    end
end

local function parseTemplatePath(relPath)
    local tf = Config.TemplateFlow or {}
    local root = (tf.templateRoot or 'templates/cloth_templates'):gsub('%.','%%.'):gsub('/','/')
    local pattern = '^' .. root .. '/([^/]+)/([^/]+)/([^/]+)$'
    local gender, component, fileName = relPath:gsub('\\','/'):match(pattern)
    if not gender or not component or not fileName then
        return nil, 'wrong_folder_structure'
    end
    gender = gender:lower(); component = component:lower()
    local ext = lowerExt(fileName)
    if not (tf.genders and tf.genders[gender]) then return nil, 'top_folder_must_be_male_or_female' end
    if not (tf.supportedComponents and tf.supportedComponents[component]) then return nil, 'unsupported_component_folder' end
    if not (tf.templateExtensions and tf.templateExtensions[ext]) then return nil, 'unsupported_file_type' end
    local stem = stemName(fileName):lower()
    if stem:sub(1, #component) ~= component then return nil, 'file_prefix_must_match_component' end
    local templateKey = ('%s_%s_%s'):format(gender, component, stem:gsub('_[ur]$',''))
    return {
        name = stem,
        fileName = fileName,
        fileType = ext,
        gender = gender,
        category = component,
        componentKey = component,
        previewType = (tf.componentToPreviewType and tf.componentToPreviewType[component]) or 'hoodie',
        modelName = stem,
        textureName = stem,
        drawable = tonumber(stem:match('_(%d+)_')) or tonumber(stem:match('_(%d+)$')) or 0,
        texture = stem:match('_r$') and 1 or 0,
        templateKey = templateKey,
        templatePath = relPath,
        previewPath = nil,
        slotPath = pathJoin(tf.slotRoot or 'templates/template_slots', templateKey),
        managedPreview = false,
        skippedReason = nil,
        meta = { source = 'template-folder-scan', docs = 'templates/cloth_templates/<gender>/<component>/<file>.ydd|ytd' }
    }, nil
end

local function findPreviewForTemplate(t)
    local tf = Config.TemplateFlow or {}
    local previewRoot = tf.previewRoot or 'templates/template_previews'
    local stem = stemName(t.fileName)
    for _, ext in ipairs(tf.previewExtensions or { 'png', 'webp', 'jpg', 'jpeg' }) do
        local rel = pathJoin(previewRoot, t.gender, t.componentKey, stem .. '.' .. ext)
        local absolute = pathJoin(GetResourcePath(GetCurrentResourceName()) or '', rel)
        local f = io.open(absolute, 'rb')
        if f then f:close(); return rel, false end
    end
    if tf.generateMissingPreviews then
        local generated = pathJoin(previewRoot, t.gender, t.componentKey, stem .. '.' .. (tf.generatedPreviewExtension or 'png'))
        -- Placeholder file. Client-side screenshot-basic can overwrite this with a real png when the template is previewed.
        SaveResourceFile(GetCurrentResourceName(), generated, '', -1)
        return generated, true
    end
    return nil, false
end

local function slotFolderExists(t)
    local absolute = pathJoin(GetResourcePath(GetCurrentResourceName()) or '', t.slotPath or '')
    local files = readAllFiles(absolute)
    for _, f in ipairs(files) do if lowerExt(f) == 'ytd' then return t.slotPath end end
    return nil
end

local function registerTemplateRow(t)
    if not t or not t.fileName then return false end
    local exists = MySQL.single.await('SELECT id FROM realrpg_clothing_templates WHERE file_name = ? AND gender = ? AND category = ? LIMIT 1', { t.fileName, t.gender or 'unisex', t.componentKey or t.category or 'other' })
    local meta = t.meta or {}
    meta.templateKey = t.templateKey
    meta.templatePath = t.templatePath
    meta.previewPath = t.previewPath
    meta.slotPath = t.slotPath
    meta.managedPreview = t.managedPreview == true
    meta.skippedReason = t.skippedReason

    local payload = {
        tostring(t.name or t.fileName):sub(1,120),
        tostring(t.fileName):sub(1,180),
        tostring(t.fileType or 'ydd'):sub(1,10),
        tostring(t.category or t.componentKey or 'other'):sub(1,50),
        tostring(t.gender or 'unisex'):sub(1,20),
        tostring(t.previewType or 'hoodie'):sub(1,40),
        tostring(t.componentKey or t.category or 'other'):sub(1,60),
        tostring(t.modelName or ''):sub(1,120),
        tostring(t.textureName or ''):sub(1,120),
        tonumber(t.drawable) or 0,
        tonumber(t.texture) or 0,
        t.previewPath and tostring(t.previewPath):sub(1,16000000) or nil,
        json.encode(meta),
        t.active == false and 0 or 1,
        tostring(t.templateKey or ''):sub(1,180),
        tostring(t.templatePath or ''):sub(1,255),
        tostring(t.previewPath or ''):sub(1,255),
        tostring(t.slotPath or ''):sub(1,255),
        t.managedPreview and 1 or 0,
        t.skippedReason and tostring(t.skippedReason):sub(1,255) or nil
    }
    if exists then
        MySQL.update.await('UPDATE realrpg_clothing_templates SET name = ?, file_type = ?, preview_type = ?, model_name = ?, texture_name = ?, drawable = ?, texture = ?, image = ?, meta = ?, active = ?, template_key = ?, template_path = ?, preview_path = ?, slot_path = ?, managed_preview = ?, skipped_reason = ?, updated_at = NOW() WHERE id = ?', {
            payload[1], payload[3], payload[6], payload[8], payload[9], payload[10], payload[11], payload[12], payload[13], payload[14], payload[15], payload[16], payload[17], payload[18], payload[19], payload[20], exists.id
        })
        return exists.id
    end
    return MySQL.insert.await('INSERT INTO realrpg_clothing_templates (name, file_name, file_type, category, gender, preview_type, component_key, model_name, texture_name, drawable, texture, image, meta, active, template_key, template_path, preview_path, slot_path, managed_preview, skipped_reason, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())', payload)
end

local function cleanTemporaryPreviewCache()
    if not (Config.TemplateFlow and Config.TemplateFlow.cleanTemporaryPreviewCache) then return 0 end
    -- Safe behavior: create the cache marker only. Real deletion is intentionally not done automatically to avoid deleting user files.
    SaveResourceFile(GetCurrentResourceName(), pathJoin(Config.TemplateFlow.tempPreviewCache or 'data/workspace/preview_cache', '.keep'), '', -1)
    return 0
end

local function scanTemplateFolders()
    if not (Config.TemplateFlow and Config.TemplateFlow.enabled) then return { ok = false, error = 'Template flow disabled.' } end
    ensureWorkspaceFolders()
    local root = GetResourcePath(GetCurrentResourceName())
    if not root then return { ok=false, error='Resource path nem található.' } end
    local templateRootAbs = pathJoin(root, Config.TemplateFlow.templateRoot or 'templates/cloth_templates')
    local result = { ok=true, scanned=0, registered=0, skipped=0, generatedPreviews=0, slots=0, files={}, skippedFiles={} }
    for _, full in ipairs(readAllFiles(templateRootAbs)) do
        local rel = stripResourceRoot(full, root)
        local ext = lowerExt(full)
        if Config.TemplateFlow.templateExtensions and Config.TemplateFlow.templateExtensions[ext] then
            result.scanned = result.scanned + 1
            local data, reason = parseTemplatePath(rel)
            if data then
                local preview, managed = findPreviewForTemplate(data)
                data.previewPath = preview
                data.managedPreview = managed
                if managed then result.generatedPreviews = result.generatedPreviews + 1 end
                if slotFolderExists(data) then result.slots = result.slots + 1 end
                local id = registerTemplateRow(data)
                if id then result.registered = result.registered + 1; data.id = id end
                result.files[#result.files+1] = data
            else
                result.skipped = result.skipped + 1
                result.skippedFiles[#result.skippedFiles+1] = { path = rel, reason = reason }
            end
        end
    end
    cleanTemporaryPreviewCache()
    return result
end

local function serializeTemplate(row)
    if not row then return nil end
    row.meta = safeJsonDecode(row.meta)
    row.template_key = row.template_key or (row.meta and row.meta.templateKey)
    row.template_path = row.template_path or (row.meta and row.meta.templatePath)
    row.preview_path = row.preview_path or (row.meta and row.meta.previewPath)
    row.slot_path = row.slot_path or (row.meta and row.meta.slotPath)
    return row
end

local function listTemplateRows(category, gender)
    local q = 'SELECT * FROM realrpg_clothing_templates WHERE active = 1'
    local params = {}
    if category and category ~= '' and category ~= 'all' then q = q .. ' AND category = ?'; params[#params+1] = category end
    if gender and gender ~= '' and gender ~= 'all' then q = q .. ' AND gender = ?'; params[#params+1] = gender end
    q = q .. ' ORDER BY gender, category, file_name ASC'
    local rows = MySQL.query.await(q, params) or {}
    for i=1,#rows do rows[i] = serializeTemplate(rows[i]) end
    return rows
end

local function exportTemplateJsonInternal(id)
    id = tonumber(id)
    if not id then return false, 'invalid id' end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_templates WHERE id = ? LIMIT 1', { id })
    if not row then return false, 'template not found' end
    row = serializeTemplate(row)
    local relPath = pathJoin(Config.TemplateFlow.workspaceRoot or 'data/workspace', ('template_%s.json'):format(id))
    SaveResourceFile(GetCurrentResourceName(), relPath, json.encode(row), -1)
    return true, relPath, row
end

local function exportAddonInternal(id, addonName)
    local ok, jsonPath, row = exportTemplateJsonInternal(id)
    if not ok then return false, jsonPath end
    addonName = tostring(addonName or ('realrpg_clothing_' .. (row.template_key or row.id))):gsub('[^%w_%-]', '_')
    local manifest = [[fx_version 'cerulean'
game 'gta5'

version '17.0.0'

files {
    'stream/*.ydd',
    'stream/*.ytd',
    'stream/*.ymt'
}

data_file 'SHOP_PED_APPAREL_META_FILE' 'stream/*.ymt'
]]
    local exportBase = pathJoin(Config.TemplateFlow.exportRoot or 'exports', addonName)
    local mirrorBase = pathJoin(Config.TemplateFlow.mirrorExportRoot or '../realrpg_clothing_exports', addonName)
    SaveResourceFile(GetCurrentResourceName(), pathJoin(exportBase, 'fxmanifest.lua'), manifest, -1)
    SaveResourceFile(GetCurrentResourceName(), pathJoin(exportBase, 'template.json'), json.encode(row), -1)
    SaveResourceFile(GetCurrentResourceName(), pathJoin(exportBase, 'README.txt'), 'Addon-first export created by RealRPG Clothing Designer V17. Copy stream files into this resource if they are not mirrored automatically.\nRestart realrpg_clothing_exports after successful export.\n', -1)
    SaveResourceFile(GetCurrentResourceName(), pathJoin(mirrorBase, 'fxmanifest.lua'), manifest, -1)
    SaveResourceFile(GetCurrentResourceName(), pathJoin(mirrorBase, 'template.json'), json.encode(row), -1)
    SaveResourceFile(GetCurrentResourceName(), pathJoin(Config.TemplateFlow.exportRoot or 'exports', addonName .. '.zip.README.txt'), 'FiveM runtime cannot reliably create zip archives on every host. This marker represents the zip output path; zip the exported folder for distribution.\n', -1)
    return true, { addon = addonName, exportPath = exportBase, mirrorPath = mirrorBase, jsonPath = jsonPath, restart = 'restart realrpg_clothing_exports' }
end

exports('scanStreamTemplates', scanTemplateFolders) -- backward-compatible alias
exports('scanTemplateFolders', scanTemplateFolders)
exports('listTemplates', listTemplateRows)
exports('registerTemplate', function(data) return registerTemplateRow(data) end)
exports('exportTemplateJson', function(id) local ok, path = exportTemplateJsonInternal(id); return ok, path end)
exports('exportAddon', exportAddonInternal)

ESX.RegisterServerCallback('realrpg_clothing_designer:listTemplates', function(source, cb, category, gender)
    if not isAdmin(source) then cb({}) return end
    cb(listTemplateRows(category, gender))
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:scanTemplates', function(source, cb)
    if not isAdmin(source) then cb({ ok=false, error='Nincs jogosultság.' }) return end
    local ok, result = pcall(function()
        return exports[GetCurrentResourceName()]:bridgeRescanTemplates()
    end)
    if not ok then cb({ ok=false, error='Template scan hiba.', detail=tostring(result) }) return end
    result.ok = true
    cb(result)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:registerTemplate', function(source, cb, data)
    if not isAdmin(source) then cb({ ok=false, error='Nincs jogosultság.' }) return end
    data = data or {}
    if not data.fileName then cb({ ok=false, error='Hiányzó fileName.' }) return end
    local id = registerTemplateRow(data)
    cb({ ok = id ~= nil, id = id })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getTemplate', function(source, cb, id)
    if not isAdmin(source) then cb(nil) return end
    local row = MySQL.single.await('SELECT * FROM realrpg_clothing_templates WHERE id = ? LIMIT 1', { tonumber(id) or 0 })
    cb(serializeTemplate(row))
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:deleteTemplate', function(source, cb, id)
    if not isAdmin(source) then cb({ ok=false, error='Nincs jogosultság.' }) return end
    MySQL.update.await('UPDATE realrpg_clothing_templates SET active = 0, updated_at = NOW() WHERE id = ? LIMIT 1', { tonumber(id) or 0 })
    cb({ ok=true })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:exportTemplate', function(source, cb, id)
    if not isAdmin(source) then cb({ ok=false, error='Nincs jogosultság.' }) return end
    local ok, path = exportTemplateJsonInternal(id)
    cb({ ok=ok, path=path })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:exportAddon', function(source, cb, id, addonName)
    if not isAdmin(source) then cb({ ok=false, error='Nincs jogosultság.' }) return end
    local ok, result = exportAddonInternal(id, addonName)
    cb({ ok=ok, result=result })
end)

-- The legacy shell-based scanner is retained only as an export for old integrations.
-- V17 startup and commands use the filetype-safe bridge scanner in server/texture_bridge.lua.
RegisterCommand(Config.TemplateCommand or 'clothingtemplates', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    local ok, res = pcall(function()
        return exports[GetCurrentResourceName()]:bridgeRescanTemplates()
    end)
    local msg
    if ok and type(res) == 'table' then
        msg = ('Template scan: %s file, %s YDD, %s regisztrálva, %s kihagyva. Aktív: %s'):format(
            res.filesFound or 0, res.yddTemplates or 0, res.registered or 0, res.skipped or 0,
            res.catalog and #res.catalog or 0
        )
    else
        msg = 'Template scan hiba: ' .. tostring(res)
    end
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', msg } }) else print('[RCD] ' .. msg) end
end, true)

-- V12 docs-based compatibility layer: skin callback, RealRPG-style callback alias, open store/give menu flow.
ESX.RegisterServerCallback('realrpg_clothing:getSkin:server', function(source, cb)
    local idf = identifier(source)
    if not idf then cb({}) return end
    local row = MySQL.single.await('SELECT skin FROM users WHERE identifier = ? LIMIT 1', { idf })
    cb(safeJsonDecode(row and row.skin or nil))
end)

local function openClothingMenuForTarget(src, target, menuType, restricted)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false, 'Hibás játékos ID.' end
    TriggerClientEvent('realrpg_clothing_designer:openPresetMenu', target, menuType or 'clothing', restricted == true)
    return true
end

exports('openClothStoreForPlayer', function(target, storeType)
    return openClothingMenuForTarget(0, target, storeType or 'clothing', false)
end)

exports('giveClothingMenu', function(target, restricted)
    return openClothingMenuForTarget(0, target, restricted and 'restricted' or 'clothing', restricted == true)
end)

RegisterCommand(Config.GiveClothingMenuCommand or 'giveclothingmenu', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    local target = tonumber(args[1] or src)
    local ok, err = openClothingMenuForTarget(src, target, 'clothing', false)
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', ok and 'Clothing menü megnyitva.' or (err or 'Hiba') } }) else print(ok and '[RCD] Clothing menu opened.' or ('[RCD] ' .. tostring(err))) end
end, true)

RegisterCommand(Config.GiveRestrictedClothingMenuCommand or 'giverestrictedclothingmenu', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    local target = tonumber(args[1] or src)
    local ok, err = openClothingMenuForTarget(src, target, 'restricted', true)
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', ok and 'Restricted clothing menü megnyitva.' or (err or 'Hiba') } }) else print(ok and '[RCD] Restricted clothing menu opened.' or ('[RCD] ' .. tostring(err))) end
end, true)

ESX.RegisterServerCallback('realrpg_clothing_designer:getPriceForSelection', function(source, cb, category, drawable)
    category = tostring(category or '')
    drawable = tonumber(drawable) or 0
    local data = Config.ClothPrices and Config.ClothPrices[category]
    if not data then cb(0) return end
    local price = (data.Customs and data.Customs[drawable]) or data.Default or 0
    cb(price)
end)


-- V12 troubleshooting/auth compatibility layer.
exports('grantPlayerAccess', function(src, minutes)
    return grantAccess(src, minutes)
end)

exports('revokePlayerAccess', function(src)
    revokeAccess(src)
    return true
end)

exports('hasPlayerAccess', function(src)
    return hasGrantedAccess(src)
end)

RegisterNetEvent('realrpg_clothing_designer:grantPlayerAccess', function(target, minutes)
    local src = source
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    grantAccess(target or src, minutes)
end)

-- RealRPG-style alias for migration from documented examples.
exports('grantPlayerAccessRealRPGCompat', function(src, minutes)
    return grantAccess(src, minutes)
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:checkAccess', function(source, cb, context)
    if not (Config.Authorization and Config.Authorization.Enabled) then cb({ ok = true }) return end
    if (context == 'command' and Config.Authorization.AllowCommandOpen) or context == 'shop' or context == 'item' or context == 'internal' then cb({ ok = true }) return end
    if hasGrantedAccess(source) then cb({ ok = true }) return end
    cb({ ok = false, error = Config.Authorization.NotAuthorizedMessage or 'not_authorized' })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getTroubleshootingBundle', function(source, cb)
    if not isAdmin(source) then cb({ ok=false, error='Nincs jogosultság.' }) return end
    cb({
        ok = true,
        resource = GetCurrentResourceName(),
        os = 'unknown_from_fivem_runtime',
        worker = Config.Worker or {},
        permissions = Config.Permissions or {},
        templateFlow = Config.TemplateFlow or {},
        savedDesigns = Config.SavedDesigns or {},
        ai = { enabled = Config.AI and Config.AI.Enabled or false, provider = Config.AI and Config.AI.Provider or 'none', model = Config.AI and Config.AI.Model or '' },
        notes = {
            'Worker indítás: add_unsafe_child_process_permission realrpg_clothing_worker',
            'YTD export: add_filesystem_permission realrpg_clothing_worker write realrpg_clothing_designer',
            'Preview/static file változás után: refresh + restart realrpg_clothing_designer',
            'Sikeres YTD export után: restart realrpg_clothing_designer'
        }
    })
end)

RegisterCommand('rcd_troubleshoot', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission) then return end
    local lines = {
        '[RCD V17 Troubleshooting]',
        ('Worker mode: %s'):format((Config.Worker and Config.Worker.Mode) or 'resource'),
        ('Worker resource: %s'):format(resourceState((Config.Worker and Config.Worker.Resource) or 'realrpg_clothing_worker')),
        ('Child process permission: %s'):format((Config.Permissions and Config.Permissions.UnsafeChildProcessLine) or 'n/a'),
        ('Filesystem permission: %s'):format((Config.Permissions and Config.Permissions.FilesystemPermissionLine) or 'n/a'),
        ('Saved designs: %s'):format((Config.SavedDesigns and Config.SavedDesigns.Enabled) and 'enabled' or 'disabled'),
        ('AI: %s/%s'):format((Config.AI and Config.AI.Enabled) and 'enabled' or 'disabled', (Config.AI and Config.AI.Provider) or 'none')
    }
    for _, line in ipairs(lines) do
        if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', line } }) else print(line) end
    end
end, true)


-- V14: RealRPG-style Exports and RPC / authorization flow
local rcdAuthorizedPlayers = rcdAuthorizedPlayers or {}

local function _rcdPlayerKey(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    return tostring(src)
end

local function rcdGrantAccess(src)
    return grantAccess(src)
end

local function rcdRevokeAccess(src)
    revokeAccess(src)
    return true
end

local function rcdHasAccess(src)
    if not (Config.RPC and Config.RPC.requireAuthorization) then return true end
    return hasGrantedAccess(src)
end

local function rcdTemplateCatalog()
    local rows = {}
    if MySQL and MySQL.query and MySQL.query.await then
        rows = MySQL.query.await('SELECT id, name, file_name, file_type, category, gender, preview_type, component_key, model_name, texture_name, drawable, texture, image, meta, template_key, template_path, preview_path, slot_path, managed_preview, active, skipped_reason, updated_at FROM realrpg_clothing_templates WHERE active = 1 ORDER BY gender, category, drawable, file_name', {}) or {}
    end
    for _, row in ipairs(rows) do
        row.meta = safeJsonDecode(row.meta)
        row.texture_path = row.meta.texturePath or row.meta.ytdPath
        row.ytd_path = row.meta.ytdPath or row.meta.texturePath
    end
    return rows
end

local function rcdRuntimeConfig()
    return {
        version = Config.Version or '17.0.0',
        rpc = Config.RPC or {},
        worker = Config.Worker or {},
        authorization = Config.Authorization or {},
        templateFlow = Config.TemplateFlow or {},
        exports = {
            'getRuntimeConfig',
            'getTemplateCatalog',
            'rescanTemplates',
            'grantPlayerAccess',
            'revokePlayerAccess'
        }
    }
end

local function rcdRescanTemplates()
    local ok, result = pcall(function()
        return exports[GetCurrentResourceName()]:bridgeRescanTemplates()
    end)
    if ok and type(result) == 'table' then return result.catalog or result end
    return rcdTemplateCatalog()
end

exports('getRuntimeConfig', rcdRuntimeConfig)
exports('getTemplateCatalog', rcdTemplateCatalog)
exports('rescanTemplates', rcdRescanTemplates)
exports('openForPlayer', function(src)
    if rcdGrantAccess(src) then
        TriggerClientEvent('realrpg_clothing_designer:client:openClothingDesigner', tonumber(src))
        return true
    end
    return false
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:rpcHasAccess', function(source, cb)
    cb(rcdHasAccess(source))
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getRuntimeConfig', function(source, cb)
    if not rcdHasAccess(source) and not IsPlayerAceAllowed(source, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then cb({ ok=false, error='not_authorized' }) return end
    cb({ ok=true, config=rcdRuntimeConfig() })
end)

ESX.RegisterServerCallback('realrpg_clothing_designer:getTemplateCatalog', function(source, cb)
    cb({ ok=true, catalog=rcdTemplateCatalog() })
end)

RegisterNetEvent('realrpg_clothing_designer:server:grantPlayerAccess', function(target)
    local src = source
    target = tonumber(target or src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then return end
    rcdGrantAccess(target)
end)

RegisterNetEvent('realrpg_clothing_designer:server:revokePlayerAccess', function(target)
    local src = source
    target = tonumber(target or src)
    if src > 0 and target ~= src and not IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then return end
    rcdRevokeAccess(target)
end)

RegisterNetEvent('realrpg_clothing_designer:server:uiClosed', function()
    if Config.RPC and Config.RPC.revokeOnClose then rcdRevokeAccess(source) end
end)

RegisterNetEvent('realrpg_clothing_designer:server:openForSelf', function()
    local src = source
    if not rcdHasAccess(src) then
        TriggerClientEvent('realrpg_clothing_designer:notify', src, 'not_authorized', 'error')
        return
    end
    TriggerClientEvent('realrpg_clothing_designer:client:openClothingDesigner', src)
end)

local function rcdOpenDesignerFor(src, target)
    target = tonumber(target or src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then return false, 'not_authorized' end
    if not target or not GetPlayerName(target) then return false, 'invalid_player' end
    if rcdGrantAccess(target) then
        TriggerClientEvent('realrpg_clothing_designer:client:openClothingDesigner', target)
        return true
    end
    return false, 'grant_failed'
end

RegisterCommand((Config.AdminCommandsRealRPG and Config.AdminCommandsRealRPG.open) or 'clothingdesigner', function(src, args)
    local target = tonumber(args and args[1]) or src
    local ok, err = rcdOpenDesignerFor(src, target)
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD', ok and ('Designer megnyitva: '..target) or ('Hiba: '..tostring(err)) } })
    else print(ok and ('[RCD] Designer opened for '..target) or ('[RCD] Error: '..tostring(err))) end
end, true)

RegisterCommand((Config.AdminCommandsRealRPG and Config.AdminCommandsRealRPG.stats) or 'clothingdesignerstats', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then return end
    local catalog = rcdTemplateCatalog(); local authCount = 0
    for _ in pairs(rcdAuthorizedPlayers) do authCount = authCount + 1 end
    local msg = ('templates=%s authorized=%s version=%s'):format(#catalog, authCount, Config.Version or '17.0.0')
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD Stats', msg } }) else print('[RCD Stats] '..msg) end
end, true)

RegisterCommand((Config.AdminCommandsRealRPG and Config.AdminCommandsRealRPG.rescan) or 'clothingdesignerrescan', function(src)
    if src > 0 and not IsPlayerAceAllowed(src, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then return end
    local catalog = rcdRescanTemplates()
    local msg = ('Template rescan kész. Catalog: %s db'):format(type(catalog) == 'table' and #catalog or 0)
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'RCD Rescan', msg } }) else print('[RCD Rescan] '..msg) end
end, true)

AddEventHandler('playerDropped', function() rcdRevokeAccess(source) end)


-- V15: current model editor addon export request from UI
ESX.RegisterServerCallback('realrpg_clothing_designer:exportCurrentAddon', function(source, cb, data)
    if not IsPlayerAceAllowed(source, Config.AdminPermission or 'realrpg.clothingdesigner.admin') then
        cb({ ok = false, error = 'not_authorized' })
        return
    end
    data = data or {}
    local exportName = tostring(data.template or ('realrpg_export_' .. os.time())):gsub('[^%w_%-]', '_')
    local payload = {
        name = exportName,
        author = GetPlayerName(source) or 'RealRPG',
        createdAt = os.date('%Y-%m-%d %H:%M:%S'),
        layers = data.layers or {},
        slots = data.slots or {},
        image = data.image,
        note = 'V15 model texture editor export payload. Final ytd/ydd writing is handled by the worker/stream integration.'
    }
    local folder = 'exports/' .. exportName
    SaveResourceFile(GetCurrentResourceName(), folder .. '/design.json', json.encode(payload), -1)
    cb({ ok = true, path = folder .. '/design.json' })
end)


-- V16: seed the exact jbib clothing files supplied by the user into the template catalog.
local function seedKnownClothingModels()
    if not Config.KnownClothingModels then return end
    for _, m in ipairs(Config.KnownClothingModels) do
        local fileName = m.ydd or m.fileName or (m.key .. '.ydd')
        local exists = MySQL.single.await('SELECT id FROM realrpg_clothing_templates WHERE file_name = ? LIMIT 1', { fileName })
        local meta = {
            source = 'Config.KnownClothingModels',
            ydd = m.ydd,
            ytd = m.ytd,
            prefixedYdd = m.prefixedYdd,
            prefixedYtd = m.prefixedYtd,
            txd = m.txd,
            txn = m.txn,
            componentId = m.componentId,
            note = 'Freemode clothing component mapping. Standalone 3D object preview requires exported object/worker output.'
        }
        if exists then
            MySQL.update.await('UPDATE realrpg_clothing_templates SET name = ?, file_type = ?, category = ?, gender = ?, preview_type = ?, component_key = ?, model_name = ?, texture_name = ?, drawable = ?, texture = ?, meta = ?, active = 1, updated_at = NOW() WHERE file_name = ?', {
                m.label or m.key, 'ydd', m.component or 'jbib', m.gender or 'male', m.previewType or 'jbib', m.component or 'jbib', m.key, m.ytd or '', m.drawable or 0, m.texture or 0, json.encode(meta), fileName
            })
        else
            MySQL.insert.await('INSERT INTO realrpg_clothing_templates (name, file_name, file_type, category, gender, preview_type, component_key, model_name, texture_name, drawable, texture, meta, active, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW())', {
                m.label or m.key, fileName, 'ydd', m.component or 'jbib', m.gender or 'male', m.previewType or 'jbib', m.component or 'jbib', m.key, m.ytd or '', m.drawable or 0, m.texture or 0, json.encode(meta)
            })
        end
    end
end

-- KnownClothingModels remains a manual compatibility helper; the V17 scanner only registers files that really exist.
