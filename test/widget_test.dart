import 'package:call_to_record/call/call_controller.dart';
import 'package:call_to_record/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the headphones warning in Italian', (tester) async {
    await tester.pumpWidget(MainApp(controller: CallController()));

    expect(
      find.text(
        'Usa le cuffie: con le casse la voce degli altri finisce anche nella tua traccia.',
      ),
      findsOneWidget,
    );
  });
}
