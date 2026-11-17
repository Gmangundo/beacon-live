window.Celebrate=(()=>{let ov,raf,tm;
const S=(x,n)=>String(x==null?'':x).slice(0,n),el=(t,css,txt)=>{const e=document.createElement(t);if(css)e.style.cssText=css;if(txt!=null)e.textContent=txt;return e};
function close(){if(ov){ov.remove();ov=null}cancelAnimationFrame(raf);clearTimeout(tm)}
function confetti(cv){const c=cv.getContext('2d');cv.width=innerWidth;cv.height=innerHeight;const col=['#FFC857','#FF6B6B','#5AA9FF','#7C5CFF','#5FD6A0','#ffffff'];
 const P=Array.from({length:170},()=>({x:Math.random()*cv.width,y:-Math.random()*cv.height,w:6+Math.random()*8,h:10+Math.random()*10,vx:-1.5+Math.random()*3,vy:2+Math.random()*4,r:Math.random()*6,vr:-.2+Math.random()*.4,c:col[Math.random()*6|0]}));
 (function f(){if(!ov)return;c.clearRect(0,0,cv.width,cv.height);P.forEach(p=>{p.x+=p.vx;p.y+=p.vy;p.r+=p.vr;if(p.y>cv.height+20){p.y=-20;p.x=Math.random()*cv.width}c.save();c.translate(p.x,p.y);c.rotate(p.r);c.fillStyle=p.c;c.fillRect(-p.w/2,-p.h/2,p.w,p.h);c.restore()});raf=requestAnimationFrame(f)})()}
function show(p){close();p=p||{};const calm=matchMedia('(prefers-reduced-motion:reduce)').matches;
 if(!document.getElementById('cel-css')){const st=el('style');st.id='cel-css';st.textContent='@keyframes cpr{from{opacity:0;transform:translateY(70px) scale(.6)}}@keyframes cfl{50%{transform:translateY(-10px)}}@keyframes crot{to{transform:rotate(360deg)}}@keyframes cswa{from{transform:rotate(-40deg)}to{transform:rotate(-6deg)}}@keyframes cswb{from{transform:rotate(40deg)}to{transform:rotate(6deg)}}';document.head.appendChild(st)}
 const col=/^#[0-9a-f]{6}$/i.test(p.color)?p.color:'#FFC857';
 ov=el('div','position:fixed;inset:0;z-index:120;display:flex;align-items:center;justify-content:center;padding:20px;overflow:auto;background:radial-gradient(900px 600px at 50% 15%,'+col+'44,rgba(7,10,20,.97) 70%),#070A14;color:#fff;text-align:center');
 ov.setAttribute('role','dialog');ov.setAttribute('aria-label','Celebration');
 if(window.BEACON_SPLINE&&BEACON_SPLINE.winner&&window.customElements&&customElements.get('spline-viewer')){const v=el('spline-viewer','position:absolute;inset:0;width:100%;height:100%;z-index:0;pointer-events:none');v.setAttribute('url',BEACON_SPLINE.winner);ov.appendChild(v)}
 if(!calm){const lf=el('div','position:absolute;inset:0;overflow:hidden;pointer-events:none;z-index:0');
  lf.appendChild(el('div','position:absolute;inset:-60%;background:repeating-conic-gradient(from 0deg at 50% 40%,'+col+'2e 0 6deg,transparent 6deg 18deg);-webkit-mask-image:radial-gradient(circle at 50% 40%,#000 0,transparent 55%);mask-image:radial-gradient(circle at 50% 40%,#000 0,transparent 55%);animation:crot 60s linear infinite'));
  ['a','b'].forEach(k=>lf.appendChild(el('div','position:absolute;top:-10%;left:calc(50% - 150px);width:300px;height:125%;transform-origin:50% 0;clip-path:polygon(44% 0,56% 0,100% 100%,0 100%);background:linear-gradient(180deg,rgba(255,255,255,.55),rgba(255,224,138,.2) 60%,transparent);mix-blend-mode:screen;animation:csw'+k+' 5s ease-in-out infinite alternate')));ov.appendChild(lf)}
 if(!calm){const cv=el('canvas','position:absolute;inset:0;z-index:1;pointer-events:none');ov.appendChild(cv);requestAnimationFrame(()=>confetti(cv))}
 const box=el('div','position:relative;z-index:2;display:flex;flex-direction:column;align-items:center;gap:18px;max-width:720px;width:100%');
 box.appendChild(el('h1','margin:0;font-size:clamp(2.2rem,8vw,4.5rem);font-weight:900;letter-spacing:-.04em;color:'+col,S(p.title||'Winners!',60)));
 if(p.sub)box.appendChild(el('div','font-size:1.2rem;opacity:.85',S(p.sub,80)));
 const pod=(Array.isArray(p.podium)?p.podium:[]).slice(0,3);
 if(pod.length){const w=el('div','display:flex;align-items:flex-end;justify-content:center;gap:12px;margin-top:10px;perspective:800px;width:100%');
  const H=[150,110,80],G=['linear-gradient(#FFE08A,#E8A93D)','linear-gradient(#E6ECF5,#9AA6B8)','linear-gradient(#E9B48A,#A9693A)'],D=[1.3,.7,.2];
  [1,0,2].filter(i=>pod[i]).forEach(i=>{const r=pod[i],c=el('div','display:flex;flex-direction:column;align-items:center;width:'+(i===0?'34%':'28%')+';'+(calm?'':'animation:cpr .7s cubic-bezier(.22,1,.36,1) '+D[i]+'s both'));
   {const em=S(r.emoji,8)||(i===0?'\u{1F451}':'\u2B50'),d=el('div','line-height:1;display:flex;justify-content:center');if(window.Av)d.innerHTML=Av.html(em,{size:i===0?104:78,cls:calm?'':'cheer',name:r.name});else{d.style.fontSize=i===0?'3.6rem':'2.6rem';d.textContent=em}c.appendChild(d)}
   c.appendChild(el('b','font-size:1.05rem;margin:6px 0 2px;overflow-wrap:anywhere',S(r.name,24)));
   c.appendChild(el('span','opacity:.85;font-size:.95rem;margin-bottom:6px',S(r.score,8)));
   c.appendChild(el('div','width:100%;height:'+H[i]+'px;border-radius:14px 14px 0 0;background:'+G[i]+';color:#1a1000;font-weight:900;font-size:2.2rem;display:grid;place-items:center;transform:rotateX(10deg);transform-origin:bottom;box-shadow:0 24px 40px -18px rgba(0,0,0,.7)',String(i+1)));
   w.appendChild(c)});box.appendChild(w)}
 const em=(Array.isArray(p.emojis)?p.emojis:[]).slice(0,20);
 if(em.length){const w=el('div','display:flex;flex-wrap:wrap;gap:10px;justify-content:center');em.forEach((x,i)=>w.appendChild(el('span','font-size:2.4rem;'+(calm?'':'animation:cfl 2s ease-in-out '+(i*.12)+'s infinite'),S(x,8))));box.appendChild(w)}
 const b=el('button','margin-top:10px;padding:14px 32px;border:0;border-radius:18px;background:linear-gradient(180deg,#FFD479,#FF9F1C);color:#2A1700;font:inherit;font-weight:800;font-size:1.05rem;cursor:pointer;width:auto','Continue');b.type='button';b.onclick=close;box.appendChild(b);
 ov.appendChild(box);document.body.appendChild(ov);b.focus();
 if(window.Sound)Sound.cheer();tm=setTimeout(close,30000)}
function build(rows,E){const t=(rows||[]).filter(r=>r&&r.rank<=3).sort((a,b)=>a.rank-b.rank).slice(0,3);if(!t.length)return null;return{title:'Winners!',sub:'Thanks for playing',podium:t.map(r=>({name:S(r.nickname,24),score:r.score,emoji:(E&&E[r.nickname])||''}))}}
return{show,build,podium(rows,E){const p=build(rows,E);if(p)show(p)},close}})();
