"""Exercise real concurrent transactions against a DISPOSABLE test database."""
import concurrent.futures
import json
import os
import subprocess
import uuid

PSQL = os.environ.get('PSQL', 'psql')
DATABASE = os.environ['TEST_DATABASE_URL']
ids = [str(uuid.uuid4()) for _ in range(6)]
customer, pharmacist, rider1, rider2, pharmacy, request = ids

def sql(statement):
    result = subprocess.run([PSQL, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', DATABASE],
                            input=statement, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    return result.stdout.strip()

def as_user(user, statement):
    return sql(f"begin; set local role authenticated; set local request.jwt.claim.sub='{user}'; {statement}; commit;")

try:
    sql(f"""
      insert into auth.users(id,email) values
      ('{customer}','race-customer@example.invalid'),('{pharmacist}','race-pharmacy@example.invalid'),
      ('{rider1}','race-rider-one@example.invalid'),('{rider2}','race-rider-two@example.invalid');
      update public.profiles set role='pharmacy_owner' where id='{pharmacist}';
      update public.profiles set role='delivery_partner',service_postal_codes=array['382010'] where id in ('{rider1}','{rider2}');
      insert into public.pharmacies(id,name,postal_codes,active) values('{pharmacy}','Concurrency Test Pharmacy',array['382010'],true);
      insert into public.pharmacy_members values('{pharmacy}','{pharmacist}');
    """)
    create = f"select public.create_order('{request}','{pharmacy}','123 Fictional Race Road','382010','[{{\"name\":\"Fictional sample\",\"quantity\":1}}]')->>'id'"
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: as_user(customer, create), range(2)))
    assert results[0] == results[1], 'Concurrent retries created different orders'
    order = results[0]
    as_user(pharmacist, f"select public.transition_order('{order}','quote',12000)")
    as_user(customer, f"select public.transition_order('{order}','confirm')")
    as_user(pharmacist, f"select public.transition_order('{order}','prepare'); select public.transition_order('{order}','ready')")

    def accept(rider):
        try:
            as_user(rider, f"select public.transition_order('{order}','accept'); select pg_sleep(0.2)")
            return True
        except RuntimeError as error:
            if 'Transition not permitted' not in str(error):
                raise
            return False

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        wins = list(pool.map(accept, [rider1,rider2]))
    assert sum(wins) == 1, f'Expected one winning rider, got {wins}'
    record = json.loads(sql(f"select json_build_object('status',status,'rider_id',rider_id) from public.orders where id='{order}'"))
    assert record['status'] == 'assigned'
    assert record['rider_id'] == [rider1,rider2][wins.index(True)]
    print('Concurrent idempotency and exclusive rider assignment passed.')
finally:
    sql(f"""
      delete from public.order_events where order_id in (select id from public.orders where pharmacy_id='{pharmacy}');
      delete from public.orders where pharmacy_id='{pharmacy}';
      delete from public.pharmacy_members where pharmacy_id='{pharmacy}';
      delete from public.pharmacies where id='{pharmacy}';
      delete from auth.users where id in ('{customer}','{pharmacist}','{rider1}','{rider2}');
    """)
