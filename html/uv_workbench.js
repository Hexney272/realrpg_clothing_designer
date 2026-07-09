(() => {
  const $ = (id) => document.getElementById(id);
  const qsa = (sel) => Array.from(document.querySelectorAll(sel));
  const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data)
  }).then(r => r.json()).catch(err => ({ ok: false, error: String(err) }));

  const componentMap = {
    head: { id: 1, key: 'mask_1', tex: 'mask_2', focus: 'head' },
    accs: { id: 7, key: 'chain_1', tex: 'chain_2', focus: 'head' },
    decl: { id: 10, key: 'decals_1', tex: 'decals_2', focus: 'torso' },
    feet: { id: 6, key: 'shoes_1', tex: 'shoes_2', focus: 'feet' },
    hand: { id: 3, key: 'arms', tex: 'arms_2', focus: 'torso' },
    jbib: { id: 11, key: 'torso_1', tex: 'torso_2', focus: 'torso' },
    lowr: { id: 4, key: 'pants_1', tex: 'pants_2', focus: 'legs' },
    task: { id: 5, key: 'bags_1', tex: 'bags_2', focus: 'torso' },
    uppr: { id: 8, key: 'tshirt_1', tex: 'tshirt_2', focus: 'torso' }
  };

  const state = {
    visible: false,
    catalog: [], filtered: [], template: null,
    layers: [], selectedLayer: -1,
    canvas: null, ctx: null, bg: null,
    dragging: false, dragStart: null, history: [], redo: [], zoom: 1,
    mode: 'ped_fallback'
  };

  function setStatus(text) { $('bridgeStatus').textContent = text; }
  function safeJson(value) { try { return JSON.parse(value || '{}'); } catch { return {}; } }
  function activeTemplatePayload() {
    const extra = safeJson($('templateJson').value);
    const t = state.template || {};
    const textureName = $('originalTxn').value || extra.textureName || t.texture_name || t.textureName || t.name || '';
    return {
      ...extra,
      id: t.id,
      name: t.name,
      gender: t.gender,
      component: t.component_key || t.category,
      category: t.category,
      drawable: Number(t.drawable || 0),
      texture: Number(t.texture || 0),
      templatePath: t.template_path || t.templatePath,
      yddPath: (t.file_type === 'ydd' ? t.template_path : undefined) || extra.yddPath,
      ytdPath: (t.file_type === 'ytd' ? t.template_path : undefined) || extra.ytdPath || extra.templateYtd,
      textureName,
      originalTxn: textureName,
      txdName: $('originalTxd').value || extra.txdName || extra.txd || ''
    };
  }
  function fileLabel(t) { return `${t.gender || ''}/${t.category || t.component_key || ''}/${t.file_name || t.name || ''}`; }

  function pushHistory() {
    if (!state.canvas) return;
    try {
      state.history.push(JSON.stringify({ layers: state.layers.map(l => ({...l, img: undefined, imgSrc: l.imgSrc || null})) }));
      if (state.history.length > 30) state.history.shift();
      state.redo = [];
    } catch {}
  }
  function restoreSnapshot(s) {
    if (!s) return;
    const data = JSON.parse(s);
    state.layers = data.layers || [];
    state.selectedLayer = Math.min(state.selectedLayer, state.layers.length - 1);
    Promise.all(state.layers.filter(l => l.imgSrc).map(l => loadImage(l.imgSrc).then(img => { l.img = img; }).catch(()=>{}))).then(() => { draw(); renderLayers(); syncInspector(); });
  }

  function draw() {
    const c = state.canvas, ctx = state.ctx;
    if (!c || !ctx) return;
    ctx.clearRect(0,0,c.width,c.height);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0,0,c.width,c.height);
    if (state.bg) ctx.drawImage(state.bg,0,0,c.width,c.height);
    for (const layer of state.layers) {
      if (layer.hidden) continue;
      ctx.save(); ctx.globalAlpha = Number(layer.opacity ?? 1);
      if (layer.type === 'color') { ctx.fillStyle = layer.color || '#8b5cf6'; ctx.fillRect(0,0,c.width,c.height); }
      if (layer.type === 'text') {
        ctx.font = `900 ${layer.size || 64}px Inter, Segoe UI, Arial, sans-serif`;
        ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.fillStyle = layer.color || '#fff'; ctx.shadowColor = layer.glow || layer.color || '#8b5cf6'; ctx.shadowBlur = 18;
        ctx.fillText(layer.text || 'REALRPG', layer.x || c.width/2, layer.y || c.height/2);
      }
      if (layer.type === 'image' && layer.img) ctx.drawImage(layer.img, layer.x || 0, layer.y || 0, layer.w || 300, layer.h || 300);
      ctx.restore();
    }
    const sel = state.layers[state.selectedLayer];
    if (sel && !sel.hidden && (sel.type === 'text' || sel.type === 'image')) {
      ctx.save(); ctx.strokeStyle = '#8cff2e'; ctx.lineWidth = 2; ctx.setLineDash([8,6]);
      const x = (sel.x || c.width/2) - (sel.type === 'text' ? 180 : 0);
      const y = (sel.y || c.height/2) - (sel.type === 'text' ? (sel.size || 64) : 0);
      const w = sel.type === 'text' ? 360 : (sel.w || 300); const h = sel.type === 'text' ? (sel.size || 64) * 1.35 : (sel.h || 300);
      ctx.strokeRect(x,y,w,h); ctx.restore();
    }
    $('emptyCanvas').classList.toggle('hidden', !!state.bg);
  }

  function canvasDataUrl() { draw(); return state.canvas.toDataURL('image/png'); }
  function loadImage(src) { return new Promise((resolve,reject)=>{ const img = new Image(); img.onload=()=>resolve(img); img.onerror=reject; img.src=src; }); }
  function download(name, href) { const a = document.createElement('a'); a.href = href; a.download = name; a.click(); }

  function renderLayers() {
    $('layerCount').textContent = String(state.layers.length);
    const box = $('layerList'); box.innerHTML = '';
    state.layers.forEach((l,i)=>{
      const row = document.createElement('div'); row.className = 'layer' + (i === state.selectedLayer ? ' active' : '');
      row.innerHTML = `<div class="layer-head"><b>${l.label || l.type}</b><span>${Math.round((l.opacity ?? 1)*100)}%</span></div><span>${l.type}</span>`;
      row.onclick = () => { state.selectedLayer = i; renderLayers(); syncInspector(); draw(); };
      box.appendChild(row);
    });
  }

  function syncInspector() {
    const l = state.layers[state.selectedLayer];
    $('layerText').value = l && l.type === 'text' ? (l.text || '') : '';
    $('layerColor').value = l ? (l.color || '#ffffff') : '#ffffff';
    $('layerGlow').value = l ? (l.glow || '#8b5cf6') : '#8b5cf6';
    $('layerOpacity').value = l ? Math.round((l.opacity ?? 1)*100) : 100;
    $('layerSize').value = l && l.size ? l.size : 64;
  }
  function updateSelectedFromInspector() {
    const l = state.layers[state.selectedLayer]; if (!l) return;
    if (l.type === 'text') l.text = $('layerText').value || 'REALRPG';
    l.color = $('layerColor').value; l.glow = $('layerGlow').value; l.opacity = Number($('layerOpacity').value)/100;
    if (l.type === 'text') l.size = Number($('layerSize').value);
    renderLayers(); draw();
  }

  function addText() { pushHistory(); state.layers.push({ type:'text', label:'RealRPG Text', text:'REALRPG', color:'#ffffff', glow:'#8b5cf6', opacity:1, size:64, x:512, y:512 }); state.selectedLayer = state.layers.length-1; renderLayers(); syncInspector(); draw(); }
  function addColor() { pushHistory(); state.layers.push({ type:'color', label:'Color Overlay', color:'#8b5cf6', opacity:.22 }); state.selectedLayer = state.layers.length-1; renderLayers(); syncInspector(); draw(); }
  async function addImage(file) { if (!file) return; pushHistory(); const src = await fileToDataUrl(file); const img = await loadImage(src); state.layers.push({ type:'image', label:file.name || 'Image', img, imgSrc:src, opacity:1, x:256, y:256, w:360, h:360 }); state.selectedLayer = state.layers.length-1; renderLayers(); syncInspector(); draw(); }
  function fileToDataUrl(file) { return new Promise(resolve => { const r = new FileReader(); r.onload = () => resolve(r.result); r.readAsDataURL(file); }); }

  function renderTemplates() {
    const gender = $('genderFilter').value, comp = $('componentFilter').value;
    state.filtered = state.catalog.filter(t => (gender === 'all' || t.gender === gender) && (comp === 'all' || t.category === comp || t.component_key === comp));
    const box = $('templateList'); box.innerHTML = '';
    state.filtered.forEach((t)=>{
      const row = document.createElement('div'); row.className = 'template' + (state.template && state.template.id === t.id ? ' active' : '');
      row.innerHTML = `<div class="template-head"><b>${t.name || t.file_name}</b><span>${t.file_type || ''}</span></div><span>${t.gender || ''} · ${t.category || t.component_key || ''} · drawable ${t.drawable || 0}/${t.texture || 0}</span><small>${t.template_path || t.file_name || ''}</small>`;
      row.onclick = () => selectTemplate(t);
      box.appendChild(row);
    });
  }

  async function selectTemplate(t) {
    state.template = t; renderTemplates();
    $('activeTemplateText').textContent = 'Template: ' + fileLabel(t);
    $('editorTitle').textContent = 'EDITOR ' + (t.name || t.file_name || 'template');
    if (!$('originalTxn').value) $('originalTxn').value = t.texture_name || t.name || '';
    if (!$('outputName').value) $('outputName').value = `realrpg_custom_${(t.name || t.file_name || 'texture').replace(/\.[^.]+$/,'')}.ytd`;
    const map = componentMap[t.component_key || t.category];
    if (map) {
      await post('setComponent', { id: map.id, key: map.key, tex: map.tex, drawable: Number(t.drawable || 0), texture: Number(t.texture || 0), focus: map.focus });
      await post('focus', { focus: map.focus });
    }
  }

  async function loadCatalog(rescan=false) {
    setStatus(rescan ? 'Template rescan...' : 'Template lista betöltése...');
    let res = await post(rescan ? 'rescanTemplateCatalog' : 'getTemplateCatalog', {});
    if (!res.ok) { setStatus(res.error || 'Template lista hiba'); return; }

    state.catalog = res.catalog || [];

    // First open quality-of-life: if the DB catalog is empty, run a real server-side rescan
    // instead of showing an empty Templates tab and forcing the user to know the console command.
    if (!rescan && state.catalog.length === 0) {
      setStatus('Nincs template a DB-ben, automatikus rescan...');
      const scan = await post('rescanTemplateCatalog', {});
      if (scan.ok) {
        res = scan;
        state.catalog = scan.catalog || [];
      } else {
        setStatus(scan.error || 'Template rescan hiba');
        return;
      }
    }

    renderTemplates();
    const scanned = res.rescan && typeof res.rescan.scanned !== 'undefined' ? ` · scanned ${res.rescan.scanned}, registered ${res.rescan.registered || 0}, skipped ${res.rescan.skipped || 0}` : '';
    setStatus(`Templates: ${state.catalog.length}${scanned}`);
  }

  async function extractTexture() {
    if (!state.template) { setStatus('Válassz template-et.'); return; }
    setStatus('UV textúra kinyerése...');
    const res = await post('extractTemplateTexture', { template: activeTemplatePayload() });
    if (!res.ok) { setStatus(res.error || 'Extract hiba'); return; }
    const img = await loadImage(res.dataUri || res.imageData || res.pngDataUri);
    state.bg = img; state.layers = []; state.selectedLayer = -1; state.history = []; state.redo = [];
    if (!$('originalTxn').value && res.textureName) $('originalTxn').value = res.textureName;
    draw(); renderLayers(); syncInspector();
    setStatus('UV textúra betöltve: ' + (res.textureName || 'diffuse'));
  }
  async function livePreview() {
    if (!state.bg) { setStatus('Előbb töltsd be a textúrát.'); return; }
    const t = activeTemplatePayload();
    const res = await post('applyLiveTexture', { template: t, imageData: canvasDataUrl(), originalTxd: t.txdName, originalTxn: t.originalTxn || t.textureName });
    setStatus(res.ok ? 'Live 3D preview frissítve.' : (res.error || 'Live preview hiba'));
  }
  async function exportYtd() {
    if (!state.bg) { setStatus('Előbb töltsd be a textúrát.'); return; }
    setStatus('Export .YTD...');
    const res = await post('injectTemplateTexture', { template: activeTemplatePayload(), imageData: canvasDataUrl(), outputName: $('outputName').value || undefined });
    setStatus(res.ok ? `Export kész: ${res.outputPath || res.outputFile || 'stream'}` : (res.error || 'Export hiba'));
  }
  async function status() { const res = await post('bridgeStatus'); setStatus(res.ok ? `Worker OK · bridge=${res.bridgeFound?'OK':'MISSING'} · texconv=${res.texconvFound?'OK':'MISSING'}` : (res.error || 'Worker hiba')); }

  function initCanvasInput() {
    state.canvas = $('uvCanvas'); state.ctx = state.canvas.getContext('2d'); draw();
    state.canvas.addEventListener('mousedown', e => { const l = state.layers[state.selectedLayer]; if (!l || l.type === 'color') return; state.dragging = true; state.dragStart = { x:e.offsetX*(state.canvas.width/state.canvas.clientWidth), y:e.offsetY*(state.canvas.height/state.canvas.clientHeight), ox:l.x||0, oy:l.y||0 }; pushHistory(); });
    window.addEventListener('mousemove', e => { if (!state.dragging) return; const rect = state.canvas.getBoundingClientRect(); const x = (e.clientX-rect.left)*(state.canvas.width/rect.width); const y = (e.clientY-rect.top)*(state.canvas.height/rect.height); const l = state.layers[state.selectedLayer]; if (!l) return; l.x = state.dragStart.ox + (x-state.dragStart.x); l.y = state.dragStart.oy + (y-state.dragStart.y); draw(); });
    window.addEventListener('mouseup', () => { state.dragging=false; });
  }
  function bind() {
    qsa('.tabs button').forEach(b => b.onclick = () => { qsa('.tabs button').forEach(x=>x.classList.remove('active')); qsa('.tabpage').forEach(x=>x.classList.remove('active')); b.classList.add('active'); $('tab-'+b.dataset.tab).classList.add('active'); });
    qsa('.tool').forEach(b => b.onclick = () => { qsa('.tool').forEach(x=>x.classList.remove('active')); b.classList.add('active'); });
    qsa('[data-focus]').forEach(b=>b.onclick=()=>post('focus',{focus:b.dataset.focus}));
    $('rotLeft').onclick=()=>post('rotate',{delta:-12}); $('rotRight').onclick=()=>post('rotate',{delta:12});
    $('closeBtn').onclick=()=>post('close',{apply:false,save:false});
    $('addTextBtn').onclick=addText; $('addColorBtn').onclick=addColor; $('addImageBtn').onclick=()=>$('imageFile').click(); $('imageFile').onchange=e=>addImage(e.target.files[0]);
    ['layerText','layerColor','layerGlow','layerOpacity','layerSize'].forEach(id=>$(id).addEventListener('input', updateSelectedFromInspector));
    $('delLayerBtn').onclick=()=>{ if(state.selectedLayer<0)return; pushHistory(); state.layers.splice(state.selectedLayer,1); state.selectedLayer=-1; renderLayers(); syncInspector(); draw(); };
    $('dupLayerBtn').onclick=()=>{ const l=state.layers[state.selectedLayer]; if(!l)return; pushHistory(); state.layers.push({...l, x:(l.x||0)+30, y:(l.y||0)+30}); state.selectedLayer=state.layers.length-1; renderLayers(); draw(); };
    $('undoBtn').onclick=()=>{ const s=state.history.pop(); if(!s)return; state.redo.push(JSON.stringify({layers:state.layers.map(l=>({...l,img:undefined,imgSrc:l.imgSrc||null}))})); restoreSnapshot(s); };
    $('redoBtn').onclick=()=>{ const s=state.redo.pop(); if(!s)return; state.history.push(JSON.stringify({layers:state.layers.map(l=>({...l,img:undefined,imgSrc:l.imgSrc||null}))})); restoreSnapshot(s); };
    $('genderFilter').onchange=renderTemplates; $('componentFilter').onchange=renderTemplates; $('rescanBtn').onclick=()=>loadCatalog(true);
    $('extractBtn').onclick=extractTexture; $('livePreviewBtn').onclick=livePreview; $('clearLiveBtn').onclick=async()=>{ await post('clearLiveTextures'); setStatus('Live preview törölve.'); };
    $('exportYtdBtn').onclick=exportYtd; $('statusBtn').onclick=status;
    $('downloadPngBtn').onclick=()=>download('realrpg_uv_texture.png', canvasDataUrl()); $('savePngBtn').onclick=$('downloadPngBtn').onclick;
    $('quickFitBtn').onclick=()=>{ addText(); setStatus('Quick AI Fit placeholder: AI generálás későbbi fázis.'); };
    window.addEventListener('wheel', e=>{ if(!state.visible)return; post('zoom',{delta:e.deltaY>0?2.2:-2.2}); });
    window.addEventListener('keydown', e=>{ if(!state.visible)return; if(e.key==='Escape')post('close',{apply:false,save:false}); if(e.key.toLowerCase()==='q')post('rotate',{delta:-10}); if(e.key.toLowerCase()==='e')post('rotate',{delta:10}); });
  }

  window.addEventListener('message', e => {
    const d = e.data || {};
    if (d.action === 'open' || d.action === 'openScreenshot' || d.action === 'refreshLimits') {
      state.visible = true; $('app').classList.remove('hidden'); state.mode = d.mode || state.mode; $('previewMode').textContent = (d.mode || 'PREVIEW').toUpperCase();
      if (!state.catalog.length) loadCatalog(false);
    }
    if (d.action === 'hide') { $('app').classList.add('hidden'); state.visible=false; }
  });

  document.addEventListener('DOMContentLoaded', () => { initCanvasInput(); bind(); status(); });
})();
