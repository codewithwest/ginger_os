# Phase 4A: Ginger Assistant Runtime

## Goal

Introduce a small, optional, UI-neutral conversation runtime. The initial inference backend is **llama.cpp** using its OpenAI-compatible `llama-server` HTTP API. Ollama is not part of this runtime.

## Components

- `llm/ginger_assistant/runtime.py`: provider-independent conversation loop and bounded in-memory history.
- `llm/ginger_assistant/provider.py`: provider protocol and standard-library llama.cpp HTTP adapter.
- `llm/ginger_assistant/cli.py`: terminal client.
- `/status`: explicit read-only call to the existing `ginger-core` CLI. No arbitrary shell or model-triggered tool execution is exposed.
- `/reset`: clear current in-memory conversation; `/quit`: exit.

## Running

Start a llama.cpp server separately, for example:

```sh
llama-server -m /path/to/model.gguf --host 127.0.0.1 --port 8080 -c 4096
```

Then from the repository root:

```sh
python3 -m llm.ginger_assistant.cli
```

Configuration:

- `GINGER_LLAMA_URL` (default `http://127.0.0.1:8080`)
- `GINGER_LLAMA_MODEL` (default `local`; llama.cpp commonly ignores or accepts this compatibility field)
- `GINGER_LLAMA_TIMEOUT` (default 120 seconds)

The assistant does not download model weights, start llama-server, install GPU drivers, or start at boot. Bind llama-server to loopback unless remote access has been deliberately secured. Choose model and context sizes according to available memory; the 16 GB / 2+ core profile is a reference target, not a minimum requirement.

## Security and scope

- The runtime uses Python's standard library only.
- No shell tool, filesystem write tool, network browsing tool, or privileged action is exposed to model output.
- Core status is a user-invoked command and calls the existing read-only Core CLI with a fixed executable path and argument vector (no shell).
- Conversation history is in memory only and bounded; there is no persistent memory in this increment.
- The UI is not coupled to the runtime; a future client can consume a stable service/API without replacing the provider layer.

## Validation

Run `python3 tests/test_assistant_runtime.py`. The tests use a fake provider and a local HTTP test server; they do not require llama.cpp, a model download, Ollama, ChromaDB, or a GPU.

## Next increments

1. 4B: add streaming responses and robust llama-server model/health discovery.
2. 4C: define a typed, permissioned tool registry with explicit user confirmation before any state-changing operation.
3. 4D: optional local memory with retention and deletion controls.
4. 4E: publish a UI-neutral local client contract.
