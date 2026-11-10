import 'dart:async';

/// Utility class to debounce rapid function calls.
/// 
/// Useful for search inputs, scroll listeners, or any high-frequency events
/// that should only trigger after user stops interacting.
/// 
/// Example usage:
/// ```dart
/// final debouncer = Debouncer(delay: Duration(milliseconds: 300));
/// 
/// TextField(
///   onChanged: (value) {
///     debouncer.call(() {
///       // This only runs 300ms after user stops typing
///       performSearch(value);
///     });
///   },
/// );
/// ```
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Debounce a function call
  /// 
  /// Cancels any pending timer and starts a new one.
  /// The [action] will only execute after [delay] with no new calls.
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Run action immediately and cancel any pending timer
  void runImmediately(VoidCallback action) {
    _timer?.cancel();
    action();
  }

  /// Cancel any pending timer without executing
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose the debouncer (call in widget's dispose method)
  void dispose() {
    _timer?.cancel();
  }
}

/// Alternative callback-based implementation
typedef VoidCallback = void Function();
