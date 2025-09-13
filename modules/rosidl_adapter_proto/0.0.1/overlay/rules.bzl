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
load(":aspects.bzl", "proto_aspect")
load(":types.bzl", "RosProtoInfo")
load(":tools.bzl", "merge_proto_infos")

def _proto_ros_library_impl(ctx):
    proto_info, _ = merge_proto_infos(
        ctx = ctx,
        name = ctx.label.name,
        deps = ctx.attr.deps
    )
    proto_files = []
    for dep in ctx.attr.deps:
        if RosProtoInfo in dep:
            proto_files.extend(dep[RosProtoInfo].protos.to_list())
    default_info = DefaultInfo(files = depset(proto_files))
    return [proto_info, default_info]

proto_ros_library = rule(
    implementation = _proto_ros_library_impl,
    fragments = ["proto"],
    toolchains = ["@protobuf//bazel/private:proto_toolchain_type"],
    attrs = {
        "deps": attr.label_list(
            aspects = [
                idl_aspect,
                proto_aspect,
            ],
            providers = [RosInterfaceInfo],
            allow_files = False,
        ),
    },
    provides = [ProtoInfo, DefaultInfo],
)

