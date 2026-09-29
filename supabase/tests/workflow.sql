-- Run with psql -v ON_ERROR_STOP=1 against a disposable Supabase database.
begin;
create function pg_temp.check_true(value boolean, message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
create function pg_temp.denied(statement text) returns boolean language plpgsql as $$
begin execute statement; return false; exception when insufficient_privilege then return true; end $$;
create function pg_temp.invalid(statement text) returns boolean language plpgsql as $$
begin execute statement; return false; exception when others then return true; end $$;

insert into auth.users(id,email,raw_user_meta_data) values
 ('20000000-0000-0000-0000-000000000001','customer1@example.invalid','{"role":"admin"}'),
 ('20000000-0000-0000-0000-000000000002','customer2@example.invalid','{}'),
 ('20000000-0000-0000-0000-000000000003','pharmacist1@example.invalid','{}'),
 ('20000000-0000-0000-0000-000000000004','pharmacist2@example.invalid','{}'),
 ('20000000-0000-0000-0000-000000000005','rider1@example.invalid','{}'),
 ('20000000-0000-0000-0000-000000000006','rider2@example.invalid','{}'),
 ('20000000-0000-0000-0000-000000000007','operator@example.invalid','{}');
select pg_temp.check_true((select role='customer' from public.profiles where id='20000000-0000-0000-0000-000000000001'),'metadata cannot grant admin');
update public.profiles set role='pharmacy_owner' where id in ('20000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000004');
update public.profiles set role='delivery_partner', service_postal_codes=array['382010'] where id in ('20000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000006');
update public.profiles set role='admin' where id='20000000-0000-0000-0000-000000000007';
insert into public.pharmacies(id,name,postal_codes,active) values
 ('21000000-0000-0000-0000-000000000001','Test pharmacy one',array['382010'],true),
 ('21000000-0000-0000-0000-000000000002','Test pharmacy two',array['382010'],true);
insert into public.pharmacy_members values
 ('21000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000003'),
 ('21000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000004');

set local role anon;
select pg_temp.check_true(pg_temp.denied('select public.list_orders(0)'),'anonymous order access denied');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true(pg_temp.denied($q$update public.profiles set role='admin'$q$),'profile escalation denied');
select pg_temp.check_true(pg_temp.denied($q$insert into public.orders(customer_id) values(auth.uid())$q$),'direct order insert denied');
select pg_temp.check_true(pg_temp.denied($q$update public.orders set status='delivered'$q$),'direct status update denied');
select pg_temp.check_true(pg_temp.invalid($q$select public.create_order('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','123 Fictional Road','999999','[{"name":"Sample","quantity":1}]')$q$),'serviceability enforced');
select pg_temp.check_true(pg_temp.invalid($q$select public.create_order('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[{"name":"Sample","quantity":-1}]')$q$),'quantity validated');
select pg_temp.check_true(pg_temp.invalid($q$select public.create_order('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[{"name":"Sample"}]')$q$),'missing quantity rejected');
select public.create_order('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[{"name":"Sample medicine","quantity":2}]')->>'id' as order_id \gset
select pg_temp.check_true(public.create_order('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[{"name":"Sample medicine","quantity":2}]')->>'id'=:'order_id','retry returns same order');
select pg_temp.check_true((select count(*)=1 from public.order_events where order_id=:'order_id'),'retry creates one event');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''quote'',1000)',:'order_id')),'customer cannot quote');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
select pg_temp.check_true((select count(*)=0 from public.orders where id=:'order_id'),'other customer cannot read');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''cancel'')',:'order_id')),'other customer cannot cancel');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000004',true);
select pg_temp.check_true((select count(*)=0 from public.orders where id=:'order_id'),'other pharmacy cannot read');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''quote'',1000)',:'order_id')),'other pharmacy cannot quote');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000003',true);
select public.transition_order(:'order_id','quote',25050);
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''ready'')',:'order_id')),'cannot skip customer confirmation');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select public.transition_order(:'order_id','confirm');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000003',true);
select public.transition_order(:'order_id','prepare');
select public.transition_order(:'order_id','ready');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000005',true);
select pg_temp.check_true((select count(*)=0 from public.orders where id=:'order_id'),'rider cannot read medical rows');
select pg_temp.check_true(not (public.list_orders(0)->0 ? 'items'),'dispatch projection has no medicines');
select pg_temp.check_true(public.list_orders(0)->0->>'delivery_address'='','address hidden before assignment');
select public.transition_order(:'order_id','accept');
select pg_temp.check_true(public.list_orders(0)->0->>'delivery_address'='123 Fictional Road','assigned rider can see address');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000006',true);
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''accept'')',:'order_id')),'second rider cannot claim');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''pickup'')',:'order_id')),'other rider cannot pick up');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000005',true);
select public.transition_order(:'order_id','pickup');
select public.transition_order(:'order_id','deliver');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''deliver'')',:'order_id')),'duplicate delivery rejected');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true((select status='delivered' and payment_status='cash_collected' from public.orders where id=:'order_id'),'complete COD lifecycle');
select pg_temp.check_true((select count(*)=8 from public.order_events where order_id=:'order_id'),'all transitions audited');
reset role;
-- Actual Storage object policies (metadata fixtures, not image blobs).
insert into storage.objects(bucket_id,name) values ('prescriptions','20000000-0000-0000-0000-000000000001/22000000-0000-0000-0000-000000000002.jpg');
set local role authenticated;
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select public.create_order('22000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[]','20000000-0000-0000-0000-000000000001/22000000-0000-0000-0000-000000000002.jpg');
select pg_temp.check_true((select count(*)=1 from storage.objects where bucket_id='prescriptions'),'owner reads own prescription');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000002',true);
select pg_temp.check_true((select count(*)=0 from storage.objects where bucket_id='prescriptions'),'other customer cannot read image');
select pg_temp.check_true(pg_temp.denied($q$insert into storage.objects(bucket_id,name) values('prescriptions','20000000-0000-0000-0000-000000000001/22000000-0000-0000-0000-000000000003.jpg')$q$),'cannot upload to another customer folder');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000003',true);
select pg_temp.check_true((select count(*)=1 from storage.objects where bucket_id='prescriptions'),'assigned pharmacy reads image');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000004',true);
select pg_temp.check_true((select count(*)=0 from storage.objects where bucket_id='prescriptions'),'other pharmacy cannot read image');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000005',true);
select pg_temp.check_true((select count(*)=0 from storage.objects where bucket_id='prescriptions'),'rider cannot read prescription');

select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true(pg_temp.invalid($q$select public.create_order('22000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','999 Different Address','382010','[{"name":"Sample medicine","quantity":2}]')$q$),'idempotency key cannot change payload');
select public.create_order('22000000-0000-0000-0000-000000000003','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[{"name":"Sample","quantity":1}]')->>'id' as cancelled_id \gset
select public.transition_order(:'cancelled_id','cancel');
select pg_temp.check_true((select status='cancelled' from public.orders where id=:'cancelled_id'),'customer cancellation persists');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''confirm'')',:'cancelled_id')),'cancelled order cannot resume');
select public.create_order('22000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001','123 Fictional Road','382010','[{"name":"Sample","quantity":1}]')->>'id' as failed_id \gset
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000003',true);
select pg_temp.check_true(pg_temp.invalid(format('select public.transition_order(%L,''reject'',null,null)',:'failed_id')),'rejection needs a reason');
select public.transition_order(:'failed_id','quote',10000);
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000001',true);
select public.transition_order(:'failed_id','confirm');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000003',true);
select public.transition_order(:'failed_id','prepare');
select public.transition_order(:'failed_id','ready');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000005',true);
select public.transition_order(:'failed_id','accept');
select public.transition_order(:'failed_id','pickup');
select public.transition_order(:'failed_id','fail',null,'Customer unavailable; returned to pharmacy');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''redispatch'')',:'failed_id')),'rider cannot redispatch');
select set_config('request.jwt.claim.sub','20000000-0000-0000-0000-000000000007',true);
select public.transition_order(:'failed_id','redispatch');
select pg_temp.check_true((select status='ready' and rider_id is null and payment_status='cash_due' from public.orders where id=:'failed_id'),'redispatch resets assignment without collecting cash');
select pg_temp.check_true(pg_temp.denied('delete from public.order_events'),'audit log is immutable for clients');
rollback;
\echo Workflow and authorization assertions passed.
