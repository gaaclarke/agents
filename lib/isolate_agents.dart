import 'dart:isolate';
import 'dart:async';
import 'dart:collection' show Queue;

class _Command {
  final _Commands code;
  final Object? arg0;

  _Command(this.code, {Object? this.arg0});
}

enum _Commands {
  Init,
  Exec,
  Ack,
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
      state = command.arg0 as T;
    } else if (command.code == _Commands.Exec) {
      final func = command.arg0 as T Function(T);
      state = func(state);
      sendPort.send(_Command(_Commands.Ack));
    } else if (command.code == _Commands.Deref) {
      sendPort.send(_Command(_Commands.Deref, arg0: state));
    } else if (command.code == _Commands.Exit) {
      Isolate.exit(sendPort, _Command(_Commands.Deref, arg0: state));
    } else if (command.code == _Commands.Query) {
      Object? Function(T) func = command.arg0 as Object? Function(T);
      sendPort.send(_Command(_Commands.Query, arg0: func(state)));
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
  final ReceivePort _receivePort;
  final Queue<Completer<void>> _completers;
  final Queue<Completer<Object?>> _derefCompleters;

  Agent._(this._isolate, this._sendPort, this._receivePort, this._completers,
      this._derefCompleters);

  static Future<Agent<T>> create<T>(T initialState) async {
    ReceivePort receivePort = ReceivePort();
    Isolate isolate =
        await Isolate.spawn(_isolateMain<T>, receivePort.sendPort);
    final completer = Completer<SendPort>();
    Queue<Completer<void>> completers = Queue<Completer<void>>();
    Queue<Completer<Object?>> derefCompleters = Queue<Completer<Object?>>();
    receivePort.listen((value) {
      _Command command = value;
      if (command.code == _Commands.Init) {
        completer.complete(command.arg0 as SendPort);
      } else if (command.code == _Commands.Ack) {
        completers.removeLast().complete();
      } else if (command.code == _Commands.Deref) {
        derefCompleters.removeLast().complete(command.arg0 as T);
      } else if (command.code == _Commands.Query) {
        derefCompleters.removeLast().complete(command.arg0);
      }
    });
    SendPort sendPort = await completer.future;
    sendPort.send(_Command(_Commands.Init, arg0: initialState));
    return Agent<T>._(
        isolate, sendPort, receivePort, completers, derefCompleters);
  }

  /// Send a closure that will be executed in the Agent's isolate.
  Future<void> send(T Function(T) func) async {
    _sendPort.send(_Command(_Commands.Exec, arg0: func));
    Completer<void> completer = Completer<void>();
    _completers.addFirst(completer);
    return completer.future;
  }

  /// Query the current value of the agent.
  Future<T> deref() {
    _sendPort.send(_Command(_Commands.Deref));
    Completer<T> completer = Completer<T>();
    _derefCompleters.addFirst(completer);
    return completer.future;
  }

  /// Queries the [Agent]'s state with a closure.
  ///
  /// This is useful for reading a portion of the state held by the agent to
  /// avoid the overhead of reading the whole state.
  Future<U> query<U>(U Function(T state) queryFunc) {
    _sendPort.send(_Command(_Commands.Query, arg0: queryFunc));
    Completer<U> completer = Completer<U>();
    _derefCompleters.addFirst(completer);
    return completer.future;
  }

  /// Kills the agent and returns its state value. This is faster thank calling
  /// [deref] then [kill] since Dart will elide the copy of the result.
  Future<T> exit() {
    _sendPort.send(_Command(_Commands.Exit));
    Completer<T> completer = Completer<T>();
    _derefCompleters.addFirst(completer);
    return completer.future;
  }

  /// Kills the agent's isolate.
  void kill() {
    _receivePort.close();
    _isolate.kill();
  }
}
