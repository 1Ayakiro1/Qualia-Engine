#include "fl_native_vsync.h"
#include <cassert>
#include <chrono>
#include <thread>
#include <vector>

static GThread* platform_thread;
static std::vector<intptr_t> received;
static uint64_t current_time() {
  return static_cast<uint64_t>(g_get_monotonic_time()) * 1000;
}
static FlutterEngineResult on_vsync(FlutterEngine, intptr_t baton,
                                    uint64_t start, uint64_t target) {
  assert(g_thread_self() == platform_thread);
  assert(target > start);
  assert(start <= current_time());
  received.push_back(baton);
  return kSuccess;
}
static void wait_for(size_t count) {
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
  while (received.size() < count && std::chrono::steady_clock::now() < deadline) {
    while (g_main_context_iteration(nullptr, FALSE)) {}
    g_usleep(1000);
  }
  assert(received.size() == count);
}

int main(int argc, char** argv) {
  gtk_init(&argc, &argv);
  platform_thread = g_thread_self();
  auto* self = fl_native_vsync_new();
  FlutterEngineProcTable api = {};
  api.GetCurrentTime = current_time;
  api.OnVsync = on_vsync;
  fl_native_vsync_set_engine(self, reinterpret_cast<FlutterEngine>(1), &api);
  GtkWidget* window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  fl_native_vsync_set_widget(self, window);
  // Bootstrap an unrealized/hidden window without waiting on an absent clock.
  fl_native_vsync_request(self, 1);
  wait_for(1);
  gtk_widget_show_all(window);
  // A worker callback must return to the platform thread and batch all batons.
  std::thread worker([&] {
    fl_native_vsync_request(self, 2);
    fl_native_vsync_request(self, 3);
  });
  worker.join();
  wait_for(3);
  // Unmapping after dispatch but before a tick must not strand an engine baton.
  fl_native_vsync_request(self, 4);
  g_main_context_iteration(nullptr, FALSE);
  gtk_widget_hide(window);
  wait_for(4);
  gtk_widget_show_all(window);
  fl_native_vsync_request(self, 5);
  // A queued idle source is destroyed and all outstanding batons returned.
  fl_native_vsync_shutdown(self);
  assert(received == std::vector<intptr_t>({1, 2, 3, 4, 5}));
  fl_native_vsync_engine_stopped(self);
  fl_native_vsync_free(self);
  gtk_widget_destroy(window);
  while (g_main_context_iteration(nullptr, FALSE)) {}
  g_print("native vsync bridge: bootstrap, worker thread, native tick, unmap, shutdown passed\n");
}
