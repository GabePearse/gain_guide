import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/friend_summary.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_header.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  Future<void> _refresh(BuildContext context) async {
    final provider = context.read<WorkoutProvider>();
    await provider.loadFriends();
    await provider.loadReminders();
  }

  Future<void> _addFriend(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                if (name.isEmpty || !email.contains('@')) {
                  return;
                }

                await dialogContext.read<WorkoutProvider>().addFriend(
                      displayName: name,
                      email: email,
                    );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendReminder(
    BuildContext context,
    FriendSummary friend,
  ) async {
    final controller = TextEditingController(
      text: 'Time to get a workout in today?',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Remind ${friend.displayName}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final message = controller.text.trim();
                if (message.isEmpty) {
                  return;
                }

                await dialogContext.read<WorkoutProvider>().sendReminder(
                      friendUserId: friend.friendUserId,
                      message: message,
                    );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reminder sent to ${friend.displayName}'),
                  ),
                );
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final friends = provider.friends;
    final reminders = provider.reminders;
    final currentUser = provider.currentUser;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            onPressed: () => _addFriend(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _CheckInPanel(
              name: currentUser?.displayName ?? 'You',
              lastCheckIn: currentUser?.lastCheckInAt == null
                  ? 'No check-in yet'
                  : 'Checked in ${dateFormat.format(currentUser!.lastCheckInAt!)}',
              onCheckIn: () async {
                await context.read<WorkoutProvider>().checkInNow();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checked in')),
                );
              },
            ),
            const SizedBox(height: 18),
            const AppSectionHeader(title: 'Friend Progress'),
            if (friends.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Add a friend to start tracking each other.'),
                ),
              )
            else
              ...friends.map((friend) {
                final lastCheckIn = friend.lastCheckInAt == null
                    ? 'No check-in yet'
                    : 'Checked in ${dateFormat.format(friend.lastCheckInAt!)}';
                final lastWorkout = friend.lastWorkoutAt == null
                    ? 'No completed workouts yet'
                    : '${friend.lastWorkoutName} on ${dateFormat.format(friend.lastWorkoutAt!)}';

                return _FriendProgressCard(
                  friend: friend,
                  lastCheckIn: lastCheckIn,
                  lastWorkout: lastWorkout,
                  onReminder: () => _sendReminder(context, friend),
                );
              }),
            const SizedBox(height: 6),
            AppSectionHeader(
              title: 'Reminders',
              actionLabel: 'Mark Read',
              onAction: () =>
                  context.read<WorkoutProvider>().markRemindersRead(),
            ),
            if (reminders.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No reminders yet.'),
                ),
              )
            else
              ...reminders.map((reminder) {
                final fromMe = reminder.fromUserId == currentUser?.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Icon(
                      fromMe
                          ? Icons.outgoing_mail
                          : reminder.readAt == null
                              ? Icons.mark_email_unread_outlined
                              : Icons.mail_outline,
                      color: fromMe
                          ? Theme.of(context).colorScheme.secondary
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      fromMe
                          ? 'To ${reminder.toName}'
                          : 'From ${reminder.fromName}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${reminder.message}\n${dateFormat.format(reminder.createdAt)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CheckInPanel extends StatelessWidget {
  final String name;
  final String lastCheckIn;
  final VoidCallback onCheckIn;

  const _CheckInPanel({
    required this.name,
    required this.lastCheckIn,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.ink,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  lastCheckIn,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.ink,
            ),
            onPressed: onCheckIn,
            child: const Text('Check In'),
          ),
        ],
      ),
    );
  }
}

class _FriendProgressCard extends StatelessWidget {
  final FriendSummary friend;
  final String lastCheckIn;
  final String lastWorkout;
  final VoidCallback onReminder;

  const _FriendProgressCard({
    required this.friend,
    required this.lastCheckIn,
    required this.lastWorkout,
    required this.onReminder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Text(
                friend.displayName[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(lastCheckIn),
                  Text(
                    '$lastWorkout - ${friend.completedWorkouts} total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Send reminder',
              onPressed: onReminder,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
