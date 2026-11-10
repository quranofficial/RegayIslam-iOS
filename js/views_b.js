/* ============ ڕێگای ئیسلام — views B: media, articles, prayer, tasbih, settings ============ */
'use strict';

/* ================= VIDEOS (Firebase RTDB — same as app) ================= */
const VID={all:null,tags:null,
  async load(){
    if(this.all)return;
    const [vn,va]=await Promise.all([db.get('videoNew').catch(()=>null),db.get('videoall').catch(()=>null)]);
    let tags=[];
    const uva=unwrap(va);
    if(Array.isArray(uva))tags=uva.filter(t=>t&&t.tag);
    else if(uva&&typeof uva==='object')tags=Object.values(uva).filter(t=>t&&t.tag);
    const folders={};
    const uvn=unwrap(vn)||{};
    const walk=(obj,folder)=>{
      if(!obj||typeof obj!=='object')return;
      for(const k of Object.keys(obj)){
        const val=obj[k];
        if(val&&(val.url||val.name)&&typeof val==='object')folders[folder]=folders[folder]||{},folders[folder][k]=val;
        else if(val&&typeof val==='object')walk(val,k);
      }};
    walk(uvn,'');
    this.tags=tags.length?tags:Object.keys(folders).map(t=>({tag:t,name:t,image:''}));
    this.all=folders;
  },
  videosOf(tag){const f=this.all[tag];return f?Object.keys(f).map(k=>({key:k,...f[k]})).sort((a,b)=>String(b.date||'').localeCompare(String(a.date||''))):[];}
};
route(/^#\/videos$/,async(m,v)=>{
  setTitle('ڤیدیۆی ئاینی');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  try{await VID.load();}catch(e){v.innerHTML='<div class="card"><div class="empty">ڤیدیۆکان بارنەبوون — ئینتەرنێت بپشکنە</div></div>';return;}
  v.innerHTML=`<div class="appbar2"><span class="msr">ondemand_video</span><h1>ڤیدیۆی ئاینی</h1></div>
    <div class="tagbar" id="vidTags"></div><div class="vgrid" id="vidList"></div>`;
  vidTags(0);
});
function vidTags(i){
  const tags=VID.tags;
  $('#vidTags').innerHTML=tags.map((t,j)=>`<button class="${j===i?'active':''}" onclick="vidTags(${j})">${esc(t.name||t.tag)}</button>`).join('');
  const tag=tags[i]?tags[i].tag:null;
  const vids=tag?VID.videosOf(tag):[];
  $('#vidList').innerHTML=vids.length?vids.map(x=>`
    <button class="vcard" onclick="nav('#/video/${encodeURIComponent(tag)}/${x.key}')">
      <span class="th">${x.url&&x.url.includes('youtube')?'<span class="msr">smart_display</span>':'<span class="msr">play_circle</span>'}</span>
      <b>${esc(x.name||'بێ ناو')}</b>
      <span class="meta"><span><span class="msr">favorite</span> ${ku(x.like||0)}</span><span><span class="msr">visibility</span> ${ku(x.view||0)}</span></span>
    </button>`).join(''):'<div class="empty" style="grid-column:1/-1">هیچ ڤیدیۆیەک نییە لەم بەشە</div>';
}
function ytEmbed(url){
  const m=url.match(/[?&]v=([\w-]+)|youtu\.be\/([\w-]+)|\/embed\/([\w-]+)/);
  const id=m?(m[1]||m[2]||m[3]):null;
  return id?`https://www.youtube.com/embed/${id}`:null;
}
route(/^#\/video\/([^/]+)\/([^/]+)$/,async(m,v)=>{
  await VID.load();
  const tag=decodeURIComponent(m[1]),key=m[2];
  const x=VID.videosOf(tag).find(y=>y.key===key)||VID.videosOf(tag)[0];
  if(!x){v.innerHTML='<div class="empty">ڤیدیۆ نەدۆزرایەوە</div>';return;}
  setTitle(x.name||'ڤیدیۆ');
  const emb=x.url&&x.url.includes('youtube')?ytEmbed(x.url):null;
  const liked=P.get('liked',[]).includes(tag+'/'+key);
  v.innerHTML=`
    <div class="player">${emb?`<iframe src="${emb}" allowfullscreen></iframe>`
      :`<video id="pv" controls playsinline src="${esc(x.url)}"></video>`}</div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin:12px 2px 4px">
      <b style="font-size:15px">${esc(x.name||'')}</b>
      <span style="font-size:11px;color:var(--muted)"><span class="msr" style="font-size:15px">visibility</span> ${ku(x.view||0)}</span>
    </div>
    ${emb?'':`<div class="pctrls">
      <button class="btn sm ghost" onclick="pvSeek(-10)"><span class="msr">replay_10</span>١٠ چرکە</button>
      <button class="btn sm ghost" onclick="pvSeek(10)"><span class="msr">forward_10</span>١٠ چرکە</button>
      <button class="btn sm ghost" onclick="pvSpeed(this)"><span class="msr">speed</span><b id="pvSpd">١.٠</b></button>
      <a class="btn sm ghost" href="${esc(x.url)}" target="_blank" rel="noopener"><span class="msr">download</span>داگرتن</a>
    </div>`}
    <div class="pctrls">
      <button class="btn ${liked?'':'gold'}" id="likeBtn" onclick="vidLike('${esc(tag)}','${key}',${x.like||0})">
        <span class="msr">favorite</span>${ku((x.like||0)+(liked?1:0))}</button>
      <button class="btn" onclick="vidComments('${esc(tag)}','${key}','${esc(x.name||'')}')">
        <span class="msr">chat_bubble</span>سەرنجەکان ${ku(x.comment||0)}</button>
      <button class="btn ghost" onclick="shareText('${esc(x.name||'')}\n${esc(x.url||'')}\n\n#ڕێگای_ئیسلام')"><span class="msr">share</span></button>
    </div>
    <div class="card" style="margin-top:14px"><button class="btn ghost block" onclick="nav('#/videos')"><span class="msr">arrow_back</span>گەڕانەوە بۆ ڤیدیۆکان</button></div>`;
  // count view once
  const vk='v_'+tag+'/'+key;
  if(!P.get(vk,false)){P.set(vk,true);db.patch(`videoNew/${tag}/${key}`,{view:(x.view||0)+1}).catch(()=>{});}
  if(emb)closeSheet();
});
function pvSeek(d){const el=$('#pv');if(el)el.currentTime=Math.max(0,el.currentTime+d);}
const SPD=[0.25,0.5,1,1.25,1.5,2];
function pvSpeed(btn){
  const el=$('#pv');if(!el)return;
  let i=SPD.indexOf(el.playbackRate);if(i<0)i=2;
  i=(i+1)%SPD.length;el.playbackRate=SPD[i];
  $('#pvSpd').textContent=ku(String(SPD[i]).replace('.','.'));$('#pvSpd').textContent=String(SPD[i]).replace('0.','.')==='1'?'١.٠':ku(String(SPD[i]));
}
async function vidLike(tag,key,cur){
  const id=tag+'/'+key;
  let liked=P.get('liked',[]);
  try{
    if(liked.includes(id)){ // unlike
      await db.patch(`videoNew/${tag}/${key}`,{like:Math.max(0,(cur||1)-1)});
      liked=liked.filter(x=>x!==id);P.set('liked',liked);
      toast('لابرا لە دڵخوازەکان');render();
    }else{
      await db.patch(`videoNew/${tag}/${key}`,{like:(cur||0)+1});
      liked.push(id);P.set('liked',liked);
      toast('بەدڵم بوو ❤️');render();
    }
  }catch(e){toast('نەکرا — دووبارە هەوڵبدەرەوە');}
}
async function vidComments(tag,key,name){
  openSheet(`<h3><span class="msr">chat_bubble</span>سەرنجەکان — ${esc(name)}</h3><div id="cmList"><div class="spinner"></div></div>
    <div style="display:flex;gap:8px;margin-top:12px">
      <input id="cmTxt" placeholder="سەرنجەکەت بنووسە...">
      <button class="btn" onclick="cmSend('${esc(tag)}','${key}')"><span class="msr">send</span></button>
    </div>`);
  try{
    const d=await db.get(`CommentVideo/${key}`);
    let arr=[];const u=unwrap(d);
    if(u&&typeof u==='object')arr=Object.values(u);
    arr.sort((a,b)=>String(a.date||'').localeCompare(String(b.date||'')));
    $('#cmList').innerHTML=arr.length?arr.map(c=>`<div class="cm">
      <span class="who">${esc(c.userrr||'بەکارهێنەر')}</span><span class="when">${esc(String(c.date||'').slice(0,10))}</span>
      <p>${esc(c.commenttt||'')}</p></div>`).join(''):'<div class="empty">هێشتا سەرنجێک نییە — یەکەم کەس بە!</div>';
  }catch(e){$('#cmList').innerHTML='<div class="empty">سەرنجەکان بارنەبوون</div>';}
}
async function cmSend(tag,key){
  const t=($('#cmTxt').value||'').trim();if(!t)return;
  let name=P.get('myname','');
  if(!name){name=prompt('ناوت چییە؟');if(!name)return;P.set('myname',name);}
  const btn=$('#cmTxt');btn.disabled=true;
  try{
    const d=new Date();
    const date=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')+' '+String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0');
    const res=await db.push('CommentVideo/'+key,{userrr:name,commenttt:t,date:date,uid:UID,verify:'web',video_id:key});
    if(res&&res.name)await db.patch(`CommentVideo/${key}/${res.name}`,{comment_key:res.name}).catch(()=>{});
    toast('سەرنجەکەت نێردرا ✅');vidComments(tag,key,name);
  }catch(e){toast('نەنێردرا — دووبارە هەوڵبدەرەوە');btn.disabled=false;}
}

/* ================= LIVE ================= */
route(/^#\/live$/,async(m,v)=>{
  setTitle('پەخشی ڕاستەوخۆ');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let ch=[];try{
    const d=await db.get('Live');const u=unwrap(d);
    ch=Array.isArray(u)?u.filter(c=>c&&c.url):(u&&typeof u==='object'?Object.values(u).filter(c=>c&&c.url):[]);
  }catch(e){}
  try{const d2=await db.get('livemuslim');const u2=unwrap(d2);
    if(!ch.length&&u2)ch=(Array.isArray(u2)?u2:Object.values(u2)).filter(c=>c&&c.url);}catch(e){}
  v.innerHTML=`<div class="appbar2"><span class="msr">wifi_tethering</span><h1>پەخشی ڕاستەوخۆ (${ku(ch.length)} کەناڵ)</h1></div>
    <div id="liveBox"></div>
    <div class="vgrid" style="margin-top:12px">
    ${ch.map((c,i)=>{const img=c.image&&String(c.image).startsWith('http')?c.image:'';
      return `<button class="vcard" onclick="livePlay(${i})">
        <span class="th">${img?`<img src="${esc(img)}">`:'<span class="msr">live_tv</span>'}</span>
        <b>${esc(c.name||'کەناڵی '+ku(i+1))}</b><span class="meta"><span class="msr">live_tv</span> ڕاستەوخۆ</span></button>`;}).join('')||
      '<div class="empty" style="grid-column:1/-1">کەناڵێک بەردەست نییە</div>'}</div>`;
  window._live=ch;livePlay(0);
});
function livePlay(i){
  const c=window._live[i];if(!c)return;
  const box=$('#liveBox');if(!box)return;
  const isYt=c.url.includes('youtube');
  if(isYt){const e=ytEmbed(c.url);box.innerHTML=`<div class="player">${e?`<iframe src="${e}" allowfullscreen></iframe>`:''}</div>`;return;}
  box.innerHTML=`<div class="player"><video id="lv" controls autoplay playsinline muted></video></div>`;
  const el=$('#lv');
  if(Hls&&Hls.isSupported()&&c.url.includes('.m3u8')){
    const hls=new Hls();hls.loadSource(c.url);hls.attachMedia(el);
    el.muted=false;el.play().catch(()=>{el.muted=true;el.play().catch(()=>{});});
  }else{el.src=c.url;el.play().catch(()=>{});}
}

/* ================= QUIZ (RTDB) ================= */
route(/^#\/quiz$/,async(m,v)=>{
  setTitle('پرسیار و وەڵام');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let qs=[];try{
    const d=await db.get('quiz');const u=unwrap(d);
    let arr=Array.isArray(u)?u:Object.values(u||{});
    qs=arr.map(q=>quizNorm(q)).filter(q=>q&&q.opts.length>=2);
  }catch(e){}
  if(!qs.length){v.innerHTML='<div class="card"><div class="empty">پرسیارەکان بارنەبوون — دووبارە هەوڵبدەرەوە</div></div>';return;}
  window._quiz=qs.sort(()=>Math.random()-.5).slice(0,20);
  window._qi=-1;window._score=0;
  v.innerHTML='<div id="quizBox"></div>';quizNext();
});
function quizNorm(q){
  if(!q||typeof q!=='object')return null;
  const u=unwrap(q);
  const keys=['op1','op2','op3','op4','o1','o2','o3','o4','opt1','opt2','opt3','opt4','a','b','c','d'];
  let opts=keys.map(k=>u[k]).filter(x=>x&&typeof x==='string');
  let ans=u.ans!=null?u.ans:(u.answer!=null?u.answer:null);
  let ai=-1;
  if(typeof ans==='number')ai=ans>0?ans-1:ans;
  else if(typeof ans==='string'){
    const m=ans.trim().toLowerCase();
    const map={a:0,b:1,c:2,d:3,'1':0,'2':1,'3':2,'4':3};
    if(m in map)ai=map[m];else ai=opts.findIndex(o=>o===ans||o.trim()===ans.trim());
  }
  return {q:u.question||u.q||'',opts:opts,ai:ai};
}
function quizNext(){
  window._qi++;
  const box=$('#quizBox');
  if(window._qi>=window._quiz.length){
    const n=window._quiz.length,s=window._score;
    box.innerHTML=`<div class="card" style="text-align:center;padding:30px">
      <span class="msr" style="font-size:60px;color:var(--gold)">emoji_events</span>
      <h2 style="justify-content:center;margin-top:8px">ئەنجام</h2>
      <div style="font-size:30px;font-weight:700;color:var(--accent);margin:10px 0">${ku(s)} / ${ku(n)}</div>
      <div style="font-size:13px;color:var(--muted);margin-bottom:16px">${s>=n*0.7?'زۆر باش بوو! ماڵاڵا 👏':'دووبارە هەوڵبدەرەوە — باشتر دەبیت 💪'}</div>
      <button class="btn block" onclick="nav('#/quiz');render()"><span class="msr">refresh</span>دووبارە</button></div>`;
    return;
  }
  const q=window._quiz[window._qi];
  box.innerHTML=`<div class="qbar"><i style="width:${(window._qi/window._quiz.length)*100}%"></i></div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
      <span class="qtimer" id="qT">٣٠</span>
      <span style="font-size:12px;color:var(--muted)">${ku(window._qi+1)} / ${ku(window._quiz.length)} • ${ku(window._score)} ڕاست</span>
    </div>
    <div class="card"><div class="qq">${esc(q.q)}</div>
      ${q.opts.map((o,i)=>`<button class="qopt" onclick="quizAns(${i},this)">${esc(o)}</button>`).join('')}
    </div>`;
  window._qleft=30;clearInterval(window._qtimer);
  window._qtimer=setInterval(()=>{
    window._qleft--;const el=$('#qT');
    if(el)el.textContent=ku(window._qleft);
    if(window._qleft<=0){clearInterval(window._qtimer);quizAns(-1,null);}
  },1000);
}
function quizAns(i,btn){
  clearInterval(window._qtimer);
  const q=window._quiz[window._qi];
  const btns=$$('.qopt');
  btns.forEach((b,j)=>{if(j===q.ai)b.classList.add('ok');b.disabled=true;});
  if(i===q.ai){window._score++;}
  else if(btn)btn.classList.add('no');
  setTimeout(quizNext,1100);
}

/* ================= BOOKS ================= */
route(/^#\/books$/,async(m,v)=>{
  setTitle('کتێبخانە');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let books=[];try{
    books=await J('https://github.com/quranofficial/ktebakan/raw/main/ktebakan.json',{ttl:6*3600e3});
    if(!Array.isArray(books))books=Object.values(books||{});
  }catch(e){}
  if(!books.length){try{books=await J(RAWD+'ktebakan.json',{nocache:true});}catch(e){}}
  window._books=books;
  v.innerHTML=`<div class="appbar2"><span class="msr">local_library</span><h1>کتێبخانە (${ku(books.length)} کتێب)</h1></div>
    <div class="card" style="padding:12px"><input id="bkq" placeholder="گەڕان..." oninput="renderBooks()"></div>
    <div class="vgrid" style="grid-template-columns:repeat(auto-fill,minmax(120px,1fr))" id="bkGrid"></div>`;
  renderBooks();
});
function renderBooks(){
  const q=($('#bkq')?$('#bkq').value:'').trim();
  const list=window._books.filter(b=>!q||(b.name||'').includes(q)||(b.about||'').includes(q));
  $('#bkGrid').innerHTML=list.map((b,i)=>`
    <button class="bk" onclick="bookOpen(${window._books.indexOf(b)})">
      <img src="${esc(b.image||'')}" loading="lazy" onerror="this.style.background='var(--chip)';this.src='logo.png'">
      <b>${esc(b.name||'')}</b></button>`).join('')||'<div class="empty">هیچ نەدۆزرایەوە</div>';
}
function bookOpen(i){
  const b=window._books[i];if(!b)return;
  openSheet(`<h3><span class="msr">local_library</span>${esc(b.name||'')}</h3>
    ${b.about?`<p style="font-size:12.5px;line-height:2;color:var(--muted);margin-bottom:10px">${esc(b.about)}</p>`:''}
    ${b.admin?`<p style="font-size:11.5px;color:var(--gold);margin-bottom:10px">✍️ ${esc(b.admin)}</p>`:''}
    <div style="display:flex;gap:8px">
      <button class="btn block" onclick="nav('#/bookpdf/${i}');closeSheet()"><span class="msr">menu_book</span>خوێندنەوە</button>
      <a class="btn gold block" href="${esc(b.url||'#')}" target="_blank" rel="noopener"><span class="msr">download</span>داگرتن</a>
    </div>`);
}
route(/^#\/bookpdf\/(\d+)$/,async(m,v)=>{
  const b=window._books[+m[1]];if(!b)return;
  setTitle(b.name||'کتێب');
  v.innerHTML=`<div class="appbar2"><span class="msr">menu_book</span><h1 style="font-size:15px">${esc(b.name||'')}</h1></div>
    <iframe class="pdfframe" src="${esc(b.url)}" allowfullscreen></iframe>
    <div style="display:flex;gap:8px;margin-top:10px">
      <button class="btn ghost block" onclick="history.back()"><span class="msr">arrow_back</span>گەڕانەوە</button>
      <a class="btn gold block" href="${esc(b.url)}" target="_blank" rel="noopener"><span class="msr">open_in_new</span>کردنەوە لە تاب</a>
    </div>`;
});

/* ================= GENERIC ARTICLE VIEWER (all home JSON cards) ================= */
route(/^#\/article\/([^/]+)$/,async(m,v)=>articleView(m[1],null,v));
route(/^#\/article\/([^/]+)\/(\d+)$/,async(m,v)=>articleView(m[1],+m[2],v));
async function articleView(file,openIdx,v){
  const meta=findArticle(file);
  setTitle(meta?meta.t:file);
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let items=[];try{items=await article(file);}catch(e){}
  window._art=items;window._artFile=file;
  v.innerHTML=`<div class="appbar2"><span class="msr">article</span><h1>${esc(meta?meta.t:file)} <span style="font-size:12px;color:var(--muted)">(${ku(items.length)})</span></h1></div>
    <div class="card" style="padding:12px"><input id="aq" placeholder="گەڕان..." oninput="renderArts()"></div>
    <div class="card" style="padding:0 14px" id="artBox"></div>`;
  renderArts();
  if(openIdx!=null)setTimeout(()=>{const el=$('#art'+openIdx);if(el){el.classList.add('open');el.scrollIntoView({block:'start'});}},100);
}
function renderArts(){
  const q=($('#aq')?$('#aq').value:'').trim();
  const items=window._art.map((x,realIdx)=>({x,realIdx})).filter(({x})=>!q||(x.title||'').includes(q)||(x.text||'').includes(q));
  $('#artBox').innerHTML=items.map(({x,realIdx})=>{
    const on=FAV.has('article',window._artFile+'|'+realIdx);
    return `<div class="art" id="art${realIdx}">
      <div class="h" onclick="this.parentNode.classList.toggle('open')">
        <b>${esc(x.title||'بابەتی '+ku(realIdx+1))}</b>
        <span style="display:flex;gap:2px;align-items:center">
          <button class="abtn ${on?'on':''}" onclick="event.stopPropagation();favToggle('article','${window._artFile}|${realIdx}','${esc(x.title||'بابەت')}',null,this)"><span class="msr">${on?'favorite':'favorite_border'}</span></button>
          <button class="abtn" onclick="event.stopPropagation();shareText('${esc(x.title||'')}\n\n${esc((x.text||'').slice(0,400))}\n\n#ڕێگای_ئیسلام')"><span class="msr">share</span></button>
          <span class="msr">keyboard_arrow_down</span>
        </span>
      </div>
      <div class="b">${esc(x.text)}</div>
      ${x.extra?`<div style="display:none" class="b">${esc(x.extra)}</div>`:''}
    </div>`;}).join('')||'<div class="empty">هیچ نەدۆزرایەوە</div>';
}

/* ================= WOMEN HUB ================= */
route(/^#\/women$/,async(m,v)=>{
  setTitle('ئافرەتان');
  v.innerHTML=`<div class="appbar2"><span class="msr">face_3</span><h1>ئافرەتان</h1></div>
    <div class="grid2">${ART_WOMEN.map(w=>`<button class="tile" style="min-height:110px" onclick="nav('#/article/${w.f}')">
      <span class="msr" style="font-size:36px">auto_stories</span><b style="font-size:13px">${esc(w.t)}</b></button>`).join('')}</div>`;
});

/* ================= STATIC INFO SCREENS (nwezh hub content) ================= */
async function staticData(){return await J(RAWD+'generated_static.json',{ttl:12*3600e3});}
function renderStatic(container,blocks){
  container.innerHTML=blocks.map(b=>{
    if(b.id==='title'||b.w)return `<div class="static-block"><div class="w">${esc(b.w||b.text||'')}</div>${b.text&&b.w&&b.text!==b.w?`<p>${esc(b.text)}</p>`:''}</div>`;
    return `<div class="static-block"><p>${esc(b.text||'')}</p></div>`;
  }).join('');
}
route(/^#\/static\/(.+)$/,async(m,v)=>{
  const key=m[1];
  const NAMES={fate7a:'سوورەتی فاتیحە',dastnwezh:'دەست نوێژ',error:'هەڵەکانی نوێژ',islam:'ئیسلام و باوەر',
    vsbs:'تەیەمموم',cheshtan:'نوێژی چێشتەنگاو',estyxara:'نوێژی ئیستیخارە',islam2:'ئیسلام و باوەر',
    gss:'بانگدان',hwuw:'شرۆڤەی بانگ',manaynwezh:'مانای نوێژ',hwhe:'نوێژە فەڕزەکان',whw:'نوێژی جەژن',
    page123:'نوێژی ویتڕ',dasalatakan:'دوعاکانی نوێژ',seetine:'سیەرەتی پێغەمبەر ﷺ',brdnapesh:'بڕدانەپەش',
    bayani:'بەیانی',eywara:'ئێوارە',sleep:'خەوتن',swrat:'سوورەتەکان',seng:'سەنگ',nwezhi:'بەتاڵکردنەوەی نوێژ'};
  setTitle(NAMES[key]||'زانیاری');
  v.innerHTML=`<div class="appbar2"><span class="msr">info</span><h1>${esc(NAMES[key]||'')}</h1></div><div class="card"><div class="spinner"></div></div>`;
  try{
    const data=await staticData();
    const blocks=data[key];
    if(!blocks||!blocks.length)throw 0;
    const box=v.querySelector('.card');box.classList.remove('card');box.className='card';box.innerHTML='';
    renderStatic(box,blocks);
  }catch(e){v.innerHTML+='<div class="card"><div class="empty">ئەم بەشە تەنها لە ئەپەکە بەردەستە — بەم زووانە لێرەش دادەنرێت</div></div>';}
});

/* ================= NWEZH HUB (20 cards) ================= */
route(/^#\/nwezh$/,async(m,v)=>{
  setTitle('نوێژکردن');
  const cards=[
    ['سوورەتی فاتیحە','menu_book','#/static/fate7a'],['دەست نوێژ','clean_hands','#/static/dastnwezh'],
    ['هەڵەکانی نوێژ','error_outline','#/static/error'],['ئیسلام و باوەر','foundation','#/static/islam'],
    ['تەیەمموم','water_drop','#/static/vsbs'],['چونە سەرئاو','shower','#/static/awrstan'],
    ['بانگدان','campaign','#/static/gss'],['مانای نوێژ','translate','#/static/manaynwezh'],
    ['بەتاڵکردنەوەی نوێژ','disabled_by_default','#/static/nwezhi'],['نوێژە فەڕزەکان','mosque','#/static/hwhe'],
    ['شەونوێژ','dark_mode','#/static/shawnwezh'],['نوێژی ئیستیخارە','help_center','#/static/estyxara'],
    ['نوێژی چێشتەنگاو','soup_kitchen','#/static/cheshtan'],['نوێژی جەژن','celebration','#/static/whw'],
    ['زیکرەکان','self_improvement','#/article/zikrakan.json'],['دوعاکانی نوێژ','waving_hand','#/duas'],
    ['کاتەکانی مانگ','calendar_month','#/month'],['ڕێکخستنی بانگ','notifications_active','#/bang'],
    ['کاتەکانی بانگ','access_time','#/prayer'],['پرسیار و وەڵام','quiz','#/quiz']];
  v.innerHTML=`<div class="appbar2"><span class="msr">mosque</span><h1>نوێژکردن</h1></div>
    <div class="grid2">${cards.map(c=>`<button class="tile" style="min-height:100px" onclick="nav('${c[2]}')">
      <span class="msr" style="font-size:34px">${c[1]}</span><b style="font-size:13px">${esc(c[0])}</b></button>`).join('')}</div>`;
});

/* ================= DUAS (prayer duas — duha.db) ================= */
route(/^#\/duas$/,async(m,v)=>{
  setTitle('دوعاکانی نوێژ');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let list=[];try{list=await J(REL+'data/duas.json',{nocache:true});}catch(e){}
  v.innerHTML=`<div class="appbar2"><span class="msr">waving_hand</span><h1>دوعاکانی نوێژ (${ku(list.length)})</h1></div>
    <div class="card" style="padding:0">${list.map((d,i)=>`
    <div class="item" style="display:block;cursor:default">
      <div style="display:flex;justify-content:space-between;align-items:center;gap:8px">
        <span class="num">${ku(i+1)}</span>
        <span style="display:flex;gap:2px">
          ${FAV.heart('article','duas|'+i,'دوعای '+ku(i+1),null)}
          <button class="abtn" onclick="shareText('${esc(d.a)}\n\n${esc(d.w||'')}\n\n#ڕێگای_ئیسلام')"><span class="msr">share</span></button>
        </span></div>
      <div style="font-family:'Quran',serif;font-size:21px;line-height:2.1;margin:10px 0">${esc(d.a)}</div>
      <div style="font-size:12.5px;color:var(--muted);line-height:2">${esc(d.w||'')}</div>
    </div>`).join('')}</div>`;
});

/* ================= PRAYER SCREEN ================= */
route(/^#\/prayer$/,async(m,v)=>{
  setTitle('کاتەکانی بانگ');
  await TIMES.get();
  const names={bayani:'بەیانی',xorhalatn:'گزنک',niwaro:'نیوەڕۆ',asr:'عەسر',eywara:'ئێوارە',esha:'خەوتنان'};
  v.innerHTML=`<div class="appbar2"><span class="msr">access_time</span><h1>کاتەکانی بانگ</h1></div>
    <div class="card">
      <div class="row"><select id="prCity" onchange="P.set('city',this.value);prRender()">${TIMES.d.map(c=>`<option value="${c.id}" ${c.id===P.get('city','Hawler')?'selected':''}>${esc(c.name)}</option>`).join('')}</select></div>
      <div class="date3" id="prDate"></div>
      <div id="prTimes" class="times"></div>
      <div style="display:flex;gap:8px;margin-top:12px">
        <button class="btn block" onclick="nav('#/month')"><span class="msr">calendar_month</span>کاتەکانی مانگ</button>
      </div>
    </div>`;
  prRender();
});
function prRender(){
  const c=TIMES.city();if(!c)return;
  $('#prDate').innerHTML=date3html();
  const d=new Date(),key=String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
  const row=c.days[key];
  const N=['بەیانی','گزنک','نیوەڕۆ','عەسر','ئێوارە','خەوتنان'];
  const now=d.getHours()*60+d.getMinutes();
  let ni=-1;
  if(row)for(let i=0;i<6;i++){const p=row[i].split(':');if(+p[0]*60+ +p[1]>now){ni=i;break;}}
  $('#prTimes').innerHTML=N.map((n,i)=>`<div class="time ${i===ni?'now':''}"><div class="n">${n}</div><div class="v">${row?row[i]:'--'}</div></div>`).join('');
}

/* ================= MONTH TABLE ================= */
route(/^#\/month$/,async(m,v)=>{
  setTitle('کاتەکانی مانگ');
  await TIMES.get();
  v.innerHTML=`<div class="appbar2"><span class="msr">calendar_month</span><h1>کاتەکانی مانگ</h1></div>
    <div class="card">
      <div class="row">
        <select id="mCity" onchange="monthRender()">${TIMES.d.map(c=>`<option value="${c.id}" ${c.id===P.get('city','Hawler')?'selected':''}>${esc(c.name)}</option>`).join('')}</select>
        <select id="mMon" onchange="monthRender()">${KU_MONTHS.map((mn,i)=>`<option value="${i+1}" ${i===new Date().getMonth()?'selected':''}>${mn}</option>`).join('')}</select>
      </div>
      <div class="tblwrap" id="mTbl"></div>
    </div>`;
  monthRender();
});
function monthRender(){
  const c=TIMES.d.find(x=>x.id===$('#mCity').value);const mon=+$('#mMon').value;
  const year=new Date().getFullYear();
  const N=['بەیانی','گزنک','نیوەڕۆ','عەسر','ئێوارە','خەوتنان'];
  const today=new Date(),tk=String(today.getMonth()+1).padStart(2,'0')+'-'+String(today.getDate()).padStart(2,'0');
  let rows='';
  for(let day=1;day<=31;day++){
    const key=String(mon).padStart(2,'0')+'-'+String(day).padStart(2,'0');
    const row=c.days[key];if(!row)continue;
    const dt=new Date(year,mon-1,day);
    rows+=`<tr class="${key===tk?'today':''}"><td>${ku(day)} ${WEEK[dt.getDay()]}</td>${row.map(t=>`<td>${t}</td>`).join('')}</tr>`;
  }
  $('#mTbl').innerHTML=`<table class="times"><thead><tr><th>بەروار</th>${N.map(n=>`<th>${n}</th>`).join('')}</tr></thead><tbody>${rows}</tbody></table>`;
}

/* ================= QIBLA ================= */
route(/^#\/qibla$/,async(m,v)=>{
  setTitle('قیبلەنما');
  v.innerHTML=`<div class="appbar2"><span class="msr">explore</span><h1>قیبلەنما</h1></div>
    <div class="card">
      <div class="compass"><div class="needle" id="needle"></div><div class="deg" id="qdeg">--</div></div>
      <div class="comp-note" id="qnote">کرتە لە دوگمەکە بکە بۆ کردنەوەی کۆمپاسی</div>
      <button class="btn block" onclick="startCompass()"><span class="msr">explore</span>کردنەوەی قیبلەنما</button>
    </div>`;
});
function bearingToKaaba(lat,lng){
  const kLat=21.4225*Math.PI/180,kLng=39.8262*Math.PI/180;
  const p1=lat*Math.PI/180,dl=kLng-lng*Math.PI/180;
  const y=Math.sin(dl)*Math.cos(kLat);
  const x=Math.cos(p1)*Math.sin(kLat)-Math.sin(p1)*Math.cos(kLat)*Math.cos(dl);
  return (Math.atan2(y,x)*180/Math.PI+360)%360;
}
function startCompass(){
  if(!navigator.geolocation){$('#qnote').textContent='ناوخۆکە بەردەست نییە';return;}
  navigator.geolocation.getCurrentPosition(p=>{
    window._qb=bearingToKaaba(p.coords.latitude,p.coords.longitude);
    $('#qdeg').textContent='گۆشەی قیبلە: '+window._qb.toFixed(1)+'°';
    $('#qnote').textContent='مۆبایلەکە بچرخێنە هەتا کەعبەکە بۆ سەرەوە بێت';
    listenCompass();
  },()=>{$('#qnote').textContent='ڕێگەی ناوخۆکە نەدرا — مۆڵەت بدە';});
}
function listenCompass(){
  const handler=e=>{
    if(e.alpha==null)return;
    const heading=360-e.alpha;
    const rot=window._qb!=null?(window._qb-heading):(0-heading);
    $('#needle').style.transform=`translate(-50%,-100%) rotate(${rot}deg)`;
    if(window._qb!=null){
      const diff=Math.abs((window._qb-heading+540)%360-180);
      $('#qnote').className='comp-note'+(diff<8?' ok':'');
      $('#qnote').textContent=diff<8?'ئەمە ئاڕاستەی قیبلەیە ✅':'مۆبایلەکە بچرخێنە هەتا کەعبەکە بۆ سەرەوە بێت';
    }
  };
  if(window.DeviceOrientationEvent&&DeviceOrientationEvent.requestPermission){
    DeviceOrientationEvent.requestPermission().then(s=>{
      if(s==='granted')window.addEventListener('deviceorientation',handler,true);
    }).catch(()=>{});
  }else{
    window.addEventListener('deviceorientationabsolute',handler,true);
    window.addEventListener('deviceorientation',handler,true);
  }
}

/* ================= RUQYA ================= */
route(/^#\/ruqya$/,async(m,v)=>{
  setTitle('ڕوقیەی شەرعی');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let items=[];try{items=await J(RAWD+'taybat.json',{ttl:12*3600e3});}catch(e){}
  const RANGES=[[1,1,7,'سوورەتی فاتیحە'],[2,255,255,'ئایەتی کورسی'],[2,285,286,'بەقەرە ٢٨٥-٢٨٦'],[7,117,122,'ئەعراف ١١٧-١٢٢'],[10,81,82,'یونس ٨١-٨٢'],[20,69,69,'طه ٦٩'],[112,1,5,'ئەخلاص'],[113,1,5,'فەلەق'],[114,1,6,'ناس']];
  v.innerHTML=`<div class="appbar2"><span class="msr">healing</span><h1>ڕوقیەی شەرعی</h1></div>
    <div class="card"><h2><span class="msr">headphones</span>ڕوقیە بە دەنگ (${ku(items.length)})</h2>
    <div class="list" style="max-height:330px">${items.map((x,i)=>`
      <div class="item" onclick="AU.play('${esc(x.link||'')}').catch(audioError);toast('دەنگ دەست پێکرد ▶')">
        <span>${esc(x.title||x.namefile||'ڕوقیە '+ku(i+1))}</span><span class="num">▶</span></div>`).join('')}</div></div>
    <div class="card"><h2><span class="msr">menu_book</span>ڕوقیە بە نووسین</h2>
      <div class="chipset">${RANGES.map((r,i)=>`<button class="chip" onclick="ruqyaText(${i})">${esc(r[3])}</button>`).join('')}</div>
      <div id="rqTxt" style="margin-top:12px"></div>
    </div>`;
  window._rq=RANGES;ruqyaText(0);
});
async function ruqyaText(i){
  const [s,a,b,name]=window._rq[i];
  await Q.load();
  const box=$('#rqTxt');
  box.innerHTML=`<div style="font-size:13px;font-weight:700;color:var(--accent);margin-bottom:8px">${esc(name)}</div>`+
    Q.sura(s).filter(x=>x.n>=a&&x.n<=b).map(x=>`<div style="font-family:'Quran',serif;font-size:22px;line-height:2.2;text-align:center;padding:6px 0">${esc(x.t)}</div>`).join('');
}

/* ================= RAMADAN ================= */
route(/^#\/ramadan$/,async(m,v)=>{
  setTitle('مانگی ڕەمەزان');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let ram=null;try{ram=await J(REL+'data/ramadan.json',{nocache:true});}catch(e){}
  if(!ram){v.innerHTML='<div class="card"><div class="empty">بارنەبوو</div></div>';return;}
  const tabs=ram.titles||[];
  v.innerHTML=`<div class="appbar2"><span class="msr">dark_mode</span><h1>مانگی ڕەمەزان</h1></div>
    <div class="tagbar">${tabs.map((t,i)=>`<button class="${i===0?'active':''}" id="rtab${i}" onclick="ramTab(${i})">${esc(t.titles)}</button>`).join('')}</div>
    <div id="ramBox"></div>`;
  window._ram=ram;ramTab(0);
});
function ramTab(i){
  const ram=window._ram;const t=ram.titles[i];
  $$('.tagbar button').forEach(b=>b.classList.remove('active'));
  const tb=$('#rtab'+i);if(tb)tb.classList.add('active');
  const items=ram[t.tableName]||[];
  $('#ramBox').innerHTML=`<div class="card" style="padding:0">${items.map(x=>`
    <div class="item" style="display:block;cursor:default">
      <b style="color:var(--accent);font-size:14px">${esc(x.title||'')}</b>
      <p style="font-size:13px;line-height:2.1;white-space:pre-wrap;margin-top:6px">${esc(x.desc||'')}</p>
    </div>`).join('')||'<div class="empty">بەتاڵە</div>'}</div>`;
}

/* ================= TAWBA ================= */
route(/^#\/tawba$/,async(m,v)=>{
  setTitle('چۆن تۆبە بکەم');
  let t=null;try{t=await J(REL+'data/tawba.json',{nocache:true});}catch(e){}
  if(!t){v.innerHTML='<div class="card"><div class="empty">بارنەبوو</div></div>';return;}
  window._tawba=t;
  const secs=t.babatakan||[];
  v.innerHTML=`<div class="appbar2"><span class="msr">change_circle</span><h1>چۆن تۆبە بکەم</h1></div>
    <div class="card" style="padding:0">${secs.map((s,i)=>`
    <div class="item" onclick="tawbaSec('${esc(s.tableName)}')"><b>${esc(s.title)}</b><span class="msr" style="color:var(--muted)">chevron_left</span></div>`).join('')}</div>`;
});
function tawbaSec(tb){
  const items=window._tawba[tb]||[];
  openSheet(`<h3><span class="msr">menu_book</span>بەشەکە</h3>
    <div style="max-height:60vh;overflow-y:auto">${items.map(x=>`
      <b style="color:var(--accent);font-size:13.5px;display:block;margin-top:10px">${esc(x.title||'')}</b>
      <p style="font-size:13px;line-height:2.1;white-space:pre-wrap;margin-top:4px">${esc(x.desc||'')}</p>`).join('')}</div>`);
}

/* ================= SAHIH MUSLIM ================= */
route(/^#\/muslim$/,async(m,v)=>{
  setTitle('پوختەی سەحیحی موسلیم');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let mu=null;try{mu=await J(REL+'data/muslim.json',{nocache:true});}catch(e){}
  if(!mu){v.innerHTML='<div class="card"><div class="empty">بارنەبوو</div></div>';return;}
  window._mu=mu;
  v.innerHTML=`<div class="appbar2"><span class="msr">format_quote</span><h1>پوختەی سەحیحی موسلیم (${ku(mu.sarki.length)} بەش)</h1></div>
    <div class="card" style="padding:0">${mu.sarki.map(s=>`
    <div class="item" onclick="muslimSec('${esc(s.tag)}')"><b style="font-size:13px">${esc(s.title)}</b><span class="msr" style="color:var(--muted)">chevron_left</span></div>`).join('')}</div>`;
});
function muslimSec(tag){
  const items=window._mu.babat.filter(b=>b.b===tag);
  openSheet(`<h3><span class="msr">format_quote</span>فەرموودەکان (${ku(items.length)})</h3>
    <div style="max-height:65vh;overflow-y:auto">${items.map(x=>`
      <div style="border-bottom:1px solid var(--line);padding:12px 0">
        <b style="color:var(--gold);font-size:12px">${esc(x.s||'')}</b>
        <p style="font-size:13.5px;line-height:2.2;margin-top:6px">${esc(x.d||'')}</p>
        ${x.f?`<p style="font-size:11.5px;color:var(--muted);margin-top:4px">${esc(x.f)}</p>`:''}
      </div>`).join('')}</div>`);
}

/* ================= AYATUL KURSI ================= */
route(/^#\/kursi$/,async(m,v)=>{
  setTitle('ئایەتی کورسی');await Q.load();
  const a=Q.sura(2).find(x=>x.n===255);
  v.innerHTML=`<div class="appbar2"><span class="msr">menu_book</span><h1>ئایەتی کورسی</h1></div>
    <div class="card" style="text-align:center">
      <div style="font-family:'Quran',serif;font-size:26px;line-height:2.4">${esc(a.t)}</div>
      <div style="display:flex;gap:8px;justify-content:center;margin-top:14px">
        <button class="btn" onclick="AU.play('${CDN_AYAH}262.mp3').catch(audioError)"><span class="msr">volume_up</span>دەنگ</button>
        <button class="btn gold" onclick="nav('#/read/2/255')"><span class="msr">menu_book</span>لە قورئان</button>
        ${FAV.heart('ayah','2:255','بەقەرە ئایەتی ٢٥٥ (کورسی)',null)}
      </div>
    </div>`;
});

/* ================= FRIDAY ZIKR ================= */
route(/^#\/zikrfriday$/,async(m,v)=>{
  setTitle('سونەتەکانی ڕۆژی هەینی');
  try{
    const items=await article('zikrakan.json');
    const friday=items.filter(x=>(x.title||'').includes('هەینی')||(x.text||'').includes('سەڵاوات'));
    const list=friday.length?friday:items.slice(0,10);
    v.innerHTML=`<div class="appbar2"><span class="msr">favorite</span><h1>سونەتەکانی ڕۆژی هەینی</h1></div>
      <div class="card" style="padding:0 14px">${list.map((x,i)=>`
      <div class="art ${i===0?'open':''}"><div class="h" onclick="this.parentNode.classList.toggle('open')"><b>${esc(x.title||'')}</b><span class="msr">keyboard_arrow_down</span></div>
      <div class="b">${esc(x.text)}</div></div>`).join('')}</div>`;
  }catch(e){v.innerHTML='<div class="card"><div class="empty">بارنەبوو</div></div>';}
});

/* ================= TASBIH TAB ================= */
route(/^#\/tasbih$/,async(m,v)=>{
  setTitle('تەسبیح');
  const ziks=P.get('ziks',[['سوبحان الله',33],['الحمد لله',33],['الله أكبر',34]]);
  const zi=Math.min(P.get('zidx',0),ziks.length-1);
  const z=ziks[zi]||ziks[0];
  v.innerHTML=`<div class="tasbih-wrap">
    <button class="tzname" onclick="tzPick()"><span class="msr">expand_more</span><span id="tzName">${esc(z[0])}</span></button>
    <button class="tcircle" onclick="tzTap()"><span class="cnt" id="tzCnt">${ku(P.get('zcnt',0))}</span><span class="tgt">لە ${ku(z[1])}</span></button>
    <div class="tmeta"><span>خول: <b id="tzRound">${ku(P.get('zround',0))}</b></span><span>کۆی گشتی: <b id="tzTotal">${ku(P.get('ztotal',0))}</b></span></div>
    <div style="display:flex;gap:8px;margin-top:16px">
      <button class="btn ghost block" onclick="tzReset()"><span class="msr">refresh</span>سفرکردن</button>
    </div></div>`;
});
function tzPick(){
  const ziks=P.get('ziks',[['سوبحان الله',33],['الحمد لله',33],['الله أكبر',34]]);
  openSheet(`<h3><span class="msr">fingerprint</span>زیکر هەڵبژێرە</h3>
    ${ziks.map((z,i)=>`<div class="item" onclick="tzSel(${i})"><span>${esc(z[0])}</span><span class="num">${ku(z[1])}</span></div>`).join('')}
    <div class="item" onclick="tzAdd()"><span style="color:var(--accent);font-weight:700">+ زیکری نوێ</span></div>`);
}
function tzSel(i){P.set('zidx',i);P.set('zcnt',0);closeSheet();render();}
function tzAdd(){
  const n=prompt('زیکرەکە بنووسە — وەک: لا إله إلا الله');if(!n)return;
  const t=+prompt('ئامانج (چەند جار؟)','33')||33;
  const ziks=P.get('ziks',[]);ziks.push([n,t]);P.set('ziks',ziks);tzSel(ziks.length-1);
}
function tzTap(){
  const ziks=P.get('ziks',[['سوبحان الله',33],['الحمد لله',33],['الله أكبر',34]]);
  const z=ziks[P.get('zidx',0)]||ziks[0];
  let c=P.get('zcnt',0)+1;
  let r=P.get('zround',0),t=P.get('ztotal',0)+1;
  if(c>=z[1]){c=0;r++;if(navigator.vibrate)navigator.vibrate(120);toast('خولێک تەواو بوو ✅');}
  else if(navigator.vibrate)navigator.vibrate(18);
  P.set('zcnt',c);P.set('zround',r);P.set('ztotal',t);
  $('#tzCnt').textContent=ku(c);
  $('#tzRound').textContent=ku(r);
  $('#tzTotal').textContent=ku(t);
}
function tzReset(){P.set('zcnt',0);render();}

/* ================= BANG VOICES ================= */
route(/^#\/bang$/,async(m,v)=>{
  setTitle('دەنگی بانگبێژ');
  v.innerHTML='<div class="spinner" style="margin-top:40px"></div>';
  let vs=[];try{vs=await J(RAWD+'dangebangbezh.json',{ttl:24*3600e3});}catch(e){}
  v.innerHTML=`<div class="appbar2"><span class="msr">campaign</span><h1>دەنگی بانگبێژ (${ku(vs.length)})</h1></div>
    <div class="list">${vs.map((x,i)=>`
    <div class="item" onclick="AU.play('https://github.com/quranofficial/DangeBangBezh/raw/main/${esc(x.text)}.mp3').catch(audioError)">
      <span>${esc(x.title||'بانگ '+ku(i+1))}</span><span class="num">▶</span></div>`).join('')}</div>
    <p style="font-size:11.5px;color:var(--muted);margin-top:8px;line-height:1.9">کرتە لە هەر دەنگێک بکە بۆ بیستنی.</p>`;
});

/* ================= REORDER HOME ================= */
route(/^#\/reorder$/,async(m,v)=>{
  setTitle('ڕێکخستنی بەشەکان');
  const items=gridItems();
  v.innerHTML=`<div class="appbar2"><span class="msr">swap_vert</span><h1>ڕێکخستنی بەشەکان</h1></div>
    <p style="font-size:12px;color:var(--muted);margin-bottom:10px;line-height:1.9">بە تیرەکان جێگەی بەشەکان بگۆڕە — ناوەکەش دەتوانیت بگۆڕیت.</p>
    <div class="card" style="padding:0">${items.map((g,i)=>`
    <div class="item" draggable="true" data-i="${g.idx}" id="ro${g.idx}">
      <span style="display:flex;gap:8px;align-items:center"><span class="msr" style="color:var(--muted);font-size:18px">drag_indicator</span>${esc(g.t)}</span>
      <span style="display:flex;gap:2px">
        <button class="abtn" onclick="roRename(${g.idx})"><span class="msr">edit</span></button>
        <button class="abtn" onclick="roMove(${g.idx},-1)"><span class="msr">arrow_upward</span></button>
        <button class="abtn" onclick="roMove(${g.idx},1)"><span class="msr">arrow_downward</span></button>
      </span></div>`).join('')}</div>
    <button class="btn red block" style="margin-top:10px" onclick="P.del('grid_order');P.del('grid_labels');toast('گەڕایەوە بۆ بنەڕەت');render()"><span class="msr">restart_alt</span>گەڕانەوە بۆ ڕیزبەندی بنەڕەت</button>`;
  roDrag();
});
function roMove(idx,d){
  let order=P.get('grid_order',null)||GRID.map((_,i)=>i);
  let labels=P.get('grid_labels',{});
  // current visible items in order
  let vis=order.map(i=>i);
  const pos=vis.indexOf(idx);
  const np=pos+d;
  if(np<0||np>=vis.length)return;
  [vis[pos],vis[np]]=[vis[np],vis[pos]];
  P.set('grid_order',vis);
  // keep label overrides attached
  saveLabels(labels);
  render();
}
function saveLabels(labels){P.set('grid_labels',labels);}
function roRename(idx){
  const g=GRID[idx];
  const labels=P.get('grid_labels',{});
  const n=prompt('ناوی نوێ:',(labels[idx]||g.t));if(n==null)return;
  labels[idx]=n;saveLabels(labels);render();
}
function roDrag(){
  let src=null;
  $$('#view .item[draggable]').forEach(el=>{
    el.ondragstart=e=>{src=el;el.classList.add('drag');};
    el.ondragend=()=>{el.classList.remove('drag');};
    el.ondragover=e=>{e.preventDefault();};
    el.ondrop=e=>{
      e.preventDefault();if(!src||src===el)return;
      const a=+src.dataset.i,b=+el.dataset.i;
      let order=P.get('grid_order',null)||GRID.map((_,i)=>i);
      const ia=order.indexOf(a),ib=order.indexOf(b);
      order.splice(ia,1);order.splice(ib,0,a);
      P.set('grid_order',order);render();
    };
  });
}
/* grid labels applied in gridItems: patch core? do here: override */
const _gridItemsOrig=gridItems;
gridItems=function(){
  const items=_gridItemsOrig();
  const labels=P.get('grid_labels',{});
  return items.map(x=>({...x,t:labels[x.idx]||x.t}));
};

/* ================= SETTINGS TAB ================= */
route(/^#\/settings$/,async(m,v)=>{
  setTitle('ڕێکخستن');
  const socials=[['facebook','https://www.facebook.com/profile.php?id=100076875589539','فەیسبووک'],
    ['send','https://t.me/Regayislam_1','تەلەگرام'],['music_note','https://www.tiktok.com/@regayislam55','تیک تاک']];
  v.innerHTML=`
    <div class="card" style="text-align:center">
      <img src="logo.png" style="width:76px;border-radius:20px">
      <h2 style="justify-content:center;margin-top:8px">ڕێگای ئیسلام</h2>
      <p style="font-size:12px;color:var(--muted)">وەشان v71.0 • وێبسایت وەک ئەپەکە</p>
      <button class="btn gold" style="margin-top:8px" onclick="shareApp()"><span class="msr">share</span>هاوبەشی ئەپ</button>
    </div>
    <div class="card"><h2><span class="msr">download</span>داگرتن</h2>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <a class="btn block" style="flex:1" href="https://linkakam.com/Regayislam" target="_blank" rel="noopener"><span class="msr">language</span>لینکی داگرتن</a>
        <a class="btn ghost block" style="flex:1" href="https://github.com/quranofficial/RegayIslam-iOS/releases" target="_blank" rel="noopener"><span class="msr">android</span>APK</a>
      </div></div>
    <div class="card"><h2><span class="msr">tune</span>ڕێکخستنەکان</h2>
      <div class="item" style="border:none;padding:10px 0" onclick="nav('#/editor')"><span style="display:flex;gap:8px;align-items:center"><span class="msr">edit_note</span>ئیدیتی قورئان</span><span class="msr" style="color:var(--muted)">chevron_left</span></div>
      <div class="item" style="border:none;padding:10px 0" onclick="nav('#/bang')"><span style="display:flex;gap:8px;align-items:center"><span class="msr">campaign</span>دەنگی بانگبێژ</span><span class="msr" style="color:var(--muted)">chevron_left</span></div>
      <div class="item" style="border:none;padding:10px 0" onclick="nav('#/prayer')"><span style="display:flex;gap:8px;align-items:center"><span class="msr">location_on</span>شار (کاتەکانی نوێژ)</span><span class="msr" style="color:var(--muted)">chevron_left</span></div>
    </div>
    <div class="card"><h2><span class="msr">forum</span>پەیام و ڕەخنە</h2>
      <input id="fbName" placeholder="ناوت" value="${esc(P.get('myname',''))}">
      <textarea id="fbTxt" rows="3" placeholder="پەیامەکەت بنووسە..." style="margin-top:8px"></textarea>
      <button class="btn block" style="margin-top:8px" onclick="fbSend()"><span class="msr">send</span>ناردن</button>
    </div>
    <div class="card"><h2><span class="msr">link</span>پەیوەندی</h2>
      <div style="display:flex;gap:8px">${socials.map(s=>`<a class="btn ghost" style="flex:1" href="${s[1]}" target="_blank" rel="noopener"><span class="msr">${s[0]}</span>${s[2]}</a>`).join('')}</div>
    </div>
    <div class="card"><h2><span class="msr">info</span>دەربارە</h2><div id="aboutBox" style="font-size:12.5px;line-height:2;color:var(--muted)"><div class="spinner"></div></div></div>
    <footer class="credit">ڕێگای ئیسلام — خزمەتگوزاری ئاینی بە زمانی کوردی<br>
      <a href="https://linkakam.com/Regayislam" target="_blank" rel="noopener">linkakam.com/Regayislam</a></footer>`;
  db.get('bandaccount').then(x=>{const b=unwrap(x);
    if(b&&$('#aboutBox'))$('#aboutBox').textContent=b.about||b.text||b.title||'';}).catch(()=>{});
});
async function fbSend(){
  const n=($('#fbName').value||'').trim(),t=($('#fbTxt').value||'').trim();
  if(!n||!t){toast('ناو و پەیام پڕ بکەرەوە');return;}
  P.set('myname',n);
  const d=new Date();
  try{
    await db.push('feedback',{name:n,message:t,date:d.toISOString().slice(0,10),app:'regayislam-web'});
    toast('پەیامەکەت نێردرا — سوپاس ✅');$('#fbTxt').value='';
  }catch(e){toast('نەنێردرا — دووبارە هەوڵبدەرەوە');}
}
