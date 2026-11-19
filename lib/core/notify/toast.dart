import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final int id;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

class ToastNotifier extends Notifier<ToastMessage?> {
  Timer? _timer;
  int _counter = 0;

  @override
  ToastMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    _timer?.cancel();
    state = ToastMessage(
      id: ++_counter,
      text: text,
      actionLabel: actionLabel,
      onAction: onAction,
    );
    _timer = Timer(duration, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

final toastProvider =
    NotifierProvider<ToastNotifier, ToastMessage?>(ToastNotifier.new);
