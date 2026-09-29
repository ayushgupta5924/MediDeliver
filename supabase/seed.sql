-- LOCAL/STAGING ONLY. Fictional identities; no passwords, no messages, no real prescriptions.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('10000000-0000-0000-0000-000000000001','demo-customer@example.invalid','{}'),
 ('10000000-0000-0000-0000-000000000002','demo-pharmacist@example.invalid','{}'),
 ('10000000-0000-0000-0000-000000000003','demo-rider@example.invalid','{}'),
 ('10000000-0000-0000-0000-000000000004','demo-operator@example.invalid','{}') on conflict (id) do nothing;
update public.profiles set full_name='Demo Customer' where id='10000000-0000-0000-0000-000000000001';
update public.profiles set role='pharmacy_owner',full_name='Demo Pharmacist' where id='10000000-0000-0000-0000-000000000002';
update public.profiles set role='delivery_partner',full_name='Demo Rider',service_postal_codes=array['382010'] where id='10000000-0000-0000-0000-000000000003';
update public.profiles set role='admin',full_name='Demo Operator' where id='10000000-0000-0000-0000-000000000004';
insert into public.pharmacies(id,name,postal_codes,active) values ('11000000-0000-0000-0000-000000000001','Demo Community Pharmacy',array['382010'],true) on conflict(id) do nothing;
insert into public.pharmacy_members values ('11000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002') on conflict do nothing;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select public.create_order('12000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','12 Fictional Garden, Demo District','382010','[{"name":"Sample item A (fictional), pack of 10","quantity":2}]',null,'Synthetic order for workflow testing.');
select public.create_order('12000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000001','24 Fictional Garden, Demo District','382010','[{"name":"Sample item B (fictional), 100 ml","quantity":1}]',null,'Synthetic order awaiting pharmacy review.');
-- Populate several lifecycle stages, with auditable actors and realistic order shapes.
do $$
declare o public.orders; action text;
begin
  select * into o from public.orders where request_id='12000000-0000-0000-0000-000000000001';
  if o.status='submitted' then
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
    perform public.transition_order(o.id,'quote',18450);
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
    perform public.transition_order(o.id,'confirm');
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
    perform public.transition_order(o.id,'prepare');
    perform public.transition_order(o.id,'ready');
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
    perform public.transition_order(o.id,'accept');
    perform public.transition_order(o.id,'pickup');
    perform public.transition_order(o.id,'deliver');
  end if;
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
  perform public.create_order('12000000-0000-0000-0000-000000000003','11000000-0000-0000-0000-000000000001','36 Fictional Garden, Demo District','382010','[{"name":"Sample item C (fictional), pack of 15","quantity":1}]',null,'Synthetic request with unavailable stock.');
  select * into o from public.orders where request_id='12000000-0000-0000-0000-000000000003';
  if o.status='submitted' then
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
    perform public.transition_order(o.id,'reject',null,'Requested item unavailable. Please contact the pharmacy.');
  end if;
  perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
  perform public.create_order('12000000-0000-0000-0000-000000000004','11000000-0000-0000-0000-000000000001','48 Fictional Garden, Demo District','382010','[{"name":"Sample item D (fictional), 50 g","quantity":1}]',null,'Synthetic order ready for dispatch.');
  select * into o from public.orders where request_id='12000000-0000-0000-0000-000000000004';
  if o.status='submitted' then
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
    perform public.transition_order(o.id,'quote',13200);
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
    perform public.transition_order(o.id,'confirm');
    perform set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
    perform public.transition_order(o.id,'prepare');
    perform public.transition_order(o.id,'ready');
  end if;
end $$;
commit;
