import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated upload state banner shown above the composer or top of chat.
/// Provides Telegram-level visual polish with fluid progress bar, animated
/// icon pulsation, and clear status text.
class ChatUploadBanner extends StatefulWidget {
  final String mediaType; // 'image', 'video', 'voice', 'file', 'video_note'
  final String? fileName;
  final VoidCallback? onCancel;
  final bool isFa;

  const ChatUploadBanner({
    super.key,
    required this.mediaType,
    this.fileName,
    this.onCancel,
    this.isFa = true,
  });

  @override
  State<ChatUploadBanner> createState() => _ChatUploadBannerState();
}

class _ChatUploadBannerState extends State<ChatUploadBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  IconData _iconForType() {
    switch (widget.mediaType) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'voice':
        return Icons.mic_rounded;
      case 'video_note':
        return Icons.play_circle_fill_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _titleForType() {
    if (widget.isFa) {
      switch (widget.mediaType) {
        case 'image':
          return 'در حال بارگذاری و ارسال عکس…';
        case 'video':
          return 'در حال بهینه‌سازی و آپلود ویدیو…';
        case 'voice':
          return 'در حال آپلود پیام صوتی…';
        case 'video_note':
          return 'در حال ارسال ویدیو مسیج…';
        default:
          return widget.fileName != null
              ? 'در حال ارسال ${widget.fileName}…'
              : 'در حال آپلود فایل…';
      }
    } else {
      switch (widget.mediaType) {
        case 'image':
          return 'Uploading photo…';
        case 'video':
          return 'Optimizing & uploading video…';
        case 'voice':
          return 'Uploading voice note…';
        case 'video_note':
          return 'Sending video message…';
        default:
          return widget.fileName != null
              ? 'Uploading ${widget.fileName}…'
              : 'Uploading file…';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Animated pulsing icon
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, child) {
                      final scale = 0.92 + 0.08 * math.sin(_ctrl.value * 2 * math.pi);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                primary,
                                primary.withValues(alpha: 0.75),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Icon(_iconForType(), color: Colors.white, size: 20),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _titleForType(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isFa ? 'لطفاً شکیبا باشید' : 'Please wait…',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  if (widget.onCancel != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: widget.isFa ? 'لغو' : 'Cancel',
                      onPressed: widget.onCancel,
                    ),
                  ],
                ],
              ),
            ),
            // Shimmering linear progress bar
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return LinearProgressIndicator(
                  minHeight: 2.5,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Full interactive voice recording bar with dynamic animated audio waveforms,
/// pulsing live microphone badge, elapsed timer, slide-to-cancel, and discard/send actions.
class VoiceRecordingBar extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final bool isFa;

  const VoiceRecordingBar({
    super.key,
    required this.onCancel,
    required this.onSend,
    this.isFa = true,
  });

  @override
  State<VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<VoiceRecordingBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  int _seconds = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _disposed) return;
      setState(() => _seconds++);
      _startTimer();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Discard / Trash icon
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: widget.isFa ? 'لغو و حذف' : 'Discard',
            onPressed: widget.onCancel,
          ),
          const SizedBox(width: 4),
          // Pulsing red recording dot
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.6 + 0.4 * _pulseCtrl.value),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5 * _pulseCtrl.value),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Elapsed time
          Text(
            _formattedTime,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          // Dynamic animated audio waveform bars
          Expanded(
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(14, (i) {
                    final phase = (i / 14.0) * 2 * math.pi;
                    final h = 6.0 + 18.0 * ((math.sin(_waveCtrl.value * 2 * math.pi + phase) + 1) / 2);
                    return Container(
                      width: 3,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.45 + (h / 24.0) * 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Slide to cancel text
          Text(
            widget.isFa ? '« کشیدن برای لغو' : '« Slide to cancel',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          Material(
            color: primary,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              onTap: widget.onSend,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
