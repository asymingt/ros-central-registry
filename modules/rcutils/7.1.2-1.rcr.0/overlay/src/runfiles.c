// Copyright 2026 Open Source Robotics Foundation, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
 
#include "rcutils/filesystem.h"
#include "rcutils/runfiles.h"
#include "rcutils/snprintf.h"

#include <unistd.h> // For readlink
#include <limits.h> // For PATH_MAX
#include <stdint.h> // For uint32_t
#include <stdlib.h> // For getenv

#if defined(__APPLE__)
#include <mach-o/dyld.h> // For _NSGetExecutablePath
#endif

#if defined(_WIN32)
#include <windows.h> // For GetModuleFileNameA, MAX_PATH
#endif

// Cross-platform way of obtaining the full path to the current executable. Returns
// std::nullopt if we can't determine the path. We need this to determine if a
// .runfiles/MANIFEST file exists in the current directory.
bool
get_executable_name(char result[PATH_MAX])
{
#if defined(_WIN32)
  DWORD path_len = GetModuleFileNameA(NULL, result, MAX_PATH);
#elif defined(__APPLE__)
  uint32_t path_len = PATH_MAX;
  if (_NSGetExecutablePath(result, &path_len) != 0) {
    return true;
  }
  const ssize_t resolved_path_len = readlink(result, result, PATH_MAX);
  if (resolved_path_len > 0) {
    result[resolved_path_len] = '\0';
    path_len = (uint32_t)resolved_path_len;
  }
#else
  ssize_t path_len = readlink("/proc/self/exe", result, PATH_MAX);
#endif
  if (path_len > 0) {
    return true;
  }
  return false;
}

// Do our best to resolve the correct runfile path from which to load all assets
// belonging to the current target.
char *
get_runfile(
  const char* runfile_name,
  rcutils_allocator_t allocator)
{
    char * runfiles_dir = getenv("RUNFILES_DIR");
    char * test_workspace = getenv("TEST_WORKSPACE");
    if (runfiles_dir && test_workspace) {
      char * runfile_path = rcutils_join_path(runfiles_dir, runfile_name, allocator);
      if (rcutils_is_file(runfile_path)) {
        return runfile_path;
      }
    }
    char buffer[PATH_MAX] = {'\0'};
    if (get_executable_name(buffer)) {
      char runfile_root[PATH_MAX] = {'\0'};
      int ret = rcutils_snprintf(runfile_root, PATH_MAX, "%s.runfiles", buffer);
      if (ret) {
        char * runfile_base = rcutils_join_path(runfile_root, "_main", allocator);
        char * runfile_path = rcutils_join_path(runfile_base, runfile_name, allocator);
        if (rcutils_is_file(runfile_path)) {
          return runfile_path;
        }
      }
    }
    if (getcwd(buffer, PATH_MAX)) {
      char * runfile_path = rcutils_join_path(buffer, runfile_name, allocator);
      if (rcutils_is_file(runfile_path)) {
          return runfile_path;
      }
    }
    return NULL;
}
