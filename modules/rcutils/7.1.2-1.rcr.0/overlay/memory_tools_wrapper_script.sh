#!/usr/bin/env bash
# Copyright 2026 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Runs a test binary with osrf_testing_tools_cpp's memory-tools interposition
# dylib injected on Darwin. DYLD_INSERT_LIBRARIES is consulted by dyld before
# main() runs, so the path must be resolved to an absolute location up front
# -- it can't be resolved from within the test binary itself. Bazel's own
# $(location) expansion produces a path relative to the test's runfiles
# directory, which only resolves if the process's cwd at exec time happens to
# match; that assumption doesn't hold in every context (e.g. when this
# package is consumed as a bzlmod dependency of a different root module), so
# this resolves the dylib through the runfiles library instead, which handles
# that correctly regardless of context.
#
# On non-Darwin platforms DYLD_INSERT_LIBRARIES is meaningless, so this is a
# transparent passthrough to the wrapped binary. TODO(asymingt) are there any
# other platforms that might require this type of workaround?

set -euo pipefail

# --- begin runfiles.bash boilerplate ---
if [[ -z "${RUNFILES_DIR:-}" && -z "${RUNFILES_MANIFEST_FILE:-}" ]]; then
  if [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -d "$0.runfiles" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " "${RUNFILES_MANIFEST_FILE}" | cut -d' ' -f2-)"
else
  echo >&2 "ERROR: cannot find runfiles.bash"
  exit 1
fi
# --- end runfiles.bash boilerplate ---

test_bin="$(rlocation "$1")"
shift
memory_tools_interpose_dylib="$(rlocation "$1")"
shift

if [[ "$(uname -s)" == "Darwin" ]]; then
  export DYLD_INSERT_LIBRARIES="${memory_tools_interpose_dylib}"
fi

exec "${test_bin}" "$@"
