import 'dart:async';

import '../models/log_entry.dart';

class LogBus {
  LogBus._();
  static final LogBus instance = LogBus._();

  final _controller = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get stream => _controller.stream;

  void emit(LogEntry e) => _controller.add(e);

  void info(String msg, {String? scope, String? file}) {
    emit(
      LogEntry(
        ts: DateTime.now(),
        level: 'INFO',
        message: msg,
        scope: scope,
        file: file,
      ),
    );
  }

  void warn(String msg, {String? scope, String? file}) {
    emit(
      LogEntry(
        ts: DateTime.now(),
        level: 'WARN',
        message: msg,
        scope: scope,
        file: file,
      ),
    );
  }

  void error(String msg, {String? scope, String? file}) {
    emit(
      LogEntry(
        ts: DateTime.now(),
        level: 'ERROR',
        message: msg,
        scope: scope,
        file: file,
      ),
    );
  }
}
