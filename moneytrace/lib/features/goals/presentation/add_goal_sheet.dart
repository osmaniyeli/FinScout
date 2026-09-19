// lib/features/goals/presentation/add_goal_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../models/financial_goal.dart';
import '../data/goal_preset_data.dart';

class AddGoalSheet extends StatefulWidget {
  final Function(FinancialGoal newGoal) onGoalCreated;

  const AddGoalSheet({
    Key? key,
    required this.onGoalCreated,
  }) : super(key: key);

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _initialSavedController = TextEditingController(text: '0');

  GoalCategory _selectedCategory = GoalCategory.vehicle;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 365));

  // Dinamik Alan Değerleri
  String? _selectedHouseType = GoalPresetData.houseTypes.first;
  String? _selectedVehicleBrand = 'Fiat';
  String? _selectedVehicleModel = 'Egea Sedan';
  String? _selectedMotoBrand = 'Honda';
  String? _selectedMotoModel = 'PCX 125';
  String? _selectedBoatType = GoalPresetData.boatTypes.first;
  String? _selectedGiftOccasion = GoalPresetData.giftOccasions.first;

  @override
  void initState() {
    super.initState();
    _updateDefaultTitle();
  }

  void _updateDefaultTitle() {
    switch (_selectedCategory) {
      case GoalCategory.house:
        _titleController.text = _selectedHouseType ?? 'Yeni Ev';
        break;
      case GoalCategory.vehicle:
        _titleController.text = '$_selectedVehicleBrand $_selectedVehicleModel';
        break;
      case GoalCategory.motorcycle:
        _titleController.text = '$_selectedMotoBrand $_selectedMotoModel';
        break;
      case GoalCategory.boat:
        _titleController.text = _selectedBoatType ?? 'Yeni Tekne';
        break;
      case GoalCategory.gift:
        _titleController.text = _selectedGiftOccasion ?? 'Özel Hediye';
        break;
      default:
        _titleController.text = '';
        break;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _initialSavedController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen hedef başlığı girin.')),
      );
      return;
    }

    final targetCents = CurrencyNormalizer.toMinorUnits(_targetAmountController.text);
    if (targetCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir hedef tutar girin.')),
      );
      return;
    }

    final initialCents = CurrencyNormalizer.toMinorUnits(_initialSavedController.text);

    String? subType;
    String? brandModel;

    if (_selectedCategory == GoalCategory.house) {
      subType = _selectedHouseType;
    } else if (_selectedCategory == GoalCategory.vehicle) {
      brandModel = '$_selectedVehicleBrand $_selectedVehicleModel';
    } else if (_selectedCategory == GoalCategory.motorcycle) {
      brandModel = '$_selectedMotoBrand $_selectedMotoModel';
    } else if (_selectedCategory == GoalCategory.boat) {
      subType = _selectedBoatType;
    } else if (_selectedCategory == GoalCategory.gift) {
      subType = _selectedGiftOccasion;
    }

    final goal = FinancialGoal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: _selectedCategory,
      targetAmountCents: targetCents,
      currentSavedCents: initialCents > 0 ? initialCents : 0,
      targetDate: _selectedDate,
      createdAt: DateTime.now(),
      subType: subType,
      brandModel: brandModel,
    );

    widget.onGoalCreated(goal);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _selectedCategory.themeColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sürükleme Tutamacı
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_selectedCategory.iconData, color: themeColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Yeni Birikim Hedefi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kategori Seçici Yatay Çip Listesi
            const Text(
              'Hedef Kategorisi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: GoalCategory.values.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        cat.iconData,
                        size: 16,
                        color: isSelected ? Colors.white : cat.themeColor,
                      ),
                      label: Text(cat.displayName),
                      selected: isSelected,
                      selectedColor: cat.themeColor,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected ? cat.themeColor : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedCategory = cat;
                            _updateDefaultTitle();
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // DİNAMİK ALANLAR (Ev Tipi / Araç Marka Model / Motor Marka Model)
            if (_selectedCategory == GoalCategory.house) _buildHouseTypeSelector(),
            if (_selectedCategory == GoalCategory.vehicle) _buildVehicleSelector(),
            if (_selectedCategory == GoalCategory.motorcycle) _buildMotorcycleSelector(),
            if (_selectedCategory == GoalCategory.boat) _buildBoatSelector(),
            if (_selectedCategory == GoalCategory.gift) _buildGiftSelector(),

            const SizedBox(height: 14),

            // Dinamik Motivasyon Banner'ı
            _buildMotivationBanner(),
            const SizedBox(height: 16),

            // Hedef Başlığı
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Hedef Adı',
                labelStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Hedef Tutar & Mevcut Birikim
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: 'Hedef Tutar (₺)',
                      hintText: '1.200.000',
                      labelStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _initialSavedController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      labelText: 'Mevcut Birikim (₺)',
                      hintText: '0',
                      labelStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hedef Tarih Seçici
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Hedef Tarih: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Video 4: Radar Dalgalı Doğrulama ve Güvenli Başlatma Butonu
            RadarCheckoutButton(
              label: 'Hedefi Doğrula & Başlat',
              idleAmountText: _targetAmountController.text.isNotEmpty ? '₺${_targetAmountController.text}' : '',
              verifyingAmountText: 'Hedef Oluşturuluyor...',
              onPressed: () async {
                _submit();
              },
              onVerificationComplete: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 1. Ev Tipi Seçici
  Widget _buildHouseTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ev Tipi Seçin',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedHouseType,
              isExpanded: true,
              items: GoalPresetData.houseTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedHouseType = val;
                    _updateDefaultTitle();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // 2. Araç Marka & Model Seçici
  Widget _buildVehicleSelector() {
    final models = GoalPresetData.popularVehicles[_selectedVehicleBrand] ?? ['Özel Model'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Araç Marka & Model Seçin',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Marka
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedVehicleBrand,
                    isExpanded: true,
                    items: GoalPresetData.popularVehicles.keys.map((brand) {
                      return DropdownMenuItem(
                        value: brand,
                        child: Text(brand, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      );
                    }).toList(),
                    onChanged: (brand) {
                      if (brand != null) {
                        setState(() {
                          _selectedVehicleBrand = brand;
                          _selectedVehicleModel = GoalPresetData.popularVehicles[brand]!.first;
                          _updateDefaultTitle();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Model
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: models.contains(_selectedVehicleModel) ? _selectedVehicleModel : models.first,
                    isExpanded: true,
                    items: models.map((model) {
                      return DropdownMenuItem(
                        value: model,
                        child: Text(model, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (model) {
                      if (model != null) {
                        setState(() {
                          _selectedVehicleModel = model;
                          _updateDefaultTitle();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 3. Motorsiklet Marka & Model Seçici
  Widget _buildMotorcycleSelector() {
    final models = GoalPresetData.popularMotorcycles[_selectedMotoBrand] ?? ['Özel Model'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Motorsiklet / Scooter Seçin',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMotoBrand,
                    isExpanded: true,
                    items: GoalPresetData.popularMotorcycles.keys.map((brand) {
                      return DropdownMenuItem(
                        value: brand,
                        child: Text(brand, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      );
                    }).toList(),
                    onChanged: (brand) {
                      if (brand != null) {
                        setState(() {
                          _selectedMotoBrand = brand;
                          _selectedMotoModel = GoalPresetData.popularMotorcycles[brand]!.first;
                          _updateDefaultTitle();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: models.contains(_selectedMotoModel) ? _selectedMotoModel : models.first,
                    isExpanded: true,
                    items: models.map((model) {
                      return DropdownMenuItem(
                        value: model,
                        child: Text(model, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (model) {
                      if (model != null) {
                        setState(() {
                          _selectedMotoModel = model;
                          _updateDefaultTitle();
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Tekne Seçici
  Widget _buildBoatSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tekne Tipi Seçin',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBoatType,
              isExpanded: true,
              items: GoalPresetData.boatTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedBoatType = val;
                    _updateDefaultTitle();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // 5. Hediye Seçici
  Widget _buildGiftSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hediye Amacı Seçin',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGiftOccasion,
              isExpanded: true,
              items: GoalPresetData.giftOccasions.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedGiftOccasion = val;
                    _updateDefaultTitle();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // Motivasyon Kartı
  Widget _buildMotivationBanner() {
    String text = '';
    switch (_selectedCategory) {
      case GoalCategory.house:
        text = 'Kendi kapını anahtarınla açtığın o ilk günün huzuru paha biçilemez. Her ay biriktirdiğin her kuruş, o evin temeline konan sağlam bir tuğla! 🏠';
        break;
      case GoalCategory.vehicle:
        text = '$_selectedVehicleBrand $_selectedVehicleModel direksiyonuna geçip kontağı çevirdiğin ilk anı ve yeni araç kokusunu hayal et. Gaza basmaya devam! 🚗';
        break;
      case GoalCategory.motorcycle:
        text = '$_selectedMotoBrand $_selectedMotoModel ile trafiğe takılmadan rüzgarı hissedeceğin o ilk rota çok yakın! Birikim depon hızla doluyor. 🏍️';
        break;
      case GoalCategory.boat:
        text = 'Mavi sularda kendi rotanı çizeceğin, gün batımını denizden izleyeceğin günler yakın! ⛵';
        break;
      case GoalCategory.gift:
        text = 'Sevdiklerinin yüzündeki o samimi tebessüm, bu birikimin en büyük getirisi olacak. 🎁';
        break;
      default:
        text = 'Bugün attığın her disiplinli adım, yarının finansal özgürlüğünün güvencesidir! 🌟';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✨', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
