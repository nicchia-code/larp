import 'package:call_to_record/call/call_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('callBaseName uses the start time as AAAA-MM-GG_HH-MM-SS', () {
    expect(callBaseName(DateTime(2026, 3, 4, 9, 5, 7)), '2026-03-04_09-05-07');
    expect(callBaseName(DateTime(2026, 12, 31, 23, 59, 59)), '2026-12-31_23-59-59');
  });

  test('callsDirectory is the fixed CallToRecord folder in HOME', () {
    expect(callsDirectory().path, endsWith('/CallToRecord'));
  });
}
