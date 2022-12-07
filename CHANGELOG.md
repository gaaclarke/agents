# 0.2.0

* Converted `Agent.error` to return an `AgentError` class.
* Started handling errors in `Agent.create`.

# 0.1.0

* Adds `Agent.error` and `Agent.resetError`.
* Adds protection from talking to killed Agents.
* Updated naming of methods based on feedback:
  - deref -> read
  - query -> **eliminated for read**
  - create -> **eliminated for new create**
  - createWithResult -> create
  - send -> update

# 0.0.7

* Adds `Agent.createWithResult`.

# 0.0.6

* Switched implementation to use SendPort API instead of completers so that
  Agents can be sent across Isolates.

# 0.0.5

* Fixes `query` calls where the return types differ from the agent type.

# 0.0.4

* Adds `query` method.

# 0.0.3

* Makes Agents null-safe.

# 0.0.2

* Updates README.md
* Adds `exit()` method.

# 0.0.1

* Initial import.
