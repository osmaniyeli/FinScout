// lib/core/widgets/morphing_share_button.dart

import 'package:flutter/material.dart';

/// Referans Video: document_5868465651932210344.mp4
/// "Download and Share Button UI"
///
/// Mantık:
/// 1. Başlangıç: "Raporu İndir & Paylaş" butonu.
/// 2. Tıklandığında: Buton morflanarak akıcı bir yüzde çubuğuna (0% -> 69% -> 100%) dönüşür.
/// 3. Bitiş: "✓ İndirildi" rozetine evrilir ve yanına yay fiziğiyle
///    sosyal paylaşım hapları (WhatsApp, CSV, PDF, Bağlantı) açılır!
class MorphingShareButton extends StatefulWidget {
  final String label;
  final Future<void> Function()? onDownload;
  final Function(String channel)? onShareChannel;

  const MorphingShareButton({
    Key? key,
    this.label = 'Raporu İndir & Paylaş',
    this.onDownload,
    this.onShareChannel,
  }) : super(key: key);

  @override
  State<MorphingShareButton> createState() => _MorphingShareButtonState();
}

enum _ShareBtnState { idle, downloading, downloaded }

class _MorphingShareButtonState extends State<MorphingShareButton>
    with SingleTickerProviderStateMixin {
  _ShareBtnState _state = _ShareBtnState.idle;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startDownloadAndShare() async {
    if (_state != _ShareBtnState.idle) return;

    setState(() => _state = _ShareBtnState.downloading);
    _progressController.forward(from: 0.0);

    if (widget.onDownload != null) {
      await widget.onDownload!();
    } else {
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (mounted) {
      setState(() => _state = _ShareBtnState.downloaded);
    }
  }

  void _reset() {
    setState(() {
      _state = _ShareBtnState.idle;
      _progressController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _buildStateWidget(),
    );
  }

  Widget _buildStateWidget() {
    switch (_state) {
      case _ShareBtnState.idle:
        return _buildIdleButton();
      case _ShareBtnState.downloading:
        return _buildDownloadingBar();
      case _ShareBtnState.downloaded:
        return _buildDownloadedWithShareIcons();
    }
  }

  Widget _buildIdleButton() {
    return InkWell(
      key: const ValueKey('idle'),
      onTap: _startDownloadAndShare,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingBar() {
    return AnimatedBuilder(
      key: const ValueKey('downloading'),
      animation: _progressController,
      builder: (context, child) {
        final progress = _progressController.value;
        final pct = (progress * 100).toInt();

        return Container(
          height: 48,
          width: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: progress.clamp(0.05, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0052FF), Color(0xFF00D084)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Hazırlanıyor... %$pct',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadedWithShareIcons() {
    return Container(
      key: const ValueKey('downloaded'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D084).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D084).withOpacity(0.2),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Onay Rozeti
          InkWell(
            onTap: _reset,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D084).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF00D084), size: 16),
                  SizedBox(width: 5),
                  Text(
                    'İndirildi',
                    style: TextStyle(
                      color: Color(0xFF00D084),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Paylaşım Kanalları (Video 2'deki gibi yayılan hap ikonlar)
          _buildSharePill(Icons.chat_bubble_outline_rounded, 'WhatsApp', const Color(0xFF25D366)),
          const SizedBox(width: 6),
          _buildSharePill(Icons.picture_as_pdf_rounded, 'PDF', const Color(0xFFEF4444)),
          const SizedBox(width: 6),
          _buildSharePill(Icons.table_chart_rounded, 'CSV', const Color(0xFF10B981)),
          const SizedBox(width: 6),
          _buildSharePill(Icons.link_rounded, 'Kopyala', const Color(0xFF38BDF8)),
        ],
      ),
    );
  }

  Widget _buildSharePill(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        widget.onShareChannel?.call(label);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            content: Text('$label ile paylaşıldı!'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
