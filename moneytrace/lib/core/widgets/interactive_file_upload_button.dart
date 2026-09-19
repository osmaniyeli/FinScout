// lib/core/widgets/interactive_file_upload_button.dart

import 'package:flutter/material.dart';

/// Referans Video: document_5868465651932210345.mp4
/// "File Button Animation"
///
/// Mantık:
/// 1. Başlangıçta şık dosya adı ve "Yükle" butonu.
/// 2. Tıklandığında buton morflanarak akıcı bir ilerleme kapsülüne ("Uploading...") dönüşür.
/// 3. İşlem tamamlandığında yumuşak yay animasyonuyla pitch-black zemin üzerine
///    yeşil onay tiki ("✓ Tamamlandı") rozetine evrilir.
class InteractiveFileUploadButton extends StatefulWidget {
  final String fileName;
  final String uploadLabel;
  final String successLabel;
  final String? label;
  final Future<void> Function()? onUploadAction;
  final VoidCallback? onComplete;

  const InteractiveFileUploadButton({
    Key? key,
    this.fileName = 'Banka_Ekstresi.pdf',
    this.uploadLabel = 'Yükle',
    this.successLabel = 'Tamamlandı',
    this.label,
    this.onUploadAction,
    this.onComplete,
  }) : super(key: key);

  @override
  State<InteractiveFileUploadButton> createState() =>
      _InteractiveFileUploadButtonState();
}

enum _UploadState { idle, uploading, completed }

class _InteractiveFileUploadButtonState
    extends State<InteractiveFileUploadButton>
    with SingleTickerProviderStateMixin {
  _UploadState _state = _UploadState.idle;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _triggerUpload() async {
    if (_state != _UploadState.idle) return;

    setState(() => _state = _UploadState.uploading);
    _progressController.forward(from: 0.0);

    if (widget.onUploadAction != null) {
      await widget.onUploadAction!();
    } else {
      await Future.delayed(const Duration(milliseconds: 1400));
    }

    if (mounted) {
      setState(() => _state = _UploadState.completed);
      widget.onComplete?.call();

      // 2.5 saniye sonra ilk duruma resetle
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _state = _UploadState.idle;
            _progressController.reset();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: _buildCurrentState(),
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case _UploadState.idle:
        return _buildIdleCard();
      case _UploadState.uploading:
        return _buildUploadingPill();
      case _UploadState.completed:
        return _buildCompletedPill();
    }
  }

  Widget _buildIdleCard() {
    return Container(
      key: const ValueKey('idle_card'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFFEF4444),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.fileName,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: _triggerUpload,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316), // Canlı turuncu (Videodaki ton)
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.uploadLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingPill() {
    return AnimatedBuilder(
      key: const ValueKey('uploading_pill'),
      animation: _progressController,
      builder: (context, child) {
        final progress = _progressController.value;
        return Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFED7AA),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // İlerleyen gradyan çubuğu
              FractionallySizedBox(
                widthFactor: progress.clamp(0.05, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              // Merkez Yazı
              Center(
                child: Text(
                  'Yükleniyor... %${(progress * 100).toInt()}',
                  style: TextStyle(
                    color: progress > 0.4 ? Colors.white : const Color(0xFF9A3412),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedPill() {
    return Container(
      key: const ValueKey('completed_pill'),
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Pitch dark pill (Videodaki siyah kapsül)
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.successLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
