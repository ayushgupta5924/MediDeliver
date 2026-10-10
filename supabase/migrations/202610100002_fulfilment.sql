begin;
alter table public.pharmacies add column pickup_address text not null default '';
alter table public.pharmacies add column contact_phone text not null default '';
alter table public.pharmacies add column license_reference text not null default '';
alter table public.pharmacies add column verified_at timestamptz;
alter table public.orders add column recipient_phone text not null default '';
alter table public.orders add column quote_items jsonb not null default '[]';
alter table public.orders add column delivery_fee_paise integer not null default 0 check(delivery_fee_paise between 0 and 1000000);
alter table public.orders add column reviewed_by uuid references public.profiles(id);
alter table public.orders add column reviewed_at timestamptz;
alter table public.orders add column review_note text;
create table public.inventory_lots (
  id uuid primary key default gen_random_uuid(), pharmacy_id uuid not null references public.pharmacies(id),
  medicine_name text not null check(length(trim(medicine_name)) between 1 and 200),
  batch_number text not null check(length(trim(batch_number)) between 1 and 100),
  expires_on date not null, unit_price_paise integer not null check(unit_price_paise between 1 and 10000000),
  on_hand integer not null check(on_hand between 0 and 1000000),
  reserved integer not null default 0 check(reserved>=0 and reserved<=on_hand),
  updated_at timestamptz not null default now(), unique(pharmacy_id,medicine_name,batch_number)
);
create table public.order_lots (
  order_id uuid not null references public.orders(id), lot_id uuid not null references public.inventory_lots(id),
  quantity integer not null check(quantity between 1 and 100), primary key(order_id,lot_id)
);
alter table public.inventory_lots enable row level security;
alter table public.order_lots enable row level security;
revoke all on public.inventory_lots,public.order_lots from public,anon,authenticated;
grant select on public.inventory_lots to authenticated;
create policy inventory_staff on public.inventory_lots for select to authenticated using
  (public.is_pharmacy_member(pharmacy_id) or public.app_role()='admin');
create index inventory_pharmacy on public.inventory_lots(pharmacy_id,expires_on,id);

create function public.save_inventory(p_pharmacy_id uuid,p_name text,p_batch text,p_expiry date,p_price integer,p_stock integer,p_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  if auth.uid() is null or not public.is_pharmacy_member(p_pharmacy_id) then raise exception 'Pharmacy access required' using errcode='42501'; end if;
  if p_expiry is null or p_expiry<=current_date then raise exception 'Expiry must be in the future'; end if;
  if p_id is null then
    insert into public.inventory_lots(pharmacy_id,medicine_name,batch_number,expires_on,unit_price_paise,on_hand)
      values(p_pharmacy_id,trim(p_name),trim(p_batch),p_expiry,p_price,p_stock) returning id into result;
  else
    -- Identity of a lot is immutable. Existing quote snapshots retain their prices.
    update public.inventory_lots set on_hand=p_stock,unit_price_paise=p_price,updated_at=now()
      where id=p_id and pharmacy_id=p_pharmacy_id and medicine_name=trim(p_name) and batch_number=trim(p_batch)
      and expires_on=p_expiry returning id into result;
    if result is null then raise exception 'Lot not found or identity changed'; end if;
  end if;
  return result;
end $$;
create function public.quote_order(p_id uuid,p_lines jsonb,p_delivery_fee integer,p_review_note text) returns void
language plpgsql security definer set search_path='' as $$
declare o public.orders; l public.inventory_lots; item jsonb; q integer; total bigint:=0; snapshot jsonb:='[]';
begin
  select * into o from public.orders where id=p_id for update;
  if not found or not public.is_pharmacy_member(o.pharmacy_id) then raise exception 'Pharmacy access required' using errcode='42501'; end if;
  if o.status<>'submitted' then raise exception 'Order already reviewed'; end if;
  if not exists(select 1 from public.pharmacies where id=o.pharmacy_id and active and verified_at is not null
    and length(pickup_address)>=10 and contact_phone~'^\+[1-9][0-9]{7,14}$' and length(license_reference)>0) then raise exception 'Pharmacy setup incomplete'; end if;
  if p_lines is null or jsonb_typeof(p_lines)<>'array' then raise exception 'Quote lines required'; end if;
  if jsonb_array_length(p_lines) not between 1 and 50 or p_delivery_fee is null or p_delivery_fee not between 0 and 1000000
    or p_review_note is null or length(trim(p_review_note)) not between 3 and 500 then raise exception 'Invalid quote or review'; end if;
  -- Lock lots in deterministic order so overlapping multi-item quotes cannot deadlock.
  for item in select value from jsonb_array_elements(p_lines) order by value->>'lot_id' loop
    if jsonb_typeof(item->'quantity') is distinct from 'number' or (item->>'quantity') !~ '^[0-9]+$'
      or (item->>'quantity')::numeric not between 1 and 100 then raise exception 'Invalid quantity'; end if;
    q:=(item->>'quantity')::integer;
    select * into l from public.inventory_lots where id=(item->>'lot_id')::uuid and pharmacy_id=o.pharmacy_id for update;
    if not found or l.expires_on<=current_date or l.on_hand-l.reserved<q then raise exception 'Stock unavailable or expired'; end if;
    insert into public.order_lots(order_id,lot_id,quantity) values(o.id,l.id,q);
    update public.inventory_lots set reserved=reserved+q,updated_at=now() where id=l.id;
    total:=total+l.unit_price_paise::bigint*q;
    snapshot:=snapshot||jsonb_build_array(jsonb_build_object('name',l.medicine_name,'quantity',q,'unit_price_paise',l.unit_price_paise,
      'batch_number',l.batch_number,'expires_on',l.expires_on));
  end loop;
  total:=total+p_delivery_fee;
  if total not between 1 and 10000000 then raise exception 'Invalid quote total'; end if;
  update public.orders set quote_items=snapshot,delivery_fee_paise=p_delivery_fee,reviewed_by=auth.uid(),reviewed_at=now(),review_note=trim(p_review_note) where id=o.id;
  perform public.transition_order(o.id,'quote',total::integer);
end $$;
create function public.fulfilment_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare row record;
begin
  if new.status=old.status then return new; end if;
  if new.status='quoted' and (jsonb_array_length(new.quote_items)=0 or new.reviewed_by is null) then
    raise exception 'Use an itemized pharmacy quote'; end if;
  if new.status in ('confirmed','preparing','ready','picked_up') then
    if jsonb_array_length(new.quote_items)=0 then raise exception 'Legacy order needs operator review'; end if;
    if exists(select 1 from public.order_lots ol join public.inventory_lots l on l.id=ol.lot_id where ol.order_id=new.id and l.expires_on<=current_date) then
      raise exception 'Reserved stock has expired; cancel and review a new request'; end if;
  end if;
  if new.status in ('cancelled','rejected','delivered') then
    for row in select * from public.order_lots where order_id=new.id order by lot_id loop
      update public.inventory_lots set reserved=reserved-row.quantity,
        on_hand=on_hand-case when new.status='delivered' then row.quantity else 0 end,updated_at=now() where id=row.lot_id;
    end loop;
    delete from public.order_lots where order_id=new.id;
  end if;
  return new;
end $$;
create trigger fulfilment_guard before update on public.orders for each row execute function public.fulfilment_guard();

-- Keep the existing validation/idempotency implementation internal, add contact validation.
alter function public.create_order(uuid,uuid,text,text,jsonb,text,text) rename to create_order_internal;
revoke all on function public.create_order_internal(uuid,uuid,text,text,jsonb,text,text) from public,anon,authenticated;
create function public.create_order(p_request_id uuid,p_pharmacy_id uuid,p_address text,p_postal_code text,p_items jsonb,
 p_prescription_path text default null,p_notes text default '',p_recipient_phone text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; existing_phone text;
begin
  if p_recipient_phone is null or p_recipient_phone !~ '^\+[1-9][0-9]{7,14}$' then raise exception 'Phone must include country code'; end if;
  if not exists(select 1 from public.pharmacies where id=p_pharmacy_id and verified_at is not null
    and length(pickup_address)>=10 and contact_phone~'^\+[1-9][0-9]{7,14}$' and length(license_reference)>0) then raise exception 'Pharmacy setup incomplete'; end if;
  result:=public.create_order_internal(p_request_id,p_pharmacy_id,p_address,p_postal_code,p_items,p_prescription_path,p_notes);
  select recipient_phone into existing_phone from public.orders where id=(result->>'id')::uuid;
  if existing_phone<>'' and existing_phone<>p_recipient_phone then raise exception 'Request identifier already used for different contact'; end if;
  update public.orders set recipient_phone=p_recipient_phone where id=(result->>'id')::uuid;
  return result||jsonb_build_object('recipient_phone',p_recipient_phone);
end $$;

create or replace function public.list_orders(p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare role_name text:=public.app_role(); result jsonb;
begin
  if auth.uid() is null or role_name is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid page'; end if;
  select coalesce(jsonb_agg(row_data order by created_at desc,id),'[]'::jsonb) into result from (
    select o.id,o.created_at,case when role_name='delivery_partner' then
      jsonb_build_object('id',o.id,'order_number',o.order_number,'status',o.status,'pharmacy_id',o.pharmacy_id,
        'pharmacy_name',p.name,'pickup_address',p.pickup_address,'pharmacy_phone',p.contact_phone,'postal_code',o.postal_code,'rider_id',o.rider_id,
        'delivery_address',case when o.rider_id=auth.uid() and o.status in ('assigned','picked_up','delivery_failed') then o.delivery_address else '' end,
        'recipient_phone',case when o.rider_id=auth.uid() and o.status in ('assigned','picked_up','delivery_failed') then o.recipient_phone else '' end,
        'quote_paise',case when o.rider_id=auth.uid() then o.quote_paise else null end,'payment_status',o.payment_status,'payment_method',o.payment_method)
      else to_jsonb(o)||jsonb_build_object('pharmacy_name',p.name,'pickup_address',p.pickup_address,'pharmacy_phone',p.contact_phone) end as row_data
    from public.orders o join public.pharmacies p on p.id=o.pharmacy_id
    where o.customer_id=auth.uid() or public.is_pharmacy_member(o.pharmacy_id) or role_name='admin'
      or (role_name='delivery_partner' and (o.rider_id=auth.uid() or (o.status='ready' and o.postal_code=any(
        (select service_postal_codes from public.profiles where id=auth.uid())::text[]))))
    order by o.created_at desc,o.id limit 25 offset p_offset
  ) page;
  return result;
end $$;
revoke all on function public.save_inventory(uuid,text,text,date,integer,integer,uuid),public.quote_order(uuid,jsonb,integer,text),
 public.fulfilment_guard(),public.create_order(uuid,uuid,text,text,jsonb,text,text,text) from public,anon,authenticated;
grant execute on function public.save_inventory(uuid,text,text,date,integer,integer,uuid),public.quote_order(uuid,jsonb,integer,text),
 public.create_order(uuid,uuid,text,text,jsonb,text,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
