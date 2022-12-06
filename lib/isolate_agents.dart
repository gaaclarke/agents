import 'dart:async';
import 'dart:isolate';

class _Command {
  final _Commands code;
  final SendPort? sendPort;
  final Object? arg0;

  _Command(this.code, {this.sendPort, this.arg0});
}

class _Result<T> {
  _Result({required this.value, required this.error});

  final T value;
  final Object? error;
}

enum _Commands {
  init,
  exec,
  exit,
  query,
  getError,
  resetError,
}

void _isolateMain<T>(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();
  sendPort.send(_Command(_Commands.init, arg0: receivePort.sendPort));
  late T state;
  Object? error;
  receivePort.listen((value) {
    _Command command = value;
    if (command.code == _Commands.init) {
      state = (command.arg0 as T Function())();
    } else if (command.code == _Commands.exec) {
      try {
        final func = command.arg0 as T Function(T);
        state = func(state);
      } catch (e) {
        error = e;
      }
      command.sendPort!.send(null);
    } else if (command.code == _Commands.exit) {
      Isolate.exit(command.sendPort!, state);
    } else if (command.code == _Commands.query) {
      Object? result;
      try {
        Object? Function(T) func = command.arg0 as Object? Function(T);
        result = func(state);
      } catch (e) {
        error = e;
      }
      if (error != null) {
        command.sendPort!.send(_Result<dynamic>(value: null, error: error));
      } else {
        command.sendPort!.send(_Result<dynamic>(value: result, error: null));
      }
    } else if (command.code == _Commands.getError) {
      command.sendPort!.send(error);
    } else if (command.code == _Commands.resetError) {
      error = null;
      command.sendPort!.send(null);
    }
  });
}

/// State that lives on an isolate.
///
/// This is a convenient wrapper around having an isolate, dart ports and
/// managing some state that is edited on the isolate.
class Agent<T> {
  Isolate? _isolate;
  final SendPort _sendPort;

  Agent._(this._isolate, this._sendPort);

  /// Creates the [Agent] whose initial state is the result of executing [func].
  static Future<Agent<T>> create<T>(T Function() func) async {
    ReceivePort receivePort = ReceivePort();
    Isolate isolate =
        await Isolate.spawn(_isolateMain<T>, receivePort.sendPort);
    final completer = Completer<SendPort>();
    receivePort.listen((value) {
      _Command command = value;
      if (command.code == _Commands.init) {
        completer.complete(command.arg0 as SendPort);
      }
    });
    SendPort sendPort = await completer.future;
    sendPort.send(_Command(_Commands.init, arg0: func));
    return Agent<T>._(isolate, sendPort);
  }

  /// Send a closure [func] that will be executed in the [Agent]'s [Isolate].
  /// The result of [func] is assigned to the value of the [Agent].
  Future<void> update(T Function(T) func) async {
    if (_isolate == null) {
      throw StateError('Agent has been killed.');
    }
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(
        _Command(_Commands.exec, sendPort: receivePort.sendPort, arg0: func));
    return receivePort.first;
  }

  /// Reads the [Agent]'s state with a closure.
  ///
  /// [query] is useful for reading a portion of the state held by the agent to
  /// avoid the overhead of reading the whole state.
  Future<U> read<U>({U Function(T state)? query}) async {
    if (_isolate == null) {
      throw StateError('Agent has been killed.');
    }
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(_Command(_Commands.query,
        sendPort: receivePort.sendPort, arg0: query ?? (x) => x));
    final _Result<dynamic> result = await receivePort.first;
    if (result.error != null) {
      throw result.error!;
    } else {
      return result.value as U;
    }
  }

  /// Kills the agent and returns its state value. This is faster than calling
  /// [deref] then [kill] since Dart will elide the copy of the result.
  Future<T> exit() async {
    // TODO(gaaclarke): Add an exit listener to the isolate so the state of all
    // Agents can be cleared out.
    if (_isolate == null) {
      throw StateError('Agent has been killed.');
    }
    _isolate = null;
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(_Command(_Commands.exit, sendPort: receivePort.sendPort));
    dynamic value = await receivePort.first;
    return value as T;
  }

  /// Gets the current error associated with the Agent, null if there is none.
  ///
  /// See also:
  ///   * [resetError]
  Future<Object?> get error async {
    if (_isolate == null) {
      throw StateError('Agent has been killed.');
    }
    ReceivePort receivePort = ReceivePort();
    _sendPort
        .send(_Command(_Commands.getError, sendPort: receivePort.sendPort));
    dynamic value = await receivePort.first;
    return value as Object?;
  }

  /// Resets the [Agent] so it can start receiving messages again.
  Future<void> resetError() async {
    if (_isolate == null) {
      throw StateError('Agent has been killed.');
    }
    ReceivePort receivePort = ReceivePort();
    _sendPort
        .send(_Command(_Commands.resetError, sendPort: receivePort.sendPort));
    await receivePort.first;
  }

  /// Kills the [Agent]'s isolate. Any interaction with the Agent after this will
  /// result in a [StateError].
  void kill() {
    _isolate = null;
  }
}
