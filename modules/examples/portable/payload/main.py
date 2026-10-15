"""One source payload for desktop ABIs; requires Python 3 on PATH.

Default: stdio. For TCP, add transport to the manifest and launch arguments
["--tcp", "127.0.0.1", "43125"] with the same host/port. This is a trusted
local-process example, not an authenticated or encrypted network service.
"""
import json
import socket
import sys

MAX_FRAME_BYTES = 1024 * 1024


def run(reader, writer):
    def send(message):
        frame = json.dumps(message, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        if len(frame) > MAX_FRAME_BYTES:
            raise ValueError("Frame too large")
        writer.write(frame + b"\n")
        writer.flush()

    send({"type": "ready", "protocol": 1})
    while True:
        frame = reader.readline(MAX_FRAME_BYTES + 2)
        if not frame:
            return
        if not frame.endswith(b"\n") or len(frame) > MAX_FRAME_BYTES + 1:
            raise ValueError("Frame too large or unterminated")
        message = json.loads(frame)
        if message["type"] == "stop":
            return
        if message["type"] == "input":
            value = message["value"]
            send({"type": "state", "values": {"result": value}})
            send({"type": "output", "port": "output", "value": value, "hops": message["hops"]})


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--tcp":
        with socket.create_server((sys.argv[2], int(sys.argv[3]))) as server:
            connection, _ = server.accept()
            with connection, connection.makefile("rb") as reader, connection.makefile("wb") as writer:
                run(reader, writer)
    else:
        run(sys.stdin.buffer, sys.stdout.buffer)
