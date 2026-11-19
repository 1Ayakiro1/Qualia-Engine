#!/usr/bin/env python3
"""Dependency diagnostics work even before Qt/NumPy are available."""
import sys

if __name__ == "__main__":
    try:
        from eternal_cortex.app import main
    except ImportError as error:
        print(f"EternalCortex dependency unavailable: {error}. Install the module's "
              "requirements.txt using the same Python interpreter, or use the bundled build.",
              file=sys.stderr, flush=True)
        raise SystemExit(2)
    raise SystemExit(main())
