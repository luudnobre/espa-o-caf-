-- Funções da versão anterior, para testar a migração.
create or replace function public.cafe_board() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ready',coalesce((select jsonb_agg(jsonb_build_object('number',o.number,'updated_at',o.updated_at) order by o.updated_at desc) from public.cafe_orders o join public.cafe_sessions s on s.id=o.session_id where s.state='open' and o.status='ready' and o.payment_status='paid'),'[]'::jsonb),'preparing',coalesce((select jsonb_agg(o.number order by o.number) from public.cafe_orders o join public.cafe_sessions s on s.id=o.session_id where s.state='open' and o.status='preparing' and o.payment_status='paid'),'[]'::jsonb))
$$;

create or replace function public.cafe_advance_order(p_id uuid,p_status text) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders;
begin
 perform cafe_private.require_role(array['admin','caixa','cozinha']);
 select * into o from public.cafe_orders where id=p_id for update;
 if not found then raise exception 'PEDIDO_NAO_ENCONTRADO'; end if;
 if o.payment_status<>'paid' then raise exception 'AGUARDE_PAGAMENTO'; end if;
 if o.status=p_status then return cafe_private.order_json(o); end if;
 if not ((o.status='queued' and p_status='preparing') or (o.status='preparing' and p_status='ready') or (o.status='ready' and p_status='delivered')) then raise exception 'ETAPA_INVALIDA'; end if;
 update public.cafe_orders set status=p_status,updated_at=now() where id=p_id returning * into o;
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('etapa_alterada',o.id,p_status,auth.uid());
 return cafe_private.order_json(o);
end $$;
