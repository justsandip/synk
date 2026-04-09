import 'package:flutter/widgets.dart';
import 'package:flutter_synk/flutter_synk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/synk.dart';

void main() {
  group('SynkProvider', () {
    testWidgets('provides a SynkDoc to its subtree', (tester) async {
      final doc = SynkDoc(clientId: 1);

      late SynkDoc captured;

      await tester.pumpWidget(
        SynkProvider(
          doc: doc,
          child: Builder(
            builder: (context) {
              captured = SynkProvider.docOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(captured, same(doc));
    });

    testWidgets('throws when no SynkProvider is in the tree', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => SynkProvider.of(context),
              throwsA(isA<FlutterError>()),
            );
            return const SizedBox.shrink();
          },
        ),
      );
    });
    testWidgets('updateShouldNotify returns true if doc changes', (
      tester,
    ) async {
      final doc1 = SynkDoc(clientId: 1);
      final doc2 = SynkDoc(clientId: 2);

      var buildCount = 0;

      final widget = Builder(
        builder: (context) {
          SynkProvider.of(context);
          buildCount++;
          return const SizedBox.shrink();
        },
      );

      await tester.pumpWidget(SynkProvider(doc: doc1, child: widget));

      expect(buildCount, 1);

      await tester.pumpWidget(SynkProvider(doc: doc2, child: widget));

      expect(buildCount, 2);

      await tester.pumpWidget(SynkProvider(doc: doc2, child: widget));

      expect(
        buildCount,
        2,
      ); // doc2 is the same as doc2 (by value? No, SynkDoc identity)
    });
  });
}
