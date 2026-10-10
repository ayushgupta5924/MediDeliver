begin;
create table public.payment_events (
  id bigint generated always as identity primary key, payment_id uuid not null references public.payments(id),
  previous_status text, status text not null, amount_paise integer not null,
  created_at timestamptz not null default now()
);
alter table public.payment_events enable row level security;
revoke all on public.payment_events from public,anon,authenticated;
grant select on public.payment_events to authenticated;
create policy payment_events_operator on public.payment_events for select to authenticated using(public.app_role()='admin');
create index payment_events_payment on public.payment_events(payment_id,created_at);
create function public.record_payment_event() returns trigger language plpgsql security definer set search_path='' as $$
begin
  if TG_OP='INSERT' then
    insert into public.payment_events(payment_id,status,amount_paise) values(new.id,new.status,new.amount_paise);
  elsif old.status is distinct from new.status then
    insert into public.payment_events(payment_id,previous_status,status,amount_paise) values(new.id,old.status,new.status,new.amount_paise);
  end if;
  return new;
end $$;
create trigger payment_audit after insert or update on public.payments for each row execute function public.record_payment_event();
revoke all on function public.record_payment_event() from public,anon,authenticated;

create or replace function public.payment_captured(p_provider_order_id text,p_payment_id text,p_amount integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.payments; o public.orders; target uuid; expired boolean;
begin
  if p_payment_id is null or p_payment_id !~ '^pay_[A-Za-z0-9]+$' then raise exception 'Invalid payment ID'; end if;
  select order_id into target from public.payments where provider_order_id=p_provider_order_id;
  if target is null then raise exception 'Unknown provider order'; end if;
  select * into o from public.orders where id=target for update;
  select * into p from public.payments where order_id=target for update;
  if p.amount_paise is distinct from p_amount then raise exception 'Payment amount mismatch'; end if;
  if p.provider_payment_id is not null then
    if p.provider_payment_id<>p_payment_id then raise exception 'Conflicting captured payment'; end if;
    return jsonb_build_object('status',p.status);
  end if;
  expired:=jsonb_array_length(o.quote_items)=0 or exists(select 1 from public.order_lots ol
    join public.inventory_lots l on l.id=ol.lot_id where ol.order_id=o.id and l.expires_on<=current_date);
  if o.status='quoted' and o.payment_method='razorpay' and not expired then
    update public.payments set status='captured',provider_payment_id=p_payment_id,updated_at=now() where id=p.id;
    update public.orders set status='confirmed',payment_status='paid',updated_at=now() where id=o.id;
    return jsonb_build_object('status','captured');
  end if;
  update public.payments set status='refund_pending',provider_payment_id=p_payment_id,updated_at=now() where id=p.id;
  update public.orders set payment_status='refund_pending',updated_at=now(),
    status=case when status='quoted' and expired then 'cancelled' else status end,
    rejection_reason=case when status='quoted' and expired then 'Stock expired before payment confirmation. Full refund queued.' else rejection_reason end
    where id=o.id;
  return jsonb_build_object('status','refund_pending');
end $$;
notify pgrst,'reload schema';
commit;
