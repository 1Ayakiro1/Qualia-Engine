// Qualia's GTK vsync bridge for the pinned Flutter Linux embedder.
#ifndef QUALIA_FL_NATIVE_VSYNC_H_
#define QUALIA_FL_NATIVE_VSYNC_H_

#include <gtk/gtk.h>
#include "flutter/shell/platform/embedder/embedder.h"

struct FlNativeVsync;

FlNativeVsync* fl_native_vsync_new();
void fl_native_vsync_set_widget(FlNativeVsync* self, GtkWidget* widget);
void fl_native_vsync_set_engine(FlNativeVsync* self,
                                FlutterEngine engine,
                                FlutterEngineProcTable* api);
void fl_native_vsync_request(FlNativeVsync* self, intptr_t baton);
// Main-thread shutdown, before FlutterEngineShutdown; drains queued batons.
void fl_native_vsync_shutdown(FlNativeVsync* self);
// Called after engine shutdown has joined its request-producing threads.
void fl_native_vsync_engine_stopped(FlNativeVsync* self);
void fl_native_vsync_free(FlNativeVsync* self);

#endif
