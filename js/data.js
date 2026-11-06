/* ============ ڕێگای ئیسلام — data layer: fetch cache, RTDB, registries, hijri ============ */
'use strict';

/* ---------- generic fetch with in-memory + localStorage cache ---------- */
const MEM={};
async function J(url,opts){
  opts=opts||{};
  if(MEM[url]&&!opts.fresh)return MEM[url];
  const ck='c:'+url;
  if(!opts.fresh&&!opts.nocache){
    const c=P.get(ck,null);
    if(c&&(Date.now()-c.t<(opts.ttl||6*3600e3)))return c.d;
  }
  const r=await fetch(url);
  if(!r.ok)throw new Error('http '+r.status);
  const d=await r.json();
  MEM[url]=d;
  if(!opts.nocache)P.set(ck,{t:Date.now(),d:d});
  return d;
}
async function JT(url){ // json-or-string (Sketchware nodes sometimes store JSON strings)
  const d=await J(url);
  return d;
}
function unwrap(x){ // unwrap JSON strings / {node:{...}} wrappers like the app (recursive)
  let guard=0;
  while(guard++<8){
    if(x==null)return null;
    if(typeof x==='string'){try{x=JSON.parse(x);continue}catch(e){return x}}
    if(Array.isArray(x))return x;
    if(typeof x==='object'){
      const ks=Object.keys(x);
      if(ks.length===1){const v=x[ks[0]];if(v&&(typeof v==='object'||typeof v==='string')){x=v;continue}}
      return x;
    }
    return x;
  }
  return x;
}

/* ---------- sources ---------- */
const RAW='https://raw.githubusercontent.com/quranofficial/RegayIslam-iOS/main/';
const DBB='https://regayislam-1-default-rtdb.firebaseio.com';
const REL=''; // same-site data/

const db={
  async get(path){const r=await fetch(`${DBB}/${path}.json`);if(!r.ok)throw 0;return r.json();},
  async patch(path,obj){
    const r=await fetch(`${DBB}/${path}.json`,{method:'PATCH',body:JSON.stringify(obj),
      headers:{'Content-Type':'application/json'}});
    if(!r.ok)throw 0;return r.json();
  },
  async push(path,obj){
    const r=await fetch(`${DBB}/${path}.json`,{method:'POST',body:JSON.stringify(obj),
      headers:{'Content-Type':'application/json'}});
    if(!r.ok)throw 0;return r.json(); // {name: key}
  }
};

/* ---------- article registry (exact app home-card mapping) ---------- */
const RAWD=RAW+'assets/data/';
const ARTICLES=[
  {f:'zikrakan.json',t:'زیکرەکان'},
  {f:'duha.json',t:'دوعا و پاڕانەوە'},
  {f:'agr.json',t:'ئەهلی ئاگر'},
  {f:'bahasht.json',t:'بەهەشت'},
  {f:'xawn.json',t:'خەونامە'},
  {f:'wta.json',t:'وتە و ئامۆژگاری'},
  {f:'zianakanygorani.json',t:'زیانەکانی گۆرانی'},
  {f:'pexambarman.json',t:'ژیانی پێغەمبەرمان ﷺ'},
  {f:'pexambaran.json',t:'ژیانی پێغەمبەران'},
  {f:'haram.json',t:'حەڕام کراوەکان'},
  {f:'swnat.json',t:'سونەت'},
  {f:'xaybat.json',t:'تاوانی غەیبەت'},
  {f:'dajal.json',t:'چیرۆکی دەجال'},
  {f:'hawal.json',t:'هاوەڵانی پێغەمبەر ﷺ'},
  {f:'zanyaryquran.json',t:'زانیاری قورئان'},
  {f:'tawanakan.json',t:'تاوانەگەورەکان'},
  {f:'rawbochwn.json',t:'ڕاو بۆچونەکان'},
  {f:'dozax.json',t:'دۆزەخ'},
  {f:'hajw.json',t:'حەج و عومرە'},
];
const ART_WOMEN=[{f:'gggg.json',t:'چل فەرموودە دەربارەی ئافرەتان'},{f:'girlss.json',t:'پرسیار و وەڵامی ئافرەتان'},{f:'balaposhi.json',t:'باڵاپۆشی'}];
async function article(f){
  const d=await J(RAWD+f,{ttl:6*3600e3});
  let a=Array.isArray(d)?d:(d.items||d.data||[]);
  if(!Array.isArray(a))a=[];
  return a.map((x,i)=>({i:i,title:x.title||x.name||'',text:x.text||x.desc||'',extra:x.extratext||x.sc||''}));
}
function findArticle(file){return ARTICLES.concat(ART_WOMEN).find(a=>a.f===file);}

/* ---------- quran ---------- */
const Q={list:null,surat:null,tafsirs:{},
  async load(){
    if(this.list)return;
    const r=await Promise.all([J(REL+'data/quran.json',{nocache:true}),J(REL+'data/surat.json',{nocache:true})]);
    this.list=r[0];this.surat=r[1];
  },
  async tafsir(col){
    if(this.tafsirs[col])return this.tafsirs[col];
    const d=await J(REL+'data/tafsir/'+col+'.json',{nocache:true});
    this.tafsirs[col]=d;return d;
  },
  sura(n){return this.list.filter(a=>a.s===n)},
  suratMeta(n){return this.surat.find(s=>s.i===n)},
  global(s,n){let g=0;for(const x of this.surat){if(x.i<s)g+=x.aya;else break;}return g+n;}
};

/* ---------- hijri + kurdish dates (same algorithm as app) ---------- */
const KU_MONTHS=['کانوونی دووەم','شوبات','ئازار','نیسان','ئایار','حوزەیران','تەمووز','ئاب','ئەیلوول','تشرینی یەکەم','تشرینی دووەم','کانوونی یەکەم'];
const HIJRI_MONTHS=['موحەڕەم','سەفەر','ڕەبیع الاول','ڕەبیعی دووەم','جەمادیولولا','جەمادیولاخر','ڕەجەب','شەعبان','ڕەمەزان','شەوال','زولقەعدە','زولحەججە'];
const WEEK=['یەکشەممە','دووشەممە','سێشەممە','چوارشەممە','پێنجشەممە','هەینی','شەممە'];
function hijriOf(d){
  const F=Math.floor;
  const y2=d.getFullYear()+4800-F((14-(d.getMonth()+1))/12);
  const m2=(d.getMonth()+1)+12*F((14-(d.getMonth()+1))/12)-3;
  let jdn=d.getDate()+F((153*m2+2)/5)+365*y2+F(y2/4)-F(y2/100)+F(y2/400)-32045;
  let l=jdn-1948440+10632;
  const n=F((l-1)/10631);
  l=l-10631*n+354;
  const j=F((10985-l)/5316)*F((50*l)/17719)+F(l/5670)*F((43*l)/15238);
  l=l-F((30-j)/15)*F((17719*j)/50)-F(j/16)*F((15238*j)/43)+29;
  const hm=F((24*l)/709);
  const hd=l-F((709*hm)/24);
  const hy=30*n+j-30;
  return [hy,hm,hd];
}
function date3html(d){
  d=d||new Date();
  const [hy,hm,hd]=hijriOf(d);
  return `<b>${WEEK[d.getDay()]}</b> — ${ku(d.getDate())}ی ${KU_MONTHS[d.getMonth()]} ${ku(d.getFullYear())} — ${ku(hd)}ی ${HIJRI_MONTHS[hm-1]} ${ku(hy)}`;
}

/* ---------- daily ayah (same seed as app: Random(day*31+month)) ---------- */
function mulberry(seed){return function(){seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
function dailyAyah(){
  const d=new Date();
  const rnd=mulberry(d.getDate()*31+d.getMonth());
  const s=Math.floor(rnd()*114)+1;
  const meta=Q.suratMeta(s);
  const n=Math.floor(rnd()*meta.aya)+1;
  return {s,n};
}

/* ---------- audio helper (single player like the app) ---------- */
const AU={el:null,cur:'',
  init(){if(!this.el){this.el=new Audio();this.el.preload='none';}},
  play(url,onend){this.init();this.stop();
    this.el.src=url;this.cur=url;
    this.el.onended=()=>{if(onend)onend()};
    return this.el.play();},
  pause(){if(this.el)this.el.pause();},
  stop(){if(this.el){this.el.pause();this.el.currentTime=0;this.el.src='';this.cur='';}}
};
function audioError(e){toast('دەنگەکە بارنەبوو — ئینتەرنێت بپشکنە');}

/* ---------- misc ---------- */
const CDN_AYAH='https://cdn.islamic.network/quran/audio/128/ar.alafasy/';
const MUSHAF=p=>`https://raw.githubusercontent.com/GovarJabbar/Quran-PNG/master/${String(p).padStart(3,'0')}.png`;
const pad3=n=>String(n).padStart(3,'0')+'.mp3';
/* strip arabic diacritics/tatweel + unify alef/ya forms for forgiving search */
function normAr(s){return String(s||'')
  .replace(/[\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200f\u200e]/g,'')
  .replace(/[\u0622\u0623\u0625\u0671]/g,'\u0627')
  .replace(/\u0649/g,'\u064A');}
