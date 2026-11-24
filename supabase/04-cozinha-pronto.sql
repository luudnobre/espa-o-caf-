-- ESPAÇO CAFÉ: atualização da cozinha em instalação já existente.
-- Execute SOMENTE depois de 01-estrutura.sql. Atualiza duas funções, não apaga dados.
-- Feche temporariamente as abas antigas da equipe e publique o código novo em seguida.
begin;
create or replace function public.cafe_board() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ready',coalesce((select jsonb_agg(jsonb_build_object('number',o.number,'updated_at',o.updated_at) order by o.updated_at desc) from public.cafe_orders o join public.cafe_sessions s on s.id=o.session_id where s.state='open' and o.status='ready' and o.payment_status='paid'),'[]'::jsonb),'preparing',coalesce((select jsonb_agg(o.number order by o.number) from public.cafe_orders o join public.cafe_sessions s on s.id=o.session_id where s.state='open' and o.status in ('queued','preparing') and o.payment_status='paid'),'[]'::jsonb))
$$;

create or replace function public.cafe_advance_order(p_id uuid,p_status text) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders; r text;
begin
 perform cafe_private.require_role(array['admin','caixa','cozinha']);
 r:=public.cafe_role();
 select * into o from public.cafe_orders where id=p_id for update;
 if not found then raise exception 'PEDIDO_NAO_ENCONTRADO'; end if;
 if o.payment_status<>'paid' then raise exception 'AGUARDE_PAGAMENTO'; end if;
 -- A cozinha marca apenas pronto. Caixa/admin confirmam a retirada.
 if r='cozinha' and p_status is distinct from 'ready' then raise exception 'SEM_PERMISSAO'; end if;
 if o.status=p_status then return cafe_private.order_json(o); end if;
 -- Preparo antigo continua aceito para clientes anteriores de caixa/admin.
 if not ((o.status in ('queued','preparing') and p_status='ready') or (o.status='ready' and p_status='delivered' and r in ('admin','caixa')) or (o.status='queued' and p_status='preparing' and r in ('admin','caixa'))) then raise exception 'ETAPA_INVALIDA'; end if;
 update public.cafe_orders set status=p_status,updated_at=now() where id=p_id returning * into o;
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('etapa_alterada',o.id,p_status,auth.uid());
 return cafe_private.order_json(o);
end $$;

-- Mantém o mesmo modelo de acesso da instalação original.
revoke execute on function public.cafe_advance_order(uuid,text) from public, anon;
grant execute on function public.cafe_advance_order(uuid,text) to authenticated;
grant execute on function public.cafe_board() to anon, authenticated;
notify pgrst,'reload schema';
commit;
select 'Cozinha atualizada: pedidos pagos podem ser marcados como prontos.' as resultado;
