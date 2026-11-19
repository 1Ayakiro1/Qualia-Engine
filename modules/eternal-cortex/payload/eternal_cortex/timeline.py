"""Monotonic replay clock and undoable annotation document; no Qt dependency."""
from dataclasses import asdict, dataclass
import math
import time


@dataclass(frozen=True)
class Annotation:
    start: float
    end: float
    label: str
    category: str = "Event"


class Timeline:
    def __init__(self, duration: float, clock=time.monotonic):
        if not math.isfinite(duration) or duration <= 0:
            raise ValueError("Invalid duration")
        self.duration = duration
        self.clock = clock
        self.position = 0.0
        self.speed = 1.0
        self.playing = False
        self.loop = False
        self.selection = (0.0, min(5.0, duration))
        self._last = clock()

    def seek(self, position):
        if not math.isfinite(position):
            raise ValueError("Nonfinite position")
        self.position = max(0.0, min(self.duration, position))
        self._last = self.clock()

    def play(self, enabled=True):
        self.tick()
        self.playing = enabled
        if enabled and self.position >= self.duration:
            self.position = 0.0
        self._last = self.clock()

    def set_speed(self, speed):
        if speed not in (.25, .5, 1, 2, 4):
            raise ValueError("Unsupported replay speed")
        self.tick()
        self.speed = speed

    def select(self, start, end):
        if not math.isfinite(start) or not math.isfinite(end):
            raise ValueError("Nonfinite selection")
        self.selection = tuple(sorted((max(0., min(self.duration, start)),
                                       max(0., min(self.duration, end)))))

    def tick(self):
        now = self.clock()
        elapsed = max(0.0, now-self._last)
        self._last = now
        if self.playing:
            position = self.position + elapsed*self.speed
            a, b = self.selection
            if self.loop and b > a and (position >= b or position < a):
                position = a + (position-a) % (b-a)
            elif position >= self.duration:
                position = self.duration
                self.playing = False
            self.position = position
        return self.position


class Annotations:
    def __init__(self, duration):
        self.duration = duration
        self.items: list[Annotation] = []
        self._undo = []
        self._redo = []

    def validate(self, item):
        if (not math.isfinite(item.start) or not math.isfinite(item.end)
                or not 0 <= item.start <= item.end <= self.duration
                or not item.label.strip() or len(item.label) > 200 or len(item.category) > 64):
            raise ValueError("Invalid annotation")

    def replace(self, items):
        if len(items) > 10000:
            raise ValueError("Annotation limit reached")
        for item in items:
            self.validate(item)
        self._undo.append(self.items[:])
        self._undo = self._undo[-100:]
        self._redo.clear()
        self.items = list(items)

    def undo(self):
        if self._undo:
            self._redo.append(self.items[:])
            self.items = self._undo.pop()

    def redo(self):
        if self._redo:
            self._undo.append(self.items[:])
            self.items = self._redo.pop()

    def serialize(self):
        return [asdict(item) for item in self.items]
