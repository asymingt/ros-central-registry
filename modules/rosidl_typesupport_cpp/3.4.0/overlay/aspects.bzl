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
load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")

load("@rosidl_cmake//:types.bzl", "RosInterfaceInfo")
load("@rosidl_adapter//:types.bzl", "RosIdlInfo")
load("@rosidl_adapter//:tools.bzl", "generate_sources", "generate_cc_info")
load("@rosidl_generator_c//:types.bzl", "RosCBindingsInfo")
load("@rosidl_generator_cpp//:types.bzl", "RosCcBindingsInfo")
load("@rosidl_generator_type_description//:types.bzl", "RosTypeDescriptionInfo")
load("@rosidl_typesupport_c//:types.bzl", "RosCTypesupportInfo")
load(":types.bzl", "RosCcTypesupportInfo")

def _cc_typesupport_aspect_impl(target, ctx):
    input_idls = target[RosIdlInfo].idls.to_list()
    input_type_descriptions = target[RosTypeDescriptionInfo].jsons.to_list()

    # Generate type support
    cc_typesupport_hdrs, cc_typesupport_srcs, cc_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._cc_typesupport_generator,
        mnemonic = "CCTypeSupportGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._cc_typesupport_templates[DefaultInfo].files.to_list(),
        templates_hdrs = [],
        templates_srcs = ["detail/{}__rosidl_typesupport_cpp.cpp"],
        additional = [
            "--typesupports",
            "rosidl_typesupport_introspection_cpp",
            "rosidl_typesupport_fastrtps_cpp",
            "rosidl_typesupport_protobuf_cpp",
        ],
    )

    # Generate the type support library for introspection
    cc_introspection_hdrs, cc_introspection_srcs, cc_introspection_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._cc_typesupport_introspection_generator,
        mnemonic = "CcTypeSupportIntrospectionGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._cc_typesupport_introspection_templates[DefaultInfo].files.to_list(),
        templates_hdrs = ["detail/{}__rosidl_typesupport_introspection_cpp.hpp"],
        templates_srcs = ["detail/{}__rosidl_typesupport_introspection_cpp.cpp"],
        template_visibility_control = None,
    )

    # Generate the type support library for fastrtps
    cc_fastrtps_hdrs, cc_fastrtps_srcs, cc_fastrtps_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._cc_typesupport_fastrtps_generator,
        mnemonic = "CcTypeSupportFastRTPSGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._cc_typesupport_fastrtps_templates[DefaultInfo].files.to_list(),
        templates_hdrs = ["detail/{}__rosidl_typesupport_fastrtps_cpp.hpp"],
        templates_srcs = ["detail/{}__rosidl_typesupport_fastrtps_cpp.cpp"],
        template_visibility_control = ctx.file._cc_typesupport_fastrtps_visibility_template,
    )

    # Generate the type support library for protobuf
    cc_protobuf_hdrs, cc_protobuf_srcs, cc_protobuf_include_dir = generate_sources(
        target = target,
        ctx = ctx,
        executable = ctx.executable._cc_typesupport_protobuf_generator,
        mnemonic = "CcTypeSupportProtobufGeneration",
        input_idls = input_idls,
        input_type_descriptions = input_type_descriptions,
        input_templates = ctx.attr._cc_typesupport_protobuf_templates[DefaultInfo].files.to_list(),
        templates_hdrs = [
            "{}__rosidl_typesupport_protobuf_cpp.hpp",
            "{}__typeadapter_protobuf_cpp.hpp",
        ],
        templates_srcs = [
            "detail/{}__rosidl_typesupport_protobuf_cpp.cpp",
        ],
        template_visibility_control = ctx.file._cc_typesupport_protobuf_visibility_template,
    )

    # These deps will all have CcInfo providers. We need to combine the library
    # dependencies with the C generated headers and C++ generated headers.
    deps = [target[CcInfo]]
    deps.extend([dep[CcInfo] for dep in ctx.attr._cc_deps + ctx.rule.attr.deps if CcInfo in dep])
    deps.extend([d for d in target[RosCBindingsInfo].cc_infos.to_list()])
    deps.extend([d for d in target[RosCcBindingsInfo].cc_infos.to_list()])
    for dep in ctx.rule.attr.deps:
        if RosCcTypesupportInfo in dep:
            deps.extend([d for d in dep[RosCcTypesupportInfo].cc_infos.to_list()])
    
    # Merge headers, sources and deps into a CcInfo provider.
    hdrs = cc_typesupport_hdrs + cc_introspection_hdrs + cc_fastrtps_hdrs + cc_protobuf_hdrs
    srcs = cc_typesupport_srcs + cc_introspection_srcs + cc_fastrtps_srcs + cc_protobuf_srcs
    cc_info = generate_cc_info(
        ctx = ctx,
        name = "{}_cc_typesupport".format(ctx.label.name),
        hdrs = hdrs,
        srcs = srcs,
        deps = deps,
        include_dirs = [
            cc_include_dir,
            cc_introspection_include_dir,
            cc_fastrtps_include_dir,
            cc_protobuf_include_dir
        ]
    )

    # Return a CcInfo provider for the aspect.
    return [
        RosCcTypesupportInfo(
            cc_infos = depset(
                direct = [cc_info],
                transitive = [
                    dep[RosCcTypesupportInfo].cc_infos
                        for dep in ctx.rule.attr.deps if RosCcTypesupportInfo in dep
                ],
            ),
            cc_files = depset(
                direct = hdrs + srcs,
                transitive = [
                    dep[RosCcTypesupportInfo].cc_files
                        for dep in ctx.rule.attr.deps if RosCcTypesupportInfo in dep
                ],
            ),
        )
    ]

cc_typesupport_aspect = aspect(
    implementation = _cc_typesupport_aspect_impl,
    toolchains = use_cc_toolchain(),
    attr_aspects = ["deps"],
    fragments = ["cpp"],
    attrs = {

        #########################################################################
        # General type support generation #######################################
        #########################################################################
        
        "_cc_typesupport_generator": attr.label(
            default = Label("@rosidl_typesupport_cpp//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_cc_typesupport_templates": attr.label(
            default = Label("@rosidl_typesupport_cpp//:interface_templates"),
        ),

        #########################################################################
        # Introspection type support generation #################################
        #########################################################################
        
        "_cc_typesupport_introspection_generator": attr.label(
            default = Label("@rosidl_typesupport_introspection_cpp//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_cc_typesupport_introspection_templates": attr.label(
            default = Label("@rosidl_typesupport_introspection_cpp//:interface_templates"),
        ),

        #########################################################################
        # FastRTPS type support generation ######################################
        #########################################################################
        
        "_cc_typesupport_fastrtps_generator": attr.label(
            default = Label("@rosidl_typesupport_fastrtps_cpp//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_cc_typesupport_fastrtps_templates": attr.label(
            default = Label("@rosidl_typesupport_fastrtps_cpp//:interface_templates"),
        ),
        "_cc_typesupport_fastrtps_visibility_template": attr.label(
            default = Label("@rosidl_typesupport_fastrtps_cpp//:resource/rosidl_typesupport_fastrtps_cpp__visibility_control.h.in"),
            allow_single_file = True,
        ),

        #########################################################################
        # Protobuf type support generation ######################################
        #########################################################################
        
        "_cc_typesupport_protobuf_generator": attr.label(
            default = Label("@rosidl_typesupport_protobuf_cpp//:cli"),
            executable = True,
            cfg = "exec",
        ),
        "_cc_typesupport_protobuf_templates": attr.label(
            default = Label("@rosidl_typesupport_protobuf_cpp//:interface_templates"),
        ),
        "_cc_typesupport_protobuf_visibility_template": attr.label(
            default = Label("@rosidl_typesupport_protobuf_cpp//:resource/rosidl_typesupport_protobuf_cpp__visibility_control.h.in"),
            allow_single_file = True,
        ),

        #########################################################################
        # Dependencies ##########################################################
        #########################################################################
        
        "_cc_deps": attr.label_list(
            default = [
                Label("@rosidl_typesupport_interface"),
                Label("@rosidl_typesupport_cpp"),
                Label("@rosidl_typesupport_introspection_cpp"),
                Label("@rosidl_typesupport_fastrtps_cpp"),
                Label("@rosidl_typesupport_protobuf_cpp"),
                Label("@rmw"),
            ],
            providers = [CcInfo],
        ),  
    },
    required_providers = [RosInterfaceInfo],
    required_aspect_providers = [
        [RosIdlInfo],
        [RosTypeDescriptionInfo],
        [CcInfo],
        [RosCBindingsInfo],
        [RosCcBindingsInfo],
    ],
    provides = [RosCcTypesupportInfo],
)
