"""Run: PYTHONPATH=payload python -m unittest discover -s tests -v."""
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
import numpy as np
from eternal_cortex.recording import Recording, Spectrogram, compute_spectrum, demo, load
from eternal_cortex.timeline import Annotation, Annotations, Timeline
from eternal_cortex.project import open_project, save_project, export_annotations


class ClockTests(unittest.TestCase):
    def test_elapsed_speed_pause_seek_and_end(self):
        now = [100.]
        timeline = Timeline(10, lambda: now[0])
        timeline.play()
        now[0] += .5
        self.assertAlmostEqual(timeline.tick(), .5)
        timeline.set_speed(2)
        now[0] += 1
        self.assertAlmostEqual(timeline.tick(), 2.5)
        timeline.play(False)
        now[0] += 5
        self.assertEqual(timeline.tick(), 2.5)
        timeline.seek(9)
        timeline.play()
        now[0] += 1
        self.assertEqual(timeline.tick(), 10)
        self.assertFalse(timeline.playing)
        timeline.play()
        self.assertEqual(timeline.position, 0)
        with self.assertRaises(ValueError):
            timeline.seek(float("nan"))

    def test_loop_overshoot_and_zero_length(self):
        now = [0.]
        timeline = Timeline(10, lambda: now[0])
        timeline.select(4, 2)
        timeline.loop = True
        timeline.seek(3)
        timeline.play()
        now[0] += 8.5
        self.assertEqual(timeline.tick(), 3.5)
        timeline.select(2, 2)
        now[0] += 20
        self.assertEqual(timeline.tick(), 10)

    def test_annotation_history_and_validation(self):
        document = Annotations(10)
        item = Annotation(1, 3, "Artifact")
        document.replace([item])
        document.replace([])
        document.undo()
        self.assertEqual(document.items, [item])
        document.redo()
        self.assertEqual(document.items, [])
        with self.assertRaises(ValueError):
            document.replace([Annotation(3, 11, "Out of bounds")])
        with self.assertRaises(ValueError):
            document.replace([Annotation(3, 2, "Reversed")])


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="eternalcortex-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_project_round_trip_signal_and_spectrum(self):
        signal = demo()
        for source in (signal, compute_spectrum(signal, 0)):
            path = self.root / "project.npz"
            items = [Annotation(1., 2., "α event", "Task")]
            save_project(path, source, items, 0, 512, (1., 5.))
            reopened, annotations, channel, fft, selection = open_project(path)
            self.assertEqual(annotations, items)
            self.assertEqual((channel, fft, selection), (0, 512, (1., 5.)))
            self.assertEqual(reopened.duration, source.duration)
            if isinstance(source, Recording):
                np.testing.assert_array_equal(reopened.samples, source.samples)
            else:
                np.testing.assert_array_equal(reopened.db, source.db)

    def test_npz_nonfinite_and_forged_huge_shape_rejected(self):
        path = self.root / "bad.npz"
        np.savez(path, samples=[[np.nan]], sample_rate=256.)
        with self.assertRaises(ValueError):
            load(path)
        header = io.BytesIO()
        np.lib.format.write_array_header_1_0(header, {
            "descr": "<f4", "fortran_order": False, "shape": (10**12, 8)})
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("samples.npy", header.getvalue())
        with self.assertRaisesRegex(ValueError, "shape"):
            load(path)

    def test_pickle_and_unknown_extensions_rejected(self):
        path = self.root / "pickle.npz"
        np.savez(path, samples=np.array([{}], dtype=object), sample_rate=256.)
        with self.assertRaises(ValueError):
            load(path)
        path = self.root / "spectrum.png"
        path.write_bytes(b"not numeric")
        with self.assertRaisesRegex(ValueError, "not signal"):
            load(path)

    def test_edf_record_order_and_calibration(self):
        path = self.root / "signal.edf"
        def field(value, size):
            return str(value).encode("ascii").ljust(size)
        header = b"".join(field(value, size) for value, size in [
            (0, 8), ("patient", 80), ("recording", 80), ("01.01.26", 8),
            ("12.00.00", 8), (768, 8), ("", 44), (2, 8), (1, 8), (2, 4)])
        channels = b"".join(field(value, size) for values, size in [
            (["C3", "C4"], 16), (["", ""], 80), (["uV", "mV"], 8),
            ([-100, -1], 8), ([100, 1], 8), ([-1000, -1000], 8),
            ([1000, 1000], 8), (["", ""], 80), ([2, 2], 8), (["", ""], 32)
        ] for value in values)
        path.write_bytes(header+channels+np.array([0, 100, 200, 300, 400, 500, 600, 700], dtype="<i2").tobytes())
        signal = load(path)
        self.assertEqual(signal.rate, 2)
        np.testing.assert_allclose(signal.samples, [[0, .2], [10, .3], [40, .6], [50, .7]], atol=1e-6)
        self.assertEqual(signal.units, ("uV", "mV"))
        path.write_bytes(path.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, "length"):
            load(path)

    def test_csv_formula_safe(self):
        path = self.root / "events.csv"
        export_annotations(path, [Annotation(0, 1, "=1+1")])
        self.assertIn("'=1+1", path.read_text())


class SpectrumTests(unittest.TestCase):
    def test_psd_peak_power_and_time_centres(self):
        rate = 256
        t = np.arange(rate*4)/rate
        signal = Recording(np.sin(2*np.pi*16*t)[:, None], rate, ("C3",), ("uV",))
        spectrum = compute_spectrum(signal, 0, 256)
        peak = spectrum.frequencies[np.argmax(spectrum.db.mean(axis=0))]
        self.assertEqual(peak, 16)
        power = np.power(10, spectrum.db[0]/10).sum()
        self.assertAlmostEqual(float(power), .5, places=4)
        self.assertEqual(spectrum.offset, .5)
        self.assertEqual(spectrum.step, .25)
        self.assertLessEqual(len(spectrum.db), 4097)

    def test_nonuniform_frequencies_rejected(self):
        with self.assertRaises(ValueError):
            Spectrogram(np.zeros((10, 3)), .1, np.array([0, 1, 4]))


class UiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from PySide6.QtWidgets import QApplication
        cls.app = QApplication.instance() or QApplication([])

    def test_demo_selection_replay_annotation_and_spectrum_only(self):
        from eternal_cortex.app import Studio
        window = Studio()
        self.addCleanup(window.deleteLater)
        source = demo()
        spectrum = compute_spectrum(source, 0)
        window.install((source, spectrum, [], 0, 512, None))
        window.label.setText("Blink")
        window.add_annotation()
        self.assertEqual(len(window.annotations.items), 1)
        self.assertFalse(window.annotations.items[0].start == window.annotations.items[0].end)
        window.history(False)
        self.assertEqual(len(window.annotations.items), 0)
        window.seek(3.5)
        window.cursors[0].moving = True
        window.cursors[0].setValue(4.5)
        window._tick()
        self.assertEqual(window.cursors[0].value(), 4.5)
        window.cursors[0].moving = False
        window.add_marker()
        self.assertEqual(window.annotations.items[0].start, 3.5)
        window.toggle_play()
        self.assertTrue(window.timeline.playing)
        window.stop()
        self.assertEqual(window.timeline.position, 0)
        window.install((spectrum, spectrum, [], 0, 512, None))
        self.assertFalse(window.fft.isEnabled())
        window._controls(True)
        self.assertFalse(window.fft.isEnabled())

    def test_managed_protocol_handshake_and_eof(self):
        entry = Path(__file__).resolve().parents[1] / "payload/main.py"
        process = subprocess.Popen([sys.executable, str(entry), "--qualia"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        # communicate closes stdin: queued init is processed before EOF shutdown.
        out, err = process.communicate(json.dumps({"type": "init", "protocol": 1,
            "instanceId": "test-instance", "parameters": {}})+"\n", timeout=15)
        self.assertEqual(process.returncode, 0, err)
        messages = [json.loads(line) for line in out.splitlines()]
        self.assertEqual(messages[0]["type"], "ready")
        self.assertEqual(messages[0]["protocol"], 1)
        self.assertEqual(messages[1]["type"], "state")

    def test_annotation_typing_does_not_trigger_single_key_actions(self):
        from PySide6 import QtCore, QtTest
        from eternal_cortex.app import Studio
        window = Studio()
        self.addCleanup(window.deleteLater)
        signal = demo()
        window.install((signal, compute_spectrum(signal, 0), [], 0, 512, None))
        window.show()
        window.label.setFocus()
        self.app.processEvents()
        QtTest.QTest.keyClicks(window.label, "a marker")
        self.assertEqual(window.label.text(), "a marker")
        self.assertFalse(window.timeline.playing)
        self.assertEqual(window.annotations.items, [])
        window.dirty = False
        window.close()


if __name__ == "__main__":
    unittest.main()
