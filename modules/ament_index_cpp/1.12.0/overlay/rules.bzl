# Copyright 2025 Open Source Robotics Foundation, Inc.
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

def _ros_data_impl(ctx):
    # When we use local path overrides for the module name, Bazel appends
    # a plus sign to the end. We must remove this, or the ament_index
    # paths will not be correct and we won't be able to resolve files.
    module_name = ctx.label.workspace_name.removesuffix("+")

    # Create a new, empty file for the ament index. This is a shim to help
    # the ament_index_{cpp, python, ...} discover packages. We use the
    # ctx.index.write call because it's platform independent.
    ament_index_path = "share/ament_index/resource_index/packages/" + module_name
    ament_index_file = ctx.actions.declare_file("_" + module_name)
    ctx.actions.write(output = ament_index_file, content = "")

    # Add the package index and the additional files for the share dir.
    symlinks = { ament_index_path : ament_index_file }
    for target in ctx.attr.data:
        for file in target.files.to_list():
            # The Bazel runfile engine by default prefixes the symlinks
            # with the workspace_root to avoid conflicts. We have to
            # remove this to allow them all to be relative to
            if file.basename.endswith(".so"):
                symlinks["lib" + "/" + file.basename] = file
            else:
                file_path = file.path.removeprefix(ctx.label.workspace_root + "/")
                symlinks["share" + "/" + module_name + "/" + file_path] = file

    # Return a collection of runfiles with manipulated symlinks.
    return [
        DefaultInfo(
            files = depset(direct = symlinks.values()),
            runfiles = ctx.runfiles(symlinks = symlinks)
        )
    ]

ros_data = rule(
    implementation = _ros_data_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
    }
)
