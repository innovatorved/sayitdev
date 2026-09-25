#!/usr/bin/env python3
"""MCP server fixture that emits server->client noise before every response.

Before answering each request it writes logging notifications (what FastMCP's
``ctx.info()`` emits as ``notifications/message``) and a server->client
``ping`` request to stdout. A client without JSON-RPC id correlation (#217)
parses the first noise line as the response, fails, and stays off-by-one
forever; a correct client skips the notifications, answers the ping, and
returns the response whose id matches its request.
"""

import json
import sys

_ping_id = 9000


def send(msg):
    sys.stdout.write(json.dumps(msg, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def respond(msg_id, result):
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def noise(stage):
    """Interleave notifications and a ping request before the real response."""
    global _ping_id
    send({
        "jsonrpc": "2.0",
        "method": "notifications/message",
        "params": {"level": "info", "logger": "noisy", "data": f"{stage}: starting"},
    })
    _ping_id += 1
    send({"jsonrpc": "2.0", "id": _ping_id, "method": "ping"})
    send({
        "jsonrpc": "2.0",
        "method": "notifications/message",
        "params": {"level": "debug", "logger": "noisy", "data": f"{stage}: almost done"},
    })


def handle(msg):
    method = msg.get("method")
    msg_id = msg.get("id")

    if method is None:
        # A response to one of our server->client requests (the ping reply).
        return
    if method == "initialize":
        noise("initialize")
        respond(msg_id, {
            "protocolVersion": "2025-06-18",
            "capabilities": {"tools": {}, "logging": {}},
            "serverInfo": {"name": "noisy-mcp", "version": "1.0.0"},
        })
    elif method == "notifications/initialized":
        return
    elif method == "tools/list":
        noise("tools/list")
        respond(msg_id, {
            "tools": [{
                "name": "marker",
                "description": "Return a fixed marker proving the tool response arrived.",
                "inputSchema": {
                    "type": "object",
                    "properties": {},
                },
            }]
        })
    elif method == "tools/call":
        noise("tools/call")
        respond(msg_id, {
            "content": [{"type": "text", "text": "20501"}],
            "isError": False,
        })


def main():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        handle(json.loads(line))


if __name__ == "__main__":
    main()
