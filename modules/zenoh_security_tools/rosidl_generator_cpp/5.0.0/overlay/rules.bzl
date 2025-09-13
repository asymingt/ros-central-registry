
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

load("@rules_cc//cc:defs.bzl", "CcInfo", "cc_common")
load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load("@rosidl_adapter//:aspects.bzl", "idl_aspect")
load("@rosidl_adapter_proto//:aspects.bzl", "proto_aspect")
load("@rosidl_generator_c//:aspects.bzl", "c_aspect")
load("@rosidl_generator_type_description//:aspects.bzl", "type_description_aspect")
load("@rosidl_typesupport_c//:aspects.bzl", "c_typesupport_aspect")
load("@rosidl_typesupport_c//:types.bzl", "RosCTypesupportInfo")
load("@rosidl_typesupport_cpp//:aspects.bzl", "cc_typesupport_aspect")
load("@rosidl_typesupport_cpp//:types.bzl", "RosCcTypesupportInfo")
load(":types.bzl", "RosCcBindingsInfo")
load(":aspects.bzl", "cc_aspect")

def _cc_ros_library_impl(ctx):
    cc_infos = []
    for dep in ctx.attr.deps:
        if RosCcTypesupportInfo in dep:
            cc_infos.extend(dep[RosCcTypesupportInfo].cc_infos.to_list())
    return [
        cc_common.merge_cc_infos(direct_cc_infos = cc_infos),
        DefaultInfo(
            files = depset(
                transitive = [
                    dep[RosCcTypesupportInfo].cc_files
                        for dep in ctx.attr.deps if RosCcTypesupportInfo in dep
                ]
            )
        ),
    ]

cc_ros_library = rule(
    implementation = _cc_ros_library_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [
                idl_aspect,               # RosIdlInfo
                proto_aspect,             # ProtoInfo, CcInfo
                type_description_aspect,  # RosTypeDescriptionInfo
                c_aspect,                 # RosCBindingsInfo
                cc_aspect,                # RosCcBindingsInfo
                cc_typesupport_aspect,    # RosCcTypesupportInfo
            ],
            providers = [RosInterfaceInfo],
            allow_files = False,
        ),
    },
    provides = [CcInfo, DefaultInfo],
)

