-- Atualização do Espaço Café existente. Não recria tabelas nem apaga pedidos.
begin;

alter table public.cafe_orders
  add column if not exists discount_cents integer not null default 0
  check (discount_cents >= 0);

create or replace function cafe_private.order_json(p public.cafe_orders)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'id',p.id,'number',p.number,'token',p.token,'customer_name',p.customer_name,
    'notes',p.notes,'source',p.source,'items',p.items,'total_cents',p.total_cents,
    'discount_cents',p.discount_cents,'status',p.status,'payment_status',p.payment_status,
    'payment_method',p.payment_method,'cash_received_cents',p.cash_received_cents,
    'paid_at',p.paid_at,'created_at',p.created_at,'updated_at',p.updated_at,
    'cancel_reason',p.cancel_reason,'session_id',p.session_id
  )
$$;

-- As funções antigas permanecem disponíveis para abas ainda abertas na versão anterior.
create or replace function public.cafe_pay_order_discount(
  p_id uuid, p_method text, p_received integer default null, p_discount integer default 0
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders; final_total integer;
begin
  perform cafe_private.require_role(array['admin','caixa']);
  select * into o from public.cafe_orders where id=p_id for update;
  if not found then raise exception 'PEDIDO_NAO_ENCONTRADO'; end if;
  if o.payment_status='paid' then return cafe_private.order_json(o); end if;
  if o.status='cancelled' or o.payment_status='refunded' then raise exception 'PEDIDO_CANCELADO'; end if;
  if (select state from public.cafe_sessions where id=o.session_id)<>'open' then raise exception 'CAIXA_FECHADO'; end if;
  if p_method is null or p_method not in ('dinheiro','pix','cartao') then raise exception 'FORMA_INVALIDA'; end if;
  if p_discount is null or p_discount<0 or p_discount>=o.total_cents then raise exception 'DESCONTO_INVALIDO'; end if;
  final_total:=o.total_cents-p_discount;
  if p_method='dinheiro' and (p_received is null or p_received<final_total or p_received>10000000) then
    raise exception 'VALOR_RECEBIDO_INSUFICIENTE';
  end if;
  update public.cafe_orders set total_cents=final_total,discount_cents=p_discount,
    payment_status='paid',payment_method=p_method,
    cash_received_cents=case when p_method='dinheiro' then p_received else null end,
    paid_at=now(),paid_by=auth.uid(),updated_at=now()
  where id=p_id returning * into o;
  insert into public.cafe_payments(order_id,session_id,kind,amount_cents,method,actor_id)
    values(o.id,o.session_id,'payment',o.total_cents,p_method,auth.uid());
  insert into public.cafe_audit(action,entity_id,detail,actor_id)
    values('pagamento_confirmado',o.id,p_method||' · desconto (centavos): '||p_discount,auth.uid());
  return cafe_private.order_json(o);
end $$;

create or replace function public.cafe_counter_order_discount(
  p_items jsonb, p_name text, p_notes text, p_request uuid,
  p_method text default null, p_received integer default null, p_discount integer default 0
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders;
begin
  perform cafe_private.require_role(array['admin','caixa']);
  if p_method is null and (p_discount is null or p_discount<>0) then
    raise exception 'DESCONTO_SOMENTE_AO_PAGAR';
  end if;
  o:=cafe_private.create_order(p_items,p_name,p_notes,p_request,'caixa');
  if p_method is not null then
    return public.cafe_pay_order_discount(o.id,p_method,p_received,p_discount);
  end if;
  return cafe_private.order_json(o);
end $$;

revoke execute on function public.cafe_pay_order_discount(uuid,text,integer,integer) from public,anon,authenticated;
revoke execute on function public.cafe_counter_order_discount(jsonb,text,text,uuid,text,integer,integer) from public,anon,authenticated;
grant execute on function public.cafe_pay_order_discount(uuid,text,integer,integer) to authenticated;
grant execute on function public.cafe_counter_order_discount(jsonb,text,text,uuid,text,integer,integer) to authenticated;
notify pgrst,'reload schema';
commit;
select 'Desconto do caixa atualizado com sucesso.' as resultado;
