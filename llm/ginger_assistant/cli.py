"""Terminal client for the optional local Ginger assistant."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

from .provider import LlamaCppProvider, ProviderError
from .runtime import Assistant

DEFAULT_SYSTEM_PROMPT = (
    "You are Ginger, a helpful local-first assistant running on GingerOS. "
    "Be concise, explain uncertainty, and never claim to have performed an action "
    unless a permitted tool actually performed it."
)


def core_status(command: str = "/usr/bin/ginger-core") -> dict:
    """Read status through the existing read-only Core CLI; no shell is involved."""
    try:
        result = subprocess.run(
            [command], stdin=subprocess.DEVNULL, capture_output=True, text=True,
            timeout=4, check=False, env={"PATH": "/usr/bin:/bin", "LANG": "C"},
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError(f"Ginger Core is unavailable: {exc}") from exc
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "Ginger Core returned an error")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError("Ginger Core returned invalid JSON") from exc
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise RuntimeError("Unsupported Ginger Core response")
    return payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="ginger-assistant", description="Local Ginger assistant (llama.cpp)")
    parser.add_argument("--url", default=os.environ.get("GINGER_LLAMA_URL", "http://127.0.0.1:8080"))
    parser.add_argument("--model", default=os.environ.get("GINGER_LLAMA_MODEL", "local"))
    parser.add_argument("--timeout", type=float, default=float(os.environ.get("GINGER_LLAMA_TIMEOUT", "120")))
    args = parser.parse_args(argv)
    provider = LlamaCppProvider(args.url, args.model, args.timeout)
    if not provider.health():
        print(
            f"llama.cpp server is unavailable at {args.url}. Start llama-server separately; "
            "the assistant does not download models or start inference services automatically.",
            file=sys.stderr,
        )
        return 1

    assistant = Assistant(provider, DEFAULT_SYSTEM_PROMPT)
    print("Ginger Assistant — llama.cpp backend. Commands: /status, /reset, /quit")
    while True:
        try:
            line = input("\nyou> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            return 0
        if not line:
            continue
        if line in {"/quit", "/exit"}:
            print("Goodbye.")
            return 0
        if line == "/reset":
            assistant.reset()
            print("Conversation cleared.")
            continue
        if line == "/status":
            try:
                print(json.dumps(core_status(), indent=2, sort_keys=True))
            except RuntimeError as exc:
                print(f"status unavailable: {exc}", file=sys.stderr)
            continue
        try:
            print(f"ginger> {assistant.ask(line)}")
        except (ProviderError, ValueError) as exc:
            print(f"assistant error: {exc}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
