import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';
import '../services/family_service.dart';

/// Aile: premium hakkını en fazla 4 kişiyle paylaşma (davet kodu ile).
/// Veri paylaşımı YOK: herkesin ekstre ve işlemleri kendi telefonunda kalır.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  /// "Aile nasıl çalışır?" açıklaması (ör. Premium paketler ekranından).
  /// Aileye giriş yalnız Ayarlar › Aile'dedir; bu sayfa yalnız anlatır.
  static Future<void> showHowItWorks(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FamilyHowItWorks(),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anladım'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final FamilyService _service = FamilyService.instance;
  final TextEditingController _codeController = TextEditingController();

  FamilyState? _state;
  String? _loadError;
  bool _loading = true;
  bool _busy = false;

  bool _showJoinForm = false; // Aile Paketi sahibinde "kodla katıl" formu gizli başlar
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final s = await _service.load();
      if (!mounted) return;
      setState(() {
        _state = s;
        _loading = false;
      });
    } on FamilyException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  /// Sunucu işlemini çalıştırır; başarı mesajı yalnız gerçek sonuçtan sonra gösterilir.
  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (success != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.incomeGreen,
          content: Text(success),
        ));
      }
    } on FamilyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text(e.message),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expenseRed),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _fmtDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Aile',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _state == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _state == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: _load, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }
    final s = _state!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const FamilyHowItWorks(),
          const SizedBox(height: 20),
          if (!s.inFamily) ..._notInFamily(s) else ..._inFamily(s),
        ],
      ),
    );
  }

  /// Ailede değilken tek net eylem: Aile Paketi varsa davet kodu oluştur, yoksa aldığın kodu gir.
  List<Widget> _notInFamily(FamilyState s) {
    final join = <Widget>[
      _sectionTitle('KODU GİR'),
      const Text(
        'Aile sahibinin gönderdiği 8 karakterlik kodu gir. Katılınca premium hakların açılır; '
        'verilerin yine yalnız senin telefonunda kalır.',
        style: TextStyle(
            fontSize: 13, color: AppColors.textSecondary, height: 1.35),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _codeController,
        textCapitalization: TextCapitalization.characters,
        maxLength: 8,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
        ],
        onChanged: (_) {
          if (_codeError != null) setState(() => _codeError = null);
        },
        decoration: InputDecoration(
          labelText: 'Davet kodu',
          errorText: _codeError,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _busy
            ? null
            : () {
                final code = _codeController.text.trim();
                if (code.length != 8) {
                  setState(() => _codeError = 'Davet kodu 8 karakterdir.');
                  return;
                }
                _run(() async {
                  await _service.join(code);
                  _codeController.clear();
                }, success: 'Aileye katıldın. Premium hakların açıldı.');
              },
        child: const Text('Aileye katıl'),
      ),
    ];

    if (s.canCreate) {
      return [
        _sectionTitle('AİLE KUR'),
        const Text(
          'Aile Paketin aktif. Davet kodu oluştur ve eklemek istediğin kişiye gönder. '
          'Kod 48 saat geçerlidir ve bir kez kullanılabilir.',
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await _service.createInvite();
                  }, success: 'Davet kodu oluşturuldu.'),
          icon: const Icon(Icons.group_add_rounded),
          label: const Text('Davet kodu oluştur'),
        ),
        const SizedBox(height: 16),
        if (_showJoinForm)
          ...join
        else
          Center(
            child: TextButton(
              onPressed: () => setState(() => _showJoinForm = true),
              child: const Text('Başkasının ailesine kodla katılacağım'),
            ),
          ),
      ];
    }

    return [
      ...join,
      const SizedBox(height: 20),
      Center(
        child: TextButton(
          onPressed: () => SubscriptionPlansSheet.show(context),
          child: const Text('Kendi aileni kurmak için: Aile Paketi'),
        ),
      ),
    ];
  }

  List<Widget> _inFamily(FamilyState s) {
    return [
      if (!s.ownerActive)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            s.isOwner
                ? 'Aile Paketi aboneliğin şu an aktif değil; üyelerin premium hakları kapalı. '
                    'Aboneliğini yenilediğinde hakları yeniden açılır.'
                : 'Aile sahibinin Aile Paketi aboneliği şu an aktif değil; premium hakların kapalı.',
            style: const TextStyle(fontSize: 13, color: AppColors.expenseRed),
          ),
        ),
      _sectionTitle('ÜYELER (${s.members.length}/${s.maxMembers})'),
      ...s.members.map((m) => _memberTile(m, s)),
      if (s.isOwner) ...[
        const SizedBox(height: 24),
        _sectionTitle('DAVET'),
        if (s.inviteCode != null)
          _inviteCard(s)
        else if (s.isFull)
          const Text(
              'Aile dolu. Yeni birini eklemek için önce bir üyeyi çıkar.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        if (!s.isFull)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await _service.createInvite();
                    }, success: 'Yeni davet kodu oluşturuldu.'),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.inviteCode == null
                ? 'Davet kodu oluştur'
                : 'Yeni kod oluştur (eskisi geçersiz olur)'),
          ),
      ],
      const SizedBox(height: 28),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.expenseRed,
          side: const BorderSide(color: AppColors.expenseRed),
        ),
        onPressed: _busy
            ? null
            : () async {
                final ok = s.isOwner
                    ? await _confirm(
                        'Aileyi dağıt',
                        'Tüm üyeler aileden çıkarılır ve aile paketi hakları sadece sende kalır. '
                            'Kimsenin telefonundaki veri silinmez.',
                        'Dağıt')
                    : await _confirm(
                        'Aileden ayrıl',
                        'Aile paketinin premium hakları hesabından kalkar. Telefonundaki verilerin silinmez.',
                        'Ayrıl');
                if (!ok) return;
                await _run(_service.leave,
                    success:
                        s.isOwner ? 'Aile dağıtıldı.' : 'Aileden ayrıldın.');
              },
        child: Text(s.isOwner ? 'Aileyi dağıt' : 'Aileden ayrıl'),
      ),
    ];
  }

  Widget _memberTile(FamilyMember m, FamilyState s) {
    final subtitle = [
      if (m.isOwner) 'Aile sahibi',
      if (m.isMe) 'Sen',
      if (m.emailMasked != null) m.emailMasked!,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE0F2FE),
        child: Text(
          m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?',
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AppColors.actionPrimary),
        ),
      ),
      title: Text(m.displayName,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: s.isOwner && !m.isOwner
          ? IconButton(
              tooltip: 'Aileden çıkar',
              icon: const Icon(Icons.person_remove_outlined,
                  color: AppColors.expenseRed),
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await _confirm(
                          'Üyeyi çıkar',
                          '${m.displayName} aileden çıkarılacak ve aile paketi hakları kalkacak. '
                              'Telefonundaki verileri silinmez.',
                          'Çıkar');
                      if (!ok) return;
                      await _run(() => _service.removeMember(m.userId),
                          success: '${m.displayName} aileden çıkarıldı.');
                    },
            )
          : null,
    );
  }

  Widget _inviteCard(FamilyState s) {
    final code = s.inviteCode!;
    final expires = s.inviteExpiresAt;
    final shareText =
        'FinScout aile paketime katıl: uygulamada Ayarlar > Aile bölümüne bu kodu gir: $code'
        '${expires != null ? ' (${_fmtDateTime(expires)} tarihine kadar geçerli)' : ''}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            code,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.textPrimary),
          ),
          if (expires != null) ...[
            const SizedBox(height: 4),
            Text(
                'Tek kullanımlık · ${_fmtDateTime(expires)} tarihine kadar geçerli',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kod kopyalandı.')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Kopyala'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Share.share(shareText),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Paylaş'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
      );
}

/// Aile özelliğinin 3 adımlık açıklaması. Premium hakkı paylaşılır, veri paylaşılmaz.
class FamilyHowItWorks extends StatelessWidget {
  const FamilyHowItWorks({super.key});

  static const _steps = [
    (
      'Aile Paketi sahibi davet kodu oluşturur',
      'Ayarlar › Aile › "Davet kodu oluştur". Kod 48 saat geçerli ve tek kullanımlıktır.'
    ),
    (
      'Kodu aile üyesine gönderir',
      'Kopyala ya da Paylaş ile mesajla gönder. Aile en fazla 4 kişidir (sahip dahil).'
    ),
    (
      'Üye kendi telefonunda kodu girer',
      'Ayarlar › Aile › Kodu gir. Üyenin premium hakkı açılır.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aile nasıl çalışır?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.actionPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_steps[i].$1,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(_steps[i].$2,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: AppColors.incomeGreen, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paylaşılan yalnız premium hakkıdır; veriler paylaşılmaz. Herkesin ekstre ve '
                  'işlemleri kendi telefonunda kalır, kimse diğerinin verisini görmez.',
                  style: TextStyle(
                      fontSize: 12, height: 1.35, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
