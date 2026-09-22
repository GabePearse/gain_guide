import 'package:flutter/material.dart';

class WorkoutCard extends StatelessWidget {
  final String title;
  final int exerciseCount;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onSchedule;
  final VoidCallback onDelete;
  final int dragIndex;
  final String? scheduleLabel;

  const WorkoutCard({
    required this.title,
    required this.exerciseCount,
    required this.onTap,
    required this.onRename,
    required this.onSchedule,
    required this.onDelete,
    required this.dragIndex,
    this.scheduleLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReorderableDelayedDragStartListener(
      index: dragIndex,
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        leading: Icon(
          Icons.fitness_center,
          color: theme.colorScheme.primary,
          size: 22,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            scheduleLabel == null
                ? (exerciseCount == 1 ? '1 exercise' : '$exerciseCount exercises')
                : '${exerciseCount == 1 ? '1 exercise' : '$exerciseCount exercises'} · $scheduleLabel',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                onRename();
                break;
              case 'schedule':
                onSchedule();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'schedule',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_month_outlined),
                title: Text('Schedule'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'rename',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Rename'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline),
                title: Text('Delete'),
              ),
            ),
          ],
            ),
          ],
        ),
        onTap: onTap,
      ),
      ),
    );
  }
}
