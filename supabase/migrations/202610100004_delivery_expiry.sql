-- Validate expiry again at assignment and delivery, including an overnight transit.
begin;
create or replace function public.fulfilment_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare row record;
begin
  if new.status=old.status then return new; end if;
  if new.status='quoted' and (jsonb_array_length(new.quote_items)=0 or new.reviewed_by is null) then
    raise exception 'Use an itemized pharmacy quote'; end if;
  if new.status in ('confirmed','preparing','ready','assigned','picked_up','delivered') then
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
notify pgrst,'reload schema';
commit;
