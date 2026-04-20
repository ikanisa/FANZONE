import 'dart:async';

const matchPollInterval = Duration(seconds: 15);

/// Generic polling stream that emits a value from [loader] every
/// [matchPollInterval]. Used by live/realtime match gateways.
Stream<T> pollMatchStream<T>(Future<T> Function() loader) {
  final controller = StreamController<T>();
  Timer? timer;
  var loading = false;

  Future<void> emit() async {
    if (loading || controller.isClosed) return;
    loading = true;
    try {
      controller.add(await loader());
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    } finally {
      loading = false;
    }
  }

  controller.onListen = () {
    unawaited(emit());
    timer = Timer.periodic(matchPollInterval, (_) => unawaited(emit()));
  };
  controller.onCancel = () async {
    timer?.cancel();
    timer = null;
    await controller.close();
  };

  return controller.stream;
}
