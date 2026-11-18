const { chromium } = require('playwright');
const SLIDES = {
  fr: [
    { k: 'hook', a: 'GTA 5', b: 'GTA 6', t: 'La différence en 15 secondes' },
    { k: 'row', label: 'Sortie', a: '2013', b: '2026', note: '13 ans d’écart' },
    { k: 'row', label: 'Ville', a: 'Los Santos', b: 'Vice City' },
    { k: 'row', label: 'État', a: 'San Andreas', b: 'Leonida' },
    { k: 'row', label: 'Héros', a: '3', b: '2', note: 'Michael, Franklin, Trevor vs Lucia & Jason' },
    { k: 'row', label: 'Consoles', a: 'PS3 · Xbox 360', b: 'PS5 · Xbox Series', note: 'à la sortie' },
    { k: 'end', t: 'Lequel tu préfères ?', s: 'Dis-le en commentaire', h: '@vicecitoyen' },
  ],
  en: [
    { k: 'hook', a: 'GTA 5', b: 'GTA 6', t: 'The difference in 15 seconds' },
    { k: 'row', label: 'Release', a: '2013', b: '2026', note: '13 years apart' },
    { k: 'row', label: 'City', a: 'Los Santos', b: 'Vice City' },
    { k: 'row', label: 'State', a: 'San Andreas', b: 'Leonida' },
    { k: 'row', label: 'Heroes', a: '3', b: '2', note: 'Michael, Franklin, Trevor vs Lucia & Jason' },
    { k: 'row', label: 'Consoles', a: 'PS3 · Xbox 360', b: 'PS5 · Xbox Series', note: 'at launch' },
    { k: 'end', t: 'Which one is better?', s: 'Tell me in the comments', h: '@neonandwasted' },
  ],
};
const CSS = `*{box-sizing:border-box;margin:0}body{width:1080px;height:1920px;overflow:hidden;font-family:'Inter Display','Inter',sans-serif;color:#fff;
background:linear-gradient(180deg,#14061f 0%,#3a0d4f 35%,#b81f63 70%,#ff8a3d 100%);position:relative}
.sun{position:absolute;left:50%;top:1180px;width:900px;height:900px;margin-left:-450px;border-radius:50%;background:radial-gradient(circle,#ffd36b 0%,#ff7a59 45%,rgba(255,80,120,0) 70%);opacity:.55}
.grid{position:absolute;left:-200px;right:-200px;bottom:0;height:520px;background:repeating-linear-gradient(90deg,rgba(255,92,180,.35) 0 2px,transparent 2px 120px),repeating-linear-gradient(0deg,rgba(255,92,180,.35) 0 2px,transparent 2px 70px);transform:perspective(500px) rotateX(60deg);transform-origin:bottom}
.wrap{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:56px;padding:0 70px;text-align:center}
.label{font-size:64px;font-weight:800;letter-spacing:.18em;text-transform:uppercase;color:#ffd6ec}
.cols{display:grid;grid-template-columns:1fr 1fr;gap:36px;width:100%}
.card{border-radius:36px;padding:44px 24px;display:flex;flex-direction:column;gap:22px;align-items:center;box-shadow:0 20px 60px rgba(0,0,0,.45)}
.c5{background:rgba(31,111,235,.85);border:4px solid #8ab8ff}.c6{background:rgba(224,48,107,.9);border:4px solid #ffb3cf}
.tag{font-size:46px;font-weight:900;letter-spacing:.06em;opacity:.9}.val{font-size:86px;font-weight:900;line-height:1.02;word-break:break-word}
.val.s{font-size:62px}.note{font-size:46px;font-weight:700;color:#fff;background:rgba(0,0,0,.35);padding:18px 30px;border-radius:24px;line-height:1.25}
.vs{font-size:250px;font-weight:900;line-height:.9;text-shadow:0 0 40px #ff4fa3,0 0 90px #ff4fa3}.h5{color:#8ab8ff}.h6{color:#ffb3cf}
.big{font-size:210px;font-weight:900;line-height:.95}.sub{font-size:62px;font-weight:800}
.end1{font-size:120px;font-weight:900;line-height:1.05;text-shadow:0 0 40px #ff4fa3}.end2{font-size:64px;font-weight:700}.handle{font-size:58px;font-weight:800;background:#fff;color:#b81f63;padding:16px 36px;border-radius:999px}`;
function html(s){
  let inner='';
  if(s.k==='hook') inner=`<div class="big h5">${s.a}</div><div class="vs">VS</div><div class="big h6">${s.b}</div><div class="sub">${s.t}</div>`;
  if(s.k==='row'){ const sm=(s.a.length>8||s.b.length>8)?' s':'';
    inner=`<div class="label">${s.label}</div><div class="cols"><div class="card c5"><div class="tag">GTA 5</div><div class="val${sm}">${s.a}</div></div><div class="card c6"><div class="tag">GTA 6</div><div class="val${sm}">${s.b}</div></div></div>${s.note?`<div class="note">${s.note}</div>`:''}`;}
  if(s.k==='end') inner=`<div class="end1">${s.t}</div><div class="end2">${s.s}</div><div class="handle">${s.h}</div>`;
  return `<html><head><meta charset="utf-8"><style>${CSS}</style></head><body><div class="sun"></div><div class="grid"></div><div class="wrap">${inner}</div></body></html>`;
}
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});
for(const [lang,sl] of Object.entries(SLIDES)){ for(let i=0;i<sl.length;i++){ await p.setContent(html(sl[i])); await p.screenshot({path:`${lang}_${i}.png`}); } }
await b.close(); console.log('slides ok');})();
