import 'package:flutter/widgets.dart';
import 'package:flutter_synk/flutter_synk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/synk.dart';

void main() {
  group('SynkBuilder', () {
    testWidgets('renders initialData on first frame', (tester) async {
      final doc = SynkDoc(clientId: 1);
      final counter = SynkInt(doc, 'score');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SynkBuilder<int>(
            stream: counter.stream,
            initialData: counter.value,
            builder: (context, value) => Text('$value'),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('rebuilds when stream emits', (tester) async {
      final doc = SynkDoc(clientId: 1);
      final counter = SynkInt(doc, 'score');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SynkBuilder<int>(
            stream: counter.stream,
            initialData: counter.value,
            builder: (context, value) => Text('$value'),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      counter.increment(5);
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('works with SynkProvider', (tester) async {
      final doc = SynkDoc(clientId: 1);
      final counter = SynkInt(doc, 'score');

      await tester.pumpWidget(
        SynkProvider(
          doc: doc,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                final resolvedDoc = SynkProvider.docOf(context);
                expect(resolvedDoc, same(doc));

                return SynkBuilder<int>(
                  stream: counter.stream,
                  initialData: counter.value,
                  builder: (context, value) => Text('value: $value'),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('value: 0'), findsOneWidget);

      counter.increment(10);
      await tester.pumpAndSettle();

      expect(find.text('value: 10'), findsOneWidget);

      counter.dispose();
    });
    testWidgets('unsubscribes and resubscribes when stream changes', (
      tester,
    ) async {
      final doc = SynkDoc(clientId: 1);
      final counter1 = SynkInt(doc, 'score1');
      final counter2 = SynkInt(doc, 'score2');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SynkBuilder<int>(
            stream: counter1.stream,
            initialData: counter1.value,
            builder: (context, value) => Text('value: $value'),
          ),
        ),
      );

      expect(find.text('value: 0'), findsOneWidget);

      counter1.increment(5);
      await tester.pumpAndSettle();
      expect(find.text('value: 5'), findsOneWidget);

      // Re-pump with counter2's stream
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SynkBuilder<int>(
            stream: counter2.stream,
            initialData: counter2.value,
            builder: (context, value) => Text('value: $value'),
          ),
        ),
      );

      // Should now show counter2's initial value
      expect(find.text('value: 0'), findsOneWidget);

      counter2.increment(10);
      await tester.pumpAndSettle();
      expect(find.text('value: 10'), findsOneWidget);

      // counter1 should no longer affect the builder
      counter1.increment(20);
      await tester.pumpAndSettle();
      expect(find.text('value: 10'), findsOneWidget);

      counter1.dispose();
      counter2.dispose();
    });
  });
}
