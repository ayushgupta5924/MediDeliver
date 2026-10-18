begin;
-- Customers see listing names and indicative prices, never staff-only lot details.
create function public.pharmacy_catalog(p_pharmacy_id uuid)
returns table(medicine_name text, from_price_paise integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in required' using errcode='42501';
  end if;
  return query
    select l.medicine_name, min(l.unit_price_paise)
    from public.inventory_lots l join public.pharmacies p on p.id=l.pharmacy_id
    where p.id=p_pharmacy_id and p.active and p.verified_at is not null
      and l.expires_on>current_date and l.on_hand>l.reserved
    group by l.medicine_name order by l.medicine_name limit 100;
end $$;
revoke all on function public.pharmacy_catalog(uuid) from public, anon;
grant execute on function public.pharmacy_catalog(uuid) to authenticated;
commit;
