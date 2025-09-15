
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

load(":types.bzl", "RosInterfaceInfo")

def _ros_interface_impl(ctx):
    return RosInterfaceInfo(
        srcs = depset(
            direct = [ctx.file.src],
            transitive = [
                dep[RosInterfaceInfo].srcs for dep in ctx.attr.deps
            ]
        ),
        package = ctx.attr.package
    )

ros_interface_rule = rule(
    implementation = _ros_interface_impl,
    attrs = {
        "src": attr.label(
            allow_single_file = [
                ".msg",
                ".srv",
                ".action"
            ],
            mandatory = True,
        ),
        "package": attr.string(mandatory=True),
        "deps": attr.label_list(providers = [RosInterfaceInfo]),
    },
    provides = [RosInterfaceInfo],
)

# This is a workaround to allow messages to be declared from the root
# workspace. When this happens the target.label.workspace_name variable
# is empty, and so we need this macro to propagate the name correctly
# down the aspect chain.

def ros_interface(name, src, deps = []):
    ros_interface_rule(
        name = name,
        src = src,
        package = native.module_name(),
        deps = deps,
    )