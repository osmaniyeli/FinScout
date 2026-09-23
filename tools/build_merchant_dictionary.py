"""
Üye işyeri → sektör sözlüğünü Gemini ile üretir, doğrular ve birleştirir.

Kullanım (repo kökünden):  python tools/build_merchant_dictionary.py
Çıktı: moneytrace/assets/dictionaries/merchant_sectors_tr.json

Gemini'ye yalnızca genel bir soru gider ("Türkiye'deki X sektörü zincirleri"); kullanıcı verisi gönderilmez.
Üretilen her giriş şema, kategori beyaz listesi, belirsiz kısa kalıp ve tekrar kontrolünden geçer.
"""
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "moneytrace" / "assets" / "dictionaries" / "merchant_sectors_tr.json"

ALLOWED = {
    "cat_market", "cat_fuel", "cat_transit", "cat_dining", "cat_subscriptions", "cat_utilities", "cat_tax",
    "cat_home", "cat_pet", "cat_kids", "cat_investment", "cat_clothing", "cat_health", "cat_salary", "cat_general",
    "cat_insurance", "cat_shopping", "cat_education", "cat_travel", "cat_transfer", "cat_card_payment", "cat_fees",
    "cat_cash", "cat_electronics", "cat_personal_care",
}

# Tek başına yanlış eşleşmeye çok açık kalıplar
AMBIGUOUS = {"PET", "ISU", "GAIN", "TOTAL", "FILE", "SOK", "BIM", "AXA", "HDI", "FLO", "THY", "BP", "ZES", "OGS", "HGS"}
# İnceleme sonrası elenen: kesilmiş veya sıradan kelimeye takılan kalıplar
BLOCKLIST = {"BAKKA", "KARAC", "MADAM", "GARAJ", "BURC", "KEA", "LAV"}
SHORT_OK = {"BIM", "SOK", "BP", "HGS", "OGS", "ZES", "THY", "AXA", "HDI", "FLO"}  # yerleşik kurallarda zaten var

GROUPS = {
    "Süpermarket, market zincirleri, yerel hipermarketler, online market (Getir, İstegelsin vb.)": "cat_market",
    "Akaryakıt istasyonları ve elektrikli araç şarj ağları": "cat_fuel",
    "Toplu taşıma kartları, taksi uygulamaları, otoyol/köprü, otopark, otobüs firmaları, scooter": "cat_transit",
    "Restoran, kafe, fast food, pastane, kahve zincirleri ve yemek siparişi uygulamaları": "cat_dining",
    "Dijital abonelikler: video/müzik yayın, bulut depolama, oyun platformları, yazılım ve yapay zeka servisleri": "cat_subscriptions",
    "Elektrik, doğalgaz, su dağıtım şirketleri, GSM operatörleri, internet ve TV servis sağlayıcıları": "cat_utilities",
    "Ev, mobilya, yapı market, ev tekstili, beyaz eşya mağazaları": "cat_home",
    "Giyim, ayakkabı, spor giyim ve moda zincirleri": "cat_clothing",
    "Eczane zincirleri, özel hastane grupları, optik, diş ve laboratuvar zincirleri": "cat_health",
    "Sigorta ve bireysel emeklilik şirketleri": "cat_insurance",
    "E-ticaret pazaryerleri ve online alışveriş siteleri": "cat_shopping",
    "Elektronik ve teknoloji perakendecileri, telefon markaları mağazaları": "cat_electronics",
    "Havayolları, otel zincirleri, tur operatörleri, bilet ve seyahat siteleri": "cat_travel",
    "Kitapçılar, kırtasiye, özel okul/kolej zincirleri, kurs ve dil okulları, online eğitim": "cat_education",
    "Kozmetik, kişisel bakım mağazaları, kuaför zincirleri": "cat_personal_care",
    "Kuyumcular, altın/döviz, kripto borsaları, yatırım uygulamaları, tasarruf finansman şirketleri": "cat_investment",
    "Oyuncak mağazaları, çocuk eğlence merkezleri, lunapark, bowling": "cat_kids",
    "Pet shop zincirleri ve veteriner klinikleri": "cat_pet",
}

PROMPT = (
    "Türkiye'de kredi kartı ekstrelerinde görülen üye işyeri adları için bir sözlük hazırlıyoruz. "
    "Konu: {topic}. Bu konuda Türkiye'de yaygın en az 40 marka/zincir listele. "
    "SADECE geçerli JSON döndür, açıklama yazma, kod bloğu kullanabilirsin. Şema: "
    '{{"entries":[{{"pattern":"BANKA EKSTRESINDE GORUNDUGU GIBI BUYUK HARF","brand":"Marka Adı","sector":"Kısa sektör adı"}}]}}. '
    "Kurallar: pattern büyük harf; Türkçe karakterli ve karaktersiz iki farklı yazılış varsa ikisini ayrı giriş yap "
    "(ör. MİGROS ve MIGROS). 3 harf ve daha kısa kalıp kullanma. Ödeme aracılarını (IYZICO, PAYTR, PAYPAL) yazma."
)


def ask(topic: str) -> str:
    result = subprocess.run(
        [sys.executable, str(ROOT / "ask_gemini.py"), PROMPT.format(topic=topic)],
        capture_output=True, text=True, encoding="utf-8", timeout=240,
    )
    return result.stdout


def extract_entries(text: str):
    match = re.search(r"\{[\s\S]*\}", text)
    if not match:
        return []
    try:
        return json.loads(match.group(0)).get("entries", [])
    except json.JSONDecodeError:
        return []


def main():
    with ThreadPoolExecutor(max_workers=6) as pool:
        answers = list(pool.map(lambda item: (item[1], extract_entries(ask(item[0]))), GROUPS.items()))

    merged, rejected = {}, []
    for category, entries in answers:
        print(f"{category:20s} {len(entries):3d} giriş")
        for e in entries:
            pattern = str(e.get("pattern", "")).strip().upper()
            pattern = re.sub(r"\s+", " ", pattern)
            if (len(pattern) <= 3 and pattern not in SHORT_OK) or pattern in AMBIGUOUS - SHORT_OK or pattern in BLOCKLIST:
                rejected.append(pattern)
                continue
            if category not in ALLOWED or not pattern:
                continue
            merged.setdefault(pattern, {
                "pattern": pattern,
                "brand": str(e.get("brand") or pattern.title()).strip(),
                "sector": str(e.get("sector") or "").strip(),
                "category": category,
            })

    OUT.write_text(json.dumps({"version": 1, "entries": sorted(merged.values(), key=lambda x: x["pattern"])},
                              ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\nToplam {len(merged)} benzersiz giriş → {OUT}")
    if rejected:
        print(f"Belirsiz/kısa olduğu için reddedilen: {sorted(set(rejected))}")


if __name__ == "__main__":
    main()
