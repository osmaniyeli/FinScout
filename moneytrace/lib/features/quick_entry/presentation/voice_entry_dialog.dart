import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../../../core/theme/app_colors.dart';

class VoiceEntryDialog extends StatefulWidget {
  const VoiceEntryDialog({Key? key}) : super(key: key);

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const VoiceEntryDialog(),
    );
  }

  @override
  State<VoiceEntryDialog> createState() => _VoiceEntryDialogState();
}

class _VoiceEntryDialogState extends State<VoiceEntryDialog> {
  final SpeechToText _speechToText = SpeechToText();
  final TextEditingController _textController = TextEditingController();

  bool _isInitialized = false;
  bool _isListening = false;
  double _soundLevel = 0.0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (SpeechRecognitionError error) {
          if (mounted) {
            setState(() {
              _errorMessage = error.errorMsg.contains('language') || error.errorMsg.contains('not_available')
                  ? "Cihaz içi Türkçe ses tanıma paketi yok. Telefon Ayarları > Sistem > Diller > Konuşma tanıma bölümünden çevrimdışı Türkçe paketini indirin ya da yazarak girin."
                  : "Ses tanınamadı (${error.errorMsg}). Tekrar deneyin veya yazarak girin.";
              _isListening = _speechToText.isListening;
            });
          }
        },
        onStatus: (String status) {
          if (mounted) {
            setState(() {
              _isListening = _speechToText.isListening;
            });
          }
        },
      );
      var hasTurkish = true;
      if (available) {
        final locales = await _speechToText.locales();
        hasTurkish =
            locales.any((l) => l.localeId.toLowerCase().startsWith('tr'));
      }
      if (mounted) {
        setState(() {
          _isInitialized = available;
          if (!available) {
            _errorMessage =
                "Ses tanıma kullanılamıyor (mikrofon izni verilmemiş veya cihaz desteklemiyor). Yazarak da girebilirsiniz.";
          } else if (!hasTurkish) {
            _errorMessage =
                "Cihazda Türkçe ses tanıma paketi yok. Telefon Ayarları > Dil ve giriş > Konuşma tanıma bölümünden Türkçe'yi indirin.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _errorMessage = "Ses tanıma sistemi başlatılamadı: $e";
        });
      }
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      await _initSpeech();
    }
    if (!_isInitialized) return;

    if (mounted) {
      setState(() {
        _errorMessage = '';
      });
    }

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          }
        },
        onSoundLevelChange: (double level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
          localeId: 'tr_TR',
          // Sıfır-bilgi: ses yalnızca cihaz üzerinde tanınır, Google sunucularına gönderilmez
          onDevice: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Mikrofon başlatılamadı: $e";
        });
      }
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.mic_rounded, color: AppColors.actionPrimary, size: 22),
          SizedBox(width: 8),
          Text(
            'Sesli Harcama Tanıma',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Mikrofona basıp harcamanızı söyleyin. Sesiniz yalnızca telefonunuzda metne çevrilir, hiçbir sunucuya gönderilmez.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Mikrofon Butonu ve Ses Seviyesi Göstergesi
            Stack(
              alignment: Alignment.center,
              children: [
                if (_isListening)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 72 + (_soundLevel * 4),
                    height: 72 + (_soundLevel * 4),
                    decoration: BoxDecoration(
                      color: AppColors.expenseRed.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppColors.expenseRed.withValues(alpha: 0.2)
                        : AppColors.actionPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 36,
                    icon: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isListening
                          ? AppColors.expenseRed
                          : AppColors.actionPrimary,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              _isListening ? "Dinleniyor..." : "Mikrofona Dokunarak Başlayın",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isListening
                    ? AppColors.expenseRed
                    : AppColors.textSecondary,
              ),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.expenseRed),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),

            // Giriş Alanı (Düzenlenebilir)
            TextField(
              controller: _textController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Örn: Manavdan üç yüz elli liralık sebze aldım',
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Örnek Şablonlar:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildTemplateChip(
                'Sanayide oto tamirciye üç bin beş yüz nakit verdim'),
            _buildTemplateChip('Migros\'ta dört yüz elli lira harcadım'),
            _buildTemplateChip('Shell benzin bin sekiz yüz elli lira aldım'),
            _buildTemplateChip('Starbucks kahve yüz seksen beş lira'),
            _buildTemplateChip('Netflix abonelik yüz kırk dokuz tl'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('İptal',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _textController.text.trim();
            Navigator.pop(context, text.isNotEmpty ? text : null);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.actionPrimary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Uygula', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTemplateChip(String voiceText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            _textController.text = voiceText;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.record_voice_over_rounded,
                  size: 14, color: AppColors.actionPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  voiceText,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
