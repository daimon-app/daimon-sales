const fs=require('fs'),path=require('path'),crypto=require('crypto'),webpush=require('web-push');
const [command,serverRoot,payloadPath]=process.argv.slice(2);if(!command||!serverRoot)throw new Error('missing arguments');
const root=path.join(serverRoot,'runtime','push'),subscriptions=path.join(root,'subscriptions'),vapidPath=path.join(root,'vapid.json');fs.mkdirSync(subscriptions,{recursive:true});
function vapid(){if(!fs.existsSync(vapidPath))fs.writeFileSync(vapidPath,JSON.stringify(webpush.generateVAPIDKeys()),{encoding:'utf8',flag:'wx'});return JSON.parse(fs.readFileSync(vapidPath,'utf8'))}
if(command==='init'||command==='public-key'){process.stdout.write(JSON.stringify({publicKey:vapid().publicKey}))}
else if(command==='send'){
  const payload=fs.readFileSync(payloadPath,'utf8'),keys=vapid();webpush.setVapidDetails('mailto:ai5-hub@localhost.invalid',keys.publicKey,keys.privateKey);
  Promise.all(fs.readdirSync(subscriptions).filter(x=>x.endsWith('.json')).map(async name=>{const file=path.join(subscriptions,name);try{await webpush.sendNotification(JSON.parse(fs.readFileSync(file,'utf8')),payload,{TTL:300,urgency:'high'});return{name,status:'sent'}}catch(error){if(error.statusCode===404||error.statusCode===410)fs.unlinkSync(file);return{name,status:'failed',code:error.statusCode||0}}})).then(results=>process.stdout.write(JSON.stringify({results})));
}else throw new Error('unsupported command');
