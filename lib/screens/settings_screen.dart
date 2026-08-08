import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionCard(
            title: '연속 흡연 묶기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '직전 기록과 ${settings.sessionGapMinutes}분 이내면 같은 흡연 1회로 묶어 '
                  '1회 n개비로 집계합니다. 기록 자체는 누를 때마다 1개비씩 그대로 쌓입니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: settings.sessionGapMinutes.toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '${settings.sessionGapMinutes}분',
                        onChanged: (v) => state.updateSettings(
                          settings.copyWith(sessionGapMinutes: v.round()),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${settings.sessionGapMinutes}분',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.session,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '하루 기준 시각',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '새벽 흡연을 전날로 집계하려면 시작 시각을 늦춰 두세요. '
                  '(예: 4시로 두면 새벽 3시 흡연은 전날 기록)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var h = 0; h <= 6; h++)
                      ChoiceChip(
                        label: Text('$h시'),
                        selected: settings.dayStartHour == h,
                        onSelected: (_) => state.updateSettings(
                          settings.copyWith(dayStartHour: h),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '하루 목표 개비 수 (0이면 사용 안 함)',
            child: _NumberField(
              value: settings.dailyGoal,
              suffix: '개비',
              onChanged: (v) =>
                  state.updateSettings(settings.copyWith(dailyGoal: v)),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '한 개비 가격 (0이면 표시 안 함)',
            child: _NumberField(
              value: settings.pricePerCigarette,
              suffix: '원',
              onChanged: (v) =>
                  state.updateSettings(settings.copyWith(pricePerCigarette: v)),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: '데이터',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.copy_all_rounded),
                  title: const Text('CSV로 복사'),
                  subtitle: Text('기록 ${state.logs.length}건을 클립보드에 복사'),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: state.exportCsv()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('클립보드에 복사했습니다.')),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: AppColors.bad),
                  title: const Text('전체 기록 삭제',
                      style: TextStyle(color: AppColors.bad)),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('전체 기록 삭제'),
                        content: const Text('모든 흡연 기록이 삭제됩니다. 되돌릴 수 없습니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('삭제',
                                style: TextStyle(color: AppColors.bad)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await state.clearAll();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'SmokeCount · 데이터는 이 기기에만 저장됩니다',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        isDense: true,
        suffixText: widget.suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (text) => widget.onChanged(int.tryParse(text) ?? 0),
    );
  }
}
