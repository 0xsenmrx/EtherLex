import 'dart:convert';

/// One server-sent event: the optional `event:` name and the `data:` text.
class SseEvent {
  const SseEvent(this.event, this.data);

  final String? event;
  final String data;
}

/// Reads server-sent events from raw bytes. Lines may be cut anywhere between
/// chunks, line ends may be \n or \r\n, `:` comment lines are skipped and
/// several `data:` lines of one event are joined with a newline.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  String? event;
  final data = <String>[];
  await for (final line in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield SseEvent(event, data.join('\n'));
      event = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') {
      event = value;
    } else if (field == 'data') {
      data.add(value);
    }
  }
  // A stream that ends without the blank line still delivers its last event.
  if (data.isNotEmpty) yield SseEvent(event, data.join('\n'));
}
