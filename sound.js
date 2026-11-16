window.Sound=(()=>{let AC,off=localStorage.lampMute==='1';
const ctx=()=>{AC=AC||new (window.AudioContext||window.webkitAudioContext)();if(AC.state!=='running')AC.resume();return AC};
const run=f=>{if(off)return;try{f(ctx())}catch(_){}};
const beep=(f,d,ty,v,t0)=>run(c=>{const o=c.createOscillator(),k=c.createGain(),n=c.currentTime+(t0||0);o.type=ty;o.frequency.value=f;k.gain.setValueAtTime(v,n);k.gain.exponentialRampToValueAtTime(.001,n+d);o.connect(k);k.connect(c.destination);o.start(n);o.stop(n+d)});
const horn=(f0,f1,t0,d,vib)=>run(c=>{const n=c.currentTime+t0,o=c.createOscillator(),lp=c.createBiquadFilter(),k=c.createGain();o.type='sawtooth';o.frequency.setValueAtTime(f0,n);o.frequency.linearRampToValueAtTime(f1,n+d);lp.type='lowpass';lp.frequency.value=900;
 k.gain.setValueAtTime(.0001,n);k.gain.linearRampToValueAtTime(.28,n+.04);k.gain.exponentialRampToValueAtTime(.001,n+d);
 if(vib){const l=c.createOscillator(),lg=c.createGain();l.frequency.value=6;lg.gain.value=7;l.connect(lg);lg.connect(o.frequency);l.start(n);l.stop(n+d)}
 o.connect(lp);lp.connect(k);k.connect(c.destination);o.start(n);o.stop(n+d)});
const clap=()=>run(c=>{const len=Math.floor(c.sampleRate*.05),buf=c.createBuffer(1,len,c.sampleRate),d=buf.getChannelData(0);for(let i=0;i<len;i++)d[i]=(Math.random()*2-1)*Math.pow(1-i/len,3);
 const T=2.6;for(let i=0;i<130;i++){const t=Math.random()*T,s=c.createBufferSource(),f=c.createBiquadFilter(),k=c.createGain();s.buffer=buf;s.playbackRate.value=.8+Math.random()*.6;f.type='bandpass';f.frequency.value=1200+Math.random()*1800;f.Q.value=1.2;
  k.gain.value=(.15+Math.random()*.3)*Math.pow(Math.sin(Math.PI*t/T),.7);s.connect(f);f.connect(k);k.connect(c.destination);s.start(c.currentTime+t)}});
const api={right(){clap();beep(1047,.3,'triangle',.18)},
 wrong(none){if(none){horn(233,208,0,.4);horn(208,185,.45,.7,1)}else{horn(233,233,0,.35);horn(220,220,.4,.35);horn(208,208,.8,.35);horn(196,160,1.2,1.1,1)}},
 reveal(){beep(880,.25,'sine',.22);beep(1320,.4,'sine',.18,.12)},
 lock(){beep(440,.12,'square',.18);beep(440,.12,'square',.18,.18)},
 clap(){clap()},cheer(){clap();[523,659,784,1047].forEach((f,i)=>beep(f,.3,'triangle',.22,i*.1))},sad(){api.wrong(false)},ding(){api.reveal()}};
let au;
const wav=()=>{const n=2205,b=new Uint8Array(44+n),v=new DataView(b.buffer),w=(o,t)=>[...t].forEach((c,i)=>b[o+i]=c.charCodeAt(0));w(0,'RIFF');v.setUint32(4,36+n,true);w(8,'WAVEfmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,22050,true);v.setUint32(28,22050,true);v.setUint16(32,1,true);v.setUint16(34,8,true);w(36,'data');v.setUint32(40,n,true);b.fill(128,44);return URL.createObjectURL(new Blob([b],{type:'audio/wav'}))};
const unlock=()=>{try{const c=ctx(),z=c.createBuffer(1,1,22050),p=c.createBufferSource();p.buffer=z;p.connect(c.destination);p.start(0);
 if(!au){au=new Audio(wav());au.loop=true}au.play().catch(()=>{})}catch(_){}};
['click','touchend','keydown'].forEach(e=>addEventListener(e,unlock,true));
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&AC&&AC.state!=='running')AC.resume()});
addEventListener('DOMContentLoaded',()=>{const b=document.createElement('button');b.type='button';
 b.style.cssText='position:fixed;left:14px;bottom:14px;z-index:30;padding:8px 14px;border-radius:999px;border:1px solid rgba(255,255,255,.18);background:rgba(7,10,20,.7);color:inherit;font:inherit;font-size:.8rem;font-weight:700;cursor:pointer';
 const sync=()=>{b.textContent=off?'Sound off':'Sound on';b.setAttribute('aria-pressed',String(!off))};sync();
 b.onclick=()=>{off=!off;localStorage.lampMute=off?'1':'0';sync();if(!off)api.reveal()};document.body.appendChild(b)});
return api})();
