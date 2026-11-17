window.Progress=(()=>{
const BL={first_game:'First game',podium:'Podium finish',champion:'Champion',on_fire:'3-day streak',regular:'Regular (5 games)',rising_star:'Rising star (level 5)'};
const el=(t,css,txt)=>{const e=document.createElement(t);if(css)e.style.cssText=css;if(txt!=null)e.textContent=txt;return e};
function card(d,name){const c=document.createElement('canvas');c.width=1080;c.height=1350;const x=c.getContext('2d'),gr=x.createLinearGradient(0,0,1080,1350);gr.addColorStop(0,'#1B1440');gr.addColorStop(1,'#070A14');x.fillStyle=gr;x.fillRect(0,0,1080,1350);
 x.fillStyle='#FFC857';x.font='800 54px sans-serif';x.fillText('BEACON',80,120);x.textAlign='center';x.fillStyle='#fff';x.font='900 300px sans-serif';x.fillText('#'+d.rank,540,620);
 x.font='700 64px sans-serif';x.fillText(String(name||'Player').slice(0,20),540,740);x.fillStyle='#FFC857';x.font='800 56px sans-serif';x.fillText(d.score+' points',540,830);
 x.fillStyle='#fff';x.font='600 46px sans-serif';x.fillText('Level '+d.level+'  |  +'+d.xp+' XP  |  '+d.streak+'-day streak',540,950);
 (d.new_badges||[]).slice(0,2).forEach((b,i)=>x.fillText('Badge: '+(BL[b]||b),540,1040+i*70));x.fillStyle='#98A3C7';x.font='600 40px sans-serif';x.fillText('Play at '+location.host,540,1270);return c}
async function share(d,name){const txt='I finished #'+d.rank+' on Beacon! Can you beat me? '+location.origin+location.pathname.replace(/[^/]*$/,'');
 try{const b=await new Promise(r=>card(d,name).toBlob(r,'image/png')),f=new File([b],'beacon-result.png',{type:'image/png'});if(navigator.canShare&&navigator.canShare({files:[f]})){await navigator.share({files:[f],text:txt});return}}catch(_){}
 window.open('https://wa.me/?text='+encodeURIComponent(txt),'_blank')}
function toast(d,name){const t=el('div','position:fixed;left:50%;bottom:18px;transform:translateX(-50%);z-index:130;width:min(92vw,420px);box-sizing:border-box;padding:16px 18px;border-radius:22px;background:rgba(16,24,49,.96);border:1px solid rgba(255,200,87,.5);color:#fff;box-shadow:0 20px 50px rgba(0,0,0,.6);text-align:left');
 t.appendChild(el('b','display:block;font-size:1.15rem','+'+d.xp+' XP  -  Level '+d.level));
 t.appendChild(el('div','opacity:.85;margin:4px 0 12px',(d.streak>1?d.streak+'-day streak. ':'')+((d.new_badges||[]).length?'New badge: '+d.new_badges.map(b=>BL[b]||b).join(', '):'Keep playing to earn badges.')));
 const row=el('div','display:flex;gap:8px'),mk=(l,f)=>{const b=el('button','flex:1;padding:10px;border:0;border-radius:14px;font:inherit;font-weight:700;cursor:pointer;background:rgba(255,255,255,.12);color:#fff;width:auto',l);b.type='button';b.onclick=f;row.appendChild(b)};
 mk('Share result',()=>share(d,name));mk('My profile',()=>{location.href='profile.html'});mk('Close',()=>t.remove());t.appendChild(row);document.body.appendChild(t)}
function moment(d){const prev=Math.floor(Math.sqrt(Math.max(0,(d.total||0)-(d.xp||0))/100))+1,up=d.level>prev,nb=d.new_badges||[];if(!up&&!nb.length)return;
 const calm=matchMedia('(prefers-reduced-motion:reduce)').matches,fresh=up&&window.AVATAR_LV?Object.keys(AVATAR_LV).filter(e=>AVATAR_LV[e]>prev&&AVATAR_LV[e]<=d.level):[];
 if(!document.getElementById('mom-css')){const s=el('style');s.id='mom-css';s.textContent='@keyframes mrot{to{transform:rotate(360deg)}}@keyframes mpop{from{transform:scale(.2);opacity:0}}';document.head.appendChild(s)}
 const ov=el('div','position:fixed;inset:0;z-index:140;display:flex;align-items:center;justify-content:center;padding:20px;overflow:hidden;background:radial-gradient(800px 560px at 50% 30%,rgba(255,200,87,.35),rgba(7,10,20,.96) 70%),#070A14;color:#fff;text-align:center');
 ov.setAttribute('role','dialog');ov.setAttribute('aria-label',up?'Level up':'New badge');
 ov.appendChild(el('div','position:absolute;inset:-60%;pointer-events:none;background:repeating-conic-gradient(from 0deg at 50% 50%,rgba(255,200,87,.16) 0 6deg,transparent 6deg 18deg);-webkit-mask-image:radial-gradient(circle,#000 0,transparent 60%);mask-image:radial-gradient(circle,#000 0,transparent 60%);'+(calm?'':'animation:mrot 50s linear infinite')));
 const box=el('div','position:relative;display:flex;flex-direction:column;align-items:center;gap:12px;max-width:520px;width:100%');
 const av=el('div','display:flex;justify-content:center;'+(calm?'':'animation:mpop .7s cubic-bezier(.3,1.5,.5,1) both'));av.innerHTML=window.Av?Av.html(localStorage.lampEm||'\u{1F981}',{size:132,cls:calm?'':'cheer'}):'';box.appendChild(av);
 box.appendChild(el('h1','margin:0;font-size:clamp(2.4rem,9vw,4.2rem);font-weight:900;letter-spacing:-.04em;color:#FFC857',up?'LEVEL UP!':'NEW BADGE!'));
 box.appendChild(el('div','font-size:1.3rem;opacity:.9',up?'You reached level '+d.level:'Nice work!'));
 if(fresh.length){box.appendChild(el('div','margin-top:6px;font-weight:800;letter-spacing:.12em;font-size:.85rem;color:#FFC857','NEW CHARACTERS UNLOCKED'));const r=el('div','display:flex;gap:12px;justify-content:center;flex-wrap:wrap');fresh.forEach((e,i)=>{const c=el('div',calm?'':'animation:mpop .6s '+(.5+i*.2)+'s cubic-bezier(.3,1.5,.5,1) both');c.innerHTML=window.Av?Av.html(e,{size:64}):e;r.appendChild(c)});box.appendChild(r)}
 if(nb.length){const r=el('div','display:flex;gap:8px;justify-content:center;flex-wrap:wrap;margin-top:6px');nb.forEach(b=>r.appendChild(el('span','padding:8px 16px;border-radius:999px;background:rgba(255,200,87,.18);border:1px solid rgba(255,200,87,.6);font-weight:800',BL[b]||b)));box.appendChild(r)}
 const b=el('button','margin-top:14px;padding:14px 32px;border:0;border-radius:18px;background:linear-gradient(180deg,#FFD479,#FF9F1C);color:#2A1700;font:inherit;font-weight:800;font-size:1.05rem;cursor:pointer;width:auto','Continue');b.type='button';b.onclick=()=>ov.remove();box.appendChild(b);
 ov.appendChild(box);document.body.appendChild(ov);b.focus();if(window.Sound&&Sound.cheer)Sound.cheer()}
async function award(S,name){try{const{data}=await sb.rpc('award_session',{p_session:S});if(data&&data.ok){toast(data,name);setTimeout(()=>moment(data),900)}return data}catch(_){}}
return{award,share,moment,BL}})();
