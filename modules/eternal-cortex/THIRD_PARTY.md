# Runtime dependencies

The bundled build contains third-party software and its bundled license notices
under `EternalCortex/_internal/`. Keep that directory with redistributions.

- Python 3.14: PSF License (https://docs.python.org/3/license.html).
- NumPy 2.4.6: BSD-3-Clause and bundled numerical-library notices
  (https://numpy.org/doc/stable/license.html).
- PyQtGraph 0.14.0: MIT (https://github.com/pyqtgraph/pyqtgraph).
- PySide6 / Qt 6.10.3 / Shiboken: LGPLv3/GPLv3/commercial, module-dependent
  (https://doc.qt.io/qtforpython-6/licenses.html). This application uses Qt Core,
  Gui, Widgets and SVG support, not Qt WebEngine or GPL-only add-on APIs.
- PyInstaller 6.18.0 bootloader: GPL with distribution exception
  (https://pyinstaller.org/en/stable/license.html).

Qt libraries are dynamically linked and shipped separately in `_internal/`;
users may replace them with compatible modified libraries. Dependency source
and license obligations must be reviewed before public binary redistribution;
this local development build is not a completed legal/compliance audit.
