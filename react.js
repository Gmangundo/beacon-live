window.React=(()=>{
const E={clap:['\u{1F44F}','clap','Clap'],cheer:['\u{1F389}','cheer','Cheer'],fire:['\u{1F525}','ding','Fire'],wow:['\u{1F62E}','ding','Wow'],sad:['\u{1F622}','sad','Aww']};
const chs={};let last=0;
function burst(em){if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;
 if(!document.getElementById('rx')){const s=document.createElement('style');s.id='rx';s.textContent='@keyframes rxr{0%{opacity:0;transform:translateY(0) scale(.6)}15%{opacity:1}100%{opacity:0;transform:translateY(-70vh) scale(1.5)}}';document.head.appendChild(s)}
 for(let i=0;i<14;i++){const d=document.createElement('div');d.textContent=em;d.setAttribute('aria-hidden','true');
  d.style.cssText='position:fixed;bottom:70px;left:'+(8+Math.random()*84)+'vw;font-size:'+(28+Math.random()*28)+'px;z-index:99;pointer-events:none;opacity:0;animation:rxr '+(1.6+Math.random())+'s ease-out '+(Math.random()*.5)+'s forwards';
  document.body.appendChild(d);setTimeout(()=>d.remove(),3500)}}
function show(k){const e=E[k];if(!e)return;if(window.Sound&&Sound[e[1]])Sound[e[1]]();burst(e[0])}
function ch(n){if(!chs[n])chs[n]=sb.channel(n,{config:{broadcast:{self:false}}}).on('broadcast',{event:'react'},m=>show(m&&m.payload&&m.payload.k)).on('broadcast',{event:'celebrate'},m=>{if(window.Celebrate&&m&&m.payload)Celebrate.show(m.payload)}).subscribe();return chs[n]}
function send(n,k){ch(n).send({type:'broadcast',event:'react',payload:{k}});show(k)}
function listen(get){setInterval(()=>{try{const n=get();if(n)ch(n)}catch(_){}},1500)}
function bar(get,cel){const d=document.createElement('div');d.setAttribute('role','toolbar');d.setAttribute('aria-label','Reactions for the players');
 d.style.cssText='position:fixed;right:14px;bottom:14px;z-index:40;display:flex;gap:4px;padding:6px 8px;border-radius:999px;background:rgba(7,10,20,.78);border:1px solid rgba(255,255,255,.16);-webkit-backdrop-filter:blur(14px);backdrop-filter:blur(14px)';
 Object.keys(E).forEach(k=>{const b=document.createElement('button');b.type='button';b.textContent=E[k][0];b.title=E[k][2];b.setAttribute('aria-label',E[k][2]+' for the players');
  b.style.cssText='font-size:1.6rem;line-height:1;padding:6px 9px;border:0;border-radius:14px;background:transparent;cursor:pointer;width:auto';
  b.onclick=()=>{let n=null;try{n=get()}catch(_){}if(!n||Date.now()-last<600)return;last=Date.now();send(n,k)};d.appendChild(b)});
 if(cel){const t=document.createElement('button');t.type='button';t.textContent='\u{1F3C6}';t.title='Celebrate winners';t.setAttribute('aria-label','Celebrate the winners');t.style.cssText='font-size:1.6rem;line-height:1;padding:6px 9px;border:0;border-radius:14px;background:rgba(255,200,87,.25);cursor:pointer;width:auto';
  t.onclick=()=>{let n=null,p=null;try{n=get();p=cel()}catch(_){}if(!n||!p)return;ch(n).send({type:'broadcast',event:'celebrate',payload:p});Celebrate.show(p)};d.appendChild(t)}
 document.body.appendChild(d);listen(get)}
return{bar,listen,show}})();
