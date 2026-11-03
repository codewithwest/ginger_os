# GingerOS Headless BLFS

This directory is an optional post-LFS layer. It is deliberately separate from
\`lfs/\`: the completed LFS build is the stable base and must not be modified
to add the assistant or its inference backend.

## Scope

- Build and install upstream **llama.cpp** (the \`llama-server\` executable).
- Install the UI-neutral Ginger assistant runtime from \`llm/ginger_assistant\`.
- Keep model files and local configuration outside the source tree.
- Leave both inference and assistant startup under explicit administrator/user
  control. Nothing here enables a service or starts a model at boot.

Ollama is not used.

## Build llama.cpp

Build dependencies are CMake, a C/C++ toolchain, and (optionally) Ninja.
Check out a reviewed llama.cpp release/tag first, then pass that checkout to:

\`\`\`sh
blfs/headless/build-llama-cpp.sh /path/to/llama.cpp
\`\`\`

For a reproducible build, record the exact upstream tag/commit used. CPU is
the portable default. GPU backends are opt-in build variants and are not
required. The build script accepts a source checkout and does not download
code or silently select a moving upstream revision.

## Install the assistant runtime

From the repository root:

\`\`\`sh
sudo blfs/headless/install-assistant.sh "$PWD"
\`\`\`

This installs the Python standard-library-only runtime under
\`/opt/ginger/assistant\`, a launcher at \`/usr/bin/ginger-assistant\`, and a
configuration file at \`/etc/ginger/assistant.conf\` (created only if absent).
It does not install Python, llama.cpp, model weights, or alter LFS files.

Edit \`/etc/ginger/assistant.conf\` to set:

- \`GINGER_LLAMA_URL\` — default \`http://127.0.0.1:8080\`
- \`GINGER_LLAMA_MODEL\` — default \`local\`
- \`GINGER_LLAMA_TIMEOUT\` — default \`120\` seconds

A running \`llama-server\` must be started separately by the operator, bound
to loopback unless remote access is deliberately designed and secured.

## Operational boundaries

- No systemd unit is enabled or started by these scripts.
- No model is downloaded, selected, or started automatically.
- No daemon, network listener, or boot-time AI workload is installed.
- The assistant's \`/status\` command uses the already-installed read-only
  Ginger Core CLI when available.
- Model output cannot execute shell commands. Future tools must use an
  explicit allowlist and confirmation for state-changing operations.
- Conversation history is process-local and bounded; persistent memory is
  not part of this foundation.

The existing LFS tree remains the authoritative base. Future BLFS work should
add optional packages and integrations here rather than reopening LFS recipes.
