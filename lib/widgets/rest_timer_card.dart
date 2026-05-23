import 'dart:async';

import 'package:flutter/material.dart';

class RestTimerCard extends StatefulWidget {
  const RestTimerCard({super.key});

  @override
  State<RestTimerCard> createState() => _RestTimerCardState();
}

class _RestTimerCardState extends State<RestTimerCard> {
  static const List<int> _presets = [60, 90, 120, 180];

  Timer? _timer;
  int _selectedSeconds = 90;
  int _remainingSeconds = 90;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeText {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _progress {
    if (_selectedSeconds == 0) {
      return 0;
    }
    return 1 - (_remainingSeconds / _selectedSeconds);
  }

  void _selectPreset(int seconds) {
    _timer?.cancel();
    setState(() {
      _selectedSeconds = seconds;
      _remainingSeconds = seconds;
      _isRunning = false;
    });
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rest complete. Next set is ready.')),
        );
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _selectedSeconds;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.timer_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rest Timer',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Keep intensity honest between sets.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _timeText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress.clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((seconds) {
                return ChoiceChip(
                  selected: _selectedSeconds == seconds,
                  label: Text(
                    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                  ),
                  onSelected: (_) => _selectPreset(seconds),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isRunning ? _pause : _start,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? 'Pause' : 'Start Rest'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Reset rest timer',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
