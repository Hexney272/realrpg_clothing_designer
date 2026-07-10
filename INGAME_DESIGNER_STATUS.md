# 🎨 RealRPG Clothing Designer - INGAME INTRACT-Style Implementation

## 📋 Áttekintés

Ez a projekt egy **teljes értékű in-game clothing designer**, ami hasonló funkcionalitást nyújt mint az INTRACT, DE teljes egészében **FiveM-ben fut**, böngésző helyett.

---

## ✅ MŰKÖDŐ FUNKCIÓK (2026-07-10)

### 1. **3D Live Preview ✅**
- Mannequin megjelenítés a preview ablakban
- Valós idejű 3D forgatás (Q/E vagy egér)
- Zoom funkció
- Kamera fókusz pontok (full, head, torso, legs, feet)
- Component visualization (jbib, pants, shoes, stb.)

### 2. **UV Texture Editor ✅**
- Canvas-based textúra szerkesztő
- Layer system:
  - Text layers (szín, fény, méret, forgatás)
  - Image layers (logók, matricák feltöltése)
  - Color layers (háttérszínek)
- Opacity control
- Layer sorrend változtatás
- Inspector panel

### 3. **Template Catalog ✅**
- YDD/YTD fájlok beolvasása
- Sablonok listázása
- Szűrés nem és komponens szerint
- Keresés fájlnév alapján
- Template betöltés a preview-ba

### 4. **Runtime Texture Preview ✅ (ÚJ!)**
- DUI-based texture renderelés
- Base64 PNG → Runtime TXD konverzió
- Live preview a 3D modellen
- Szerkesztett textúra valós időben megjelenik

### 5. **Database & Orders ✅**
- Design mentés MySQL-be
- Rendelési rendszer
- Admin jóváhagyási workflow
- Pending/Approved/Rejected státuszok
- Ruhatár (saved designs)

### 6. **Real Coin Integration ✅**
- RC fizetési rendszer
- Price konfiguráció
- Automatic payment handling

---

## ⚠️ FEJLESZTÉS ALATT

### 1. **YTD Export Worker** (következő)
```
Cél: Kész YTD fájl generálása a szerkesztett textúrából
├── PNG → DDS konverzió
├── YTD packaging
├── DXT1/3/5/BC7 compression
└── Stream-ready output
```

### 2. **Texture Bridge Optimization**
```
Cél: Gyorsabb texture betöltés és mentés
├── Cached texture extraction
├── Async file operations
└── Progress feedback
```

### 3. **AI-Assisted Design** (opcionális)
```
Cél: INTRACT-szerű AI support
├── Quick AI Fit gombok
├── Pattern generation
└── Color scheme suggestions
```

---

## 🎯 INTRACT vs REALRPG CLOTHING DESIGNER

| Funkció | INTRACT | RealRPG Designer |
|---------|---------|------------------|
| **Platform** | Browser-based | **IN-GAME (FiveM NUI)** |
| **3D Preview** | ✅ Yes | ✅ Yes |
| **UV Editor** | ✅ Yes | ✅ Yes (canvas-based) |
| **Live Texture** | ✅ Yes | ✅ Yes (DUI runtime) |
| **Template Catalog** | ✅ Yes | ✅ Yes (YDD/YTD scan) |
| **Approval Workflow** | ✅ Yes | ✅ Yes (admin panel) |
| **YTD Export** | ✅ Auto | ⚠️ In Progress |
| **Tebex Integration** | ✅ Required | ❌ Real Coin instead |
| **Auto-deployment** | ✅ txAdmin | ⚠️ Manual restart |
| **Player Experience** | External link | **Seamless in-game** |

---

## 📐 Architektúra

```
┌─────────────────────────────────────────────────┐
│           FiveM Client (Lua)                    │
├─────────────────────────────────────────────────┤
│  • Preview Ped Management                      │
│  • Camera Control                              │
│  • DUI Runtime Texture                         │
│  • Component Variation                         │
└────────────┬────────────────────────────────────┘
             │
             │ NUI Callbacks
             ▼
┌─────────────────────────────────────────────────┐
│           NUI (HTML/CSS/JS)                     │
├─────────────────────────────────────────────────┤
│  • UV Canvas Editor                            │
│  • Layer Management                            │
│  • Template Browser                            │
│  • Admin Panel                                 │
└────────────┬────────────────────────────────────┘
             │
             │ HTTP Fetch
             ▼
┌─────────────────────────────────────────────────┐
│           FiveM Server (Lua)                    │
├─────────────────────────────────────────────────┤
│  • ESX Integration                             │
│  • MySQL Database                              │
│  • Order Management                            │
│  • Payment Processing                          │
└────────────┬────────────────────────────────────┘
             │
             │ File System
             ▼
┌─────────────────────────────────────────────────┐
│         Worker/Bridge (Optional)                │
├─────────────────────────────────────────────────┤
│  • YTD Export                                  │
│  • DDS Conversion                              │
│  • Texture Extraction                          │
└─────────────────────────────────────────────────┘
```

---

## 🚀 Használati Útmutató

### **Játékos perspektíva:**

1. **Designer megnyitása:**
   ```
   /clothingdesigner  vagy  Clothing Shop interaction
   ```

2. **Template választás:**
   - Bal oldali menü: "Sablonok"
   - Válassz jbib/pants/shoes template-et
   - Kattints "Betöltés" gombra

3. **Textúra szerkesztése:**
   - UV Editor ablakban rajzolj
   - Adj hozzá szöveget, képet, színeket
   - Layer rendszer az inspector-ban

4. **Live Preview:**
   - A 3D ablakban látod a mannequin-t
   - Szerkesztés közben valós időben frissül
   - Q/E forgatás, egérgörgő zoom

5. **Mentés/Rendelés:**
   - "Mentés" → Ruhatárba kerül
   - "Megrendelés" → Admin jóváhagyásra
   - RC fizetés automatikus

### **Admin perspektíva:**

1. **Admin panel:**
   ```
   /clothingadmin
   ```

2. **Pending rendelések:**
   - Látod a játékos dizájnját
   - Preview a 3D ablakban
   - Approve/Reject gombok

3. **Item kiadás:**
   - Approved után automatikus ox_inventory item
   - Vagy manual delivery opcióval

---

## 🔧 Technikai Részletek

### **DUI Runtime Texture:**
```lua
-- Create DUI for custom texture
local runtimeDui = CreateDui('about:blank', 1024, 1024)
local runtimeTxd = CreateRuntimeTxd('realrpg_runtime_txd')
local duiHandle = GetDuiHandle(runtimeDui)
local txdHandle = CreateRuntimeTextureFromDuiHandle(runtimeTxd, 'txn', duiHandle)

-- Update with base64 PNG
local htmlContent = '<html><body><img src="data:image/png;base64,..."></body></html>'
SetDuiUrl(runtimeDui, 'data:text/html;charset=utf-8,' .. htmlContent)
```

### **Component Application:**
```lua
-- Apply jbib component to preview ped
SetPedComponentVariation(previewPed, 11, drawable, texture, 2)

-- Camera focus on torso
local cfg = Config.Focus['torso']
local camCoords = GetOffsetFromEntityInWorldCoords(ped, cfg.offset)
PointCamAtCoord(cam, pointCoords)
```

### **Database Schema:**
```sql
CREATE TABLE realrpg_clothing_designs (
  id INT PRIMARY KEY AUTO_INCREMENT,
  identifier VARCHAR(80),
  name VARCHAR(80),
  gender VARCHAR(20),
  preview_type VARCHAR(40),
  skin LONGTEXT,
  components LONGTEXT,
  props LONGTEXT,
  canvas LONGTEXT,  -- UV editor layers
  image MEDIUMTEXT, -- Preview screenshot
  created_at TIMESTAMP
);

CREATE TABLE realrpg_clothing_orders (
  id INT PRIMARY KEY AUTO_INCREMENT,
  design_id INT,
  status VARCHAR(30), -- pending/approved/rejected
  metadata LONGTEXT,  -- Full design payload
  price INT,
  created_at TIMESTAMP
);
```

---

## 📝 KÖVETKEZŐ LÉPÉSEK

### **Prioritás 1: YTD Export Worker**
```lua
-- server/texture_bridge.lua
function exportDesignAsYTD(designId, outputPath)
  -- 1. Load design from DB
  local design = getDesign(designId)
  
  -- 2. Get canvas image (base64 PNG)
  local pngData = design.canvas.image
  
  -- 3. Convert PNG → DDS
  local ddsData = convertPngToDds(pngData, 'DXT5')
  
  -- 4. Package into YTD
  local ytdData = packageYTD({
    txd = design.canvas.template.txdName,
    txn = design.canvas.template.textureName,
    dds = ddsData
  })
  
  -- 5. Save to stream folder
  SaveResourceFile(GetCurrentResourceName(), outputPath, ytdData, -1)
  
  return true
end
```

### **Prioritás 2: Auto-Deployment**
```lua
-- Auto-restart resource after new YTD export
function triggerResourceRefresh()
  ExecuteCommand('refresh')
  Wait(1000)
  ExecuteCommand('restart realrpg_clothing_designer')
end
```

### **Prioritás 3: Texture Caching**
```lua
-- Cache extracted textures for faster load
local textureCache = {}

function getExtractedTexture(ytdPath, textureName)
  local key = ytdPath .. ':' .. textureName
  if textureCache[key] then
    return textureCache[key]
  end
  
  local pngData = extractTextureFromYTD(ytdPath, textureName)
  textureCache[key] = pngData
  return pngData
end
```

---

## 🎉 ÖSSZEFOGLALÁS

A **RealRPG Clothing Designer** jelenleg egy **teljesen működő in-game clothing design tool**, ami:

✅ **3D live preview**-val rendelkezik  
✅ **UV texture editor**-t biztosít  
✅ **Runtime texture** megjelenítést támogat  
✅ **Admin workflow**-t implementál  
✅ **Database** integrációt tartalmaz  

A **fő különbség az INTRACT-hez képest**:
- ❌ Nem Tebex-based (Real Coin helyette)
- ❌ Nem böngészőben fut (FiveM NUI)
- ⚠️ YTD export még fejlesztés alatt

**De cserébe:**
- ✅ **Seamless in-game experience**
- ✅ **Nincs külső link**
- ✅ **Teljes ESX/ox integráció**
- ✅ **Valós időben látod a karaktereden**

---

## 📞 Support

Ha kérdésed van vagy hibát találsz:
1. Ellenőrizd az F8 console-t (`Config.Debug = true`)
2. Nézd meg a `TROUBLESHOOTING_V12.md` fájlt
3. Futtasd a `/rcd_troubleshoot` parancsot

**Version:** 17.3.0  
**Last Updated:** 2026-07-10  
**Status:** ✅ Production Ready (YTD export development in progress)
