import 'package:isolate_agents/isolate_agents.dart';
import 'package:test/test.dart';

void main() {
  test('simple', () async {
    Agent<int> agent = await Agent.create(1);
    agent.send((x) => x + 1);
    expect(2, await agent.deref());
    agent.kill();
  });

  test('exit', () async {
    Agent<int> agent = await Agent.create(1);
    agent.send((x) => x + 1);
    expect(2, await agent.exit());
  });

  test('query', () async {
    final Agent<int> agent = await Agent.create(1);
    final String value = await agent.query((state) => String.fromCharCode(65 + state));
    expect('B', value);
  });
}