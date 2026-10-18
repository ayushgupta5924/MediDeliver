-- Direct UPI with operator bank verification, separate from Razorpay.
begin;
alter table public.orders drop constraint orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check check(payment_method in ('cod','razorpay','upi'));
create table public.upi_payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id),
  mode text not null check(mode in ('mock','manual')),
  vpa text, payee_name text not null,
  amount_paise integer not null check(amount_paise between 1 and 10000000),
  status text not null default 'pending' check(status in ('pending','review','verified','refund_pending','refunded')),
  claimed_utr text check(claimed_utr ~ '^\d{12}$'),
  verified_utr text check(verified_utr ~ '^\d{12}$'),
  refund_utr text check(refund_utr ~ '^\d{12}$'),
  verified_by uuid references public.profiles(id), verified_at timestamptz,
  refunded_by uuid references public.profiles(id), refunded_at timestamptz,
  verification_note text, refund_note text,
  token_hash text not null unique, token_expires_at timestamptz not null,
  expires_at timestamptz not null default now()+interval '5 minutes',
  created_at timestamptz not null default now(),
  unique(mode,verified_utr), unique(mode,refund_utr),
  check((mode='mock' and vpa is null) or (mode='manual' and vpa is not null))
);
alter table public.upi_payments enable row level security;
revoke all on public.upi_payments from public,anon,authenticated;
grant select on public.upi_payments to authenticated;
create policy upi_operator_read on public.upi_payments for select to authenticated using(public.app_role()='admin');
create table public.upi_events (
  id bigint generated always as identity primary key,
  payment_id uuid not null references public.upi_payments(id),
  status text not null, actor uuid, created_at timestamptz not null default now()
);
alter table public.upi_events enable row level security;
revoke all on public.upi_events from public,anon,authenticated;
grant select on public.upi_events to authenticated;
create policy upi_audit_read on public.upi_events for select to authenticated using(public.app_role()='admin');
create function public.upi_audit() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if TG_OP='INSERT' or old.status is distinct from new.status then
    insert into public.upi_events(payment_id,status,actor) values(new.id,new.status,auth.uid());
  end if;
  return new;
end $$;
create trigger upi_audit after insert or update on public.upi_payments for each row execute function public.upi_audit();

create function public.upi_begin(p_customer uuid,p_order uuid,p_mode text,p_vpa text,p_name text,p_hash text) returns void
language plpgsql security definer set search_path='' as $$
declare o public.orders; p public.upi_payments;
begin
  if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' or p_mode is null or p_mode not in ('mock','manual') then raise exception 'Invalid checkout'; end if;
  if p_mode='manual' and (p_vpa is null or p_vpa !~ '^[a-zA-Z0-9._-]{2,128}@[a-zA-Z0-9.-]{2,64}$') then raise exception 'Invalid payee'; end if;
  select * into o from public.orders where id=p_order for update;
  if not found or o.customer_id is distinct from p_customer or o.status<>'quoted' or o.quote_paise is null
    or o.payment_method is not null and o.payment_method<>'upi' then raise exception 'Checkout unavailable'; end if;
  select * into p from public.upi_payments where order_id=o.id for update;
  if found then
    if p.mode<>p_mode or p.status not in ('pending','review') then raise exception 'Checkout unavailable'; end if;
    -- Refresh access only. Never extend the payment window or change its payee/amount.
    update public.upi_payments set token_hash=p_hash,token_expires_at=now()+interval '15 minutes' where id=p.id;
  else
    insert into public.upi_payments(order_id,mode,vpa,payee_name,amount_paise,token_hash,token_expires_at)
      values(o.id,p_mode,case when p_mode='mock' then null else p_vpa end,p_name,o.quote_paise,p_hash,now()+interval '15 minutes');
    update public.orders set payment_method='upi',payment_status='pending',updated_at=now() where id=o.id;
  end if;
end $$;
create function public.upi_checkout(p_hash text) returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('id',p.id,'mode',p.mode,'vpa',p.vpa,'payee_name',p.payee_name,
    'amount_paise',p.amount_paise,'status',p.status,'expires_at',p.expires_at,'order_status',o.status)
  from public.upi_payments p join public.orders o on o.id=p.order_id
  where p.token_hash=p_hash and p.token_expires_at>now()
$$;
create function public.upi_claim(p_hash text,p_utr text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.upi_payments; target uuid;
begin
  if p_utr is null or p_utr !~ '^\d{12}$' then raise exception 'Invalid reference'; end if;
  select order_id into target from public.upi_payments where token_hash=p_hash;
  perform 1 from public.orders where id=target for update;
  select * into p from public.upi_payments where order_id=target for update;
  if not found or p.token_hash<>p_hash or p.token_expires_at<=now() then raise exception 'Checkout expired'; end if;
  if p.claimed_utr is not null then
    if p.claimed_utr<>p_utr then raise exception 'Reference already submitted; contact support'; end if;
  elsif p.status='pending' then
    -- A claim never confirms an order, even in mock mode. Late claims still need review.
    update public.upi_payments set claimed_utr=p_utr,status='review' where id=p.id;
  else raise exception 'Payment already reviewed'; end if;
  return jsonb_build_object('status','review');
end $$;

create function public.upi_review(p_order uuid,p_utr text,p_amount integer,p_note text,p_refund boolean default false) returns void
language plpgsql security definer set search_path='' as $$
declare o public.orders; p public.upi_payments; expired boolean;
begin
  if auth.uid() is null or public.app_role() is distinct from 'admin' then raise exception 'Operator required' using errcode='42501'; end if;
  if p_utr is null or p_utr !~ '^\d{12}$' or p_note is null or length(trim(p_note)) not between 20 and 500 or p_refund is null then raise exception 'Bank reference and review evidence required'; end if;
  select * into o from public.orders where id=p_order for update;
  select * into p from public.upi_payments where order_id=p_order for update;
  if not found or p.amount_paise is distinct from p_amount then raise exception 'Payment or exact amount not found'; end if;
  if p_refund then
    if p.status='refunded' and p.refund_utr=p_utr then return; end if;
    if p.status<>'refund_pending' then raise exception 'Refund not pending'; end if;
    update public.upi_payments set status='refunded',refund_utr=p_utr,refunded_by=auth.uid(),refunded_at=now(),refund_note=trim(p_note) where id=p.id;
    update public.orders set payment_status='refunded',updated_at=now() where id=o.id;
    return;
  end if;
  if p.verified_utr is not null then
    if p.verified_utr=p_utr then return; end if;
    raise exception 'Conflicting bank reference';
  end if;
  -- The operator must match payer, credit date, receiving account, UTR and exact total
  -- in the merchant bank ledger, not merely match an amount or a customer's claim.
  expired:=jsonb_array_length(o.quote_items)=0 or exists(select 1 from public.order_lots ol
    join public.inventory_lots l on l.id=ol.lot_id where ol.order_id=o.id and l.expires_on<=current_date);
  update public.upi_payments set verified_utr=p_utr,verified_by=auth.uid(),verified_at=now(),verification_note=trim(p_note),
    status=case when o.status='quoted' and not expired then 'verified' else 'refund_pending' end where id=p.id;
  if o.status='quoted' and not expired then
    update public.orders set status='confirmed',payment_status='paid',updated_at=now() where id=o.id;
  else
    update public.orders set payment_status='refund_pending',updated_at=now(),
      status=case when status='quoted' then 'cancelled' else status end where id=o.id;
  end if;
end $$;

create function public.upi_order_guard() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.payment_method='upi' and new.payment_method is distinct from 'upi' then raise exception 'UPI checkout already started; cannot switch payment method' using errcode='42501'; end if;
  if new.payment_method='upi' and new.status in ('confirmed','preparing','ready','assigned','picked_up','delivered')
    and not exists(select 1 from public.upi_payments where order_id=new.id and status='verified') then
    raise exception 'Bank verification required' using errcode='42501';
  end if;
  if new.payment_method='upi' and new.status in ('cancelled','rejected') then
    update public.upi_payments set status='refund_pending' where order_id=new.id and status='verified';
  end if;
  return new;
end $$;
create trigger upi_order_guard before update on public.orders for each row execute function public.upi_order_guard();
revoke all on function public.upi_audit(),public.upi_order_guard(),public.upi_begin(uuid,uuid,text,text,text,text),
 public.upi_checkout(text),public.upi_claim(text,text),public.upi_review(uuid,text,integer,text,boolean) from public,anon,authenticated;
grant execute on function public.upi_begin(uuid,uuid,text,text,text,text),public.upi_checkout(text),public.upi_claim(text,text) to service_role;
grant execute on function public.upi_review(uuid,text,integer,text,boolean) to authenticated;
notify pgrst,'reload schema';
commit;
