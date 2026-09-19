# Paraİz (MoneyTrace) - Proje Genel Bakış ve Sistem Mimarisi

Paraİz, kullanıcıların banka kredi kartı hesap özetlerini, vadesiz hesap hareketlerini ve maaş bordrolarını **hiçbir sunucuya göndermeden**, **tamamen cihaz içinde (%100 On-Device)** deterministik algoritmalarla ayrıştıran, analiz eden ve yöneten yeni nesil bir kişisel finans ve bütçe yönetim platformudur.

---

## 1. Temel Prensipler ve Tasarım Felsefesi

1. **Sıfır Bilgi Güvenliği (Zero-Knowledge Architecture)**:
   - Kullanıcının hiçbir finansal verisi, ekstresi, harcama kaydı veya kimlik bilgisi harici bir sunucuya iletilmez.
   - Veritabanı cihazın yerel depolama alanında SQLite (`paraiz_vault.db`) üzerinde tutulur.
2. **Kişisel Veri Maskeleme (PII Redactor)**:
   - TCKN, Kredi Kartı Numarası (PAN), IBAN, telefon numarası ve ev/iş adresi gibi hassas kişisel veriler hafızaya alınmadan önce regex motoruyla maskelenir.
3. **Deterministik & Hukuki Zeka**:
   - Yıllık kart aidatı kesintilerini tespit edip **6502 sayılı Kanun** ve **Yargıtay 13. Hukuk Dairesi** emsal kararlarıyla tek tıkla resmi iade dilekçesi üretir.
   - Nakit avans işlemlerini tespit ederek aylık %5.00 akdi faiz yükünü hesaplar ve acil ödeme takvimine bağlar.
4. **Çapraz Platform (Android & iPhone)**:
   - Tek bir modern Flutter çekirdeği üzerinden hem Android hem iOS (iPhone/iPad) cihazlarda yerel performans ve akıcı animasyonlarla çalışır.
5. **Tam Yönetilebilirlik (Admin Control Panel)**:
   - Modüller, ülke kısıtlamaları, alt menü sıralaması, tema renkleri, buton stilleri ve veri modları merkezi yönetim panelinden anında ayarlanabilir.

---

## 2. Sistem Mimarisi Şeması

```mermaid
flowchart TD
    subgraph Girdi ["1. Finansal Belgeler & Girdiler"]
        A1["Banka PDF Ekstreleri<br/>(Yapı Kredi, Enpara, VakıfBank vb.)"]
        A2["Maaş Bordroları<br/>(SGK, Gelir Vergisi, Damga Vergisi)"]
        A3["Hızlı Manuel & Sesli Giriş<br/>(Kamera Fişi, Sesli Şablon)"]
    end

    subgraph Guvenlik ["2. Güvenlik & Ayrıştırma Katmanı"]
        B1["PII Redactor<br/>(TCKN, PAN, IBAN, Adres Maskeleme)"]
        B2["Deterministik Regex Motoru<br/>(Multi-Card, FX, Taksitler, KDV)"]
        B3["Gateway & Merchant Sanitizer<br/>(Iyzico, PayTR, Sipay POS Temizliği)"]
    end

    subgraph Depolama ["3. Yerel Güvenli Depolama"]
        C1[("SQLite Yerel Kasa<br/>paraiz_vault.db")]
        C2["Dışa Aktarım Motoru<br/>(UTF-8 BOM CSV & Kriptolu JSON)"]
    end

    subgraph Zeka ["4. Finansal Zeka & Projeksiyon"]
        D1["30 Günlük Nakit Akışı & Avans Uyarısı"]
        D2["Birikim Hedefleri & Portföy Analitiği"]
        D3["İzci (Scout) Harcama Koçu"]
        D4["TCMB / Kapalıçarşı Canlı Kurlar"]
    end

    subgraph Yonetim ["5. Merkezi Yönetim & Dinamik Arayüz"]
        E1["Kill-Switch & Bölgesel Kısıtlama"]
        E2["Dinamik Menü Sıralama Motoru"]
        E3["Dinamik Tema & Renk Paleti"]
        E4["Buton & FAB Biçimlendirici"]
    end

    A1 --> B1
    A2 --> B1
    A3 --> B1
    B1 --> B2
    B2 --> B3
    B3 --> C1
    C1 --> D1
    C1 --> D2
    C1 --> D3
    C1 --> C2
    Yonetim -.-> D1
    Yonetim -.-> D2
    Yonetim -.-> D3
```
