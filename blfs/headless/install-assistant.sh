#!/bin/sh
set -eu

if [ "$#" -ne 1 ] || [ ! -d "$1/llm/ginger_assistant" ]; then
    echo "Usage: $0 /path/to/ginger_os-repository" >&2
    exit 2
fi

REPO=$(CDPATH= cd -- "$1" && pwd)
PREFIX=\${PREFIX:-/opt/ginger/assistant}
BINDIR=\${BINDIR:-/usr/bin}
SYSCONFDIR=\${SYSCONFDIR:-/etc/ginger}

install -d -m 0755 "$PREFIX/llm/ginger_assistant" "$BINDIR" "$SYSCONFDIR"
install -m 0644 "$REPO/llm/ginger_assistant/__init__.py" "$PREFIX/llm/ginger_assistant/"
install -m 0644 "$REPO/llm/ginger_assistant/cli.py" "$PREFIX/llm/ginger_assistant/"
install -m 0644 "$REPO/llm/ginger_assistant/provider.py" "$PREFIX/llm/ginger_assistant/"
install -m 0644 "$REPO/llm/ginger_assistant/runtime.py" "$PREFIX/llm/ginger_assistant/"

cat > "$BINDIR/ginger-assistant" <<EOF
#!/bin/sh
set -eu
CONFIG="$SYSCONFDIR/assistant.conf"
if [ -r "\$CONFIG" ]; then
    set -a
    . "\$CONFIG"
    set +a
fi
export PYTHONPATH="$PREFIX\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -m llm.ginger_assistant.cli "\$@"
EOF
chmod 0755 "$BINDIR/ginger-assistant"

if [ ! -e "$SYSCONFDIR/assistant.conf" ]; then
    cat > "$SYSCONFDIR/assistant.conf" <<'EOF'
# Local llama.cpp server. Start llama-server separately when needed.
GINGER_LLAMA_URL=http://127.0.0.1:8080
GINGER_LLAMA_MODEL=local
GINGER_LLAMA_TIMEOUT=120
EOF
    chmod 0644 "$SYSCONFDIR/assistant.conf"
fi

printf 'Ginger assistant installed. No service was enabled or started.\n'
