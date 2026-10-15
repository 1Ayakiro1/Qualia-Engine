"""Same protocol as C++/Go. Stdout is exclusively flushed NDJSON."""
import json
import sys


def send(message):
    print(json.dumps(message, separators=(",", ":"), allow_nan=False), flush=True)


send({"type": "ready", "protocol": 1, "requires": ["port-schemas-v1"]})
parameters = {}
for line in sys.stdin:
    if len(line.encode("utf-8")) > 1024 * 1024 + 1:
        break
    message = json.loads(line)
    kind = message.get("type")
    if kind in ("init", "parameters"):
        parameters = message.get("parameters" if kind == "init" else "values", {})
        send({"type": "state", "values": {"parameterKeys": sorted(parameters)}})
    elif kind == "input" and message.get("port") == "input":
        result = message["value"] * parameters.get("gain", 2)
        send({"type": "state", "values": {"result": result}})
        send({"type": "output", "port": "output", "value": result, "hops": message["hops"]})
    elif kind == "event" and message.get("id") == "run":
        result = parameters.get("sample", 3) * parameters.get("gain", 2)
        send({"type": "state", "values": {"result": result}})
        send({"type": "output", "port": "output", "value": result, "hops": 32})
