"""Conversation runtime independent of terminal or graphical presentation."""
from __future__ import annotations

from .provider import ChatProvider


class Assistant:
    def __init__(self, provider: ChatProvider, system_prompt: str, max_history: int = 20):
        if max_history < 2:
            raise ValueError("max_history must be at least 2")
        self.provider = provider
        self.system_prompt = system_prompt
        self.max_history = max_history
        self.messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]

    def ask(self, prompt: str) -> str:
        prompt = prompt.strip()
        if not prompt:
            raise ValueError("prompt must not be empty")
        self.messages.append({"role": "user", "content": prompt})
        try:
            answer = self.provider.complete(self.messages)
        except Exception:
            self.messages.pop()
            raise
        self.messages.append({"role": "assistant", "content": answer})
        # Keep the system prompt and a bounded number of recent conversation turns.
        self.messages = [self.messages[0], *self.messages[-self.max_history:]]
        return answer

    def reset(self) -> None:
        self.messages = [{"role": "system", "content": self.system_prompt}]
