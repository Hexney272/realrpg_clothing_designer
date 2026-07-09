const state = {
  visible:false, active:'Clothing', components:[], props:[], presets:[], categories:[], previewObjects:{}, playerModels:{}, gender:'male', canvas:{}, currentImage:null, isAdmin:false
};

const app = document.getElementById('app');
const $ = (id)=>document.getElementById(id);

function post(name, data={}){
  return fetch(`https://${GetParentResourceName()}/${name}`, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data) }).then(r=>r.json()).catch(()=>({ok:false}));
}

function show(section){
  state.active = section;
  document.querySelectorAll('.section').forEach(el=>el.classList.remove('active'));
  document.querySelectorAll('.tab').forEach(el=>el.classList.toggle('active', el.dataset.key===section));
  const map = { Skin:'modelPanel', Clothing:'componentPanel', Accessories:'componentPanel', Body:'componentPanel', Studio:'canvasPanel', Saved:'savedPanel', Orders:'savedPanel', Screenshot:'screenshotPanel', Admin:'adminPanel' };
  const panel = $(map[section] || 'componentPanel');
  if(panel) panel.classList.add('active');
  $('componentList').classList.toggle('hidden', section==='Accessories');
  $('propList').classList.toggle('hidden', section!=='Accessories');
  if(section==='Orders') setTimeout(loadOrders, 60);
  if(section==='Saved') setTimeout(loadSaved, 60);
  $('panelEyebrow').textContent = section.toUpperCase();
  $('panelTitle').textContent = ({Skin:'Karakter modellek',Clothing:'Ruházat',Accessories:'Kiegészítők',Body:'Test részletek',Studio:'Designer canvas',Saved:'Ruhatár / mentett dizájnok',Orders:'Rendelések',Screenshot:'Image Generator',Admin:'Admin creator'})[section] || section;
}

function renderTabs(){
  const tabs = $('categoryTabs'); tabs.innerHTML='';
  const cats = [...state.categories.filter(c=>c.enabled!==false), {key:'Screenshot', label:'Image Generator', type:'screenshot'}];
  if(state.isAdmin) cats.push({key:'Admin', label:'Admin', type:'admin', icon:'shield'});
  cats.forEach(c=>{
    const b=document.createElement('button'); b.className='tab'; b.dataset.key=c.key; b.innerHTML=`<b>${c.label}</b><span>${c.icon || c.type || ''}</span>`; b.onclick=()=>show(c.key); tabs.appendChild(b);
  });
}

function renderPreviewSelect(){
  const sel=$('previewSelect'); sel.innerHTML='';
  Object.entries(state.previewObjects || {}).forEach(([key,v])=>{
    const o=document.createElement('option'); o.value=key; o.textContent=v.label || key; sel.appendChild(o);
  });
  sel.onchange=()=>post('changePreviewType',{kind:sel.value}).then(r=>{$('previewMode').textContent=(r.mode||'preview').toUpperCase();});
}

function rowForComponent(c, type){
  const row=document.createElement('div'); row.className='row';
  const drawableMin = type==='prop' ? -1 : 0;
  row.innerHTML=`
    <div class="row-head"><b>${c.label}</b><button class="mini focus">Fókusz</button></div>
    <div class="slider-line"><span>Drawable</span><input class="draw" type="range" min="${drawableMin}" max="${c.maxDrawable||0}" value="${c.drawable||0}"><b class="drawVal">${c.drawable||0}</b></div>
    <div class="slider-line"><span>Texture</span><input class="tex" type="range" min="0" max="${c.maxTexture||0}" value="${c.texture||0}"><b class="texVal">${c.texture||0}</b></div>
  `;
  const draw=row.querySelector('.draw'), tex=row.querySelector('.tex'), drawVal=row.querySelector('.drawVal'), texVal=row.querySelector('.texVal');
  row.querySelector('.focus').onclick=()=>post('focus',{focus:c.focus});
  const send=()=>{
    drawVal.textContent=draw.value; texVal.textContent=tex.value;
    const payload={id:c.id,key:c.key,tex:c.tex,drawable:Number(draw.value),texture:Number(tex.value),focus:c.focus};
    post(type==='prop'?'setProp':'setComponent', payload).then(r=>{
      if(r && r.ok && typeof r.maxTexture==='number') { tex.max = r.maxTexture; if(Number(tex.value)>r.maxTexture) tex.value=r.maxTexture; texVal.textContent=tex.value; }
    });
  };
  draw.oninput=send; tex.oninput=send;
  return row;
}

function renderLists(){
  const comp=$('componentList'); comp.innerHTML=''; state.components.forEach(c=>comp.appendChild(rowForComponent(c,'component')));
  const prop=$('propList'); prop.innerHTML=''; state.props.forEach(p=>prop.appendChild(rowForComponent(p,'prop')));
}

function renderPresets(){
  const box=$('presetList'); box.innerHTML='';
  state.presets.forEach((p,i)=>{
    const el=document.createElement('div'); el.className='preset'; el.innerHTML=`<b>${p.name}</b><span>${p.tag || 'preset'} · ${p.price || 0} RC</span>`;
    el.onclick=()=>post('applyPreset',{index:i}); box.appendChild(el);
  });
}

function renderModels(){
  const box=$('modelList'); box.innerHTML='';
  const models = (state.playerModels && (state.playerModels[state.gender] || [])) || [];
  models.forEach(m=>{
    const el=document.createElement('div'); el.className='preset'; el.innerHTML=`<b>${m.label}</b><span>${m.model}</span>`; el.onclick=()=>post('setModel',{model:m.model}); box.appendChild(el);
  });
}

function canvasData(){ return { text:$('designText').value, baseColor:$('baseColor').value, neonColor:$('neonColor').value, pattern:$('pattern').value }; }
function updateCanvas(){
  state.canvas=canvasData();
  const p=$('canvasPreview'); p.className='canvas-preview '+state.canvas.pattern; p.style.background=state.canvas.baseColor; p.style.color=state.canvas.neonColor; p.style.boxShadow=`inset 0 0 55px ${state.canvas.neonColor}33`;
  p.querySelector('span').textContent=state.canvas.text || 'REALRPG';
}
['designText','baseColor','neonColor','pattern'].forEach(id=>setTimeout(()=>$(id).addEventListener('input',updateCanvas),0));

function applyCanvasFromResponse(res){
  if(res.canvas){ Object.assign(state.canvas,res.canvas); $('designText').value=state.canvas.text||''; $('baseColor').value=state.canvas.baseColor||'#17172a'; $('neonColor').value=state.canvas.neonColor||'#8b5cf6'; $('pattern').value=state.canvas.pattern||'clean'; updateCanvas(); }
}
function loadSaved(){
  $('savedList').classList.remove('hidden'); $('orderList').classList.add('hidden');
  post('loadMyDesigns').then(r=>{
    const box=$('savedList'); box.innerHTML='';
    (r.designs||[]).forEach(d=>{
      const el=document.createElement('div'); el.className='row';
      el.innerHTML=`<div class="row-head"><b>${d.name}</b><span class="status-pill">#${d.id}</span></div><div class="eyebrow">${d.preview_type || ''} · ${d.gender || ''} · ${d.created_at || ''}</div><div class="saved-actions"><button class="mini load">Betöltés</button><button class="mini apply">Felvétel</button><button class="mini item">Item</button><button class="mini duplicate">Másolás</button><button class="mini rename">Átnevezés</button><button class="mini danger-mini delete">Törlés</button></div>`;
      el.querySelector('.load').onclick=()=>post('applySavedDesign',{id:d.id}).then(applyCanvasFromResponse);
      el.querySelector('.apply').onclick=()=>post('applySavedDesignToPlayer',{id:d.id});
      el.querySelector('.item').onclick=()=>post('orderSavedDesignItem',{id:d.id,itemType:'outfit'});
      el.querySelector('.duplicate').onclick=()=>post('duplicateDesign',{id:d.id}).then(loadSaved);
      el.querySelector('.rename').onclick=()=>{ const name=prompt('Új dizájn név', d.name); if(name) post('renameDesign',{id:d.id,name}).then(loadSaved); };
      el.querySelector('.delete').onclick=()=>{ if(confirm('Biztos törlöd ezt a dizájnt?')) post('deleteDesign',{id:d.id}).then(loadSaved); };
      box.appendChild(el);
    });
  });
}
function statusLabel(status){
  return ({pending:'Függőben',approved:'Jóváhagyva',ready:'Elkészült',rejected:'Elutasítva',cancelled:'Lemondva'})[status] || status || 'ready';
}
function loadOrders(){
  $('savedList').classList.add('hidden'); $('orderList').classList.remove('hidden');
  post('loadMyOrders').then(r=>{
    const box=$('orderList'); box.innerHTML='';
    (r.orders||[]).forEach(o=>{
      const el=document.createElement('div'); el.className='row';
      const canCancel = (o.status || '') === 'pending';
      el.innerHTML=`<div class="row-head"><b>${o.name}</b><span class="status-pill ${o.status||''}">${statusLabel(o.status)}</span></div><div class="eyebrow">${o.type || ''} · ${o.price || 0} RC · ${o.created_at || ''}</div>${o.note ? `<div class="info-card small">${o.note}</div>` : ''}<div class="saved-actions">${canCancel ? '<button class="mini danger-mini cancel">Lemondás</button>' : ''}</div>`;
      const cancel=el.querySelector('.cancel'); if(cancel) cancel.onclick=()=>post('cancelOrder',{id:o.id}).then(loadOrders);
      box.appendChild(el);
    });
  });
}
function loadAdminDesigns(){
  $('adminList').classList.remove('hidden'); if($('adminOrders')) $('adminOrders').classList.add('hidden');
  post('adminListDesigns').then(r=>{
    const box=$('adminList'); box.innerHTML='';
    (r.designs||[]).forEach(d=>{
      const el=document.createElement('div'); el.className='row';
      el.innerHTML=`<div class="row-head"><b>${d.name}</b><span class="status-pill">${d.identifier || ''}</span></div><div class="eyebrow">#${d.id} · ${d.preview_type || ''} · ${d.created_at || ''}</div><div class="saved-actions"><button class="mini load">Preview</button><button class="mini item">Item saját magadnak</button></div>`;
      el.querySelector('.load').onclick=()=>post('adminLoadDesign',{id:d.id}).then(applyCanvasFromResponse);
      el.querySelector('.item').onclick=()=>post('adminGiveDesignItem',{id:d.id});
      box.appendChild(el);
    });
  });
}

function loadAdminOrders(){
  $('adminOrders').classList.remove('hidden'); $('adminList').classList.add('hidden');
  const status = $('adminOrderStatus').value || 'pending';
  post('adminListOrders',{status}).then(r=>{
    const box=$('adminOrders'); box.innerHTML='';
    (r.orders||[]).forEach(o=>{
      const el=document.createElement('div'); el.className='row';
      el.innerHTML=`<div class="row-head"><b>#${o.id} · ${o.name}</b><span class="status-pill ${o.status||''}">${statusLabel(o.status)}</span></div><div class="eyebrow">${o.identifier || ''} · ${o.type || ''} · ${o.price || 0} RC · ${o.created_at || ''}</div>${o.note ? `<div class="info-card small">${o.note}</div>` : ''}<div class="saved-actions"><button class="mini approve">Jóváhagyás</button><button class="mini deliver">Item kiadás</button><button class="mini danger-mini reject">Elutasítás</button></div>`;
      el.querySelector('.approve').onclick=()=>post('adminSetOrderStatus',{id:o.id,status:'approved',note:'Admin jóváhagyta'}).then(loadAdminOrders);
      el.querySelector('.deliver').onclick=()=>post('adminDeliverOrder',{id:o.id}).then(loadAdminOrders);
      el.querySelector('.reject').onclick=()=>{ const note=prompt('Elutasítás oka','Nem megfelelő dizájn'); post('adminSetOrderStatus',{id:o.id,status:'rejected',note:note||''}).then(loadAdminOrders); };
      box.appendChild(el);
    });
  });
}

function open(data, screenshot=false){
  state.visible=true; app.classList.remove('hidden');
  Object.assign(state, { components:data.components||[], props:data.props||[], presets:data.presets||[], categories:data.categories||[], previewObjects:data.previewObjects||{}, playerModels:data.playerModels||{}, gender:data.gender||'male', isAdmin:data.isAdmin||false });
  $('genderPill').textContent=state.gender;
  $('coinLabel').textContent=(data.realCoin && data.realCoin.label) || 'RC';
  $('previewMode').textContent=(data.mode||'preview').toUpperCase();
  renderTabs(); renderPreviewSelect(); renderLists(); renderPresets(); renderModels(); updateCanvas(); if(data.flow && data.flow.loadSavedOnOpen) setTimeout(loadSaved, 200); show(screenshot?'Screenshot':'Clothing');
}

window.addEventListener('message', (e)=>{
  const d=e.data||{};
  if(d.action==='open') open(d,false);
  if(d.action==='openScreenshot') open(d,true);
  if(d.action==='refreshLimits'){ state.components=d.components||state.components; state.props=d.props||state.props; $('previewMode').textContent=(d.mode||'preview').toUpperCase(); renderLists(); }
  if(d.action==='adminState'){ state.isAdmin=!!d.isAdmin; renderTabs(); }
  if(d.action==='forceSection'){ show(d.section || 'Clothing'); }
  if(d.action==='hide'){ app.classList.add('hidden'); state.visible=false; }
});

document.querySelectorAll('[data-focus]').forEach(b=>b.onclick=()=>post('focus',{focus:b.dataset.focus}));
$('rotLeft').onclick=()=>post('rotate',{delta:-12}); $('rotRight').onclick=()=>post('rotate',{delta:12});
$('closeBtn').onclick=()=>post('close',{apply:false,save:false});
$('applyBtn').onclick=()=>post('close',{apply:true,save:true});
$('saveDesign').onclick=()=>post('saveDesign',{name:$('designName').value,canvas:canvasData(),image:state.currentImage});
$('orderOutfit').onclick=()=>post('orderItem',{name:$('designName').value,itemType:'outfit',canvas:canvasData(),image:state.currentImage});
$('orderPart').onclick=()=>post('orderItem',{name:$('designName').value,itemType:'part',canvas:canvasData(),image:state.currentImage});
$('loadSaved').onclick=loadSaved;
$('loadOrders').onclick=loadOrders;
$('loadAdminDesigns').onclick=loadAdminDesigns;
$('loadAdminOrders').onclick=loadAdminOrders;
$('adminOrderStatus').onchange=loadAdminOrders;
$('adminOpenFor').onclick=()=>post('adminOpenForPlayer',{target:Number($('adminTarget').value||0)});
$('captureBtn').onclick=()=>{
  $('captureResult').textContent='Kép készítése...';
  post('captureImage',{name:$('designName').value,category:state.active}).then(r=>{
    if(r.ok && r.result){ state.currentImage=r.result; $('captureResult').innerHTML=`<img src="${r.result}">`; }
    else $('captureResult').textContent=r.error || 'Nem sikerült képet készíteni.';
  });
};

window.addEventListener('wheel', e=>{ if(!state.visible) return; post('zoom',{delta:e.deltaY>0?2.2:-2.2}); });
window.addEventListener('keydown', e=>{ if(!state.visible) return; if(e.key==='Escape') post('close',{apply:false,save:false}); if(e.key.toLowerCase()==='q') post('rotate',{delta:-10}); if(e.key.toLowerCase()==='e') post('rotate',{delta:10}); });
