import 'dart:isolate';
import 'dart:async';

class _Command {
  final _Commands code;
  final SendPort? sendPort;
  final Object? arg0;

  _Command(this.code, {SendPort? this.sendPort, Object? this.arg0});
}

enum _Commands {
  Init,
  Exec,
  Deref,
  Exit,
  Query,
}

void _isolateMain<T>(SendPort sendPort) {
  ReceivePort receivePort = ReceivePort();
  sendPort.send(_Command(_Commands.Init, arg0: receivePort.sendPort));
  late T state;
  receivePort.listen((value) {
    _Command command = value;
    if (command.code == _Commands.Init) {
      state = (command.arg0 as T Function())();
    } else if (command.code == _Commands.Exec) {
      final func = command.arg0 as T Function(T);
      state = func(state);
      command.sendPort!.send(null);
    } else if (command.code == _Commands.Deref) {
      command.sendPort!.send(state);
    } else if (command.code == _Commands.Exit) {
      Isolate.exit(command.sendPort!, state);
    } else if (command.code == _Commands.Query) {
      Object? Function(T) func = command.arg0 as Object? Function(T);
      command.sendPort!.send(func(state));
    }
  });
}

/// State that lives on an isolate.
///
/// This is a convenient wrapper around having an isolate, dart ports and
/// managing some state that is edited on the isolate.
class Agent<T> {
  final Isolate _isolate;
  final SendPort _sendPort;

  Agent._(this._isolate, this._sendPort);

  /// Creates the [Agent] whose initial state is the result of executing [func].
  static Future<Agent<T>> createWithResult<T>(T Function() func) async {
    ReceivePort receivePort = ReceivePort();
    Isolate isolate =
        await Isolate.spawn(_isolateMain<T>, receivePort.sendPort);
    final completer = Completer<SendPort>();
    receivePort.listen((value) {
      _Command command = value;
      if (command.code == _Commands.Init) {
        completer.complete(command.arg0 as SendPort);
      }
    });
    SendPort sendPort = await completer.future;
    sendPort.send(_Command(_Commands.Init, arg0: func));
    return Agent<T>._(isolate, sendPort);
  }

  /// Create the [Agent] with the initial value being [initialState].
  ///
  /// Note: It may be faster to use [createWithResult] since it avoids
  /// sending the [initialState].
  static Future<Agent<T>> create<T>(T initialState) async {
    return createWithResult(() => initialState);
  }

  /// Send a closure that will be executed in the Agent's isolate.
  Future<void> send(T Function(T) func) async {
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(
        _Command(_Commands.Exec, sendPort: receivePort.sendPort, arg0: func));
    return receivePort.first;
  }

  /// Query the current value of the agent.
  Future<T> deref() async {
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(_Command(_Commands.Deref, sendPort: receivePort.sendPort));
    dynamic value = await receivePort.first;
    return value as T;
  }

  /// Queries the [Agent]'s state with a closure.
  ///
  /// This is useful for reading a portion of the state held by the agent to
  /// avoid the overhead of reading the whole state.
  Future<U> query<U>(U Function(T state) queryFunc) async {
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(_Command(_Commands.Query,
        sendPort: receivePort.sendPort, arg0: queryFunc));
    dynamic value = await receivePort.first;
    return value as U;
  }

  /// Kills the agent and returns its state value. This is faster than calling
  /// [deref] then [kill] since Dart will elide the copy of the result.
  Future<T> exit() async {
    ReceivePort receivePort = ReceivePort();
    _sendPort.send(_Command(_Commands.Exit, sendPort: receivePort.sendPort));
    dynamic value = await receivePort.first;
    return value as T;
  }

  /// Kills the agent's isolate.
  void kill() {
    _isolate.kill();
  }
}
