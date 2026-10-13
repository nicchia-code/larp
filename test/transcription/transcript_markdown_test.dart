import 'package:call_to_record/transcription/transcript_markdown.dart';
import 'package:call_to_record/transcription/word_segmentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 13, 18, 58);

  test('the markdown has the title, the length and one line per sentence', () {
    final markdown = transcriptMarkdown(
      start: start,
      length: const Duration(hours: 1, minutes: 2, seconds: 3),
      sentences: const [
        Sentence(start: Duration(seconds: 65), speaker: 'Io', text: 'Ciao.'),
        Sentence(start: Duration(hours: 1, seconds: 5), speaker: 'Altri', text: 'Buongiorno.'),
      ],
    );

    expect(
      markdown,
      '# Call del 13/10/2026 alle 18:58\n'
      '\n'
      'Durata: 01:02:03\n'
      '\n'
      '[01:05] **Io:** Ciao.\n'
      '[01:00:05] **Altri:** Buongiorno.\n',
    );
  });

  test('without recognized speech the markdown says so', () {
    final markdown = transcriptMarkdown(
      start: start,
      length: const Duration(seconds: 9),
      sentences: const [],
    );

    expect(markdown, '# Call del 13/10/2026 alle 18:58\n\nDurata: 00:00:09\n\nNessun parlato rilevato\n');
  });
}
