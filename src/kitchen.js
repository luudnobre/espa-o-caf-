import {age,e,number,time} from './core.js';
import {icon} from './icons.js';

// Pedidos em preparo da versão anterior permanecem visíveis após a atualização.
export function kitchenOrders(orders) {
 const paid=orders.filter(o=>o.payment_status==='paid');
 const byArrival=(a,b)=>new Date(a.created_at)-new Date(b.created_at);
 return {
  waiting:paid.filter(o=>['queued','preparing'].includes(o.status)).sort(byArrival),
  ready:paid.filter(o=>o.status==='ready').sort(byArrival),
 };
}

export function kitchenCard(o) {
 const ready=o.status==='ready';
 const button=ready
  ? '<div class="kitchen-ready">'+icon('check')+' Pronto para retirar</div>'
  : '<button type="button" class="button lime full" data-action="advance" data-id="'+e(o.id)+'" data-status="ready">'+icon('check')+' Pronto</button>';
 return `<article class="kitchen-card ${!ready&&age(o.created_at)>=15?'late':''}"><header><strong>#${number(o.number)}</strong><span>${icon('clock')} ${age(o.created_at)} min</span></header><h3>${e(o.customer_name)}</h3><ul>${o.items.map(i=>`<li><b>${i.quantity}</b><span>${e(i.name)}</span></li>`).join('')}</ul>${o.notes?`<p class="kitchen-note">${e(o.notes)}</p>`:''}<footer><span>${o.source==='web'?'Pedido online':'Pedido do caixa'} · ${time(o.created_at)}</span>${button}</footer></article>`;
}

export function kitchenBoard(orders) {
 const {waiting,ready}=kitchenOrders(orders);
 const column=(title,cls,items,empty)=>`<div class="kitchen-column"><div class="column-title"><span><i class="${cls}"></i>${title}</span><b>${items.length}</b></div><div class="kitchen-cards">${items.length?items.map(kitchenCard).join(''):`<div class="column-empty">${empty}</div>`}</div></div>`;
 return `<section class="kitchen-board">${column('A preparar','queued',waiting,'Os próximos pedidos chegam aqui.')}${column('Prontos para retirar','ready',ready,'Ainda não há pedidos prontos.')}</section>`;
}
