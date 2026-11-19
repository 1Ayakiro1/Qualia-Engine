from __future__ import annotations

import argparse
from dataclasses import replace
import json
from pathlib import Path
import sys
import threading

import numpy as np
from PySide6 import QtCore, QtGui, QtWidgets as W
import pyqtgraph as pg

from . import __version__
from .recording import Recording, Spectrogram, compute_spectrum, demo, load
from .timeline import Annotation, Annotations, Timeline
from .project import export_annotations, open_project, save_project

# Match Qualia's semantic neutral ramp; color belongs to the data, not chrome.
STYLE = """
QWidget { background: #141414; color: #bdbdbd; font: 13px 'Sans Serif'; }
QToolBar, QStatusBar, QMenuBar, QMenu, QListWidget, QLineEdit, QComboBox,
QDoubleSpinBox { background: #181818; border: none; }
QToolBar { spacing: 8px; padding: 8px; }
QPushButton, QToolButton { background: #242424; border: none; border-radius: 6px; padding: 8px 12px; }
QPushButton:hover, QToolButton:hover { background: #333333; }
QPushButton:checked, QToolButton:checked { background: #444444; color: white; }
QPushButton:disabled, QToolButton:disabled { color: #656565; }
QLineEdit, QComboBox, QDoubleSpinBox { padding: 7px; border-radius: 5px; }
QListWidget::item { padding: 9px; border-radius: 5px; }
QListWidget::item:selected { background: #333333; }
QLabel#muted { color: #858585; }
QSplitter::handle { background: #242424; }
"""


class JobSignals(QtCore.QObject):
    done = QtCore.Signal(object, object)


class Job(QtCore.QRunnable):
    def __init__(self, work):
        super().__init__()
        self.work = work
        self.signals = JobSignals()

    def run(self):
        try:
            self.signals.done.emit(self.work(), None)
        except Exception as error:
            self.signals.done.emit(None, str(error))


class Protocol(QtCore.QObject):
    """Existing middle process-v1; no direct module RPC or engine secrets.

    stdin is drained on one daemon thread. Only UI events are queued, with a
    fixed bound. stdout is reserved for protocol messages, never application logs.
    """
    received = QtCore.Signal(object)

    def __init__(self):
        super().__init__()
        self.pending = 0
        self.lock = threading.Lock()

    def start(self):
        self.send({"type": "ready", "protocol": 1, "requires": []})
        threading.Thread(target=self._read, daemon=True).start()

    def send(self, value):
        try:
            sys.stdout.write(json.dumps(value, ensure_ascii=False, allow_nan=False) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, OSError):
            pass

    def _read(self):
        try:
            while True:
                line = sys.stdin.buffer.readline(1024*1024+2)
                if not line:
                    self.received.emit({"type": "stop"})
                    return
                if len(line) > 1024*1024+1 or not line.endswith(b"\n"):
                    raise ValueError("Qualia frame exceeds 1 MiB")
                message = json.loads(line)
                if not isinstance(message, dict):
                    raise ValueError("Expected a protocol object")
                if message.get("type") not in ("init", "event", "stop", "parameters"):
                    continue
                with self.lock:
                    if self.pending >= 128:
                        raise ValueError("Qualia event queue exceeded")
                    self.pending += 1
                self.received.emit(message)
        except (ValueError, OSError) as error:
            print(f"EternalCortex protocol: {error}", file=sys.stderr)
            self.received.emit({"type": "stop"})


class Studio(W.QMainWindow):
    def __init__(self, managed=False):
        super().__init__()
        self.managed = managed
        self.setWindowTitle(f"EternalCortex · {__version__}")
        self.resize(1440, 920)
        self.setMinimumSize(920, 640)
        self.source = None
        self.spectrum = None
        self.timeline = None
        self.annotations = None
        self.dirty = False
        self.busy = False
        self.curves = []
        self.annotation_regions = []
        self._visible = None
        self._setting_range = False
        self._job = None
        self.pool = QtCore.QThreadPool(self)
        self.pool.setMaxThreadCount(1)
        self._build()
        self.timer = QtCore.QTimer(self)
        self.timer.setInterval(16)
        self.timer.timeout.connect(self._tick)
        self.timer.start()
        self.protocol = None
        if managed:
            self.protocol = Protocol()
            self.protocol.received.connect(self._message)
            self.protocol.start()
        self.statusBar().showMessage("Откройте EDF / NPZ или загрузите демо. Данные остаются на этом компьютере.")

    def _button(self, text, callback, shortcut=None, checkable=False):
        button = W.QPushButton(text)
        button.setCheckable(checkable)
        button.clicked.connect(callback)
        if shortcut:
            button.setToolTip(f"{text} · {shortcut}")
            action = QtGui.QAction(self)
            action.setShortcut(QtGui.QKeySequence(shortcut))
            action.triggered.connect(lambda: button.click() if self._shortcut_allowed(shortcut) else None)
            self.addAction(action)
        return button

    def _shortcut_allowed(self, shortcut):
        # Single-key navigation must never eat typing in the annotation editor.
        focus = W.QApplication.focusWidget()
        editing = isinstance(focus, (W.QLineEdit, W.QAbstractSpinBox))
        return not editing or shortcut in ("Ctrl+S", "Ctrl+O")

    def _build(self):
        toolbar = W.QToolBar("Файлы", self)
        toolbar.setMovable(False)
        self.addToolBar(toolbar)
        title = W.QLabel("  EternalCortex  ")
        title.setStyleSheet("font-size: 20px; font-weight: 600")
        toolbar.addWidget(title)
        toolbar.addWidget(self._button("Открыть…", self.open_file, "Ctrl+O"))
        toolbar.addWidget(self._button("Демо", self.open_demo))
        self.save_button = self._button("Сохранить проект", self.save, "Ctrl+S")
        toolbar.addWidget(self.save_button)
        toolbar.addSeparator()
        self.mode = W.QLabel("OFFLINE · нет записи")
        self.mode.setObjectName("muted")
        toolbar.addWidget(self.mode)

        root = W.QWidget()
        outer = W.QVBoxLayout(root)
        outer.setContentsMargins(16, 8, 16, 12)
        outer.setSpacing(10)
        split = W.QSplitter()
        outer.addWidget(split, 1)
        left = W.QWidget()
        layout = W.QVBoxLayout(left)
        layout.setContentsMargins(0, 0, 12, 0)
        settings = W.QHBoxLayout()
        settings.addWidget(W.QLabel("Спектр канала"))
        self.channel = W.QComboBox()
        self.channel.currentIndexChanged.connect(self.recompute)
        settings.addWidget(self.channel)
        settings.addWidget(W.QLabel("FFT"))
        self.fft = W.QComboBox()
        self.fft.addItems(["128", "256", "512", "1024", "2048"])
        self.fft.setCurrentText("512")
        self.fft.currentIndexChanged.connect(self.recompute)
        settings.addWidget(self.fft)
        settings.addStretch()
        settings.addWidget(self._button("Вся запись", self.fit, "Home"))
        settings.addWidget(self._button("К выделению", self.zoom_selection, "Z"))
        layout.addLayout(settings)

        pg.setConfigOptions(antialias=False, background="#141414", foreground="#858585")
        self.wave = pg.PlotWidget(title="ЭЭГ · каналы нормированы по амплитуде для обзора")
        self.wave.setLabel("bottom", "Время", units="s")
        self.wave.showGrid(x=True, y=False, alpha=.15)
        self.wave.setMouseEnabled(x=True, y=False)
        self.wave.setClipToView(True)
        self.wave.getPlotItem().setDownsampling(auto=True, mode="peak")
        self.heat = pg.PlotWidget(title="Спектрограмма · PSD, dB / Hz")
        self.heat.setLabel("left", "Частота", units="Hz")
        self.heat.setLabel("bottom", "Время", units="s")
        self.heat.setXLink(self.wave)
        self.heat.setMouseEnabled(x=True, y=False)
        self.image = pg.ImageItem(axisOrder="row-major")
        self.image.setLookupTable(pg.colormap.get("viridis").getLookupTable())
        self.heat.addItem(self.image)
        self.overview = pg.PlotWidget(title="Обзор записи · перетащите окно для навигации")
        self.overview.setMaximumHeight(120)
        self.overview.setMouseEnabled(x=False, y=False)
        self.overview.hideAxis("left")
        self.navigator = pg.LinearRegionItem((0, 10), brush=pg.mkBrush(150, 150, 150, 35))
        self.overview.addItem(self.navigator)
        self.navigator.sigRegionChanged.connect(self._navigate)
        self.wave.getViewBox().sigXRangeChanged.connect(self._range_changed)
        layout.addWidget(self.wave, 3)
        layout.addWidget(self.heat, 3)
        layout.addWidget(self.overview, 1)
        self.selection_region = pg.LinearRegionItem((0, 5), brush=pg.mkBrush(110, 170, 190, 25))
        self.heat.addItem(self.selection_region)
        self.selection_region.sigRegionChangeFinished.connect(self._selection_from_plot)
        self.cursors = []
        for plot in (self.wave, self.heat, self.overview):
            cursor = pg.InfiniteLine(0, pen=pg.mkPen("#dedede", width=1), movable=plot is not self.overview)
            plot.addItem(cursor)
            if plot is not self.overview:
                cursor.sigPositionChangeFinished.connect(lambda line: self.seek(line.value()))
            self.cursors.append(cursor)
        self.wave.scene().sigMouseClicked.connect(self._click_wave)
        split.addWidget(left)

        side = self.side = W.QWidget()
        side.setMinimumWidth(240)
        side.setMaximumWidth(360)
        panel = W.QVBoxLayout(side)
        panel.setContentsMargins(12, 0, 0, 0)
        panel.addWidget(W.QLabel("ВЫДЕЛЕНИЕ И РАЗМЕТКА"))
        self.start = W.QDoubleSpinBox()
        self.end = W.QDoubleSpinBox()
        for field in (self.start, self.end):
            field.setDecimals(3)
            field.setSuffix(" s")
            field.setMaximum(1e9)
            field.editingFinished.connect(self._selection_from_fields)
        form = W.QFormLayout()
        form.addRow("От", self.start)
        form.addRow("До", self.end)
        panel.addLayout(form)
        self.label = W.QLineEdit()
        self.label.setPlaceholderText("Название события или участка")
        self.label.setMaxLength(200)
        panel.addWidget(self.label)
        self.category = W.QComboBox()
        self.category.addItems(["Event", "Artifact", "Sleep", "Task", "Note"])
        panel.addWidget(self.category)
        panel.addWidget(self._button("Добавить интервал", self.add_annotation, "A"))
        panel.addWidget(self._button("Маркер на курсоре", self.add_marker, "M"))
        self.events = W.QListWidget()
        self.events.itemClicked.connect(self.select_annotation)
        self.events.itemDoubleClicked.connect(self.edit_annotation)
        panel.addWidget(self.events, 1)
        actions = W.QHBoxLayout()
        actions.addWidget(self._button("↶", lambda: self.history(False), "Ctrl+Z"))
        actions.addWidget(self._button("↷", lambda: self.history(True), "Ctrl+Shift+Z"))
        actions.addWidget(self._button("Удалить", self.delete_annotation))
        panel.addLayout(actions)
        panel.addWidget(self._button("Экспорт разметки CSV", self.export_events))
        panel.addWidget(self._button("Экспорт спектра NPZ", self.export_spectrum))
        self.details = W.QLabel("EDF / numeric NPZ\n\nЩелчок по ЭЭГ — курсор.\nПрокрутка — zoom, drag — pan.\nГраницы выделения — на спектре.\n\nSpace — play/pause\n← / → — шаг по сэмплам\nShift+← / → — шаг 1 секунда")
        self.details.setWordWrap(True)
        self.details.setObjectName("muted")
        panel.addWidget(self.details)
        split.addWidget(side)
        split.setSizes([1050, 280])
        transport = W.QHBoxLayout()
        transport.addWidget(self._button("В начало", lambda: self.seek(0)))
        self.play_button = self._button("▶  Воспроизвести", self.toggle_play, "Space")
        transport.addWidget(self.play_button)
        transport.addWidget(self._button("Стоп", self.stop))
        self.loop_button = self._button("Loop выделения", self.set_loop, "L", True)
        transport.addWidget(self.loop_button)
        self.time_label = W.QLabel("00:00.000 / 00:00.000")
        transport.addWidget(self.time_label, 1)
        self.speed = W.QComboBox()
        self.speed.addItems(["0.25×", "0.5×", "1×", "2×", "4×"])
        self.speed.setCurrentIndex(2)
        self.speed.currentIndexChanged.connect(self._speed)
        transport.addWidget(self.speed)
        self.position = W.QDoubleSpinBox()
        self.position.setDecimals(3)
        self.position.setSuffix(" s")
        self.position.setMaximum(1e9)
        self.position.editingFinished.connect(lambda: self.seek(self.position.value()))
        transport.addWidget(self.position)
        outer.addLayout(transport)
        self.setCentralWidget(root)
        for shortcut, seconds in (("Left", -1), ("Right", 1), ("Shift+Left", -1), ("Shift+Right", 1)):
            action = QtGui.QAction(self)
            action.setShortcut(shortcut)
            action.triggered.connect(lambda checked=False, s=seconds, key=shortcut:
                                     self.step(s, key.startswith("Shift")) if self._shortcut_allowed(key) else None)
            self.addAction(action)
        self._controls(False)

    def _controls(self, enabled):
        for widget in (self.save_button, self.play_button, self.loop_button, self.channel,
                       self.fft, self.start, self.end, self.speed, self.position):
            widget.setEnabled(enabled)
        self.fft.setEnabled(enabled and isinstance(self.source, Recording))
        self.side.setEnabled(enabled)

    def run_job(self, work, success):
        if self.busy:
            return False
        self.busy = True
        if self.timeline:
            self.timeline.play(False)
        self._controls(False)
        self.statusBar().showMessage("Подготовка данных…")
        job = self._job = Job(work)
        def done(result, error):
            self.busy = False
            self._controls(self.source is not None)
            self._job = None
            if error:
                self.error(error)
            else:
                try:
                    success(result)
                except Exception as failure:
                    self.error(str(failure))
        job.signals.done.connect(done)
        self.pool.start(job)
        return True

    def error(self, message):
        self.statusBar().showMessage(f"Ошибка: {message}")
        W.QMessageBox.warning(self, "EternalCortex", message)

    def _can_replace(self):
        if self.busy:
            return False
        if self.dirty:
            return W.QMessageBox.question(self, "Несохранённая разметка",
                "Продолжить без сохранения?", W.QMessageBox.Yes | W.QMessageBox.No,
                W.QMessageBox.No) == W.QMessageBox.Yes
        return True

    def open_file(self):
        if not self._can_replace():
            return
        path, _ = W.QFileDialog.getOpenFileName(self, "Открыть запись или проект", "",
                                               "Записи и проекты (*.edf *.npz)")
        if path:
            self.open_path(path)

    def open_path(self, path):
        self.stop()
        def work():
            is_project = False
            if Path(path).suffix.lower() == ".npz":
                from .recording import _bounded_npz
                with _bounded_npz(Path(path)) as archive:
                    is_project = "project" in archive
            if is_project:
                source, annotations, channel, fft, selection = open_project(path)
            else:
                source, annotations, channel, fft, selection = load(path), [], 0, 512, None
            spectrum = compute_spectrum(source, channel, fft) if isinstance(source, Recording) else source
            return source, spectrum, annotations, channel, fft, selection
        self.run_job(work, self.install)

    def open_demo(self):
        if self._can_replace():
            self.stop()
            def work():
                source = demo()
                return source, compute_spectrum(source, 0), [], 0, 512, None
            self.run_job(work, self.install)

    def install(self, result):
        source, spectrum, annotations, channel, fft, selection = result
        self.source, self.spectrum = source, spectrum
        self.timeline = Timeline(source.duration)
        self.timeline.set_speed((.25, .5, 1, 2, 4)[self.speed.currentIndex()])
        self.timeline.loop = self.loop_button.isChecked()
        self.annotations = Annotations(source.duration)
        self.annotations.items = annotations
        self.channel.blockSignals(True)
        self.channel.clear()
        self.channel.addItems(source.labels if isinstance(source, Recording) else ["Saved spectrum"])
        self.channel.setCurrentIndex(channel)
        self.channel.blockSignals(False)
        self.fft.blockSignals(True)
        self.fft.setCurrentText(str(fft))
        self.fft.blockSignals(False)
        self._controls(True)
        self.fft.setEnabled(isinstance(source, Recording))
        self._visible = None
        for curve in self.curves:
            self.wave.removeItem(curve)
        self.curves = []
        self.overview.clear()
        self.overview.addItem(self.navigator)
        self.overview.addItem(self.cursors[2])
        if isinstance(source, Recording):
            count = min(16, source.samples.shape[1])
            for i in range(count):
                self.curves.append(self.wave.plot(pen=pg.mkPen("#8bb9c5" if i == channel else "#858585", width=1)))
            self.wave.getAxis("left").setTicks([[(i*3, source.labels[i]) for i in range(count)]])
            self.wave.setYRange(-2, count*3)
            stride = max(1, len(source.samples)//4000)
            self.overview.plot(np.arange(0, len(source.samples), stride)/source.rate,
                               source.samples[::stride, channel], pen="#858585")
            self.details.setText(f"{source.samples.shape[1]} каналов · {source.rate:g} Hz\n"
                f"{source.duration:.3f} s\n\nКривые: первые {count} каналов, нормированы только для обзора. "
                "Исходные значения не меняются.\n\nСпектр: выбранный канал. Единицы: "
                f"{source.units[channel] or 'не заданы'}.\n\nSpace — play/pause · A — интервал · M — маркер")
        else:
            self.wave.getAxis("left").setTicks(None)
            self.details.setText("Числовая спектрограмма. Исходная ЭЭГ отсутствует: смена FFT и восстановление сигнала недоступны.")
            self.overview.plot(np.arange(len(source.db))*source.step + source.offset,
                               source.db.mean(axis=1), pen="#858585")
        self.mode.setText("REPLAY · " + (source.path.name if source.path else "DEMO / синтетическая ЭЭГ"))
        self.selection_region.setBounds((0, source.duration))
        self.navigator.setBounds((0, source.duration))
        for field in (self.start, self.end, self.position):
            field.setMaximum(source.duration)
        self.timeline.select(*(selection or (0, min(5, source.duration))))
        self._sync_selection()
        self._draw_spectrum()
        self.fit()
        self.refresh_annotations()
        self.dirty = False
        self.statusBar().showMessage("Готово · локальный replay, без публикации сигнала в граф")
        if self.protocol:
            self.protocol.send({"type": "state", "values": {"status": self.mode.text()}})

    def recompute(self):
        if self.busy or not isinstance(self.source, Recording):
            return
        source, channel, size = self.source, self.channel.currentIndex(), int(self.fft.currentText())
        self.run_job(lambda: compute_spectrum(source, channel, size), self._spectrum_ready)

    def _spectrum_ready(self, spectrum):
        self.spectrum = spectrum
        self._draw_spectrum()
        for index, curve in enumerate(self.curves):
            curve.setPen(pg.mkPen("#8bb9c5" if index == self.channel.currentIndex() else "#858585", width=1))
        self.dirty = True
        self.statusBar().showMessage("Спектр обновлён · one-sided PSD, Hann window")

    def _draw_spectrum(self):
        spectrum = self.spectrum
        self.image.setImage(spectrum.db.T, autoLevels=False)
        self.image.setLevels((float(np.percentile(spectrum.db, 5)), float(np.percentile(spectrum.db, 99))))
        df = spectrum.frequencies[1]-spectrum.frequencies[0]
        self.image.setRect(QtCore.QRectF(spectrum.offset-spectrum.step/2, spectrum.frequencies[0]-df/2,
                                         len(spectrum.db)*spectrum.step, len(spectrum.frequencies)*df))
        self.heat.setYRange(0, min(100, spectrum.frequencies[-1]))
        if isinstance(self.source, Recording):
            channel = self.channel.currentIndex()
            self.heat.setTitle(f"Спектрограмма · {self.source.labels[channel]} · PSD, dB ({self.source.units[channel] or 'unit'})²/Hz")
        else:
            self.heat.setTitle("Сохранённая спектрограмма · dB (единицы исходного файла)")

    def _range_changed(self, _, bounds):
        if not self.source or self._setting_range:
            return
        a, b = max(0., bounds[0]), min(self.source.duration, bounds[1])
        self.navigator.blockSignals(True)
        self.navigator.setRegion((a, b))
        self.navigator.blockSignals(False)
        self._draw_wave(a, b)

    def _draw_wave(self, a, b):
        if not isinstance(self.source, Recording) or self._visible == (a, b):
            return
        self._visible = (a, b)
        # Peak-preserving min/max bins keep narrow spikes visible at large zoom.
        for channel, curve in enumerate(self.curves):
            x, y = self.source.window(a, b, channel)
            if not len(y):
                curve.setData([], [])
                continue
            stride = max(1, len(y)//2000)
            if stride > 1:
                usable = len(y)//stride*stride
                grouped = y[:usable].reshape(-1, stride)
                tail_x, tail_y = x[usable:], y[usable:]
                y = np.concatenate((np.column_stack((grouped.min(axis=1), grouped.max(axis=1))).ravel(), tail_y))
                x = np.concatenate((np.repeat(x[:usable:stride], 2), tail_x))
            scale = max(float(np.std(y))*2.5, 1e-12)
            curve.setData(x, (y-float(np.mean(y)))/scale + channel*3)

    def _navigate(self):
        if self.source and not self._setting_range:
            self.wave.setXRange(*self.navigator.getRegion(), padding=0)

    def fit(self):
        if self.source:
            self.wave.setLimits(xMin=0, xMax=self.source.duration, minXRange=min(.001, self.source.duration))
            self.wave.setXRange(0, self.source.duration, padding=0)

    def zoom_selection(self):
        if self.timeline:
            a, b = self.timeline.selection
            if b > a:
                self.wave.setXRange(a, b, padding=.02)

    def _selection_from_plot(self):
        if self.timeline and not self.busy:
            self.timeline.select(*self.selection_region.getRegion())
            self._sync_selection()
            self.dirty = True

    def _selection_from_fields(self):
        if self.timeline:
            self.timeline.select(self.start.value(), self.end.value())
            self._sync_selection()
            self.dirty = True

    def _sync_selection(self):
        a, b = self.timeline.selection
        self.selection_region.blockSignals(True)
        self.selection_region.setRegion((a, b))
        self.selection_region.blockSignals(False)
        self.start.setValue(a)
        self.end.setValue(b)

    def _click_wave(self, event):
        if event.button() == QtCore.Qt.LeftButton and not event.isAccepted() and self.wave.sceneBoundingRect().contains(event.scenePos()):
            self.seek(self.wave.getViewBox().mapSceneToView(event.scenePos()).x())

    def seek(self, position):
        if self.timeline:
            self.timeline.seek(position)
            self._tick()

    def step(self, direction, seconds=False):
        if self.timeline:
            interval = 1/self.source.rate if isinstance(self.source, Recording) else self.source.step
            self.seek(self.timeline.position + direction*(1 if seconds else interval))

    def toggle_play(self):
        if self.timeline and not self.busy:
            self.timeline.play(not self.timeline.playing)

    def stop(self):
        if self.timeline:
            self.timeline.play(False)
            self.seek(0)

    def set_loop(self):
        if self.timeline:
            self.timeline.loop = self.loop_button.isChecked()

    def _speed(self):
        if self.timeline:
            self.timeline.set_speed((.25, .5, 1, 2, 4)[self.speed.currentIndex()])

    def _tick(self):
        if not self.timeline:
            return
        if any(cursor.moving for cursor in self.cursors):
            return  # don't overwrite an in-progress user drag on the next frame
        position = self.timeline.tick()
        for cursor in self.cursors:
            cursor.setValue(position)
        self.play_button.setText("Ⅱ  Пауза" if self.timeline.playing else "▶  Воспроизвести")
        def stamp(value):
            return f"{int(value)//60:02}:{value%60:06.3f}"
        self.time_label.setText(f"{stamp(position)} / {stamp(self.timeline.duration)}")
        if not self.position.hasFocus():
            self.position.setValue(position)

    def add_annotation(self, marker=False):
        if not self.timeline or self.busy:
            return
        start, end = self.timeline.selection
        if marker:
            start = end = self.timeline.position
        label = self.label.text().strip() or ("Маркер" if marker else "Участок")
        item = Annotation(start, end, label, self.category.currentText())
        try:
            self.annotations.replace([*self.annotations.items, item])
        except ValueError as error:
            self.error(str(error))
            return
        self.refresh_annotations()
        self.dirty = True

    def add_marker(self):
        self.add_annotation(True)

    def refresh_annotations(self):
        self.events.clear()
        for region in self.annotation_regions:
            self.wave.removeItem(region)
        self.annotation_regions.clear()
        for item in self.annotations.items:
            self.events.addItem(f"{item.start:.3f}–{item.end:.3f} s\n{item.label} · {item.category}")
        # Avoid thousands of graphics objects; all events remain in the list.
        for item in self.annotations.items[:500]:
            if item.end > item.start:
                region = pg.LinearRegionItem((item.start, item.end), movable=False,
                    brush=pg.mkBrush(190, 150, 90, 22), pen=pg.mkPen(190, 150, 90, 90))
            else:
                region = pg.InfiniteLine(item.start, pen=pg.mkPen("#be965a"))
            self.wave.addItem(region)
            self.annotation_regions.append(region)

    def select_annotation(self):
        index = self.events.currentRow()
        if index >= 0:
            item = self.annotations.items[index]
            self.timeline.select(item.start, item.end)
            self._sync_selection()
            self.seek(item.start)
            self.label.setText(item.label)
            self.category.setCurrentText(item.category)

    def edit_annotation(self):
        if self.busy:
            return
        index = self.events.currentRow()
        if index < 0:
            return
        item = self.annotations.items[index]
        label, ok = W.QInputDialog.getText(self, "Редактировать событие", "Название", text=item.label)
        if ok and label.strip():
            items = self.annotations.items[:]
            items[index] = replace(item, label=label[:200])
            self.annotations.replace(items)
            self.refresh_annotations()
            self.dirty = True

    def delete_annotation(self):
        index = self.events.currentRow()
        if self.annotations and index >= 0:
            items = self.annotations.items[:]
            del items[index]
            self.annotations.replace(items)
            self.refresh_annotations()
            self.dirty = True

    def history(self, redo):
        if self.annotations and not self.busy:
            self.annotations.redo() if redo else self.annotations.undo()
            self.refresh_annotations()
            self.dirty = True

    def save(self):
        if not self.source or self.busy:
            return
        path, _ = W.QFileDialog.getSaveFileName(self, "Сохранить проект", "EternalCortex-project.npz", "EternalCortex (*.npz)")
        if not path:
            return
        self.timeline.play(False)
        source, items = self.source, self.annotations.items[:]
        channel, fft, selection = self.channel.currentIndex(), int(self.fft.currentText()), self.timeline.selection
        def saved(_):
            self.dirty = False
            self.statusBar().showMessage(f"Проект сохранён: {path}")
        self.run_job(lambda: save_project(path, source, items, channel, fft, selection), saved)

    def export_events(self):
        if not self.annotations or self.busy:
            return
        path, _ = W.QFileDialog.getSaveFileName(self, "Экспорт разметки", "annotations.csv", "CSV (*.csv)")
        if path:
            try:
                export_annotations(path, self.annotations.items)
                self.statusBar().showMessage(f"Разметка сохранена: {path}")
            except OSError as error:
                self.error(str(error))

    def export_spectrum(self):
        if not self.spectrum or self.busy:
            return
        path, _ = W.QFileDialog.getSaveFileName(self, "Экспорт числового спектра", "spectrogram.npz", "NPZ (*.npz)")
        if path:
            spectrum = self.spectrum
            def work():
                with open(path, "wb") as stream:
                    np.savez_compressed(stream, power_db=spectrum.db, time_step=spectrum.step,
                                        frequencies=spectrum.frequencies, offset=spectrum.offset)
            self.run_job(work, lambda _: self.statusBar().showMessage(f"Спектр сохранён: {path}"))

    def _message(self, message):
        with self.protocol.lock:
            self.protocol.pending = max(0, self.protocol.pending-1)
        kind = message.get("type")
        if kind == "init":
            if message.get("protocol") != 1:
                W.QApplication.quit()
                return
            self.protocol.send({"type": "state", "values": {"status": "EternalCortex ready · dedicated window"}})
        elif kind == "event" and message.get("id") == "show_window":
            self.showNormal()
            self.raise_()
            self.activateWindow()
        elif kind == "stop":
            self.pool.waitForDone()
            W.QApplication.quit()

    def closeEvent(self, event):
        if self.managed:
            self.hide()
            self.statusBar().showMessage("Окно скрыто; открыть снова можно из Qualia")
            event.ignore()
        elif self._can_replace():
            self.pool.waitForDone()
            event.accept()
        else:
            event.ignore()


def main():
    parser = argparse.ArgumentParser(description="EternalCortex EEG studio")
    parser.add_argument("--qualia", action="store_true", help="process-v1 stdio, owned by Qualia")
    parser.add_argument("--demo", action="store_true")
    parser.add_argument("--smoke", action="store_true", help="Load demo and exit after rendering (CI)")
    parser.add_argument("path", nargs="?")
    args = parser.parse_args()
    app = W.QApplication([sys.argv[0]])
    app.setApplicationName("EternalCortex")
    app.setOrganizationName("Qualia")
    app.setStyle("Fusion")
    app.setStyleSheet(STYLE)
    studio = Studio(args.qualia)
    studio.show()
    if args.path:
        studio.open_path(args.path)
    elif args.demo or args.smoke:
        studio.open_demo()
    if args.smoke:
        def finish():
            if studio.busy:
                QtCore.QTimer.singleShot(100, finish)
                return
            if studio.source is None:
                app.exit(1)
                return
            studio.pool.waitForDone()
            app.exit(0)
        QtCore.QTimer.singleShot(1200, finish)
    return app.exec()
