-- Explicit opt-in sample catalog. No auth identities or staff permissions are created.
-- Run only for the sample deployment, with real payment collection disabled.
begin;
insert into public.pharmacies(id,name,postal_codes,active,pickup_address,contact_phone,license_reference,verified_at)
values
 ('21000000-0000-4000-8000-000000000001','Sample - Greenleaf Pharmacy',array['382010','382011'],true,'Sample pickup counter A, fictional address','+910000000001','SAMPLE-NOT-A-LICENSE',now()),
 ('21000000-0000-4000-8000-000000000002','Sample - Sunrise Pharmacy',array['382010','382016'],true,'Sample pickup counter B, fictional address','+910000000002','SAMPLE-NOT-A-LICENSE',now())
on conflict(id) do nothing;
insert into public.inventory_lots(pharmacy_id,medicine_name,batch_number,expires_on,unit_price_paise,on_hand)
select p.id,v.name,'SAMPLE-2026',date '2028-12-31',v.price,100
from public.pharmacies p cross join (values
 ('Sample - Paracetamol 500 mg, 10 tablets',2500),
 ('Sample - Oral rehydration salts, 1 sachet',2200),
 ('Sample - Digital thermometer, 1 unit',19900),
 ('Sample - Adhesive bandages, pack of 10',4500),
 ('Sample - Sterile gauze, pack of 5',6000),
 ('Sample - Saline nasal spray, 20 ml',8500)
) v(name,price)
where p.id in ('21000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000002')
on conflict(pharmacy_id,medicine_name,batch_number) do nothing;
commit;
