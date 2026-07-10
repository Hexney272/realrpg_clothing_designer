/* RealRPG Clothing Designer V15.3 targeted UI patch
   Replace the activeTemplatePayload() function in html/uv_workbench.js with this version.
*/

function activeTemplatePayload() {
  const extra = safeJson($('templateJson').value);
  const t = state.template || {};
  const meta = typeof t.meta === 'string' ? safeJson(t.meta) : (t.meta || {});

  const component = t.component_key || t.category || extra.component || extra.category || '';
  const drawable = Number(t.drawable || extra.drawable || 0);
  const texture = Number(t.texture || extra.texture || 0);

  const yddPath =
    extra.yddPath ||
    t.ydd_path ||
    t.yddPath ||
    (t.file_type === 'ydd' ? t.template_path : undefined) ||
    meta.yddPath ||
    meta.templatePath ||
    undefined;

  const ytdPath =
    extra.ytdPath ||
    extra.templateYtd ||
    t.ytd_path ||
    t.ytdPath ||
    t.texture_path ||
    t.texturePath ||
    meta.ytdPath ||
    meta.texturePath ||
    (t.file_type === 'ytd' ? t.template_path : undefined) ||
    undefined;

  const inferredTextureName =
    t.texture_name ||
    t.textureName ||
    meta.textureName ||
    (component ? `${component}_diff_${String(drawable).padStart(3, '0')}_a_uni` : '') ||
    t.name ||
    '';

  const textureName = $('originalTxn').value || extra.textureName || inferredTextureName;

  return {
    ...extra,
    id: t.id,
    name: t.name,
    gender: t.gender || extra.gender,
    component,
    category: t.category || component,
    drawable,
    texture,
    fileName: t.file_name || t.fileName,
    fileType: t.file_type || t.fileType,
    templatePath: t.template_path || t.templatePath || meta.templatePath,
    yddPath,
    ytdPath,
    texturePath: ytdPath,
    templateYtd: ytdPath,
    textureName,
    originalTxn: textureName,
    txdName: $('originalTxd').value || extra.txdName || extra.txd || meta.txdName || ''
  };
}
