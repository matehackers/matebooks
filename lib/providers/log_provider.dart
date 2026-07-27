import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LogProvider extends ChangeNotifier {
  static const _maxEntries = 1000;

  final List<String> _logs = [];

  List<String> get logs => List.unmodifiable(_logs);

  void addLog(String message) {
    final ts = _timestamp();
    _logs.add('$ts $message');
    while (_logs.length > _maxEntries) {
      _logs.removeAt(0);
    }
    _scheduleNotify();
  }

  void clear() {
    _logs.clear();
    _scheduleNotify();
  }

  void _scheduleNotify() {
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } catch (_) {
      notifyListeners();
    }
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
