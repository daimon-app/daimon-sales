import { createHmac, timingSafeEqual } from 'node:crypto';
export const ENTITLEMENT = Object.freeze({ ACTIVE: 'ACTIVE', INACTIVE: 'INACTIVE', PENDING: 'PENDING' });
export function safeEqual(a,b){const x=Buffer.from(String(a)),y=Buffer.from(String(b));return x.length===y.length&&timingSafeEqual(x,y);}
export function tokenFingerprint(token,key){return createHmac('sha256',key).update(token).digest('hex');}
export function validateRequest(body,config){
  if(!body||typeof body!=='object')throw Object.assign(new Error('invalid body'),{status:400});
  for(const key of ['purchaseToken','productId','packageName'])if(typeof body[key]!=='string'||!body[key]||body[key].length>4096)throw Object.assign(new Error(`invalid ${key}`),{status:400});
  if(body.packageName!==config.packageName||body.productId!==config.productId)throw Object.assign(new Error('product identity mismatch'),{status:403});
}
export function decideEntitlement(result,now=Date.now()){
  if(!result||result.productId==null||result.packageName==null)return ENTITLEMENT.INACTIVE;
  if(result.revoked||result.refunded||result.expiryTimeMillis<=now)return ENTITLEMENT.INACTIVE;
  if(result.paymentState==='PENDING'||result.onHold||!result.acknowledged)return ENTITLEMENT.PENDING;
  return ENTITLEMENT.ACTIVE;
}
export async function withTimeoutRetry(operation,{timeoutMs,maxRetries}){
  let lastError;
  for(let attempt=0;attempt<=maxRetries;attempt++)try{return await Promise.race([operation(attempt),new Promise((_,reject)=>setTimeout(()=>reject(new Error('verification timeout')),timeoutMs))]);}
  catch(error){lastError=error;if(attempt<maxRetries)await new Promise(resolve=>setTimeout(resolve,Math.min(50*2**attempt,250)));}
  throw lastError;
}
export class MemoryLedger{
  #records=new Map();get(fingerprint){return this.#records.get(fingerprint);}
  put(fingerprint,identity,response){const prior=this.#records.get(fingerprint);if(prior&&prior.identity!==identity)throw Object.assign(new Error('purchase token replay mismatch'),{status:409});this.#records.set(fingerprint,{identity,response});}
}
export class FakeVerifier{
  constructor(fixtures=new Map()){this.fixtures=fixtures;this.calls=0;}
  async verify({purchaseToken,productId,packageName}){this.calls++;const item=this.fixtures.get(purchaseToken);if(item instanceof Error)throw item;if(!item)throw Object.assign(new Error('purchase not found'),{status:404});return{productId,packageName,...item};}
}
export class ProductionVerifier{async verify(){throw Object.assign(new Error('Google Play verifier adapter not configured'),{status:503});}}
export function createService({config,verifier,ledger,audit,now=()=>Date.now()}){return async body=>{
  validateRequest(body,config);const fingerprint=tokenFingerprint(body.purchaseToken,config.hmacKey),identity=`${body.packageName}:${body.productId}`,prior=await ledger.get(fingerprint);
  if(prior&&prior.identity!==identity)throw Object.assign(new Error('purchase token replay mismatch'),{status:409});
  if(prior&&now()-Date.parse(prior.response.verifiedAt)<Number(config.cacheMs||60000)){audit({event:'verification_idempotent',fingerprint});return{...prior.response,idempotent:true};}
  try{const verified=await withTimeoutRetry(()=>verifier.verify(body),{timeoutMs:config.timeoutMs,maxRetries:config.maxRetries});
    if(verified.packageName!==config.packageName||verified.productId!==config.productId)throw Object.assign(new Error('upstream identity mismatch'),{status:403});
    const response={entitlement:decideEntitlement(verified,now()),expiryTimeMillis:Number(verified.expiryTimeMillis||0),acknowledged:Boolean(verified.acknowledged),autoRenewing:Boolean(verified.autoRenewing),cancelReason:verified.cancelReason||null,verifiedAt:new Date(now()).toISOString(),idempotent:false};
    await ledger.put(fingerprint,identity,response);audit({event:prior?'verification_refreshed':'verification_complete',fingerprint,entitlement:response.entitlement});return{...response,idempotent:Boolean(prior)};
  }catch(error){audit({event:'verification_failed',fingerprint,reason:error.message});throw error;}
};}
