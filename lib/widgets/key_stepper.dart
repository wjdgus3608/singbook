import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KeyStepper extends StatelessWidget {
  final int keyOffset;
  final String origNote;
  final ValueChanged<int> onChanged;

  const KeyStepper({
    super.key,
    required this.keyOffset,
    required this.origNote,
    required this.onChanged,
  });

  static const _notes = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];

  String get _currentNote {
    final idx = _notes.indexOf(origNote);
    if (idx < 0) return origNote;
    return _notes[((idx + keyOffset) % 12 + 12) % 12];
  }

  String get _keyLabel => keyOffset > 0 ? '+$keyOffset' : '$keyOffset';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('내 키',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          // Stepper row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: () {
                  if (keyOffset > -7) onChanged(keyOffset - 1);
                },
              ),
              Column(
                children: [
                  Text(_keyLabel,
                      style: AppTheme.mono(52, FontWeight.w800, AppColors.accent)
                          .copyWith(
                              shadows: [
                            Shadow(
                                color: AppColors.accent.withOpacity(0.5),
                                blurRadius: 24)
                          ])),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: _currentNote,
                          style: AppTheme.mono(
                              13, FontWeight.normal, AppColors.textDim)),
                      const TextSpan(
                          text: ' 장조로 부르기',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textDim)),
                    ]),
                  ),
                ],
              ),
              _StepBtn(
                icon: Icons.add,
                onTap: () {
                  if (keyOffset < 7) onChanged(keyOffset + 1);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Slider
          _KeySlider(
            value: keyOffset,
            onChanged: onChanged,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('-7', style: AppTheme.mono(11, FontWeight.normal, AppColors.textMuted)),
              Text('0', style: AppTheme.mono(11, FontWeight.normal, AppColors.textMuted)),
              Text('+7', style: AppTheme.mono(11, FontWeight.normal, AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1F1F28),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 28),
      ),
    );
  }
}

class _KeySlider extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _KeySlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: const Color(0xFF24242E),
        thumbColor: AppColors.textPrimary,
        overlayColor: AppColors.accent.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      child: Slider(
        value: value.toDouble(),
        min: -7,
        max: 7,
        divisions: 14,
        onChanged: (v) => onChanged(v.round()),
      ),
    );
  }
}
