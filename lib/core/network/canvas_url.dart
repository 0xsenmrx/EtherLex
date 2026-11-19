import 'canvas_exception.dart';

/// "school.instructure.com/courses/1" -> "https://school.instructure.com"
String normalizeCanvasUrl(String raw) {
  var input = raw.trim();
  if (input.isEmpty) {
    throw const CanvasException(CanvasErrorKind.invalidUrl, 'Enter your Canvas address.');
  }
  if (!input.contains('://')) input = 'https://$input';
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
    throw const CanvasException(
      CanvasErrorKind.invalidUrl,
      'That does not look like a Canvas address, e.g. school.instructure.com.',
    );
  }
  if (uri.scheme != 'https') {
    throw const CanvasException(CanvasErrorKind.invalidUrl, 'Canvas must be reached over https.');
  }
  final port = uri.hasPort && uri.port != 443 ? ':${uri.port}' : '';
  return 'https://${uri.host.toLowerCase()}$port';
}
