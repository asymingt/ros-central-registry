#include <iostream>
#include <thread>
#include <chrono>
#include <filesystem>
#include <gtest/gtest.h>

#if defined(__APPLE__)
#include <mach/mach.h>
#include <mach/thread_act.h>
#endif

namespace {

size_t get_current_thread_count() {
#if defined(__APPLE__)
  thread_act_array_t thread_list;
  mach_msg_type_number_t thread_count;
  kern_return_t kr = task_threads(mach_task_self(), &thread_list, &thread_count);
  if (kr == KERN_SUCCESS) {
    for (mach_msg_type_number_t i = 0; i < thread_count; ++i) {
      mach_port_deallocate(mach_task_self(), thread_list[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)thread_list, thread_count * sizeof(thread_act_t));
    return thread_count;
  }
  return 1;
#else
  size_t count = 0;
  try {
    for (const auto & entry : std::filesystem::directory_iterator("/proc/self/task")) {
      (void)entry;
      count++;
    }
  } catch (...) {
    return 1; // Fallback if /proc is not mounted
  }
  return count;
#endif
}

class DDSThreadCleanupListener : public ::testing::EmptyTestEventListener {
public:
  void OnTestProgramStart(const ::testing::UnitTest& /*unit_test*/) override {
    baseline_thread_count_ = get_current_thread_count();
  }

  void OnTestEnd(const ::testing::TestInfo& test_info) override {
    auto start = std::chrono::steady_clock::now();
    constexpr std::chrono::milliseconds timeout(2000);
    
    size_t current_threads = get_current_thread_count();
    while (current_threads > baseline_thread_count_) {
      if (std::chrono::steady_clock::now() - start > timeout) {
        std::cerr << "[ WARNING ] " << test_info.test_suite_name() << "." << test_info.name() 
                  << " timed out waiting for background threads to exit. "
                  << "Baseline: " << baseline_thread_count_ 
                  << ", Current: " << current_threads << "\n";
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
      current_threads = get_current_thread_count();
    }
  }

private:
  size_t baseline_thread_count_ = 1;
};

// Register the listener statically
static struct DDSThreadCleanupListenerRegistrar {
  DDSThreadCleanupListenerRegistrar() {
    auto& listeners = ::testing::UnitTest::GetInstance()->listeners();
    listeners.Append(new DDSThreadCleanupListener);
  }
} g_dds_thread_cleanup_listener_registrar;

} // namespace
