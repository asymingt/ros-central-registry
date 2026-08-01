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

load("@rules_cc//cc/common:cc_shared_library_info.bzl", "CcSharedLibraryInfo")
load(":types.bzl", "CollectedCcSharedLibraryInfo")

def _collect_transitive_dynamic_deps_aspect_impl(target, ctx):
    direct_cc_shared_library_infos = [
        target[CcSharedLibraryInfo],
    ] if CcSharedLibraryInfo in target else []
    transitive_cc_shared_library_infos = [
        dep[CollectedCcSharedLibraryInfo].cc_shared_library_info
        for dep in ctx.rule.attr.dynamic_deps
        if CollectedCcSharedLibraryInfo in dep
    ]
    return [
        CollectedCcSharedLibraryInfo(
            cc_shared_library_info = depset(
                direct = direct_cc_shared_library_infos,
                transitive = transitive_cc_shared_library_infos,
            ),
        ),
    ]

collect_transitive_dynamic_deps_aspect = aspect(
    implementation = _collect_transitive_dynamic_deps_aspect_impl,
    attr_aspects = ["dynamic_deps"],
    provides = [CollectedCcSharedLibraryInfo],
)
