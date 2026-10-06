#include "fl_native_vsync.h"
#include "frame_time.h"

#include <deque>
#include <cstdlib>
#include <mutex>
#include <utility>

// GTK access and OnVsync occur only on the engine's platform thread.
// request() is thread-safe: Flutter can invoke it on its own UI thread.
struct FlNativeVsync {
  GMainContext* context = g_main_context_ref_thread_default();
  GWeakRef widget;
  FlutterEngine engine = nullptr;
  FlutterEngineProcTable* api = nullptr;
  std::mutex mutex;
  std::deque<intptr_t> pending;
  GSource* dispatch = nullptr;
  guint tick = 0;
  gulong unmap = 0;
  bool stopping = false;
  int64_t logged_interval = 0;
};

static void deliver(FlNativeVsync* self, GdkFrameClock* clock) {
  if (!self->engine) return;
  std::deque<intptr_t> batons;
  {
    std::lock_guard<std::mutex> lock(self->mutex);
    batons.swap(self->pending);
  }
  if (batons.empty()) return;
  const gint64 now = g_get_monotonic_time();
  gint64 frame = now, interval = 0, target = 0;
  if (clock) {
    frame = gdk_frame_clock_get_frame_time(clock);
    gdk_frame_clock_get_refresh_info(clock, now, &interval, &target);
  }
  const auto times = qualia::frame_time(self->api->GetCurrentTime(), now,
                                       frame, target, interval);
  for (intptr_t baton : batons) {
    if (self->api->OnVsync(self->engine, baton, times.start, times.target) != kSuccess) {
      g_warning("Qualia native vsync: OnVsync failed");
    }
  }
  if (clock && interval > 0 &&
      (self->logged_interval == 0 ||
       std::abs(interval - self->logged_interval) > self->logged_interval / 100)) {
    self->logged_interval = interval;
    g_message("Qualia native vsync: GTK frame clock %.2f Hz (%" G_GINT64_FORMAT " us)",
              1000000.0 / interval, interval);
  }
}

static gboolean tick_cb(GtkWidget*, GdkFrameClock* clock, gpointer data) {
  auto* self = static_cast<FlNativeVsync*>(data);
  self->tick = 0;
  deliver(self, clock);
  // One native tick per engine request; no continuous idle rendering.
  return G_SOURCE_REMOVE;
}

static void unmap_cb(GtkWidget* widget, gpointer data) {
  auto* self = static_cast<FlNativeVsync*>(data);
  if (self->tick) {
    gtk_widget_remove_tick_callback(widget, self->tick);
    self->tick = 0;
  }
  // Hidden windows do not receive GTK ticks. Complete the outstanding baton
  // once so bootstrap/unmap cannot deadlock; this is not a background timer.
  deliver(self, nullptr);
}

static gboolean dispatch_cb(gpointer data) {
  auto* self = static_cast<FlNativeVsync*>(data);
  {
    std::lock_guard<std::mutex> lock(self->mutex);
    g_source_unref(self->dispatch);
    self->dispatch = nullptr;
    if (self->stopping) return G_SOURCE_REMOVE;
  }
  g_autoptr(GtkWidget) widget = GTK_WIDGET(g_weak_ref_get(&self->widget));
  if (widget && gtk_widget_get_mapped(widget)) {
    if (!self->tick) self->tick = gtk_widget_add_tick_callback(widget, tick_cb, self, nullptr);
  } else {
    deliver(self, nullptr);
  }
  return G_SOURCE_REMOVE;
}

FlNativeVsync* fl_native_vsync_new() {
  auto* self = new FlNativeVsync();
  g_weak_ref_init(&self->widget, nullptr);
  return self;
}

void fl_native_vsync_set_widget(FlNativeVsync* self, GtkWidget* widget) {
  g_autoptr(GtkWidget) previous = GTK_WIDGET(g_weak_ref_get(&self->widget));
  if (previous) {
    if (self->tick) gtk_widget_remove_tick_callback(previous, self->tick);
    if (self->unmap) g_signal_handler_disconnect(previous, self->unmap);
  }
  self->tick = 0;
  self->unmap = 0;
  g_weak_ref_set(&self->widget, widget);
  if (widget) self->unmap = g_signal_connect(widget, "unmap", G_CALLBACK(unmap_cb), self);
}

void fl_native_vsync_set_engine(FlNativeVsync* self,
                                FlutterEngine engine,
                                FlutterEngineProcTable* api) {
  self->engine = engine;
  self->api = api;
  if (g_strcmp0(g_getenv("QUALIA_NATIVE_VSYNC"), "0") == 0) {
    g_message("Qualia native vsync: disabled (Flutter fallback)");
  } else {
    g_message("Qualia native vsync: enabled (GTK frame clock, no fixed FPS cap)");
  }
}

void fl_native_vsync_request(FlNativeVsync* self, intptr_t baton) {
  std::lock_guard<std::mutex> lock(self->mutex);
  self->pending.push_back(baton);
  if (self->stopping || self->dispatch) return;
  // invoke() may run synchronously on the caller; a source always rethreads.
  self->dispatch = g_idle_source_new();
  g_source_set_priority(self->dispatch, G_PRIORITY_HIGH);
  g_source_set_callback(self->dispatch, dispatch_cb, self, nullptr);
  g_source_attach(self->dispatch, self->context);
}

void fl_native_vsync_shutdown(FlNativeVsync* self) {
  {
    std::lock_guard<std::mutex> lock(self->mutex);
    self->stopping = true;
    if (self->dispatch) {
      g_source_destroy(self->dispatch);
      g_source_unref(self->dispatch);
      self->dispatch = nullptr;
    }
  }
  fl_native_vsync_set_widget(self, nullptr);
  deliver(self, nullptr);
}

void fl_native_vsync_free(FlNativeVsync* self) {
  if (!self) return;
  fl_native_vsync_shutdown(self);
  g_weak_ref_clear(&self->widget);
  g_main_context_unref(self->context);
  delete self;
}

void fl_native_vsync_engine_stopped(FlNativeVsync* self) {
  self->engine = nullptr;
  self->api = nullptr;
}
