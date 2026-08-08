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

#include <cstdlib>

#if defined(_WIN32)
#include <stdlib.h>
#define setenv(name, val, overwrite) _putenv_s(name, val)
#else
#include <unistd.h>
#endif

static int initialize_test_environment() {
    const char* test_tmpdir = std::getenv("TEST_TMPDIR");
    if (test_tmpdir) {
        setenv("ROS_HOME", test_tmpdir, 1);
        setenv("TMPDIR", test_tmpdir, 1);
        setenv("HOME", test_tmpdir, 1);
    }
    return 0;
}

// Global static initializer to ensure environment setup runs before main()
static int dummy = initialize_test_environment();
