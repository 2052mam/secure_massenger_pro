import 'package:flutter/material.dart';

import '../../../data/models/poll_model.dart';

/// Telegram-style poll / quiz card rendered inside a message bubble.
///
/// Before voting the options behave like buttons; afterwards each row shows a
/// percentage bar. A quiz additionally marks the correct answer and shows the
/// author's explanation once the viewer has answered.
class PollBubble extends StatelessWidget {
  const PollBubble({
    super.key,
    required this.poll,
    required this.isMine,
    required this.foreground,
    this.onVote,
    this.onRetract,
    this.onClose,
    this.onShowVoters,
    this.busy = false,
  });

  final PollModel poll;
  final bool isMine;
  final Color foreground;

  /// Called with the tapped option id.
  final ValueChanged<String>? onVote;
  final VoidCallback? onRetract;
  final VoidCallback? onClose;
  final VoidCallback? onShowVoters;
  final bool busy;

  String get _subtitle {
    if (poll.isClosed) {
      return poll.isQuiz ? 'آزمون بسته شد' : 'نظرسنجی بسته شد';
    }
    if (poll.isQuiz) return 'آزمون';
    if (poll.allowsMultipleAnswers) {
      return poll.isAnonymous
          ? 'نظرسنجی ناشناس · چند گزینه‌ای'
          : 'نظرسنجی عمومی · چند گزینه‌ای';
    }
    return poll.isAnonymous ? 'نظرسنجی ناشناس' : 'نظرسنجی عمومی';
  }

  String get _votesLabel {
    if (poll.totalVoters == 0) {
      return poll.isQuiz ? 'هنوز کسی پاسخ نداده' : 'هنوز کسی رأی نداده';
    }
    return poll.isQuiz
        ? '${poll.totalVoters} پاسخ'
        : '${poll.totalVoters} رأی';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isMine ? Colors.white : theme.colorScheme.primary;
    final muted = foreground.withValues(alpha: 0.7);
    final showResults = poll.showsResults;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            poll.question,
            style: TextStyle(
              color: foreground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          for (final option in poll.options)
            _PollOptionRow(
              key: ValueKey('poll-option-${option.id}'),
              option: option,
              poll: poll,
              accent: accent,
              foreground: foreground,
              showResults: showResults,
              enabled: !busy && !poll.isClosed && onVote != null,
              onTap: () => onVote?.call(option.id),
            ),
          const SizedBox(height: 6),
          if (poll.isQuiz && poll.hasVoted && poll.explanation?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      poll.explanation!,
                      style: TextStyle(color: muted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (busy)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: muted),
                )
              else
                Text(_votesLabel, style: TextStyle(color: muted, fontSize: 11)),
              const Spacer(),
              if (!poll.isAnonymous && poll.totalVoters > 0 && onShowVoters != null)
                _PollAction(
                  key: const ValueKey('poll-voters'),
                  label: 'رأی‌دهندگان',
                  color: accent,
                  onTap: busy ? null : onShowVoters,
                ),
              if (poll.canRetract && onRetract != null)
                _PollAction(
                  key: const ValueKey('poll-retract'),
                  label: 'حذف رأی',
                  color: accent,
                  onTap: busy ? null : onRetract,
                ),
              if (poll.canClose && onClose != null)
                _PollAction(
                  key: const ValueKey('poll-close'),
                  label: 'بستن',
                  color: accent,
                  onTap: busy ? null : onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    super.key,
    required this.option,
    required this.poll,
    required this.accent,
    required this.foreground,
    required this.showResults,
    required this.enabled,
    required this.onTap,
  });

  final PollOptionModel option;
  final PollModel poll;
  final Color accent;
  final Color foreground;
  final bool showResults;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final correct = option.isCorrect == true;
    final wrongChoice = poll.isQuiz && option.chosen && option.isCorrect == false;
    final barColor = correct
        ? Colors.green
        : wrongChoice
            ? Colors.red
            : accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Marker(
                    chosen: option.chosen,
                    correct: correct,
                    wrong: wrongChoice,
                    multiple: poll.allowsMultipleAnswers,
                    color: barColor,
                    foreground: foreground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight:
                            option.chosen ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (showResults)
                    Text(
                      '${option.percent}٪',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              if (showResults) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (option.percent / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: foreground.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({
    required this.chosen,
    required this.correct,
    required this.wrong,
    required this.multiple,
    required this.color,
    required this.foreground,
  });

  final bool chosen;
  final bool correct;
  final bool wrong;
  final bool multiple;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    if (correct) {
      return Icon(Icons.check_circle, size: 18, color: color);
    }
    if (wrong) {
      return Icon(Icons.cancel, size: 18, color: color);
    }
    if (chosen) {
      return Icon(
        multiple ? Icons.check_box : Icons.radio_button_checked,
        size: 18,
        color: color,
      );
    }
    return Icon(
      multiple ? Icons.check_box_outline_blank : Icons.radio_button_unchecked,
      size: 18,
      color: foreground.withValues(alpha: 0.55),
    );
  }
}

class _PollAction extends StatelessWidget {
  const _PollAction({super.key, required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10),
      child: InkWell(
        onTap: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? color.withValues(alpha: 0.5) : color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
