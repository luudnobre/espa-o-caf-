-- ESPAÇO CAFÉ / PAES CABO. Execute em um projeto novo do Supabase.
-- Reexecutável: não remove produtos, pedidos, usuários nem movimentações.
begin;
create schema if not exists cafe_private;
revoke all on schema cafe_private from public, anon, authenticated;
create table if not exists cafe_private.staff (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check(role in ('admin','caixa','cozinha')),
 active boolean not null default true
);
create table if not exists public.cafe_settings (
 id boolean primary key default true check(id), title text not null default 'Espaço Café',
 message text not null default 'O culto termina. A mesa continua.',
 public_ordering boolean not null default false,
 pix_key text not null default '', pix_name text not null default 'PAES CABO', pix_city text not null default 'CABO',
 updated_at timestamptz not null default now()
);
insert into public.cafe_settings(id) values(true) on conflict do nothing;
create table if not exists public.cafe_sessions (
 id uuid primary key default gen_random_uuid(), title text not null check(length(title) between 3 and 100),
 state text not null default 'open' check(state in ('open','closed')),
 opening_cash_cents integer not null default 0 check(opening_cash_cents>=0),
 counted_cash_cents integer, expected_cash_cents integer, closing_note text,
 opened_by uuid references auth.users(id), opened_at timestamptz not null default now(), closed_at timestamptz
);
create unique index if not exists cafe_one_open_session on public.cafe_sessions(state) where state='open';
create table if not exists public.cafe_products (
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 2 and 120),
 category text not null check(category in ('Salgados','Doces','Bebidas','Combos')),
 description text not null default '' check(length(description)<=1000),
 allergens text not null default '' check(length(allergens)<=300),
 price_cents integer not null check(price_cents between 1 and 1000000),
 stock integer not null default 0 check(stock between 0 and 100000),
 low_stock integer not null default 5 check(low_stock between 0 and 100000),
 image_url text not null default '', active boolean not null default true,
 featured boolean not null default false, prep_minutes integer not null default 5 check(prep_minutes between 0 and 120),
 updated_at timestamptz not null default now()
);
create sequence if not exists public.cafe_order_seq;
create table if not exists public.cafe_orders (
 id uuid primary key default gen_random_uuid(), number bigint not null default nextval('public.cafe_order_seq') unique,
 session_id uuid not null references public.cafe_sessions(id), request_id uuid not null unique,
 token uuid not null default gen_random_uuid() unique,
 customer_name text not null check(length(customer_name) between 2 and 80),
 notes text not null default '' check(length(notes)<=300), source text not null check(source in ('web','caixa')),
 items jsonb not null, total_cents integer not null check(total_cents>0),
 status text not null default 'queued' check(status in ('queued','preparing','ready','delivered','cancelled')),
 payment_status text not null default 'pending' check(payment_status in ('pending','paid','refunded')),
 payment_method text check(payment_method in ('dinheiro','pix','cartao')),
 cash_received_cents integer, paid_at timestamptz, paid_by uuid references auth.users(id),
 cancel_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists cafe_orders_session on public.cafe_orders(session_id,created_at desc);
create table if not exists public.cafe_payments (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.cafe_orders(id),
 session_id uuid not null references public.cafe_sessions(id), kind text not null check(kind in ('payment','refund')),
 amount_cents integer not null, method text not null check(method in ('dinheiro','pix','cartao')),
 actor_id uuid references auth.users(id), created_at timestamptz not null default now(), unique(order_id,kind)
);
create table if not exists public.cafe_cash_moves (
 id uuid primary key default gen_random_uuid(), session_id uuid not null references public.cafe_sessions(id),
 direction text not null check(direction in ('entrada','saida')), amount_cents integer not null check(amount_cents>0),
 reason text not null check(length(reason) between 3 and 200), actor_id uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.cafe_stock_moves (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.cafe_products(id),
 delta integer not null, reason text not null, actor_id uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.cafe_audit (
 id uuid primary key default gen_random_uuid(), action text not null, entity_id uuid,
 detail text not null default '', actor_id uuid references auth.users(id), created_at timestamptz not null default now()
);

create or replace function public.cafe_role() returns text language sql stable security definer set search_path='' as $$
 select s.role from cafe_private.staff s where s.user_id=auth.uid() and s.active
$$;
create or replace function cafe_private.require_role(p_roles text[]) returns void language plpgsql set search_path='' as $$
begin if public.cafe_role() is null or not (public.cafe_role()=any(p_roles)) then raise exception 'SEM_PERMISSAO'; end if; end $$;
create or replace function cafe_private.order_json(p public.cafe_orders) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',p.id,'number',p.number,'token',p.token,'customer_name',p.customer_name,'notes',p.notes,'source',p.source,'items',p.items,'total_cents',p.total_cents,'status',p.status,'payment_status',p.payment_status,'payment_method',p.payment_method,'cash_received_cents',p.cash_received_cents,'paid_at',p.paid_at,'created_at',p.created_at,'updated_at',p.updated_at,'cancel_reason',p.cancel_reason,'session_id',p.session_id)
$$;
create or replace function public.cafe_menu() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('settings',(select jsonb_build_object('title',title,'message',message,'public_ordering',public_ordering,'pix_key',pix_key,'pix_name',pix_name,'pix_city',pix_city) from public.cafe_settings where id),
 'session',(select jsonb_build_object('id',id,'title',title) from public.cafe_sessions where state='open'),
 'products',coalesce((select jsonb_agg(to_jsonb(p) order by p.featured desc,p.name) from public.cafe_products p where p.active),'[]'::jsonb))
$$;
create or replace function public.cafe_track(p_token uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select cafe_private.order_json(o) from public.cafe_orders o where o.token=p_token
$$;
create or replace function public.cafe_board() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('ready',coalesce((select jsonb_agg(jsonb_build_object('number',o.number,'updated_at',o.updated_at) order by o.updated_at desc) from public.cafe_orders o join public.cafe_sessions s on s.id=o.session_id where s.state='open' and o.status='ready' and o.payment_status='paid'),'[]'::jsonb),'preparing',coalesce((select jsonb_agg(o.number order by o.number) from public.cafe_orders o join public.cafe_sessions s on s.id=o.session_id where s.state='open' and o.status in ('queued','preparing') and o.payment_status='paid'),'[]'::jsonb))
$$;

create or replace function cafe_private.create_order(p_items jsonb,p_name text,p_notes text,p_request uuid,p_source text) returns public.cafe_orders language plpgsql set search_path='' as $$
declare s public.cafe_sessions; o public.cafe_orders; p public.cafe_products; r record; lines jsonb:='[]'; total integer:=0;
begin
 if p_request is null then raise exception 'REQUISICAO_INVALIDA'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request::text,1));
 select * into o from public.cafe_orders where request_id=p_request;
 if found then return o; end if;
 if length(trim(coalesce(p_name,''))) not between 2 and 80 or length(coalesce(p_notes,''))>300 then raise exception 'NOME_OU_OBSERVACAO_INVALIDOS'; end if;
 if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'CARRINHO_INVALIDO'; end if;
 if jsonb_array_length(p_items) not between 1 and 20 then raise exception 'CARRINHO_INVALIDO'; end if;
 if exists(select 1 from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer) where x.product_id is null or x.quantity is null or x.quantity not between 1 and 20) then raise exception 'QUANTIDADE_INVALIDA'; end if;
 select * into s from public.cafe_sessions where state='open' for update;
 if not found then raise exception 'CAIXA_FECHADO'; end if;
 if p_source='web' then
  if not (select public_ordering from public.cafe_settings where id) then raise exception 'PEDIDOS_ONLINE_PAUSADOS'; end if;
  if (select count(*) from public.cafe_orders where session_id=s.id and source='web' and payment_status='pending' and status<>'cancelled')>=60 then raise exception 'FILA_ONLINE_CHEIA'; end if;
 end if;
 for r in select x.product_id,sum(x.quantity)::integer quantity from jsonb_to_recordset(p_items) as x(product_id uuid,quantity integer) group by x.product_id order by x.product_id loop
  if r.quantity>20 then raise exception 'QUANTIDADE_INVALIDA'; end if;
  select * into p from public.cafe_products where id=r.product_id for update;
  if not found or not p.active then raise exception 'PRODUTO_INDISPONIVEL'; end if;
  if p.stock<r.quantity then raise exception 'ESTOQUE_INSUFICIENTE: %',p.name; end if;
  total:=total+p.price_cents*r.quantity;
  lines:=lines||jsonb_build_array(jsonb_build_object('product_id',p.id,'name',p.name,'price_cents',p.price_cents,'quantity',r.quantity,'category',p.category));
  update public.cafe_products set stock=stock-r.quantity,updated_at=now() where id=p.id;
  insert into public.cafe_stock_moves(product_id,delta,reason,actor_id) values(p.id,-r.quantity,'Reserva de pedido',auth.uid());
 end loop;
 if total>2000000 then raise exception 'LIMITE_DO_PEDIDO'; end if;
 insert into public.cafe_orders(session_id,request_id,customer_name,notes,source,items,total_cents) values(s.id,p_request,trim(p_name),trim(coalesce(p_notes,'')),p_source,lines,total) returning * into o;
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('pedido_criado',o.id,p_source,auth.uid());
 return o;
end $$;
create or replace function public.cafe_place_order(p_items jsonb,p_name text,p_notes text,p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders;
begin o:=cafe_private.create_order(p_items,p_name,p_notes,p_request,'web'); return cafe_private.order_json(o); end $$;

create or replace function public.cafe_pay_order(p_id uuid,p_method text,p_received integer default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders;
begin
 perform cafe_private.require_role(array['admin','caixa']);
 select * into o from public.cafe_orders where id=p_id for update;
 if not found then raise exception 'PEDIDO_NAO_ENCONTRADO'; end if;
 if o.payment_status='paid' then return cafe_private.order_json(o); end if;
 if o.status='cancelled' or o.payment_status='refunded' then raise exception 'PEDIDO_CANCELADO'; end if;
 if (select state from public.cafe_sessions where id=o.session_id)<>'open' then raise exception 'CAIXA_FECHADO'; end if;
 if p_method not in ('dinheiro','pix','cartao') or p_method is null then raise exception 'FORMA_INVALIDA'; end if;
 if p_method='dinheiro' and (p_received is null or p_received<o.total_cents or p_received>10000000) then raise exception 'VALOR_RECEBIDO_INSUFICIENTE'; end if;
 update public.cafe_orders set payment_status='paid',payment_method=p_method,cash_received_cents=case when p_method='dinheiro' then p_received else null end,paid_at=now(),paid_by=auth.uid(),updated_at=now() where id=p_id returning * into o;
 insert into public.cafe_payments(order_id,session_id,kind,amount_cents,method,actor_id) values(o.id,o.session_id,'payment',o.total_cents,p_method,auth.uid());
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('pagamento_confirmado',o.id,p_method,auth.uid());
 return cafe_private.order_json(o);
end $$;
create or replace function public.cafe_counter_order(p_items jsonb,p_name text,p_notes text,p_request uuid,p_method text default null,p_received integer default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders;
begin perform cafe_private.require_role(array['admin','caixa']); o:=cafe_private.create_order(p_items,p_name,p_notes,p_request,'caixa'); if p_method is not null then return public.cafe_pay_order(o.id,p_method,p_received); end if; return cafe_private.order_json(o); end $$;
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
create or replace function public.cafe_cancel_order(p_id uuid,p_reason text,p_refund_confirmed boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare o public.cafe_orders; r record;
begin
 perform cafe_private.require_role(array['admin','caixa']);
 select * into o from public.cafe_orders where id=p_id for update;
 if not found then raise exception 'PEDIDO_NAO_ENCONTRADO'; end if;
 if o.status='cancelled' then return cafe_private.order_json(o); end if;
 if (select state from public.cafe_sessions where id=o.session_id)<>'open' then raise exception 'CAIXA_FECHADO'; end if;
 if length(trim(coalesce(p_reason,''))) not between 3 and 200 then raise exception 'INFORME_MOTIVO'; end if;
 if o.payment_status='paid' and not p_refund_confirmed then raise exception 'CONFIRME_DEVOLUCAO_DO_DINHEIRO'; end if;
 if o.payment_status='paid' then insert into public.cafe_payments(order_id,session_id,kind,amount_cents,method,actor_id) values(o.id,o.session_id,'refund',-o.total_cents,o.payment_method,auth.uid()); end if;
 for r in select x.product_id,x.quantity from jsonb_to_recordset(o.items) as x(product_id uuid,quantity integer) order by x.product_id loop
  update public.cafe_products set stock=stock+r.quantity,updated_at=now() where id=r.product_id;
  insert into public.cafe_stock_moves(product_id,delta,reason,actor_id) values(r.product_id,r.quantity,'Cancelamento de pedido',auth.uid());
 end loop;
 update public.cafe_orders set status='cancelled',payment_status=case when payment_status='paid' then 'refunded' else payment_status end,cancel_reason=trim(p_reason),updated_at=now() where id=p_id returning * into o;
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('pedido_cancelado',o.id,p_reason,auth.uid());
 return cafe_private.order_json(o);
end $$;

create or replace function public.cafe_open_session(p_title text,p_opening integer) returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin perform cafe_private.require_role(array['admin','caixa']); if p_opening is null or p_opening not between 0 and 10000000 then raise exception 'VALOR_INVALIDO'; end if; if exists(select 1 from public.cafe_sessions where state='open') then raise exception 'JA_EXISTE_CAIXA_ABERTO'; end if; insert into public.cafe_sessions(title,opening_cash_cents,opened_by) values(trim(p_title),p_opening,auth.uid()) returning id into sid; insert into public.cafe_audit(action,entity_id,detail,actor_id) values('caixa_aberto',sid,p_title,auth.uid()); return sid; end $$;
create or replace function public.cafe_cash_move(p_direction text,p_amount integer,p_reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare s public.cafe_sessions; mid uuid;
begin perform cafe_private.require_role(array['admin','caixa']); select * into s from public.cafe_sessions where state='open' for update; if not found then raise exception 'CAIXA_FECHADO'; end if; if p_amount not between 1 and 10000000 or p_amount is null then raise exception 'VALOR_INVALIDO'; end if; insert into public.cafe_cash_moves(session_id,direction,amount_cents,reason,actor_id) values(s.id,p_direction,p_amount,trim(p_reason),auth.uid()) returning id into mid; insert into public.cafe_audit(action,entity_id,detail,actor_id) values('movimentacao_caixa',mid,p_direction||': '||p_reason,auth.uid()); return mid; end $$;
create or replace function public.cafe_close_session(p_id uuid,p_counted integer,p_note text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cafe_sessions; expected integer;
begin
 perform cafe_private.require_role(array['admin','caixa']);
 select * into s from public.cafe_sessions where id=p_id for update;
 if not found or s.state<>'open' then raise exception 'CAIXA_FECHADO'; end if;
 if p_counted is null or p_counted not between 0 and 10000000 then raise exception 'VALOR_INVALIDO'; end if;
 if exists(select 1 from public.cafe_orders where session_id=s.id and status not in ('delivered','cancelled')) then raise exception 'FINALIZE_OU_CANCELE_PEDIDOS_ABERTOS'; end if;
 select s.opening_cash_cents+coalesce((select sum(amount_cents) from public.cafe_payments where session_id=s.id and method='dinheiro'),0)+coalesce((select sum(case when direction='entrada' then amount_cents else -amount_cents end) from public.cafe_cash_moves where session_id=s.id),0) into expected;
 update public.cafe_sessions set state='closed',counted_cash_cents=p_counted,expected_cash_cents=expected,closing_note=left(coalesce(p_note,''),500),closed_at=now() where id=s.id;
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('caixa_fechado',s.id,'Contado '||p_counted||', esperado '||expected,auth.uid());
 return jsonb_build_object('expected',expected,'counted',p_counted,'difference',p_counted-expected);
end $$;

create or replace function public.cafe_save_product(p jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare pid uuid; old_stock integer;
begin
 perform cafe_private.require_role(array['admin']); pid:=coalesce(nullif(p->>'id','')::uuid,gen_random_uuid());
 if coalesce(p->>'image_url','')<>'' and not ((p->>'image_url') ~ '^https://[^[:space:]]+$' or (p->>'image_url') ~ '^/images/[a-zA-Z0-9_./-]+$') then raise exception 'IMAGEM_INVALIDA'; end if;
 select stock into old_stock from public.cafe_products where id=pid for update;
 -- Estoque é alterado em operação própria, para não sobrescrever vendas simultâneas.
 insert into public.cafe_products(id,name,category,description,allergens,price_cents,stock,low_stock,image_url,active,featured,prep_minutes)
 values(pid,trim(p->>'name'),p->>'category',coalesce(p->>'description',''),coalesce(p->>'allergens',''),(p->>'price_cents')::int,0,coalesce((p->>'low_stock')::int,5),coalesce(p->>'image_url',''),coalesce((p->>'active')::boolean,true),coalesce((p->>'featured')::boolean,false),coalesce((p->>'prep_minutes')::int,5))
 on conflict(id) do update set name=excluded.name,category=excluded.category,description=excluded.description,allergens=excluded.allergens,price_cents=excluded.price_cents,low_stock=excluded.low_stock,image_url=excluded.image_url,active=excluded.active,featured=excluded.featured,prep_minutes=excluded.prep_minutes,updated_at=now();
 insert into public.cafe_audit(action,entity_id,detail,actor_id) values('produto_salvo',pid,p->>'name',auth.uid()); return pid;
end $$;
create or replace function public.cafe_adjust_stock(p_id uuid,p_delta integer,p_reason text) returns integer language plpgsql security definer set search_path='' as $$
declare p public.cafe_products; remaining integer;
begin perform cafe_private.require_role(array['admin']); select * into p from public.cafe_products where id=p_id for update; if not found then raise exception 'PRODUTO_INDISPONIVEL'; end if; if p_delta is null or p_delta=0 or abs(p_delta)>100000 or p.stock+p_delta<0 then raise exception 'AJUSTE_ESTOQUE_INVALIDO'; end if; if length(trim(coalesce(p_reason,''))) not between 3 and 200 then raise exception 'INFORME_MOTIVO'; end if; update public.cafe_products set stock=stock+p_delta,updated_at=now() where id=p_id returning stock into remaining; insert into public.cafe_stock_moves(product_id,delta,reason,actor_id) values(p_id,p_delta,trim(p_reason),auth.uid()); return remaining; end $$;
create or replace function public.cafe_save_settings(p jsonb) returns void language plpgsql security definer set search_path='' as $$
begin perform cafe_private.require_role(array['admin']); if length(trim(p->>'title')) not between 2 and 80 or length(coalesce(p->>'message',''))>200 or length(coalesce(p->>'pix_key',''))>100 then raise exception 'CONFIGURACAO_INVALIDA'; end if; update public.cafe_settings set title=trim(p->>'title'),message=coalesce(p->>'message',''),public_ordering=coalesce((p->>'public_ordering')::boolean,false),pix_key=trim(coalesce(p->>'pix_key','')),pix_name=left(coalesce(p->>'pix_name','PAES CABO'),25),pix_city=left(coalesce(p->>'pix_city','CABO'),15),updated_at=now() where id; insert into public.cafe_audit(action,detail,actor_id) values('configuracoes_salvas','Cardápio e Pix',auth.uid()); end $$;
create or replace function public.cafe_set_staff(p_email text,p_role text,p_active boolean default true) returns void language plpgsql security definer set search_path='' as $$
declare uid uuid;
begin perform cafe_private.require_role(array['admin']); select id into uid from auth.users where lower(email)=lower(trim(p_email)) and email_confirmed_at is not null; if uid is null then raise exception 'CRIE_E_CONFIRME_USUARIO_NO_SUPABASE'; end if; if (select role='admin' and active from cafe_private.staff where user_id=uid) and (p_role<>'admin' or not p_active) and (select count(*) from cafe_private.staff where role='admin' and active)=1 then raise exception 'MANTENHA_UM_ADMINISTRADOR'; end if; insert into cafe_private.staff values(uid,p_role,p_active) on conflict(user_id) do update set role=excluded.role,active=excluded.active; insert into public.cafe_audit(action,entity_id,detail,actor_id) values('equipe_alterada',uid,p_role,auth.uid()); end $$;

create or replace function public.cafe_staff_state(p_session uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sid uuid; r text;
begin
 perform cafe_private.require_role(array['admin','caixa','cozinha']); r:=public.cafe_role();
 sid:=coalesce(p_session,(select id from public.cafe_sessions order by (state='open') desc,opened_at desc limit 1));
 return jsonb_build_object('role',r,'session_id',sid,
 'settings',(select to_jsonb(s) from public.cafe_settings s where id),
 'products',coalesce((select jsonb_agg(to_jsonb(p) order by p.name) from public.cafe_products p),'[]'::jsonb),
 'sessions',coalesce((select jsonb_agg(to_jsonb(s) order by s.opened_at desc) from (select * from public.cafe_sessions order by opened_at desc limit 60) s),'[]'::jsonb),
 'orders',coalesce((select jsonb_agg(cafe_private.order_json(o) order by o.created_at desc) from public.cafe_orders o where o.session_id=sid and (r<>'cozinha' or o.payment_status='paid')),'[]'::jsonb),
 'payments',case when r='cozinha' then '[]'::jsonb else coalesce((select jsonb_agg(to_jsonb(p) order by created_at desc) from public.cafe_payments p where session_id=sid),'[]'::jsonb) end,
 'cash_moves',case when r='cozinha' then '[]'::jsonb else coalesce((select jsonb_agg(to_jsonb(m) order by created_at desc) from public.cafe_cash_moves m where session_id=sid),'[]'::jsonb) end,
 'stock_moves',case when r<>'admin' then '[]'::jsonb else coalesce((select jsonb_agg(to_jsonb(m) order by created_at desc) from (select * from public.cafe_stock_moves order by created_at desc limit 50) m),'[]'::jsonb) end,
 'audit',case when r<>'admin' then '[]'::jsonb else coalesce((select jsonb_agg(to_jsonb(a) order by created_at desc) from (select * from public.cafe_audit order by created_at desc limit 30) a),'[]'::jsonb) end,
 'staff',case when r<>'admin' then '[]'::jsonb else coalesce((select jsonb_agg(jsonb_build_object('email',u.email,'role',s.role,'active',s.active)) from cafe_private.staff s join auth.users u on u.id=s.user_id),'[]'::jsonb) end);
end $$;

-- Tabelas nunca podem ser gravadas diretamente pelo navegador.
do $$ declare t text; begin foreach t in array array['cafe_settings','cafe_sessions','cafe_products','cafe_orders','cafe_payments','cafe_cash_moves','cafe_stock_moves','cafe_audit'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('drop policy if exists cafe_staff_read on public.%I',t);
 if t='cafe_orders' then
  execute format('create policy cafe_staff_read on public.%I for select to authenticated using (public.cafe_role() in (''admin'',''caixa'') or (public.cafe_role()=''cozinha'' and payment_status=''paid''))',t);
 elsif t in ('cafe_payments','cafe_cash_moves') then
  execute format('create policy cafe_staff_read on public.%I for select to authenticated using (public.cafe_role() in (''admin'',''caixa''))',t);
 elsif t in ('cafe_stock_moves','cafe_audit') then
  execute format('create policy cafe_staff_read on public.%I for select to authenticated using (public.cafe_role()=''admin'')',t);
 else
  execute format('create policy cafe_staff_read on public.%I for select to authenticated using (public.cafe_role() is not null)',t);
 end if;
end loop; end $$;
-- Todas as funções novas têm acesso explicitamente definido.
do $$ declare f record; begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='public' and p.proname like 'cafe_%') or n.nspname='cafe_private' loop execute format('revoke execute on function %s from public, anon, authenticated',f.signature); if f.signature::text not like 'cafe_private.%' then execute format('grant execute on function %s to authenticated',f.signature); end if; end loop; end $$;
grant execute on function public.cafe_menu(),public.cafe_track(uuid),public.cafe_board(),public.cafe_place_order(jsonb,text,text,uuid) to anon;

-- Fotos públicas. Apenas administradores enviam ou removem arquivos.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('cafe-menu','cafe-menu',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
drop policy if exists cafe_images_read on storage.objects;
create policy cafe_images_read on storage.objects for select to public using(bucket_id='cafe-menu');
drop policy if exists cafe_images_insert on storage.objects;
create policy cafe_images_insert on storage.objects for insert to authenticated with check(bucket_id='cafe-menu' and public.cafe_role()='admin');
drop policy if exists cafe_images_delete on storage.objects;
create policy cafe_images_delete on storage.objects for delete to authenticated using(bucket_id='cafe-menu' and public.cafe_role()='admin');
-- Realtime para a equipe. Clientes acompanham apenas o próprio pedido via token.
do $$ declare t text; begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then foreach t in array array['cafe_orders','cafe_products','cafe_sessions','cafe_settings'] loop if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then execute format('alter publication supabase_realtime add table public.%I',t); end if; end loop; end if; end $$;
notify pgrst,'reload schema';
commit;
select 'Estrutura pronta. Execute 02-administrador.sql depois de criar seu usuário.' as resultado;
