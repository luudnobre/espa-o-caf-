import test from 'node:test';
import assert from 'node:assert/strict';
import {cents,totals,csvText,pixPayload,crc16,e,safeImage,uuid} from '../src/core.js';
import {receiptHTML} from '../src/receipt.js';
test('valores brasileiros preservam centavos e rejeitam formatos ambíguos',()=>{assert.equal(cents('R$ 1.234,56'),123456);assert.equal(cents('7,50'),750);assert.equal(cents('0,00',{zero:true}),0);for(const s of ['-1','12,345','2.1.4','abc',''])assert.throws(()=>cents(s));});
test('fechamento separa dinheiro, Pix, sangrias, cancelamentos e troco',()=>{const s={session_id:'s',sessions:[{id:'s',opening_cash_cents:5000}],orders:[{payment_status:'paid',status:'delivered',total_cents:700,items:[{product_id:'a',name:'Café',quantity:1,price_cents:700}]},{payment_status:'pending',status:'queued',total_cents:900},{payment_status:'refunded',status:'cancelled',total_cents:800}],payments:[{method:'dinheiro',amount_cents:700},{method:'pix',amount_cents:1000},{method:'pix',amount_cents:-1000}],cash_moves:[{direction:'entrada',amount_cents:1000},{direction:'saida',amount_cents:300}]};const t=totals(s);assert.equal(t.revenue,700);assert.equal(t.expected,6400);assert.equal(t.methods.pix,0);assert.equal(t.pending_cents,900);assert.equal(t.ranking[0].quantity,1);});
test('CSV protege fórmulas e mantém aspas, vírgulas e quebras de linha',()=>{const text=csvText([['nome','valor'],['Bolo, café','="perigo"'],['Um "bom" encontro','7,00']]);assert.ok(text.startsWith('\uFEFF'));assert.ok(text.includes('"\'=""perigo"""'));assert.ok(text.includes('Um ""bom"" encontro'));});
test('Pix usa CRC correto e valor exato em reais',()=>{assert.equal(crc16('123456789'),'29B1');const p=pixPayload('cafe@example.test','PAES CABO','CABO',1290,'CAFE42');assert.ok(p.includes('540512.90'));assert.ok(p.includes('cafe@example.test'));assert.equal(p.slice(-4),crc16(p.slice(0,-4)));});
test('recibo só afirma pagamento para pedido pago e não cancelado',()=>{const order={number:1,customer_name:'<script>alert(1)</script>',created_at:'2026-11-06T20:00:00Z',items:[{name:'Café',quantity:1,price_cents:500}],total_cents:500,status:'queued',payment_status:'pending'};const pending=receiptHTML(order);assert.ok(pending.includes('COMANDA · FALTA PAGAR'));assert.ok(!pending.includes('<script>'));assert.ok(pending.includes('&lt;script&gt;'));assert.ok(receiptHTML({...order,payment_status:'paid'}).includes('RECIBO DE PAGAMENTO'));assert.ok(receiptHTML({...order,payment_status:'refunded',status:'cancelled'}).includes('PEDIDO CANCELADO'));});
test('links de imagens e textos não executam conteúdo injetado',()=>{assert.equal(safeImage('javascript:alert(1)'),'/images/salgados.svg');assert.equal(safeImage('/images/../segredo'),'/images/salgados.svg');assert.equal(e('<img onerror="x">'),'&lt;img onerror=&quot;x&quot;&gt;');assert.match(uuid(),/^[0-9a-f-]{36}$/);});

test('cozinha agrupa pedidos pagos, incluindo o preparo antigo, e mostra somente Pronto', async()=>{
 const {kitchenOrders,kitchenBoard}=await import('../src/kitchen.js');
 const base={created_at:new Date().toISOString(),source:'caixa',customer_name:'<Ana>',items:[{quantity:1,name:'Pão <queijo>'}],notes:''};
 const sample=[
  {...base,id:'one',number:1,payment_status:'paid',status:'queued'},
  {...base,id:'old',number:2,payment_status:'paid',status:'preparing'},
  {...base,id:'done',number:3,payment_status:'paid',status:'ready'},
  {...base,id:'wait',number:4,payment_status:'pending',status:'queued'},
  {...base,id:'finished',number:5,payment_status:'paid',status:'delivered'},
 ];
 const {waiting,ready}=kitchenOrders(sample);
 assert.deepEqual(waiting.map(o=>o.id),['one','old']);
 assert.deepEqual(ready.map(o=>o.id),['done']);
 const html=kitchenBoard(sample);
 assert.equal((html.match(/<button /g)||[]).length,2);
 assert.equal((html.match(/data-status="ready"/g)||[]).length,2);
 assert.ok(!html.includes('data-id="done"'));
 assert.ok(!html.includes('data-id="wait"'));
 assert.ok(!html.includes('Confirmar entrega'));
 assert.ok(html.includes('&lt;Ana&gt;'));
 assert.ok(html.includes('&lt;queijo&gt;'));
});

test('demonstração envia pedido pago à cozinha e só caixa confirma a retirada',async()=>{
 const previous={localStorage:globalThis.localStorage,sessionStorage:globalThis.sessionStorage,window:globalThis.window};
 const storage=()=>{const data=new Map();return {getItem:k=>data.has(k)?data.get(k):null,setItem:(k,v)=>data.set(k,String(v)),removeItem:k=>data.delete(k)}};
 globalThis.localStorage=storage();globalThis.sessionStorage=storage();globalThis.window=new EventTarget();
 try{
  const {demoRPC}=await import('../src/demo.js');
  sessionStorage.setItem('cafe-demo-role','cozinha');
  const initial=await demoRPC('cafe_staff_state');
  const order=initial.orders.find(o=>o.status==='queued'&&o.payment_status==='paid');
  assert.ok(order);
  const prepared=await demoRPC('cafe_board');assert.ok(prepared.preparing.includes(order.number));
  await demoRPC('cafe_advance_order',{p_id:order.id,p_status:'ready'});
  assert.ok((await demoRPC('cafe_board')).ready.some(o=>o.number===order.number));
  await assert.rejects(()=>demoRPC('cafe_advance_order',{p_id:order.id,p_status:'delivered'}),/SEM_PERMISSAO/);
  sessionStorage.setItem('cafe-demo-role','caixa');
  await demoRPC('cafe_advance_order',{p_id:order.id,p_status:'delivered'});
  assert.ok(!(await demoRPC('cafe_board')).ready.some(o=>o.number===order.number));
 }finally{for(const [key,value] of Object.entries(previous)){if(value===undefined)delete globalThis[key];else globalThis[key]=value;}}
});
