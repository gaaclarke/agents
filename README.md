# Isolate Agents

## Description

Isolate Agents adds a new class, `Agent`, which is a proper implementation of
the [Actor model](https://en.wikipedia.org/wiki/Actor_model) for Dart.  Where
Isolates have no mechanism for communication, `Agent`s do. It is inspired by
Clojure's [`agents`](https://clojuredocs.org/clojure.core/agent).

## Example usage

```dart
import 'package:isolate_agents/isolate_agents.dart';

void main() async {
  Agent<int> agent = await Agent.create(1);
  // The following add operation is executed in the Agent's isolate.
  agent.send((int? x) => x! + 1);
  assert(2 == await agent.exit());
}
```

## Why?

After writing Dart code for a couple of years I realized I was writing the same
code over and over again in order to be able to use Isolates.  Isolates don't
fully implement the Actor model so a handshake of
[`SendPort`](https://api.dart.dev/stable/2.18.2/dart-isolate/SendPort-class.html)
and a protocol needs to be devised for each non-trivial usage of Isolates.
`Agent`s factor all that logic into a reusable package, eliminating the
`SendPort` handshake and standardizing the protocol.
