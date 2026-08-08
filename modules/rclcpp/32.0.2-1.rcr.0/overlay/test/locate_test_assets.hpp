// Copyright 2020 Open Source Robotics Foundation, Inc.
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

#ifndef LOCATE_TEST_ASSETS_HPP_
#define LOCATE_TEST_ASSETS_HPP_

#include <rcpputils/env.hpp>

#include <filesystem>
#include <string>

std::filesystem::path get_test_asset_dir() {
  std::string runfiles_dir = rcpputils::get_env_var("RUNFILES_DIR");
  if (!runfiles_dir.empty()) { 
    std::filesystem::path runfiles_path(runfiles_dir);
    return runfiles_path / BAZEL_CURRENT_REPOSITORY / "test" / "resources";
  }
  throw std::runtime_error("Could not determine the path to test assets");
}

#endif  // LOCATE_TEST_ASSETS_HPP_
