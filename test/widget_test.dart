import 'package:flutter_test/flutter_test.dart';

import 'package:gift_voice_app/main.dart';

void main() {
  testWidgets('renders app title', (WidgetTester tester) async {
    await tester.pumpWidget(
      GiftVoiceApp(model: GiftListModel(), settings: AppSettings()),
    );

    expect(find.text('Gift Tracker'), findsOneWidget);
  });
}
