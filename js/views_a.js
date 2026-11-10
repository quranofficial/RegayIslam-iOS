/* ============ ڕێگای ئیسلام — views A: home + quran cluster ============ */
'use strict';

/* ================= HOME ================= */
const GRID=[
 {t:'دڵخوازەکان',i:'bookmarks',r:'#/favorites'},
 {t:'ئیدیتی قورئان',i:'edit_note',r:'#/editor'},
 {t:'نوێژکردن',i:'mosque',r:'#/nwezh'},
 {t:'ناوەکانی خودای گەورە',i:'badge',r:'#/names'},
 {t:'ئایەتی کورسی',i:'menu_book',r:'#/kursi'},
 {t:'پرسیار و وەڵام',i:'quiz',r:'#/quiz'},
 {t:'ڤیدیۆی ئاینی',i:'ondemand_video',r:'#/videos'},
 {t:'تاوەنە گەورەکان',i:'warning_amber',r:'#/article/tawanakan.json'},
 {t:'کتێبخانە',i:'local_library',r:'#/books'},
 {t:'ڕوقیەی شەرعی',i:'healing',r:'#/ruqya'},
 {t:'زیکرەکان',i:'self_improvement',r:'#/article/zikrakan.json'},
 {t:'فەرموودەکان',i:'format_quote',r:'#/article/farmwda.json'},
 {t:'مانگی ڕەمەزان',i:'dark_mode',r:'#/ramadan'},
 {t:'ئافرەتان',i:'face_3',r:'#/women'},
 {t:'دوعا و پاڕانەوە',i:'volunteer_activism',r:'#/article/duha.json'},
 {t:'چۆن تۆبە بکەم',i:'change_circle',r:'#/tawba'},
 {t:'حەج و عومرە',i:'flight_land',r:'#/article/hajw.json'},
 {t:'ئەهلی ئاگر',i:'local_fire_department',r:'#/article/agr.json'},
 {t:'بەهەشت',i:'park',r:'#/article/bahasht.json'},
 {t:'دۆزەخ',i:'whatshot',r:'#/article/dozax.json'},
 {t:'خەونامە',i:'bedtime',r:'#/article/xawn.json'},
 {t:'ژیانی پێغەمبەرمان ﷺ',i:'person',r:'#/article/pexambarman.json'},
 {t:'ژیانی پێغەمبەران',i:'groups',r:'#/article/pexambaran.json'},
 {t:'هاوەڵانی پێغەمبەر ﷺ',i:'people',r:'#/article/hawal.json'},
 {t:'سونەت',i:'star',r:'#/article/swnat.json'},
 {t:'زانیاری قورئان',i:'info',r:'#/article/zanyaryquran.json'},
 {t:'ڕاو بۆچونەکان',i:'forum',r:'#/article/rawbochwn.json'},
 {t:'وتە و ئامۆژگاری',i:'record_voice_over',r:'#/article/wta.json'},
 {t:'حەڕام کراوەکان',i:'block',r:'#/article/haram.json'},
 {t:'زیانەکانی گۆرانی',i:'music_off',r:'#/article/zianakanygorani.json'},
 {t:'تاوانی غەیبەت',i:'volume_off',r:'#/article/xaybat.json'},
 {t:'چیرۆکی دەجال',i:'crisis_alert',r:'#/article/dajal.json'},
 {t:'قیبلەنما',i:'explore',r:'#/qibla'},
 {t:'دەنگی قورئان',i:'graphic_eq',r:'#/qari'},
 {t:'گەڕان لە قورئان',i:'search',r:'#/search'},
 {t:'دوعاکانی نوێژ',i:'waving_hand',r:'#/duas'},
 {t:'کاتەکانی مانگ',i:'calendar_month',r:'#/month'},
 {t:'خوێندنی ئایەتەکان',i:'surround_sound',r:'#/range'},
 {t:'دروستکردنی ڤیدیۆ و وێنە',i:'movie_creation',r:'#/studio'},
 {t:'ڕێکخستنی بەشەکان',i:'swap_vert',r:'#/reorder'}
];
function gridItems(){
  const saved=P.get('grid_order',null);
  if(!saved)return GRID.map((g,idx)=>({...g,idx}));
  return saved.map(idx=>({...GRID[idx],idx})).filter(x=>x.t);
}

async function viewHome(m,v){
  setTitle('ڕێگای ئیسلام');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  // daily ayah
  let daily='';
  try{
    await Q.load();
    const d=dailyAyah(), meta=Q.suratMeta(d.s);
    const a=Q.sura(d.s).find(x=>x.n===d.n);
    let taf='';
    try{const t=await Q.tafsir('rebar');taf=t[Q.global(d.s,d.n)-1]||'';}catch(e){}
    const fav=FAV.has('ayah',d.s+':'+d.n);
    daily=`<div class="daily">
      <div class="lbl"><span class="msr">auto_stories</span>ئایەتی ڕۆژ</div>
      <div class="ayah">${esc(a.t)}</div>
      <div class="ref">${esc(meta.name)} — ئایەتی ${ku(d.n)}</div>
      <div class="taf">${esc(taf)}</div>
      <div class="acts">
        <button onclick="nav('#/read/${d.s}/${d.n}')"><span class="msr">menu_book</span>خوێندنەوە</button>
        <button onclick="shareAyah(${d.s},${d.n})"><span class="msr">share</span>هاوبەش</button>
        <button onclick="dailyFav(this,${d.s},${d.n})"><span class="msr">${fav?'favorite':'favorite_border'}</span>دڵخواز</button>
      </div></div>`;
  }catch(e){daily=`<div class="card"><div class="empty">ئایەتی ڕۆژ بارنەبوو — ئینتەرنێت بپشکنە</div></div>`;}

  // banners + cards
  v.innerHTML=daily+`
    <div class="banner live" onclick="nav('#/live')">
      <span class="msr">wifi_tethering</span>
      <div><b>پەخشی ڕاستەوخۆ</b><span class="sub" id="liveCnt">کەناڵەکان بار دەکرێن…</span></div>
    </div>
    <div class="banner ramadan" id="ramadanBanner" style="display:none" onclick="nav('#/ramadan')">
      <span class="msr">nights_stay</span>
      <div><b id="ramT">مانگی ڕەمەزان</b><span class="sub" id="ramS">ڕۆژی ١ لە مانگی ڕەمەزانی پیرۆز</span></div>
    </div>
    <div class="banner friday" onclick="nav('#/zikrfriday')">
      <span class="msr">favorite</span>
      <div><b>شەوی هەینی یە با سەڵاوات لەبیرنەکەین</b>
      <span class="sub" style="font-family:'Quran',serif;font-size:15px">اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ</span></div>
    </div>
    <button class="hcard" onclick="nav('#/tasbih')">
      <span class="av"><span class="msr">fingerprint</span></span>
      <span><b>تەسبیح</b><span class="sub">ژماردنی زیکر و تەسبیحات</span></span>
    </button>
    <div class="card timecard">
      <h2><span class="msr">access_time</span>کاتەکانی بانگ</h2>
      <div class="cityline"><span id="tcCity"></span><button class="btn sm ghost" onclick="nav('#/prayer')">هەموو</button></div>
      <div class="date3">${date3html()}</div>
      <div id="homeTimes" class="times"><div class="spinner"></div></div>
    </div>
    <div class="grid3" id="homeGrid"></div>
    <footer class="credit">ڕێگای ئیسلام — خزمەتگوزاری ئاینی بە زمانی کوردی<br>
      وێبسایت وەک ئەپەکە • <a href="https://linkakam.com/Regayislam" target="_blank" rel="noopener">linkakam.com/Regayislam</a></footer>`;
  renderHomeGrid();
  loadHomeTimes();
  // live count
  db.get('Live').then(x=>{const l=unwrap(x);const n=Array.isArray(l)?l.length:(l?Object.keys(l).length:0);
    const el=$('#liveCnt');if(el)el.textContent=ku(n)+' کەناڵ بەردەستە';}).catch(()=>{});
  // ramadan banner
  db.get('ramadan').then(x=>{const r=unwrap(x);
    if(r&&(r.month||r.day||r.title)){const b=$('#ramadanBanner');if(b){b.style.display='';
      if($('#ramT'))$('#ramT').textContent=r.title||'مانگی ڕەمەزان';
      if($('#ramS'))$('#ramS').textContent=r.text||('ڕۆژی '+ku(r.day||1)+' لە مانگی ڕەمەزانی پیرۆز');}}}).catch(()=>{});
}
function dailyFav(btn,s,n){
  const on=FAV.toggle('ayah',s+':'+n,'سوڕەتی '+(Q.suratMeta(s)?Q.suratMeta(s).name:'')+' ئایەتی '+n,null);
  btn.innerHTML='<span class="msr">'+(on?'favorite':'favorite_border')+'</span>دڵخواز';
  toast(on?'خرایە ناو دڵخوازەکان ❤️':'لابرا');
}
function shareAyah(s,n){
  const meta=Q.suratMeta(s);const a=Q.sura(s).find(x=>x.n===n);
  shareText(a.t+'\n\n'+meta.name+' — ئایەتی '+ku(n)+'\n\n#ڕێگای_ئیسلام');
}
function renderHomeGrid(){
  const items=gridItems();
  $('#homeGrid').innerHTML=items.map(g=>{
    const on=FAV.has('grid',String(g.idx));
    return `<button class="tile" onclick="nav('${g.r}')">
      <button class="favh ${on?'on':''}" onclick="event.stopPropagation();favToggle('grid','${g.idx}','${esc(g.t)}',null,this);renderHomeGrid()"><span class="msr">${on?'favorite':'favorite_border'}</span></button>
      <span class="msr">${g.i}</span><b>${esc(g.t)}</b></button>`;
  }).join('');
}
/* nested button invalid fix: render heart as span overlay instead */
function renderHomeGrid(){
  const items=gridItems();
  $('#homeGrid').innerHTML=items.map(g=>{
    const on=FAV.has('grid',String(g.idx));
    return `<button class="tile" onclick="nav('${g.r}')">
      <span class="favh ${on?'on':''}" onclick="event.stopPropagation();favToggle('grid','${g.idx}','${esc(g.t)}',null,this);renderHomeGrid()"><span class="msr">${on?'favorite':'favorite_border'}</span></span>
      <span class="msr">${g.i}</span><b>${esc(g.t)}</b></button>`;
  }).join('');
}

/* prayer times on home + screens */
const TIMES={d:null,
  async get(){if(this.d)return this.d;this.d=await J(REL+'data/times.json',{nocache:true});return this.d;},
  city(){const id=P.get('city','Hawler');return this.d?this.d.find(c=>c.id===id)||this.d[0]:null;}
};
async function loadHomeTimes(){
  const el=$('#homeTimes');if(!el)return;
  try{
    await TIMES.get();
    const c=TIMES.city();$('#tcCity').textContent='📍 '+c.name;
    const d=new Date(),key=String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
    const row=c.days[key];
    const names=['بەیانی','گزنک','نیوەڕۆ','عەسر','ئێوارە','خەوتنان'];
    const now=d.getHours()*60+d.getMinutes();
    let ni=-1;
    if(row){for(let i=0;i<6;i++){const[m,h]=row[i].split(':').reverse().map(Number);const t=h*60+m;if(t>now){ni=i;break;}}}
    el.innerHTML=names.map((n,i)=>`<div class="time ${i===ni?'now':''}"><div class="n">${n}</div><div class="v">${row?row[i]:'--:--'}</div></div>`).join('');
  }catch(e){el.innerHTML='<div class="empty">کاتەکان بارنەبوون</div>';}
}

/* ================= QURAN TAB ================= */
async function viewQuran(m,v){
  setTitle('ڕێگای ئیسلام');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  await Q.load();
  const rd=P.get('read',null);
  let cont='';
  if(rd&&Q.suratMeta(rd.s)){
    cont=`<button class="hcard" style="background:var(--chip)" onclick="nav('#/read/${rd.s}/${rd.n}')">
      <span class="av"><span class="msr">play_arrow</span></span>
      <span><b>بەردەوامبوون لە خوێندنەوە</b><span class="sub">${esc(Q.suratMeta(rd.s).name)} — ئایەتی ${ku(rd.n)}</span></span>
    </button>`;
  }
  v.innerHTML=cont+`
    <div class="qtabbar">
      <button class="active" id="qtList" onclick="qtab('list')"><span class="msr">list</span>سوورەتەکان</button>
      <button id="qtMushaf" onclick="qtab('mushaf')"><span class="msr">auto_stories</span>موشەف</button>
    </div>
    <div id="qListWrap">
      <div class="card" style="padding:12px"><input id="sq" placeholder="گەڕان بۆ سوورەت..." oninput="renderSurahList()"></div>
      <div class="list" id="surahs"></div>
    </div>
    <div id="qMushafWrap" style="display:none"></div>`;
  renderSurahList();
}
function qtab(t){
  $('#qtList').classList.toggle('active',t==='list');
  $('#qtMushaf').classList.toggle('active',t==='mushaf');
  $('#qListWrap').style.display=t==='list'?'':'none';
  const mw=$('#qMushafWrap');
  if(t==='mushaf'){mw.style.display='';if(!mw.dataset.done){mw.dataset.done=1;mushafInto(mw,P.get('mpage',1));}}
  else mw.style.display='none';
}
function renderSurahList(){
  const q=($('#sq').value||'').trim();
  const list=Q.surat.filter(s=>!q||s.name.includes(q)||String(s.i)===q);
  $('#surahs').innerHTML=list.map(s=>`
    <div class="item" onclick="nav('#/read/${s.i}/1')">
      <span>${ku(s.i)}. ${esc(s.name)}</span>
      <span style="display:flex;gap:8px;align-items:center">
        <span style="font-size:11px;color:var(--muted)">${esc(s.place)} • ${ku(s.aya)} ئایەت</span>
        <span class="num">${ku(s.page)}</span>
      </span></div>`).join('')||'<div class="empty">هیچ نەدۆزرایەوە</div>';
}

/* ================= READER ================= */
async function viewRead(m,v){
  const s=+m[1],n=+m[2];
  setTitle('قورئانی پیرۆز');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  await Q.load();
  const meta=Q.suratMeta(s);if(!meta){v.innerHTML='<div class="empty">سوورەت نەدۆزرایەوە</div>';return;}
  P.set('read',{s:s,n:n});
  const showTaf=P.get('showtafsir',true), col=P.get('tafsir','rebar');
  let tafArr=null;
  if(showTaf){try{tafArr=await Q.tafsir(col)}catch(e){}}
  const ayat=Q.sura(s);
  const sz=P.get('qsize',26);
  v.innerHTML=`
    <div class="card" style="text-align:center;background:var(--daily);color:#fff">
      <div style="font-family:'Quran',serif;font-size:22px;color:var(--gold)">${esc(meta.name)}</div>
      <div style="font-size:12px;margin-top:6px;opacity:.9">${esc(meta.place)} • ${ku(meta.aya)} ئایەت • ${esc(meta.juz)}</div>
      <div style="display:flex;gap:8px;justify-content:center;margin-top:10px">
        <button class="btn sm gold" onclick="nav('#/mushaf/${meta.page}')"><span class="msr">auto_stories</span>موشەف</button>
        <button class="btn sm" onclick="playSura(${s},this)"><span class="msr">graphic_eq</span>دەنگی سوورەت</button>
      </div>
    </div>
    <div class="reader-bar">
      <span>${esc(meta.name.replace('سورەتی ',''))}</span><span class="sp"></span>
      <button onclick="fsAdj(-2)"><span class="msr">remove</span></button>
      <button onclick="fsAdj(2)"><span class="msr">add</span></button>
      <button onclick="tafToggle(this)"><span class="msr">notes</span>تەفسیر</button>
    </div>
    <div class="card" style="padding:0" id="ayatBox">
      ${ayat.map(a=>{
        const g=Q.global(s,a.n);const on=FAV.has('ayah',s+':'+a.n);
        return `<div class="ayah-row ${a.n===n?'hl':''}" id="ay${a.n}">
          <div class="top">
            <span class="anum" onclick="nav('#/read/${s}/${a.n}')">${ku(a.n)}</span>
            <span class="ref">ئایەتی ${ku(a.n)}</span>
            <span class="sp"></span>
            <button class="abtn" onclick="playAyah(${g},this)" title="دەنگ"><span class="msr">play_circle</span></button>
            ${FAV.heart('ayah',s+':'+a.n,meta.name+' ئایەتی '+a.n,{s:s,n:a.n})}
            <button class="abtn" onclick="shareAyah(${s},${a.n})"><span class="msr">share</span></button>
          </div>
          <div class="a">${esc(a.t)}</div>
          ${tafArr&&tafArr[g-1]?`<div class="taf">${esc(tafArr[g-1])}</div>`:''}
        </div>`;}).join('')}
    </div>
    <div style="display:flex;gap:8px;margin-top:10px">
      ${s>1?`<button class="btn ghost block" onclick="nav('#/read/${s-1}/1')">پێشوو</button>`:''}
      ${s<114?`<button class="btn block" onclick="nav('#/read/${s+1}/1')">دوات</button>`:''}
    </div>`;
  document.documentElement.style.setProperty('--qsize',sz+'px');
  if(n>1){setTimeout(()=>{const el=$('#ay'+n);if(el)el.scrollIntoView({block:'center'});},60);}
}
function fsAdj(d){const z=Math.min(60,Math.max(14,P.get('qsize',26)+d));P.set('qsize',z);
  document.documentElement.style.setProperty('--qsize',z+'px');}
function tafToggle(btn){
  const on=P.get('showtafsir',true);P.set('showtafsir',!on);
  toast(!on?'تەفسیر کراوە':'تەفسیر داخرا');
  const m=location.hash.match(/^#\/read\/(\d+)\/(\d+)/);
  if(m)render();
}
function playAyah(g,btn){
  AU.init();
  if(AU.cur===CDN_AYAH+g+'.mp3'&&!AU.el.paused){AU.pause();return;}
  AU.play(CDN_AYAH+g+'.mp3').catch(audioError);
}
function playSura(s,btn){
  // sequential per-ayah playback of the whole surah
  const ayat=Q.sura(s);let i=0;
  AU.init();
  const next=()=>{if(i>=ayat.length)return;
    const g=Q.global(s,ayat[i].n);
    AU.play(CDN_AYAH+g+'.mp3',next).catch(()=>{});
    const el=$('#ay'+ayat[i].n);
    $$('.ayah-row.hl').forEach(x=>x.classList.remove('hl'));
    if(el){el.classList.add('hl');el.scrollIntoView({block:'center',behavior:'smooth'});}
    i++;};
  next();
}

/* ================= MUSHAF ================= */
function mushafInto(wrap,page){
  page=Math.min(604,Math.max(1,page));P.set('mpage',page);
  wrap.innerHTML=`
    <div class="mushaf-bar">
      <button class="btn sm ghost" onclick="mushafNav(-1)"><span class="msr">chevron_right</span></button>
      <input id="mpInput" value="${ku(page)}" onchange="mushafGo(this.value)">
      <span class="pageof">لە ${ku(604)}</span>
      <span class="sp" style="flex:1"></span>
      <select id="mpSura" onchange="mushafGo(Q.suratMeta(+this.value).page)" style="width:150px">
        ${Q.surat.map(s=>`<option value="${s.i}" ${s.page===page?'selected':''}>${esc(s.name)}</option>`).join('')}
      </select>
      <button class="btn sm ghost" onclick="mushafFull()"><span class="msr">fullscreen</span></button>
      <button class="btn sm ghost" onclick="mushafNav(1)"><span class="msr">chevron_left</span></button>
    </div>
    <div class="mushaf-wrap"><img id="mpImg" src="${MUSHAF(page)}" alt="لاپەڕە ${ku(page)}"></div>`;
}
function mushafNav(d){mushafGo(P.get('mpage',1)+d);}
function mushafGo(p){p=parseInt(ku2en(String(p)));if(!p)return;
  const mw=$('#qMushafWrap');mushafInto(mw,Math.min(604,Math.max(1,p)));}
function ku2en(s){return s.replace(/[٠-٩]/g,c=>'٠١٢٣٤٥٦٧٨٩'.indexOf(c)).replace(/[^\d]/g,'');}
function mushafFull(){
  const img=$('#mpImg');if(!img)return;
  if(img.requestFullscreen)img.requestFullscreen().catch(()=>{});
  else openSheet(`<h3>لاپەڕە ${ku(P.get('mpage',1))}</h3><img src="${MUSHAF(P.get('mpage',1))}" style="width:100%;border-radius:12px">`);
}
route(/^#\/mushaf\/(\d+)$/,async(m,v)=>{
  setTitle('موشەف');await Q.load();
  v.innerHTML='<div id="mushafBox"></div>';
  mushafInto($('#mushafBox'),+m[1]);
});

/* ================= SEARCH ================= */
route(/^#\/search$/,async(m,v)=>{
  setTitle('گەڕان لە قورئان');
  v.innerHTML=`<div class="appbar2"><span class="msr">search</span><h1>گەڕان لە قورئان</h1></div>
    <div class="card" style="padding:12px"><input id="sqa" placeholder="وشە بنووسە — وەک: ڕەحمەت، الصبر..." oninput="doSearch()"></div>
    <div id="sres"></div>`;
  await Q.load();
});
let searchT=null;
function doSearch(){
  clearTimeout(searchT);
  searchT=setTimeout(async()=>{
    const q=($('#sqa').value||'').trim();
    const box=$('#sres');
    if(q.length<2){box.innerHTML='';return;}
    box.innerHTML='<div class="spinner"></div>';
    await Q.load();
    const nq=normAr(q);
    const suraHits=Q.surat.filter(s=>s.name.includes(q)||normAr(s.name).includes(nq)).slice(0,8);
    const hits=Q.list.filter(a=>normAr(a.t).includes(nq)).slice(0,60);
    box.innerHTML=(suraHits.length?`<div class="card" style="padding:0"><div style="padding:10px 14px;font-size:12px;color:var(--muted)">سوورەتەکان</div>${suraHits.map(s=>`<div class="item" onclick="nav('#/read/${s.i}/1')"><span>${esc(s.name)}</span><span class="num">${ku(s.i)}</span></div>`).join('')}</div>`:'')+
      (hits.length?`<div class="card" style="padding:0"><div style="padding:10px 14px;font-size:12px;color:var(--muted)">ئایەتەکان — ${ku(hits.length)} ئەنجام</div>${hits.map(a=>{const meta=Q.suratMeta(a.s);
        return `<div class="item" style="display:block" onclick="nav('#/read/${a.s}/${a.n}')">
          <div style="font-size:11px;color:var(--gold);font-weight:700;margin-bottom:4px">${esc(meta.name)} — ئایەتی ${ku(a.n)}</div>
          <div style="font-family:'Quran',serif;font-size:19px;line-height:2">${hit(a.t,q)}</div></div>`;}).join('')}</div>`
       :(suraHits.length?'':'<div class="card"><div class="empty">هیچ ئەنجامێک نەدۆزرایەوە</div></div>'));
  },350);
}
function hit(t,q){
  const nt=normAr(t),nq=normAr(q);
  const i=nt.indexOf(nq);if(i<0)return esc(t);
  return esc(t.slice(Math.max(0,i-40),i))+'<span class="srchit">'+esc(t.slice(i,i+nq.length))+'</span>'+esc(t.slice(i+nq.length,i+nq.length+60));
}

/* ================= 99 NAMES ================= */
async function namesData(){
  try{return await J(RAWD+'nawakani_xwda.json',{ttl:24*3600e3})}catch(e){
    return await J(REL+'names.json',{nocache:true});}
}
route(/^#\/names$/,async(m,v)=>{
  setTitle('ناوەکانی خودای گەورە');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let data=[];try{data=await namesData()}catch(e){}
  v.innerHTML=`<div class="appbar2"><span class="msr">badge</span><h1>ناوەکانی خودای گەورە (${ku(data.length)})</h1></div>
    <div class="card" style="padding:12px"><input id="nq" placeholder="گەڕان..." oninput="renderNames()"></div>
    <div class="list" id="namesBox"></div>
    <p style="font-size:11.5px;color:var(--muted);margin-top:8px;line-height:1.9">کرتە لەسەر ناوێک بکە بۆ بینینی واتاکان بە سۆرانی و بادینی و شوێنی ناوەکە لە قورئان.</p>`;
  window._names=data;renderNames();
});
function renderNames(){
  const q=($('#nq')?$('#nq').value:'').trim();
  const list=window._names.filter(n=>!q||(n.arabic||'').includes(q)||(n.tashkeel||'').includes(q)||(n.sorani||'').includes(q)||(n.badini||'').includes(q));
  $('#namesBox').innerHTML=list.map(n=>`
    <div class="name" onclick="nameSheet(${n.id||0},this)">
      <div style="font-family:'Quran',serif;font-size:25px;color:var(--accent);min-width:110px">${esc(n.arabic)}</div>
      <div><div style="font-size:12.5px;font-weight:600">${esc(n.sorani)}</div>
      <div style="font-size:11px;color:var(--gold);font-weight:700;margin-top:3px">📍 ${esc(n.ref||'')}</div></div>
    </div>`).join('')||'<div class="empty">هیچ نەدۆزرایەوە</div>';
  window._namesFiltered=list;
}
function nameSheet(idx){
  const n=window._namesFiltered[idx]||window._names[idx];
  let g=null;
  if(n.ref){const p=String(n.ref).split(':');if(p.length===2&&Q.list){g=Q.global(+p[0],+p[1]);}}
  openSheet(`
    <h3><span class="msr">badge</span>${esc(n.arabic)} — ${esc(n.sorani)}</h3>
    <div style="text-align:center;font-family:'Quran',serif;font-size:40px;color:var(--accent);padding:6px 0">${esc(n.tashkeel||n.arabic)}</div>
    <div style="font-size:13px;line-height:2.1;margin-top:6px">
      <p><b>سۆرانی:</b> ${esc(n.sorani||'—')}</p>
      <p><b>بادینی:</b> ${esc(n.badini||'—')}</p>
      ${n.english?`<p><b>English:</b> ${esc(n.english)}</p>`:''}
      ${n.farsi?`<p><b>فارسی:</b> ${esc(n.farsi)}</p>`:''}
      <p style="color:var(--gold);font-weight:700">📍 شوێن: سوڕەتی ${esc(n.ref||'—')}</p>
    </div>
    <div style="display:flex;gap:8px;margin-top:12px">
      ${g?`<button class="btn block" onclick="AU.play('${CDN_AYAH+g}.mp3').catch(audioError)"><span class="msr">volume_up</span>دەنگی ئایەتەکە</button>`:''}
      ${g?`<button class="btn gold block" onclick="closeSheet();nav('#/read/${String(n.ref).split(':')[0]}/${String(n.ref).split(':')[1]}')"><span class="msr">menu_book</span>کردنەوەی ئایەتەکە</button>`:''}
      ${FAV.heart('name',String(n.id||n.arabic),n.arabic+' — '+n.sorani,{name:n.arabic,sorani:n.sorani,ref:n.ref})}
    </div>`);
  if(g&&Q.list){const p=String(n.ref).split(':');}
}

/* ================= QARI (81 reciters) ================= */
route(/^#\/qari$/,async(m,v)=>{
  setTitle('دەنگی قورئان');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let data=[];try{data=await J(RAWD+'dangakan.json',{ttl:24*3600e3})}catch(e){}
  // mirror the app: ONLY doxx=true reciters (audio + timings ready)
  window._qaris=data.filter(q=>q.url&&String(q.doxx||'').toLowerCase()==='true');
  v.innerHTML=`<div class="appbar2"><span class="msr">graphic_eq</span><h1>دەنگی قورئان (${ku(window._qaris.length)} قارئ)</h1></div>
    <div class="vgrid" style="grid-template-columns:repeat(auto-fill,minmax(100px,1fr))">
    ${window._qaris.map((q,i)=>`<button class="qari" onclick="qariSurahs(${i})">
      <img src="${RAW}assets/images/qari/${q.id}.png" onerror="this.style.visibility='hidden'" loading="lazy">
      <b>${esc(q.name_ar.trim())}</b></button>`).join('')}</div>`;
});
function qariSurahs(i){
  const q=window._qaris[i];
  openSheet(`<h3><span class="msr">graphic_eq</span>${esc(q.name_ar.trim())}</h3>
    <div class="card" style="padding:12px;margin:0"><input id="qsurq" placeholder="گەڕان..." oninput="qariList(${i})"></div>
    <div class="list" style="max-height:400px" id="qsurList"></div>`);
  qariList(i);
}
function qariList(i){
  const q=window._qaris[i];
  const f=($('#qsurq')?$('#qsurq').value:'').trim();
  const list=Q.surat.filter(s=>!f||s.name.includes(f)||String(s.i)===f);
  $('#qsurList').innerHTML=list.map(s=>`
    <div class="item" onclick="AU.play('${q.url}/${pad3(s.i)}').catch(audioError);toast('دەنگ دەست پێکرد ▶')">
      <span>${esc(s.name)}</span><span class="num">▶</span></div>`).join('');
}

/* ================= RANGE PLAYER (خوێندنی ئایەتەکان) ================= */
route(/^#\/range$/,async(m,v)=>{
  setTitle('خوێندنی ئایەتەکان');await Q.load();
  v.innerHTML=`<div class="appbar2"><span class="msr">surround_sound</span><h1>خوێندنی ئایەتەکان</h1></div>
    <div class="card">
      <div class="row">
        <select id="rgS" onchange="rgFill()">${Q.surat.map(s=>`<option value="${s.i}">${esc(s.name)}</option>`).join('')}</select>
      </div>
      <div class="rangectl">
        <select id="rgA" style="max-width:110px"></select>
        <span>بۆ</span>
        <select id="rgB" style="max-width:110px"></select>
        <button class="btn" onclick="rgPlay()"><span class="msr">play_arrow</span>لێدان</button>
      </div>
      <div class="chipset">
        <button class="chip on" id="rgRep" onclick="this.classList.toggle('on')">دووبارەکردنەوە</button>
        <button class="chip on" id="rgAuto" onclick="this.classList.toggle('on')">خۆکارانە دوات</button>
      </div>
    </div>
    <div id="rgList"></div>`;
  rgFill();
});
function rgFill(){
  const s=+$('#rgS').value,meta=Q.suratMeta(s);
  const opts=Array.from({length:meta.aya},(_,i)=>i+1);
  $('#rgA').innerHTML=opts.map(n=>`<option value="${n}">${ku(n)}</option>`).join('');
  $('#rgB').innerHTML=opts.map(n=>`<option value="${n}" ${n===meta.aya?'selected':''}>${ku(n)}</option>`).join('');
}
let RG={playing:false,i:0,list:[]};
function rgPlay(){
  const s=+$('#rgS').value,a=+$('#rgA').value,b=+$('#rgB').value;
  if(b<a){toast('مەودای هەڵەیە');return;}
  RG.list=[];for(let n=a;n<=b;n++)RG.list.push({s,n});
  RG.i=0;RG.playing=true;rgRender();rgStep();
}
function rgStep(){
  if(!RG.playing)return;
  if(RG.i>=RG.list.length){
    if($('#rgRep')&&$('#rgRep').classList.contains('on')){RG.i=0;}
    else{RG.playing=false;return;}
  }
  const x=RG.list[RG.i];const g=Q.global(x.s,x.n);
  $$('.ayah-row.hl').forEach(e=>e.classList.remove('hl'));
  const el=$('#ay'+x.n);if(el){el.classList.add('hl');el.scrollIntoView({block:'center',behavior:'smooth'});}
  if($('#rgNow'))$('#rgNow').textContent=Q.suratMeta(x.s).name+' — ئایەتی '+ku(x.n);
  AU.play(CDN_AYAH+g+'.mp3',()=>{if($('#rgAuto')&&!$('#rgAuto').classList.contains('on')){RG.playing=false;return;}RG.i++;rgStep();}).catch(()=>{RG.i++;setTimeout(rgStep,800);});
}
function rgRender(){
  $('#rgList').innerHTML=`<div class="nowplay"><span class="msr">music_note</span><span class="tt" id="rgNow">—</span><span class="sp"></span>
    <button onclick="RG.i=Math.max(0,RG.i-1);rgStep()"><span class="msr">skip_previous</span></button>
    <button onclick="RG.playing?AU.pause():rgStep()"><span class="msr">pause</span></button>
    <button onclick="RG.i++;rgStep()"><span class="msr">skip_next</span></button></div>
    <div class="card" style="padding:0;margin-top:12px">${RG.list.map(x=>{const a=Q.sura(x.s).find(y=>y.n===x.n);
      return `<div class="ayah-row" id="ay${x.n}"><div class="top"><span class="anum">${ku(x.n)}</span>
      <span class="ref">${esc(Q.suratMeta(x.s).name)}</span></div><div class="a" style="font-size:22px">${esc(a.t)}</div></div>`;}).join('')}</div>`;
}

/* ================= STUDIO (image maker) ================= */
route(/^#\/studio$/,async(m,v)=>{
  setTitle('دروستکردنی وێنە');await Q.load();
  v.innerHTML=`<div class="appbar2"><span class="msr">movie_creation</span><h1>دروستکردنی وێنەی ئایەت</h1></div>
    <div class="card">
      <div class="row">
        <select id="stS" onchange="stFill()">${Q.surat.map(s=>`<option value="${s.i}">${esc(s.name)}</option>`).join('')}</select>
        <select id="stA" style="max-width:100px"></select>
      </div>
      <div class="chipset" id="stBg">
        <button class="chip on" data-c="g1">شین</button><button class="chip" data-c="g2">سەوز</button>
        <button class="chip" data-c="g3">مۆر</button><button class="chip" data-c="dark">ڕەش</button>
        <button class="chip" data-c="light">سپی</button>
      </div>
      <canvas id="stC" class="studio-canvas" width="1080" height="1080" style="margin-top:12px"></canvas>
      <div style="display:flex;gap:8px;margin-top:10px">
        <button class="btn block" onclick="stDraw()"><span class="msr">refresh</span>نوێکردنەوە</button>
        <button class="btn gold block" onclick="stSave()"><span class="msr">download</span>داگرتن</button>
      </div>
    </div>`;
  stFill();stDraw();
  $$('#stBg .chip').forEach(c=>c.onclick=()=>{$$('#stBg .chip').forEach(x=>x.classList.remove('on'));c.classList.add('on');stDraw();});
});
function stFill(){
  const s=+$('#stS').value,meta=Q.suratMeta(s);
  $('#stA').innerHTML=Array.from({length:meta.aya},(_,i)=>i+1).map(n=>`<option value="${n}">ئایەتی ${ku(n)}</option>`).join('');
}
function stDraw(){
  const s=+$('#stS').value,n=+$('#stA').value;
  const a=Q.sura(s).find(x=>x.n===n),meta=Q.suratMeta(s);
  const cv=$('#stC'),ctx=cv.getContext('2d');
  const mode=$('#stBg .chip.on').dataset.c;
  const grads={g1:['#004D7B','#00639b'],g2:['#1B5E20','#2E7D32'],g3:['#4A148C','#6A1B9A'],dark:['#111','#333'],light:['#F4F5F7','#fff']};
  const g=ctx.createLinearGradient(0,0,cv.width,cv.height);
  g.addColorStop(0,grads[mode][0]);g.addColorStop(1,grads[mode][1]);
  ctx.fillStyle=g;ctx.fillRect(0,0,cv.width,cv.height);
  const light=mode==='light';
  ctx.fillStyle=light?'#004D7B':'#C8A24B';
  ctx.font='700 46px Rabar';ctx.textAlign='center';
  ctx.fillText('ئایەتی ڕۆژ',cv.width/2,110);
  // wrap ayah text
  ctx.fillStyle=light?'#111':'#fff';
  ctx.font='52px Quran';
  const words=a.t.split(' ');let line='',lines=[],y=220;
  for(const w of words){const t=line?line+' '+w:w;
    if(ctx.measureText(t).width>cv.width-160){lines.push(line);line=w;}else line=t;}
  lines.push(line);
  for(const l of lines){ctx.fillText(l,cv.width/2,y);y+=105;}
  ctx.fillStyle=light?'#004D7B':'#C8A24B';
  ctx.font='700 36px Rabar';
  ctx.fillText(meta.name+' — ئایەتی '+ku(n),cv.width/2,cv.height-90);
  ctx.font='28px Rabar';ctx.fillStyle=light?'#666':'rgba(255,255,255,.75)';
  ctx.fillText('#ڕێگای_ئیسلام',cv.width/2,cv.height-40);
}
function stSave(){
  const a=document.createElement('a');
  a.download='regayislam-ayah.png';a.href=$('#stC').toDataURL('image/png');a.click();
  toast('وێنەکە داگیرا ✅');
}

/* ================= FAVORITES ================= */
route(/^#\/favorites$/,async(m,v)=>{
  setTitle('دڵخوازەکان');await Q.load();
  const list=FAV.all().slice().reverse();
  const nm={ayah:'ئایەت',name:'ناوی خودا',article:'بابەت',grid:'بەش',hadith:'فەرموودە'};
  v.innerHTML=`<div class="appbar2"><span class="msr">bookmarks</span><h1>دڵخوازەکان (${ku(list.length)})</h1></div>
    <div class="card" style="padding:0">
    ${list.length?list.map((f,i)=>`<div class="item" onclick="openFav('${f.t}','${esc(String(f.id))}')">
      <span class="favline"><span class="msr">${f.t==='ayah'?'menu_book':f.t==='name'?'badge':f.t==='article'?'article':'grid_view'}</span>
      <span>${esc(f.title||nm[f.t]||f.t)}</span></span>
      <span style="display:flex;gap:8px;align-items:center">
        <button class="abtn" onclick="event.stopPropagation();favToggle('${f.t}','${esc(String(f.id))}','',null,null);viewFavoritesRefresh()"><span class="msr" style="color:var(--red)">delete</span></button>
        <span class="msr" style="color:var(--muted);font-size:18px">chevron_left</span>
      </span></div>`).join(''):'<div class="empty">هێشتا هیچت دڵخواز نەکردووە 💛</div>'}</div>`;
});
function viewFavoritesRefresh(){if(location.hash==='#/favorites')render();}
function openFav(t,id){
  if(t==='ayah'){const p=id.split(':');nav('#/read/'+p[0]+'/'+p[1]);}
  else if(t==='name'){nav('#/names');setTimeout(()=>{toast('ناوەکە لە لیستەکە هەڵبژێرە');},400);}
  else if(t==='article'){const p=id.split('|');nav('#/article/'+p[0]+'/'+p[1]);}
  else if(t==='grid'){const g=GRID[+id];if(g)nav(g.r);}
}

/* ================= EDITOR (ئیدیتی قورئان) ================= */
route(/^#\/editor$/,async(m,v)=>{
  setTitle('ئیدیتی قورئان');
  const sz=P.get('qsize',26),st=P.get('showtafsir',true),col=P.get('tafsir','rebar');
  const T=[['rebar','ڕێبەری سەرفیڕاز'],['raman','ڕەمان'],['roshn','ڕۆشن'],['sanahi','سەناهی'],['hazhar','هەژار'],['tawhid','تەوحید'],['asan','ئاسان'],['maiser','مەیسر'],['zhin','ژیان'],['puxta','پوختە']];
  v.innerHTML=`<div class="appbar2"><span class="msr">edit_note</span><h1>ئیدیتی قورئان</h1></div>
    <div class="card">
      <h2><span class="msr">format_size</span>قەبارەی نووسین</h2>
      <div class="rangectl">
        <button class="btn sm ghost" onclick="edSize(-2)"><span class="msr">remove</span></button>
        <b id="edSz" style="font-size:18px;color:var(--accent)">${ku(sz)}</b>
        <button class="btn sm ghost" onclick="edSize(2)"><span class="msr">add</span></button>
        <input type="range" min="14" max="60" value="${sz}" style="flex:2" oninput="edSize(0,this.value)">
      </div>
      <div style="font-family:'Quran',serif;font-size:${Math.min(sz,34)}px;line-height:2.2;margin-top:10px;text-align:center">بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ</div>
    </div>
    <div class="card">
      <h2><span class="msr">notes</span>تەفسیر</h2>
      <div class="chipset">
        <button class="chip ${st?'on':''}" onclick="P.set('showtafsir',${!st});render()">تەفسیر ${st?'کاردەکات ✅':'ناکارایە'}</button>
      </div>
      <div class="chipset">${T.map(t=>`<button class="chip ${col===t[0]?'on':''}" onclick="P.set('tafsir','${t[0]}');render()">${t[1]}</button>`).join('')}</div>
    </div>
    <div class="card">
      <h2><span class="msr">palette</span>ڕەنگی خوێنەر</h2>
      <div class="chipset">
        <button class="chip" onclick="P.set('dark',false);applyTheme();toast('دۆخی ڕووناک')">☀️ ڕووناک</button>
        <button class="chip" onclick="P.set('dark',true);applyTheme();toast('دۆخی تاریک')">🌙 تاریک</button>
      </div>
    </div>
    <button class="btn gold block" onclick="nav('#/read/1/1')"><span class="msr">visibility</span>پێشبینین — کردنەوەی قورئان</button>`;
});
function edSize(d,val){
  let z=val?+val:P.get('qsize',26)+d;
  z=Math.min(60,Math.max(14,z));P.set('qsize',z);
  document.documentElement.style.setProperty('--qsize',z+'px');
  const el=$('#edSz');if(el)el.textContent=ku(z);
}
