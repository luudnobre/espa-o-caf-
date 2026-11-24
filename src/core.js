export const CATEGORIES=['Salgados','Doces','Bebidas','Combos'];
export const STATUS={queued:'A preparar',preparing:'A preparar',ready:'Pronto para retirar',delivered:'Entregue',cancelled:'Cancelado'};
export const PAYMENT={pending:'Falta pagar',paid:'Pago',refunded:'Devolvido'};
export const METHODS={dinheiro:'Dinheiro',pix:'Pix',cartao:'Cartão'};
export const ROLES={admin:'Administração',caixa:'Caixa',cozinha:'Cozinha'};
export function uuid(){if(crypto.randomUUID)return crypto.randomUUID();const b=crypto.getRandomValues(new Uint8Array(16));b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;const h=[...b].map(v=>v.toString(16).padStart(2,'0')).join('');return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20)}`;}
export const e=(v='')=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const money=c=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format((Number(c)||0)/100);
export function cents(value,{zero=false}={}) {
 let s=String(value??'').trim().replace(/^R\$\s*/i,'').replace(/\s/g,'');
 if(s.includes(',')){if(!/^(?:\d+|\d{1,3}(?:\.\d{3})+),\d{1,2}$/.test(s))throw Error('Use um valor como 12,50.');s=s.replaceAll('.','').replace(',','.');}
 if(!/^\d+(?:\.\d{1,2})?$/.test(s))throw Error('Informe um valor válido.');
 const [a,b='']=s.split('.');const n=Number(a)*100+Number(b.padEnd(2,'0'));
 if(!Number.isSafeInteger(n)||n<(zero?0:1)||n>10000000)throw Error('Valor fora do limite.');return n;
}
export const priceInput=v=>(Number(v||0)/100).toFixed(2).replace('.',',');
export const number=n=>String(n).padStart(3,'0');
export const time=d=>d?new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Recife',hour:'2-digit',minute:'2-digit'}).format(new Date(d)):'—';
export const date=d=>d?new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Recife',dateStyle:'short',timeStyle:'short'}).format(new Date(d)):'—';
export const age=d=>Math.max(0,Math.floor((Date.now()-new Date(d).getTime())/60000));
export const nextStatus=s=>({queued:'ready',preparing:'ready',ready:'delivered'}[s]);
export const nextLabel=s=>({queued:'Marcar pronto',preparing:'Marcar pronto',ready:'Confirmar entrega'}[s]);
export function safeImage(value,category='Salgados') {
 const fallback='/images/'+({Salgados:'salgados',Doces:'doces',Bebidas:'bebidas',Combos:'combos'}[category]||'salgados')+'.svg';
 if(typeof value!=='string'||!value)return fallback;
 if(/^\/images\/[\w./-]+$/.test(value)&&!value.includes('..'))return value;
 try{const u=new URL(value);return u.protocol==='https:'?u.href:fallback;}catch{return fallback;}
}
export function totals(state) {
 const orders=state.orders||[],payments=state.payments||[],moves=state.cash_moves||[];
 const session=(state.sessions||[]).find(s=>s.id===state.session_id);
 const paid=orders.filter(o=>o.payment_status==='paid'&&o.status!=='cancelled');
 const revenue=payments.reduce((n,p)=>n+p.amount_cents,0);
 const methods=Object.fromEntries(Object.keys(METHODS).map(k=>[k,payments.filter(p=>p.method===k).reduce((n,p)=>n+p.amount_cents,0)]));
 const expected=(session?.opening_cash_cents||0)+methods.dinheiro+moves.reduce((n,m)=>n+(m.direction==='entrada'?1:-1)*m.amount_cents,0);
 const pending=orders.filter(o=>o.payment_status==='pending'&&o.status!=='cancelled');
 const ranking={};for(const o of paid)for(const i of o.items){const r=ranking[i.product_id]??={name:i.name,quantity:0,total:0};r.quantity+=i.quantity;r.total+=i.quantity*i.price_cents;}
 return {revenue,paid:paid.length,pending:pending.length,pending_cents:pending.reduce((n,o)=>n+o.total_cents,0),ticket:paid.length?Math.round(revenue/paid.length):0,methods,expected,ranking:Object.values(ranking).sort((a,b)=>b.quantity-a.quantity),cancelled:orders.filter(o=>o.status==='cancelled').length,active:paid.filter(o=>o.status!=='delivered').length};
}
export function csvText(rows) {return '\uFEFF'+rows.map(row=>row.map(v=>{let s=String(v??'');if(/^[=+@\-\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';}).join(';')).join('\r\n');}
export function crc16(text){let c=0xffff;for(const b of new TextEncoder().encode(text)){c^=b<<8;for(let i=0;i<8;i++)c=(c&0x8000)?((c<<1)^0x1021)&0xffff:(c<<1)&0xffff;}return c.toString(16).toUpperCase().padStart(4,'0');}
export function pixPayload(key,receiver,city,total,ref='***'){
 const clean=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9 ]/g,'');
 const field=(id,s)=>id+String(new TextEncoder().encode(s).length).padStart(2,'0')+s;
 key=key.trim();if(!key||key.length>77)throw Error('Confira a chave Pix em Configurações.');
 const merchant=field('00','br.gov.bcb.pix')+field('01',key);
 const payload=field('00','01')+field('26',merchant)+field('52','0000')+field('53','986')+field('54',(total/100).toFixed(2))+field('58','BR')+field('59',clean(receiver||'PAES CABO').slice(0,25))+field('60',clean(city||'CABO').slice(0,15))+field('62',field('05',String(ref).replace(/[^A-Za-z0-9]/g,'').slice(0,25)||'***'))+'6304';return payload+crc16(payload);
}
