import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/widgets/fade_through_indexed_stack.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.label);
  final String label;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => count++),
        child: Text('${widget.label}:$count'),
      );
}

Widget _host(int index, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: FadeThroughIndexedStack(
          index: index,
          children: const [_Counter('a'), _Counter('b')],
        ),
      ),
    );

void main() {
  testWidgets('sekme değişince durum korunur ve geçiş animasyonludur',
      (tester) async {
    await tester.pumpWidget(_host(0));
    await tester.tap(find.text('a:0'));
    await tester.pump();
    expect(find.text('a:1'), findsOneWidget);

    await tester.pumpWidget(_host(1));
    await tester.pump(const Duration(milliseconds: 50));
    // Geçiş ortasında eski sekme hâlâ çiziliyor (sönüyor).
    expect(find.text('a:1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('a:1'), findsNothing); // offstage
    expect(find.text('b:0'), findsOneWidget);

    await tester.pumpWidget(_host(0));
    await tester.pumpAndSettle();
    expect(find.text('a:1'), findsOneWidget); // durum kaybolmadı
  });

  testWidgets('animasyonları kaldır açıkken geçiş anında', (tester) async {
    await tester.pumpWidget(_host(0, disableAnimations: true));
    await tester.pumpWidget(_host(1, disableAnimations: true));
    await tester.pump();
    expect(find.text('a:0'), findsNothing);
    expect(find.text('b:0'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('gizli sekme odak tutamaz; geçişte sönen sekmeye dokunulamaz', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget host(int index) => MaterialApp(
          home: Scaffold(
            body: FadeThroughIndexedStack(
              index: index,
              children: [
                TextField(focusNode: focus),
                const _Counter('b'),
              ],
            ),
          ),
        );

    await tester.pumpWidget(host(0));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.pumpWidget(host(1));
    await tester.pump();
    expect(focus.hasFocus, isFalse); // sekme değişince odak (ve klavye) bırakılır
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isFalse); // gizliyken odak alamaz

    // Geçiş ortasında: yeni sekme dokunulabilir, sönen sekme dokunulamaz
    await tester.pumpWidget(host(0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('b:0').hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });
}
