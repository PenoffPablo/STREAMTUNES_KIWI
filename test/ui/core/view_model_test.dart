import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamtunes/ui/core/view_model.dart';

class _CounterViewModel extends ViewModel {
  Future<void> slowIncrement(Future<void> gate) async {
    await gate;
    notifyListeners(); // llega DESPUÉS del dispose
  }
}

void main() {
  test('ViewModel ignora notifyListeners después de dispose (ciclo de vida)', () async {
    final vm = _CounterViewModel();
    final gate = Completer<void>();
    final pending = vm.slowIncrement(gate.future);
    vm.dispose(); // la View se cerró mientras la operación seguía en curso
    gate.complete();
    await expectLater(pending, completes); // sin "used after being disposed"
    expect(vm.isDisposed, isTrue);
  });
}
