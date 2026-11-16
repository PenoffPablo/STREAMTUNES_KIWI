import 'dart:async';

/// Emite un valor recién cuando pasaron [duration] sin recibir otro.
///
/// Uso típico: búsqueda mientras el usuario escribe. Si tipea "rock" rápido,
/// en lugar de 4 consultas ("r", "ro", "roc", "rock") se hace una sola.
StreamTransformer<T, T> debounce<T>(Duration duration) {
  return StreamTransformer<T, T>.fromBind((source) {
    Timer? timer;
    late StreamController<T> controller;
    StreamSubscription<T>? sub;

    controller = StreamController<T>(
      sync: true,
      onListen: () {
        sub = source.listen(
          (value) {
            timer?.cancel();
            timer = Timer(duration, () => controller.add(value));
          },
          onError: controller.addError,
          onDone: () {
            timer?.cancel();
            controller.close();
          },
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        timer?.cancel();
        return sub?.cancel();
      },
    );
    return controller.stream;
  });
}
