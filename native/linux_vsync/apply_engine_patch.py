#!/usr/bin/env python3
"""Apply Qualia's small vsync integration to an exact, isolated engine checkout.

Never changes the user's Flutter SDK. Fail closed on an unexpected upstream
source, and permit reruns after copying the pristine pinned engine sources.
"""
import argparse
import pathlib
import shutil

REVISION = "af7e796e161ae0bb1ff0758c71a7105418bd9ded"


def replace_once(text, before, after):
    if text.count(before) != 1:
        raise SystemExit(f"Unexpected Flutter engine source at anchor: {before!r}")
    return text.replace(before, after, 1)


def apply(engine):
    local = pathlib.Path(__file__).resolve().parent
    linux = engine / "shell/platform/linux"
    file = linux / "fl_engine.cc"
    text = file.read_text()
    if "fl_native_vsync.h" not in text:
        text = replace_once(text,
            '#include "flutter/shell/platform/linux/fl_engine_private.h"',
            '#include "flutter/shell/platform/linux/fl_engine_private.h"\n'
            '#include "flutter/shell/platform/linux/fl_native_vsync.h"')
        text = replace_once(text,
            '  FlutterEngineProcTable embedder_api;',
            '  FlutterEngineProcTable embedder_api;\n\n'
            '  FlNativeVsync* native_vsync;')
        text = replace_once(text,
            '  if (self->engine != nullptr) {\n    if (self->embedder_api.Shutdown',
            '  if (self->native_vsync) fl_native_vsync_shutdown(self->native_vsync);\n'
            '  if (self->engine != nullptr) {\n    if (self->embedder_api.Shutdown')
        text = replace_once(text,
            '    self->engine = nullptr;\n  }\n\n  if (self->aot_data',
            '    self->engine = nullptr;\n  }\n'
            '  if (self->native_vsync) {\n'
            '    fl_native_vsync_engine_stopped(self->native_vsync);\n'
            '    fl_native_vsync_free(self->native_vsync);\n'
            '    self->native_vsync = nullptr;\n'
            '  }\n\n  if (self->aot_data')
        text = replace_once(text,
            '  self->thread = g_thread_self();',
            '  self->thread = g_thread_self();\n'
            '  self->native_vsync = fl_native_vsync_new();')
        text = replace_once(text,
            '  args.engine_id = reinterpret_cast<int64_t>(self);',
            '  args.engine_id = reinterpret_cast<int64_t>(self);\n'
            '  if (g_strcmp0(g_getenv("QUALIA_NATIVE_VSYNC"), "0") != 0) {\n'
            '    args.vsync_callback = [](void* data, intptr_t baton) {\n'
            '      fl_native_vsync_request(FL_ENGINE(data)->native_vsync, baton);\n'
            '    };\n'
            '  }')
        text = replace_once(text,
            '  result = self->embedder_api.RunInitialized(self->engine);',
            '  fl_native_vsync_set_engine(self->native_vsync, self->engine, &self->embedder_api);\n'
            '  result = self->embedder_api.RunInitialized(self->engine);')
        text = replace_once(text,
            '  set_renderable(self, flutter::kFlutterImplicitViewId, renderable);',
            '  set_renderable(self, flutter::kFlutterImplicitViewId, renderable);\n'
            '  if (GTK_IS_WIDGET(renderable)) {\n'
            '    fl_native_vsync_set_widget(self->native_vsync, GTK_WIDGET(renderable));\n'
            '  }')
        file.write_text(text)
    for name in ("fl_native_vsync.h", "fl_native_vsync.cc", "frame_time.h"):
        shutil.copy2(local / name, linux / name)
    gn = linux / "BUILD.gn"
    text = gn.read_text()
    if '"fl_native_vsync.cc"' not in text:
        text = replace_once(text, '    "fl_engine.cc",',
                            '    "fl_engine.cc",\n    "fl_native_vsync.cc",')
        gn.write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("engine", type=pathlib.Path)
    args = parser.parse_args()
    apply(args.engine)
