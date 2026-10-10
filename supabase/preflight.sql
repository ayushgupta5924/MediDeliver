-- READ ONLY. Run as an operator before planning any hosted migration.
select version();
select table_name,column_name,data_type from information_schema.columns
where table_schema='public' and table_name in ('profiles','pharmacies','pharmacy_members','orders','order_events','payments','inventory_lots','order_lots')
order by table_name,ordinal_position;
select proname,pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
and proname in ('create_order','create_order_internal','transition_order','list_orders','quote_order','payment_begin');
select tablename,policyname,roles,cmd from pg_policies where schemaname='public';
select status,count(*) from public.orders group by status;
select count(*) as active_pharmacies from public.pharmacies where active;
-- No customer addresses, prescriptions, emails or payment secrets are selected.
