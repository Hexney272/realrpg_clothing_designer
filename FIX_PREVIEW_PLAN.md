# 🔧 3D Preview Javítási Terv

## ❌ PROBLÉMA

A képeden látható problémák:
1. **Bal oldali 3D preview ablak ÜRES/FEKETE**
2. **Jobb oldali UV editor ARC-ot mutat** torso helyett
3. A mannequin nem látszik

## 🎯 MI A HELYES MŰKÖDÉS?

Az INTRACT és hasonló rendszerek **SCREENSHOT-based preview**-t használnak:

```
┌──────────────────────────────┐
│   FiveM Client (Lua)         │
│                              │
│  ┌──────────────────────┐   │
│  │  3D Preview Ped      │   │
│  │  + Camera            │   │
│  │  + Render to screen  │   │
│  └──────────────────────┘   │
│           │                  │
│           ├─ Screenshot      │
│           │  (base64 PNG)    │
│           ▼                  │
│  ┌──────────────────────┐   │
│  │  NUI Display         │   │
│  │  <img src="data..."> │   │
│  └──────────────────────┘   │
└──────────────────────────────┘
```

**FONTOS:** Az NUI **NEM** tudja közvetlenül renderelni a 3D world-öt!

## 📊 JELENLEGI ARCHITEKTÚRA (ROSSZ)

```lua
-- client/main.lua - MOSTANI
function setupPreview()
  previewPed = createPreviewPed()
  focusCamera('torso')
  RenderScriptCams(true, true, 250, true, true)
end

-- ❌ PROBLÉMA: A kamera render NEM jelenik meg az NUI-ban
-- Az NUI csak HTML/CSS/JS, nem tudja látni a game world-öt
```

## ✅ HELYES MEGOLDÁS

### 1. **DUI-based Preview (Ajánlott)**

A FiveM **DUI** (Drawing User Interface) segítségével tudjuk a 3D render-t az NUI-ba küldeni:

```lua
-- HELYES IMPLEMENTÁCIÓ
local previewDui = nil
local previewTexture = nil

function createPreviewWithDUI()
  -- 1. Létrehozunk egy DUI objektumot
  if not previewDui then
    previewDui = CreateDui('about:blank', 512, 512)
  end
  
  -- 2. Render Target létrehozása
  local renderTarget = CreateNamedRenderTargetForModel('preview_rt', GetHashKey('prop_dummy'))
  
  -- 3. Kamera render a DUI-ra
  SetTextRenderId(renderTarget)
  RenderScriptCams(true, false, 0, true, false)
  SetTextRenderId(GetDefaultScriptRendertargetRenderId())
  
  -- 4. DUI frissítése screenshot-tal
  local duiHandle = GetDuiHandle(previewDui)
  -- ... screenshot logic
end
```

### 2. **Screenshot-based Preview (Egyszerűbb)**

A `screenshot-basic` resource-t használva:

```lua
-- client/main.lua
function updatePreviewScreenshot()
  if not previewPed or not DoesEntityExist(previewPed) then return end
  
  -- Export screenshot-basic resource
  exports['screenshot-basic']:requestScreenshot({
    encoding = 'png',
    quality = 0.9
  }, function(dataUrl)
    -- Küldd az NUI-nak
    SendNUIMessage({
      action = 'updatePreviewImage',
      imageData = dataUrl
    })
  end)
end

-- Frissítsd 100ms-enként vagy layer change-re
CreateThread(function()
  while true do
    if uiOpen then
      updatePreviewScreenshot()
    end
    Wait(100)
  end
end)
```

### 3. **NUI HTML módosítás**

```html
<!-- html/index.html -->
<div class="preview-window" id="previewWindow">
  <!-- ❌ RÉGI: Üres div (nem lehet bele 3D render) -->
  
  <!-- ✅ ÚJ: Image elem screenshot-hoz -->
  <img id="preview3DImage" src="" style="width:100%;height:100%;object-fit:contain;">
  
  <div class="preview-grid"></div>
  <div class="scan-line"></div>
  <div class="frame-corners"></div>
  <!-- ... -->
</div>
```

### 4. **NUI JavaScript módosítás**

```javascript
// html/uv_workbench.js
window.addEventListener('message', (e) => {
  const d = e.data || {};
  
  if (d.action === 'updatePreviewImage') {
    const img = document.getElementById('preview3DImage');
    if (img) {
      img.src = d.imageData; // Base64 PNG
    }
  }
});
```

## 🎬 TELJES IMPLEMENTÁCIÓ

### **LÉPÉS 1: Lua screenshot handler**

```lua
-- client/main.lua HOZZÁADNI:

local previewUpdateInterval = 150 -- ms
local lastPreviewUpdate = 0

function capturePreviewScreenshot()
  if not GetResourceState('screenshot-basic') == 'started' then
    dbg('screenshot-basic nincs elindítva')
    return
  end
  
  local now = GetGameTimer()
  if now - lastPreviewUpdate < previewUpdateInterval then return end
  lastPreviewUpdate = now
  
  if not previewPed or not DoesEntityExist(previewPed) then return end
  
  exports['screenshot-basic']:requestScreenshot({
    encoding = 'png',
    quality = 0.85,
    targetFormat = 'dataUrl'
  }, function(dataUrl)
    SendNUIMessage({
      action = 'updatePreviewImage',
      imageData = dataUrl
    })
  end)
end

-- Automatikus frissítés thread
CreateThread(function()
  while true do
    if uiOpen and previewPed then
      capturePreviewScreenshot()
    end
    Wait(previewUpdateInterval)
  end
end)

-- Manual trigger layer change-nél
RegisterNUICallback('layerChanged', function(data, cb)
  Wait(50)
  capturePreviewScreenshot()
  cb({ ok = true })
end)
```

### **LÉPÉS 2: HTML módosítás**

```html
<!-- FIND: -->
<div class="preview-window">

<!-- REPLACE WITH: -->
<div class="preview-window">
  <img id="preview3DImage" 
       src="data:image/png;base64,iVBORw0KG..." 
       style="position:absolute;width:100%;height:100%;object-fit:contain;pointer-events:none;z-index:1;"
       alt="3D Preview">
```

### **LÉPÉS 3: JavaScript handler**

```javascript
// uv_workbench.js-ben a window.addEventListener('message') részbe:

if (d.action === 'updatePreviewImage') {
  const img = $('#preview3DImage') || document.getElementById('preview3DImage');
  if (img && d.imageData) {
    img.src = d.imageData;
    img.style.display = 'block';
  }
}

// Layer változásnál trigger:
function draw() {
  // ... existing code ...
  
  // Notify Lua about layer change
  post('layerChanged', {});
}
```

## 🎯 PRIORITÁSOK

1. **Screenshot-basic integráció** ✅ (Egyszerű, működik)
2. **Auto-refresh logic** ✅ (100-150ms interval)
3. **HTML img elem** ✅ (Befogadja a screenshot-ot)
4. **Layer change trigger** ✅ (Manuális frissítés szerkesztéskor)

## ⚠️ FONTOS TUDNIVALÓK

### **Miért NEM működik a mostani?**

```lua
-- ❌ ROSSZ
RenderScriptCams(true, true, 250, true, true)
-- Ez CSAK a játék képernyőjén renderel, NEM az NUI-ban!
```

### **Miért kell screenshot?**

- Az NUI egy **Chromium browser embed**
- Nem tudja közvetlenül renderelni a GTA world-öt
- **Screenshot → Base64 PNG → <img> elem** a helyes út

### **Performance**

- 150ms refresh = 6-7 FPS (elég smooth)
- 0.85 quality PNG = ~50-100KB
- Base64 overhead: +33%
- Összesen: ~70-130KB/frame

## 📦 KÖVETKEZŐ COMMIT

```bash
git add client/main.lua html/index.html html/uv_workbench.js
git commit -m "feat: Screenshot-based 3D preview implementation

- screenshot-basic integráció
- Auto-refresh 150ms interval
- HTML img elem hozzáadása
- NUI message handler
- Layer change trigger
- Preview most látható az NUI-ban"
```
