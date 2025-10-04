class LogEntry {
  final DateTime ts;
  final String level; // INFO, WARN, ERROR
  final String message;
  final String? scope; // e.g., InstallCheck, Setup, Manage
  final String? file; // optional file path
  LogEntry({
    required this.ts,
    required this.level,
    required this.message,
    this.scope,
    this.file,
  });
}
