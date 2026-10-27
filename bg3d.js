(()=>{if(document.getElementById('hero'))return;
const cv=document.createElement('canvas');cv.setAttribute('aria-hidden','true');cv.style.cssText='position:fixed;inset:0;width:100%;height:100%;z-index:-1;pointer-events:none;opacity:.75';document.body.prepend(cv);
const go=()=>{let R;try{R=new THREE.WebGLRenderer({canvas:cv,alpha:true})}catch(e){return}
const S=new THREE.Scene(),C=new THREE.PerspectiveCamera(50,1,.1,100);C.position.z=9;
S.add(new THREE.AmbientLight(0xffffff,.5));const L=new THREE.PointLight(0xffb347,2,40);L.position.set(2,3,6);S.add(L);
const orb=new THREE.Mesh(new THREE.IcosahedronGeometry(1.5,1),new THREE.MeshStandardMaterial({color:0xff9f1c,emissive:0xff7a00,emissiveIntensity:.6,flatShading:true}));S.add(orb);
const ring=new THREE.Mesh(new THREE.TorusGeometry(2.5,.04,10,100),new THREE.MeshBasicMaterial({color:0x7c5cff}));ring.rotation.x=1.2;orb.add(ring);
const n=160,p=new Float32Array(n*3);for(let i=0;i<n*3;i++)p[i]=(Math.random()-.5)*26;
const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.BufferAttribute(p,3));const pts=new THREE.Points(g,new THREE.PointsMaterial({size:.06,color:0xffffff,transparent:true,opacity:.6}));S.add(pts);
const still=matchMedia('(prefers-reduced-motion:reduce)').matches;
(function loop(t){requestAnimationFrame(loop);if(document.hidden)return;const w=innerWidth,h=innerHeight,wide=w>800,pr=Math.min(devicePixelRatio,1.5);
 if(cv.width!==Math.floor(w*pr)){R.setPixelRatio(pr);R.setSize(w,h,false);C.aspect=w/h;C.updateProjectionMatrix()}
 orb.position.set(wide?5.2:1.7,wide?-2.4:-3.3,-1);orb.scale.setScalar(wide?1:.55);
 const s=still?0:t/1000;orb.rotation.y=s*.35;orb.rotation.x=s*.15;pts.rotation.y=s*.02;R.render(S,C)})(0)};
if(window.THREE)go();else{const s=document.createElement('script');s.src='https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js';s.onload=go;document.head.appendChild(s)}})();
