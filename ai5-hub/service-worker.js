const CACHE='ai5-hub-v41-command-center';
const ASSETS=['/','/index.html','/styles.css','/app.js','/manifest.webmanifest','/icons/ai5-icon-192.png','/icons/ai5-icon-512.png','/icons/apple-touch-icon.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
  const url=new URL(event.request.url);
  if(event.request.method!=='GET'||url.pathname.startsWith('/api/'))return;
  event.respondWith(fetch(event.request).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));return response}).catch(()=>caches.match(event.request).then(hit=>hit||caches.match('/index.html'))));
});
self.addEventListener('push',event=>{let data={title:'AI5 HUB',body:'詳細は本人認証後にAI5 HUBで確認してください。',tag:'ai5-hub',url:'/'};try{if(event.data)data={...data,...event.data.json()}}catch{}event.waitUntil(self.registration.showNotification(data.title,{body:data.body,icon:'/icons/ai5-icon-192.png',badge:'/icons/ai5-icon-192.png',tag:data.tag,data:{url:data.url},renotify:false}))});
self.addEventListener('notificationclick',event=>{event.notification.close();const target=new URL(event.notification.data?.url||'/',self.location.origin).href;event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{const found=list.find(client=>client.url.startsWith(self.location.origin));if(found){found.navigate(target);return found.focus()}return clients.openWindow(target)}))});
