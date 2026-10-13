import pathlib
import sys
import json
import ctypes

root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / "runtime/site-packages"))
import numpy as np

library = ctypes.CDLL(str(root / "lib/libqualia_math.so"))
library.qualia_rms.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.c_int]
library.qualia_rms.restype = ctypes.c_double
library.qualia_square.argtypes = [ctypes.c_double]
library.qualia_square.restype = ctypes.c_double

def send(message):
    print(json.dumps(message, allow_nan=False, separators=(",", ":")), flush=True)

send({"type": "ready", "protocol": 1, "requires": ["port-schemas-v1"]})
calls = 0
for line in sys.stdin:
    message = json.loads(line)
    if message["type"] == "event" and message["id"] == "run":
        values = np.array([1.0, 2.0, 3.0, 4.0], dtype=np.float64)
        calls += 1
        mean = float(np.mean(values))
        rms = library.qualia_rms(values.ctypes.data_as(ctypes.POINTER(ctypes.c_double)), values.size)
        assert np.isclose(rms, np.sqrt(np.mean(values * values)))
        result = {"mean": mean, "rms": rms, "energy": library.qualia_square(mean), "pythonCalls": calls}
        send({"type": "state", "values": {"result": result, "numpyVersion": np.__version__}})
        send({"type": "output", "port": "output", "value": result, "hops": 32})
