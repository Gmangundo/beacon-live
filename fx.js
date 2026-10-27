if(matchMedia('(hover:hover) and (prefers-reduced-motion:no-preference)').matches)addEventListener('pointermove',e=>{
 const c=e.target.closest&&e.target.closest('.card');
 document.querySelectorAll('.card.tilt').forEach(x=>{if(x!==c){x.style.transform='';x.classList.remove('tilt')}});
 if(!c||(document.activeElement&&c.contains(document.activeElement)&&/INPUT|TEXTAREA/.test(document.activeElement.tagName)))return;
 const r=c.getBoundingClientRect(),px=(e.clientX-r.left)/r.width-.5,py=(e.clientY-r.top)/r.height-.5;
 c.classList.add('tilt');c.style.transform=`perspective(900px) rotateY(${px*5}deg) rotateX(${-py*5}deg) translateY(-3px)`});
