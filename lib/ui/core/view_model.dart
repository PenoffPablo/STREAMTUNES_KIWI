import 'package:flutter/foundation.dart';

/// Clase base de todos los ViewModels.
///
/// Resuelve un problema de ciclo de vida típico de MVVM con `async`: si una
/// operación termina (`await`) después de que la View hizo `dispose()` del
/// ViewModel, llamar a `notifyListeners()` lanza
/// "A ChangeNotifier was used after being disposed". Acá se ignora en forma
/// segura y se expone [isDisposed] para cortar trabajo innecesario.
abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
