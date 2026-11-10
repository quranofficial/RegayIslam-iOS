/* ============ ڕێگای ئیسلام — core: helpers, router, prefs, favorites ============ */
'use strict';
const $=s=>document.querySelector(s), $$=s=>[...document.querySelectorAll(s)];
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const AR=['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
const ku=n=>String(n).split('').map(c=>/\d/.test(c)?AR[+c]:c).join('');
function toast(m){const t=$('#toast');t.textContent=m;t.classList.add('show');clearTimeout(t._h);t._h=setTimeout(()=>t.classList.remove('show'),2300);}

/* ---------- prefs (localStorage) ---------- */
const P={
  get(k,d){try{const v=localStorage.getItem('ri_'+k);return v==null?d:JSON.parse(v)}catch(e){return d}},
  set(k,v){try{localStorage.setItem('ri_'+k,JSON.stringify(v))}catch(e){}},
  del(k){try{localStorage.removeItem('ri_'+k)}catch(e){}}
};
let UID=P.get('uid',null);
if(!UID){UID='web-'+Math.random().toString(36).slice(2,10)+Date.now().toString(36);P.set('uid',UID);}

/* ---------- theme ---------- */
function applyTheme(){
  const d=P.get('dark',false);
  document.body.classList.toggle('dark',d);
  $('#hTheme').innerHTML='<span class="msr">'+(d?'light_mode':'dark_mode')+'</span>';
  const m=document.querySelector('meta[name=theme-color]');
  if(m)m.content=d?'#212121':'#004D7B';
}
function toggleTheme(){P.set('dark',!P.get('dark',false));applyTheme();}

/* ---------- share ---------- */
function shareApp(){
  const url='https://linkakam.com/Regayislam';
  const txt='ئەپڵیکەیشنی ڕێگای ئیسلام — '+url+'  #ڕێگای_ئیسلام';
  if(navigator.share)navigator.share({title:'ڕێگای ئیسلام',text:txt,url}).catch(()=>{});
  else{navigator.clipboard&&navigator.clipboard.writeText(url);toast('لینکەکە کۆپی کرا ✅');}
}
function shareText(t){
  if(navigator.share)navigator.share({text:t}).catch(()=>{});
  else{navigator.clipboard&&navigator.clipboard.writeText(t);toast('کۆپی کرا ✅');}
}

/* ---------- favorites (دڵخوازەکان) ---------- */
const FAV={
  all:()=>P.get('fav',[]),
  has(t,id){return this.all().some(x=>x.t===t&&x.id===id)},
  toggle(t,id,title,extra){
    let a=this.all();
    if(this.has(t,id))a=a.filter(x=>!(x.t===t&&x.id===id));
    else a.push({t:t,id:id,title:title,extra:extra||null,ts:Date.now()});
    P.set('fav',a);return this.has(t,id);
  },
  heart(t,id,title,extra){ // returns btn html
    const on=this.has(t,id);
    return `<button class="abtn ${on?'on':''}" onclick="event.stopPropagation();favToggle('${t}','${esc(id)}','${esc(title||'')}','${esc(JSON.stringify(extra||null))}',this)"><span class="msr">${on?'favorite':'favorite_border'}</span></button>`;
  }
};
function favToggle(t,id,title,extraStr,btn){
  let extra=null;try{extra=JSON.parse(extraStr)}catch(e){}
  const on=FAV.toggle(t,id,title,extra);
  if(btn){btn.classList.toggle('on',on);btn.innerHTML='<span class="msr">'+(on?'favorite':'favorite_border')+'</span>';}
  toast(on?'خرایە ناو دڵخوازەکان ❤️':'لابرا لە دڵخوازەکان');
  if(FRefetch)FRefetch=true;
}

/* ---------- bottom sheet ---------- */
function openSheet(html){$('#sheetIn').innerHTML='<div class="grip"></div>'+html;$('#sheet').classList.add('show');}
function closeSheet(){$('#sheet').classList.remove('show');}

/* ---------- router ---------- */
let FRefetch=false; // favorites view dirty flag
const ROUTES=[]; // {re, fn}
function route(re,fn){ROUTES.push({re,fn});}
function nav(h){if(location.hash===h)render();else location.hash=h;}
function noTab(){}
function render(){
  closeSheet();
  const h=location.hash||'#/';
  let m=null,fn=null;
  for(const r of ROUTES){m=h.match(r.re);if(m){fn=r.fn;break;}}
  const v=$('#view');
  v.scrollTop=0;window.scrollTo(0,0);
  // header back visibility + title
  const top=['#/','#/quran','#/tasbih','#/settings'].includes(h);
  $('#hBack').style.display=top?'none':'';
  $$('#bnav button').forEach(b=>b.classList.toggle('active',b.dataset.r===h||(b.dataset.r==='#/'&&top)));
  if(!fn){v.innerHTML='';return;}
  fn(m,v);
}
function setTitle(t){$('#hTitle').textContent=t||'ڕێگای ئیسلام';}
window.addEventListener('hashchange',render);
