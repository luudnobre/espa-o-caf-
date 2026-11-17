-- 1. Crie e confirme este usuário em Authentication > Users > Add user.
-- 2. Se quiser outro administrador, altere SOMENTE o e-mail abaixo.
do $$
declare admin_email text:='dknsdaniel@gmail.com'; admin_id uuid;
begin
 select id into admin_id from auth.users where lower(email)=lower(admin_email) and email_confirmed_at is not null;
 if admin_id is null then raise exception 'Crie e confirme o usuário % em Authentication > Users antes de executar este arquivo.',admin_email; end if;
 insert into cafe_private.staff(user_id,role,active) values(admin_id,'admin',true) on conflict(user_id) do update set role='admin',active=true;
end $$;
select 'Administrador autorizado. Configure o .env.local e entre em /login.' as resultado;
