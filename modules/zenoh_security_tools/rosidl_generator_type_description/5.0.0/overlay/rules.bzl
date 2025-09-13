
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

load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load("@rosidl_adapter//:aspects.bzl", "idl_aspect")
load(":aspects.bzl", "type_description_aspect")
load(":types.bzl", "RosTypeDescriptionInfo")

def _type_description_ros_library_impl(ctx):
    files = []
    for dep in ctx.attr.deps:
        files.extend(dep[RosTypeDescriptionInfo].jsons.to_list())
    return [
        DefaultInfo(files = depset(files)),
    ]

type_description_ros_library = rule(
    implementation = _type_description_ros_library_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [
                idl_aspect,                 # idl  <- ros aspect [STEP 1]
                type_description_aspect,    # json <- idl aspect [STEP 2]
            ],
            providers = [RosInterfaceInfo],
            allow_files = False,
        ),
    },
    provides = [DefaultInfo],
)

