"""Opt-in hosted COD/Storage acceptance. Only disposable fixtures are mutated.
Set SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY and
HOSTED_TEST_PROJECT_REF to the same approved mock project. Never use real data.
Privileged credentials are used only to provision/clean up fixtures; assertions
use separately signed-in customer, stranger, pharmacy, rider and operator JWTs.
"""
import base64
import concurrent.futures
import datetime
import json
import os
import secrets
import time
import urllib.error
import urllib.request
import uuid


def main():
    ref = os.environ['HOSTED_TEST_PROJECT_REF']
    origin = os.environ['SUPABASE_URL'].rstrip('/')
    assert origin == f'https://{ref}.supabase.co' or (ref == 'local' and origin == 'http://127.0.0.1:54321'), 'Explicit project confirmation required'
    anon = os.environ['SUPABASE_ANON_KEY']
    service = os.environ['SUPABASE_SERVICE_ROLE_KEY']
    run = str(uuid.uuid4())
    users, sessions, orders, uploads = {}, {}, [], []
    pharmacy, lot = str(uuid.uuid4()), str(uuid.uuid4())
    created_pharmacy = False
    checks = []

    def request(method, path, body=None, token=None, binary=False, mime='application/json'):
        headers = {'apikey': service if token == service else anon,
                   'Authorization': 'Bearer ' + (token or anon), 'Content-Type': mime}
        raw = body if binary else (json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(origin + path, data=raw, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data, status = r.read(), r.status
        except urllib.error.HTTPError as e:
            data, status = e.read(), e.code
        try:
            data = json.loads(data) if data else None
        except (ValueError, UnicodeDecodeError):
            pass
        return status, data

    def ok(method, path, body=None, token=None, **kw):
        status, data = request(method, path, body, token, **kw)
        assert 200 <= status < 300, f'{method} {path.split("?")[0]} HTTP {status}'
        return data

    def denied(method, path, body=None, role='stranger', **kw):
        status, _ = request(method, path, body, sessions.get(role), **kw)
        assert status in (400, 401, 403, 404, 409, 413, 415, 422), f'Expected denial, HTTP {status}'

    def rpc(role, name, args):
        return ok('POST', '/rest/v1/rpc/' + name, args, sessions[role])

    def listed(role, order):
        return next((r for r in rpc(role, 'list_orders', {'p_offset': 0}) if r['id'] == order), None)

    def transition(role, order, action):
        rpc(role, 'transition_order', {'p_id': order, 'p_action': action})

    def check(name, condition=True):
        assert condition, name
        checks.append(name)
        print('PASS:', name, flush=True)

    png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==')
    cleanup_errors = []
    try:
        roles = {'customer': 'customer', 'stranger': 'customer', 'pharmacy': 'pharmacy_owner',
                 'rider': 'delivery_partner', 'rider2': 'delivery_partner', 'operator': 'admin'}
        for name, role in roles.items():
            email = f'md-test-{run}-{name}@example.invalid'
            password = secrets.token_urlsafe(32)
            user = ok('POST', '/auth/v1/admin/users', {'email': email, 'password': password,
                       'email_confirm': True, 'user_metadata': {'test_run': run}}, service)
            users[name] = user['id']
            ok('PATCH', '/rest/v1/profiles?id=eq.' + user['id'],
               {'role': role, 'full_name': 'Disposable mock ' + name, 'service_postal_codes': ['382010']}, service)
            session = ok('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
            sessions[name] = session['access_token']
            profile = ok('GET', '/rest/v1/profiles?select=role', token=sessions[name])
            check('separate authenticated profile: ' + name, profile == [{'role': role}])
        ok('POST', '/rest/v1/pharmacies', {'id': pharmacy, 'name': 'Disposable mock test ' + run,
           'postal_codes': ['382010'], 'active': True, 'pickup_address': '123 Fictional Test Road',
           'contact_phone': '+919876543210', 'license_reference': 'TEST-NOT-A-LICENSE',
           'verified_at': datetime.datetime.now(datetime.timezone.utc).isoformat()}, service)
        created_pharmacy = True
        ok('POST', '/rest/v1/pharmacy_members', {'pharmacy_id': pharmacy, 'user_id': users['pharmacy']}, service)
        expiry = (datetime.date.today() + datetime.timedelta(days=365)).isoformat()
        lot = rpc('pharmacy', 'save_inventory', {'p_pharmacy_id': pharmacy, 'p_name': 'Fictional test item',
                  'p_batch': run, 'p_expiry': expiry, 'p_price': 9225, 'p_stock': 10})
        request_id = str(uuid.uuid4())
        path = users['customer'] + '/' + request_id + '.png'
        ok('POST', '/storage/v1/object/prescriptions/' + path, png, sessions['customer'], binary=True, mime='image/png')
        uploads.append(path)
        check('customer PNG upload')
        denied('POST', '/storage/v1/object/prescriptions/' + path, png, role='customer', binary=True, mime='image/png')
        denied('POST', '/storage/v1/object/prescriptions/' + path, png, binary=True, mime='image/png')
        denied('POST', '/storage/v1/object/prescriptions/' + users['customer'] + '/' + str(uuid.uuid4()) + '.txt', b'fictional', role='customer', binary=True, mime='text/plain')
        denied('POST', '/storage/v1/object/prescriptions/' + users['customer'] + '/' + str(uuid.uuid4()) + '.png', png + b'0' * (5 * 1024 * 1024), role='customer', binary=True, mime='image/png')
        check('duplicate, foreign-folder, invalid MIME and oversized uploads denied')
        args = {'p_request_id': request_id, 'p_pharmacy_id': pharmacy, 'p_address': '12 Fictional Test Garden',
                'p_postal_code': '382010', 'p_items': [], 'p_prescription_path': path,
                'p_notes': 'Synthetic acceptance image; not a prescription', 'p_recipient_phone': '+919876543210'}
        order = rpc('customer', 'create_order', args)['id']
        orders.append(order)
        check('request replay is idempotent', rpc('customer', 'create_order', args)['id'] == order)
        check('foreign customer cannot list order', listed('stranger', order) is None)
        check('pharmacy and operator can list assigned order', listed('pharmacy', order) is not None and listed('operator', order) is not None)
        for role in ('stranger', 'rider', 'rider2'):
            denied('POST', '/storage/v1/object/sign/prescriptions/' + path, {'expiresIn': 60}, role=role)
            check('private image signing denied: ' + role)
        denied('GET', '/storage/v1/object/public/prescriptions/' + path, role='anonymous')
        for role in ('customer', 'pharmacy', 'operator'):
            signed = ok('POST', '/storage/v1/object/sign/prescriptions/' + path, {'expiresIn': 2}, sessions[role])['signedURL']
            url_path = '/storage/v1' + signed if signed.startswith('/object/') else signed
            data = ok('GET', url_path)
            check('authorized signed image download: ' + role, data == png)
        time.sleep(4)
        denied('GET', url_path, role='anonymous')
        check('signed image expires')
        denied('POST', '/rest/v1/rpc/quote_order', {'p_id': order, 'p_lines': [{'lot_id': lot, 'quantity': 2}],
               'p_delivery_fee': 2500, 'p_review_note': 'Fictional review'}, role='customer')
        rpc('pharmacy', 'quote_order', {'p_id': order, 'p_lines': [{'lot_id': lot, 'quantity': 2}],
            'p_delivery_fee': 2500, 'p_review_note': 'Fictional review for acceptance test'})
        check('server computes itemized total', listed('customer', order)['quote_paise'] == 20950)
        stock = ok('GET', '/rest/v1/inventory_lots?id=eq.' + lot, token=sessions['pharmacy'])[0]
        check('quote reserves stock', stock['on_hand'] == 10 and stock['reserved'] == 2)
        transition('customer', order, 'confirm')
        transition('pharmacy', order, 'prepare')
        transition('pharmacy', order, 'ready')
        redacted = listed('rider', order)
        check('rider dispatch view hides medical and recipient information', redacted['delivery_address'] == '' and redacted['recipient_phone'] == '' and 'prescription_path' not in redacted and 'items' not in redacted)
        def accept(role):
            status, _ = request('POST', '/rest/v1/rpc/transition_order', {'p_id': order, 'p_action': 'accept'}, sessions[role])
            return role, status
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(accept, ('rider', 'rider2')))
        winners = [role for role, status in results if 200 <= status < 300]
        check('concurrent rider acceptance has one winner', len(winners) == 1)
        winner = winners[0]
        check('assigned rider receives delivery contact', listed(winner, order)['recipient_phone'] == '+919876543210')
        check('rider cannot bypass redacted RPC', ok('GET', '/rest/v1/orders?id=eq.' + order, token=sessions[winner]) == [])
        transition(winner, order, 'pickup')
        transition(winner, order, 'deliver')
        delivered = listed('customer', order)
        check('COD delivered with cash collection', delivered['status'] == 'delivered' and delivered['payment_status'] == 'cash_collected')
        check('completed rider contact removed', listed(winner, order)['delivery_address'] == '' and listed(winner, order)['recipient_phone'] == '')
        stock = ok('GET', '/rest/v1/inventory_lots?id=eq.' + lot, token=sessions['pharmacy'])[0]
        check('delivery deducts stock exactly once', stock['on_hand'] == 8 and stock['reserved'] == 0)
        denied('POST', '/rest/v1/rpc/transition_order', {'p_id': order, 'p_action': 'deliver'}, role=winner)
        check('duplicate delivery denied')
    finally:
        # Delete only this run's UUID-scoped fixtures, preserving all existing demo data.
        cleanup = []
        if uploads:
            cleanup.append(('DELETE', '/storage/v1/object/prescriptions', {'prefixes': uploads}))
        for order in orders:
            cleanup.extend(('DELETE', '/rest/v1/' + table + '?order_id=eq.' + order, None) for table in ('order_events', 'order_lots'))
            cleanup.append(('DELETE', '/rest/v1/orders?id=eq.' + order, None))
        if created_pharmacy:
            cleanup.extend(('DELETE', '/rest/v1/' + table + '?pharmacy_id=eq.' + pharmacy, None) for table in ('inventory_lots', 'pharmacy_members'))
            cleanup.append(('DELETE', '/rest/v1/pharmacies?id=eq.' + pharmacy, None))
        for token in sessions.values():
            try:
                ok('POST', '/auth/v1/logout?scope=global', token=token)
            except Exception:
                cleanup_errors.append('session logout')
        cleanup.extend(('DELETE', '/auth/v1/admin/users/' + user, None) for user in users.values())
        for method, path, body in cleanup:
            try:
                ok(method, path, body, service)
            except Exception:
                cleanup_errors.append(path)
        print(json.dumps({'run': run, 'checks_passed': checks, 'cleanup_errors': cleanup_errors}))
        assert not cleanup_errors, 'Fixture cleanup incomplete; inspect UUID-scoped report'


if __name__ == '__main__':
    main()
