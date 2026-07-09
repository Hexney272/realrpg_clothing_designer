(() => {
  const $ = (id) => document.getElementById(id);
  const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).then(r => r.json()).catch(err => ({ ok: false, error: String(err) }));

  const editor = {
    bg: null,
    layers: [],
    selected: -1,
    lastExtract: null,
    canvas: null,
    ctx: null
  };

  function safeJson(value) {
    try { return JSON.parse(value || '{}'); } catch { return {}; }
  }

  function templateFromInputs() {
    const extra = safeJson($('rcdTemplateJson')?.value);
    return {
      ...extra,
      ytdPath: $('rcdYtdPath')?.value || extra.ytdPath || extra.templateYtd || '',
      textureName: $('rcdTextureName')?.value || extra.textureName || extra.txn || '',
      txdName: $('rcdOriginalTxd')?.value || extra.txdName || extra.txd || '',
      originalTxn: $('rcdOriginalTxn')?.value || extra.originalTxn || extra.textureName || extra.txn || ''
    };
  }

  function setStatus(text, type = 'info') {
    const el = $('rcdBridgeStatus');
    if (!el) return;
    el.textContent = text;
    el.dataset.type = type;
  }

  function draw() {
    const c = editor.canvas;
    const ctx = editor.ctx;
    if (!c || !ctx) return;
    ctx.clearRect(0, 0, c.width, c.height);
    ctx.fillStyle = '#111827';
    ctx.fillRect(0, 0, c.width, c.height);
    if (editor.bg) ctx.drawImage(editor.bg, 0, 0, c.width, c.height);

    for (const layer of editor.layers) {
      ctx.save();
      ctx.globalAlpha = Number(layer.opacity ?? 1);
      if (layer.type === 'color') {
        ctx.fillStyle = layer.color || '#8b5cf6';
        ctx.fillRect(0, 0, c.width, c.height);
      }
      if (layer.type === 'text') {
        ctx.font = `${layer.size || 54}px Inter, Segoe UI, Arial, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = layer.color || '#ffffff';
        ctx.shadowColor = layer.glow || layer.color || '#8b5cf6';
        ctx.shadowBlur = layer.glowBlur || 14;
        ctx.fillText(layer.text || 'REALRPG', layer.x || c.width / 2, layer.y || c.height / 2);
      }
      if (layer.type === 'image' && layer.img) {
        ctx.drawImage(layer.img, layer.x || 0, layer.y || 0, layer.w || c.width, layer.h || c.height);
      }
      ctx.restore();
    }
  }

  function renderLayers() {
    const box = $('rcdLayerList');
    if (!box) return;
    box.innerHTML = '';
    editor.layers.forEach((layer, index) => {
      const row = document.createElement('div');
      row.className = 'rcd-layer' + (index === editor.selected ? ' active' : '');
      row.innerHTML = `<b>${layer.label || layer.type}</b><span>${Math.round((layer.opacity ?? 1) * 100)}%</span><button>×</button>`;
      row.onclick = () => { editor.selected = index; renderLayers(); };
      row.querySelector('button').onclick = (e) => {
        e.stopPropagation();
        editor.layers.splice(index, 1);
        if (editor.selected === index) editor.selected = -1;
        draw(); renderLayers();
      };
      box.appendChild(row);
    });
  }

  function addTextLayer() {
    editor.layers.push({
      type: 'text',
      label: 'Felirat',
      text: $('rcdLayerText').value || 'REALRPG',
      color: $('rcdLayerColor').value || '#ffffff',
      glow: $('rcdLayerGlow').value || '#8b5cf6',
      size: Number($('rcdLayerSize').value || 54),
      opacity: Number($('rcdLayerOpacity').value || 100) / 100,
      x: 256,
      y: 256
    });
    editor.selected = editor.layers.length - 1;
    draw(); renderLayers();
  }

  function addColorLayer() {
    editor.layers.push({
      type: 'color',
      label: 'Szín overlay',
      color: $('rcdLayerColor').value || '#8b5cf6',
      opacity: Number($('rcdLayerOpacity').value || 25) / 100
    });
    editor.selected = editor.layers.length - 1;
    draw(); renderLayers();
  }

  function toDataUrl() {
    draw();
    return editor.canvas.toDataURL('image/png');
  }

  function downloadPng() {
    const a = document.createElement('a');
    a.href = toDataUrl();
    a.download = 'realrpg_texture.png';
    a.click();
  }

  function loadImage(src) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = reject;
      img.src = src;
    });
  }

  async function extractTexture() {
    setStatus('Texture kinyerése...', 'info');
    const res = await post('extractTemplateTexture', { template: templateFromInputs() });
    if (!res.ok) { setStatus(res.error || 'Nem sikerült kinyerni.', 'error'); return; }
    editor.lastExtract = res;
    editor.bg = await loadImage(res.dataUri || res.imageData || res.pngDataUri);
    editor.layers = [];
    editor.selected = -1;
    if (res.textureName && !$('rcdTextureName').value) $('rcdTextureName').value = res.textureName;
    if (res.textureName && !$('rcdOriginalTxn').value) $('rcdOriginalTxn').value = res.textureName;
    draw(); renderLayers();
    setStatus(`Kinyerve: ${res.textureName || 'diffuse texture'}`, 'success');
  }

  async function injectTexture() {
    setStatus('Végleges .ytd export...', 'info');
    const name = $('rcdOutputName').value || '';
    const res = await post('injectTemplateTexture', {
      template: templateFromInputs(),
      imageData: toDataUrl(),
      outputName: name
    });
    if (!res.ok) { setStatus(res.error || 'Nem sikerült exportálni.', 'error'); return; }
    setStatus(`Export kész: ${res.outputPath || res.outputFile || 'stream .ytd'}`, 'success');
  }

  async function liveTexture() {
    setStatus('Élő preview frissítése...', 'info');
    const t = templateFromInputs();
    const res = await post('applyLiveTexture', {
      template: t,
      imageData: toDataUrl(),
      originalTxd: t.txdName,
      originalTxn: t.originalTxn || t.textureName
    });
    setStatus(res.ok ? 'Élő preview frissítve.' : (res.error || 'Live preview hiba.'), res.ok ? 'success' : 'error');
  }

  async function checkStatus() {
    setStatus('Worker ellenőrzése...', 'info');
    const res = await post('bridgeStatus');
    setStatus(res.ok ? `Worker OK · bridge=${res.bridgeFound ? 'ok' : 'missing'} · texconv=${res.texconvFound ? 'ok' : 'missing'}` : (res.error || 'Worker nem elérhető'), res.ok ? 'success' : 'error');
  }

  function buildEditor() {
    const panel = $('canvasPanel');
    if (!panel || $('rcdTextureEditor')) return;
    const wrap = document.createElement('div');
    wrap.id = 'rcdTextureEditor';
    wrap.className = 'rcd-editor';
    wrap.innerHTML = `
      <div class="rcd-title"><b>Texture Bridge Editor</b><span id="rcdBridgeStatus">Worker nincs ellenőrizve</span></div>
      <label>Template .ytd útvonal</label>
      <input id="rcdYtdPath" placeholder="templates/cloth_templates/male/jbib/jbib_diff_000_a_uni.ytd" />
      <div class="double">
        <div><label>Texture név</label><input id="rcdTextureName" placeholder="jbib_diff_000_a_uni" /></div>
        <div><label>Output név</label><input id="rcdOutputName" placeholder="realrpg_custom_jbib_001.ytd" /></div>
      </div>
      <div class="double">
        <div><label>Live original TXD</label><input id="rcdOriginalTxd" placeholder="mp_m_freemode_01_mp_m_realrpg" /></div>
        <div><label>Live original TXN</label><input id="rcdOriginalTxn" placeholder="jbib_diff_000_a_uni" /></div>
      </div>
      <label>Extra template JSON</label>
      <textarea id="rcdTemplateJson" placeholder='{"component":"jbib","gender":"male"}'></textarea>
      <div class="rcd-actions">
        <button id="rcdStatusBtn">Worker teszt</button>
        <button id="rcdExtractBtn">PNG kinyerés</button>
        <button id="rcdLiveBtn">Élő 3D preview</button>
        <button id="rcdInjectBtn">Végleges .ytd export</button>
      </div>
      <canvas id="rcdCanvas" width="512" height="512"></canvas>
      <div class="rcd-layer-tools">
        <input id="rcdLayerText" placeholder="REALRPG" />
        <input id="rcdLayerColor" type="color" value="#ffffff" />
        <input id="rcdLayerGlow" type="color" value="#8b5cf6" />
        <input id="rcdLayerSize" type="number" value="54" min="8" max="160" />
        <input id="rcdLayerOpacity" type="number" value="100" min="1" max="100" />
      </div>
      <div class="rcd-actions small">
        <button id="rcdAddTextBtn">Text réteg</button>
        <button id="rcdAddColorBtn">Szín overlay</button>
        <button id="rcdDownloadBtn">PNG letöltés</button>
        <button id="rcdClearBtn">Live törlés</button>
      </div>
      <div id="rcdLayerList"></div>
    `;
    panel.appendChild(wrap);

    editor.canvas = $('rcdCanvas');
    editor.ctx = editor.canvas.getContext('2d');
    draw();
    $('rcdStatusBtn').onclick = checkStatus;
    $('rcdExtractBtn').onclick = extractTexture;
    $('rcdInjectBtn').onclick = injectTexture;
    $('rcdLiveBtn').onclick = liveTexture;
    $('rcdAddTextBtn').onclick = addTextLayer;
    $('rcdAddColorBtn').onclick = addColorLayer;
    $('rcdDownloadBtn').onclick = downloadPng;
    $('rcdClearBtn').onclick = async () => { await post('clearLiveTextures'); setStatus('Live texture csere törölve.', 'info'); };
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', buildEditor);
  else buildEditor();
})();
