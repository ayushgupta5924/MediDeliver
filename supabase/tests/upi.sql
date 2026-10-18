begin;
create function pg_temp.check_true(value boolean,message text) returns void language plpgsql as $$
begin if value is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
create function pg_temp.denied(statement text) returns boolean language plpgsql as $$
begin execute statement;return false;exception when insufficient_privilege then return true;end $$;
create function pg_temp.invalid(statement text) returns boolean language plpgsql as $$
begin execute statement;return false;exception when others then return true;end $$;
create function pg_temp.expired_delivery(statement text) returns boolean language plpgsql as $$
begin execute statement;return false;exception when raise_exception then return sqlerrm='Reserved stock has expired; cancel and review a new request';end $$;
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

insert into auth.users(id,email) values('30000000-0000-4000-8000-000000000004','upi-admin@example.invalid');
update public.profiles set role='admin' where id='30000000-0000-4000-8000-000000000004';
set local role service_role;
select pg_temp.check_true(pg_temp.invalid(format('select public.upi_begin(%L,%L,''mock'',null,''Mock'',%L)','30000000-0000-4000-8000-000000000003',:'order_id',repeat('a',64))),'other customer cannot checkout');
select public.upi_begin('30000000-0000-4000-8000-000000000001',:'order_id','mock',null,'Mock',repeat('a',64));
select pg_temp.check_true((public.upi_checkout(repeat('a',64))->>'amount_paise')::integer=21000,'UPI amount comes from quote');
select public.upi_begin('30000000-0000-4000-8000-000000000001',:'order_id','mock',null,'Mock',repeat('b',64));
select pg_temp.check_true(public.upi_checkout(repeat('a',64)) is null,'old checkout token revoked');
select pg_temp.check_true(pg_temp.invalid(format('select public.payment_begin(%L,%L)','30000000-0000-4000-8000-000000000001',:'order_id')),'cannot switch UPI to Razorpay');
select public.upi_claim(repeat('b',64),'123456789012');
select public.upi_claim(repeat('b',64),'123456789012');
select pg_temp.check_true(pg_temp.invalid($q$select public.upi_claim(repeat('b',64),'123456789013')$q$),'claim cannot be overwritten');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select pg_temp.check_true((select payment_status='pending' and status='quoted' from public.orders where id=:'order_id'),'claim does not fulfill');
select pg_temp.check_true((select count(*)=0 from public.upi_payments),'customer cannot read ledger tokens');
select pg_temp.check_true(pg_temp.denied(format('select public.transition_order(%L,''confirm'')',:'order_id')),'cannot switch UPI to COD');
select pg_temp.check_true(pg_temp.denied($q$select public.upi_checkout(repeat('b',64))$q$),'client cannot call service RPC');
select pg_temp.check_true(pg_temp.denied(format('select public.upi_review(%L,''123456789012'',21000,''Simulated bank credit checked'')',:'order_id')),'customer cannot approve own payment');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select pg_temp.check_true(pg_temp.denied(format('select public.upi_review(%L,''123456789012'',21000,''Simulated bank credit checked'')',:'order_id')),'pharmacy cannot approve bank credit');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select pg_temp.check_true(pg_temp.invalid(format('select public.upi_review(%L,''123456789012'',1,''Simulated bank credit checked'')',:'order_id')),'wrong amount rejected');
select public.upi_review(:'order_id','123456789012',21000,'Simulated bank credit checked');
select public.upi_review(:'order_id','123456789012',21000,'Simulated bank credit checked');
select pg_temp.check_true((select count(*)=3 from public.upi_events),'idempotent receipt audit');
select pg_temp.check_true((select payment_status='paid' and status='confirmed' from public.orders where id=:'order_id'),'verified credit confirms');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.transition_order(:'order_id','cancel');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select pg_temp.check_true((select status='refund_pending' from public.upi_payments where order_id=:'order_id'),'cancellation needs manual refund');
select public.upi_review(:'order_id','999999999999',21000,'Simulated refund verified in bank ledger',true);
select public.upi_review(:'order_id','999999999999',21000,'Simulated refund verified in bank ledger',true);
select public.upi_review(:'order_id','123456789012',21000,'Simulated bank credit checked');
select pg_temp.check_true((select payment_status='refunded' and status='cancelled' from public.orders where id=:'order_id'),'replay cannot revive refunded order');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.create_order('32000000-0000-4000-8000-000000000002','31000000-0000-4000-8000-000000000001','123 Fictional Address','382010','[{"name":"Test","quantity":1}]',null,'','+919876543210')->>'id' as late_id \gset
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.quote_order(:'late_id','[{"lot_id":"33000000-0000-4000-8000-000000000001","quantity":1}]',0,'Reviewed prescription');
reset role;
set local role service_role;
select public.upi_begin('30000000-0000-4000-8000-000000000001',:'late_id','mock',null,'Mock',repeat('c',64));
reset role;
update public.upi_payments set expires_at=now()-interval '1 minute' where order_id=:'late_id';
set local role service_role;
select public.upi_begin('30000000-0000-4000-8000-000000000001',:'late_id','mock',null,'Mock',repeat('d',64));
reset role;
select pg_temp.check_true((select expires_at<now() from public.upi_payments where order_id=:'late_id'),'resume does not extend payment window');
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select pg_temp.check_true(pg_temp.invalid(format('select public.upi_review(%L,''123456789012'',10000,''Simulated bank credit checked'')',:'late_id')),'UTR reuse rejected across orders');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.transition_order(:'late_id','cancel');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select public.upi_review(:'late_id','123456789014',10000,'Late simulated bank credit checked');
select pg_temp.check_true((select status='cancelled' and payment_status='refund_pending' from public.orders where id=:'late_id'),'late credit requires refund without reviving order');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000001',true);
select public.create_order('32000000-0000-4000-8000-000000000003','31000000-0000-4000-8000-000000000001','123 Fictional Address','382010','[{"name":"Test","quantity":1}]',null,'','+919876543210')->>'id' as delivery_id \gset
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.quote_order(:'delivery_id','[{"lot_id":"33000000-0000-4000-8000-000000000001","quantity":1}]',0,'Reviewed prescription');
reset role;
set local role service_role;
select public.upi_begin('30000000-0000-4000-8000-000000000001',:'delivery_id','mock',null,'Mock',repeat('e',64));
set local role authenticated;
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000004',true);
select public.upi_review(:'delivery_id','123456789015',10000,'Simulated bank credit checked');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000002',true);
select public.transition_order(:'delivery_id','prepare');
select public.transition_order(:'delivery_id','ready');
select set_config('request.jwt.claim.sub','30000000-0000-4000-8000-000000000003',true);
select public.transition_order(:'delivery_id','accept');
select public.transition_order(:'delivery_id','pickup');
select public.transition_order(:'delivery_id','deliver');
reset role;
select pg_temp.check_true((select status='delivered' and payment_status='paid' and payment_method='upi' from public.orders where id=:'delivery_id'),'UPI delivery never collects COD');
select pg_temp.check_true((select on_hand=1 and reserved=0 from public.inventory_lots where id='33000000-0000-4000-8000-000000000001'),'UPI delivery consumes stock once');
rollback;
