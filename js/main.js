/* ============ ڕێگای ئیسلام — router table + boot ============ */
'use strict';

route(/^#\/$/,viewHome);
route(/^#\/quran$/,viewQuran);
route(/^#\/read\/(\d+)\/(\d+)$/,viewRead);

/* boot */
(async function(){
  applyTheme();
  try{await Q.load();}catch(e){}
  render();
  $('#splash').style.display='none';
  $('#app').style.display='';
  // announcement dialog (same as app)
  try{
    const d=unwrap(await db.get('dialogg/dialog'));
    const ver=P.get('dlgver',0);
    if(d&&d.open&&(d.ver||1)>ver){
      const box=document.createElement('div');
      box.className='dlg show';
      box.innerHTML=`<div class="box"><h3>${esc(d.title||'ئاگاداری')}</h3>
        <p>${esc(d.text||'')}</p>
        ${d.url?`<a class="btn gold block" style="margin-bottom:8px" href="${esc(d.url)}" target="_blank" rel="noopener">کردنەوەی بەستەر</a>`:''}
        <button class="btn block" onclick="P.set('dlgver',${d.ver||1});this.closest('.dlg').remove()">داخستن</button></div>`;
      document.body.appendChild(box);
    }
  }catch(e){}
})();
