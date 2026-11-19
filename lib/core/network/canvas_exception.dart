enum CanvasErrorKind { invalidUrl, unauthorized, network, rateLimited, server, unexpected }

class CanvasException implements Exception {
  const CanvasException(this.kind, this.message);

  final CanvasErrorKind kind;

  /// Safe to show to the user.
  final String message;

  @override
  String toString() => 'CanvasException($kind): $message';
}
