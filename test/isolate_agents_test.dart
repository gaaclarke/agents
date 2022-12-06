import 'dart:isolate';

import 'package:isolate_agents/isolate_agents.dart';
import 'package:test/test.dart';

void main() {
  test('simple', () async {
    Agent<int> agent = await Agent.create(() => 1);
    agent.update((x) => x + 1);
    expect(2, await agent.read());
    agent.kill();
  });

  test('exit', () async {
    Agent<int> agent = await Agent.create(() => 1);
    agent.update((x) => x + 1);
    expect(2, await agent.exit());
  });

  test('query', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    final String value =
        await agent.read(query: (state) => String.fromCharCode(65 + state));
    expect('B', value);
  });

  test('hop agents', () async {
    final Agent<int> agent1 = await Agent.create(() => 1);
    final Agent<int> agent2 = await Agent.create(() => 2);
    ReceivePort receivePort = ReceivePort();
    SendPort sendPort = receivePort.sendPort;
    agent1.update((x) {
      agent2.update((y) {
        sendPort.send(x + y);
        return y;
      });
      return x;
    });

    int result = (await receivePort.first) as int;
    expect(3, result);
  });

  test('error reset', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.update((_) {
      throw Exception('test');
    });
    expect(await agent.error, isNotNull);
    agent.resetError();
    expect(await agent.error, isNull);
  });

  test('query with error', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.update((_) {
      throw Exception('test');
    });
    expect(() async {
      return await agent.read();
    }, throwsA(isA<Exception>()));
  });

  test('deref after kill', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.kill();
    expect(() async {
      await agent.read();
    }, throwsA(isA<StateError>()));
  });

  test('update after kill', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.kill();
    expect(() async {
      await agent.update((x) => x);
    }, throwsA(isA<StateError>()));
  });

  test('query after kill', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.kill();
    expect(() async {
      await agent.read();
    }, throwsA(isA<StateError>()));
  });

  test('exit after kill', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.kill();
    expect(() async {
      await agent.exit();
    }, throwsA(isA<StateError>()));
  });

  test('err after kill', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.kill();
    expect(() async {
      await agent.error;
    }, throwsA(isA<StateError>()));
  });

  test('reset error after kill', () async {
    final Agent<int> agent = await Agent.create(() => 1);
    agent.kill();
    expect(() async {
      await agent.resetError();
    }, throwsA(isA<StateError>()));
  });
}
