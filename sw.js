/* Contas da casa: service worker.
   Guarda só a "casca" do app (página, ícones, fontes e biblioteca) para abrir rápido e permitir a instalação.
   Dados do Supabase nunca passam pelo cache. Para forçar atualização de todos, aumente VERSAO. */
const VERSAO="contas-v1";
const CASCA=["./","index.html","config.js","manifest.webmanifest","icons/icon-192.png","icons/icon-512.png","icons/apple-touch-icon.png"];

self.addEventListener("install",e=>{
  e.waitUntil(caches.open(VERSAO).then(c=>Promise.all(CASCA.map(u=>c.add(u).catch(()=>{})))).then(()=>self.skipWaiting()));
});
self.addEventListener("activate",e=>{
  e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==VERSAO).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener("fetch",e=>{
  const req=e.request,url=new URL(req.url);
  if(req.method!=="GET")return;
  if(url.hostname.endsWith("supabase.co")||url.hostname.endsWith("supabase.in"))return; // dados: sempre direto da rede
  const mesmaOrigem=url.origin===self.location.origin;
  if(mesmaOrigem){
    // página e arquivos do app: rede primeiro (assim as atualizações chegam), cache como reserva
    e.respondWith(fetch(req).then(r=>{if(r.ok){const cp=r.clone();caches.open(VERSAO).then(c=>c.put(req,cp))}return r}).catch(()=>caches.match(req).then(r=>r||caches.match("index.html"))));
    return;
  }
  // fontes e biblioteca de CDN: cache primeiro, atualiza em segundo plano
  if(/fonts\.(googleapis|gstatic)\.com|cdn\.jsdelivr\.net/.test(url.hostname)){
    e.respondWith(caches.match(req).then(hit=>{
      const rede=fetch(req).then(r=>{if(r.ok||r.type==="opaque"){const cp=r.clone();caches.open(VERSAO).then(c=>c.put(req,cp))}return r}).catch(()=>hit);
      return hit||rede;
    }));
  }
});
