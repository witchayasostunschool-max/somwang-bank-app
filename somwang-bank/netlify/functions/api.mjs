import {createHmac,timingSafeEqual,randomBytes} from 'node:crypto';
const json=(data,status=200,headers={})=>new Response(JSON.stringify(data),{status,headers:{'content-type':'application/json; charset=utf-8','cache-control':'no-store',...headers}});
const secret=()=>process.env.SESSION_SECRET||'';
const sign=(v)=>createHmac('sha256',secret()).update(v).digest('hex');
const eq=(a,b)=>{const x=Buffer.from(String(a)),y=Buffer.from(String(b));return x.length===y.length&&timingSafeEqual(x,y)};
const cookie=(req)=>req.headers.get('cookie')?.match(/(?:^|; )sb_session=([^;]+)/)?.[1];
function authorized(req){const c=cookie(req);if(!c||!secret())return false;const [expiry,nonce,signature]=c.split('.');return !!expiry&&!!nonce&&!!signature&&eq(signature,sign(`${expiry}.${nonce}`))&&Number(expiry)>Date.now()}
async function db(path,options={}){
 const base=process.env.SUPABASE_URL?.replace(/\/$/,'');const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!base||!key)throw Error('ยังไม่ได้ตั้งค่า Supabase บน Netlify');
 const r=await fetch(`${base}/rest/v1/${path}`,{...options,headers:{apikey:key,Authorization:`Bearer ${key}`,'content-type':'application/json',...options.headers}});
 const body=await r.text();let result;try{result=JSON.parse(body)}catch{result=body}
 if(!r.ok)throw Error(result?.message||result?.details||`Database error ${r.status}`);return result;
}
const methods={funds:'funds?select=*&order=sort_order.asc',loans:'loans?select=*&order=created_at.desc',transactions:'transactions?select=*&order=created_at.desc&limit=500',reconciliations:'reconciliations?select=*&order=checked_at.desc&limit=10'};
export default async function handler(req){
 try{
  const url=new URL(req.url);const action=url.pathname.split('/').pop();
  if(action==='login'&&req.method==='POST'){
   const {pin}=await req.json();const pins=(process.env.APP_PINS||'').split(',').map(s=>s.trim()).filter(Boolean);
   if(!pins.length||!secret())return json({error:'กรุณาตั้งค่า APP_PINS และ SESSION_SECRET ใน Netlify'},503);
   if(typeof pin!=='string'||!pins.some(p=>eq(p,pin)))return json({error:'รหัส PIN ไม่ถูกต้อง'},401);
   const expiry=Date.now()+8*60*60*1000;const nonce=randomBytes(16).toString('hex');const value=`${expiry}.${nonce}.${sign(`${expiry}.${nonce}`)}`;
   return json({ok:true},200,{'set-cookie':`sb_session=${value}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=28800`});
  }
  if(action==='logout')return json({ok:true},200,{'set-cookie':'sb_session=; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=0'});
  if(!authorized(req))return json({error:'กรุณาเข้าสู่ระบบ'},401);
  if(action==='session')return json({ok:true});
  if(action==='data'&&req.method==='GET'){
   const [funds,loans,transactions,reconciliations]=await Promise.all(Object.values(methods).map(p=>db(p)));
   return json({funds,loans,transactions,reconciliations});
  }
  if(action==='movement'&&req.method==='POST'){
   const b=await req.json();const allowed=['deposit','withdraw','family','borrow','repay','transfer'];
   if(!allowed.includes(b.kind)||!Number.isFinite(Number(b.amount))||Number(b.amount)<=0||Number(b.amount)>99999999999)return json({error:'ข้อมูลรายการไม่ถูกต้อง'},400);
   const p={p_kind:b.kind,p_amount:Number(b.amount),p_fund:b.fund||null,p_target:b.target||null,p_loan:b.loan||null,p_note:String(b.note||'').slice(0,500),p_date:b.date||new Date().toISOString().slice(0,10),p_loan_kind:b.loanKind||null};
   await db('rpc/record_movement',{method:'POST',body:JSON.stringify(p)});return json({ok:true});
  }
  if(action==='reconcile'&&req.method==='POST'){
   const b=await req.json();const actual=Number(b.actual);if(!Number.isFinite(actual)||actual<0)return json({error:'ยอดธนาคารไม่ถูกต้อง'},400);
   const funds=await db(methods.funds);const expected=funds.reduce((s,f)=>s+Number(f.balance),0);
   await db('reconciliations',{method:'POST',headers:{Prefer:'return=minimal'},body:JSON.stringify({actual,expected,note:String(b.note||'').slice(0,500)})});return json({ok:true,expected,difference:actual-expected});
  }
  return json({error:'ไม่พบ API'},404);
 }catch(e){return json({error:e.message||'เกิดข้อผิดพลาด'},500)}
}
