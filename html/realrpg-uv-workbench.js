(() => {
  const $ = (id) => document.getElementById(id);
  const post = (name, data = {}) => fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(data)
  }).then(r => r.json()).catch(() => ({ok:false}));

  function makeTopbar(){
    if ($('rrUvTopbar')) return;
    const bar = document.createElement('div');
    bar.id = 'rrUvTopbar';
    bar.className = 'rr-uv-topbar';
    bar.innerHTML = `
      <div class="rr-uv-brand"><div class="rr-uv-mark">R</div><div><b>RealRPG Clothing Designer</b><span>Live 3D preview · UV texture workbench</span></div></div>
      <div class="rr-uv-tools"><div class="rr-uv-tool-pill">▲ Select Tool</div><div class="rr-uv-tool-pill">Move layer</div><div class="rr-uv-tool-pill">Alt + drag pan</div></div>
      <div class="rr-uv-actions"><button class="quick" id="rrQuickAi">✦ Quick AI Fit</button><button id="rrSaveTop">Save</button><button class="export" id="rrExportTop">Export</button><button class="close" id="rrCloseTop">×</button></div>`;
    const app = $('app');
    if (app) app.appendChild(bar);
    $('rrSaveTop').onclick = () => $('saveDesign')?.click();
    $('rrExportTop').onclick = () => $('rcdInjectBtn')?.click();
    $('rrCloseTop').onclick = () => $('closeBtn')?.click();
    $('rrQuickAi').onclick = () => {
      const color = $('rcdLayerColor'); const glow = $('rcdLayerGlow'); const text = $('rcdLayerText');
      if (color) color.value = '#7cff3b'; if (glow) glow.value = '#22d3ee'; if (text && !text.value) text.value = 'REALRPG';
      $('rcdAddTextBtn')?.click(); setTimeout(() => $('rcdLiveBtn')?.click(), 80);
    };
  }

  function makeDock(){
    if ($('rrUvDock')) return;
    const dock = document.createElement('aside');
    dock.id = 'rrUvDock';
    dock.className = 'rr-uv-dock';
    dock.innerHTML = `
      <div class="rr-uv-dock-tabs">
        <button class="active" data-dock="layers">LAYERS</button>
        <button data-dock="templates">TEMPLATES</button>
        <button data-dock="saved">SAVED</button>
      </div>
      <div class="rr-uv-dock-body active" id="rrDockLayers">
        <div class="rr-uv-dock-title"><b>LAYERS</b><span id="rrLayerCount">0</span></div>
        <div class="rr-uv-card"><b>Rétegek</b><br>A text/szín/image rétegek itt jelennek meg. Az UV canvas középen szerkeszthető.</div>
        <div id="rrLayerMount"></div>
        <div class="rr-uv-slot"><div><b>Slot A</b><small>Texture export slot</small></div><span>A</span></div>
      </div>
      <div class="rr-uv-dock-body" id="rrDockTemplates">
        <div class="rr-uv-dock-title"><b>TEMPLATES</b><span>.ydd + .ytd</span></div>
        <div class="rr-uv-card"><b>Mi ez?</b><br>A jobb oldali nagy kép a kiterített UV/diffuse textúra. A bridge ezt nyeri ki a .ytd-ből PNG-ként.</div>
        <input class="rr-uv-mini-input" id="rrTemplateQuickYtd" placeholder="templates/cloth_templates/male/head/head_diff_000_a_uni.ytd" />
        <input class="rr-uv-mini-input" id="rrTemplateQuickTxn" placeholder="head_diff_000_a_uni" />
        <div class="rcd-actions"><button id="rrUseTemplate">Template betöltés</button><button id="rrExtractTemplate">PNG kinyerés</button></div>
      </div>
      <div class="rr-uv-dock-body" id="rrDockSaved">
        <div class="rr-uv-dock-title"><b>SAVED</b><span>RealRPG</span></div>
        <div class="rr-uv-card"><b>Mentés / Export</b><br>A felső Save a DB-be ment, az Export új streamelhető .ytd-t készít a workerrel.</div>
        <div class="rcd-actions"><button id="rrOpenSaved">Saját dizájnok</button><button id="rrOpenOrders">Rendelések</button></div>
      </div>`;
    $('app')?.appendChild(dock);
    dock.querySelectorAll('[data-dock]').forEach(btn => btn.onclick = () => {
      dock.querySelectorAll('[data-dock]').forEach(b => b.classList.toggle('active', b === btn));
      dock.querySelectorAll('.rr-uv-dock-body').forEach(b => b.classList.remove('active'));
      const id = btn.dataset.dock === 'layers' ? 'rrDockLayers' : btn.dataset.dock === 'templates' ? 'rrDockTemplates' : 'rrDockSaved';
      $(id)?.classList.add('active');
    });
    $('rrUseTemplate').onclick = () => {
      if ($('rrTemplateQuickYtd')?.value && $('rcdYtdPath')) $('rcdYtdPath').value = $('rrTemplateQuickYtd').value;
      if ($('rrTemplateQuickTxn')?.value && $('rcdTextureName')) $('rcdTextureName').value = $('rrTemplateQuickTxn').value;
      if ($('rrTemplateQuickTxn')?.value && $('rcdOriginalTxn')) $('rcdOriginalTxn').value = $('rrTemplateQuickTxn').value;
    };
    $('rrExtractTemplate').onclick = () => { $('rrUseTemplate')?.click(); $('rcdExtractBtn')?.click(); };
    $('rrOpenSaved').onclick = () => { try { window.show && window.show('Saved'); } catch {} $('loadSaved')?.click(); };
    $('rrOpenOrders').onclick = () => { try { window.show && window.show('Orders'); } catch {} $('loadOrders')?.click(); };
  }

  function moveLayers(){
    const mount = $('rrLayerMount');
    const list = $('rcdLayerList');
    if (mount && list && list.parentElement !== mount) mount.appendChild(list);
    const count = list ? list.children.length : 0;
    if ($('rrLayerCount')) $('rrLayerCount').textContent = String(count);
  }

  function forceStudioOnFirstOpen(){
    let forced = false;
    window.addEventListener('message', (e) => {
      const d = e.data || {};
      if ((d.action === 'open' || d.action === 'openScreenshot') && !forced) {
        forced = true;
        setTimeout(() => { try { window.show && window.show('Studio'); } catch {} }, 180);
      }
    });
  }

  function boot(){
    document.documentElement.classList.add('rr-uv-skin');
    makeTopbar();
    makeDock();
    forceStudioOnFirstOpen();
    let ticks = 0;
    const timer = setInterval(() => { moveLayers(); if (++ticks > 40) clearInterval(timer); }, 250);
    const obs = new MutationObserver(moveLayers);
    const layerParent = $('rcdTextureEditor') || document.body;
    try { obs.observe(layerParent, {childList:true, subtree:true}); } catch {}
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
