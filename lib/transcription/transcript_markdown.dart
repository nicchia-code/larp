import '../call/call_screen.dart' show formatElapsed;
import 'word_segmentation.dart';

/// The markdown of a call: the title with its start, the length, then one line per sentence in start order,
/// or "Nessun parlato rilevato" when no sentence was recognized.
String transcriptMarkdown({
  required DateTime start,
  required Duration length,
  required List<Sentence> sentences,
}) {
  final out = StringBuffer()
    ..writeln('# Call del ${_date(start)} alle ${_hourMinute(start)}')
    ..writeln()
    ..writeln('Durata: ${formatElapsed(length)}')
    ..writeln();
  if (sentences.isEmpty) {
    out.writeln('Nessun parlato rilevato');
  } else {
    for (final sentence in sentences) {
      out.writeln('[${_stamp(sentence.start)}] **${sentence.speaker}:** ${sentence.text}');
    }
  }
  return out.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _date(DateTime t) => '${_two(t.day)}/${_two(t.month)}/${t.year.toString().padLeft(4, '0')}';

String _hourMinute(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

// mm:ss, and hh:mm:ss from the first hour on.
String _stamp(Duration d) {
  final minutes = _two(d.inMinutes.remainder(60));
  final seconds = _two(d.inSeconds.remainder(60));
  return d.inHours > 0 ? '${_two(d.inHours)}:$minutes:$seconds' : '$minutes:$seconds';
}
