begin;
create function pg_temp.check_true(value boolean,message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
create function pg_temp.denied(statement text) returns boolean language plpgsql as $$
begin execute statement;return false;exception when insufficient_privilege then return true;end $$;
create function pg_temp.invalid(statement text) returns boolean language plpgsql as $$
begin execute statement;return false;exception when others then return true;end $$;
insert into auth.users(id,email) values
('30000000-0000-4000-8000-000000000001','payment-customer@example.invalid'),
('30000000-0000-4000-8000-000000000002','payment-pharmacy@example.invalid'),
('30000000-0000-4000-8000-000000000003','payment-rider@example.invalid');
update public.profiles set role='pharmacy_owner' where id='30000000-0000-4000-8000-000000000002';
update public.profiles set role='delivery_partner',service_postal_codes=array['382010'] where id='30000000-0000-4000-8000-000000000003';
insert into public.pharmacies(id,name,postal_codes,active,pickup_address,contact_phone,license_reference,verified_at) values
('31000000-0000-4000-8000-000000000001','Test pharmacy',array['382010'],true,'123 Fictional Pickup Road','+919876543211','TEST',now());
insert into public.pharmacy_members values('31000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002');
insert into public.inventory_lots(id,pharmacy_id,medicine_name,batch_number,expires_on,unit_price_paise,on_hand) values
('33000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001','Test medicine','STOCK',current_date+365,10000,2),
('33000000-0000-4000-8000-000000000002','31000000-0000-4000-8000-000000000001','Expired medicine','EXPIRED',current_date-1,10000,10);
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select pg_temp.check_true((select count(*)=0 from public.inventory_lots),'customers cannot read stock');
select pg_temp.check_true(pg_temp.denied('select public.payment_work()'),'client cannot read payment work');
select pg_temp.check_true(pg_temp.denied($q$select public.payment_captured('order_test','pay_test',1)$q$),'client cannot forge payment');
select public.create_order('32000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000001','123 Fictional Address','382010','[{"name":"Test","quantity":2}]',null,'','+919876543210')->>'id' as order_id \gset
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select pg_temp.check_true(pg_temp.invalid(format('select public.transition_order(%L,''quote'',20000)',:'order_id')),'unitemized quote rejected');
select pg_temp.check_true(pg_temp.invalid(format('select public.quote_order(%L,''[{"lot_id":"33000000-0000-4000-8000-000000000002","quantity":1}]'',0,''Reviewed'')',:'order_id')),'expired stock rejected');
select public.quote_order(:'order_id','[{"lot_id":"33000000-0000-4000-8000-000000000001","quantity":2}]',1000,'Prescription and eligibility checked');
select pg_temp.check_true((select reserved=2 from public.inventory_lots where id='33000000-0000-4000-8000-000000000001'),'quote reserves stock');
select pg_temp.check_true((select quote_paise=21000 and jsonb_array_length(quote_items)=1 from public.orders where id=:'order_id'),'server calculates itemized total');
select pg_temp.check_true(pg_temp.invalid($q$select public.save_inventory('31000000-0000-4000-8000-000000000001','Test medicine','STOCK',current_date+365,10000,1,'33000000-0000-4000-8000-000000000001')$q$),'stock cannot fall below reservations');
reset role;
set local role service_role;
select public.payment_begin('30000000-0000-4000-8000-000000000001',:'order_id')->>'id' as payment_id \gset
select pg_temp.check_true(not (public.payment_begin('30000000-0000-4000-8000-000000000001',:'order_id')->>'create_provider')::boolean,'provider creation reserved exactly once');
select public.payment_attach(:'payment_id','order_test');
select pg_temp.check_true(pg_temp.invalid($q$select public.payment_captured('order_test','pay_test',1)$q$),'captured amount mismatch rejected');
select public.payment_captured('order_test','pay_test',21000);
select public.payment_captured('order_test','pay_test',21000);
reset role;
select pg_temp.check_true((select count(*)=3 from public.order_events where order_id=:'order_id'),'duplicate capture does not duplicate transition');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select pg_temp.check_true((select status='confirmed' and payment_status='paid' from public.orders where id=:'order_id'),'capture confirms prepaid order');
select public.transition_order(:'order_id','cancel');
reset role;
select pg_temp.check_true((select reserved=0 and on_hand=2 from public.inventory_lots where id='33000000-0000-4000-8000-000000000001'),'cancellation releases reservations');
select pg_temp.check_true((select status='refund_pending' from public.payments where id=:'payment_id'),'cancellation queues refund');
set local role service_role;
select public.payment_refunded('pay_test','rfnd_test',21000);
select public.payment_refunded('pay_test','rfnd_test',21000);
select public.payment_captured('order_test','pay_test',21000);
reset role;
select pg_temp.check_true((select payment_status='refunded' and status='cancelled' from public.orders where id=:'order_id'),'late duplicate capture cannot undo refund');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.create_order('32000000-0000-4000-8000-000000000002','31000000-0000-4000-8000-000000000001','123 Fictional Address','382010','[{"name":"Test","quantity":1}]',null,'','+919876543210')->>'id' as late_id \gset
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.quote_order(:'late_id','[{"lot_id":"33000000-0000-4000-8000-000000000001","quantity":1}]',0,'Reviewed prescription');
reset role;
set local role service_role;
select public.payment_begin('30000000-0000-4000-8000-000000000001',:'late_id')->>'id' as late_payment \gset
select public.payment_attach(:'late_payment','order_late');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''confirm'')',:'late_id')),'pending prepaid cannot become COD');
select public.transition_order(:'late_id','cancel');
reset role;
set local role service_role;
select public.payment_captured('order_late','pay_late',10000);
reset role;
select pg_temp.check_true((select status='cancelled' and payment_status='refund_pending' from public.orders where id=:'late_id'),'late payment refunded without reviving cancelled order');
select pg_temp.check_true((select count(*)=5 from public.payment_events where payment_id=:'payment_id'),'payment audit records transitions exactly once');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.create_order('32000000-0000-4000-8000-000000000003','31000000-0000-4000-8000-000000000001','123 Fictional Address','382010','[{"name":"Test","quantity":1}]',null,'','+919876543210')->>'id' as delivered_id \gset
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.quote_order(:'delivered_id','[{"lot_id":"33000000-0000-4000-8000-000000000001","quantity":1}]',0,'Reviewed prescription');
reset role;
set local role service_role;
select public.payment_begin('30000000-0000-4000-8000-000000000001',:'delivered_id')->>'id' as delivered_payment \gset
select public.payment_attach(:'delivered_payment','order_delivered');
select public.payment_captured('order_delivered','pay_delivered',10000);
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.transition_order(:'delivered_id','prepare');
select public.transition_order(:'delivered_id','ready');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
select public.transition_order(:'delivered_id','accept');
select public.transition_order(:'delivered_id','pickup');
select public.transition_order(:'delivered_id','deliver');
select pg_temp.check_true(public.list_orders(0)->0->>'delivery_address'='','completed delivery hides exact address from rider');
reset role;
select pg_temp.check_true((select status='delivered' and payment_status='paid' from public.orders where id=:'delivered_id'),'prepaid delivery never collects cash');
select pg_temp.check_true((select on_hand=1 and reserved=0 from public.inventory_lots where id='33000000-0000-4000-8000-000000000001'),'delivery consumes stock exactly once');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.create_order('32000000-0000-4000-8000-000000000004','31000000-0000-4000-8000-000000000001','123 Fictional Address','382010','[{"name":"Test","quantity":1}]',null,'','+919876543210')->>'id' as expired_id \gset
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.quote_order(:'expired_id','[{"lot_id":"33000000-0000-4000-8000-000000000001","quantity":1}]',0,'Reviewed prescription');
reset role;
set local role service_role;
select public.payment_begin('30000000-0000-4000-8000-000000000001',:'expired_id')->>'id' as expired_payment \gset
select public.payment_attach(:'expired_payment','order_expired');
reset role;
update public.inventory_lots set expires_on=current_date where id='33000000-0000-4000-8000-000000000001';
set local role service_role;
select public.payment_captured('order_expired','pay_expired',10000);
reset role;
select pg_temp.check_true((select status='cancelled' and payment_status='refund_pending' from public.orders where id=:'expired_id'),'expiry during checkout queues refund');
select pg_temp.check_true((select reserved=0 from public.inventory_lots where id='33000000-0000-4000-8000-000000000001'),'expiry cancellation releases stock');
rollback;
\echo Production stock and payment assertions passed.
