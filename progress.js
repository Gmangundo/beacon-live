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
async function award(S,name){try{const{data}=await sb.rpc('award_session',{p_session:S});if(data&&data.ok)toast(data,name);return data}catch(_){}}
return{award,share,BL}})();
