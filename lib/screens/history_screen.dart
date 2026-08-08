import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/smoke_log.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

/// 전체 기록 목록. 잘못된 기록을 지우거나 시간을 고칠 수 있고,
/// 깜빡한 흡연을 과거 시각으로 추가할 수도 있다.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final analytics = state.analytics;

    // 최신 날짜부터.
    final days = <DateTime>{
      for (final log in state.logs) state.dayCalc.dayKeyOf(log.time),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addManual(context, state),
        icon: const Icon(Icons.add_rounded),
        label: const Text('기록 추가'),
      ),
      body: days.isEmpty
          ? Center(
              child: Text(
                '아직 기록이 없습니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final sessions = analytics.sessionsOn(day);
                final count = analytics.countOn(day);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SectionCard(
                    title: dateFmt.format(day),
                    trailing: Text(
                      '$count개비 · ${sessions.length}회',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ember,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final session in sessions)
                          _SessionTile(session: session),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  static Future<void> _addManual(BuildContext context, AppState state) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    await state.addSmoke(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SmokeSession session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multi = session.count > 1;

    final header = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: (multi ? AppColors.session : AppColors.ember)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '${session.count}',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: multi ? AppColors.session : AppColors.ember,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          multi
              ? '${timeFmt.format(session.start)} ~ ${timeFmt.format(session.end)}'
              : timeFmt.format(session.start),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (multi) ...[
          const SizedBox(width: 8),
          Text(
            '연속 ${session.count}개비',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1개비 세션은 줄 전체를 눌러 수정/삭제, 연속 흡연은 개비별 칩을 누른다.
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: multi
                ? null
                : () => showLogActions(context, session.logs.first),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: header,
            ),
          ),
          if (multi) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final log in session.logs) _LogChip(log: log),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogChip extends StatelessWidget {
  final SmokeLog log;

  const _LogChip({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showLogActions(context, log),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          timeFmt.format(log.time),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// 기록 1건에 대한 수정/삭제 시트.
Future<void> showLogActions(BuildContext context, SmokeLog log) async {
  final state = context.read<AppState>();
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(fullTimeFmt.format(log.time)),
            subtitle: const Text('흡연 기록 1개비'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('시간 수정'),
            onTap: () async {
              Navigator.pop(sheetContext);
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(log.time),
              );
              if (picked == null) return;
              await state.updateLogTime(
                log,
                DateTime(log.time.year, log.time.month, log.time.day,
                    picked.hour, picked.minute),
              );
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: AppColors.bad),
            title: const Text('삭제', style: TextStyle(color: AppColors.bad)),
            onTap: () {
              Navigator.pop(sheetContext);
              state.deleteLog(log);
            },
          ),
        ],
      ),
    ),
  );
}
