import http from 'node:http';
import {appendFileSync,mkdirSync} from 'node:fs';import{dirname}from'node:path';
import{loadConfig}from'./config.js';import{createService,FakeVerifier,MemoryLedger,safeEqual}from'./core.js';import{GooglePlayVerifier}from'./google-play.js';
export function createHttpServer({config,verifier,ledger=new MemoryLedger(),audit}={}){
 const writeAudit=audit||(entry=>{mkdirSync(dirname(config.auditFile),{recursive:true});appendFileSync(config.auditFile,`${JSON.stringify({at:new Date().toISOString(),...entry})}\n`,{mode:0o600});});
 const verify=createService({config,verifier,ledger,audit:writeAudit});
 return http.createServer(async(req,res)=>{res.setHeader('content-type','application/json; charset=utf-8');
  if(req.method==='GET'&&req.url==='/healthz')return res.end(JSON.stringify({status:'ok',mode:config.mode}));
  const internal=req.url==='/v1/google-play/subscriptions/verify',client=req.url==='/v1/client/subscriptions/verify';
  if(req.method!=='POST'||(!internal&&!client)){res.statusCode=404;return res.end(JSON.stringify({error:'not_found'}));}
  if(internal&&!safeEqual(req.headers.authorization||'',`Bearer ${config.apiKey}`)){res.statusCode=401;return res.end(JSON.stringify({error:'unauthorized'}));}
  try{let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>16384)throw Object.assign(new Error('body too large'),{status:413});}
   const result=await verify(JSON.parse(raw));res.end(JSON.stringify(result));
  }catch(error){res.statusCode=error.status||(error instanceof SyntaxError?400:503);res.end(JSON.stringify({error:'verification_failed',failClosed:true}));}
 });
}
const invoked=process.argv[1]&&new URL(import.meta.url).pathname.replace(/^\/(.:)/,'$1').replaceAll('/','\\')===process.argv[1];
if(invoked){const config=loadConfig(),verifier=config.mode==='fake'?new FakeVerifier(new Map([['local-active-token',{expiryTimeMillis:Date.now()+86400000,acknowledged:true,autoRenewing:true}]])):new GooglePlayVerifier(config);createHttpServer({config,verifier}).listen(config.port,'0.0.0.0',()=>console.log(JSON.stringify({event:'server_started',port:config.port,mode:config.mode})));}
