"""Inference provider contract and llama.cpp HTTP implementation.

The runtime uses only Python's standard library. llama-server exposes an
OpenAI-compatible endpoint; no Ollama or LangChain dependency is required.
"""
from __future__ import annotations

import json
from typing import Protocol
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class ProviderError(RuntimeError):
    """Raised when an inference provider cannot complete a request."""


class ChatProvider(Protocol):
    def complete(self, messages: list[dict[str, str]]) -> str: ...


class LlamaCppProvider:
    """Client for llama.cpp's OpenAI-compatible /v1/chat/completions API."""

    def __init__(self, base_url: str, model: str = "local", timeout: float = 120.0):
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.timeout = timeout

    def health(self) -> bool:
        request = Request(f"{self.base_url}/health", method="GET")
        try:
            with urlopen(request, timeout=min(self.timeout, 5.0)) as response:
                return 200 <= response.status < 300
        except (HTTPError, URLError, TimeoutError, OSError):
            return False

    def complete(self, messages: list[dict[str, str]]) -> str:
        payload = json.dumps({
            "model": self.model,
            "messages": messages,
            "stream": False,
        }).encode("utf-8")
        request = Request(
            f"{self.base_url}/v1/chat/completions",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                result = json.loads(response.read(2_000_001).decode("utf-8"))
        except (HTTPError, URLError, TimeoutError, OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ProviderError(f"llama.cpp request failed: {exc}") from exc
        try:
            content = result["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as exc:
            raise ProviderError("llama.cpp returned an unexpected response") from exc
        if not isinstance(content, str):
            raise ProviderError("llama.cpp response content was not text")
        return content.strip()
