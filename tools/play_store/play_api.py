"""Google Play Developer API için küçük yardımcı (Paraİz mağaza ayarları).

Servis hesabı anahtarı repo DIŞINDA durur:
  PLAY_SA_KEY ortam değişkeni ya da varsayılan D:\\dev\\secrets\\play-publisher.json
Anahtarın içeriği hiçbir yere yazdırılmaz.

Kullanım:
  python tools/play_store/play_api.py inspect      # yalnızca okur
"""
import base64
import json
import os
import sys
import time

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

PACKAGE = 'com.moneytrace.app'
KEY_PATH = os.environ.get('PLAY_SA_KEY', r'D:\dev\secrets\play-publisher.json')
BASE = f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def access_token() -> str:
    with open(KEY_PATH, encoding='utf-8') as f:
        sa = json.load(f)
    now = int(time.time())
    header = _b64(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode())
    claims = _b64(json.dumps({
        'iss': sa['client_email'], 'scope': SCOPE, 'aud': sa['token_uri'],
        'iat': now, 'exp': now + 3600,
    }).encode())
    key = serialization.load_pem_private_key(sa['private_key'].encode(), password=None)
    sig = key.sign(f'{header}.{claims}'.encode(), padding.PKCS1v15(), hashes.SHA256())
    r = requests.post(sa['token_uri'], data={
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': f'{header}.{claims}.{_b64(sig)}',
    }, timeout=30)
    r.raise_for_status()
    return r.json()['access_token']


class Play:
    def __init__(self):
        self.s = requests.Session()
        self.s.headers['Authorization'] = 'Bearer ' + access_token()

    def call(self, method, path, **kw):
        url = path if path.startswith('http') else BASE + path
        r = self.s.request(method, url, timeout=60, **kw)
        if r.status_code >= 400:
            raise RuntimeError(f'{method} {path} -> {r.status_code}: {r.text[:500]}')
        return r.json() if r.content else {}

    # --- düzenleme oturumu (edit) ---
    def edit_open(self):
        return self.call('POST', '/edits')['id']

    def edit_delete(self, edit_id):
        self.s.delete(f'{BASE}/edits/{edit_id}', timeout=30)


def inspect():
    p = Play()
    edit = p.edit_open()
    try:
        details = p.call('GET', f'/edits/{edit}/details')
        print('DETAILS:', json.dumps(details, ensure_ascii=False))
        listings = p.call('GET', f'/edits/{edit}/listings').get('listings', [])
        for l in listings:
            print(f"LISTING {l['language']}: title={l.get('title')!r} short={len(l.get('shortDescription',''))} full={len(l.get('fullDescription',''))} karakter")
        tracks = p.call('GET', f'/edits/{edit}/tracks').get('tracks', [])
        for t in tracks:
            rel = [(r.get('name'), r.get('status'), r.get('versionCodes')) for r in t.get('releases', [])]
            print('TRACK', t['track'], rel)
    finally:
        p.edit_delete(edit)  # hiçbir şey kaydedilmez
    subs = p.call('GET', '/subscriptions').get('subscriptions', [])
    print('SUBSCRIPTIONS:', [s['productId'] for s in subs] or 'yok')
    try:
        inapp = p.call('GET', '/onetimeproducts').get('oneTimeProducts', [])
        print('ONE-TIME PRODUCTS:', [x['productId'] for x in inapp] or 'yok')
    except RuntimeError as e:
        print('ONE-TIME PRODUCTS okunamadı:', str(e)[:200])


IMAGE_TYPES = ['icon', 'featureGraphic', 'phoneScreenshots']
UPLOAD = f'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PACKAGE}'


def _copy_missing_images(p, edit, src, dst):
    """dst dilinde olmayan görselleri src dilinden kopyalar (varsayılan dil ikonsuz olamaz)."""
    for t in IMAGE_TYPES:
        if p.call('GET', f'/edits/{edit}/listings/{dst}/{t}').get('images'):
            continue
        for im in p.call('GET', f'/edits/{edit}/listings/{src}/{t}').get('images', []):
            data = requests.get(im['url'] + '=s0', timeout=60).content
            r = p.s.post(f'{UPLOAD}/edits/{edit}/listings/{dst}/{t}?uploadType=media',
                         data=data, headers={'Content-Type': 'image/png'}, timeout=120)
            if r.status_code >= 400:
                raise RuntimeError(f'{t} yüklenemedi: {r.status_code} {r.text[:300]}')
        print(f'görseller {src} -> {dst}: {t}')


def push_listing(default_language='tr-TR'):
    """listing.json'daki metinleri yükler ve varsayılan dili ayarlar (tek edit, commit)."""
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, 'listing.json'), encoding='utf-8') as f:
        listings = json.load(f)
    for lang, v in listings.items():
        assert len(v['title']) <= 30 and len(v['shortDescription']) <= 80 \
            and len(v['fullDescription']) <= 4000, f'{lang}: karakter sınırı aşıldı'
    p = Play()
    edit = p.edit_open()
    try:
        for lang, v in listings.items():
            p.call('PUT', f'/edits/{edit}/listings/{lang}', json={
                'language': lang, 'title': v['title'],
                'shortDescription': v['shortDescription'],
                'fullDescription': v['fullDescription'],
            })
            print('listing', lang, 'yüklendi')
        _copy_missing_images(p, edit, src='en-US', dst=default_language)
        p.call('PATCH', f'/edits/{edit}/details', json={'defaultLanguage': default_language})
        print('varsayılan dil', default_language)
        res = p.call('POST', f'/edits/{edit}:commit')
        print('COMMIT OK', res.get('id'))
    except Exception:
        p.edit_delete(edit)
        raise


REGIONS_VERSION = {'regionsVersion.version': '2022/02'}

# Fiyatlar kullanıcı onayıyla (2026-09-23, TR rakip araştırması). Yalnızca Türkiye.
SUBSCRIPTIONS = [
    {
        'productId': 'finscout_individual_monthly',
        'title': 'FinScout Premium Aylık',
        'description': 'Ayda 3 belge: kart ekstresi, hesap ekstresi ve bordro',
        'benefits': ['Ayda 3 belge yükleme', 'Kart son ödeme hatırlatmaları', 'Reklamsız'],
        'basePlanId': 'monthly', 'period': 'P1M', 'price': (79, 990000000), 'trial': None,
    },
    {
        'productId': 'finscout_individual_annual',
        'title': 'FinScout Premium Yıllık',
        'description': 'Ayda 5 belge; aylık plana göre %37 daha uygun',
        'benefits': ['Ayda 5 belge yükleme', 'Aylığa göre %37 daha uygun', 'İlk 7 gün ücretsiz'],
        'basePlanId': 'annual', 'period': 'P1Y', 'price': (599, 990000000), 'trial': 'P1W',
    },
    {
        'productId': 'finscout_family_annual_4p',
        'title': 'FinScout Aile Yıllık (4 kişi)',
        'description': '4 kişiye kadar, ayda toplam 12 belge',
        'benefits': ['4 kişiye kadar', 'Ayda toplam 12 belge', 'Ortak aile bütçesi'],
        'basePlanId': 'family-annual', 'period': 'P1Y', 'price': (899, 990000000), 'trial': None,
    },
]


def create_subscriptions():
    p = Play()
    existing = {s['productId'] for s in p.call('GET', '/subscriptions').get('subscriptions', [])}
    for s in SUBSCRIPTIONS:
        pid, bp = s['productId'], s['basePlanId']
        units, nanos = s['price']
        if pid not in existing:
            body = {
                'packageName': PACKAGE, 'productId': pid,
                'listings': [{'languageCode': 'tr-TR', 'title': s['title'],
                              'description': s['description'], 'benefits': s['benefits']}],
                'basePlans': [{
                    'basePlanId': bp,
                    'autoRenewingBasePlanType': {
                        'billingPeriodDuration': s['period'],
                        'gracePeriodDuration': 'P7D',
                        'resubscribeState': 'RESUBSCRIBE_STATE_ACTIVE',
                        'prorationMode': 'SUBSCRIPTION_PRORATION_MODE_CHARGE_ON_NEXT_BILLING_DATE',
                        'legacyCompatible': True,
                    },
                    'regionalConfigs': [{
                        'regionCode': 'TR', 'newSubscriberAvailability': True,
                        'price': {'currencyCode': 'TRY', 'units': str(units), 'nanos': nanos},
                    }],
                }],
            }
            p.call('POST', '/subscriptions', params={'productId': pid, **REGIONS_VERSION}, json=body)
            print('oluşturuldu', pid)
        else:
            print('zaten var', pid)
        sub = p.call('GET', f'/subscriptions/{pid}')
        state = next((b.get('state') for b in sub.get('basePlans', []) if b['basePlanId'] == bp), None)
        if state != 'ACTIVE':
            p.call('POST', f'/subscriptions/{pid}/basePlans/{bp}:activate',
                   json={'packageName': PACKAGE, 'productId': pid, 'basePlanId': bp})
            print('  ana plan etkin:', bp)
        if s['trial']:
            offers = p.call('GET', f'/subscriptions/{pid}/basePlans/{bp}/offers').get('subscriptionOffers', [])
            offer = next((o for o in offers if o['offerId'] == 'free-trial-7d'), None)
            if offer is None:
                p.call('POST', f'/subscriptions/{pid}/basePlans/{bp}/offers',
                       params={'offerId': 'free-trial-7d', **REGIONS_VERSION}, json={
                    'packageName': PACKAGE, 'productId': pid, 'basePlanId': bp,
                    'offerId': 'free-trial-7d',
                    'phases': [{'recurrenceCount': 1, 'duration': s['trial'],
                                'regionalConfigs': [{'regionCode': 'TR', 'free': {}}]}],
                    'targeting': {'acquisitionRule': {'scope': {'thisSubscription': {}}}},
                    'regionalConfigs': [{'regionCode': 'TR', 'newSubscriberAvailability': True}],
                })
                print('  deneme teklifi oluşturuldu')
                offer = {'state': 'DRAFT'}
            if offer.get('state') != 'ACTIVE':
                p.call('POST', f'/subscriptions/{pid}/basePlans/{bp}/offers/free-trial-7d:activate',
                       json={'packageName': PACKAGE, 'productId': pid, 'basePlanId': bp,
                             'offerId': 'free-trial-7d'})
                print('  deneme teklifi etkin')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'inspect'
    if cmd == 'inspect':
        inspect()
    elif cmd == 'listing':
        push_listing()
    elif cmd == 'subscriptions':
        create_subscriptions()
    else:
        sys.exit(f'Bilinmeyen komut: {cmd}')
