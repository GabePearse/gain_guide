import 'package:flutter/material.dart';

class ExerciseTile extends StatelessWidget {
  final String name;
  final int? setCount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const ExerciseTile({
    required this.name,
    this.setCount,
    this.onEdit,
    this.onDelete,
    this.onTap,
    super.key,
  });

  bool get _showMenu => onEdit != null || onDelete != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget? trailing;

    if (_showMenu) {
      trailing = PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit?.call();
              break;
            case 'delete':
              onDelete?.call();
              break;
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];

          if (onEdit != null) {
            items.add(
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Rename'),
                ),
              ),
            );
          }

          if (onDelete != null) {
            items.add(
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            );
          }

          return items;
        },
      );
    } else if (onTap != null) {
      trailing = const Icon(Icons.chevron_right);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        leading: Icon(
          Icons.add_task,
          color: theme.colorScheme.primary,
          size: 22,
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: setCount == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  setCount == 1 ? '1 logged set' : '$setCount logged sets',
                ),
              ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
