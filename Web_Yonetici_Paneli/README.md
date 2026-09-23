# FinScout Merkezi Yönetim Portalı (Web Konsolu)

Bu portal, mobil uygulamanın (`FinScout`) güvenliğini riske atmamak adına **mobil kod tabanından tamamen ayrıştırılmış bağımsız bir web arayüzüdür.**

---

## 🚀 Nasıl Çalıştırılır?
1. Herhangi bir sunucu veya node kurulumu **gerektirmez**.
2. Doğrudan bu klasördeki [`index.html`](file:///d:/Users/26075759/OneDrive%20-%20AR%C3%87EL%C4%B0K%20A.%C5%9E/Desktop/Ev%20Ekonomisi/Web_Yonetici_Paneli/index.html) dosyasına çift tıklayarak Google Chrome, Microsoft Edge veya Safari üzerinde açabilirsiniz.

---

## 🎛️ Temel Yetenekler
1. **Modül Şalterleri & Kill-Switch:**
   - 12 temel alt sistemi (PDF ayrıştırıcı, nakit akışı, altın/kurlar, hedefler, varlıklar vb.) canlı açıp kapatabilme.
   - **Test Modu (Temiz Veri Şalteri):** Açıldığında mobil uygulama kullanıcının kendi ekstrelerini yüklemesi için tertemiz `₺0,00` ile başlar.
2. **Menü Sıralaması (Bottom Navigation Bar):**
   - Alt çubuktaki 5 sekmenin (Ana Panel, Nakit Akışı, Analiz, Hedefler, Varlıklar) sırasını `▲ / ▼` butonlarıyla değiştirme.
   - İstenilen sekmeyi gizleme/gösterme.
3. **Renk & Tema Paletleri:**
   - Tek tıkla kurumsal renk temaları (Elektrik Mavisi, Zümrüt Finans, Gece Mavisi, Asil Mor, Siber Amber).
   - Özel Hex renk seçicileri.
4. **Buton Stilleri & UX:**
   - Köşe yuvarlaklığı (Border Radius 0-28px).
   - Buton yükseltisi (Elevation / gölge derinliği).
   - Yüzen Eylem Butonu (FAB) konumu: Sağ altta yüzen (`endFloat`), ortada gömülü (`centerDocked`) veya gizli (`hidden`).
5. **Canlı Akıllı Telefon Simülatörü:**
   - Sağ tarafta yer alan iPhone / Android simülatöründe yapılan her ayar anında gerçek zamanlı yansır.
6. **JSON Dağıtımı:**
   - `remote_config.json İndir` butonuyla tek tıkla yapılandırma dosyasını indirme.
   - Mobil uygulamanın `assets/config/remote_config.json` dizinine veya sunucuya koyarak anında canlıya alma.
