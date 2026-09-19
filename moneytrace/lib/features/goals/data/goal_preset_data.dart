// lib/features/goals/data/goal_preset_data.dart

class GoalPresetData {
  // Ev Tipleri
  static const List<String> houseTypes = [
    '2+1 Standart Aile Evi',
    '3+1 / 4+1 Geniş Yaşam Alanı',
    '1+1 Yatırımlık / Şehir Dairesi',
    'Müstakil / Bahçeli / Villa',
    'Yazlık / Sahil Evi',
    'Arsa + Prefabrik Proje',
  ];

  // Türkiye'de En Çok Satan Araç Marka ve Modelleri
  static const Map<String, List<String>> popularVehicles = {
    'Fiat': ['Egea Sedan', 'Egea Cross', '500X', 'Doblo'],
    'Renault': ['Clio', 'Megane Sedan', 'Austral', 'Captur', 'Duster'],
    'Volkswagen': ['Golf', 'Polo', 'T-Roc', 'Tiguan', 'Passat'],
    'Toyota': ['Corolla', 'Corolla Cross', 'Yaris Cross', 'C-HR'],
    'Hyundai': ['i20', 'Bayon', 'Tucson', 'Elantra'],
    'Peugeot': ['208', '2008', '3008', '408'],
    'Ford': ['Focus', 'Puma', 'Kuga', 'Tourneo Courier'],
    'Chery': ['Omoda 5', 'Tiggo 7 Pro', 'Tiggo 8 Pro'],
    'Togg': ['T10X'],
    'Dacia': ['Duster', 'Sandero Stepway', 'Jogger'],
    'Opel': ['Corsa', 'Astra', 'Mokka', 'Grandland'],
    'Skoda': ['Octavia', 'Superb', 'Kamiq', 'Karoq'],
    'Honda': ['Civic', 'City', 'HR-V', 'CR-V'],
    'BMW': ['3 Serisi', '1 Serisi', '5 Serisi', 'X1'],
    'Mercedes-Benz': ['C-Serisi', 'A-Serisi', 'GLA', 'E-Serisi'],
    'Audi': ['A3 Sedan', 'A4', 'Q2', 'Q3'],
    'Diğer': ['Özel Marka / Model'],
  };

  // En Popüler Motorsiklet ve Scooter Marka / Modelleri
  static const Map<String, List<String>> popularMotorcycles = {
    'Honda': ['PCX 125', 'Forza 250', 'Dio', 'Activa 125', 'CB250R', 'Africa Twin'],
    'Yamaha': ['NMAX 125', 'NMAX 155', 'XMAX 250', 'MT-07', 'MT-09', 'Tracer 7'],
    'Vespa': ['Primavera 125', 'Primavera 150', 'GTS 300', 'Sprint 125'],
    'KTM': ['Duke 250', 'Duke 390', 'RC 390', 'Adventure 390'],
    'RKS': ['Wildcat 125', 'Arome 125', 'Freccia 150', 'Bitter 50'],
    'Arora': ['Cappucino 50/125', 'Max-T 150', 'Beatrix 150'],
    'Mondial': ['Drift L 125', 'Turismo 50', 'Lavinia 125'],
    'BMW Motorrad': ['R 1250 GS', 'G 310 R', 'F 900 XR'],
    'Kawasaki': ['Ninja 400', 'Z400', 'Versys 650'],
    'Diğer': ['Özel Model'],
  };

  // Tekne Tipleri
  static const List<String> boatTypes = [
    'Sürat Motoru / Teknesi (5-7m)',
    'Balıkçı / Gezi Teknesi',
    'Şişme Bot (Joker/Zodiac)',
    'Yelkenli Yat (10-14m)',
    'Motoryat (Kamara & Flybridge)',
    'Katamaran',
  ];

  // Özel Hediye Tipleri
  static const List<String> giftOccasions = [
    'Eşime Evlilik Yıl Dönümü Hediyesi',
    'Çocuğuma Doğum Günü / Gelecek Hediyesi',
    'Anne & Baba Özel Gün Hediyesi',
    'Kendime Başarı / Terfi Ödülü',
    'Sevgililer Günü / Yılbaşı Sürprizi',
  ];
}
