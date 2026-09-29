-- Fresh-project baseline. Do not apply over an existing schema without reviewing a schema diff.
begin;
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '', full_name text,
  role text not null default 'customer' check (role in ('customer','pharmacy_owner','delivery_partner','admin')),
  service_postal_codes text[] not null default '{}'
);
create table public.pharmacies (
  id uuid primary key default gen_random_uuid(), name text not null,
  postal_codes text[] not null, active boolean not null default false
);
create table public.pharmacy_members (
  pharmacy_id uuid not null references public.pharmacies(id),
  user_id uuid not null references public.profiles(id), primary key (pharmacy_id,user_id)
);
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('MD-' || upper(replace(gen_random_uuid()::text,'-',''))),
  request_id uuid not null,
  customer_id uuid not null references public.profiles(id),
  pharmacy_id uuid not null references public.pharmacies(id),
  rider_id uuid references public.profiles(id),
  status text not null default 'submitted' check (status in ('submitted','quoted','confirmed','preparing','ready','assigned','picked_up','delivered','rejected','cancelled','delivery_failed')),
  delivery_address text not null check (char_length(delivery_address) between 10 and 500),
  postal_code text not null check (postal_code ~ '^[0-9]{6}$'),
  items jsonb not null default '[]', prescription_path text,
  customer_notes text not null default '' check (char_length(customer_notes) <= 1000),
  quote_paise integer check (quote_paise between 1 and 10000000),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','cash_due','cash_collected')),
  rejection_reason text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (customer_id,request_id)
);
create table public.order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id), actor_id uuid references public.profiles(id),
  previous_status text, status text not null, created_at timestamptz not null default now()
);
create index orders_customer_created on public.orders(customer_id,created_at desc,id);
create index orders_pharmacy_status_created on public.orders(pharmacy_id,status,created_at desc,id);
create index orders_rider_created on public.orders(rider_id,created_at desc,id) where rider_id is not null;
create index orders_dispatch on public.orders(postal_code,created_at desc,id) where status = 'ready';
create index pharmacy_members_user on public.pharmacy_members(user_id,pharmacy_id);
create index order_events_order on public.order_events(order_id,created_at);

create function public.provision_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Never trust raw_user_meta_data for privilege assignment.
  insert into public.profiles(id,email,role) values (new.id,coalesce(new.email,''),'customer');
  return new;
end $$;
create trigger medideliver_profile after insert on auth.users for each row execute function public.provision_profile();
insert into public.profiles(id,email) select id,coalesce(email,'') from auth.users;

create function public.app_role() returns text language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = auth.uid()
$$;
create function public.is_pharmacy_member(p_pharmacy_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select public.app_role() = 'pharmacy_owner' and exists (
    select 1 from public.pharmacy_members where pharmacy_id = p_pharmacy_id and user_id = auth.uid())
$$;
create function public.can_read_order(p_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.orders o where o.id = p_id and (
    o.customer_id = auth.uid() or public.is_pharmacy_member(o.pharmacy_id) or public.app_role() = 'admin' or
    (public.app_role() = 'delivery_partner' and o.rider_id = auth.uid())))
$$;

alter table public.profiles enable row level security;
alter table public.pharmacies enable row level security;
alter table public.pharmacy_members enable row level security;
alter table public.orders enable row level security;
alter table public.order_events enable row level security;
revoke all on public.profiles, public.pharmacies, public.pharmacy_members, public.orders, public.order_events from anon, authenticated;
grant select on public.profiles, public.pharmacies, public.pharmacy_members, public.orders, public.order_events to authenticated;
-- Riders consume a redacted projection through list_orders, not medical rows.
create policy profiles_self on public.profiles for select to authenticated using (id = auth.uid());
create policy pharmacy_directory on public.pharmacies for select to authenticated using (active or public.app_role() = 'admin');
create policy memberships_self on public.pharmacy_members for select to authenticated using (user_id = auth.uid());
create policy orders_read on public.orders for select to authenticated using (
  customer_id = auth.uid() or public.is_pharmacy_member(pharmacy_id) or public.app_role() = 'admin');
create policy events_read on public.order_events for select to authenticated using (public.can_read_order(order_id));

create function public.record_order_event() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if TG_OP = 'INSERT' then
    insert into public.order_events(order_id,actor_id,status) values(new.id,auth.uid(),new.status);
  elsif new.status is distinct from old.status then
    insert into public.order_events(order_id,actor_id,previous_status,status) values(new.id,auth.uid(),old.status,new.status);
  end if;
  return new;
end $$;
create trigger order_audit after insert or update on public.orders for each row execute function public.record_order_event();

create function public.create_order(p_request_id uuid, p_pharmacy_id uuid, p_address text, p_postal_code text,
  p_items jsonb, p_prescription_path text default null, p_notes text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.orders; item jsonb;
begin
  if auth.uid() is null or public.app_role() is distinct from 'customer' then raise exception 'Customer access required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'Request identifier required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_request_id::text,0));
  select * into o from public.orders where customer_id = auth.uid() and request_id = p_request_id;
  if found then
    if o.pharmacy_id is distinct from p_pharmacy_id or o.delivery_address is distinct from trim(p_address)
      or o.postal_code is distinct from p_postal_code or o.items is distinct from p_items
      or o.prescription_path is distinct from p_prescription_path or o.customer_notes is distinct from coalesce(p_notes,'') then
      raise exception 'Request identifier already used for a different request';
    end if;
    return to_jsonb(o);
  end if;
  if not exists(select 1 from public.pharmacies where id = p_pharmacy_id and active and p_postal_code = any(postal_codes)) then
    raise exception 'Pharmacy does not serve this postal code';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then raise exception 'Items must be an array'; end if;
  if jsonb_array_length(p_items) > 50 or (jsonb_array_length(p_items) = 0 and p_prescription_path is null) then raise exception 'Provide a prescription or 1–50 items'; end if;
  for item in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(item) <> 'object' or jsonb_typeof(item->'name') is distinct from 'string'
      or length(trim(item->>'name')) not between 1 and 200 or jsonb_typeof(item->'quantity') is distinct from 'number'
      or (item->>'quantity') !~ '^[0-9]+$' then raise exception 'Invalid medicine item'; end if;
    if (item->>'quantity')::numeric not between 1 and 100 then raise exception 'Quantity must be 1–100'; end if;
    if item - 'name' - 'quantity' <> '{}'::jsonb then raise exception 'Unexpected medicine fields'; end if;
  end loop;
  if p_prescription_path is not null then
    if p_prescription_path not in (auth.uid()::text || '/' || p_request_id::text || '.jpg',auth.uid()::text || '/' || p_request_id::text || '.png')
      or not exists(select 1 from storage.objects where bucket_id='prescriptions' and name=p_prescription_path) then
      raise exception 'Prescription is missing or belongs to another request' using errcode='42501';
    end if;
  end if;
  insert into public.orders(request_id,customer_id,pharmacy_id,delivery_address,postal_code,items,prescription_path,customer_notes)
    values(p_request_id,auth.uid(),p_pharmacy_id,trim(p_address),p_postal_code,p_items,p_prescription_path,coalesce(p_notes,'')) returning * into o;
  return to_jsonb(o);
end $$;

create function public.list_orders(p_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare role_name text := public.app_role(); result jsonb;
begin
  if auth.uid() is null or role_name is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_offset is null or p_offset < 0 or p_offset > 100000 then raise exception 'Invalid page'; end if;
  select coalesce(jsonb_agg(row_data order by created_at desc, id),'[]'::jsonb) into result from (
    select o.id,o.created_at, case when role_name='delivery_partner' then
      jsonb_build_object('id',o.id,'order_number',o.order_number,'status',o.status,'pharmacy_id',o.pharmacy_id,
        'pharmacy_name',p.name,'postal_code',o.postal_code,'rider_id',o.rider_id,
        'delivery_address',case when o.rider_id=auth.uid() then o.delivery_address else '' end,
        'quote_paise',case when o.rider_id=auth.uid() then o.quote_paise else null end,'payment_status',o.payment_status)
      else to_jsonb(o) || jsonb_build_object('pharmacy_name',p.name) end as row_data
    from public.orders o join public.pharmacies p on p.id=o.pharmacy_id
    where o.customer_id=auth.uid() or public.is_pharmacy_member(o.pharmacy_id) or role_name='admin'
      or (role_name='delivery_partner' and (o.rider_id=auth.uid() or (o.status='ready' and o.postal_code=any(
        (select service_postal_codes from public.profiles where id=auth.uid())::text[]))))
    order by o.created_at desc,o.id limit 25 offset p_offset
  ) page;
  return result;
end $$;

create function public.transition_order(p_id uuid,p_action text,p_quote_paise integer default null,p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare o public.orders; next_status text; role_name text := public.app_role();
begin
  if auth.uid() is null or role_name is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into o from public.orders where id=p_id for update;
  if not found then raise exception 'Order unavailable'; end if;
  if role_name='customer' and o.customer_id=auth.uid() then
    if p_action='confirm' and o.status='quoted' then next_status:='confirmed';
    elsif p_action='cancel' and o.status in ('submitted','quoted','confirmed') then next_status:='cancelled'; end if;
  elsif public.is_pharmacy_member(o.pharmacy_id) then
    if p_action='quote' and o.status='submitted' and p_quote_paise between 1 and 10000000 then next_status:='quoted';
    elsif p_action='reject' and o.status in ('submitted','quoted','confirmed') then next_status:='rejected';
    elsif p_action='prepare' and o.status='confirmed' then next_status:='preparing';
    elsif p_action='ready' and o.status='preparing' then next_status:='ready'; end if;
  elsif role_name='delivery_partner' then
    if p_action='accept' and o.status='ready' and o.rider_id is null and exists (
      select 1 from public.profiles where id=auth.uid() and o.postal_code=any(service_postal_codes)) then next_status:='assigned';
    elsif o.rider_id=auth.uid() then
      if p_action='pickup' and o.status='assigned' then next_status:='picked_up';
      elsif p_action='deliver' and o.status='picked_up' and o.payment_status='cash_due' then next_status:='delivered';
      elsif p_action='fail' and o.status='picked_up' then next_status:='delivery_failed'; end if;
    end if;
  elsif role_name='admin' and p_action='redispatch' and o.status='delivery_failed' then next_status:='ready';
  end if;
  if next_status is null then raise exception 'Transition not permitted or order already changed' using errcode='42501'; end if;
  if next_status in ('rejected','delivery_failed') and (p_reason is null or length(trim(p_reason)) not between 1 and 500) then raise exception 'Reason required'; end if;
  update public.orders set status=next_status,updated_at=now(),
    quote_paise=case when next_status='quoted' then p_quote_paise else quote_paise end,
    rider_id=case when p_action='accept' then auth.uid() when p_action='redispatch' then null else rider_id end,
    payment_status=case when next_status='confirmed' then 'cash_due' when next_status='delivered' then 'cash_collected' else payment_status end,
    rejection_reason=case when next_status in ('rejected','delivery_failed') then trim(p_reason) when p_action='redispatch' then null else rejection_reason end
    where id=p_id;
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
  values ('prescriptions','prescriptions',false,5242880,array['image/jpeg','image/png']);
create policy prescription_upload on storage.objects for insert to authenticated with check (
  bucket_id='prescriptions' and public.app_role()='customer' and (storage.foldername(name))[1]=auth.uid()::text
  and name ~ ('^' || auth.uid()::text || '/[0-9a-f-]{36}\.(jpg|png)$'));
create policy prescription_read on storage.objects for select to authenticated using (
  bucket_id='prescriptions' and (
    (storage.foldername(name))[1]=auth.uid()::text or exists (
      select 1 from public.orders o where o.prescription_path=name and (public.is_pharmacy_member(o.pharmacy_id) or public.app_role()='admin'))));
-- No client update/delete policy: submitted images cannot be replaced by a retry.
revoke execute on function public.provision_profile(),public.record_order_event() from public,anon,authenticated;
revoke execute on function public.app_role(),public.is_pharmacy_member(uuid),public.can_read_order(uuid),
  public.create_order(uuid,uuid,text,text,jsonb,text,text),public.list_orders(integer),public.transition_order(uuid,text,integer,text) from public,anon;
grant execute on function public.app_role(),public.is_pharmacy_member(uuid),public.can_read_order(uuid),
  public.create_order(uuid,uuid,text,text,jsonb,text,text),public.list_orders(integer),public.transition_order(uuid,text,integer,text) to authenticated;
notify pgrst, 'reload schema';
commit;
