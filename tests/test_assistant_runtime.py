import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

from llm.ginger_assistant.provider import LlamaCppProvider, ProviderError
from llm.ginger_assistant.runtime import Assistant


class FakeProvider:
    def __init__(self):
        self.calls = []

    def complete(self, messages):
        self.calls.append(list(messages))
        return "Local response"


def test_conversation_keeps_bounded_history_and_system_prompt():
    provider = FakeProvider()
    assistant = Assistant(provider, "system", max_history=4)
    assert assistant.ask("one") == "Local response"
    assistant.ask("two")
    assistant.ask("three")
    assert assistant.messages[0] == {"role": "system", "content": "system"}
    assert len(assistant.messages) <= 5
    assistant.reset()
    assert assistant.messages == [{"role": "system", "content": "system"}]


def test_empty_prompt_rejected():
    assistant = Assistant(FakeProvider(), "system")
    with pytest.raises(ValueError):
        assistant.ask("  ")


def test_failed_provider_does_not_leave_orphan_user_message():
    class Broken:
        def complete(self, _messages):
            raise ProviderError("offline")
    assistant = Assistant(Broken(), "system")
    with pytest.raises(ProviderError):
        assistant.ask("hello")
    assert assistant.messages == [{"role": "system", "content": "system"}]


def test_llama_cpp_openai_compatible_api():
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")

        def do_POST(self):
            length = int(self.headers["Content-Length"])
            payload = json.loads(self.rfile.read(length))
            assert payload["stream"] is False
            body = json.dumps({"choices": [{"message": {"content": "hello from llama.cpp"}}]}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        provider = LlamaCppProvider(f"http://127.0.0.1:{server.server_port}")
        assert provider.health()
        assert provider.complete([{"role": "user", "content": "hi"}]) == "hello from llama.cpp"
    finally:
        server.shutdown()
        thread.join(timeout=2)
        server.server_close()
