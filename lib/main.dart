import 'dart:async';
import 'package:flutter/material.dart';
import 'package:live_activities/live_activities.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Timer',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const TimerPage(),
    );
  }
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

enum _Status { idle, running, paused }

class _TimerPageState extends State<TimerPage> {
  final _plugin = LiveActivities();
  bool _ready = false;

  _Status _status = _Status.idle;
  Duration _elapsed = Duration.zero;

  // Adjusted so that (now - _origin) always equals total elapsed while running.
  // On resume after pause, _origin is shifted back by the paused duration.
  DateTime? _origin;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    await _plugin.init(
      appGroupId: 'group.iosLiveActivities',
      urlScheme: 'ila',
    );
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _plugin.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _start() async {
    final isResume = _status == _Status.paused;

    // Shift origin back so (now - origin) == _elapsed (zero on fresh start).
    final origin = DateTime.now().subtract(_elapsed);
    _origin = origin;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_origin == null) return;
      setState(() => _elapsed = DateTime.now().difference(_origin!));
    });
    setState(() => _status = _Status.running);

    final data = {
      'startTime': origin.millisecondsSinceEpoch.toDouble(),
      'paused': false,
    };

    if (isResume) {
      await _plugin.updateActivity('timer', data);
    } else {
      await _plugin.createActivity('timer', data);
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    setState(() => _status = _Status.paused);
    await _plugin.updateActivity('timer', {
      'startTime': _origin?.millisecondsSinceEpoch.toDouble() ?? 0.0,
      'paused': true,
      'elapsedSeconds': _elapsed.inSeconds,
    });
  }

  Future<void> _reset() async {
    _ticker?.cancel();
    _ticker = null;
    _origin = null;
    setState(() {
      _status = _Status.idle;
      _elapsed = Duration.zero;
    });
    await _plugin.endActivity('timer');
  }

  // ── UI ────────────────────────────────────────────────────────

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isRunning = _status == _Status.running;
    final isPaused = _status == _Status.paused;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Timer'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _format(_elapsed),
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isRunning
                    ? theme.colorScheme.primary
                    : isPaused
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_status) {
                _Status.idle => 'Ready',
                _Status.running => 'Running',
                _Status.paused => 'Paused',
              },
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 56),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_status == _Status.idle)
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start'),
                  )
                else ...[
                  if (isRunning)
                    FilledButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.pause_rounded),
                      label: const Text('Stop'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Resume'),
                    ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
