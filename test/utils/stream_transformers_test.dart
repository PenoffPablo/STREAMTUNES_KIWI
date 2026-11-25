import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/utils/stream_transformers.dart';

void main() {
  test('debounce emite solo el último valor de una ráfaga', () async {
    final controller = StreamController<String>();
    final out = <String>[];
    final sub = controller.stream.transform(debounce(const Duration(milliseconds: 30))).listen(out.add);
    for (final q in ['r', 'ro', 'roc', 'rock']) {
      controller.add(q);
    }
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(out, ['rock']);
    await sub.cancel();
    await controller.close();
  });
}
