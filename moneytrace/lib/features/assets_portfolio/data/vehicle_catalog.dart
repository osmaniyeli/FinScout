// lib/features/assets_portfolio/data/vehicle_catalog.dart

/// Türkiye pazarında yaygın binek / hafif ticari marka ve modelleri (alfabetik).
/// Listede olmayan model için her markanın sonunda "Diğer" seçeneği vardır; o durumda model elle yazılır.
class VehicleCatalog {
  static const String other = 'Diğer';

  static const Map<String, List<String>> brands = {
    'Alfa Romeo': ['Giulia', 'Stelvio', 'Tonale', 'Junior'],
    'Audi': [
      'A1',
      'A3',
      'A4',
      'A5',
      'A6',
      'Q2',
      'Q3',
      'Q5',
      'Q7',
      'Q8',
      'e-tron / Q4 e-tron'
    ],
    'BMW': [
      '1 Serisi',
      '2 Serisi',
      '3 Serisi',
      '4 Serisi',
      '5 Serisi',
      'X1',
      'X2',
      'X3',
      'X5',
      'iX1',
      'i4'
    ],
    'BYD': ['Atto 2', 'Atto 3', 'Dolphin', 'Seal', 'Seal U', 'Sealion 7'],
    'Chery': ['Omoda 5', 'Tiggo 4 Pro', 'Tiggo 7 Pro', 'Tiggo 8 Pro'],
    'Citroen': [
      'C3',
      'C3 Aircross',
      'C4',
      'C4 X',
      'C5 Aircross',
      'Berlingo',
      'C-Elysee'
    ],
    'Cupra': ['Formentor', 'Leon', 'Born', 'Tavascan'],
    'Dacia': [
      'Sandero',
      'Sandero Stepway',
      'Duster',
      'Jogger',
      'Spring',
      'Bigster'
    ],
    'DS': ['DS 3', 'DS 4', 'DS 7'],
    'Fiat': [
      'Egea Sedan',
      'Egea Hatchback',
      'Egea Cross',
      'Egea Station Wagon',
      '500',
      '500X',
      'Doblo',
      'Fiorino',
      'Linea',
      'Panda',
      'Topolino'
    ],
    'Ford': [
      'Fiesta',
      'Focus',
      'Puma',
      'Kuga',
      'Mustang Mach-E',
      'Courier',
      'Tourneo Courier',
      'Tourneo Connect',
      'Transit Custom',
      'Ranger'
    ],
    'Honda': ['Civic', 'City', 'Jazz', 'HR-V', 'CR-V', 'ZR-V'],
    'Hyundai': [
      'i10',
      'i20',
      'Bayon',
      'Elantra',
      'Kona',
      'Tucson',
      'Santa Fe',
      'IONIQ 5',
      'Accent Blue'
    ],
    'Jeep': ['Renegade', 'Compass', 'Avenger', 'Wrangler'],
    'Kia': [
      'Picanto',
      'Rio',
      'Stonic',
      'Ceed',
      'XCeed',
      'Sportage',
      'Sorento',
      'EV6',
      'EV3'
    ],
    'Land Rover': [
      'Defender',
      'Discovery Sport',
      'Range Rover Evoque',
      'Range Rover Velar',
      'Range Rover Sport'
    ],
    'Lexus': ['UX', 'NX', 'RX', 'ES'],
    'Mazda': ['Mazda2', 'Mazda3', 'CX-3', 'CX-30', 'CX-5'],
    'Mercedes-Benz': [
      'A-Serisi',
      'B-Serisi',
      'C-Serisi',
      'CLA',
      'E-Serisi',
      'GLA',
      'GLB',
      'GLC',
      'EQA',
      'EQB',
      'Vito',
      'Sprinter'
    ],
    'MG': ['MG3', 'MG4', 'MG ZS', 'HS', 'Marvel R'],
    'Mini': ['Cooper', 'Countryman', 'Aceman'],
    'Mitsubishi': ['Space Star', 'ASX', 'Eclipse Cross', 'L200'],
    'Nissan': ['Micra', 'Juke', 'Qashqai', 'X-Trail', 'Leaf', 'Navara'],
    'Opel': [
      'Corsa',
      'Astra',
      'Mokka',
      'Crossland',
      'Grandland',
      'Frontera',
      'Combo',
      'Insignia'
    ],
    'Peugeot': [
      '208',
      '2008',
      '301',
      '308',
      '3008',
      '408',
      '5008',
      'Rifter',
      'Partner'
    ],
    'Porsche': ['Macan', 'Cayenne', 'Taycan', '911', 'Panamera'],
    'Renault': [
      'Clio',
      'Megane Sedan',
      'Megane E-Tech',
      'Taliant',
      'Captur',
      'Austral',
      'Symbioz',
      'Duster',
      'Kadjar',
      'Fluence',
      'Symbol',
      'Kangoo',
      'Zoe'
    ],
    'Seat': ['Ibiza', 'Leon', 'Arona', 'Ateca', 'Toledo'],
    'Skoda': [
      'Fabia',
      'Scala',
      'Octavia',
      'Superb',
      'Kamiq',
      'Karoq',
      'Kodiaq',
      'Elroq',
      'Enyaq'
    ],
    'Subaru': ['XV / Crosstrek', 'Forester', 'Outback'],
    'Suzuki': ['Swift', 'Vitara', 'S-Cross', 'Jimny'],
    'Tesla': ['Model 3', 'Model Y', 'Model S', 'Model X'],
    'Togg': ['T10X', 'T10F'],
    'Toyota': [
      'Yaris',
      'Yaris Cross',
      'Corolla',
      'Corolla Cross',
      'C-HR',
      'RAV4',
      'Camry',
      'Proace City',
      'Hilux'
    ],
    'Volkswagen': [
      'Polo',
      'Golf',
      'Jetta',
      'Passat',
      'T-Cross',
      'T-Roc',
      'Taigo',
      'Tiguan',
      'Touareg',
      'ID.3',
      'ID.4',
      'Caddy',
      'Transporter',
      'Amarok'
    ],
    'Volvo': ['XC40', 'EX30', 'XC60', 'XC90', 'S60', 'S90'],
  };

  static List<String> get brandNames => [...brands.keys, other];

  static List<String> modelsOf(String brand) => [...?brands[brand], other];
}
