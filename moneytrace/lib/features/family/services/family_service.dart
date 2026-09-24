import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/account_service.dart';
import '../../subscription/services/subscription_service.dart';

/// Kullanıcıya gösterilecek aile hatası (Türkçe mesaj).
class FamilyException implements Exception {
  final String message;
  const FamilyException(this.message);
  @override
  String toString() => message;
}

class FamilyMember {
  final String userId;
  final bool isOwner;
  final bool isMe;
  final String displayName;
  final String? emailMasked;
  final DateTime? joinedAt;

  const FamilyMember({
    required this.userId,
    required this.isOwner,
    required this.isMe,
    required this.displayName,
    this.emailMasked,
    this.joinedAt,
  });

  factory FamilyMember.fromMap(Map<String, dynamic> m) => FamilyMember(
        userId: m['user_id']?.toString() ?? '',
        isOwner: m['role'] == 'owner',
        isMe: m['is_me'] == true,
        displayName: (m['display_name'] as String?)?.trim().isNotEmpty == true
            ? (m['display_name'] as String).trim()
            : 'Üye',
        emailMasked: m['email_masked'] as String?,
        joinedAt: DateTime.tryParse(m['joined_at']?.toString() ?? ''),
      );
}

/// Sunucudaki aile durumu (my_family RPC)
class FamilyState {
  final bool inFamily;
  final bool isOwner;

  /// Aile paketi aktif ama henüz aile kurulmamış (sahip olabilir)
  final bool canCreate;

  /// Aile sahibinin aile aboneliği şu an geçerli mi
  final bool ownerActive;
  final int maxMembers;
  final List<FamilyMember> members;
  final String? inviteCode;
  final DateTime? inviteExpiresAt;

  const FamilyState({
    required this.inFamily,
    required this.isOwner,
    required this.canCreate,
    required this.ownerActive,
    required this.maxMembers,
    required this.members,
    this.inviteCode,
    this.inviteExpiresAt,
  });

  bool get isFull => members.length >= maxMembers;

  factory FamilyState.fromMap(Map<String, dynamic> m) {
    final invite = m['invite'];
    final members = m['members'];
    return FamilyState(
      inFamily: m['in_family'] == true,
      isOwner: m['role'] == 'owner',
      canCreate: m['can_create'] == true,
      ownerActive: m['owner_active'] == true,
      maxMembers: (m['max_members'] as num?)?.toInt() ?? 4,
      members: members is List
          ? members
              .whereType<Map>()
              .map((e) => FamilyMember.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      inviteCode: invite is Map ? invite['code'] as String? : null,
      inviteExpiresAt: invite is Map
          ? DateTime.tryParse(invite['expires_at']?.toString() ?? '')?.toLocal()
          : null,
    );
  }
}

/// Aile paketi: premium hakkını en fazla 4 kişiyle paylaşma.
/// Finansal veri paylaşılmaz; sunucu yalnızca kimin hangi ailede olduğunu bilir.
class FamilyService {
  FamilyService._();
  static final FamilyService instance = FamilyService._();

  SupabaseClient get _client {
    final c = AccountService.instance.signedInClient;
    if (c == null) {
      throw const FamilyException('Aile özelliği için hesabına giriş yapmalısın.');
    }
    return c;
  }

  Future<FamilyState> load() async {
    final data = await _call('my_family');
    return FamilyState.fromMap(data);
  }

  /// Yeni davet kodu (48 saat geçerli, tek kullanımlık; önceki kullanılmamış kod geçersiz olur)
  Future<({String code, DateTime expiresAt})> createInvite() async {
    final data = await _call('create_family_invite');
    return (
      code: data['code'] as String,
      expiresAt: DateTime.parse(data['expires_at'].toString()).toLocal(),
    );
  }

  Future<void> join(String code) async {
    await _call('join_family', params: {'p_code': code.trim()});
    await SubscriptionService.instance.refreshEntitlement();
  }

  /// Üye aileden ayrılır; sahip ayrılırsa aile dağılır.
  Future<void> leave() async {
    await _call('leave_family');
    await SubscriptionService.instance.refreshEntitlement();
  }

  Future<void> removeMember(String userId) async {
    await _call('remove_family_member', params: {'p_user_id': userId});
  }

  Future<Map<String, dynamic>> _call(String fn,
      {Map<String, dynamic>? params}) async {
    try {
      final data = await _client.rpc(fn, params: params);
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on PostgrestException catch (e) {
      debugPrint('Aile RPC $fn: ${e.code} ${e.message}');
      throw FamilyException(_message(e.message));
    } on FamilyException {
      rethrow;
    } catch (e) {
      debugPrint('Aile RPC $fn: $e');
      throw const FamilyException(
          'Sunucuya ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.');
    }
  }

  static String _message(String code) => switch (code) {
        'no_family_subscription' =>
          'Davet kodu için aktif bir Aile Paketi aboneliği gerekir.',
        'already_in_family' =>
          'Zaten bir ailedesin. Başka bir aileye katılmak için önce mevcut aileden ayrıl.',
        'family_full' => 'Aile dolu: sen dahil en fazla 4 kişi olabilir.',
        'invalid_code' =>
          'Kod geçersiz, kullanılmış ya da süresi dolmuş. Aile sahibinden yeni kod iste.',
        'owner_subscription_inactive' =>
          'Bu ailenin sahibinin Aile Paketi aboneliği şu an aktif değil.',
        'not_family_owner' => 'Bu işlemi yalnız aile sahibi yapabilir.',
        'cannot_remove_owner' => 'Aile sahibi aileden çıkarılamaz.',
        _ => 'İşlem tamamlanamadı. Lütfen tekrar dene.',
      };
}
