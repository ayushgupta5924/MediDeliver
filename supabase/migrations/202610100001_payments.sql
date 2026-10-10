-- Additive upgrade from the COD foundation. Payment writes are server-only.
begin;
alter table public.orders drop constraint orders_payment_status_check;
alter table public.orders add constraint orders_payment_status_check check
  (payment_status in ('unpaid','cash_due','cash_collected','pending','paid','refund_pending','refunded'));
alter table public.orders add column payment_method text check (payment_method in ('cod','razorpay'));
update public.orders set payment_method='cod' where payment_status in ('cash_due','cash_collected');
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id),
  amount_paise integer not null check (amount_paise between 1 and 10000000),
  provider_order_id text unique, provider_payment_id text unique, provider_refund_id text unique,
  status text not null default 'creating' check (status in ('creating','ready','captured','refund_pending','refunded')),
  checkout_token_hash text, checkout_expires_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  last_checked_at timestamptz, needs_attention boolean not null default false
);
alter table public.payments enable row level security;
revoke all on public.payments from public,anon,authenticated;
create index payments_work on public.payments(last_checked_at nulls first,created_at)
  where status in ('creating','ready','refund_pending');

create function public.payment_begin(p_customer_id uuid,p_order_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.orders; p public.payments;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found or o.customer_id is distinct from p_customer_id or o.status<>'quoted'
    or o.quote_paise is null then raise exception 'Order not available for checkout'; end if;
  select * into p from public.payments where order_id=o.id;
  if found then
    if p.status not in ('creating','ready') then raise exception 'Payment already processed'; end if;
    return to_jsonb(p)||jsonb_build_object('create_provider',false);
  end if;
  insert into public.payments(order_id,amount_paise) values(o.id,o.quote_paise) returning * into p;
  update public.orders set payment_method='razorpay',payment_status='pending',updated_at=now() where id=o.id;
  return to_jsonb(p)||jsonb_build_object('create_provider',true);
end $$;
create function public.payment_attach(p_id uuid,p_provider_order_id text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if p_provider_order_id is null or p_provider_order_id !~ '^order_[A-Za-z0-9]+$' then raise exception 'Invalid provider order'; end if;
  update public.payments set provider_order_id=p_provider_order_id,status='ready',updated_at=now()
    where id=p_id and status='creating' and provider_order_id is null;
  if not found and not exists(select 1 from public.payments where id=p_id and provider_order_id=p_provider_order_id) then
    raise exception 'Provider order already attached'; end if;
end $$;
create function public.payment_token(p_customer_id uuid,p_id uuid,p_token_hash text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if p_token_hash is null or p_token_hash !~ '^[a-f0-9]{64}$' then raise exception 'Invalid token'; end if;
  update public.payments p set checkout_token_hash=p_token_hash,checkout_expires_at=now()+interval '15 minutes'
    from public.orders o where p.id=p_id and o.id=p.order_id and o.customer_id=p_customer_id
      and o.status='quoted' and p.status='ready';
  if not found then raise exception 'Checkout unavailable'; end if;
end $$;
create function public.payment_checkout(p_token_hash text) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('provider_order_id',p.provider_order_id,'amount_paise',p.amount_paise)
    from public.payments p join public.orders o on o.id=p.order_id where checkout_token_hash=p_token_hash
    and checkout_expires_at>now() and p.status in ('ready','captured')
$$;
create function public.payment_by_provider(p_provider_order_id text) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('provider_order_id',provider_order_id,'amount_paise',amount_paise)
    from public.payments where provider_order_id=p_provider_order_id
$$;
create function public.payment_captured(p_provider_order_id text,p_payment_id text,p_amount integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.payments; o public.orders; target uuid;
begin
  if p_payment_id is null or p_payment_id !~ '^pay_[A-Za-z0-9]+$' then raise exception 'Invalid payment ID'; end if;
  select order_id into target from public.payments where provider_order_id=p_provider_order_id;
  if target is null then raise exception 'Unknown provider order'; end if;
  -- Same lock order as cancellation and payment_begin: order first, then payment.
  select * into o from public.orders where id=target for update;
  select * into p from public.payments where order_id=target for update;
  if p.amount_paise is distinct from p_amount then raise exception 'Payment amount mismatch'; end if;
  if p.provider_payment_id is not null then
    if p.provider_payment_id<>p_payment_id then raise exception 'Conflicting captured payment'; end if;
    return jsonb_build_object('status',p.status);
  end if;
  if o.status='quoted' and o.payment_method='razorpay' then
    update public.payments set status='captured',provider_payment_id=p_payment_id,updated_at=now() where id=p.id;
    update public.orders set status='confirmed',payment_status='paid',updated_at=now() where id=o.id;
    return jsonb_build_object('status','captured');
  end if;
  -- Cancellation/rejection can race provider capture. Never revive fulfilment.
  update public.payments set status='refund_pending',provider_payment_id=p_payment_id,updated_at=now() where id=p.id;
  update public.orders set payment_status='refund_pending',updated_at=now() where id=o.id;
  return jsonb_build_object('status','refund_pending');
end $$;
create function public.payment_refunded(p_payment_id text,p_refund_id text,p_amount integer) returns void
language plpgsql security definer set search_path='' as $$
declare p public.payments; target uuid;
begin
  select order_id into target from public.payments where provider_payment_id=p_payment_id;
  if target is null then raise exception 'Unknown payment'; end if;
  perform 1 from public.orders where id=target for update;
  select * into p from public.payments where order_id=target for update;
  if p.amount_paise is distinct from p_amount or p_refund_id is null or p_refund_id !~ '^rfnd_[A-Za-z0-9]+$' then
    raise exception 'Refund mismatch'; end if;
  if p.status='refunded' and p.provider_refund_id=p_refund_id then return; end if;
  if p.status<>'refund_pending' then raise exception 'Unexpected refund; operator review required'; end if;
  update public.payments set status='refunded',provider_refund_id=p_refund_id,updated_at=now() where id=p.id;
  update public.orders set payment_status='refunded',updated_at=now() where id=target;
end $$;
create function public.payment_work() returns jsonb
language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) from
    (select id,provider_order_id,provider_payment_id,amount_paise,status from public.payments
      where status in ('creating','ready','refund_pending')
      and created_at<now()-interval '1 minute'
      order by last_checked_at nulls first,created_at limit 10) p
$$;
create function public.payment_checked(p_id uuid,p_failed boolean) returns void
language sql security definer set search_path='' as $$
  update public.payments set last_checked_at=now(),needs_attention=p_failed where id=p_id
$$;

-- Amend the existing transition function without changing its public signature.
create or replace function public.transition_order(p_id uuid,p_action text,p_quote_paise integer default null,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare o public.orders; next_status text; role_name text:=public.app_role();
begin
  if auth.uid() is null or role_name is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into o from public.orders where id=p_id for update;
  if not found then raise exception 'Order unavailable'; end if;
  if role_name='customer' and o.customer_id=auth.uid() then
    if p_action='confirm' and o.status='quoted' and o.payment_method is distinct from 'razorpay' then next_status:='confirmed';
    elsif p_action='cancel' and o.status in ('submitted','quoted','confirmed') then next_status:='cancelled'; end if;
  elsif public.is_pharmacy_member(o.pharmacy_id) then
    if p_action='quote' and o.status='submitted' and p_quote_paise between 1 and 10000000 then next_status:='quoted';
    elsif p_action='reject' and o.status in ('submitted','quoted','confirmed') then next_status:='rejected';
    elsif p_action='prepare' and o.status='confirmed' and o.payment_status in ('cash_due','paid') then next_status:='preparing';
    elsif p_action='ready' and o.status='preparing' then next_status:='ready'; end if;
  elsif role_name='delivery_partner' then
    if p_action='accept' and o.status='ready' and o.rider_id is null and exists (
      select 1 from public.profiles where id=auth.uid() and o.postal_code=any(service_postal_codes)) then next_status:='assigned';
    elsif o.rider_id=auth.uid() then
      if p_action='pickup' and o.status='assigned' then next_status:='picked_up';
      elsif p_action='deliver' and o.status='picked_up' and o.payment_status in ('cash_due','paid') then next_status:='delivered';
      elsif p_action='fail' and o.status='picked_up' then next_status:='delivery_failed'; end if;
    end if;
  elsif role_name='admin' then
    if p_action='redispatch' and o.status='delivery_failed' then next_status:='ready';
    elsif p_action='return_cancel' and o.status='delivery_failed' then next_status:='cancelled'; end if;
  end if;
  if next_status is null then raise exception 'Transition not permitted or order already changed' using errcode='42501'; end if;
  if (next_status in ('rejected','delivery_failed') or p_action='return_cancel') and
    (p_reason is null or length(trim(p_reason)) not between 1 and 500) then raise exception 'Reason required'; end if;
  update public.orders set status=next_status,updated_at=now(),
    quote_paise=case when next_status='quoted' then p_quote_paise else quote_paise end,
    rider_id=case when p_action='accept' then auth.uid() when p_action='redispatch' then null else rider_id end,
    payment_method=case when next_status='confirmed' then 'cod' else payment_method end,
    payment_status=case when next_status='confirmed' then 'cash_due'
      when next_status='delivered' and payment_status='cash_due' then 'cash_collected'
      when next_status in ('cancelled','rejected') and payment_status='paid' then 'refund_pending'
      when next_status in ('cancelled','rejected') and payment_status='cash_due' then 'unpaid'
      else payment_status end,
    rejection_reason=case when next_status in ('rejected','delivery_failed') or p_action='return_cancel' then trim(p_reason)
      when p_action='redispatch' then null else rejection_reason end where id=p_id;
  if next_status in ('cancelled','rejected') then
    update public.payments set status='refund_pending',updated_at=now() where order_id=p_id and status='captured';
  end if;
end $$;

-- SECURITY DEFINER functions default to PUBLIC execute; revoke each explicitly.
revoke all on function public.payment_begin(uuid,uuid),public.payment_attach(uuid,text),public.payment_token(uuid,uuid,text),
 public.payment_checkout(text),public.payment_by_provider(text),public.payment_captured(text,text,integer),
 public.payment_refunded(text,text,integer),public.payment_work(),public.payment_checked(uuid,boolean) from public,anon,authenticated;
grant execute on function public.payment_begin(uuid,uuid),public.payment_attach(uuid,text),public.payment_token(uuid,uuid,text),
 public.payment_checkout(text),public.payment_by_provider(text),public.payment_captured(text,text,integer),
 public.payment_refunded(text,text,integer),public.payment_work(),public.payment_checked(uuid,boolean) to service_role;
notify pgrst,'reload schema';
commit;
